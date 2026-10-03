/****************************************************************************
 * QSkin · Quick Design System — Theme / shadcn / slots / SCInputBackground
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * shadcn/ui 的输入框底板 —— **无底、纯描边**，与 Arco 的灰底正好相反：
 *
 *   常态   transparent + 1px zinc-200（input 边框）
 *   聚焦   边框不变，外围 ring-2 zinc-400 + 2px offset（focus-visible）
 *   错误   描边变 destructive + ring 变红
 *   禁用   底色 muted + 半透明
 *
 * ring-offset（光晕与控件之间留 2px 空隙）是 shadcn 焦点环的签名 ——
 * 由 size.focusOffset 驱动，FocusRing 消费同一个令牌，输入框内做的是
 * 同款近似（光晕矩形外扩 offset+ring，内缩 offset 处留空隙）。
 ****************************************************************************/

/* QtQuick **不带版本号**：四角独立半径（topLeftRadius 等）在版本化导入下
 * 不存在 —— 实测 2.15 / 2.16 / 2.17 全报 "is not available"。完整实测与
 * 理由见 COVERAGE.md 第七节「M27 裁决四」；第一个用户是 SCButtonBackground。
 * M30 的输入框底板是第二个用户（分组圆角），同一条。 */
import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    anchors.fill: parent

    /* ── ring：外扩 offset+ring 宽，中间挖出 offset 的空隙 ──
     * 两个空心矩形叠加：外层画 ring 色，内层用 bg 挖掉。 */
    Rectangle {
        id: ringOuter

        anchors.fill:    parent
        anchors.margins: -(Theme.size.focusRing + Theme.size.focusOffset)
        /* 光晕层跟着主体走 —— 不同步会让聚焦环在分组的内侧角上"支出来" */
        readonly property var _haloCorners:
            CornerUtil.corners(d.groupPosition(),
                    Theme.radius.md + Theme.size.focusRing + Theme.size.focusOffset)

        radius: Math.max(_haloCorners.tl, _haloCorners.tr, _haloCorners.br, _haloCorners.bl)
        /* Qt 5.15 无四角独立半径（topLeftRadius 等是 Qt 6 独有，且只在
         * 「无版本 import」下才存在 —— 原注释有实测记录）。
         * 降级：主体取四角最大值，再用补角矩形把该直的角填回方形。
         * 已知差异：补角会盖掉一小段 border，而那正是分组按钮与相邻
         * 按钮的接缝；standalone（四角全等）与中段（四角全零）两种
         * 情形与 Qt 6 侧逐像素一致。 */
        Rectangle { visible: _haloCorners.tl < radius; x: 0; y: 0; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _haloCorners.tr < radius; x: parent.width - radius; y: 0; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _haloCorners.br < radius; x: parent.width - radius; y: parent.height - radius; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _haloCorners.bl < radius; x: 0; y: parent.height - radius; width: radius; height: radius; color: parent.color }

        color:        "transparent"
        border.width: Theme.size.focusRing
        border.color: d.ringColor()

        visible:  d.showRing()
        opacity:  d.showRing() ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    /* offset 空隙层：把 ring 与控件隔开 */
    Rectangle {
        anchors.fill:    parent
        anchors.margins: -Theme.size.focusOffset
        radius:          Theme.radius.md + Theme.size.focusOffset

        color:   Theme.color.bg
        visible: d.showRing()

        Behavior on color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    Rectangle {
        id: field

        anchors.fill: parent
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
        function error()    { return root.control ? root.control.error === true : false }

        function showRing() {
            if (disabled()) return false
            return focused() || error()
        }

        function ringColor() {
            return error() ? Theme.color.danger : Theme.color.focusHalo
        }

        /* ★ 无底（transparent）：shadcn 输入框靠描边划边界 */
        function bg() {
            if (disabled()) return Theme.color.bgSunken
            return "transparent"
        }

        /* 聚焦时边框保持原色 —— 表达全部交给 ring（shadcn 的做法） */
        function borderColor() {
            if (error())    return Theme.color.danger
            if (disabled()) return Theme.color.border
            return Theme.color.border
        }
    }
}
