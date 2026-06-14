#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$ROOT_DIR/scripts/install-log.md"
DEPS_DIR="$ROOT_DIR/.local/deps"
RUN_DIR="$ROOT_DIR/.local/run"
DOWNLOAD_DIR="$ROOT_DIR/.local/downloads"
LOCAL_ENV_FILE="$ROOT_DIR/scripts/install-deps.local.env"

if [ -f "$LOCAL_ENV_FILE" ]; then
  # 本地私有配置文件用于放 MYSQL_ROOT_PASSWORD 等敏感值，不建议提交。
  # shellcheck disable=SC1090
  . "$LOCAL_ENV_FILE"
fi

MYSQL_DB="${MYSQL_DB:-admin}"
MYSQL_USER="${MYSQL_USER:-admin}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-admin}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root}"

ES_VERSION="${ES_VERSION:-9.1.2}"
KIBANA_VERSION="${KIBANA_VERSION:-9.1.2}"
NACOS_VERSION="${NACOS_VERSION:-3.0.3}"
ROCKETMQ_VERSION="${ROCKETMQ_VERSION:-5.3.2}"
LOONGCOLLECTOR_VERSION="${LOONGCOLLECTOR_VERSION:-3.1.4}"
APACHE_MIRROR="${APACHE_MIRROR:-https://mirrors.tuna.tsinghua.edu.cn/apache}"

START_SERVICES="${START_SERVICES:-1}"
INSTALL_OPTIONAL_KIBANA="${INSTALL_OPTIONAL_KIBANA:-1}"
SKIP_ELASTICSEARCH="${SKIP_ELASTICSEARCH:-0}"
SKIP_NACOS="${SKIP_NACOS:-0}"
SKIP_BREW_UPDATE="${SKIP_BREW_UPDATE:-1}"

mkdir -p "$DEPS_DIR" "$RUN_DIR" "$DOWNLOAD_DIR" "$(dirname "$LOG_FILE")"

cat > "$LOG_FILE" <<EOF
# 本地依赖安装日志

- 执行时间：$(date '+%Y-%m-%d %H:%M:%S %z')
- 项目目录：$ROOT_DIR
- 启动服务：$START_SERVICES
- 跳过 brew update：$SKIP_BREW_UPDATE
- 跳过 Elasticsearch：$SKIP_ELASTICSEARCH
- 跳过 Nacos：$SKIP_NACOS
- 安装 Kibana：$INSTALL_OPTIONAL_KIBANA
- 本地私有配置：$([ -f "$LOCAL_ENV_FILE" ] && echo "已读取 $LOCAL_ENV_FILE" || echo "未使用")

EOF

log() {
  echo "$*"
  printf '%s\n' "$*" >> "$LOG_FILE"
}

section() {
  log ""
  log "## $1"
  log ""
}

run_cmd() {
  log ""
  log '```bash'
  log "$*"
  log '```'
  "$@" 2>&1 | tee -a "$LOG_FILE"
  return "${PIPESTATUS[0]}"
}

retry_cmd() {
  local title="$1"
  shift
  local try=1
  local max=3
  while [ "$try" -le "$max" ]; do
    log ""
    log "- ${title}：第 ${try} 次尝试"
    if run_cmd "$@"; then
      log "- 结果：成功"
      return 0
    fi
    log "- 结果：失败"
    try=$((try + 1))
    sleep 2
  done
  log "- 连续失败 3 次，停止在：${title}"
  return 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

detect_os() {
  OS_NAME="$(uname -s)"
  ARCH_NAME="$(uname -m)"
  case "$OS_NAME" in
    Darwin) OS_FAMILY="macos" ;;
    Linux) OS_FAMILY="linux" ;;
    *) log "- 不支持的系统：$OS_NAME"; exit 1 ;;
  esac
  log "- 系统：$OS_NAME / $ARCH_NAME"
}

sudo_if_needed() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

install_pkg() {
  local pkg="$1"
  if [ "$OS_FAMILY" = "macos" ]; then
    if brew list --versions "$pkg" >/dev/null 2>&1; then
      log "- brew 包已存在：$pkg"
      return 0
    fi
    retry_cmd "brew install $pkg" brew install "$pkg"
  else
    retry_cmd "apt-get install $pkg" sudo_if_needed apt-get install -y "$pkg"
  fi
}

ensure_package_manager() {
  section "包管理器"
  if [ "$OS_FAMILY" = "macos" ]; then
    if ! have brew; then
      log "- 未检测到 Homebrew。安装方式：https://brew.sh/"
      return 1
    fi
    if [ "$SKIP_BREW_UPDATE" = "1" ]; then
      log "- 跳过 brew update；如需强制更新，执行 SKIP_BREW_UPDATE=0 scripts/install-deps.sh"
    else
      retry_cmd "brew update" brew update || log "- brew update 失败，继续使用本地索引尝试安装"
    fi
  else
    if ! have apt-get; then
      log "- 未检测到 apt-get，本脚本当前只支持 Debian/Ubuntu 系 Linux。"
      return 1
    fi
    retry_cmd "apt-get update" sudo_if_needed apt-get update
  fi
}

install_base_tools() {
  section "基础工具"
  if ! have curl; then install_pkg curl; else log "- curl 已存在：$(command -v curl)"; fi
  if ! have jq; then install_pkg jq || true; else log "- jq 已存在：$(command -v jq)"; fi
  if ! have unzip; then install_pkg unzip || true; else log "- unzip 已存在：$(command -v unzip)"; fi

  ensure_java
  if ! have mvn; then install_pkg maven; fi
  if ! have node; then
    if [ "$OS_FAMILY" = "macos" ]; then install_pkg node@20 || install_pkg node; else install_pkg nodejs; fi
  fi
  if ! have npm; then install_pkg npm; fi

  log "- Java：$(java -version 2>&1 | head -1 || true)"
  log "- Maven：$(mvn -version 2>/dev/null | head -1 || true)"
  log "- Node：$(node -v 2>/dev/null || true)"
  log "- npm：$(npm -v 2>/dev/null || true)"
}

java_major_version() {
  java -version 2>&1 | awk -F[\".] '/version/ { if ($2 == "1") print $3; else print $2; exit }'
}

ensure_java() {
  local java_major="0"
  if have java; then
    java_major="$(java_major_version)"
  fi

  if [ "$OS_FAMILY" = "macos" ] && [ "${java_major:-0}" -lt 17 ] && [ -x /usr/libexec/java_home ]; then
    local java21_home
    java21_home="$(/usr/libexec/java_home -v 21 2>/dev/null || true)"
    if [ -n "$java21_home" ]; then
      export JAVA_HOME="$java21_home"
      export PATH="$JAVA_HOME/bin:$PATH"
      java_major="$(java_major_version)"
      log "- 使用本机已有 JDK 21：$JAVA_HOME"
    fi
  fi

  if ! have java || [ "${java_major:-0}" -lt 17 ]; then
    log "- 未检测到可用 JDK >= 17。"
    if [ "$OS_FAMILY" = "macos" ]; then
      log "- 本脚本不再自动安装 openjdk@17；请先安装/切换到 JDK 21，例如设置 JAVA_HOME=$(/usr/libexec/java_home -v 21 2>/dev/null || echo '<JDK21_HOME>')。"
    else
      log "- Linux 可执行：sudo apt-get install -y openjdk-21-jdk，或设置 JAVA_HOME 指向 JDK 21。"
    fi
    return 1
  fi
}

install_mysql() {
  section "MySQL 8"
  if have mysql; then
    log "- mysql 命令已存在：$(command -v mysql)"
  else
    if [ "$OS_FAMILY" = "macos" ]; then
      install_pkg mysql@8.0 || install_pkg mysql
    else
      install_pkg mysql-server
    fi
  fi

  if [ "$START_SERVICES" = "1" ]; then
    if mysqladmin ping --silent >/dev/null 2>&1; then
      log "- MySQL 已在运行"
    elif have mysql.server; then
      retry_cmd "mysql.server start" mysql.server start || true
    elif [ "$OS_FAMILY" = "macos" ] && have brew; then
      brew services start mysql@8.0 >> "$LOG_FILE" 2>&1 || brew services start mysql >> "$LOG_FILE" 2>&1 || true
    else
      sudo_if_needed systemctl start mysql >> "$LOG_FILE" 2>&1 || sudo_if_needed service mysql start >> "$LOG_FILE" 2>&1 || true
    fi
  fi

  init_mysql
}

mysql_exec_root() {
  local sql="$1"
  if mysql -uroot -e "$sql" >/tmp/install-deps-mysql.out 2>&1; then
    cat /tmp/install-deps-mysql.out >> "$LOG_FILE"
    return 0
  fi
  if mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "$sql" >/tmp/install-deps-mysql.out 2>&1; then
    cat /tmp/install-deps-mysql.out >> "$LOG_FILE"
    return 0
  fi
  if [ "$OS_FAMILY" = "macos" ] && sudo -n mysql -uroot -e "$sql" >/tmp/install-deps-mysql.out 2>&1; then
    cat /tmp/install-deps-mysql.out >> "$LOG_FILE"
    return 0
  fi
  if [ "$OS_FAMILY" = "linux" ] && sudo mysql -uroot -e "$sql" >/tmp/install-deps-mysql.out 2>&1; then
    cat /tmp/install-deps-mysql.out >> "$LOG_FILE"
    return 0
  fi
  cat /tmp/install-deps-mysql.out >> "$LOG_FILE" || true
  return 1
}

init_mysql() {
  log "- 初始化要求：创建数据库 ${MYSQL_DB}，创建用户 ${MYSQL_USER}，并导入两份 schema SQL。"
  local sql
  sql="CREATE DATABASE IF NOT EXISTS \`$MYSQL_DB\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD'; CREATE USER IF NOT EXISTS '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD'; GRANT ALL PRIVILEGES ON \`$MYSQL_DB\`.* TO '$MYSQL_USER'@'%'; GRANT ALL PRIVILEGES ON \`$MYSQL_DB\`.* TO '$MYSQL_USER'@'localhost'; FLUSH PRIVILEGES;"
  if retry_cmd "MySQL 建库建用户" mysql_exec_root "$sql"; then
    if mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DB" -N -e "SHOW TABLES LIKE 'account'; SHOW TABLES LIKE 'dataset'; SHOW TABLES LIKE 'agent_schema';" 2>/dev/null | grep -q "agent_schema"; then
      log "- MySQL schema 已存在关键表：account、dataset、agent_schema；跳过重复导入，避免外键 drop 冲突。"
      return 0
    fi
    if mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DB" < "$ROOT_DIR/docker/middleware/init/mysql/admin-schema.sql" >> "$LOG_FILE" 2>&1 \
      && mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DB" < "$ROOT_DIR/docker/middleware/init/mysql/agentscope-schema.sql" >> "$LOG_FILE" 2>&1; then
      log "- MySQL schema 初始化完成：admin-schema.sql、agentscope-schema.sql"
    else
      log "- MySQL schema 导入失败。常见原因：已存在结构不兼容、root 权限不足、MySQL 未启动。"
      return 1
    fi
  else
    log "- MySQL root 登录失败。脚本已尝试 root 空密码、root/root、Linux sudo mysql。"
    log "- macOS 上也会尝试 sudo -n mysql；如果 sudo 需要密码，脚本不会交互式索要。"
    log "- 为避免破坏你已有的 MySQL，本脚本不会自动停服、重置 root 密码或使用 --skip-grant-tables。"
    log "- 如果你使用自定义 root 密码，可重新执行：MYSQL_ROOT_PASSWORD='你的密码' scripts/install-deps.sh"
    return 1
  fi
}

install_redis() {
  section "Redis 7"
  if have redis-server; then
    log "- redis-server 已存在：$(command -v redis-server)"
  else
    if [ "$OS_FAMILY" = "macos" ]; then install_pkg redis; else install_pkg redis-server; fi
  fi
  if [ "$START_SERVICES" = "1" ]; then
    if redis-cli ping >/dev/null 2>&1; then
      log "- Redis 已在运行"
    elif [ "$OS_FAMILY" = "macos" ] && have brew; then
      brew services start redis >> "$LOG_FILE" 2>&1 || nohup redis-server --daemonize yes >> "$LOG_FILE" 2>&1 || true
    else
      sudo_if_needed systemctl start redis-server >> "$LOG_FILE" 2>&1 || sudo_if_needed service redis-server start >> "$LOG_FILE" 2>&1 || nohup redis-server --daemonize yes >> "$LOG_FILE" 2>&1 || true
    fi
    redis-cli ping >> "$LOG_FILE" 2>&1 && log "- Redis 初始化完成：无需建库，使用 database 0" || log "- Redis 未通过 ping 检查"
  fi
}

download_file() {
  local url="$1"
  local dest="$2"
  local min_bytes="${3:-1}"
  if [ -f "$dest" ]; then
    local size
    size="$(wc -c < "$dest" | tr -d ' ')"
    if [ "$size" -lt "$min_bytes" ]; then
      log "- 已存在下载文件过小，视为不完整并删除：$dest (${size} bytes)"
      rm -f "$dest"
    else
      log "- 下载文件已存在：$dest"
      return 0
    fi
  fi
  # 尝试从 ~/Downloads/ 复制已手动下载的文件
  local basename
  basename="$(basename "$dest")"
  local user_download="$HOME/Downloads/$basename"
  if [ -f "$user_download" ]; then
    local src_size
    src_size="$(wc -c < "$user_download" | tr -d ' ')"
    if [ "$src_size" -ge "$min_bytes" ]; then
      log "- 从 ~/Downloads/ 复制已下载文件：$user_download (${src_size} bytes)"
      cp "$user_download" "$dest"
      return 0
    else
      log "- ~/Downloads/$basename 文件过小 (${src_size} bytes)，跳过复制。"
    fi
  fi
  if [ -f "$dest" ]; then
    log "- 下载文件已存在：$dest"
    return 0
  fi
  retry_cmd "下载 $url" curl -L --retry 3 --retry-delay 2 -o "$dest" "$url"
}

extract_tar_gz() {
  local archive="$1"
  local marker="$2"
  if [ -d "$marker" ]; then
    log "- 解压目录已存在：$marker"
    return 0
  fi
  retry_cmd "解压 $archive" tar -xzf "$archive" -C "$DEPS_DIR"
}

extract_zip() {
  local archive="$1"
  local marker="$2"
  if [ -d "$marker" ]; then
    log "- 解压目录已存在：$marker"
    return 0
  fi
  retry_cmd "解压 $archive" unzip -q "$archive" -d "$DEPS_DIR"
}

elastic_archive_name() {
  if [ "$OS_FAMILY" = "macos" ]; then
    if [ "$ARCH_NAME" = "arm64" ]; then echo "elasticsearch-${ES_VERSION}-darwin-aarch64.tar.gz"; else echo "elasticsearch-${ES_VERSION}-darwin-x86_64.tar.gz"; fi
  else
    if [ "$ARCH_NAME" = "aarch64" ] || [ "$ARCH_NAME" = "arm64" ]; then echo "elasticsearch-${ES_VERSION}-linux-aarch64.tar.gz"; else echo "elasticsearch-${ES_VERSION}-linux-x86_64.tar.gz"; fi
  fi
}

kibana_archive_name() {
  if [ "$OS_FAMILY" = "macos" ]; then
    if [ "$ARCH_NAME" = "arm64" ]; then echo "kibana-${KIBANA_VERSION}-darwin-aarch64.tar.gz"; else echo "kibana-${KIBANA_VERSION}-darwin-x86_64.tar.gz"; fi
  else
    if [ "$ARCH_NAME" = "aarch64" ] || [ "$ARCH_NAME" = "arm64" ]; then echo "kibana-${KIBANA_VERSION}-linux-aarch64.tar.gz"; else echo "kibana-${KIBANA_VERSION}-linux-x86_64.tar.gz"; fi
  fi
}

install_elasticsearch() {
  section "Elasticsearch ${ES_VERSION}"
  if [ "$SKIP_ELASTICSEARCH" = "1" ]; then
    log "- 跳过 Elasticsearch 安装/启动/初始化；用户正在手动下载 ES/Kibana。"
    log "- ES 下载完成后放到：$DOWNLOAD_DIR/$(elastic_archive_name)"
    log "- 后续可执行：SKIP_ELASTICSEARCH=0 INSTALL_OPTIONAL_KIBANA=0 scripts/install-deps.sh"
    return 0
  fi

  # 已在运行则跳过
  if curl -fsS http://localhost:9200/_cluster/health >/dev/null 2>&1; then
    log "- Elasticsearch 已在运行"
    init_elasticsearch
    return 0
  fi

  # 已有 brew 安装的 elasticsearch
  if have elasticsearch; then
    log "- elasticsearch 命令已存在：$(command -v elasticsearch)"
    if [ "$START_SERVICES" = "1" ]; then
      if [ "$OS_FAMILY" = "macos" ] && have brew; then
        brew services start elastic/tap/elasticsearch-full >> "$LOG_FILE" 2>&1 || elasticsearch -d -p "$RUN_DIR/elasticsearch.pid" >> "$LOG_FILE" 2>&1 || true
      else
        ES_JAVA_OPTS="-Xms1g -Xmx1g" elasticsearch -d -p "$RUN_DIR/elasticsearch.pid" >> "$LOG_FILE" 2>&1 || true
      fi
      wait_http "Elasticsearch" "http://localhost:9200/_cluster/health" 90 || return 1
      init_elasticsearch
    fi
    return 0
  fi

  local archive
  archive="$(elastic_archive_name)"
  local url="https://artifacts.elastic.co/downloads/elasticsearch/$archive"
  local dest="$DOWNLOAD_DIR/$archive"
  local es_home="$DEPS_DIR/elasticsearch-$ES_VERSION"

  # 已有解压目录则跳过下载和解压
  if [ ! -d "$es_home" ]; then
    # 尝试 brew 安装
    if [ "$OS_FAMILY" = "macos" ] && have brew; then
      retry_cmd "brew tap elastic/tap" brew tap elastic/tap || true
      if retry_cmd "brew install elastic/tap/elasticsearch-full" brew install elastic/tap/elasticsearch-full; then
        log "- Elasticsearch 已通过 Homebrew elastic/tap 安装。"
        if [ "$START_SERVICES" = "1" ]; then
          brew services start elastic/tap/elasticsearch-full >> "$LOG_FILE" 2>&1 || true
          wait_http "Elasticsearch" "http://localhost:9200/_cluster/health" 90 || return 1
          init_elasticsearch
        fi
        return 0
      fi
      log "- Homebrew 安装 Elasticsearch 失败，退回下载安装。"
    fi

    # 下载文件（会自动尝试从 ~/Downloads/ 复制）
    download_file "$url" "$dest" 100000000 || {
      log "- Elasticsearch 下载失败（文件约 472MB）。"
      log "- 请手动下载放到：$dest"
      log "- 下载链接：$url"
      log "- 或放到 ~/Downloads/ 目录下脚本会自动检测。"
      return 0
    }
    extract_tar_gz "$dest" "$es_home" || return 1
  else
    log "- Elasticsearch 解压目录已存在：$es_home"
  fi

  # 配置
  mkdir -p "$es_home/data" "$es_home/logs"
  cat > "$es_home/config/elasticsearch.yml" <<EOF
cluster.name: es-cluster
node.name: es-node-1
discovery.type: single-node
xpack.security.enabled: false
xpack.security.enrollment.enabled: false
http.port: 9200
transport.port: 9300
path.data: data
path.logs: logs
http.cors.enabled: true
http.cors.allow-origin: "*"
action.destructive_requires_name: false
cluster.routing.allocation.disk.watermark.low: 95%
cluster.routing.allocation.disk.watermark.high: 98%
cluster.routing.allocation.disk.watermark.flood_stage: 99%
EOF
  log "- Elasticsearch 放置路径：$es_home"

  # 启动
  if [ "$START_SERVICES" = "1" ]; then
    if [ "$OS_FAMILY" = "macos" ]; then
      start_elasticsearch_launchctl "$es_home" || return 1
    else
      ES_JAVA_OPTS="-Xms1g -Xmx1g" "$es_home/bin/elasticsearch" -d -p "$RUN_DIR/elasticsearch.pid" >> "$LOG_FILE" 2>&1 || true
      wait_http "Elasticsearch" "http://localhost:9200/_cluster/health" 90 || return 1
    fi
    init_elasticsearch
  fi
}

start_elasticsearch_launchctl() {
  local es_home="$1"
  local label="com.spring-ai-alibaba-admin.elasticsearch"
  local java_home_current="${JAVA_HOME:-$(/usr/libexec/java_home -v 21 2>/dev/null || true)}"

  cat > "$RUN_DIR/start-elasticsearch.sh" <<EOF
#!/usr/bin/env bash
export JAVA_HOME="${java_home_current}"
export PATH="\$JAVA_HOME/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export ES_JAVA_OPTS="-Xms1g -Xmx1g"
cd "${es_home}"
exec "${es_home}/bin/elasticsearch"
EOF
  chmod +x "$RUN_DIR/start-elasticsearch.sh"

  local plist
  plist="$(write_launch_agent "$label" "$RUN_DIR/start-elasticsearch.sh" "$RUN_DIR/elasticsearch.log" "$RUN_DIR/elasticsearch.err.log")"
  launch_agent_restart "$label" "$plist" || return 1
  wait_http "Elasticsearch" "http://localhost:9200/_cluster/health" 120 || return 1
}

wait_http() {
  local name="$1"
  local url="$2"
  local seconds="$3"
  local elapsed=0
  while [ "$elapsed" -lt "$seconds" ]; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      log "- $name 已就绪：$url"
      return 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  log "- $name 等待超时：$url"
  return 1
}

init_elasticsearch() {
  local tmp="$RUN_DIR/init-indices-local.sh"
  sed 's#http://elasticsearch:9200#http://localhost:9200#g' "$ROOT_DIR/docker/middleware/init/elasticsearch/init-indices.sh" > "$tmp"
  chmod +x "$tmp"
  if retry_cmd "Elasticsearch 初始化 trace pipeline/index" "$tmp"; then
    log "- Elasticsearch 初始化完成：parsing_loongsuite_traces、loongsuite_traces"
  else
    return 1
  fi
}

install_kibana() {
  if [ "$INSTALL_OPTIONAL_KIBANA" != "1" ]; then
    log "- 跳过 Kibana，可设置 INSTALL_OPTIONAL_KIBANA=1 开启。"
    return 0
  fi
  section "Kibana ${KIBANA_VERSION}"

  # 已在运行则跳过
  if curl -fsS http://localhost:5601/api/status >/dev/null 2>&1; then
    log "- Kibana 已在运行"
    return 0
  fi

  if have kibana; then
    log "- kibana 命令已存在：$(command -v kibana)"
    return 0
  fi

  local archive
  archive="$(kibana_archive_name)"
  local url="https://artifacts.elastic.co/downloads/kibana/$archive"
  local dest="$DOWNLOAD_DIR/$archive"
  local kibana_home="$DEPS_DIR/kibana-$KIBANA_VERSION"

  # 已有解压目录则跳过下载和解压
  if [ ! -d "$kibana_home" ]; then
    # 尝试 brew 安装
    if [ "$OS_FAMILY" = "macos" ] && have brew; then
      retry_cmd "brew tap elastic/tap" brew tap elastic/tap || true
      if retry_cmd "brew install elastic/tap/kibana-full" brew install elastic/tap/kibana-full; then
        log "- Kibana 已通过 Homebrew elastic/tap 安装。"
        return 0
      fi
      log "- Homebrew 安装 Kibana 失败，退回下载安装。"
    fi

    # 下载文件（会自动尝试从 ~/Downloads/ 复制）
    download_file "$url" "$dest" 100000000 || {
      log "- Kibana 下载失败（文件约 245MB）。"
      log "- 请手动下载放到：$dest"
      log "- 下载链接：$url"
      log "- 或放到 ~/Downloads/ 目录下脚本会自动检测。"
      return 0
    }
    extract_tar_gz "$dest" "$kibana_home" || return 1
  else
    log "- Kibana 解压目录已存在：$kibana_home"
  fi

  # 配置（Kibana 9.x 不支持 xpack.security.enabled 配置项）
  cat > "$kibana_home/config/kibana.yml" <<EOF
server.port: 5601
server.host: "127.0.0.1"
elasticsearch.hosts: ["http://localhost:9200"]
EOF
  log "- Kibana 放置路径：$kibana_home"

  # 启动
  if [ "$START_SERVICES" = "1" ]; then
    if [ "$OS_FAMILY" = "macos" ]; then
      start_kibana_launchctl "$kibana_home" || return 1
    else
      nohup "$kibana_home/bin/kibana" > "$RUN_DIR/kibana.log" 2>&1 &
      echo $! > "$RUN_DIR/kibana.pid"
      wait_http "Kibana" "http://localhost:5601/api/status" 180 || log "- Kibana 未通过 HTTP 检查"
    fi
  fi
}

start_kibana_launchctl() {
  local kibana_home="$1"
  local label="com.spring-ai-alibaba-admin.kibana"

  cat > "$RUN_DIR/start-kibana.sh" <<EOF
#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "${kibana_home}"
exec "${kibana_home}/bin/kibana"
EOF
  chmod +x "$RUN_DIR/start-kibana.sh"

  local plist
  plist="$(write_launch_agent "$label" "$RUN_DIR/start-kibana.sh" "$RUN_DIR/kibana.log" "$RUN_DIR/kibana.err.log")"
  launch_agent_restart "$label" "$plist" || return 1
  wait_http "Kibana" "http://localhost:5601/api/status" 180 || log "- Kibana 未通过 HTTP 检查"
}

install_nacos() {
  section "Nacos ${NACOS_VERSION}"
  if [ "$SKIP_NACOS" = "1" ]; then
    log "- 跳过 Nacos 安装/启动；设置 SKIP_NACOS=0 启用。"
    log "- 手动下载地址：https://github.com/alibaba/nacos/releases/download/${NACOS_VERSION}/nacos-server-${NACOS_VERSION}.tar.gz"
    log "- 下载后放到：$DOWNLOAD_DIR/nacos-server-${NACOS_VERSION}.tar.gz"
    log "- 当前项目未发现必须预建 Nacos namespace/dataId/group。"
    return 0
  fi

  # 已在运行则跳过
  if curl -fsS http://localhost:8848/nacos/ >/dev/null 2>&1; then
    log "- Nacos 已在运行"
    return 0
  fi

  local archive="nacos-server-${NACOS_VERSION}.tar.gz"
  local dest="$DOWNLOAD_DIR/$archive"
  local nacos_home="$DEPS_DIR/nacos"
  [ -d "$nacos_home" ] || nacos_home="$DEPS_DIR/nacos-server-$NACOS_VERSION"

  # 已有解压目录则跳过下载
  if [ ! -d "$nacos_home" ]; then
    # 尝试多个下载源：GitHub -> ghproxy 镜像 -> 国内 CDN
    local urls=(
      "https://github.com/alibaba/nacos/releases/download/${NACOS_VERSION}/$archive"
      "https://ghfast.top/https://github.com/alibaba/nacos/releases/download/${NACOS_VERSION}/$archive"
    )
    local downloaded=false
    for url in "${urls[@]}"; do
      log "- 尝试下载源：$url"
      if download_file "$url" "$dest" 1000000; then
        downloaded=true
        break
      fi
      log "- 下载源失败：$url"
    done

    if [ "$downloaded" = "false" ]; then
      log "- 所有下载源均失败。"
      log "- 请手动下载并放到：$dest"
      log "- 或放到 ~/Downloads/ 目录下脚本会自动检测。"
      log "- 下载地址：https://github.com/alibaba/nacos/releases/download/${NACOS_VERSION}/$archive"
      return 0
    fi

    extract_tar_gz "$dest" "$nacos_home" || true
    # 重新检测解压目录
    [ -d "$nacos_home" ] || nacos_home="$DEPS_DIR/nacos-server-$NACOS_VERSION"
  else
    log "- Nacos 解压目录已存在：$nacos_home"
  fi

  if [ -d "$nacos_home" ]; then
    log "- Nacos 放置路径：$nacos_home"

    # 配置 application.properties 中的 auth token（Nacos 3.x 要求合法 Base64 token）
    local nacos_props="$nacos_home/conf/application.properties"
    if [ -f "$nacos_props" ]; then
      if grep -q "^nacos.core.auth.plugin.nacos.token.secret.key=$" "$nacos_props" 2>/dev/null; then
        log "- 设置 Nacos auth token.secret.key"
        sed -i '' 's|^nacos.core.auth.plugin.nacos.token.secret.key=.*|nacos.core.auth.plugin.nacos.token.secret.key=VGhpc0lzTXlDdXN0b21TZWNyZXRLZXkwMTIzNDU2Nzg=|' "$nacos_props"
        sed -i '' 's|^nacos.core.auth.server.identity.key=.*|nacos.core.auth.server.identity.key=admin|' "$nacos_props"
        sed -i '' 's|^nacos.core.auth.server.identity.value=.*|nacos.core.auth.server.identity.value=admin|' "$nacos_props"
      fi
    fi
  fi
  log "- Admin 当前未发现必须预建 Nacos namespace/dataId/group。"

  if [ "$START_SERVICES" = "1" ] && [ -d "$nacos_home" ] && [ -x "$nacos_home/bin/startup.sh" ]; then
    if [ "$OS_FAMILY" = "macos" ]; then
      start_nacos_launchctl "$nacos_home" || return 1
    else
      (cd "$nacos_home" && sh bin/startup.sh -m standalone) >> "$LOG_FILE" 2>&1 || true
      wait_http "Nacos" "http://localhost:8848/nacos/" 90 || log "- Nacos 未通过 HTTP 检查，后续可手动查看 $nacos_home/logs/start.out"
    fi
  fi
}

start_nacos_launchctl() {
  local nacos_home="$1"
  local label="com.spring-ai-alibaba-admin.nacos"
  local java_home_current="${JAVA_HOME:-$(/usr/libexec/java_home -v 21 2>/dev/null || true)}"

  # 直接 exec java，不通过 startup.sh（startup.sh 会 fork 后台进程导致 LaunchAgent 不断重启）
  cat > "$RUN_DIR/start-nacos.sh" <<EOF
#!/usr/bin/env bash
export JAVA_HOME="${java_home_current}"
export PATH="\$JAVA_HOME/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "${nacos_home}"
exec "\$JAVA_HOME/bin/java" \\
  -Xms512m -Xmx512m -Xmn256m \\
  -Dnacos.standalone=true \\
  -Dnacos.member.list= \\
  -Xlog:gc*:file=${nacos_home}/logs/nacos_gc.log:time,tags:filecount=10,filesize=100m \\
  -Dnacos.deployment.type=merged \\
  -Dloader.path=${nacos_home}/plugins,${nacos_home}/plugins/health,${nacos_home}/plugins/cmdb,${nacos_home}/plugins/selector \\
  -Dnacos.home=${nacos_home} \\
  -jar ${nacos_home}/target/nacos-server.jar \\
  --spring.config.additional-location=file:${nacos_home}/conf/ \\
  --logging.config=${nacos_home}/conf/nacos-logback.xml \\
  --server.max-http-request-header-size=524288
EOF
  chmod +x "$RUN_DIR/start-nacos.sh"

  local plist
  plist="$(write_launch_agent "$label" "$RUN_DIR/start-nacos.sh" "$RUN_DIR/nacos.log" "$RUN_DIR/nacos.err.log")"
  launch_agent_restart "$label" "$plist" || return 1
  wait_http "Nacos" "http://localhost:8848/nacos/" 90 || log "- Nacos 未通过 HTTP 检查，后续可手动查看 $nacos_home/logs/startup.log"
}

install_rocketmq() {
  section "RocketMQ ${ROCKETMQ_VERSION}"
  local archive="rocketmq-all-${ROCKETMQ_VERSION}-bin-release.zip"
  local url="${APACHE_MIRROR}/rocketmq/${ROCKETMQ_VERSION}/$archive"
  local dest="$DOWNLOAD_DIR/$archive"
  log "- RocketMQ 下载源：$url"
  download_file "$url" "$dest" 50000000 || return 1
  extract_zip "$dest" "$DEPS_DIR/rocketmq-all-${ROCKETMQ_VERSION}-bin-release" || return 1
  local home="$DEPS_DIR/rocketmq-all-${ROCKETMQ_VERSION}-bin-release"
  log "- RocketMQ 放置路径：$home"
  log "- 下载链接：$url"

  if [ "$START_SERVICES" = "1" ]; then
    start_rocketmq "$home" || return 1
    init_rocketmq "$home" || return 1
  fi
}

start_rocketmq() {
  local home="$1"
  if [ "$OS_FAMILY" = "macos" ]; then
    start_rocketmq_launchctl "$home"
    return $?
  fi

  if ! nc -z localhost 9876 >/dev/null 2>&1; then
    nohup sh "$home/bin/mqnamesrv" > "$RUN_DIR/rocketmq-namesrv.log" 2>&1 &
    echo $! > "$RUN_DIR/rocketmq-namesrv.pid"
  fi
  wait_port "RocketMQ NameServer" localhost 9876 60 || return 1

  if ! nc -z localhost 10911 >/dev/null 2>&1; then
    export NAMESRV_ADDR=localhost:9876
    export HEAP_OPTS="-Xms256M -Xmx512M -Xmn256M -XX:MaxDirectMemorySize=128M"
    write_rocketmq_broker_config
    nohup sh "$home/bin/mqbroker" -n localhost:9876 -c "$RUN_DIR/rmq-broker.conf" > "$RUN_DIR/rocketmq-broker.log" 2>&1 &
    echo $! > "$RUN_DIR/rocketmq-broker.pid"
  fi
  wait_port "RocketMQ Broker" localhost 10911 90 || return 1
  wait_rocketmq_cluster "$home" || return 1

  cat > "$RUN_DIR/rmq-proxy.json" <<EOF
{
  "rocketMQClusterName": "DefaultCluster",
  "remotingListenPort": 18080,
  "grpcServerPort": 18081,
  "proxyMode": "CLUSTER",
  "namesrvAddr": "localhost:9876"
}
EOF
  if ! nc -z localhost 18080 >/dev/null 2>&1; then
    export NAMESRV_ADDR=localhost:9876
    export HEAP_OPTS="-Xms128M -Xmx256M -Xmn128M"
    nohup sh "$home/bin/mqproxy" -n localhost:9876 -pc "$RUN_DIR/rmq-proxy.json" > "$RUN_DIR/rocketmq-proxy.log" 2>&1 &
    echo $! > "$RUN_DIR/rocketmq-proxy.pid"
  fi
  wait_port "RocketMQ Proxy" localhost 18080 90 || log "- RocketMQ Proxy 未通过端口检查，应用默认依赖 localhost:18080"
}

write_launch_agent() {
  local label="$1"
  local script_path="$2"
  local stdout_path="$3"
  local stderr_path="$4"
  local plist="$HOME/Library/LaunchAgents/${label}.plist"

  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${label}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${script_path}</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${ROOT_DIR}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${stdout_path}</string>
  <key>StandardErrorPath</key>
  <string>${stderr_path}</string>
</dict>
</plist>
EOF
  echo "$plist"
}

write_rocketmq_broker_config() {
  cat > "$RUN_DIR/rmq-broker.conf" <<EOF
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
}

launch_agent_restart() {
  local label="$1"
  local plist="$2"
  local domain="gui/$(id -u)"
  launchctl bootout "$domain" "$plist" >/dev/null 2>&1 || true
  launchctl bootstrap "$domain" "$plist" >> "$LOG_FILE" 2>&1
  launchctl kickstart -k "$domain/$label" >> "$LOG_FILE" 2>&1 || true
}

start_rocketmq_launchctl() {
  local home="$1"
  local namesrv_label="com.spring-ai-alibaba-admin.rocketmq.namesrv"
  local broker_label="com.spring-ai-alibaba-admin.rocketmq.broker"
  local proxy_label="com.spring-ai-alibaba-admin.rocketmq.proxy"
  local java_home_current="${JAVA_HOME:-$(/usr/libexec/java_home -v 21 2>/dev/null || true)}"

  cat > "$RUN_DIR/start-rocketmq-namesrv.sh" <<EOF
#!/usr/bin/env bash
export JAVA_HOME="${java_home_current}"
export PATH="\$JAVA_HOME/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "${home}"
exec sh "${home}/bin/mqnamesrv"
EOF

  write_rocketmq_broker_config
  cat > "$RUN_DIR/start-rocketmq-broker.sh" <<EOF
#!/usr/bin/env bash
export JAVA_HOME="${java_home_current}"
export PATH="\$JAVA_HOME/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export NAMESRV_ADDR="localhost:9876"
export HEAP_OPTS="-Xms256M -Xmx512M -Xmn256M -XX:MaxDirectMemorySize=128M"
until nc -z localhost 9876 >/dev/null 2>&1; do sleep 2; done
cd "${home}"
exec sh "${home}/bin/mqbroker" -n localhost:9876 -c "${RUN_DIR}/rmq-broker.conf"
EOF

  cat > "$RUN_DIR/rmq-proxy.json" <<EOF
{
  "rocketMQClusterName": "DefaultCluster",
  "remotingListenPort": 18080,
  "grpcServerPort": 18081,
  "proxyMode": "CLUSTER",
  "namesrvAddr": "localhost:9876"
}
EOF

  cat > "$RUN_DIR/start-rocketmq-proxy.sh" <<EOF
#!/usr/bin/env bash
export JAVA_HOME="${java_home_current}"
export PATH="\$JAVA_HOME/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export NAMESRV_ADDR="localhost:9876"
export HEAP_OPTS="-Xms128M -Xmx256M -Xmn128M"
until nc -z localhost 10911 >/dev/null 2>&1; do sleep 2; done
cd "${home}"
exec sh "${home}/bin/mqproxy" -n localhost:9876 -pc "${RUN_DIR}/rmq-proxy.json"
EOF

  chmod +x "$RUN_DIR/start-rocketmq-namesrv.sh" "$RUN_DIR/start-rocketmq-broker.sh" "$RUN_DIR/start-rocketmq-proxy.sh"

  local namesrv_plist broker_plist proxy_plist
  namesrv_plist="$(write_launch_agent "$namesrv_label" "$RUN_DIR/start-rocketmq-namesrv.sh" "$RUN_DIR/rocketmq-namesrv.log" "$RUN_DIR/rocketmq-namesrv.err.log")"
  broker_plist="$(write_launch_agent "$broker_label" "$RUN_DIR/start-rocketmq-broker.sh" "$RUN_DIR/rocketmq-broker.log" "$RUN_DIR/rocketmq-broker.err.log")"
  proxy_plist="$(write_launch_agent "$proxy_label" "$RUN_DIR/start-rocketmq-proxy.sh" "$RUN_DIR/rocketmq-proxy.log" "$RUN_DIR/rocketmq-proxy.err.log")"

  launch_agent_restart "$namesrv_label" "$namesrv_plist" || return 1
  wait_port "RocketMQ NameServer" localhost 9876 60 || return 1
  launch_agent_restart "$broker_label" "$broker_plist" || return 1
  wait_port "RocketMQ Broker" localhost 10911 90 || return 1
  wait_rocketmq_cluster "$home" || return 1
  launch_agent_restart "$proxy_label" "$proxy_plist" || return 1
  wait_port "RocketMQ Proxy" localhost 18080 90 || log "- RocketMQ Proxy 未通过端口检查，应用默认依赖 localhost:18080"
}

wait_rocketmq_cluster() {
  local home="$1"
  local elapsed=0
  while [ "$elapsed" -lt 90 ]; do
    if sh "$home/bin/mqadmin" clusterList -n localhost:9876 2>>"$LOG_FILE" | tee -a "$LOG_FILE" | grep -q "DefaultCluster"; then
      log "- RocketMQ DefaultCluster 路由已注册"
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
  log "- RocketMQ DefaultCluster 路由等待超时"
  return 1
}

wait_port() {
  local name="$1"
  local host="$2"
  local port="$3"
  local seconds="$4"
  local elapsed=0
  while [ "$elapsed" -lt "$seconds" ]; do
    if nc -z "$host" "$port" >/dev/null 2>&1; then
      log "- $name 已就绪：$host:$port"
      return 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  log "- $name 等待端口超时：$host:$port"
  return 1
}

init_rocketmq() {
  local home="$1"
  export NAMESRV_ADDR=localhost:9876
  retry_cmd "RocketMQ 创建文档索引 topic" sh "$home/bin/mqadmin" updateTopic -n localhost:9876 -t topic_saa_studio_document_index -c DefaultCluster -a +message.type=NORMAL || return 1
  retry_cmd "RocketMQ 创建文档索引 consumer group" sh "$home/bin/mqadmin" updateSubGroup -n localhost:9876 -g group_saa_studio_document_index -c DefaultCluster || return 1
  log "- RocketMQ 初始化完成：topic_saa_studio_document_index、group_saa_studio_document_index"
}

install_loongcollector() {
  section "LoongCollector ${LOONGCOLLECTOR_VERSION}"

  # 已在运行则跳过
  if curl -fsS -m 3 -X POST http://localhost:4318/v1/traces -d '{}' >/dev/null 2>&1; then
    log "- LoongCollector 已在运行（端口 4318）"
    return 0
  fi

  # 检查是否有本地原生二进制
  local lc_home="$DEPS_DIR/loongcollector-${LOONGCOLLECTOR_VERSION}"
  if [ -x "$lc_home/loongcollector" ]; then
    log "- 发现本地 LoongCollector 二进制：$lc_home/loongcollector"
    if [ "$START_SERVICES" = "1" ]; then
      # 需要用户自行配置，只给出提示
      log "- 本地二进制启动方式请参考官方文档。"
    fi
    return 0
  fi

  # 无本地二进制，尝试 Docker 容器
  if have docker && docker info >/dev/null 2>&1; then
    local image="sls-opensource-registry.cn-shanghai.cr.aliyuncs.com/loongcollector-community-edition/loongcollector:${LOONGCOLLECTOR_VERSION}"
    local conf_dir="$ROOT_DIR/docker/middleware/conf/loongcollector"
    log "- 通过 Docker 容器运行 LoongCollector"
    log "- 镜像：$image"

    if docker ps --filter name=loongcollector --format '{{.Names}}' | grep -q loongcollector; then
      log "- LoongCollector 容器已在运行"
    else
      # 删除已停止的旧容器
      docker rm -f loongcollector >/dev/null 2>&1 || true
      retry_cmd "启动 LoongCollector 容器" docker run -d \
        --name loongcollector \
        --restart always \
        -p 4318:4318 \
        -v "$conf_dir:/usr/local/loongcollector/conf/continuous_pipeline_config/local" \
        "$image" || {
        log "- Docker 容器启动失败"
        return 0
      }
      sleep 3
      if curl -fsS -m 3 -X POST http://localhost:4318/v1/traces -d '{}' >/dev/null 2>&1; then
        log "- LoongCollector 已通过 Docker 启动，端口 4318"
      else
        log "- LoongCollector 容器已创建，但 4318 端口未就绪，检查：docker logs loongcollector"
      fi
    fi
  else
    log "- 未找到可用的 Docker 或本地 LoongCollector 二进制。"
    log "- 官方容器镜像：sls-opensource-registry.cn-shanghai.cr.aliyuncs.com/loongcollector-community-edition/loongcollector:${LOONGCOLLECTOR_VERSION}"
    log "- 本项目配置文件：docker/middleware/conf/loongcollector/otlp_pipeline.yaml"
    log "- 如果需要本地原生运行，请将 LoongCollector 二进制放到：$lc_home/"
    log "- 必须监听：0.0.0.0:4318，并写入 Elasticsearch 索引 loongsuite_traces。"
  fi
}

write_env_hint() {
  section "应用连接环境变量"
  cat >> "$LOG_FILE" <<EOF

\`\`\`bash
export SPRING_DATASOURCE_URL='jdbc:mysql://localhost:3306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai'
export SPRING_DATASOURCE_USERNAME='admin'
export SPRING_DATASOURCE_PASSWORD='admin'
export SPRING_REDIS_HOST='localhost'
export SPRING_REDIS_PORT='6379'
export SPRING_REDIS_DATABASE='0'
export SPRING_ELASTICSEARCH_URIS='http://localhost:9200'
export SPRING_ELASTICSEARCH_URL='http://localhost:9200'
export NACOS_SERVER_ADDR='localhost:8848'
export ROCKETMQ_ENDPOINTS='localhost:18080'
export ROCKETMQ_NAME_SERVER='localhost:9876'
export ROCKETMQ_DOCUMENT_INDEX_TOPIC='topic_saa_studio_document_index'
export ROCKETMQ_DOCUMENT_INDEX_GROUP='group_saa_studio_document_index'
export MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT='http://localhost:4318/v1/traces'
\`\`\`

EOF
}

final_check() {
  section "最终校验"
  local all_ok=true

  # JDK
  local java_major
  java_major="$(java_major_version 2>/dev/null || echo 0)"
  if [ "${java_major:-0}" -ge 17 ]; then
    log "- JDK：版本 ${java_major}，路径为 \`${JAVA_HOME:-unknown}\`。"
  else
    log "- JDK：未检测到 JDK >= 17。"
    all_ok=false
  fi

  # MySQL
  if mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DB" -N -e "SELECT 1" >/dev/null 2>&1; then
    log "- MySQL：\`localhost:3306\` 已就绪；\`$MYSQL_DB\` 库可连接。"
  else
    log "- MySQL：\`localhost:3306\` 未就绪。"
    all_ok=false
  fi

  # Redis
  if redis-cli ping >/dev/null 2>&1; then
    log "- Redis：\`localhost:6379\` 已就绪。"
  else
    log "- Redis：\`localhost:6379\` 未就绪。"
    all_ok=false
  fi

  # Elasticsearch
  local es_status
  es_status="$(curl -fsS http://localhost:9200/_cluster/health 2>/dev/null | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4 || true)"
  if [ -n "$es_status" ]; then
    log "- Elasticsearch：\`localhost:9200\` 已就绪，集群状态 ${es_status}。"
  else
    log "- Elasticsearch：\`localhost:9200\` 未就绪。"
    all_ok=false
  fi

  # Kibana
  if [ "$INSTALL_OPTIONAL_KIBANA" = "1" ]; then
    if curl -fsS http://localhost:5601/api/status >/dev/null 2>&1; then
      log "- Kibana：\`localhost:5601\` 已就绪。"
    else
      log "- Kibana：\`localhost:5601\` 未就绪。"
    fi
  fi

  # Nacos
  if curl -fsS -m 3 http://localhost:8848/nacos/ >/dev/null 2>&1; then
    log "- Nacos：\`localhost:8848\` 已就绪。"
  else
    log "- Nacos：\`localhost:8848\` 未就绪。"
    all_ok=false
  fi

  # RocketMQ
  if nc -z localhost 9876 >/dev/null 2>&1 && nc -z localhost 10911 >/dev/null 2>&1; then
    log "- RocketMQ：\`9876/10911/18080\` 已就绪。"
  else
    log "- RocketMQ：端口未就绪。"
    all_ok=false
  fi

  # macOS LaunchAgent 列表
  if [ "$OS_FAMILY" = "macos" ]; then
    log "- macOS LaunchAgent 服务："
    for svc in elasticsearch kibana nacos rocketmq.namesrv rocketmq.broker rocketmq.proxy; do
      local label="com.spring-ai-alibaba-admin.${svc}"
      if launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
        log "  - ${svc}：已注册"
      fi
    done
    log ""
    log "- 查看服务状态：\`launchctl print gui/\$(id -u)/com.spring-ai-alibaba-admin.<service>\`"
    log "- 停止服务：\`launchctl bootout gui/\$(id -u) ~/Library/LaunchAgents/com.spring-ai-alibaba-admin.<service>.plist\`"
  fi

  # LoongCollector
  if curl -fsS -m 3 -X POST http://localhost:4318/v1/traces -d '{}' >/dev/null 2>&1; then
    log "- LoongCollector：\`localhost:4318\` 已就绪。"
  else
    log "- LoongCollector：\`localhost:4318\` 未就绪（可选依赖）。"
  fi

  # Docker 容器
  if have docker && docker ps --filter name=loongcollector --format '{{.Names}}' 2>/dev/null | grep -q loongcollector; then
    log "- Docker 容器 loongcollector：运行中"
  fi

  if [ "$all_ok" = "true" ]; then
    log ""
    log "- 所有必需依赖已就绪，可以启动后端应用。"
  else
    log ""
    log "- 部分依赖未就绪，请检查上方日志。"
  fi
}

main() {
  section "环境识别"
  detect_os
  ensure_package_manager || exit 1
  install_base_tools || exit 1
  install_mysql || exit 1
  install_redis || exit 1
  install_elasticsearch || exit 1
  install_nacos || exit 1
  install_rocketmq || exit 1
  install_loongcollector || true
  install_kibana || true
  write_env_hint
  final_check
  section "完成"
  log "- 安装脚本执行完成。"
  log "- 详细日志：$LOG_FILE"
}

main "$@"
