# 本地依赖安装日志

## 安装历史

### 第一轮：2026-06-09 10:45:44 +0800（scripts/install-deps.sh 自动执行）

- 跳过 brew update
- 基础工具（JDK 21 / Maven 3.8.5 / Node 23.11.0 / npm 11.6.2）：已就绪
- MySQL 8：建库建用户成功，schema 已导入
- Redis 7：已就绪
- Elasticsearch：跳过（等待手动下载）
- Nacos：跳过（GitHub 下载不可达）
- RocketMQ 5.3.2：下载、解压、LaunchAgent 托管、topic/group 初始化均成功
- Kibana：跳过
- LoongCollector：无 macOS 原生包，记录容器镜像

### 第二轮：2026-06-09 11:39 ~ 14:35（手动补装）

- Elasticsearch 9.1.2：从 ~/Downloads/ 复制到 .local/downloads/，解压到 .local/deps/，配置单节点+磁盘水位线，LaunchAgent 托管启动，trace pipeline/index 初始化完成
- Kibana 9.1.2：从 ~/Downloads/ 复制到 .local/downloads/，解压到 .local/deps/，配置连接本地 ES（移除 9.x 不支持的 xpack.security.enabled），LaunchAgent 托管启动
- Nacos 3.0.3：通过 ghfast.top 镜像下载（187MB），解压到 .local/deps/nacos/，配置 application.properties 中的 token.secret.key 和 identity，直接 exec java 启动（避免 startup.sh fork 导致 LaunchAgent 不断重启）
- LoongCollector 3.1.4：通过 Docker 容器运行，映射 4318 端口，挂载 docker/middleware/conf/loongcollector 配置
  - ES 地址需用 `host.docker.internal:9200`（容器通过 Docker DNS 访问宿主机 ES）
  - `flusher_elasticsearch` 插件强制要求非空的 `Authentication.PlainText` 用户名密码，即使 ES 未开认证也必须填占位值（如 `elastic/elastic`）

## 最终校验（2026-06-09 14:35）

| 服务 | 端口 | 状态 | 运行方式 |
|---|---|---|---|
| MySQL 8 | 3306 | OK | 系统服务 |
| Redis 7 | 6379 | PONG | 系统服务 |
| Elasticsearch 9.1.2 | 9200 | green | macOS LaunchAgent |
| Kibana 9.1.2 | 5601 | available | macOS LaunchAgent |
| Nacos 3.0.3 | 8848 | OK | macOS LaunchAgent |
| RocketMQ 5.3.2 | 9876 / 10911 / 18080 | OK | macOS LaunchAgent x3 |
| LoongCollector 3.1.4 | 4318 | OK | Docker 容器 |

## macOS LaunchAgent 服务

以下服务通过 `launchctl` 托管，开机自动启动、崩溃自动重启：

```bash
# 查看服务状态
launchctl print gui/$(id -u)/com.spring-ai-alibaba-admin.elasticsearch
launchctl print gui/$(id -u)/com.spring-ai-alibaba-admin.kibana
launchctl print gui/$(id -u)/com.spring-ai-alibaba-admin.nacos
launchctl print gui/$(id -u)/com.spring-ai-alibaba-admin.rocketmq.namesrv
launchctl print gui/$(id -u)/com.spring-ai-alibaba-admin.rocketmq.broker
launchctl print gui/$(id -u)/com.spring-ai-alibaba-admin.rocketmq.proxy
```

```bash
# 停止服务（不再自动重启）
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.elasticsearch.plist
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.kibana.plist
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.nacos.plist
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.rocketmq.namesrv.plist
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.rocketmq.broker.plist
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.rocketmq.proxy.plist
```

```bash
# 重新启动已停止的服务
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.elasticsearch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.kibana.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.nacos.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.rocketmq.namesrv.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.rocketmq.broker.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.rocketmq.proxy.plist
```

## Docker 容器

```bash
# LoongCollector
docker start loongcollector
docker stop loongcollector
docker logs loongcollector
```

## 安装过程中遇到的问题和解决方案

### 1. ES 磁盘水位线导致分片不分配

磁盘 `/System/Volumes/Data` 使用率 92%，超过 ES 默认 90% 高水位线，所有分片 UNASSIGNED。

解决：在 ES 配置和集群设置中调高水位线：
```
cluster.routing.allocation.disk.watermark.low: 95%
cluster.routing.allocation.disk.watermark.high: 98%
cluster.routing.allocation.disk.watermark.flood_stage: 99%
```

### 2. Kibana 9.x 不支持 xpack.security.enabled

Kibana 9.x 移除了 `xpack.security.enabled` 配置项，设置后 FATAL 报错。

解决：kibana.yml 只保留 `server.port`、`server.host`、`elasticsearch.hosts` 三项。

### 3. Nacos 3.x token.secret.key 校验

Nacos 3.x 要求 `nacos.core.auth.plugin.nacos.token.secret.key` 必须是 Base64 编码且原始字符串 >= 32 字符，空值或非法值会无限报错并不断重启。

解决：在 `conf/application.properties` 中设置合法 token。

### 4. Nacos startup.sh 与 LaunchAgent 不兼容

`startup.sh` 会 fork 后台 Java 进程后退出，LaunchAgent 检测到脚本退出就不断重启 Nacos。

解决：启动脚本中直接 `exec java` 运行 nacos-server.jar，跳过 startup.sh。

### 5. LoongCollector 无 macOS 原生二进制

官方只发布 Linux/Windows 二进制。

解决：通过 Docker 容器运行，映射 4318 端口。

### 6. LoongCollector 容器访问宿主机 ES

容器内 `elasticsearch:9200` 不可达（那是 Docker Compose 内部域名），本地 ES 跑在宿主机上。

解决：ES 地址改为 `http://host.docker.internal:9200`。

### 7. LoongCollector flusher_elasticsearch 强制要求认证

`flusher_elasticsearch` 插件初始化时校验 `PlainText username or password cannot be null`，即使 ES 未开 xpack 安全认证也会报错，导致 pipeline 加载失败、4318 端口拒绝所有请求。

解决：保留 `Authentication.PlainText` 配置，填入占位值 `elastic/elastic`（ES 未开认证时会忽略这些值）。

## 文件布局

```
.local/
├── downloads/
│   ├── elasticsearch-9.1.2-darwin-aarch64.tar.gz   (472MB)
│   ├── kibana-9.1.2-darwin-aarch64.tar.gz          (245MB)
│   ├── nacos-server-3.0.3.tar.gz                   (187MB)
│   └── rocketmq-all-5.3.2-bin-release.zip          (87MB)
├── deps/
│   ├── elasticsearch-9.1.2/
│   ├── kibana-9.1.2/
│   ├── nacos/
│   └── rocketmq-all-5.3.2-bin-release/
└── run/
    ├── start-elasticsearch.sh
    ├── start-kibana.sh
    ├── start-nacos.sh
    ├── start-rocketmq-namesrv.sh
    ├── start-rocketmq-broker.sh
    ├── start-rocketmq-proxy.sh
    ├── rmq-proxy.json
    └── *.log / *.err.log
```

## 应用连接环境变量

```bash
export SPRING_DATASOURCE_URL='jdbc:mysql://localhost:3306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai'
export SPRING_DATASOURCE_USERNAME='admin'
export SPRING_DATASOURCE_PASSWORD='admin'
export SPRING_REDIS_HOST='localhost'
export SPRING_REDIS_PORT='6379'
export SPRING_REDIS_DATABASE='0'
export SPRING_ELASTICSEARCH_URIS='http://localhost:9200'
export SPRING_ELASTICSEARCH_URL='http://localhost:9200'
export NACOS_SERVER_ADDR='localhost:8848'
export ROCKETMQ_ENDPOINTS='localhost:18080'
export ROCKETMQ_NAME_SERVER='localhost:9876'
export ROCKETMQ_DOCUMENT_INDEX_TOPIC='topic_saa_studio_document_index'
export ROCKETMQ_DOCUMENT_INDEX_GROUP='group_saa_studio_document_index'
export MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT='http://localhost:4318/v1/traces'
```
