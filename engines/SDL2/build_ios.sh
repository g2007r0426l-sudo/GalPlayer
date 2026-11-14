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

# 头文件
rm -rf "$BUILD_ROOT/include/SDL2"
mkdir -p "$BUILD_ROOT/include/SDL2"
if [ -d "$SDL_SRC/include" ]; then
    cp "$SDL_SRC"/include/*.h "$BUILD_ROOT/include/SDL2/"
    # 复制配置头（SDL_config.h 可能由 CMake 生成）
    if [ ! -f "$BUILD_ROOT/include/SDL2/SDL_config.h" ]; then
        find "$BUILD_DIR" -name "SDL_config.h" -exec cp -f {} "$BUILD_ROOT/include/SDL2/" \; || true
        cp -f "$SDL_SRC/include/SDL_config.h.default" "$BUILD_ROOT/include/SDL2/SDL_config.h" 2>/dev/null || true
    fi
fi

echo "[SDL2] OK -> $BUILD_ROOT/lib/libSDL2.a"

# 记录版本
{
    SDL_VER=$(grep -m1 "SDL_MAJOR_VERSION\|MAJOR_VERSION" "$SDL_SRC/include/SDL_version.h" 2>/dev/null || echo "unknown")
    COMMIT=$(git -C "$SDL_SRC" rev-parse HEAD 2>/dev/null || echo "unknown")
    SRC_URL=$(git -C "$SDL_SRC" remote get-url origin 2>/dev/null || echo "local-source")
    echo "- **SDL2**: $SRC_URL @ $COMMIT (tag/branch 见 clone 日志) -> build/ios/lib/libSDL2.a"
} >> "$ROOT_DIR/THIRD_PARTY_RESOLVED.md"
