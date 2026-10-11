/****************************************************************************
 * QSkin · Quick Design System — Theme / Arco Design / slots / ACLabel
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Arco Design 的文字插槽。官方 CSS：按钮字重恒 @font-weight-400。
 *
 * 与 Ant 的差异：text 变体的文字是**次强调色 #4E5969**（color-text-2），
 * hover 才升到正文色 —— Ant 的 text 按钮文字是全强度正文色。
 * 另外 Arco 的「加粗」封顶 500（weightSemiBold 已在令牌里降档）。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Text {
    id: root

    property var control: null

    text: root.control && root.control.text !== undefined ? root.control.text : ""

    font.family:    Theme.font.family
    font.pixelSize: Theme.font.sm
    /* ★ Arco 表头 th 用 500（weightSemiBold 已在令牌降档）；
     * "header" 变体由 QSkinTable 伪装上报（M5） */
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
            /* link（M30）：Arco 的 Link 用 `rgb(var(--primary-6))`，
             * 即品牌色，按下退到 brandActive。**不能**复用 text ——
             * Arco 的 text 是非 hover 时的次强调色 #4E5969（见下方），
             * 那正是"看不出是链接"的那一档。 */
            case "link":    return pressed() ? Theme.color.brandActive
                                            : Theme.color.brand
            case "primary":
            /* danger 文字（菜单项 / 危险链接等透明宿主）用 danger 前景色；
             * 实心危险按钮上的文字才是 onBrand（白）。宿主类型用鸭子
             * 类型判断 —— iconSize 只有按钮有（M3 确立的契约惯例）。 */
            case "danger":  return isButtonHost() ? Theme.color.onBrand
                                                  : Theme.color.danger
            case "ghost":   return pressed() ? Theme.color.brandActive
                                : (hovered() ? Theme.color.brand : Theme.color.fg)
            /* ★ text：#4E5969 起步，hover 升到正文色 */
            case "text":    return hovered() || pressed() ? Theme.color.fg
                                                          : Theme.color.fgSecondary
            default:        return pressed() ? Theme.color.fg : Theme.color.fg
            }
        }
    }
}
