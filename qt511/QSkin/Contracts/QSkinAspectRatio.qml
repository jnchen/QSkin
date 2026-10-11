/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinAspectRatio
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 定比例容器 —— "无论多宽，我的高度都按这个比例来"。封面图、视频帧、
 * 头像框、地图窗，凡是要**先占好位再填内容**的地方都用它。
 *
 * ── 它和 Image.fillMode 不是一回事（最常被混的一对）─────────────────────
 *   Image { fillMode: Image.PreserveAspectRatio }  是"**图**按比例缩放，
 *                                                  留给它的那块地不动"
 *   QSkinAspectRatio                                 是"**地**按比例占好，
 *                                                  里面放什么随意"
 * 前者在图片加载完之前无法确定占多大（CLS 抖动），后者在布局阶段就定死了。
 * 要让"图片撑出正确高度的卡片"，用的是**后者包住前者**：
 *
 *     QSkinAspectRatio {
 *         ratio: 16 / 9
 *         Image { anchors.fill: parent; source: "cover.jpg"; fillMode: Image.PreserveAspectCrop }
 *     }
 *
 * ── 只做"宽度驱动高度"，不做反向 ───────────────────────────────────────
 * 高度驱动宽度需要**父容器的高度是确定的**，而 QML 里高度确定的容器远比
 * 宽度确定的少（Layout 的纵向尺寸普遍由内容撑出，是"往后算"的量）。
 * 硬要支持反向，就得在"父高还没算出来"的那个瞬间读 height 并推出一个
 * 错的宽度 —— 这正是 M13 记录过的"拿半算完的值反推"。
 * 所以这里**单向**：宽度是输入，高度是输出。需要反向时，把高度写成
 * `width: height * ratio` 由调用方自己表达，语义更清楚。
 *
 * ── 实现只有两行，为什么值得单独成一个控件 ────────────────────────────
 * 因为比例这件事**会被写错**，而且错法很隐蔽：
 *     height: width / ratio        ← 直接绑 height 会被 Layout 打断绑定
 *                                    （Layout 设 height 时绑定被解除，之后
 *                                    窗口变宽高度不再跟随，看着像"偶发"）
 *     implicitHeight: width / ratio ← 正确：Layout 会读它并且每次都读
 * 差别在 Qt Quick Layouts 的工作方式（子项尺寸由 implicit 尺寸决定，
 * 显式 height 绑定会被接管覆盖）。把这两行收进一个控件，比让每个调用方
 * 各自踩一次要好。
 *
 * ── 子项怎么放 ─────────────────────────────────────────────────────────
 * 子项**自己**写 `anchors.fill: parent`。这里刻意不做"自动把子项铺满"的
 * 魔法 —— 见 QSkinBadge 文件头同一段道理：控件替子项设 anchors，会让
 * "我想留内边距"这种正常需求无处表达。作为容器，它只负责把地量好。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 比例 ══════════════════════ */

    /** 宽 / 高。16:9 就写 16 / 9，正方形写 1。 */
    property real ratio: 1.0

    /** 是否撑满父容器宽度（等价于 QSkinRow / QSkinColumn 的 fill）。
     *
     *  ┌── 前提：必须有父容器给得出宽度 ──────────────────────────────┐
     *  │ 默认 true 时读 parent.width。放进 Layout 后 Layout 会接管    │
     *  │ width，此时起作用的是 Layout.fillWidth（下面绑好了）——       │
     *  │ 两种容器都能用，不需要调用方分情况写。                       │
     *  └───────────────────────────────────────────────────────────────┘ */
    property bool fill: true

    /** 无外部约束时的基准宽度。只有它决定 implicitWidth 。 */
    property int baseWidth: 100

    /** 防御：ratio 为 0 或负数会让高变成 Infinity / 负数 */
    readonly property real _ratio: root.ratio > 0 ? root.ratio : 1.0

    /* ── 宽度：优先取"外部真的给过来的宽度"，否则退回基准 ──
     * 读 root.width 而不是直接写 parent.width，是为了让
     * "Layout 设的宽"和"anchors 锚的宽"都能被同一条式子看见。 */
    readonly property real effectiveWidth:
        root.width > 0 ? root.width : root.baseWidth

    implicitWidth:  root.baseWidth
    implicitHeight: Math.round(root.effectiveWidth / root._ratio)

    /* height 不显式绑定 —— 交给 QML 的默认规则（无外部约束时
     * height = implicitHeight）。见文件头"实现只有两行"那段：
     * 显式绑 height 反而会在 Layout 接管后失去响应。 */
    width:  root.fill && root.parent ? root.parent.width : root.implicitWidth

    Layout.fillWidth: root.fill

    Accessible.role: Accessible.Grouping
}
