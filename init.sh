#!/bin/sh

# ----------------------
# 检查 jffs 分区是否挂载
if [ ! -d "/jffs" ] || [ ! -w "/jffs" ]; then
    echo "ERROR: jffs 分区未挂载或不可写"
    exit 1
fi

source /usr/sbin/helper.sh

# ----------------------
check_clash_ui_installed() {
    # 判断是否已经安装过
    # 方法是检查 /www/user/目录下是否已经有包含关键词的文件
    local keyword="Clash UI Management"
    local user_dir="/www/user"
    local found_page=""

    # Check if any file in /www/user directory contains the keyword
    if [ -d "$user_dir" ]; then
        for file in "$user_dir"/*.asp; do
            if [ -f "$file" ] && grep -q "$keyword" "$file" 2>/dev/null; then
                found_page="$(basename "$file")"
                break
            fi
        done
    fi

    # 通过全局变量返回结果
    if [ -n "$found_page" ]; then
        am_webui_page="$found_page"
        return 0  # Found installed Clash UI
    fi

    return 1  # Not installed
}

# ----------------------
# Does the firmware support addons?
APP_NAME="clash_for_merlin"
APP_HOME="/jffs/addons/${APP_NAME}"

nvram get rc_support | grep -q am_addons
if [ $? != 0 ]; then
    logger -t "${APP_NAME}" "This firmware does not support addons!"
    exit 5
fi

# 检查 addons 支持
nvram get rc_support | grep -q am_addons
if [ $? != 0 ]; then
    logger -t "${APP_NAME}" "This firmware does not support addons!"
    exit 5
fi

# 创建应用目录
if [ ! -d "$APP_HOME" ]; then
    mkdir -p "$APP_HOME"
    logger -t "${APP_NAME}" "创建应用目录: $APP_HOME"
fi

# 创建日志目录
if [ ! -d "${APP_HOME}/log" ]; then
    mkdir -p "${APP_HOME}/log"
fi


# 生产配置文件

CONFIG_YML="${APP_HOME}/configs/config.yaml"
if [ ! -f "$CONFIG_YML" ]; then
    if [ -f "${APP_HOME}/configs/config_template.yml" ]; then
        cp "${APP_HOME}/configs/config_template.yml" "$CONFIG_YML"
        logger -t "${APP_NAME}" "已生成配置文件: $CONFIG_YML"
    else
        logger -t "${APP_NAME}" "警告: 未找到配置模板文件"
    fi
fi

webui_page="${APP_HOME}/clashUI.asp"
if [ ! -f "$webui_page" ]; then
    logger -t "${APP_NAME}" "Missing clashUI.asp"
    exit 5
fi

am_webui_page="none"
# 判断是否已经安装过
if check_clash_ui_installed; then
    logger -t "${APP_NAME}" "Clash UI is already installed (page: $am_webui_page)"
     exit 5
else
    # Obtain the first available mount point in $am_webui_page
    # 这个指令会为 ${webui_page} 分配一个唯一的文件名称：user{xx}.asp，并存储在变量 am_webui_page
    am_get_webui_page "${webui_page}"
fi

if [ "$am_webui_page" = "none" ]; then
    logger -t "${APP_NAME}" "Unable to install clashUI"
    exit 5
fi
logger -t "${APP_NAME}" "Mounting MyPage as $am_webui_page"

# 实际上web系统会访问 /www/user{xx}.asp 系列文件
# 然而 /www/user{xx}.asp 是软连接，指向/www/user/user{xx}.asp
# 所以我们只需要把实际的文件移动到 /www/user/user{xx}.asp 即可
# Copy custom page
cp "$webui_page" /www/user/"$am_webui_page"
logger -t "${APP_NAME}" "已复制 Web UI 文件"

# 备份原始 menuTree.js
if [ -f /www/require/modules/menuTree.js ] && [ ! -f "${APP_HOME}/menuTree.js.bak" ]; then
    cp /www/require/modules/menuTree.js "${APP_HOME}/menuTree.js.bak"
fi

if [ -f /www/require/modules/menuTree.js ]; then
    cp /www/require/modules/menuTree.js /tmp/
fi

# Insert link at the end of the Tools menu.  Match partial string, since tabname can change between builds
if ! grep -q "{url: \"$am_webui_page\", tabName: \"Clash\"}" /tmp/menuTree.js 2>/dev/null; then
    sed -i "/url: \"Tools_OtherSettings.asp\", tabName:/a {url: \"$am_webui_page\", tabName: \"Clash\"}," /tmp/menuTree.js
    logger -t "${APP_NAME}" "已添加菜单项"
fi

# 将 menuTree.js 的修改持久化写入 jffs
cp /tmp/menuTree.js "${APP_HOME}/menuTree.js"

# 立即应用修改到系统（当前会话也生效）
cp /tmp/menuTree.js /www/require/modules/menuTree.js

# 配置 service-start 脚本实现开机自动恢复
SERVICE_START="/jffs/scripts/service-start"
START_SCRIPT="${APP_HOME}/service-start.sh"

# 创建启动恢复脚本
cat > "$START_SCRIPT" << 'SCRIPT_EOF'
#!/bin/sh
APP_NAME="clash_for_merlin"
APP_HOME="/jffs/addons/${APP_NAME}"
MENUTREE_SRC="${APP_HOME}/menuTree.js"
MENUTREE_DST="/www/require/modules/menuTree.js"

# 检查 menuTree.js 是否需要更新
if [ -f "$MENUTREE_SRC" ] && [ -f "$MENUTREE_DST" ]; then
    # 检查源文件是否包含 Clash 菜单项
    if grep -q 'tabName: "Clash"' "$MENUTREE_SRC"; then
        # 复制覆盖系统文件
        cp "$MENUTREE_SRC" "$MENUTREE_DST"
        logger -t "$APP_NAME" "已恢复 menuTree.js"
    fi
fi
SCRIPT_EOF
chmod +x "$START_SCRIPT"

# 在 service-start 中添加启动调用
SERVICE_LINE="${START_SCRIPT}"
if [ -f "$SERVICE_START" ]; then
    if ! grep -qF "$START_SCRIPT" "$SERVICE_START" 2>/dev/null; then
        echo "$SERVICE_LINE" >> "$SERVICE_START"
        logger -t "${APP_NAME}" "已注册启动脚本"
    fi
else
    echo "#!/bin/sh" > "$SERVICE_START"
    echo "$SERVICE_LINE" >> "$SERVICE_START"
    chmod +x "$SERVICE_START"
    logger -t "${APP_NAME}" "已创建 service-start 脚本"
fi

# 设置 Web UI 配置
# 这些配置会写入到文件/jffs/addons/custom_settings.txt
# 系统可以通过 am_settings_get/am_settings_set 来操作这些配置
# webUI 页面中可以通过特殊的js变量操控这些配置
# 这样就实现了前后端（配置）信息的交互
# 但是这里的配置有长度限制，所以不能使用太长的值
# 详细参考 https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API
am_settings_set clash_external_controller 0.0.0.0:9090
am_settings_set clash_secret default_secret_value
am_settings_set clash_config_path "$APP_HOME/configs"

# webUI 中实现控制服务起停
# webUI 会把两个字段传递个脚本 /jffs/scripts/service-event ，并执行这个脚本
#  $1: start|stop|restart
#  $2: 服务名
#  例如：restart myservice
# 配置 service-event 脚本
SERVICE_EVENT="/jffs/scripts/service-event"
SERVICE_LINE="${APP_HOME}/clash_service.sh \$*"

if [ -f "$SERVICE_EVENT" ]; then
    # 检查是否已存在，避免重复添加
    if ! grep -qF "$SERVICE_LINE" "$SERVICE_EVENT" 2>/dev/null; then
        echo "$SERVICE_LINE" >> "$SERVICE_EVENT"
        logger -t "${APP_NAME}" "已更新 service-event 脚本"
    fi
else
    # 文件不存在则创建
    echo "#!/bin/sh" > "$SERVICE_EVENT"
    echo "$SERVICE_LINE" >> "$SERVICE_EVENT"
    chmod +x "$SERVICE_EVENT"
    logger -t "${APP_NAME}" "已创建 service-event 脚本"
fi

logger -t "${APP_NAME}" "安装完成"
echo "done"
