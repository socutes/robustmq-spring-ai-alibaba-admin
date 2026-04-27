# 测试缺口清单

> 来源：docs/critical-paths.md × docs/test-status.md 对照分析
> 原则：只列核心链路上的缺口；追求"关键路径有兜底"而非覆盖率指标；总数 ≤ 20

---

## 汇总表

| # | 优先级 | 链路 | 场景描述 | 建议测试类型 |
|---|--------|------|----------|-------------|
| G01 | P0 | 链路 1 | Argon2id 验证通过 → JWT 生成 → Redis 写入完整登录流 | 集成测试 |
| G02 | P0 | 链路 1 | 登出后原 Token 被 Redis DEL，再次请求返回 401 | 集成测试 |
| G03 | P0 | 链路 1 | 错误密码返回 401，不泄露账号是否存在 | 集成测试 |
| G04 | P0 | 链路 2 | Prompt release 操作同时更新两张表（prompt.latest_version + prompt_version.status） | 集成测试 |
| G05 | P0 | 链路 2 | Nacos 不可达时 release 操作不抛异常、DB 状态已落地 | 单元测试 |
| G06 | P0 | 链路 3 | ChatSession 写 Redis → 读回反序列化结果与原始 Message 列表一致 | 集成测试 |
| G07 | P0 | 链路 4 | 文档上传后 index_status 最终变为 3（完成），ES 中可检索到对应分块 | 集成测试 |
| G08 | P0 | 链路 4 | RocketMQ 消费失败时 index_status 更新为错误状态并写入 error 字段 | 集成测试 |
| G09 | P0 | 链路 5 | 实验执行完成后 status = COMPLETED、experiment_result 数量 = data_count | 集成测试 |
| G10 | P0 | 链路 5 | GraalVM 脚本返回 score > 1 时被截断或拒绝，不静默写入 | 单元测试 |
| G11 | P0 | 链路 5 | 实验执行抛异常后 status 改为 FAILED，不卡在 RUNNING | 集成测试 |
| G12 | P0 | 链路 6 | App 发布后 application.status = 2，application_version.config 快照不为空 | 集成测试 |
| G13 | P0 | 链路 6 | OpenAPI 对话用有效 api_key 返回 200，用无效 api_key 返回 401 | 集成测试 |
| G14 | P0 | 链路 7 | ES KNN 查询返回结果，且 score_threshold 过滤行为符合预期 | 集成测试 |
| G15 | P1 | 链路 3 | AI 模型未配置（无 API Key）时 SSE 流返回可识别的错误事件，连接不静默断开 | Characterization Test |
| G16 | P1 | 链路 4 | Embedding 维度与索引不匹配时抛出明确异常，不写入全零向量 | 单元测试 |
| G17 | P1 | 链路 6 | 被引用的 KB 或 Plugin 已删除时，App 对话返回业务错误而非 NullPointerException | Characterization Test |
| G18 | P1 | 链路 8 | GitHub 邮箱为 null 时 OAuth2 注册不因 NOT NULL 约束崩溃 | 单元测试 |
| G19 | P1 | 链路 2 | Nacos 端口用 gRPC（9848）而非 HTTP（8848）时，NacosClientService 报错明确 | 单元测试 |
| G20 | P1 | 链路 1 | Token 字段名 access_token（snake_case）在 JSON 序列化后不变为 accessToken | 单元测试 |

---

## 详细说明

### G01 — 完整登录流（P0）

**场景：** 调用 `POST /console/v1/auth/login`，验证 Argon2id 密码比对通过、JWT 包含正确 account_id、Token 以正确 TTL 写入 Redis。

**为什么必须：** 登录是所有其他链路的前置条件。双库路由重构、升级 jjwt 版本、调整 Redis TTL 任意一步出错都会让全系统不可用，但现有测试只覆盖了 `PasswordCryptUtils.encode/match`，不覆盖 Service 层拼装和 Redis 写入。

**建议类型：** 集成测试（`@SpringBootTest` + 嵌入式 Redis 或 Testcontainers Redis，真实 MySQL）

---

### G02 — 登出使 Token 失效（P0）

**场景：** 登录获取 Token → 调用 `POST /console/v1/auth/logout` → 用原 Token 请求受保护接口返回 401。

**为什么必须：** Token 失效依赖 Redis DEL，若 Redis key 命名规则变化或 Token 解析逻辑改动，Token 永远不过期。这是安全核心，没有测试意味着任何认证层改造都可能引入凭证泄露。

**建议类型：** 集成测试

---

### G03 — 错误密码拒绝登录（P0）

**场景：** 用错误密码调用登录接口，返回 401 且响应体不包含"账号不存在"/"密码错误"等枚举信息。

**为什么必须：** Argon2id 哈希替换或 Service 层条件判断重构时，最容易出现"永远返回 200"或"抛出 500"的回归。同时验证不泄露账号枚举。

**建议类型：** 集成测试

---

### G04 — Prompt release 两表原子性（P0）

**场景：** 调用 release 接口，验证 `prompt.latest_version` 和 `prompt_version.status` 在同一请求内都被更新，不出现只改一张表的半改状态。

**为什么必须：** 代码中两步更新没有事务包裹（见 critical-paths.md 链路 2），任何对 `PromptVersionService.release` 的重构都可能引入不一致。这是 Prompt 核心业务的数据完整性保证。

**建议类型：** 集成测试（真实 MySQL，验证两张表的最终状态）

---

### G05 — Nacos 不可达时 release 不失败（P0）

**场景：** Mock `NacosClientService.publishConfig` 抛出网络异常，验证 release 操作正常返回，DB 状态已落地，不向调用方透传异常。

**为什么必须：** Nacos 同步是非阻塞的可选步骤，但目前没有任何测试保证它真的被降级处理而非向上传播。一旦 Nacos 网络抖动，Prompt 发布全线阻塞。

**建议类型：** 单元测试（Mock NacosClientService，测试 PromptVersionService.release 的错误隔离）

---

### G06 — ChatSession Redis 序列化往返（P0）

**场景：** 创建 ChatSession 并写入多条 Spring AI `Message` 对象 → 从 Redis 读回 → 验证消息数量、类型、内容与写入时一致。

**为什么必须：** Spring AI `Message` 的序列化格式随库版本变化。升级 `spring-ai-alibaba` 后，旧会话可能因反序列化失败导致调试功能全线崩溃，且报错发生在运行时而非编译时。

**建议类型：** 集成测试（嵌入式 Redis 或 Testcontainers）

---

### G07 — 文档上传全链路 index_status 流转（P0）

**场景：** 上传文档 → 等待异步处理完成 → 查询 `document.index_status = 3`，ES 中可用 doc_id 检索到至少一个 chunk。

**为什么必须：** 这条链路跨 5 个系统，任何一个断裂都导致 `index_status` 卡在 1 或 2，但现有只有 Reader 和 Splitter 的工具级单元测试，不覆盖 MQ 消费→ES 写入的完整路径。替换 MQ 或 VectorStore 实现时这是最先断的地方。

**建议类型：** 集成测试（Testcontainers：MySQL + Redis + ES + RocketMQ，或用内存替代）

---

### G08 — 文档索引失败时 error 字段落地（P0）

**场景：** Mock Embedding 调用抛出异常 → 消费者捕获后 `document.index_status` 更新为失败状态，`error` 字段写入原因字符串。

**为什么必须：** 没有这个兜底行为，索引失败就是静默失败——文档一直显示"处理中"，用户和运维都无法感知。

**建议类型：** 集成测试（Mock Embedding，验证 DB 最终状态）

---

### G09 — 实验执行完成状态（P0）

**场景：** 创建实验 → 调用 run → 等待完成 → 验证 `experiment.status = COMPLETED`，`experiment_result` 行数 = 数据集 `data_count`。

**为什么必须：** 状态机有 5 个值，`RUNNING → COMPLETED` 路径没有测试，任何对 `ExperimentService.run` 的重构都可能让状态永久停在 `RUNNING`。

**建议类型：** 集成测试

---

### G10 — score > 1 被拒绝或截断（P0）

**场景：** 评估脚本返回 score = 1.5，验证 `experiment_result.score` 不静默截断为 1.00，而是抛出业务异常或拒绝写入。

**为什么必须：** DB 字段 `DECIMAL(3,2)` 会静默截断，上层没有校验。被截断的数据会破坏实验结果聚合分析，且极难事后发现。

**建议类型：** 单元测试（测试 ExperimentService 的 score 校验逻辑）

---

### G11 — 实验异常后 status = FAILED（P0）

**场景：** 让实验执行过程中抛出运行时异常 → 验证 `experiment.status` 最终为 `FAILED` 而非 `RUNNING`。

**为什么必须：** 没有超时兜底，若异常被吞掉，实验永久卡在 `RUNNING`，无法重新提交，且占用系统资源。

**建议类型：** 集成测试（Mock 某个依赖抛异常，验证 DB 状态）

---

### G12 — App 发布后 status 和 config 快照（P0）

**场景：** 创建 App → 配置节点图 → 调用 publish → 验证 `application.status = 2` 且 `application_version.config` 非空 JSON。

**为什么必须：** OpenAPI 对话依赖 `application_version.config` 解析节点图，快照为空或格式错误会导致所有对话请求 500。publish 逻辑改动时必须有回归保障。

**建议类型：** 集成测试

---

### G13 — OpenAPI api_key 鉴权（P0）

**场景：** 用有效 api_key 发起对话返回 200；用无效 api_key 返回 401；不携带 api_key 返回 401。

**为什么必须：** OpenAPI 鉴权与 Console JWT 是完全独立的两套体系（见 critical-paths.md 链路 6），改造任一套不影响另一套。没有测试时，一次认证层重构很容易让 OpenAPI 鉴权失效且不被发现。

**建议类型：** 集成测试（`@WebMvcTest` + Mock Service）

---

### G14 — RAG 检索 score_threshold 过滤行为（P0）

**场景：** 索引若干文档 → 用相关查询检索（预期返回结果）→ 用无关查询检索（预期因 threshold 过滤后返回空集）→ 验证两种结果符合预期。

**为什么必须：** score_threshold 设置过高时所有结果被过滤，表现与"文档未索引"完全相同，极难区分。替换 VectorStore 实现时这是最先暴露问题的地方。

**建议类型：** 集成测试（Testcontainers ES，真实 KNN 查询）

---

### G15 — AI 未配置时 SSE 返回可识别错误（P1）

**场景：** 未配置 AI 模型 API Key，调用 Prompt 调试接口，验证 SSE 流包含明确的错误事件（如 `event: error`），而不是静默关闭连接。

**为什么必须：** 当前行为未知——可能抛异常断连，可能返回空流，两种都让前端无法区分"模型未配置"和"网络超时"。属于 Characterization Test：先固化当前行为，再决定是否改。

**建议类型：** Characterization Test（记录现状，防止无意改变）

---

### G16 — Embedding 维度不匹配时明确报错（P1）

**场景：** 用维度 A 索引文档后，切换到维度 B 的 Embedding 模型执行检索，验证抛出明确的维度不匹配异常，不返回静默空结果。

**为什么必须：** 换模型是常见操作，维度不匹配时 ES 会抛异常，但异常是否被正确传递到上层未经验证。静默返回空集比报错更危险。

**建议类型：** 单元测试（Mock VectorStore 抛 ES 异常，验证 Service 层传播行为）

---

### G17 — 悬空引用时 App 对话返回业务错误（P1）

**场景：** App 引用了一个已被软删除的 KB，发起对话请求，验证返回业务错误码而非 NullPointerException 堆栈。

**为什么必须：** `reference` 表无 FK 约束，软删除后引用成悬空。这是现有架构的已知设计债（见 critical-paths.md），属于 Characterization Test：固化当前行为，防止重构时将"业务错误"误改为"崩溃"。

**建议类型：** Characterization Test

---

### G18 — GitHub 邮箱为 null 时注册不崩溃（P1）

**场景：** Mock GitHub OAuth2 UserInfo 返回 email = null，验证 `Oauth2Service` 不因 NOT NULL 约束或空指针崩溃，而是返回可识别的业务错误或用备用标识注册。

**为什么必须：** GitHub 允许用户不公开邮箱，这是生产环境的真实场景，不是边缘情况。

**建议类型：** 单元测试（Mock OAuth2UserInfo，测试 Oauth2Service 的 null 邮箱处理分支）

---

### G19 — Nacos 端口配置错误时报错明确（P1）

**场景：** `NacosClientService` 连接地址配置为 gRPC 端口（9848）而非 HTTP 端口（8848/7848），验证抛出的异常包含可识别的端口/协议错误信息，不是通用超时。

**为什么必须：** docker-compose.dev.yml 中 Nacos 端口映射非直觉（7848→8848），错误配置是高频新人问题。明确报错可以节省排查时间。

**建议类型：** 单元测试

---

### G20 — Token 响应字段名序列化不变（P1）

**场景：** 调用登录接口，验证响应 JSON 中 Token 字段名为 `access_token`（snake_case），升级 Jackson 版本或修改 `@JsonProperty` 注解后不变为 `accessToken`。

**为什么必须：** 前端硬编码读取 `access_token`，若字段名变化会导致所有前端请求 401 且错误原因极隐蔽（返回值看起来正常）。这是接口契约，需要显式固定。

**建议类型：** 单元测试（`ObjectMapper` 序列化 `TokenResponse`，断言字段名）

---

## P0 缺口一览（改造前必须补齐的 14 项）

| 优先级 | 涉及链路 | 缺口 |
| --- | --- | --- |
| P0 | 链路 1 | G01 完整登录流 |
| P0 | 链路 1 | G02 登出 Token 失效 |
| P0 | 链路 1 | G03 错误密码拒绝 |
| P0 | 链路 2 | G04 release 两表原子性 |
| P0 | 链路 2 | G05 Nacos 不可达降级 |
| P0 | 链路 3 | G06 ChatSession 序列化往返 |
| P0 | 链路 4 | G07 文档全链路 index_status 流转 |
| P0 | 链路 4 | G08 索引失败 error 字段落地 |
| P0 | 链路 5 | G09 实验完成状态 |
| P0 | 链路 5 | G10 score > 1 被拒绝 |
| P0 | 链路 5 | G11 实验异常后 FAILED 状态 |
| P0 | 链路 6 | G12 App 发布快照 |
| P0 | 链路 6 | G13 OpenAPI api_key 鉴权 |
| P0 | 链路 7 | G14 RAG score_threshold 行为 |
