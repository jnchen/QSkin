import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

/* ════════════════════════════════════════════════════════════════════════
 * M11 · 浮层选择类 —— 日期 / 时间选择器的数值与状态契约
 *
 * 守两件事：
 *
 *   ① 地基层的 DateUtil 算得对 —— 闰年、42 格网格、跨年翻月、
 *      严格解析（拒绝越界输入而不是静默滚动）。
 *   ② 两个控件把算出来的东西正确地接到了 UI 上 —— 显示格式、
 *      范围钳制（赋值与选值两条路径都要钳）、面板尺寸随内容变。
 *
 * ── 为什么只有 8 条断言 ──────────────────────────────────────────────
 * tools/test.sh 的退出码只保留低 8 位（Qt.exit 在 POSIX 下的限制）。
 * 超出的位不但读不到，还会因为 Qt.exit(Math.min(255, failures))
 * 把单个失败放大成"8 条全败"的假象。所以这里把同类断言合并：
 * 一条 bit 里 && 好几个相关事实，失败时按注释里的分组去定位。
 * ════════════════════════════════════════════════════════════════════════ */

Item {
    id: root

    property int failures: 0
    function bit(n, ok) { if (!ok) root.failures |= (1 << n) }

    /* ══════════════════ DateUtil 纯计算 ══════════════════ */

    /* [0] 闰年规则：被 4 整除、但不被 100 整除、除非被 400 整除。
     *     第三个例外最容易漏（2000 是闰年、1900 不是）。 */
    function checkLeap() {
        root.bit(0, DateUtil.daysInMonth(2000, 2) === 29
                   && DateUtil.daysInMonth(1900, 2) === 28
                   && DateUtil.daysInMonth(2024, 2) === 29
                   && DateUtil.daysInMonth(2026, 2) === 28
                   && DateUtil.daysInMonth(2026, 1) === 31
                   && DateUtil.daysInMonth(2026, 4) === 30)
    }

    /* [1] 日历网格：固定 42 格；首尾补格属于相邻月且序号正确。
     *     2026-09-01 是周二 → 前补 2 格；本月 30 天 → 已用 32 格，
     *     后补 10 格到 10 月 10 日。 */
    function checkGrid() {
        var g = DateUtil.monthGrid(2026, 9)
        root.bit(1, g.length === 42
                   && DateUtil.firstWeekday(2026, 9) === 2
                   && g[0].inMonth === false && g[0].month === 8
                   && g[2].inMonth === true && g[2].day === 1
                   && g[41].inMonth === false && g[41].month === 10 && g[41].day === 10)
    }

    /* [2] 跨年翻月 + 日期比较 + 格式化 */
    function checkMonthMath() {
        var nxt = DateUtil.addMonths(2026, 12, 1)
        var prv = DateUtil.addMonths(2026, 1, -1)
        var far = DateUtil.addMonths(2026, 1, -13)
        var d   = DateUtil.make(2026, 9, 9)
        root.bit(2, nxt.year === 2027 && nxt.month === 1
                   && prv.year === 2025 && prv.month === 12
                   && far.year === 2024 && far.month === 12
                   && DateUtil.format(d) === "2026-09-09"
                   && DateUtil.format(d, "YYYY/M/D") === "2026/9/9"
                   && DateUtil.compare(d, DateUtil.make(2026, 9, 10)) < 0)
    }

    /* [3] 严格解析：合法的往返成功，越界的必须拒绝。
     *     这里钉死的是"不许静默滚动" —— make() 会把 2026-02-30
     *     滚成 03-02，但 parse() 不能，否则用户打错一天值就悄悄变了。 */
    function checkParse() {
        var good = DateUtil.parse("2026-09-09")
        root.bit(3, good !== null && good.year === 2026
                   && good.month === 9 && good.day === 9
                   && DateUtil.parse("2026-13-01") === null
                   && DateUtil.parse("2026-02-30") === null
                   && DateUtil.parse("2026-00-10") === null
                   && DateUtil.parse("") === null
                   && DateUtil.parse("随便什么") === null)
    }

    /* [4] 时间：12/24 小时格式化、严格解析、候选项粒度 */
    function checkTimeUtil() {
        var t = DateUtil.makeTime(13, 45, 30)
        var p = DateUtil.parseTime("13:45")
        var am = DateUtil.parseTime("12:00 上午", "hh:mm A")
        var pm = DateUtil.parseTime("12:00 下午", "hh:mm A")
        /* A token 的两个词**由属性给**，不在这里抄第二遍文案 —— 断言的是
         * 「A token 用 amPmLabels 渲染」这个**结构**事实，所以 M33-7 填了
         * 英文翻译之后，下面这几条不必跟着改。 */
        var AM = DateUtil.amPmLabels[0]
        var PM = DateUtil.amPmLabels[1]
        root.bit(4, DateUtil.formatTime(t) === "13:45"
                   && DateUtil.formatTime(t, "HH:mm:ss") === "13:45:30"
                   && DateUtil.formatTime(t, "hh:mm A") === "01:45 " + PM
                   /* 12 小时制的两个边界：0 时 → 12 上午、12 时 → 12 下午。
                    * 实测踩过：链式 replace 会让 15:30 显示成 "03:30 下午"
                    * 前一版把小时算对了但替换顺序咬坏，改成单次扫描。 */
                   && DateUtil.formatTime(DateUtil.makeTime(0, 5), "hh:mm A") === "12:05 " + AM
                   && DateUtil.formatTime(DateUtil.makeTime(12, 0), "hh:mm A") === "12:00 " + PM
                   && DateUtil.formatTime(DateUtil.makeTime(15, 30), "hh:mm A") === "03:30 " + PM
                   /* 默认值契约：这条只在**没加载翻译**的环境里成立（冒烟不带
                    * --translation，见 tools/test.sh）。它与上面几条**不是重复**：
                    * 上面测"用属性渲染"（结构），这条测"属性的默认值是中文"。 */
                   && AM === "上午" && PM === "下午"
                   && p !== null && p.hour === 13 && p.minute === 45
                   && am !== null && am.hour === 0      /* 12 上午 = 0 时 */
                   && pm !== null && pm.hour === 12     /* 12 下午 = 12 时 */
                   && DateUtil.parseTime("24:00") === null
                   /* 防护：12 小时制输入配 24 小时制 pattern → 判失败，
                    * 不许静默按 24 小时读（否则 12:00 上午 会变成 12 时） */
                   && DateUtil.parseTime("12:00 上午") === null
                   && DateUtil.minutesList(15).length === 4
                   && DateUtil.hoursList(6).length === 4)
    }

    /* ══════════════════ 控件接线 ══════════════════ */

    QSkinDatePicker { id: dp1; width: 200 }
    QSkinDatePicker { id: dp2; width: 200
                    value: DateUtil.make(2026, 9, 9)
                    displayFormat: "YYYY/MM/DD" }
    QSkinDatePicker { id: dp3; width: 200
                    minimumDate: DateUtil.make(2026, 9, 10)
                    maximumDate: DateUtil.make(2026, 9, 20) }
    QSkinDatePicker { id: dp4; width: 200
                    minimumDate: DateUtil.make(2026, 9, 10)
                    value: DateUtil.make(2026, 1, 1) }   /* 越界 → 应钳到 09-10 */

    QSkinTimePicker { id: tp1; width: 200 }
    QSkinTimePicker { id: tp2; width: 200
                    value: DateUtil.makeTime(13, 45)
                    displayFormat: "HH:mm" }
    QSkinTimePicker { id: tp3; width: 200
                    value: DateUtil.makeTime(9, 5, 30)
                    showSeconds: true
                    displayFormat: "HH:mm:ss" }
    QSkinTimePicker { id: tp4; width: 200; minuteStep: 15 }
    QSkinTimePicker { id: tp5; width: 200
                    minimumTime: DateUtil.makeTime(9, 0)
                    maximumTime: DateUtil.makeTime(17, 0)
                    value: DateUtil.makeTime(8, 0) }     /* 越界 → 应钳到 09:00 */

    Timer {
        interval: 700
        running: true
        repeat: false
        onTriggered: root.check()
    }

    function check() {
        checkLeap()
        checkGrid()
        checkMonthMath()
        checkParse()
        checkTimeUtil()

        /* [5] DatePicker 接线：显示格式、无值占位、面板对齐今天、
         *     选中判定、范围判定（含边界闭区间）。
         *
         *     末两条是**面板不裁内容**的不变量：标题行 + 星期头 + 6 行格子
         *     必须放得进面板内容区。这条曾漏掉 —— cellSize*0.9 是非整数，
         *     anchors 链式堆叠逐段舍入后把第 6 行挤出了可视区，
         *     而当时的几何断言用的还是那套会漂的浮点公式，所以"通过"了。
         *     现在三个段高都取整，断言直接比"取整后的实际值"。 */
        var today = DateUtil.today()
        root.bit(5, dp1.value === null && dp1.text === ""
                   && dp2.text === "2026/09/09"
                   && dp1.panelYear === today.year && dp1.panelMonth === today.month
                   && dp2._isSelected(2026, 9, 9) === true
                   && dp2._isSelected(2026, 9, 10) === false
                   && dp3._inRange(2026, 9, 15) === true
                   && dp3._inRange(2026, 9, 10) === true    /* 下界闭 */
                   && dp3._inRange(2026, 9, 20) === true    /* 上界闭 */
                   && dp3._inRange(2026, 9, 9) === false
                   && dp3._inRange(2026, 9, 21) === false
                   /* 6 行完整可见 */
                   && dp2.headerHeight + dp2.weekdayHeight + dp2.gridHeight
                      <= dp2.panelHeight - dp2.panelPadding * 2
                   /* 段高必须是整数：非整数会在 anchors 链上累积舍入 */
                   && dp2.headerHeight === Math.round(dp2.headerHeight)
                   && dp2.weekdayHeight === Math.round(dp2.weekdayHeight)
                   && dp2.gridHeight === dp2.cellSize * 6)

        /* [6] DatePicker 钳制：**赋值路径**也要钳（这是实测踩到的 bug ——
         *     最早的实现只在"用户点格子"时钳，直接赋 value 是越界的）。 */
        root.bit(6, dp4.value !== null
                   && DateUtil.compare(dp4.value, DateUtil.make(2026, 9, 10)) === 0)

        /* [7] TimePicker 接线：显示格式、列数决定面板宽度、
         *     档位下标落位、_compose 保留未提供字段。
         *     末两条同 [5]：列高 + 列头 + 按钮行必须放得进内容区。 */
        var w2 = tp1.panelWidth
        var w3 = tp3.panelWidth
        root.bit(7, tp2.text === "13:45" && tp3.text === "09:05:30"
                   && tp1.text === ""
                   && w3 > w2                                    /* 三列比两列宽 */
                   && tp4.minutes.length === 4
                   && tp4._currentIndex(tp4.minutes, 44) === 2    /* 44 分落到 30 */
                   && tp4._currentIndex(tp4.minutes, 59) === 3    /* 59 分落到 45 */
                   && tp2._compose(10, null, null).hour === 10
                   && tp2._compose(10, null, null).minute === 45
                   /* 时间钳制：赋值路径 */
                   && DateUtil.compareTime(tp5.value, DateUtil.makeTime(9, 0)) === 0
                   /* 列区 + 列头 + 按钮行完整装得下 */
                   && tp3.columnHeight + tp3.headerHeight + tp3.footerHeight
                      <= tp3.panelHeight - tp3.panelPadding * 2
                   && tp3.headerHeight === Math.round(tp3.headerHeight)
                   && tp3.footerHeight === Math.round(tp3.footerHeight)
                   /* 脚部必须真的给按钮留出上方呼吸空间：
                    * footerHeight = buttonHeight + footerGap，
                    * 按钮贴底 → 上方空地正好是 footerGap。
                    * 曾经写死 rowHeight*1.6，按钮居中后上下各 4px，
                    * 视觉上"确定"紧贴最后一行数字。 */
                   && tp3.footerHeight === tp3.buttonHeight + tp3.footerGap
                   && tp3.footerGap > 0
                   && tp3.footerGap >= Math.round(tp3.rowHeight * 0.4)
                   /* 秒列的宽度要真参与面板宽度换算 */
                   && w3 - w2 === tp3.columnWidth + tp3.separatorWidth)

        Qt.exit(Math.min(255, root.failures))
    }
}
