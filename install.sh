#!/bin/sh

source /usr/sbin/helper.sh

# ----------------------
check_clash_ui_installed() {
    # 判断是否已经安装过
    # 方法是检查 /www/user/目录下是否已经有包含关键词的文件
    local keyword="Clash UI Management"
    local user_dir="/www/user"
    
    # Check if any file in /www/user directory contains the keyword
    if [ -d "$user_dir" ]; then
        for file in "$user_dir"/*.asp; do
            if [ -f "$file" ] && grep -q "$keyword" "$file" 2>/dev/null; then
                am_webui_page="$(basename "$file")"  # Return the matched filename
                return 0  # Found installed Clash UI
            fi
        done
    fi
    
    return 1  # Not installed
}

# ----------------------
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

webui_page="${APP_HOME}/clashUI.asp"
if [ ! -f $webui_page ]
then
    logger -t "${naAPP_NAMEme}" "Missing clashUI.asp"
    exit 5
fi

am_webui_page="none"
# 判断是否已经安装过
if check_clash_ui_installed; then
    echo "Clash UI is already installed"
else
    echo "Clash UI is not installed"
    # Obtain the first available mount point in $am_webui_page
    # 这个指令会为 ${webui_page} 分配一个唯一的文件名称：user{xx}.asp，并存储在变量 am_webui_page
    am_get_webui_page "${webui_page}"
fi

if [ "$am_webui_page" = "none" ]
then
    logger -t "${APP_NAME}" "Unable to install clashUI"
    exit 5
fi
logger "${APP_NAME}" "Mounting MyPage as $am_webui_page"
# 实际上web系统会访问 /www/user{xx}.asp 系列文件
# 然而 /www/user{xx}.asp 是软连接，指向/www/user/user{xx}.asp
# 所以我们只需要把实际的文件移动到 /www/user/user{xx}.asp 即可
# Copy custom page
cp ${webui_page} /www/user/$am_webui_page

# Copy menuTree (if no other script has done it yet) so we can modify it
if [ ! -f /tmp/menuTree.js ]
then
    cp /www/require/modules/menuTree.js /tmp/
    # mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
fi

# Insert link at the end of the Tools menu.  Match partial string, since tabname can change between builds (if using an AS tag)
if ! grep -q "{url: \"$am_webui_page\", tabName: \"Clash\"}" /tmp/menuTree.js; then
    sed -i "/url: \"Tools_OtherSettings.asp\", tabName:/a {url: \"$am_webui_page\", tabName: \"Clash\"}," /tmp/menuTree.js
fi

# sed and binding mounts don't work well together, so remount modified file
umount /www/require/modules/menuTree.js && mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js

# 这些配置会写入到文件/jffs/addons/custom_settings.txt
# 系统可以通过 am_settings_get/am_settings_set 来操作这些配置
# webUI 页面中可以通过特殊的js变量操控这些配置
# 这样就实现了前后端（配置）信息的交互
# 但是这里的配置有长度限制，所以不能使用太长的值
# 详细参考 https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API
# am_settings_set clash_server 0.0.0.0

# am_settings_set clash_port 7890
# am_settings_set clash_server 0.0.0.0
# am_settings_set clash_mode rule
# am_settings_set clash_secret 0
am_settings_set clash_external_controller 0.0.0.0:9090
am_settings_set clash_secret default_secret_value
am_settings_set clash_config_path "$APP_HOME/configs"
# am_settings_set rules default

# webUI 中实现控制服务起停
# # webUI 会把两个字段传递个脚本 /jffs/scripts/service-event ，并执行这个脚本
#  $1: start|stop|restart
#  $2: 服务名
#  例如：restart myservice

# 控制脚本写入 /jffs/scripts/service-event
if ! grep -q "clash_service.sh" /jffs/scripts/service-event; then
    echo "${APP_HOME}/clash_service.sh \$*" >> /jffs/scripts/service-event
fi

echo "done"