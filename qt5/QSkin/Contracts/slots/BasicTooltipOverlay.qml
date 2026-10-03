/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicTooltipOverlay
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「tooltipOverlay」插槽的 Basic 默认实现 —— 气泡本体。
 *
 * ── 为什么这里不复用 label 插槽 ────────────────────────────────────────
 * Tooltip 的文字排版跟正文不是一回事：更小（12px）、要折行、颜色跟随气泡
 * 而不是跟随文字层级。强行套 Slots.label 只会让主题作者被迫覆盖一堆
 * 本不该出现在 tooltip 上的属性。插槽该按"视觉职责"划分，不是按"都是文字"。
 *
 * ── 配色：取反 ────────────────────────────────────────────────────────
 * 气泡底色用 Theme.color.fg、文字用 Theme.color.bg。
 * 这样浅色模式下是"深底浅字"、深色模式下自动变成"浅底深字"，
 * 不需要新增任何 tooltip 专用令牌，也不需要在明暗切换时特殊处理。
 *
 * ── 契约 ──────────────────────────────────────────────────────────────
 *   property var control   宿主（QSkinTooltip），这里只读 control.text
 *   implicitWidth/Height   气泡建议尺寸（不含阴影）
 *   extender               阴影外扩量（M4 契约回收，与 selectOverlay 同一
 *                          条款）。Basic 无阴影，为 0。
 *   不含 content：气泡里只有一段文字，没有需要宿主注入的内容。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    property int padding: Theme.space.sm
    property int maxWidth: 260

    /** 阴影外扩量（M4 契约回收）。Basic 无阴影，恒为 0。 */
    readonly property real extender: 0

    implicitWidth:  Math.min(bubble.implicitWidth  + root.padding * 2, root.maxWidth)
    implicitHeight: bubble.implicitHeight + root.padding * 2

    Rectangle {
        id: panel

        anchors.fill: parent
        radius:       Theme.radius.sm
        color:        Theme.color.fg
        border.width: 1
        border.color: Theme.color.border
        opacity:      0.96
    }

    Text {
        id: bubble

        anchors.centerIn: parent
        width: Math.min(root.implicitWidth - root.padding * 2, root.maxWidth - root.padding * 2)

        text: root.control && root.control.text !== undefined ? root.control.text : ""

        font.family:    Theme.font.family
        font.pixelSize: Theme.font.xs
        color:          Theme.color.bg

        wrapMode:            Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment:   Text.AlignVCenter
        renderType:          Text.NativeRendering
    }
}
