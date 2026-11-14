#!/usr/bin/env bash
# =============================================================================
# 编译 App（xcodegen 生成工程 -> xcodebuild 出 .app）
#   必须: build/ios/lib/ 下 GalPlayer 侧库齐备
#   可选: Kirikinux2 侧库齐备时一并构建（缺库则跳过，.deb 里就只有主 App）
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
BUILD_ROOT="$ROOT_DIR/build/ios"

for lib in libSDL2.a libons.a libfreetype.a libSDL2_image.a libSDL2_ttf.a libSDL2_mixer.a libSDL2stdlib.a; do
    if [ ! -f "$BUILD_ROOT/lib/$lib" ]; then
        echo "[app] ERROR: 缺少 $BUILD_ROOT/lib/$lib"
        echo "  先运行 engines/SDL2/build_ios.sh 与 engines/onscripter/build_ios.sh"
        exit 1
    fi
done

command -v xcodegen >/dev/null || { echo "[app] ERROR: brew install xcodegen"; exit 1; }
command -v xcodebuild >/dev/null || { echo "[app] ERROR: 需要 macOS + Xcode"; exit 1; }

cd "$APP_DIR"
xcodegen generate

COMMON_ARGS=(
    -project GalPlayer.xcodeproj
    -configuration Release
    -sdk iphoneos
    -destination "generic/platform=iOS"
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
    CONFIGURATION_BUILD_DIR="$ROOT_DIR/build/app"
)

echo "[app] xcodebuild GalPlayer ..."
xcodebuild "${COMMON_ARGS[@]}" -target GalPlayer build

# ---- KRKR 引擎 App（可选，缺库则跳过） ----
KRKR_OK=1
for lib in libkrkr2core.a libcocos2d.a; do
    [ -f "$BUILD_ROOT/lib/$lib" ] || KRKR_OK=0
done
if [ "$KRKR_OK" = "1" ]; then
    echo "[app] xcodebuild Kirikinux2 ..."
    if ! xcodebuild "${COMMON_ARGS[@]}" -target Kirikinux2 build; then
        echo "[app] WARNING: Kirikinux2 构建失败，仅打包主 App"
    fi
else
    echo "[app] 跳过 Kirikinux2（KRKR 库未就绪: $BUILD_ROOT/lib/libkrkr2core.a）"
fi

ls -la "$ROOT_DIR/build/app" | head -20
echo "[app] OK。下一步: packaging/build_deb.sh"
