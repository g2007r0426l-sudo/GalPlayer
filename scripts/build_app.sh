#!/usr/bin/env bash
# =============================================================================
# 编译 App（xcodegen 生成工程 -> xcodebuild 出 .app）
# 前置: brew install xcodegen；engines 构建产物已在 build/ios/lib/
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
BUILD_ROOT="$ROOT_DIR/build/ios"

# 引擎库检查（缺失给出明确指引）
for lib in libSDL2.a libons.a libkrkr2.a libfreetype.a; do
    if [ ! -f "$BUILD_ROOT/lib/$lib" ]; then
        echo "[app] ERROR: 缺少 $BUILD_ROOT/lib/$lib"
        echo "  先依次运行:"
        echo "    engines/fonts/fetch_fonts.sh"
        echo "    engines/SDL2/build_ios.sh"
        echo "    engines/onscripter/build_ios.sh"
        echo "    engines/kirikiroid2/build_ios.sh"
        exit 1
    fi
done

command -v xcodegen >/dev/null || { echo "[app] ERROR: brew install xcodegen"; exit 1; }
command -v xcodebuild >/dev/null || { echo "[app] ERROR: 需要 macOS + Xcode"; exit 1; }

cd "$APP_DIR"
xcodegen generate

echo "[app] xcodebuild (iphoneos arm64) ..."
xcodebuild \
    -project GalPlayer.xcodeproj \
    -scheme GalPlayer \
    -configuration Release \
    -sdk iphoneos \
    -destination "generic/platform=iOS" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
    CONFIGURATION_BUILD_DIR="$ROOT_DIR/build/app" \
    build

OUT="$ROOT_DIR/build/app/GalPlayer.app"
[ -d "$OUT" ] || OUT=$(find "$ROOT_DIR/build/app" -maxdepth 1 -name "*.app" | head -1)
[ -d "$OUT" ] || { echo "[app] ERROR: 构建产物未找到"; exit 1; }

echo "[app] OK -> $OUT"
echo "  下一步: packaging/build_deb.sh"
