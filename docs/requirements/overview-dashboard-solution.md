# Overview 数据总览页 — 技术方案（定稿）

> 状态：方案定稿，待实施
> 关联需求：docs/requirements/overview-dashboard.md
> 关联影响：docs/requirements/overview-dashboard-impact.md

---

## 1. 一句话概要

新增 `GET /api/dashboard/overview` 接口，聚合 admin + agentscope 两个数据库的统计数据，Redis 缓存 5 分钟，前端新增 `/overview` 页面展示 6 张指标卡、实验状态图、Top Prompt 柱状图、最近活动时间线、知识库索引进度。

---

## 2. 后端方案

### 2.1 目录结构

```
spring-ai-alibaba-admin-server-start/src/main/java/
└── com/alibaba/cloud/ai/studio/admin/
    ├── controller/
    │   └── DashboardController.java          # 新建
    ├── service/
    │   ├── DashboardService.java             # 新建
    │   └── impl/
    │       └── DashboardServiceImpl.java     # 新建
    └── dto/
        ├── DashboardOverviewResult.java      # 新建（顶层）
        └── dashboard/
            ├── PromptsStats.java
            ├── PromptVersionsStats.java
            ├── ExperimentStats.java
            ├── DatasetsStats.java
            ├── KnowledgeBasesStats.java
            ├── ModelStats.java
            ├── ProviderCount.java
            ├── RecentActivityItem.java
            ├── TopPromptItem.java
            └── DocumentIndexStatusItem.java
```

### 2.2 Controller

```java
@RestController
@RequestMapping("/api/dashboard")
public class DashboardController {

    private final DashboardService dashboardService;

    @GetMapping("/overview")
    public Result<DashboardOverviewResult> overview() {
        return Result.success(dashboardService.getOverview());
    }
}
```

### 2.3 Service 实现核心逻辑

```java
@Service
public class DashboardServiceImpl implements DashboardService {

    private static final String CACHE_KEY = "dashboard:overview";
    private static final long CACHE_TTL_SECONDS = 300;

    @Autowired private RedissonClient redisson;
    // 各 Mapper 注入...

    @Override
    public DashboardOverviewResult getOverview() {
        RBucket<DashboardOverviewResult> bucket = redisson.getBucket(CACHE_KEY);
        DashboardOverviewResult cached = bucket.get();
        if (cached != null) return cached;

        DashboardOverviewResult result = buildOverview();
        bucket.set(result, Duration.ofSeconds(CACHE_TTL_SECONDS));
        return result;
    }

    private DashboardOverviewResult buildOverview() {
        // 并行查询各模块（后期优化，初期串行即可）
        return DashboardOverviewResult.builder()
            .prompts(buildPromptsStats())
            .promptVersions(buildPromptVersionsStats())
            .experiments(buildExperimentStats())
            .datasets(buildDatasetsStats())
            .knowledgeBases(buildKnowledgeBasesStats())
            .models(buildModelStats())
            .recentActivity(buildRecentActivity())
            .topPrompts(buildTopPrompts())
            .documentIndexStatus(buildDocumentIndexStatus())
            .build();
    }
}
```

### 2.4 关键 SQL

#### Prompt 本月新增
```xml
<select id="countByMonth" resultType="int">
    SELECT COUNT(*) FROM prompt
    WHERE DATE_FORMAT(create_time, '%Y-%m') = DATE_FORMAT(NOW(), '%Y-%m')
    AND status != 0
</select>
```

#### PromptVersion 按状态分组
```xml
<select id="countGroupByStatus" resultType="map">
    SELECT status, COUNT(*) as cnt FROM prompt_version
    GROUP BY status
</select>
```

#### Experiment 按状态分组
```xml
<select id="countGroupByStatus" resultType="map">
    SELECT status, COUNT(*) as cnt FROM experiment
    WHERE deleted = 0
    GROUP BY status
</select>
```

#### Dataset 总条目数（关联 dataset_item）
```xml
<select id="countTotalItems" resultType="int">
    SELECT COUNT(*) FROM dataset_item di
    INNER JOIN dataset d ON di.dataset_id = d.id
    WHERE d.deleted = 0 AND di.deleted = 0
</select>
```

#### 最近活动（近 20 条，union 三张表）

初期用 UNION ALL 查近期事件，按 timestamp 倒序取 20 条：

```xml
<select id="selectRecentActivity" resultType="...">
    (SELECT 'PROMPT_VERSION_PUBLISHED' as event_type,
            pv.prompt_key as entity_key,
            pv.version as entity_version,
            pv.create_time as ts
     FROM prompt_version pv ORDER BY pv.create_time DESC LIMIT 10)
    UNION ALL
    (SELECT 'EXPERIMENT_STATUS_CHANGED',
            e.name, e.status, e.update_time
     FROM experiment e WHERE e.deleted = 0 ORDER BY e.update_time DESC LIMIT 10)
    ORDER BY ts DESC LIMIT 20
</select>
```

### 2.5 跨库查询注意事项

KnowledgeBase、Document、Model 在 agentscope 库，对应 Mapper 已在 `server-runtime` 模块中。`DashboardServiceImpl` 在 `server-start` 模块，直接 `@Autowired` 这些 Mapper 即可，DataSource 路由由 MyBatis-Plus 的多数据源配置自动处理（参考 `ModelConfigBridgeServiceImpl` 的现有做法）。

---

## 3. 前端方案

### 3.1 目录结构

```
frontend/packages/main/src/legacy/
├── services/
│   └── dashboard/
│       ├── index.ts          # getDashboardOverview()
│       └── typing.ts         # TS 类型声明
└── pages/
    └── overview/
        ├── overview.jsx      # 主页面
        └── components/
            ├── StatsCards.jsx
            ├── ExperimentStatusChart.jsx
            ├── TopPromptsBar.jsx
            ├── RecentActivity.jsx
            └── DocumentIndexStatus.jsx
```

### 3.2 主页面数据流

```jsx
// overview.jsx
const OverviewPage = () => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    DashboardAPI.getDashboardOverview()
      .then(res => { if (res.code === 200) setData(res.data); })
      .finally(() => setLoading(false));
  }, []);

  return (
    <Spin spinning={loading}>
      <Space direction="vertical" size={24} style={{ width: '100%', padding: 24 }}>
        <StatsCards data={data} />
        <Row gutter={24}>
          <Col span={10}><ExperimentStatusChart data={data?.experiments} /></Col>
          <Col span={14}><TopPromptsBar data={data?.topPrompts} /></Col>
        </Row>
        <Row gutter={24}>
          <Col span={12}><RecentActivity data={data?.recentActivity} /></Col>
          <Col span={12}><DocumentIndexStatus data={data?.documentIndexStatus} /></Col>
        </Row>
      </Space>
    </Spin>
  );
};
```

### 3.3 指标卡

用 antd `Card` + `Statistic`，不引入新依赖：

```jsx
// StatsCards.jsx
const CARDS = [
  { title: 'Prompt 总数', key: 'prompts', mainKey: 'total', subKey: 'addedThisMonth', subLabel: '本月新增', icon: <FileTextOutlined /> },
  { title: 'Prompt 版本', key: 'promptVersions', mainKey: 'total', subLabel: 'release / pre', icon: <BranchesOutlined /> },
  // ...
];
```

### 3.4 实验状态图

不引入 echarts，用 antd `Progress` 多段或自定义 SVG 饼图，颜色映射：

| 状态 | 颜色 |
|------|------|
| COMPLETED | `#52c41a` |
| RUNNING | `#1890ff` |
| FAILED | `#ff4d4f` |
| DRAFT | `#8c8c8c` |
| STOPPED | `#faad14` |

### 3.5 路由与菜单

**App.jsx** 新增：
```jsx
import OverviewPage from './pages/overview/overview';
// ...
<Route path="/overview" element={<OverviewPage />} />
```

**侧边栏菜单**（需确认具体文件后修改）：
```jsx
{ key: '/overview', label: '总览', icon: <DashboardOutlined /> }
```
放在菜单列表第一项。

---

## 4. 接口 mock 方案（并行开发用）

后端未完成时，前端可在 `getDashboardOverview` 内硬编码 mock 数据：

```ts
export async function getDashboardOverview() {
  if (process.env.NODE_ENV === 'development' && USE_MOCK) {
    return { code: 200, data: MOCK_OVERVIEW_DATA };
  }
  return request(...);
}
```

---

## 5. 实施顺序

| 步骤 | 内容 | 工作量 | 可并行 |
|------|------|--------|--------|
| 1 | 建后端 DTO（P01-P10） | 1.5h | 否 |
| 2 | 后端 Mapper 新增 COUNT 方法（P14-P17） | 2h | 与步骤 1 并行 |
| 3 | 实现 DashboardService + Controller（P11-P13） | 3h | 依赖步骤 1、2 |
| 4 | 前端类型 + API 函数（P18-P19） | 0.5h | 依赖步骤 3 接口定型 |
| 5 | 前端各 Section 组件（P21-P25） | 3h | 可用 mock 并行于步骤 3 |
| 6 | 前端主页 + 路由 + 菜单（P20、P26-P27） | 1h | 依赖步骤 5 |
| 7 | 联调、Redis 缓存验证 | 1h | 依赖步骤 3、6 |
| 8 | 文档更新（P28-P29） | 0.5h | 随时 |

**合计约 12.5 小时，实际并行可缩短到 8-9 小时。**

---

## 6. 关键决策记录

| 决策 | 结论 | 理由 |
|------|------|------|
| 是否引入 echarts | **不引入** | 管理后台体量不需要完整图表库，antd 现有组件够用，减少包体积 |
| 缓存粒度 | **整体缓存 5 分钟** | 各模块数据独立缓存复杂度高，且 Overview 对实时性要求低，整体缓存更简单 |
| 最近活动来源 | **MySQL UNION，不引入 ES** | 活动数据本身在 MySQL，避免引入跨存储依赖 |
| 实时刷新 | **不做，手动刷新** | 管理后台低频使用，轮询或 SSE 过度设计 |
| 时间范围筛选 | **第一期不做** | 减少 API 复杂度，后续按需增加 `?month=YYYY-MM` 参数 |
