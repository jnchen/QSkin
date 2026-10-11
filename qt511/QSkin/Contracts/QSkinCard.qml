/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinCard
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 卡片 —— 页面里的一块地，把一组相关的东西框在一起：标题 + 内容 + 操作。
 *
 * ── 它和 QSkinDialog 是同族，但不是同一个东西 ────────────────────────────
 *   Dialog  是**浮层**（Popup）：抢焦点、压在遮罩上、有开合动画、逃生出口
 *           是"关掉它"。
 *   Card    是**页面里的地**（Item）：参与正常布局流、不抢焦点、没有开合，
 *           参与者是"读"和"点进去"。
 * 两者的**头部 / 身体 / 尾部**结构几乎一样，所以这里刻意沿用 Dialog 已经
 * 确立的三条做法，而不是另起一套：
 *   · 面板底板用令牌组合，**不开插槽**（Dialog 先例：面板的形态差异比按钮
 *     小得多，为一个没有第二个消费者的形态再开一个格子不划算）
 *   · 标题走 `Slots.label` + 伪装一个 control（variant: "header"）
 *   · 尾部交给 `ButtonBar`（平台顺序、危险项安全间距、窄屏堆叠免费拿到）
 * 「同一件事在项目里只有一个做法」比「每个控件都自成一派」值钱。
 *
 * ── 为什么没有"带阴影"的变体 ───────────────────────────────────────────
 * 阴影要用 `QtQuick.Effects` 的 DropShadow / MultiEffect，而本项目从 M1
 * 起就没有引入它 —— TDSelectOverlay 与 TDInputBackground 的文件头都记着
 * 同一条理由：**它属于额外的图形特效模块，最小化安装的 Qt 未必带**。
 * 于是层次改用三档底色 / 描边表达：
 *     outlined  白底 + 1px 描边    ← 页面里的常规卡片
 *     filled    浅底，无描边       ← 嵌在已有卡片里的内层块
 *     plain     无底无边           ← 只借它的内边距与结构
 * 悬停（hoverable）不改阴影，改为**描边变品牌色** —— 同一档信息量，
 * 不引入新依赖。
 *
 * ── 分割线走 QSkinDivider（它有第一个真实消费者了）───────────────────────
 * M17 的判据是"没有消费者就不该做"；反过来，做出来的东西要有地方用。
 * QSkinDivider 与本控件同批落地，这里是它第一个非演示的调用点 ——
 * 而且用的是**无文字、撑满宽**那条分支，正好是它最常被用的形态。
 * 分割线只在"上一段和下一段都存在"时出现，否则尾部会多出一条悬空的线。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    /** 标题。走 label 插槽的 header 变体（同 Dialog）。 */
    property string title: ""

    /** 副标题。弱一档的辅助说明，走 Caption。 */
    property string subtitle: ""

    /** 右上角操作区。可直接写多个子项：
     *      extra: QSkinButton { text: "更多" } */
    property alias extra: extraHost.data

    /** 底部操作区，交给 ButtonBar（自动右对齐 + 平台顺序 + 危险项间距） */
    property alias footer: footerHost.data

    /** 主内容。默认属性 —— `QSkinCard { QSkinInput {} }` 直接进内容区。 */
    default property alias contentData: bodyHost.data

    /* ══════════════════════ 外观 ══════════════════════ */

    /** outlined | filled | plain */
    property string variant: "outlined"

    /** 头部与身体之间、身体与尾部之间是否画分割线 */
    property bool separator: true

    /** 内容区四周内边距 */
    property int contentPadding: Theme.space.lg

    /** 头部四周内边距（比内容区略大：标题需要更多呼吸） */
    property int headerPadding: Theme.space.lg

    /** 尾部四周内边距 */
    property int footerPadding: Theme.space.lg

    /** 可点 / 可悬停。开了之后才进 Tab 顺序、才有点击光标。 */
    property bool hoverable: false

    /** 悬停中（供槽 / 业务读） */
    property bool hovered: false

    signal clicked()

    /* ══════════════════════ 派生 ══════════════════════
     *
     * 判"用户有没有放东西"用的是 **data** 而不是 **children**。
     *
     * 这是个会静默算错的坑：三个宿主都是 QSkin 布局组件
     * （QSkinColumn / QSkinRow / ButtonBar），它们内部各自有一个
     * ColumnLayout / RowLayout / Item —— 那个内部布局**也是**
     * 宿主的 QQuickItem 子项。于是 `host.children.length` 恒 ≥ 1，
     * 三个 has* 会永远为 true：一张空卡片也会画出头部区、分割线、
     * 尾部三块空白。
     *
     * 而 `data` 在这三个控件里都被 alias 到了内部布局的 data
     * （`default property alias data: layout.data`），也就是
     * **只剩用户放进去的那一份**。用对了这一处，派生条件才是真的。 */
    readonly property bool hasHeader:
        root.title !== "" || root.subtitle !== "" || extraHost.data.length > 0

    readonly property bool hasBody:  bodyHost.data.length > 0

    readonly property bool hasFooter: footerHost.data.length > 0

    /* 分割线只在两段都在的时候画 —— 否则会在末尾留一条悬空的线 */
    readonly property bool showHeaderRule: root.separator && root.hasHeader && root.hasBody
    readonly property bool showFooterRule: root.separator && root.hasFooter && root.hasBody

    /* ══════════════════════ 尺寸 ══════════════════════
     * hug 语义：宽度 = 最宽的一段，高度 = 三段之和。
     * 需要固定或撑满时由调用方给 width / 用 fill（下面绑了 Layout.fillWidth）。 */

    implicitWidth:  column.implicitWidth
    implicitHeight: column.implicitHeight

    /* 供 FocusRing 使用（FocusRing 会读 control.radius 让环贴着圆角走） */
    readonly property int radius: d.radius()

    activeFocusOnTab: root.hoverable
    Accessible.role: Accessible.Grouping
    Accessible.name: root.title

    /* ══════════════════════ 底板 ══════════════════════ */

    Rectangle {
        id: plate

        anchors.fill: parent
        color:        d.bg()
        border.width: d.borderWidth()
        border.color: d.borderColor()
        radius:       d.radius()

        Behavior on border.color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    /* ══════════════════════ 结构 ══════════════════════ */

    ColumnLayout {
        id: column

        anchors.fill: parent
        spacing: 0

        /* ── 头部 ── */
        Item {
            id: header

            Layout.fillWidth: true
            visible: root.hasHeader
            implicitHeight: headerRow.implicitHeight + root.headerPadding * 2

            RowLayout {
                id: headerRow

                anchors.fill: parent
                anchors.margins: root.headerPadding
                spacing: Theme.space.sm

                QSkinColumn {
                    id: titleBox

                    Layout.fillWidth: true
                    gap: Theme.space.xxs

                    /* 标题：label 插槽的 header 变体。
                     * 与 Dialog 完全同款 —— 包括这个伪装 control 的写法：
                     * label 插槽读的是 duck-typing 的 text / variant /
                     * labelAlignment，控件只要提供这三样就行，
                     * 不必真的让 Divider / Card 继承什么基类。 */
                    Loader {
                        id: titleLabel

                        visible: root.title !== ""
                        Layout.fillWidth: true
                        sourceComponent: Slots.label

                        Binding {
                            target: titleLabel.item
                            property: "control"
                            value: cardTitleCtl
                            when: titleLabel.status === Loader.Ready
                        }
                    }

                    Caption {
                        visible: root.subtitle !== ""
                        Layout.fillWidth: true
                        text: root.subtitle
                    }
                }

                /* 把 extra 顶到右边 */
                Item { Layout.fillWidth: true }

                QSkinRow {
                    id: extraHost

                    gap: Theme.space.xs
                    align: "center"
                }
            }
        }

        QSkinDivider {
            visible: root.showHeaderRule
            Layout.fillWidth: true
        }

        /* ── 内容 ── */
        QSkinColumn {
            id: bodyHost

            Layout.fillWidth:  true
            Layout.fillHeight: true
            Layout.margins:    root.contentPadding

            visible: root.hasBody
            fill: true
            gap: Theme.space.md
        }

        QSkinDivider {
            visible: root.showFooterRule
            Layout.fillWidth: true
        }

        /* ── 尾部 ── */
        ButtonBar {
            id: footerHost

            Layout.fillWidth: true
            visible: root.hasFooter
            padding: root.footerPadding
            fill: true
        }
    }

    FocusRing { control: root }

    /* ══════════════════════ 交互 ══════════════════════
     * hoverable 关掉时这个 MouseArea 完全不参与（enabled: false），
     * 于是内容区里的控件能正常拿到鼠标事件 —— 这是"卡片可点"与
     * "卡片里的按钮可点"之间的界线，靠这一条属性划开。 */
    MouseArea {
        id: ma

        anchors.fill: parent
        enabled: root.hoverable
        hoverEnabled: root.hoverable
        cursorShape: Qt.PointingHandCursor

        onEntered: root.hovered = true
        onExited:  root.hovered = false
        onClicked: {
            if (root.hoverable) root.forceActiveFocus()
            root.clicked()
        }
    }

    Accessible.onPressAction: root.clicked()

    QtObject {
        id: cardTitleCtl

        readonly property string text: root.title
        readonly property string variant: "header"
        readonly property int labelAlignment: Text.AlignLeft
    }

    QtObject {
        id: d

        function bg() {
            switch (root.variant) {
            case "filled": return Theme.color.bgSubtle
            case "plain":  return "transparent"
            default:       return Theme.color.bgElevated
            }
        }

        function borderWidth() {
            return root.variant === "outlined" ? 1 : 0
        }

        function borderColor() {
            if (root.hoverable && (root.hovered || root.activeFocus))
                return Theme.color.brand
            return Theme.color.border
        }

        function radius() { return Theme.radius.lg }
    }
}
