# add-crud-module

## Description

**触发场景**：需要给 Spring AI Alibaba Admin 新增一个业务资源（如 `Tag`、`Template`、`Workflow`）时触发。你知道资源名、它归属哪个数据库 schema、有哪些字段，其余一切由 skill 推导。

**产出**：以下 7 类文件全部生成，外加 2 个文档的追加更新——

| # | 产物 | 位置 |
|---|------|------|
| 1 | SQL 建表 DDL | `docker/middleware/init/mysql/{schema}-schema.sql` 末尾追加 |
| 2 | Entity 类 | `server-core/.../base/entity/`（admin）或 `server-start/.../entity/`（agentscope） |
| 3 | Mapper 接口 | `server-core/.../base/mapper/`（仅 admin schema） |
| 4 | Service 接口 | `server-core/.../base/service/`（admin）或 `server-start/.../service/`（agentscope） |
| 5 | ServiceImpl | 同 Service 的 `impl/` 子目录 |
| 6 | Controller | `server-start/.../admin/builder/controller/`（admin）或 `server-start/.../admin/controller/`（agentscope） |
| 7 | 文档追加 | `docs/api-list.md`（新增接口节）+ `docs/data-model.md`（新增表节） |

**两条代码路径**（由 `database` 参数决定，不可混用）：
- `admin` schema → MyBatis-Plus（`@TableName`、`BaseMapper`、`ServiceImpl<Mapper, Entity>`）
- `agentscope` schema → JPA（`@Table`、`@Id`、`@GeneratedValue`，Service 不继承 `IService`）

**只汇报，不自动改文档**：步骤 7 生成完所有代码文件后，skill 会列出 `docs/api-list.md` 和 `docs/data-model.md` 需要追加的内容，但**不自动写入**，由人确认后手动或授权追加。

---

## Usage

```
/add-crud-module <moduleName> <database> <fields> [operations]
```

| 参数 | 必填 | 说明 | 示例 |
|------|------|------|------|
| `moduleName` | 是 | 资源名，PascalCase | `Tag`、`Workflow`、`Template` |
| `database` | 是 | `admin` 或 `agentscope` | `admin` |
| `fields` | 是 | 逗号分隔的 `fieldName:JavaType`，不含公共字段 | `name:String,config:String,status:Integer` |
| `operations` | 否 | 默认 `create,list,get,update,delete`；可子集 | `create,list,delete` |

**示例**

```
/add-crud-module Tag admin "tagKey:String,description:String"
/add-crud-module Workflow agentscope "name:String,config:String,status:Integer" create,list,get,update,delete
/add-crud-module Template agentscope "name:String,content:String,variables:String" create,list,get,delete
```

---

## Instructions

When the user runs `/add-crud-module <moduleName> <database> <fields> [operations]`:

### Step 0 — 解析参数，推导命名

从用户输入提取四个参数，然后推导所有后续用到的名字：

```
entityName     = {moduleName}Entity              （e.g. TagEntity）
tableName      = moduleName 转 snake_case         （e.g. tag, workflow_item）
bizIdField     = tableName + "_id"               （e.g. tag_id）
bizIdFieldCC   = bizIdField 转 camelCase          （e.g. tagId）
urlPath        = /console/v1/ + tableName 转 kebab-case + s   （e.g. /console/v1/tags）
operations     = 用户传入，或默认 create,list,get,update,delete
```

**路径常量**（根据 `database` 选择）：

| 变量 | admin | agentscope |
|------|-------|-----------|
| `entityPkg` | `com.alibaba.cloud.ai.studio.core.base.entity` | `com.alibaba.cloud.ai.studio.admin.entity` |
| `mapperPkg` | `com.alibaba.cloud.ai.studio.core.base.mapper` | —（agentscope 不生成 Mapper） |
| `servicePkg` | `com.alibaba.cloud.ai.studio.core.base.service` | `com.alibaba.cloud.ai.studio.admin.service` |
| `serviceImplPkg` | `com.alibaba.cloud.ai.studio.core.base.service.impl` | `com.alibaba.cloud.ai.studio.admin.service.impl` |
| `controllerPkg` | `com.alibaba.cloud.ai.studio.admin.builder.controller` | `com.alibaba.cloud.ai.studio.admin.controller` |
| `entityDir` | `server-core/src/main/java/com/alibaba/cloud/ai/studio/core/base/entity/` | `server-start/src/main/java/com/alibaba/cloud/ai/studio/admin/entity/` |
| `sqlFile` | `docker/middleware/init/mysql/admin-schema.sql` | `docker/middleware/init/mysql/agentscope-schema.sql` |

用 Bash `find` 确认 `entityDir` 真实存在后再继续。若目录不存在，停止并报告实际路径，请用户确认。

---

### Step 1 — 生成 SQL DDL

向 `sqlFile` 末尾追加建表语句。

**admin schema 模板**（使用 backtick 标识符，带 `gmt_create`/`gmt_modified`/`creator`/`modifier`）：

```sql
/******************************************/
/*   TableName = {tableName}              */
/******************************************/
DROP TABLE IF EXISTS `{tableName}`;
CREATE TABLE `{tableName}`
(
    `id`             BIGINT(20) UNSIGNED AUTO_INCREMENT NOT NULL COMMENT 'Primary Key ID',
    `{bizIdField}`   VARCHAR(64)  NOT NULL              COMMENT '{moduleName} business ID',
    `workspace_id`   VARCHAR(64)  NOT NULL              COMMENT 'Workspace ID',
    `account_id`     VARCHAR(64)  NOT NULL              COMMENT 'Creator account ID',
    -- [用户指定字段，每行按 Java 类型映射为 SQL 类型，末尾加 COMMENT]
    -- String   → VARCHAR(255) DEFAULT NULL
    -- Integer  → TINYINT(4)   NOT NULL DEFAULT 1
    -- Long     → BIGINT(20)   DEFAULT NULL
    -- Boolean  → TINYINT(1)   NOT NULL DEFAULT 0
    -- Text/大字段 → LONGTEXT   DEFAULT NULL
    `status`         TINYINT(4)   NOT NULL DEFAULT 1    COMMENT 'Status: 0=deleted, 1=normal',
    `gmt_create`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `gmt_modified`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `creator`        VARCHAR(64)  NOT NULL              COMMENT 'Creator account_id',
    `modifier`       VARCHAR(64)  NOT NULL              COMMENT 'Last modifier account_id',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_{bizIdField}` (`{bizIdField}`)
) ENGINE = InnoDB
  AUTO_INCREMENT = 10000
  DEFAULT CHARSET = utf8mb4
  COMMENT = '{moduleName} table';
```

**agentscope schema 模板**（无 backtick，带 `create_time`/`update_time`/`deleted`）：

```sql
/******************************************/
/*   TableName = {tableName}              */
/******************************************/
DROP TABLE IF EXISTS {tableName};
CREATE TABLE {tableName}
(
    id          BIGINT(20) UNSIGNED AUTO_INCREMENT NOT NULL COMMENT 'Primary Key ID',
    -- [用户指定字段，类型映射同上]
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP              COMMENT 'Create time',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Update time',
    deleted     TINYINT(1)        NOT NULL DEFAULT 0                     COMMENT 'Logical delete: 0=not deleted, 1=deleted',
    PRIMARY KEY (id)
) ENGINE = InnoDB
  AUTO_INCREMENT = 10000
  DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '{moduleName} table';
```

---

### Step 2 — 生成 Entity 类

写到 `{entityDir}/{entityName}.java`。

**admin schema**（MyBatis-Plus，Apache 2.0 文件头）：

```java
/*
 * Copyright 2025 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * ...
 */
package {entityPkg};

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.util.Date;

@Data
@TableName("{tableName}")
public class {entityName} {

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    @TableField("{bizIdField}")
    private String {bizIdFieldCC};

    @TableField("workspace_id")
    private String workspaceId;

    @TableField("account_id")
    private String accountId;

    // [用户指定字段]
    // 多词字段补 @TableField("snake_case_name")

    private Integer status;

    @TableField("gmt_create")
    private Date gmtCreate;

    @TableField("gmt_modified")
    private Date gmtModified;

    private String creator;
    private String modifier;
}
```

**agentscope schema**（JPA，无文件头）：

```java
package {entityPkg};

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "{tableName}")
public class {entityName} {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // [用户指定字段]

    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
```

---

### Step 3 — 生成 Mapper（仅 admin schema）

写到 `server-core/src/main/java/com/alibaba/cloud/ai/studio/core/base/mapper/{moduleName}Mapper.java`：

```java
/*
 * Copyright 2025 ...（Apache 2.0 头）
 */
package {mapperPkg};

import {entityPkg}.{entityName};
import com.baomidou.mybatisplus.core.mapper.BaseMapper;

public interface {moduleName}Mapper extends BaseMapper<{entityName}> {
}
```

agentscope schema 跳过此步骤（JPA 不需要 Mapper）。

---

### Step 4 — 生成 Service 接口

只生成 `operations` 中选中的方法。

**admin schema**（写到 `server-core/.../base/service/{moduleName}Service.java`，继承 `IService`）：

```java
package {servicePkg};

import {entityPkg}.{entityName};
import com.alibaba.cloud.ai.studio.runtime.domain.PagingList;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.IService;
import java.util.List;

public interface {moduleName}Service extends IService<{entityName}> {
    // create  → {entityName} create{moduleName}({entityName} entity);
    // get     → {entityName} get{moduleName}ById(Long id);
    // list    → PagingList<{entityName}> list{moduleName}s(String workspaceId, Page<{entityName}> page);
    // update  → {entityName} update{moduleName}({entityName} entity);
    // delete  → void delete{moduleName}(Long id);
}
```

**agentscope schema**（写到 `server-start/.../service/{moduleName}Service.java`，不继承 `IService`）：

```java
package {servicePkg};

import {entityPkg}.{entityName};
import java.util.List;

public interface {moduleName}Service {
    // 方法签名同上，但无 IService 泛型父接口
}
```

---

### Step 5 — 生成 ServiceImpl

**admin schema**（写到 `server-core/.../base/service/impl/{moduleName}ServiceImpl.java`）：

继承 `ServiceImpl<{moduleName}Mapper, {entityName}>`，实现 Service 接口中选中的方法：

- `create`：
  1. 从 `RequestContextHolder.getRequestContext()` 取 `workspaceId`（null 时回退 `"1"`）和 `accountId`（null 时回退 `"10000"`）
  2. 用 `IdGenerator.idStr()` 生成 `{bizIdFieldCC}`
  3. 设 `gmtCreate`/`gmtModified = new Date()`，`creator`/`modifier = accountId`
  4. 调 `save(entity)`，返回 entity
- `get`：调 `getById(id)`，为 null 时抛 `IllegalArgumentException("{moduleName} not found: " + id)`
- `list`：`LambdaQueryWrapper` 按 `workspaceId eq` 过滤，`orderByDesc(gmtModified)`，调 `page(page, qw)`，返回 `PagingList.builder()...build()`
- `update`：先 `getById` 判存在，更新 `gmtModified = new Date()`、`modifier`，调 `updateById`
- `delete`：调 `removeById(id)`

**agentscope schema**（写到 `server-start/.../service/impl/{moduleName}ServiceImpl.java`）：

不继承 `ServiceImpl`，注入 JPA Repository（若尚不存在，Step 5 末尾提示需创建 `{moduleName}Repository` 接口，继承 `JpaRepository<{entityName}, Long>`）。实现方法同语义，用 Repository 替换 MyBatis-Plus 调用。

两条路径均加 `@Service` 注解，不加 `@Slf4j`（Controller 层记 log 即可）。

---

### Step 6 — 生成 Controller

写到 `{controllerDir}/{moduleName}Controller.java`。

```java
/*
 * Copyright 2025 ...（admin schema 加 Apache 2.0 头；agentscope schema 无头）
 */
package {controllerPkg};

import {entityPkg}.{entityName};
import {servicePkg}.{moduleName}Service;
import com.alibaba.cloud.ai.studio.runtime.domain.PagingList;
import com.alibaba.cloud.ai.studio.runtime.domain.Result;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;  // 仅 admin schema
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequestMapping("{urlPath}")
public class {moduleName}Controller {

    private final {moduleName}Service {moduleName首字母小写}Service;

    public {moduleName}Controller({moduleName}Service service) {
        this.{moduleName首字母小写}Service = service;
    }

    // 根据 operations 只生成选中的方法：

    // create
    @PostMapping
    public Result<{entityName}> create(@RequestBody {entityName} entity) {
        log.info("创建 {moduleName} 请求: {}", entity);
        return Result.success({moduleName首字母小写}Service.create{moduleName}(entity));
    }

    // get
    @GetMapping("/{id}")
    public Result<{entityName}> get(@PathVariable Long id) {
        return Result.success({moduleName首字母小写}Service.get{moduleName}ById(id));
    }

    // list（admin schema 用 Page；agentscope 可用 pageNum/pageSize 手动构造）
    @GetMapping("/page")
    public Result<PagingList<{entityName}>> list(
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "10") long size) {
        Page<{entityName}> page = new Page<>(current, size);
        return Result.success({moduleName首字母小写}Service.list{moduleName}s("1", page));
    }

    // update
    @PutMapping("/{id}")
    public Result<{entityName}> update(@PathVariable Long id, @RequestBody {entityName} entity) {
        entity.setId(id);
        return Result.success({moduleName首字母小写}Service.update{moduleName}(entity));
    }

    // delete
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        {moduleName首字母小写}Service.delete{moduleName}(id);
        return Result.success(null);
    }
}
```

---

### Step 7 — 汇报文档变更（只汇报，不写入）

生成完所有代码文件后，输出以下两段内容，**不自动修改任何文档文件**：

#### 7a. `docs/api-list.md` 需要追加的内容

```markdown
## N. {moduleName} 管理

**Controller**：`{moduleName}Controller`  **前缀**：`{urlPath}`

| 方法 | 路径 | 说明 | 主要入参 | 返回 |
|------|------|------|---------|------|
[根据 operations 生成行，格式与现有 api-list.md 保持一致]
| POST   | `/`       | 创建 {moduleName}         | body: `{entityName}`                            | `Result<{entityName}>` |
| GET    | `/{id}`   | 查询 {moduleName} 详情    | path: `id`                                      | `Result<{entityName}>` |
| GET    | `/page`   | 分页查询 {moduleName} 列表 | query: `current, size`                          | `Result<PagingList<{entityName}>>` |
| PUT    | `/{id}`   | 更新 {moduleName}         | path: `id`；body: `{entityName}`                | `Result<{entityName}>` |
| DELETE | `/{id}`   | 删除 {moduleName}         | path: `id`                                      | `Result<Void>` |
```

#### 7b. `docs/data-model.md` 需要追加的内容

指明追加位置（`## admin schema` 节 或 `## agentscope schema` 节末尾），然后输出：

```markdown
### {N}. {tableName} — {moduleName}

{moduleName} 主表。

| 字段 | 类型 | 说明 |
|------|------|------|
| 🔑 id | BIGINT UNSIGNED AUTO_INCREMENT | 物理主键 |
| {bizIdField} | VARCHAR(64) UNIQUE NOT NULL | 业务主键 |
| workspace_id | VARCHAR(64) NOT NULL | 工作空间 |
| account_id | VARCHAR(64) NOT NULL | 所属账号 |
[用户指定字段，每行列出字段名、SQL 类型、一句话说明]
| status | TINYINT(4) | 📋 `0`=已删除 `1`=正常  （admin schema）|
| create_time / update_time | DATETIME | 时间戳  （agentscope schema）|
| deleted | TINYINT(1) | 逻辑删除标志  （agentscope schema）|
| gmt_create / gmt_modified | DATETIME | 时间戳  （admin schema）|
| creator / modifier | VARCHAR(64) | 操作者 account_id  （admin schema）|
```

---

### Step 8 — 最终汇总

输出所有已生成/修改文件的完整路径列表，以及需要手工完成的后续步骤：

```
已生成文件：
  docker/middleware/init/mysql/{schema}-schema.sql  （末尾追加 DDL）
  {entityDir}/{entityName}.java
  {mapperDir}/{moduleName}Mapper.java               （仅 admin schema）
  {serviceDir}/{moduleName}Service.java
  {serviceImplDir}/{moduleName}ServiceImpl.java
  {controllerDir}/{moduleName}Controller.java

文档变更待确认（见 Step 7 输出，确认后手动追加或告知我写入）：
  docs/api-list.md  — 新增 "{moduleName} 管理" 节
  docs/data-model.md — 在 {schema} 节末尾新增 "{tableName}" 表

手工后续步骤：
  1. 在本地 MySQL 执行新增的 DDL（或 docker compose down -v && up -d 重建）
  2. agentscope schema 若 ServiceImpl 用到 JPA Repository，需创建：
     {serviceDir}/repository/{moduleName}Repository.java
     （继承 JpaRepository<{entityName}, Long>）
  3. 确认 @MapperScan 已包含新 Mapper 包（admin schema）：
     server-start 启动类 @MapperScan("com.alibaba.cloud.ai.studio.core.base.mapper")
     现有配置已覆盖，无需修改。
```

---

## Notes

- **不要混用 ORM**：`admin` schema 只走 MyBatis-Plus，`agentscope` schema 只走 JPA，两套代码路径不对称是设计决策，不是 bug。
- **business ID 生成**：admin schema 用 `IdGenerator.idStr()`（Sequence 雪花算法，返回 String）；如需特定前缀参考 `IdGenerator.generateAgentId()` 的写法自行扩展。
- **workspaceId 回退**：从 `RequestContextHolder.getRequestContext()` 取，为 null 时回退 `"1"`，与 `AgentSchemaServiceImpl` 现有行为一致。
- **不生成测试类**，除非用户明确要求。
- **文件头**：admin schema（server-core 模块）加 Apache 2.0 License 头；agentscope schema（server-start 模块）按 `PromptDO.java` 风格，无文件头。
- **路径推导有歧义时**：先用 `Bash find` 确认目录存在，再写入，不要猜测路径。

---

## allowed-tools

`Read`, `Write`, `Bash`（仅 `find` 确认目录是否存在）

不使用 `Edit`（全部是新文件）；不使用 `Agent`；不使用 `WebFetch`/`WebSearch`。
