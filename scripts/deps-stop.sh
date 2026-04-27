#!/usr/bin/env bash
# deps-stop.sh — 一键停止所有依赖中间件
# 停止顺序与启动顺序相反：LoongCollector → Nacos → RocketMQ → ES → Redis → MySQL
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 颜色 ──────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
header(){ echo -e "\n${BOLD}${CYAN}── $* ──${NC}"; }

# ── 路径配置（与 install-deps.sh / deps-start.sh 保持一致）──────────────────
ES_HOME="${ES_HOME:-$HOME/elasticsearch-8.18.3}"
RMQ_HOME="${RMQ_HOME:-$HOME/rocketmq}"
NACOS_HOME="${NACOS_HOME:-$HOME/nacos}"
LC_HOME="${LC_HOME:-$HOME/loongcollector}"

# ── 工具函数 ──────────────────────────────────────────────────────────────────
# port_listening <port>
port_listening() { nc -z localhost "$1" 2>/dev/null; }

# kill_pid_file <pid_file> <name>  — 读 pid file 发 SIGTERM，等进程退出
kill_pid_file() {
  local pid_file="$1" name="$2"
  if [[ -f "$pid_file" ]]; then
    local pid
    pid="$(cat "$pid_file" 2>/dev/null || echo "")"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      info "停止 $name (pid $pid)..."
      kill -TERM "$pid" 2>/dev/null || true
      # 最多等 15s
      for i in $(seq 1 15); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 1
      done
      if kill -0 "$pid" 2>/dev/null; then
        warn "$name 未响应 SIGTERM，发送 SIGKILL..."
        kill -KILL "$pid" 2>/dev/null || true
      fi
      rm -f "$pid_file"
      ok "$name 已停止"
    else
      info "$name pid $pid 已不存在，清理 pid 文件"
      rm -f "$pid_file"
    fi
  else
    info "$name 无 pid 文件，尝试按端口查找进程..."
  fi
}

# kill_by_port <port> <name>  — 按端口找 pid 并发 SIGTERM（兜底手段）
kill_by_port() {
  local port="$1" name="$2"
  if ! port_listening "$port"; then return 0; fi
  local pid
  pid=$(lsof -ti "tcp:$port" 2>/dev/null | head -1 || echo "")
  if [[ -n "$pid" ]]; then
    info "停止 $name (端口 $port，pid $pid)..."
    kill -TERM "$pid" 2>/dev/null || true
    for i in $(seq 1 10); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 1
    done
    if kill -0 "$pid" 2>/dev/null; then
      warn "$name 未响应 SIGTERM，发送 SIGKILL..."
      kill -KILL "$pid" 2>/dev/null || true
    fi
    ok "$name 已停止"
  fi
}

# ── 检测 OS ───────────────────────────────────────────────────────────────────
OS="$(uname -s)"
USE_SYSTEMD=false
[[ "$OS" == "Linux" ]] && command -v systemctl >/dev/null 2>&1 && USE_SYSTEMD=true

# ──────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║       deps-stop.sh — 停止所有依赖中间件          ║"
echo "╚══════════════════════════════════════════════════╝${NC}"

# ── 1. LoongCollector（可选）─────────────────────────────────────────────────
header "LoongCollector (port 4318)"
if port_listening 4318; then
  kill_pid_file "$LC_HOME/loongcollector.pid" "LoongCollector"
  kill_by_port 4318 "LoongCollector"
else
  ok "LoongCollector 未在运行，跳过"
fi

# ── 2. Nacos ──────────────────────────────────────────────────────────────────
header "Nacos (port 8848)"
if port_listening 8848; then
  if [[ -f "$NACOS_HOME/bin/shutdown.sh" ]]; then
    info "调用 Nacos shutdown.sh..."
    "$NACOS_HOME/bin/shutdown.sh" > /dev/null 2>&1 || true
    for i in $(seq 1 15); do
      port_listening 8848 || break
      sleep 1
    done
    if port_listening 8848; then
      warn "Nacos shutdown.sh 无效，按端口强制停止..."
      kill_by_port 8848 "Nacos"
    fi
    ok "Nacos 已停止"
  else
    kill_by_port 8848 "Nacos"
  fi
else
  ok "Nacos 未在运行，跳过"
fi

# ── 3. RocketMQ ───────────────────────────────────────────────────────────────
header "RocketMQ Broker+Proxy (18080) + NameServer (9876)"

# 先停 Broker（依赖 NameServer 做下线通知）
if port_listening 18080; then
  kill_pid_file "$RMQ_HOME/broker.pid" "RocketMQ Broker"
  kill_by_port 18080 "RocketMQ Proxy"
else
  ok "RocketMQ Broker 未在运行，跳过"
fi

# 再停 NameServer
if port_listening 9876; then
  kill_pid_file "$RMQ_HOME/namesrv.pid" "RocketMQ NameServer"
  kill_by_port 9876 "RocketMQ NameServer"
else
  ok "RocketMQ NameServer 未在运行，跳过"
fi

# ── 4. Elasticsearch ──────────────────────────────────────────────────────────
header "Elasticsearch (port 9200)"
if port_listening 9200; then
  # ES 写了自己的 pid 文件
  ES_PID_FILE="$ES_HOME/elasticsearch.pid"
  if [[ -f "$ES_PID_FILE" ]]; then
    kill_pid_file "$ES_PID_FILE" "Elasticsearch"
    # ES 进程停止后删不删 pid 文件由 ES 自己决定，确保清理
    rm -f "$ES_PID_FILE"
  else
    kill_by_port 9200 "Elasticsearch"
  fi
  # 等端口释放（ES 优雅关闭需要几秒）
  for i in $(seq 1 15); do
    port_listening 9200 || break
    sleep 1
  done
  port_listening 9200 && warn "ES 端口 9200 仍在监听，可能需要手动检查" || ok "Elasticsearch 已停止"
else
  ok "Elasticsearch 未在运行，跳过"
fi

# ── 5. Redis ──────────────────────────────────────────────────────────────────
header "Redis (port 6379)"
if port_listening 6379; then
  if [[ "$USE_SYSTEMD" == true ]]; then
    sudo systemctl stop redis-server
  elif command -v brew >/dev/null 2>&1; then
    brew services stop redis
  else
    # redis-cli shutdown 是最干净的停止方式
    redis-cli shutdown nosave 2>/dev/null || kill_by_port 6379 "Redis"
  fi
  for i in $(seq 1 10); do
    port_listening 6379 || break
    sleep 1
  done
  ok "Redis 已停止"
else
  ok "Redis 未在运行，跳过"
fi

# ── 6. MySQL ──────────────────────────────────────────────────────────────────
header "MySQL (port 3306)"
if port_listening 3306; then
  if [[ "$USE_SYSTEMD" == true ]]; then
    sudo systemctl stop mysql
  elif command -v brew >/dev/null 2>&1; then
    brew services stop mysql
  else
    mysqladmin -u root shutdown 2>/dev/null || kill_by_port 3306 "MySQL"
  fi
  for i in $(seq 1 15); do
    port_listening 3306 || break
    sleep 1
  done
  ok "MySQL 已停止"
else
  ok "MySQL 未在运行，跳过"
fi

# ── 汇总 ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}"
echo -e "${BOLD}          停止状态汇总${NC}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}"

_check_stopped() {
  local name="$1" port="$2"
  if port_listening "$port"; then
    echo -e "  ${RED}✗${NC} $name (port $port) — 仍在运行"
  else
    echo -e "  ${GREEN}✓${NC} $name (port $port) — 已停止"
  fi
}

_check_stopped "MySQL"          3306
_check_stopped "Redis"          6379
_check_stopped "Elasticsearch"  9200
_check_stopped "RocketMQ NS"    9876
_check_stopped "RocketMQ Proxy" 18080
_check_stopped "Nacos"          8848
_check_stopped "LoongCollector" 4318

echo ""
