#!/bin/sh

# 保存当前目录，切换到根目录
OLD_CWD=$(pwd)
cd /

source /usr/sbin/helper.sh

APP_NAME="clash_for_merlin"
APP_HOME="/jffs/addons/${APP_NAME}"
webui_page="${APP_HOME}/clashUI.asp"

# 先停掉clash 服务
service clash stop 2>/dev/null

# 查找并删除 Web UI 页面
AM_WEBUI_PAGE=""
if [ -d "/www/user" ]; then
    for f in /www/user/*.asp; do
        if [ -f "$f" ] && grep -q "Clash UI Management" "$f" 2>/dev/null; then
            AM_WEBUI_PAGE=$(basename "$f")
            break
        fi
    done
fi

if [ -n "$AM_WEBUI_PAGE" ]; then
    rm -f /www/user/"$AM_WEBUI_PAGE"
fi

# 卸载 menuTree.js 的 bind mount
MENUTREE_DST="/www/require/modules/menuTree.js"
if mountpoint -q "$MENUTREE_DST" 2>/dev/null; then
    umount "$MENUTREE_DST" 2>/dev/null
fi

# Remove settings
am_settings_unset clash_external_controller 2>/dev/null
am_settings_unset clash_secret 2>/dev/null
am_settings_unset clash_config_path 2>/dev/null

# Remove service-event entry
if [ -f /jffs/scripts/service-event ]; then
    sed -i "\|${APP_HOME}/clash_service.sh|d" /jffs/scripts/service-event
fi

# Remove service-start entry
if [ -f /jffs/scripts/service-start ]; then
    sed -i "\|${APP_HOME}/service-start.sh|d" /jffs/scripts/service-start
fi

# Remove application files
rm -rf "${APP_HOME}"

logger -t "${APP_NAME}" "Uninstalled successfully"

echo "done"
