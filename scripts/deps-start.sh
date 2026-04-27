#!/usr/bin/env bash
# deps-start.sh — 一键启动 Spring AI Alibaba Admin 所需的所有中间件
# 混合场景：brew services（MySQL/Redis）+ 手动 jar/tar.gz（ES/RocketMQ/Nacos/LoongCollector）
# 每个服务启动后等待端口就绪再继续，确保 ready 而不只是"已启动"
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 颜色 ──────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }
header(){ echo -e "\n${BOLD}${CYAN}── $* ──${NC}"; }

# ── 路径配置（与 install-deps.sh 保持一致）────────────────────────────────────
ES_HOME="${ES_HOME:-$HOME/elasticsearch-8.18.3}"
RMQ_HOME="${RMQ_HOME:-$HOME/rocketmq}"
NACOS_HOME="${NACOS_HOME:-$HOME/nacos}"
LC_HOME="${LC_HOME:-$HOME/loongcollector}"

# ── 工具函数 ──────────────────────────────────────────────────────────────────
# wait_for_port <name> <port> [retries=30] [interval=2]
wait_for_port() {
  local name="$1" port="$2" retries="${3:-30}" interval="${4:-2}"
  info "等待 $name 端口 $port 就绪..."
  for i in $(seq 1 "$retries"); do
    if nc -z localhost "$port" 2>/dev/null; then
      ok "$name 端口 $port 已就绪"
      return 0
    fi
    sleep "$interval"
  done
  fail "$name 端口 $port 等待超时（${retries}×${interval}s）"
}

# port_listening <port>  → 0 if listening
port_listening() { nc -z localhost "$1" 2>/dev/null; }

# brew_service_running <name>
brew_service_running() {
  brew services list 2>/dev/null | awk '{print $1, $2}' | grep -q "^$1 started"
}

# ── 检测 OS ───────────────────────────────────────────────────────────────────
OS="$(uname -s)"
USE_SYSTEMD=false
[[ "$OS" == "Linux" ]] && command -v systemctl >/dev/null 2>&1 && USE_SYSTEMD=true

# ──────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║       deps-start.sh — 启动所有依赖中间件         ║"
echo "╚══════════════════════════════════════════════════╝${NC}"

# ── 1. MySQL ──────────────────────────────────────────────────────────────────
header "MySQL (port 3306)"
if port_listening 3306; then
  ok "MySQL 已在运行，跳过"
else
  if [[ "$USE_SYSTEMD" == true ]]; then
    sudo systemctl start mysql
  elif command -v brew >/dev/null 2>&1; then
    brew services start mysql
  else
    fail "无法启动 MySQL：不支持 brew services 也没有 systemctl"
  fi
  wait_for_port "MySQL" 3306 20 2
fi

# ── 2. Redis ──────────────────────────────────────────────────────────────────
header "Redis (port 6379)"
if port_listening 6379; then
  ok "Redis 已在运行，跳过"
else
  if [[ "$USE_SYSTEMD" == true ]]; then
    sudo systemctl start redis-server
  elif command -v brew >/dev/null 2>&1; then
    brew services start redis
  else
    fail "无法启动 Redis：不支持 brew services 也没有 systemctl"
  fi
  wait_for_port "Redis" 6379 15 2
fi

# ── 3. Elasticsearch ──────────────────────────────────────────────────────────
header "Elasticsearch (port 9200)"
if port_listening 9200; then
  ok "Elasticsearch 已在运行，跳过"
else
  if [[ ! -f "$ES_HOME/bin/elasticsearch" ]]; then
    fail "未找到 Elasticsearch：$ES_HOME/bin/elasticsearch 不存在\n请先运行 scripts/install-deps.sh"
  fi
  info "启动 Elasticsearch（daemon 模式）..."
  "$ES_HOME/bin/elasticsearch" -d -p "$ES_HOME/elasticsearch.pid"
  wait_for_port "Elasticsearch" 9200 45 4
fi

# 等待集群状态 green/yellow
info "等待 ES 集群健康..."
for i in $(seq 1 20); do
  STATUS=$(curl -s "http://localhost:9200/_cluster/health" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
  if [[ "$STATUS" == "green" || "$STATUS" == "yellow" ]]; then
    ok "ES 集群状态: $STATUS"
    break
  fi
  [[ "$i" -eq 20 ]] && warn "ES 集群未达到 green/yellow，继续..."
  sleep 3
done

# ── 4. RocketMQ ───────────────────────────────────────────────────────────────
header "RocketMQ NameServer (9876) + Proxy (18080)"
if port_listening 9876 && port_listening 18080; then
  ok "RocketMQ 已在运行，跳过"
else
  if [[ ! -f "$RMQ_HOME/bin/mqnamesrv" ]]; then
    fail "未找到 RocketMQ：$RMQ_HOME/bin/mqnamesrv 不存在\n请先运行 scripts/install-deps.sh"
  fi

  mkdir -p "$RMQ_HOME/logs"
  export JAVA_OPT_EXT="-Xms256m -Xmx512m"

  # NameServer
  if ! port_listening 9876; then
    info "启动 NameServer..."
    "$RMQ_HOME/bin/mqnamesrv" > "$RMQ_HOME/logs/namesrv.log" 2>&1 &
    echo $! > "$RMQ_HOME/namesrv.pid"
    wait_for_port "NameServer" 9876 20 2
  else
    ok "NameServer 已在运行"
  fi

  # Broker + Proxy
  if ! port_listening 18080; then
    # 确保 proxy 配置存在
    mkdir -p "$RMQ_HOME/conf"
    if [[ ! -f "$RMQ_HOME/conf/rmq-proxy.json" ]]; then
      cat > "$RMQ_HOME/conf/rmq-proxy.json" <<'JSON'
{
  "rocketMQClusterName": "DefaultCluster",
  "remotingListenPort": 18080,
  "grpcServerPort": 18081
}
JSON
    fi
    info "启动 Broker + Proxy..."
    "$RMQ_HOME/bin/mqbroker" \
      -n localhost:9876 \
      --enable-proxy \
      -pc "$RMQ_HOME/conf/rmq-proxy.json" \
      > "$RMQ_HOME/logs/broker.log" 2>&1 &
    echo $! > "$RMQ_HOME/broker.pid"
    wait_for_port "RocketMQ Proxy" 18080 30 3
  else
    ok "Broker + Proxy 已在运行"
  fi
fi

# ── 5. Nacos ──────────────────────────────────────────────────────────────────
header "Nacos (port 8848)"
if port_listening 8848; then
  ok "Nacos 已在运行，跳过"
else
  if [[ ! -f "$NACOS_HOME/bin/startup.sh" ]]; then
    fail "未找到 Nacos：$NACOS_HOME/bin/startup.sh 不存在\n请先运行 scripts/install-deps.sh"
  fi
  info "启动 Nacos（standalone）..."
  # startup.sh 本身已经是后台进程，这里不用 &
  export JAVA_OPT="-Xms256m -Xmx512m -Xmn128m"
  "$NACOS_HOME/bin/startup.sh" -m standalone > "$NACOS_HOME/logs/start-wrapper.log" 2>&1
  wait_for_port "Nacos" 8848 30 3
fi

# ── 6. LoongCollector（可选）─────────────────────────────────────────────────
header "LoongCollector (port 4318) [可选]"
if port_listening 4318; then
  ok "LoongCollector 已在运行，跳过"
else
  LC_BIN=""
  [[ -f "$LC_HOME/loongcollector" ]] && LC_BIN="$LC_HOME/loongcollector"
  [[ -f "$LC_HOME/bin/loongcollector" ]] && LC_BIN="$LC_HOME/bin/loongcollector"

  if [[ -z "$LC_BIN" ]]; then
    warn "LoongCollector 未安装（$LC_HOME），跳过（可观测性功能不可用）"
  else
    info "启动 LoongCollector..."
    "$LC_BIN" > "$LC_HOME/loongcollector.log" 2>&1 &
    echo $! > "$LC_HOME/loongcollector.pid"
    # 软等待，失败不退出
    for i in $(seq 1 10); do
      port_listening 4318 && ok "LoongCollector 端口 4318 已就绪" && break
      sleep 2
      [[ "$i" -eq 10 ]] && warn "LoongCollector 启动超时，可观测性功能可能不可用"
    done
  fi
fi

# ── 汇总 ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}"
echo -e "${BOLD}          启动状态汇总${NC}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}"

_status() {
  local name="$1" port="$2"
  if port_listening "$port"; then
    echo -e "  ${GREEN}✓${NC} $name (port $port)"
  else
    echo -e "  ${RED}✗${NC} $name (port $port) — 未就绪"
  fi
}

_status "MySQL"          3306
_status "Redis"          6379
_status "Elasticsearch"  9200
_status "RocketMQ NS"    9876
_status "RocketMQ Proxy" 18080
_status "Nacos"          8848
if [[ -n "${LC_BIN:-}" ]] || port_listening 4318; then
  _status "LoongCollector" 4318
else
  echo -e "  ${YELLOW}—${NC} LoongCollector       — 未安装（可选）"
fi

echo ""
echo -e "  ${YELLOW}！${NC} 确认 model-config.yaml 已配置 AI API Key"
echo -e "  ${GREEN}→${NC}  启动应用：cd spring-ai-alibaba-admin-server-start && mvn spring-boot:run"
echo ""
