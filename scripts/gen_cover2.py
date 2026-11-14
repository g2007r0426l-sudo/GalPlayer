# -*- coding: utf-8 -*-
"""二次元风格占位封面 v2 —— 正常比例萌系头像"""
import math, random, sys
from PIL import Image, ImageDraw, ImageFilter

W, H = 800, 1000
OUT = sys.argv[1] if len(sys.argv) > 1 else "cover.png"
VARIANT = int(sys.argv[2]) if len(sys.argv) > 2 else 0

PALETTES = [
    dict(top=(255, 226, 238), bot=(206, 200, 250), hairA=(255, 150, 195), hairB=(232, 96, 152),
         iris=(120, 70, 150), accent=(255, 130, 190)),
    dict(top=(214, 240, 255), bot=(224, 210, 252), hairA=(146, 182, 255), hairB=(102, 134, 236),
         iris=(70, 90, 170), accent=(120, 160, 255)),
    dict(top=(255, 240, 214), bot=(252, 212, 228), hairA=(255, 186, 128), hairB=(242, 146, 96),
         iris=(160, 90, 70), accent=(255, 168, 120)),
    dict(top=(224, 248, 236), bot=(204, 226, 252), hairA=(132, 220, 186), hairB=(84, 196, 158),
         iris=(70, 130, 130), accent=(108, 214, 176)),
]
P = PALETTES[VARIANT % len(PALETTES)]
top, bot = P["top"], P["bot"]
hairA, hairB = P["hairA"], P["hairB"]
iris_c, accent = P["iris"], P["accent"]

SS = 2  # 超采样
w, h = W * SS, H * SS
img = Image.new("RGB", (w, h), top)
dr = ImageDraw.Draw(img)

# ---------- 背景渐变 ----------
for y in range(h):
    t = (y / (h - 1)) ** 0.9
    dr.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))

# 柔光
glow = Image.new("L", (w, h), 0)
ImageDraw.Draw(glow).ellipse([w*0.08, -h*0.05, w*0.92, h*0.80], fill=105)
img = Image.composite(Image.new("RGB", (w, h), (255, 255, 255)), img, glow.filter(ImageFilter.GaussianBlur(140*SS)))
dr = ImageDraw.Draw(img, "RGBA")

def star(cx, cy, r, color, alpha=200):
    pts = []
    for k in range(8):
        a = math.pi * k / 4 - math.pi / 2
        rr = r if k % 2 == 0 else r * 0.34
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    dr.polygon(pts, fill=color + (alpha,))

def petal(cx, cy, r, ang, alpha):
    pts = []
    for k in range(20):
        a = 2 * math.pi * k / 20
        rr = r * (0.62 + 0.38 * math.cos(a * 1.0))
        x, y = rr * math.cos(a), rr * math.sin(a) * 0.72
        ca, sa = math.cos(ang), math.sin(ang)
        pts.append((cx + x*ca - y*sa, cy + x*sa + y*ca))
    dr.polygon(pts, fill=(255, 255, 255, alpha))

random.seed(20 + VARIANT)
for _ in range(22):
    petal(random.uniform(0, w), random.uniform(0, h), random.uniform(10, 26) * SS,
          random.uniform(0, math.pi), random.randint(45, 100))
for _ in range(7):
    star(random.uniform(0.06, 0.94) * w, random.uniform(0.05, 0.9) * h,
         random.uniform(9, 20) * SS, (255, 255, 255), random.randint(120, 200))

# ---------- 人物 ----------
cx = w * 0.5
head_cy = h * 0.415
face_rx = w * 0.205
face_ry = w * 0.245

# 后发（大轮廓 + 双马尾）
dr.ellipse([cx - face_rx*1.30, head_cy - face_ry*1.24,
            cx + face_rx*1.30, head_cy + face_ry*1.34], fill=hairB)
for sgn in (-1, 1):
    bx = cx + sgn * face_rx * 1.02
    dr.ellipse([bx - 96*SS*0.8, head_cy + face_ry*0.10,
                bx + 96*SS*0.8, head_cy + face_ry*1.90], fill=hairA)
    dr.ellipse([bx - 66*SS*0.8, head_cy + face_ry*0.95,
                bx + 66*SS*0.8, head_cy + face_ry*2.05], fill=hairB)

# 脸（下缘收窄 → 下巴）
face = Image.new("RGBA", (w, h), (0,0,0,0))
fd = ImageDraw.Draw(face)
fd.ellipse([cx - face_rx, head_cy - face_ry*1.02, cx + face_rx, head_cy + face_ry*0.90],
           fill=(255, 231, 219, 255))
# 下巴三角
fd.polygon([(cx - face_rx*0.60, head_cy + face_ry*0.62),
            (cx + face_rx*0.60, head_cy + face_ry*0.62),
            (cx, head_cy + face_ry*1.10)], fill=(255, 231, 219, 255))
img = Image.alpha_composite(img.convert("RGBA"), face).convert("RGB")
dr = ImageDraw.Draw(img, "RGBA")

# 刘海：顶部圆弧 + 锯齿下缘（下缘控制在眉毛之上）
top_y = head_cy - face_ry * 1.06
arc = []
steps = 40
for i in range(steps + 1):
    a = math.pi * (1 + i / steps)
    arc.append((cx + face_rx*1.06*math.cos(a), top_y + face_ry*0.30*math.sin(a) + face_ry*0.30))
edge = []
n = 7
left = cx - face_rx*1.06; right = cx + face_rx*1.06
for i in range(n + 1):
    x = left + (right - left) * i / n
    dip = face_ry * (0.42 if i % 2 == 0 else 0.20)
    edge.append((x, head_cy - face_ry*0.52 + dip))
dr.polygon(arc + edge[::-1], fill=hairA)

# 呆毛
dr.polygon([(cx + face_rx*0.06, head_cy - face_ry*1.02),
            (cx + face_rx*0.62, head_cy - face_ry*1.58),
            (cx + face_rx*0.30, head_cy - face_ry*0.94)], fill=hairA)

# 发丝高光
hi = Image.new("RGBA", (w, h), (0,0,0,0))
hd = ImageDraw.Draw(hi)
hd.arc([cx - face_rx*0.92, head_cy - face_ry*0.88, cx + face_rx*0.92, head_cy + face_ry*0.28],
       start=200, end=340, fill=(255, 255, 255, 120), width=12*SS)
hd.arc([cx - face_rx*0.62, head_cy - face_ry*0.80, cx + face_rx*0.62, head_cy + face_ry*0.10],
       start=205, end=335, fill=(255, 255, 255, 80), width=8*SS)
img = Image.alpha_composite(img.convert("RGBA"), hi.filter(ImageFilter.GaussianBlur(3*SS))).convert("RGB")
dr = ImageDraw.Draw(img, "RGBA")

# 侧发（细长贴脸）
for sgn in (-1, 1):
    x0 = cx + sgn * face_rx * 0.96
    dr.polygon([(x0, head_cy - face_ry*0.55),
                (x0 + sgn*face_rx*0.20, head_cy - face_ry*0.10),
                (x0 + sgn*face_rx*0.12, head_cy + face_ry*0.95),
                (x0 - sgn*face_rx*0.10, head_cy + face_ry*0.60)], fill=hairA)

# 眼睛
eye_dx = face_rx * 0.45
eye_cy = head_cy + face_ry * 0.13
eye_rx = face_rx * 0.215
eye_ry = face_ry * 0.245
for sgn in (-1, 1):
    ex = cx + sgn * eye_dx
    # 眼白（略带上挑）
    dr.ellipse([ex - eye_rx*1.04, eye_cy - eye_ry*1.05, ex + eye_rx*1.04, eye_cy + eye_ry*1.05],
               fill=(255, 255, 255))
    # 虹膜
    dr.ellipse([ex - eye_rx, eye_cy - eye_ry, ex + eye_rx, eye_ry + eye_cy], fill=iris_c + (255,))
    # 下缘亮环
    dr.ellipse([ex - eye_rx*0.84, eye_cy - eye_ry*0.06, ex + eye_rx*0.84, eye_cy + eye_ry*0.94],
               fill=accent + (235,))
    # 瞳孔
    dr.ellipse([ex - eye_rx*0.40, eye_cy - eye_ry*0.34, ex + eye_rx*0.40, eye_cy + eye_ry*0.58],
               fill=(48, 30, 62))
    # 高光
    dr.ellipse([ex - eye_rx*0.66, eye_cy - eye_ry*0.78, ex - eye_rx*0.06, eye_cy - eye_ry*0.18],
               fill=(255, 255, 255))
    dr.ellipse([ex + eye_rx*0.16, eye_cy + eye_ry*0.22, ex + eye_rx*0.50, eye_cy + eye_ry*0.56],
               fill=(255, 255, 255, 210))
    # 上眼线（粗）
    dr.arc([ex - eye_rx*1.10, eye_cy - eye_ry*1.22, ex + eye_rx*1.10, eye_cy + eye_ry*0.26],
           start=196, end=344, fill=(58, 36, 64), width=int(10*SS))
    # 外眼角小翘
    tipx = ex + sgn * eye_rx * 1.12
    dr.line([(tipx, eye_cy - eye_ry*1.02), (tipx + sgn*eye_rx*0.22, eye_cy - eye_ry*1.20)],
            fill=(58, 36, 64), width=int(7*SS))

# 眉毛
for sgn in (-1, 1):
    bx = cx + sgn * eye_dx
    by = head_cy - face_ry * 0.33
    dr.arc([bx - eye_rx*0.9, by - 14*SS, bx + eye_rx*0.9, by + 26*SS],
           start=208, end=332, fill=(168, 108, 132), width=int(6*SS))

# 腮红
bl = Image.new("RGBA", (w, h), (0,0,0,0))
bd = ImageDraw.Draw(bl)
for sgn in (-1, 1):
    bx = cx + sgn * face_rx * 0.62
    by = eye_cy + eye_ry * 1.35
    bd.ellipse([bx - 64*SS, by - 28*SS, bx + 64*SS, by + 28*SS], fill=(255, 126, 158, 115))
img = Image.alpha_composite(img.convert("RGBA"), bl.filter(ImageFilter.GaussianBlur(11*SS))).convert("RGB")
dr = ImageDraw.Draw(img, "RGBA")

# 嘴（小猫嘴）
mcy = head_cy + face_ry * 0.60
dr.arc([cx - 16*SS, mcy - 8*SS, cx + 4*SS, mcy + 14*SS], start=0, end=180,
       fill=(196, 92, 112), width=int(5*SS))
dr.arc([cx - 4*SS, mcy - 8*SS, cx + 16*SS, mcy + 14*SS], start=0, end=180,
       fill=(196, 92, 112), width=int(5*SS))

# 肩膀 / 衣领
dr.polygon([(cx - face_rx*1.30, h),
            (cx - face_rx*0.72, head_cy + face_ry*1.06),
            (cx + face_rx*0.72, head_cy + face_ry*1.06),
            (cx + face_rx*1.30, h)], fill=(255, 253, 254))
dr.polygon([(cx - face_rx*0.34, head_cy + face_ry*1.02),
            (cx, head_cy + face_ry*1.26),
            (cx + face_rx*0.34, head_cy + face_ry*1.02)], fill=accent + (255,))

img = img.resize((W, H), Image.LANCZOS)
img.save(OUT, quality=92)
print("saved", OUT)
