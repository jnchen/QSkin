/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinDescriptions
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 描述列表（M24）—— 一串「标签 : 值」按网格排开。订单详情、用户资料、
 * 配置摘要都用它。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 它为什么是个**容器**（而不是"数组 + delegate"）
 * ════════════════════════════════════════════════════════════════════════
 * 参照实现里 `items` 是一个数据数组（`{label, children, span}`）。本仓不
 * 走那条路，理由与本项目一贯的取舍一致：**值常常不是字符串，而是一段
 * 真实内容** —— 一个 QSkinSwitch、一枚 QSkinTag、一段带链接的说明。
 * 把它们塞进数组意味着每个调用方都要写 `Component` 或字符串化的
 * 富文本，而 QML 里"直接写进去"才是自然的（QSkinCollapse 同款判断）。
 *
 * 代价说清楚：数据驱动能做的事（从后端 JSON 直接铺一屏）这里做不了，
 * 得用 Repeater 自己铺 —— 但那本来就不该由"描述列表"承担。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 两种排布 × 两种外观，四个组合都要成立
 * ════════════════════════════════════════════════════════════════════════
 *     layout: horizontal | vertical     —— 标签在值的左边 / 上边
 *     bordered: true | false           —— 画表格线 / 只排内容
 *
 * 四家在这一处的差异是**行为性**的（不是颜色）：
 *   · Ant      `layout` 两值都有，`bordered` 画完整表格（label 列 + value 列）
 *   · Arco     同 Ant，另有 `size`
 *   · TDesign  只有水平排布；它的"表格化"是另一种组件
 *   · shadcn   没有这一件（覆盖表里记作 —）
 * 所以 `layout` 与 `bordered` 都是**正交的开关**，而不是两个组件。
 *
 * ════════════════════════════════════════════════════════════════════════
 * `span` 是怎么落到网格上的：**累计跨度**，不是"第几个"
 * ════════════════════════════════════════════════════════════════════════
 * 成员要么占 1 格，要么占 N 格（`span`）。于是"我在第几列"不能数下标 ——
 * 下标与列号在有 span 的序列里根本不同。本件算的是**累计跨度**：
 *
 *     offset(i) = Σ span(0..i-1)        col = offset % column
 *                                       row = floor(offset / column)
 *
 * 表格线只画在"左邻居存在"与"上邻居存在"的位置 —— 也就是
 * `col > 0` / `row > 0`。外框由**容器**画，于是最后一行不满时，
 * 右侧那片补白**不会**出现"缺一格边框"的洞（本仓取法：宁可让它看起来
 * 像一格被合并的空格，也不要一串不存在的空单元格 —— 后者会引入
 * "空格子占不占 span"的歧义）。
 *
 * 成员顺序由 `MemberOrder.sortByDeclaration` 矫正 —— 兄弟节点的
 * `onCompleted` 是**逆声明序**触发的（见 MemberOrder.qml 文件头）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 标签宽度是**全组统一**的，而且是量出来的
 * ════════════════════════════════════════════════════════════════════════
 * 一列"标签"如果每条各按各的宽度走，值就会参差不齐 —— 而"参差不齐"
 * 恰恰是这一件要消灭的东西。所以：
 *
 *     labelWidth = -1（默认）→ 取**所有成员里最宽的那个标签**的实际宽度
 *     labelWidth >= 0        → 用宿主给的值
 *
 * 宽度取的是**渲染出来的**那个 label（`labelLoader.item.implicitWidth`），
 * 不是另起一个 Text 自己量 —— 后者会在主题把 label 换掉（字重/字号变）
 * 之后量出错的数。这与 QSkinDivider 量它自己的 label 是同一手法。
 *
 * 用法：
 *     QSkinDescriptions {
 *         column: 2
 *         QSkinDescriptionsItem { label: "订单号"; Body { text: "SO-2026-0914" } }
 *         QSkinDescriptionsItem { label: "备注"; span: 2; Body { text: "…" } }
 *     }
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 每行放几组「标签 : 值」（Ant 的 `column`） */
    property int column: 3

    /** 标签相对值的位置：horizontal（左）| vertical（上） */
    property string layout: "horizontal"

    /** 画表格线。关掉就是"只排内容"的那一档 */
    property bool bordered: false

    /** 区块标题 / 右上角附加说明（都可以留空） */
    property string title: ""
    property string extra: ""

    /** 标签列统一宽度。−1 = **自动**（取最宽的那个标签，见文件头） */
    property real labelWidth: -1

    /** 水平排布时，标签与值之间是否画冒号 */
    property bool colon: true

    /** 网格间距（bordered 时内部为 0 —— 格线要共边，不能留缝） */
    property int gap: Theme.space.lg

    /** 成员（default property） */
    default property alias items: grid.data

    signal itemClicked(int offset)

    /** 成员沿 `parent` 链往上找组时认这个标记（与 QSkinCollapse 同一协议）。 */
    readonly property bool _isDescriptionsGroup: true

    readonly property bool _vertical: root.layout === "vertical"

    /* ══════════════════════ 成员登记 ══════════════════════
     * 协议与 QSkinCollapse 完全同源（那边文件头有完整论证）：
     * 成员自己沿 `parent` 链找上来，调用方不用写 `group:`；
     * 顺序交给 MemberOrder 按声明序矫正。 */

    property var _members: []

    function _register(item) {
        if (item === null || item === undefined) return
        if (root._members.indexOf(item) >= 0) return
        var out = root._members.slice()
        out.push(item)
        root._members = MemberOrder.sortByDeclaration(out)
    }

    function _unregister(item) {
        var i = root._members.indexOf(item)
        if (i < 0) return
        var out = root._members.slice()
        out.splice(i, 1)
        root._members = out
    }

    /** 排在给定成员**之前**的那些成员的跨度之和 —— 也就是它的网格偏移。
     *  找不到成员时返回 0（宿主可能在成员还没挂上来时先问一句）。 */
    function _offsetOf(item) {
        var list = root._members
        var at = list.indexOf(item)
        if (at < 0) return 0
        var sum = 0
        for (var i = 0; i < at; ++i) sum += root._spanOf(list[i])
        return sum
    }

    function _spanOf(item) {
        if (item === null || item === undefined) return 1
        var s = item.span
        if (typeof s !== "number" || !isFinite(s) || s < 1) return 1
        return Math.min(Math.round(s), Math.max(1, root.column))
    }

    /** 标签列的统一宽度（见文件头）。 */
    readonly property real _uniformLabelWidth: {
        if (root.labelWidth >= 0) return root.labelWidth
        var list = root._members
        var best = 0
        for (var i = 0; i < list.length; ++i) {
            var w = list[i] !== null && list[i] !== undefined
                    ? list[i].labelWidthHint : 0
            if (typeof w === "number" && w > best) best = w
        }
        return best
    }

    /* ══════════════════════ 视觉 ══════════════════════ */

    implicitWidth:  480
    implicitHeight: outer.implicitHeight

    width:  implicitWidth
    height: implicitHeight

    /* 表格外框。**由容器画** —— 让每格自己画一圈框会在相邻格之间得到
     * 双线（2px），而"分割线只在条目之间"是本项目一以贯之的规矩。 */
    Rectangle {
        id: frame

        anchors.fill: parent
        visible: root.bordered
        color:   "transparent"
        border.width: 1
        border.color: Theme.color.border
        radius: Theme.radius.sm
    }

    QSkinColumn {
        id: outer

        x: 0
        y: 0
        width: root.width
        gap: root.title !== "" || root.extra !== "" ? Theme.space.md : 0
        padding: 0

        /* ── 区块标题行 ──
         * 标题走 label 插槽（本项目"标题不许自己画一个 Text"）。
         * 空白用 `Layout.fillWidth` 的 Spacer 顶开，而不是给说明文字
         * 加 fillWidth —— 后者会把说明文字拉到与标题同宽再左对齐，
         * 右对齐就没了。 */
        QSkinRow {
            id: header

            Layout.fillWidth: true
            visible: root.title !== "" || root.extra !== ""
            gap: Theme.space.sm
            padding: 0

            Loader {
                id: titleLabel

                sourceComponent: Slots.label
                active: root.title !== ""
                visible: root.title !== ""
                Layout.alignment: Qt.AlignVCenter

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

            Spacer { Layout.fillWidth: true }

            Caption {
                Layout.alignment: Qt.AlignVCenter
                visible: root.extra !== ""
                text: root.extra
            }
        }

        QSkinGrid {
            id: grid

            fill: true
            columns: Math.max(1, root.column)
            /* bordered 时内部间距必须是 0：格线要共边。留一点缝就会出现
             * "两条 1px 之间夹一条背景色"的假双线。 */
            gap: root.bordered ? 0 : root.gap
            padding: 0
        }
    }
}
