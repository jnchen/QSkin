/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicSwitchIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「indicator」插槽 —— 开关的轨道与滑块。
 *
 * 开关和复选框共用同一套状态（checked / indeterminate / enabled），
 * 视觉语义却不同：复选框是"勾选"，开关是"开合"。
 * 所以它们是两个插槽，不是一个插槽加一个开关参数 ——
 * 让主题作者能只换其中一个。
 *
 * 滑块位移用 x 而不是 anchors：anchors 的变化是瞬时的，
 * 而开关的手感几乎全在那 200ms 的滑动上。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    implicitWidth:  36
    implicitHeight: 20
    width:  implicitWidth
    height: implicitHeight

    /* 轨道内缩量 = 滑块与轨道边缘的间隙，(20 - 16) / 2 = 2 */
    readonly property int inset:    2
    readonly property int knobSize: 16

    /* ── 轨道 ── */

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2

        color:        d.trackColor()
        border.width: 1
        border.color: d.borderColor()

        Behavior on color {
            ColorAnimation { duration: Theme.motion.normal; easing.type: Theme.motion.easing }
        }
    }

    /* ── 滑块 ── */

    Rectangle {
        id: knob

        width:  root.knobSize
        height: root.knobSize
        radius: root.knobSize / 2

        y: (root.height - root.knobSize) / 2
        x: d.checked() ? root.width - root.knobSize - root.inset : root.inset

        color:        d.knobColor()
        border.width: 1
        border.color: d.knobBorderColor()

        Behavior on x {
            NumberAnimation { duration: Theme.motion.normal; easing.type: Theme.motion.easing }
        }
    }

    QtObject {
        id: d

        function checked()  { return root.control ? root.control.checked === true : false }
        function disabled() { return root.control ? root.control.enabled === false : false }
        function hovered()  { return root.control ? root.control.hovered === true : false }

        function trackColor() {
            if (disabled()) return checked() ? Theme.color.brandSubtle : Theme.color.bgSunken
            return checked() ? Theme.color.brand : Theme.color.bgSunken
        }

        function borderColor() {
            if (disabled()) return Theme.color.border
            if (checked())  return "transparent"
            return hovered() ? Theme.color.borderStrong : Theme.color.border
        }

        function knobColor() {
            return disabled() ? Theme.color.bgSubtle : Theme.color.bgElevated
        }

        function knobBorderColor() {
            return disabled() ? Theme.color.border : Theme.color.borderStrong
        }
    }
}
