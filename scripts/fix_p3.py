# -*- coding: utf-8 -*-
"""用 StorageImpl.h 的真 IStream 声明替换自己的前置声明"""
import pathlib

p = pathlib.Path(r"engines/tjs2/KRKRPlatform2Ios.cpp")
s = p.read_text(encoding="utf-8")

# 1) 删掉自己的 struct IStream; 前置声明，改为包含 StorageImpl.h
s = s.replace('''class tTJSNI_VideoOverlay;
class iTVPVideoOverlay;
struct IStream;
''', '''class tTJSNI_VideoOverlay;
class iTVPVideoOverlay;
#include "StorageImpl.h"   // 真正的 IStream 类型与 TVPCreateIStream 声明在这里
''')

# 2) 删掉自己那句 IStream* TVPCreateIStream（会与头文件声明冲突）
s = s.replace('IStream *TVPCreateIStream(TJS::tTJSBinaryStream *) { return nullptr; }\n\n', '')

# 3) 用头文件的类型补上定义
if "IStream *TVPCreateIStream(TJS::tTJSBinaryStream *) {" not in s and "TVPCreateIStream(TJS::tTJSBinaryStream *)" not in s.split("StorageImpl.h")[0]:
    pass
s = s.replace('''// ---------------------------------------------------------------------------
// 视频叠加（Windows MF 后端）—— iOS 无视频播放，返回失败
// ---------------------------------------------------------------------------''',
'''// ---------------------------------------------------------------------------
// 视频叠加（Windows MF 后端）—— iOS 无视频播放，返回失败
// ---------------------------------------------------------------------------
IStream *TVPCreateIStream(TJS::tTJSBinaryStream *) { return nullptr; }''', 1)

p.write_text(s, encoding="utf-8")
print("patched")
