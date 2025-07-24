#!/bin/sh

source /usr/sbin/helper.sh

APP_NAME="clash_for_merlin"
APP_HOME="/jffs/addons/${APP_NAME}"
webui_page="/jffs/addons/${APP_NAME}/clashUI.asp"

# 先停掉clash 服务
service stop_clash

# Remove custom page
rm -f /www/user/$(basename $webui_page)

# Restore original menuTree.js if it was modified
if [ -f /tmp/menuTree.js ]; then
    umount /www/require/modules/menuTree.js
    rm -f /tmp/menuTree.js
fi

# Remove the link from the Tools menu
if grep -q "{url: \"$(basename $webui_page)\", tabName: \"Clash\"}" /www/require/modules/menuTree.js; then
    sed -i "/{url: \"$(basename $webui_page)\", tabName: \"Clash\"},/d" /www/require/modules/menuTree.js
fi

# Remove settings
# am_settings_unset clash_external_controller
# am_settings_unset clash_secret
# am_settings_unset clash_config_path

# Remove service-event entry
sed -i "/${APP_HOME}\/clash_service.sh/d" /jffs/scripts/service-event

# Remove application files
rm -rf ${APP_HOME}

logger -t "${APP_NAME}" "Uninstalled successfully"

echo "done"
