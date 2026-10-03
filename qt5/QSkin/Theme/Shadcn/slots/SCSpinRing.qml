/****************************************************************************
 * QSkin · Quick Design System — Theme / shadcn / slots / SCSpinRing
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * shadcn 的环形加载指示器。
 *
 * ── 它与 TDesign / Ant 的差别：**两段弧，对角放置** ────────────────────
 * shadcn 的加载记号来自 lucide 的 loader 系列，最常用的是
 * **两段、对角、等长**的那种（`loader-2` 的形）。
 *
 * 三家的环，三种读法：
 *     TDesign   一段 300°    "快合上了"
 *     Ant       四段 70°     "齿轮在咬"
 *     shadcn    两段 120°    "拧"（两个对角块互相追）
 *
 * ── 线宽是**固定 2px**，不按直径缩放 ───────────────────────────────────
 * 这是 shadcn（更准确地说是 lucide）的图标语言：它是一套 24×24 的
 * 描边图标，`stroke-width: 2` 是**绝对宽度**，图标放大时线不会变粗
 * （`vector-effect="non-scaling-stroke"` 的观感）。
 * Ant 与 TDesign 相反，它们的线宽跟着尺寸走。
 * 这个差别正好落在 strokeWidth 这一个属性上 —— 主题各写各的，控件不管。
 *
 * ── 关于数值的可核验性（诚实说明）──────────────────────────────────────
 * 段数（2）、弧长（120°）、线宽（2）取的是与 lucide loader 一致的
 * 视觉参数，**没有逐点核对官方 SVG**。可复核项：lucide 的
 * loader-2 / loader-circle 路径数据。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Shapes 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    readonly property real px:
        root.control && root.control.indicatorSize > 0 ? root.control.indicatorSize : 24

    /** 固定 2px —— 见文件头"线宽是固定 2px"。 */
    readonly property real sw: 2

    readonly property color tint:
        root.control && root.control.color !== undefined ? root.control.color : Theme.color.brand

    readonly property int period:
        root.control && root.control.period > 0 ? root.control.period : 960

    readonly property bool running:
        root.control === null || root.control === undefined
        || root.control.spinning === undefined || root.control.spinning === true

    readonly property real arcRadius: (Math.min(root.px, root.px) - root.sw) / 2

    /* ── 形态参数 ──
     * 提成只读属性而不是写在 ShapePath 里的字面量，理由见
     * TDSpinRing 里同一段注释（主题身份要可读；否则冒烟测试只能
     * 证明"换了对象"，证明不了"换对了"）。 */
    readonly property int  segCount:  2     /* 两段 */
    readonly property real segSweep:  120   /* 每段 120° */
    readonly property real segStart1: -90   /* 第一段起点 */
    readonly property real segStart2:  90   /* 第二段 —— 与第一段对角 */

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
            strokeWidth: root.sw; strokeColor: root.tint
            fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: root.arcRadius; radiusY: root.arcRadius
                startAngle: root.segStart1; sweepAngle: root.segSweep
            }
        }

        ShapePath {
            strokeWidth: root.sw; strokeColor: root.tint
            fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: root.arcRadius; radiusY: root.arcRadius
                startAngle: root.segStart2; sweepAngle: root.segSweep
            }
        }
    }
}
