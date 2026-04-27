# add-crud-module

给 Spring AI Alibaba Admin 项目新增一套标准 CRUD 模块骨架。

## Usage

```
/add-crud-module <moduleName> <database> <fields> [operations]
```

**参数说明**

| 参数 | 必填 | 说明 | 示例 |
|------|------|------|------|
| `moduleName` | 是 | 资源名称，PascalCase | `Workflow`、`Template` |
| `database` | 是 | `admin` 或 `agentscope` | `agentscope` |
| `fields` | 是 | 逗号分隔的 `fieldName:type` 列表 | `name:String,config:String,status:Integer` |
| `operations` | 否 | 逗号分隔，默认全选 | `create,list,get,update,delete` |

**示例**

```
/add-crud-module Workflow agentscope "name:String,config:String,status:Integer"
/add-crud-module Tag admin "tagKey:String,description:String" create,list,delete
```

## What this skill does

根据 `database` 参数走两条不同的代码路径：

- **agentscope**：MyBatis-Plus（`@TableName`、`BaseMapper`、`ServiceImpl<Mapper, Entity>`），包路径 `server-core/.../base/`
- **admin**：JPA（`@Table`、`@Id`、`@GeneratedValue`），包路径 `server-start/.../admin/`

生成 7 类产物，并更新 2 个文档文件。

## Instructions

When the user runs `/add-crud-module <moduleName> <database> <fields> [operations]`:

### Step 0 — 解析参数

1. 从用户输入中提取 `moduleName`、`database`、`fields`、`operations`（默认 `create,list,get,update,delete`）
2. 推导命名：
   - `entityName` = `${moduleName}Entity`（agentscope）或 `${moduleName}DO`（admin）
   - `tableName` = `moduleName` 转 snake_case
   - `bizIdField` = `${moduleName 首字母小写}_id`（如 `workflow_id`）
   - `urlPath` = `/console/v1/${tableName 转 kebab-case}s`
   - `packageBase`:
     - agentscope → `com.alibaba.cloud.ai.studio.core.base`
     - admin → `com.alibaba.cloud.ai.studio.admin`
3. 读一个同 database 的现有模块作结构参考确认路径：
   - agentscope 参考：`AgentSchemaEntity` / `AgentSchemaService` / `AgentSchemaServiceImpl` / `AgentSchemaMapper` / `AgentSchemaController`
   - admin 参考：`PromptDO` / `PromptController`

### Step 1 — 生成 SQL DDL

在用户确认 `docker/middleware/init/mysql/` 对应的 SQL 文件末尾追加 DDL。

**agentscope** 表模板（追加到 `agentscope-schema.sql`）：
```sql
/******************************************/
/*   table = {tableName}                  */
/******************************************/
DROP TABLE IF EXISTS `{tableName}`;
CREATE TABLE `{tableName}`
(
    `id`             BIGINT(20) UNSIGNED AUTO_INCREMENT NOT NULL COMMENT 'pk',
    `{bizIdField}`   VARCHAR(64)  NOT NULL COMMENT '{moduleName} id',
    `workspace_id`   VARCHAR(64)  NOT NULL COMMENT 'workspace id',
    `account_id`     VARCHAR(64)  NOT NULL COMMENT 'creator account id',
    -- [用户指定字段，每行加 COMMENT]
    `status`         TINYINT(4)   NOT NULL DEFAULT 1 COMMENT 'status: 0-deleted, 1-normal',
    `gmt_create`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `gmt_modified`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `creator`        VARCHAR(64)  NOT NULL COMMENT 'creator uid',
    `modifier`       VARCHAR(64)  NOT NULL COMMENT 'modifier uid',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_{bizIdField}` (`{bizIdField}`)
) ENGINE = InnoDB
  AUTO_INCREMENT = 10000
  DEFAULT CHARSET = utf8mb4
  COMMENT = '{moduleName} table';
```

**admin** 表模板（追加到 `admin-schema.sql`）：
```sql
/******************************************/
/*   TableName = {tableName}              */
/******************************************/
DROP TABLE IF EXISTS {tableName};
CREATE TABLE {tableName}
(
    id          BIGINT(20) UNSIGNED AUTO_INCREMENT NOT NULL COMMENT 'Primary Key ID',
    -- [用户指定字段，每行加 COMMENT]
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Create time',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Update time',
    deleted     TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Logical delete: 0-not deleted, 1-deleted',
    PRIMARY KEY (id)
) ENGINE = InnoDB
  AUTO_INCREMENT = 10000
  DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci
  COMMENT = '{moduleName} table';
```

### Step 2 — 生成 Entity

**agentscope**（写到 `server-core/src/main/java/com/alibaba/cloud/ai/studio/core/base/entity/{entityName}.java`）：

```java
/*
 * Copyright 2025 the original author or authors.
 * Licensed under the Apache License, Version 2.0
 */
package com.alibaba.cloud.ai.studio.core.base.entity;

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
    private String {bizIdField camelCase};

    @TableField("workspace_id")
    private String workspaceId;

    @TableField("account_id")
    private String accountId;

    // [用户指定字段，驼峰命名，String/Integer/Long 等直接声明]
    // 多词字段加 @TableField("snake_case_name")

    private Integer status;

    @TableField("gmt_create")
    private Date gmtCreate;

    @TableField("gmt_modified")
    private Date gmtModified;

    private String creator;
    private String modifier;
}
```

**admin**（写到 `server-start/src/main/java/com/alibaba/cloud/ai/studio/admin/entity/{entityName}.java`）：

```java
package com.alibaba.cloud.ai.studio.admin.entity;

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

### Step 3 — 生成 Mapper（仅 agentscope）

写到 `server-core/src/main/java/com/alibaba/cloud/ai/studio/core/base/mapper/{moduleName}Mapper.java`：

```java
package com.alibaba.cloud.ai.studio.core.base.mapper;

import com.alibaba.cloud.ai.studio.core.base.entity.{entityName};
import com.baomidou.mybatisplus.core.mapper.BaseMapper;

public interface {moduleName}Mapper extends BaseMapper<{entityName}> {
}
```

### Step 4 — 生成 Service 接口

**agentscope**（写到 `server-core/.../service/{moduleName}Service.java`）：

根据 `operations` 参数只生成被选中的方法：

```java
package com.alibaba.cloud.ai.studio.core.base.service;

import com.alibaba.cloud.ai.studio.core.base.entity.{entityName};
import com.alibaba.cloud.ai.studio.runtime.domain.PagingList;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.IService;
import java.util.List;

public interface {moduleName}Service extends IService<{entityName}> {

    // create → create{moduleName}({entityName}) : {entityName}
    // get    → get{moduleName}ById(Long id) : {entityName}
    // list   → list{moduleName}(String workspaceId, Page<{entityName}> page) : PagingList<{entityName}>
    // update → update{moduleName}({entityName}) : {entityName}
    // delete → delete{moduleName}(Long id) : void
}
```

**admin**：Service 接口写到 `server-start/.../service/{moduleName}Service.java`，不继承 `IService`，方法签名相同。

### Step 5 — 生成 ServiceImpl

**agentscope**（写到 `server-core/.../service/impl/{moduleName}ServiceImpl.java`）：

- 继承 `ServiceImpl<{moduleName}Mapper, {entityName}>`
- `create` 方法：从 `RequestContextHolder.getRequestContext()` 取 `workspaceId`、`accountId`；用 `IdGenerator.uuid32()` 生成 `bizIdField`；设 `gmtCreate`、`gmtModified`、`creator`、`modifier`；调 `save(entity)`
- `update` 方法：先 `getById` 判存在，更新 `gmtModified`、`modifier`，调 `updateById`
- `delete` 方法：调 `removeById`
- `get` 方法：调 `getById`
- `list` 方法：`LambdaQueryWrapper` 按 `workspaceId` 过滤，`orderByDesc(gmtModified)`，调 `page(page, queryWrapper)` 返回 `PagingList`

**admin**：ServiceImpl 写到 `server-start/.../service/impl/{moduleName}ServiceImpl.java`，不继承 `ServiceImpl`，用 JPA Repository 或现有 admin 侧的数据访问方式。

### Step 6 — 生成 Controller

**agentscope** 写到 `server-start/src/main/java/com/alibaba/cloud/ai/studio/admin/builder/controller/{moduleName}Controller.java`：

**admin** 写到 `server-start/src/main/java/com/alibaba/cloud/ai/studio/admin/controller/{moduleName}Controller.java`：

```java
package com.alibaba.cloud.ai.studio.admin.[builder.]controller;

import ...;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequestMapping("{urlPath}")
public class {moduleName}Controller {

    private final {moduleName}Service {moduleName 首字母小写}Service;

    public {moduleName}Controller({moduleName}Service service) {
        this.{moduleName 首字母小写}Service = service;
    }

    // 根据 operations 参数只生成被选中的方法：

    // create → @PostMapping  → Result<{entityName}>
    // list   → @GetMapping("/page") → Result<PagingList<{entityName}>>
    // get    → @GetMapping("/{id}") → Result<{entityName}>
    // update → @PutMapping("/{id}") → Result<{entityName}>
    // delete → @DeleteMapping("/{id}") → Result<Void>

    // 每个方法：
    // - log.info("...请求: {}", param)
    // - RequestContext context = RequestContextHolder.getRequestContext()（agentscope）
    // - 调 Service 方法
    // - return Result.success(data)
}
```

### Step 7 — 更新 docs/api-list.md

在对应模块章节末尾（或新建章节）追加：

```markdown
## N. {moduleName} 管理

**Base path：** `{urlPath}`

| 方法 | 路径 | 说明 |
|------|------|------|
[根据 operations 生成行]

[每个 operation 的入参/返回说明]
```

### Step 8 — 更新 docs/data-model.md

在对应数据库节（Admin 库 或 Agentscope 库）末尾追加：

```markdown
### {tableName}

{moduleName} 主表。

| 字段 | 类型 | 说明 |
|------|------|------|
| **id** 🔑 | BIGINT UNSIGNED AI | 主键 |
| {bizIdField} 🔐 | VARCHAR(64) | 业务唯一 ID |
[用户指定字段]
| status | TINYINT(4) | `0` 已删除，`1` 正常 |
| gmt_create / gmt_modified | DATETIME | 创建/更新时间 |
```

### Step 9 — 汇报

列出所有已生成/已修改的文件路径，以及需要手工完成的后续步骤：

- 若 admin 侧需要 JPA Repository，提示创建位置
- 提示在 Spring Boot 启动类上确认 `@MapperScan` 包含新 Mapper（agentscope）
- 提示将新表 DDL 在本地 MySQL 执行一次

## Notes

- 不要生成测试类，除非用户明确要求
- 不硬编码 workspaceId，从 `RequestContextHolder` 取；若 context 为 null 回退到 `"1"`（保持与现有代码一致）
- 所有文件头加 Apache 2.0 License 注释（agentscope 侧）；admin 侧按现有文件风格决定是否加
- 文件路径推导若有歧义，先用 Bash find 确认目录存在，再写入
