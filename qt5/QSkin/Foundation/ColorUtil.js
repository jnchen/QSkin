/****************************************************************************
 * QSkin · Quick Design System — Foundation
 * 颜色换算（HSV ↔ RGB ↔ HEX）+ 取色几何
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 输入是一组数（色相/饱和度/明度、或色域面上的一个点），输出是一组数。
 * 它不画一笔 —— 画色域面、色相条、色块是 Contracts 层 QSkinColorPicker 的事。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么这是一个 `.js` 而不是一个 QML 单例
 * ════════════════════════════════════════════════════════════════════════
 * 与 FuzzyMatch.js / QRCodeEncoder.js 同源：**门禁要做独立算路**。
 *
 * 颜色换算有一个比像素强得多的核验可能 —— 它是一组**恒等式**：
 *
 *   ① 往返：rgbToHsv(hsvToRgb(h,s,v)) 应当回到 (h,s,v)
 *   ② 六个顶点是**定义**，不是近似：红=#FF0000、青=#00FFFF …
 *   ③ 两条几何互逆：pointFromSv(svFromPoint(p)) 应当回到 p
 *
 * 核验器（`.cache/_verify_m26color.js`）用 **HSL 中转**再写一份完全不同的
 * 公式来比对 ① —— 与这里的 sector 分支**没有共享代码**，也不共享
 * "必须用 sector 分支"这个假设。若换算长在控件里，就只能通过控件属性
 * 去摸「控件认为的颜色」，那什么也证明不了。
 *
 * 所以本文件刻意**不写 `.pragma library`** —— 那条指令是 QML 专有的，
 * node 会当作语法错误。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 三条**刻意的**确定性选择（它们同时也是判据）
 * ════════════════════════════════════════════════════════════════════════
 *
 * 1. **灰阶的色相固定为 0。** `rgbToHsv(128,128,128)` 的 h 在数学上
 *    *无定义*（delta = 0）。返回 0 而不是 NaN：色相条上要有一个位置，
 *    "灰的时候色相条跳到最左"是可预期的，NaN 会让整条色相条消失。
 *    同理 `v === 0`（纯黑）时 s 固定为 0。
 *
 * 2. **`rgbToHex` 输出大写、恒为 6 位。** `#FF0000` 而不是 `#ff0000`、
 *    `#00FF00` 而不是 `#0F0`。输入的三种写法都接受（`#RGB` / `#RRGGBB` /
 *    带不带 `#`），输出只有一种 —— 否则像素核验比对一个由输入写法决定的
 *    字符串，就成了"测输入格式"。
 *
 * 3. **所有通道值都是 0..255 的整数**，在函数内部就 `Math.round` 掉。
 *    不把浮点 RGB 漏给调用方：色域面取色要写进 `#RRGGBB`，早晚要舍入，
 *    早舍入只有一个舍入点。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 取色几何：y 轴是反的，这是唯一容易写错的地方
 * ════════════════════════════════════════════════════════════════════════
 * 色域面（SV 面）的四角：
 *
 *     左上 (0,0)  白  s=0 v=1        右上 (w,0)   纯色  s=1 v=1
 *     左下 (0,h)  黑  s=0 v=0        右下 (w,h)   黑    s=1 v=0
 *
 * 于是 x 正向 = 饱和度增大，**y 正向 = 明度减小**。两个方向各给一个
 * 函数、核验时互为逆运算 —— 把方向记在函数名上，比记在注释里可靠。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 已知边界（写出来，不假装没有）
 * ════════════════════════════════════════════════════════════════════════
 *
 * · **不做 gamma / sRGB 线性化**。这里算的是"按 8bit 通道直读的颜色"，
 *   与设计软件一致；做色彩管理是另一个量级的事，本项目没有消费者。
 * · **不做 alpha**。`hexToRgb` 只认 3 / 6 位十六进制，8 位（带 alpha）
 *   返回 `null`。QSkinColorPicker 至今没有 alpha 条 —— 有消费者再加。
 * · **通道值恒在 .5 上的那些色相，舍入方向取决于浮点路径。** 例如
 *   `h = 70` 与 `h = 190` 数学上是同一个 x 值，但 `70/60` 与 `190/60`
 *   的浮点尾数不同，一个算出 `212.49999…`（舍到 212）、另一个算出
 *   `212.50000…`（舍到 213）。于是**任何「两个色相应当给出相同通道值」**
 *   的判据都要带 ±1 级容差 —— 要求严格相等是要求 8bit 量化不存在。
 *   受影响的判据见 `tools/check-color-util.js` 的 [性质] 段。
 * · **退化输入只承诺「不出 NaN、落在 [0,1]」**。宽 / 高为 0、为负、
 *   为 NaN 时，(s, v) 的具体取值**不作承诺** —— 零宽的色域面本来就
 *   不可见。防的是唯一的真风险：除零把整块色域面变成 NaN。
 * · 色相精度是**浮点**（不是整数），因为色相条宽 200px 时 1° ≈ 0.56px，
 *   取整会让拖动一格跳 2°。于是色相的断言要写容差，而 RGB 的不用。
 * · **色相在低饱和 / 低明度处不可反推。** `d = s × v` 决定了色相的分辨率：
 *   `h` 由 `(g−b)/d` 这类比值算出，而分子与分母**都被量化过** —— 误差是
 *   双重放大的，比"误差 ∝ 1/d"更陡。实测（`tools/check-color-util.js`
 *   出题：逐 d 取遍 h，取最大偏差）：
 *
 *         d       0.01   0.02   0.05   0.10   0.20   0.50   1.00
 *         Δh_max  29.0   14.0    4.23   2.20   1.18   0.44   0.12   （度）
 *
 *   拟合上界 `Δh ≤ 0.3 / d`。所以往返断言**按 d 分档**：`d ≥ 0.05` 时
 *   容差取 `0.3 / d`（d = 0.05 处为 6°，实测 4.23，留 1.4 倍余量）；
 *   `d < 0.05` 时**不比对色相** —— 那里量化已经把色相吃掉了，要求它相等
 *   是**要求一件做不到的事**（M24 的 7% 遮罩记过同一条）。
 ****************************************************************************/

/* ═══════════════════════ 常量 ═══════════════════════ */

var HUE_MAX = 360

/* ═══════════════════════ 基础 ═══════════════════════ */

function clamp01(x) {
    if (x !== x || x === Infinity || x === -Infinity) return 0
    if (x < 0) return 0
    if (x > 1) return 1
    return x
}

/** 把任意实数折进 [0, 360) —— 负数色相（`rgbToHsv` 的中间结果）也要能进 */
function normalizeHue(h) {
    if (h !== h || h === Infinity || h === -Infinity) return 0
    var r = h % HUE_MAX
    if (r < 0) r += HUE_MAX
    return r
}

function _clamp255(x) {
    var v = Math.round(x)
    if (v < 0) return 0
    if (v > 255) return 255
    return v
}

/* ═══════════════════════ HSV → RGB ═══════════════════════ */

/**
 * hsvToRgb(h, s, v) → { r, g, b }   （0..255 整数）
 *
 * 标准 sector 分支：按色相落在哪个 60° 扇区选通道排列。
 * 扇区号用 `Math.floor(h / 60)`，注意 h 已被折进 [0,360)，所以扇区 ∈ 0..5，
 * 不会出现 6（那是把 360 当成合法色相才会有的 bug —— 折过之后 360 → 0）。
 */
function hsvToRgb(h, s, v) {
    var hh = normalizeHue(h)
    var ss = clamp01(s)
    var vv = clamp01(v)

    var c = vv * ss
    var x = c * (1 - Math.abs(((hh / 60) % 2) - 1))
    var m = vv - c

    var sec = Math.floor(hh / 60)
    var r = 0, g = 0, b = 0
    if (sec === 0)      { r = c; g = x; b = 0 }
    else if (sec === 1) { r = x; g = c; b = 0 }
    else if (sec === 2) { r = 0; g = c; b = x }
    else if (sec === 3) { r = 0; g = x; b = c }
    else if (sec === 4) { r = x; g = 0; b = c }
    else                { r = c; g = 0; b = x }

    return { r: _clamp255((r + m) * 255),
             g: _clamp255((g + m) * 255),
             b: _clamp255((b + m) * 255) }
}

/* ═══════════════════════ RGB → HSV ═══════════════════════ */

/**
 * rgbToHsv(r, g, b) → { h, s, v }
 *   h ∈ [0,360) 浮点，s / v ∈ [0,1]
 *   灰阶（max === min）→ h = 0；纯黑 → s = 0（见文件头第 1 条）
 */
function rgbToHsv(r, g, b) {
    var rr = clamp01(r / 255)
    var gg = clamp01(g / 255)
    var bb = clamp01(b / 255)

    var mx = Math.max(rr, gg, bb)
    var mn = Math.min(rr, gg, bb)
    var d = mx - mn

    var h = 0
    if (d > 0) {
        if (mx === rr)      h = 60 * (((gg - bb) / d) % 6)
        else if (mx === gg) h = 60 * (((bb - rr) / d) + 2)
        else                h = 60 * (((rr - gg) / d) + 4)
    }

    return { h: normalizeHue(h),
             s: mx === 0 ? 0 : d / mx,
             v: mx }
}

/* ═══════════════════════ HEX ═══════════════════════ */

function _pair(n) {
    var t = _clamp255(n).toString(16).toUpperCase()
    return t.length < 2 ? "0" + t : t
}

/** rgbToHex(r,g,b) → "#RRGGBB"（大写、恒 6 位） */
function rgbToHex(r, g, b) {
    return "#" + _pair(r) + _pair(g) + _pair(b)
}

/**
 * hexToRgb(str) → { r, g, b } | null
 *
 * 接受 `#RGB` / `#RRGGBB` / 不带 `#` 的同样两种写法、大小写均可。
 * 其它一律 **null**（不是黑）——"输入框里打错了一个字符"与"选到黑色"
 * 必须在调用方那里分得开，否则 hex 输入框会把非法值悄悄变成 #000000。
 */
function hexToRgb(str) {
    if (str === null || str === undefined) return null
    var t = String(str).trim()
    if (t.charAt(0) === "#") t = t.substring(1)
    if (t.length === 3) {
        t = t.charAt(0) + t.charAt(0)
          + t.charAt(1) + t.charAt(1)
          + t.charAt(2) + t.charAt(2)
    }
    if (t.length !== 6) return null
    if (!/^[0-9a-fA-F]{6}$/.test(t)) return null
    return { r: parseInt(t.substring(0, 2), 16),
             g: parseInt(t.substring(2, 4), 16),
             b: parseInt(t.substring(4, 6), 16) }
}

/** 校验 + 归一化：非法返回 ""，合法返回大写 6 位形式 */
function normalizeHex(str) {
    var c = hexToRgb(str)
    return c === null ? "" : rgbToHex(c.r, c.g, c.b)
}

/* ═══════════════════════ 取色几何 ═══════════════════════ */

/** 色域面上的点 → (s, v)。y 正向 = 明度**减小** */
function svFromPoint(x, y, w, h) {
    var ww = (w > 0) ? w : 1
    var hh = (h > 0) ? h : 1
    return { s: clamp01(x / ww), v: clamp01(1 - y / hh) }
}

/** (s, v) → 色域面上的点。与 svFromPoint 互为逆运算 */
function pointFromSv(s, v, w, h) {
    var ww = (w > 0) ? w : 1
    var hh = (h > 0) ? h : 1
    return { x: Math.round(clamp01(s) * ww),
             y: Math.round((1 - clamp01(v)) * hh) }
}

/** 色相条上的一维位置 → 色相 */
function hueFromX(x, w) {
    var ww = (w > 0) ? w : 1
    return normalizeHue(clamp01(x / ww) * HUE_MAX)
}

/** 色相 → 色相条上的一维位置 */
function xFromHue(h, w) {
    var ww = (w > 0) ? w : 1
    return Math.round(normalizeHue(h) / HUE_MAX * ww)
}

/* ═══════════════════════ 预设色块 ═══════════════════════ */

/**
 * swatchRing(n, s, v) → [{ h, hex, r, g, b }]
 *
 * 预设色块是**算出来的**，不是抄来的色值表 —— n 个等距色相、固定
 * s / v。这样核验器能用同一个公式复算，而"我手抄了 TDesign 的十二个
 * 十六进制"是复算不出来的（本项目对文档数字的同一条规矩）。
 *
 * 调用方可以整份替换（`QSkinColorPicker.swatches`），这里给的是默认。
 */
function swatchRing(n, s, v) {
    var count = (n === undefined || n === null) ? 12 : Math.max(1, Math.round(n))
    var ss = (s === undefined || s === null) ? 0.85 : clamp01(s)
    var vv = (v === undefined || v === null) ? 0.95 : clamp01(v)

    var out = []
    for (var i = 0; i < count; ++i) {
        var h = HUE_MAX * i / count
        var c = hsvToRgb(h, ss, vv)
        out.push({ h: h, hex: rgbToHex(c.r, c.g, c.b), r: c.r, g: c.g, b: c.b })
    }
    return out
}

/* ═══════════════════════ 导出（node 侧的门禁要用） ═══════════════════════ */

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        HUE_MAX: HUE_MAX,
        clamp01: clamp01,
        normalizeHue: normalizeHue,
        hsvToRgb: hsvToRgb,
        rgbToHsv: rgbToHsv,
        rgbToHex: rgbToHex,
        hexToRgb: hexToRgb,
        normalizeHex: normalizeHex,
        svFromPoint: svFromPoint,
        pointFromSv: pointFromSv,
        hueFromX: hueFromX,
        xFromHue: xFromHue,
        swatchRing: swatchRing
    }
}
