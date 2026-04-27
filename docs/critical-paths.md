# 核心链路清单

> 原则：只列"改造时容易出问题"的链路。空列表胜过水货链路。
> 来源：docs/api-list.md、docs/data-model.md、CLAUDE.md

---

## 总览

| # | 链路名 | 起点接口 | 风险类型 |
|---|--------|----------|----------|
| 1 | 登录 → Token → Redis 失效 | `POST /console/v1/auth/login` | 双库路由 + Redis 耦合 |
| 2 | Prompt 创建 → 发布 → Nacos 同步 | `POST /api/prompts` | 跨系统写一致性 |
| 3 | Prompt 版本调试（SSE） | `POST /api/prompts/debug` | 流式 + Redis 会话 + AI 模型 |
| 4 | 文档上传 → RocketMQ → ES 向量写入 | `POST /api/kb/{kbId}/documents` | 异步管道全链路 |
| 5 | 实验执行（状态机） | `POST /api/experiments/{id}/run` | 状态机 + GraalVM 脚本 + 并发写 |
| 6 | Agent/Workflow 发布 → OpenAPI 对话 | `POST /console/v1/apps` | 跨库 + ChatClient + application_version 配置解析 |
| 7 | 知识库检索（RAG 召回） | `POST /api/kb/{kbId}/search` | ES 向量查询 + embedding 模型 |
| 8 | OAuth2 GitHub 登录 → Cookie → 前端重定向 | `GET /oauth2/authorization/github` | 外部 OAuth + Cookie 写入 + 前端 SPA 路由 |

---

## 详细说明

### 链路 1：登录 → Token → Redis 失效

**起点：** `POST /console/v1/auth/login`

**关键节点：**
1. `AccountService.login` 查 `agentscope.account`（MyBatis-Plus）
2. Argon2id 密码验证（CPU 密集，首次 ~5s）
3. jjwt 生成 `access_token` + `refresh_token`
4. `RedissonClient` 将 Token 写入 Redis（key = token，value = account_id，TTL）
5. `POST /console/v1/auth/logout` → Redis DEL，使 Token 失效

**终点：** `logout` 后用原 token 请求任意接口返回 401

**为什么容易出问题：**
- `agentscope.account` 和 `admin.*` 实体共用同一个 datasource，双库改造时极易切错路由
- Token 字段名为 `access_token`（snake_case），前端或测试脚本习惯用 `accessToken` 会静默拿到 null
- Redis 连接断开时 Token 写入失败会导致 login 接口 500，错误不明显

---

### 链路 2：Prompt 创建 → 发布 → Nacos 同步

**起点：** `POST /api/prompts`（创建）→ `POST /api/prompts/{key}/versions`（新建版本）→ `PUT /api/prompts/{key}/versions/{version}/release`（发布）

**关键节点：**
1. `PromptService.create` → `admin.prompt` 写入（JPA）
2. `PromptVersionService.create` → `admin.prompt_version` 写入，`status=pre`
3. `PromptVersionService.release` → `status` 改为 `release`，更新 `prompt.latest_version`（两步必须原子或有补偿）
4. `NacosConfigService.publishConfig` → 以 `prompt_key` 为 dataId 同步到 Nacos（网络调用，可失败）
5. 外部 Agent 应用通过 `spring-ai-alibaba-agent-nacos` 订阅收到推送

**终点：** Nacos 控制台 `prompt_key` 对应 dataId 内容与 `prompt_version.template` 一致

**为什么容易出问题：**
- `release` 操作需同时更新两张表（`prompt.latest_version` + `prompt_version.status`）且没有事务包裹两步时会出现半改状态
- Nacos 网络不可达时调用静默失败（非阻塞），本地数据库已更新但远端不同步，难排查
- Nacos 端口映射在 docker-compose.dev.yml 中是 7848→8848，应用配置若用 8848 会走 gRPC 而非 HTTP，`NacosConfigService` 会挂

---

### 链路 3：Prompt 版本调试（SSE 流式）

**起点：** `POST /api/prompts/debug`（创建 ChatSession）→ `POST /api/prompts/debug/{sessionId}/chat`（流式对话）

**关键节点：**
1. `ChatSessionService.create` → `RedissonClient` 写 ChatSession（JSON 序列化 Spring AI `Message` 列表）
2. `PromptDebugController.chat` → 变量填充 → 组装 `ChatClient`
3. `ChatClient` 调用 AI 模型（DashScope / OpenAI）→ 返回 `Flux<String>`
4. `SseEmitter` 逐 chunk 推送到客户端
5. 历史消息追加到 Redis ChatSession

**终点：** SSE 流正常结束（`event: complete` 或连接关闭），Redis 中 ChatSession 消息数 +1

**为什么容易出问题：**
- `SseEmitter` 超时配置与 AI 模型响应时间需匹配，模型慢时 SSE 会提前关闭
- Redis 中的 `Message` 对象序列化依赖 Spring AI 内部类型，升级 spring-ai-alibaba 版本后反序列化格式可能不兼容，导致旧会话报错
- 没有配置 AI 模型 API Key 时 `ChatClient` 抛出异常，SSE 连接直接断开，前端只收到空流，无明显错误提示

---

### 链路 4：文档上传 → RocketMQ → ES 向量写入

**起点：** `POST /api/kb/{kbId}/documents/upload`

**关键节点：**
1. 文件 → OSS（或本地文件系统）存储，`document.path` 写 MySQL
2. `document.index_status` = `1`（待处理）
3. `RocketMQTemplate.send` → Topic `topic_saa_studio_document_index`
4. `DocumentIndexConsumer` 消费消息 → 拉取文件 → 文本解析 → 分块
5. Embedding 模型调用 → 生成 `float[]` 向量
6. Spring AI `ElasticsearchVectorStore.add` → 写 ES `loongsuite_*` 索引（或自定义索引）
7. `document.index_status` 更新为 `3`（完成）或 `error` 字段写入失败原因

**终点：** `GET /api/kb/{kbId}/documents/{docId}` 返回 `index_status=3`，且 ES 中可检索到对应分块

**为什么容易出问题：**
- 全链路跨 5 个系统（MySQL → RocketMQ → Consumer → Embedding API → ES），任一环节失败都会导致 `index_status` 卡在 `2`，且没有自动重试
- ES 索引未初始化（`elasticsearch-init` 容器未成功运行）时向量写入静默失败
- Embedding 模型未配置 API Key 时 `float[]` 全零，写入成功但检索召回率为 0，表现为"功能正常"但实际不可用
- RocketMQ Proxy（18080）和 NameServer（9876）都必须健康，否则发送消息无报错但消息丢失

---

### 链路 5：实验执行（状态机）

**起点：** `POST /api/experiments/{id}/run`

**关键节点：**
1. `ExperimentService.run` → `experiment.status` 改为 `RUNNING`
2. 读取 `dataset_version.dataset_items` → 批量查 `dataset_item`
3. 读取 `evaluator_config` → 加载 `evaluator_version.prompt`
4. 对每条 `dataset_item`：调用被评估对象（Prompt / App）→ 获取 `actual_output`
5. 调用评估器：GraalVM Polyglot 执行自定义 JS/Python 脚本 或 LLM 评估
6. `experiment_result` 批量写入，`score` 聚合更新到 `experiment`
7. `experiment.status` → `COMPLETED` 或 `FAILED`，`progress` 推进到 100

**终点：** `GET /api/experiments/{id}` 返回 `status=COMPLETED`，`experiment_result` 数量 = 数据集版本的 `data_count`

**为什么容易出问题：**
- `status` 状态机有 5 个值，`RUNNING` → `COMPLETED`/`FAILED` 路径若有异常被吞掉，`status` 永久卡在 `RUNNING`，无超时兜底
- GraalVM Polyglot 脚本执行需要 context 线程安全，多条数据并发时共享 context 会报 IllegalStateException
- `experiment_result.score` 为 `DECIMAL(3,2)`，范围 0.00–1.00；评估脚本返回 >1 的值会触发 DB 截断，业务层无校验

---

### 链路 6：Agent/Workflow 发布 → OpenAPI 对话

**起点：** `POST /console/v1/apps`（创建）→ `PUT /console/v1/apps/{appId}/publish`（发布）→ `POST /api/v1/apps/chat` 或 `POST /api/v1/apps/workflow/`（对话）

**关键节点：**
1. `ApplicationService.create` → `agentscope.application` + `application_version` 写入，`status=1`（草稿）
2. `publish` → `application.status=2`，`application_version.config` 快照当前配置 JSON
3. OpenAPI `ChatController` 读 `application_version.config` → 解析节点图
4. `ChatClient` 按图结构编排 Agent / Tool 调用
5. `reference` 表查联引用的 KB（RAG）或 Plugin（Tool Use）
6. 对话结果流式返回

**终点：** `POST /api/v1/apps/chat` 携带有效 `api_key` 返回 HTTP 200，SSE 流有实质内容

**为什么容易出问题：**
- `application_version.config` 是大 JSON Blob，节点类型枚举（`agent`/`workflow`）变化时解析器向后不兼容
- `reference` 表用 `main_type` / `refer_type` 整型枚举关联，没有 FK，删除 KB 或 Plugin 后引用成悬空，对话时 NullPointerException
- OpenAPI 鉴权走 `api_key`（`api_key` 表），与 Console JWT 是两套独立鉴权，改造认证层时极易只改一套

---

### 链路 7：知识库 RAG 检索

**起点：** `POST /api/kb/{kbId}/search`（直接检索）或 Agent 对话时隐式触发

**关键节点：**
1. `KnowledgeBaseService.search` → 读 `knowledge_base.search_config`（topK、score_threshold 等）
2. 调用 Embedding 模型将查询文本转为向量
3. `ElasticsearchVectorStore.similaritySearch` → ES KNN 查询
4. 按 score_threshold 过滤，返回 `DocumentChunk` 列表
5. 组装到 Prompt context，传给 ChatClient

**终点：** 返回非空 chunk 列表，且 chunk 内容与查询语义相关

**为什么容易出问题：**
- ES 索引 mapping 与 Spring AI `VectorStore` 期望的字段（`embedding`、`content`、`metadata`）必须严格对齐，任一字段名变动导致 KNN 查询静默返回空集
- `search_config` 的 `score_threshold` 默认值过高时所有结果被过滤，表现与"文档未索引"完全相同，极难区分
- Embedding 模型与索引时使用的模型不一致（维度不匹配）会抛 ES 异常，且改换模型后已有向量必须全量重建索引

---

### 链路 8：OAuth2 GitHub 登录 → Cookie → 前端重定向

**起点：** 前端跳转 `GET /oauth2/authorization/github`

**关键节点：**
1. Spring Security OAuth2 Client 重定向到 GitHub 授权页
2. GitHub 回调 `GET /login/oauth2/code/github?code=...`
3. `OAuth2LoginController` 或 `DefaultOAuth2UserService` 用 code 换取 GitHub UserInfo
4. 查 `agentscope.account`（按 email）→ 不存在则自动注册
5. 生成 JWT Token，**写入 HTTP Cookie**（非返回 JSON body）
6. 302 重定向到前端 SPA 路由（`http://localhost:8000/...`）
7. 前端从 Cookie 读 Token，后续请求携带

**终点：** 前端 SPA 落地页正常渲染，`Authorization` 请求头携带有效 Token

**为什么容易出问题：**
- Cookie `Domain` / `SameSite` / `Secure` 属性在开发环境（前后端不同端口：8000/8080）时会被浏览器拦截，Token 无法传递
- 与用户名密码登录不同，OAuth2 成功后 Token 在 Cookie 而非 JSON Body，前端需要两套 Token 提取逻辑，遗漏任一就会 401
- GitHub 邮箱可能为 null（用户设置了"不公开邮箱"），自动注册时邮箱为空导致 `account` 唯一键冲突或字段 NOT NULL 报错

---

## 改造高危区速查

| 改造类型 | 高风险链路 |
|----------|-----------|
| 双 datasource 重构 | 链路 1、6（agentscope/admin 路由切换） |
| 升级 spring-ai-alibaba | 链路 3、7（Message 序列化、VectorStore 字段） |
| 替换 MQ（如改 RobustMQ） | 链路 4（Topic 配置、消费者组、消息格式） |
| 替换认证方案 | 链路 1、8（JWT + Redis + Cookie 三处同步改） |
| 替换向量数据库 | 链路 4、7（VectorStore 实现 + index mapping） |
| 扩展 Agent 节点类型 | 链路 6（config JSON 解析器向后兼容） |
