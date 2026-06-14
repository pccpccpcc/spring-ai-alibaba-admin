# 核心链路清单

本文档列出改造时最容易出问题的核心链路，用于指导测试优先级和回归重点。

选取标准：跨表/跨服务交互多、状态流转复杂、或认证机制特殊。不是全部链路的罗列。

---

## 总览

| # | 链路名 | 起点（接口） | 风险点 |
|---|---|---|---|
| 1 | 登录认证 | `POST /console/v1/auth/login` | Redis 状态化认证，token 过期/刷新/失效 |
| 2 | Prompt 调试运行 | `POST /api/prompt/run` | WebFlux 流式输出，会话无截断 |
| 3 | 实验执行评测 | `POST /api/experiment` | LLM-as-Judge 打分，异步线程池，多表关联 |
| 4 | 知识库文档索引 | `POST /console/v1/knowledge-bases/{kbId}/documents` | RocketMQ 异步，多步骤状态流转 |
| 5 | 应用工作流调试 | `POST /console/v1/apps/workflow/debug/run-task` | DAG 执行框架，断点暂停/恢复，多节点类型 |
| 6 | OpenAPI 外部调用 | `POST /api/v1/apps/chat/completions` | API Key 认证，Agent 组装，工具调用循环 |
| 7 | 工具发布与执行 | `POST /console/v1/plugins/{pluginId}/tools` | HTTP API 封装，OpenAPI 解析，被 Agent/Workflow 引用 |
| 8 | Agent RAG 检索增强 | `POST /console/v1/knowledge-bases/retrieve` | 多知识库并行检索，混合检索+可选 Rerank，Advisor 注入 |

---

## 1. 登录认证

**起点：** `POST /console/v1/auth/login` → 后续所有 `/console/v1/**` 接口

**认证机制：** JWT + Redis 有状态认证（不是纯 JWT 无状态方案，Redis 是硬依赖）

**关键节点：**

1. 查 `account` 表校验用户名密码
2. 生成 JWT access_token（TTL=7200s/2h）+ refresh_token（TTL=2592000s/30d）
3. 将 token→accountId 映射写入 Redis（`access_token:{token}` → accountId），TTL 过期即失效
4. 将 AccountEntity 缓存到 Redis（缓存优先 + 防穿透策略：查不到缓存时写入 `CACHE_EMPTY_ID` 占位）
5. 后续请求经 `TokenAuthInterceptor` 从 Redis 校验 token（Redis 查不到则 401，不解析 JWT）
6. `POST /console/v1/auth/refresh-token`：从 Redis 查 refresh_token → 换发新 access_token
7. `POST /console/v1/auth/logout`：从 Redis 删除 access_token（主动失效）

**双认证架构：** `/console/v1/**` 用 JWT Token 认证（`TokenAuthInterceptor`），`/api/v1/**` 用 API Key 认证（`ApiKeyAuthInterceptor`），两套拦截器互不干扰。

**前端配合：** localStorage 存储 access_token + refresh_token + expires_time（access_token 的 2h 过期时间戳）。每次请求前 `asyncGet()` 检查 expires_time，过期则自动 refresh。refresh_token 的 30d 过期只由后端 Redis TTL 管理。

**终点：** 登录返回 token；用 token 调任意认证接口返回 200；refresh-token 能正常换发；logout 后 token 立即失效

---

## 2. Prompt 调试运行

**起点：** `POST /api/prompt/run`

**关键节点：**

1. 读取 `prompt_version.template` 和 `variables`，做模板变量替换
2. 读取 `model_config` 获取模型 endpoint/apiKey/temperature 等参数
3. 从 `ChatSessionServiceImpl` 获取或创建会话（ConcurrentHashMap 内存存储，30min TTL，10min 定时清理）
4. 通过 `SessionUtils` 将历史 ChatMessage 列表转换为 Spring AI 的 UserMessage/AssistantMessage 序列（**无截断，无滑动窗口**，达到模型上下文上限会直接报错）
5. 创建 Spring AI `ChatClient`，发起流式调用
6. 使用 Spring WebFlux `Flux<PromptRunResponse>` 流式返回（NDJSON content type，Reactor 背压控制）
7. 支持 Mock 工具（`FunctionToolCallback` 预设输出，用于调试模板渲染逻辑而不调真实模型）

**技术要点：**
- 流式实现基于 Spring WebFlux，非 Servlet 阻塞模型
- 会话存储是内存 ConcurrentHashMap（代码注释：生产环境建议用 Redis）
- 模型调用走 Spring AI ChatClient，非直接 HTTP

**终点：** 流式响应正常返回；session 可查询；模型参数（temperature 等）生效

---

## 3. 实验执行评测

**起点：** `POST /api/experiment` → 异步执行 → `GET /api/experiment/results`

**核心概念：** LLM-as-Judge 自动化评测——拿一批测试数据，逐条跑被测 Prompt，再用评估器 LLM 给输出打分。

**关键节点：**

1. 创建实验记录，状态直接设为 RUNNING（DRAFT 状态定义了但未使用）
2. 从 `experiment.evaluation_object_config`（JSON）解析被测对象配置：
   - `type: "prompt"` → 定位 `prompt_version`（通过 JSON 内的 promptKey + version，非外键列）
   - `variableMap`：数据集列名 ↔ Prompt 模板变量的映射
3. 从 `experiment.dataset_version_id` 加载 `dataset_version`：
   - `dataset_version.dataset_items`（JSON 数组）包含 item ID 列表
   - 每个 `dataset_item.data_content`（JSON）包含 input、reference_output 等字段
4. 从 `experiment.evaluator_config`（JSON 数组）加载评估器列表，每个评估器含：
   - `evaluatorVersionId` → 指向 `evaluator_version`（有独立的 model_config 和 prompt）
   - `variableMap`：source="actual_output" 或数据集列名 ↔ 评估器模板变量
5. 提交到固定线程池（5 threads）**异步执行**，API 立即返回
6. 逐条执行：
   - 对每条 dataset_item，替换 Prompt 模板变量 → 调目标模型 → 得到 actual_output
   - 对每个评估器，填充 actual_output + 参考数据 → 调评估器 LLM
   - 评估器 LLM 被强制要求返回 JSON：`{"score":"0.85","reason":"回答基本正确..."}`
   - 存入 `experiment_result` 表（score 0.00-1.00，reason 文本）
   - 单条失败只 catch + log，不中断整体实验
7. 更新 `experiment.progress`（0→100）

**结果量：** `dataset_item 数量 × 评估器数量` 条 experiment_result 记录。`GET /experiment/results` 实时聚合每个评估器的平均分。

**状态流转：**
```
(create) → RUNNING
  ├── 全部跑完 → COMPLETED
  ├── 线程异常 → FAILED
  ├── 用户 stop → STOPPED
  └── restart → 清除旧 result → RUNNING（重新执行）
```

**风险点：** 重启后实验不会自动恢复（内存线程池，不像知识库索引用了 RocketMQ）

**终点：** experiment 状态变为 COMPLETED；progress=100；每条 dataset_item 都有对应的 experiment_result 且 score 有效

---

## 4. 知识库文档索引

**起点：** `POST /console/v1/knowledge-bases/{kbId}/documents`（上传）→ `PUT .../re-index`（重新索引）

**关键节点：**

1. **文件上传（同步）：** `FileManager.saveFile()` 将 MultipartFile 写入本地磁盘（路径：`storagePath/category/accountId/workspaceId/date/uuid_timestamp.ext`），返回 UploadPolicy
2. **创建文档记录（同步）：** 在 `document` 表创建记录（index_status=UPLOADED），文件路径存在 document 中
3. **发送 MQ（同步）：** 通过 RocketMQ Producer 异步发送消息到 `topic_saa_studio_document_index`。消息体是 Document JSON（含文件路径，**不含文件内容**）
4. `DocumentIndexHandler` 消费 MQ 消息，更新 index_status=PROCESSING
5. 解析文件 → 分块（Chunk） → Embedding 向量化 → 写入 VectorStore（Elasticsearch 等）
6. 更新 `document.index_status`：UPLOADED → PROCESSING → PROCESSED（或 FAILED）
7. 更新 `knowledge_base.total_docs`

**为什么用 RocketMQ 而非线程池：**
- 进程重启后消息不丢失（持久化）
- 支持多实例部署
- 内置重试机制
- 文档索引是 IO 密集型操作，耗时可能很长

**re-index 流程：** 删除旧 chunks → 重置 status 为 UPLOADED → 重新发 MQ 消息

**终点：** document.index_status=PROCESSED；chunks 可查询；ES 中可检索到分片内容

---

## 5. 应用工作流调试

**起点：** `POST /console/v1/apps/workflow/debug/run-task`

**核心概念：** 可视化 DAG 编排与逐步执行工具。用户在前端画布上拖拽节点、连线，组成工作流图。支持断点暂停、子图调试、SSE 流式推送。

**DAG 执行框架层（所有节点共享，必须测）：**

1. 读取 `application_version.config`（Workflow JSON）
2. 用 JGraphT 构建 DAG 拓扑，确认节点执行顺序
3. 监控线程不断寻找"所有前驱节点已完成"的节点，放入执行队列
4. `WorkflowContext` 缓存到 Redis（节点输入/输出、变量、状态），key = `WORKFLOW_TASK_CONTEXT_PREFIX + workspaceId + "_" + taskId`
5. 前端轮询 `get-task-process` 从 Redis 读执行进度
6. Input 节点：设置状态为 PAUSE → 进入轮询循环（500ms 间隔，检查 Redis 状态变化）→ `resume-task` 填入用户输入 → 恢复执行
7. 支持 `part-graph/run-task` 子图调试：自动补虚拟 Start/End 节点，连接选中子图的源和汇
8. `stop-task` 通过 Redis 状态位终止执行，监控线程和节点执行检测到后停止
9. SSE 流式（`run_stream`）：`SseEmitter` 推送节点执行事件（Message/Error/Paused/Finished）

**高风险节点层（按需回归）：**

| 节点 | Processor | 风险原因 |
|---|---|---|
| LLM | `LLMExecuteProcessor` | 调外部模型，流式输出，使用最多 |
| Iterator | `IteratorExecuteProcessor` | 嵌套子 DAG 执行，状态管理复杂，支持嵌套 resume |
| Classifier/Judge | `ClassifierExecuteProcessor` / `JudgeExecuteProcessor` | 条件路由，决定后续执行路径，路径选错影响全局 |
| Plugin | `PluginExecuteProcessor` | 调用插件工具，和工具体系耦合 |
| Retrieval | `RetrievalExecuteProcessor` | 触发 RAG 检索，和知识库体系耦合 |

**测试建议：** 框架用 `Start → LLM → End` 验证，节点层只测高风险的 3~4 个。

**终点：** 框架：串行/并行/分支/循环执行顺序正确，断点暂停恢复正常，子图调试结果一致；节点层：LLM 流式输出、Iterator 嵌套执行、条件路由分支正确

---

## 6. OpenAPI 外部调用

**起点：** `POST /api/v1/apps/chat/completions`（API Key 认证）

**与控制台调试的区别：** 控制台用 JWT Token（`TokenAuthInterceptor`），OpenAPI 用 API Key（`ApiKeyAuthInterceptor`）。控制台支持断点/子图调试，OpenAPI 一口气跑完。

**关键节点：**

1. 从 Header 提取 API Key，查 `api_key` 表校验有效性（过期时间、启用状态）
2. 根据 application 配置确定类型（Agent / Workflow）：
   - **Agent 类型：** `BasicAgentExecutor` 组装 Agent
     - 从 `AgentConfig` 加载关联工具（`tool`）、知识库（`knowledge_base`）、模型（`model`）
     - `CompositeToolCallbackProvider` 收集四种 ToolCallback：Plugin 工具、MCP Server 工具、Agent 组件、Workflow 组件
     - 执行 Agent 推理循环：LLM 决策 → 调用工具（`PluginToolCallback.call()` 发 HTTP）→ 结果返回 LLM → 重复直到完成
     - 流式模式下 `processToolCallsRecursively()` 递归处理工具调用链
   - **Workflow 类型：** `WorkflowServiceImpl` 执行工作流
     - 走 `WorkflowExecuteManager.runTask()`，与调试路径共用执行引擎
     - `invokeSource` 不同：OpenAPI 不缓存 WorkflowContext 到 Redis
3. 流式（SSE）或非流式返回结果

**终点：** API Key 校验通过；Agent 正确调用模型和工具；流式 chunk 正常返回

---

## 7. 工具发布与执行

**起点：** `POST /console/v1/plugins/{pluginId}/tools` → `POST .../test` → `POST .../publish`

**核心概念：** 工具（Tool）是对外部 HTTP API 端点的封装（路径、方法、参数 schema），**不是 Agent 也不是 Workflow**。从属于插件（Plugin = server URL + 认证配置）。发布和测试都是工具级别操作，插件本身无发布流程。

**创建与发布：**

1. 导入 OpenAPI YAML/JSON，`OpenApiUtils.parseSchemaToForm()` 解析出工具（每个端点一个 tool）
2. 在 `tool` 表创建记录（status=DRAFT），`config` 存储 ToolConfig JSON（path、requestMethod、contentType、inputParams、outputParams），`api_schema` 存储原始 OpenAPI 文档
3. 启用：`POST .../enable`（enabled=1）
4. 测试：`POST .../test` 拼接 `plugin.server + tool.path`，注入 plugin 认证（Bearer/Basic/Custom），将参数分发到 Header/Query/Path/Body，实际发 HTTP 请求验证连通性
5. 更新 `tool.test_status`：NOT_TEST → PASSED / FAILED
6. 发布：`POST .../publish`（status=DRAFT → PUBLISHED）

**被 Agent/Workflow 调用：**
- **Agent 路径：** `PluginToolCallback` 注册给 Spring AI，LLM 看到工具的 name/description/inputSchema 后自主决定调用 → `call()` 拼接 URL + 认证 + 参数 → `ToolExecutionService` 发 HTTP 请求 → 结果返回 LLM
- **Workflow 路径：** `PluginExecuteProcessor` 节点引用 tool_id → 同样走 `ToolExecutionService` 发 HTTP 请求

**终点：** 工具状态 DRAFT→PUBLISHED 流转正确；测试连通性验证返回 PASSED；已发布工具在 Agent/Workflow 编排中可选且实际 HTTP 调用成功

---

## 8. Agent RAG 检索增强

**起点：** `POST /console/v1/knowledge-bases/retrieve`（被 Agent 对话内部自动调用）

**两个入口：**
- **手动调用：** 直接调 retrieve 接口
- **自动注入：** Agent 对话时通过 `KnowledgeBaseRetrievalAdvisor`（Spring AI Advisor）自动拦截，在 before() 中检索文档并注入

**关键节点：**

1. `DocumentRetrieverManager` 创建 `KnowledgeBaseDocumentRetriever`
2. **多知识库并行检索：** 对每个知识库提交 `CompletableFuture`，通过 `ThreadPoolUtils` 并行执行
3. 每个知识库内部：
   - 获取 VectorStore 实例（基于知识库的 `indexConfig`）
   - 构建 FilterExpression（workspace_id + enabled=true）
   - 根据 `searchConfig` 确定 SearchType（SIMILARITY / HYBRID 等）
   - 设置 similarityThreshold、topK、hybridWeight 等参数
   - 调用 `vectorStore.similaritySearch()`（ES kNN 向量检索 + 关键词混合检索）
4. **可选 Rerank：** 若 `searchConfig.enableRerank=true` 且配置了 rerankProvider + rerankModel，调用 `DashscopeReranker` 对检索结果重排序
5. **合并排序过滤：** 所有知识库结果合并 → 按 score 降序 → 过滤低于 similarityThreshold → 截取 topK
6. 超时控制：单知识库检索超时 `SEARCH_TIMEOUT` 秒，超时抛 `DOCUMENT_RETRIEVAL_TIMEOUT`

**Advisor 注入模式：**
- `KnowledgeBaseRetrievalAdvisor.before()`：检索文档 → 拼接文本 → 替换系统 Prompt 中的 `{documents}` 占位符
- 支持 stream 和 non-stream 两种模式

**终点：** 返回与 query 相关的文档分片；分片内容完整不截断；在 Agent 对话中 RAG 增强生效
