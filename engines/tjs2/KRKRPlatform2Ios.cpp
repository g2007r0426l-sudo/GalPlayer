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
#include "StorageImpl.h"   // 真正的 IStream 类型与 TVPCreateIStream 声明在这里

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
// 真实解码后续接 SDL2_image（IMG_Load）或 ImageIO
// ---------------------------------------------------------------------------
static bool codecStub() { return false; }

bool TVPLoadPNG(void *, void *,
                int (*)(void *, unsigned int, unsigned int, tTVPGraphicPixelFormat),
                void *(*)(void *, int),
                void (*)(void *, const ttstr &, const ttstr &),
                tTJSBinaryStream *, int, tTVPGraphicLoadMode) { return codecStub(); }
bool TVPLoadWEBP(void *, void *,
                 int (*)(void *, unsigned int, unsigned int, tTVPGraphicPixelFormat),
                 void *(*)(void *, int),
                 void (*)(void *, const ttstr &, const ttstr &),
                 tTJSBinaryStream *, int, tTVPGraphicLoadMode) { return codecStub(); }
bool TVPLoadBPG(void *, void *,
                int (*)(void *, unsigned int, unsigned int, tTVPGraphicPixelFormat),
                void *(*)(void *, int),
                void (*)(void *, const ttstr &, const ttstr &),
                tTJSBinaryStream *, int, tTVPGraphicLoadMode) { return codecStub(); }
bool TVPLoadJXR(void *, void *,
                int (*)(void *, unsigned int, unsigned int, tTVPGraphicPixelFormat),
                void *(*)(void *, int),
                void (*)(void *, const ttstr &, const ttstr &),
                tTJSBinaryStream *, int, tTVPGraphicLoadMode) { return codecStub(); }
bool TVPLoadPVRv3(void *, void *,
                  int (*)(void *, unsigned int, unsigned int, tTVPGraphicPixelFormat),
                  void *(*)(void *, int),
                  void (*)(void *, const ttstr &, const ttstr &),
                  tTJSBinaryStream *, int, tTVPGraphicLoadMode) { return codecStub(); }
void TVPLoadPVRv3(tTJSBinaryStream *, const std::function<void(const ttstr &, const tTJSVariant &)> &) {}

bool TVPLoadHeaderPNG(void *, tTJSBinaryStream *, iTJSDispatch2 **) { return false; }
bool TVPLoadHeaderWEBP(void *, tTJSBinaryStream *, iTJSDispatch2 **) { return false; }
bool TVPLoadHeaderBPG(void *, tTJSBinaryStream *, iTJSDispatch2 **) { return false; }
bool TVPLoadHeaderJXR(void *, tTJSBinaryStream *, iTJSDispatch2 **) { return false; }
bool TVPLoadHeaderPVRv3(void *, tTJSBinaryStream *, iTJSDispatch2 **) { return false; }

bool TVPSaveAsPNG(void *, tTJSBinaryStream *, const iTVPBaseBitmap *, const ttstr &, iTJSDispatch2 *) { return false; }
bool TVPSaveAsJXR(void *, tTJSBinaryStream *, const iTVPBaseBitmap *, const ttstr &, iTJSDispatch2 *) { return false; }
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
class tTVPMemoryStream {
public:
    tTVPMemoryStream();
};
tTVPMemoryStream::tTVPMemoryStream() {}

class tTVPLocalTempStorageHolder {
public:
    ~tTVPLocalTempStorageHolder();
};
tTVPLocalTempStorageHolder::~tTVPLocalTempStorageHolder() {}

// ---------------------------------------------------------------------------
// Storages 原生类（关键：脚本第一个找的对象之一）
// ---------------------------------------------------------------------------
tTJSNativeClass *TVPCreateNativeClass_Storages() {
    return new tTJSNC_Storages();
}
