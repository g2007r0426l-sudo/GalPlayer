# -*- coding: utf-8 -*-
"""修最后 2 个符号：
1) TVPCreateIStream —— include 提前 + 按头文件拼法定义（两个重载都给）
2) tTVPMemoryStream —— 定义全部非内联虚函数，vtable 落在本 TU（顺带可用）
"""
import pathlib

p = pathlib.Path(r"engines/tjs2/KRKRPlatform2Ios.cpp")
s = p.read_text(encoding="utf-8")

# ---- 1) StorageImpl.h include 提前，删掉文件中部旧 include ----
if '#include "StorageImpl.h"' in s:
    s = s.replace('#include "StorageImpl.h"   // 真正的 IStream 类型与 TVPCreateIStream 声明在这里\n', '')
    s = s.replace('#include "GraphicsLoaderIntf.h"',
                  '#include "GraphicsLoaderIntf.h"\n#include "StorageImpl.h"     // IStream 类型 + TVPCreateIStream 声明', 1)
print("include moved:", s.count('#include "StorageImpl.h"'))

# ---- 2) 删掉旧的 TVPCreateIStream 定义（可能与 include 相对位置不对）----
import re
s = re.sub(r'IStream \*TVPCreateIStream\(TJS::tTJSBinaryStream \*\) \{ return nullptr; \}\n?', '', s)
s = re.sub(r'IStream \*TVPCreateIStream\(tTJSBinaryStream \*\) \{ return nullptr; \}\n?', '', s)
print("old defs removed:", 'TVPCreateIStream(TJS::' not in s and s.count('TVPCreateIStream') <= 3)

# ---- 3) 在 include 之后补两个重载（拼法与头文件一字不差）----
anchor = '#include "StorageImpl.h"     // IStream 类型 + TVPCreateIStream 声明'
add = anchor + '''

// 声明在 StorageImpl.h（TJS_EXP_FUNC_DEF = extern）；iOS 无 MF 视频栈，返回空
IStream * TVPCreateIStream(const ttstr &name, tjs_uint32 flags) { (void)name; (void)flags; return nullptr; }
IStream * TVPCreateIStream(tTJSBinaryStream *stream) { (void)stream; return nullptr; }'''
assert anchor in s
s = s.replace(anchor, add, 1)

# ---- 4) tTVPMemoryStream：定义全部非内联函数（vtable 落在本 TU）----
ms_anchor = 'tTVPMemoryStream::tTVPMemoryStream() {}'
ms_add = '''// ---- tTVPMemoryStream：声明在 UtilStreams.h，实现在被跳过的 UtilStreams.cpp ----
// 这里给完整实现（真可用的内存流），vtable 由此 TU 发出
void tTVPMemoryStream::Init() {
    Block = nullptr; Reference = false;
    Size = 0; AllocSize = 0; CurrentPos = 0;
}

tTVPMemoryStream::tTVPMemoryStream() { Init(); }

tTVPMemoryStream::tTVPMemoryStream(const void *block, tjs_uint size) {
    Init();
    if (size) {
        Block = Alloc(size);
        memcpy(Block, block, size);
        Size = size; AllocSize = size;
    }
}

tTVPMemoryStream::~tTVPMemoryStream() {
    if (Block && !Reference) Free(Block);
}

void *tTVPMemoryStream::Alloc(size_t size) { return malloc(size); }
void *tTVPMemoryStream::Realloc(void *org, size_t size) { return realloc(org, size); }
void tTVPMemoryStream::Free(void *block) { free(block); }

tjs_uint64 TJS_INTF_METHOD tTVPMemoryStream::Seek(tjs_int64 offset, tjs_int whence) {
    switch (whence) {
    case 0: CurrentPos = (tjs_uint)offset; break;                          // soFromSet
    case 1: CurrentPos = (tjs_uint)(CurrentPos + offset); break;           // soFromCurrent
    case 2: CurrentPos = (tjs_uint)(Size + offset); break;                 // soFromEnd
    }
    return CurrentPos;
}

tjs_uint TJS_INTF_METHOD tTVPMemoryStream::Read(void *buffer, tjs_uint read_size) {
    if (!Block || CurrentPos >= Size) return 0;
    if (CurrentPos + read_size > Size) read_size = Size - CurrentPos;
    memcpy(buffer, (uint8_t *)Block + CurrentPos, read_size);
    CurrentPos += read_size;
    return read_size;
}

tjs_uint TJS_INTF_METHOD tTVPMemoryStream::Write(const void *buffer, tjs_uint write_size) {
    if (!write_size) return 0;
    if (CurrentPos + write_size > AllocSize) {
        tjs_uint newsize = CurrentPos + write_size;
        if (newsize < AllocSize * 2) newsize = AllocSize * 2;
        void *nb = Realloc(Reference ? nullptr : Block, newsize);
        if (!nb) return 0;
        Block = nb; AllocSize = newsize; Reference = false;
    }
    memcpy((uint8_t *)Block + CurrentPos, buffer, write_size);
    CurrentPos += write_size;
    if (CurrentPos > Size) Size = CurrentPos;
    return write_size;
}

void TJS_INTF_METHOD tTVPMemoryStream::SetEndOfStorage() { Size = CurrentPos; }

void tTVPMemoryStream::Clear(void) {
    if (Block && !Reference) Free(Block);
    Init();
}

void tTVPMemoryStream::SetSize(tjs_uint size) {
    if (!size) { if (Block && !Reference) Free(Block); Init(); return; }
    void *nb = Realloc(Reference ? nullptr : Block, size);
    if (!nb) return;
    Block = nb; AllocSize = size;
    if (Size > size) Size = size;
    if (CurrentPos > size) CurrentPos = size;
    Reference = false;
}
'''
assert ms_anchor in s
s = s.replace(ms_anchor, ms_add, 1)

p.write_text(s, encoding="utf-8")
print("all patched")
