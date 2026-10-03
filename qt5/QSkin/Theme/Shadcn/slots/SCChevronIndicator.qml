/****************************************************************************
 * QSkin · Quick Design System — Theme / Shadcn / slots / SCChevronIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * shadcn 的方向箭头。契约见 BasicChevronIndicator.qml 文件头。
 *
 * 与 Basic 的差异：shadcn 的图标来自 lucide，特征是**统一 2px 线宽、
 * 24 视框、圆端点圆折角** —— 也就是说线宽不随图标尺寸缩放，图标
 * 本身反而画得比较大（14）。这是 lucide 与前三家最不一样的一点：
 * 前三家的图标是"等比缩放的小图形"，lucide 是"固定笔画的字"。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Shapes 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    readonly property string direction: {
        if (root.control === null || root.control === undefined) return "down"
        if (root.control.direction === undefined) return "down"
        return String(root.control.direction)
    }

    readonly property bool enabled: root.control === null
                                    || root.control.enabled === undefined
                                    || root.control.enabled !== false

    readonly property int angle: root.direction === "right" ? 0
                               : root.direction === "down"  ? 90
                               : root.direction === "left"  ? 180
                                                            : 270

    implicitWidth:  14
    implicitHeight: implicitWidth
    width:  implicitWidth
    height: implicitHeight

    Shape {
        anchors.fill: parent
        rotation: root.angle
        transformOrigin: Item.Center

        Behavior on rotation {
            enabled: root.animate
            NumberAnimation {
                duration: Theme.motion.fast
                easing.type: Theme.motion.easing
            }
        }

        ShapePath {
            /* lucide 的 2px 线宽对应 24 视框 —— 这里 14 的盒子里
             * 保持同样的线宽，不做等比缩放。 */
            strokeWidth: 2
            strokeColor: root.enabled ? Theme.color.fgSecondary : Theme.color.fgDisabled
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap
            joinStyle:   ShapePath.RoundJoin

            startX: root.width  * 0.26;  startY: root.height * 0.16
            PathLine { x: root.width  * 0.70;  y: root.height * 0.50 }
            PathLine { x: root.width  * 0.26;  y: root.height * 0.84 }
        }
    }

    property bool animate: false
    Component.onCompleted: root.animate = true
}
