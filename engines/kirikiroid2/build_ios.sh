#!/usr/bin/env bash
# =============================================================================
# GalPlayer - Kirikinux2 (Kirikiroid2 引擎的 Linux/SDL2 移植) → iOS 构建脚本 v2
#
# 方案: 以 Comet387/Kirikinux2 为基底（Kirikiroid2 引擎 + Linux 平台层 + CMake），
#       注入 platform/ios 宿主（ios_host/），用 iOS 工具链编译为静态库集合。
#       App 目标 Kirikinux2（com.yg.kirikinux2）由 xcodegen 双目标工程承载。
#
# 产物:
#   build/ios/lib/libkrkr2core.a / libkrkr2plugin.a / libkrkr2plugin_ext.a / libcocos2d.a
#   build/krkr-resources/   （引擎自带 UI 的 Resources，打包进 Kirikinux2.app）
#
# 环境变量:
#   KX_SRC_DIR   手动指定 Kirikinux2 源码树
#   KR2_SKIP_BUILD=1   只准备源码不编译（调试用）
# =============================================================================
set -euo pipefail

ENGINES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT_DIR="$(cd "$ENGINES_DIR/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build/ios"
WORK="$ENGINES_DIR/kirikiroid2"
KX_SRC="${KX_SRC_DIR:-$WORK/Kirikinux2}"
TP="$KX_SRC/third_party"
IOS_HOST="$WORK/ios_host"
KRKR_BUILD="$ROOT_DIR/build/krkr-ios"
mkdir -p "$BUILD_ROOT/lib"

# ---------------------------------------------------------------------------
# 0. macOS sha256sum 兼容垫片（fetch-thirdparty.sh 需要 GNU sha256sum）
# ---------------------------------------------------------------------------
SHIM="$WORK/shim"
mkdir -p "$SHIM"
cat > "$SHIM/sha256sum" <<'EOF'
#!/bin/bash
# GNU sha256sum 兼容: 支持 -c --status 与无参数输出
if [ "$1" = "-c" ]; then
    shift; [ "${1:-}" = "--status" ] && shift
    exec shasum -a 256 -c --status "$@" 2>/dev/null || shasum -a 256 -c "$@"
fi
exec shasum -a 256 "$@"
EOF
chmod +x "$SHIM/sha256sum"
export PATH="$SHIM:$PATH"

# ---------------------------------------------------------------------------
# 1. Kirikinux2 源码树
# ---------------------------------------------------------------------------
if [ ! -d "$KX_SRC/.git" ]; then
    rm -rf "$KX_SRC"
    echo "[KRKR] clone Kirikinux2 ..."
    git clone --depth 1 https://github.com/Comet387/Kirikinux2.git "$KX_SRC" \
      || { echo "[KRKR] ERROR: clone 失败，手动: git clone https://github.com/Comet387/Kirikinux2.git '$KX_SRC'"; exit 1; }
fi
KX_COMMIT=$(git -C "$KX_SRC" rev-parse HEAD)
echo "[KRKR] Kirikinux2 @ ${KX_COMMIT:0:12}"

# ---------------------------------------------------------------------------
# 2. 第三方依赖（cocos2d-x 3.17.2 + external + p7zip；blend2d/unrar 可选）
#    fetch-thirdparty.sh 在 macOS 下个别环节可能失败（unrar 源站等），容错继续
# ---------------------------------------------------------------------------
if [ ! -d "$TP/cocos2d-x/cocos" ]; then
    echo "[KRKR] fetch-thirdparty ..."
    export KR2_THIRD_PARTY="$TP"
    export KR2_WITH_BLEND2D=0
    bash "$KX_SRC/scripts/linux/fetch-thirdparty.sh" || echo "[KRKR] WARNING: fetch-thirdparty 部分失败，继续（CMake 阶段会报缺什么）"
fi
[ -f "$TP/cocos2d-x/cocos/cocos2d.h" ] || { echo "[KRKR] ERROR: cocos2d-x 未就绪"; exit 1; }

# ---------------------------------------------------------------------------
# 3. cocos2d-x API 补丁（Kirikinux2 自带，幂等）
# ---------------------------------------------------------------------------
echo "[KRKR] patch cocos2d-x ..."
python3 "$KX_SRC/scripts/linux/patch-cocos2dx.py" "$TP/cocos2d-x" || echo "[KRKR] WARNING: cocos patch 部分失败（iOS 分支容错）"

# cocos 3.17.2 用 CMAKE_SYSTEM_NAME 判平台; iOS 交叉构建时值为 "iOS" 而非 "Darwin"
python3 - "$TP/cocos2d-x/cmake/Modules/CocosConfigDefine.cmake" <<'PYEOF'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
if not p.exists():
    print("[KRKR] WARN: CocosConfigDefine.cmake 不存在"); sys.exit(0)
s = p.read_text(encoding="utf-8", errors="surrogateescape")
if 'MATCHES "Darwin"' in s:
    s = s.replace('MATCHES "Darwin"', 'MATCHES "Darwin|iOS"')
    p.write_text(s, encoding="utf-8", errors="surrogateescape")
    print("[KRKR] CocosConfigDefine: 增加 iOS 平台识别")
else:
    print("[KRKR] CocosConfigDefine: 已是 iOS 兼容版")
PYEOF

# ---------------------------------------------------------------------------
# 4. 注入 iOS 宿主 + iOS 构建清单 + iOS 依赖库（oniguruma/lz4/cocos 预编译）
# ---------------------------------------------------------------------------
mkdir -p "$KX_SRC/platform/ios/compat"
cp -f "$IOS_HOST/IOSMain.mm" "$IOS_HOST/IOSUtils.cpp" "$IOS_HOST/KR2IOSStubs.cpp" "$KX_SRC/platform/ios/"
cp -f "$IOS_HOST/CMakeLists.ios" "$KX_SRC/CMakeLists.txt"
bash "$WORK/fetch-thirdparty-ios.sh" || echo "[KRKR] WARNING: iOS 依赖库部分失败，CMake 阶段会报缺什么"

# ---------------------------------------------------------------------------
# 5. CMake iOS 构建
# ---------------------------------------------------------------------------
if [ "${KR2_SKIP_BUILD:-0}" != "1" ]; then
    rm -rf "$KRKR_BUILD"
    # 用 iOS 清单替换顶层 CMakeLists（原 Linux 版备份为 CMakeLists.linux.bak）
    if [ ! -f "$KX_SRC/CMakeLists.linux.bak" ]; then
        cp -f "$KX_SRC/CMakeLists.txt" "$KX_SRC/CMakeLists.linux.bak"
    fi
    cp -f "$IOS_HOST/CMakeLists.ios" "$KX_SRC/CMakeLists.txt"
    cmake -S "$KX_SRC" -B "$KRKR_BUILD" -G Ninja \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_SYSROOT=iphoneos \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DKR2_ROOT="$KX_SRC" \
        -DKR2_COCOS2DX_ROOT="$TP/cocos2d-x" \
        -DKR2_THIRD_PARTY="$TP" \
        -DKR2_WITH_BLEND2D=0 \
        -DKR2_WITH_JXR=0 \
        -DIOS=ON
    cmake --build "$KRKR_BUILD" -j "$(sysctl -n hw.ncpu)"

    for lib in libkrkr2core.a libkrkr2plugin.a libkrkr2plugin_ext.a libcocos2d.a; do
        found=$(find "$KRKR_BUILD" -name "$lib" | head -n 1)
        [ -n "$found" ] && cp -f "$found" "$BUILD_ROOT/lib/$lib"
    done

    # 引擎自带 UI 的资源
    rm -rf "$ROOT_DIR/build/krkr-resources"
    mkdir -p "$ROOT_DIR/build/krkr-resources"
    if [ -d "$KX_SRC/cocos/kr2/Resources" ]; then
        cp -R "$KX_SRC/cocos/kr2/Resources/"* "$ROOT_DIR/build/krkr-resources/" 2>/dev/null || true
    fi
    if [ -d "$KX_SRC/cocos/kr2" ]; then
        for d in cocosstudio fonts shader res; do
            [ -d "$KX_SRC/cocos/kr2/$d" ] && cp -R "$KX_SRC/cocos/kr2/$d" "$ROOT_DIR/build/krkr-resources/" || true
        done
    fi

    {
        echo "- **Kirikinux2 (Kirikiroid2 引擎 iOS 移植)**: https://github.com/Comet387/Kirikinux2 @ $KX_COMMIT"
        echo "  cocos2d-x: 3.17.2 (官方 tag, 已应用 scripts/linux/patch-cocos2dx.py) -> build/ios/lib/"
    } >> "$ROOT_DIR/THIRD_PARTY_RESOLVED.md"
    echo "[KRKR] OK"
fi
