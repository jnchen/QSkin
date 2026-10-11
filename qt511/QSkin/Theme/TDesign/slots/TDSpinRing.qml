/****************************************************************************
 * QSkin · Quick Design System — Theme / TDesign / slots / TDSpinRing
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * TDesign 的环形加载指示器。
 *
 * ── 它与 Basic 的差别（这就是它值得单独写一份的理由）────────────────────
 *   · 缺口更小：扫过 300°（Basic 270°）。TDesign 的 loading 看起来
 *     是一条"几乎闭合的圆"，缺口只是用来指示方向。
 *   · 线宽按直径的 **9%**（Basic 是 10%）。差值很小，但它在小尺寸下
 *     看得见：16px 的加载圈上 1px 的差别就是"细"和"糊"的区别。
 *   · 端点是圆头（与 Basic 同）。
 *
 * ── 关于数值的可核验性（诚实说明）──────────────────────────────────────
 * 这里的弧长、线宽比例、转速取的是"与 TDesign 视觉语言一致"的值，
 * **没有逐点核对官方 SVG 的路径数据**。把它们集中在这一个文件里，
 * 正是为了让"要改成官方值"这件事只改一处 —— 这也是这个插槽存在的
 * 意义：形态参数属于主题，不属于控件。
 *
 * 可复核项：TDesign 官方 loading 图标的 SVG（tdesign-icons 仓库）。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Shapes 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    readonly property real px:
        root.control && root.control.indicatorSize > 0 ? root.control.indicatorSize : 24

    readonly property real sw:
        Math.max(2, Math.round(root.px * 0.09))

    readonly property color tint:
        root.control && root.control.color !== undefined ? root.control.color : Theme.color.brand

    readonly property int period:
        root.control && root.control.period > 0 ? root.control.period : 960

    readonly property bool running:
        root.control === null || root.control === undefined
        || root.control.spinning === undefined || root.control.spinning === true

    /* ── 形态参数 ──
     * 提成只读属性而不是写在 ShapePath 里的字面量，有两个理由：
     *   ① "这家扫多少度"是**主题的身份**，应当能被外部读到；
     *   ② 只有可读，冒烟测试才能区分"装上的确实是这一家"和"装上了
     *      但其实是 Basic"—— 后者是 M19 实测踩过的坑（键名写错，
     *      插槽没装上，控件照样画出一圈弧，因为 Basic 那一圈也在）。
     *      光靠"引用不等于 Basic"只能证明换了对象，证明不了换对了。 */
    readonly property real startAngle: -90
    readonly property real sweepAngle: 300

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
        }
    }
}
