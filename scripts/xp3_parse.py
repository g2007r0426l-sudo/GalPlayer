# -*- coding: utf-8 -*-
"""标准 XP3 解析：index -> 条目列表 -> 提取指定文件"""
import io, os, struct, sys, zlib

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

def parse_xp3(path):
    f = open(path, "rb")
    size = os.path.getsize(path)
    assert f.read(11) == b"XP3\r\n \n\x1a\x8b\x67\x01"
    index_ofs = struct.unpack("<Q", f.read(8))[0]
    assert 11 <= index_ofs < size, "index 偏移非法"

    f.seek(index_ofs)
    flag = struct.unpack("<B", f.read(1))[0]
    method = flag & 0x07
    if method == 0:                      # RAW
        isize = struct.unpack("<Q", f.read(8))[0]
        index = f.read(isize)
    elif method == 1:                    # ZLIB
        csize = struct.unpack("<Q", f.read(8))[0]
        rsize = struct.unpack("<Q", f.read(8))[0]
        index = zlib.decompress(f.read(csize))
        assert len(index) == rsize
    else:
        raise SystemExit("不支持的 index 压缩方式 %d" % method)

    entries = []   # (name, [(start, org, arc, compressed), ...])
    p = 0
    while p + 12 <= len(index):
        tag = index[p:p+4]
        csize = struct.unpack_from("<Q", index, p+4)[0]
        body = index[p+12: p+12+csize]
        if tag != b"File":
            break
        # info
        q = 0
        assert body[q:q+4] == b"info", body[q:q+8]
        isz = struct.unpack_from("<Q", body, q+4)[0]
        info = body[q+12: q+12+isz]
        flags, orgsize, arcsize = struct.unpack_from("<IQQ", info, 0)
        nlen = struct.unpack_from("<H", info, 20)[0]
        name = info[22:22+nlen*2].decode("utf-16-le", errors="replace")
        # segm
        r = q + 12 + isz
        assert body[r:r+4] == b"segm", body[r:r+8]
        ssz = struct.unpack_from("<Q", body, r+4)[0]
        segm = body[r+12: r+12+ssz]
        segs = []
        for k in range(0, len(segm), 28):
            sflags = struct.unpack_from("<I", segm, k)[0]
            start = struct.unpack_from("<Q", segm, k+4)[0]
            s_org = struct.unpack_from("<Q", segm, k+12)[0]
            s_arc = struct.unpack_from("<Q", segm, k+20)[0]
            compressed = ((sflags & 0x07) == 1)
            segs.append((start, s_org, s_arc, compressed))
        entries.append((name, segs))
        p += 12 + csize
    f.close()
    return entries, size

def read_entry(path, segs):
    out = bytearray()
    with open(path, "rb") as f:
        for start, org, arc, comp in segs:
            f.seek(start)
            blob = f.read(arc)
            out += zlib.decompress(blob) if comp else blob
    return bytes(out)

if __name__ == "__main__":
    P = sys.argv[1] if len(sys.argv) > 1 else r"D:\iPad-JB-logs\xp3"
    entries, size = parse_xp3(P)
    print("条目数:", len(entries), " 归档大小:", size)
    for n, _ in entries[:15]:
        print("  ", n)

    # 找标题线索：startup.tjs / *.tjs / first.ks
    cands = [e for e in entries if e[0].lower() in ("startup.tjs", "main.tjs", "config.tjs")]
    if not cands:
        cands = [e for e in entries if e[0].lower().endswith(".tjs")][:3]
    for name, segs in cands:
        try:
            body = read_entry(P, segs)
            txt = body.decode("utf-16-le", errors="replace") if body[:2] in (b"\xff\xfe", b"\xfe\xff") or b"\x00" in body[:40] else body.decode("utf-8", errors="replace")
            print(f"\n=== {name} ({len(body)}B) ===")
            print(txt[:800])
        except Exception as ex:
            print("读取失败", name, ex)
