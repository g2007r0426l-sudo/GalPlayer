// =============================================================================
// kr2_ios_prelude.h —— 强制包含的前置声明（补齐个别 TU 缺失的声明）
//
// base/win32/FuncStubs.cpp 里用到了 TextStream 的工厂函数但没有对应声明，
// 这里统一前置声明，避免改上游源码。
// =============================================================================
#ifndef GP_KR2_IOS_PRELUDE_H
#define GP_KR2_IOS_PRELUDE_H

#include "tjsString.h"

class iTJSTextReadStream;
class iTJSTextWriteStream;

extern iTJSTextReadStream *TVPCreateTextStreamForReadByEncoding(const ttstr &name,
                                                               const ttstr &modestr,
                                                               const ttstr &encoding);

#endif
