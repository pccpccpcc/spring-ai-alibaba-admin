# 1. 认证 / 账号

## 1.1 登录认证

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/auth/login` | 用户登录并获取访问令牌。 | Body: `LoginRequest` | `Result<TokenResponse>` |
| POST | `/console/v1/auth/refresh-token` | 刷新访问令牌。 | Body: `RefreshTokenRequest` | `Result<TokenResponse>` |
| POST | `/console/v1/auth/logout` | 退出当前登录会话。 | Header: 认证信息 | `Result<Void>` |

## 1.2 账号管理

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/accounts` | 创建账号。 | Body: `Account` | `Result<String>` |
| PUT | `/console/v1/accounts/{accountId}` | 更新账号信息。 | Path: `accountId`; Body: `Account` | `Result<String>` |
| DELETE | `/console/v1/accounts/{accountId}` | 删除账号。 | Path: `accountId` | `Result<Void>` |
| GET | `/console/v1/accounts/{accountId}` | 查询账号详情。 | Path: `accountId` | `Result<Account>` |
| GET | `/console/v1/accounts` | 分页查询账号列表。 | Query: `BaseQuery` | `Result<PagingList<Account>>` |
| PUT | `/console/v1/accounts/change-password` | 修改账号密码。 | Body: `ChangePasswordRequest` | `Result<String>` |
| GET | `/console/v1/accounts/profile` | 查询当前账号资料。 | Header: 认证信息 | `Result<Account>` |


# 2. Prompt 管理

## 2.1 Prompt 基础管理

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/api/prompt` | 创建 Prompt。 | Body: `PromptCreateRequest` | `Result<Prompt>` |
| GET | `/api/prompt` | 按 key 查询 Prompt。 | Query: `promptKey` | `Result<Prompt>` |
| GET | `/api/prompts` | 分页查询 Prompt 列表。 | Query: `PromptListRequest` | `Result<PageResult<Prompt>>` |
| PUT | `/api/prompt` | 更新 Prompt。 | Body: `PromptUpdateRequest` | `Result<Prompt>` |
| DELETE | `/api/prompt` | 删除 Prompt。 | Query: `promptKey` | `Result<Boolean>` |

## 2.2 Prompt 版本与模板

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/api/prompt/version` | 创建 Prompt 版本。 | Body: `PromptVersionCreateRequest` | `Result<PromptVersion>` |
| GET | `/api/prompt/version` | 查询指定 Prompt 版本详情。 | Query: `promptKey`, `version` | `Result<PromptVersionDetail>` |
| GET | `/api/prompt/versions` | 分页查询 Prompt 版本。 | Query: `PromptVersionListRequest` | `Result<PageResult<PromptVersion>>` |
| GET | `/api/prompt/template` | 查询 Prompt 模板详情。 | Query: `promptTemplateKey` | `Result<PromptTemplateDetail>` |
| GET | `/api/prompt/templates` | 分页查询 Prompt 模板。 | Query: `PromptTemplateListRequest` | `Result<PageResult<PromptTemplate>>` |

## 2.3 Prompt 运行与会话

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/api/prompt/run` | 运行 Prompt 并流式返回结果。 | Body: `PromptRunRequest` | `Flux<PromptRunResponse>` |
| GET | `/api/prompt/session` | 查询 Prompt 会话。 | Query: `sessionId` | `Result<ChatSession>` |
| DELETE | `/api/prompt/session` | 删除 Prompt 会话。 | Query: `sessionId` | `Result<Void>` |


# 3. 数据集管理

## 3.1 数据集管理

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/api/dataset/dataset` | 创建数据集。 | Body: `DatasetCreateRequest` | `Result<Dataset>` |
| POST | `/api/dataset/datasetVersion` | 创建数据集版本。 | Body: `DatasetVersionCreateRequest` | `Result<DatasetVersion>` |
| GET | `/api/dataset/datasets` | 分页查询数据集。 | Query: `DatasetListRequest` | `Result<PageResult<Dataset>>` |
| GET | `/api/dataset/dataset` | 查询数据集详情。 | Query: `datasetId` | `Result<Dataset>` |
| PUT | `/api/dataset/dataset` | 更新数据集。 | Body: `DatasetUpdateRequest` | `Result<Dataset>` |
| DELETE | `/api/dataset/dataset` | 删除数据集。 | Query: `datasetId` | `Result<Void>` |

## 3.2 数据项

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/api/dataset/dataItem` | 创建数据集样本项。 | Body: `DatasetItemCreateRequest` | `Result<List<DatasetItem>>` |
| GET | `/api/dataset/dataItems` | 分页查询数据集样本项。 | Query: `DatasetItemListRequest` | `Result<PageResult<DatasetItem>>` |
| GET | `/api/dataset/dataItem` | 查询数据集样本项详情。 | Query/Path: `id` | `Result<DatasetItem>` |
| PUT | `/api/dataset/dataItem` | 更新数据集样本项。 | Body: `DatasetItemUpdateRequest` | `Result<DatasetItem>` |
| DELETE | `/api/dataset/dataItem` | 删除数据集样本项。 | Query: `id` | `Result<Void>` |

## 3.3 数据集版本与关联实验

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| GET | `/api/dataset/datasetVersions` | 分页查询数据集版本。 | Query: `DatasetVersionListRequest` | `Result<PageResult<DatasetVersion>>` |
| PUT | `/api/dataset/datasetVersion` | 更新数据集版本。 | Body: `DatasetVersionUpdateRequest` | `Result<DatasetVersion>` |
| GET | `/api/dataset/experiments` | 查询数据集关联实验。 | Query: `DatasetExperimentsListRequest` | `Result<PageResult<Experiment>>` |
| POST | `/api/dataset/dataItemFromTrace` | 从 Trace 创建数据集样本项。 | Body: `DataItemCreateFromTraceRequest` | `Result<List<DatasetItem>>` |


# 4. 评估器管理

## 4.1 评估器管理

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/api/evaluator/evaluator` | 创建评测器。 | Body: `EvaluatorCreateRequest` | `Result<Evaluator>` |
| POST | `/api/evaluator/evaluatorVersion` | 创建评测器版本。 | Body: `EvaluatorVersionCreateRequest` | `Result<EvaluatorVersion>` |
| GET | `/api/evaluator/evaluators` | 分页查询评测器。 | Query: `EvaluatorListRequest` | `Result<PageResult<Evaluator>>` |
| GET | `/api/evaluator/evaluator` | 查询评测器详情。 | Query: `id` | `Result<Evaluator>` |
| GET | `/api/evaluator/evaluatorVersions` | 分页查询评测器版本。 | Query: `EvaluatorVersionListRequest` | `Result<PageResult<EvaluatorVersion>>` |
| PUT | `/api/evaluator/evaluator` | 更新评测器。 | Body: `EvaluatorUpdateRequest` | `Result<Evaluator>` |
| DELETE | `/api/evaluator/evaluator` | 删除评测器。 | Query: `id` | `Result<Void>` |
| POST | `/api/evaluator/debug` | 调试评测器。 | Body: `EvaluatorTestRequest` | `Result<EvaluatorDebugResult>` |

## 4.2 评估器模板与关联实验

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| GET | `/api/evaluator/templates` | 分页查询评测器模板。 | Query: `EvaluatorTemplateListRequest` | `Result<PageResult<EvaluatorTemplate>>` |
| GET | `/api/evaluator/template` | 查询评测器模板详情。 | Query: `templateId` | `Result<EvaluatorTemplate>` |
| GET | `/api/evaluator/experiments` | 查询评测器关联实验。 | Query: `EvaluatorExperimentsListRequest` | `Result<PageResult<Experiment>>` |


# 5. 实验管理

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/api/experiment` | 创建实验。 | Body: `ExperimentCreateRequest` | `Result<Experiment>` |
| GET | `/api/experiments` | 分页查询实验列表。 | Query: `ExperimentListRequest` | `Result<PageResult<Experiment>>` |
| GET | `/api/experiment` | 查询实验详情。 | Query: `experimentId` | `Result<Experiment>` |
| GET | `/api/experiment/results` | 查询实验评测结果汇总。 | Query: `experimentId` | `Result<List<ExperimentEvaluatorResult>>` |
| GET | `/api/experiment/result` | 分页查询实验评测结果明细。 | Query: `ExperimentEvaluatorResultDetailListRequest` | `Result<PageResult<ExperimentEvaluatorResultDetail>>` |
| PUT | `/api/experiment/stop` | 停止实验。 | Query: `experimentId` | `Result<Experiment>` |
| DELETE | `/api/experiment` | 删除实验。 | Query: `experimentId` | `Result<Void>` |
| PUT | `/api/experiment/restart` | 重启实验。 | Query: `experimentId` | `Result<Void>` |


# 6. 模型配置（Studio）

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| GET | `/api/model/supported` | 查询评测/配置模块支持的模型供应商。 | 无 | `Result<List<String>>` |
| GET | `/api/models` | 分页查询模型配置。 | Query: `ModelConfigQueryRequest` | `Result<PageResult<ModelConfigResponse>>` |
| GET | `/api/model` | 按 ID 查询模型配置。 | Query: `id` | `Result<ModelConfigResponse>` |
| GET | `/api/models/enabled` | 查询启用的模型配置。 | 无 | `Result<List<ModelConfigResponse>>` |


# 7. 可观测性

## 7.1 Trace 查询

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| GET | `/api/observability/traces` | 分页查询 Trace 列表。 | Query: `TracesQueryRequest` | `Result<PageResult<TraceSpanDTO>>` |
| GET | `/api/observability/traces/{traceId}` | 查询 Trace 详情。 | Path: `traceId` | `Result<TraceDetailDTO>` |

## 7.2 服务与概览

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| GET | `/api/observability/services` | 查询可观测服务列表/指标。 | Query: `ServicesQueryRequest` | `Result<ServicesResponseDTO>` |
| GET | `/api/observability/overview` | 查询可观测概览统计。 | Query: `OverviewQueryRequest` | `Result<OverviewStatsDTO>` |


# 8. 应用管理

## 8.1 应用管理

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/apps` | 创建应用。 | Body: `Application` | `Result<String>` |
| PUT | `/console/v1/apps/{appId}` | 更新应用配置。 | Path: `appId`; Body: `Application` | `Result<String>` |
| DELETE | `/console/v1/apps/{appId}` | 删除应用。 | Path: `appId` | `Result<Void>` |
| GET | `/console/v1/apps/{appId}` | 查询应用详情。 | Path: `appId` | `Result<Application>` |
| GET | `/console/v1/apps` | 分页查询应用列表。 | Query: `AppQuery` | `Result<PagingList<Application>>` |
| POST | `/console/v1/apps/{appId}/publish` | 发布应用版本。 | Path: `appId` | `Result<Void>` |
| POST | `/console/v1/apps/{appId}/copy` | 复制应用。 | Path: `appId` | `Result<String>` |

## 8.2 应用版本

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| GET | `/console/v1/apps/{appId}/versions` | 分页查询应用版本列表。 | Path: `appId`; Query: `AppQuery` | `Result<PagingList<ApplicationVersion>>` |
| GET | `/console/v1/apps/{appId}/versions/{version}` | 查询指定应用版本详情。 | Path: `appId`, `version` | `Result<ApplicationVersion>` |

## 8.3 控制台会话

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/apps/chat/completions` | 控制台侧发起智能体对话补全。 | Body: `AgentRequest`; Response 可为流式或非流式 | `Object` |


# 9. 工作流调试

## 9.1 调试任务

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/apps/workflow/debug/run-task` | 启动工作流调试任务。 | Body: `TaskRunRequest` | `Result<TaskRunResponse>` |
| POST | `/console/v1/apps/workflow/debug/get-task-process` | 查询调试任务执行过程。 | Body: `ProcessGetRequest` | `Result<ProcessGetResponse>` |
| POST | `/console/v1/apps/workflow/debug/init` | 初始化工作流调试参数。 | Body: `InitRequest` | `Result<List<TaskRunParam>>` |
| POST | `/console/v1/apps/workflow/debug/resume-task` | 恢复被中断的调试任务。 | Body: `TaskResumeRequest` | `Result<TaskResumeResponse>` |
| POST | `/console/v1/apps/workflow/debug/part-graph/run-task` | 运行局部工作流图调试任务。 | Body: `TaskPartGraphRequest` | `Result<TaskPartGraphResponse>` |
| POST | `/console/v1/apps/workflow/debug/part-graph/stop-task` | 停止局部工作流图调试任务。 | Body: `TaskStopRequest` | `Result<Boolean>` |

## 9.2 运行接口

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/apps/workflow/{appId}/run_stream` | 以 SSE 方式运行指定应用工作流。 | Path: `appId`; Body: `ApiTaskRunRequest` | `SseEmitter` |


# 10. 知识库 / 文档 / 分块

## 10.1 知识库管理

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/knowledge-bases` | 创建知识库。 | Body: `KnowledgeBase` | `Result<String>` |
| PUT | `/console/v1/knowledge-bases/{kbId}` | 更新知识库。 | Path: `kbId`; Body: `KnowledgeBase` | `Result<String>` |
| DELETE | `/console/v1/knowledge-bases/{kbId}` | 删除知识库。 | Path: `kbId` | `Result<Void>` |
| GET | `/console/v1/knowledge-bases/{kbId}` | 查询知识库详情。 | Path: `kbId` | `Result<KnowledgeBase>` |
| GET | `/console/v1/knowledge-bases` | 分页查询知识库列表。 | Query: `BaseQuery` | `Result<PagingList<KnowledgeBase>>` |
| POST | `/console/v1/knowledge-bases/query-by-codes` | 按编码批量查询知识库。 | Body: `KnowledgeBaseQuery` | `Result<List<KnowledgeBase>>` |
| POST | `/console/v1/knowledge-bases/retrieve` | 从知识库检索文档分片。 | Body: `DocumentRetrieverQuery` | `Result<List<DocumentChunk>>` |

备注：创建 / 更新知识库时，`index_config.embedding_provider` 和 `index_config.embedding_model` 必填；`search_config.rerank_provider` 和 `search_config.rerank_model` 可选。未配置 Rerank 时应传或保存 `enable_rerank=false`，检索只走向量召回。

## 10.2 文档管理

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/knowledge-bases/{kbId}/documents` | 向知识库新增文档。 | Path: `kbId`; Body: `CreateDocumentRequest` | `Result<List<String>>` |
| PUT | `/console/v1/knowledge-bases/{kbId}/documents/{docId}` | 更新文档信息。 | Path: `kbId`, `docId`; Body: `Document` | `Result<Void>` |
| DELETE | `/console/v1/knowledge-bases/{kbId}/documents/{docId}` | 删除文档。 | Path: `kbId`, `docId` | `Result<Void>` |
| DELETE | `/console/v1/knowledge-bases/{kbId}/documents/batch-delete` | 批量删除文档。 | Path: `kbId`; Body: `DeleteDocumentRequest` | `Result<Void>` |
| GET | `/console/v1/knowledge-bases/{kbId}/documents/{docId}` | 查询文档详情。 | Path: `kbId`, `docId` | `Result<Document>` |
| GET | `/console/v1/knowledge-bases/{kbId}/documents` | 分页查询知识库文档。 | Path: `kbId`; Query: `DocumentQuery` | `Result<PagingList<Document>>` |
| PUT | `/console/v1/knowledge-bases/{kbId}/documents/{docId}/re-index` | 对文档重新索引。 | Path: `kbId`, `docId`; Body: `IndexDocumentRequest` | `Result<Void>` |

## 10.3 文档分块

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/documents/{docId}/chunks` | 创建文档分片。 | Path: `docId`; Body: `DocumentChunk` | `Result<String>` |
| PUT | `/console/v1/documents/{docId}/chunks/{chunkId}` | 更新文档分片。 | Path: `docId`, `chunkId`; Body: `DocumentChunk` | `Result<Void>` |
| DELETE | `/console/v1/documents/{docId}/chunks/{chunkId}` | 删除文档分片。 | Path: `docId`, `chunkId` | `Result<Void>` |
| DELETE | `/console/v1/documents/{docId}/chunks/batch-delete` | 批量删除文档分片。 | Path: `docId`; Body: `DeleteChunkRequest` | `Result<Void>` |
| GET | `/console/v1/documents/{docId}/chunks` | 分页查询文档分片。 | Path: `docId`; Query: `BaseQuery` | `Result<PagingList<DocumentChunk>>` |
| POST | `/console/v1/documents/{docId}/chunks/preview` | 预览文档切分后的分片。 | Path: `docId`; Body: `IndexDocumentRequest` | `Result<List<DocumentChunk>>` |
| PUT | `/console/v1/documents/{docId}/chunks/update-status` | 批量更新分片状态。 | Path: `docId`; Body: `UpdateChunkRequest` | `Result<Void>` |


# 11. 模型 / Provider 管理

## 11.1 Provider 配置

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/providers` | 新增模型供应商配置。 | Body: `AddProviderRequest` | `Result<Boolean>` |
| PUT | `/console/v1/providers/{provider}` | 更新模型供应商配置。 | Path: `provider`; Body: `UpdateProviderRequest` | `Result<Boolean>` |
| DELETE | `/console/v1/providers/{provider}` | 删除模型供应商配置。 | Path: `provider` | `Result<Boolean>` |
| GET | `/console/v1/providers` | 查询模型供应商列表。 | Query: `QueryProviderRequest` | `Result<List<ProviderConfigInfo>>` |
| GET | `/console/v1/providers/{provider}` | 查询模型供应商详情。 | Path: `provider` | `Result<ProviderConfigInfo>` |

## 11.2 Provider 模型

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/providers/{provider}/models` | 为供应商新增模型。 | Path: `provider`; Body: `AddModelRequest`，包含 `model_id`、`model_name`、`type`、`tags`、`icon` | `Result<Boolean>` |
| PUT | `/console/v1/providers/{provider}/models/{modelId}` | 更新供应商模型配置。 | Path: `provider`, `modelId`; Body: `UpdateModelRequest`，支持更新 `model_name`、`type`、`tags`、`icon`、`enable` | `Result<Boolean>` |
| DELETE | `/console/v1/providers/{provider}/models/{modelId}` | 删除供应商模型配置。 | Path: `provider`, `modelId` | `Result<Boolean>` |
| GET | `/console/v1/providers/{provider}/models` | 查询供应商模型列表。 | Path: `provider` | `Result<List<ModelConfigInfo>>` |
| GET | `/console/v1/providers/{provider}/models/{modelId}` | 查询供应商模型详情。 | Path: `provider`, `modelId` | `Result<ModelConfigInfo>` |
| GET | `/console/v1/providers/{provider}/models/{modelId}/parameter_rules` | 查询模型参数规则。 | Path: `provider`, `modelId` | `Result<List<ParameterRule>>` |
| GET | `/console/v1/providers/protocols` | 查询支持的供应商协议。 | 无 | `Result<List<String>>` |

## 11.3 模型选择器

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| GET | `/console/v1/models/{modelType}/selector` | 查询指定类型的模型选择器数据。 | Path: `modelType` | `Result<List<ModelProviderGroup>>` |
| GET | `/console/v1/models/enabled` | 查询已启用模型列表。 | 无 | `Result<List<Map<String,Object>>>` |

备注：模型选择器按 `model.type` 过滤，常用值为 `llm`、`text_embedding`、`rerank`。勾选 tags 不会替代 `type`；创建 Embedding 模型时必须把 `type` 设置为 `text_embedding`。


# 12. 工具 / 插件

## 12.1 插件管理

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/plugins` | 创建插件。 | Body: `Plugin` | `Result<String>` |
| PUT | `/console/v1/plugins/{pluginId}` | 更新插件。 | Path: `pluginId`; Body: `Plugin` | `Result<Void>` |
| DELETE | `/console/v1/plugins/{pluginId}` | 删除插件。 | Path: `pluginId` | `Result<Void>` |
| GET | `/console/v1/plugins/{pluginId}` | 查询插件详情。 | Path: `pluginId` | `Result<Plugin>` |
| GET | `/console/v1/plugins` | 分页查询插件列表。 | Query: `BaseQuery` | `Result<PagingList<Plugin>>` |

## 12.2 插件工具

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/plugins/{pluginId}/tools` | 在插件下创建工具。 | Path: `pluginId`; Body: `Tool` | `Result<String>` |
| PUT | `/console/v1/plugins/{pluginId}/tools/{toolId}` | 更新插件工具。 | Path: `pluginId`, `toolId`; Body: `Tool` | `Result<String>` |
| DELETE | `/console/v1/plugins/{pluginId}/tools/{toolId}` | 删除插件工具。 | Path: `pluginId`, `toolId` | `Result<Void>` |
| GET | `/console/v1/plugins/{pluginId}/tools/{toolId}` | 查询插件工具详情。 | Path: `pluginId`, `toolId` | `Result<Tool>` |
| GET | `/console/v1/plugins/{pluginId}/tools` | 分页查询插件工具。 | Path: `pluginId`; Query: `ToolQuery` | `Result<PagingList<Tool>>` |
| POST | `/console/v1/tools/{toolId}/enable` | 启用工具。 | Path: `toolId` | `Result<Void>` |
| POST | `/console/v1/tools/{toolId}/disable` | 禁用工具。 | Path: `toolId` | `Result<Void>` |
| POST | `/console/v1/plugins/{pluginId}/tools/{toolId}/test` | 测试执行插件工具。 | Path: `pluginId`, `toolId`; Body: `ToolExecutionRequest` | `Result<ToolExecutionResult>` |
| POST | `/console/v1/plugins/{pluginId}/tools/{toolId}/publish` | 发布插件工具。 | Path: `pluginId`, `toolId` | `Result<Void>` |
| POST | `/console/v1/tools/query-by-ids` | 按 ID 批量查询工具。 | Body: `ToolQuery` | `Result<List<Tool>>` |

## 12.3 工具全局管理

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/tools` | 从全局工具入口创建工具。 | Body: `ToolEntity` | `Result<ToolEntity>` |
| PUT | `/console/v1/tools/{id}` | 从全局工具入口更新工具。 | Path: `id`; Body: `ToolEntity` | `Result<ToolEntity>` |
| DELETE | `/console/v1/tools/{id}` | 从全局工具入口删除工具。 | Path: `id` | `Result<Void>` |
| GET | `/console/v1/tools/{id}` | 查询工具详情。 | Path: `id` | `Result<ToolEntity>` |
| GET | `/console/v1/tools` | 查询全部工具。 | 无 | `Result<List<ToolEntity>>` |
| GET | `/console/v1/tools/page` | 分页查询工具。 | Query: `current`, `size` | `Result<PagingList<ToolEntity>>` |
| GET | `/console/v1/tools/search` | 按名称搜索工具。 | Query: `name` | `Result<List<ToolEntity>>` |
| GET | `/console/v1/tools/plugin/{pluginId}` | 查询指定插件下的工具。 | Path: `pluginId` | `Result<List<ToolEntity>>` |
| PATCH | `/console/v1/tools/{id}/enabled` | 设置工具启用状态。 | Path: `id`; Query: `enabled` | `Result<Void>` |


# 13. MCP Server

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/mcp-servers` | 创建 MCP Server。 | Body: `McpServerDetail` | `Result<String>` |
| PUT | `/console/v1/mcp-servers` | 更新 MCP Server。 | Body: `McpServerDetail` | `Result<String>` |
| DELETE | `/console/v1/mcp-servers/{serverCode}` | 删除 MCP Server。 | Path: `serverCode` | `Result<Void>` |
| GET | `/console/v1/mcp-servers/{serverCode}` | 查询 MCP Server 详情。 | Path: `serverCode`; Query: `need_tools` | `Result<McpServerDetail>` |
| GET | `/console/v1/mcp-servers` | 分页查询 MCP Server。 | Query: `McpQuery` | `Result<PagingList<McpServerDetail>>` |
| POST | `/console/v1/mcp-servers/query-by-codes` | 按编码批量查询 MCP Server。 | Body: `McpQuery` | `Result<List<McpServerDetail>>` |
| POST | `/console/v1/mcp-servers/debug-tools` | 调试调用 MCP 工具。 | Body: `McpServerCallToolRequest` | `Result<McpServerCallToolResponse>` |


# 14. Agent Schema

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/agent-schemas` | 创建智能体 Schema。 | Body: `AgentSchemaEntity` | `Result<AgentSchemaEntity>` |
| PUT | `/console/v1/agent-schemas/{id}` | 更新智能体 Schema。 | Path: `id`; Body: `AgentSchemaEntity` | `Result<AgentSchemaEntity>` |
| DELETE | `/console/v1/agent-schemas/{id}` | 删除智能体 Schema。 | Path: `id` | `Result<Void>` |
| GET | `/console/v1/agent-schemas/{id}` | 查询智能体 Schema 详情。 | Path: `id` | `Result<AgentSchemaEntity>` |
| GET | `/console/v1/agent-schemas` | 查询全部智能体 Schema。 | 无 | `Result<List<AgentSchemaEntity>>` |
| GET | `/console/v1/agent-schemas/page` | 分页查询智能体 Schema。 | Query: `current`, `size` | `Result<PagingList<AgentSchemaEntity>>` |
| GET | `/console/v1/agent-schemas/search` | 按名称搜索智能体 Schema。 | Query: `name` | `Result<List<AgentSchemaEntity>>` |
| PATCH | `/console/v1/agent-schemas/{id}/enabled` | 设置智能体 Schema 启用状态。 | Path: `id`; Query: `enabled` | `Result<Void>` |


# 15. 文件上传

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/files/upload` | 上传本地文件。 | Multipart: `files`, `category` | `Result<List<UploadPolicy>>` |
| GET | `/console/v1/files/download` | 下载或预览文件。 | Query: `path`, `preview=false` | 文件响应 |
| POST | `/console/v1/files/upload-policies` | 获取 Web/OSS 直传策略。 | Body: `WebUploadRequest` | `Result<List<WebUploadPolicy>>` |
| GET | `/console/v1/files/get-preview-url` | 生成文件预览地址。 | Query: `path` | `Result<String>` |


# 16. API Key

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/api-keys` | 创建外部调用 `/api/v1/**` 接口使用的 API Key。 | Body: `ApiKey` | `Result<String>` |
| PUT | `/console/v1/api-keys/{id}` | 更新 API Key 描述。 | Path: `id`; Body: `ApiKey` | `Result<String>` |
| DELETE | `/console/v1/api-keys/{id}` | 删除 API Key 并使其失效。 | Path: `id` | `Result<Void>` |
| GET | `/console/v1/api-keys/{id}` | 查询 API Key 详情。 | Path: `id` | `Result<ApiKey>` |
| GET | `/console/v1/api-keys` | 分页查询当前账号的 API Key 列表。 | Query: `BaseQuery` | `Result<PagingList<ApiKey>>` |


# 17. 工作空间

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/console/v1/workspaces` | 创建工作空间。 | Body: `Workspace` | `Result<String>` |
| PUT | `/console/v1/workspaces/{workspaceId}` | 更新工作空间。 | Path: `workspaceId`; Body: `Workspace` | `Result<String>` |
| DELETE | `/console/v1/workspaces/{workspaceId}` | 删除工作空间。 | Path: `workspaceId` | `Result<Void>` |
| GET | `/console/v1/workspaces/{workspaceId}` | 查询工作空间详情。 | Path: `workspaceId` | `Result<Workspace>` |
| GET | `/console/v1/workspaces` | 分页查询工作空间列表。 | Query: `BaseQuery` | `Result<PagingList<Workspace>>` |


# 18. 组件服务

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| GET | `/console/v1/component-servers` | 分页查询组件服务。 | Query: `AppComponentQuery` | `Result<PagingList<AppComponent>>` |
| GET | `/console/v1/component-servers/app-publishable` | 分页查询可发布为组件的应用。 | Query: `AppComponentQuery` | `Result<PagingList<Application>>` |
| POST | `/console/v1/component-servers` | 发布组件服务。 | Body: `AppComponentQuery` | `Result<String>` |
| PUT | `/console/v1/component-servers/{code}` | 更新组件服务。 | Path: `code`; Body: `AppComponentQuery` | `Result<String>` |
| DELETE | `/console/v1/component-servers/{code}` | 删除组件服务。 | Path: `code` | `Result<Boolean>` |
| GET | `/console/v1/component-servers/{code}/detail-by-code` | 按组件编码查询详情。 | Path: `code` | `Result<AppComponent>` |
| GET | `/console/v1/component-servers/{appId}/detail-by-appid` | 按应用 ID 查询组件详情。 | Path: `appId` | `Result<AppComponent>` |
| GET | `/console/v1/component-servers/{code}/query-refer` | 查询组件引用关系。 | Path: `code` | `Result<List<AppComponent>>` |
| GET | `/console/v1/component-servers/{appId}/query-config` | 查询应用组件配置。 | Path: `appId` | `Result<AppComponent>` |
| POST | `/console/v1/component-servers/query-by-codes` | 按编码批量查询组件。 | Body: `AppComponentQuery` | `Result<List<AppComponent>>` |
| GET | `/console/v1/component-servers/{code}/query-schema` | 查询组件 Schema。 | Path: `code` | `Result<Map<String,Object>>` |
| POST | `/console/v1/component-servers/schema-by-codes` | 批量查询组件 Schema。 | Body: `AppComponentQuery` | `Result<Map<String,Object>>` |


# 19. Chat 对话（OpenAPI）

## 19.1 Chat 对话

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/api/v1/apps/chat/completions` | 对外提供智能体对话补全。 | Body: `AgentRequest`; Response 可为流式或非流式 | `Object` |

## 19.2 Workflow 调用（OpenAPI）

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/api/v1/apps/workflow/completions` | 对外同步运行工作流。 | Body: `WorkflowRequest`; Response 可为流式或非流式 | `Object` |
| POST | `/api/v1/apps/workflow/async-completions` | 对外异步启动工作流。 | Body: `WorkflowRequest` | `Result<TaskRunResponse>` |
| POST | `/api/v1/apps/workflow/stop-completions` | 对外停止工作流任务。 | Body: `TaskStopRequest` | `Result<Boolean>` |
| POST | `/api/v1/apps/workflow/async-results` | 查询异步工作流结果。 | Body: `AsyncResultRequest` | `Result<AsyncResultResponse>` |


# 20. OAuth2

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| GET | `/oauth2/login/github` | 获取 GitHub OAuth 登录地址。 | 无 | `Result<String>` |
| GET | `/oauth2/callback/github` | 处理 GitHub OAuth 回调并跳转。 | Query: `code` | `void` |


# 21. 系统

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| GET | `/console/v1/system/global-config` | 查询全局系统配置。 | 无 | `Result<GlobalConfig>` |
| GET | `/console/v1/system/health` | 健康检查。 | 无 | `String` |


# 22. 代码生成器（Graph Studio）

## 22.1 应用

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/graph-studio/api/app` | 创建 Graph Studio 应用。 | Body: `CreateAppParam` | `R<App>` |
| GET | `/graph-studio/api/app` | 查询 Graph Studio 应用列表。 | 无 | `R<List<App>>` |
| GET | `/graph-studio/api/app/{id}` | 查询 Graph Studio 应用详情。 | Path: `id` | `R<App>` |
| PUT | `/graph-studio/api/app` | 同步 Graph Studio 应用。 | Body: `App` | `R<App>` |
| DELETE | `/graph-studio/api/app/{id}` | 删除 Graph Studio 应用。 | Path: `id` | `R<Boolean>` |

## 22.2 DSL 导入导出

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| GET | `/graph-studio/api/dsl/export/{id}` | 导出应用 DSL 文本。 | Path: `id`; Query: `dialect` | `R<String>` |
| GET | `/graph-studio/api/dsl/export-file/{id}` | 导出应用 DSL 文件。 | Path: `id`; Query: `dialect` | `ResponseEntity<Resource>` |
| POST | `/graph-studio/api/dsl/import` | 从 DSL 文本导入应用。 | Body: `DSLParam` | `R<App>` |
| POST | `/graph-studio/api/dsl/import-file` | 从 DSL 文件导入应用。 | Multipart: `file`; Query: `dialect` | `R<App>` |

## 22.3 运行

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |
| POST | `/graph-studio/api/run/app/{id}/stream` | 以流式模式运行 Graph Studio 应用。 | Path: `id`; Body: `Map<String,Object>` | `Flux<RunEvent>` |
| POST | `/graph-studio/api/run/app/{id}/sync` | 以同步模式运行 Graph Studio 应用。 | Path: `id`; Body: `Map<String,Object>` | `R<RunEvent>` |
