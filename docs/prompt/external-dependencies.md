# 对外依赖图生成提示词

请帮我生成一张项目对外依赖图，目标是说明系统运行和开发所依赖的关键外部组件，而不是展示内部模块结构。

请先分析构建文件、配置文件和部署文件，例如 Maven `pom.xml`、应用配置、Docker Compose、Kubernetes manifests、README，然后按以下规则组织图：

1. 对外依赖至少分为三类：
   - 关键 Java 依赖：影响项目核心能力的框架、SDK、客户端库和运行时库。
   - 中间件：需要部署、连接或运维的数据库、缓存、消息队列、搜索/向量库、配置中心、采集器等。
   - 外部 API：系统通过 HTTP/SDK/协议调用的支付、短信、地图、邮件、对象存储、模型服务、外部业务系统等。
2. 如果项目存在明显的运维或可观测依赖，可以额外增加 `Platform / Observability` 分组，例如 Docker Compose、Kubernetes、OpenTelemetry、ARMS、Kibana 等。
3. 不要罗列所有 transitive dependencies，只展示架构理解所必需的关键依赖。
4. Java 依赖优先按能力分组，而不是按 Maven 坐标逐项堆叠：
   - Core Framework
   - Data / Integration
   - Security / API / Observability
   - Domain Capability Libraries
5. 中间件要区分“应用连接的运行时服务”和“辅助观测/部署组件”。同一个组件如果既是存储又参与观测，可以在说明里标注主要职责。
6. 外部 API 要区分“能力提供方”和“外部交互系统”：
   - 能力提供方：支付、短信、地图、邮件、对象存储、OCR、模型 API 等。
   - 外部交互系统：第三方业务系统、开放平台、Webhook 调用方、外部客户端等。
7. 用少量连线表达依赖方向：应用核心分别依赖 Java 库、中间件和外部 API；不要从每个业务能力拉到每个依赖。
8. 图面适合 README/技术方案文档阅读：保持分组清楚、文字简短、版本只标关键版本。

请输出一版 SVG 或 Mermaid 依赖图，并说明每个分组的依据和主要依赖来源。
