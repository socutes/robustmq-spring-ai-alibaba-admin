# 核心数据模型

> 来源：`docker/middleware/init/mysql/admin-schema.sql`、`agentscope-schema.sql` 及所有 entity 类。
> 两个数据库：`admin`（Prompt / Dataset / Evaluator / Experiment / ModelConfig）、`agentscope`（Account / App / KB / Tool / Plugin / Provider / Model / MCP / AgentSchema 等）。

---

## 目录

- [Admin 库](#admin-库)
  - [prompt](#prompt)
  - [prompt_version](#prompt_version)
  - [prompt_build_template](#prompt_build_template)
  - [dataset](#dataset)
  - [dataset_version](#dataset_version)
  - [dataset_item](#dataset_item)
  - [evaluator](#evaluator)
  - [evaluator_version](#evaluator_version)
  - [evaluator_template](#evaluator_template)
  - [experiment](#experiment)
  - [experiment_result](#experiment_result)
  - [model_config](#model_config)
- [Agentscope 库](#agentscope-库)
  - [account](#account)
  - [workspace](#workspace)
  - [api_key](#api_key)
  - [application](#application)
  - [application_version](#application_version)
  - [application_component](#application_component)
  - [knowledge_base](#knowledge_base)
  - [document](#document)
  - [plugin](#plugin)
  - [tool](#tool)
  - [provider](#provider)
  - [model](#model)
  - [mcp_server](#mcp_server)
  - [agent_schema](#agent_schema)
  - [reference](#reference)

---

## Admin 库

### prompt

Prompt 主表，以 `prompt_key` 为业务唯一标识，对应一组版本。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| prompt_key 🔐 | VARCHAR(255) | 业务唯一键，Nacos 同步也使用此 key |
| prompt_desc | VARCHAR(255) | Prompt 描述 |
| latest_version | VARCHAR(32) | 当前最新版本号（冗余，快速读取） |
| tags | VARCHAR(255) | 逗号分隔标签 |
| create_time | DATETIME(3) | 创建时间 |
| update_time | DATETIME(3) | 更新时间（自动维护） |

---

### prompt_version

Prompt 的具体版本内容，一个 prompt 对应多个版本。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| prompt_key 🔗 | VARCHAR(255) | 关联 `prompt.prompt_key` |
| version 🔐 | VARCHAR(32) | 版本号，与 prompt_key 联合唯一 |
| version_desc | VARCHAR(255) | 版本描述 |
| template | LONGTEXT | Prompt 模板正文，含 `{{变量}}` 占位符 |
| variables | LONGTEXT | 变量名列表（逗号或 JSON） |
| model_config | LONGTEXT | 调试该版本使用的模型参数 JSON |
| status | VARCHAR(32) | **枚举**：`pre`（预发布）、`release`（正式） |
| previous_version | VARCHAR(32) | 前置版本号，用于 diff 对比 |
| create_time | DATETIME(3) | 创建时间 |

> 索引：`UNIQUE(prompt_key, version)`

---

### prompt_build_template

Prompt 构建模板（系统预置），供用户快速选用。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| prompt_template_key 🔐 | VARCHAR(255) | 模板唯一键 |
| tags | VARCHAR(255) | 逗号分隔标签 |
| template_desc | VARCHAR(255) | 模板描述 |
| template | LONGTEXT | 模板正文 |
| variables | LONGTEXT | 变量名列表 |
| model_config | LONGTEXT | 推荐模型参数 JSON |

---

### dataset

评估数据集主表。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| name | VARCHAR(255) | 数据集名称 |
| description | TEXT | 描述 |
| columns_config | LONGTEXT | 列结构定义 JSON（字段名、类型） |
| create_time | DATETIME | 创建时间 |
| update_time | DATETIME | 更新时间 |
| deleted | TINYINT(1) | 逻辑删除：`0` 正常，`1` 已删除 |

---

### dataset_version

数据集版本，一个 dataset 对应多个版本，版本锁定数据项快照。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| dataset_id 🔗 | BIGINT UNSIGNED | FK → `dataset.id`，级联删除 |
| version 🔐 | VARCHAR(32) | 版本号，与 dataset_id 联合唯一 |
| description | TEXT | 版本描述 |
| data_count | INT | 该版本数据项数量 |
| status | VARCHAR(32) | **枚举**：`DRAFT`、`PUBLISHED`、`ARCHIVED` |
| experiments | TEXT | 关联实验 ID 列表 JSON |
| dataset_items | TEXT | 该版本数据项 ID 列表 JSON |
| create_time | DATETIME | 创建时间 |
| update_time | DATETIME | 更新时间 |

---

### dataset_item

数据集的单条数据项，存储输入/期望输出等实际内容。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| dataset_id 🔗 | BIGINT UNSIGNED | FK → `dataset.id`，级联删除 |
| columns_config | LONGTEXT | 列结构定义（覆盖 dataset 级别） |
| data_content | LONGTEXT | 数据内容 JSON（input、expected_output 等） |
| create_time | DATETIME | 创建时间 |
| update_time | DATETIME | 更新时间 |
| deleted | TINYINT(1) | 逻辑删除 |

---

### evaluator

评估器主表，一个评估器对应多个版本。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| name | VARCHAR(255) | 评估器名称 |
| description | TEXT | 描述 |
| create_time | DATETIME | 创建时间 |
| update_time | DATETIME | 更新时间 |
| deleted | TINYINT(1) | 逻辑删除 |

---

### evaluator_version

评估器版本，包含具体的 Prompt 逻辑和模型配置。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| evaluator_id 🔗 | BIGINT UNSIGNED | FK → `evaluator.id`，级联删除 |
| version 🔐 | VARCHAR(32) | 版本号，与 evaluator_id 联合唯一 |
| description | TEXT | 版本描述 |
| model_config | TEXT | 评估用模型参数 JSON |
| prompt | LONGTEXT | 评估 Prompt JSON |
| variables | LONGTEXT | Prompt 中的变量定义 |
| status | VARCHAR(32) | **枚举**：`DRAFT`、`PUBLISHED`、`ARCHIVED` |
| experiments | TEXT | 关联实验 ID 列表 JSON |
| create_time | DATETIME | 创建时间 |
| update_time | DATETIME | 更新时间 |

---

### evaluator_template

系统预置评估器模板（文本相似度、代码质量、情感分析等）。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| evaluator_template_key 🔐 | VARCHAR(255) | 模板唯一键 |
| template_desc | VARCHAR(255) | 模板描述 |
| template | LONGTEXT | 评估 Prompt 模板正文 |
| variables | LONGTEXT | 变量列表 |
| model_config | LONGTEXT | 推荐模型参数 JSON |

---

### experiment

实验主表，将数据集版本和评估器版本绑定后执行评估。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| name | VARCHAR(255) | 实验名称 |
| description | TEXT | 描述 |
| dataset_id 🔗 | BIGINT UNSIGNED | 关联数据集 ID |
| dataset_version_id 🔗 | BIGINT UNSIGNED | 关联数据集版本 ID |
| dataset_version | VARCHAR(32) | 冗余版本号（快速读取） |
| evaluation_object_config | LONGTEXT | 被评估对象配置 JSON（Prompt key/version 等） |
| evaluator_config | TEXT | 评估器配置 JSON（evaluator_id、version 等列表） |
| status | VARCHAR(32) | **枚举**：`DRAFT`、`RUNNING`、`COMPLETED`、`FAILED`、`STOPPED` |
| progress | INT(3) | 进度百分比 0-100 |
| complete_time | DATETIME | 完成时间 |
| create_time | DATETIME | 创建时间 |
| update_time | DATETIME | 更新时间 |

---

### experiment_result

实验的单条评估结果，每条对应一个 (数据项, 评估器版本) 组合。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| experiment_id 🔗 | BIGINT UNSIGNED | 关联 `experiment.id` |
| evaluator_version_id 🔗 | BIGINT UNSIGNED | 关联 `evaluator_version.id` |
| input | LONGTEXT | 输入内容 |
| actual_output | LONGTEXT | 被评估对象的实际输出 |
| reference_output | LONGTEXT | 参考输出（用于对比） |
| score | DECIMAL(3,2) | 评估分数 0.00–1.00 |
| reason | TEXT | 评估理由说明 |
| evaluation_time | DATETIME | 评估执行时间 |
| create_time | DATETIME | 创建时间 |
| update_time | DATETIME | 更新时间 |

---

### model_config

Studio 侧管理的模型配置（供 Prompt 调试使用）。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT AI | 主键 |
| name 🔐 | VARCHAR(100) | 配置名称（唯一） |
| provider | VARCHAR(50) | 提供商标识：`openai`、`dashscope`、`deepseek` 等 |
| model_name | VARCHAR(100) | 模型标识符：`gpt-4`、`qwen-max` 等 |
| base_url | VARCHAR(500) | 模型服务地址 |
| api_key | VARCHAR(500) | API 密钥（存储时应加密） |
| default_parameters | JSON | 默认参数（temperature、max_tokens 等） |
| supported_parameters | JSON | 支持的参数定义列表 |
| status | TINYINT | `1` 启用，`0` 禁用 |
| deleted | TINYINT(1) | 逻辑删除 |
| create_time | DATETIME | 创建时间 |
| update_time | DATETIME | 更新时间 |

---

## Agentscope 库

### account

用户账号表，系统认证的核心实体。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| account_id 🔐 | VARCHAR(64) | 业务唯一 ID（UUID） |
| username | VARCHAR(255) | 登录名 |
| email | VARCHAR(255) | 邮箱 |
| mobile | VARCHAR(255) | 手机号 |
| password | VARCHAR(255) | Argon2 哈希密码 |
| nickname | VARCHAR(255) | 显示名 |
| icon | VARCHAR(255) | 头像 URL |
| type | VARCHAR(64) | **枚举**：`basic`、`admin` |
| status | TINYINT(4) | `0` 已删除，`1` 正常 |
| gmt_last_login | DATETIME | 最后登录时间 |
| creator / modifier | VARCHAR(64) | 操作人 UID |

---

### workspace

工作空间，资源隔离的基本单元，属于某个账号。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| workspace_id 🔐 | VARCHAR(64) | 业务唯一 ID |
| account_id 🔗 | VARCHAR(64) | 归属账号 `account.account_id` |
| name | VARCHAR(255) | 工作空间名称 |
| description | VARCHAR(4096) | 描述 |
| config | TEXT | 工作空间配置 JSON |
| status | TINYINT(4) | `0` 已删除，`1` 正常 |

---

### api_key

账号的 API 访问密钥。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| account_id 🔗 | VARCHAR(64) | 归属账号 `account.account_id` |
| api_key | VARCHAR(512) | 密钥值 |
| status | TINYINT(4) | `0` 已删除，`1` 正常 |
| description | VARCHAR(4096) | 描述 |

---

### application

AI 应用主表（Agent 或 Workflow 类型）。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| app_id 🔐 | VARCHAR(64) | 业务唯一 ID |
| workspace_id 🔗 | VARCHAR(64) | 归属工作空间 |
| name | VARCHAR(255) | 应用名称 |
| description | VARCHAR(4096) | 描述 |
| icon | VARCHAR(255) | 图标 |
| type | VARCHAR(64) | **枚举**：`agent`、`workflow` |
| source | VARCHAR(64) | 来源标识 |
| status | TINYINT(4) | **枚举**：`0` 删除，`1` 草稿，`2` 已发布，`3` 发布后编辑中 |

---

### application_version

应用的具体版本配置快照。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| app_id 🔗 | VARCHAR(64) | 归属应用 `application.app_id` |
| workspace_id 🔗 | VARCHAR(64) | 归属工作空间 |
| version | VARCHAR(32) | 版本号（默认 `0.0.1`） |
| config | LONGTEXT | 应用完整配置 JSON（图结构、节点配置等） |
| description | VARCHAR(4096) | 版本描述 |
| status | TINYINT(4) | 同 application.status 枚举 |

---

### application_component

已发布的应用组件，供其他应用引用。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| code 🔐 | VARCHAR(64) | 组件唯一 code |
| app_id 🔗 | VARCHAR(64) | 来源应用 `application.app_id` |
| workspace_id 🔗 | VARCHAR(64) | 归属工作空间 |
| name | VARCHAR(128) | 组件名称 |
| type | VARCHAR(64) | **枚举**：`agent`、`workflow` |
| config | LONGTEXT | 组件配置 JSON |
| status | TINYINT | `0` 删除，`1` 正常，`2` 已发布 |
| need_update | TINYINT | `0` 无需更新，`1` 需更新 |

---

### knowledge_base

知识库，向量检索的资源容器。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| kb_id 🔐 | VARCHAR(64) | 业务唯一 ID |
| workspace_id 🔗 | VARCHAR(64) | 归属工作空间 |
| name | VARCHAR(255) | 知识库名称 |
| type | VARCHAR(64) | 知识库类型（当前为 `unstructured`） |
| process_config | TEXT | 文档解析配置 JSON |
| index_config | TEXT | 向量索引配置 JSON |
| search_config | TEXT | 检索配置 JSON |
| total_docs | BIGINT UNSIGNED | 文档总数（计数缓存） |
| status | TINYINT(4) | `0` 删除，`1` 正常 |

---

### document

知识库中的文档，支持多种格式，异步索引到 Elasticsearch。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| doc_id 🔐 | VARCHAR(64) | 业务唯一 ID |
| kb_id 🔗 | VARCHAR(64) | 归属知识库 `knowledge_base.kb_id` |
| workspace_id 🔗 | VARCHAR(64) | 归属工作空间 |
| name | VARCHAR(255) | 文档名称 |
| format | VARCHAR(64) | 文件格式：`pdf`、`md`、`txt` 等 |
| size | BIGINT | 文件大小（字节） |
| path | VARCHAR(512) | OSS 存储路径 |
| parsed_path | VARCHAR(512) | 解析后内容路径 |
| index_status | TINYINT(4) | **枚举**：`1` 待处理，`2` 处理中，`3` 完成 |
| enabled | TINYINT(4) | `0` 禁用，`1` 启用 |
| process_config | TEXT | 分块配置 JSON |
| metadata | TEXT | 文档元数据 JSON |
| error | TEXT | 索引失败原因 |
| status | TINYINT(4) | `0` 删除，`1` 正常 |

---

### plugin

工具插件主表，一个插件包含多个 tool。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| plugin_id 🔐 | VARCHAR(64) | 业务唯一 ID |
| workspace_id 🔗 | VARCHAR(64) | 归属工作空间 |
| name | VARCHAR(255) | 插件名称 |
| type | VARCHAR(64) | **枚举**：`official`（官方）、`custom`（自定义） |
| source | VARCHAR(64) | 来源 |
| config | TEXT | 插件配置 JSON |
| status | TINYINT(4) | `0` 删除，`1` 正常 |

---

### tool

插件中的单个工具（对应一个 API 操作）。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| tool_id 🔐 | VARCHAR(64) | 业务唯一 ID |
| plugin_id 🔗 | VARCHAR(64) | 归属插件 `plugin.plugin_id` |
| workspace_id 🔗 | VARCHAR(64) | 归属工作空间 |
| name | VARCHAR(255) | 工具名称 |
| description | VARCHAR(4096) | 工具描述（被 LLM 读取） |
| config | LONGTEXT | 工具配置 JSON |
| api_schema | LONGTEXT | OpenAPI Schema JSON（参数定义） |
| enabled | TINYINT(4) | `0` 禁用，`1` 启用 |
| test_status | TINYINT(4) | **枚举**：`1` 未测试，`2` 测试通过，`3` 测试失败 |
| status | TINYINT(4) | `0` 删除，`1` 正常 |

---

### provider

AI 模型提供商配置（OpenAI、DashScope、自定义等）。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT AI | 主键 |
| workspace_id 🔗 | VARCHAR(64) | 归属工作空间 |
| provider | VARCHAR(255) | 提供商标识（`openai`、`dashscope` 等） |
| name | VARCHAR(255) | 显示名 |
| protocol | VARCHAR(64) | 接入协议（当前仅 `openai` 协议） |
| credential | VARCHAR(1024) | 访问凭证 JSON（含 API Key） |
| supported_model_types | VARCHAR(255) | 支持的模型类型列表 |
| enable | TINYINT(1) | `0` 禁用，`1` 启用 |
| source | VARCHAR(64) | **枚举**：`preset`（预置）、`custom`（自定义） |

---

### model

Provider 下的具体模型配置。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT AI | 主键 |
| model_id | VARCHAR(100) | 模型标识符（`gpt-4o`、`qwen-max` 等） |
| provider 🔗 | VARCHAR(100) | 归属 Provider 标识 |
| workspace_id 🔗 | VARCHAR(64) | 归属工作空间 |
| name | VARCHAR(100) | 显示名 |
| type | VARCHAR(100) | 模型类型：`LLM`、`EMBEDDING` 等 |
| mode | VARCHAR(100) | 工作模式：`chat`、`completion` 等 |
| tags | VARCHAR(255) | 标签 |
| enable | TINYINT(1) | `0` 禁用，`1` 启用 |
| source | VARCHAR(100) | `preset` / `custom` |

---

### mcp_server

MCP（Model Context Protocol）Server 注册信息。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| server_code 🔐 | VARCHAR(64) | 业务唯一 code |
| workspace_id 🔗 | VARCHAR(64) | 归属工作空间 |
| account_id 🔗 | VARCHAR(64) | 创建者账号 |
| name | VARCHAR(64) | Server 名称 |
| description | VARCHAR(1024) | 描述 |
| type | VARCHAR(32) | **枚举**：`OFFICIAL`、`CUSTOMER`（自定义） |
| deploy_env | VARCHAR(16) | **枚举**：`local`、`remote` |
| install_type | VARCHAR(32) | **枚举**：`npx`、`uvx`、`sse` |
| host | VARCHAR(1024) | 远程主机地址 |
| deploy_config | TEXT | 部署配置 JSON |
| detail_config | TEXT | 工具详情 JSON |
| status | TINYINT | `0` 禁用，`1` 正常，`3` 已删除 |
| biz_type | VARCHAR(512) | 业务分类标签 |

---

### agent_schema

Agent 定义配置，支持多种 Agent 类型组合。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| agent_id 🔐 | VARCHAR(64) | 业务唯一 ID |
| workspace_id 🔗 | VARCHAR(64) | 归属工作空间 |
| name | VARCHAR(255) | Agent 名称 |
| type | VARCHAR(64) | **枚举**：`ReactAgent`、`ParallelAgent`、`SequentialAgent`、`LLMRoutingAgent`、`LoopAgent` |
| instruction | TEXT | 系统级 System Prompt |
| input_keys | TEXT | 输入参数键定义 JSON |
| output_key | VARCHAR(255) | 输出参数键 |
| handle | LONGTEXT | 节点处理配置 JSON |
| sub_agents | LONGTEXT | 子 Agent 配置 JSON（用于组合模式） |
| yaml_schema | LONGTEXT | 生成的 YAML Schema |
| status | VARCHAR(64) | **枚举**：`DRAFT`、`PUBLISHED`、`ARCHIVED` |
| enabled | TINYINT(4) | `0` 禁用，`1` 启用 |

---

### reference

通用引用关系表，记录任意两个实体间的引用（App 引用 KB、Plugin 等）。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| main_code | VARCHAR(64) | 主体实体 code（如 app_id） |
| main_type | TINYINT | 主体实体类型枚举值 |
| refer_code | VARCHAR(64) | 被引用实体 code（如 kb_id、plugin_id） |
| refer_type | TINYINT | 被引用实体类型枚举值 |
| workspace_id 🔗 | VARCHAR(64) | 归属工作空间 |

---

## 非 MySQL 实体（运行时 / 外部存储）

以下实体在接口响应中出现，但不对应任何 MySQL 表。

---

### ChatSession（Redis）

Prompt 调试时的对话会话，由 `ChatSessionService` 管理，存储在 **Redis**（Redisson）。

| 字段 | 类型 | 说明 |
|------|------|------|
| sessionId | String | 会话唯一 ID（UUID） |
| messages | List | 历史消息列表（Spring AI `Message` 对象） |
| createTime | Long | 创建时间戳 |

> 生命周期由 Redis TTL 控制，进程重启后不保留。

---

### DocumentChunk（Elasticsearch）

文档分块向量，由 `DocumentService` 通过 RocketMQ 异步管道写入 **Elasticsearch**（Spring AI `elasticsearch-store`）。

| 字段 | 类型 | 说明 |
|------|------|------|
| chunkId | String | 分块唯一 ID |
| docId 🔗 | String | 归属文档 `document.doc_id` |
| kbId 🔗 | String | 归属知识库 `knowledge_base.kb_id` |
| content | String | 分块文本内容 |
| embedding | float[] | 向量表示（由 embedding 模型生成） |
| metadata | Map | 附加元数据（来源、页码等） |

> `DocumentChunkConverter` 负责 Spring AI `Document` ↔ `DocumentChunk` 的双向转换。MySQL 中只存储 `document` 元数据，分块内容全量在 ES。

---

### GlobalConfig（运行时 DTO）

`SystemController` 的静态内部类，每次 `GET /console/v1/system/global-config` 请求时动态构造，**不持久化**。

| 字段 | 类型 | 说明 |
|------|------|------|
| appName | String | 应用名称 |
| version | String | 系统版本号 |
| features | Map | 功能开关配置项 |

> 数据来源：`application.yml` 中的静态配置，无数据库写入。

---

## 枚举值汇总

| 模型 | 字段 | 枚举值 |
|------|------|--------|
| prompt_version | status | `pre` 预发布，`release` 正式 |
| dataset_version / evaluator_version | status | `DRAFT`、`PUBLISHED`、`ARCHIVED` |
| experiment | status | `DRAFT`、`RUNNING`、`COMPLETED`、`FAILED`、`STOPPED` |
| model_config | status | `1` 启用，`0` 禁用 |
| account | type | `basic`、`admin` |
| account | status | `0` 删除，`1` 正常 |
| application | type | `agent`、`workflow` |
| application | status | `0` 删除，`1` 草稿，`2` 已发布，`3` 发布后编辑中 |
| plugin | type | `official`、`custom` |
| tool | test_status | `1` 未测试，`2` 通过，`3` 失败 |
| document | index_status | `1` 待处理，`2` 处理中，`3` 完成 |
| agent_schema | type | `ReactAgent`、`ParallelAgent`、`SequentialAgent`、`LLMRoutingAgent`、`LoopAgent` |
| agent_schema | status | `DRAFT`、`PUBLISHED`、`ARCHIVED` |
| mcp_server | type | `OFFICIAL`、`CUSTOMER` |
| mcp_server | deploy_env | `local`、`remote` |
| mcp_server | install_type | `npx`、`uvx`、`sse` |
| provider | source | `preset`、`custom` |
