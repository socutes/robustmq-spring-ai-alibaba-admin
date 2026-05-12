#!/usr/bin/env bash
# =============================================================================
# install-deps.sh
# Spring AI Alibaba Admin — 本地依赖安装 & 初始化脚本
#
# 平台：macOS（Homebrew）/ Linux（apt）
# 策略：每个中间件先检测是否已运行/安装，跳过则不重复安装。
#       初始化操作幂等（CREATE IF NOT EXISTS / 已存在跳过）。
#
# 用法：
#   chmod +x scripts/install-deps.sh
#   bash scripts/install-deps.sh
#
# 环境变量覆盖（可选）：
#   MYSQL_ROOT_PASSWORD   默认 root
#   MYSQL_USER            默认 admin
#   MYSQL_PASSWORD        默认 admin
#   ROCKETMQ_HOME         默认 ~/rocketmq-5.3.2
#   NACOS_HOME            默认 ~/nacos
#   ES_URL                默认 http://localhost:9200
#   NACOS_HTTP_PORT       默认 8848（直接进程端口；项目 application.yml 默认 localhost:8848）
# =============================================================================

set -euo pipefail

# ── 颜色 ──────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
step()    { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; \
            echo -e "${CYAN}  $*${NC}"; \
            echo -e "${CYAN}══════════════════════════════════════════${NC}"; }

# ── 脚本所在目录（项目根） ──────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── 配置变量 ──────────────────────────────────────────────────────────────────
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root}"
MYSQL_USER="${MYSQL_USER:-admin}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-admin}"
ROCKETMQ_HOME="${ROCKETMQ_HOME:-$HOME/rocketmq-5.3.2}"
NACOS_HOME="${NACOS_HOME:-$HOME/nacos}"
ES_URL="${ES_URL:-http://localhost:9200}"
NACOS_HTTP_PORT="${NACOS_HTTP_PORT:-8848}"

# ── 工具函数 ──────────────────────────────────────────────────────────────────
wait_for_port() {
    local host="$1" port="$2" label="$3" retries="${4:-30}" delay="${5:-2}"
    info "等待 $label ($host:$port) 就绪..."
    for i in $(seq 1 "$retries"); do
        if nc -z "$host" "$port" 2>/dev/null; then
            success "$label 已就绪"
            return 0
        fi
        echo -n "."
        sleep "$delay"
    done
    echo ""
    error "$label 超时未就绪（$((retries * delay))s）"
    return 1
}

wait_for_http() {
    local url="$1" label="$2" retries="${3:-30}" delay="${4:-3}"
    info "等待 $label ($url) 响应..."
    for i in $(seq 1 "$retries"); do
        if curl -sf "$url" > /dev/null 2>&1; then
            success "$label 已就绪"
            return 0
        fi
        echo -n "."
        sleep "$delay"
    done
    echo ""
    error "$label HTTP 超时未响应（$((retries * delay))s）"
    return 1
}

# ── OS 检测 ───────────────────────────────────────────────────────────────────
OS="$(uname -s)"
if [[ "$OS" == "Darwin" ]]; then
    PKG_MANAGER="brew"
    if ! command -v brew &>/dev/null; then
        error "未找到 Homebrew，请先安装：https://brew.sh"
        exit 1
    fi
elif [[ "$OS" == "Linux" ]]; then
    PKG_MANAGER="apt"
    if ! command -v apt-get &>/dev/null; then
        error "仅支持 apt（Debian/Ubuntu）"
        exit 1
    fi
    sudo apt-get update -qq
else
    error "不支持的操作系统：$OS"
    exit 1
fi

info "检测到操作系统：$OS，包管理器：$PKG_MANAGER"
info "项目根目录：$PROJECT_ROOT"

# =============================================================================
# 1. Java 17
# =============================================================================
step "1/7  Java 17"

JAVA_OK=false
if command -v java &>/dev/null; then
    JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
    if [[ "$JAVA_VER" -ge 17 ]]; then
        success "Java $JAVA_VER 已安装（满足 ≥17 要求）"
        JAVA_OK=true
    else
        warn "当前 Java 版本为 $JAVA_VER，需要 ≥17"
    fi
fi

if [[ "$JAVA_OK" == false ]]; then
    info "安装 Java 17..."
    if [[ "$PKG_MANAGER" == "brew" ]]; then
        brew install --cask temurin@17 || brew install openjdk@17
        # 设置 JAVA_HOME 指向 17
        export JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || echo /opt/homebrew/opt/openjdk@17)"
        export PATH="$JAVA_HOME/bin:$PATH"
    else
        sudo apt-get install -y openjdk-17-jdk
        export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-$(dpkg --print-architecture)
        export PATH="$JAVA_HOME/bin:$PATH"
    fi
    success "Java 17 安装完成"
fi

# =============================================================================
# 2. MySQL 8.0
# =============================================================================
step "2/7  MySQL 8.0"

MYSQL_RUNNING=false
if nc -z localhost 3306 2>/dev/null; then
    MYSQL_RUNNING=true
    MYSQL_VER=$(mysql --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    success "MySQL 已运行（版本 $MYSQL_VER，端口 3306）"
fi

if [[ "$MYSQL_RUNNING" == false ]]; then
    info "MySQL 未运行，尝试安装并启动..."
    if [[ "$PKG_MANAGER" == "brew" ]]; then
        if ! brew list mysql &>/dev/null && ! brew list mysql@8.0 &>/dev/null; then
            brew install mysql
        fi
        brew services start mysql
    else
        sudo apt-get install -y mysql-server
        sudo systemctl start mysql
        sudo systemctl enable mysql
    fi
    wait_for_port localhost 3306 "MySQL" 20 3
fi

# ── MySQL 初始化 ───────────────────────────────────────────────────────────────
info "初始化 MySQL：创建用户和 schema..."

# 尝试 root 无密码登录（brew 新装默认），也支持有密码
MYSQL_ROOT_CMD="mysql -u root"
if ! $MYSQL_ROOT_CMD -e "SELECT 1;" &>/dev/null 2>&1; then
    MYSQL_ROOT_CMD="mysql -u root -p${MYSQL_ROOT_PASSWORD}"
    if ! $MYSQL_ROOT_CMD -e "SELECT 1;" &>/dev/null 2>&1; then
        warn "无法以 root 登录 MySQL（无密码或密码 '$MYSQL_ROOT_PASSWORD' 均失败）"
        warn "请手动执行：mysql -u root < $PROJECT_ROOT/scripts/_mysql_init.sql"
    fi
fi

# 写临时初始化 SQL
cat > /tmp/saa_mysql_init.sql << 'MYSQL_INIT_EOF'
-- 创建 admin schema（Builder 平台表）
CREATE DATABASE IF NOT EXISTS admin DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- 创建 agentscope schema（评估平台表）
CREATE DATABASE IF NOT EXISTS agentscope DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建应用用户（幂等）
CREATE USER IF NOT EXISTS 'admin'@'localhost' IDENTIFIED BY 'admin';
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'admin';
GRANT ALL PRIVILEGES ON admin.* TO 'admin'@'localhost';
GRANT ALL PRIVILEGES ON admin.* TO 'admin'@'%';
GRANT ALL PRIVILEGES ON agentscope.* TO 'admin'@'localhost';
GRANT ALL PRIVILEGES ON agentscope.* TO 'admin'@'%';
FLUSH PRIVILEGES;
MYSQL_INIT_EOF

if $MYSQL_ROOT_CMD < /tmp/saa_mysql_init.sql 2>/dev/null; then
    success "MySQL 用户 & schema 初始化完成"
else
    warn "MySQL 初始化 SQL 执行失败，可能已存在，继续..."
fi
rm -f /tmp/saa_mysql_init.sql

# ── 导入 DDL（幂等：表已存在则跳过） ─────────────────────────────────────────
# admin-schema.sql → agentscope 数据库（评估平台表：dataset/evaluator/experiment/prompt）
# agentscope-schema.sql → admin 数据库（Builder 平台表：account/workspace/application）
ADMIN_SQL="$PROJECT_ROOT/docker/middleware/init/mysql/admin-schema.sql"
AGENTSCOPE_SQL="$PROJECT_ROOT/docker/middleware/init/mysql/agentscope-schema.sql"

MYSQL_APP_CMD="mysql -u ${MYSQL_USER} -p${MYSQL_PASSWORD}"

if [[ -f "$ADMIN_SQL" ]]; then
    info "导入 admin-schema.sql → agentscope 库..."
    if $MYSQL_APP_CMD agentscope < "$ADMIN_SQL" 2>/dev/null; then
        success "admin-schema.sql 导入完成"
    else
        warn "admin-schema.sql 导入时有警告（可能表已存在，属正常）"
    fi
else
    warn "未找到 $ADMIN_SQL，跳过"
fi

if [[ -f "$AGENTSCOPE_SQL" ]]; then
    info "导入 agentscope-schema.sql → admin 库..."
    if $MYSQL_APP_CMD admin < "$AGENTSCOPE_SQL" 2>/dev/null; then
        success "agentscope-schema.sql 导入完成"
    else
        warn "agentscope-schema.sql 导入时有警告（可能表已存在，属正常）"
    fi
else
    warn "未找到 $AGENTSCOPE_SQL，跳过"
fi

# =============================================================================
# 3. Redis 7
# =============================================================================
step "3/7  Redis 7"

if nc -z localhost 6379 2>/dev/null; then
    REDIS_VER=$(redis-cli --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    success "Redis 已运行（版本 $REDIS_VER，端口 6379）"
else
    info "Redis 未运行，安装并启动..."
    if [[ "$PKG_MANAGER" == "brew" ]]; then
        brew list redis &>/dev/null || brew install redis
        brew services start redis
    else
        sudo apt-get install -y redis-server
        sudo systemctl start redis-server
        sudo systemctl enable redis-server
    fi
    wait_for_port localhost 6379 "Redis" 15 2
fi

if redis-cli ping 2>/dev/null | grep -q PONG; then
    success "Redis 连接正常（PONG）"
else
    warn "Redis ping 失败，请检查服务"
fi

# =============================================================================
# 4. Elasticsearch 8.x
# =============================================================================
step "4/7  Elasticsearch 8.x"

ES_RUNNING=false
if curl -sf "${ES_URL}/_cluster/health" > /dev/null 2>&1; then
    ES_RUNNING=true
    ES_VER=$(curl -s "${ES_URL}/" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['version']['number'])" 2>/dev/null || echo "unknown")
    success "Elasticsearch 已运行（版本 $ES_VER，$ES_URL）"
fi

if [[ "$ES_RUNNING" == false ]]; then
    info "Elasticsearch 未运行，安装并启动..."
    if [[ "$PKG_MANAGER" == "brew" ]]; then
        if ! brew list elasticsearch-full &>/dev/null; then
            brew tap elastic/tap 2>/dev/null || true
            brew install elastic/tap/elasticsearch-full
        fi
        # 关闭 xpack security（开发环境）
        ES_CONF=$(brew --prefix)/etc/elasticsearch/elasticsearch.yml
        if [[ -f "$ES_CONF" ]] && ! grep -q 'xpack.security.enabled: false' "$ES_CONF"; then
            echo 'xpack.security.enabled: false' >> "$ES_CONF"
            echo 'xpack.security.enrollment.enabled: false' >> "$ES_CONF"
        fi
        brew services start elastic/tap/elasticsearch-full
    else
        wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" \
            | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
        sudo apt-get update -qq && sudo apt-get install -y elasticsearch
        sudo sed -i 's/^#\?xpack.security.enabled:.*/xpack.security.enabled: false/' /etc/elasticsearch/elasticsearch.yml
        sudo systemctl start elasticsearch
        sudo systemctl enable elasticsearch
    fi
    wait_for_http "${ES_URL}/_cluster/health" "Elasticsearch" 30 5
fi

# ── ES 初始化：pipeline + index ────────────────────────────────────────────────
info "检查 ES pipeline: parsing_loongsuite_traces..."
if curl -sf "${ES_URL}/_ingest/pipeline/parsing_loongsuite_traces" > /dev/null 2>&1; then
    success "Pipeline 已存在，跳过"
else
    info "创建 Ingest Pipeline..."
    curl -s -X PUT "${ES_URL}/_ingest/pipeline/parsing_loongsuite_traces" \
      -H "Content-Type: application/json" \
      -d '{
        "processors": [
          {"json": {"field": "contents.attribute", "target_field": "attributes"}},
          {"json": {"field": "contents.resource", "target_field": "resources"}},
          {"json": {"field": "contents.links", "target_field": "spanLinks"}},
          {"json": {"field": "contents.logs", "target_field": "spanEvents"}},
          {"remove": {"field": ["contents.attribute","contents.resource","contents.links","contents.logs"]}},
          {"rename": {"field": "contents", "target_field": "metadata"}},
          {"script": {"source": "Map usage = new HashMap();\nlong total = 0;\nif (ctx.attributes.containsKey(\"gen_ai.usage.input_tokens\")) {\n  long input = Long.parseLong(ctx.attributes[\"gen_ai.usage.input_tokens\"]);\n  usage[\"input_tokens\"] = input;\n  total = total + input;\n}\nif (ctx.attributes.containsKey(\"gen_ai.usage.output_tokens\")) {\n  long output = Long.parseLong(ctx.attributes[\"gen_ai.usage.output_tokens\"]);\n  usage[\"output_tokens\"] = output;\n  total = total + output;\n}\nusage[\"total_tokens\"] = total;\nctx.usage = usage;"}}
        ]
      }' > /dev/null
    success "Pipeline 创建完成"
fi

info "检查 ES index: loongsuite_traces..."
if curl -sf "${ES_URL}/loongsuite_traces/_mapping" > /dev/null 2>&1; then
    success "Index 已存在，跳过"
else
    info "创建 loongsuite_traces index..."
    curl -s -X PUT "${ES_URL}/loongsuite_traces" \
      -H "Content-Type: application/json" \
      -d '{
        "settings": {
          "index.default_pipeline": "parsing_loongsuite_traces",
          "number_of_shards": 1,
          "number_of_replicas": 0
        },
        "mappings": {
          "dynamic": "false",
          "properties": {
            "metadata": {
              "type": "object",
              "properties": {
                "duration":{"type":"long"}, "end":{"type":"long"}, "host":{"type":"keyword"},
                "kind":{"type":"text"}, "name":{"type":"keyword"}, "parentSpanID":{"type":"text"},
                "service":{"type":"keyword"}, "spanID":{"type":"text"}, "start":{"type":"long"},
                "statusCode":{"type":"text"}, "statusMessage":{"type":"keyword"},
                "traceID":{"type":"text"}, "traceState":{"type":"keyword"}
              }
            },
            "tags":{"type":"object"}, "time":{"type":"long"},
            "attributes":{"type":"flattened"}, "resources":{"type":"flattened"},
            "spanEvents":{"type":"nested","properties":{"name":{"type":"keyword"},"attribute":{"type":"flattened"},"time":{"type":"long"}}},
            "spanLinks":{"type":"nested","properties":{"spanID":{"type":"text"},"traceID":{"type":"text"},"attribute":{"type":"flattened"}}},
            "usage":{"type":"object","properties":{"input_tokens":{"type":"long"},"output_tokens":{"type":"long"},"total_tokens":{"type":"long"}}}
          }
        }
      }' > /dev/null
    success "Index 创建完成"
fi

# =============================================================================
# 5. RocketMQ 5
# =============================================================================
step "5/7  RocketMQ 5"

RMQ_RUNNING=false
if nc -z localhost 18080 2>/dev/null || nc -z localhost 9876 2>/dev/null; then
    RMQ_RUNNING=true
    success "RocketMQ 已运行（NameServer:9876 / Proxy:18080）"
fi

if [[ "$RMQ_RUNNING" == false ]]; then
    RMQ_VERSION="5.3.2"
    RMQ_PKG="rocketmq-all-${RMQ_VERSION}-bin-release.zip"
    RMQ_URL="https://dist.apache.org/repos/dist/release/rocketmq/${RMQ_VERSION}/${RMQ_PKG}"

    if [[ ! -d "$ROCKETMQ_HOME" ]]; then
        info "下载 RocketMQ ${RMQ_VERSION}..."
        cd /tmp
        curl -L "$RMQ_URL" -o "$RMQ_PKG"
        unzip -q "$RMQ_PKG"
        mv "rocketmq-all-${RMQ_VERSION}-bin-release" "$ROCKETMQ_HOME"
        chmod +x "$ROCKETMQ_HOME/bin/"*
        rm -f "$RMQ_PKG"
        cd -
    fi

    info "启动 NameServer..."
    export JAVA_OPT_EXT="-Xms128m -Xmx256m"
    nohup bash "$ROCKETMQ_HOME/bin/mqnamesrv" > /tmp/rmq-namesrv.log 2>&1 &
    wait_for_port localhost 9876 "RocketMQ NameServer" 20 3

    info "启动 Broker..."
    nohup bash "$ROCKETMQ_HOME/bin/mqbroker" \
        -n localhost:9876 \
        autoCreateTopicEnable=true \
        > /tmp/rmq-broker.log 2>&1 &
    wait_for_port localhost 10911 "RocketMQ Broker" 20 3

    info "启动 Proxy..."
    # 写 proxy 配置
    mkdir -p "$ROCKETMQ_HOME/conf"
    cat > "$ROCKETMQ_HOME/conf/rmq-proxy.json" << 'PROXY_EOF'
{
  "rocketMQClusterName": "DefaultCluster",
  "remotingListenPort": 18080,
  "grpcServerPort": 18081
}
PROXY_EOF
    nohup bash "$ROCKETMQ_HOME/bin/mqproxy" \
        -n localhost:9876 \
        -pc "$ROCKETMQ_HOME/conf/rmq-proxy.json" \
        > /tmp/rmq-proxy.log 2>&1 &
    wait_for_port localhost 18080 "RocketMQ Proxy" 20 3
fi

# ── RocketMQ 初始化：Topic + ConsumerGroup ────────────────────────────────────
RMQ_ADMIN="${ROCKETMQ_HOME}/bin/mqadmin"
TOPIC="topic_saa_studio_document_index"
GROUP="group_saa_studio_document_index"

if [[ -x "$RMQ_ADMIN" ]]; then
    info "检查 RocketMQ Topic: $TOPIC..."
    if "$RMQ_ADMIN" topicList -n localhost:9876 2>/dev/null | grep -q "$TOPIC"; then
        success "Topic 已存在，跳过"
    else
        info "创建 Topic..."
        "$RMQ_ADMIN" updateTopic \
            -n localhost:9876 \
            -t "$TOPIC" \
            -c DefaultCluster \
            -a "+message.type=NORMAL" 2>/dev/null && success "Topic 创建完成" || warn "Topic 创建失败，可能 Broker 未完全就绪，稍后手动执行"
    fi

    info "创建 ConsumerGroup: $GROUP..."
    "$RMQ_ADMIN" updateSubGroup \
        -n localhost:9876 \
        -g "$GROUP" \
        -c DefaultCluster 2>/dev/null && success "ConsumerGroup 创建完成" || warn "ConsumerGroup 创建失败（可能已存在或 Broker 未就绪）"
else
    warn "未找到 mqadmin（$RMQ_ADMIN），请手动创建 Topic 和 ConsumerGroup"
fi

# =============================================================================
# 6. Nacos 2
# =============================================================================
step "6/7  Nacos 2"

NACOS_RUNNING=false
if nc -z localhost "$NACOS_HTTP_PORT" 2>/dev/null; then
    NACOS_RUNNING=true
    success "Nacos 已运行（端口 $NACOS_HTTP_PORT）"
fi

if [[ "$NACOS_RUNNING" == false ]]; then
    NACOS_VERSION="2.4.3"
    NACOS_PKG="nacos-server-${NACOS_VERSION}.tar.gz"
    NACOS_URL="https://github.com/alibaba/nacos/releases/download/${NACOS_VERSION}/${NACOS_PKG}"

    if [[ ! -d "$NACOS_HOME" ]]; then
        info "下载 Nacos ${NACOS_VERSION}..."
        cd /tmp
        curl -L "$NACOS_URL" -o "$NACOS_PKG"
        tar -xzf "$NACOS_PKG"
        mv nacos "$NACOS_HOME"
        rm -f "$NACOS_PKG"
        cd -
    fi

    info "以 standalone 模式启动 Nacos..."
    export JAVA_OPTS="-Xms128m -Xmx256m -Xmn64m"
    nohup bash "$NACOS_HOME/bin/startup.sh" -m standalone > /tmp/nacos.log 2>&1 &
    wait_for_http "http://localhost:${NACOS_HTTP_PORT}/nacos/v1/console/health/liveness" "Nacos" 30 3
fi

success "Nacos 就绪（Console: http://localhost:${NACOS_HTTP_PORT}/nacos，user=nacos/nacos）"

# =============================================================================
# 7. 汇总检查
# =============================================================================
step "7/7  最终状态检查"

echo ""
printf "%-25s %-10s %s\n" "服务" "端口" "状态"
printf "%-25s %-10s %s\n" "─────────────────────" "──────" "──────"

check_service() {
    local name="$1" host="$2" port="$3"
    if nc -z "$host" "$port" 2>/dev/null; then
        printf "%-25s %-10s ${GREEN}%s${NC}\n" "$name" "$port" "✓ 运行中"
    else
        printf "%-25s %-10s ${RED}%s${NC}\n" "$name" "$port" "✗ 未响应"
    fi
}

check_service "MySQL"                   localhost 3306
check_service "Redis"                   localhost 6379
check_service "Elasticsearch"           localhost 9200
check_service "RocketMQ NameServer"     localhost 9876
check_service "RocketMQ Proxy (gRPC)"   localhost 18080
check_service "Nacos HTTP"              localhost "$NACOS_HTTP_PORT"

echo ""
info "ES pipeline:  $(curl -sf "${ES_URL}/_ingest/pipeline/parsing_loongsuite_traces" > /dev/null 2>&1 && echo '✓ 已创建' || echo '✗ 未创建')"
info "ES index:     $(curl -sf "${ES_URL}/loongsuite_traces/_mapping" > /dev/null 2>&1 && echo '✓ 已创建' || echo '✗ 未创建')"
info "MySQL admin:  $(mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} admin -e 'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA="admin"' 2>/dev/null | tail -1 || echo '检查失败') 张表"
info "MySQL agentscope: $(mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} agentscope -e 'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA="agentscope"' 2>/dev/null | tail -1 || echo '检查失败') 张表"

echo ""
success "install-deps.sh 执行完成！"
echo ""
echo -e "${CYAN}下一步：${NC}"
echo "  1. 配置模型 API Key："
echo "     cp spring-ai-alibaba-admin-server-start/model-config-dashscope.yaml \\"
echo "        spring-ai-alibaba-admin-server-start/model-config.yaml"
echo "     # 编辑填入 API Key"
echo ""
echo "  2. 启动后端："
echo "     cd spring-ai-alibaba-admin-server-start"
echo "     mvn spring-boot:run -Dspring-boot.run.profiles=dev"
echo ""
echo "  3. 访问管理台：http://localhost:8080/admin"
