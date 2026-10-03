/****************************************************************************
 * QSkin · 冒烟测试 —— M13：QSkinTable 横向滚动 + 左侧固定列
 *
 * 断言写法见 tools/test.sh 文件头：≤ 8 条，bit n = 断言 [n]。
 *
 * ── 这轮要守的核心不变量 ───────────────────────────────────────────────
 * 「固定列」听起来是个视觉功能，实际它先要一个**前提**：内容可以比容器
 * 宽。M12 之前列布局永远恰好撑满容器，压根没有"装不下"的时候 ——
 * 所以这轮的真正改动是给布局引入"内容坐标系"，固定列只是它的第一个
 * 消费者。三条不变量必须同时成立，少一条整个设计就塌：
 *
 *   ① `contentWidth` 是列布局的基准 —— 等分分的是内容宽的剩余，
 *      拖宽的上限也以内容宽为准。否则拖宽会被容器卡住，横滚等于白做。
 *   ② `colLayout` 与 `fixedColumns` **完全解耦** —— 它是内容坐标，
 *      "钉住哪几列"只影响分区宿主的 x，不影响任何一个列宽或 x。
 *      这正是双区结构能让单元格代码一行不改的原因。
 *   ③ `checkable` 的 checkbox 列天然属于固定区，即使一段数据列都没固定。
 *
 * 断言分工：
 *   [0] 横向溢出的判据（内容总宽 - 固定区宽 - 视口宽）+ scrollTo 钳制
 *   [1] 等分基准 = 内容宽（不是容器宽）
 *   [2] 固定区宽 = checkbox 列（若有）+ 前 N 列
 *   [3] 固定列数夹取 + 全列固定即不可滚
 *   [4] 拖宽上限以内容宽为基准（M13 的关键差异）+ 快照仍冻结其余列
 *   [5] 零回归：contentWidth = 0 时上限仍是「容器宽 - 右留位」
 *   [6] colLayout 与 fixedColumns 解耦
 *   [7] 正交性：排序 / 分页 / 多选不受横滚与固定列影响
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int failures: 0

    function bit(n, ok) { if (!ok) root.failures |= (1 << n) }

    /* ══════════════════ 被测实例 ══════════════════ */

    /* 主表：内容 1200 宽塞进 400 宽的容器，最左 1 列钉住。
     * 全列显式宽 → 列宽计算不受等分影响，数字好核。 */
    QSkinTable {
        id: wide

        width: 400
        contentWidth: 1200
        fixedColumns: 1
        columns: [
            { title: "文件名",   dataIndex: "name",  width: 200 },
            { title: "大小",     dataIndex: "size",  width: 300, align: "right" },
            { title: "修改时间", dataIndex: "mtime", width: 300 },
            { title: "状态",     dataIndex: "status", width: 400 }
        ]
        rows: [
            { name: "index.qml",   size: 4,   mtime: "09-05 14:02", status: "已同步" },
            { name: "sidebar.qml", size: 12,  mtime: "09-05 11:47", status: "草稿" },
            { name: "table.qml",   size: 128, mtime: "09-04 20:15", status: "已同步" }
        ]
    }

    /* 对照：同一套列定义、contentWidth = 0（撑满容器）→ 不该出现横滚 */
    QSkinTable {
        id: fit
        width: 400
        columns: [
            { title: "文件名", dataIndex: "name", width: 200 },
            { title: "大小",   dataIndex: "size" },
            { title: "状态",   dataIndex: "status" }
        ]
        rows: [{ name: "a", size: 1, status: "x" }]
    }

    /* 新能力：未定宽列平分**内容宽**的剩余（不是容器宽的剩余） */
    QSkinTable {
        id: shareWide
        width: 400
        contentWidth: 1200
        columns: [
            { title: "文件名", dataIndex: "name", width: 200 },
            { title: "大小",   dataIndex: "size" },
            { title: "状态",   dataIndex: "status" }
        ]
        rows: [{ name: "a", size: 1, status: "x" }]
    }

    /* 无 checkable、无固定列 → 固定区宽必须正好是 0（而不是留一条缝） */
    QSkinTable {
        id: plain
        width: 400
        columns: [{ title: "A", dataIndex: "a" }, { title: "B", dataIndex: "b" }]
        rows: [{ a: "1", b: "2" }]
    }

    /* checkable + 固定 1 列：固定区 = checkbox 列 + 首列 */
    QSkinTable {
        id: checked
        width: 400
        contentWidth: 1000
        checkable: true
        fixedColumns: 1
        columns: [
            { title: "文件名", dataIndex: "name", width: 200 },
            { title: "大小",   dataIndex: "size", width: 400 },
            { title: "状态",   dataIndex: "status", width: 400 }
        ]
        rows: [{ name: "a", size: 1, status: "x" }]
    }

    /* checkable 但一列都不固定：checkbox 列自己构成固定区 ——
     * 它不在 columns 里，用户没法通过任何列定义把它捞回来，
     * 所以它必须自动钉住 */
    QSkinTable {
        id: checkedOnly
        width: 400
        contentWidth: 800
        checkable: true
        columns: [{ title: "文件名", dataIndex: "name", width: 800 }]
        rows: [{ name: "a" }]
    }

    /* 固定列数越界 → 夹到 columnCount；全列固定 = 没有可滚的东西 */
    QSkinTable {
        id: clampHi
        width: 400
        contentWidth: 1200
        fixedColumns: 99
        columns: [
            { title: "A", dataIndex: "a", width: 300 },
            { title: "B", dataIndex: "b", width: 300 },
            { title: "C", dataIndex: "c", width: 300 },
            { title: "D", dataIndex: "d", width: 300 }
        ]
        rows: [{ a: 1, b: 2, c: 3, d: 4 }]
    }

    QSkinTable {
        id: clampLo
        width: 400
        fixedColumns: -3
        columns: [{ title: "A", dataIndex: "a" }, { title: "B", dataIndex: "b" }]
        rows: [{ a: 1, b: 2 }]
    }

    /* 零回归对照：contentWidth = 0，4 列各 100 → 拖宽上限仍是
     * 「容器宽 - 右侧每列 minColumnWidth」= 400 - 144 = 256 */
    QSkinTable {
        id: fit4
        width: 400
        columns: [
            { title: "A", dataIndex: "a", width: 100, resizable: true },
            { title: "B", dataIndex: "b", width: 100 },
            { title: "C", dataIndex: "c", width: 100 },
            { title: "D", dataIndex: "d", width: 100 }
        ]
        rows: [{ a: 1, b: 2, c: 3, d: 4 }]
    }

    /* 解耦对照：切 fixedColumns 前后，colLayout 一个数都不该变 */
    QSkinTable {
        id: decouple
        width: 400
        contentWidth: 1000
        columns: [
            { title: "A", dataIndex: "a", width: 200 },
            { title: "B", dataIndex: "b" },
            { title: "C", dataIndex: "c" },
            { title: "D", dataIndex: "d" }
        ]
        rows: [{ a: 1, b: 2, c: 3, d: 4 }]
    }

    /* 正交性：干净的横滚 + 固定列配置，用来验证排序 / 分页 / 多选 */
    QSkinTable {
        id: ortho
        width: 600
        contentWidth: 1400
        fixedColumns: 1
        columns: [
            { title: "文件名",   dataIndex: "name", width: 200 },
            { title: "大小",     dataIndex: "size", width: 400, sortable: true },
            { title: "修改时间", dataIndex: "mtime", width: 400 },
            { title: "状态",     dataIndex: "status", width: 400 }
        ]
        rows: [
            { name: "e", size: 5, mtime: "0", status: "x" },
            { name: "a", size: 1, mtime: "0", status: "x" },
            { name: "c", size: 3, mtime: "0", status: "x" },
            { name: "d", size: 4, mtime: "0", status: "x" },
            { name: "b", size: 2, mtime: "0", status: "x" }
        ]
    }

    Timer {
        interval: 400
        running: true
        repeat: false
        onTriggered: root.check()
    }

    function check() {
        /* ══════════════════ [0] 横向溢出的判据 ══════════════════ */

        /* 内容 1200、固定区 200、视口 400 → 可滚内容 1000，能滚 800。
         * 这三个数分别是「内容实际有多宽」「其中多少是可滚的」
         * 「可滚的那部分比视口多出多少」，各错一个都会让横滚要么
         * 滚不到底、要么能滚出空白。 */
        var ok0 = wide._contentTotal === 1200
                  && wide._scrollableContentWidth === 1000
                  && wide._maxScrollX === 800
                  && wide._canScrollX === true

        /* 对照：同一套 3 列的两张表，只是 contentWidth 不同 */
        ok0 = ok0 && fit._maxScrollX === 0
                  && fit._canScrollX === false
                  && fit._contentTotal === 400

        /* 滚动位置 API：越界写入必须被钳住。scrollX 是 body.contentX 的别名，
         * 直接写它不会钳制，而 StopAtBounds 也不会把内容弹回来 ——
         * 结果就是表格右边露出一大片空白。所以对外暴露的是 scrollTo()。 */
        wide.scrollTo(99999)
        ok0 = ok0 && wide.scrollX === wide._maxScrollX     /* 800 */
        wide.scrollTo(-50)
        ok0 = ok0 && wide.scrollX === 0

        root.bit(0, ok0)

        /* ══════════════════ [1] 等分基准 = 内容宽 ══════════════════ */

        /* shareWide 只给首列定宽 200，另两列等分 (1200-200)/2 = 500。
         * 若还是按容器宽算，会得到 (400-200)/2 = 100 —— 横滚区里
         * 右侧会永远空着一大片，且滚到底也看不到东西。 */
        var ok1 = shareWide.colLayout.widths[1] === 500
                  && shareWide.colLayout.widths[2] === 500
                  && shareWide.colLayout.xs[1] === 200
                  && shareWide.colLayout.xs[2] === 700
                  && shareWide._contentTotal === 1200

        /* fit 是同一套列定义、contentWidth = 0 → 回到按容器宽等分 */
        ok1 = ok1 && fit.colLayout.widths[1] === 100
                  && fit.colLayout.widths[2] === 100

        root.bit(1, ok1)

        /* ══════════════════ [2] 固定区宽度 ══════════════════ */

        var ok2 = wide._fixedWidth === 200          /* 1 列 × 200 */
                  && wide._fixedCount === 1

        /* 没有 checkable、也没固定列 → 严格为 0，固定区整个不出现 */
        ok2 = ok2 && plain._fixedWidth === 0
                  && plain._fixedCount === 0

        /* checkable 的前置列宽要算进去，否则首列会被 checkbox 压掉一截 */
        ok2 = ok2 && checked._fixedWidth === checked.checkColumnWidth + 200

        /* **一条数据列都不固定时，checkbox 列自己就是固定区** ——
         * 它是"行选择入口"，横滚把它带走就再也点不到全选了 */
        ok2 = ok2 && checkedOnly._fixedCount === 0
                  && checkedOnly._fixedWidth === checkedOnly.checkColumnWidth

        root.bit(2, ok2)

        /* ══════════════════ [3] 固定列数夹取 ══════════════════ */

        /* 上界：99 → 夹到 4；全列固定 → 没有可滚的东西了，
         * 可滚内容宽与滚动上限都必须归零（而不是留一个能滚出空白的范围） */
        var ok3 = clampHi._fixedCount === 4
                  && clampHi._fixedWidth === 1200
                  && clampHi._scrollableContentWidth === 0
                  && clampHi._maxScrollX === 0

        /* 下界：负数 → 0，且固定区宽必须归零 */
        ok3 = ok3 && clampLo._fixedCount === 0
                  && clampLo._fixedWidth === 0

        root.bit(3, ok3)

        /* ══════════════════ [4] 拖宽上限以内容宽为基准 ══════════════════ */

        /* 容器只有 400，但内容宽 1200 —— 拖到 999 必须**不被容器卡住**。
         * 上限 = 内容宽 - 右侧每列 minColumnWidth(48) × 3 = 1056，
         * 所以 999 原样落地。M12 的实现会把它压到 400-144 = 256，
         * 那样子在有横滚的表格里拖宽等于拖不动。 */
        wide.resetColumnWidths()
        wide.setColumnWidth(0, 999)
        var ok4 = wide.colLayout.widths[0] === 999
                  && wide.colLayout.xs[1] === 999        /* 后续列跟着右移 */

        /* 快照语义（M12）必须原样保留：拖一列会把其余列一起冻结 */
        ok4 = ok4 && wide.colLayout.widths[1] === 300
                  && wide.colLayout.widths[2] === 300
                  && wide.colLayout.widths[3] === 400

        root.bit(4, ok4)

        /* ══════════════════ [5] contentWidth = 0 零回归 ══════════════════ */

        /* 没开横滚时，上限的基准必须还是容器宽 ——
         * 这一条就是"M13 没有偷偷改掉 M12 行为"的守门人 */
        var ok5 = fit4._layoutWidth === 400
                  && fit4._maxScrollX === 0
                  && fit4._canScrollX === false

        fit4.resetColumnWidths()
        fit4.setColumnWidth(0, 999)
        ok5 = ok5 && fit4.colLayout.widths[0] === 400 - fit4.minColumnWidth * 3
                  && fit4.colLayout.widths[1] === 100
                  && fit4.colLayout.widths[2] === 100

        root.bit(5, ok5)

        /* ══════════════════ [6] colLayout 与 fixedColumns 解耦 ══════════════════ */

        /* 这是双区结构成立的地基：colLayout 是**内容坐标**，
         * "钉住哪几列"只改分区宿主的 x，一个列宽 / 列 x 都不该动。
         * 若这里错了，固定列会连带改变列宽计算，M12 的那几条断言
         * （以及所有依赖 colLayout 的代码）会一起失效。
         *
         * 把数值抄进数组再比 —— 直接存两次 colLayout 的引用可能
         * 是同一个 JS 对象，那就成了永真断言。 */
        decouple.fixedColumns = 0
        var dA = decouple.colLayout
        var wA = [dA.widths[0], dA.widths[1], dA.widths[2], dA.widths[3]]
        var xA = [dA.xs[1], dA.xs[2], dA.xs[3]]

        decouple.fixedColumns = 2
        var dB = decouple.colLayout
        var wB = [dB.widths[0], dB.widths[1], dB.widths[2], dB.widths[3]]
        var xB = [dB.xs[1], dB.xs[2], dB.xs[3]]

        var ok6 = wA[0] === wB[0] && wA[1] === wB[1]
                  && wA[2] === wB[2] && wA[3] === wB[3]
                  && xA[0] === xB[0] && xA[1] === xB[1] && xA[2] === xB[2]
                  /* 同时确认 fixedColumns 真的生效了（否则是"两边都没动"的假通过）*/
                  && decouple._fixedCount === 2
                  && decouple._fixedWidth === wB[0] + wB[1]

        root.bit(6, ok6)

        /* ══════════════════ [7] 正交性 ══════════════════ */

        /* 横滚 + 固定列是"视图层"的事，不该渗进排序 / 分页 / 多选
         * 这三套各自独立的下标体系里 */
        var ok7 = ortho.contentWidth === 1400 && ortho.fixedColumns === 1
                  && ortho._maxScrollX === 800

        ortho._toggleSort(1)
        ok7 = ok7 && ortho.sortColumn === 1 && ortho.sortDirection === "asc"
                  && ortho.displayRows[0].size === 1          /* 最小的排到最前 */

        /* 排序改的是行序，不该碰到列几何或横滚范围 */
        ok7 = ok7 && ortho._maxScrollX === 800
                  && ortho.colLayout.widths[0] === 200
                  && ortho.colLayout.xs[3] === 1000

        /* 打开多选后 checkbox 列并入固定区 */
        ortho.checkable = true
        ok7 = ok7 && ortho._fixedWidth === ortho.checkColumnWidth + 200
        ortho._toggleCheck(0)
        ok7 = ok7 && ortho.selectedIndexes.length === 1 && ortho.selectedIndexes[0] === 0

        /* 分页照旧：5 行 / 每页 2 → 3 页 */
        ortho.pageSize = 2
        ortho.page = 1
        ok7 = ok7 && ortho.pageCount === 3 && ortho.displayRows.length === 2

        root.bit(7, ok7)

        Qt.exit(Math.min(255, root.failures))
    }
}
