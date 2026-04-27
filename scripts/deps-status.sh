#!/usr/bin/env bash
# deps-status.sh — 查看每个中间件的运行状态和端口监听情况
set -uo pipefail

# ── 颜色 ──────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
GRAY='\033[0;90m'; BOLD='\033[1m'; NC='\033[0m'

# ── 路径配置（与 install-deps.sh 保持一致）────────────────────────────────────
ES_HOME="${ES_HOME:-$HOME/elasticsearch-8.18.3}"
RMQ_HOME="${RMQ_HOME:-$HOME/rocketmq}"
NACOS_HOME="${NACOS_HOME:-$HOME/nacos}"
LC_HOME="${LC_HOME:-$HOME/loongcollector}"

# ── 工具函数 ──────────────────────────────────────────────────────────────────
OS="$(uname -s)"

# port_listening <port>
port_listening() { nc -z localhost "$1" 2>/dev/null; }

# pid_from_file <pid_file>  → prints pid or ""
pid_from_file() {
  local f="$1"
  [[ -f "$f" ]] && cat "$f" 2>/dev/null || echo ""
}

# pid_alive <pid>  → 0 if alive
pid_alive() { [[ -n "$1" ]] && kill -0 "$1" 2>/dev/null; }

# listening_ports_of_pid <pid>  → space-separated list of TCP ports
listening_ports_of_pid() {
  local pid="$1"
  if [[ "$OS" == "Darwin" ]]; then
    lsof -nP -iTCP -sTCP:LISTEN -p "$pid" 2>/dev/null \
      | awk 'NR>1 {match($9, /\*:([0-9]+)/, a); if (a[1]) printf a[1] " "}' \
      | tr ' ' '\n' | sort -un | tr '\n' ' '
  else
    ss -tlnp 2>/dev/null \
      | awk -v pid="$pid" '$0 ~ "pid="pid"," {match($4, /:([0-9]+)$/, a); print a[1]}' \
      | sort -un | tr '\n' ' '
  fi
}

# pids_on_port <port>  → space-separated pids
pids_on_port() {
  local port="$1"
  if [[ "$OS" == "Darwin" ]]; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {print $2}' | sort -u | tr '\n' ' '
  else
    ss -tlnp "sport = :$port" 2>/dev/null \
      | awk 'NR>1 {match($0, /pid=([0-9]+)/, a); if (a[1]) print a[1]}' | sort -u | tr '\n' ' '
  fi
}

# process_info <pid>  → "name (pid NNN, mem MB, cpu%)"
process_info() {
  local pid="$1"
  [[ -z "$pid" ]] && echo "" && return
  if [[ "$OS" == "Darwin" ]]; then
    ps -p "$pid" -o comm=,rss=,%cpu= 2>/dev/null \
      | awk '{printf "%s (pid '$pid', mem %.0fMB, cpu %s%%)", $1, $2/1024, $3}'
  else
    ps -p "$pid" -o comm=,rss=,%cpu= --no-headers 2>/dev/null \
      | awk '{printf "%s (pid '$pid', mem %.0fMB, cpu %s%%)", $1, $2/1024, $3}'
  fi
}

# brew_service_status <name>  → "started" / "stopped" / "error" / ""
brew_service_status() {
  command -v brew >/dev/null 2>&1 \
    && brew services list 2>/dev/null | awk -v svc="$1" '$1==svc {print $2}' || echo ""
}

# systemd_status <name>  → "active" / "inactive" / ""
systemd_status() {
  command -v systemctl >/dev/null 2>&1 \
    && systemctl is-active "$1" 2>/dev/null || echo ""
}

# ── 打印行 ────────────────────────────────────────────────────────────────────
# print_service <display_name> <ports_csv> <manager> <pid_or_pids> <extra_info>
print_service() {
  local display_name="$1"
  local ports_csv="$2"        # "3306" or "9876,18080"
  local manager="$3"          # "brew" / "systemd" / "manual" / "optional"
  local pid="$4"              # pid string, may be empty
  local extra="$5"            # e.g. version string or URL

  # 把 ports_csv 转成数组检查
  local all_up=true any_up=false
  IFS=',' read -ra PORT_LIST <<< "$ports_csv"
  for p in "${PORT_LIST[@]}"; do
    if port_listening "$p"; then any_up=true; else all_up=false; fi
  done

  local status_icon status_label
  if [[ "$all_up" == true ]]; then
    status_icon="${GREEN}●${NC}"
    status_label="${GREEN}运行中${NC}"
  elif [[ "$any_up" == true ]]; then
    status_icon="${YELLOW}●${NC}"
    status_label="${YELLOW}部分运行${NC}"
  else
    status_icon="${RED}●${NC}"
    status_label="${RED}已停止${NC}"
  fi

  # 端口显示
  local port_str=""
  for p in "${PORT_LIST[@]}"; do
    if port_listening "$p"; then
      port_str+="${GREEN}$p✓${NC} "
    else
      port_str+="${RED}$p✗${NC} "
    fi
  done

  # 管理方式标签
  local mgr_label
  case "$manager" in
    brew)     mgr_label="${CYAN}[brew]${NC}"     ;;
    systemd)  mgr_label="${CYAN}[systemd]${NC}"  ;;
    manual)   mgr_label="${GRAY}[manual]${NC}"   ;;
    optional) mgr_label="${GRAY}[optional]${NC}" ;;
    *)        mgr_label="${GRAY}[$manager]${NC}" ;;
  esac

  printf "  %b %-20s %b  port: %b  %b\n" \
    "$status_icon" "$display_name" "$status_label" "$port_str" "$mgr_label"

  # 详细信息
  if [[ -n "$pid" ]] && pid_alive "$pid"; then
    local proc_info
    proc_info=$(process_info "$pid")
    printf "     ${GRAY}└─ %s${NC}\n" "$proc_info"
  elif [[ "$any_up" == true ]] && [[ -z "$pid" ]]; then
    # 找端口上的 pid 做展示
    local first_port="${PORT_LIST[0]}"
    local found_pid
    found_pid=$(pids_on_port "$first_port" | awk '{print $1}')
    if [[ -n "$found_pid" ]]; then
      local proc_info
      proc_info=$(process_info "$found_pid")
      printf "     ${GRAY}└─ %s${NC}\n" "$proc_info"
    fi
  fi

  if [[ -n "$extra" ]]; then
    printf "     ${GRAY}└─ %s${NC}\n" "$extra"
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║       deps-status.sh — 中间件运行状态            ║"
echo "╚══════════════════════════════════════════════════╝${NC}"
echo -e "${GRAY}  检查时间：$(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
echo -e "  ${BOLD}服务名                状态      端口              管理方式${NC}"
echo    "  ──────────────────────────────────────────────────────────────"

# ── MySQL ─────────────────────────────────────────────────────────────────────
MYSQL_BREW=$(brew_service_status mysql)
MYSQL_SYSTEMD=$(systemd_status mysql)
if [[ "$MYSQL_BREW" == "started" ]]; then
  MYSQL_MGR="brew"
elif [[ "$MYSQL_SYSTEMD" == "active" ]]; then
  MYSQL_MGR="systemd"
else
  MYSQL_MGR="manual"
fi
MYSQL_VER=""
if port_listening 3306; then
  MYSQL_VER=$(mysql -u root --connect-timeout=2 -e "SELECT VERSION();" 2>/dev/null \
    | grep -v VERSION | tr -d '[:space:]' || echo "")
  [[ -n "$MYSQL_VER" ]] && MYSQL_VER="version: $MYSQL_VER"
fi
print_service "MySQL" "3306" "$MYSQL_MGR" "" "$MYSQL_VER"

# ── Redis ─────────────────────────────────────────────────────────────────────
REDIS_BREW=$(brew_service_status redis)
REDIS_SYSTEMD=$(systemd_status redis-server)
if [[ "$REDIS_BREW" == "started" ]]; then
  REDIS_MGR="brew"
elif [[ "$REDIS_SYSTEMD" == "active" ]]; then
  REDIS_MGR="systemd"
else
  REDIS_MGR="manual"
fi
REDIS_VER=""
if port_listening 6379; then
  REDIS_VER=$(redis-cli --no-auth-warning INFO server 2>/dev/null \
    | grep redis_version | cut -d: -f2 | tr -d '[:space:]' || echo "")
  [[ -n "$REDIS_VER" ]] && REDIS_VER="version: $REDIS_VER"
fi
print_service "Redis" "6379" "$REDIS_MGR" "" "$REDIS_VER"

# ── Elasticsearch ─────────────────────────────────────────────────────────────
ES_PID=$(pid_from_file "$ES_HOME/elasticsearch.pid")
ES_VER=""
ES_HEALTH=""
if port_listening 9200; then
  ES_JSON=$(curl -s --connect-timeout 3 "http://localhost:9200" 2>/dev/null || echo "{}")
  ES_VER=$(echo "$ES_JSON" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('version',{}).get('number',''))" 2>/dev/null || echo "")
  ES_STATUS=$(curl -s --connect-timeout 3 "http://localhost:9200/_cluster/health" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
  [[ -n "$ES_VER" ]] && ES_HEALTH="version: $ES_VER, cluster: ${ES_STATUS:-unknown}"
fi
print_service "Elasticsearch" "9200" "manual" "$ES_PID" "$ES_HEALTH"

# ── RocketMQ NameServer ───────────────────────────────────────────────────────
RMQ_NS_PID=$(pid_from_file "$RMQ_HOME/namesrv.pid")
print_service "RocketMQ NameServer" "9876" "manual" "$RMQ_NS_PID" ""

# ── RocketMQ Broker+Proxy ─────────────────────────────────────────────────────
RMQ_BR_PID=$(pid_from_file "$RMQ_HOME/broker.pid")
print_service "RocketMQ Proxy" "18080" "manual" "$RMQ_BR_PID" ""

# ── Nacos ─────────────────────────────────────────────────────────────────────
NACOS_HEALTH=""
if port_listening 8848; then
  NACOS_LIVENESS=$(curl -s --connect-timeout 3 \
    "http://localhost:8848/nacos/v1/console/health/liveness" 2>/dev/null || echo "")
  NACOS_HEALTH="liveness: ${NACOS_LIVENESS:-unknown}  console: http://localhost:8848/nacos"
fi
# Nacos 自己管理进程，pid 通过 shutdown.sh 确认
NACOS_PID=""
if [[ -d "$NACOS_HOME/logs" ]]; then
  NACOS_PID=$(pids_on_port 8848 | awk '{print $1}')
fi
print_service "Nacos" "8848" "manual" "$NACOS_PID" "$NACOS_HEALTH"

# ── LoongCollector（可选）────────────────────────────────────────────────────
LC_PID=$(pid_from_file "$LC_HOME/loongcollector.pid")
if [[ -f "$LC_HOME/loongcollector" || -f "$LC_HOME/bin/loongcollector" ]]; then
  print_service "LoongCollector" "4318" "optional" "$LC_PID" "OTLP HTTP → ES loongsuite_traces"
else
  printf "  ${GRAY}—${NC} %-20s ${GRAY}未安装${NC}   port: ${GRAY}4318${NC}  ${GRAY}[optional]${NC}\n" "LoongCollector"
fi

# ── 分隔 ──────────────────────────────────────────────────────────────────────
echo    "  ──────────────────────────────────────────────────────────────"

# ── AI 模型 API ───────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_CONFIG="$SCRIPT_DIR/../spring-ai-alibaba-admin-server-start/model-config.yaml"
if [[ -f "$MODEL_CONFIG" ]]; then
  MODEL_PROVIDER=$(grep -E '^\s*(type|provider)\s*:' "$MODEL_CONFIG" 2>/dev/null \
    | head -1 | awk -F: '{print $2}' | tr -d ' ' || echo "已配置")
  printf "  ${GREEN}●${NC} %-20s ${GREEN}已配置${NC}   provider: ${GRAY}%s${NC}\n" \
    "AI Model API" "${MODEL_PROVIDER:-已配置}"
else
  printf "  ${YELLOW}●${NC} %-20s ${YELLOW}待配置${NC}   ${GRAY}复制 model-config-*.yaml 为 model-config.yaml${NC}\n" \
    "AI Model API"
fi

# ── 端口监听总览 ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}── 端口监听明细 ──${NC}"
echo -e "${GRAY}  (通过 lsof/ss 查询实际监听状态)${NC}"
echo ""

for port in 3306 6379 9200 9876 18080 18081 8848 4318; do
  if port_listening "$port"; then
    if [[ "$OS" == "Darwin" ]]; then
      PROC=$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null \
        | awk 'NR>1 {print $1, $2}' | head -1)
    else
      PROC=$(ss -tlnp "sport = :$port" 2>/dev/null \
        | awk 'NR>1 {match($0, /\"([^\"]+)\"/, a); match($0, /pid=([0-9]+)/, b); printf "%s %s", a[1], b[1]}' \
        | head -1)
    fi
    printf "  ${GREEN}✓${NC}  :%d  ${GRAY}%s${NC}\n" "$port" "${PROC:-unknown process}"
  else
    printf "  ${RED}✗${NC}  :%d  ${GRAY}not listening${NC}\n" "$port"
  fi
done

# ── Java 环境信息 ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}── Java 环境 ──${NC}"
JAVA_INFO=$(java -version 2>&1 | head -1 || echo "未找到")
printf "  ${GRAY}%s${NC}\n" "$JAVA_INFO"
JAVA_VER=$(java -version 2>&1 | grep -oE '"[0-9]+' | head -1 | tr -d '"' || echo "0")
if [[ "$JAVA_VER" -ge 17 ]]; then
  printf "  ${GREEN}✓${NC} Java $JAVA_VER 满足 ≥17 要求\n"
else
  printf "  ${RED}✗${NC} Java $JAVA_VER 不满足 ≥17 要求\n"
fi

echo ""
