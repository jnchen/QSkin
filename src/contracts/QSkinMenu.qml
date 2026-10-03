/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinMenu
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 菜单（右键菜单 / 下拉动作菜单）。M4 新增。
 *
 * ── 为什么菜单外壳直接复用 Slots.selectOverlay ──────────────────────────
 * M3 的结论之一：selectOverlay 实际上是「浮层面板外壳」——
 * 底色、圆角、描边、内边距、阴影。这套外观对下拉面板和菜单是同一件事
 * （四套设计系统里两者也确实长得一样），没必要让主题作者多写一份
 * menuOverlay。如果将来出现真正的差异（比如菜单需要分组标题），
 * 再拆分插槽也不迟 —— 契约层加插槽是增量改动。
 *
 * ── 分工 ─────────────────────────────────────────────────────────────
 *   本文件：model 解析（含分隔线 / 禁用项 / 危险项）、上下键导航
 *           （跳过分隔线）、回车触发、Esc 关闭、Accessible.PopupMenu
 *   插槽：  Slots.selectOverlay（面板外壳）、Slots.label（条目文字）
 *
 * 用法：
 *     QSkinMenu {
 *         model: ["复制", "粘贴", { text: "删除", danger: true }, "separator", "刷新"]
 *         onTriggered: (index) => { ... }
 *     }
 *     menu.openAt(x, y)     // 通常来自 MouseArea 的 mouse.x/y
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* 本体不可见 —— 菜单的视觉全部在 Popup 里。
     * 但必须留在场景里，Popup 才有 parent。 */
    width: 0
    height: 0

    /* ══════════════════════ 数据 ══════════════════════ */

    /**
     * 菜单项。每项可以是：
     *   字符串                      普通条目
     *   { text, danger, enabled }   危险条目（红）/ 禁用条目
     *   "separator" 或 {separator:true}  分隔线
     */
    property var model: []

    /* ══════════════════════ 外观（供插槽读取） ══════════════════════ */

    property int itemHeight: Theme.size.controlMd
    property int maxVisibleRows: 10
    property int padding: Theme.space.xs

    /** 面板本体宽度。菜单与下拉不同：条目宽窄不一，跟随内容会抖，
     * Web 端菜单也普遍定宽。 */
    property int panelWidth: 180

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 用户触发了第 index 项 */
    signal triggered(int index)

    /** 面板关掉了（选了 / 按了 Esc / 点了外面，三条路都算）。
     *
     *  这是 M25 的 `QSkinMenubar` 装出来的：它要在面板关掉时复位
     *  `activeIndex` 并把焦点还给标题条。在那之前它把这段逻辑挂在
     *  `QSkinMenu.onClosed` 上 —— 而 `QSkinMenu` 当时**没有**这个信号
     *  （`onClosed` 是 Popup 的），那个 handler 从来没跑过。
     *  qmllint 的 "no matching signal found for handler" 是唯一抓到它的东西：
     *  属性断言全绿、图也画得对（因为条本身不画开合态）。 */
    signal closed()

    readonly property bool opened: popup.opened

    function open()      { popup.open() }
    function close()     { popup.close() }

    /** 在指定位置打开（相对 parent 的坐标；右键菜单传 mouse.x/y） */
    function openAt(x, y) {
        popup.x = x
        popup.y = y
        popup.open()
    }

    /* ══════════════════════ 内部状态 ══════════════════════ */

    property int highlightIndex: -1

    /* ══════════════════════ 浮层 ══════════════════════ */

    Popup {
        id: popup

        padding: 0
        background: Item {}

        onOpened: {
            root.highlightIndex = root._firstEnabled()
            list.forceActiveFocus()
        }
        onClosed: {
            root.highlightIndex = -1
            root.closed()
        }

        contentItem: Loader {
            id: overlayLoader

            sourceComponent: Slots.selectOverlay

            Binding {
                target: overlayLoader.item
                property: "control"
                value: fakeControl
                when: overlayLoader.item !== null
            }
            Binding {
                target: overlayLoader.item
                property: "content"
                value: list
                when: overlayLoader.item !== null
            }
        }

        /* 面板宽度定宽（panelWidth）—— 跟随条目内容会在开合间抖动。
         * 注意不能依赖外壳的 implicitWidth：外壳按 control.width 取值，
         * 那样会形成 popup.width ↔ control.width 的循环引用。 */
        width: root.panelWidth

        /* 外壳读这几项来决定面板高度。
         * contentHeight 是 M5 契约扩展：菜单条目不等高（分隔线只有
         * 1px + 上下留白），旧公式「行数 × 行高」会把分隔线按整行计高，
         * 面板底部多出一段空白。现在由宿主上报精确值。 */
        QtObject {
            id: fakeControl

            readonly property int  count:          root._itemCount()
            readonly property int  maxVisibleRows: root.maxVisibleRows
            readonly property int  rowHeight:      root.itemHeight
            readonly property real contentHeight:  root._contentHeight()
            readonly property real width:          popup.width
        }

        contentWidth: width
        contentHeight: Math.max(overlayLoader.implicitHeight, root.itemHeight + Theme.space.xs * 2)
    }

    /* ══════════════════════ 列表（行为，不属于插槽） ══════════════════════ */

    ListView {
        id: list

        visible: false
        anchors.fill: parent
        clip: true
        focus: true
        interactive: root._contentHeight() > root.maxVisibleRows * root.itemHeight

        model: root.model
        delegate: menuDelegate
        highlightMoveDuration: 0
        keyNavigationEnabled: false

        currentIndex: root.highlightIndex

        Keys.onUpPressed:   root._move(-1)
        Keys.onDownPressed: root._move(1)

        Keys.onReturnPressed: root._trigger(root.highlightIndex)
        Keys.onEnterPressed:  root._trigger(root.highlightIndex)
        Keys.onEscapePressed: function(event) {
            event.accepted = true
            popup.close()
        }
    }

    /* delegate 引用了外层 id（root / list / Slots）—— 与 QSkinSelect 同款
     * qmllint 局限，局部关闭。注释首行不要以 qmllint 开头。 */
    // qmllint disable unqualified

    Component {
        id: menuDelegate

        Item {
            id: row

            required property int index

            readonly property var    item: root._itemAt(row.index)
            readonly property bool   isSeparator: root._isSeparator(row.index)
            readonly property bool   isEnabled: !isSeparator && !(item && item.enabled === false)
            readonly property bool   isDanger: !isSeparator && item && item.danger === true
            readonly property string text: isSeparator ? "" : (typeof item === "string" ? item : (item && item.text ? String(item.text) : ""))

            width:  list.width
            height: isSeparator ? 1 + Theme.space.xs * 2 : root.itemHeight

            /* 伪装成"控件"给 Slots.label 读 */
            readonly property string variant: isDanger ? "danger" : "ghost"
            property bool hovered: root.highlightIndex === row.index
            readonly property int labelAlignment: Text.AlignLeft

            opacity: isEnabled ? 1 : 0.4

            /* hover 底色（分隔线行不给） */
            Rectangle {
                anchors.fill: parent
                anchors.topMargin:    row.isSeparator ? Theme.space.xs : 0
                anchors.bottomMargin: row.isSeparator ? Theme.space.xs : 0
                radius: Theme.radius.sm
                color: Theme.color.bgSunken
                visible: row.hovered && row.isEnabled
            }

            /* 分隔线本体 */
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.space.xs
                height: 1
                color: Theme.color.border
                visible: row.isSeparator
            }

            Loader {
                id: rowLabel

                anchors.left:  parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.space.md
                anchors.rightMargin: Theme.space.md
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
                anchors.fill: parent
                hoverEnabled: true
                enabled: row.isEnabled

                onPositionChanged: root.highlightIndex = row.index
                onEntered: root.highlightIndex = row.index
                onClicked: root._trigger(row.index)
            }
        }
    }

    // qmllint enable unqualified

    /* ══════════════════════ 内部 ══════════════════════ */

    function _itemCount() {
        return root.model !== null && root.model !== undefined ? root.model.length : 0
    }

    function _itemAt(i) {
        if (i < 0 || i >= root._itemCount()) return null
        return root.model[i]
    }

    function _isSeparator(i) {
        var it = root._itemAt(i)
        if (it === null || it === undefined) return false
        if (typeof it === "string") return it === "separator"
        return it.separator === true
    }

    /** 内容精确高度：普通行 = itemHeight，分隔线行 = 1px 线 + 上下留白。
     * 经 fakeControl.contentHeight 交给浮层外壳（M5 契约扩展）。 */
    function _contentHeight() {
        var total = 0
        for (var i = 0; i < root._itemCount(); ++i)
            total += root._isSeparator(i) ? 1 + Theme.space.xs * 2 : root.itemHeight
        return total
    }

    function _firstEnabled() {
        for (var i = 0; i < root._itemCount(); ++i)
            if (!root._isSeparator(i) && !(root._itemAt(i) && root._itemAt(i).enabled === false))
                return i
        return -1
    }

    /** 移动高亮，跳过分隔线与禁用项 */
    function _move(dir) {
        var n = root._itemCount()
        var next = root.highlightIndex
        for (var step = 0; step < n; ++step) {
            next += dir
            if (next < 0) next = n - 1
            if (next >= n) next = 0
            if (!root._isSeparator(next) && !(root._itemAt(next) && root._itemAt(next).enabled === false))
                break
        }
        root.highlightIndex = next
    }

    function _trigger(i) {
        if (i < 0 || i >= root._itemCount()) return
        if (root._isSeparator(i)) return
        var it = root._itemAt(i)
        if (it && it.enabled === false) return
        popup.close()
        root.triggered(i)
    }
}
