# -*- coding: utf-8 -*-
"""清理重复定义：
1) 删掉 find 加的 visual/BasicDrawDevice.cpp（visual/win32 已有同名实现）
2) 从 KRKRPlatformStubs.cpp 移除已被真实现覆盖的函数
   （TVPToActualColor / TVPSet/GetGraphicCacheLimit）
"""
import pathlib

b = pathlib.Path(r"engines/tjs2/build_base.sh")
t = b.read_text(encoding="utf-8")
old = '''# 软件绘制设备（TVP 的 BasicDrawDevice：纯 CPU 合成）
BBD=$(find "$CORE/visual" -name "BasicDrawDevice.cpp" -print -quit)
if [ -n "$BBD" ]; then
    compile_one "$BBD" "visual/BasicDrawDevice.cpp"
fi

'''
if old in t:
    t = t.replace(old, '')
    print("BasicDrawDevice find-block removed")
else:
    print("find-block not found (check manually)")
b.write_text(t.replace("\r\n", "\n"), encoding="utf-8")

p = pathlib.Path(r"engines/tjs2/KRKRPlatformStubs.cpp")
s = p.read_text(encoding="utf-8")
old2 = '''// --------------------------------------------------------------------------- \u56fe\u5f62\u7f13\u5b58
static tjs_uint64 gGraphicCacheLimit = 64ull * 1024 * 1024;

void TVPSetGraphicCacheLimit(tjs_uint64 limit) { gGraphicCacheLimit = limit; }
tjs_uint64 TVPGetGraphicCacheLimit()          { return gGraphicCacheLimit; }

'''
if old2 in s:
    s = s.replace(old2, '')
    print("cache-limit stubs removed")
old3 = '''// --------------------------------------------------------------------------- \u989c\u8272
tjs_uint32 TVPToActualColor(tjs_uint32 color) { return color; }

'''
if old3 in s:
    s = s.replace(old3, '')
    print("TVPToActualColor stub removed")
p.write_text(s, encoding="utf-8")
print("done")
