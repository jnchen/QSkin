/****************************************************************************
 * QSkin · Quick Design System — Theme / Arco Design / slots / ACCheckIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Arco Design 的复选框指示器。与 Ant 的差异：
 *   尺寸   14×14（Arco 图标/勾选整体小一号）
 *   圆角   2px（radius.sm）
 *   hover  描边 → brand（Arco 直接用常态品牌色，Ant 用浅一档）
 *   选中   #165DFF 实心 + 白勾
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Shapes 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    implicitWidth:  14
    implicitHeight: 14
    width:  implicitWidth
    height: implicitHeight

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

    /* 14×14 里勾要小一号 */
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

            startX: 3.5
            startY: 7.5
            PathLine { x: 5.75; y: 9.75 }
            PathLine { x: 10.5; y: 5    }
        }
    }

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
            if (disabled()) return Theme.color.bgSubtle
            return on() ? Theme.color.brand : Theme.color.bgElevated
        }

        function borderWidth() {
            return on() ? 0 : 1
        }

        function borderColor() {
            if (disabled()) return Theme.color.border
            if (hovered())  return Theme.color.brand
            return Theme.color.borderStrong
        }

        function glyphColor() {
            if (disabled()) return Theme.color.fgDisabled
            return Theme.color.onBrand
        }
    }
}
