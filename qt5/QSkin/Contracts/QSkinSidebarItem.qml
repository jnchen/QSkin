/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinSidebarItem
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 侧栏里的一行：图标 + 文字 + 右侧尾巴 + 可选子级展开箭头。
 * 参照 shadcn 的 `SidebarMenuItem` + `SidebarMenuButton`（那两件合起来
 * 才是一行，本仓按既有口径并成一件）。
 *
 * ── 为什么它是一件独立控件，而不是 QSkinSidebar 的内部代理 ────────────────
 * 因为**手搭**侧栏是常态：宿主要放分组标题、要放分割线、要放自己的
 * 品牌块 —— 那些都不是"一行"。若行只能是内部代理，宿主就得放弃
 * `QSkinSidebar.model` 之外的写法，或者自己去对齐图标列。
 * 独立之后两条路都成立：给 `model` 让它自己铺，或手写一行行。
 *
 * ── 尾巴（badge）为什么是 alias 而不是一个 `count` 属性 ─────────────────
 * 本仓已有 `QSkinBadge`，但它的语义是**挂在别的东西上的通知点**
 * （`value` / `max` / `dot` / `anchorTo` / `anchorCorner` —— 它靠锚在
 * 宿主角上来定位）。而这里要的是"行尾一个安静的数字"，也就是 shadcn 的
 * `SidebarMenuBadge` 那一档。两者的定位机制相反（一个锚出去、一个排进来），
 * 硬用前者会把"角标"这套语义污染成两种。
 *
 * 所以尾巴是一个 **alias**：宿主想放什么放什么（`QSkinBadge` 也行、
 * 一个 `Text` 也行）。本件不重画第三种角标。
 *
 * ── 已知边界 ─────────────────────────────────────────────────────────
 * · **不做**行内动作按钮（shadcn 的 `SidebarMenuAction`，悬停才出现）。
 *   它需要一个"悬停时占用本来给尾巴的位置"的约定，而这个约定在四家里
 *   都不一致（有的挤掉数字、有的浮在数字上）。没有消费者，先不做。
 * · 子级的展开**不由本件自己管**：`expanded` 是输入，翻转由宿主/容器决定。
 *   一行自己记住"我展开了"会让"折叠整个侧栏再展开"时状态对不上。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    property string text: ""
    property bool active: false

    /** 缩进层级（子级 = 1） */
    property int level: 0

    /* ══════════════════════ 内容 ══════════════════════ */

    /** 左图标。一个 Component —— 与 QSkinButton.icon 同一口径 */
    property Component icon: null
    property int iconSize: Theme.size.iconMd

    /** 行尾内容。放 QSkinBadge、Text，或什么都不放 */
    property alias trailing: trailingHost.data

    /** 有子级时显示展开箭头 */
    property bool expandable: false
    property bool expanded: false

    /* ══════════════════════ 外观 ══════════════════════ */

    property int itemHeight: Theme.size.controlLg
    property int radius: Theme.radius.md
    /** 每一级的缩进量 */
    property int indentStep: Theme.space.lg
    /** 由容器给：图标态（折叠成图标栏）时隐藏文字与箭头 */
    property bool iconOnly: false

    /* ══════════════════════ 状态 ══════════════════════ */

    property bool hovered: false
    property bool pressed: false

    /* ══════════════════════ 信号 ══════════════════════ */

    /** 被点了。`expandable` 的行**也发这个** —— 之后再发 `toggled()`，
     *  因为"选中一个可展开的行"与"把它折起来"是两件事，宿主可能两件都要。 */
    signal clicked()
    signal toggled()

    /* ══════════════════════ 几何 ══════════════════════ */

    implicitWidth:  200
    implicitHeight: root.itemHeight

    /* ══════════════════════ 底板 ══════════════════════ */

    Rectangle {
        id: plate

        anchors.fill: parent
        radius: root.radius

        /* 三档，互斥：按下 > 悬停 > 活动。
         * 活动态用 brandSubtle（"我在这一页"），悬停用 bgSunken（"鼠标在这"）——
         * 两者必须能同时被看懂，所以不能取同一个色。 */
        color: root.pressed ? Theme.color.bgSunken
               : root.active ? Theme.color.brandSubtle
               : (root.hovered && root.enabled ? Theme.color.bgSunken : "transparent")

        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

        opacity: root.enabled ? 1 : 0.4

        /* ── 图标 ── */
        Loader {
            id: iconLoader

            anchors.left: parent.left
            anchors.leftMargin: Theme.space.sm + root.level * root.indentStep
            anchors.verticalCenter: parent.verticalCenter

            visible: root.icon !== null
            width:  root.iconSize
            height: root.iconSize

            sourceComponent: root.icon
        }

        /* ── 文字 ──
         * 折叠成图标栏时**隐藏**而不是缩窄 —— 缩窄会让文字挤成省略号，
         * 看起来像"坏了"，而藏起来读作"现在只有图标"。 */
        Loader {
            id: labelLoader

            visible: !root.iconOnly
            anchors.left:  iconLoader.visible ? iconLoader.right : parent.left
            anchors.right: tailSlot.left
            anchors.leftMargin: Theme.space.sm
            anchors.rightMargin: Theme.space.xs
            anchors.verticalCenter: parent.verticalCenter

            sourceComponent: Slots.label

            Binding {
                target: labelLoader.item
                property: "control"
                value: root
                when: labelLoader.item !== null
            }
        }

        /* ── 行尾 ── */
        QSkinRow {
            id: tailSlot

            visible: !root.iconOnly && trailingHost.data.length > 0
            anchors.right: chevron.visible ? chevron.left : parent.right
            anchors.rightMargin: Theme.space.sm
            anchors.verticalCenter: parent.verticalCenter
            gap: Theme.space.xs

            QSkinRow {
                id: trailingHost
                Layout.alignment: Qt.AlignVCenter
                gap: Theme.space.xs
            }
        }

        /* ── 展开箭头 ──
         * 走 chevronIndicator 插槽：线宽 / 端点 / 尺寸都是主题差异。
         * 展开语义留在本件里：收起朝右、展开朝下。 */
        Loader {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: Theme.space.sm
            anchors.verticalCenter: parent.verticalCenter

            visible: root.expandable && !root.iconOnly
            width:  Theme.size.iconSm
            height: Theme.size.iconSm

            sourceComponent: Slots.chevronIndicator

            Binding {
                target: chevron.item
                property: "control"
                value: chevronProxy
                when: chevron.item !== null
            }
        }
    }

    /* 给 chevronIndicator 读的假控件 —— 与 QSkinMenu 的菜单行同一手法 */
    QtObject {
        id: chevronProxy

        readonly property string direction: root.expanded ? "down" : "right"
        readonly property int size: Theme.size.iconSm
    }

    /* ══════════════════════ 输入 ══════════════════════ */

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled

        onContainsMouseChanged: root.hovered = containsMouse
        onPressedChanged:       root.pressed = pressed
        onClicked: {
            root.clicked()
            if (root.expandable) root.toggled()
        }
    }

    /* 文字给 Slots.label 读 —— 与 QSkinMenu 的菜单行同一套伪装。
     * 注意 `enabled` **不在这里**：它是 Item 自己的属性（上面直接用它），
     * 不再另立一个 `disabled` 输入 —— 两个真相源早晚会打架。 */
    readonly property string variant: root.active ? "primary" : "ghost"
    readonly property int labelAlignment: Text.AlignLeft

    Accessible.role: Accessible.ListItem
    Accessible.name: root.text
    Accessible.selected: root.active
    Accessible.onPressAction: {
        root.clicked()
        if (root.expandable) root.toggled()
    }
}
