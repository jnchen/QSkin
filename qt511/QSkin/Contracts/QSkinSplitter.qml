/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinSplitter
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 可拖拽分栏 —— 一条能拖的界线，把一块地分成两半。
 *
 * ── 和 QSkinLayout 的分工（两者都"分地"，但决定权不同）─────────────────────
 *   QSkinLayout   按**角色**分地：顶栏 / 内容 / 底栏。比例是控件算的，
 *               用户不参与。
 *   QSkinSplitter 按**用户的手**分地：界线在哪儿由用户拖出来，程序只保证
 *               它不越界。比例是用户的，控件不参与。
 * 所以它们是互补的：`QSkinLayout` 的中间区里放一个 `QSkinSplitter`
 * （左边文件树、右边编辑器）是最典型的组合。
 *
 * ── 为什么只做两栏，不做 N 栏 ──────────────────────────────────────────
 * 两栏的语义是"**一条线的位置**"—— 一个标量 ratio 就描述完了，边界条件
 * 只有"别把某一栏拖没"。N 栏的语义是"**一组权的分配**"，要处理
 * "某一栏拖到下限时其它栏怎么补"、"窗口变窄时按比例收缩还是按优先级
 * 收缩"这类多方协商，每一种都有合理但不同的答案。与其猜一个，不如让
 * N 栏由**嵌套**表达：
 *
 *     QSkinSplitter {                      // 左 | 右
 *         QSkinLayout { ... }
 *         QSkinSplitter {                  //   右再分上下
 *             orientation: "vertical"
 *             ...
 *         }
 *     }
 * 嵌套的每一层只有一条线要管，行为定义明确；而且"左右分 + 右再分上下"
 * 正是布局编辑器、IDE 这类场景真实的样子。
 *
 * ── 拖拽为什么不用 drag.target ─────────────────────────────────────────
 * 直觉写法是把 handle 的 x 绑到分界线上、再用 `drag.target: handle`：
 *
 *     handle.x: root.splitPos - handleSize / 2      ← 绑定
 *     MouseArea { drag.target: handle }             ← 拖拽要写 x
 *
 * 拖拽一旦开始，Qt 会把 `x` 从绑定里**摘出来**（setX 打断绑定）——
 * 之后 `ratio` 再变（窗口缩放、键盘微调、代码里改）handle 就不跟了。
 * 症状是"拖过一次之后，改 ratio 没反应"，而且只在拖过之后才出现。
 *
 * 这里改用**绝对坐标换算**：不把 handle 的位置当状态，而是每次事件都用
 * `mapToItem(root, ...)` 求出鼠标在 root 坐标里的位置。handle 自己动到
 * 哪儿都不影响这个换算，也不存在"绑定被打断"这回事。
 *
 * ── 键盘可调 + 双击复位，不只是体贴 ────────────────────────────────────
 * 一条纯靠拖的界线**没法被自动验证**（模拟拖拽要注入真实鼠标事件、
 * 还要处理阈值与抖动）。所以 handle 是聚焦点，← →（或 ↑ ↓）可微调、
 * Home / End 推到两端、双击复位到 50%。这几条让"分栏逻辑"能在
 * smoke 测试里用**属性**直接断言，也顺手解决了纯键盘用户用不了分栏的问题。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 方向 ══════════════════════ */

    /** horizontal：左右分栏（界线竖直）  vertical：上下分栏（界线水平） */
    property string orientation: "horizontal"

    readonly property bool horizontal: root.orientation !== "vertical"

    /* ══════════════════════ 两栏内容 ══════════════════════ */

    /** 第一栏（左 / 上）。内容自己写 anchors.fill: parent。 */
    property alias first: firstHost.data

    /** 第二栏（右 / 下） */
    property alias second: secondHost.data

    /* ══════════════════════ 界线位置 ══════════════════════ */

    /** 第一栏占总长的比例（0~1）。这是唯一的"位置状态"。 */
    property real ratio: 0.5

    /** 每一栏的最小尺寸（像素）。拖到这里就停 —— 不许把某一栏拖没，
     *  否则用户会得到一个"看不见但还在那儿"的面板，再也拖不回来。 */
    property int minSize: 80

    /** 双击界线时回到的比例 */
    property real resetRatio: 0.5

    /** 键盘每按一次调整的比例步长 */
    property real keyboardStep: 0.02

    /* ══════════════════════ 界线外观 ══════════════════════ */

    /** 是否可拖 */
    property bool resizable: true

    /** 界线的命中宽度（占位）。做宽一点是为了好抓 —— 视觉上的线可以很细。 */
    property int handleSize: 8

    /** 常态是否显示那条细线。关掉后只有 hover / 拖拽时才浮出来，
     *  适合"希望界面干净"的场景（分栏本身仍然拖得动）。 */
    property bool handleAlwaysVisible: true

    /* ══════════════════════ 状态（供槽 / 业务读） ══════════════════════ */

    property bool handleHovered: false
    property bool handlePressed: false

    /** 拖拽或键盘调整结束时发出 */
    signal resized()

    /* ══════════════════════ 几何 ══════════════════════
     *
     * ratio 是输入，splitPos 是**夹过之后**的结果。分开的两个量，
     * 是因为"用户想要 0.98"和"实际给到 0.98 还是 0.9"是两件事 ——
     * 容器一变窄，同一个 ratio 可能就不合法了，而用户想要的意图
     * （靠右）应当被保留，不该被就地改写成 0.9。 */

    readonly property real _total: root.horizontal ? root.width : root.height

    /** 界线中心相对第一栏起点的偏移 */
    readonly property real splitPos: {
        var total = root._total
        if (total <= 0) return 0
        var want = root.ratio * total
        /* 容器装不下两倍 minSize 时，两边各让一半 —— 不退化成负数 */
        var lo = Math.min(root.minSize, total / 2)
        var hi = Math.max(total - root.minSize, total / 2)
        return Math.max(lo, Math.min(want, hi))
    }

    implicitWidth:  root.horizontal
                    ? firstHost.implicitWidth + root.handleSize + secondHost.implicitWidth
                    : Math.max(firstHost.implicitWidth, secondHost.implicitWidth)
    implicitHeight: root.horizontal
                    ? Math.max(firstHost.implicitHeight, secondHost.implicitHeight)
                    : firstHost.implicitHeight + root.handleSize + secondHost.implicitHeight

    /* ══════════════════════ 两栏 ══════════════════════ */

    Item {
        id: firstHost

        x: 0
        y: 0
        width:  root.horizontal ? Math.max(0, root.splitPos - root.handleSize / 2) : root.width
        height: root.horizontal ? root.height
                                : Math.max(0, root.splitPos - root.handleSize / 2)
    }

    Item {
        id: secondHost

        x: root.horizontal ? Math.min(root.width, root.splitPos + root.handleSize / 2) : 0
        y: root.horizontal ? 0 : Math.min(root.height, root.splitPos + root.handleSize / 2)
        width:  root.horizontal ? Math.max(0, root.width - root.splitPos - root.handleSize / 2)
                                : root.width
        height: root.horizontal ? root.height
                                : Math.max(0, root.height - root.splitPos - root.handleSize / 2)
    }

    /* ══════════════════════ 界线 ══════════════════════ */

    Item {
        id: handle

        x: root.horizontal ? root.splitPos - root.handleSize / 2 : 0
        y: root.horizontal ? 0 : root.splitPos - root.handleSize / 2
        width:  root.horizontal ? root.handleSize : root.width
        height: root.horizontal ? root.height : root.handleSize

        activeFocusOnTab: root.resizable

        /* 常态：一条居中的细线。hover / 拖拽 / 聚焦时变粗、变品牌色 ——
         * 与项目里其它"可交互的次级元素"同一套映射。
         *
         * ── 栏杆的"粗细"和"长度"是两件事，必须分开写 ──────────────────
         * 原先横向分支的 height 也写成 1，于是这条"栏杆"退化成一个
         * **1×1 逻辑像素的点**。属性侧一条都测不出来 —— splitPos 的夹取、
         * 键盘微调、minSize 全部是绿的 —— 而屏幕上什么也看不见；
         * 鼠标虽然还能在 8px 的 MouseArea 上拖，但用户看不见自己抓的是
         * 什么。这是 M18 抓图上抓到的第二个「属性全绿、界面全错」。
         *
         * 长度取 `parent` 的对应边：handle 这个 Item 本身就是贯穿的那条
         * 窄带（横向时它的 height 已经等于 root.height）。 */
        Rectangle {
            anchors.centerIn: parent
            width:  root.horizontal ? (d.emphasized() ? 3 : 1)
                                    : (root.handleAlwaysVisible ? parent.width : 0)
            height: root.horizontal ? (root.handleAlwaysVisible ? parent.height : 0)
                                    : (d.emphasized() ? 3 : 1)
            radius: 1
            color: d.emphasized() ? Theme.color.brand : Theme.color.divider

            Behavior on width  { NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing } }
            Behavior on height { NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing } }
            Behavior on color  { ColorAnimation  { duration: Theme.motion.fast; easing.type: Theme.motion.easing } }
        }

        MouseArea {
            id: handleMa

            anchors.fill: parent
            enabled: root.resizable
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: root.horizontal ? Qt.SplitHCursor : Qt.SplitVCursor

            /* 按下点与分界线之间的偏移。拖动过程中每次都用**绝对坐标**
             * 重算，所以 handle 自己移到哪儿都不影响 —— 见文件头。 */
            property real grabOffset: 0

            onEntered:  root.handleHovered = true
            onExited:   root.handleHovered = false
            onCanceled: root.handlePressed = false

            onPressed: function(mouse) {
                handleMa.grabOffset = root.splitPos
                                      - handleMa.mapToItem(root, mouse.x, mouse.y).x
                root.handlePressed = true
                handle.forceActiveFocus()
            }

            onReleased: function(mouse) {
                if (root.handlePressed) {
                    root.handlePressed = false
                    root.resized()
                }
            }

            onPositionChanged: function(mouse) {
                if (!root.handlePressed) return
                var p = handleMa.mapToItem(root, mouse.x, mouse.y)
                var along = root.horizontal ? p.x : p.y
                if (root._total > 0)
                    root.ratio = (along + handleMa.grabOffset) / root._total
            }

            onDoubleClicked: {
                root.ratio = root.resetRatio
                root.resized()
            }
        }

        Keys.onLeftPressed:  if (root.horizontal) root._nudge(-1)
        Keys.onRightPressed: if (root.horizontal) root._nudge(1)
        Keys.onUpPressed:    if (!root.horizontal) root._nudge(-1)
        Keys.onDownPressed:  if (!root.horizontal) root._nudge(1)
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Home) {
                root.ratio = 0; root.resized(); event.accepted = true
            } else if (event.key === Qt.Key_End) {
                root.ratio = 1; root.resized(); event.accepted = true
            }
        }

        FocusRing { control: handle; radiusOverride: Theme.radius.sm }
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    function _nudge(dir) {
        root.ratio = root.ratio + dir * root.keyboardStep
        root.resized()
    }

    QtObject {
        id: d

        function emphasized() {
            return root.handleHovered || root.handlePressed
                   || (root.resizable && handle.activeFocus)
        }
    }
}
