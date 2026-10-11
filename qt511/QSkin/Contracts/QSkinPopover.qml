/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinPopover
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 浮层基座。M21 的 Popconfirm / HoverCard 都由它派生 —— 这一族真正的
 * 新东西是"任意内容 + 锚定到某个控件"，菜单那套（行、分隔线、上下键）
 * 是 QSkinMenu 的事，两条腿分开走。
 *
 * ── 分工 ─────────────────────────────────────────────────────────────
 *   这个文件：开合状态机、锚定与翻转、窗口边界夹取、外部点击 / Esc、
 *             内容注入、排他登记（OverlayStack）
 *   插槽负责：Slots.selectOverlay —— 面板外壳（底色 / 圆角 / 描边 / 阴影）
 *
 * ── 面板外壳为什么复用 selectOverlay，而不是新开一格 ────────────────────
 * 先例是 M4 的 QSkinMenu，它的文件头写着结论："selectOverlay 实际上是
 * 「浮层面板外壳」"。四套设计系统里，下拉面板、菜单、气泡三者的外壳
 * 本来就是同一件事（同一个 bgElevated + 同一个圆角 + 同一个阴影），
 * 四家的 selectOverlay 实现也证实了这点 —— 每份都只是"阴影 + 面板 +
 * 内容区"三件套（70~91 行）。
 *
 * 所以这里复用的是**外壳**，不是它的尺寸法则：selectOverlay 从
 * control.contentHeight 读高度（M5 契约扩展），Popover 就把内容的
 * 隐式高度喂给它。这也正是 QSkinMenu 当初的做法。
 *
 * 代价写在这里不藏：**面板内边距由插槽决定**（Basic 4 / TDesign 8），
 * 所以同一个 panelWidth 在不同主题下内容区会差几个像素。这是"内边距
 * 属于外观"的必然结果 —— 真要让 Popover 自己定内边距，就该给它一格
 * 独立插槽；等出现第二个不满足于复用的场景再说（契约层加插槽是增量改动）。
 *
 * ── 坐标参考系：Popup 不设 parent（与 QSkinSelect 一致）───────────────────
 * 项目里两个先例看着矛盾，实测（.cache/_probe_m21_popup_coord.qml）结论是
 * **两者都对，因为它们的 parent 不同**：
 *
 *     Popup 不设 parent        → 坐标相对**声明它的那个 Item**
 *     Popup parent: Overlay    → 坐标相对 overlay
 *                                （QSkinTooltip / QSkinDialog 这一支）
 *
 * 本文件走第一支：root 是 0×0，popup.x/y 相对 root。锚定一个不在同层的
 * target 时，把两者的**场景坐标**都算出来再相减 —— 这样无论调用方把
 * Popover 声明在哪一层，结果都一样，不必要求它和 target 做邻居。
 *
 * ── 内容注入：default property alias 的适用范围（实测踩出来的）─────────
 * `default property alias contentData: bodyHost.data` 里的 alias 目标
 * **必须是 id**，不能穿过"property 值里的对象"（写 `root.p.bodyHost.data`
 * 会直接报 Invalid alias reference）。而且要**声明在组件定义的根对象**上
 * 才生效 —— 把同样的两行写进一个内联 `Item {}` 实例里，子节点一个都不会
 * 被重定向（.cache/_probe_m21_idiom.qml 与 _probe_m21_alias.qml 对照过）。
 * 本文件的根对象就是组件根，满足条件。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Window 2.11
import QtQuick.Controls 2.4
/* 内容宿主是 QSkinColumn（内部是 ColumnLayout），标题那一格要写
 * `Layout.fillWidth` —— 附加属性属于这个模块，不 import 会报
 * "Non-existent attached object"。 */
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 锚定到哪个控件。必须暴露 width / height（也就是任何 Item）。
     * 声明为 var 而不是 Item：契约是鸭子类型，声明成 Item 会让 qmllint
     * 按 QQuickItem 做成员检查而误报（与 QSkinTooltip.target 同一理由）。 */
    property var target: null

    /** 可选标题。非空时排在内容上方，走 label 插槽的 header 变体
     *  （与 QSkinDialog 标题同款）。 */
    property string title: ""

    /** 偏好方向：bottom | top。空间不足时自动翻到另一侧 */
    property string placement: "bottom"

    /** 与 target 之间的间距 */
    property int gap: Theme.space.xs

    /** 面板总宽。<= 0 表示跟随内容（hug）。内容里有折行文字时请显式给值 ——
     *  否则"面板宽 ← 内容宽 ← 文字不折行"会自洽地一直不折行。 */
    property int panelWidth: -1

    /** 是否参与"同刻只有一个浮层"（见 foundation/OverlayStack.qml）。
     *  悬停类浮层应设 false —— 它不该顶掉用户刚点开的东西。 */
    property bool exclusive: true

    /** 点面板外部是否关闭。确认类内容建议关掉 */
    property bool dismissOnPressOutside: true

    /** 无障碍名。内容可读时留空即可 */
    property string accessibleName: ""

    /** 无障碍角色。Popconfirm 会改成 Dialog */
    property int accessibleRole: Accessible.Grouping

    readonly property alias opened: popup.opened

    /** 指针是否停在浮层面板上。悬停类浮层（QSkinHoverCard）靠它决定
     *  "该不该收" —— 详见 contentItem 里 HoverHandler 处的说明。 */
    readonly property alias panelHovered: panelHover.hovered

    /** 内容宿主。调用方声明的子节点都落进这里；测试也靠它 */
    readonly property alias contentHost: bodyHost

    /** 面板实例（插槽加载出来的那个 Item），测试用来读 padding / extender */
    readonly property var panel: overlayLoader.item

    /** 插槽上报的面板内边距。插槽没提供时为 0 */
    readonly property real panelPadding: {
        var p = root.panel
        return (p !== null && p.padding !== undefined) ? p.padding : 0
    }

    /** 插槽上报的阴影外扩量（M4 契约回收）。Popup 据此把自己放大
     *  extender*2，否则主题画的阴影会被浮层边界裁掉。 */
    readonly property real panelExtender: {
        var p = root.panel
        return (p !== null && p.extender !== undefined) ? p.extender : 0
    }

    /* 调用方声明的子节点 → 内容宿主。
     * 这里必须是组件根对象上的 default property（见文件头）。 */
    default property alias contentData: bodyHost.data

    /* ══════════════════════ 开合 ══════════════════════
     *
     * ── 为什么要分成四个函数 ─────────────────────────────────────────────
     * QML 里派生件覆盖同名函数是**整个替换**，没有 super 可以回调基座。
     * 而 QSkinHoverCard 必须覆盖 open()/close()（它要顺带掐掉两个计时器），
     * 于是它需要一对"不含任何策略、只管开合"的原语来落脚。
     *
     * 所以：showOverlay / hideOverlay 是**原语**，open / close 是**策略**。
     * 派生件覆盖策略、调用原语。 */
    function showOverlay() { popup.open()  }
    function hideOverlay() { popup.close() }

    function open()  { root.showOverlay()  }
    function close() { root.hideOverlay()  }
    function toggle() { popup.opened ? root.close() : root.open() }

    /* 本体零占位：视觉全在 Popup 里。但必须留在场景里，
     * 否则 Popup 没有可锚的父（QSkinMenu / QSkinTooltip 同款）。 */
    width: 0
    height: 0

    /* ══════════════════════ 内容宿主 ══════════════════════
     * 撑满调用方给的空间、尺寸对齐面板内容区。
     *
     * 宽度**不从 parent 取**：接管前 parent 是 root（0×0），
     * `anchors.fill` 会让宽度变 0 —— 而折行文字在 0 宽下会一行一个词，
     * implicitHeight 直接爆炸，再经插件喂回面板高度就是个死循环的观感。
     * 所以宽度只由 panelWidth / 自身隐式宽度决定，与父容器无关。 */
    QSkinColumn {
        id: bodyHost

        visible: false                       /* 等插槽接管后再亮 */
        gap: Theme.space.sm

        width: root.panelWidth > 0
               ? Math.max(0, root.panelWidth - root.panelPadding * 2)
               : implicitWidth

        Accessible.role: root.accessibleRole
        Accessible.name: root.accessibleName

        /* 标题（可选）。声明在内容之前 —— 调用方的子节点会接在它后面 */
        Loader {
            id: titleLabel

            visible: root.title !== ""
            Layout.fillWidth: true
            sourceComponent: Slots.label

            Binding {
                target: titleLabel.item
                property: "control"
                value: titleCtl
                when: titleLabel.status === Loader.Ready
            }
        }

        QtObject {
            id: titleCtl

            readonly property string text: root.title
            readonly property string variant: "header"
            readonly property int labelAlignment: Text.AlignLeft
        }
    }

    /* ══════════════════════ 浮层 ══════════════════════ */

    Popup {
        id: popup

        /* 浮层边界比面板大一圈 extender，主题的阴影才不被裁 */
        padding: root.panelExtender

        /* 面板外观完全由 overlay 插槽负责，这里不放任何东西 */
        background: Item {}

        focus: true
        modal: false
        closePolicy: root.dismissOnPressOutside
                     ? (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
                     : Popup.CloseOnEscape

        contentItem: Item {
            id: panelRoot

            Loader {
                id: overlayLoader

                width:  parent ? parent.width  : 0
                height: parent ? parent.height : 0

                sourceComponent: Slots.selectOverlay

                Binding {
                    target: overlayLoader.item
                    property: "control"
                    value: panelCtl
                    when: overlayLoader.item !== null
                }
                /* 宿主持有内容、插槽负责把它摆进自己的内容区并显示 ——
                 * 正是 BasicSelectOverlay 文件头写的那条浮层契约。 */
                Binding {
                    target: overlayLoader.item
                    property: "content"
                    value: bodyHost
                    when: overlayLoader.item !== null
                }
            }

            /* 指针是否停在**浮层面板**上（含内边距，不只是内容）。
             * 悬停类浮层靠它判断"指针从 target 移到卡片上了，先别收"。
             * 用 HoverHandler 而不是 MouseArea：它只参与 hover 事件链，
             * 不吃点击 —— 契约第 3 条那条"插槽不能引入交互"的精神同样
             * 适用于这里。 */
                        MouseArea {
                /* Qt 5.11 无 HoverHandler（Pointer Handlers 是 Qt 5.15 才有）
                 * → 降级为 MouseArea。hoverEnabled: true 是前提：5.11 的
                 *   MouseArea 默认不上报 onEntered/onExited（5.15 默认开）。 */
                /* hovered 兼容：HoverHandler 的状态在 5.11 无对应属性 */
                readonly property bool hovered: containsMouse
                hoverEnabled: true

                id: panelHover

            }
        }

        /* 外壳读这几项决定面板尺寸（M5 契约扩展：contentHeight 优先）。
         * count / maxVisibleRows / rowHeight 是列表面板的三个字段，
         * Popover 没有行，但仍要提供 —— 外壳在没有 contentHeight 时才用它们，
         * 而这里 contentHeight 恒有值。 */
        QtObject {
            id: panelCtl

            readonly property int  count: 0
            readonly property int  maxVisibleRows: 0
            readonly property int  rowHeight: 1
            readonly property real contentHeight: bodyHost.implicitHeight
            readonly property real width: root.panelFullWidth
        }

        contentWidth: root.panelFullWidth
        contentHeight: root._contentHeight()

        x: root._popupX()
        y: root._popupY()

        onOpened: {
            if (root.exclusive) OverlayStack.request(root)
            bodyHost.forceActiveFocus()
        }
        onClosed: OverlayStack.drop(root)
    }

    /* ══════════════════════ 定位 ══════════════════════
     * 一律走**场景坐标**再减回 root 的偏移：这样 target 在不在同一层都成立。 */

    /* ── 锚点为什么必须"假读"一遍几何（M21 像素核验抓出来的真缺陷）─────────
     *
     * `mapToItem()` 是**方法调用**，不产生任何属性依赖。于是
     *
     *     readonly property point targetOrigin: root.target
     *         ? root.target.mapToItem(null, 0, 0)
     *         : root.sceneOrigin
     *
     * 这个绑定只会被求值一次（它依赖的只有 target 本身，而 target 赋上之后
     * 再没变过）。求值那一刻 QML 正在实例化 QSkinPopover 的**内部属性**：
     * 外部那条 `target: 锚点` 还没落下来，而目标自己的 `x: …` 是惰性绑定，
     * 谁都还没读过 —— 于是 mapToItem 一路拿到 (0,0)，并且**永远停在 (0,0)**
     * （实测：t=1400ms 时 `targetOrigin` 仍是 (0,0)，而同一刻现算的
     * `target.mapToItem(null,0,0)` 已经是 (200,52)）。
     *
     * 后果是面板落到窗口左上角、被夹取到最小边距，多个浮层全叠在一处 ——
     * 属性读数（panelFullWidth / panelPadding / extender）个个正确，
     * 只有像素上看得见。这正是本项目反复撞到的"属性对而界面错"。
     *
     * 修法：沿父链把 x/y 显式读一遍，把依赖登记进绑定。实测三点收敛
     * (0,0) → (0,52) → (200,52)；目标自己或任一祖先挪动时也会重算。 */

    /** 沿父链读一遍 x/y —— 唯一目的是**登记依赖**（返回值不用）。 */
    function _anchorDeps(item) {
        var acc = 0
        var p = item
        while (p !== null && p !== undefined) {
            acc += p.x + p.y
            p = p.parent
        }
        return acc
    }

    /** root 自身的场景原点 */
    readonly property point sceneOrigin: {
        var _ = root._anchorDeps(root)
        return root.mapToItem(null, 0, 0)
    }

    /** target 的场景原点。没有 target 时退化成 root 自己 */
    readonly property point targetOrigin: {
        if (!root.target) return root.sceneOrigin
        var _ = root._anchorDeps(root.target)
        return root.target.mapToItem(null, 0, 0)
    }

    readonly property real targetWidth:  root.target ? root.target.width  : 0
    readonly property real targetHeight: root.target ? root.target.height : 0

    /** 面板总宽：定宽就取定宽；否则 = 内容宽 + 两侧内边距 */
    readonly property real panelFullWidth: root.panelWidth > 0
        ? root.panelWidth
        : Math.max(1, bodyHost.implicitWidth + root.panelPadding * 2)

    /** 面板总高。
     *
     * ── 为什么读 bodyHost 而不是 overlayLoader.implicitHeight ─────────────
     * 后者会踩一个**绑定环**（实测告警：Binding loop detected for property
     * "contentHeight"）。链路是：
     *
     *     popup.contentHeight ← loader.implicitHeight ← 外壳的 implicitHeight
     *       ← panelCtl.contentHeight ← bodyHost.implicitHeight ← … 再回到 popup
     *
     * 环的最后一跳来自"外壳的 host 是 anchors.fill，bodyHost 住在它里面" ——
     * 内容的隐式高度与浮层高度互相看得见。直接读 bodyHost 就把外壳从这条
     * 链上摘掉了：面板尺寸 = 内容隐式尺寸 + 两侧内边距，一个环都没有。
     * 外壳的内边距仍由插槽决定（panelPadding），所以这是"复用了外壳、
     * 但没有复用它的尺寸法则"，与文件头那段说明一致。 */
    function _contentHeight() {
        return bodyHost.implicitHeight + root.panelPadding * 2
    }

    function _popupX() {
        var win = root.Window.window
        var want = root.targetOrigin.x + root.targetWidth / 2 - popup.width / 2
        if (win) {
            var m = Theme.space.sm
            want = Math.max(m, Math.min(want, win.width - popup.width - m))
        }
        return want - root.sceneOrigin.x
    }

    function _popupY() {
        var win = root.Window.window
        var below = root.targetOrigin.y + root.targetHeight + root.gap
        var above = root.targetOrigin.y - popup.height - root.gap

        var use = root.placement === "top" ? above : below
        if (win) {
            var m = Theme.space.sm
            /* 偏好方向放不下、另一侧放得下 → 翻过去 */
            if (use + popup.height > win.height - m && above > m) use = above
            else if (use < m && below + popup.height < win.height - m) use = below
        }
        return use - root.sceneOrigin.y
    }
}
