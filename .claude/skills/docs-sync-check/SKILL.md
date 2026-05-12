# docs-sync-check

## Description

**触发场景**：代码变更后（新增/修改 Controller 或 Entity/SQL）、PR review 前、或怀疑文档已漂移时触发。

**产出**：一份结构化差异报告，分两节——
1. **接口差异**：代码 vs `docs/api-list.md`（新增接口、已删接口、路径/方法变更、入参/返回变更）
2. **数据模型差异**：Entity/SQL vs `docs/data-model.md`（新增表、已删表、字段增删、类型变更）

每条差异标注：来源文件 + 行号、代码实际值、文档记录值、建议动作。

**只汇报，不修改任何文件**。由人决定每条差异如何处置。

---

## Usage

```
/docs-sync-check [targetModule] [docTarget]
```

| 参数 | 必填 | 默认 | 说明 |
|------|------|------|------|
| `targetModule` | 否 | `all` | 模块名模糊匹配（如 `MCP`、`AgentSchema`）或 `all` 全量扫描 |
| `docTarget` | 否 | `both` | `api`（只查接口差异）、`model`（只查数据模型差异）、`both` |

**示例**

```
/docs-sync-check                        # 全量扫描，两个文档都对比
/docs-sync-check McpServer api          # 只对比 MCP 模块的接口清单
/docs-sync-check all model              # 全量扫描数据模型差异
/docs-sync-check Prompt both            # 只看 Prompt 相关的接口 + 数据模型
```

---

## Instructions

When the user runs `/docs-sync-check [targetModule] [docTarget]`:

### Step 0 — 解析参数

1. `targetModule` 默认 `all`；`docTarget` 默认 `both`
2. 若 `targetModule` 不是 `all`，后续所有 find/grep 限定到文件名包含该关键词的文件（大小写不敏感模糊匹配，`MCP` 可匹配 `McpServerController`、`mcp_server`）

---

### Step 1 — 收集代码侧接口清单（当 docTarget 为 `api` 或 `both`）

**1a. 找所有目标 Controller 文件**

```bash
find . -name '*Controller.java' -not -path '*/test/*' -not -path '*/node_modules/*'
```

若 `targetModule != all`，加 `-iname "*{targetModule}*Controller.java"` 过滤。

**1b. 对每个 Controller 文件，提取端点信息**

```bash
grep -n '@RequestMapping\|@GetMapping\|@PostMapping\|@PutMapping\|@DeleteMapping\|@PatchMapping' {file}
```

从结果中记录每个端点的：
- 类级 `@RequestMapping` 前缀路径
- 方法级注解（HTTP 方法 + 子路径）
- 完整路径 = 前缀 + 子路径拼接
- 入参类型（`@RequestBody`、`@RequestParam`、`@PathVariable` 的类型名）
- 返回类型（`Result<T>`、`Flux<T>`、`SseEmitter` 等）
- 所在文件 + 行号

**拼接规则**：若子路径为空字符串或 `/`，完整路径 = 前缀；否则 `前缀 + 子路径`（避免双斜杠）。

---

### Step 2 — 收集代码侧数据模型清单（当 docTarget 为 `model` 或 `both`）

**2a. 扫描 Entity 类**

```bash
# admin schema（MyBatis-Plus）
find . -name '*Entity.java' -not -path '*/test/*' -not -path '*/node_modules/*'

# agentscope schema（JPA）
find . -name '*DO.java' -not -path '*/test/*' -not -path '*/node_modules/*'
```

对每个目标文件，提取：
- `@TableName(...)` 或 `@Table(name = "...")` → 数据库表名
- 所有字段（驼峰名 + Java 类型）
- `@TableId` / `@Id` 标注的主键字段
- `@TableField("snake_name")` 映射的列名（若无注解，列名 = 驼峰转 snake_case）

**2b. 扫描 SQL 建表语句**

```bash
grep -n 'CREATE TABLE\|^\s*`[a-z]\|^\s*[a-z][a-z_]* ' \
  docker/middleware/init/mysql/admin-schema.sql \
  docker/middleware/init/mysql/agentscope-schema.sql
```

从 SQL 中记录每张表的：表名、列名、列类型（VARCHAR/BIGINT/TINYINT/DATETIME/TEXT 等）。

---

### Step 3 — 读取现有文档

```
Read docs/api-list.md      （当 docTarget 为 api 或 both）
Read docs/data-model.md    （当 docTarget 为 model 或 both）
```

解析规则：
- `api-list.md`：按 `## N.` 章节分组，从表格行提取「方法 + 路径 + 入参说明 + 返回说明」
- `data-model.md`：按 `### N.` 章节分组，从表格行提取「字段名（snake_case）+ 类型 + 说明」

---

### Step 4 — 交叉比对：接口（当 docTarget 为 `api` 或 `both`）

**匹配 key**：HTTP 方法（大写）+ 完整路径。

对每条从代码提取的端点，在 `api-list.md` 中查找：

| 情况 | 标记 |
|------|------|
| 代码有，文档无 | `[新增接口]` |
| 文档有，代码无 | `[已删接口]` |
| key 相同但返回类型描述不符 | `[返回变更]` |
| key 相同但入参类型描述不符 | `[入参变更]` |
| 完全一致 | 不输出，计入通过数 |

注意：文档中的入参/返回是自然语言描述，不需要逐字匹配——只在**结构性差异**（多了/少了参数、返回类型从 `Result<T>` 变成 `Flux<T>`）时才标记变更，措辞差异忽略。

---

### Step 5 — 交叉比对：数据模型（当 docTarget 为 `model` 或 `both`）

**匹配 key**：表名（统一小写 snake_case）。

对每张从 Entity/SQL 提取的表，在 `data-model.md` 中查找对应章节：

| 情况 | 标记 |
|------|------|
| 代码/SQL 有表，文档无章节 | `[新增表]` |
| 文档有章节，Entity 和 SQL 都找不到 | `[已删表]` |
| 表存在，字段在代码有、文档无 | `[新增字段]` |
| 表存在，字段在文档有、代码无 | `[已删字段]` |
| 字段存在，类型描述明显不符（如 `BigDecimal` vs `Float`） | `[类型变更]` |
| 完全一致 | 不输出，计入通过数 |

字段名匹配时统一转换：Entity 驼峰 ↔ 文档 snake_case，用驼峰→snake_case 转换后再比对。

**已知非 MySQL 实体，跳过 SQL 比对**（Entity 存在但无对应表属于正常设计）：
- `ChatSession`（存 Redis）
- `DocumentChunk`（存 Elasticsearch）
- `UploadPolicy` / `WebUploadPolicy`（运行时 DTO）
- `TokenResponse` / `AgentRequest` / `AgentResponse`（运行时 DTO）
- `GlobalConfig`（读 yml 配置，非持久化）
- `McpServerDetail` / `ModelConfigInfo` / `ProviderConfigInfo`（视图 DTO）
- `AppComponent`（对应 `application_component` 表，名字不同，已知映射）

---

### Step 6 — 输出差异报告

**输出格式**：

```
## docs-sync-check 差异报告

扫描范围：{targetModule} / {docTarget}
扫描时间：{当前日期}

### 摘要
- 接口：{N} 条一致，{N} 条差异
- 数据模型：{N} 条一致，{N} 条差异

---

### 接口差异（共 N 条）

#### [新增接口] POST /console/v1/xxx
- 代码位置：`XxxController.java:42`
- 文档现状：docs/api-list.md 中无此接口
- 建议动作：在对应章节追加该接口说明

#### [已删接口] DELETE /api/prompt/session
- 文档位置：`docs/api-list.md:105`
- 代码现状：未找到对应 Controller 方法
- 建议动作：确认是否已废弃，若是则从 api-list.md 删除

#### [入参变更] GET /console/v1/accounts
- 代码位置：`AccountController.java:67`
- 代码实际：含 `type` 查询参数
- 文档记录：无 `type` 参数
- 建议动作：更新 api-list.md 对应行的入参说明

---

### 数据模型差异（共 N 条）

#### [新增字段] 表 experiment_result — evaluator_version_id
- 代码位置：`ExperimentResultDO.java:28` / `agentscope-schema.sql:186`
- 文档现状：docs/data-model.md ### experiment_result 章节无此字段
- 建议动作：在 data-model.md 对应表中补充该字段说明

#### [类型变更] 表 experiment_result — score
- 代码位置：`ExperimentResultDO.java:33`
- 代码实际：`BigDecimal`（SQL: DECIMAL(3,2)）
- 文档记录：`Float`
- 建议动作：修正 data-model.md 中 score 字段的类型说明

---

### 无需处理的已知情况（供参考）

以下差异属于已知设计决策，不代表文档错误：
- ChatSession / DocumentChunk / UploadPolicy 等运行时 DTO，无 MySQL 表，跳过 SQL 比对
- AppComponent ↔ application_component：名字不同，已知映射，不标记差异

---

（差异为 0 时输出：文档与代码完全一致，无需更新。）
```

---

### Step 7 — 结束

- **不修改任何文件**
- 如需修复具体差异，可以告知「修复第 N 条」，或使用 `/add-crud-module` 补充新模块
- 若差异数为 0，输出一行「文档与代码完全一致，无需更新。」即可

---

## Notes

- 只关注**结构性不一致**（路径、方法、字段名、类型），忽略注释风格、空白行、措辞差异
- `targetModule` 模糊匹配大小写不敏感：`MCP` 可匹配 `McpServerController.java` 和 `mcp_server` 表
- 同一路径若在多个 Controller 中出现（继承/覆盖），以能扫描到的实际注解为准
- Entity 字段驼峰 ↔ 文档 snake_case 比对时，转换规则：`workspaceId` → `workspace_id`，`gmtCreate` → `gmt_create`
- 扫描时排除 `*/test/*` 和 `*/node_modules/*` 路径
- SQL 文件路径固定为 `docker/middleware/init/mysql/admin-schema.sql` 和 `docker/middleware/init/mysql/agentscope-schema.sql`

---

## allowed-tools

`Read`（读文档和 Entity 文件）、`Bash`（`find` / `grep`，只读操作）

**不使用** `Write`、`Edit`、`Agent`、`WebFetch`
