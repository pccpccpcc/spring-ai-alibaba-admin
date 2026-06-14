# 本地依赖安装提示词

> 触发场景：需要从头搭建本地开发环境，或在空机器上安装全部运行依赖。

## 输入

读取 `docs/env-checklist.md`，获取全部必需/可选依赖的版本、端口、连接信息和初始化要求。

## 输出

1. `scripts/install-deps.sh` — 一键安装脚本
2. 执行脚本
3. `scripts/install-log.md` — 安装日志

## 脚本要求

- **操作系统适配**：自动识别 macOS / Linux，用 brew 或 apt 安装中间件。
- **幂等性**：重复执行不报错、不重复初始化。已存在的跳过，已运行的跳过启动。
- **每个中间件的初始化**：
  - MySQL：建库 `admin`，建用户 `admin/admin`，导入 `docker/middleware/init/mysql/*.sql`。
  - Elasticsearch：创建 `parsing_loongsuite_traces` ingest pipeline 和 `loongsuite_traces` 索引。
  - RocketMQ：创建 `topic_saa_studio_document_index` 和 `group_saa_studio_document_index`。
  - Nacos：配置 `application.properties` 中的 `token.secret.key`（Nacos 3.x 要求合法 Base64 编码，原始字符串 >= 32 字符）和 `server.identity`。
  - Redis / Kibana：无需额外初始化。
- **不会自动安装的依赖**：写清楚下载链接、放到哪个目录、后续命令。不要阻塞整条安装链路。
- **macOS 服务托管**：用 LaunchAgent 管理需要常驻的进程（ES、Kibana、Nacos、RocketMQ），开机自启、崩溃重启。注意 Nacos 的 `startup.sh` 会 fork 后台进程导致 LaunchAgent 不断重启，需要直接 `exec java`。
- **环境变量提示**：脚本末尾输出全部 `SPRING_*` / `NACOS_*` / `ROCKETMQ_*` 环境变量。
- **最终校验**：脚本末尾逐个检查每个服务的端口和连接，输出汇总表。
- **控制变量**：通过环境变量控制跳过行为（`SKIP_ELASTICSEARCH`、`SKIP_NACOS`、`INSTALL_OPTIONAL_KIBANA`、`START_SERVICES` 等）。
- **敏感信息**：支持 `scripts/install-deps.local.env` 文件传入 MySQL root 密码等，不提交到仓库。

## 下载优化

- 自动检测 `~/Downloads/` 下是否有已手动下载的文件，有则复制到 `.local/downloads/`。
- 对 GitHub 等国内不可达的下载源，尝试 ghproxy 镜像等替代源。
- 大文件下载不阻塞安装链路，记录下载地址后继续。

## 执行过程

生成完直接执行脚本。执行过程遵循自主修复原则：

1. 任何一步失败，先看报错信息。
2. 自己判断原因（版本不对、源问题、权限问题、依赖缺失）。
3. 自己修（换源、换版本、加 sudo、装前置依赖）。
4. 修完重试，跑通为止。
5. 不要每个错误都问用户。
6. 如果同一个错误连续修 3 次还不行，停下来汇报具体卡在哪。

## 安装日志

`scripts/install-log.md` 需要记录：

- 每个中间件最终用了什么命令装上。
- 过程中遇到什么问题、怎么修的。
- 最终每个服务的端口和状态。
- macOS LaunchAgent 服务列表和常用管理命令。
- 应用连接环境变量。
