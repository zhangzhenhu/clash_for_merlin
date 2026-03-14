#!/bin/sh
APP_NAME="clash_for_merlin"
APP_HOME="/jffs/addons/${APP_NAME}"
MENUTREE_SRC="${APP_HOME}/menuTree.js"
MENUTREE_DST="/www/require/modules/menuTree.js"

# 如果已挂载则先卸载
if mountpoint -q "$MENUTREE_DST" 2>/dev/null; then
    umount "$MENUTREE_DST" 2>/dev/null
fi

# 挂载 menuTree.js
if [ -f "$MENUTREE_SRC" ]; then
    mount -o bind "$MENUTREE_SRC" "$MENUTREE_DST"
    logger -t "$APP_NAME" "已挂载 menuTree.js"
fi
