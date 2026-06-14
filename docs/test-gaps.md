# 核心链路测试缺口

生成日期：2026-06-12

依据：

- 应测范围：[critical-paths.md](critical-paths.md)
- 当前现状：[test-status.md](test-status.md)

口径：

- 只列核心链路上的缺口，不列非主链路能力。
- 总数控制在 30 项以内，宁少勿多。
- 不追求覆盖率指标，只追求关键路径改造时有兜底。
- P0 表示改造前必须有；P1 表示有了更好。
- 当前 `mvn test` 最终 `BUILD SUCCESS`，但 Surefire 实际执行测试数为 0；现有源码中的 7 个测试类、16 个 `@Test` 方法没有形成可运行的关键路径保护。

## 缺口总表

| # | 核心链路 | 优先级 | 场景描述 | 为什么必须 | 建议测试类型 |
|---:|---|---|---|---|---|
| 1 | 登录认证 | P0 | 调用 `POST /console/v1/auth/login` 校验用户名密码：正确凭证返回 access_token / refresh_token 和过期时间；错误密码或不存在用户返回 401，且不写入 token 到 Redis | 登录凭证校验是控制台入口的第一道防线；既要保证合法用户能进入，也要保证错误凭证不会被误放行或留下半成品会话 | 集成 |
| 2 | 登录认证 | P0 | 带有效 access_token 访问 `/console/v1/**` 认证接口通过；Redis 中 token 缺失或过期时返回 401 | 当前方案依赖 Redis 做有状态认证，不是纯 JWT 解析；这条保护认证拦截器的真实行为 | 集成 |
| 3 | 登录认证 | P0 | `POST /console/v1/auth/refresh-token` 用有效 refresh_token 换发新 access_token，新 access_token 可访问 `/console/v1/**` 认证接口；失效 refresh_token 返回 401 | 前端依赖自动 refresh 维持会话；只返回 token 不代表 token 可用，必须验证换发结果能通过后续认证 | 集成 |
| 4 | 登录认证 | P0 | `POST /console/v1/auth/logout` 后原 access_token 立即失效，再访问认证接口返回 401 | 主动失效是状态化认证的安全边界；只测 JWT 有效期无法覆盖用户退出后的即时失效 | 集成 |
| 5 | Prompt 调试运行 | P0 | `POST /api/prompt/run` 读取 prompt_version、替换 variables、加载 model_config，并以 NDJSON / Flux 返回合法流式事件 | Prompt 调试是模板迭代主入口；模板渲染、模型参数或流式协议任一处变化都会让调试页面不可用 | Characterization Test |
| 6 | Prompt 调试运行 | P0 | 同一 session 连续调用 `POST /api/prompt/run` 时，第二轮请求携带第一轮用户和助手消息历史；session 查询接口能看到多轮消息 | 多轮会话是 Prompt 调试主链路的一部分；只测单轮流式输出无法发现历史消息丢失、顺序错误或 sessionId 失效 | Characterization Test |
| 7 | 实验执行评测 | P0 | 创建实验后异步解析 evaluation_object_config、dataset_version、dataset_item 和 evaluator_config，按 item × evaluator 写入 `experiment_result` | 实验链路跨多表、多段 JSON 和异步线程池；这是 LLM-as-Judge 评测真正产出结果的主路径 | 集成 |
| 8 | 实验执行评测 | P0 | 实验全部执行完成后状态为 COMPLETED、progress=100，`GET /api/experiment/results` 返回按评估器聚合的平均分 | 用户最终只看状态、进度和聚合结果；底层结果存在但聚合或状态错误，主链路仍不可用 | 集成 |
| 9 | 知识库文档索引 | P0 | 上传文档后同步保存文件、创建 `document` 记录、写入文件路径，并发送 RocketMQ 索引消息，初始 index_status=UPLOADED | 知识库入口依赖同步落库和异步索引衔接；如果 MQ 消息没发出，文档永远不会进入索引流程 | 集成 |
| 10 | 知识库文档索引 | P0 | `DocumentIndexHandler` 消费消息后将状态推进到 PROCESSING，再写入 chunks / VectorStore，成功为 PROCESSED，失败为 FAILED | 文档索引最怕异步状态卡住或索引完成但查询不到分片；这条覆盖 MQ 消费后的主处理链路 | 集成 |
| 11 | 知识库文档索引 | P1 | re-index 删除旧 chunks、重置 index_status=UPLOADED，并重新发送 RocketMQ 索引消息 | 重建索引是知识库修复和配置调整后的主恢复手段；旧 chunks 残留会导致检索结果混乱 | 集成 |
| 12 | 应用工作流调试 / OpenAPI 外部调用 | P0 | 最小 DAG `Start -> LLM -> End` 通过控制台调试入口和 OpenAPI Workflow 入口复用 `WorkflowExecuteManager` 完成执行；控制台写入 / 查询 WorkflowContext，OpenAPI 按 invokeSource 返回结果 | DAG 调度框架是所有工作流节点共享底座；控制台调试和 OpenAPI Workflow 共用执行引擎，入口差异不能破坏调度、上下文和返回语义 | Characterization Test |
| 13 | 应用工作流调试 | P0 | Input 节点进入 PAUSE，`resume-task` 写入用户输入后继续执行到 End，`get-task-process` 能读到 Redis 进度 | 暂停 / 恢复是调试态和人工输入节点的关键行为，依赖 Redis 状态位和轮询逻辑 | 集成 |
| 14 | 应用工作流调试 | P1 | `stop-task` 写入终止状态后，监控线程和正在执行的节点都停止，后续不再产生新的节点输出 | 停止任务是调试态的基本控制能力；失败时容易造成任务挂起、重复执行或脏上下文残留 | 集成 |
| 15 | 应用工作流调试 | P1 | Classifier / Judge 根据条件只执行命中的后续分支，未命中分支不执行 | 条件路由决定 DAG 后续路径；错路由通常不抛异常，只会产生错误业务结果 | 单元 |
| 16 | OpenAPI 外部调用 | P0 | `/api/v1/apps/chat/completions` 使用 API Key 认证：有效 key 通过，禁用、过期、错误 key 拒绝，且不受控制台 JWT 认证影响 | OpenAPI 与控制台是两套认证体系；外部调用入口必须先保证认证边界不会串线 | 集成 |
| 17 | Agent 工具调用 | P0 | tool 从 DRAFT 发布为 PUBLISHED 后，Agent 执行时能从 AgentConfig 组装该插件工具、注册 ToolCallback，并完成一次 LLM -> 工具调用 -> LLM 的递归调用链 | 这是 Agent 使用外部工具的核心路径；发布状态、AgentConfig 解析、ToolCallback 注册和工具调用循环必须连成闭环 | Characterization Test |
| 18 | 工具发布与执行 | P0 | 导入 OpenAPI YAML / JSON 后为端点创建 DRAFT tool，`config` 保存 path、method、contentType 和参数 schema，`api_schema` 保存原始文档 | 工具创建是后续测试、发布和编排引用的起点；OpenAPI 解析错会让工具定义从源头失真 | 单元 |
| 19 | 工具发布与执行 | P0 | 工具 test 调用拼接 plugin.server + tool.path，按配置注入认证，并把参数分发到 Header / Query / Path / Body，更新 test_status | 工具可用性取决于真实 HTTP 执行；URL、认证、参数位置任一处拼错都会导致 Agent / Workflow 调用失败 | 单元 |
| 20 | Agent RAG 检索增强 | P0 | 手动调用 `/console/v1/knowledge-bases/retrieve` 时，多知识库并行检索后合并排序，按 similarityThreshold 过滤并截取 topK；rerank 配置完整且启用时才调用 Rerank | 手动 retrieve 是 RAG 检索能力的基础入口；排序、过滤、截断和可选重排错误通常不抛异常，只会让召回质量变差 | 单元 |
| 21 | Agent RAG 检索增强 | P0 | Agent 对话触发 `KnowledgeBaseRetrievalAdvisor.before()`：检索结果替换系统 Prompt 中的 `{documents}`，stream 和 non-stream 模式都生效 | RAG 的最终价值在 Agent 对话中自动注入上下文；手动检索可用但 Advisor 未注入时，用户仍得不到增强答案 | Characterization Test |

## 汇总

| 优先级 | 数量 | 重点 |
|---|---:|---|
| P0 | 18 | 认证、Prompt 流式和多轮会话、实验执行、文档索引、工作流调度、OpenAPI 入口、Agent 工具调用、工具发布执行、RAG 检索和注入 |
| P1 | 3 | 文档 re-index、工作流停止 / 条件路由 |
| 合计 | 21 | 每项都是可独立认领、独立实现、独立验收的核心链路测试任务 |

## 说明

- 这些缺口不是“补多少覆盖率”，而是“核心路径改造前至少要有的行为防线”。
- P0 优先用薄集成测试或 Characterization Test 锁住当前行为，再进行重构。
- 当前测试套件没有实际执行任何测试，因此即使存在少量工具类测试源码，也不能算作关键路径兜底。
