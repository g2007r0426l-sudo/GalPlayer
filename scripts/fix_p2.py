# -*- coding: utf-8 -*-
"""KRKRPlatform2Ios.cpp 补 RenderManager.h（含 cocos 前置声明）"""
import pathlib

p = pathlib.Path(r"engines/tjs2/KRKRPlatform2Ios.cpp")
s = p.read_text(encoding="utf-8")

old = '#include "GraphicsLoaderIntf.h"\n'
new = ('#include "GraphicsLoaderIntf.h"\n'
       '\n'
       '// iTVPRenderManager 在 RenderManager.h 里；先前置声明 cocos2d::Texture2D（接口仅作指针用）\n'
       'namespace cocos2d { class Texture2D; }\n'
       '#include "RenderManager.h"\n')
if '#include "RenderManager.h"' not in s:
    s = s.replace(old, new, 1)
    p.write_text(s, encoding="utf-8")
    print("rendermanager include added")
else:
    print("already")
