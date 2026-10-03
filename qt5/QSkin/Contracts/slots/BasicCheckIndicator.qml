/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicCheckIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「indicator」插槽 —— 复选框的方框与勾。
 *
 * 三个容易被忽略的细节：
 *
 *   1. 尺寸固定 16×16，不随字号走。
 *      Ant Design 是 16，TDesign 是 16，shadcn 是 16 —— 这个数字惊人的一致，
 *      所以硬编码没问题；真要变，主题替换这个插槽即可。
 *
 *   2. 勾用 Shape 画而不是 Text 打 "✓"。
 *      字体里 U+2713 的覆盖率在 Linux / 嵌入式上并不稳定，
 *      而且字形随字体变化会让"同一套设计"在不同机器上长歪。
 *
 *   3. indeterminate（半选）不是 checked 的中间态，是**第三种状态**。
 *      树形控件全选/部分选中全靠它。画横线而不是勾。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Shapes 1.15
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
            if (disabled()) return on() ? Theme.color.bgSunken : Theme.color.bgSubtle
            return on() ? Theme.color.brand : (hovered() ? Theme.color.bgSubtle : Theme.color.bg)
        }

        function borderWidth() {
            return on() ? 0 : 1
        }

        function borderColor() {
            if (disabled()) return Theme.color.border
            if (hovered())  return Theme.color.brand
            return Theme.color.borderStrong
        }

        /** 勾与横线的颜色：选中时是品牌色的反色，未选中时不可见 */
        function glyphColor() {
            if (disabled()) return Theme.color.fgDisabled
            return Theme.color.onBrand
        }
    }
}
