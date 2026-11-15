# -*- coding: utf-8 -*-
"""TVPCreateIStream 定义必须放在 StorageImpl.h include 之后"""
import pathlib

p = pathlib.Path(r"engines/tjs2/KRKRPlatform2Ios.cpp")
s = p.read_text(encoding="utf-8")

# 1) 删掉 include 之前的那条定义
before = 'IStream *TVPCreateIStream(TJS::tTJSBinaryStream *) { return nullptr; }\n'
s = s.replace(before, '', 1)

# 2) 在 include 之后（视频叠加注释块前）补一条
marker = '#include "StorageImpl.h"   // 真正的 IStream 类型与 TVPCreateIStream 声明在这里\n'
add = marker + '\nIStream *TVPCreateIStream(TJS::tTJSBinaryStream *) { return nullptr; }\n'
if marker in s and s.count('TVPCreateIStream(TJS::tTJSBinaryStream *)') == 1:
    s = s.replace(marker, add, 1)

p.write_text(s, encoding="utf-8")
print("reordered; count=", s.count('TVPCreateIStream(TJS::tTJSBinaryStream *)'))
