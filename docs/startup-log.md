# 应用启动日志

> 时间：2026-04-27
> 环境：macOS 15.7.3 / Java 21.0.7 / Maven 3.9.9 / Node 20.20.2

---

## 最终结果

**启动成功。** 应用监听 `http://localhost:8080`，启动耗时约 15 秒。

| 地址 | 说明 |
|------|------|
| http://localhost:8080 | 控制台主界面 |
| http://localhost:8080/actuator/health | Spring Actuator 健康检查（返回 HTTP 200） |
| http://localhost:8080/actuator | Actuator 入口（base-path: /actuator） |

---

## 启动命令

```bash
# 构建
mvn clean package -DskipTests -q

# 启动（禁用 OTLP 导出，因 LoongCollector 未安装）
java -jar spring-ai-alibaba-admin-server-start/target/spring-ai-alibaba-admin-server-start.jar \
  --spring.profiles.active=dev \
  --management.otlp.tracing.export.enabled=false
```

---

## 问题与修复记录

### 问题 1：Lombok annotation processor 未激活（编译失败）

**现象：** `mvn clean package` 阶段编译报错：

```
[ERROR] 无法将枚举 AccountType 中的构造器 AccountType 应用到给定类型；需要：没有参数；找到：java.lang.String
[ERROR] 无法将枚举 CommonStatus 中的构造器 CommonStatus 应用到给定类型
... (共约 40 个同类错误，涵盖所有带 @AllArgsConstructor 的 enum)
```

**根因分析：**

- 所有 enum 均使用 `@AllArgsConstructor` + `@Getter` 生成带参数构造器，代码本身语法正确。
- `maven-compiler-plugin 3.9.0` + `plexus-compiler-javac 2.9.0` 在 Java 21 环境下，`provided` scope 的 Lombok jar 会出现在 `-classpath` 中，但**不会自动加入 `-processorpath`**，导致 annotation processor 未被 javac 触发。
- 用 `mvn -X` 确认：javac 命令行有 Lombok 在 classpath，但无 `-processorpath` 参数。
- 用裸 `javac -processorpath lombok.jar` 直接编译同一文件：成功，验证 Lombok 本身正常。

**修复：** 在根 `pom.xml` 的 `maven-compiler-plugin` 配置中显式声明 `<annotationProcessorPaths>`：

```xml
<!-- pom.xml — maven-compiler-plugin configuration -->
<annotationProcessorPaths>
    <path>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <version>${lombok.version}</version>
    </path>
</annotationProcessorPaths>
```

修复后全量编译通过，无任何 annotation 相关错误。

**修改文件：** `pom.xml`（`pluginManagement` → `maven-compiler-plugin` → `configuration`）

---

### 问题 2：OTLP tracing 连接 4318 端口失败（启动时阻塞/警告）

**现象：** `application.yml` 默认开启 `management.otlp.tracing.export.enabled: true`，LoongCollector 未安装，端口 4318 未监听，应用启动时会尝试连接并报错。

**修复：** 创建 `application-dev.yml` 覆盖该配置：

```yaml
# spring-ai-alibaba-admin-server-start/src/main/resources/application-dev.yml
management:
  otlp:
    tracing:
      export:
        enabled: false
```

启动时加 `--spring.profiles.active=dev` 激活该 profile，或直接通过命令行参数传入：
```
--management.otlp.tracing.export.enabled=false
```

---

## 启动日志摘要（关键行）

```
Tomcat initialized with port 8080 (http)
Starting service [Tomcat]
Tomcat started on port 8080 (http) with context path '/'
Started SaaStudioAdmin in 15.448 seconds (process running for 15.829)
```

GraalVM Polyglot 警告（不影响功能，评估器脚本走解释模式）：
```
[engine] WARNING: The polyglot engine uses a fallback runtime that does not support
runtime compilation to native code.
```

---

---

## 前端（UmiJS Dev Server）

**访问地址：** [http://localhost:8000](http://localhost:8000)（自动代理 `/api`、`/console`、`/oauth2` 到后端 8080）

### 前端启动命令

```bash
cd frontend
# 依赖安装（--ignore-scripts 绕过 Node 版本兼容问题，见下）
PATH="/opt/homebrew/opt/node@20/bin:$PATH" npm install --ignore-scripts
# 构建 spark-flow（main 的 alias 依赖此 dist）
npm run build:flow
# 启动 dev server
cd packages/main && PATH="/opt/homebrew/opt/node@20/bin:$PATH" npm run dev
```

### 问题与修复

**问题 1：Node 24 不兼容 `http-deceiver`（`umi setup` postinstall 崩溃）**

- 现象：`npm install` postinstall 阶段报 `Error: No such module: http_parser`
- 根因：`http-deceiver` 调用了 `process.binding('http_parser')`，该 Node.js 内部 API 在 Node 22+ 已移除
- 修复：安装 Node 20 LTS（`brew install node@20`），改用 `/opt/homebrew/opt/node@20/bin/npm` 执行所有前端命令

**问题 2：`umi setup` postinstall 触发 npm 回滚**

- 现象：即使用 Node 20，postinstall 中的 `umi setup` 报 esbuild 错误，导致 npm 回滚所有已装包
- 修复：`npm install --ignore-scripts` 跳过 postinstall，依赖正常写入 `node_modules`；umi dev 启动时会自动补全 setup 步骤

---

## 待完成

- [ ] 配置 AI 模型 API Key（`spring-ai-alibaba-admin-server-start/model-config.yaml`），应用启动后可在控制台动态添加，无需重启
- [ ] 若需可观测性，安装 LoongCollector 并去掉 `management.otlp.tracing.export.enabled=false` 限制
- [ ] 前端生产构建：`npm run build:subtree:java`（产物可由后端 8080 直接托管）
