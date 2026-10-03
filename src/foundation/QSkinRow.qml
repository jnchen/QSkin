/****************************************************************************
 * QSkin · Quick Design System — Foundation / QSkinRow
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Web 语义的行布局：
 *     gap     ≈ CSS  gap
 *     padding ≈ CSS  padding
 *     align   ≈ CSS  align-items      （交叉轴："start" | "center" | "end" | "baseline"）
 *     justify ≈ CSS  justify-content  （主轴：  "start" | "center" | "end"）
 *
 * 示例：
 *     QSkinRow {
 *         gap: Theme.space.md
 *         padding: Theme.space.lg
 *         align: "center"
 *         justify: "center"
 *         Icon { source: "..." }
 *         Body { text: "保存成功" }
 *     }
 *
 * ── 命名（M29 改名）─────────────────────────────────────────────────────
 * 本文件原名 `Row.qml`，并在 qmldir 里**同时注册** `Row` 与 `QSkinRow`
 * 两个名字。双名在源侧可行，但官方构建路径（CMake 的
 * `QT_QML_SOURCE_TYPENAME` 是单值属性）表达不出来 → 构建产物里 `QSkinRow`
 * 不存在，几十个契约文件在官方构建下全崩。已改为单名 `QSkinRow`。
 * 顺带消掉另一个隐患：改名后裸 `Row` 稳定地指 QtQuick 的 positioner，
 * 不再有"同一个词在本模块内外指不同东西"这种要人记住的事。
 * 完整记账见 `foundation/qmldir` 与 `CMakeLists.txt` 的模块头。
 *
 * ── 主轴分配（M29 新增 justify，同时改掉默认行为）───────────────────────
 *
 * **先说结论**：多余的主轴空间，默认**留在末端**（= CSS 的 `flex-start`）。
 *
 * 改之前不是这样。`Row` 的内层 `RowLayout` 原来 `anchors.fill` 撑满，
 * 而 Qt 在"撑满 + 没有任何子项声明 `Layout.fillWidth`"时会把余量**摊进
 * 子项之间的间距**，并且**尾部还剩一份没人要**。M27 实测（580 宽 / 3 枚
 * 40 宽 / gap 8）落点是 `0 / 196 / 392` —— 两道间隙各从 8 涨到 **156**，
 * 而尾部还空着 **148**。这条缺陷当时被 `tests/smoke_layout_gap.qml` 的
 * `[6]` **刻意钉住**（"哪天补上了它会红，那是在提醒你改文档"）。M29 补上了。
 *
 * ── 实现为什么是"移动 layout 自己"而不是"注入占位项"────────────────────
 *
 * CSS 的标准做法是插入 `flex-grow` 的哑元。Qt 这边也能这么干（插一枚
 * `Item { Layout.fillWidth: true }`），M29 探针（`.cache/_probe_m29justify.qml`）
 * 实测它**确实有效**：
 *
 *     尾部插一枚 → 0 / 48 / 96     间隙回到真 gap 8，余量全在末端 ✓
 *     头部插一枚 → 444 / 492 / 540                        （flex-end）
 *     首尾各一枚 → 首尾各 214，内容居中                    （flex-center）
 *     每缝各一枚 → 0 / 270 / 540                          （space-between）
 *
 * 但**不用它**，理由三条，每条都是实测或结构性的：
 *
 *   ① 位置控制不了。"每缝一枚"要求把 Item 插进第 k 与第 k+1 个子项之间，
 *      而 QSkin 的子项是通过 `default property alias data: layout.data` 进来的，
 *      会**一律追加到末尾**。QML 没有公开 API 把已有 child 移到指定下标。
 *   ② 它自己会占一份 spacing。n 枚占位项把 spacing 数从 n−1 抬到 2n，
 *      于是形状与 CSS 的公式对不上 —— 会造出"看起来像 `space-between`、
 *      细节对不上"的假等价物，而本项目明确不做那种东西（`COVERAGE.md` §四）。
 *   ③ 不必付这个代价。余量的去向**不是只有 fill 子项一种办法** ——
 *      让 `layout` 自己别撑满，余量就根本不存在，间隙自然回到真 gap。
 *      这正是 `QSkinColumn` 早就采用的做法（见它的文件头）。
 *
 * 于是本组件的规则是：
 *
 *     layout 的主轴尺寸 = 内容尺寸（`implicitWidth`），**除非**有子项声明
 *     `Layout.fillWidth` —— 那时才撑满，把余量交给那个子项。
 *     而 `justify` 决定 layout 在容器内的**落点**。
 *
 * ⚠ 这条与 CSS 的语义是**对齐的**：CSS 里只要有一个 `flex-grow` 子项，
 *   余量就被它吃干，`justify-content` 就无从发生。QSkin 这边同理 ——
 *   有 fill 子项时 `justify` 无效（余量已经没了）。
 *   静态检查抓不到这一点，所以它写在 `tests/smoke_layout_gap.qml` 里当断言。
 *
 * ── 交叉轴对齐（align）──────────────────────────────────────────────────
 * `align` 走 `_alignmentEnum()` → 每个子项的 `Layout.alignment`，只影响交叉轴。
 *
 * ⚠ 别把 `Layout.alignment` 的**主轴**分量当 `justify` 用。M29 探针量过：
 *   给三枚子项都设 `Layout.alignment: Qt.AlignHCenter`，得到
 *   `74 / 270 / 466` —— 整组居中了，**但间隙仍然是 156**。也就是说
 *   alignment 管的是"整组靠哪边"，一个字都不碰间距。这与 `QSkinColumn`
 *   交叉轴那次排查的结论同族（见其文件头"排查中走过两条错路"）。
 *
 * ── 已知的有损处（写在明处，不藏）───────────────────────────────────────
 *   · **没有 `around` / `evenly`**。CSS 的 `space-around` 是"边缘半份、
 *     间隙整份"，而 Qt 的 fill 是**布尔量、没有权重**。"边缘拿半份"要么
 *     依赖"内容宽"（引入一条脆弱的绑定），要么用 `Layout.maximumWidth` 卡 ——
 *     M29 探针实测后者**分配不均**：首尾各卡在 74，而三处间隙拿到
 *     69 / 34 / 34，且尾部还有 77 没人要。既然造不出干净形状，
 *     就不提供这一档（造假的等价物比缺少一个选项更坏）。真要那种观感，
 *     用 `Spacer` 手工摆。
 *   · **`justify` 不处理溢出** —— `Row` 不换行（见 `COVERAGE.md` §一：
 *     `flex-wrap` 未做）。内容比容器宽时 layout 会溢出到右侧
 *     （`x` 仍是 `padding`），不裁剪、不滚动。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    /** 子项间距，等价于 CSS gap */
    property int gap: Theme.space.sm

    /** 内边距，等价于 CSS padding */
    property int padding: 0

    /** 交叉轴对齐：start | center | end | baseline */
    property string align: "center"

    /** 主轴分配：start | center | end
     *  （等价于 CSS justify-content 的 flex-start / center / flex-end）。
     *  有 `fillWidth` 子项时本项无效 —— 余量已被那个子项吃干，与 CSS 一致。 */
    property string justify: "start"

    /** 是否由本组件统一管理子项对齐（关掉后子项可自行设置 Layout.alignment） */
    property bool manageAlignment: true

    /* ── 撑满父容器 ──────────────────────────────────────────────
     * **不要**用 width: parent.width 来撑满 —— 会静默失效。
     *
     * 本组件内部是 RowLayout，而 Qt Quick Layouts 决定子项尺寸用的是
     * implicitWidth（本组件定义了它），不是 width。所以外面写的
     * width: parent.width 会被布局忽略，行退化成按内容收缩。
     * 这个 bug 是 M2 主题的截图验证抓出来的：头部一行的 Spacer
     * 从来没把右侧按钮顶到行尾。
     *
     * 撑满请写 fill: true（等价于 Layout.fillWidth，命名对齐 Spacer）。
     * 不在 QSkin 布局里时它没有副作用，width 仍是 hug。
     * Rectangle / Text 这类**没有**定义 implicitWidth 的类型不受影响，
     * 它们写 width: parent.width 是有效的 —— 但风格上统一用 fill 更安全。 */
    property bool fill: false

    default property alias data: layout.data

    implicitWidth:  layout.implicitWidth  + root.padding * 2
    implicitHeight: layout.implicitHeight + root.padding * 2

    /* 默认按内容收缩（≈ CSS 的 inline-flex）。
     * 需要撑满父容器时写 fill: true —— 不要和 anchors.fill 混用。 */
    width:  implicitWidth
    height: implicitHeight

    Layout.fillWidth: root.fill

    /* `_hasFill` 必须是**属性**而不是现算的函数 —— QML 的绑定不会因为
     * "某个函数读了 children"而重算（命令式读取不建立依赖，见 README
     * 第十一节）。它由 layout 的 `onChildrenChanged` 经 `_refresh()` 驱动。 */
    property bool _hasFill: false

    /* 这里刻意**不**写 `anchors.fill: root`。旧版是 fill + margins，那会让
     * 内层 RowLayout 永远撑满，于是 Qt 的"余量摊进间距"必然发生 ——
     * 那正是 `[6]` 钉住的那条缺陷。改成显式 x/y/width/height 之后，
     * 尺寸策略变成下面 layout 上那两条绑定：没有 fill 子项时余量根本不存在。
     *
     * ⚠ 主轴的那两个绑定必须写在 **layout 上**，不能写在 root 上 ——
     *   `width` 的表达式里要读 `root.width`，而 root 的 `width` 已经由
     *   `implicitWidth` 定义了。写在 root 上会变成"同一个属性被设置两次"
     *   （运行期报 `Property value set multiple times`，**qmllint 不报**），
     *   而且 `root.width` 出现在它自己的绑定里是自引用。
     *   M29 第一版就栽在这里：冒烟全线报 `Type QSkinRow unavailable`，
     *   真正的错因（一行 `Property value set multiple times`）被埋在末尾。 */
    RowLayout {
        id: layout

        /* 主轴（水平）：
         *   有 fill 子项 → 撑满，余量交给子项（此时 justify 无从发生）
         *   没有       → 等于内容宽，余量留在容器里、由 x 定位 */
        width: root._hasFill ? (root.width - root.padding * 2) : implicitWidth

        x: {
            if (root._hasFill) return root.padding
            var avail = root.width - root.padding * 2
            if (root.justify === "center") return root.padding + (avail - width) / 2
            if (root.justify === "end")    return root.padding + (avail - width)
            return root.padding
        }

        /* 交叉轴（垂直）**始终**撑满 root —— `align` 要有空间才谈得上 */
        y: root.padding
        height: root.height - root.padding * 2

        spacing: root.gap

        onChildrenChanged: root._refresh()
        Component.onCompleted: root._refresh()
    }

    onAlignChanged: _applyAlign()
    onManageAlignmentChanged: _applyAlign()

    /** align（CSS 的 align-items）→ Qt::Alignment 的交叉轴值（垂直方向）。 */
    function _alignmentEnum() {
        switch (root.align) {
        case "start":    return Qt.AlignTop
        case "end":      return Qt.AlignBottom
        case "baseline": return Qt.AlignBaseline
        default:         return Qt.AlignVCenter
        }
    }

    /**
     * 子项变化时重算两件事：有没有 fill 子项（决定 layout 撑不撑满）、
     * 以及子项的交叉轴对齐。
     *
     * ⚠ 合成一个函数是**有意的**：`onChildrenChanged` 在声明期会被触发很多次，
     *   两个功能各挂一次会让遍历做两遍；更要紧的是只要有一处漏挂，
     *   表现就是"某些声明顺序下 justify 或 align 静默不生效"，很难查。
     */
    /* 下面**两个**函数都在 JS 循环里读写 `Layout` 附加属性，qmllint 推断不出
     * 循环变量的运行时类型，会误报 "Layout must be attached to Item elements"。
     * 运行时行为是正确的，故用行内指令只在这一段关闭该检查，而不是在
     * `.qmllint.ini` 里全局降级（那样会掩盖真正的问题）。
     *
     * ⚠ 指令必须包住 `_refresh()` —— 它也读 `c.Layout.fillWidth`。
     *   M29 重写本文件时只包了 `_applyAlign()`，于是 lint 多出 3 条警告
     *   （同一行被 3 条 import 路径各扫一遍，所以计数是 3 不是 1）。 */
    // qmllint disable Quick.attached-property-type
    function _refresh() {
        var f = false
        for (var i = 0; i < layout.children.length; ++i) {
            var c = layout.children[i]
            if (c && c.Layout !== undefined && c.Layout.fillWidth) { f = true; break }
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
