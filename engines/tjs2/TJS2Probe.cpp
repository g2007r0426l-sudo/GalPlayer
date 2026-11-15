// =============================================================================
// TJS2Probe.cpp —— TJS2 引擎真机验证
//
// 目标：证明 libtjs2.a 在 iPad 上能初始化、能执行源码与字节码。
// 结果写 /var/mobile/Documents/tjs2_probe.log
// =============================================================================
#include <cstdio>
#include <cstdarg>
#include <cstring>
#include <string>
#include <vector>

#include "tjs.h"
#include "tjsError.h"
#include "tjsVariant.h"
#include "tjsString.h"
#include "tjsUtils.h"

extern "C" int  gp_xp3_read_file(const char *xp3Path, const char *entryName,
                                 unsigned char **outBuf, size_t *outLen);
extern "C" void gp_xp3_free(unsigned char *p);

namespace {

FILE *gLog = nullptr;

void logf(const char *fmt, ...) {
    if (!gLog) return;
    va_list ap;
    va_start(ap, fmt);
    std::vfprintf(gLog, fmt, ap);
    va_end(ap);
    std::fflush(gLog);
}

std::string toStd(const tjs_char *s) {
    if (!s) return "";
    std::string out;
    while (*s) {
        tjs_uint32 c = (tjs_uint32)*s++;
        if (c < 0x80) out.push_back((char)c);
        else out += "?";     // 日志只保留可读 ASCII，避免编码问题
    }
    return out;
}

class Console : public iTJSConsoleOutput {
public:
    void TJS_INTF_METHOD Print(const tjs_char *msg) override {
        if (gLog && msg) std::fprintf(gLog, "[console] %s\n", toStd(msg).c_str());
    }
    void TJS_INTF_METHOD ExceptionPrint(const tjs_char *msg) override {
        if (gLog && msg) std::fprintf(gLog, "[exception] %s\n", toStd(msg).c_str());
    }
};

} // namespace

extern "C" void gp_tjs2_probe(const char *xp3Path) {
    gLog = std::fopen("/var/mobile/Documents/tjs2_probe.log", "w");
    if (!gLog) return;
    logf("=== TJS2 probe start ===\n");

    Console console;
    tTJS *engine = nullptr;
    try {
        engine = new tTJS();
        engine->SetConsoleOutput(&console);
        logf("[ok] engine created\n");

        tTJSVariant result;
        engine->ExecScript(TJS_W("var a = 6 * 7; var s = 'gal' + 'player'; var arr = [1,2,3]; a + arr[2];"),
                           &result);
        logf("[ok] ExecScript -> result=%d (expect 45)\n", (int)(tjs_int64)result);

        tTJSVariant r2;
        engine->EvalExpression(TJS_W("1 + 2 * 3"), &r2);
        logf("[ok] EvalExpression -> %d (expect 7)\n", (int)(tjs_int64)r2);

        if (xp3Path && *xp3Path) {
            unsigned char *buf = nullptr;
            size_t len = 0;
            int rc = gp_xp3_read_file(xp3Path, "startup.tjs", &buf, &len);
            logf("[xp3] read startup.tjs rc=%d len=%zu\n", rc, len);
            if (rc == 0 && buf && len > 0) {
                logf("[xp3] head: %02x %02x %02x %02x %02x %02x %02x %02x\n",
                     buf[0], buf[1], buf[2], buf[3], buf[4], buf[5], buf[6], buf[7]);
                tTJSVariant br;
                try {
                    engine->LoadByteCode(buf, len, &br, nullptr, TJS_W("startup.tjs"));
                    logf("[ok] LoadByteCode success\n");
                } catch (eTJS &e) {
                    logf("[warn] LoadByteCode: %s\n", toStd(e.GetMessage().c_str()).c_str());
                }
                gp_xp3_free(buf);
            }
        }

        engine->Shutdown();
        engine->Release();
        engine = nullptr;
        logf("=== TJS2 probe done ===\n");
    } catch (eTJS &e) {
        logf("[fatal] eTJS: %s\n", toStd(e.GetMessage().c_str()).c_str());
    } catch (...) {
        logf("[fatal] unknown exception\n");
    }
    if (gLog) { std::fclose(gLog); gLog = nullptr; }
}
