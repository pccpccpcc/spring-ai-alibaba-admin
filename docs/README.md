# 文档地图（先看这里）

Spring AI Alibaba Admin 是基于 Spring AI Alibaba 的 AI Agent 开发、调试、评估与可观测平台。本文是 `docs/` 的**总入口**，帮你快速找到要看的那一份。

> 维护原则：本文件只做"目录 + 一句话说明"，不放接口清单、数据字典、SVG 内容。细节都在各自的子文档里。

---

## 1. 文档分类一览

### 🧭 入口与总览

| 文档 | 一句话 | 适合谁 |
|---|---|---|
| [../CLAUDE.md](../CLAUDE.md) | 项目级开发约定：架构、事实来源优先级、怎么跑、CI、禁区。**改任何代码前先读** | 所有开发者 / AI agent |
| [critical-paths.md](critical-paths.md) | 改造时最容易出问题的核心链路清单（认证、Prompt、评测、文档索引、工作流、OpenAPI、工具、RAG） | 改核心逻辑、定测试优先级的人 |
| [architecture.svg](architecture.svg) | 系统总体架构图 | 所有人快速建立全局认知 |

### 🏗️ 架构与依赖

| 文档 | 一句话 | 适合谁 |
|---|---|---|
| [module-deps.svg](module-deps.svg) | 后端 Maven 模块间依赖关系图 | 改模块边界、加新模块的人 |
| [external-dependencies.svg](external-dependencies.svg) | 外部中间件 / 外部 API 依赖图 | 排查中间件、配置中心问题的人 |
| [env-checklist.md](env-checklist.md) | 外部依赖环境检查清单（工具版本、中间件、配置） | 配环境、做部署的人 |

### 📡 接口与数据模型

> 这两类以**代码为事实来源**，文档是整理后的索引。改动时先看 Controller/SQL，再同步这里。

| 文档 | 事实来源 | 一句话 |
|---|---|---|
| [api-list.md](api-list.md) | Controller / OpenAPI | REST 接口清单 |
| [data-model.md](data-model.md) | `docker/middleware/init/mysql/*.sql` | 数据模型与数据字典 |
| [data-model-er.svg](data-model-er.svg) | SQL / Entity | 数据模型 ER 图 |

### 🚀 本地启动与运维

| 文档 | 一句话 | 适合谁 |
|---|---|---|
| [setup-guide.md](setup-guide.md) | **新人从零搭环境的主指南**（中间件、启动、踩坑、验证清单） | 第一次接触本项目的人 |
| [startup-log.md](startup-log.md) | 应用启动日志记录 | 排查启动问题的人 |
| [smoke-test-result.md](smoke-test-result.md) | 启动后核心 API 冒烟测试结果 | 验证环境是否就绪 |

> 启动脚本在仓库根的 [../scripts/](../scripts/)（`install-deps.sh`、`deps-start.sh`、`admin-start.sh` 等），根目录 `./start.sh` 是薄封装。

### 🧪 测试

| 文档 | 一句话 | 适合谁 |
|---|---|---|
| [testing-guide.md](testing-guide.md) | **测试运行主指南**：本地跑、中间件约定、CI、踩坑 | 写测试、跑测试的人 |
| [test-plan.md](test-plan.md) | P0 补测试计划（批次 + 工作量） | 规划补测的人 |
| [test-status.md](test-status.md) | 测试现状报告（覆盖率、缺口统计） | 了解测试健康度 |
| [test-gaps.md](test-gaps.md) | 核心链路测试缺口明细 | 决定补测优先级 |

### 📋 需求与改造方案

`requirements/` 下是单个功能/需求从「需求 → 影响分析 → 改造方案」的完整推演文档（含流程图），供评审与实施参考，**不是接口/数据事实来源**（事实以代码 + api-list/data-model 为准）：

| 文档 | 一句话 |
|---|---|
| [requirements/prompt-version-diff-solution.md](requirements/prompt-version-diff-solution.md) | Prompt 版本对比：改造方案（评审入口，含决策集中审核） |
| [requirements/prompt-version-diff.md](requirements/prompt-version-diff.md) | Prompt 版本对比：需求（接口契约 + 边界场景） |

### 💬 概念问答

| 文档 | 一句话 |
|---|---|
| [qa/qa.md](qa/qa.md) | 概念问答。**不是架构事实主入口**，仅供理解概念 |

### 🤖 Prompt 模板（文档生成器）

`prompt/` 下是**用来重新生成/维护上述文档的可复用 Prompt**，不是给人读的业务文档：

| 模板 | 生成目标 |
|---|---|
| [prompt/api-inventory.md](prompt/api-inventory.md) | 接口清单 |
| [prompt/data-model-inventory.md](prompt/data-model-inventory.md) | 数据字典 + ER 图 |
| [prompt/architecture-diagram.md](prompt/architecture-diagram.md) | 架构图 |
| [prompt/internal-module-dependencies.md](prompt/internal-module-dependencies.md) | 模块依赖图 |
| [prompt/external-dependencies.md](prompt/external-dependencies.md) | 外部依赖图 |
| [prompt/install-deps.md](prompt/install-deps.md) | 安装脚本 |
| [prompt/claude-md.md](prompt/claude-md.md) | CLAUDE.md |

### 🛠️ Skills（工作流自动化）

`skills/` 下是项目专用工作流 skill（agent 工具），编码了项目特定流程：

| Skill | 用途 |
|---|---|
| [skills/local-dev-bootstrap](skills/local-dev-bootstrap) | 新接手项目时拉起并验证本地开发环境 |
| [skills/resource-api-change](skills/resource-api-change) | 变更后端资源类接口（含文档同步） |
| [skills/docs-maintenance](skills/docs-maintenance) | 更新或校验项目文档 |
| [skills/docker-image-release](skills/docker-image-release) | 构建 / 打标签 / 推送 Docker 镜像 |

---

## 2. 按角色 / 目标的阅读路径

**我是新人，想跑起来项目**
→ [setup-guide.md](setup-guide.md) → [env-checklist.md](env-checklist.md) → 启动后看 [smoke-test-result.md](smoke-test-result.md) 验证。

**我要改某个接口**
→ [api-list.md](api-list.md) 找接口 → 看对应 Controller 改代码 → 同步 [api-list.md](api-list.md) 和（如涉及）[data-model.md](data-model.md)。

**我要改数据表**
→ [data-model.md](data-model.md) + [data-model-er.svg](data-model-er.svg) 看现状 → 改 `docker/middleware/init/mysql/*.sql` 和 Entity → 同步数据字典。

**我要写/跑测试**
→ [testing-guide.md](testing-guide.md)（本地 + CI 全流程）→ [test-plan.md](test-plan.md) 看补测计划 → [test-status.md](test-status.md) 看现状。

**我要改架构 / 模块边界**
→ [architecture.svg](architecture.svg) + [module-deps.svg](module-deps.svg) → 改完同步图和 [../CLAUDE.md](../CLAUDE.md) 的"核心架构"。

**我不懂某个概念**
→ 先查 [qa/qa.md](qa/qa.md)；架构事实以代码和上面的文档为准，不要把 qa 当事实来源。

---

## 3. 文档维护约定（摘要）

完整约定见 [../CLAUDE.md](../CLAUDE.md) 的"文档同步约定"，要点：

- 改 REST/OpenAPI/DTO → 同步 [api-list.md](api-list.md)。
- 改 SQL/Entity/DO/Mapper/枚举 → 同步 [data-model.md](data-model.md) 和 [data-model-er.svg](data-model-er.svg)。
- 改 Maven 模块依赖/包边界 → 同步 [module-deps.svg](module-deps.svg) 和 [../CLAUDE.md](../CLAUDE.md)。
- 改中间件/外部 API/部署依赖 → 同步 [external-dependency.svg](external-dependency.svg) 和 setup-guide。
- 新增长期项目约定 → 写进 [../CLAUDE.md](../CLAUDE.md)；临时/概念性内容放 [qa/](qa/)。
- **入口文档（含本文件）只放链接和摘要**，不要把大段接口清单、数据字典、SVG 内容复制进来。

---

## 4. 关于文档组织

- `docs/` 顶层目前是**扁平结构**（md + svg 同级），加 `qa/`、`prompt/`、`skills/`、`requirements/` 四个子目录。这是有意为之：这些文档之间交叉引用密集（30+ 处），且 [../CLAUDE.md](../CLAUDE.md) / 根 README 直接按路径引用；物理上移到子目录会扯断这些链接。**归类通过本文件的分类表表达**，不需要移动文件。
- 新增文档时：放顶层 `docs/`，并在本文件第 1 节对应分类表里登记一行。
- 如果某类文档将来增长到很多（>10 个），再考虑拆子目录，并一次性更新所有引用。
