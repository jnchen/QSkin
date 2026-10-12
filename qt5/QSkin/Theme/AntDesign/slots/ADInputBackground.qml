/****************************************************************************
 * QSkin · Quick Design System — Theme / Ant Design / slots / ADInputBackground
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Ant Design 的输入框底板。与 TDesign 的差异：
 *   圆角     6px（radius.md）vs TD 3px
 *   hover    边框 → **brandHover #4096FF**（TD 直接变常态品牌色）
 *   聚焦     边框 → brand #1677FF + 2px 光晕（rgba(5,145,255,10%)）
 *   错误     边框 #FF4D4F + 光晕 #FFF1F0（colorErrorBg）
 *   禁用     底 #F5F5F5 + 边框 #D9D9D9（与 TD 同构）
 *
 * 三态映射结构与 TD 相同 —— 差异全部落在令牌取值上，
 * 这正说明插槽契约切对了位置：结构稳定，数值随主题。
 * 光晕画法沿用 TD 的「外扩 2px 空心矩形」，理由见 TDInputBackground。
 ****************************************************************************/

/* QtQuick **不带版本号**：四角独立半径（topLeftRadius 等）在版本化导入下
 * 不存在 —— 实测 2.15 / 2.16 / 2.17 全报 "is not available"。完整实测与
 * 理由见 COVERAGE.md 第七节「M27 裁决四」；第一个用户是 ADButtonBackground。
 * M30 的输入框底板是第二个用户（分组圆角），同一条。 */
import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    anchors.fill: parent

    Rectangle {
        id: halo

        anchors.fill:    parent
        anchors.margins: -2
        /* 光晕层跟着主体走 —— 不同步会让聚焦环在分组的内侧角上"支出来" */
        readonly property var _haloCorners:
            CornerUtil.corners(d.groupPosition(), Theme.radius.md + 2)

        /* Qt 5.11：_corners 是函数调用属性，5.11 在它返回前
         * 就求值 radius ⇒ ReferenceError。守卫挡不住（读属性就抛）。
         * 正解：自己算一次放进一个 QtObject，后续都从它取。*/
        QtObject { id: _c511_0; property var v: CornerUtil.corners(d.groupPosition(), Theme.radius.md + 2) }
        radius: _c511_0.v ? Math.max(_c511_0.v.tl, _c511_0.v.tr, _c511_0.v.br, _c511_0.v.bl) : 0
        /* Qt 5.15 无四角独立半径（topLeftRadius 等是 Qt 6 独有，且只在
         * 「无版本 import」下才存在 —— 原注释有实测记录）。
         * 降级：主体取四角最大值，再用补角矩形把该直的角填回方形。
         * 已知差异：补角会盖掉一小段 border，而那正是分组按钮与相邻
         * 按钮的接缝；standalone（四角全等）与中段（四角全零）两种
         * 情形与 Qt 6 侧逐像素一致。 */
        Rectangle { visible: _c511_0.v.tl < radius; x: 0; y: 0; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _c511_0.v.tr < radius; x: parent.width - radius; y: 0; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _c511_0.v.br < radius; x: parent.width - radius; y: parent.height - radius; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _c511_0.v.bl < radius; x: 0; y: parent.height - radius; width: radius; height: radius; color: parent.color }

        color:        "transparent"
        border.width: 2
        border.color: d.haloColor()

        visible:  d.showHalo()
        opacity:  d.showHalo() ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    Rectangle {
        id: field

        anchors.fill: parent
        readonly property var _corners: CornerUtil.corners(d.groupPosition(), Theme.radius.md)

        /* Qt 5.11：_corners 是函数调用属性，5.11 在它返回前
         * 就求值 radius ⇒ ReferenceError。守卫挡不住（读属性就抛）。
         * 正解：自己算一次放进一个 QtObject，后续都从它取。*/
        QtObject { id: _c511_1; property var v: CornerUtil.corners(d.groupPosition(), Theme.radius.md) }
        radius: _c511_1.v ? Math.max(_c511_1.v.tl, _c511_1.v.tr, _c511_1.v.br, _c511_1.v.bl) : 0
        /* Qt 5.15 无四角独立半径（topLeftRadius 等是 Qt 6 独有，且只在
         * 「无版本 import」下才存在 —— 原注释有实测记录）。
         * 降级：主体取四角最大值，再用补角矩形把该直的角填回方形。
         * 已知差异：补角会盖掉一小段 border，而那正是分组按钮与相邻
         * 按钮的接缝；standalone（四角全等）与中段（四角全零）两种
         * 情形与 Qt 6 侧逐像素一致。 */
        Rectangle { visible: _c511_1.v.tl < radius; x: 0; y: 0; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _c511_1.v.tr < radius; x: parent.width - radius; y: 0; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _c511_1.v.br < radius; x: parent.width - radius; y: parent.height - radius; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _c511_1.v.bl < radius; x: 0; y: parent.height - radius; width: radius; height: radius; color: parent.color }

        color:        d.bg()
        border.width: 1
        border.color: d.borderColor()

        Behavior on color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    QtObject {
        id: d

        /* M30 · 分组方位。由父项（QSkinInputGroup）上报。
         * 没设 groupPosition 的消费者拿到 "standalone" → 四角全等 →
         * 与本件加这个字段之前**逐字相同**。 */
        function groupPosition() {
            return (root.control && root.control.groupPosition !== undefined)
                    ? root.control.groupPosition : "standalone"
        }

        function disabled() { return root.control ? root.control.enabled === false : false }
        function focused()  { return root.control ? root.control.activeFocus === true : false }
        function hovered()  { return root.control ? root.control.hovered === true : false }
        function error()    { return root.control ? root.control.error === true : false }

        function showHalo() {
            if (disabled()) return false
            return focused() || error()
        }

        function haloColor() {
            return error() ? Theme.color.dangerSubtle : Theme.color.focusHalo
        }

        function bg() {
            if (disabled()) return Theme.color.bgSubtle
            return Theme.color.bgElevated
        }

        function borderColor() {
            if (error())    return Theme.color.danger
            if (disabled()) return Theme.color.borderStrong
            if (focused())  return Theme.color.brand
            if (hovered())  return Theme.color.brandHover   /* ★ hover 用浅一档 */
            return Theme.color.borderStrong
        }
    }
}
