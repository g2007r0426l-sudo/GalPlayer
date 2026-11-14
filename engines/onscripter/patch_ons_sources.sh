#!/usr/bin/env bash
# =============================================================================
# ONScripter 源码零星修补（SDL1.2 -> SDL2），幂等、带 grep 守卫、全部有日志。
# 用法: patch_ons_sources.sh <ons_source_dir>
# =============================================================================
set -uo pipefail
DIR="${1:?用法: patch_ons_sources.sh <src_dir>}"
cd "$DIR"

patch_all() {
    local guard="$1"; local sedexpr="$2"; local desc="$3"
    for f in *.cpp *.h; do
        [ -e "$f" ] || continue
        if grep -qE "$guard" "$f"; then
            cp "$f" "$f.orig" 2>/dev/null || true
            sed -i '' -E "$sedexpr" "$f" 2>/dev/null || sed -i "$sedexpr" "$f"
            echo "[ONS-patch] $f: $desc"
        fi
    done
}

# 1) SDL1.2 keysym.unicode —— SDL2 已移除（文本输入场景极少用到）
patch_all "keysym\.unicode" 's/keysym\.unicode/keysym.sym/g' "keysym.unicode -> keysym.sym"

# 2) SDL_ACTIVEEVENT / event.active.* —— SDL2 事件模型移除（映射到 WINDOWEVENT）
patch_all "SDL_ACTIVEEVENT" \
  's/SDL_ACTIVEEVENT/SDL_WINDOWEVENT/g; s/event\.active\.gain/event\.window\.data1/g; s/event\.active\.state/event\.window\.data2/g' \
  "SDL_ACTIVEEVENT -> SDL_WINDOWEVENT"

# 3) SDL_EnableKeyRepeat / SDL_EnableUNICODE —— SDL2 移除（兼容层提供桩，直连调用删除）
patch_all "SDL_EnableKeyRepeat" 's/[[:space:]]*SDL_EnableKeyRepeat([^;]*);//g' "移除 SDL_EnableKeyRepeat"
patch_all "SDL_EnableUNICODE"   's/[[:space:]]*SDL_EnableUNICODE([^;]*);//g'   "移除 SDL_EnableUNICODE"

# 4) SDL_GetWMInfo —— 极少用到，删除调用
patch_all "SDL_GetWMInfo" 's/[[:space:]]*SDL_GetWMInfo([^;]*);//g' "移除 SDL_GetWMInfo"

echo "[ONS-patch] 完成。orig 备份已保留在源码目录（*.orig）。"
exit 0
