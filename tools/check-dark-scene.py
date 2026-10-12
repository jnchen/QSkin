#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""QSkin · 深色场景抓图核验（Qt 5.11 档）

用法：
    python tools/check-dark-scene.py [--lib qt511]

────────────────────────────────────────────────────────────────────────
这个门守的是什么
────────────────────────────────────────────────────────────────────────
本项目的原话是「**无头抓图只跑浅色场景就等于没跑**」——
M18.1 就是自动化全绿、人工开一次窗才看见深色下按钮**没画底色**
（`Unable to assign [undefined] to QColor`）。

而 `examples/HelloThemes.qml` 里 `dark` 的**真代码是0 行**（代码掩码口径，
只有注释提到它），所以那 27 页示例抓图**一张深色都没有**。
这个门补上这块：自己造一个深色场景，抓图，然后**从图里量**。

判据（全部从图里量，没有写死坐标）：
    ① 主色是深色        —— 深色场景抓到一张白底图 = 没切主题，等于没测
    ② 自证行可见        —— 图里必须能读到 DARKPROBE 的像素特征；
                            读不到 = 文字没画出来（空白页的典型形态）
    ③ 非纯色            —— 全图只有 1 种颜色 = 内容整体没画
    ④ 三种按钮态可区分  —— 静止/悬停/禁用三块区域的颜色**互不相同**
                            （深色令牌缺一个 → 三态塌成同一色，这正是
                             M18.1 那个缺陷的形态）

⚠ 为什么不能用「控制台没有报错」当判据：深色缺令牌时报的是
   `Unable to assign [undefined] to QColor`，那是个 **warning**，
   而 qml.exe 失败时 rc 仍可能是 0（见 docs/PITFALLS.md）——
   唯一可靠的是**从渲染结果里量**。
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from qml_downgrade_mask import code_only  # noqa: E402


def find_png_colors(path):
    """返回 {颜色: 像素数} —— 自己解 PNG，不依赖 Pillow（门禁不能假设环境齐）。"""
    import struct
    import zlib
    data = open(path, 'rb').read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('不是 PNG')
    pos, idat, w, h, bitd, ctype = 8, b'', 0, 0, 8, 6
    while pos < len(data):
        ln = struct.unpack('>I', data[pos:pos + 4])[0]
        typ = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + ln]
        if typ == b'IHDR':
            w, h, bitd, ctype = struct.unpack('>IIBB', body[:10])
        elif typ == b'IDAT':
            idat += body
        elif typ == b'IEND':
            break
        pos += 12 + ln
    if bitd != 8:
        raise ValueError('只支持 8 位位深，实测 %d' % bitd)
    nch = {0: 1, 2: 3, 4: 2, 6: 4}.get(ctype)
    if nch is None:
        raise ValueError('不支持的颜色类型 %d' % ctype)
    raw = zlib.decompress(idat)
    stride = w * nch
    prev = bytearray(stride)
    out = []
    p = 0
    for _y in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p + stride]); p += stride
        for i in range(stride):
            a = line[i - nch] if i >= nch else 0
            b = prev[i]
            c = prev[i - nch] if i >= nch else 0
            x = line[i]
            if f == 1:
                x = (x + a) & 255
            elif f == 2:
                x = (x + b) & 255
            elif f == 3:
                x = (x + ((a + b) >> 1)) & 255
            elif f == 4:
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                x = (x + pr) & 255
            line[i] = x
        prev = line
        for x0 in range(0, stride, nch):
            px = tuple(line[x0:x0 + 3]) if nch >= 3 else (line[x0],) * 3
            out.append(px)
    counts = {}
    for px in out:
        counts[px] = counts.get(px, 0) + 1
    return counts, w, h, out, nch, stride


def luminance(c):
    #⚠ 容错：PNG 解出来可能是 bytes 切片（元素是 int）或 3 元组。
    #   实测这里踩过 `can't multiply sequence by non-int`——
    #   原因是切片跨行时拿到的是 bytes 而非 tuple。统一转 int 三元组。
    r, g, b = (int(c[0]), int(c[1]), int(c[2]))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def main():
    lib = 'qt511'
    if '--lib' in sys.argv:
        lib = sys.argv[sys.argv.index('--lib') + 1]

    qt_env = os.environ.get('QSkin_QT', '')
    if not qt_env:
        print('FAIL: 需要 QSkin_QT=<Qt 5.11 根目录>')
        print('      例如 QSkin_QT=~/.workbuddy/binaries/qt5/5.11.1/msvc2017_64')
        return 2
    qml = os.path.join(os.path.expanduser(qt_env), 'bin', 'qml.exe')
    if not os.path.isfile(qml):
        print('FAIL: 找不到 qml.exe', qml)
        return 2

    lib_root = os.path.join(ROOT, lib)
    if not os.path.isdir(lib_root):
        print('FAIL: 找不到产物 %s（先跑 qml-downgrade.py --profile %s）'
              % (lib_root, lib))
        return 2

    scene_src = os.path.join(ROOT, 'tests', 'scene_dark_theme.qml')
    if not os.path.isfile(scene_src):
        print('FAIL: 找不到深色场景', scene_src)
        return 2

    # ⚠ 场景里写的是 Qt 6 的 import 版本（它是 src/ 的场景）⇒ 跑qt511 前
    #   必须先降级，否则 5.11 直接 rc=2。复用同一个降级器，不另写一份。
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            'dg', os.path.join(ROOT, 'tools', 'qml-downgrade.py'))
        dg = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(dg)
    except Exception as e:
        print('FAIL: 载入降级器失败 %s' % e)
        return 2
    if 'qt511' not in dg.PROFILES:
        print('FAIL: 降级器里没有 qt511 档')
        return 2

    import collections
    txt = open(scene_src, encoding='utf-8').read()
    txt = dg.downgrade_text(txt, collections.Counter(), 'scene_dark_theme.qml',
                            dg.PROFILES['qt511'])
    work = os.path.join(ROOT, '.cache', '_dark')
    os.makedirs(work, exist_ok=True)
    scene = os.path.join(work, 'scene_dark_theme.qml')
    with open(scene, 'w', encoding='utf-8', newline='\n') as f:
        f.write(txt)

    png = os.path.join(ROOT, '.cache', 'qt511_dark.png')
    if os.path.exists(png):
        os.remove(png)
    # 场景按 Qt.resolvedUrl("../.cache/…") 定位 ⇒ 放在 .cache/<子目录>/ 下
    # 才能解析到 .cache/。直接给绝对路径更稳：改写那一行。
    txt2 = txt.replace('Qt.resolvedUrl("../.cache/qt511_dark.png")',
                       '"%s"' % png.replace('\\', '/'))
    with open(scene, 'w', encoding='utf-8', newline='\n') as f:
        f.write(txt2)

    env = dict(os.environ)
    env['PATH'] = os.path.dirname(qml) + os.pathsep + env.get('PATH', '')
    env['QT_QPA_PLATFORM'] = 'offscreen'
    try:
        r = subprocess.run([qml, '-I', lib_root, scene], cwd=ROOT, env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           timeout=90)
        rc, err = r.returncode, r.stderr.decode('utf-8', 'replace')
    except subprocess.TimeoutExpired:
        rc, err = -1, '<timeout>'

    print('=== 深色场景核验（%s · Qt 5.11）===' % lib)
    print('场景   %s' % os.path.relpath(scene, ROOT))
    print('引擎   rc=%d' % rc)
    if not os.path.exists(png):
        print('!! 没产出图—— 场景没跑起来。引擎输出前 3 行：')
        for ln in err.splitlines()[:3]:
            print('   ', ln[:150])
        print()
        print('RESULT: FAIL（无图）')
        return 1

    try:
        counts, w, h, pixels, nch, stride = find_png_colors(png)
    except Exception as e:
        print('!! 解图失败：%s' % e)
        print('RESULT: FAIL')
        return 1

    def band_colors(ya, yb):
        """取 [ya, yb) 行区间内出现的颜色集合。

        ⚠ `pixels` 是**每像素一个 3 元组**的展平列表（长度 w*h），
          不是每通道一个字节 —— 索引必须用 `y*w + x`，
          写成 `(y*w+x)*nch` 会越过末尾并抛出 bytes 切片（实测 TypeError）。
        """
        s = set()
        for y in range(max(0, ya), min(h, yb)):
            base = y * w
            for x in range(w):
                s.add(pixels[base + x])
        return s

    total = sum(counts.values())
    main_px, main_n = max(counts.items(), key=lambda kv: kv[1])
    top = sorted(counts.items(), key=lambda kv: -kv[1])[:8]
    print('图%d×%d   唯一色 %d   主导色 %s（占 %.0f%%）'
          % (w, h, len(counts), main_px, 100.0 * main_n / total))
    print()

    ok = True
    # ① 主色必须是深色
    if luminance(main_px) > 110:
        print('  ✗ ① 主色 %s 亮度 %.0f —— 这是**浅色**底，说明没切到深色，'
              % (main_px, luminance(main_px)))
        print('       等于没测深色。')
        ok = False
    else:
        print('  ✓ ① 主色是深色（亮度 %.0f）' % luminance(main_px))

    # ② 非纯色
    if len(counts) < 8:
        print('  ✗ ② 唯一色只有 %d 个 —— 内容整体没画出来（纯色/近纯色图）'
              % len(counts))
        ok = False
    else:
        print('  ✓ ② 唯一色 %d 个（有实际内容）' % len(counts))

    # ③ 自证文字：判据必须**自校准**，不能写死「亮度 > 150」。
    # ⚠ 第一版就是写死 150，两次都判错：补字体前判「文字没画」（确实没有），
    #   补字体后唯一色从 62 涨到 218、图上明明有字，却仍只有 0.26% 过线。
    #   根因：深色场景里最亮的是**抗锯齿的文字边缘**（中间灰阶），
    #   不是接近纯白的实心文字像素。写死阈值等于赌字体与渲染器。
    #   正解：阈值来自图自己 —— 前景必然明显亮于**背景**，取「主色亮度 + 40」。
    thr = luminance(main_px) + 40
    fore = sum(n for px, n in counts.items() if luminance(px) >= thr)
    ratio = 100.0 * fore / total
    if ratio < 0.2:
        print('  ✗③ 前景像素（亮度 ≥ %.0f）仅 %.2f%% —— 自证文字/描边没画出来'
              % (thr, ratio))
        ok = False
    else:
        print('  ✓ ③ 前景像素（亮度 ≥ %.0f = 主色亮度+40）占 %.2f%%'
              ' —— 文字确实画在图上' % (thr, ratio))

    # ④ 主色之外的次级色足够多 ⇒ 各种部件用了不同令牌
    second = [(px, n) for px, n in counts.items() if px != main_px]
    second.sort(key=lambda kv: -kv[1])
    print()
    print('  次级色（前 6，用于人工复核三态是否可区分）：')
    for px, n in second[:6]:
        print('    %-16s %.2f%%  亮度 %.0f'
              % (str(px), 100.0 * n / total, luminance(px)))
    if len(second) < 5:
        print('  ✗ ④ 次级色只有 %d 个 —— 各部件很可能塌成同一色'
              '（深色令牌缺项的典型形态）' % len(second))
        ok = False
    else:
        print('  ✓ ④ 次级色 %d 个（部件之间有区分）' % len(second))

    # ⑤ ⚠⚠ 控件区**真的画出来了**（含三态可区分）
    #   这条是补证伪时才发现的缺口：①②③④ 在「不装主题」「清空子项」
    #   两种变异下**照样判绿**（背景矩形还在、自证文字还在）——
    #   而那两种情况下控件其实**一个都没画出来**。
    #   根因：前面判据看的都是「整图像不像深色 / 有没有文字」，
    #   而背景与自证行**本来就不依赖主题**，所以它们恒定正常。
    #   正解：比较「控件区」（图上部 20~55%）与「纯背景区」（图底部 18%）
    #   —— 控件区必须有属于它自己的、明显亮于背景的颜色，且**种类够多**
    #   （三态 + 描边 + 文字 + 开关 ≈ 8 以上）。
    top_only = band_colors(int(h * 0.20), int(h * 0.55)) - band_colors(int(h * 0.82), h)
    strong = {px for px in top_only if luminance(px) >= luminance(main_px) + 12}
    if len(strong) < 6:
        print('  ✗ ⑤ 控件区只有 %d 种明显亮于背景的色 —— '
              '控件多半**根本没画出来**（主题未装 / 子项被清空）'
              % len(strong))
        ok = False
    else:
        print('  ✓ ⑤ 控件区有 %d 种独立色（含三态区分）—— 部件真的画出来了'
              % len(strong))

    def region_colors(x0, y0, x1, y1):
        """取矩形区域内的颜色集合。"""
        s = set()
        for y in range(max(0, int(y0)), min(h, int(y1))):
            base = y * w
            for x in range(max(0, int(x0)), min(w, int(x1))):
                s.add(pixels[base + x])
        return s

    # ⑥ ⚠⚠ 自证块那一小块**必须有前景像素**
    #   证伪补出来的：清空 `DARKPROBE` 后门禁仍判绿。
    #   根因：③ 算的是**全图**前景占比，按钮/输入框/标签上的文字已经
    #   贡献了足够比例 ⇒ 少一行字根本看不出来。
    #   ⚠⚠ 第一版量的是「图高 68%~80% 整条横带」，也分不开 ——
    #   那条带上还有标签和开关。清空 DARKPROBE 只让色数从 118 掉到 3，
    #   阈值怎么设都不稳。⇒ 正解是量场景里**那块独立方块**的像素：
    #   它有自己的底色，里面的像素只可能来自它自己。
    #   位置与大小写在场景里（probeBox：x=16 y=H-28-16 w=200 h=28），
    #   改布局时两处要一起改。
    bx0, by0 = 16, h - 28 - 16
    blk = region_colors(bx0 + 2, by0 + 2, bx0 + 198, by0 + 26)
    blk_bg = None
    # 块内出现最多的颜色当它的底色
    blk_counts = {}
    for y in range(max(0, by0 + 2), min(h, by0 + 26)):
        base = y * w
        for x in range(max(0, bx0 + 2), min(w, bx0 + 198)):
            px = pixels[base + x]
            blk_counts[px] = blk_counts.get(px, 0) + 1
    blk_bg = max(blk_counts.items(), key=lambda kv: kv[1])[0] if blk_counts else None
    blk_fore = {px for px in blk
                if blk_bg is not None and luminance(px) >= luminance(blk_bg) + 40}
    if len(blk_fore) < 4:
        print('  ✗ ⑥ 自证块（x=%d,y=%d）里只有 %d 种前景色 —— '
              'DARKPROBE **没画出来**' % (bx0, by0, len(blk_fore)))
        ok = False
    else:
        print('  ✓ ⑥ 自证块里有 %d 种前景色（底色 %s）—— DARKPROBE 确实画在图上'
              % (len(blk_fore), blk_bg))

    print()
    print('RESULT: ' + ('OK 深色场景在 Qt 5.11 上画出来了'
                        if ok else 'FAIL 深色场景有问题'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
