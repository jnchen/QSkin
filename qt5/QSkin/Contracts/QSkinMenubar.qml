/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinMenubar
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 应用菜单条 —— 桌面程序顶上那一排「文件 / 编辑 / 视图」，点开各自掉一串。
 * 参照 shadcn 的 `Menubar`。
 *
 * ── 为什么不并进 `QSkinMenu`（COVERAGE.md 第七节「M25 五项裁决」之一）────
 * `QSkinMenu` 是**竖排浮层内容**：读 `model`、上下键导航、有分隔线 / 禁用项 /
 * 危险项。它**没有**水平模式、没有"一排标题"、没有"开着的时候悬停换一栏"。
 * 两件事共用的其实只有"菜单行长什么样"，而那部分**正是复用**的 ——
 * 本件内部就是一个 `QSkinMenu`（见下），一行行语义都没有重写。
 *
 * ── 一个面板，不是每个标题一个 ────────────────────────────────────────
 * 天真做法是每个标题各配一个 QSkinMenu。那样"开着的时候把鼠标移到隔壁标题"
 * 会先关一个再开一个，中间空一帧（真实桌面上看起来就是闪一下）。
 * 这里只放**一个** QSkinMenu：切换标题时只换 `model` 与位置，
 * Popup 始终开着 —— 于是没有那一帧。
 *
 * ── 已知边界（写出来，不假装没有）────────────────────────────────────
 * · 子菜单**只有一级**。`QSkinMenu` 的 `model` 是平的（分隔线 / 禁用 / 危险，
 *   无嵌套），所以 shadcn 的 `MenubarSub`（嵌套子菜单）、
 *   `MenubarCheckboxItem` / `MenubarRadioGroup`（勾选项）、
 *   `MenubarShortcut`（右侧快捷键提示）本批**未做**。
 *   前三项要动 `QSkinMenu` 的模型语义（那是它的契约扩张，牵动 Dropdown /
 *   ContextMenu 两条既有路径），本批不顺手改，如实记在这里。
 * · 左右键只在**焦点在条上**时换标题。菜单打开后焦点进了菜单的列表，
 *   而 `QSkinMenu` 不转发左右键 —— 要补得给它加一对信号。当前行为：
 *   菜单开着时左右键无响应，Esc 关闭后焦点回到条上，再左右键可用。
 * · 面板只在下方展开（与 QSkinDropdown 同一取舍，理由见那份文件头）。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /**
     * 每一栏：`{ text, items: [...], enabled }`
     * `items` 的格式与 `QSkinMenu.model` **完全一致**（本件不重定义它）：
     *     字符串 / { text, danger, enabled } / "separator"
     */
    property var model: []

    /* ══════════════════════ 外观 ══════════════════════ */

    property int gap: Theme.space.xxs
    property int itemHeight: Theme.size.controlMd
    property int padding: Theme.space.xxs

    /** 面板宽度。菜单条目宽窄不一，跟随内容会在换栏时抖动，所以定宽 */
    property int panelWidth: 200
    property int maxVisibleRows: 12

    /** 已有菜单打开着时，鼠标滑到别的标题上是否切换（真实桌面的行为） */
    property bool switchOnHover: true

    /* ══════════════════════ 状态 ══════════════════════ */

    /** 当前打开的是第几栏。-1 = 都关着。**只有这一个真相源** */
    property int activeIndex: -1

    readonly property bool opened: root.activeIndex >= 0

    readonly property int count: root.model ? root.model.length : 0

    /* ══════════════════════ 信号 ══════════════════════ */

    /** 用户触发了第 menu 栏的第 item 项 */
    signal triggered(int menu, int item)

    /* ══════════════════════ 接口 ══════════════════════ */

    function openAt(i) {
        if (i < 0 || i >= root.count) return
        if (!root._enabledAt(i)) return

        root.activeIndex = i
        /* 换栏时清掉旧的高亮 —— 菜单的 onOpened 只在第一次触发，
         * 后面几次切换走的是"同一个 Popup 换 model"这条路。 */
        ddMenu.highlightIndex = -1
        ddMenu.model = root._itemsAt(i)
        ddMenu.panelWidth = root.panelWidth
        ddMenu.maxVisibleRows = root.maxVisibleRows
        ddMenu.openAt(root.titleX(i), root.barHeight + root.padding)
    }

    function close() {
        ddMenu.close()
        root.activeIndex = -1
    }

    function toggleAt(i) {
        if (root.activeIndex === i) root.close()
        else root.openAt(i)
    }

    /**
     * 第 i 个标题的 x（本件坐标）。**纯计算**，不读布局结果 ——
     * 于是"面板左缘对齐标题左缘"是一条可以被像素判据写的等式，
     * 而不依赖"布局跑完了没有"（本项目反复撞的那条时序假设）。
     */
    function titleX(i) {
        var x = root.padding
        for (var k = 0; k < i; ++k) {
            var it = titleRep.itemAt(k)
            x += (it ? it.implicitWidth : 0) + root.gap
        }
        return x
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    function _menuAt(i)   { return root.model ? root.model[i] : null }
    function _itemsAt(i)  {
        var m = root._menuAt(i)
        return (m && m.items) ? m.items : []
    }
    function _textAt(i)   {
        var m = root._menuAt(i)
        return (m && m.text !== undefined) ? String(m.text) : ""
    }
    function _enabledAt(i) {
        var m = root._menuAt(i)
        return !(m && m.enabled === false)
    }

    readonly property int barHeight: root.itemHeight + root.padding * 2

    /* ══════════════════════ 几何 ══════════════════════ */

    implicitWidth:  bar.implicitWidth
    implicitHeight: root.barHeight

    /* ══════════════════════ 一排标题 ══════════════════════ */

    QSkinRow {
        id: bar

        x: root.padding
        y: root.padding
        /* 内容行的高度 = `itemHeight` —— 条高（`barHeight`）减掉上下内边距
         * 之后剩下的那一格。**这一条是必需的**，不是修饰：
         *
         * 子项（标题按钮）的隐式高来自 `size: "sm"`，而 `sm` 是
         * `Theme.size.controlSm`（tdesign 24），比 `itemHeight`（32）矮 8px。
         * 不把行高钉住，`barHeight`（36）与"条里真正占的高度"（2+24+2=28）
         * 就对不上 —— 文字墨的竖直中心比条中线高 4px。
         *
         * 直写 `height` 在这里是有效的：`QSkinRow` 内部是 `RowLayout`
         * （`anchors.fill` 于 root），行高定了它跟着定，子项再按
         * `align: "center"` 在行里垂直居中。`QSkinRow.qml` 文件头说"撑满请写
         * `fill: true`" 指的是**宽度**（那是 `Layout.fillWidth` 的语义，
         * 因为放自身尺寸用的是 `implicitWidth`）；高度这里可以直写。 */
        height: root.itemHeight
        gap: root.gap
        align: "center"

        Repeater {
            id: titleRep

            model: root.count

            /* 代理里要引用外层 root / Theme —— 非限定访问，局部关掉。
             * 注释首行不要以 qmllint 开头。 */
            // qmllint disable unqualified
            delegate: QSkinButton {
                required property int index

                /* 一栏的高度**不在这里定** —— 见 `bar.height` 那一段。
                 * 原先这里只有 `size: "sm"`，而 `sm` 的隐式高是
                 * `Theme.size.controlSm`（tdesign 24），比 `itemHeight`
                 * （32）矮 8px；条高却按 `itemHeight` 算 —— 于是文字墨的
                 * 竖直中心比条中线高 4px。那是**渲染侧**量出来的
                 * （`.cache/_verify_m25px.py` 的 [P7]），属性侧全绿。 */
                text: root._textAt(index)
                size: "sm"
                variant: "ghost"
                checkable: true
                checked: root.activeIndex === index
                enabled: root._enabledAt(index)
                accessibleName: root._textAt(index)

                onClicked: root.toggleAt(index)

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    enabled: root.switchOnHover && root.opened

                    onContainsMouseChanged: {
                        if (containsMouse && root.activeIndex !== index)
                            root.openAt(index)
                    }
                }
            }
            // qmllint enable unqualified
        }
    }

    /* ══════════════════════ 那**一个**面板 ══════════════════════ */

    QSkinMenu {
        id: ddMenu

        onTriggered: function(index) { root.triggered(root.activeIndex, index) }
        onClosed: {
            root.activeIndex = -1
            bar.forceActiveFocus()
        }
    }

    /* ══════════════════════ 键盘 ══════════════════════
     * 焦点在条上时：左右换栏、下键展开、Esc 关闭。
     * 菜单打开后焦点进菜单列表（由 QSkinMenu 的 onOpened 完成），
     * 那时左右键无响应 —— 见文件头"已知边界"。 */

    activeFocusOnTab: true
    focus: false

    Keys.onLeftPressed:  root._step(-1)
    Keys.onRightPressed: root._step(1)
    Keys.onDownPressed:  if (!root.opened) root.openAt(0)
    Keys.onEscapePressed: root.close()

    function _step(delta) {
        if (root.count === 0) return
        var cur = root.activeIndex >= 0 ? root.activeIndex : 0
        var next = root.activeIndex < 0
                   ? (delta > 0 ? 0 : root.count - 1)
                   : Math.max(0, Math.min(root.count - 1, cur + delta))
        if (root.opened) root.openAt(next)
        else root.activeIndex = next
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: root.activeFocus ? Theme.size.focusRing : 0
        border.color: Theme.color.focus
        radius: Theme.radius.sm
    }

    Accessible.role: Accessible.MenuBar
    Accessible.name: qsTr("菜单条")
}
