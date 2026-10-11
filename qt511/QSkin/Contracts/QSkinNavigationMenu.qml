/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinNavigationMenu
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 站点导航 —— 一排导航项，悬停/点击展开**任意内容**的面板（一格格链接、
 * 卡片、图文块都行）。参照 shadcn 的 `NavigationMenu`。
 *
 * ── 它与 QSkinMenubar 到底差在哪（这是两个控件而不是一个预设的理由）────
 *     QSkinMenubar        面板里是**菜单行**（由 `QSkinMenu` 渲染，`model` 驱动）
 *     QSkinNavigationMenu 面板里是**宿主给的任意内容**（一个 Component）
 * 触发器形态也不同：前者是应用菜名的"按一下打开"，后者是站点链接的
 * "滑过去就展开"。共用的只有"一排触发器 + 同刻只有一个面板"这条骨架，
 * 而那部分在这里只有 5 行（面板贴当前触发器左缘展开）—— 不是一份
 * 值得抽出来的定位算法（对比 QSkinPopover 的锚定 + 翻转 + 边界夹取，
 * 那才是真的有一份可共享的实现）。
 *
 * ── 一个面板、内容换，不是每项一个面板 ────────────────────────────────
 * 与 QSkinMenubar 同一条理由：滑过一个又一个触发器的过程中，
 * "关一个 + 开一个"会在中间留一帧空白，真实观感是闪。这里只有一个
 * Popup，切换时只换里面加载的 Component 与位置。
 *
 * ── 排他走 OverlayStack ───────────────────────────────────────────────
 * 本件的面板登记在 `QSkin.Foundation.OverlayStack` 里（M21 那份"同一时刻
 * 只能有一个排他浮层"的唯一实现）—— 于是打开一个 Popover 会把它顶掉，
 * 反之亦然。`QSkinMenu` 不走这条路（它是 `Popup` 直开），所以本件**不**
 * 靠 QSkinMenu 拿排他。
 *
 * ── hover 的延时是**可关的**，这是确定性要求 ─────────────────────────
 * `openOnHover` 缺省 true、`delayDuration` 缺省 200（shadcn 同值）。
 * 但判定"哪个是打开的"只读 `activeIndex` 这一个显式状态；
 * 悬停只是**触发它变化**的一种方式。所以测试既可以直接写 `activeIndex`，
 * 也可以把 `delayDuration` 设成 0 后走 hover —— 两条路到达同一个状态，
 * 不需要"等计时器"（与 `QSkinBackTop.animated` 同一种处置）。
 *
 * ── 已知边界（写出来，不假装没有）────────────────────────────────────
 * · shadcn 的 `NavigationMenuIndicator`（面板顶部指向当前触发器的小三角）
 *   **未做**：它要跨出面板边界绘制，而面板是 Popup（自成窗口坐标），
 *   跨边界画需要一个不属于本件的浮层。没有消费者时不做。
 * · 纯链接项（没有 `content`）点了只发 `activated(index)`，**不导航** ——
 *   路由是宿主的（本件不知道 URL 是什么，也刻意不引 `href` 那套）。
 * · 面板只在下方展开（与 QSkinDropdown / QSkinMenubar 同一取舍）。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /**
     * 导航项。每项：
     *   { text, content: Component }   有面板的触发器
     *   { text }                       纯链接（点了只发信号）
     *   { text, enabled }              禁用
     */
    property var model: []

    /* ══════════════════════ 外观 ══════════════════════ */

    property int gap: Theme.space.xs
    property int itemHeight: Theme.size.controlMd
    property int padding: Theme.space.xxs

    /** 面板宽度。<= 0 表示由内容自己撑 */
    property int panelWidth: 320

    /** 面板内边距与内容间距（传给承载内容的 QSkinColumn） */
    property int panelPadding: Theme.space.md
    property int panelGap: Theme.space.sm

    /** 面板与触发器之间的缝 */
    property int panelOffset: Theme.space.xs

    /* ══════════════════════ 行为 ══════════════════════ */

    property bool openOnHover: true

    /** 悬停多久才展开（毫秒）。设 0 = 立刻 —— 抓图与测试走这条 */
    property int delayDuration: 200

    /* ══════════════════════ 状态 ══════════════════════ */

    /** 当前展开的是第几项。-1 = 都关着。**只有这一个真相源** */
    property int activeIndex: -1

    readonly property bool opened: root.activeIndex >= 0

    readonly property int count: root.model ? root.model.length : 0

    /* ══════════════════════ 信号 ══════════════════════ */

    /** 用户点了第 index 项（有面板的项也会发 —— "点开"与"点进"是两件事） */
    signal activated(int index)

    /* ══════════════════════ 接口 ══════════════════════ */

    function open(index) {
        if (index < 0 || index >= root.count) return
        if (!root._enabledAt(index)) return
        if (!root._hasPanel(index)) return

        root.activeIndex = index
        popup.x = root.triggerX(index)
        popup.y = root.height + root.panelOffset
        if (!popup.opened) popup.open()
    }

    function close() {
        popup.close()
        root.activeIndex = -1
    }

    function toggle(index) {
        if (root.activeIndex === index) root.close()
        else root.open(index)
    }

    /** 第 i 个触发器的 x（本件坐标）。**纯计算**，不读布局结果 —— 见 QSkinMenubar */
    function triggerX(i) {
        var x = root.padding
        for (var k = 0; k < i; ++k) {
            var it = triggerRep.itemAt(k)
            x += (it ? it.implicitWidth : 0) + root.gap
        }
        return x
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    function _itemAt(i)    { return root.model ? root.model[i] : null }
    function _textAt(i) {
        var it = root._itemAt(i)
        if (typeof it === "string") return it
        return (it && it.text !== undefined) ? String(it.text) : ""
    }
    function _enabledAt(i) {
        var it = root._itemAt(i)
        return !(it && it.enabled === false)
    }
    function _hasPanel(i) {
        var it = root._itemAt(i)
        return !!(it && it.content !== undefined && it.content !== null)
    }

    readonly property int barHeight: root.itemHeight + root.padding * 2

    /* ══════════════════════ 几何 ══════════════════════ */

    implicitWidth:  bar.implicitWidth
    implicitHeight: root.barHeight

    /* 悬停意图计时器：只有它在跑，"延时"才存在 */
    Timer {
        id: hoverTimer
        interval: Math.max(0, root.delayDuration)
        repeat: false
        onTriggered: root.open(root.pendingIndex)
    }

    property int pendingIndex: -1

    /* ══════════════════════ 一排触发器 ══════════════════════ */

    QSkinRow {
        id: bar

        x: root.padding
        y: root.padding
        /* 内容行的高度 = `itemHeight`（条高减掉上下内边距那一格）。
         * 理由与 `QSkinMenubar` 的 `bar.height` 完全一致 —— 不钉住行高，
         * `barHeight` 与条里真正占的高度就差 8px（子项 `size: "sm"`
         * 的隐式高是 `controlSm`），文字墨中心会偏上 4px。 */
        height: root.itemHeight
        gap: root.gap
        align: "center"

        Repeater {
            id: triggerRep

            model: root.count

            // qmllint disable unqualified
            delegate: QSkinButton {
                property int index

                /* 一栏的高度**不在这里定** —— 见 `bar.height` 那一段。
                 * 理由与 `QSkinMenubar` 那一处一字不差：`size: "sm"` 的隐式高
                 * 是 `controlSm`（24），比 `itemHeight`（32）矮 8px，而条高
                 * 按 `itemHeight` 算 —— 文字墨中心比条中线高 4px。
                 * 像素门禁的 [P7] 量的就是这一条。 */
                text: root._textAt(index)
                size: "sm"
                variant: "ghost"
                checkable: true
                checked: root.activeIndex === index
                enabled: root._enabledAt(index)
                /* 有面板的项挂一个方向箭头 —— "滑过去会掉出东西来"的唯一提示。
                 * 纯链接项不给箭头（那才是它"点了就走"的暗示）。 */
                icon: root._hasPanel(index) ? Slots.chevronIndicator : null
                iconDirection: "down"
                accessibleName: root._textAt(index)

                onClicked: {
                    root.activated(index)
                    if (root._hasPanel(index)) root.toggle(index)
                    else root.close()
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    enabled: root.openOnHover && root.enabled

                    onContainsMouseChanged: {
                        if (containsMouse) {
                            if (root._hasPanel(index)) {
                                root.pendingIndex = index
                                /* 已展开时**立刻**换 —— 再等一次 200ms
                                 * 会让"滑过一排"变成一串卡顿。 */
                                if (root.opened) root.open(index)
                                else hoverTimer.restart()
                            } else {
                                root.close()
                            }
                        } else if (!containsMouse && root.pendingIndex === index) {
                            hoverTimer.stop()
                            root.pendingIndex = -1
                        }
                    }
                }
            }
            // qmllint enable unqualified
        }
    }

    /* ══════════════════════ 面板 ══════════════════════ */

    /* 承载面板内容的项。声明在这里，由插槽 reparent 进它自己的内容区
     * （BasicSelectOverlay 的契约，见那份文件头）。 */
    QSkinColumn {
        id: panelContent

        visible: false
        /* 只跟宽度，**不跟高度** —— 跟了就会与 popup 的高度成环
         * （shell.implicitHeight ← control.contentHeight ← 本项 implicitHeight
         *  ← 父高 ← shell.implicitHeight）。 */
        width: parent ? parent.width : 0

        padding: root.panelPadding
        gap: root.panelGap

        Loader {
            id: panelLoader

            Layout.fillWidth: true
            sourceComponent: root.activeIndex >= 0 ? root._contentAt(root.activeIndex) : null
        }
    }

    function _contentAt(i) {
        var it = root._itemAt(i)
        return (it && it.content !== undefined) ? it.content : null
    }

    Popup {
        id: popup

        padding: 0
        background: Item {}

        onOpened: {
            if (root.activeIndex >= 0) OverlayStack.request(root)
        }
        onClosed: {
            OverlayStack.drop(root)
            root.activeIndex = -1
            bar.forceActiveFocus()
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
                value: panelContent
                when: overlayLoader.item !== null
            }
        }

        width: root.panelWidth > 0 ? root.panelWidth : panelContent.implicitWidth
    }

    /* 外壳读这几项（契约：插槽可以读宿主状态）。
     * `contentHeight` 报**精确**值 —— 面板里是任意内容，行数 × 行高估不出来。
     * `width` 是**必须报**的一项：外壳的 `implicitWidth` 直接就是 `control.width`，
     * 少了它那一条赋值会失败（`Unable to assign [undefined] to double`）。
     * 实测那次失败**保留**了上一次的值（200），所以画面上看不出来、只有警告 ——
     * 于是它躲过了 M25 的收口，也在 `test.sh` 的累积日志里堆了 658 行。
     * 其余六个共用 selectOverlay 的宿主（Menu / AutoComplete / Cascader /
     * ColorPicker / Mentions / TreeSelect）都报了 `width`，本件是唯一的例外。
     * 报 `popup.width` 不会成环：它取的是 `panelWidth` 或 `panelContent.implicitWidth`，
     * 两条都不经过外壳（`panelContent` 的宽度只跟父宽，见上）。 */
    QtObject {
        id: fakeControl

        readonly property int  count:          root.count
        readonly property int  maxVisibleRows: root.count
        readonly property int  rowHeight:      root.itemHeight
        readonly property real contentHeight:  panelContent.implicitHeight
        readonly property real width:          popup.width
    }

    /* ══════════════════════ 键盘 ══════════════════════ */

    activeFocusOnTab: true
    focus: false

    Keys.onLeftPressed:  root._step(-1)
    Keys.onRightPressed: root._step(1)
    Keys.onDownPressed:  if (!root.opened && root.count > 0) root.open(0)
    Keys.onEscapePressed: root.close()

    function _step(delta) {
        if (root.count === 0) return
        var next = root.activeIndex < 0
                   ? (delta > 0 ? 0 : root.count - 1)
                   : Math.max(0, Math.min(root.count - 1, root.activeIndex + delta))
        if (root.opened) root.open(next)
        else root.activeIndex = next
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: root.activeFocus ? Theme.size.focusRing : 0
        border.color: Theme.color.focus
        radius: Theme.radius.sm
    }

    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("站点导航")
}
