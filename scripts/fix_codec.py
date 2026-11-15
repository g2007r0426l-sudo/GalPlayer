# -*- coding: utf-8 -*-
"""按 GraphicsLoaderIntf.h 真实签名重写编解码桩区块"""
import pathlib

p = pathlib.Path(r"engines/tjs2/KRKRPlatform2Ios.cpp")
s = p.read_text(encoding="utf-8")

start_marker = "// ---------------------------------------------------------------------------\n// \u56fe\u50cf\u7f16\u89e3\u7801\u6ce8\u518c\u6869"
end_marker = "// ---------------------------------------------------------------------------\n// \u7a97\u53e3\u5165\u53e3"
a = s.find(start_marker)
b = s.find(end_marker)
assert a > 0 and b > a, "markers not found"

block = '''// ---------------------------------------------------------------------------
// \u56fe\u50cf\u7f16\u89e3\u7801\u6ce8\u518c\u6869\uff08PNG/WEBP/BPG/JXR/PVRv3\uff09\u2014\u2014 \u9636\u6bb5\u4e00\u8fd4\u56de\u5931\u8d25
// \u7b7e\u540d\u4e25\u683c\u6309 GraphicsLoaderIntf.h\uff08void \u8fd4\u56de + typedef \u56de\u8c03\uff09
// \u771f\u5b9e\u89e3\u7801\u540e\u7eed\u63a5 SDL2_image\uff08IMG_Load\uff09\u6216 ImageIO
// ---------------------------------------------------------------------------
static void codecStub() {}

void TVPLoadPNG(void *formatdata, void *callbackdata, tTVPGraphicSizeCallback sizecallback,
                tTVPGraphicScanLineCallback scanlinecallback, tTVPMetaInfoPushCallback metainfopushcallback,
                tTJSBinaryStream *src, tjs_int keyidx, tTVPGraphicLoadMode mode) { codecStub(); }
void TVPLoadWEBP(void *formatdata, void *callbackdata, tTVPGraphicSizeCallback sizecallback,
                 tTVPGraphicScanLineCallback scanlinecallback, tTVPMetaInfoPushCallback metainfopushcallback,
                 tTJSBinaryStream *src, tjs_int keyidx, tTVPGraphicLoadMode mode) { codecStub(); }
void TVPLoadBPG(void *formatdata, void *callbackdata, tTVPGraphicSizeCallback sizecallback,
                tTVPGraphicScanLineCallback scanlinecallback, tTVPMetaInfoPushCallback metainfopushcallback,
                tTJSBinaryStream *src, tjs_int keyidx, tTVPGraphicLoadMode mode) { codecStub(); }
void TVPLoadJXR(void *formatdata, void *callbackdata, tTVPGraphicSizeCallback sizecallback,
                tTVPGraphicScanLineCallback scanlinecallback, tTVPMetaInfoPushCallback metainfopushcallback,
                tTJSBinaryStream *src, tjs_int keyidx, tTVPGraphicLoadMode mode) { codecStub(); }
void TVPLoadPVRv3(void *formatdata, void *callbackdata, tTVPGraphicSizeCallback sizecallback,
                  tTVPGraphicScanLineCallback scanlinecallback, tTVPMetaInfoPushCallback metainfopushcallback,
                  tTJSBinaryStream *src, tjs_int keyidx, tTVPGraphicLoadMode mode) { codecStub(); }
void TVPLoadPVRv3(tTJSBinaryStream *, const std::function<void(const ttstr &, const tTJSVariant &)> &) {}

void TVPLoadHeaderPNG(void *, tTJSBinaryStream *, iTJSDispatch2 **) {}
void TVPLoadHeaderWEBP(void *, tTJSBinaryStream *, iTJSDispatch2 **) {}
void TVPLoadHeaderBPG(void *, tTJSBinaryStream *, iTJSDispatch2 **) {}
void TVPLoadHeaderJXR(void *, tTJSBinaryStream *, iTJSDispatch2 **) {}
void TVPLoadHeaderPVRv3(void *, tTJSBinaryStream *, iTJSDispatch2 **) {}

void TVPSaveAsPNG(void *, tTJSBinaryStream *, const iTVPBaseBitmap *, const ttstr &, iTJSDispatch2 *) {}
void TVPSaveAsJXR(void *, tTJSBinaryStream *, const iTVPBaseBitmap *, const ttstr &, iTJSDispatch2 *) {}
bool TVPAcceptSaveAsPNG(void *, const ttstr &, iTJSDispatch2 **) { return false; }
bool TVPAcceptSaveAsJXR(void *, const ttstr &, iTJSDispatch2 **) { return false; }

'''

s = s[:a] + block + s[b:]
p.write_text(s, encoding="utf-8")
print("codec block rewritten")
