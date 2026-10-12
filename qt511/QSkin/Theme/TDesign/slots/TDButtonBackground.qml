/****************************************************************************
 * QSkin · Quick Design System — Theme / TDesign / slots / TDButtonBackground
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * TDesign 的按钮底板。与 Basic 实现的差别，正是「为什么必须开插槽」的答案：
 *
 *   ┌──────────┬──────────────────────────┬──────────────────────────┐
 *   │          │ Basic（中性）             │ TDesign                  │
 *   ├──────────┼──────────────────────────┼──────────────────────────┤
 *   │ 默认按钮 │ 白底，hover 整块变灰      │ 白底，hover **只变描边** │
 *   │ hover    │ 底色 + 描边一起变        │ 底色不动                 │
 *   │ 按下     │ bgSunken                 │ bg-color-container-active│
 *   │ 圆角     │ Theme.radius.md（4→3）   │ 同左，令牌驱动           │
 *   └──────────┴──────────────────────────┴──────────────────────────┘
 *
 * 光换令牌改不掉第一行：Basic 的 default 分支写了
 *     hovered ? bgSubtle : bg
 * 而 TDesign 的 hover 根本不动底色。这类「状态到令牌的映射关系」差异，
 * 才是插槽真正要承载的东西 —— 令牌只能改值，改不了映射。
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

    /* 3px —— --td-radius-default。
     * 注意这里写的是 Theme.radius.md 而不是硬编码 3：
     * 换肤时令牌已经替你改了，插槽不该重复写死数值，
     * 否则同一份令牌在深浅两主题下会失去控制力。 */
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
    QtObject { id: _c511_11; property var v: CornerUtil.corners(d.groupPosition(), Theme.radius.md) }
    radius: _c511_11.v ? Math.max(_c511_11.v.tl, _c511_11.v.tr, _c511_11.v.br, _c511_11.v.bl) : 0
    /* Qt 5.15 无四角独立半径（topLeftRadius 等是 Qt 6 独有，且只在
     * 「无版本 import」下才存在 —— 原注释有实测记录）。
     * 降级：主体取四角最大值，再用补角矩形把该直的角填回方形。
     * 已知差异：补角会盖掉一小段 border，而那正是分组按钮与相邻
     * 按钮的接缝；standalone（四角全等）与中段（四角全零）两种
     * 情形与 Qt 6 侧逐像素一致。 */
    Rectangle { visible: _c511_11.v.tl < radius; x: 0; y: 0; width: radius; height: radius; color: parent.color }
    Rectangle { visible: _c511_11.v.tr < radius; x: parent.width - radius; y: 0; width: radius; height: radius; color: parent.color }
    Rectangle { visible: _c511_11.v.br < radius; x: parent.width - radius; y: parent.height - radius; width: radius; height: radius; color: parent.color }
    Rectangle { visible: _c511_11.v.bl < radius; x: 0; y: parent.height - radius; width: radius; height: radius; color: parent.color }

    color:        d.bg()
    border.width: d.borderWidth()
    border.color: d.borderColor()
    opacity:      d.opacity()

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

        /* 勾选态（M20）。规则与 Basic 同一条，取值按 TDesign 的语汇。
         * 完整论证见 BasicButtonBackground 里那段注释。 */
        function isOn() { return checkable() && checked() }

        function isEmphasis() {
            var v = variant()
            return v === "primary" || v === "danger"
        }
        function isBorderless() {
            var v = variant()
            return v === "ghost" || v === "text"
        }

        /* TDesign 的禁用态是**换令牌**而不是降透明度，
         * 所以这里返回 1 —— 降 opacity 会连带把底色一起冲淡，
         * 与官方「底色变灰、文字变浅」的做法不是一回事。 */
        function opacity() { return 1 }

        function bg() {
            if (disabled())
                return isEmphasis()    ? Theme.color.brandSubtle
                     : isBorderless()  ? "transparent"
                                       : Theme.color.bgSubtle

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

            /* TDesign 的 outline / text 变体常态没有底，
             * hover 才浮出极浅的品牌底色（--td-brand-color-light）。 */
            case "ghost":
            case "text":
                return (hovered() || pressed()) ? Theme.color.brandSubtle : "transparent"

            /* ★ 与 Basic 的关键差别：default 的 hover 不动底色，
             *   只有按下才变。底色变化全部交给描边和文字去表达。 */
            default:
                return pressed() ? Theme.color.bgSubtle : Theme.color.bgElevated
            }
        }

        function borderWidth() {
            /* 文字按钮没有边框；实心按钮也不需要（底色已经够重） */
            if (variant() === "text" || isEmphasis()) return 0
            return 1
        }

        function borderColor() {
            if (disabled()) return Theme.color.border

            if (isOn() && !isEmphasis() && variant() !== "text")
                return Theme.color.brand

            switch (variant()) {
            case "primary":
            case "danger":
            case "text":
                return "transparent"
            case "ghost":
                return (hovered() || pressed()) ? Theme.color.brand : Theme.color.borderStrong
            /* ★ TDesign 默认按钮的招牌动作：hover 描边变品牌色 */
            default:
                return (hovered() || pressed()) ? Theme.color.brand : Theme.color.borderStrong
            }
        }
    }
}
