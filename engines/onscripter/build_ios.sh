#!/usr/bin/env bash
# =============================================================================
# GalPlayer - ONScripter (JH 优先, 官方版兜底) for iOS arm64 -> libons.a
#
# ONScripter 系源码基于 SDL 1.2。本脚本把 sdl2_compat/ 的 include 目录放在
# 最前面，引擎源码不改即可走 SDL2。零星不兼容由 patch_ons_sources.sh 修补。
#
# 环境变量:
#   ONS_SRC_TARBALL   手动指定已下载的源码包路径（网络不通时兜底）
#   ONS_BUILD_OGG     1/0 是否构建 OGG 支持 (默认 1)
# =============================================================================
set -euo pipefail

ENGINES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT_DIR="$(cd "$ENGINES_DIR/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build/ios"
WORK="$ENGINES_DIR/onscripter"
mkdir -p "$BUILD_ROOT/lib" "$BUILD_ROOT/include"

# ---------------------------------------------------------------------------
# 1. 拉取源码（JH 优先）。全部是 ONScripter 社区的官方分发渠道。
# ---------------------------------------------------------------------------
ONS_DIR="$WORK/src"
if [ ! -d "$ONS_DIR" ]; then
    mkdir -p "$WORK/dl"
    if [ -n "${ONS_SRC_TARBALL:-}" ]; then
        echo "[ONS] 使用手动指定的源码包: $ONS_SRC_TARBALL"
        cp "$ONS_SRC_TARBALL" "$WORK/dl/ons.tar.gz"
    else
        URLS=(
            # ONScripter-JH (JH 增强版，中文 ONS 移植圈事实标准)
            "https://github.com/wamsoft/OnscripterJH/releases/latest/download/onscripter-jh.tar.gz"
            "http://onscripter.osdn.jp/onscripter_jh/onscripter-jh.tar.gz"
            # 官方 ogapee 版
            "http://onscripter.sourceforge.jp/onscripter/onscripter-20180104.tar.gz"
            "http://onscripter.sourceforge.jp/onscripter/onscripter-20150725.tar.gz"
            # GitHub 镜像
            "https://codeload.github.com/ ogapee/onscripter/tar.gz/refs/heads/master"
        )
        # 去掉镜像行里可能引入的空格（防手误）
        URLS=("${URLS[@]// /}")
        ok=""
        for u in "${URLS[@]}"; do
            echo "[ONS] 尝试下载: $u"
            if curl -fsSL --connect-timeout 20 -o "$WORK/dl/ons.tar.gz" "$u"; then
                if file "$WORK/dl/ons.tar.gz" | grep -qiE "gzip|tar"; then ok="$u"; break; fi
            fi
        done
        if [ -z "$ok" ]; then
            echo "[ONS] ERROR: 所有源均下载失败。"
            echo "  手动方案: 从 http://onscripter.osdn.jp/onscripter_jh.html 或"
            echo "            http://onscripter.sourceforge.jp/onscripter.shtml"
            echo "            下载源码包，然后: ONS_SRC_TARBALL=/path/to/xxx.tar.gz ./build_ios.sh"
            exit 1
        fi
    fi
    mkdir -p "$ONS_DIR"
    tar -xzf "$WORK/dl/ons.tar.gz" -C "$ONS_DIR" --strip-components=1
    echo "[ONS] 源码解压到 $ONS_DIR"
fi

echo "[ONS] 源码文件数: $(find "$ONS_DIR" -name '*.cpp' | wc -l | tr -d ' ')"

# ---------------------------------------------------------------------------
# 2. 修补零星 SDL1.2→SDL2 不兼容（带 grep 守卫，幂等）
# ---------------------------------------------------------------------------
bash "$WORK/patch_ons_sources.sh" "$ONS_DIR"

# ---------------------------------------------------------------------------
# 3. FreeType（ONScripter 字体渲染必需）
# ---------------------------------------------------------------------------
FT_DIR="$WORK/thirdparty/freetype"
FT_BUILD="$ROOT_DIR/build/freetype-ios"
if [ ! -d "$FT_DIR/.git" ]; then
    rm -rf "$FT_DIR"
    git clone --depth 1 --branch VER-2-13-3 https://github.com/freetype/freetype.git "$FT_DIR" \
      || git clone --depth 1 --branch VER-2-13-2 https://github.com/freetype/freetype.git "$FT_DIR" \
      || { echo "[ONS] ERROR: freetype clone 失败，请手动 clone 到 $FT_DIR"; exit 1; }
fi
if [ ! -f "$BUILD_ROOT/lib/libfreetype.a" ]; then
    cmake -S "$FT_DIR" -B "$FT_BUILD" -G Ninja \
        -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
        -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
        -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DFT_DISABLE_ZLIB=TRUE \
        -DFT_DISABLE_BZIP2=TRUE -DFT_DISABLE_PNG=TRUE -DFT_DISABLE_HARFBUZZ=TRUE -DFT_DISABLE_BROTLI=TRUE
    cmake --build "$FT_BUILD" -j "$(sysctl -n hw.ncpu)"
    FT_LIB=$(find "$FT_BUILD" -name "libfreetype.a" | head -n 1)
    [ -n "$FT_LIB" ] || { echo "[ONS] ERROR: libfreetype.a 未生成"; exit 1; }
    cp -f "$FT_LIB" "$BUILD_ROOT/lib/libfreetype.a"
    mkdir -p "$BUILD_ROOT/include/freetype2"
    cp -R "$FT_DIR/include/"* "$BUILD_ROOT/include/freetype2/"
    echo "[ONS] FreeType OK"
fi

# ---------------------------------------------------------------------------
# 4. OGG 支持（可选，失败自动跳过）
# ---------------------------------------------------------------------------
OGG_FLAGS=""
OGG_LIBS=""
OGG_INC=""
if [ "${ONS_BUILD_OGG:-1}" = "1" ]; then
    TP="$WORK/thirdparty"
    PREFIX="$BUILD_ROOT/prefix"
    mkdir -p "$TP"
    OGGD="$TP/libogg"; VORD="$TP/libvorbis"
    if [ ! -d "$OGGD/.git" ]; then git clone --branch v1.3.5 https://github.com/xiph/ogg.git "$OGGD" || true; fi
    if [ ! -d "$VORD/.git" ]; then git clone --branch v1.3.7 https://github.com/xiph/vorbis.git "$VORD" || true; fi
    if [ -f "$OGGD/CMakeLists.txt" ] && [ -f "$VORD/CMakeLists.txt" ]; then
        # libogg: 编译并安装到 prefix（vorbis 的 find_package(Ogg) 需要）
        cmake -S "$OGGD" -B "$ROOT_DIR/build/ogg-ios" -G Ninja \
            -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_ARCHITECTURES=arm64 \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_INSTALL_PREFIX="$PREFIX" -DINSTALL_DOCS=OFF >/dev/null
        cmake --build "$ROOT_DIR/build/ogg-ios" -j "$(sysctl -n hw.ncpu)" >/dev/null
        cmake --install "$ROOT_DIR/build/ogg-ios" >/dev/null || true
        # 手动铺头文件（不依赖 cmake install 规则）
        mkdir -p "$PREFIX/include/ogg"
        cp -f "$OGGD"/include/ogg/*.h "$PREFIX/include/ogg/" 2>/dev/null || true
        # libvorbis: 显式喂 ogg 库与头文件路径（FindOgg 不认 prefix 时兜底）
        cmake -S "$VORD" -B "$ROOT_DIR/build/vorbis-ios" -G Ninja \
            -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_ARCHITECTURES=arm64 \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_PREFIX_PATH="$PREFIX" -DBUILD_SHARED_LIBS=OFF \
            -DOGG_LIBRARY="$BUILD_ROOT/lib/libogg.a" -DOGG_INCLUDE_DIR="$OGGD/include" >/dev/null
        cmake --build "$ROOT_DIR/build/vorbis-ios" -j "$(sysctl -n hw.ncpu)" >/dev/null
        mkdir -p "$PREFIX/include/vorbis"
        cp -f "$VORD"/include/vorbis/*.h "$PREFIX/include/vorbis/" 2>/dev/null || true
        OGG_LIB=$(find "$ROOT_DIR/build/ogg-ios" -name "libogg.a" | head -n1)
        VOR_LIB=$(find "$ROOT_DIR/build/vorbis-ios" -name "libvorbis.a" | head -n1)
        VORF_LIB=$(find "$ROOT_DIR/build/vorbis-ios" -name "libvorbisfile.a" | head -n1)
        if [ -n "$OGG_LIB" ] && [ -n "$VOR_LIB" ]; then
            cp -f "$OGG_LIB" "$BUILD_ROOT/lib/libogg.a"
            cp -f "$VOR_LIB" "$BUILD_ROOT/lib/libvorbis.a"
            if [ -n "$VORF_LIB" ]; then cp -f "$VORF_LIB" "$BUILD_ROOT/lib/libvorbisfile.a"; fi
            OGG_FLAGS="-DUSE_OGG_VORBIS=1"
            OGG_LIBS="-lvorbisfile -lvorbis -logg"
            OGG_INC="-I$PREFIX/include"
            echo "[ONS] OGG 支持: 开启"
        fi
    else
        echo "[ONS] OGG 源码缺失，跳过 OGG 支持（影响: 部分 ONS 游戏无音乐，见 TROUBLESHOOTING.md）"
    fi
fi

# ---------------------------------------------------------------------------
# 5. 编译 ONScripter
#    -Dmain=ons_main 把引擎入口重命名，桥接层通过 SDL_UIKitRunApp 启动
# ---------------------------------------------------------------------------
COMPAT_INC="$WORK/sdl2_compat"
CC="xcrun -sdk iphoneos clang"
CXX="xcrun -sdk iphoneos clang++"
ARCH="-arch arm64 -miphoneos-version-min=14.0"
INC=(-I"$COMPAT_INC" -I"$ONS_DIR" -I"$BUILD_ROOT/include" -I"$BUILD_ROOT/include/SDL2" -I"$BUILD_ROOT/include/freetype2" $OGG_INC)
CXXFLAGS=(-std=c++14 -O2 $ARCH -fno-objc-arc \
          -DLINUX=1 -DCJK=1 -DNDEBUG $OGG_FLAGS "${INC[@]}")

# 选出"入口翻译单元"（定义 main 的那个文件），其余带 main 的工具源码排除
# vanilla master 的入口在 onscripter_main.cpp；优先匹配已知入口名
MAIN_TU=""
CANDIDATES=""
for f in "$ONS_DIR"/*.cpp; do
    if grep -lE "(int|void)[[:space:]]+main[[:space:]]*\(" "$f" >/dev/null 2>&1; then
        CANDIDATES="$CANDIDATES $f"
        echo "[ONS] 发现含 main 的源文件: $(basename "$f")"
    fi
done
for pref in onscripter_main.cpp ONScripter.cpp onscripter.cpp ONScripterJH.cpp; do
    for c in $CANDIDATES; do
        if [ "$(basename "$c")" = "$pref" ]; then MAIN_TU="$c"; break 2; fi
    done
done
if [ -z "$MAIN_TU" ] && [ -n "$CANDIDATES" ]; then
    MAIN_TU=$(echo $CANDIDATES | awk '{print $1}')
fi
if [ -z "$MAIN_TU" ] && [ -n "$CANDIDATES" ]; then
    MAIN_TU=$(echo $CANDIDATES | awk '{print $1}')
fi
if [ -z "$MAIN_TU" ]; then
    echo "[ONS] ERROR: 未找到定义 main() 的源文件，上游布局可能变化。"
    echo "  请检查 $ONS_DIR 下哪个 .cpp 含 'int main'，并把它加入下面 SOURCES 手动重编。"
    exit 1
fi
echo "[ONS] 入口 TU: $(basename "$MAIN_TU") （重命名为 ons_main）"

OUT="$BUILD_ROOT/lib/libons.a"
rm -f "$OUT"; mkdir -p "$WORK/obj"; rm -f "$WORK/obj"/*.o
OBJS=()
# 依赖外部库（avifile/lua）或属于独立工具的源码，不参与引擎编译
SKIP_RE='^(AVIWrapper|simple_aviplay|LUAHandler)\.cpp$'
for f in "$ONS_DIR"/*.cpp; do
    base=$(basename "$f")
    if grep -lE "int[[:space:]]+main[[:space:]]*\(" "$f" >/dev/null 2>&1 && [ "$f" != "$MAIN_TU" ]; then
        echo "[ONS] 跳过独立工具源（含 main）: $base"
        continue
    fi
    if echo "$base" | grep -qE "$SKIP_RE"; then
        echo "[ONS] 跳过外部依赖源: $base"
        continue
    fi
    o="$WORK/obj/${base%.cpp}.o"
    echo "[ONS] CC $base"
    $CXX "${CXXFLAGS[@]}" -Dmain=ons_main -c "$f" -o "$o"
    OBJS+=("$o")
done
# 兼容层也编进来
$CXX "${CXXFLAGS[@]}" -c "$COMPAT_INC/onsdl_compat.cpp" -o "$WORK/obj/onsdl_compat.o"
OBJS+=("$WORK/obj/onsdl_compat.o")

xcrun -sdk iphoneos ar rcs "$OUT" "${OBJS[@]}"
xcrun -sdk iphoneos ranlib "$OUT"

echo "[ONS] OK -> $OUT"
{
    COMMIT=$(git -C "$ONS_DIR" rev-parse HEAD 2>/dev/null || echo "tarball(no-git)")
    echo "- **ONScripter(-JH)**: source=$ONS_DIR commit=$COMMIT（SDL1.2源码 + sdl2_compat 兼容层编译）-> build/ios/lib/libons.a"
} >> "$ROOT_DIR/THIRD_PARTY_RESOLVED.md"
