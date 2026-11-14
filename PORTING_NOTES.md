# PORTING_NOTES — 引擎整合技术细节

## 1. 统一 SDL2 运行时

两个引擎都跑在**同一份** libSDL2.a 上（iOS UIKit 后端）：

- 构建顺序: `engines/SDL2/build_ios.sh` 最先执行。若 Kirikiroid2 仓库自带 SDL2 fork
  （顶层 `SDL2/` 目录含 CMakeLists），则优先用它 —— Kirikiroid2 的渲染/音频层是围绕
  自己 fork 写的，统一 fork 可避免其核心与上游 SDL2 的 API 漂移；ONScripter 兼容层
  面向标准 SDL2 API，两种 fork 均可工作。
- **绝不同时链接两份 SDL**（符号冲突必炸），这是把 ONS 与 KRKR 都指向同一库的原因。
- iOS 17: SDL2 2.26+ 支持 UIWindowScene；构建脚本从 release-2.30.x 起尝试。

## 2. 引擎启动模型（引擎线程 + SDL_UIKitRunApp）

SDL2 iOS 后端的标准启动路径是 `SDL_UIKitRunApp(argc, argv, mainFunc)`：
它负责 UIApplicationDelegate 挂接、场景管理、UIKit 主线程与引擎线程的隔离。
因此桥接层（`Bridges/SDLTouchBridge.mm`）把引擎入口放到独立线程，经
`SDL_UIKitRunApp` 进入；引擎 `main` 由编译期 `-Dmain=<引擎名>_entry/ons_main` 重命名。

- 退出：推送 `SDL_QUIT` → 引擎走自身退出路径 → `SDL_UIKitRunApp` 返回 →
  `onsdl_compat_shutdown()`（ONS）→ Swift 收到 stopped 回调 → 主窗口重新 makeKeyAndVisible。
- 反复进出：SDL_UIKitRunApp 每次 SDL_Init/SDL_Quit 完整成对；兼容层在 SDL_QUIT
  事件观察器里自拆窗口/渲染器/纹理；触控状态在会话边界重置。

## 3. 触控三件套（App 层统一语义）

- **ONScripter**: `SDL_HINT_TOUCH_MOUSE_EVENTS=0` 关掉系统级手指→鼠标合成，
  由 `SDLTouchBridge.mm` 自己映射（事件观察器 + 监控线程）：
  - 单指 down → 鼠标移动 + 左键 down；up → 左键 up（= 单击推进）
  - 双指在 400ms 内轻点 → 右键 down/up（= 呼出引擎菜单）
  - 单指按住 ≥450ms → 结束原始按压 → **Ctrl 按住**（ONScripter 的 skip 语义）
    + 周期左键连点（间隔 = 160ms/文字速度，0.25x→640ms，4x→40ms）= 持续快进
- **Kirikiri**: `touchToMouse=false`，Kirikiroid2 自带 SDL 触控处理
  （单击推进/双指右键菜单/长按跳过），与 App 层手势约定一致，直接走引擎原生路径。

> 若实机发现 Kirikiroid2 原生触控在某 SDL fork 上失效，把 `KrkrBridge.mm` 里
> `ctx.touchToMouse = false` 改为 `true` 即可切到 App 层映射（一键兜底）。

## 4. ONScripter 为什么走"兼容层"而不是改源码

### 4.1 实测得到的 SDL1.2 → SDL2 兼容矩阵（全部经过 iOS 真机链路编译验证）

**shim 层（`engines/onscripter/sdl2_compat/onsdl_compat.h`，零源码改动）**

| SDL1.2 符号 | SDL2 处理 |
|---|---|
| `SDL_SetVideoMode` / `SDL_GetVideoSurface` / `SDL_Flip` / `SDL_UpdateRect(s)` | 自研 compat 实现（SDL_Window + SDL_Renderer + ARGB8888 流式纹理） |
| `SDL_SetAlpha` | `SDL_SetSurfaceAlphaMod` + `SDL_SetSurfaceBlendMode` |
| `SDL_WM_SetCaption` / `SDL_WM_GetCaption` | `SDL_SetWindowTitle` |
| `SDL_EnableUNICODE` / `SDL_EnableKeyRepeat` / `SDL_GetWMInfo` | 空桩 |
| `SDL_ListModes` / `SDL_GetVideoInfo` / `SDL_SetGamma` | 桩（返回 NULL / 静态结构 / 0） |
| `SDL_Overlay`（YUV 视频帧） | 结构体类型定义（仅编译需要；smpeg/ANDROID 宏内不执行） |
| `SDL_GetAppState` | 桩（恒返回前台聚焦） |
| `SDL_WM_ToggleFullScreen` | 宏替换为 `(0)` |
| `SDLKey` | `typedef SDL_Keycode SDLKey` |
| `SDL_BUTTON_WHEELUP/DOWN` | 常量 4/5（iOS 无滚轮，仅供编译） |
| `SDL_VIDEOEXPOSE` | 保留事件值 0x7F00（SDL 永不产生，运行期不可达） |

**源码补丁层（`patch_ons_sources.py`，Python 确定性替换 + 自动备份）**

| 原符号 | 替换 | 原因 |
|---|---|---|
| `keysym.unicode` | `keysym.sym` | SDL2 移除 unicode 字段 |
| `SDL_ACTIVEEVENT` / `event.active.*` | `SDL_WINDOWEVENT` / `event.window.data*` | 事件模型变更 |
| `SDL_WarpMouse(` | `SDL_WarpMouseInWindow(NULL, ` | 函数改名 |
| `SDL_mutexP(` / `SDL_mutexV(` | `SDL_LockMutex(` / `SDL_UnlockMutex(` | 宏移除 |
| `SDLK_KP0..9` | `SDLK_KP_0..9` | 键名加下划线 |
| `Mix_LoadMUS_RW(x)` | `Mix_LoadMUS_RW(x, 1)` | SDL_mixer 2.8 签名变更 |

**⚠ 血泪教训**：`sed -i '' -E` 在 macOS runner 上会**静默失败**（补丁打印成功但文件未改）。
改为 Python 字符串替换后一次通过 —— 任何跨平台补丁脚本都应避免 shell sed 方言。

### 4.2 构建依赖清单（实测）

`SDL2`（`SDL_LIBC` 保持默认；`SDL_config.h` 必须用 **CMake 生成版**，源码模板版会导致
`Sint64` 断言失败）· `SDL_image`（`SDL2IMAGE_BACKEND_IMAGEIO=OFF` + `STB=ON`）·
`SDL_ttf`（`SDL2TTF_VENDORED=ON`，头文件在 2.20 的仓库根部）·
`SDL_mixer`（关 OPUS/MOD/MIDI/WAVPACK，保留 WAV/OGG/FLAC/MP3 内置解码）·
`libjpeg-turbo`（`CMAKE_SYSTEM_PROCESSOR=arm64` 必传）· `libogg/libvorbis/libvorbisfile` · `freetype`

## 5. Kirikiroid2 构建脚本的自适应设计

官方 ONScripter（含 JH）基于 SDL 1.2。方案对比：

| 方案 | 结论 |
|---|---|
| 引擎源码大改迁 SDL2 | 侵入面大、每个版本都要重做 |
| 换 SDL2 系 fork（如 PONScripter） | CJK/GBK 编码链路与 JH 行为有差异，风险高 |
| **include 垫片 + 少量带守卫补丁（采用）** | 引擎源码零修改（仅 3 类机械替换），兼容层约 300 行，可控可修 |

兼容层覆盖面（引擎实际使用集）：`SDL_SetVideoMode / SDL_GetVideoSurface /
SDL_Flip / SDL_UpdateRect(s) / SDL_WM_SetCaption / SDL_SetAlpha /
SDL_EnableUNICODE / SDL_EnableKeyRepeat / SDL_ListModes / SDL_GetVideoInfo /
SDL_SetGamma` + SDL1.2 surface 标志常量。音频走 SDL2 保留的 legacy
`SDL_OpenAudio` 系列，无需垫片。

**屏幕适配实现**：兼容层拥有 renderer —— 原始比例 = `SDL_RenderSetLogicalSize(w,h)`
（自动居中黑边）；拉伸全屏 = 取消逻辑尺寸直接铺满。Kirikiri 侧由 Kirikiroid2
原生等比缩放（stretch 模式一期不作用于 KRKR，属已知限制）。

**机械补丁**（`patch_ons_sources.sh`，全部 grep 守卫 + 备份 .orig）：
1. `keysym.unicode` → `keysym.sym`（SDL2 移除 unicode 字段）
2. `SDL_ACTIVEEVENT`/`event.active.*` → `SDL_WINDOWEVENT`/`event.window.*`
3. 移除直连的 `SDL_EnableKeyRepeat/SDL_EnableUNICODE/SDL_GetWMInfo` 调用

## 5. Kirikiroid2 构建脚本的自适应设计

无法在编写时假设上游目录布局永不变，脚本做了：

- **doctor 输出**：clone 后打印顶层目录，人工一眼可查
- **平台目录排除**：`windows|win32|project/jni|android|wii|psp` 等目录不参与编译
- **include 目录自动收集**：把仓库内所有含 .h 的目录加进 -I（kirikiri 头文件扁平分散）
- **入口自动探测**：grep `int main(` 找到入口 TU 后用 `-Dmain=krkr_entry` 重命名；
  多个 TU 含 main 时打印全部，编译失败时输出前 30 行错误 + 修复指引
- 若核心依赖仓库内置 third_party（boost/oniguruma 等），按报错提示把对应目录补进 INCS

## 6. 存档落盘

引擎线程 `chdir(游戏目录)` 后启动：
- ONScripter → `save.dat` 写在 cwd = 游戏目录
- Kirikiri → KAG `savedata/` 写在游戏目录
- 目录属主为 mobile，App 以 mobile 运行，直接可写（越狱环境无沙盒限制）

## 7. 已知限制（MVP 一期）

| 项 | 说明 |
|---|---|
| Kirikiri 拉伸全屏 | 一期走引擎原生等比（Kirikiroid2 未暴露拉伸入口）；ONS 完整支持两模式 |
| 设置页"文字速度" | 映射为长按快进节奏（两引擎统一）；游戏内逐字速度由引擎自带菜单调节 |
| ONS MP3/视频 | smpeg 未编入（MP3/OGM 无声无画面）；NWA/WAV/OGG 正常 |
| 16bpp 直绘路径 | 兼容层统一 32bpp ARGB8888，极少数按 16bpp 写死的游戏花屏 → 后续按需补 |
| Kirikiri xp3 filter | 私有加密 xp3（带自定义 filter 的游戏）一期不支持 |
| SDL_UIKitRunApp 与自定义 AppDelegate | SDL 会接管生命周期回调；横屏由 Info.plist + AppDelegate 双保险 |

## 8. 实机验收对照表（§6 验收标准）

| # | 验收项 | 状态 |
|---|---|---|
| 1 | KRKR 游戏入目录→列表→全屏运行→有声→存档 | 代码路径完成，待实机跑 |
| 2 | ONS 游戏（nscript.dat）同流程 | 代码路径完成，待实机跑 |
| 3 | 5 个游戏（含 root.pfs）分类正确，Artemis 标灰 | Scanner 已实现 |
| 4 | 触控三件套 | SDLTouchBridge 已实现 |
| 5 | 全局设置三项真实生效 | 适配(ONS)/快进节奏/音量(MPVolumeView) 已实现 |
| 6 | .deb Filza 安装、图标出现/消失 | packaging 齐备（postinst/postrm） |
| 7 | 反复进出 5 次不崩不漏 | 兼容层自拆 + SDL_Quit 成对；用 Xcode Memory Graph 实测 |
| 8 | 无网络请求 | 全工程无网络调用；Instruments/Proxyman 验证 |
