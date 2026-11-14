# -*- coding: utf-8 -*-
"""把抓到的二次元横图裁成 3:4 竖版封面（智能偏移裁切）"""
import glob, os, sys
from PIL import Image

SRC = r"D:\iPad-JB-logs\anime"
DST = r"D:\AA下载文件其他别乱动\Deepseek听话\GalPlayer\app\GalPlayer\Resources\covers"
os.makedirs(DST, exist_ok=True)

files = sorted(glob.glob(os.path.join(SRC, "a*.jpg")))
print("源图:", len(files))

TW, TH = 720, 960  # 3:4，足够 iPad 卡片与横幅使用
for i, p in enumerate(files, start=1):
    im = Image.open(p).convert("RGB")
    w, h = im.size
    # 目标宽高比
    target_ratio = TW / TH
    if w / h > target_ratio:
        # 太宽 → 左右裁，偏移量按序号变化（避免全是中央）
        new_w = int(h * target_ratio)
        offset = int((w - new_w) * [0.5, 0.62, 0.38, 0.55, 0.45, 0.68, 0.42, 0.58][(i - 1) % 8])
        box = (max(0, offset), 0, max(0, offset) + new_w, h)
    else:
        new_h = int(w / target_ratio)
        offset = int((h - new_h) * 0.35)
        box = (0, max(0, offset), w, max(0, offset) + new_h)
    im2 = im.crop(box).resize((TW, TH), Image.LANCZOS)
    out = os.path.join(DST, f"cover{i}.jpg")
    im2.save(out, quality=88, optimize=True)
    print(f"  cover{i}.jpg  {im2.size}  {os.path.getsize(out)//1024}KB")

print("完成 →", DST)
