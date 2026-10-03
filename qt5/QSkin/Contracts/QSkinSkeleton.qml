/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinSkeleton
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 骨架屏 —— 内容还没到，先把**版式**占出来。
 *
 * ── 它和 QSkinSpin 的分工（这一批里最容易被随手混的一对）───────────────
 *   QSkinSkeleton   **知道**内容长什么样：列表就是"一个圆 + 三行字"，
 *                 卡片就是"一张图 + 标题 + 两行"。于是先把真实版式占好，
 *                 数据回来时**不跳位**。
 *   QSkinSpin       **不知道**内容长什么样，只说"在跑"。
 * 判据：能提前画出"内容的骨架"吗？能 → Skeleton；不能 → Spin。
 *
 * ── 两个颜色令牌，一条硬约束 ────────────────────────────────────────────
 *   块   = Theme.color.bgSunken
 *   流光 = Theme.color.divider
 *
 * 为什么不自己造一对灰：这两个令牌已经被 M18.1 的可见性门禁守住了 ——
 * **每一套主题的 divider 都必须在自己的 bg 上可辨识**。
 * 骨架屏恰恰是最依赖这条约束的控件：块比页底色只深一点点是它的常态，
 * 而"深一点点"到了 TDesign（bg #EEEEEE）这种灰底主题上很容易变成
 * "完全看不见"。借用一个已有的、被门禁盯着的关系，比自己挑两个灰安全。
 *
 * 顺带得到一件好事：深色主题下 bgSunken 更暗、divider 更亮，
 * 光流的方向自动从"变暗"翻成"变亮"，不需要写第二套。
 *
 * ── 闪动用**移动的渐变带**，不用改 GradientStop 的位置 ──────────────────
 * 两种都能做出流光。选前者的理由：渐变带是一个普通 Rectangle，
 * 它的 `x` 是唯一被动画的属性 —— 而 GradientStop.position 被动画时，
 * 每一帧都会让 Qt 重建整条渐变。一个页面上同时有 30 个骨架块时，
 * 那是 30 条渐变在每帧重建。
 *
 * ── 圆角块上的流光会露出方角（一处已知且可接受的小瑕疵）────────────────
 * Qt 的 `clip` 只裁包围盒，不裁圆角（这一点在 QSkinAvatar 的文件头
 * 有实测记录）。所以 `round: true` 的药丸块上，流光带扫过两端时
 * 会有一小块方角压到圆角外面。修它需要 MultiEffect 遮罩 ——
 * 每个块一层离屏纹理，代价明显大于收益。这里把流光带**也做成药丸**，
 * 让它的两个端帽自己就是圆的，缺陷因此只剩圆角外的一两个像素。
 *
 * ── TDesign 的 `theme` 没有实现 ─────────────────────────────────────────
 * TDesign 的 Skeleton 有一个 `theme: text | avatar | paragraph | image`
 * 的**预设开关**。它的四种取值在本实现里都能用部件开关组合出来：
 *
 *     theme="avatar"     → avatar: true
 *     theme="paragraph"  → title: false; paragraph: true
 *     theme="image"      → image: true
 *     theme="text"       → 默认
 *
 * 再加一个预设层，等于给同一个状态两种写法 —— 而两种写法之间
 * 一旦漂移（预设漏改了一个新属性），症状是"某个 theme 值下不对"。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 状态 ══════════════════════ */

    /** 是否显示骨架。false 时渲染默认属性里的内容。 */
    property bool loading: true

    /** 延迟多少毫秒之后才显示骨架。与 QSkinSpin 同款 ——
     *  骨架屏比转圈更"占地"，一次 50ms 的请求闪一下骨架比不显示更糟。 */
    property int delay: 0

    /** wave（流光横扫）| pulse（整体呼吸）| none（静止） */
    property string animation: "wave"

    /** 被占位的内容。骨架消失后原样显示。 */
    default property alias content: contentHost.data

    /* ══════════════════════ 部件开关 ══════════════════════ */

    /** 标题行。 */
    property bool title: true

    /** 标题行宽度。≤1 表示占可用宽度的比例，>1 表示像素。 */
    property real titleWidth: 0.38

    /** 段落。 */
    property bool paragraph: true

    /** 段落行数。 */
    property int rows: 3

    /** 段落每行的宽度（语义同 titleWidth）。 */
    property real rowWidth: 1.0

    /** **最后一行**的宽度 —— 等长会读成"表格"，短一截才读成"一段文字"。 */
    property real lastRowWidth: 0.61

    /** 头像占位。 */
    property bool avatar: false

    /** circle | square */
    property string avatarShape: "circle"

    /** 图片占位。 */
    property bool image: false

    /** square | round | circle */
    property string imageShape: "round"

    /** left | right | top | bottom —— 图片相对文字的位置。 */
    property string imagePosition: "left"

    /** 圆角块（药丸）。Ant 的 `round`。 */
    property bool round: false

    /* ══════════════════════ 尺寸 ══════════════════════ */

    /** 无外部宽度约束时的基准宽度。所有"比例型"宽度都按它折算 ——
     *  没有这个基准，`rowWidth: 1.0` 会变成"100% 的未知量"，
     *  于是隐式尺寸成环。 */
    property int baseWidth: 320

    /** 头像占位块的边长。 */
    property int avatarSize: Theme.size.controlLg

    /** 标题行高。 */
    property int titleHeight: 16

    /** 段落行高。 */
    property int rowHeight: 16

    /** 图片占位块的边长（正方形）。 */
    property int imageSize: 96

    /** 图片与文字之间的距离。 */
    property int gap: Theme.space.lg

    /** 标题与段落之间、段落各行之间的距离。 */
    property int blockGap: Theme.space.sm

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property bool active: root.loading && root._shown

    /** 骨架的可见性跟着 _shown 走；内容反过来。 */
    readonly property bool skeletonVisible: root.active
    readonly property bool contentVisible: !root.loading || !root.active

    readonly property bool _side: root.image
                                  && (root.imagePosition === "left" || root.imagePosition === "right")

    /* GridLayout 的显式落位。写成一组只读属性而不是散在子项里：
     * 四轴的组合只有这 5 种情形，集中写出比在 6 个子项上分别判断清楚。 */
    readonly property int _imgRow:  (root.image && root.imagePosition === "top")    ? 0
                                 : (root.image && root.imagePosition === "bottom") ? 1 : 0
    readonly property int _txtRow:  (root.image && root.imagePosition === "top")    ? 1 : 0
    readonly property int _imgCol:  (root.image && root.imagePosition === "right")  ? 1 : 0
    readonly property int _txtCol:  (root.image && root.imagePosition === "left")   ? 1 : 0
    readonly property int _imgSpan: (root.image && !root._side) ? 2 : 1
    readonly property int _txtSpan: root._side ? 1 : 2

    implicitWidth:  root.loading ? grid.implicitWidth : contentHost.implicitWidth
    implicitHeight: root.loading ? grid.implicitHeight : contentHost.implicitHeight

    width:  implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("内容加载中")
    Accessible.ignored: !root.active

    /* ══════════════════════ 延迟状态机 ══════════════════════ */

    property bool _shown: true

    Timer {
        id: delayTimer
        interval: Math.max(0, root.delay)
        onTriggered: root._shown = true
    }

    onLoadingChanged: {
        if (!root.loading) {
            delayTimer.stop()
            root._shown = true
        } else if (root.delay > 0) {
            root._shown = false
            delayTimer.restart()
        } else {
            root._shown = true
        }
    }

    Component.onCompleted: {
        if (root.loading && root.delay > 0) {
            root._shown = false
            delayTimer.start()
        }
    }

    /* ══════════════════════ 骨架 ══════════════════════ */

    GridLayout {
        id: grid

        anchors.fill: parent
        visible: root.skeletonVisible

        columns: 2
        columnSpacing: root.gap
        rowSpacing: root.gap

        /* ── 图（可选）── */
        Loader {
            id: imageLoader

            Layout.row:          root._imgRow
            Layout.column:       root._imgCol
            Layout.columnSpan:   root._imgSpan
            Layout.preferredWidth:  root.imageSize
            Layout.preferredHeight: root.imageSize
            Layout.alignment:    Qt.AlignTop

            visible: root.image
            sourceComponent: root.image ? blockComp : null

            Binding {
                target: imageLoader.item; property: "shape"
                value: root.imageShape
                when: imageLoader.item !== null
            }
        }

        /* ── 头像（可选）──
         * 与图并列在文字左侧：三家都是这个排布（头像 + 两行字的
         * 评论/消息骨架），所以它不参与 imagePosition 的四向逻辑。
         *
         * **与 image 互斥，image 优先**：两者都是"文字左边那一块"，
         * 同时开会在同一格里叠起来。它们在一个骨架里也从不并存
         * （头像骨架说的是"一条评论"，图片骨架说的是"一张封面"）。 */
        Loader {
            id: avatarLoader

            Layout.row:    0
            Layout.column: 0
            Layout.preferredWidth:  root.avatarSize
            Layout.preferredHeight: root.avatarSize
            Layout.alignment: Qt.AlignTop

            visible: root.avatar && !root.image
            sourceComponent: (root.avatar && !root.image) ? blockComp : null

            Binding {
                target: avatarLoader.item; property: "shape"
                value: root.avatarShape
                when: avatarLoader.item !== null
            }
        }

        /* ── 文字 ── */
        ColumnLayout {
            id: textCol

            /* 有头像时文字落在右列（头像占了左列的第 0 行）。 */
            Layout.row:        root._txtRow
            Layout.column:     root.avatar && !root.image ? 1 : root._txtCol
            Layout.columnSpan: root.avatar && !root.image ? 1 : root._txtSpan
            Layout.fillWidth:  true

            spacing: root.blockGap

            /* ── 标题 ── */
            Loader {
                id: titleLoader

                Layout.fillWidth: true
                Layout.preferredWidth:  root.baseWidth
                Layout.preferredHeight: root.titleHeight

                visible: root.title
                sourceComponent: root.title ? blockComp : null

                Binding {
                    target: titleLoader.item; property: "fraction"
                    value: root.titleWidth
                    when: titleLoader.item !== null
                }
                Binding {
                    target: titleLoader.item; property: "pill"
                    value: root.round
                    when: titleLoader.item !== null
                }
            }

            /* ── 段落 ── */
            ColumnLayout {
                id: paraCol

                Layout.fillWidth: true
                spacing: root.blockGap

                /* delegate 写在 `delegate:` 后面（不是独立的 Component），
                 * qmllint 解析外层 id 会受限 —— 与 QSkinBreadcrumb / QSkinTabs
                 * 同款，局部关闭该检查。 */
                // qmllint disable unqualified
                Repeater {
                    model: root.paragraph ? Math.max(1, root.rows) : 0

                    delegate: Loader {
                        id: rowLoader

                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredWidth:  root.baseWidth
                        Layout.preferredHeight: root.rowHeight

                        sourceComponent: blockComp

                        Binding {
                            target: rowLoader.item; property: "fraction"
                            value: (rowLoader.index === root.rows - 1)
                                   ? root.lastRowWidth : root.rowWidth
                            when: rowLoader.item !== null
                        }
                        Binding {
                            target: rowLoader.item; property: "pill"
                            value: root.round
                            when: rowLoader.item !== null
                        }
                    }
                }
                // qmllint enable unqualified
            }
        }
    }

    /* ══════════════════════ 内容 ══════════════════════
     *
     * 骨架消失后显示的东西**一直在对象树里**，只是 visible 被关掉。
     * 为什么不是"加载完再创建"：那样每次切换都要重建整棵子树，
     * 内容里的滚动位置、展开状态、输入框里已经敲了一半的字全丢。
     * 代价是内容在加载期间也被实例化了 —— 但调用方既然已经把内容
     * 写出来了，本来也准备了它的开销。 */

    QSkinColumn {
        id: contentHost

        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top

        visible: root.contentVisible
        gap: 0
        padding: 0
    }

    /* ══════════════════════ 骨架块 ══════════════════════
     *
     * 一块"底色 + 流光带"。三种用法（标题 / 段落行 / 图）共用它，
     * 靠 `fraction` / `shape` / `pill` 三个开关区分。
     *
     * 为什么外面套一个零尺寸的 Item：Layout 的 fillWidth 给的是**整格**
     * 宽度，而 `fraction` 要的是"整格宽度的一个比例"。让 Item 拿满、
     * 里面那条矩形按比例取宽，两者就不会互相覆盖绑定。 */

    // qmllint disable unqualified
    Component {
        id: blockComp

        Item {
            id: block

            /** 宽度：≤1 取宿主宽度的比例，>1 取像素。 */
            property real fraction: 1.0
            /** 形状：square | round | circle */
            property string shape: "square"
            /** 药丸（等价于 shape: "round"，Ant 的 round 开关）。 */
            property bool pill: false

            readonly property real _radius:
                block.shape === "circle" ? block.height / 2
              : (block.pill || block.shape === "round") ? Math.min(Theme.radius.md, block.height / 2)
              : Theme.radius.sm

            Rectangle {
                id: bar

                anchors.left:   parent.left
                anchors.top:    parent.top
                anchors.bottom: parent.bottom

                width: block.fraction <= 1
                       ? Math.round(parent.width * block.fraction)
                       : Math.round(block.fraction)

                radius: block._radius
                color:  Theme.color.bgSunken
                clip:   true

                /* 呼吸：整块的透明度来回走 */
                SequentialAnimation on opacity {
                    running: root.active && root.animation === "pulse"
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.45; to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }

                /* 流光：一条透明 → divider → 透明的带子横扫 */
                Rectangle {
                    id: wave

                    y: 0
                    height: bar.height
                    width: Math.max(bar.height * 2, bar.width * 0.6)
                    radius: bar.radius
                    visible: root.active && root.animation === "wave"

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Theme.color.divider }
                        GradientStop { position: 1.0; color: "transparent" }
                    }

                    SequentialAnimation on x {
                        running: wave.visible
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: -wave.width
                            to: bar.width
                            duration: 1200
                            easing.type: Easing.InOutSine
                        }
                        PauseAnimation { duration: 300 }
                    }
                }
            }
        }
    }
    // qmllint enable unqualified
}
