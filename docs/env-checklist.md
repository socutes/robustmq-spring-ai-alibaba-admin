# 外部依赖环境清单

> 来源：`docker-compose.dev.yml` · `application.yml` · `pom.xml` · `init/` 脚本  
> 生成时间：2026-05-12

---

## 汇总表格

| # | 名称 | 版本要求 | 默认宿主机端口 | 连接信息（默认值） | 环境变量覆盖 | 初始化要求 | 是否必须 |
|---|------|---------|--------------|-------------------|-------------|-----------|---------|
| 1 | **MySQL** | 8.0（精确：8.0.35） | 3306 | `localhost:3306` user=`admin` pwd=`admin` schema=`admin` | `SPRING_DATASOURCE_URL` `SPRING_DATASOURCE_USERNAME` `SPRING_DATASOURCE_PASSWORD` | 建两个 schema；执行两份 DDL SQL | 必须 |
| 2 | **Redis** | 7（精确：7.2.5） | 6379 | `localhost:6379` db=`0`，无密码 | `SPRING_REDIS_HOST` `SPRING_REDIS_PORT` `SPRING_REDIS_DATABASE` | 无 | 必须 |
| 3 | **Elasticsearch** | 8（客户端 8.13.4；服务端 9.1.2 可兼容） | 9200（HTTP）9300（集群内部） | `http://localhost:9200`，无认证 | `SPRING_ELASTICSEARCH_URIS` `SPRING_ELASTICSEARCH_URL` | 创建 ingest pipeline + index（见下文） | 必须 |
| 4 | **RocketMQ** | 5（精确：5.3.2） | 18080（Proxy gRPC）9876（NameServer）10911（Broker） | `localhost:18080` | `ROCKETMQ_ENDPOINTS` `ROCKETMQ_DOCUMENT_INDEX_TOPIC` `ROCKETMQ_DOCUMENT_INDEX_GROUP` | 创建 Topic + ConsumerGroup（见下文） | 必须 |
| 5 | **Nacos** | 2（精确：2.4.3） | 7848（HTTP API/Console → 容器 8848）8848（gRPC → 容器 9848） | `localhost:7848` user=`nacos` pwd=`nacos` | `NACOS_SERVER_ADDR` | standalone 模式，无需额外配置命名空间 | 必须 |
| 6 | **LoongCollector** | 3（精确：3.1.4） | 4318（OTLP HTTP） | `http://localhost:4318/v1/traces` | `MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT` | 需 ES pipeline/index 已就绪；pipeline 配置挂载自 `docker/middleware/conf/loongcollector/` | 可选（dev 模式默认关闭） |
| 7 | **Kibana** | 9（精确：9.1.2） | 5601 | `http://localhost:5601` | — | 无（连接同一 ES 节点） | 可选（开发调试用） |
| 8 | **Java** | 17（LTS） | — | — | — | 无 | 必须（运行时） |
| 9 | **AI 模型 API** | — | — | DashScope / OpenAI / DeepSeek 等（HTTPS） | 见 `model-config.yaml` | 配置 API Key（见下文） | 必须（至少一个） |

---

## 1 · MySQL 8.0

### 连接信息

| 参数 | 默认值 |
|------|--------|
| Host | `localhost` |
| Port | `3306` |
| User | `admin` |
| Password | `admin` |
| Root Password | `root`（仅 Docker 容器使用） |
| 字符集 | `utf8mb4` / `utf8mb4_unicode_ci` |
| 时区 | `Asia/Shanghai`（`+8:00`） |

### 初始化要求

1. **建库**：需要两个 schema

   ```sql
   -- schema 1（由 docker MYSQL_DATABASE 自动创建）
   CREATE DATABASE IF NOT EXISTS admin DEFAULT CHARACTER SET utf8mb4;
   -- schema 2（由 init 容器补建）
   CREATE DATABASE IF NOT EXISTS agentscope DEFAULT CHARACTER SET utf8mb4;
   GRANT ALL PRIVILEGES ON agentscope.* TO 'admin'@'%';
   ```

2. **建表**：按顺序执行以下 DDL 文件（`docker-entrypoint-initdb.d` 首次启动自动执行）

   | 文件 | 目标 schema | 包含表 |
   |------|------------|--------|
   | `docker/middleware/init/mysql/admin-schema.sql` | `agentscope`（文件内含两个 schema 的表） | 见下 |
   | `docker/middleware/init/mysql/agentscope-schema.sql` | `admin`（Builder 平台表） | 见下 |

   > **注意**：两份 SQL 文件名与 schema 名**相反**，`admin-schema.sql` 实际建的是 agentscope 平台的表（dataset / evaluator / experiment / prompt / model_config），`agentscope-schema.sql` 建的是 Builder 平台的表（account / workspace / application 等）。导入前确认 `USE` 语句或手动指定目标 schema。

3. **慢查询配置**（来自 `docker/middleware/conf/mysql/my.cnf`）：慢查询日志开启，无需额外操作。

---

## 2 · Redis 7

### 连接信息

| 参数 | 默认值 |
|------|--------|
| Host | `localhost` |
| Port | `6379` |
| Database | `0` |
| 密码 | 无 |

### 初始化要求

无。Redisson 客户端（v3.27.2）启动时自动连接，用于分布式锁与会话缓存（`ChatSession`）。

---

## 3 · Elasticsearch 8/9

### 版本说明

- **Java 客户端**：`elasticsearch-java` 8.13.4（pom.xml 锁定）
- **服务端镜像**：9.1.2（docker-compose.dev.yml）
- ES 9.x 对 8.x 客户端保持向后兼容，生产建议对齐到 8.x 以严格匹配客户端版本

### 连接信息

| 参数 | 默认值 |
|------|--------|
| URI（Spring Boot） | `http://localhost:9200` |
| URI（自定义 ElasticsearchClient） | `http://localhost:9200` |
| 认证 | 无（`xpack.security.enabled=false`） |
| 连接超时 | 5000 ms |
| 读取超时 | 60000 ms |

### 初始化要求

首次启动前**必须**执行 `docker/middleware/init/elasticsearch/init-indices.sh`（docker-compose 中由 `elasticsearch-init` 容器自动执行）：

1. **创建 Ingest Pipeline**

   ```
   PUT /_ingest/pipeline/parsing_loongsuite_traces
   ```
   处理器：解析 `attribute` / `resource` / `links` / `logs` JSON 字段，计算 token usage。

2. **创建 Index**

   ```
   PUT /loongsuite_traces
   ```
   - 默认 pipeline：`parsing_loongsuite_traces`
   - 分片数：1，副本数：0（开发环境）
   - 用途：存储 OTel Trace Span（可观测性）；RAG DocumentChunk 向量数据也存此处

---

## 4 · RocketMQ 5

### 连接信息

| 组件 | 宿主机端口 | 说明 |
|------|-----------|------|
| NameServer | 9876 | 服务发现 |
| Broker | 10909 / 10911 / 10912 | 消息存储 |
| Proxy（gRPC） | 18080 | **应用连接此端口** |
| Proxy（remoting） | 18081 | 内部通信 |

应用配置：`rocketmq.endpoints=localhost:18080`

### 初始化要求

首次启动后**必须**创建（docker-compose 中由 `rmq-init-topic` 容器自动执行）：

1. **Topic**

   ```bash
   sh mqadmin updateTopic \
     -n rmq_namesrv:9876 \
     -t topic_saa_studio_document_index \
     -c DefaultCluster \
     -a +message.type=NORMAL
   ```

2. **ConsumerGroup**

   ```bash
   sh mqadmin updateSubGroup \
     -n rmq_namesrv:9876 \
     -g group_saa_studio_document_index \
     -c DefaultCluster
   ```

默认 Topic / Group 名可通过环境变量覆盖：`ROCKETMQ_DOCUMENT_INDEX_TOPIC` / `ROCKETMQ_DOCUMENT_INDEX_GROUP`。

---

## 5 · Nacos 2

### 连接信息

| 参数 | 默认值 | 说明 |
|------|--------|------|
| 宿主机 HTTP 端口 | `7848` | 映射容器 8848，控制台 + API |
| 宿主机 gRPC 端口 | `8848` | 映射容器 9848，客户端连接 |
| 应用配置地址 | `localhost:7848` | `NACOS_SERVER_ADDR` 环境变量 |
| 用户名 | `nacos` | |
| 密码 | `nacos` | |
| 模式 | `standalone` | 单节点，无需集群配置 |

### 初始化要求

- 无需手动创建命名空间，应用使用默认命名空间（`public`）
- Prompt 配置中心热加载通过 Nacos Config 实现，配置 Key 在运行时通过 Provider API 动态管理
- Console 地址：`http://localhost:7848/nacos`

---

## 6 · LoongCollector 3（可选）

### 连接信息

| 参数 | 值 |
|------|-----|
| OTLP HTTP 端口 | `4318` |
| 接收路径 | `/v1/traces` |
| 上报端（应用侧） | `http://localhost:4318/v1/traces` |

### 初始化要求

- 依赖 ES pipeline `parsing_loongsuite_traces` 和 index `loongsuite_traces` **已创建**
- pipeline 配置挂载自 `docker/middleware/conf/loongcollector/`（转发至 ES `loongsuite_traces` index）
- **本地开发关闭方式**：`application-dev.yml` 已将 `management.otlp.tracing.export.enabled=false`，不需要可观测性时直接使用 `dev` profile 即可

---

## 7 · Kibana 9（可选）

| 参数 | 值 |
|------|-----|
| 访问地址 | `http://localhost:5601` |
| 后端 ES | `http://elasticsearch:9200`（容器内网） |
| 认证 | 无（`xpack.security.enabled=false`） |

开发调试 ES 数据用，生产环境可不部署。

---

## 8 · Java 运行时

| 参数 | 值 |
|------|-----|
| 最低版本 | **Java 17** |
| 推荐版本 | Java 17 LTS |
| Maven | 3.6+ |
| Spring Boot | 3.3.6 |

---

## 9 · AI 模型 API

应用通过 Spring AI Alibaba（v1.0.0.3）统一适配多个模型提供商，凭证在运行时通过 Provider API 动态注册并经 RSA 加密入库，也可提前写入 `model-config.yaml`。

| 提供商 | API 端点 | 获取 Key |
|--------|---------|---------|
| DashScope（阿里云通义） | `https://dashscope.aliyuncs.com/compatible-mode/v1` | 阿里云控制台 |
| OpenAI | `https://api.openai.com/v1` | platform.openai.com |
| DeepSeek | `https://api.deepseek.com/v1` | platform.deepseek.com |

**首次配置步骤**：

```bash
# 从模板复制配置文件（gitignore，不提交）
cp spring-ai-alibaba-admin-server-start/model-config-dashscope.yaml \
   spring-ai-alibaba-admin-server-start/model-config.yaml
# 编辑 model-config.yaml，填入对应提供商的 API Key
```

或启动后通过 Builder 平台 → 模型提供商页面在线添加。

---

## 快速启动命令

```bash
# 1. 启动全部中间件（首次约 60–90s 完成初始化）
docker compose -f docker-compose.dev.yml up -d

# 2. 确认所有服务健康
docker compose -f docker-compose.dev.yml ps

# 3. 配置模型 API Key（首次）
cp spring-ai-alibaba-admin-server-start/model-config-dashscope.yaml \
   spring-ai-alibaba-admin-server-start/model-config.yaml
# 编辑填入 API Key

# 4. 启动后端（dev profile 关闭 OTLP 导出，避免 4318 连接报错）
cd spring-ai-alibaba-admin-server-start
mvn spring-boot:run -Dspring-boot.run.profiles=dev

# 5. 访问
# 管理台：  http://localhost:8080/admin
# Nacos：   http://localhost:7848/nacos   (nacos/nacos)
# Kibana：  http://localhost:5601
```

## 端口速查

| 服务 | 宿主机端口 | 用途 |
|------|-----------|------|
| 应用（Spring Boot） | 8080 | 管理台 / API |
| MySQL | 3306 | 数据库 |
| Redis | 6379 | 缓存 / 分布式锁 |
| Elasticsearch | 9200 | HTTP API |
| Elasticsearch | 9300 | 集群内部通信 |
| RocketMQ NameServer | 9876 | 服务发现 |
| RocketMQ Broker | 10911 | 消息存储 |
| RocketMQ Proxy（gRPC） | 18080 | **应用连接点** |
| Nacos HTTP/Console | 7848 | 配置中心 + 控制台 |
| Nacos gRPC | 8848 | 客户端连接 |
| LoongCollector OTLP | 4318 | Trace 数据接收（可选） |
| Kibana | 5601 | ES 可视化（可选） |
