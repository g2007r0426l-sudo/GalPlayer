// =============================================================================
// EngineBridge.h — GalPlayer 引擎桥接 C ABI（Swift 通过 Bridging Header 调用）
//
// 两个引擎（Kirikiri2 / ONScripter）统一由 SDL2 运行时承载:
//   - 引擎 main 在独立线程经 SDL_UIKitRunApp 启动
//   - 触控语义统一映射（单击=左键 / 双指=右键 / 长按=快进）
//   - 退出时推送 SDL_QUIT，引擎自然走完退出路径，资源干净释放
// =============================================================================
#ifndef ENGINE_BRIDGE_H
#define ENGINE_BRIDGE_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    GP_ENGINE_KIRIKIRI   = 0,
    GP_ENGINE_ONSCRIPTER = 1,
} GP_EngineKind;

/// 异步启动引擎（立即返回；0=已启动，非0=失败原因码）
///   kind               GP_ENGINE_KIRIKIRI / GP_ENGINE_ONSCRIPTER
///   gameDir            游戏目录绝对路径（含 data.xp3 或 nscript.dat / 0.txt）
///   fontPath           兜底 CJK 字体绝对路径（可 NULL；桥接层会拷成引擎约定文件名）
///   dataFile           Kirikiri: .xp3 文件名（相对 gameDir；NULL 时自动取第一个 .xp3）
///   stretchFullscreen  1=拉伸全屏 0=原始比例（ONS 完整生效；KRKR 走引擎原生等比）
///   textSpeed          0.25 ~ 4.0，作用于"长按快进"的点击节流
int  GP_EngineStart(int kind,
                    const char *gameDir,
                    const char *fontPath,
                    const char *dataFile,
                    int stretchFullscreen,
                    float textSpeed);

/// 请求停止引擎（推送 SDL_QUIT，引擎走自身退出路径）
void GP_EngineStop(void);

/// 引擎是否在运行
int  GP_EngineIsRunning(void);

/// 引擎完全退出后的回调（在引擎线程上触发；Swift 侧自行转主线程）
void GP_SetStoppedCallback(void (*cb)(void));

#ifdef __cplusplus
}
#endif
#endif // ENGINE_BRIDGE_H
