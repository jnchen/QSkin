/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinSidebar
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 侧栏导航 —— 一列分区菜单 + 头部槽 + 底部槽 + 可折叠。
 * 参照 shadcn 的 `Sidebar`（`side` / `variant` / `collapsible` 三档折叠）。
 *
 * ── 与 QSkinLayout.sider 的关系（COVERAGE.md 第七节「M25 五项裁决」之一）──
 * `QSkinLayout.sider` 是**布局空槽**：吃任意内容 + 一个折叠宽度。它不知道
 * "项"是什么，也没有活动态。本件是**导航件**：有分组、有项、有活动态、
 * 有三档折叠语义。两者不是替代关系 —— 常见组合是
 * `QSkinLayout { sider: QSkinSidebar { … } }`，布局给地方，本件给内容。
 *
 * ── 三档折叠（`collapsible`）──────────────────────────────────────────
 *     "offcanvas"  折起来后整条**移出**视口（宽度 → 0）
 *     "icon"       折起来后收成一列图标（宽度 → iconWidth）
 *     "none"       不可折叠（`collapsed` 无效）
 * 三档的宽度都由 `currentWidth` 一个派生量给出 —— 判据读它，不读过渡中的
 * `width`（与 QSkinCollapseItem 把自然值与绘制值分开同一种处置）。
 *
 * ── 快捷键为什么默认是关的 ────────────────────────────────────────────
 * shadcn 用 `cmd/ctrl+B`，靠它的 provider 单例保证"一个进程只有一个"。
 * 本仓没有那层 provider，而一个进程里放两个侧栏就会**抢同一个快捷键**。
 * 所以 `toggleShortcut` 缺省是空串（= 不注册），要用的宿主自己填
 * `"Ctrl+B"` —— 这时"谁拥有这个键"是一个显式决定，不是碰巧。
 * 程序化开合一律走 `toggle()`。
 *
 * ── 已知边界 ─────────────────────────────────────────────────────────
 * · **不持有一棵树**。`model` 是**平的**；缩进用每项的 `level`、分区标题用
 *   `{ header: "…" }`、分割线用 `"separator"`。要做"可折叠的分组"，
 *   用 `QSkinCollapse` + `QSkinSidebarItem` 手搭 —— 硬把树逻辑拉进来会得到
 *   第二棵树的语义（本仓的树只有一份，在 `TreeUtil`）。
 * · **不自带滚动**。内容超高时由宿主放进 `QSkinScrollArea`（与 `QSkinAnchor`
 *   同一条取舍：多一个滚动宿主就多一处"谁来管 contentY"）。
 * · `collapsible: "offcanvas"` 只把宽度收到 0。shadcn 是把它平移到窗口外，
 *   两者在"侧栏贴窗口边缘"时视觉等价；贴在窗口中间时不等价 ——
 *   那种摆放没有消费者。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /**
     * 项目。每项可以是：
     *    字符串                        普通项
     *    { text, icon, badge, level,  普通项（icon 是一个 Component）
     *      enabled, expandable, expanded }
     *    { header: "文字" }            分区标题（不可点、不参与选中）
     *    "separator"                   分割线
     */
    property var model: []

    /** 当前活动项（model 下标）。-1 = 没有。
     *  **只有这一个真相源** —— 项里写 `active` 会被忽略。 */
    property int activeIndex: -1

    /* ══════════════════════ 槽 ══════════════════════ */

    property alias header: headerHost.data
    property alias footer: footerHost.data
    /** 插在 model 之前的内容（品牌块、搜索框…） */
    property alias content: contentHost.data

    /* ══════════════════════ 形状 ══════════════════════ */

    /** "left" | "right" —— 决定内边缘（贴内容的那一边）在哪 */
    property string side: "left"

    /** "sidebar" 平铺 | "floating" 浮起（带外边距与圆角）| "inset" 内嵌 */
    property string variant: "sidebar"

    /** "offcanvas" | "icon" | "none" */
    property string collapsible: "offcanvas"

    property bool collapsed: false
    property bool animated: true

    property int expandedWidth: 240
    property int iconWidth: 56

    property int itemSpacing: Theme.space.xxs
    property int padding: Theme.space.sm

    /** 内边缘那条可点的拖拽/开合轨 */
    property bool showRail: false

    /** 开合快捷键。空串 = 不注册（见文件头"快捷键为什么默认是关的"） */
    property string toggleShortcut: ""

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property bool _iconMode: root.collapsible === "icon"

    /** 折到了"只剩图标"这一档 */
    readonly property bool iconOnly: root._iconMode && root.collapsed

    /** 当前实际宽度 —— **判据读这一个**，不读过渡中的 width */
    readonly property int currentWidth:
        root.collapsible === "none" ? root.expandedWidth
        : root.collapsed ? (root._iconMode ? root.iconWidth : 0)
        : root.expandedWidth

    readonly property bool _floating: root.variant === "floating"
    readonly property int  _margin:   root._floating ? Theme.space.sm : 0
    readonly property int  _radius:   root._floating ? Theme.radius.lg
                                      : (root.variant === "inset" ? Theme.radius.lg : 0)
    readonly property color _bg: root._floating || root.variant === "inset"
                                 ? Theme.color.bgElevated : Theme.color.bgSubtle

    readonly property int count: root.model ? root.model.length : 0

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 用户选了第 index 项（只对"项"发，分区标题与分割线不发） */
    signal selected(int index)

    function toggle() {
        if (root.collapsible === "none") return
        root.collapsed = !root.collapsed
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    function _itemAt(i)       { return root.model ? root.model[i] : null }
    function _isSeparator(i)  {
        var it = root._itemAt(i)
        return it === "separator" || (it && it.separator === true)
    }
    function _isHeader(i)     {
        var it = root._itemAt(i)
        return !!(it && typeof it === "object" && it.header !== undefined)
    }
    function _textAt(i) {
        var it = root._itemAt(i)
        if (typeof it === "string") return it
        if (!it) return ""
        if (it.header !== undefined) return String(it.header)
        return it.text !== undefined ? String(it.text) : ""
    }
    function _isSelectable(i) { return !root._isSeparator(i) && !root._isHeader(i) }

    /* ══════════════════════ 几何 ══════════════════════ */

    implicitWidth:  root.currentWidth
    implicitHeight: 480

    width: root.currentWidth

    Behavior on width {
        enabled: root.animated && root.collapsible !== "none"
        NumberAnimation { duration: Theme.motion.normal; easing.type: Theme.motion.easing }
    }

    /* 面板本体。`floating` / `inset` 有外边距，所以它不铺满 root。 */
    Rectangle {
        id: panel

        x: root._margin
        y: root._margin
        width:  Math.max(0, root.width - root._margin * 2)
        height: Math.max(0, root.height - root._margin * 2)

        radius: root._radius
        color: root._bg
        clip: true

        /* `floating` 的四周描边（M25 抓图时补上的）。
         *
         * 它是那一档**唯一的轮廓来源**：亮色下 arco / shadcn 的
         * `bgElevated` 与页底 `bg` **都是纯白**，只靠底色的话这一档摆在
         * 普通页面上整块**不可见**（M23 记过同一条：不要用颜色定位容器）。
         * 另两档靠下面那条 `innerEdge`，`floating` 的一圈边框就是它的对应物 ——
         * 这条注释原先写着"四周都有描边"，但代码里**没有**：注释是意图，
         * 属性才是事实。抓图核验把它暴露出来了（`.cache/_verify_m25px.py` 的
         * 那一组要量"这一档的左边缘是不是一条描边"）。
         * 与 shadcn 的 `variant="floating"` 也一致：那一档自带 border。 */
        border.width: root._floating ? 1 : 0
        border.color: Theme.color.border

        /* 内边缘那条线：贴内容的那一边。`floating` 走上面那圈描边，
         * 所以它只是另两档的标记。 */
        Rectangle {
            id: innerEdge

            visible: !root._floating
            width: 1
            height: parent.height
            x: root.side === "left" ? parent.width - 1 : 0
            color: Theme.color.divider
        }

        QSkinColumn {
            id: col

            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            anchors.margins: root.padding
            gap: root.itemSpacing

            /* ── 头部 ── */
            QSkinRow {
                id: headerHost

                visible: headerHost.data.length > 0
                Layout.fillWidth: true
                gap: Theme.space.xs
            }

            /* ── 宿主插进来的内容 ── */
            QSkinColumn {
                id: contentHost

                visible: contentHost.data.length > 0
                Layout.fillWidth: true
                gap: root.itemSpacing
            }

            /* ── 项目 ── */
            QSkinColumn {
                id: listHost

                Layout.fillWidth: true
                gap: root.itemSpacing

                Repeater {
                    model: root.count

                    /* 代理里要引用外层 root / Theme —— 非限定访问，局部关掉
                     * （与 QSkinMenu / QSkinAnchor 同一处置；注释首行不要以 qmllint 开头） */
                    // qmllint disable unqualified
                    delegate: Item {
                        id: slot

                        property int index

                        Layout.fillWidth: true
                        width:  listHost.width
                        height: {
                            if (root._isSeparator(slot.index)) return 1 + Theme.space.xs * 2
                            if (root._isHeader(slot.index))    return root.iconOnly ? 0
                                                                 : Theme.size.controlSm
                            return Theme.size.controlLg
                        }

                        /* 分区标题与分割线在图标态下**整体消失**：
                         * 只剩一列图标时，标题没有可读的位置。 */
                        visible: !(root.iconOnly && (root._isHeader(slot.index)
                                                     || root._isSeparator(slot.index)))

                        /* ── 分割线 ── */
                        Rectangle {
                            visible: root._isSeparator(slot.index)
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left:  parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Theme.color.divider
                        }

                        /* ── 分区标题 ── */
                        Text {
                            visible: root._isHeader(slot.index)
                            anchors.left:  parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Theme.space.sm
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.space.xxs
                            text: root._textAt(slot.index)
                            elide: Text.ElideRight
                            color: Theme.color.fgMuted
                            font.family: Theme.font.family
                            font.pixelSize: Theme.font.xs
                            font.weight: Theme.font.weightMedium
                        }

                        /* ── 一行 ── */
                        QSkinSidebarItem {
                            visible: root._isSelectable(slot.index)
                            anchors.fill: parent

                            text:    root._textAt(slot.index)
                            active:  root.activeIndex === slot.index
                            enabled: {
                                var it = root._itemAt(slot.index)
                                return !(it && it.enabled === false)
                            }
                            level: {
                                var it = root._itemAt(slot.index)
                                return (it && it.level !== undefined) ? Number(it.level) : 0
                            }
                            icon: {
                                var it = root._itemAt(slot.index)
                                return (it && it.icon !== undefined) ? it.icon : null
                            }
                            expandable: {
                                var it = root._itemAt(slot.index)
                                return !!(it && it.expandable === true)
                            }
                            expanded: {
                                var it = root._itemAt(slot.index)
                                return !!(it && it.expanded === true)
                            }
                            iconOnly: root.iconOnly

                            onClicked:  root.selected(slot.index)
                            onToggled:  root.toggled(slot.index)
                        }
                    }
                    // qmllint enable unqualified
                }
            }

            /* ── 底部 ── */
            QSkinRow {
                id: footerHost

                visible: footerHost.data.length > 0
                Layout.fillWidth: true
                gap: Theme.space.xs
            }
        }

        /* ── 内边缘的开合轨（可选）── */
        MouseArea {
            id: rail

            visible: root.showRail && root.collapsible !== "none"
            width: 4
            height: parent.height
            x: root.side === "left" ? parent.width - 4 : 0
            hoverEnabled: true
            cursorShape: Qt.SplitHCursor

            Rectangle {
                anchors.fill: parent
                color: rail.containsMouse ? Theme.color.border : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
            }

            onClicked: root.toggle()
        }
    }

    /** 用户展开了/收起了第 index 项（可展开的行同时也会发 `selected`） */
    signal toggled(int index)

    Shortcut {
        sequence: root.toggleShortcut
        enabled: root.toggleShortcut !== ""
        onActivated: root.toggle()
    }

    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("侧栏导航")
}
