# 补测试计划

> 来源：docs/test-gaps.md P0 缺口（14 项）
> 排批原则：Characterization Test → 核心链路集成测试 → 复杂逻辑单元测试
> 每批 1–2 项，粒度够小才能真正落地

---

## 批次总览

| 批次 | 缺口 | 测试类型 | 核心链路 | 预期工作量 |
| --- | --- | --- | --- | --- |
| Batch 1 | G20 Token 字段名序列化 | 单元测试 | 链路 1 | 0.5 天 |
| Batch 2 | G05 Nacos 不可达降级 | 单元测试 | 链路 2 | 1 天 |
| Batch 3 | G10 score > 1 被拒绝 | 单元测试 | 链路 5 | 0.5 天 |
| Batch 4 | G01 完整登录流、G03 错误密码拒绝 | 集成测试 | 链路 1 | 2 天 |
| Batch 5 | G02 登出 Token 失效 | 集成测试 | 链路 1 | 1 天 |
| Batch 6 | G06 ChatSession 序列化往返 | 集成测试 | 链路 3 | 1 天 |
| Batch 7 | G04 Prompt release 两表原子性 | 集成测试 | 链路 2 | 1.5 天 |
| Batch 8 | G13 OpenAPI api_key 鉴权 | 集成测试 | 链路 6 | 1.5 天 |
| Batch 9 | G12 App 发布快照 | 集成测试 | 链路 6 | 1.5 天 |
| Batch 10 | G09 实验完成状态、G11 异常后 FAILED | 集成测试 | 链路 5 | 2 天 |
| Batch 11 | G08 索引失败 error 字段落地 | 集成测试 | 链路 4 | 1.5 天 |
| Batch 12 | G07 文档全链路 index_status 流转 | 集成测试 | 链路 4 | 3 天 |
| Batch 13 | G14 RAG score_threshold 行为 | 集成测试 | 链路 7 | 2 天 |

**合计：P0 缺口 14 项，预计 19 天。**

---

## 批次详情

### Batch 1 — Token 字段名序列化契约

**缺口：** G20
**类型：** 单元测试
**链路：** 链路 1（登录 → Token）
**工作量：** 0.5 天

**做什么：** 用 `ObjectMapper` 序列化 `TokenResponse` 对象，断言输出 JSON 包含 `access_token`（snake_case）字段名，不出现 `accessToken`。

**为什么先做：** 这是最便宜的 P0 测试，零基础设施依赖，30 分钟可写完。同时它是接口契约的基线——后续所有集成测试都依赖从登录响应里正确提取 Token，如果字段名变了会级联破坏所有测试。先把契约固定住。

**前置条件：** 无。

---

### Batch 2 — Nacos 不可达时 release 降级

**缺口：** G05
**类型：** 单元测试
**链路：** 链路 2（Prompt 创建 → 发布 → Nacos 同步）
**工作量：** 1 天

**做什么：** Mock `NacosClientService.publishConfig` 抛出网络异常，调用 `PromptVersionService.release`，断言：（1）方法正常返回不向上抛出；（2）DB 中 `prompt_version.status` 已变为 `release`。

**为什么放早：** Nacos 网络失败是生产环境高概率场景。当前代码若没有 try-catch，则任何 Nacos 抖动都会让 Prompt 发布全线阻塞。属于"改造前先确认现有行为是否安全"的 Characterization 性质。

**前置条件：** Mockito；测试用 H2 或真实 MySQL。

---

### Batch 3 — score 越界拒绝写入

**缺口：** G10
**类型：** 单元测试
**链路：** 链路 5（实验执行状态机）
**工作量：** 0.5 天

**做什么：** 构造评估脚本返回 score = 1.5，调用 `ExperimentService` 中写入结果的逻辑，断言抛出业务异常或 score 被校验拒绝，不静默写入 DB 被截断为 1.00。

**为什么放早：** 纯单元测试，零环境依赖。`DECIMAL(3,2)` 的静默截断是数据质量问题，先用测试固化预期行为（"应该报错"），再决定是否需要加校验层。

**前置条件：** 无。

---

### Batch 4 — 完整登录流 + 错误密码拒绝

**缺口：** G01、G03
**类型：** 集成测试
**链路：** 链路 1（登录 → Token → Redis）
**工作量：** 2 天

**做什么：**
- G01：`@SpringBootTest` + Testcontainers Redis + 真实 MySQL，调用登录接口，断言 JWT 结构合法、Redis 中存在对应 Token key、TTL > 0。
- G03：用错误密码调用登录，断言 HTTP 401，响应体不含"账号不存在"/"密码错误"枚举字符串。

**为什么放第四批：** 需要搭集成测试基础设施（Testcontainers 配置、测试 Spring Profile、DB 初始化脚本），这是后续所有集成测试批次的公共脚手架。投入 2 天是因为首次搭建，之后各批次复用。

**前置条件：** Docker（Testcontainers）；复用 `docker/middleware/init/mysql/agentscope-schema.sql`。

---

### Batch 5 — 登出 Token 失效

**缺口：** G02
**类型：** 集成测试
**链路：** 链路 1（登录 → Token → Redis 失效）
**工作量：** 1 天

**做什么：** 登录获取 Token → 调用 logout → 用原 Token 请求受保护接口（任意一个需要鉴权的接口），断言返回 401。

**为什么单独一批：** 复用 Batch 4 的基础设施，但逻辑独立（验证 Redis DEL 而非写入），单独拆开便于失败时定位。

**前置条件：** Batch 4 的 Testcontainers 脚手架。

---

### Batch 6 — ChatSession Redis 序列化往返

**缺口：** G06
**类型：** 集成测试
**链路：** 链路 3（Prompt SSE 调试）
**工作量：** 1 天

**做什么：** 调用 `ChatSessionService.create` 写入包含多条 `UserMessage` / `AssistantMessage` 的会话 → 从 Redis 读回 → 断言消息数量、类型、内容与写入时完全一致，不出现反序列化异常。

**为什么必须：** Spring AI `Message` 类型层次在版本升级时序列化格式可能变化，这个测试的核心价值是"升级 spring-ai-alibaba 后第一个暴露问题"。

**前置条件：** Testcontainers Redis（复用 Batch 4）。

---

### Batch 7 — Prompt release 两表原子性

**缺口：** G04
**类型：** 集成测试
**链路：** 链路 2（Prompt 创建 → 发布）
**工作量：** 1.5 天

**做什么：** 创建 Prompt → 新建版本 → 调用 release → 查询 DB，断言 `prompt.latest_version` 和 `prompt_version.status = release` 同时成立；在 release 中途 Mock 某一步抛异常，断言两张表均未出现半改状态。

**为什么放第七批：** 需要真实 MySQL 和完整的 Prompt 建表 SQL，依赖 Batch 4 已验证的 DB 初始化流程。

**前置条件：** Batch 4 的 MySQL Testcontainer；`admin-schema.sql`。

---

### Batch 8 — OpenAPI api_key 鉴权

**缺口：** G13
**类型：** 集成测试
**链路：** 链路 6（App 发布 → OpenAPI 对话）
**工作量：** 1.5 天

**做什么：** 创建账号 → 生成 api_key → 用有效 api_key 请求 `POST /api/v1/apps/chat` 断言不返回 401；用无效 api_key 断言 401；无 api_key 断言 401。不需要真实 AI 调用，Mock ChatClient 返回固定字符串即可。

**为什么单独一批：** OpenAPI 鉴权与 Console JWT 完全独立，是双套鉴权中最容易在认证层改造时被遗漏的一套。单独测试便于两套鉴权各自演进。

**前置条件：** Batch 4 的基础设施；Mock ChatClient。

---

### Batch 9 — App 发布后 status 和 config 快照

**缺口：** G12
**类型：** 集成测试
**链路：** 链路 6（App 发布 → OpenAPI 对话）
**工作量：** 1.5 天

**做什么：** 创建 App（携带节点图 JSON）→ 调用 publish → 查询 DB，断言 `application.status = 2`，`application_version.config` 是合法非空 JSON 且内容与提交时一致。

**为什么放第九批：** 与 G13 同属链路 6，但依赖不同（G12 验证写入，G13 验证读取鉴权），拆开避免测试互相干扰。

**前置条件：** Batch 4 的基础设施；`agentscope-schema.sql`。

---

### Batch 10 — 实验完成状态 + 异常后 FAILED

**缺口：** G09、G11
**类型：** 集成测试
**链路：** 链路 5（实验执行状态机）
**工作量：** 2 天

**做什么：**
- G09：创建数据集（2 条）+ 评估器 → 运行实验 → 等待完成 → 断言 `experiment.status = COMPLETED`，`experiment_result` 行数 = 2。
- G11：Mock 评估器调用抛出异常 → 断言 `experiment.status = FAILED`，不卡在 `RUNNING`。

**为什么合并：** 两个场景共享同一套 Fixture（数据集、评估器、实验），合并省去重复建数据的时间。

**前置条件：** Batch 4 基础设施；Mock AI 模型调用；`admin-schema.sql`。

---

### Batch 11 — 文档索引失败 error 字段落地

**缺口：** G08
**类型：** 集成测试
**链路：** 链路 4（文档上传 → RocketMQ → ES 向量写入）
**工作量：** 1.5 天

**做什么：** 上传文档 → Mock Embedding 调用抛出异常 → 等待 MQ 消费完成 → 查询 DB，断言 `document.index_status` 为失败状态，`document.error` 字段非空。

**为什么先于 G07：** 这是链路 4 的降级路径测试，比全链路正常路径（G07）依赖更少（不需要真实 ES 写入成功），可以用 Mock Embedding + 真实 MQ 完成，成本更低，且"失败兜底"比"成功路径"更值得先固化。

**前置条件：** Testcontainers RocketMQ；Mock Embedding；真实 MySQL。

---

### Batch 12 — 文档全链路 index_status 流转

**缺口：** G07
**类型：** 集成测试
**链路：** 链路 4（文档上传 → RocketMQ → ES 向量写入）
**工作量：** 3 天

**做什么：** 上传 txt 文档 → 等待异步处理 → 断言 `document.index_status = 3`；用 doc_id 查 ES，断言至少一个 chunk 存在且 content 非空。

**为什么放最后几批：** 这是整个计划中基础设施要求最高的测试，需要 Testcontainers 同时拉起 MySQL + RocketMQ + ES，且需要真实（或 Mock）Embedding 模型。3 天预算含基础设施调试时间。Batch 11 已验证了 MQ 消费路径，本批在此基础上补充 ES 写入验证。

**前置条件：** Testcontainers：MySQL + RocketMQ + Elasticsearch；真实 Embedding 或 Mock（返回固定维度向量）。

---

### Batch 13 — RAG score_threshold 过滤行为

**缺口：** G14
**类型：** 集成测试
**链路：** 链路 7（知识库 RAG 检索）
**工作量：** 2 天

**做什么：** 写入若干已知文档到 ES → 用语义相关查询检索（断言返回非空结果）→ 用完全无关查询检索（断言因 threshold 过滤后返回空集）→ 调整 threshold 到 0，断言同一无关查询返回非空结果（验证 threshold 确实生效）。

**为什么放最后：** 依赖 Batch 12 已验证的 ES 写入路径，且需要真实 KNN 查询和 Embedding 语义，无法完全 Mock。

**前置条件：** Batch 12 的 Testcontainers ES；真实 Embedding 或语义 Mock。

---

## 基础设施一次性投入说明

Batch 4 搭建的 Testcontainers 配置（Spring `@ActiveProfiles("test")`、数据库初始化、Redis 容器）将被 Batch 5–13 全部复用。建议抽取为独立的 `AbstractIntegrationTest` 基类：

```java
@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
public abstract class AbstractIntegrationTest {
    @Container
    static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0.35");
    @Container
    static GenericContainer<?> redis = new GenericContainer<>("redis:7.2.5").withExposedPorts(6379);
    // RocketMQ、ES 容器按需在子类中声明
}
```

Batch 4 的 2 天预算中包含这部分脚手架搭建，后续批次仅需继承并补充业务逻辑，每批实际编码时间约 0.5–1 天。
