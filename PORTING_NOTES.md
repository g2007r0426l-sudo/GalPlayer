# GalPlayer 移植要点（实战记录）

> 全部结论来自真机（iPad Pro 10.5 / iPadOS 17.5.1 / palera1n rootless）实测，
> 不是理论推测。踩过的坑与对应解法都记在这里。

---

## 一、架构：为什么是「三个 App」

| App | 角色 |
|---|---|
| **GalPlayer** | 纯 Swift/UIKit 界面：扫描游戏库、识别引擎、设置 |
| **OnsPlayer** | ONScripter 播放器（SDL2 生命周期自持） |
| **Kirikinux2** | Kirikiri2 播放器（cocos2d-x，二期） |

### 1.1 不能在主 App 里进程内启动 SDL

最初设计是在 GalPlayer 进程里用后台线程调 `SDL_UIKitRunApp`，真机直接崩：

```
UIApplicationMain            ← 重复调用
SDL_UIKitRunApp
gp::engineThreadMain
→ UIApplicationInstantiateSingleton 抛异常 → SIGABRT
```

`SDL_UIKitRunApp` 内部会调 `UIApplicationMain`，**一个进程只能调一次、必须在主线程**。
因此引擎必须独占一个 App 生命周期：GalPlayer 写标记文件 → `LSApplicationWorkspace`
拉起播放器 → 播放器读标记（一次性消费）后进游戏。

---

## 二、GPU 不可用：UIKit 直贴像素

真机探针结果（这是本项目最关键的发现）：

```
probe MTLDevice=nil
driver[0]=metal      → Failed to obtain Metal device
driver[1]=opengles2  → GL ES 2 context could not be created
driver[2]=opengles   → GL ES 1 context could not be created
```

**当前越狱环境下 App 进程拿不到 GPU 直连**（Metal/GLES 全部失败），
但 CoreAnimation 合成是系统代办的，所以 UIKit 界面照常显示。

### 解法：presenter 回退链路

```
引擎像素 (ARGB8888)
   ↓  onsdl_set_presenter 回调
CGImage(CGBitmapContextCreateImage, kCGImageAlphaPremultipliedFirst|32Little)
   ↓
CALayer.contents  ← 系统合成器直接上屏，全程不需要 GPU 客户端
```

- 兼容层先尝试 metal → opengles2 → opengles → software
- 全部失败且已注册 presenter 时，`g_usePresenter = true`，`SetVideoMode` 仍返回合法 surface
- 触摸不再依赖 SDL 的事件通道：自建 `UIWindow`（层级高于 SDL 窗口）+ 自绘视图，
  触摸直接合成 `SDL_MouseButtonEvent` 推进引擎事件队列
  - 单击 = 左键推进
  - 双指轻点 = 右键（呼出菜单）
  - 长按 ≥450ms = 按住 Ctrl + 连点（快进）


### 2.1 GPU 权限的最终结论（两处独立探针）

| 探针位置 | 时机 | 结果 |
|---|---|---|
| OnsPlayer（SDL 启动早期，UIApplicationMain 之前） | 引擎入口 | `MTLDevice=nil` |
| GalPlayer（纯 UIKit App，`didFinishLaunching` 末尾） | App 启动 | `MTLDevice=nil` |

两处都拿不到 Metal 设备，且加 `platform-application` 等 entitlements 后依旧为 nil
→ **这是该越狱环境对侧载 App 的全局 GPU 限制**，不是 SDL 初始化时机问题。

因此：
- 任何依赖 GL/Metal 的渲染方案（cocos2d-x/Kirikiroid2、SDL 的 metal/opengles 后端）在本机不可用
- 唯一可行路径是「CPU 渲染 + `CALayer.contents` 交给系统合成器」——ONScripter 正是这么做的

---

## 三、ONScripter 接入细节

### 3.1 参数陷阱

`onscripter_main.cpp` 的参数循环**只接受 `-` 开头的选项**，传裸目录会走
`optionHelp()` → `exit(0)`。而我们已经在入口 `chdir()` 到游戏目录，
所以启动时不传任何参数（引擎自己按 `0.txt` → `00.txt` → `nscript.dat` → `nscript.___` 顺序探测）。

### 3.2 exit() 与静态线程

`optionHelp()` 里的 `exit()` 会跑静态析构；若此时还有 joinable 的
`static std::thread`，会触发 `std::terminate` → `abort`。
→ 监控线程改为堆分配 + `detach()`。

### 3.3 字体

引擎缺 TTF 会直接报 `can't open font file: default.ttf` 并退出。
做法：包内带 `DroidSansFallback.ttf`，启动时以 `-f <包内路径>` 传给引擎；
若游戏目录自带 `default.ttf` 则不传（尊重作者字体）。

> 踩坑：`fetch_fonts.sh` 的 `ROOT_DIR` 少算一级，字体被下到 `engines/app/...`，
> 导致 App 包里根本没有字体（表现为 `font candidates=1`）。

### 3.4 默认编码改为 UTF-8

真机日志：`ONScripter version 20230825(2.96)` 之后默认 `CODE_CP932`，
实测日文脚本被解成半角片假名乱码。改为默认 `CODE_UTF8` 后：

```
`こんにちは　ギャルゲー     ✅
`中文测试 中文测试          ✅
`ABCabc 123                ✅
```

> 注意：UTF-8 模式下文本标记不是反引号，实际游戏用各自正确的标记即可。
> 纯 Shift-JIS 老游戏如需原样运行，可把脚本转成 UTF-8 再用（编码转换不改变剧情内容）。

---

## 四、构建链上的硬坑

| 现象 | 真因 | 解法 |
|---|---|---|
| `Sint64 == 4` 静态断言 / `unknown type name size_t` | SDL 用了源码模板 `SDL_config.h` | 强制用 CMake 生成版，并 `grep HAVE_STDINT_H` 校验 |
| `SDL_strcmp/SDL_strlen` 未定义 | SDL2 静态库未含 stdlib 符号 | 单独编 `libSDL2stdlib.a`（后来改用正确的 libSDL2.a 后不再需要） |
| 链接报 126 个重复符号 | `-all_load` 同时加载 stdlib 备份库与 SDL2 本体 | 移除 `-lSDL2stdlib` |
| `libSDL2.a` 里没有 SDL_Init | `find libSDL2*.a` 拷贝到了 `libSDL2main.a` | 精确按文件名取 `libSDL2.a` |
| `ldid.cpp(3332) _assert errno=2` | `sign.sh` 硬编码 `GalPlayer` 二进制名 | 从 `CFBundleExecutable` 读取 |
| `unbound variable: APP` / `COMMIT` | 全角括号紧贴 `$VAR`，bash 把括号算进变量名 | 一律写 `${VAR}` |
| `dpkg-deb: tar --warning=no-timestamp not supported` | 设备自带 tar 太老 | 打包在 CI 完成；装机改走 tar 流式上传 + 手工签名 + uicache |
| `Parsing project spec failed` | YAML 里用 `;` 分隔多个值 | 每个值单独一行 |

---

## 五、装机（免 dpkg）

设备 `dpkg` 依赖的 `tar` 太老会失败，改为等价手工流程：

1. 本地解 `.deb`：ar → `data.tar.gz` → 解出 `*.app`
2. tar 流式上传到 `/var/jb/Applications/`
3. `chown -R root:wheel` + `chmod -R 755`
4. 逐文件 `ldid -S`（只签主程序会崩：`mapped file has no cdhash`）
5. `uicache -p <app>` 注册图标
6. `uiopen -b com.yg.galplayer` 启动

脚本：`scripts/install_latest.py`（自动下载最新成功产物并完成以上全部步骤）。

---

## 六、当前状态

| 能力 | 状态 |
|---|---|
| 可爱 UI（侧边栏/大卡/网格/搜索/设置） | ✅ 真机可用 |
| 二次元封面（8 张内置图池 + 横版大卡图） | ✅ |
| App 图标 | ✅ |
| ONScripter 引擎：视频/音频/文字/触摸 | ✅ 真机验证 |
| .deb 打包（双 App） | ✅（15MB） |
| Kirikiri2 引擎 | 🔄 二期（cocos2d-x iOS 平台层） |
