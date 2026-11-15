// =============================================================================
// IOSPlatform.cpp —— KiriKiri 运行时在 iOS 上的平台层实现
//
// base 层依赖一批「平台函数」（原本在 environ/win32 / environ/linux 里实现）。
// 这里用 POSIX / Foundation 能力补上，让运行时可以链接并启动。
// 未实现的部分先给安全桩（写日志），后续逐步替换为真实实现。
// =============================================================================
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <string>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>
#include <dirent.h>
#include <ctime>

#include "tjsCommHead.h"
#include "tjsString.h"
#include "tjsUtils.h"
#include "StorageIntf.h"
#include "SysInitIntf.h"
#include "MsgIntf.h"
#include "TickCount.h"
#include "FilePathUtil.h"

#ifndef GP_KRKR_LOG
#define GP_KRKR_LOG(...) do { fprintf(stderr, "[KRKR] " __VA_ARGS__); fputc('\n', stderr); } while (0)
#endif

namespace {

// App 可执行文件所在目录（/var/jb/Applications/OnsPlayer.app 或容器路径）
std::string appDir() {
    static std::string cached;
    if (!cached.empty()) return cached;
    char buf[PATH_MAX] = {0};
    uint32_t size = sizeof(buf);
    if (_NSGetExecutablePath(buf, &size) == 0) {
        char real[PATH_MAX] = {0};
        if (realpath(buf, real)) {
            std::string p(real);
            size_t pos = p.find_last_of('/');
            cached = (pos == std::string::npos) ? p : p.substr(0, pos);
            return cached;
        }
    }
    cached = "/var/mobile/Documents";
    return cached;
}

} // namespace

// ---------------------------------------------------------------- 路径
ttstr TVPGetAppPath() {
    return ttstr(appDir().c_str());
}

ttstr ExePath() {
    // 运行时的「exe 目录」，KiriKiri 用它定位 data 目录
    return ttstr(appDir().c_str());
}

std::string ExtractFileDir(const std::string &FileName) {
    size_t pos = FileName.find_last_of("/\\");
    if (pos == std::string::npos) return "";
    return FileName.substr(0, pos);
}

// ---------------------------------------------------------------- 目录操作
bool TVPCreateFolders(const ttstr &folder) {
    std::string path = folder.AsStdString();
    if (path.empty()) return false;
    std::string cur;
    for (size_t i = 0; i < path.size(); ++i) {
        cur.push_back(path[i]);
        if (path[i] == '/' && cur.size() > 1) {
            mkdir(cur.c_str(), 0755);
        }
    }
    if (mkdir(path.c_str(), 0755) != 0) {
        struct stat st;
        if (stat(path.c_str(), &st) == 0 && S_ISDIR(st.st_mode)) return true;
        return false;
    }
    return true;
}

bool TVPCheckExistentLocalFolder(const ttstr &name) {
    struct stat st;
    std::string p = name.AsStdString();
    return stat(p.c_str(), &st) == 0 && S_ISDIR(st.st_mode);
}

// ---------------------------------------------------------------- 存储名规范化
void TVPPreNormalizeStorageName(ttstr &name) {
    std::string s = name.AsStdString();
    for (auto &c : s) {
        if (c == '\\') c = '/';
        else if (c >= 'A' && c <= 'Z') c = (char)(c - 'A' + 'a');
    }
    name = ttstr(s.c_str());
}

// ---------------------------------------------------------------- 归档
tTVPArchive *TVPOpenArchive(const ttstr &name, bool /*normalizeFileName*/) {
    // 目前由我们自己的 XP3 读取器负责挂载；这里返回空表示「该存储不支持自动归档」
    GP_KRKR_LOG("TVPOpenArchive stub: %s", name.AsStdString().c_str());
    return nullptr;
}

iTVPStorageMedia *TVPCreateFileMedia() {
    // 文件媒体（真实实现里是 tTVPFileMedia），暂未实现 -> 后续用自研实现替换
    GP_KRKR_LOG("TVPCreateFileMedia stub");
    return nullptr;
}

// ---------------------------------------------------------------- 消息/时间
ttstr TVPGetMessageByLocale(const std::string &key) {
    return ttstr(key.c_str());
}

tjs_uint32 TVPGetRoughTickCount32() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (tjs_uint32)(ts.tv_sec * 1000ull + ts.tv_nsec / 1000000ull);
}
