#!/usr/bin/env bash
# 一键停止所有依赖中间件
# 用法: scripts/deps-stop.sh [--skip <name,...>]

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_DIR="$ROOT_DIR/.local/deps"

# 加载本地敏感配置
[ -f "$ROOT_DIR/scripts/install-deps.local.env" ] && source "$ROOT_DIR/scripts/install-deps.local.env"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 跳过列表
SKIP_LIST=""
if [ "${1:-}" = "--skip" ] && [ -n "${2:-}" ]; then
  SKIP_LIST="$2"
fi

should_skip() {
  local name="$1"
  echo "$SKIP_LIST" | tr ',' '\n' | grep -qx "$name"
}

log_ok()   { echo -e "  ${GREEN}[OK]${NC} $*"; }
log_fail() { echo -e "  ${RED}[FAIL]${NC} $*"; }
log_skip() { echo -e "  ${YELLOW}[SKIP]${NC} $*"; }
log_stop() { echo -e "  ${YELLOW}[...]${NC} $*"; }

have() { command -v "$1" >/dev/null 2>&1; }

stop_launchctl() {
  local name="$1"
  local label="com.spring-ai-alibaba-admin.${name}"
  local plist="$HOME/Library/LaunchAgents/${label}.plist"
  local domain="gui/$(id -u)"

  if launchctl print "$domain/$label" >/dev/null 2>&1; then
    launchctl bootout "$domain" "$plist" >/dev/null 2>&1
  fi
}

echo "========================================="
echo "  Spring AI Alibaba Admin - 停止依赖中间件"
echo "========================================="
echo ""

STOPPED=""
SKIPPED=""

# -------------------------------------------------------
# LoongCollector（先停容器，避免日志涌入 ES）
# -------------------------------------------------------
echo "[1/7] LoongCollector"
if should_skip loongcollector; then
  log_skip "loongcollector"
  SKIPPED="$SKIPPED loongcollector"
else
  if docker ps --filter name=loongcollector --format '{{.Names}}' 2>/dev/null | grep -q loongcollector; then
    log_stop "停止 LoongCollector 容器..."
    docker stop loongcollector >/dev/null 2>&1
    log_ok "LoongCollector 已停止"
    STOPPED="$STOPPED loongcollector"
  else
    log_ok "LoongCollector 未在运行"
    STOPPED="$STOPPED loongcollector"
  fi
fi

# -------------------------------------------------------
# RocketMQ（先停 Proxy → Broker → NameServer）
# -------------------------------------------------------
echo "[2/7] RocketMQ"
if should_skip rocketmq; then
  log_skip "rocketmq"
  SKIPPED="$SKIPPED rocketmq"
else
  log_stop "停止 RocketMQ..."
  if [ "$(uname -s)" = "Darwin" ]; then
    stop_launchctl rocketmq.proxy
    stop_launchctl rocketmq.broker
    stop_launchctl rocketmq.namesrv
  elif have systemctl; then
    sudo systemctl stop rocketmq-proxy 2>/dev/null
    sudo systemctl stop rocketmq-broker 2>/dev/null
    sudo systemctl stop rocketmq-namesrv 2>/dev/null
  elif [ -x "${DEPS_DIR:-}/rocketmq-all-5.3.2-bin-release/bin/mqshutdown" ]; then
    "$DEPS_DIR/rocketmq-all-5.3.2-bin-release/bin/mqshutdown" broker >/dev/null 2>&1
    "$DEPS_DIR/rocketmq-all-5.3.2-bin-release/bin/mqshutdown" namesrv >/dev/null 2>&1
  fi
  log_ok "RocketMQ 已停止"
  STOPPED="$STOPPED rocketmq"
fi

# -------------------------------------------------------
# Nacos
# -------------------------------------------------------
echo "[3/7] Nacos"
if should_skip nacos; then
  log_skip "nacos"
  SKIPPED="$SKIPPED nacos"
else
  log_stop "停止 Nacos..."
  if [ "$(uname -s)" = "Darwin" ]; then
    stop_launchctl nacos
  elif have systemctl; then
    sudo systemctl stop nacos 2>/dev/null
  else
    # 尝试 kill PID
    nacos_pid="$(pgrep -f 'nacos-server.jar' 2>/dev/null | head -1)"
    if [ -n "$nacos_pid" ]; then
      kill "$nacos_pid" 2>/dev/null
    fi
  fi
  log_ok "Nacos 已停止"
  STOPPED="$STOPPED nacos"
fi

# -------------------------------------------------------
# Kibana
# -------------------------------------------------------
echo "[4/7] Kibana"
if should_skip kibana; then
  log_skip "kibana"
  SKIPPED="$SKIPPED kibana"
else
  log_stop "停止 Kibana..."
  if [ "$(uname -s)" = "Darwin" ]; then
    stop_launchctl kibana
  elif have systemctl; then
    sudo systemctl stop kibana 2>/dev/null
  fi
  log_ok "Kibana 已停止"
  STOPPED="$STOPPED kibana"
fi

# -------------------------------------------------------
# Elasticsearch
# -------------------------------------------------------
echo "[5/7] Elasticsearch"
if should_skip elasticsearch; then
  log_skip "elasticsearch"
  SKIPPED="$SKIPPED elasticsearch"
else
  log_stop "停止 Elasticsearch..."
  if [ "$(uname -s)" = "Darwin" ]; then
    stop_launchctl elasticsearch
  elif have systemctl; then
    sudo systemctl stop elasticsearch 2>/dev/null
  elif [ -x "${DEPS_DIR:-}/elasticsearch-9.1.2/bin/elasticsearch" ]; then
    es_pid="$(pgrep -f 'elasticsearch' 2>/dev/null | head -1)"
    if [ -n "$es_pid" ]; then
      kill "$es_pid" 2>/dev/null
    fi
  fi
  log_ok "Elasticsearch 已停止"
  STOPPED="$STOPPED elasticsearch"
fi

# -------------------------------------------------------
# Redis
# -------------------------------------------------------
echo "[6/7] Redis"
if should_skip redis; then
  log_skip "redis"
  SKIPPED="$SKIPPED redis"
else
  log_stop "停止 Redis..."
  if [ "$(uname -s)" = "Darwin" ] && have brew; then
    brew services stop redis >/dev/null 2>&1
  elif have systemctl; then
    sudo systemctl stop redis-server 2>/dev/null || sudo systemctl stop redis 2>/dev/null
  elif have service; then
    sudo service redis-server stop 2>/dev/null
  else
    redis-cli shutdown 2>/dev/null
  fi
  log_ok "Redis 已停止"
  STOPPED="$STOPPED redis"
fi

# -------------------------------------------------------
# MySQL
# -------------------------------------------------------
echo "[7/7] MySQL"
if should_skip mysql; then
  log_skip "mysql"
  SKIPPED="$SKIPPED mysql"
else
  log_stop "停止 MySQL..."
  if [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
    mysqladmin -uroot -p"$MYSQL_ROOT_PASSWORD" shutdown 2>/dev/null
  elif have mysql.server; then
    mysql.server stop >/dev/null 2>&1
  elif [ "$(uname -s)" = "Darwin" ] && have brew; then
    brew services stop mysql 2>/dev/null || brew services stop mysql@8.0 >/dev/null 2>&1
  elif have systemctl; then
    sudo systemctl stop mysql 2>/dev/null || sudo systemctl stop mysqld 2>/dev/null
  elif have service; then
    sudo service mysql stop 2>/dev/null
  fi
  log_ok "MySQL 已停止"
  STOPPED="$STOPPED mysql"
fi

# -------------------------------------------------------
# 汇总
# -------------------------------------------------------
echo ""
echo "========================================="
echo "  停止结果"
echo "========================================="
if [ -n "$STOPPED" ]; then
  for s in $STOPPED; do echo -e "  ${GREEN}STOPPED${NC} $s"; done
fi
if [ -n "$SKIPPED" ]; then
  for s in $SKIPPED; do echo -e "  ${YELLOW}SKIP${NC}   $s"; done
fi
echo ""
echo "  所有服务已停止。"
