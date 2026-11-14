# GalPlayer — iPad 上的 galgame 播放器

在越狱 iPad 上玩 galgame：可爱界面 + ONScripter 引擎实机可用。
（iPad Pro 10.5 / iPadOS 17.5.1 / palera1n rootless 实测）

---

## 一、安装

```bash
# 设备已越狱（palera1n rootless）
# 把 dist/com.yg.galplayer_x.x.x_iphoneos-arm64.deb 传到设备，Filza 里点开安装
# 或本机跑：
python scripts/install_latest.py     # 自动下载最新构建产物并完成安装
```

装完桌面会出现两个图标：

| 图标 | 作用 |
|---|---|
| 🌸 **GalPlayer** | 游戏库界面（扫描/导入/设置） |
| **ONS 播放器** | ONScripter 引擎，由 GalPlayer 自动拉起，一般不用手动点 |

---

## 二、导入游戏（三种方式，任选）

**方式 A：App 内导入（推荐）**
右上角 **⤓** → 选游戏文件夹（可多选）→ 自动拷入并提示「已导入 N 个游戏」。

**方式 B：从「文件」App 投放**
「文件 → 我的 iPad → GalPlayer」里直接拖入游戏文件夹，
回到 App 点 **↻ 刷新**，会自动收录并提示。

**方式 C：直接放进游戏库目录**（Filza / SSH）
```
/var/mobile/Documents/Galgames/<游戏名>/
```

> 压缩包（zip/rar）请先解压成文件夹再导入 —— iOS 没有内置解压 API。

---

## 三、支持的引擎

| 引擎 | 判定条件 | 状态 |
|---|---|---|
| **ONScripter** | 目录内有 `nscript.dat` / `0.txt` / `00.txt` / `nscript.___` | ✅ 实机验证可用 |
| Kirikiri2 | 目录内有 `*.xp3` | ⚠️ 本机不可用（见下） |
| Artemis | `root.pfs` | ❌ 未实现，建议用 Artroid+ |

### 为什么 Kirikiri2 不行

真机探针结果：

```
probe MTLDevice=nil                          ← 拿不到 Metal 设备
driver[0]=metal      → Failed to obtain Metal device
driver[1]=opengles2  → GL ES 2 context could not be created
driver[2]=opengles   → GL ES 1 context could not be created
```

这台设备的越狱环境里，第三方 App 进程**没有 GPU 直连权限**（即使加
`platform-application` 等 entitlements 也一样）。cocos2d-x 那套渲染完全依赖
GL/Metal，且没有软件光栅化回退，所以 `.xp3` 游戏在本机无解。

ONScripter 之所以能跑，是因为我把它改成了 **GPU-free 呈现**：
引擎像素（ARGB8888）→ `CGImage` → 直接赋给 `CALayer.contents`，
由系统合成器上屏，全程不需要 GPU 客户端权限。

列表里 KRKR 游戏会**标灰并排在末尾**，点开会明确提示原因。

---

## 四、操作

| 手势 | 作用 |
|---|---|
| 单击 | 推进对话 |
| 双击（两指轻点） | 右键菜单（存档/读档/设置等，取决于游戏） |
| 长按 | 快进（按住 Ctrl + 连点） |
| 左上角 **←** | 退出游戏，回到游戏库 |

游戏内 `end` / 退出后会自动回到 GalPlayer。

---

## 五、界面

- 左侧边栏：全部游戏 / 最近游玩 / 设置（图标与文字严格对齐 + 粉色渐变胶囊）
- 右侧：暖奶油→薰衣草渐变、大号「游戏库」标题、搜索框
- 「继续上次」大卡：16:9 横版封面 + 悬浮播放键
- 网格卡片：3:4 竖版封面 + 左上时间胶囊 + 右上引擎角标
- 内置 8 张二次元插画封面（按游戏名稳定分配）
- 动效：卡片入场淡入上浮、按下缩放、刷新旋转、空状态浮动
- 字体：界面用霞鹜文楷，引擎用 DroidSansFallback（CJK 兜底）

---

## 六、目录结构

```
app/
  GalPlayer/            纯 Swift/UIKit 界面（不含任何引擎代码）
  OnsPlayer/            ONScripter 播放器（SDL2 App + GPU-free 呈现）
engines/
  SDL2/                 SDL2/Image/TTF/Mixer iOS 静态库构建脚本
  onscripter/           ONScripter + SDL1.2→SDL2 兼容层
  kirikiroid2/          Kirikiri2（二期，本机受 GPU 限制）
packaging/              .deb 打包 + entitlements + postinst
scripts/                构建/签名/装机脚本
```

---

## 七、构建

没有 Mac 也能出包：推 GitHub 后由 Actions 的 macOS runner 构建。

```
Actions → Build GalPlayer → Run workflow → 下载 galplayer-deb
```

关键坑与解法见 [PORTING_NOTES.md](PORTING_NOTES.md)。
