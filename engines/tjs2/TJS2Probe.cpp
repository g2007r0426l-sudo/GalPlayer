// =============================================================================
// TJS2Probe.cpp —— TJS2 引擎真机验证
//
// 目标：证明 libtjs2.a 在 iPad 上能初始化、能执行字节码。
//   1. 建引擎
//   2. 执行一段 TJS 源码（算术 + 字符串 + 数组）
//   3. 从游戏 data.xp3 里取出 startup.tjs 字节码并 LoadByteCode
//   4. 结果写 /var/mobile/Documents/tjs2_probe.log
// =============================================================================
#include <stdio.h>
#include <string.h>
#include <string>
#include <vector>

#include "tjs.h"
#include "tjsError.h"
#include "tjsVariant.h"
#include "tjsUtils.h"

// XP3 读取由 ObjC++ 侧提供（避免在 C++ 里再写一遍）
extern "C" int  gp_xp3_read_file(const char *xp3Path, const char *entryName,
                                 unsigned char **outBuf, size_t *outLen);
extern "C" void gp_xp3_free(unsigned char *p);

namespace {

FILE *gLog = nullptr;

void logf(const char *fmt, ...) {
    if (!gLog) return;
    va_list ap;
    va_start(ap, fmt);
    vfprintf(gLog, fmt, ap);
    va_end(ap);
    fflush(gLog);
}

// TJS 控制台输出重定向
class Console : public iTJSConsoleOutput {
public:
    void TJS_INTF_METHOD Print(const tjs_char *msg) override {
        if (gLog && msg) fprintf(gLog, "[console] %s\n", ttstr(msg).AsStdString().c_str());
    }
    void TJS_INTF_METHOD Print(const char *msg) override {
        if (gLog && msg) fprintf(gLog, "[console] %s\n", msg);
    }
    void TJS_INTF_METHOD PrintException(const tjs_char *msg) override {
        if (gLog && msg) fprintf(gLog, "[exception] %s\n", ttstr(msg).AsStdString().c_str());
    }
};

} // namespace

extern "C" void gp_tjs2_probe(const char *xp3Path) {
    gLog = fopen("/var/mobile/Documents/tjs2_probe.log", "w");
    if (!gLog) return;
    logf("=== TJS2 probe start ===\n");

    Console console;
    tTJS *engine = nullptr;
    try {
        engine = new tTJS();
        engine->SetConsoleOutput(&console);
        logf("[ok] engine created\n");

        // 1) 源码执行
        tTJSVariant result;
        engine->ExecScript(TJS_W("var a = 6 * 7; var s = 'gal' + 'player'; var arr = [1,2,3]; a + arr[2];"),
                           &result);
        tjs_int v = (tjs_int)result;
        logf("[ok] ExecScript result = %d (expect 45)\n", (int)v);

        // 2) 表达式求值
        tTJSVariant r2;
        engine->EvalExpression(TJS_W("1 + 2 * 3"), &r2);
        logf("[ok] EvalExpression = %d (expect 7)\n", (int)r2);

        // 3) 执行游戏真实字节码
        if (xp3Path && *xp3Path) {
            unsigned char *buf = nullptr;
            size_t len = 0;
            int rc = gp_xp3_read_file(xp3Path, "startup.tjs", &buf, &len);
            logf("[xp3] read startup.tjs rc=%d len=%zu\n", rc, len);
            if (rc == 0 && buf && len > 0) {
                tTJSVariant br;
                try {
                    engine->LoadByteCode(buf, len, &br, nullptr, TJS_W("startup.tjs"));
                    logf("[ok] LoadByteCode success\n");
                } catch (tTJSRuntimeError &e) {
                    logf("[warn] LoadByteCode runtime error: %s\n",
                         ttstr(e.GetMessage()).AsStdString().c_str());
                } catch (eTJS &e) {
                    logf("[warn] LoadByteCode eTJS: %s\n",
                         ttstr(e.GetMessage()).AsStdString().c_str());
                }
                gp_xp3_free(buf);
            }
        }

        engine->Shutdown();
        engine->Release();
        logf("=== TJS2 probe done ===\n");
    } catch (eTJS &e) {
        logf("[fatal] eTJS: %s\n", ttstr(e.GetMessage()).AsStdString().c_str());
    } catch (...) {
        logf("[fatal] unknown exception\n");
    }
    if (gLog) { fclose(gLog); gLog = nullptr; }
}
