/****************************************************************************
 * QSkin · Quick Design System — 门禁 / ColorUtil 的独立算路核验
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 被测：`src/foundation/ColorUtil.js`（QML 侧由 ColorUtil.qml 薄转发，
 * 同一份源码）。本文件**不 import 任何 Qt**，只用 node。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么必须住在 `tools/`
 * ════════════════════════════════════════════════════════════════════════
 * 它原来是 `.cache/_verify_m26color.js`。M25 记下过一句话，这里照办：
 *
 *     **一个住在可丢弃目录里的闸不算闸。**
 *
 * `./tools/clean-cache.sh --all` 一次就把 `.cache/*.js` 清掉，而且**没有
 * 任何门禁会报"我的裁判不见了"** —— 于是下一次跑 test.sh 时这一层静默
 * 消失，退出码照旧是 0。住在 `tools/` 里、由 `test.sh [3.7]` 调用，
 * 才有人替它说话。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 七段判据，各在防什么
 * ════════════════════════════════════════════════════════════════════════
 *
 * [顶点]     六个纯色 + 黑白。这些是 HSV 的**定义**（s=v=1 必落纯色），
 *            不是拟合值 —— 一张手写的期望表，防"扇区表整体错位"。
 *
 * [性质]     **不需要参照实现**的四条性质，这一段的强度最高：
 *              · 固定 h,s，v 递增 → 三个通道**都不减**
 *              · s = 0 → 三通道相等（灰阶）；s = v = 1 → max=255, min=0
 *              · **h + 120° 恰好是通道循环置换**（r←b, g←r, b←g）
 *              · **关于红轴对称**：h 与 360−h 的 r 相同、g / b 互换
 *            第三条能抓住扇区表里任何一处错位，而且它不依赖"参考答案"。
 *
 * [HSL 中转] 数值交叉：用 `hsv → hsl → rgb` 的**另一条公式链**（系数不同：
 *            `c = (1−|2l−1|)·s_hsl` vs `c = v·s`）算一遍比对，容差 1 级。
 *            它与被测的 sector 分支没有共享代码。**这是弱独立**（两条链
 *            都有扇区分支），所以它只是补充 —— 主力是 [性质]。
 *
 * [往返]     `rgbToHsv(hsvToRgb(h,s,v))` 回到 (h,s,v)，**按 d = s·v 分档**
 *            给容差。这张分档表的来历写在 ColorUtil.js 的文件头里（实测的），
 *            不在这里重抄 —— 两处都写会漂。
 *            另**单独钉两个退化点**（纯黑 → s = 0；灰阶 → h = 0）：它们落在
 *            采样网格之外（si / vi 从 1 起步），只有单独断言才守得住 ——
 *            M26 的 GB4 变异正是从这道缝里逃掉过一次。
 *
 * [hex]      大写 / 恒 6 位 / 三种输入写法 / 非法值必须给 null 而不是黑。
 *
 * [几何]     色域面四角（y 轴是反的）与两组互逆运算。四角是**位置断言**：
 *            (0,0)=白、(w,0)=纯色、(·,h)=黑。
 *
 * [色块]     `swatchRing(n)` 的每一项必须能被 `hsvToRgb` **复算**出来 ——
 *            "我手抄了十二个十六进制"是复算不出来的（本项目对文档数字的
 *            同一条规矩）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 失败时要说清"是哪一段、差多少"
 * ════════════════════════════════════════════════════════════════════════
 * 报出差异（`实测 12 ≠ 期望 8`）比只报"不一致"有用得多 ——
 * 前者能区分「算错了」与「容差写小了」，后者的处置方向完全相反。
 ****************************************************************************/

"use strict"

var path = require("path")

var SRC = path.join(__dirname, "..", "src", "foundation", "ColorUtil.js")
var CO = require(SRC)

/* ═══════════════════════ 记账 ═══════════════════════ */

var pass = 0
var fail = 0
var secPass = {}
var secFail = {}

var SECTIONS = ["顶点", "性质", "HSL 中转", "往返", "hex", "几何", "色块"]

function report(sec, tag, detail) {
    if (SECTIONS.indexOf(sec) < 0) {
        console.log("  !! 段名 `" + sec + "` 不在 SECTIONS 里 —— 本文件的判据组织坏了")
    }
    secFail[sec] = (secFail[sec] || 0) + 1
    fail++
    console.log("  ✗ [" + sec + "] " + tag)
    console.log("      " + detail)
}

function ok(sec) {
    secPass[sec] = (secPass[sec] || 0) + 1
    pass++
}

/* ═══════════════════════ 工具 ═══════════════════════ */

function near(a, b, eps) {
    return Math.abs(a - b) <= eps
}

/** 色相差：折进 [0,180] 再比 —— 359° 与 1° 只差 2° */
function hueDiff(a, b) {
    var d = Math.abs(CO.normalizeHue(a) - CO.normalizeHue(b))
    return d > 180 ? 360 - d : d
}

function hex2(n) {
    var t = n.toString(16).toUpperCase()
    return t.length < 2 ? "0" + t : t
}

/* ── 独立算路 A：走 HSL 中转的另一条公式链（系数不同） ── */
function hslToRgb(h, s, l) {
    var c = (1 - Math.abs(2 * l - 1)) * s
    var x = c * (1 - Math.abs(((CO.normalizeHue(h) / 60) % 2) - 1))
    var m = l - c / 2
    var sec = Math.floor(CO.normalizeHue(h) / 60)
    var r = 0, g = 0, b = 0
    if (sec === 0)      { r = c; g = x; b = 0 }
    else if (sec === 1) { r = x; g = c; b = 0 }
    else if (sec === 2) { r = 0; g = c; b = x }
    else if (sec === 3) { r = 0; g = x; b = c }
    else if (sec === 4) { r = x; g = 0; b = c }
    else                { r = c; g = 0; b = x }
    var cl = function (z) {
        var v = Math.round((z + m) * 255)
        return v < 0 ? 0 : (v > 255 ? 255 : v)
    }
    return { r: cl(r), g: cl(g), b: cl(b) }
}

function hsvToRgbViaHsl(h, s, v) {
    var l = v * (1 - s / 2)
    var sl = (l <= 0 || l >= 1) ? 0 : (v - l) / Math.min(l, 1 - l)
    return hslToRgb(h, sl, l)
}

/* ═══════════════════════ [顶点] ═══════════════════════ */

console.log("==> 被测：" + SRC)
console.log("")

/* 期望值是**定义**：s = v = 1 时必然落在纯色上 */
var VERTICES = [
    { h: 0,   s: 1, v: 1, hex: "#FF0000", name: "红" },
    { h: 60,  s: 1, v: 1, hex: "#FFFF00", name: "黄" },
    { h: 120, s: 1, v: 1, hex: "#00FF00", name: "绿" },
    { h: 180, s: 1, v: 1, hex: "#00FFFF", name: "青" },
    { h: 240, s: 1, v: 1, hex: "#0000FF", name: "蓝" },
    { h: 300, s: 1, v: 1, hex: "#FF00FF", name: "品红" },
    { h: 0,   s: 0, v: 1, hex: "#FFFFFF", name: "白" },
    { h: 0,   s: 0, v: 0, hex: "#000000", name: "黑" }
]
VERTICES.forEach(function (t) {
    var c = CO.hsvToRgb(t.h, t.s, t.v)
    var got = CO.rgbToHex(c.r, c.g, c.b)
    if (got === t.hex) ok("顶点")
    else report("顶点", "[" + t.name + " h=" + t.h + " s=" + t.s + " v=" + t.v + "]",
                "期望 " + t.hex + "，实测 " + got
                + "（rgb " + c.r + "," + c.g + "," + c.b + "）")
})

/* ═══════════════════════ [性质] ═══════════════════════ */

/* ① 固定 h, s：v 递增 → 三通道都不减 */
;(function () {
    var bad = 0, detail = ""
    for (var hi = 0; hi < 360; hi += 17) {
        for (var si = 1; si <= 4; ++si) {
            var s = si / 4
            var prev = null
            for (var vi = 0; vi <= 20; ++vi) {
                var v = vi / 20
                var c = CO.hsvToRgb(hi, s, v)
                if (prev) {
                    if (c.r < prev.r || c.g < prev.g || c.b < prev.b) {
                        bad++
                        if (bad === 1) detail = "h=" + hi + " s=" + s + " v=" + (vi / 20)
                                        + "：(" + prev.r + "," + prev.g + "," + prev.b + ")"
                                        + " → (" + c.r + "," + c.g + "," + c.b + ")"
                    }
                }
                prev = c
            }
        }
    }
    if (bad === 0) ok("性质")
    else report("性质", "[v 单调性]", bad + " 处通道随 v 上升反而减小；首处 " + detail)
})()

/* ② s = 0 → 灰阶；s = v = 1 → max=255 min=0 */
;(function () {
    var bad = 0, detail = ""
    for (var hi = 0; hi < 360; hi += 23) {
        for (var vi = 0; vi <= 10; ++vi) {
            var c = CO.hsvToRgb(hi, 0, vi / 10)
            if (c.r !== c.g || c.g !== c.b) {
                bad++
                if (bad === 1) detail = "h=" + hi + " v=" + (vi / 10)
                                + " 得到 " + c.r + "," + c.g + "," + c.b
            }
        }
    }
    if (bad === 0) ok("性质")
    else report("性质", "[s=0 必是灰阶]", bad + " 处三通道不等；首处 " + detail)

    var bad2 = 0, detail2 = ""
    for (var h2 = 0; h2 < 360; h2 += 7) {
        var c2 = CO.hsvToRgb(h2, 1, 1)
        var mx = Math.max(c2.r, c2.g, c2.b), mn = Math.min(c2.r, c2.g, c2.b)
        if (mx !== 255 || mn !== 0) {
            bad2++
            if (bad2 === 1) detail2 = "h=" + h2 + "：max=" + mx + " min=" + mn
        }
    }
    if (bad2 === 0) ok("性质")
    else report("性质", "[s=v=1 必是纯色]", bad2 + " 处 max/min 不是 255/0；首处 " + detail2)
})()

/* ③ h + 120° 是通道循环置换：r' = b, g' = r, b' = g
 *
 * 这条最值钱 —— 它把六个扇区的排列**互相钉住**，任何一处错位都会露出来，
 * 而且不需要"参考答案"。 */
;(function () {
    var bad = 0, detail = ""
    for (var hi = 0; hi < 360; hi += 5) {
        for (var si = 1; si <= 3; ++si) {
            for (var vi = 1; vi <= 3; ++vi) {
                var s = si / 3, v = vi / 3
                var a = CO.hsvToRgb(hi, s, v)
                var b = CO.hsvToRgb(hi + 120, s, v)
                if (Math.abs(b.r - a.b) > 1 || Math.abs(b.g - a.r) > 1
                    || Math.abs(b.b - a.g) > 1) {
                    bad++
                    if (bad === 1) detail = "h=" + hi + " s=" + s + " v=" + v
                                    + "：基底 (" + a.r + "," + a.g + "," + a.b + ")"
                                    + " 旋转后 (" + b.r + "," + b.g + "," + b.b + ")"
                                    + "，期望 (" + a.b + "," + a.r + "," + a.g + ")"
                }
            }
        }
    }
    if (bad === 0) ok("性质")
    else report("性质", "[色相 +120° = 通道循环]", bad + " 处不满足；首处 " + detail)
})()

/* ④ 关于红轴对称：h 与 360−h 的 r 相同、g / b 互换 */
;(function () {
    var bad = 0, detail = ""
    for (var hi = 1; hi < 360; ++hi) {
        for (var si = 1; si <= 3; ++si) {
            var s = si / 3, v = 0.8
            var a = CO.hsvToRgb(hi, s, v)
            var b = CO.hsvToRgb(360 - hi, s, v)
            if (Math.abs(a.r - b.r) > 1 || Math.abs(a.g - b.b) > 1
                || Math.abs(a.b - b.g) > 1) {
                bad++
                if (bad === 1) detail = "h=" + hi + "：" + a.r + "," + a.g + "," + a.b
                                + " vs h=" + (360 - hi) + "：" + b.r + "," + b.g + "," + b.b
            }
        }
    }
    if (bad === 0) ok("性质")
    else report("性质", "[红轴对称]", bad + " 处不满足；首处 " + detail)
})()

/* ═══════════════════════ [HSL 中转] ═══════════════════════ */

;(function () {
    var bad = 0, detail = ""
    for (var hi = 0; hi < 360; hi += 3) {
        for (var si = 1; si <= 10; ++si) {
            for (var vi = 1; vi <= 10; ++vi) {
                var s = si / 10, v = vi / 10
                var a = CO.hsvToRgb(hi, s, v)
                var b = hsvToRgbViaHsl(hi, s, v)
                if (Math.abs(a.r - b.r) > 1 || Math.abs(a.g - b.g) > 1
                    || Math.abs(a.b - b.b) > 1) {
                    bad++
                    if (bad === 1) detail = "h=" + hi + " s=" + s + " v=" + v
                                    + "：sector 路 " + a.r + "," + a.g + "," + a.b
                                    + " ／ HSL 路 " + b.r + "," + b.g + "," + b.b
                }
            }
        }
    }
    if (bad === 0) ok("HSL 中转")
    else report("HSL 中转", "[两条公式链]", bad + " 例相差 > 1 级；首例 " + detail)
})()

/* ═══════════════════════ [往返] ═══════════════════════ */

/* 容差按 d = s·v 分档。d < 0.05 时不比对色相（见 ColorUtil.js 文件头那张表）。
 * s / v 的容差由量化推导：v 的误差 ≤ 0.5/255；s = d/v 的误差 ≈ Δd/v + s·Δv/v，
 * 取 Δd ≤ 1/255 得上界 `1/255/v + 0.01`。 */
;(function () {
    var badH = 0, badS = 0, badV = 0
    var dH = "", dS = "", dV = ""
    var skipped = 0

    for (var si = 1; si <= 20; ++si) {
        for (var vi = 1; vi <= 20; ++vi) {
            var s = si / 20, v = vi / 20, d = s * v
            for (var hi = 0; hi < 360; hi += 7) {
                var c = CO.hsvToRgb(hi, s, v)
                var b = CO.rgbToHsv(c.r, c.g, c.b)

                if (d < 0.05) {
                    skipped++
                } else {
                    var tol = 0.3 / d
                    if (hueDiff(b.h, hi) > tol) {
                        badH++
                        if (badH === 1) dH = "h=" + hi + " s=" + s + " v=" + v
                                         + "：实测 " + Math.round(b.h * 100) / 100
                                         + "，偏差 " + Math.round(hueDiff(b.h, hi) * 100) / 100
                                         + "° > 容差 " + Math.round(tol * 100) / 100 + "°"
                    }
                }

                var tolS = 1 / 255 / v + 0.01
                if (Math.abs(b.s - s) > tolS) {
                    badS++
                    if (badS === 1) dS = "h=" + hi + " s=" + s + " v=" + v
                                     + "：实测 " + b.s + "，容差 " + tolS
                }
                if (Math.abs(b.v - v) > 0.005) {
                    badV++
                    if (badV === 1) dV = "h=" + hi + " s=" + s + " v=" + v
                                     + "：实测 " + b.v
                }
            }
        }
    }

    if (badH === 0) ok("往返")
    else report("往返", "[色相（d ≥ 0.05）]", badH + " 例超容差；首例 " + dH)

    if (badS === 0) ok("往返")
    else report("往返", "[饱和度]", badS + " 例超容差；首例 " + dS)

    if (badV === 0) ok("往返")
    else report("往返", "[明度]", badV + " 例超容差；首例 " + dV)

    console.log("  · 往返采样：d < 0.05 而**跳过色相**的有 " + skipped + " 例"
                + "（量化已吃掉色相，见 ColorUtil.js 文件头）")

    /* 退化点：纯黑与灰阶。
     *
     * ⚠ 上面那两重循环**碰不到这两个点** —— `si` / `vi` 都从 1 起步，
     * 所以 s 与 v 永远不会是 0。于是「纯黑 → s = 0（不是 NaN）」这条写在
     * `ColorUtil.js` 文件头里的契约**一直没有任何判据在守**：M26 的门禁侧
     * 变异测试把它量出来了 —— 把 `s: mx === 0 ? 0 : d / mx` 里的那一支去掉
     * （变成 `s: d / mx`），七段**一段都不红**（`.cache/mutate_m26_gate.py`
     * 的 GB4 首次就是这么逃掉的）。这是一条**只靠采样永远测不到**的契约：
     * `s = d / mx` 在 mx = 0 时分母为零，NaN 会被下游一路带下去。
     *
     * 同一支 `if (d > 0)` 的另一半（灰阶 → h = 0）也在这里一起钉：它同样
     * 落在采样网格之外。 */
    var blk = CO.rgbToHsv(0, 0, 0)
    var gry = CO.rgbToHsv(128, 128, 128)
    if (blk.h === 0 && blk.s === 0 && blk.v === 0
        && gry.h === 0 && gry.s === 0
        && Math.abs(gry.v - 128 / 255) < 0.005) {
        ok("往返")
    } else {
        report("往返", "[退化点：纯黑与灰阶]",
               "rgbToHsv(0,0,0) = h " + blk.h + " s " + blk.s + " v " + blk.v
               + "（期望 0 / 0 / 0；s 是 NaN 说明分母零没兜住）；"
               + " rgbToHsv(128,128,128) = h " + gry.h + " s " + gry.s
               + " v " + gry.v + "（期望 h 0 s 0）")
    }
})()

/* ═══════════════════════ [hex] ═══════════════════════ */

;(function () {
    /* 大写、恒 6 位 */
    var cases = [[255, 0, 0, "#FF0000"], [0, 255, 0, "#00FF00"],
                 [0, 0, 255, "#0000FF"], [10, 11, 12, "#0A0B0C"],
                 [0, 0, 0, "#000000"], [255, 255, 255, "#FFFFFF"]]
    var bad = 0, detail = ""
    cases.forEach(function (t) {
        var got = CO.rgbToHex(t[0], t[1], t[2])
        if (got !== t[3]) {
            bad++
            if (!detail) detail = "rgbToHex(" + t[0] + "," + t[1] + "," + t[2] + ") = " + got
                            + "，期望 " + t[3]
        }
    })
    if (bad === 0) ok("hex")
    else report("hex", "[输出格式]", detail)

    /* 四种输入写法 */
    var ins = [["#FF0000", 255], ["#ff0000", 255], ["FF0000", 255],
               ["#F00", 255], ["f00", 255], ["  #f00  ", 255]]
    var bad2 = 0, detail2 = ""
    ins.forEach(function (t) {
        var c = CO.hexToRgb(t[0])
        if (c === null || c.r !== t[1] || c.g !== 0 || c.b !== 0) {
            bad2++
            if (!detail2) detail2 = "hexToRgb(" + JSON.stringify(t[0]) + ") = "
                            + JSON.stringify(c) + "，期望 r=" + t[1]
        }
    })
    if (bad2 === 0) ok("hex")
    else report("hex", "[输入写法]", detail2)

    /* 非法值必须给 null —— 不能悄悄变成黑 */
    var bads = ["#GG0000", "#12345", "#1234567", "", "  ", null, undefined,
                "red", "#-10000"]
    var bad3 = 0, detail3 = ""
    bads.forEach(function (x) {
        var c = CO.hexToRgb(x)
        if (c !== null) {
            bad3++
            if (!detail3) detail3 = "hexToRgb(" + JSON.stringify(x) + ") = "
                            + JSON.stringify(c) + "，必须为 null"
        }
    })
    if (bad3 === 0) ok("hex")
    else report("hex", "[非法值 → null]", bad3 + " 处没给 null；首处 " + detail3)

    /* 往返恒等 */
    var bad4 = 0, detail4 = ""
    for (var i = 0; i < 256; i += 3) {
        for (var j = 0; j < 256; j += 51) {
            var hx = CO.rgbToHex(i, j, (i + j) % 256)
            var back = CO.hexToRgb(hx)
            if (back === null || back.r !== i || back.g !== j || back.b !== (i + j) % 256) {
                bad4++
                if (!detail4) detail4 = hx + " 回读成 " + JSON.stringify(back)
            }
        }
    }
    if (bad4 === 0) ok("hex")
    else report("hex", "[往返恒等]", bad4 + " 例不恒等；首例 " + detail4)

    /* normalizeHex */
    var nrm = [["abc", "#AABBCC"], ["#AbC", "#AABBCC"], ["zzz", ""], ["", ""]]
    var bad5 = 0, detail5 = ""
    nrm.forEach(function (t) {
        var got = CO.normalizeHex(t[0])
        if (got !== t[1]) {
            bad5++
            if (!detail5) detail5 = "normalizeHex(" + JSON.stringify(t[0]) + ") = "
                            + JSON.stringify(got) + "，期望 " + JSON.stringify(t[1])
        }
    })
    if (bad5 === 0) ok("hex")
    else report("hex", "[normalizeHex]", detail5)
})()

/* ═══════════════════════ [几何] ═══════════════════════ */

;(function () {
    var W = 200, H = 100

    /* 四角 —— y 轴是反的，这是唯一容易写错的地方 */
    var corners = [
        [0, 0, 0, 1, "左上=白"],
        [W, 0, 1, 1, "右上=纯色"],
        [0, H, 0, 0, "左下=黑"],
        [W, H, 1, 0, "右下=黑（饱和但有 s）"]
    ]
    var bad = 0, detail = ""
    corners.forEach(function (t) {
        var sv = CO.svFromPoint(t[0], t[1], W, H)
        if (!near(sv.s, t[2], 1e-9) || !near(sv.v, t[3], 1e-9)) {
            bad++
            if (!detail) detail = t[4] + "：(" + t[0] + "," + t[1] + ") → "
                            + JSON.stringify(sv) + "，期望 s=" + t[2] + " v=" + t[3]
        }
    })
    if (bad === 0) ok("几何")
    else report("几何", "[色域面四角]", detail)

    /* 越界夹取 */
    var oob = [[-40, -40, 0, 1], [W + 40, H + 40, 1, 0]]
    var bad2 = 0, detail2 = ""
    oob.forEach(function (t) {
        var sv = CO.svFromPoint(t[0], t[1], W, H)
        if (!near(sv.s, t[2], 1e-9) || !near(sv.v, t[3], 1e-9)) {
            bad2++
            if (!detail2) detail2 = "(" + t[0] + "," + t[1] + ") → " + JSON.stringify(sv)
        }
    })
    if (bad2 === 0) ok("几何")
    else report("几何", "[越界夹取]", detail2)

    /* 两组互逆 */
    var bad3 = 0, detail3 = ""
    for (var x = 0; x <= W; x += 7) {
        for (var y = 0; y <= H; y += 7) {
            var sv = CO.svFromPoint(x, y, W, H)
            var p = CO.pointFromSv(sv.s, sv.v, W, H)
            if (Math.abs(p.x - x) > 1 || Math.abs(p.y - y) > 1) {
                bad3++
                if (!detail3) detail3 = "(" + x + "," + y + ") → " + JSON.stringify(sv)
                                + " → (" + p.x + "," + p.y + ")"
            }
        }
    }
    if (bad3 === 0) ok("几何")
    else report("几何", "[svFromPoint / pointFromSv 互逆]", bad3 + " 例不互逆；首例 " + detail3)

    var bad4 = 0, detail4 = ""
    for (var hx = 0; hx < W; hx += 3) {
        var hue = CO.hueFromX(hx, W)
        var bx = CO.xFromHue(hue, W)
        if (Math.abs(bx - hx) > 1) {
            bad4++
            if (!detail4) detail4 = "x=" + hx + " → hue=" + hue + " → x=" + bx
        }
    }
    if (bad4 === 0) ok("几何")
    else report("几何", "[hueFromX / xFromHue 互逆]", bad4 + " 例不互逆；首例 " + detail4)

    /* 360° 折回 0：条右端与左端是**同一个色相**。这条是刻意的语义，
     * 写成断言，免得有人"修"成 360。 */
    if (CO.hueFromX(W, W) === 0 && CO.xFromHue(360, W) === 0) ok("几何")
    else report("几何", "[360° 折回 0]",
                "色相条右端必须等于左端（360 ≡ 0）：hueFromX(w,w)=" + CO.hueFromX(W, W)
                + "（期望 0），xFromHue(360,w)=" + CO.xFromHue(360, W) + "（期望 0）")

    /* 退化输入：**只承诺「不出 NaN、落在 [0,1]」**，不承诺具体取值。
     *
     * 零宽 / 负宽 / NaN 宽度的色域面本来就不可见，给它一个「正确」的
     * (s, v) 没有意义 —— 首跑我在这里写了个 {0,0} 的期望，实测是
     * {1,0}（x 越界夹到 1），说明那个期望是**我猜的**。
     *
     * 这里真正要防的是唯一的真风险：**除零把整块色域面变成 NaN** ——
     * 那会让面板整块消失，而不是显示得难看。 */
    var degen = [[10, 10, 0, 0], [10, 10, -5, -5], [NaN, NaN, 200, 100],
                 [Infinity, 0, 200, 100], [0, 0, NaN, NaN], [1e9, -1e9, 200, 100]]
    var bad5 = 0, detail5 = ""
    degen.forEach(function (t) {
        var sv = CO.svFromPoint(t[0], t[1], t[2], t[3])
        if (!isFinite(sv.s) || !isFinite(sv.v)
            || sv.s < 0 || sv.s > 1 || sv.v < 0 || sv.v > 1) {
            bad5++
            if (!detail5) detail5 = "svFromPoint(" + t.join(",") + ") = "
                            + JSON.stringify(sv)
        }
    })
    if (bad5 === 0) ok("几何")
    else report("几何", "[退化输入不出 NaN]", bad5 + " 处越界 / NaN；首处 " + detail5)
})()

/* ═══════════════════════ [色块] ═══════════════════════ */

;(function () {
    var ring = CO.swatchRing(12)
    if (ring.length === 12) ok("色块")
    else report("色块", "[长度]", "swatchRing(12).length = " + ring.length + "，期望 12")

    /* 每一项都要能被 hsvToRgb **复算**——"手抄十二个十六进制"是复算不出来的 */
    var bad = 0, detail = ""
    for (var i = 0; i < ring.length; ++i) {
        var expectH = 360 * i / 12
        var c = CO.hsvToRgb(expectH, 0.85, 0.95)
        var expectHex = CO.rgbToHex(c.r, c.g, c.b)
        if (Math.abs(ring[i].h - expectH) > 1e-9 || ring[i].hex !== expectHex
            || ring[i].r !== c.r || ring[i].g !== c.g || ring[i].b !== c.b) {
            bad++
            if (!detail) detail = "第 " + i + " 项 = " + JSON.stringify(ring[i])
                            + "，复算得 h=" + expectH + " hex=" + expectHex
        }
    }
    if (bad === 0) ok("色块")
    else report("色块", "[逐项可复算]", bad + " 项对不上；首项 " + detail)

    /* 第一项必须是 0°（色相环从红开始）—— 这是"起点在哪"的判据 */
    if (ring[0].h === 0) ok("色块")
    else report("色块", "[起点]", "swatchRing 第一项 h = " + ring[0].h + "，期望 0")

    /* 边界：n = 1 给一个色标；n = 0 / 负数夹到 1；小数四舍五入 */
    var r1 = CO.swatchRing(1), r0 = CO.swatchRing(0), rn = CO.swatchRing(-5)
    var rf = CO.swatchRing(3.6)
    if (r1.length === 1 && r0.length === 1 && rn.length === 1 && rf.length === 4) ok("色块")
    else report("色块", "[n 的边界]",
                "swatchRing(1)=" + r1.length + " swatchRing(0)=" + r0.length
                + " swatchRing(-5)=" + rn.length + "（前三个都期望 1）"
                + " swatchRing(3.6)=" + rf.length + "（期望 4）")
})()

/* ═══════════════════════ 结论 ═══════════════════════ */

console.log("")
SECTIONS.forEach(function (s) {
    var p = secPass[s] || 0
    var f = secFail[s] || 0
    console.log("  " + s.padEnd(10) + p + " 条通过" + (f ? "   ✗ " + f + " 条失败" : "   ✓"))
})
console.log("")
console.log("判据合计   " + pass + " / " + (pass + fail) + (fail ? "   ✗" : "   ✓"))
console.log("")

if (fail) {
    console.log("COLOR_FAIL")
    process.exit(1)
}
console.log("COLOR_OK")
