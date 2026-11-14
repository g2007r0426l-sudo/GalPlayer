#!/usr/bin/env bash
# =============================================================================
# 字体下载 —— CJK 兜底字体 DroidSansFallback.ttf（Apache License 2.0）
# 用途: 打进 App 包，运行时拷给 Kirikiri/ONS 做中文兜底渲染
# =============================================================================
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FONT_DIR="$ROOT_DIR/app/GalPlayer/Resources"
FONT="$FONT_DIR/DroidSansFallback.ttf"
mkdir -p "$FONT_DIR"

if [ -f "$FONT" ] && [ $(stat -f%z "$FONT") -gt 1000000 ]; then
    echo "[fonts] 字体已存在: $FONT"
    exit 0
fi

URLS=(
    "https://github.com/aosp-mirror/platform_frameworks_base/raw/master/data/fonts/DroidSansFallback.ttf"
    "https://github.com/aosp-mirror/platform_frameworks_base/raw/oreo-release/data/fonts/DroidSansFallback.ttf"
    "https://github.com/android/platform_frameworks_base/raw/master/data/fonts/DroidSansFallback.ttf"
)
for u in "${URLS[@]}"; do
    echo "[fonts] 尝试: $u"
    if curl -fsSL --connect-timeout 20 -o "$FONT" "$u" && [ $(stat -f%z "$FONT") -gt 1000000 ]; then
        echo "[fonts] OK: $(ls -lh "$FONT")"
        exit 0
    fi
done

rm -f "$FONT"
echo "[fonts] WARNING: 自动下载失败。请手动放置 DroidSansFallback.ttf (或 NotoSansSC-Regular.ttf"
echo "  重命名) 到: $FONT"
echo "  来源: Android AOSP data/fonts/ 或 https://fonts.google.com/noto/specimen/Noto+Sans+SC"
exit 0   # 不阻塞构建，运行期中文缺失时按 TROUBLESHOOTING.md 处理
