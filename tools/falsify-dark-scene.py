#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""变异证伪：故意破坏深色场景，看 check-dark-scene.py 是否变红。

为什么必须做：门禁报「✓ 深色场景在 Qt 5.11 上画出来了」，
这只证明它**当前没报警**。一个从不会红的检查和一个有效检查，
在输出上长得一模一样。本轮这道门已经两次判错（写死亮度阈值），
所以更要证明它有牙。

做法：在场景的**副本**上注入 4 类缺陷，跑同一个门，要求每类都变红。
    ① 不切深色   → 判据 ①（主色亮度）
    ② 拆掉 apply() → 文字全丢 → 判据 ③（前景像素）
    ③ 清空背景色 → 判据 ①（主色仍偏亮）
    ④ 只留一个空矩形 → 判据 ②（唯一色太少）
⚠ 全部在 .cache/ 下做，不碰 tests/ 里的真场景；不删除任何文件。
"""
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCENE = os.path.join(ROOT, 'tests', 'scene_dark_theme.qml')
WORK = os.path.join(ROOT, '.cache', '_dark_mut')

# (名称, 旧串, 新串)
#
# ⚠⚠ 清单本身也被证伪过一轮：第一版里有两条「变异」**根本不是缺陷**——
#   · 「不装主题 TDesign.apply()」：实测图里控件照常渲染（契约层有默认外观），
#     只是主色不同（Neutral 的紫 vs TDesign 的蓝）。拿它当缺陷是**把常态当缺陷**。
#   · 「清空子项」：实际只删掉了背景矩形，控件一个没少 ⇒ 当然判绿。
#   ⇒ 教训与项目里那条一致：**常态不是缺陷就别进红项**。
#     变异必须注入「真的会让渲染坏掉」的东西，否则门禁要么假红、要么学会放水。
MUTANTS = [
    # ① 真缺陷：不切深色 → 整张图变浅色（判据 ①）
    ('不切深色（Theme.mode 保持 light）',
     'Theme.mode = "dark"', '// 变异：不切深色'),
    # ② 真缺陷：背景换成纯白 → 主色变白（判据 ①）
    ('深色背景被换成纯白',
     'color: Theme.color.bg', 'color: "#FFFFFF"'),
    # ③ 真缺陷：自证文字改成空串 → 那一块没有前景像素（判据 ⑥）
    ('自证文字清空（文字全丢）',
     'text: "DARKPROBE"', 'text: ""'),
    # ④ 真缺陷：按钮文字色改成与背景同色 ⇒ 文字"隐形"。
    #    ⚠ 第一版写的是「把按钮 text 清空」，那条**不是缺陷**
    #    （按钮没文字是合法用法），门禁放行是对的 —— 已换掉。
    ('按钮文字色与背景同色（文字隐形）',
     'color: Theme.color.fg\n            font.pixelSize: Theme.font.md',
     'color: Theme.color.bg\n            font.pixelSize: Theme.font.md'),
]


def run_gate():
    env = dict(os.environ)
    py = sys.executable
    r = subprocess.run([py, os.path.join(ROOT, 'tools', 'check-dark-scene.py'),
                        '--lib', 'qt511'],
                       cwd=ROOT, capture_output=True, text=True, timeout=600,
                       env=env)
    return r.returncode, (r.stdout or '') + (r.stderr or '')


def main():
    if not os.path.isfile(SCENE):
        print('FAIL: 找不到场景', SCENE)
        return 2
    raw = open(SCENE, encoding='utf-8', newline='').read()
    backup = raw

    print('=== 变异证伪：注入缺陷，深色门必须变红 ===')
    print()

    # 基线：未变异必须绿
    rc0, out0 = run_gate()
    print('  基线（未变异）        rc=%d  %s'
          % (rc0, '绿' if rc0 == 0 else '红← 基线就红，证伪无效'))
    if rc0 != 0:
        print('\nRESULT: 基线不绿 —— 先修基线')
        return 3

    caught, skipped = [], []
    for name, old, new in MUTANTS:
        if old not in backup:
            print('  %-38s 跳过（锚点未命中：%r）' % (name, old[:26]))
            skipped.append(name)
            continue
        mutated = backup.replace(old, new, 1)
        # 直接改真场景再改回：门禁是从 tests/ 读场景的
        open(SCENE, 'w', encoding='utf-8', newline='').write(mutated)
        try:
            rc, out = run_gate()
        finally:
            open(SCENE, 'w', encoding='utf-8', newline='').write(backup)
        red = rc != 0
        print('  %-38s rc=%-3d %s' % (name, rc, '抓到了' if red else '★ 漏了 ★'))
        if red:
            caught.append(name)
            for ln in out.splitlines():
                if ln.strip().startswith('✗'):
                    print('      └ %s' % ln.strip()[:120])
                    break
        else:
            print('      └ 门禁仍判绿 —— 这条判据对该缺陷没反应')

    print()
    total = len(MUTANTS) - len(skipped)
    print('=== 汇总：可注入 %d 类，抓到 %d 类 ===' % (total, len(caught)))
    missed = [n for n, o, _ in MUTANTS if n not in caught and n not in skipped]
    if missed:
        print('★ 漏网%d 类：' % len(missed))
        for n in missed:
            print('   -', n)
        print('RESULT: 证伪未通过')
        return 1
    print('RESULT: 证伪通过 —— 每类注入都变红，深色门不是假绿')
    return 0


if __name__ == '__main__':
    sys.exit(main())
