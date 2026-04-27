# docs-auto-sync

对照代码（Controller、Entity、SQL）与文档（`docs/api-list.md`、`docs/data-model.md`）做交叉比对，输出不一致清单，**不自动修改任何文件**，由人决定如何处理。

## 触发场景

- 新增或修改了 Controller（接口变更、路径变更、参数变更）
- 新增或修改了 Entity 类或 SQL 表定义（字段变更、新表、删表）
- 怀疑文档与代码已经偏移，想做一次全量对齐检查
- PR review 前确认文档是否跟上了代码变更

## 产出

一份结构化差异报告，分两节：

1. **接口差异**（代码 vs `docs/api-list.md`）：新增接口、删除接口、路径/方法变更、入参/返回类型变更
2. **数据模型差异**（Entity/SQL vs `docs/data-model.md`）：新增表/实体、删除表/实体、字段增删、类型变更、枚举值变更

每条差异标注：来源文件 + 行号、当前代码实际值、文档记录值、建议动作（更新文档 / 核实代码 / 忽略）。

## Usage

```
/docs-auto-sync [targetModule] [docTarget]
```

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `targetModule` | 否 | `all` | 模块名（如 `MCP`、`AgentSchema`）或 `all` 全量扫描 |
| `docTarget` | 否 | `both` | `api`（只查接口）、`model`（只查数据模型）、`both` |

**示例**

```
/docs-auto-sync                        # 全量扫描，两个文档都对比
/docs-auto-sync McpServer api          # 只对比 MCP 模块的接口清单
/docs-auto-sync all model              # 全量扫描数据模型
```

## allowed-tools

`Read`、`Bash`（仅用于 `find` / `grep` 定位文件）

**不使用** `Write`、`Edit`、`Agent`。

---

## Instructions

When the user runs `/docs-auto-sync [targetModule] [docTarget]`:

### Step 0 — 解析参数

1. `targetModule` 默认 `all`；`docTarget` 默认 `both`
2. 若 `targetModule` 不是 `all`，后续所有 find/grep 限定到包含该模块名的文件

---

### Step 1 — 收集代码侧接口清单（当 docTarget 为 `api` 或 `both`）

用 Bash 扫描所有 Controller 文件：

```bash
find . -name '*Controller.java' -not -path '*/test/*'
```

对每个目标 Controller（`targetModule=all` 则全部），提取：

```bash
grep -n '@RequestMapping\|@GetMapping\|@PostMapping\|@PutMapping\|@DeleteMapping\|@PatchMapping' <file>
```

从代码中记录每个 endpoint 的：
- HTTP 方法（GET/POST/PUT/DELETE/PATCH）
- 完整路径（`@RequestMapping` 前缀 + 方法注解路径拼接）
- 方法签名中的入参类型（`@RequestBody`、`@RequestParam`、`@PathVariable`）
- 返回类型（`Result<T>`、`Flux<T>`、`SseEmitter` 等）
- 所在文件 + 行号

---

### Step 2 — 收集代码侧数据模型清单（当 docTarget 为 `model` 或 `both`）

**2a. 扫描 Entity 类**

```bash
# agentscope 侧（MyBatis-Plus）
find . -name '*Entity.java' -not -path '*/test/*'

# admin 侧（JPA）
find . -name '*DO.java' -not -path '*/test/*'
```

对每个目标 Entity 文件，提取：
- `@TableName` 或 `@Table(name=...)` → 表名
- 所有字段名（驼峰）+ Java 类型
- `@TableId` / `@Id` 标注的主键字段
- `@TableField("snake_name")` 映射的列名

**2b. 扫描 SQL 文件**

```bash
grep -n 'CREATE TABLE\|^\s*`\|^\s*[a-z]' docker/middleware/init/mysql/admin-schema.sql
grep -n 'CREATE TABLE\|^\s*`\|^\s*[a-z]' docker/middleware/init/mysql/agentscope-schema.sql
```

从 SQL 中记录每张表的：表名、列名、列类型、是否有 NOT NULL / DEFAULT、注释

---

### Step 3 — 读取现有文档

```bash
# 读 docs/api-list.md，按 ## 章节分组
# 读 docs/data-model.md，按 ### 表名分组
```

用 `Read` 工具读取两个文档，解析出：
- api-list.md：每个模块的接口列表（方法 + 路径 + 入参说明 + 返回说明）
- data-model.md：每张表的字段列表（字段名 + 类型 + 说明）

---

### Step 4 — 交叉比对：接口

对每个从代码提取的 endpoint，在 api-list.md 中查找对应记录：

**匹配规则**：HTTP 方法 + 路径完全相同为同一接口。

对每条 endpoint 判断：

| 情况 | 标记 |
|------|------|
| 代码有，文档无 | `[新增接口]` — 文档缺失 |
| 文档有，代码无 | `[已删接口]` — 文档过期 |
| 路径相同但方法不同 | `[方法变更]` |
| 入参类型与文档描述不符 | `[入参变更]` |
| 返回类型与文档描述不符 | `[返回变更]` |
| 完全一致 | 不输出，只统计通过数 |

---

### Step 5 — 交叉比对：数据模型

对每张从 Entity/SQL 提取的表，在 data-model.md 中查找对应 `### {tableName}` 章节：

| 情况 | 标记 |
|------|------|
| 代码/SQL 有表，文档无章节 | `[新增表]` — 文档缺失 |
| 文档有章节，代码/SQL 无表 | `[已删表]` — 文档过期 |
| 表存在，但字段在代码中有、文档无 | `[新增字段]` |
| 表存在，但字段在文档中有、代码无 | `[已删字段]` |
| 字段存在，但类型不符 | `[类型变更]` |
| 字段存在，但枚举值说明不符 | `[枚举变更]` |
| 完全一致 | 不输出，只统计通过数 |

---

### Step 6 — 输出差异报告

**格式要求**：

```
## docs-auto-sync 差异报告
扫描范围：{targetModule} / {docTarget}
扫描时间：{当前日期}

### 摘要
- 接口：{通过数} 条一致，{差异数} 条不一致
- 数据模型：{通过数} 条一致，{差异数} 条不一致

---

### 接口差异（共 N 条）

#### [新增接口] POST /console/v1/xxx
- 代码位置：`XxxController.java:42`
- 文档现状：docs/api-list.md 中无此接口
- 建议动作：在 docs/api-list.md 对应章节追加该接口说明

#### [已删接口] DELETE /api/prompt/session
- 文档位置：`docs/api-list.md:105`
- 代码现状：未找到对应 Controller 方法
- 建议动作：确认是否已废弃，若是则从 api-list.md 中删除

#### [入参变更] GET /console/v1/accounts
- 代码位置：`AccountController.java:67`
- 代码实际：入参 `AccountQuery { page, size, keyword, type }`
- 文档记录：入参 `BaseQuery { page, size, keyword }`
- 差异：文档缺少 `type` 字段
- 建议动作：更新 docs/api-list.md 对应入参说明

---

### 数据模型差异（共 N 条）

#### [新增字段] 表 account — 字段 `gmt_last_login`
- 代码位置：`AccountEntity.java:45` / `agentscope-schema.sql:28`
- 文档现状：docs/data-model.md ### account 章节无此字段
- 建议动作：在 data-model.md account 表中补充该字段

#### [类型变更] 表 experiment_result — 字段 `score`
- 代码位置：`ExperimentResultDO.java:33`
- 代码实际：`BigDecimal`（SQL: `DECIMAL(3,2)`）
- 文档记录：`Float`
- 建议动作：修正 data-model.md 中 score 字段的类型说明

---

### 无需处理的已知情况

以下差异是已知的设计决策，不代表文档错误：
- `ChatSession`：无 MySQL 表，存 Redis，文档中已有"非 MySQL 实体"节说明
- `DocumentChunk`：无 MySQL 表，存 Elasticsearch，同上
- `GlobalConfig`：运行时 DTO，非持久化，同上
```

---

### Step 7 — 结束

报告输出后：

- **不修改任何文件**
- 告知用户：如需逐条修复，可用 `/add-crud-module` 补充新模块，或手动 Edit 对应章节
- 若差异数为 0，输出"文档与代码完全一致，无需更新"

---

## Notes

- 比对时忽略注释风格、空白行、措辞差异，只关注结构性不一致（路径、方法、字段名、类型）
- Entity 字段用驼峰，文档字段用 snake_case，比对时统一转换后再匹配
- `targetModule` 模糊匹配：输入 `MCP` 可匹配 `McpServerController`、`mcp_server` 表
- 若同一路径在多个 Controller 中出现（如继承/覆盖），以最终注册到 Spring 的为准，扫描时注意 `@RequestMapping` 前缀叠加
- `docs/data-model.md` 中"非 MySQL 实体"节（ChatSession / DocumentChunk / GlobalConfig）不参与 SQL 比对，跳过
