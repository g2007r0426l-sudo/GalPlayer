# -*- coding: utf-8 -*-
"""移除 KRKRVisualStubs.cpp 里的 LocaleConfigManager（改用 KRKRPlatformStubs 的真实签名版）"""
import pathlib

p = pathlib.Path(r"engines/tjs2/KRKRVisualStubs.cpp")
s = p.read_text(encoding="utf-8")
idx = s.find("// 语言配置")
if idx > 0:
    s = s[:idx].rstrip() + "\n"
    p.write_text(s, encoding="utf-8")
    print("removed LocaleConfigManager from visual stubs")
else:
    print("nothing to remove")

# 把 environ/ConfigManager 加进编译目录
b = pathlib.Path(r"engines/tjs2/build_base.sh")
t = b.read_text(encoding="utf-8")
if "environ/ConfigManager" not in t:
    t = t.replace("visual visual/gl movie sound sound/win32; do",
                  "visual visual/gl movie sound sound/win32 environ/ConfigManager; do")
    b.write_text(t, encoding="utf-8")
    print("ConfigManager added to build")
else:
    print("ConfigManager already in build")
