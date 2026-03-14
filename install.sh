#!/bin/sh

set -e

# Clash for Merlin - 一键安装脚本
# 用法: curl -sL https://github.com/zhangzhenhu/clash_for_merlin/releases/latest/download/install.sh | sh

GITHUB_REPO="zhangzhenhu/clash_for_merlin"
APP_NAME="clash_for_merlin"
APP_HOME="/jffs/addons/${APP_NAME}"
VERSION="latest"

echo "========================================="
echo "  Clash for Merlin 一键安装脚本"
echo "========================================="

# 检查 jffs 分区
if [ ! -d "/jffs" ] || [ ! -w "/jffs" ]; then
    echo "错误: jffs 分区未挂载或不可写"
    exit 1
fi

# 检查是否已安装
if [ -d "${APP_HOME}" ] && [ -f "${APP_HOME}/init.sh" ]; then
    echo "检测到 Clash for Merlin 已安装"
    read -p "是否重新安装? (y/N): " confirm
    case "$confirm" in
        [yY]|[yY][eE][sS])
            echo "开始重新安装..."
            ;;
        *)
            echo "取消安装"
            exit 0
            ;;
    esac
fi

# 获取最新 release 版本
echo "获取最新版本..."
LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')

if [ -z "$LATEST_TAG" ]; then
    echo "错误: 无法获取最新版本"
    exit 1
fi

echo "最新版本: v${LATEST_TAG}"

# 下载 release 包
TMP_DIR="/tmp/clash_install"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

echo "下载安装包..."
curl -fsSL "https://github.com/${GITHUB_REPO}/releases/download/v${LATEST_TAG}/clash_for_merlin.tar.gz" -o "${TMP_DIR}/clash_for_merlin.tar.gz"

# 解压到应用目录
echo "解压文件..."
rm -rf "${APP_HOME}"
mkdir -p "${APP_HOME}"
tar -xzf "${TMP_DIR}/clash_for_merlin.tar.gz" -C "${APP_HOME}"

# 设置权限
echo "设置权限..."
chmod +x "${APP_HOME}/"*.sh
chmod +x "${APP_HOME}/bin/"*

# 清理临时文件
rm -rf "$TMP_DIR"

# 执行实际安装
echo "执行安装..."
cd "${APP_HOME}"
sh ./init.sh

echo ""
echo "========================================="
echo "  安装完成！"
echo "========================================="
echo ""
echo "请在浏览器中访问路由器管理页面"
echo "点击 Tools -> Clash 进入 Clash 管理界面"
echo ""
echo "Web UI 访问地址: http://路由器IP:9090/ui"
echo ""
