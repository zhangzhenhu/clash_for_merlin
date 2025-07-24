#!/bin/sh

source /usr/sbin/helper.sh

# Does the firmware support addons?
APP_NAME="clash_for_merlin"
APP_HOME="/jffs/addons/${APP_NAME}"
nvram get rc_support | grep -q am_addons
if [ $? != 0 ]
then
    logger -t "${APP_NAME}" "This firmware does not support addons!"
    exit 5
fi


# 生产配置文件

CONFIG_YML="${APP_HOME}/configs/config.yaml"
if [ ! -f $CONFIG_YML ]
then
    cp ${APP_HOME}/configs/config_template.yml $CONFIG_YML
fi

webui_page="/jffs/addons/${APP_NAME}/clashUI.asp"
if [ ! -f $webui_page ]
then
    logger -t "${naAPP_NAMEme}" "Missing clashUI.asp"
    exit 5
fi
# Obtain the first available mount point in $am_webui_page
am_get_webui_page "${webui_page}"

if [ "$am_webui_page" = "none" ]
then
    logger -t "${APP_NAME}" "Unable to install clashUI"
    exit 5
fi
logger "${APP_NAME}" "Mounting MyPage as $am_webui_page"

# Copy custom page
cp ${webui_page} /www/user/$am_webui_page

# Copy menuTree (if no other script has done it yet) so we can modify it
if [ ! -f /tmp/menuTree.js ]
then
    cp /www/require/modules/menuTree.js /tmp/
    mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
fi

# Insert link at the end of the Tools menu.  Match partial string, since tabname can change between builds (if using an AS tag)
if ! grep -q "{url: \"$am_webui_page\", tabName: \"Clash\"}" /tmp/menuTree.js; then
    sed -i "/url: \"Tools_OtherSettings.asp\", tabName:/a {url: \"$am_webui_page\", tabName: \"Clash\"}," /tmp/menuTree.js
fi

# sed and binding mounts don't work well together, so remount modified file
umount /www/require/modules/menuTree.js && mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js


# am_settings_set clash_port 7890
# am_settings_set clash_server 0.0.0.0
# am_settings_set clash_mode rule
# am_settings_set clash_secret 0
am_settings_set clash_external_controller 0.0.0.0:9090
am_settings_set clash_secret default_secret_value
am_settings_set clash_config_path "$APP_HOME/configs"
# am_settings_set rules default

echo "${APP_HOME}/clash_service.sh \$*">> /jffs/scripts/service-event

echo "done"