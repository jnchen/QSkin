/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinSelect
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 下拉选择框。这是契约层里第一个**带浮层**的控件，也是浮层插槽的验证场。
 *
 * ── 分工 ─────────────────────────────────────────────────────────────
 *
 *   这个文件负责（换肤一行不动）：
 *     Popup 的开合与翻转、model 解析、当前项、上下键导航、
 *     回车选中 / Esc 取消、Accessible.ComboBox 语义
 *
 *   插槽负责（换肤整个替换）：
 *     Slots.inputBackground  输入框底板（与 QSkinInput 共用同一个插槽）
 *     Slots.selectOverlay    下拉面板外壳
 *     Slots.label            当前项文字与选项行文字
 *
 * ── 关键手法：控件持有 ListView，插槽持有外壳 ───────────────────────────
 * 列表是行为，不能丢给主题重写（否则键盘导航要写 N 遍）。
 * 所以 ListView 声明在这里，通过 content 属性注入 overlay 插槽，
 * 由插槽把它摆进面板内容区。详见 slots/BasicSelectOverlay.qml。
 *
 * ── 选项行也走 label 插槽 ─────────────────────────────────────────────
 * 默认 delegate 让每一行"伪装成控件"：暴露 text / variant / labelAlignment
 * 三个属性，于是 Slots.label 原样可用。主题改字号字重，选项行跟着变，
 * 不需要碰 delegate 的任何一行。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 数字（表示条数）、字符串数组、对象数组，或 ListModel */
    property var  model: null
    property int  currentIndex: -1

    /** model 是对象数组时，取哪个字段显示；为空则整体转字符串 */
    property string textRole: ""

    property string placeholderText: ""
    property bool   error: false

    /* ══════════════════ 外观（供插槽读取） ══════════════════
     * maxVisibleRows / rowHeight 由 overlay 插槽读取来决定面板高度，
     * 因为"一个面板最多露几行"是外观而不是行为。 */

    property int maxVisibleRows: 6
    property int rowHeight: Theme.size.controlMd
    property int padding: Theme.space.md

    property string variant: "default"
    property bool   hovered: false
    property bool   pressed: false

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 用户选中了某一项 */
    signal activated(int index)

    /** 可替换的选项行；不指定就用下面 defaultDelegate */
    property Component delegate: defaultDelegate

    readonly property int  count:  listView.count
    readonly property bool opened: popup.opened

    /* 给 Slots.label 读的三个属性 —— 与 QSkinButton 保持同一套鸭子类型接口 */
    readonly property string text: root.currentIndex >= 0 ? root._textOf(root.currentIndex) : ""
    readonly property string variantName: "default"
    readonly property int    labelAlignment: Text.AlignLeft

    /* ══════════════════════ 尺寸 ══════════════════════ */

    implicitWidth:  200
    implicitHeight: Theme.size.controlMd

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true

    /* ══════════════════════ 无障碍 ══════════════════════ */

    Accessible.role:      Accessible.ComboBox
    Accessible.name:      root.text !== "" ? root.text : root.placeholderText
    Accessible.editable:  false
    Accessible.onPressAction: root._toggle()

    /* ══════════════════════ 插槽：底板 ══════════════════════ */

    Loader {
        id: backgroundLoader

        anchors.fill: parent
        sourceComponent: Slots.inputBackground

        Binding {
            target: backgroundLoader.item
            property: "control"
            value: root
            when: backgroundLoader.item !== null
        }
    }

    /* ══════════════════════ 当前项文字 ══════════════════════ */

    Item {
        anchors.fill: parent
        anchors.leftMargin:  root.padding
        anchors.rightMargin: root.padding + caret.width + Theme.space.sm

        Loader {
            id: textLoader

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            sourceComponent: Slots.label

            Binding {
                target: textLoader.item
                property: "control"
                value: root
                when: textLoader.item !== null
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text === "" && root.placeholderText !== ""

            text:  root.placeholderText
            font.family:    Theme.font.family
            font.pixelSize: Theme.font.sm
            color:          Theme.color.fgMuted
            elide:          Text.ElideRight
            renderType:     Text.NativeRendering
        }
    }

    /* ══════════════════════ 展开指示 ══════════════════════
     * 走 chevronIndicator 插槽 —— 也就是 indicator 家族里「展开箭头」
     * 那一格。这里以前自绘了一个三角，并在注释里论证过"为什么不能打
     * 字符 ▾"。那条论证是对的，但只走到一半：项目里还有 QSkinTable 的
     * 树形箭头、QSkinDatePicker 的翻月、QSkinPagination 的上下页，四处各
     * 自为政。收进插槽之后，四套主题才有机会用同一种图标语言回答
     * "箭头长什么样"。
     *
     * **展开语义留在控件里**：收起 → 朝下，展开 → 朝上（180° 翻转，
     * 与改造前 `rotation: opened ? 180 : 0` 的观感一致）。
     * 插槽只回答"朝下的箭头长什么样"，不解释 opened ——
     * 状态机是契约层的职责（Slots.qml 契约第 2 条）。 */

    Loader {
        id: caret

        anchors.right:          parent.right
        anchors.rightMargin:    root.padding
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: Slots.chevronIndicator

        Binding {
            target: caret.item
            property: "control"
            value: caretProxy
            when: caret.item !== null
        }
    }

    QtObject {
        id: caretProxy

        readonly property string direction: root.opened ? "up" : "down"
        readonly property bool enabled: root.enabled
    }

    FocusRing { control: root }

    /* ══════════════════════ 列表（行为，不属于插槽） ══════════════════════
     * visible: false 等着被 overlay 插槽 reparent 进面板。
     * 在那之前显示出来的话，会画在输入框内部。 */

    ListView {
        id: listView

        visible: false
        anchors.fill: parent        // reparent 之后指向 overlay 的内容区
        clip: true
        focus: true

        model: root.model
        delegate: root.delegate
        currentIndex: root.currentIndex
        highlightMoveDuration: 0
        keyNavigationEnabled: false   // 键盘我们自己处理，见下方 Keys

        Keys.onUpPressed:      root._move(-1)
        Keys.onDownPressed:    root._move(1)

        /* Keys 没有 onHomePressed / onEndPressed 这两个信号，
         * 只能在通用的 onPressed 里按 key 判断。 */
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Home) {
                event.accepted = true
                root._moveTo(0)
            } else if (event.key === Qt.Key_End) {
                event.accepted = true
                root._moveTo(root.count - 1)
            }
        }
        Keys.onReturnPressed:  root._pick(listView.currentIndex)
        Keys.onEnterPressed:   root._pick(listView.currentIndex)
        Keys.onSpacePressed: function(event) {
            event.accepted = true
            root._pick(listView.currentIndex)
        }
        Keys.onEscapePressed: function(event) {
            event.accepted = true
            popup.close()
        }
    }

    /* ══════════════════════ 浮层 ══════════════════════ */

    /* 浮层上报的阴影外扩量（M4 契约回收）。Basic 插槽为 0，
     * TDesign/Ant 为 3、Arco 为 2、shadcn 为 4 —— Popup 用它把自己
     * 放大 extender*2，主题画的阴影才不会被浮层边界裁掉。
     * 经 var 中转：extender 是插槽契约的鸭子类型属性，Loader.item
     * 的静态类型是 QObject，直接点号会被 qmllint 误报。 */
    readonly property var  overlayItem: overlayLoader.item
    readonly property real overlayExtender: root.overlayItem !== null
        && root.overlayItem.extender !== undefined ? root.overlayItem.extender : 0

    Popup {
        id: popup

        /* 下方空间不够、上方更宽裕时向上弹。
         * 不做翻转的话，靠窗口底部的下拉框会直接弹出可视区。
         * y 以「面板本体」为基准换算：popup 的边界比面板大一圈 extender。 */
        y: root.flipUp ? (root.overlayExtender - popup.height - Theme.space.xs)
                       : (root.height + Theme.space.xs - root.overlayExtender)

        width: root.width + root.overlayExtender * 2
        padding: root.overlayExtender

        /* 面板外观完全由 overlay 插槽负责，这里不放任何东西 */
        background: Item {}

        contentItem: Loader {
            id: overlayLoader

            sourceComponent: Slots.selectOverlay

            Binding {
                target: overlayLoader.item
                property: "control"
                value: root
                when: overlayLoader.item !== null
            }
            Binding {
                target: overlayLoader.item
                property: "content"
                value: listView
                when: overlayLoader.item !== null
            }
        }

        contentWidth: root.width

        /* overlay 的 implicitHeight 在首帧之前可能是 0（Qt Quick Layouts
         * 把尺寸重算推迟到 polish 阶段，见 tests/smoke_sizes.qml 的说明），
         * 所以兜一个最小高度，避免第一次展开时面板塌成一条。 */
        contentHeight: Math.max(overlayLoader.implicitHeight,
                                root.rowHeight + Theme.space.xs * 2)

        onOpened: {
            listView.positionViewAtIndex(listView.currentIndex, ListView.Beginning)
            listView.forceActiveFocus()
        }
        onClosed: root.pressed = false
    }

    readonly property bool flipUp: {
        var win = Window.window
        if (!win) return false
        var gy    = root.mapToItem(win.contentItem, 0, 0).y
        var below = win.height - (gy + root.height)
        return below < popup.height + Theme.space.xs && gy > below
    }

    /* ══════════════════════ 默认选项行 ══════════════════════ */

    /* 下面这段 delegate 引用了外层 id（root / listView / Slots）。
     * inline Component 内部它们解析不到，会被报成 Unqualified access，
     * 但 QML 运行时是沿着上下文链查找的，这些引用完全正确 ——
     * 那是静态检查器的局限，不是代码问题，所以只在这里局部关闭。
     *
     * 注意：注释首行不要以 qmllint 开头，否则它会被当成指令本身来解析。
     * 也不要改用 .qmllint.ini 全局降级，那会把真正的问题一起盖掉。 */
    // qmllint disable unqualified

    Component {
        id: defaultDelegate

        Rectangle {
            id: row

            width:  listView.width
            height: root.rowHeight
            radius: Theme.radius.sm

            required property int index

            /* 伪装成一个"控件"，好让 Slots.label 原样复用 */
            readonly property string text: root._textOf(row.index)
            readonly property string variant: "default"
            readonly property int    labelAlignment: Text.AlignLeft

            color: rowMouse.containsMouse ? Theme.color.bgSunken
                                          : (listView.currentIndex === row.index
                                             ? Theme.color.brandSubtle : "transparent")

            Loader {
                id: rowLabel

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter

                sourceComponent: Slots.label

                Binding {
                    target: rowLabel.item
                    property: "control"
                    value: row
                    when: rowLabel.item !== null
                }
            }

            MouseArea {
                id: rowMouse

                anchors.fill: parent
                hoverEnabled: true
                onClicked: function(mouse) { root._pick(row.index) }
            }
        }
    }

    // qmllint enable unqualified

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
        onReleased: root.pressed = false

        onPressed: function(mouse) {
            if (mouse.button !== Qt.LeftButton) return
            root.pressed = true
            root.forceActiveFocus()
        }
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) root._toggle()
        }
    }

    /* 关闭态的键盘：上下键直接改当前项（Windows 习惯），
     * 回车 / 空格 / Alt+↓ / F4 展开。 */
    Keys.onUpPressed:      root._move(-1)
    Keys.onDownPressed:    root._move(1)

    Keys.onReturnPressed:  root._toggle()
    Keys.onEnterPressed:   root._toggle()
    Keys.onSpacePressed: function(event) {
        event.accepted = true
        root._toggle()
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    /** 取第 i 项的显示文本。兼容：数字 / 字符串数组 / 对象数组 / ListModel */
    function _textOf(i) {
        var m = root.model
        if (m === null || m === undefined) return ""
        if (typeof m === "number") return String(i)

        var it = (typeof m.get === "function") ? m.get(i) : m[i]
        if (it === null || it === undefined) return ""

        if (root.textRole !== "" && typeof it === "object") {
            var v = it[root.textRole]
            return v === undefined || v === null ? "" : String(v)
        }
        return String(it)
    }

    function _toggle() {
        if (!root.enabled) return
        if (popup.opened) popup.close()
        else              popup.open()
    }

    /** 移动高亮（不提交）。dir 为 -1 / +1 */
    function _move(dir) {
        if (!root.enabled) return
        var next = listView.currentIndex + dir
        if (next < 0 || next >= root.count) return
        listView.currentIndex = next
    }

    function _moveTo(i) {
        if (!root.enabled) return
        if (i < 0 || i >= root.count) return
        listView.currentIndex = i
    }

    /** 提交选择 */
    function _pick(i) {
        if (i < 0 || i >= root.count) return
        root.currentIndex = i
        popup.close()
        root.forceActiveFocus()
        root.activated(i)
    }
}
