# Smoke Test Results

> 时间：2026-04-27 11:25:22
> 环境：macOS 15.7.3 / Java 21.0.7 / Spring Boot 3.3.6
> 后端：http://localhost:8080
> 前端：http://localhost:8000（UmiJS dev server，代理 /api 到 8080）

---

## 总结

**5 / 5 通过。**

| # | 接口 | 方法 | 路径 | HTTP | 业务码 | 耗时 | 结果 |
|---|------|------|------|------|--------|------|------|
| T1 | 用户登录 | POST | `/console/v1/auth/login` | 200 | 200 | 5403 ms | ✅ PASS |
| T2 | Prompt 列表 | GET | `/api/prompts` | 200 | 200 | 80 ms | ✅ PASS |
| T3 | Dataset 列表 | GET | `/api/dataset/datasets` | 200 | 200 | 7 ms | ✅ PASS |
| T4 | Evaluator 模板列表 | GET | `/api/evaluator/templates` | 200 | 200 | 7 ms | ✅ PASS |
| T5 | 可观测性总览 | GET | `/api/observability/overview` | 200 | 200 | 142 ms | ✅ PASS |

> T1 首次登录耗时约 5s，为 Argon2id 哈希验证 + 冷启动 Redis 连接，后续请求正常。

---

## 测试详情

### T1 — 用户登录

```
POST /console/v1/auth/login
Body: {"username": "saa", "password": "123456"}

Response 200:
{
  "code": 200,
  "message": "success",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiJ9...",
    ...
  }
}
```

- 默认账号：`saa` / `123456`（初始化脚本写入 agentscope.account 表）
- 返回字段为 `access_token`（snake_case），后续请求用 `Authorization: Bearer <token>`

---

### T2 — Prompt 列表

```
GET /api/prompts?page=1&size=10
Authorization: Bearer <token>

Response 200:
{"code": 200, "message": "success", "data": {"total": 0, "list": []}}
```

---

### T3 — Dataset 列表

```
GET /api/dataset/datasets?page=1&size=10
Authorization: Bearer <token>

Response 200:
{"code": 200, "message": "success", "data": {"total": 0, "list": []}}
```

---

### T4 — Evaluator 模板列表

```
GET /api/evaluator/templates?page=1&size=10
Authorization: Bearer <token>

Response 200:
{"code": 200, "message": "success", "data": {"total": 0, "list": []}}
```

---

### T5 — 可观测性总览

```
GET /api/observability/overview?startTime=<epoch_ms-1h>&endTime=<epoch_ms>
Authorization: Bearer <token>

Response 200:
{"code": 200, "message": "success", "data": {...}}
```

- `startTime` / `endTime` 使用 epoch 毫秒（如 `1745716122000`）

---

## 启动前置条件说明

### 数据库合并（单 datasource 方案）

本次测试采用单 datasource 方案：将 `admin` 库的 schema 导入到 `agentscope` 库，应用统一连接 `agentscope`。

```bash
# 一次性操作（在中间件已启动状态下执行）
mysql -u admin -padmin agentscope < docker/middleware/init/mysql/admin-schema.sql
```

**背景：** 应用内部 MyBatis-Plus 实体（`agentscope` 库）和 JPA 实体（`admin` 库）共用同一个 datasource 配置，
架构上属于技术债（历史单库设计残留）。由于两库表名无重叠，合并到一个 DB 是最低侵入性的本地开发修复方案，
不影响生产双库部署（生产环境配有完整的双 datasource 路由）。

### 启动命令

```bash
java -jar spring-ai-alibaba-admin-server-start/target/spring-ai-alibaba-admin-server-start.jar \
  --spring.profiles.active=dev \
  --spring.datasource.url="jdbc:mysql://localhost:3306/agentscope?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=true&serverTimezone=GMT%2B8" \
  --spring.datasource.username=admin \
  --spring.datasource.password=admin \
  --spring.jpa.properties.jakarta.persistence.jdbc.url="jdbc:mysql://localhost:3306/agentscope?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=true&serverTimezone=GMT%2B8"
```

---

## 待办

- [ ] 配置 AI 模型 API Key，验证 Prompt 调试、Agent 对话等 AI 功能接口
- [ ] 配置双 datasource（`admin` + `agentscope`）以匹配生产架构，替代上述合并方案
- [ ] 补充 App / Knowledge Base / MCP Server 模块接口冒烟测试
