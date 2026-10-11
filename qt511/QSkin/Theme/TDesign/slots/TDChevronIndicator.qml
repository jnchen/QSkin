/****************************************************************************
 * QSkin · Quick Design System — Theme / TDesign / slots / TDChevronIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * TDesign 的方向箭头。契约见 BasicChevronIndicator.qml 文件头。
 *
 * 与 Basic 的差异：TDesign 的图标线整体偏硬 —— 线更粗（边长 18%）、
 * 端点不收圆（FlatCap），折角也更利。尺寸略小。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Shapes 1.11
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

    implicitWidth:  12
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
            strokeWidth: root.width * 0.18
            strokeColor: root.enabled ? Theme.color.fgSecondary : Theme.color.fgDisabled
            fillColor:   "transparent"
            capStyle:    ShapePath.FlatCap
            joinStyle:   ShapePath.MiterJoin

            startX: root.width  * 0.30;  startY: root.height * 0.16
            PathLine { x: root.width  * 0.70;  y: root.height * 0.50 }
            PathLine { x: root.width  * 0.30;  y: root.height * 0.84 }
        }
    }

    property bool animate: false
    Component.onCompleted: root.animate = true
}
