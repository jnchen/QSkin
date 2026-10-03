/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinToggle
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 开关按钮（两态按钮）。用来表达"这个功能此刻是开着的"——
 * 加粗、只读、自动换行，这类没有输入、只有状态的东西。
 *
 * ── 与 QSkinButton 的关系：共用**内容**，各用各的**底**────────────────────
 * 它复用两格插槽、新增一格：
 *
 *   buttonContent   图标 + 文字的排布，**一模一样** —— 开关里的
 *                   "图标在左、间距多少"与按钮没有任何差别，
 *                   所以这格是真正意义上的复用（含 label 的接线）
 *   label           字体 / 字重 / 颜色策略，同上
 *   toggleBackground  **不复用**。完整论证写在
 *                   slots/BasicToggleBackground.qml 文件头，一句话是：
 *                   `variant` 答"这是个什么按钮"，on/off 答"它现在是
 *                   开还是关"——两条正交的轴，挤进一个枚举就丢信息。
 *
 * ── 为什么不直接 `QSkinButton { checkable: true }` ────────────────────────
 * 差别不在画法，在**语义与默认值**：
 *   · 按钮是动作（按一下发生一件事），开关是状态（一直有个值）。
 *     `Accessible.role` 因此不同（CheckBox vs Button），
 *     而读屏软件正是靠这个决定念"开关，已打开"还是"按钮"。
 *   · 默认变体不同：按钮默认是有底的 `default`，开关默认是描边的
 *     `outline`。这条有实测依据 —— Basic 的 ghost 常态 `opacity: 0`，
 *     若开关沿用那套"幽灵"逻辑，关闭状态的开关在屏幕上**完全不可见**。
 *
 * 顺带一件本批一并修掉的老账：`QSkinButton` 的 `checkable` 从 M1 起就公开，
 * 但五套主题的按钮底板**没有一份读过 `checked`** —— 可切换按钮按下去
 * 布尔值变了、屏幕上一个像素都没动。这一批把那条状态轴补进了五份底板，
 * 于是 `QSkinButton { checkable: true }` 现在也有反馈了（见各文件的注释）。
 *
 * ── `checked` 只由"面"表达，不由文字表达 ────────────────────────────────
 * 打开时底色与描边变、**文字颜色不变**。这不是省事：shadcn 的开关正是
 * 这么做的（`data-[state=on]:bg-accent`，而 accent-foreground 是深灰、
 * 不是品牌色）。少一条状态轴穿过 label，主题作者的负担就少一条。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    property string text: ""
    property url    iconSource: ""
    property int    iconSize: Theme.size.iconSm

    /** 矢量图标插槽（与 QSkinButton 同一约定）。 */
    property Component icon: null
    property string iconDirection: "down"

    /* ══════════════════════ 外观 ══════════════════════ */

    /** outline（默认，常态有描边）| default（常态无底无描边）。 */
    property string variant: "outline"

    /** sm | md | lg */
    property string size: "md"

    /* ══════════════════════ 状态 ══════════════════════ */

    property bool checked: false

    property bool hovered: false
    property bool pressed: false

    /** 所属的开关组。设了就由组决定 checked（与 QSkinRadio 同一协议）。 */
    property var group: null

    /** 代表的值。组按它比对。 */
    property var value: undefined

    signal clicked()
    signal toggled()

    /* ══════════════════════ 尺寸 ══════════════════════
     * 与 QSkinButton 用**同一套**映射 —— 一个开关和它旁边的按钮必须等高、
     * 同内距，否则并排摆出来会一高一低。主题可以改 controlSm/Md/Lg 的
     * 值，但不该决定"开关到底多高"。 */

    readonly property int controlHeight: root.size === "sm" ? Theme.size.controlSm
                                       : root.size === "lg" ? Theme.size.controlLg
                                       : Theme.size.controlMd

    readonly property int contentPadding: root.size === "sm" ? Theme.space.md
                                        : root.size === "lg" ? Theme.space.xl
                                        : Theme.space.lg

    implicitWidth: Math.max(root.controlHeight,
                            root.contentPadding * 2 + contentLoader.implicitWidth)
    implicitHeight: root.controlHeight

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true

    Accessible.role:          Accessible.CheckBox
    Accessible.name:          root.text
    Accessible.checkable:     true
    Accessible.checked:       root.checked
    Accessible.onPressAction: root._activate()

    /* ══════════════════════ 插槽 ══════════════════════ */

    Loader {
        id: backgroundLoader

        anchors.fill: parent
        sourceComponent: Slots.toggleBackground

        Binding {
            target: backgroundLoader.item
            property: "control"
            value: root
            when: backgroundLoader.item !== null
        }
    }

    Loader {
        id: contentLoader

        anchors.centerIn: parent
        sourceComponent: Slots.buttonContent

        Binding {
            target: contentLoader.item
            property: "control"
            value: root
            when: contentLoader.item !== null
        }

        /* label / icon 的接线与 QSkinButton 逐字相同（理由见那里的注释） */
        Binding {
            target: contentLoader.item
            property: "labelDelegate"
            value: Slots.label
            when: contentLoader.item !== null
        }

        Binding {
            target: contentLoader.item
            property: "iconDelegate"
            value: root.icon
            when: contentLoader.item !== null
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
    Keys.onReturnPressed: root._activate()
    Keys.onEnterPressed:  root._activate()
    Keys.onSpacePressed: function(event) { event.accepted = true; root.pressed = true }
    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Space) {
            event.accepted = true
            root.pressed = false
            root._activate()
        }
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    Component.onCompleted: if (root.group !== null) root.group._register(root)
    Component.onDestruction: if (root.group !== null) root.group._unregister(root)

    function _activate() {
        if (!root.enabled) return
        if (root.group !== null) {
            /* 组在场时由组决定新状态（它还要处理"最多选几个"这类规则），
             * 控件自己不先改 —— 否则会出现"控件已经翻过去了、
             * 组又把它翻回来"的一帧闪烁。 */
            root.group._toggleFrom(root)
        } else {
            root.checked = !root.checked
        }
        root.toggled()
        root.clicked()
    }
}
