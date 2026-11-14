#!/usr/bin/env bash
# =============================================================================
# 编译 App（xcodegen 生成工程 -> xcodebuild）
#   GalPlayer  必建（UI 外壳）
#   OnsPlayer  必建（ONS 引擎，需要 libons.a + SDL 全栈）
#   Kirikinux2 可选（KRKR 引擎，缺库自动跳过）
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
BUILD_ROOT="$ROOT_DIR/build/ios"
OUT_DIR="$ROOT_DIR/build/app"

for lib in libSDL2.a libons.a libfreetype.a libSDL2_image.a libSDL2_ttf.a libSDL2_mixer.a libjpeg.a; do
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
    CONFIGURATION_BUILD_DIR="$OUT_DIR"
)

mkdir -p "$OUT_DIR"

echo "[app] xcodebuild GalPlayer ..."
xcodebuild "${COMMON_ARGS[@]}" -target GalPlayer build

echo "[app] xcodebuild OnsPlayer ..."
xcodebuild "${COMMON_ARGS[@]}" -target OnsPlayer build

KRKR_OK=1
for lib in libkrkr2core.a libcocos2d.a libkrkr2plugin.a; do
    [ -f "$BUILD_ROOT/lib/$lib" ] || KRKR_OK=0
done
if [ "$KRKR_OK" = "1" ]; then
    echo "[app] xcodebuild Kirikinux2 ..."
    xcodebuild "${COMMON_ARGS[@]}" -target Kirikinux2 build || echo "[app] WARNING: Kirikinux2 构建失败"
else
    echo "[app] 跳过 Kirikinux2（KRKR 库未就绪）"
fi

ls -la "$OUT_DIR" | head -20
echo "[app] OK。下一步: packaging/build_deb.sh"
