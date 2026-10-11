/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicRadioIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「indicator」插槽 —— 单选框的圆环与圆心圆点。
 *
 * ── 为什么不复用 checkIndicator ─────────────────────────────────────────
 * 尺寸一样（都是 16）、状态一样（checked / hovered / disabled 三件套）、
 * 令牌一样。按项目那条判据「只差颜色/字重 → 复用」本来该复用，但这里
 * 差的不是颜色，是**画法**：
 *
 *     复选框  选中 = 整块**填满**品牌色 + 反色勾
 *     单选框  选中 = 外圈**填法不同**
 *
 * 而"外圈怎么填"恰恰是四家分歧最大的一处（2 实心 / 2 描边，见下），
 * 一个插槽画不出两种策略。更要紧的是**耦合**：若两者共用一个格子，
 * 那么为了改单选而写的实现会顺带把复选框也改掉 —— 与 M4 把
 * switchIndicator / checkIndicator 分成两格是同一条判据。
 *
 * ⚠ 写注释时的坑：路径通配符（星号紧跟斜杠）在块注释里就是**结束符**，
 *   写进去会把本段注释提前闭合，余下那半句变成代码 —— 后果是整棵
 *   import 树一起红，而报错行号指在注释中间，因果极难看出。
 *   所以下面提到主题 slots 目录时一律写 `<主题>`，不写通配符。
 *   这条已由 tools/check-undefined-fn.sh 守着（判据两路：注释提前闭合、
 *   调用未定义函数）。
 *
 * ── 五家的策略与圆心直径（M20.1 逐个查过源码）──────────────────────────
 *   主题        策略    圆心    依据
 *   Basic       实心    6      本项目自己的默认牌子（本文件）
 *   TDesign     实心    8      icon 默认 'circle'＝填充型；@radio-dot-size = @radio-size/2
 *   Ant         实心    8      radioBgColor = colorPrimary + radioColor = colorWhite
 *   Arco        实心    5.6    mask 底色 = brand；::after 白点 scale(0.4) → (16−2)×0.4
 *   shadcn      描边    10     border-primary + fill-primary 圆点，h-2.5 = 10px
 *
 * 初版这里写的是"2 实心 / 2 描边（TDesign+Arco 实心，Ant+shadcn 描边）",
 * 两处都错：Ant 被误判成了它非默认的 wireframe 主题，而 TDesign 的圆心
 * 是 8 不是 6。更正之后覆盖矩阵变成 **TDesign / Ant / shadcn 各自覆盖一格，
 * Arco 复用本文件**——Arco 复用的理由是可以算出来的：5.6 与 6 差 0.4px，
 * 而这个 0.4px 就是"能复用"与"不能复用"的分界线（TDesign 的 8 差 2px，
 * 在小圆点上是 33% 的相对差，肉眼一眼可辨）。
 *
 * ── 圆点直径写死 6，不跟字号走 ──────────────────────────────────────────
 * 与 BasicCheckIndicator 同源：16px 这个方框尺寸五家一致得惊人，
 * 圆心取各自的规矩（见上表）。真要变，换掉这个插槽即可。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    implicitWidth:  16
    implicitHeight: 16
    width:  implicitWidth
    height: implicitHeight

    /** 圆心圆点直径。**公开出来给属性侧立桩** —— 主题换掉这个插槽时，
     *  这个数就是"装上去的到底是不是本家那一份"的证据
     *  （与 QSkinSpin.strokeWidth 同一套用法，见 smoke_m19_theme.qml）。 */
    readonly property int dotSize: 6

    /* ── 外圈 ── */

    Rectangle {
        anchors.fill: parent
        radius: width / 2

        color:        d.bg()
        border.width: d.borderWidth()
        border.color: d.borderColor()

        Behavior on color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    /* ── 圆心 ──
     * 实心策略下，选中时外圈是品牌色、圆心取反色 —— 于是"白点"在
     * 深色主题里同样成立（onBrand 的定义就是品牌色之上的前景色）。 */

    Rectangle {
        anchors.centerIn: parent
        width:  root.dotSize
        height: root.dotSize
        radius: width / 2

        visible: d.on()
        color:   d.dotColor()

        Behavior on color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    QtObject {
        id: d

        function on()       { return root.control ? root.control.checked === true : false }
        function disabled() { return root.control ? root.control.enabled === false : false }
        function hovered()  { return root.control ? root.control.hovered === true : false }

        function bg() {
            if (disabled()) return on() ? Theme.color.bgSunken : Theme.color.bgSubtle
            return on() ? Theme.color.brand
                        : (hovered() ? Theme.color.bgSubtle : Theme.color.bg)
        }

        function borderWidth() { return on() ? 0 : 1 }

        function borderColor() {
            if (disabled()) return Theme.color.border
            if (hovered())  return Theme.color.brand
            return Theme.color.borderStrong
        }

        /** 圆心颜色：选中时是品牌色的**反色**，未选中时不可见 */
        function dotColor() {
            if (disabled()) return Theme.color.fgDisabled
            return Theme.color.onBrand
        }
    }
}
