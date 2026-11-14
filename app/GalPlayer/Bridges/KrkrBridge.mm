// =============================================================================
// KrkrBridge.mm — Kirikiri2（Kirikiroid2 核心）启动胶水
//
// 引擎经 engines/kirikiroid2/build_ios.sh 编译，入口用 -Dmain=krkr_entry 重命名。
// 剥离 Android 胶水层后的核心以 SDL2 桌面式 main() 运行:
//   argv[1] = data.xp3 路径（或项目目录）
//
// 触控: Kirikiroid2 自带完整触控处理（单击推进/双指菜单/长按跳过），
//       与 App 层手势约定一致，故 touchToMouse=false 走引擎原生路径。
// 字体: 把内置 CJK 字体同时放到引擎常见查找位置（font/ 子目录与游戏根目录）。
// =============================================================================
#include "EngineRuntime.hpp"

#include <sys/stat.h>

// 引擎入口（由 build_ios.sh 的 -Dmain=krkr_entry 重命名；全局 C++ 符号，勿加 extern "C"）
int krkr_entry(int argc, char **argv);

namespace gp {

int launchKrkr(LaunchCtx ctx) {
    ctx.touchToMouse = false; // Kirikiroid2 原生触控

    // 字体就位（Kirikiroid2 会尝试游戏目录内 font/ 或根目录的 TTF）
    if (!ctx.fontPath.empty()) {
        ensureDir(ctx.gameDir + "/font");
        copyFontIfNeeded(ctx.fontPath, ctx.gameDir + "/font/DroidSansFallback.ttf");
        copyFontIfNeeded(ctx.fontPath, ctx.gameDir + "/DroidSansFallback.ttf");
    }

    // 数据包: data.xp3（或扫描到的第一个 .xp3）；缺失时传目录本身
    ctx.args.clear();
    ctx.args.push_back("kirikiri");
    if (!ctx.dataFile.empty()) {
        ctx.args.push_back(ctx.gameDir + "/" + ctx.dataFile);
    } else {
        ctx.args.push_back(ctx.gameDir);
    }

    // 工作目录 = 游戏目录，Kirikiri 存档(save.dat 等)直接落在游戏目录内
    return launchEngine(krkr_entry, std::move(ctx));
}

} // namespace gp
