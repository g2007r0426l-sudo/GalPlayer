# -*- coding: utf-8 -*-
"""把 KRKRRenderIos.cpp 加入构建"""
import pathlib

b = pathlib.Path(r"engines/tjs2/build_base.sh")
t = b.read_text(encoding="utf-8")

if "KRKRRenderIos.cpp" not in t:
    t = t.replace(
        '# iOS 平台层实现',
        '''# iOS 软件渲染管理器（CPU 纹理 + 合成）
compile_one "$ROOT_DIR/engines/tjs2/KRKRRenderIos.cpp" "ios/KRKRRenderIos.cpp"

# iOS 平台层实现'''
    )
    b.write_text(t.replace("\r\n", "\n"), encoding="utf-8")
    print("added")
else:
    print("already")
