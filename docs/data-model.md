# 核心数据模型

> 来源：entity 类 + SQL DDL（admin-schema.sql / agentscope-schema.sql）  
> 数据库：MySQL 8.0，分两个 schema——**admin**（Builder 平台）、**agentscope**（评估平台）  
> 约定：🔑 主键 · 🔗 外键/关联键 · 📋 枚举见字段说明

---

## 目录

**admin schema**
1. [account — 账号](#1-account--账号)
2. [workspace — 工作空间](#2-workspace--工作空间)
3. [api_key — API 密钥](#3-api_key--api-密钥)
4. [application — 应用](#4-application--应用)
5. [application_version — 应用版本](#5-application_version--应用版本)
6. [application_component — 应用组件](#6-application_component--应用组件)
7. [reference — 引用关系](#7-reference--引用关系)
8. [knowledge_base — 知识库](#8-knowledge_base--知识库)
9. [document — 文档](#9-document--文档)
10. [plugin — 插件](#10-plugin--插件)
11. [tool — 工具](#11-tool--工具)
12. [provider — 模型提供商](#12-provider--模型提供商)
13. [model — 模型](#13-model--模型)
14. [mcp_server — MCP 服务](#14-mcp_server--mcp-服务)
15. [agent_schema — Agent Schema](#15-agent_schema--agent-schema)

**agentscope schema**
16. [prompt — Prompt](#16-prompt--prompt)
17. [prompt_version — Prompt 版本](#17-prompt_version--prompt-版本)
18. [prompt_build_template — Prompt 模板库](#18-prompt_build_template--prompt-模板库)
19. [model_config — 模型配置](#19-model_config--模型配置)
20. [dataset — 数据集](#20-dataset--数据集)
21. [dataset_version — 数据集版本](#21-dataset_version--数据集版本)
22. [dataset_item — 数据项](#22-dataset_item--数据项)
23. [evaluator — 评估器](#23-evaluator--评估器)
24. [evaluator_version — 评估器版本](#24-evaluator_version--评估器版本)
25. [evaluator_template — 评估器模板库](#25-evaluator_template--评估器模板库)
26. [experiment — 实验](#26-experiment--实验)
27. [experiment_result — 实验结果](#27-experiment_result--实验结果)

---

## admin schema

### 1 account — 账号

用户账号基本信息，支持 basic / admin 两种类型。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| account_id | VARCHAR(64) UNIQUE NOT NULL | 业务主键（UUID） |
| username | VARCHAR(255) NOT NULL | 登录用户名 |
| email | VARCHAR(255) | 邮箱 |
| mobile | VARCHAR(255) | 手机号 |
| password | VARCHAR(255) NOT NULL | Argon2 哈希密码 |
| nickname | VARCHAR(255) | 昵称 |
| icon | VARCHAR(255) | 头像 URL |
| type | VARCHAR(64) NOT NULL | 📋 `basic` / `admin` |
| status | TINYINT(4) NOT NULL DEFAULT 1 | 📋 `0`=已删除 `1`=正常 |
| gmt_create | DATETIME | 创建时间 |
| gmt_modified | DATETIME | 修改时间 |
| gmt_last_login | DATETIME | 最后登录时间 |
| creator | VARCHAR(64) | 创建者 account_id |
| modifier | VARCHAR(64) | 修改者 account_id |

---

### 2 workspace — 工作空间

资源隔离单元，每个账号可有多个工作空间。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| workspace_id | VARCHAR(64) UNIQUE NOT NULL | 业务主键 |
| 🔗 account_id | VARCHAR(64) NOT NULL | 所属账号（→ account.account_id） |
| name | VARCHAR(255) NOT NULL | 工作空间名称 |
| description | VARCHAR(4096) | 描述 |
| config | TEXT | 扩展配置 JSON |
| status | TINYINT(4) NOT NULL DEFAULT 1 | 📋 `0`=已删除 `1`=正常 |
| gmt_create / gmt_modified | DATETIME | 时间戳 |
| creator / modifier | VARCHAR(64) | 操作者 account_id |

---

### 3 api_key — API 密钥

供外部调用 OpenAPI 端点使用的密钥。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| 🔗 account_id | VARCHAR(64) NOT NULL | 所属账号（→ account.account_id） |
| api_key | VARCHAR(512) UNIQUE NOT NULL | 密钥值（Bearer Token） |
| description | VARCHAR(4096) | 用途描述 |
| status | TINYINT(4) NOT NULL DEFAULT 1 | 📋 `0`=已删除 `1`=正常 |
| gmt_create / gmt_modified | DATETIME | 时间戳 |
| creator / modifier | VARCHAR(64) | 操作者 |

---

### 4 application — 应用

Agent 或 Workflow 应用的元数据（不含配置内容，配置在 application_version）。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| app_id | VARCHAR(64) UNIQUE NOT NULL | 业务主键 |
| 🔗 workspace_id | VARCHAR(64) NOT NULL | 所属工作空间 |
| name | VARCHAR(255) NOT NULL | 应用名称 |
| description | VARCHAR(4096) | 描述 |
| icon | VARCHAR(255) | 图标 URL |
| type | VARCHAR(64) NOT NULL | 📋 `agent` / `workflow` |
| status | TINYINT(4) NOT NULL DEFAULT 1 | 📋 `0`=已删除 `1`=草稿 `2`=已发布 `3`=发布后编辑中 |
| source | VARCHAR(64) NOT NULL | 来源（custom / system） |
| gmt_create / gmt_modified | DATETIME | 时间戳 |
| creator / modifier | VARCHAR(64) | 操作者 |

---

### 5 application_version — 应用版本

存储每次发布/保存的完整配置快照（JSON）。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| 🔗 app_id | VARCHAR(64) NOT NULL | 所属应用（→ application.app_id） |
| 🔗 workspace_id | VARCHAR(64) NOT NULL | 工作空间 |
| version | VARCHAR(32) NOT NULL DEFAULT '0.0.1' | 版本号 |
| config | LONGTEXT | 完整应用配置 JSON（含节点、边、模型、提示词等） |
| status | TINYINT(4) NOT NULL | 📋 同 application.status |
| description | VARCHAR(4096) | 版本说明 |
| gmt_create / gmt_modified | DATETIME | 时间戳 |
| creator / modifier | VARCHAR(64) | 操作者 |

> 唯一索引：`(workspace_id, app_id, version)`

---

### 6 application_component — 应用组件

将已发布的 App 封装为可复用组件（供 Workflow 节点引用）。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| code | VARCHAR(64) NOT NULL | 组件唯一 code |
| 🔗 app_id | VARCHAR(64) | 源应用（→ application.app_id） |
| 🔗 workspace_id | VARCHAR(64) NOT NULL | 工作空间 |
| name | VARCHAR(128) NOT NULL | 组件名称 |
| type | VARCHAR(64) NOT NULL | 📋 `agent` / `workflow` |
| config | LONGTEXT | 组件输入输出配置 JSON |
| description | VARCHAR(4096) | 描述 |
| status | TINYINT | 📋 `0`=已删除 `1`=正常 `2`=已发布 |
| need_update | TINYINT | 源 App 更新后标记组件需同步 |
| gmt_create / gmt_modified | DATETIME | 时间戳 |
| creator / modifier | VARCHAR(64) | 操作者 |

---

### 7 reference — 引用关系

记录 App/Workflow 节点引用组件的多对多关系（无级联）。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| main_code | VARCHAR(64) NOT NULL | 引用方 code（App appId） |
| main_type | TINYINT NOT NULL | 引用方类型枚举 |
| refer_code | VARCHAR(64) NOT NULL | 被引用方 code（component code） |
| refer_type | TINYINT NOT NULL | 被引用方类型枚举 |
| 🔗 workspace_id | VARCHAR(64) NOT NULL DEFAULT '1' | 工作空间 |
| gmt_create / gmt_modified | DATETIME | 时间戳 |

---

### 8 knowledge_base — 知识库

RAG 知识库元数据，配置 Embedding 模型与检索策略。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| kb_id | VARCHAR(64) UNIQUE NOT NULL | 业务主键 |
| 🔗 workspace_id | VARCHAR(64) NOT NULL | 工作空间 |
| name | VARCHAR(255) NOT NULL | 知识库名称 |
| description | VARCHAR(4096) | 描述 |
| type | VARCHAR(64) NOT NULL | 📋 `unstructured`（当前仅非结构化） |
| status | TINYINT(4) NOT NULL DEFAULT 1 | 📋 `0`=已删除 `1`=正常 |
| process_config | TEXT | 文档处理配置 JSON（切分策略、OCR 等） |
| index_config | TEXT | 索引配置 JSON（embeddingProvider、embeddingModel、维度） |
| search_config | TEXT | 检索配置 JSON（topK、相似度阈值） |
| total_docs | BIGINT | 文档数量统计 |
| gmt_create / gmt_modified | DATETIME | 时间戳 |
| creator / modifier | VARCHAR(64) | 操作者 |

---

### 9 document — 文档

知识库中每个文档的元数据与索引状态。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| doc_id | VARCHAR(64) UNIQUE NOT NULL | 业务主键 |
| 🔗 kb_id | VARCHAR(64) NOT NULL | 所属知识库（→ knowledge_base.kb_id） |
| 🔗 workspace_id | VARCHAR(64) NOT NULL | 工作空间 |
| name | VARCHAR(255) NOT NULL | 文件名 |
| type | VARCHAR(64) NOT NULL | 📋 `file` / `url` |
| format | VARCHAR(64) NOT NULL | 文件格式（pdf / docx / txt 等） |
| size | BIGINT NOT NULL DEFAULT 0 | 文件大小（字节） |
| path | VARCHAR(512) NOT NULL | 存储路径（本地或 OSS key） |
| parsed_path | VARCHAR(512) | 解析后文本路径 |
| index_status | TINYINT(4) NOT NULL DEFAULT 1 | 📋 `1`=待处理 `2`=处理中 `3`=已完成 |
| status | TINYINT(4) NOT NULL DEFAULT 1 | 📋 `0`=已删除 `1`=正常 |
| enabled | TINYINT(4) NOT NULL DEFAULT 1 | 是否参与检索 |
| process_config | TEXT | 该文档的切分配置覆盖 |
| metadata | TEXT | 扩展元数据 JSON |
| error | TEXT | 索引失败的错误信息 |
| source | VARCHAR(255) | 来源标识 |
| gmt_create / gmt_modified | DATETIME | 时间戳 |
| creator / modifier | VARCHAR(64) | 操作者 |

> Chunk 数据存储在 **Elasticsearch**（index: `loongsuite_traces`），不落 MySQL。

---

### 10 plugin — 插件

HTTP API 插件，定义外部服务的连接配置与鉴权方式。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| plugin_id | VARCHAR(64) UNIQUE NOT NULL | 业务主键 |
| 🔗 workspace_id | VARCHAR(64) NOT NULL | 工作空间 |
| name | VARCHAR(255) NOT NULL | 插件名称 |
| description | VARCHAR(4096) | 描述 |
| type | VARCHAR(64) NOT NULL | 📋 `official` / `custom` |
| status | TINYINT(4) NOT NULL DEFAULT 1 | 📋 `0`=已删除 `1`=正常 |
| config | TEXT | 插件配置 JSON（server、auth 类型、凭证） |
| source | VARCHAR(64) NOT NULL | 来源 |
| gmt_create / gmt_modified | DATETIME | 时间戳 |
| creator / modifier | VARCHAR(64) | 操作者 |

---

### 11 tool — 工具

插件下的具体 API 端点，是 Agent 可调用的最小执行单元。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| tool_id | VARCHAR(64) UNIQUE NOT NULL | 业务主键 |
| 🔗 plugin_id | VARCHAR(64) NOT NULL | 所属插件（→ plugin.plugin_id） |
| 🔗 workspace_id | VARCHAR(64) NOT NULL | 工作空间 |
| name | VARCHAR(255) NOT NULL | 工具名称 |
| description | VARCHAR(4096) | 工具描述（LLM 用于决策调用） |
| config | LONGTEXT NOT NULL | 调用配置 JSON（path、method、contentType、参数定义） |
| api_schema | LONGTEXT NOT NULL | OpenAPI Schema JSON |
| status | TINYINT(4) NOT NULL DEFAULT 1 | 📋 `0`=已删除 `1`=正常 |
| enabled | TINYINT(4) NOT NULL DEFAULT 1 | 📋 `0`=禁用 `1`=启用 |
| test_status | TINYINT(4) NOT NULL DEFAULT 1 | 📋 `1`=未测试 `2`=通过 `3`=失败 |
| gmt_create / gmt_modified | DATETIME | 时间戳 |
| creator / modifier | VARCHAR(64) | 操作者 |

---

### 12 provider — 模型提供商

LLM 提供商配置，统一管理 API 凭证与协议。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| provider | VARCHAR(64) UNIQUE NOT NULL | 提供商 code（8 位随机或内置） |
| 🔗 workspace_id | VARCHAR(64) NOT NULL | 工作空间 |
| name | VARCHAR(255) NOT NULL | 显示名称 |
| description | VARCHAR(4096) | 描述 |
| icon | VARCHAR(255) | 图标 URL |
| protocol | VARCHAR(64) DEFAULT 'openai' | 📋 `openai` / 自定义 |
| enable | TINYINT(1) | 是否启用 |
| supported_model_types | TEXT | 支持的模型类型列表（逗号分隔：llm,embedding,image） |
| credential | TEXT | 凭证 JSON（api_key 经 RSA 加密，endpoint） |
| source | VARCHAR(64) | 📋 `custom` / 内置 |
| gmt_create / gmt_modified | DATETIME | 时间戳 |
| creator / modifier | VARCHAR(64) | 操作者 |

---

### 13 model — 模型

提供商下的具体模型配置。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| model_id | VARCHAR(64) NOT NULL | 模型标识符（如 `qwen-max`） |
| 🔗 provider | VARCHAR(64) NOT NULL | 所属提供商（→ provider.provider） |
| 🔗 workspace_id | VARCHAR(64) NOT NULL | 工作空间 |
| name | VARCHAR(255) NOT NULL | 显示名称 |
| type | VARCHAR(64) NOT NULL | 📋 `llm` / `embedding` / `image` |
| mode | VARCHAR(64) | 📋 `chat` / `completion` |
| enable | TINYINT(1) | 是否启用 |
| tags | VARCHAR(255) | 标签（逗号分隔） |
| icon | VARCHAR(255) | 图标 |
| source | VARCHAR(64) | 来源 |
| gmt_create / gmt_modified | DATETIME | 时间戳 |
| creator / modifier | VARCHAR(64) | 操作者 |

---

### 14 mcp_server — MCP 服务

Model Context Protocol 服务注册，供 Agent 动态调用外部工具。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| server_code | VARCHAR(64) UNIQUE NOT NULL | 业务主键 |
| 🔗 workspace_id | VARCHAR(64) | 工作空间 |
| 🔗 account_id | VARCHAR(64) | 所属账号 |
| name | VARCHAR(64) NOT NULL | 服务名称 |
| description | VARCHAR(1024) | 描述 |
| type | VARCHAR(32) NOT NULL | 📋 `OFFICIAL` / `CUSTOMER` |
| deploy_env | VARCHAR(16) | 📋 `local` / `remote` |
| install_type | VARCHAR(32) | 📋 `npx` / `uvx` / `sse` |
| deploy_config | TEXT NOT NULL | 部署配置 JSON（命令、环境变量、端口） |
| detail_config | TEXT | 详细配置（tools 定义等） |
| host | VARCHAR(1024) | 服务地址 |
| source | VARCHAR(128) | 来源 |
| biz_type | VARCHAR(512) | 业务类型标签 |
| status | TINYINT NOT NULL | 📋 `0`=禁用 `1`=正常 `3`=已删除 |
| gmt_create / gmt_modified | DATETIME | 时间戳 |

---

### 15 agent_schema — Agent Schema

Agent 的 YAML Schema 定义，描述输入输出契约。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| agent_id | VARCHAR(64) UNIQUE NOT NULL | 业务主键 |
| 🔗 workspace_id | VARCHAR(64) NOT NULL | 工作空间 |
| name | VARCHAR(255) NOT NULL | Schema 名称 |
| description | VARCHAR(4096) | 描述 |
| type | VARCHAR(64) | 📋 Agent 类型枚举 |
| instruction | TEXT | 系统指令 |
| input_keys | TEXT | 输入参数键列表 JSON |
| output_key | VARCHAR(255) | 输出键 |
| handle | VARCHAR(255) | 处理器标识 |
| sub_agents | TEXT | 子 Agent 列表 JSON |
| yaml_schema | LONGTEXT | 完整 YAML Schema |
| status | VARCHAR(64) | 📋 Agent 状态枚举 |
| enabled | TINYINT(1) | 是否启用 |
| gmt_create / gmt_modified | DATETIME | 时间戳 |
| creator / modifier | VARCHAR(64) | 操作者 |

---

## agentscope schema

### 16 prompt — Prompt

Prompt 的顶层实体，以 promptKey 作为业务标识。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| prompt_key | VARCHAR(255) UNIQUE NOT NULL | 业务主键（全局唯一标识） |
| prompt_desc | VARCHAR(255) | 描述 |
| latest_version | VARCHAR(32) | 当前最新版本号 |
| tags | VARCHAR(255) | 标签（逗号分隔） |
| create_time / update_time | DATETIME(3) | 时间戳（精确到毫秒） |

---

### 17 prompt_version — Prompt 版本

每个 Prompt 的版本快照，包含模板内容与调试参数。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| 🔗 prompt_key | VARCHAR(255) NOT NULL | 所属 Prompt（→ prompt.prompt_key） |
| version | VARCHAR(32) NOT NULL | 版本号（如 `v1`, `v1.0.1`） |
| template | LONGTEXT | Prompt 模板内容（支持 `{{variable}}` 占位） |
| variables | LONGTEXT | 变量参数列表 JSON |
| model_config | LONGTEXT | 调试用模型参数 JSON（modelId、temperature、max_tokens） |
| status | VARCHAR(32) NOT NULL DEFAULT 'pre' | 📋 `pre`=预发布 `release`=正式版本 |
| previous_version | VARCHAR(32) | 前置版本（用于 diff 对比） |
| version_desc | VARCHAR(255) | 版本说明 |
| create_time | DATETIME(3) | 创建时间 |

> 唯一索引：`(prompt_key, version)`

---

### 18 prompt_build_template — Prompt 模板库

系统内置的可复用 Prompt 脚手架（不归属用户，全局共享）。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| prompt_template_key | VARCHAR(255) UNIQUE NOT NULL | 模板唯一 key |
| template_desc | VARCHAR(255) | 模板描述 |
| template | LONGTEXT | 模板内容（含 `{{变量}}` 占位） |
| variables | LONGTEXT | 变量名列表（逗号分隔） |
| tags | VARCHAR(255) | 分类标签 |
| model_config | LONGTEXT | 推荐模型参数 JSON |

---

### 19 model_config — 模型配置

评估平台专用的模型配置（独立于 Builder 的 provider/model 体系）。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT NOT NULL AUTO_INCREMENT | 物理主键 |
| name | VARCHAR(100) NOT NULL UNIQUE | 配置名称 |
| provider | VARCHAR(50) NOT NULL | 提供商标识（openai / azure 等） |
| model_name | VARCHAR(100) NOT NULL | 模型标识符 |
| base_url | VARCHAR(500) NOT NULL | 服务地址 |
| api_key | VARCHAR(500) NOT NULL | API 密钥 |
| default_parameters | JSON | 默认参数 JSON |
| supported_parameters | JSON | 支持参数定义 JSON |
| status | TINYINT NOT NULL DEFAULT 1 | 📋 `0`=禁用 `1`=启用 |
| deleted | TINYINT(1) NOT NULL DEFAULT 0 | 逻辑删除标志 |
| create_time / update_time | DATETIME | 时间戳 |

---

### 20 dataset — 数据集

评估数据集的顶层实体。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| name | VARCHAR(255) NOT NULL | 数据集名称 |
| description | TEXT | 描述 |
| columns_config | LONGTEXT | 列结构配置 JSON（字段名、类型、用途） |
| deleted | TINYINT(1) NOT NULL DEFAULT 0 | 逻辑删除标志 |
| create_time / update_time | DATETIME | 时间戳 |

---

### 21 dataset_version — 数据集版本

数据集的版本快照，记录版本与实验的关联。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| 🔗 dataset_id | BIGINT UNSIGNED NOT NULL | 所属数据集（→ dataset.id，CASCADE DELETE） |
| version | VARCHAR(32) NOT NULL | 版本号 |
| description | TEXT | 版本描述 |
| data_count | INT NOT NULL DEFAULT 0 | 该版本数据项数量 |
| status | VARCHAR(32) NOT NULL DEFAULT 'DRAFT' | 📋 `DRAFT` / `PUBLISHED` / `ARCHIVED` |
| experiments | TEXT | 关联实验 ID 列表（JSON） |
| dataset_items | TEXT | 数据项 ID 列表（JSON） |
| create_time / update_time | DATETIME | 时间戳 |

> 唯一约束：`(dataset_id, version)`

---

### 22 dataset_item — 数据项

数据集中的单条测试用例。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| 🔗 dataset_id | BIGINT UNSIGNED NOT NULL | 所属数据集（→ dataset.id，CASCADE DELETE） |
| columns_config | LONGTEXT | 本条数据的列结构覆盖 JSON |
| data_content | LONGTEXT NOT NULL | 数据内容 JSON（input / reference_output 等） |
| deleted | TINYINT(1) NOT NULL DEFAULT 0 | 逻辑删除标志 |
| create_time / update_time | DATETIME | 时间戳 |

---

### 23 evaluator — 评估器

评估器的顶层实体。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| name | VARCHAR(255) NOT NULL | 评估器名称 |
| description | TEXT | 描述 |
| deleted | TINYINT(1) NOT NULL DEFAULT 0 | 逻辑删除标志 |
| create_time / update_time | DATETIME | 时间戳 |

---

### 24 evaluator_version — 评估器版本

评估器的版本快照，包含评估 Prompt 和模型配置。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| 🔗 evaluator_id | BIGINT UNSIGNED NOT NULL | 所属评估器（→ evaluator.id，CASCADE DELETE） |
| version | VARCHAR(32) NOT NULL | 版本号 |
| description | TEXT | 描述 |
| model_config | TEXT NOT NULL | 评估用模型配置 JSON |
| prompt | LONGTEXT | 评估 Prompt 内容 |
| variables | LONGTEXT | 变量参数列表 JSON |
| status | VARCHAR(32) | 📋 `DRAFT` / `PUBLISHED` / `ARCHIVED` |
| experiments | TEXT | 关联实验 ID 列表（JSON） |
| create_time / update_time | DATETIME | 时间戳 |

> 唯一约束：`(evaluator_id, version)`

---

### 25 evaluator_template — 评估器模板库

系统内置评估器脚手架（文本相似度、代码质量、情感分析等）。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| evaluator_template_key | VARCHAR(255) UNIQUE NOT NULL | 模板唯一 key |
| template_desc | VARCHAR(255) | 描述 |
| template | LONGTEXT | 评估 Prompt 模板 |
| variables | LONGTEXT | 变量参数名列表 |
| model_config | LONGTEXT | 推荐模型参数 JSON |

---

### 26 experiment — 实验

将数据集版本与评估器版本绑定，执行批量自动化评估。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| name | VARCHAR(255) NOT NULL | 实验名称 |
| description | TEXT | 描述 |
| 🔗 dataset_id | BIGINT UNSIGNED NOT NULL | 使用的数据集 |
| 🔗 dataset_version_id | BIGINT UNSIGNED NOT NULL | 使用的数据集版本 |
| dataset_version | VARCHAR(32) NOT NULL | 版本号快照（冗余） |
| evaluation_object_config | LONGTEXT | 被评估对象配置 JSON（promptKey、version、模型参数） |
| evaluator_config | TEXT NOT NULL | 评估器配置 JSON（evaluatorId、evaluatorVersionId 列表） |
| status | VARCHAR(32) NOT NULL DEFAULT 'DRAFT' | 📋 `DRAFT` / `RUNNING` / `COMPLETED` / `FAILED` / `STOPPED` |
| progress | INT(3) NOT NULL DEFAULT 0 | 进度百分比 0–100 |
| complete_time | DATETIME | 完成时间 |
| create_time / update_time | DATETIME | 时间戳 |

---

### 27 experiment_result — 实验结果

每条数据项 × 每个评估器版本的评分记录。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| 🔗 experiment_id | BIGINT UNSIGNED NOT NULL | 所属实验（→ experiment.id） |
| 🔗 evaluator_version_id | BIGINT UNSIGNED NOT NULL | 使用的评估器版本（→ evaluator_version.id） |
| input | LONGTEXT NOT NULL | 输入内容 |
| actual_output | LONGTEXT NOT NULL | 被评估对象的实际输出 |
| reference_output | LONGTEXT | 参考输出（黄金答案） |
| score | DECIMAL(3,2) | 评分 0.00–1.00 |
| reason | TEXT | 评分理由 |
| evaluation_time | DATETIME | 评估执行时间 |
| create_time / update_time | DATETIME | 时间戳 |

---

## 枚举汇总

| 枚举 | 值 |
|------|----|
| account.type | `basic` / `admin` |
| account.status | `0`=已删除 `1`=正常 |
| application.type | `agent` / `workflow` |
| application.status | `0`=已删除 `1`=草稿 `2`=已发布 `3`=发布后编辑中 |
| document.type | `file` / `url` |
| document.index_status | `1`=待处理 `2`=处理中 `3`=已完成 |
| plugin.type | `official` / `custom` |
| tool.test_status | `1`=未测试 `2`=通过 `3`=失败 |
| mcp_server.type | `OFFICIAL` / `CUSTOMER` |
| mcp_server.install_type | `npx` / `uvx` / `sse` |
| prompt_version.status | `pre`=预发布 `release`=正式 |
| dataset_version.status | `DRAFT` / `PUBLISHED` / `ARCHIVED` |
| evaluator_version.status | `DRAFT` / `PUBLISHED` / `ARCHIVED` |
| experiment.status | `DRAFT` / `RUNNING` / `COMPLETED` / `FAILED` / `STOPPED` |
| model_config.status | `0`=禁用 `1`=启用 |
