# -*- coding: utf-8 -*-
"""XP3 解析原型：走 chunk -> 解 index -> 列出文件名 -> 提取 startup.tjs 找标题"""
import io, os, struct, sys, zlib

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

PATH = r"D:\iPad-JB-logs\xp3"
TAG_FILE  = 0x0D768019
TAG_INFO  = 0x0D76801B
TAG_SEEK  = 0x0D76801D
TAG_INDEX = 0x0D76801C

data = open(PATH, "rb").read()
print("文件大小:", len(data))
assert data[:11] == b"XP3\r\n \n\x1a\x8b\x67\x01", "不是 XP3"

off = 11
index_payload = None
while off + 12 <= len(data):
    tag, size = struct.unpack_from("<IQ", data, off)
    if tag == TAG_INDEX:
        index_payload = data[off+12: off+12+size]
        print("找到 index chunk @", off, "size", size)
        break
    off += 12 + size
    if size <= 0 or off > len(data):
        print("走到尽头，没找到 index")
        break

assert index_payload, "没有 index"

# 解压
flag = index_payload[0]
if flag == 0:
    raw = index_payload[1:]
elif flag == 1:
    orig = struct.unpack_from("<Q", index_payload, 1)[0]
    raw = zlib.decompress(index_payload[9:])
    print("index 解压:", len(raw), "/", orig)
else:
    raise SystemExit("未知压缩类型 %d" % flag)

# 暴力扫 UTF-16LE 文件名（.tjs/.ks/.txt），并读出其后的 start/length/orig
names = []
i = 0
needle = ".tjs".encode("utf-16-le")
while True:
    j = raw.find(needle, i)
    if j < 0: break
    # 名字长度 = 前 2 字节（字符数）
    ln_off = j - len("startup.tjs".encode("utf-16-le"))  # 粗略回退
    # 更稳：向前找 2 字节长度，使 name_len*2 正好覆盖到 j+4
    for back in range(2, 200, 2):
        if j + 4 - back < 2: break
        maybe_len = struct.unpack_from("<H", raw, j + 4 - back)[0]
        if maybe_len * 2 == back + 4 - 2:  # 名字字节数 = back+4-2? 近似
            pass
    names.append(j)
    i = j + 2

print("index 里 .tjs 出现次数:", len(names))

# 用结构化方式解析 info 段
info_size = struct.unpack_from("<I", raw, 0)[0]
print("info_size:", info_size)
p = 4
end = 4 + info_size
entries = []
while p + 12 <= end:
    flags = struct.unpack_from("<I", raw, p)[0]; p += 4
    hash_part = b""
    if flags & 0x80000000:
        hash_part = raw[p:p+8]; p += 8
    if p + 2 > len(raw): break
    nlen = struct.unpack_from("<H", raw, p)[0]; p += 2
    nbytes = nlen * 2
    if p + nbytes + 12 > len(raw): break
    name = raw[p:p+nbytes].decode("utf-16-le", errors="replace"); p += nbytes
    start, length, orig_len = struct.unpack_from("<III", raw, p); p += 12
    entries.append((name, start, length, orig_len))
    if len(entries) <= 12:
        print(f"  {name}  start={start} len={length} orig={orig_len}")

print("总条目:", len(entries))
if not entries:
    raise SystemExit("info 解析失败")

targets = [e for e in entries if e[0].lower() in ("startup.tjs", "config.tjs", "main.tjs")]
print("候选:", [t[0] for t in targets])

def extract(e):
    name, start, length, orig_len = e
    # start 指向 File chunk 的 tag 位置
    tag, size = struct.unpack_from("<IQ", data, start)
    assert tag == TAG_FILE, hex(tag)
    payload = data[start+12: start+12+size]
    if length == orig_len:
        return payload
    return zlib.decompress(payload)

for e in targets:
    try:
        body = extract(e)
        text = body.decode("utf-16-le", errors="replace") if e[0].lower().endswith(".tjs") else body.decode("utf-8", errors="replace")
        print(f"\n=== {e[0]} ({len(body)} bytes) ===")
        print(text[:1200])
    except Exception as ex:
        print("提取失败", e[0], ex)
