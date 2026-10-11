/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinCollapseItem
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 折叠面板的**一块**：一条可点的表头 + 一块可展开的内容区（M23）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 它同时扮演两个角色 —— 一个件，两种用法
 * ════════════════════════════════════════════════════════════════════════
 *   ① 组内成员：挂 `collapse:` 给一个 QSkinCollapse，展开态由**组**保管
 *      （排他 / 多开都是组的事，见 QSkinCollapse 文件头）
 *   ② 独立使用：不给 `collapse`，自己管自己的 `open`
 *
 * ②这一档不是"顺手支持"，它是覆盖度表里 **shadcn 的 `Collapsible`**
 * 那一格：shadcn 把折叠拆成两个概念 —— `Collapsible` 是"一个能开合的
 * 区域"（无外框、无分隔线），`Accordion` 是在它上面加一组。QSkin 不拆两个
 * 控件，因为**差别只在"有没有组、有没有外框"，而这两件事都能用一个开关
 * 表达**（`collapse: null` + `bordered: false`）。多一个控件就多一份
 * 状态机，而这份状态机与组内成员的那一份完全一样。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 展开态只有**一个**事实来源
 * ════════════════════════════════════════════════════════════════════════
 *     readonly property bool expanded: 组在场 ? 组说了算 : 自己的 open
 *
 * 反过来写（面板自己存一份、再往组里同步一份）会得到一个只在屏幕上现形的
 * 缺陷：组被外部改写（`col.expandedKeys = []`）时，面板那份还亮着。
 * 这与 QSkinRadioGroup 把 checked 单向由组推是同一套约定。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 高度是**动画**的 —— 因此断言必须等它收尾
 * ════════════════════════════════════════════════════════════════════════
 * 内容区的高度在 `0 ↔ 内容自然高` 之间过渡（`Theme.motion.fast`）。
 * 于是任何"展开之后立刻读高度"的断言都会读到**中途值** ——
 * 而那类断言的表现是"大部分时候对、偶尔红"，最难查。
 *
 * 所以本件额外暴露一个**不参与动画**的纯值：
 *
 *     readonly property real contentHeight   // 内容自然高（不含过渡）
 *
 * 判据写"收尾后 height === header 高 + contentHeight"，把动画排除在
 * 等式之外。这是 M22 那条教训（`Popup` 未收尾时量坐标失真）的近亲，
 * 只是这次宿主自己把那个纯值递出来了。
 *
 * 用法：
 *     QSkinCollapse {
 *         QSkinCollapseItem { key: "a"; title: "基本信息"; QSkinBody { text: "…" } }
 *     }
 *
 *     // 独立使用 = shadcn 的 Collapsible
 *     QSkinCollapseItem { title: "高级选项"; bordered: false; QSkinBody { text: "…" } }
 ****************************************************************************/

import QtQuick 2.11
/* Layout.* 附加属性：表头内部那一行是 Layout，得有这一句，
 * 否则 qmllint 报 unknown attached property scope Layout（M22 同样踩过）。 */
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 挂靠的折叠组。不给 = 独立工作（= shadcn 的 Collapsible） */
    property var collapse: null

    /** 组内的唯一键。留空则用**声明序下标**（字符串）——
     *  够用，但重排会换号，所以显式给 key 更稳。 */
    property string key: ""

    /** 表头标题。空则只画 extra / 箭头 */
    property string title: ""

    /** 表头右侧的附加内容（Ant 的 `extra`）。没塞东西就整块不占位 */
    property alias extra: extraHost.data

    /** 内容区（default property） */
    default property alias content: contentHost.data

    /** 禁用：表头不可点、箭头与标题压暗 */
    property bool disabled: false

    /** 独立模式下的展开态。挂组时**读它没用**（组说了算），
     *  但仍可写 —— 写成组分发的那一面，见下面的 expanded。 */
    property bool open: false

    /** 是否显示表头右侧的展开箭头 */
    property bool showArrow: true

    signal toggled()

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property var _group: (root.collapse !== null
                                  && root.collapse !== undefined) ? root.collapse : null

    /** 展开态的唯一事实来源（见文件头）。 */
    readonly property bool expanded: root._group !== null
                                     ? root._group._isExpandedByItem(root)
                                     : root.open

    /** 展开态是否可写 —— 挂组时只有组能改它。UI 用它决定表头可不可点。 */
    readonly property bool _canToggle: !root.disabled
                                       && (root._group === null || root._group.enabled !== false)

    /** 是不是组里的第一块。**第一块不画上分隔线** —— 项目一贯的
     *  "分割线只在条目之间"（QSkinList / QSkinCard 都写过这条）。
     *
     *  用 MemberOrder 而不是"注册时谁先来"：兄弟节点的 onCompleted 是
     *  **逆声明序**触发的，照它排会让"第一块"整体反转。 */
    readonly property bool isFirst: root._group === null
                                    ? true
                                    : (MemberOrder.indexOf(root._group._panels, root) === 0)

    /** 内容区自然高（不含过渡）—— 判据用它把动画排除在等式外。 */
    readonly property real contentHeight: contentHost.implicitHeight

    /** 表头高。它是插件式的（标题字号、extra 里的按钮都可能改它），
     *  所以不外传常量，读实际值。 */
    readonly property real headerHeight: header.implicitHeight

    implicitHeight: root.headerHeight
                    + (root.expanded ? root.contentHeight : 0)
    implicitWidth: 320

    /* ══════════════════════ 分隔线 ══════════════════════
     * 只在"上一条与本条之间"画：第一块不画。最后一块**照画**——
     * 它下面接的是外框底边，不是"另一个条目"。 */
    Rectangle {
        id: divider

        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top

        height: 1
        visible: !root.isFirst && !dividerHidden
        color: Theme.color.divider

        /** 由组统一下达（`bordered: false` 的组里不画线）；
         *  独立使用时没有组，就看自己的 framed。 */
        readonly property bool dividerHidden: root._group !== null
                                              ? root._group.bordered === false
                                              : !root.framed
    }

    /** 独立模式下是否要分隔线（挂组时无用，组说了算）。 */
    property bool framed: true

    /* ══════════════════════ 表头 ══════════════════════ */

    Item {
        id: header

        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top

        implicitHeight: headerRow.implicitHeight

        /* 表头是这一块里**唯一**可点的区域。用 MouseArea 而不是
         * TapHandler：项目既有控件（QSkinAlert 的关闭钮、QSkinTabs）都用
         * MouseArea，保持一致，且 hover 态靠它给。 */
        Rectangle {
            id: headerBg

            anchors.fill: parent

            color: (!root._canToggle) ? "transparent"
                 : headerMouse.containsMouse ? Theme.color.bgSubtle
                                             : "transparent"
            radius: Theme.radius.sm

            Behavior on color {
                ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
            }
        }

        QSkinRow {
            id: headerRow

            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.top:   parent.top

            padding: Theme.space.md
            gap:     Theme.space.sm
            align:   "center"

            /* ── 标题 ──
             * 走 label 插槽。项目的惯例是"标题不许自己画一个 Text"
             * （QSkinDialog / QSkinNotification / QSkinLabel / QSkinAlert 四处都
             * 写了这条），这里照办 —— 换主题时折叠面板的标题与对话框
             * 标题一起变。 */
            Loader {
                id: titleLabel

                sourceComponent: Slots.label
                Layout.fillWidth: true
                visible: root.title !== ""
                active:  root.title !== ""
                opacity: root.disabled ? 0.5 : 1

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

            /* ── 表头右侧附加内容 ──
             * visible 绑 implicitWidth 而不是 `data.length`：空的 QSkinRow
             * 的 implicitWidth 恰好是 0 且可通知，而 list 的 length 不保证
             * 通知（M22 的 QSkinAlert 同款做法）。 */
            QSkinRow {
                id: extraHost

                visible: extraHost.implicitWidth > 0
                gap: Theme.space.xs
                Layout.fillWidth: false
            }

            /* ── 展开箭头 ──
             * 走 chevronIndicator 插槽。它的契约明说「**展开语义不进插槽**」
             * ——宿主自己把"展开还是收起"翻译成 direction：
             *     收起 → "right"，展开 → "down"
             * 这正是那一格当初被设计出来的用法（见它的文件头）。 */
            Loader {
                id: arrowLoader

                visible: root.showArrow
                active:  root.showArrow
                sourceComponent: Slots.chevronIndicator
                Layout.alignment: Qt.AlignVCenter

                Binding {
                    target: arrowLoader.item
                    property: "control"
                    value: arrowCtl
                    when: arrowLoader.status === Loader.Ready
                }
            }

            QtObject {
                id: arrowCtl

                readonly property string direction: root.expanded ? "down" : "right"
                readonly property bool enabled: root._canToggle
            }
        }

        MouseArea {
            id: headerMouse

            anchors.fill: parent
            hoverEnabled: true
            enabled: root._canToggle
            cursorShape: root._canToggle ? Qt.PointingHandCursor : Qt.ArrowCursor

            onClicked: root._toggle()
        }

        /* 键盘：Tab 进得来、空格/回车切换、上下键在组内移动。
         * 用一个不可见的 Item 承载 activeFocus 而不是给 MouseArea ——
         * MouseArea 可以拿焦点，但它的 Keys 处理与 focus 语义在有的平台
         * 上不一致；项目既有控件（QSkinTabs / QSkinCollapse 的兄弟件）用的是
         * "一个 Item + Keys" 这条路。 */
        Item {
            id: keyItem

            anchors.fill: parent
            focus: false
            activeFocusOnTab: root._canToggle

            /* 信号参数必须写成 `function(event)`。写成裸块 `{ … }` 时
             * qmllint 把 event 判为 Unqualified access（QSkinButton:215 /
             * QSkinCheckBox:115 都写过这条）。 */
            Keys.onSpacePressed:  function(event) { root._toggle(); event.accepted = true }
            Keys.onReturnPressed: function(event) { root._toggle(); event.accepted = true }
            Keys.onEnterPressed:  function(event) { root._toggle(); event.accepted = true }

            Keys.onDownPressed: function(event) {
                if (root._group !== null) root._group._moveFocus(root, 1)
                event.accepted = true
            }
            Keys.onUpPressed: function(event) {
                if (root._group !== null) root._group._moveFocus(root, -1)
                event.accepted = true
            }
        }

        /** 焦点环由地基层的 FocusRing 画（项目统一件，别自己画）。
         *  接口是 `control:` 而不是 `target:` —— FocusRing 是"环绕某个
         *  控件"的件，不是动画，写错由 qmllint 报 missing-property。 */
        FocusRing {
            anchors.fill: parent
            control: keyItem
        }
    }

    /* ══════════════════════ 内容区 ══════════════════════
     * 高度在 0 ↔ 内容自然高之间过渡。`clip: true` 是必须的 ——
     * 否则过渡期间内容会**溢出到下面的块上**（它自己那一块已经缩到 0 了，
     * 但里面的孩子还在按自然尺寸画）。 */
    Item {
        id: contentWrap

        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   header.bottom

        height: root.expanded ? root.contentHeight : 0
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Theme.motion.fast
                easing.type: Theme.motion.easing
            }
        }

        QSkinColumn {
            id: contentHost

            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.top:   parent.top

            /* 内边距放在这里而不是 contentWrap 上：内容自然高要包含它，
             * 否则收尾后的高度会短一截（一个只在"量高度"时才现形的差）。
             *
             * `padding` 是**四边统一**的 —— Column 只有这一个内边距接口
             * （`src/foundation/QSkinColumn.qml:34`）。所以表头下方到正文之间是
             * 表头的 md + 正文的 md 两段相加，比"标题紧贴正文"松一档。
             * 这一档是**故意留的**：折叠面板的表头与正文本来就不是同一段
             * 内容（一个是可点区域、一个是被揭示的正文），压在一起会让
             * "点哪里"变得不清楚。首版这里写过 `paddingTop: 0` 想压掉它，
             * 那是照着一个不存在的接口写的（会静默失效）—— 已删。
             * 真要单边控制，得先给 Column 加 per-side 接口，那是改地基层、
             * 有自己的一圈消费者，不在这件里顺手做。 */
            padding: Theme.space.md
            gap: Theme.space.sm
        }
    }

    /* ══════════════════════ 行为 ══════════════════════ */

    function _toggle() {
        if (!root._canToggle) return
        if (root._group !== null) root._group._toggleByItem(root)
        else                      root.open = !root.open
        root.toggled()
    }

    /** 供组调用：把焦点移到这一块的表头（键盘上下键用）。 */
    function _focusHeader() {
        keyItem.forceActiveFocus(Qt.TabFocusReason)
    }

    /* 向组登记。协议与 QSkinRadio / QSkinToggle 一致（见 QSkinRadioGroup 文件头），
     * 只多一步"自己往上找组"—— 理由见下面 _findGroup 的注释。 */
    Component.onCompleted: {
        if (root._group === null) {
            var g = root._findGroup()
            if (g !== null) root.collapse = g
        }
        if (root._group !== null) root._group._register(root)
    }
    Component.onDestruction: if (root._group !== null) root._group._unregister(root)

    /** 沿 `parent` 链找最近的折叠组。找不到就返回 null（= 独立使用）。
     *
     * ── 为什么是成员往上找，而不是组认领自己的孩子 ──────────────────────
     * 组的成员是用 default property 收的，而 `QSkinColumn` 声明了
     * `default property alias data: layout.data` —— 用户写进去的子项最终
     * 是**内部那个 ColumnLayout 的孩子**，不是组的直接孩子。从组那边遍历
     * `children` 只会看到那个 layout，看不到成员。
     *
     * 而这里是"反过来写会静默失效"的现场：首版照 M20 的写法只在
     * `Component.onCompleted` 里登记（`if (root._group !== null) …`），
     * 而 `_group` 来自公开属性 `collapse` —— 于是**没有人去接这根线**：
     * 组是容器，成员却要调用方一个一个写 `collapse: col`。忘了写不会报错，
     * 表现是"点了表头没反应"，而属性侧每个成员自己都自洽。
     *
     * 实测（`.cache/_probe_m23collapse.qml`，退出码 163 → 三条同时红）：
     *   `col._panels.length === 0` · `iA._group === null` ·
     *   `iA.collapse === null` —— 而 `key === "a"`、`_keyOf(iA) === "a"`
     *   （键算得对）、`iA.open === false` 全绿。也就是说**账全对，线没接**。
     *
     * 往上找比"让组去遍历孩子"稳：它不依赖任何一层的内部结构
     * （组里换成 Grid、或者成员外面再包一层容器都不影响）。
     *
     * 判定用组身上的标记，而不是 `typeof p._register === "function"` ——
     * QSkinRadioGroup 也有 `_register`，靠函数名撞运气会接错线。 */
    function _findGroup() {
        var p = root.parent
        var guard = 0
        while (p !== null && p !== undefined && guard < 16) {
            /* `parent` 的静态类型是 QQuickItem，标记名天然不在它上面 ——
             * 鸭子类型的合法场景，项目同款处置见 QSkinProgress.qml 与
             * QSkinAvatarGroup.qml（局部关闭，不在 .qmllint.ini 里全局降级）。
             * 注释首行不要以 qmllint 开头。 */
            // qmllint disable missing-property
            if (p._isCollapseGroup === true) return p
            // qmllint enable missing-property
            p = p.parent
            guard++
        }
        return null
    }

    /* 无障碍：表头是一个"能开合"的按钮。
     *
     * ⚠ 曾经这里还有一行 `Accessible.expanded: root.expanded`，**已删**。
     *   本机 Qt 6.8.3 的 Accessible 附加类型里**没有 expanded** ——
     *   实测属性表（`.qt/6.8.3/mingw_64/qml/QtQuick/plugins.qmltypes`，
     *   `QQuickAccessibleAttached`）只到 role / name / description / id /
     *   ignored / checkable / checked / editable / focusable / focused /
     *   multiLine / readOnly / selected / selectable / pressed /
     *   checkStateMixed / defaultButton / passwordEdit / selectableText /
     *   searchEdit 为止。
     *
     *   于是那一行不是"多写了个没人读的提示"，而是**运行时错误**：
     *   给不存在的属性赋值会让整块对象构造失败。属性断言抓不到它
     *   （对象根本没建成），只有 qmllint 的 missing-property 会报。
     *   读屏因此只能听到"按钮 + 标题"，听不到展开态 —— 这是一笔**已知
     *   缺口**，不是"已经做好了"。 */
    Accessible.role: Accessible.Button
    Accessible.name: root.title
    Accessible.focusable: root._canToggle
}
