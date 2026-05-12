#!/usr/bin/env bash
# =============================================================================
# deps-start.sh  —  启动所有中间件依赖，等服务就绪后再返回
#
# 启动顺序：MySQL → Redis → Elasticsearch → RocketMQ (namesrv → broker+proxy) → Nacos
#
# 中间件管理方式：
#   MySQL / Redis    brew services
#   Elasticsearch    手动 tar 包，~/elasticsearch-8.18.3/bin/elasticsearch
#   RocketMQ         手动 tar 包，~/rocketmq-5.3.2/；broker 带 --enable-proxy
#   Nacos            手动 tar 包，~/nacos/bin/startup.sh
#
# 环境变量覆盖（可选）：
#   ES_HOME          默认 ~/elasticsearch-8.18.3
#   ROCKETMQ_HOME    默认 ~/rocketmq-5.3.2
#   NACOS_HOME       默认 ~/nacos
#   NACOS_HTTP_PORT  默认 8848
# =============================================================================

set -euo pipefail

ES_HOME="${ES_HOME:-$HOME/elasticsearch-8.18.3}"
ROCKETMQ_HOME="${ROCKETMQ_HOME:-$HOME/rocketmq-5.3.2}"
NACOS_HOME="${NACOS_HOME:-$HOME/nacos}"
NACOS_HTTP_PORT="${NACOS_HTTP_PORT:-8848}"

LOG_DIR="$HOME/logs/saa-deps"
mkdir -p "$LOG_DIR"

# ── 颜色 ──────────────────────────────────────────────────────────────────────
G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; R='\033[0;31m'; N='\033[0m'
ok()   { echo -e "${G}[✓]${N} $*"; }
info() { echo -e "${C}[…]${N} $*"; }
warn() { echo -e "${Y}[!]${N} $*"; }
fail() { echo -e "${R}[✗]${N} $*"; exit 1; }

# ── wait_port: 等到 TCP 端口可连，超时后 fail ──────────────────────────────
wait_port() {
    local host="$1" port="$2" label="$3"
    local retries="${4:-40}" delay="${5:-2}"
    info "等待 $label 端口 $port …"
    for i in $(seq 1 "$retries"); do
        nc -z "$host" "$port" 2>/dev/null && { ok "$label 端口就绪"; return 0; }
        sleep "$delay"
    done
    fail "$label 端口 $port 超时未就绪（${retries}×${delay}s）"
}

# ── wait_http: 等到 HTTP 返回 2xx/3xx ──────────────────────────────────────
wait_http() {
    local url="$1" label="$2"
    local retries="${3:-40}" delay="${4:-3}"
    info "等待 $label HTTP 就绪 …"
    for i in $(seq 1 "$retries"); do
        curl -sf "$url" > /dev/null 2>&1 && { ok "$label HTTP 就绪"; return 0; }
        sleep "$delay"
    done
    fail "$label HTTP 超时未就绪（${retries}×${delay}s）"
}

# ── already_up: 端口已监听则跳过 ─────────────────────────────────────────────
already_up() {
    local port="$1" label="$2"
    if nc -z localhost "$port" 2>/dev/null; then
        ok "$label 已在运行（端口 $port）"
        return 0
    fi
    return 1
}

echo ""
echo -e "${C}════════════════════════════════════════════${N}"
echo -e "${C}  SAA 中间件启动脚本  deps-start.sh${N}"
echo -e "${C}════════════════════════════════════════════${N}"
echo ""

# =============================================================================
# 1. MySQL（brew services）
# =============================================================================
echo -e "${C}── 1/5  MySQL ──────────────────────────────${N}"
if ! already_up 3306 "MySQL"; then
    info "启动 MySQL …"
    brew services start mysql
    wait_port localhost 3306 "MySQL"
fi

# =============================================================================
# 2. Redis（brew services）
# =============================================================================
echo ""
echo -e "${C}── 2/5  Redis ──────────────────────────────${N}"
if ! already_up 6379 "Redis"; then
    info "启动 Redis …"
    brew services start redis
    wait_port localhost 6379 "Redis"
fi

# =============================================================================
# 3. Elasticsearch（手动 tar 包，~/elasticsearch-8.18.3）
# =============================================================================
echo ""
echo -e "${C}── 3/5  Elasticsearch ──────────────────────${N}"
if ! already_up 9200 "Elasticsearch"; then
    if [[ ! -x "$ES_HOME/bin/elasticsearch" ]]; then
        fail "未找到 Elasticsearch：$ES_HOME/bin/elasticsearch\n请确认 ES_HOME 路径正确"
    fi
    info "启动 Elasticsearch（$ES_HOME）…"
    # ES 要以 ES_HOME 为工作目录，否则找不到相对路径的 modules/
    ES_JAVA_OPTS="${ES_JAVA_OPTS:--Xms512m -Xmx512m}"
    export ES_JAVA_OPTS
    nohup "$ES_HOME/bin/elasticsearch" \
        > "$LOG_DIR/elasticsearch.log" 2>&1 &
    echo $! > "$LOG_DIR/elasticsearch.pid"
    wait_http "http://localhost:9200/_cluster/health" "Elasticsearch" 50 4
fi
ok "Elasticsearch 版本：$(curl -sf http://localhost:9200/ | python3 -c "import sys,json; print(json.load(sys.stdin)['version']['number'])" 2>/dev/null || echo unknown)"

# =============================================================================
# 4. RocketMQ（手动 tar 包，~/rocketmq-5.3.2）
#    启动顺序：namesrv → broker（带 --enable-proxy，内嵌 proxy）
# =============================================================================
echo ""
echo -e "${C}── 4/5  RocketMQ ───────────────────────────${N}"

if [[ ! -x "$ROCKETMQ_HOME/bin/mqnamesrv" ]]; then
    fail "未找到 RocketMQ：$ROCKETMQ_HOME/bin/mqnamesrv\n请确认 ROCKETMQ_HOME 路径正确"
fi

# 4a. NameServer（端口 9876）
if already_up 9876 "RocketMQ NameServer"; then
    : # 已运行
else
    info "启动 NameServer …"
    JAVA_OPT_EXT="-Xms128m -Xmx256m -Xmn128m" \
        nohup "$ROCKETMQ_HOME/bin/mqnamesrv" \
        > "$LOG_DIR/rmq-namesrv.log" 2>&1 &
    echo $! > "$LOG_DIR/rmq-namesrv.pid"
    wait_port localhost 9876 "RocketMQ NameServer"
fi

# 4b. Broker（带 --enable-proxy，同时监听 10911 + 18080）
if already_up 18080 "RocketMQ Broker+Proxy"; then
    : # 已运行
else
    # 确保 proxy 配置文件存在
    mkdir -p "$ROCKETMQ_HOME/conf"
    if [[ ! -f "$ROCKETMQ_HOME/conf/rmq-proxy.json" ]]; then
        cat > "$ROCKETMQ_HOME/conf/rmq-proxy.json" <<'PROXY_EOF'
{
  "rocketMQClusterName": "DefaultCluster",
  "remotingListenPort": 18080,
  "grpcServerPort": 18081
}
PROXY_EOF
    fi
    info "启动 Broker（内嵌 Proxy）…"
    JAVA_OPT_EXT="-Xms256m -Xmx512m -Xmn256m -XX:MaxDirectMemorySize=128m" \
        nohup "$ROCKETMQ_HOME/bin/mqbroker" \
        -n localhost:9876 \
        --enable-proxy \
        -pc "$ROCKETMQ_HOME/conf/rmq-proxy.json" \
        > "$LOG_DIR/rmq-broker.log" 2>&1 &
    echo $! > "$LOG_DIR/rmq-broker.pid"
    # broker 注册到 namesrv 需要时间，先等 10911，再等 18080
    wait_port localhost 10911 "RocketMQ Broker" 30 3
    wait_port localhost 18080 "RocketMQ Proxy"  30 3
fi

# =============================================================================
# 5. Nacos（手动 tar 包，~/nacos）
# =============================================================================
echo ""
echo -e "${C}── 5/5  Nacos ──────────────────────────────${N}"

if [[ ! -f "$NACOS_HOME/bin/startup.sh" ]]; then
    fail "未找到 Nacos：$NACOS_HOME/bin/startup.sh\n请确认 NACOS_HOME 路径正确"
fi

if already_up "$NACOS_HTTP_PORT" "Nacos"; then
    : # 已运行
else
    info "启动 Nacos standalone …"
    # startup.sh 内部会 nohup，自行后台化；stdout 写到 nacos/logs/start.out
    CUSTOM_NACOS_MEMORY="-Xms128m -Xmx256m -Xmn64m" \
        bash "$NACOS_HOME/bin/startup.sh" -m standalone \
        > "$LOG_DIR/nacos-startup.log" 2>&1
    wait_http "http://localhost:${NACOS_HTTP_PORT}/nacos/v1/console/health/liveness" \
        "Nacos" 40 3
fi

# =============================================================================
# 汇总
# =============================================================================
echo ""
echo -e "${C}════════════════════════════════════════════${N}"
echo -e "${C}  全部中间件已就绪${N}"
echo -e "${C}════════════════════════════════════════════${N}"
_dot() { nc -z localhost "$1" 2>/dev/null && echo -e "${G}✓${N}" || echo -e "${R}✗${N}"; }
echo -e "  $(_dot 3306)  MySQL 3306"
echo -e "  $(_dot 6379)  Redis 6379"
echo -e "  $(_dot 9200)  Elasticsearch 9200"
echo -e "  $(_dot 9876)  RocketMQ NameServer 9876"
echo -e "  $(_dot 18080) RocketMQ Proxy 18080"
echo -e "  $(_dot "$NACOS_HTTP_PORT") Nacos ${NACOS_HTTP_PORT}"
echo ""
echo -e "  日志目录：${C}$LOG_DIR${N}"
echo ""
