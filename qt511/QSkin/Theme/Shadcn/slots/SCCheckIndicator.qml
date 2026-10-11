/****************************************************************************
 * QSkin · Quick Design System — Theme / shadcn / slots / SCCheckIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * shadcn/ui 的复选框指示器：
 *   未选中  transparent + 1px zinc-200（描边划界，与输入框同语言）
 *   hover   描边 → zinc-900（accent-hover 的暗化表达）
 *   选中    primary 近黑实心 + primary-foreground 白勾（深色下反转成白底黑勾）
 *   圆角    4px（rounded-sm）
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
            if (disabled()) return Theme.color.bgSunken
            return on() ? Theme.color.brand : "transparent"
        }

        function borderWidth() {
            return on() ? 0 : 1
        }

        function borderColor() {
            if (disabled()) return Theme.color.border
            if (hovered())  return Theme.color.fg
            return Theme.color.border
        }

        function glyphColor() {
            if (disabled()) return Theme.color.fgDisabled
            return Theme.color.onBrand
        }
    }
}
