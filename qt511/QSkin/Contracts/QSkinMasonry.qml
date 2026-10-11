/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinMasonry
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 瀑布流 —— 一组高度不等的块，按"落进当前最矮的列"铺开，于是各列
 * 底部参差（不像 QSkinGrid 那样每行等高）。
 *
 * ── 分配算法不在这里（M27 裁决三）────────────────────────────────────
 * 全部几何都在 `QSkin.Foundation.MasonryUtil`（一份 `.js` + 一个薄转发），
 * 本文件一行分配都没有 —— 它只做三件事：把 model 翻成高度数组、
 * 把 util 的结果铺到 Repeater 上、把总高报给父布局。
 *
 * 为什么必须这样分：分配结果要能被 node **直接算**（对输出验四条不变量，
 * 见 `MasonryUtil.js` 文件头）。算法长在控件里就只能通过控件属性去摸
 * "控件认为的布局"，而"控件认为的"与"算出来的"一致什么也证明不了。
 *
 * ── 高度是**输入**，不是实测值（这是本件最重要的一条裁剪）──────────
 * 瀑布流的分配需要"先知道高度、再决定放哪一列"，而 QML 的 delegate 高度
 * 要**布局之后**才知道 —— 那是一个循环依赖。真要做，就得引入"先估后测、
 * 再重排"的收敛循环，而**收敛过程是抓图不确定性的来源**（同一份源码
 * 可能在第一帧与第二帧给出不同的图）。
 *
 * 所以本件把高度作为**输入**：`model` 每一项给出自己的高度。
 *
 *     QSkinMasonry {
 *         model: [ { h: 120 }, { h: 80 }, { h: 160 } ]
 *         heightField: "h"
 *         delegate: Rectangle { ... }
 *     }
 *
 * 调用方（或示例屏）在喂数据之前先知道高度 —— 图片场景可以读原始尺寸、
 * 卡片场景可以按内容行数估。这与本仓另外两处同一种处置：
 * `QSkinTextarea` 用"行数 × 行高"而不是实测、`QSkinCalendar` 用固定格高。
 *
 * **刻意不做** `autoHeight`（实测 delegate 高度后重排）：理由见上，
 * 它会让这个件的图变成"看运气"。要它的话，调用方自己测完再喂进来，
 * 两步走同样能达成，而且每一步都是确定的。
 *
 * ── delegate 契约（与 QSkinList 同一份）────────────────────────────────
 *     delegate:  Component {
 *         Rectangle {
 *             property var modelData     // 注入：当前数据项
 *             property int index         // 注入：当前下标
 *         }
 *     }
 * 注入走 `Loader.onLoaded` 而**不是** `Binding` —— 理由与 QSkinList 那里
 * 逐字相同（Binding 会无条件赋值，delegate 忘了声明就成了每帧一条警告）。
 *
 * ── 尺寸怎么定 ────────────────────────────────────────────────────────
 * `columns` 给 0 时按 `minColumnWidth` 自动算（`MasonryUtil.columnsFor`）。
 * `implicitHeight` 由 util 报回的总高决定 —— 注意它是**最长列的底边**，
 * 不含末项之后的缝（那条缝会让容器底部多出一块空白，而看起来"只是
 * padding 大了一点"）。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 输入 ══════════════════════ */

    /** JS 数组。元素可以是数字（就是高度），也可以是对象（按 heightField 取） */
    property var model: []

    /** 对象元素里"高度"的字段名 */
    property string heightField: "height"

    /** 条目模板。根对象应声明 `property var modelData` / `property int index` */
    property Component delegate: null

    /** 固定列数；0 = 按 minColumnWidth 自动 */
    property int columns: 0

    /** 自动模式下的每列最小宽度 */
    property int minColumnWidth: 200

    /** 列间距与行间距（同一个值） */
    property int gap: Theme.space.md

    /* ══════════════════════ 派生 ══════════════════════ */

    /** 实际列数 */
    readonly property int columnCount:
        root.columns > 0 ? root.columns
                         : MasonryUtil.columnsFor(root.width, root.minColumnWidth, root.gap)

    readonly property var heights: {
        var m = root.model
        if (m === null || m === undefined || m.length === undefined) return []
        var out = []
        for (var i = 0; i < m.length; ++i) {
            var it = m[i]
            if (typeof it === "number") out.push(it)
            else if (it !== null && it !== undefined) out.push(it[root.heightField])
            else out.push(0)
        }
        return out
    }

    /** 分配结果。全部几何都在 MasonryUtil 里。
     *  名字刻意不叫 `layout` —— 那个词在 QtQuick.Layouts 的语境里已经有
     *  一层意思（attached `Layout` + `layout` 相关的算法），一个同名的
     *  自定义属性会让后来读代码的人先怀疑三秒它是哪边的。 */
    readonly property var layoutResult: MasonryUtil.layout(root.heights, root.columnCount,
                                                           root.gap, root.width)

    readonly property var items: root.layoutResult.items
    readonly property real columnWidth: root.layoutResult.colWidth

    /** 兜底槽位：越界或被跳过时不至于让 delegate 读到 undefined */
    readonly property var _zeroSlot: ({ x: 0, y: 0, w: 0, h: 0, col: -1, index: -1 })

    implicitHeight: root.layoutResult.contentHeight

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 第 i 项的槽位（公开给冒烟测试与像素核验读同一个数） */
    function slotAt(i) {
        var its = root.items
        if (i === null || i === undefined || i < 0 || i >= its.length) return root._zeroSlot
        return its[i]
    }

    /* ══════════════════════ 绘制 ══════════════════════ */

    Repeater {
        model: root.model

        /* delegate 抽成顶层 Component —— 内联 delegate 会被 qmllint 判成
         * 新作用域（`QSkinList` 的 rowComp 也是这个写法）。 */
        delegate: cellComp
    }

    /* ── delegate 的绑定引用外层 id（root / Theme）—— 完整调查见
     * `QSkinCalendar.qml` 文件头，处置取第三条（局部关掉），与 QSkinKbd 同款。 */
    // qmllint disable unqualified
    Component {
        id: cellComp

        Item {
            id: cell

            property int index
            property var modelData

            readonly property var slot: root.slotAt(cell.index)

            x: cell.slot.x
            y: cell.slot.y
            width:  cell.slot.w
            height: cell.slot.h

            Loader {
                id: cellLoader

                anchors.fill: parent
                sourceComponent: root.delegate

                /* 数据注入走 onLoaded 而不是 Binding —— 理由与 QSkinList
                 * 那里逐字相同：Binding 会无条件赋值，delegate 忘了声明
                 * modelData 时就变成每帧一条警告；onLoaded 只跑一次。 */
                onLoaded: {
                    if (!cellLoader.item) return
                    cellLoader.item.modelData = cell.modelData
                    cellLoader.item.index = cell.index
                }
            }
        }
    }
    // qmllint enable unqualified
}
