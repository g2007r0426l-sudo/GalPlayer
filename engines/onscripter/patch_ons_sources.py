#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ONScripter 源码零星修补（SDL1.2 -> SDL2）—— Python 确定性替换（无 sed 方言问题）
幂等：已替换过的内容不会二次修改。修改前备份 *.orig。
用法: python3 patch_ons_sources.py <ons_source_dir>
"""
import sys, pathlib, shutil

REPLACEMENTS = [
    # (旧串, 新串, 描述)
    ("keysym.unicode", "keysym.sym", "keysym.unicode -> keysym.sym"),
    ("SDL_ACTIVEEVENT", "SDL_WINDOWEVENT", "SDL_ACTIVEEVENT -> SDL_WINDOWEVENT"),
    ("event.active.gain", "event.window.data1", "event.active.gain -> event.window.data1"),
    ("event.active.state", "event.window.data2", "event.active.state -> event.window.data2"),
    ("SDL_WarpMouse(", "SDL_WarpMouseInWindow(NULL, ", "SDL_WarpMouse -> SDL_WarpMouseInWindow"),
    ("SDL_mutexP(", "SDL_LockMutex(", "SDL_mutexP -> SDL_LockMutex"),
    ("SDL_mutexV(", "SDL_UnlockMutex(", "SDL_mutexV -> SDL_UnlockMutex"),
    ("code = CODE_CP932;", "code = CODE_UTF8;", "default encoding CP932 -> UTF-8"),
    # SDL2 键名: 小键盘数字键加下划线（SDLK_KP0 -> SDLK_KP_0）
    ("SDLK_KP0", "SDLK_KP_0", "SDLK_KP0 -> SDLK_KP_0"),
    ("SDLK_KP1", "SDLK_KP_1", "SDLK_KP1 -> SDLK_KP_1"),
    ("SDLK_KP2", "SDLK_KP_2", "SDLK_KP2 -> SDLK_KP_2"),
    ("SDLK_KP3", "SDLK_KP_3", "SDLK_KP3 -> SDLK_KP_3"),
    ("SDLK_KP4", "SDLK_KP_4", "SDLK_KP4 -> SDLK_KP_4"),
    ("SDLK_KP5", "SDLK_KP_5", "SDLK_KP5 -> SDLK_KP_5"),
    ("SDLK_KP6", "SDLK_KP_6", "SDLK_KP6 -> SDLK_KP_6"),
    ("SDLK_KP7", "SDLK_KP_7", "SDLK_KP7 -> SDLK_KP_7"),
    ("SDLK_KP8", "SDLK_KP_8", "SDLK_KP8 -> SDLK_KP_8"),
    ("SDLK_KP9", "SDLK_KP_9", "SDLK_KP9 -> SDLK_KP_9"),
    # SDL_mixer 2.8+: Mix_LoadMUS_RW 需要 freesrc 参数
    ("Mix_LoadMUS_RW(SDL_RWFromMem(buffer, length))",
     "Mix_LoadMUS_RW(SDL_RWFromMem(buffer, length), 1)",
     "Mix_LoadMUS_RW 补 freesrc 参数"),
]

CALL_REMOVALS = [
    ("SDL_EnableKeyRepeat(", "移除 SDL_EnableKeyRepeat 调用"),
    ("SDL_EnableUNICODE(", "移除 SDL_EnableUNICODE 调用"),
    ("SDL_GetWMInfo(", "移除 SDL_GetWMInfo 调用"),
]

def remove_calls(text, name):
    """删除整条调用语句（到分号为止），行首缩进保留"""
    out, idx, removed = [], 0, 0
    while True:
        p = text.find(name, idx)
        if p < 0:
            out.append(text[idx:]); break
        # 回退到行首
        bol = text.rfind("\n", 0, p) + 1
        # 找语句结尾分号
        semi = text.find(";", p)
        if semi < 0:
            out.append(text[idx:]); break
        out.append(text[idx:bol])
        removed += 1
        idx = semi + 1
        if idx < len(text) and text[idx] == "\n":
            idx += 1
    return "".join(out), removed

def main():
    if len(sys.argv) != 2:
        print("用法: patch_ons_sources.py <ons_source_dir>"); return 2
    root = pathlib.Path(sys.argv[1])
    for f in sorted(list(root.glob("*.cpp")) + list(root.glob("*.h"))):
        try:
            text = f.read_text(encoding="utf-8", errors="surrogateescape")
        except Exception:
            continue
        orig = text
        for old, new, desc in REPLACEMENTS:
            if old in text:
                text = text.replace(old, new)
                print(f"[ONS-patch] {f.name}: {desc}")
        for name, desc in CALL_REMOVALS:
            if name in text and "onsdl_compat.h" not in text:
                text, n = remove_calls(text, name)
                if n: print(f"[ONS-patch] {f.name}: {desc} ×{n}")
        if text != orig:
            backup = f.with_suffix(f.suffix + ".orig")
            if not backup.exists():
                shutil.copy2(f, backup)
            f.write_text(text, encoding="utf-8", errors="surrogateescape")
    print("[ONS-patch] 完成。orig 备份已保留（*.orig）。")
    return 0

if __name__ == "__main__":
    sys.exit(main())
