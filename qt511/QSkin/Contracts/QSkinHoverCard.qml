/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinHoverCard
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 悬停卡片 —— 鼠标停上去一会儿才出现、并且**可以移进去**的富内容浮层。
 *
 * ── 与 QSkinTooltip 的分界 ────────────────────────────────────────────────
 * 两者都是"悬停触发"，但有一处本质区别：
 *
 *     Tooltip    一移开 target 就消失，指针进不去 —— 它只是一句话
 *     HoverCard  指针要能移进卡片里（卡片里有链接、按钮、头像）
 *
 * 后者要求"指针在卡片上"也必须算作"还在悬停中"，否则指针一离开 target
 * 卡片就没了，永远够不着里面的东西。这就是 QSkinPopover 那只
 * HoverHandler（panelHovered）存在的理由。
 *
 * ── 两个 delay 都是必须的 ───────────────────────────────────────────────
 * showDelay  鼠标只是路过时不该弹东西出来（默认 400ms）
 * hideDelay  从 target 挪到卡片的路上会有一小段"两边都不在"的间隙，
 *            立即关会让卡片在指针到达前消失。给一个缓冲（默认 120ms）
 *            让指针有机会落到卡片上。
 *
 * ── 为什么它不参与"同刻只有一个浮层" ────────────────────────────────────
 * exclusive: false。悬停提示不该顶掉用户刚点开的下拉框，反过来，
 * 打开下拉框也不该把鼠标底下那张卡片吃掉 —— 两者在交互上不冲突。
 * 详见 foundation/OverlayStack.qml 文件头。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

QSkinPopover {
    id: root

    property int showDelay: 400
    property int hideDelay: 120

    /* 悬停类浮层：不进排他栈。 */
    exclusive: false

    /* 它不是"点开"的，所以点别处不该关 —— 收不收只由指针位置决定。 */
    dismissOnPressOutside: false

    accessibleRole: Accessible.ToolTip
    accessibleName: root.title

    /** "还该不该开着"：指针在 target 上，或者已经移进卡片里 */
    readonly property bool hoverActive: {
        var t = root.target
        return (t !== null && t !== undefined && t.hovered === true)
               || root.panelHovered
    }

    onHoverActiveChanged: root._schedule()

    function _schedule() {
        if (root.hoverActive) {
            hideTimer.stop()
            if (!root.opened) showTimer.restart()
        } else {
            showTimer.stop()
            hideTimer.restart()
        }
    }

    /* 覆盖基座的策略函数、落到它的原语上（QML 没有 super，
     * 见 QSkinPopover 里 showOverlay / hideOverlay 处的说明）。
     * 手动开关时把两个计时器一并掐掉，免得刚开就被 hideTimer 收走。 */
    function open()  { showTimer.stop(); hideTimer.stop(); root.showOverlay()  }
    function close() { showTimer.stop(); hideTimer.stop(); root.hideOverlay()  }

    Timer {
        id: showTimer
        interval: root.showDelay
        onTriggered: root.showOverlay()
    }

    Timer {
        id: hideTimer
        interval: root.hideDelay
        onTriggered: root.hideOverlay()
    }

    Component.onCompleted: root._schedule()
}
