# 改造流程图：Prompt 版本对比（Prompt Version Diff）

- 关联：[需求](prompt-version-diff.md)｜[影响分析](prompt-version-diff-impact.md)
- 本文件含三段 mermaid 源码，并已渲染为同名 `.svg`：
  - 主调用链 → [prompt-version-diff-flow.svg](prompt-version-diff-flow.svg)
  - 数据流 → [prompt-version-diff-dataflow.svg](prompt-version-diff-dataflow.svg)
  - Schema 变更 → [prompt-version-diff-schema.svg](prompt-version-diff-schema.svg)

---

## 图 1：完整调用链（前端发起 → Controller → Service → DAO → 返回）

```mermaid
sequenceDiagram
    autonumber
    actor U as 用户
    participant FE as 前端 VersionCompareModal
    participant CTL as PromptController
    participant SVC as PromptVersionService
    participant CALC as DiffCalculator
    participant DAO as Mapper (PromptVersion / Prompt)
    participant DB as prompt_version 表

    U->>FE: 勾选 versionA、versionB
    FE->>CTL: GET /api/prompt/version/diff<br/>?promptKey & versionA & versionB
    CTL->>CTL: 校验 @NotBlank / @Pattern<br/>versionA==versionB ⇒ 400 INVALID_PARAM (#1)
    CTL->>SVC: diff(promptKey, versionA, versionB)
    SVC->>DAO: selectByPromptKey(promptKey)
    DAO->>DB: SELECT ... WHERE prompt_key
    DB-->>SVC: PromptDO 或 null
    Note over SVC: null ⇒ 404 NOT_FOUND (#3)
    SVC->>DAO: selectByPromptKeyAndVersion(A)
    DB-->>SVC: VersionDO_A
    SVC->>DAO: selectByPromptKeyAndVersion(B)
    DB-->>SVC: VersionDO_B
    Note over SVC: A/B 任一 null ⇒ 404 (#2)
    SVC->>CALC: diffFields(DO_A, DO_B)
    Note over CALC: 详见「图 2 数据流」<br/>template / variables / modelConfig<br/>→ 3 个 FieldDiff
    CALC-->>SVC: List[FieldDiff]
    SVC->>SVC: 组装 PromptVersionDiffResponse<br/>(anyChange, metaA, metaB, fields)
    SVC-->>CTL: DiffResponse
    CTL-->>FE: Result.success(DiffResponse)
    FE-->>U: 按 hunks 行级高亮渲染
```

---

## 图 2：数据流（入参 → FieldDiff → Response）

聚焦 `DiffCalculator` 内部：两个 `PromptVersionDO` 的三个内容字段如何各自变换成 `FieldDiff`，再组装成响应。

```mermaid
flowchart TD
    IN["入参：两个 PromptVersionDO<br/>(template / variables / modelConfig)"]:::in

    IN --> T["template 分支"]:::field
    IN --> J["variables / modelConfig 分支"]:::field

    T --> T1["① 换行归一：CRLF → LF (#11)"]:::step
    T1 --> T2["② java-diff-utils 行级 diff"]:::step
    T2 --> TH["FieldDiff: field=template, diffType=text"]:::out

    J --> J1{"两方都合法 JSON?"}:::check
    J1 -- 是 --> J2["① readTree → 按键排序<br/>→ prettyPrint 规范化"]:::step
    J2 --> J3["② 行级 diff（规范化后）"]:::step
    J3 --> JH["FieldDiff: diffType=json<br/>键顺序无关 / 0.70≡0.7"]:::out
    J1 -- 否(null/空串/非法) --> J4["退化文本 diff<br/>null 等同 空串"]:::step
    J4 --> JH2["FieldDiff: diffType=text"]:::out

    TH --> AGG
    JH --> AGG
    JH2 --> AGG
    AGG["组装 PromptVersionDiffResponse<br/>anyChange / metaA / metaB / fields[3]<br/>changed=false ⇒ hunks=[] (#5)"]:::out

    classDef in fill:#eef,stroke:#88f,color:#000
    classDef field fill:#efe,stroke:#3c3,color:#000
    classDef step fill:#fff,stroke:#999,color:#000
    classDef check fill:#ffe,stroke:#cc3,color:#000
    classDef out fill:#fef,stroke:#93c,color:#000
```

---

## 图 3：Schema 变更

> **本需求不改表结构。** `prompt_version` 表的 `previous_version` 字段及其注释（"前置版本，用于对比"）早已存在，本期仅读取，不新增/不修改任何列，无需 DDL。

```mermaid
flowchart TB
    subgraph T["prompt_version 表（本期不改表结构）"]
        direction LR
        F1["id BIGINT PK"]:::c
        F2["version VARCHAR(32)"]:::c
        F3["prompt_key VARCHAR(255)"]:::c
        F4["template LONGTEXT"]:::c
        F5["variables LONGTEXT"]:::c
        F6["model_config LONGTEXT"]:::c
        F7["previous_version VARCHAR(32)<br/>注释：前置版本，用于对比"]:::hl
        F8["status / create_time"]:::c
    end
    N["✅ 无 DDL：previous_version 字段与注释早已存在<br/>本期仅读取（SELECT），不新增列、不改列"]:::note

    classDef c fill:#f7f7f7,stroke:#ccc,color:#000
    classDef hl fill:#fffbe6,stroke:#fadb14,color:#000
    classDef note fill:#f6ffed,stroke:#73d13d,color:#000
```
