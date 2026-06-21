#!/usr/bin/env bash
# 一键启动所有依赖中间件
# 用法: scripts/deps-start.sh [--skip <name,...>]
#   --skip  跳过指定服务，逗号分隔，如 --skip kibana,loongcollector

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_DIR="$ROOT_DIR/.local/deps"
RUN_DIR="$ROOT_DIR/.local/run"
LOG_DIR="$RUN_DIR"

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

have() { command -v "$1" >/dev/null 2>&1; }

log_ok()   { echo -e "  ${GREEN}[OK]${NC} $*"; }
log_fail() { echo -e "  ${RED}[FAIL]${NC} $*"; }
log_wait() { echo -e "  ${YELLOW}[...]${NC} $*"; }
log_skip() { echo -e "  ${YELLOW}[SKIP]${NC} $*"; }

wait_tcp() {
  local name="$1" host="$2" port="$3" max_wait="${4:-60}"
  local elapsed=0
  while [ "$elapsed" -lt "$max_wait" ]; do
    if nc -z "$host" "$port" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

wait_http() {
  local name="$1" url="$2" max_wait="${3:-90}"
  local elapsed=0
  while [ "$elapsed" -lt "$max_wait" ]; do
    if curl -fsS -m 3 "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  return 1
}

start_launchctl() {
  local name="$1"
  local label="com.spring-ai-alibaba-admin.${name}"
  local plist="$HOME/Library/LaunchAgents/${label}.plist"
  local domain="gui/$(id -u)"

  if [ ! -f "$plist" ]; then
    log_fail "$name: plist 不存在 $plist"
    return 1
  fi

  # 已注册且运行中
  if launchctl print "$domain/$label" >/dev/null 2>&1; then
    local pid
    pid="$(launchctl print "$domain/$label" 2>/dev/null | grep 'pid' | head -1 | awk '{print $NF}')"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      return 0  # 已在运行，不算失败
    fi
  fi

  launchctl bootout "$domain" "$plist" >/dev/null 2>&1 || true
  launchctl bootstrap "$domain" "$plist" >/dev/null 2>&1
  launchctl kickstart -k "$domain/$label" >/dev/null 2>&1
}

restart_launchctl() {
  local name="$1"
  local label="com.spring-ai-alibaba-admin.${name}"
  local plist="$HOME/Library/LaunchAgents/${label}.plist"
  local domain="gui/$(id -u)"

  if [ ! -f "$plist" ]; then
    log_fail "$name: plist 不存在 $plist"
    return 1
  fi

  launchctl bootout "$domain" "$plist" >/dev/null 2>&1 || true
  launchctl bootstrap "$domain" "$plist" >/dev/null 2>&1
  launchctl kickstart -k "$domain/$label" >/dev/null 2>&1
}

ensure_rocketmq_broker_config() {
  local config="$RUN_DIR/rmq-broker.conf"

  if [ -f "$config" ] && grep -q 'brokerIP1[[:space:]]*=[[:space:]]*127\.0\.0\.1' "$config"; then
    :
  else
    mkdir -p "$RUN_DIR"
    cat > "$config" <<EOF
brokerClusterName = DefaultCluster
brokerName = broker-a
brokerId = 0
deleteWhen = 04
fileReservedTime = 48
brokerRole = ASYNC_MASTER
flushDiskType = ASYNC_FLUSH
enableProxyInBroker = true
grpcServerPort = 10912
brokerIP1 = 127.0.0.1
EOF
  fi

  local broker_script="$RUN_DIR/start-rocketmq-broker.sh"
  if [ -f "$broker_script" ] && ! grep -q 'rmq-broker\.conf' "$broker_script"; then
    local mq_home="${DEPS_DIR}/rocketmq-all-5.3.2-bin-release"
    cat > "$broker_script" <<EOF
#!/usr/bin/env bash
export JAVA_HOME="\${JAVA_HOME:-/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home}"
export PATH="\$JAVA_HOME/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export NAMESRV_ADDR="localhost:9876"
export HEAP_OPTS="-Xms256M -Xmx512M -Xmn256M -XX:MaxDirectMemorySize=128M"
until nc -z localhost 9876 >/dev/null 2>&1; do sleep 2; done
cd "$mq_home"
exec sh "$mq_home/bin/mqbroker" -n localhost:9876 -c "$config"
EOF
    chmod +x "$broker_script"
  fi
}

rocketmq_broker_route_local() {
  local mq_home="${DEPS_DIR}/rocketmq-all-5.3.2-bin-release"
  [ -x "$mq_home/bin/mqadmin" ] || return 0
  local elapsed=0
  while [ "$elapsed" -lt 60 ]; do
    if sh "$mq_home/bin/mqadmin" clusterList -n localhost:9876 2>/dev/null | grep -q '127\.0\.0\.1:10911'; then
      return 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  return 1
}

ensure_rocketmq_proxy_config() {
  local config="$RUN_DIR/rmq-proxy.json"

  if [ -f "$config" ] \
    && grep -q '"proxyMode"[[:space:]]*:[[:space:]]*"CLUSTER"' "$config" \
    && grep -q '"namesrvAddr"[[:space:]]*:[[:space:]]*"localhost:9876"' "$config"; then
    return 0
  fi

  mkdir -p "$RUN_DIR"
  cat > "$config" <<EOF
{
  "rocketMQClusterName": "DefaultCluster",
  "remotingListenPort": 18080,
  "grpcServerPort": 18081,
  "proxyMode": "CLUSTER",
  "namesrvAddr": "localhost:9876"
}
EOF
}

ensure_rocketmq_topic() {
  local mq_home="${DEPS_DIR}/rocketmq-all-5.3.2-bin-release"
  [ -x "$mq_home/bin/mqadmin" ] || return 0

  export NAMESRV_ADDR=localhost:9876
  sh "$mq_home/bin/mqadmin" updateTopic -n localhost:9876 -t topic_saa_studio_document_index -c DefaultCluster -a +message.type=NORMAL >/dev/null 2>&1
  local topic_rc=$?
  sh "$mq_home/bin/mqadmin" updateSubGroup -n localhost:9876 -g group_saa_studio_document_index -c DefaultCluster >/dev/null 2>&1
  local group_rc=$?

  if [ "$topic_rc" -eq 0 ] && [ "$group_rc" -eq 0 ]; then
    log_ok "RocketMQ topic/group 已校验"
    return 0
  fi

  log_fail "RocketMQ topic/group 校验失败"
  return 1
}

echo "========================================="
echo "  Spring AI Alibaba Admin - 启动依赖中间件"
echo "========================================="
echo ""

FAILED=""
STARTED=""
SKIPPED=""

# -------------------------------------------------------
# MySQL
# -------------------------------------------------------
echo "[1/7] MySQL"
if should_skip mysql; then
  log_skip "mysql"
  SKIPPED="$SKIPPED mysql"
else
  if mysqladmin ping -uadmin -padmin --silent >/dev/null 2>&1; then
    log_ok "MySQL 已在运行"
    STARTED="$STARTED mysql"
  else
    log_wait "启动 MySQL..."
    if [ "$(uname -s)" = "Darwin" ] && [ -f /Library/LaunchDaemons/com.oracle.oss.mysql.mysqld.plist ]; then
      sudo launchctl kickstart -k system/com.oracle.oss.mysql.mysqld 2>/dev/null
    elif [ -x /usr/local/mysql/support-files/mysql.server ]; then
      sudo /usr/local/mysql/support-files/mysql.server start >/dev/null 2>&1
    elif have mysql.server; then
      mysql.server start >/dev/null 2>&1
    elif [ "$(uname -s)" = "Darwin" ] && have brew; then
      brew services start mysql >/dev/null 2>&1 || brew services start mysql@8.0 >/dev/null 2>&1
    elif have systemctl; then
      sudo systemctl start mysql >/dev/null 2>&1 || sudo systemctl start mysqld >/dev/null 2>&1
    elif have service; then
      sudo service mysql start >/dev/null 2>&1
    fi

    if wait_tcp MySQL localhost 3306 30; then
      log_ok "MySQL 已就绪 (3306)"
      STARTED="$STARTED mysql"
    else
      log_fail "MySQL 启动超时"
      FAILED="$FAILED mysql"
    fi
  fi
fi

# -------------------------------------------------------
# Redis
# -------------------------------------------------------
echo "[2/7] Redis"
if should_skip redis; then
  log_skip "redis"
  SKIPPED="$SKIPPED redis"
else
  if redis-cli ping >/dev/null 2>&1; then
    log_ok "Redis 已在运行"
    STARTED="$STARTED redis"
  else
    log_wait "启动 Redis..."
    if [ "$(uname -s)" = "Darwin" ] && have brew; then
      brew services start redis >/dev/null 2>&1
    elif have systemctl; then
      sudo systemctl start redis-server >/dev/null 2>&1 || sudo systemctl start redis >/dev/null 2>&1
    elif have service; then
      sudo service redis-server start >/dev/null 2>&1
    else
      nohup redis-server --daemonize yes >/dev/null 2>&1
    fi

    if wait_tcp Redis localhost 6379 15; then
      log_ok "Redis 已就绪 (6379)"
      STARTED="$STARTED redis"
    else
      log_fail "Redis 启动超时"
      FAILED="$FAILED redis"
    fi
  fi
fi

# -------------------------------------------------------
# Elasticsearch
# -------------------------------------------------------
echo "[3/7] Elasticsearch"
if should_skip elasticsearch; then
  log_skip "elasticsearch"
  SKIPPED="$SKIPPED elasticsearch"
else
  if curl -fsS -m 3 http://localhost:9200/_cluster/health >/dev/null 2>&1; then
    log_ok "Elasticsearch 已在运行"
    STARTED="$STARTED elasticsearch"
  else
    log_wait "启动 Elasticsearch..."
    if [ "$(uname -s)" = "Darwin" ]; then
      start_launchctl elasticsearch
    elif have systemctl; then
      sudo systemctl start elasticsearch >/dev/null 2>&1
    elif [ -x "$DEPS_DIR/elasticsearch-9.1.2/bin/elasticsearch" ]; then
      ES_JAVA_OPTS="-Xms1g -Xmx1g" nohup "$DEPS_DIR/elasticsearch-9.1.2/bin/elasticsearch" \
        -p "$RUN_DIR/elasticsearch.pid" >> "$LOG_DIR/elasticsearch.log" 2>&1 &
    fi

    if wait_http Elasticsearch http://localhost:9200/_cluster/health 120; then
      log_ok "Elasticsearch 已就绪 (9200)"
      STARTED="$STARTED elasticsearch"
    else
      log_fail "Elasticsearch 启动超时"
      FAILED="$FAILED elasticsearch"
    fi
  fi
fi

# -------------------------------------------------------
# Kibana
# -------------------------------------------------------
echo "[4/7] Kibana"
if should_skip kibana; then
  log_skip "kibana"
  SKIPPED="$SKIPPED kibana"
else
  if curl -fsS -m 3 http://localhost:5601/api/status >/dev/null 2>&1; then
    log_ok "Kibana 已在运行"
    STARTED="$STARTED kibana"
  else
    log_wait "启动 Kibana..."
    if [ "$(uname -s)" = "Darwin" ]; then
      start_launchctl kibana
    elif have systemctl; then
      sudo systemctl start kibana >/dev/null 2>&1
    elif [ -x "$DEPS_DIR/kibana-9.1.2/bin/kibana" ]; then
      nohup "$DEPS_DIR/kibana-9.1.2/bin/kibana" >> "$LOG_DIR/kibana.log" 2>&1 &
      echo $! > "$RUN_DIR/kibana.pid"
    fi

    if wait_http Kibana http://localhost:5601/api/status 180; then
      log_ok "Kibana 已就绪 (5601)"
      STARTED="$STARTED kibana"
    else
      log_fail "Kibana 启动超时（首次启动可能需要 2-3 分钟，可用 deps-status.sh 检查）"
      FAILED="$FAILED kibana"
    fi
  fi
fi

# -------------------------------------------------------
# Nacos
# -------------------------------------------------------
echo "[5/7] Nacos"
if should_skip nacos; then
  log_skip "nacos"
  SKIPPED="$SKIPPED nacos"
else
  if curl -fsS -m 3 http://localhost:8848/nacos/ >/dev/null 2>&1; then
    log_ok "Nacos 已在运行"
    STARTED="$STARTED nacos"
  else
    log_wait "启动 Nacos..."
    if [ "$(uname -s)" = "Darwin" ]; then
      start_launchctl nacos
    elif have systemctl; then
      sudo systemctl start nacos >/dev/null 2>&1
    elif [ -x "$DEPS_DIR/nacos/bin/startup.sh" ]; then
      (cd "$DEPS_DIR/nacos" && sh bin/startup.sh -m standalone) >> "$LOG_DIR/nacos.log" 2>&1
    fi

    if wait_http Nacos http://localhost:8848/nacos/ 90; then
      log_ok "Nacos 已就绪 (8848)"
      STARTED="$STARTED nacos"
    else
      log_fail "Nacos 启动超时"
      FAILED="$FAILED nacos"
    fi
  fi
fi

# -------------------------------------------------------
# RocketMQ
# -------------------------------------------------------
echo "[6/7] RocketMQ"
if should_skip rocketmq; then
  log_skip "rocketmq"
  SKIPPED="$SKIPPED rocketmq"
else
  mq_ok=true
  ensure_rocketmq_broker_config

  # NameServer
  if nc -z localhost 9876 >/dev/null 2>&1; then
    log_ok "RocketMQ NameServer 已在运行"
  else
    log_wait "启动 RocketMQ NameServer..."
    if [ "$(uname -s)" = "Darwin" ]; then
      start_launchctl rocketmq.namesrv
    elif [ -x "${DEPS_DIR:-}/rocketmq-all-5.3.2-bin-release/bin/mqnamesrv" ]; then
      export NAMESRV_ADDR=localhost:9876
      nohup sh "${DEPS_DIR}/rocketmq-all-5.3.2-bin-release/bin/mqnamesrv" >> "$LOG_DIR/rocketmq-namesrv.log" 2>&1 &
    fi
    if wait_tcp "RocketMQ NameServer" localhost 9876 60; then
      log_ok "NameServer 已就绪 (9876)"
    else
      log_fail "NameServer 启动超时"
      mq_ok=false
    fi
  fi

  # Broker
  if nc -z localhost 10911 >/dev/null 2>&1; then
    if rocketmq_broker_route_local; then
      log_ok "RocketMQ Broker 已在运行"
    else
      log_wait "RocketMQ Broker 广播地址不是本地地址，重启 Broker/Proxy..."
      if [ "$(uname -s)" = "Darwin" ]; then
        restart_launchctl rocketmq.proxy >/dev/null 2>&1 || true
        launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.spring-ai-alibaba-admin.rocketmq.proxy.plist" >/dev/null 2>&1 || true
        restart_launchctl rocketmq.broker
      else
        pkill -f 'mqbroker' >/dev/null 2>&1 || true
        export NAMESRV_ADDR=localhost:9876
        export HEAP_OPTS="-Xms256M -Xmx512M -Xmn256M -XX:MaxDirectMemorySize=128M"
        nohup sh "${DEPS_DIR}/rocketmq-all-5.3.2-bin-release/bin/mqbroker" -n localhost:9876 -c "$RUN_DIR/rmq-broker.conf" >> "$LOG_DIR/rocketmq-broker.log" 2>&1 &
      fi
      if wait_tcp "RocketMQ Broker" localhost 10911 90 && rocketmq_broker_route_local; then
        log_ok "Broker 已以本地地址就绪 (10911)"
      else
        log_fail "Broker 本地路由修复失败"
        mq_ok=false
      fi
    fi
  else
    log_wait "启动 RocketMQ Broker..."
    if [ "$(uname -s)" = "Darwin" ]; then
      start_launchctl rocketmq.broker
    elif [ -x "${DEPS_DIR:-}/rocketmq-all-5.3.2-bin-release/bin/mqbroker" ]; then
      export NAMESRV_ADDR=localhost:9876
      export HEAP_OPTS="-Xms256M -Xmx512M -Xmn256M -XX:MaxDirectMemorySize=128M"
      nohup sh "${DEPS_DIR}/rocketmq-all-5.3.2-bin-release/bin/mqbroker" -n localhost:9876 -c "$RUN_DIR/rmq-broker.conf" >> "$LOG_DIR/rocketmq-broker.log" 2>&1 &
    fi
    if wait_tcp "RocketMQ Broker" localhost 10911 90 && rocketmq_broker_route_local; then
      log_ok "Broker 已就绪 (10911)"
    else
      log_fail "Broker 启动超时"
      mq_ok=false
    fi
  fi

  # Proxy
  ensure_rocketmq_proxy_config
  if nc -z localhost 18080 >/dev/null 2>&1; then
    log_ok "RocketMQ Proxy 已在运行"
  else
    log_wait "启动 RocketMQ Proxy..."
    if [ "$(uname -s)" = "Darwin" ]; then
      start_launchctl rocketmq.proxy
    fi
    if wait_tcp "RocketMQ Proxy" localhost 18080 90; then
      log_ok "Proxy 已就绪 (18080)"
    else
      log_fail "Proxy 启动超时"
      mq_ok=false
    fi
  fi

  if $mq_ok; then
    ensure_rocketmq_topic || mq_ok=false
  fi

  if $mq_ok; then
    STARTED="$STARTED rocketmq"
  else
    FAILED="$FAILED rocketmq"
  fi
fi

# -------------------------------------------------------
# LoongCollector
# -------------------------------------------------------
echo "[7/7] LoongCollector"
if should_skip loongcollector; then
  log_skip "loongcollector"
  SKIPPED="$SKIPPED loongcollector"
else
  if docker ps --filter name=loongcollector --format '{{.Names}}' 2>/dev/null | grep -q loongcollector; then
    log_ok "LoongCollector 容器已在运行"
    STARTED="$STARTED loongcollector"
  else
    log_wait "启动 LoongCollector 容器..."
    docker start loongcollector >/dev/null 2>&1 2>&1

    # 等待 OTLP 端口就绪
    lc_ok=false
    for _ in $(seq 1 15); do
      if nc -z localhost 4318 >/dev/null 2>&1; then
        lc_ok=true
        break
      fi
      sleep 2
    done

    if $lc_ok; then
      log_ok "LoongCollector 已就绪 (4318)"
      STARTED="$STARTED loongcollector"
    else
      log_fail "LoongCollector 启动超时"
      FAILED="$FAILED loongcollector"
    fi
  fi
fi

# -------------------------------------------------------
# 汇总
# -------------------------------------------------------
echo ""
echo "========================================="
echo "  启动结果"
echo "========================================="
if [ -n "$STARTED" ]; then
  for s in $STARTED; do echo -e "  ${GREEN}OK${NC}   $s"; done
fi
if [ -n "$SKIPPED" ]; then
  for s in $SKIPPED; do echo -e "  ${YELLOW}SKIP${NC} $s"; done
fi
if [ -n "$FAILED" ]; then
  for s in $FAILED; do echo -e "  ${RED}FAIL${NC} $s"; done
  echo ""
  echo "  部分服务启动失败，可用 scripts/deps-status.sh 查看详情。"
  exit 1
fi

echo ""
echo "  所有服务已就绪。"
