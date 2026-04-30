# Overview 数据总览页

> 状态：需求定稿
> 创建时间：2026-04-30
> 关联接口：`GET /api/dashboard/overview`

**一句话总结：** 在平台首页新增 Overview 面板，聚合展示 Prompt、数据集、评估、实验、应用、知识库、模型等各模块的关键指标，让用户打开平台第一眼就能掌握整体运行状态。

---

## 1. 业务目标

平台目前每个功能模块相互独立，用户无法在一个位置看到"整体跑了多少 Prompt、有多少实验在跑、知识库索引了多少文档"。Overview 页解决以下问题：

- **快速感知**：运营、PM、工程师打开平台时，不需要逐页切换就能掌握关键数量和状态
- **异常发现**：实验失败率高、文档索引积压等问题在 Overview 能第一时间暴露
- **上线决策辅助**：Prompt 版本 pre/release 分布、实验通过率等数据支撑发布判断

---

## 2. 用户场景

**场景 A — 运营早会**
运营每天上班第一件事：看有没有新增 Prompt、有没有实验跑完、知识库文档有没有卡在索引中。现在要逐个模块翻，Overview 一页搞定。

**场景 B — 上线前 checklist**
工程师准备把 `customer-service` v5 发布到生产，打开 Overview 确认：目前 release 版本数量、实验通过率趋势、模型启用状态是否正常。

**场景 C — 新成员了解平台规模**
新加入团队的工程师想快速了解"这个平台有多少 Prompt、跑了多少实验"，Overview 提供最直观的数字。

---

## 3. 页面内容规划

### 3.1 指标卡（Stats Cards）

顶部一行 6 张卡片，每张显示一个核心数量 + 环比变化（可选）：

| 卡片 | 主数字 | 副信息 |
|------|--------|--------|
| Prompt 总数 | 全量 promptKey 数 | 本月新增 N 个 |
| Prompt 版本 | 全量版本数 | release / pre 各几个 |
| 实验 | 全量 experiment 数 | 运行中 N 个 |
| 数据集 | 全量 dataset 数 | 数据条目总数 |
| 知识库 | 全量 knowledge base 数 | 文档总数 |
| 模型 | 已启用模型数 / 总数 | 按 provider 分布 |

### 3.2 实验状态分布（Experiment Status Pie）

饼图展示 DRAFT / RUNNING / COMPLETED / FAILED / STOPPED 各占比，点击可跳转到实验列表并自动筛选该状态。

### 3.3 Prompt 版本状态分布（Version Status Bar）

横向柱状图，按 promptKey 展示 pre 和 release 版本数量，取最近活跃的 Top 10 Prompt（按 updateTime 倒序）。

### 3.4 最近活动（Recent Activity）

时间线列表，展示最近 20 条事件，包括：
- 新建 Prompt / 发布版本
- 实验状态变更（开始 / 完成 / 失败）
- 知识库文档索引完成

每条记录：时间戳 + 事件描述 + 相关实体 Key 的跳转链接。

### 3.5 知识库文档索引状态（Document Index Status）

进度条组，按知识库分组，显示：待索引 / 索引中 / 已完成 / 失败 的文档数量。

---

## 4. 不做什么

- 不做实时数据（WebSocket/SSE 推送），所有数据点开页面时静态加载，手动刷新
- 不做 token 用量统计（已有 `/api/observability/overview` 覆盖，不重复建设）
- 不做用户行为分析（登录频次、操作日志聚合）
- 不做时间范围筛选（第一期固定展示全量数据 + 本月新增）
- 不做数据导出

---

## 5. 接口契约

### 5.1 基本信息

| 项 | 值 |
|----|-----|
| 方法 | `GET` |
| 路径 | `/api/dashboard/overview` |
| 鉴权 | `Authorization: Bearer <token>` |
| 返回格式 | `Result<DashboardOverviewResult>` |
| 缓存策略 | Redis 缓存 5 分钟，key = `dashboard:overview` |

### 5.2 返回结构

```json
{
  "code": 200,
  "data": {
    "prompts": {
      "total": 42,
      "addedThisMonth": 8
    },
    "promptVersions": {
      "total": 187,
      "releaseCount": 95,
      "preCount": 92
    },
    "experiments": {
      "total": 31,
      "runningCount": 3,
      "completedCount": 21,
      "failedCount": 4,
      "draftCount": 2,
      "stoppedCount": 1
    },
    "datasets": {
      "total": 15,
      "totalItems": 8420
    },
    "knowledgeBases": {
      "total": 6,
      "totalDocuments": 312,
      "indexingCount": 5,
      "failedCount": 2
    },
    "models": {
      "total": 18,
      "enabledCount": 12,
      "byProvider": [
        { "provider": "dashscope", "count": 8, "enabledCount": 6 },
        { "provider": "openai", "count": 6, "enabledCount": 4 },
        { "provider": "deepseek", "count": 4, "enabledCount": 2 }
      ]
    },
    "recentActivity": [
      {
        "eventType": "PROMPT_VERSION_PUBLISHED",
        "entityKey": "customer-service",
        "entityVersion": "v5",
        "description": "发布 Prompt customer-service v5（release）",
        "timestamp": 1746000000000
      }
    ],
    "topPrompts": [
      {
        "promptKey": "customer-service",
        "releaseVersion": "v5",
        "preVersion": "v6",
        "updateTime": 1746000000000
      }
    ],
    "documentIndexStatus": [
      {
        "kbId": "kb-001",
        "kbName": "产品手册",
        "pendingCount": 2,
        "processingCount": 1,
        "completedCount": 45,
        "failedCount": 0
      }
    ]
  }
}
```

### 5.3 错误码

| code | 说明 |
|------|------|
| 200 | 成功 |
| 401 | 未登录或 token 过期 |
| 500 | 服务端聚合查询异常 |

---

## 6. 验收标准

1. 打开 Overview 页，6 张指标卡正确展示总数和月度新增
2. 实验状态饼图数量之和等于实验总数
3. 点击饼图的某个状态，跳转到实验列表并自动带上该状态的筛选条件
4. 最近活动列表展示最新的 20 条事件，点击实体 Key 可跳转对应详情页
5. 知识库索引状态各分组数量之和等于该知识库文档总数
6. 页面加载时间 < 2s（含接口响应时间）
7. Redis 缓存命中时接口响应 < 100ms
