# -*- coding: utf-8 -*-
"""生成横版封面（给「继续上次」大卡）与 App 图标"""
import glob, math, os
from PIL import Image, ImageDraw, ImageFilter

ROOT = r"D:\AA下载文件其他别乱动\Deepseek听话\GalPlayer\app"
SRC = r"D:\iPad-JB-logs\anime"
WIDE_DIR = os.path.join(ROOT, "GalPlayer", "Resources", "covers_wide")
os.makedirs(WIDE_DIR, exist_ok=True)

# ---------- 1. 横版封面 1200x675（16:9），裁切偏上取脸 ----------
files = sorted(glob.glob(os.path.join(SRC, "a*.jpg")))
TW, TH = 1200, 675
for i, p in enumerate(files, start=1):
    im = Image.open(p).convert("RGB")
    w, h = im.size
    ratio = TW / TH
    if w / h > ratio:
        nw = int(h * ratio)
        ox = int((w - nw) * [0.5, 0.4, 0.6, 0.45, 0.55, 0.35, 0.65, 0.5][(i-1) % 8])
        box = (max(0, ox), 0, max(0, ox) + nw, h)
    else:
        nh = int(w / ratio)
        # 偏上裁，保留人物头部
        oy = int((h - nh) * 0.18)
        box = (0, max(0, oy), w, max(0, oy) + nh)
    im.crop(box).resize((TW, TH), Image.LANCZOS).save(
        os.path.join(WIDE_DIR, f"wide{i}.jpg"), quality=86, optimize=True)
print("横版封面:", len(files))

# ---------- 2. App 图标 ----------
def make_icon(size):
    S = size * 4
    img = Image.new("RGB", (S, S), (255, 255, 255))
    dr = ImageDraw.Draw(img)
    # 渐变底（樱粉 -> 薰衣草）
    top, bot = (255, 176, 208), (186, 178, 246)
    for y in range(S):
        t = y / (S - 1)
        dr.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))

    # 柔和光晕
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse([S*0.08, S*0.02, S*0.92, S*0.86], fill=120)
    img = Image.composite(Image.new("RGB", (S, S), (255, 255, 255)), img,
                          glow.filter(ImageFilter.GaussianBlur(S//12)))
    dr = ImageDraw.Draw(img, "RGBA")

    # 樱花花瓣
    def petal(cx, cy, r, ang, alpha):
        pts = []
        for k in range(20):
            a = 2 * math.pi * k / 20
            rr = r * (0.62 + 0.38 * math.cos(a))
            x, y = rr * math.cos(a), rr * math.sin(a) * 0.75
            ca, sa = math.cos(ang), math.sin(ang)
            pts.append((cx + x*ca - y*sa, cy + x*sa + y*ca))
        dr.polygon(pts, fill=(255, 255, 255, alpha))

    for (fx, fy, fr, fa, fang) in [(0.20, 0.20, 0.075, 150, 0.6), (0.82, 0.26, 0.06, 130, 1.9),
                                    (0.24, 0.80, 0.055, 120, 2.6), (0.80, 0.78, 0.08, 140, 0.9)]:
        petal(S*fx, S*fy, S*fr, fang, fa)

    # 中央白色圆盘 + 萌脸
    cx = cy = S * 0.5
    R = S * 0.29
    dr.ellipse([cx-R, cy-R, cx+R, cy+R], fill=(255, 255, 255, 235))
    # 眼睛
    eye_dx, eye_r = R * 0.42, R * 0.15
    for sgn in (-1, 1):
        ex = cx + sgn * eye_dx
        ey = cy - R * 0.10
        dr.ellipse([ex-eye_r*0.82, ey-eye_r*1.15, ex+eye_r*0.82, ey+eye_r*1.15], fill=(58, 40, 68))
        dr.ellipse([ex-eye_r*0.50, ey-eye_r*0.78, ex-eye_r*0.02, ey-eye_r*0.28], fill=(255, 255, 255))
        # 腮红
        bx = cx + sgn * R * 0.62
        by = cy + R * 0.20
        bl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(bl).ellipse([bx-R*0.20, by-R*0.10, bx+R*0.20, by+R*0.10],
                                   fill=(255, 128, 160, 110))
        img = Image.alpha_composite(img.convert("RGBA"), bl.filter(ImageFilter.GaussianBlur(S//80))).convert("RGB")
        dr = ImageDraw.Draw(img, "RGBA")
    # 嘴
    mw = R * 0.26
    dr.arc([cx-mw, cy+R*0.06, cx+mw, cy+R*0.34], start=15, end=165, fill=(214, 108, 130), width=max(2, S//90))

    return img.resize((size, size), Image.LANCZOS)

ICON_DIRS = [os.path.join(ROOT, "GalPlayer", "Resources"),
             os.path.join(ROOT, "OnsPlayer", "Resources")]
SIZES = [1024, 180, 167, 152, 144, 120, 114, 87, 80, 76, 60, 58, 57, 40, 29]
for d in ICON_DIRS:
    os.makedirs(d, exist_ok=True)
    for s in SIZES:
        make_icon(s).save(os.path.join(d, f"AppIcon{s}.png"), optimize=True)
print("图标生成完成:", ICON_DIRS)
