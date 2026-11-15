// =============================================================================
// KRKRPlatformStubs.cpp —— KiriKiri 平台层补全（iOS）
//
// 覆盖：
//   OS 信息 / 图形缓存上限 / 输入状态 / 插件加载 / 消息框 / 颜色转换
//   GlobalConfigManager（配置，内存版）
//   LocaleConfigManager（语言文案）
// 说明：这些原本在 Kirikinux2 里依赖 cocos FileUtils 落盘；iOS 侧改为内存实现，
//       等渲染打通后再接真实存档目录。
// =============================================================================
#include <cstdio>
#include <string>
#include <vector>
#include <unordered_map>
#include <functional>

#include "tjsCommHead.h"
#include "tjsString.h"
#include "tjsVariant.h"
#include "tjsNative.h"
#include "tjsUtils.h"
#include "StorageIntf.h"
#include "SysInitIntf.h"
#include "GlobalConfigManager.h"
#include "LocaleConfigManager.h"

#ifndef KRKR_STUB_LOG
#define KRKR_STUB_LOG(...) do { fprintf(stderr, "[KRKR-stub] " __VA_ARGS__); fputc('\n', stderr); } while (0)
#endif

// --------------------------------------------------------------------------- OS
ttstr TVPGetOSName()       { return ttstr("iOS"); }
ttstr TVPGetPlatformName() { return ttstr("iOS"); }

// --------------------------------------------------------------------------- 输入
bool TVPGetKeyMouseAsyncState(tjs_uint keycode, bool get) { (void)keycode; (void)get; return false; }
bool TVPGetJoyPadAsyncState(tjs_uint keycode, bool get)   { (void)keycode; (void)get; return false; }

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

// --------------------------------------------------------------------------- 配置管理（内存版）
void iSysConfigManager::Initialize() { ConfigUpdated = false; }

void iSysConfigManager::SaveToFile() { ConfigUpdated = false; }

bool iSysConfigManager::IsValueExist(const std::string &name) {
    return AllConfig.find(name) != AllConfig.end();
}

void iSysConfigManager::SetValue(const std::string &name, const std::string &val) {
    AllConfig[name] = val;
    ConfigUpdated = true;
}

void iSysConfigManager::SetValueInt(const std::string &name, int val) {
    SetValue(name, std::to_string(val));
}

void iSysConfigManager::SetValueFloat(const std::string &name, float val) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", val);
    SetValue(name, std::string(buf));
}

void iSysConfigManager::SetKeyMap(int k, int v) {
    if (v == 0) KeyMap.erase(k);
    else KeyMap[k] = v;
    ConfigUpdated = true;
}

std::vector<std::string> iSysConfigManager::GetCustomArgumentsForPush() {
    std::vector<std::string> out;
    for (auto &kv : CustomArguments) {
        out.push_back(kv.first);
        out.push_back(kv.second);
    }
    return out;
}

template<> bool iSysConfigManager::GetValue<bool>(const std::string &name, const bool &defVal) {
    auto it = AllConfig.find(name);
    if (it == AllConfig.end()) return defVal;
    return it->second == "true" || it->second == "1";
}

template<> int iSysConfigManager::GetValue<int>(const std::string &name, const int &defVal) {
    auto it = AllConfig.find(name);
    if (it == AllConfig.end()) return defVal;
    return atoi(it->second.c_str());
}

template<> float iSysConfigManager::GetValue<float>(const std::string &name, const float &defVal) {
    auto it = AllConfig.find(name);
    if (it == AllConfig.end()) return defVal;
    return (float)atof(it->second.c_str());
}

template<> std::string iSysConfigManager::GetValue<std::string>(const std::string &name,
                                                               const std::string &defVal) {
    auto it = AllConfig.find(name);
    if (it == AllConfig.end()) return defVal;
    return it->second;
}

GlobalConfigManager::GlobalConfigManager() { Initialize(); }

std::string GlobalConfigManager::GetFilePath() {
    return std::string("/var/mobile/Documents/krkr_global.cfg");
}

GlobalConfigManager *GlobalConfigManager::GetInstance() {
    static GlobalConfigManager *inst = new GlobalConfigManager();
    return inst;
}

// --------------------------------------------------------------------------- 语言文案
LocaleConfigManager::LocaleConfigManager() {}

LocaleConfigManager *LocaleConfigManager::GetInstance() {
    static LocaleConfigManager *inst = new LocaleConfigManager();
    return inst;
}

const std::string &LocaleConfigManager::GetText(const std::string &tid) {
    static std::string text;
    text = tid;                    // 没有 locale 资源时回显 tid
    return text;
}

void LocaleConfigManager::Initialize(const std::string &sysLang) { (void)sysLang; }

std::string LocaleConfigManager::GetFilePath() { return std::string(); }
