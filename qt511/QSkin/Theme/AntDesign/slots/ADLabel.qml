/****************************************************************************
 * QSkin · Quick Design System — Theme / Ant Design / slots / ADLabel
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Ant Design 的文字插槽。
 *
 * 与 TDesign 的差异：
 *   1. 字重同样恒 400 —— Ant 主按钮白字也不加粗（与 TD 一致，佐证惯例）。
 *   2. 默认按钮 hover 文字 → **brandHover**（#4096FF），
 *      按下 → brandActive（#0958D9），比 TD 多一档按下色。
 *   3. text 变体 hover **不改文字色**（底色去表达），这是 Ant 与 TD
 *      在 text 按钮上的根本分歧：TD 变蓝、Ant 只浮底。
 *   4. 禁用色 #00000040（colorTextQuaternary 25%），比 TD 的 26% 略浅。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Text {
    id: root

    property var control: null

    text: root.control && root.control.text !== undefined ? root.control.text : ""

    font.family:    Theme.font.family
    font.pixelSize: Theme.font.sm
    /* ★ Ant Design 表头 th 用 600；"header" 变体由 QSkinTable 伪装上报（M5） */
    font.weight:    (root.control && root.control.variant === "header")
                    ? Theme.font.weightSemiBold : Theme.font.weightRegular

    /* M30：下划线走契约读取字段。不声明 → 不画（与 M3 以来一致）。
     * 字段的三态语义见 contracts/slots/BasicLabel.qml 文件头。 */
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
        function pressed() {
            return root.control ? root.control.pressed === true : false
        }

        /** M30：下划线只在宿主**明确上报**时才画 —— 三态见文件头。 */
        function underline() {
            return (root.control && root.control.labelUnderline !== undefined)
                    ? root.control.labelUnderline === true : false
        }

        function fg() {
            if (disabled()) return Theme.color.fgDisabled

            switch (variant()) {
            /* link（M30）：Ant 的链接是 `colorLink`（= #1677FF，品牌色），
             * 与它自家 `Button type="link"` 同色。**不能**复用 ghost ——
             * Ant 的 ghost 在非 hover 时是正文色（下方那一条），
             * 而链接要求"不 hover 也认得出是链接"。 */
            case "link":    return pressed() ? Theme.color.brandActive
                                : (hovered() ? Theme.color.brandHover
                                             : Theme.color.brand)
            case "primary":
            /* danger 文字（菜单项 / 危险链接等透明宿主）用 danger 前景色；
             * 实心危险按钮上的文字才是 onBrand（白）。宿主类型用鸭子
             * 类型判断 —— iconSize 只有按钮有（M3 确立的契约惯例）。 */
            case "danger":  return isButtonHost() ? Theme.color.onBrand
                                                  : Theme.color.danger
            case "ghost":   return pressed() ? Theme.color.brandActive
                                : (hovered() ? Theme.color.brandHover : Theme.color.fg)
            case "text":    return Theme.color.fg   /* ★ hover 不改文字色 */
            default:        return pressed() ? Theme.color.brandActive
                                : (hovered() ? Theme.color.brandHover : Theme.color.fg)
            }
        }
    }
}
