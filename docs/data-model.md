# 数据模型总览与数据字典

本文基于以下来源整理：

- `docker/middleware/init/mysql/agentscope-schema.sql`
- `docker/middleware/init/mysql/admin-schema.sql`
- `spring-ai-alibaba-admin-server-core/.../core/base/entity/*Entity.java`
- `spring-ai-alibaba-admin-server-start/.../admin/entity/*DO.java`
- 相关枚举类，例如 `CommonStatus`、`ToolStatus`、`DocumentType`、`AgentType`、`ExperimentStatus`

说明：

- `PK` 表示数据库主键。
- `UK` 表示唯一业务键。
- `FK` 表示 SQL 中显式外键。
- `逻辑 FK` 表示代码和索引中通过业务 ID 关联，但 SQL 没有声明外键约束。
- 多数主业务表都包含 `creator`、`modifier`、`gmt_create`、`gmt_modified` 等审计字段，下表仍按 SQL 如实列出。

ER 图见：[data-model-er.svg](/Users/pengchengchen/CcProject/spring-ai-alibaba-admin/docs/data-model-er.svg)

图和本文的分工：

- `docs/data-model-er.svg` 是核心数据模型总览图，只展示核心表、核心字段和关键关系，优先保证可读性。
- 本文是数据字典，覆盖 SQL 中的全部建表字段，并补充主键、唯一键、外键、逻辑关联和枚举值。

## 一、账号、工作空间与凭证

### 1. account

账号表，保存平台登录账号和基础身份信息。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| account_id | VARCHAR(64) | UK | 账号业务 ID |
| username | VARCHAR(255) |  | 登录名 / 账号名 |
| email | VARCHAR(255) |  | 邮箱 |
| mobile | VARCHAR(255) |  | 手机号 |
| password | VARCHAR(255) |  | 密码哈希 |
| nickname | VARCHAR(255) |  | 昵称 |
| icon | VARCHAR(255) |  | 头像 |
| type | VARCHAR(64) | 枚举 | 账号类型；SQL 初始化使用 `admin`，代码枚举为 `admin`、`user` |
| status | TINYINT | 枚举 | 账号状态；`0=deleted`、`1=normal`、`2=disabled` |
| gmt_create | DATETIME |  | 创建时间 |
| gmt_modified | DATETIME |  | 修改时间 |
| gmt_last_login | DATETIME |  | 最近登录时间 |
| creator | VARCHAR(64) |  | 创建人账号 ID |
| modifier | VARCHAR(64) |  | 修改人账号 ID |

### 2. workspace

工作空间表，是大多数业务资源的数据隔离边界。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| workspace_id | VARCHAR(64) | UK | 工作空间业务 ID |
| account_id | VARCHAR(64) | 逻辑 FK -> account.account_id | 工作空间所属账号 |
| status | TINYINT | 枚举 | `0=deleted`、`1=normal` |
| name | VARCHAR(255) |  | 工作空间名称 |
| description | VARCHAR(4096) |  | 工作空间描述 |
| config | TEXT |  | 工作空间配置 |
| gmt_create | DATETIME |  | 创建时间 |
| gmt_modified | DATETIME |  | 修改时间 |
| creator | VARCHAR(64) |  | 创建人账号 ID |
| modifier | VARCHAR(64) |  | 修改人账号 ID |

### 3. api_key

外部 OpenAPI 调用凭证表，保存账号维度签发的 API Key。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| account_id | VARCHAR(64) | 逻辑 FK -> account.account_id | API Key 所属账号 |
| api_key | VARCHAR(512) | UK | API Key 明文 / 密钥值 |
| status | TINYINT | 枚举 | `0=deleted`、`1=normal` |
| description | VARCHAR(4096) |  | 用途说明 |
| gmt_create | DATETIME |  | 创建时间 |
| gmt_modified | DATETIME |  | 修改时间 |
| creator | VARCHAR(64) |  | 创建人账号 ID |
| modifier | VARCHAR(64) |  | 修改人账号 ID |

## 二、应用、版本、组件与引用

### 4. application

应用主表，表示 Agent 或 Workflow 应用的基础信息。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| workspace_id | VARCHAR(64) | 逻辑 FK -> workspace.workspace_id | 所属工作空间 |
| app_id | VARCHAR(64) | UK | 应用业务 ID |
| name | VARCHAR(255) |  | 应用名称 |
| description | VARCHAR(4096) |  | 应用描述 |
| icon | VARCHAR(255) |  | 应用图标 |
| source | VARCHAR(64) |  | 应用来源 |
| type | VARCHAR(64) | 枚举 | 应用类型；SQL 注释为 `agent`、`workflow` |
| status | TINYINT | 枚举 | `0=deleted`、`1=draft`、`2=published`、`3=publishedEditing` |
| gmt_create | DATETIME |  | 创建时间 |
| gmt_modified | DATETIME |  | 修改时间 |
| creator | VARCHAR(64) |  | 创建人账号 ID |
| modifier | VARCHAR(64) |  | 修改人账号 ID |

### 5. application_version

应用版本表，保存应用发布 / 草稿版本的完整配置。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| app_id | VARCHAR(64) | 逻辑 FK -> application.app_id | 应用业务 ID |
| workspace_id | VARCHAR(64) | 逻辑 FK -> workspace.workspace_id | 所属工作空间 |
| config | LONGTEXT |  | 应用配置 JSON，通常包含 Agent 或 Workflow 编排配置 |
| status | TINYINT | 枚举 | `0=deleted`、`1=draft`、`2=published`、`3=publishedEditing` |
| version | VARCHAR(32) |  | 版本号，默认 `0.0.1` |
| description | VARCHAR(4096) |  | 版本描述 |
| gmt_create | DATETIME |  | 创建时间 |
| gmt_modified | DATETIME |  | 修改时间 |
| creator | VARCHAR(64) |  | 创建人账号 ID |
| modifier | VARCHAR(64) |  | 修改人账号 ID |

### 6. application_component

组件服务表，将已发布应用封装成可复用组件。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| gmt_create | DATETIME |  | 创建时间 |
| gmt_modified | DATETIME |  | 修改时间 |
| code | VARCHAR(64) |  | 组件编码 |
| name | VARCHAR(128) |  | 组件名称 |
| workspace_id | VARCHAR(64) | 逻辑 FK -> workspace.workspace_id | 所属工作空间 |
| type | VARCHAR(64) | 枚举 | 组件类型；SQL 注释为 `agent`、`workflow`，代码枚举含 `basic`、`workflow` |
| app_id | VARCHAR(64) | 逻辑 FK -> application.app_id | 来源应用 ID |
| config | LONGTEXT |  | 组件配置 |
| description | VARCHAR(4096) |  | 组件描述 |
| status | TINYINT | 枚举 | `0=deleted`、`1=normal`、`2=published` |
| creator | VARCHAR(64) |  | 创建人账号 ID |
| modifier | VARCHAR(64) |  | 修改人账号 ID |
| need_update | TINYINT | 枚举 | `0=无需更新`、`1=需要更新` |

### 7. reference

资源引用关系表，用于记录某个主资源引用了另一个资源。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| gmt_create | DATETIME |  | 创建时间 |
| gmt_modified | DATETIME |  | 修改时间 |
| main_code | VARCHAR(64) |  | 主资源编码 |
| main_type | TINYINT | 枚举 | 主资源类型，具体枚举未在 SQL 中展开 |
| refer_code | VARCHAR(64) |  | 被引用资源编码 |
| refer_type | TINYINT | 枚举 | 被引用资源类型，具体枚举未在 SQL 中展开 |
| workspace_id | VARCHAR(64) | 逻辑 FK -> workspace.workspace_id | 所属工作空间 |

## 三、工具、插件与 MCP

### 8. plugin

插件表，是工具的归属容器。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| plugin_id | VARCHAR(64) | UK | 插件业务 ID |
| workspace_id | VARCHAR(64) | 逻辑 FK -> workspace.workspace_id | 所属工作空间 |
| type | VARCHAR(64) | 枚举 | 插件类型；SQL 注释为 `1=official`、`2=custom` |
| status | TINYINT | 枚举 | `0=deleted`、`1=normal` |
| name | VARCHAR(255) |  | 插件名称 |
| description | VARCHAR(4096) |  | 插件描述 |
| config | TEXT |  | 插件配置 |
| source | VARCHAR(64) |  | 插件来源 |
| gmt_create | DATETIME |  | 创建时间 |
| gmt_modified | DATETIME |  | 修改时间 |
| creator | VARCHAR(64) |  | 创建人账号 ID |
| modifier | VARCHAR(64) |  | 修改人账号 ID |

### 9. tool

工具表，表示插件下可执行的具体工具。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| plugin_id | VARCHAR(64) | 逻辑 FK -> plugin.plugin_id | 所属插件 |
| tool_id | VARCHAR(64) | UK | 工具业务 ID |
| workspace_id | VARCHAR(64) | 逻辑 FK -> workspace.workspace_id | 所属工作空间 |
| status | TINYINT | 枚举 | SQL 注释为 `0=deleted`、`1=normal`；代码 `ToolStatus` 为 `0=deleted`、`1=draft`、`2=published`、`3=published_editing` |
| enabled | TINYINT | 枚举 | `0=disabled`、`1=enabled` |
| test_status | TINYINT | 枚举 | `1=not_test`、`2=passed`、`3=failed` |
| name | VARCHAR(255) |  | 工具名称 |
| description | VARCHAR(4096) |  | 工具描述 |
| config | LONGTEXT |  | 工具执行配置 |
| api_schema | LONGTEXT |  | 工具 API Schema |
| gmt_create | DATETIME |  | 创建时间 |
| gmt_modified | DATETIME |  | 修改时间 |
| creator | VARCHAR(64) |  | 创建人账号 ID |
| modifier | VARCHAR(64) |  | 修改人账号 ID |

### 10. mcp_server

MCP Server 表，保存 MCP 工具源的部署和连接配置。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| gmt_create | DATETIME |  | 创建时间 |
| gmt_modified | DATETIME |  | 修改时间 |
| server_code | VARCHAR(64) |  | MCP Server 编码 |
| name | VARCHAR(64) |  | MCP Server 名称 |
| description | VARCHAR(1024) |  | 描述 |
| source | VARCHAR(128) |  | 来源 |
| deploy_env | VARCHAR(16) | 枚举 | 部署环境；SQL 注释为 `local`、`remote` |
| type | VARCHAR(32) | 枚举 | `OFFICIAL`、`CUSTOMER` |
| deploy_config | TEXT |  | 部署配置 |
| workspace_id | VARCHAR(64) | 逻辑 FK -> workspace.workspace_id | 所属工作空间，可为空 |
| account_id | VARCHAR(64) | 逻辑 FK -> account.account_id | 所属账号，可为空 |
| status | TINYINT | 枚举 | `0=unavailable`、`1=normal`、`3=deleted` |
| biz_type | VARCHAR(512) |  | 业务类型 |
| detail_config | TEXT |  | 详细配置 |
| host | VARCHAR(1024) |  | 服务地址 |
| install_type | VARCHAR(32) | 枚举 | 安装 / 连接类型；SQL 注释为 `npx`、`uvx`、`sse` |

## 四、知识库与文档

### 11. knowledge_base

知识库表，保存知识库基础配置和索引 / 检索配置。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| workspace_id | VARCHAR(64) | 逻辑 FK -> workspace.workspace_id | 所属工作空间 |
| kb_id | VARCHAR(64) | UK | 知识库业务 ID |
| type | VARCHAR(64) | 枚举 | 知识库类型；代码枚举为 `unstructured`、`structured`，SQL 注释默认 `unstructured` |
| status | TINYINT | 枚举 | `0=deleted`、`1=normal` |
| name | VARCHAR(255) |  | 知识库名称 |
| description | VARCHAR(4096) |  | 知识库描述 |
| process_config | TEXT |  | 文档处理 / 分块配置 |
| index_config | TEXT |  | 索引配置 |
| search_config | TEXT |  | 检索配置 |
| total_docs | BIGINT UNSIGNED |  | 文档总数 |
| gmt_create | DATETIME |  | 创建时间 |
| gmt_modified | DATETIME |  | 修改时间 |
| creator | VARCHAR(64) |  | 创建人账号 ID |
| modifier | VARCHAR(64) |  | 修改人账号 ID |

配置说明：

- `index_config` 中的 `embedding_provider` 和 `embedding_model` 是知识库向量化必需配置。
- `search_config` 中的 `rerank_provider` 和 `rerank_model` 可为空；为空时应配合 `enable_rerank=false`，检索不调用 Rerank。

### 12. document

文档表，保存知识库中的文件 / URL / OSS 文档及其解析索引状态。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| workspace_id | VARCHAR(64) | 逻辑 FK -> workspace.workspace_id | 所属工作空间 |
| kb_id | VARCHAR(64) | 逻辑 FK -> knowledge_base.kb_id | 所属知识库 |
| doc_id | VARCHAR(64) | UK | 文档业务 ID |
| type | VARCHAR(64) | 枚举 | 文档来源类型；`file`、`url`、`oss` |
| status | TINYINT | 枚举 | `0=deleted`、`1=normal` |
| enabled | TINYINT | 枚举 | `0=disabled`、`1=enabled` |
| name | VARCHAR(255) |  | 文档名称 |
| format | VARCHAR(64) |  | 文档格式 |
| size | BIGINT |  | 文档大小 |
| metadata | TEXT |  | 文档元数据 |
| index_status | TINYINT | 枚举 | 代码枚举为 `1=uploaded`、`2=processing`、`3=processed`、`4=failed`；SQL 注释只写到 `1=pending`、`2=processing`、`3=completed` |
| path | VARCHAR(512) |  | 原始文件存储路径 |
| parsed_path | VARCHAR(512) |  | 解析结果路径 |
| process_config | TEXT |  | 文档级处理 / 分块配置 |
| source | VARCHAR(255) |  | 文档来源 |
| error | TEXT |  | 处理错误信息 |
| gmt_create | TIMESTAMP |  | 创建时间 |
| gmt_modified | TIMESTAMP |  | 修改时间 |
| creator | VARCHAR(64) |  | 创建人账号 ID |
| modifier | VARCHAR(64) |  | 修改人账号 ID |

## 五、模型与 Provider

### 13. provider

模型 Provider 表，保存模型供应商及访问凭证。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT | PK | 自增主键 |
| workspace_id | VARCHAR(64) | 逻辑 FK -> workspace.workspace_id | 所属工作空间，可为空 |
| icon | VARCHAR(255) |  | Provider 图标 |
| name | VARCHAR(255) |  | Provider 展示名称 |
| description | VARCHAR(1024) |  | Provider 描述 |
| provider | VARCHAR(255) |  | Provider 标识 |
| enable | TINYINT | 枚举 | `0=disabled`、`1=enabled` |
| source | VARCHAR(64) | 枚举 | `preset`、`custom` |
| credential | VARCHAR(1024) |  | 访问凭证 JSON |
| supported_model_types | VARCHAR(255) |  | 支持的模型类型，逗号分隔 |
| protocol | VARCHAR(64) |  | 协议，默认 OpenAI 兼容协议 |
| gmt_create | DATETIME |  | 创建时间 |
| gmt_modified | DATETIME |  | 修改时间 |
| creator | VARCHAR(64) |  | 创建人 |
| modifier | VARCHAR(64) |  | 修改人 |

### 14. model

模型表，保存具体可调用模型。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT | PK | 自增主键 |
| workspace_id | VARCHAR(64) | 逻辑 FK -> workspace.workspace_id | 所属工作空间，可为空 |
| icon | VARCHAR(255) |  | 模型图标 |
| name | VARCHAR(100) |  | 模型展示名称 |
| type | VARCHAR(100) | 枚举 | 模型类型；初始化数据含 `llm`、`text_embedding`、`rerank` |
| mode | VARCHAR(100) |  | 调用模式，初始化数据为 `chat` |
| model_id | VARCHAR(100) |  | 模型标识 |
| provider | VARCHAR(100) | 逻辑 FK -> provider.provider | Provider 标识 |
| enable | TINYINT | 枚举 | `0=disabled`、`1=enabled` |
| tags | VARCHAR(255) |  | 能力标签，例如 `web_search`、`function_call`、`reasoning`、`vision`、`embedding` |
| source | VARCHAR(100) | 枚举 | `preset`、`custom` |

注意：模型选择器按 `type` 过滤，`tags` 只表达能力标签。Embedding 模型必须设置 `type=text_embedding`；只给 `tags` 添加 `embedding` 不会让知识库 Embedding 下拉框选到该模型。
| gmt_create | DATETIME |  | 创建时间 |
| gmt_modified | DATETIME |  | 修改时间 |
| creator | VARCHAR(64) |  | 创建人 |
| modifier | VARCHAR(64) |  | 修改人 |

### 15. model_config

Studio 评测 / Prompt 调试使用的模型配置表。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT | PK | 自增主键 |
| name | VARCHAR(100) | UK | 配置名称 |
| provider | VARCHAR(50) |  | 提供商，例如 `openai`、`azure` |
| model_name | VARCHAR(100) |  | 模型标识符 |
| base_url | VARCHAR(500) |  | 模型服务地址 |
| api_key | VARCHAR(500) |  | API 密钥 |
| default_parameters | JSON |  | 默认参数配置 |
| supported_parameters | JSON |  | 支持的参数定义 |
| status | TINYINT | 枚举 | `1=enabled`、`0=disabled` |
| create_time | DATETIME |  | 创建时间 |
| update_time | DATETIME |  | 更新时间 |
| deleted | TINYINT | 枚举 | `0=未删除`、`1=已删除` |

## 六、Agent Schema

### 16. agent_schema

Agent Schema 表，保存 Agent 模板 / 编排定义。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| agent_id | VARCHAR(64) | UK | Agent 业务 ID |
| workspace_id | VARCHAR(64) | 逻辑 FK -> workspace.workspace_id | 所属工作空间 |
| name | VARCHAR(255) |  | Agent 名称 |
| description | VARCHAR(4096) |  | Agent 描述 |
| type | VARCHAR(64) | 枚举 | `ReactAgent`、`ParallelAgent`、`SequentialAgent`、`LLMRoutingAgent`、`LoopAgent` |
| instruction | TEXT |  | 系统指令 |
| input_keys | TEXT |  | 输入变量键 JSON |
| output_key | VARCHAR(255) |  | 输出变量键 |
| handle | LONGTEXT |  | Handle 配置 JSON |
| sub_agents | LONGTEXT |  | 子 Agent 配置 JSON |
| yaml_schema | LONGTEXT |  | 生成的 YAML Schema |
| status | VARCHAR(64) | 枚举 | SQL 注释为 `DRAFT`、`PUBLISHED`、`ARCHIVED` |
| enabled | TINYINT | 枚举 | `0=disabled`、`1=enabled` |
| gmt_create | DATETIME |  | 创建时间 |
| gmt_modified | DATETIME |  | 修改时间 |
| creator | VARCHAR(64) |  | 创建人账号 ID |
| modifier | VARCHAR(64) |  | 修改人账号 ID |

## 七、Prompt 管理

### 17. prompt

Prompt 主表，保存 Prompt 的稳定业务键和最新版本。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| prompt_key | VARCHAR(255) | UK | Prompt 业务键 |
| prompt_desc | VARCHAR(255) |  | Prompt 描述 |
| latest_version | VARCHAR(32) |  | 最新版本号 |
| tags | VARCHAR(255) |  | 标签 |
| create_time | DATETIME(3) |  | 创建时间 |
| update_time | DATETIME(3) |  | 更新时间 |

### 18. prompt_version

Prompt 版本表，保存每个版本的模板、变量和调试模型配置。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| version | VARCHAR(32) |  | 版本号 |
| prompt_key | VARCHAR(255) | 逻辑 FK -> prompt.prompt_key | Prompt 业务键 |
| version_desc | VARCHAR(255) |  | 版本描述 |
| template | LONGTEXT |  | Prompt 模板内容 |
| variables | LONGTEXT |  | 模板变量 |
| model_config | LONGTEXT |  | 调试该 Prompt 的模型参数 JSON |
| status | VARCHAR(32) | 枚举 | `pre=预发布版本`、`release=正式版本` |
| create_time | DATETIME(3) |  | 创建时间 |
| previous_version | VARCHAR(32) |  | 前置版本，用于对比 |

### 19. prompt_build_template

Prompt 构建模板表，保存可复用的 Prompt 模板。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| prompt_template_key | VARCHAR(255) | UK | Prompt 模板业务键 |
| tags | VARCHAR(255) |  | 标签 |
| template_desc | VARCHAR(255) |  | 模板描述 |
| template | LONGTEXT |  | 模板内容 |
| variables | LONGTEXT |  | 模板变量 |
| model_config | LONGTEXT |  | 推荐模型参数 |

## 八、数据集、评估器与实验

### 20. dataset

评测数据集主表，保存数据集定义和列结构配置。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| name | VARCHAR(255) |  | 数据集名称 |
| description | TEXT |  | 数据集描述 |
| columns_config | LONGTEXT |  | 列结构配置 JSON |
| create_time | DATETIME |  | 创建时间 |
| update_time | DATETIME |  | 更新时间 |
| deleted | TINYINT | 枚举 | `0=未删除`、`1=已删除` |

### 21. dataset_version

数据集版本表，保存某个数据集版本的状态和数据快照引用。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| dataset_id | BIGINT UNSIGNED | FK -> dataset.id | 所属数据集 |
| version | VARCHAR(32) |  | 版本号 |
| description | TEXT |  | 版本描述 |
| data_count | INT |  | 当前版本数据量 |
| status | VARCHAR(32) | 枚举 | SQL 注释为 `DRAFT`、`PUBLISHED`、`ARCHIVED`；代码枚举含 `DRAFT`、`PUBLISHED` |
| experiments | TEXT |  | 实验集合 JSON |
| dataset_items | TEXT |  | 数据项集合 JSON |
| create_time | DATETIME |  | 创建时间 |
| update_time | DATETIME |  | 更新时间 |

### 22. dataset_item

数据集条目表，保存评测样本的 JSON 内容。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| dataset_id | BIGINT UNSIGNED | FK -> dataset.id | 所属数据集 |
| columns_config | LONGTEXT |  | 列结构配置 JSON |
| data_content | LONGTEXT |  | 数据内容 JSON |
| create_time | DATETIME |  | 创建时间 |
| update_time | DATETIME |  | 更新时间 |
| deleted | TINYINT | 枚举 | `0=未删除`、`1=已删除` |

### 23. evaluator

评估器主表，保存评估器基础信息。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| name | VARCHAR(255) |  | 评估器名称 |
| description | TEXT |  | 评估器描述 |
| create_time | DATETIME |  | 创建时间 |
| update_time | DATETIME |  | 更新时间 |
| deleted | TINYINT | 枚举 | `0=未删除`、`1=已删除` |

### 24. evaluator_version

评估器版本表，保存评估 Prompt、变量和模型配置。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| evaluator_id | BIGINT UNSIGNED | FK -> evaluator.id | 所属评估器 |
| description | TEXT |  | 版本描述 |
| version | VARCHAR(32) |  | 版本号 |
| model_config | TEXT |  | 模型配置 |
| prompt | LONGTEXT |  | 评估 Prompt 配置 JSON |
| variables | LONGTEXT |  | Prompt 变量参数 |
| status | VARCHAR(32) | 枚举 | SQL 注释为 `DRAFT`、`PUBLISHED`、`ARCHIVED`；代码枚举含 `DRAFT`、`PUBLISHED` |
| experiments | TEXT |  | 实验集合 JSON |
| create_time | DATETIME |  | 创建时间 |
| update_time | DATETIME |  | 更新时间 |

### 25. evaluator_template

评估器模板表，保存可复用的评估 Prompt 模板。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| evaluator_template_key | VARCHAR(255) | UK | 评估器模板业务键 |
| template_desc | VARCHAR(255) |  | 模板描述 |
| template | LONGTEXT |  | 模板内容 |
| variables | LONGTEXT |  | 模板变量 |
| model_config | LONGTEXT |  | 推荐模型参数 |

### 26. experiment

实验表，表示一次基于数据集版本和评估器配置的评测任务。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| name | VARCHAR(255) |  | 实验名称 |
| description | TEXT |  | 实验描述 |
| dataset_id | BIGINT UNSIGNED | 逻辑 FK -> dataset.id | 数据集 ID |
| dataset_version_id | BIGINT UNSIGNED | 逻辑 FK -> dataset_version.id | 数据集版本 ID |
| dataset_version | VARCHAR(32) |  | 数据集版本号 |
| evaluation_object_config | LONGTEXT |  | 被评测对象配置 JSON |
| evaluator_config | TEXT |  | 评估器配置 |
| status | VARCHAR(32) | 枚举 | `DRAFT`、`RUNNING`、`COMPLETED`、`FAILED`、`STOPPED` |
| progress | INT |  | 进度百分比，0-100 |
| complete_time | DATETIME |  | 完成时间 |
| create_time | DATETIME |  | 创建时间 |
| update_time | DATETIME |  | 更新时间 |

### 27. experiment_result

实验结果表，保存单条样本的评测输出、评分和理由。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK | 自增主键 |
| experiment_id | BIGINT UNSIGNED | 逻辑 FK -> experiment.id | 所属实验 |
| input | LONGTEXT |  | 输入内容 |
| actual_output | LONGTEXT |  | 被评测对象实际输出 |
| reference_output | LONGTEXT |  | 参考输出 |
| score | DECIMAL(3,2) |  | 评估分数，0.00-1.00 |
| reason | TEXT |  | 评估理由 |
| evaluation_time | DATETIME |  | 评估执行时间 |
| evaluator_version_id | BIGINT UNSIGNED | 逻辑 FK -> evaluator_version.id | 使用的评估器版本 |
| create_time | DATETIME |  | 创建时间 |
| update_time | DATETIME |  | 更新时间 |

## 九、代码存在但 SQL 未发现的模型

### 28. LimitEntity

限流配置对象，当前未发现对应 `@TableName` 和建表 SQL，更像嵌入式配置模型。

| 字段 | 类型 | 标记 | 说明 |
| --- | --- | --- | --- |
| count | int |  | 允许的最大操作次数 |
| time | long |  | 限流时间窗口，单位毫秒 |

## 关键关系说明

### 显式数据库外键

| 来源字段 | 目标字段 | 关系 |
| --- | --- | --- |
| dataset_version.dataset_id | dataset.id | 一个数据集有多个版本 |
| dataset_item.dataset_id | dataset.id | 一个数据集有多条数据 |
| evaluator_version.evaluator_id | evaluator.id | 一个评估器有多个版本 |

### 逻辑外键 / 业务关联

| 来源字段 | 目标字段 | 关系 |
| --- | --- | --- |
| workspace.account_id | account.account_id | 一个账号拥有多个工作空间 |
| api_key.account_id | account.account_id | 一个账号可签发多个 API Key |
| application.workspace_id | workspace.workspace_id | 一个工作空间下有多个应用 |
| application_version.app_id | application.app_id | 一个应用有多个版本 |
| application_component.app_id | application.app_id | 应用可发布为组件 |
| plugin.workspace_id | workspace.workspace_id | 一个工作空间下有多个插件 |
| tool.plugin_id | plugin.plugin_id | 一个插件下有多个工具 |
| knowledge_base.workspace_id | workspace.workspace_id | 一个工作空间下有多个知识库 |
| document.kb_id | knowledge_base.kb_id | 一个知识库下有多个文档 |
| provider.workspace_id | workspace.workspace_id | 一个工作空间下可配置多个 Provider |
| model.provider | provider.provider | 一个 Provider 下有多个模型 |
| agent_schema.workspace_id | workspace.workspace_id | Agent Schema 归属工作空间 |
| prompt_version.prompt_key | prompt.prompt_key | 一个 Prompt 有多个版本 |
| experiment.dataset_version_id | dataset_version.id | 实验使用某个数据集版本 |
| experiment_result.experiment_id | experiment.id | 一个实验产生多条结果 |
| experiment_result.evaluator_version_id | evaluator_version.id | 结果由某个评估器版本打分 |

## 枚举值汇总

| 字段 / 枚举 | 取值 |
| --- | --- |
| CommonStatus | `0=deleted`、`1=normal` |
| AccountStatus | `0=deleted`、`1=normal`、`2=disabled` |
| AccountType | `admin`、`user`；SQL 初始化数据使用 `admin` |
| application.type | `agent`、`workflow` |
| application.status / application_version.status | `0=deleted`、`1=draft`、`2=published`、`3=publishedEditing` |
| tool.status | SQL 注释：`0=deleted`、`1=normal`；代码枚举：`0=deleted`、`1=draft`、`2=published`、`3=published_editing` |
| tool.enabled / document.enabled / model.enable / provider.enable | `0=disabled`、`1=enabled` |
| tool.test_status | `1=not_test`、`2=passed`、`3=failed` |
| knowledge_base.type | `unstructured`、`structured` |
| document.type | `file`、`url`、`oss` |
| document.index_status | 代码枚举：`1=uploaded`、`2=processing`、`3=processed`、`4=failed` |
| mcp_server.type | `OFFICIAL`、`CUSTOMER` |
| mcp_server.status | `0=unavailable`、`1=normal`、`3=deleted` |
| mcp_server.deploy_env | `local`、`remote` |
| mcp_server.install_type | `npx`、`uvx`、`sse` |
| provider.source / model.source | `preset`、`custom` |
| model.type | 初始化数据含 `llm`、`text_embedding`、`rerank` |
| agent_schema.type | `ReactAgent`、`ParallelAgent`、`SequentialAgent`、`LLMRoutingAgent`、`LoopAgent` |
| agent_schema.status | SQL 注释：`DRAFT`、`PUBLISHED`、`ARCHIVED` |
| prompt_version.status | `pre=预发布版本`、`release=正式版本` |
| dataset_version.status / evaluator_version.status | SQL 注释：`DRAFT`、`PUBLISHED`、`ARCHIVED`；代码枚举含 `DRAFT`、`PUBLISHED` |
| experiment.status | `DRAFT`、`RUNNING`、`COMPLETED`、`FAILED`、`STOPPED` |
| model_config.status | `1=启用`、`0=禁用` |
| deleted 字段 | `0=未删除`、`1=已删除` |
