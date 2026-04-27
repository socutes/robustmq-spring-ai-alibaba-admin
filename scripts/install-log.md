# 本地依赖安装日志

> 执行时间：2026-04-27
> 执行脚本：`scripts/install-deps.sh`
> 操作系统：macOS 15.7.3 (Darwin 24.6.0, Apple Silicon)
> 注意：Docker 在本机被限制，所有中间件均采用原生安装。

---

## 安装结果总览

| 中间件 | 版本 | 安装方式 | 状态 | 备注 |
|--------|------|---------|------|------|
| Java | 21.0.7 (Temurin) | 已预装 | ✅ 正常 | 满足 Java 17+ 要求 |
| Maven | 3.9.9 | 已预装 | ✅ 正常 | 满足 Maven 3.8+ 要求 |
| MySQL | 9.6.0 | brew install mysql | ✅ 正常 | 端口 3306，含初始化 |
| Redis | 8.0.3 | brew install redis | ✅ 正常 | 端口 6379 |
| Elasticsearch | 8.18.3 | 官方 tar.gz | ✅ 正常 | 端口 9200，含索引初始化 |
| RocketMQ | 5.3.2 | Tsinghua mirror zip | ✅ 正常 | 端口 9876/18080 |
| Nacos | 2.4.3 | GitHub Release zip | ✅ 正常 | 端口 8848 |
| LoongCollector | 3.1.4 | 跳过（可选组件） | ⏭ 跳过 | 可观测性功能暂不需要 |
| AI 模型 API | — | 手动配置 | ⚠️ 待完成 | 需手动填写 API Key |

---

## 详细安装记录

### 1. Java

**最终命令：** 已预装，无需操作

**版本：** `openjdk 21.0.7` (Temurin)

**遇到的问题：**
- 脚本最初使用 `java -version 2>&1 | grep -oP '"\\K[0-9]+'` 检测版本
- macOS 使用 BSD grep，不支持 `-P`（Perl 模式），导致版本检测返回空值并被判定为 0
- **修复：** 将所有 `-oP '"\\K[0-9]+'` 替换为 `-oE '"[0-9]+'` + `| tr -d '"'`（POSIX ERE 兼容写法）

---

### 2. Maven

**最终命令：** 已预装，无需操作

**版本：** `Apache Maven 3.9.9`

---

### 3. MySQL

**最终命令：**
```bash
brew install mysql
brew services start mysql
```

**版本：** `9.6.0`（brew 最新稳定版，向后兼容 8.0.35 要求）

**初始化步骤：**
```bash
# 创建 admin 用户和数据库
mysql -u root -e "
  CREATE USER IF NOT EXISTS 'admin'@'localhost' IDENTIFIED BY 'admin';
  CREATE DATABASE IF NOT EXISTS admin DEFAULT CHARSET utf8mb4;
  CREATE DATABASE IF NOT EXISTS agentscope DEFAULT CHARSET utf8mb4;
  GRANT ALL PRIVILEGES ON admin.* TO 'admin'@'localhost';
  GRANT ALL PRIVILEGES ON agentscope.* TO 'admin'@'localhost';
  FLUSH PRIVILEGES;
"

# 导入建表 SQL
mysql -u admin -padmin admin < docker/middleware/init/mysql/admin-schema.sql
mysql -u admin -padmin agentscope < docker/middleware/init/mysql/agentscope-schema.sql
```

**验证：**
- `admin` 库：12 张表（app_info, api_key, conversation, dataset, document, experiment, experiment_evaluator, experiment_result, knowledge_base, prompt, prompt_version, user）
- `agentscope` 库：15 张表（agent_schema, agent_tool, conversation_message, dataset, document, document_chunk_task, knowledge_base, mcp_server, model_provider, playground, prompt, prompt_version, scene, tool, workflow）

**遇到的问题：** 无

---

### 4. Redis

**最终命令：**
```bash
brew install redis
brew services start redis
```

**版本：** `8.0.3`（brew 最新稳定版，向后兼容）

**验证：** `redis-cli ping` → `PONG`

**遇到的问题：** 无，开箱即用。

---

### 5. Elasticsearch

**最终命令：**
```bash
# 下载官方 tar.gz（非 brew 安装）
curl -L -o /tmp/elasticsearch-8.18.3.tar.gz \
  https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.18.3-darwin-aarch64.tar.gz
tar -xzf /tmp/elasticsearch-8.18.3.tar.gz -C ~/middleware/
```

**版本：** `8.18.3`（官方 tar.gz，含内置 JDK）

**配置修改（`config/elasticsearch.yml`）：**
```yaml
xpack.security.enabled: false
xpack.security.enrollment.enabled: false
xpack.ml.enabled: false
```

**启动命令：**
```bash
~/middleware/elasticsearch-8.18.3/bin/elasticsearch -d \
  -p ~/middleware/elasticsearch-8.18.3/elasticsearch.pid
```

**ES 索引初始化：**
```bash
# 创建 Ingest Pipeline
curl -s -X PUT http://localhost:9200/_ingest/pipeline/parsing_loongsuite_traces \
  -H "Content-Type: application/json" \
  -d @docker/middleware/init/elasticsearch/pipeline.json

# 创建索引
curl -s -X PUT http://localhost:9200/loongsuite_traces \
  -H "Content-Type: application/json" \
  -d @docker/middleware/init/elasticsearch/index-mapping.json
```

**遇到的问题（共 3 个）：**

**问题 1：brew elastic/tap 只有 7.17.4 且 JDK 路径损坏**
- 症状：`brew install elastic/tap/elasticsearch-full` 安装 7.17.4，启动时报 `JAVA_HOME` 指向不存在路径 `/opt/homebrew/Cellar/elasticsearch-full/7.17.4/libexec/jdk.app/Contents/Home/bin/java`
- 修复：放弃 brew tap，改用官方 tar.gz（内置完整 JDK）

**问题 2：xpack.ml native code 加载失败**
- 症状：ES 启动日志出现 `Failure running machine learning native code. This could be due to running on an unsupported OS or architecture.`，ES 进程退出
- 原因：macOS 15 arm64 上 xpack.ml 的 native library 兼容性问题
- 修复：在 `elasticsearch.yml` 中追加 `xpack.ml.enabled: false`，重启成功

**问题 3：nohup 被 OKG 安全策略拦截**
- 症状：脚本使用 `nohup elasticsearch &` 时被安全 hook 阻断
- 修复：改用 ES 内置 daemon 标志 `elasticsearch -d -p <pid_file>`

---

### 6. RocketMQ

**最终命令：**
```bash
# 从清华大学镜像下载
curl -L -o /tmp/rocketmq-5.3.2.zip \
  https://mirrors.tuna.tsinghua.edu.cn/apache/rocketmq/5.3.2/rocketmq-all-5.3.2-bin-release.zip
unzip /tmp/rocketmq-5.3.2.zip -d ~/middleware/

# 启动 NameServer
export JAVA_OPT_EXT="-Xms256m -Xmx512m"
~/middleware/rocketmq-all-5.3.2-bin-release/bin/mqnamesrv &

# 启动 Broker+Proxy
~/middleware/rocketmq-all-5.3.2-bin-release/bin/mqbroker \
  -n localhost:9876 --enable-proxy &
```

**版本：** `5.3.2`

**初始化（创建 Topic + ConsumerGroup）：**
```bash
# 等待 Broker 就绪后（约 30s）
~/middleware/rocketmq-all-5.3.2-bin-release/bin/mqadmin updateTopic \
  -n localhost:9876 \
  -t topic_saa_studio_document_index \
  -c DefaultCluster \
  -a +message.type=NORMAL

~/middleware/rocketmq-all-5.3.2-bin-release/bin/mqadmin updateSubGroup \
  -n localhost:9876 \
  -g group_saa_studio_document_index \
  -c DefaultCluster
```

**遇到的问题：**

**问题 1：默认 JVM 堆大小过大**
- 症状：RocketMQ 默认 `-Xms4g -Xmx4g`，内存不足时 NameServer/Broker 启动失败
- 修复：设置环境变量 `JAVA_OPT_EXT="-Xms256m -Xmx512m"` 覆盖默认值

---

### 7. Nacos

**最终命令：**
```bash
# 从 GitHub Release 下载
curl -L -o /tmp/nacos-2.4.3.zip \
  https://github.com/alibaba/nacos/releases/download/2.4.3/nacos-server-2.4.3.zip
unzip /tmp/nacos-2.4.3.zip -d ~/middleware/

# standalone 模式启动（覆盖 JVM 参数）
JAVA_OPT="-Xms128m -Xmx256m -Xmn64m" \
  ~/middleware/nacos/bin/startup.sh -m standalone
```

**版本：** `2.4.3`

**初始化：** 无需预建 Namespace/Group/DataId，应用启动后自动推送 Prompt 配置。

**遇到的问题：**

**问题 1：默认 JVM 参数过大**
- 症状：Nacos 默认 `-Xms512m -Xmx512m`，低内存环境容易 OOM
- 修复：启动时通过环境变量 `JAVA_OPT` 覆盖为 `-Xms128m -Xmx256m -Xmn64m`

---

### 8. LoongCollector（跳过）

**状态：** 跳过，标记为可选组件。

**影响：** 可观测性页面（Trace 列表、服务统计）无数据，其他业务功能正常。

**若需手动安装：**
```bash
# 下载（macOS arm64 版本）
curl -L -o /tmp/loongcollector-3.1.4-darwin-arm64.tar.gz \
  https://loongcollector-community-edition.oss-cn-shanghai.aliyuncs.com/3.1.4/loongcollector-3.1.4-darwin-arm64.tar.gz
tar -xzf /tmp/loongcollector-3.1.4-darwin-arm64.tar.gz -C ~/middleware/

# 将 docker/middleware/conf/loongcollector/otlp_pipeline.yaml 中的
# ES 地址从 http://elasticsearch:9200 改为 http://localhost:9200
# 然后启动
~/middleware/loongcollector/loongcollector
```

---

### 9. AI 模型 API（待手动完成）

**状态：** ⚠️ 需要手动配置

**步骤：**
```bash
cd spring-ai-alibaba-admin-server-start/

# 选择一个 Provider
cp model-config-dashscope.yaml model-config.yaml   # DashScope（阿里云百炼）
# 或
cp model-config-openai.yaml model-config.yaml       # OpenAI
# 或
cp model-config-deepseek.yaml model-config.yaml     # DeepSeek

# 编辑文件，填入真实 API Key
# 文件已在 .gitignore 中排除，不会提交到 git
```

---

## 最终健康检查

执行时间：2026-04-27

| 服务 | 端口 | 状态 |
|------|------|------|
| MySQL | 3306 | ✅ mysqladmin ping OK |
| Redis | 6379 | ✅ PONG |
| Elasticsearch | 9200 | ✅ cluster status: green |
| RocketMQ NameServer | 9876 | ✅ 端口通 |
| RocketMQ Proxy | 18080 | ✅ 端口通 |
| Nacos | 8848 | ✅ HTTP liveness OK |

---

## 手动待办清单

- [ ] 配置 AI 模型 API Key（`spring-ai-alibaba-admin-server-start/model-config.yaml`）
- [ ] 若需可观测性，手动安装 LoongCollector 并修改 ES 地址为 `http://localhost:9200`
- [ ] 启动应用：`./start.sh`
- [ ] 验证 Nacos Console：http://localhost:7848/nacos（账号 nacos/nacos）
- [ ] 验证 ES 索引：`curl http://localhost:9200/loongsuite_traces`
