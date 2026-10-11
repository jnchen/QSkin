#!/usr/bin/env python3
"""qt511 产物残留自检 —— 用**代码掩码**口径，排除注释里的说明文字。

为什么不用 grep：降级器自己会往产物里写「Qt 5.11 无 HoverHandler」这类注释，
grep 会把它们数成残留 ⇒ 满屏假红（实测 15/13/4…）。真残留只有掩码后能看见。

用法：python check-residue.py [产物目录，默认 qt511]
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
from qml_downgrade_mask import code_only  # noqa: E402

PATTERNS = [
    ('required property',  r'required\s+property'),
    ('HoverHandler',       r'\bHoverHandler\b'),
    ('TapHandler',         r'\bTapHandler\b'),
    ('WheelHandler',       r'\bWheelHandler\b'),
    ('import ... 2.15',    r'^import\s+\S+\s+2\.15'),
    ('import ... 1.15',    r'^import\s+\S+\s+1\.15'),
    ('preferredRendererType', r'\bpreferredRendererType\b'),
    ('MultiEffect',        r'\bMultiEffect\b'),
    ('import QtQuick.Effects', r'^import\s+QtQuick\.Effects'),
    ('__xxx 内部占位残留', r'^\s*__\w+\s*:'),
]


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else 'qt511'
    if not os.path.isdir(root):
        print('FAIL: 目录不存在', root)
        return 2
    tot = {n: 0 for n, _ in PATTERNS}
    files = 0
    hits = {}
    for r, _d, fns in os.walk(root):
        for fn in fns:
            if not fn.endswith('.qml'):
                continue
            files += 1
            p = os.path.join(r, fn)
            raw = open(p, encoding='utf-8', errors='replace').read()
            c = code_only(raw)
            for n, pat in PATTERNS:
                k = len(re.findall(pat, c, re.M))
                if k:
                    tot[n] += k
                    hits.setdefault(n, []).append((p, k))
    print('=== %s 真代码残留自检（掩码口径，已排除注释）===' % root)
    print('扫描 %d 个 qml' % files)
    print()
    bad = 0
    for n, _p in PATTERNS:
        v = tot[n]
        flag = 'OK  ' if v == 0 else '残留'
        if v:
            bad += 1
        print('  %s %-26s %d' % (flag, n, v))
    print()
    for n, lst in hits.items():
        for p, k in lst[:6]:
            print('    %-26s %s ×%d' % (n, p, k))
    print()
    print('RESULT: ' + ('OK（产物无 Qt6 残留）' if bad == 0
                        else '有 %d 类残留，必须清零才能入库' % bad))
    return 0 if bad == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
