#!/usr/bin/env python3
"""定位「产物在 Qt 5.11 加载期就崩」的具体原因。

做法：不靠 qml.exe 的日志（实测在本机会被吞），改用**逐步二分**：
  1. 先用一个只 import 各模块、不用任何类型的空壳，测「import 本身」；
  2. 再逐个把控件里用到的可疑类型加进去，看哪个一加就崩。
每步都用退出码当判据（rc=0 通过 / rc=2 崩）。
"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
QT_BIN = os.path.expanduser('~/.workbuddy/binaries/qt5/5.11.1/msvc2017_64/bin')
EXE = os.path.join(QT_BIN, 'qml.exe')
LIB = os.path.abspath(os.path.join(HERE, '..', 'qt511'))

BASE = '''import QtQuick 2.11
import QtQuick.Window 2.2
%s
Window {
    visible: true
    width: 200
    height: 200
%s
    Timer { running: true; interval: 30; onTriggered: Qt.quit(0) }
}
'''


def run(imports, body=''):
    src = BASE % (imports, body)
    p = os.path.join(HERE, '_bisect.qml')
    with open(p, 'w', encoding='utf-8', newline='\n') as f:
        f.write(src)
    env = dict(os.environ)
    env['PATH'] = QT_BIN + os.pathsep + env.get('PATH', '')
    env['QML2_IMPORT_PATH'] = LIB
    r = subprocess.run([EXE, p], cwd=os.path.dirname(HERE), env=env,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
    return r.returncode


def main():
    print('=== 二分定位：先测 import 本身 ===')
    print()
    imps = [
        ('QSkin.Foundation 1.0', 'import QSkin.Foundation 1.0'),
        ('QtQuick.Controls 2.11', 'import QtQuick.Controls 2.11'),
        ('QtQuick.Layouts 1.11', 'import QtQuick.Layouts 1.11'),
        ('QtQuick.Shapes 1.11', 'import QtQuick.Shapes 1.11'),
        ('QtQuick.Window 2.11', 'import QtQuick.Window 2.11'),
        ('QtGraphicalEffects 1.0', 'import QtGraphicalEffects 1.0'),
    ]
    base_rc = run('')
    print('  基线（只 Window）           rc=%d  %s' % (base_rc, 'OK' if base_rc == 0 else '崩'))
    if base_rc != 0:
        print('FAIL: 基线就崩，探针坏了')
        return 3
    for name, imp in imps:
        rc = run(imp)
        print('  import %-24s rc=%d  %s' % (name, rc, 'OK' if rc == 0 else '崩'))
    print()
    print('=== 逐个加类型（先在 QSkin 之外）===')
    for t in ['Popup', 'Menu', 'MenuBar', 'Dialog', 'Drawer', 'ToolTip',
              'ComboBox', 'ScrollView', 'ListView', 'Calendar']:
        rc = run('import QtQuick.Controls 2.11', '    %s { }' % t)
        print('  %-14s rc=%d  %s' % (t, rc, 'OK' if rc == 0 else '崩'))
    return 0


if __name__ == '__main__':
    sys.exit(main())