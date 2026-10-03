/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinBadge
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 徽标 —— 挂在别的东西角上的一个数字或小圆点。
 *
 * ── 它和 Tag 的区别（很容易混）────────────────────────────────────────
 *   Tag    是内容本身（"已上线"），参与者是**读者**，占正常布局流。
 *   Badge  是内容的**附属**（未读数 5），参与者是**注意力**，通常悬浮
 *          在宿主右上角，不占布局流。
 * 所以 Badge 是唯一一个默认"溢出到自己宿主外面"的控件 —— 它内部用
 * 负偏移把标记推到角上，宿主容器不需要为它留空间。
 *
 * ── 怎么挂（推荐用 anchorTo）───────────────────────────────────────────
 * 把要挂的宿主控件赋给 anchorTo 即可，位置自己算：
 *
 *     QSkinButton { id: inbox; text: "收件箱" }
 *     QSkinBadge  { anchorTo: inbox; value: 5 }
 *
 * **不要**手写 x/y 三角函数 —— 那是这批视觉验证中真实踩过的坑：
 * 手算偏移极易让徽标压住宿主文字、或撞上相邻控件，而且宿主尺寸一变
 * 就要重算。anchorTo 把这件事收进控件里，宿主换尺寸也不用改调用方。
 *
 * ── value 的三种形态 ──────────────────────────────────────────────────
 *   正整数  显示数字，超过 max 显示 "max+"
 *   0       默认隐藏（Badge 的存在意义是"有东西要提醒"，
 *           0 条提醒没有意义）。设 showZero: true 可以强制显示。
 *   dot     只显示小圆点，不显示数字 —— 用在"有几个不重要，
 *           总之有待处理"的场景
 *
 * 这些是**语义**判断，属于契约层，所以写在控件里而不是槽里。
 * 插槽只回答"这个标记长什么样、什么颜色"。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 取值 ══════════════════════ */

    /** 要展示的数量 */
    property int value: 0

    /** 封顶值：value > max 时显示 "max+" */
    property int max: 99

    /** 只显示圆点，不显示数字 */
    property bool dot: false

    /** value 为 0 时是否仍然显示 */
    property bool showZero: false

    /** 是否显示（总开关）。业务常用绑定：`visible: unread > 0 || hasError` */
    property bool show: true

    /* ══════════════════════ 挂载 ══════════════════════
     *
     * 把宿主控件赋给 anchorTo，徽标自动贴到它的右上角外侧。
     * 见文件头的用法说明 —— 不要手写 x/y。 */

    /** 要挂靠的宿主控件（通常是 QSkinButton）。null = 不挂靠，按普通 Item 摆放。 */
    property Item anchorTo: null

    /** 挂靠方向：topRight | topLeft | bottomRight | bottomLeft */
    property string anchorCorner: "topRight"

    /** 挂靠时相对角落的外扩量。默认把徽标中心压在宿主角上。 */
    property int anchorOffsetX: 0
    property int anchorOffsetY: 0

    /** 挂靠时用宿主尺寸自动定位。
     *
     *  ── 重要前提：徽标不能是 Layout 的直接子项 ──
     *  anchorTo 写的是 x / y，而 QtQuick.Layouts 会**接管**子项的
     *  x / y（由 Layout 重新摆位）。所以下面这条绑在 QSkinRow /
     *  QSkinColumn / QSkinGrid 的直接子项上是无效的 —— 会被 Layout 覆盖。
     *
     *  两种正确用法：
     *    ① 徽标与宿主放平级，整体再被 Layout 摆位（徽标自己不受摆布）；
     *    ② 给徽标套一个 Item 当容器（容器进 Layout，徽标在容器内自由定位）。
     *
     *  推荐 ①，因为它不需要额外容器，也就没有容器裁剪徽标的问题。 */
    Binding {
        target: root
        property: "x"
        when: root.anchorTo !== null
        value: {
            var h = root.anchorTo
            if (!h) return root.x
            var half = root.width / 2
            switch (root.anchorCorner) {
            case "topLeft":
            case "bottomLeft":  return h.x - half + root.anchorOffsetX
            default:            return h.x + h.width - half + root.anchorOffsetX
            }
        }
    }

    Binding {
        target: root
        property: "y"
        when: root.anchorTo !== null
        value: {
            var h = root.anchorTo
            if (!h) return root.y
            var half = root.height / 2
            switch (root.anchorCorner) {
            case "bottomLeft":
            case "bottomRight": return h.y + h.height - half + root.anchorOffsetY
            default:            return h.y - half + root.anchorOffsetY
            }
        }
    }

    /** 挂靠时把自身层级提到宿主之上 —— 否则会被后声明的兄弟盖住。 */
    z: root.anchorTo !== null ? 10 : 0

    /* ══════════════════════ 外观 ══════════════════════ */

    /** default | success | warning | info —— 决定标记底色 */
    property string status: "default"

    /** 圆点模式的直径。默认跟着徽标高度走 —— 圆点与数字徽标挂在
     *  同一个角上，两者大小应当同一档次，否则并排看会一胖一瘦。 */
    property int dotSize: root.badgeHeight - 4      /* 16 */

    /* ══════════════════════ 派生 ══════════════════════ */

    /** 最终要显示的文本。空串 = 不显示文字（dot 模式或应隐藏）。 */
    readonly property string text: root._computeText()

    /** 最终是否可见 —— 所有隐藏条件在这里收口 */
    readonly property bool effectiveVisible:
        root.show && (root.dot || root.value > 0 || (root.showZero && root.value === 0))

    /* ══════════════════════ 尺寸 ══════════════════════
     *
     * Badge 的尺寸有个特点：**至少要有一个数字的直径**。
     * 只有 1 位数字时是正圆，2~3 位时变成胶囊（左右加宽）。
     * 所以高度固定、宽度由内容撑。
     *
     * 高度取 iconMd(20) 而不是 iconSm(16)：16px 高度配 12px 字号时，
     * 数字的上下缘几乎顶到胶囊边缘（可用空间只剩 4px），视觉上发闷、
     * 像被裁过。20px 给到 8px 的呼吸空间，这也是各设计系统的通行值。 */

    readonly property int badgeHeight: Theme.size.iconMd      /* 20 */

    implicitWidth:  root.dot ? root.dotSize : badge.implicitWidth
    implicitHeight: root.dot ? root.dotSize : root.badgeHeight

    width:  implicitWidth
    height: implicitHeight

    visible: root.effectiveVisible

    Accessible.role: Accessible.StaticText
    Accessible.name: root.dot ? qsTr("有新的提醒") : qsTr("%1 条未读").arg(root.text)
    Accessible.ignored: !root.effectiveVisible

    /* ══════════════════════ 视觉 ══════════════════════
     *
     * 用 QSkinRow + label 插槽组一个"标记胶囊" —— 复用方式与 Tag 完全一致。
     * 数字的字体由主题的 label 插槽决定，Badge 不自带排版。 */

    QSkinRow {
        id: badge

        visible: !root.dot
        anchors.fill: parent
        gap: 0
        padding: 0
        align: "center"

        /* 胶囊底 —— 直接画一个，不走 buttonBackground：
         * 徽标的形状太特殊（正圆 / 胶囊，无描边、无 hover），
         * 硬塞给 buttonBackground 会让那个插槽被迫处理一个
         * 它不该认识的形态。这里用最小实现，主题若想换色
         * 只需改 status 对应的令牌。 */
        Rectangle {
            id: plate

            /* 纵向撑满 —— 本件是 QSkinRow 内层 RowLayout 的**直接子项**，
             * 在它身上挂 anchors 是 Qt 明说的 undefined behavior
             * （运行期报 `Detected anchors on an item that is managed by a layout`）。
             * 用 `Layout.fillHeight` 替掉 `anchors.fill`：
             *   · 宽度**不要** fill —— 胶囊宽度本来就由 plate 自己的
             *     `implicitWidth`（下面那条）定义，RowLayout 的内容宽正是它。
             *     不声明 `Layout.fillWidth`，`QSkinRow._hasFill` 就不会被翻开，
             *     layout 的宽度法则一行不动（这也是不写 `Layout.fillWidth` 的理由本身）。
             *   · 横向居中由 QSkinRow 的 `align: "center"` 经 `_applyAlign()` 统一施加，
             *     这里不重复写 `Layout.alignment`。 */
            Layout.fillHeight: true
            radius: height / 2
            color:  d.plateColor()

            Behavior on color {
                ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
            }

            /* 数字：直接内联一个 Text。
             *
             * 这里**刻意不用 Slots.label**。理由是尺寸契约不同：
             * label 的字号是"正文 14"（主题决定，适合按钮/表格），
             * 而徽标里的数字必须小一号并且**反色**（实心底上的白字），
             * 还要精确居中在 20px 高的胶囊里。
             * 让 label 插槽同时服务这两个场景，只会逼主题作者写
             * "如果我在徽标里就…"这种判断 —— 那正是契约要消灭的。
             *
             * 判据：当两个使用者对**尺寸**的要求冲突时，不要复用插槽；
             * 只有当它们只差**颜色/字重**时（如按钮 vs 页签），才复用。 */
            Text {
                id: numText

                /* 垂直居中：不能只用 anchors.centerIn —— Text 的盒子
                 * 含字体下行（descender）留白，数字字形本身只占基线以上，
                 * 于是"盒子居中"会让可见数字偏高。实测偏差 > 0.5px。
                 *
                 * 用 anchors.fill 铺满胶囊 + 自带垂直居中，再靠
                 * font 的实际行盒把它压回中线：这是 Text 在固定高度
                 * 容器里最稳的居中方式（QSkinInput / QSkinButton 同款做法）。 */
                anchors.fill: parent
                text: root.text
                visible: !root.dot && root.text !== ""

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
                renderType:          Text.NativeRendering

                font.family:    Theme.font.family
                font.pixelSize: Theme.font.xs            /* 12 */
                font.weight:    Theme.font.weightMedium
                color:          Theme.color.onBrand
            }

            /* 宽度：
             *   单字符 → 正圆（宽 = 高）。数字居中，左右各半个字宽，
             *            天然有富余。
             *   多字符 → 文字宽 + 左右各 xs(4) 的内距。
             *
             * 为什么多字符**不能**写成 max(height, text + xs*2)：
             * 两位数字（"12"）的 text 宽约 14px，14 + 8 = 22px，
             * 比 badgeHeight(20) 只大 2px。用 max 兜住的话，一旦主题
             * 把 badgeHeight 调大（或字号调小），上限就被 height 接管，
             * 内距随之被吃掉、数字贴壁。所以多字符**无条件**给足
             * 左右内距，不和 height 比大小。 */
            implicitWidth: numText.text.length <= 1
                           ? root.badgeHeight
                           : numText.implicitWidth + Theme.space.xs * 2
        }
    }

    /* 圆点模式 */
    Rectangle {
        visible: root.dot
        anchors.fill: parent
        radius: width / 2
        color:  d.plateColor()

        Behavior on color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    function _computeText() {
        if (root.dot) return ""
        if (root.value <= 0) return root.showZero ? "0" : ""
        if (root.value > root.max) return root.max + "+"
        return String(root.value)
    }

    QtObject {
        id: d

        function plateColor() {
            switch (root.status) {
            case "success": return Theme.color.success
            case "warning": return Theme.color.warning
            case "info":    return Theme.color.info
            default:        return Theme.color.danger
            }
        }
    }
}
