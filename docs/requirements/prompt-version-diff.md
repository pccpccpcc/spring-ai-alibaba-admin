# 需求草稿：Prompt 版本对比（Prompt Version Diff）

- 草稿日期：2026-06-15
- 状态：草稿（待产品评审）
- 相关接口组：Prompt 版本管理（[docs/api-list.md](../api-list.md) 第 2.2 节）
- 相关数据表：`prompt_version`（[docs/data-model.md](../data-model.md) 第 18 表）

---

## 1. 业务目标

> 让用户在控制台内一键对比同一个 Prompt 任意两个版本的内容差异（模板 / 变量 / 模型配置 / 元信息），辅助版本选型、回归定位与发版评审。

---

## 2. 用户场景与当前痛点

**典型场景**

- Prompt 工程师迭代了多版 `template`，发版前想确认 v5 相对 v3 改了哪些措辞、变量或模型参数。
- 线上效果出现回退，需要快速定位"是哪一版引入的变更"。
- Code Review / 评审时，需要把候选 release 版本和当前线上 release 版本并列展示差异。

**当前痛点**

- 现有只有 `GET /api/prompt/version?promptKey&version`（[PromptController](../../spring-ai-alibaba-admin-server-start/src/main/java/com/alibaba/cloud/ai/studio/admin/controller/PromptController.java)）单版本详情接口，要看差异必须**开两个详情页肉眼对比**。
- `template` 是 `LONGTEXT`，人工对比既慢又易错。
- `variables` / `modelConfig` 是 JSON 字符串，纯文本 diff 看不出结构差异（键顺序不同就全是"变更"）。

---

## 3. 接口契约

对齐现有 `PromptController` 风格（`@RequestMapping("/api")` + `Result<T>` 包装 + `StudioException` 错误码）。

### 3.1 请求

| 项 | 值 |
|---|---|
| 方法 | `GET` |
| 路径 | `/api/prompt/version/diff` |
| Content-Type | 无 body（纯 query） |

Query 参数：

| 参数 | 必填 | 校验（沿用 `PromptVersionCreateRequest` 的正则） | 说明 |
|---|---|---|---|
| `promptKey` | 是 | `^[a-zA-Z0-9_-]+$`，1–255 | Prompt 业务键 |
| `versionA` | 是 | `^[a-zA-Z0-9._-]+$`，1–32 | 对比的"旧"侧（diff 方向起点） |
| `versionB` | 是 | `^[a-zA-Z0-9._-]+$`，1–32 | 对比的"新"侧（diff 方向终点） |

> 方向语义：`add` / `remove` 以 **A → B** 为方向（A 有 B 无 = removed，B 有 A 无 = added）。方向是否对用户可见见第 4 节。

### 3.2 响应

`Result<PromptVersionDiffResponse>`，其中 `PromptVersionDiffResponse`（新建 DTO，风格对齐 `PromptVersionDetail` 的 Lombok `@Data @Builder`）：

```java
PromptVersionDiffResponse {
    String promptKey;
    String versionA;
    String versionB;

    // 顶层快速判断位：任一"内容字段"(template/variables/modelConfig)有差异即为 true。
    // 注意：不统计 createTime 等元信息差异（两版创建时刻几乎必然不同，计入会让它恒为 true）。
    boolean anyChange;

    // 两侧轻量元信息（不含大字段，便于 UI 展示表头；标量差异由 UI 自行对比）
    VersionMeta metaA;   // { versionDescription, status, createTime(ms), previousVersion }
    VersionMeta metaB;

    // 内容字段的逐字段差异（只放需要结构化 diff 的大字段）
    List<FieldDiff> fields;   // 覆盖：template / variables / modelConfig
}

FieldDiff {
    String field;        // "template" | "variables" | "modelConfig"
    boolean changed;     // 该字段是否有差异
    String diffType;     // "text" | "json" | "none"（changed=false 时为 "none"；"json" = 合法 JSON 经规范化后行级 diff）
    List<DiffHunk> hunks;// 差异块；changed=false 时为空数组（不回吐未变更内容）
}

DiffHunk {
    String type;         // "add" | "remove" | "equal" | "context"
    Integer oldStart;    // A 侧行号（可选）
    Integer newStart;    // B 侧行号（可选）
    List<String> lines;
}
```

> `versionDescription` / `status` / `createTime` / `previousVersion` 这类标量不进 `fields`，统一放 `metaA`/`metaB` 让 UI 自己比；`fields` 只承载需要行级/结构化 diff 的 `template`、`variables`、`modelConfig`。

### 3.3 错误码（对齐 `StudioException` 常量）

| HTTP | 常量 | 触发条件 |
|---|---|---|
| 400 | `INVALID_PARAM` | 参数缺失 / `promptKey`/`versionA`/`versionB` 不符正则 / `versionA == versionB` |
| 404 | `NOT_FOUND` | `promptKey` 不存在，或 `versionA`/`versionB` 任一不存在（对齐 `getByPromptKeyAndVersion` 现有行为） |
| 500 | `SERVER_ERROR` | diff 计算过程异常 |

成功：`Result.success(diffResponse)`，HTTP 200。

---

## 4. 边界场景清单

> **口径（硬性原则）**：每一条边界场景**必须能由接口的实际入参组合触发**。描述一个接口根本无法产生的场景（例如"两个 version 来自不同 promptKey"——而本接口只有一个 `promptKey` 参数）属于**伪场景**，不得列入；它会误导读者以为需要为之写防御代码。新增边界场景前先自检：它能否由 `{promptKey, versionA, versionB}` 的某种取值真实产生。

| # | 场景 | 标注 | 预期 / 处理 |
|---|---|---|---|
| 1 | `versionA == versionB` | **已定：返回 400** | 拒绝无意义调用，抛 `INVALID_PARAM`（对齐参数校验风格，与 #7「调用方自行交换参数重调」一致） |
| 2 | `versionA` 或 `versionB` 不存在 | 基于现有代码 | 抛 `NOT_FOUND`，对齐 `getByPromptKeyAndVersion`（`PromptVersionServiceImpl` L149-151） |
| 3 | `promptKey` 不存在 | 基于现有代码 | 抛 `NOT_FOUND`。是否同时校验 prompt 主表存在（对齐 `create` 里 `promptMapper.selectByPromptKey`）见 4.x，倾向校验 |
| 4 | 版本号格式非法（不符 `^[a-zA-Z0-9._-]+$`） | 基于现有代码 | 抛 `INVALID_PARAM`（对齐 `PromptVersionCreateRequest` 校验） |
| 5 | 两版本 `template` 完全相同 | 基于现有代码 | `fields[template].changed=false`、`diffType="none"`、`hunks=[]`（**空数组，不把整段相同内容回吐为一个 `equal` hunk**——`template` 是 `LONGTEXT`，回吐无变更内容纯属浪费带宽；调用方要内容走 `GET /api/prompt/version` 详情）。若三个内容字段全相同，顶层 `anyChange=false` |
| 6 | `variables` / `modelConfig` 为 null 或非合法 JSON | **已定（见下规则）** | 至少一方非合法时退化文本 diff（`diffType=text`），两方合法时规范化后行级 diff（`diffType=json`）。详见边界表后「JSON 字段 diff 规则」 |
| 7 | diff 方向对 UI 是否可逆 | **已定：不做** | 后端只实现单向 A→B（add/remove 以 A→B 为方向），不提供方向反转/交换能力；若需 B→A 视图，调用方自行交换 `versionA`/`versionB` 重新请求即可 |
| 8 | `template` 为超长 `LONGTEXT` 的性能与响应体大小 | **已定：不截断** | 当前阶段 prompt 不会特别长，不对 `hunks` 做行数/字符数截断，也不加 diff 分页参数；后续若出现超大模板再评估 |
| 9 | `status` 不同（`pre` vs `release`）的版本能否对比 | 基于现有代码 | 不限制。`getByPromptKeyAndVersion` 不校验 status，两态版本都可取，故都可对比 |
| 10 | 版本号大小写（实际不敏感） | **修正**（集成测试 t10 发现） | `prompt_version` 表 collation 为 `utf8mb4_0900_ai_ci`（大小写不敏感），`WHERE version='V1'` 会匹配 `v1`。原判断"大小写敏感"是误差，实际 `v3` = `V3`。若需大小写敏感，需改列 collation 为 `_bin` 或 `BINARY` 比较（本期不做） |
| 11 | 空白符差异（`\r\n` vs `\n`） | **已定：需要做** | 文本 diff 前对换行归一化（统一为 `\n`），避免 `\r\n` 与 `\n` 混用造成整段"伪变更"。作用于 `template` 全程，以及 `variables`/`modelConfig` 在退化文本分支（分支 1）时；JSON 规范化分支（分支 2）因 `pretty-print` 统一输出 `\n` 而天然免疫，无需额外处理 |
| 12 | JSON 等价但键顺序不同（`variables`/`modelConfig`） | **已定（见下规则）** | 规范化（按键排序 `pretty-print`）后行级 diff，键顺序无关，数值按值比较。详见边界表后「JSON 字段 diff 规则」 |

> **JSON 字段（`variables` / `modelConfig`）diff 规则（定稿，关闭 #6 / #12）**：对这两个字段统一按两条分支处理——
> 1. **至少一方为 `null` / 空串 / 非法 JSON**：退化文本 diff，`diffType="text"`，按原始字符串走行级 diff；合法的那一方先 `pretty-print` 再比，提升可读性。`null` 与 `""` 归一化为"无配置"，二者之间不产生变更（避免伪差异）。
> 2. **两方均为合法 JSON**：规范化后行级 diff，`diffType="json"`——两边各 `objectMapper.readTree` → 按键排序 → `writerWithDefaultPrettyPrinter` 规范化输出 → 复用 `template` 同一套行级 diff 与 `DiffHunk` 结构。键顺序自然无关；数值按值比较（`0.70`≡`0.7`、`1`≡`1.0`），不按字符串比较。
>
> 取舍：分支 2 不另造 path 级结构化 diff，是为了让 `template` / `variables` / `modelConfig` 三个内容字段共用同一 `DiffHunk` 形态，`diffType` 仅标记"是否经过规范化"，不引入额外 hunk 结构。根因上，非法 JSON 能入库是因为 `create` 链路未做 JSON 校验（`PromptVersionCreateRequest` 这两字段无校验注解、`PromptVersionServiceImpl.create` 裸 `String` 入库，而现成的 `ModelConfigParser.checkAndGetModelConfig` 只接在 Run 路径上），分支 1 兼顾这部分存量脏数据；建议另在 `create` 前置 `ModelConfigParser` 校验治本，但本接口仍需保留降级分支兜底。

---

## 5. 老项目约束（CLAUDE.md 来源）

| 约束 | 来源 | 对本需求的影响 |
|---|---|---|
| 改 REST Controller / DTO 要同步 `docs/api-list.md` | CLAUDE.md「文档同步约定」 | 新增 `/api/prompt/version/diff` 与 `PromptVersionDiffResponse` 等 DTO 后，必须在 api-list.md 第 2.2 节补一行 |
| 数据访问多套并存（MyBatis-Plus / MyBatis XML Mapper / JPA），先看所在模块既有风格 | CLAUDE.md「关键约定」 | `PromptVersion` 走的是 **MyBatis XML Mapper**（`PromptVersionMapper.selectByPromptKeyAndVersion` + `@Param`）。diff 服务应**复用该 mapper**，不要新引入 JPA/MyBatis-Plus 风格 |
| 数据关系多为逻辑 FK，SQL 无外键约束 | CLAUDE.md「关键约定」 | `prompt_version.prompt_key → prompt.prompt_key` 是逻辑 FK。接口需**自己做存在性校验**（对齐 `create` 中 `promptMapper.selectByPromptKey`），不能依赖 DB 外键 |
| 入口文档不堆大段清单 | CLAUDE.md「关键约定」 | 本详细契约放本 requirements 文档；CLAUDE.md / `docs/README.md` 只放链接摘要，不复制响应结构 |
| 事实来源优先级：接口看 Controller，数据看 SQL/DO | CLAUDE.md「事实来源优先级」 | 契约最终以 Controller 为准；字段以 `PromptVersionDO` / `prompt_version` 表为准 |
| 禁区 / 历史包袱 | CLAUDE.md「禁区」「历史包袱」 | 目前均标注"待补充"，本需求**未发现明确冲突**；实施时若触及再回填 |

> 顺带：`PromptVersionDO.previousVersion` 字段注释已写"前置版本，**用于对比**"——数据模型早为本需求预留，本期**无需改表结构**。

---

## 6. 不在这次范围里的事（候选，待你最终拍板）

以下是已识别的候选范围外项，请确认哪些排除、哪些挪进来：

1. **跨 Prompt 对比**（不同 `promptKey` 的两个版本互相 diff）。
2. **多版本 / 三方 merge diff**（一次对比 ≥3 个版本）。
3. **diff 结果持久化或导出**（存档、生成分享链接、导出 PDF/Markdown）。
4. **前端可视化**：本期纳入「基础切换」——把现有 `VersionCompareModal`（当前是纯前端弱 diff：按行号硬对齐、只覆盖 `template`、`modelConfig` 硬编码 `modelId/maxTokens/temperature/topP` 四字段、无 `variables`）改为消费新的 `/api/prompt/version/diff` 接口，按 `FieldDiff.hunks` 渲染行级高亮（add/remove/equal）。**仍列后续的**：并排↔合并视图切换、折叠未变区域等高级可视化。
5. ~~**`variables` / `modelConfig` 的语义化 JSON diff**~~（已纳入本期，见第 4 节「JSON 字段 diff 规则」：规范化 + 行级 diff，键顺序无关）。
6. **基于 diff 的"一键回滚到某版本"**操作。
7. **diff 的审计 / 权限**（记录谁对比过、按工作空间隔离）——接口本身应复用现有 `TokenAuthInterceptor` 鉴权，但细粒度审计不在本期。
8. **diff 算法正式选型**（Myers 行级 vs 字符级 vs 词级）的最终敲定。
9. **超大模板的分页 / 截断策略**（与第 4 节 #9 关联）。
10. **与评测/实验联动**：版本 diff + 对应版本的评测分数/实验结果对比。

---

## 7. 实施线索（非承诺，供排期参考）

- Controller：在 `PromptController` 新增 `@GetMapping("/prompt/version/diff")`，委托 `PromptVersionService`（或新 `PromptVersionDiffService`）。
- Service：复用 `promptVersionMapper.selectByPromptKeyAndVersion` 取两个 `PromptVersionDO`，组装 `PromptVersionDiffResponse`。
- diff 算法：`template` / `versionDesc` 走行级文本 diff（diff 前统一换行为 `\n`，见 #11）。当前 `pom.xml` **没有任何 diff 库**（已有的 `org.eclipse.jdt.core` 是 Java 格式化用，与 diff 无关），需新增依赖（推荐轻量的 `io.github.java-diff-utils:java-diff-utils`）或自实现简易 Myers；`variables` / `modelConfig` 按第 4 节「JSON 字段 diff 规则」：至少一方非合法 JSON 时按字符串走同一套行级 diff（`diffType=text`，合法方先 pretty-print）；两方合法时先 `objectMapper.readTree` + 按键排序 + `writerWithDefaultPrettyPrinter` 规范化后再行级 diff（`diffType=json`），复用同一套 `DiffHunk` 结构。
- 文档：同步 `docs/api-list.md` 第 2.2 节、`docs/data-model.md`（如涉及字段说明）。
- 测试：对齐 `docs/testing-guide.md`，补 `PromptVersionDiff` 相关单元/集成测试（纯逻辑可单元测，校验 404/400 可集成测）。
- 前端：改造 `frontend/packages/main/src/legacy/components/VersionCompareModal.jsx`（调用方 `pages/prompts/version-history/version-history.jsx:883`、`components/VersionHistoryModal.jsx:136`）——删掉 `renderDiffLines` 纯前端弱 diff 与硬编码 modelConfig 字段对比，新增前端 service 方法调用 `GET /api/prompt/version/diff`，按 `PromptVersionDiffResponse` 的 `FieldDiff.hunks` 渲染（`template` / `variables` / `modelConfig` 三个字段统一走 hunks，`variables`、动态 modelConfig 参数借此自然覆盖）；`metaA`/`metaB` 标量由前端自行对比展示。
