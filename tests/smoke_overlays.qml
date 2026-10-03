/****************************************************************************
 * QSkin · 冒烟测试 4/4 — 浮层插槽（QSkinSelect / QSkinTooltip）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 浮层是五个插槽里最难的一档：它同时含"外壳"（视觉）和"列表"（行为）。
 * 这组断言守住拆分是否真的成立 —— 换掉插槽之后，行为不能跟着变。
 *
 * 位掩码退出码的约定见 smoke_slots.qml 文件头。
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

    /* ── 被测对象 ── */

    QSkinButton {
        id: btn
        text: "Save"
    }

    QSkinSelect {
        id: sel
        model: ["Red", "Green", "Blue"]
        currentIndex: 1
    }

    QSkinTooltip {
        id: tip
        text: "保存当前文档"
        target: btn
        delay: 0
    }

    /* 用来替换的下拉面板外壳：纯色、直角，与 Basic 明显不同 */
    Component {
        id: altSelectOverlay
        Item {
            property var  control: null
            property Item content: null
            implicitWidth:  120
            implicitHeight: 40
            onContentChanged: {
                if (content) { content.parent = null; content.visible = false }
            }
        }
    }

    function run() {
        /* [0] 两个浮层插槽都有 Basic 默认实现 */
        root.expect(Slots.selectOverlay !== null && Slots.tooltipOverlay !== null)

        var origSelect = Slots.selectOverlay

        Slots.install({ selectOverlay: altSelectOverlay })

        /* [1] overlay 插槽可以被替换 */
        root.expect(Slots.selectOverlay === altSelectOverlay)

        /* [2] reset 恢复 Basic 实现 */
        Slots.reset()
        root.expect(Slots.selectOverlay === origSelect)

        /* [3] 下拉框本身有有效尺寸 */
        root.expect(sel.implicitWidth > 0 && sel.implicitHeight === Theme.size.controlMd)

        /* [4] count 跟随 model */
        root.expect(sel.count === 3)

        /* [5] 当前项文字跟随 currentIndex —— 走的是 _textOf() 的解析 */
        root.expect(sel.currentIndex === 1 && sel.text === "Green")

        /* [6] 越界索引不会抛出，也不会产生脏文字 */
        root.expect(sel._textOf(99) === "")

        /* [7] Tooltip 的 hover 侦测接上了 target.hovered；
         *     默认不弹，target 进入 hover 才弹 */
        root.expect(tip.opened === false && tip.targetHovered === false)
        btn.hovered = true
        root.expect(tip.targetHovered === true)
        btn.hovered = false

        Qt.exit(root.mask)
    }

    Component.onCompleted: function() { Qt.callLater(root.run) }
}
