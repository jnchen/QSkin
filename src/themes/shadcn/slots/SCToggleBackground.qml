/****************************************************************************
 * QSkin · Quick Design System — Theme / Shadcn / slots / SCToggleBackground
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * shadcn 的开关底板 —— 四家主题里**唯一**需要覆盖这一格的一份。
 *
 *   ┌──────────┬──────────────────────────┬──────────────────────────────┐
 *   │          │ Basic（四家共用）         │ shadcn                       │
 *   ├──────────┼──────────────────────────┼──────────────────────────────┤
 *   │ 开态底色 │ 品牌浅底（brandSubtle）   │ **中性灰**（bgSunken）       │
 *   │ 开态描边 │ 品牌色                    │ 无（描边只在 outline 常态）  │
 *   │ 常态描边 │ border                    │ border（更浅一档，见下）     │
 *   └──────────┴──────────────────────────┴──────────────────────────────┘
 *
 * 第一行就是它必须单独成文件的原因，而且它是一个**反直觉**的选择：
 * shadcn 的开关打开时**不用品牌色**（`data-[state=on]:bg-accent`）——
 * 开与关是"两种灰"，不是"灰与蓝"。理由是 shadcn 把品牌色留给
 * "主要动作"，而开关是一个中性的状态切换。
 *
 * ── 一行更正：第一行在 shadcn 自己身上**量不出来** ──────────────────────
 * 三行里**只有第二行是可观测的**，这是写这一格的冒烟测试时才算出来的：
 * shadcn 没有品牌色（`tokens.js` 里 brand 一族填的是灰阶），于是
 *         brandSubtle = "#F4F4F5"   // accent = muted
 *         bgSunken    = "#F4F4F5"   // muted zinc-100
 * 是**同一个数**。所以第一行写在这里是**设计意图**，不是一个测得出的差别：
 * 把下面 `bg()` 里那行换成 `brandSubtle`，屏幕上、截图上、属性上都一模一样
 * （变异测试实测 MISSED，而它报得**对**）。
 *
 * 真正把这一格与 Basic 分开的是**第二行**：Basic 认为"选中的东西该有轮廓"，
 * 开态给一圈品牌色（`borderColor` 里的 `Theme.color.brand`）；这一份把轮廓
 * 让给**常态** —— 关着的时候才需要边框告诉用户"这里有个可点的框"，
 * 开着的时候底色已经说清了。`tests/smoke_m20_theme.qml` 的 [3] 量的就是
 * 这条轴（开态描边必须透明 + 常态描边必须正在用 `border` 那一档色）。
 *
 * 上面这段留在这里的原因：一个**量不出来**的差别，最容易被写成一条永远
 * 绿的断言 —— 而那种断言比没有断言更糟，它让人以为这里有守卫。
 * 写进来源文件，是为了下次有人来核对这张表时不必再算一遍。
 *
 * 这也是本项目里第一次出现"同一格插槽，两家给出方向相反的答案"。
 * 它比任何论证都更能说明插槽该切在哪 —— 如果这一格不存在，
 * shadcn 的开关就只能跟着别人变成蓝的。
 *
 * 契约三条照旧：只读 control 状态、不改状态、不加交互。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Rectangle {
    id: root

    property var control: null

    anchors.fill: parent

    radius: Theme.radius.md

    color:        d.bg()
    border.width: d.borderWidth()
    border.color: d.borderColor()
    opacity:      d.opacity()

    Behavior on color {
        ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
    }

    QtObject {
        id: d

        function variant() {
            return (root.control && root.control.variant !== undefined)
                    ? root.control.variant : "outline"
        }
        function on()       { return root.control ? root.control.checked === true : false }
        function pressed()  { return root.control ? root.control.pressed === true : false }
        function hovered()  { return root.control ? root.control.hovered === true : false }
        function disabled() { return root.control ? root.control.enabled === false : false }

        function bg() {
            if (on())      return Theme.color.bgSunken
            if (pressed()) return Theme.color.bgSubtle
            if (hovered()) return Theme.color.bgSubtle
            return "transparent"
        }

        /* outline 常态有描边、开态**没有**（底色已经够说清）；
         * default 变体常态无描边。与 Basic 刚好相反 —— 那一份是
         * "开态才有描边"。两家都不算错，只是各自把轮廓放在了自己
         * 认为该有轮廓的那一档上。 */
        function borderWidth() {
            return variant() === "outline" ? 1 : 0
        }

        function borderColor() {
            if (disabled()) return Theme.color.border
            if (on())       return "transparent"
            if (hovered() || pressed()) return Theme.color.borderStrong
            return Theme.color.border
        }

        function opacity() { return disabled() ? 0.5 : 1 }
    }
}
