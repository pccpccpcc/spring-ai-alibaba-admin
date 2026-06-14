# 测试现状报告

扫描日期：2026-06-11

---

## 实际运行结果

运行日期：2026-06-12  
运行命令：`mvn test`；默认 shell 下先运行一次，随后按项目 JDK 要求使用 JDK 21 重跑同一 Maven 测试命令。  
最终计入口径：JDK 21 下的 `mvn test` 结果。

| 项 | 结果 |
|---|---|
| 最终命令 | `JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home ... mvn test` |
| Maven 结果 | `BUILD SUCCESS` |
| Reactor 模块 | 5 个模块全部 SUCCESS |
| Surefire 实际执行 | `Tests run: 0, Failures: 0, Errors: 0, Skipped: 0` |
| 源码中可见测试 | 7 个 Java 测试类，16 个 `@Test` 方法 |
| 总耗时 | 2.539 s |

| 统计项 | 数量 | 说明 |
|---|---:|---|
| 通过 | 0 | 没有测试被 Surefire 实际执行 |
| 失败 | 0 | 没有测试用例失败；也没有代码断言失败 |
| 跳过 | 0 | Surefire 统计跳过为 0 |
| 未被发现 / 未执行 | 16 | 源码中 16 个 JUnit Jupiter `@Test` 方法未被当前 Maven/Surefire 实际发现执行 |

| 失败 / 异常分类 | 数量 | 归因 |
|---|---:|---|
| 代码 bug | 0 | 没有测试执行到业务断言，因此没有暴露代码 bug |
| 测试本身坏了 | 16 | 测试源码使用 JUnit Jupiter；当前 `mvn test` 实际运行的 Surefire 未发现这些测试，导致 16 个 `@Test` 方法有效执行数为 0 |
| 环境问题 | 1 | 默认 shell 直接运行 `mvn test` 时使用了 Java 8，报 `UnsupportedClassVersionError`；使用 JDK 21 后构建成功 |

| 健康度 | 判断 | 依据 |
|---|---|---|
| 测试健康度 | 红 | 虽然 Maven 最终 BUILD SUCCESS，但实际执行测试数为 0；按源码可见 16 个测试方法计算，有效通过率为 0%，低于 60% |

备注：

- 本次未尝试修复任何失败或未执行的测试。
- 默认 shell 的 Java 8 问题属于环境问题；JDK 21 重跑后没有代码编译失败。
- Maven 运行过程中出现 `~/.m2` metadata tracking file 写入权限 warning，但未导致最终 JDK 21 测试命令失败。

---

## 1. 总量统计

| 类别 | 文件数 | 说明 |
|---|---|---|
| 单元测试 | 7 | 全部在 `server-core` 模块，共 16 个测试方法 |
| 集成测试 | 0 | 无 |
| E2E 测试 | 0 | 无 |
| 前端测试 | 0 | `frontend/packages/` 下无任何 `.test.*` 或 `.spec.*` 文件 |

**总测试文件：7 个，覆盖范围极薄。** `server-start`、`server-openapi`、`server-runtime` 三个模块的 `src/test` 目录完全为空。

---

## 2. 现有测试文件清单

全部位于 `spring-ai-alibaba-admin-server-core/src/test/`：

| 文件 | 测试目标 | 方法数 |
|---|---|---|
| `core/crypto/RSACryptTest.java` | RSA 加解密工具 | 2 |
| `core/crypto/PasswordCryptTest.java` | 密码编码与匹配 | 2 |
| `core/utils/common/DateUtilsTests.java` | 日期解析 | 2 |
| `core/rag/reader/TextDocumentReaderTest.java` | 文本文档读取 | 1 |
| `core/rag/reranker/DashscopeRerankerTest.java` | DashScope 重排序 | 4 |
| `core/rag/indices/KnowledgeBaseIndexPipelineTest.java` | 知识库索引管道（解析/分块/存储） | 3 |
| `core/rag/splitter/TextSplitterTest.java` | 文本分块 | 2 |

**特点：** 只覆盖了工具类和 RAG 组件的部分逻辑，不涉及任何 Controller、Service、拦截器、MQ 消费者或工作流执行器。

---

## 3. Controller 测试覆盖

共 32 个 Controller，**0 个有对应测试**。

| 模块 | Controller | 对应核心链路 | 有测试 |
|---|---|---|---|
| server-start (builder) | `AuthController` | #1 登录认证 | 否 |
| server-start (builder) | `AccountController` | #1 登录认证 | 否 |
| server-start (admin) | `PromptController` | #2 Prompt 调试 | 否 |
| server-start (admin) | `ExperimentController` | #3 实验评测 | 否 |
| server-start (admin) | `EvaluatorController` | #3 实验评测 | 否 |
| server-start (admin) | `DatasetController` | #3 实验评测 | 否 |
| server-start (builder) | `DocumentController` | #4 文档索引 | 否 |
| server-start (builder) | `KnowledgeBaseController` | #4 文档索引、#8 RAG 检索 | 否 |
| server-start (builder) | `WorkflowController` | #5 工作流调试 | 否 |
| server-start (builder) | `AppController` | #5 #6 应用管理 | 否 |
| server-start (builder) | `AppChatController` | #5 #6 应用对话 | 否 |
| server-openapi | `ChatController` | #6 OpenAPI 调用 | 否 |
| server-start (builder) | `PluginController` | #7 工具发布 | 否 |
| server-start (builder) | `ToolController` | #7 工具发布 | 否 |
| server-start (builder) | `ApiKeyController` | #6 API Key 管理 | 否 |
| server-start (builder) | `ModelController` | 模型管理 | 否 |
| server-start (builder) | `ProviderController` | 模型 Provider | 否 |
| server-start (admin) | `ModelConfigController` | 模型配置 | 否 |
| server-start (builder) | `WorkspaceController` | 工作空间 | 否 |
| server-start (builder) | `Oauth2Controller` | OAuth2 | 否 |
| server-start (builder) | `AgentSchemaController` | Agent Schema | 否 |
| server-start (builder) | `AppComponentController` | 应用组件 | 否 |
| server-start (builder) | `DocumentChunkController` | 文档分块 | 否 |
| server-start (builder) | `McpServerController` | MCP Server | 否 |
| server-start (builder) | `SystemController` | 系统配置 | 否 |
| server-start (builder) | `FileController` | 文件上传 | 否 |
| server-start (builder) | `ApiExampleController` | API 示例 | 否 |
| server-start (admin) | `ObservabilityController` | 可观测性 | 否 |
| server-start (generator) | `GeneratorController` | 代码生成 | 否 |
| server-start (generator) | `ApplicationController` | 代码生成应用 | 否 |
| server-start (generator) | `DSLController` | DSL | 否 |
| server-start (generator) | `RunnerController` | 代码运行 | 否 |

---

## 4. Service 测试覆盖

### server-core 模块（17 个 ServiceImpl）

| ServiceImpl | 对应核心链路 | 有测试 |
|---|---|---|
| `AccountServiceImpl` | #1 登录认证 | 否 |
| `PluginServiceImpl` | #7 工具发布与执行 | 否 |
| `ToolServiceImpl` | #7 工具发布与执行 | 否 |
| `ToolExecutionServiceImpl` | #7 工具执行（HTTP 调用） | 否 |
| `WorkflowServiceImpl` | #5 工作流、#6 OpenAPI | 否 |
| `AgentServiceImpl` | #6 OpenAPI Agent 组装 | 否 |
| `AgentSchemaServiceImpl` | Agent Schema | 否 |
| `ApiKeyServiceImpl` | #6 API Key 校验 | 否 |
| `AppServiceImpl` | 应用管理 | 否 |
| `AppComponentServiceImpl` | 应用组件 | 否 |
| `McpServerServiceImpl` | MCP Server | 否 |
| `WorkspaceServiceImpl` | 工作空间 | 否 |
| `ReferServiceImpl` | 引用管理 | 否 |
| `GitHubOAuth2ServiceImpl` | OAuth2 | 否 |
| `KnowledgeBaseServiceImpl` | #4 文档索引、#8 RAG 检索 | 否 |
| `DocumentServiceImpl` | #4 文档索引 | 否 |
| `ElasticSearchVectorStoreService` | #4 #8 向量存储 | 否 |

### server-start 模块（16 个 ServiceImpl）

| ServiceImpl | 对应核心链路 | 有测试 |
|---|---|---|
| `ExperimentServiceImpl` | #3 实验评测 | 否 |
| `PromptRunServiceImpl` | #2 Prompt 调试 | 否 |
| `EvaluatorServiceImpl` | #3 评估器打分 | 否 |
| `ChatSessionServiceImpl` | #2 会话管理 | 否 |
| `PromptServiceImpl` | Prompt 管理 | 否 |
| `PromptVersionServiceImpl` | Prompt 版本 | 否 |
| `DatasetServiceImpl` | 数据集管理 | 否 |
| `DatasetVersionServiceImpl` | 数据集版本 | 否 |
| `DatasetItemServiceImpl` | 数据集条目 | 否 |
| `ModelConfigServiceImpl` | 模型配置 | 否 |
| `ModelConfigBridgeServiceImpl` | 模型配置桥接 | 否 |
| `NacosClientService` | Nacos 配置 | 否 |
| `TracingServiceImpl` | 链路追踪 | 否 |
| `EvaluatorVersionServiceImpl` | 评估器版本 | 否 |
| `EvaluatorTemplateServiceImpl` | 评估器模板 | 否 |
| `PromptTemplateServiceImpl` | Prompt 模板 | 否 |

---

## 5. 核心链路测试覆盖对照

对照 [docs/critical-paths.md](critical-paths.md) 中的 8 条核心链路：

| # | 核心链路 | 涉及的关键类 | 当前测试覆盖 | 说明 |
|---|---|---|---|---|
| 1 | **登录认证** | `AuthController`、`AccountServiceImpl`、`TokenManager`、`TokenAuthInterceptor` | **部分** | `PasswordCryptTest` 覆盖了密码校验的底层工具（encode/match），但登录流程、Redis token 存储、refresh-token 换发、logout 失效均无测试 |
| 2 | **Prompt 调试运行** | `PromptController`、`PromptRunServiceImpl`、`ChatSessionServiceImpl` | **没有** | 无任何测试。流式输出、会话管理、模板渲染、Mock 工具均未覆盖 |
| 3 | **实验执行评测** | `ExperimentController`、`ExperimentServiceImpl`、`EvaluatorServiceImpl`、`DatasetVersionServiceImpl` | **没有** | 无任何测试。异步执行、LLM-as-Judge 打分、进度更新、状态流转均未覆盖 |
| 4 | **知识库文档索引** | `DocumentController`、`DocumentServiceImpl`、`DocumentIndexHandler`、`ElasticSearchVectorStoreService` | **部分** | `KnowledgeBaseIndexPipelineTest` 覆盖了文档解析/分块/存储三个步骤，`TextSplitterTest` 覆盖了分块逻辑。但 MQ 发送/消费、状态流转、VectorStore 集成均无测试 |
| 5 | **应用工作流调试** | `WorkflowController`、`WorkflowExecuteManager`、各 `ExecuteProcessor`、`WorkflowInnerService` | **没有** | 无任何测试。DAG 构建、节点调度、断点暂停/恢复、子图调试均未覆盖 |
| 6 | **OpenAPI 外部调用** | `ChatController`(openapi)、`ApiKeyServiceImpl`、`WorkflowServiceImpl`、`AgentServiceImpl`、`BasicAgentExecutor` | **没有** | 无任何测试。API Key 校验、Agent 组装、工具调用循环均未覆盖 |
| 7 | **工具发布与执行** | `PluginController`、`PluginServiceImpl`、`ToolServiceImpl`、`ToolExecutionServiceImpl` | **没有** | 无任何测试。OpenAPI 解析、HTTP 调用执行、发布状态流转均未覆盖 |
| 8 | **Agent RAG 检索增强** | `KnowledgeBaseController`、`KnowledgeBaseDocumentRetriever`、`KnowledgeBaseRetrievalAdvisor`、`DashscopeReranker` | **部分** | `DashscopeRerankerTest` 覆盖了重排序逻辑，`KnowledgeBaseIndexPipelineTest` 覆盖了索引构建。但多知识库并行检索、混合搜索、Advisor 注入、阈值过滤均无测试 |

### 汇总

| 覆盖状态 | 链路数 | 链路 |
|---|---|---|
| 有测试 | 0 | — |
| 部分覆盖 | 3 | #1 登录认证（密码工具）、#4 文档索引（分块管道）、#8 RAG 检索（Rerank） |
| 完全没有 | 5 | #2 Prompt 调试、#3 实验评测、#5 工作流调试、#6 OpenAPI 调用、#7 工具发布 |

---

## 6. 补测优先级建议

基于核心链路的风险和当前覆盖缺口，建议按以下优先级补测试：

| 优先级 | 目标 | 理由 |
|---|---|---|
| P0 | **#5 工作流 DAG 执行框架** | 最复杂的无测试链路。纯逻辑可脱离外部依赖测：DAG 构建、拓扑排序、节点调度、上下文传递 |
| P0 | **#1 登录认证流程** | 安全敏感。补：token 存储/校验/刷新/失效的 Redis 交互 |
| P1 | **#3 实验评测核心逻辑** | 异步执行+状态流转容易出 bug。补：promptEvaluation 循环、打分 JSON 解析、progress 计算 |
| P1 | **#7 工具执行 HTTP 调用** | 纯 HTTP 拼接逻辑，易于 mock。补：URL 拼接、认证注入、参数分发 |
| P2 | **#2 Prompt 模板渲染+会话** | 补：变量替换、会话 TTL 管理 |
| P2 | **#6 API Key 校验** | 安全敏感但逻辑简单。补：过期/禁用/无效 Key 的拦截 |
