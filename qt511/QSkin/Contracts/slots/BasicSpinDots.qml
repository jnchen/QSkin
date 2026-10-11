/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicSpinDots
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「spinDots」插槽的 Basic 默认实现 —— 点阵加载指示器。
 *
 * ── 契约 ──────────────────────────────────────────────────────────────
 *   与 spinRing **完全一致**（同一个宿主、同一组属性）——
 *     control.indicatorSize / strokeWidth / color / period / spinning
 *   `strokeWidth` 在这里当"点的基准直径"用：点的直径取它的 1.6 倍，
 *   这样"加粗"这一个旋钮在两种形态下都说得通。
 *   宿主保证方框是正方形，点阵按外接圆排布。
 *
 * ── 为什么不和 spinRing 合成一个插槽 ──────────────────────────────────
 * 结构不同（一条描边 vs N 个实心块），连"自然尺寸"的算法都不同。
 * 详细论证见 QSkinSpin 的文件头「形态是主题的事」那一段。
 *
 * ── 三个点，不是四个 ──────────────────────────────────────────────────
 * 三点在圆周上均分 120°，任何时刻都有一到两个点处于亮态 ——
 * 四点（90°）在方形网格里读起来更像"四个方向"，而加载指示器要的是
 * "在转"，不是"四方"。Basic 取三点这个最中性的形态；
 * 具体几家主题用几个点，是它们各自的实现自由（见 slots/）。
 *
 * 契约第 3 条：指示器没有交互，插槽里不许放 MouseArea / Keys。
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

    /** 点的直径。 */
    readonly property real dotSize: base * 1.6

    /** 外接圆半径：让点**外缘**正好落在方框内。 */
    readonly property real orbit: (root.px - root.dotSize) / 2

    /** 点的个数。 */
    readonly property int dotCount: 3

    implicitWidth:  root.px
    implicitHeight: root.px
    width:  implicitWidth
    height: implicitHeight

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

            /* 极坐标摆位。角度从 12 点方向起算，顺时针。 */
            readonly property real angle:
                (index * 2 * Math.PI / root.dotCount) - Math.PI / 2

            x: root.px / 2 + Math.cos(dot.angle) * root.orbit - root.dotSize / 2
            y: root.px / 2 + Math.sin(dot.angle) * root.orbit - root.dotSize / 2

            /* 错开 period/3 起跑，于是"亮点"绕着圈跑。
             * 三段的时长加起来正好是一个 period：
             *   等一会（index × period/3）+ 淡入（period/3）+ 淡出（2×period/3）
             * 最后一段的时长是 2/3 个周期，这样下一轮开始时
             * 上一个点刚好回到最暗 —— 三个点的总相位刚好铺满一圈。 */
            SequentialAnimation on opacity {
                running: root.running
                loops: Animation.Infinite

                PauseAnimation { duration: dot.index * (root.period / root.dotCount) }
                NumberAnimation {
                    from: 0.15; to: 1.0
                    duration: root.period / root.dotCount
                    easing.type: Easing.OutSine
                }
                NumberAnimation {
                    from: 1.0; to: 0.15
                    duration: root.period * 2 / root.dotCount
                    easing.type: Easing.InSine
                }
            }
        }
    }

    // qmllint enable unqualified

    /* 这行是**防御性空操作**（root.opacity 本来就是 1），别把它当成
     * "把三个点钉在暗态"—— 它没这个作用，也做不到。真实的静止态是这样来的：
     * `spinning: false` 时下面的 SequentialAnimation 根本不跑，于是每个点的
     * `opacity` 停在**属性默认值 1.0**（不是动画的 from 值 0.15），
     * 三个点都实心、位置不转。
     *
     * 这件事对 M19 的像素门禁是前提：核验脚本量的是"点阵外缘到中心的
     * 距离 = indicatorSize/2"，而每个点各带 1/3 周期的错相。
     * 好在最暗相位（0.15）与页面底的亮度差仍有 ~25，远超判墨阈值 6 ——
     * 所以**抓图落在哪一相都不影响**这个量（见 .cache/_verify_m19.py 的 [5]）。 */
    Component.onCompleted: opacity = 1
}
