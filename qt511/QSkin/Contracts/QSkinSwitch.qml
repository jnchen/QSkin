/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinSwitch
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 开关。
 *
 * 和 QSkinCheckBox 共用同一套状态（checked / enabled / hovered），
 * 但语义不同：复选框是"我勾选了这项"，开关是"这个功能是开着的"。
 * 所以它是独立控件、独立插槽（switchIndicator），不是一个开关参数 ——
 * 主题作者可以只换其中一个的样式。
 *
 * 没有 indeterminate：开关表达的是二元的开合状态，
 * 半选在这里没有语义，硬加只会让状态机变复杂。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    property string text: ""
    property string variant: "default"

    property bool checked: false

    property bool hovered: false
    property bool pressed: false

    signal clicked()
    signal toggled()

    implicitWidth:  content.implicitWidth
    implicitHeight: Math.max(Theme.size.controlSm, content.implicitHeight)

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true

    Accessible.role:          Accessible.CheckBox
    Accessible.name:          root.text
    Accessible.checkable:     true
    Accessible.checked:       root.checked
    Accessible.onPressAction: root._activate()

    /* ══════════════════════ 插槽 ══════════════════════ */

    QSkinRow {
        id: content

        anchors.verticalCenter: parent.verticalCenter
        gap: Theme.space.sm
        align: "center"

        /* 用 Binding 注入宿主引用，而不是 onLoaded 回调 —— 理由见
         * QSkinButton.qml 同名注释。 */
        Loader {
            id: indicatorLoader
            sourceComponent: Slots.switchIndicator

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
            event.accepted  = true
            root.pressed = false
            root._activate()
        }
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    function _activate() {
        if (!root.enabled) return
        root.checked = !root.checked
        root.toggled()
        root.clicked()
    }
}
