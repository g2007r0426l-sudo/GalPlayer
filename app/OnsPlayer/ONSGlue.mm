// =============================================================================
// ONSGlue.mm - ONScripter standalone player glue
//   1. read marker file /var/mobile/Documents/Galgames/.ons_launch (line 1 = game dir)
//   2. chdir into game dir (saves land inside game dir)
//   3. install unified touch mapping (tap = left click, 2-finger = right click, long press = skip)
//   4. call engine entry ons_main (renamed at build time with -Dmain=ons_main)
//
// NOTE: all log strings are ASCII on purpose - keeps the file encoding-safe.
// =============================================================================
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>

#define SDL_MAIN_HANDLED 1
#include <SDL.h>

#include <unistd.h>
#include <sys/stat.h>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <mutex>
#include <string>
#include <thread>
#include <chrono>

int ons_main(int argc, char **argv);
extern "C" void onsdl_set_scale_mode(int stretch);

static const char *K_MARKER = "/var/mobile/Documents/Galgames/.ons_launch";

// ============================ touch mapping ================================
static const Uint32 LONG_PRESS_MS  = 450;
static const Uint32 TWO_FINGER_MAX = 400;
static const float  MOVE_EPS       = 0.02f;

struct FingerInfo { float x, y; Uint32 t0; bool moved; };
static std::map<SDL_FingerID, FingerInfo> g_fingers;
static std::mutex g_mtx;
static bool   g_leftDown = false;
static bool   g_skip = false;
static bool   g_pendingRight = false;
static Uint32 g_twoT0 = 0;
static Uint32 g_lastClick = 0;
static bool   g_monitorRun = false;
static std::thread *g_monitor = nullptr;  // heap: avoid joinable-thread terminate on exit()

static SDL_Window *engineWindow() { return SDL_GetWindowFromID(1); }

static void pushMotion(float nx, float ny) {
    SDL_Window *w = engineWindow(); if (!w) return;
    int ww = 0, wh = 0; SDL_GetWindowSize(w, &ww, &wh);
    if (ww <= 0 || wh <= 0) return;
    SDL_Event ev; SDL_zero(ev);
    ev.motion.type = SDL_MOUSEMOTION;
    ev.motion.windowID = SDL_GetWindowID(w);
    ev.motion.x = (Sint32)(nx * ww); ev.motion.y = (Sint32)(ny * wh);
    SDL_PushEvent(&ev);
}

static void pushButton(bool down, Uint8 button, float nx, float ny) {
    SDL_Window *w = engineWindow(); if (!w) return;
    int ww = 0, wh = 0; SDL_GetWindowSize(w, &ww, &wh);
    if (ww <= 0 || wh <= 0) return;
    SDL_Event ev; SDL_zero(ev);
    ev.button.type = down ? SDL_MOUSEBUTTONDOWN : SDL_MOUSEBUTTONUP;
    ev.button.windowID = SDL_GetWindowID(w);
    ev.button.button = button;
    ev.button.state = down ? SDL_PRESSED : SDL_RELEASED;
    ev.button.clicks = 1;
    ev.button.x = (Sint32)(nx * ww); ev.button.y = (Sint32)(ny * wh);
    SDL_PushEvent(&ev);
}

static void pushCtrl(bool down) {
    SDL_Window *w = engineWindow(); if (!w) return;
    SDL_Event ev; SDL_zero(ev);
    ev.key.type = down ? SDL_KEYDOWN : SDL_KEYUP;
    ev.key.windowID = SDL_GetWindowID(w);
    ev.key.state = down ? SDL_PRESSED : SDL_RELEASED;
    ev.key.keysym.sym = SDLK_LCTRL;
    SDL_PushEvent(&ev);
}

static void stopSkipLocked() {
    if (g_skip) { pushCtrl(false); g_skip = false; }
}

static void monitorLoop() {
    while (g_monitorRun) {
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
        std::lock_guard<std::mutex> lk(g_mtx);
        Uint32 now = SDL_GetTicks();
        if (g_fingers.size() == 1 && g_leftDown) {
            FingerInfo &f = g_fingers.begin()->second;
            Uint32 held = now - f.t0;
            if (!g_skip && held >= LONG_PRESS_MS) {
                pushButton(false, SDL_BUTTON_LEFT, f.x, f.y);
                g_leftDown = false;
                pushCtrl(true);
                g_skip = true;
                g_lastClick = now;
            }
            if (g_skip && (now - g_lastClick) >= 160) {
                pushButton(true,  SDL_BUTTON_LEFT, f.x, f.y);
                pushButton(false, SDL_BUTTON_LEFT, f.x, f.y);
                g_lastClick = now;
            }
        }
    }
}

static int touchWatch(void *, SDL_Event *e) {
    switch (e->type) {
    case SDL_FINGERDOWN: {
        std::lock_guard<std::mutex> lk(g_mtx);
        SDL_FingerID fid = e->tfinger.fingerId;
        float x = e->tfinger.x, y = e->tfinger.y;
        if (g_fingers.empty()) {
            g_fingers[fid] = FingerInfo{x, y, SDL_GetTicks(), false};
            pushMotion(x, y);
            pushButton(true, SDL_BUTTON_LEFT, x, y);
            g_leftDown = true;
        } else if (g_fingers.size() == 1) {
            std::map<SDL_FingerID, FingerInfo>::iterator it = g_fingers.begin();
            pushButton(false, SDL_BUTTON_LEFT, it->second.x, it->second.y);
            g_leftDown = false;
            stopSkipLocked();
            g_fingers[fid] = FingerInfo{x, y, SDL_GetTicks(), false};
            g_twoT0 = SDL_GetTicks();
            g_pendingRight = true;
        } else {
            g_fingers[fid] = FingerInfo{x, y, SDL_GetTicks(), false};
        }
        break;
    }
    case SDL_FINGERMOTION: {
        std::lock_guard<std::mutex> lk(g_mtx);
        std::map<SDL_FingerID, FingerInfo>::iterator it = g_fingers.find(e->tfinger.fingerId);
        if (it == g_fingers.end()) break;
        float x = e->tfinger.x, y = e->tfinger.y;
        float dx = x - it->second.x, dy = y - it->second.y;
        if (dx > MOVE_EPS || dx < -MOVE_EPS || dy > MOVE_EPS || dy < -MOVE_EPS) it->second.moved = true;
        it->second.x = x; it->second.y = y;
        if (g_fingers.size() == 1 && g_leftDown) pushMotion(x, y);
        break;
    }
    case SDL_FINGERUP: {
        std::lock_guard<std::mutex> lk(g_mtx);
        std::map<SDL_FingerID, FingerInfo>::iterator it = g_fingers.find(e->tfinger.fingerId);
        if (it == g_fingers.end()) break;
        FingerInfo f = it->second;
        g_fingers.erase(it);
        Uint32 now = SDL_GetTicks();
        if (g_fingers.empty()) {
            if (g_pendingRight && (now - g_twoT0) <= TWO_FINGER_MAX && !f.moved) {
                pushButton(true,  SDL_BUTTON_RIGHT, f.x, f.y);
                pushButton(false, SDL_BUTTON_RIGHT, f.x, f.y);
            } else {
                stopSkipLocked();
                if (g_leftDown) pushButton(false, SDL_BUTTON_LEFT, f.x, f.y);
            }
            g_leftDown = false;
            g_pendingRight = false;
        } else if (g_fingers.size() == 1 && g_pendingRight) {
            g_pendingRight = false;
        }
        break;
    }
    default: break;
    }
    return 1;
}

// ============================ entry ========================================
int GP_ONS_Entry(int argc, char **argv) {
    // 0. runtime log (stderr is not visible in iOS syslog for apps)
    if (FILE *lf = fopen("/var/mobile/Documents/ons_runtime.log", "w")) {
        dup2(fileno(lf), 1);
        dup2(fileno(lf), 2);
        setvbuf(stdout, nullptr, _IONBF, 0);
        setvbuf(stderr, nullptr, _IONBF, 0);
    }
    fprintf(stderr, "[ONSApp] start argc=%d\n", argc);

    // 1. marker
    std::string gameDir;
    if (FILE *fp = fopen(K_MARKER, "r")) {
        char line[1024];
        if (fgets(line, sizeof(line), fp)) {
            size_t n = strlen(line);
            while (n && (line[n-1] == '\n' || line[n-1] == '\r')) line[--n] = 0;
            gameDir = line;
        }
        fclose(fp);
        unlink(K_MARKER);
    }
    if (gameDir.empty()) gameDir = "/var/mobile/Documents/Galgames";
    fprintf(stderr, "[ONSApp] gameDir=%s\n", gameDir.c_str());

    if (::chdir(gameDir.c_str()) != 0)
        fprintf(stderr, "[ONSApp] chdir failed errno=%d\n", errno);
    char cwd[1024] = {0};
    if (getcwd(cwd, sizeof(cwd))) fprintf(stderr, "[ONSApp] cwd=%s\n", cwd);

    const char *scripts[] = {"0.txt", "00.txt", "nscript.dat", "nscript.___"};
    for (int i = 0; i < 4; ++i)
        if (access(scripts[i], R_OK) == 0)
            fprintf(stderr, "[ONSApp] script found: %s\n", scripts[i]);

    // 2. GPU / environment probe
    @autoreleasepool {
        id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
        fprintf(stderr, "[ONSApp] probe MTLDevice=%s\n", dev ? "OK" : "nil");
        UIScreen *scr = [UIScreen mainScreen];
        CGRect b = scr ? scr.bounds : CGRectZero;
        fprintf(stderr, "[ONSApp] probe screen=%.0fx%.0f scale=%.1f\n",
                (double)b.size.width, (double)b.size.height, scr ? (double)scr.scale : 0.0);
        const char *drv = SDL_GetCurrentVideoDriver();
        fprintf(stderr, "[ONSApp] probe videoDriver=%s\n", drv ? drv : "(null)");
    }

    // 3. SDL hints + touch bridge
    SDL_SetHint(SDL_HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight");
    SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "0");
    SDL_SetHint(SDL_HINT_MOUSE_TOUCH_EVENTS, "0");
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "1");
    onsdl_set_scale_mode(0);

    SDL_AddEventWatch(touchWatch, nullptr);
    g_monitorRun = true;
    g_monitor = new std::thread(monitorLoop);
    g_monitor->detach();

    // 4. engine main loop
    //    ONScripter only accepts '-' options; a bare directory arg triggers optionHelp()+exit().
    //    We already chdir'ed into the game dir, so pass no arguments.
    std::string a0 = "onscripter";
    char *av[] = { const_cast<char *>(a0.c_str()), nullptr };
    int rc = ons_main(1, av);
    fprintf(stderr, "[ONSApp] ons_main returned rc=%d\n", rc);

    g_monitorRun = false;
    SDL_DelEventWatch(touchWatch, nullptr);
    return rc;
}
