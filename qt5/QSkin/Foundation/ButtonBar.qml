/****************************************************************************
 * QSkin · Quick Design System — Foundation / ButtonBar
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 按钮布局系统 —— 注意它解决的不是"按钮长什么样"（那是主题层的事），
 * 而是"按钮该怎么排"。这是纯逻辑、与 UI 无关的部分，因此属于地基层。
 *
 * 它替你处理三件容易做错、又没人愿意反复写的事：
 *
 *   1. 平台顺序
 *      macOS / Linux：主按钮在右（"取消  确定"）
 *      Windows：      主按钮在左（"确定  取消"）
 *      followPlatform: true 时自动处理 —— 业务永远按"主按钮写在最后"来写代码，
 *      由 ButtonBar 决定它最终显示在左边还是右边。
 *
 *   2. 危险操作的安全间距
 *      "删除"和"确定"紧挨着极易误点。把危险按钮的**声明下标**写进
 *      dangerIndexes，ButtonBar 会在它两侧自动插入更大的间距。
 *
 *   3. 窄屏堆叠
 *      宽度不足时自动改为纵向堆叠，且主按钮在上（优先命中）。
 *
 * 示例：
 *     ButtonBar {
 *         align: "end"
 *         dangerIndexes: [0]
 *         QSkinButton { text: "删除" }        // index 0，危险
 *         QSkinButton { text: "取消" }        // index 1
 *         QSkinButton { text: "确定" }        // index 2，主按钮
 *     }
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    /** 按钮之间的基础间距 */
    property int gap: Theme.space.sm

    /** 内边距 */
    property int padding: 0

    /** 整体对齐：start | center | end */
    property string align: "end"

    /**
     * 主按钮的声明下标；-1 表示"最后一个"。
     * 业务代码请统一把主按钮写在最后，由平台规则决定它最终显示在左还是右。
     */
    property int primaryIndex: -1

    /** 是否按平台规则调整主按钮位置（Windows 主按钮在左） */
    property bool followPlatform: true

    /** 危险按钮的声明下标列表，例如 [0] */
    property var dangerIndexes: []

    /** 危险按钮与主按钮之间的额外安全间距 */
    property int extraGapBeforeDanger: Theme.space.xl

    /** 窄屏是否自动堆叠为纵向 */
    property bool stackWhenNarrow: true

    /** 低于此宽度触发堆叠 */
    property int stackBelow: 320

    /** 是否声明想撑满父容器宽。
     *
     *  在 Layout（如 ColumnLayout / QSkinColumn）里写 fill: true，ButtonBar
     *  会被拉到容器全宽，再按 align 把按钮推到 start / center / end ——
     *  表单操作区、对话框 footer 的标准姿势。
     *
     *  QSkinRow + Spacer 也能达到同样效果，但 fill:true 更直接：一条属性
     *  就表达"这一行撑满"，不必额外摆一个 Spacer。
     *
     *  ┌── 前提：必须有一个 Layout 祖先 ──────────────────────────────┐
     *  │ 本属性的实现是 Layout.fillWidth（见下方），而 Layout 附加属性  │
     *  │ 只在 **Layout 容器**（ColumnLayout / QSkinColumn / RowLayout …） │
     *  │ 里才有意义。把 ButtonBar 直接塞进裸 Item 再写 fill: true，   │
     *  │ 没有任何东西去执行这条指令 —— 宽度会停在 implicitWidth 上，   │
     *  │ align: "end" 也就推不动（availW == flatW，x0 恒为 0）。      │
     *  │ 这是用法前提，不是组件缺陷；需要撑满时请放进 Layout。        │
     *  └───────────────────────────────────────────────────────────────┘
     *
     *  注：M9 曾记录「fill:true 与 width:implicitWidth 相互牵制」。
     *  后续复测澄清了这件事的两半：
     *    · 「放进 Layout 后 fill 正常」—— 结论正确（Windows / Qt 6.8.3
     *      实测 width 被 Layout 拉到 760，右对齐精确到位）；
     *    · 「裸 Item 里失效是探针假象」—— 结论错误。裸 Item 里它是真的
     *      失效，原因就是上面那段前提，与探针无关。 */
    property bool fill: false

    /** 当前是否堆叠布局（只读）。hug 模式永远 false —— M3 老 bug
     *  让 hug 状态误堆叠并永久锁死；M9 起 stacked=false 等价于"横排"。
     *  窄约束下，flatW 超出可用宽度或可用宽度低于 stackBelow 时为 true */
    readonly property alias stacked: d.stacked

    /** 子项隐式尺寸之和（只读）。
     *
     *  ┌── 它是"哨兵"，不是"数据" ────────────────────────────────────┐
     *  │ 这个属性本身没什么用（谁也不会去读它），它的价值在于**读出**   │
     *  │ 了每个子项的 implicitWidth / implicitHeight。QML 引擎记录      │
     *  │ 了这次读取，于是任何一个子项的隐式尺寸变化，都会让本绑定重新  │
     *  │ 求值 —— onImplicitSumChanged 于是成为"子项 Loader 加载完了"   │
     *  │ 的信号，驱动 relayout()。这比轮询、比 Connections 都干净。    │
     *  └───────────────────────────────────────────────────────────────┘
     *
     *  注意必须定义在 root 上：QtObject 内无法用 JS 函数驱动绑定重算
     *  （属性绑定表达式里不能调用同文件函数形成有效依赖链）。 */
    readonly property real implicitSum: root._kidImplicitSum()
    onImplicitSumChanged: d.relayout()

    default property alias data: content.data

    implicitWidth:  d.totalW + root.padding * 2
    implicitHeight: d.totalH + root.padding * 2

    /* 默认按内容收缩（≈ CSS inline-flex）。
     *
     * 需要撑满父容器时写 fill: true（见上方注释），不要和 anchors.fill
     * 混用。注意 fill 是「告诉 Layout 把我拉开」，不是「我自己变宽」——
     * 真正改 width 的是 Layout，所以必须有 Layout 祖先。
     *
     * 关于 width / implicitWidth 的关系，有一个容易被误读的细节：
     * implicitWidth 是"内容想占多宽"（由子项测量结果推出），所以本组件
     * 天然是 hug 的。QML 的规矩是——**没有外部约束时 width 自动等于
     * implicitWidth**，不需要显式写 `width: implicitWidth`。显式写反而
     * 有害：它把 width 变成一个对 implicitWidth 的绑定，当 Layout 试图
     * 接管 width 时，两个来源会互相争夺。
     *
     * 所以这里不写 width，交给 QML 默认规则处理。 */
    height: implicitHeight

    Layout.fillWidth: root.fill

    Item {
        id: content
        x: root.padding
        y: root.padding
        onChildrenChanged: d.relayout()
    }

    onWidthChanged:               d.relayout()
    onAlignChanged:               d.relayout()
    onGapChanged:                 d.relayout()
    onPaddingChanged:             d.relayout()
    onPrimaryIndexChanged:        d.relayout()
    onFollowPlatformChanged:      d.relayout()
    onDangerIndexesChanged:       d.relayout()
    onExtraGapBeforeDangerChanged: d.relayout()
    onStackWhenNarrowChanged:     d.relayout()
    onStackBelowChanged:          d.relayout()
    Component.onCompleted:        d.relayout()

    /* ── 子项隐式尺寸的"哨兵求和" ─────────────────────────────────────
     *
     *  这是 M9.x「fill:true 不撑满、按钮只露出一个」的两半根因之一。
     *
     *  QSkinButton 的 implicitWidth 是这么一层层推出来的：
     *      QSkinButton.implicitWidth
     *        ← contentLoader.implicitWidth          （Loader）
     *        ← BasicButtonContent(QSkinRow).implicitWidth
     *        ← labelLoader.implicitWidth            （Loader）
     *        ← 一个 Text 的宽度
     *  整条链上全是 Loader —— 要等好几帧才收敛到真实值。而 ButtonBar
     *  在 Component.onCompleted 只量一轮，那时读到的是"Loader 还没加载"
     *  的最小值（controlHeight=32），之后再也没有事件把它拉回来。
     *
     *  这个函数的唯一作用是**把子项的 implicit 尺寸拉进 QML 依赖图**：
     *  root.implicitSum 绑定到它，函数体里读了每个子项的 implicitWidth /
     *  implicitHeight，于是任何一个子项的隐式尺寸一变，implicitSum
     *  重新求值 → onImplicitSumChanged → relayout()。Loader 加载完是
     *  QML 自己知道的事，交给绑定系统转发即可，不必轮询。
     *
     *  注意：这个函数必须写在 root 上，不能写在 QtObject d 里 ——
     *  d 的作用域里 `content`（同级 id）解析不到，整条绑定会算成
     *  undefined（实测），哨兵就永远不响。
     *
     *  ⚠️ 另一半根因在 measure()：哨兵把 implicitWidth 的收敛"叫醒"了，
     *  但如果 measure() 优先读 width（旧写法），醒来后量的还是陈旧值，
     *  等于白醒。两处必须一起改。见 measure() 的注释。 */
    function _kidImplicitSum() {
        var s = 0
        for (var i = 0; i < content.children.length; ++i) {
            var c = content.children[i]
            if (!c || c.visible === false) continue
            s += (c.implicitWidth || 0) + (c.implicitHeight || 0)
        }
        return s
    }

    QtObject {
        id: d

        property real totalW: 0
        property real totalH: 0
        property bool stacked: false

        /** relayout 重入闸门。
         *
         *  _pass() 会给子项写 x / y / width，子项几何一变又通过
         *  onWidthChanged → relayout() 回调进来 —— 形成重入。重入的那一轮
         *  读到的是"只排了一半"的子项尺寸，算出的 totalW/implicitWidth
         *  是残值，正好把外层的正确结果覆盖掉。
         *
         *  闸门策略：在外层 relayout 跑完前，后续进来的调用只登记
         *  "还需要再算一次"，跑完后再补一轮。这样既不丢更新，也不会
         *  用中间态覆盖最终态。 */
        property bool _running: false
        property bool _dirty: false

        /** 是否为主按钮（Windows 上主按钮挪到最左） */
        readonly property bool primaryLeft:
            root.followPlatform && Qt.platform.os === "windows"

        /** 收集可见子项，并保留其声明下标 */
        function kids() {
            var out = []
            for (var i = 0; i < content.children.length; ++i) {
                var c = content.children[i]
                if (c && c.visible !== false) out.push({ item: c, index: i })
            }
            return out
        }

        /**
         * 取子项尺寸 —— **优先 implicit，而不是优先 width**。
         *
         * 这个优先级顺序是 M9.x 那个真 bug 的正解，值得写清楚：
         *
         * QSkinButton 这类控制件的 implicitWidth 是"内容想要多大"，由内层
         * Loader 异步收敛（初值 controlHeight=32，几帧后涨到真实值 88）。
         * 而 width 会被本组件的横排分支写上一次测量结果 —— 一旦写过，
         * 后续每一轮 measure() 都会读到那个**陈旧值**，implicitWidth 的
         * 收敛再也传不进来，尺寸永久锁死在第一轮的 32。
         *
         * 实测症状（Windows / Qt 6.8.3，两个按钮）：同一时刻
         *     d.implicitSum（读 implicitWidth）= 212   ← 真实值
         *     flatW        （读 width）        = 108   ← 陈旧值 32+16+60
         * 两个数打架，就是这条优先级写反导致的。
         *
         * 反过来以 implicitWidth 为准就永远收敛：它是"内容想要多大"的
         * 权威来源，Loader 加载完会自动更新，哨兵（implicitSum）再驱动
         * 一轮 relayout。width 只在 implicitWidth 缺失（0）时兜底。
         */
        function measure(c) {
            var w = (c.implicitWidth  > 0) ? c.implicitWidth  : c.width
            var h = (c.implicitHeight > 0) ? c.implicitHeight : c.height
            return { w: Math.max(0, w), h: Math.max(0, h) }
        }

        function isDangerIndex(idx) {
            var list = root.dangerIndexes
            if (!list || list.length === undefined) return false
            for (var i = 0; i < list.length; ++i)
                if (list[i] === idx) return true
            return false
        }

        function relayout() {
            /* 重入保护 —— 见 _running 注释。_pass() 会给子项写几何，
             * 子项尺寸一变又会回调进来；若任其递归，中间态会覆盖外层
             * 算好的 totalW。 */
            if (d._running) { d._dirty = true; return }
            d._running = true
            d._dirty = false
            d._pass()
            d._running = false
            if (d._dirty) { d._dirty = false; d.relayout() }
        }

        function _pass() {
            var kids = d.kids()
            if (kids.length === 0) { d.totalW = 0; d.totalH = 0; return }

            // ── 1. 排列顺序：Windows 上把主按钮挪到最左 ──
            var pi = (root.primaryIndex < 0) ? (kids.length - 1)
                                             : Math.min(root.primaryIndex, kids.length - 1)
            var ordered = kids.slice()
            if (d.primaryLeft && pi > 0 && pi < ordered.length) {
                var p = ordered.splice(pi, 1)[0]
                ordered.unshift(p)
            }

            // ── 2. 测量 ──
            var i, m, sizes = [], maxH = 0, maxW = 0
            for (i = 0; i < ordered.length; ++i) {
                m = d.measure(ordered[i].item)
                sizes.push(m)
                maxH = Math.max(maxH, m.h)
                maxW = Math.max(maxW, m.w)
            }

            // ── 3. 决定横向还是堆叠 ──
            var availW = Math.max(0, root.width - root.padding * 2)

            var spacing = []
            for (i = 0; i < ordered.length - 1; ++i) {
                var extra = d.isDangerIndex(ordered[i].index)
                         || d.isDangerIndex(ordered[i + 1].index)
                spacing.push(root.gap + (extra ? root.extraGapBeforeDanger : 0))
            }

            var flatW = 0
            for (i = 0; i < sizes.length; ++i) flatW += sizes[i].w
            for (i = 0; i < spacing.length; ++i) flatW += spacing[i]

            /* 宽度受外部约束才可能堆叠（M9 修复 M3 的 self-width 死锁）。
             *
             * hug 模式下 width 恒等于 implicitWidth，availW 就是自己
             * 上一轮的内容宽 —— 两个假信号让堆叠判定完全失真：
             *   · "availW < stackBelow(320)"：两三个按钮的 flatW 常小于
             *     320，hug 状态下恒为真；
             *   · 一旦堆叠，totalW = maxW < flatW，下一轮 flatW > availW
             *     更过不了 —— 永久锁死在竖排，按钮再也回不到横排。
             * "width ≠ implicitWidth"是"宽度被外部（布局/显式 width）约束"
             * 的可靠信号：hug 模式两者恒相等；被约束时宽度来自父容器。 */
            var widthConstrained = root.width > 0
                                   && root.width !== root.implicitWidth

            d.stacked = root.stackWhenNarrow
                        && widthConstrained
                        && (flatW > availW || availW < root.stackBelow)

            if (d.stacked) {
                // ── 纵向堆叠：等宽，主按钮在上 ──
                /* 堆叠必须统一宽度（否则参差不齐），所以这里写 width 是
                 * 有意的 —— 它把子项宽对齐到最宽者。写的是测量结果 maxW，
                 * 不含陈旧隐患（maxW 来源于 implicitWidth）。 */
                var y = 0
                for (i = 0; i < ordered.length; ++i) {
                    var it = ordered[i].item
                    it.x = 0
                    it.y = y
                    it.width = maxW
                    if (!(it.implicitHeight > 0) && !(it.height > 0))
                        it.height = sizes[i].h
                    y += sizes[i].h + root.gap
                }
                d.totalW = maxW
                d.totalH = Math.max(0, y - root.gap)
                return
            }

            // ── 4. 横向排列 ──
            var x0
            if (root.align === "end")         x0 = Math.max(0, availW - flatW)
            else if (root.align === "center") x0 = Math.max(0, (availW - flatW) / 2)
            else                              x0 = 0

            var x = x0
            for (i = 0; i < ordered.length; ++i) {
                var it2 = ordered[i].item
                it2.x = x
                it2.y = 0
                /* 尺寸：**不写 width/height**。见 measure() 的注释 ——
                 * 子项自身的 width: implicitWidth 绑定已经够用，写一次
                 * 就会让下一轮的 measure() 读到陈旧值。只在子项两边都
                 * 拿不到数（implicit 和 width 全是 0）时兜底赋一次。 */
                if (!(it2.implicitWidth > 0) && !(it2.width > 0))
                    it2.width = sizes[i].w
                if (!(it2.implicitHeight > 0) && !(it2.height > 0))
                    it2.height = sizes[i].h
                x += sizes[i].w
                if (i < spacing.length) x += spacing[i]
            }

            d.totalW = flatW
            d.totalH = maxH
        }
    }
}
