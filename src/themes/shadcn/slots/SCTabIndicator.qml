/****************************************************************************
 * QSkin · Theme / shadcn / slots / SCTabIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * shadcn/ui 的 Tabs 激活下划线：2px 全宽，前景色（近黑）。
 * 没有品牌色的设计系统里，激活态用最强前景表达 —— 与它的
 * primary 按钮是同一个答案。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Rectangle {
    id: root

    property var control: null

    readonly property bool active: control !== null && control.active === true

    height: 2
    radius: 0
    color:  Theme.color.fg

    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing } }
    opacity: root.active ? 1 : 0
}
