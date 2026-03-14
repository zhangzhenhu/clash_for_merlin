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

# Remove custom page
rm -f /www/user/$(basename "$webui_page") 2>/dev/null

# 从 jffs 的备份中恢复原始 menuTree.js
if [ -f "${APP_HOME}/menuTree.js.bak" ]; then
    cp -f "${APP_HOME}/menuTree.js.bak" /www/require/modules/menuTree.js
fi

# 清理菜单链接
BASENAME=$(basename "$webui_page" 2>/dev/null)
if [ -n "$BASENAME" ] && [ -f /www/require/modules/menuTree.js ]; then
    if grep -q "tabName: \"Clash\"" /www/require/modules/menuTree.js 2>/dev/null; then
        sed -i "s/{url: \"${BASENAME}\", tabName: \"Clash\"},//g" /www/require/modules/menuTree.js
    fi
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
