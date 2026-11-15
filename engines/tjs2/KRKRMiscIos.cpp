// =============================================================================
// KRKRMiscIos.cpp —— 收尾桩
//   alSourcefv：OpenAL 批量参数设置（静音）
// =============================================================================
#include <cstdio>

extern "C" void alSourcefv(unsigned int sid, int param, const float *values) {
    (void)sid; (void)param; (void)values;
}
