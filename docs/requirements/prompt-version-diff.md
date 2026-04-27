# Prompt 版本对比（Diff）

> 状态：正式
> 创建时间：2026-04-27
> 关联接口：`GET /api/prompt/version/diff`

**一句话总结：** 在团队多人协作下，支持任意两个 Prompt 版本的内容与元信息对比，用于演进追溯和发布前 review。

---

## 1. 业务目标

支持团队多人协作场景下的 Prompt 演进追溯：任意两个版本之间的 `template`、`variables`、`modelConfig` 内容差异，以及版本元信息（创建时间、状态、创建者），均可通过一次接口调用获取，无需手动切换版本页面对比。

---

## 2. 用户场景

**场景 A — 发布前 review**
工程师修改了 `customer-service` v4 → v5，准备发布到生产。PM 需要核对改了哪些地方，目前只能在两个版本详情页之间反复切换，手动比对 `template` 内容。

**场景 B — 问题回溯**
线上 Prompt `order-summary` 在 v7 之后效果下滑，工程师需要逐版本比对，找到是哪一次修改引入了问题。当前没有 diff 视图，只能在本地手动 diff。

**场景 C — 多人协作冲突解决**
两名工程师各自基于 v3 创建了 v4-alice 和 v4-bob，需要对比差异后决定合并策略。返回的版本元信息（创建时间、状态）帮助团队判断哪个版本更新、哪个已发布。

**当前痛点：**

- `GET /api/prompt/version` 每次只返回单个版本，没有跨版本比较视图
- `PromptVersionDO.previousVersion` 字段已存在（设计时预留 diff 场景），但从未被任何接口消费
- 版本列表接口不返回 `template` 内容，用户须逐个请求详情再手动比对

---

## 3. 接口契约

### 基本信息

| 项 | 值 |
| --- | --- |
| 方法 | `GET` |
| 路径 | `/api/prompt/version/diff` |
| 鉴权 | `Authorization: Bearer <token>`（与其他 `/api/prompt/*` 接口一致） |
| 返回格式 | `Result<PromptVersionDiffResult>` |

### 入参

| 参数名 | 类型 | 必填 | 约束 | 说明 |
| --- | --- | --- | --- | --- |
| `promptKey` | `String` | ✅ | `@NotBlank`；`^[a-zA-Z0-9_-]+$`；长度 1–255 | 与 `PromptCreateRequest.promptKey` 校验规则一致 |
| `versionA` | `String` | ✅ | `@NotBlank`；`^[a-zA-Z0-9._-]+$`；长度 1–32 | 与 `PromptVersionCreateRequest.version` 校验规则一致 |
| `versionB` | `String` | ✅ | `@NotBlank`；`^[a-zA-Z0-9._-]+$`；长度 1–32 | 同上 |

**示例：**

```http
GET /api/prompt/version/diff?promptKey=customer-service&versionA=v3&versionB=v5
```

### 返回结构

**顶层：** `Result<PromptVersionDiffResult>`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `code` | `Integer` | 200 = 成功 |
| `message` | `String` | `"success"` 或错误描述 |
| `data` | `PromptVersionDiffResult` | diff 结果，见下表 |

**`PromptVersionDiffResult`：**

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `promptKey` | `String` | 被比较的 Prompt Key |
| `versionA` | `VersionMeta` | 版本 A 元信息 |
| `versionB` | `VersionMeta` | 版本 B 元信息 |
| `diffs` | `DiffFields` | 各字段的对比结果 |

**`VersionMeta`（版本元信息）：**

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `version` | `String` | 版本号 |
| `status` | `String` | `pre` / `release` |
| `createTime` | `Long` | 创建时间，epoch 毫秒，与现有 `PromptVersionDetail.createTime` 格式一致 |

**`DiffFields`：**

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `template` | `DiffItem` | Prompt 模板内容对比 |
| `variables` | `DiffItem` | 变量列表对比 |
| `modelConfig` | `DiffItem` | 模型参数对比 |

**`DiffItem`：**

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `changed` | `Boolean` | 两版本该字段是否有差异（null 视同空字符串参与比较） |
| `valueA` | `String` | 版本 A 的原始字符串值；字段为 null 时返回 `""` |
| `valueB` | `String` | 版本 B 的原始字符串值；字段为 null 时返回 `""` |

> **设计说明：** 接口返回原始字段值，不在后端生成行级 diff 标注。行级高亮由前端渲染层实现，后端不持有 UI 表达逻辑。

**响应示例：**

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "promptKey": "customer-service",
    "versionA": {
      "version": "v3",
      "status": "release",
      "createTime": 1745000000000
    },
    "versionB": {
      "version": "v5",
      "status": "pre",
      "createTime": 1745100000000
    },
    "diffs": {
      "template": {
        "changed": true,
        "valueA": "你是一名客服，请回答用户问题。\n\n用户问题：{{question}}",
        "valueB": "你是一名专业客服，请简洁准确地回答用户问题。\n\n用户问题：{{question}}\n\n要求：回答不超过200字。"
      },
      "variables": {
        "changed": false,
        "valueA": "[\"question\"]",
        "valueB": "[\"question\"]"
      },
      "modelConfig": {
        "changed": true,
        "valueA": "{\"temperature\": 0.7, \"maxTokens\": 1024}",
        "valueB": "{\"temperature\": 0.3, \"maxTokens\": 512}"
      }
    }
  }
}
```

### 错误码

| HTTP 状态码 | `code` | `message` | 触发条件 |
| --- | --- | --- | --- |
| 400 | 400 | `"参数错误：{字段} 不能为空"` | `promptKey`/`versionA`/`versionB` 为空或格式不符 |
| 400 | 400 | `"versionA 和 versionB 不能相同"` | 两个版本号完全相同 |
| 404 | 404 | `"Prompt 不存在"` | `promptKey` 在 DB 中不存在 |
| 404 | 404 | `"版本 {versionA} 不存在"` | 版本 A 在该 `promptKey` 下找不到 |
| 404 | 404 | `"版本 {versionB} 不存在"` | 版本 B 在该 `promptKey` 下找不到 |
| 500 | 500 | `"An internal error has occurred..."` | 未预期异常 |

> 错误码与 `StudioException` 常量对齐：`INVALID_PARAM=400`、`NOT_FOUND=404`、`SERVER_ERROR=500`。

---

## 4. 边界场景

| # | 场景 | 预期行为 | 依据 |
| --- | --- | --- | --- |
| E01 | `versionA == versionB`（传入相同版本号） | 返回 400，`"versionA 和 versionB 不能相同"` | 所有字段 `changed=false` 无业务意义，且大概率是调用方 bug；代码推断 |
| E02 | `promptKey` 存在，但某个版本不存在 | 返回 404，错误信息明确区分是 versionA 还是 versionB 不存在，如 `"版本 v9 不存在"` | 方便前端精确提示；代码推断 |
| E03 | `promptKey` 本身不存在 | 先查 `prompt` 表，返回 404 `"Prompt 不存在"`，不继续查版本表 | 快速失败，减少无效 DB 查询；代码推断 |
| E04 | 某版本的 `template` / `variables` / `modelConfig` 为 null（历史数据缺失） | null 视同空字符串：`valueA`/`valueB` 返回 `""`，`changed` 基于空字符串参与比较 | **产品决策** |
| E05 | `versionA` 和 `versionB` 属于不同 `promptKey` | 接口设计只有一个 `promptKey`，两版本必须属于同一 Prompt；传入版本号在当前 `promptKey` 下查不到时走 E02 的 404 逻辑 | 跨 Prompt 比较不在本期范围；代码推断 |
| E06 | 两个版本都是 `pre` 状态，或一个 `release` 一个 `pre` | 正常返回，不限制版本状态组合 | `pre` 版本之间的 diff 是合理的 review 场景；代码推断 |
| E07 | `promptKey` 对应的 Prompt 已被软删除 | 允许查 diff，正常返回版本内容 | 历史追溯需要；**产品决策** |
| E08 | `template` 内容极大（LONGTEXT，可达数 MB） | 直接返回完整内容，本期不做大小限制；网络传输性能由调用方承担 | **产品决策** |
| E09 | 版本号大小写，如 `versionA=V3` vs 存储值 `v3` | 不在应用层做 toLowerCase；查询结果依赖 MySQL collation（`admin` 库 `utf8mb4_general_ci`，大小写不敏感），行为与现有 `GET /api/prompt/version` 一致 | **产品决策** |
| E10 | 高并发对同一对版本频繁请求 diff | 纯只读接口，DB 读并发安全；本期不加缓存 | **产品决策** |

---

## 5. 老项目约束

| 约束 | CLAUDE.md 来源 | 对本需求的影响 |
| --- | --- | --- |
| `prompt_version` 表使用 **JPA `@Table`**，实体在 `server-start/entity` 包 | "ORM 混用" | 新查询逻辑必须走 JPA Repository 或 JPQL，不能混用 MyBatis-Plus `BaseMapper`；新 DTO `PromptVersionDiffResult` 不加 `@TableName` |
| 接口传参和关联外键一律用**业务 ID**，不暴露自增主键 | "业务 ID vs 自增主键" | 入参使用 `promptKey + versionA + versionB`，禁止用数据库 `id` 字段作为查询条件 |
| 大多数表用 `status = 0` 表示软删除，直接写 `DELETE` 会破坏数据完整性 | "逻辑删除" | `prompt_version` 当前无 `deleted` 字段；E07 决策允许查已软删除 Prompt 的版本，查询时不过滤 `prompt.status`，仅按 `prompt_key` 查版本表 |
| 统一返回结构：`Result<T> { code, message, data: T }` | "统一返回结构" | `PromptVersionDiffResult` 必须包在 `Result<>` 里返回；错误时用 `Result.error(code, message)`，不裸抛 HTTP 异常 |
| `admin` 库用 JPA，`agentscope` 库用 MyBatis-Plus，注意 DataSource 路由 | "ORM 混用" | `prompt_version` 在 `admin` 库，diff 接口只读 `admin` 库，无跨库操作风险 |

---

## 6. 不在这次范围里

### 本期砍掉（不做）

| 候选项 | 原因 |
| --- | --- |
| 后端生成 unified diff / Myers diff 行级标注 | diff 格式与前端 UI 框架强耦合，前端自行计算性能更好；后端不持有渲染逻辑 |
| 跨 `promptKey` 的版本对比 | 业务语义不清晰，`promptKey` 是版本的命名空间，跨 key 比较无明确含义 |
| 超过 2 个版本的多向对比（v3 vs v4 vs v5） | 界面复杂度指数级增加，当前场景不需要 |
| Diff 结果缓存（Redis） | 当前数据量小；缓存带来的失效一致性问题得不偿失，量上来再做 |
| `versionDescription` 字段的 diff | 非核心内容，改动频率低，意义不大 |
| 细粒度权限控制（仅创建者可查 diff） | 当前无细粒度资源权限体系，等权限体系完善后再加 |

### 留到下期

| 候选项 | 说明 |
| --- | --- |
| Diff 结果导出（PDF / 文本文件下载） | 有审计存档场景，非 MVP 必须 |
| 基于 `previousVersion` 的"一键比对上一版"快捷入口 | `PromptVersionDO.previousVersion` 字段已存在，后端接口已通用（调用方传 `versionA=previousVersion` 即可）；前端加快捷按钮即可，不需要新增后端接口 |
