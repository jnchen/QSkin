/****************************************************************************
 * QSkin · 冒烟测试 1/3 — 插槽装载语义（Slots.install / Slots.reset）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 为什么结果走退出码，而且是位掩码 ────────────────────────────────────
 *
 * Windows 上的 Qt 是 GUI 子系统程序，没有控制台，console.log 写出去的东西
 * 全部丢失（实测重定向到文件也是 0 字节）。唯一可靠的回传通道是进程退出码。
 *
 * 而 POSIX 的 WEXITSTATUS 只保留低 8 位（实测 Qt.exit(1000) 在 bash 里
 * 读到的是 232 = 1000 & 0xFF）。所以这里把断言限制在 8 条以内，
 * 每条占一个 bit：
 *
 *     退出码 = 0                 全部通过
 *     退出码 第 n 位为 1         第 n 条断言失败
 *
 * 一次运行就能报出全部失败项，不用逐条二分。
 *
 * ── 维护约定 ──────────────────────────────────────────────────────────
 * 每条断言上方标了 [n]，n 必须与 expect() 的调用顺序严格一致。
 * 插入新断言要重排所有编号，并且不能超过 8 条。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int mask: 0
    property int idx: 0

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    /* ── 用来替换的假插槽 ── */

    Component {
        id: altBg
        Rectangle { implicitWidth: 8; implicitHeight: 8; color: "red" }
    }

    Component {
        id: altContent
        Item { implicitWidth: 20; implicitHeight: 8 }
    }

    Component {
        id: altLabel
        Text {
            property var control: null
            text: control ? control.text : ""
            font.pixelSize: 20
        }
    }

    function run() {
        /* [0] 默认插槽全部非空 */
        root.expect(Slots.buttonBackground !== null
                    && Slots.buttonContent  !== null
                    && Slots.label         !== null)

        var origBg       = Slots.buttonBackground
        var origContent  = Slots.buttonContent
        var origLabel    = Slots.label
        var origSelect   = Slots.selectOverlay
        var origTooltip  = Slots.tooltipOverlay

        Slots.install({ buttonBackground: altBg })

        /* [1] install 替换指定插槽 */
        root.expect(Slots.buttonBackground === altBg)

        /* [2] install 不触碰未提供的插槽 */
        root.expect(Slots.label === origLabel && Slots.buttonContent === origContent)

        Slots.install({ buttonBackground: altBg })

        /* [3] install 幂等 */
        root.expect(Slots.buttonBackground === altBg)

        Slots.install({ notASlot: altBg })

        /* [4] 未知键被白名单挡下 */
        root.expect(Slots.buttonBackground === altBg && Slots.label === origLabel)

        Slots.install({ buttonContent: null })

        /* [5] null 值不会把插槽清空 */
        root.expect(Slots.buttonContent === origContent)

        Slots.reset()

        /* [6] reset 恢复全部已实现的插槽 */
        root.expect(Slots.buttonBackground === origBg
                    && Slots.buttonContent  === origContent
                    && Slots.label          === origLabel)

        /* [7] reset 把浮层插槽恢复到 Basic 实现
         * （曾经这里断言的是"置回 null" —— 那时 M1 还没实现浮层，
         *   插槽只有契约没有实现。现在两个都有 Basic 了。） */
        root.expect(Slots.selectOverlay  === origSelect
                    && Slots.tooltipOverlay === origTooltip
                    && origSelect !== null
                    && origTooltip !== null)

        Qt.exit(root.mask)
    }

    /* 不用 Component.onCompleted 直接测：见 smoke_sizes.qml 文件头的说明
     * —— Qt Quick Layouts 把尺寸重算推迟到 polish 阶段，同步读会是 0。
     * 本文件不测尺寸，但保持一致能省掉一个心照不宣的例外。 */
    Component.onCompleted: function() { Qt.callLater(root.run) }
}
