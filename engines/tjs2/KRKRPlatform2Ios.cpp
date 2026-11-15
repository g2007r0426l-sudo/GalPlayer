// =============================================================================
// KRKRPlatform2Ios.cpp —— 第二批收尾实现（iOS）
//
// 覆盖：音频解码器 Creator（真实类，Create 返回空）、视频叠加工厂（Windows
// 后端桩）、字体系统桩、渲染管理查询、图像编解码注册桩（失败回退）、
// 窗口入口、内存流、 Storages 原生类。
//
// 说明：图像 TVPLoad* 桩返回失败 —— 真实解码下一阶段用 SDL2_image/ImageIO 接。
// =============================================================================
#include <cstdio>
#include <string>
#include <vector>
#include <functional>
#include <tuple>

#include "tjsCommHead.h"
#include "tjsString.h"
#include "tjsVariant.h"
#include "tjsNative.h"
#include "tjsUtils.h"
#include "StorageIntf.h"
#include "GraphicsLoaderIntf.h"
#include "StorageImpl.h"     // IStream 类型 + TVPCreateIStream 声明

// 声明在 StorageImpl.h（TJS_EXP_FUNC_DEF = extern）；iOS 无 MF 视频栈，返回空
IStream * TVPCreateIStream(const ttstr &name, tjs_uint32 flags) { (void)name; (void)flags; return nullptr; }
IStream * TVPCreateIStream(tTJSBinaryStream *stream) { (void)stream; return nullptr; }
#include "UtilStreams.h"

// iTVPRenderManager 在 RenderManager.h 里；先前置声明 cocos2d::Texture2D（接口仅作指针用）
namespace cocos2d { class Texture2D; }
#include "RenderManager.h"

// 音频解码器 Creator：头文件干净（只依赖 WaveIntf.h），vtable 由此 TU 发出
#include "VorbisWaveDecoder.h"
#include "FFWaveDecoder.h"

// ---------------------------------------------------------------------------
// 音频解码器（vorbis/opus/ffmpeg 后端缺库）—— Create 返回空 = 不支持该格式
// ---------------------------------------------------------------------------
tTVPWaveDecoder *VorbisWaveDecoderCreator::Create(const ttstr &, const ttstr &) { return nullptr; }
tTVPWaveDecoder *OpusWaveDecoderCreator::Create(const ttstr &, const ttstr &) { return nullptr; }
tTVPWaveDecoder *FFWaveDecoderCreator::Create(const ttstr &, const ttstr &) { return nullptr; }

// ---------------------------------------------------------------------------
// 视频叠加（Windows MF 后端）—— iOS 无视频播放，返回失败
// ---------------------------------------------------------------------------
class tTJSNI_VideoOverlay;
class iTVPVideoOverlay;

bool GetVideoOverlayObject(tTJSNI_VideoOverlay *, IStream *, const char16_t *, const char16_t *,
                           unsigned long long, iTVPVideoOverlay **) { return false; }
bool GetMFVideoOverlayObject(tTJSNI_VideoOverlay *, IStream *, const char16_t *, const char16_t *,
                             unsigned long long, iTVPVideoOverlay **) { return false; }
bool GetMixingVideoOverlayObject(tTJSNI_VideoOverlay *, IStream *, const char16_t *, const char16_t *,
                                 unsigned long long, iTVPVideoOverlay **) { return false; }
bool GetVideoLayerObject(tTJSNI_VideoOverlay *, IStream *, const char16_t *, const char16_t *,
                         unsigned long long, iTVPVideoOverlay **) { return false; }

namespace TJS { class tTJSBinaryStream; }
// ---------------------------------------------------------------------------
// 字体系统（阶段一：最小可用 —— 只报一个内置字体名）
// ---------------------------------------------------------------------------
struct KR2FontPickRequest;
struct KR2FontPickResult;

ttstr TVPGetDefaultFontName() { return ttstr("LXGWWenKai-Regular"); }
bool TVPFindFont(const ttstr &) { return true; }
void TVPGetAllFontList(std::vector<ttstr> &list) {
    list.push_back(ttstr("LXGWWenKai-Regular"));
    list.push_back(ttstr("DroidSansFallback"));
}
void TVPEnumFontsProcCollect(const ttstr &, std::vector<ttstr> &) {}
bool KR2LinuxPickFont(const KR2FontPickRequest &, KR2FontPickResult &) { return false; }
TJS::tTJSBinaryStream *TVPCreateFontStream(const ttstr &) { return nullptr; }

// ---------------------------------------------------------------------------
// 渲染管理查询
// ---------------------------------------------------------------------------
iTVPRenderManager *TVPGetSoftwareRenderManager() { return TVPGetRenderManager(); }
bool TVPIsSoftwareRenderManager() { return true; }
void TVPInitWindowOptions() {}
void TVPRelinquishCPU() {}

// ---------------------------------------------------------------------------
// 图像编解码注册桩（PNG/WEBP/BPG/JXR/PVRv3）—— 阶段一返回失败
// 签名严格按 GraphicsLoaderIntf.h（void 返回 + typedef 回调）
// 真实解码后续接 SDL2_image（IMG_Load）或 ImageIO
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

// ---------------------------------------------------------------------------
// 窗口入口（阶段一：记录；真实窗口层随后）
// ---------------------------------------------------------------------------
class tTJSNI_Window;
class tTJSNI_MenuItem;
void TVPCreateAndAddWindow(tTJSNI_Window *) {}
void TVPShowPopMenu(tTJSNI_MenuItem *) {}

// ---------------------------------------------------------------------------
// 内存流 / 临时存储
// ---------------------------------------------------------------------------
// ---- tTVPMemoryStream：声明在 UtilStreams.h，实现在被跳过的 UtilStreams.cpp ----
// 这里给完整实现（真可用的内存流），vtable 由此 TU 发出
void tTVPMemoryStream::Init() {
    Block = nullptr; Reference = false;
    Size = 0; AllocSize = 0; CurrentPos = 0;
}

tTVPMemoryStream::tTVPMemoryStream() { Init(); }

tTVPMemoryStream::tTVPMemoryStream(const void *block, tjs_uint size) {
    Init();
    if (size) {
        Block = Alloc(size);
        memcpy(Block, block, size);
        Size = size; AllocSize = size;
    }
}

tTVPMemoryStream::~tTVPMemoryStream() {
    if (Block && !Reference) Free(Block);
}

void *tTVPMemoryStream::Alloc(size_t size) { return malloc(size); }
void *tTVPMemoryStream::Realloc(void *org, size_t size) { return realloc(org, size); }
void tTVPMemoryStream::Free(void *block) { free(block); }

tjs_uint64 TJS_INTF_METHOD tTVPMemoryStream::Seek(tjs_int64 offset, tjs_int whence) {
    switch (whence) {
    case 0: CurrentPos = (tjs_uint)offset; break;                          // soFromSet
    case 1: CurrentPos = (tjs_uint)(CurrentPos + offset); break;           // soFromCurrent
    case 2: CurrentPos = (tjs_uint)(Size + offset); break;                 // soFromEnd
    }
    return CurrentPos;
}

tjs_uint TJS_INTF_METHOD tTVPMemoryStream::Read(void *buffer, tjs_uint read_size) {
    if (!Block || CurrentPos >= Size) return 0;
    if (CurrentPos + read_size > Size) read_size = Size - CurrentPos;
    memcpy(buffer, (uint8_t *)Block + CurrentPos, read_size);
    CurrentPos += read_size;
    return read_size;
}

tjs_uint TJS_INTF_METHOD tTVPMemoryStream::Write(const void *buffer, tjs_uint write_size) {
    if (!write_size) return 0;
    if (CurrentPos + write_size > AllocSize) {
        tjs_uint newsize = CurrentPos + write_size;
        if (newsize < AllocSize * 2) newsize = AllocSize * 2;
        void *nb = Realloc(Reference ? nullptr : Block, newsize);
        if (!nb) return 0;
        Block = nb; AllocSize = newsize; Reference = false;
    }
    memcpy((uint8_t *)Block + CurrentPos, buffer, write_size);
    CurrentPos += write_size;
    if (CurrentPos > Size) Size = CurrentPos;
    return write_size;
}

void TJS_INTF_METHOD tTVPMemoryStream::SetEndOfStorage() { Size = CurrentPos; }

void tTVPMemoryStream::Clear(void) {
    if (Block && !Reference) Free(Block);
    Init();
}

void tTVPMemoryStream::SetSize(tjs_uint size) {
    if (!size) { if (Block && !Reference) Free(Block); Init(); return; }
    void *nb = Realloc(Reference ? nullptr : Block, size);
    if (!nb) return;
    Block = nb; AllocSize = size;
    if (Size > size) Size = size;
    if (CurrentPos > size) CurrentPos = size;
    Reference = false;
}


tTVPLocalTempStorageHolder::~tTVPLocalTempStorageHolder() {}

// ---------------------------------------------------------------------------
// Storages 原生类（关键：脚本第一个找的对象之一）
// ---------------------------------------------------------------------------
tTJSNativeClass *TVPCreateNativeClass_Storages() {
    return new tTJSNC_Storages();
}
