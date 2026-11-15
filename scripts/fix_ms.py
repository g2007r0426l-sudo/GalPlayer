# -*- coding: utf-8 -*-
"""MemoryStream 用真头文件；LocalTempStorageHolder 视声明位置处理"""
import pathlib, re

p = pathlib.Path(r"engines/tjs2/KRKRPlatform2Ios.cpp")
s = p.read_text(encoding="utf-8")

# 1) 删掉我自己的 tTVPMemoryStream 最小类定义（真类在 UtilStreams.h）
old_ms = '''class tTVPMemoryStream {
public:
    tTVPMemoryStream();
};
tTVPMemoryStream::tTVPMemoryStream() {}
'''
if old_ms in s:
    s = s.replace(old_ms, 'tTVPMemoryStream::tTVPMemoryStream() {}\n', 1)
    print("MemoryStream class def removed, ctor kept")

# 2) 包含 UtilStreams.h（tTVPMemoryStream 真声明）
if '#include "UtilStreams.h"' not in s:
    s = s.replace('#include "GraphicsLoaderIntf.h"',
                  '#include "GraphicsLoaderIntf.h"\n#include "UtilStreams.h"', 1)
    print("UtilStreams.h included")

p.write_text(s, encoding="utf-8")
print("done")
