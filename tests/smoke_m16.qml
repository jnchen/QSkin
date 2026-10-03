/****************************************************************************
 * QSkin · 冒烟测试 —— M16：QSkinTable 右侧固定列
 *
 * 断言写法见 tools/test.sh 文件头：≤ 8 条，bit n = 断言 [n]。
 *
 * ── 这轮要守的核心不变量 ───────────────────────────────────────────────
 * M13 的双区是「左固定 + 滚动」。加到三区（左 / 中 / 右）看着只是多摆
 * 一个 Item，实际逼出三件必须同时成立的事，少一条就塌：
 *
 *   ① **内容侧与屏幕侧必须分成两个概念。**
 *      `_fixedWidth` / `_rightTotal` 回答"哪几列不参与滚动"（内容坐标）；
 *      `_leftWidth` / `_rightWidth` / `_middleWidth` 回答"三个区各占多宽"
 *      （屏幕坐标）。两者在容器够宽时相等 —— 容器比钉住列还窄时分叉。
 *      M13 只有左边时这个分叉不会暴露（左区溢出容器只是自己被裁掉），
 *      加了右区就必须补上，否则右区会滑到容器左沿外面去。
 *
 *   ② **能滚多远与钉住多少无关。**
 *      `_maxScrollX` 代入三区宽度后化简为 `内容总宽 - 容器宽`，左右
 *      固定宽各消掉一次。这条性质是"中间区与右固定区在滚到底时恰好
 *      接上"的代数形式 —— 钉住既不凭空造出滚动范围，也不吃掉它。
 *      所以断言 [2] 拿同一套列、只改 `fixedRightColumns` 比滚动上限。
 *
 *   ③ **一列不能同时钉在两边。**
 *      `_rightCount` 的上限是"列数 - 左固定列数"。夹掉之后区间不重叠，
 *      `内容总宽 = 左固定 + 中间 + 右固定` 才是真划分，`_scrollableContentWidth`
 *      才是个不会把同一段内容减两遍的减法。
 *
 * 断言分工：
 *   [0] 三区划分恒等式 + 非负（不重叠、不留缝的代数形式）
 *   [1] `_rightTotal` = 最右 N 列之和；`_rightCount` 夹取且与左不重叠
 *   [2] ★ 钉住不改变滚动范围（同一套列，只改 fixedRightColumns）
 *   [3] `_scrollableContentWidth = 内容 - 左 - 右`，`_maxScrollX = 可滚 - 中间`
 *   [4] 退化：容器比钉住列还窄 → 中间区 0、上限 0、右区不越过左区右沿
 *   [5] 几何：真的存在三个覆盖整条带的 clip 区域，且右区贴右沿、
 *       宿主偏移 = 右区宽 - 内容总宽（内容右端落在容器右沿）
 *   [6] 正交：checkable + 树形 + 左右固定同时开，三条不变式都还在
 *   [7] 零回归：不钉右边时一切与 M13 相同
 *
 * 几何只断言"区域存在且贴边"，具体渲染（三道箭头、两道渐隐条）走截图。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int failures: 0

    function bit(n, ok) { if (!ok) root.failures |= (1 << n) }

    /* ══════════════════ 共用的列与数据 ══════════════════ */

    /* 4 列显式宽合计 1400 —— 与 contentWidth 相等，列宽计算不掺等分，
     * 断言里的数字可以直接手算核对。 */
    readonly property var cols4: [
        { title: "文件名", dataIndex: "name",   width: 200 },
        { title: "摘要",   dataIndex: "note",   width: 400 },
        { title: "正文",   dataIndex: "body",   width: 600 },
        { title: "状态",   dataIndex: "status", width: 200 }
    ]

    readonly property var rows4: [
        { name: "index.qml", note: "入口", body: "…", status: "已同步" },
        { name: "table.qml", note: "表格", body: "…", status: "草稿" }
    ]

    readonly property var cols3: [
        { title: "A", dataIndex: "a", width: 400 },
        { title: "B", dataIndex: "b", width: 400 },
        { title: "C", dataIndex: "c", width: 400 }
    ]

    readonly property var rows3: [{ a: "1", b: "2", c: "3" }]

    /* ══════════════════ 被测实例 ══════════════════ */

    /* 基准：容器 800、内容 1400、左钉 1 列（200）、右钉 1 列（200）。
     * 中间区 400，可滚内容 1000，能滚 600。 */
    QSkinTable {
        id: both
        width: 800
        contentWidth: 1400
        fixedColumns: 1
        fixedRightColumns: 1
        columns: root.cols4
        rows: root.rows4
    }

    /* 对照：同一套列与容器，**右边不钉** —— 滚动上限必须一字不差 */
    QSkinTable {
        id: leftOnly
        width: 800
        contentWidth: 1400
        fixedColumns: 1
        columns: root.cols4
        rows: root.rows4
    }

    /* 只钉右：容器 1000、内容 1200、右 1 列（400）。
     * 中间区 600，可滚 800，能滚 200 —— 钉右边也能单独成立。 */
    QSkinTable {
        id: rightOnly
        width: 1000
        contentWidth: 1200
        fixedRightColumns: 1
        columns: root.cols3
        rows: root.rows3
    }

    /* 夹取：3 列，左钉 2 右钉 2 → 右只能钉 1（一列不能同时在两边） */
    QSkinTable {
        id: overlap
        width: 1000
        contentWidth: 1200
        fixedColumns: 2
        fixedRightColumns: 2
        columns: root.cols3
        rows: root.rows3
    }

    /* 夹取上界：fixedRightColumns 给到 99 → 夹到 3，可滚内容归零 */
    QSkinTable {
        id: allRight
        width: 1000
        contentWidth: 1200
        fixedRightColumns: 99
        columns: root.cols3
        rows: root.rows3
    }

    /* 退化一：容器 300 比"左 200 + 右 200"还窄。
     * 左区照样 200，右区只能吃剩下的 100，中间区 0。 */
    QSkinTable {
        id: narrow
        width: 300
        contentWidth: 1400
        fixedColumns: 1
        fixedRightColumns: 1
        columns: root.cols4
        rows: root.rows4
    }

    /* 退化二：左固定列自己（500）就比容器（300）宽 */
    QSkinTable {
        id: pinnedWide
        width: 300
        contentWidth: 1200
        fixedColumns: 1
        columns: [
            { title: "A", dataIndex: "a", width: 500 },
            { title: "B", dataIndex: "b", width: 400 },
            { title: "C", dataIndex: "c", width: 300 }
        ]
        rows: root.rows3
    }

    /* 零回归对照：什么都不钉 */
    QSkinTable {
        id: noFix
        width: 500
        columns: [
            { title: "A", dataIndex: "a" },
            { title: "B", dataIndex: "b" },
            { title: "C", dataIndex: "c" }
        ]
        rows: root.rows3
    }

    /* 正交：checkable + 树形 + 左右固定三件事同时开 */
    QSkinTable {
        id: ortho
        width: 900
        contentWidth: 1500
        checkable: true
        treeMode: true
        treeKey: "id"
        fixedColumns: 1
        fixedRightColumns: 1
        columns: [
            { title: "名称", dataIndex: "name", width: 200 },
            { title: "摘要", dataIndex: "note", width: 500 },
            { title: "正文", dataIndex: "body", width: 400 },
            { title: "状态", dataIndex: "stat", width: 400 }
        ]
        rows: [
            {
                id: "src", name: "src", note: "…", body: "…", stat: "已同步",
                children: [
                    { id: "c1", name: "contracts", note: "…", body: "…", stat: "x", children: [] },
                    { id: "c2", name: "themes",    note: "…", body: "…", stat: "y", children: [] }
                ]
            }
        ]
    }

    /* ══════════════════ 几何：走到组件内部去量 ══════════════════
     * 上面那些断言读的都是派生属性。区域到底有没有真的摆出来、摆在哪，
     * 读属性读不到 —— 得遍历一遍真实的对象树。 */

    /** 收集全部后代（QQuickItem）。QtObject 之类没有 children，跳过 */
    function walk(item, out) {
        var kids = item.children
        if (kids === undefined || kids === null || kids.length === undefined)
            return out
        for (var i = 0; i < kids.length; ++i) {
            out.push(kids[i])
            root.walk(kids[i], out)
        }
        return out
    }

    /** 是否存在一个**真正显示出来**的"区域"：clip 且 visible 的 Item，
     * 位置与宽度正好是这两个数。
     *
     * `visible` 这一条不能省：`fixedRightColumns: 0` 时那个右区 Item 依然
     * 在树上（x = width、宽 0），只是 `visible: false`。宽度 0 的 Item 不吃
     * 事件、也画不出东西，但它**在**树里 —— "两个固定区都没开则整个区
     * 不出现"这句承诺指的是视觉不出现，所以判据得带上 visible。 */
    function hasRegion(list, x, w) {
        for (var i = 0; i < list.length; ++i) {
            var c = list[i]
            if (c.clip === true
                && c.visible === true
                && Math.abs(c.x - x) < 0.5
                && Math.abs(c.width - w) < 0.5)
                return true
        }
        return false
    }

    /** 是否存在一个"宿主"：不 clip，x 与宽正好是这两个数。
     * 宿主是区域里那层承载整块内容的 Item，它的 x 就是分区位移本身。 */
    function hasHost(list, x, w) {
        for (var i = 0; i < list.length; ++i) {
            var c = list[i]
            if (c.clip !== true
                && Math.abs(c.x - x) < 0.5
                && Math.abs(c.width - w) < 0.5)
                return true
        }
        return false
    }

    Timer {
        interval: 400
        running: true
        repeat: false
        onTriggered: root.check()
    }

    function check() {
        /* ══════════════════ [0] 三区划分恒等式 ══════════════════ */

        /* 三个区加起来必须**恰好**是容器宽：少了会有缝（内容被切掉
         * 一段什么也没画），多了会重叠（同一段内容被画两遍、且后画的
         * 那个区会吃掉另一个区的点击）。所以除了求和，还要每个都非负。 */
        var ok0 = true
        var tabs = [both, leftOnly, rightOnly, overlap, allRight, narrow, pinnedWide, noFix, ortho]
        for (var i = 0; i < tabs.length; ++i) {
            var t = tabs[i]
            if (t._leftWidth + t._middleWidth + t._rightWidth !== t.width) ok0 = false
            if (t._leftWidth < 0 || t._middleWidth < 0 || t._rightWidth < 0) ok0 = false
            /* 右区不许越过左区的右沿 —— 这是"不重叠"的另一种写法，
             * 比上面的求和更直接地表达"两个固定区在窄容器里不许撞上" */
            if (t.width - t._rightWidth < t._leftWidth) ok0 = false
        }

        /* 基准表的绝对值，防止"恒等式恒成立但全是 0"这种假绿 */
        ok0 = ok0 && both._leftWidth === 200
                  && both._middleWidth === 400
                  && both._rightWidth === 200

        root.bit(0, ok0)

        /* ══════════════════ [1] 右固定列的宽度与夹取 ══════════════════ */

        /* 右固定宽 = 最右 N 列的宽之和（内容坐标） */
        var ok1 = both._rightCount === 1
                  && both._rightTotal === 200          /* 末列 200 */
                  && rightOnly._rightTotal === 400     /* 末列 400 */
                  && rightOnly._fixedWidth === 0

        /* 夹取：左 2 + 右 2 在 3 列上 → 右只能 1。
         * 不夹的话末列会同时落在两个区里被画两次。 */
        ok1 = ok1 && overlap._fixedCount === 2
                  && overlap._rightCount === 1
                  && overlap._fixedCount + overlap._rightCount <= overlap.columnCount

        /* 上界：99 → 3 列全钉到右边 */
        ok1 = ok1 && allRight._rightCount === 3
                  && allRight._rightTotal === 1200
                  && allRight._scrollableContentWidth === 0

        /* 两边都不钉 → 严格为 0，两个固定区整个不出现 */
        ok1 = ok1 && noFix._rightCount === 0
                  && noFix._rightTotal === 0
                  && noFix._fixedWidth === 0

        root.bit(1, ok1)

        /* ══════════════════ [2] ★ 钉住不改变滚动范围 ══════════════════ */

        /* 同一套列、同一个容器，只把"右钉 1 列"打开：
         * 可滚内容少了 200（少掉被钉住的那列），中间区也多出 200 ——
         * 两个变化正好抵消，能滚多远一点没变，都等于 内容 - 容器 =
         * 1400 - 800 = 600。这是三区结构最重要的一条性质。 */
        var ok2 = leftOnly._scrollableContentWidth === 1200
                  && leftOnly._middleWidth === 600
                  && both._scrollableContentWidth === 1000
                  && both._middleWidth === 400
                  && leftOnly._maxScrollX === both._maxScrollX
                  && both._maxScrollX === 600

        /* 只钉右也是同一条：1200 - 1000 = 200 */
        ok2 = ok2 && rightOnly._maxScrollX === 200
                  && rightOnly._canScrollX === true

        /* 滚到底之后，中间区右沿的内容坐标正好是右固定区的左沿。
         * 换成可读的等式：中间区可见的内容起点（左固定宽）+ 中间区宽 +
         * 能滚的距离 === 内容总宽 - 右固定宽。 */
        ok2 = ok2 && both._leftWidth + both._middleWidth + both._maxScrollX
                     === both._contentTotal - both._rightTotal

        root.bit(2, ok2)

        /* ══════════════════ [3] 可滚内容宽 ══════════════════ */

        /* 三项相减是**真减法**（三区不重叠）。overlap 那张表左 800 右只
         * 夹到 1 列 400，可滚内容 1200 - 800 - 400 = 0 —— 如果 `_rightCount`
         * 没夹，这里会减掉 800，算出 -400 再被 max(0,…) 抹成 0 ——
         * 同样得 0，所以上面 [1] 必须单独断言 `_rightCount`，不能只靠这里。 */
        var ok3 = both._scrollableContentWidth
                  === both._contentTotal - both._fixedWidth - both._rightTotal
                  && both._scrollableContentWidth === 1000
                  && overlap._scrollableContentWidth === 0
                  && allRight._scrollableContentWidth === 0

        /* `_maxScrollX` 是"可滚内容 - 中间区视口"，不是"内容 - 容器"
         * 直接写死 —— 两者在正常配置下相等，但中间区被挤成 0 时
         * 前者才是对的（见 [4]）。 */
        ok3 = ok3 && rightOnly._scrollableContentWidth === 800
                  && rightOnly._middleWidth === 600
                  && rightOnly._maxScrollX
                     === rightOnly._scrollableContentWidth - rightOnly._middleWidth

        root.bit(3, ok3)

        /* ══════════════════ [4] 钉住列撑满容器时的退化 ══════════════════ */

        /* narrow：容器 300，左想占 200、右想占 200。
         * 分配是**左优先**（左边还扛着"全选"那个入口），右区只能吃
         * 剩下的 100，中间区被挤成 0。关键是右区宽度必须是 100 而不是
         * 200 —— 是 200 的话它会从 x=100 开始，横着压在左区上面。 */
        var ok4 = narrow._leftWidth === 200
                  && narrow._rightWidth === 100
                  && narrow._middleWidth === 0
                  && narrow.width - narrow._rightWidth === narrow._leftWidth

        /* 中间区没有视口 → 谈不上能滚多远。这一条是 `_maxScrollX` 里
         * `_middleWidth <= 0` 那个分支存在的全部理由：不写它，这里会
         * 报出一个"能滚 1100"的上限，而屏幕上根本没有一寸地方可滚。 */
        ok4 = ok4 && narrow._maxScrollX === 0
                  && narrow._canScrollX === false

        /* pinnedWide：左固定列自己（500）就比容器（300）宽 →
         * 左区被裁到容器宽，中间区与右区都归零，不是让左区溢出到容器外 */
        ok4 = ok4 && pinnedWide._fixedWidth === 500
                  && pinnedWide._leftWidth === 300
                  && pinnedWide._middleWidth === 0
                  && pinnedWide._rightWidth === 0
                  && pinnedWide._maxScrollX === 0

        root.bit(4, ok4)

        /* ══════════════════ [5] 几何：区域真的摆出来了 ══════════════════ */

        /* 上面全是派生属性 —— 属性对而绑定写错（x 写成 `_fixedWidth`、
         * 宽度忘了换）一样能全绿。这里遍历真实对象树，量三个区的位置。 */
        var regs = root.walk(both, [])

        var ok5 = root.hasRegion(regs, 0, 200)                 /* 左区贴左沿 */
                  && root.hasRegion(regs, 200, 400)            /* 中间区接在左区右边 */
                  && root.hasRegion(regs, 600, 200)            /* 右区：800 - 200 = 600 */

        /* 右区的宿主：x = 右区宽 - 内容总宽 = 200 - 1400 = -1200，
         * 宽 = 内容总宽。这条 x 就是"内容右端贴容器右沿"的代数形式 ——
         * 写反成 `_leftWidth - ...` 或者漏掉符号，区域照样有、位置全错，
         * 只有这一个数能抓住。 */
        ok5 = ok5 && root.hasHost(regs, both._rightWidth - both._contentTotal,
                                  both._contentTotal)
                  && root.hasHost(regs, 200 - 1400, 1400)      /* 同上，写死一遍 */

        /* 左区的宿主必须还在 x = 0 且宽 = 左区宽（M13 那条不许被改坏） */
        ok5 = ok5 && root.hasHost(regs, 0, both._leftWidth)

        root.bit(5, ok5)

        /* ══════════════════ [6] 与勾选 / 树形正交 ══════════════════ */

        /* checkable + 树形 + 左右固定同时开：
         * 左固定区里多了 checkbox 列，它必须算进左区宽（不然首列会被
         * checkbox 压掉一截）；右固定宽仍是末列；三条不变式都不受影响。 */
        var ok6 = ortho._fixedWidth === ortho.checkColumnWidth + 200
                  && ortho._rightCount === 1
                  && ortho._rightTotal === 400
                  && ortho._contentTotal === ortho.checkColumnWidth + 1500

        ok6 = ok6 && ortho._leftWidth + ortho._middleWidth + ortho._rightWidth === ortho.width

        /* 树形本身没被碰坏：默认收起 → 只有根那一条可见。
         * `_visibleRows` 是 { rows, meta, total } 而**不是**数组 —— 行数和
         * 总数是两个字段（分页要按未切片的 `total` 算页数）。 */
        ok6 = ok6 && ortho._visibleRows.total === 1
                  && ortho._visibleRows.rows.length === 1
                  && ortho.rowMeta.length === 1
                  && ortho.rowMeta[0].hasChildren === true
                  && ortho.rowMeta[0].expanded === false

        root.bit(6, ok6)

        /* ══════════════════ [7] 零回归：不钉右边 === M13 ══════════════════ */

        /* fixedRightColumns 默认 0 时，右区必须彻底消失（不是宽 0 还占着
         * 一个 Item 挡点击），中间区回到"容器 - 左固定"，与 M13 完全一致。 */
        var ok7 = leftOnly._rightWidth === 0
                  && leftOnly._rightTotal === 0
                  && leftOnly._middleWidth === leftOnly.width - leftOnly._fixedWidth
                  && leftOnly._leftWidth === leftOnly._fixedWidth

        ok7 = ok7 && noFix._middleWidth === noFix.width
                  && noFix._leftWidth === 0
                  && noFix._maxScrollX === 0
                  && noFix._canScrollX === false

        /* 不钉右边时右区那块 Item 仍然在树上（x = width、宽 0），但必须
         * **不显示**。留着它显示出来会是一条 0 宽的裁剪窗口 —— 画不出
         * 东西，却会在最右沿吃掉一小条鼠标事件。 */
        var regsL = root.walk(leftOnly, [])
        ok7 = ok7 && !root.hasRegion(regsL, leftOnly.width, 0)

        root.bit(7, ok7)

        Qt.exit(Math.min(255, root.failures))
    }
}
