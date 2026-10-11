#!/usr/bin/env python3
"""把 qt511/ 的每个契约控件在**真实 Qt 5.11.1** 上实例化一遍。

为什么不能只加载文件：契约组件是库件，独立 `qml file.qml` 必然失败
（没有宿主、没有 Window）。必须为每个控件生成一个「宿主窗口 + 实例化」
的最小页面，看它**真的能不能被引擎构造出来**。

这比「解析」强一层：实例化会执行 Component.onCompleted、绑定求值、
插槽装配 —— 降级里那些「属性不存在 / 信号没连上」的静默失效
（最典型是 Handler→MouseArea 那类）大多在这一步才暴露。

判据 = qml.exe 退出码（本机实测：失败 rc=2 / 成功 rc=0；console.log 会被吞）。
⚠ 根对象必须是 Window：Item 作根时 qml.exe 回 rc=0 但什么都没加载，
   那是假绿（实测踩过，控件全绿实则一个没测）。
"""
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..'))
QT_BIN = os.path.expanduser('~/.workbuddy/binaries/qt5/5.11.1/msvc2017_64/bin')
EXE = os.path.join(QT_BIN, 'qml.exe')
SCENE = os.path.join(QT_BIN, 'qmlscene.exe')

HOST_TMPL = '''import QtQuick 2.11
import QtQuick.Window 2.2
import QSkin.Contracts 1.0

Window {
    id: win
    visible: true
    width: 420
    height: 320

    // 目标控件：只做**无参实例化**，不加 anchors / width / height。
    // ⚠ 第一版给了 `anchors.fill: parent` + `id: inst`，结果
    //   QSkinRadioGroup / QSkinToggleGroup 这类**不是 Item** 的容器
    //   （成员登记型，无几何）被判红 —— 那是**宿主模板的错**，不是产物缺陷。
    //   判据应是「类型能否被引擎构造出来」，与几何无关。
    Loader {
        id: inst
        sourceComponent: Component {
            %(type)s {}
        }
        onStatusChanged: {
            if (status === Loader.Error) loaderFailed = true
        }
    }

    property bool loaderFailed: false

    Timer {
        running: true
        interval: 120
        // Loader 加载完即算成功：它Ready 说明类型已成功实例化。
        onTriggered: Qt.quit(inst.status === Loader.Error ? 3 : 0)
    }
}
'''


def public_types(contracts_dir):
    """从 qmldir 里读**对外**类型（跳过 singleton 与文件缺失的条目）。

    ⚠ qmldir 里的注释（`#` 开头）里也有 `QSkinXxx 1.0 Xxx.qml` 这样的示例行，
      不去掉就会把注释里的名字当成真类型。第一版没去注释，且正则要求
      `\\w+$` —— 结果**读到 0 个类型却报 OK**（假绿）。
      ⇒ 现在：先剥注释，再匹配真实条目，读到 0 个一律报工装错误。
    """
    out = []
    qmldir = os.path.join(contracts_dir, 'qmldir')
    if not os.path.isfile(qmldir):
        return out
    for ln in open(qmldir, encoding='utf-8', errors='replace'):
        ln = ln.split('#', 1)[0].strip()        # 剥行尾注释
        if not ln or ln.startswith(('module', 'singleton', 'typeinfo', 'plugin',
                                     'depends', 'classname', 'designer', 'import')):
            continue
        m = re.match(r'^([A-Z]\w*)\s+(\d+\.\d+)\s+(\w+\.qml)$', ln)
        if not m:
            continue
        name, impl = m.group(1), m.group(3)
        # 文件必须真实存在，否则是注释残留或历史脏条目
        if os.path.isfile(os.path.join(contracts_dir, impl)):
            out.append((name, impl))
    return out


def qmldir_path(contracts_dir):
    return os.path.join(contracts_dir, 'qmldir')


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else 'qt511'
    base = os.path.join(ROOT, target)
    contracts = os.path.join(base, 'QSkin', 'Contracts')
    if not os.path.isdir(contracts):
        print('FAIL: 找不到', contracts)
        return 2
    if not os.path.isfile(EXE):
        print('FAIL: 找不到 qml.exe', EXE)
        return 2

    types = public_types(contracts)
    # --only：只测指定控件（证伪器用；全量 94 个 × 多个变异会超时）
    only = None
    for i, a in enumerate(sys.argv):
        if a == '--only' and i + 1 < len(sys.argv):
            only = sys.argv[i + 1]
    if only:
        types = [t for t in types if t[0] == only]
    print('=== qt511契约控件在真实 Qt 5.11.1 上逐个实例化 ===')
    print('待测对外类型 %d 个%s' % (len(types), ('（限定 %s）' % only) if only else ''))
    print()
    # ⚠ 读到 0 个类型 = 工装坏了（qmldir 格式变了 / 目录不对），
    #   **不是**「全部通过」。第一版在这里报 OK，是典型假绿。
    if not types:
        print('FAIL: 从 qmldir 读到 0 个对外类型 —— 工装错误，不是「全部通过」')
        print('      qmldir =', qmldir_path(contracts))
        return 3

    env = dict(os.environ)
    env['PATH'] = QT_BIN + os.pathsep + env.get('PATH', '')
    env['QML2_IMPORT_PATH'] = base

    hostdir = os.path.join(base, '..', '.cache', 'qt511hosts')
    os.makedirs(hostdir, exist_ok=True)

    ok, bad = [], []
    for name, impl in types:
        hp = os.path.join(hostdir, '_h_%s.qml' % name)
        with open(hp, 'w', encoding='utf-8', newline='\n') as f:
            f.write(HOST_TMPL % {'type': name})
        try:
            # ⚠ 用 qmlscene 而不是 qml：qml.exe 在本机会把错误日志吞掉
            #   （失败时只回 `Did not load any objects`，拿不到原因）；
            #   qmlscene 会给出 `file:///...:1871 Expected token `identifier'`
            #   这种带行号的真错误。
            # ⚠⚠ 判据必须看**输出里有没有错误行**，不能看退出码：
            #   qmlscene 加载成功后**根本不退出**（要靠宿主里的 Timer 退出），
            #   所以成功路径靠 timeout 结束；第一版把 timeout 当失败，
            #   于是 RadioGroup/ToggleGroup 这类其实通过的控件被误判（假红）。
            #   现在：跑满 timeout 且无错误行 = 通过。
            try:
                r = subprocess.run([SCENE, hp], cwd=ROOT, env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   timeout=8)
                out = r.stdout.decode('utf-8', 'replace') + r.stderr.decode('utf-8', 'replace')
            except subprocess.TimeoutExpired as e:
                # 超时 = 宿主 Timer 没退出（正常路径），不是失败
                o = (e.stdout or b'').decode('utf-8', 'replace')
                er = (e.stderr or b'').decode('utf-8', 'replace')
                out = o + er
            # ⚠ 关键词表要**逐条对账**，不能拿 'Error'/'Cannot' 这类宽泛词 ——
            #   控件运行时打出的正常警告（Unable to assign [undefined] 之类）
            #   也会命中，于是好控件被判红（实测一次就多出 9 个假红）。
            #   这里只收**加载期结构性错误**。
            err_lines = [ln for ln in out.splitlines()
                         if re.search(r'Type \w+ unavailable', ln)
                         or re.search(r'Expected token', ln)
                         or re.search(r'is not a type', ln)
                         or re.search(r'Cannot assign to non-existent', ln)
                         or re.search(r'Syntax error', ln)
                         or re.search(r'Invalid alias target', ln)
                         or re.search(r'is not installed', ln)]
            rc = 1 if err_lines else 0
            err = '\n'.join(err_lines)
        except Exception as e:
            rc, err = -1, str(e)
        if rc == 0:
            ok.append(name)
        else:
            msg = ''
            for ln in err.splitlines():
                if 'is not a type' in ln or 'is not' in ln or 'Unable' in ln \
                        or 'Error' in ln or 'module' in ln.lower():
                    msg = ln.strip()[:160]
                    break
            bad.append((name, rc, msg))

    print('实例化成功 %d / %d' % (len(ok), len(types)))
    print()
    if bad:
        print('失败 %d 个：' % len(bad))
        for n, rc, m in bad:
            print('  rc=%-4s %-32s %s' % (rc, n, m))
        print()
    print('RESULT: ' + ('OK 全部控件在 Qt 5.11.1 上可实例化' if not bad
                        else 'FAIL %d/%d 不可实例化' % (len(bad), len(types))))
    return 0 if not bad else 1


if __name__ == '__main__':
    sys.exit(main())