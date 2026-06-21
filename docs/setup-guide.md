# 新人 Setup Guide

本文档帮助新人从零搭建 Spring AI Alibaba Admin 本地开发环境。

---

## 0. 标准启动路径

日常开发优先使用项目根目录的启动脚本，不需要手动分别启动前端、后端和中间件：

```bash
# 首次机器或中间件缺失
scripts/install-deps.sh

# 日常启动：中间件 + 完整前端静态资源 + 后端服务
./start.sh

# 中间件已经运行，只重启 Admin
./start.sh --skip-deps --restart

# 代码或前端菜单资源变化后，强制重建并重启
./start.sh --build --restart
```

启动成功后访问：

- 管理界面：`http://localhost:8081/admin`
- 健康检查：`http://localhost:8081/actuator/health`
- 默认账号：`saa` / `123456`

`./start.sh` 会调用 `scripts/admin-start.sh`，自动完成以下动作：

1. 运行 `scripts/deps-start.sh` 启动并校验 MySQL、Redis、Elasticsearch、Kibana、Nacos、RocketMQ、LoongCollector
2. 检查后端 `static` 中是否已有完整前端资源；缺失时自动执行 `npm run build:flow` 和 `BACK_END=java npm run build:app`
3. 将 `frontend/packages/main/dist` 同步到 `spring-ai-alibaba-admin-server-start/src/main/resources/static`
4. 打包 `spring-ai-alibaba-admin-server-start.jar`
5. 通过 macOS LaunchAgent 或后台进程启动 Admin，并等待 `/actuator/health` 通过

如果页面能打开但缺少“应用 / 工作流编排”“知识库”“MCP”“模型服务”等菜单，通常是旧静态资源或浏览器缓存：先强制刷新；仍不正常时执行 `./start.sh --build --restart`。

---

## 1. 前置条件

开始之前，确认你的机器上具备以下工具：

| 工具 | 版本要求 | 检查命令 | 说明 |
|---|---|---|---|
| Docker + Docker Compose | Docker 20+、Compose 2.x | `docker --version` && `docker compose version` | LoongCollector 容器运行需要 |
| JDK | **>= 17**，推荐 21 | `java -version` | 构建和运行后端 |
| Maven | 3.8+ | `mvn -version` | 后端构建 |
| Node.js | 20.x+ | `node -v` | 前端构建 |
| npm | 随 Node 安装 | `npm -v` | 前端包管理 |
| curl / nc | 系统自带或 brew 安装 | `curl --version` | 脚本内部健康检查 |

> **macOS 用户**：推荐使用 Homebrew 安装上述工具。Linux 用户脚本支持 apt-get 自动安装。

**可选但建议准备：**

- 一个可用的 AI 模型 API Key（DashScope / OpenAI / DeepSeek 等），用于 AI 对话功能。
- 磁盘剩余空间 > 10GB（中间件下载和解压占用）。

---

## 2. 一键安装中间件

项目提供了自动化脚本 `scripts/install-deps.sh`，会依次安装和启动所有依赖。

### 2.1 基本用法

```bash
# 一键安装所有依赖（首次使用推荐）
scripts/install-deps.sh
```

脚本会自动完成：

1. 检测操作系统和包管理器
2. 安装 curl、jq、unzip 等基础工具
3. 校验 JDK >= 17 和 Maven
4. 安装并启动 MySQL 8（创建 `admin` 库、导入 schema）
5. 安装并启动 Redis 7
6. 下载并启动 Elasticsearch 9.x（初始化 trace pipeline 和索引）
7. 下载并启动 Kibana 9.x（可选）
8. 下载并启动 Nacos 3.x
9. 下载并启动 RocketMQ 5.x（创建文档索引 topic 和 consumer group）
10. 通过 Docker 容器启动 LoongCollector 3.x

### 2.2 自定义配置

脚本支持通过环境变量和参数控制行为：

```bash
# 自定义 MySQL root 密码（如果你的 MySQL 已有密码）
MYSQL_ROOT_PASSWORD=你的密码 scripts/install-deps.sh

# 跳过某些步骤
SKIP_ELASTICSEARCH=1 scripts/install-deps.sh   # 跳过 ES（手动下载）
SKIP_NACOS=1 scripts/install-deps.sh           # 跳过 Nacos
INSTALL_OPTIONAL_KIBANA=0 scripts/install-deps.sh  # 不装 Kibana

# 强制 brew update
SKIP_BREW_UPDATE=0 scripts/install-deps.sh
```

敏感配置放在 `scripts/install-deps.local.env`（已 gitignore），格式：

```bash
MYSQL_ROOT_PASSWORD=你的密码
```

### 2.3 手动下载大文件

Elasticsearch（约 472MB）和 Kibana（约 245MB）下载可能较慢。脚本会自动检测 `~/Downloads/` 目录下已有的安装包，你可以手动下载后放到：

```
~/.local/downloads/
```

或直接放到 `~/Downloads/`，脚本会自动发现并复用。

---

## 3. 管理中间件

安装完成后，日常使用以下脚本管理中间件生命周期。

### 3.1 启动所有中间件

```bash
scripts/deps-start.sh

# 跳过某些服务
scripts/deps-start.sh --skip kibana,loongcollector
```

启动顺序：MySQL → Redis → Elasticsearch → Kibana → Nacos → RocketMQ → LoongCollector。

### 3.2 停止所有中间件

```bash
scripts/deps-stop.sh

# 跳过某些服务
scripts/deps-stop.sh --skip mysql,redis
```

### 3.3 查看中间件状态

```bash
scripts/deps-status.sh
```

输出示例：

```
  SERVICE          STATUS     PORT          DETAIL
  -------          ------     ----          ------
  MySQL            RUNNING    LISTENING     v8.0.35 @ localhost:3306
  Redis            RUNNING    LISTENING     localhost:6379 (PONG)
  Elasticsearch    RUNNING    LISTENING     v9.1.2 status=green @ localhost:9200
  Kibana           RUNNING    LISTENING     localhost:5601
  Nacos            RUNNING    LISTENING     localhost:8848
  RocketMQ         RUNNING
    NameServer     RUNNING    LISTENING     localhost:9876
    Broker         RUNNING    LISTENING     localhost:10911
    Proxy          RUNNING    LISTENING     localhost:18080
  LoongCollector   RUNNING    LISTENING     容器运行中 @ localhost:4318

  汇总: 7 OK  0 FAIL  共 7 个服务
```

---

## 4. 启动 Admin 服务

### 4.1 使用一键脚本（推荐）

```bash
# 自动启动中间件 + 构建完整前端 + 构建并运行后端
./start.sh

# 等效于（显式调用）
scripts/admin-start.sh

# 常用参数
scripts/admin-start.sh --foreground    # 前台运行（可看实时日志）
scripts/admin-start.sh --skip-deps     # 跳过中间件启动
scripts/admin-start.sh --build         # 强制重新构建
scripts/admin-start.sh --restart       # 重启后端
scripts/admin-start.sh --port 8081     # 指定端口
```

脚本会优先使用 JDK 21；若本机默认 Java 是 8 或低于 17，脚本会尝试使用 `/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home/bin/java` 或 `JAVA_HOME` 指向的 JDK。

macOS 上脚本通过 LaunchAgent 托管后端进程，日志位于：

```
.local/run/admin-server.log
.local/run/admin-server.err.log
```

### 4.2 手动构建和启动

手动方式只建议排障时使用。日常启动请优先使用 `./start.sh`，避免忘记同步前端资源导致页面菜单缺失。

```bash
# 构建完整前端资源
cd frontend
npm install --ignore-scripts
npm run build:flow
BACK_END=java npm run build:app
cd ..

# 同步前端资源到后端
rm -rf spring-ai-alibaba-admin-server-start/src/main/resources/static/*
cp -R frontend/packages/main/dist/. spring-ai-alibaba-admin-server-start/src/main/resources/static/

# 构建后端
mvn clean install -DskipTests

# 启动（方式一：mvn spring-boot:run，需要先 mvn install）
cd spring-ai-alibaba-admin-server-start
mvn spring-boot:run

# 启动（方式二：java -jar，推荐）
source scripts/install-deps.local.env 2>/dev/null
SPRING_DATASOURCE_URL='jdbc:mysql://localhost:3306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai' \
SPRING_DATASOURCE_USERNAME='admin' \
SPRING_DATASOURCE_PASSWORD='admin' \
SPRING_REDIS_HOST='localhost' \
SPRING_REDIS_PORT='6379' \
SPRING_ELASTICSEARCH_URIS='http://localhost:9200' \
SPRING_ELASTICSEARCH_URL='http://localhost:9200' \
NACOS_SERVER_ADDR='localhost:8848' \
ROCKETMQ_ENDPOINTS='localhost:18080' \
ROCKETMQ_NAME_SERVER='localhost:9876' \
SERVER_PORT=8081 \
java -jar spring-ai-alibaba-admin-server-start/target/spring-ai-alibaba-admin-server-start.jar
```

### 4.3 连接信息汇总

| 服务 | 端口 | 连接地址 | 用户名/密码 |
|---|---|---|---|
| MySQL | 3306 | `localhost:3306/admin` | `admin` / `admin` |
| Redis | 6379 | `localhost:6379` | 无认证 |
| Elasticsearch | 9200 | `http://localhost:9200` | 无认证 |
| Nacos | 8848 | `localhost:8848` | — |
| RocketMQ Proxy | 18080 | `localhost:18080` | — |
| RocketMQ NameServer | 9876 | `localhost:9876` | — |
| LoongCollector | 4318 | `http://localhost:4318/v1/traces` | — |
| Kibana | 5601 | `http://localhost:5601` | — |

---

## 5. 启动前端

Admin 默认使用后端 jar 内置的静态资源，不需要单独启动前端 dev server。只有开发前端页面时才需要执行本节命令。

```bash
cd frontend
npm install
npm run build:flow          # 构建工作流编排组件
BACK_END=java npm run build:app  # 构建主应用

# 开发模式
cd packages/main
cp .env.example .env        # 首次需要创建 .env
npm run dev
```

前端 `.env` 关键配置：

```
WEB_SERVER="http://127.0.0.1:8081"   # 后端地址（注意端口与 SERVER_PORT 一致）
BACK_END="java"
```

前端改动后，如果希望后端内置静态资源同步更新，直接执行：

```bash
./start.sh --build --restart
```

---

## 6. 常见踩坑

### JDK 版本不对

**现象**：构建报 `无效的目标发行版: 17`，或运行报 `UnsupportedClassVersionError: class file version 61.0`。

**原因**：jenv 或系统默认 Java 版本低于 17。

**解决**：

```bash
# 检查实际 Java 版本
java -version

# macOS：设置 JAVA_HOME 到 JDK 21
export JAVA_HOME=$(/usr/libexec/java_home -v 21)

# 或使用 jenv 切换
jenv global 21
```

### 端口冲突（8080 被占）

**现象**：后端启动失败，报端口已被占用。

**原因**：Nacos 3.x 内嵌控制台默认监听 8080，与应用默认端口冲突。

**解决**：通过环境变量指定其他端口：

```bash
export SERVER_PORT=8081
```

或启动时传入：`scripts/admin-start.sh --port 8081`。

### MySQL 连接失败

**现象**：后端日志报 `Access denied for user 'admin'@'localhost'`。

**原因**：MySQL 未初始化 `admin` 库和用户。

**解决**：

```bash
# 手动初始化
mysql -uroot -p -e "
  CREATE DATABASE IF NOT EXISTS admin DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE USER IF NOT EXISTS 'admin'@'localhost' IDENTIFIED BY 'admin';
  GRANT ALL PRIVILEGES ON admin.* TO 'admin'@'localhost';
  FLUSH PRIVILEGES;
"
mysql -uadmin -padmin admin < docker/middleware/init/mysql/admin-schema.sql
mysql -uadmin -padmin admin < docker/middleware/init/mysql/agentscope-schema.sql
```

如果你的 MySQL root 有密码，先配置 `scripts/install-deps.local.env`：

```bash
MYSQL_ROOT_PASSWORD=你的root密码
```

### Elasticsearch 启动后分片不分配

**现象**：`curl localhost:9200/_cluster/health` 返回 `status: red`，分片 UNASSIGNED。

**原因**：磁盘使用率超过 ES 默认 90% 高水位线。

**解决**：安装脚本已自动调高水位线到 95%/98%/99%。如果是手动安装的 ES，在 `elasticsearch.yml` 中添加：

```yaml
cluster.routing.allocation.disk.watermark.low: 95%
cluster.routing.allocation.disk.watermark.high: 98%
cluster.routing.allocation.disk.watermark.flood_stage: 99%
```

### Kibana 9.x 启动报错 xpack.security.enabled

**现象**：Kibana FATAL 报错，提示不支持的配置项。

**原因**：Kibana 9.x 移除了 `xpack.security.enabled` 配置项。

**解决**：`kibana.yml` 只保留最小配置：

```yaml
server.port: 5601
server.host: "127.0.0.1"
elasticsearch.hosts: ["http://localhost:9200"]
```

### Nacos 3.x 无限重启

**现象**：Nacos 进程不断重启，日志报 token.secret.key 不合法。

**原因**：Nacos 3.x 要求 `token.secret.key` 必须是 Base64 编码且原始字符串 >= 32 字符。

**解决**：安装脚本会自动处理。手动安装时在 `conf/application.properties` 中设置：

```properties
nacos.core.auth.plugin.nacos.token.secret.key=VGhpc0lzTXlDdXN0b21TZWNyZXRLZXkwMTIzNDU2Nzg=
nacos.core.auth.server.identity.key=admin
nacos.core.auth.server.identity.value=admin
```

### LoongCollector 容器无法连接宿主机 ES

**现象**：LoongCollector 容器日志报连接 `elasticsearch:9200` 失败。

**原因**：容器内 `elasticsearch` 是 Docker Compose 内部域名，本地 ES 跑在宿主机上。

**解决**：配置文件中 ES 地址改为 `http://host.docker.internal:9200`。

### LoongCollector flusher_elasticsearch 报认证错误

**现象**：`PlainText username or password cannot be null`，即使 ES 未开启认证。

**原因**：`flusher_elasticsearch` 插件强制要求非空用户名密码。

**解决**：在配置中保留占位值 `elastic/elastic`（ES 未开认证时会忽略）。

### mvn package vs install

**现象**：`mvn clean package` 后 `mvn spring-boot:run` 报找不到依赖。

**原因**：`package` 只打包不安装到本地仓库，`spring-boot:run` 需要依赖已在本地仓库中。

**解决**：使用 `mvn clean install -DskipTests`，或直接用 `java -jar` 运行打包好的 jar。

---

## 7. 验证清单

启动完成后，按以下步骤验证环境是否正常。

### Step 1：检查中间件状态

```bash
scripts/deps-status.sh
```

确认 7 个服务全部显示 `RUNNING`。

### Step 2：检查后端健康

```bash
curl http://localhost:8081/actuator/health
```

应返回 `{"status":"UP"}`。

### Step 3：访问管理界面

浏览器打开 **http://localhost:8081/admin**，应看到登录页面。

页面登录后应能看到以下核心功能入口：

- Prompt 工程：Prompts、Playground
- 评测：评测集、评估器、实验
- 应用：应用列表、工作流编排
- 知识库：知识库列表、创建、文档管理、检索测试
- 可观测：Tracing
- 设置：模型服务、API Key、账号

如果只看到 Prompt / 评测 / 可观测，说明加载了旧前端资源。处理顺序：

```bash
# 1. 浏览器强制刷新
# 2. 仍不正常时重建完整静态资源并重启
./start.sh --build --restart
```

### Step 4：登录测试

使用默认账号登录：

- 用户名：`saa`
- 密码：`123456`

### Step 5：核心 API 冒烟测试

登录后，以下 API 应返回 200：

```bash
# 获取 Token（替换到后续命令的 <TOKEN>）
TOKEN=$(curl -s -X POST http://localhost:8081/console/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"saa","password":"123456"}' | jq -r '.data.access_token')

# Prompt 列表
curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/prompts?pageNo=1&pageSize=10 \
  -H "Authorization: Bearer $TOKEN"

# 数据集列表
curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/dataset/datasets?pageNumber=1&pageSize=10 \
  -H "Authorization: Bearer $TOKEN"

# 评估器列表
curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/evaluator/evaluators?pageNumber=1&pageSize=10 \
  -H "Authorization: Bearer $TOKEN"
```

### Step 6：（可选）配置模型 API Key

登录管理界面后，进入“模型服务管理”，配置至少一个模型 Provider 的 API Key，否则 AI 对话和知识库向量化不可用。

推荐配置方式：

1. 新增模型服务商，协议选择 `OpenAI`
2. 填写 API Key 和 OpenAI 兼容 endpoint
3. 在服务商详情中分别新增模型：
   - 对话模型：类型选择 `llm`
   - Embedding 模型：类型选择 `text_embedding`
   - Rerank 模型：类型选择 `rerank`，可选

知识库至少需要 `text_embedding` 模型。`rerank` 已支持不配置；未选择时 `enable_rerank=false`，检索只走向量召回。

---

## 8. 文件布局说明

安装脚本产生的文件位于 `.local/` 目录（已 gitignore）：

```
.local/
├── downloads/           # 中间件安装包缓存
├── deps/                # 解压后的中间件
│   ├── elasticsearch-9.1.2/
│   ├── kibana-9.1.2/
│   ├── nacos/
│   └── rocketmq-all-5.3.2-bin-release/
└── run/                 # 启动脚本和日志
    ├── start-*.sh
    ├── rmq-proxy.json
    └── *.log
```

---

## 9. macOS LaunchAgent 管理

macOS 上 Elasticsearch、Kibana、Nacos、RocketMQ 通过 LaunchAgent 托管，开机自动启动、崩溃自动重启。

```bash
# 查看服务状态
launchctl print gui/$(id -u)/com.spring-ai-alibaba-admin.elasticsearch

# 停止服务（不再自动重启）
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.elasticsearch.plist

# 重新启动
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.elasticsearch.plist
```

可用服务名：`elasticsearch`、`kibana`、`nacos`、`rocketmq.namesrv`、`rocketmq.broker`、`rocketmq.proxy`。

---

## 10. 相关文档

- [环境依赖清单](env-checklist.md)
- [测试运行指南](testing-guide.md)
- [安装日志](../scripts/install-log.md)
- [应用启动日志](startup-log.md)
- [冒烟测试结果](smoke-test-result.md)
- [REST 接口清单](api-list.md)
- [数据模型](data-model.md)
- [外部依赖图](external-dependencies.svg)
