# 测试现状报告

> 扫描时间：2026-05-12  
> 扫描范围：全部 4 个 Maven 模块 + 3 个前端 package  

---

## 一、测试文件统计

| 类别 | 文件数 | 说明 |
|------|--------|------|
| 单元测试（Mockito，无 Spring 容器） | 7 | server-core × 5，server-start × 2 |
| 集成测试（@SpringBootTest / 需真实中间件） | 0 | 无 |
| E2E / API 测试 | 0 | 无 |
| 前端测试（Jest / Vitest / Cypress 等） | 0 | 无 |
| **合计** | **9** | 仅 Java 单元测试，全部在 server-core / server-start |

### 按 Maven 模块分布

| 模块 | 有无 src/test | 测试文件数 |
|------|-------------|----------|
| server-core | ✓ | 7 |
| server-start | ✓ | 2 |
| server-openapi | ✗ | 0 |
| server-runtime | ✗ | 0 |

### 现有 9 个测试文件

| 文件 | 测试内容 | 是否需要外部依赖 |
|------|---------|----------------|
| `RSACryptTest` | RSA 加解密正确性 | 否（纯算法） |
| `PasswordCryptTest` | Argon2 密码哈希 | 否（纯算法） |
| `DateUtilsTests` | 日期工具函数 | 否（纯算法） |
| `TextDocumentReaderTest` | 文档解析（读 txt fixture） | 否（本地文件） |
| `TextSplitterTest` | 文档切片逻辑 | 否（Mockito） |
| `DashscopeRerankerTest` | Reranker 接口调用 | 否（Mockito mock 外部 API） |
| `KnowledgeBaseIndexPipelineTest` | 索引 Pipeline（parse/transform/store） | 否（Mockito mock ES + Embedding） |
| `PromptVersionServiceImplTest` | PromptVersion 查询逻辑 | 否（Mockito mock Mapper） |
| `PromptVersionServiceDiffTest` | Prompt 版本 diff 逻辑 | 否（Mockito mock Mapper） |

---

## 二、Controller 覆盖情况

全部 32 个 Controller，**0 个**有对应测试。

| 模块 | Controller | 有无测试 |
|------|-----------|---------|
| Builder 平台 | AuthController | ✗ |
| Builder 平台 | AccountController | ✗ |
| Builder 平台 | WorkspaceController | ✗ |
| Builder 平台 | AppController | ✗ |
| Builder 平台 | AppChatController | ✗ |
| Builder 平台 | WorkflowController | ✗ |
| Builder 平台 | AppComponentController | ✗ |
| Builder 平台 | KnowledgeBaseController | ✗ |
| Builder 平台 | DocumentController | ✗ |
| Builder 平台 | DocumentChunkController | ✗ |
| Builder 平台 | FileController | ✗ |
| Builder 平台 | ProviderController | ✗ |
| Builder 平台 | ModelController | ✗ |
| Builder 平台 | PluginController | ✗ |
| Builder 平台 | ToolController | ✗ |
| Builder 平台 | McpServerController | ✗ |
| Builder 平台 | AgentSchemaController | ✗ |
| Builder 平台 | ApiKeyController | ✗ |
| Builder 平台 | SystemController | ✗ |
| Builder 平台 | Oauth2Controller | ✗ |
| Builder 平台 | ApiExampleController | ✗ |
| Graph Studio | ApplicationController / DSLController / GeneratorController / RunnerController | ✗ |
| 评估平台 | PromptController | ✗ |
| 评估平台 | DatasetController | ✗ |
| 评估平台 | EvaluatorController | ✗ |
| 评估平台 | ExperimentController | ✗ |
| 评估平台 | ObservabilityController | ✗ |
| 评估平台 | ModelConfigController | ✗ |
| 评估平台 | DashboardController | ✗ |
| OpenAPI | ChatController（server-openapi） | ✗ |

---

## 三、核心 Service 覆盖情况

### server-core 服务（Builder 业务核心）

| Service | 有无测试 | 备注 |
|---------|---------|------|
| AgentService | ✗ | Agent DAG 执行引擎，最复杂 |
| WorkflowService / WorkflowInnerService | ✗ | Workflow 调度，次复杂 |
| KnowledgeBaseService | ✗ | — |
| DocumentService | ✗ | — |
| VectorStoreService / ElasticSearchVectorStoreService | 部分 | `KnowledgeBaseIndexPipelineTest` mock 了 Pipeline，未测 ES 写入 |
| AppService | ✗ | — |
| AppComponentService | ✗ | — |
| ApiKeyService | ✗ | — |
| AccountService | ✗ | — |
| PluginService / ToolService / ToolExecutionService | ✗ | — |
| McpServerService | ✗ | — |
| WorkspaceService | ✗ | — |

### server-start 服务（评估平台 + 鉴权）

| Service | 有无测试 | 备注 |
|---------|---------|------|
| PromptVersionService | ✓ | 版本查询 + diff 逻辑，Mockito 覆盖 |
| PromptService | ✗ | — |
| PromptRunService | ✗ | 流式执行无测试 |
| DatasetService / DatasetVersionService / DatasetItemService | ✗ | — |
| EvaluatorService / EvaluatorVersionService | ✗ | — |
| ExperimentService | ✗ | 批量实验无测试 |
| TracingService | ✗ | — |
| ModelConfigService / ModelConfigBridgeService | ✗ | — |
| NacosClientService | ✗ | — |

---

## 四、核心链路测试覆盖（对照 docs/critical-paths.md）

| # | 链路名 | 覆盖状态 | 现有测试 | 差距说明 |
|---|--------|---------|---------|---------|
| 1 | JWT 登录 → 受保护接口 | **没有** | — | AuthController、JWT 过滤器、Redis token 存取均无测试 |
| 2 | RAG 文档上传 → 向量检索 | **部分** | `TextDocumentReaderTest`、`TextSplitterTest`、`KnowledgeBaseIndexPipelineTest`（均 mock） | 文件上传 → RocketMQ 消费 → ES 写入 → retrieve 全链路无集成测试；index_status 状态机无测试 |
| 3 | Agent 发布 → OpenAPI 外部调用 | **没有** | — | `AppController.publish`、`ApiKeyAuthInterceptor`、Agent 执行引擎均无测试；server-openapi 模块零测试 |
| 4 | Workflow 调试 → 流式执行 | **没有** | — | `WorkflowService`、DAG 节点调度、`resume-task` 幂等性、SSE 流均无测试 |
| 5 | RAG + Agent 对话（含 KB 检索） | **部分** | `DashscopeRerankerTest`（mock）、`TextSplitterTest` | ES 向量检索 → Chunk 拼接 → LLM 调用 → SSE 输出全链路无测试 |
| 6 | Prompt 版本创建 → 流式调试 | **部分** | `PromptVersionServiceImplTest`、`PromptVersionServiceDiffTest` | 仅覆盖版本查询/diff 逻辑；`PromptRunService` 流式执行、Nacos 热加载均无测试 |
| 7 | 批量实验执行 → 结果聚合 | **没有** | — | `ExperimentService`、RocketMQ 消费、`experiment_result` 写入、进度更新均无测试 |
| 8 | Trace 写入 → 可观测性查询 | **没有** | — | `TracingService`、ES ingest pipeline、`ObservabilityController`、跨存储 `dataItemFromTrace` 均无测试 |

### 覆盖汇总

| 状态 | 链路数 | 链路编号 |
|------|--------|---------|
| 有（完整） | 0 | — |
| 部分 | 3 | 2、5、6 |
| 没有 | 5 | 1、3、4、7、8 |

---

## 六、实际运行结果（mvn test）

> 执行时间：2026-05-12 08:16  
> 命令：`mvn test`（从项目根目录）  
> 总耗时：**11.980 s**

### 按模块统计

| Maven 模块 | 通过 | 失败 | 跳过 | 耗时 |
|-----------|------|------|------|------|
| server-runtime | — | — | — | 0.337 s（无测试） |
| server-core | 14 | 0 | 0 | 9.946 s |
| server-openapi | — | — | — | 0.086 s（无测试） |
| server-start | 6 | 0 | 0 | 1.486 s |
| **合计** | **20** | **0** | **0** | **11.980 s** |

### 汇总

| 指标 | 值 |
|------|-----|
| 总测试方法数 | 20 |
| 通过 | 20 |
| 失败 | 0 |
| 跳过 | 0 |
| 通过率 | 100% |
| 构建结果 | BUILD SUCCESS |

### 失败分类

无失败。运行过程中出现以下**非致命警告**，不影响测试结果：

| 警告 | 类型 | 说明 |
|------|------|------|
| `byte-buddy-agent` 动态加载警告 | JVM 版本兼容提示 | Java 21 对动态 agent 加载收紧，Mockito 使用的 ByteBuddy agent 触发；不影响测试逻辑，未来版本可能需要加 `-XX:+EnableDynamicAgentLoading` |
| `Sequence Very Slow! workerId:10` | 环境提示 | Snowflake ID 生成器初始化时检测到机器 ID 分配较慢，测试仍通过 |
| `JBossLoggerFinder` LogManager 顺序错误 | 日志配置警告 | Quarkus/JBoss 日志框架与 JUL 初始化顺序问题，不影响断言 |
| `Sharing is only supported for boot loader classes` | JVM CDS 提示 | Class Data Sharing 在 agent 加载后不可用，纯性能提示 |

### 测试健康度

| 评级 | 标准 | 当前状态 |
|------|------|---------|
| 🟢 绿 | 通过率 ≥ 90% | **100%（20/20）** |
| 🟡 黄 | 60–90% | — |
| 🔴 红 | < 60% | — |

**结论：现有测试全部通过，健康度 🟢 绿。**

但需特别注意：这 20 个测试方法全部是 Mockito 单元测试，没有一个真正触碰数据库、Redis、ES、RocketMQ 或 Nacos。"全绿"反映的是 mock 层逻辑的正确性，不能代表系统整体健康。结合第五节的覆盖分析，8 条核心链路中有 5 条完全无测试保障。

---

## 五、结论

- 现有 9 个测试全部是**纯算法 / Mock 层单元测试**，没有一个打通完整链路。
- **Controller 层零覆盖**（32 个 Controller 无一有测试），**集成测试和 E2E 测试空白**。
- 风险最高的 5 条链路（JWT 鉴权、Agent 发布外部调用、Workflow DAG、批量实验、Trace）完全没有任何测试保障。
- "部分覆盖"的 3 条链路（RAG、RAG+Agent、Prompt）只覆盖了中间某个子组件，跨中间件的端到端路径均未验证。
