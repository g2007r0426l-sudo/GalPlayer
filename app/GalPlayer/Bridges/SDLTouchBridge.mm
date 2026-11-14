// =============================================================================
// SDLTouchBridge.mm — GalPlayer 统一引擎运行时桥接
//
//   1. 引擎线程管理: 独立线程 + SDL_UIKitRunApp（SDL2 iOS 标准启动路径）
//   2. 触控统一映射（touchToMouse=true 的引擎，即 ONScripter）:
//        单指单击  -> 鼠标左键（推进剧情）
//        双指轻点  -> 鼠标右键（呼出引擎菜单）
//        长按      -> 快进（Ctrl 按住 + 连点节流，间隔由"文字速度"设置控制）
//      Kirikiri 走 Kirikiroid2 原生触控处理（touchToMouse=false），行为一致。
//   3. GP_* C API 分发（Swift 调用入口）
// =============================================================================
#import <Foundation/Foundation.h>

#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <cstdio>
#include <chrono>
#include <map>
#include <mutex>
#include <thread>

// SDL2 类型/事件 API（禁用 SDL_main.h 的 main 宏污染）
#define SDL_MAIN_HANDLED 1
#include <SDL.h>

#include "EngineBridge.h"
#include "EngineRuntime.hpp"

// iOS 启动入口（SDL_main.h 未包含，手动声明）
extern "C" {
    typedef int (*SDL_main_func)(int argc, char *argv[]);
    int SDL_UIKitRunApp(int argc, char *argv[], SDL_main_func mainFunction);
}
// ONScripter SDL1.2 兼容层（engines/onscripter/sdl2_compat）
extern "C" void onsdl_compat_shutdown(void);

// ============================================================================

namespace gp {

// ---- 手势参数 ----
static const Uint32 LONG_PRESS_MS   = 450;   // 长按阈值
static const Uint32 TWO_FINGER_MAX  = 400;   // 双指轻点窗口
static const float  MOVE_EPS        = 0.02f; // 归一化位移阈值（防抖）

// ---- 运行状态 ----
static LaunchCtx        g_ctx;
static std::atomic<bool> g_running{false};
static std::thread       g_thread;
static void            (*g_stoppedCb)(void) = nullptr;

// ---- 触控映射状态 ----
struct FingerInfo { float x, y; Uint32 t0; bool moved; };
static std::map<SDL_FingerID, FingerInfo> g_fingers;
static std::mutex  g_stateMutex;
static bool        g_leftDownSent = false;  // 原始单击的左键按下态
static bool        g_skipActive   = false;  // 长按快进中
static Uint32      g_lastClick    = 0;
static bool        g_pendingRight = false;
static Uint32      g_twoFingerT0  = 0;
static std::atomic<bool> g_monitorRun{false};
static std::thread g_monitor;

// ---------------------------------------------------------------------------
// 事件推送
// ---------------------------------------------------------------------------
static SDL_Window *engineWindow() {
    // 引擎窗口是本次 SDL 运行中创建的第一个窗口（ID 从 1 起）
    return SDL_GetWindowFromID(1);
}

static void pushMouseMotion(float nx, float ny) {
    SDL_Window *w = engineWindow();
    if (!w) return;
    int ww = 0, wh = 0;
    SDL_GetWindowSize(w, &ww, &wh);
    if (ww <= 0 || wh <= 0) return;

    SDL_Event ev;
    SDL_zero(ev);
    ev.motion.type = SDL_MOUSEMOTION;
    ev.motion.windowID = SDL_GetWindowID(w);
    ev.motion.which = 0;
    ev.motion.x = nx * (float)ww;
    ev.motion.y = ny * (float)wh;
    SDL_PushEvent(&ev);
}

static void pushMouseButton(bool down, Uint8 button, float nx, float ny) {
    SDL_Window *w = engineWindow();
    if (!w) return;
    int ww = 0, wh = 0;
    SDL_GetWindowSize(w, &ww, &wh);
    if (ww <= 0 || wh <= 0) return;

    SDL_Event ev;
    SDL_zero(ev);
    ev.button.type    = down ? SDL_MOUSEBUTTONDOWN : SDL_MOUSEBUTTONUP;
    ev.button.windowID = SDL_GetWindowID(w);
    ev.button.which   = 0;
    ev.button.button  = button;
    ev.button.state   = down ? SDL_PRESSED : SDL_RELEASED;
    ev.button.clicks  = 1;
    ev.button.x = nx * (float)ww;
    ev.button.y = ny * (float)wh;
    SDL_PushEvent(&ev);
}

static void pushCtrlKey(bool down) {
    SDL_Window *w = engineWindow();
    if (!w) return;
    SDL_Event ev;
    SDL_zero(ev);
    ev.key.type = down ? SDL_KEYDOWN : SDL_KEYUP;
    ev.key.windowID = SDL_GetWindowID(w);
    ev.key.state = down ? SDL_PRESSED : SDL_RELEASED;
    ev.key.repeat = 0;
    ev.key.keysym.sym = SDLK_LCTRL;
    SDL_PushEvent(&ev);
}

static void sendMouseMove(float x, float y) { pushMouseMotion(x, y); }
static void sendMouseLeft(bool down, float x, float y) { pushMouseButton(down, SDL_BUTTON_LEFT, x, y); }
static void sendMouseRightClick(float x, float y) {
    pushMouseButton(true, SDL_BUTTON_RIGHT, x, y);
    pushMouseButton(false, SDL_BUTTON_RIGHT, x, y);
}

static void stopSkipLocked() {
    if (g_skipActive) {
        pushCtrlKey(false);
        g_skipActive = false;
    }
}

static void resetTouchState() {
    std::lock_guard<std::mutex> lk(g_stateMutex);
    g_fingers.clear();
    g_leftDownSent = false;
    g_skipActive = false;
    g_pendingRight = false;
    g_lastClick = 0;
    g_twoFingerT0 = 0;
}

// ---------------------------------------------------------------------------
// SDL 事件观察（仅 touchToMouse 引擎安装）
// ---------------------------------------------------------------------------
static int gp_touch_watch(void *userdata, SDL_Event *e) {
    (void)userdata;
    switch (e->type) {
    case SDL_FINGERDOWN: {
        SDL_FingerID fid = e->tfinger.fingerId;
        float x = e->tfinger.x, y = e->tfinger.y;
        std::lock_guard<std::mutex> lk(g_stateMutex);
        if (g_fingers.empty()) {
            // 第一指落下 = 左键按下（推进）
            g_fingers[fid] = FingerInfo{x, y, SDL_GetTicks(), false};
            sendMouseMove(x, y);
            sendMouseLeft(true, x, y);
            g_leftDownSent = true;
        } else if (g_fingers.size() == 1) {
            // 第二指落下 → 取消左键按压态，进入右键候选
            auto it = g_fingers.begin();
            sendMouseLeft(false, it->second.x, it->second.y);
            g_leftDownSent = false;
            stopSkipLocked();
            g_fingers[fid] = FingerInfo{x, y, SDL_GetTicks(), false};
            g_twoFingerT0 = SDL_GetTicks();
            g_pendingRight = true;
        } else {
            g_fingers[fid] = FingerInfo{x, y, SDL_GetTicks(), false};
        }
        break;
    }
    case SDL_FINGERMOTION: {
        SDL_FingerID fid = e->tfinger.fingerId;
        float x = e->tfinger.x, y = e->tfinger.y;
        std::lock_guard<std::mutex> lk(g_stateMutex);
        auto it = g_fingers.find(fid);
        if (it == g_fingers.end()) break;
        float dx = x - it->second.x, dy = y - it->second.y;
        if (dx > MOVE_EPS || dx < -MOVE_EPS || dy > MOVE_EPS || dy < -MOVE_EPS) it->second.moved = true;
        it->second.x = x; it->second.y = y;
        if (g_fingers.size() == 1 && g_leftDownSent) sendMouseMove(x, y);
        break;
    }
    case SDL_FINGERUP: {
        SDL_FingerID fid = e->tfinger.fingerId;
        std::lock_guard<std::mutex> lk(g_stateMutex);
        auto it = g_fingers.find(fid);
        if (it == g_fingers.end()) break;
        FingerInfo f = it->second;
        g_fingers.erase(it);
        Uint32 now = SDL_GetTicks();
        if (g_fingers.empty()) {
            if (g_pendingRight && f.t0 >= g_twoFingerT0 &&
                (now - g_twoFingerT0) <= TWO_FINGER_MAX && !f.moved) {
                // 双指轻点 = 右键（呼出引擎菜单）
                sendMouseRightClick(f.x, f.y);
            } else {
                stopSkipLocked();
                if (g_leftDownSent) sendMouseLeft(false, f.x, f.y);
            }
            g_leftDownSent = false;
            g_pendingRight = false;
        } else if (g_fingers.size() == 1 && g_pendingRight) {
            // 双指只抬起一指 → 取消右键候选
            g_pendingRight = false;
        }
        break;
    }
    default:
        break;
    }
    return 1;
}

// ---------------------------------------------------------------------------
// 长按快进监控线程
// ---------------------------------------------------------------------------
static void monitorLoop() {
    while (g_monitorRun.load()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
        std::lock_guard<std::mutex> lk(g_stateMutex);
        Uint32 now = SDL_GetTicks();
        if (g_fingers.size() == 1 && g_leftDownSent) {
            auto &f = g_fingers.begin()->second;
            Uint32 held = now - f.t0;
            if (!g_skipActive && held >= LONG_PRESS_MS) {
                // 长按触发: 结束原始按压 → Ctrl 按住 + 周期连点 = 持续快进
                sendMouseLeft(false, f.x, f.y);
                g_leftDownSent = false;
                pushCtrlKey(true);
                g_skipActive = true;
                g_lastClick = now;
            }
            if (g_skipActive && (now - g_lastClick) >= (Uint32)fastForwardIntervalMs(g_ctx.textSpeed)) {
                sendMouseLeft(true, f.x, f.y);
                sendMouseLeft(false, f.x, f.y);
                g_lastClick = now;
            }
        }
    }
}

static void startMonitor() {
    g_monitorRun = true;
    g_monitor = std::thread(monitorLoop);
}

static void stopMonitor() {
    g_monitorRun = false;
    if (g_monitor.joinable()) g_monitor.join();
}

// ---------------------------------------------------------------------------
// 引擎线程
// ---------------------------------------------------------------------------
static int engineThreadMain(EngineMainFn fn) {
    if (!g_ctx.gameDir.empty()) {
        if (::chdir(g_ctx.gameDir.c_str()) != 0) {
            fprintf(stderr, "[GP] chdir(%s) 失败，引擎可能找不到游戏文件\n", g_ctx.gameDir.c_str());
        }
    }

    // SDL 全局行为设定
    SDL_SetHint(SDL_HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight");
    SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "0"); // 我们自己映射，避免双重鼠标事件
    SDL_SetHint(SDL_HINT_MOUSE_TOUCH_EVENTS, "0");

    if (g_ctx.touchToMouse) {
        SDL_AddEventWatch(gp_touch_watch, nullptr);
        startMonitor();
    }

    // 组装 argv
    std::vector<char *> argv;
    argv.reserve(g_ctx.args.size() + 1);
    for (auto &s : g_ctx.args) argv.push_back(const_cast<char *>(s.c_str()));
    argv.push_back(nullptr);

    fprintf(stderr, "[GP] 引擎线程启动: argc=%d touchToMouse=%d dir=%s\n",
            (int)g_ctx.args.size(), g_ctx.touchToMouse ? 1 : 0, g_ctx.gameDir.c_str());

    int rc = SDL_UIKitRunApp((int)g_ctx.args.size(), argv.data(), fn);

    fprintf(stderr, "[GP] 引擎线程退出 rc=%d\n", rc);

    if (g_ctx.touchToMouse) {
        stopMonitor();
        SDL_DelEventWatch(gp_touch_watch, nullptr);
    }
    // ONS 兼容层资源自拆（窗口/渲染器/纹理/画面 surface）；KRKR 无兼容层
    onsdl_compat_shutdown();
    resetTouchState();

    g_running = false;
    if (g_stoppedCb) g_stoppedCb();
    return rc;
}

// ---------------------------------------------------------------------------
// 运行时 API
// ---------------------------------------------------------------------------
int launchEngine(EngineMainFn fn, LaunchCtx ctx) {
    if (g_running.load()) return -1;             // 已在运行
    if (g_thread.joinable()) {
        requestEngineStop();                     // 兜底: 上一会话未完全退出
        g_thread.join();
    }
    g_ctx = std::move(ctx);
    resetTouchState();
    g_running = true;
    g_thread = std::thread(engineThreadMain, fn);
    return 0;
}

void requestEngineStop() {
    SDL_Event ev;
    SDL_zero(ev);
    ev.type = SDL_QUIT;
    SDL_PushEvent(&ev);
}

bool engineRunning() { return g_running.load(); }

void setStoppedCallback(void (*cb)(void)) { g_stoppedCb = cb; }

// ---- 工具 ----
void ensureDir(const std::string &path) {
    ::mkdir(path.c_str(), 0755); // EEXIST 忽略
}

void copyFontIfNeeded(const std::string &src, const std::string &dst) {
    if (src.empty() || dst.empty()) return;
    struct stat st;
    if (::stat(src.c_str(), &st) != 0 || !S_ISREG(st.st_mode)) return;
    if (::stat(dst.c_str(), &st) == 0 && S_ISREG(st.st_mode)) return; // 已存在，跳过
    FILE *in = fopen(src.c_str(), "rb");
    if (!in) return;
    FILE *out = fopen(dst.c_str(), "wb");
    if (!out) { fclose(in); return; }
    char buf[64 * 1024];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), in)) > 0) fwrite(buf, 1, n, out);
    fclose(in);
    fclose(out);
    fprintf(stderr, "[GP] 字体就位: %s\n", dst.c_str());
}

float fastForwardIntervalMs(float textSpeed) {
    // 1.0x -> 160ms；0.25x -> 640ms；4.0x -> 40ms
    float v = 160.0f / (textSpeed > 0.05f ? textSpeed : 1.0f);
    if (v < 40.0f) v = 40.0f;
    if (v > 640.0f) v = 640.0f;
    return v;
}

} // namespace gp

// ============================================================================
// GP_* C API 分发
// ============================================================================
extern "C" int GP_EngineStart(int kind,
                              const char *gameDir,
                              const char *fontPath,
                              const char *dataFile,
                              int stretchFullscreen,
                              float textSpeed) {
    gp::LaunchCtx ctx;
    ctx.gameDir   = gameDir   ? gameDir   : "";
    ctx.fontPath  = fontPath  ? fontPath  : "";
    ctx.dataFile  = dataFile  ? dataFile  : "";
    ctx.stretch   = stretchFullscreen != 0;
    ctx.textSpeed = (textSpeed > 0.05f) ? textSpeed : 1.0f;
    ctx.touchToMouse = (kind == GP_ENGINE_ONSCRIPTER);

    int rc;
    if (kind == GP_ENGINE_ONSCRIPTER) {
        rc = gp::launchOns(std::move(ctx));
    } else {
        rc = gp::launchKrkr(std::move(ctx));
    }
    return rc;
}

extern "C" void GP_EngineStop(void) { gp::requestEngineStop(); }
extern "C" int  GP_EngineIsRunning(void) { return gp::engineRunning() ? 1 : 0; }
extern "C" void GP_SetStoppedCallback(void (*cb)(void)) { gp::setStoppedCallback(cb); }
