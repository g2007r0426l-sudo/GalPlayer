// =============================================================================
// KRKRPlatformStubs.cpp —— KiriKiri 平台层补全（iOS）
//
// 只补运行时真正需要、且不依赖 cocos 的部分：
//   OS 信息 / 图形缓存上限 / 输入状态 / 插件加载 / 消息框 / 颜色转换 /
//   LocaleConfigManager（语言文案，按真实头文件签名实现）
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
#include "LocaleConfigManager.h"

#ifndef KRKR_STUB_LOG
#define KRKR_STUB_LOG(...) do { fprintf(stderr, "[KRKR-stub] " __VA_ARGS__); fputc('\n', stderr); } while (0)
#endif

// --------------------------------------------------------------------------- OS
ttstr TVPGetOSName()       { return ttstr("iOS"); }
ttstr TVPGetPlatformName() { return ttstr("iOS"); }

// --------------------------------------------------------------------------- 图形缓存
static tjs_uint64 gGraphicCacheLimit = 64ull * 1024 * 1024;

void TVPSetGraphicCacheLimit(tjs_uint64 limit) { gGraphicCacheLimit = limit; }
tjs_uint64 TVPGetGraphicCacheLimit()          { return gGraphicCacheLimit; }

// --------------------------------------------------------------------------- 输入
bool TVPGetKeyMouseAsyncState(tjs_uint keycode, bool get) {
    (void)keycode; (void)get;
    return false;
}

bool TVPGetJoyPadAsyncState(tjs_uint keycode, bool get) {
    (void)keycode; (void)get;
    return false;
}

// --------------------------------------------------------------------------- 插件
bool TVPLoadInternalPlugin(const ttstr &name) {
    KRKR_STUB_LOG("TVPLoadInternalPlugin(%s) 未实现（不影响 xp3 游戏）", name.AsStdString().c_str());
    return false;
}

// --------------------------------------------------------------------------- 消息框
void TVPShowSimpleMessageBox(const ttstr &text, const ttstr &caption) {
    KRKR_STUB_LOG("MessageBox[%s] %s", caption.AsStdString().c_str(), text.AsStdString().c_str());
}

int TVPShowSimpleMessageBox(const ttstr &text, const ttstr &caption,
                            const std::vector<ttstr> &buttons) {
    KRKR_STUB_LOG("MessageBox[%s] %s (buttons=%zu) -> 0",
                  caption.AsStdString().c_str(), text.AsStdString().c_str(), buttons.size());
    return 0;
}

bool TVPShowSimpleInputBox(ttstr &text, const ttstr &caption,
                           const ttstr &prompt, const std::vector<ttstr> &buttons) {
    (void)text; (void)buttons;
    KRKR_STUB_LOG("InputBox[%s] %s 未实现", caption.AsStdString().c_str(),
                  prompt.AsStdString().c_str());
    return false;
}

// --------------------------------------------------------------------------- 颜色
tjs_uint32 TVPToActualColor(tjs_uint32 color) {
    return color;
}

// --------------------------------------------------------------------------- 语言文案
// 按 LocaleConfigManager.h 的真实签名实现（返回 const std::string&，非 const 成员）
LocaleConfigManager::LocaleConfigManager() {}

LocaleConfigManager *LocaleConfigManager::GetInstance() {
    static LocaleConfigManager *inst = new LocaleConfigManager();
    return inst;
}

const std::string &LocaleConfigManager::GetText(const std::string &tid) {
    static std::string text;
    text = tid;              // 没有 locale 资源时直接回显 tid
    return text;
}

void LocaleConfigManager::Initialize(const std::string &sysLang) {
    (void)sysLang;
}

std::string LocaleConfigManager::GetFilePath() {
    return std::string();
}
