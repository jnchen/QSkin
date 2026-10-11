/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinSpin
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 加载指示器 —— "正在跑，稍等"。
 *
 * ── 它和 QSkinSkeleton 的分工（这一批里最容易被随手混的一对）─────────────
 *   QSkinSkeleton   **知道**内容长什么样（列表就是三行、卡片就是一张图），
 *                 于是先把真实版式占出来。加载完内容不跳位。
 *   QSkinSpin       **不知道**内容长什么样，或者内容本来就只是一小块。
 *                 它只说"在跑"，不承诺版式。
 * 判据：能提前画出"内容的骨架"吗？能 → Skeleton；不能 → Spin。
 * 所以按钮里的转圈、下拉刷新、表格的 loading 遮罩都用 Spin，
 * 而"列表首次加载"该用 Skeleton。
 *
 * ── 形态是**主题**的事，而且不能被合并成一个插槽 ────────────────────────
 * 这一批新增两个插槽家族成员：`spinRing`（一段弧在转）与 `spinDots`
 * （一组点在脉冲）。
 *
 * 为什么不合成一个 `spinIndicator` 槽、让主题在读 `control.variant`
 * 之后自己分岔：这恰好是契约层那条**已有的**判据 ——
 *     「当两个使用者对**尺寸**的要求冲突时，不要复用插槽；
 *       只有当它们只差**颜色/字重**时，才复用。」
 * 环形与点阵是两种**结构**（一条描边 vs N 个实心块），它们连
 * "自己的自然尺寸"都不一样：环的线宽与直径绑定，点的直径与间距无关。
 * 塞进一个槽，主题作者第一件事就是写 `if (variant === "dots") …` ——
 * 那正是契约要消灭的东西。（同一条判据在 M4 就把
 * switchIndicator / checkIndicator 分成了两个槽。）
 *
 * 四家主题的覆盖情况（这就是"形态属于主题"的实证）：
 *     TDesign    spinRing    一圈带缺口的环（官方 theme: circular）
 *     Ant        spinRing    四段弧的环（官方 LoadingOutlined 的形）
 *     Arco       spinDots    四点脉冲（Arco 的签名形态，官方 dot 模式）
 *     shadcn     spinRing    一段 300° 的弧（lucide Loader2 的形）
 * 未被覆盖的那一格保留 Basic 实现 —— 契约层的常态，不是缺口。
 *
 * ── 刻意不做 fullscreen（TDesign 有，本项目不实现）──────────────────────
 * 全屏遮罩是**浮层**的职责，不是指示器的职责：它要盖住整个窗口、
 * 拦住所有点击、还要处理 Esc 与焦点陷阱 —— 那是 QSkinDialog 已经
 * 交付过的一整套东西。在 QSkin 里"全屏加载"由两件现成的东西组合出来：
 * 一个铺满窗口的容器 + 一个 `overlay: true` 的 QSkinSpin。
 *
 * 有一条硬约束逼着这个决定：QSkinSpin 的绝大多数用法（按钮内、列表行内、
 * 骨架旁）**根本不在窗口上下文里**，而浮层必须挂在 Overlay 上。
 * 把它塞进 Spin，等于让一个纯指示器依赖 QtQuick.Controls 与窗口 Overlay，
 * 并且在没有窗口的场合（冒烟测试、离屏渲染）每次都报一条空 parent。
 *
 * ── 不做模糊（blur）────────────────────────────────────────────────────
 * Ant 的 Spin 给被遮住的内容加 `filter: blur(2px)`。QML 里那需要
 * QtQuick.Effects / MultiEffect，而本项目全程没有引入它（同 M18 里
 * "层次用底色而不是阴影"那一条）。这里用**降透明度**代替：
 * 观感上同样是"内容退到后面去"，但没有引入新的渲染后端依赖。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 状态 ══════════════════════ */

    /** 是否正在加载。 */
    property bool spinning: true

    /** 延迟多少毫秒之后才把指示器画出来。
     *
     *  这不是"美观"，是**防闪烁**：一次 60ms 的请求如果立刻就转圈，
     *  用户看到的是一个一闪而过的图形，比什么都不显示更像"出错了"。
     *  TDesign 与 Arco 都有这个开关，默认 0（不延迟）——
     *  因为"要不要延迟"取决于这次请求的预期耗时，只有调用方知道。 */
    property int delay: 0

    /* ══════════════════════ 外观 ══════════════════════ */

    /** ring | dots —— 见文件头"形态是主题的事"。 */
    property string variant: "ring"

    /** sm | md | lg，或者直接给像素数。
     *  与 QSkinAvatar 同款：`var` 型 —— 名字给常用档，数字给精确控制。 */
    property var size: "md"

    /** 指示器下方的说明文字。空串 = 不占位。 */
    property string tip: ""

    /** 指示器的颜色。 */
    property color color: root.inheritColor ? root._inheritedColor() : Theme.color.brand

    /** 从父项取前景色（TDesign 的 inheritColor）——
     *  放在深色按钮里时不必手写颜色。父项没有 `color` 属性时退回品牌色。 */
    property bool inheritColor: false

    /** 指示器转一圈的毫秒数。所有形态共用这一个旋钮 ——
     *  "转多快"是节奏，不该四处硬编码。 */
    property int period: Theme.motion.slow * 3      /* 960 */

    /* ══════════════════════ 包裹内容 ══════════════════════ */

    /** 被遮住的内容。不写就是**独立指示器**（只有一个圈），
     *  写了就是**包裹模式**（内容照常渲染，加载时压一层遮罩）。
     *
     *      QSkinSpin { QSkinCard { ... } }          // 包裹
     *      QSkinSpin { size: "sm" }               // 独立
     */
    default property alias content: contentHost.data

    /** 包裹模式下是否压遮罩。关掉它就只剩一个浮在内容中央的圈 ——
     *  适合"内容本身不刺眼，只想告诉你还在等"的场合。 */
    property bool overlay: true

    /** 遮罩的不透明度。见文件头"不做模糊"那一段。 */
    property real overlayOpacity: 0.65

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property bool hasContent: contentHost.data.length > 0

    /** 指示器的边长（像素）。 */
    readonly property int indicatorSize:
        typeof root.size === "number" ? Math.max(8, Math.round(root.size))
      : root.size === "sm" ? 16
      : root.size === "lg" ? 32
                           : 24

    /** 描边宽度。按直径的 1/10 取 —— 三档下分别是 2 / 2 / 3。
     *  固定 2px 在 lg 上会显得细，在小尺寸下又会显得糊。 */
    readonly property int strokeWidth: Math.max(2, Math.round(root.indicatorSize / 10))

    /** 此刻是否真的在画。delay 未满时是 false。 */
    readonly property bool active: root.spinning && root._shown

    /** 尺寸 = 内容尺寸（包裹模式）或指示器块的尺寸（独立模式）。 */
    implicitWidth:  root.hasContent ? contentHost.implicitWidth  : blockHost.implicitWidth
    implicitHeight: root.hasContent ? contentHost.implicitHeight : blockHost.implicitHeight

    width:  implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: root.tip !== "" ? root.tip : qsTr("加载中")
    Accessible.ignored: !root.active

    /* ══════════════════════ 延迟状态机 ══════════════════════ */

    property bool _shown: true

    Timer {
        id: delayTimer
        interval: Math.max(0, root.delay)
        onTriggered: root._shown = true
    }

    onSpinningChanged: {
        if (!root.spinning) {
            delayTimer.stop()
            root._shown = root.delay <= 0
        } else if (root.delay > 0) {
            root._shown = false
            delayTimer.restart()
        } else {
            root._shown = true
        }
    }

    Component.onCompleted: {
        if (root.spinning && root.delay > 0) {
            root._shown = false
            delayTimer.start()
        }
    }

    /* ══════════════════════ 被包裹的内容 ══════════════════════ */

    QSkinColumn {
        id: contentHost

        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top

        visible: root.hasContent
        gap: 0
        padding: 0
    }

    /* ══════════════════════ 遮罩 ══════════════════════
     *
     * 用 Theme.color.bg 而不是 Theme.color.scrim：scrim 是**模态遮罩**
     * （黑/深色，用于"你不能碰后面"），而加载遮罩的语义是
     * "后面这块还没准备好"，用页面底色淡出才对 —— 黑色遮罩配转圈
     * 会被读成"出错了"。而且 bg 会跟着主题换，深色主题下自然变暗。 */

    Rectangle {
        anchors.fill: parent
        visible: root.hasContent && root.active && root.overlay
        color: Theme.color.bg
        opacity: root.overlayOpacity
        radius: Theme.radius.sm
    }

    /* ══════════════════════ 指示器块 ══════════════════════ */

    Item {
        id: blockHost

        /* 独立模式：贴在原点（root 的尺寸就等于它）。
         * 包裹模式：居中压在内容上。 */
        x: root.hasContent ? Math.round((root.width  - width)  / 2) : 0
        y: root.hasContent ? Math.round((root.height - height) / 2) : 0
        width:  block.implicitWidth
        height: block.implicitHeight
        visible: root.active

        QSkinColumn {
            id: block

            anchors.fill: parent
            gap: Theme.space.sm
            padding: 0
            align: "center"

            Item {
                id: ringHost

                Layout.alignment: Qt.AlignHCenter
                implicitWidth:  root.indicatorSize
                implicitHeight: root.indicatorSize

                /* 形态由主题决定。Loader 只负责把宿主实例化出来
                 * 并把 `control` 注入进去 —— 契约三条见 Slots.qml。 */
                Loader {
                    id: indicatorLoader

                    anchors.fill: parent
                    sourceComponent: root.variant === "dots" ? Slots.spinDots
                                                             : Slots.spinRing

                    Binding {
                        target: indicatorLoader.item
                        property: "control"
                        value: root
                        when: indicatorLoader.item !== null
                    }
                }
            }

            Text {
                id: tipText

                Layout.alignment: Qt.AlignHCenter
                visible: root.tip !== ""
                text: root.tip

                horizontalAlignment: Text.AlignHCenter
                renderType: Text.NativeRendering

                font.family:    Theme.font.family
                font.pixelSize: Theme.font.sm
                color:          Theme.color.fgSecondary
            }
        }
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    /* `root.parent` 的静态类型是 QQuickItem（没有 color）。这是刻意的
     * 鸭子类型读取 —— 父项可能是一个带 color 的 Rectangle / QSkinButton，
     * 也可能什么都没有。故只在函数级关闭该检查。 */
    // qmllint disable missing-property
    function _inheritedColor() {
        var p = root.parent
        if (p && p.color !== undefined)
            return p.color
        return Theme.color.brand
    }
    // qmllint enable missing-property
}
