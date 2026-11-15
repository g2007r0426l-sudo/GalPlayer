// =============================================================================
// platform/CCPlatformConfig.h —— iOS 侧桩头
//
// KiriKiri base 层有少量 cocos 头引用（仅用于平台判定），我们不引入 cocos，
// 用这个桩满足编译。真正需要 cocos 的地方（visual/）不参与编译。
// =============================================================================
#ifndef GP_CC_PLATFORM_CONFIG_STUB_H
#define GP_CC_PLATFORM_CONFIG_STUB_H

#define CC_TARGET_PLATFORM 0
#define CC_PLATFORM_IOS 0
#define CC_TARGET_PLATFORM_IOS 0
#define CC_PLATFORM_UNKNOWN 0

#ifndef CC_DLL
#define CC_DLL
#endif

#endif
