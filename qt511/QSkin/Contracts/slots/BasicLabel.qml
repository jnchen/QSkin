/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicLabel
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「label」插槽的 Basic 默认实现。
 *
 * 这是五个插槽里最容易被忽略、但跨设计语言差异最大的一个：
 *   TDesign / Ant：正文 14px，字重 400，主按钮 500
 *   shadcn：       正文 14px，字重 500，按钮 600
 * 差异只在字重和颜色，逻辑一行没变 —— 这正是 label 值得单独成槽的原因。
 *
 * 契约提醒：只读 control 的状态，不改状态、不加交互。
 *
 * ── M30 补上的第二个可选读取字段：`labelUnderline` ──────────────────────
 * M4 记下过一个缺口：「label 无下划线语义，shadcn 的 link 变体只能靠
 * hover 时的 `Text.underline` 近似」。M30 给 `QSkinLink` 补链接语义时把它
 * 了结了 —— 与 `labelAlignment` 同一手法：**宿主上报、主题读取**，
 * 不声明就保持本主题原有的样子。
 *
 *     control.labelUnderline === true/false → 以它为准
 *     control.labelUnderline === undefined  → 本主题自己决定
 *
 * 三态（而不是一个 bool）的理由：`QSkinButton` 的 text 变体在 shadcn 下
 * **本来就**会在 hover 时画下划线。若把契约写成 bool、默认 false，
 * 那个已有行为会被这里静默抹掉 —— 一次"补契约"顺带改掉了四个主题的
 * 既有像素，是最难查的一类回归。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Text {
    id: root

    /* 由宿主控件在 Loader.onLoaded 里注入。
     * 刻意声明为 var 而非 Item：插槽要读 control.variant / control.checked
     * 这类"宿主自定义"的状态，声明成 Item 会让 qmllint 按 QQuickItem
     * 做成员检查并报 Member not found。插槽契约是鸭子类型，就该用 var。 */
    property var control: null

    text: root.control && root.control.text !== undefined ? root.control.text : ""

    font.family:    Theme.font.family
    font.pixelSize: Theme.font.sm
    font.weight:    d.isEmphasisVariant() ? Theme.font.weightSemiBold
                                          : Theme.font.weightRegular

    color: d.fg()

    /* 下划线走**契约读取字段**（见文件头）。不声明 → Basic 不画下划线，
     * 与 M4 以来逐像素一致。 */
    font.underline: (root.control && root.control.labelUnderline !== undefined)
                    ? root.control.labelUnderline : false

    /* 对齐默认居中，因为第一个使用者是按钮。
     * 但 label 是**共用**插槽：下拉框的当前项、菜单项都要左对齐。
     * 所以允许宿主通过可选的 labelAlignment 覆盖 —— 不声明就保持原样，
     * 已有的按钮渲染结果一个像素都不会变。
     * （插槽读宿主状态是契约允许的，见 Slots.qml 契约第 2 条。） */
    horizontalAlignment: (root.control && root.control.labelAlignment !== undefined)
                         ? root.control.labelAlignment
                         : Text.AlignHCenter

    elide:             Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    renderType:        Text.NativeRendering

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

        /** 实心按钮（primary / danger）与表头（header，M5 起 QSkinTable
         * 伪装上报）需要更高字重 */
        function isEmphasisVariant() {
            var v = variant()
            return v === "primary" || v === "danger" || v === "header"
        }

        function fg() {
            if (disabled()) return Theme.color.fgDisabled
            switch (variant()) {
            case "primary": return Theme.color.onBrand
            /* danger 文字（菜单项 / 危险链接等透明宿主）用 danger 前景色；
             * 实心危险按钮上的文字才是 onBrand（白）。宿主类型用鸭子
             * 类型判断 —— iconSize 只有按钮有（M3 确立的契约惯例）。 */
            case "danger":  return isButtonHost() ? Theme.color.onBrand
                                                  : Theme.color.danger
            case "ghost":   return Theme.color.brand
            case "text":    return Theme.color.brand
            /* link（M30）：四家参照里的链接**都是品牌色**（TDesign 的
             * theme="primary"、Ant 的 colorLink、Arco 的 primary-6、
             * shadcn 的 text-primary）。与 ghost / text 分开写是有必要的 ——
             * 那两个在中性主题里恰好也是品牌色，但在 Ant / Arco 的插槽里
             * 是"hover 才变色的正文色"（见 ADLabel / ACLabel）。
             * 链接要求的是"不 hover 也认得出是链接"，那是另一条语义。 */
            case "link":    return Theme.color.brand
            /* muted：弱前景。M10 起被 Breadcrumb 的"非当前项"与 Steps 的
             * "未开始步骤"使用 —— 这两处要的是"存在但不抢眼"，
             * 与 ghost 的"品牌色可点"是两种语义，所以必须是独立取值。 */
            case "muted":   return Theme.color.fgMuted
            default:        return Theme.color.fg
            }
        }
    }
}
