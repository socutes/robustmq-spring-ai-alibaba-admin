# 依赖安装日志

> 执行时间：2026-05-12  
> 环境：macOS 15.7.3（arm64）/ Homebrew  
> 脚本：`scripts/install-deps.sh`

---

## 执行结论

**全部 6 项中间件一次通过，0 报错，0 需人工干预。**

所有服务在脚本运行前即已在本机以 native 进程运行（非 Docker），脚本以"检测到则跳过安装、仅补充初始化"策略幂等执行。

---

## 逐项记录

### 1 · Java

| 项目 | 值 |
|------|-----|
| 安装方式 | 已预装，无需操作 |
| 版本 | OpenJDK 21.0.7（Microsoft Build），满足 ≥17 要求 |
| 检测命令 | `java -version` |
| 问题 | 无 |

---

### 2 · MySQL

| 项目 | 值 |
|------|-----|
| 安装方式 | `brew install mysql`（已预装） |
| 实际版本 | 9.6.0（brew 最新稳定版，高于 checklist 要求的 8.0，向上兼容） |
| 启动方式 | `brew services start mysql`（已作为 LaunchAgent 自启动） |
| 端口 | 3306 |

**初始化执行情况：**

| 操作 | 结果 | 备注 |
|------|------|------|
| 创建 `admin` schema | 已存在，跳过 | 幂等 `CREATE DATABASE IF NOT EXISTS` |
| 创建 `agentscope` schema | 已存在，跳过 | 同上 |
| 创建用户 `admin@localhost` / `admin@%` | 已存在，跳过 | 幂等 `CREATE USER IF NOT EXISTS` |
| 导入 `admin-schema.sql` → agentscope 库 | WARN（表已存在） | 属正常，幂等导入 |
| 导入 `agentscope-schema.sql` → admin 库 | 成功 | |
| 最终 admin 库表数 | **27 张** | |
| 最终 agentscope 库表数 | **27 张** | |

**注意**（已在脚本内注释）：`admin-schema.sql` 内容是评估平台表（dataset/evaluator/experiment/prompt/model_config），需导入 `agentscope` 库；`agentscope-schema.sql` 是 Builder 平台表（account/workspace/application 等），需导入 `admin` 库。文件名与 schema 名相反，是项目历史设计，脚本已正确处理。

---

### 3 · Redis

| 项目 | 值 |
|------|-----|
| 安装方式 | `brew install redis`（已预装） |
| 实际版本 | 8.0.3（高于 checklist 要求的 7.x，向上兼容） |
| 启动方式 | `brew services start redis`（已自启动） |
| 端口 | 6379 |
| 连接验证 | `redis-cli ping` → `PONG` |
| 问题 | 无 |

---

### 4 · Elasticsearch

| 项目 | 值 |
|------|-----|
| 安装方式 | `brew install elastic/tap/elasticsearch-full`（已预装） |
| 实际版本 | 8.18.3（与 Java 客户端 8.13.4 同主版本，完全兼容） |
| 启动方式 | brew services 自启动 |
| 端口 | 9200（HTTP）、9300（集群） |
| Security | xpack.security.enabled=false（开发模式） |

**初始化执行情况：**

| 操作 | 结果 |
|------|------|
| Ingest Pipeline `parsing_loongsuite_traces` | 已存在，跳过 |
| Index `loongsuite_traces` | 已存在，跳过 |

**遇到的问题：无**。Pipeline 和 Index 在项目之前已初始化完成（ES 状态 yellow，是因为单节点无法分配副本分片，开发环境正常）。

---

### 5 · RocketMQ

| 项目 | 值 |
|------|-----|
| 安装方式 | 手动下载解压到 `~/rocketmq-5.3.2`（brew 无官方 tap） |
| 实际版本 | 5.3.2（与 checklist 完全一致） |
| 启动方式 | nohup 手动启动 NameServer + Broker + Proxy |
| 端口 | NameServer:9876、Broker:10911、Proxy gRPC:18080 |

**初始化执行情况：**

| 操作 | 结果 |
|------|------|
| Topic `topic_saa_studio_document_index` | 已存在，跳过 |
| ConsumerGroup `group_saa_studio_document_index` | 新建成功（`create subscription group to 192.168.0.31:10911 success`） |

**遇到的问题：无**。NameServer、Broker、Proxy 均已运行。ConsumerGroup 虽然之前 `consumerProgress` 查询报"No topic route"（因为没有 consumer 实际连接，是正常的），本次 `updateSubGroup` 直接成功。

---

### 6 · Nacos

| 项目 | 值 |
|------|-----|
| 安装方式 | 手动下载解压到 `~/nacos`（brew 无官方 tap） |
| 实际版本 | 2.4.3（与 checklist 完全一致） |
| 启动方式 | `bin/startup.sh -m standalone`，nohup 后台运行 |
| 端口 | HTTP:8848（直接进程端口），gRPC:9848 |

**端口说明**（与 checklist 的差异）：

checklist 中因参考 docker-compose 的端口映射写的是"宿主机 7848 → 容器 8848"，但本机是 native 进程，直接监听 **8848**。项目 `application.yml` 中 `NACOS_SERVER_ADDR` 默认值是 `localhost:8848`（容器内端口），与 native 进程端口一致，**无需修改应用配置**。

**遇到的问题：无**。

---

## 最终端口速查（本机实际）

| 服务 | 端口 | 状态 |
|------|------|------|
| MySQL | 3306 | ✓ 运行中 |
| Redis | 6379 | ✓ 运行中 |
| Elasticsearch | 9200 | ✓ 运行中 |
| RocketMQ NameServer | 9876 | ✓ 运行中 |
| RocketMQ Broker | 10911 | ✓ 运行中 |
| RocketMQ Proxy (gRPC) | 18080 | ✓ 运行中 |
| Nacos HTTP | 8848 | ✓ 运行中 |
| Nacos gRPC | 9848 | ✓ 运行中 |

---

## 与 env-checklist.md 的差异说明

| 项目 | Checklist 要求 | 实际版本 | 影响 |
|------|--------------|---------|------|
| MySQL | 8.0.35 | 9.6.0 | 向上兼容，无影响 |
| Redis | 7.2.5 | 8.0.3 | 向上兼容，无影响 |
| Elasticsearch | 客户端 8.13.4 / 服务端 9.1.2 建议 | 8.18.3 | 同主版本，完全兼容 |
| Nacos HTTP 端口 | 7848（docker 映射） | 8848（native 直接） | 应用默认配置 `localhost:8848` 正确对应，无需改动 |
| LoongCollector | 可选 | 未安装 | dev profile 已关闭 OTLP 导出，无影响 |
| Kibana | 可选 | 未安装 | 不影响运行 |
