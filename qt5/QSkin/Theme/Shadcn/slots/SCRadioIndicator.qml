/****************************************************************************
 * QSkin · Quick Design System — Theme / Shadcn / slots / SCRadioIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * shadcn 的单选圈 —— **五家里唯一走描边策略的那一家**，圆点也最大。
 *
 * ── 更正（M20.1）：这张表原来写的是"Ant 与 shadcn 都是描边"────────────
 * 查过 Ant 的源码之后确认 Ant 是**实心**（`radioBgColor = colorPrimary`
 * + 白点），初版把它误判成了它那个非默认的 wireframe 主题。于是这张
 * 对照表要重写 —— 改成"五家的策略与圆点"，因为少一家都会让人以为
 * 这里只有两家可选：
 *
 *     主题        策略      圆心      依据
 *     Basic      实心      6        本项目自己的默认牌子
 *     TDesign    实心      8        icon 默认 'circle'＝填充型；@radio-dot-size = @radio-size/2
 *     Ant        实心      8        radioBgColor = colorPrimary + radioColor = colorWhite
 *     Arco       实心      5.6      mask 底色 = brand；::after 白点 scale(0.4)，(16−2)×0.4
 *     shadcn     描边      10       border-primary + fill-primary 圆点，h-2.5 = 10px
 *
 * 于是这一格的存在理由是**双重的**：策略（描边）+ 直径（10，全场最大）。
 * 而 Arco 之所以能复用 Basic，也因为它的 5.6 与 Basic 的 6 只差 0.4px——
 * "能不能复用"要拿这两个数去判，不能凭印象。
 *
 * 契约三条照旧。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    implicitWidth:  16
    implicitHeight: 16
    width:  implicitWidth
    height: implicitHeight

    /** 圆心直径 10 —— shadcn 的 `h-2.5 w-2.5`。 */
    readonly property int dotSize: 10

    Rectangle {
        anchors.fill: parent
        radius: width / 2

        color:        Theme.color.bg
        border.width: 1
        border.color: d.borderColor()
        opacity:      d.opacity()

        Behavior on border.color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width:  root.dotSize
        height: root.dotSize
        radius: width / 2

        visible: d.on()
        color:   d.dotColor()
        opacity: d.opacity()

        Behavior on color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    QtObject {
        id: d

        function on()       { return root.control ? root.control.checked === true : false }
        function disabled() { return root.control ? root.control.enabled === false : false }
        function hovered()  { return root.control ? root.control.hovered === true : false }

        /* shadcn 的禁用态是**降透明度**（`disabled:opacity-50`），
         * 不是换令牌 —— 与 TDesign 相反（那个见 TDButtonBackground 的注释）。
         * 同一件事两种做法，正是"映射关系差异"的又一个样本。 */
        function opacity() { return disabled() ? 0.5 : 1 }

        function borderColor() {
            if (disabled()) return Theme.color.border
            if (on())       return Theme.color.brand
            if (hovered())  return Theme.color.borderStrong
            return Theme.color.border
        }

        function dotColor() {
            if (disabled()) return Theme.color.fgMuted
            return Theme.color.brand
        }
    }
}
