# 测试现状报告

> 扫描时间：2026-04-27
> 扫描范围：所有 Maven 模块 `src/test/java/`、前端 `src/`（含 `__tests__`、`*.spec.*`、`*.test.*`）

---

## 一、测试文件统计

### 按类型

| 类型 | 文件数 | 说明 |
|------|--------|------|
| 单元测试 | 7 | 纯 JUnit 5 + Mockito，无 Spring 容器启动 |
| 集成测试 | 0 | 无 `@SpringBootTest`、无 `@DataJpaTest`、无 `@WebMvcTest` |
| E2E 测试 | 0 | 无 |
| 前端测试 | 0 | frontend/ 目录无任何 `.test.ts`/`.spec.tsx` 文件 |

**全部 7 个测试文件集中在 `server-core` 模块。其余三个模块（server-runtime、server-openapi、server-start）无任何测试。**

### 测试文件清单

| 文件 | 被测对象 | 测试手段 | 实际有效性 |
|------|----------|----------|-----------|
| `PasswordCryptTest` | `PasswordCryptUtils`（Argon2id） | 真实调用 | ✅ 有效，验证了 encode + match 逻辑 |
| `RSACryptTest` | RSA 加解密工具 | 真实调用 | ✅ 有效 |
| `DateUtilsTests` | `DateUtils` 日期解析 | 真实调用 | ✅ 有效 |
| `TextDocumentReaderTest` | `TextDocumentReader`（文档读取） | 真实调用 | ✅ 有效，使用 `springaialibaba.txt` 资源 |
| `TextSplitterTest` | `TextSplitter`（分块） | 真实调用 | ✅ 有效，含空输入边界测试 |
| `KnowledgeBaseIndexPipelineTest` | `KnowledgeBaseIndexPipeline` | **仅 Mock 调用验证** | ⚠️ 无效——测试对象本身是 Mock，只验证了方法被调用，没有验证任何业务逻辑 |
| `DashscopeRerankerTest` | `DashscopeReranker` | **仅 Mock 调用验证** | ⚠️ 无效——被测对象是 Mock，等价于测试 Mockito 框架本身；多个测试方法被注释掉 |

> **注：** `KnowledgeBaseIndexPipelineTest` 和 `DashscopeRerankerTest` 中，被测对象用 `@Mock` 声明后直接 `when(...).thenReturn(...)` 再调用，不涉及任何真实实现代码，对发现 bug 没有价值。

---

## 二、Controller 覆盖情况

共 32 个 Controller，**0 个有对应测试**。

| 模块 | Controller | 有测试 |
|------|-----------|--------|
| server-openapi | `ChatController` | ❌ |
| server-core（builder） | `AuthController` | ❌ |
| server-core（builder） | `AccountController` | ❌ |
| server-core（builder） | `AppController` | ❌ |
| server-core（builder） | `AppChatController` | ❌ |
| server-core（builder） | `WorkflowController` | ❌ |
| server-core（builder） | `KnowledgeBaseController` | ❌ |
| server-core（builder） | `DocumentController` | ❌ |
| server-core（builder） | `DocumentChunkController` | ❌ |
| server-core（builder） | `PluginController` | ❌ |
| server-core（builder） | `ToolController` | ❌ |
| server-core（builder） | `McpServerController` | ❌ |
| server-core（builder） | `AgentSchemaController` | ❌ |
| server-core（builder） | `ProviderController` | ❌ |
| server-core（builder） | `ModelController` | ❌ |
| server-core（builder） | `ApiKeyController` | ❌ |
| server-core（builder） | `WorkspaceController` | ❌ |
| server-core（builder） | `Oauth2Controller` | ❌ |
| server-core（builder） | `FileController` | ❌ |
| server-core（builder） | `SystemController` | ❌ |
| server-core（builder） | `AppComponentController` | ❌ |
| server-core（builder） | `ApiExampleController` | ❌ |
| server-core（generator） | `ApplicationController` | ❌ |
| server-core（generator） | `DSLController` | ❌ |
| server-core（generator） | `GeneratorController` | ❌ |
| server-core（generator） | `RunnerController` | ❌ |
| server-core（admin） | `PromptController` | ❌ |
| server-core（admin） | `DatasetController` | ❌ |
| server-core（admin） | `EvaluatorController` | ❌ |
| server-core（admin） | `ExperimentController` | ❌ |
| server-core（admin） | `ModelConfigController` | ❌ |
| server-core（admin） | `ObservabilityController` | ❌ |

---

## 三、核心 Service 覆盖情况

共 35 个 Service 类，**0 个有直接测试**（`PasswordCryptTest` 测的是工具类而非 Service）。

| 核心 Service | 链路相关性 | 有测试 |
|-------------|-----------|--------|
| `AccountService` | 链路 1、8（登录、OAuth2） | ❌ |
| `Oauth2Service` | 链路 8（GitHub OAuth2） | ❌ |
| `PromptService` / `PromptVersionService` | 链路 2、3 | ❌ |
| `ChatSessionService` | 链路 3（SSE 调试会话） | ❌ |
| `PromptRunService` | 链路 3（实际 AI 调用） | ❌ |
| `NacosClientService` | 链路 2（Nacos 同步） | ❌ |
| `DocumentService` | 链路 4（文档上传→ES） | ❌ |
| `KnowledgeBaseService` | 链路 4、7 | ❌ |
| `VectorStoreService` / `ElasticSearchVectorStoreService` | 链路 4、7 | ❌ |
| `ExperimentService` | 链路 5（实验状态机） | ❌ |
| `AppService` | 链路 6（App 发布） | ❌ |
| `AgentService` / `WorkflowService` | 链路 6（对话编排） | ❌ |
| `ReferService` | 链路 6（KB/Plugin 引用） | ❌ |
| `ApiKeyService` | 链路 6（OpenAPI 鉴权） | ❌ |
| `TracingService` | 链路 1 以外（可观测性） | ❌ |
| `DatasetService` / `DatasetVersionService` | 链路 5 | ❌ |
| `EvaluatorService` / `EvaluatorVersionService` | 链路 5 | ❌ |

---

## 四、核心链路测试覆盖对照

对照 [docs/critical-paths.md](critical-paths.md)：

| # | 链路 | 覆盖状态 | 说明 |
|---|------|----------|------|
| 1 | 登录 → Token → Redis 失效 | **没有** | `AccountService`、JWT 生成、Redis 写入均无测试；`PasswordCryptUtils` 有单元测试但不覆盖登录流程 |
| 2 | Prompt 创建 → 发布 → Nacos 同步 | **没有** | `PromptService`、`PromptVersionService`、`NacosClientService` 均无测试 |
| 3 | Prompt 版本调试（SSE） | **没有** | `ChatSessionService`（Redis 序列化）、`PromptRunService`（AI 调用）、SSE 推送均无测试 |
| 4 | 文档上传 → RocketMQ → ES 向量写入 | **部分** | `TextDocumentReaderTest`（读取）、`TextSplitterTest`（分块）有真实单元测试；但 RocketMQ 消费、Embedding 调用、ES 写入、`index_status` 状态更新均无测试；`KnowledgeBaseIndexPipelineTest` 是 Mock 无效测试 |
| 5 | 实验执行（状态机） | **没有** | `ExperimentService` 状态流转、GraalVM 脚本执行、`experiment_result` 写入均无测试 |
| 6 | Agent/Workflow 发布 → OpenAPI 对话 | **没有** | `AppService`、`AgentService`、`WorkflowService`、`ReferService`、`ChatController` 均无测试 |
| 7 | 知识库 RAG 检索 | **部分** | `TextSplitterTest`（分块）有效；`DashscopeRerankerTest` 是 Mock 无效测试；ES KNN 查询、`score_threshold` 过滤、Embedding 维度一致性均无测试 |
| 8 | OAuth2 GitHub 登录 → Cookie → 前端重定向 | **没有** | `Oauth2Service`、Cookie 写入、前端 SPA 路由跳转均无测试 |

---

## 五、总结

- **有效测试：5 个**（PasswordCrypt、RSACrypt、DateUtils、TextDocumentReader、TextSplitter），全部是工具类/基础组件单元测试
- **无效测试：2 个**（KnowledgeBaseIndexPipeline、DashscopeReranker），Mock 对象自测，没有执行任何真实代码
- **8 条核心链路：6 条完全没有测试，2 条（链路 4、7）仅有管道中某个工具步骤的局部覆盖**
- **所有 Controller、所有 Service、所有跨系统集成点（Redis、RocketMQ、ES、Nacos、AI 模型）均无测试**
- 当前测试对"改造时发现问题"几乎没有保护作用；任何对 Service 层或 Controller 层的重构都缺乏回归保障

---

## 六、实际运行结果

> 运行时间：2026-04-27 11:37
> 命令：`mvn test -pl spring-ai-alibaba-admin-server-runtime,spring-ai-alibaba-admin-server-core`
> 说明：`server-openapi` 和 `server-start` 无测试文件，Surefire 对这两个模块输出 "No tests to run"，不计入统计。需先带 `server-runtime` 一起跑才能解析依赖（单独 `-pl server-core` 找不到 SNAPSHOT jar）。

### 逐文件结果

| 测试类 | 测试数 | 通过 | 失败 | 错误 | 跳过 | 耗时 |
| --- | --- | --- | --- | --- | --- | --- |
| `RSACryptTest` | 2 | 2 | 0 | 0 | 0 | 0.056 s |
| `PasswordCryptTest` | 2 | 2 | 0 | 0 | 0 | 0.709 s |
| `DateUtilsTests` | 2 | 2 | 0 | 0 | 0 | 0.059 s |
| `TextDocumentReaderTest` | 1 | 1 | 0 | 0 | 0 | 0.455 s |
| `DashscopeRerankerTest` | 2 | 2 | 0 | 0 | 0 | 0.023 s |
| `KnowledgeBaseIndexPipelineTest` | 3 | 3 | 0 | 0 | 0 | 5.054 s |
| `TextSplitterTest` | 2 | 2 | 0 | 0 | 0 | 0.042 s |
| **合计** | **14** | **14** | **0** | **0** | **0** | **~10.9 s** |

### 汇总

| 指标 | 数值 |
| --- | --- |
| 总测试数 | 14 |
| 通过 | 14 |
| 失败 | 0 |
| 错误 | 0 |
| 跳过 | 0 |
| 通过率 | 100% |
| 总耗时 | 10.9 s（含依赖解析约 0.3 s） |
| 构建结果 | BUILD SUCCESS |

### 失败分类

无失败。以下为运行期间的非失败异常情况：

| 现象 | 类型 | 影响 |
| --- | --- | --- |
| `KnowledgeBaseIndexPipelineTest` 耗时 5.05 s | 环境——`Sequence` 初始化慢（Snowflake workerId 探测） | 不影响结果 |
| `DateUtilsTests` 打印 WARN 堆栈（`Failed to parse date string: invalid-date`） | 预期行为——该测试故意传入非法日期验证 null 返回 | 不影响结果 |
| ByteBuddy agent 动态加载警告（Java 21 兼容性） | JVM 兼容性警告，Mockito 使用 byte-buddy-agent | 不影响结果 |

### 测试健康度判断

| 维度 | 状态 | 说明 |
| --- | --- | --- |
| 执行通过率 | 🟢 绿（100%） | 14/14 全部通过，无失败、无跳过 |
| 测试有效性 | 🔴 红 | 14 个测试中 5 个（KnowledgeBaseIndexPipeline 3 个 + DashscopeReranker 2 个）是 Mock 自测，不覆盖任何真实代码 |
| 链路保护能力 | 🔴 红 | 8 条核心链路 6 条零覆盖，有效覆盖约 9%（2/14 个有效测试触及 RAG 管道的工具步骤） |

> **综合健康度：🔴 红**
>
> 执行层面是绿色的（跑不挂），但测试本身的保护价值极低。"100% 通过率"是假象——半数测试是 Mock 自证，其余只覆盖工具类边角逻辑，任何一条核心链路出问题都无法被现有测试捕获。
