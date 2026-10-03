/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicInputBackground
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「background」插槽的输入框版本。
 *
 * 输入框的视觉状态比按钮更微妙，它有一条重要规则：
 *
 *     **容器底色比页面更深（sunken），获得焦点后才提亮。**
 *
 * 这是 Web 表单的通用约定，Qt 的默认控件恰好相反（白底 + 无差别描边），
 * 导致表单在浅色页面上"糊成一片"。这里用 bgSunken 把层级拉开。
 *
 * 三态优先级：error > focus > hover > 常态。
 * 校验失败时无论焦点在哪都要红 —— 用户不该"点一下别处"就看不到错误。
 ****************************************************************************/

/* QtQuick **不带版本号**：四角独立半径（topLeftRadius 等）在版本化导入下
 * 不存在 —— 实测 2.15 / 2.16 / 2.17 全报 "is not available"。完整实测与
 * 理由见 COVERAGE.md 第七节「M27 裁决四」；第一个用户是 BasicButtonBackground。
 * M30 的输入框底板是第二个用户（分组圆角），同一条。 */
import QtQuick 2.15
import QSkin.Foundation 1.0

Rectangle {
    id: root

    property var control: null

    anchors.fill: parent

    /* M30：分组时四角不同，不能用 `radius`（它四角统一）。
     * 方位由父项（QSkinInputGroup）上报，映射下沉在 CornerUtil.corners。
     * 没设 groupPosition 的消费者读到 "standalone" → 四角全等 →
     * 与本件加这个字段之前**逐字相同**。 */
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
    border.width: 1
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

        /* M30 · 分组方位。由父项（QSkinInputGroup）上报 —— 本件不自己数兄弟。
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

        function opacity() { return disabled() ? 0.6 : 1 }

        function bg() {
            if (disabled()) return Theme.color.bgSubtle
            /* 常态下沉，聚焦提亮 —— 让表单在浅色页面上有层次 */
            return focused() ? Theme.color.bg : Theme.color.bgSunken
        }

        function borderColor() {
            if (error())    return Theme.color.danger
            if (disabled()) return Theme.color.border
            if (focused())  return Theme.color.brand
            if (hovered())  return Theme.color.borderStrong
            return Theme.color.border
        }
    }
}
