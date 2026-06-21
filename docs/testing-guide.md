# 测试运行指南

本文档说明如何在本机跑通 Spring AI Alibaba Admin 的全部测试，包括纯单元测试和依赖中间件的集成测试。

> 测试计划与缺口背景见 [test-plan.md](test-plan.md)，历史测试现状见 [test-status.md](test-status.md)。

---

## 1. 前置条件

| 项 | 要求 | 检查命令 |
|---|---|---|
| JDK | **>= 17**，推荐 21 | `java -version` |
| Maven | 3.8+ | `mvn -version` |
| 本地中间件 | MySQL / Redis / RocketMQ 全部就绪（仅集成测试需要） | `scripts/deps-status.sh` |

> **关键：JDK 必须 >= 17。** 默认 shell 若指向 Java 8，构建会报 `UnsupportedClassVersionError: class file version 61.0`。macOS 切换方式：
> ```bash
> export JAVA_HOME=$(/usr/libexec/java_home -v 21)
> export PATH="$JAVA_HOME/bin:$PATH"
> ```

中间件首次安装参考 [setup-guide.md](setup-guide.md) 第 2 节。

---

## 2. 测试分类

| 模块 | 类型 | 是否依赖中间件 | 运行前提 |
|---|---|---|---|
| `spring-ai-alibaba-admin-server-core` | 纯单元 / mock 测试 | 否 | 仅需 JDK + Maven |
| `spring-ai-alibaba-admin-server-start` | 单元 + Spring Boot 集成测试 | **部分需要**（MySQL / Redis / RocketMQ） | 需本地中间件就绪 |

`server-start` 中**需要中间件**的集成测试统一继承基类 `RealMiddlewareSpringBootTest`，它们会连接本地真实 MySQL、Redis、RocketMQ，不使用 Testcontainers，也不 mock。其余测试（如 `AuthControllerTest`、`TokenAuthInterceptorTest`、`PromptRunServiceImplTest`）是纯 mock，不连任何中间件。

---

## 3. 一键运行全部测试

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export PATH="$JAVA_HOME/bin:$PATH"

# 确保 MySQL / Redis / RocketMQ 在跑
scripts/deps-status.sh

# 跑全部测试
mvn test
```

预期结果：约 33 个测试全部通过（core 21 + start 12），`BUILD SUCCESS`。

> 如果中间件没启动，`server-core` 的 21 个单元测试仍能跑通，但 `server-start` 的 5 个集成测试会因连不上 MySQL/RocketMQ 报错。

---

## 4. 中间件依赖约定（重要）

涉及中间件的集成测试通过 `RealMiddlewareSpringBootTest` 的 `@DynamicPropertySource` 连接本地真实环境，约定如下：

| 中间件 | 默认连接 | 隔离方式 |
|---|---|---|
| MySQL | `localhost:3306/admin_test`，账号 `admin/admin` | 用独立库 `admin_test`，**不碰业务库 `admin`**，测试可自由 DROP/CREATE 表 |
| Redis | `localhost:6379`，**db 1** | 用 db 1，与控制台默认 db 0 隔离，避免污染真实 token 缓存 |
| RocketMQ | endpoint `localhost:18080` | 复用本地 `topic_saa_studio_document_index` 主题与 `group_saa_studio_document_index` 消费组 |

### 4.1 首次运行：创建 `admin_test` 库

集成测试需要独立的 `admin_test` 数据库（默认 `admin` 用户没有建库权限），首次运行前用 root 创建并授权一次：

```bash
mysql -uroot -p<PASSWORD> <<'SQL'
CREATE DATABASE IF NOT EXISTS admin_test DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON admin_test.* TO 'admin'@'%';
GRANT ALL PRIVILEGES ON admin_test.* TO 'admin'@'localhost';
FLUSH PRIVILEGES;
SQL
```

root 密码取自 `scripts/install-deps.local.env`（已 gitignore）中的 `MYSQL_ROOT_PASSWORD`。建好之后持久生效，后续无需重复。

测试表由 `src/test/resources/schema-test.sql`（`spring.sql.init.mode=always`）在 `admin_test` 中自动创建，包含 `account`、`workspace`、`api_key` 三张表；集成测试的 `@BeforeEach` 会清空这三张表再写入测试数据。

### 4.2 通过环境变量覆盖连接参数

如果本地中间件端口或账号与默认不同，可在运行前设置环境变量：

| 环境变量 | 默认值 | 说明 |
|---|---|---|
| `TEST_MYSQL_HOST` | `localhost` | MySQL 主机 |
| `TEST_MYSQL_PORT` | `3306` | MySQL 端口 |
| `TEST_MYSQL_DATABASE` | `admin_test` | 测试库名 |
| `TEST_MYSQL_USER` | `admin` | MySQL 账号 |
| `TEST_MYSQL_PASSWORD` | `admin` | MySQL 密码 |
| `TEST_REDIS_HOST` | `localhost` | Redis 主机 |
| `TEST_REDIS_PORT` | `6379` | Redis 端口 |
| `TEST_ROCKETMQ_ENDPOINTS` | `localhost:18080` | RocketMQ Proxy endpoint |

### 4.3 特例：连 `admin` 业务库的测试（`@EnabledIfEnvironmentVariable`）

Prompt 版本对比的两个测试**不连 `admin_test`，而是连 `admin` 业务库**，并用 `@EnabledIfEnvironmentVariable(named="TEST_MYSQL_DATABASE", matches="admin")` 控制：仅在 `TEST_MYSQL_DATABASE=admin` 时执行，默认（`admin_test`）和 CI 会**自动跳过**（这就是 CI 里看到这两个测试 Skipped 的原因）。

连 `admin` 时通过 `@DynamicPropertySource` 设 `spring.sql.init.mode=never`，禁用 `schema-test.sql`，避免在业务库建/删测试表。

- `PromptVersionBaselineTest`：基线回归，固定改造链路上不变动老方法（`selectByPromptKey` / `selectByPromptKeyAndVersion` / `getByPromptKeyAndVersion`）对真实数据 `pcctest/1.0.0` 的返回，改造前后对比。
- `PromptVersionDiffIntegrationTest`：边界覆盖，用独立 `difftest` prompt 构造数据覆盖 12 个边界场景，`@BeforeEach` 插 / `@AfterEach` 清，不碰 `pcctest`。

本地运行（需中间件就绪 + `admin` 库有 `pcctest`）：

```bash
TEST_MYSQL_DATABASE=admin mvn test -pl spring-ai-alibaba-admin-server-start -am \
    -Dtest=PromptVersionBaselineTest,PromptVersionDiffIntegrationTest
```

---

## 5. 按模块运行

```bash
# 只跑 core 模块（纯单元测试，无需中间件）
mvn -pl spring-ai-alibaba-admin-server-core -am test

# 只跑 start 模块（含集成测试，需中间件就绪）
mvn -pl spring-ai-alibaba-admin-server-start -am test

# 跑单个测试类
mvn -pl spring-ai-alibaba-admin-server-start -am test \
  -Dtest=AuthSpringBootIntegrationTest

# 跳过所有测试快速构建
mvn clean install -DskipTests
```

> 注意：因为父 POM 使用 `${revision}` 占位符，单独运行某个子模块时**必须加 `-am`**（同时构建依赖模块），否则会报找不到 `spring-ai-alibaba-admin:pom:${revision}`。

---

## 6. 在 IDE 中运行

1. 确保项目用 **JDK 17+** 导入（IntelliJ：File → Project Structure → SDK）。
2. 集成测试需要本地中间件就绪；首次运行前按 4.1 创建好 `admin_test` 库。
3. 直接右键运行测试类或方法即可。`RealMiddlewareSpringBootTest` 的 `@DynamicPropertySource` 会自动注入本地中间件连接参数，无需手动配置 run configuration。

---

## 7. CI（GitHub Actions）

代码库托管在 GitHub，CI 使用 **GitHub Actions**，配置文件 [.github/workflows/ci.yml](../.github/workflows/ci.yml)。

### 7.1 触发时机

- `push` 到 `main`：自动跑。
- 对 `main` 的 `pull_request`：自动跑（PR 上直接显示 ✅/❌）。
- `workflow_dispatch`：可在 GitHub 仓库 Actions 页面手动点按钮重跑。

> 本地的 commit/分支**不会**触发 CI，必须 `git push` 到 GitHub 后才会跑。

### 7.2 CI 里怎么跑中间件测试

CI 在干净的 Ubuntu runner 上，用 [`docker/middleware/docker-compose.ci.yml`](../docker/middleware/docker-compose.ci.yml) 起一套**真实**的 MySQL + Redis + RocketMQ（不是 mock、不是 Testcontainers），集成测试连它们：

| 中间件 | CI 连接 | 说明 |
|---|---|---|
| MySQL | `127.0.0.1:3306/admin_test` | compose 里 `MYSQL_DATABASE=admin_test` 自动建库，账号 `admin/admin` |
| Redis | `127.0.0.1:6379` | CI 无并发，db 0 即可（CI 与本地隔离策略不同，都安全） |
| RocketMQ | `127.0.0.1:18080` | 一次性 `init-topic` 容器自旋等待 broker 就绪后建 topic 与消费组 |

连接参数通过 `TEST_*` 环境变量（第 4.2 节）切到 CI 容器，`RealMiddlewareSpringBootTest` 的 `@DynamicPropertySource` 自动读取。**同一份测试代码本地和 CI 都能跑**，本地无需任何改动。

### 7.3 为什么 CI 必须连 RocketMQ

`DocumentServiceImpl` 在构造期注入 RocketMQ `Producer`，`DocumentIndexHandler` 在 `@PostConstruct` 订阅消费——所以 Spring context 一启动就连 RocketMQ。要在 CI 真跑登录认证集成测试，RocketMQ 必须真实在线。这不是 mock，是真实中间件依赖。

### 7.4 本地复现 CI 行为

想在不 push 的情况下本地复现 CI 的中间件环境（例如排查 CI 失败），直接用 CI 编排起一套：

```bash
cd docker/middleware
docker compose -f docker-compose.ci.yml up -d mysql redis rmq_namesrv rmq_broker rmq_proxy
docker compose -f docker-compose.ci.yml run --rm init-topic   # 建 topic 与消费组

# 用 CI 的连接参数跑测试（端口与 CI 一致）
TEST_MYSQL_HOST=127.0.0.1 TEST_MYSQL_PORT=3306 TEST_MYSQL_DATABASE=admin_test \
TEST_MYSQL_USER=admin TEST_MYSQL_PASSWORD=admin \
TEST_REDIS_HOST=127.0.0.1 TEST_REDIS_PORT=6379 \
TEST_ROCKETMQ_ENDPOINTS=127.0.0.1:18080 \
mvn -pl spring-ai-alibaba-admin-server-start -am test

# 清理
docker compose -f docker-compose.ci.yml down -v
```

> 注意：CI 编排用的是本机原生中间件的默认端口（3306/6379/18080）。本机若已跑着原生中间件，两者会端口冲突——验证时要么先停原生中间件，要么临时改 compose 端口。

### 7.5 CI 失败排查

- **看 surefire 报告**：workflow 无论成功失败都会上传 `surefire-reports` artifact，在 Actions 页面下载查看。
- **中间件没起好**：RocketMQ broker 启动需要 ~60-90s，`init-topic` 会自旋等待；若超时多半是 runner 资源紧张，重跑一次通常就好。
- **Java 版本**：CI 用 `actions/setup-java` 装 JDK 21，不存在本地那种默认 Java 8 的问题。

### 7.6 首次推送 CI 的坑（fork 工作流）

上游 `spring-ai-alibaba/spring-ai-alibaba-admin` 已于 2026-01-11 **归档为只读**，无法直接 push、也无法接收 PR。本仓库的 CI 实际在**个人 fork** 上跑，下面是首次跑 CI 时踩过的坑：

1. **不能 push 到 origin**：`origin` 指向归档的上游，`git push` 会报 `This repository was archived ... read-only`。需要先在 GitHub 上 Fork 到自己账号，再添加 fork 为 remote：
   ```bash
   git remote add fork git@github.com:<你的账号>/spring-ai-alibaba-admin.git
   git push -u fork feature_cc_test
   ```

2. **fork 默认禁用 Actions**：新建的 fork 不会自动跑 workflow。进 fork 的 **Settings → Actions → General** → 选 "Allow all actions and reusable workflows" → Save。

3. **推 feature 分支不会自动触发 CI**：workflow 触发条件是 `push 到 main` 或 `PR 到 main`。单独推 `feature_cc_test` 分支**不会跑**。触发方式：
   - 在 fork 内开 PR（base `main` ← head `feature_cc_test`），`on: pull_request` 自动跑；
   - 或把分支合进 fork 的 `main` 再 push，`on: push` 自动跑；
   - `workflow_dispatch` 手动触发需 workflow 文件已在 `main` 上才出现按钮。

4. **开 PR 时 base repository 默认指向上游归档仓**：GitHub 的 PR 页面 base 默认是上游 `spring-ai-alibaba/...`，于是报 "This repository was archived ... read-only"，Create 按钮也点不了。解决：手动把 **base repository** 改成自己 fork `pccpccpcc/spring-ai-alibaba-admin`；或直接用锁定在 fork 内的对比链接：
   ```
   https://github.com/<你的账号>/spring-ai-alibaba-admin/compare/main...feature_cc_test
   ```
   （注意：是你的 fork 本身可写——Settings 底部 Danger Zone 显示 "Archive" 按钮就代表当前未归档；如果显示 "Unarchive" 才需要先取消归档。）

5. **git 身份未配置会无法 commit**：本仓库 `git config` 未设 user.name/email 时 `git commit` 报 `unable to auto-detect email address`。在仓库内设置（用 GitHub noreply 邮箱可不暴露真实邮箱并自动关联账号头像）：
   ```bash
   git config user.name "<名字>"
   git config user.email "<账号>@users.noreply.github.com"
   ```

---

## 8. 常见踩坑

### 8.1 默认 Java 是 8，构建直接失败

**现象**：`UnsupportedClassVersionError: ... class file version 61.0`，或 spring-boot-maven-plugin 的 `repackage` 报错。

**解决**：切换到 JDK 17+，见第 1 节。

### 8.2 集成测试报连不上 MySQL

**现象**：`Access denied`、`Unknown database 'admin_test'` 或 `Communications link failure`。

**排查**：

1. `scripts/deps-status.sh` 确认 MySQL `RUNNING`。
2. 确认已按 4.1 创建 `admin_test` 库并授权 `admin`。
3. 端口/账号非默认时，用 `TEST_MYSQL_*` 环境变量覆盖。

### 8.3 集成测试报 RocketMQ producer 启动失败

**现象**：`Expected the service ProducerImpl-0 [FAILED] to be RUNNING` / `UNAVAILABLE: io exception` / `Connection refused`。

**原因**：RocketMQ Proxy 没起，或端口不是 18080。

**解决**：`scripts/deps-start.sh` 拉起 RocketMQ；本地 Proxy 默认监听 `localhost:18080`，确认 `scripts/deps-status.sh` 显示 Proxy `RUNNING`。端口非默认时设置 `TEST_ROCKETMQ_ENDPOINTS`。

### 8.4 日志里出现 `ERROR ... login ... fail`

**这不是失败。** `AuthSpringBootIntegrationTest` 会故意触发认证失败路径（错密码 → 401、失效 refresh_token → 401、过期 access_token → 401），这些 ERROR 日志是预期输出。判断是否真正失败只看 Maven 末尾的 `Tests run: ..., Failures: 0, Errors: 0` 与 `BUILD SUCCESS`。

### 8.5 单模块测试报找不到 `${revision}`

**现象**：`Could not find artifact com.alibaba.cloud.ai:spring-ai-alibaba-admin:pom:${revision}`。

**解决**：在 reactor 根目录运行，且加 `-am`（见第 5 节）；或先执行一次 `mvn install -DskipTests` 把父 POM 和各模块装进本地仓库。

### 8.6 测试污染了真实业务库

**不会发生。** 集成测试强制连接 `admin_test` 库（不是 `admin`），Redis 用 db 1（不是控制台的 db 0）。如果你确实观察到 `admin` 库数据被改，检查是否有人把 `TEST_MYSQL_DATABASE` 误设成了 `admin`。

---

## 9. 测试清单速览

| 测试类 | 模块 | 类型 | 依赖中间件 | 对应 test-plan 批次 |
|---|---|---|---|---|
| `RSACryptTest` | core | 单元 | 否 | — |
| `PasswordCryptTest` | core | 单元 | 否 | — |
| `DateUtilsTests` | core | 单元 | 否 | — |
| `OpenApiUtilsTest` | core | 单元 | 否 | 16 |
| `BasicAgentExecutorTest` | core | 单元（mock） | 否 | 4 |
| `ToolExecutionServiceImplTest` | core | 单元（mock） | 否 | 17 |
| `WorkflowExecuteManagerTest` | core | 单元（mock） | 否 | 3 |
| `KnowledgeBaseRetrievalAdvisorTest` | core | 单元（mock） | 否 | 5 |
| `KnowledgeBaseDocumentRetrieverTest` | core | 单元（mock） | 否 | 18 |
| `KnowledgeBaseIndexPipelineTest` | core | 单元（mock） | 否 | 13 |
| `DashscopeRerankerTest` | core | 单元（mock） | 否 | 18 |
| `TextDocumentReaderTest` | core | 单元（mock） | 否 | — |
| `TextSplitterTest` | core | 单元（mock） | 否 | — |
| `PromptRunServiceImplTest` | start | 单元（mock） | 否 | 1、2 |
| `AuthControllerTest` | start | 单元（mock） | 否 | 6 |
| `TokenAuthInterceptorTest` | start | 单元（mock） | 否 | 7 |
| `SaaStudioAdminContextTest` | start | 集成 | **是** | — |
| `AuthSpringBootIntegrationTest` | start | 集成 | **是** | 6、7、8、9 |

> test-plan 中批次 3、10、11、12、14、15 尚未实现测试代码；本表仅列已存在的测试。

---

## 10. 相关文档

- [补测试计划](test-plan.md)
- [测试现状报告](test-status.md)
- [新人 Setup Guide](setup-guide.md)
- [环境依赖清单](env-checklist.md)
