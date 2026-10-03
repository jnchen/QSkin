/****************************************************************************
 * QSkin · 冒烟测试 — M18.1：分隔线的**可见性**
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件为什么存在 ──────────────────────────────────────────────────
 * smoke_m18.qml 把 Divider 的**账目**守得死死的：洞多宽、两段线加起来
 * 正好等于容器宽、虚线末段不越界 —— 8 条断言，每条都被变异测试证伪过。
 * 它们全绿。然后抓图出来一看：**一整屏分隔线在屏幕上什么都不剩。**
 *
 * 原因不在控件里（几何一个像素都没错），在令牌表里：
 *
 *     tdesign/tokens.js   bg: "#EEEEEE"    border: "#E7E7E7"
 *     ant/tokens.js       bg: "#F5F5F5"    border: "#F0F0F0"
 *
 * 线的颜色比它躺着的那个底色还浅 7 阶 / 5 阶。这不是"审美问题"，是
 * **渲染结果与意图不符**，属于项目铁律「属性值对 ≠ 界面画对」的第六次
 * 实证 —— 而且这一次属性断言**根本没有能力**发现它：账目里没有"颜色"
 * 这一项。
 *
 * 所以这个文件补的就是那一项：把"线必须能被看见"写成一条**能变红**的
 * 断言。判据是感知亮度差（0.299R + 0.587G + 0.114B），阈值 12 ——
 *
 *     阈值怎么来的：M18 实测 ΔL=7 的线在屏幕上确实看不见（有图作证，
 *     .cache/m18_tdesign_light_base.png 就是它），ΔL=18 是第一个能看清
 *     的值。取 12 是这两者之间。
 *
 * ── 为什么必须遍历主题 × 明暗 ───────────────────────────────────────────
 * 这个缺陷**只在两套主题上出现**（tdesign 与 ant，它们的页底色是灰的；
 * arco / shadcn / neutral 的页底色是纯白，border 本来就看得见）。
 * 只测一套主题的实现，无论测哪一套，都会漏掉另一半 —— 这一类"只在某个
 * 配置下才成立"的缺陷，只有把配置空间走遍才抓得住。
 *
 * ── 断言（三条，互不替代）──────────────────────────────────────────────
 *   [0] 五套主题 × 明暗：`color.divider` 这个令牌存在且非空
 *       —— 防"删掉令牌表里那一行"（控件会拿到 undefined，画成黑线或者
 *          什么都不画，两种都很难在上层看出来）
 *   [1] 五套主题 × 明暗：divider 与 **该主题自己的** bg 的 ΔL ≥ 12
 *       —— 这是本文件的正主。它防的是"令牌在，但取值不可见"
 *   [2] 每套主题下，QSkinDivider 实际用出来的颜色 == 该主题的 divider 令牌
 *       —— 防"令牌表改对了，控件忘了跟着改"。这一条把令牌表和控件
 *          之间的那一跳也钉住
 *
 * [1] 和 [2] 缺一不可：只有 [1] 会放过"控件还用着旧令牌"，只有 [2] 会
 * 放过"控件和令牌一起取了个看不见的值"。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0
import QSkin.Theme.AntDesign 1.0
import QSkin.Theme.ArcoDesign 1.0
import QSkin.Theme.Shadcn 1.0

Item {
    id: root

    property int mask: 0
    property int idx: 0

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    /* 一条普通的横向 Divider —— 只用它的 `lineColor`，几何不参与。
     * 放在一个固定尺寸的宿主里，免得 width 为 0 时有人以为"没画出来
     * 是因为塌了"（本文件根本不看它画没画，只看它**打算用什么颜色画**）。 */
    Item {
        width: 300
        height: 30

        QSkinDivider {
            id: probe
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    /* QML 的 color 类型才会带 .r/.g/.b，而 Theme.color.xxx 从 JS 里来
     * 是字符串。用它俩做一次显式转换，顺带把"字符串到底能不能转"这件事
     * 也一并测了（转不了的话 .r 是 undefined，下面的差值会变成 NaN，
     * 比较必然为假 —— 不会静默通过）。 */
    QtObject {
        id: cvt

        property color divider: "#000000"
        property color bg:      "#000000"
    }

    /** 感知亮度（0..255）。系数是 ITU-R BT.601 的 luma 权重。 */
    function lum255(c) {
        return 0.299 * c.r * 255 + 0.587 * c.g * 255 + 0.114 * c.b * 255
    }

    function applyByName(n, mode) {
        Theme.mode = mode
        if (n === "TDesign")         TDesign.apply()
        else if (n === "AntDesign")  AntDesign.apply()
        else if (n === "ArcoDesign") ArcoDesign.apply()
        else if (n === "Shadcn")     Shadcn.apply()
        else                         Theme.reset()          /* Neutral */
    }

    function run() {
        var themes = ["Neutral", "TDesign", "AntDesign", "ArcoDesign", "Shadcn"]
        var modes  = ["light", "dark"]

        var allPresent = true
        var allVisible = true
        var allMatch   = true
        var trouble = []

        for (var t = 0; t < themes.length; ++t) {
            for (var m = 0; m < modes.length; ++m) {
                applyByName(themes[t], modes[m])

                var tag = themes[t] + "/" + modes[m]
                var dv  = Theme.color.divider

                /* ── [0] 令牌在不在 ── */
                if (dv === undefined || dv === null || dv === "") {
                    allPresent = false
                    trouble.push(tag + " 无 divider 令牌")
                    continue
                }

                cvt.divider = dv
                cvt.bg      = Theme.color.bg

                /* ── [1] 看不看得见 ── */
                var dL = Math.abs(lum255(cvt.divider) - lum255(cvt.bg))
                if (!(dL >= 12)) {
                    allVisible = false
                    trouble.push(tag + " ΔL=" + dL.toFixed(1)
                                 + " (divider=" + dv + " bg=" + Theme.color.bg + ")")
                }

                /* ── [2] 控件有没有真的用它 ──
                 * 比的是 0..255 的整数值 —— 浮点误差不会让它假红。 */
                var lc = probe.lineColor
                if (Math.round(lc.r * 255) !== Math.round(cvt.divider.r * 255)
                 || Math.round(lc.g * 255) !== Math.round(cvt.divider.g * 255)
                 || Math.round(lc.b * 255) !== Math.round(cvt.divider.b * 255)) {
                    allMatch = false
                    trouble.push(tag + " 控件用色 ≠ 令牌")
                }
            }
        }

        root.expect(allPresent)
        root.expect(allVisible)
        root.expect(allMatch)

        if (trouble.length > 0)
            console.log("smoke_m18_theme 失败明细：" + trouble.join(" | "))

        Theme.reset()
        Qt.exit(root.mask)
    }

    Component.onCompleted: function() { Qt.callLater(root.run) }
}
