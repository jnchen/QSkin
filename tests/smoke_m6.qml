/****************************************************************************
 * QSkin · 冒烟测试 —— M6：QSkinTable 排序 / 多选
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
    property int sortEvents: 0
    property int selectionEvents: 0

    function expect(ok) { if (!ok) root.failures++ }

    QSkinTable {
        id: table

        width: 400
        checkable: true
        columns: [
            { title: "文件名", dataIndex: "name", width: 200, sortable: true },
            { title: "大小",   dataIndex: "size", align: "right", sortable: true },
            { title: "状态",   dataIndex: "status" }
        ]
        rows: [
            { name: "b.qml", size: 12, status: "草稿" },
            { name: "a.qml", size: 4,  status: "已同步" },
            { name: "c.qml", size: 9,  status: "评审中" }
        ]
        onSortChanged:     root.sortEvents++
        onSelectionChanged: root.selectionEvents++
    }

    /* 无 checkbox 的表：验证 colLayout 在两种模式下的偏移差 */
    QSkinTable {
        id: plainTable

        width: 400
        columns: [{ title: "A", dataIndex: "a", width: 200 }, { title: "B", dataIndex: "b" }]
    }

    Timer { id: stage1Timer; interval: 300; running: true; onTriggered: root.stage1() }

    function stage1() {
        /* [0] 未排序：displayRows 与 rows 同序，数据下标 = 显示下标 */
        root.expect(table.displayRows[0] === table.rows[0]
                    && table._sourceIndex(2) === 2)

        /* [1] colLayout：checkable 时首列右移一个 checkbox 列宽；
         *     无 checkbox 时从 0 起 */
        root.expect(table.colLayout.xs[0] === table.checkColumnWidth
                    && plainTable.colLayout.xs[0] === 0
                    && plainTable.colLayout.xs[1] === 200)

        /* [2] 点击排序列：size 升序 → 显示顺序 a(4) c(9) b(12)，
         *     再点一次 → 降序 b c a；sortChanged 信号同步触发 */
        table._toggleSort(1)
        table._toggleSort(1)
        root.expect(table.sortColumn === 1 && table.sortDirection === "desc"
                    && table.displayRows[0].name === "b.qml"
                    && table.displayRows[2].name === "a.qml"
                    && root.sortEvents === 2)

        /* [3] 两套下标换算：降序下显示 0 = 数据 0（b.qml），显示 2 = 数据 1（a.qml） */
        root.expect(table._sourceIndex(0) === 0
                    && table._sourceIndex(2) === 1)

        /* [4] 勾选显示行 2（数据 a.qml）：selectedIndexes 存数据下标 1 */
        table._viewToggleCheck(2)
        root.expect(table.selectedIndexes.length === 1
                    && table.selectedIndexes[0] === 1
                    && root.selectionEvents === 1)

        /* [5] 排序翻回升序：勾选仍跟着数据走 —— 显示行 0（a.qml）仍是勾选态 */
        table._toggleSort(1)
        root.expect(table.sortDirection === "asc"
                    && table._viewIsChecked(0) === true
                    && table._viewIsChecked(1) === false)

        /* [6] 三态：勾 1 条 → _someSelected；全选 → _allSelected、selectedIndexes 全量 */
        root.expect(table._someSelected && !table._allSelected)
        table._toggleAll()
        root.expect(table._allSelected
                    && table.selectedIndexes.length === 3
                    && root.selectionEvents === 2)

        /* [7] 半选点击进全选的反向：全选状态下再点 → 清空；
         *     复合断言收尾 */
        table._toggleAll()
        root.expect(table.selectedIndexes.length === 0
                    && !table._someSelected && !table._allSelected)

        Qt.exit(root.failures & 0xFF)
    }
}
