# -*- coding: utf-8 -*-
"""撤销全局 -include，改为只对 FuncStubs 注入前置声明"""
import pathlib

b = pathlib.Path(r"engines/tjs2/build_base.sh")
t = b.read_text(encoding="utf-8")

# 1) 去掉全局 -include
t = t.replace(' -include kr2_ios_prelude.h"', '"')

# 2) compile_one 内增加按文件注入
old = '''    local rc=0
    case "$src" in'''
new = '''    local rc=0
    local EXTRA=""
    case "$tag" in
        *FuncStubs.cpp) EXTRA="-include $ROOT_DIR/engines/tjs2/iosinc/kr2_ios_prelude.h" ;;
    esac
    case "$src" in'''
if old in t and "EXTRA=" not in t:
    t = t.replace(old, new, 1)
    t = t.replace('clang $FLAGS $INC -c "$src"', 'clang $FLAGS $INC $EXTRA -c "$src"')
    t = t.replace('clang++ $FLAGS $INC -c "$src"', 'clang++ $FLAGS $INC $EXTRA -c "$src"')

b.write_text(t.replace("\r\n", "\n"), encoding="utf-8")
print("done")
