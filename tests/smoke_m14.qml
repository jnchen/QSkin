/****************************************************************************
 * QSkin · 冒烟测试 —— M14：QSkinTable 树形展开
 *
 * 断言写法见 tools/test.sh 文件头：≤ 8 条，bit n = 断言 [n]。
 *
 * ── 这轮要守的核心不变量 ───────────────────────────────────────────────
 * 树形让"行"从"rows 的一个元素"变成"rows 展平后的一段"，于是 M6 建立的
 * 两套下标体系（显示下标 / 数据下标）第一次出现**结构性**的错位：
 * 折叠会藏行、同级排序会换序，两者都会让 viewIndex ≠ rows 下标。
 * 四条不变量必须同时成立：
 *
 *   ① 展平只吐**可见**行，且折叠是**整枝**剪掉 —— 父收起时子辈即使
 *      自己处于展开态也不出现。
 *   ② 排序只作用于同级兄弟，**绝不跨层搬行**（换了爹树就散了）。
 *      判据不是"顺序对不对"，而是"键→层级的归属一个都没变"。
 *   ③ 分页数按**可见行**算 —— 折叠掉的分支不该占页码；
 *      `rowMeta` 必须与 `displayRows` 同步切片，否则缩进会串行。
 *   ④ 树形的 `_sourceIndex` 不能走 M6 那条快路径，也不能靠对象反查
 *      （嵌套节点不在 rows 里，反查必然落空）。
 *
 * 断言分工：
 *   [0] 展平顺序 / 层级 / 键 / sourceIndex（含嵌套节点 -1 与下标陷阱）
 *   [1] 折叠整枝剪枝 + expandAll / collapseAll
 *   [2] 同级排序不跨层（升 / 降各一次，层级归属不变）
 *   [3] 分页按可见行（页数、切片、rowMeta 同步、折叠后页数缩水并夹回页码）
 *   [4] 非树形零回归（displayRows 同引用 / rowMeta 空 / 排序分页照旧）
 *   [5] 勾选列的几何占位（M15 起 checkable 与 treeMode 不再互斥）
 *   [6] defaultExpandAll 语义 + 显式状态 + 换数据后新节点吃默认值
 *   [7] 缩进几何：上限存在、层级真的传到界面、窄列停止缩进
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int failures: 0

    function bit(n, ok) { if (!ok) root.failures |= (1 << n) }

    /* 测试用树：两层分支 + 一个三层深的分支。
     * 名称与 size 刻意错开，好让"同级排序"真的会换序：
     *   顶层            r1(C 工作, 10)、r2(B 生活, 5)
     *   r1 的子         c1(C1 甲, 30) → g1(G1 深)、c2(C2 乙, 20)
     *   r2 的子         c3(C3 丙, 40)
     * 不排序时的展开序：r1(0) c1(1) g1(2) c2(1) r2(0) c3(1) */
    property var nestedRows: [
        { id: "r1", name: "C 工作", size: 10, children: [
            { id: "c1", name: "C1 甲", size: 30, children: [
                { id: "g1", name: "G1 深", size: 1 }
            ] },
            { id: "c2", name: "C2 乙", size: 20 }
        ] },
        { id: "r2", name: "B 生活", size: 5, children: [
            { id: "c3", name: "C3 丙", size: 40 }
        ] }
    ]

    function metaKeys(t) {
        var out = []
        var ms = t.rowMeta
        for (var i = 0; i < ms.length; ++i) out.push(ms[i].key)
        return out.join(",")
    }

    /** "键:层级" 集合（排序后拼串）—— 证明"排序只换顺序，不动层级归属" */
    function pairSet(t) {
        var out = []
        var ms = t.rowMeta
        for (var i = 0; i < ms.length; ++i) out.push(ms[i].key + ":" + ms[i].level)
        out.sort()
        return out.join(",")
    }

    function findAll(node, pred, out) {
        if (out === undefined) out = []
        if (!node) return out
        if (pred(node)) out.push(node)
        var ch = node.children
        if (ch) for (var i = 0; i < ch.length; ++i) root.findAll(ch[i], pred, out)
        return out
    }

    /* ══════════════════ 被测实例 ══════════════════ */

    /* 主树。缩进三件套给成整数，断言里的算式才写得清楚 */
    QSkinTable {
        id: tree
        width: 400
        treeMode: true
        treeIndentWidth: 20
        treeChevronWidth: 16
        treeMinLabelWidth: 64
        columns: [
            { title: "名称", dataIndex: "name", width: 200 },
            { title: "大小", dataIndex: "size", width: 200, align: "right", sortable: true }
        ]
        rows: root.nestedRows
    }

    /* 非树形对照：同一份数据、同一套列，只差 treeMode */
    QSkinTable {
        id: flat
        width: 400
        columns: [
            { title: "名称", dataIndex: "name", width: 200 },
            { title: "大小", dataIndex: "size", width: 200, align: "right", sortable: true }
        ]
        rows: root.nestedRows
    }

    /* checkable + treeMode 同时开：M15 起两者共存，勾选列出现。
     * 两列都给显式宽，`_contentTotal` 才是可手算的定值 */
    QSkinTable {
        id: both
        width: 400
        checkable: true
        treeMode: true
        columns: [
            { title: "名称", dataIndex: "name", width: 200 },
            { title: "大小", dataIndex: "size", width: 200 }
        ]
        rows: root.nestedRows
    }

    /* 反向对照：只开 checkable → 勾选列照旧（证明互斥没有误伤非树形） */
    QSkinTable {
        id: chk
        width: 400
        checkable: true
        columns: [
            { title: "名称", dataIndex: "name", width: 200 },
            { title: "大小", dataIndex: "size", width: 200 }
        ]
        rows: [{ name: "a", size: 1 }]
    }

    /* 默认全展开，且一条显式状态都没有 */
    QSkinTable {
        id: defAll
        width: 400
        treeMode: true
        defaultExpandAll: true
        columns: [
            { title: "名称", dataIndex: "name", width: 200 },
            { title: "大小", dataIndex: "size" }
        ]
        rows: root.nestedRows
    }

    /* 窄树形列：100 宽扣掉内边距 / 箭头位 / 文字下限后上限算下来是 0，
     * 于是所有层级都退回 0 缩进（而不是把文字挤没） */
    QSkinTable {
        id: narrow
        width: 400
        treeMode: true
        treeIndentWidth: 20
        treeChevronWidth: 16
        treeMinLabelWidth: 64
        columns: [
            { title: "名称", dataIndex: "name", width: 100 },
            { title: "大小", dataIndex: "size", width: 300 }
        ]
        rows: root.nestedRows
    }

    Timer {
        interval: 400
        running: true
        repeat: false
        onTriggered: root.check()
    }

    function check() {
        /* ══════════════════ [0] 展平 / 层级 / 键 / 下标 ══════════════════ */

        /* 默认收起：只有两个根可见，且都是 0 层 */
        var ok0 = tree._viewTotal === 2
                  && tree.displayRows[0].id === "r1"
                  && tree.displayRows[1].id === "r2"

        var m0 = tree.rowMeta
        ok0 = ok0 && m0[0].key === "r1" && m0[0].level === 0
                  && m0[0].hasChildren === true && m0[0].expanded === false
                  && m0[0].parentKey === ""
                  && m0[1].key === "r2" && m0[1].level === 0

        /* 顶层节点的数据下标：它是 rows 里的位置 */
        ok0 = ok0 && tree._sourceIndex(0) === 0 && tree._sourceIndex(1) === 1

        tree.expandAll()

        var m1 = tree.rowMeta
        var levels = []
        for (var i = 0; i < m1.length; ++i) levels.push(m1[i].level)

        /* 层级不限深、顺序就是深度优先的展开序 */
        ok0 = ok0 && tree._viewTotal === 6
                  && root.metaKeys(tree) === "r1,c1,g1,c2,r2,c3"
                  && levels.join(",") === "0,1,2,1,0,1"

        /* 叶子 / 有子节点 / 父键 */
        ok0 = ok0 && m1[2].hasChildren === false
                  && m1[1].hasChildren === true
                  && m1[1].parentKey === "r1"
                  && m1[2].parentKey === "c1"

        /* **下标陷阱**：r2 在显示序里排第 5，数据下标却是 1 ——
         * 树形一旦折叠或同级排序，viewIndex 就再也不可能等于 rows 下标。
         * M6 那条"未排序就直接 return viewIndex"的快路径在这里会静默
         * 返回另一条数据的下标，所以树形必须走 rowMeta.sourceIndex。
         * 嵌套节点不在 rows 里，给 -1（而不是某个看似合理的数字）。 */
        ok0 = ok0 && tree._sourceIndex(4) === 1
                  && tree._sourceIndex(1) === -1

        root.bit(0, ok0)

        /* ══════════════════ [1] 折叠整枝剪枝 ══════════════════ */

        /* 全展开之后**单独**收起 r1：r1 那一枝整个消失 ——
         * 注意 c1 自己仍处于"显式展开"状态（expandAll 落的），
         * 但它的父收起了，所以它和 g1 都不该出现。
         * r2 那一枝不受影响，c3 照旧可见。 */
        tree.expandAll()
        tree.setExpanded("r1", false)

        var ok1 = tree._viewTotal === 3
                  && root.metaKeys(tree) === "r1,r2,c3"
                  && tree.rowMeta[0].expanded === false
                  && tree.isExpanded("c1") === true      /* 子辈状态没被改写 */
                  && tree._sourceIndex(2) === -1         /* c3 是嵌套节点 */

        tree.collapseAll()
        ok1 = ok1 && tree._viewTotal === 2 && root.metaKeys(tree) === "r1,r2"
                  && tree.expandedKeys.length === 0      /* 全收起 → 没有展开键 */

        tree.expandAll()
        ok1 = ok1 && tree._viewTotal === 6 && tree.expandedKeys.length === 6
                  && tree.isExpanded("g1") === true      /* 叶子也记状态，无害 */

        root.bit(1, ok1)

        /* ══════════════════ [2] 同级排序不跨层 ══════════════════ */

        /* 判据不是"顺序对不对"，而是**键 → 层级的归属一个都没变**：
         * 这直接对应"排序只重排兄弟，绝不跨层搬行"。
         * 若实现是"先把所有节点拍平再整体排序"，层级归属会立刻错乱。 */
        tree.expandAll()
        var before = root.pairSet(tree)

        tree._toggleSort(1)                            /* → asc（按 size） */
        var ok2 = tree.sortColumn === 1 && tree.sortDirection === "asc"
                  && root.metaKeys(tree) === "r2,c3,r1,c2,c1,g1"
                  && root.pairSet(tree) === before

        tree._toggleSort(1)                            /* → desc */
        ok2 = ok2 && tree.sortDirection === "desc"
                  && root.metaKeys(tree) === "r1,c1,g1,c2,r2,c3"
                  && root.pairSet(tree) === before

        /* m0 与 m1 的层级序列都属于同一棵树 —— 顺手确认排序没有把
         * 三层深的那个分支拍平 */
        ok2 = ok2 && tree.rowMeta[2].level === 2 && tree.rowMeta[2].key === "g1"

        tree.sortColumn = -1                           /* 复位，后面的断言要用展开序 */

        root.bit(2, ok2)

        /* ══════════════════ [3] 分页按可见行算 ══════════════════ */

        tree.expandAll()
        tree.pageSize = 2
        tree.page = 1

        var ok3 = tree._viewTotal === 6
                  && tree.pageCount === 3                  /* 页数按可见行，不按 rowCount */
                  && tree.viewRowCount === 2
                  && tree.displayRows[0].id === "r1"

        tree.page = 3
        ok3 = ok3 && tree.displayRows.length === 2
                  && tree.displayRows[0].id === "r2"
                  /* rowMeta 必须与 displayRows **同步切片** ——
                   * 不同步的话，第二页的行会套着第一页的缩进 */
                  && tree.rowMeta[0].key === "r2"
                  && tree.rowMeta[0].level === 0

        /* 折叠到只剩 2 行 → 页数缩到 1，页码必须被夹回来（M7 的既有行为） */
        tree.collapseAll()
        ok3 = ok3 && tree._viewTotal === 2
                  && tree.pageCount === 1
                  && tree.page === 1
                  && tree.displayRows.length === 2
                  && tree.displayRows[1].id === "r2"

        tree.pageSize = 0
        tree.page = 1
        tree.expandAll()

        root.bit(3, ok3)

        /* ══════════════════ [4] 非树形零回归 ══════════════════ */

        /* 未排序、未分页 → displayRows 与 rows 是**同一个数组引用**
         * （M5 起的约定：不排序就不复制）。M14 把行来源换成了 _view 管线，
         * 这一条是"管线没有偷偷变成每次都复制"的守门人。 */
        var ok4 = flat.displayRows === flat.rows
                  && flat.rowMeta.length === 0
                  && flat._viewTotal === flat.rowCount

        flat._toggleSort(1)
        ok4 = ok4 && flat.sortDirection === "asc"
                  && flat.displayRows[0].size === 5
                  && flat._sourceIndex(0) === 1            /* 数据下标反查照旧 */

        flat.pageSize = 1
        flat.page = 2
        ok4 = ok4 && flat.pageCount === 2
                  && flat.displayRows.length === 1
                  && flat.displayRows[0].size === 10
                  && flat._sourceIndex(0) === 0

        flat.pageSize = 0
        flat.page = 1
        flat.sortColumn = -1

        root.bit(4, ok4)

        /* ══════════════════ [5] 勾选列的几何占位 ══════════════════ */

        /* M14 时这里断言的是「互斥：树形下勾选列不出现」。M15 把那条边界
         * 撤了 —— 树形的问题在**寻址方式**（改用 selectedKeys），
         * 不在"能不能勾"，所以判据退回纯粹的 `checkable`。
         *
         * 这一条因此改守**几何**：勾选列一旦出现，就必须在前置位占宽，
         * 而且不占掉等分列的额度 —— 树形 / 非树形两边的算法必须一致。 */
        var ok5 = both._showCheckColumn === true
                  && both._fixedWidth === both.checkColumnWidth
                  && both._contentTotal === both.checkColumnWidth + 400
                  && both.colLayout.xs[0] === both.checkColumnWidth
                  && both.colLayout.widths[1] === 200      /* 两列都显式 200 */

        /* 非树形的勾选列照旧 —— 同一套判据的对照 */
        ok5 = ok5 && chk._showCheckColumn === true
                  && chk._fixedWidth === chk.checkColumnWidth
                  && chk._contentTotal === chk.checkColumnWidth + 400
                  && chk.colLayout.xs[0] === chk.checkColumnWidth

        root.bit(5, ok5)

        /* ══════════════════ [6] defaultExpandAll 与显式状态 ══════════════════ */

        /* 一条显式状态都没有，全靠默认值 */
        var ok6 = defAll._viewTotal === 6
                  && defAll.expandedKeys.length === 0
                  && defAll.isExpanded("r1") === true

        /* 收起一个：只有它被落成显式状态，其余仍然"无记录"（吃默认值）——
         * 这正是"只记被改过的节点"的语义，也是换数据不用重置的原因 */
        defAll.setExpanded("r1", false)
        ok6 = ok6 && defAll._viewTotal === 3            /* r1 那一枝收掉 */
                  && defAll.expandedKeys.length === 0
                  && defAll.expandedKeys.indexOf("r1") < 0
                  && defAll.isExpanded("r1") === false
                  && defAll.isExpanded("c1") === true   /* 无记录 → 默认展开 */

        /* 换数据：r1 是**显式**收起 → 保持收起；
         * r3 / c9 是全新节点 → 没有记录，照旧吃 defaultExpandAll。
         * 这就是"不按结构路径记状态"换来的好处：换数据不需要任何重置逻辑。 */
        defAll.rows = [
            { id: "r1", name: "C 工作", size: 10, children: [
                { id: "c1", name: "C1 甲", size: 30 }
            ] },
            { id: "r3", name: "R3 新", size: 7, children: [
                { id: "c9", name: "C9 新", size: 8 }
            ] }
        ]
        ok6 = ok6 && defAll._viewTotal === 3
                  && root.metaKeys(defAll) === "r1,r3,c9"
                  && defAll.isExpanded("r1") === false
                  && defAll.isExpanded("r3") === true

        root.bit(6, ok6)

        /* ══════════════════ [7] 缩进几何 ══════════════════ */

        /* 上限 = 列宽 − 左右内边距 − 箭头位 − 文字下限
         *      = 200 − 24 − 16 − 64 = 96（够用，不夹）
         *      = 100 − 24 − 16 − 64 = −4 → 夹到 0（窄列停止缩进） */
        var ok7 = tree._treeMaxIndent(200) === 96
                  && tree._treeMaxIndent(100) === 0
                  && tree._treeMaxIndent(40) === 0
                  && tree._treeColumnX() === 0

        /* 列下标越界时不能算出 NaN（NaN 会让 x 变成 0 并静默错位） */
        tree.treeColumn = 99
        ok7 = ok7 && tree._treeColumnX() === 0 && tree._treeColumnWidth() === 0
        tree.treeColumn = 0

        /* 层级真的传到界面上了吗 —— 直接量箭头的 x。
         * 箭头是行里那个带 `shown` 属性的 Item，两个宿主各一份，
         * 所以按"缩进量的集合"核对，不按个数。 */
        tree.expandAll()
        var togs = root.findAll(tree, function (o) { return o.shown !== undefined })
        var seen = {}
        var withinCap = togs.length > 0
        for (var t = 0; t < togs.length; ++t) {
            var lead = togs[t].x - tree._treeColumnX() - Theme.space.md
            seen[Math.round(lead)] = true
            if (lead < 0 || lead > tree._treeMaxIndent(tree._treeColumnWidth())) withinCap = false
        }
        ok7 = ok7 && withinCap
                  && seen[0] === true && seen[20] === true && seen[40] === true

        /* 窄列：上限为 0 → 三个层级全部退回 0 缩进，而不是把文字挤没 */
        narrow.expandAll()
        var nTogs = root.findAll(narrow, function (o) { return o.shown !== undefined })
        var allZero = nTogs.length > 0
        for (var n = 0; n < nTogs.length; ++n)
            if (Math.abs(nTogs[n].x - narrow._treeColumnX() - Theme.space.md) > 0.5)
                allZero = false
        ok7 = ok7 && allZero

        root.bit(7, ok7)

        Qt.exit(Math.min(255, root.failures))
    }
}
