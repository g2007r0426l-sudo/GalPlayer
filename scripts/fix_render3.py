# -*- coding: utf-8 -*-
"""按真实签名修正 OperateTriangles/OperatePerspective，并把 GetRenderMethod 改为类外定义"""
import pathlib, re

p = pathlib.Path(r"engines/tjs2/KRKRRenderIos.cpp")
s = p.read_text(encoding="utf-8")

start = s.find("    void OperateTriangles(")
end = s.find("    iTVPRenderMethod *GetRenderMethod(")
assert start > 0 and end > start, "anchors not found"

new_ops = '''    void OperateTriangles(iTVPRenderMethod *method, int nTriangles,
                          iTVPTexture2D *target, iTVPTexture2D *reftar,
                          const tTVPRect &rcclip, const tTVPPointD *pttar,
                          const tRenderTexQuadArray &textures) override {
        // 三角形/透视在 KAG 里极少用；先按「整块矩形」近似，保证不崩
        if (nTriangles <= 0 || !target || textures.size() == 0) return;
        auto *t = dynamic_cast<CpuTexture *>(target);
        if (!t) return;
        tTVPRect rc = rcclip;
        if (rc.get_width() <= 0 || rc.get_height() <= 0) {
            rc.set_width(t->Width);
            rc.set_height(t->Height);
        }
        tRenderTextureArray<tTVPRect> single(const_cast<std::pair<iTVPTexture2D *, tTVPRect> *>(&textures[0]), 1);
        OperateRect(method, target, reftar, rc, single);
        (void)pttar;
    }

    void OperatePerspective(iTVPRenderMethod *method, int nQuads, iTVPTexture2D *target,
                            iTVPTexture2D *reftar, const tTVPRect &rcclip,
                            const tTVPPointD *pttar,
                            const tRenderTexQuadArray &textures) override {
        if (nQuads <= 0 || !target || textures.size() == 0) return;
        auto *t = dynamic_cast<CpuTexture *>(target);
        if (!t) return;
        tTVPRect rc = rcclip;
        if (rc.get_width() <= 0 || rc.get_height() <= 0) {
            rc.set_width(t->Width);
            rc.set_height(t->Height);
        }
        tRenderTextureArray<tTVPRect> single(const_cast<std::pair<iTVPTexture2D *, tTVPRect> *>(&textures[0]), 1);
        OperateRect(method, target, reftar, rc, single);
        (void)pttar;
    }

'''

# 删除旧的 GetRenderMethod 定义（含函数体），稍后用类外定义补上
tail_start = s.find("    iTVPRenderMethod *GetRenderMethod(", start)
tail_end = s.find("};", tail_start)
assert tail_start > 0 and tail_end > tail_start
s = s[:start] + new_ops + s[tail_end:]

# 类外定义 GetRenderMethod（上游在 RenderManager.cpp 里实现，我们替代）
if "iTVPRenderManager::GetRenderMethod" not in s:
    s += '''
// 上游在 RenderManager.cpp 内实现；这里给 CPU 版本（只携带混合参数）
iTVPRenderMethod *iTVPRenderManager::GetRenderMethod(tjs_int opa, bool hda, int method) {
    return new CpuRenderMethod((int)opa, hda, method);
}
'''
p.write_text(s, encoding="utf-8")
print("render file fixed")
