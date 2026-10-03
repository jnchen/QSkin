/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinTooltip
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 悬浮提示。用法：
 *
 *     QSkinTooltip { text: "保存"; target: saveButton }
 *
 * ── 分工 ─────────────────────────────────────────────────────────────
 *   这个文件：延迟出现、定位与翻转、窗口边界夹取、无障碍播报
 *   插槽负责：Slots.tooltipOverlay —— 气泡的样子
 *
 * ── 为什么 hover 靠读 target.hovered，而不是自己盖一层 MouseArea ────────
 * 盖一层 MouseArea 就得 reparent 到 target 上，而且即使设成
 * acceptedButtons: Qt.NoButton，也可能改变 target 的层级与事件顺序。
 * 所有 QSkin 控件都统一暴露 hovered（这是契约层的状态约定），直接读最省事，
 * 也最不容易出错。代价是：target 必须暴露 hovered —— 非 QSkin 控件请自行适配。
 *
 * ── 关于依赖 QtQuick.Controls ────────────────────────────────────────
 * 浮层用 Controls 的 Popup。自己实现一套（overlay 层级、模态、Esc 关闭、
 * 焦点管理）代码量不小，而这些都是"行为"，放进插槽会违反契约第 3 条。
 * 我们把 background 清空、外观全部交给插槽，Controls 只当浮层引擎用。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    property string text: ""

    /** 触发提示的控件；必须暴露 hovered（所有 QSkin 控件都有）。
     * 声明为 var 而不是 Item：契约是鸭子类型，声明成 Item 会让 qmllint
     * 按 QQuickItem 做成员检查，把 target.hovered 报成 Member not found。
     * 与 Slots.qml 里 `property var control` 是同一个道理。 */
    property var target: null

    /** 悬停多久后出现（毫秒） */
    property int delay: 500

    readonly property bool opened: popup.opened

    /* ══════════════════ hover 侦测 ══════════════════ */

    readonly property bool targetHovered: root.target && root.target.hovered === true

    onTargetHoveredChanged: {
        if (root.targetHovered) {
            showTimer.restart()
        } else {
            showTimer.stop()
            popup.close()
        }
    }

    Timer {
        id: showTimer
        interval: root.delay
        repeat: false
        onTriggered: popup.open()
    }

    /* ══════════════════ 浮层 ══════════════════ */

    /* 沿父链读一遍 x/y —— 唯一目的是**登记依赖**（返回值不用）。
     *
     * ── 为什么不能直接写 `root.target.mapToItem(Overlay.overlay, 0, 0)` ──
     * `mapToItem()` 是方法调用，**不产生属性依赖**。单独写成
     * `readonly property point anchor: …mapToItem(…)` 时，这个绑定只会被
     * 求值一次 —— 而且求值那一刻 QSkinPopover / QSkinTooltip 的**内部属性**正在
     * 实例化，外部那条 `target: 锚点` 还没落下来、目标自己的 `x: …` 也还
     * 没被任何人读过（惰性绑定）。于是锚点停在 (0,0) 并且永不更新，
     * 气泡落到窗口左上角。同一处缺陷在 QSkinPopover 上被 M21 的像素核验
     * 抓了个现行（实录：t=1400ms 时缓存值仍 (0,0)，现算已是 (200,52)），
     * 这里一并修掉。
     *
     * 显式读一遍之后，实测绑定会自发收敛： (0,0) → (0,52) → (200,52)，
     * 且目标或任一祖先挪动时重算。 */
    function _anchorDeps(item) {
        var acc = 0
        var p = item
        while (p !== null && p !== undefined) {
            acc += p.x + p.y
            p = p.parent
        }
        return acc
    }

    /* 目标在 overlay 坐标系里的左上角 —— Popup 的 x/y 就在这个坐标系里 */
    readonly property point anchor: {
        if (!root.target || !Overlay.overlay) return Qt.point(0, 0)
        var _ = root._anchorDeps(root.target)
        return root.target.mapToItem(Overlay.overlay, 0, 0)
    }

    /* 上方放不下就翻到下方 */
    readonly property bool flipDown: root.anchor.y - popup.height - Theme.space.xs < 0

    /* 浮层上报的阴影外扩量（M4 契约回收，与 QSkinSelect 同一条款）。
     * 经 var 中转以绕开 Loader.item 的静态类型误报。 */
    readonly property var  overlayItem: overlayLoader.item
    readonly property real overlayExtender: root.overlayItem !== null
        && root.overlayItem.extender !== undefined ? root.overlayItem.extender : 0

    Popup {
        id: popup

        padding: root.overlayExtender
        background: Item {}

        contentItem: Loader {
            id: overlayLoader

            sourceComponent: Slots.tooltipOverlay

            Binding {
                target: overlayLoader.item
                property: "control"
                value: root
                when: overlayLoader.item !== null
            }
        }

        contentWidth:  overlayLoader.implicitWidth
        contentHeight: overlayLoader.implicitHeight

        /* 水平居中于目标，再做窗口边界夹取 */
        x: {
            var want = root.anchor.x + (root.target ? root.target.width : 0) / 2
                       - popup.width / 2
            var max = Overlay.overlay ? Overlay.overlay.width - popup.width : want
            return Math.max(Theme.space.xs, Math.min(want, max))
        }

        /* y 以「气泡本体」为基准换算：popup 边界比气泡大一圈 extender */
        y: root.flipDown ? root.anchor.y + (root.target ? root.target.height : 0)
                           + Theme.space.xs - root.overlayExtender
                         : root.anchor.y - popup.height - Theme.space.xs
                           + root.overlayExtender

        /* Tooltip 永远不吃焦点，也不该进 Tab 序列 */
        focus: false
        modal: false
        closePolicy: Popup.NoAutoClose
    }
}
