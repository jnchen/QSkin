/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinLabel
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 独立文本标签。表单里那个"字段名"就是它。
 *
 * ── 它存在的理由是"两段文字必须一起换肤"────────────────────────────────
 * 项目里已经有一个共用的文字插槽（`Slots.label`）：按钮的文字、复选框
 * 的文字、下拉当前项的文字，全从它出来。若表单的字段名自己写一个
 * `Text { font.pixelSize: 14 }`，那就出现了**第二处定义"标签长什么样"**
 * 的地方 —— 换肤时它会留下，成为页面上唯一一处没变的字。
 *
 * 所以 QSkinLabel 的核心是：它是 `Slots.label` 的**宿主**，不是它的替代品。
 * `smoke_m20_theme.qml` 就守着这一条（"给 QSkinLabel 装上的必须与按钮上的
 * 是同一个 Component"）。
 *
 * ── 三件只有独立标签才需要、而按钮上的文字不需要的东西 ───────────────────
 *   1. 默认**左对齐**。插槽的默认是对齐居中（第一个使用者是按钮）。
 *      宿主通过 `labelAlignment` 覆盖它 —— 契约第 2 条允许宿主上报状态。
 *   2. **必填标记**。它不是文字：`*` 的字形在字体回退链之间宽窄不一，
 *      而且它是要被"读屏软件跳过、右侧文字接管"的东西。所以画成矢量
 *      （三条辐条），并且 `Accessible.ignored: true`。
 *   3. `Accessible.role: StaticText`。Text 的默认角色是 StaticText，
 *      但这里显式写出来 —— 标签是**可被关联到字段**的东西，将来要接
 *      `Accessible.description` 时，角色必须先对。
 *
 * ── 没有 elide ──────────────────────────────────────────────────────────
 * 插槽的实现是一个 `Text`，宽度是它自己的隐式宽（主题作者不欠宿主一个
 * "按容器宽度折行"的行为）。所以标签不省略号，而由**布局**决定它有多宽。
 * 要截断就给它一个窄容器 —— 那本来就是调用方的事。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import QSkin.Foundation 1.0

QSkinRow {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    property string text: ""

    /** 必填。只影响**样子**（画一个星号），不参与校验 ——
     *  校验是 QSkinForm / QSkinFormItem 的职责，一个标签没有能力阻止
     *  也不该假装能阻止表单提交。 */
    property bool required: false

    /* ══════════════════════ 外观 ══════════════════════ */

    /** default | muted。muted 用于"（可选）""示例：…"这类弱提示。 */
    property string variant: "default"

    /** 强制左对齐：插槽默认居中（那是给按钮的）。 */
    readonly property int labelAlignment: Text.AlignLeft

    /* 尺寸 */

    gap: Theme.space.xxs
    align: "center"

    implicitHeight: Math.max(root.markerSize, labelLoader.implicitHeight)

    Accessible.role: Accessible.StaticText
    Accessible.name: root.text

    /* ══════════════════════ 必填标记 ══════════════════════ */

    /** 标记方框边长。与字号无关 —— 它是记号，不是文字。 */
    readonly property int markerSize: 10

    Shape {
        // CurveRenderer 才有原生抗锯齿（见 README「图标锯齿」）

        Layout.alignment: Qt.AlignVCenter
        /* 尺寸走 `Layout.preferred*`，**不要**写 implicitWidth/Height：
         * `Shape` 的隐式尺寸是它自己按路径包围盒算出来的（实测这颗画在
         * 10×10 坐标空间里的星号量出来是 8.75 × 9.2），显式绑一个
         * `implicitWidth: root.markerSize` 会被它盖掉 —— 于是
         * `markerSize` 变成一个**说了不算**的数：属性读 10、布局按 8.75 排。
         *
         * 抓出这个不一致的是冒烟测试里那条与字体无关的恒等式
         * 「有标记的宽 − 没标记的宽 === markerSize + gap」（差 1px 红）。
         * 修法是让布局认 `Layout.preferredWidth/Height` —— 记号画多大由
         * 路径决定，它**占多宽**由 markerSize 决定，两件事分开。 */
        Layout.preferredWidth:  root.markerSize
        Layout.preferredHeight: root.markerSize

        /* 只有必填才画。**这一行曾经被变异测试改坏过一次**（`visible: true`
         * 被留在源码里，见 README「十一、坑」第 12 条）—— 症状是本项目最
         * 熟悉的那种：`required` 属性读出来完全正确，而屏幕上**每个标签
         * 都带着一颗红星**。抓出它的是 smoke_m20.qml 里那条与字体无关的
         * 恒等式「有标记的宽 − 没标记的宽 === markerSize + gap」：
         * 用户永远看到标记 → 差值是 0 而不是 12 → 红。 */
        visible: root.required

        /* 读屏软件应当跳过它 —— 它会念成"星号"，而"必填"这件事
         * 由右边的文字与表单自己的校验去表达。 */
        Accessible.ignored: true

        /* 三条辐条（竖直 + 两条 60°）—— 画出来的星号。
         * 用矢量而不是 U+002A：字体回退链上星号的大小与基线各不相同，
         * 而这个记号出现在**每一个必填字段**上，摆歪一个就是一片。 */
        ShapePath {
            strokeWidth: 1.6
            strokeColor: Theme.color.danger
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            startX: 5; startY: 1.6
            PathLine { x: 5; y: 8.4 }
        }
        ShapePath {
            strokeWidth: 1.6
            strokeColor: Theme.color.danger
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            startX: 2.05; startY: 3.3
            PathLine { x: 7.95; y: 6.7 }
        }
        ShapePath {
            strokeWidth: 1.6
            strokeColor: Theme.color.danger
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            startX: 2.05; startY: 6.7
            PathLine { x: 7.95; y: 3.3 }
        }
    }

    /* ══════════════════════ 文字 ══════════════════════ */

    Loader {
        id: labelLoader

        Layout.alignment: Qt.AlignVCenter
        sourceComponent: Slots.label

        Binding {
            target: labelLoader.item
            property: "control"
            value: root
            when: labelLoader.item !== null
        }
    }
}
