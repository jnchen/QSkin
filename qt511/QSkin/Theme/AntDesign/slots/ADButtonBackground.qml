/****************************************************************************
 * QSkin · Quick Design System — Theme / Ant Design / slots / ADButtonBackground
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Ant Design 的按钮底板。与 TDesign 的关键差异：
 *   ┌──────────┬───────────────────────────┬──────────────────────────┐
 *   │          │ TDesign                    │ Ant Design               │
 *   ├──────────┼───────────────────────────┼──────────────────────────┤
 *   │ 圆角     │ 3px                        │ 6px（radius.md 驱动）    │
 *   │ 默认hover│ 描边变蓝，按下时底色变灰   │ 描边变蓝，**按下底色不变**│
 *   │ text hover│ 浮出品牌浅底              │ 浮出 4% 黑的中性底       │
 *   │ 禁用     │ 换令牌（灰底灰字）         │ 同左，实心变 #F5F5F5 底  │
 *   └──────────┴───────────────────────────┴──────────────────────────┘
 *
 * 「默认 hover 描边变蓝、底色不动」这条签名 TDesign 与 Ant 完全一致 ——
 * M3 的收获：它是行业惯例而不是某家的怪癖，Basic 的映射才是异类。
 *
 * 契约三条照旧：只读 control 状态、不改状态、不加交互。
 ****************************************************************************/

/* QtQuick **不带版本号**：四角独立半径在版本化导入下不存在 —— 实测
 * 2.15 / 2.16 / 2.17 全报 "is not available"。完整实测见 COVERAGE.md
 * 第七节「M27 裁决四」。 */
import QtQuick 2.11
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

    /* Qt 5.11：_corners 是函数调用属性，5.11 在它返回前
     * 就求值 radius ⇒ ReferenceError。守卫挡不住（读属性就抛）。
     * 正解：自己算一次放进一个 QtObject，后续都从它取。*/
    QtObject { id: _c511_2; property var v: CornerUtil.corners(d.groupPosition(), Theme.radius.md) }
    radius: _c511_2.v ? Math.max(_c511_2.v.tl, _c511_2.v.tr, _c511_2.v.br, _c511_2.v.bl) : 0
    /* Qt 5.15 无四角独立半径（topLeftRadius 等是 Qt 6 独有，且只在
     * 「无版本 import」下才存在 —— 原注释有实测记录）。
     * 降级：主体取四角最大值，再用补角矩形把该直的角填回方形。
     * 已知差异：补角会盖掉一小段 border，而那正是分组按钮与相邻
     * 按钮的接缝；standalone（四角全等）与中段（四角全零）两种
     * 情形与 Qt 6 侧逐像素一致。 */
    Rectangle { visible: _c511_2.v.tl < radius; x: 0; y: 0; width: radius; height: radius; color: parent.color }
    Rectangle { visible: _c511_2.v.tr < radius; x: parent.width - radius; y: 0; width: radius; height: radius; color: parent.color }
    Rectangle { visible: _c511_2.v.br < radius; x: parent.width - radius; y: parent.height - radius; width: radius; height: radius; color: parent.color }
    Rectangle { visible: _c511_2.v.bl < radius; x: 0; y: parent.height - radius; width: radius; height: radius; color: parent.color }

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

        /* 勾选态（M20）。规则与 Basic 同一条，取值按 Ant 的语汇：
         * 选中 = --control-item-bg-active 那一族的品牌浅底 + 品牌描边；
         * primary / danger 走自己的 Active 档。完整论证见
         * BasicButtonBackground 里那段注释。 */
        function isOn() { return checkable() && checked() }

        function isEmphasis() {
            var v = variant()
            return v === "primary" || v === "danger"
        }
        function isBorderless() {
            return variant() === "text"
        }

        function bg() {
            if (disabled())
                return isEmphasis() ? Theme.color.bgSubtle
                                    : (isBorderless() ? "transparent" : Theme.color.bgSubtle)

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

            /* text 变体：hover 浮出 colorFillTertiary（4% 黑）的中性底 */
            case "text":
                return (hovered() || pressed()) ? "#0A000000" : "transparent"

            /* ★ Ant 默认按钮按下时底色**不变**（TDesign 会变灰） */
            default:
                return Theme.color.bgElevated
            }
        }

        function borderWidth() {
            if (variant() === "text" || isEmphasis()) return 0
            return 1
        }

        function borderColor() {
            if (disabled()) return Theme.color.borderStrong

            if (isOn() && !isEmphasis() && !isBorderless())
                return Theme.color.brand

            switch (variant()) {
            case "primary":
            case "danger":
            case "text":
                return "transparent"
            /* ghost = Ant 的 dashed/outline 按钮位：hover 描边与文字同变品牌色 */
            case "ghost":
                return pressed() ? Theme.color.brandActive
                                 : (hovered() ? Theme.color.brandHover : Theme.color.borderStrong)
            /* ★ default：hover → #4096FF（hover 色，不是常态品牌色），
             *   active → #0958D9 —— 比 TDesign 多区分了一档「hover vs 按下」 */
            default:
                return pressed() ? Theme.color.brandActive
                                 : (hovered() ? Theme.color.brandHover : Theme.color.borderStrong)
            }
        }
    }
}
