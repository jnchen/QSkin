#!/usr/bin/env python3
"""**变异证伪**：故意往qt511 产物里注入缺陷，看门禁是否变红。

为什么必须做：check-qt511-contracts 报「94/94 OK」，但这只证明它
**当前没报警**。一个从不会红的检查和一个有效检查，在输出上长得一模一样。
不证伪，它就只是装饰。

做法：拷贝一份产物到 .cache/，注入 4 类**真会炸**的缺陷，跑同一个门禁，
要求**每一类都必须被抓到**（红）。抓不到 = 门禁没牙。
⚠ 全部在 .cache/ 里做，不碰入库产物；不删除任何文件。
"""
import os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..'))
SRC = os.path.join(ROOT, 'qt511')
WORK = os.path.join(ROOT, '.cache', 'qt511_mutant')

# (名字, 相对路径, 旧串, 新串, 期望门禁结果)
MUTANTS = [
    ('注入不支持的类型 HoverHandler',
     'QSkin/Contracts/QSkinButton.qml',
     'import QtQuick 2.11',
     'import QtQuick 2.11\n    HoverHandler { onHovered: {} }',
     '红'),
    ('把 import 版本改回 Qt 6 的 2.15',
     'QSkin/Contracts/QSkinButton.qml',
     'import QtQuick 2.11',
     'import QtQuick 2.15',
     '红'),
    ('浮层里塞 anchors.centerIn（5.11 非法）',
     'QSkin/Contracts/QSkinDialog.qml',
     '/* Qt 5.11 的浮层不是 Item，不能用anchors */',
     'anchors.centerIn: parent',
     '红'),
    ('恢复 JS 保留字 var as',
     'QSkin/Contracts/QSkinTable.qml',
     'var aS = String(av)',
     'var as = String(av)',
     '红'),
    ('注入 Gradient.orientation（5.11 非法）',
     'QSkin/Contracts/QSkinSkeleton.qml',
     'gradient: Gradient {',
     'gradient: Gradient {\n                        orientation: Gradient.Horizontal',
     '红'),
]


def run_gate(base, ctrl):
    """对给定产物目录跑门禁，返回 (rc, 输出)。

    ⚠ 只跑**注入点相关的那一个控件**（第二个参数），不跑全量 94 个：
    证伪要的是「这条判据有没有牙」，不是「整库好不好」——
    全量跑一次 94 个控件 × 5 个变异 = 470 次引擎启动，本机直接超时。
    """
    env = dict(os.environ)
    py = sys.executable
    r = subprocess.run([py, os.path.join(HERE, 'check-qt511-contracts.py'),
                        base, '--only', ctrl],
                       cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       timeout=600, env=env)
    return r.returncode, r.stdout.decode('utf-8', 'replace')


def ctrl_from(rel):
    """从产物相对路径反推控件名：QSkin/Contracts/X.qml → X"""
    return os.path.splitext(os.path.basename(rel))[0]


def main():
    if not os.path.isdir(SRC):
        print('FAIL: 找不到产物', SRC)
        return 2

    print('=== 变异证伪：注入缺陷，门禁必须变红 ===')
    print()

    # 基线：未变异必须绿（否则后面「变红」说明不了任何事）
    only0 = ctrl_from(MUTANTS[0][1])
    rc0, out0 = run_gate(SRC, only0)
    print('  基线（未变异，只测 %s）  rc=%d  %s'
          % (only0, rc0, '绿' if rc0 == 0 else '红← 基线就红，证伪无效'))
    if rc0 != 0:
        print('\nRESULT: 基线不绿 —— 先修基线再做证伪')
        return 3

    caught = []
    for name, rel, old, new, want in MUTANTS:
        ctrl = ctrl_from(rel)
        if os.path.isdir(WORK):
            shutil.rmtree(WORK, ignore_errors=True)
        shutil.copytree(SRC, WORK)
        p = os.path.join(WORK, rel)
        if not os.path.isfile(p):
            print('  %-44s 跳过（文件不存在）', name)
            continue
        txt = open(p, encoding='utf-8', errors='replace').read()
        if old not in txt:
            print('  %-44s 跳过（锚点未命中：%r）', name, old[:36])
            continue
        open(p, 'w', encoding='utf-8', newline='\n').write(
            txt.replace(old, new, 1))

        rc, out = run_gate(WORK, ctrl)
        is_red = rc != 0
        mark = '抓到了' if is_red else '★ 漏了 ★'
        print('  %-44s rc=%-3d %s' % (name, rc, mark))
        if is_red:
            caught.append(name)
            for ln in out.splitlines():
                if 'unavailable' in ln or 'Expected' in ln or 'Cannot assign' in ln \
                        or 'not installed' in ln or 'not a type' in ln:
                    print('      └ %s' % ln.strip().split(': ', 1)[-1][:130])
                    break
        else:
            print('      └ 门禁仍判绿 —— 这条判据对该缺陷没反应')

    print()
    done = [n for n, r, o, w, _ in MUTANTS if os.path.isfile(os.path.join(WORK, r))]
    print('=== 汇总：注入 %d 类，抓到 %d 类 ===' % (len(MUTANTS), len(caught)))
    missed = [n for n, *_ in MUTANTS if n not in caught]
    if missed:
        print('★ 漏网 %d 类 —— 门禁的真实盲区：' % len(missed))
        for n in missed:
            print('   -', n)
        print('RESULT: 证伪未通过')
        return 1
    print('RESULT: 证伪通过 —— 每一类注入都变红，门禁不是假绿')
    return 0


if __name__ == '__main__':
    sys.exit(main())
