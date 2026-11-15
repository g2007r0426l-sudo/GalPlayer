# -*- coding: utf-8 -*-
"""探针收尾：引擎由运行时管理，不再手动 Shutdown/Release"""
import pathlib

p = pathlib.Path(r"engines/tjs2/TJS2Probe.cpp")
s = p.read_text(encoding="utf-8")

old = ('        engine->Shutdown();\n'
       '        engine->Release();\n'
       '        engine = nullptr;\n')
new = ('        // 引擎归运行时管理，这里不 Shutdown/Release\n')
if old in s:
    s = s.replace(old, new, 1)
    p.write_text(s, encoding="utf-8")
    print("tail patched")
else:
    print("tail already ok")
