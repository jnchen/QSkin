/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicSpinRing
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「spinRing」插槽的 Basic 默认实现 —— 环形加载指示器。
 *
 * ── 契约 ──────────────────────────────────────────────────────────────
 *   property var control   宿主 = QSkinSpin。鸭子类型，要求暴露：
 *     · indicatorSize  int     指示器边长（像素）
 *     · strokeWidth    int     建议描边宽度
 *     · color          color   指示器颜色
 *     · period         int     转一圈的毫秒数
 *     · spinning       bool    是否在转（**必须用它来起停动画**，
 *                              否则一次"暂停"会让画面还在转）
 *
 *   尺寸：插槽填满宿主给的 indicatorSize × indicatorSize 方框。
 *   宿主保证方框是正方形 —— 环形的"自然尺寸"就是它的外接方框。
 *
 * ── 通用修法：`Theme` 的读取一律走 root.xxx ────────────────────────────
 * 插槽是**主题替换点**，所以这里不写任何具体的几何数字，
 * 只写"通用环形的画法"：起始角从 12 点方向、顺时针扫 sweepAngle。
 * 四家主题各自覆盖 sweepAngle / 端点 / 线宽比例 —— 差异全在那儿。
 *
 * 契约第 3 条：指示器没有交互，插槽里不许放 MouseArea / Keys。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Shapes 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    /* ── 宿主状态读取（鸭子类型，读不到就给安全默认值） ── */

    readonly property real px:
        root.control && root.control.indicatorSize > 0 ? root.control.indicatorSize : 24

    readonly property real sw:
        root.control && root.control.strokeWidth > 0 ? root.control.strokeWidth
                                                     : Math.max(2, Math.round(root.px / 10))

    readonly property color tint:
        root.control && root.control.color !== undefined ? root.control.color : Theme.color.brand

    readonly property int period:
        root.control && root.control.period > 0 ? root.control.period : 960

    readonly property bool running:
        root.control === null || root.control === undefined
        || root.control.spinning === undefined || root.control.spinning === true

    /** 扫过的角度。Basic 取 270°（缺四分之一），是最"没有立场"的环形 ——
     *  四家主题各自的取值见 slots/ 下它们的实现。 */
    readonly property real sweepAngle: 270

    /** 起始角。-90 是 12 点方向（Qt 的角度以 3 点方向为 0、顺时针为正）。 */
    readonly property real startAngle: -90

    implicitWidth:  root.px
    implicitHeight: root.px
    width:  implicitWidth
    height: implicitHeight

    Shape {
        id: ring

        anchors.fill: parent

        RotationAnimator on rotation {
            running: root.running
            from: 0
            to: 360
            duration: root.period
            loops: Animation.Infinite
        }

        ShapePath {
            strokeWidth: root.sw
            strokeColor: root.tint
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: (Math.min(ring.width, ring.height) - root.sw) / 2
                radiusY: radiusX
                startAngle: root.startAngle
                sweepAngle: root.sweepAngle
            }

            Behavior on strokeColor {
                ColorAnimation { duration: Theme.motion.normal; easing.type: Theme.motion.easing }
            }
        }
    }
}
