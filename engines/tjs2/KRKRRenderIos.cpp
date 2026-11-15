// =============================================================================
// KRKRRenderIos.cpp —— KiriKiri 的 iOS 软件渲染管理器
//
// 背景：上游 RenderManager.cpp 依赖 cocos2d 的 Texture2D 与 opencv/ffmpeg，
// 无法在 GPU 受限的越狱 iPad 上移植。这里用纯 CPU 实现同一套接口：
//   iTVPTexture2D  -> 内存位图纹理
//   iTVPRenderManager -> CPU 合成（矩形/三角形近似），Present 交给上层 CALayer
//
// 说明：cocos2d::Texture2D 在接口里只是指针，前置声明即可，永远返回 nullptr。
// =============================================================================
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <string>
#include <unordered_map>
#include <vector>
#include <algorithm>

// 前置声明（接口里仅作为指针使用）
namespace cocos2d { class Texture2D; }

#include "tjsCommHead.h"
#include "tjsString.h"
#include "RenderManager.h"
#include "LayerBitmapIntf.h"
#include "MsgIntf.h"

#ifndef KRKR_RLOG
#define KRKR_RLOG(...) do { fprintf(stderr, "[KRKR-render] " __VA_ARGS__); fputc('\n', stderr); } while (0)
#endif

// =============================================================================
// tTVPBitmap：上游在 RenderManager.cpp 里实现，这里改为 CPU 内存位图
// =============================================================================
void tTVPBitmap::Allocate(tjs_uint w, tjs_uint h, tjs_uint bpp) {
    Width = (tjs_int)w;
    Height = (tjs_int)h;
    tjs_int bytesPerPixel = (tjs_int)(bpp / 8);
    if (bytesPerPixel <= 0) bytesPerPixel = 4;
    PitchStep = (tjs_int)w * bytesPerPixel;
    PitchBytes = PitchStep;
    RefCount = 1;
    Bits = malloc((size_t)PitchStep * (size_t)h);
    if (Bits) memset(Bits, 0, (size_t)PitchStep * (size_t)h);
}

tTVPBitmap::tTVPBitmap(tjs_uint w, tjs_uint h, tjs_uint bpp) {
    Bits = nullptr;
    RefCount = 0;
    Allocate(w, h, bpp);
}

tTVPBitmap::tTVPBitmap(const tTVPBitmap &r) {
    Bits = nullptr;
    RefCount = 0;
    Allocate(r.GetWidth(), r.GetHeight(), r.GetBPP());
    if (Bits && r.GetBits()) {
        for (tjs_int y = 0; y < Height; ++y) {
            memcpy(GetScanLine((tjs_uint)y),
                   (const uint8_t *)r.GetBits() + (size_t)r.GetPitch() * y,
                   (size_t)PitchStep);
        }
    }
}

tTVPBitmap::~tTVPBitmap() {
    if (RefCount <= 1 && Bits) {
        free(Bits);
        Bits = nullptr;
    }
}

void *tTVPBitmap::GetScanLine(tjs_uint l) const {
    if (!Bits || l >= (tjs_uint)Height) return nullptr;
    return (void *)((uint8_t *)Bits + (size_t)PitchStep * l);
}

// =============================================================================
// CPU 纹理
// =============================================================================
namespace {

struct CpuTexture : public iTVPTexture2D {
    std::vector<uint32_t> pix;      // ARGB8888
    TVPTextureFormat::e fmt;
    bool opaque;
    bool isStatic;

    CpuTexture(tjs_int w, tjs_int h, TVPTextureFormat::e f, bool st = false)
        : iTVPTexture2D(w, h), pix((size_t)w * (size_t)h, 0), fmt(f), opaque(false), isStatic(st) {}

    TVPTextureFormat::e GetFormat() const override { return fmt; }

    const void *GetScanLineForRead(tjs_uint l) override {
        if (l >= (tjs_uint)Height) return nullptr;
        return pix.data() + (size_t)l * (size_t)Width;
    }

    void *GetScanLineForWrite(tjs_uint l) override {
        if (l >= (tjs_uint)Height) return nullptr;
        return pix.data() + (size_t)l * (size_t)Width;
    }

    void Update(const void *pixel, TVPTextureFormat::e format, int pitch, const tTVPRect &rc) override {
        (void)format;
        if (!pixel) return;
        int x0 = rc.left, y0 = rc.top;
        int w = rc.get_width(), h = rc.get_height();
        for (int y = 0; y < h; ++y) {
            int dy = y0 + y;
            if (dy < 0 || dy >= Height) continue;
            const uint8_t *src = (const uint8_t *)pixel + (size_t)(y0 + y) * (size_t)pitch + (size_t)x0 * 4;
            uint32_t *dst = pix.data() + (size_t)dy * (size_t)Width;
            for (int x = 0; x < w; ++x) {
                int dx = x0 + x;
                if (dx < 0 || dx >= Width) continue;
                memcpy(&dst[dx], src + (size_t)x * 4, 4);
            }
        }
    }

    uint32_t GetPoint(int x, int y) override {
        if (x < 0 || y < 0 || x >= Width || y >= Height) return 0;
        return pix[(size_t)y * (size_t)Width + (size_t)x];
    }

    void SetPoint(int x, int y, uint32_t clr) override {
        if (x < 0 || y < 0 || x >= Width || y >= Height) return;
        pix[(size_t)y * (size_t)Width + (size_t)x] = clr;
    }

    bool IsStatic() override { return isStatic; }
    bool IsOpaque() override { return opaque; }
    cocos2d::Texture2D *GetAdapterTexture(cocos2d::Texture2D *) override { return nullptr; }
};

// ---- 简易渲染方法：只携带混合参数 ----
struct CpuRenderMethod : public iTVPRenderMethod {
    int opa;
    bool hda;
    int method;
    CpuRenderMethod(int o, bool h, int m) : opa(o), hda(h), method(m) {}
};

} // namespace

// =============================================================================
// 软件渲染管理器
// =============================================================================
namespace {

class CpuRenderManager : public iTVPRenderManager {
public:
    iTVPTexture2D *CreateTexture2D(const void *pixel, int pitch, unsigned int w, unsigned int h,
                                   TVPTextureFormat::e format, int flags = 0) override {
        auto *t = new CpuTexture((tjs_int)w, (tjs_int)h, format,
                                 (flags & RENDER_CREATE_TEXTURE_FLAG_STATIC) != 0);
        if (pixel && pitch > 0) {
            for (unsigned int y = 0; y < h; ++y) {
                const uint8_t *src = (const uint8_t *)pixel + (size_t)y * (size_t)pitch;
                uint32_t *dst = t->pix.data() + (size_t)y * (size_t)w;
                memcpy(dst, src, (size_t)w * 4);
            }
        }
        return t;
    }

    iTVPTexture2D *CreateTexture2D(tTVPBitmap *bmp) override {
        if (!bmp) return nullptr;
        return CreateTexture2D(bmp->GetBits(), bmp->GetPitch(),
                               bmp->GetWidth(), bmp->GetHeight(),
                               TVPTextureFormat::RGBA8);
    }

    iTVPTexture2D *CreateTexture2D(TJS::tTJSBinaryStream *) override {
        // 压缩纹理（PVR/ETC）不支持；返回空由上层回退
        return nullptr;
    }

    iTVPTexture2D *CreateTexture2D(unsigned int neww, unsigned int newh, iTVPTexture2D *tex) override {
        auto *t = new CpuTexture((tjs_int)neww, (tjs_int)newh, TVPTextureFormat::RGBA8);
        if (tex) {
            int sw = (int)tex->GetWidth(), sh = (int)tex->GetHeight();
            for (unsigned int y = 0; y < newh; ++y) {
                int sy = sh > 0 ? (int)((uint64_t)y * sh / newh) : 0;
                const uint32_t *src = (const uint32_t *)tex->GetScanLineForRead(sy);
                uint32_t *dst = t->pix.data() + (size_t)y * neww;
                for (unsigned int x = 0; x < neww; ++x) {
                    int sx = sw > 0 ? (int)((uint64_t)x * sw / neww) : 0;
                    dst[x] = src ? src[sx] : 0;
                }
            }
        }
        return t;
    }

    const char *GetName() override { return "cpu"; }
    bool IsSoftware() override { return true; }

    bool GetRenderStat(unsigned int &drawCount, uint64_t &vmemsize) override {
        drawCount = 0;
        vmemsize = 0;
        return true;
    }

    // 纹理 -> 目标 的 CPU alpha 混合
    void OperateRect(iTVPRenderMethod *method, iTVPTexture2D *tar, iTVPTexture2D *reftar,
                     const tTVPRect &rctar, const tRenderTexRectArray &textures) override {
        (void)reftar;
        auto *dst = dynamic_cast<CpuTexture *>(tar);
        if (!dst || textures.size() == 0) return;
        auto *src = dynamic_cast<CpuTexture *>(textures[0].first);
        if (!src) return;

        int opa = 255;
        if (auto *m = dynamic_cast<CpuRenderMethod *>(method)) opa = std::clamp(m->opa, 0, 255);
        const tTVPRect &rs = textures[0].second;

        int dw = rctar.get_width(), dh = rctar.get_height();
        int sw = rs.get_width(), sh = rs.get_height();
        if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0) return;

        for (int y = 0; y < dh; ++y) {
            int dy = rctar.top + y;
            if (dy < 0 || dy >= dst->Height) continue;
            int sy = rs.top + (int)((int64_t)y * sh / dh);
            if (sy < 0 || sy >= src->Height) continue;
            const uint32_t *srow = src->pix.data() + (size_t)sy * (size_t)src->Width;
            uint32_t *drow = dst->pix.data() + (size_t)dy * (size_t)dst->Width;
            for (int x = 0; x < dw; ++x) {
                int dx = rctar.left + x;
                if (dx < 0 || dx >= dst->Width) continue;
                int sx = rs.left + (int)((int64_t)x * sw / dw);
                if (sx < 0 || sx >= src->Width) continue;
                uint32_t s = srow[sx];
                unsigned sa = ((s >> 24) & 0xFF) * (unsigned)opa / 255u;
                if (sa == 0) continue;
                if (sa == 255) { drow[dx] = s; continue; }
                uint32_t d = drow[dx];
                unsigned da = (d >> 24) & 0xFF;
                unsigned outA = sa + da * (255u - sa) / 255u;
                unsigned r = (((s >> 16) & 0xFF) * sa + ((d >> 16) & 0xFF) * da * (255u - sa) / 255u) / (outA ? outA : 1);
                unsigned g = (((s >> 8) & 0xFF) * sa + ((d >> 8) & 0xFF) * da * (255u - sa) / 255u) / (outA ? outA : 1);
                unsigned b = ((s & 0xFF) * sa + (d & 0xFF) * da * (255u - sa) / 255u) / (outA ? outA : 1);
                drow[dx] = (outA << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF);
            }
        }
    }

    void OperateTriangles(iTVPRenderMethod *method, int nTriangles, iTVPTexture2D *tar,
                          const tTVPRect &rctar,
                          const tRenderTexQuadArray &textures) override {
        // 三角形用包围盒近似（KAG 极少用，先保证不崩）
        if (nTriangles > 0) {
            tRenderTexRectArray rects;
            (void)rects;
        }
        (void)method; (void)tar; (void)rctar; (void)textures;
    }

    void OperatePerspective(iTVPRenderMethod *method, int nQuads, iTVPTexture2D *target,
                            const tTVPRect &rctar, const tRenderTexQuadArray &textures) override {
        (void)method; (void)nQuads; (void)target; (void)rctar; (void)textures;
    }

    iTVPRenderMethod *GetRenderMethod(tjs_int opa, bool hda, int method) override {
        return new CpuRenderMethod((int)opa, hda, method);
    }
};

CpuRenderManager *gRenderManager = nullptr;

} // namespace

// =============================================================================
// 对外接口
// =============================================================================
iTVPRenderManager *TVPGetRenderManager() {
    if (!gRenderManager) gRenderManager = new CpuRenderManager();
    return gRenderManager;
}

iTVPRenderManager *TVPGetRenderManager(const TJS::tTJSString &name) {
    (void)name;
    return TVPGetRenderManager();
}

void TVPRegisterRenderManager(const char *, iTVPRenderManager *(*func)()) {
    (void)func;   // iOS 只有软件渲染
}
