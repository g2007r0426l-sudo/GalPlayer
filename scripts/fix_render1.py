# -*- coding: utf-8 -*-
"""修正 KRKRRenderIos.cpp 的 tTVPBitmap 成员用法"""
import pathlib

p = pathlib.Path(r"engines/tjs2/KRKRRenderIos.cpp")
s = p.read_text(encoding="utf-8")

s = s.replace("    BitmapInfoSize = 0;\n", "")
s = s.replace("    RefCount = 1;\n", "    RefCount = 1;\n")

# 补上拷贝构造（上游声明了但我们没实现）
if "tTVPBitmap::tTVPBitmap(const tTVPBitmap &" not in s:
    s = s.replace("tTVPBitmap::~tTVPBitmap() {",
"""tTVPBitmap::tTVPBitmap(const tTVPBitmap &r) {
    Bits = nullptr;
    RefCount = 0;
    Allocate(r.GetWidth(), r.GetHeight(), r.GetBPP());
    if (Bits && r.GetBits()) {
        for (tjs_int y = 0; y < Height; ++y) {
            memcpy(GetScanLine((tjs_uint)y),
                   (const uint8_t *)r.GetBits() + (size_t)r.GetPitch() * y,
                   (size_t)PitchStep);
        }
    }
}

tTVPBitmap::~tTVPBitmap() {""", 1)

p.write_text(s, encoding="utf-8")
print("patched")
