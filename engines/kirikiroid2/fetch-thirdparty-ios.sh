#!/usr/bin/env bash
# =============================================================================
# Kirikinux2 iOS 第三方依赖库构建
#   oniguruma (tjsRegExp)  — 源码构建
#   lz4       (RenderManager 压缩) — 源码构建
#   jpeg/png/webp/freetype — 直接使用 cocos2d-x external 的 iOS 预编译库
# 产物: build/ios/lib/*.a  +  build/ios/include/kr2deps/
# =============================================================================
set -euo pipefail

ENGINES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT_DIR="$(cd "$ENGINES_DIR/.." && pwd)"
TP="$ENGINES_DIR/kirikiroid2/Kirikinux2/third_party"
BUILD_ROOT="$ROOT_DIR/build/ios"
DEPS_INC="$BUILD_ROOT/include/kr2deps"
mkdir -p "$BUILD_ROOT/lib" "$DEPS_INC"

IOS_FLAGS="-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5"

# ---------------------------------------------------------------------------
# 1. oniguruma 6.9.x（tjsRegExp 正则引擎）
# ---------------------------------------------------------------------------
ONIG="$TP/oniguruma"
if [ ! -f "$BUILD_ROOT/lib/libonig.a" ]; then
    if [ ! -d "$ONIG/.git" ]; then
        rm -rf "$ONIG"
        git clone --depth 1 --branch v6.9.10 https://github.com/kkos/oniguruma.git "$ONIG" \
          || { echo "[kr2deps] WARNING: oniguruma 拉取失败"; }
    fi
    if [ -f "$ONIG/CMakeLists.txt" ]; then
        cmake -S "$ONIG" -B "$ROOT_DIR/build/onig-ios" -G Ninja $IOS_FLAGS \
            -DONIG_BUILD_EXECUTABLES=OFF -DENABLE_ONIG_ENCODING_UTF8=ON >/dev/null
        cmake --build "$ROOT_DIR/build/onig-ios" -j "$(sysctl -n hw.ncpu)" >/dev/null
        lib=$(find "$ROOT_DIR/build/onig-ios" -name "libonig.a" | head -n1)
        [ -n "$lib" ] && { cp -f "$lib" "$BUILD_ROOT/lib/libonig.a"; echo "[kr2deps] oniguruma OK"; }
        mkdir -p "$DEPS_INC" && cp "$ONIG"/src/oniguruma.h "$DEPS_INC/" 2>/dev/null || true
    fi
fi

# ---------------------------------------------------------------------------
# 2. lz4（RenderManager 状态压缩）
# ---------------------------------------------------------------------------
LZ4="$TP/lz4"
if [ ! -f "$BUILD_ROOT/lib/liblz4.a" ]; then
    if [ ! -d "$LZ4/.git" ]; then
        rm -rf "$LZ4"
        git clone --depth 1 --branch v1.9.4 https://github.com/lz4/lz4.git "$LZ4" \
          || { echo "[kr2deps] WARNING: lz4 拉取失败"; }
    fi
    if [ -f "$LZ4/lib/lz4.c" ]; then
        # lz4 是纯 C 小库，直接编源文件
        mkdir -p "$ROOT_DIR/build/lz4-ios"
        SRCS=("$LZ4/lib/lz4.c" "$LZ4/lib/lz4frame.c" "$LZ4/lib/lz4hc.c" "$LZ4/lib/xxhash.c")
        OBJS=()
        for s in "${SRCS[@]}"; do
            o="$ROOT_DIR/build/lz4-ios/$(basename "$s" .c).o"
            xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=14.0 -O2 -DNDEBUG \
                -I"$LZ4/lib" -c "$s" -o "$o" && OBJS+=("$o")
        done
        [ ${#OBJS[@]} -gt 0 ] && xcrun -sdk iphoneos ar rcs "$BUILD_ROOT/lib/liblz4.a" "${OBJS[@]}" \
            && xcrun -sdk iphoneos ranlib "$BUILD_ROOT/lib/liblz4.a" \
            && echo "[kr2deps] lz4 OK"
        mkdir -p "$DEPS_INC/lz4" && cp "$LZ4"/lib/*.h "$DEPS_INC/lz4/" 2>/dev/null || true
    fi
fi

# ---------------------------------------------------------------------------
# 3. cocos external iOS 预编译库（jpeg/png/webp/freetype）
#    目录形态: external/<lib>/prebuilt/ios/*.a  +  external/<lib>/include/ios/
# ---------------------------------------------------------------------------
CX="$TP/cocos2d-x/external"
copy_prebuilt() {
    local name="$1" libname="$2"
    local prebuilt=$(find "$CX/$name/prebuilt/ios" -name "$libname" 2>/dev/null | head -n1)
    if [ -n "$prebuilt" ]; then
        cp -f "$prebuilt" "$BUILD_ROOT/lib/$libname"
        if [ -d "$CX/$name/include/ios" ]; then
            mkdir -p "$DEPS_INC/$name" && cp -R "$CX/$name/include/ios/"* "$DEPS_INC/$name/" 2>/dev/null || true
        elif [ -d "$CX/$name/include" ]; then
            mkdir -p "$DEPS_INC/$name" && cp -R "$CX/$name/include/"* "$DEPS_INC/$name/" 2>/dev/null || true
        fi
        echo "[kr2deps] $name: 预编译库就位"
    else
        echo "[kr2deps] WARNING: $name 预编译库未找到（$CX/$name/prebuilt/ios）"
    fi
}
copy_prebuilt "jpeg"     "libjpeg.a"
copy_prebuilt "png"      "libpng.a"
copy_prebuilt "webp"     "libwebp.a"
copy_prebuilt "freetype2" "libfreetype.a"

echo "[kr2deps] 完成。库清单:"
ls -la "$BUILD_ROOT/lib/" | grep -E "onig|lz4|jpeg|png|webp" || true
