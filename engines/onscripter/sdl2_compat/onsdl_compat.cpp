// =============================================================================
// onsdl_compat.cpp — SDL1.2 视频 API 的 SDL2 实现（ONScripter 专用）
//
// 模型:
//   SDL_SetVideoMode(w,h,32,..)  -> 建全屏 SDL_Window + SDL_Renderer +
//                                   ARGB8888 流式纹理 + 一块软件 surface
//   SDL_GetVideoSurface()        -> 那块软件 surface（引擎像 SDL1.2 一样往里画）
//   SDL_Flip / SDL_UpdateRect    -> 纹理上传 + RenderCopy + Present
//
// 适配模式（GalPlayer 全局设置，由桥接层在引擎启动前设置）:
//   stretch=0 原始比例: SDL_RenderSetLogicalSize(w,h) 自动居中加黑边
//   stretch=1 拉伸全屏: 纹理直接铺满整个窗口
// =============================================================================
#include <stdio.h>
#include <string.h>

#include <SDL.h>          // 命中垫片 SDL.h -> 真SDL2 + 兼容宏
#include "onsdl_compat.h" // 再取一遍声明（幂等）

extern "C" {

// ---- 状态 ----
static SDL_Window   *g_window   = nullptr;
static SDL_Renderer *g_renderer = nullptr;
static SDL_Texture  *g_texture  = nullptr;
static SDL_Surface  *g_screen   = nullptr;
static int   g_stretch = 0;       // 0=原始比例 1=拉伸全屏
static int   g_w = 0, g_h = 0;
static bool  g_quitWatchInstalled = false;
static SDL_VideoInfo g_vinfo;
static char g_title[256] = "ONScripter";

void onsdl_set_scale_mode(int stretch) { g_stretch = stretch ? 1 : 0; }

// ---- SDL_QUIT 到来时优先自拆（保证 SDL_Quit 时窗口/渲染器已注销，
//      引擎退出后可反复进出游戏不残留） ----
static int compat_quit_watch(void *userdata, SDL_Event *event) {
    if (event->type == SDL_QUIT) {
        if (g_texture)  { SDL_DestroyTexture(g_texture);  g_texture = nullptr; }
        if (g_renderer) { SDL_DestroyRenderer(g_renderer); g_renderer = nullptr; }
        if (g_window)   { SDL_DestroyWindow(g_window);   g_window = nullptr; }
        if (g_screen)   { SDL_FreeSurface(g_screen);     g_screen = nullptr; }
        g_w = g_h = 0;
    }
    (void)userdata;
    return 1;
}

static void ensure_quit_watch() {
    if (!g_quitWatchInstalled) {
        SDL_AddEventWatch(compat_quit_watch, nullptr);
        g_quitWatchInstalled = true;
    }
}

SDL_Surface *SDL_Compat_SetVideoMode(int w, int h, int bpp, Uint32 flags) {
    (void)bpp;    // 统一 32bpp ARGB8888
    (void)flags;  // 统一全屏；分辨率以引擎传入为准
    ensure_quit_watch();

    if (!g_window) {
        g_window = SDL_CreateWindow("ONScripter",
                                    SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                                    w, h,
                                    SDL_WINDOW_FULLSCREEN_DESKTOP |
                                    SDL_WINDOW_ALLOW_HIGHDPI |
                                    SDL_WINDOW_BORDERLESS);
        if (!g_window) {
            fprintf(stderr, "[onsdl] CreateWindow failed: %s\n", SDL_GetError());
            return nullptr;
        }
    }

    if (!g_renderer) {
        // iOS 上可用驱动有限（metal / opengles2 / opengles），逐个显式尝试并打印诊断
        int ndrv = SDL_GetNumRenderDrivers();
        fprintf(stderr, "[onsdl] 可用渲染驱动数=%d\n", ndrv);
        for (int i = 0; i < ndrv; ++i) {
            SDL_RendererInfo info;
            if (SDL_GetRenderDriverInfo(i, &info) == 0)
                fprintf(stderr, "[onsdl]   driver[%d]=%s\n", i, info.name);
        }
        const char *order[] = {"metal", "opengles2", "opengles", nullptr};
        for (int i = 0; order[i]; ++i) {
            g_renderer = SDL_CreateRenderer(g_window, order[i],
                                            SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
            if (g_renderer) {
                fprintf(stderr, "[onsdl] renderer=%s 创建成功\n", order[i]);
                break;
            }
            fprintf(stderr, "[onsdl] renderer %s 失败: %s\n", order[i], SDL_GetError());
            g_renderer = SDL_CreateRenderer(g_window, order[i], SDL_RENDERER_ACCELERATED);
            if (g_renderer) {
                fprintf(stderr, "[onsdl] renderer=%s 创建成功(无vsync)\n", order[i]);
                break;
            }
        }
        if (!g_renderer) {
            g_renderer = SDL_CreateRenderer(g_window, -1, SDL_RENDERER_SOFTWARE);
            if (g_renderer) fprintf(stderr, "[onsdl] renderer=software\n");
        }
        if (!g_renderer) {
            fprintf(stderr, "[onsdl] CreateRenderer failed: %s\n", SDL_GetError());
            return nullptr;
        }
    }

    // 比例模式
    if (g_stretch) {
        SDL_RenderSetLogicalSize(g_renderer, 0, 0); // 取消逻辑尺寸 = 拉伸铺满
    } else {
        SDL_RenderSetLogicalSize(g_renderer, w, h); // 等比 + 黑边
    }
    SDL_SetRenderDrawColor(g_renderer, 0, 0, 0, 255);

    // 重建纹理与画面 surface
    if (g_texture) SDL_DestroyTexture(g_texture);
    if (g_screen)  SDL_FreeSurface(g_screen);
    g_texture = SDL_CreateTexture(g_renderer, SDL_PIXELFORMAT_ARGB8888,
                                  SDL_TEXTUREACCESS_STREAMING, w, h);
    g_screen  = SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL_PIXELFORMAT_ARGB8888);
    if (!g_texture || !g_screen) {
        fprintf(stderr, "[onsdl] texture/surface create failed: %s\n", SDL_GetError());
        return nullptr;
    }
    g_w = w; g_h = h;

    SDL_SetWindowTitle(g_window, g_title);
    fprintf(stderr, "[onsdl] SetVideoMode %dx%d stretch=%d ok\n", w, h, g_stretch);
    return g_screen;
}

SDL_Surface *SDL_Compat_GetVideoSurface(void) { return g_screen; }

static void present_frame() {
    if (!g_texture || !g_renderer || !g_screen) return;
    SDL_UpdateTexture(g_texture, nullptr, g_screen->pixels, g_screen->pitch);
    SDL_RenderClear(g_renderer);
    SDL_RenderCopy(g_renderer, g_texture, nullptr, nullptr);
    SDL_RenderPresent(g_renderer);
}

int SDL_Compat_Flip(SDL_Surface *s) {
    (void)s;
    present_frame();
    return 0;
}

void SDL_Compat_UpdateRect(SDL_Surface *s, Sint32 x, Sint32 y, Sint32 w, Sint32 h) {
    (void)s; (void)x; (void)y; (void)w; (void)h;
    present_frame(); // 整帧上屏，简单可靠（800x600 级别分辨率无压力）
}

void SDL_Compat_UpdateRects(SDL_Surface *s, int n, SDL_Rect *rects) {
    (void)s; (void)n; (void)rects;
    present_frame();
}

void SDL_Compat_SetCaption(const char *title, const char *icon) {
    (void)icon;
    if (title && *title) {
        snprintf(g_title, sizeof(g_title), "%s", title);
        if (g_window) SDL_SetWindowTitle(g_window, g_title);
    }
}

int SDL_Compat_SetAlpha(SDL_Surface *s, Uint32 flag, Uint8 alpha) {
    if (!s) return -1;
    if (flag & ONSDL_SRCALPHA) {
        SDL_SetSurfaceAlphaMod(s, alpha);
        SDL_SetSurfaceBlendMode(s, SDL_BLENDMODE_BLEND);
    } else {
        SDL_SetSurfaceAlphaMod(s, SDL_ALPHA_OPAQUE);
        SDL_SetSurfaceBlendMode(s, SDL_BLENDMODE_NONE);
    }
    return 0;
}

int SDL_Compat_EnableUNICODE(int)   { return 1; }
int SDL_Compat_EnableKeyRepeat(int, int) { return 0; }

int SDL_Compat_GetAppState(void) {
    // 始终视为前台聚焦（iOS 全屏单窗口场景）
    return SDL_APPMOUSEFOCUS | SDL_APPINPUTFOCUS | SDL_APPACTIVE;
}

SDL_VideoInfo *SDL_Compat_GetVideoInfo(void) {
    memset(&g_vinfo, 0, sizeof(g_vinfo));
    SDL_Rect r;
    if (SDL_GetDisplayBounds(0, &r) == 0) { g_vinfo.current_w = r.w; g_vinfo.current_h = r.h; }
    return &g_vinfo;
}

void onsdl_compat_shutdown(void) {
    if (g_texture)  { SDL_DestroyTexture(g_texture);   g_texture = nullptr; }
    if (g_renderer) { SDL_DestroyRenderer(g_renderer); g_renderer = nullptr; }
    if (g_window)   { SDL_DestroyWindow(g_window);     g_window = nullptr; }
    if (g_screen)   { SDL_FreeSurface(g_screen);       g_screen = nullptr; }
    g_w = g_h = 0;
}

} // extern "C"
