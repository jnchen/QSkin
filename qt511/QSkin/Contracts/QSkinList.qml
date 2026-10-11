/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinList
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 列表 —— 一列**同质的条目**。它和 QSkinColumn 的分工是这一批里最容易混的：
 *
 *     QSkinColumn   你亲手往里摆 N 个**各不相同**的东西（标题 + 输入框 + 按钮）
 *     QSkinList     你给一份**数据**和一份**模板**，条目长得一样、只差内容
 *
 * 判据只有一条：**条目的数量在运行时会变吗？** 会 → 列表；不会 → 列布局。
 * 拿 QSkinColumn 套 Repeater 也能跑，但你会自己重写一遍这里的 hover 底、
 * 分割线、空态、加载态、分栏 —— 而那份代码不会有人来同步修。
 *
 * ── 这一批里它是唯一"数据驱动"的控件 ────────────────────────────────────
 * 其余五个（Avatar / Empty / Skeleton / Spin）都是"摆一个东西"。
 * 所以这里把数据源的三种形态都收进来（见 `model` 的注释），并且
 * **刻意不自己滚动** —— 需要滚动就套 QSkinScrollArea（M18 已落地）。
 * 列表自己滚会让"外层还有没有滚动条"变成两个控件互相猜的问题。
 *
 * ── 三家的口径差异，以及本实现选了哪一个 ────────────────────────────────
 *
 *   Ant Design List   bordered / split / size / loading / loadMore /
 *                     header / footer / grid / itemLayout / pagination
 *   TDesign List      bordered / split / stripe / size / loading /
 *                     header / footer / layout / onLoadMore / onScroll
 *   Arco Design      —— 没有 List（官方把它归为"用 Table 或自定义"）
 *
 * 于是本控件交付的是 **Ant ∪ TDesign**：
 *
 *   两家都有        split · size · bordered · loading · header · footer · loadMore
 *   只有 TDesign    stripe（隔行底色）
 *   只有 Ant        columns（多列格子）
 *
 * 两处**刻意的合并**（这里值得写下理由，因为它们是"看起来少了一个 API"）：
 *
 *   ① Ant 的 `grid` 与 TDesign 的 `layout: horizontal` 是同一件事 ——
 *      "条目横向铺开"。本实现只留一个 `columns: int`：
 *      `columns: 1` 就是竖排，`columns: n` 就是 n 列。
 *      留两个属性会让"我要 n 列"有两种写法，且它们互相冲突。
 *
 *   ② Ant 的 `pagination` 与 TDesign 的 `onScroll` 都**不实现** 。
 *      翻页交给 M9 已落地的 QSkinPagination（Ant 的 List pagination 本来
 *      也就是"在列表下面挂一个 Pagination"）；滚动加载需要列表自己
 *      认识滚动容器，与上一条"不自己滚"的决定冲突。两者都由调用方
 *      组合出来 —— 见文件末尾"怎么组合"那一段。
 *
 * ── 条目交互：hover 与 click ────────────────────────────────────────────
 * 两家都把这两件事放在**条目**上（TDesign ListItem 的 `hover` / `onClick`）。
 * 本实现由行外壳统一提供，不让每个 delegate 自己写 MouseArea ——
 * 否则同一个项目里会有 N 种 hover 底色，而且点空白处不会触发。
 *
 * delegate 的契约（**根对象要声明这两个属性**）：
 *
 *     Component {
 *         id: itemComp
 *         QSkinColumn {
 *             property var modelData     // 注入：当前数据
 *             property int index        // 注入：当前下标
 *             ...
 *         }
 *     }
 *
 * 不声明也能跑，只是控制台会打一条 "Cannot assign to non-existent
 * property" —— 那是 QML 在提醒你模板里读不到数据。
 *
 * ── 空态与加载态是**复用**，不是重画 ────────────────────────────────────
 * `count === 0` 时渲染 QSkinEmpty，`loading` 时渲染 QSkinSpin。
 * 这两个控件与 List 同批落地，用它们而不是在 List 里再画一遍，
 * 是这一批最主要的内部收益 —— 空态的插图与加载态的形态因此只有一份实现。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 数据源。三种形态都收：
     *    int        「给我 N 条」—— 快速摆版时最省事
     *    数组        JS 数组，元素原样作为 modelData 传给 delegate
     *    ListModel / QAbstractItemModel —— 同上，走 QML 的模型协议
     *  空值（0 / null / []）等价于空列表，会渲染空态。 */
    property var model: 0

    /** 条目模板。根对象应当声明 `property var modelData` / `property int index`。 */
    property Component delegate: null

    /* ══════════════════════ 结构 ══════════════════════
     *
     * header / footer 用 `property alias ... .data` 而不是 `Component`：
     * 调用方写的是**内容**（几个控件），不是**模板** ——
     * 列表头尾各只有一份，没有"重复实例化"的需求。
     * 这与 QSkinCard 的 header / extra / footer 完全同款。 */

    /** 列表头。放标题、过滤条件、操作按钮。 */
    property alias header: headerHost.data

    /** 列表尾。放"共 N 条"、翻页器、说明文字。 */
    property alias footer: footerHost.data

    /* ══════════════════════ 布局 ══════════════════════ */

    /** 条目列数。1 = 竖排（默认），n = n 列格子（Ant 的 grid）。
     *  列数 > 1 时 `split` 自动失效 —— 格子里画横分割线没有意义。 */
    property int columns: 1

    /** 条目之间的间距。竖排时是行距，多列时是行距 + 列距。 */
    property int gap: 0

    /** 多列时格子之间的间距。只有 columns > 1 时有意义。 */
    property int gutter: Theme.space.md

    /** sm | md | lg —— 决定条目内边距。 */
    property string size: "md"

    /** 条目之间是否画分割线（不画在最后一条下面）。 */
    property bool split: true

    /** 隔行底色。TDesign 独有，用于条目很长、容易串行的场景。 */
    property bool stripe: false

    /** 外框：一圈描边 + 与页面区分的底色。 */
    property bool bordered: false

    /* ══════════════════════ 条目交互 ══════════════════════ */

    /** 鼠标悬停时给底色反馈。 */
    property bool hoverable: true

    /** 条目可点。**默认 false** —— 两家都是 opt-in（Ant 的 List.Item
     *  本来就不是按钮，TDesign 的 onClick 要显式写）。
     *  开了之后：光标变手型、按下给反馈、点击发 `itemClicked`。 */
    property bool clickable: false

    /* ══════════════════════ 状态 ══════════════════════ */

    /** 加载中：用 QSkinSpin 顶掉条目区。优先级高于 loadMore / noMore。 */
    property bool loading: false

    /** 加载中的提示文字。空串 = 只转圈不写字。 */
    property string loadingText: qsTr("加载中…")

    /** 还有下一页：底部给一行可点的"加载更多"，点了发 `loadMoreRequested`。 */
    property bool loadMore: false

    /** "加载更多"那一行的文字。 */
    property string loadMoreText: qsTr("加载更多")

    /** 已经到底了：底部给一行不可点的"没有更多了"。 */
    property bool noMore: false

    /** "没有更多了"那一行的文字。 */
    property string noMoreText: qsTr("没有更多了")

    /** 空列表时的文字。 */
    property string emptyText: qsTr("暂无数据")

    /** 空列表时的插图（URL）。空串 = 用 QSkinEmpty 的内置矢量插图。 */
    property url emptyImage: ""

    /** 空态文字的最大宽度。列表比自己这个数窄时按列表宽走。 */
    property int emptyTextMaxWidth: 320

    /* ══════════════════════ 派生 ══════════════════════ */

    /** 条目数。由 model 的形态算出来，不是数渲染出来的子项 ——
     *  Grid/Repeater 的实例化是异步的一帧，数子项会读到上一帧的值。 */
    readonly property int count: root._count()

    /** 当前悬停的条目下标。-1 = 没有。delegate 可以读它做额外反馈。 */
    readonly property int hoveredIndex: root._hover >= 0 ? root._hover : -1

    /** 当前被按下的条目下标。-1 = 没有。 */
    readonly property int pressedIndex: root._pressed

    /** split 是否真的生效 —— 多列时自动关掉，见 columns 的注释。 */
    readonly property bool splitActive: root.split && root.columns <= 1

    /** 条目区是否要显示（有空态就不显示）。 */
    readonly property bool hasEmptyState:
        !root.loading && !root.loadMore && !root.noMore && root.count === 0

    /** 条目区是否要显示加载/更多/到底这三行。 */
    readonly property bool hasStatusRow:
        root.loading || root.loadMore || root.noMore

    signal itemClicked(int index)
    signal loadMoreRequested()

    /* ══════════════════════ 尺寸 ══════════════════════
     *
     * 与 QSkinCard 同款：**默认按内容收缩**。要撑满请调用方写
     * `Layout.fillWidth: true`，或者直接给 width ——
     * 控件自己抢宽度会与 Layout 打架（见 QSkinRow.qml 里那段注释）。
     *
     * ── 为什么要把 _framePad 加回来 ─────────────────────────────────────
     * `shell` 是 `anchors.fill` + `anchors.margins: _framePad`：外框模式下
     * 它比 root **四面各小 16px**。而 anchored 的子项不会反过来把尺寸喂给
     * 父项的隐式尺寸，所以 `implicitHeight = shell.implicitHeight` 会算漏
     * 上下两条 16px —— 外框（`anchors.fill: parent`）就只有内容那么高，
     * 条目直接溢出边框下缘。
     *
     * M19 抓图实测：bordered 列表的隐式高报 120，而它的内容需要 152；
     * 那一屏因为 height 是显式给的，问题没露出来，量隐式高才露出来。
     * 所以这里两侧都补上 —— 尺寸账要算完整，别让调用方替控件补。 */

    implicitWidth:  shell.implicitWidth  + root._framePad * 2
    implicitHeight: shell.implicitHeight + root._framePad * 2

    width:  implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.List
    Accessible.name: qsTr("列表")
    Accessible.description: qsTr("%1 个条目").arg(root.count)

    /* ══════════════════════ 内部状态 ══════════════════════ */

    property int _hover: -1
    property int _pressed: -1

    /** 条目内边距。三档尺寸各给一对（竖向 / 横向）。 */
    readonly property int _padV: root.size === "sm" ? Theme.space.sm
                               : root.size === "lg" ? Theme.space.lg
                                                    : Theme.space.md
    readonly property int _padH: root.size === "sm" ? Theme.space.md
                               : root.size === "lg" ? Theme.space.xl
                                                    : Theme.space.lg

    /** 外框内边距。竖排时头/尾与条目贴边不好看，给一档内距；
     *  多列时由 gutter 负责，不再叠加。 */
    readonly property int _framePad: root.bordered ? root._padH : 0

    /* ══════════════════════ 外框 ══════════════════════ */

    Rectangle {
        id: frame

        anchors.fill: parent

        visible: root.bordered
        color:  Theme.color.bgElevated
        radius: Theme.radius.lg
        border.width: root.bordered ? 1 : 0
        border.color: Theme.color.border

        /* 尺寸跟着 root 走。root 的 implicit 尺寸又来自 shell ——
         * 而 shell 是 frame 的子项，看起来是个环。不会成环的原因：
         * shell 的 implicit 尺寸只由**内容**决定，与 frame 无关。 */
        z: -1
    }

    /* ══════════════════════ 主结构 ══════════════════════ */

    QSkinColumn {
        id: shell

        anchors.fill: parent
        anchors.margins: root._framePad
        gap: 0
        padding: 0

        /* ── 头部 ──
         * 只有真的放了东西才占位（`data.length` 而不是 `children.length`，
         * 理由见 QSkinCard 里同一段注释）。
         *
         * ── 宿主里**不能**再声明任何子项 ────────────────────────────────
         * 第一版把"头与条目区之间的那条线"写在了宿主内部。于是
         * `headerHost.data` 里**永远有那一条线**，`data.length > 0`
         * 恒成立 —— 宿主永远可见、永远占一档高度（实测 33px）。
         * 后果是全列表整体下移 33 + 尾部 33，条目区被挤出外框下缘；
         * 而属性侧一切自洽（没人会去断言"空头部的高度是 0"）。
         * M19 抓图 + 像素实测抓到：第一行 101px、其余 54px，总高 316 > 外框 240。
         *
         * 所以分割线挪到 shell 这一层（与宿主平级），由 `hasHeader` /
         * `hasFooter` 决定可见性。顺带也更贴近 Ant / TDesign 的 bordered
         * 列表 —— 它们的分隔线是**通栏**的，不在内容的内边距里。 */
        QSkinColumn {
            id: headerHost

            fill: true
            gap: root._padV
            padding: root._padH
            visible: headerHost.data.length > 0
        }

        QSkinDivider {
            Layout.fillWidth: true
            visible: root.bordered && headerHost.data.length > 0
        }

        /* ── 条目区 / 空态 / 状态行 ──
         * 一层 Loader 二选一，避免"两个分支都实例化、靠 visible 遮" ——
         * 那样空列表也会真的把 delegate 跑一遍（delegate 里可能有网络图片）。 */
        Loader {
            id: bodyLoader

            Layout.fillWidth: true
            sourceComponent: root.hasStatusRow ? statusComp
                           : root.hasEmptyState ? emptyComp
                           : rowsComp
        }

        QSkinDivider {
            Layout.fillWidth: true
            visible: root.bordered && footerHost.data.length > 0
        }

        /* ── 尾部 ── */
        QSkinColumn {
            id: footerHost

            fill: true
            gap: root._padV
            padding: root._padH
            visible: footerHost.data.length > 0
        }
    }

    /* ══════════════════════ 条目区 ══════════════════════
     *
     * 用一个 Grid 同时承担"竖排"和"多列"两种形态：
     * `columns: 1` 的 GridLayout 就是 ColumnLayout（每行一格、占满整行）。
     * 分成两个分支写会把下面的 Repeater 抄两遍，而两份之间一旦漂移，
     * 症状是"列表在某些尺寸下才不对"。
     *
     * 网格里放**行外壳**而不是直接放 delegate：hover 底、内边距、
     * 分割线这三件事必须由宿主统一给，见文件头"条目交互"那一段。 */

    // qmllint disable unqualified
    Component {
        id: rowsComp

        QSkinGrid {
            columns: Math.max(1, root.columns)
            gap: root.columns > 1 ? root.gutter : root.gap
            padding: 0
            equalColumns: true

            Repeater {
                model: root.model
                delegate: rowComp
            }
        }
    }

    Component {
        id: rowComp

        Item {
            id: rowItem

            property int index
            property var modelData

            Layout.fillWidth: true
            /* 行高 = 内容隐式高 + 上下内边距。
             * 用 `cellLoader.implicitHeight` 而不是 `cellLoader.item.implicitHeight`：
             * Loader 的隐式尺寸本来就跟随它的 item，直接读它既少一层判空，
             * 也让静态检查能推出类型（item 的静态类型是 QObject）。 */
            implicitHeight: cellLoader.implicitHeight + root._padV * 2

            readonly property bool isHovered: hoverH.hovered
            readonly property bool isPressed: tapH.pressed

            /* ── 底色：隔行 / 悬停 / 按下 ──
             * 三档优先级：按下 > 悬停 > 隔行。三档各用一个令牌 ——
             * 复用同一档会让"悬停在隔行条目上"看不出任何变化。 */
            Rectangle {
                id: rowBg

                anchors.fill: parent
                color: rowItem._bg()

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.motion.fast
                        easing.type: Theme.motion.easing
                    }
                }
            }

            Loader {
                id: cellLoader

                x: root._padH
                y: root._padV
                width: Math.max(0, rowItem.width - root._padH * 2)
                /* 高度不写 —— 让它等于 implicitHeight（跟随 item）。 */

                sourceComponent: root.delegate

                /* 数据注入走 onLoaded 而不是 Binding：
                 * Binding 会无条件给目标属性赋值，delegate 忘了声明
                 * modelData 时就变成每帧一条警告；onLoaded 只跑一次，
                 * 且能顺带做 null 保护。 */
                onLoaded: {
                    if (!cellLoader.item)
                        return
                    cellLoader.item.modelData = rowItem.modelData
                    cellLoader.item.index = rowItem.index
                }
            }

                        MouseArea {
                /* Qt 5.11 无 HoverHandler（Pointer Handlers 是 Qt 5.15 才有）
                 * → 降级为 MouseArea。hoverEnabled: true 是前提：5.11 的
                 *   MouseArea 默认不上报 onEntered/onExited（5.15 默认开）。 */
                /* hovered 兼容：HoverHandler 的状态在 5.11 无对应属性 */
                readonly property bool hovered: containsMouse
                hoverEnabled: true

                id: hoverH

                enabled: root.hoverable || root.clickable
                cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor

                onEntered: root._hover = rowItem.index
                onExited:  root._hover = -1

            }

            /* 用 TapHandler 而不是 MouseArea：鼠标区域会**吃掉**条目内部
             * 控件的点击（列表条目里放一个按钮是常见需求），而指针处理器
             * 走的是"最内层优先"的抢占规则 —— 条目里的按钮照常可点，
             * 空白处的点击才落到这里。 */
                        MouseArea {
                /* Qt 5.11 无 TapHandler（Pointer Handlers 是 Qt 5.15 才有）
                 * → 降级为 MouseArea。hoverEnabled: true 是前提：5.11 的
                 *   MouseArea 默认不上报 onEntered/onExited（5.15 默认开）。 */

                id: tapH

                enabled: root.clickable
                onPressedChanged: root._pressed = tapH.pressed ? rowItem.index : -1
                onClicked: root.itemClicked(rowItem.index)

            }

            /* ── 分割线 ──
             * 画在行的最底一行像素上，于是它正好落在两条条目的交界处
             * （而不是"下一条的顶部"—— 那在 gap > 0 时会分家）。
             * 最后一条下面不画：那会在列表末尾留一条悬空的线。
             *
             * ── `fill: true` 不是可选的 ─────────────────────────────────
             * QSkinDivider 横向的 `implicitWidth` 是 **0**，它只在 `fill`
             * 打开时才把宽度接到 `parent.width` 上。而这里不是布局子项
             * （挂在裸 Item 里），写 `Layout.fillWidth` 不会生效 ——
             * 于是分割线宽度为 0，**一条都画不出来**。
             * M19 抓图实测抓到：行距 48 全对、`splitActive` 为 true、
             * 图上一个像素的线都没有。属性侧完全测不到这一层。 */
            QSkinDivider {
                fill: true
                visible: root.splitActive && rowItem.index < root.count - 1
                y: rowItem.height - implicitHeight
            }

            function _bg() {
                if (rowItem.isPressed && root.clickable) return Theme.color.bgSunken
                if (rowItem.isHovered && (root.hoverable || root.clickable))
                    return Theme.color.bgSunken
                if (root.stripe && rowItem.index % 2 === 1) return Theme.color.bgSubtle
                return "transparent"
            }
        }
    }

    /* ══════════════════════ 空态 ══════════════════════
     *
     * 根用 QSkinColumn 而不是裸 Item + 手算隐式高：内边距由布局自己算，
     * 于是"上下各留一格"这件事不需要在两处（隐式高、锚点）保持一致。
     *
     * ── textMaxWidth 要把三层内距全减掉（M19 抓图抓出来的）──
     * 早先写的是 `min(root.width, emptyTextMaxWidth)` —— 拿列表框的
     * **外宽**（360）当可用宽，算出 320。可空态真正能用的宽度是
     *      360 − 外框内距×2（32）− 这一层的内距×2（两侧共 48） = 280
     * 于是 QSkinEmpty 的隐式宽（320）比可用宽大 40，溢出到右边；
     * 而插图是在 QSkinEmpty **内部**居中的，于是整块跟着偏右 20px ——
     * 抓图实测插图中心 223.7，本该在 204（= 列表中心）。
     *
     * 这个错在属性侧是隐形的：`textMaxWidth` 的值"看起来在范围内"、
     * `_iw`/`_ih` 全对、`hasText` 也对，只有像素上量得出来。
     *
     * ⚠ 这里刻意**只用 root 自己的属性**算，不去读"加载后那一层的宽度"：
     * QSkinList 是 `width: implicitWidth`，而空态块的隐式宽又会喂回
     * shell 的隐式宽 —— 读子项宽度会成环。减内距是纯函数，不会。 */
    readonly property int _emptyAvailW:
        Math.max(0, root.width - root._framePad * 2 - root._padV * 4)

    Component {
        id: emptyComp

        QSkinColumn {
            id: emptyBox

            padding: root._padV * 2
            align: "center"
            gap: 0

            QSkinEmpty {
                id: emptyItem

                imageSource:   root.emptyImage
                description:   root.emptyText
                size:          root.size
                textMaxWidth:  Math.min(root._emptyAvailW, root.emptyTextMaxWidth)
            }
        }
    }

    /* ══════════════════════ 状态行 ══════════════════════
     *
     * 加载 / 加载更多 / 没有更多，三行互斥，优先级从上到下。
     * 全都居中、都送同样的内边距 —— 三行替换时高度不该跳。 */

    Component {
        id: statusComp

        QSkinColumn {
            padding: root._padV * 2
            align: "center"
            gap: 0

            QSkinRow {
                id: statusRow

                gap: Theme.space.sm
                align: "center"

                QSkinSpin {
                    visible: root.loading
                    spinning: root.loading
                    size: "sm"
                    overlay: false
                }

                Body {
                    visible: root.loading && root.loadingText !== ""
                    text: root.loadingText
                    tone: "secondary"
                }

                /* "加载更多"用 QSkinButton 的 text 变体而不是自绘一个可点文字：
                 * 可点区域、hover 反馈、键盘可达性都已经在里面了。 */
                QSkinButton {
                    visible: !root.loading && root.loadMore
                    text: root.loadMoreText
                    variant: "text"
                    size: "sm"
                    onClicked: root.loadMoreRequested()
                }

                Caption {
                    visible: !root.loading && !root.loadMore && root.noMore
                    text: root.noMoreText
                }
            }
        }
    }
    // qmllint enable unqualified

    /* ══════════════════════ 内部 ══════════════════════ */

    /** 把 model 的三种形态归一成条目数。
     *
     *  ── 为什么不能直接读 `model.length` ──────────────────────────────
     *  `model` 是 var：它可以是一个数字（此时 `.length` 是 undefined，
     *  于是"3 条数据"会被算成 0 条，列表直接显示空态），
     *  也可以是 ListModel（它**有** length，但那是 QML 的实现细节，
     *  官方给的是 count）。所以三种形态各读各的字段。 */
    function _count() {
        var m = root.model
        if (m === null || m === undefined) return 0
        if (typeof m === "number") return Math.max(0, Math.floor(m))
        if (m.count !== undefined) return m.count          /* ListModel */
        if (m.length !== undefined) return m.length        /* JS 数组 */
        if (m.rowCount !== undefined) return m.rowCount()  /* QAbstractItemModel */
        return 0
    }
}
