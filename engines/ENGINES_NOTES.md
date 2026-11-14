# GalPlayer 引擎整合说明（必读）

本目录下的三个引擎构建脚本负责：拉取源码 → 探测目录结构 → 编译 iOS arm64 静态库。
所有源码都在**构建时**从官方仓库现场拉取，并自动把实际解析出的 commit 记录到
`THIRD_PARTY_RESOLVED.md`（工程根目录）。

## 目录

```
engines/
├── SDL2/build_ios.sh          # 构建 libSDL2.a（iOS arm64，UIKit 后端）
├── onscripter/
│   ├── build_ios.sh           # 构建 libons.a（ONScripter-JH / 官方版 + SDL1.2 兼容层）
│   └── sdl2_compat/           # 我们自研的 SDL1.2→SDL2 视频兼容层（ONScripter 专用）
├── kirikiroid2/build_ios.sh   # 构建 libkrkr2.a（Kirikiroid2 核心，剥离 Android 胶水层）
└── fonts/                     # CJK 兜底字体（首次构建时脚本会自动下载）
```

## 构建产物

统一输出到工程根目录 `build/ios/`：

```
build/ios/lib/libSDL2.a  libons.a  libkrkr2.a  libfreetype.a  [libvorbis.a libogg.a]
build/ios/include/...    # 对应头文件
```

## 关键设计决策

1. **SDL 统一运行时**：两个引擎都链接同一份 `libSDL2.a`。SDL2（2.30.x）自带
   UIKit 后端，支持 iOS 17 的 UIWindowScene。若 Kirikiroid2 仓库自带 SDL2 fork
   （`kirikiroid2/SDL2/` 存在 CMakeLists），`engines/SDL2/build_ios.sh` 会优先
   用它的 fork，保证 Kirikiroid2 用它自己熟悉的 SDL 版本，ONScripter 用兼容层
   走同一份 SDL2 —— 避免两份 SDL 符号冲突。

2. **ONScripter 不改源码走 SDL2**：官方 ONScripter / JH 版基于 SDL 1.2。
   我们提供 `sdl2_compat/`（约 300 行），实现 ONScripter 实际用到的 SDL1.2 面：
   `SDL_SetVideoMode / SDL_GetVideoSurface / SDL_Flip / SDL_UpdateRect /
   SDL_SetAlpha / SDL_EnableUNICODE` 等。引擎源码不改，编译时把兼容层 include
   目录放在最前面即可。已知零星不兼容（如 `keysym.unicode`）由
   `patch_ons_sources.sh` 用带 grep 守卫的 sed 修补，全部动作有日志。

3. **Kirikiroid2 剥离 Android 胶水层**：编译 `kirikiri2/` 目录下核心源码，
   排除 Windows/Android 平台目录，入口 main 由脚本 grep 自动探测并用
   `-Dmain=krkr_entry` 重命名（详见 `PORTING_NOTES.md`）。若上游布局变化，
   脚本会打印探测结果与修复指引，而不是静默出错。

4. **触控统一在 SDL 事件层**：App 桥接层（`app/GalPlayer/Bridges/SDLTouchBridge.mm`）
   实现 单击→左键 / 双指→右键 / 长按→快进（Ctrl 按住 + 连点节流），
   两个引擎行为一致。Kirikiri 引擎自身触控处理更完整时走引擎原生路径
   （`touchToMouse=false`），由 GameSession 按引擎配置。

5. **字体**：打包内置 DroidSansFallback.ttf（Apache 2.0）。构建脚本自动下载，
   下载失败会明确提示手动放置；App 运行时也会把字体路径传给引擎。
