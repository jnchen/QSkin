#!/usr/bin/env python3
"""隔离「某个契约控件在 Qt 5.11 加载期就崩」的具体原因。

不用 qml.exe 的日志（实测会被吞），改用**逐步降输入**法：
  1. 先测：只 import 该控件文件依赖的模块（不含控件本身）
  2. 再测：把该控件文件里的**每一行顶层语句**按行加回去
  3. 哪一行一加就崩，就是那一行
判据 = 退出码（rc=0 过 / rc=2崩）。
"""
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..'))
QT_BIN = os.path.expanduser('~/.workbuddy/binaries/qt5/5.11.1/msvc2017_64/bin')
EXE = os.path.join(QT_BIN, 'qml.exe')
LIB = os.path.join(ROOT, 'qt511')

TMPL = '''%s
Window {
    visible: true
    width: 200
    height: 200
%s
    Timer { running: true; interval: 40; onTriggered: Qt.quit(0) }
}
'''


def run(imports, body):
    src = TMPL % (imports, body)
    p = os.path.join(HERE, '_bis.qml')
    with open(p, 'w', encoding='utf-8', newline='\n') as f:
        f.write(src)
    env = dict(os.environ)
    env['PATH'] = QT_BIN + os.pathsep + env.get('PATH', '')
    env['QML2_IMPORT_PATH'] = LIB
    try:
        r = subprocess.run([EXE, p], cwd=ROOT, env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
        return r.returncode
    except subprocess.TimeoutExpired:
        return -1


def imports_of(path):
    return '\n'.join(re.findall(r'^import .*$', open(path, encoding='utf-8').read(), re.M))


def main():
    names = sys.argv[1:] or ['QSkinTable', 'QSkinSkeleton', 'QSkinStatistic']
    for name in names:
        f = os.path.join(LIB, 'QSkin', 'Contracts', name + '.qml')
        if not os.path.isfile(f):
            print('%s: 产物不存在' % name)
            continue
        raw = open(f, encoding='utf-8').read()
        imps = imports_of(raw)
        print('=== %s ===' % name)
        rc = run(imps, '')
        print('  仅 import（不含控件）        rc=%d %s' % (rc, 'OK' if rc == 0 else '崩← import 层'))
        if rc != 0:
            # 逐个 import 二分
            for ln in imps.split('\n'):
                if not ln.strip():
                    continue
                r1 = run(ln, '')
                print('      %-46s rc=%d %s' % (ln, r1, 'OK' if r1 == 0 else '崩← 就是它'))
            print()
            continue
        rc = run(imps, '    %s {}' % name)
        print('  加控件本体                    rc=%d %s' % (rc, 'OK' if rc == 0 else '崩← 控件自身'))
        print()


if __name__ == '__main__':
    sys.exit(main())