/****************************************************************************
 * QSkin · Quick Design System — Theme / AntDesign / slots / ADRadioIndicator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Ant Design 的单选圈 —— **实心策略**：选中时整块填品牌色，圆心是白色的。
 *
 * ── 这份实现被改过一次，原因值得记下来（M20.1）────────────────────────
 * 初版把它写成了**描边策略**（选中时底色不动、只把 1px 描边换成品牌色、
 * 圆心取品牌色），并在文件头用一张表论证"Ant 与 Basic 恰好相反"。
 * 那张表是错的 —— 它描述的是 Ant 的 **wireframe 主题**，不是默认主题。
 *
 * 查 Ant Design 源码 `components/radio/style/index.ts` 的
 * `prepareComponentToken`，默认（非 wireframe）下：
 *
 *     radioColor    = colorWhite      → 圆点颜色：**白**
 *     radioBgColor  = colorPrimary    → 选中时外圈底色：**品牌色**
 *
 * 而 `getRadioBasicStyle` 里 `-checked` 用的是
 * `backgroundColor: radioBgColor`，圆点 `&:after` 用的是
 * `backgroundColor: radioColor`。两行合起来就是"实心蓝 + 白点"——
 * 与 Basic 同策略，不是相反。
 *
 * 教训：**"这家是什么画法"不能靠印象，要去读它的 token。** 一次错误的
 * 反推会写出一份看起来很有说服力的对照表，还带着 token 名字，但整个方向
 * 是反的 —— 静态截图上看不出来（都是个圆圈），只有对着真源码才现形。
 *
 * ── 与 Basic 的实心策略差在哪（这才是这一格必须存在的理由）────────────
 *   圆心直径    Basic 6px   Ant 8px   ← `dotSize: 8` 是官方 token
 *   外圈描边    勾选时 Ant 保留 border（与底色同色，等于无）；
 *               未勾选时 Ant 用 colorBorder(#d9d9d9)，
 *               Basic 用更深的 borderStrong
 *   勾选 + hover Ant 转 colorPrimaryHover（#4096ff）
 *
 * 这三个数/色都是"换一家主题，肉眼就能看出来"的读数，也是主题冒烟测试
 * 用来识别"装上去的到底是不是本家那一份"的签名。
 *
 * 契约三条照旧：只读 control 状态、不改状态、不加交互。
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

    /** 圆心直径 8 —— Ant 官方组件 token `dotSize` / `radioSize` = 8 / 16。 */
    readonly property int dotSize: 8

    Rectangle {
        id: ring

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

        /** radioBgColor：勾选时 = colorPrimary，其余 = colorBgContainer */
        function bg() {
            if (disabled()) return Theme.color.bgSubtle
            if (on())       return hovered() ? Theme.color.brandHover : Theme.color.brand
            return Theme.color.bg
        }

        function borderWidth() { return 1 }

        /** borderColor：勾选时与底色同色（视觉上等于无描边） */
        function borderColor() {
            if (disabled()) return on() ? Theme.color.bgSubtle : Theme.color.border
            if (on())       return hovered() ? Theme.color.brandHover : Theme.color.brand
            /* 未勾选：colorBorder；hover 时转 colorPrimary */
            return hovered() ? Theme.color.brandHover : Theme.color.border
        }

        /** radioColor = colorWhite —— 注意是**反色**，不是品牌色 */
        function dotColor() {
            if (disabled()) return Theme.color.fgDisabled
            return Theme.color.onBrand
        }
    }
}
