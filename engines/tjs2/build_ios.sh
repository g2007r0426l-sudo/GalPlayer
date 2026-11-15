#!/usr/bin/env bash
# =============================================================================
# TJS2 脚本引擎 -> iOS 静态库
#
# TJS2 是 KiriKiri 的脚本 VM（80 个源文件，零 cocos / 零 GL 依赖），
# 是整个 KRKR 移植的地基：先把它单独编通，再加宿主层与渲染层。
#
#   engines/kirikiroid2/Kirikinux2/src/core/tjs2/*.cpp  ->  build/ios/lib/libtjs2.a
#
# 用法: engines/tjs2/build_ios.sh
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build/ios"
SRC_ROOT="$ROOT_DIR/engines/kirikiroid2/Kirikinux2/src/core/tjs2"
OUT="$BUILD_ROOT/lib/libtjs2.a"
OBJ_DIR="$BUILD_ROOT/obj/tjs2"

mkdir -p "$BUILD_ROOT/lib" "$OBJ_DIR"

# ---- 1. 源码就位（复用 kirikiroid2 脚本的 clone，没有就自己拉） ----
if [ ! -d "$SRC_ROOT" ]; then
    echo "[TJS2] 源码缺失，克隆 Kirikinux2 ..."
    KX="$ROOT_DIR/engines/kirikiroid2/Kirikinux2"
    if [ ! -d "$KX/.git" ]; then
        git clone --depth 1 https://github.com/Comet387/Kirikinux2.git "$KX"
    fi
fi
[ -d "$SRC_ROOT" ] || { echo "[TJS2] ERROR: 找不到 $SRC_ROOT"; exit 1; }

if [ -f "$OUT" ]; then
    echo "[TJS2] 已存在: $OUT"
    exit 0
fi

# ---- 2. 编译 ----
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
ARCH="-target arm64-apple-ios14.0 -isysroot $SDK -miphoneos-version-min=14.0"

CXXFLAGS=(-std=c++14 -O2 $ARCH -fno-exceptions -fno-rtti \
          -DTJS_TEXT_OUT_CRLF -D__STDC_CONSTANT_MACROS \
          -I"$SRC_ROOT")

# 排除需要宿主/图形环境的文件（保持 VM 纯净）
SKIP_RE='tjsDate\.cpp|tjsRandomGenerator\.cpp'

COUNT=0
for f in "$SRC_ROOT"/*.cpp; do
    base=$(basename "$f")
    if echo "$base" | grep -qE "$SKIP_RE"; then
        echo "[TJS2] 跳过: $base"
        continue
    fi
    obj="$OBJ_DIR/${base%.cpp}.o"
    clang++ "${CXXFLAGS[@]}" -c "$f" -o "$obj" 2> "$OBJ_DIR/${base}.log" || {
        echo "[TJS2] FAIL: $base"
        sed -n '1,25p' "$OBJ_DIR/${base}.log"
        exit 1
    }
    COUNT=$((COUNT+1))
    echo "[TJS2] CC $base ($COUNT)"
done

xcrun --sdk iphoneos ar rcs "$OUT" "$OBJ_DIR"/*.o
xcrun --sdk iphoneos ranlib "$OUT"
echo "[TJS2] OK -> $OUT ($(ls -lh "$OUT" | awk '{print $5}'), $COUNT 个源文件)"
