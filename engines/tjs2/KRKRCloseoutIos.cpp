// =============================================================================
// KRKRCloseoutIos.cpp —— 收尾实现（iOS）
//
//  1) 视频叠加后端：Windows 专用（MFVideo/MixingVideo/VideoLayer），返回空
//  2) libjpeg-turbo 的 tj* 接口：iOS 上用的是系统 libjpeg，这里给兼容桩
//  3) IndividualConfigManager 的 bool 模板特化
//
// 说明：视频/JPEG 桩只保证「引擎不崩、流程可继续」；真实解码后续接
//       iOS ImageIO 或已编好的 SDL2_image（IMG_Load）。
// =============================================================================
#include <cstdio>
#include <cstddef>
#include <string>

#include "tjsCommHead.h"
#include "tjsString.h"
#include "GlobalConfigManager.h"
#include "IndividualConfigManager.h"

// ---------------------------------------------------------------------------
// 1) libjpeg-turbo 兼容桩
// ---------------------------------------------------------------------------
extern "C" {

typedef void *tjhandle;
typedef unsigned char JSAMPLE;

tjhandle tjInitDecompress(void) { return (tjhandle)1; }
void     tjDestroy(tjhandle h) { (void)h; }
void    *tjAlloc(int bytes) { (void)bytes; return nullptr; }
void     tjFree(void *buf) { (void)buf; }
int      tjDecompressHeader2(tjhandle h, const unsigned char *src, unsigned long n,
                             int *w, int *hgt, int *subsamp) {
    (void)h; (void)src; (void)n;
    if (w) *w = 0;
    if (hgt) *hgt = 0;
    if (subsamp) *subsamp = 0;
    return -1;                    // 失败：上层会回退其它解码器
}
int      tjDecompress2(tjhandle h, const unsigned char *src, unsigned long n,
                       unsigned char *dst, int w, int pitch, int hgt, int fmt, int flags) {
    (void)h; (void)src; (void)n; (void)dst; (void)w; (void)pitch; (void)hgt; (void)fmt; (void)flags;
    return -1;
}
int      tjDecompressHeader3(tjhandle h, const unsigned char *src, unsigned long n,
                             int *w, int *hgt, int *subsamp, int *colorspace) {
    (void)h; (void)src; (void)n; (void)subsamp; (void)colorspace;
    if (w) *w = 0;
    if (hgt) *hgt = 0;
    return -1;
}
char    *tjGetErrorStr(void) { return (char *)"turbojpeg stub"; }

} // extern "C"
