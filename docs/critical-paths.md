# 核心链路清单

> 筛选标准：改造时容易出问题的链路——跨中间件、双 ORM 边界、状态机、异步任务、SSE 流式、外部鉴权。
> 共 8 条，按风险优先级排列。

---

| # | 链路名 | 起点（接口） | 关键节点 | 终点（预期状态） |
|---|--------|------------|---------|----------------|
| 1 | **JWT 登录 → 受保护接口** | `POST /console/v1/auth/login` | JWT 生成（JJWT）→ Redis 写 token → 下游请求携带 `Authorization: Bearer` → JWT 过滤器验签 | 受保护接口返回 200；token 过期或篡改返回 401 |
| 2 | **RAG 文档上传 → 向量检索** | `POST /console/v1/knowledge-bases/{kbId}/documents` | 文件落盘/OSS → RocketMQ 发消息（`topic_saa_studio_document_index`）→ 消费者切片 → Embedding 模型调用 → ES 写 index `loongsuite_traces` | `GET /retrieve` 向量检索命中新文档 Chunk；document.index_status = 3 |
| 3 | **Agent App 发布 → OpenAPI 外部调用** | `POST /console/v1/apps/{appId}/publish` | application.status 1→2 → application_version 快照写入 → ApiKey 鉴权拦截器（`ApiKeyAuthInterceptor`）验证 → Agent 执行引擎（JGraphT DAG）加载版本配置 | `POST /api/v1/apps/chat/completions`（Bearer apiKey）返回 AgentResponse；非法 Key 返回 403 |
| 4 | **Workflow 编排 → 流式调试执行** | `POST /console/v1/apps/workflow/debug/init` | 节点参数初始化 → `debug/run-task` 生成 taskId → DAG 调度各节点（LLM / 工具 / 子 Agent）→ 节点状态轮询（`get-task-process`）→ 人工审核节点 `resume-task` | `POST /workflow/{appId}/run_stream`（已发布）输出 `text/event-stream`，末帧 status=COMPLETED |
| 5 | **知识库检索注入 Agent 对话** | `POST /console/v1/apps/chat/completions`（含 KB 组件） | JWT 鉴权 → Agent 配置读取 KB 引用 → ES 向量检索（召回 Chunk）→ Chunk 拼接上下文 → LLM 调用（Spring AI Alibaba）→ SSE 流式输出 | 流式响应包含 RAG 引用；ES 或 Embedding 服务异常时链路降级或报错可观测 |
| 6 | **Prompt 版本创建 → 流式调试** | `POST /api/prompt/version` | agentscope 库 JPA 写 prompt_version → `POST /api/prompt/run`（PromptRunRequest）→ Nacos 热加载检查 → Spring AI 模型调用 → Flux<PromptRunResponse> NDJSON 流输出 | 客户端逐帧收到 NDJSON；version.status=pre；Nacos 配置变更后不重启即生效 |
| 7 | **批量实验执行 → 结果聚合** | `POST /api/experiment`（experimentId） | agentscope JPA 写 experiment(status=RUNNING) → RocketMQ 发实验任务消息 → 消费者按 dataset_item × evaluator_version 笛卡尔积调用 LLM 评估 → experiment_result 逐行写入 → progress 更新 | `GET /api/experiment/results` 返回各 evaluator 汇总评分；`PUT /api/experiment/stop` 能将 RUNNING→STOPPED |
| 8 | **Trace 可观测性写入 → 查询** | 外部 LoongCollector `OTLP HTTP :4318` 接收 Span → ES 通过 ingest pipeline `parsing_loongsuite_traces` 写 index | `GET /api/observability/traces` ES 查询分页 → DTO 映射 → `GET /api/observability/traces/{traceId}` Span 树还原；`/dataset/dataItemFromTrace` 从 Trace 创建数据项（ES→MySQL 跨存储） | Trace 列表分页正常；traceId 详情 Span 父子关系完整；从 Trace 创建的数据项落 agentscope 库 |

---

## 为什么这 8 条最容易出问题

| 链路 | 核心风险点 |
|------|-----------|
| 1 JWT | token 序列化格式、Redis key 命名与过期策略一旦改动，全平台鉴权失效 |
| 2 RAG 文档 | 跨 MySQL（元数据）+ RocketMQ（异步）+ Embedding 外部 API + ES（Chunk）四层，任何一层异常状态机卡死在 index_status=2 |
| 3 OpenAPI 发布 | 两套鉴权并存（JWT vs ApiKey），interceptor 拦截路径配置错误会导致越权或全部 403 |
| 4 Workflow DAG | JGraphT 拓扑排序 + 多节点并发 + 人工暂停恢复，状态机复杂，resume-task 幂等性难保证 |
| 5 RAG+Agent | ES 向量检索延迟直接影响首 token 时延，Chunk 拼接超上下文窗口时截断策略改动影响质量 |
| 6 Prompt 流式 | 双 ORM 边界（agentscope JPA）+ Nacos 热加载 + Reactor Flux，任何一层阻塞导致流中断或背压积压 |
| 7 批量实验 | RocketMQ 消费失败重试 × evaluator 数量放大，experiment_result 写入幂等性、进度计算竞争条件 |
| 8 Trace | ES ingest pipeline 版本依赖，mapping 变更不兼容会导致全链路 Trace 写入失败；跨 ES→MySQL 创建数据项是唯一的跨存储写操作 |
