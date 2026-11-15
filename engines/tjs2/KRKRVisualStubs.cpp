// =============================================================================
// KRKRVisualStubs.cpp —— KiriKiri 图形/窗口/音频层的 iOS 过渡实现
//
// 目的：先把运行时缺的符号补齐，让游戏脚本能完整跑一遍（无画面）。
// 之后逐步把 Bitmap / Layer / Font / Window 换成真正的 CPU 渲染实现。
//
// 设计原则：
//   - 只提供最小可用的行为，不做假数据
//   - 每个桩都打日志，运行时可观测
// =============================================================================
#include <cstdio>
#include <string>
#include <functional>
#include <tuple>
#include <vector>

#include "tjsCommHead.h"
#include "tjsString.h"
#include "tjsVariant.h"
#include "tjsNative.h"
#include "tjsUtils.h"
#include "StorageIntf.h"
#include "SysInitIntf.h"

#ifndef KRKR_STUB_LOG
#define KRKR_STUB_LOG(...) do { fprintf(stderr, "[KRKR-stub] " __VA_ARGS__); fputc('\n', stderr); } while (0)
#endif

// ---------------------------------------------------------------------------
// 屏幕信息（KAG 会读分辨率来布局）
// ---------------------------------------------------------------------------
class tTVPScreen {
public:
    static int GetWidth();
    static int GetHeight();
    static int GetDesktopWidth();
    static int GetDesktopHeight();
    static int GetDesktopLeft();
    static int GetDesktopTop();
};

int tTVPScreen::GetWidth()         { return 1920; }
int tTVPScreen::GetHeight()        { return 1080; }
int tTVPScreen::GetDesktopWidth()  { return 1920; }
int tTVPScreen::GetDesktopHeight() { return 1080; }
int tTVPScreen::GetDesktopLeft()   { return 0; }
int tTVPScreen::GetDesktopTop()    { return 0; }

// ---------------------------------------------------------------------------
// 系统控制（事件循环相关）—— 先空转
// ---------------------------------------------------------------------------
class tTVPSystemControl {
public:
    void BeginContinuousEvent();
    void EndContinuousEvent();
    void InvokeEvents();
    void CallDeliverAllEventsOnIdle();
    void NotifyEventDelivered();
};

void tTVPSystemControl::BeginContinuousEvent() {}
void tTVPSystemControl::EndContinuousEvent() {}
void tTVPSystemControl::InvokeEvents() {}
void tTVPSystemControl::CallDeliverAllEventsOnIdle() {}
void tTVPSystemControl::NotifyEventDelivered() {}

// ---------------------------------------------------------------------------
// 应用对象（标题/退出等）
// ---------------------------------------------------------------------------
class tTVPApplication {
public:
    void SetTitle(const ttstr &title);
    void Terminate();
    void PostUserMessage(const std::function<void()> &func, void *data, int delay);
    void FilterUserMessage(const std::function<void(std::vector<std::tuple<void *, int, std::function<void()>>> &)> &filter);
    void LoadImageRequest(TJS::iTJSDispatch2 *callback, class tTJSNI_Bitmap *bmp, const ttstr &name);
};

void tTVPApplication::FilterUserMessage(const std::function<void(std::vector<std::tuple<void *, int, std::function<void()>>> &)> &filter) {
    (void)filter;   // 阶段一：不过滤，事件照常派发
}

void tTVPApplication::LoadImageRequest(TJS::iTJSDispatch2 *callback, class tTJSNI_Bitmap *, const ttstr &name) {
    KRKR_STUB_LOG("LoadImageRequest(%s) 未实现（阶段二接 SDL2_image）", name.AsStdString().c_str());
    (void)callback;
}

void tTVPApplication::SetTitle(const ttstr &title) {
    KRKR_STUB_LOG("SetTitle: %s", title.AsStdString().c_str());
}
void tTVPApplication::Terminate() {
    KRKR_STUB_LOG("Terminate requested");
}
void tTVPApplication::PostUserMessage(const std::function<void()> &func, void *, int) {
    if (func) func();
}

// 全局实例（运行时按名引用）
tTVPApplication     *Application = nullptr;
void                *TVPRegisteredPlugins = nullptr;
tTVPSystemControl   *TVPSystemControl = nullptr;

// ---------------------------------------------------------------------------
// 杂项
// ---------------------------------------------------------------------------
void TVPClearGraphicCache() {
    KRKR_STUB_LOG("TVPClearGraphicCache");
}

void TVPUninitTVPGL() {
    KRKR_STUB_LOG("TVPUninitTVPGL");
}

void TVPExitApplication(int code) {
    KRKR_STUB_LOG("TVPExitApplication(%d)", code);
    throw "TVPExitApplication";
}

ttstr TVPGetErrorDialogTitle() {
    return ttstr("GalPlayer");
}
