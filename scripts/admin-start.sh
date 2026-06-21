#!/usr/bin/env bash
# Start local middleware and the Spring AI Alibaba Admin server.
#
# Usage:
#   scripts/admin-start.sh [--skip-deps] [--restart] [--build] [--foreground] [--port 8081]

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DIR="$ROOT_DIR/.local/run"
APP_NAME="spring-ai-alibaba-admin"
LABEL="com.spring-ai-alibaba-admin.admin-server"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
SERVER_PORT="${SERVER_PORT:-8081}"
SKIP_DEPS=0
RESTART=0
BUILD=0
FOREGROUND=0
FRONTEND_BUILT=0

usage() {
  sed -n '2,7p' "$0" | sed 's/^# //'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-deps)
      SKIP_DEPS=1
      shift
      ;;
    --restart)
      RESTART=1
      shift
      ;;
    --build)
      BUILD=1
      shift
      ;;
    --foreground)
      FOREGROUND=1
      shift
      ;;
    --port)
      SERVER_PORT="${2:?--port requires a value}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

log() {
  printf '[admin-start] %s\n' "$*"
}

java_bin() {
  if [ -x /Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home/bin/java ]; then
    echo /Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home/bin/java
  elif [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    echo "$JAVA_HOME/bin/java"
  elif [ "$(uname -s)" = "Darwin" ] && /usr/libexec/java_home -v 21 >/dev/null 2>&1; then
    echo "$(/usr/libexec/java_home -v 21)/bin/java"
  else
    command -v java
  fi
}

wait_http() {
  local url="$1"
  local timeout="${2:-120}"
  local elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    if curl -fsS -m 3 "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

build_if_needed() {
  local jar="$ROOT_DIR/spring-ai-alibaba-admin-server-start/target/spring-ai-alibaba-admin-server-start.jar"
  build_frontend_if_needed
  if [ "$BUILD" = "1" ] || [ "$FRONTEND_BUILT" = "1" ] || [ ! -f "$jar" ]; then
    log "building admin server jar..."
    local java
    java="$(java_bin)"
    local java_home
    java_home="$(cd "$(dirname "$java")/.." && pwd)"
    (cd "$ROOT_DIR" && JAVA_HOME="$java_home" PATH="$java_home/bin:$PATH" mvn -pl spring-ai-alibaba-admin-server-start -am clean package -DskipTests)
  fi
}

frontend_static_ready() {
  local static_dir="$ROOT_DIR/spring-ai-alibaba-admin-server-start/src/main/resources/static"
  local entry_js=""

  if [ -f "$static_dir/umi.js" ]; then
    entry_js="$static_dir/umi.js"
  elif [ -f "$static_dir/main.js" ]; then
    entry_js="$static_dir/main.js"
  fi

  [ -n "$entry_js" ] && grep -qE '/knowledge|main\.pages\.Knowledge|p__Knowledge' "$entry_js"
}

build_frontend_if_needed() {
  local frontend_dir="$ROOT_DIR/frontend"
  local dist_dir="$frontend_dir/packages/main/dist"
  local static_dir="$ROOT_DIR/spring-ai-alibaba-admin-server-start/src/main/resources/static"

  if [ "$BUILD" != "1" ] && frontend_static_ready; then
    return
  fi

  if ! command -v npm >/dev/null 2>&1; then
    log "npm is required to build the full frontend, but was not found"
    return 1
  fi

  log "building full frontend assets..."
  if [ ! -d "$frontend_dir/node_modules" ]; then
    (cd "$frontend_dir" && npm install --ignore-scripts)
  fi
  (cd "$frontend_dir" && npm run build:flow && BACK_END=java npm run build:app)

  if [ ! -d "$dist_dir" ]; then
    log "frontend dist not found after build: $dist_dir"
    return 1
  fi

  log "syncing frontend assets to backend static resources..."
  mkdir -p "$static_dir"
  find "$static_dir" -mindepth 1 -maxdepth 1 ! -name 'favicon.ico' -exec rm -rf {} +
  cp -R "$dist_dir/." "$static_dir/"
  FRONTEND_BUILT=1
}

start_deps() {
  if [ "$SKIP_DEPS" = "1" ]; then
    log "skip middleware startup"
    return
  fi

  log "starting middleware..."
  "$ROOT_DIR/scripts/deps-start.sh"
}

write_runner() {
  mkdir -p "$RUN_DIR" "$HOME/Library/LaunchAgents"
  local java
  java="$(java_bin)"

  cat > "$RUN_DIR/start-admin-server.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$ROOT_DIR"
JAVA_BIN="$java"

cd "\$ROOT_DIR"
source "\$ROOT_DIR/scripts/install-deps.local.env" 2>/dev/null || true

export APP_NAME="\${APP_NAME:-$APP_NAME}"
export SPRING_DATASOURCE_URL="\${SPRING_DATASOURCE_URL:-jdbc:mysql://localhost:3306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai}"
export SPRING_DATASOURCE_USERNAME="\${SPRING_DATASOURCE_USERNAME:-admin}"
export SPRING_DATASOURCE_PASSWORD="\${SPRING_DATASOURCE_PASSWORD:-admin}"
export SPRING_REDIS_HOST="\${SPRING_REDIS_HOST:-localhost}"
export SPRING_REDIS_PORT="\${SPRING_REDIS_PORT:-6379}"
export SPRING_ELASTICSEARCH_URIS="\${SPRING_ELASTICSEARCH_URIS:-http://localhost:9200}"
export SPRING_ELASTICSEARCH_URL="\${SPRING_ELASTICSEARCH_URL:-http://localhost:9200}"
export NACOS_SERVER_ADDR="\${NACOS_SERVER_ADDR:-localhost:8848}"
export ROCKETMQ_ENDPOINTS="\${ROCKETMQ_ENDPOINTS:-localhost:18080}"
export ROCKETMQ_NAME_SERVER="\${ROCKETMQ_NAME_SERVER:-localhost:9876}"
export SERVER_PORT="\${SERVER_PORT:-$SERVER_PORT}"

exec "\$JAVA_BIN" -jar "\$ROOT_DIR/spring-ai-alibaba-admin-server-start/target/spring-ai-alibaba-admin-server-start.jar"
EOF
  chmod +x "$RUN_DIR/start-admin-server.sh"

  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$RUN_DIR/start-admin-server.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$ROOT_DIR</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>StandardOutPath</key>
  <string>$RUN_DIR/admin-server.log</string>
  <key>StandardErrorPath</key>
  <string>$RUN_DIR/admin-server.err.log</string>
</dict>
</plist>
EOF
}

run_foreground() {
  local java
  java="$(java_bin)"

  cd "$ROOT_DIR"
  source "$ROOT_DIR/scripts/install-deps.local.env" 2>/dev/null || true

  export APP_NAME="${APP_NAME:-$APP_NAME}"
  export SPRING_DATASOURCE_URL="${SPRING_DATASOURCE_URL:-jdbc:mysql://localhost:3306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai}"
  export SPRING_DATASOURCE_USERNAME="${SPRING_DATASOURCE_USERNAME:-admin}"
  export SPRING_DATASOURCE_PASSWORD="${SPRING_DATASOURCE_PASSWORD:-admin}"
  export SPRING_REDIS_HOST="${SPRING_REDIS_HOST:-localhost}"
  export SPRING_REDIS_PORT="${SPRING_REDIS_PORT:-6379}"
  export SPRING_ELASTICSEARCH_URIS="${SPRING_ELASTICSEARCH_URIS:-http://localhost:9200}"
  export SPRING_ELASTICSEARCH_URL="${SPRING_ELASTICSEARCH_URL:-http://localhost:9200}"
  export NACOS_SERVER_ADDR="${NACOS_SERVER_ADDR:-localhost:8848}"
  export ROCKETMQ_ENDPOINTS="${ROCKETMQ_ENDPOINTS:-localhost:18080}"
  export ROCKETMQ_NAME_SERVER="${ROCKETMQ_NAME_SERVER:-localhost:9876}"
  export SERVER_PORT

  log "starting admin server in foreground on port $SERVER_PORT"
  exec "$java" -jar "$ROOT_DIR/spring-ai-alibaba-admin-server-start/target/spring-ai-alibaba-admin-server-start.jar"
}

start_launch_agent() {
  local domain="gui/$(id -u)"

  write_runner

  if [ "$RESTART" = "1" ]; then
    launchctl bootout "$domain" "$PLIST" >/dev/null 2>&1 || true
  elif curl -fsS -m 3 "http://localhost:${SERVER_PORT}/actuator/health" >/dev/null 2>&1; then
    log "admin server already healthy: http://localhost:${SERVER_PORT}/admin"
    return 0
  fi

  launchctl bootout "$domain" "$PLIST" >/dev/null 2>&1 || true
  launchctl bootstrap "$domain" "$PLIST"
  launchctl kickstart -k "$domain/$LABEL" >/dev/null 2>&1 || true

  log "waiting for admin server health..."
  if wait_http "http://localhost:${SERVER_PORT}/actuator/health" 180; then
    log "admin server ready: http://localhost:${SERVER_PORT}/admin"
  else
    log "admin server failed to become healthy; recent logs:"
    tail -120 "$RUN_DIR/admin-server.log" 2>/dev/null || true
    tail -80 "$RUN_DIR/admin-server.err.log" 2>/dev/null || true
    return 1
  fi
}

main() {
  start_deps
  build_if_needed

  if [ "$FOREGROUND" = "1" ]; then
    run_foreground
  fi

  if [ "$(uname -s)" = "Darwin" ]; then
    start_launch_agent
  else
    mkdir -p "$RUN_DIR"
    nohup env SERVER_PORT="$SERVER_PORT" "$ROOT_DIR/.local/run/start-admin-server.sh" \
      > "$RUN_DIR/admin-server.log" 2> "$RUN_DIR/admin-server.err.log" < /dev/null &
    echo $! > "$RUN_DIR/admin-server.pid"
    wait_http "http://localhost:${SERVER_PORT}/actuator/health" 180
    log "admin server ready: http://localhost:${SERVER_PORT}/admin"
  fi
}

main
