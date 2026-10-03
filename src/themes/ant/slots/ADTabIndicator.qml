/****************************************************************************
 * QSkin · Theme / Ant Design / slots / ADTabIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Ant Design 的 Tabs 激活下划线：2px 细线，colorPrimary。
 * （官方 ants 的线是通栏贴底、不带圆角，这里照做。）
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Rectangle {
    id: root

    property var control: null

    readonly property bool active: control !== null && control.active === true

    height: 2
    radius: 0
    color:  Theme.color.brand

    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing } }
    opacity: root.active ? 1 : 0
}
