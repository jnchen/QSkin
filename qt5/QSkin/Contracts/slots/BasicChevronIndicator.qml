/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicChevronIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「chevronIndicator」插槽的 Basic 默认实现 —— 方向箭头（展开 / 折叠 / 翻页）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这个插槽为什么早该存在
 * ════════════════════════════════════════════════════════════════════════
 * Slots.qml 从 M1 起就把 indicator 家族写成「勾选框、开关轨道、**展开箭头**」。
 * 但「展开箭头」这一项**从来没有实现过**，于是每个用到它的控件各自绕过去：
 *
 *   QSkinSelect      自己硬编码了一个 Shape 三角（还在注释里论证了为什么
 *                  不能用 Text "▾"）
 *   QSkinTable       树形展开箭头直接打字符 "▾"/"▸" —— 违反了它自己那条
 *                  规则（见下）
 *   QSkinDatePicker  自己画了两条 Shape 折线做翻月
 *   QSkinPagination  上/下页直接拿 QSkinButton 的 text 打 "‹"/"›"
 *
 * 同一种记号在同一个仓库里有四种画法，其中一种是字符。
 * 这不是风格分歧，是契约里许诺了却没兑现的那一格。
 *
 * ── 为什么必须是插槽而不是「就地画成 Shape」────────────────────────────
 * 项目的既有规则是「图标不用字符，用矢量画」，四处都写过：
 *
 *   BasicCheckIndicator  「勾用 Shape 画而不是 Text 打 "✓"」
 *   QSkinSelect            「用 Shape 画三角而不是 Text "▾"」
 *   QSkinTag               「× 用 Shape 画而不是打 "×"」
 *   QSkinInputNumber       「"▴/▾" 这类字形在不同系统字体栈里回退不可控」
 *
 * 但「用矢量画」只解决一半问题 —— 还有「画成什么样」。而这一半恰恰
 * **因主题而异**：线宽、端点圆钝、图标尺寸，各家的图标语言都不同
 * （见 slots/ 下四份主题实现）。按项目一贯的判据 ——
 * 「差异属于主题，就不该在控件里硬编码」—— 它必须是一个插槽。
 *
 * ── 契约 ──────────────────────────────────────────────────────────────
 *   property var control   宿主。鸭子类型，要求暴露：
 *     · direction  string  箭头指向："up" | "down" | "left" | "right"
 *     · enabled    bool    可选，缺省视为 true
 *
 *   **展开语义不进插槽**。树形节点「展开还是收起」是控件的事，控件自己
 *   翻译成 direction（收起 → "right"，展开 → "down"）。插槽只回答
 *   「朝右的箭头长什么样」。
 *
 *   尺寸：宿主**不要**给宽高，用插槽的 implicitWidth/Height —— 图标多大
 *   本来就是主题的差异之一。宿主把自己的列宽留给插槽居中即可。
 *
 * 契约第 3 条：箭头本身没有交互，插槽里不许放 MouseArea。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Shapes 1.15
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

    /* 底形画成**朝右**的折线，其余方向靠旋转得到。
     *
     * 顺时针：右 0° / 下 90° / 左 180° / 上 270°。
     * 于是最常用的两种过渡都走最短路径：
     *   树形  收起→展开  right → down   =   0° → 90°    四分之一圈
     *   下拉  收起→展开  down  → up     =  90° → 270°    半圈
     * 半圈那两个方向从哪边绕都一样远，视觉上就是个翻转 ——
     * 与 QSkinSelect 原来那版 `rotation: opened ? 180 : 0` 完全一致。 */
    readonly property int angle: root.direction === "right" ? 0
                               : root.direction === "down"  ? 90
                               : root.direction === "left"  ? 180
                                                            : 270

    implicitWidth:  Math.round(Theme.size.iconSm / 2)
    implicitHeight: implicitWidth
    width:  implicitWidth
    height: implicitHeight

    Shape {
        anchors.fill: parent

        rotation: root.angle
        transformOrigin: Item.Center

        /* 动画只在**方向变了**之后跑，首次出现时不该看见箭头自己在转。
         *
         * 光靠 Behavior 不够：绑定第一次求值时 rotation 从默认的 0
         * 跳到 root.angle，Behavior 会把这**也算成一次变化**。于是
         * QSkinSelect（初始 down = 90°）一出现就会转四分之一圈。
         * 所以延到组件完成后再开。 */
        Behavior on rotation {
            enabled: root.animate
            NumberAnimation {
                duration: Theme.motion.fast
                easing.type: Theme.motion.easing
            }
        }

        ShapePath {
            /* 线宽跟着盒子走，这样宿主（或主题）改 implicitWidth 时
             * 不会出现「大箭头配细线」的失真。 */
            strokeWidth: root.strokeWidth
            strokeColor: root.enabled ? Theme.color.fgSecondary : Theme.color.fgDisabled
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap
            joinStyle:   ShapePath.RoundJoin

            startX: root.width  * 0.30;  startY: root.height * 0.16
            PathLine { x: root.width  * 0.70;  y: root.height * 0.50 }
            PathLine { x: root.width  * 0.30;  y: root.height * 0.84 }
        }
    }

    /** 线宽：盒子边长的 16%。主题要改线宽就重写这个属性，
     *  不必重写整条路径。 */
    readonly property real strokeWidth: root.width * 0.16

    /** 首次出现时不许动画。见上面 Behavior 处的注释。 */
    property bool animate: false
    Component.onCompleted: root.animate = true
}
