/****************************************************************************
 * QSkin · Quick Design System — Foundation / TreeUtil
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 树形结构的**纯计算**工具。放在地基层而不是契约层，理由和 DateUtil / Theme
 * 一样：它不含任何 UI 决策 —— 没有颜色、没有字号、没有行高、没有"缩进该多少
 * 像素"。它只回答四个问题：
 *
 *     ① 这棵树有哪些节点、谁是谁的子、谁是谁的父   → index()
 *     ② 展开状态下，从根往下**看得见**的是哪一串    → flatten()
 *     ③ 勾了一个节点，集合该怎么变（级联 / 闭合）  → applyCascade() 一族
 *     ④ 一个节点该显示成"全选"还是"半选"           → subtreeHasChecked()
 *
 * 谁长什么样、行多高、箭头画在哪，都是契约层与主题层的事。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么它必须存在 —— 一次"差一点就复制粘贴"的岔口
 * ════════════════════════════════════════════════════════════════════════
 *
 * 这套逻辑原本长在 QSkinTable 里（M14 展平 / M15 键勾选），因为它第一个
 * 宿主是表格。但"树形"和"表格"是两件事：表格是**二维**的（行 × 列），
 * 树是**一维**的（展平后的节点序列）。QSkinTable 的树形模式其实是
 * "一张只有一列值得看的一维树，套了二维的壳"。
 *
 * 于是做 QSkinTree（M17）时会遇到一个岔口：
 *
 *     要么，把那 250 行树逻辑复制一份到新控件里；
 *     要么，先把它拎出来，两边共用。
 *
 * 项目在 Theme / DateUtil 上已经做过两次同样的判断，且 README 里写死了
 * 那条原则：「契约层没定就做控件，等于把逻辑复制 N 份」。这里按同一条
 * 原则处理 —— 而且这次不是预防性的，是**已经摆在面前**的：不拎出来，
 * 从 M17 起就有两份"级联该不该管折叠节点"的实现，早晚分叉成两种行为。
 *
 * 所以这个文件的真正价值不是"省了几百行"，而是**让表格与树不可能在同一
 * 个语义上给出不同答案**。QSkinTree 与 QSkinTable 的树形勾选由此共享同一组
 * 函数，`smoke_m14` / `smoke_m15` 在重构后一条不改仍然全绿 —— 那 22 条
 * 断言就是这次下沉的验收证据。
 *
 * ── 三条不变量（写在实现之前，改动时先看这里）────────────────────────────
 *
 *   1. **两套树视图，职责不同，不要合并。**
 *        受折叠影响、剪枝的   → flatten()        （渲染 / 分页）
 *        不受折叠影响、全树的 → index() / 级联   （勾选 / 祖先链 / 后代集）
 *      合并的代价是"折叠起来的分支不参与级联"，即"折叠会悄悄改变勾选
 *      结果"—— 这是语义错误，不是性能取舍。
 *
 *   2. **祖先的"未选 / 半选"是推导出来的，不写进集合。**
 *      `selectedKeys` 里**只有完全选中的键**。它的不变量是
 *      「父在集合 ⟺ 所有直接子都在集合」。半选由 subtreeHasChecked()
 *      现算（调用方负责缓存，见其注释）。
 *
 *   3. **键的取法只有一处。** `keyOf()` 与 flatten() 里拼回退路径的写法
 *      必须始终一致（回退路径 = 父键 + "/" + **原始下标**）。级联和展开
 *      一旦各认各的键，症状是"展得开但勾不上"，而且只在没有 id 的数据上
 *      出现 —— 极难查。所有键的生成都走 keyOf()，不要就地拼字符串。
 *
 * ── 键从哪来 ─────────────────────────────────────────────────────────────
 *
 * 优先取节点上的 `keyField` 字段（默认由调用方传 "id"）。取不到时**回退到
 * 结构路径**（前缀 "#"，如 "#0/2"），此时同级一排序展开状态就会跟着错位 ——
 * 所以这是"数据没写键"时的可用性兜底，不是推荐做法。前缀 "#" 的存在是为了
 * 让回退键与真实键不可能撞上。
 *
 * ── ★ 结构路径与键是**两个**东西，递归时都要往下传（M17 修） ────────────
 *
 * 拼子路径只能用**结构路径**（纯原始下标串，如 "0/2"），不能用父**键**。
 * 因为父键上已经带了 "#" 前缀，拿它去拼就会在每一层再前缀一个：
 *
 *     根   path "0"     → 键 "#0"
 *     子   path "#0/0"  → 键 "##0/0"        ← 错。应该是 "#0/0"
 *     孙   path "##0/0/0" → 键 "###0/0/0"   ← 错。应该是 "#0/0/0"
 *
 * 这个 bug 从 M14 潜伏到 M17：它**不报错也不影响功能**（展开、级联、展平
 * 三处用的是同一套拼法，自洽），只是上面那句"如 #0/2"成了假的，而且键长
 * 随深度无界增长。发现它的是 `smoke_m17.qml` 的 [0] —— 它是第一个去读
 * 回退键**长什么样**的测试（既有测试全用带 id 的数据）。
 *
 * 教训与 M14 那条同源：**自洽的两个错误实现互相印证，测试只测"两处一致"
 * 就永远是绿的**。要么断言具体值，要么断言不变量以外的东西。
 *
 * ── 键的形状：一律是字符串 ───────────────────────────────────────────────
 *
 * `index.byKey` 是个普通 JS 对象，键天然是字符串。节点若用数字 id（1 / 2），
 * 不做转换的话 `set[1]` 和 `set["1"]` 在同一对象上其实是同一个键，看着能用；
 * 但 `sameKeys()` 比的是数组元素、`selectedKeys` 是**对外**的数组，
 * 数字 1 与字符串 "1" 在那里就不相等了。所以内部统一 String() 归一，
 * 对外输出也是字符串 —— 与 M15 起 QSkinTable 的既有行为一致。
 ****************************************************************************/

pragma Singleton
import QtQuick 2.15

QtObject {
    id: root

    /** 递归深度硬上限。
     *
     * 正常数据永远碰不到（500 层深的树在界面上没有任何意义）。它防的是
     * **数据成环**：使用方给的 children 指回了祖先时，不设限就是无限递归，
     * 栈溢出会让整个 QML 引擎挂掉，而不是报一个错。宁可在 500 层处停住，
     * 也不让一个坏数据把宿主进程带走。 */
    readonly property int maxDepth: 500

    /* ══════════════════ 节点访问 ══════════════════ */

    /**
     * childrenOf(node, childrenKey) → 子节点数组
     * 字段缺失 / 不是数组一律按"没有子节点"处理 —— 不抛错。
     * （树的中间层经常来自"只填了一半"的数据，控件不该因此白屏。）
     */
    function childrenOf(node, childrenKey) {
        if (node === null || node === undefined) return []
        var v = node[childrenKey]
        return (v !== undefined && v !== null && Array.isArray(v)) ? v : []
    }

    /**
     * keyOf(node, path, keyField) → 字符串键
     * 节点上有 keyField 且非空 → String(该值)；否则回退 "#" + path。
     *
     * `path` 由调用方按"父键 + '/' + 原始下标"拼 —— 用**原始下标**而不是
     * 排序后的位置，这样至少不受排序影响。
     */
    function keyOf(node, path, keyField) {
        if (node !== null && node !== undefined && keyField) {
            var v = node[keyField]
            if (v !== undefined && v !== null && v !== "") return String(v)
        }
        return "#" + path
    }

    /* ══════════════════ ① 全树索引 ══════════════════ */

    /**
     * index(nodes, keyField, childrenKey) → {
     *     byKey: { 键 → { node, parentKey, childKeys, level } },
     *     roots: [顶层键],            // 顺序 = 数据顺序（未排序）
     *     order: [全部键],            // **前序**遍历顺序
     *     count: 节点总数
     * }
     *
     * 前序（父在子前）是刻意的：`keysToArray()` 靠它把集合转成稳定数组，
     * 而"稳定"是刻意的 —— 不排的话输出顺序就是用户点击顺序，同一个选中
     * 集合会因为先后不同给出不同数组，用起来像随机数，对比测试尤其难受。
     *
     * 这一份**不受折叠影响**。级联、祖先链、后代集全部基于它。
     */
    function index(nodes, keyField, childrenKey) {
        var out = { byKey: {}, roots: [], order: [], count: 0 }
        root._indexInto(nodes, "", "", 0, keyField, childrenKey, out)
        return out
    }

    /* `parentKey` 与 `parentPath` 是**两个**变量，不能合并：
     *   parentKey   父节点的**键**（可能是 id，也可能是回退键）→ 写进 byKey
     *   parentPath  父节点的**纯结构路径**（原始下标串，绝不含 "#"）→ 只用来拼子路径
     *
     * 合并的代价是 M17 实测到的那个 bug：拿父**键**去拼路径时，父的回退键
     * 自带 "#"，于是每一层都再前缀一个 —— 根是 "#0"、子变成 "##0/0"、
     * 孙变成 "###0/0/0"。它不会报错（展开与级联用的是同一套拼法，自洽），
     * 但 `keyOf` 注释里许诺的 "#0/2" 是假的，而且键长随深度无界增长。 */
    function _indexInto(nodes, parentKey, parentPath, level, keyField, childrenKey, out) {
        if (nodes === null || nodes === undefined) return
        if (level >= root.maxDepth) return
        for (var i = 0; i < nodes.length; ++i) {
            var node = nodes[i]
            var path = parentPath === "" ? String(i) : parentPath + "/" + i
            var k = root.keyOf(node, path, keyField)
            var kids = root.childrenOf(node, childrenKey)
            var childKeys = []
            for (var c = 0; c < kids.length; ++c)
                childKeys.push(root.keyOf(kids[c], path + "/" + c, keyField))
            out.byKey[k] = { node: node, parentKey: parentKey,
                             childKeys: childKeys, level: level }
            out.order.push(k)
            out.count += 1
            if (parentKey === "") out.roots.push(k)
            if (kids.length > 0)
                root._indexInto(kids, k, path, level + 1, keyField, childrenKey, out)
        }
    }

    /**
     * allKeys(nodes, keyField, childrenKey) → [全部键，前序]
     * 不带索引的浅用法（expandAll / collapseAll 之类只需要键的场合）。
     * 需要反复按键查询时请用 index()，别反复调这个。
     */
    function allKeys(nodes, keyField, childrenKey) {
        var out = []
        root._walkKeys(nodes, keyField, childrenKey, 0, "", "", out)
        return out
    }

    /* parentKey / parentPath 分开的理由见 `_indexInto` */
    function _walkKeys(nodes, keyField, childrenKey, level, parentKey, parentPath, out) {
        if (nodes === null || nodes === undefined) return
        if (level >= root.maxDepth) return
        for (var i = 0; i < nodes.length; ++i) {
            var node = nodes[i]
            var path = parentPath === "" ? String(i) : parentPath + "/" + i
            var k = root.keyOf(node, path, keyField)
            out.push(k)
            var kids = root.childrenOf(node, childrenKey)
            if (kids.length > 0)
                root._walkKeys(kids, keyField, childrenKey, level + 1, k, path, out)
        }
    }

    /* ══════════════════ ② 可见行（展平）══════════════════ */

    /**
     * flatten(nodes, opts) → { rows: [节点], meta: [每行的树信息] }
     *
     * opts = {
     *     keyField:     "id",
     *     childrenKey:  "children",
     *     isExpanded:   function(key) → bool,      // 必给
     *     compare:      function(a, b) → number    // 可选，同级排序
     *     sourceIndex:  bool                       // 可选，顶层节点是否带源下标
     * }
     *
     * meta[i] = { key, level, parentKey, hasChildren, expanded, sourceIndex }
     *   sourceIndex 只有**顶层**节点有意义（它们是 nodes 里的下标）；
     *   嵌套节点给 -1。表格靠它把可见行映射回 `rows`（M6 的下标寻址），
     *   树用不到 —— 但两者共用同一个 flatten，所以这个字段对谁都给。
     *
     * ── 排序只作用于**同级兄弟** ───────────────────────────────────────
     * 递归地对每一层排序，绝不跨层搬行。跨层重排会让节点换爹，树就散了。
     * 判据不是"顺序对不对"，而是"**键 → 层级的归属一个都没变**"。
     *
     * ── 排序用原始下标做中介 ───────────────────────────────────────────
     * 不直接重排传入的数组：一来不修改使用方的数据，二来下标还得用来拼
     * 回退路径（见 keyOf 的注释）。
     *
     * 这一份**受折叠影响**，折叠的分支整枝剪掉。
     */
    function flatten(nodes, opts) {
        var out = { rows: [], meta: [] }
        var o = opts || {}
        var keyField    = o.keyField    !== undefined ? o.keyField    : "id"
        var childrenKey = o.childrenKey !== undefined ? o.childrenKey : "children"
        var isExpanded  = o.isExpanded
        var compare     = o.compare !== undefined ? o.compare : null
        /* 顶层节点的源下标：与 nodes 一一对应 */
        var top = []
        for (var i = 0; i < (nodes !== null && nodes !== undefined ? nodes.length : 0); ++i)
            top.push(i)
        root._walkVisible(nodes, top, 0, "", "", o.sourceIndex === true,
                          keyField, childrenKey, isExpanded, compare, out)
        return out
    }

    /* parentKey / parentPath 分开的理由见 `_indexInto` —— 这个必须与它一致，
     * 否则展平出来的键和索引里的键对不上，症状是"展得开但勾不上"。 */
    function _walkVisible(nodes, srcIndexes, level, parentKey, parentPath, wantSourceIndex,
                          keyField, childrenKey, isExpanded, compare, out) {
        if (nodes === null || nodes === undefined) return
        if (level >= root.maxDepth) return

        var order = []
        for (var i = 0; i < nodes.length; ++i) order.push(i)
        if (compare !== null && compare !== undefined) {
            order.sort(function(a, b) { return compare(nodes[a], nodes[b]) })
        }

        for (var j = 0; j < order.length; ++j) {
            var oi = order[j]
            var node = nodes[oi]
            /* 回退路径用**原始下标**而不是排序后位置 —— 至少不受排序影响 */
            var path = parentPath === "" ? String(oi) : parentPath + "/" + oi
            var k = root.keyOf(node, path, keyField)
            var kids = root.childrenOf(node, childrenKey)
            var expanded = isExpanded !== undefined && isExpanded !== null
                           ? isExpanded(k) === true : false

            out.rows.push(node)
            out.meta.push({ key: k,
                            level: level,
                            parentKey: parentKey,
                            hasChildren: kids.length > 0,
                            expanded: expanded,
                            sourceIndex: wantSourceIndex && oi < srcIndexes.length
                                         ? srcIndexes[oi] : -1 })
            if (expanded && kids.length > 0) {
                /* 嵌套节点不在源数组里 → 递归时不带源下标 */
                root._walkVisible(kids, [], level + 1, k, path, false,
                                  keyField, childrenKey, isExpanded, compare, out)
            }
        }
    }

    /**
     * maxIndent(available, padding, chevronWidth, minLabelWidth) → 缩进上限
     *
     * 「缩到"再缩就没字了"就停住」—— 与 minColumnWidth 同一条原则：
     * 宁可少缩进，也不让内容消失。返回夹到 ≥ 0 的值。
     *
     * 只做减法，不关心 available 是列宽还是窗口宽 —— 这正是它能放在
     * 地基层的原因（表格按列宽调，树按控件宽调，公式同一条）。
     */
    function maxIndent(available, padding, chevronWidth, minLabelWidth) {
        return Math.max(0, available - padding * 2 - chevronWidth - minLabelWidth)
    }

    /* ══════════════════ ③ 勾选集合 ══════════════════ */

    /**
     * keySet(keys) → { 键: true }
     * 数组 → 集合。级联里一次写入要问几百次"这个键在不在"，用 `indexOf`
     * 会退化成 O(n²)，所以内部一律用对象查表。
     */
    function keySet(keys) {
        var out = {}
        if (keys !== null && keys !== undefined)
            for (var i = 0; i < keys.length; ++i) out[String(keys[i])] = true
        return out
    }

    /** 集合的浅拷贝（集合里只可能是 true，所以只需拷键） */
    function cloneSet(set) {
        var out = {}
        if (set !== null && set !== undefined)
            for (var k in set) out[k] = true
        return out
    }

    /**
     * applyCascade(idx, key, on, set)
     * 把 key 与其**全部后代**写进 / 移出集合，不限深度。
     * 只动自己的话，勾了父而子还是空的 —— 级联就是干这个的。
     */
    function applyCascade(idx, key, on, set) {
        root._cascadeInto(idx, key, on, set, 0)
    }

    function _cascadeInto(idx, key, on, set, depth) {
        if (depth >= root.maxDepth) return
        var e = idx.byKey[key]
        if (e === undefined) return
        if (on) set[key] = true
        else    delete set[key]
        for (var i = 0; i < e.childKeys.length; ++i)
            root._cascadeInto(idx, e.childKeys[i], on, set, depth + 1)
    }

    /**
     * closeUpwardOne(idx, key, set)
     * 闭合一个节点：它的**所有直接子**都在集合里 → 自己也在集合里，否则移出。
     * 调用方保证此时子节点已经闭合过了（所以反向遍历前序能一遍扫完）。
     */
    function closeUpwardOne(idx, key, set) {
        var e = idx.byKey[key]
        if (e === undefined || e.childKeys.length === 0) return
        for (var i = 0; i < e.childKeys.length; ++i)
            if (set[e.childKeys[i]] !== true) { delete set[key]; return }
        set[key] = true
    }

    /**
     * refreshAncestorsOf(idx, key, set)
     * 从 key 的**父**开始往上逐层重算"完全选中"。
     *
     * 祖先的"未选 / 半选"是**推导**出来的、不写进集合 —— 集合里只有完全
     * 选中的键。所以这里只做两件事：所有子都在 → 加进来；否则 → 移出去。
     * 半选不用管，它由 subtreeHasChecked() 现算。
     *
     * 逐层走是必要的：取消一个三层深的叶子，a1 退出集合之后 a 才可能退出 ——
     * 一遍自底向上才不会漏。
     */
    function refreshAncestorsOf(idx, key, set) {
        var e = idx.byKey[String(key)]
        if (e === undefined) return
        var guard = 0
        while (e.parentKey !== "" && guard++ < root.maxDepth) {
            root.closeUpwardOne(idx, e.parentKey, set)
            var pe = idx.byKey[e.parentKey]
            if (pe === undefined) break
            e = pe
        }
    }

    /**
     * normalize(idx, keys, checkStrictly) → 集合
     *
     * 整份设定选中键时做**级联闭包**：
     *   给了父       → 后代自动补进来
     *   给了全部子   → 父自动补上来
     *   数据里没有的键（陈旧）→ 直接丢弃
     *
     * 为什么要闭合，而不是原样照收：`selectedKeys` 的不变量是
     * 「父在集合 ⟺ 所有直接子都在集合」。照收会收到一个自相矛盾的集合，
     * 之后 isIndeterminate 就会给出莫名其妙的答案 —— 宁可在这里多走一遍，
     * 也不让脏集合流进状态。
     */
    function normalize(idx, keys, checkStrictly) {
        var set = {}
        var src = (keys === null || keys === undefined) ? [] : keys
        for (var i = 0; i < src.length; ++i) {
            var k = String(src[i])
            if (idx.byKey[k] === undefined) continue     /* 陈旧键丢弃 */
            if (checkStrictly) set[k] = true
            else               root.applyCascade(idx, k, true, set)
        }
        if (!checkStrictly) {
            /* 反向遍历前序 = 子先于父 → 一遍扫完就自下而上闭合了 */
            for (var j = idx.order.length - 1; j >= 0; --j)
                root.closeUpwardOne(idx, idx.order[j], set)
        }
        return set
    }

    /* ══════════════════ ④ 半选推导 ══════════════════ */

    /**
     * subtreeHasChecked(idx, set) → { 键: true }
     * 键 → 该节点的**子树里是否有被完全选中的节点**（不含自己）。
     *
     * 半选判据 = 「自己不在集合」且「这个值为 true」。**预计算**而不是每次
     * 现算：渲染时每一行都要问一次，现算就是每行一次子树遍历。
     *
     * 自底向上（后序）一次算完。
     */
    function subtreeHasChecked(idx, set) {
        var out = {}
        root._markHasChecked(idx.roots, idx, set, out, 0)
        return out
    }

    function _markHasChecked(keys, idx, set, out, depth) {
        if (depth >= root.maxDepth) return
        for (var i = 0; i < keys.length; ++i) {
            var e = idx.byKey[keys[i]]
            if (e === undefined) continue
            /* 先递归到子（后序）—— 子算完了才好判自己 */
            root._markHasChecked(e.childKeys, idx, set, out, depth + 1)
            var any = false
            for (var c = 0; c < e.childKeys.length; ++c) {
                var ck = e.childKeys[c]
                if (set[ck] === true || out[ck] === true) { any = true; break }
            }
            out[keys[i]] = any
        }
    }

    /**
     * indeterminateKeys(idx, set, hasChecked) → [半选的键，前序]
     * 半选 = 自己没被完全选中、但子树里有被完全选中的节点。
     * 叶子永远不在这里（没有后代）。`checkStrictly` 下调用方应直接给空数组
     * —— 没有联动就没有半选的语义，这里不做判断，交给调用方决定。
     */
    function indeterminateKeys(idx, set, hasChecked) {
        var out = []
        var order = idx.order
        for (var i = 0; i < order.length; ++i)
            if (set[order[i]] !== true && hasChecked[order[i]] === true)
                out.push(order[i])
        return out
    }

    /* ══════════════════ 集合 → 数组 ══════════════════ */

    /** 集合 → 键数组，按**树的前序**排。见 index() 里关于顺序稳定性的说明 */
    function keysToArray(set, idx) {
        var out = []
        var order = idx.order
        for (var i = 0; i < order.length; ++i)
            if (set[order[i]] === true) out.push(order[i])
        return out
    }

    /** 新数组与旧数组是否等价（比内容不比引用）。两边都按字符串比 */
    function sameKeys(cur, arr) {
        if (cur === null || cur === undefined) return arr.length === 0
        if (cur.length !== arr.length) return false
        for (var i = 0; i < arr.length; ++i)
            if (String(cur[i]) !== arr[i]) return false
        return true
    }

    /** 集合里有多少个键**在树里还真实存在**。
     * 换了数据之后把陈旧键筛掉 —— 否则"全选"会一直亮着。 */
    function countExisting(set, idx) {
        var n = 0
        for (var k in set) if (idx.byKey[k] !== undefined) n += 1
        return n
    }

    /**
     * rowsOfKeys(idx, keys) → [节点对象]
     * 键数组 → 对应的节点数组（跳过树里不存在的键）。
     * 这是"想直接拿数据"时的出口：不必自己再做一遍键 → 节点的映射，
     * 而树形的节点根本不在扁平的 `rows` 里 —— 那一步正是最容易写错的。
     */
    function rowsOfKeys(idx, keys) {
        var out = []
        var src = (keys === null || keys === undefined) ? [] : keys
        for (var i = 0; i < src.length; ++i) {
            var e = idx.byKey[String(src[i])]
            if (e !== undefined) out.push(e.node)
        }
        return out
    }

    /* ══════════════════ 标签取值 ══════════════════ */

    /**
     * labelOf(node, textRole) → 字符串
     * textRole 为空时退化成 String(node) —— 与 QSkinTable 的 `_cellText` 同一条
     * 兜底思路：数据没写字段时不该白屏，宁可显示得难看一点。
     */
    function labelOf(node, textRole) {
        if (node === null || node === undefined) return ""
        if (textRole === undefined || textRole === "")
            return String(node)
        var v = node[textRole]
        return (v === undefined || v === null) ? "" : String(v)
    }

    /* ══════════════════ 级联列（M26）══════════════════ */

    /**
     * columnsOf(nodes, path, opts) → [{ level, parentKey, parentPath,
     *                                   nodes, keys, activeIndex }]
     *
     * `QSkinCascader` 的多列算路。给定根节点集与一条「已展开路径」（**键**数组），
     * 返回每一列该画什么、以及每列里被指到的那一行。
     *
     *     path = []                  → 1 列，全在 level 0，activeIndex 全 -1
     *     path = ["zj"]              → 2 列：根层（activeIndex 指向 zj）、zj 的子层
     *     path = ["zj","hz"]         → 3 列
     *
     * ── 三个刻意的语义，都有理由 ─────────────────────────────────────────
     *
     *   1. **路径里出现不存在的键 → 就地截断，不报错、不补全。**
     *      这是个纯函数，没有 UI 可供它喊人；返回一个"能画出来"的东西
     *      比让调用方去 catch 有用。截断点由 `activeIndex === -1` 标出 ——
     *      调用方据此知道"这条路径只兑现了前 N 层"。
     *
     *   2. **返回的 `keys` 与 `nodes` 一一对应。**
     *      级联要靠键回写 `value`，而**下标会被排序带走**（`QSkinTree` 的
     *      `currentKey` 那句注释记着同一笔账）。两个数组同长同序，
     *      调用方按下标取键即可，不会出现"选中了错的那个"。
     *
     *   3. **末层没有孩子时不再多给一列空列。**
     *      否则面板右侧会挂一条空白竖栏 —— 那是"看起来坏了"的样子。
     *
     * `parentPath` 的拼法必须与 `_walkVisible` / `_indexInto` **逐字一致**
     * （都用**原始下标**），否则算出来的键与索引里的对不上 ——
     * 症状与那两个函数注释里写的同一个：「展得开但勾不上」。
     */
    function columnsOf(nodes, path, opts) {
        var o = opts || {}
        var keyField    = o.keyField    !== undefined ? o.keyField    : "id"
        var childrenKey = o.childrenKey !== undefined ? o.childrenKey : "children"

        var keys = path
        if (keys === null || keys === undefined) keys = []
        /* 单键当作一层 —— 调用方传字符串比传数组自然，不该逼它包一层 */
        if (typeof keys === "string" || typeof keys === "number") keys = [keys]

        var cols = []
        var cur = nodes
        var level = 0
        var parentKey = ""
        var parentPath = ""

        for (;;) {
            var list = cur
            if (list === null || list === undefined) list = []

            var col = { level: level, parentKey: parentKey, parentPath: parentPath,
                        nodes: [], keys: [], activeIndex: -1 }
            for (var i = 0; i < list.length; ++i) {
                var p = parentPath === "" ? String(i) : parentPath + "/" + i
                col.nodes.push(list[i])
                col.keys.push(root.keyOf(list[i], p, keyField))
            }
            cols.push(col)

            if (level >= keys.length) break

            var want = keys[level]
            var at = -1
            for (var j = 0; j < col.keys.length; ++j) {
                if (col.keys[j] === want) { at = j; break }
            }
            if (at < 0) break                 /* 截断：这一层没兑现 */

            col.activeIndex = at

            var kids = root.childrenOf(col.nodes[at], childrenKey)
            if (kids.length === 0) break      /* 末层不留空列 */

            cur = kids
            parentKey  = col.keys[at]
            parentPath = parentPath === "" ? String(at) : parentPath + "/" + at
            level = level + 1
        }

        return cols
    }
}
