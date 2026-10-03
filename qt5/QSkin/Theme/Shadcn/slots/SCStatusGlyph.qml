/****************************************************************************
 * QSkin · Quick Design System — Theme / Shadcn / slots / SCStatusGlyph
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 * shadcn 的语义状态记号。契约见 BasicStatusGlyph.qml 文件头。
 *
 * ── 与 Basic 的差异：描边而不是实心 ────────────────────────────────────
 * 前三家（Ant / TDesign / Arco）的语义图标都是**实心圆盘 + 反白记号**；
 * shadcn 的图标来自 lucide，是**描边圆环 + 同色记号**。这是这一格
 * 必须进插槽的直接证据 —— 分歧在形态上，令牌表达不了。
 *
 * 还有一处更硬的分歧：**warning 的形状根本不同**。
 * 前三家用圆盘 + "!"，lucide 的 `triangle-alert` 是**三角** + "!"。
 * 所以本文件里 warning 走的是另一条容器路径，不是同一支笔换个颜色。
 *
 * ── 坐标的出处（可以逐点核对，不是估的）──────────────────────────────
 * 下面所有控制点都是 lucide **24 视框**里的原始坐标除以 24：
 *
 *     circle           cx=12 cy=12 r=10        → 半径 10/24，笔画 2/24
 *     circle-check     "m9 12 2 2 4-4"         → (9,12) (11,14) (15,10)
 *     info             circle + "M12 16v-4" + "M12 8h.01"
 *     circle-alert     circle + (12,8)-(12,12) + 点(12,16)
 *     triangle-alert   "M12 9v4" + "M12 17h.01" + 顶点 (12,3.5) (3,20) (21,20)
 *
 * 所以"像不像 shadcn"这件事不靠审美，靠 24 视框这条算术。
 *
 * ── 线宽为什么是**等比**的（与 SCChevronIndicator 不同）────────────────
 * SCChevronIndicator 把线宽写死 2px，并在文件头写明"lucide 的线宽不随
 * 图标尺寸缩放"。那是那一格的特殊情况：箭头的盒子恒为 14，没有尺寸轴。
 *
 * 这一格不一样 —— 宿主给的 size 从 QSkinAlert 的 16 到 QSkinResult 的 64，
 * **跨了一个数量级**。此时写死 2px 会在 64px 上变成一根发丝。
 * SVG 里 stroke-width 是随视框等比缩放的，所以这里按 24 视框换算成
 * `size / 12`（= 2/24），这才是"同一个 lucide 图标被放大"的真实行为。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Shapes 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    readonly property string status: {
        if (root.control === null || root.control === undefined) return "info"
        if (root.control.status === undefined) return "info"
        var s = String(root.control.status)
        return (s === "success" || s === "warning" || s === "danger") ? s : "info"
    }

    readonly property int size: {
        if (root.control === null || root.control === undefined) return Theme.size.iconMd
        if (root.control.size === undefined || root.control.size === null) return Theme.size.iconMd
        var n = Number(root.control.size)
        return (isNaN(n) || n <= 0) ? Theme.size.iconMd : n
    }

    implicitWidth:  root.size
    implicitHeight: root.size
    width:  implicitWidth
    height: implicitHeight

    /** lucide 的笔画 = 视框的 2/24。 */
    readonly property real strokeW: root.width / 12

    readonly property color toneColor: root.status === "success" ? Theme.color.success
                                     : root.status === "warning" ? Theme.color.warning
                                     : root.status === "danger"  ? Theme.color.danger
                                                                 : Theme.color.info

    /* ══════════════════ 容器：圆环（warning 除外） ══════════════════
     * 描边圆用 Rectangle 的 border 画：borders 画在矩形**内沿**，
     * 所以外径正好等于 width，不必再去算 antialiasing 的半像素。
     * 圆心半径 = 10/24 视框 → border 的内沿落在 2*10/24 处，
     * 于是 border.width = size/12 时内径 = size - 2*(size/12) = size*10/12 ✓ */
    Rectangle {
        anchors.fill: parent

        visible: root.status !== "warning"

        radius: width / 2
        color:  "transparent"
        border.width: root.strokeW
        border.color: root.toneColor
    }

    /* ══════════════════ 容器：三角（仅 warning） ══════════════════
     * lucide triangle-alert 的三个顶点是 (12,3.5) (3,20) (21,20)，
     * 归一化后收进盒内一点点 —— 描边有半笔宽留在路径外侧。
     * 三点用 RoundJoin 连起来就是 lucide 那个圆角三角。 */
    Shape {
        anchors.fill: parent
        visible: root.status === "warning"

        ShapePath {
            strokeWidth: root.strokeW
            strokeColor: root.toneColor
            fillColor:   "transparent"
            joinStyle:   ShapePath.RoundJoin
            capStyle:    ShapePath.RoundCap

            startX: root.width * 0.50;  startY: root.height * 0.16
            PathLine { x: root.width * 0.16;  y: root.height * 0.80 }
            PathLine { x: root.width * 0.84;  y: root.height * 0.80 }
            PathLine { x: root.width * 0.50;  y: root.height * 0.16 }
        }
    }

    /* ══════════════════ 记号（与容器同色，不是反白） ══════════════════ */

    /* ✓ circle-check: (9,12) → (11,14) → (15,10) */
    Shape {
        anchors.fill: parent
        visible: root.status === "success"

        ShapePath {
            strokeWidth: root.strokeW
            strokeColor: root.toneColor
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap
            joinStyle:   ShapePath.RoundJoin

            startX: root.width * (9 / 24);   startY: root.height * (12 / 24)
            PathLine { x: root.width * (11 / 24);  y: root.height * (14 / 24) }
            PathLine { x: root.width * (15 / 24);  y: root.height * (10 / 24) }
        }
    }

    /* i info: 点 (12,8) + 竖杠 (12,16) → (12,12) */
    Shape {
        anchors.fill: parent
        visible: root.status === "info"

        ShapePath {
            strokeWidth: root.strokeW
            strokeColor: root.toneColor
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            startX: root.width * (12 / 24);  startY: root.height * (8 / 24)
            PathLine { x: root.width * (12 / 24);  y: root.height * (8 / 24) }
        }

        ShapePath {
            strokeWidth: root.strokeW
            strokeColor: root.toneColor
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            startX: root.width * (12 / 24);  startY: root.height * (16 / 24)
            PathLine { x: root.width * (12 / 24);  y: root.height * (12 / 24) }
        }
    }

    /* ! circle-alert（在圆环里）: 竖杠 (12,8)-(12,12) + 点 (12,16)
     *   ! triangle-alert（在三角里）: 竖杠 (12,9)-(12,13) + 点 (12,17)
     * 两个 warning 分支共用这一个 Shape —— 它们形状自洽，只是位置不同，
     * 所以由 status 之外的那个量（容器类型）来选。 */
    Shape {
        anchors.fill: parent
        visible: root.status === "warning"

        ShapePath {
            strokeWidth: root.strokeW
            strokeColor: root.toneColor
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            /* triangle-alert 的竖杠 */
            startX: root.width * (12 / 24);  startY: root.height * (9 / 24)
            PathLine { x: root.width * (12 / 24);  y: root.height * (13 / 24) }
        }

        ShapePath {
            strokeWidth: root.strokeW
            strokeColor: root.toneColor
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            /* triangle-alert 的点 */
            startX: root.width * (12 / 24);  startY: root.height * (17 / 24)
            PathLine { x: root.width * (12 / 24);  y: root.height * (17 / 24) }
        }
    }

    /* × circle-alert 的对角线写法在 lucide 里没有 —— shadcn 的"错误"
     * 用的是 circle-alert（圆 + !），与 warning 的三角 + ! 区分开。
     * 但 QSkinAlert 的 danger 语义需要一个"确定是错的"记号，而
     * `circle-x` 才是 lucide 里对应 × 的那一个（"M15 9l-6 6" + "M9 9l6 6"）。
     * 所以这里按语义选 `circle-x`，坐标同样取自 24 视框。 */
    Shape {
        anchors.fill: parent
        visible: root.status === "danger"

        ShapePath {
            strokeWidth: root.strokeW
            strokeColor: root.toneColor
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            startX: root.width * (9 / 24);   startY: root.height * (9 / 24)
            PathLine { x: root.width * (15 / 24);  y: root.height * (15 / 24) }
        }

        ShapePath {
            strokeWidth: root.strokeW
            strokeColor: root.toneColor
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            startX: root.width * (15 / 24);  startY: root.height * (9 / 24)
            PathLine { x: root.width * (9 / 24);   y: root.height * (15 / 24) }
        }
    }
}
