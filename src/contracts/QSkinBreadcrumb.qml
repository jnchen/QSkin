/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinBreadcrumb
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 面包屑 —— 显示"我在层级里的哪个位置"。
 *
 * ── 三个设计约束（都来自"路径会很长"这个现实）──────────────────────────
 *
 *   1. **最后一项不可点**。它是"你当前所在的位置"，不是一个可以跳转的
 *      目标 —— 点它等于原地刷新。各大设计系统都把它渲染成不可交互的
 *      强文字。所以它走 label 的 "text" variant（强前景），其余走 "ghost"。
 *
 *   2. **中间项可折叠**。路径长到 6、7 层时，面包屑会撑爆容器。
 *      策略是在中间塞一个"…"按钮，点开才展开。折叠保留**首项 +
 *      末两项**，中间全收起 —— 这是 Ant Design 的默认策略，
 *      因为首项（首页/根目录）和末两项（当前上下文）信息量最大。
 *
 *   3. **分隔符是主题的事**。TDesign 用 "/"，Ant 用 "/"，shadcn 用 "›"，
 *      Arco 用 ">"。所以分隔符不是硬编码字符，而是插槽（breadcrumbSeparator）——
 *      与 tabIndicator 同属"indicator 家族"。
 *
 * ── 复用 label 插槽的第二个证明点 ──────────────────────────────────────
 * 面包屑每一项都是"一段可点或不可点的文字"，与 Tabs 页签、按钮文字
 * 是同一类东西。三项都走 Slots.label，主题不用为面包屑写任何排版代码。
 * 与 Progress、Tag 合起来，M10 五个控件中有三个做到了零新排版插槽。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 字符串数组，或对象数组（配 textRole）。
     *  最后一项自动视为"当前位置"，不可点击。 */
    property var model: null

    property string textRole: ""

    /* ══════════════════════ 外观 ══════════════════════ */

    /** 项之间是否留空（分隔符两侧的间距由插槽自己决定） */
    property int gap: Theme.space.sm

    /* ══════════════════════ 行为 ══════════════════════ */

    /** 是否允许折叠中间项。关掉则全部展开（路径短时更好看）。 */
    property bool collapsible: true

    /** 折叠时保留的**末尾**项数。首项永远保留。
     *  设为 2 = 首页 / … / 父级 / 当前。 */
    property int keepLast: 2

    /** 中间段当前是否展开 */
    property bool expanded: false

    /** 用户点击了第 index 项（最后一项不会触发） */
    signal activated(int index)

    readonly property int count: _countOf()

    /** 是否需要折叠：项数超过"首 1 + 末 keepLast + 省略号自身" */
    readonly property bool _needsCollapse:
        root.collapsible && !root.expanded && root.count > root.keepLast + 2

    /* ══════════════════════ 尺寸 ══════════════════════ */

    implicitWidth:  crumbRow.implicitWidth
    implicitHeight: Math.max(Theme.size.controlSm, crumbRow.implicitHeight)

    width:  implicitWidth
    height: implicitHeight

    /* ── 用法前提（与 ButtonBar 的 fill 同类）────────────────────────
     *
     * QSkinBreadcrumb 是"宽度等于内容"的控件（上面两行）。这意味着
     * **不要把一个依赖本控件宽度的子项锚进它内部**：
     *
     *     QSkinBreadcrumb {                     // ✗ 会互相牵扯
     *         QSkinButton { anchors.right: parent.right }   // 父宽 ← 内容宽
     *     }                                               // 子位 ← 父宽
     *
     * 这会让隐式宽度在"含按钮"与"不含按钮"之间来回收敛，实测结果
     * 是面包屑被压扁、首项被省略成 "首…"。
     *
     * 反过来，子项若锚在 parent.right **之外**（x 为正、超出右边界）
     * 则不参与隐式宽度，是安全的 —— 但可读性差。
     *
     * 推荐：需要并排放按钮时，外层套一个 QSkinRow，两者做兄弟。
     * 这与 foundation 层 ButtonBar 那条"width 由 Layout 决定，
     * 组件自己不去写 width"的教训是同一个根源：
     * 组件一旦把 width 绑到 implicitWidth，就不再容忍内部有
     * "反向依赖父宽"的布局。 */

    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("面包屑导航")

    /* ══════════════════════ 排布 ══════════════════════
     *
     * 用 Repeater + 一个**扁平的条目序列**，而不是"项 + 分隔符"交替。
     * 交替写法会让折叠状态下的下标计算变复杂（省略了一项要同时删掉
     * 它后面的分隔符）。这里先生成"要显示什么"的序列，再画。 */

    QSkinRow {
        id: crumbRow

        anchors.verticalCenter: parent.verticalCenter
        gap: root.gap
        align: "center"

        Repeater {
            model: root._visibleEntries()
            delegate: crumbComp
        }
    }

    /* delegate 里引用了外层 id（root / Slots）—— inline Component 的
     * 静态检查局限，与 QSkinTabs / QSkinSelect 同款，局部关闭即可。 */
    // qmllint disable unqualified

    Component {
        id: crumbComp

        Item {
            id: crumb

            required property var modelData
            required property int index

            /* modelData 的形状（由 _visibleEntries() 保证）：
             *   { kind: "crumb" | "separator" | "ellipsis",
             *     text: string, srcIndex: int, last: bool } */

            readonly property bool isCrumb:     crumb.modelData.kind === "crumb"
            readonly property bool isSeparator: crumb.modelData.kind === "separator"
            readonly property bool isEllipsis:  crumb.modelData.kind === "ellipsis"

            implicitWidth:  crumbLoader.implicitWidth
            implicitHeight: root.implicitHeight

            /* ── 文字项 / 省略号 ── */
            Loader {
                id: crumbLoader

                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)

                /* 分隔符走独立的插槽；文字与省略号走 label */
                sourceComponent: crumb.isSeparator ? Slots.breadcrumbSeparator
                                                   : Slots.label

                Binding {
                    target: crumbLoader.item
                    property: "control"
                    value: crumb
                    when: crumbLoader.item !== null
                }
            }

            /* label 插槽的宿主契约（与 Tabs 页签同款） */
            readonly property string text: crumb.isEllipsis
                                           ? "…" : (crumb.modelData.text || "")
            /* 最后一项是"当前位置" → 强前景；其余 → 弱前景。
             * 这正是 label 插槽已有的两个 variant，不用新词。 */
            readonly property string variant: crumb.modelData.last ? "text" : "ghost"
            readonly property int    labelAlignment: Text.AlignLeft

            /* 位置信息给分隔符插槽读 */
            readonly property bool last: crumb.isSeparator
                                         ? crumb.modelData.last === true
                                         : crumb.modelData.last === true

            property bool hovered: false
            property bool pressed: false

            /* 当前位置与分隔符不可点 —— 这一条决定了键盘导航的范围 */
            readonly property bool interactive:
                crumb.isEllipsis || (crumb.isCrumb && crumb.modelData.last !== true)

            Accessible.role: crumb.interactive ? Accessible.Link : Accessible.StaticText
            Accessible.name: crumb.text
            Accessible.onPressAction: {
                if (crumb.isEllipsis) root._expand()
                else root._activate(crumb.modelData.srcIndex)
            }

            MouseArea {
                anchors.fill: parent
                enabled: crumb.interactive
                hoverEnabled: true
                cursorShape: crumb.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

                onEntered:  crumb.hovered = true
                onExited:   crumb.hovered = false
                onCanceled: crumb.pressed = false
                onReleased: crumb.pressed = false
                onPressed:  crumb.pressed = true

                onClicked: {
                    if (crumb.isEllipsis) root._expand()
                    else root._activate(crumb.modelData.srcIndex)
                }
            }
        }
    }

    // qmllint enable unqualified

    /* ══════════════════════ 内部 ══════════════════════ */

    function _countOf() {
        var m = root.model
        if (m === null || m === undefined) return 0
        if (typeof m === "number") return m
        if (typeof m.get === "function") return m.count
        return m.length
    }

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

    /** 生成"要画什么"的扁平序列 —— 见排布那段的说明。 */
    function _visibleEntries() {
        var n = root.count
        var out = []
        if (n === 0) return out

        /* 决定要保留哪些原始下标 */
        var keep = []
        if (!root._needsCollapse) {
            for (var i = 0; i < n; ++i) keep.push(i)
        } else {
            keep.push(0)                                   /* 首项永远保留 */
            for (var j = Math.max(1, n - root.keepLast); j < n; ++j) keep.push(j)
        }

        for (var k = 0; k < keep.length; ++k) {
            /* 折叠时，在首项与"保留的末段"之间插入省略号 */
            if (root._needsCollapse && k === 1) {
                out.push({ kind: "ellipsis", text: "…", srcIndex: -1, last: false })
                out.push({ kind: "separator", text: "", srcIndex: -1, last: false })
            }
            if (k > 0 && !(root._needsCollapse && k === 1)) {
                out.push({ kind: "separator", text: "", srcIndex: -1, last: false })
            }
            var idx = keep[k]
            out.push({
                kind: "crumb",
                text: root._textOf(idx),
                srcIndex: idx,
                last: idx === n - 1
            })
        }
        return out
    }

    function _expand() {
        root.expanded = true
    }

    function _activate(i) {
        if (i < 0 || i >= root.count) return
        if (i === root.count - 1) return       /* 当前位置不可点 */
        root.activated(i)
    }
}
