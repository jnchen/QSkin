#!/usr/bin/env python3
"""把 qt511 降级结果写到 .cache/（**不碰入库产物**）供真引擎验证。

为什么要这一步：`qml-downgrade.py` 的生成模式会先 rmtree 整个产物目录，
在门禁里跑会被宿主的批量删除拦下（项目踩坑记录里就有这条）。
而 `--check` 虽不写盘，却只能比对、**拿不到能跑的文件**，
于是「新规则改得对不对」没有验证手段。

这里只做一件事：把内存里的降级文本写到 .cache/qt511_verify/。
写的是**验证副本**，与 qt511/ 入库产物互不相干；删它也不影响任何东西。
"""
import os, sys, collections

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..'))
sys.path.insert(0, HERE)

import importlib.util
spec = importlib.util.spec_from_file_location('dg', os.path.join(HERE, 'qml-downgrade.py'))
dg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dg)

SRC = os.path.join(ROOT, 'src')
DST = os.path.join(ROOT, '.cache', 'qt511_verify')
PROFILE = sys.argv[1] if len(sys.argv) > 1 else 'qt511'
WITH_EX = '--with-examples' in sys.argv


def main():
    prof = dg.PROFILES[PROFILE]
    modmap = dg.module_map(SRC)
    if not modmap:
        print('FAIL: src 结构不符预期（找不到 qmldir）')
        return 2
    counters = collections.Counter()
    n = 0
    for root, _dirs, files in os.walk(SRC):
        rel = os.path.relpath(root, SRC).replace(os.sep, '/')
        if rel == '.':
            continue
        uri = None
        for mf in modmap:
            if rel == mf or rel.startswith(mf + '/'):
                if uri is None or len(mf) > len(uri[0]):
                    uri = (mf, modmap[mf])
        if uri is None:
            continue
        sub = rel[len(uri[0]):].lstrip('/')
        dst_dir = os.path.join(DST, uri[1].replace('.', os.sep), sub.replace('/', os.sep)) if sub \
            else os.path.join(DST, uri[1].replace('.', os.sep))
        for fn in files:
            sp = os.path.join(root, fn)
            dp = os.path.join(dst_dir, fn)
            text = open(sp, encoding='utf-8', errors='replace').read()
            if fn.endswith(('.qml', '.js')):
                text = dg.downgrade_text(text, counters, os.path.relpath(sp, SRC), prof)
            os.makedirs(os.path.dirname(dp), exist_ok=True)
            open(dp, 'w', encoding='utf-8', newline='\n').write(text)
            n += 1

    if WITH_EX:
        ex_src = os.path.join(ROOT, 'examples')
        ex_dst = os.path.join(DST, 'examples')
        m = 0
        for root, _dirs, files in os.walk(ex_src):
            for fn in files:
                if not fn.endswith('.qml'):
                    continue
                sp = os.path.join(root, fn)
                dp = os.path.join(ex_dst, os.path.relpath(sp, ex_src))
                text = open(sp, encoding='utf-8', errors='replace').read()
                text = dg.downgrade_text(text, counters, os.path.relpath(sp, ex_src), prof)
                os.makedirs(os.path.dirname(dp), exist_ok=True)
                open(dp, 'w', encoding='utf-8', newline='\n').write(text)
                m += 1
        print('示例页 %d 个→ %s' % (m, ex_dst))

    print('库文件 %d 个 → %s' % (n, DST))
    print('（验证副本，**不是**入库产物）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
