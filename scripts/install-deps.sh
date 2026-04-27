#!/usr/bin/env bash
# install-deps.sh — 本地安装 Spring AI Alibaba Admin 所需中间件
# 平台：macOS (Homebrew) / Linux (apt)
# 策略：优先检测已安装，跳过已就绪的依赖
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$SCRIPT_DIR/install-log.md"

# ── 颜色 ──────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()    { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

# ── OS 检测 ───────────────────────────────────────────────────────────────────
OS="$(uname -s)"
if [[ "$OS" == "Darwin" ]]; then
  PKG_MGR="brew"
  which brew >/dev/null 2>&1 || fail "Homebrew 未安装，请先访问 https://brew.sh 安装"
elif [[ "$OS" == "Linux" ]]; then
  PKG_MGR="apt"
  which apt >/dev/null 2>&1 || fail "apt 未找到，请确认使用 Debian/Ubuntu 系发行版"
else
  fail "不支持的操作系统: $OS"
fi

# ── 日志初始化 ────────────────────────────────────────────────────────────────
cat > "$LOG_FILE" << 'EOF'
# install-log.md

> 由 `scripts/install-deps.sh` 自动生成。

EOF
log_step() { echo -e "\n## $*" >> "$LOG_FILE"; }
log_note() { echo "- $*" >> "$LOG_FILE"; }

# ── 工具函数 ──────────────────────────────────────────────────────────────────
wait_for_port() {
  local name="$1" port="$2" retries="${3:-30}" interval="${4:-2}"
  info "等待 $name 在端口 $port 就绪..."
  for i in $(seq 1 $retries); do
    if nc -z localhost "$port" 2>/dev/null; then ok "$name 端口 $port 已就绪"; return 0; fi
    sleep "$interval"
  done
  fail "$name 端口 $port 等待超时（${retries}×${interval}s）"
}

brew_install_if_missing() {
  local pkg="$1"
  if brew list "$pkg" >/dev/null 2>&1; then
    ok "$pkg 已安装（$(brew list --versions "$pkg" | awk '{print $2}')）"
    return 0
  fi
  info "安装 $pkg ..."
  brew install "$pkg"
}

brew_install_cask_if_missing() {
  local cask="$1"
  if brew list --cask "$cask" >/dev/null 2>&1; then
    ok "$cask 已安装"
    return 0
  fi
  info "安装 cask $cask ..."
  brew install --cask "$cask"
}

# ── 1. Java 17 ────────────────────────────────────────────────────────────────
log_step "1. Java"
info "检查 Java 版本..."
JAVA_VER=$(java -version 2>&1 | grep -oE '"[0-9]+' | head -1 | tr -d '"' || echo "0")
if [[ "$JAVA_VER" -ge 17 ]]; then
  ok "Java $JAVA_VER 已满足要求（需要 ≥17）"
  log_note "Java 已就绪：版本 $JAVA_VER，命令：\`$(which java)\`"
else
  info "当前 Java $JAVA_VER < 17，安装 Temurin 17..."
  if [[ "$PKG_MGR" == "brew" ]]; then
    brew tap homebrew/cask-versions 2>/dev/null || true
    brew install --cask temurin@17
    export JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || echo '')"
    [[ -n "$JAVA_HOME" ]] && export PATH="$JAVA_HOME/bin:$PATH"
  else
    sudo apt-get install -y openjdk-17-jdk
  fi
  JAVA_VER=$(java -version 2>&1 | grep -oE '"[0-9]+' | head -1 | tr -d '"')
  ok "Java $JAVA_VER 已安装"
  log_note "安装 Java 17：brew install --cask temurin@17"
fi

# ── 2. Maven ──────────────────────────────────────────────────────────────────
log_step "2. Maven"
if which mvn >/dev/null 2>&1; then
  MVN_VER=$(mvn -version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  ok "Maven $MVN_VER 已安装"
  log_note "Maven 已就绪：版本 $MVN_VER"
else
  info "安装 Maven..."
  [[ "$PKG_MGR" == "brew" ]] && brew_install_if_missing maven || sudo apt-get install -y maven
  log_note "安装 Maven：brew install maven"
fi

# ── 3. MySQL ──────────────────────────────────────────────────────────────────
log_step "3. MySQL"
MYSQL_ISSUES=""

info "检查 MySQL 服务..."
if nc -z localhost 3306 2>/dev/null; then
  MYSQL_VER=$(mysql -u root -e "SELECT VERSION();" 2>/dev/null | grep -v VERSION || echo "unknown")
  ok "MySQL 已在 3306 运行（版本: $MYSQL_VER）"
  log_note "MySQL 已就绪（已运行），版本：$MYSQL_VER"
else
  if [[ "$PKG_MGR" == "brew" ]]; then
    brew_install_if_missing mysql
    brew services start mysql
    wait_for_port "MySQL" 3306 20 2
  else
    sudo apt-get install -y mysql-server
    sudo systemctl start mysql
    wait_for_port "MySQL" 3306 20 2
  fi
  log_note "安装并启动 MySQL：brew install mysql && brew services start mysql"
fi

info "初始化 MySQL：创建用户和数据库..."
# 尝试 root 无密码
MYSQL_CMD="mysql -u root"
$MYSQL_CMD -e "SELECT 1;" >/dev/null 2>&1 || MYSQL_CMD="mysql -u root -proot"
$MYSQL_CMD -e "SELECT 1;" >/dev/null 2>&1 || fail "无法连接 MySQL root 账户，请手动检查密码"

# 创建 admin 用户（幂等）
$MYSQL_CMD << 'MYSQL_INIT'
CREATE USER IF NOT EXISTS 'admin'@'localhost' IDENTIFIED BY 'admin';
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'admin';
CREATE DATABASE IF NOT EXISTS `admin` DEFAULT CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS `agentscope` DEFAULT CHARACTER SET utf8mb4;
GRANT ALL PRIVILEGES ON `admin`.* TO 'admin'@'localhost';
GRANT ALL PRIVILEGES ON `admin`.* TO 'admin'@'%';
GRANT ALL PRIVILEGES ON `agentscope`.* TO 'admin'@'localhost';
GRANT ALL PRIVILEGES ON `agentscope`.* TO 'admin'@'%';
FLUSH PRIVILEGES;
MYSQL_INIT
ok "用户 admin / 数据库 admin + agentscope 已就绪"
log_note "创建用户 admin 和数据库 admin、agentscope"

info "导入 admin 建表 SQL..."
mysql -u admin -padmin admin < "$PROJECT_ROOT/docker/middleware/init/mysql/admin-schema.sql" 2>&1 | grep -v Warning || true
ok "admin 库建表完成"

info "导入 agentscope 建表 SQL..."
mysql -u admin -padmin agentscope < "$PROJECT_ROOT/docker/middleware/init/mysql/agentscope-schema.sql" 2>&1 | grep -v Warning || true
ok "agentscope 库建表完成"
log_note "导入建表 SQL：admin-schema.sql → admin库，agentscope-schema.sql → agentscope库"

# ── 4. Redis ──────────────────────────────────────────────────────────────────
log_step "4. Redis"
if nc -z localhost 6379 2>/dev/null; then
  REDIS_VER=$(redis-cli INFO server 2>/dev/null | grep redis_version | cut -d: -f2 | tr -d '\r')
  ok "Redis 已在 6379 运行（版本: $REDIS_VER）"
  log_note "Redis 已就绪（已运行），版本：$REDIS_VER，无需初始化"
else
  if [[ "$PKG_MGR" == "brew" ]]; then
    brew_install_if_missing redis
    brew services start redis
  else
    sudo apt-get install -y redis-server
    sudo systemctl start redis-server
  fi
  wait_for_port "Redis" 6379 15 2
  ok "Redis 已启动"
  log_note "安装并启动 Redis：brew install redis && brew services start redis"
fi

# ── 5. Elasticsearch ──────────────────────────────────────────────────────────
log_step "5. Elasticsearch"
if nc -z localhost 9200 2>/dev/null; then
  ES_VER=$(curl -s http://localhost:9200 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['version']['number'])" 2>/dev/null || echo "unknown")
  ok "Elasticsearch 已在 9200 运行（版本: $ES_VER）"
  log_note "Elasticsearch 已就绪（已运行），版本：$ES_VER"
else
  # brew elastic/tap 仅提供 ES 7.17.4，且有 JDK 路径问题；
  # 官方 tar.gz 自带 JDK，稳定可用，macOS/Linux 均适用
  ES_VERSION="8.18.3"
  ES_HOME="$HOME/elasticsearch-${ES_VERSION}"
  if [[ -d "$ES_HOME/bin" ]]; then
    ok "Elasticsearch 已存在于 $ES_HOME"
  else
    if [[ "$OS" == "Darwin" ]]; then
      ARCH=$(uname -m); [[ "$ARCH" == "arm64" ]] && ARCH="aarch64"
      ES_TARBALL="elasticsearch-${ES_VERSION}-darwin-${ARCH}.tar.gz"
    else
      ES_TARBALL="elasticsearch-${ES_VERSION}-linux-x86_64.tar.gz"
    fi
    ES_DL_URL="https://artifacts.elastic.co/downloads/elasticsearch/${ES_TARBALL}"
    info "下载 Elasticsearch ${ES_VERSION}（官方 tar.gz，自带 JDK）..."
    info "下载链接：$ES_DL_URL"
    mkdir -p "$HOME/downloads"
    curl -L --retry 3 -o "$HOME/downloads/$ES_TARBALL" "$ES_DL_URL"
    tar -xzf "$HOME/downloads/$ES_TARBALL" -C "$HOME"
    log_note "下载 Elasticsearch ${ES_VERSION}：$ES_DL_URL → $ES_HOME"
  fi
  info "配置 ES：禁用 xpack.security 和 xpack.ml..."
  grep -q 'xpack.security.enabled' "$ES_HOME/config/elasticsearch.yml" \
    || printf '\nxpack.security.enabled: false\nxpack.security.enrollment.enabled: false\nxpack.ml.enabled: false\n' \
       >> "$ES_HOME/config/elasticsearch.yml"
  info "启动 Elasticsearch..."
  "$ES_HOME/bin/elasticsearch" -d -p "$ES_HOME/elasticsearch.pid"
  wait_for_port "Elasticsearch" 9200 45 4
  ok "Elasticsearch 已启动"
fi

info "初始化 ES：创建 pipeline 和索引..."
# 等待集群 green/yellow
for i in $(seq 1 20); do
  STATUS=$(curl -s "http://localhost:9200/_cluster/health" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
  [[ "$STATUS" == "green" || "$STATUS" == "yellow" ]] && break
  info "等待 ES 集群就绪 ($i/20)..."; sleep 5
done

# 创建 pipeline
curl -s -X PUT "http://localhost:9200/_ingest/pipeline/parsing_loongsuite_traces" \
  -H "Content-Type: application/json" \
  -d '{
    "processors": [
      {"json": {"field": "contents.attribute","target_field": "attributes"}},
      {"json": {"field": "contents.resource","target_field": "resources"}},
      {"json": {"field": "contents.links","target_field": "spanLinks"}},
      {"json": {"field": "contents.logs","target_field": "spanEvents"}},
      {"remove": {"field": ["contents.attribute","contents.resource","contents.links","contents.logs"]}},
      {"rename": {"field": "contents","target_field": "metadata"}}
    ]
  }' >/dev/null 2>&1
ok "ES Pipeline parsing_loongsuite_traces 已创建"

# 创建索引（忽略已存在错误）
INDEX_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:9200/loongsuite_traces")
if [[ "$INDEX_EXISTS" == "200" ]]; then
  ok "ES 索引 loongsuite_traces 已存在，跳过"
else
  curl -s -X PUT "http://localhost:9200/loongsuite_traces" \
    -H "Content-Type: application/json" \
    -d '{
      "settings": {"index.default_pipeline": "parsing_loongsuite_traces"},
      "mappings": {
        "dynamic": "false",
        "properties": {
          "metadata": {"type": "object"},
          "time": {"type": "long"},
          "attributes": {"type": "flattened"},
          "resources": {"type": "flattened"},
          "usage": {"type": "object","properties": {
            "input_tokens": {"type": "long"},
            "output_tokens": {"type": "long"},
            "total_tokens": {"type": "long"}
          }}
        }
      }
    }' >/dev/null 2>&1
  ok "ES 索引 loongsuite_traces 已创建"
fi
log_note "初始化 ES：创建 parsing_loongsuite_traces pipeline 和 loongsuite_traces 索引"

# ── 6. RocketMQ ───────────────────────────────────────────────────────────────
log_step "6. RocketMQ"
RMQ_HOME="$HOME/rocketmq"
RMQ_VERSION="5.3.2"
RMQ_TARBALL="rocketmq-all-${RMQ_VERSION}-bin-release.zip"
RMQ_DOWNLOAD_URL="https://dist.apache.org/repos/dist/release/rocketmq/${RMQ_VERSION}/${RMQ_TARBALL}"

if nc -z localhost 18080 2>/dev/null; then
  ok "RocketMQ Proxy 已在 18080 运行"
  log_note "RocketMQ 已就绪（已运行）"
else
  if [[ ! -d "$RMQ_HOME/bin" ]]; then
    info "下载 RocketMQ ${RMQ_VERSION}..."
    info "下载链接：$RMQ_DOWNLOAD_URL"
    info "目标目录：$RMQ_HOME"
    mkdir -p "$HOME/downloads"
    if ! curl -L --retry 3 -o "$HOME/downloads/$RMQ_TARBALL" "$RMQ_DOWNLOAD_URL" 2>&1; then
      # 备用镜像
      warn "主源下载失败，尝试清华镜像..."
      RMQ_DOWNLOAD_URL="https://mirrors.tuna.tsinghua.edu.cn/apache/rocketmq/${RMQ_VERSION}/${RMQ_TARBALL}"
      curl -L --retry 3 -o "$HOME/downloads/$RMQ_TARBALL" "$RMQ_DOWNLOAD_URL"
    fi
    mkdir -p "$RMQ_HOME"
    unzip -q "$HOME/downloads/$RMQ_TARBALL" -d "$HOME/rocketmq-extract"
    mv "$HOME/rocketmq-extract/rocketmq-all-${RMQ_VERSION}-bin-release/"* "$RMQ_HOME/"
    rm -rf "$HOME/rocketmq-extract"
    ok "RocketMQ ${RMQ_VERSION} 已解压到 $RMQ_HOME"
    log_note "下载 RocketMQ ${RMQ_VERSION}：\`$RMQ_DOWNLOAD_URL\` → \`$RMQ_HOME\`"
  else
    ok "RocketMQ 已存在于 $RMQ_HOME"
  fi

  # 写 Proxy 配置
  mkdir -p "$RMQ_HOME/conf"
  cat > "$RMQ_HOME/conf/rmq-proxy.json" << 'PROXY_CONF'
{
  "rocketMQClusterName": "DefaultCluster",
  "remotingListenPort": 18080,
  "grpcServerPort": 18081
}
PROXY_CONF

  # 调低 JVM 内存（开发环境）
  export JAVA_OPT_EXT="-Xms256m -Xmx512m"

  info "启动 NameServer..."
  nohup "$RMQ_HOME/bin/mqnamesrv" > "$RMQ_HOME/logs/namesrv.log" 2>&1 &
  NAMESRV_PID=$!
  wait_for_port "NameServer" 9876 20 2

  info "启动 Broker..."
  nohup "$RMQ_HOME/bin/mqbroker" -n localhost:9876 \
    --enable-proxy \
    -pc "$RMQ_HOME/conf/rmq-proxy.json" \
    > "$RMQ_HOME/logs/broker.log" 2>&1 &
  BROKER_PID=$!
  wait_for_port "RocketMQ Proxy" 18080 30 3
  ok "RocketMQ NameServer + Broker + Proxy 已启动"
  log_note "启动 RocketMQ：nohup mqnamesrv & nohup mqbroker --enable-proxy &"

  info "创建 Topic 和 Consumer Group（等待 15s 让 Broker 完全就绪）..."
  sleep 15
  "$RMQ_HOME/bin/mqadmin" updateTopic \
    -n localhost:9876 \
    -t topic_saa_studio_document_index \
    -c DefaultCluster \
    -a +message.type=NORMAL 2>&1 | tail -3 || warn "Topic 创建失败，可稍后手动创建"

  "$RMQ_HOME/bin/mqadmin" updateSubGroup \
    -n localhost:9876 \
    -g group_saa_studio_document_index \
    -c DefaultCluster 2>&1 | tail -3 || warn "Consumer Group 创建失败，可稍后手动创建"
  ok "RocketMQ Topic 和 Consumer Group 已创建"
  log_note "创建 Topic topic_saa_studio_document_index 和 Consumer Group group_saa_studio_document_index"
fi

# ── 7. Nacos ──────────────────────────────────────────────────────────────────
log_step "7. Nacos"
NACOS_HOME="$HOME/nacos"
NACOS_VERSION="2.4.3"
NACOS_TARBALL="nacos-server-${NACOS_VERSION}.tar.gz"
NACOS_DOWNLOAD_URL="https://github.com/alibaba/nacos/releases/download/${NACOS_VERSION}/${NACOS_TARBALL}"

if nc -z localhost 8848 2>/dev/null; then
  ok "Nacos 已在 8848 运行"
  log_note "Nacos 已就绪（已运行）"
else
  if [[ ! -d "$NACOS_HOME/bin" ]]; then
    info "下载 Nacos ${NACOS_VERSION}..."
    info "下载链接：$NACOS_DOWNLOAD_URL"
    info "目标目录：$NACOS_HOME"
    mkdir -p "$HOME/downloads"
    if ! curl -L --retry 3 -o "$HOME/downloads/$NACOS_TARBALL" "$NACOS_DOWNLOAD_URL" 2>&1; then
      warn "GitHub 下载失败，尝试镜像..."
      NACOS_DOWNLOAD_URL="https://download.fastgit.org/alibaba/nacos/releases/download/${NACOS_VERSION}/${NACOS_TARBALL}"
      curl -L --retry 3 -o "$HOME/downloads/$NACOS_TARBALL" "$NACOS_DOWNLOAD_URL"
    fi
    tar -xzf "$HOME/downloads/$NACOS_TARBALL" -C "$HOME"
    ok "Nacos ${NACOS_VERSION} 已解压到 $NACOS_HOME"
    log_note "下载 Nacos ${NACOS_VERSION}：\`$NACOS_DOWNLOAD_URL\` → \`$NACOS_HOME\`"
  else
    ok "Nacos 已存在于 $NACOS_HOME"
  fi

  # 调低 JVM 内存
  export JAVA_OPT="-Xms256m -Xmx512m -Xmn128m"

  info "启动 Nacos（standalone 模式）..."
  nohup "$NACOS_HOME/bin/startup.sh" -m standalone \
    > "$NACOS_HOME/logs/start.log" 2>&1 &
  wait_for_port "Nacos" 8848 30 3
  ok "Nacos 已启动（Console: http://localhost:8848/nacos，账号: nacos/nacos）"
  log_note "启动 Nacos standalone：sh startup.sh -m standalone"
  log_note "不需要预建 Namespace/Group/DataId，应用启动后自动推送"
fi

# ── 8. LoongCollector（可选）─────────────────────────────────────────────────
log_step "8. LoongCollector（可选）"
LC_VERSION="3.1.4"
LC_TARBALL="loongcollector-${LC_VERSION}.macos-arm64.tar.gz"
# macOS arm64；x86_64 换 macos-amd64
if [[ "$(uname -m)" == "x86_64" ]]; then
  LC_TARBALL="loongcollector-${LC_VERSION}.macos-amd64.tar.gz"
fi
LC_DOWNLOAD_URL="https://github.com/alibaba/loongcollector/releases/download/v${LC_VERSION}/${LC_TARBALL}"
LC_HOME="$HOME/loongcollector"

info "LoongCollector 为可观测性可选组件（端口 4318）"
info "下载链接：$LC_DOWNLOAD_URL"
info "目标目录：$LC_HOME"

if nc -z localhost 4318 2>/dev/null; then
  ok "LoongCollector 已在 4318 运行"
  log_note "LoongCollector 已就绪（已运行）"
else
  if [[ ! -d "$LC_HOME" ]]; then
    mkdir -p "$HOME/downloads"
    if curl -L --retry 3 --connect-timeout 15 \
         -o "$HOME/downloads/$LC_TARBALL" "$LC_DOWNLOAD_URL" 2>&1; then
      mkdir -p "$LC_HOME"
      tar -xzf "$HOME/downloads/$LC_TARBALL" -C "$LC_HOME" --strip-components=1 2>/dev/null \
        || tar -xzf "$HOME/downloads/$LC_TARBALL" -C "$LC_HOME"
      ok "LoongCollector 已解压到 $LC_HOME"
      log_note "下载 LoongCollector：$LC_DOWNLOAD_URL → $LC_HOME"
    else
      warn "LoongCollector 下载失败（GitHub Release 可能暂时不可达）"
      warn "手动下载：$LC_DOWNLOAD_URL"
      warn "解压到：$LC_HOME，然后运行 \$LC_HOME/loongcollector"
      log_note "LoongCollector 下载失败，需手动安装：$LC_DOWNLOAD_URL → $LC_HOME"
      echo "  （跳过 LoongCollector，可观测性功能暂不可用）"
    fi
  fi

  if [[ -f "$LC_HOME/loongcollector" || -f "$LC_HOME/bin/loongcollector" ]]; then
    LC_BIN="$LC_HOME/loongcollector"
    [[ ! -f "$LC_BIN" ]] && LC_BIN="$LC_HOME/bin/loongcollector"
    # 复制 pipeline 配置
    LC_CONF_DIR="$LC_HOME/conf/continuous_pipeline_config/local"
    mkdir -p "$LC_CONF_DIR"
    cp "$PROJECT_ROOT/docker/middleware/conf/loongcollector/otlp_pipeline.yaml" "$LC_CONF_DIR/"
    # 修改 ES 地址（容器内 elasticsearch → localhost）
    sed -i.bak 's|http://elasticsearch:9200|http://localhost:9200|g' "$LC_CONF_DIR/otlp_pipeline.yaml"
    info "启动 LoongCollector..."
    nohup "$LC_BIN" > "$LC_HOME/loongcollector.log" 2>&1 &
    wait_for_port "LoongCollector" 4318 15 2
    ok "LoongCollector 已启动（OTLP HTTP: http://localhost:4318）"
    log_note "启动 LoongCollector，pipeline 配置复制自 docker/middleware/conf/loongcollector/otlp_pipeline.yaml（ES 地址改为 localhost）"
  fi
fi

# ── 9. 健康检查汇总 ───────────────────────────────────────────────────────────
log_step "9. AI 模型 API"
log_note "需要手动配置：复制 spring-ai-alibaba-admin-server-start/model-config-dashscope.yaml（或 openai/deepseek 模板）为 model-config.yaml，填入 API Key"
log_note "API Key 获取地址：DashScope→https://bailian.console.aliyun.com，OpenAI→https://platform.openai.com，DeepSeek→https://platform.deepseek.com"

echo ""
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}           健康检查汇总                  ${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"

check_service() {
  local name="$1" host="$2" port="$3"
  if nc -z "$host" "$port" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $name ($host:$port)"
  else
    echo -e "  ${RED}✗${NC} $name ($host:$port) — 未就绪"
  fi
}

check_service "Java 17+"      ""          ""  # 特殊处理
JAVA_OK=$(java -version 2>&1 | grep -oE '"[0-9]+' | head -1 | tr -d '"')
[[ "$JAVA_OK" -ge 17 ]] \
  && echo -e "  ${GREEN}✓${NC} Java $JAVA_OK" \
  || echo -e "  ${RED}✗${NC} Java $JAVA_OK (需要 ≥17)"

check_service "MySQL"           "localhost" 3306
check_service "Redis"           "localhost" 6379
check_service "Elasticsearch"   "localhost" 9200
check_service "RocketMQ Proxy"  "localhost" 18080
check_service "Nacos"           "localhost" 8848
check_service "LoongCollector"  "localhost" 4318
echo ""
echo -e "  ${YELLOW}！${NC} AI 模型 API Key — 需手动配置 model-config.yaml"
echo ""
echo -e "${GREEN}安装日志已写入：${NC} $LOG_FILE"
echo -e "${YELLOW}下一步：${NC} 配置 model-config.yaml，然后运行 mvn spring-boot:run"

# ── 追加最终汇总到日志 ────────────────────────────────────────────────────────
cat >> "$LOG_FILE" << SUMMARY

---

## 最终健康状态

| 组件 | 端口 | 状态 |
|------|------|------|
| Java | — | $(java -version 2>&1 | grep -oE '"[^"]+' | head -1 | tr -d '"') |
| MySQL | 3306 | $(nc -z localhost 3306 2>/dev/null && echo "✓ 运行中" || echo "✗ 未就绪") |
| Redis | 6379 | $(nc -z localhost 6379 2>/dev/null && echo "✓ 运行中" || echo "✗ 未就绪") |
| Elasticsearch | 9200 | $(nc -z localhost 9200 2>/dev/null && echo "✓ 运行中" || echo "✗ 未就绪") |
| RocketMQ Proxy | 18080 | $(nc -z localhost 18080 2>/dev/null && echo "✓ 运行中" || echo "✗ 未就绪") |
| Nacos | 8848 | $(nc -z localhost 8848 2>/dev/null && echo "✓ 运行中" || echo "✗ 未就绪") |
| LoongCollector | 4318 | $(nc -z localhost 4318 2>/dev/null && echo "✓ 运行中" || echo "✗ 未就绪（可选）") |

## 手动完成项

- [ ] 复制 \`model-config-{provider}.yaml\` 为 \`model-config.yaml\`，填入 AI API Key
- [ ] 若 LoongCollector 下载失败，手动下载并启动（链接见 LoongCollector 节）
SUMMARY
