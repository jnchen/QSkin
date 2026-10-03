#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""QSkin · 输入底板像素门（M31）

用法：
    python tools/check-input-plate-pixels.py .cache/m31_plate.png

一般不用直接调 —— `tools/check-input-plate-pixels.sh` 会先抓图再调这里，
`tools/test.sh` 的第 3.9 节会自动带上它。

────────────────────────────────────────────────────────────────────────
这个文件守的是什么
────────────────────────────────────────────────────────────────────────
`tests/smoke_m30_theme.qml` 的 [2]~[4] 读的是插槽 `Rectangle` 的
`topLeftRadius` / `topRightRadius` / `bottomRightRadius` / `bottomLeftRadius`
四个属性 —— 它证明的是「**我设了这些值**」。

本项目已经付过七次学费的那句话是「**属性值对 ≠ 界面画对**」。下面两件事
在属性侧根本读不出来，只有像素能认：

  ① **方位对不对**。`CornerUtil.corners` 的键名（tl/tr/br/bl）与插槽的
     `topLeftRadius`… 之间那一层翻译，写错一格的症状是**镜像** ——
     四个数字全对、属性全对、界面全错。属性门读的就是那个结果，
     它与被测量**共享同一份假设**；像素门不共享。
  ② **光晕画在哪、有多厚、四角跟不跟主体**。`halo` 用
     `anchors.margins: -2` 画到字段外面，四角由 `_haloCorners` 决定。
     属性侧读得出 `visible: true`，读不出这三件事。

判据全部来自**从图里量出来的东西**，没有一个写死的像素坐标：

    · 背景色   ← 全图众数色（场景衬底是深灰 #3C3C3C，与字段白拉开）
    · 前景参考 ← **该件自己内部** 3×3 的众数非背景色。
                 ⚠ 这一条是被实测打回来改的：探针 A 用「整行众数」时，
                 error 件与常态件共用 y=260 那一行，error 的红边框挤掉了
                 常态的浅灰边框 —— 参考色被**邻件带偏**，常态件的角落
                 读数漂了 1。改成"该件内部"后两边都回到 5/4/4/3。
                 教训与 `check-layout-pixels.py` 的 pick_bg 同源：
                 **参考量要按"被测量的那个对象"取，不要按"它凑巧所在的行"取。**
    · 判据     ← 「更靠近背景还是更靠近前景」——**零阈值自校准**。
                 边框色（浅灰 #D9D9D9）在这套判定里天然落在"前景侧"
                 （它离白 4332、离衬底 73947），所以圆角判据不需要
                 知道边框是什么颜色。

────────────────────────────────────────────────────────────────────────
★ 关于光晕的三条判据：[5] / [6] / [7] 一律**从字段边界往外扫**
────────────────────────────────────────────────────────────────────────
首版这三条是"在字段外固定偏移处采样"（y = 字段顶边 − 2 / − 1 等）——
**它们把光晕的厚度 2px 焊进了判据**。证伪器 P9 一枪（把外扩从 2px 改成
4px）就把三条同时打红，而**那种变异在视觉上完全正确**：光晕真的画在外面、
真的更厚、四角真的跟着主体 —— 报红是**假红**。

这正是本项目制作规矩第 5 条说的那件事：
**量法不能与被测量共享硬编码假设。**

改成三个"往外扫"的原语（见 `Plate.gap_up` / `halo_thickness` / `diag_reach`）：

    [5] 存在性  「从字段顶边往上，第一个亮像素在第几步」—— 判"有值/无值"
    [6] 细环    「往上连续亮几行」—— 判"不超过 HALO_EDGE_MAX"
    [7] 角同步  「从字段左上角沿对角往外，最远的亮像素在第几步」——
                判"**方角主体比圆角主体伸得更远**"（相对判据，零假设）

[7] 为什么用**相对**判据而不是"圆角主体对角方向必须没有光晕"：
后者同样是个陷阱 —— 光晕一变厚，圆角主体的对角方向**本来**就会有光晕
（那是正确行为）。而"方角伸得比圆角远"这个**序关系**与厚度无关，
只与"halo 的角跟不跟主体"有关。P3 那一枪（halo 恒用 standalone 的圆角）
会让两个值都变成 0，序关系不成立 → 红。

────────────────────────────────────────────────────────────────────────
场景约定（与 tests/scene_input_plate.qml 一一对应，改一边要改两边）
────────────────────────────────────────────────────────────────────────
    画布 900×520，衬底 #3C3C3C

    A 组（分组圆角）   first (60,60) / middle (260,60) / last (460,60)，各 200×40
    B 组（半径实测源） solo  (60,160)  200×40   四角全圆
    C 组（光晕对照）   error (60,260)  200×40   四角圆 + 光晕
                       常态 (320,260) 200×40   无光晕
    D 组（光晕角同步） middle (260,360) 200×40  **方角** + 光晕（error）

    圆角判据的标定：ant 的 radius.md = 6，实测圆角侧 d ∈ [3,5]、
    方角侧 d ≡ 0。阈值 ROUND_MIN=2 / SQUARE_MAX=0 落在两档之间，
    各留 1px 以上余量。
    ⚠ 若将来让本场景跑更多主题，这两个阈值必须**重测**再改 ——
      尤其 TDesign 的 r=3（弧只有一半大）。理由写在场景文件头。

────────────────────────────────────────────────────────────────────────
已知未覆盖（一笔正账，不是"忘了"）
────────────────────────────────────────────────────────────────────────
  · **Link 的下划线不在这里**。`Text.underline` 是 Qt 直接绘制的，
    属性侧读插槽 `Text` 的 `font.underline` **就是绘制指令本身** ——
    与像素判据等价，而它由 `smoke_m30_theme` 那份门守。
    （本门刻意不去画一个"下划线条带"的判据：`underline` 紧贴基线下方、
    与文字之间没有空隙，"有/无"在像素上要靠字体度量去猜，那种判据
    脆而不承重。**宁可不说，不写一条随时会假红的判据。**）
  · **只跑一档主题**（ant）。圆角**数值**由属性门在五档上守；
    本门守的是"数值 → 弧度"这一跳，它是插槽的绘制机制，不随主题变。
  · **不做竖排 / RTL** 的角映射 —— 场景与 `CornerUtil` 都没有这两条通路。
  · **不判"光晕的颜色是不是它该有的那一档"**（error 的 `dangerSubtle`
    vs 聚焦的 `focusHalo`）。那需要色相判断，会把"配色的假设"引进来；
    而"哪一档"由 `ADInputBackground` 的 `showHalo()` / `haloColor()` 决定，
    属属性侧可读的量（`smoke_m30_theme` 的取色判据那一族）。

────────────────────────────────────────────────────────────────────────
退出码
────────────────────────────────────────────────────────────────────────
    0         全部成立
    bit0~bit7 对应下面 [1]~[8] 组判据，可组合（本项目惯例：位掩码）
              ⚠ 一组判据可能**多条同时失败**，所以"失败条数"通常大于
                "亮的位数"，两者不是一回事 —— 别拿它们对账。
    255       工装问题：一条判据都没跑到（`_n == 0`）
    2         输入或环境问题（图不存在、缺 Pillow、缩放比两路不一致）

位掩码与报告文本的**两路对账不在这里做**，在证伪器里做
（`.cache/mutate_m31_plate.py` 解析本文件打印的 `[n]` 标记，独立算出
"该红哪些位"，再与退出码比）。放在这边的"对账"只会是**恒等式** ——
两个量都由同一个 `gate()` 写出来，对不上才有鬼；而给它加一条
`popcount(mask) == len(bad)` 这样的判据，则会在"一组判据多条同时失败"
时**误报 HARNESS**（M31 首跑实测：P2 一枪把 [2][3] 各两条判据同时打红，
亮 2 位、报 4 条，于是核验器自己返回了 255）。
**教训：两路对账的前提是"两路真的独立"；同源的两个量之间做对账，
不是对账，是复读。**
"""

import os
import sys
from collections import Counter

try:
    from PIL import Image
except ImportError:
    print("!! 需要 Pillow —— 用托管的 python 跑（tools/check-input-plate-pixels.sh 会去找）")
    sys.exit(2)


# ═══════════════════════════ 场景约定 ═════════════════════════════════════
# ⚠ 这些是**场景定义**，不是"被测量的假设"。被测量的东西（哪个角是圆的、
#   光晕画在哪 / 多厚 / 角上伸多远）全部在下面从图里量。

CANVAS_W = 900

# (x, y, w, h)
P_FIRST    = (60,  60,  200, 40)
P_MIDDLE   = (260, 60,  200, 40)
P_LAST     = (460, 60,  200, 40)
P_SOLO     = (60,  160, 200, 40)
P_ERR      = (60,  260, 200, 40)
P_NORM     = (320, 260, 200, 40)
P_GRP2_MID = (260, 360, 200, 40)

GROUP_LEFT  = 60                       # A 组整体左沿
GROUP_RIGHT = 660                      # A 组整体右沿 —— 用于第二路缩放比
GROUP_W     = GROUP_RIGHT - GROUP_LEFT  # 600

Y_GROUP_ROW = 80                       # A 组内部的一行（穿过三枚，量交界线宽）

# 圆角判据的标定区间 —— 见文件头「场景约定」末段
ROUND_MIN  = 2                         # d >= 2 → 判为"圆"
SQUARE_MAX = 0                         # d == 0 → 判为"方"（1 两边都不满足 → 报红）

# 光晕三判据的扫描上界。
HALO_SCAN_LIMIT = 12                   # 从字段边界往外最多扫这么多步（逻辑 px）
# HALO_EDGE_MAX 是**语义**上界而不是实现常量：实现里光晕是 2px，
# 但"光晕"这个概念要求它是**细环**；厚过 8px 它在视觉上已经是"外框块"。
# 阈值与实现值 2 之间留了 4 倍余量，所以"实现把 2 改成 3 或 4"不会假红。
HALO_EDGE_MAX  = 8
DIAG_LIMIT     = 16                    # 从字段角沿对角往外最多扫这么多步

# 「已知有损」的正账：first 的右边框 + middle 的左边框 = 两道 1px 同色线。
# QSkinInputGroup 的文件头把它记成"刻意不做负边距合并"。这里把那个**数字**
# 钉住：哪天有人真去做了合并，它会变成 1 —— 判据变红，是**提醒改文档**，
# 不是提醒改回去。
JOINT_WANT = 2.0
JOINT_TOL  = 0.51


def dist2(a, b):
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def pick_bg(img):
    """全图众数色 = 衬底色。一图一标定。

    与 check-layout-pixels.py 的 pick_bg 同源：本场景衬底占图面约 93%，
    "背景占多数"这个前提比"每一行的背景都最多"宽得多。
    """
    colors = img.getcolors(maxcolors=1 << 24)
    if not colors:
        return (0, 0, 0)
    return max(colors, key=lambda t: t[0])[1]


# ═══════════════════════════ 判据收集 ═════════════════════════════════════

_mask = 0
_n = 0
_bad = []


def gate(bit, name, cond, detail=""):
    """记一条判据。失败时点亮位掩码的那一位，并把**实测值**一并留住。

    只报"红/绿"而不报实测值的门，第二次失败时就没人能一眼看出差多少
    ——那是本项目记过的"报告行没有信息量"。
    """
    global _mask, _n
    _n += 1
    if not cond:
        _mask |= (1 << bit)
        _bad.append(name + ("   " + detail if detail else ""))


class Plate:
    """把一张图 + 一个件的几何包起来，提供"从图里量"的原语。"""

    def __init__(self, img, bg, name, rect, scale):
        self.img = img
        self.bg = bg
        self.name = name
        self.x, self.y, self.w, self.h = rect
        self.scale = scale

    # ---- 取像素（入参一律逻辑坐标）----
    def px(self, xl, yl):
        x = int(round(xl * self.scale))
        y = int(round(yl * self.scale))
        if not (0 <= x < self.img.width and 0 <= y < self.img.height):
            return None
        return self.img.getpixel((x, y))

    # ---- 参考色：该件**自己内部**的众数非背景色 ----
    def fgref(self, rad=3):
        cx, cy = self.x + self.w / 2.0, self.y + self.h / 2.0
        cs = []
        for dx in range(-rad, rad + 1):
            for dy in range(-rad, rad + 1):
                c = self.px(cx + dx, cy + dy)
                if c is not None:
                    cs.append(c)
        for c, _n2 in Counter(cs).most_common():
            if dist2(c, self.bg) > 0:
                return c
        return self.bg

    # ---- 判定原语 ----
    def is_fg(self, c, fr):
        """更靠近前景（字段 / 边框 / 光晕）还是背景。零阈值。"""
        if c is None:
            return False
        return dist2(c, self.bg) > dist2(c, fr)

    def corner_d(self, corner, fr, limit=24):
        """从该角的**外侧沿**往内走，返回第一个"前景侧"像素的步数（逻辑 px）。

        返回 0   = 那个角是**方的**（第 0 个像素就已经是边框/字段）；
        返回 >=2 = 那个角是**圆的**（弧把角落让给了衬底）；
        返回 1   = 可疑（两边判据都不满足 → 报红）。
        """
        x0, y0 = self.x, self.y
        x1, y1 = self.x + self.w - 1, self.y + self.h - 1
        sx, sy, dx, dy = {
            "tl": (x0, y0, +1, 0),
            "tr": (x1, y0, -1, 0),
            "bl": (x0, y1, +1, 0),
            "br": (x1, y1, -1, 0),
        }[corner]
        for k in range(limit):
            if self.is_fg(self.px(sx + dx * k, sy + dy * k), fr):
                return k
        return limit

    def corners(self, fr):
        return {c: self.corner_d(c, fr) for c in CL}

    # ---- 光晕三原语：一律"从字段边界往外扫"，不假设厚度 ----

    def gap_up(self, fr, limit=HALO_SCAN_LIMIT):
        """从字段**顶边中部**往上扫，返回第一个亮像素在第几步（逻辑 px）。
        扫完都没有 → None（= 字段外面没有光晕）。

        正常实现返回 1（光晕紧贴字段外面）。**不判"必须等于 1"** ——
        那会把厚度焊进来；只判"有值 / 无值"。
        """
        cx = self.x + self.w // 2
        for k in range(1, limit + 1):
            if self.is_fg(self.px(cx, self.y - k), fr):
                return k
        return None

    def halo_thickness(self, fr, limit=HALO_SCAN_LIMIT):
        """从字段顶边中部往上，**连续**亮的行数（= 光晕在那一侧的厚度）。"""
        cx = self.x + self.w // 2
        n = 0
        for k in range(1, limit + 1):
            if not self.is_fg(self.px(cx, self.y - k), fr):
                break
            n += 1
        return n

    def diag_reach(self, fr, limit=DIAG_LIMIT):
        """从字段**左上角**沿对角线往外扫，返回最远的亮像素在第几步。

        0 = 那条线上没有光晕（角上让开了）。
        这是一个**相对量**：方角主体与圆角主体的值做序关系比较才有意义
        （见文件头「[7] 为什么用相对判据」）。
        """
        far = 0
        for k in range(1, limit + 1):
            if self.is_fg(self.px(self.x - k, self.y - k), fr):
                far = k
        return far


CL = ("tl", "tr", "bl", "br")


def main():
    if len(sys.argv) < 2:
        print("用法：python tools/check-input-plate-pixels.py <png>")
        return 2
    path = sys.argv[1]
    if not os.path.isfile(path):
        print("!! 找不到图：%s" % path)
        print("   （先跑 ./tools/check-input-plate-pixels.sh —— 它会先抓图）")
        return 2

    try:
        img = Image.open(path).convert("RGB")
    except Exception as exc:                      # noqa: BLE001
        print("!! 打不开图：%s（%s）" % (path, exc))
        return 2

    print("QSkin · 输入底板像素门（M31）")
    print("=" * 70)
    print("图      ：%s  (%d×%d)" % (path, img.width, img.height))

    bg = pick_bg(img)
    print("背景色  ：%s（全图众数）" % (bg,))

    scale = img.width / float(CANVAS_W)

    # ── 0. 缩放比：**两路独立来源**，必须对得上 ──────────────────────
    #   ① 图宽 / 画布逻辑宽（场景约定 900）
    #   ② A 组整体的物理跨度 / 逻辑跨度（场景约定 600）
    # 两者不等 ⇒ grabToImage 的缩放行为变了、或场景被改过。
    # 那种情况下**所有**坐标都会错，必须先停下 —— 别把错算成"底板画错了"。
    row_y = int(round(Y_GROUP_ROW * scale))
    spans, s0 = [], None
    for x in range(img.width):
        c = img.getpixel((x, row_y))
        fg = dist2(c, bg) > 0
        if fg and s0 is None:
            s0 = x
        elif not fg and s0 is not None:
            spans.append((s0, x))
            s0 = None
    if s0 is not None:
        spans.append((s0, img.width))

    print("缩放比  ：%.4f×（图宽 %d / 画布 %d）" % (scale, img.width, CANVAS_W))
    if len(spans) != 1:
        print("!! A 组那一行（逻辑 y=%d）量到 %d 个非背景段，期望 1 个："
              % (Y_GROUP_ROW, len(spans)))
        for (a, b) in spans:
            print("     物理 [%4d, %4d)   逻辑 [%7.1f, %7.1f)" % (a, b, a / scale, b / scale))
        print("   （三枚紧邻、中间只有边框色，应当连成一段；多段说明场景被改过）")
        return 2
    a0, a1 = spans[0]
    scale_b = (a1 - a0) / float(GROUP_W)
    print("         第二路：A 组跨度 %.1f 物理 / %d 逻辑 = %.4f×"
          % (a1 - a0, GROUP_W, scale_b))

    if abs(scale_b - scale) > 0.01:
        print("!! 缩放比两路不一致：%.4f（图尺寸）vs %.4f（A 组跨度）" % (scale, scale_b))
        print("   → 工装问题，不是底板画错。先查场景与 grabToImage。")
        return 2

    # ── 夹具 ──────────────────────────────────────────────────────────
    def plate(name, rect):
        return Plate(img, bg, name, rect, scale)

    first  = plate("first", P_FIRST)
    middle = plate("middle", P_MIDDLE)
    last   = plate("last", P_LAST)
    solo   = plate("solo", P_SOLO)
    err    = plate("error", P_ERR)
    norm   = plate("normal", P_NORM)
    g2mid  = plate("grp2-middle", P_GRP2_MID)

    def fmt(cs):
        return " / ".join("%s=%d" % (k, cs[k]) for k in CL)

    # ── [1] solo：四角全圆（同时是"半径真的被画出来"的证词）bit0 ─────
    fr_solo = solo.fgref()
    cs_solo = solo.corners(fr_solo)
    print("-" * 70)
    print("半径实测：standalone %s   （件内参考色 %s）" % (fmt(cs_solo), fr_solo))
    gate(0, "[1] solo 四角全圆（圆角真的被画出来了）",
         all(cs_solo[k] >= ROUND_MIN for k in CL),
         fmt(cs_solo) + "  要求每角 >= %d" % ROUND_MIN)

    # ── [2] first：左两角圆、右两角方 ─────────────────────── bit1 ──
    fr_first = first.fgref()
    cs_first = first.corners(fr_first)
    print("A 组 first  %s" % fmt(cs_first))
    gate(1, "[2] first 左边两角是圆的",
         cs_first["tl"] >= ROUND_MIN and cs_first["bl"] >= ROUND_MIN,
         "tl=%d bl=%d  要求 >= %d" % (cs_first["tl"], cs_first["bl"], ROUND_MIN))
    gate(1, "[2] first 右边两角是方的（不是镜像）",
         cs_first["tr"] <= SQUARE_MAX and cs_first["br"] <= SQUARE_MAX,
         "tr=%d br=%d  要求 == %d" % (cs_first["tr"], cs_first["br"], SQUARE_MAX))

    # ── [3] last：与 first 镜像 ───────────────────────────── bit2 ──
    fr_last = last.fgref()
    cs_last = last.corners(fr_last)
    print("A 组 last   %s" % fmt(cs_last))
    gate(2, "[3] last 右边两角是圆的",
         cs_last["tr"] >= ROUND_MIN and cs_last["br"] >= ROUND_MIN,
         "tr=%d br=%d  要求 >= %d" % (cs_last["tr"], cs_last["br"], ROUND_MIN))
    gate(2, "[3] last 左边两角是方的（与 first 镜像）",
         cs_last["tl"] <= SQUARE_MAX and cs_last["bl"] <= SQUARE_MAX,
         "tl=%d bl=%d  要求 == %d" % (cs_last["tl"], cs_last["bl"], SQUARE_MAX))

    # ── [4] middle：四角全方 ──────────────────────────────── bit3 ──
    fr_mid = middle.fgref()
    cs_mid = middle.corners(fr_mid)
    print("A 组 middle %s" % fmt(cs_mid))
    gate(3, "[4] middle 四角全方",
         all(cs_mid[k] <= SQUARE_MAX for k in CL),
         fmt(cs_mid) + "  要求每角 == %d" % SQUARE_MAX)

    # ── [5] 光晕存在性（从字段顶边往外扫）──────────────────── bit4 ──
    fr_halo = err.fgref()
    gu_err  = err.gap_up(fr_halo)
    gu_norm = norm.gap_up(fr_halo)
    print("-" * 70)
    print("光晕    ：error 顶边外第一个亮像素在 +%s px；常态 +%s（应为 None）"
          % (gu_err, gu_norm))
    gate(4, "[5] error 件紧贴字段外面就有光晕（画到了外面）",
         gu_err is not None, "实测 +%s（扫了 %d px 都没亮）" % (gu_err, HALO_SCAN_LIMIT))
    gate(4, "[5] 常态件外面没有光晕",
         gu_norm is None, "实测 +%s" % gu_norm)

    # ── [6] 光晕是"细环"，不是一块外扩的板 ─────────────────── bit5 ──
    th_err = err.halo_thickness(fr_halo)
    print("光晕厚度：%.0f px（细环的语义上界 %d，实现值是 2）" % (th_err, HALO_EDGE_MAX))
    gate(5, "[6] 光晕是细环（厚度 <= %d）" % HALO_EDGE_MAX,
         th_err <= HALO_EDGE_MAX, "实测 %.0f px" % th_err)

    # ── [7] 光晕的四角跟着主体走（对角伸展的**序关系**）────── bit6 ──
    # 一正一反在同一条判据里：方角主体（D 组 middle）的对角伸展必须**大于**
    # 圆角主体（C 组 error）。单判"圆角主体对角方向没有光晕"会在光晕变厚时
    # 假红（那时角上本来就有光晕），所以用与厚度无关的序关系。
    d_sq = g2mid.diag_reach(fr_halo)
    d_rd = err.diag_reach(fr_halo)
    print("光晕角  ：方角主体对角方向最远亮像素 +%d；圆角主体 +%d"
          % (d_sq, d_rd))
    gate(6, "[7] 方角主体的光晕铺到角上、圆角主体在角上让开（序关系）",
         d_sq > d_rd, "方角 +%d  vs  圆角 +%d  要求前者更大" % (d_sq, d_rd))

    # ── [8] 「已知有损」的正账：交界处两道同色线 == 2px ───── bit7 ──
    # ⚠ 这一条用**精确相等**（与件内部色比对），不用自校准判据 ——
    #   浅灰边框在这套两级判定里站在"前景侧"，与字段白分不开。
    #   实测证明这个取舍是安全的：交界两侧的字段是**精确的** (255,255,255)。
    #   代价说清楚：它比别的判据脆（抗锯齿一变就会红）—— 而这正是它想要的，
    #   它守的是一个"数字"，数字变了就该有人去看一眼文档。
    white = fr_mid
    xs = list(range(P_MIDDLE[0] - 5, P_MIDDLE[0] + 5))
    joint = [x for x in xs if middle.px(x, Y_GROUP_ROW) != white]
    print("-" * 70)
    print("交界线  ：first|middle 交界 x∈[%d,%d)，非字段色的逻辑像素 %d 个"
          % (xs[0], xs[-1] + 1, len(joint)))
    gate(7, "[8] 交界处是两道同色线（QSkinInputGroup 的「已知有损」正账）",
         abs(len(joint) - JOINT_WANT) <= JOINT_TOL,
         "实测 %.1f，期望 %.1f（±%.2f）" % (float(len(joint)), JOINT_WANT, JOINT_TOL))

    # ── 汇总 ────────────────────────────────────────────────────────
    print("-" * 70)
    if _n == 0:
        # 「检查了 0 条」一律算失败 —— 空面的绿比红更危险。
        print("NG  一条判据都没跑到 —— 工装坏了，不是代码对了")
        return 255
    if _bad:
        print("NG  %d / %d 条判据失败（位掩码 0x%02X）：" % (len(_bad), _n, _mask))
        for b in _bad:
            print("    ✗ %s" % b)
        return _mask
    print("OK  %d 条判据全部成立（位掩码 0x00）" % _n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
