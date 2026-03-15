#!/bin/sh
APP_NAME="clash_for_merlin"
APP_HOME="/jffs/addons/${APP_NAME}"
MENUTREE_SRC="${APP_HOME}/menuTree.js"
MENUTREE_DST="/www/require/modules/menuTree.js"
CLASH_TMP="/tmp/clash"

# 挂载 menuTree.js - 使用 grep 检测是否已挂载修改后的版本
if grep -q "Clash" "$MENUTREE_DST" 2>/dev/null; then
    logger -t "$APP_NAME" "menuTree.js 已挂载"
    echo "menuTree.js 已挂载"
else
    umount "$MENUTREE_DST" 2>/dev/null
    if [ -f "$MENUTREE_SRC" ]; then
        mount -o bind "$MENUTREE_SRC" "$MENUTREE_DST"
        logger -t "$APP_NAME" "已挂载 menuTree.js"
    fi
fi

# 检测 /tmp/clash 是否存在，不存在则解压
if [ ! -f "$CLASH_TMP" ] && [ -d "${APP_HOME}/binaries" ]; then
    mkdir -p /tmp
    for gz_file in "${APP_HOME}"/binaries/*.gz; do
        if [ -f "$gz_file" ]; then
            ARCH=$(uname -m)
            case "$ARCH" in
                armv5*)
                    if echo "$gz_file" | grep -q "armv5"; then
                        gzip -dc "$gz_file" > "$CLASH_TMP"
                        chmod +x "$CLASH_TMP"
                        logger -t "$APP_NAME" "已解压: $(basename $gz_file)"
                        break
                    fi
                    ;;
                armv6*)
                    if echo "$gz_file" | grep -q "armv6"; then
                        gzip -dc "$gz_file" > "$CLASH_TMP"
                        chmod +x "$CLASH_TMP"
                        logger -t "$APP_NAME" "已解压: $(basename $gz_file)"
                        break
                    fi
                    ;;
                armv7*)
                    if echo "$gz_file" | grep -q "armv7"; then
                        gzip -dc "$gz_file" > "$CLASH_TMP"
                        chmod +x "$CLASH_TMP"
                        logger -t "$APP_NAME" "已解压: $(basename $gz_file)"
                        break
                    fi
                    ;;
                aarch64)
                    if echo "$gz_file" | grep -qE "arm64|armv8"; then
                        gzip -dc "$gz_file" > "$CLASH_TMP"
                        chmod +x "$CLASH_TMP"
                        logger -t "$APP_NAME" "已解压: $(basename $gz_file)"
                        break
                    fi
                    ;;
            esac
        fi
    done
fi

# 创建 bin 目录软链接
if [ -f "$CLASH_TMP" ] && [ ! -L "${APP_HOME}/bin/clash" ]; then
    mkdir -p "${APP_HOME}/bin"
    ln -sf "$CLASH_TMP" "${APP_HOME}/bin/clash"
fi

source /usr/sbin/helper.sh

CLASH_VERSION=$("$CLASH_TMP" -v 2>/dev/null | head -n1)
if [ -n "$CLASH_VERSION" ]; then
    CLASH_VERSION_CLEAN=$(echo "$CLASH_VERSION" | tr ' ' '_')
    am_settings_set clash_version "$CLASH_VERSION_CLEAN"
    logger -t "$APP_NAME" "已设置 clash_version: $CLASH_VERSION_CLEAN"
fi
