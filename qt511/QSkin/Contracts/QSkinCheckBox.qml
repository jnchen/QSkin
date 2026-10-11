/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinCheckBox
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 复选框。
 *
 * ── 三态，不是两态 ──────────────────────────────────────────────────────
 * checked / indeterminate / unchecked。半选是树形控件"部分子项被选中"的
 * 表达方式，把它的点击行为定义清楚很重要：
 *
 *     半选状态下点击 → 变成**全选**（而不是变成未选）
 *
 * 这是 Web 的通用约定。如果反过来，用户在"全选/半选/全不选"里循环时
 * 会莫名跳到空选，体感很差。
 *
 * ── 点击热区 ────────────────────────────────────────────────────────────
 * 文字也算热区。只让 16×16 的方框可点，是桌面端最典型的"反人类"设计之一：
 * 用户点文字没反应，会以为软件坏了。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    property string text: ""
    property string variant: "default"

    property bool checked: false
    property bool indeterminate: false

    property bool hovered: false
    property bool pressed: false

    signal clicked()
    signal toggled()

    implicitWidth:  content.implicitWidth
    implicitHeight: Math.max(Theme.size.controlSm, content.implicitHeight)

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true

    Accessible.role:           Accessible.CheckBox
    Accessible.name:           root.text
    Accessible.checkable:      true
    Accessible.checked:        root.checked
    Accessible.onPressAction:  root._activate()

    /* ══════════════════════ 插槽 ══════════════════════ */

    QSkinRow {
        id: content

        anchors.verticalCenter: parent.verticalCenter
        gap: Theme.space.sm
        align: "center"

        /* 用 Binding 注入宿主引用，而不是 onLoaded 回调 —— 理由见
         * QSkinButton.qml 中的同名注释。 */
        Loader {
            id: indicatorLoader
            sourceComponent: Slots.checkIndicator

            Binding {
                target: indicatorLoader.item
                property: "control"
                value: root
                when: indicatorLoader.item !== null
            }
        }

        Loader {
            id: labelLoader
            sourceComponent: Slots.label

            Binding {
                target: labelLoader.item
                property: "control"
                value: root
                when: labelLoader.item !== null
            }
        }
    }

    FocusRing { control: root }

    /* ══════════════════════ 交互 ══════════════════════ */

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onEntered:  root.hovered = true
        onExited:   root.hovered = false
        onCanceled: root.pressed = false
        onReleased: root.pressed = false

        onPressed: function(mouse) {
            if (mouse.button !== Qt.LeftButton) return
            root.pressed = true
            root.forceActiveFocus()
        }
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) root._activate()
        }
    }

    /* 信号参数必须写成 function(event)，否则 qmllint 报 Unqualified access */
    Keys.onSpacePressed: function(event) { event.accepted = true; root.pressed = true }
    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Space) {
            event.accepted = true
            root.pressed = false
            root._activate()
        }
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    function _activate() {
        if (!root.enabled) return
        if (root.indeterminate) {
            root.indeterminate = false
            root.checked = true
        } else {
            root.checked = !root.checked
        }
        root.toggled()
        root.clicked()
    }
}
