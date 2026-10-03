/****************************************************************************
 * QSkin · 冒烟测试 5 — TDesign 主题（M2）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件守的是「主题层与契约层的接缝」──────────────────────────────
 * M2 最容易坏的地方不是色值抄错，而是这两件事：
 *
 *   1. apply() 只装了令牌、忘了装插槽（或漏装某一个）；
 *   2. remove() 只卸了一半 —— 令牌回去了、插槽还留着，
 *      于是界面变成「Neutral 的令牌 + TDesign 的插槽」这种不存在的组合。
 *
 * 所以断言刻意分成「装」和「卸」两组，且两边都逐个插槽核对。
 *
 * 位掩码退出码的约定见 smoke_slots.qml 文件头（8 条以内，一条占一个 bit）。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0

Item {
    id: root

    property int mask: 0
    property int idx: 0

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    QSkinButton { id: b; text: "TDesign" }

    function run() {
        /* ── 先把 Basic 状态全部记下来 ── */
        var basicBg      = Slots.buttonBackground
        var basicLabel   = Slots.label
        var basicInput   = Slots.inputBackground
        var basicCheck   = Slots.checkIndicator
        var basicSelect  = Slots.selectOverlay
        var basicContent = Slots.buttonContent
        var basicSwitch  = Slots.switchIndicator
        var basicTip     = Slots.tooltipOverlay

        TDesign.apply()

        /* [0] 令牌装上了：主题名 + 品牌色（--td-brand-color） */
        root.expect(Theme.themeName === "TDesign" && Theme.color.brand === "#0052D9")

        /* [1] 令牌形状完整，且真的作用到了控件上
         *     （radius.md 3px 是 TDesign 与 Neutral 4px 最直观的分界） */
        root.expect(Theme.radius.md === 3 && Theme.size.controlMd === 32
                    && b.implicitHeight === 32)

        /* [2] 五个该覆盖的插槽全部换了 */
        root.expect(Slots.buttonBackground !== basicBg
                    && Slots.label            !== basicLabel
                    && Slots.inputBackground  !== basicInput
                    && Slots.checkIndicator   !== basicCheck
                    && Slots.selectOverlay    !== basicSelect)

        /* [3] 三个不该覆盖的插槽保持 Basic —— 防止主题"顺手"多换东西 */
        root.expect(Slots.buttonContent   === basicContent
                    && Slots.switchIndicator  === basicSwitch
                    && Slots.tooltipOverlay   === basicTip)

        /* [4] apply() 幂等：重复装载不会生成新的插槽实例 */
        var bgOnce = Slots.buttonBackground
        TDesign.apply()
        root.expect(Slots.buttonBackground === bgOnce
                    && Theme.color.brand === "#0052D9")

        /* [5] 深色集合：官方《深色模式》蓝阶 Blue6 + 页面灰 gray-14 */
        Theme.mode = "dark"
        root.expect(Theme.color.brand === "#2174FF" && Theme.color.bg === "#181818")

        Theme.mode = "light"
        TDesign.remove()

        /* [6] 令牌卸干净了（Neutral 的品牌紫 #7C3AED） */
        root.expect(Theme.themeName === "Neutral" && Theme.color.brand === "#7C3AED")

        /* [7] 插槽也卸干净了 —— 不许出现"令牌回去了、插槽还留着" */
        root.expect(Slots.buttonBackground === basicBg
                    && Slots.label            === basicLabel
                    && Slots.inputBackground  === basicInput
                    && Slots.checkIndicator   === basicCheck
                    && Slots.selectOverlay    === basicSelect)

        Qt.exit(root.mask)
    }

    Component.onCompleted: function() { Qt.callLater(root.run) }
}
