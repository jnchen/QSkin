/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicToggleBackground
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「background」插槽的**开关**版本 —— 一个按钮形状的两态控件。
 *
 * ── 为什么这一格没有复用 buttonBackground（本批的第二个新增插槽）──────
 * 一开始的方案是复用：开关不就是"会一直按着的按钮"吗？`variant` 换一档
 * 就够了。落到实现上才发现它不成立，而证据就在已有的五份底板里：
 *
 *   ① `variant` 在各家**不是同一套语汇**
 *        shadcn   default = 近黑**实心**
 *        其余四家  default = 浅色**描边**
 *      于是"开关的关闭态用 default"在 shadcn 上会得到一个黑按钮，
 *      而"打开态"是浅色 —— 一个开关，关着比开着还重。
 *
 *   ② 常态可见性也不是一回事
 *        Basic     ghost 在常态 `opacity: 0`（只有 hover 才浮出来）
 *        其余四家  ghost/outline 常态都有 1px 描边
 *      于是"开关的关闭态用 ghost"在 Basic 上会**完全看不见** ——
 *      屏幕上只有一个孤零零的文字标签，没有任何东西提示"这里能点"。
 *
 *   ③ 更要紧的是语义：`variant` 回答的是"这是个什么按钮"（主要 / 次要 /
 *      幽灵），而开关问的是"它现在是开还是关"。这是**两条正交的轴**。
 *      把后者塞进前者的枚举里，等于让"主按钮的开关态"没有地方表达 ——
 *      而它显然需要（一个 primary 变体的开关打开时应该更深，不是换蓝底）。
 *
 * 所以：**开关的 off/on 是一条独立的轴，它需要自己的格子。**
 * 与 M4 把 checkIndicator / switchIndicator 分成两格、M20 把 radioIndicator
 * 独立出来，是同一条判据的三次应用。
 *
 * ── 与 buttonBackground 的关系：共用令牌，不共用映射 ────────────────────
 * 它俩读同一批颜色令牌、同一个 radius / motion，四套主题的语汇因此
 * 自动一致；不同的只有"哪一档给哪个状态"。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Rectangle {
    id: root

    /* 宿主引用。用 var 而非 Item：插槽要读 control.checked / control.variant
     * 这类宿主自定义状态，声明成 Item 会被 qmllint 按 QQuickItem 做成员检查。
     * 插槽契约是鸭子类型，统一用 var。 */
    property var control: null

    anchors.fill: parent

    radius: d.radius()

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

        function variant() {
            return (root.control && root.control.variant !== undefined)
                    ? root.control.variant : "outline"
        }
        function on()        { return root.control ? root.control.checked === true : false }
        function pressed()   { return root.control ? root.control.pressed === true : false }
        function hovered()   { return root.control ? root.control.hovered === true : false }
        function disabled()  { return root.control ? root.control.enabled === false : false }

        /* 圆角比按钮略大一档：开关通常是"内容区里的一小块"，
         * 直角会让它看起来像一个没做完的输入框。 */
        function radius() { return Theme.radius.md }

        function bg() {
            if (disabled()) return on() ? Theme.color.brandSubtle : Theme.color.bgSubtle
            if (on())       return Theme.color.brandSubtle
            if (pressed())  return Theme.color.bgSunken
            if (hovered())  return Theme.color.bgSubtle
            /* default 变体常态无底（它靠 hover 与开态区分）；
             * outline 变体也是有底的白 —— 底色不是它俩的差别，描边才是。 */
            return variant() === "default" ? "transparent" : Theme.color.bg
        }

        function borderWidth() {
            /* 开态一律有描边：那是"选中的东西"该有的轮廓 */
            if (on()) return 1
            return variant() === "default" ? 0 : 1
        }

        function borderColor() {
            if (disabled()) return Theme.color.border
            if (on())       return Theme.color.brand
            if (hovered() || pressed()) return Theme.color.borderStrong
            return Theme.color.border
        }

        /* 常态**必须可见** —— Basic 的 ghost 在常态 opacity 0，
         * 那是"悬停才浮出来"的幽灵按钮该有的样子；但一个开关如果不画出来，
         * 就没有任何东西告诉用户"这里可以点"。这条正是新增插槽的理由之一。 */
        function opacity() { return disabled() ? 0.5 : 1 }
    }
}
