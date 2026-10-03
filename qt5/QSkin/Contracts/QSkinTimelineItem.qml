/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinTimelineItem
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 时间轴上的**一条**（M23）：一颗点 + 一条连接线 + 一段内容。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这一件真正的难点是**连接线画到哪为止**
 * ════════════════════════════════════════════════════════════════════════
 * 时间轴读起来是一条**穿过所有点的线**，而不是"N 段各自带线的行"。
 * 差别落在两个端点上，而且是这条控件唯一的"形状"问题：
 *
 *     第一颗点**之上**不画线（线是从第一个点开始的，不是从行顶）
 *     最后一颗点**之下**不画线（线到最后一个点为止）
 *
 * 这条规则只由**全序**决定，也就是"我是不是第一/最后一个" ——
 * 而那件事得由组来答（兄弟节点的 onCompleted 是逆声明序的，
 * 数不了）。所以本件把两段线拆开画：
 *
 *     上段线  y ∈ [0, dotCenterY − dotSize/2]      仅 `!first` 时可见
 *     下段线  y ∈ [dotCenterY + dotSize/2, 行底]    仅 `!last` 时可见
 *
 * **为什么值得单列一条**：属性侧"我是不是最后一个"是对的，而线照样可能
 * 画到行底 —— 那是一个**只在渲染上存在**的缺陷，像素核验要量的正是
 * "第一行点上方无墨 / 最后一行点下方无墨"。这是本批判据里最值钱的一条。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 点在竖直方向对齐**内容首行**的中线
 * ════════════════════════════════════════════════════════════════════════
 * 不是"对齐行的顶部"，也不是"居中于整块内容" —— 内容有三行时，
 * 居中的点会落在第二行旁边，读起来像错位。
 *
 * 所以点的中心跟着**内容的第一个孩子**走（它的高度就是首行的高度）。
 * 内容为空时退回到"贴着顶部一小段距离"，免得点跑到行中间去。
 *
 * ── 刻意**没做**的（消费者为零）────────────────────────────────────────
 *   · `pending`（Ant / Arco 的"待续"条目）—— 它要一条**虚线**，
 *     而本项目的令牌表里没有"虚线"这个概念（只有 color / space / radius /
 *     font / size / motion）。为一个消费者扩令牌面不划算。
 *   · `mode: right | alternate`（Ant 的左右分布）—— 那是**排列方向**，
 *     不是时间轴的语义。要一个镜像的时间轴，该由调用方翻转布局容器，
 *     而不是让控件再长一套左右两列的排法（与 QSkinRadioGroup 不当
 *     positioner 是同一条判据）。
 *   · `disabled` —— 兄弟件 `QSkinCollapseItem` 有这一格（它要拦点击、要变灰），
 *     这里**不跟**：时间轴是**展示**件，本件一个 MouseArea 都没有，
 *     给一个不影响任何行为的属性只会让读接口的人以为"可以禁用某一条"。
 *     Ant / Arco 的 `Timeline.Item` 也同样没有这一格 —— 这是"参照实现一致 +
 *     语义上本就不该有"的双重理由，不是漏做。
 *   · 自定义点**内部**的图标 —— 那是调用方要塞的东西，走 `dotContent`。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 挂靠的时间轴。不给则视为"只有一条"（first 与 last 同时为真） */
    property var timeline: null

    /** 语义色档：default | primary | success | warning | danger（未知按 default） */
    property string type: "default"

    /** 直接指定点的颜色。给了它就不再看 `type`（与 `type` 二者取一） */
    property color color: "transparent"

    /** 标签（时间 / 状态说明），画在内容**上方的一行小字**。空则不占位 */
    property string label: ""

    /** 内容（default property） */
    default property alias content: contentHost.data

    /** 自定义点。塞了东西就用它，内置的点让位（Ant 的 `dot`） */
    property alias dotContent: dotHost.data

    /** 点直径。宿主给 —— 它要与两侧文字的基线对齐，是**行节奏**的一部分 */
    property int dotSize: 10

    /** 与下一条之间的呼吸空间。
     *
     *  由**条目自己**承担而不是容器的 `gap`：容器的 gap 会在两个条目的
     *  盒子之间留出真空，而那一段是**没人画线**的 —— 连接线就断了。
     *  容器因此固定 `gap: 0`（见 QSkinTimeline 文件头）。
     *
     *  最后一条**不留**：它下面本来就没有下一条，留了只是多一截空白。 */
    property int bottomGap: Theme.space.md

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property var _group: (root.timeline !== null
                                  && root.timeline !== undefined) ? root.timeline : null

    /** 全序。没有组时**两个都真** —— "只有一条"时上面与下面都不画线。 */
    readonly property bool isFirst: root._group === null
                                    ? true
                                    : (MemberOrder.indexOf(root._group._items, root) === 0)

    readonly property bool isLast: root._group === null
                                   ? true
                                   : MemberOrder.isLast(root._group._items, root)

    /* ══════════════════════ 成员登记 ══════════════════════
     * 与 QSkinCollapseItem 同一套协议（那边有完整论证与实测）：成员在
     * onCompleted 里**自己沿 parent 链找组**，然后向它登记。
     *
     * ⚠ 首版这里**整段漏了** —— 而症状是静默的：`_group` 永远是 null，
     *   于是 `isFirst` / `isLast` **双双恒真**，表现为"每条时间轴的上下
     *   两段线都不画"（只有一串孤立的点）。属性侧每个条目自己都自洽。
     *   这一条由 tests/smoke_m23.qml 的 [5] 守着（它读中间那条的上下两段线：
     *   `up2.visible === true && dn2.visible === true`）。 */
    Component.onCompleted: {
        if (root._group === null) {
            var g = root._findGroup()
            if (g !== null) root.timeline = g
        }
        if (root._group !== null) root._group._register(root)
    }
    Component.onDestruction: if (root._group !== null) root._group._unregister(root)

    /** 沿 `parent` 链找最近的时间轴（判定用组身上的标记，理由同
     *  QSkinCollapseItem：靠函数名撞运气会接错线）。找不到 = 只有一条。 */
    function _findGroup() {
        var p = root.parent
        var guard = 0
        while (p !== null && p !== undefined && guard < 16) {
            /* `parent` 的静态类型是 QQuickItem，标记名天然不在它上面 ——
             * 鸭子类型的合法场景，项目同款处置见 QSkinProgress.qml。
             * 注释首行不要以 qmllint 开头。 */
            // qmllint disable missing-property
            if (p._isTimelineGroup === true) return p
            // qmllint enable missing-property
            p = p.parent
            guard++
        }
        return null
    }

    /** 自定义点在场时，内置点让位。用 implicitWidth 判而不是 `data.length`：
     *  空容器的隐式宽恰好是 0 且可通知（QSkinAlert 记过这条）。 */
    readonly property bool hasCustomDot: dotHost.implicitWidth > 0

    /** 点的中心线（相对本件）：对齐**内容列里第一条真正可见的行**的中线。
     *
     *  ⚠ 三条坑，全部实测过（`.cache/_probe_m23tl.qml`）：
     *
     *  ① **不能直接读 `contentHost.children[0]`**。`QSkinColumn` 是一个 Item
     *     套着内部的 ColumnLayout（见 `QSkinColumn.qml`），用户写进去的东西与
     *     `label` 最终都是**那个 layout 的孩子**。所以
     *     `contentHost.children` 只有一个元素 —— 那个 layout，读它的 height
     *     得到的是"整块内容的高度"，于是点会落到**两行的分界**上。
     *     实测就是这一条：标签与正文两行时点被算到两个中点之间
     *     （探针 bit6 红），而**单行时它碰巧是对的** —— 最难查的那一类。
     *  ② **要跳过 `visible: false` 的行**：`label` 常常是空的（不可见、高 0）。
     *     不跳的话，"有 label 但 label 为空"的调用会算出 0 高、点跑到行顶上去。
     *  ③ 真正要找的是"**穿过包装层之后**的第一块有高度的可见行" ——
     *     包装层的特征很明确：那一层**只有一个孩子**。 */
    readonly property real dotCenterY: {
        var row = root._firstRow()
        if (row === null) return root.dotSize / 2 + Theme.space.xxs
        return contentHost.y + row.y + row.height / 2
    }

    /** 内容列里第一条"真正的行"。返回 null = 内容还是空的。
     *
     *  从 contentHost 起，取**当前这一层**里第一条可见且有高度的孩子；
     *  若这一层只有一个孩子，那它就是包装层（`QSkinColumn` 内部的
     *  ColumnLayout 正是），继续往下钻。`guard` 是死循环保险。 */
    function _firstRow() {
        var host = contentHost
        var guard = 0
        while (host !== null && host !== undefined && guard < 8) {
            var cs = host.children
            if (cs === undefined || cs.length === 0) return null
            var first = null
            for (var i = 0; i < cs.length; ++i) {
                var c = cs[i]
                if (c === null || c === undefined) continue
                if (c.visible === false) continue
                if (!(c.height > 0)) continue
                first = c
                break
            }
            if (first === null) return null
            if (cs.length === 1 && first.children !== undefined
                    && first.children.length > 0) {
                host = first
                guard++
                continue
            }
            return first
        }
        return null
    }

    readonly property real dotCenterX: dotSize / 2

    implicitWidth: 320
    implicitHeight: Math.max(contentHost.implicitHeight, dotSize)
                    + (root.isLast ? 0 : root.bottomGap)

    /* ══════════════════════ 连接线 ══════════════════════
     * 两段分开画，各自带自己的可见性条件（见文件头）。 */
    Rectangle {
        id: lineAbove

        x: Math.round(root.dotCenterX - width / 2)
        y: 0
        width: 2
        height: Math.max(0, root.dotCenterY - root.dotSize / 2)

        visible: !root.isFirst && height > 0
        color: Theme.color.divider
    }

    Rectangle {
        id: lineBelow

        x: Math.round(root.dotCenterX - width / 2)
        y: root.dotCenterY + root.dotSize / 2
        width: 2
        height: Math.max(0, root.height - y)

        visible: !root.isLast && height > 0
        color: Theme.color.divider
    }

    /* ══════════════════════ 点 ══════════════════════ */

    Item {
        id: dotSlot

        x: 0
        y: root.dotCenterY - root.dotSize / 2
        width:  root.dotSize
        height: root.dotSize

        visible: !root.hasCustomDot

        Loader {
            id: dotLoader

            anchors.fill: parent
            sourceComponent: Slots.timelineDot

            Binding {
                target: dotLoader.item
                property: "control"
                value: dotCtl
                when: dotLoader.status === Loader.Ready
            }
        }

        QtObject {
            id: dotCtl

            readonly property string type: root.type
            readonly property bool   last: root.isLast
            readonly property int    dotSize: root.dotSize
            /* 只在调用方显式给了颜色时才外传（透明 = 没给），
             * 否则由插槽按 type 自己推 —— 颜色该怎么算属于主题。 */
            readonly property var color: root.color.a > 0 ? root.color : undefined
        }
    }

    /** 自定义点的容器。没塞东西时它是个空 Item，不占位。 */
    Item {
        id: dotHost

        x: 0
        y: root.dotCenterY - root.dotSize / 2
        width:  root.dotSize
        height: root.dotSize

        visible: root.hasCustomDot
    }

    /* ══════════════════════ 内容 ══════════════════════
     * 左内边距 = 点直径 + 点与内容之间的固定间隙。
     * 间隙取 `space.md`（与 QSkinList / QSkinCard 的行内边距同一个档），
     * 这样时间轴放进卡片里时不会显得比别处紧。 */
    QSkinColumn {
        id: contentHost

        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top

        anchors.leftMargin: root.dotSize + Theme.space.md

        gap: Theme.space.xxs

        /* 标签：一行小字。它属于"文字"，走 Caption（地基层的文本件），
         * 不自己画 Text —— 与 QSkinAlert 用 Body 是同一条约定。 */
        Caption {
            Layout.fillWidth: true
            visible: root.label !== ""
            text: root.label
            tone: "muted"
        }
    }

    /* 无障碍：读屏把一条时间轴读成"一条带标签的条目"。
     * 名字取标签（没有则取内容里的文字由读屏自己走）。 */
    Accessible.role: Accessible.ListItem
    Accessible.name: root.label
}
