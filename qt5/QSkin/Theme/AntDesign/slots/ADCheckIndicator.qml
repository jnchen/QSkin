/****************************************************************************
 * QSkin · Quick Design System — Theme / Ant Design / slots / ADCheckIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Ant Design 的复选框指示器。与 TDesign 的差异：
 *   圆角   4px（radius.sm = borderRadiusSM）vs TD 2px —— 一眼可辨
 *   hover  边框 → brandHover（浅一档，与输入框 hover 同一手法）
 *   选中   #1677FF 实心 + 白勾（无描边），与 TD 同构
 *   半选   #1677FF 实心 + 白横条
 *
 * 「未选中底色用 bgElevated 而不是 bg」的教训见 TDCheckIndicator：
 * 页面灰主题下（bg=#F5F5F5）白底方块才不与页面糊在一起。
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
            if (disabled()) return Theme.color.bgSubtle
            return on() ? Theme.color.brand : Theme.color.bgElevated
        }

        function borderWidth() {
            return on() ? 0 : 1
        }

        function borderColor() {
            if (disabled()) return Theme.color.borderStrong
            if (hovered())  return Theme.color.brandHover   /* ★ 浅一档 */
            return Theme.color.borderStrong
        }

        function glyphColor() {
            if (disabled()) return Theme.color.fgDisabled
            return Theme.color.onBrand
        }
    }
}
