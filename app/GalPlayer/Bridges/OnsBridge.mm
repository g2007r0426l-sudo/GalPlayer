// =============================================================================
// OnsBridge.mm — ONScripter 启动胶水
//
// 引擎源码经 engines/onscripter/build_ios.sh 编译时用 -Dmain=ons_main 重命名入口；
// 本文件声明该符号（全局作用域，与引擎侧一致），并做 ONS 特有准备:
//   - 兜底字体拷贝为引擎默认字体文件 default.ttf（引擎在 cwd 查找）
//   - SDL1.2 兼容层适配模式（原始比例/拉伸全屏）
//   - 传入脚本文件名（nscript.dat 优先，其次 0.txt）
// =============================================================================
#include "EngineRuntime.hpp"

#include <sys/stat.h>

// 引擎入口（由 build_ios.sh 的 -Dmain=ons_main 重命名；全局 C++ 符号，勿加 extern "C"）
int ons_main(int argc, char **argv);

// SDL1.2 视频兼容层的适配模式开关（engines/onscripter/sdl2_compat/onsdl_compat.cpp）
extern "C" void onsdl_set_scale_mode(int stretch);

namespace gp {

static bool fileExists(const std::string &p) {
    struct stat st;
    return ::stat(p.c_str(), &st) == 0 && S_ISREG(st.st_mode);
}

int launchOns(LaunchCtx ctx) {
    ctx.touchToMouse = true; // 触控统一映射由 SDLTouchBridge 负责

    // 1. 字体: ONScripter 在游戏目录内查找 default.ttf
    if (!ctx.fontPath.empty()) {
        copyFontIfNeeded(ctx.fontPath, ctx.gameDir + "/default.ttf");
    }

    // 2. 屏幕适配模式（必须在引擎 SDL_SetVideoMode 之前设置）
    onsdl_set_scale_mode(ctx.stretch ? 1 : 0);

    // 3. 脚本定位: 显式传参比引擎隐式探测更稳
    ctx.args.clear();
    ctx.args.push_back("onscripter");
    if (fileExists(ctx.gameDir + "/nscript.dat")) {
        ctx.args.push_back("nscript.dat");
    } else if (fileExists(ctx.gameDir + "/0.txt")) {
        ctx.args.push_back("0.txt");
    }
    // 都没有: 交给引擎默认探测（部分 JH 版本会自动找 0.txt）

    // 工作目录会被 launchEngine 切到 gameDir，引擎存档 save.dat 直接落在游戏目录内
    return launchEngine(ons_main, std::move(ctx));
}

} // namespace gp
