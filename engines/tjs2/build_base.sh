#!/usr/bin/env bash
# =============================================================================
# KiriKiri base 层 -> iOS 静态库
#
# base/ 里是 KiriKiri 的运行时接口实现（Storages / System / Scripts / Plugins /
# XP3Archive / PluginIntf / ScriptMgnIntf ...），图形实现才在 visual/（依赖 cocos）。
# 所以先把 base 编通：脚本引擎 + 归档 + 宿主类能工作，画面后面自己用 CPU 画。
#
# 产物: build/ios/lib/libkrkrbase.a
# =============================================================================
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build/ios"
CORE="$ROOT_DIR/engines/kirikiroid2/Kirikinux2/src/core"
SRC="$CORE/base"
OBJ_DIR="$BUILD_ROOT/obj/krkrbase"
OUT="$BUILD_ROOT/lib/libkrkrbase.a"

mkdir -p "$BUILD_ROOT/lib" "$OBJ_DIR"
[ -d "$SRC" ] || { echo "[KRKRBASE] ERROR: 缺少 $SRC"; exit 1; }

# TJS2 头与 onig 头
TJS_INC="$CORE/tjs2"
ONIG_INC="$ROOT_DIR/engines/kirikiroid2/third_party/oniguruma/src"

SDK=$(xcrun --sdk iphoneos --show-sdk-path)
ARCH="-target arm64-apple-ios14.0 -isysroot $SDK -miphoneos-version-min=14.0"

INC=(-I"$SRC" -I"$TJS_INC" -I"$CORE/utils" -I"$CORE/base" -I"$CORE/environ" -I"$CORE"
     -I"$CORE/msg" -I"$CORE/msg/win32" -I"$CORE/visual" -I"$CORE/visual/win32"
     -I"$CORE/extension" -I"$CORE/movie" -I"$CORE/sound" -I"$CORE/sound/win32"
     -I"$CORE/base/win32" -I"$CORE/utils/win32" -I"$CORE/../plugins"
     -I"$ROOT_DIR/engines/kirikiroid2/Kirikinux2/platform/linux/compat")
[ -f "$ONIG_INC/oniguruma.h" ] && INC+=(-I"$ONIG_INC")
# third_party 根（7zip C API: 7zip/C/7z.h）
TP="$ROOT_DIR/engines/kirikiroid2/Kirikinux2/third_party"
[ -d "$TP" ] && INC+=(-I"$TP")

CXXFLAGS=(-std=c++14 -O2 $ARCH -fexceptions -frtti
          -DTJS_TEXT_OUT_CRLF -D__STDC_CONSTANT_MACROS -D_7ZIP_ST
          -DLINUX -DKR2_IOS "${INC[@]}")

FAILED=0
COUNT=0
for f in "$SRC"/*.cpp; do
    base=$(basename "$f")
    # XP3ArchiveRepack 依赖 7-Zip C++ 库，先跳过
    case "$base" in
        XP3ArchiveRepack.cpp) echo "[KRKRBASE] 跳过: $base"; continue;;
    esac
    obj="$OBJ_DIR/${base%.cpp}.o"
    if ! clang++ "${CXXFLAGS[@]}" -c "$f" -o "$obj" 2> "$OBJ_DIR/${base}.log"; then
        echo "[KRKRBASE] FAIL: $base"
        grep -E "error:" "$OBJ_DIR/${base}.log" | head -4
        FAILED=$((FAILED+1))
        continue
    fi
    COUNT=$((COUNT+1))
    echo "[KRKRBASE] CC $base"
done

if [ "$COUNT" -gt 0 ]; then
    xcrun --sdk iphoneos ar rcs "$OUT" "$OBJ_DIR"/*.o 2>/dev/null
    xcrun --sdk iphoneos ranlib "$OUT" 2>/dev/null
    echo "[KRKRBASE] OK -> $OUT ($(ls -lh "$OUT" | awk '{print $5}'), $COUNT 个文件, $FAILED 个失败)"
else
    echo "[KRKRBASE] ERROR: 没有文件编译成功"
    exit 1
fi
