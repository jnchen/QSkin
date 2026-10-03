/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicStepIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「stepIndicator」插槽的 Basic 默认实现 —— 步骤条左侧/上方那个圆。
 *
 * ── 契约 ──────────────────────────────────────────────────────────────
 *   property var control   宿主 = 一个步骤项（QSkinSteps 内的 step）
 *   宿主保证暴露：
 *     index（int）       本步下标
 *     status（string）   "finish" | "process" | "wait" | "error"
 *     active（bool）     status === "process"
 *     done（bool）       status === "finish"
 *     first / last（bool）
 *     stepSize（int）    圆直径，默认 24
 *
 * ── 三种状态的画法 ────────────────────────────────────────────────────
 *   finish   实心品牌圆 + 白勾
 *   process  实心品牌圆 + 白色数字（进行中要显眼）
 *   wait     空心圆（描边）+ 弱前景数字
 *   error    实心危险色圆 + 白 ×   —— 失败步骤，业务通过 model 的
 *            status 字段覆盖时出现
 *
 * 勾与 × 都用 Shape 画，不打字符 —— 字体字形覆盖率问题，
 * 与 BasicCheckIndicator 同款理由。
 *
 * 契约第 3 条：步骤圆没有交互（点击由宿主 QSkinSteps 的 MouseArea 接管），
 * 插槽里不许放 MouseArea。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Shapes 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    readonly property int size: (root.control && root.control.stepSize > 0)
                                ? root.control.stepSize : 24

    implicitWidth:  root.size
    implicitHeight: root.size
    width:  implicitWidth
    height: implicitHeight

    /* ── 宿主状态（鸭子类型） ── */

    function st()      { return root.control ? root.control.status : "wait" }
    function isDone()  { return st() === "finish" }
    function isError() { return st() === "error" }
    function isAct()   { return st() === "process" }
    function idx()     { return root.control ? root.control.index : 0 }

    /* ── 圆底 ── */

    Rectangle {
        id: disc

        anchors.fill: parent
        radius: width / 2

        /* 实心：finish / process / error。空心（白底 + 描边）：wait */
        color:        d.discBg()
        border.width: d.discBorderW()
        border.color: d.discBorder()

        Behavior on color {
            ColorAnimation { duration: Theme.motion.normal; easing.type: Theme.motion.easing }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.motion.normal; easing.type: Theme.motion.easing }
        }
    }

    /* ── 进行中的脉冲光环 ── */

    Rectangle {
        id: pulse

        anchors.centerIn: parent
        width:  root.size
        height: root.size
        radius: width / 2
        color:  "transparent"
        border.width: 2
        border.color: Theme.color.brand
        visible: root.isAct()

        SequentialAnimation on opacity {
            running: pulse.visible
            loops:   Animation.Infinite
            NumberAnimation { from: 0.55; to: 0.0; duration: 1400; easing.type: Easing.OutQuad }
            NumberAnimation { from: 0.0;  to: 0.55; duration: 0 }
        }
        SequentialAnimation on scale {
            running: pulse.visible
            loops:   Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.5; duration: 1400; easing.type: Easing.OutQuad }
            NumberAnimation { from: 1.5; to: 1.0; duration: 0 }
        }
    }

    /* ── 勾（finish） ── */

    Shape {
        // CurveRenderer 才有原生抗锯齿；默认的 GeometryRenderer 是硬边（见 README「图标锯齿」）
        anchors.fill: parent
        visible: root.isDone()

        ShapePath {
            strokeWidth: 2
            strokeColor: Theme.color.onBrand
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap
            joinStyle:   ShapePath.RoundJoin

            /* 按 24 的基准画，再随尺寸缩放 */
            startX: root.size * 0.28
            startY: root.size * 0.52
            PathLine { x: root.size * 0.44; y: root.size * 0.68 }
            PathLine { x: root.size * 0.74; y: root.size * 0.34 }
        }
    }

    /* ── ×（error） ── */

    Shape {
        // CurveRenderer 才有原生抗锯齿；默认的 GeometryRenderer 是硬边（见 README「图标锯齿」）
        anchors.fill: parent
        visible: root.isError()

        ShapePath {
            strokeWidth: 2
            strokeColor: Theme.color.onBrand
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            startX: root.size * 0.33
            startY: root.size * 0.33
            PathLine { x: root.size * 0.67; y: root.size * 0.67 }
        }
        ShapePath {
            strokeWidth: 2
            strokeColor: Theme.color.onBrand
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            startX: root.size * 0.67
            startY: root.size * 0.33
            PathLine { x: root.size * 0.33; y: root.size * 0.67 }
        }
    }

    /* ── 数字（process / wait） ──
     * process 用白字（实心底上），wait 用弱前景（白底上）。 */

    Text {
        anchors.centerIn: parent
        visible: !root.isDone() && !root.isError()

        text: String(root.idx() + 1)

        font.family:    Theme.font.family
        font.pixelSize: Theme.font.sm
        font.weight:    root.isAct() ? Theme.font.weightSemiBold
                                     : Theme.font.weightRegular
        color:          root.isAct() ? Theme.color.onBrand : Theme.color.fgMuted
    }

    QtObject {
        id: d

        function discBg() {
            if (root.isDone() || root.isAct()) return Theme.color.brand
            if (root.isError())                return Theme.color.danger
            return Theme.color.bg          /* wait：白底空心 */
        }

        function discBorderW() { return root.st() === "wait" ? 1 : 0 }

        function discBorder()  { return Theme.color.borderStrong }
    }
}
