/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinRadio
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 单选框。
 *
 * ── 与 QSkinCheckBox 的关系 ────────────────────────────────────────────────
 * 状态机几乎一样（checked / hovered / pressed / disabled），差别只有两条：
 *
 *   1. **没有半选。** 半选是"部分子项被选中"的表达，单选没有这个语义。
 *   2. **它是排他的。** 勾上这一个，同一组里其他所有个都必须弹起来。
 *      这一条是单选框的**全部意义** —— 一个能同时勾上两项的"单选组"
 *      比没有单选组还糟：它会安静地给出一个不存在的数据状态。
 *
 * 所以本控件的核心不是"画一个圈"，而是**排他性放在哪一层**。
 * 本设计的答案是：状态机在组（QSkinRadioGroup），单选只负责两件事 ——
 * 把点击转成一次 `select()` 请求，以及把 `checked` 画出来。
 * 单独使用时 `group` 为 null，它就退化成"自己能勾上自己"的复选框行为
 * （不会去动别人，因为它不认识别人）。
 *
 * ── 键盘为什么不在这里实现 ──────────────────────────────────────────────
 * 方向键在**组内**移动才成立（"下一个"是相对于组说的）。所以
 * ↑↓←→ 只在这里接住事件，转手交给 `group._moveFrom()`。
 * 没有组时方向键什么也不做 —— 而不是"按一下就自己动"，那会让一个
 * 独立摆放的单选框表现得像个滑块。
 *
 * ── roving tabindex（一个容易被忽略但很要紧的细节）──────────────────────
 * 一组单选框里，Tab 键应该**只停在选中的那一个**上，方向键在组内穿梭。
 * 若每个单选框都可 Tab 聚焦，键盘用户要从第一项按 N 次才能走到别的控件。
 * 于是 `activeFocusOnTab` 由组回答（`group._isTabStop()`），没有组时恒真。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    property string text: ""
    property string variant: "default"

    /** 这个选项代表的值。组按它比对 `group.value` 决定谁被选中。 */
    property var value: undefined

    /** 所属的组（由 QSkinRadioGroup 在同步时**推**下来，不用自己注册）。
     *  var 而非具体类型：插槽/组契约是鸭子类型，声明成具体组件会与
     *  QSkinRadioGroup 形成模块内互相引用。 */
    property var group: null

    property bool checked: false

    property bool hovered: false
    property bool pressed: false

    /* 让 label 插槽左对齐 —— 单选/复选的文字在控件右边，
     * 居中的话标签会比圈还窄。插槽读宿主状态是契约允许的
     * （见 Slots.qml 契约第 2 条）。 */
    readonly property int labelAlignment: Text.AlignLeft

    signal clicked()
    signal toggled()
    /** 请求组把自己选上。组不在场时没人听，控件自身仍然会勾上。 */
    signal selectRequested()

    implicitWidth:  content.implicitWidth
    implicitHeight: Math.max(Theme.size.controlSm, content.implicitHeight)

    width:  implicitWidth
    height: implicitHeight

    /* 组内的 roving tabindex；没有组时恒可 Tab 到 */
    activeFocusOnTab: root.group === null ? true : root.group._isTabStop(root)

    Accessible.role:          Accessible.RadioButton
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

        Loader {
            id: indicatorLoader
            sourceComponent: Slots.radioIndicator

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
    /* 方向键：**先移动焦点、再选中**（WAI-ARIA 的单选组约定 ——
     * 方向键在组内即选即走，与 Tab 键"只走不选"分工不同）。 */
    Keys.onUpPressed:    function(event) { event.accepted = true; root._move(-1) }
    Keys.onDownPressed:  function(event) { event.accepted = true; root._move(1) }
    Keys.onLeftPressed:  function(event) { event.accepted = true; root._move(-1) }
    Keys.onRightPressed: function(event) { event.accepted = true; root._move(1) }

    /* ══════════════════════ 内部 ══════════════════════ */

    /* 向组报到 / 离组。**报到时组会立刻把 checked 推回来**，
     * 所以"初始选中项"不需要任何额外代码 —— 组知道 value，就够了。
     * 用 Component.onCompleted 而不是 onGroupChanged：声明式挂靠时
     * group 在构造期就已就位，而动态改 group 的用法会让"谁在管我"
     * 变成两处状态，不如不支持。 */
    Component.onCompleted: if (root.group !== null) root.group._register(root)
    Component.onDestruction: if (root.group !== null) root.group._unregister(root)

    function _activate() {
        if (!root.enabled) return
        /* 已经选中的项再点一次：**不取消**。这是单选框与复选框最关键
         * 的体感差别 —— 允许取消的话，用户会得到一个"什么都没选"的
         * 单选组，而组的数据契约通常要求必有一项。 */
        if (root.checked) {
            root.clicked()
            return
        }
        if (root.group !== null) {
            root.selectRequested()
            root.group._selectFrom(root)
        } else {
            root.checked = true
        }
        root.toggled()
        root.clicked()
    }

    function _move(delta) {
        if (root.group === null) return
        root.group._moveFrom(root, delta)
    }
}
