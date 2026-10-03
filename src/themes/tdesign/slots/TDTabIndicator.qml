/****************************************************************************
 * QSkin · Theme / TDesign / slots / TDTabIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * TDesign 的 Tabs 激活下划线：3px 圆角条（对齐官方 --td-comp 分隔 +
 * indicator 视觉），品牌色。契约见 BasicTabIndicator.qml 文件头。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Rectangle {
    id: root

    property var control: null

    readonly property bool active: control !== null && control.active === true

    height: 3
    radius: 1.5
    color:  Theme.color.brand

    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing } }
    opacity: root.active ? 1 : 0
}
