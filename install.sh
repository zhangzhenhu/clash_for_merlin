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

# 检测设备架构
echo "检测设备架构..."
ARCH=$(uname -m)
echo "检测到架构: $ARCH"

# 根据架构选择对应的 mihomo 包
# 华硕梅林固件常用架构:
# - aarch64 (64位) - 如 RT-AX86U, RT-AX88U, RT-AX92U 等
# - armv7l (32位) - 如 RT-AC68U, RT-AC88U, RT-AC3100 等
case "$ARCH" in
    aarch64)
        PKG_NAME="mihomo-linux-arm64-v1.19.21"
        echo "选择: arm64 (64位) 版本"
        ;;
    armv7l|armv6l|armhf)
        PKG_NAME="mihomo-linux-armv7-v1.19.21"
        echo "选择: armv7 (32位) 版本"
        ;;
    *)
        echo "警告: 未知的架构 $ARCH，尝试使用 armv7 版本"
        PKG_NAME="mihomo-linux-armv7-v1.19.21"
        ;;
esac

RELEASE_FILE="clash_for_merlin_${PKG_NAME}.tar.gz"
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/v${LATEST_TAG}/${RELEASE_FILE}"

echo "下载安装包: ${RELEASE_FILE}..."

# 下载 release 包
TMP_DIR="/tmp/clash_install"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

if ! curl -fsSL "$DOWNLOAD_URL" -o "${TMP_DIR}/${RELEASE_FILE}"; then
    echo "错误: 下载失败，请检查网络连接或版本是否支持当前架构"
    rm -rf "$TMP_DIR"
    exit 1
fi

# 解压到应用目录
echo "解压文件..."
rm -rf "${APP_HOME}"
mkdir -p "${APP_HOME}"
tar -xzf "${TMP_DIR}/${RELEASE_FILE}" -C "${APP_HOME}"

# 设置权限
echo "设置权限..."
chmod +x "${APP_HOME}/"*.sh
chmod +x "${APP_HOME}/bin/"* 2>/dev/null || true

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
