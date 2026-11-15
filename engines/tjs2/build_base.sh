#!/usr/bin/env bash
# =============================================================================
# KiriKiri 运行时 -> iOS 静态库（不含图形/音频/视频）
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
if [ ! -d "$CORE" ]; then
    echo "[KRKRBASE] ERROR: missing $CORE"
    exit 1
fi

SDK=$(xcrun --sdk iphoneos --show-sdk-path)
ARCH="-target arm64-apple-ios14.0 -isysroot $SDK -miphoneos-version-min=14.0"

INC="-I$CORE -I$CORE/tjs2 -I$CORE/base -I$CORE/base/win32"
INC="$INC -I$CORE/msg -I$CORE/msg/win32 -I$CORE/utils -I$CORE/utils/win32 -I$CORE/utils/encoding"
INC="$INC -I$CORE/environ -I$CORE/environ/win32 -I$CORE/environ/linux"
INC="$INC -I$CORE/visual -I$CORE/visual/win32 -I$CORE/extension -I$CORE/movie"
INC="$INC -I$CORE/sound -I$CORE/sound/win32 -I$CORE/../plugins"
INC="$INC -I$KX/platform/linux/compat -I$ROOT_DIR/engines/tjs2/iosinc"

ONIG_INC="$ROOT_DIR/engines/kirikiroid2/third_party/oniguruma/src"
if [ -f "$ONIG_INC/oniguruma.h" ]; then
    INC="$INC -I$ONIG_INC"
fi
if [ -d "$KX/third_party" ]; then
    INC="$INC -I$KX/third_party"
fi

FLAGS="-std=c++14 -O2 $ARCH -fexceptions -frtti -w -DTJS_TEXT_OUT_CRLF -D__STDC_CONSTANT_MACROS -D_7ZIP_ST -DLINUX -DKR2_IOS"

SKIP_LIST=" base/win32/FuncStubs.cpp base/7zArchive.cpp base/UtilStreams.cpp base/ZIPArchive.cpp base/win32/StorageImpl.cpp base/win32/SusieArchive.cpp msg/win32/MsgLoad.cpp msg/win32/ReadOptionDesc.cpp "

OK=0
FAIL=0
FAILED_NAMES=""

compile_one() {
    # $1 = 源文件绝对路径, $2 = 相对标识（用于日志/去重）
    local src="$1"
    local tag="$2"
    local base
    base=$(basename "$src")
    local obj="$OBJ_DIR/$(echo "$tag" | tr '/' '_').o"
    if clang++ $FLAGS $INC -c "$src" -o "$obj" 2> "$OBJ_DIR/$base.log"; then
        OK=$((OK + 1))
    else
        FAIL=$((FAIL + 1))
        FAILED_NAMES="$FAILED_NAMES $tag"
    fi
}

for d in base base/win32 msg msg/win32 utils utils/win32 utils/encoding extension; do
    dir="$CORE/$d"
    [ -d "$dir" ] || continue
    for f in "$dir"/*.cpp "$dir"/*.c; do
        [ -e "$f" ] || continue
        rel="$d/$(basename "$f")"
        case "$SKIP_LIST" in
            *" $rel "*) continue ;;
        esac
        compile_one "$f" "$rel"
    done
done

# iOS 平台层实现
compile_one "$ROOT_DIR/engines/tjs2/IOSPlatform.cpp" "ios/IOSPlatform.cpp"

echo "[KRKRBASE] ok=$OK fail=$FAIL"
for n in $FAILED_NAMES; do
    base=$(basename "$n")
    err=$(grep -m1 -E "fatal error:|error:" "$OBJ_DIR/$base.log" 2>/dev/null | head -1)
    echo "  FAIL $n :: ${err:-unknown}"
done

if [ "$OK" -gt 0 ]; then
    rm -f "$OUT"
    xcrun --sdk iphoneos ar rcs "$OUT" "$OBJ_DIR"/*.o 2>/dev/null
    xcrun --sdk iphoneos ranlib "$OUT" 2>/dev/null
    echo "[KRKRBASE] OK -> $OUT"
else
    echo "[KRKRBASE] ERROR: nothing compiled"
    exit 1
fi
