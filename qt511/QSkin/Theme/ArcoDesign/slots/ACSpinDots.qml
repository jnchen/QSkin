/****************************************************************************
 * QSkin · Quick Design System — Theme / Arco Design / slots / ACSpinDots
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Arco Design 的点阵加载指示器。
 *
 * ── 为什么 Arco 是四家里唯一覆盖 `spinDots` 的 ──────────────────────────
 * 四家都有"一个环在转"，但**只有 Arco 把点阵当作一等形态**
 * （官方 Spin 的 `dot: true`）。TDesign 与 Ant 的点只是环形的一个变体，
 * shadcn 的图标库里没有"点阵加载"这一项。
 *
 * 于是这一格恰好演示了契约层的常态：**主题只覆盖它真正要改的那一格，
 * 其余保留 Basic**。Arco 覆盖 spinDots、不覆盖 spinRing；
 * 另外三家反过来。四家合计覆盖 4 格中的 4 格，没有一格是空的。
 *
 * ── 它与 Basic 的点阵差别：**整组在转** ─────────────────────────────────
 * Basic 是三个点原地明暗（"亮点绕着圈跑"），点是静止的。
 * Arco 是四个点**整体旋转**，同时每个点自己明暗。
 * 两个动作叠在一起才读成"拧螺丝"，只有明暗会读成"心跳"。
 *
 * ── 关于数值的可核验性（诚实说明）──────────────────────────────────────
 * 点的个数（4）、点径比例（1.7×）、转速与 Basic 同源（period）。
 * **没有逐点核对官方 SVG** —— Arco 的 dot spinner 是 CSS 动画，
 * 官方没有可对比的静态路径。可复核项：@arco-design/web-vue 的
 * spin 组件样式表。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    readonly property real px:
        root.control && root.control.indicatorSize > 0 ? root.control.indicatorSize : 24

    readonly property real base:
        root.control && root.control.strokeWidth > 0 ? root.control.strokeWidth
                                                     : Math.max(2, Math.round(root.px / 10))

    readonly property color tint:
        root.control && root.control.color !== undefined ? root.control.color : Theme.color.brand

    readonly property int period:
        root.control && root.control.period > 0 ? root.control.period : 960

    readonly property bool running:
        root.control === null || root.control === undefined
        || root.control.spinning === undefined || root.control.spinning === true

    readonly property real dotSize: root.base * 1.7
    readonly property real orbit:   (root.px - root.dotSize) / 2
    readonly property int dotCount: 4

    implicitWidth:  root.px
    implicitHeight: root.px
    width:  implicitWidth
    height: implicitHeight

    /* 整组旋转。用 RotationAnimator（渲染线程驱动的动画器）而不是
     * RotationAnimation —— 骨架屏与加载圈常常一屏好几个，
     * 动画器不占主线程的绑定求值。 */
    Item {
        id: group

        anchors.fill: parent

        RotationAnimator on rotation {
            running: root.running
            from: 0
            to: 360
            duration: root.period
            loops: Animation.Infinite
        }

        /* Repeater 的 inline delegate 里对文件级 id `root` 的每一次读取
         * 都会被报成 Unqualified access（共 11 条），因为静态检查推断不出
         * delegate 处于本文件作用域。运行时解析正常。只在 delegate 这一层
         * 关掉该检查，不做全局降级，以免掩盖真问题。 */
        // qmllint disable unqualified
        Repeater {
            model: root.dotCount

            delegate: Rectangle {
                id: dot

                property int index

                width:  root.dotSize
                height: root.dotSize
                radius: root.dotSize / 2
                color:  root.tint

                readonly property real angle:
                    (index * 2 * Math.PI / root.dotCount) - Math.PI / 2

                x: root.px / 2 + Math.cos(dot.angle) * root.orbit - root.dotSize / 2
                y: root.px / 2 + Math.sin(dot.angle) * root.orbit - root.dotSize / 2

                /* 明暗错相：四个点各差 1/4 周期。
                 * 与整组旋转的周期**取同一个值**，于是"转到下一个点的位置"
                 * 和"下一个点亮起来"是同一拍 —— 两个动作合起来才是咬合感；
                 * 两个周期取不同值会变成各转各的，看着散。 */
                SequentialAnimation on opacity {
                    running: root.running
                    loops: Animation.Infinite

                    PauseAnimation { duration: dot.index * (root.period / root.dotCount) }
                    NumberAnimation {
                        from: 0.3; to: 1.0
                        duration: root.period / root.dotCount
                        easing.type: Easing.OutSine
                    }
                    NumberAnimation {
                        from: 1.0; to: 0.3
                        duration: root.period * 3 / root.dotCount
                        easing.type: Easing.InSine
                    }
                }
            }
        }
        // qmllint enable unqualified
    }
}
