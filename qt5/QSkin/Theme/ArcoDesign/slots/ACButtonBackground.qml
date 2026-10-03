/****************************************************************************
 * QSkin · Quick Design System — Theme / Arco Design / slots / ACButtonBackground
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Arco Design 的按钮底板。三套主题里映射关系差异最大的一个：
 *
 *   ┌──────────┬──────────────────────────────┬─────────────────────────┐
 *   │          │ Ant / TDesign（default）      │ Arco（default）          │
 *   ├──────────┼──────────────────────────────┼─────────────────────────┤
 *   │ 默认按钮 │ 白底 + 描边，hover 描边变蓝  │ **灰色实心**（secondary）│
 *   │ hover    │ 描边表达                     │ 底色加深一档灰          │
 *   │ ghost    │ 品牌浅底                     │ 白底描边，hover 描边变蓝 │
 *   │ text     │ hover 浮出品牌浅底 / 中性底  │ hover 浮出灰色 fill     │
 *   └──────────┴──────────────────────────────┴─────────────────────────┘
 *
 * Arco 是三套里唯一「default ≠ outline」的 —— 这正是插槽要保护的自由度：
 * 同一个 variant 枚举，每家对「默认长什么样」的回答可以完全不同。
 * 灰阶 hover 用令牌 fillHover / fillActive（tokens.js 扩展键）驱动。
 ****************************************************************************/

/* QtQuick **不带版本号**：四角独立半径在版本化导入下不存在 —— 实测
 * 2.15 / 2.16 / 2.17 全报 "is not available"。完整实测见 COVERAGE.md
 * 第七节「M27 裁决四」。 */
import QtQuick 2.15
import QSkin.Foundation 1.0

Rectangle {
    id: root

    property var control: null

    anchors.fill: parent

    /* ══ 分组按钮的三态圆角（M27）═════════════════════════════════════
     * 四角半径由 control.groupPosition 决定，映射在 Foundation/CornerUtil
     * 里（一份实现、五个消费者）。**不分组的按钮读到 "standalone"、
     * 四角全等** —— 与加这个功能之前逐字一致，这就是新契约字段带默认值
     * 的意思：老消费者一行不改。
     *
     * 为什么不写成一句 `radius:`：`radius` 是四角的**默认值**，被单独指定的
     * 角会覆盖它 —— 而中段按钮要的是四角全 0，光靠 radius 表达不了。
     */
    readonly property var _corners: CornerUtil.corners(d.groupPosition(), Theme.radius.md)

    radius: Math.max(_corners.tl, _corners.tr, _corners.br, _corners.bl)
    /* Qt 5.15 无四角独立半径（topLeftRadius 等是 Qt 6 独有，且只在
     * 「无版本 import」下才存在 —— 原注释有实测记录）。
     * 降级：主体取四角最大值，再用补角矩形把该直的角填回方形。
     * 已知差异：补角会盖掉一小段 border，而那正是分组按钮与相邻
     * 按钮的接缝；standalone（四角全等）与中段（四角全零）两种
     * 情形与 Qt 6 侧逐像素一致。 */
    Rectangle { visible: _corners.tl < radius; x: 0; y: 0; width: radius; height: radius; color: parent.color }
    Rectangle { visible: _corners.tr < radius; x: parent.width - radius; y: 0; width: radius; height: radius; color: parent.color }
    Rectangle { visible: _corners.br < radius; x: parent.width - radius; y: parent.height - radius; width: radius; height: radius; color: parent.color }
    Rectangle { visible: _corners.bl < radius; x: 0; y: parent.height - radius; width: radius; height: radius; color: parent.color }

    color:        d.bg()
    border.width: d.borderWidth()
    border.color: d.borderColor()

    Behavior on color {
        ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
    }
    Behavior on border.color {
        ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
    }

    QtObject {
        id: d

        /* 组的方位（M27）。不分组时是 "standalone" —— 契约的默认值，
         * 也是"老消费者一行不改"那条承诺的落点。 */
        function groupPosition() {
            return (root.control && root.control.groupPosition !== undefined)
                    ? root.control.groupPosition : "standalone"
        }

        function variant() {
            return (root.control && root.control.variant !== undefined)
                    ? root.control.variant : "default"
        }
        function pressed()  { return root.control ? root.control.pressed === true : false }
        function hovered()  { return root.control ? root.control.hovered === true : false }
        function disabled() { return root.control ? root.control.enabled === false : false }
        function checkable() { return root.control ? root.control.checkable === true : false }
        function checked()   { return root.control ? root.control.checked === true : false }

        /* 勾选态（M20）。Arco 的"选中"语汇是 color-primary-light-1 那一档
         * 品牌浅底；实心（primary / danger）走自己的 Active 档。
         * 注意 Arco 的 default 是**灰色实心**（secondary），它没有描边 ——
         * 所以勾选后靠底色区分，不靠边。详见 BasicButtonBackground。 */
        function isOn() { return checkable() && checked() }

        function isEmphasis() {
            var v = variant()
            return v === "primary" || v === "danger"
        }

        function bg() {
            if (disabled())
                return isEmphasis() ? Theme.color.brandSubtle : Theme.color.bgSubtle

            if (isOn()) {
                switch (variant()) {
                case "primary": return Theme.color.brandActive
                case "danger":  return Theme.color.dangerActive
                default:        return Theme.color.brandSubtle
                }
            }

            switch (variant()) {
            case "primary":
                return pressed() ? Theme.color.brandActive
                                 : (hovered() ? Theme.color.brandHover : Theme.color.brand)
            case "danger":
                return pressed() ? Theme.color.dangerActive
                                 : (hovered() ? Theme.color.dangerHover : Theme.color.danger)

            /* ghost = Arco 的 outline 位：白底描边，hover 底色微降 */
            case "ghost":
                return (hovered() || pressed()) ? Theme.color.bgSubtle : Theme.color.bgElevated

            /* text = Arco 的 text 位：hover 浮出灰色 fill（color-fill-2） */
            case "text":
                return pressed() ? Theme.color.fillActive
                                 : (hovered() ? Theme.color.bgSunken : "transparent")

            /* ★ default = Arco secondary：灰色实心，hover/按下逐档加深 */
            default:
                return pressed() ? Theme.color.fillActive
                                 : (hovered() ? Theme.color.fillHover : Theme.color.bgSunken)
            }
        }

        function borderWidth() {
            if (variant() === "text" || isEmphasis()) return 0
            /* 只有 ghost（outline 位）有描边 */
            return variant() === "ghost" ? 1 : 0
        }

        function borderColor() {
            if (disabled()) return Theme.color.border

            /* 只有 ghost（outline 位）有描边，勾选态对它才有意义 */
            if (isOn() && variant() === "ghost")
                return Theme.color.brand

            switch (variant()) {
            case "ghost":
                return pressed() ? Theme.color.brandActive
                                 : (hovered() ? Theme.color.brand : Theme.color.borderStrong)
            default:
                return "transparent"
            }
        }
    }
}
