#!/usr/bin/env bash
# =============================================================================
# GalPlayer 全量构建: 字体 -> SDL2 -> ONScripter -> Kirikiri -> App -> .deb
# 平台: macOS（需 Xcode / cmake / ninja / xcodegen / ldid / dpkg）
#
#   brew install cmake ninja xcodegen ldid dpkg libimobiledevice
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 依赖自检
for cmd in git cmake ninja xcodegen ldid dpkg-deb xcodebuild curl; do
    command -v "$cmd" >/dev/null || { echo "[build] ERROR: 缺少 $cmd （brew install ...）"; exit 1; }
done

echo "==== [1/6] CJK 字体 ===="
bash "$ROOT_DIR/engines/fonts/fetch_fonts.sh"

echo "==== [2/6] SDL2 (iOS arm64) ===="
bash "$ROOT_DIR/engines/SDL2/build_ios.sh"

echo "==== [3/6] ONScripter ===="
bash "$ROOT_DIR/engines/onscripter/build_ios.sh"

echo "==== [4/6] Kirikiroid2 (Kirikiri2 核心) ===="
bash "$ROOT_DIR/engines/kirikiroid2/build_ios.sh"

echo "==== [5/6] App ===="
bash "$ROOT_DIR/scripts/build_app.sh"

echo "==== [6/6] 打包 .deb ===="
bash "$ROOT_DIR/packaging/build_deb.sh"

echo ""
echo "全部完成:"
ls -lh "$ROOT_DIR"/dist/*.deb
echo ""
echo "版本记录见 THIRD_PARTY_RESOLVED.md（引擎源码实际 commit）"
