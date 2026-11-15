# -*- coding: utf-8 -*-
"""FuncStubs 会引入整套 Win32 API 引用，回退；保留 UtilStreams（提供 tTVPMemoryStream）"""
import pathlib

b = pathlib.Path(r"engines/tjs2/build_base.sh")
t = b.read_text(encoding="utf-8")

if "base/win32/FuncStubs.cpp" not in t.split('SKIP_LIST="')[1].split('"')[0]:
    t = t.replace('SKIP_LIST=" ', 'SKIP_LIST=" base/win32/FuncStubs.cpp ', 1)

b.write_text(t.replace("\r\n", "\n"), encoding="utf-8")
print(t.split('SKIP_LIST="')[1].split('"')[0])
