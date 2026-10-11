/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinAffix
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 固钉 —— 把一块内容钉在滚动容器的顶部，滚到它要离开视口时就不让它走。
 *
 * 典型场景：表格上方的筛选栏、文档里的章节小标题、详情页的操作条。
 * 原始参照是 Ant / Arco 的 `Affix`。
 *
 * ── 它做的是"占位 + 挪位"，不是"复制一个浮动层" ────────────────────────
 * 天真的做法是再画一个浮动副本，滚过阈值时显示它。那样有两个躲不掉的病：
 *   · 副本要与本体逐像素一致（否则钉住的瞬间会跳一下）
 *   · 本体离场时要在它自己那个位置上，副本要接得上 —— 两处的字号、
 *     内边距、边框都会各自漂移
 * 这里改成本体**挪位**：占位块（本组件）始终留在内容流里撑着高度，
 * 被钉的内容在占位块内部沿 y 平移。屏幕上永远只有一份内容。
 *
 * ── 滚动宿主是**输入**（COVERAGE.md 第七节「M25 五项裁决」之二）─────────
 * 本件不自造滚动。`target` 指向一个 `Flickable`（`QSkinScrollArea` 已经把
 * 它用 `property alias flickable` 交出来了）。这带来两个好处：
 *
 *   1. 抓图能确定性 —— 脚本写 `target.contentY = N`，瞬时、无动画
 *   2. 判定**只有一处**：`QSkin.Foundation.ScrollUtil.affixDeltaY()`。
 *      于是"挪到哪"与"判有没有钉住"是同一个函数、同一个输入，
 *      属性门禁与像素门禁读的是同一个数（M20 那条：
 *      handler 与属性绑定必须走同一条算路）
 *
 * ── 位置怎么算出来的（这里有个容易写错的地方）──────────────────────────
 * `ScrollUtil` 的 `affixOffsetY` 返回的是**视口坐标**，而本组件的子项
 * 是相对本组件定位的。于是子项的 y 应当是**差值**：
 *
 *     childY = affixOffsetY(内容坐标里的 itemY, …) - itemY在视口里的 y
 *
 * 直接用绝对值会让内容多偏一整个 `itemY` —— 屏幕上表现为"钉住的瞬间
 * 整块内容跳到视口顶部"，而它的所有属性断言都还是绿的。
 *
 * `_viewportY` 用 `mapToItem(target, 0, 0)` 求，并且**显式读一次
 * contentY**：`mapToItem` 的结果不会自己跟着滚动更新，这个"假读"是
 * 绑定依赖的唯一来源（M21 在 QSkinPopover 的锚点几何上量出过同一条）。
 *
 * ── 已知边界 ─────────────────────────────────────────────────────────
 * · `holderHeight` 小于内容自身高度时，内容一开屏就会被"顶出去"
 *   （`affixDeltaY` 返回负数）。这是**结构上无解**的：占位块装不下它，
 *   自然没有可以钉的余量。本件不静默夹取，如实呈现。
 * · 只处理竖直方向。横向固钉（吸左/吸右）本项目没有消费者。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    /** 被钉住的内容。放在这里的东西会整体沿 y 平移。 */
    default property alias contentData: contentHost.data

    /* ══════════════════════ 输入 ══════════════════════ */

    /** 滚动宿主，一个 Flickable。null = 不钉（内容就是个普通块）。
     *  `QSkinScrollArea` 的 `flickable` 属性可以直接接过来。 */
    property var target: null

    /** 钉住之后，被钉内容的顶边距**滚动宿主顶边**的距离 */
    property int stickyTop: 0

    /** 内容项之间的间距（透传给承载内容的 QSkinColumn） */
    property int spacing: 0

    /* ══════════════════════ 形状 ══════════════════════ */

    /** 占位块高度。-1 = 由内容撑出。
     *  显式给一个更大的值，可以让"钉住"发生在内容离开之前。 */
    property int holderHeight: -1

    /* ══════════════════════ 派生（判定只在 ScrollUtil 里） ══════════════════════ */

    readonly property real _holderH: root.holderHeight >= 0
                                     ? root.holderHeight
                                     : contentHost.implicitHeight

    readonly property real _itemH: contentHost.implicitHeight

    /** 显式读一次 contentY —— 它是下面那条绑定唯一的依赖来源 */
    readonly property real _scrollY: root.target ? root.target.contentY : 0

    /** 本组件在**内容坐标**里的顶边。
     *
     * ⚠ 映射的目标是 `target.contentItem`，**不是** `target` 本身。
     * 内容项自己的坐标系不随滚动变，所以这一步算出来就是"内容坐标里的 y"，
     * 不必再用 `_scrollY` 反推 —— 而"用滚动量反推"正是本件第一版栽的地方：
     *
     *     第一版： _itemY = _scrollY + mapToItem(target).y
     *
     * `mapToItem` 是一次 **C++ 调用**，它内部读各级父项（含内容项）的位置
     * **不经过** QML 的依赖包装层。内容滚了，引擎不会因此把这条绑定标脏 ——
     * 于是那个 `mapToItem` 的结果**冻在第一帧**，`_itemY` 越滚越离谱，
     * `reached` 永远是 false（钉住/顶出从不触发），而每个属性单独读都自洽。
     *
     * 抓它的是 `tests/smoke_m25.qml` 的 [5] —— 那一条必须在**真 Flickable**
     * 上跑，因为假对象（只造一个 `contentY` 属性）会让 `mapToItem` 的行为
     * 与真宿主完全不同。这与 M24 在 QSkinTour 上记过的是同一条
     * （`tourTarget.y` 动了洞不跟着动），那次靠"把目标真的挪一次"抓到。
     *
     * 第一行的 `root.y` 是**依赖声明**、不是运算数：万一将来这个件被放进
     * 一个会移动的父项里，靠它才建立得起依赖。删了它不会立刻出错，
     * 但会把"M24 那个坑"重新打开。 */
    readonly property real _itemY: {
        root.y
        if (!root.target || !root.target.contentItem) return root.y
        return root.mapToItem(root.target.contentItem, 0, 0).y
    }

    /** 本组件在**视口**坐标里的顶边 = 内容坐标 − 滚过的距离。
     *  这一条依赖 `_scrollY`（而 `_scrollY` 依赖 `target.contentY`），
     *  所以它会跟着滚动重算 —— 上面那段注释讲的就是"为什么不能反过来算"。 */
    readonly property real _viewportY: root._itemY - root._scrollY

    /** 被钉内容相对原位的偏移。>0 往下让、0 在原位、<0 被顶出去。 */
    readonly property real _deltaY:
        ScrollUtil.affixDeltaY(root._itemY, root._holderH, root._itemH,
                               root._scrollY, root.stickyTop)

    /** 已经滚到线了（内容本该离开视口） */
    readonly property bool reached: root.target !== null
                                    && root._viewportY < root.stickyTop

    /** 此刻**正钉在** stickyTop 上（到线了，且还没被占位块的底边顶走） */
    readonly property bool pinned: root.reached && root._deltaY > 0

    /** 被顶出去了（占位块的底边已经把它推回内容流里） */
    readonly property bool pushedOut: root.reached && root._deltaY < 0

    /* ══════════════════════ 几何 ══════════════════════ */

    implicitWidth:  contentHost.implicitWidth
    implicitHeight: root._holderH

    /* 钉住时抬到同层兄弟之上 —— 否则会被后面的内容盖住。
     * 不在拖动过程中改 z（那会让绘制顺序抖），只在"钉住/未钉住"两态之间切。 */
    z: root.pinned ? 1 : 0

    QSkinColumn {
        id: contentHost

        y: root._deltaY
        width: root.width
        gap: root.spacing
    }

    Accessible.role: Accessible.Grouping
}
