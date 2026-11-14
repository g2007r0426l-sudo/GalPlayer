#!/usr/bin/env bash
# =============================================================================
# 设备安装 —— 通过 USB SSH (iproxy -> dropbear 127.0.0.1:44) 推送 .deb 并 dpkg 安装
#
# 用法:
#   install_device.sh [deb路径]        # 默认 dist/com.yg.galplayer_0.1.0_iphoneos-arm64.deb
#   install_device.sh --uninstall      # 卸载
#
# 设备侧要求:
#   - palera1n rootless 越狱，dropbear 监听 127.0.0.1:44（root 密码通常 alpine）
#   - Mac 端已安装 libimobiledevice: brew install libimobiledevice usbmuxd
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEB="${1:-$ROOT_DIR/dist/com.yg.galplayer_0.1.0_iphoneos-arm64.deb}"
HOST_PORT=2222
DEVICE_PORT=44      # dropbear
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)

UNINSTALL=0
if [ "${1:-}" = "--uninstall" ]; then UNINSTALL=1; fi

command -v iproxy >/dev/null || { echo "ERROR: 未安装 iproxy —— brew install libimobiledevice"; exit 1; }

# 1. usbmux 端口转发（后台）
echo "[install] 启动 iproxy ${HOST_PORT} -> ${DEVICE_PORT} ..."
iproxy $HOST_PORT $DEVICE_PORT &
PROXY_PID=$!
trap 'kill $PROXY_PID 2>/dev/null || true' EXIT
sleep 1

if [ "$UNINSTALL" = "1" ]; then
    echo "[install] 卸载 GalPlayer ..."
    ssh -p $HOST_PORT "${SSH_OPTS[@]}" root@127.0.0.1 \
        "dpkg -r com.yg.galplayer; uicache -u com.yg.galplayer 2>/dev/null; killall GalPlayer 2>/dev/null; true"
    echo "[install] 已卸载（图标将在桌面刷新后消失）"
    exit 0
fi

[ -f "$DEB" ] || { echo "ERROR: 未找到 $DEB —— 先运行 packaging/build_deb.sh"; exit 1; }

# 2. 推送 deb
echo "[install] 推送 $(basename "$DEB") ..."
scp -P $HOST_PORT "${SSH_OPTS[@]}" "$DEB" root@127.0.0.1:/var/mobile/Documents/GalPlayer.deb

# 3. dpkg 安装（postinst 自动跑: 权限/ldid/uicache）
echo "[install] dpkg -i ..."
ssh -p $HOST_PORT "${SSH_OPTS[@]}" root@127.0.0.1 \
    "dpkg -i /var/mobile/Documents/GalPlayer.deb"

# 4. 启动
echo "[install] 启动 App ..."
ssh -p $HOST_PORT "${SSH_OPTS[@]}" root@127.0.0.1 \
    "uiopen -b com.yg.galplayer" || true

echo "[install] 完成。图标应已出现在桌面。"
echo "  闪退排查: ssh -p $HOST_PORT root@127.0.0.1 'ls -t /var/mobile/Library/Logs/CrashReporter/*.ips | head -1'"
