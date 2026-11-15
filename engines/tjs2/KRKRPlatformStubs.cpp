// =============================================================================
// KRKRVisualStubs.cpp —— KiriKiri 图形/窗口/音频层的 iOS 过渡实现（第 2 部分）
//
// 这里补齐运行时的零散平台函数：OS 信息、图形缓存上限、输入状态、插件加载、
// 消息框、颜色转换等。图形类（Bitmap/Layer/Window/Font）在 KRRKVisualIos.cpp
// 里用真实的 CPU 实现提供。
// =============================================================================
#include <cstdio>
#include <string>
#include <vector>
#include <functional>

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
// OS / 平台信息
// ---------------------------------------------------------------------------
ttstr TVPGetOSName()      { return ttstr("iOS"); }
ttstr TVPGetPlatformName(){ return ttstr("iOS"); }

// ---------------------------------------------------------------------------
// 图形缓存（KAG 会设置上限，我们暂不缓存位图）
// ---------------------------------------------------------------------------
static tjs_uint64 gGraphicCacheLimit = 64ull * 1024 * 1024;   // 64MB

void TVPSetGraphicCacheLimit(tjs_uint64 limit) { gGraphicCacheLimit = limit; }
tjs_uint64 TVPGetGraphicCacheLimit()          { return gGraphicCacheLimit; }

void TVPUninitTVPGL() {
    KRKR_STUB_LOG("TVPUninitTVPGL");
}

// ---------------------------------------------------------------------------
// 输入状态查询（异步键盘/手柄）—— 由 UI 层后续填充
// ---------------------------------------------------------------------------
bool TVPGetKeyMouseAsyncState(tjs_uint keycode, bool get) {
    (void)keycode; (void)get;
    return false;
}

bool TVPGetJoyPadAsyncState(tjs_uint keycode, bool get) {
    (void)keycode; (void)get;
    return false;
}

// ---------------------------------------------------------------------------
// 插件
// ---------------------------------------------------------------------------
bool TVPLoadInternalPlugin(const ttstr &name) {
    KRKR_STUB_LOG("TVPLoadInternalPlugin(%s) -> 未实现，忽略", name.AsStdString().c_str());
    return false;
}

// ---------------------------------------------------------------------------
// 消息框（脚本里的 confirm/信息提示）—— 先只写日志
// ---------------------------------------------------------------------------
void TVPShowSimpleMessageBox(const ttstr &text, const ttstr &caption) {
    KRKR_STUB_LOG("MessageBox[%s] %s", caption.AsStdString().c_str(), text.AsStdString().c_str());
}

int TVPShowSimpleMessageBox(const ttstr &text, const ttstr &caption,
                            std::vector<ttstr> &buttons) {
    KRKR_STUB_LOG("MessageBox[%s] %s (buttons=%zu) -> 返回 0",
                  caption.AsStdString().c_str(), text.AsStdString().c_str(), buttons.size());
    return 0;
}

bool TVPShowSimpleInputBox(ttstr &text, const ttstr &caption,
                           const ttstr &prompt, std::vector<ttstr> &buttons) {
    (void)text; (void)buttons;
    KRKR_STUB_LOG("InputBox[%s] %s -> 未实现", caption.AsStdString().c_str(),
                  prompt.AsStdString().c_str());
    return false;
}

// ---------------------------------------------------------------------------
// 颜色转换（KiriKiri 内部 0xRRGGBB -> 设备颜色）
// ---------------------------------------------------------------------------
tjs_uint32 TVPToActualColor(tjs_uint32 color) {
    return color;
}
