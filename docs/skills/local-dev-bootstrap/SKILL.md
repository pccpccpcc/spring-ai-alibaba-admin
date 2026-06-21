---
name: local-dev-bootstrap
description: 新接手 spring-ai-alibaba-admin 项目、重置本地环境或定期验证环境健康时使用；按依赖盘点、装中间件、启停脚本、编译启动、接口冒烟的顺序拉起并验证本地开发环境。
allowed-tools: Read, Bash, Write
---

# 本地开发环境 Bootstrap

当用户要“新接手项目”“重置环境”“检查本地环境健康”“把中间件和服务拉起来”“跑一轮冒烟”时使用这个 skill。目标是用项目内脚本完成可重复启动和验证，默认保护本地数据。

## 工作原则

- 优先读取项目脚本和文档，不凭记忆假设端口、profile 或服务目录。
- 优先使用已有脚本：`scripts/install-deps.sh`、`scripts/deps-start.sh`、`scripts/deps-stop.sh`、`scripts/deps-status.sh`、`scripts/admin-start.sh`、`start.sh`。
- 默认不删除数据库、volume、`.local/` 数据目录或用户配置；只有用户明确要求“清空/重置数据”时才执行破坏性操作。
- 端口冲突时先识别进程归属；如果不是本项目进程，只报告 PID 和命令，不擅自 kill。
- 启动后必须做健康检查、核心接口冒烟和功能入口检查，不能只看进程存在。

## 流程

### 1. 依赖盘点

先确认项目根目录和关键文件：

```bash
pwd
ls
ls scripts docs docker
```

检查基础依赖和版本：

```bash
java -version
mvn -version
docker --version
curl --version
```

再读取启动脚本，确认当前项目真实命令：

```bash
sed -n '1,220p' start.sh
sed -n '1,260p' scripts/admin-start.sh
sed -n '1,260p' scripts/deps-start.sh
sed -n '1,220p' scripts/deps-status.sh
```

本项目常见依赖和端口：

- Admin 服务：`8081`，管理页 `http://localhost:8081/admin`，健康检查 `http://localhost:8081/actuator/health`。
- MySQL：`3306`。
- Redis：`6379`。
- Elasticsearch：`9200`。
- Kibana：`5601`。
- Nacos：`8848`。
- RocketMQ：`9876`、`10911`、`18080`。
- LoongCollector / OTLP：`4318`。

### 2. 装中间件

如果是新机器或依赖缺失，先安装依赖：

```bash
scripts/install-deps.sh
```

安装脚本会准备 `.local/` 下的中间件运行环境。不要手动改写 `.local/` 内生成文件，除非是在修复项目脚本中的生成逻辑。

### 3. 启停脚本

启动中间件：

```bash
scripts/deps-start.sh
```

查看状态：

```bash
scripts/deps-status.sh
```

停止中间件：

```bash
scripts/deps-stop.sh
```

如果 RocketMQ、Elasticsearch、Nacos 等服务失败，先看对应日志和脚本配置，再改项目脚本。已知 RocketMQ Proxy 需要使用 `CLUSTER` 模式并显式配置 `namesrvAddr`。

### 4. 编译启动

默认全量启动：

```bash
./start.sh
```

`./start.sh` 会自动启动中间件、构建完整前端资源、同步后端 static、打包后端并等待健康检查。不要再要求用户手动分别执行 Docker Compose、前端 build 和 `mvn spring-boot:run`，除非是在排障。

只启动 Admin 服务，跳过中间件：

```bash
./start.sh --skip-deps
```

重启服务：

```bash
./start.sh --restart
```

需要重新编译时：

```bash
./start.sh --build
```

指定端口：

```bash
./start.sh --port 8081
```

启动后检查：

```bash
curl -fsS http://localhost:8081/actuator/health
curl -I http://localhost:8081/admin
```

登录后必须确认侧边栏包含 Prompt、评测、应用 / 工作流编排、知识库、可观测、设置 / 模型服务。如果只看到 Prompt、评测、可观测，通常是旧静态资源，执行：

```bash
./start.sh --build --restart
```

### 5. 接口冒烟

优先参考 `docs/api-list.md` 和已有 `docs/smoke-test-result.md`，覆盖登录、Prompt、Dataset、Evaluator、Trace 五类核心能力。推荐先登录拿 token：

```bash
TOKEN=$(curl -fsS -X POST http://localhost:8081/console/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"saa","password":"123456"}' | jq -r '.data.access_token // .data.accessToken // .data.token // .token')
```

核心接口示例：

```bash
curl -fsS -H "Authorization: Bearer $TOKEN" http://localhost:8081/api/prompts
curl -fsS -H "Authorization: Bearer $TOKEN" http://localhost:8081/api/dataset/datasets
curl -fsS -H "Authorization: Bearer $TOKEN" http://localhost:8081/api/evaluator/evaluators
curl -fsS -H "Authorization: Bearer $TOKEN" 'http://localhost:8081/api/observability/traces?current=1&pageSize=10&startTime=2026-01-01T00:00:00.000Z&endTime=2026-12-31T23:59:59.999Z'
```

冒烟标准：

- HTTP 200 算通过。
- 非 200、连接失败、认证失败、超时都列为失败。
- 记录失败接口、状态码、响应摘要和下一步排障方向。
- 用户要求产出报告时，写入 `docs/smoke-test-result.md`。

## 常见问题

- `localhost:8081/admin` 访问不了：先查 Admin 服务是否启动，再查 `/actuator/health` 和端口占用。
- 中间件未就绪：运行 `scripts/deps-status.sh`，逐项看 MySQL、Redis、Nacos、Elasticsearch、RocketMQ。
- RocketMQ Proxy 启动失败：检查生成配置里是否有 `proxyMode: CLUSTER` 和 `namesrvAddr: localhost:9876`。
- Trace 查询报 `all shards failed`：检查 Elasticsearch `loongsuite_traces` mapping、default pipeline、`metadata.start` 字段和旧数据迁移。
- 冒烟登录失败：确认账号 `saa/123456` 是否仍可用，或读取项目初始化 SQL 查默认账号。
- 应用 / 工作流编排、知识库菜单缺失：先强制刷新浏览器；仍缺失则运行 `./start.sh --build --restart`，确认 `spring-ai-alibaba-admin-server-start/src/main/resources/static/umi.js` 中包含 `p__Knowledge` 和 `p__App__Workflow`。
- 知识库创建缺少可选模型：进入模型服务管理，确认目标模型的 `type` 是 `text_embedding`，不是只在 tags 里勾了 embedding；Rerank 可不选。

## 收尾回复

最终回复用户时说明：

- 使用了哪些脚本。
- 中间件和 Admin 服务是否启动成功。
- 管理页、健康检查和核心接口冒烟结果。
- 修改过哪些文件。
- 仍存在的失败项和最短下一步排查命令。
