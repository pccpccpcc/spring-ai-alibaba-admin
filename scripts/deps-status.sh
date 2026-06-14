#!/usr/bin/env bash
# 查看每个中间件的运行状态和端口监听
# 用法: scripts/deps-status.sh

set -u

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

have() { command -v "$1" >/dev/null 2>&1; }

check_tcp() {
  local host="$1" port="$2"
  nc -z "$host" "$port" >/dev/null 2>&1
}

check_http() {
  local url="$1"
  curl -fsS -m 3 "$url" >/dev/null 2>&1
}

status_icon() {
  if [ "$1" = "true" ]; then
    echo -e "${GREEN}RUNNING${NC}"
  else
    echo -e "${RED}STOPPED${NC}"
  fi
}

port_icon() {
  if [ "$1" = "true" ]; then
    echo -e "${GREEN}LISTENING${NC}"
  else
    echo -e "${RED}CLOSED${NC}"
  fi
}

# 获取 LaunchAgent 服务 PID
launchctl_pid() {
  local label="com.spring-ai-alibaba-admin.$1"
  local domain="gui/$(id -u)"
  launchctl print "$domain/$label" 2>/dev/null | grep 'pid' | head -1 | awk '{print $NF}'
}

echo "========================================="
echo "  Spring AI Alibaba Admin - 中间件状态"
echo "========================================="
echo ""

printf "  %-16s %-10s %-12s %s\n" "SERVICE" "STATUS" "PORT" "DETAIL"
printf "  %-16s %-10s %-12s %s\n" "-------" "------" "----" "------"

# -------------------------------------------------------
# MySQL
# -------------------------------------------------------
mysql_running="false"
mysql_port="false"
mysql_detail=""
if check_tcp localhost 3306; then
  mysql_port="true"
  mysql_running="true"
  mysql_detail="localhost:3306"
  # 尝试获取版本
  if have mysql; then
    ver="$(mysql --version 2>/dev/null | awk '{print $5}' | tr -d ',')"
    mysql_detail="v${ver} @ localhost:3306"
  fi
else
  mysql_detail="localhost:3306 未监听"
fi
printf "  %-16s " "MySQL"
echo -e "$(status_icon $mysql_running)\t$(port_icon $mysql_port)\t $mysql_detail"

# -------------------------------------------------------
# Redis
# -------------------------------------------------------
redis_running="false"
redis_port="false"
redis_detail=""
if check_tcp localhost 6379; then
  redis_port="true"
  redis_running="true"
  pong="$(redis-cli ping 2>/dev/null)"
  redis_detail="localhost:6379 (${pong:-N/A})"
else
  redis_detail="localhost:6379 未监听"
fi
printf "  %-16s " "Redis"
echo -e "$(status_icon $redis_running)\t$(port_icon $redis_port)\t $redis_detail"

# -------------------------------------------------------
# Elasticsearch
# -------------------------------------------------------
es_running="false"
es_port="false"
es_detail=""
if check_http http://localhost:9200/_cluster/health; then
  es_running="true"
  es_port="true"
  health="$(curl -fsS -m 3 http://localhost:9200/_cluster/health 2>/dev/null)"
  status_val="$(echo "$health" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)"
  ver="$(curl -fsS -m 3 http://localhost:9200 2>/dev/null | grep -o '"number" : "[^"]*"' | head -1 | cut -d'"' -f4)"
  es_detail="v${ver:-?} status=${status_val:-?} @ localhost:9200"
else
  if check_tcp localhost 9200; then
    es_port="true"
    es_detail="localhost:9200 端口开放但 HTTP 未就绪"
  else
    es_detail="localhost:9200 未监听"
  fi
fi
printf "  %-16s " "Elasticsearch"
echo -e "$(status_icon $es_running)\t$(port_icon $es_port)\t $es_detail"

# -------------------------------------------------------
# Kibana
# -------------------------------------------------------
kb_running="false"
kb_port="false"
kb_detail=""
if check_http http://localhost:5601/api/status; then
  kb_running="true"
  kb_port="true"
  kb_detail="localhost:5601"
else
  if check_tcp localhost 5601; then
    kb_port="true"
    kb_detail="localhost:5601 端口开放但 HTTP 未就绪"
  else
    kb_detail="localhost:5601 未监听"
  fi
fi
printf "  %-16s " "Kibana"
echo -e "$(status_icon $kb_running)\t$(port_icon $kb_port)\t $kb_detail"

# -------------------------------------------------------
# Nacos
# -------------------------------------------------------
nacos_running="false"
nacos_port="false"
nacos_detail=""
if check_http http://localhost:8848/nacos/; then
  nacos_running="true"
  nacos_port="true"
  nacos_detail="localhost:8848"
else
  if check_tcp localhost 8848; then
    nacos_port="true"
    nacos_detail="localhost:8848 端口开放但 HTTP 未就绪"
  else
    nacos_detail="localhost:8848 未监听"
  fi
fi
printf "  %-16s " "Nacos"
echo -e "$(status_icon $nacos_running)\t$(port_icon $nacos_port)\t $nacos_detail"

# -------------------------------------------------------
# RocketMQ
# -------------------------------------------------------
ns_port="false"
br_port="false"
px_port="false"
ns_running="false"
br_running="false"
px_running="false"

if check_tcp localhost 9876; then
  ns_port="true"
  ns_running="true"
fi
if check_tcp localhost 10911; then
  br_port="true"
  br_running="true"
fi
if check_tcp localhost 18080; then
  px_port="true"
  px_running="true"
fi

mq_all_ok="false"
if $ns_running && $br_running && $px_running; then
  mq_all_ok="true"
fi

printf "  %-16s " "RocketMQ"
echo -e "$(status_icon $mq_all_ok)"
printf "    %-14s " "  NameServer"
echo -e "$(status_icon $ns_running)\t$(port_icon $ns_port)\t localhost:9876"
printf "    %-14s " "  Broker"
echo -e "$(status_icon $br_running)\t$(port_icon $br_port)\t localhost:10911"
printf "    %-14s " "  Proxy"
echo -e "$(status_icon $px_running)\t$(port_icon $px_port)\t localhost:18080"

# -------------------------------------------------------
# LoongCollector
# -------------------------------------------------------
lc_running="false"
lc_port="false"
lc_detail=""
if docker ps --filter name=loongcollector --format '{{.Names}}' 2>/dev/null | grep -q loongcollector; then
  lc_running="true"
  if check_tcp localhost 4318; then
    lc_port="true"
    lc_detail="容器运行中 @ localhost:4318"
  else
    lc_detail="容器运行中但 4318 端口未就绪"
  fi
else
  if check_tcp localhost 4318; then
    lc_port="true"
    lc_running="true"
    lc_detail="localhost:4318"
  else
    lc_detail="容器未运行"
  fi
fi
printf "  %-16s " "LoongCollector"
echo -e "$(status_icon $lc_running)\t$(port_icon $lc_port)\t $lc_detail"

echo ""
echo "========================================="

# -------------------------------------------------------
# macOS LaunchAgent 服务详情
# -------------------------------------------------------
if [ "$(uname -s)" = "Darwin" ]; then
  echo "  LaunchAgent 服务:"
  echo ""
  for svc in elasticsearch kibana nacos rocketmq.namesrv rocketmq.broker rocketmq.proxy; do
    label="com.spring-ai-alibaba-admin.${svc}"
    domain="gui/$(id -u)"
    pid="$(launchctl_pid "$svc")"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      printf "    %-30s %s\n" "$svc" "PID=$pid"
    else
      printf "    %-30s %s\n" "$svc" "未注册或未运行"
    fi
  done
  echo ""
fi

# 汇总
ok_count=0
fail_count=0
$mysql_running && ok_count=$((ok_count + 1)) || fail_count=$((fail_count + 1))
$redis_running && ok_count=$((ok_count + 1)) || fail_count=$((fail_count + 1))
$es_running   && ok_count=$((ok_count + 1)) || fail_count=$((fail_count + 1))
$kb_running   && ok_count=$((ok_count + 1)) || fail_count=$((fail_count + 1))
$nacos_running && ok_count=$((ok_count + 1)) || fail_count=$((fail_count + 1))
$mq_all_ok    && ok_count=$((ok_count + 1)) || fail_count=$((fail_count + 1))
$lc_running   && ok_count=$((ok_count + 1)) || fail_count=$((fail_count + 1))

echo -e "  汇总: ${GREEN}${ok_count} OK${NC}  ${RED}${fail_count} FAIL${NC}  共 7 个服务"
echo "========================================="
