#!/usr/bin/env bash
# =============================================================================
# GalPlayer - SDL2 for iOS (arm64) static library
#
# 优先使用 Kirikiroid2 自带的 SDL2 fork（保证 Kirikiri 渲染层与其适配的 SDL 一致）；
# 不存在时回退到上游 SDL2 2.30.x release tag。
# 产物: build/ios/lib/libSDL2.a  + build/ios/include/SDL2/
# =============================================================================
set -euo pipefail

ENGINES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT_DIR="$(cd "$ENGINES_DIR/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build/ios"
mkdir -p "$BUILD_ROOT/lib" "$BUILD_ROOT/include"

echo "[SDL2] root=$ROOT_DIR"

# ---------------------------------------------------------------------------
# 1. 选源码：Kirikiroid2 内置 fork 优先
# ---------------------------------------------------------------------------
KRKR_DIR="$ENGINES_DIR/kirikiroid2/Kirikiroid2"
SDL_SRC=""

if [ -d "$KRKR_DIR" ] && [ -f "$KRKR_DIR/SDL2/CMakeLists.txt" ]; then
    echo "[SDL2] 使用 Kirikiroid2 自带 SDL2 fork: $KRKR_DIR/SDL2"
    SDL_SRC="$KRKR_DIR/SDL2"
fi

if [ -z "$SDL_SRC" ]; then
    SDL_DIR="$ENGINES_DIR/SDL2/SDL"
    # 从新到旧尝试已知存在的 2.x release tag（均为 upstream 官方 tag）
    TAGS=("release-2.30.10" "release-2.30.9" "release-2.30.8" "release-2.30.6" "release-2.28.5" "release-2.26.5")
    if [ ! -d "$SDL_DIR/.git" ]; then
        mkdir -p "$ENGINES_DIR/SDL2"
        cloned=""
        for t in "${TAGS[@]}"; do
            echo "[SDL2] 尝试 clone SDL2 tag $t ..."
            if git clone --depth 1 --branch "$t" https://github.com/libsdl-org/SDL.git "$SDL_DIR"; then
                cloned="$t"; break
            fi
            rm -rf "$SDL_DIR"
        done
        if [ -z "$cloned" ]; then
            echo "[SDL2] ERROR: 所有已知 tag 均克隆失败。"
            echo "        手动修复: git clone https://github.com/libsdl-org/SDL.git '$SDL_DIR'"
            echo "        然后 cd '$SDL_DIR' && git checkout <2.x release tag>，再重跑本脚本。"
            exit 1
        fi
        echo "[SDL2] 已锁定 tag: $cloned"
    fi
    SDL_SRC="$SDL_DIR"
fi

# ---------------------------------------------------------------------------
# 2. CMake 构建 iOS arm64 静态库
# ---------------------------------------------------------------------------
BUILD_DIR="$ROOT_DIR/build/sdl2-ios"
cmake -S "$SDL_SRC" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DSDL_STATIC_PIC=ON \
    -DSDL_TEST=OFF -DSDL_TESTS=OFF \
    -DSDL_JOYSTICK=OFF -DSDL_HAPTIC=OFF -DSDL_POWER=OFF \
    -DSDL_RENDER=ON -DSDL_AUDIO=ON -DSDL_VIDEO=ON -DSDL_FILE=ON \
    -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/install"

cmake --build "$BUILD_DIR" -j "$(sysctl -n hw.ncpu)"

# ---------------------------------------------------------------------------
# 3. 收集产物
# ---------------------------------------------------------------------------
LIB=$(find "$BUILD_DIR" -name "libSDL2*.a" -not -name "*pic*" | head -n 1)
if [ -z "$LIB" ]; then
    echo "[SDL2] ERROR: 未找到 libSDL2.a，构建目录: $BUILD_DIR"
    find "$BUILD_DIR" -name "*.a" | head -n 20
    exit 1
fi
cp -f "$LIB" "$BUILD_ROOT/lib/libSDL2.a"

# 头文件: 必须用构建目录里 CMake 生成的 SDL_config.h（源码模板版会导致 Sint64 断言失败）
rm -rf "$BUILD_ROOT/include/SDL2"
mkdir -p "$BUILD_ROOT/include/SDL2"
if [ -d "$BUILD_DIR/include/SDL2" ]; then
    cp "$BUILD_DIR"/include/SDL2/*.h "$BUILD_ROOT/include/SDL2/" 2>/dev/null || true
fi
if [ ! -f "$BUILD_ROOT/include/SDL2/SDL_config.h" ]; then
    cp "$SDL_SRC"/include/*.h "$BUILD_ROOT/include/SDL2/" 2>/dev/null || true
fi
find "$BUILD_DIR" -name "SDL_config.h" -exec cp -f {} "$BUILD_ROOT/include/SDL2/" \; 2>/dev/null || true
echo "[SDL2] SDL_config.h 来源: $(grep -m1 'SDL_CONFIG_H_FROM\|Generated' "$BUILD_ROOT/include/SDL2/SDL_config.h" 2>/dev/null | head -c 80 || ls -la "$BUILD_ROOT/include/SDL2/SDL_config.h")"

echo "[SDL2] OK -> $BUILD_ROOT/lib/libSDL2.a"

# ---------------------------------------------------------------------------
# 3b. 安装 SDL2（供 SDL_image/ttf/mixer 的 find_package 定位）+ 构建三件套
# ---------------------------------------------------------------------------
# 手动铺设 prefix 布局（SDL_image/ttf/mixer 的 PrivateSDL2 查找需要 lib+include 齐备）
mkdir -p "$BUILD_ROOT/prefix/lib" "$BUILD_ROOT/prefix/include/SDL2"
cp -f "$BUILD_ROOT/lib/libSDL2.a" "$BUILD_ROOT/prefix/lib/" 2>/dev/null || true
cmake --install "$BUILD_DIR" --prefix "$BUILD_ROOT/prefix" > "$ROOT_DIR/build/sdl2_install.log" 2>&1 \
    && echo "[SDL2] install OK" || { echo "[SDL2] install FAILED:"; tail -5 "$ROOT_DIR/build/sdl2_install.log"; }
# 校验 SDL_config.h 是生成版（含 HAVE_STDINT_H）；否则从构建目录找最大的生成版
if ! grep -q "HAVE_STDINT_H" "$BUILD_ROOT/prefix/include/SDL2/SDL_config.h" 2>/dev/null; then
    GEN=$(find "$BUILD_DIR" -name "SDL_config.h" -size +2k 2>/dev/null | head -n 1)
    if [ -n "$GEN" ]; then cp -f "$GEN" "$BUILD_ROOT/prefix/include/SDL2/SDL_config.h"; echo "[SDL2] config 用构建目录生成版: $GEN"; fi
fi
cp -f "$BUILD_ROOT"/prefix/include/SDL2/*.h "$BUILD_ROOT/include/SDL2/" 2>/dev/null || true
if grep -q "HAVE_STDINT_H" "$BUILD_ROOT/include/SDL2/SDL_config.h" 2>/dev/null; then
    echo "[SDL2] SDL_config.h 校验: 生成版 OK"
else
    echo "[SDL2] WARNING: SDL_config.h 仍是模板版！后续编译会失败"
fi

build_sdl_ext() {
    local name="$1"; local repo="$2"; local tags="$3"; local recurse="$4"
    shift 4
    local extra_flags=("$@")
    local ext_dir="$ROOT_DIR/SDL2/SDL_$name"
    if [ ! -f "$BUILD_ROOT/lib/libSDL2_$name.a" ]; then
        if [ ! -d "$ext_dir/.git" ]; then
            rm -rf "$ext_dir"
            local cloned=""
            for t in ${tags//|/ }; do
                echo "[SDL2] clone SDL_$name @ $t ..."
                if [ "$recurse" = "yes" ]; then
                    git clone --depth 1 --recurse-submodules --branch "$t" "https://github.com/$repo.git" "$ext_dir" && cloned="$t" && break
                else
                    git clone --depth 1 --branch "$t" "https://github.com/$repo.git" "$ext_dir" && cloned="$t" && break
                fi
                rm -rf "$ext_dir"
            done
            if [ -z "$cloned" ]; then
                echo "[SDL2] WARNING: SDL_$name 拉取失败，跳过（影响: 图片/BGM 部分格式）"
                return 0
            fi
        fi
        local ext_build="$ROOT_DIR/build/sdl${name}-ios"
        cmake -S "$ext_dir" -B "$ext_build" -G Ninja \
            -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
            -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
            -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            -DCMAKE_PREFIX_PATH="$BUILD_ROOT/prefix" \
            -DSDL2_LIBRARY="$BUILD_ROOT/lib/libSDL2.a" \
            -DSDL2_INCLUDE_DIR="$BUILD_ROOT/include/SDL2" \
            -DBUILD_TESTING=OFF -DSDL2IMAGE_SAMPLES=OFF -DSDL2IMAGE_TESTS=OFF \
            -DCMAKE_INSTALL_PREFIX="$BUILD_ROOT/prefix" \
            ${extra_flags[@]+"${extra_flags[@]}"}
        cmake --build "$ext_build" -j "$(sysctl -n hw.ncpu)"
        local lib=$(find "$ext_build" -name "libSDL2_$name.a" | head -n 1)
        if [ -n "$lib" ]; then
            cp -f "$lib" "$BUILD_ROOT/lib/libSDL2_$name.a"
            [ -d "$ext_dir/include" ] && cp "$ext_dir"/include/*.h "$BUILD_ROOT/include/SDL2/" 2>/dev/null || true
            cmake --install "$ext_build" --prefix "$BUILD_ROOT/prefix" >/dev/null 2>&1 || true
            echo "[SDL2] OK -> $BUILD_ROOT/lib/libSDL2_$name.a"
        else
            echo "[SDL2] WARNING: SDL_$name 构建产物未找到，跳过"
        fi
    fi
}

# SDL_image: 关闭 ImageIO 后端（避免 CoreServices 依赖），启用内置 stb 解码器
build_sdl_ext "image" "libsdl-org/SDL_image" "release-2.6.3|release-2.8.4|release-2.8.0" "no" \
    -DSDL2IMAGE_BACKEND_IMAGEIO=OFF -DSDL2IMAGE_BACKEND_STB=ON
# SDL_ttf: freetype/harfbuzz 子模块 vendored 构建（recurse clone 已就位）
build_sdl_ext "ttf"   "libsdl-org/SDL_ttf"   "release-2.22.1|release-2.20.2|release-2.0.18" "yes" \
    -DSDL2TTF_VENDORED=ON
# SDL_mixer: 内置解码器（WAV/OGG/FLAC/MP3/MIDI 均为 in-tree）
build_sdl_ext "mixer" "libsdl-org/SDL_mixer" "release-2.8.0|release-2.6.3" "no"

# 记录版本
{
    SDL_VER=$(grep -m1 "SDL_MAJOR_VERSION\|MAJOR_VERSION" "$SDL_SRC/include/SDL_version.h" 2>/dev/null || echo "unknown")
    COMMIT=$(git -C "$SDL_SRC" rev-parse HEAD 2>/dev/null || echo "unknown")
    SRC_URL=$(git -C "$SDL_SRC" remote get-url origin 2>/dev/null || echo "local-source")
    echo "- **SDL2**: $SRC_URL @ $COMMIT (tag/branch 见 clone 日志) -> build/ios/lib/libSDL2.a"
} >> "$ROOT_DIR/THIRD_PARTY_RESOLVED.md"
