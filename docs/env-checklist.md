# 外部依赖环境检查清单

本文档综合 `docs/external-dependencies.svg`、`spring-ai-alibaba-admin-server-start/src/main/resources/application*.yml`、`spring-ai-alibaba-admin-server-start/src/main/resources/elasticsearch.yml`、`pom.xml`、`README*`、`docker/middleware/docker-compose.yaml` 和 `deploy/` 下部署清单整理。

## 1. 运行前置工具

这些不是业务中间件，但本地源码运行或容器化部署前需要先具备。

| 依赖 | 版本要求 | 用途 | 检查命令 |
|---|---|---|---|
| Docker | 未锁定具体版本 | 本地启动中间件、构建镜像 | `docker --version` |
| Docker Compose | 2.x | `docker/middleware/docker-compose.yaml` | `docker compose version` |
| JDK | >=17；本机安装脚本优先使用已有 JDK 21 | 后端源码运行和 Maven 构建 | `java -version` |
| Maven | 3.8+ | 后端构建、`mvn spring-boot:run` | `mvn -version` |
| Node.js | 20.x+ | 前端源码运行 | `node -v` |
| npm | 随 Node 安装 | 前端 workspace 安装和启动 | `npm -v` |

## 2. 必需运行依赖

### 2.1 MySQL

| 项 | 内容 |
|---|---|
| 名字 | MySQL |
| 版本要求 | 8.x；本地 Compose / K8s 镜像为 `sca-registry.cn-hangzhou.cr.aliyuncs.com/dubbo/mysql:8.0.35`，Java 驱动为 `mysql-connector-j` 8.x |
| 默认端口 | `3306` |
| 本地连接信息 | `jdbc:mysql://localhost:3306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| K8s 连接信息 | `jdbc:mysql://mysql:3306/admin?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai` |
| 用户名 / 密码 | `admin` / `admin`；root 密码 `root` |
| 配置项 | `SPRING_DATASOURCE_URL`、`SPRING_DATASOURCE_USERNAME`、`SPRING_DATASOURCE_PASSWORD` |
| 初始化要求 | 创建数据库 `admin`；首次初始化时执行 `docker/middleware/init/mysql/admin-schema.sql` 和 `docker/middleware/init/mysql/agentscope-schema.sql`。这两份 SQL 未声明 `CREATE DATABASE` / `USE`，会落到容器环境变量 `MYSQL_DATABASE=admin` 指定的库中 |
| 注意事项 | MySQL 官方镜像只会在数据目录首次初始化时执行 `/docker-entrypoint-initdb.d/`；已有数据目录时不会重复跑建表脚本。K8s 部署前需要先创建 `mysql-init-scripts` ConfigMap |

### 2.2 Redis

| 项 | 内容 |
|---|---|
| 名字 | Redis |
| 版本要求 | 7.x；本地 Compose / K8s 镜像为 `redis:7.2.5` |
| 默认端口 | `6379` |
| 本地连接信息 | `localhost:6379`，database `0` |
| K8s 连接信息 | `redis:6379`，database `0` |
| 用户名 / 密码 | 未配置认证 |
| 配置项 | `SPRING_REDIS_HOST`、`SPRING_REDIS_PORT`、`SPRING_REDIS_DATABASE` |
| 初始化要求 | 无建库脚本；需要持久化数据目录或 PVC |

### 2.3 Elasticsearch

| 项 | 内容 |
|---|---|
| 名字 | Elasticsearch |
| 版本要求 | 服务端 9.x；本地 Compose / K8s 镜像为 `docker.elastic.co/elasticsearch/elasticsearch:9.1.2`。Java 客户端依赖为 8.x：`elasticsearch-java` / `elasticsearch-rest-client` 8.13.4 |
| 默认端口 | HTTP `9200`，transport `9300` |
| 本地连接信息 | `http://localhost:9200` |
| K8s 连接信息 | `http://elasticsearch:9200` |
| 用户名 / 密码 | Compose 中 `xpack.security.enabled=false`，应用侧未配置认证；LoongCollector 配置里保留了 `elastic` / `elastic`，但当前 ES 安全关闭 |
| 配置项 | `SPRING_ELASTICSEARCH_URIS`、`SPRING_ELASTICSEARCH_URL` |
| 初始化要求 | `docker/middleware/init/elasticsearch/init-indices.sh` 会创建 `parsing_loongsuite_traces` ingest pipeline 和 `loongsuite_traces` 索引；本地 Compose 通过 `elasticsearch-init` 容器执行 |
| 注意事项 | K8s 清单设置 `vm.max_map_count=262144`，本地环境也要关注该系统参数和内存；Compose 设置 `ES_JAVA_OPTS=-Xms1g -Xmx1g` |

### 2.4 Nacos

| 项 | 内容 |
|---|---|
| 名字 | Nacos |
| 版本要求 | 服务端未锁定具体版本，Compose / K8s 使用 `nacos/nacos-server:latest`；Java 侧存在 Nacos Client 3.x / Spring Alibaba Nacos Config 2023.x 依赖 |
| 默认端口 | Nacos client `8848`；容器内还暴露 HTTP `8080`、RPC `9848` |
| 本地连接信息 | 应用默认 `localhost:8848`；当前 Compose 端口映射为宿主机 `7848 -> 容器 8848`、`7080 -> 容器 8080`、`8848 -> 容器 9848` |
| K8s 连接信息 | `nacos:8848` |
| 认证信息 | `NACOS_AUTH_IDENTITY_KEY=admin`、`NACOS_AUTH_IDENTITY_VALUE=admin`，并配置 `NACOS_AUTH_TOKEN` |
| 配置项 | `NACOS_SERVER_ADDR` / `nacos.server-addr` |
| 初始化要求 | 当前未发现 Admin 自身必须预创建 Nacos namespace、dataId 或 group；README 只要求需要调整地址时修改 `nacos.server-addr` |
| 注意事项 | 本地 Compose 的宿主机端口映射和应用默认 `localhost:8848` 存在易混点：应用默认连 `8848`，但 Compose 中 `8848` 映射到容器 `9848`，容器 client 端口 `8848` 映射到宿主机 `7848`。如果本地 Nacos 连接失败，优先核对端口映射并考虑设置 `NACOS_SERVER_ADDR=localhost:7848` |

### 2.5 RocketMQ

| 项 | 内容 |
|---|---|
| 名字 | RocketMQ NameServer / Broker / Proxy |
| 版本要求 | 服务端 5.x；本地 Compose / K8s 镜像为 `apache/rocketmq:5.3.2`。Java 客户端依赖为 `rocketmq-client-java` 5.0.7 |
| 默认端口 | NameServer `9876`；Broker `10909` / `10911` / `10912`；Proxy HTTP `18080`，gRPC `18081` |
| 本地连接信息 | 应用默认 `ROCKETMQ_ENDPOINTS=localhost:18080`；NameServer 为 `localhost:9876` |
| K8s 连接信息 | `ROCKETMQ_ENDPOINTS=rmq-proxy:18080`，`ROCKETMQ_NAME_SERVER=rmq-namesrv:9876` |
| 配置项 | `ROCKETMQ_ENDPOINTS`、`ROCKETMQ_NAME_SERVER`、`ROCKETMQ_DOCUMENT_INDEX_TOPIC`、`ROCKETMQ_DOCUMENT_INDEX_GROUP` |
| 初始化要求 | 需要创建文档索引 Topic `topic_saa_studio_document_index` 和消费者组 `group_saa_studio_document_index`；本地 Compose 通过 `init-topic` 容器执行 `mqadmin updateTopic` 和 `mqadmin updateSubGroup` |
| 注意事项 | `docker/middleware/conf/rocketmq/rmq-proxy.json` 配置 `rocketMQClusterName=DefaultCluster`、`remotingListenPort=18080`、`grpcServerPort=18081` |

### 2.6 LoongCollector / OTLP Collector

| 项 | 内容 |
|---|---|
| 名字 | LoongCollector Community Edition |
| 版本要求 | 3.x；本地 Compose / K8s 镜像为 `sls-opensource-registry.cn-shanghai.cr.aliyuncs.com/loongcollector-community-edition/loongcollector:3.1.4` |
| 默认端口 | OTLP HTTP `4318` |
| 本地连接信息 | 应用默认 `http://localhost:4318/v1/traces` |
| K8s 连接信息 | `http://loongcollector:4318/v1/traces` |
| 配置项 | `MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT` |
| 初始化要求 | 挂载 `docker/middleware/conf/loongcollector/otlp_pipeline.yaml`；配置接收 OTLP HTTP `0.0.0.0:4318`，输出到 stdout 和 Elasticsearch `http://elasticsearch:9200` 的 `loongsuite_traces` 索引 |
| 注意事项 | 依赖 Elasticsearch 已启动，并依赖前述 ES trace index / pipeline 初始化 |

## 3. 可选或按功能启用依赖

### 3.1 Kibana

| 项 | 内容 |
|---|---|
| 名字 | Kibana |
| 版本要求 | 9.x；本地 Compose / K8s 镜像为 `docker.elastic.co/kibana/kibana:9.1.2` |
| 默认端口 | `5601` |
| 本地连接信息 | `http://localhost:5601` |
| K8s 连接信息 | `http://kibana:5601` |
| 上游连接 | `ELASTICSEARCH_HOSTS=http://elasticsearch:9200` |
| 初始化要求 | 无；等待 Elasticsearch 健康后启动 |
| 作用 | Trace / Elasticsearch 数据可视化查询；不影响后端主流程启动，但影响可观测性排查体验 |

### 3.2 AI 模型服务

| 项 | 内容 |
|---|---|
| 名字 | DashScope / OpenAI / DeepSeek / OpenAI-Compatible API / Ollama 等模型服务 |
| 版本要求 | 外部 HTTP API，无固定服务端版本；代码侧基于 Spring AI 1.x、Spring AI Alibaba 1.x |
| 默认端口 | 云服务无本地端口；Ollama 常见为 `11434`，但项目未在配置中锁定 |
| 连接信息 | 模板文件位于 `spring-ai-alibaba-admin-server-start/model-config-*.yaml`；OpenAI 示例 `https://api.openai.com/v1`，DashScope 示例 `https://dashscope.aliyuncs.com/compatible-mode`，DeepSeek 代码默认 `https://api.deepseek.com` |
| 凭证 | `OPENAI_API_KEY`、`DASHSCOPE_API_KEY`、`DEEPSEEK_API_KEY`，或通过数据库 provider/model 配置维护 |
| 初始化要求 | 按 README 修改 `spring-ai-alibaba-admin-server-start/model-config.yaml` 或参考 `model-config-openai.yaml`、`model-config-dashscope.yaml`、`model-config-deepseek.yaml`；默认 SQL 预置了 Tongyi provider 和多条模型记录，但真实调用仍需要有效 API Key / credential |
| 注意事项 | 模型配置接口中提示“不支持通过接口创建/更新/删除模型配置，请使用 model-config.yml”；不同模块也可能从数据库 provider credential 读取 endpoint/apiKey |

### 3.3 对象存储 / OSS

| 项 | 内容 |
|---|---|
| 名字 | Aliyun OSS 或兼容对象存储 |
| 版本要求 | SDK 3.x；`aliyun-sdk-oss` 3.17.4 |
| 默认端口 | 云服务无固定端口 |
| 连接信息 | 代码和领域模型支持 OSS 上传策略、OSS 文档类型，但当前 `application.yml` / README 未发现必填 OSS endpoint、bucket、AK/SK |
| 初始化要求 | 未发现本地启动必须配置 OSS；仅在启用 OSS 上传或 OSS 类型文档时需要补齐相关凭证和 bucket |
| 注意事项 | 如果只使用本地文件或非 OSS 上传路径，可先不配置 |

## 4. 前端到后端连接

| 项 | 内容 |
|---|---|
| 前端环境文件 | `frontend/packages/main/.env`，可由 `.env.example` 复制 |
| 后端地址 | `WEB_SERVER="http://127.0.0.1:8081"` |
| 后端类型 | `BACK_END="java"` |
| 默认登录 | `DEFAULT_USERNAME=saa`、`DEFAULT_PASSWORD=123456` |
| 前端端口 | README 指向 `http://localhost:8000` |
| 初始化要求 | `cd frontend && npm run re-install` 后进入 `packages/main` 执行 `npm run dev` |

## 5. Kubernetes 运行要求

| 项 | 内容 |
|---|---|
| Namespace | `spring-ai-admin`，由 `deploy/namespace.yaml` 创建 |
| 部署入口 | `deploy/deploy.sh` 或 `kubectl apply -k deploy/` |
| MySQL 初始化 | 必须在 MySQL 首次部署前创建 `mysql-init-scripts` ConfigMap；`deploy/deploy.sh` 会从 `docker/middleware/init/mysql/admin-schema.sql` 和 `agentscope-schema.sql` 创建 |
| 持久化 | MySQL、Redis、Nacos、RocketMQ Broker、Elasticsearch 使用 PVC |
| 后端环境变量 | `deploy/backend/backend-deployment.yaml` 已配置 MySQL、Redis、Elasticsearch、Nacos、RocketMQ、LoongCollector 连接信息 |
| 镜像 | 后端默认 `spring-ai-admin-server:latest`，前端默认 `spring-ai-admin-frontend:latest` |

## 6. 本地一键启动参考

```bash
# 首次安装中间件
scripts/install-deps.sh

# 日常启动中间件 + 完整前端静态资源 + 后端 Admin
./start.sh

# 中间件已运行时，只重启 Admin
./start.sh --skip-deps --restart

# 前端菜单或静态资源变化后，强制重建
./start.sh --build --restart

# 查看 / 停止中间件
scripts/deps-status.sh
scripts/deps-stop.sh
```

启动成功后访问 `http://localhost:8081/admin`，健康检查为 `http://localhost:8081/actuator/health`。后端 jar 默认内置已构建的前端静态资源，不需要单独启动前端 dev server；只有开发前端页面时才需要 `cd frontend/packages/main && npm run dev`。

## 7. 快速核对清单

- [ ] Docker / Docker Compose 可用。
- [ ] JDK >=17、Maven 3.8+ 可用；本机优先使用已有 JDK 21。
- [ ] Node.js 20+、npm 可用。
- [ ] MySQL 8 已启动，`admin` 库存在，账号 `admin/admin` 可连接。
- [ ] MySQL 首次初始化已执行 `admin-schema.sql` 和 `agentscope-schema.sql`。
- [ ] Redis 7 已启动，`localhost:6379` 或 `redis:6379` 可连接。
- [ ] Elasticsearch 已启动，`/_cluster/health` 返回 green/yellow。
- [ ] Elasticsearch 已创建 `parsing_loongsuite_traces` pipeline 和 `loongsuite_traces` 索引。
- [ ] Nacos 已启动，`NACOS_SERVER_ADDR` 指向正确 client 端口。
- [ ] RocketMQ NameServer、Broker、Proxy 已启动。
- [ ] RocketMQ 已创建 `topic_saa_studio_document_index` 和 `group_saa_studio_document_index`。
- [ ] LoongCollector 已启动，OTLP endpoint 为 `http://localhost:4318/v1/traces` 或 `http://loongcollector:4318/v1/traces`。
- [ ] 如需 Trace 查询，Kibana 已连接 Elasticsearch。
- [ ] Admin 健康检查 `http://localhost:8081/actuator/health` 返回 UP。
- [ ] 管理页面 `http://localhost:8081/admin` 可访问，默认账号 `saa/123456` 可登录。
- [ ] 登录后侧边栏能看到 Prompt、评测、应用 / 工作流编排、知识库、可观测、设置 / 模型服务。
- [ ] 如需真实模型调用，已在“模型服务管理”配置 Provider endpoint、API Key 和正确模型类型。
- [ ] 如需知识库，至少配置一个 `text_embedding` 模型；`rerank` 可选。
- [ ] 前端 `.env` 中 `WEB_SERVER` 指向后端地址，`BACK_END=java`。
