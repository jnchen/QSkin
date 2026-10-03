/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinSlider
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 滑块（M9）。
 *
 * ── 分工 ─────────────────────────────────────────────────────────────
 *   本文件：取值状态机 —— 点击/拖拽轨道、键盘步进、滚轮、stepSize 吸附、
 *           from/to 边界钳制
 *   插槽：  sliderTrack（indicator 家族）—— 轨道/已滑过区/手柄的视觉
 *
 * ── 取值链路 ─────────────────────────────────────────────────────────
 *   一切输入（鼠标 x / 键盘 / 滚轮）先归一到 _snap()：
 *     stepSize > 0 → 吸附到 from + n * stepSize 的格点
 *     永远钳制到 [from, to]
 *   position 是只读派生量（0~1），供插槽定位手柄 —— 插槽只读不写。
 *
 * ── 键盘 ─────────────────────────────────────────────────────────────
 *   ←/→ 步进（stepSize，未设时为量程的 1/100）；Home/End 直达两端。
 *   拖拽与点击期间的每一步都发 moved(value)，业务可拿去做实时预览。
 *
 * 用法：
 *     QSkinSlider {
 *         from: 0; to: 100; stepSize: 10
 *         onMoved: function(v) { label.text = v }
 *     }
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    property real from: 0
    property real to: 100
    property real value: 0

    /** 步长。0 = 连续取值（不吸附格点） */
    property real stepSize: 0

    /** 视觉位置（0~1），插槽据此摆手柄。只读派生量 */
    readonly property real position:
        (root.to === root.from) ? 0
        : (root.value - root.from) / (root.to - root.from)

    property bool hovered: false
    property bool pressed: false

    /** 用户拖动/点击/键盘过程中的每一步。外部改 value 不发此信号 */
    signal moved(real val)

    /* ══════════════════════ 尺寸 ══════════════════════ */

    implicitWidth:  200
    implicitHeight: Theme.size.controlSm

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true

    Accessible.role: Accessible.Slider
    Accessible.name: qsTr("滑块")

    /* ══════════════════════ 插槽 ══════════════════════ */

    Loader {
        id: trackLoader

        anchors.fill: parent
        sourceComponent: Slots.sliderTrack

        Binding {
            target: trackLoader.item
            property: "control"
            value: root
            when: trackLoader.item !== null
        }
    }

    FocusRing { control: root }

    /* ══════════════════════ 交互 ══════════════════════ */

    MouseArea {
        id: ma

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onEntered:  root.hovered = true
        onExited:   root.hovered = false
        onCanceled: root.pressed = false

        onPressed: function(mouse) {
            if (mouse.button !== Qt.LeftButton) return
            root.pressed = true
            root.forceActiveFocus()
            root._setValueFromX(mouse.x)
        }

        /* 拖动 = 持续按住的位移（不需要 drag.target —— 手柄是纯视觉，
         * 真值永远由 x 反算，视图与状态不会分叉） */
        onPositionChanged: function(mouse) {
            if (root.pressed) root._setValueFromX(mouse.x)
        }

        onReleased: root.pressed = false

        onWheel: function(wheel) {
            if (!root.enabled) return
            wheel.accepted = true
            root.forceActiveFocus()
            root._step(wheel.angleDelta.y > 0 ? 1 : -1)
        }
    }

    Keys.onLeftPressed:  function(event) { event.accepted = true; root._step(-1) }
    Keys.onRightPressed: function(event) { event.accepted = true; root._step(1) }

    /* Home/End 不在 Keys 的专用处理器列表里，走通用 onPressed */
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Home) {
            event.accepted = true
            root._setValue(root.from)
        } else if (event.key === Qt.Key_End) {
            event.accepted = true
            root._setValue(root.to)
        }
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    /** 吸附 + 钳制。所有输入的唯一收口 */
    function _snap(v) {
        if (root.stepSize > 0)
            v = root.from + Math.round((v - root.from) / root.stepSize) * root.stepSize
        v = Math.max(root.from, Math.min(root.to, v))
        /* 浮点累积误差收尾（0.30000000000000004 之类） */
        return Number(v.toPrecision(12))
    }

    function _setValue(v) {
        v = root._snap(v)
        if (v !== root.value) {
            root.value = v
            root.moved(v)
        }
    }

    function _setValueFromX(x) {
        var p = Math.max(0, Math.min(1, x / Math.max(1, root.width)))
        root._setValue(root.from + p * (root.to - root.from))
    }

    function _step(dir) {
        var s = root.stepSize > 0 ? root.stepSize : (root.to - root.from) / 100
        root._setValue(root.value + dir * s)
    }
}
