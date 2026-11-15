#!/usr/bin/env bash
# =============================================================================
# KiriKiri 运行时 -> iOS 静态库（不含图形/音频）
#
# 编译：base(+win32) / msg(+win32) / utils(+win32) / extension
# 排除：visual（GL 渲染，后续用自研 CPU 渲染替代）、sound、movie、
#       environ/win32（Win32 GUI 实现）、7z/zip/unrar 归档解码器
#
# 产物: build/ios/lib/libkrkrbase.a
# =============================================================================
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build/ios"
CORE="$ROOT_DIR/engines/kirikiroid2/Kirikinux2/src/core"
KX="$ROOT_DIR/engines/kirikiroid2/Kirikinux2"
OBJ_DIR="$BUILD_ROOT/obj/krkrbase"
OUT="$BUILD_ROOT/lib/libkrkrbase.a"

mkdir -p "$BUILD_ROOT/lib" "$OBJ_DIR"
[ -d "$CORE" ] || { echo "[KRKRBASE] ERROR: missing $CORE"; exit 1; }

SDK=$(xcrun --sdk iphoneos --show-sdk-path)
ARCH="-target arm64-apple-ios14.0 -isysroot $SDK -miphoneos-version-min=14.0"

INC=(
  -I"$CORE"
  -I"$CORE/tjs2"
  -I"$CORE/base" -I"$CORE/base/win32"
  -I"$CORE/msg"  -I"$CORE/msg/win32"
  -I"$CORE/utils" -I"$CORE/utils/win32" -I"$CORE/utils/encoding"
  -I"$CORE/environ" -I"$CORE/environ/win32" -I"$CORE/environ/linux"
  -I"$CORE/visual" -I"$CORE/visual/win32"
  -I"$CORE/extension"
  -I"$CORE/movie" -I"$CORE/sound" -I"$CORE/sound/win32"
  -I"$CORE/../plugins"
  -I"$KX/platform/linux/compat"
  -I"$ROOT_DIR/engines/tjs2/iosinc"
)
ONIG_INC="$ROOT_DIR/engines/kirikiroid2/third_party/oniguruma/src"
[ -f "$ONIG_INC/oniguruma.h" ] && INC+=(-I"$ONIG_INC")
TP="$KX/third_party"
[ -d "$TP" ] && INC+=(-I"$TP")

CXXFLAGS=(-std=c++14 -O2 $ARCH -fexceptions -frtti -w
          -DTJS_TEXT_OUT_CRLF -D__STDC_CONSTANT_MACROS -D_7ZIP_ST
          -DLINUX -DKR2_IOS "${INC[@]}")

DIRS=(
  "base"
  "base/win32"
  "msg"
  "msg/win32"
  "utils"
  "utils/win32"
  "utils/encoding"
  "extension"
)

SKIP_LIST="base/win32/FuncStubs.cpp base/7zArchive.cpp base/UtilStreams.cpp base/ZIPArchive.cpp base/win32/StorageImpl.cpp base/win32/SusieArchive.cpp msg/win32/MsgLoad.cpp msg/win32/ReadOptionDesc.cpp"

is_skipped() {
    for s in $SKIP_LIST; do
        [ "$s" = "$1" ] && return 0
    done
    return 1
}

OK=0
FAIL=0
FAILED_NAMES=""

for d in "${DIRS[@]}"; do
    dir="$CORE/$d"
    [ -d "$dir" ] || continue
    for f in "$dir"/*.cpp; do
        [ -e "$f" ] || continue
        base=$(basename "$f")
        rel="$d/$base"
        is_skipped "$rel" && continue
        obj="$OBJ_DIR/$(echo "$rel" | tr '/' '_' | sed 's/\.cpp$/.o/')"
        if clang++ "${CXXFLAGS[@]}" -c "$f" -o "$obj" 2> "$OBJ_DIR/${base}.log"; then
            OK=$((OK + 1))
        else
            FAIL=$((FAIL + 1))
            FAILED_NAMES="$FAILED_NAMES $rel"
        fi
    done
done

echo "[KRKRBASE] ok=$OK fail=$FAIL"
for n in $FAILED_NAMES; do
    base=$(basename "$n")
    err=$(grep -m1 -E "fatal error:|error:" "$OBJ_DIR/${base}.log" 2>/dev/null | head -1)
    echo "  FAIL $n :: ${err:-unknown}"
done

if [ "$OK" -gt 0 ]; then
    rm -f "$OUT"
    xcrun --sdk iphoneos ar rcs "$OUT" "$OBJ_DIR"/*.o 2>/dev/null
    xcrun --sdk iphoneos ranlib "$OUT" 2>/dev/null
    echo "[KRKRBASE] OK -> $OUT ($(ls -lh "$OUT" | awk '{print $5}'))"
else
    echo "[KRKRBASE] ERROR: nothing compiled"
    exit 1
fi
