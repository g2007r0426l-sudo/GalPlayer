// =============================================================================
// EngineRuntime.hpp — 桥接层内部共享（C++，仅供 Bridges/ 下各 .mm 使用）
// =============================================================================
#pragma once

#include <string>
#include <vector>
#include <atomic>

namespace gp {

// 引擎入口函数签名（编译期已用 -Dmain=xxx 重命名；全局作用域符号）
using EngineMainFn = int (*)(int, char **);

struct LaunchCtx {
    std::string gameDir;
    std::string fontPath;   // App 内置兜底字体绝对路径（可空）
    std::string dataFile;   // Kirikiri 的 .xp3 文件名（可空）
    bool        stretch = false;
    float       textSpeed = 1.0f;
    bool        touchToMouse = false; // true=桥接层做 手指→鼠标 映射(ONS)
                                      // false=引擎原生触控(Kirikiroid2)
    std::vector<std::string> args;    // 传给引擎 main 的 argv
};

// ---- 运行时（SDLTouchBridge.mm 实现） ----
int  launchEngine(EngineMainFn fn, LaunchCtx ctx);
void requestEngineStop();
bool engineRunning();
void setStoppedCallback(void (*cb)(void));
void copyFontIfNeeded(const std::string &src, const std::string &dst);
void ensureDir(const std::string &path);
float fastForwardIntervalMs(float textSpeed);

// ---- 引擎启动胶水 ----
int launchOns(LaunchCtx ctx);   // OnsBridge.mm
int launchKrkr(LaunchCtx ctx);  // KrkrBridge.mm

} // namespace gp
