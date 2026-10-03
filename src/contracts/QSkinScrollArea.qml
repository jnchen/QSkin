/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinScrollArea
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 可滚动容器 —— 内容比地方大时，给它一块能滚的地，并画上滚动条。
 *
 * ── 先说清楚它现在补的是什么缺口 ───────────────────────────────────────
 * `src/` 里搜索 "thumb / 滚动条 / ScrollBar" **一个匹配都没有**：
 * QSkinTable 与 QSkinTree 各自裸用 Flickable 滚内容，屏幕上**没有可见的
 * 滚动指示**。所以本项目此前并不存在"滚动条长什么样"这件事 ——
 * 这个控件是第一个把滚动条画出来的地方。
 *
 * ── 为什么滚动条交给 QtQuick.Controls 而不是自绘 ───────────────────────
 * 项目**已经在依赖** Controls（QSkinTable 的 `ScrollIndicator`、QSkinSelect /
 * QSkinDialog 的 `Popup`，见各自的 import）。Controls 的 `ScrollBar` 做对了
 * 三件很难自己写对的事：
 *   · `position` / `size` 与 Flickable 的**双向**同步（自己写必踩
 *     "拖拽时绑定被打断，之后滚轮再也不同步"的那一版）
 *   · `policy: AsNeeded` 的显隐与 `active` 的自动淡出时序
 *   · 触摸 / 拖拽 / 键盘三套输入汇流
 * 自绘等于把这三件重写一遍，而且**写错了也不会有人发现**（滚动条不像
 * 勾选框，它不参与任何状态机，错了只是"看着有点怪"）。
 *
 * 但视觉**不**用 Controls 的默认样式：contentItem 与 background 由我们
 * 给（见下），颜色、圆角、粗细全部走 QSkin 令牌。这正好是 Controls 为
 * 自定义留的口子 —— 用它的行为，不用它的皮肤。
 *
 * ── 换皮肤时丢掉的那半件东西：淡出状态机 ──────────────────────────────
 * "换 contentItem" 听起来只是换外观，实际会**连行为一起丢掉一半**：
 * Basic 样式的 `contentItem` 不是一块普通矩形，它默认 `opacity: 0.0`，
 * 由一条状态机在 `AlwaysOn || (active && size < 1)` 时升到 0.75 ——
 * "静止时透明、滚动时浮出"这件事是**画在 contentItem 上**的，不在 ScrollBar 上。
 * 换掉它 = 换掉那台状态机，而自绘的矩形默认 opacity 是 1。
 * 后果不是"没有淡出"，是**淡出永远不会发生**：滚动条一旦存在就恒亮。
 * M18 抓图里右栏（内容 749 < 视口 769）在最右边画出一条贯穿视口的 4px 竖线，
 * 就是这么来的 —— `policy: auto` 于是形同虚设。
 * 现在的做法不是把那台状态机抄回来（它让滚动条在静止截图里彻底不可见，
 * 本项目靠抓图做门禁，不能接受），而是按本文档写的语义自己算可见性：
 * `auto` = 有东西可滚就常驻、没东西可滚就一点不画。见 `_barVisible`。
 * 顺带：Basic 的 ScrollBar 自带 `padding: 2`，可见滑杆 = width − 2×padding，
 * 所以 `scrollBarThickness` **不等于**看得见的粗细；`scrollBarInset`
 * 原先是个声明了却从没被读过的属性，现在显式绑在 padding 上。
 *
 * ── 为什么不直接用 QtQuick.Controls 的 ScrollView ──────────────────────
 * ScrollView 自己接管 `contentWidth / contentHeight`（用它的
 * `implicitContentWidth` 推断），而 QSkin 这边已经确立的约定是
 * **内容尺寸由宿主显式声明**（QSkinTable 文件头关于 contentWidth 那一大段，
 * 以及 M13 因为少了"左固定宽度"那一截而把 bug 当成期望值的记录）。
 * 让两套推断逻辑共存，会得到"内层说 800、外层说 620"这种无法归因的错位。
 *
 * ── 内容尺寸怎么给 ────────────────────────────────────────────────────
 *     QSkinScrollArea {
 *         anchors.fill: parent
 *         contentHeight: col.implicitHeight     // ← 显式声明
 *         QSkinColumn { id: col; width: parent.width; ... }
 *     }
 * `contentWidth / contentHeight` 默认 -1，意思是**跟随视口**（即不需要
 * 滚动）。不去猜内容多大 —— 猜就要读 childrenRect，而内容若写
 * `anchors.fill: parent`，读 childrenRect 会与"视口尺寸"形成绑定循环
 * （QML 只会给一句 Binding loop 警告然后取一个中间值，非常难查）。
 *
 * ── 子项放在哪儿 ──────────────────────────────────────────────────────
 * 子项被收进一个跟随内容滚动的宿主（默认属性 alias 到它的 data）。
 * 所以子项的 `parent.width` 就是**内容宽**，不是视口宽 —— 写
 * `width: parent.width` 得到的是"铺满一行内容"，这正是想要的。
 ****************************************************************************/

import QtQuick 2.15

/* 刻意 import **Basic** 风格而不是 `QtQuick.Controls`。
 *
 * 默认的 Controls 风格在本机是 Windows 原生风格，而原生风格**不允许**
 * 自定义控件的 contentItem / background —— 运行时会一路打
 *   "The current style does not support customization of this control
 *    (property: "contentItem")"
 * 然后静默用回它自己的外观（滚动条变成系统样式，我们的令牌全不生效）。
 *
 * 而 QSkin 要的正是"用它的行为、不用它的皮肤"。`QtQuick.Controls.Basic`
 * 模块就是官方为此准备的：同一个 ScrollBar，但完全允许换皮。
 * 注意它只影响**本文件** —— QSkinTable 里的 ScrollIndicator 走的是
 * 另一份 import，不受牵连。 */
import QtQuick.Controls.Basic 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容尺寸 ══════════════════════ */

    /** 内容总宽。-1 = 跟随视口（不横滚）。见文件头。 */
    property real contentWidth: -1

    /** 内容总高。-1 = 跟随视口（不纵滚）。见文件头。 */
    property real contentHeight: -1

    /* ══════════════════════ 滚动条 ══════════════════════ */

    /** 允许纵向滚动条 */
    property bool verticalScrollBar: true

    /** 允许横向滚动条。默认关 —— 桌面端横向滚动靠触控板手势不常见，
     *  且它会在底部压掉一行内容的高度。需要时显式打开。 */
    property bool horizontalScrollBar: false

    /** 何时显示：auto（**内容真的超出才显示**）| always | never。
     *  注意 auto 的实现**不是** Qt 默认那套"静止就淡出"—— 见
     *  ScrollBar.vertical 里那段：Qt 默认的滑杆在没有交互时是透明的，
     *  那样一张静止的截图里永远看不到它，本项目的抓图/像素门禁就失去落点。
     *  auto 在这里 = "有东西可滚就常驻，没东西可滚就一点不画"。 */
    property string policy: "auto"

    /** 滚动条的**外框**宽度（横向时是高度）。
     *  实际能看见的滑杆 = 这个值 − 2 × `scrollBarInset`。 */
    property int scrollBarThickness: 8

    /** 滑杆与轨道边缘的距离（= ScrollBar 的 padding）。
     *  它**真的**参与几何：可见宽度 = thickness − 2×inset。 */
    property int scrollBarInset: 2

    /* ══════════════════════ 行为 ══════════════════════ */

    /** 是否允许鼠标拖动内容（触屏式滚动）。
     *  桌面端把它关掉可以让"按下拖动"留给业务（比如框选）。 */
    property bool interactive: true

    /* ══════════════════════ 暴露 ══════════════════════ */

    /** 底层 Flickable。要读 contentY / 调 positionViewAtEnd 之类时用它。 */
    property alias flickable: flick

    /* ── 关于 contentX / contentY：**它们不夹取** ─────────────────────────
     *
     * 这两个是到 Flickable 的**裸直通**（property alias）。Flickable 的
     * contentY setter 不会把值夹到 [0, contentHeight - height] —— 夹取只发生
     * 在拖拽 / 惯性滑动那条路径上（`updateBeginningEnd`）。
     *
     * 这一点曾经被写反过。M17 的注释里写着"Flickable 自己的 contentY setter
     * 就会夹取"，于是 M18 抓图脚本大胆地写了 `scroller.contentY = 1e6`
     * 想"滚到底"，结果 contentY 原样收下 100000，视口里**一片空白** ——
     * 图上什么都没画，而所有属性断言全绿（这不是渲染错，是"没人把值夹回来"）。
     * 现场证据：`m18_tdesign_light_scrolled.png` 的自证行印着
     * `viewH=769 contentH=2038 contentY=100000 scrollable=true`。
     *
     * 要程序化滚动请用 `scrollTo()`（它按 `_cw / _ch` 夹取）；直接写这两个
     * 属性等于声明"我自己知道合法范围是多少"。 */
    property alias contentX: flick.contentX
    property alias contentY: flick.contentY

    /** 内容是否真的超出了视口 */
    readonly property bool scrollableVertically:   flick.contentHeight > flick.height
    readonly property bool scrollableHorizontally: flick.contentWidth  > flick.width

    /* 解析后的内容尺寸：-1 表示跟随视口 */
    readonly property real _cw: root.contentWidth  >= 0 ? root.contentWidth  : flick.width
    readonly property real _ch: root.contentHeight >= 0 ? root.contentHeight : flick.height

    /* ══════════════════════ 视口 ══════════════════════ */

    Flickable {
        id: flick

        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        contentWidth:  root._cw
        contentHeight: root._ch

        interactive: root.interactive
                     && (root.scrollableVertically || root.scrollableHorizontally)

        /* ── 内容宿主 ──
         * 必须显式改 parent：声明在 Flickable 里的话 parent 是 flick，
         * 那样它不会跟着 contentX / contentY 动（Flickable 移动的是
         * contentItem 自身的 x / y）。挂到 contentItem 上才有了"内容
         * 坐标系"，子项写 parent.width 得到的是内容宽。 */
        Item {
            id: holder

            parent: flick.contentItem
            width:  flick.contentWidth
            height: flick.contentHeight
        }

        /* ══════════════════════ 滚动条 ══════════════════════
         *
         * 必须写在 Flickable **内部** —— `ScrollBar.vertical` 是附加到
         * Flickable 上的属性（qmllint 的原话：must be attached to a
         * Flickable or ScrollView）。写在 root 上会被判为类型错误，
         * 而且运行时真的不会生效。
         *
         * 只给 contentItem（滑杆本体）与 background，行为全部交给
         * Controls。颜色分三档：常态 divider、hover / 拖拽中 borderStrong
         * —— 与项目里其它"可交互的次级元素"同一套映射，不新造词汇。
         *
         * 常态为什么是 `divider` 而不是 `border`：滚动条浮在**内容**上，
         * 而内容两侧没有容器包着，它和 Divider / 分栏栏杆是同一种东西 ——
         * "裸放在页面底上的线"。TDesign 下用 border 会让整条滚动条消失。 */
        ScrollBar.vertical: ScrollBar {
            id: vbar

            policy: root._policyEnum()
            width: root.scrollBarThickness
            /* 让 `scrollBarInset` 真的有用。Basic 样式的 ScrollBar 自带
             * `padding: 2`，可见滑杆 = width - 2×padding —— 也就是说
             * **实际看到的粗细不是 scrollBarThickness**。这里把它显式绑上，
             * 于是"粗细"与"离边距离"两个数各自能读、各自能查。
             * （原先 scrollBarInset 只是个从没被读过的属性：声明了、写在文档里、
             * 却不影响任何像素 —— 属于"看着像旋钮、其实是贴纸"。） */
            padding: root.scrollBarInset

            /* ── 为什么 visible 要自己算 ──────────────────────────────────
             * Basic 样式的默认 contentItem 带一套**淡出状态机**：
             * 默认 `opacity: 0.0`，只有 `policy === AlwaysOn ||
             * (active && size < 1.0)` 时才升到 0.75 —— 所以
             * "AsNeeded 且内容没超出"时它虽然 `visible: true`，但透明不可见。
             *
             * 我们替换了 contentItem，**连带把那套状态机一起丢了**：
             * 自绘的 Rectangle 默认 opacity 是 1。于是淡出永远不会发生，
             * 滚动条一旦存在就恒亮 —— 包括"根本没有东西可滚"的时候。
             *
             * 症状（M18 抓图实测，TDesign 亮色 base 场景）：
             * 右栏 contentH=749 < viewH=769，却在窗口最右边
             * （x 1274..1278）画出一条贯穿整个视口（y 57..821）的 4px 竖线。
             * 那正是 ScrollBar 的滑杆 —— `size` 被夹到 1，铺满了整条轨道。
             * 也就是说 `policy: auto` 这个档位形同虚设：
             * 文档写着"内容超出才显示"，实际是"永远显示"。
             *
             * 修法不复杂，但要想清楚取哪一套语义。Qt 默认那套是
             * "静止就淡出、滚动时才浮出来"；而本控件文档里写的 auto 是
             * "内容超出才显示"。后者可被截图验证（前者不能 ——
             * 一张静止的图里它必然是透明的），也符合桌面上
             * Windows / shadcn 那类**常驻**滚动条的预期。
             * 所以按文档来：可见性 = f(policy, 是否真的超出)。 */
            visible: root._barVisible(root.verticalScrollBar, root.scrollableVertically)

            contentItem: Rectangle {
                implicitWidth: root.scrollBarThickness
                radius: width / 2
                color: vbar.pressed ? Theme.color.borderStrong
                     : vbar.hovered ? Theme.color.borderStrong
                                    : Theme.color.divider

                Behavior on color {
                    ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
                }
            }

            background: Item { }
        }

        ScrollBar.horizontal: ScrollBar {
            id: hbar

            policy: root._policyEnum()
            height: root.scrollBarThickness
            padding: root.scrollBarInset

            visible: root._barVisible(root.horizontalScrollBar, root.scrollableHorizontally)

            contentItem: Rectangle {
                implicitHeight: root.scrollBarThickness
                radius: height / 2
                color: hbar.pressed ? Theme.color.borderStrong
                     : hbar.hovered ? Theme.color.borderStrong
                                    : Theme.color.divider

                Behavior on color {
                    ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
                }
            }

            background: Item { }
        }
    }

    /* default property 只能声明在 root 上（alias 目标必须是同一文件里的
     * id.property）。声明在 Flickable 内部会让它成为 flick 的默认属性，
     * 而不是 root 的 —— 于是 `QSkinScrollArea { Rectangle {} }` 会报
     * "Cannot assign to non-existent default property"。 */
    default property alias contentData: holder.data

    /* 滚动条不在这里 —— `ScrollBar.vertical` 是附加到 Flickable 上的属性，
     * 声明在 root 上 qmllint 会报 "must be attached to a Flickable"，
     * 运行时也确实不生效。见 Flickable 内部那两段。 */

    /* ══════════════════════ 无障碍 ══════════════════════ */

    Accessible.role: Accessible.Pane

    /* ══════════════════════ 内部 ══════════════════════ */

    function _policyEnum() {
        switch (root.policy) {
        case "always": return ScrollBar.AlwaysOn
        case "never":  return ScrollBar.AlwaysOff
        default:       return ScrollBar.AsNeeded
        }
    }

    /** 滚动条该不该露出来。见 ScrollBar.vertical 那段注释：
     *  Qt 默认那套是"静止即透明"，与本文档写的 auto 不是同一个语义；
     *  这里按文档实现 —— auto = 内容真的超出才显示。
     *  「是否超出」由**调用方传入**（纵向传 scrollableVertically），
     *  这样这个函数是纯函数，两个方向共用，也不会与 Flickable 的几何成环。 */
    function _barVisible(enabled, scrollable) {
        if (!enabled) return false
        if (root.policy === "never")  return false
        if (root.policy === "always") return true
        return scrollable
    }

    /** 滚到指定内容坐标（夹到合法范围）。 */
    function scrollTo(x, y) {
        if (x !== undefined && x !== null)
            flick.contentX = Math.max(0, Math.min(x, root._cw - flick.width))
        if (y !== undefined && y !== null)
            flick.contentY = Math.max(0, Math.min(y, root._ch - flick.height))
    }
}
