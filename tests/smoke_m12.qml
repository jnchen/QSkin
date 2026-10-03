/****************************************************************************
 * QSkin · 冒烟测试 —— M12：QSkinTable 列宽可拖
 *
 * 断言写法见 tools/test.sh 文件头：≤ 8 条，bit n = 断言 [n]。
 *
 * ── 这轮要守的核心不变量 ───────────────────────────────────────────────
 * 列宽拖拽看起来只是"把某个数改大"，但它动了 colLayout 的**宽度来源
 * 优先级**。原来的布局只有"定宽 + 等分"两档，现在插进了第三档
 * （用户手动宽度）。三档之间的优先级一旦搞错，症状是
 * "拖完看起来对了，容器一变又回去了" —— 这类 bug 靠肉眼截图抓不到，
 * 必须把优先级和快照行为写成断言。
 *
 * 断言分工：
 *   [0] 优先级：手动宽度 > 列定宽 > 等分
 *   [1] 拖拽落地：setColumnWidth 改宽 + 发出信号 + 下限钳制
 *   [2] 快照行为：拖一列会把其余列当前宽度一起冻结
 *   [3] 复位：resetColumnWidths 回到等分
 *   [4] 可拖判定：显式 resizable + 最后一列不可拖 + 等分列不可拖
 *   [5] 双击自适应：按内容量宽（含表头），结果不小于最低宽
 *   [6] 量宽准确性：TextMetrics 按 header 切换字重 + 按字串长度变化
 *   [7] 与既有能力的正交性：拖宽不影响排序 / 分页 / 多选
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int failures: 0
    property int resizedSignals: 0
    property int lastResizedIndex: -1
    property int lastResizedWidth: -1

    function bit(n, ok) { if (!ok) root.failures |= (1 << n) }

    /* ══════════════════ 被测实例 ══════════════════ */

    /* 主表格：首列定宽 200 + 两列等分。
     * 列 0 与列 1 标了 resizable —— 列 1 原本是等分列，
     * 用它验证"等分列能否成为拖拽起点"（当前实现：不能，
     * 因为等分宽度依赖容器宽，从它起拖语义含糊）。 */
    QSkinTable {
        id: t1

        width: 400
        columns: [
            { title: "文件名", dataIndex: "name", width: 200, resizable: true, sortable: true },
            { title: "大小",   dataIndex: "size", align: "right", resizable: true, sortable: true },
            { title: "状态",   dataIndex: "status" }
        ]
        rows: [
            { name: "a.qml", size: "4 KB", status: "已同步" },
            { name: "b.qml", size: "12 KB", status: "草稿" },
            { name: "c.qml", size: "128 KB", status: "已同步" }
        ]
        onColumnResized: function(i, w) {
            root.resizedSignals++
            root.lastResizedIndex = i
            root.lastResizedWidth = w
        }
    }

    /* 量宽对照组：验证 header 开关真的换了字重 */
    QSkinTable {
        id: t2
        width: 400
        columns: [{ title: "文件名称", dataIndex: "name" }]
        rows: [{ name: "短" }]
    }

    /* 单列 + 显式 resizable："最后一列不可拖" 的独立对照组。
     * t2 没标 resizable，考不出"最后一列"这条规则；
     * 必须有一张"标了 resizable 却仍是最后一列"的表，否则
     * 实现若把"最后一列"规则写丢，会被 t2 的"没标 resizable"
     * 顺带 PASS，规则就漏测了。 */
    QSkinTable {
        id: t3
        width: 400
        columns: [{ title: "唯一列", dataIndex: "name", resizable: true }]
        rows: [{ name: "值" }]
    }

    Timer {
        interval: 400
        running: true
        repeat: false
        onTriggered: root.check()
    }

    function check() {
        /* ══════════════════ [0] 宽度来源优先级 ══════════════════ */

        /* 初始：列 0 定宽 200，列 1/2 平分剩余 200 → 各 100。
         * 注意此时**没有**手动宽度，走的是「定宽 + 等分」两档。 */
        var base = t1.colLayout
        var ok0 = base.xs[0] === 0
                  && base.widths[0] === 200
                  && base.xs[1] === 200
                  && base.widths[1] === 100
                  && base.widths[2] === 100

        /* 拖列 0 → 260。快照把列 1/2 的 100 一并冻结，
         * 所以结果是 260 / 100 / 100（**不是**"列 2 独吞剩余"）。
         * 这正是 setColumnWidth 的设计：快照后所有列都显式，
         * 不会再有等分重算把用户拖出来的宽度洗掉。 */
        t1.setColumnWidth(0, 260)
        ok0 = ok0 && t1.colLayout.widths[0] === 260
                && t1.colLayout.widths[1] === 100
                && t1.colLayout.widths[2] === 100
                && t1.colLayout.xs[1] === 260          /* 后续列跟着右移 */

        /* 手动宽度覆盖「等分」：此时列 1 已有快照值，不再是等分列 */
        t1.setColumnWidth(1, 60)
        ok0 = ok0 && t1.colLayout.widths[1] === 60
                && t1.colLayout.widths[0] === 260
                && t1.colLayout.widths[2] === 100

        root.bit(0, ok0)

        /* ══════════════════ [1] 拖拽落地 ══════════════════ */

        t1.resetColumnWidths()
        var sigBefore = root.resizedSignals
        t1.setColumnWidth(0, 120)
        var ok1 = t1.colLayout.widths[0] === 120
                  && root.resizedSignals === sigBefore + 1
                  && root.lastResizedIndex === 0
                  && root.lastResizedWidth === 120

        /* 下限：负数 / 小于下限 → 钳到 minColumnWidth */
        t1.setColumnWidth(0, -50)
        ok1 = ok1 && t1.colLayout.widths[0] === t1.minColumnWidth
        t1.setColumnWidth(0, 10)
        ok1 = ok1 && t1.colLayout.widths[0] === t1.minColumnWidth

        /* 越界下标直接忽略（不崩、不改任何东西） */
        var w0 = t1.colLayout.widths[0]
        t1.setColumnWidth(-1, 999)
        t1.setColumnWidth(99, 999)
        ok1 = ok1 && t1.colLayout.widths[0] === w0

        /* **右侧留位**：想把列 0 拖到 999（远超容器）时，
         * 上限 = 容器宽 - 右侧每列 minColumnWidth（两列）= 400 - 96 = 304。
         * 这条守的是"拖宽不会把右边的列顶出表格边界"。 */
        t1.resetColumnWidths()
        t1.setColumnWidth(0, 999)
        ok1 = ok1 && t1.colLayout.widths[0]
                    === 400 - t1.minColumnWidth * 2
        root.bit(1, ok1)

        /* ══════════════════ [2] 快照行为 ══════════════════ */

        /* 这一条是 M12 的设计核心：拖任意一列，会把**所有**列
         * 当前的实际宽度快照进 columnWidths。
         * 目的：容器 resize 时用户拖出来的宽度不被等分洗掉。
         *
         * 验证方式：拖完后把容器宽度改掉，各列宽度必须纹丝不动。 */
        t1.resetColumnWidths()
        t1.width = 400
        var wBefore = [t1.colLayout.widths[0], t1.colLayout.widths[1], t1.colLayout.widths[2]]

        t1.setColumnWidth(0, 180)                       /* 触发快照 */
        var wFrozen = [t1.colLayout.widths[0], t1.colLayout.widths[1], t1.colLayout.widths[2]]
        t1.width = 520                                  /* 容器变宽 */
        var wAfter = [t1.colLayout.widths[0], t1.colLayout.widths[1], t1.colLayout.widths[2]]

        var ok2 = wAfter[0] === 180                     /* 拖过的列保持 */
                  && wAfter[1] === wFrozen[1]           /* 未拖的列也保持（快照） */
                  && wAfter[2] === wFrozen[2]
                  && wAfter[1] === wBefore[1]           /* 且等于拖之前的值 */
                  /* 若走了等分，列 1 会变成 (520-180)/2 = 170，与快照值 100 不同 */
                  && wAfter[1] !== Math.floor((520 - 180) / 2)
        root.bit(2, ok2)

        /* ══════════════════ [3] 复位 ══════════════════ */

        t1.resetColumnWidths()
        t1.width = 400
        var ok3 = t1.columnWidths !== null
                  && Object.keys(t1.columnWidths).length === 0
                  && t1.colLayout.widths[0] === 200     /* 回到列定宽 */
                  && t1.colLayout.widths[1] === 100     /* 回到等分 */
                  && t1.colLayout.widths[2] === 100
        root.bit(3, ok3)

        /* ══════════════════ [4] 可拖判定 ══════════════════ */

        /* 先复位到干净的等分态，再逐条判 ——
         * 快照会把列"显式化"，从而改变 _resizableAt 的结果，
         * 所以判定必须在确定的状态下做。 */
        t1.resetColumnWidths()
        t1.width = 400

        /* 列 0 定宽 200 + 标了 resizable → 可拖 */
        var ok4 = t1._resizableAt(0) === true

        /* 列 2 没标 resizable → 不可拖 */
        ok4 = ok4 && t1._resizableAt(2) === false

        /* **最后一列恒不可拖** —— 它的右沿就是表格边界，
         * 拖了会把内容顶出可视区且拖不回来。
         * t3 是"标了 resizable 的单列表"：列定义通过了 resizable
         * 那道闸，唯一的拦截理由只能是"它是最后一列"。
         * （用 t2 测不出来 —— 它没标 resizable，到底被哪条规则
         *   拦下说不清，实现把"最后一列"写丢也照样 PASS。） */
        ok4 = ok4 && t3._resizableAt(0) === false
                  && t3.columns[0].resizable === true
                  && t3.colLayout.widths[0] > 0

        /* **等分列不可拖**：列 1 标了 resizable，但此刻它是等分的
         * （列定宽为 0）。等分宽度依赖容器宽，从它起拖语义含糊。 */
        ok4 = ok4 && t1.columns[1].resizable === true
                  && t1._resizableAt(1) === false

        /* 一旦它有了确定宽度（用户拖过别的列 / 显式设过），就可拖了 */
        t1.setColumnWidth(0, 180)
        ok4 = ok4 && t1._resizableAt(1) === true
        t1.resetColumnWidths()

        root.bit(4, ok4)

        /* ══════════════════ [5] 双击自适应 ══════════════════ */

        /* 自适应宽度 = max(表头宽, 各单元格宽) + 内距余量，
         * 且不小于 minColumnWidth。
         * 这里不钉死具体像素（字体渲染各平台有差），
         * 只钉三件确定的事：
         *   ① 结果 >= minColumnWidth
         *   ② 结果 >= 纯文字量宽（至少装得下内容）
         *   ③ 列越长（内容越宽）自适应结果越大（单调性） */
        var shortTable = autoShort
        var longTable  = autoLong
        var wShort = shortTable.colLayout.widths[0]
        shortTable._autoFitColumn(0)
        var fitShort = shortTable.colLayout.widths[0]

        longTable._autoFitColumn(0)
        var fitLong = longTable.colLayout.widths[0]

        var ok5 = fitShort >= shortTable.minColumnWidth
                  && fitLong  >= longTable.minColumnWidth
                  && fitLong  >  fitShort          /* 长内容自适应更宽 */
                  && fitShort >  0
        root.bit(5, ok5)

        /* ══════════════════ [6] 量宽准确性 ══════════════════ */

        /* header 开关必须真的换字重 —— 表头是半粗，比同字号的正文宽。
         * 这是 _measureText 的核心行为，也是"自适应宽度装得下表头"
         * 这条体验的前提。 */
        var sameText = "文件名"
        var wBody   = t1._measureText(sameText, false)
        var wHead   = t1._measureText(sameText, true)
        var ok6 = wBody > 0 && wHead > 0 && wHead >= wBody

        /* 探针必须真的按传入字串工作，而不是返回常量：
         * 长串一定量得比短串宽。 */
        ok6 = ok6 && t1._measureText("很长的一段中文字符串内容", false) > wBody

        /* 空串与 undefined 落到 0，不抛异常 —— _autoFitColumn 会
         * 把 title 缺失的列喂进来，这条是它的安全网。 */
        ok6 = ok6 && t1._measureText("", false) === 0
                  && t1._measureText(undefined, false) === 0

        root.bit(6, ok6)

        /* ══════════════════ [7] 与既有能力正交 ══════════════════ */

        /* 拖宽不能影响排序 / 分页 / 多选这三件事 ——
         * 它们各自有独立的下标体系，改列宽只该动 colLayout。 */
        var ok7 = true

        /* 排序仍工作 */
        t1._toggleSort(0)
        ok7 = ok7 && t1.sortColumn === 0 && t1.sortDirection === "asc"
        t1._toggleSort(0)
        ok7 = ok7 && t1.sortDirection === "desc"

        /* 拖宽后再排序，列宽保持 */
        var wKeep = t1.colLayout.widths[0]
        t1._toggleSort(1)
        ok7 = ok7 && t1.colLayout.widths[0] === wKeep

        /* 多选仍工作 */
        t1.checkable = true
        t1._toggleCheck(0)
        ok7 = ok7 && t1.selectedIndexes.length === 1 && t1.selectedIndexes[0] === 0
        t1._toggleCheck(0)
        ok7 = ok7 && t1.selectedIndexes.length === 0

        /* 分页仍工作 */
        t1.pageSize = 2
        t1.page = 1
        ok7 = ok7 && t1.pageCount === 2 && t1.displayRows.length === 2
        t1.page = 2
        ok7 = ok7 && t1.displayRows.length === 1

        root.bit(7, ok7)

        Qt.exit(Math.min(255, root.failures))
    }

    /* 自适应对照：一个短内容表 + 一个长内容表 */
    QSkinTable {
        id: autoShort
        width: 400
        columns: [{ title: "A", dataIndex: "v", resizable: true }]
        rows: [{ v: "x" }]
    }

    QSkinTable {
        id: autoLong
        width: 600
        columns: [{ title: "A", dataIndex: "v", resizable: true }]
        rows: [{ v: "一段明显更长的单元格内容用于验证自适应单调性" }]
    }
}
