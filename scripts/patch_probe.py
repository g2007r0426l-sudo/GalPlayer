# -*- coding: utf-8 -*-
"""把 TJS2 探针从「自己 new tTJS」改成官方入口 TVPInitScriptEngine()"""
import pathlib

p = pathlib.Path(r"engines/tjs2/TJS2Probe.cpp")
s = p.read_text(encoding="utf-8")

if "TVPInitScriptEngine" not in s:
    s = s.replace('#include "tjsUtils.h"',
                  '#include "tjsUtils.h"\n#include "ScriptMgnIntf.h"', 1)

    old = ('        engine = new tTJS();\n'
           '        engine->SetConsoleOutput(&console);\n'
           '        logf("[ok] engine created\\n");')
    new = ('        // 官方入口：创建脚本引擎并注册全部原生类\n'
           '        // (Debug/Font/Layer/System/Storages/Plugins/Scripts/Bitmap ...)\n'
           '        TVPInitScriptEngine();\n'
           '        engine = TVPGetScriptEngine();\n'
           '        engine->SetConsoleOutput(&console);\n'
           '        logf("[ok] TVPInitScriptEngine done engine=%p\\n", (void*)engine);')
    assert old in s, "engine creation anchor not found"
    s = s.replace(old, new, 1)
    p.write_text(s, encoding="utf-8")
    print("probe patched")
else:
    print("already patched")
