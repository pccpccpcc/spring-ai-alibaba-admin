# P0 补测试计划

生成日期：2026-06-12

依据：

- P0 缺口来源：[test-gaps.md](test-gaps.md)
- 排序原则：改造路径上的 Characterization Test 优先，其次核心链路集成测试，最后复杂逻辑单元测试。

口径：

- 只纳入 P0 缺口。
- 每批 1-3 个测试目标，默认 1 个，便于独立认领和验收。
- 简单 CRUD 不进计划；保留的是核心链路、跨组件交互或复杂逻辑兜底。
- 预期工作量为粗估，包含测试数据准备、mock / stub、断言和本地验证。

## 批次计划

| 批次 | 测试类型 | 覆盖的核心链路 | 对应 P0 缺口 | 预期工作量 |
|---:|---|---|---|---|
| 1 | Characterization Test | Prompt 调试运行 | `POST /api/prompt/run` 模板变量替换、model_config 加载、NDJSON / Flux 流式事件返回 | 1 天 |
| 2 | Characterization Test | Prompt 调试运行 | 同一 session 多轮运行，第二轮携带第一轮 user / assistant 历史，session 查询可见多轮消息 | 1 天 |
| 3 | Characterization Test | 应用工作流调试 / OpenAPI Workflow | 最小 DAG `Start -> LLM -> End` 通过控制台调试入口和 OpenAPI Workflow 入口复用执行引擎完成 | 1.5-2 天 |
| 4 | Characterization Test | Agent 工具调用 | 已发布工具被 AgentConfig 组装、注册 ToolCallback，并完成 `LLM -> 工具调用 -> LLM` 闭环 | 1.5-2 天 |
| 5 | Characterization Test | Agent RAG 检索增强 | Agent 对话触发 `KnowledgeBaseRetrievalAdvisor.before()`，检索结果注入 `{documents}`，stream / non-stream 生效 | 1 天 |
| 6 | 集成测试 | 登录认证 | login 正确凭证返回 token；错误密码 / 不存在用户返回 401 且不写 Redis token | 1 天 |
| 7 | 集成测试 | 登录认证 | 有效 access_token 可访问 `/console/v1/**`；Redis token 缺失或过期返回 401 | 0.5-1 天 |
| 8 | 集成测试 | 登录认证 | refresh-token 换发新 access_token，新 token 可访问认证接口；失效 refresh_token 返回 401 | 0.5-1 天 |
| 9 | 集成测试 | 登录认证 | logout 后原 access_token 立即失效，再访问认证接口返回 401 | 0.5 天 |
| 10 | 集成测试 | 实验执行评测 | 创建实验后异步解析实验配置、数据集和评估器，并按 item × evaluator 写入 `experiment_result` | 1.5-2 天 |
| 11 | 集成测试 | 实验执行评测 | 实验完成后状态为 COMPLETED、progress=100，结果接口返回按评估器聚合的平均分 | 1 天 |
| 12 | 集成测试 | 知识库文档索引 | 上传文档后保存文件、创建 `document`、写入文件路径并发送 RocketMQ 索引消息 | 1-1.5 天 |
| 13 | 集成测试 | 知识库文档索引 | `DocumentIndexHandler` 消费消息，推进 PROCESSING，并写入 chunks / VectorStore，最终 PROCESSED / FAILED | 1.5-2 天 |
| 14 | 集成测试 | 应用工作流调试 | Input 节点 PAUSE，`resume-task` 写入用户输入后继续到 End，`get-task-process` 读取 Redis 进度 | 1-1.5 天 |
| 15 | 集成测试 | OpenAPI 外部调用 | `/api/v1/apps/chat/completions` API Key 认证：有效通过，禁用 / 过期 / 错误拒绝，且不受 JWT 影响 | 1 天 |
| 16 | 单元测试 | 工具发布与执行 | 导入 OpenAPI YAML / JSON 后解析端点，生成 DRAFT tool config 和原始 `api_schema` | 1 天 |
| 17 | 单元测试 | 工具发布与执行 | 工具 test 拼接 URL、注入认证、分发 Header / Query / Path / Body 参数，并更新 test_status | 1-1.5 天 |
| 18 | 单元测试 | Agent RAG 检索增强 | 手动 retrieve 多知识库结果合并排序、similarityThreshold 过滤、topK 截取，可选 rerank 调用条件 | 1-1.5 天 |

## 执行建议

- 先跑通批次 1-5，用 Characterization Test 锁住改造最容易改变的现有行为。
- 批次 6-15 建议用薄集成测试优先覆盖接口到关键依赖的主链路，不追求全环境真实外部服务。
- 批次 16-18 放在最后做复杂逻辑单元测试，优先 mock 外部 HTTP、VectorStore、Rerank Provider。

## 中间件依赖与本地执行约定

- 涉及中间件（MySQL / Redis / RocketMQ）的集成测试**不使用 Testcontainers，也不 mock**，
  全部连接本地真实环境：执行前先 `scripts/deps-start.sh` 拉起中间件，并用 `scripts/deps-status.sh` 确认就绪。
- 基类 `RealMiddlewareSpringBootTest` 通过 `@DynamicPropertySource` 指向：
  - MySQL：独立库 `admin_test`（与业务库 `admin` 隔离，测试可自由 DROP/CREATE 表），默认 `localhost:3306`，账号 `admin/admin`。
  - Redis：默认 `localhost:6379`，使用 **db 1**（与控制台默认 db 0 隔离，避免污染真实 token）。
  - RocketMQ：默认 endpoint `localhost:18080`，复用本地 `topic_saa_studio_document_index` 主题与 `group_saa_studio_document_index` 消费组。
- 首次运行前需在本地 MySQL 创建 `admin_test` 库并授权（用 root 执行）：

  ```sql
  CREATE DATABASE IF NOT EXISTS admin_test DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  GRANT ALL PRIVILEGES ON admin_test.* TO 'admin'@'%';
  GRANT ALL PRIVILEGES ON admin_test.* TO 'admin'@'localhost';
  FLUSH PRIVILEGES;
  ```

- 连接参数可通过环境变量覆盖：`TEST_MYSQL_HOST/PORT/DATABASE/USER/PASSWORD`、`TEST_REDIS_HOST/PORT`、`TEST_ROCKETMQ_ENDPOINTS`。
- 运行：`JAVA_HOME=<JDK17+> mvn -pl spring-ai-alibaba-admin-server-start -am test`（core 模块为纯单元测试，无需中间件）。

> 完整的测试运行步骤、按模块运行、IDE 运行、常见踩坑见 [testing-guide.md](testing-guide.md)。
