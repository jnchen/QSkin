/****************************************************************************
 * QSkin · Quick Design System — Foundation / QSkinColumn
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Web 语义的列布局：
 *     gap     ≈ CSS  gap
 *     padding ≈ CSS  padding
 *     align   ≈ CSS  align-items      （交叉轴："start" | "center" | "end"）
 *     justify ≈ CSS  justify-content  （主轴：  "start" | "center" | "end"）
 *
 * 示例：
 *     QSkinColumn {
 *         gap: Theme.space.md
 *         padding: Theme.space.lg
 *         align: "start"
 *         justify: "end"
 *         Heading { level: 2; text: "设置" }
 *         Body { text: "..." }
 *     }
 *
 * 命名：本文件原名 `Column.qml`，M29 改为 `QSkinColumn.qml`（去掉了 qmldir 里
 * 的双名注册）。原因与完整记账见 `foundation/qmldir` 与 `QSkinRow` 的文件头。
 *
 * ── 主轴分配（M29）：为什么"默认不撑满"这件事本身就是 justify 的地基 ────
 *
 * 本组件从 M2 起就有一个刻意的决定：内层 `ColumnLayout` 的**主轴（高度）
 * 按内容收缩，绝不撑满**。当时只是把它当"躲开 Qt 的余量摊分"的权宜之计，
 * M29 才看清它其实是**主轴分配的实现手段本身**：
 *
 *     主轴尺寸 = 内容尺寸 → 余量不在 layout 里 → 间隙只能是真 gap。
 *
 * 所以 `justify` 的实现只是"决定这块内容贴在容器的头 / 中 / 尾"：
 *   `start`（默认）—— layout 贴容器顶，余量全在底部
 *   `center`       —— 上下平分余量
 *   `end`          —— 贴容器底，余量全在顶部
 * 全部通过 `y` 的绑定完成，不注入任何占位项（取舍见 `QSkinRow` 文件头三条理由）。
 *
 * ⚠ 有子项声明 `Layout.fillHeight` 时，上面这条**整个让位**：layout 改为撑满，
 *   余量交给那个子项，`justify` 无从发生。这与 CSS 一致 —— 只要有一个
 *   `flex-grow` 子项，`justify-content` 就没有余量可分配。
 *
 * ── 为什么"撑满就会摊间距"（原始排查，保留）────────────────────────────
 *
 * Qt 的 ColumnLayout 在"容器有多余高度、且没有任何子项声明
 * `Layout.fillHeight`"时，会把那些高度**分到子项之间**。表现是间距莫名
 * 变大 —— M18 抓图上侧栏四个按钮之间隔了 125px，而 `gap` 设的是 8。
 *
 * ── ⚠ 数字校正（M27 复测，**第二版**）──────────────────────────────────
 * 这里原来写的是「容器 400、3 个 32 高的子项，y 落在 0 / 136 / 272」。
 * M27 第一版把它改成 **0 / 184 / 320** —— **那也是错的**，错在把第一枚
 * 子项的 y 当成了 0：它是 **48**（整组垂直居中，上下各留白 48，与下面
 * 「不设 alignment = 居中 48」那一行本来就是同一件事，改数字时没对上）。
 *
 * Qt 6.8.3 实测（探针 `.cache/keep/_probe_layoutgap*.qml`）：
 *     y        = **48 / 184 / 320**（不是 0 / 184 / 320）
 *     间距     = **104**（= 8 + 96），**不是**我第一版写的 152（19 倍）
 *     上/下留白 = 各 **48**
 *     复算：48 + 32 + 104 + 32 + 104 + 32 + 48 = 400 ✓
 *
 * 于是余量 288（= 400 − 96 − 16）的分配形状是**边缘拿半份、间隙拿整份**
 * （48 / 96 / 96 / 48）—— 也就是 CSS 的 `space-around`，
 * 不是我第一版写的"均分进 gap"（那是 `space-between`）。
 * 子项**有没有 size hint**（`Rectangle` 的 implicitHeight 恒 0）
 * 对结果毫无影响，两档完全一致（`_probe_layoutgap2.qml` 已排除）。
 *
 * 顺带一提，这个形状**不能**拿去推 `QSkinRow` —— 同一份意图下 RowLayout
 * 那边实测是「间隙各拿一份、尾部再留一份、头部不留」（0 / 196 / 392，
 * 尾部 148 没人要）。**两种容器的分配形状实测不一样**，一个推不出另一个。
 * Row 那边的数字与门在 `tests/smoke_layout_gap.qml` 的 [6]。
 *
 * 结论不变（仍然是"余量被分进间距"），只有量级与形状要按实测改。
 * ⚠ 改动这里会红：`tests/smoke_layout_gap.qml` 的 [0][1][2] 三条守着
 * 本文件的这个决定，改完必须重跑 `./tools/test.sh`。
 *
 * 排查中走过两条错路，都已排除，写在这里省得后人再走：
 *   · 以为是 `Layout.alignment` 的锅 —— 不是。探针把"完全不设 /
 *     全设 AlignLeft / 只给第一个设 / 全设 AlignHCenter"四种写法摆在一起，
 *     y 完全相同。alignment 只管"整组靠哪边"（不设=居中 48、
 *     `Qt.AlignTop`=贴顶 0），一个字都不碰间距。
 *   · 想改用 `Layout.counterAxisAlignItems`（"只认交叉轴"的那个 API）——
 *     Qt 6.8 的 QtQuick.Layouts 里**根本没有这个属性**，查
 *     `.qt/<版本>/qml/QtQuick/Layouts/plugins.qmltypes` 确认过：
 *     整个模块只导出一个 `alignment`。
 *
 * ⚠ M29 补一句：上面这条对 alignment 的结论，在**主轴**上也成立。
 *   给 `QSkinRow` 的三枚子项都设 `Layout.alignment: Qt.AlignHCenter`，
 *   实测落点 `74 / 270 / 466` —— 整组居中了，但间隙仍是 156。
 *   所以 alignment 不是 justify 的替代品，两者各管一件事。
 *
 * 代价（明确写下来，不藏）：`justify` 只在"没有 fillHeight 子项"时有效；
 * 而"某个子项吃掉剩余高度"（消息列表撑满、表单左右分栏）与它互斥 ——
 * 这两种诉求本来就矛盾（一个是"余量留给容器"，一个是"余量给某个子项"）。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Layouts 1.11

Item {
    id: root

    /** 子项间距，等价于 CSS gap */
    property int gap: Theme.space.sm

    /** 内边距，等价于 CSS padding */
    property int padding: 0

    /** 交叉轴对齐：start | center | end */
    property string align: "start"

    /** 主轴分配：start | center | end
     *  （等价于 CSS justify-content 的 flex-start / center / flex-end）。
     *  有 `fillHeight` 子项时本项无效 —— 余量已被那个子项吃干，与 CSS 一致。 */
    property string justify: "start"

    /** 是否由本组件统一管理子项对齐 */
    property bool manageAlignment: true

    /* 撑满父容器。不要用 width: parent.width —— Qt Quick Layouts 用
     * implicitWidth（本组件定义了它）决定子项尺寸，显式 width 会被静默忽略。
     * 撑满请写 fill: true。详见 QSkinRow.qml 里同一段注释。 */
    property bool fill: false

    default property alias data: layout.data

    implicitWidth:  layout.implicitWidth  + root.padding * 2
    implicitHeight: layout.implicitHeight + root.padding * 2

    /* 默认按内容收缩。需要撑满父容器时写 fill: true。 */
    width:  implicitWidth
    height: implicitHeight

    Layout.fillWidth: root.fill

    /* `_hasFill` 必须是**属性**而不是现算的函数 —— QML 的绑定不会因为
     * "某个函数读了 children"而重算（命令式读取不建立依赖，见 README
     * 第十一节）。它由 layout 的 `onChildrenChanged` 经 `_refresh()` 驱动。 */
    property bool _hasFill: false

    /* 内层 ColumnLayout 的尺寸策略是本组件最要紧的一处决定：
     *
     *     交叉轴（宽度）—— 始终撑满 root（`align` 要有空间才谈得上）
     *     主轴  （高度）—— 按内容收缩，**除非**有子项声明 `Layout.fillHeight`
     *
     * 主轴不撑满时，多余空间根本不存在，justify 就退化成"这块内容贴在容器
     * 的哪一头"（由下面的 `y` 决定）。这正是 M2 那次排查留下的结论 ——
     * 当年只当成"躲开摊间距"的权宜之计，M29 才看清它就是主轴分配的实现。 */
    ColumnLayout {
        id: layout

        x: root.padding
        width: root.width - root.padding * 2
        spacing: root.gap

        height: root._hasFill ? (root.height - root.padding * 2) : implicitHeight

        y: {
            if (root._hasFill) return root.padding
            var avail = root.height - root.padding * 2
            if (root.justify === "center") return root.padding + (avail - height) / 2
            if (root.justify === "end")    return root.padding + (avail - height)
            return root.padding
        }

        onChildrenChanged: root._refresh()
        Component.onCompleted: root._refresh()
    }

    onAlignChanged: _applyAlign()
    onManageAlignmentChanged: _applyAlign()

    /** align（CSS 的 align-items）→ Qt::Alignment 的交叉轴值。 */
    function _alignmentEnum() {
        switch (root.align) {
        case "center": return Qt.AlignHCenter
        case "end":    return Qt.AlignRight
        default:       return Qt.AlignLeft
        }
    }

    /**
     * 子项变化时重算两件事：有没有 fillHeight 子项（决定 layout 撑不撑满，
     * 进而决定 justify 有没有意义）、以及子项的交叉轴对齐。
     *
     * 合成一个函数是**有意的** —— 见 `QSkinRow.qml` 里同名的 `_refresh`。
     */
    /* 下面**两个**函数都在 JS 循环里读写 `Layout` 附加属性，qmllint 推断不出
     * 循环变量的运行时类型，会误报 "Layout must be attached to Item elements"。
     * 运行时行为正确，故只在函数级关闭该检查；不用 `.qmllint.ini` 全局降级，
     * 以免掩盖真问题。
     * 注意指令要写在函数**外面** —— 该警告归属到 `_refresh` 的第一行，
     * 写在函数体内部盖不住。M29 重写时只包了 `_applyAlign()`，于是
     * lint 多出 3 条警告（同一行被 3 条 import 路径各扫一遍，计数是 3）。 */
    // qmllint disable Quick.attached-property-type
    function _refresh() {
        var f = false
        for (var i = 0; i < layout.children.length; ++i) {
            var c = layout.children[i]
            if (c && c.Layout !== undefined && c.Layout.fillHeight) { f = true; break }
        }
        root._hasFill = f
        root._applyAlign()
    }

    function _applyAlign() {
        if (!root.manageAlignment) return
        var a = root._alignmentEnum()
        for (var i = 0; i < layout.children.length; ++i) {
            var c = layout.children[i]
            if (c && c.Layout !== undefined)
                c.Layout.alignment = a
        }
    }
    // qmllint enable Quick.attached-property-type
}
