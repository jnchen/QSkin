/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinDivider
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 分隔线 —— 把同一块区域里的两段内容分开，或者把一个标题从它的内容里分开。
 *
 * ── 三个语义决定，写清楚免得下次再想 ───────────────────────────────────
 *
 * ① **横向默认撑满父宽**（对齐 Ant 的 100% 与 shadcn 的 w-full）。
 *    Divider 是块级元素而不是行内元素：`Column { Divider {} }` 的期望是
 *    一条横贯的线，不是一小段。所以 fill 默认为 true。
 *    纵向是反过来的：默认给一个令牌高度，**不**撑满 —— 纵向分隔线通常
 *    只分一行文字（"已读 | 未读"），撑满父容器会戳出到别的行去。
 *
 * ② **带文字时是"一条线被挖掉一段"，不是"线 + 文字 + 线"并排**。
 *    两者在宽度充裕时长得一样，差在**宽度不够时**：
 *      · 并排写法（Row [线, 文字, 线]）里文字有 implicitWidth，三段的
 *        总宽会顶着容器往外长 —— 线被挤到 0 宽**然后整条线溢出**；
 *      · 挖洞写法先给文字一个**上限**（`width - 2 × (minSegment + textGap)`），
 *        超了就 elide，线永远保住 minSegment 那一截。
 *    所以这里把"洞"当成一等公民：`hole` 是一个可读属性，线由 `segments`
 *    按洞切出来，文字定位到洞上。三者的几何出自**同一个函数**，
 *    不是三处各算一遍（M13 的教训：同一个量写三遍，就有三个会互相
 *    打架的真相）。
 *
 * ③ **线画成若干段，不是一条矩形**。虚线只是"段更短、段间有空隙"。
 *    实线 = 一段铺满；虚线 = N 段。**同一条代码路径**，所以虚线不需要
 *    单独验证一遍，也不会出现"实线对、虚线漏"这类只在第二条分支上的 bug。
 *
 * ④ **文字靠左 / 靠右时，靠的那一侧仍留一截线**（不是让文字贴着容器边）。
 *    这条是被**图**逼出来的，不是被断言逼出来的：属性侧的 `segments` 一直
 *    如实报着 `[398]`（一段），断言全绿；而抓图上"第一节"直接贴着左缘、
 *    左端**一截线都没有** —— 和同一屏里那句文案"左边只留一小截"当场矛盾。
 *    属性值自洽、界面与自己的说明书不符，属于「属性值对 ≠ 界面画对」的
 *    第四种形态：前三种是"颜色漏用令牌 / 几何算错 / 少一个换算"，
 *    这一种是**实现与文案各说各话，而只有看图才能发现**。
 *
 *    改哪一边？查了两家的真实实现（这是"三家并集"基准的意义所在）：
 *      · Ant Design  `components/divider/style/index.ts`：
 *        `orientationMargin` 默认 **0.05**，左对齐时
 *        `rail-start` 宽 5%、`rail-end` 宽 95% —— **有左线段**。
 *        要让左端归零得显式打开 `no-default-orientation-margin-start`
 *        那个变体（`rail-start: 0 / rail-end: 100%`）。
 *        也就是说"左端零线段"在 Ant 里是**退出默认**，不是默认。
 *      · Arco Design `divider/style/token.less`：
 *        `@divider-position-text-left: @spacing-9`（= 36px），
 *        文字框绝对定位在 36px 处、再靠 `background: color-bg-2`
 *        把底下的整条线盖掉 —— 于是文字左边**必然**留下 36px 的线。
 *    两家都留，所以改实现。留多长由 `minSegment` 说了算 ——
 *    它的文档本来就写着"洞的**两侧**各自至少留多长的线"，
 *    而"贴着边"那种写法让其中一侧恒为 0，与自己的文档也矛盾。
 *    想要"文字真正贴着容器边"（Ant 那个退出分支的样子）用现成的两个
 *    属性就够了：`textGap: 0; minSegment: 0` —— 不另造 API。
 *
 * ── 为什么把几何做成可读属性而不是只画出来 ─────────────────────────────
 * `segments` / `hole` 是纯函数的结果，属性侧能直接断言（见
 * tests/smoke_m18.qml）：把宽度从 600 改到 40，文字那一段必须 elide、
 * 两侧线必须各剩 minSegment。这类断言比"看起来对"硬得多，也让
 * .cache/_verify_m18.py 的像素核验**有期望可对**，而不是"图里有个东西"。
 *
 * ── textWidthOverride / textHeightOverride 是给谁用的 ──────────────────
 * 给抓图脚本与测试用。文字宽度正常从 label 插槽实例上读，而 Loader 的
 * 隐式尺寸要**下一轮事件循环**才收敛（见 tests/smoke_sizes.qml 记录的那次
 * 排查）—— 于是"抓图那一帧量到的洞"和"渲染出来的洞"可能差一帧。
 * 显式给一个数，这一屏就只由我们摆的状态决定。
 * （M17 的教训：抓图脚本自己也是被测对象。）
 *
 * ── 和 QSkinMenu 里的分隔线是什么关系 ────────────────────────────────────
 * 那个是菜单项列表里的"一条横线"，画在菜单内部、没有文字、宽度由菜单给。
 * 它现在是 1 行 Rectangle。**本轮刻意不改它** —— 菜单的换行分隔线不是
 * "内容分区"语义，且菜单有自己的一套 padding 契约；等真的出现第二个
 * 消费者（比如 Dropdown 菜单）再统一。没有第二个消费者就不动，这条
 * 判据在 README 里写过两遍。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 形状 ══════════════════════ */

    /** horizontal | vertical */
    property string orientation: "horizontal"

    /** subtle | default | strong。
     *
     *  default 用的是 `Theme.color.divider` —— "裸放在页面底上的线"那一档。
     *  它和 `border` 不是一回事：`border` 的参照物是**容器自己的面**（卡片
     *  / 输入框 / 菜单），而分隔线底下什么都没有，直接躺在页面底上。
     *
     *  这个区分是抓图逼出来的：TDesign 主题的页底色是 #EEEEEE，而它的
     *  `border` 是 #E7E7E7 —— 比页底色还浅 7 阶。一整屏分隔线在屏幕上
     *  什么都不剩，属性断言却全绿。（M18 实测，详见 tokens/neutral.js） */
    property string tone: "default"

    /** 是否撑满父容器（横向撑宽、纵向撑高） */
    property bool fill: true

    /* ══════════════════════ 文字（仅横向） ══════════════════════ */

    /** 线上的文字。空串 = 一条通线。纵向时忽略。 */
    property string text: ""

    /** 文字位置：left | center | right。
     *  left / right 都会在**靠边那一侧**保留 `minSegment` 长的一截线
     *  （与 Ant / Arco 的实际行为一致，见文件头 ④）；想要"文字贴到容器边"
     *  就同时把 `textGap` 与 `minSegment` 设成 0。 */
    property string textAlign: "center"

    /** 文字与线之间的最小空隙（洞的左右各留这么多） */
    property int textGap: Theme.space.md

    /** 洞的两侧各自至少留多长的**线**。
     *  文字很长时靠它压住文字宽度 —— 宁可 elide 也不让线消失。
     *  三种对齐共用这一个下限：居中时两侧都是它，靠左 / 靠右时**靠边那一侧**
     *  也是它（不设 0，见文件头 ④ 与 `hole` 里的不变量）。 */
    property int minSegment: Theme.space.lg

    /* ══════════════════════ 虚线 ══════════════════════ */

    property bool dashed: false

    /** 每一小段的长度（仅虚线用） */
    property int dashLength: 4

    /** 段间空隙（仅虚线用） */
    property int dashGap: 4

    /* ══════════════════════ 粗细 ══════════════════════ */

    /** 线宽。桌面端 1px 是通行值，主题若要改粗走这里。 */
    property int lineThickness: 1

    /* ══════════════════════ 测量覆盖（测试 / 抓图用） ══════════════════════ */

    /** ≥0 时直接采用，不再问 label 插槽实例。见文件头。 */
    property real textWidthOverride: -1
    property real textHeightOverride: -1

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property bool horizontal: root.orientation !== "vertical"

    /* label 插槽实例的文字实测尺寸。Loader 未就绪时是 0。
     *
     * 走 `var` 而不是直接读 `labelLoader.item.implicitWidth`：
     * Loader.item 的静态类型是 QObject，qmllint 会按它做成员检查并报
     * "Member implicitWidth not found"。而这里是**鸭子类型** ——
     * 插槽契约（Slots.qml 契约第 1 条）本来就不保证插槽实例的类型，
     * 只保证它能读 control。与 BasicLabel / FocusRing 里
     * `property var control` 是同一个处理。 */
    readonly property var _labelItem: labelLoader.item
    readonly property real _measuredW: root._labelItem ? root._labelItem.implicitWidth : 0
    readonly property real _measuredH: root._labelItem ? root._labelItem.implicitHeight : 0

    /** 线的颜色。做成 root 上的只读属性，是为了让 Repeater 的 delegate
     *  能**完全限定**地访问它（delegate 是独立作用域，访问内层 id 会被
     *  qmllint 判为 Unqualified access —— 而那正是它该报警的情形）。 */
    readonly property color lineColor:
        root.tone === "subtle" ? Theme.color.border
      : root.tone === "strong" ? Theme.color.borderStrong
      :                          Theme.color.divider

    readonly property real textContentWidth:
        root.textWidthOverride >= 0 ? root.textWidthOverride : root._measuredW
    readonly property real textContentHeight:
        root.textHeightOverride >= 0 ? root.textHeightOverride : root._measuredH

    /** 沿主轴的总长（横向 = 宽，纵向 = 高） */
    readonly property real _mainLength:
        root.horizontal ? root.width : root.height

    /** 文字实际拿到的宽度（受 minSegment 压制后的值）。
     *  纵向或没有文字时是 0。 */
    readonly property real holeWidth: {
        if (!root.horizontal || root.text === "") return 0
        var avail = root._mainLength - 2 * (root.minSegment + root.textGap)
        if (avail <= 0) return 0
        return Math.min(root.textContentWidth, avail)
    }

    /** 洞（被文字占掉的那一段）：{ x, w }。没有文字时两个都是 0。
     *
     *  ── 为什么左 / 右不是"贴边" ────────────────────────────────────────
     *  见文件头 ④。靠边那一侧留 `textGap + minSegment` 出来，于是
     *  可见的线 = `minSegment`，与居中时两侧的下限**同一个数**。
     *  三种对齐于是满足同一条不变量：
     *      两侧线长 >= minSegment，且 len(左段) + textGap + w + textGap + len(右段) == total
     */
    readonly property var hole: {
        var tw = root.holeWidth
        if (tw <= 0) return { x: 0, w: 0 }
        var total = root._mainLength
        /* "靠边那一侧至少要让出多少" —— 线(textGap 之后的 minSegment) 加 空隙(textGap)。
         * holeWidth 已经被 avail = total - 2*(minSegment+textGap) 压过，
         * 所以这里不会把另一侧的线挤到 minSegment 以下。 */
        var edge = root.textGap + root.minSegment
        var x0
        if (root.textAlign === "left")       x0 = edge
        else if (root.textAlign === "right") x0 = total - tw - edge
        else                                 x0 = (total - tw) / 2
        return { x: Math.max(0, x0), w: tw }
    }

    /** 线的全部小段：[{ pos, len }, ...]。
     *  实线就是一段；虚线是 N 段 —— 同一条路径，见文件头 ③。 */
    readonly property var segments: root._computeSegments()

    /** 横向时的高度：有文字就按文字行高，否则只有线的粗细 */
    readonly property int contentHeight:
        root.horizontal
            ? Math.max(root.lineThickness,
                       Math.round(root.text === "" ? 0
                                                   : root.textContentHeight))
            : root.lineThickness

    /* ══════════════════════ 尺寸 ══════════════════════ */

    implicitWidth:  root.horizontal ? 0 : root.lineThickness
    implicitHeight: root.horizontal ? root.contentHeight : Theme.size.controlMd

    /* 横向：撑满父宽（没有父容器时保持 0，由 Layout 的 fillWidth 接手）。
     * 纵向：fill 时撑满父高，否则用令牌高度。 */
    width: root.horizontal
           ? (root.parent && root.fill ? root.parent.width : root.implicitWidth)
           : root.lineThickness
    height: root.horizontal
            ? root.contentHeight
            : (root.parent && root.fill ? root.parent.height : root.implicitHeight)

    Layout.fillWidth:  root.horizontal && root.fill
    Layout.fillHeight: !root.horizontal && root.fill

    Accessible.role: Accessible.Separator
    Accessible.ignored: true          /* 装饰物，不该被读屏念出来 */

    /* ══════════════════════ 线 ══════════════════════ */

    Repeater {
        model: root.segments
        delegate: segmentComp
    }

    /* delegate 只读 `modelData`，**不**碰外层的任何 id。
     *
     * 起初这里写的是 `x: root.horizontal ? …`，qmllint 报了 5 处
     * Unqualified access，并建议加 `pragma ComponentBehavior: Bound`。
     * 那条 pragma 是对的，但为一个控件往文件里引入一套新的组件作用域
     * 规则不划算 —— 而且代价是隐含的：Bound 之后嵌套组件对外层 id 是
     * **静态绑定**，以后有人想在这个 Component 里动态取东西会撞墙。
     *
     * 改成把渲染参数一并算进 `segments`（见 _computeSegments），
     * delegate 就变成一个纯函数式的渲染器：给它数据，它画出来，
     * 不依赖任何外部状态。顺带得到一个副作用 —— 这个 delegate 可以
     * 被单独抠出来测（给定 modelData 就有确定的几何）。 */
    Component {
        id: segmentComp

        Rectangle {
            required property var modelData

            x:      modelData.horizontal ? modelData.pos : 0
            y:      modelData.horizontal ? 0 : modelData.pos
            width:  modelData.horizontal ? modelData.len : modelData.thickness
            height: modelData.horizontal ? modelData.thickness : modelData.len

            color: modelData.color
        }
    }

    /* ══════════════════════ 文字 ══════════════════════ */

    Loader {
        id: labelLoader

        visible: root.horizontal && root.text !== ""
        sourceComponent: Slots.label

        /* 定位到洞上 —— 用的是 root.hole，与切线段用的是同一个函数结果 */
        x: root.hole.x
        y: 0
        width:  Math.max(0, root.hole.w)
        height: root.height

        Binding {
            target: labelLoader.item
            property: "control"
            value: dividerLabelCtl
            when: labelLoader.status === Loader.Ready
        }
    }

    /* label 插槽读的是 control 的 duck-typing 状态。Divider 没有
     * variant 语义，但"线旁边的文字"应当比正文弱 —— 借 muted 那一档，
     * 与 Breadcrumb 的"非当前项"、Steps 的"未开始"同一档位。
     * 刻意**不**新造 variant：label 插槽的分支已经够多，多一个就要在
     * 四份主题实现里各加一条，而它解决的问题这里用现有档位就够了。 */
    QtObject {
        id: dividerLabelCtl

        readonly property string text: root.text
        readonly property string variant: "muted"
        readonly property int labelAlignment: Text.AlignHCenter
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    /* `segments` 的绑定要能重算：读到的每一个量都在下面被读到。
     * 写成 readonly property 而不是让每个 delegate 各算一次，是为了
     * 让 N 个段共用一次计算结果（虚线可能有上百段）。
     *
     * 每个元素都带齐渲染所需的全部参数（位置、长度、方向、粗细、颜色），
     * 这样 delegate 不需要回头看 root —— 见上面 segmentComp 的注释。 */
    function _computeSegments() {
        var total = root._mainLength
        if (total <= 0) return []

        /* 先把主轴切成"洞前 / 洞后"两段 */
        var spans = []
        var hw = root.holeWidth
        if (hw > 0) {
            var a = root.hole.x - root.textGap
            var b = root.hole.x + hw + root.textGap
            if (a > 0)           spans.push([0, a])
            if (b < total)       spans.push([b, total])
        } else {
            spans.push([0, total])
        }

        if (!root.dashed) {
            var solid = []
            for (var i = 0; i < spans.length; ++i) {
                var len = spans[i][1] - spans[i][0]
                if (len > 0) solid.push(root._seg(spans[i][0], len))
            }
            return solid
        }

        /* 虚线：把每一段再切成等距小段。
         * 末段的长度取 min(dashLength, 剩余)，所以不会戳出段尾。 */
        var step = Math.max(1, root.dashLength + root.dashGap)
        var out = []
        for (var s = 0; s < spans.length; ++s) {
            var from = spans[s][0]
            var to   = spans[s][1]
            var n = Math.ceil((to - from) / step)
            for (var k = 0; k < n; ++k) {
                var p = from + k * step
                var l = Math.min(root.dashLength, to - p)
                if (l > 0) out.push(root._seg(p, l))
            }
        }
        return out
    }

    /** 一个线段的完整描述（几何 + 渲染参数）。 */
    function _seg(pos, len) {
        return {
            pos:        pos,
            len:        len,
            horizontal: root.horizontal,
            thickness:  root.lineThickness,
            color:      root.lineColor
        }
    }
}
