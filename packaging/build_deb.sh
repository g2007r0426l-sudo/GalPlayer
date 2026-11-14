#!/usr/bin/env bash
# =============================================================================
# GalPlayer 一键打包 .deb
#
#   编译 App -> ldid 递归签名 -> debian 目录结构组装 -> dpkg-deb 出包
#   产出: dist/com.yg.galplayer_<ver>_iphoneos-arm64.deb
#
# 包含两个 App:
#   GalPlayer.app    主界面（扫描/识别/ONS 引擎）
#   Kirikinux2.app   KRKR 引擎（cocos2d-x + Kirikiroid2 核心，可选）
#
# 前置: build_all.sh（或分步脚本）已产出 build/app/GalPlayer.app
# 依赖: brew install ldid dpkg
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$ROOT_DIR/build/app/GalPlayer.app"
KRKR_APP_SRC="$ROOT_DIR/build/app/Kirikinux2.app"
KRKR_RES="$ROOT_DIR/build/krkr-resources"
VERSION="0.1.0"
STAGE="$ROOT_DIR/build/deb-stage"
DIST="$ROOT_DIR/dist"

[ -d "$APP_SRC" ] || { echo "[deb] ERROR: 未找到 $APP_SRC —— 先运行 scripts/build_app.sh"; exit 1; }

# ---------------------------------------------------------------------------
# 1. ldid 递归签名（主程序 + Frameworks/ 下每一个 Mach-O，缺一启动即崩）
# ---------------------------------------------------------------------------
command -v ldid >/dev/null || { echo "[deb] ERROR: 未安装 ldid —— brew install ldid"; exit 1; }
bash "$ROOT_DIR/scripts/sign.sh" "$APP_SRC"

if [ -d "$KRKR_APP_SRC" ]; then
    # 引擎自带 UI 资源（cocos 资源包）
    if [ -d "$KRKR_RES" ]; then
        mkdir -p "$KRKR_APP_SRC/Resources"
        cp -R "$KRKR_RES/"* "$KRKR_APP_SRC/Resources/" 2>/dev/null || true
    fi
    bash "$ROOT_DIR/scripts/sign.sh" "$KRKR_APP_SRC"
else
    echo "[deb] 注意: Kirikinux2.app 不存在（KRKR 引擎未构建成功），本次只打包 GalPlayer"
fi

# ---------------------------------------------------------------------------
# 2. 组装 debian 目录
#    rootless(palera1n) 布局: 内容放 ./var/jb/... ；rootful 兜底在 postinst 里判断
# ---------------------------------------------------------------------------
rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" "$STAGE/var/jb/Applications"
cp -R "$APP_SRC" "$STAGE/var/jb/Applications/GalPlayer.app"
[ -d "$KRKR_APP_SRC" ] && cp -R "$KRKR_APP_SRC" "$STAGE/var/jb/Applications/Kirikinux2.app"

cp "$ROOT_DIR/packaging/control" "$STAGE/DEBIAN/control"
cp "$ROOT_DIR/packaging/postinst" "$STAGE/DEBIAN/postinst"
cp "$ROOT_DIR/packaging/prerm"    "$STAGE/DEBIAN/prerm"
cp "$ROOT_DIR/packaging/postrm"   "$STAGE/DEBIAN/postrm"
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/prerm" "$STAGE/DEBIAN/postrm"
chmod 644 "$STAGE/DEBIAN/control"

# ---------------------------------------------------------------------------
# 3. 出包（root-owner-group 保证 root:wheel 属主）
# ---------------------------------------------------------------------------
mkdir -p "$DIST"
OUT="$DIST/com.yg.galplayer_${VERSION}_iphoneos-arm64.deb"
rm -f "$OUT"

command -v dpkg-deb >/dev/null || { echo "[deb] ERROR: 未安装 dpkg-deb —— brew install dpkg"; exit 1; }
dpkg-deb --root-owner-group -Zgzip -b "$STAGE" "$OUT"

echo "[deb] OK -> $OUT ($(du -h "$OUT" | cut -f1))"
echo "[deb] 安装方式: AirDrop/Filza 拷贝到设备 -> Filza 点击安装（自动跑 postinst）"
echo "[deb] 或: scripts/install_device.sh"
