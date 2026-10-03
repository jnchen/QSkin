/****************************************************************************
 * QSkin · Quick Design System — Foundation / Grid
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Web 语义的网格布局，核心是这一句 CSS 的等价物：
 *
 *     grid-template-columns: repeat(auto-fit, minmax(160px, 1fr))
 *                                        ↓
 *     Grid { minChildWidth: 160; gap: Theme.space.md }
 *
 * 语义对照：
 *     minChildWidth  ≈ minmax() 的下限
 *     columns        ≈ repeat(N, ...) 里的 N（为 0 时走 auto-fit）
 *     gap            ≈ CSS gap
 *     columnWidth    ≈ 1fr 折算出的实际列宽（只读，供子项参考）
 *
 * 示例：
 *     Grid {
 *         minChildWidth: 240
 *         gap: Theme.space.lg
 *         padding: Theme.space.lg
 *         Repeater {
 *             model: 12
 *             Card { }            // 每格自动等分，窗口变窄自动减少列数
 *         }
 *     }
 *
 * 窄屏强制单列的常见写法：
 *     minChildWidth: Breakpoints.compact ? 99999 : 240
 *
 * 注意：本文件所在模块内，QML 的 `Grid` 指的就是这里定义的类型。
 *       若需要 QtQuick 原生 Grid，请写 `QtQuick.Grid`。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    /** 子项间距（行距列距相同），等价于 CSS gap */
    property int gap: Theme.space.md

    /** 每列最小宽度，等价于 minmax() 的下限 */
    property int minChildWidth: 160

    /** 固定列数；0 表示 auto-fit（按宽度自动算） */
    property int columns: 0

    /** 内边距 */
    property int padding: 0

    /** 是否让每格等分剩余空间（等价于 1fr）。关掉后按子项自身宽度排布 */
    property bool equalColumns: true

    /* 撑满父容器。不要用 width: parent.width —— Qt Quick Layouts 用
     * implicitWidth（本组件定义了它）决定子项尺寸，显式 width 会被静默忽略。
     * 对 Grid 来说这尤其致命：hug 状态下 avail 由自身内容宽决定，
     * auto-fit 的列数会算错。撑满请写 fill: true。详见 QSkinRow.qml。 */
    property bool fill: false

    default property alias data: layout.data

    readonly property real avail: Math.max(0, root.width - root.padding * 2)

    /** 当前实际列数 */
    readonly property int columnCount: root.columns > 0
        ? root.columns
        : Math.max(1, Math.floor((root.avail + root.gap) / (root.minChildWidth + root.gap)))

    /** 折算后的列宽（等价于 1fr 结算结果），子项可参考它做内部布局 */
    readonly property real columnWidth:
        (root.avail - root.gap * Math.max(0, root.columnCount - 1)) / Math.max(1, root.columnCount)

    /* ── 为什么 fill 时 implicitWidth 不能跟着 layout 走 ──────────────
     * Grid 的 implicitWidth 经过 columnCount 间接依赖自身 width：
     *     width → avail → columnCount → GridLayout.columns → implicitWidth
     * 而外部布局（fillWidth）会写 width。两个写入者一旦同时存在：
     *     布局写 580 → 列数 3 → implicitWidth≈27 → 绑定回写 27
     *     → 列数 1 → implicitWidth≈1 → 布局又写 580 → ……
     * 每轮数值都不同，Qt 的绑定环检测判定不了，直接死循环挂死
     * （实测：Grid{fill:true} 放进任何 Layout 就再也无法退出）。
     *
     * 所以 fill 时 implicitWidth 必须与 width 彻底脱钩 —— 反正外部
     * 布局负责拉伸，隐式宽度只需给出合理下限。minChildWidth 恰好
     * 也是 auto-fit 的下限，语义一致。 */
    implicitWidth: root.fill
        ? root.minChildWidth
        : layout.implicitWidth + root.padding * 2
    implicitHeight: layout.implicitHeight + root.padding * 2

    /* 默认按内容收缩。需要撑满父容器时写 fill: true。 */
    width:  implicitWidth
    height: implicitHeight

    Layout.fillWidth: root.fill
    Layout.fillHeight: false

    GridLayout {
        id: layout
        anchors.fill: root
        anchors.margins: root.padding

        columns: root.columnCount
        columnSpacing: root.gap
        rowSpacing: root.gap

        onChildrenChanged: root._applyCells()
        Component.onCompleted: root._applyCells()
    }

    onColumnCountChanged: _applyCells()
    onEqualColumnsChanged: _applyCells()

    /**
     * 让每一格等分剩余空间。
     * fillWidth + preferredWidth=1 是 Qt Layouts 里实现等比分配的惯用手段：
     * preferredWidth 只是"权重"，真正的宽度由 fillWidth 拉平。
     */
    /* 说明见 QSkinColumn.qml / QSkinRow.qml 中 _applyAlign 上方的同名注释：
     * JS 循环里写 Layout 附加属性属于 qmllint 静态误报，
     * 指令须写在函数外面才能覆盖到函数声明行。 */
    // qmllint disable Quick.attached-property-type
    function _applyCells() {
        if (!root.equalColumns) return
        for (var i = 0; i < layout.children.length; ++i) {
            var c = layout.children[i]
            if (!c || c.Layout === undefined) continue
            c.Layout.fillWidth = true
            c.Layout.preferredWidth = 1
        }
    }
    // qmllint enable Quick.attached-property-type
}
