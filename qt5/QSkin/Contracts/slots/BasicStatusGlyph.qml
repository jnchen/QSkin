/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicStatusGlyph
 *
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 * 「statusGlyph」插槽的 Basic 默认实现 —— **语义状态记号**（M22 新增）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这一格为什么必须存在（而不是让三个控件各画一遍）
 * ════════════════════════════════════════════════════════════════════════
 * M22 的三个件都要"按语义画一个记号"：
 *
 *     QSkinAlert        行内提示左侧的 ✓ / i / ! / ×
 *     QSkinResult       结果页正中的大号同款记号
 *     QSkinAlertDialog  标题前的同款记号
 *
 * 三处各画一遍，就是本项目已经付过**四次**代价的那个形状 ——
 * 同一个 affordance 在同一仓库里有 N 种画法（见 Slots.qml 文件头里
 * 「展开箭头」那段：QSkinSelect / QSkinTable / QSkinDatePicker / QSkinPagination
 * 各绕一遍，其中一种还是字符）。所以先有唯一的定义。
 *
 * ── 为什么是**插槽**而不是"在契约层画一个内部组件"────────────────────
 * 「用矢量画」只解决一半问题，另一半是「画成什么样」，而这一半因主题而异：
 *
 *     Ant / TDesign / Arco   实心圆盘 + 反白记号（本文件就是这个形态）
 *     shadcn（lucide）       描边圆环 + 同色记号；且 warning **是三角**
 *
 * 三比一的分歧，而且分歧在**形态**上（实心 vs 描边、圆 vs 三角）——
 * 令牌表达不了。按项目一贯的判据「差异属于主题，就不该在控件里硬编码」，
 * 它必须是插槽。与 spinRing（四家弧长/段数/线宽全不同）、
 * radioIndicator（2:2 分成实心/描边两派）是同一条判据。
 *
 * ── 为什么四家主题里只有 shadcn 需要另写一份 ─────────────────────────
 * TD / Ant / Arco 三家在这一格的差异只有**尺寸**，而尺寸由宿主给
 * （见下面契约），形态与 Basic 一致 —— 于是它们不覆盖，继承 Basic 即可。
 * 这与 switchIndicator / buttonContent / tooltipOverlay 三格的既有情形
 * 完全一样（TDesign 文件头写着"纯令牌换肤即可达标，没必要写第二份实现"）。
 * 所以这一格落地时是 **2 份实现**，不是 5 份。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 契约
 * ════════════════════════════════════════════════════════════════════════
 *   property var control   宿主。鸭子类型，要求暴露：
 *     · status  string  "info" | "success" | "warning" | "danger"
 *                       （缺省 info；不认识的值按 info 处理）
 *     · size    int     记号边长（px）。**这一格与 chevronIndicator 不同：
 *                       尺寸由宿主给**，缺省 Theme.size.iconMd。
 *
 *   ── 为什么尺寸这次由宿主给 ──────────────────────────────────────────
 *   chevronIndicator 的契约写着"宿主不要给宽高，用插槽的 implicitWidth" ——
 *   那里的箭头只在一个数量级里出现（12~14px）。记号不一样：同一个形态
 *   在 QSkinAlert 里是 16px、在 QSkinAlertDialog 里是 20px、在 QSkinResult 里
 *   是 64px —— **跨了一个数量级**。把三个缺省值塞进主题只会得到三个
 *   语义含糊的格子，还不如让宿主直接报它要多大。
 *
 *   插槽仍然自己声明 implicitWidth/implicitHeight（= size），所以
 *   "不给定尺寸就按主题缺省摆" 这条对宿主依然成立。
 *
 *   ── 颜色不进契约 ────────────────────────────────────────────────────
 *   与 chevronIndicator 一样，颜色由插槽自己按 status 从 Theme 取。
 *   宿主不该告诉插槽"用哪个绿"，那是主题的词汇表。
 *
 * 契约第 3 条：记号没有交互，本文件里不许出现 MouseArea / Keys。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Shapes 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    /* ══════════════════ 从宿主读的两个量 ══════════════════ */

    readonly property string status: {
        if (root.control === null || root.control === undefined) return "info"
        if (root.control.status === undefined) return "info"
        var s = String(root.control.status)
        return (s === "success" || s === "warning" || s === "danger") ? s : "info"
    }

    readonly property int size: {
        if (root.control === null || root.control === undefined) return Theme.size.iconMd
        if (root.control.size === undefined || root.control.size === null) return Theme.size.iconMd
        var n = Number(root.control.size)
        return (isNaN(n) || n <= 0) ? Theme.size.iconMd : n
    }

    implicitWidth:  root.size
    implicitHeight: root.size
    width:  implicitWidth
    height: implicitHeight

    /* ══════════════════ 由 status 派生的两个颜色 ══════════════════ */

    readonly property color discColor: root.status === "success" ? Theme.color.success
                                     : root.status === "warning" ? Theme.color.warning
                                     : root.status === "danger"  ? Theme.color.danger
                                                                 : Theme.color.info

    /* 记号画在**实心盘上**，所以它必须是"彩色底上的反白"。
     * 令牌是 Theme.color.onBrand（四家都指向 #FFFFFF）——
     * 写死 "#FFFFFF" 在浅色下是数值空操作，换主题时也看不出差别，
     * 但那就把"这个颜色属于主题"这条约定悄悄丢掉了。 */
    readonly property color markColor: Theme.color.onBrand

    /** 记号笔画宽：边长的 13%。上色用的是同一支笔，
     *  所以点（零长度线段 + 圆帽）与线段的粗细天然一致。 */
    readonly property real markWidth: root.width * 0.13

    /* ══════════════════ 盘：实心圆 ══════════════════
     * 用 Rectangle + radius 而不是 Shape 画圆 —— 圆没有斜边问题，
     * Rectangle 的圆角是像素级准确的整数光栅化，而且这一个节点
     * 就不必再挂 preferredRendererType。QSkinEmpty 的插图同理
     * （那边是"全是圆角矩形所以不用 Shape"，见其文件头）。 */
    Rectangle {
        anchors.fill: parent

        radius: width / 2
        color:  root.discColor
    }

    /* ══════════════════ 记号（四个，各占一个 Shape） ══════════════════
     *
     * ── 为什么四个记号分四个 Shape，而不是一个 Shape 里四组 ShapePath ──
     * ShapePath **没有**可靠的 visible 属性，而用
     * `strokeColor: 命中 ? 色 : "transparent"` 去屏蔽会让七条路径
     * （✓ 一条、i 两条、! 两条、× 两条）挤在一个节点里，读的人
     * 得自己反推"此刻哪几条是活的"。Shape 是 Item，visible 是它的
     * 本分 —— 四个节点的代价换来"谁在画"一眼可见，值。
     *
     * 所有记号都画在**盘内侧约 32%~68%** 的方框里：实心盘上的反白记号
     * 比空心图标需要更收一点，否则笔画会顶到盘的边缘、看着发胀。
     * 坐标一律写成 `root.width * k` 的形式，所以整格可以无级缩放 ——
     * 这正是 QSkinResult 能把同一个记号放大到 64px 的原因。 */

    /* ✓ 成功 */
    Shape {
        anchors.fill: parent
        visible: root.status === "success"

        ShapePath {
            strokeWidth: root.markWidth
            strokeColor: root.markColor
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap
            joinStyle:   ShapePath.RoundJoin

            startX: root.width * 0.32;  startY: root.height * 0.51
            PathLine { x: root.width * 0.44;  y: root.height * 0.64 }
            PathLine { x: root.width * 0.69;  y: root.height * 0.36 }
        }
    }

    /* i 信息：一个点 + 一条竖杠（两条路径，同属一个 Shape） */
    Shape {
        anchors.fill: parent
        visible: root.status === "info"

        ShapePath {
            strokeWidth: root.markWidth
            strokeColor: root.markColor
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            /* 零长度线段 + 圆帽 = 一个直径等于笔宽的圆点。
             * 比 PathAngleArc 省事，也不必和"整圆 sweepAngle"较劲。 */
            startX: root.width * 0.50;  startY: root.height * 0.34
            PathLine { x: root.width * 0.50;  y: root.height * 0.34 }
        }

        ShapePath {
            strokeWidth: root.markWidth
            strokeColor: root.markColor
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            startX: root.width * 0.50;  startY: root.height * 0.47
            PathLine { x: root.width * 0.50;  y: root.height * 0.67 }
        }
    }

    /* ! 警告：一条竖杠 + 下面一个点（与 i 上下颠倒） */
    Shape {
        anchors.fill: parent
        visible: root.status === "warning"

        ShapePath {
            strokeWidth: root.markWidth
            strokeColor: root.markColor
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            startX: root.width * 0.50;  startY: root.height * 0.33
            PathLine { x: root.width * 0.50;  y: root.height * 0.54 }
        }

        ShapePath {
            strokeWidth: root.markWidth
            strokeColor: root.markColor
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            startX: root.width * 0.50;  startY: root.height * 0.66
            PathLine { x: root.width * 0.50;  y: root.height * 0.66 }
        }
    }

    /* × 危险：两条对角线 */
    Shape {
        anchors.fill: parent
        visible: root.status === "danger"

        ShapePath {
            strokeWidth: root.markWidth
            strokeColor: root.markColor
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            startX: root.width * 0.35;  startY: root.height * 0.35
            PathLine { x: root.width * 0.65;  y: root.height * 0.65 }
        }

        ShapePath {
            strokeWidth: root.markWidth
            strokeColor: root.markColor
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            startX: root.width * 0.65;  startY: root.height * 0.35
            PathLine { x: root.width * 0.35;  y: root.height * 0.65 }
        }
    }
}
