# CLAUDE.md

> 给 Claude Code 看的项目速查手册。详细文档见 [docs/](docs/) 目录。

---

## 项目定位

**Spring AI Alibaba Admin**（内部代号 Agent Studio）是基于 Spring AI Alibaba 的 AI Agent 全生命周期管理平台。

核心能力：Prompt 工程与版本管理、数据集管理、评估器配置、实验执行与分析、可观测性（OTel 链路追踪）、AI Agent / Workflow 应用托管、知识库（RAG）、MCP Server 管理。

上游仓库已迁移至 [alibaba/spring-ai-alibaba](https://github.com/alibaba/spring-ai-alibaba/tree/main/spring-ai-alibaba-admin)，本仓库为独立维护分支。

---

## 核心架构

→ 架构分层图：[docs/architecture.svg](docs/architecture.svg)
→ 模块依赖图：[docs/module-deps.svg](docs/module-deps.svg)
→ 外部依赖图：[docs/external-deps.svg](docs/external-deps.svg)

### 四个 Maven 模块（无循环依赖）

| 模块 | 职责 |
|------|------|
| `server-runtime` | 基础设施层：MyBatis-Plus、Redis、ES、RocketMQ 客户端封装，无业务逻辑 |
| `server-core` | 业务核心：所有 Service、Domain 对象、AI 集成（Spring AI Alibaba）、GraalVM 脚本执行 |
| `server-openapi` | 对外 OpenAPI：供外部 Agent 调用的标准对话接口，依赖 server-core |
| `server-start` | 启动模块：Spring Boot 入口、配置文件、静态资源，依赖全部三个模块 |

依赖链：`server-runtime` ← `server-core` ← `server-openapi` / `server-start`

### 两个数据库

| 数据库 | 存储内容 |
|--------|---------|
| `admin` | Prompt、Dataset、Evaluator、Experiment、ModelConfig |
| `agentscope` | Account、App、KB、Plugin、Tool、Provider、Model、MCP Server、AgentSchema、Workspace、ApiKey |

### 非 MySQL 存储

| 实体 | 存储 | 说明 |
|------|------|------|
| `DocumentChunk` | Elasticsearch | Spring AI vector store，通过 RocketMQ 异步写入 |
| `ChatSession` | Redis（Redisson） | Prompt 调试会话，TTL 控制生命周期 |
| `GlobalConfig` | 无（运行时 DTO） | `SystemController` 静态内部类，每次请求动态构造 |

---

## 关键模块

### 认证
- Argon2 密码哈希 + jjwt JWT 令牌，无 Spring Security session
- Token 存 Redis，`logout` 接口主动失效
- GitHub OAuth2 回调写 Cookie 后重定向前端

### 知识库 / RAG 管道
1. 上传文件 → OSS 存储，`document` 记录写 MySQL
2. 发 RocketMQ 消息触发异步索引
3. `DocumentService` 拉取文件 → 分块 → embedding → 写 Elasticsearch
4. 检索接口直接查 ES，返回 `DocumentChunk`

### 可观测性
- 业务应用通过 OTel OTLP → LoongCollector → Elasticsearch（`loongsuite_traces` 索引）
- Admin 侧从 ES 读取 Trace / Span 数据展示，不经过 Jaeger / Zipkin

### Agent / Workflow 执行
- Spring AI Alibaba `ChatClient` 驱动 Agent 对话
- Workflow 节点图序列化为 JSON 存 `application_version.config`
- 调试态走 `WorkflowDebugController`，生产态走 OpenAPI `/api/v1/apps/workflow/`

### Prompt 同步
- Nacos 作配置中心，`prompt_key` 为业务唯一键
- Prompt 发布后同步推送到 Nacos，外部 Agent 应用通过 `spring-ai-alibaba-agent-nacos` 订阅

### 代码生成器（Graph Studio）
- 继承 Spring Initializr，接收 `GraphProjectRequest`，生成 Spring AI Alibaba 工程骨架
- 路由前缀 `/graph-studio/api/`，下载入口 `/starter.zip`

---

## 关键约定

### ORM 混用
- `admin` 库实体用 **JPA** `@Table`，存放在 `server-core` 的 `domain` 包
- `agentscope` 库实体用 **MyBatis-Plus** `@TableName`，存放在 `server-runtime` 的 entity 包
- 同一个 Service 可能同时操作两个库，注意 DataSource 路由

### 业务 ID vs 自增主键
所有表均有自增 `id` 作物理主键，同时用 `xxx_id`（UUID/nanoid）或 `xxx_key` 作业务唯一标识。接口传参和关联外键一律用业务 ID，不暴露自增主键。

### 逻辑删除
大多数表用 `status = 0` 表示软删除，MyBatis-Plus 全局过滤。直接写 `DELETE` SQL 会破坏数据完整性。

### 统一返回结构
```
Result<T>       { code, message, data: T }
PageResult<T>   { total, list: T[] }
PagingList<T>   { total, list: T[] }   // agentscope 侧部分接口
```
流式接口返回 `Flux<T>` 或 `SseEmitter`，不包装 Result。

### 配置覆盖
生产 / 本地差异通过环境变量覆盖，参考 `application-dev.yml.example`。不要在代码里硬编码地址或密钥。

### GraalVM Polyglot
评估器自定义脚本（JS / Python）通过 GraalVM Polyglot 执行，沙箱隔离。修改脚本执行逻辑时需注意 context 线程安全。

---

## 怎么跑

### 前置条件
- Java 17+，Maven 3.8+
- Docker + Docker Compose（启动中间件）
- 至少一个 AI 模型 API Key（DashScope / OpenAI / DeepSeek）

### 本地启动

```bash
# 1. 启动中间件（MySQL × 2、Redis、Elasticsearch、RocketMQ、Nacos）
sh start.sh

# 2. 配置模型 API Key
# 编辑 spring-ai-alibaba-admin-server-start/model-config.yaml
# 模板见同目录 model-config-dashscope.yaml / model-config-openai.yaml

# 3. 启动应用
cd spring-ai-alibaba-admin-server-start
mvn spring-boot:run

# 4. 访问
# 控制台：http://localhost:8080
```

### 中间件默认地址（本地 Docker）

| 服务 | 地址 | 环境变量覆盖 |
|------|------|-------------|
| MySQL (admin) | localhost:3306/admin | `SPRING_DATASOURCE_URL` |
| MySQL (agentscope) | localhost:3306/agentscope | — |
| Redis | localhost:6379 | `SPRING_REDIS_PORT` |
| Elasticsearch | http://localhost:9200 | — |
| Nacos | localhost:8848 | `NACOS_SERVER_ADDR` |
| RocketMQ | localhost:18080 | — |
| OTel Collector | http://localhost:4318 | `MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT` |

### 详细参考文档

| 文档 | 内容 |
|------|------|
| [docs/api-list.md](docs/api-list.md) | 全量 REST 接口清单（22 模块，含入参/返回） |
| [docs/data-model.md](docs/data-model.md) | 核心数据模型（25 张表 + 3 个非 MySQL 实体） |
| [docs/data-model-er.svg](docs/data-model-er.svg) | ER 关系图 |
| [docs/login-flow.svg](docs/login-flow.svg) | 用户登录流程图 |
| [docs/methodology.svg](docs/methodology.svg) | 人机协作工作流（接手项目方法论） |

---

## 禁区

> 记录不能随意修改的代码区域、高风险操作、历史上曾出过问题的地方。

<!-- TODO：随项目演进在此补充 -->

---

## 历史包袱

> 记录设计债、临时方案、已知但暂不处理的问题。

<!-- TODO：随项目演进在此补充 -->
