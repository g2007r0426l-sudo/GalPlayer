// =============================================================================
// onsdl_compat.h — SDL 1.2 -> SDL 2.x 兼容垫片（ONScripter 专用）
//
// 原理: 把本目录放在引擎 include 搜索路径最前面，引擎 #include "SDL.h"
// 命中的是本垫片；垫片用 #include_next 引入真正的 SDL2 头文件，然后把
// ONScripter 用到的 SDL1.2 API 宏重定向到 onsdl_compat.cpp 的实现。
// 引擎源码零修改即可编译运行。
//
// 覆盖面（ONScripter 实际使用集）:
//   SDL_SetVideoMode / SDL_GetVideoSurface / SDL_Flip / SDL_UpdateRect(s)
//   SDL_WM_SetCaption / SDL_SetAlpha / SDL_EnableUNICODE / SDL_EnableKeyRepeat
//   SDL_ListModes / SDL_GetVideoInfo / SDL_SetGamma
//   SDL1.2 独有的 surface 标志常量
// 音频: SDL2 仍保留 SDL_OpenAudio/SDL_CloseAudio/SDL_PauseAudio 等 legacy API，
//       无需垫片。事件循环 SDL_PollEvent/SDL_PushEvent 两代兼容。
// =============================================================================
#ifndef ONSDL_COMPAT_H
#define ONSDL_COMPAT_H

#include <SDL2/SDL.h> // 真正的 SDL2（由 -I 顺序解析）

#ifdef __cplusplus
extern "C" {
#endif

// ---- SDL1.2 遗留类型/常量（iOS 无滚轮与键盘，仅供编译通过） ----
typedef SDL_Keycode SDLKey;   // SDL1.2: SDLKey → SDL2: SDL_Keycode

#ifndef SDL_BUTTON_WHEELUP
#define SDL_BUTTON_WHEELUP  4
#endif
#ifndef SDL_BUTTON_WHEELDOWN
#define SDL_BUTTON_WHEELDOWN 5
#endif

// SDL_VIDEOEXPOSE: SDL2 已移除该事件类型。映射到一个 SDL 永远不会产生的
// 保留事件值，使 case 标签可编译且运行期不可达（全屏 iOS 无 expose 场景）。
#ifndef SDL_VIDEOEXPOSE
#define SDL_VIDEOEXPOSE 0x7F00
#endif

// ---- SDL1.2 独有常量（SDL2 已移除/改名） ----
#ifndef SDL_SWSURFACE
#define SDL_SWSURFACE 0x00000000u
#endif
#define ONSDL_HWSURFACE       0x00000001u
#ifndef SDL_HWSURFACE
#define SDL_HWSURFACE ONSDL_HWSURFACE
#endif
#define ONSDL_ASYNCBLIT       0x00000004u
#ifndef SDL_ASYNCBLIT
#define SDL_ASYNCBLIT ONSDL_ASYNCBLIT
#endif
#define ONSDL_ANYFORMAT       0x10000000u
#ifndef SDL_ANYFORMAT
#define SDL_ANYFORMAT ONSDL_ANYFORMAT
#endif
#define ONSDL_HWPALETTE       0x20000000u
#ifndef SDL_HWPALETTE
#define SDL_HWPALETTE ONSDL_HWPALETTE
#endif
#define ONSDL_DOUBLEBUF       0x40000000u
#ifndef SDL_DOUBLEBUF
#define SDL_DOUBLEBUF ONSDL_DOUBLEBUF
#endif
#define ONSDL_FULLSCREEN      0x80000000u
#ifndef SDL_FULLSCREEN
#define SDL_FULLSCREEN ONSDL_FULLSCREEN
#endif
#define ONSDL_OPENGL          0x00000002u
#ifndef SDL_OPENGL
#define SDL_OPENGL ONSDL_OPENGL
#endif
#define ONSDL_RESIZABLE       0x00000010u
#ifndef SDL_RESIZABLE
#define SDL_RESIZABLE ONSDL_RESIZABLE
#endif
#define ONSDL_NOFRAME         0x00000020u
#ifndef SDL_NOFRAME
#define SDL_NOFRAME ONSDL_NOFRAME
#endif
#define ONSDL_HWACCEL         0x00000100u
#ifndef SDL_HWACCEL
#define SDL_HWACCEL ONSDL_HWACCEL
#endif
#define ONSDL_SRCALPHA        0x00010000u
#ifndef SDL_SRCALPHA
#define SDL_SRCALPHA ONSDL_SRCALPHA
#endif
#define ONSDL_RLEACCEL        0x00004000u
#ifndef SDL_RLEACCEL
#define SDL_RLEACCEL ONSDL_RLEACCEL
#endif
#define ONSDL_SRCCOLORKEY     0x00001000u
#ifndef SDL_SRCCOLORKEY
#define SDL_SRCCOLORKEY ONSDL_SRCCOLORKEY
#endif

// ---- SDL1.2 独有类型（若引擎引用） ----
#ifndef ONSDL_VIDEOINFO_DEFINED
#define ONSDL_VIDEOINFO_DEFINED
typedef struct SDL_VideoInfo {
    Uint32 hw_available :1;
    Uint32 wm_available :1;
    Uint32 blit_hw      :1;
    Uint32 blit_hw_CC   :1;
    Uint32 blit_hw_A    :1;
    Uint32 blit_sw      :1;
    Uint32 blit_sw_CC   :1;
    Uint32 blit_sw_A    :1;
    Uint32 blit_fill    :1;
    Uint32 video_mem;
    SDL_PixelFormat *vfmt;
    int  current_w;
    int  current_h;
} SDL_VideoInfo;
#endif

// ---- 兼容实现（见 onsdl_compat.cpp） ----
SDL_Surface  *SDL_Compat_SetVideoMode(int w, int h, int bpp, Uint32 flags);
SDL_Surface  *SDL_Compat_GetVideoSurface(void);
int           SDL_Compat_Flip(SDL_Surface *s);
void          SDL_Compat_UpdateRect(SDL_Surface *s, Sint32 x, Sint32 y, Sint32 w, Sint32 h);
void          SDL_Compat_UpdateRects(SDL_Surface *s, int n, SDL_Rect *rects);
void          SDL_Compat_SetCaption(const char *title, const char *icon);
int           SDL_Compat_SetAlpha(SDL_Surface *s, Uint32 flag, Uint8 alpha);
int           SDL_Compat_EnableUNICODE(int enable);
int           SDL_Compat_EnableKeyRepeat(int delay, int interval);
SDL_VideoInfo*SDL_Compat_GetVideoInfo(void);
void          onsdl_compat_shutdown(void);   // 停止引擎后由桥接层调用

// ---- SDL1.2 YUV overlay 类型（SDL2 已移除；类型参与编译，运行路径未启用） ----
typedef struct SDL_Overlay {
    Uint32  format;
    int     planes;
    Uint16  *pitches;
    Uint8   **pixels;
    Uint32  hw_overlay;
    Uint16  w, h;
} SDL_Overlay;

// ---- SDL1.2 app-state 常量与 SDL_GetAppState ----
#ifndef SDL_APPMOUSEFOCUS
#define SDL_APPMOUSEFOCUS  0x01
#endif
#ifndef SDL_APPINPUTFOCUS
#define SDL_APPINPUTFOCUS  0x02
#endif
#ifndef SDL_APPACTIVE
#define SDL_APPACTIVE      0x04
#endif
int           SDL_Compat_GetAppState(void);
#define SDL_GetAppState() SDL_Compat_GetAppState()

// ---- SDL1.2 独有 API 的桩 ----
#define SDL_WM_ToggleFullScreen(s)              (0)

// ---- SDL1.2 API -> 兼容实现 的宏重定向 ----
#define SDL_SetVideoMode(w,h,bpp,flags)        SDL_Compat_SetVideoMode((w),(h),(bpp),(flags))
#define SDL_GetVideoSurface()                  SDL_Compat_GetVideoSurface()
#define SDL_Flip(s)                            SDL_Compat_Flip((s))
#define SDL_UpdateRect(s,x,y,w,h)              SDL_Compat_UpdateRect((s),(x),(y),(w),(h))
#define SDL_UpdateRects(s,n,rs)                SDL_Compat_UpdateRects((s),(n),(rs))
#define SDL_WM_SetCaption(t,i)                 SDL_Compat_SetCaption((t),(i))
#define SDL_WM_GetCaption(t,i)                 do { if(t) *(t)=NULL; if(i) *(i)=NULL; } while(0)
#define SDL_SetAlpha(s,f,a)                    SDL_Compat_SetAlpha((s),(f),(a))
#define SDL_EnableUNICODE(e)                   SDL_Compat_EnableUNICODE((e))
#define SDL_EnableKeyRepeat(d,i)               SDL_Compat_EnableKeyRepeat((d),(i))
#define SDL_GetVideoInfo()                     SDL_Compat_GetVideoInfo()
#define SDL_ListModes(fmt, flags)              ((SDL_Rect **)0)
#define SDL_SetGamma(r,g,b)                    (0)
#define SDL_VideoModeOK(w,h,bpp,f)             (1)

// SDL2 的 SDL_SetColorKey 语义差异: SDL1.2 用 flag=SDL_SRCCOLORKEY|SDL_RLEACCEL，
// SDL2 用 SDL_TRUE/SDL_FALSE。非零值在 SDL2 中即 true，无需重定向。

#ifdef __cplusplus
}
#endif
#endif // ONSDL_COMPAT_H
