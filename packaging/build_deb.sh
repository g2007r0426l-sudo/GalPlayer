#!/usr/bin/env bash
# =============================================================================
# GalPlayer 一键打包 .deb
#
#   编译 App -> ldid 递归签名 -> debian 目录结构组装 -> dpkg-deb 出包
#   产出: dist/com.yg.galplayer_<ver>_iphoneos-arm64.deb
#
# 包含:
#   GalPlayer.app    主界面（扫描/识别/设置）
#   OnsPlayer.app    ONScripter 播放器（SDL2 应用）
#   Kirikinux2.app   Kirikiri2 播放器（可选，二期）
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/build/app"
APP_SRC="$OUT_DIR/GalPlayer.app"
ONS_APP_SRC="$OUT_DIR/OnsPlayer.app"
KRKR_APP_SRC="$OUT_DIR/Kirikinux2.app"
KRKR_RES="$ROOT_DIR/build/krkr-resources"
VERSION="0.1.0"
STAGE="$ROOT_DIR/build/deb-stage"
DIST="$ROOT_DIR/dist"

[ -d "$APP_SRC" ] || { echo "[deb] ERROR: 未找到 $APP_SRC —— 先运行 scripts/build_app.sh"; exit 1; }
[ -d "$ONS_APP_SRC" ] || { echo "[deb] ERROR: 未找到 $ONS_APP_SRC —— ONS 引擎未构建"; exit 1; }

command -v ldid >/dev/null || { echo "[deb] ERROR: 未安装 ldid —— brew install ldid"; exit 1; }

bash "$ROOT_DIR/scripts/sign.sh" "$APP_SRC"
bash "$ROOT_DIR/scripts/sign.sh" "$ONS_APP_SRC"

if [ -d "$KRKR_APP_SRC" ]; then
    if [ -d "$KRKR_RES" ]; then
        mkdir -p "$KRKR_APP_SRC/Resources"
        cp -R "$KRKR_RES/"* "$KRKR_APP_SRC/Resources/" 2>/dev/null || true
    fi
    bash "$ROOT_DIR/scripts/sign.sh" "$KRKR_APP_SRC"
else
    echo "[deb] 注意: Kirikinux2.app 不存在（KRKR 未构建成功），本次不含 KRKR 播放器"
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" "$STAGE/var/jb/Applications"
cp -R "$APP_SRC"     "$STAGE/var/jb/Applications/GalPlayer.app"
cp -R "$ONS_APP_SRC" "$STAGE/var/jb/Applications/OnsPlayer.app"
[ -d "$KRKR_APP_SRC" ] && cp -R "$KRKR_APP_SRC" "$STAGE/var/jb/Applications/Kirikinux2.app"

cp "$ROOT_DIR/packaging/control" "$STAGE/DEBIAN/control"
cp "$ROOT_DIR/packaging/postinst" "$STAGE/DEBIAN/postinst"
cp "$ROOT_DIR/packaging/prerm"    "$STAGE/DEBIAN/prerm"
cp "$ROOT_DIR/packaging/postrm"   "$STAGE/DEBIAN/postrm"
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/prerm" "$STAGE/DEBIAN/postrm"
chmod 644 "$STAGE/DEBIAN/control"

mkdir -p "$DIST"
OUT="$DIST/com.yg.galplayer_${VERSION}_iphoneos-arm64.deb"
rm -f "$OUT"
command -v dpkg-deb >/dev/null || { echo "[deb] ERROR: 未安装 dpkg-deb —— brew install dpkg"; exit 1; }
dpkg-deb --root-owner-group -Zgzip -b "$STAGE" "$OUT"

echo "[deb] OK -> $OUT ($(du -h "$OUT" | cut -f1))"
