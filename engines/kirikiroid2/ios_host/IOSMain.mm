// =============================================================================
// IOSMain.mm — Kirikinux2 (Kirikiroid2 引擎) 的 iOS 宿主入口
//
// 对应 Kirikinux2 的 platform/linux/LinuxMain.cpp（Linux 桌面版入口）：
//   - Linux 用 GLFW 窗口；iOS 由 cocos2d-x 的 UIKit 集成提供全屏窗口
//   - 启动参数通过 TVPLinuxStartupArgs 传入（与 Linux/Android 同一套符号）：
//       GalPlayer 桥接层把游戏目录写入 /var/mobile/Documents/Galgames/.krkr_launch
//       本入口读取后填入 TVPLinuxStartupArgs，TVPCheckStartupArg() 自动启动游戏
//   - 退出路径沿用 TVPLinuxQuickExit（跳过静态析构）
// =============================================================================
#import <UIKit/UIKit.h>
#include "cocos2d.h"
#include "AppDelegate.h"   // src/core/environ/cocos2d/AppDelegate.cpp (TVPAppDelegate)

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

// 由 IOSUtils.cpp 提供（与 LinuxUtils.cpp 同名符号，核心层无需改动）
extern std::vector<std::string> TVPLinuxStartupArgs;
void TVPLinuxInstallCrashHandler();   // iOS 版为桩（见 KR2IOSStubs.cpp）
void TVPLinuxQuickExit(int code);

// GalPlayer 写入的启动标记：第一行 = 游戏目录或 xp3 路径，其余行 = name=value
static const char *K2_LAUNCH_MARKER = "/var/mobile/Documents/Galgames/.krkr_launch";

static void _LoadLaunchMarker() {
    FILE *fp = fopen(K2_LAUNCH_MARKER, "r");
    if (!fp) return;
    char line[1024];
    bool first = true;
    while (fgets(line, sizeof(line), fp)) {
        size_t n = strlen(line);
        while (n && (line[n-1] == '\n' || line[n-1] == '\r')) line[--n] = 0;
        if (!n) continue;
        if (first) {
            TVPLinuxStartupArgs.push_back("kirikinux2"); // argv[0] 占位
            TVPLinuxStartupArgs.push_back(line);
            first = false;
        } else {
            TVPLinuxStartupArgs.push_back(line);
        }
    }
    fclose(fp);
    unlink(K2_LAUNCH_MARKER); // 一次性消费
}

// 定向启动时隐藏 kirikinux2 自带的文件选择界面：有启动参数时 TVPCheckStartupArg
// 会直接 startupFrom()；没有标记（用户从图标直接打开）时进入引擎自带游戏库。
@interface K2AppController : NSObject <UIApplicationDelegate>
@end

@implementation K2AppController

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    _LoadLaunchMarker();

    GLContextAttrs attrs = {8, 8, 8, 8, 24, 8};
    cocos2d::GLView::setGLContextAttrs(attrs);

    static TVPAppDelegate appInstance; // 静态实例，进程存续期内有效
    (void)appInstance;

    auto glview = cocos2d::GLViewImpl::createWithFullScreen("Kirikinux2");
    if (!glview) {
        fprintf(stderr, "Kirikinux2: could not create the GL view\n");
        exit(1);
    }
    cocos2d::Director::getInstance()->setOpenGLView(glview);

    // cocos iOS 路径: Application::run() 由 CCApplication-ios 驱动主循环
    cocos2d::Application::getInstance()->run();
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {}
- (void)applicationDidEnterBackground:(UIApplication *)application {}
- (void)applicationWillEnterForeground:(UIApplication *)application {}
- (void)applicationDidBecomeActive:(UIApplication *)application {}
- (void)applicationWillTerminate:(UIApplication *)application {}

@end

int main(int argc, char *argv[]) {
    TVPLinuxInstallCrashHandler();
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"K2AppController");
    }
}
