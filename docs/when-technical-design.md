# When 技术方案

> 承接《When 需求文档》。需求文档说 What，本文说 How。

---

## 一、概述

### 1.1 背景

延时投递是一类高频业务需求：订单超时未支付自动关闭、合同到期前 N 天发送提醒、任务调度在指定时间点触发回调、消息在流量低谷期延迟推送……这类场景的共同特征是"提交即忘，到点必达"，业务方不关心中间状态，只关心消息在约定时刻能准时出现在目标系统里。

在 OKX 内部，这类需求分散在各业务线，各自用不同的方案应付：有的用 RocketMQ 的固定档位凑合，有的用 Redis ZSet 自己实现，有的直接在数据库里轮询定时任务表。方案不统一、运维成本分散、稳定性参差不齐，是长期存在的问题。

**When** 是为了统一解决这个问题而设计的独立组件。它以 Java 17 实现，独立部署，核心职责只有一件事：**接收业务方提交的延时消息，在指定时间点精准投递到任意下游目标（HTTP Webhook / Kafka / gRPC）**。

When 定位为一个轻量的基础设施组件，而非又一套完整的消息队列。业务方不需要引入 SDK，通过 HTTP 接口提交和管理消息，投递目标通过 Sink 配置灵活指定。集群化部署后支持水平扩展，单节点故障不影响全局服务。

开源生态里做延时的方案不少，但没有一个在"轻量独立部署 + 任意延时精度 + 多 Sink 扩展 + 生产级可靠性"这几个维度上同时达标：

- **Kafka**：无原生延时支持。社区有基于时间戳过滤或额外 Topic 分层的方案，但都有精度损失或运维复杂度问题，不适合作为通用延时层。
- **RocketMQ 4.x**：只有 18 个固定延时档位（1s / 5s / 10s / … / 2h），无法满足任意时间点投递。5.0 引入任意时间延时，但在 OKX 内部的 RocketMQ 版本尚未覆盖，且引入整套 RocketMQ 体系成本偏高。
- **Pulsar**：原生支持消息级别的延时投递，精度较好，但 Pulsar 整套 BookKeeper + Broker 体系偏重，单纯为了延时引入成本与收益不匹配。
- **Redisson DelayedQueue**：基于 Redis ZSet 实现，方案简单，但所有消息写入同一个 ZSet key，消息量上去之后会形成大 Key，在极端情况下影响 Redis 性能。OKX 内部 Ok-MQ SDK 的生产环境已经踩过这个问题。
- **Airbnb Dynein**：架构上最接近 When 的设计思路（独立延时服务 + 多 Sink），但强绑定 AWS SQS，开源后社区几乎停止维护，不具备可落地性。

这个空位是真实存在的。When 要在这个位置提供一个可用于生产的解法。

### 1.2 技术目标

| 维度 | 指标 |
|------|------|
| 吞吐 | 单节点写入 ≥ 10,000 QPS；单节点投递 ≥ 10,000 QPS；集群随节点数线性扩展 |
| 精度 | 99% 消息在到期时间 ±1s 内投递；覆盖 1s ~ 30d |
| 容量 | 单节点稳定存储 ≥ 100 万条延时消息 |
| 可用性 | Master 故障后 Slave ≤ 10s 接管；单节点故障不影响整体服务 |
| 可靠性 | 至少一次投递；Master 宕机已写入消息不丢 |
| 可运维 | ETCD 动态下发配置；支持滚动升级；节点扩缩容自动 rebalance |

### 1.3 术语表

| 术语 | 含义 |
|------|------|
| When | 本项目，也指服务进程 |
| 延时消息 | 业务方提交的、携带到期时间的投递任务单元 |
| Sink | 投递目标的抽象，HTTP Webhook / Kafka / gRPC 等是具体实现 |
| 时间轮（TimeWheel） | 调度核心数据结构，负责到期触发 |
| Slot | 时间轮的最小刻度格 |
| Bucket | 某个 Slot 上挂载的消息集合 |
| Controller | 集群中负责调度决策的逻辑角色，不是独立进程 |
| Master | 时间轮的主副本，负责实际调度和投递 |
| Slave | 时间轮的备副本，同步 Master 数据，故障时接管 |

---

## 二、业界技术方案调研

### 2.1 延时调度算法

核心问题：N 条消息，每条有一个到期时间戳，怎么以最小代价在恰当的时间触发？

**DelayQueue（Java JDK）**

最小堆结构，`poll` 取堆顶判断是否到期。插入和删除均为 O(log N)。实现简单，毫秒级精度，但纯内存，进程重启全丢，高并发下堆操作有锁竞争。只适合单机小规模场景。

**Quartz / XXL-JOB**

cron 表达式驱动，底层存 MySQL，调度线程定时扫 DB 捞 Job。精度秒级，高并发下 DB 扫描是瓶颈。定位是任务调度框架，关注"何时执行业务代码"，不是"投递消息到外部系统"，场景不对。

**Redis ZSet**

以到期时间戳为 score 存消息 ID，定时 `ZRANGEBYSCORE` 扫到期消息再投。实现简单，利用 Redis 持久化。有赞延时队列、OKX 内部 Ok-MQ SDK 都走的这条路。问题是大 Key：ZSet 堆积百万消息时单个 Key 体积极大，ZRANGEBYSCORE 会卡 Redis 数百毫秒，OKX 内部已在生产中遇到。另外轮询间隔限制精度，通常 ≥1s。

**多层时间轮**

环形数组，每个 Slot 对应一个时间刻度，指针推进时触发当前 Slot 上的消息，O(1) 复杂度。Kafka、Netty 都在用。多层级联（天 / 小时 / 分钟 / 秒）可以覆盖秒到月的延时跨度，同时保持 O(1) 触发。

| 方案 | 触发复杂度 | 精度 | 持久化 | 分布式 | 大规模 |
|------|-----------|------|--------|--------|--------|
| DelayQueue | O(log N) | 毫秒 | ✗ | ✗ | 不适合 |
| Quartz/XXL-JOB | O(1)（DB 扫描） | 秒 | ✓ | ✓ | 任务调度场景 |
| Redis ZSet | O(log N) | ≥1s | ✓ | ✓ | 大 Key 风险 |
| 多层时间轮 | O(1) | 毫秒~秒 | 需另建 | ✓ | **When 选型** |

---

### 2.2 分布式协调方案

When 需要节点注册与发现、Controller 选举、配置下发、故障检测，需要一个外部协调组件来做这些事。

**ZooKeeper**

最成熟，Kafka 早期、HBase 都用它。ZAB 协议，临时节点做服务注册，Watch 做变更通知。缺点是运维重（JVM 进程 + 独立集群），API 偏底层（ZNode 路径操作），社区进入维护期。

**ETCD**

Kubernetes 的核心存储，Raft 协议，Go 单进程，运维比 ZooKeeper 轻得多。Lease 做服务注册和故障检测，Watch 做变更通知，事务 CAS 做选举。Java 客户端 jetcd 功能完整。新项目的首选。

**Consul**

内置 DNS 和 HTTP 服务发现，服务发现场景更开箱即用，但默认非强一致，每台机器都要跑 agent，拓扑复杂。纯做协调不如 ETCD 简洁。

**Nacos**

Spring Cloud Alibaba 生态，服务注册和配置中心用起来方便，但强一致 KV 事务不是它的强项，不适合做 Controller 选举。

| 方案 | 一致性协议 | 运维 | 分布式选举 | Java 客户端 | 新项目 |
|------|-----------|------|-----------|------------|--------|
| ZooKeeper | ZAB | 重 | ✓ 成熟 | Curator | 渐退 |
| ETCD | Raft | 轻 | ✓ 原生 | jetcd | **When 选型** |
| Consul | Raft | 中 | ✓ | 社区维护 | 可选 |
| Nacos | Raft（v2） | 轻 | 弱 | Spring 原生 | 配置场景 |

---

### 2.3 持久化存储方案

核心诉求：写入快（不能拖慢 10,000 QPS 写入路径）、按 key 随机读写快、运维成熟。

**Redis**

内存操作，写入 < 1ms。AOF + RDB 双持久化，`everysec` 模式最多丢 1s 数据，`always` 模式完全不丢。企业普及率极高，运维成本低。大 Key 问题通过按消息 ID 分散存储规避（§5.7）。

**RocksDB**

嵌入式 KV，LSM-Tree，写吞吐高，磁盘存储成本低，TiKV 底层在用。缺点是作为嵌入式库跑在 When 进程内，JNI 调用有开销，Java 客户端成熟度不如 Redisson，监控工具链薄弱。100 万条消息约 1GB 内存，Redis 完全承受得住，RocksDB 的磁盘优势在 When 场景意义有限。

**MySQL**

写入 QPS 远低于 Redis，单节点 10,000 QPS 目标需要批量写和分库分表，引入不必要复杂度。适合管理台元数据，不适合消息主存储。

| 方案 | 写入延迟 | 持久化 | 运维 | 大 Key 风险 | When |
|------|---------|--------|------|------------|------|
| Redis | < 1ms | ✓ | 高 | 需规避 | **选型** |
| RocksDB | 低 | ✓ | 中 | 无 | 复杂度高 |
| MySQL | 10~50ms | ✓ | 高 | 无 | 不适合主存储 |

---

### 2.4 副本与高可用机制

时间轮跑在内存里，节点挂掉内存就没了，需要副本机制让故障时能快速接管。

**Raft 多副本**

强一致共识协议，写入需要多数节点确认，故障时自动选新 Leader。ETCD、TiKV 都基于它。优点是强一致自动容错；缺点是完整实现（选举 + 日志复制 + 成员变更 + 快照）代码量 3,000~5,000 行以上，测试难度大，训练营 10 周搞不完。写入延迟也因多数确认而比主从高。

**Master-Slave 同步复制**

一个 Master 处理写入，同步复制到 Slave，Slave 确认后才返回 ACK。Master 宕机 Slave 接管，无数据丢失。Redis Sentinel、MySQL 主从都是这个模型。实现比 Raft 简单，延迟低（只等一个 Slave RTT），1+1 副本覆盖单节点故障场景。

| 方案 | 一致性 | 写入延迟 | 实现复杂度 | 节点数 | When |
|------|--------|---------|-----------|--------|------|
| Raft | 强一致 | 较高 | 高 | ≥3 | 过重 |
| Master-Slave 同步 | 强一致 | 低 | 中 | 2 | **选型** |
| Master-Slave 异步 | 最终一致 | 极低 | 低 | 2 | 有丢数据窗口 |

---

### 2.5 通信协议

When 有两层通信：对外（业务方接入）和对内（节点间）。

**HTTP/REST**

接入门槛最低，curl 直接用，任何语言都能调，不需要 SDK。性能比 gRPC 差，但对接入层（万级 QPS）够用。

**gRPC**

HTTP/2 + Protocol Buffers，序列化体积比 JSON 小 3~10 倍，强类型接口定义，双向流。适合节点间高频通信——副本同步、Controller 指令、消息路由转发。

| 协议 | 性能 | 接入门槛 | 调试 | 适用层 |
|------|------|---------|------|--------|
| HTTP/REST | 中 | 极低 | 高 | 对外接入层 |
| gRPC | 高 | 需 proto stub | 中 | 内部节点通信 |

---

## 三、技术选型思考

### 3.1 调度算法：多层时间轮

四层级联：秒轮 60 槽 / 分钟轮 60 槽 / 小时轮 24 槽 / 天轮 30 槽，总计 174 槽覆盖 30 天。

投递 QPS ≥ 10,000 是硬指标。时间轮触发 O(1)，与系统中消息总数无关，是唯一能在百万级消息规模下稳定达到这个目标的方案。单层不够用（覆盖 30 天需要 260 万个槽），四层级联解决这个问题——长延时消息放高层，逐层降级到秒轮精确触发。

放弃 Redis ZSet：调度逻辑交给 Redis 轮询意味着 When 退化为消费者，失去内存调度的精度控制，而且大 Key 风险是已被证实的生产问题。

---

### 3.2 分布式协调：ETCD

选 ETCD + jetcd，核心是三个机制刚好对上 When 的需求：

- **Lease**：节点注册时绑定 Lease，心跳续约保活，节点宕机后 ETCD 自动清理，不用另外实现故障检测
- **事务 CAS**：`IF key NOT EXISTS THEN PUT` 原语直接实现 Controller 选举
- **Watch**：Controller 监听 `/when/nodes/` 前缀，节点上下线实时感知，事件驱动不轮询

另外，跑 Kubernetes 的环境一般都有 ETCD，When 用户几乎不需要额外部署。

放弃 ZooKeeper：能满足需求，但运维重、API 繁琐，新项目没理由选它。

---

### 3.3 持久化存储：Redis

When 的可靠性语义是"业务方收到 ACK 则消息不丢"。实现路径：消息先写 Redis，再入时间轮，再返回 ACK。Redis AOF 保证持久化，Master 宕机后新 Master 从 Redis 全量 recover，不依赖内存副本的完整性。

按消息 ID 分散存储（每条消息一个独立 Key）彻底规避大 Key 问题，100 万条消息约 550MB 内存，可控。

放弃 RocksDB：磁盘优势在 When 场景用不上，JNI 调用和 Java 客户端成熟度都不如 Redisson，运维团队不熟悉。

---

### 3.4 副本机制：Master/Slave 同步复制

1 Master + 1 Slave，同步复制。

选它的理由不是它最强，而是它够用且能在 10 周内实现正确。Raft 的实现和测试成本超出训练营范围。When 的可靠性兜底是 Redis，时间轮副本的目标只是"故障快速切换"，不需要强一致——哪怕 Slave 有几秒落后，新 Master 从 Redis recover 也能补齐。

故障切换由 Controller 协调：检测到 Master 宕机后向 Slave 发 gRPC 指令，Slave 从 Redis 加载数据，重建时间轮，开始调度。逻辑链路清晰，可测。

---

### 3.5 通信协议：对外 HTTP + 对内 gRPC

When 的一个核心设计原则是"接入不依赖 SDK"。OKX 内部 Ok-MQ SDK 推广受阻的原因之一就是 SDK 形态本身——业务方要引入依赖、要升级版本、要和运维沟通。HTTP API 没有这些问题，curl 就能接入。

节点间通信（副本同步、指令下发、消息转发）频率高、类型固定，gRPC 的 Protocol Buffers 序列化和强类型约束让内部通信更高效、更不容易出错。

---

### 3.6 实现语言：Java 17

训练营面向 Java 后端开发者，这是基本约束。Spring Boot、Redisson、jetcd、gRPC Java 全部有成熟实现，不用造轮子。Netty 的 `HashedWheelTimer` 是现成的时间轮参考。Java 17 的 ZGC 停顿 < 1ms，不干扰时间轮精度，这是 Java 8/11 时代不具备的能力。

---

## 四、整体架构设计

### 4.1 架构总览

When 整体架构由四部分组成：业务方、When 集群、外部依赖（ETCD / Redis）、下游 Sink。

![整体架构图](images/arch-overview.svg)

几点说明：

- **同构多节点**：集群里每个节点进程完全一样，都能收请求、跑时间轮、投消息，没有"专用角色节点"
- **Controller 是角色不是节点**：其中一台节点兼任 Controller，负责分片分配和故障处理，宕机后 ETCD 重新选举
- **ETCD 和 Redis 是外部依赖**：When 不自己做集群协调和持久化，这两件事交给成熟组件
- **Sink 插件化**：HTTP / Kafka / gRPC 内置，其余通过 Java SPI 扩展，不改核心代码
- **Web 管理台独立部署**，通过 HTTP API 和 When 集群通信

---

### 4.2 节点内部模块

每个 When 节点是一个 Spring Boot 应用，模块划分如下：

![节点内部模块图](images/node-internal.svg)

---

### 4.3 节点角色与集群形态

集群节点同构，运行时通过 ETCD 协调产生三种逻辑角色：

**Controller**（同一时刻只有一个）
- Watch ETCD `/when/nodes/` 感知节点上下线
- 负责时间轮的 Master/Slave 分配和 rebalance
- 负责 Master 故障时的 Slave 提升决策
- 宕机后 ETCD 自动重选

**Master**（每个时间轮分片一个）
- 本地内存时间轮负责调度和投递
- 写入时同步复制到对应 Slave

**Slave**（每个时间轮分片一个）
- 同步 Master 数据，维护热备
- 收到 Controller 指令后切换为 Master

一个节点可以同时持有多个角色：Node 1 可以是 Controller + TW-1 的 Master + TW-2 的 Slave。

时间轮数量和节点数量解耦，默认 `时间轮总数 = 节点数 × 2`。节点数变化时 Controller 重新分配，不需要增减时间轮。

生产环境最小部署：3 节点，覆盖单节点故障，奇数节点对 ETCD 选举友好。

---

### 4.4 关键数据流

**写入流**

业务方 `POST /messages` 打到任意节点，节点按 `message_id % timewheel_count` 路由到目标时间轮的 Master。如果 Master 不在本节点，gRPC 转发过去。Master 先写 Redis（消息体 + 时间索引），再入内存时间轮，再异步通知 Slave，最后返回 ACK。Redis 持久化先于 ACK 返回——业务方拿到 message_id 就代表消息已落盘。

**投递流**

时间轮调度循环每秒推进一次指针。Slot 到期时，Bucket 里的消息交给 SinkDispatcher 异步投递。投递成功后删 Redis 消息体和索引，通知 Slave 同步删除。投递失败按重试策略重新入轮（指数退避）。调度循环里只做读和触发，Redis 删除和 Sink 调用都是异步提交，不阻塞指针推进。

**故障切换流**

Master 宕机后 ETCD Lease 过期，Controller Watch 到 DELETE 事件，向受影响时间轮的 Slave 发 gRPC 指令。Slave 从 Redis 加载全量索引，重建内存时间轮，开始调度。全程目标 ≤ 10s。

---

## 五、详细设计

### 5.1 集群组建与协调

集群协调全部基于 ETCD，覆盖节点注册、保活、Controller 选举、节点上下线感知四个环节。

![集群组建协调时序图](images/cluster-coordination.svg)

#### 节点注册

节点启动第一件事是向 ETCD 注册，key 为 `/when/nodes/{node_id}`，value 是节点元信息，绑定 TTL 10s 的 Lease：

```
PUT /when/nodes/node-1
value: {"ip":"10.0.0.1","port":8080,"grpc_port":9090,"start_time":1700000000,"load":0}
lease: 10s TTL
```

绑定 Lease 的 key 在 Lease 过期后自动删除，节点宕机的检测就靠这个。

#### 心跳保活

注册完后起一个独立后台线程，每 3s 发一次 KeepAlive 续约（TTL 10s，续约间隔 3s，留 3 倍余量应对抖动）。续约线程必须和业务线程隔离，用独立的 ETCD 连接，GC 停顿不影响续约。

#### Controller 选举

多个节点同时尝试创建 `/when/controller`，ETCD 事务保证只有一个成功：

```
TXN
  IF /when/controller NOT EXISTS (create_revision == 0)
  THEN PUT /when/controller = node_id, lease=10s
  ELSE NOOP
```

成功的节点启动 Controller 线程，失败的 Watch 这个 key 等待下次选举机会。Controller key 也绑 Lease，由 Controller 线程续约，宕机后 key 消失，其他节点立刻触发重选。

#### 节点上下线感知

Controller 持续 Watch `/when/nodes/` 前缀：

- **PUT 事件**：新节点加入，触发时间轮 rebalance（§5.5）
- **DELETE 事件**：节点下线，检查该节点的 Master 时间轮，向对应 Slave 发切换指令（§5.4）

全链路事件驱动，Controller 不主动 ping 节点。

#### 时间轮元数据

时间轮的分配信息存 ETCD，Controller 写，普通节点只读：

```
/when/timewheels/tw-001
value: {"id":"tw-001","master":"node-1","slave":"node-2","status":"running"}
```

节点 Watch 这个前缀，变更后更新本地路由表。

---

### 5.2 多层时间轮

![多层时间轮结构图](images/timing-wheel.svg)

#### 单层原理

时间轮是环形数组，每个 Slot 代表一个时间刻度（秒轮 1 Slot = 1s）。指针从 0 开始，每个刻度前进一格，走到 Slot N 时触发 Slot N 上的所有消息。插入和触发均为 O(1)，与消息总数无关。

新消息延时 30s，当前指针在 Slot 5：放入 `(5+30) % 60 = Slot 35`，指针推进 30 次后触发。

#### 四层结构

| 层 | 名称 | 槽数 | 每槽跨度 | 覆盖范围 |
|----|------|------|---------|---------|
| L4 | 天轮 | 30 | 1 天 | 30 天 |
| L3 | 小时轮 | 24 | 1 小时 | 24 小时 |
| L2 | 分钟轮 | 60 | 1 分钟 | 60 分钟 |
| L1 | 秒轮 | 60 | 1 秒 | 60 秒 |

总计 174 槽，覆盖 1s ~ 30d 任意延时。

**降级机制**：延时 2d 3h 15m 20s 的消息，先放天轮 Slot[2]。天轮指针走到 Slot[2] 时，剩余 3h 15m 20s，降到小时轮 Slot[3]。依此类推，最终进入秒轮 Slot[20] 触发投递。

#### 调度循环

每个时间轮实例跑在独立线程里：

```java
while (running) {
    long tickStart = System.currentTimeMillis();

    Bucket bucket = wheel[L1][pointer];
    for (MessageRef ref : bucket.drain()) {
        sinkDispatcher.submitAsync(ref);          // 异步投递，不阻塞
        redisStore.deleteIndexAsync(ref.msgId()); // 异步删索引
    }

    if (++pointer % 60 == 0) tickHigherWheels();
    pointer = pointer % 60;

    long sleep = SLOT_DURATION_MS - (System.currentTimeMillis() - tickStart);
    if (sleep > 0) LockSupport.parkNanos(sleep * 1_000_000L);
}
```

调度循环里只做读和触发，Redis 删除和 Sink 调用全部异步提交，确保指针推进不被 IO 拖慢。

#### 时间轮分布

集群默认 `时间轮总数 = 节点数 × 2`，分布在各节点上。多时间轮的作用：并发调度提升总 QPS，单个时间轮出问题（GC 停顿）不影响其他，Controller 可动态迁移 Slave 副本均衡负载。

写入时按 `message_id % timewheel_count` 均匀散列到各时间轮。

---

### 5.3 延时消息生命周期

![消息生命周期时序图](images/message-lifecycle.svg)

#### 写入

1. 业务方 `POST /messages`，body 包含 `delay_seconds`、`sink_type`、`sink_config`、`payload`
2. 接入层参数校验，Snowflake 生成全局唯一 `message_id`
3. `message_id % timewheel_count` 路由到目标时间轮 tw-N
4. 若本节点是 tw-N 的 Master：写 Redis（消息体 HSET + 时间索引 SET）→ 入内存时间轮 → 异步通知 Slave → 返回 `message_id`
5. 若不是：gRPC 转发到 Master 节点，等 ACK 后返回给业务方

**Redis 写入先于 ACK 是硬约束**：业务方拿到 `message_id` 就代表消息已持久化，这条消息不会丢。

#### 投递

时间轮指针推进到期，Bucket 里的消息交给 SinkDispatcher。Sink 执行投递（HTTP POST / Kafka Produce / gRPC Call），成功后删 Redis 消息体和索引，通知 Slave 同步删除。失败则按重试策略（指数退避，默认最多 4 次）重新入时间轮。

**投递语义是至少一次**：若投递成功后、Redis 删除前 Master 宕机，新 Master recover 时会重新触发投递，导致消息被投递两次。这是分布式系统的标准权衡，业务方下游需要保证幂等消费。

#### 取消

`DELETE /messages/{id}` 路由到对应 Master，内存时间轮标记 cancelled（惰性删除 O(1)），Redis 删除消息体和索引，通知 Slave 同步。

边界情况：消息已投递后取消请求到达，Redis 里消息已不存在，接口返回 404，状态为 `delivered`，业务方需处理这个竞态。

#### 查询

`GET /messages/{id}` 路由到对应节点，先查内存时间轮，没有再查 Redis，返回状态（`pending` / `delivered` / `cancelled` / `failed`）和时间戳。

---

### 5.4 Master/Slave 副本机制

![故障切换时序图](images/failover.svg)

#### 数据同步

Master 完成 Redis 写入后，异步向 Slave 发 gRPC 同步请求：

```protobuf
rpc SyncWrite(SyncWriteRequest) returns (SyncWriteReply) {}

message SyncWriteRequest {
  string tw_id        = 1;
  string msg_id       = 2;
  uint64 expire_ts_ms = 3;
  bytes  payload      = 4;
  string sink_type    = 5;
  string sink_config  = 6;
}
```

Slave 在自己的内存时间轮里执行同样的插入后 ACK，整个过程通常几毫秒。

同步是异步的，不阻塞写入路径。Redis 是可靠性的真正保证，Slave 内存落后几秒不影响数据安全——故障切换时新 Master 从 Redis 全量 recover 即可。

#### 故障检测

完全依赖 ETCD Lease 机制，Controller Watch 感知，When 不另建心跳体系。Lease 由独立线程续约，GC 停顿和业务线程阻塞不影响续约——只有节点真正失能才会 Lease 过期，误判率极低。

#### 故障切换

```
T+0s   Node-X 宕机，Lease 续约停止
T+10s  ETCD 删除 /when/nodes/node-x
T+10s  Controller 收到 Watch DELETE 事件，查出 Node-X 的 Master 时间轮
T+11s  Controller → Node-2（TW-3 的 Slave）：PromoteToMaster(tw_id="tw-3")
T+11s  Node-2：SCAN Redis 加载 TW-3 所有未到期索引 → 重建内存时间轮 → 启动调度
T+12s  Node-2 回报接管完成，Controller 更新 ETCD 分片表，分配新 Slave
```

全程 ≤ 10s，期间 TW-3 的写入请求失败，业务方重试即可，已写入消息全部安全。

#### 不丢消息的两层保证

1. Redis 写入先于 ACK：Master 宕机前未写 Redis，业务方未收到 ACK，会重试提交（Snowflake message_id 幂等）
2. 新 Master 全量 recover：SCAN Redis 该时间轮的所有索引，不会漏

---

### 5.5 节点扩缩容与负载均衡

![Rebalance 对比图](images/rebalance.svg)

#### 节点加入

新节点向 ETCD 注册后，Controller 触发 rebalance，把部分时间轮的 Slave 副本迁移到新节点（优先迁移 Slave 不动 Master，避免影响写入路径）。新节点从 Master 全量拉取数据，同步完成后承担 Slave 角色。

#### 节点退出

**主动退出**（滚动升级、运维下线）：节点收到 SIGTERM 后主动 DELETE ETCD key（不等 Lease 过期），Controller 立即感知，执行故障切换流程，等所有 Master 时间轮切换完成，节点再真正退出。业务方视角：写入短暂失败约 1~3s，已写消息不丢。

**异常退出**：等 Lease TTL 过期，流程和故障切换相同。

#### Rebalance 算法

目标：每个时间轮 1 Master + 1 Slave，Master 和 Slave 在不同节点，各节点副本总数（Master 数 + Slave 数）均匀（target ± 1）。

```
function rebalance(nodes, timewheels):
    target = (len(timewheels) * 2) / len(nodes)  // 每节点目标副本数

    // 修复 Master 和 Slave 在同一节点的违规
    for tw in timewheels:
        if tw.master == tw.slave:
            tw.slave = pick_node(nodes, exclude=tw.master)

    // 均衡负载：优先迁移 Slave
    while exists overloaded and underloaded nodes:
        src = most_overloaded_node()
        dst = most_underloaded_node()
        tw  = pick_movable_slave(src)
        migrate_slave(tw, src, dst)
```

不追求绝对均匀，target ± 1 的容忍范围避免频繁 rebalance。每次集群变化触发一次，日常每 5 分钟检查一次。

---

### 5.6 Sink 投递层

#### 接口与 SPI

所有 Sink 实现同一个接口：

```java
public interface Sink {
    String type();  // 与消息的 sink_type 字段匹配，如 "http"
    DeliveryResult deliver(DelayMessage message);  // 线程安全
}
```

SinkDispatcher 通过 Java SPI 加载，构建 `Map<String, Sink>` 路由表按 `sink_type` 分发。新增 Sink 只需实现接口 + 添加 SPI 注册文件，不改核心代码。

```
META-INF/services/com.when.core.sink.Sink:
com.when.sink.HttpSink
com.when.sink.KafkaSink
com.when.sink.GrpcSink
```

#### HttpSink

业务方指定 endpoint，到期时 POST 消息体：

```json
{
  "url": "https://api.example.com/webhook/order-timeout",
  "method": "POST",
  "headers": {"X-When-Signature": "xxx"},
  "timeout_ms": 5000
}
```

OkHttp 连接池复用，读 HTTP 响应码，2xx 成功，其余触发重试。

#### KafkaSink

业务方指定 Kafka 集群和 Topic，到期时 Produce 一条消息：

```json
{
  "bootstrap_servers": "kafka-1:9092,kafka-2:9092",
  "topic": "order-timeout-events",
  "key": "${message_id}"
}
```

KafkaProducer 按 `bootstrap_servers` 分组复用，`producer.send().get()` 同步确认，key 支持模板替换。

#### GrpcSink

业务方指定 gRPC 服务地址和方法，到期时发 Unary RPC：

```json
{
  "target": "order-service:50051",
  "service": "com.example.OrderService",
  "method": "HandleTimeout",
  "deadline_ms": 3000
}
```

ManagedChannel 按 target 分组复用，消息体以 `bytes payload` 透传。

#### 重试策略

失败后重新入时间轮等待重试，默认指数退避：

```
第 1 次：10s 后
第 2 次：30s 后
第 3 次：90s 后
第 4 次：270s 后
超过 4 次 → 标记 failed（P1 阶段进入死信队列）
```

重试配置可在提交消息时自定义（`retry_config` 字段）。

---

### 5.7 持久化层

![Redis 数据模型图](images/redis-data-model.svg)

#### 数据模型

**消息体**：`/when/messages/{msg_id}`，Hash 类型，字段包含 payload、sink_type、sink_config、status、created_at、expire_at、retry_count。TTL 为 expire_at + 7 天（投递后保留 7 天供查询）。

**时间索引**：`/when/tw/{tw_id}/index/{msg_id}`，String 类型，value 为 `expire_ts`（Unix ms）。TTL 为 expire_at + 1 小时（投递后尽快清理）。

#### 大 Key 规避

OKX 内部 Ok-MQ SDK 踩坑的根源：所有消息 ID 放一个 ZSet，堆积百万条时单个 Key 几百 MB，`ZRANGEBYSCORE` 阻塞 Redis 数百毫秒。

When 从设计上彻底规避：每条消息一个独立 Key（单 Key < 1KB），时间索引同样按消息 ID 分散，没有任何大集合 Key。调度在内存时间轮完成，不依赖 Redis 操作触发，不给 Redis 增加额外压力。所有 Key 设 TTL，投递后自动过期，无需主动批量删除。

单节点 100 万条消息：消息体约 500MB + 索引约 50MB = ~550MB，1GB 内存的 Redis 轻松承载。

#### 节点 Recover

新 Master 接管时从 Redis 重建内存时间轮：

```java
String cursor = "0";
do {
    ScanResult<String> result = redis.scan(cursor,
        ScanParams.MATCH("/when/tw/" + twId + "/index/*"), ScanParams.COUNT(1000));
    cursor = result.getCursor();
    for (String key : result.getResult()) {
        long expireTs = Long.parseLong(redis.get(key));
        if (expireTs > System.currentTimeMillis()) {
            timingWheel.insert(extractMsgId(key), expireTs);
        }
    }
} while (!cursor.equals("0"));
timingWheel.start();
```

SCAN 是非阻塞增量扫描，100 万条索引约 1~3s 完成，满足 10s 内接管目标。

---

### 5.8 Web 管理台

管理台是独立部署的 Web 应用（React + Spring Boot），通过 HTTP API 和 When 集群通信，不耦合在服务节点内。管理台服务端直接读 ETCD 获取集群元数据，直接读 Redis 做统计，减少对 When 节点的压力。

**集群状态页**：节点列表（ID / IP / 状态 / 负载 / 时间轮数）、Controller 高亮、时间轮分布（每个时间轮的 Master/Slave 节点）、集群聚合指标（总待投递消息数、写入 QPS、投递 QPS）。

**任务列表页**：按状态 / 时间范围 / Sink 类型筛选，单条消息详情（消息体 / 重试记录），支持取消和手动重投（failed 状态）。

**投递日志页**：投递历史时间轴，失败消息的错误信息和重试记录，耗时分布（P50 / P95 / P99）。

---

### 5.9 可观测能力

#### Prometheus Metrics

所有节点通过 `/actuator/prometheus` 暴露：

| Metric | 类型 | 说明 |
|--------|------|------|
| `when_messages_written_total` | Counter | 写入消息总数 |
| `when_messages_delivered_total` | Counter | 投递成功总数 |
| `when_messages_failed_total` | Counter | 投递失败总数 |
| `when_messages_pending_count` | Gauge | 当前待投递消息数 |
| `when_delivery_latency_ms` | Histogram | 投递耗时（P50/P95/P99） |
| `when_timing_wheel_slot_lag` | Gauge | 时间轮指针延迟（实际 vs 预期，ms） |
| `when_sink_call_duration_ms` | Histogram | Sink 调用耗时（按 sink_type） |
| `when_replication_lag_ms` | Gauge | Master→Slave 同步延迟 |

`when_timing_wheel_slot_lag` 是核心精度指标，超过 500ms 需要告警，通常是 GC 停顿或线程竞争导致。

#### 结构化日志

关键路径用结构化 JSON，包含 `trace_id`、`msg_id`、`tw_id`、`node_id`，方便日志聚合检索：

```json
{
  "timestamp": "2026-05-13T10:00:00.123Z",
  "level": "INFO",
  "event": "message_delivered",
  "trace_id": "abc123",
  "msg_id": "17000000001",
  "tw_id": "tw-001",
  "node_id": "node-1",
  "sink_type": "http",
  "latency_ms": 45,
  "retry_count": 0
}
```

日志级别：INFO 记写入和投递成功；WARN 记失败重试和 Slave 同步延迟超阈值；ERROR 记彻底失败和中间件连接异常。

#### 健康检查

```
GET /actuator/health
{
  "status": "UP",
  "components": {
    "etcd": {"status": "UP"},
    "redis": {"status": "UP"},
    "timingWheels": {"status": "UP", "count": 2, "running": 2}
  }
}
```

任意组件 DOWN 则整体变 DOWN，供 Kubernetes Liveness/Readiness Probe 使用。

---

## 六、接口定义

### 6.1 HTTP API（业务方接入）

统一响应格式：

```json
{
  "code": 0,
  "message": "ok",
  "data": {},
  "request_id": "abc-123"
}
```

`code` 为 0 表示成功，非 0 为错误码。

---

#### POST /api/v1/messages — 提交延时消息

**请求**

```json
{
  "delay_seconds": 1800,
  "sink_type": "http",
  "sink_config": {
    "url": "https://api.example.com/webhook/order-timeout",
    "method": "POST",
    "headers": {"X-Source": "when"},
    "timeout_ms": 5000
  },
  "payload": "eyJvcmRlcl9pZCI6IjEyMzQ1NiJ9",
  "idempotency_key": "order-123456-timeout",
  "retry_config": {
    "max_retries": 4,
    "strategy": "exponential",
    "initial_interval_ms": 10000
  }
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| delay_seconds | int | 是 | 延时秒数，范围 [1, 2592000] |
| sink_type | string | 是 | `http` / `kafka` / `grpc` |
| sink_config | object | 是 | 结构因 sink_type 不同而异 |
| payload | string | 是 | Base64 编码，最大 64KB |
| idempotency_key | string | 否 | 相同 key 不重复创建 |
| retry_config | object | 否 | 不填用默认（指数退避，最多 4 次） |

**响应（200）**

```json
{
  "code": 0,
  "data": {
    "message_id": "1700000000001",
    "status": "pending",
    "expire_at": "2026-05-13T11:30:00Z",
    "created_at": "2026-05-13T11:00:00Z"
  }
}
```

**错误码**

| code | HTTP | 含义 |
|------|------|------|
| 1001 | 400 | 参数校验失败 |
| 1002 | 400 | sink_type 不支持 |
| 1003 | 400 | sink_config 格式错误 |
| 2001 | 409 | idempotency_key 重复，data 中返回已有 message_id |
| 5001 | 503 | 集群不可用 |

---

#### DELETE /api/v1/messages/{message_id} — 取消延时消息

**响应（200）**

```json
{
  "code": 0,
  "data": {"message_id": "1700000000001", "status": "cancelled"}
}
```

| code | HTTP | 含义 |
|------|------|------|
| 4001 | 404 | 消息不存在（已投递、已取消或 ID 错误） |
| 4002 | 409 | 消息已投递，无法取消 |

---

#### GET /api/v1/messages/{message_id} — 查询消息状态

**响应（200）**

```json
{
  "code": 0,
  "data": {
    "message_id": "1700000000001",
    "status": "delivered",
    "sink_type": "http",
    "created_at": "2026-05-13T11:00:00Z",
    "expire_at": "2026-05-13T11:30:00Z",
    "delivered_at": "2026-05-13T11:30:00.432Z",
    "retry_count": 0,
    "actual_delay_ms": 432
  }
}
```

`actual_delay_ms` 是实际投递时间与预期到期时间的差值，用于精度统计。

---

#### Sink Config 结构

**HTTP**
```json
{"url": "https://...", "method": "POST", "headers": {}, "timeout_ms": 5000}
```

**Kafka**
```json
{"bootstrap_servers": "k1:9092,k2:9092", "topic": "my-topic", "key": "${message_id}"}
```

**gRPC**
```json
{"target": "svc:50051", "service": "com.example.Svc", "method": "Handle", "deadline_ms": 3000}
```

---

### 6.2 内部 gRPC API（节点间）

```protobuf
syntax = "proto3";
package when.internal.v1;

// 消息转发（任意节点 → Master）
service MessageService {
  rpc ForwardWrite(ForwardWriteRequest) returns (ForwardWriteReply) {}
  rpc ForwardCancel(ForwardCancelRequest) returns (ForwardCancelReply) {}
  rpc ForwardQuery(ForwardQueryRequest) returns (ForwardQueryReply) {}
}

message ForwardWriteRequest {
  string tw_id           = 1;
  string msg_id          = 2;
  uint64 expire_ts_ms    = 3;
  string sink_type       = 4;
  string sink_config     = 5;
  bytes  payload         = 6;
  string idempotency_key = 7;
}

// 副本同步（Master → Slave）
service ReplicationService {
  rpc SyncWrite(SyncWriteRequest) returns (SyncWriteReply) {}
  rpc SyncDelete(SyncDeleteRequest) returns (SyncDeleteReply) {}
  rpc SyncCancel(SyncCancelRequest) returns (SyncCancelReply) {}
  rpc FullSync(FullSyncRequest) returns (stream FullSyncChunk) {}
}

message SyncWriteRequest {
  string tw_id        = 1;
  string msg_id       = 2;
  uint64 expire_ts_ms = 3;
  bytes  payload      = 4;
  string sink_type    = 5;
  string sink_config  = 6;
}

message FullSyncChunk {
  repeated SyncWriteRequest messages = 1;
  bool is_last = 2;
}

// Controller 指令
service ControllerService {
  rpc PromoteToMaster(PromoteRequest) returns (PromoteReply) {}
  rpc AssignSlave(AssignSlaveRequest) returns (AssignSlaveReply) {}
}

message PromoteRequest {
  string tw_id       = 1;
  string master_hint = 2;
}
```

---

### 6.3 管理台 API

#### GET /admin/api/v1/cluster — 集群概览

```json
{
  "nodes": [
    {"node_id": "node-1", "ip": "10.0.0.1", "status": "healthy",
     "is_controller": true, "master_count": 2, "slave_count": 1, "pending_messages": 12500}
  ],
  "time_wheels": [
    {"tw_id": "tw-001", "master_node": "node-1", "slave_node": "node-2",
     "status": "running", "pending_messages": 6200}
  ],
  "total_pending": 25000,
  "write_qps": 450,
  "deliver_qps": 380
}
```

#### GET /admin/api/v1/messages — 消息列表（分页）

Query params: `status`, `sink_type`, `created_after`, `created_before`, `page`, `page_size`

#### POST /admin/api/v1/messages/{id}/cancel — 强制取消

#### POST /admin/api/v1/messages/{id}/redeliver — 手动重投（failed 状态）

#### GET /admin/api/v1/metrics/summary — 指标摘要

```json
{
  "write_qps_p1m": 450,
  "deliver_qps_p1m": 380,
  "deliver_success_rate_p1h": 0.9987,
  "delivery_latency_p50_ms": 12,
  "delivery_latency_p95_ms": 98,
  "delivery_latency_p99_ms": 312
}
```

---

## 七、训练营排期

### 7.1 整体节奏

训练营 10 周，目标是交付一个**可生产使用的最小完整版本**。

- **Phase 1（W1~W3）**：单节点端到端跑通
- **Phase 2（W4~W7）**：集群化
- **Phase 3（W8~W10）**：生产就绪

Phase 1 是一切的前提，不能压缩。Phase 2 和 3 的子任务可以降级，但不能整体跳过。

---

### 7.2 周排期

#### W1 — 骨架 + 单层时间轮

Maven 多模块搭建（`when-core` / `when-server` / `when-client`）、gRPC proto 初版、单层内存时间轮（环形数组 + 指针推进）、Spring Boot HTTP 接入层（`POST /api/v1/messages`）、延时消息对象模型。

**交付**：单节点接收延时消息，内存时间轮到期后打印消息内容。

---

#### W2 — 四层时间轮 + Redis 持久化

四层时间轮（L1~L4 级联，降级逻辑）、Redisson 接入（消息体 HSET + 时间索引 SET + TTL）、节点启动从 Redis SCAN 重建时间轮（recover 流程）、单元测试（插入/触发正确性、多层降级）。

**交付**：重启节点消息不丢，四层时间轮覆盖 1s ~ 30d。

---

#### W3 — HttpSink + 完整生命周期

HttpSink（OkHttp 连接池、响应码处理）、SinkDispatcher（SPI 加载）、取消接口、查询接口、重试机制（指数退避重新入轮）、端到端集成测试（提交 → 到期 → HTTP 投递 → 状态查询）。

**交付**：单节点端到端功能完整，curl 可接入验证。

---

#### W4 — ETCD 集群协调

jetcd 接入、节点注册（/when/nodes/{id}）+ Lease 保活、Controller 选举（ETCD 事务 CAS）、Controller Watch /when/nodes/ 感知上下线、时间轮元数据写 ETCD、单元测试（Controller 宕机后重新选举）。

**交付**：3 节点集群启动，ETCD 中可见节点注册和 Controller 选举结果。

---

#### W5 — 消息路由 + 节点间 gRPC 转发

路由层（message_id % timewheel_count）、ForwardWrite / ForwardCancel / ForwardQuery gRPC 实现、集群路由表本地缓存（Watch ETCD 自动更新）、集成测试（消息路由到非本节点 Master 的场景）。

**交付**：3 节点集群，请求任意节点均能正确路由到目标 Master。

---

#### W6 — Master/Slave 副本

ReplicationService gRPC 实现（SyncWrite / SyncDelete / SyncCancel）、Master 写入异步同步 Slave、FullSync（新 Slave 加入时全量拉取）、Controller 监听节点下线 → 向 Slave 发 PromoteToMaster 指令、集成测试（Kill Master，Slave 10s 内接管，消息不丢）。

**交付**：任意节点宕机，消息不丢，Slave 接管调度。

---

#### W7 — 扩缩容 + Rebalance

rebalance 算法、新节点加入触发 Slave 副本迁移、节点 SIGTERM 清洁退出、FullSync 数据同步、集成测试（3→5 节点扩容，5→3 缩容，消息不丢）。

**交付**：集群弹性扩缩容验证通过，rebalance 对业务方无感。

---

#### W8 — KafkaSink + GrpcSink

KafkaSink（KafkaProducer 连接池复用、同步 Produce、key 模板）、GrpcSink（ManagedChannel 复用、TLS 支持）、SPI 机制完善（验证新增一个 MockSink 不改核心代码）、各 Sink 集成测试。

**交付**：三种 Sink 全部跑通，SPI 扩展机制验证。

---

#### W9 — Web 管理台

管理台服务端 API（§6.3 接口）、前端三个页面（集群状态 / 任务列表 / 投递日志）、集群状态数据聚合（ETCD + Metrics 接口）、任务列表分页查询（Redis SCAN + 过滤）、手动取消和重投操作。

**交付**：管理台浏览器可用，能看集群状态、查消息、执行取消。

---

#### W10 — 可观测 + 性能测试 + 文档

Prometheus Metrics 接入（§5.9 指标清单）、结构化日志（trace_id 全链路）、健康检查接口、性能测试（单节点写入 QPS 10,000、投递 QPS 10,000、精度 99% ±1s）、故障测试（Kill Master，接管 ≤ 10s，消息不丢）、README 和接入文档（中英文）。

**交付**：性能报告、故障测试记录、可公开的 GitHub 仓库。

---

### 7.3 交付物汇总

| 周 | 阶段 | 核心交付 |
|----|------|---------|
| W1 | Phase 1 | 单层时间轮 + HTTP 接入骨架 |
| W2 | Phase 1 | 四层时间轮 + Redis 持久化 + recover |
| W3 | Phase 1 | HttpSink + 完整生命周期 + 集成测试 |
| W4 | Phase 2 | ETCD 协调 + Controller 选举 |
| W5 | Phase 2 | 消息路由 + gRPC 转发 |
| W6 | Phase 2 | Master/Slave 副本 + 故障切换 |
| W7 | Phase 2 | 扩缩容 + rebalance |
| W8 | Phase 3 | Kafka Sink + gRPC Sink + SPI |
| W9 | Phase 3 | Web 管理台 |
| W10 | Phase 3 | 可观测 + 性能测试 + 文档 |

### 7.3 风险与兜底

| 风险 | 应对 |
|------|------|
| W6 副本机制比预期复杂，延期 | W7 扩缩容降级为手动 rebalance，自动 rebalance 推后 |
| W9 前端工作量超预期 | 降级为纯 API 交付，前端 UI 作加分项 |
| Redis SCAN recover 超时（数据量极大） | 异步 recover：先接管调度，后台补齐索引 |
| GC 停顿影响时间轮精度 | W10 性能测试验证，必要时调 ZGC 参数或加补偿机制 |
