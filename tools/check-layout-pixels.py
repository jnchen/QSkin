#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""QSkin · 布局层像素门（M29）

用法：
    python tools/check-layout-pixels.py .cache/m29_layout_ant.png

一般不用直接调 —— `tools/check-layout-pixels.sh` 会先抓图再调这里，
`tools/test.sh` 的第 3.8 节会自动带上它。

────────────────────────────────────────────────────────────────────────
这个文件守的是什么
────────────────────────────────────────────────────────────────────────
`smoke_layout*.qml` 那三道门全是**属性侧**的（读 `x` / `y` / `width`）。
本项目的原话是「**属性值对 ≠ 界面画对**」—— M27 的 `QSkinKbd` 就是属性门与
冒烟全绿、只有抓图能看见问题。布局这一层在 M29 之前**一道像素门都没有**。

这里核验两件在属性侧没法确证的事：

    ① **余量落在哪里**（justify 的 start / center / end）
    ② **间隙真的是不是 gap**（属性侧读 `spacing` 只能证明"我设了"）

判据全部来自**从图里量出来的东西**，没有一个写死的像素坐标：

    · 容器范围     ← 量锚条（tests/scene_layout_justify.qml 里那条 4px 实心条）
    · 缩放比       ← 锚条的物理宽 / 它的逻辑宽 580（高 DPI 下 grabToImage
                     会按 devicePixelRatio 出图；不折回来所有坐标都会错）
    · 前景/背景    ← 本行众数色当背景、本行离背景最远的像素当前景参考，
                     判据是「更靠近前景还是背景」—— **零阈值自校准**
                     （见 spans_at 的文档串）

────────────────────────────────────────────────────────────────────────
场景约定（与 tests/scene_layout_justify.qml 一一对应，改一边要改两边）
────────────────────────────────────────────────────────────────────────
    容器 580 宽、3 枚 40×40 色块、gap 8  →  内容宽 3×40 + 2×8 = 136
    start  组左沿 = 容器左沿 + 0
    center 组左沿 = 容器左沿 + (580−136)/2 = 222
    end    组左沿 = 容器左沿 + 580−136    = 444
    最后一行是原生 RowLayout（反证）：Qt 把余量摊进间距，间隙远大于 8

退出码：0 = 全部成立；1 = 有判据失败；2 = 输入/环境问题。
"""

import os
import sys
from collections import Counter

try:
    from PIL import Image
except ImportError:
    print("!! 需要 Pillow —— 用托管的 python 跑（tools/check-layout-pixels.sh 会去找）")
    sys.exit(2)


# ═══════════════════════════ 场景约定 ═════════════════════════════════════
# ⚠ 这些数字是**场景定义**，不是"被测量的假设"。被测量的东西（余量落在
#   哪里、间隙多宽）读的是 y 坐标与"哪一列是前景"，两者都在下面从图里量。

CONTAINER_W = 580
BLOCK_W = 40
BLOCK_H = 40
GAP = 8
GROUP_W = BLOCK_W * 3 + GAP * 2              # 136

Y_ANCHOR = 12                                 # 锚条中央（条高 4，y ∈ [10,14)）
Y_START = 60                                  # 色块行 y ∈ [40, 80)
Y_CENTER = 130                                # y ∈ [110, 150)
Y_END = 200                                   # y ∈ [180, 220)
Y_RAW = 270                                   # 原生 RowLayout，y ∈ [250, 290)

# 场景画布的逻辑尺寸（tests/scene_layout_justify.qml 里 canvas 的 width）。
# ⚠ 高 DPI 下 `grabToImage` 按 devicePixelRatio 出图 —— 本机实测 **1.5×**
#   （1050 / 700）。所以：**下面的 y 一律按逻辑坐标给**，扫图前统一乘 SCALE；
#   而 SCALE 由"图宽 / 画布逻辑宽"定，再用锚条独立复核一次（见 main 第 0 节）。
CANVAS_W = 700
SCALE = 1.0                       # 由 main() 按图尺寸设定

# 逻辑像素容差。为什么不是 0：抗锯齿让边缘像素落在前景与背景之间，判定
# 「更靠近哪边」会把边界推开或收进 1px —— 这是渲染的物理必然，不是配色
# 假设。缩放比 > 1 时物理像素上的偏差同比放大，故判据统一折回逻辑像素再比。
TOL = 1.5

# 反证那一档的判据：只要求"明显大于 gap"，不钉内部数字 —— 与
# smoke_layout_gap.qml [1] / smoke_layout_justify.qml [4] 同一收窄理由：
# Qt 若微调分配规则，语义（间隙 ≠ gap）不变，那条判据不该假红。
RAW_GAP_MIN = 48

BG_IMG_CORNER = (0, 0)                        # 仅用于诊断打印，不参与判据


def dist2(a, b):
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def pick_bg(img):
    """全图众数色 = 背景色（一图一标定，全行复用）。

    为什么**不**在每一行各自取众数：M29 实测把它打回来了 —— 锚条那一行
    （逻辑 y=12）里蓝色 580px 压过白色 120px，于是"行内众数"选中了**前景**，
    背景与前景整体颠倒，锚条行量出两段白。改成一图一标定之后，前提只剩
    "背景占图面多数"（本场景约 94%），比"每行的背景都最多"宽得多。
    """
    colors = img.getcolors(maxcolors=1 << 24)
    if not colors:
        return (255, 255, 255)
    return max(colors, key=lambda t: t[0])[1]


def spans_at(img, y_logical, bg):
    """把第 y_logical 行（**逻辑坐标**）压成前景游程。
    返回 (fgref, [(s, e), ...])，s / e 是**物理像素**。

    **无阈值自校准**：
      · bg    = `pick_bg()` 从图里量出来的背景色
      · fgref = 本行**出现次数最多的非背景色** —— 不需要预先知道前景是什么色。
                按频次降序找第一个非背景色，天然把装饰 / 抗锯齿碎片排在后面
                （M29 教训：改成"离背景最远的那个像素"时，一处装饰碎片就能
                 把判定整体带偏）。
      · 判据  = dist(c,bg) > dist(c,fgref)，即「更靠近前景还是背景」。
    全程不含任何写死的颜色或亮度阈值，换主题 / 换配色都不用改这里。
    """
    y = int(round(y_logical * SCALE))
    w = img.width
    px = [img.getpixel((x, y))[:3] for x in range(w)]
    fgref = bg
    for c, _n in Counter(px).most_common():
        if dist2(c, bg) > 0:
            fgref = c
            break
    fg = [dist2(c, bg) > dist2(c, fgref) for c in px]

    out = []
    x = 0
    while x < w:
        if fg[x]:
            s = x
            while x < w and fg[x]:
                x += 1
            out.append((s, x))                # 半开区间 [s, x)
        else:
            x += 1
    return fgref, out


class Gate:
    """判据收集器 —— 每条都记名字与实测值，便于失败时一眼看出差多少。"""

    def __init__(self):
        self.n = 0
        self.bad = []

    def eq(self, name, got, want, tol=TOL):
        self.n += 1
        if abs(got - want) > tol:
            self.bad.append("%s  实测 %.2f  期望 %.2f  (容差 %.2f)"
                            % (name, got, want, tol))

    def true(self, name, cond, detail=""):
        self.n += 1
        if not cond:
            self.bad.append("%s  %s" % (name, detail))


def main():
    if len(sys.argv) < 2:
        print("用法：python tools/check-layout-pixels.py <png>")
        return 2
    path = sys.argv[1]
    if not os.path.isfile(path):
        print("!! 找不到图：%s" % path)
        print("   （先跑 ./tools/check-layout-pixels.sh —— 它会先抓图）")
        return 2

    img = Image.open(path).convert("RGB")
    print("QSkin · 布局层像素门（M29）")
    print("=" * 68)
    print("图      ：%s  (%d×%d)" % (path, img.width, img.height))

    g = Gate()

    # ── 0a. 背景色：一图一标定（为什么不是逐行取众数，见 pick_bg 的文档串）
    bg = pick_bg(img)
    print("背景色  ：%s（全图众数）" % (bg,))

    # ── 0b. 缩放比 —— **两路独立来源**，必须对得上 ──────────────────
    #   ① 图宽 / 画布逻辑宽（场景约定 700）
    #   ② 锚条物理宽 / 锚条逻辑宽（场景约定 580）
    # 两者不等 ⇒ 场景改过、或者 grabToImage 的缩放行为变了。那种情况下
    # 后面**所有**坐标都会错，必须先停下，别把错算成"布局画错了"。
    global SCALE
    SCALE = img.width / float(CANVAS_W)

    fgref, anchor = spans_at(img, Y_ANCHOR, bg)
    if len(anchor) != 1:
        print("!! 锚条那一行（逻辑 y=%d，物理 y=%d）量到 %d 个前景段，期望 1 个："
              % (Y_ANCHOR, int(round(Y_ANCHOR * SCALE)), len(anchor)))
        for (s, e) in anchor:
            print("     物理 [%4d, %4d)   逻辑 [%6.1f, %6.1f)"
                  % (s, e, s / SCALE, e / SCALE))
        print("   背景 bg=%s   前景参考 fgref=%s" % (bg, fgref))
        print("   （锚条应在逻辑 [30, 610)。多出来的段通常是窗口边框 / 装饰）")
        return 2
    a0, a1 = anchor[0]
    anchor_px = a1 - a0
    scale_b = anchor_px / float(CONTAINER_W)

    print("缩放比  ：%.4f×（图宽 %d / 画布 %d）" % (SCALE, img.width, CANVAS_W))
    g.eq("两路缩放比一致（图尺寸 vs 锚条）", scale_b, SCALE, tol=0.01)

    cx0 = a0 / SCALE                              # 容器左沿（逻辑像素）
    print("容器    ：左沿 %.1f，宽 %.1f" % (cx0, anchor_px / SCALE))
    print("-" * 68)

    def report(label, y, want_left):
        _fgref, sp = spans_at(img, y, bg)
        if len(sp) != 3:
            g.true("%s 三枚色块都画出来了" % label, False,
                   "实测 %d 段（y=%d）" % (len(sp), y))
            print("%-8s段数 %d ≠ 3   ← 画错了，后面的尺寸判据跳过" % (label, len(sp)))
            return
        # 折回逻辑像素
        segs = [(s / SCALE, e / SCALE) for (s, e) in sp]
        widths = [e - s for (s, e) in segs]
        gaps = [segs[1][0] - segs[0][1], segs[2][0] - segs[1][1]]
        left = segs[0][0] - cx0
        group = segs[2][1] - segs[0][0]

        print("%-8s段 %6.1f..%-6.1f %6.1f..%-6.1f %6.1f..%-6.1f"
              % (label, segs[0][0], segs[0][1], segs[1][0], segs[1][1],
                 segs[2][0], segs[2][1]))
        print("%-8s  块宽 %.1f/%.1f/%.1f   间隙 %.1f/%.1f   组宽 %.1f   组左沿 +%.1f"
              % ("", widths[0], widths[1], widths[2], gaps[0], gaps[1], group, left))

        for i, wv in enumerate(widths):
            g.eq("%s 第%d枚块宽" % (label, i + 1), wv, BLOCK_W)
        g.eq("%s 第一道间隙" % label, gaps[0], GAP)
        g.eq("%s 第二道间隙" % label, gaps[1], GAP)
        g.eq("%s 组宽" % label, group, GROUP_W)
        g.eq("%s 组左沿（相对容器）" % label, left, want_left)
        return gaps, left

    report("start", Y_START, 0)
    report("center", Y_CENTER, (CONTAINER_W - GROUP_W) / 2.0)      # 222
    report("end", Y_END, CONTAINER_W - GROUP_W)                    # 444

    # ── 反证：原生 RowLayout 的间隙必须明显大于 gap ──────────────────
    _, raw = spans_at(img, Y_RAW, bg)
    if len(raw) == 3:
        rs = [(s / SCALE, e / SCALE) for (s, e) in raw]
        raw_gap = (rs[1][0] - rs[0][1] + rs[2][0] - rs[1][1]) / 2.0
        print("-" * 68)
        print("原生     间隙 %.1f（间距被撑大）" % raw_gap)
        g.true("原生 RowLayout 的间隙明显大于 gap（反证成立）",
               raw_gap > RAW_GAP_MIN,
               "实测 %.1f，要求 > %d" % (raw_gap, RAW_GAP_MIN))
    else:
        g.true("原生 RowLayout 画出了三枚色块", False, "实测 %d 段" % len(raw))

    # ── 汇总 ──────────────────────────────────────────────────────────
    print("-" * 68)
    if g.n == 0:
        # 「检查了 0 条」一律算失败 —— 空面的绿比红更危险。
        print("NG  一条判据都没跑到 —— 工装坏了，不是代码对了")
        return 1
    if g.bad:
        print("NG  %d / %d 条判据失败：" % (len(g.bad), g.n))
        for b in g.bad:
            print("    ✗ %s" % b)
        return 1
    print("OK  %d 条判据全部成立" % g.n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
