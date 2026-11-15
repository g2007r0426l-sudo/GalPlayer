# -*- coding: utf-8 -*-
"""启用 FuncStubs/UtilStreams、前置声明头、编入 BasicDrawDevice"""
import pathlib

b = pathlib.Path(r"engines/tjs2/build_base.sh")
t = b.read_text(encoding="utf-8")

# 1) 编译参数加 -include prelude
if "-include kr2_ios_prelude.h" not in t:
    t = t.replace('-D_7ZIP_ST -DLINUX -DKR2_IOS"',
                  '-D_7ZIP_ST -DLINUX -DKR2_IOS -include kr2_ios_prelude.h"')

# 2) 从跳过名单里移除 FuncStubs / UtilStreams
t = t.replace("base/win32/FuncStubs.cpp ", " ")
t = t.replace("base/UtilStreams.cpp ", " ")

# 3) 额外编译 BasicDrawDevice.cpp（找不到就跳过，脚本里用 find 兜底）
if "BasicDrawDevice.cpp" not in t:
    t = t.replace(
        '# iOS 平台层实现',
        '''# 软件绘制设备（TVP 的 BasicDrawDevice：纯 CPU 合成）
BBD=$(find "$CORE/visual" -name "BasicDrawDevice.cpp" -print -quit)
if [ -n "$BBD" ]; then
    compile_one "$BBD" "visual/BasicDrawDevice.cpp"
fi

# iOS 平台层实现'''
    )

b.write_text(t.replace("\r\n", "\n"), encoding="utf-8")
print("build_base.sh updated (LF)")
