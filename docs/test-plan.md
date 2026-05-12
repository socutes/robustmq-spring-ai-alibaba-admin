# 补测试计划

> 来源：docs/test-gaps.md P0 缺口  
> 排序原则：Characterization Test（改造前锁定现有行为）→ 核心链路集成测试 → 复杂逻辑单元测试  
> 简单 CRUD 不进计划。日期：2026-05-12

---

| 批次 | 缺口 | 测试类型 | 覆盖核心链路 | 场景 | 预期工作量 |
|------|------|---------|------------|------|-----------|
| Batch 1 | G14 | Characterization Test | 链路 8：Trace 可观测性 | 给 `TracingService`（或 ObservabilityController 底层的 Span 树重建逻辑）输入一组 flat SpanList，记录当前代码实际返回的父子树结构，把实际输出转为断言。改造时树重建逻辑若回归，立刻被捕获。 | 0.5 天 |
| Batch 2 | G07 | Characterization Test | 链路 4：Workflow DAG 调度 | 给 `WorkflowService` / `WorkflowInnerService` 输入一个含 3 个节点的线性 DAG（mock LLM 节点），记录节点执行顺序、节点状态流转的实际行为并转为断言。不测 LLM 输出，只测调度框架本身。 | 1 天 |
| Batch 3 | G01 | 集成测试（SpringBootTest） | 链路 1：JWT 鉴权 | 完整 Spring context + 真实 MySQL（Testcontainers）+ 真实 Redis（Testcontainers）：① 正确凭证登录拿到 accessToken；② 错误密码返回 401；③ 携带 accessToken 访问 `/console/v1/accounts/profile` 返回 200；④ 不带 token 访问返回 401。 | 1 天 |
| Batch 4 | G02 | 集成测试（SpringBootTest） | 链路 1：JWT 鉴权（token 轮换） | 同 Batch 3 基础设施：① refresh-token 换新 accessToken 成功；② 旧 accessToken 在 Redis 黑名单写入后访问受保护接口返回 401。 | 0.5 天 |
| Batch 5 | G03 | 集成测试（SpringBootTest） | 链路 3：ApiKey 鉴权 | 完整 context + Testcontainers MySQL：① 创建 ApiKey；② 用有效 ApiKey 调用 `/api/v1/apps/chat/completions`（mock Agent 执行引擎）返回 200；③ 无 Key / 错误 Key 返回 403；④ 确认 JWT 路径不受 ApiKey 拦截器影响（不互相干扰）。 | 1 天 |
| Batch 6 | G04 | 集成测试（SpringBootTest） | 链路 3：Agent 发布状态机 | 完整 context + Testcontainers MySQL：① 创建草稿 App（status=1）；② `publish` 后 status=2，application_version 快照存在；③ 编辑已发布 App 后 status=3；④ 再次 publish 后 status=2，版本号递增。 | 1 天 |
| Batch 7 | G09 | 集成测试（SpringBootTest） | 链路 5：Agent 对话 SSE | 完整 context + mock LLM + mock ES：① `stream=true` 时响应 Content-Type 为 `text/event-stream`；② 能收到至少一帧正文；③ 末帧包含 `status=COMPLETED`；④ `stream=false` 时返回普通 JSON。 | 1 天 |
| Batch 8 | G10 | 单元测试 | 链路 6：Prompt 流式调试 | mock 模型调用：① `{{var}}` 变量正确替换为入参值；② 多变量同时替换；③ 不存在的 promptKey 抛业务异常（而非 NPE）；④ 流帧格式符合 NDJSON 规范（每帧可独立反序列化）。 | 0.5 天 |
| Batch 9 | G12 | 单元测试 | 链路 7：实验状态机 | mock ExperimentRepository：① 创建实验初始 status=DRAFT；② 启动后 status=RUNNING；③ `stop` 将 RUNNING→STOPPED；④ COMPLETED 状态下调 `stop` 抛业务异常；⑤ STOPPED 状态下调 `stop` 幂等（不报错，不重复写）。 | 0.5 天 |
| Batch 10 | G13 | 单元测试 | 链路 7：实验结果幂等写入 | mock ExperimentResultRepository：① 同一 (experimentId, datasetItemId, evaluatorVersionId) 组合第二次消费时不新增行；② 验证幂等检查发生在 Repository 调用之前（避免主键冲突异常穿透到 MQ broker 触发死信）。 | 0.5 天 |

---

## 工作量汇总

| 类型 | 批次 | 合计工作量 |
|------|------|-----------|
| Characterization Test | Batch 1、2 | 1.5 天 |
| 集成测试（SpringBootTest） | Batch 3、4、5、6、7 | 4.5 天 |
| 单元测试 | Batch 8、9、10 | 1.5 天 |
| **总计** | 10 批 | **7.5 天** |

## 基础设施说明

集成测试（Batch 3–7）统一使用 **Testcontainers**，在 `pom.xml` 的 `server-start` 模块引入：

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-testcontainers</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>mysql</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>junit-jupiter</artifactId>
    <scope>test</scope>
</dependency>
```

Redis 可用 `com.redis:testcontainers-redis` 或直连本地 Redis（`application-test.yml` 配置 `SPRING_REDIS_HOST=localhost`，CI 环境通过 GitHub Actions `services.redis` 提供）。
