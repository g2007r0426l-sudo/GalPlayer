// =============================================================================
// ONSMain.mm — ONScripter 独立播放器 App 入口（SDL2 应用标准结构）
//
// 为什么是独立 App：SDL2 的 iOS 后端通过 SDL_UIKitRunApp 内部调用
// UIApplicationMain，一个进程只能调用一次且必须在 main 线程。
// 因此在已有 UIKit App（GalPlayer）里进程内启动 SDL 引擎会崩溃
// （实测：UIApplicationInstantiateSingleton 抛异常 SIGABRT）。
//
// 标准做法：让 SDL 应用自己拥有整个 App 生命周期。
//   GalPlayer（UI 外壳）写标记文件 → LSApplicationWorkspace 拉起本 App →
//   本 App 的 main() 直接 SDL_UIKitRunApp(engine) → 引擎全屏接管。
// =============================================================================
#import <UIKit/UIKit.h>

#define SDL_MAIN_HANDLED 1
#include <SDL.h>

#include <cstdio>
#include <cstdlib>

// 由 ONSGlue.mm 提供：读标记文件 / 切换工作目录 / 装触控映射 / 调 ons_main
int GP_ONS_Entry(int argc, char **argv);

int main(int argc, char *argv[]) {
    fprintf(stderr, "[ONSApp] main() 启动\n");
    return SDL_UIKitRunApp(argc, argv, GP_ONS_Entry);
}
