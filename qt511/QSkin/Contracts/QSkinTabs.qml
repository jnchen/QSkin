/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinTabs
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 标签页导航（Tabs / TabBar）。M4 新增，用于验证两个契约结论：
 *
 *   1. 激活下划线走 Slots.tabIndicator（M4 契约回收）——
 *      TDesign 3px 圆角条、Ant/Arco 2px 细线、shadcn 前景色，
 *      差异全部由主题回答，本文件里没有一个像素的颜色。
 *   2. 文字走 Slots.label —— 激活页"伪装"成 variant "text"（强前景）、
 *      非激活页 "ghost"（弱前景），主题不用为 Tabs 写任何新代码。
 *
 * ── 分工 ─────────────────────────────────────────────────────────────
 *   本文件：model 解析、currentIndex、左右键 / Home / End 导航、
 *           点击切换、Accessible.PageTab 语义、内容区（M26 起）
 *   插槽：  Slots.label（页签文字）、Slots.tabIndicator（下划线）
 *
 * ════════════════════════════════════════════════════════════════════════
 * M26：补上内容区（M4 说过"不适合塞进导航控件"）
 * ════════════════════════════════════════════════════════════════════════
 * M4 的结论是「内容切换本质是 Loader + 业务自己的页面栈，Web 端 Tabs
 * 组件同样只管导航条」。那条结论**今天变了**，理由是出现了第二个消费者：
 * 三家设计系统的 Tabs（Ant / Arco / TDesign）都带 content pane，而本项目
 * 的消费者开始问「Tab 点了以后内容怎么跟着换」。
 *
 *     「出现第二个消费者，"它现在能跑"就不再是不做的理由。」（项目规矩）
 *
 * 补的方式刻意是**最小扩张** —— 老契约不能破：
 *
 *   contentDelegate 默认 null  →  零回归。null 时本件与 M4 逐项同形：
 *                                 implicitHeight 仍是 tabHeight、导航条
 *                                 仍铺满、多出来的那个 Loader `active:
 *                                 false` 不实例化任何东西。
 *   contentHeight   默认 -1    →  自适应内容的 implicitHeight；
 *                                 写 >= 0 则定高。
 *   keepAlive       默认 true  →  与 Ant / Arco / TDesign 三家默认一致
 *                                 （切走的页保留实例）。shadcn（Radix）
 *                                 那边是不保留，想要那种语义写 false。
 *
 * 内容实例通过 `control` 代理读状态（`currentIndex` / `count` /
 * `currentTitle` / `enabled`），与本项目所有插槽同一套约定 —— 于是
 * "保活"时用户写 `text: control.currentTitle` 就能跟着切，而"不保活"时
 * `Component.onCompleted` 会**重新跑**。
 *
 * 注意这里**没有**新增插槽：内容区是控件自己的能力，不是主题差异
 * （M26 裁决三 —— 零新增插槽，白名单仍是 21 格）。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 字符串数组、对象数组（配 textRole）、ListModel，或数字（表示条数） */
    property var  model: null
    property int  currentIndex: 0
    property string textRole: ""

    /* ══════════════════════ 外观（供插槽读取） ══════════════════════ */

    property int tabHeight: Theme.size.controlLg
    /** 页签文字两侧的留白 */
    property int tabPadding: Theme.space.lg
    /** 下划线相对页签文字的横向收缩量；主题可经插槽读它 */
    property int indicatorInset: 0

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 用户切换到了某一页 */
    signal activated(int index)

    readonly property int count: _countOf()

    /* ══════════════════════ 内容区（M26） ══════════════════════ */

    /** 内容区模板。`null`（默认）时本件与 M4 逐项同形 —— 零回归。
     *  实例上会挂一个 `control` 代理，字段见文件头。 */
    property Component contentDelegate: null

    /** 内容区高度：`-1` = 自适应内容的 implicitHeight，`>= 0` = 定高 */
    property int contentHeight: -1

    /** 导航条与内容区之间的间距 */
    property int contentSpacing: Theme.space.md

    /** 切换页签时是否保留已建好的内容实例（默认保留） */
    property bool keepAlive: true

    readonly property bool _hasContent: root.contentDelegate !== null
    readonly property real _contentResolved:
        root.contentHeight >= 0 ? root.contentHeight : contentLoader.implicitHeight

    /* ══════════════════════ 尺寸 ══════════════════════ */

    /* 页签宽度由文字撑开（Loader 的 implicitWidth 在 polish 后就绪，
     * 绑定会自动跟上 —— 见 tests/smoke_sizes.qml 的时序说明） */
    implicitWidth:  tabsRow.implicitWidth
    implicitHeight: root._hasContent
        ? root.tabHeight + root.contentSpacing + root._contentResolved
        : root.tabHeight

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true

    /* ══════════════════════ 无障碍 ══════════════════════ */

    Accessible.role: Accessible.PageTabList
    Accessible.name: root._titleOf(root.currentIndex)

    /* ══════════════════════ 页签排布 ══════════════════════ */

    QSkinRow {
        id: tabsRow

        /* 无内容区时与 `anchors.fill: parent` 等价（implicitHeight ==
         * tabHeight）；有内容区时贴顶，把下方让给内容。 */
        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top
        height: root.tabHeight

        gap: 0

        Repeater {
            model: root.model
            delegate: tabComp
        }
    }

    /* tabComp 引用了外层 id（root / Slots）—— inline Component 的静态
     * 检查局限，与 QSkinSelect 的 delegate 同款，局部关闭即可。
     * 注释首行不要以 qmllint 开头，否则会被当成指令解析。 */
    // qmllint disable unqualified

    Component {
        id: tabComp

        Item {
            id: tab

            property int index

            /* 页签被 QSkinRow（内部是 RowLayout）管理 —— Layouts 决定子项
             * 尺寸看的是 implicitWidth/Height，写 width/height 会被静默
             * 忽略（与 Grid.fill 挂死同一族陷阱，见 QSkinGrid.qml 文件头）。 */
            implicitWidth:  tabLoader.implicitWidth + root.tabPadding * 2
            implicitHeight: root.tabHeight

            /* 伪装成"控件"给 Slots.label 读 —— 与 QSkinSelect 的选项行同一套约定 */
            readonly property string text:  root._titleOf(tab.index)
            readonly property string variant: tab.active ? "text" : "ghost"
            readonly property bool   active: root.currentIndex === tab.index
            property bool hovered: false
            property bool pressed: false
            readonly property int labelAlignment: Text.AlignLeft

            Accessible.role:          Accessible.PageTab
            Accessible.name:          tab.text
            Accessible.selected:      tab.active
            Accessible.onPressAction: root._activate(tab.index)

            Loader {
                id: tabLoader

                /* 刻意**不**锚定左右来给宽度 —— label 插槽的 Text 都带
                 * elide，而 elide 的 Text 在 width 为 0 时 implicitWidth
                 * 恒为 0（Qt 的实现行为），页签宽度依赖它就会锁死在
                 * 「内边距宽」，文字被裁没。让 Loader 跟随 Text 的自然
                 * 隐式尺寸、只做居中定位，三套主题实测全部正确。 */
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)

                sourceComponent: Slots.label

                Binding {
                    target: tabLoader.item
                    property: "control"
                    value: tab
                    when: tabLoader.item !== null
                }
            }

            /* 激活下划线：视觉全部在插槽里，这里只是给它留了个位置 */
            Loader {
                id: indicatorLoader

                anchors.left:        parent.left
                anchors.right:       parent.right
                anchors.bottom:      parent.bottom
                anchors.leftMargin:  root.tabPadding + root.indicatorInset
                anchors.rightMargin: root.tabPadding + root.indicatorInset

                sourceComponent: Slots.tabIndicator

                Binding {
                    target: indicatorLoader.item
                    property: "control"
                    value: tab
                    when: indicatorLoader.item !== null
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                onEntered:  tab.hovered = true
                onExited:   tab.hovered = false
                onCanceled: tab.pressed = false
                onReleased: tab.pressed = false
                onPressed:  tab.pressed = true
                onClicked:  root._activate(tab.index)
            }
        }
    }

    // qmllint enable unqualified

    /* ══════════════════════ 内容区（M26） ══════════════════════ */

    Loader {
        id: contentLoader

        anchors.left:      parent.left
        anchors.right:     parent.right
        anchors.top:       tabsRow.bottom
        anchors.topMargin: root.contentSpacing
        height: root._contentResolved

        visible: root._hasContent
        active:  root._hasContent

        /* 刻意**不**写 `sourceComponent: root.contentDelegate` 这种声明式
         * 绑定：`_syncContent()` 要给它赋 null 再赋回原值（重建），而声明式
         * 绑定一旦被函数赋值就会**静默断开**（QSkinTreeSelect 的树勾选记过
         * 同一条 —— 那类 bug 的表现是"用一会儿才坏"）。
         * 所以创建 / 销毁统一走 `_syncContent()`，这里只留一个空壳。 */
    }

    /* 把"控制柄"注入内容实例。
     *
     * ⚠ `contentDelegate` 是**给外面写的**（`Slots.*` 那些是主题在写，全都
     * 声明了 `control`），所以这里不能像插槽那样无条件打绑定：内容区写成
     * 最自然的 `Item {}` 时，`Binding` 会每次都喊
     *     QML Binding: Property 'control' does not exist on QQuickItem.
     * （实测：一个裸 `Item` 的 delegate 会喊 4 行 console 噪音）。
     * 所以先问一句**有没有**这个属性 —— `hasOwnProperty` 在 QML 的 JS 引擎里
     * 会查 QObject 元对象（同 `tests/smoke_m26.qml` 的 `inputOf` 用它的手法）。
     * 声明了 `property var control: null` 就拿到句柄，没声明就什么都没发生。 */
    Binding {
        target: contentLoader.item
        property: "control"
        value: contentControl
        when: contentLoader.item !== null
              && contentLoader.item.hasOwnProperty("control") === true
    }

    QtObject {
        id: contentControl

        /* 内容实例能读到的东西。刻意只给这四样 —— 给多了就成了"从内容区
         * 反向操作导航条"，那是把两件事又揉回一起。 */
        readonly property int    currentIndex: root.currentIndex
        readonly property int    count:        root.count
        readonly property string currentTitle: root._titleOf(root.currentIndex)
        readonly property bool   enabled:      root.enabled

        function activate(i) { root._activate(i) }
        /** 手动重建内容实例 —— keepAlive=true 时给"我就是想重来一次"用 */
        function reload()    { root._syncContent() }
    }

    /* ══════════════════════ 键盘 ══════════════════════ */

    Keys.onLeftPressed:  root._move(-1)
    Keys.onRightPressed: root._move(1)

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Home) {
            event.accepted = true
            root._activate(0)
        } else if (event.key === Qt.Key_End) {
            event.accepted = true
            root._activate(root.count - 1)
        }
    }

    Keys.onReturnPressed: root._activate(root.currentIndex)
    Keys.onEnterPressed:  root._activate(root.currentIndex)

    /* ══════════════════════ 内部 ══════════════════════ */

    function _countOf() {
        var m = root.model
        if (m === null || m === undefined) return 0
        if (typeof m === "number") return m
        if (typeof m.get === "function") return m.count
        return m.length
    }

    function _titleOf(i) {
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

    function _move(dir) {
        if (!root.enabled) return
        var next = root.currentIndex + dir
        if (next < 0 || next >= root.count) return
        root._activate(next)
    }

    function _activate(i) {
        if (i < 0 || i >= root.count) return
        var changed = root.currentIndex !== i
        root.currentIndex = i
        root.forceActiveFocus()
        if (changed) root.activated(i)
    }

    /* ── 内容实例的创建 / 销毁 ──────────────────────────────────────────
     * 两个触发点：
     *   · contentDelegate 变了 → 一定要重建
     *   · currentIndex 变了   → 只有 keepAlive=false 才重建
     *
     * Loader 的销毁是同步的、创建是排队的，所以"先置 null 再置回原值"
     * 拿到的就是一个**新实例**。这条是要能证伪的，smoke_m26 里钉了：
     * keepAlive=false 切换后实例身份必须变、true 必须不变。 */
    onContentDelegateChanged: root._syncContent()
    onCurrentIndexChanged:    { if (!root.keepAlive) root._syncContent() }
    Component.onCompleted:    root._syncContent()

    function _syncContent() {
        contentLoader.sourceComponent = null
        if (root._hasContent) contentLoader.sourceComponent = root.contentDelegate
    }
}
