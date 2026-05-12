#!/usr/bin/env bash
# =============================================================================
# deps-stop.sh  —  停止所有中间件依赖
#
# 停止顺序（与启动相反）：Nacos → RocketMQ → Elasticsearch → Redis → MySQL
#
# 停止策略：
#   MySQL / Redis    brew services stop
#   Elasticsearch    用 pid 文件 SIGTERM，等进程退出
#   RocketMQ         mqshutdown namesrv/broker，再兜底 SIGTERM
#   Nacos            nacos/bin/shutdown.sh
# =============================================================================

set -uo pipefail   # 不用 -e，stop 某个失败不应中断后续

ES_HOME="${ES_HOME:-$HOME/elasticsearch-8.18.3}"
ROCKETMQ_HOME="${ROCKETMQ_HOME:-$HOME/rocketmq-5.3.2}"
NACOS_HOME="${NACOS_HOME:-$HOME/nacos}"
NACOS_HTTP_PORT="${NACOS_HTTP_PORT:-8848}"

LOG_DIR="$HOME/logs/saa-deps"

G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; R='\033[0;31m'; N='\033[0m'
ok()   { echo -e "${G}[✓]${N} $*"; }
info() { echo -e "${C}[…]${N} $*"; }
warn() { echo -e "${Y}[!]${N} $*"; }

# ── kill_pid: 发 SIGTERM，等进程退出（最多 15s），再 SIGKILL ─────────────────
kill_pid() {
    local pid="$1" label="$2"
    if ! kill -0 "$pid" 2>/dev/null; then
        warn "$label (PID $pid) 已不存在"
        return 0
    fi
    info "停止 $label (PID $pid) …"
    kill "$pid" 2>/dev/null || true
    for i in $(seq 1 15); do
        kill -0 "$pid" 2>/dev/null || { ok "$label 已停止"; return 0; }
        sleep 1
    done
    warn "$label 未在 15s 内退出，强制 SIGKILL"
    kill -9 "$pid" 2>/dev/null || true
    ok "$label 已强制停止"
}

# ── kill_by_pattern: 按进程关键字匹配 ───────────────────────────────────────
kill_by_pattern() {
    local pattern="$1" label="$2"
    local pids
    pids=$(pgrep -f "$pattern" 2>/dev/null || true)
    if [[ -z "$pids" ]]; then
        warn "$label 未找到运行进程"
        return 0
    fi
    for pid in $pids; do
        kill_pid "$pid" "$label"
    done
}

echo ""
echo -e "${C}════════════════════════════════════════════${N}"
echo -e "${C}  SAA 中间件停止脚本  deps-stop.sh${N}"
echo -e "${C}════════════════════════════════════════════${N}"
echo ""

# =============================================================================
# 1. Nacos
# =============================================================================
echo -e "${C}── 1/5  Nacos ──────────────────────────────${N}"
if nc -z localhost "$NACOS_HTTP_PORT" 2>/dev/null; then
    if [[ -f "$NACOS_HOME/bin/shutdown.sh" ]]; then
        info "执行 nacos/bin/shutdown.sh …"
        bash "$NACOS_HOME/bin/shutdown.sh" 2>/dev/null || true
        # shutdown.sh 只是 kill，等一下
        sleep 2
        # 兜底：若进程还在
        kill_by_pattern "nacos.nacos" "Nacos"
    else
        kill_by_pattern "nacos.nacos" "Nacos"
    fi
else
    ok "Nacos 未运行，跳过"
fi

# =============================================================================
# 2. RocketMQ（先 broker，再 namesrv）
# =============================================================================
echo ""
echo -e "${C}── 2/5  RocketMQ ───────────────────────────${N}"

# 2a. broker（含内嵌 proxy）
if nc -z localhost 18080 2>/dev/null || nc -z localhost 10911 2>/dev/null; then
    info "停止 RocketMQ Broker+Proxy …"
    # 官方停止命令
    if [[ -x "$ROCKETMQ_HOME/bin/mqshutdown" ]]; then
        "$ROCKETMQ_HOME/bin/mqshutdown" broker 2>/dev/null || true
        sleep 3
    fi
    # PID 文件兜底
    if [[ -f "$LOG_DIR/rmq-broker.pid" ]]; then
        kill_pid "$(cat "$LOG_DIR/rmq-broker.pid")" "RocketMQ Broker"
        rm -f "$LOG_DIR/rmq-broker.pid"
    fi
    # 进程名兜底
    kill_by_pattern "org.apache.rocketmq.proxy.ProxyStartup" "RocketMQ Broker+Proxy"
    kill_by_pattern "org.apache.rocketmq.broker.BrokerStartup" "RocketMQ Broker"
else
    ok "RocketMQ Broker 未运行，跳过"
fi

# 2b. NameServer
if nc -z localhost 9876 2>/dev/null; then
    info "停止 RocketMQ NameServer …"
    if [[ -x "$ROCKETMQ_HOME/bin/mqshutdown" ]]; then
        "$ROCKETMQ_HOME/bin/mqshutdown" namesrv 2>/dev/null || true
        sleep 2
    fi
    if [[ -f "$LOG_DIR/rmq-namesrv.pid" ]]; then
        kill_pid "$(cat "$LOG_DIR/rmq-namesrv.pid")" "RocketMQ NameServer"
        rm -f "$LOG_DIR/rmq-namesrv.pid"
    fi
    kill_by_pattern "org.apache.rocketmq.namesrv.NamesrvStartup" "RocketMQ NameServer"
else
    ok "RocketMQ NameServer 未运行，跳过"
fi

# =============================================================================
# 3. Elasticsearch
# =============================================================================
echo ""
echo -e "${C}── 3/5  Elasticsearch ──────────────────────${N}"
if nc -z localhost 9200 2>/dev/null; then
    ES_STOPPED=false
    # 优先用 pid 文件
    if [[ -f "$LOG_DIR/elasticsearch.pid" ]]; then
        kill_pid "$(cat "$LOG_DIR/elasticsearch.pid")" "Elasticsearch"
        rm -f "$LOG_DIR/elasticsearch.pid"
        ES_STOPPED=true
    fi
    # 兜底：按进程目录匹配（避免误杀其他 java 进程）
    if [[ "$ES_STOPPED" == false ]]; then
        ES_PID=$(pgrep -f "elasticsearch-8" 2>/dev/null | head -1 || true)
        if [[ -n "$ES_PID" ]]; then
            kill_pid "$ES_PID" "Elasticsearch"
        else
            # 最后手段：用 cwd 匹配
            ES_PID=$(lsof -i :9200 2>/dev/null | awk 'NR>1 {print $2}' | head -1 || true)
            [[ -n "$ES_PID" ]] && kill_pid "$ES_PID" "Elasticsearch"
        fi
    fi
    # 等端口释放
    for i in $(seq 1 20); do
        nc -z localhost 9200 2>/dev/null || { ok "Elasticsearch 端口已释放"; break; }
        sleep 1
    done
else
    ok "Elasticsearch 未运行，跳过"
fi

# =============================================================================
# 4. Redis（brew services）
# =============================================================================
echo ""
echo -e "${C}── 4/5  Redis ──────────────────────────────${N}"
if nc -z localhost 6379 2>/dev/null; then
    info "停止 Redis …"
    brew services stop redis 2>/dev/null || true
    # 等端口释放
    for i in $(seq 1 10); do
        nc -z localhost 6379 2>/dev/null || { ok "Redis 已停止"; break; }
        sleep 1
    done
else
    ok "Redis 未运行，跳过"
fi

# =============================================================================
# 5. MySQL（brew services）
# =============================================================================
echo ""
echo -e "${C}── 5/5  MySQL ──────────────────────────────${N}"
if nc -z localhost 3306 2>/dev/null; then
    info "停止 MySQL …"
    brew services stop mysql 2>/dev/null || true
    for i in $(seq 1 15); do
        nc -z localhost 3306 2>/dev/null || { ok "MySQL 已停止"; break; }
        sleep 1
    done
else
    ok "MySQL 未运行，跳过"
fi

# =============================================================================
# 汇总
# =============================================================================
echo ""
echo -e "${C}════════════════════════════════════════════${N}"
echo -e "${C}  停止完成 — 端口验证${N}"
echo -e "${C}════════════════════════════════════════════${N}"
check_stopped() {
    local port="$1" label="$2"
    if nc -z localhost "$port" 2>/dev/null; then
        echo -e "  ${R}✗${N} $label (端口 $port 仍在监听)"
    else
        echo -e "  ${G}✓${N} $label 已停止"
    fi
}
check_stopped 3306            "MySQL"
check_stopped 6379            "Redis"
check_stopped 9200            "Elasticsearch"
check_stopped 9876            "RocketMQ NameServer"
check_stopped 18080           "RocketMQ Proxy"
check_stopped "$NACOS_HTTP_PORT" "Nacos"
echo ""
