/****************************************************************************
 * QSkin · Quick Design System — Theme / ArcoDesign / slots / ACChevronIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Arco Design 的方向箭头。契约见 BasicChevronIndicator.qml 文件头。
 *
 * 与 Basic 的差异：Arco 的图标线最粗（边长 22%）、端点收圆、尺寸偏大，
 * 折线角度也更张开（0.22 / 0.78）—— 官方 IconDown 那类图标的笔画
 * 明显比 Ant 压得重，是 Arco 视觉里比较好认的一处。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Shapes
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

    implicitWidth:  13
    implicitHeight: implicitWidth
    width:  implicitWidth
    height: implicitHeight

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
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
            strokeWidth: root.width * 0.22
            strokeColor: root.enabled ? Theme.color.fgSecondary : Theme.color.fgDisabled
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap
            joinStyle:   ShapePath.RoundJoin

            startX: root.width  * 0.24;  startY: root.height * 0.22
            PathLine { x: root.width  * 0.72;  y: root.height * 0.50 }
            PathLine { x: root.width  * 0.24;  y: root.height * 0.78 }
        }
    }

    property bool animate: false
    Component.onCompleted: root.animate = true
}
