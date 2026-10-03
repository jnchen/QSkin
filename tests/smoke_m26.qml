/****************************************************************************
 * QSkin · 冒烟测试 — M26：TreeSelect / Cascader / Tabs 内容区 /
 *                        Transfer / ColorPicker / AutoComplete / Mentions
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这一批的断言为什么大量落在"**纯算路**"上
 * ════════════════════════════════════════════════════════════════════════
 * 七件里有五件的浮层面板是 `Popup`（**独立窗口**）。于是：
 *   · 面板内部的**渲染**抓不到 → 归 `.cache/_verify_m26px.py` 之外的地方，
 *     而那一份也只量触发器（见其文件头的能力边界）。
 *   · 面板内部的**逻辑**却全是纯函数 —— `columnsOf` / `filterBy` /
 *     `_computeContext` / `_labelsOfPath`。**纯函数可以写等号**，
 *     这是本仓最强的一类断言（M24 的二维码、M25 的 ScrollUtil 同理）。
 * 所以分工是：本文件守"算路与契约"，像素核验守"触发器真的画对了"。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 三条"故意不这么写"（别以为是漏了）
 * ════════════════════════════════════════════════════════════════════════
 * ① **不验真鼠标点击 / hover**（勾选框、行点击）。那归
 *    `tests/tst_*.qml`（真事件）。这里只驱动**契约级**的入口
 *    （`moveRight` / `_toggleCheck` / `selectAllSource`），它们是按钮
 *    onClicked 唯一的出口 —— 按钮点不点得着归像素核验。
 * ② **不验文字画在哪儿**。`Slots.label` 的内容是被 Loader 装进去的、
 *    不在 `children` 里，这里一个字都读不到。
 * ③ **不建假 Popup**。`open()` / `close()` 真的作用在真 `Popup` 上，
 *    读的是 `opened` —— 造个假对象只会绕过"Popup 到底开没开"。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 断言清单（位掩码退出码，见 tools/test.sh 文件头；上限 8 条）
 * ════════════════════════════════════════════════════════════════════════
 *   [0] TreeUtil.columnsOf：列数 / 就地截断 / 末层不留空列 / 字符串当一层 /
 *       下标路径 parentPath / 无键节点得到 `#<下标路径>` / nodes 与 keys 同长
 *   [1] QSkinTreeSelect：_pathOf 与 _labelOf（showPath / separator / 多选摘要）
 *       + selectedKeys 两个视图 + clear + _runSearch 的"只展开不收起"
 *       + **多选摘要用的是调用方给的键**（树的级联闭包不回填 `values`）
 *   [2] QSkinCascader：valuePath 的"字符串当单层" + text 逐层 join + 截断不崩
 *       + 列视图（`_cols` 跟 `_path` 走）+ open() 时 `_path` 从 valuePath 播种
 *       + _activate 的两支（有子只展开 / 叶子提交）+ changeOnSelect
 *   [3] QSkinTabs 内容区：contentDelegate 为 null 时的**零回归**（总高 = tabHeight）
 *       + 非空时的三段和 + contentHeight=-1 落到 delegate 的 implicitHeight
 *       + keepAlive 的实例身份（true 不重建 / false 重建）
 *       + 控制柄注入是**可选**的（delegate 声明了 `control` 才拿到）
 *   [4] QSkinTransfer：两栏分类与顺序 + 禁用项不参与勾选计数与全选 +
 *       _moveKeys 的两支与"搬完清那一侧勾选" + 行结构里**没有** checked
 *   [5] QSkinColorPicker：hex 规范化（大写 6 位 / 短写展开 / 非法忽略）+
 *       _applyHsv 与 _syncStateFromValue 的一致性 + 灰阶反推 h=0 +
 *       swatchRing 六顶点（定义式）+ chipInset 算式
 *   [6] QSkinAutoComplete：空查询给全量 + maxSuggestions 截断 + 候选带**原下标**
 *       + 无匹配给空 + _moveActive 在未开面板时只开不动 + _commit 的回填与越界守卫
 *   [7] QSkinMentions：inputHeight = controlLg*2 + @ 语境的四条边界（无 @ /
 *       在 @ 里 / 已隔开 / 前面有字只取触发符之后）+ _commit 只换那一段 +
 *       appendMention 的拼法（**连叫两次不重复加分隔符**）
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int mask: 0
    property int idx: 0

    width: 1200
    height: 900

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    /** 跑一段会写断言的代码；抛异常算这一条失败。
     *  理由与 smoke_m21~m25 同源：分回合时任何 TypeError 都会让 run()
     *  中断、Qt.exit 永不执行，而 qml.exe 是个开着窗口的 GUI 进程 ——
     *  测试不是失败，是永远挂着（tools/test.sh 的超时看门狗兜这一层）。 */
    function check(block) {
        var ok = false
        try { ok = block() === true } catch (e) { ok = false }
        root.expect(ok)
    }

    /** 一次性把所有断言包进一个 check（位掩码只有 8 位，到顶时的正解是
     *  合并同类项，不是往上加位）。 */
    function all(conds) {
        for (var i = 0; i < conds.length; ++i)
            if (conds[i] !== true) return false
        return true
    }

    /* ══════════════════ 遍历辅助（与 smoke_m23~m25 同一份）══════════════════ */

    function findAll(item, pred) {
        var out = []
        root.collect(item, pred, out, 0)
        return out
    }

    function findIn(item, pred) {
        var out = []
        root.collect(item, pred, out, 0)
        return out.length > 0 ? out[0] : null
    }

    /** 深度上限 16：万一遇到环也不会死循环。 */
    function collect(item, pred, out, d) {
        if (item === null || item === undefined || d > 16) return
        if (pred(item)) out.push(item)
        var kids = item.children
        if (kids === undefined || kids === null) return
        for (var i = 0; i < kids.length; ++i)
            root.collect(kids[i], pred, out, d + 1)
    }

    /** 找控件内部那个真的 `TextInput`（Mentions 要驱动光标 = 驱动 `@` 语境）*/
    function inputOf(ctl) {
        return root.findIn(ctl, function (it) {
            return typeof it.cursorPosition === "number"
                   && typeof it.text === "string"
                   && it.hasOwnProperty("wrapMode") === true
        })
    }

    /** 把 `ctl.text` 设上，并把光标摆到指定的逻辑位置。
     *  `cursorPosition` 没有公开属性，只能从内部 `TextInput` 上驱动 —— 而
     *  "光标在哪"正是 `@` 语境的输入，绕不过去。
     *
     *  ⚠ **必须先归零再摆位**：`QSkinMentions` 的"自动开面板"挂在
     *  `onCursorPositionChanged` 上（不是 `onTextChanged` —— 那条会被
     *  "input.text === root.text" 的守卫挡掉，程序化赋值正是那个情况）。
     *  而写完 `text` 之后光标本来就在末尾，直接赋 `s.length` 是个**无变化**
     *  的写入，信号不发、面板不开。先把位置拨到 0 再拨回去，才是"用户真的
     *  把光标放到了那儿"。 */
    function typeText(ctl, s, pos) {
        ctl.text = s
        var ti = root.inputOf(ctl)
        if (ti === null) return null
        ti.cursorPosition = 0
        ti.cursorPosition = (pos === undefined) ? s.length : pos
        return ti
    }

    /* ══════════════════════ 夹具 ══════════════════════ */

    /* 树：浙江(杭州(西湖区), 宁波) / 江苏 —— 共 5 个节点 */
    property var tree: [
        { id: "zj", label: "浙江", children: [
            { id: "hz", label: "杭州", children: [
                { id: "xh", label: "西湖区" }
            ] },
            { id: "nb", label: "宁波" }
        ] },
        { id: "js", label: "江苏", children: [] }
    ]

    /* 无 `id` 的树：键必须退化成 `#<下标路径>` */
    property var nameless: [
        { label: "甲", children: [ { label: "乙" } ] }
    ]

    /* 级联：杭州 / 宁波 / 南京都是叶子（好让 _commitActive 一步提交）*/
    property var cats: [
        { id: "zj", label: "浙江", children: [
            { id: "hz", label: "杭州" },
            { id: "nb", label: "宁波" }
        ] },
        { id: "js", label: "江苏", children: [
            { id: "nj", label: "南京" }
        ] }
    ]

    property var people: [
        { id: "alice", label: "爱丽丝" },
        { id: "bob",   label: "鲍勃" }
    ]

    property var cities: [
        { id: "bj", label: "北京" },
        { id: "sh", label: "上海" }
    ]

    property var log: []

    /* ══════════════════════ 控件 ══════════════════════ */

    QSkinTreeSelect {
        id: ts
        nodes: root.tree
        textRole: "label"
        value: "hz"
        showPath: true
    }

    QSkinTreeSelect {
        id: tsMulti
        nodes: root.tree
        textRole: "label"
        multiple: true
        values: ["hz", "nb"]
    }

    QSkinCascader {
        id: cas
        nodes: root.cats
        textRole: "label"
        value: ["zj", "hz"]
    }

    QSkinTabs {
        id: tabsPlain
        model: ["一", "二", "三"]
        currentIndex: 0
    }

    /* 内容区 delegate。抽成顶层 `Component`（形状与 smoke_m25 的 `fakeComp`
     * 一致）—— 它要数"被装了几次"，就得碰 `root.builds`，而外层 id 在
     * qmllint 眼里一律算「嵌套组件里的非限定访问」。它建议
     * `pragma ComponentBehavior: Bound`，那会改掉整个文件的 id 解析语义，
     * 本仓不用（与 HelloM25 / QSkinMenubar / QSkinAnchor 同一处置）。 */
    Component {
        id: bodyPane

        Item {
            implicitHeight: 50
            // qmllint disable unqualified
            Component.onCompleted: root.builds++
            // qmllint enable unqualified
        }
    }

    property int builds: 0

    /* 另一个 delegate：**声明了** `control`。用来钉住"注入是可选的"这件事 ——
     * 上面那个 `bodyPane` 什么都没声明（它能不能跑起来本身就是一条断言：
     * 打不进去的绑定会喊 console 噪音），这一个声明了就必须要拿到句柄。 */
    Component {
        id: bodyPaneCtl

        Item {
            property var control: null
            property string paneTag: "ctl"

            implicitHeight: 40
        }
    }

    QSkinTabs {
        id: tabsCtl
        model: ["一", "二"]
        currentIndex: 0
        contentHeight: 40
        contentDelegate: bodyPaneCtl
    }

    QSkinTabs {
        id: tabsBody
        model: ["一", "二", "三"]
        currentIndex: 0
        contentHeight: 80
        contentDelegate: bodyPane
    }

    QSkinTransfer {
        id: tr
        dataSource: [
            { key: "a", label: "乙 A" },
            { key: "b", label: "乙 B" },
            { key: "c", label: "乙 C" },
            { key: "d", label: "乙 D", disabled: true }
        ]
        targetKeys: ["c"]
    }

    QSkinColorPicker { id: cp; value: "#1677FF" }

    QSkinAutoComplete {
        id: ac
        options: root.cities
        textRole: "label"
        openOnFocus: false
    }

    QSkinMentions {
        id: mn
        options: root.people
        textRole: "label"
    }

    /* ══════════════════════════════════════════════════════════════════════
     * 跑
     * ══════════════════════════════════════════════════════════════════════ */

    function run() {
        /* ───────────── [0] columnsOf ───────────── */
        root.check(function () {
            var c0 = TreeUtil.columnsOf(root.tree, [], {})
            var c1 = TreeUtil.columnsOf(root.tree, ["zj"], {})
            var c2 = TreeUtil.columnsOf(root.tree, ["zj", "hz"], {})
            var c3 = TreeUtil.columnsOf(root.tree, ["zj", "hz", "xh"], {})
            var c4 = TreeUtil.columnsOf(root.tree, ["zj", "zz"], {})
            var c5 = TreeUtil.columnsOf(root.tree, ["zz"], {})
            var c6 = TreeUtil.columnsOf(root.tree, "zj", {})
            var c7 = TreeUtil.columnsOf(root.nameless, ["#0"], {})

            /* 每列 nodes 与 keys 必须同长同序 —— 不然 `keys[row]` 会串位 */
            var sameLen = true
            var allCols = c0.concat(c1).concat(c2).concat(c3).concat(c4)
                            .concat(c5).concat(c6).concat(c7)
            for (var i = 0; i < allCols.length; ++i)
                if (allCols[i].nodes.length !== allCols[i].keys.length) sameLen = false

            return root.all([
                c0.length === 1 && c0[0].level === 0 && c0[0].activeIndex === -1,
                c0[0].keys.length === 2 && c0[0].keys[0] === "zj" && c0[0].keys[1] === "js",
                c0[0].parentKey === "" && c0[0].parentPath === "",

                c1.length === 2 && c1[0].activeIndex === 0,
                c1[1].keys.length === 2 && c1[1].keys[0] === "hz" && c1[1].keys[1] === "nb",
                c1[1].parentKey === "zj" && c1[1].parentPath === "0",
                c1[1].activeIndex === -1 && c1[1].level === 1,

                /* 三层：末列要给出 西湖区，但 activeIndex 仍是 -1（路径只到 hz）*/
                c2.length === 3 && c2[2].keys.length === 1 && c2[2].keys[0] === "xh",
                c2[2].parentKey === "hz" && c2[2].parentPath === "0/0",

                /* 路径走到底：末层无子 → **不**多给一个空列 */
                c3.length === 3 && c3[2].activeIndex === 0,

                /* 截断：这一层没兑现 → 列还在（要显示可选项）、activeIndex = -1 */
                c4.length === 2 && c4[1].activeIndex === -1 && c4[1].keys.length === 2,
                /* 第一层就没兑现 → 只有一列 */
                c5.length === 1 && c5[0].activeIndex === -1,
                /* 字符串当一层 */
                c6.length === 2 && c6[0].activeIndex === 0,

                /* 无键节点 → `#<下标路径>`（`keyOf` 的兜底）*/
                c7.length === 2 && c7[0].keys[0] === "#0" && c7[1].keys[0] === "#0/0",

                sameLen
            ])
        })

        /* ───────────── [1] TreeSelect ───────────── */
        root.check(function () {
            ts.showPath = true
            var vPath = ts.text === "浙江 / 杭州"
            ts.showPath = false
            var vLeaf = ts.text === "杭州"
            ts.separator = ">"
            ts.showPath = true
            var vSep = ts.text === "浙江>杭州"
            ts.separator = " / "

            /* 多选：**给两个叶子就回两个**。级联闭包（连浙江一起选中）该活在
             * 树里、由勾选框画出来，不该把调用方给的 `values` 改写成四个
             * —— 这条是 M26 冒烟第一趟跑红的实测结论（修在 `_syncing`）。 */
            var vMulti = tsMulti.selectedKeys.join("+") === "hz+nb"
                       && tsMulti.text === "杭州 等 2 项"
                       && tsMulti.hasValue === true

            var vSingle = ts.selectedKeys.length === 1
                          && ts.selectedKeys[0] === "hz"
            var vMiss = ts._pathOf("nope").length === 0
                        && ts._labelOf("nope") === ""

            /* 5 个节点全展开 = 5 行（defaultExpandAll 默认 true） */
            var vRows = ts._rowCount() === 5

            /* `_runSearch` 只**并**上祖先链，不收起用户展开过的分支 →
             * 命中"宁波"之后可见行数不该变少 */
            var before = ts._rowCount()
            root.log = []
            ts.searchChanged.connect(function (q) { root.log.push(q) })
            ts._runSearch("宁波")
            var vSearch = ts._rowCount() === before && root.log.length === 1
                          && root.log[0] === "宁波"
            /* 空查询：直接返回，什么都不动 */
            ts._runSearch("")
            var vSearchEmpty = ts._rowCount() === before

            /* clear 走契约：值清空且发信号 */
            root.log = []
            ts.selectionChanged.connect(function (ks) { root.log.push(ks.length) })
            ts.clear()
            var vClear = ts.hasValue === false && ts.text === ""
                         && root.log.length === 1 && root.log[0] === 0

            return root.all([vPath, vLeaf, vSep, vMulti, vSingle, vMiss,
                             vRows, vSearch, vSearchEmpty, vClear])
        })

        /* ───────────── [2] Cascader ───────────── */
        root.check(function () {
            cas.value = ["zj", "hz"]
            var v1 = cas.text === "浙江 / 杭州" && cas.hasValue === true
            /* 字符串当单层 */
            cas.value = "js"
            var v2 = cas.valuePath.length === 1 && cas.text === "江苏"
            /* 空 */
            cas.value = []
            var v3 = cas.text === "" && cas.hasValue === false
            cas.value = null
            var v4 = cas.valuePath.length === 0
            /* 中途不存在 → 只回出前面几段（不崩、不补全）*/
            cas.value = ["zj", "zz", "x"]
            var v5 = cas.text === "浙江"
            /* separator */
            cas.separator = ">"
            cas.value = ["zj", "hz"]
            var v6 = cas.text === "浙江>杭州"
            cas.separator = " / "

            /* 列视图：`_cols` 跟着**交互路径** `_path` 走，不是跟着 `value`
             * 走 —— `value` 是"我已经提交了什么"，`_path` 是"我在面板里走到
             * 了哪儿"。没打开面板时 `_path` 是空的，所以只有一列。 */
            cas.value = []
            cas._path = []
            var v7 = cas._cols.length === 1 && cas._isEmpty === false
                     && cas._keyAt(0, 0) === "zj" && cas._keyAt(0, 9) === ""
                     && cas._rowsInCol(0) === 2

            /* 打开面板时 `_path` 从 `valuePath` **播种** —— 这就是"点开就
             * 停在我上次选的那一层"。改 `value` 本身不动路径。 */
            cas.value = ["zj"]
            var vSeed = cas._path.length === 0
            cas.open()
            var v8 = vSeed && cas._path.join(",") === "zj"
                     && cas._cols.length === 2 && cas._nodeAt(1, 1).id === "nb"
            cas.close()
            cas.value = []
            cas._path = []

            /* _activate 两支：有子 → 只展开（不提交）；叶子 → 提交 */
            root.log = []
            cas.picked.connect(function (ks, labels) { root.log.push(labels.join("|")) })
            cas.changeOnSelect = false
            cas._activate(0, 0)                       /* 浙江（有子）*/
            var v9 = cas.value.length === 0 && cas._activeCol === 1 && cas._activeRow === 0
                     && root.log.length === 0
            cas._commitActive()                       /* 第 2 列第 0 行 = 杭州（叶子）*/
            var v10 = cas.value.length === 2 && cas.value[0] === "zj"
                      && cas.value[1] === "hz"
                      && root.log.length === 1 && root.log[0] === "浙江|杭州"

            /* changeOnSelect：有子也当场提交 */
            cas.value = []
            root.log = []
            cas.changeOnSelect = true
            cas._activate(0, 0)
            var v11 = cas.value.length === 1 && cas.value[0] === "zj"
                      && root.log.length === 1 && root.log[0] === "浙江"

            /* 点叶子（江苏→南京）不依赖 changeOnSelect */
            cas.changeOnSelect = false
            cas.value = []
            root.log = []
            cas._activate(0, 1)                       /* 江苏 → 下一个会走到南京 */
            var v12 = cas._activeCol === 1 && cas._activeRow === 0
            cas._activate(1, 0)                       /* 南京（叶子）*/
            var v13 = cas.value.join(",") === "js,nj" && root.log.length === 1

            return root.all([v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13])
        })

        /* ───────────── [3] Tabs 内容区 ───────────── */
        root.check(function () {
            var tabH = Theme.size.controlLg
            var gap  = Theme.space.md

            /* 零回归：没有内容区时总高**就是** tabHeight */
            var vPlain = tabsPlain._hasContent === false
                         && tabsPlain.implicitHeight === tabH

            /* 有内容区：三段和 */
            var vBody = tabsBody._hasContent === true
                        && tabsBody.implicitHeight === tabH + gap + 80

            /* contentHeight = -1 → 落到 delegate 的 implicitHeight（50）*/
            var saved = tabsBody.contentHeight
            tabsBody.contentHeight = -1
            var vAuto = tabsBody._contentResolved === 50
                       && tabsBody.implicitHeight === tabH + gap + 50
            tabsBody.contentHeight = saved

            /* keepAlive：切换时实例身份不变 */
            var n0 = root.builds
            tabsBody.currentIndex = 1
            tabsBody.currentIndex = 2
            var vKeep = root.builds === n0

            /* keepAlive = false → 每次切换重建 */
            tabsBody.keepAlive = false
            tabsBody.currentIndex = 0
            var vRebuild = root.builds === n0 + 1
            tabsBody.currentIndex = 1
            var vRebuild2 = root.builds === n0 + 2

            /* 改 delegate 一定重建（三条触发路径里最硬的一条）*/
            tabsBody.keepAlive = true
            var same = tabsBody.contentDelegate
            tabsBody.contentDelegate = null
            var vNull = tabsBody._hasContent === false
                        && tabsBody.implicitHeight === tabH
            tabsBody.contentDelegate = same
            var vBack = tabsBody._hasContent === true && tabsBody.implicitHeight === tabH + gap + 80

            /* 控制柄注入是**可选**的：delegate 声明了 `control` 才拿到。
             * 声明了就必须要拿到 —— 这条同时证伪"守卫写宽了、把该注入的
             * 也一起挡掉了"（`QSkinTabs` 里那句 `hasOwnProperty` 的守卫）。 */
            var paneCtl = root.findIn(tabsCtl, function (it) {
                return it.hasOwnProperty("paneTag") && it.paneTag === "ctl"
            })
            var vInject = paneCtl !== null && paneCtl.control !== null
                          && paneCtl.control.currentIndex === 0
                          && paneCtl.control.count === 2
                          && paneCtl.control.currentTitle === "一"
                          && paneCtl.control.enabled === true

            return root.all([vPlain, vBody, vAuto, vKeep, vRebuild, vRebuild2,
                             vNull, vBack, vInject])
        })

        /* ───────────── [4] Transfer ───────────── */
        root.check(function () {
            var vCounts = tr.sourceCount === 3 && tr.targetCount === 1
            var vKeys = tr.sourceItems.length === 3
                        && tr.sourceItems[0].key === "a"
                        && tr.sourceItems[1].key === "b"
                        && tr.sourceItems[2].key === "d"
                        && tr.targetItems.length === 1 && tr.targetItems[0].key === "c"
            var vDis = tr._isDisabled(tr.dataSource[3]) === true
                       && tr._isDisabled(tr.dataSource[0]) === false

            /* 行结构里**没有** `checked` —— 有的话列表会在勾选时整体重建 */
            var vRowShape = tr.sourceItems[0].checked === undefined
                            && tr.sourceItems[0].side === "left"
                            && tr.targetItems[0].side === "right"

            /* 勾选计数要排掉禁用项 —— 这正是 `_usableCheckedCount` 存在的理由 */
            tr._checkedLeft = ["d"]
            var vUsable = tr.checkedLeftCount === 0
            tr._checkedLeft = ["a", "d"]
            var vUsable2 = tr.checkedLeftCount === 1

            /* 全选源栏：只碰可用项（d 禁用 → 不进）*/
            tr.selectAllSource()
            var vAllSrc = tr._checkedLeft.length === 2
                          && tr._checkedLeft.indexOf("a") >= 0
                          && tr._checkedLeft.indexOf("b") >= 0
                          && tr._checkedLeft.indexOf("d") < 0
                          && tr.checkedLeftCount === 2

            /* 右移：搬勾选、清那一侧勾选、发信号带三个实参 */
            root.log = []
            tr.changed.connect(function (keys, toTarget, moved) {
                root.log.push(keys.join("+") + "|" + toTarget + "|" + moved.join("+"))
            })
            tr.moveRight()
            var vMove = tr.targetKeys.join("+") === "c+a+b"
                        && tr._checkedLeft.length === 0
                        && tr._checkedRight.length === 0
                        && root.log.length === 1
                        && root.log[0] === "c+a+b|true|a+b"

            /* 左移回来：targetKeys 清空（b 与 a 回源栏）*/
            tr._checkedRight = ["c", "a", "b"]
            root.log = []
            tr.moveLeft()
            var vLeft = tr.targetKeys.length === 0 && tr._checkedRight.length === 0
                        && root.log.length === 1 && root.log[0] === "|false|c+a+b"

            /* 空勾选 → 什么都不做（也不发信号）*/
            root.log = []
            tr.moveLeft()
            var vNoop = tr.targetKeys.length === 0 && root.log.length === 0

            /* 标题条高度：没标题 / 不显示标题 → 0 */
            var vTitle = tr._titleOf(0) === "" && tr._headHeightOf(0) === 0
            tr.titles = ["待选", "已选"]
            var vShown = tr._titleOf(0) === "待选"
                         && tr._headHeightOf(0) === Theme.size.controlSm
            tr.showTitles = false
            var vHidden = tr._titleOf(0) === "" && tr._headHeightOf(0) === 0

            return root.all([vCounts, vKeys, vDis, vRowShape, vUsable, vUsable2,
                             vAllSrc, vMove, vLeft, vNoop, vTitle, vShown, vHidden])
        })

        /* ───────────── [5] ColorPicker ───────────── */
        root.check(function () {
            cp.value = "#1677FF"
            var v1 = cp.hex === "#1677FF"
            var v2 = cp.setHex("#198cff") === true && cp.hex === "#198CFF"
            var v3 = cp.setHex("#fff") === true && cp.hex === "#FFFFFF"
            var v4 = cp.setHex("nope") === false && cp.hex === "#FFFFFF"
            var v5 = cp.setHex("#12345") === false && cp.hex === "#FFFFFF"

            /* _rgbOf：Qt color → 0..255 */
            cp.value = "#FF8000"
            var r = cp._rgbOf(cp.value)
            var v6 = r.r === 255 && r.g === 128 && r.b === 0

            /* _applyHsv 与 _syncStateFromValue 必须互为逆（同一份 ColorUtil）*/
            cp._applyHsv(210, 0.9, 1)
            var v7 = cp.hex === "#198CFF" && cp.hue === 210
                     && cp.saturation === 0.9 && cp.brightness === 1
            cp._syncStateFromValue()
            var v8 = cp.hue === 210

            cp._applyHsv(120, 1, 1)
            var v9 = cp.hex === "#00FF00"
            /* 六个顶点是**定义**，不是拟合 */
            cp._applyHsv(0,   1, 1); var v10 = cp.hex === "#FF0000"
            cp._applyHsv(60,  1, 1); var v11 = cp.hex === "#FFFF00"
            cp._applyHsv(180, 1, 1); var v12 = cp.hex === "#00FFFF"
            cp._applyHsv(240, 1, 1); var v13 = cp.hex === "#0000FF"
            cp._applyHsv(300, 1, 1); var v14 = cp.hex === "#FF00FF"

            /* 灰阶：色相无处可推 → 刻意归 0（不是 NaN、不是沿用旧值）*/
            cp._applyHsv(200, 1, 1)
            cp.value = "#808080"
            cp._syncStateFromValue()
            var v15 = cp.hue === 0 && cp.saturation === 0
                      && Math.abs(cp.brightness - 128 / 255) < 0.01

            /* 色板数量（swatchRing 的定义式在 tools/check-color-util.js 里守）*/
            var v16 = cp.presets.length === 12
            var v17 = cp.chipInset === Math.max(
                        Theme.space.xs,
                        Math.round((Theme.size.controlMd - Theme.size.controlSm) / 2))

            /* 当前色标：命中自己为真、给别人为假 */
            var v18 = cp._swatchIsCurrent(cp.hex) === true
                      && cp._swatchIsCurrent("#000000") === false

            return root.all([v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11,
                             v12, v13, v14, v15, v16, v17, v18])
        })

        /* ───────────── [6] AutoComplete ───────────── */
        root.check(function () {
            /* 空查询 → 全量（`filterBy` 对空查询刻意给 0 项，所以这条分支
             *  必须写在控件里 —— 钉住它）*/
            ac.text = ""
            var v1 = ac.suggestions.length === 2
                     && ac.suggestions[0].index === 0
                     && ac.suggestions[1].index === 1
            ac.maxSuggestions = 1
            var v2 = ac.suggestions.length === 1
            ac.maxSuggestions = 0

            /* 过滤后仍带**原下标**（不是过滤后的下标）*/
            ac.text = "上海"
            var v3 = ac.suggestions.length === 1
                     && ac.suggestions[0].index === 1
                     && ac.suggestions[0].text === "上海"

            ac.text = "不存在的城市"
            var v4 = ac.suggestions.length === 0 && ac._isEmpty === true

            /* 未开面板时方向键只负责开、**不移动**高亮 */
            ac.text = ""
            ac.close()
            ac._activeIndex = -1
            ac._moveActive(1)
            var v5 = ac.opened === true && ac._activeIndex === -1
            ac.close()
            var v6 = ac.opened === false

            /* _commit：回填 text、带出 item、报**原下标** */
            ac.text = "上海"
            root.log = []
            ac.selected.connect(function (item, index) { root.log.push(index) })
            ac._commit(0)
            var v7 = ac.text === "上海" && ac.value !== null
                     && ac.value.id === "sh" && ac.opened === false
                     && root.log.length === 1 && root.log[0] === 1

            /* 越界守卫 */
            var keepText = ac.text
            ac._commit(9)
            ac._commit(-1)
            var v8 = ac.text === keepText

            /* 字符串候选 + textRole 为空 → 直接用字符串本身 */
            ac.options = ["甲", "乙"]
            ac.text = "乙"
            var v9 = ac.suggestions.length === 1 && ac.suggestions[0].text === "乙"
            ac.options = root.cities

            return root.all([v1, v2, v3, v4, v5, v6, v7, v8, v9])
        })

        /* ───────────── [7] Mentions ───────────── */
        root.check(function () {
            /* 多行输入：高度是 controlLg 的两倍（与 AutoComplete 的 controlMd
             *  不同 —— 这正是示例屏 A 组标题一度写错的那件事）*/
            var v1 = mn.inputHeight === Theme.size.controlLg * 2
                     && mn.implicitHeight === Theme.size.controlLg * 2

            /* 没有前缀 → 不在提及里 */
            root.typeText(mn, "今天天气不错")
            var v2 = mn._inMention === false && mn.suggestions.length === 0
                     && mn.opened === false

            /* 刚打出 `@` → 词为空 → 给全量候选 */
            root.typeText(mn, "今天 @", 4)
            var v3 = mn._inMention === true && mn._context.word === ""
                     && mn.suggestions.length === 2 && mn.opened === true

            /* 触发符之后才参与过滤：前面那个"今天 "不参与 */
            root.typeText(mn, "今天 @爱", 5)
            var v4 = mn._context.word === "爱" && mn.suggestions.length === 1
                     && mn.suggestions[0].text === "爱丽丝"
                     && mn.suggestions[0].index === 0

            /* 已经隔开（词里有 separator）→ 这一段说完了 */
            root.typeText(mn, "今天 @爱丽丝 后面")
            var v5 = mn._inMention === false && mn.suggestions.length === 0

            /* `@` 在光标右边 → 不算 */
            root.typeText(mn, "@爱丽丝", 0)
            var v6 = mn._inMention === false

            /* _commit：只换 `@词` 那一段，前面的字一个不碰 */
            root.typeText(mn, "今天 @爱", 5)
            root.log = []
            mn.selected.connect(function (item, index) { root.log.push(index) })
            mn._commit(0)
            var v7 = mn.text === "今天 @爱丽丝 " && mn.value.length === 1
                     && mn.value[0].id === "alice"
                     && root.log.length === 1 && root.log[0] === 0

            /* 越界 / 没有语境 → 不动 */
            var keep = mn.text
            mn._commit(9)
            var v8 = mn.text === keep

            /* appendMention：空文本不加前置分隔符；非空要加 */
            mn.text = ""
            mn.value = []
            mn.appendMention("鲍勃")
            var v9 = mn.text === "@鲍勃 "
            mn.appendMention("爱丽丝")
            var v10 = mn.text === "@鲍勃 @爱丽丝 " && mn.value.length === 0

            return root.all([v1, v2, v3, v4, v5, v6, v7, v8, v9, v10])
        })

        Qt.exit(root.mask)
    }

    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }

    /* 推迟一轮再断言：布局与 `implicitHeight` 的重算在 polish 阶段
     * （见 smoke_sizes.qml 的时序说明）—— [3] 读的全是尺寸。 */
    Component.onCompleted: function () {
        try {
            Qt.callLater(root.run)
        } catch (e) {
            Qt.exit(255)
        }
    }
}
