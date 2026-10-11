/****************************************************************************
 * QSkin · Quick Design System — Theme / TDesign / slots / TDLabel
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * TDesign 的文字插槽。两个与 Basic 不同的点：
 *
 *   1. **字重恒为 400。**
 *      TDesign 按钮统一用 --td-font-body-medium（400），主按钮的白字也不加粗。
 *      Basic 会给 primary / danger 加 SemiBold —— 那是中性主题自己的选择，
 *      不是跨设计语言的通例。这是「字重该不该跟 variant 走」的典型分歧，
 *      所以 label 必须单独成槽，否则主题作者只能去改控件代码。
 *
 *   2. **默认按钮 hover 时文字变品牌色。**
 *      这是 TDesign 默认按钮 hover 的主要表达（底色不动、描边和文字变蓝）。
 *      Basic 的 label 只看 variant，不看 hovered，做不出这个效果。
 *
 * 契约：只读 control（variant / enabled / hovered / text / labelAlignment）。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Text {
    id: root

    property var control: null

    text: root.control && root.control.text !== undefined ? root.control.text : ""

    font.family:    Theme.font.family
    font.pixelSize: Theme.font.sm

    /* ★ TDesign：按钮一律 400；唯一例外是表头（TDesign 表格 th 用 600）。
     * "header" 变体由 QSkinTable 的表头单元伪装上报（M5 契约扩展）。 */
    font.weight:    (root.control && root.control.variant === "header")
                    ? Theme.font.weightSemiBold : Theme.font.weightRegular

    /* M30：下划线走契约读取字段。不声明 → 不画（与 M3 以来一致）。
     * 字段的三态语义见 contracts/slots/BasicLabel.qml 文件头。 */
    font.underline: d.underline()

    color: d.fg()

    /* 与 BasicLabel 一致：默认居中（按钮用），
     * 但允许宿主通过 labelAlignment 覆盖（下拉框当前项要左对齐）。 */
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

        /** M30：下划线只在宿主**明确上报**时才画 —— 三态见文件头。 */
        function underline() {
            return (root.control && root.control.labelUnderline !== undefined)
                    ? root.control.labelUnderline === true : false
        }

        function fg() {
            if (disabled()) return Theme.color.fgDisabled

            switch (variant()) {
            /* link（M30）：TDesign 的 Link `theme="primary"` 用
             * `--td-text-color-brand`。它的 ghost / text 恰好也是品牌色，
             * 但那是**按钮**语义；链接单独成档，是为了让以后"链接与文字
             * 按钮要能分别换色"这件事有地方可改。 */
            case "link":    return hovered() ? Theme.color.brandHover
                                             : Theme.color.brand
            case "primary":
            /* danger 文字（菜单项 / 危险链接等透明宿主）用 danger 前景色；
             * 实心危险按钮上的文字才是 onBrand（白）。宿主类型用鸭子
             * 类型判断 —— iconSize 只有按钮有（M3 确立的契约惯例）。 */
            case "danger":  return isButtonHost() ? Theme.color.onBrand
                                                  : Theme.color.danger
            case "ghost":   return hovered() ? Theme.color.brandHover : Theme.color.brand
            case "text":    return hovered() ? Theme.color.brandHover : Theme.color.brand

            /* ★ 默认按钮 hover → 文字变品牌色（--td-text-color-brand） */
            default:        return hovered() ? Theme.color.brand : Theme.color.fg
            }
        }
    }
}
