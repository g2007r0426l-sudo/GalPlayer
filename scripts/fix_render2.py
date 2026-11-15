# -*- coding: utf-8 -*-
"""移除与内联定义冲突的 GetBPP/Is32bit/Is8bit；回退 UtilStreams（其引入大量 win32 符号）"""
import pathlib

p = pathlib.Path(r"engines/tjs2/KRKRRenderIos.cpp")
s = p.read_text(encoding="utf-8")

old_block = """tjs_uint tTVPBitmap::GetBPP() const {
    if (Width <= 0) return 32;
    tjs_int bpp = PitchStep / Width * 8;
    return (tjs_uint)(bpp > 0 ? bpp : 32);
}

bool tTVPBitmap::Is32bit() const { return GetBPP() == 32; }
bool tTVPBitmap::Is8bit() const  { return GetBPP() == 8; }

"""
if old_block in s:
    s = s.replace(old_block, "")
    print("removed conflicting inline-defs")

p.write_text(s, encoding="utf-8")

b = pathlib.Path(r"engines/tjs2/build_base.sh")
t = b.read_text(encoding="utf-8")
if "base/UtilStreams.cpp" not in t.split('SKIP_LIST="')[1].split('"')[0]:
    t = t.replace('SKIP_LIST=" ', 'SKIP_LIST=" base/UtilStreams.cpp ', 1)
    b.write_text(t.replace("\r\n", "\n"), encoding="utf-8")
    print("UtilStreams re-skipped")
else:
    print("UtilStreams already skipped")
