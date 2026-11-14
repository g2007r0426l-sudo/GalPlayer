# GalPlayer

越狱 iPad 本地视觉小说（Galgame）播放器 · MVP 第一期（Kirikiri2 + ONScripter）

对标「咔咔喵 / Galplay」的核心体验：把游戏文件夹放进平板指定目录 → App 自动识别引擎 → 点击即玩。
**仅本地播放**：无联网、无账号、无广告、无统计、无任何授权校验相关功能。

## 支持引擎（一期）

| 引擎 | 识别特征 | 来源 | 状态 |
|---|---|---|---|
| Kirikiri2（KAG） | 目录内任意 `*.xp3` | Kirikiroid2（剥离 Android 胶水层） | ✅ |
| ONScripter | `nscript.dat` 或 `0.txt` | ONScripter-JH / 官方版 + 自研 SDL1.2→SDL2 兼容层 | ✅ |
| Artemis | `root.pfs` | — | ⛔ 一期不支持，列表标灰，建议用 Artroid+ |
| 未知 | — | — | 可长按卡片手动指定引擎 |

## 环境要求

**目标设备**
- iPad Pro 10.5（iPad7,3）或任意 arm64 iPad，iPadOS 14.0+（实机验证环境: 17.5.1）
- 越狱: palera1n rootless（`/var/jb`），兼容 checkra1n / Taurine 等（rootful 自动走 `/Applications`）
- 设备组件: AppSync Unified（装自签 App）、Filza、Sileo、dropbear（127.0.0.1:44）

**构建机（Mac）**
- macOS + Xcode 15+
- `brew install cmake ninja xcodegen ldid dpkg libimobiledevice`

## 目录结构

```
GalPlayer/
├── app/                        # Xcode 工程（Swift + ObjC++ 桥接）
│   ├── project.yml             # XcodeGen 定义（xcodegen generate 出 .xcodeproj）
│   └── GalPlayer/
│       ├── AppDelegate.swift           # 纯代码，无 storyboard/XIB
│       ├── UI/                         # 列表页 / 设置页 / 弹层（纯代码 UIKit）
│       ├── Core/
│       │   ├── Scanner.swift           # 扫描 + 引擎识别 + index.json 缓存
│       │   ├── EngineRegistry.swift    # 引擎注册表（手动指定覆盖）
│       │   └── GameSession.swift       # 统一引擎会话管理
│       └── Bridges/
│           ├── EngineBridge.h          # C ABI（Swift ↔ C）
│           ├── SDLTouchBridge.mm       # 引擎线程 + 触控三件套映射
│           ├── OnsBridge.mm            # ONScripter 启动胶水
│           └── KrkrBridge.mm           # Kirikiri 启动胶水
├── engines/
│   ├── SDL2/build_ios.sh               # libSDL2.a（iOS arm64，UIKit 后端）
│   ├── onscripter/build_ios.sh         # libons.a（含 sdl2_compat 兼容层）
│   ├── onscripter/sdl2_compat/         # SDL1.2→SDL2 视频兼容层（约 300 行）
│   ├── kirikiroid2/build_ios.sh        # libkrkr2.a（剥离 Android 层）
│   └── fonts/fetch_fonts.sh            # CJK 兜底字体
├── packaging/
│   ├── control / postinst / prerm / postrm
│   └── build_deb.sh
├── scripts/
│   ├── build_all.sh                    # 一键全量构建
│   ├── build_app.sh                    # xcodegen + xcodebuild
│   ├── sign.sh                         # ldid 递归签名
│   └── install_device.sh               # USB SSH 推送安装
├── README.md / TROUBLESHOOTING.md
├── THIRD_PARTY.md                      # 引擎仓库 + 协议（GPL 署名，勿删）
├── THIRD_PARTY_RESOLVED.md             # 构建时自动记录的实际 commit
└── PORTING_NOTES.md                    # 引擎整合的技术细节与坑
```

## 编译（Mac 端）

```bash
# 1. 一键全量（字体 → SDL2 → ONS → KRKR → App → .deb）
./scripts/build_all.sh

# 或分步
bash engines/fonts/fetch_fonts.sh
bash engines/SDL2/build_ios.sh
bash engines/onscripter/build_ios.sh
bash engines/kirikiroid2/build_ios.sh
bash scripts/build_app.sh
bash packaging/build_deb.sh
```

产出: `dist/com.yg.galplayer_0.1.0_iphoneos-arm64.deb`

### 没有 Mac？（GitHub Actions 免费云 Mac 编译）

没有苹果设备也能编译，全程只用 Windows：

1. 注册/登录 [github.com](https://github.com)，新建一个**公开**仓库（公开 = macOS 编译免费不限时长；本项目 GPL 开源且不含任何密钥，公开无碍）
2. 把整个 `GalPlayer` 文件夹上传到该仓库（网页端 Add file → Upload files 拖进去即可，或装 git 推送）
3. 仓库页面 → **Actions** → 左侧 **Build GalPlayer** → **Run workflow** → 等待编译（约 30~90 分钟）
4. 跑完后打开该次运行页面，底部 **Artifacts** 下载 `galplayer-deb`，解压得到 `.deb`
5. 把 `.deb` 传进 iPad（微信文件传输助手 / 网盘 / 邮件均可），用 Filza 点击安装

> 编译失败时，下载 Artifacts 里的 `build-logs`，把报错发出来即可定位。

> 引擎源码在构建时从官方仓库现场拉取并锁定 commit（自动写入 `THIRD_PARTY_RESOLVED.md`）。
> ONScripter 源码包下载失败时支持 `ONS_SRC_TARBALL=/path/xxx.tar.gz` 手动指定。

## 安装到设备

```bash
# 方式 A: USB SSH 自动安装（推荐）
./scripts/install_device.sh          # 依赖 iproxy（libimobiledevice），dropbear 44 端口

# 方式 B: AirDrop/Filza 手动
#  1. 把 .deb 拷到设备任意目录
#  2. Filza 点击 .deb -> Install（自动执行 postinst: 权限 + ldid 兜底签名 + uicache）

# 卸载
./scripts/install_device.sh --uninstall
```

安装后图标出现在桌面（`/var/jb/Applications/GalPlayer.app` + `uicache -p`）。

## 使用

1. 把游戏文件夹放入 `/var/mobile/Documents/Galgames/<游戏名>/`
   - Kirikiri: 目录内含 `data.xp3`（或任意 `.xp3`）
   - ONScripter: 目录内含 `nscript.dat` 或 `0.txt`
2. 打开 App → 列表出现游戏卡片（角标 KRKR / ONS）→ 点击启动
3. 游戏内存档/读档/系统菜单由引擎自带（KAG/ONS 右键菜单），存档直接写在游戏目录内

### 触控操作（两个引擎行为一致）

| 手势 | 映射 | 效果 |
|---|---|---|
| 单击 | 鼠标左键 | 推进剧情 |
| 双指轻点 | 鼠标右键 | 呼出引擎菜单（存档/读档/设置） |
| 长按 | 左键按住 + Ctrl + 连点 | 持续快进（节奏 = 设置页"快进/文字速度"） |

### 设置

- **全局设置**（右上角齿轮）: 屏幕适配（原始比例/拉伸全屏）· 快进/文字速度 · 音量
- **单游戏设置**（长按卡片）: 手动指定引擎 · 清除识别缓存
- 屏幕适配对 ONScripter 完整生效（原始比例=居中黑边/拉伸=铺满）；Kirikiri 采用 Kirikiroid2 原生等比缩放

## 开源协议

- Kirikiroid2 / ONScripter: **GPL-2.0** —— 本项目遵守协议，App「关于」页保留引擎署名，
  协议声明见 [THIRD_PARTY.md](THIRD_PARTY.md)；修改部分（SDL1.2 兼容层、iOS 胶水层、构建脚本）
  随源码一并按 GPL-2.0 分发。
- SDL2: zlib；DroidSansFallback 字体: Apache-2.0。

## 常见问题

见 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)：游戏放哪、黑屏、闪退（先看 CrashReporter）、存档位置、无声音等。
