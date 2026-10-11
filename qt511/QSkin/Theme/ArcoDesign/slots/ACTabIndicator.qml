/****************************************************************************
 * QSkin · Theme / Arco Design / slots / ACTabIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Arco Design 的 Tabs 激活下划线：2px 细线，arcoblue-6。
 * 与 Ant 同规格但取色走 Arco 自己的令牌 —— 这正是令牌层的意义。
 ****************************************************************************/

import QtQuick 2.11
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
