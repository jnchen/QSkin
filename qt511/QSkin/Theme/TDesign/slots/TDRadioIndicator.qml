/****************************************************************************
 * QSkin · Quick Design System — Theme / TDesign / slots / TDRadioIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * TDesign 的单选圈 —— **实心策略**，圆心直径 **8**。
 *
 * ── 为什么 TDesign 需要自己一格，而 Arco 不需要（M20.1 核实）───────────
 * 两家都是"实心 + 白点"，策略上没有分歧。分开它们的是**圆点直径**：
 *
 *     Arco      mask 内点 = (@radio-layout-height − 2×border) × 0.4
 *               = (16 − 2) × 0.4 = **5.6px**  → 与 Basic 的 6 差 0.4px，
 *               肉眼不可分，复用 Basic 是站得住的
 *     TDesign   `@radio-dot-size = (@radio-size / 2)` = 16 / 2 = **8px**
 *               与 Basic 的 6 差 2px（小圆点上这是 33% 的相对差），
 *               复用 Basic 会让 TDesign 的单选看起来"点太小"→ 必须自己一格
 *
 * TDesign 采用实心策略的依据是它自己的 API：`Radio.icon` 默认值是
 * `'circle'`，而官方文档对这个取值的定义是「**circle 表示填充型图标**、
 * line 表示描边型图标、dot 表示圆点图标」。默认即填充型。
 *
 * ── 与 Ant 的实心有什么区别 ────────────────────────────────────────────
 * 两家圆心直径都是 8、都是白点，区别在**描边**：
 *     TDesign  勾选后不再需要描边（底色已经说清），未勾选用 component-border
 *     Ant      勾选后描边与底色同色（"留着但看不见"），未勾选用 colorBorder
 * 以及在**未勾选时的底色**：TDesign 的 `--td-radio-bg-color` 是容器色，
 * 两家一致。这一格存在的意义就是那个 8 —— 一个数字。
 *
 * 契约三条照旧：只读 control 状态、不改状态、不加交互。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    implicitWidth:  16
    implicitHeight: 16
    width:  implicitWidth
    height: implicitHeight

    /** 圆心直径 8 —— TDesign `@radio-dot-size = @radio-size / 2`。 */
    readonly property int dotSize: 8

    Rectangle {
        id: ring

        anchors.fill: parent
        radius: width / 2

        color:        d.bg()
        border.width: d.borderWidth()
        border.color: d.borderColor()

        Behavior on color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width:  root.dotSize
        height: root.dotSize
        radius: width / 2

        visible: d.on()
        color:   d.dotColor()

        Behavior on color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    QtObject {
        id: d

        function on()       { return root.control ? root.control.checked === true : false }
        function disabled() { return root.control ? root.control.enabled === false : false }
        function hovered()  { return root.control ? root.control.hovered === true : false }

        /** 勾选 = --td-radio-icon-checked-color（品牌色）铺满 */
        function bg() {
            if (disabled()) return on() ? Theme.color.brandSubtle : Theme.color.bgSubtle
            if (on())       return hovered() ? Theme.color.brandHover : Theme.color.brand
            return hovered() ? Theme.color.bgSubtle : Theme.color.bg
        }

        /** TDesign 的单选圈未勾选时时时有 1px 描边，勾选后由底色接管 */
        function borderWidth() { return on() ? 0 : 1 }

        function borderColor() {
            if (disabled()) return Theme.color.border
            if (hovered())  return Theme.color.brand
            return Theme.color.border
        }

        /** 白点（勾选态图标是"实心圆挖掉一个白圆"） */
        function dotColor() {
            if (disabled()) return Theme.color.fgDisabled
            return Theme.color.onBrand
        }
    }
}
