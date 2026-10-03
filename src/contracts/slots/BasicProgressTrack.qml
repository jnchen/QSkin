/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicProgressTrack
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「progressTrack」插槽的 Basic 默认实现 —— 进度条的轨道、已填充区、光环。
 *
 * ── 为什么不复用 sliderTrack ────────────────────────────────────────────
 * 两者结构相近（轨道 + 已填充区），但契约差异足够大，复用会让两边都变脏：
 *   · slider 有手柄，progress 没有；
 *   · slider 只读 position(0~1)，progress 还要读 status（语义色）与
 *     indeterminate（不确定态）；
 *   · slider 是**可交互**的（宿主 MouseArea 改值），progress 是纯展示的。
 * 让一个插槽同时服务两种语义，主题作者写实现时就得先判断"我现在是
 * 给谁画的"——那正是契约层应该消灭的东西。所以单独成槽。
 *
 * ── 契约 ──────────────────────────────────────────────────────────────
 *   property var control   宿主 = QSkinProgress
 *   宿主保证 control 暴露：
 *     clamped（real, 0~1 已钳制）  status（string 语义色）
 *     indeterminate（bool）         variant（"line" | "circle"）
 *     thickness（int）              circleSize（int）
 *   textBelowRing（可选，bool）—— 本插槽向宿主**上报**"环心文字该放哪"，
 *   宿主读它来决定 circle 形态的总高度。这是插槽反向影响宿主布局的
 *   唯一通道，与浮层的 extender 上报同一族做法。
 *
 * 尺寸：line 形态下插槽填满宿主（宿主给宽度、插槽给高度语义）；
 *       circle 形态下插槽自报 circleSize × circleSize。
 *
 * 契约第 3 条：进度条没有交互，插槽里不许放 MouseArea / Keys。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Shapes
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    /** 向宿主上报：环心文字该放在环下方（true）还是环中央（false）。
     *  默认放下方 —— 环中央的空间要留给 100% 那种三位数。 */
    readonly property bool textBelowRing: true

    /* ── 宿主状态读取（鸭子类型，读不到就给安全默认值） ── */

    function val()      { return root.control && root.control.clamped !== undefined
                               ? root.control.clamped : 0 }
    function indet()    { return root.control ? root.control.indeterminate === true : false }
    function isCircle() { return root.control ? root.control.variant === "circle" : false }
    function thick()    { return root.control && root.control.thickness > 0
                               ? root.control.thickness : 8 }
    function circleD()  { return root.control && root.control.circleSize > 0
                               ? root.control.circleSize : 96 }

    /** 语义色 —— 这就是 progress 需要独立插槽的核心理由 */
    function barColor() {
        var s = root.control ? root.control.status : "default"
        switch (s) {
        case "success": return Theme.color.success
        case "warning": return Theme.color.warning
        case "danger":  return Theme.color.danger
        default:        return Theme.color.brand
        }
    }

    implicitWidth:  isCircle() ? circleD() : 200
    implicitHeight: isCircle() ? circleD() : thick()

    /* ══════════════════════ line 形态 ══════════════════════ */

    Rectangle {
        id: lineTrack

        anchors.fill: parent
        visible: !root.isCircle()
        radius: height / 2
        color: Theme.color.bgSunken
    }

    Rectangle {
        id: lineFill

        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom

        visible: !root.isCircle()

        /* 不确定态：一个短滑块来回跑，模拟"还在进行但不知道多久" */
        width: root.indet() ? Math.max(root.thick() * 2, parent.width * 0.3)
                            : Math.max(0, Math.min(parent.width, root.val() * parent.width))
        radius: height / 2
        color:  root.barColor()

        Behavior on color {
            ColorAnimation { duration: Theme.motion.normal; easing.type: Theme.motion.easing }
        }

        /* 确定态下宽度也走动画（值变化时平滑推进，而不是跳变）。
         * 不确定态下由下面的动画直接驱动 x，宽度动画要关掉，
         * 否则两个动画会互相拉扯出抖动。 */
        Behavior on width {
            enabled: !root.indet()
            NumberAnimation { duration: Theme.motion.normal; easing.type: Theme.motion.easing }
        }

        SequentialAnimation on x {
            running: root.indet() && lineTrack.visible
            loops:   Animation.Infinite
            NumberAnimation {
                from: 0
                to: Math.max(0, lineTrack.width - lineFill.width)
                duration: 900
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                from: Math.max(0, lineTrack.width - lineFill.width)
                to: 0
                duration: 900
                easing.type: Easing.InOutQuad
            }
        }
    }

    /* ══════════════════════ circle 形态 ══════════════════════
     *
     * 用 Shape + 两个 ShapePath 画两段弧：
     *   · 底环：整圈，bgSunken
     *   · 进度环：从 12 点方向顺时针，value 决定扫过角度
     *
     * 为什么不用 Canvas：Canvas 不参与 QML 的绑定依赖图，值变了要手动
     * requestPaint()（QSkinInputNumber 的步进器踩过这个坑）。Shape 是
     * 声明式的，尺寸/颜色/角度都能直接绑，改值自动重绘。
     * 为什么不用 ConicalGradient：它画不出"圆头端点"（round cap），
     * 而三大设计系统的进度环都是圆头的。 */

    Shape {
        // CurveRenderer 才有原生抗锯齿；默认的 GeometryRenderer 是硬边（见 README「图标锯齿」）
        preferredRendererType: Shape.CurveRenderer
        id: ring

        visible: root.isCircle()

        width:  root.circleD()
        height: root.circleD()
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        /* 底环 */
        ShapePath {
            strokeWidth: root.thick()
            strokeColor: Theme.color.bgSunken
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: (Math.min(ring.width, ring.height) - root.thick()) / 2
                radiusY: (Math.min(ring.width, ring.height) - root.thick()) / 2
                startAngle: -90
                sweepAngle: 360
            }
        }

        /* 进度环 */
        ShapePath {
            strokeWidth: root.thick()
            strokeColor: root.barColor()
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: (Math.min(ring.width, ring.height) - root.thick()) / 2
                radiusY: (Math.min(ring.width, ring.height) - root.thick()) / 2
                startAngle: -90
                sweepAngle: root.indet() ? 90 : 360 * root.val()
            }

            /* sweepAngle 在 ShapePath 里不是可动画的属性（它由
             * PathAngleArc 驱动），所以确定态下的平滑推进靠宿主
             * 侧做插值 —— 见 QSkinProgress 的 valueAnim。 */
            Behavior on strokeColor {
                ColorAnimation { duration: Theme.motion.normal; easing.type: Theme.motion.easing }
            }
        }

        /* 不确定态：整圈匀速旋转 */
        RotationAnimator on rotation {
            running: root.indet() && ring.visible
            from: 0; to: 360
            duration: 1100
            loops: Animation.Infinite
        }
    }
}
