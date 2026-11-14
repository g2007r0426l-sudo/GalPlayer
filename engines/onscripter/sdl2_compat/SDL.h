// =============================================================================
// SDL.h 垫片 —— 引擎源码 #include "SDL.h" 时命中本文件。
// #include_next 跳过本目录，去拿真正的 SDL2 头文件，再叠加 SDL1.2 兼容宏。
// =============================================================================
#ifndef ONSDL_SHIM_SDL_H
#define ONSDL_SHIM_SDL_H
#include_next <SDL.h>
#include "onsdl_compat.h"
#endif // ONSDL_SHIM_SDL_H
