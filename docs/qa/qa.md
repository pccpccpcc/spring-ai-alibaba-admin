# 项目接口与业务概念问答

本文整理接口清单梳理过程中较容易混淆、但有助于理解系统边界的问题。

## 1. API Key 是做什么的？为什么不放在账号登录里？

API Key 是给外部系统调用本平台 OpenAPI 使用的访问凭证，不是控制台用户登录凭证。

例如外部服务调用：

```text
POST /api/v1/apps/chat/completions
POST /api/v1/apps/workflow/completions
```

会通过请求头携带：

```text
Authorization: Bearer xxx
```

后端拦截 `/api/v1/**` 请求后，会用这个 API Key 找到所属账号，再以该账号上下文执行聊天或工作流请求。

因此它更适合单独归到 `API Key` 或“开放接口凭证”模块，而不是放在“认证 / 账号”里。认证 / 账号主要处理控制台登录、刷新 Token、退出、账号 CRUD 等能力。

## 2. 插件、插件工具、工具全局管理有什么区别？

插件是能力包或外部系统配置容器，插件工具是插件里的具体可调用动作。

关系可以理解为：

```text
Plugin
  -> Tool 1
  -> Tool 2
  -> Tool 3
```

例如：

```text
高德地图插件
  -> 搜索 POI 工具
  -> 查询路线工具
```

`/console/v1/plugins/{pluginId}/tools` 是从“插件详情页”视角管理某个插件下的工具。

`/console/v1/tools` 是从“全局工具列表”视角管理工具记录，可以查全部工具、按名称搜索、按插件过滤、启用禁用等。当前源码中它直接暴露 `ToolEntity`，比插件工具接口更底层。

## 3. 一个工具是否可以属于多个插件？

从当前数据模型看，不可以。

`Tool` 和 `ToolEntity` 都只有一个 `pluginId` 字段。创建插件工具时会绑定 `pluginId`，查询插件工具时也按 `pluginId` 过滤。删除插件时，该插件下的工具会一起被标记删除。

因此当前关系是：

```text
一个 Plugin -> 多个 Tool
一个 Tool -> 一个 Plugin
```

但“归属一个插件”不等于“只能被一个地方使用”。工具可以被多个应用、Agent 或工作流引用和调用。

## 4. MCP Server 和插件工具是什么关系？

MCP Server 和插件工具不是包含关系，而是两种不同的工具来源。

插件工具是平台自定义的插件体系：

```text
Plugin -> Tool
```

它通过平台配置 HTTP path、method、输入输出参数和认证方式。

MCP Server 是通过 MCP 协议接入的一组外部工具：

```text
MCP Server -> MCP Tool
```

工作流执行时，插件工具走 `PluginExecuteProcessor`，MCP 工具走 `MCPExecuteProcessor`。二者都偏“工具调用”，但协议和配置模型不同。

## 5. 组件服务和工具有什么区别？

组件服务不是工具。组件服务是把已发布的 Agent 或 Workflow 应用封装成可复用组件。

工具粒度较小，通常是一个具体动作，例如查询订单、查天气、发消息。

组件粒度较大，通常是一个可复用子应用或子流程，例如：

```text
合同审查 Agent
客服工单分类 Workflow
```

关系可以理解为：

```text
工具 = 一个函数 / 一个 API 动作
组件 = 一个可复用的小应用 / 子工作流
```

在工作流中，工具节点调用插件工具或 MCP 工具；组件节点调用已发布的 Agent / Workflow 组件。

## 6. 应用、Agent、Workflow、工具、组件、Graph Studio 之间是什么关系？

Application 是平台中的顶层业务资产。根据类型不同，应用可以是 Agent 应用，也可以是 Workflow 应用。

```text
Application
  -> Agent Application
  -> Workflow Application
```

Agent 偏对话式智能体，配置里包含模型、系统指令、记忆、插件工具、MCP Server、组件和 Prompt 变量。

Workflow 偏流程编排，由节点和边组成。节点可以调用模型、插件工具、MCP 工具、组件、知识库、脚本、分支、并行等能力。

工具是 Agent / Workflow 可调用的小能力。组件是 Agent / Workflow 可复用的大能力。

Graph Studio 是另一条偏 DSL、图应用、代码生成和运行调试的链路，接口路径为 `/graph-studio/api/**`。它和控制台应用管理 `/console/v1/apps` 相关但不是同一个接口模块。

## 7. Workspace 和 Agent Schema 是什么关系？

Workspace 是资源隔离空间，可以理解为项目空间或租户空间。应用、知识库、插件、工具、MCP Server、组件等资源通常都会挂在某个 `workspaceId` 下。

Agent Schema 是某个工作空间中的 Agent 定义或模板资源，包含：

```text
agentId
workspaceId
name
instruction
inputKeys
outputKey
handle
subAgents
yamlSchema
enabled
status
```

关系是：

```text
Workspace
  -> Agent Schema 1
  -> Agent Schema 2
```

但这不代表 Agent Schema 应该放在 Workspace 模块下。很多资源都有 `workspaceId`，更合理的文档分组仍然是将 Workspace 和 Agent Schema 独立拆开。

## 8. 应用和 Agent Schema 是什么关系？

从当前源码看，Application 和 Agent Schema 没有强绑定关系。

Application 是可运行、可发布、可复制、可对外调用的应用资产。如果应用类型是 Agent，它的运行配置是 `AgentConfig`，包括模型、指令、工具、MCP Server、组件等。

Agent Schema 更像 Agent 的结构定义或模板资源，包含输入输出、指令、子 Agent、YAML Schema 等。

当前没有看到 `Application`、`AppEntity`、`AppVersionEntity` 或 `AgentConfig` 直接引用 `agentSchemaId` / `agentId` 的字段。因此更准确的理解是：

```text
Application = 运行态应用配置
Agent Schema = Agent 的结构 / 模板定义资源
```

二者都按 Workspace 隔离，但不是必然的一对一关系。

## 9. Prompt 为什么要和数据集、评估器、实验拆开？

Prompt 是可管理、可版本化、可调试、可用于实验评测的提示词资产。

数据集是测试样本集合；评估器是打分规则或评估逻辑；实验是把 Prompt、数据集、评估器组合起来批量运行并生成结果的任务。

它们在实验链路中会组合使用：

```text
Prompt 版本
  + 数据集样本
  + 评估器
  -> 实验
  -> 评估结果
```

但资源语义不同，因此文档里拆成独立模块更清晰：

```text
Prompt 管理
数据集管理
评估器管理
实验管理
```

## 10. 为什么接口清单里没有测试示例接口？

源码中有 `ApiExampleController`，包含：

```text
GET  /test/api/example/getOrder
POST /test/api/example/getOrder
POST /test/api/example/getOrder/{orderId}
```

这些接口路径带 `/test/api/example/**`，更像开发或调试用样例接口，不属于正式业务 API 模块。

因此在最终按业务模块重排的接口清单中没有纳入这 3 个接口。排除它们后，当前文档接口数量与正式 Controller 接口数量一致。
