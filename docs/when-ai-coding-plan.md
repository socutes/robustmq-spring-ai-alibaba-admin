# When × AI 编程实施计划

> 本文档回答一个问题：When 项目 3 周内，怎么用 AI Coding（Claude Code）完成 95% 以上的代码工作？
>
> 文档分两层：第一层是方法论——用什么 Claude Code 能力、以什么姿态驾驭 AI；第二层是执行——每周每天做什么、AI 做什么、人做什么。

## 一、为什么 When 适合 95% AI Coding

When 的技术栈和架构特征，让它在 AI Coding 上有几个天然优势。

**边界清晰，模块独立。** When 的核心模块分工明确：时间轮算法、ETCD 协调、Redis 持久化层、Sink 插件、gRPC 内部通信、HTTP 接入层、Web 管理台，每个模块有清晰的接口边界。这种结构天然适合用多个 Subagent 并行实现，各自不干扰。

**算法有标准实现可参考。** 多层时间轮、Raft 选举、Master-Slave 同步复制，这些都是有文献、有开源参考实现的经典算法。Claude 对这类有标准答案的工程问题极其熟悉，给清晰的 spec，它能输出工程级的实现。

**纯 Java，无奇怪依赖。** Java 17 + Spring Boot + Redis + ETCD，全是主流技术栈，Claude 的训练数据覆盖充分，不会因为冷门技术栈导致频繁幻觉。

**什么是人必须做的 5%？** 架构决策（etcd vs ZooKeeper、同步复制 vs Raft 的选型判断）、生产级性能调优（时间轮参数、Redis 连接池）、集群故障场景验证（脑裂、网络分区的真实测试），以及 code review 中发现 AI 无法自知的逻辑错误。这 5% 是工程判断力，不是写代码本身。

## 二、AI Coding 能力地图

3 周里用到的 Claude Code 能力，按使用频率排：

**每天都在用：**
- **CLAUDE.md**：项目级上下文注入。当前模块的架构约束、禁止触碰的边界、代码风格规范，放进 CLAUDE.md，每次对话都自动带上，不需要重复解释背景。
- **Plan Mode**：所有影响架构的决策先 plan，不可逆操作（删除文件、改核心接口）必须先 plan 再执行。Plan 出来人 review 一遍，确认没有偏差再放行。
- **Subagents**：多个独立模块并行实现时启动多个 Subagent，各自在自己的上下文里写代码，主对话做架构决策和集成 review。

**每周都会用到：**
- **Skills**：把"时间轮实现模式"、"gRPC service 定义模式"、"Redis Hash 存储模式"封装成可复用 Skill，下周或其他模块用到同类问题直接调，不重复写 prompt。
- **Slash Commands**：把高频 prompt 模板化。`/implement-sink`、`/write-test`、`/review-boundary` 这类命令，一次定义，后续一行触发。
- **Hooks**：PostToolUse hook 在每次 AI 改完代码后自动跑单元测试，测试失败直接打回给 AI 重改，不需要人工介入这个循环。
- **Permission System**：`.claude/settings.json` 里配置白名单，只允许 AI 在 `src/main/java/io/when/` 下写代码，禁止触碰 `pom.xml` 的依赖部分（防止 AI 随意引入未经评审的依赖）。

**关键节点用：**
- **Headless Mode**：把"跑集成测试 → 输出报告"做成 `claude -p "跑完整测试套件，输出失败列表"` 接进 CI，不需要人工触发。
- **Worktrees**：并行 Subagent 实现不同模块时，各 Subagent 在独立 worktree 分支上工作，主分支不被中间状态污染。

## 三、SDD 在 When 的展开方式

When 用 Spec-Driven Development，规格先行。具体展开为三层文档，每层有明确的消费者：

**需求层（when-requirements.md）**：人写，确认 What。延时精度 ±1s、10000 QPS、10s 故障切换，这些是硬指标，AI 实现时必须对照它们验收，不是"看着差不多就行"。

**技术方案层（when-technical-design.md）**：人主导，AI 辅助。架构图、模块划分、关键选型已在技术方案文档里确定，AI 实现代码时以这份文档为准，不能擅自更改选型（比如自作主张把 ETCD 换成 Zookeeper）。

**任务层（tasks.md，每周生成）**：Spec-Kit 生成，人 review。把本周要实现的功能拆成粒度适中的任务，每个任务有明确的输入输出和验收标准。任务粒度控制在"一个 Subagent 一个工作小时内能完成"，太粗会导致 AI 输出混乱，太细会产生大量上下文切换。

## 四、第 1 周：环境 + 骨架 + 单机核心

### 4.1 目标

第 1 周结束时，When 的单机版本跑通：接收 HTTP 请求 → 写入 Redis → 时间轮调度 → 到期触发 → HTTP Sink 投递出去。整个链路端到端可验证，有单元测试覆盖核心路径。

### 4.2 第 1 天：环境搭建 + CLAUDE.md + constitution.md

**人做：**
- 创建 GitHub 仓库，初始化 Maven 多模块结构（`when-core` / `when-api` / `when-sink` / `when-admin`）
- 决定包结构、命名规范、日志框架选型
- 配好本地开发环境：JDK 17、Redis、ETCD（docker-compose.dev.yml）

**AI 做（主对话）：**

```
任务：基于以下模块划分生成 Maven 多模块 POM 文件
- when-parent：父 POM，管理依赖版本
- when-core：时间轮、调度器、Sink 接口
- when-api：HTTP 接入层，Spring Boot 入口
- when-sink：Sink 插件实现（HTTP / Kafka / gRPC）
- when-admin：Web 管理台后端

依赖版本：
- Spring Boot 3.3
- Spring Data Redis（Lettuce）
- jetcd-core 0.7.x
- grpc-java 1.65.x
- protobuf-java 3.25.x
- Micrometer + Prometheus

输出：完整可构建的多模块 POM，确保 mvn clean package 能跑通
```

**写 CLAUDE.md：**

这是整个项目最重要的上下文文件，第 1 天就要写好，后续每周迭代。第一版至少包含：

```markdown
# When 项目上下文

## 核心原则
- When 是轻量独立的延时投递组件，不是消息队列，不做 worker 执行
- 最小依赖原则：不引入非必要依赖，每个新依赖需要说明理由
- 接入不依赖 SDK：对外接口只有 HTTP，不提供客户端 SDK

## 技术选型（已确定，不得改动）
- 调度：多层时间轮（秒/分/时/天 四层级联）
- 持久化：Redis（每条消息独立 Hash Key，禁止 ZSet 大 Key 模式）
- 集群协调：ETCD（Lease 注册 + Watch 发现 + CAS 选主）
- 副本：Master-Slave 同步复制（不用 Raft）
- 内部通信：gRPC（Protobuf 定义）
- 外部接入：HTTP/REST（Spring MVC）

## 禁区
- 禁止在 Redis 里用 ZSet 存延时消息（大 Key 问题）
- 禁止跨模块直接调用，必须通过接口
- 禁止在 when-core 模块引入 Spring 依赖（保持核心可测试性）

## 代码风格
- 所有公共接口写 Javadoc（说明为什么，不只是什么）
- 异常处理：业务异常用自定义 Exception，不吞异常
- 日志：关键路径用 INFO，异常用 ERROR，调试信息用 DEBUG（生产不开）
```

**写 constitution.md：**

比 CLAUDE.md 更高层的工程原则，用于在 AI 偏离时拉回：

```markdown
# When constitution.md

## 不可协商的约束
1. 时间轮触发精度：秒级精度通过 slot 推进保证，不依赖定时轮询
2. 消息不丢：写入 Redis ACK 后，Master 宕机消息不丢（同步复制保证）
3. 最小侵入：Sink 扩展不修改核心，SPI 机制插件化
4. 可运维性：所有配置通过 ETCD 动态下发，不重启服务

## AI 工作边界
- AI 可以自由实现接口约定范围内的逻辑
- AI 不得修改已确定的接口签名（需人工 review 后才能改）
- AI 不得更改 pom.xml 的依赖版本（统一在父 POM 管理）
```

### 4.3 第 2-3 天：时间轮 + Redis 持久化层（Subagents 并行）

这是技术复杂度最高的两天，启动两个并行 Subagent：

**Subagent 1：多层时间轮实现**

```
实现 When 的四层级联时间轮，放在 when-core/src/main/java/io/when/core/wheel/

技术要求（来自技术方案文档）：
- 四层结构：秒轮（60个slot，1s推进）/ 分轮（60个slot，1min推进）/ 时轮（24个slot，1h推进）/ 天轮（30个slot，1day推进）
- 长延时消息放高层slot，指针推进到该slot时降级到下层，最终在秒轮触发
- O(1) 触发复杂度，不依赖排序结构
- 线程安全：slot 读写加锁，指针推进和消息触发分离
- 支持消息取消：O(1) 从 bucket 中移除

接口设计：
public interface TimeWheel {
    void add(DelayMessage message);
    void cancel(String messageId);
    void start(); // 启动指针推进线程
    void stop();
    // 触发回调通过 Consumer<DelayMessage> 注入
}

输出：
1. 完整实现代码（含 bucket、slot、四层 wheel）
2. 单元测试：覆盖消息到期精度（误差 < 100ms）、取消、降级三个核心场景
3. 简单 benchmark：10万消息并发插入的吞吐测试
```

**Subagent 2：Redis 存储层实现**

```
实现 When 的 Redis 持久化层，放在 when-core/src/main/java/io/when/core/storage/

技术要求：
- 每条消息独立 Hash Key：key 格式 when:msg:{messageId}
- Hash 字段：body（消息内容）/ sinkType / sinkConfig / deliverAt / status / createAt / retryCount
- 时间轮索引：key 格式 when:wheel:{wheelId}:{slotIndex}，类型 Set，存 messageId 集合
- 禁止任何 ZSet 大 key 模式（constitution.md 硬约束）
- 写入必须是 pipeline 批量操作，不允许多次 round-trip

接口设计：
public interface MessageStore {
    void save(DelayMessage message);
    Optional<DelayMessage> get(String messageId);
    void updateStatus(String messageId, MessageStatus status);
    void delete(String messageId);
    List<String> getSlotMessages(String wheelId, int slotIndex);  // 恢复用
    void addToSlot(String wheelId, int slotIndex, String messageId);
    void removeFromSlot(String wheelId, int slotIndex, String messageId);
}

输出：
1. 完整实现代码（Redisson 客户端）
2. 单元测试（需要 testcontainers-redis，不 mock Redis）
3. 说明为什么每个 key 要这样设计（注释里写清楚）
```

主对话在两个 Subagent 完成后做集成：把 MessageStore 注入 TimeWheel，确保消息插入时同步写 Redis、指针推进时从 Redis 恢复状态（模拟宕机重启场景）。

### 4.4 第 4 天：HTTP 接入层 + HTTP Sink

**AI 做（一个对话完成）：**

```
实现 When 的 HTTP 接入层和第一个 Sink

HTTP 接入层（when-api 模块）：
三个 REST 接口：
- POST /api/v1/messages：提交延时消息，返回 messageId
  请求体：{ "delaySeconds": 300, "sinkType": "HTTP", "sinkConfig": {...}, "body": "..." }
  响应：{ "messageId": "uuid", "deliverAt": "2026-05-13T10:30:00Z" }
- DELETE /api/v1/messages/{id}：取消消息，返回 204 或 404
- GET /api/v1/messages/{id}：查询状态，返回 pending/delivered/cancelled/failed

HTTP Sink（when-sink 模块）：
- 接口定义：interface Sink { void deliver(DelayMessage msg) throws SinkException; }
- HTTP Sink 实现：到期后 POST 到 message 里的 webhookUrl，带 3 次重试（指数退避）
- SPI 机制：通过 Java SPI（ServiceLoader）加载 Sink 实现

统一错误响应格式：{ "code": "MSG_NOT_FOUND", "message": "消息不存在", "traceId": "..." }

输出：
1. Controller + Service + DTO 完整实现
2. Sink 接口 + HTTP Sink 实现
3. MockMvc 接口测试（不需要起真实 HTTP 服务）
```

### 4.5 第 5 天：端到端跑通 + Hooks 配置

**端到端跑通场景：**

用 AI 写一个集成测试，覆盖完整链路：提交一条 5 秒后到期的 HTTP Sink 消息 → 等待 6 秒 → 验证 Sink 收到了投递请求 → 查询消息状态变为 delivered。这是第 1 周的验收标准，跑通了才算完成。

**配置 Hooks（重要）：**

在 `.claude/settings.json` 里配：

```json
{
  "permissions": {
    "allow": ["Bash(mvn test:*)", "Read(**)", "Edit(src/**)", "Write(src/**)"],
    "deny": ["Edit(pom.xml)", "Bash(git push:*)"]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "cd /path/to/when && mvn test -pl when-core -q 2>&1 | tail -20" }]
      }
    ]
  }
}
```

效果：AI 每改一次代码，自动跑 `when-core` 的单元测试，失败结果直接反馈给 AI，AI 自行修复，不需要人工介入"改代码-跑测试-看结果-再改"的循环。

## 五、第 2 周：集群化 + gRPC + Kafka Sink

### 5.1 目标

第 2 周结束时，When 的集群化版本跑通：两个节点可以同时启动，通过 ETCD 完成注册和 Controller 选举，一个节点的时间轮 Master 宕机后 Slave 在 10s 内接管，Kafka Sink 可用。

### 5.2 第 1-2 天：ETCD 集群协调层（Subagents 并行）

**Subagent 1：节点注册与发现**

```
实现 When 的节点注册和集群发现，放在 when-core/src/main/java/io/when/core/cluster/

技术要求：
- 节点启动时向 ETCD 注册：key = when/nodes/{nodeId}，value = JSON 节点信息（IP / port / 状态）
- Lease TTL = 10s，节点进程活着时通过 keepAlive 自动续约
- Watch when/nodes/ 前缀，节点上线/下线时通知 ClusterChangeListener
- 节点信息结构：{ nodeId, host, port, grpcPort, startTime, status }

接口：
public interface ClusterRegistry {
    void register(NodeInfo self);
    void deregister();
    List<NodeInfo> getAliveNodes();
    void addChangeListener(ClusterChangeListener listener);
}

输出：完整实现 + 集成测试（需要真实 ETCD，用 testcontainers 起）
```

**Subagent 2：Controller 选举**

```
实现 When 的 Controller 选举，放在 when-core/src/main/java/io/when/core/cluster/

技术要求：
- 基于 ETCD 事务 CAS：所有节点争抢写 when/controller 这个 key，成功者成为 Controller
- Controller Lease TTL = 15s，Controller 存活时持续续约
- Controller 宕机后 Lease 过期，其他节点重新竞选
- Controller 职责：决定每个时间轮分配到哪个节点（Master），同时决定 Slave 节点

接口：
public interface ControllerElection {
    boolean tryBecomeController();
    boolean isController();
    Optional<String> getCurrentController(); // 返回当前 controller nodeId
    void addControllerChangeListener(ControllerChangeListener listener);
}

输出：完整实现 + 单元测试（模拟多节点竞选，验证只有一个 winner）
```

### 5.3 第 3 天：gRPC 内部通信 + Master-Slave 同步

这一天人工参与度最高，因为 gRPC Protobuf 定义决定了内部通信的数据结构，后续难以改动。先人工设计 proto 文件，再让 AI 实现。

**人设计 proto（30分钟，不让 AI 做）：**

```protobuf
// when-internal.proto
service WhenInternalService {
  rpc SyncMessage(SyncRequest) returns (SyncResponse);      // Master → Slave 同步消息
  rpc TransferWheel(TransferRequest) returns (TransferResponse); // 时间轮迁移
  rpc HeartBeat(HeartBeatRequest) returns (HeartBeatResponse);   // Master-Slave 心跳
}
```

**AI 实现（主对话）：**

```
基于以下 proto 文件实现 When 的 Master-Slave 同步复制

[粘贴 proto 文件内容]

技术要求：
1. gRPC Server：在节点启动时同时启动 gRPC Server（独立端口，默认 9090）
2. Master 写入消息时：先写本地 Redis，再 gRPC 同步给 Slave，Slave 确认后才返回 ACK
3. 超时处理：Slave 同步超时（500ms）时降级为异步（不能让写入 hang 住）
4. Slave 检测 Master 心跳：连续 3 次心跳超时触发 failover，通知 Controller 重新分配

输出：
1. gRPC Server/Client 完整实现
2. Master-Slave 同步写入流程（同步路径 + 降级路径）
3. Failover 触发逻辑
4. 集成测试：模拟 Master 宕机，验证 Slave 在 10s 内接管并继续正常投递
```

### 5.4 第 4 天：Kafka Sink + Sink SPI 验证

```
实现 Kafka Sink，验证 SPI 插件化机制

Kafka Sink（when-sink 模块）：
- 接收延时消息后，到期时把 message body 写入指定 Topic
- sinkConfig 格式：{ "bootstrapServers": "...", "topic": "...", "key": "..." }
- 使用 Kafka Producer（非 Spring Kafka，避免依赖 Spring 进 when-sink 模块）
- 支持幂等写入（enable.idempotence=true）

SPI 验证：
- META-INF/services/io.when.sink.Sink 文件里注册 HttpSink 和 KafkaSink
- SinkFactory 通过 ServiceLoader 动态加载，按 sinkType 字段路由到对应实现
- 验证：不修改核心代码，只添加新文件就能接入新 Sink

输出：
1. Kafka Sink 完整实现
2. SinkFactory + ServiceLoader 加载机制
3. 测试（用 testcontainers-kafka）
```

### 5.5 第 5 天：集群稳定性测试 + 混沌测试脚本

```
写一套混沌测试脚本，验证 When 集群在各类故障场景下的行为

测试场景：
1. 场景一：提交 1000 条延时消息，杀掉 Master 节点，验证 Slave 接管后所有消息正常投递，无重复无丢失
2. 场景二：提交 1000 条延时消息，杀掉 Controller 节点，验证新 Controller 选出后集群恢复正常
3. 场景三：网络分区模拟（用 iptables 隔离 Slave 节点），验证 Master 降级为异步模式但不阻塞写入
4. 场景四：Redis 重启，验证时间轮从 Redis 状态完全恢复，无消息丢失

每个场景输出：
- 测试前提交的消息数
- 实际投递成功数（应该 = 提交数）
- 故障检测时间（Slave 接管 ≤ 10s）
- 重复投递数（应该 = 0）

用 Shell + Java 实现，不依赖外部测试框架
```

## 六、第 3 周：管理台 + 可观测 + CI + 文档

### 6.1 目标

第 3 周结束时，When 是一个可以对外发布的开源项目：有 Web 管理台、有 Prometheus 指标、有 Docker Compose 一键启动、有完整的 README 和 API 文档。

### 6.2 第 1-2 天：Web 管理台（前后端同时）

管理台是第 3 周工作量最大的部分。用两个 Subagent 并行：一个写后端 API，一个写前端。

**Subagent 1：管理台后端 API（when-admin 模块）**

```
实现 Web 管理台的后端 API，放在 when-admin 模块

三个页面对应的 API：

1. 集群状态页：
   GET /admin/api/cluster/nodes  → 返回所有节点列表（nodeId / host / port / 状态 / 负载）
   GET /admin/api/cluster/wheels → 返回时间轮分布（wheelId / Master节点 / Slave节点 / 当前slot）

2. 任务列表页：
   GET /admin/api/messages?status=&sinkType=&startTime=&endTime=&page=&size=
   DELETE /admin/api/messages/{id}      → 取消消息
   POST /admin/api/messages/{id}/redeliver → 手动重投

3. 投递日志页：
   GET /admin/api/logs?messageId=&status=&page=&size=
   返回每次投递尝试的记录：时间 / 目标 / 状态 / 耗时 / 错误信息

数据存 MySQL（管理台元数据，和消息主存储的 Redis 分开）：
建表语句也一并给出

输出：Controller + Service + Mapper（MyBatis-Plus）完整实现
```

**Subagent 2：管理台前端**

```
实现 Web 管理台前端，技术栈：React + Ant Design + Vite

三个页面（参考 docs/images/ui-cluster.svg / ui-tasks.svg / ui-logs.svg 的线框图）：

1. 集群状态页：
   - 顶部 4 个 metric card：节点总数 / 活跃节点 / 时间轮总数 / 待投递消息数
   - 节点列表表格：nodeId / host / 状态 / 是否Controller / 负载 / 时间轮分配数量
   - 时间轮分布：每个 wheel 的 Master/Slave 分配情况

2. 任务列表页：
   - 搜索/筛选栏：状态下拉 / Sink类型 / 时间范围 / 搜索框
   - 消息表格：messageId / sinkType / deliverAt / 状态 / 重试次数 / 操作（取消/重投）
   - 右侧抽屉：点击消息行展开详情

3. 投递日志页：
   - 统计卡片：今日总投递 / 成功率 / 平均耗时
   - 日志表格：时间 / messageId / 目标地址 / 状态 / 耗时 / 错误信息（可展开）

要求：
- 支持暗色主题（Ant Design token 配置）
- 数据 polling 刷新（每 10s 自动刷新集群状态页）
- 前端代理到后端 :8080，不需要配 nginx

输出：完整前端工程，npm run dev 可直接启动
```

### 6.3 第 3 天：Prometheus 指标 + 结构化日志

```
给 When 加完整的可观测能力

Prometheus 指标（Micrometer + actuator/prometheus）：
需要暴露的指标：
- when_messages_submitted_total：提交总量（label: sinkType）
- when_messages_delivered_total：投递成功总量（label: sinkType）
- when_messages_failed_total：投递失败总量（label: sinkType, reason）
- when_delivery_latency_seconds：投递耗时分布（histogram，label: sinkType）
- when_timewheels_active：当前活跃时间轮数量
- when_pending_messages：当前待投递消息数（gauge）
- when_cluster_nodes：集群节点数（gauge, label: status）

指标要放在哪里：
- 消息提交时：when_messages_submitted_total++
- 投递成功时：when_messages_delivered_total++ + latency 记录
- 投递失败时：when_messages_failed_total++（reason=SINK_ERROR/TIMEOUT/MAX_RETRY）

结构化日志：
- 所有日志用 JSON 格式（logback + logstash-logback-encoder）
- 关键字段：traceId / messageId / nodeId / operation / durationMs
- 关键路径打 INFO（消息提交 / 投递成功 / 投递失败 / 节点上下线 / 故障切换）

输出：
1. 指标埋点完整代码
2. logback.xml 配置（JSON 格式）
3. 一份 Grafana Dashboard JSON（可直接导入，含上述所有指标的面板）
```

### 6.4 第 4 天：Docker Compose + Headless CI

**Docker Compose 一键启动（AI 做）：**

```
写 When 的 Docker Compose 部署方案

docker-compose.yml 需要包含：
- Redis（持久化：AOF everysec 模式）
- ETCD（单节点，生产建议 3 节点但 demo 用单节点）
- MySQL 8.0（管理台元数据）
- when-server（可 scale，默认 2 个实例）
- when-admin（管理台，:3000 端口）
- Prometheus（:9090，scrape when-server 的 /actuator/prometheus）
- Grafana（:3001，预加载上一步的 Dashboard JSON）

health check 全部配上，when-server 要等 Redis + ETCD 健康后才启动

附 docker-compose.dev.yml：只启动依赖（Redis / ETCD / MySQL），用于本地开发
```

**Headless CI（AI 做）：**

```
写一个 Headless Mode 脚本，接进 GitHub Actions

功能：推送代码后自动：
1. 构建 when-server
2. 用 docker-compose 起完整环境
3. 跑集成测试套件（含混沌测试的前两个场景）
4. 用 claude -p 生成测试报告摘要，附在 PR comment 里

GitHub Actions workflow 文件：.github/workflows/integration-test.yml
Headless 脚本：scripts/ci-report.sh（调用 claude -p 生成报告）

输出：完整的 workflow YAML + 脚本
```

### 6.5 第 5 天：文档 + Skills 沉淀 + 开源发布准备

**AI 做：README + API 文档**

```
写 When 的 README.md 和完整 API 文档

README 结构：
1. 一句话描述（什么是 When，解决什么问题）
2. 特性列表（5-6 条，有数字支撑：10000 QPS / ±1s 精度 / 10s 故障切换）
3. 快速开始（3 步跑起来：docker compose up → 提交消息 → 验证投递）
4. 架构图（引用 docs/images/when-arch.svg）
5. 与同类方案对比表格（RocketMQ / Redis ZSet / Dynein / When）
6. 配置说明
7. 贡献指南

API 文档（OpenAPI 3.0 YAML）：
覆盖 3 个核心接口 + 管理台 API，包含：
- 请求/响应示例
- 错误码说明
- 限流说明

输出：README.md + openapi.yaml
```

**人做：Skills 沉淀（重要，不让 AI 代劳）**

3 周实战后沉淀出来的 Skills，是比代码更有长期价值的资产：

- `skill-timingwheel.md`：多层时间轮的实现模式，下次在其他项目遇到类似问题直接调
- `skill-etcd-election.md`：ETCD CAS 选举的标准实现模式
- `skill-grpc-java.md`：Java gRPC Server/Client 的工程化搭建模式（Protobuf 定义 → 实现 → 测试）
- `skill-redis-hash-per-key.md`：避免 Redis 大 Key 的存储设计模式

每个 Skill 的结构：问题背景 → 适用场景 → 实现模板 → 已知坑。

## 七、AI 做什么 / 人做什么

明确分工比"95% AI Coding"这个数字更重要。

| 工作 | AI 做 | 人做 |
|------|-------|------|
| 算法实现（时间轮、选举） | 完整实现 + 单元测试 | Review 逻辑正确性、边界场景 |
| 接口层代码（Controller / gRPC） | 全部 | 接口签名设计（proto 文件） |
| 测试代码 | 生成测试框架 + 正常路径 | 补充故障场景、边界测试 |
| 配置文件（Docker / POM / logback） | 全部 | 确认版本选型 |
| 文档（README / API doc） | 生成初稿 | 补充真实数据和个人判断 |
| 架构决策 | 提供选项和分析 | 拍板（etcd vs ZK、同步 vs 异步） |
| 性能调优 | 提供参数建议 | 实测验证、最终参数确认 |
| 故障场景验证 | 写混沌测试脚本 | 解读结果、判断是否达标 |
| Skills 沉淀 | 生成模板 | 补充真实踩坑、标注适用边界 |

**5% 人做的本质：** 不是写代码，是做工程判断。哪些地方 AI 会信心满满地给出错误答案，哪些边界场景 AI 不会主动考虑，哪些性能数字需要实测而不是理论估算——这些判断，是工程经验积累出来的，也是 AI Coding 时代程序员最核心的价值。

## 八、关键风险和对应方法

**风险一：时间轮精度不达标（目标 ±1s，实测可能有偏差）**

对应方法：第 2 天 Subagent 1 就要跑精度测试，不到第 3 周才发现。精度问题通常出在两个地方：指针推进线程被 GC 暂停打断，或者系统时钟漂移。GC 问题用 ZGC / Shenandoah 解决；时钟漂移用 System.nanoTime() 而非 System.currentTimeMillis()。

**风险二：AI 在集群化代码里引入竞态条件**

对应方法：所有涉及并发的代码（时间轮 slot 操作、Master-Slave 同步状态机）必须有并发测试（JCStress 或 CountDownLatch 场景测试），不能只靠代码 review。在 Hooks 里加：改了 `cluster/` 目录下的文件，自动跑并发测试。

**风险三：Redis 设计被 AI 悄悄引入 ZSet 大 Key**

对应方法：CLAUDE.md 和 constitution.md 里都写了禁止，同时在 Hooks 里加静态检查：

```bash
# PostToolUse hook：改了 storage 相关文件后自动扫描
grep -r "ZSet\|zadd\|zrangebyscore" src/main/java/io/when/core/storage/ && echo "VIOLATION: ZSet 大 Key 被禁止" && exit 1
```

**风险四：第 3 周管理台工作量超出预期**

对应方法：管理台是锦上添花，不是核心。如果第 3 周前两天的实现质量不够好，优先保证后端 API 完整，前端可以用 Swagger UI 代替自定义界面。验收标准是"集群可运维"，不是"界面好看"。
