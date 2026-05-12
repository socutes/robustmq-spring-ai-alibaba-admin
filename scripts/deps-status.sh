#!/usr/bin/env bash
# =============================================================================
# deps-status.sh  —  查看所有中间件的运行状态
#
# 输出每个中间件：端口 / 版本 / PID / 进程运行时长 / 关键健康指标
# =============================================================================

set -uo pipefail

ES_HOME="${ES_HOME:-$HOME/elasticsearch-8.18.3}"
ROCKETMQ_HOME="${ROCKETMQ_HOME:-$HOME/rocketmq-5.3.2}"
NACOS_HOME="${NACOS_HOME:-$HOME/nacos}"
NACOS_HTTP_PORT="${NACOS_HTTP_PORT:-8848}"

LOG_DIR="$HOME/logs/saa-deps"

G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; R='\033[0;31m'; DIM='\033[2m'; N='\033[0m'

# ── 工具函数 ──────────────────────────────────────────────────────────────────

# 端口对应的 PID
pid_for_port() {
    lsof -ti :"$1" 2>/dev/null | head -1 || true
}

# 进程已运行时长（macOS ps -o etime= 格式 [[DD-]HH:]MM:SS）
proc_elapsed() {
    local pid="$1"
    ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ' || echo "?"
}

# 输出一行状态
# usage: status_row <label> <port> <up_extra> <down_msg>
status_row() {
    local label="$1" port="$2" up_extra="$3" down_msg="$4"
    if nc -z localhost "$port" 2>/dev/null; then
        local pid; pid=$(pid_for_port "$port")
        local elapsed; elapsed=$(proc_elapsed "$pid")
        printf "  ${G}●${N} %-28s ${G}运行中${N}  PID=%-7s 运行时长=%-12s %s\n" \
            "$label" "${pid:-?}" "${elapsed:-?}" "$up_extra"
    else
        printf "  ${R}○${N} %-28s ${R}未运行${N}  %s\n" "$label" "$down_msg"
    fi
}

echo ""
echo -e "${C}════════════════════════════════════════════${N}"
echo -e "${C}  SAA 中间件状态  deps-status.sh${N}"
echo -e "${C}════════════════════════════════════════════${N}"
echo ""

# =============================================================================
# 1. MySQL
# =============================================================================
echo -e "${C}── MySQL${N}"
MYSQL_EXTRA=""
if nc -z localhost 3306 2>/dev/null; then
    MYSQL_VER=$(mysql --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "?")
    MYSQL_EXTRA="版本=$MYSQL_VER"
    BREW_STATUS=$(brew services list 2>/dev/null | awk '/^mysql /{print $2}')
    [[ -n "$BREW_STATUS" ]] && MYSQL_EXTRA+="  brew=$BREW_STATUS"
fi
status_row "MySQL :3306" 3306 "$MYSQL_EXTRA" "(brew services start mysql)"

# 额外：检查 schema 和表
if nc -z localhost 3306 2>/dev/null; then
    ADMIN_TABLES=$(mysql -uadmin -padmin admin \
        -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='admin'" \
        2>/dev/null | tail -1 || echo "?")
    AGENTSCOPE_TABLES=$(mysql -uadmin -padmin agentscope \
        -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='agentscope'" \
        2>/dev/null | tail -1 || echo "?")
    echo -e "    ${DIM}admin 库: ${ADMIN_TABLES} 张表 | agentscope 库: ${AGENTSCOPE_TABLES} 张表${N}"
fi
echo ""

# =============================================================================
# 2. Redis
# =============================================================================
echo -e "${C}── Redis${N}"
REDIS_EXTRA=""
if nc -z localhost 6379 2>/dev/null; then
    REDIS_VER=$(redis-cli --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "?")
    REDIS_PING=$(redis-cli ping 2>/dev/null || echo "?")
    REDIS_CLIENTS=$(redis-cli info clients 2>/dev/null | grep connected_clients | cut -d: -f2 | tr -d '\r' || echo "?")
    REDIS_MEM=$(redis-cli info memory 2>/dev/null | grep used_memory_human | cut -d: -f2 | tr -d '\r ' || echo "?")
    REDIS_EXTRA="版本=$REDIS_VER  ping=$REDIS_PING  连接数=${REDIS_CLIENTS:-?}  内存=${REDIS_MEM:-?}"
fi
status_row "Redis :6379" 6379 "$REDIS_EXTRA" "(brew services start redis)"
echo ""

# =============================================================================
# 3. Elasticsearch
# =============================================================================
echo -e "${C}── Elasticsearch${N}"
ES_EXTRA=""
if nc -z localhost 9200 2>/dev/null; then
    ES_VER=$(curl -sf http://localhost:9200/ 2>/dev/null \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['version']['number'])" 2>/dev/null || echo "?")
    ES_HEALTH=$(curl -sf http://localhost:9200/_cluster/health 2>/dev/null \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['status'])" 2>/dev/null || echo "?")
    ES_SHARDS=$(curl -sf http://localhost:9200/_cluster/health 2>/dev/null \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"active={d['active_shards']} unassigned={d['unassigned_shards']}\")" 2>/dev/null || echo "?")
    ES_EXTRA="版本=$ES_VER  cluster=${ES_HEALTH}  shards: ${ES_SHARDS}"
fi
status_row "Elasticsearch :9200" 9200 "$ES_EXTRA" "($ES_HOME/bin/elasticsearch)"

if nc -z localhost 9200 2>/dev/null; then
    # Pipeline & Index
    PIPELINE_OK=$(curl -sf "http://localhost:9200/_ingest/pipeline/parsing_loongsuite_traces" \
        > /dev/null 2>&1 && echo "${G}✓ 存在${N}" || echo "${R}✗ 缺失${N}")
    INDEX_OK=$(curl -sf "http://localhost:9200/loongsuite_traces/_mapping" \
        > /dev/null 2>&1 && echo "${G}✓ 存在${N}" || echo "${R}✗ 缺失${N}")
    INDEX_DOCS=$(curl -sf "http://localhost:9200/loongsuite_traces/_count" 2>/dev/null \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('count','?'))" 2>/dev/null || echo "?")
    echo -e "    ${DIM}pipeline: ${PIPELINE_OK}${DIM}  |  loongsuite_traces index: ${INDEX_OK}${DIM}  docs=${INDEX_DOCS}${N}"
fi
echo ""

# =============================================================================
# 4. RocketMQ
# =============================================================================
echo -e "${C}── RocketMQ${N}"

# NameServer
NAMESRV_EXTRA=""
if nc -z localhost 9876 2>/dev/null; then
    NS_PID=$(pgrep -f "NamesrvStartup" 2>/dev/null | head -1 || true)
    NAMESRV_EXTRA="PID=${NS_PID:-?}"
fi
status_row "RocketMQ NameServer :9876" 9876 "$NAMESRV_EXTRA" "($ROCKETMQ_HOME/bin/mqnamesrv)"

# Broker + Proxy（同一进程，带 --enable-proxy）
BROKER_EXTRA=""
if nc -z localhost 18080 2>/dev/null; then
    BR_PID=$(pgrep -f "ProxyStartup" 2>/dev/null | head -1 || \
             pgrep -f "BrokerStartup" 2>/dev/null | head -1 || true)
    BROKER_EXTRA="PID=${BR_PID:-?}"
fi
status_row "RocketMQ Broker+Proxy :10911/:18080" 18080 "$BROKER_EXTRA" \
    "($ROCKETMQ_HOME/bin/mqbroker -n localhost:9876 --enable-proxy)"

# Topic & ConsumerGroup
if nc -z localhost 9876 2>/dev/null && [[ -x "$ROCKETMQ_HOME/bin/mqadmin" ]]; then
    TOPIC="topic_saa_studio_document_index"
    GROUP="group_saa_studio_document_index"
    TOPIC_OK=$("$ROCKETMQ_HOME/bin/mqadmin" topicList -n localhost:9876 2>/dev/null \
        | grep -q "$TOPIC" && echo "${G}✓ 存在${N}" || echo "${R}✗ 缺失${N}")
    echo -e "    ${DIM}topic: ${TOPIC_OK}${DIM}  |  group: $GROUP${N}"
fi
echo ""

# =============================================================================
# 5. Nacos
# =============================================================================
echo -e "${C}── Nacos${N}"
NACOS_EXTRA=""
if nc -z localhost "$NACOS_HTTP_PORT" 2>/dev/null; then
    NACOS_VER=$(curl -sf "http://localhost:${NACOS_HTTP_PORT}/nacos/v1/console/health/readiness" \
        -H "Authorization: Bearer " 2>/dev/null | head -c 200 || true)
    NACOS_HEALTH=$(curl -sf "http://localhost:${NACOS_HTTP_PORT}/nacos/v1/console/health/liveness" \
        2>/dev/null || echo "?")
    NACOS_EXTRA="health=${NACOS_HEALTH}"
fi
status_row "Nacos :${NACOS_HTTP_PORT}" "$NACOS_HTTP_PORT" "$NACOS_EXTRA" \
    "($NACOS_HOME/bin/startup.sh -m standalone)"

if nc -z localhost "$NACOS_HTTP_PORT" 2>/dev/null; then
    echo -e "    ${DIM}Console: http://localhost:${NACOS_HTTP_PORT}/nacos  (nacos/nacos)${N}"
fi
echo ""

# =============================================================================
# 汇总
# =============================================================================
echo -e "${C}════════════════════════════════════════════${N}"
# 端口一览
PORTS=(3306 6379 9200 9876 18080 "$NACOS_HTTP_PORT")
LABELS=("MySQL" "Redis" "Elasticsearch" "RocketMQ-NS" "RocketMQ-Proxy" "Nacos")
ALL_UP=true
printf "  "
for i in "${!PORTS[@]}"; do
    if nc -z localhost "${PORTS[$i]}" 2>/dev/null; then
        printf "${G}${LABELS[$i]}${N} "
    else
        printf "${R}${LABELS[$i]}↓${N} "
        ALL_UP=false
    fi
done
echo ""
if [[ "$ALL_UP" == true ]]; then
    echo -e "  ${G}所有中间件运行正常${N}"
else
    echo -e "  ${Y}有中间件未运行，执行 deps-start.sh 启动${N}"
fi
echo ""
