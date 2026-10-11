/****************************************************************************
 * QSkin · Quick Design System — Theme / Ant Design / slots / ADSpinRing
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Ant Design 的环形加载指示器。
 *
 * ── 它与另外两家的差别：**四段弧** ─────────────────────────────────────
 * Ant 的 loading 记号是四段彼此分开的弧（官方 LoadingOutlined），
 * 整组一起旋转。这一点很关键 —— 它和"一段长弧在转"是**两种读法**：
 *
 *     一段长弧 → 读成"进度在走"（像进度环）
 *     四段短弧 → 读成"系统在忙"（像齿轮在咬合）
 *
 * 这正是"形态属于主题"最直接的证据：同一句"正在加载"，
 * 两家的记法不一样，而这个差别**没法用令牌表达**。
 *
 * ── 四段为什么写成四个 ShapePath ────────────────────────────────────────
 * 一个 ShapePath 里连着写四个 PathAngleArc 是否会自动分隔成子路径，
 * 取决于 PathAngleArc 内部是否插入 moveTo —— 这一点官方文档没有明说，
 * 而"四段被连成一条锯齿"是那种**只在渲染后才看得见**的错法。
 * 四段各写一条 ShapePath，代价是四份属性、收益是确定的几何。
 *
 * ── 关于数值的可核验性（诚实说明）──────────────────────────────────────
 * 段数（4）、段间距（20°）、线宽比例（10%）取的是与 Ant 视觉语言
 * 一致的值，**没有逐点核对官方 SVG**。可复核项：@ant-design/icons 的
 * LoadingOutlined 路径数据。
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
        Math.max(2, Math.round(root.px * 0.10))

    readonly property color tint:
        root.control && root.control.color !== undefined ? root.control.color : Theme.color.brand

    readonly property int period:
        root.control && root.control.period > 0 ? root.control.period : 960

    readonly property bool running:
        root.control === null || root.control === undefined
        || root.control.spinning === undefined || root.control.spinning === true

    /** 每段扫过的角度：360 / 4 − 间隙 20 = 70 */
    readonly property real segSweep: 70

    /** 段与段之间的起始角差：360 / 4 = 90 */
    readonly property real segStep: 90

    readonly property real arcRadius: (Math.min(root.px, root.px) - root.sw) / 2

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

        /* 四段。startAngle 从 -90（12 点）起，每段错开 90°。
         * 这里刻意不合并成循环 —— ShapePath 不是 Item，
         * Repeater 造不出来（它只认 Item）。 */

        ShapePath {
            strokeWidth: root.sw; strokeColor: root.tint
            fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: root.arcRadius; radiusY: root.arcRadius
                startAngle: -90; sweepAngle: root.segSweep
            }
        }

        ShapePath {
            strokeWidth: root.sw; strokeColor: root.tint
            fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: root.arcRadius; radiusY: root.arcRadius
                startAngle: -90 + root.segStep; sweepAngle: root.segSweep
            }
        }

        ShapePath {
            strokeWidth: root.sw; strokeColor: root.tint
            fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: root.arcRadius; radiusY: root.arcRadius
                startAngle: -90 + root.segStep * 2; sweepAngle: root.segSweep
            }
        }

        ShapePath {
            strokeWidth: root.sw; strokeColor: root.tint
            fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: root.arcRadius; radiusY: root.arcRadius
                startAngle: -90 + root.segStep * 3; sweepAngle: root.segSweep
            }
        }
    }
}
