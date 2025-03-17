#!/bin/sh
source /usr/sbin/helper.sh
SERVICE=$2
ACTION=$1
event="$SERVICE-$ACTION"

logger -t "service-event" "收到指令 $*"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
APP_HOME=${SCRIPT_DIR}

ARCH=$(uname -m)
if [ "$ARCH" = "armv7l" ]; then
    CLASH_BIN_NAME="clash-linux-armv7"
elif [ "$ARCH" = "aarch64" ]; then
    CLASH_BIN_NAME="clash-linux-armv8"
else
    CLASH_BIN_NAME="clash-linux-amd64"
fi
CLASH_BIN_PATH="${APP_HOME}/bin/clash-linux-armv7"

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


# Function to start Clash service
start_clash_service() {
    logger  -t "service-event"  "Starting Clash service"
    "${CLASH_BIN_PATH}" -d "${CLASH_CONFIG}" -ext-ctl "${CLASH_ctl}" -secret  "${CLASH_secret}" -ext-ui "${APP_HOME}/dashboard/" &
    service clash restart
}

stop_clash_service() {
    logger  -t "service-event"  "Killing Clash service"
    killall ${CLASH_BIN_NAME}
#     service clash restart
}

# Function to restart Clash service
restart_clash_service() {
    logger  -t "service-event" "Restarting Clash service"
    stop_clash_service
    start_clash_service
}



case "$SERVICE-$ACTION" in
    "clash-restart")
        logger -t "service-event" "重启 clash..."
        restart_clash_service
        ;;
    "clash-start")
        logger -t "service-event" "启动 clash..."
        start_clash_service
        ;;

    "clash-stop")
        logger -t "service-event" "停止 clash..."
        stop_clash_service
        ;;
     *)
        echo "未知指令 $event"
        logger -t "service-event" "未知指令 $event"
        ;;
esac
