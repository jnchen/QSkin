/****************************************************************************
 * QSkin · Quick Design System — Theme / shadcn / slots / SCLabel
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * shadcn/ui 的文字插槽 —— 三套里唯一用 **500 字重**（font-medium）的。
 *
 * link 变体（text 位）的下划线：shadcn 的 link 是
 *     text-primary underline-offset-4 hover:underline
 * M4 写下这一件时用的是 `Text.underline` 在 hover 时打开**近似**，
 * 并记了一句"这是契约的第一个缺口：应该升格为 `control.labelUnderline`
 * 让控件决定，而不是每个主题各自 hardcode"。
 *
 * ⚠ **M30 已经把那个缺口补上了** —— `labelUnderline` 现在是 label 契约的
 * 第二个可选读取字段（完整语义见 `contracts/slots/BasicLabel.qml` 文件头）。
 * 本件的写法随之改成"**声明优先、否则落回自家惯例**"：
 *
 *     control.labelUnderline !== undefined → 以它为准（链接/按钮说了算）
 *     不声明                              → 仍是 text 变体 hover 才画
 *
 * 后半句是**兼容**的那一半：`QSkinButton` 的 text 变体从 M3 起就在 hover 时
 * 画下划线，本件不声明这个字段，所以行为逐像素不变。若把契约写成
 * "bool、默认 false"，那次"补契约"会顺带抹掉这个既有行为。
 *
 * 仍然表达不了的：官方的 `underline-offset-4`（Qt 的 `Text` 没有下划线
 * 偏移量这一项）。这是**已知有损**，不是漏做。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Text {
    id: root

    property var control: null

    text: root.control && root.control.text !== undefined ? root.control.text : ""

    font.family:    Theme.font.family
    font.pixelSize: Theme.font.sm

    /* ★ font-medium(500) —— shadcn 全体按钮统一，不随 variant 变化 */
    font.weight:    Theme.font.weightMedium

    font.underline: d.underline()

    color: d.fg()

    horizontalAlignment: (root.control && root.control.labelAlignment !== undefined)
                         ? root.control.labelAlignment
                         : Text.AlignHCenter

    elide:             Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    renderType:        Text.NativeRendering

    Behavior on color {
        ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
    }

    QtObject {
        id: d

        function variant() {
            return (root.control && root.control.variant !== undefined)
                    ? root.control.variant : "default"
        }
        function isButtonHost() {
            return root.control && root.control.iconSize !== undefined
        }
        function disabled() {
            return root.control ? root.control.enabled === false : false
        }
        function hovered() {
            return root.control ? root.control.hovered === true : false
        }

        function underline() {
            /* M30：**声明优先**。宿主（如 QSkinLink）一旦上报 labelUnderline，
             * 就由它说了算；不声明才落回 shadcn 自家的 text-hover 惯例。
             * 详见文件头 —— 这两半缺一不可。 */
            if (root.control && root.control.labelUnderline !== undefined)
                return root.control.labelUnderline === true
            return variant() === "text" && hovered()
        }

        function fg() {
            if (disabled()) return Theme.color.fgDisabled

            /* ── "default" 的歧义与裁决 ─────────────────────────────
             * shadcn 的 default 按钮是黑色实心（它没有 outline 按钮），
             * 文字该是白；但 Slots.label 的宿主不止按钮 —— 复选框、
             * 下拉选项行也是 default、且底是透明的，白字会隐身。
             * 用鸭子类型区分宿主：iconSize 只有按钮才有（契约惯例，
             * 同 variant !== undefined 的用法）。 */
            function isButtonHost() {
                return root.control && root.control.iconSize !== undefined
            }

            switch (variant()) {
            case "primary":
            case "default": return isButtonHost() ? Theme.color.onBrand
                                                  : Theme.color.fg
            /* danger 文字（菜单项 / 危险链接等透明宿主）用 danger 前景色；
             * 实心危险按钮上的文字才是 onBrand（白）。宿主类型用鸭子
             * 类型判断 —— iconSize 只有按钮有（M3 确立的契约惯例）。 */
            case "danger":  return isButtonHost() ? Theme.color.onBrand
                                                  : Theme.color.danger
            case "ghost":   return Theme.color.fg
            case "text":    return Theme.color.fg   /* text-primary = 近黑 */

            /* ★ M30：四家里的**例外**。shadcn 的 `--primary` 就是近黑
             * （`240 5.9% 10%`），所以它的链接是 `text-primary underline-
             * offset-4 hover:underline` —— **近黑 + hover 下划线**，
             * 不是品牌色。另外三家的链接都是品牌色（见 BasicLabel 的
             * `case "link"`）。契约只要求"这个变体表示链接"，具体画成
             * 什么色由主题回答 —— 这正是插槽存在的意思。 */
            case "link":    return Theme.color.fg

            /* ★ M20 补的一格：outline 宿主的底是**透明**的（shadcn 的
             * outline 按钮 / QSkinToggle 的默认态都是 `border-input
             * bg-background`），文字必须走正文色。
             *
             * 之前它落到下面的 default 分支、被判成"按钮宿主 → onBrand"，
             * 于是在 shadcn 下 QSkinToggle 的文字是**浅底白字，屏幕上几乎
             * 看不见**。这不是猜出来的：M20 的像素核验 .cache/_verify_m20.py
             * 判据 [C] 要求"每个开关格内有文字级深墨"，四家里只有 shadcn
             * 量到 0 个像素，抓图放大后肉眼确认。
             *
             * 契约上的教训：`iconSize !== undefined` 这个鸭子类型标记
             * 从 M3 起被当成"是不是按钮"，但 QSkinToggle / QSkinTag 也声明了
             * iconSize —— 标记已经不唯一了。"是不是实心底"这个事实，
             * 只有"宿主 × 变体"的组合知道，靠代理属性猜迟早会错第二次。
             * 下一批若要根治，应把它升格为契约属性（比如宿主声明
             * `labelOnBrand`），而不是继续加 case。 */
            case "outline": return Theme.color.fg

            /* ★ 兜底改为 fg：未知变体一律按"底是透明的"处理。
             * 两个方向都会错，但要选错得**看得见**的那一边 ——
             * 深字压浅底只是对比度不足，白字压白底是彻底隐身。 */
            default:        return Theme.color.fg
            }
        }
    }
}
