/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicButtonBackground
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「background」插槽的 Basic 默认实现 —— 按钮的底板。
 *
 * 这个文件是「为什么需要插槽」最好的例子：
 * 下面这 60 行状态映射，在 TDesign / Ant / Arco / shadcn 里各不相同
 * （圆角 3px 还是 6px、hover 是加深还是变淡、描边按钮有没有底色……），
 * 但**状态机本身一行都不用改**。换肤就是换这个文件。
 *
 * 它只做三件事：
 *   1. 读 control 的状态（variant / hovered / pressed / enabled）
 *   2. 把状态映射成令牌
 *   3. 把令牌画出来
 * 不写状态、不加交互 —— 见 Slots.qml 的契约三条。
 ****************************************************************************/

/* QtQuick **不带版本号**：四角独立半径（topLeftRadius 等）在版本化导入下
 * 不存在 —— 实测 2.15 / 2.16 / 2.17 全报 "is not available"，不带版本号才能
 * 用（Qt 6 里无版本导入 = 取最高可用版本）。完整实测与理由见
 * COVERAGE.md 第七节「M27 裁决四」。同一条坑在 tools/check-shape-aa.py
 * 文件头已经记过一次（那里是 QtQuick.Shapes）。 */
import QtQuick
import QSkin.Foundation 1.0

Rectangle {
    id: root

    /* 由宿主控件在 Loader.onLoaded 里注入。
     * 用 var 而非 Item：插槽要读 control.pressed / control.variant 这类
     * 宿主自定义状态，声明成 Item 会被 qmllint 按 QQuickItem 做成员检查。
     * 插槽契约是鸭子类型 —— 统一用 var，见 BasicLabel.qml 的同名注释。 */
    property var control: null

    /* 插槽是 Loader 的 item，它的 parent 就是那个 Loader；
     * 而 Loader 在宿主控件里已经撑满控件，所以这里直接 fill。 */
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

    topLeftRadius:      _corners.tl
    topRightRadius:     _corners.tr
    bottomRightRadius:  _corners.br
    bottomLeftRadius:   _corners.bl

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

        /* ── 勾选态（M20）────────────────────────────────────────────
         * `QSkinButton.checkable / checked` 自 M1 起就是公开属性，但**五份
         * 底板没有一份读过它** —— 一个 checkable 的按钮按下去，checked
         * 变了、toggled 发了，底色一个像素不动。这是 M20 做 Toggle 时
         * 撞出来的存量缺陷（Toggle 与 Button 共用这一格插槽）。
         *
         * 注意「勾选」与「变体」是**两条正交的轴**：
         *   variant 答"这是个什么按钮"，checked 答"它现在是开还是关"。
         * 所以勾选态必须独立成格，不能塞进 variant 的分支里。
         */
        function isOn() { return checkable() && checked() }

        function isEmphasis() {
            var v = variant()
            return v === "primary" || v === "danger"
        }
        function isBorderless() {
            var v = variant()
            return v === "ghost" || v === "text"
        }

        /** 幽灵 / 文字按钮：常态不画底，hover 或按下时才浮现 */
        function opacity() {
            if (disabled())    return 0.55
            /* ★ 勾选态也要可见（M20）：ghost / text 常态 opacity 0，
             *   一个"已经选中"的幽灵按钮若仍然隐形，那勾选就没有表达。
             *   注意这只影响 checkable 的宿主 —— 普通 ghost 按钮的
             *   checked 恒 false，行为一个像素都没变。 */
            if (isBorderless()) return (hovered() || pressed() || isOn()) ? 1 : 0
            return 1
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
            case "ghost":
            case "text":
                return pressed() ? Theme.color.bgSunken : Theme.color.bgSubtle
            default:
                return pressed() ? Theme.color.bgSunken
                                 : (hovered() ? Theme.color.bgSubtle : Theme.color.bg)
            }
        }

        function borderWidth() {
            return variant() === "text" ? 0 : 1
        }

        function borderColor() {
            if (disabled()) return Theme.color.border

            /* 勾选态自己带一圈品牌描边 —— 底色那一档（brandSubtle）与
             * hover 后的 bgSubtle 都是浅灰系，光靠底色区分不干净。 */
            if (isOn() && !isEmphasis() && variant() !== "text")
                return Theme.color.brand

            switch (variant()) {
            case "primary":
            case "danger":
                return "transparent"
            case "text":
                return "transparent"
            case "ghost":
                return (hovered() || pressed()) ? Theme.color.brand : Theme.color.border
            default:
                return (hovered() || pressed()) ? Theme.color.brand : Theme.color.borderStrong
            }
        }
    }
}
