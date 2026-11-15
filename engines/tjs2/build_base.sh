#!/usr/bin/env bash
# =============================================================================
# KiriKiri 运行时 -> iOS 静态库（不含图形/音频）
#
# 编译范围：base(+win32) / msg(+win32) / utils(+win32) / environ(+win32+linux) / tjs2 宿主接口
# 排除：visual（GL 渲染，后面用自研 CPU 渲染替代）、sound（音频）、movie（视频）
#
# 产物: build/ios/lib/libkrkrbase.a
#   失败的单个文件会列出来，但不阻塞其它文件（便于逐步攻克）
# =============================================================================
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build/ios"
CORE="$ROOT_DIR/engines/kirikiroid2/Kirikinux2/src/core"
KX="$ROOT_DIR/engines/kirikiroid2/Kirikinux2"
OBJ_DIR="$BUILD_ROOT/obj/krkrbase"
OUT="$BUILD_ROOT/lib/libkrkrbase.a"

mkdir -p "$BUILD_ROOT/lib" "$OBJ_DIR"
[ -d "$CORE" ] || { echo "[KRKRBASE] ERROR: 缺少 $CORE"; exit 1; }

SDK=$(xcrun --sdk iphoneos --show-sdk-path)
ARCH="-target arm64-apple-ios14.0 -isysroot $SDK -miphoneos-version-min=14.0"

INC=(-I"$CORE" -I"$CORE/tjs2" -I"$CORE/base" -I"$CORE/base/win32" -I"$CORE/msg" -I"$CORE/msg/win32"
     -I"$CORE/utils" -I"$CORE/utils/win32" -I"$CORE/utils/encoding"
     -I"$CORE/environ" -I"$CORE/environ/win32" -I"$CORE/environ/linux"
     -I"$CORE/visual" -I"$CORE/visual/win32" -I"$CORE/extension" -I"$CORE/movie"
     -I"$CORE/sound" -I"$CORE/sound/win32" -I"$CORE/../plugins"
     -I"$KX/platform/linux/compat" -I"$ROOT_DIR/engines/tjs2/iosinc")
ONIG_INC="$ROOT_DIR/engines/kirikiroid2/third_party/oniguruma/src"
[ -f "$ONIG_INC/oniguruma.h" ] && INC+=(-I"$ONIG_INC")
TP="$KX/third_party"
[ -d "$TP" ] && INC+=(-I"$TP")

CXXFLAGS=(-std=c++14 -O2 $ARCH -fexceptions -frtti -w
          -DTJS_TEXT_OUT_CRLF -D__STDC_CONSTANT_MACROS -D_7ZIP_ST
          -DLINUX -DKR2_IOS "${INC[@]}")

# 需要编译的目录（相对 CORE）
DIRS=(
  "base"
  "base/win32"
  "msg"
  "msg/win32"
  "utils"
  "utils/win32"
  "utils/encoding"
  "environ"
  "environ/win32"
  "environ/linux"
  "extension"
)

OK=0; FAIL=0
FAILED_NAMES=""
for d in "${DIRS[@]}"; do
    dir="$CORE/$d"
    [ -d "$dir" ] || continue
    for f in "$dir"/*.cpp; do
        [ -e "$f" ] || continue
        base=$(basename "$f")
        case "$d/$base" in
            base/win32/FuncStubs.cpp) continue ;;
        esac
        obj="$OBJ_DIR/${d//\//_}_${base%.cpp}.o"
        if clang++ "${CXXFLAGS[@]}" -c "$f" -o "$obj" 2> "$OBJ_DIR/${base}.log"; then
            OK=$((OK+1))
        else
            FAIL=$((FAIL+1))
            FAILED_NAMES="$FAILED_NAMES $d/$base"
        fi
    done
done

echo "[KRKRBASE] 成功 $OK 个，失败 $FAIL 个"
if [ "$FAIL" -gt 0 ]; then
    for n in $FAILED_NAMES; do
        base=$(basename "$n")
        err=$(grep -m1 -E "fatal error:|error:" "$OBJ_DIR/${base}.log" 2>/dev/null | head -1)
        echo "  FAIL $n :: ${err:-unknown}"
    done
fi

if [ "$OK" -gt 0 ]; then
    rm -f "$OUT"
    xcrun --sdk iphoneos ar rcs "$OUT" "$OBJ_DIR"/*.o 2>/dev/null
    xcrun --sdk iphoneos ranlib "$OUT" 2>/dev/null
    echo "[KRKRBASE] OK -> $OUT ($(ls -lh "$OUT" | awk '{print $5}'))"
else
    echo "[KRKRBASE] ERROR: 没有文件编译成功"
    exit 1
fi
