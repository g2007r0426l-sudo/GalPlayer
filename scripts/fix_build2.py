# -*- coding: utf-8 -*-
"""完善 base 构建：加 ConfigManager 头路径、从编译目录移除 cocos 依赖的 ConfigManager"""
import pathlib

b = pathlib.Path(r"engines/tjs2/build_base.sh")
t = b.read_text(encoding="utf-8")

# 1) 头路径加入 environ/ConfigManager
if "environ/ConfigManager" not in t.split("FLAGS")[0]:
    t = t.replace('-I$CORE/environ/win32 -I$CORE/environ/linux',
                  '-I$CORE/environ/win32 -I$CORE/environ/linux -I$CORE/environ/ConfigManager')
else:
    print("include already present")

# 2) 编译目录里去掉 environ/ConfigManager（其 cpp 依赖 cocos FileUtils，由 stub 替代）
t = t.replace("visual visual/gl movie sound sound/win32 environ/ConfigManager; do",
              "visual visual/gl movie sound sound/win32; do")

b.write_text(t, encoding="utf-8")
print("build_base.sh updated")
