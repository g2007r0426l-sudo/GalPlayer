#!/usr/bin/env bash
# =============================================================================
# GalPlayer 全量构建: 字体 -> SDL2 -> ONScripter -> Kirikiri -> App -> .deb
# 平台: macOS（需 Xcode / cmake / ninja / xcodegen / ldid / dpkg）
#
#   brew install cmake ninja xcodegen ldid dpkg libimobiledevice
#
# 说明: KRKR 引擎（Kirikinux2）为二期能力 —— 构建失败不会中断出包，
#       .deb 将只包含主 App（ONS 引擎）；KRKR 成功则自动带上第二个 App。
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for cmd in git cmake ninja xcodegen ldid dpkg-deb xcodebuild curl python3; do
    command -v "$cmd" >/dev/null || { echo "[build] ERROR: 缺少 $cmd （brew install ...）"; exit 1; }
done

echo "==== [1/6] CJK 字体 ===="
bash "$ROOT_DIR/engines/fonts/fetch_fonts.sh"

echo "==== [2/6] SDL2 全栈 (iOS arm64) ===="
bash "$ROOT_DIR/engines/SDL2/build_ios.sh"

echo "==== [3/6] ONScripter ===="
bash "$ROOT_DIR/engines/onscripter/build_ios.sh"

echo "==== [4/6] Kirikiroid2 (Kirikiri2 核心) ===="
if [ "${SKIP_KRKR:-0}" = "1" ]; then
    echo "[build] SKIP_KRKR=1 —— 跳过 KRKR 引擎（快速出包模式）"
elif bash "$ROOT_DIR/engines/kirikiroid2/build_ios.sh"; then
    echo "[build] KRKR 引擎构建成功"
else
    echo "[build] WARNING: KRKR 引擎构建失败 —— 本次 .deb 仅含主 App（ONS），KRKR 相关功能不可用"
fi

echo "==== [5/6] App ===="
bash "$ROOT_DIR/scripts/build_app.sh"

echo "==== [6/6] 打包 .deb ===="
bash "$ROOT_DIR/packaging/build_deb.sh"

echo ""
echo "全部完成:"
ls -lh "$ROOT_DIR"/dist/*.deb
echo ""
echo "版本记录见 THIRD_PARTY_RESOLVED.md（引擎源码实际 commit）"
