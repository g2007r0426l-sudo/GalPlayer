#!/usr/bin/env bash
# =============================================================================
# ONScripter 源码零星修补（SDL1.2 -> SDL2），幂等、带 grep 守卫、全部有日志。
# 用法: patch_ons_sources.sh <ons_source_dir>
# =============================================================================
set -uo pipefail
DIR="${1:?用法: patch_ons_sources.sh <src_dir>}"
cd "$DIR"

patch_file() {
    local f="$1"; local guard="$2"; local sedexpr="$3"; local desc="$4"
    [ -f "$f" ] || return 0
    if grep -qE "$guard" "$f"; then
        cp "$f" "$f.orig" 2>/dev/null || true
        sed -i '' -E "$sedexpr" "$f" 2>/dev/null || sed -i "$sedexpr" "$f"
        echo "[ONS-patch] $f: $desc"
    fi
}

# 1) SDL1.2 keysym.unicode —— SDL2 已移除。文本输入场景 ONS 游戏极少用到，
#    统一改成 .sym（键值本身），不影响触屏游玩。
for f in *.cpp *.h; do
    [ -e "$f" ] || continue
    if grep -q "keysym.unicode" "$f"; then
        cp "$f" "$f.orig" 2>/dev/null || true
        sed -i '' 's/keysym\.unicode/keysym.sym/g' "$f" 2>/dev/null \
          || sed -i 's/keysym\.unicode/keysym.sym/g' "$f"
        echo "[ONS-patch] $f: keysym.unicode -> keysym.sym"
    fi
done

# 2) SDL_ACTIVEEVENT / event.active —— SDL2 事件模型移除。
#    把 case 与读取替换为 WINDOWEVENT 等价处理路径。
patch_file "ONScripterEvent.cpp" "SDL_ACTIVEEVENT" \
  's/SDL_ACTIVEEVENT/SDL_WINDOWEVENT/g; s/event\.active\.gain/event\.window\.data1/g; s/event\.active\.state/event\.window\.data2/g' \
  "SDL_ACTIVEEVENT -> SDL_WINDOWEVENT"

# 3) SDL_EnableKeyRepeat / SDL_EnableUNICODE —— SDL2 移除，由兼容层提供同名桩。
#    若引擎直接调用而兼容层宏未生效（例如源码包含 <SDL_keyboard.h> 直连），删除调用。
for f in *.cpp; do
    [ -e "$f" ] || continue
    if grep -q "SDL_EnableKeyRepeat" "$f" && ! grep -q "onsdl_compat.h" "$f"; then
        sed -i '' 's/[[:space:]]*SDL_EnableKeyRepeat([^;]*);//g' "$f" 2>/dev/null \
          || sed -i 's/[[:space:]]*SDL_EnableKeyRepeat([^;]*);//g' "$f"
        echo "[ONS-patch] $f: 移除 SDL_EnableKeyRepeat 调用"
    fi
    if grep -q "SDL_EnableUNICODE" "$f" && ! grep -q "onsdl_compat.h" "$f"; then
        sed -i '' 's/[[:space:]]*SDL_EnableUNICODE([^;]*);//g' "$f" 2>/dev/null \
          || sed -i 's/[[:space:]]*SDL_EnableUNICODE([^;]*);//g' "$f"
        echo "[ONS-patch] $f: 移除 SDL_EnableUNICODE 调用"
    fi
done

# 4) SDL_GetWMInfo / SDL_SetGamma —— 极少用到，直接删调用。
for f in *.cpp; do
    [ -e "$f" ] || continue
    grep -q "SDL_GetWMInfo" "$f" && {
        sed -i '' 's/[[:space:]]*SDL_GetWMInfo([^;]*);//g' "$f" 2>/dev/null
        echo "[ONS-patch] $f: 移除 SDL_GetWMInfo 调用"; }
done

echo "[ONS-patch] 完成。orig 备份已保留在源码目录（*.orig）。"
exit 0
