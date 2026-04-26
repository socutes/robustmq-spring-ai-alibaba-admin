# REST 接口清单

> 来源：扫描所有 Controller 源码自动整理，共 32 个 Controller。
> 统一返回结构：`Result<T>` `{ code, message, data: T }`，分页为 `PageResult<T>` / `PagingList<T>` `{ total, list }`。

---

## 目录

- [1. 认证 / 账号](#1-认证--账号)
- [2. Prompt 管理](#2-prompt-管理)
- [3. 数据集管理](#3-数据集管理)
- [4. 评估器管理](#4-评估器管理)
- [5. 实验管理](#5-实验管理)
- [6. 模型配置（Studio）](#6-模型配置studio)
- [7. 可观测性](#7-可观测性)
- [8. 应用管理](#8-应用管理)
- [9. 工作流调试](#9-工作流调试)
- [10. 知识库 / 文档 / 分块](#10-知识库--文档--分块)
- [11. 模型 / Provider 管理](#11-模型--provider-管理)
- [12. 工具 / 插件](#12-工具--插件)
- [13. MCP Server](#13-mcp-server)
- [14. Agent Schema](#14-agent-schema)
- [15. 文件上传](#15-文件上传)
- [16. API Key](#16-api-key)
- [17. 工作空间](#17-工作空间)
- [18. 组件服务](#18-组件服务)
- [19. Chat 对话（OpenAPI）](#19-chat-对话openapi)
- [20. OAuth2](#20-oauth2)
- [21. 系统](#21-系统)
- [22. 代码生成器（Graph Studio）](#22-代码生成器graph-studio)

---

## 1. 认证 / 账号

**Base path：** `/console/v1/auth`、`/console/v1/accounts`

### 1.1 认证

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/auth/login` | 用户名密码登录，返回 JWT Token |
| POST | `/console/v1/auth/refresh-token` | 刷新 Token |
| POST | `/console/v1/auth/logout` | 退出登录，使 Token 失效 |

**POST `/console/v1/auth/login`**
- 入参：`LoginRequest { username, password }`
- 返回：`Result<TokenResponse>` — `{ accessToken, refreshToken, expiresIn }`

**POST `/console/v1/auth/refresh-token`**
- 入参：`RefreshTokenRequest { refreshToken }`
- 返回：`Result<TokenResponse>`

**POST `/console/v1/auth/logout`**
- 入参：Header 携带 Token
- 返回：`Result<Void>`

---

### 1.2 账号管理

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/accounts` | 创建账号 |
| GET | `/console/v1/accounts` | 分页查询账号列表 |
| GET | `/console/v1/accounts/{accountId}` | 获取账号详情 |
| PUT | `/console/v1/accounts/{accountId}` | 更新账号信息 |
| DELETE | `/console/v1/accounts/{accountId}` | 删除账号 |
| PUT | `/console/v1/accounts/change-password` | 修改密码 |
| GET | `/console/v1/accounts/profile` | 获取当前登录用户信息 |

**POST `/console/v1/accounts`**
- 入参：`Account { username, email, role, ... }`
- 返回：`Result<String>` — 新建账号 ID

**GET `/console/v1/accounts`**
- 入参：`BaseQuery { page, size, keyword }` (query string)
- 返回：`Result<PagingList<Account>>`

**PUT `/console/v1/accounts/change-password`**
- 入参：`ChangePasswordRequest { oldPassword, newPassword }`
- 返回：`Result<String>`

---

## 2. Prompt 管理

**Base path：** `/api`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/prompt` | 创建 Prompt |
| GET | `/api/prompt` | 按 promptKey 获取 Prompt |
| GET | `/api/prompts` | 分页列表 |
| PUT | `/api/prompt` | 更新 Prompt |
| DELETE | `/api/prompt` | 删除 Prompt |
| POST | `/api/prompt/version` | 创建 Prompt 版本 |
| GET | `/api/prompt/version` | 获取指定版本详情 |
| GET | `/api/prompt/versions` | 版本分页列表 |
| GET | `/api/prompt/template` | 获取 Prompt 模板详情 |
| GET | `/api/prompt/templates` | 模板分页列表 |
| POST | `/api/prompt/run` | 执行 Prompt（流式） |
| GET | `/api/prompt/session` | 获取对话 Session |
| DELETE | `/api/prompt/session` | 删除对话 Session |

**POST `/api/prompt`**
- 入参：`PromptCreateRequest { promptKey, name, description, content, ... }`
- 返回：`Result<Prompt>`

**GET `/api/prompt`**
- 入参：`?promptKey=xxx`
- 返回：`Result<Prompt>`

**GET `/api/prompts`**
- 入参：`PromptListRequest { page, size, keyword }` (query string)
- 返回：`Result<PageResult<Prompt>>`

**POST `/api/prompt/version`**
- 入参：`PromptVersionCreateRequest { promptKey, content, remark, ... }`
- 返回：`Result<PromptVersion>`

**GET `/api/prompt/version`**
- 入参：`?promptKey=xxx&version=xxx`
- 返回：`Result<PromptVersionDetail>`

**POST `/api/prompt/run`**
- 入参：`PromptRunRequest { promptKey, version, variables, sessionId, stream }`
- 返回：`Flux<PromptRunResponse>` — SSE 流式响应

**GET `/api/prompt/session`**
- 入参：`?sessionId=xxx`
- 返回：`Result<ChatSession>`

---

## 3. 数据集管理

**Base path：** `/api/dataset`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/dataset/dataset` | 创建数据集 |
| GET | `/api/dataset/datasets` | 数据集分页列表 |
| GET | `/api/dataset/dataset` | 获取数据集详情 |
| PUT | `/api/dataset/dataset` | 更新数据集 |
| DELETE | `/api/dataset/dataset` | 删除数据集 |
| POST | `/api/dataset/datasetVersion` | 创建数据集版本 |
| GET | `/api/dataset/datasetVersions` | 版本分页列表 |
| PUT | `/api/dataset/datasetVersion` | 更新版本信息 |
| POST | `/api/dataset/dataItem` | 创建数据项 |
| GET | `/api/dataset/dataItems` | 数据项分页列表 |
| GET | `/api/dataset/dataItem` | 获取单条数据项 |
| PUT | `/api/dataset/dataItem` | 更新数据项 |
| DELETE | `/api/dataset/dataItem` | 删除数据项 |
| GET | `/api/dataset/experiments` | 关联实验列表 |
| POST | `/api/dataset/dataItemFromTrace` | 从链路追踪创建数据项 |

**POST `/api/dataset/dataset`**
- 入参：`DatasetCreateRequest { name, description, ... }`
- 返回：`Result<Dataset>`

**GET `/api/dataset/datasets`**
- 入参：`DatasetListRequest { page, size, keyword }` (query string)
- 返回：`Result<PageResult<Dataset>>`

**GET `/api/dataset/dataset`**
- 入参：`?datasetId=123`
- 返回：`Result<Dataset>`

**POST `/api/dataset/dataItem`**
- 入参：`DatasetItemCreateRequest { datasetId, items: [{ input, expectedOutput, ... }] }`
- 返回：`Result<List<DatasetItem>>`

**POST `/api/dataset/dataItemFromTrace`**
- 入参：`DataItemCreateFromTraceRequest { traceId, datasetId, ... }`
- 返回：`Result<List<DatasetItem>>`

---

## 4. 评估器管理

**Base path：** `/api/evaluator`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/evaluator/evaluator` | 创建评估器 |
| GET | `/api/evaluator/evaluators` | 评估器分页列表 |
| GET | `/api/evaluator/evaluator` | 获取评估器详情 |
| PUT | `/api/evaluator/evaluator` | 更新评估器 |
| DELETE | `/api/evaluator/evaluator` | 删除评估器 |
| POST | `/api/evaluator/evaluatorVersion` | 创建评估器版本 |
| GET | `/api/evaluator/evaluatorVersions` | 版本分页列表 |
| POST | `/api/evaluator/debug` | 调试评估器 |
| GET | `/api/evaluator/templates` | 评估器模板列表 |
| GET | `/api/evaluator/template` | 获取模板详情 |
| GET | `/api/evaluator/experiments` | 关联实验列表 |

**POST `/api/evaluator/evaluator`**
- 入参：`EvaluatorCreateRequest { name, type, config, templateId, ... }`
- 返回：`Result<Evaluator>`

**POST `/api/evaluator/debug`**
- 入参：`EvaluatorTestRequest { evaluatorId, input, expectedOutput }`
- 返回：`Result<EvaluatorDebugResult>` — `{ score, passed, detail }`

**GET `/api/evaluator/templates`**
- 入参：`EvaluatorTemplateListRequest { page, size }` (query string)
- 返回：`Result<PageResult<EvaluatorTemplate>>`

---

## 5. 实验管理

**Base path：** `/api`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/experiment` | 创建实验 |
| GET | `/api/experiments` | 实验分页列表 |
| GET | `/api/experiment` | 获取实验详情 |
| GET | `/api/experiment/results` | 获取实验整体评估结果 |
| GET | `/api/experiment/result` | 获取单个评估结果明细（分页） |
| PUT | `/api/experiment/stop` | 停止实验 |
| PUT | `/api/experiment/restart` | 重启实验 |
| DELETE | `/api/experiment` | 删除实验 |

**POST `/api/experiment`**
- 入参：`ExperimentCreateRequest { name, datasetId, evaluatorIds[], promptKey, promptVersion, ... }`
- 返回：`Result<Experiment>`

**GET `/api/experiment/results`**
- 入参：`?experimentId=123`
- 返回：`Result<List<ExperimentEvaluatorResult>>` — 每个评估器的汇总分

**GET `/api/experiment/result`**
- 入参：`ExperimentEvaluatorResultDetailListRequest { experimentId, evaluatorId, page, size }`
- 返回：`Result<PageResult<ExperimentEvaluatorResultDetail>>`

---

## 6. 模型配置（Studio）

**Base path：** `/api`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/model/supported` | 查询支持的模型提供商列表 |
| GET | `/api/models` | 模型配置分页列表 |
| GET | `/api/model` | 按 ID 获取单条模型配置 |
| GET | `/api/models/enabled` | 获取所有已启用的模型配置 |

**GET `/api/model/supported`**
- 入参：无
- 返回：`Result<List<String>>` — 提供商名称列表，如 `["openai","dashscope","deepseek"]`

**GET `/api/models`**
- 入参：`ModelConfigQueryRequest { page, size, provider }` (query string)
- 返回：`Result<PageResult<ModelConfigResponse>>`

**GET `/api/models/enabled`**
- 入参：无
- 返回：`Result<List<ModelConfigResponse>>`

---

## 7. 可观测性

**Base path：** `/api/observability`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/observability/traces` | 链路列表（分页） |
| GET | `/api/observability/traces/{traceId}` | 获取 Trace 详情及 Span 树 |
| GET | `/api/observability/services` | 服务列表及统计 |
| GET | `/api/observability/overview` | 全局概览统计 |

**GET `/api/observability/traces`**
- 入参：`TracesQueryRequest { page, size, serviceName, startTime, endTime, status }` (query string)
- 返回：`Result<PageResult<TraceSpanDTO>>`

**GET `/api/observability/traces/{traceId}`**
- 入参：`traceId` (path)
- 返回：`Result<TraceDetailDTO>` — 含完整 Span 树

**GET `/api/observability/services`**
- 入参：`ServicesQueryRequest { startTime, endTime }` (query string)
- 返回：`Result<ServicesResponseDTO>` — `{ services: [{ name, requestCount, errorRate, avgDuration }] }`

**GET `/api/observability/overview`**
- 入参：`OverviewQueryRequest { startTime, endTime }` (query string)
- 返回：`Result<OverviewStatsDTO>` — `{ totalTraces, errorCount, avgDuration, ... }`

---

## 8. 应用管理

**Base path：** `/console/v1/apps`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/apps` | 创建应用 |
| GET | `/console/v1/apps` | 应用分页列表 |
| GET | `/console/v1/apps/{appId}` | 获取应用详情 |
| PUT | `/console/v1/apps/{appId}` | 更新应用 |
| DELETE | `/console/v1/apps/{appId}` | 删除应用 |
| POST | `/console/v1/apps/{appId}/publish` | 发布应用 |
| POST | `/console/v1/apps/{appId}/copy` | 复制应用 |
| GET | `/console/v1/apps/{appId}/versions` | 应用版本列表 |
| GET | `/console/v1/apps/{appId}/versions/{version}` | 获取指定版本详情 |
| POST | `/console/v1/apps/chat/completions` | 应用对话（内部调试用） |

**POST `/console/v1/apps`**
- 入参：`Application { name, type, description, config, ... }`
- 返回：`Result<String>` — 新建 appId

**POST `/console/v1/apps/{appId}/publish`**
- 入参：`appId` (path)
- 返回：`Result<Void>`

**POST `/console/v1/apps/chat/completions`**
- 入参：`AgentRequest { appId, messages[], stream, ... }`，`HttpServletResponse`
- 返回：SSE 流 / JSON（取决于 stream 参数）

---

## 9. 工作流调试

**Base path：** `/console/v1/apps`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/apps/workflow/debug/init` | 初始化工作流调试，返回入参定义 |
| POST | `/console/v1/apps/workflow/debug/run-task` | 执行调试任务 |
| POST | `/console/v1/apps/workflow/debug/get-task-process` | 查询任务执行进度 |
| POST | `/console/v1/apps/workflow/debug/resume-task` | 恢复暂停的任务 |
| POST | `/console/v1/apps/workflow/debug/part-graph/run-task` | 执行子图任务 |
| POST | `/console/v1/apps/workflow/debug/part-graph/stop-task` | 停止子图任务 |
| POST | `/console/v1/apps/workflow/{appId}/run_stream` | 正式运行工作流（SSE 流） |

**POST `/console/v1/apps/workflow/debug/init`**
- 入参：`InitRequest { appId, version }`
- 返回：`Result<List<TaskRunParam>>` — 入参字段定义列表

**POST `/console/v1/apps/workflow/debug/run-task`**
- 入参：`TaskRunRequest { appId, inputs, nodeId }`
- 返回：`Result<TaskRunResponse>` — `{ taskId, status }`

**POST `/console/v1/apps/workflow/{appId}/run_stream`**
- 入参：`appId` (path)，`ApiTaskRunRequest { inputs, ... }`
- 返回：`SseEmitter` — 实时事件流

---

## 10. 知识库 / 文档 / 分块

**Base path：** `/console/v1/knowledge-bases`、`/console/v1/documents`

### 知识库

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/knowledge-bases` | 创建知识库 |
| GET | `/console/v1/knowledge-bases` | 知识库分页列表 |
| GET | `/console/v1/knowledge-bases/{kbId}` | 获取知识库详情 |
| PUT | `/console/v1/knowledge-bases/{kbId}` | 更新知识库 |
| DELETE | `/console/v1/knowledge-bases/{kbId}` | 删除知识库 |
| POST | `/console/v1/knowledge-bases/query-by-codes` | 按 code 批量查询 |
| POST | `/console/v1/knowledge-bases/retrieve` | 向量检索（RAG 召回） |

**POST `/console/v1/knowledge-bases/retrieve`**
- 入参：`DocumentRetrieverQuery { kbCode, query, topK, minScore }`
- 返回：`Result<List<DocumentChunk>>`

### 文档

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/knowledge-bases/{kbId}/documents` | 批量创建文档 |
| GET | `/console/v1/knowledge-bases/{kbId}/documents` | 文档分页列表 |
| GET | `/console/v1/knowledge-bases/{kbId}/documents/{docId}` | 获取文档详情 |
| PUT | `/console/v1/knowledge-bases/{kbId}/documents/{docId}` | 更新文档 |
| DELETE | `/console/v1/knowledge-bases/{kbId}/documents/{docId}` | 删除文档 |
| DELETE | `/console/v1/knowledge-bases/{kbId}/documents/batch-delete` | 批量删除文档 |
| PUT | `/console/v1/knowledge-bases/{kbId}/documents/{docId}/re-index` | 重新索引文档 |

**POST `/console/v1/knowledge-bases/{kbId}/documents`**
- 入参：`CreateDocumentRequest { filePaths[], parseConfig, indexConfig }`
- 返回：`Result<List<String>>` — 文档 ID 列表

### 文档分块

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/documents/{docId}/chunks` | 创建分块 |
| GET | `/console/v1/documents/{docId}/chunks` | 分块分页列表 |
| PUT | `/console/v1/documents/{docId}/chunks/{chunkId}` | 更新分块 |
| DELETE | `/console/v1/documents/{docId}/chunks/{chunkId}` | 删除分块 |
| DELETE | `/console/v1/documents/{docId}/chunks/batch-delete` | 批量删除分块 |
| POST | `/console/v1/documents/{docId}/chunks/preview` | 预览分块效果（不入库） |
| PUT | `/console/v1/documents/{docId}/chunks/update-status` | 批量更新分块状态 |

---

## 11. 模型 / Provider 管理

**Base path：** `/console/v1/models`、`/console/v1/providers`

### 模型选择器

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/console/v1/models/{modelType}/selector` | 按类型获取可用模型分组列表 |
| GET | `/console/v1/models/enabled` | 获取已启用模型列表 |

**GET `/console/v1/models/{modelType}/selector`**
- 入参：`modelType` (path) — 如 `chat`、`embedding`
- 返回：`Result<List<ModelProviderGroup>>`

### Provider 配置

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/providers` | 添加 Provider |
| GET | `/console/v1/providers` | Provider 列表 |
| GET | `/console/v1/providers/{provider}` | 获取 Provider 详情 |
| PUT | `/console/v1/providers/{provider}` | 更新 Provider |
| DELETE | `/console/v1/providers/{provider}` | 删除 Provider |
| GET | `/console/v1/providers/protocols` | 查询支持的协议列表 |
| POST | `/console/v1/providers/{provider}/models` | 为 Provider 添加模型 |
| GET | `/console/v1/providers/{provider}/models` | 查询 Provider 下的模型 |
| GET | `/console/v1/providers/{provider}/models/{modelId}` | 获取模型详情 |
| PUT | `/console/v1/providers/{provider}/models/{modelId}` | 更新模型配置 |
| DELETE | `/console/v1/providers/{provider}/models/{modelId}` | 删除模型 |
| GET | `/console/v1/providers/{provider}/models/{modelId}/parameter_rules` | 获取模型参数规则 |

---

## 12. 工具 / 插件

**Base path：** `/console/v1/tools`、`/console/v1`（plugins）

### 工具（内置）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/tools` | 创建工具 |
| GET | `/console/v1/tools` | 全量工具列表 |
| GET | `/console/v1/tools/page` | 工具分页列表 |
| GET | `/console/v1/tools/{id}` | 获取工具详情 |
| PUT | `/console/v1/tools/{id}` | 更新工具 |
| DELETE | `/console/v1/tools/{id}` | 删除工具 |
| GET | `/console/v1/tools/search` | 按名称搜索工具 |
| GET | `/console/v1/tools/plugin/{pluginId}` | 按插件 ID 查询工具 |
| PATCH | `/console/v1/tools/{id}/enabled` | 启用 / 禁用工具 |

**PATCH `/console/v1/tools/{id}/enabled`**
- 入参：`id` (path)，`?enabled=true/false`
- 返回：`Result<Void>`

### 插件

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/plugins` | 创建插件 |
| GET | `/console/v1/plugins` | 插件分页列表 |
| GET | `/console/v1/plugins/{pluginId}` | 获取插件详情 |
| PUT | `/console/v1/plugins/{pluginId}` | 更新插件 |
| DELETE | `/console/v1/plugins/{pluginId}` | 删除插件 |
| POST | `/console/v1/plugins/{pluginId}/tools` | 为插件添加工具 |
| GET | `/console/v1/plugins/{pluginId}/tools` | 插件工具列表 |
| GET | `/console/v1/plugins/{pluginId}/tools/{toolId}` | 获取插件工具详情 |
| PUT | `/console/v1/plugins/{pluginId}/tools/{toolId}` | 更新插件工具 |
| DELETE | `/console/v1/plugins/{pluginId}/tools/{toolId}` | 删除插件工具 |
| POST | `/console/v1/plugins/{pluginId}/tools/{toolId}/test` | 测试插件工具 |
| POST | `/console/v1/plugins/{pluginId}/tools/{toolId}/publish` | 发布插件工具 |
| POST | `/console/v1/tools/{toolId}/enable` | 启用工具 |
| POST | `/console/v1/tools/{toolId}/disable` | 禁用工具 |
| POST | `/console/v1/tools/query-by-ids` | 按 ID 批量查询工具 |

---

## 13. MCP Server

**Base path：** `/console/v1/mcp-servers`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/mcp-servers` | 注册 MCP Server |
| PUT | `/console/v1/mcp-servers` | 更新 MCP Server |
| GET | `/console/v1/mcp-servers` | MCP Server 分页列表 |
| GET | `/console/v1/mcp-servers/{serverCode}` | 获取 MCP Server 详情（含工具列表） |
| DELETE | `/console/v1/mcp-servers/{serverCode}` | 删除 MCP Server |
| POST | `/console/v1/mcp-servers/query-by-codes` | 按 code 批量查询 |
| POST | `/console/v1/mcp-servers/debug-tools` | 调试 MCP 工具调用 |

**POST `/console/v1/mcp-servers`**
- 入参：`McpServerDetail { code, name, url, transport, tools[], ... }`
- 返回：`Result<String>` — serverCode

**POST `/console/v1/mcp-servers/debug-tools`**
- 入参：`McpServerCallToolRequest { serverCode, toolName, arguments }`
- 返回：`Result<McpServerCallToolResponse>` — `{ result, error }`

---

## 14. Agent Schema

**Base path：** `/console/v1/agent-schemas`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/agent-schemas` | 创建 Agent Schema |
| GET | `/console/v1/agent-schemas` | 全量列表 |
| GET | `/console/v1/agent-schemas/page` | 分页列表 |
| GET | `/console/v1/agent-schemas/{id}` | 获取详情 |
| PUT | `/console/v1/agent-schemas/{id}` | 更新 |
| DELETE | `/console/v1/agent-schemas/{id}` | 删除 |
| GET | `/console/v1/agent-schemas/search` | 按名称搜索 |
| PATCH | `/console/v1/agent-schemas/{id}/enabled` | 启用 / 禁用 |

---

## 15. 文件上传

**Base path：** `/console/v1/files`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/files/upload` | 上传文件（服务端转存） |
| GET | `/console/v1/files/download` | 下载 / 预览文件 |
| POST | `/console/v1/files/upload-policies` | 获取前端直传 OSS 策略 |
| GET | `/console/v1/files/get-preview-url` | 获取文件预览链接 |

**POST `/console/v1/files/upload`**
- 入参：`multipart/form-data`，`files[]`（多文件），`category`（分类）
- 返回：`Result<List<UploadPolicy>>` — `{ url, key, ... }`

**POST `/console/v1/files/upload-policies`**
- 入参：`WebUploadRequest { fileNames[], category }`
- 返回：`Result<List<WebUploadPolicy>>` — 前端直传 OSS 所需签名信息

**GET `/console/v1/files/download`**
- 入参：`?filePath=xxx&preview=true/false`
- 返回：文件字节流（`void`，直接写入 response）

---

## 16. API Key

**Base path：** `/console/v1/api-keys`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/api-keys` | 创建 API Key |
| GET | `/console/v1/api-keys` | 分页列表 |
| GET | `/console/v1/api-keys/{id}` | 获取详情 |
| PUT | `/console/v1/api-keys/{id}` | 更新 |
| DELETE | `/console/v1/api-keys/{id}` | 删除 |

**POST `/console/v1/api-keys`**
- 入参：`ApiKey { name, expireAt, ... }`
- 返回：`Result<String>` — 生成的 key 值（仅此次可见）

---

## 17. 工作空间

**Base path：** `/console/v1/workspaces`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/console/v1/workspaces` | 创建工作空间 |
| GET | `/console/v1/workspaces` | 分页列表 |
| GET | `/console/v1/workspaces/{workspaceId}` | 获取详情 |
| PUT | `/console/v1/workspaces/{workspaceId}` | 更新 |
| DELETE | `/console/v1/workspaces/{workspaceId}` | 删除 |

---

## 18. 组件服务

**Base path：** `/console/v1/component-servers`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/console/v1/component-servers` | 组件分页列表 |
| GET | `/console/v1/component-servers/app-publishable` | 可发布应用分页列表 |
| POST | `/console/v1/component-servers` | 发布应用为组件 |
| PUT | `/console/v1/component-servers/{code}` | 更新组件 |
| DELETE | `/console/v1/component-servers/{code}` | 删除组件 |
| GET | `/console/v1/component-servers/{code}/detail-by-code` | 按 code 获取组件详情 |
| GET | `/console/v1/component-servers/{appId}/detail-by-appid` | 按 appId 获取组件详情 |
| GET | `/console/v1/component-servers/{code}/query-refer` | 查询引用关系 |
| GET | `/console/v1/component-servers/{appId}/query-config` | 查询组件配置 |
| POST | `/console/v1/component-servers/query-by-codes` | 按 code 批量查询 |
| GET | `/console/v1/component-servers/{code}/query-schema` | 获取组件 Schema |
| POST | `/console/v1/component-servers/schema-by-codes` | 按 code 批量获取 Schema |

---

## 19. Chat 对话（OpenAPI）

**Base path：** `/api/v1/apps`

> 供外部 Agent 应用调用的标准对话接口。

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/apps/chat/completions` | Agent 对话（流式 / 非流式） |
| POST | `/api/v1/apps/workflow/completions` | 工作流同步执行 |
| POST | `/api/v1/apps/workflow/async-completions` | 工作流异步执行 |
| POST | `/api/v1/apps/workflow/stop-completions` | 停止异步任务 |
| POST | `/api/v1/apps/workflow/async-results` | 查询异步执行结果 |

**POST `/api/v1/apps/chat/completions`**
- 入参：`AgentRequest { appId, messages[], stream, model, ... }`，`HttpServletResponse`
- 返回：SSE 流（`stream=true`）或 JSON

**POST `/api/v1/apps/workflow/async-completions`**
- 入参：`WorkflowRequest { appId, inputs, ... }`
- 返回：`Result<TaskRunResponse>` — `{ taskId }`

**POST `/api/v1/apps/workflow/async-results`**
- 入参：`AsyncResultRequest { taskId }`
- 返回：`Result<AsyncResultResponse>` — `{ status, outputs, error }`

---

## 20. OAuth2

**Base path：** `/oauth2`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/oauth2/login/github` | 获取 GitHub OAuth 授权跳转 URL |
| GET | `/oauth2/callback/github` | GitHub OAuth 回调，完成登录 |

**GET `/oauth2/callback/github`**
- 入参：`?code=xxx`（GitHub 回调 code）
- 返回：重定向（写入 Cookie / 跳转前端）

---

## 21. 系统

**Base path：** `/console/v1/system`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/console/v1/system/global-config` | 获取系统全局配置 |
| GET | `/console/v1/system/health` | 健康检查 |

**GET `/console/v1/system/global-config`**
- 入参：无
- 返回：`Result<GlobalConfig>` — 前端所需全局配置项

**GET `/console/v1/system/health`**
- 入参：无
- 返回：`"ok"`（纯字符串）

---

## 22. 代码生成器（Graph Studio）

**Base path：** `/graph-studio/api`

| 方法 | 路径 | 说明 |
|------|------|------|
| — | `/graph-studio/api/app/**` | Graph 应用管理（实现 AppAPI 接口） |
| — | `/graph-studio/api/dsl/**` | DSL 导入导出（实现 DSLAPI 接口） |
| — | `/graph-studio/api/run/**` | 运行 Graph（实现 RunnerAPI 接口） |
| POST | `/starter.zip` 等 | 代码工程下载（继承 Spring Initializr） |

> 此模块基于 Spring Initializr 框架扩展，具体路由由框架约定，接收 `GraphProjectRequest` 生成 Spring AI Alibaba 工程骨架。
