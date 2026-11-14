# TROUBLESHOOTING — 排障手册

## 一、闪退 / 启动即崩

**第一件事：看崩溃日志**
```bash
ssh -p 2222 root@127.0.0.1 'ls -t /var/mobile/Library/Logs/CrashReporter/*.ips | head -3'
# 通过 iproxy 2222 44 转发后执行；把最新 .ips 拷出来看 Exception / Termination Reason
```

| 症状（崩溃日志关键字） | 原因 | 对策 |
|---|---|---|
| `mapped file has no cdhash` | Frameworks 里的 Mach-O 没递归签名 | 重跑 `packaging/build_deb.sh`（内含 `scripts/sign.sh` 递归签名）；或在设备上手动: `find /var/jb/Applications/GalPlayer.app -type f -exec ldid -S {} \;` 再 `uicache -p` |
| `UINib` / storyboard 相关异常 | 用了 storyboard（新 SDK 编译的 storyboard 跑旧系统必崩） | 本项目全代码 UI，确认没有混入 XIB/Storyboard |
| `Library not loaded: libSDL2.dylib` 等 | 静态库没链接进去 | 重跑 `scripts/build_app.sh`，确认 `build/ios/lib/` 五个 .a 都在 |
| 越狱插件注入崩溃（Flex/Force120Hz 等） | 第三方 tweak 注入冲突 | 在 **Choicy** 里对 GalPlayer 禁用全部注入（本项目不依赖任何注入） |

**uicache 报错**

| 报错 | 原因 | 对策 |
|---|---|---|
| `does not support App Store apps` | App 放在了 `/var/containers/Bundle/Application/...` | 必须放 `/var/jb/Applications/GalPlayer.app`（rootless）或 `/Applications`（rootful），再 `uicache -p` |

## 二、游戏相关

**游戏放哪？**
```
/var/mobile/Documents/Galgames/<游戏名>/
```
- App 首次运行会自动创建该目录并弹引导
- 一级子文件夹 = 一个游戏；识别规则见 README
- 目录属主应为 mobile（Filza 新建即为 mobile）；权限不对时:
  `chown -R mobile:mobile /var/mobile/Documents/Galgames/xxx`

**点击游戏没反应 / 列表没有新游戏**
- 点右上角刷新按钮（目录 mtime 没变化时不重扫）
- 未知引擎的卡片是灰色的 → 长按卡片手动指定引擎

**Kirikiri 游戏黑屏 / 卡在启动画面**
1. 确认 `.xp3` 完整（FIlza 看文件大小与 PC 端一致）
2. 中文显示方块/乱码 → 字体问题:
   - App 内置了 DroidSansFallback.ttf，启动时会拷到游戏目录（`font/` 与根目录）
   - 仍乱码时把游戏自带 TTF 手动放进游戏目录并改名 `DroidSansFallback.ttf`
3. 部分 KRKR 游戏自带私有启动器（旧版 krkr / 加密 xp3 过滤器）→ 一期不支持自定义 xp3 filter，属已知限制

**ONScripter 游戏黑屏 / 无声**
1. `nscript.dat` / `0.txt` 必须在目录根部
2. 无声音: 一期默认支持 NWA/WAV；OGG 需构建时 OGG 源码拉取成功（构建日志有提示）；
   MP3（smpeg）一期不支持 → 用 ONS 工具把音频转 NWA/WAV 或 ogg
3. 部分游戏分辨率非常规（如 1280x720 以上）→ 拉伸全屏模式试试
4. 花屏: 极少数游戏按 16bpp 写死 → 见 PORTING_NOTES.md「已知限制」

**存档在哪？**
- ONScripter: 游戏目录内 `save.dat`（引擎原生，随游戏目录走）
- Kirikiri: 游戏目录内 `savedata/`（KAG 默认）
- 存档/读档入口: 游戏内双指呼出菜单 → 引擎自带存档界面

## 三、触控

| 手势失效 | 排查 |
|---|---|
| 双指呼出菜单无效 | 部分游戏右键被脚本改成了跳过/存档，这是游戏行为不是 App 问题 |
| 长按不快进 | 该游戏脚本禁用了 skip；快进节奏可在设置页调"快进/文字速度" |
| 触控错位 | SDL 窗口尺寸与引擎画面不一致 → 设置页切换适配模式 |

## 四、构建问题（Mac 端）

| 报错 | 对策 |
|---|---|
| `brew install ...` 缺件 | cmake ninja xcodegen ldid dpkg libimobiledevice 逐一补齐 |
| SDL2 clone 失败 | 脚本按 tag 列表尝试；仍失败则手动 clone 后放进 `engines/SDL2/SDL` |
| ONScripter 下载失败 | `ONS_SRC_TARBALL=/path/onscripter-jh.tar.gz bash engines/onscripter/build_ios.sh` |
| Kirikiroid2 编译失败 | 看脚本打印的前 30 行错误 + `PORTING_NOTES.md` 对应条目（平台目录排除/依赖头文件/入口探测） |
| xcodebuild 链接错误 undefined symbol | 确认引擎库与 App 是同一轮构建（`build/ios/lib/*.a` 时间戳） |
| App 能编译但安装后崩溃 | 八成是签名 —— 见「递归签名」条目 |

## 五、网络行为验证（验收 #8）

App 无任何网络请求，验证方式任选:
- Instruments → Network instrument（模板: Network）跑一遍进出游戏
- Proxyman/Charles 监听 Wi-Fi 代理，操作全程 0 请求
- 代码层面: 全工程无 `URLSession`/`NSURLConnection`/`CFNetwork` 调用（可 grep 验证）
