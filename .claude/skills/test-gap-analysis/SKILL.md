# test-gap-analysis

## Description

**触发场景**：大规模重构完成后、大功能合入前、或季度测试专项时触发。适合「改了很多东西，不知道测试是否能兜住」的场景。

**产出**：三份文档，保存到 `outputDir`——

| 文档 | 内容 |
|------|------|
| `critical-paths.md` | 核心链路清单：8 条链路，每条含起点接口、关键节点、风险类型、终点断言 |
| `test-gaps.md` | 测试缺口表：按 P0/P1 分级，每条含链路编号、场景描述、建议测试类型（单元/集成/Characterization） |
| `test-plan.md` | 分批补测计划：按「最小基础设施依赖优先」排批，每批 1–2 项，含前置条件和工作量估算（天） |

**只汇报分析结果，不修改任何源码或测试文件。**

---

## Usage

```
/test-gap-analysis [scope] [outputDir]
```

| 参数 | 必填 | 默认 | 说明 |
|------|------|------|------|
| `scope` | 否 | `all` | 模块名模糊匹配（如 `Prompt`、`Experiment`）或 `all` 全量 |
| `outputDir` | 否 | `docs` | 三个输出文件的目录（相对项目根） |

**示例**

```
/test-gap-analysis                        # 全量分析，输出到 docs/
/test-gap-analysis Prompt docs            # 只分析 Prompt 相关链路
/test-gap-analysis all docs/test-review   # 全量，输出到自定义目录
```

---

## Instructions

When the user runs `/test-gap-analysis [scope] [outputDir]`:

### Step 0 — 解析参数

`scope` 默认 `all`；`outputDir` 默认 `docs`。确认 `outputDir` 目录是否存在：

```bash
ls {outputDir}/
```

不存在则用 Bash 创建：`mkdir -p {outputDir}`。

---

### Step 1 — 读入项目上下文

并行执行：

```bash
# 1a. 找所有 Service 实现文件（识别业务逻辑层）
find . -name '*ServiceImpl.java' -not -path '*/test/*' -not -path '*/node_modules/*'

# 1b. 找所有现有测试文件
find . -name '*Test.java' -not -path '*/node_modules/*'
```

同时读取：
- `docs/api-list.md`（获取接口入口 + 模块结构）
- `CLAUDE.md`（获取中间件栈和核心约定）

---

### Step 2 — 识别核心链路

基于 `api-list.md` 的接口分布和以下已知的高风险交互模式，识别 **8 条核心链路**（`scope != all` 时只保留涉及该模块的链路）：

| 链路编号 | 链路名 | 涉及的跨系统交互 |
|---------|--------|----------------|
| L1 | 登录 → Token → Redis 失效 | MySQL（account 查询）+ Argon2id + JWT + Redis 写入 |
| L2 | Prompt 创建 → 发布 → Nacos 同步 | MySQL 两表写（prompt + prompt_version）+ Nacos 网络调用 |
| L3 | Prompt 版本调试（SSE 流式） | Redis（ChatSession）+ AI 模型调用 + SseEmitter |
| L4 | 文档上传 → RocketMQ → ES 向量写入 | OSS/本地存储 + RocketMQ 异步消息 + Elasticsearch 向量索引 |
| L5 | 实验执行状态机 | MySQL 状态字段 + GraalVM 脚本执行 + RocketMQ + 并发写 experiment_result |
| L6 | Agent/Workflow App 发布 → OpenAPI 对话 | MySQL 两库（admin + agentscope）+ application_version 配置解析 + ChatClient |
| L7 | 知识库 RAG 检索 | Elasticsearch KNN 查询 + Embedding 模型 + score_threshold 过滤 |
| L8 | OAuth2 GitHub 登录 → 前端重定向 | GitHub OAuth2 外部网络 + account 写入（email 可能为 null）+ Cookie + SPA 路由 |

对每条链路，通过读 ServiceImpl 文件确认关键节点的实际代码路径：

```bash
# 示例：确认 L2 的 release 操作是否有事务包裹
grep -n '@Transactional\|promptVersionService\|latestVersion' \
  spring-ai-alibaba-admin-server-start/src/main/java/com/alibaba/cloud/ai/studio/admin/service/impl/PromptVersionServiceImpl.java

# 示例：确认 L1 的 Redis 写入
grep -n 'redisson\|RedissonClient\|setEx\|expire' \
  spring-ai-alibaba-admin-server-start/src/main/java/com/alibaba/cloud/ai/studio/admin/service/impl/AuthServiceImpl.java 2>/dev/null || \
grep -rn 'redisson\|token.*redis\|redis.*token' \
  spring-ai-alibaba-admin-server-start/src/main/java/com/alibaba/cloud/ai/studio/admin/service/impl/ 2>/dev/null | head -10
```

对每条链路记录：
- 起点接口（HTTP 方法 + 路径）
- 关键节点（2–5 个，每个写明类名 + 方法名）
- 跨系统边界（MySQL / Redis / ES / RocketMQ / Nacos / AI模型 / OSS）
- 风险类型（数据一致性 / 降级行为 / 序列化契约 / 状态机 / 外部依赖）
- 终点断言（链路跑通的可验证状态，如「Redis 中 Token 存在」「ES 中 chunk 可检索」）

---

### Step 3 — 扫描现有测试覆盖

**3a. 统计每个测试文件覆盖的方法**

```bash
grep -n '@Test\|@ParameterizedTest\|void test\|void should' {每个TestFile}
```

**3b. 找出每个测试 import 或调用的 Service/Controller 类**

```bash
grep -n 'import.*Service\|import.*Controller\|new.*Service\|@Autowired\|@MockBean' {每个TestFile}
```

**3c. 找出使用了哪些基础设施（真实 DB vs Mock）**

```bash
grep -n '@SpringBootTest\|@DataJpaTest\|@WebMvcTest\|Mockito\|mock(\|@Mock\b' {每个TestFile}
```

汇总每个测试文件：覆盖的类、覆盖的方法、使用的基础设施类型（纯单元 / Mock + 单元 / 集成）。

---

### Step 4 — 识别测试缺口

对 Step 2 识别的每条链路，逐节点与 Step 3 的覆盖情况比对：

**高风险场景清单**（每条对应一个潜在缺口，检查是否已有测试覆盖）：

| 场景 ID | 链路 | 场景描述 | 为什么高风险 |
|---------|------|---------|------------|
| G01 | L1 | 完整登录流：Argon2id 验证通过 → JWT 生成 → Redis 写入 | 登录是所有链路前置条件；双库路由重构必经 |
| G02 | L1 | 登出后原 Token 被 Redis DEL，再次请求返回 401 | Token 失效依赖 Redis key 命名；key 改动即凭证泄露 |
| G03 | L1 | 错误密码返回 401，不泄露账号是否存在 | Argon2id 替换或 Service 重构时最易静默返回 200 |
| G04 | L2 | Prompt release 同时更新两张表（prompt.latest_version + prompt_version.status） | 无事务包裹时会出现半改状态 |
| G05 | L2 | Nacos 不可达时 release 不抛异常、DB 状态已落地 | Nacos 网络调用失败静默返回，当前可能无 try-catch |
| G06 | L3 | ChatSession 写 Redis → 读回反序列化结果与原始 Message 列表一致 | Spring AI 升级后内部 Message 类型序列化格式可能变化 |
| G07 | L4 | 文档上传后 index_status 最终变为 3（完成），ES 中可检索到对应分块 | 全异步管道，任意节点失败都会让状态卡住 |
| G08 | L4 | RocketMQ 消费失败时 index_status 更新为错误状态并写入 error 字段 | 消费失败时状态可能永远停在 2（处理中） |
| G09 | L5 | 实验执行完成后 status = COMPLETED、experiment_result 数量 = data_count | 状态机核心，并发写时 progress 计算最易出错 |
| G10 | L5 | GraalVM 脚本返回 score > 1 时被截断或拒绝，不静默写入非法值 | DECIMAL(3,2) 字段插入 > 1 的值会 SQL 报错 |
| G11 | L5 | 实验执行抛异常后 status 改为 FAILED，不卡在 RUNNING | 状态机没有 try-catch 兜底时实验永远不结束 |
| G12 | L6 | App 发布后 application.status = 2，application_version.config 快照不为空 | 快照为空时 OpenAPI 对话时解析配置会 NPE |
| G13 | L6 | OpenAPI 对话用有效 api_key 返回 200，用无效 api_key 返回 401 | ApiKeyAuthInterceptor 逻辑改动或 Redis 缓存失效时鉴权失效 |
| G14 | L7 | ES KNN 查询返回结果，score_threshold 过滤行为符合预期 | Embedding 维度不匹配时 KNN 查询静默返回空结果 |

对每个场景，用 Step 3 的覆盖数据判断：
- **已覆盖**：找到测试方法明确断言了该场景 → 不纳入缺口
- **部分覆盖**：有测试但用了 Mock 跳过了关键边界 → 纳入缺口，标注「已有 Mock 覆盖，缺集成测试」
- **未覆盖**：没有找到任何相关测试 → 纳入缺口

优先级判断：
- **P0**：核心链路上、无任何测试覆盖、且是安全 / 数据一致性 / 全系统不可用风险 → G01–G14 默认 P0
- **P1**：有部分覆盖、或是边缘场景（降级行为、错误路径）

---

### Step 5 — 输出 critical-paths.md

写到 `{outputDir}/critical-paths.md`：

```markdown
# 核心链路清单

> 原则：只列"改造时容易出问题"的链路。
> 来源：docs/api-list.md、源码扫描、CLAUDE.md
> 生成时间：{当前日期}

## 总览

| # | 链路名 | 起点接口 | 风险类型 |
|---|--------|----------|---------|
[每条链路一行]

---

## 详细说明

### 链路 {N}：{链路名}

**起点：** `{HTTP方法} {路径}`

**关键节点：**
1. `{ClassName}.{methodName}` — {一句话说明}
2. ...（共 2–5 个节点）

**跨系统边界：** {MySQL / Redis / ES / RocketMQ / Nacos / AI模型}

**风险类型：** {数据一致性 / 降级行为 / 序列化契约 / 状态机 / 外部依赖}

**终点断言：** {链路跑通后可验证的最终状态}

**为什么容易出问题：**
- {具体原因，基于源码扫描结果}
```

---

### Step 6 — 输出 test-gaps.md

写到 `{outputDir}/test-gaps.md`：

```markdown
# 测试缺口清单

> 来源：critical-paths.md × 现有测试覆盖分析
> 原则：只列核心链路上的缺口；总数 ≤ 20
> 生成时间：{当前日期}

## 汇总表

| # | 优先级 | 链路 | 场景描述 | 覆盖现状 | 建议测试类型 |
|---|--------|------|---------|---------|------------|
[每条缺口一行]

---

## 详细说明

### {GNN} — {场景描述}（{优先级}）

**链路：** {L编号}

**覆盖现状：** {未覆盖 / 已有 Mock 覆盖但缺集成测试}

**为什么必须：** {基于源码扫描的具体理由}

**建议测试类型：** {单元测试 / 集成测试 / Characterization Test}

**建议断言：** {具体应该断言什么值、什么状态}

**前置条件：** {需要真实 MySQL / 嵌入式 Redis / Testcontainers / Mock AI 模型}
```

---

### Step 7 — 输出 test-plan.md

写到 `{outputDir}/test-plan.md`，按以下原则排批：

**排批原则**（优先级从高到低）：
1. **最小基础设施依赖优先**：零依赖单元测试 > Mock 单元测试 > 嵌入式 DB 集成测试 > 全栈集成测试
2. **同批次不超过 2 项**
3. **先把「后续所有测试的前置条件」排前**（如登录流是其他集成测试的前置）
4. **P0 全部排在 P1 之前**

```markdown
# 补测试计划

> 来源：test-gaps.md
> 排批原则：最小基础设施依赖优先 → 核心链路集成测试 → 边缘场景
> 生成时间：{当前日期}

## 批次总览

| 批次 | 缺口 | 测试类型 | 核心链路 | 预估工作量 |
|------|------|---------|---------|-----------|
[每批一行]

**合计：P0 缺口 {N} 项，预计 {N} 天。**

---

## 批次详情

### Batch {N} — {缺口描述}

**缺口：** {GNN}
**类型：** {单元测试 / 集成测试}
**链路：** {LN}
**工作量：** {0.5 / 1 / 1.5 / 2 / 3} 天

**做什么：** {具体要写什么测试、断言什么}

**为什么放在这批：** {排序理由}

**前置条件：** {无 / Mockito / 嵌入式 Redis / 真实 MySQL / Testcontainers}
```

---

### Step 8 — 最终汇总输出

在对话中输出：
1. 三个文件的保存路径
2. 缺口数量摘要（P0: N 项，P1: N 项，已覆盖: N 项）
3. 最需要优先处理的前 3 条缺口（理由一句话）
4. 若 `scope != all`，说明分析仅覆盖了哪些链路，其他链路未扫描

---

## Notes

- **扫描时不修改任何文件**，三个输出文件是 Markdown 文档而非代码
- 若 Step 2 中某个 ServiceImpl 文件过大（>200 行），只读前 80 行识别方法签名和关键 import，不需要读完整实现
- 工作量估算参考标准：单元测试（无基础设施）= 0.5 天；集成测试（真实 DB + 1–2 个中间件）= 1–2 天；全链路集成测试（4+ 中间件）= 3 天
- Characterization Test（摸底测试）= 0.5 天，目的是记录当前行为而非验证预期行为
- `scope` 过滤仅影响 Step 2 的链路选取，Step 1 的文件扫描仍全量执行（确保覆盖数据准确）
- 若现有测试文件数量为 0，在 test-gaps.md 摘要处注明「项目当前无测试文件，以下所有场景均未覆盖」

---

## allowed-tools

`Read`（读 api-list.md、CLAUDE.md、ServiceImpl 文件）、`Bash`（`find` / `grep`，只读）、`Write`（写三个输出文档）

**不使用** `Edit`、`Agent`、`WebFetch`、`WebSearch`
