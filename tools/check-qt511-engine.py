#!/usr/bin/env python3
"""qt511/ 产物在**真实 Qt 5.11.1 引擎**上逐文件加载 —— 与 src/ 同场景对账。

这是 Qt 5.11 支持承诺的**唯一**硬判据：
  · 计数账（改写命中数）只证明「规则按预期命中」
  · 残留扫描只证明「产物没有 Qt6 写法残留」
  · **只有真引擎加载成功，才证明「这份产物在 5.11 上真的能跑」**

判据 = `qml.exe` 的退出码（本机已实测：加载失败 → rc=2，正常 → rc=0；
      console.log 输出会被吞，不能当判据）。
⚠ 每个用例根对象必须是 Window —— 用 Item 作根时 qml.exe 会「did not load
  any objects」却仍回 rc=0，判据就废了（实测踩过）。
"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..'))
QT_BIN = os.path.expanduser('~/.workbuddy/binaries/qt5/5.11.1/msvc2017_64/bin')
EXE = os.path.join(QT_BIN, 'qml.exe')


def qml_files(base):
    for r, _d, fns in os.walk(base):
        for fn in sorted(fns):
            if fn.endswith('.qml'):
                p = os.path.join(r, fn)
                yield p, os.path.relpath(p, base).replace(os.sep, '/')


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else 'qt511'
    base = os.path.join(ROOT, target)
    if not os.path.isdir(base):
        print('FAIL: 目录不存在', base)
        return 2
    if not os.path.isfile(EXE):
        print('FAIL: 找不到 qml.exe', EXE)
        return 2

    env = dict(os.environ)
    env['PATH'] = QT_BIN + os.pathsep + env.get('PATH', '')
    # 让 import QSkin.* 能找到：产物物理目录已等于 URI 路径
    env['QML2_IMPORT_PATH'] = base + os.pathsep + os.path.join(QT_BIN, '..', 'qml')

    files = list(qml_files(base))
    print('=== 真实 Qt 5.11.1 引擎逐文件加载（%s，共 %d 个 qml）===' % (target, len(files)))
    print()

    ok, bad = [], []
    for p, rel in files:
        try:
            r = subprocess.run([EXE, p], cwd=ROOT, env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               timeout=90)
            rc = r.returncode
        except subprocess.TimeoutExpired:
            rc = -1
        (ok if rc == 0 else bad).append((rel, rc))

    print('加载成功 %d / %d' % (len(ok), len(files)))
    print()
    if bad:
        print('加载失败 %d 个：' % len(bad))
        for rel, rc in bad:
            first = ''
            try:
                r2 = subprocess.run([EXE, os.path.join(base, rel)], cwd=ROOT, env=env,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=90)
                err = r2.stderr.decode('utf-8', 'replace').strip()
                out = r2.stdout.decode('utf-8', 'replace').strip()
                for ln in (err.splitlines() or out.splitlines()):
                    if 'is not a type' in ln or 'is not a' in ln or 'module' in ln.lower() \
                            or 'Expected' in ln or 'Unable' in ln or 'Error' in ln:
                        first = ln.strip()[:170]
                        break
            except Exception:
                pass
            print('  rc=%-4s %-44s %s' % (rc, rel, first))
    print()
    print('RESULT: ' + ('OK 全部可加载' if not bad
                        else 'FAIL %d/%d 加载失败' % (len(bad), len(files))))
    return 0 if not bad else 1


if __name__ == '__main__':
    sys.exit(main())