/****************************************************************************
 * QSkin · Quick Design System — Theme / shadcn / slots / SCButtonBackground
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * shadcn/ui 的按钮底板。映射关系与前三套都不同：
 *
 *   ┌──────────┬──────────────────────────────────────────────┐
 *   │ default  │ **近黑实心**（primary）—— shadcn 没有 outline │
 *   │ primary  │ 同 default（它本来就只有黑）                  │
 *   │ danger   │ destructive 红实心                            │
 *   │ ghost    │ 透明，hover 浮出 accent 灰（#F4F4F5）         │
 *   │ text     │ link 变体位：无底，hover 下划线（见 SCLabel） │
 *   └──────────┴──────────────────────────────────────────────┘
 *
 * hover 用「同色降 10% 不透明度」而非换色阶 —— 这是 shadcn 的 hover
 * 语言（bg-primary/90），和 Ant 换色阶（-5 档）是两种流派。
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

        /* 勾选态（M20）。完整论证见 BasicButtonBackground 里那段注释。
         * shadcn 多一层：它的 `default` 是**实心黑**，其余四家的 `default`
         * 是浅底描边。所以它需要额外一个 isSolid() 来决定勾选态取哪一档 ——
         * 实心变体选中 → brandActive（已是实心，再压深一格），
         * 其余 → brandSubtle（从透明浮出品牌浅底）。 */
        function isOn() { return checkable() && checked() }

        function isEmphasis() {
            var v = variant()
            return v === "primary" || v === "danger"
        }
        function isSolid() { return isEmphasis() || variant() === "default" }

        function bg() {
            if (disabled())
                return isEmphasis() ? Theme.color.bgSunken : "transparent"

            if (isOn()) {
                if (isSolid()) return Theme.color.brandActive
                return Theme.color.brandSubtle
            }

            switch (variant()) {
            case "primary":
            case "default":   /* shadcn 的 default 就是 primary 黑 */
                return pressed() ? Theme.color.brandActive
                                 : (hovered() ? Theme.color.brandHover : Theme.color.brand)
            case "danger":
                return pressed() ? Theme.color.dangerActive
                                 : (hovered() ? Theme.color.dangerHover : Theme.color.danger)
            /* ghost：hover 浮出 accent 灰 */
            case "ghost":
            case "text":
                return (variant() === "ghost" && (hovered() || pressed()))
                        ? Theme.color.brandSubtle : "transparent"
            default:
                return Theme.color.brand
            }
        }

        function borderWidth() { return 0 }

        function borderColor() { return "transparent" }
    }
}
