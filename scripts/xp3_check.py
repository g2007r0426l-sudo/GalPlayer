# -*- coding: utf-8 -*-
"""判断这个 xp3 的 index 是否能按标准格式解析"""
import io, struct, sys, zlib
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

P = r"D:\iPad-JB-logs\xp3"
f = open(P, "rb")
data_head = f.read(64)
import os
size = os.path.getsize(P)
print("size:", size)
print("head:", data_head.hex())

f.seek(11)
u32 = struct.unpack("<I", f.read(4))[0]
print("u32@11 = 0x%08x" % u32)
f.seek(11)
u64 = struct.unpack("<Q", f.read(8))[0]
print("u64@11 =", u64, "(有效偏移? %s)" % (11 <= u64 < size))

f.seek(15)
u64b = struct.unpack("<Q", f.read(8))[0]
print("u64@15 =", u64b, "(有效偏移? %s)" % (11 <= u64b < size))

# 扫尾部找 'File' 标记
f.seek(max(0, size - 400000))
tail = f.read()
pos = tail.find(b"File")
print("尾部含 'File' 于:", (max(0, size-400000) + pos) if pos >= 0 else "无")

# 扫整个文件里第一个 'File'
f.seek(0)
found = False
CH = 8 * 1024 * 1024
prev = b""
base = 0
while True:
    blk = f.read(CH)
    if not blk: break
    buf = prev + blk
    i = buf.find(b"File")
    if i >= 0:
        print("首个 'File' 位置:", base - len(prev) + i)
        found = True
        break
    prev = buf[-8:]
    base += len(blk)
print("是否找到 File 标记:", found)
f.close()
