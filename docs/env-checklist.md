# 环境依赖清单

> 来源：`docker/middleware/docker-compose.yaml`、`application.yml`、`elasticsearch.yml`、`pom.xml`、`CONFIGURATION.md`。
> 所有默认值对应 `start.sh` / `docker/middleware/run.sh` 启动的本地 Docker Compose 环境。

---

## 运行时依赖总览

| 依赖 | 版本 | 默认端口 | 是否必须 |
|------|------|---------|---------|
| Java | 17+ | — | 是 |
| Maven | 3.8+ | — | 是（构建） |
| MySQL | 8.0.35 | 3306 | 是 |
| Redis | 7.2.5 | 6379 | 是 |
| Elasticsearch | 9.1.2 | 9200 / 9300 | 是 |
| RocketMQ | 5.3.2 | 9876 / 18080 / 18081 | 是 |
| Nacos | latest（2.x） | 8848 / 9848 | 是 |
| LoongCollector | 3.1.4 | 4318（OTLP HTTP） | 可选* |
| Kibana | 9.1.2 | 5601 | 可选* |
| AI 模型 API | — | — | 是 |

> *LoongCollector 和 Kibana 仅可观测性功能需要；去掉后核心业务功能（Prompt/Dataset/Experiment/App）正常运行，但链路追踪页面无数据。

---

## 1. Java

**版本要求：** 17+（`pom.xml`: `java.version=17`，Spring Boot 3.3.6 强制要求）

**构建工具：** Maven 3.8+

**初始化要求：** 无

---

## 2. MySQL

**镜像：** `sca-registry.cn-hangzhou.cr.aliyuncs.com/dubbo/mysql:8.0.35`（等同官方 MySQL 8.0.35）

**默认端口：** `3306`

**连接信息（默认）：**

| 项 | 值 |
|---|----|
| Host | `localhost` |
| Port | `3306` |
| 数据库 1 | `admin` |
| 数据库 2 | `agentscope`（agentscope-schema.sql 中隐含，同实例） |
| 用户名 | `admin` |
| 密码 | `admin` |
| Root 密码 | `root` |
| 时区 | `Asia/Shanghai` |

**覆盖环境变量：**

| 变量 | 对应配置 |
|------|---------|
| `SPRING_DATASOURCE_URL` | `spring.datasource.url` |
| `SPRING_DATASOURCE_USERNAME` | `spring.datasource.username` |
| `SPRING_DATASOURCE_PASSWORD` | `spring.datasource.password` |

**初始化要求：**

1. 创建数据库 `admin`（Docker Compose 通过 `mysql.env` 的 `MYSQL_DATABASE=admin` 自动创建）
2. 数据库 `agentscope` 需手动创建，或确保初始化脚本有权限创建：
   ```sql
   CREATE DATABASE IF NOT EXISTS agentscope DEFAULT CHARSET utf8mb4;
   ```
3. 执行建表 SQL：
   - `docker/middleware/init/mysql/admin-schema.sql` → `admin` 库（12 张表）
   - `docker/middleware/init/mysql/agentscope-schema.sql` → `agentscope` 库（15 张表）
4. Docker Compose 启动时自动执行 `/docker-entrypoint-initdb.d/` 下的 SQL 文件，手动部署需自行执行
5. JPA `ddl-auto=none`，不自动建表，**必须先执行 SQL 再启动应用**

**连接池配置（Druid）：** initial-size=5，min-idle=5，max-active=20（可按需调整）

---

## 3. Redis

**镜像：** `redis:7.2.5`

**默认端口：** `6379`

**连接信息（默认）：**

| 项 | 值 |
|---|----|
| Host | `localhost` |
| Port | `6379` |
| Database | `0` |
| 密码 | 无（默认无密码） |

**覆盖环境变量：**

| 变量 | 对应配置 |
|------|---------|
| `SPRING_REDIS_HOST` | `spring.data.redis.host` |
| `SPRING_REDIS_PORT` | `spring.data.redis.port` |
| `SPRING_REDIS_DATABASE` | `spring.data.redis.database` |

**客户端：** Redisson 3.27.2（`redisson-spring-boot-starter`）

**初始化要求：** 无，开箱即用。Redis 用于存储 `ChatSession`（Prompt 调试会话），TTL 由代码控制。

---

## 4. Elasticsearch

**镜像：** `docker.elastic.co/elasticsearch/elasticsearch:9.1.2`

**默认端口：** `9200`（HTTP REST）、`9300`（集群内部通信）

**连接信息（默认）：**

| 项 | 值 |
|---|----|
| URI | `http://localhost:9200` |
| 认证 | 无（`xpack.security.enabled=false`） |
| 连接超时 | 5000ms |
| 读取超时 | 60000ms |
| 最大连接数 | 100 |

**覆盖环境变量：**

| 变量 | 对应配置 |
|------|---------|
| `SPRING_ELASTICSEARCH_URIS` | Spring Data ES 客户端 URI |
| `SPRING_ELASTICSEARCH_URL` | 自定义 `ElasticsearchClient` URL |

**客户端：** `elasticsearch-java` 8.13.4（注意：服务端镜像是 9.1.2，客户端版本与服务端存在跨大版本差异，当前配置已验证可用）

**初始化要求（必须在应用启动前完成）：**

1. 创建 Ingest Pipeline `parsing_loongsuite_traces`（用于解析 OTel Trace 数据）
2. 创建索引 `loongsuite_traces`（含 mapping 定义和默认 pipeline 绑定）
3. Docker Compose 通过 `elasticsearch-init` 容器自动执行 `init/elasticsearch/init-indices.sh` 完成上述两步
4. 手动部署时，按 `init-indices.sh` 中的 curl 命令逐一执行
5. 向量存储（`DocumentChunk`）由 Spring AI `elasticsearch-store` 自动管理索引，无需手动创建

**JVM 配置：** `-Xms1g -Xmx1g`（Docker 环境），生产建议至少 4GB

---

## 5. RocketMQ

**镜像：** `apache/rocketmq:5.3.2`（NameServer + Broker + Proxy 三个容器）

**端口：**

| 组件 | 端口 | 用途 |
|------|------|------|
| NameServer | `9876` | 服务发现 |
| Broker | `10909` / `10911` / `10912` | 消息存储 |
| Proxy（gRPC） | `18080` | 应用连接端口（应用配置此端口） |
| Proxy（Remoting） | `18081` | 管理端口 |

**连接信息（应用侧）：**

| 项 | 值 |
|---|----|
| Endpoints | `localhost:18080`（连 Proxy，非 NameServer） |
| Cluster | `DefaultCluster` |

**覆盖环境变量：**

| 变量 | 对应配置 |
|------|---------|
| `ROCKETMQ_ENDPOINTS` | `rocketmq.endpoints` |
| `ROCKETMQ_DOCUMENT_INDEX_TOPIC` | `rocketmq.document-index-topic` |
| `ROCKETMQ_DOCUMENT_INDEX_GROUP` | `rocketmq.document_index_group` |

**客户端：** `rocketmq-client-java` 5.0.7

**初始化要求（必须在应用启动前完成）：**

1. 创建 Topic：
   ```bash
   sh mqadmin updateTopic -n rmq_namesrv:9876 \
     -t topic_saa_studio_document_index \
     -c DefaultCluster \
     -a +message.type=NORMAL
   ```
2. 创建 Consumer Group：
   ```bash
   sh mqadmin updateSubGroup -n rmq_namesrv:9876 \
     -g group_saa_studio_document_index \
     -c DefaultCluster
   ```
3. Docker Compose 通过 `init-topic` 容器在 Broker 就绪后自动完成（等待约 60s）
4. 手动部署时进入 Broker 容器执行上述命令，或通过 RocketMQ Dashboard 创建

**注意：** 应用启动时若 Topic 不存在，文档索引功能（知识库 RAG 管道）会启动失败但不影响其他模块。

---

## 6. Nacos

**镜像：** `nacos/nacos-server:latest`（建议锁定到 2.x，当前 latest 对应 2.x）

**端口：**

| 端口 | 用途 |
|------|------|
| `8848` | HTTP API / Console（宿主机映射：`7848→8848`、`8848→9848`，注意 Compose 中端口有偏移）|
| `9848` | gRPC（客户端连接） |

> Docker Compose 实际宿主机端口：`7080→8080`（Console UI）、`7848→8848`（HTTP API）、`8848→9848`（gRPC）。应用配置的 `8848` 是容器内端口，本地直接访问用 `7848`。

**连接信息（应用侧）：**

| 项 | 值 |
|---|----|
| server-addr | `localhost:8848` |
| 认证 Key | `admin` |
| 认证 Value | `admin` |
| Auth Token | 见 `docker-compose.yaml` `NACOS_AUTH_TOKEN` |

**覆盖环境变量：**

| 变量 | 对应配置 |
|------|---------|
| `NACOS_SERVER_ADDR` | `nacos.server-addr` |

**客户端版本（pom 中）：** `nacos.version=2023.0.3.3`（Spring Cloud Alibaba Nacos）

**初始化要求：**

1. 以 standalone 模式启动即可，无需集群配置
2. **不需要**预建 Namespace / Group / DataId，应用启动后自动向 Nacos 推送 Prompt 配置
3. 如外部 Agent 应用需订阅 Prompt，在 Agent 侧配置相同的 `nacos.server-addr` 即可
4. 数据持久化目录：`docker/middleware/nacos/data`（本地 Docker）

---

## 7. LoongCollector（可观测性，可选）

**镜像：** `sls-opensource-registry.cn-shanghai.cr.aliyuncs.com/loongcollector-community-edition/loongcollector:3.1.4`

**默认端口：** `4318`（OTLP HTTP，接收应用 Trace 数据）

**连接信息：**

| 项 | 值 |
|---|----|
| OTLP Endpoint | `http://localhost:4318/v1/traces` |
| 下游 ES 地址 | `http://elasticsearch:9200`（Docker 内网） |
| 写入索引 | `loongsuite_traces` |

**覆盖环境变量：**

| 变量 | 对应配置 |
|------|---------|
| `MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT` | `management.otlp.tracing.export.endpoint` |

**初始化要求：**

1. 依赖 Elasticsearch `loongsuite_traces` 索引和 `parsing_loongsuite_traces` Pipeline 已创建（见 ES 初始化）
2. Pipeline 配置文件：`docker/middleware/conf/loongcollector/otlp_pipeline.yaml`，不需修改即可用
3. **跳过此组件的影响**：可观测性页面（Trace 列表、服务统计）无数据，其他功能不受影响；需同时将 `management.otlp.tracing.export.enabled` 设为 `false` 避免应用启动时连接报错

---

## 8. Kibana（可选）

**镜像：** `docker.elastic.co/kibana/kibana:9.1.2`

**默认端口：** `5601`

**用途：** 直接查询 `loongsuite_traces` 索引，开发调试用，非应用运行必须项。

**初始化要求：** 无，连接同一 Elasticsearch 实例自动可用。

---

## 9. AI 模型 API

应用调用外部 AI 模型，需至少配置一个 Provider 的 API Key。

**配置文件：** `spring-ai-alibaba-admin-server-start/model-config.yaml`（参考同目录模板）

| Provider | 模板文件 | 获取 Key |
|----------|---------|---------|
| DashScope（阿里云百炼） | `model-config-dashscope.yaml` | Alibaba Cloud Bailian Console |
| OpenAI | `model-config-openai.yaml` | platform.openai.com |
| DeepSeek | `model-config-deepseek.yaml` | platform.deepseek.com |

**初始化要求：**

1. 复制对应模板为 `model-config.yaml`，填入 API Key
2. API Key 仅写入本地文件，不提交到 git（已在 `.gitignore` 中排除）
3. 应用启动后可通过 Console 动态添加/切换 Provider 和模型，无需重启

---

## 快速检查脚本

启动前可用以下命令逐一验证中间件就绪状态：

```bash
# MySQL
mysqladmin ping -h 127.0.0.1 -u admin -padmin 2>/dev/null && echo "MySQL OK"

# Redis
redis-cli ping && echo "Redis OK"

# Elasticsearch
curl -s http://localhost:9200/_cluster/health | grep -E 'green|yellow' && echo "ES OK"

# Nacos
curl -s http://localhost:7848/nacos/v1/console/health/liveness && echo "Nacos OK"

# RocketMQ Proxy
curl -s http://localhost:18081/metrics | head -1 && echo "RocketMQ Proxy OK"

# LoongCollector（可选）
curl -s http://localhost:4318/ && echo "LoongCollector OK"
```
