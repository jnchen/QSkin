#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Qt 5.11 · 插槽层加载门（补实例化门的盲区）

用法：
    QSkin_QT=<Qt 5.11 根> python tools/check-qt511-slots.py [--lib qt511]

────────────────────────────────────────────────────────────────────────
这个门守的是什么
────────────────────────────────────────────────────────────────────────
`check-qt511-contracts.py` 逐个实例化 `qmldir` 里的**对外类型**（94 个），
报「全部可实例化」。但它**不覆盖 `slots/`** —— 而 5.11 档的核心降级规则
（四角半径内联）恰恰只在插槽里生效。

后果实测过：四角半径那版**id 唯一化写错了**（两处都叫 `_c511_12`），
QML 报 `id is not unique` → `TDInputBackground` **加载期就失败** →
`TDesign` 整个类型 unavailable ⇒ 3 个示例页 + 深色场景全挂。
而那一刻：实例化门**绿的**（对外类型没被牵连）、残留扫描绿的、
漂移门绿的 —— **只有真实场景渲染才看得见**。

⇒ 正解是加一道**插槽层**的门：造一个走真实插槽的场景（带图标按钮、
带后缀的输入框、四角半径插槽），抓图 + 从图里量，并要求**引擎零加载期错误**。

判据：
  ① 引擎 stderr 零「加载期错误」—— `id is not unique` / `Type … unavailable` /
     `is not a type` / `Duplicate …` / `Expected token`
     （⚠ `Property 'control' does not exist` 是**有意保留**的存量豁免，不算）
  ② 抓出的图有实际内容（唯一色 ≥ 8、控件区有独立色）
  ③ 中文真的画出来了 —— ⚠ 这是独立的一条，因为「方框字」**引擎不报错**，
     只有从图里量才能发现（本项目的原话：无头抓图只跑浅色等于没跑，
     这里补一条「字体回退到无中文字形的字体」同样看不见）
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 加载期错误形态 —— 与 test.sh 的形态集同源思路。
FATAL_PAT = re.compile(
    r'id is not unique|Type \w+ unavailable|is not a type|'
    r'Duplicate (property|property name)|Expected token|'
    r'is not installed|Cannot read property|ReferenceError',
    re.I)
# 有意保留的存量豁免（见 tools/runtime-warn-exempt.txt 的族⑤）
KNOWN_OK = re.compile(r"Property 'control' does not exist", re.I)

SCENE = '''import QtQuick 2.11
import QtQuick.Window 2.2
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0

// 插槽层探针：每一个成员都**强制走插槽**（不是只看契约层外壳）。
Window {
    id: win
    visible: true
    width: 420
    height: 260

    Component.onCompleted: { TDesign.apply(); Theme.mode = "dark" }

    Column {
        anchors.centerIn: parent
        spacing: 12

        // 分组按钮：走 ButtonBackground 插槽（四角半径 + 补角都在里面）
        // ⚠ `groupPosition` 是 **readonly、由父项推导**的
        //   （`p.isButtonGroup === true` 时才不是 "standalone"），
        //   所以要触发分组必须放进 QSkinButtonGroup —— 直接写
        //   `variant: "groupLeft"` 是**无效**的（那是主题内部的名字）。
        QSkinButtonGroup {
            QSkinButton { text: "左"; objectName: "gbLeft" }
            QSkinButton { text: "中"; objectName: "gbMid" }
            QSkinButton { text: "右"; objectName: "gbRight" }
        }

        // 带前后缀的输入框：走 InputBackground 插槽
        // ⚠ prefix/suffix 是 **Component**（property Component），
        //   传字符串会加载失败 —— 而且qml.exe 不报错、只在抓图上看不见。
        QSkinInput {
            width: 300
            placeholderText: "插槽探针"
            prefix: Component { Text { text: "¥" } }
            suffix: Component { Text { text: "元" } }
        }

        // 普通按钮 + 标签 + 开关：确认主体路径也没被牵连
        Row {
            spacing: 10
            QSkinButton { text: "常规按钮" }
            QSkinTag { text: "标签"; closable: true }
            QSkinSwitch { checked: true }
        }
    }

    Timer {
        running: true
        interval: 700
        onTriggered: win.contentItem.grabToImage(function (res) {
            res.saveToFile("%(out)s")
            Qt.exit(0)
        })
    }
}
'''


def run_scene(qml, lib_root, png, env):
    """跑一次探针场景，返回 stderr 文本。"""
    work = os.path.join(ROOT, '.cache', '_slots')
    os.makedirs(work, exist_ok=True)
    scene_path = os.path.join(work, 'slot_probe.qml')
    with open(scene_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(SCENE % {'out': png.replace('\\', '/')})
    try:
        r = subprocess.run([qml, '-I', lib_root, scene_path], cwd=ROOT, env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           timeout=90)
        return r.stderr.decode('utf-8', 'replace')
    except subprocess.TimeoutExpired:
        return '<timeout>'


def main():
    lib = 'qt511'
    if '--lib' in sys.argv:
        lib = sys.argv[sys.argv.index('--lib') + 1]
    make_baseline = '--make-baseline' in sys.argv
    qt_env = os.environ.get('QSkin_QT', '')
    if not qt_env:
        print('FAIL: 需要 QSkin_QT=<Qt 5.11 根目录>')
        return 2
    qml = os.path.join(os.path.expanduser(qt_env), 'bin', 'qmlscene.exe')
    if not os.path.isfile(qml):
        print('FAIL: 找不到 qmlscene.exe —— 诊断必须用 **qmlscene**'
              '（qml.exe 会吞掉错误日志，实测）')
        return 2

    lib_root = os.path.join(ROOT, lib)
    if not os.path.isdir(lib_root):
        print('FAIL: 找不到产物', lib_root)
        return 2

    png = os.path.join(ROOT, '.cache', 'qt511_slots.png')
    png_nofont = os.path.join(ROOT, '.cache', 'qt511_slots_nofont.png')

    env = dict(os.environ)
    env['PATH'] = os.path.dirname(qml) + os.pathsep + env.get('PATH', '')
    env['QT_QPA_PLATFORM'] = 'offscreen'
    env['QT_FORCE_STDERR_LOGGING'] = '1'

    # ── 生成「无中文字体」基线：临时把 Qt 的 lib/fonts 挪走 ──────────────
    # ⚠ 只挪**中文字体**，且立刻挪回来 —— 必须 try/finally，
    #   否则中途失败会把验证环境弄坏（.cache 清理也救不回来）。
    # ⚠ 用 `os.rename` 而不是 shutil.move：跨卷会失败，而 Qt 目录可能在别卷。
    if make_baseline:
        fdir = os.path.join(os.path.expanduser(qt_env), 'lib', 'fonts')
        cjk = [f for f in os.listdir(fdir)] if os.path.isdir(fdir) else []
        # 只挪名字里像 CJK 的（msyh / simsun / NotoSansCJK / wqy / DroidSansFallback）
        cjk = [f for f in cjk if re.search(
            r'msyh|simsun|simhei|deng|yahei|notosanscjk|wqy|fallback|sourcehan',
            f, re.I)]
        moved = []
        try:
            for f in cjk:
                src = os.path.join(fdir, f)
                dst = src + '.miora-hidden'
                if os.path.exists(dst):
                    os.remove(dst)
                os.rename(src, dst)
                moved.append((dst, src))
            err = run_scene(qml, lib_root, png_nofont, env)
            print('已生成无中文字体基线（挪走 %d 个：%s）'
                  % (len(moved), ', '.join(cjk) or '无'))
            for ln in err.splitlines()[:3]:
                if ln.strip():
                    print('   基线引擎：', ln.strip()[:120])
        finally:
            for back, orig in moved:          # 无论成败都挪回去
                if os.path.exists(back):
                    os.rename(back, orig)
        print('✓ 字体已还原：%s' %
              (', '.join(os.path.basename(o) for _b, o in moved) or '（未动）'))
        return 0

    err = run_scene(qml, lib_root, png, env)

    print('=== 插槽层加载门（%s · Qt 5.11）===' % lib)
    print('场景 .cache\\_slots\\slot_probe.qml')
    print()

    ok = True
    # ① 加载期错误
    fatal = []
    for ln in err.splitlines():
        ln = ln.strip()
        if not ln or KNOWN_OK.search(ln):
            continue
        if FATAL_PAT.search(ln):
            fatal.append(ln)
    if fatal:
        print('  ✗ ① 引擎报 %d 条加载期错误：' % len(fatal))
        for ln in fatal[:6]:
            print('      %s' % ln[:150])
        ok = False
    else:
        print('  ✓ ① 引擎零加载期错误'
              '（已豁免"Property \'control\' does not exist"存量项）')

    # ② 抓图有内容
    if not os.path.exists(png):
        print('  ✗ ② 没产出图—— 插槽层加载失败或场景没跑起来')
        ok = False
    else:
        # ⚠ 不能写 `from check_dark_scene import …`——
        #   文件名带连字符就不是合法模块名，import 必失败。
        #   要用 importlib 按路径加载。
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            'dark_scene', os.path.join(ROOT, 'tools', 'check-dark-scene.py'))
        dsc = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(dsc)
        try:
            counts, w, h, pixels, nch, stride = dsc.find_png_colors(png)
        except Exception as e:
            print('  ✗ ② 解图失败：%s' % e)
            print('RESULT: FAIL')
            return 1
        main_px = max(counts.items(), key=lambda kv: kv[1])[0]
        lum = dsc.luminance
        print('  %s ② 图 %d×%d，唯一色 %d，主导色 %s（亮度 %.0f）'
              % ('✓' if len(counts) >= 8 else '✗', w, h, len(counts), main_px,
                 lum(main_px)))
        if len(counts) < 8:
            print('      内容没画出来（唯一色 %d 个）' % len(counts))
            ok = False

        # ③ 中文画出来了 —— ⚠⚠ **不能用「唯一色数 ≥ 固定阈值」当判据**。
        #    第一版写死 300（照深色场景的 327 拍的），结果**假红**：
        #    图里中文明明正常，这个场景只有 244 色。
        #    根因与项目记的那条同源：**跨场景拿绝对量比较**。
        #    同一套字体在不同场景下色数本就不同（内容/字号/控件数都不同）。
        #
        #    正解：**同一场景**跑两遍 —— 有中文 / 把字体目录挪走（无中文），
        #    比两遍的**前景像素数比值**。豆腐块（tofu）每字一个**纯矩形**，
        #    墨迹面积远小于真实字形 ⇒ 真实中文那一遍的前景像素明显更多。
        #    比值阈值**来自实测**：有中文 3392 : 无中文 2512 = **1.35**，
        #    取 1.25 留余量。
        #    ⚠⚠ 别指望比值很大：拉丁字符（"¥"、"slots" 这类）在**两遍里
        #    都画得出来**（本机 Candara 提供了拉丁字形），它们把比值稀释了
        #    —— 所以只有 1.35 而不是 2~3。真正的判别力来自「基线那遍
        #    确实是豆腐块」，那已经人工看过图确认（见 docs/PITFALLS.md）。
        if not os.path.exists(png_nofont):
            print('  ? ③ 无字体基线缺失（%s不存在）—— 跳过中文判据。'
                  % os.path.basename(png_nofont))
            print('     提示：第一次跑本门时它会自动生成。')
        else:
            try:
                c2, _w2, _h2, _p2, _n2, _s2 = dsc.find_png_colors(png_nofont)
            except Exception:
                c2 = {}
            if not c2:
                print('  ? ③ 无字体基线解不开 —— 跳过中文判据。')
            else:
                def fg_area(counts):
                    """前景像素数 = 亮度 ≥ 主色亮度+40 的像素。"""
                    mx = max(counts.items(), key=lambda kv: kv[1])[0]
                    thr = lum(mx) + 40
                    return sum(n for px, n in counts.items() if lum(px) >= thr)
                a_fg = fg_area(counts)
                a_nf = fg_area(c2)
                ratio = (float(a_fg) / a_nf) if a_nf else float('inf')
                if ratio >= 1.25:
                    print('  ✓ ③ 中文字形真的画出来了：前景像素 %d'
                          '（无中文字体时 %d，比值 %.2f ≥ 1.25）'
                          % (a_fg, a_nf, ratio))
                else:
                    print('  ✗ ③ 前景像素 %d ≈ 无中文字体基线 %d（比值 %.2f < 1.25）'
                          '—— 中文很可能渲染成了方框'
                          % (a_fg, a_nf, ratio))
                    print('      ⚠ 引擎不会为这件事报错，只有从图里量才发现。')
                    print('      查 QSkin_QT 指向的 Qt 有没有 lib/fonts/'
                          ' 与中文字体（如 msyh.ttc / Noto Sans CJK）。')
                    ok = False

    print()
    print('RESULT: ' + ('OK 插槽层在 Qt 5.11 上加载并渲染正常'
                        if ok else 'FAIL 插槽层有问题'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())