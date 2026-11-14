# -*- coding: utf-8 -*-
"""生成二次元风格占位封面（程序化绘制，可反复迭代）"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter

W, H = 800, 1000
OUT = sys.argv[1] if len(sys.argv) > 1 else "cover.png"
VARIANT = int(sys.argv[2]) if len(sys.argv) > 2 else 0

PALETTES = [
    # (top, bottom, hairA, hairB, accent)
    ((255, 214, 232), (208, 202, 250), (255, 138, 186), (255, 92, 152), (255, 120, 170)),  # 粉樱
    ((206, 236, 255), (222, 208, 252), (138, 176, 255), (110, 140, 240), (110, 150, 255)),  # 天空蓝
    ((255, 236, 208), (252, 208, 226), (255, 176, 120), (245, 140, 92), (255, 160, 110)),   # 暖橙
    ((219, 246, 231), (200, 224, 252), (120, 220, 180), (86, 200, 160), (100, 210, 170)),  # 薄荷
]
top, bot, hairA, hairB, accent = PALETTES[VARIANT % len(PALETTES)]

img = Image.new("RGB", (W, H), top)
dr = ImageDraw.Draw(img)

# --- 背景竖直渐变 ---
for y in range(H):
    t = y / (H - 1)
    t = t ** 0.92
    c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
    dr.line([(0, y), (W, y)], fill=c)

# --- 中心柔光 ---
glow = Image.new("L", (W, H), 0)
gd = ImageDraw.Draw(glow)
gd.ellipse([W*0.10, H*0.02, W*0.90, H*0.78], fill=110)
glow = glow.filter(ImageFilter.GaussianBlur(120))
img = Image.composite(Image.new("RGB", (W, H), (255, 255, 255)), img, glow)
dr = ImageDraw.Draw(img, "RGBA")

# --- 樱花花瓣 ---
def petal(draw, cx, cy, r, ang, color, alpha):
    pts = []
    for k in range(24):
        a = 2 * math.pi * k / 24
        # 花瓣形：r * (0.55 + 0.45*cos)
        rr = r * (0.62 + 0.38 * math.cos(a))
        x = rr * math.cos(a); y = rr * math.sin(a) * 0.75
        ca, sa = math.cos(ang), math.sin(ang)
        pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
    draw.polygon(pts, fill=color + (alpha,))

import random
random.seed(7 + VARIANT)
for _ in range(26):
    px = random.uniform(-20, W + 20)
    py = random.uniform(-20, H + 20)
    r = random.uniform(10, 26)
    petal(dr, px, py, r, random.uniform(0, math.pi), (255, 255, 255), random.randint(40, 95))

# --- 人物（半身像，偏下）---
cx = W * 0.5
head_cy = H * 0.44
head_rx = W * 0.235
head_ry = W * 0.265

# 头发外轮廓（后发）
dr.ellipse([cx - head_rx*1.16, head_cy - head_ry*1.12,
            cx + head_rx*1.16, head_cy + head_ry*1.24], fill=hairB)
# 双马尾
for sgn in (-1, 1):
    bx = cx + sgn * head_rx * 0.92
    dr.ellipse([bx - 78, head_cy - 40, bx + 78, head_cy + head_ry * 1.5], fill=hairA)
    dr.ellipse([bx - 58, head_cy + head_ry * 0.5, bx + 58, head_cy + head_ry * 1.78], fill=hairB)

# 脸
dr.ellipse([cx - head_rx, head_cy - head_ry, cx + head_rx, head_cy + head_ry * 0.96],
           fill=(255, 228, 214))

# 刘海（前发）：圆弧 + 几缕尖角
bangs = []
n = 9
for i in range(n + 1):
    a = math.pi * (1.0 + i / n)
    x = cx + head_rx * 1.04 * math.cos(a)
    y = head_cy + head_ry * 1.02 * math.sin(a)
    bangs.append((x, y))
# 尖角下沿
tips = []
for i in range(n):
    x0, y0 = bangs[i]; x1, y1 = bangs[i + 1]
    tips.append(((x0 + x1) / 2, max(y0, y1) + head_ry * (0.30 + 0.16 * ((i % 3) - 1))))
poly = bangs + tips[::-1]
dr.polygon(poly, fill=hairA)

# 呆毛
dr.polygon([(cx + 20, head_cy - head_ry * 1.02),
            (cx + 108, head_cy - head_ry * 1.62),
            (cx + 54, head_cy - head_ry * 0.96)], fill=hairA)

# 眼睛
eye_dx = head_rx * 0.44
eye_ry = head_ry * 0.235
eye_rx = head_rx * 0.205
for sgn in (-1, 1):
    ex = cx + sgn * eye_dx
    ey = head_cy + head_ry * 0.10
    # 眼白
    dr.ellipse([ex - eye_rx*1.06, ey - eye_ry*1.06, ex + eye_rx*1.06, ey + eye_ry*1.06],
               fill=(255, 255, 255))
    # 虹膜（竖椭圆，深紫）
    dr.ellipse([ex - eye_rx, ey - eye_ry, ex + eye_rx, ey + eye_ry], fill=(74, 52, 92))
    # 虹膜下缘亮色
    dr.ellipse([ex - eye_rx*0.86, ey - eye_ry*0.15, ex + eye_rx*0.86, ey + eye_ry*0.92],
               fill=accent + (255,))
    # 瞳孔
    dr.ellipse([ex - eye_rx*0.42, ey - eye_ry*0.30, ex + eye_rx*0.42, ey + eye_ry*0.62],
               fill=(52, 34, 70))
    # 高光（大 + 小）
    dr.ellipse([ex - eye_rx*0.62, ey - eye_ry*0.72, ex - eye_rx*0.02, ey - eye_ry*0.16],
               fill=(255, 255, 255))
    dr.ellipse([ex + eye_rx*0.18, ey + eye_ry*0.26, ex + eye_rx*0.52, ey + eye_ry*0.60],
               fill=(255, 255, 255, 220))
    # 上睫毛
    dr.arc([ex - eye_rx*1.12, ey - eye_ry*1.20, ex + eye_rx*1.12, ey + eye_ry*0.30],
           start=195, end=345, fill=(56, 36, 62), width=9)

# 眉毛
for sgn in (-1, 1):
    bx = cx + sgn * eye_dx
    by = head_cy - head_ry * 0.30
    dr.arc([bx - eye_rx*0.95, by - 16, bx + eye_rx*0.95, by + 30],
           start=205, end=335, fill=(150, 96, 120), width=7)

# 腮红
blush = Image.new("RGBA", (W, H), (0, 0, 0, 0))
bd = ImageDraw.Draw(blush)
for sgn in (-1, 1):
    bx = cx + sgn * head_rx * 0.60
    by = head_cy + head_ry * 0.40
    bd.ellipse([bx - 62, by - 30, bx + 62, by + 30], fill=(255, 130, 160, 120))
blush = blush.filter(ImageFilter.GaussianBlur(12))
img = Image.alpha_composite(img.convert("RGBA"), blush).convert("RGB")
dr = ImageDraw.Draw(img, "RGBA")

# 嘴
dr.arc([cx - 26, head_cy + head_ry * 0.52, cx + 26, head_cy + head_ry * 0.70],
       start=20, end=160, fill=(190, 90, 110), width=7)

# 领口 / 衣服
dr.polygon([(cx - head_rx*0.95, H),
            (cx - head_rx*0.55, head_cy + head_ry*1.02),
            (cx + head_rx*0.55, head_cy + head_ry*1.02),
            (cx + head_rx*0.95, H)], fill=(255, 252, 253))
dr.polygon([(cx - 42, head_cy + head_ry*1.00),
            (cx, head_cy + head_ry*1.26),
            (cx + 42, head_cy + head_ry*1.00)], fill=accent + (255,))

# 顶部轻微暗角
vig = Image.new("L", (W, H), 0)
vd = ImageDraw.Draw(vig)
vd.rectangle([0, 0, W, H], fill=0)
vd.ellipse([-W*0.25, -H*0.25, W*1.25, H*1.25], fill=60)
vig = vig.filter(ImageFilter.GaussianBlur(80))
img = Image.composite(Image.new("RGB", (W, H), (36, 28, 52)), img, vig)

img.save(OUT, quality=92)
print("saved", OUT, img.size)
