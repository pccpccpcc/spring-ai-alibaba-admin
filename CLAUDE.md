# CLAUDE.md

## 项目定位

Spring AI Alibaba Admin 是一个基于 Spring AI Alibaba 的 AI Agent 开发、调试、评估与可观测平台。它覆盖 Prompt 管理、数据集管理、评估器与实验、应用 / 工作流编排、知识库、模型 Provider、插件工具、MCP Server、OpenAPI 调用等能力。

本仓库当前是 Spring AI Alibaba Admin 的独立工程形态；README 中说明源码已迁移到 `alibaba/spring-ai-alibaba` 主仓，改动时要留意上游同步关系。

详细资料入口：

- 架构图：[docs/architecture.svg](docs/architecture.svg)
- 内部模块依赖图：[docs/module-deps.svg](docs/module-deps.svg)
- 外部依赖图：[docs/external-dependencies.svg](docs/external-dependencies.svg)
- REST 接口清单：[docs/api-list.md](docs/api-list.md)
- 数据模型与数据字典：[docs/data-model.md](docs/data-model.md)
- 数据模型 ER 图：[docs/data-model-er.svg](docs/data-model-er.svg)

## 事实来源优先级

- 接口事实：优先看 Controller / OpenAPI 接口定义；[docs/api-list.md](docs/api-list.md) 是整理后的接口索引。
- 数据模型事实：优先看 `docker/middleware/init/mysql/*.sql`；其次看 Entity / DO / Mapper；[docs/data-model.md](docs/data-model.md) 是整理后的数据字典。
- 运行方式事实：优先看 `start.sh`、`scripts/admin-start.sh`、`scripts/deps-start.sh`、`scripts/deps-status.sh`、`README*.md` 和 [docs/setup-guide.md](docs/setup-guide.md)。
- 架构关系事实：优先看 Maven 模块、包结构、配置文件和 [docs/module-deps.svg](docs/module-deps.svg)。
- 概念解释：可以参考 `docs/qa/`，但不要把它当作代码事实来源。

## 核心架构

后端是 Maven 多模块 Spring Boot 3 / Java 17 项目：

- `spring-ai-alibaba-admin-server-start`：启动模块，承载 Controller、配置、JPA/MyBatis Mapper、静态前端资源、Graph Studio 代码生成等入口能力。
- `spring-ai-alibaba-admin-server-core`：核心业务实现，包含实体、Manager、RAG、Workflow 执行器、模型调用、工具执行等。
- `spring-ai-alibaba-admin-server-runtime`：运行时领域对象、请求响应 DTO、枚举、通用协议模型。
- `spring-ai-alibaba-admin-server-openapi`：对外 OpenAPI / Chat / Workflow 调用相关能力。

前端在 `frontend/`，是 npm workspace，主要包包括：

- `frontend/packages/main`：主控制台应用。
- `frontend/packages/spark-flow`：工作流 / 图编排相关前端能力。

中间件和部署：

- 本地 Docker Compose 在 `docker/middleware/`，包含 MySQL、Elasticsearch、Redis、Nacos、RocketMQ、Kibana、LoongCollector 等。
- Kubernetes 部署资源在 `deploy/`。
- MySQL 初始化 SQL 在 `docker/middleware/init/mysql/`，当前数据字典以这里的 SQL 为主要事实来源。

## 关键模块

- 账号与认证：登录、Token 刷新、账号 CRUD、OAuth2、API Key 管理。
- Prompt / 数据集 / 评估器 / 实验：Studio 评测链路，支持 Prompt 版本、数据集版本、评估器版本和实验结果分析。
- 应用与工作流：应用 CRUD、版本发布、控制台对话、工作流调试、Graph Studio 代码生成。
- 知识库与文档：知识库、文档、分块、检索、文件上传和索引处理。
- 模型体系：控制台 Provider / Model 管理，以及 Studio 侧 `model_config`。
- 工具体系：插件、工具实体、MCP Server、组件服务是不同抽象，不要强行合并概念。
- OpenAPI 调用：面向外部调用方的 Chat / Workflow 能力，API Key 是外部调用凭证，不是普通登录 Token。

接口细节以 [docs/api-list.md](docs/api-list.md) 为准；数据表和关系以 [docs/data-model.md](docs/data-model.md) 为准。

## 关键约定

- Java 版本：17（构建/运行需 JDK 17+，推荐 21）。
- **执行任何 `mvn` / `java` 命令前，必须先确认 `JAVA_HOME` 指向 JDK 17+**。本机默认 shell 的 `JAVA_HOME` 经常是 Java 8（被 jenv 或系统默认接管），用它构建会报 `UnsupportedClassVersionError: ... class file version 61.0` 或 `spring-boot-maven-plugin` 的 `repackage` 失败。修复方式：
  ```bash
  export JAVA_HOME=$(/usr/libexec/java_home -v 21)
  export PATH="$JAVA_HOME/bin:$PATH"
  java -version   # 确认是 17 或 21，再继续
  ```
  这条对 `mvn test`、`mvn install`、`./start.sh`、`scripts/admin-start.sh` 都适用；不确定时先 `java -version` 自检，不要假设默认环境是对的。
- 后端框架：Spring Boot 3.3.x、Spring AI、Spring AI Alibaba。
- 数据访问同时存在 MyBatis-Plus、MyBatis XML Mapper、JPA，改动时先看所在模块既有风格。
- 数据关系要区分 SQL 显式 FK 和业务逻辑 FK。很多核心关系通过 `workspace_id`、`app_id`、`plugin_id`、`kb_id` 等业务 ID 关联，但 SQL 没有外键约束。
- 文档更新不要把大段接口清单、数据字典、SVG 内容复制到入口文档；入口文档只保留链接和摘要。
- `docs/prompt/` 是可复用 prompt 模板目录；`docs/qa.md` 是概念问答，不作为架构事实主入口。
- 生成或修改图表时，优先保证可读性。复杂图不要直接接受默认 Mermaid ER 输出，必要时使用自定义 SVG，并检查卡片重叠、字段裁剪、箭头遮挡。
- 已存在未跟踪文档资产时，不要误删或重置；本仓库可能处在文档梳理中的脏工作区。

## 文档同步约定

- 改 REST Controller、OpenAPI 接口、DTO 入参或返回结构时，同步检查 [docs/api-list.md](docs/api-list.md)。
- 改 SQL、Entity、DO、Mapper XML 或核心枚举时，同步检查 [docs/data-model.md](docs/data-model.md) 和 [docs/data-model-er.svg](docs/data-model-er.svg)。
- 改 Maven 模块依赖、包边界或启动模块职责时，同步检查 [docs/module-deps.svg](docs/module-deps.svg) 和本文件的“核心架构”。
- 改中间件、外部 API、部署依赖或配置中心相关内容时，同步检查 [docs/external-dependencies.svg](docs/external-dependencies.svg) 和“怎么跑”。
- 新增长期有效的项目约定时，优先补充本文件；临时讨论、概念问答或一次性说明放到 `docs/qa/` 更合适。

## 怎么跑

环境要求：

- Java 17+（推荐 21）。**注意：默认 shell 的 `JAVA_HOME` 常被指向 Java 8，必须先 `export JAVA_HOME=$(/usr/libexec/java_home -v 21)` 再跑任何构建命令，详见“关键约定”。**
- Maven 3.8+
- Docker + Docker Compose 2.x
- Node.js 20.x+
- 可用的模型 Provider API Key，例如 OpenAI 兼容服务、DashScope、DeepSeek

标准启动入口：

```bash
./start.sh
```

`start.sh` 只是薄封装，实际调用 `scripts/admin-start.sh`。默认行为是：

- 运行 `scripts/deps-start.sh` 启动并校验 MySQL、Redis、Elasticsearch、Kibana、Nacos、RocketMQ、LoongCollector。
- 检查后端 `static` 中是否已有完整前端资源；缺失或传入 `--build` 时执行 `npm run build:flow` 和 `BACK_END=java npm run build:app`。
- 同步 `frontend/packages/main/dist` 到 `spring-ai-alibaba-admin-server-start/src/main/resources/static`。
- 打包 `spring-ai-alibaba-admin-server-start.jar` 并启动 Admin 服务。
- 等待 `http://localhost:8081/actuator/health` 返回 UP。

常用命令：

```bash
./start.sh --skip-deps --restart      # 中间件已就绪，只重启 Admin
./start.sh --build --restart          # 强制重建前端/后端并重启
./start.sh --foreground               # 前台启动看实时日志
scripts/deps-status.sh                # 查看中间件状态
scripts/deps-stop.sh                  # 停止中间件
```

访问：

- 管理界面：`http://localhost:8081/admin`
- 健康检查：`http://localhost:8081/actuator/health`
- 默认账号：`saa` / `123456`

启动后不仅要确认进程存在，还要确认功能完整性：登录后侧边栏应包含 Prompt、评测、应用 / 工作流编排、知识库、可观测、设置 / 模型服务等入口。如果应用 / 工作流编排或知识库缺失，优先强制刷新浏览器；仍缺失时执行 `./start.sh --build --restart` 重新构建并同步完整前端静态资源。

如需配置模型 Key，优先在管理界面“模型服务管理”中配置 OpenAI 兼容 Provider、API Key、endpoint 和模型类型。知识库至少需要 `text_embedding` 模型；`rerank` 可选。

前端构建：

```bash
cd frontend
npm install
npm run build:flow
BACK_END=java npm run build:app
```

Kubernetes 部署参考 [deploy/README.md](deploy/README.md)。注意 MySQL 初始化脚本 ConfigMap 需要在 MySQL 首次部署前创建。

## 常用检查命令

查看本地中间件容器状态：

```bash
scripts/deps-status.sh
```

启动 / 停止本地中间件：

```bash
scripts/deps-start.sh
scripts/deps-stop.sh
```

后端构建：

```bash
mvn clean install -DskipTests
```

后端测试：

```bash
mvn test
```

> 测试细节（分类、中间件约定、CI、踩坑）见 [docs/testing-guide.md](docs/testing-guide.md)。集成测试连接本地真实中间件（MySQL 的 `admin_test` 库 / Redis db 1 / RocketMQ），不使用 Testcontainers 或 mock。

前端构建：

```bash
cd frontend
npm install
npm run build:flow
BACK_END=java npm run build:app
```

重建后端内置前端资源：

```bash
./start.sh --build --restart
```

## CI（GitHub Actions）

CI 配置在 `.github/workflows/ci.yml`，`push`/`pull_request` 到 `main` 时自动跑 `mvn test`。CI 在干净 Ubuntu runner 上用 `docker/middleware/docker-compose.ci.yml` 起一套**真实**的 MySQL + Redis + RocketMQ（非 mock、非 Testcontainers），集成测试通过 `TEST_*` 环境变量连它们——和本地共用同一份测试代码。改中间件相关测试时，确保本地和 CI 两套连接参数都能跑通。RocketMQ 必须在 CI 真起：`DocumentServiceImpl` 构造期注入 `Producer`，context 启动即依赖 RocketMQ，无法只连 MySQL+Redis。

## 禁区

待补充。

## 历史包袱

待补充。
