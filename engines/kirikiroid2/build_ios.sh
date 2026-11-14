#!/usr/bin/env bash
# =============================================================================
# GalPlayer - Kirikiroid2 (Kirikiri2 核心) for iOS arm64 -> libkrkr2.a
#
# 策略:
#   1. clone 上游仓库（构建时锁定实际 commit，写入 THIRD_PARTY_RESOLVED.md）
#   2. doctor 模式打印目录结构，确认布局
#   3. 自动探测:
#      - 入口 main() 所在翻译单元 -> -Dmain=krkr_entry 重命名
#      - 排除 Windows/Android 等平台目录，只编译 kirikiri2 核心
#      - 收集仓库内全部含头文件目录作为 -I（kirikiri 头文件布局扁平分散）
#   4. 任何一步失败都打印修复指引，不静默出错
#
# 环境变量:
#   KRKR_SRC_DIR   手动指定已 clone 的仓库路径
# =============================================================================
set -euo pipefail

ENGINES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT_DIR="$(cd "$ENGINES_DIR/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build/ios"
WORK="$ENGINES_DIR/kirikiroid2"
KRKR_SRC="${KRKR_SRC_DIR:-$WORK/Kirikiroid2}"
mkdir -p "$BUILD_ROOT/lib"

# ---------------------------------------------------------------------------
# 1. 拉取源码
# ---------------------------------------------------------------------------
if [ ! -d "$KRKR_SRC/.git" ]; then
    rm -rf "$KRKR_SRC"
    echo "[KRKR] clone Kirikiroid2 ..."
    git clone --depth 1 https://github.com/zeas2/Kirikiroid2.git "$KRKR_SRC" \
      || git clone --depth 1 https://github.com/kirikiroid2/kirikiroid2.git "$KRKR_SRC" \
      || { echo "[KRKR] ERROR: clone 失败。手动方案:"
           echo "  git clone https://github.com/zeas2/Kirikiroid2.git '$KRKR_SRC' 后重跑"; exit 1; }
fi
COMMIT=$(git -C "$KRKR_SRC" rev-parse HEAD)
echo "[KRKR] 源码: $KRKR_SRC @ ${COMMIT:0:12}"

# ---------------------------------------------------------------------------
# 2. doctor —— 打印布局，供排错
# ---------------------------------------------------------------------------
echo "[KRKR] ---- 顶层目录 ----"
ls -1 "$KRKR_SRC" | sed 's/^/  /'
if [ -d "$KRKR_SRC/SDL2" ]; then
    echo "[KRKR] 检测到自带 SDL2 fork: $KRKR_SRC/SDL2 （engines/SDL2/build_ios.sh 会优先使用它）"
fi

# ---------------------------------------------------------------------------
# 3. 收集编译范围
#    排除明确不可用的平台目录；Kirikiroid2 的 Android 胶水层在 project/ 下，
#    桌面 Win32 代码在含 windows.h 的目录，均排除。
# ---------------------------------------------------------------------------
EXCLUDE_PAT="(windows|win32|project/jni|/jni/|android|_win|wii|psp|darwin)"

# 3a. 头文件 include 目录
INC_DIRS=$(mktemp)
find "$KRKR_SRC" -type f \( -name '*.h' -o -name '*.hpp' \) -exec dirname {} \; | sort -u | while read -r d; do
    case "$d" in *$EXCLUDE_PAT*) continue;; esac
    echo "$d" >> "$INC_DIRS"
done
INCS=()
while read -r d; do INCS+=("-I$d"); done < "$INC_DIRS"
echo "[KRKR] include 目录数: ${#INCS[@]}"

# 自带 SDL2 fork 头文件也要能被核心找到
[ -d "$KRKR_SRC/SDL2/include" ] && INCS+=("-I$KRKR_SRC/SDL2/include")
# 本地 SDL2 / freetype 头
INCS+=("-I$BUILD_ROOT/include" "-I$BUILD_ROOT/include/SDL2" "-I$BUILD_ROOT/include/freetype2")

# 3b. 源文件
SRCS=()
while IFS= read -r f; do SRCS+=("$f"); done < <(find "$KRKR_SRC" -type f -name '*.cpp' | grep -vE "$EXCLUDE_PAT" | sort)
echo "[KRKR] 候选源文件数: ${#SRCS[@]}"
[ "${#SRCS[@]}" -gt 0 ] || { echo "[KRKR] ERROR: 没有找到任何 .cpp，仓库布局变化？检查 $KRKR_SRC"; exit 1; }

# 3c. 入口探测: 定义 main 的 TU 只保留一个
MAIN_TUS=()
for f in "${SRCS[@]}"; do
    grep -lE "(int|void)[[:space:]]+main[[:space:]]*\(" "$f" >/dev/null 2>&1 && MAIN_TUS+=("$f")
done
echo "[KRKR] 含 main 的 TU: ${#MAIN_TUS[@]}"
for f in "${MAIN_TUS[@]}"; do echo "       $(basename "$f")"; done

# ---------------------------------------------------------------------------
# 4. 编译（先试全量，失败时打印前 30 行错误 + 修复指引）
# ---------------------------------------------------------------------------
CC_BIN="xcrun -sdk iphoneos clang++"
ARCH="-arch arm64 -miphoneos-version-min=14.0"
BASE_FLAGS=(-std=c++14 -O2 $ARCH -fno-objc-arc -DSDL_STATIC=1 -DNDEBUG "${INCS[@]}")

OBJ_DIR="$WORK/obj"
rm -rf "$OBJ_DIR"; mkdir -p "$OBJ_DIR"

compile_all() {
    local objs=()
    for f in "${SRCS[@]}"; do
        local o="$OBJ_DIR/$(echo "$f" | sed "s|$KRKR_SRC/||; s|/|__|g; s|\.cpp$|.o|")"
        if ! $CC_BIN "${BASE_FLAGS[@]}" -Dmain=krkr_entry -c "$f" -o "$o" 2>"$o.err"; then
            return 1
        fi
        objs+=("$o")
    done
    # 打包
    rm -f "$BUILD_ROOT/lib/libkrkr2.a"
    xcrun -sdk iphoneos ar rcs "$BUILD_ROOT/lib/libkrkr2.a" "${objs[@]}"
    xcrun -sdk iphoneos ranlib "$BUILD_ROOT/lib/libkrkr2.a"
    return 0
}

if compile_all; then
    echo "[KRKR] OK -> $BUILD_ROOT/lib/libkrkr2.a"
else
    echo "==============================================================="
    echo "[KRKR] 编译失败。打印前 30 行首个错误:"
    FIRST_ERR=$(find "$OBJ_DIR" -name "*.err" -size +0c | head -n 1)
    head -n 30 "$FIRST_ERR" || true
    echo "==============================================================="
    echo "[KRKR] 常见修复（见 PORTING_NOTES.md）:"
    echo "  1. 平台目录误编译 —— 把目录名加进本脚本 EXCLUDE_PAT"
    echo "  2. 缺依赖头/库 —— Kirikiroid2 内置 third_party（boost/oniguruma/freetype 等）"
    echo "     若仓库顶层存在 third_party*/ 目录，执行:"
    echo "       find $KRKR_SRC/third_party* -type d | head -50  并补进 INCS"
    echo "  3. main 探测错误 —— 手动把正确的入口 TU 传给 -Dmain=krkr_entry"
    echo "  4. 若其 SDL fork 与 upstream SDL2 冲突 —— 本脚本已统一用一份 SDL2,"
    echo "     检查 engines/SDL2/build_ios.sh 是否用了 Kirikiroid2 的 fork"
    exit 1
fi

{
    echo "- **Kirikiroid2**: https://github.com/zzz-ooo/Kirikiroid2 @ $COMMIT -> build/ios/lib/libkrkr2.a"
} >> "$ROOT_DIR/THIRD_PARTY_RESOLVED.md"
