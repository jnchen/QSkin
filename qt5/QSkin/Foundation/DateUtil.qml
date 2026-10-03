/****************************************************************************
 * QSkin · Quick Design System — Foundation / DateUtil
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 日期 / 时间的**纯计算**工具。放在地基层而不是契约层，理由和 Theme 一样：
 * 它不含任何**视觉**决策 —— 没有颜色、没有字号、没有"星期头占多高"。
 * 契约层的 QSkinDatePicker 调它算格子，主题决定格子长什么样。
 *
 * ⚠ 有一处**文案**决策确实留在这里：星期名 / 月名 / 上下午标记（下面三个
 * `*Labels` 属性）。那不是越界 —— 它们与"星期几""几月"这类**日期语义**
 * 绑死，拆到契约层只会让每个调用方各抄一份；本地化走 `qsTr`。
 * （原文写的是「没有『星期几该显示成 周一 还是 Mon』」—— 本件落地后那句
 * 不再成立，所以改掉，不留着。）
 *
 * ── 为什么不用 JS 的 Date 直接算 ──────────────────────────────────────
 * 可以用，而且下面确实用了。但有两个坑让它不能裸用：
 *
 *   1. Date 的月份从 0 开始（0 = 一月），而所有 UI 标注、
 *      所有设计稿、所有用户心智都是 1~12。让每个调用方自己 ±1，
 *      早晚会有一处漏掉。这里统一对外用 1~12。
 *
 *   2. "这个月有多少天"最容易写错。闰年的判定规则是
 *      「能被 4 整除，但不能被 100 整除，除非能被 400 整除」——
 *      第三个例外条件（2000 是闰年、1900 不是）最常被漏。
 *      这里用 new Date(y, m, 0).getDate() 让引擎判，比手写可靠。
 *
 * ── 日期一律用「对象」而不是字符串表示 ────────────────────────────────
 * 内部表示是 { year, month, day }，month 为 1~12。
 * 字符串（"2026-09-09"）只在进出控件边界时出现，用 format / parse 转换。
 * 这样中间所有计算都不必反复解析、也不受本地时区影响。
 ****************************************************************************/

pragma Singleton
import QtQuick 2.15

QtObject {
    id: root

    /* ══════════════════ 常量 ══════════════════ */

    /** 星期标题（周日在前，与 new Date().getDay() 的 0=周日 对齐）。
     *
     * ── 为什么是「每条一个 qsTr」而不是「一条模板 + %1」──────────────
     * 中文是**单字**（日/一/二…），英文是 `Sun` / `Mon` 这种三字母缩写 ——
     * 两边**不是同一个模板的两个实例**：没有哪个 `%1` 能同时产出「日」和 `Sun`。
     * 所以只能让译者逐条给词。
     *
     * 第二参（消歧说明）在这里**必需** —— 单字「日」离开上下文可以被译成
     * 太阳 / 日本 / 天，而译者在 `.ts` 里只看得见这一个字。
     *
     * ⚠ 每个 `qsTr(…)` 都必须在**本行内闭合**：门禁判「这行走没走 qsTr」只看
     * 本行（`tools/check-i18n.py` 的已知近似）。折行会让下半截被判成
     * 「未登记的新增文案」，而豁免表只减不增。 */
    readonly property var weekdayLabels: [
        qsTr("日", "weekday abbreviation, Sunday"),    qsTr("一", "weekday abbreviation, Monday"),
        qsTr("二", "weekday abbreviation, Tuesday"),   qsTr("三", "weekday abbreviation, Wednesday"),
        qsTr("四", "weekday abbreviation, Thursday"),  qsTr("五", "weekday abbreviation, Friday"),
        qsTr("六", "weekday abbreviation, Saturday")
    ]

    /** 月份标题用的数字，避免调用方各自拼字符串。
     *  与 `weekdayLabels` 同理：中文「1月」对英文 `Jan`，**不是同一个模板**，
     *  所以也逐条给词、也带消歧说明（「1月」单独看会像"一个月"的量词）。 */
    readonly property var monthLabels: [
        qsTr("1月", "month name, January"),     qsTr("2月", "month name, February"),
        qsTr("3月", "month name, March"),       qsTr("4月", "month name, April"),
        qsTr("5月", "month name, May"),         qsTr("6月", "month name, June"),
        qsTr("7月", "month name, July"),        qsTr("8月", "month name, August"),
        qsTr("9月", "month name, September"),   qsTr("10月", "month name, October"),
        qsTr("11月", "month name, November"),   qsTr("12月", "month name, December")
    ]

    /** `A` token 的渲染 —— 12 小时制的上/下午标记；下标 0 = 上午、1 = 下午。
     *
     * ── 为什么提成属性、又为什么是 `readonly` ──────────────────────
     * 它是 `formatTime(t, "…A")` 里唯一的文案来源。留在函数体里，宿主就只能
     * 连算法一起改；提出来之后「上午/下午怎么写」与「时间怎么算」分开 ——
     * 与 `QSkinStatistic` 把格式化抽成 `formatValue()` 是同一个手法。
     *
     * 但它和上两个一样是 `readonly`：本文件的本地化一律走 `qsTr` + `.qm`
     * （Qt 的正途）。做成可写会变成**单例上的全局可变状态** —— 一个页面改了
     * AM/PM，所有页面的时间选择器跟着变，那是陷阱不是灵活性。
     *
     * ── 覆盖它之前的边界：往返闭合 ────────────────────────────────
     * `parseTime()` 的接受集是**固定的** `上午|下午|AM|PM`（解析用字符表，
     * 属 D 类、不 i18n），所以此刻是**接受集 ⊇ 输出集**：
     *   · 默认值、或 `["AM", "PM"]` → format → parse **往返闭合**；
     *   · 换成接受集之外的词 → 往返会断。
     * 这是**已知边界**而非缺陷：`parseTime` 刻意不收窄（历史数据、外部输入
     * 要宽容），代价落在「改这个属性的人要挑接受集里的词」。 */
    readonly property var amPmLabels: [qsTr("上午"), qsTr("下午")]

    /* ══════════════════ 构造 / 归一化 ══════════════════ */

    /**
     * make(y, m, d) → {year, month, day}
     * m 是 1~12。溢出/下溢的日期会被规范化到正确的月（如 make(2026, 2, 30)
     * → 2026-03-02），这是 JS Date 的既有行为，也正是我们要的。
     *
     * 注意这里是**有意的滚动**：算日历网格、给日期加减时，"第 30 天"这种
     * 越界输入滚动到下个月才是对的。但**解析用户输入**必须反过来 ——
     * 打错一天不该悄悄变成另一天，所以 parse() 自己先校验、不走 make()。
     */
    function make(y, m, d) {
        var dt = new Date(y, m - 1, d)
        return { year: dt.getFullYear(), month: dt.getMonth() + 1, day: dt.getDate() }
    }

    /** 今天（去掉时间部分） */
    function today() {
        var dt = new Date()
        return { year: dt.getFullYear(), month: dt.getMonth() + 1, day: dt.getDate() }
    }

    /** 是否是一个合法日期对象（含基本的范围检查） */
    function isValid(d) {
        return d !== null && d !== undefined
            && typeof d.year === "number" && typeof d.month === "number"
            && typeof d.day === "number"
            && d.month >= 1 && d.month <= 12
            && d.day >= 1 && d.day <= root.daysInMonth(d.year, d.month)
    }

    /* ══════════════════ 日历计算 ══════════════════ */

    /** 某年某月有多少天。month 为 1~12。 */
    function daysInMonth(year, month) {
        /* new Date(y, m, 0) 是"下个月的第 0 天"，即本月最后一天。
         * 闰年、大小月的全部规则由引擎处理，不手写。 */
        return new Date(year, month, 0).getDate()
    }

    /** 某年某月 1 号是星期几（0=周日 … 6=周六） */
    function firstWeekday(year, month) {
        return new Date(year, month - 1, 1).getDay()
    }

    /**
     * monthGrid(year, month) → [ {year, month, day, inMonth, isToday}, ... ]
     *
     * 返回**等长 6 行 × 7 列 = 42 格**的日历网格。固定 42 格是个刻意的
     * 选择：不同月份有的占 4 行、有的占 6 行，网格高度会跳变，
     * 翻月时面板跟着抽动。固定 42 格让面板高度恒定 —— 这也是
     * 主流 Web 日期选择器的做法。
     *
     * 前后补的格子来自相邻月份（inMonth: false），灰显但可点。
     */
    function monthGrid(year, month) {
        var out = []
        var lead = root.firstWeekday(year, month)      // 本月 1 号之前要补几格
        var dim  = root.daysInMonth(year, month)
        var t    = root.today()

        /* 上一个月的尾巴 */
        var prevMonth = month - 1
        var prevYear  = year
        if (prevMonth < 1) { prevMonth = 12; prevYear -= 1 }
        var dimPrev = root.daysInMonth(prevYear, prevMonth)
        for (var i = lead - 1; i >= 0; --i) {
            var pd = dimPrev - i
            out.push({ year: prevYear, month: prevMonth, day: pd, inMonth: false,
                       isToday: root.sameDay(prevYear, prevMonth, pd, t) })
        }

        /* 本月 */
        for (var d = 1; d <= dim; ++d) {
            out.push({ year: year, month: month, day: d, inMonth: true,
                       isToday: root.sameDay(year, month, d, t) })
        }

        /* 下一个月的头 —— 补满 42 格 */
        var nextMonth = month + 1
        var nextYear  = year
        if (nextMonth > 12) { nextMonth = 1; nextYear += 1 }
        var nd = 1
        while (out.length < 42) {
            out.push({ year: nextYear, month: nextMonth, day: nd, inMonth: false,
                       isToday: root.sameDay(nextYear, nextMonth, nd, t) })
            nd += 1
        }
        return out
    }

    /** 递减/递增月份，自动跨年。delta 可以是负数。 */
    function addMonths(year, month, delta) {
        /* 转成"从 0 起的绝对月序"再算，避免手写进位 */
        var abs = year * 12 + (month - 1) + delta
        return { year: Math.floor(abs / 12), month: (abs % 12) + 1 }
    }

    /** 比较两个日期对象：<0 早于，0 相等，>0 晚于 */
    function compare(a, b) {
        if (!a) return b ? -1 : 0
        if (!b) return 1
        if (a.year  !== b.year)  return a.year  - b.year
        if (a.month !== b.month) return a.month - b.month
        return a.day - b.day
    }

    /** 是否同一天。第四参是可选的目标日期对象，默认今天。 */
    function sameDay(y, m, d, target) {
        var t = target !== undefined && target !== null ? target : root.today()
        return t.year === y && t.month === m && t.day === d
    }

    /**
     * clamp(d, min, max) → 落在 [min, max] 内的日期
     * min / max 可以为 null（表示该侧不限制）。
     */
    function clamp(d, min, max) {
        if (!d) return d
        if (min && root.compare(d, min) < 0) return min
        if (max && root.compare(d, max) > 0) return max
        return d
    }

    /* ══════════════════ 格式化 / 解析 ══════════════════ */

    /** 两位补零 */
    function pad2(n) {
        return n < 10 ? "0" + n : "" + n
    }

    /**
     * format(d, pattern) → string
     * pattern 支持：YYYY 四位年、MM 两位月、DD 两位日、
     *               M 不补零月、D 不补零日。
     * 默认 "YYYY-MM-DD"。
     *
     * 与 formatTime 一样用单次扫描（长 token 优先）。
     * 链式 replace 的坑见 formatTime 的注释。
     */
    function format(d, pattern) {
        if (!d) return ""
        var p = pattern !== undefined && pattern !== null && pattern !== "" ? pattern : "YYYY-MM-DD"
        var out = ""
        var i = 0
        while (i < p.length) {
            var four = p.substr(i, 4)
            var two  = p.substr(i, 2)
            var one  = p.charAt(i)
            if (four === "YYYY")   { out += "" + d.year;          i += 4 }
            else if (two === "MM") { out += root.pad2(d.month);   i += 2 }
            else if (two === "DD") { out += root.pad2(d.day);     i += 2 }
            else if (one === "M")  { out += d.month;              i += 1 }
            else if (one === "D")  { out += d.day;                i += 1 }
            else                   { out += one;                  i += 1 }
        }
        return out
    }

    /**
     * parse(str, pattern) → 日期对象或 null
     * 只保证能吃下本文件 format() 产出的格式，不做宽松解析 ——
     * 宽松解析（"2026/9/9"、"20260909" 都要认）会让错误输入静默通过，
     * 那比解析失败更难查。控件里只对用户键入做严格解析，失败即保持原值。
     *
     * 关键：**先校验再归一化**。
     * make() 用的是 JS Date，它会把溢出日期静默滚动
     * （2026-02-30 → 2026-03-02）。这在做网格补格时是想要的行为，
     * 但用在解析用户输入上就是灾难：用户打错一天，值悄悄变成另一天，
     * 没有任何反馈。所以这里先按原始字段做范围检查，越界直接判失败。
     */
    function parse(str, pattern) {
        if (!str) return null
        var p = pattern !== undefined && pattern !== null && pattern !== "" ? pattern : "YYYY-MM-DD"

        /* 把 pattern 翻译成正则：先把元字符抠出来，
         * 用分组捕获，再按捕获顺序回填。 */
        var map = []
        var re = p.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
                  .replace("YYYY", function() { map.push("y"); return "(-?\\d{1,4})" })
                  .replace("MM",   function() { map.push("m"); return "(\\d{1,2})" })
                  .replace("DD",   function() { map.push("d"); return "(\\d{1,2})" })
                  .replace("M",    function() { map.push("m"); return "(\\d{1,2})" })
                  .replace("D",    function() { map.push("d"); return "(\\d{1,2})" })

        var m = new RegExp("^" + re + "$").exec(String(str).trim())
        if (!m) return null

        var y = null, mo = null, da = null
        for (var i = 0; i < map.length; ++i) {
            var v = parseInt(m[i + 1], 10)
            if (map[i] === "y") y = v
            else if (map[i] === "m") mo = v
            else da = v
        }
        /* 缺项用 1 月 1 日兜底，这样 "YYYY-MM" 也能解析成一个可用日期 */
        var yy = y === null ? 1970 : y
        var mm = mo === null ? 1 : mo
        var dd = da === null ? 1 : da

        /* 校验（在归一化之前）：月 1~12、日 1~当月天数 */
        if (mm < 1 || mm > 12) return null
        if (dd < 1 || dd > root.daysInMonth(yy, mm)) return null

        return { year: yy, month: mm, day: dd }
    }

    /* ══════════════════ 时间 ══════════════════ */

    /**
     * makeTime(h, m, s) → {hour, minute, second}
     * 各字段会按 24 小时制循环归一（25 时 → 次日 1 时，但这里只保留
     * 时分秒三个值，不引入日期进位 —— 选择器是"选一个钟点"，
     * 不是"选一个时刻"，跨日语义由业务的日期字段承担）。
     */
    function makeTime(h, m, s) {
        return {
            hour:   ((h % 24) + 24) % 24,
            minute: ((m % 60) + 60) % 60,
            second: ((s === undefined || s === null ? 0 : s) % 60 + 60) % 60
        }
    }

    /** 当前时间（去掉日期） */
    function now() {
        var dt = new Date()
        return { hour: dt.getHours(), minute: dt.getMinutes(), second: dt.getSeconds() }
    }

    /** 时间比较：<0 早于，0 相等，>0 晚于 */
    function compareTime(a, b) {
        if (!a) return b ? -1 : 0
        if (!b) return 1
        if (a.hour   !== b.hour)   return a.hour   - b.hour
        if (a.minute !== b.minute) return a.minute - b.minute
        return a.second - b.second
    }

    /** 时间钳制到 [min, max]。min / max 可为 null。 */
    function clampTime(t, min, max) {
        if (!t) return t
        if (min && root.compareTime(t, min) < 0) return min
        if (max && root.compareTime(t, max) > 0) return max
        return t
    }

    /**
     * formatTime(t, pattern) → string
     * pattern 支持：HH 两位时(24)、H 不补零时、hh 两位时(12)、
     *               mm 两位分、m 不补零分、ss 两位秒、A 上/下午（见 amPmLabels）。
     * 默认 "HH:mm"。
     */
    function formatTime(t, pattern) {
        if (!t) return ""
        var p = pattern !== undefined && pattern !== null && pattern !== "" ? pattern : "HH:mm"
        var is12 = p.indexOf("hh") >= 0 || p.indexOf("A") >= 0
        var h12 = t.hour % 12
        if (h12 === 0) h12 = 12

        /* 用**单次扫描**替换，而不是链式 .replace()。
         *
         * 链式写法的坑：先 replace("HH") 会把 "HH" 换成 "15"，
         * 这时字符串里已经没有 "HH" 了；但如果 pattern 是 "hh"，
         * 后面的 replace("H") 又会把已替换出来的数字再咬一口 ——
         * 更隐蔽的是 "HH" 与 "hh" 大小写不同却被前面的分支提前消费。
         * 一轮扫描、一次成形，避免这类"替换顺序决定结果"的脆弱。
         *
         * 从长到短匹配（YYYY 型），因为长 token 含短 token
         * （"HH" 含 "H"、"mm" 含 "m"），必须长优先。 */
        var out = ""
        var i = 0
        while (i < p.length) {
            var two = p.substr(i, 2)
            var one = p.charAt(i)
            if (two === "HH")      { out += root.pad2(t.hour);    i += 2 }
            else if (two === "hh") { out += root.pad2(is12 ? h12 : t.hour); i += 2 }
            else if (two === "mm") { out += root.pad2(t.minute);  i += 2 }
            else if (two === "ss") { out += root.pad2(t.second);  i += 2 }
            else if (one === "H")  { out += t.hour;               i += 1 }
            else if (one === "m")  { out += t.minute;             i += 1 }
            else if (one === "s")  { out += t.second;             i += 1 }
            else if (one === "A")  { out += root.amPmLabels[t.hour < 12 ? 0 : 1]; i += 1 }
            else                   { out += one;                  i += 1 }
        }
        return out
    }

    /**
     * parseTime(str, pattern) → 时间对象或 null
     * 与 parse() 同理，只吃自己 formatTime 产出的格式。
     *
     * 一个容易踩的坑：pattern 必须与实际字符串**配套**。
     * 拿默认的 "HH:mm" 去解析 "12:00 上午" 会匹配失败（返回 null），
     * 这本意是对的 —— 但旧实现里若调用方漏传 pattern，
     * 带 A 的串也不报错、只是悄悄按 24 小时读，"12:00 上午" 会变成 12 时
     * 而不是 0 时。这种"错的静默"最难查，所以这里加一道显式防护：
     * **串里含上午/下午/AM/PM 但 pattern 里没有 A 时，直接判失败。**
     */
    function parseTime(str, pattern) {
        if (!str) return null
        var p = pattern !== undefined && pattern !== null && pattern !== "" ? pattern : "HH:mm"
        var hasA = p.indexOf("A") >= 0

        /* 防护：明显的 12 小时制输入却给了 24 小时制的 pattern */
        if (!hasA && /上午|下午|AM|PM/.test(String(str)))
            return null

        var map = []
        var re = p.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
                  .replace("HH", function() { map.push("H"); return "(\\d{1,2})" })
                  .replace("hh", function() { map.push("h"); return "(\\d{1,2})" })
                  .replace("H",  function() { map.push("H"); return "(\\d{1,2})" })
                  .replace("mm", function() { map.push("m"); return "(\\d{1,2})" })
                  .replace("m",  function() { map.push("m"); return "(\\d{1,2})" })
                  .replace("ss", function() { map.push("s"); return "(\\d{1,2})" })
                  .replace("s",  function() { map.push("s"); return "(\\d{1,2})" })
                  .replace("A",  function() { map.push("A"); return "(上午|下午|AM|PM)" })

        var m = new RegExp("^" + re + "$").exec(String(str).trim())
        if (!m) return null

        var h = null, mi = null, se = null, pm = false
        for (var i = 0; i < map.length; ++i) {
            var raw = m[i + 1]
            if (map[i] === "A") {
                pm = (raw === "下午" || raw === "PM")
            } else {
                var v = parseInt(raw, 10)
                if (map[i] === "H") h = v
                else if (map[i] === "h") h = v
                else if (map[i] === "m") mi = v
                else se = v
            }
        }
        if (h === null || mi === null) return null
        /* 12 小时制转 24：12 上午 = 0 时，12 下午 = 12 时 */
        if (hasA) {
            if (h === 12) h = pm ? 12 : 0
            else if (pm)  h = h + 12
        }
        if (h < 0 || h > 23 || mi < 0 || mi > 59) return null
        return root.makeTime(h, mi, se)
    }

    /**
     * hoursList(step) / minutesList(step) / secondsList(step)
     * 生成时间列的候选项。step 为间隔（如 15 分钟一档）。
     */
    function hoursList(step) {
        var s = step === undefined || step === null || step <= 0 ? 1 : step
        var out = []
        for (var h = 0; h < 24; h += s) out.push(h)
        return out
    }

    function minutesList(step) {
        var s = step === undefined || step === null || step <= 0 ? 1 : step
        var out = []
        for (var m = 0; m < 60; m += s) out.push(m)
        return out
    }

    function secondsList(step) {
        var s = step === undefined || step === null || step <= 0 ? 1 : step
        var out = []
        for (var i = 0; i < 60; i += s) out.push(i)
        return out
    }

    /** 把数字数组按两位补零转成显示用字符串数组 */
    function padAll(list) {
        var out = []
        for (var i = 0; i < list.length; ++i) out.push(root.pad2(list[i]))
        return out
    }
}
