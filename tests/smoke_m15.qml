/****************************************************************************
 * QSkin · 冒烟测试 —— M15：QSkinTable 树形 + 键语义勾选（级联 / 半选态）
 *
 * 断言写法见 tools/test.sh 文件头：≤ 8 条，bit n = 断言 [n]。
 *
 * ── 这轮要守的核心不变量 ───────────────────────────────────────────────
 * M14 的结论是"树形下用 `selectedIndexes`（数据下标）寻址是错的"，
 * M15 的解法不是继续挡，而是**换一套寻址**：`selectedKeys`（键）。
 * 于是这一轮真正要守的是"两套寻址的边界在哪、集合的不变量是什么"：
 *
 *   ① 级联**向下**：勾一个节点 = 它 + 全部后代（不限深）。
 *   ② 级联**向上**：全部直接子都完全选中 → 父自动完全选中。
 *      祖先的"未选 / 半选"是**推导**的，不写进集合。
 *   ③ 半选 = 「自己不在集合」且「子树里有被完全选中的节点」。
 *      叶子永不半选；`checkStrictly` 下恒不半选。
 *   ④ 级联只看**结构**、不看**可见性**：折叠起来的分支照样参与计算
 *      （这正是它与 `_visibleRows` 必须分成两套的原因）。
 *   ⑤ 平铺模式的 `selectedIndexes` 语义**一字未改** —— 零回归。
 *   ⑥ 表头三态、`selectedRows`、`setSelectedKeys` 的闭包与输出顺序。
 *
 * 断言分工：
 *   [0] 级联向下 + **与折叠无关**（折叠后可见行只剩根，状态照样记得）
 *   [1] 级联向上（自下而上一步一步闭合父节点）
 *   [2] 半选态（父半选、叶子不半选、indeterminateKeys 的顺序）
 *   [3] 反向传播（取消一个深层叶子 → 祖先逐个退出集合、转半选）
 *   [4] checkStrictly 关掉级联与半选
 *   [5] 键寻址 vs 下标（折叠时设深层节点、分页后仍然记得、selectedIndexes 不动）
 *   [6] 平铺零回归（M6 的 selectedIndexes / 表头全选 行为照旧）
 *   [7] 表头三态 + selectedRows + setSelectedKeys 的闭包与顺序稳定性
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int failures: 0

    function bit(n, ok) { if (!ok) root.failures |= (1 << n) }

    /* 测试用树：一条两层分支 + 一条三层深的分支 + 一个单子父。
     * 前序（= selectedKeys 的输出顺序）：a a1 a1x a1y a2 b b1 —— 共 7 个节点。
     *   顶层     a、b
     *   a 的子   a1（还有子）、a2（叶）
     *   a1 的子  a1x、a1y（都是叶）
     *   b 的子   b1（叶，唯一的子 —— 用来验"单子父勾满即全选"）
     * 结构刻意做得三层，才能证明"级联不限深"。 */
    property var treeData: [
        { id: "a", name: "A 根", size: 1, children: [
            { id: "a1", name: "A1 枝", size: 2, children: [
                { id: "a1x", name: "A1X 叶", size: 3 },
                { id: "a1y", name: "A1Y 叶", size: 4 }
            ] },
            { id: "a2", name: "A2 叶", size: 5 }
        ] },
        { id: "b", name: "B 根", size: 6, children: [
            { id: "b1", name: "B1 叶", size: 7 }
        ] }
    ]

    property var flatData: [
        { name: "第一行", size: 10 },
        { name: "第二行", size: 20 },
        { name: "第三行", size: 30 }
    ]

    /** 选中键拼串 —— 断言里看得清顺序 */
    function keys(t) { return t.selectedKeys.join(",") }

    /* ══════════════════ 被测实例 ══════════════════ */

    /* 主实例：树形 + 勾选（级联默认开） */
    QSkinTable {
        id: cascade
        width: 400
        treeMode: true
        checkable: true
        treeIndentWidth: 20
        columns: [
            { title: "名称", dataIndex: "name", width: 200 },
            { title: "大小", dataIndex: "size", width: 200, align: "right" }
        ]
        rows: root.treeData
    }

    /* 严格模式对照：父子不关联 */
    QSkinTable {
        id: strict
        width: 400
        treeMode: true
        checkable: true
        checkStrictly: true
        columns: [
            { title: "名称", dataIndex: "name", width: 200 },
            { title: "大小", dataIndex: "size", width: 200, align: "right" }
        ]
        rows: root.treeData
    }

    /* 同一棵树上验折叠 / 分页下的键寻址 */
    QSkinTable {
        id: paged
        width: 400
        treeMode: true
        checkable: true
        columns: [
            { title: "名称", dataIndex: "name", width: 200 },
            { title: "大小", dataIndex: "size", width: 200, align: "right" }
        ]
        rows: root.treeData
    }

    /* 平铺对照：**同一份数据**、只关掉 treeMode —— 零回归的守门人 */
    QSkinTable {
        id: flat
        width: 400
        checkable: true
        columns: [
            { title: "名称", dataIndex: "name", width: 200 },
            { title: "大小", dataIndex: "size", width: 200, align: "right" }
        ]
        rows: root.flatData
    }

    Timer {
        interval: 400
        running: true
        repeat: false
        onTriggered: root.check()
    }

    function check() {
        /* ══════════════ [0] 级联向下 + 与折叠无关 ══════════════ */

        cascade.clearSelection()
        cascade.setSelected("a1", true)

        /* a1 + 它的全部后代（含三层的 a1x / a1y）进集合；
         * a2 是 a1 的兄弟，不受影响。
         * a 只有 a1 / a2 两个子，a2 没选 → a **不该**在集合里，
         * 而且应当半选。 */
        var ok0 = root.keys(cascade) === "a1,a1x,a1y"
                  && cascade.isSelected("a1") === true
                  && cascade.isSelected("a1x") === true
                  && cascade.isSelected("a1y") === true
                  && cascade.isSelected("a2") === false
                  && cascade.isSelected("a") === false
                  && cascade.isIndeterminate("a") === true

        /* **本轮的枢纽**：折叠起来之后，a1x / a1y 连可见行都不是了 ——
         * 但级联状态必须一模一样。若实现拿 `_visibleRows` 算级联，
         * 这里会看到 a 从"半选"变成"全选"（因为"有孩子没选"被折叠藏了）。 */
        cascade.collapseAll()
        ok0 = ok0 && cascade._viewTotal === 2                 /* 可见行只剩两个根 */
                  && cascade.isSelected("a1x") === true                /* 折叠不改变状态 */
                  && cascade.isSelected("a1") === true
                  && cascade.isIndeterminate("a") === true
                  && root.keys(cascade) === "a1,a1x,a1y"               /* 集合一个没少 */

        cascade.expandAll()
        ok0 = ok0 && cascade._viewTotal === 7

        root.bit(0, ok0)

        /* ══════════════ [1] 级联向上（自下而上闭合） ══════════════ */

        cascade.clearSelection()

        cascade.setSelected("a1x", true)
        var ok1 = root.keys(cascade) === "a1x"
                  && cascade.isSelected("a1") === false      /* 兄弟 a1y 没选 → 父不闭合 */
                  && cascade.isIndeterminate("a1") === true

        cascade.setSelected("a1y", true)
        ok1 = ok1 && root.keys(cascade) === "a1,a1x,a1y"     /* 子全选 → 父自动进集合 */
                  && cascade.isSelected("a1") === true
                  && cascade.isIndeterminate("a1") === false
                  && cascade.isIndeterminate("a") === true   /* 上一层还没满足 */

        cascade.setSelected("a2", true)
        ok1 = ok1 && root.keys(cascade) === "a,a1,a1x,a1y,a2" /* 再上一层也闭合了 */
                  && cascade.isSelected("a") === true
                  && cascade.isIndeterminate("a") === false

        /* 反向：父在集合里 ⇒ 所有后代都在集合里（集合的不变量） */
        ok1 = ok1 && cascade.isSelected("a1x") === true
                  && cascade.isSelected("a2") === true
                  && cascade.indeterminateKeys.length === 0

        root.bit(1, ok1)

        /* ══════════════ [2] 半选态 ══════════════ */

        cascade.clearSelection()
        cascade.setSelected("b1", true)

        /* b 只有 b1 一个子 → b 完全选中，不是半选 */
        var ok2 = cascade.isSelected("b") === true
                  && cascade.isIndeterminate("b") === false
                  && cascade.indeterminateKeys.length === 0
                  && cascade._allSelected === false
                  && cascade._someSelected === true

        cascade.setSelected("a1x", true)

        /* a1 的部分子被选中 → a1 半选（且**不在** selectedKeys 里）；
         * a 的子树里有选中的 → a 半选；
         * 叶子永远不半选（没有后代）。 */
        ok2 = ok2 && cascade.isIndeterminate("a1") === true
                  && cascade.isIndeterminate("a") === true
                  && cascade.isSelected("a1") === false
                  && cascade.isIndeterminate("a1y") === false
                  && cascade.isIndeterminate("a2") === false
                  && cascade.isIndeterminate("a1x") === false
                  && root.keys(cascade) === "a1x,b,b1"
                  && cascade.indeterminateKeys.join(",") === "a,a1"   /* 前序 */

        root.bit(2, ok2)

        /* ══════════════ [3] 反向传播（取消一个深层叶子） ══════════════ */

        cascade.selectAll()
        var ok3 = cascade._allSelected === true
                  && cascade._checkedCount === 7
                  && root.keys(cascade) === "a,a1,a1x,a1y,a2,b,b1"
                  && cascade.indeterminateKeys.length === 0

        /* 取消一个**三层深**的叶子：它自己出集合，然后 a1 → a 逐个退出集合、
         * 转成半选。兄弟与别的分支一个都不受影响。 */
        cascade.setSelected("a1y", false)
        ok3 = ok3 && cascade.isSelected("a1y") === false
                  && cascade.isSelected("a1") === false       /* 祖先退出集合 */
                  && cascade.isSelected("a") === false
                  && cascade.isSelected("a1x") === true       /* 兄弟不动 */
                  && cascade.isSelected("a2") === true
                  && cascade.isSelected("b") === true
                  && cascade.isSelected("b1") === true
                  && cascade.isIndeterminate("a1") === true
                  && cascade.isIndeterminate("a") === true
                  && root.keys(cascade) === "a1x,a2,b,b1"
                  && cascade._allSelected === false
                  && cascade._someSelected === true

        root.bit(3, ok3)

        /* ══════════════ [4] checkStrictly 关掉级联与半选 ══════════════ */

        strict.clearSelection()
        strict.setSelected("a1", true)

        /* 只动自己 —— 后代一个都不带 */
        var ok4 = root.keys(strict) === "a1"
                  && strict.isSelected("a1x") === false
                  && strict.isSelected("a1y") === false
                  /* 不重算祖先 → a 不会因为"子树里有选中的"而半选 */
                  && strict.isIndeterminate("a") === false
                  && strict.isIndeterminate("a1") === false
                  && strict.indeterminateKeys.length === 0

        /* 勾满全部子也**不闭合**父 */
        strict.setSelected("a1x", true)
        strict.setSelected("a1y", true)
        strict.setSelected("a2", true)
        ok4 = ok4 && root.keys(strict) === "a1,a1x,a1y,a2"
                  && strict.isSelected("a") === false
                  && strict.indeterminateKeys.length === 0

        /* 但表头的全选 / 未选照样工作 */
        strict.selectAll()
        ok4 = ok4 && strict._allSelected === true && strict._checkedCount === 7
        strict.clearSelection()
        ok4 = ok4 && root.keys(strict) === "" && strict._allSelected === false

        root.bit(4, ok4)

        /* ══════════════ [5] 键寻址 vs 下标 ══════════════ */

        paged.collapseAll()
        paged.clearSelection()

        /* 折叠状态下对**看不见的深层节点**设选中 —— 键寻址照样记得 */
        paged.setSelected("a1y", true)
        var ok5 = paged._viewTotal === 2                       /* 可见行只有两个根 */
                  && paged.isSelected("a1y") === true
                  && paged.selectedRows.length === 1
                  && paged.selectedRows[0].id === "a1y"        /* 拿到的是行对象 */

        /* 展开后它已经在正确的位置上被勾 */
        paged.expandAll()
        var m = paged.rowMeta
        var i5 = -1
        for (var i = 0; i < m.length; ++i) if (m[i].key === "a1y") i5 = i
        ok5 = ok5 && i5 === 3                                  /* 前序第 4 个 */
                  && paged._viewIsChecked(i5) === true
                  /* **这就是 M14 那条结论的实证**：嵌套节点没有数据下标，
                   * 下标寻址在这里只会指到别的行上 */
                  && paged._sourceIndex(i5) === -1
                  /* 反向隔离：树形勾选**不碰** selectedIndexes */
                  && paged.selectedIndexes.length === 0

        /* 分页之后仍然记得（按键记，与它此刻在第几页无关）。
         * 7 个可见行、每页 3 个 → 第 2 页 = [a1y, a2, b]，a1y 正好落在页首。
         * 顺手把"同一页里别的行没被勾"也验掉 —— 不然"整页都亮"
         * 这种错法会被漏过去。 */
        paged.pageSize = 3
        paged.page = 2
        ok5 = ok5 && paged.page === 2
                  && paged.pageCount === 3
                  && paged.rowMeta[0].key === "a1y"           /* 页首就是它 */
                  && paged.isSelected("a1y") === true
                  && paged._viewIsChecked(0) === true
                  && paged._viewIsChecked(1) === false        /* 同页的 a2 没勾 */
                  && paged._viewIsChecked(2) === false
        paged.pageSize = 0
        paged.page = 1
        ok5 = ok5 && paged.isSelected("a1y") === true

        root.bit(5, ok5)

        /* ══════════════ [6] 平铺零回归 ══════════════ */

        /* 同一份"树形数据"在这里是平铺的：M6 的 selectedIndexes 语义照旧 */
        var ok6 = flat._showCheckColumn === true
                  && flat._fixedWidth === flat.checkColumnWidth
                  && flat.selectedIndexes.length === 0

        flat._toggleCheck(1)
        ok6 = ok6 && flat.selectedIndexes.length === 1
                  && flat.selectedIndexes[0] === 1
                  && flat._viewIsChecked(0) === false
                  && flat._viewIsChecked(1) === true
                  /* 平铺没有祖先 → 永远不半选 */
                  && flat._viewIsIndeterminate(0) === false
                  && flat._viewIsIndeterminate(1) === false
                  && flat.indeterminateKeys.length === 0
                  && flat.selectedRows.length === 1
                  && flat.selectedRows[0].name === "第二行"

        /* 表头全选：平铺是勾**全部行**（跨页同样成立，M6 原语义） */
        flat._toggleAll()
        ok6 = ok6 && flat._allSelected === true
                  && flat.selectedIndexes.length === flat.rowCount
        flat._toggleAll()
        ok6 = ok6 && flat.selectedIndexes.length === 0
                  && flat._allSelected === false

        root.bit(6, ok6)

        /* ══════════════ [7] 表头三态 / selectedRows / 集合闭包 ══════════════ */

        cascade.clearSelection()
        var ok7 = cascade._allSelected === false
                  && cascade._someSelected === false
                  && cascade._checkedCount === 0

        cascade.selectAll()
        ok7 = ok7 && cascade._allSelected === true
                  && cascade._someSelected === false
                  && cascade.selectedKeys.length === 7
                  /* selectedRows 与 selectedKeys 同序同长（树前序） */
                  && cascade.selectedRows.length === 7
                  && cascade.selectedRows[0].id === "a"
                  && cascade.selectedRows[6].id === "b1"

        cascade.clearSelection()
        cascade.setSelected("a1x", true)
        ok7 = ok7 && cascade._allSelected === false
                  && cascade._someSelected === true             /* 有选中但未全选 → 表头半选 */
                  && cascade.selectedRows.length === 1
                  && cascade.selectedRows[0].id === "a1x"       /* 半选的祖先不在其中 */

        /* setSelectedKeys 的**闭包**：给父补后代、给全部子补父、丢陈旧键 */
        cascade.setSelectedKeys(["a1"])
        ok7 = ok7 && root.keys(cascade) === "a1,a1x,a1y"
        cascade.setSelectedKeys(["a1y", "a1x"])                 /* 换个输入顺序 */
        ok7 = ok7 && root.keys(cascade) === "a1,a1x,a1y"        /* 输出仍按树前序 */
        cascade.setSelectedKeys(["nope", "a1x"])                /* 陈旧键直接丢 */
        ok7 = ok7 && root.keys(cascade) === "a1x"
                  && cascade.isSelected("a1") === false
        cascade.setSelectedKeys(null)                           /* 清空 */
        ok7 = ok7 && root.keys(cascade) === ""

        /* 不存在的键：什么都不做（不写、不发信号） */
        cascade.setSelected("nope", true)
        ok7 = ok7 && cascade.selectedKeys.length === 0
                  && cascade.isSelected("nope") === false

        root.bit(7, ok7)

        Qt.exit(Math.min(255, root.failures))
    }
}
