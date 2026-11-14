// =============================================================================
// IOSUtils.cpp — Kirikinux2 引擎核心的 iOS 平台层
//
// 对应 Kirikinux2 的 platform/linux/LinuxUtils.cpp（Linux 桌面宿主）。
// 导出与 AndroidUtils.cpp/LinuxUtils.cpp 相同的符号集，src/core 与 src/plugins
// 无需修改即可编译。以 LinuxUtils.cpp 为底本，iOS 差异点如下：
//   1. _AppDataDir      → HOME/Library/Application Support/kirikinux
//   2. /proc/meminfo    → iOS 无 /proc，返回 0（仅影响内存显示）
//   3. TVPGetDriverPath → 固定为 Galgames 目录 + HOME（无 /proc/mounts 扫描）
//   4. 设备语言         → NSLocale preferredLanguages
//   5. stat timespec    → Darwin 命名 st_atimespec/st_mtimespec/st_ctimespec
//   6. 对话框           → 桩（返回 -2 走引擎非交互分支；KR2IOSStubs.cpp）
//   7. 崩溃处理器       → 桩
// =============================================================================
#include "Platform.h"
#include "tjsCommHead.h"
#include "StorageImpl.h"
#include "SysInitIntf.h"
#include "EventIntf.h"
#include "RenderManager.h"
#include "Application.h"
#include "TickCount.h"
#include "cocos2d/MainScene.h"
#include "ConfigManager/LocaleConfigManager.h"
#include "WindowIntf.h"
#include "cocos2d.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include <algorithm>
#include <cerrno>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <vector>
#include <fcntl.h>
#include <limits.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <mach/mach.h>

// ---- Darwin stat 字段名兼容 ----
#define st_atim st_atimespec
#define st_ctim st_ctimespec
#define st_mtim st_mtimespec

// ---- 桩（KR2IOSStubs.cpp）----
int KR2IOSMessageBox(const std::string &text, const std::string &caption, const std::vector<std::string> &buttons);

extern std::thread::id TVPMainThreadID; // Application.cpp, set by TVPAppDelegate
int TVPCheckArchive(const ttstr &localname);

std::vector<std::string> TVPLinuxStartupArgs;

// ---------------------------------------------------------------------------
// POSIX 小工具（与 LinuxUtils 相同）
// ---------------------------------------------------------------------------
static bool _IsDir(const std::string &p) {
	struct stat st;
	return !p.empty() && ::stat(p.c_str(), &st) == 0 && S_ISDIR(st.st_mode);
}

static std::string _HomeDir() {
	const char *h = getenv("HOME");
	return (h && *h) ? std::string(h) : std::string("/var/mobile");
}

static void _PushUniqueDir(std::vector<std::string> &v, std::string p) {
	while (p.size() > 1 && p.back() == '/') p.pop_back();
	if (!_IsDir(p)) return;
	if (std::find(v.begin(), v.end(), p) == v.end()) v.emplace_back(p);
}

static bool _MkdirP(const std::string &dir) {
	if (dir.empty()) return false;
	std::string cur = dir[0] == '/' ? "/" : "";
	size_t pos = 0;
	while (pos <= dir.size()) {
		size_t next = dir.find('/', pos);
		if (next == std::string::npos) next = dir.size();
		std::string part = dir.substr(pos, next - pos);
		if (!part.empty()) {
			if (!cur.empty() && cur.back() != '/') cur += '/';
			cur += part;
			if (::mkdir(cur.c_str(), 0755) != 0 && errno != EEXIST) return false;
		}
		pos = next + 1;
	}
	return _IsDir(dir);
}

static std::string _ToLower(std::string s) {
	std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return (char)tolower(c); });
	return s;
}

static std::string _AppDataDir() {
	// iOS: HOME = /var/mobile（越狱设备）或容器目录（App Store 场景，本项目不适用）
	std::string dir = _HomeDir() + "/Library/Application Support/kirikinux";
	_MkdirP(dir);
	return dir;
}

// Galgames 根目录（GalPlayer 的游戏库）
static std::string _GamesDir() {
	return "/var/mobile/Documents/Galgames";
}

static int _RunOnMainThread(const std::function<int()> &fn) {
	if (TVPMainThreadID == std::thread::id() || std::this_thread::get_id() == TVPMainThreadID)
		return fn();
	std::mutex m;
	std::condition_variable cv;
	bool done = false;
	int ret = -1;
	cocos2d::Director::getInstance()->getScheduler()->performFunctionInCocosThread([&]() {
		int r = fn();
		std::lock_guard<std::mutex> lk(m);
		ret = r;
		done = true;
		cv.notify_all();
	});
	std::unique_lock<std::mutex> lk(m);
	cv.wait(lk, [&] { return done; });
	return ret;
}

// ---------------------------------------------------------------------------
// logging / memory / time
// ---------------------------------------------------------------------------
void TVPPrintLog(const char *str) {
	fputs(str, stdout);
	fflush(stdout);
}

static tjs_uint32 _lastMemoryInfoQuery = 0;
static tjs_int _availMemory = 0, _usedMemory = 0;
static void _updateMemoryInfo() {
	// iOS 无 /proc；用 mach 端口粗略实现（仅影响设置页显示）
	tjs_uint32 now = TVPGetRoughTickCount32();
	if (_lastMemoryInfoQuery && now - _lastMemoryInfoQuery < 3000) return;
	_lastMemoryInfoQuery = now ? now : 1;
	task_vm_info_data_t info;
	mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
	if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) == KERN_SUCCESS) {
		_usedMemory = (tjs_int)(info.phys_footprint / (1024 * 1024));
	}
}

tjs_int TVPGetSystemFreeMemory() { _updateMemoryInfo(); return _availMemory; }
tjs_int TVPGetSelfUsedMemory() { _updateMemoryInfo(); return _usedMemory; }

tjs_uint32 TVPGetRoughTickCount32() {
	tjs_uint32 uptime = 0;
	struct timespec on;
	if (clock_gettime(CLOCK_MONOTONIC, &on) == 0)
		uptime = (tjs_uint32)(on.tv_sec * 1000 + on.tv_nsec / 1000000);
	return uptime;
}

void TVPForceSwapBuffer() {}
void TVPProcessInputEvents() {}
void TVPShowIME(int x, int y, int w, int h) {}
void TVPHideIME() {}
void TVPControlAdDialog(int adType, int arg1, int arg2) {}
void TVPFetchSDCardPermission() {}
void TVPSendToOtherApp(const std::string &filename) {}

// ---------------------------------------------------------------------------
// 设备 / 包信息
// ---------------------------------------------------------------------------
std::string TVPGetDeviceID() {
	// 越狱设备无稳定 machine-id；用设备型号代替（仅用于统计去重）
	NSString *model = [[UIDevice currentDevice] model] ?: @"unknown";
	return std::string("Model=") + [model UTF8String];
}

std::string TVPGetDeviceLanguage() {
	NSString *lang = [NSLocale preferredLanguages].firstObject ?: @"en";
	std::string l = [lang UTF8String];
	size_t p = l.find_first_of("_-");
	if (p != std::string::npos) l = l.substr(0, p);
	return l.empty() ? std::string("en") : _ToLower(l);
}

std::string TVPGetCurrentLanguage() {
	std::string l = TVPGetDeviceLanguage();
	if (l.compare(0, 2, "zh") == 0) return "zh_cn"; // 简繁细分交给引擎 UI 设置
	if (l.compare(0, 2, "ja") == 0) return "ja_jp";
	return "en_us";
}

std::string TVPGetPackageVersionString() {
	NSString *ver = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"] ?: @"0.1";
	return std::string([ver UTF8String]) + " (iOS, Kirikinux2)";
}

// ---------------------------------------------------------------------------
// 存储位置
// ---------------------------------------------------------------------------
std::vector<std::string> TVPGetDriverPath() {
	std::vector<std::string> ret;
	_PushUniqueDir(ret, _GamesDir());          // GalPlayer 游戏库
	if (const char *dir = getenv("KIRIKINUX_GAME_DIR")) _PushUniqueDir(ret, dir);
	_PushUniqueDir(ret, _HomeDir());
	_PushUniqueDir(ret, "/");
	return ret;
}

std::vector<std::string> TVPGetAppStoragePath() {
	std::vector<std::string> ret;
	ret.emplace_back(_AppDataDir());
	return ret;
}

bool TVPCheckStartupPath(const std::string &path) {
	// 越狱设备 Galgames 目录属主为 mobile，可写；不再弹只读警告
	return true;
}

// ---------------------------------------------------------------------------
// 启动参数（GalPlayer → 标记文件 → IOSMain → 这里）
// ---------------------------------------------------------------------------
static std::string _AbsPath(const std::string &p) {
	char buf[PATH_MAX];
	if (realpath(p.c_str(), buf)) return buf;
	if (!p.empty() && p[0] != '/' && getcwd(buf, sizeof(buf))) return std::string(buf) + "/" + p;
	return p;
}

std::string TVPSelectGamePath(const std::string &initialPath) {
	// iOS: 游戏选择在 GalPlayer 完成；引擎内"打开游戏"回落到初始目录
	return initialPath.empty() ? _GamesDir() : initialPath;
}

bool TVPCheckStartupArg() {
	if (TVPLinuxStartupArgs.empty()) return false;
	for (size_t i = 2; i < TVPLinuxStartupArgs.size(); ++i) {
		const std::string &a = TVPLinuxStartupArgs[i];
		size_t pos = a.find('=');
		if (pos == std::string::npos) {
			TVPSetCommandLine(ttstr(a).c_str(), ttstr("yes"));
		} else {
			TVPSetCommandLine(ttstr(a.substr(0, pos)).c_str(), ttstr(a.substr(pos + 1)));
		}
	}
	std::string path = _AbsPath(TVPLinuxStartupArgs[1]);
	if (TVPCheckExistentLocalFile(ttstr(path))) {
		if (TVPCheckArchive(ttstr(path)) == 1) {
			TVPMainScene::GetInstance()->startupFrom(path);
			return true;
		}
		return false;
	}
	if (!TVPCheckExistentLocalFolder(ttstr(path))) return false;
	bool hasStartup = false;
	std::string dataXp3;
	TVPListDir(path, [&](const std::string &name, int mask) {
		if (!(mask & S_IFREG)) return;
		std::string lower = _ToLower(name);
		if (lower == "startup.tjs") hasStartup = true;
		else if (lower == "data.xp3") dataXp3 = path + "/" + name;
	});
	if (hasStartup) {
		TVPMainScene::GetInstance()->startupFrom(path);
		return true;
	}
	if (!dataXp3.empty() && TVPCheckArchive(ttstr(dataXp3)) == 1) {
		TVPMainScene::GetInstance()->startupFrom(dataXp3);
		return true;
	}
	return false;
}

// ---------------------------------------------------------------------------
// 对话框（Android: JNI → KR2Activity；iOS: 桩走非交互分支）
// ---------------------------------------------------------------------------
extern "C" int TVPShowSimpleMessageBox(const char *pszText, const char *pszTitle, unsigned int nButton, const char **btnText) {
	std::string text = pszText ? pszText : "", title = pszTitle ? pszTitle : "";
	std::vector<std::string> btns;
	for (unsigned int i = 0; i < nButton; ++i) btns.emplace_back((btnText && btnText[i]) ? btnText[i] : "");
	int ret = _RunOnMainThread([&]() { return KR2IOSMessageBox(text, title, btns); });
	if (ret == -2) ret = 0; // 无 GUI: 保持继续（与 Linux 无 GTK 行为一致）
	return ret;
}

int TVPShowSimpleMessageBox(const ttstr &text, const ttstr &caption, const std::vector<ttstr> &vecButtons) {
	std::vector<std::string> hold;
	hold.reserve(vecButtons.size());
	for (const ttstr &btn : vecButtons) hold.emplace_back(btn.AsStdString());
	std::vector<const char *> ptrs;
	for (const std::string &s : hold) ptrs.emplace_back(s.c_str());
	std::string t = text.AsStdString(), c = caption.AsStdString();
	return TVPShowSimpleMessageBox(t.c_str(), c.c_str(), (unsigned int)ptrs.size(), ptrs.empty() ? nullptr : &ptrs[0]);
}

int TVPShowSimpleInputBox(ttstr &text, const ttstr &caption, const ttstr &prompt, const std::vector<ttstr> &vecButtons) {
	// iOS MVP: 输入框走引擎内置模板渲染（KR2IOSMessageBox 返回 -2）
	std::string t = text.AsStdString(), c = caption.AsStdString(), p = prompt.AsStdString();
	std::vector<std::string> btns;
	for (const ttstr &btn : vecButtons) btns.emplace_back(btn.AsStdString());
	int ret = _RunOnMainThread([&]() { return KR2IOSMessageBox(t, c, btns); });
	if (ret == -2) ret = 0;
	if (ret >= 0) text = t;
	return ret;
}

// ---------------------------------------------------------------------------
// 文件
// ---------------------------------------------------------------------------
bool TVPCreateFolders(const ttstr &folder) {
	if (folder.IsEmpty()) return true;
	return _MkdirP(folder.AsStdString());
}

bool TVPWriteDataToFile(const ttstr &filepath, const void *data, unsigned int size) {
	std::string filename = filepath.AsStdString();
	std::string pattern = filename + ".kr2tmp.XXXXXX";
	std::vector<char> tmp(pattern.begin(), pattern.end());
	tmp.push_back(0);
	int fd = mkstemp(tmp.data());
	if (fd < 0) return false;
	FILE *fp = fdopen(fd, "wb");
	if (!fp) { close(fd); unlink(tmp.data()); return false; }
	bool ok = size == 0 || fwrite(data, 1, size, fp) == size;
	if (fflush(fp) != 0) ok = false;
	if (ok && fsync(fd) != 0) ok = false;
	if (fclose(fp) != 0) ok = false;
	if (!ok || rename(tmp.data(), filename.c_str()) != 0) {
		unlink(tmp.data());
		return false;
	}
	return true;
}

bool TVPDeleteFile(const std::string &filename) {
	struct stat st;
	if (::lstat(filename.c_str(), &st) == 0 && S_ISDIR(st.st_mode))
		return rmdir(filename.c_str()) == 0;
	return unlink(filename.c_str()) == 0;
}

bool TVPRenameFile(const std::string &from, const std::string &to) {
	return rename(from.c_str(), to.c_str()) == 0;
}

void TVPLinuxQuickExit(int code) {
	fflush(nullptr);
	_exit(code); // 独立 App，跳过静态析构（同 Linux 桌面版）
}

// ---------------------------------------------------------------------------
// 退出流程（iOS 无窗口关闭按钮：引擎菜单"退出游戏"触发）
// ---------------------------------------------------------------------------
tTJSNI_Window *TVPGetActiveWindow(); // MainScene.cpp

void TVPExitApplication(int code) {
	TVPDeliverCompactEvent(TVP_COMPACT_LEVEL_MAX);
	if (!TVPIsSoftwareRenderManager())
		iTVPTexture2D::RecycleProcess();
	TVPLinuxQuickExit(code);
}

// Darwin stat 字段
#undef st_atime
#undef st_ctime
#undef st_mtime
bool TVP_stat(const tjs_char *name, tTVP_stat &s) {
	tTJSNarrowStringHolder holder(name);
	return TVP_stat(holder, s);
}

bool TVP_stat(const char *name, tTVP_stat &s) {
	struct stat t;
	static_assert(sizeof(t.st_size) == 8, "large file support required");
	if (::stat(name, &t) != 0) {
		memset(&s, 0, sizeof(s));
		return false;
	}
	s.st_mode = t.st_mode;
	s.st_size = t.st_size;
	s.atime_seconds = t.st_atimespec.tv_sec;
	s.mtime_seconds = t.st_mtimespec.tv_sec;
	s.ctime_seconds = t.st_ctimespec.tv_sec;
	return true;
}
