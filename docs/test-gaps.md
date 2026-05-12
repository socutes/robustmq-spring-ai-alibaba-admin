# 测试缺口清单

> 来源：对照 docs/critical-paths.md × docs/test-status.md  
> 原则：只列核心链路上的缺口；P0 = 改造前必须有，P1 = 有了更好；总数 ≤ 20。  
> 日期：2026-05-12

---

## 缺口总表

| # | 链路 | 场景描述 | 为什么必须 | 优先级 | 建议测试类型 |
|---|------|---------|-----------|--------|------------|
| G01 | 链路 1：JWT 鉴权 | 用正确凭证登录，返回 accessToken；用错误密码返回 401；用过期 token 访问受保护接口返回 401 | JWT 过滤器拦截路径配置一旦被改动，全平台鉴权会静默失效，且无任何现有测试兜底 | **P0** | 集成测试（@SpringBootTest + MockMvc，内嵌 H2 / Testcontainers MySQL） |
| G02 | 链路 1：JWT 鉴权 | refresh-token 换新 token 后，旧 access token 应失效（Redis 黑名单逻辑） | 多端登录、token 轮换场景下 Redis 黑名单写入/读取若有 bug，用旧 token 仍可访问，安全漏洞 | **P0** | 集成测试（需真实 Redis，或 Testcontainers） |
| G03 | 链路 3：OpenAPI ApiKey 鉴权 | 携带有效 ApiKey 调用 `/api/v1/apps/chat/completions`，鉴权通过；无 Key / 错误 Key 返回 403 | JWT 和 ApiKey 是两套拦截器并存，路径匹配规则改动时二者可能互相干扰，导致越权或全部拒绝 | **P0** | 集成测试（MockMvc + Stub Agent 执行引擎） |
| G04 | 链路 3：Agent 发布状态机 | `POST /apps/{appId}/publish` 将 application.status 1→2，再次发布 status 3→2；发布后 application_version 快照存在 | 状态机转换是业务核心约束，重构 AppService 时极易引入静默错误，发现时已有脏数据 | **P0** | 集成测试（真实 MySQL 或 Testcontainers） |
| G05 | 链路 2：文档索引状态机 | 添加文档后 document.index_status = 1（待处理）；消费 RocketMQ 消息后变为 2（处理中）；完成后变为 3（已完成） | 状态卡在 2 是常见生产故障，现有测试完全 mock 了 MQ 消费，无法发现消费者代码的回归 | **P0** | 集成测试（Testcontainers RocketMQ + ES，或 Characterization Test 记录现有行为） |
| G06 | 链路 2 / 链路 5：向量检索 | 向知识库写入 1 条文档 Chunk 后，`POST /retrieve` 能检索到该 Chunk | RAG 核心场景；ES mapping 或 ingest pipeline 版本不兼容时检索静默返回空，Agent 对话无 context | **P0** | 集成测试（需真实 ES，或 Testcontainers Elasticsearch） |
| G07 | 链路 4：Workflow DAG 调度 | 含 LLM 节点的线性 Workflow 执行完毕，所有节点状态 = COMPLETED；含分支节点的 Workflow 走正确分支 | JGraphT DAG 拓扑排序 + 节点并发是手写调度逻辑，重构时最容易引入死锁或节点跳过 | **P0** | 单元测试（mock LLM 调用，测调度逻辑本身） |
| G08 | 链路 4：Workflow 人工审核节点 | `resume-task` 在任务 PAUSED 状态下幂等执行两次不重复触发；非 PAUSED 状态下 resume 返回错误 | 人工审核节点是唯一有暂停/恢复状态机的节点，幂等性无测试意味着重试风暴可能重复执行 | **P1** | 单元测试（mock 状态仓储） |
| G09 | 链路 5：RAG + Agent 对话（SSE） | `POST /console/v1/apps/chat/completions`（stream=true）返回 `text/event-stream`；末帧 status=COMPLETED 存在 | SSE 流式输出是前端依赖的协议契约，末帧缺失会导致前端 loading 永不结束 | **P0** | 集成测试（MockMvc SSE + mock LLM + mock ES） |
| G10 | 链路 6：Prompt 流式调试 | `POST /api/prompt/run` 返回 NDJSON 流；变量替换正确（`{{var}}` → 实际值）；不存在的 promptKey 返回 404 | PromptRunService 是 Flux 响应式链，任何同步阻塞调用都会挂起整个响应流；变量替换是纯逻辑易写错 | **P0** | 单元测试（mock 模型调用，测变量替换 + 流帧格式） |
| G11 | 链路 6：Nacos 热加载 | 修改 Nacos 中的 Prompt 配置后，不重启服务，下一次 `prompt/run` 使用新配置 | Nacos 热加载是 Prompt 平台的核心卖点，配置监听器注册代码改动后容易静默失效 | **P1** | 集成测试（需真实 Nacos 或 mock NacosClientService） |
| G12 | 链路 7：实验创建 → 状态流转 | `POST /api/experiment` 创建实验后 status=RUNNING；`PUT /experiment/stop` 将 RUNNING→STOPPED；COMPLETED 状态下 stop 返回错误 | 实验状态机是评估平台核心约束，STOPPED 后仍有消费者写 experiment_result 是典型竞争条件 | **P0** | 单元测试（mock ExperimentRepository，测状态机转换） |
| G13 | 链路 7：实验结果写入幂等性 | 同一条 dataset_item × evaluator_version 组合被重复消费时，experiment_result 不重复写入 | RocketMQ 消费者 at-least-once 保证，重试时若无幂等逻辑会产生重复评分记录，实验结果失真 | **P0** | 单元测试（mock Repository，验证重复消费时结果数不变） |
| G14 | 链路 8：Trace 查询 → DTO 映射 | `GET /api/observability/traces` ES 查询结果能正确映射为 `TraceSpanDTO`；`GET /traces/{traceId}` 能还原 Span 父子树结构 | ES 返回的 flat Span 列表需要按 parentSpanId 重建树，树重建逻辑是纯算法，适合单元测试，现在完全无覆盖 | **P0** | 单元测试（构造 flat Span list，断言树结构正确） |
| G15 | 链路 8：Trace → 数据项跨存储写入 | `POST /api/dataset/dataItemFromTrace` 从 ES 读取 Trace 内容，写入 agentscope.dataset_item，返回新 dataItemId | 唯一跨存储写操作（ES 读 + MySQL 写），ES 字段结构变更时映射静默丢数据 | **P1** | 集成测试（mock ES 返回 + 真实 JPA 写入，或全 mock 的 Characterization Test） |
| G16 | 链路 2 / 链路 5：Embedding 模型不可用降级 | Embedding 服务调用超时或返回错误时，文档索引失败并将 document.index_status 置为对应错误状态，不静默卡死 | 外部 AI 服务不稳定是常态；无测试则 Embedding 异常时 index_status 永远卡在 2，用户无法感知 | **P1** | 单元测试（mock Embedding 客户端抛异常，验证 index_status 更新逻辑） |

---

## 按优先级汇总

| 优先级 | 数量 | 编号 |
|--------|------|------|
| P0（改造前必须有） | 11 | G01 G02 G03 G04 G05 G06 G07 G09 G10 G12 G13 G14 |
| P1（有了更好） | 5 | G08 G11 G15 G16（含 G16） |
| **合计** | **16** | — |

## 按测试类型汇总

| 类型 | 缺口项 | 说明 |
|------|--------|------|
| 单元测试 | G07 G08 G10 G12 G13 G14 G16 | 纯逻辑，可立即编写，不依赖中间件 |
| 集成测试 | G01 G02 G03 G04 G05 G06 G09 G11 G15 | 需要 Testcontainers 或真实中间件，成本较高 |

## 建议推进顺序

1. **先写 P0 单元测试**（G07 G10 G12 G13 G14）：不依赖环境，一天内可落地，覆盖 DAG 调度、Prompt 变量替换、实验状态机、Span 树重建 4 个高风险纯逻辑。
2. **再补 P0 集成测试**（G01 G03 G04 G09 优先）：引入 Testcontainers，用 MockMvc 覆盖鉴权、发布状态机、SSE 流格式 3 条最高风险链路。
3. **G05 G06**（文档索引 + 向量检索）依赖 ES + RocketMQ，建议用 Testcontainers 单独建 test profile，放 CI 的 integration-test 阶段。
4. **P1 缺口**（G08 G11 G15 G16）在 P0 全绿后按迭代节奏补齐。
