#!/bin/sh

source /usr/sbin/helper.sh
SERVICE=$2
ACTION=$1
ARCH=$(uname -m)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_HOME="$SCRIPT_DIR"
LOG_FILE="${APP_HOME}/log/clash.log"
PID_FILE="${APP_HOME}/clash.pid"


logger -t "clash_service" "ARCH：${ARCH} 收到指令: $SERVICE $ACTION"

case "$ARCH" in
    armv7l)
        CLASH_BIN_NAME="clash-linux-armv7"
        ;;
    aarch64)
        CLASH_BIN_NAME="clash-linux-armv8"
        ;;
    *)
        CLASH_BIN_NAME="clash-linux-amd64"
        ;;
esac
CLASH_BIN_PATH="${APP_HOME}/bin/${CLASH_BIN_NAME}"

# A yml config file is required for clash
CLASH_CONFIG=$(am_settings_get clash_config_path)
if [ -z "${CLASH_CONFIG}" ]; then
    CLASH_CONFIG="${APP_HOME}/configs"
fi

CLASH_ctl=$(am_settings_get clash_external_controller)
if [ -z "${CLASH_ctl}" ]; then
    CLASH_ctl="0.0.0.0:9090"
    am_settings_set clash_external_controller 0.0.0.0:9090
fi

CLASH_secret=$(am_settings_get clash_secret)
if [ -z "${CLASH_secret}" ]; then
    CLASH_secret="default_secret_value"
    am_settings_set clash_secret default_secret_value
fi

# 检查 Clash 二进制文件是否存在
if [ ! -f "$CLASH_BIN_PATH" ]; then
    logger -t "clash_service" "错误: Clash 二进制文件不存在: $CLASH_BIN_PATH"
    exit 1
fi

# 检查配置文件目录是否存在
if [ ! -d "$CLASH_CONFIG" ]; then
    logger -t "clash_service" "错误: 配置目录不存在: $CLASH_CONFIG"
    exit 1
fi

get_clash_pid() {
    if [ -f "$PID_FILE" ]; then
        cat "$PID_FILE"
    else
        pgrep -f "${CLASH_BIN_NAME}" 2>/dev/null | head -1
    fi
}

is_clash_running() {
    local pid=$(get_clash_pid)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Function to start Clash service
start_clash_service() {
    if is_clash_running; then
        local pid=$(get_clash_pid)
        logger -t "clash_service" "Clash 已在运行 (PID: $pid)"
        return 0
    fi

    logger -t "clash_service" "启动 Clash 服务"
    "${CLASH_BIN_PATH}" -d "${CLASH_CONFIG}" -ext-ctl "${CLASH_ctl}" -secret "${CLASH_secret}" -ext-ui "${APP_HOME}/dashboard/" >> "${LOG_FILE}" 2>&1 &

    local new_pid=$!
    echo "$new_pid" > "$PID_FILE"
    logger -t "clash_service" "Clash 已启动 (PID: $new_pid)"
}

# Function to stop Clash service
stop_clash_service() {
    if ! is_clash_running; then
        logger -t "clash_service" "Clash 未在运行"
        [ -f "$PID_FILE" ] && rm -f "$PID_FILE"
        return 0
    fi

    local pid=$(get_clash_pid)
    logger -t "clash_service" "停止 Clash 服务 (PID: $pid)"

    kill "$pid" 2>/dev/null
    sleep 1

    # 强制终止如果还存在
    if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null
    fi

    rm -f "$PID_FILE"
    logger -t "clash_service" "Clash 已停止"
}

# Function to restart Clash service
restart_clash_service() {
    stop_clash_service
    sleep 1
    start_clash_service
}

case "${SERVICE}-${ACTION}" in
    "clash-restart")
        restart_clash_service
        ;;
    "clash-start")
        start_clash_service
        ;;
    "clash-stop")
        stop_clash_service
        ;;
    *)
        logger -t "clash_service" "未知指令: ${SERVICE}-${ACTION}"
        echo "未知指令: ${SERVICE}-${ACTION}"
        exit 1
        ;;
esac
