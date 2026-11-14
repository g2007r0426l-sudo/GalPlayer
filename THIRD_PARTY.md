# THIRD_PARTY — 第三方开源组件与协议声明

> **本文件与 App 内「关于」页的署名必须保留（GPL-2.0 要求）。**
> 各引擎源码的实际 commit 在每次构建时自动记录到 `THIRD_PARTY_RESOLVED.md`。

## 1. Kirikiri2 核心 — Kirikiroid2

- 上游仓库: https://github.com/zzz-ooo/Kirikiroid2
- 拉取方式: `git clone --depth 1`（构建时锁定实际 commit）
- 使用范围: `kirikiri2/` 核心源码（kirikiri2 引擎 + KAG 解析 + SDL2 渲染/音频/字体层），
  **剥离** `project/` 下的 Android/Java 胶水层，替换为本项目自写的 iOS 胶水
  （`engines/kirikiroid2/build_ios.sh` + `app/GalPlayer/Bridges/KrkrBridge.mm`）
- 协议: **GPL-2.0**（以仓库 LICENSE 为准；Kirikiri 原始核心为 modified-BSD，
  Kirikiroid2 整体按 GPL-2.0 分发，本项目遵循仓库整体协议）

## 2. ONScripter — ONScripter-JH / 官方 ogapee 版

- 官方主页: http://onscripter.sourceforge.jp/onscripter.shtml（ogapee）
- JH 版主页: http://onscripter.osdn.jp/onscripter_jh.html
- 拉取方式: 构建脚本按 URL 列表自动下载源码包；支持 `ONS_SRC_TARBALL` 手动指定
- 使用范围: ONScripter 全部核心源码（ScriptHandler/ScriptParser/ONScripterEvent 等）
- 本项目新增: `engines/onscripter/sdl2_compat/` —— SDL1.2→SDL2 视频兼容层
  （不改引擎源码，编译期 include 垫片实现），补丁见 `engines/onscripter/patch_ons_sources.sh`
- 协议: **GPL-2.0**

## 3. SDL2 (Simple DirectMedia Layer)

- 上游仓库: https://github.com/libsdl-org/SDL（构建脚本按 release-2.30.x → 2.26.x tag 列表锁定）
- 附带扩展: SDL_image / SDL_ttf / SDL_mixer（libsdl-org 官方仓库，release tag 锁定）
- 若 Kirikiroid2 仓库自带 SDL2 fork，构建脚本优先使用其 fork（保证渲染层一致）
- 使用范围: iOS UIKit 后端（视频/触摸/音频/线程），两引擎统一运行时
- 协议: **zlib**（SDL_image/SDL_ttf/SDL_mixer 同为 zlib）

## 4. FreeType

- 上游仓库: https://github.com/freetype/freetype（VER-2-13.x）
- 使用范围: ONScripter 字体渲染；Kirikiroid2 若自带 FreeType 则用其内置版本
- 协议: **FTL / GPL-2.0 双许可**

## 5. libogg / libvorbis（可选，OGG 音频）

- 上游仓库: https://github.com/xiph/ogg (v1.3.5)、https://github.com/xiph/vorbis (v1.3.7)
- 使用范围: ONScripter `-DUSE_OGG_VORBIS` 音频解码
- 协议: **BSD-3-Clause**

## 6. DroidSansFallback 字体

- 来源: Android AOSP `frameworks/base/data/fonts/`
- 使用范围: App 内置 CJK 兜底字体（启动时拷入游戏目录供引擎渲染中文）
- 协议: **Apache-2.0**

## 7. XcodeGen（构建工具，仅 Mac 端使用，不进 App 包）

- https://github.com/yonaskolb/XcodeGen — MIT

---

## 合规说明

- GalPlayer 本体代码（App 层 / 桥接层 / 兼容层 / 构建脚本）按 **GPL-2.0** 随本项目分发。
- 本应用为本地播放器，不修改、不解锁任何游戏的版权内容；游戏文件由用户自行放置。
- 删除署名即违反上游 GPL 协议，请勿删除本文件与 App「关于」页署名。
