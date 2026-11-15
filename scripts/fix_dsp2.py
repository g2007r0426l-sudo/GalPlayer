# -*- coding: utf-8 -*-
"""IndividualConfigManager 无显式 ctor：删掉类外定义，GetInstance 用静态实例"""
import pathlib

p = pathlib.Path(r"engines/tjs2/KRKRDSPConfigIos.cpp")
s = p.read_text(encoding="utf-8")

old = '''IndividualConfigManager::IndividualConfigManager() { Initialize(); }

void IndividualConfigManager::Clear()'''
new = '''void IndividualConfigManager::Clear()'''
assert old in s, "anchor missing"
s = s.replace(old, new, 1)

old2 = '''IndividualConfigManager *IndividualConfigManager::GetInstance() {
    static IndividualConfigManager *inst = new IndividualConfigManager();
    return inst;
}'''
new2 = '''IndividualConfigManager *IndividualConfigManager::GetInstance() {
    static IndividualConfigManager inst;   // 隐式默认构造
    return &inst;
}'''
assert old2 in s, "anchor2 missing"
s = s.replace(old2, new2, 1)

p.write_text(s, encoding="utf-8")
print("fixed")
