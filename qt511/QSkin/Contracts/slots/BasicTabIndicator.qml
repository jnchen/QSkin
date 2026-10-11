/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicTabIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「tabIndicator」插槽的 Basic 默认实现 —— Tabs 的激活下划线。
 *
 * M4 契约回收的产物：M3 写 shadcn 时发现各家的 Tabs 下划线差异很大
 * （TDesign 3px 圆角条、Ant/Arco 2px 细线、shadcn 前景色细线），
 * 这属于 indicator 家族的视觉决策，控件里不该硬编码。
 *
 * ── 契约 ──────────────────────────────────────────────────────────────
 *   property var control   宿主 = 单个标签页（QSkinTabs 内的 tab 项）。
 *                          鸭子类型，只要求暴露 `active`（bool）。
 *   尺寸由宿主决定：宿主把插槽铺在标签页底部的一条横带里，
 *   插槽填满它即可。Basic 实现是 2px 品牌色圆角条，inactive 时不显示。
 *
 * 契约第 3 条在这里同样生效：下划线没有交互，插槽里不许放 MouseArea。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Rectangle {
    id: root

    property var control: null

    /* 不写 anchors：宿主负责把插槽摆到标签页底部；本组件只给出
     * height = 2，宽度由宿主（或包着它的 Loader）决定。 */

    readonly property bool active: control !== null && control.active === true

    height: 2
    radius: 1
    color:  Theme.color.brand

    /* 只用 opacity 不用 visible：visible 置 false 会跳过动画，
     * opacity 0 的矩形也不会参与绘制。 */
    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing } }
    opacity: root.active ? 1 : 0
}
