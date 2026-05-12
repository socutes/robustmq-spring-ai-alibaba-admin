# CLAUDE.md

> 给 Claude Code 的项目上下文。阅读完本文即可开始工作，细节见 `docs/` 链接。

---

## 项目定位

**Spring AI Alibaba Admin** 是一个 AI Agent 全生命周期管理平台，分两个子平台：

- **Builder 平台**（`/console/v1/*`）：Agent / Workflow 应用编排、知识库 RAG、插件工具、模型提供商管理。
- **Evaluation 平台**（`/api/*`）：Prompt 工程、数据集版本管理、评估器配置、批量实验执行、可观测性（OTel Trace）。

对外通过 `/api/v1/apps/*` 暴露 OpenAI 兼容 API，供外部应用直接调用已发布的 Agent/Workflow。

---

## 核心架构

详见 [docs/architecture.svg](docs/architecture.svg) | [docs/module-deps.svg](docs/module-deps.svg) | [docs/external-deps.svg](docs/external-deps.svg)

### 四层结构

```
前端（React + UmiJS monorepo）
  └─ packages/main          Builder 管理台 SPA
  └─ packages/spark-flow    Workflow 画布（可视化编排）
  └─ packages/spark-i18n    国际化包

后端（Spring Boot 3.3 / Java 17，4 个 Maven 模块）
  server-runtime   共享 DTO / VO / 枚举，无内部依赖（叶节点）
  server-core      业务核心：Agent 引擎、ORM Mapper、Redis/OSS/模型管理
  server-openapi   OpenAI 兼容端点 + ApiKey 鉴权拦截器
  server-start     启动类、全局异常、JWT 鉴权、Controller 层
  （依赖方向：start → openapi → core → runtime）

中间件
  MySQL 8.0      两个 schema：admin（Builder）/ agentscope（Evaluation）
  Redis 7        Redisson 分布式锁 + 会话缓存
  Elasticsearch  向量检索（RAG chunks）+ OTel Trace 存储（index: loongsuite_traces）
  RocketMQ 5     异步任务：文档索引、实验批量执行
  Nacos 2        Prompt 配置中心热加载

外部服务
  AI 模型：DashScope / OpenAI / DeepSeek（Spring AI Alibaba v1.0.0.3 统一适配）
  OSS：本地文件系统 or 阿里云 OSS（文件上传/预览）
  LoongCollector：OTel Collector（OTLP HTTP :4318 → ES）
```

---

## 关键模块

| 模块 | 主要职责 |
|------|---------|
| `server-start` | Spring Boot 入口，Controller 层，JWT 过滤器，全局异常处理 |
| `server-core` | Agent 执行引擎（JGraphT DAG），MyBatis-Plus Mapper，Redisson，OSS 管理 |
| `server-openapi` | OpenAI 兼容 Chat/Workflow API，ApiKey 鉴权拦截器 |
| `server-runtime` | 跨模块共享的 DTO/VO/枚举/分页封装，**不可引入业务逻辑** |

Controller 分布：全部在 `server-start`，约 30 个，~150 个端点。  
完整接口清单：[docs/api-list.md](docs/api-list.md)

---

## 数据模型

详见 [docs/data-model.md](docs/data-model.md) | [docs/data-model-er.svg](docs/data-model-er.svg)

- **admin schema**（15 张表）：account、workspace、application、application_version、application_component、reference、knowledge_base、document、plugin、tool、provider、model、mcp_server、agent_schema、api_key
- **agentscope schema**（12 张表）：prompt、prompt_version、prompt_build_template、model_config、dataset、dataset_version、dataset_item、evaluator、evaluator_version、evaluator_template、experiment、experiment_result
- Document chunks **不在 MySQL**，存 Elasticsearch（index: `loongsuite_traces`）
- 所有实体用业务主键（`VARCHAR(64)` UUID）对外，物理主键（`BIGINT AUTO_INCREMENT`）仅内部使用

---

## 关键约定

### API 规范
- 统一返回结构：`Result<T>` — `{ requestId, code, message, data }`
- 分页结构：`PagingList<T>` — `{ total, pageNum, pageSize, list }`
- 流式接口返回 `text/event-stream`（SSE），末帧 `status=COMPLETED`
- Evaluation 平台接口（`/api/*`）用 `PageResult<T>` 替代 `PagingList<T>`

### 鉴权
- Builder 平台：JWT（JJWT v0.12.6），Header `Authorization: Bearer <token>`
- OpenAPI 外部调用：ApiKey，Header `Authorization: Bearer <apiKey>`（`ApiKeyAuthInterceptor`）

### ORM
- Builder 平台（admin schema）：MyBatis-Plus，XML Mapper 在 `classpath:mapper/*.xml`，驼峰映射开启
- Evaluation 平台（agentscope schema）：Spring Data JPA + Hibernate，`ddl-auto=none`
- 两套 ORM 并存，**不要混用**

### 配置覆盖
所有中间件连接配置均支持环境变量覆盖，本地开发默认值见 `application.yml`：

| 中间件 | 环境变量前缀 | 默认值 |
|--------|------------|--------|
| MySQL | `SPRING_DATASOURCE_*` | `localhost:3306/admin` user=admin |
| Redis | `SPRING_REDIS_*` | `localhost:6379` db=0 |
| Elasticsearch | `SPRING_ELASTICSEARCH_URIS` | `http://localhost:9200` |
| RocketMQ | `ROCKETMQ_ENDPOINTS` | `localhost:18080` |
| Nacos | `NACOS_SERVER_ADDR` | `localhost:8848` |
| OTLP | `MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT` | `http://localhost:4318/v1/traces` |

### 模型配置
- AI 模型凭证在 `server-start/model-config.yaml`（gitignore，不提交），模板见 `model-config-dashscope.yaml` 等
- 运行时可通过 Provider API 动态添加模型；凭证经 RSA 加密存库

---

## 怎么跑

### 快速启动（推荐）

```bash
# 1. 启动所有中间件（MySQL / Redis / ES / RocketMQ / Nacos / LoongCollector）
docker compose -f docker-compose.dev.yml up -d

# 等待健康检查通过（约 60–90s），可用以下命令确认：
docker compose -f docker-compose.dev.yml ps

# 2. 配置模型 API Key（首次）
cp spring-ai-alibaba-admin-server-start/model-config-dashscope.yaml \
   spring-ai-alibaba-admin-server-start/model-config.yaml
# 编辑 model-config.yaml，填入 API Key

# 3. 启动后端
cd spring-ai-alibaba-admin-server-start
mvn spring-boot:run

# 4. 访问
# 管理台：http://localhost:8080/admin
# Nacos：http://localhost:7848/nacos  (user=nacos pass=nacos)
# Kibana：http://localhost:5601
```

### 中间件端口速查

| 服务 | 宿主机端口 |
|------|-----------|
| MySQL | 3306 |
| Redis | 6379 |
| Elasticsearch | 9200 |
| RocketMQ Proxy (gRPC) | 18080 |
| Nacos HTTP | 7848 |
| LoongCollector OTLP | 4318 |
| Kibana | 5601 |

> Nacos 宿主机 7848 映射容器 8848；应用配置 `NACOS_SERVER_ADDR=localhost:7848`。

### 前端开发

```bash
cd packages/main
npm install
npm run dev   # 默认代理到 localhost:8080
```

### 停止 / 清数据

```bash
docker compose -f docker-compose.dev.yml down        # 停止，保留数据卷
docker compose -f docker-compose.dev.yml down -v     # 停止并清除所有数据
```

---

## 禁区

> _待补充：记录不能改动的区域、不能删除的配置、线上有依赖的接口等。_

---

## 历史包袱

> _待补充：遗留的设计决策、已知 workaround、技术债务说明等。_
