/****************************************************************************
 * QSkin · 冒烟测试 —— M7：QSkinPagination / QSkinTable 客户端分页
 *
 * 断言写法见 tools/test.sh 文件头：≤ 8 条，bit n = 断言 [n]。
 * 尺寸断言必须在事件循环跑过至少一轮之后（Layouts 的 polish 时序）。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int failures: 0
    property int pageEvents: 0
    property int tablePageEvents: 0

    function expect(ok) { if (!ok) root.failures++ }

    /* 105 条 / 每页 10 → 11 页：能触发省略号窗口 */
    QSkinPagination {
        id: pager

        total: 105
        page: 5
        pageSize: 10
        onPaged: root.pageEvents++
    }

    /* 8 条小表：页数 ≤ 7 全显，不出现省略号 */
    QSkinPagination {
        id: smallPager

        total: 32
        page: 2
        pageSize: 8      /* → 4 页 */
    }

    QSkinPagination { id: emptyPager; total: 0; pageSize: 10 }

    QSkinTable {
        id: table

        width: 400
        pageSize: 4
        columns: [{ title: "名", dataIndex: "name", sortable: true }]
        rows: [
            { name: "r0" }, { name: "r1" }, { name: "r2" }, { name: "r3" },
            { name: "r4" }, { name: "r5" }, { name: "r6" }, { name: "r7" },
            { name: "r8" }, { name: "r9" }
        ]
        onPaged: root.tablePageEvents++
    }

    Timer { id: stage1Timer; interval: 300; running: true; onTriggered: root.stage1() }

    function stage1() {
        /* [0] 页码窗口：105/10 = 11 页，page 5 → [1,"..",3,4,5,6,7,"..",11] */
        var w = pager._pageList()
        root.expect(pager.pageCount === 11
                    && w.length === 9
                    && w[0] === 1 && w[1] === ".." && w[4] === 5
                    && w[7] === ".." && w[8] === 11)

        /* [1] 窗口贴边省略号自然消失：page 2 → from=2 起左无省略号 */
        pager.page = 2
        var w2 = pager._pageList()
        root.expect(w2[0] === 1 && w2[1] === 2 && w2[2] === 3 && w2[3] === 4
                    && w2[w2.length - 1] === 11 && w2[w2.length - 2] === "..")

        /* [2] 小表全显 + 空表退化：4 页无省略号；total 0 → pageCount 0 */
        root.expect(smallPager.pageCount === 4
                    && smallPager._pageList().length === 4
                    && emptyPager.pageCount === 0
                    && emptyPager._pageList().length === 0)

        /* [3] goTo 夹取 + 信号：超界夹到 11；相同页不触发 */
        pager.goTo(99)
        pager.goTo(11)
        root.expect(pager.page === 11 && root.pageEvents === 1)

        /* [4] 表格客户端分页：10 行 / 每页 4 → 3 页，首页 4 行 */
        root.expect(table.pageCount === 3
                    && table.viewRowCount === 4
                    && table.displayRows[0].name === "r0"
                    && table.displayRows[3].name === "r3")

        /* [5] 翻页切片 + 显示下标→数据下标：第 2 页首行是 r4，源下标 4；
         *     翻页把显示位置选中清空 */
        table.page = 2
        root.expect(table.displayRows[0].name === "r4"
                    && table._sourceIndex(0) === 4
                    && table.selectedRow === -1)

        /* [6] 排序 + 分页叠加：回第 1 页按 name 降序 → 首行 r9，源下标 9 */
        table.page = 1
        table.sortColumn = 0
        table.sortDirection = "desc"
        root.expect(table.displayRows[0].name === "r9"
                    && table._sourceIndex(0) === 9
                    && table.displayRows.length === 4)

        /* [7] 勾选跨页跟数据 + 页数缩水自动夹取：
         *     勾 r9（源 9）→ 回未排序翻到末页，r9 仍勾选可见；
         *     rows 缩到 5 条 → pageCount 3→2，page 3 夹到 2，paged 发 1 次 */
        table._viewToggleCheck(0)
        table.sortColumn = -1
        table.page = 3
        var chkCross = table._viewIsChecked(0) === false
                        && table._viewIsChecked(1) === true
                        && table.selectedIndexes.length === 1
        table.rows = table.rows.slice(0, 5)
        root.expect(chkCross
                    && table.selectedIndexes[0] === 9
                    && table.pageCount === 2
                    && table.page === 2
                    && root.tablePageEvents === 1)

        Qt.exit(root.failures & 0xFF)
    }
}
