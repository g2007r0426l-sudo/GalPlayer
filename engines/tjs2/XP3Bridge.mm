// =============================================================================
// XP3Bridge.mm —— 给 TJS2 探针提供 XP3 文件读取（复用 Swift 同款解析逻辑）
// =============================================================================
#import <Foundation/Foundation.h>
#include <vector>
#include <cstring>
#include <cstdlib>
#include <zlib.h>

extern "C" void gp_tjs2_probe(const char *xp3Path);

namespace {

struct Seg { uint64_t start; uint64_t orgSize; uint64_t arcSize; bool compressed; };

static uint32_t rdU32(const uint8_t *p) { uint32_t v; memcpy(&v, p, 4); return v; }
static uint64_t rdU64(const uint8_t *p) { uint64_t v; memcpy(&v, p, 8); return v; }

static std::string rdName(const uint8_t *p, size_t chars) {
    std::string out;
    out.reserve(chars);
    for (size_t i = 0; i < chars; ++i) {
        uint16_t c;
        memcpy(&c, p + i * 2, 2);
        if (c < 0x80) out.push_back((char)c);
        else out.push_back('?');   // 只用于匹配 ASCII 名字
    }
    return out;
}

} // namespace

extern "C" int gp_xp3_read_file(const char *xp3Path, const char *entryName,
                                unsigned char **outBuf, size_t *outLen) {
    if (outBuf) *outBuf = nullptr;
    if (outLen) *outLen = 0;
    if (!xp3Path || !entryName) return -1;

    FILE *fp = fopen(xp3Path, "rb");
    if (!fp) return -2;
    fseek(fp, 0, SEEK_END);
    long fsize = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    if (fsize < 20) { fclose(fp); return -3; }

    uint8_t head[11];
    if (fread(head, 1, 11, fp) != 11 || memcmp(head, "XP3\r\n \n\x1a\x8b\x67\x01", 11) != 0) {
        fclose(fp); return -4;
    }
    uint8_t offb[8];
    if (fread(offb, 1, 8, fp) != 8) { fclose(fp); return -5; }
    uint64_t indexOfs = rdU64(offb);
    if (indexOfs < 11 || indexOfs >= (uint64_t)fsize) { fclose(fp); return -6; }

    fseek(fp, (long)indexOfs, SEEK_SET);
    int flag = fgetc(fp);
    if (flag < 0) { fclose(fp); return -7; }
    int method = flag & 0x07;

    std::vector<uint8_t> index;
    if (method == 0) {
        uint8_t b[8];
        if (fread(b, 1, 8, fp) != 8) { fclose(fp); return -8; }
        uint64_t n = rdU64(b);
        index.resize(n);
        if (fread(index.data(), 1, n, fp) != n) { fclose(fp); return -9; }
    } else if (method == 1) {
        uint8_t b[16];
        if (fread(b, 1, 16, fp) != 16) { fclose(fp); return -10; }
        uint64_t csize = rdU64(b), rsize = rdU64(b + 8);
        std::vector<uint8_t> comp(csize);
        if (fread(comp.data(), 1, csize, fp) != csize) { fclose(fp); return -11; }
        index.resize(rsize);
        uLongf dl = (uLongf)rsize;
        if (uncompress(index.data(), &dl, comp.data(), (uLong)csize) != Z_OK) { fclose(fp); return -12; }
    } else { fclose(fp); return -13; }

    // 遍历 File chunk
    std::string want(entryName);
    size_t p = 0;
    while (p + 12 <= index.size()) {
        if (memcmp(index.data() + p, "File", 4) != 0) break;
        uint64_t csize = rdU64(index.data() + p + 4);
        size_t bodyStart = p + 12;
        size_t bodyEnd = bodyStart + (size_t)csize;
        if (bodyEnd > index.size()) break;

        std::string name;
        std::vector<Seg> segs;
        size_t q = bodyStart;
        while (q + 12 <= bodyEnd) {
            const uint8_t *tag = index.data() + q;
            uint64_t sz = rdU64(index.data() + q + 4);
            size_t ds = q + 12, de = ds + (size_t)sz;
            if (de > index.size()) break;
            if (memcmp(tag, "info", 4) == 0 && sz >= 22) {
                uint16_t nlen = 0;
                memcpy(&nlen, index.data() + ds + 20, 2);
                if (sz >= 22 + (uint64_t)nlen * 2)
                    name = rdName(index.data() + ds + 22, nlen);
            } else if (memcmp(tag, "segm", 4) == 0) {
                for (size_t k = ds; k + 28 <= de; k += 28) {
                    Seg s;
                    uint32_t flags = rdU32(index.data() + k);
                    s.start = rdU64(index.data() + k + 4);
                    s.orgSize = rdU64(index.data() + k + 12);
                    s.arcSize = rdU64(index.data() + k + 20);
                    s.compressed = ((flags & 0x07) == 1);
                    segs.push_back(s);
                }
            }
            q = de;
        }
        if (name == want && !segs.empty()) {
            std::vector<uint8_t> out;
            for (auto &s : segs) {
                std::vector<uint8_t> blob(s.arcSize);
                fseek(fp, (long)s.start, SEEK_SET);
                if (fread(blob.data(), 1, s.arcSize, fp) != s.arcSize) { fclose(fp); return -14; }
                if (s.compressed) {
                    std::vector<uint8_t> raw(s.orgSize);
                    uLongf dl = (uLongf)s.orgSize;
                    if (uncompress(raw.data(), &dl, blob.data(), (uLong)blob.size()) != Z_OK) {
                        fclose(fp); return -15;
                    }
                    out.insert(out.end(), raw.begin(), raw.end());
                } else {
                    out.insert(out.end(), blob.begin(), blob.end());
                }
            }
            fclose(fp);
            unsigned char *buf = (unsigned char *)malloc(out.size());
            memcpy(buf, out.data(), out.size());
            if (outBuf) *outBuf = buf;
            if (outLen) *outLen = out.size();
            return 0;
        }
        p = bodyEnd;
    }
    fclose(fp);
    return -16;
}

extern "C" void gp_xp3_free(unsigned char *p) { free(p); }
