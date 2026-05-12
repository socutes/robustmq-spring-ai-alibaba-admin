# REST 接口清单

> 来源：扫描全部 32 个 Controller 源文件  
> 统一返回结构：`Result<T>` — `{ requestId, code, message, data: T }`  
> 分页结构：`PagingList<T>` — `{ total, pageNum, pageSize, list: T[] }`  
> 公共前缀：`/console/v1`（管理台）、`/api`（评估平台）、`/api/v1/apps`（OpenAPI 外部调用）

---

## 目录

1. [认证鉴权](#1-认证鉴权)
2. [账号管理](#2-账号管理)
3. [工作空间](#3-工作空间)
4. [应用管理](#4-应用管理)
5. [应用对话（调试）](#5-应用对话调试)
6. [Workflow 编排与调试](#6-workflow-编排与调试)
7. [应用组件](#7-应用组件)
8. [知识库](#8-知识库)
9. [文档管理](#9-文档管理)
10. [文档 Chunk](#10-文档-chunk)
11. [文件上传下载](#11-文件上传下载)
12. [模型提供商](#12-模型提供商)
13. [模型选择](#13-模型选择)
14. [插件管理](#14-插件管理)
15. [工具管理（ToolController）](#15-工具管理-toolcontroller)
16. [MCP Server](#16-mcp-server)
17. [Agent Schema](#17-agent-schema)
18. [API Key 管理](#18-api-key-管理)
19. [Prompt 管理](#19-prompt-管理)
20. [数据集管理](#20-数据集管理)
21. [评估器管理](#21-评估器管理)
22. [实验管理](#22-实验管理)
23. [可观测性（Trace）](#23-可观测性trace)
24. [模型配置（评估平台）](#24-模型配置评估平台)
25. [仪表板](#25-仪表板)
26. [系统配置](#26-系统配置)
27. [OpenAPI 外部调用](#27-openapi-外部调用)
28. [Graph Studio 代码生成](#28-graph-studio-代码生成)
29. [OAuth2 登录](#29-oauth2-登录)
30. [测试示例接口](#30-测试示例接口)

---

## 1 认证鉴权

**Controller**：`AuthController`  **前缀**：`/console/v1/auth`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/login` | 用户名密码登录，返回 access/refresh token | `{ username, password }` | `Result<TokenResponse>` — `{ accessToken, refreshToken, expiresIn }` |
| POST | `/refresh-token` | 用 refresh token 换新 access token | `{ refreshToken }` | `Result<TokenResponse>` |
| POST | `/logout` | 使当前 access token 失效 | Header: `Authorization: Bearer <token>` | `Result<Void>` |

---

## 2 账号管理

**Controller**：`AccountController`  **前缀**：`/console/v1/accounts`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/` | 创建账号 | `{ username, password, ... }` | `Result<String>` — accountId |
| PUT | `/{accountId}` | 更新账号信息 | path: `accountId`；body: `Account` | `Result<String>` |
| DELETE | `/{accountId}` | 删除账号 | path: `accountId` | `Result<Void>` |
| GET | `/{accountId}` | 查询账号详情 | path: `accountId` | `Result<Account>` |
| GET | `/` | 分页查询账号列表 | query: `pageNum, pageSize` | `Result<PagingList<Account>>` |
| PUT | `/change-password` | 修改当前账号密码 | `{ password, newPassword }` | `Result<String>` |
| GET | `/profile` | 获取当前登录账号信息 | — | `Result<Account>` |

---

## 3 工作空间

**Controller**：`WorkspaceController`  **前缀**：`/console/v1/workspaces`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/` | 创建工作空间 | `{ name, ... }` | `Result<String>` — workspaceId |
| PUT | `/{workspaceId}` | 更新工作空间 | path: `workspaceId`；body: `Workspace` | `Result<String>` |
| DELETE | `/{workspaceId}` | 删除工作空间 | path: `workspaceId` | `Result<Void>` |
| GET | `/{workspaceId}` | 查询工作空间详情 | path: `workspaceId` | `Result<Workspace>` |
| GET | `/` | 分页查询工作空间列表 | query: `pageNum, pageSize` | `Result<PagingList<Workspace>>` |

---

## 4 应用管理

**Controller**：`AppController`  **前缀**：`/console/v1/apps`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/` | 创建 App（Agent 或 Workflow） | `{ name, type, config, ... }` | `Result<String>` — appId |
| PUT | `/{appId}` | 更新 App | path: `appId`；body: `Application` | `Result<String>` |
| DELETE | `/{appId}` | 删除 App | path: `appId` | `Result<Void>` |
| GET | `/{appId}` | 查询 App 详情 | path: `appId` | `Result<Application>` |
| GET | `/` | 分页查询 App 列表 | query: `pageNum, pageSize, type, name` | `Result<PagingList<Application>>` |
| POST | `/{appId}/publish` | 发布 App（Workflow 类型会校验配置） | path: `appId` | `Result<Void>` |
| GET | `/{appId}/versions` | 查询 App 版本列表 | path: `appId`；query: 分页 | `Result<PagingList<ApplicationVersion>>` |
| GET | `/{appId}/versions/{version}` | 查询指定版本详情 | path: `appId, version` | `Result<ApplicationVersion>` |
| POST | `/{appId}/copy` | 复制 App | path: `appId` | `Result<String>` — 新 appId |

---

## 5 应用对话（调试）

**Controller**：`AppChatController`  **前缀**：`/console/v1/apps`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/chat/completions` | 向草稿 App 发起对话（支持流式/非流式） | `AgentRequest` — `{ appId, messages, stream, ... }` | 非流：`AgentResponse` JSON；流：`text/event-stream` SSE |

> `stream=true` 时响应头为 `Content-Type: text/event-stream`，每帧为 `AgentResponse` JSON，末帧 status=COMPLETED。

---

## 6 Workflow 编排与调试

**Controller**：`WorkflowController`  **前缀**：`/console/v1/apps`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/workflow/debug/init` | 初始化调试任务，返回节点参数列表 | `{ appId, version }` | `Result<List<TaskRunParam>>` |
| POST | `/workflow/debug/run-task` | 启动调试任务 | `TaskRunRequest` — `{ appId, inputs, ... }` | `Result<TaskRunResponse>` — `{ taskId }` |
| POST | `/workflow/debug/get-task-process` | 轮询任务执行进度 | `{ taskId }` | `Result<ProcessGetResponse>` — 节点状态列表 |
| POST | `/workflow/debug/resume-task` | 恢复暂停的任务（人工审核节点） | `TaskResumeRequest` | `Result<TaskResumeResponse>` |
| POST | `/workflow/debug/part-graph/run-task` | 执行部分子图 | `TaskPartGraphRequest` | `Result<TaskPartGraphResponse>` |
| POST | `/workflow/debug/part-graph/stop-task` | 停止子图任务 | `{ taskId }` | `Result<Boolean>` |
| POST | `/workflow/{appId}/run_stream` | 已发布 App 流式执行 | path: `appId`；body: inputs | `text/event-stream` |

---

## 7 应用组件

**Controller**：`AppComponentController`  **前缀**：`/console/v1/component-servers`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| GET | `/` | 分页查询已发布组件列表 | query: `type, name, appId, pageNum, pageSize` | `Result<PagingList<AppComponent>>` |
| GET | `/app-publishable` | 查询可发布为组件的 App 列表 | query: `type, appName` | `Result<PagingList<Application>>` |
| POST | `/` | 将 App 发布为组件 | `{ type, name, config, appId, description }` | `Result<String>` — componentCode |
| PUT | `/{code}` | 更新组件配置 | path: `code`；body: 同上 | `Result<String>` |
| DELETE | `/{code}` | 删除组件 | path: `code` | `Result<Boolean>` |
| GET | `/{code}/detail-by-code` | 按 code 查组件详情（含合并配置） | path: `code` | `Result<AppComponent>` |
| GET | `/{appId}/detail-by-appid` | 按 appId 查组件详情 | path: `appId` | `Result<AppComponent>` |
| GET | `/{code}/query-refer` | 查询引用该组件的 App 列表 | path: `code` | `Result<List<AppComponent>>` |
| GET | `/{appId}/query-config` | 查询 App 的组件输入配置 | path: `appId` | `Result<AppComponent>` |
| POST | `/query-by-codes` | 批量按 codes 查组件 | `{ codes: string[] }` | `Result<List<AppComponent>>` |
| GET | `/{code}/query-schema` | 查询组件输入输出 Schema | path: `code` | `Result<Map>` — `{ input, output, output_type }` |
| POST | `/schema-by-codes` | 批量查组件 Schema | `{ codes: string[] }` | `Result<Map<code, schema>>` |

---

## 8 知识库

**Controller**：`KnowledgeBaseController`  **前缀**：`/console/v1/knowledge-bases`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/` | 创建知识库 | `{ name, processConfig, indexConfig: { embeddingProvider, embeddingModel } }` | `Result<String>` — kbId |
| PUT | `/{kbId}` | 更新知识库 | path: `kbId`；body: `KnowledgeBase` | `Result<String>` |
| DELETE | `/{kbId}` | 删除知识库 | path: `kbId` | `Result<Void>` |
| GET | `/{kbId}` | 查询知识库详情 | path: `kbId` | `Result<KnowledgeBase>` |
| GET | `/` | 分页查询知识库列表 | query: `pageNum, pageSize` | `Result<PagingList<KnowledgeBase>>` |
| POST | `/query-by-codes` | 批量按 kbIds 查知识库 | `{ kbIds: string[] }` | `Result<List<KnowledgeBase>>` |
| POST | `/retrieve` | 向量检索相关文档片段 | `{ query, searchOptions: { kbIds, topK } }` | `Result<List<DocumentChunk>>` |

---

## 9 文档管理

**Controller**：`DocumentController`  **前缀**：`/console/v1/knowledge-bases`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/{kbId}/documents` | 向知识库添加文档 | path: `kbId`；body: `{ type, files }` | `Result<List<String>>` — docIds |
| PUT | `/{kbId}/documents/{docId}` | 更新文档 | path: `kbId, docId`；body: `Document` | `Result<Void>` |
| DELETE | `/{kbId}/documents/{docId}` | 删除单个文档 | path: `kbId, docId` | `Result<Void>` |
| DELETE | `/{kbId}/documents/batch-delete` | 批量删除文档 | path: `kbId`；body: `{ docIds }` | `Result<Void>` |
| GET | `/{kbId}/documents/{docId}` | 查询文档详情 | path: `kbId, docId` | `Result<Document>` |
| GET | `/{kbId}/documents` | 分页查询文档列表 | path: `kbId`；query: 分页+过滤 | `Result<PagingList<Document>>` |
| PUT | `/{kbId}/documents/{docId}/re-index` | 重新索引文档（更新切分配置） | path: `kbId, docId`；body: `IndexDocumentRequest` | `Result<Void>` |

---

## 10 文档 Chunk

**Controller**：`DocumentChunkController`  **前缀**：`/console/v1/documents`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/{docId}/chunks` | 创建 Chunk | path: `docId`；body: `{ text }` | `Result<String>` — chunkId |
| PUT | `/{docId}/chunks/{chunkId}` | 更新 Chunk 文本 | path: `docId, chunkId`；body: `{ text }` | `Result<Void>` |
| DELETE | `/{docId}/chunks/{chunkId}` | 删除单个 Chunk | path: `docId, chunkId` | `Result<Void>` |
| DELETE | `/{docId}/chunks/batch-delete` | 批量删除 Chunk | path: `docId`；body: `{ chunkIds }` | `Result<Void>` |
| GET | `/{docId}/chunks` | 分页查询 Chunk 列表 | path: `docId`；query: 分页 | `Result<PagingList<DocumentChunk>>` |
| POST | `/{docId}/chunks/preview` | 预览切分结果（不落库） | path: `docId`；body: `IndexDocumentRequest` | `Result<List<DocumentChunk>>` |
| PUT | `/{docId}/chunks/update-status` | 批量启用/禁用 Chunk | path: `docId`；body: `{ chunkIds, enabled }` | `Result<Void>` |

---

## 11 文件上传下载

**Controller**：`FileController`  **前缀**：`/console/v1/files`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/upload` | 上传文件到本地/OSS（multipart） | form: `files[] + category` | `Result<List<UploadPolicy>>` — `{ path, name, extension, size }` |
| GET | `/download` | 下载/预览文件 | query: `path, preview=false` | 二进制流（inline 或 attachment） |
| POST | `/upload-policies` | 获取 OSS 直传凭证（前端直传） | `{ category, files: [{ name }] }` | `Result<List<WebUploadPolicy>>` |
| GET | `/get-preview-url` | 获取 OSS 文件预览 URL | query: `path` | `Result<String>` — 带签名 URL |

---

## 12 模型提供商

**Controller**：`ProviderController`  **前缀**：`/console/v1/providers`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/` | 新增模型提供商 | `{ name, description, protocol, supportedModelTypes, credentialConfig }` | `Result<Boolean>` |
| PUT | `/{provider}` | 更新提供商配置 | path: `provider`；body: `UpdateProviderRequest` | `Result<Boolean>` |
| DELETE | `/{provider}` | 删除提供商 | path: `provider` | `Result<Boolean>` |
| GET | `/` | 查询提供商列表 | query: `name` | `Result<List<ProviderConfigInfo>>` |
| GET | `/{provider}` | 查询提供商详情（含凭证结构） | path: `provider` | `Result<ProviderConfigInfo>` |
| GET | `/protocols` | 获取支持的协议列表 | — | `Result<List<String>>` — `["OpenAI"]` |
| POST | `/{provider}/models` | 向提供商添加模型 | path: `provider`；body: `{ modelId, modelName, type, tags }` | `Result<Boolean>` |
| PUT | `/{provider}/models/{modelId}` | 更新模型配置 | path: `provider, modelId`；body: `UpdateModelRequest` | `Result<Boolean>` |
| DELETE | `/{provider}/models/{modelId}` | 删除模型 | path: `provider, modelId` | `Result<Boolean>` |
| GET | `/{provider}/models` | 查询提供商下所有模型 | path: `provider` | `Result<List<ModelConfigInfo>>` |
| GET | `/{provider}/models/{modelId}` | 查询模型详情 | path: `provider, modelId` | `Result<ModelConfigInfo>` |
| GET | `/{provider}/models/{modelId}/parameter_rules` | 查询模型参数规则 | path: `provider, modelId` | `Result<List<ParameterRule>>` |

---

## 13 模型选择

**Controller**：`ModelController`  **前缀**：`/console/v1/models`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| GET | `/{modelType}/selector` | 按类型（chat/embedding）返回按提供商分组的模型列表 | path: `modelType` | `Result<List<ModelProviderGroup>>` — `{ provider, models[] }` |
| GET | `/enabled` | 获取所有启用模型（兼容 Prompt 平台格式） | — | `Result<List<Map>>` — `{ id, name, provider, modelName, status }` |

---

## 14 插件管理

**Controller**：`PluginController`  **前缀**：`/console/v1`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/plugins` | 创建插件 | `Plugin` — `{ name, config: { server, auth } }` | `Result<String>` — pluginId |
| PUT | `/plugins/{pluginId}` | 更新插件 | path: `pluginId`；body: `Plugin` | `Result<Void>` |
| DELETE | `/plugins/{pluginId}` | 删除插件 | path: `pluginId` | `Result<Void>` |
| GET | `/plugins/{pluginId}` | 查询插件详情 | path: `pluginId` | `Result<Plugin>` |
| GET | `/plugins` | 分页查询插件列表 | query: `pageNum, pageSize` | `Result<PagingList<Plugin>>` |
| POST | `/plugins/{pluginId}/tools` | 向插件添加工具 | path: `pluginId`；body: `Tool` — `{ name, description, config: { path, requestMethod } }` | `Result<String>` — toolId |
| PUT | `/plugins/{pluginId}/tools/{toolId}` | 更新工具 | path: `pluginId, toolId`；body: `Tool` | `Result<String>` |
| DELETE | `/plugins/{pluginId}/tools/{toolId}` | 删除工具 | path: `pluginId, toolId` | `Result<Void>` |
| GET | `/plugins/{pluginId}/tools/{toolId}` | 查询工具详情 | path: `pluginId, toolId` | `Result<Tool>` |
| GET | `/plugins/{pluginId}/tools` | 分页查询插件工具列表 | path: `pluginId`；query: 分页 | `Result<PagingList<Tool>>` |
| POST | `/tools/{toolId}/enable` | 启用工具 | path: `toolId` | `Result<Void>` |
| POST | `/tools/{toolId}/disable` | 禁用工具 | path: `toolId` | `Result<Void>` |
| POST | `/plugins/{pluginId}/tools/{toolId}/test` | 测试工具执行 | path: `pluginId, toolId`；body: `ToolExecutionRequest` | `Result<ToolExecutionResult>` |
| POST | `/plugins/{pluginId}/tools/{toolId}/publish` | 发布工具 | path: `pluginId, toolId` | `Result<Void>` |
| POST | `/tools/query-by-ids` | 批量按 toolIds 查工具 | `{ toolIds: string[] }` | `Result<List<Tool>>` |

---

## 15 工具管理（ToolController）

**Controller**：`ToolController`  **前缀**：`/console/v1/tools`

> 独立的工具实体 CRUD，与 Plugin 的子资源 Tool 并行存在。

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/` | 创建工具实体 | `ToolEntity` | `Result<ToolEntity>` |
| PUT | `/{id}` | 更新工具实体 | path: `id`（Long）；body: `ToolEntity` | `Result<ToolEntity>` |
| DELETE | `/{id}` | 删除工具实体 | path: `id` | `Result<Void>` |
| GET | `/{id}` | 查询工具详情 | path: `id` | `Result<ToolEntity>` |
| GET | `/` | 查询当前工作空间所有工具 | — | `Result<List<ToolEntity>>` |
| GET | `/page` | 分页查询工具 | query: `current, size` | `Result<PagingList<ToolEntity>>` |
| GET | `/search` | 按名称搜索工具 | query: `name` | `Result<List<ToolEntity>>` |
| GET | `/plugin/{pluginId}` | 按 pluginId 查工具 | path: `pluginId` | `Result<List<ToolEntity>>` |
| PATCH | `/{id}/enabled` | 启用/禁用工具 | path: `id`；query: `enabled` | `Result<Void>` |

---

## 16 MCP Server

**Controller**：`McpServerController`  **前缀**：`/console/v1/mcp-servers`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/` | 创建 MCP Server | `{ name, deployConfig }` | `Result<String>` — serverCode |
| PUT | `/` | 更新 MCP Server | `{ serverCode, name, deployConfig }` | `Result<String>` |
| DELETE | `/{serverCode}` | 删除 MCP Server | path: `serverCode` | `Result<Void>` |
| GET | `/{serverCode}` | 查询 MCP Server 详情 | path: `serverCode`；query: `need_tools` | `Result<McpServerDetail>` |
| GET | `/` | 分页查询 MCP Server 列表 | query: 分页+过滤 | `Result<PagingList<McpServerDetail>>` |
| POST | `/query-by-codes` | 批量按 serverCodes 查 | `{ codes: string[] }` | `Result<List<McpServerDetail>>` |
| POST | `/debug-tools` | 调试 MCP 工具（实时调用） | `{ serverCode, toolName, arguments }` | `Result<McpServerCallToolResponse>` |

---

## 17 Agent Schema

**Controller**：`AgentSchemaController`  **前缀**：`/console/v1/agent-schemas`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/` | 创建 Agent Schema | `AgentSchemaEntity` | `Result<AgentSchemaEntity>` |
| PUT | `/{id}` | 更新 Agent Schema | path: `id`；body: `AgentSchemaEntity` | `Result<AgentSchemaEntity>` |
| DELETE | `/{id}` | 删除 Agent Schema | path: `id` | `Result<Void>` |
| GET | `/{id}` | 查询 Agent Schema 详情 | path: `id` | `Result<AgentSchemaEntity>` |
| GET | `/` | 查询当前工作空间所有 Schema | — | `Result<List<AgentSchemaEntity>>` |
| GET | `/page` | 分页查询 | query: `current, size` | `Result<PagingList<AgentSchemaEntity>>` |
| GET | `/search` | 按名称搜索 | query: `name` | `Result<List<AgentSchemaEntity>>` |
| PATCH | `/{id}/enabled` | 启用/禁用 | path: `id`；query: `enabled` | `Result<Void>` |

---

## 18 API Key 管理

**Controller**：`ApiKeyController`  **前缀**：`/console/v1/api-keys`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/` | 创建 API Key | `{ description }` | `Result<String>` — id |
| PUT | `/{id}` | 更新 API Key 描述 | path: `id`；body: `{ description }` | `Result<String>` |
| DELETE | `/{id}` | 删除 API Key | path: `id` | `Result<Void>` |
| GET | `/{id}` | 查询 API Key 详情 | path: `id` | `Result<ApiKey>` |
| GET | `/` | 分页查询 API Key 列表 | query: `pageNum, pageSize` | `Result<PagingList<ApiKey>>` |

---

## 19 Prompt 管理

**Controller**：`PromptController`  **前缀**：`/api`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/prompt` | 创建 Prompt | `PromptCreateRequest` — `{ promptKey, promptDescription, tags }` | `Result<Prompt>` |
| GET | `/prompt` | 查询 Prompt 详情 | query: `promptKey` | `Result<Prompt>` |
| GET | `/prompts` | 分页查询 Prompt 列表 | query: `pageNum, pageSize, name, ...` | `Result<PageResult<Prompt>>` |
| PUT | `/prompt` | 更新 Prompt | `PromptUpdateRequest` | `Result<Prompt>` |
| DELETE | `/prompt` | 删除 Prompt | query: `promptKey` | `Result<Boolean>` |
| POST | `/prompt/version` | 创建 Prompt 版本 | `PromptVersionCreateRequest` | `Result<PromptVersion>` |
| GET | `/prompt/version` | 查询版本详情 | query: `promptKey, version` | `Result<PromptVersionDetail>` |
| GET | `/prompt/version/diff` | 对比两个版本差异 | query: `promptKey, versionA, versionB` | `Result<PromptVersionDiffResult>` |
| GET | `/prompt/versions` | 分页查询版本列表 | query: `promptKey, pageNum, pageSize` | `Result<PageResult<PromptVersion>>` |
| GET | `/prompt/template` | 查询 Prompt 模板详情 | query: `promptTemplateKey` | `Result<PromptTemplateDetail>` |
| GET | `/prompt/templates` | 分页查询 Prompt 模板列表 | query: 分页+过滤 | `Result<PageResult<PromptTemplate>>` |
| POST | `/prompt/run` | 流式调试执行 Prompt | `PromptRunRequest` — `{ promptKey, version, variables, messages }` | `Flux<PromptRunResponse>`（NDJSON） |
| GET | `/prompt/session` | 查询调试会话信息 | query: `sessionId` | `Result<ChatSession>` |
| DELETE | `/prompt/session` | 删除调试会话 | query: `sessionId` | `Result<Void>` |

---

## 20 数据集管理

**Controller**：`DatasetController`  **前缀**：`/api/dataset`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/dataset` | 创建数据集 | `DatasetCreateRequest` | `Result<Dataset>` |
| GET | `/dataset` | 查询数据集详情 | query: `datasetId` | `Result<Dataset>` |
| GET | `/datasets` | 分页查询数据集列表 | query: 分页+过滤 | `Result<PageResult<Dataset>>` |
| PUT | `/dataset` | 更新数据集 | `DatasetUpdateRequest` | `Result<Dataset>` |
| DELETE | `/dataset` | 删除数据集 | query: `datasetId` | `Result<Void>` |
| POST | `/datasetVersion` | 创建数据集版本 | `DatasetVersionCreateRequest` | `Result<DatasetVersion>` |
| GET | `/datasetVersions` | 查询数据集版本列表 | query: 分页 | `Result<PageResult<DatasetVersion>>` |
| PUT | `/datasetVersion` | 更新数据集版本 | `DatasetVersionUpdateRequest` | `Result<DatasetVersion>` |
| POST | `/dataItem` | 批量创建数据项 | `DatasetItemCreateRequest` | `Result<List<DatasetItem>>` |
| GET | `/dataItem` | 查询数据项详情 | path var: `id` | `Result<DatasetItem>` |
| GET | `/dataItems` | 分页查询数据项列表 | query: 分页 | `Result<PageResult<DatasetItem>>` |
| PUT | `/dataItem` | 更新数据项 | `DatasetItemUpdateRequest` | `Result<DatasetItem>` |
| DELETE | `/dataItem` | 删除数据项 | query: `id` | `Result<Void>` |
| POST | `/dataItemFromTrace` | 从 Trace 数据创建数据项 | `DataItemCreateFromTraceRequest` | `Result<List<DatasetItem>>` |
| GET | `/experiments` | 查询数据集关联的实验 | query: `datasetId, versionId, ...` | `Result<PageResult<Experiment>>` |

---

## 21 评估器管理

**Controller**：`EvaluatorController`  **前缀**：`/api/evaluator`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/evaluator` | 创建评估器 | `EvaluatorCreateRequest` | `Result<Evaluator>` |
| GET | `/evaluator` | 查询评估器详情 | query: `id` | `Result<Evaluator>` |
| GET | `/evaluators` | 分页查询评估器列表 | query: 分页+过滤 | `Result<PageResult<Evaluator>>` |
| PUT | `/evaluator` | 更新评估器 | `EvaluatorUpdateRequest` | `Result<Evaluator>` |
| DELETE | `/evaluator` | 删除评估器 | query: `id` | `Result<Void>` |
| POST | `/evaluatorVersion` | 创建评估器版本 | `EvaluatorVersionCreateRequest` | `Result<EvaluatorVersion>` |
| GET | `/evaluatorVersions` | 查询评估器版本列表 | query: 分页 | `Result<PageResult<EvaluatorVersion>>` |
| POST | `/debug` | 调试评估器 | `EvaluatorTestRequest` — `{ input, output, evaluatorId }` | `Result<EvaluatorDebugResult>` |
| GET | `/templates` | 获取评估模板列表 | query: 分页+过滤 | `Result<PageResult<EvaluatorTemplate>>` |
| GET | `/template` | 获取评估模板详情 | query: `templateId` | `Result<EvaluatorTemplate>` |
| GET | `/experiments` | 查询评估器关联实验 | query: `evaluatorId, ...` | `Result<PageResult<Experiment>>` |

---

## 22 实验管理

**Controller**：`ExperimentController`  **前缀**：`/api`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/experiment` | 创建并启动实验 | `ExperimentCreateRequest` — `{ name, promptKey, version, datasetId, evaluatorIds }` | `Result<Experiment>` |
| GET | `/experiments` | 分页查询实验列表 | query: 分页+过滤 | `Result<PageResult<Experiment>>` |
| GET | `/experiment` | 查询实验详情 | query: `experimentId` | `Result<Experiment>` |
| GET | `/experiment/results` | 查询实验概览结果（每个评估器汇总） | query: `experimentId` | `Result<List<ExperimentEvaluatorResult>>` |
| GET | `/experiment/result` | 查询实验详细结果（分页） | query: `experimentId, evaluatorVersionId, ...` | `Result<PageResult<ExperimentEvaluatorResultDetail>>` |
| PUT | `/experiment/stop` | 停止运行中的实验 | query: `experimentId` | `Result<Experiment>` |
| PUT | `/experiment/restart` | 重启实验 | query: `experimentId` | `Result<Void>` |
| DELETE | `/experiment` | 删除实验 | query: `experimentId` | `Result<Void>` |

---

## 23 可观测性（Trace）

**Controller**：`ObservabilityController`  **前缀**：`/api/observability`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| GET | `/traces` | 分页查询 Trace 列表 | query: `serviceName, startTime, endTime, pageNum, pageSize` | `Result<PageResult<TraceSpanDTO>>` |
| GET | `/traces/{traceId}` | 查询 Trace 详情（含 Span 树） | path: `traceId` | `Result<TraceDetailDTO>` |
| GET | `/services` | 查询接入的服务列表 | query: `startTime, endTime` | `Result<ServicesResponseDTO>` |
| GET | `/overview` | 查询可观测性概览统计 | query: `serviceName, startTime, endTime` | `Result<OverviewStatsDTO>` |

---

## 24 模型配置（评估平台）

**Controller**：`ModelConfigController`  **前缀**：`/api`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| GET | `/model/supported` | 获取支持的模型提供商列表 | — | `Result<List<String>>` |
| GET | `/models` | 分页查询模型配置 | query: 分页+过滤 | `Result<PageResult<ModelConfigResponse>>` |
| GET | `/model` | 按 ID 查询模型配置 | query: `id` | `Result<ModelConfigResponse>` |
| GET | `/models/enabled` | 获取所有启用的模型配置 | — | `Result<List<ModelConfigResponse>>` |

---

## 25 仪表板

**Controller**：`DashboardController`  **前缀**：`/api/dashboard`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| GET | `/overview` | 获取仪表板概览统计数据 | — | `Result<DashboardOverviewResult>` |

---

## 26 系统配置

**Controller**：`SystemController`  **前缀**：`/console/v1/system`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| GET | `/global-config` | 获取全局配置（登录方式、上传方式） | — | `Result<GlobalConfig>` — `{ login_method, upload_method }` |
| GET | `/health` | 健康检查 | — | `"ok"` (plain text) |

---

## 27 OpenAPI 外部调用

**Controller**：`ChatController`（server-openapi 模块）  **前缀**：`/api/v1/apps`  
**鉴权**：Header `Authorization: Bearer <apiKey>`（ApiKeyAuthInterceptor）

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| POST | `/chat/completions` | 对已发布 Agent App 发起对话（兼容 OpenAI Chat API） | `AgentRequest` — `{ appId, messages, stream, ... }` | 非流：`AgentResponse` JSON；流：SSE |
| POST | `/workflow/completions` | 对已发布 Workflow App 发起执行（支持流式） | `WorkflowRequest` | 非流：`WorkflowResponse`；流：SSE |
| POST | `/workflow/async-completions` | 异步启动 Workflow 任务 | `WorkflowRequest` | `Result<TaskRunResponse>` — `{ taskId }` |
| POST | `/workflow/stop-completions` | 停止异步 Workflow 任务 | `{ taskId }` | `Result<Boolean>` |
| POST | `/workflow/async-results` | 查询异步任务执行结果 | `{ taskId }` | `Result<AsyncResultResponse>` — `{ taskId, taskStatus, outputs[] }` |

---

## 28 Graph Studio 代码生成

**前缀**：`/graph-studio/api`  
> 内部代码生成工具，供前端 Workflow 画布导出 Spring AI 项目骨架使用。

| Controller | 前缀 | 说明 |
|---|---|---|
| `ApplicationController` | `/graph-studio/api/app` | App 元数据读写（委托 `AppDelegate`） |
| `DSLController` | `/graph-studio/api/dsl` | 导入/导出 DSL（Dify 等方言适配） |
| `GeneratorController` | 继承 initializr | 生成 Spring Boot 项目压缩包 |
| `RunnerController` | `/graph-studio/api/run` | 在线运行生成的 Graph 代码 |

> 具体端点由 `AppAPI`、`DSLAPI`、`RunnerAPI` 接口定义，实现细节在 `AppDelegate` / `DSLAdapter` 中。

---

## 29 OAuth2 登录

**Controller**：`Oauth2Controller`  **前缀**：`/oauth2`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| GET | `/login/github` | 获取 GitHub OAuth2 授权 URL | — | `Result<String>` — authUrl |
| GET | `/callback/github` | GitHub 授权回调，换取 token 后重定向前端 | query: `code` | 重定向至 `/?access_token=&refresh_token=&expires_in=` |

---

## 30 测试示例接口

**Controller**：`ApiExampleController`  **前缀**：`/test/api/example`  
> 仅供插件工具调试演示，不用于生产。

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
| GET | `/getOrder` | 模拟查询订单（GET） | query: 任意 | `Map` — `{ orderId, description, data }` |
| POST | `/getOrder` | 模拟查询订单（POST body） | `{ orderId }` | `Map` — `{ orderId, description, items[] }` |
| POST | `/getOrder/{orderId}` | 模拟查询订单（path + body） | path: `orderId`；body: 任意 | `Map` — `{ orderId, description, items[] }` |

---

*扫描时间：2026-05-10 | 共扫描 32 个 Controller，约 150 个接口端点*
