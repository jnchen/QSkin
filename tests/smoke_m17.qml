/****************************************************************************
 * QSkin · 冒烟测试 —— M17：TreeUtil 下沉 + QSkinTree
 *
 * 断言写法见 tools/test.sh 文件头：≤ 8 条，bit n = 断言 [n]。
 *
 * ── 这轮要守的核心不变量 ───────────────────────────────────────────────
 * M17 做了两件事，每件都有一个"看起来做成了"的失败模式：
 *
 *   ① 把树逻辑从 QSkinTable 搬到 TreeUtil。
 *      **假成功的形态**：既有 22 个测试照样全绿 —— 但因为没人走到新代码。
 *      （实测踩到：第一次变异测试改的是 `src/`，而 `qml` 跑的是
 *      `.cache/qmlimports` 里的副本 —— 变异根本没进这次运行。）
 *      所以 [0]~[4] **直接调 TreeUtil**，不经过任何控件：
 *      "实现被搬走了"与"控件还在用它"必须是两件独立可验的事。
 *
 *   ② 新做一棵 QSkinTree，**且不与表格分叉**。
 *      这是下沉真正要保的东西。所以 [6] 拿同一份数据、同一个操作序列，
 *      要求 QSkinTree 与 QSkinTable（treeMode）给出**逐字相同**的
 *      selectedKeys 与 indeterminateKeys。
 *
 *   ③ 属性值对 ≠ 界面画对（M14 实录：6 处渲染点漏了 1 处，断言永远绿）。
 *      属性侧由本文件守；渲染侧交给 examples/HelloM17.qml 抓图。
 *
 * 断言分工：
 *   [0] TreeUtil.index：前序 / 层级 / 父子链 / 键回退路径 / 访问器容错
 *   [1] TreeUtil.flatten：折叠剪枝、meta 形状、同级排序不改层级归属
 *   [2] TreeUtil 级联：向下不限深 + 自下而上闭合祖先
 *   [3] TreeUtil 半选：叶子永不半选、祖先推导、前序输出
 *   [4] TreeUtil.normalize / keysToArray / sameKeys / countExisting / labelOf
 *   [5] QSkinTree 展开一族（含"状态没变不发信号"与"批量落成显式状态"）
 *   [6] QSkinTree 勾选一族 + **与 QSkinTable 逐字一致**
 *   [7] QSkinTree 可见行 / currentIndex 的键派生 / 键盘 / 缩进上限
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int failures: 0

    function bit(n, ok) { if (!ok) root.failures |= (1 << n) }

    /* 测试用树 —— 与 smoke_m15 同一份形状，这样 [6] 的"两控件对齐"
     * 才是真的同一道题。前序：a a1 a1x a1y a2 b b1（共 7 个节点）。
     *   顶层     a、b
     *   a 的子   a1（有子）、a2（叶）
     *   a1 的子  a1x、a1y（叶）
     *   b 的子   b1（叶，单子父 —— 用来验"单子父勾满即全选"） */
    property var treeData: [
        { id: "a", name: "A 根", children: [
            { id: "a1", name: "A1 枝", children: [
                { id: "a1x", name: "A1X 叶" },
                { id: "a1y", name: "A1Y 叶" }
            ] },
            { id: "a2", name: "A2 叶" }
        ] },
        { id: "b", name: "B 根", children: [
            { id: "b1", name: "B1 叶" }
        ] }
    ]

    /** 一条没有 id 的分支：专门验"键回退到结构路径" */
    property var bareData: [
        { name: "没有键的根", children: [ { name: "同样没有键的子" } ] }
    ]

    /* 信号日志。属性值一样时，"发没发信号"是唯一能区分
     * "真的重算了"和"什么都没做"的东西。 */
    property var expandLog: []
    property var keyLog: []
    property var clickLog: []

    function keysOf(t) { return t.selectedKeys.join(",") }
    function indOf(t)  { return t.indeterminateKeys.join(",") }

    /* ══════════════════ 被测实例 ══════════════════ */

    /* 主实例：勾选 + 级联 + 默认全展开 */
    QSkinTree {
        id: tree

        width: 320
        nodes: root.treeData
        treeKey: "id"
        treeChildrenKey: "children"
        textRole: "name"
        checkable: true
        defaultExpandAll: true

        /* 信号参数必须显式声明成 function(...)，否则 qmllint 报
         * Unqualified access（与 QSkinCheckBox 里 Keys.onSpacePressed 同款） */
        onExpandToggled: function(key, expanded) {
            root.expandLog.push(String(key) + ":" + expanded)
        }
        onKeySelectionChanged: function(keys) {
            root.keyLog.push(keys.join("|"))
        }
        onNodeClicked: function(node, key, level) {
            root.clickLog.push(String(key))
        }
    }

    /* 同一份数据、同一套操作用的表格对照 —— [6] 的对齐基准 */
    QSkinTable {
        id: table

        width: 320
        treeMode: true
        checkable: true
        defaultExpandAll: true
        columns: [ { title: "名称", dataIndex: "name", width: 320 } ]
        rows: root.treeData
    }

    /* 严格模式对照（父子不关联） */
    QSkinTree {
        id: strictTree

        width: 320
        checkable: true
        checkStrictly: true
        nodes: root.treeData
    }

    /* 无键数据（键回退路径）+ 默认收起 */
    QSkinTree {
        id: bareTree

        width: 320
        nodes: root.bareData
    }

    /* 不勾选的树 —— 缩进上限用**没有勾选列**的实例量，
     * 免得期望值里还要算勾选框占位（那部分另有断言） */
    QSkinTree {
        id: plainTree

        width: 320
        nodes: root.treeData
    }

    Timer {
        interval: 400
        running: true
        repeat: false
        onTriggered: root.check()
    }

    function check() {
        var T = TreeUtil

        /* ══════════════ [0] TreeUtil.index ══════════════ */

        var idx = T.index(root.treeData, "id", "children")
        var ok0 = idx.count === 7
                  && idx.roots.join(",") === "a,b"
                  && idx.order.join(",") === "a,a1,a1x,a1y,a2,b,b1"   /* 前序 */
                  && idx.byKey["a1"].level === 1
                  && idx.byKey["a1x"].level === 2
                  && idx.byKey["a1"].parentKey === "a"
                  && idx.byKey["a1"].childKeys.join(",") === "a1x,a1y"
                  && idx.byKey["a1x"].childKeys.length === 0
                  && idx.byKey["a"].parentKey === ""                  /* 根没有父 */

        /* 键回退：数据没写 id 时用结构路径（前缀 "#"）。
         * 前缀的存在是为了让回退键**不可能**与真实键撞上。 */
        var bidx = T.index(root.bareData, "id", "children")
        ok0 = ok0 && bidx.count === 2
                  && bidx.roots.join(",") === "#0"
                  && bidx.order.join(",") === "#0,#0/0"
                  && bidx.byKey["#0/0"].parentKey === "#0"
                  && bidx.byKey["#0/0"].level === 1

        /* 访问器容错：字段缺失、不是数组、节点是 null —— 一律按"没有子节点"
         * 处理。树的中间层经常来自"只填了一半"的数据，控件不该因此白屏。 */
        ok0 = ok0 && T.childrenOf({ id: "x" }, "children").length === 0
                  && T.childrenOf({ id: "x", children: "不是数组" }, "children").length === 0
                  && T.childrenOf({ id: "x", children: null }, "children").length === 0
                  && T.childrenOf(null, "children").length === 0
                  && T.keyOf(null, "3", "id") === "#3"
                  && T.keyOf({ id: "" }, "3", "id") === "#3"          /* 空串也算取不到 */
                  && T.keyOf({ id: 7 }, "3", "id") === "7"            /* 数字键归一成字符串 */

        /* 空 / null 数据不炸 */
        ok0 = ok0 && T.index(null, "id", "children").count === 0
                  && T.index([], "id", "children").roots.length === 0

        root.bit(0, ok0)

        /* ══════════════ [1] TreeUtil.flatten ══════════════ */

        /* 全展开：7 行，meta 与行同序同长 */
        var flat = T.flatten(root.treeData, {
            keyField: "id", childrenKey: "children",
            isExpanded: function(k) { return true },
            sourceIndex: true
        })
        var ok1 = flat.rows.length === 7 && flat.meta.length === 7
                  && flat.rows[0].id === "a" && flat.rows[6].id === "b1"
                  && flat.meta[0].key === "a" && flat.meta[0].level === 0
                  && flat.meta[0].hasChildren === true
                  && flat.meta[0].expanded === true
                  && flat.meta[0].sourceIndex === 0                  /* 顶层带源下标 */
                  && flat.meta[6].sourceIndex === -1                 /* 嵌套节点没有 */

        /* 全部收起：只剩两个根。**折叠的分支整枝剪掉** ——
         * 这正是"可见行"与"全树索引"必须是两套的原因 */
        var folded = T.flatten(root.treeData, {
            keyField: "id", childrenKey: "children",
            isExpanded: function(k) { return false }
        })
        ok1 = ok1 && folded.rows.length === 2
                  && folded.meta[0].hasChildren === true
                  && folded.meta[0].expanded === false
                  && folded.rows[0].id === "a" && folded.rows[1].id === "b"

        /* 只展开 a：a、a1、a2 出现；a1 的子不出现（a1 自己没展开） */
        var partial = T.flatten(root.treeData, {
            keyField: "id", childrenKey: "children",
            isExpanded: function(k) { return k === "a" }
        })
        var partialIds = []
        for (var p1 = 0; p1 < partial.rows.length; ++p1) partialIds.push(partial.rows[p1].id)
        ok1 = ok1 && partialIds.join(",") === "a,a1,a2,b"

        /* ── 排序只作用于**同级兄弟**：层级归属一个都不能变 ──
         * 按 name 倒序。判据不是"顺序对不对"，而是"键 → 层级的归属没变"
         * ——跨层重排会让节点换爹，树就散了。 */
        var sorted = T.flatten(root.treeData, {
            keyField: "id", childrenKey: "children",
            isExpanded: function(k) { return true },
            compare: function(p, q) { return p.name < q.name ? 1 : (p.name > q.name ? -1 : 0) }
        })
        var lvl = {}
        for (var s1 = 0; s1 < sorted.meta.length; ++s1) lvl[sorted.meta[s1].key] = sorted.meta[s1].level
        ok1 = ok1 && sorted.rows.length === 7
                  && lvl["a"] === 0 && lvl["b"] === 0
                  && lvl["a1"] === 1 && lvl["a2"] === 1 && lvl["b1"] === 1
                  && lvl["a1x"] === 2 && lvl["a1y"] === 2
                  && sorted.meta[0].level === 0                     /* 根仍然排在最前 */

        /* 空 / null 数据 */
        ok1 = ok1 && T.flatten(null, { isExpanded: function() { return true } }).rows.length === 0
                  && T.flatten([], { isExpanded: function() { return true } }).meta.length === 0

        root.bit(1, ok1)

        /* ══════════════ [2] TreeUtil 级联（向下 + 向上）══════════════ */

        var idx2 = T.index(root.treeData, "id", "children")

        /* 向下**不限深**：勾 a1 → a1 与它两层深的后代一起进集合 */
        var set = {}
        T.applyCascade(idx2, "a1", true, set)
        var ok2 = T.keysToArray(set, idx2).join(",") === "a1,a1x,a1y"
                  && set["a2"] === undefined                        /* 兄弟不受影响 */

        /* 向上闭合：a 只有 a1 / a2 两个直接子，a2 没选 → a 不闭合 */
        T.refreshAncestorsOf(idx2, "a1", set)
        ok2 = ok2 && set["a"] === undefined

        /* 再勾 a2 → 直接子全选 → a 自动闭合 */
        T.applyCascade(idx2, "a2", true, set)
        T.refreshAncestorsOf(idx2, "a2", set)
        ok2 = ok2 && T.keysToArray(set, idx2).join(",") === "a,a1,a1x,a1y,a2"

        /* 取消一个**三层深**的叶子：它自己出集合，a1 → a 逐个退出集合 */
        T.applyCascade(idx2, "a1y", false, set)
        T.refreshAncestorsOf(idx2, "a1y", set)
        ok2 = ok2 && set["a1y"] === undefined
                  && set["a1"] === undefined                        /* 祖先退出集合 */
                  && set["a"] === undefined
                  && set["a1x"] === true                            /* 兄弟不动 */
                  && set["a2"] === true
                  && T.keysToArray(set, idx2).join(",") === "a1x,a2"

        /* 单子父：b 只有 b1 一个直接子 → 勾 b1 就闭合 b
         * （"所有直接子都在集合里"对一个子同样成立） */
        var set2 = {}
        T.applyCascade(idx2, "b1", true, set2)
        T.refreshAncestorsOf(idx2, "b1", set2)
        ok2 = ok2 && set2["b"] === true

        /* closeUpwardOne 对叶子不做事（没有子，闭合无从谈起） */
        var set3 = {}
        T.closeUpwardOne(idx2, "a2", set3)
        ok2 = ok2 && set3["a2"] === undefined

        /* 不存在的键：静默忽略，不抛错也不污染集合 */
        var set4 = {}
        T.applyCascade(idx2, "nope", true, set4)
        T.refreshAncestorsOf(idx2, "nope", set4)
        ok2 = ok2 && Object.keys(set4).length === 0

        /* cloneSet 是浅拷贝（改副本不影响原件） */
        var orig = { "a": true }
        var copy = T.cloneSet(orig)
        copy["b"] = true
        ok2 = ok2 && orig["b"] === undefined && copy["a"] === true

        root.bit(2, ok2)

        /* ══════════════ [3] TreeUtil 半选推导 ══════════════ */

        var set5 = {}
        T.applyCascade(idx2, "b1", true, set5)          /* → b、b1 */
        T.refreshAncestorsOf(idx2, "b1", set5)
        T.applyCascade(idx2, "a1x", true, set5)         /* → a1x 单独一个 */
        T.refreshAncestorsOf(idx2, "a1x", set5)

        var hs = T.subtreeHasChecked(idx2, set5)
        var ind = T.indeterminateKeys(idx2, set5, hs)
        var ok3 = T.keysToArray(set5, idx2).join(",") === "a1x,b,b1"
                  && ind.join(",") === "a,a1"                   /* 前序，且**不含** b */
                  && hs["a"] === true && hs["a1"] === true
                  && set5["a"] === undefined                     /* 半选的祖先不在集合里 */
                  && set5["a1"] === undefined
                  /* 叶子永不半选（子树里不可能有被选中的东西） */
                  && hs["a1x"] === false && hs["a1y"] === false
                  && hs["a2"] === false && hs["b1"] === false
                  /* b 被**完全选中**，所以不在半选列表里 */
                  && ind.indexOf("b") < 0 && ind.indexOf("b1") < 0

        /* 全空集合 → 没有半选；全选 → 也没有半选 */
        ok3 = ok3 && T.indeterminateKeys(idx2, {}, T.subtreeHasChecked(idx2, {})).length === 0
        var allSet = T.normalize(idx2, ["a", "b"], false)
        ok3 = ok3 && T.keysToArray(allSet, idx2).length === 7
                  && T.indeterminateKeys(idx2, allSet,
                                         T.subtreeHasChecked(idx2, allSet)).length === 0

        root.bit(3, ok3)

        /* ══════════════ [4] normalize / keysToArray / sameKeys / 其余 ══════════════ */

        /* 给父 → 后代自动补（级联闭包） */
        var ok4 = T.keysToArray(T.normalize(idx2, ["a1"], false), idx2).join(",") === "a1,a1x,a1y"

        /* 给全部直接子 → 父自动补上来 */
        ok4 = ok4 && T.keysToArray(T.normalize(idx2, ["a1x", "a1y"], false), idx2).join(",")
                     === "a1,a1x,a1y"

        /* 输入顺序不同 → 输出仍按**树的前序**（不然用起来像随机数） */
        ok4 = ok4 && T.keysToArray(T.normalize(idx2, ["a1y", "a1x"], false), idx2).join(",")
                     === "a1,a1x,a1y"

        /* 陈旧键丢弃；null / undefined 当清空处理 */
        ok4 = ok4 && T.keysToArray(T.normalize(idx2, ["nope", "a1x"], false), idx2).join(",") === "a1x"
                  && T.keysToArray(T.normalize(idx2, null, false), idx2).length === 0
                  && T.keysToArray(T.normalize(idx2, undefined, false), idx2).length === 0

        /* checkStrictly：只管自己，不级联也不闭合 */
        ok4 = ok4 && T.keysToArray(T.normalize(idx2, ["a1"], true), idx2).join(",") === "a1"
                  && T.keysToArray(T.normalize(idx2, ["a1x", "a1y"], true), idx2).join(",")
                     === "a1x,a1y"

        /* sameKeys 是**字符串归一**的：节点用数字 id 时集合里是 "1"，
         * 对外数组也必须是 "1"，否则 1 !== "1" 会让"没变就不写"失效 */
        ok4 = ok4 && T.sameKeys(["1", "2"], ["1", "2"]) === true
                  && T.sameKeys([1, 2], ["1", "2"]) === true
                  && T.sameKeys(["1"], ["1", "2"]) === false
                  && T.sameKeys(null, []) === true
                  && T.sameKeys([], ["1"]) === false

        /* countExisting 筛掉数据里已不存在的键（否则"全选"会一直亮着） */
        ok4 = ok4 && T.countExisting({ "a": true, "nope": true }, idx2) === 1

        /* rowsOfKeys 跳过不存在的键，拿到的是**节点对象** */
        var rows4 = T.rowsOfKeys(idx2, ["a1x", "nope", "b"])
        ok4 = ok4 && rows4.length === 2 && rows4[0].id === "a1x" && rows4[1].id === "b"
                  && T.rowsOfKeys(idx2, null).length === 0

        /* allKeys 是前序全树键（不受折叠影响） */
        ok4 = ok4 && T.allKeys(root.treeData, "id", "children").join(",")
                     === "a,a1,a1x,a1y,a2,b,b1"

        /* labelOf：textRole 为空时退化成 String(节点) —— 不白屏 */
        ok4 = ok4 && T.labelOf({ name: "甲" }, "name") === "甲"
                  && T.labelOf({ name: "甲" }, "") === "[object Object]"
                  && T.labelOf(null, "name") === ""
                  && T.labelOf({ name: null }, "name") === ""
                  && T.labelOf({ name: 3 }, "name") === "3"

        /* maxIndent 只做减法，且夹到 ≥ 0（负数会让内容跑到控件外） */
        ok4 = ok4 && T.maxIndent(200, 12, 16, 64) === 96           /* 200-24-16-64 */
                  && T.maxIndent(105, 12, 16, 64) === 1             /* 刚过边界 */
                  && T.maxIndent(104, 12, 16, 64) === 0             /* 恰好为 0 */
                  /* 100-24-16-64 = -4 → 夹到 0。负数会让内容跑到控件外面去 */
                  && T.maxIndent(100, 12, 16, 64) === 0
                  && T.maxIndent(0, 12, 16, 64) === 0

        root.bit(4, ok4)

        /* ══════════════ [5] QSkinTree 展开一族 ══════════════ */

        /* defaultExpandAll: true → 7 行可见，但**状态表是空的**
         * （没被显式设置过的节点吃默认值 —— 于是换数据不需要重置逻辑） */
        var ok5 = tree.visibleCount === 7
                  && tree.isExpanded("a1") === true
                  && tree.expandedKeys.length === 0
                  && tree._expandState["a"] === undefined

        root.expandLog = []

        /* 收起 a1 → 可见行少 2（a1x / a1y 被剪掉） */
        tree.setExpanded("a1", false)
        ok5 = ok5 && tree.visibleCount === 5
                  && tree.isExpanded("a1") === false
                  && root.expandLog.join(",") === "a1:false"

        /* 状态本来就一致 → **既不写状态也不发信号** */
        tree.setExpanded("a1", false)
        ok5 = ok5 && root.expandLog.length === 1

        /* toggle 翻转 */
        tree.toggleExpand("a1")
        ok5 = ok5 && tree.isExpanded("a1") === true && tree.visibleCount === 7
                  && root.expandLog.length === 2

        /* 有了显式状态之后 expandedKeys 才非空 */
        ok5 = ok5 && tree.expandedKeys.join(",") === "a1"

        /* collapseAll → 只剩两个根，且**全部落成显式 false** */
        tree.collapseAll()
        ok5 = ok5 && tree.visibleCount === 2
                  && tree.isExpanded("a") === false
                  && tree.isExpanded("a1x") === false
                  && tree.expandedKeys.length === 0
                  && tree._expandState["a"] === false        /* 显式 false，不是"没记录" */
                  && tree._expandState["a1x"] === false

        /* expandAll → 全部显式 true */
        tree.expandAll()
        ok5 = ok5 && tree.visibleCount === 7 && tree.expandedKeys.length === 7

        /* setExpandedKeys：整份设定，不在集合里的一律收起（不是增量） */
        tree.setExpandedKeys(["a"])
        ok5 = ok5 && tree.visibleCount === 4                 /* a a1 a2 b */
                  && tree.isExpanded("a") === true
                  && tree.isExpanded("a1") === false
                  && tree.isExpanded("b") === false

        /* 无键 + 默认收起的树。回退键是 `#` + **纯结构路径** ——
         * 根是 "#0"、它的子应当是 "#0/0"。这里钉住这条，是因为 M17 之前
         * 每一层都会再前缀一个 "#"（子变 "##0/0"），而且没人测过。 */
        var bareKeys = TreeUtil.allKeys(root.bareData, "id", "children")
        ok5 = ok5 && bareKeys.join(",") === "#0,#0/0"
                  && bareTree.visibleCount === 1
                  && bareTree.isExpanded("#0") === false
                  && bareTree.expandedKeys.length === 0

        /* 「没被记录过的键吃 defaultExpandAll」—— 不存在的键也算"没记录过"。
         * 于是同一个问题在两棵树上答案相反，这是刻意的（默认值就是默认值）。 */
        ok5 = ok5 && tree.isExpanded("nope") === true          /* defaultExpandAll: true */
                  && bareTree.isExpanded("nope") === false      /* defaultExpandAll: false */

        /* 状态一致 → 不发信号（"a" 此刻已经显式展开） */
        root.expandLog = []
        tree.setExpanded("a", true)
        ok5 = ok5 && root.expandLog.length === 0 && tree.isExpanded("a") === true

        root.bit(5, ok5)

        /* ══════════════ [6] QSkinTree 勾选一族 + 与 QSkinTable 逐字一致 ══════════════ */

        tree.clearSelection()
        table.clearSelection()

        var ok6 = tree.selectedKeys.length === 0
                  && tree.checkedCount === 0
                  && tree.allChecked === false && tree.someChecked === false

        /* 同一个操作序列，两边各做一遍 —— 结果必须**逐字相同**。
         * 这是本次下沉唯一真正的验收标准：没有两份实现。 */
        tree.setSelected("a1x", true)
        table.setSelected("a1x", true)
        ok6 = ok6 && root.keysOf(tree) === root.keysOf(table)
                  && root.indOf(tree) === root.indOf(table)
                  && root.keysOf(tree) === "a1x"
                  && root.indOf(tree) === "a,a1"

        tree.setSelected("a1y", true)
        table.setSelected("a1y", true)
        ok6 = ok6 && root.keysOf(tree) === root.keysOf(table)
                  && root.keysOf(tree) === "a1,a1x,a1y"

        tree.selectAll()
        table.selectAll()
        ok6 = ok6 && root.keysOf(tree) === root.keysOf(table)
                  && root.keysOf(tree) === "a,a1,a1x,a1y,a2,b,b1"
                  && root.indOf(tree) === ""
                  && tree.allChecked === true && tree.someChecked === false
                  && tree.checkedCount === 7

        /* 取消一个三层深的叶子 → 祖先逐个退出集合、转半选 */
        tree.setSelected("a1y", false)
        table.setSelected("a1y", false)
        ok6 = ok6 && root.keysOf(tree) === root.keysOf(table)
                  && root.indOf(tree) === root.indOf(table)
                  && root.keysOf(tree) === "a1x,a2,b,b1"
                  && root.indOf(tree) === "a,a1"
                  && tree.allChecked === false && tree.someChecked === true

        /* setSelectedKeys 的闭包 + 陈旧键，两边同样一致 */
        tree.setSelectedKeys(["a1y", "a1x"])
        table.setSelectedKeys(["a1y", "a1x"])
        ok6 = ok6 && root.keysOf(tree) === root.keysOf(table)
                  && root.keysOf(tree) === "a1,a1x,a1y"
        tree.setSelectedKeys(["nope"])
        table.setSelectedKeys(["nope"])
        ok6 = ok6 && root.keysOf(tree) === "" && root.keysOf(table) === ""

        /* selectedRows 拿到的是**节点对象**（不是键、也不是下标） */
        tree.setSelectedKeys(["b"])
        ok6 = ok6 && tree.selectedRows.length === 2
                  && tree.selectedRows[0].name === "B 根"
                  && tree.selectedRows[1].name === "B1 叶"

        /* 勾选是键语义，**不碰** currentKey（两者是两件事） */
        ok6 = ok6 && tree.currentKey === ""

        /* ── toggleSelected 的三态 ──
         * 半选点一下 → 全选（与 QSkinCheckBox 的通用约定一致）；全选再点 → 清空。
         *
         * 这里两边的**历史 bug** 都要守着：`toggleSelected` 从 M15 起
         * 写成 `!(isSelected || isIndeterminate)`，半选会被算成"要取消"，
         * 于是点一下变清空 —— 而它一直没有测试覆盖（既有测试全走
         * setSelected / selectAll / setSelectedKeys），注释与实现相反
         * 也没人发现。M17 修掉，并由这条断言守住。 */
        tree.setSelectedKeys(["a1x"])
        table.setSelectedKeys(["a1x"])
        ok6 = ok6 && tree.isIndeterminate("a1") === true
                  && tree.isIndeterminate("a1") === table.isIndeterminate("a1")

        tree.toggleSelected("a1")                       /* 半选 → 全选 */
        table.toggleSelected("a1")
        ok6 = ok6 && root.keysOf(tree) === root.keysOf(table)
                  && tree.isSelected("a1") === true
                  && tree.isSelected("a1x") === true && tree.isSelected("a1y") === true
                  && tree.isIndeterminate("a1") === false
                  && root.keysOf(tree) === "a1,a1x,a1y"

        tree.toggleSelected("a1")                       /* 全选 → 清空 */
        table.toggleSelected("a1")
        ok6 = ok6 && root.keysOf(tree) === root.keysOf(table)
                  && root.keysOf(tree) === "" && root.keysOf(table) === ""
                  && tree.isSelected("a1") === false

        tree.toggleSelected("a1")                       /* 空选 → 全选 */
        ok6 = ok6 && tree.isSelected("a1") === true
                  && root.keysOf(tree) === "a1,a1x,a1y"

        /* 严格模式：只动自己，不级联、不重算祖先、不半选 */
        strictTree.clearSelection()
        strictTree.setSelected("a1", true)
        ok6 = ok6 && root.keysOf(strictTree) === "a1"
                  && strictTree.isSelected("a1x") === false
                  && strictTree.isIndeterminate("a") === false
                  && strictTree.indeterminateKeys.length === 0

        /* 禁用的节点不许被勾，但**能展开**（"不能选"与"点不开"是两回事） */
        tree.clearSelection()
        tree.disabledKeys = ["a2"]
        ok6 = ok6 && tree.isDisabled("a2") === true
        tree.setSelected("a2", true)
        ok6 = ok6 && tree.selectedKeys.length === 0
        tree.setExpanded("a2", true)
        ok6 = ok6 && tree.isExpanded("a2") === true
        tree.disabledKeys = []

        /* keySelectionChanged 只在**真的变了**的时候发。
         * 注意先把集合弄成非空 —— 否则"清空一个已经空的集合"本来就不该发
         * 信号，这条断言会退化成恒真（本文件第一版就是这么写错的：
         * 断言了 length === 1，而实际是 0，因为集合早就空了）。 */
        root.keyLog = []
        tree.setSelectedKeys(["b"])                              /* 空 → b,b1：变了 */
        ok6 = ok6 && root.keyLog.length === 1 && root.keyLog[0] === "b|b1"
        tree.clearSelection()                                    /* → 空：变了 */
        ok6 = ok6 && root.keyLog.length === 2 && root.keyLog[1] === ""
        tree.clearSelection()                                    /* 已经是空的：没变 */
        ok6 = ok6 && root.keyLog.length === 2
        tree.setSelectedKeys(["nope"])                           /* 陈旧键：集合没变 */
        ok6 = ok6 && root.keyLog.length === 2
        tree.setSelectedKeys(["b1"])                             /* 单子父 → 闭包补上 b */
        ok6 = ok6 && root.keyLog.length === 3 && root.keyLog[2] === "b|b1"

        root.bit(6, ok6)

        /* ══════════════ [7] 可见行 / currentIndex / 键盘 / 缩进上限 ══════════════ */

        tree.expandAll()
        tree.currentKey = ""

        var rs = tree.visibleRows
        var ok7 = rs.length === 7
                  /* visibleRows 的元素形状：既有 node 也有树信息 —— 按行合成一份，
                   * 免得每个渲染点自己去对齐两个同序数组（错位一位是看不到的错） */
                  && rs[0].node.id === "a" && rs[0].key === "a" && rs[0].level === 0
                  && rs[0].hasChildren === true && rs[0].expanded === true
                  && rs[3].node.id === "a1y" && rs[3].level === 2
                  && rs[3].hasChildren === false
                  && rs[6].key === "b1" && rs[6].parentKey === "b"

        /* ── ★ 键寻址：折叠回来，游标还在**同一个节点**上 ──
         * 若 currentIndex 是存下来的下标，这里会指到别人身上 ——
         * 这正是 M14 判定"下标在树上不可用"的原因。 */
        tree.currentKey = "a1y"
        ok7 = ok7 && tree.currentIndex === 3
        tree.collapseAll()
        ok7 = ok7 && tree.currentIndex === -1                /* 它被折叠藏起来了 */
                  && tree.currentKey === "a1y"               /* 但**记得**它 */
        tree.expandAll()
        ok7 = ok7 && tree.currentIndex === 3                 /* 回到原位，不是"第 4 行" */

        /* 键盘移动：没有当前节点时，向下从第一行、向上从最后一行 */
        tree.currentKey = ""
        tree._moveCurrent(1)
        ok7 = ok7 && tree.currentKey === "a" && tree.currentIndex === 0
        tree._moveCurrent(1)
        ok7 = ok7 && tree.currentKey === "a1"
        tree._moveCurrent(-1)
        ok7 = ok7 && tree.currentKey === "a"
        tree._moveCurrent(-1)
        ok7 = ok7 && tree.currentKey === "a"                 /* 已在首行 → 钳住 */

        tree.currentKey = ""
        tree._moveCurrent(-1)
        ok7 = ok7 && tree.currentKey === "b1" && tree.currentIndex === 6

        /* 不存在的当前键：currentIndex 给 -1，不会指到第 0 行上去 */
        tree.currentKey = "nope"
        ok7 = ok7 && tree.currentIndex === -1

        /* 左右键：收起 + 有子 → 展开；已展开 → 进第一个子（前序里就是下一行）；
         * 已展开 → 收起；已收起 → 退到父 */
        tree.collapseAll()
        tree.currentKey = "a"
        tree._expandOrChild()
        ok7 = ok7 && tree.isExpanded("a") === true && tree.currentKey === "a"
        tree._expandOrChild()
        ok7 = ok7 && tree.currentKey === "a1"
        tree._collapseOrParent()
        ok7 = ok7 && tree.currentKey === "a"                 /* a1 本来就没展开 → 退到父 */
        tree.setExpanded("a1", true)
        tree.currentKey = "a1"
        tree._collapseOrParent()
        ok7 = ok7 && tree.isExpanded("a1") === false && tree.currentKey === "a1"

        /* 点击行 = 改 currentKey + 发 nodeClicked */
        tree.expandAll()
        root.clickLog = []
        tree._activateRow(3)
        ok7 = ok7 && tree.currentKey === "a1y" && root.clickLog.join(",") === "a1y"

        /* ── 缩进上限 ──
         * 公式：padding + min(level × indentWidth, width − 2×padding − chevron − minLabel)
         * 期望值用令牌写成表达式而不是硬编码数字 —— 钉住的是**公式**，
         * 令牌改了不该让这条断言跟着炸。 */
        var pad = Theme.space.md, chev = Theme.font.md, minLabel = 64
        var limitWide = 320 - pad * 2 - chev - minLabel
        var okLead2Wide   = pad + 2 * Theme.space.lg            /* 没到上限 */
        var okLeadCapWide = pad + limitWide                     /* 封顶 */
        var ok7b = plainTree._indentLimit === limitWide
                   && plainTree._leadOf(2) === okLead2Wide
                   && plainTree._leadOf(100) === okLeadCapWide

        plainTree.width = 120
        var limitNarrow = 120 - pad * 2 - chev - minLabel
        ok7b = ok7b && plainTree._indentLimit === limitNarrow
                   && plainTree._leadOf(100) === pad + limitNarrow
                   && limitNarrow < limitWide                   /* 窄了真的收住了 */

        /* 极窄时夹到 0，不是负数 —— 负数会让内容跑到控件外面去 */
        plainTree.width = 60
        ok7b = ok7b && plainTree._indentLimit === 0 && plainTree._leadOf(5) === pad
        plainTree.width = 320

        /* 勾选框占位会从可用宽度里扣掉（`checkable` 的树缩进上限更小） */
        tree.width = 320
        ok7b = ok7b && tree._checkLead === tree.checkColumnWidth
                   && tree._indentLimit === limitWide - tree.checkColumnWidth
        tree.checkable = false
        ok7b = ok7b && tree._checkLead === 0 && tree._indentLimit === limitWide
        tree.checkable = true

        ok7 = ok7 && ok7b

        root.bit(7, ok7)

        Qt.exit(Math.min(255, root.failures))
    }
}
