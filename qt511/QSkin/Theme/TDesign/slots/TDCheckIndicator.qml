/****************************************************************************
 * QSkin · Quick Design System — Theme / TDesign / slots / TDCheckIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * TDesign 的复选框指示器。
 *
 * ── 只需要改一个值，但不改就会出 bug ────────────────────────────────────
 * Basic 实现里，未选中状态的底色写的是 Theme.color.bg。
 * 在地基的 Neutral 主题下 bg 是白色，没问题；
 * 但 TDesign 的 bg 是 **#EEEEEE 的页面灰**（--td-bg-color-page），
 * 于是一个未选中的复选框会和页面背景糊成一团 —— 只剩一圈描边勉强可见。
 *
 * 这就是「换令牌会暴露出来的隐性假设」：Basic 写 bg 的时候，
 * 隐含假设了「页面底色 == 控件底色」。TDesign 打破了这个假设。
 * 正确写法是 bgElevated（--td-bg-color-specialcomponent，白）。
 *
 * 尺寸 16×16 与 Basic 一致（TDesign、Ant、shadcn 都是 16），
 * 圆角 2px 走 Theme.radius.sm（--td-radius-small），令牌已经带了。
 * 勾仍然用 Shape 画，理由见 BasicCheckIndicator 文件头。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Shapes 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    implicitWidth:  16
    implicitHeight: 16
    width:  implicitWidth
    height: implicitHeight

    /* ── 方框 ── */
    Rectangle {
        id: box

        anchors.fill: parent
        radius: Theme.radius.sm

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

    /* ── 勾 ── */
    Shape {
        // CurveRenderer 才有原生抗锯齿；默认的 GeometryRenderer 是硬边（见 README「图标锯齿」）
        anchors.fill: parent
        visible: d.checked() && !d.indeterminate()

        ShapePath {
            strokeWidth: 2
            strokeColor: d.glyphColor()
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap
            joinStyle:   ShapePath.RoundJoin

            startX: 4
            startY: 8.5
            PathLine { x: 6.5; y: 11   }
            PathLine { x: 12;  y: 5.5  }
        }
    }

    /* ── 半选：一条横线 ── */
    Rectangle {
        anchors.centerIn: parent
        width: 8
        height: 2
        radius: 1
        visible: d.indeterminate()
        color: d.glyphColor()
    }

    QtObject {
        id: d

        function checked() {
            return root.control ? root.control.checked === true : false
        }
        function indeterminate() {
            return root.control ? root.control.indeterminate === true : false
        }
        function disabled() {
            return root.control ? root.control.enabled === false : false
        }
        function hovered() {
            return root.control ? root.control.hovered === true : false
        }
        function on() {
            return checked() || indeterminate()
        }

        function bg() {
            if (disabled()) return on() ? Theme.color.bgSubtle : Theme.color.bgSubtle
            /* ★ 关键修正：未选中用 bgElevated（白），不是 bg（页面灰） */
            return on() ? Theme.color.brand : Theme.color.bgElevated
        }

        function borderWidth() {
            /* 选中后底色已经是实心品牌色，再画描边反而显得脏 */
            return on() ? 0 : 1
        }

        function borderColor() {
            if (disabled()) return Theme.color.border
            if (hovered())  return Theme.color.brand
            /* 常态 --td-component-border（#DCDCDC），比 Basic 的 borderStrong 更明确 */
            return Theme.color.borderStrong
        }

        function glyphColor() {
            if (disabled()) return Theme.color.fgDisabled
            return Theme.color.onBrand
        }
    }
}
