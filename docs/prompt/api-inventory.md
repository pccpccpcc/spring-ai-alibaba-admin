# REST 接口清单梳理 Prompt

你是一个资深后端架构师和接口文档整理专家。请扫描当前项目中的所有 REST 接口定义，整理一份清晰、准确、可用于研发、前端和产品沟通的接口清单。

## 目标

生成一份接口文档：

- `docs/api-list.md`：REST 接口清单。

如果在梳理过程中发现业务概念非常容易混淆，可以在最终回复里建议后续补充 QA 文档；但不要默认生成 QA 文档，除非我明确要求。

## 扫描范围

1. 扫描项目中所有可能声明 REST 接口的文件，包括但不限于：
   - 带有 `@RestController`、`@Controller`、`@RequestMapping` 的类。
   - 带有 `@GetMapping`、`@PostMapping`、`@PutMapping`、`@DeleteMapping`、`@PatchMapping` 的方法。
   - Controller 实现的接口、继承的父类、默认方法、抽象 Controller。
2. 不要只依赖文件名是否包含 `Controller`。
3. 排除构建产物和无关目录，例如 `target`、`build`、`.gradle`、`node_modules`、生成缓存等。
4. 对每个接口尽量读取：
   - 类级路径。
   - 方法级路径。
   - HTTP 方法。
   - 方法签名。
   - 入参注解，例如 `@RequestBody`、`@RequestParam`、`@PathVariable`、`@RequestHeader`、`@RequestPart`、`@ModelAttribute`。
   - 返回类型。
   - Swagger / OpenAPI 注解、方法注释、Service 调用逻辑、DTO / Entity 定义。

## 输出格式

`docs/api-list.md` 按业务模块分组。

标题层级要求：

1. 模块使用一级标题，例如 `# 1. 用户管理`。
2. 如果模块内部接口较多，可以使用二级标题拆成小类，例如 `## 1.1 用户 CRUD`、`## 1.2 用户权限`。
3. 模块编号从 `1` 开始递增。

每个接口使用表格展示，字段固定为：

| 方法 | 路径 | 一句话说明 | 主要入参 | 返回结构 |
| --- | --- | --- | --- | --- |

字段要求：

1. `方法` 写 `GET`、`POST`、`PUT`、`DELETE`、`PATCH` 等。
2. `路径` 写完整路径，需要合并类级和方法级映射。
3. `一句话说明` 用业务语言描述接口作用，不要只翻译方法名。
4. `主要入参` 区分 `Path`、`Query`、`Header`、`Body`、`Multipart`、`Form`。
5. `返回结构` 写顶层包装和核心业务类型，例如 `Result<UserDetail>`、`PageResult<Order>`、`List<Role>`、`SseEmitter`、`Flux<Message>`。
6. 对流式响应、文件下载、二进制响应、SSE、WebFlux 返回值等特殊返回要明确说明。
7. 如果返回类型无法从源码直接确认，请写“需结合实现确认”，不要臆造 DTO。

## 分组原则

优先按业务资源和产品模块分组，而不是机械按 Controller 类名分组。

分组时请遵循：

1. 先从接口路径、Controller 名称、Service 名称、DTO / Entity 名称判断业务资源。
2. 如果多个 Controller 服务同一个业务资源，可以合并到同一模块。
3. 如果一个 Controller 中包含多个明显不同的业务资源，可以拆到不同模块。
4. 登录认证、账号管理、权限管理、外部访问凭证、第三方授权等概念不要默认混成一个模块；需要结合源码里的用途判断是否拆分。
5. 文件上传、系统配置、健康检查、代码生成、调试接口、测试示例接口等通用或辅助能力可以单独成组。
6. 对测试示例接口、Mock 接口、内部调试接口，要明确标注；如果不纳入正式清单，需要说明原因。
7. 模块顺序应按业务主线排列：优先核心业务资源，其次支撑能力，最后系统、调试、测试、生成器等辅助接口。

## 主要入参写法

请保持简洁，但要能让读者快速判断如何调用。

示例：

- `Path: id; Query: pageNum, pageSize, keyword; Body: UserCreateRequest`
- `Path: appId, version; Header: Authorization; Body: ChatRequest`
- `Multipart: file; Query: folderId`
- `无`

如果 Body DTO 字段较少且很关键，可以在括号中补充核心字段，例如：

- `Body: LoginRequest(username, password)`

不要在接口清单里展开大型 DTO 的所有字段。

## 返回结构写法

请保留类型信息和核心业务对象。

示例：

- `Result<UserDetail>`
- `Result<PageResult<User>>`
- `List<MenuTreeNode>`
- `SseEmitter，流式返回消息片段`
- `ResponseEntity<Resource>，文件下载`

如果项目使用统一响应包装，请体现统一包装；如果某些接口直接返回原始对象，也要如实记录。

## 校验要求

完成前必须做接口集合校验：

1. 从源码中抽取所有接口的 `(HTTP 方法, 完整路径)` 集合。
2. 从 `docs/api-list.md` 中抽取所有表格里的 `(HTTP 方法, 路径)` 集合。
3. 对比两者差异，输出：
   - 源码接口总数。
   - 文档接口总数。
   - missing 列表。
   - extra 列表。
4. 如果有接口故意不纳入文档，例如测试示例接口或内部 Mock 接口，需要单独说明原因，并再次给出“排除这些接口后”的校验结果。

## 工作方式

请按以下步骤执行：

1. 先列出所有 Controller 文件和可能的接口定义文件。
2. 用脚本、结构化搜索或 AST 分析抽取接口清单，避免手工遗漏。
3. 阅读关键 DTO、Service、Entity、注释和 OpenAPI 注解，判断接口业务语义。
4. 先形成完整接口草稿，再按业务资源重新分组和排序。
5. 完成 `docs/api-list.md` 后进行接口集合校验。
6. 最终回复中说明：
   - 生成或更新了哪个文件。
   - 接口总数和校验结果。
   - 哪些接口未纳入，以及原因。
   - 是否建议后续补充 QA 文档。

## 质量标准

1. 文档应便于产品、后端、前端共同阅读。
2. 模块边界应清晰，不要因为 Controller 放在一起就把不同业务概念混在一起。
3. 说明要准确、简洁，优先使用源码里的真实概念。
4. 返回结构保留类型信息，不需要展开所有 DTO 字段。
5. 对无法确认的信息要标注不确定性，不要编造。
6. 如果业务概念存在明显歧义，可以在最终回复中列出建议澄清的问题，但不要默认创建额外文档。
