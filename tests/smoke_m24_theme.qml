/****************************************************************************
 * QSkin · 冒烟测试 — M24 的主题接线
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这一轮的主题故事与 M20~M23 不同：**一格新插槽都没有**
 * ════════════════════════════════════════════════════════════════════════
 * 前四轮的主题测试，主体都是"逐家数插槽实现"（谁覆盖了哪一格、装上的是不是
 * 自家那一份）。M24 的七件（Descriptions / Statistic / Image / QRCode /
 * Calendar / Comment / Tour）**一格都没开** —— 理由写在
 * `src/contracts/qmldir` 的 M24 段里，`Slots` 仍是 21 格。
 *
 * 于是这份文件的主题账换了三个问法：
 *   · 名单**没有**被撑大（四家都不许新开格）—— [0] / [2]
 *   · 令牌**真的**通到了这七件的取色处   —— [3] ~ [7]
 *   · 唯一的例外是二维码的**码区**，它是刻意不读令牌的 —— [3]
 *
 * ════════════════════════════════════════════════════════════════════════
 * `Slots.slotNames.length === 21` 是**承诺过的**判据
 * ════════════════════════════════════════════════════════════════════════
 * `qmldir` 的 M24 段写着："判据仍是 M21 那条：只为'同一主题里两种取值
 * 必须并存'的**形态**分歧开格。这条要能被证伪，所以
 * `tests/smoke_m24.qml` 里钉了一条 `Slots.slotNames.length === 21`。"
 *
 * 那条守在属性侧那份文件里；这里把**四家都不许动名单**补上（那边只查了
 * Basic）。两处都留着不算重复：一边守"基线是 21"，一边守"换肤不许把它
 * 撑大"——而后者才是真正会被违反的那条（新开一格时，人总是先想到往主题里
 * 加一个 `xxXx: root.tdXxXx`）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * [1] 是**前提账**，不是又一条断言
 * ════════════════════════════════════════════════════════════════════════
 * 后面每一条"某属性等于当家的令牌"都隐含一个前提：**四家的那个令牌真的
 * 不一样**。要是四家共用同一个值，那么"等于当家的令牌"与"写死一个常量"
 * 是同一句话，那条断言永远不会红 —— 而它看起来像有个守卫。
 *
 * 这正是 M20 踩过的坑（那一轮初版主张分歧在"开态底色"，可 shadcn 的
 * `brandSubtle === bgSunken`，那一枪无论怎么打都不会红，变异测试报 MISSED
 * 且报得对）。所以这里把"先算一遍"单独做成一条断言：它红了说明的是
 * **后面几条的鉴别力没了**，而不是"某个控件画错了"。两种红要能分开。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 三条采集纪律（都是踩出来的）
 * ════════════════════════════════════════════════════════════════════════
 * ① **期望值必须在 `apply()` 区间之内读。**
 *    出了区间读到的是上一家的数（或 Basic 的）。M20 那次表现为"shadcn 以
 *    一个只差 4 阶的颜色差失败"，看着像"令牌没接上"。所以采集函数把
 *    `{ 实际值, 当家的令牌 }` **成对**取回，而不是"读完再回头比对"。
 *
 * ② **`fn` 抛异常也必须把主题摘掉。**
 *    否则这一家会留在场上，后面每一条断言读到的都是它的令牌 ——
 *    一处失败会变成满屏乱码。于是 `one()` 用 `try / finally`。
 *
 * ③ **`Theme.color.*` 是十六进制字符串，不是 color 对象。**
 *    `Theme.color` 是 `readonly property var color: root.active.color`
 *    —— 一个 **`var` 包着的 JS 对象**（`tokens/neutral.js` 里写的就是
 *    `fg: "#18191D"`）。于是：
 *      · `Theme.color.fg.r` 是 `undefined`
 *      · `sameColorQ(实际颜色, Theme.color.fg)` **恒为 false**
 *        （那函数第一行就把字符串判掉，那是它刻意的分工）
 *      · 只有 `sameTokenQ`（走一遍 `property color` 再比）才对
 *    本文件首跑时，[3][4][6] 三条里确实各有一处死在这句上（`[3]` 的
 *    `frameOf` 之外那半段）。这与项目里记过三次的 `url` 型属性坑
 *    （`u === ""` 恒为 false）是**同一个形状**：QML 把值递给 JS 时换了
 *    类型，而读数的写法看起来毫无问题。
 *
 * ④ **`color` 属性读进 JS 拿到的是"活引用"，不是快照。**
 *    这一条是收 [3][4][6] 那三条红时量出来的，也是本文件最贵的一课。
 *    `property color` 的返回值会把 `.r/.g/.b` 的读取**转发到属性当前的值**
 *    上 —— 存进数组、存进对象属性都一样活。实测（同一份文件里的对照，
 *    存下来的都是四家在各自区间内读到的值）：
 *
 *        stored = perTheme(function () { return stat._valueColor })
 *        stored.map(sig)                → ["24,24,29" ×4]   ← 全是 Neutral
 *        Shadcn.apply()
 *        stored.map(sig)                → ["9,9,11"  ×4]   ← 四家一起变 Shadcn
 *        Shadcn.remove()
 *        stored.map(sig)                → ["24,24,29" ×4]   ← 又一起回去
 *
 *    而**在区间内**归一化的那一路是对的：
 *
 *        perTheme(function () { return sig(stat._valueColor) })
 *                                       → ["0,0,0","0,0,0","29,33,41","9,9,11"]
 *
 *    后果：任何"区间内采集、区间外断言"的写法都会把**四家读成同一份**
 *    （当前主题的值），而报告长成"控件根本没跟主题"—— 与 ① 的症状
 *    （读到上一家的数）几乎一样，但病因相反：① 是**采集早了**，④ 是
 *    **判等晚了**。两条都只能靠"在区间内一次做完"来堵。
 *    更阴的是它**不一定报错**：`distinctCount(cols) === 1` 这种
 *    "四家应当相同"的判据在活引用下**永远成立** —— 一条永远不会红的
 *    断言看起来比没有更糟。
 *
 *    所以本文件的采集函数一律在区间内归一化：
 *      · `collectToken(fn)` —— 判等在区间内做完，带出区间的只有签名
 *      · `collectEq(fn)`    —— 数值是原语，天然安全
 *      · `collectSig(fn)`   —— 颜色读数的出口，逐家 `sig()` 过一遍
 *      · `collectRaw(fn)`   —— **只许给原语**；拿到 color 会当场抛异常
 *        （纪律的自执行：写错名字就红，而不是静默四家同一份）
 *
 *    这与 `Theme.color.*` 是字符串（③）、`url` 型属性（`u === ""` 恒 false）
 *    是**同一族**：QML 把值递给 JS 时换了语义，而读数的写法看起来毫无问题。
 *    另外注意：`sig()` 内部那句 `cvt.c = v` 之所以能把活引用"冻"住，
 *    正是因为**赋值发生在一个 `property color` 上**——赋值那一刻求值。
 *
 *    顺带量到的一件事：**换主题会正常通知控件绑定**。同一个探针里，
 *    根上一个新写的 `readonly property color boundFg: Theme.color.fg`
 *    与 `QSkinStatistic._valueColor` 四家都跟着变（Neutral `24,24,29` →
 *    TDesign `0,0,0` → Arco `29,33,41` → shadcn `9,9,11`）。所以
 *    "`property var` 里的嵌套读会不会被登记成依赖"这个担心**不成立**
 *    （`Theme.color` 这个 `var` 本身被重新赋值时会通知）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 断言清单（位掩码退出码，见 tools/test.sh 文件头；上限 8 条）
 * ════════════════════════════════════════════════════════════════════════
 *   [0] 白名单账目：21 格 / 五个具名反例不在 / 白名单外的键被丢 /
 *                   **真装两格**后 reset 逐格回到 Basic（含 basic* 存在性）
 *   [1] **前提账**：brand · border · fg · radius.lg · size.controlLg 四家真有分歧
 *   [2] 四家换肤都不许动这份名单（仍是 21，且 `label` 回到 Basic）
 *   [3] QSkinQRCode：码区纯黑白、四家逐位相同、且路径真的按它填色；
 *       占位框那圈**是**走令牌的（读的是无效那一份 —— 它在渲染上真的存在）
 *   [4] QSkinCalendar：选中实底 / 今天描边，都等于当家的 `brand`
 *   [5] QSkinDescriptions：统一标签宽 = 组内最宽那个（四家都成立，且随字体变）
 *   [6] QSkinStatistic：格式化是纯函数（四家同一组结果）；色档跟随当家令牌
 *   [7] QSkinImage / QSkinComment / QSkinTour 的令牌接线
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0
import QSkin.Theme.AntDesign 1.0
import QSkin.Theme.ArcoDesign 1.0
import QSkin.Theme.Shadcn 1.0

Item {
    id: root

    property int mask: 0
    property int idx: 0

    width: 1100
    height: 900

    readonly property var fixedToday: ({ year: 2026, month: 3, day: 15 })

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    function check(block) {
        var ok = false
        try { ok = block() === true } catch (e) { ok = false }
        root.expect(ok)
    }

    /* ══════════════════ 被测对象 ══════════════════ */

    /* QRCode：有效的一份（码区要画的）与无效的一份（占位框要画的）。
     * 两份都要 —— 见 [3] 的注释：占位框在有效的那份上是 `visible: false`，
     * 判据不能读渲染上不存在的量（M23 的 `border.color` 那一课）。 */
    QSkinQRCode {
        id: qr

        x: 10
        y: 10
        value: "https://qds.dev/m24"
        moduleSize: 4
    }

    QSkinQRCode {
        id: qrEmpty

        x: 220
        y: 10
        value: ""
    }

    /* 两个日历：一个 value = today（选中实底），一个 value ≠ today
     * （只是今天 → 描边）。两格两条等腰路径，见 [4]。 */
    QSkinCalendar {
        id: cal

        x: 10
        y: 220

        today: root.fixedToday
        value: ({ year: 2026, month: 3, day: 15 })
    }

    QSkinCalendar {
        id: calTodayOnly

        x: 400
        y: 220

        today: root.fixedToday
        value: ({ year: 2026, month: 3, day: 8 })
    }

    QSkinDescriptions {
        id: desc

        x: 10
        y: 520
        column: 3
        colon: true

        QSkinDescriptionsItem { id: da; label: "姓名"; span: 1; Body { text: "张伟" } }
        QSkinDescriptionsItem { id: db; label: "联系电话"; span: 2; Body { text: "13800000000" } }
    }

    QSkinStatistic {
        id: stat

        x: 400
        y: 520
        value: 1234567.891
        precision: 2
        separator: true
    }

    QSkinStatistic {
        id: statOk

        x: 400
        y: 620
        value: 99.6
        valueStyle: "success"
    }

    QSkinImage {
        id: img

        x: 400
        y: 700
        width: 120
        height: 60
        src: ""
    }

    QSkinComment {
        id: cmt

        x: 10
        y: 700
        width: 340
        author: "张伟"
        content: "令牌接线"
    }

    QSkinTour {
        id: tour

        steps: [{ title: "一", description: "d" }]
    }

    /* 白名单过滤用的假件（[0]） */
    Component {
        id: fakeComp

        Rectangle {
            color: "#FF00FF"
        }
    }

    /* ══════════════════ 工具 ══════════════════ */

    QtObject {
        id: cvt
        property color c: "#000000"
    }

    function sameColorQ(a, b) {
        if (a === null || a === undefined || b === null || b === undefined) return false
        if (typeof a === "string" || typeof b === "string") return false
        if (a.r === undefined || b.r === undefined) return false
        return Math.round(a.r * 255) === Math.round(b.r * 255)
            && Math.round(a.g * 255) === Math.round(b.g * 255)
            && Math.round(a.b * 255) === Math.round(b.b * 255)
            && Math.round(a.a * 100) === Math.round(b.a * 100)
    }

    function sameTokenQ(actual, token) {
        if (token === undefined || token === null) return false
        cvt.c = token
        return root.sameColorQ(actual, cvt.c)
    }

    /** 值的**可比签名**：数字取两位小数、颜色经 `property color` 规范化
     *  成整数通道（**带 alpha**，两位小数）。用来数分歧（"四家里有几个
     *  不同的值"），也用来把颜色带出 `apply()` 区间。
     *
     *  ⚠ 它的第二个身份更重要：**它是"活引用 → 快照"的那个转换点**
     *  （见文件头纪律 ④）。`cvt.c` 是 `property color`，`cvt.c = v` 在
     *  **赋值那一刻**把值定死。所以颜色读数**必须在区间内**过这一遍 ——
     *  带出区间再 `sig()` 得到的是"当前主题"的值，不是采集那一刻的。
     *
     *  alpha 必须一起读：TDesign / Ant 的 `fg` 自带 `0xE5`/`0xE0` 的
     *  alpha（实测 `#E5000000` / `#E0000000`）。丢掉 alpha 的话，这两家
     *  会与"纯黑"签成同一个串，而它们与纯黑是**两回事**。 */
    function sig(v) {
        if (v === undefined || v === null) return "nil"
        if (typeof v === "number") return String(Math.round(v * 100) / 100)
        if (typeof v === "boolean") return String(v)
        if (typeof v === "string") return v
        if (v.r !== undefined) {
            cvt.c = v
            return Math.round(cvt.c.r * 255) + ","
                   + Math.round(cvt.c.g * 255) + ","
                   + Math.round(cvt.c.b * 255) + ","
                   + Math.round(cvt.c.a * 100) / 100
        }
        return "?"
    }

    function distinctCount(arr) {
        var seen = []
        for (var i = 0; i < arr.length; ++i) {
            var s = root.sig(arr[i])
            if (seen.indexOf(s) < 0) seen.push(s)
        }
        return seen.length
    }

    /** 换上一家、读、**无论成败都摘掉**（纪律 ②）。 */
    function one(theme, fn) {
        var v = null
        theme.apply()
        try {
            v = fn()
        } finally {
            theme.remove()
        }
        return v
    }

    /** 四家各采一轮，返回长度 4 的数组（0=TDesign 1=Ant 2=Arco 3=Shadcn）。 */
    function perTheme(fn) {
        return [ root.one(TDesign, fn),
                 root.one(AntDesign, fn),
                 root.one(ArcoDesign, fn),
                 root.one(Shadcn, fn) ]
    }

    /** 颜色版：`fn` 返回 `{ a: 实际值, t: 当家的令牌 }`，**在区间内**成对读
     *  （纪律 ①）。返回 `{ ok, values }`，`values` 是**签名**（字符串），
     *  不是颜色 —— 颜色带不出区间（纪律 ④）。
     *
     *  ⚠ 两条都要在**区间内**做完，缺一条就白做：
     *    · `sameTokenQ(p.a, p.t)` 必须在区间内调 —— 走到区间外，`p.a`
     *      就变回"当前主题"的活引用，比的是别的主题（纪律 ④）。
     *    · 比较必须走 `sameTokenQ`，**不能**走 `sameColorQ`：
     *      `Theme.color.*` 是**十六进制字符串**（`tokens/neutral.js` 里就是
     *      `fg: "#18191D"`），而 `sameColorQ` 的第一行就把字符串判 false
     *      （那是它刻意的行为，见隔壁 smoke_m23_theme 的注释）。
     *
     *  首版把判等写在区间外，于是 [4]/[6] 两条报"实际值与令牌不等"，
     *  而实际值其实**完全正确** —— 两条纪律各犯了一半。 */
    function collectToken(fn) {
        var pairs = root.perTheme(function () {
            var p = fn()
            if (p === null || p === undefined
                || p.a === null || p.a === undefined)
                return { eq: false, a: "nil" }
            /* ↓ 这两句是纪律 ④ 的全部：在区间内判等、在区间内取签名 */
            return { eq: root.sameTokenQ(p.a, p.t), a: root.sig(p.a) }
        })
        var ok = true
        var vals = []
        for (var i = 0; i < pairs.length; ++i) {
            if (!pairs[i].eq) ok = false
            vals.push(pairs[i].a)
        }
        return { ok: ok, values: vals }
    }

    /** 数值版。**数值是原语，带出区间是安全的** —— 所以这里可以照旧
     *  "先采集、后判等"（`p.a` 是一个数，不是活引用）。 */
    function collectEq(fn) {
        var pairs = root.perTheme(fn)
        var ok = true
        var vals = []
        for (var i = 0; i < pairs.length; ++i) {
            var p = pairs[i]
            if (p === null || p === undefined || p.a === null || p.a === undefined) {
                ok = false
                continue
            }
            if (p.a !== p.t) ok = false
            vals.push(p.a)
        }
        return { ok: ok, values: vals }
    }

    /** 颜色读数的出口：逐家在区间内 `sig()` 过一遍，返回四家签名的数组。
     *  任何"要读某个控件的颜色属性"的判据都走这里（纪律 ④）。 */
    function collectSig(fn) {
        return root.perTheme(function () { return root.sig(fn()) })
    }

    /** 原语版。**只许给字符串 / 数字 / 布尔**。
     *
     *  ⚠ 拿到一个 color 会**当场抛异常**，这是纪律 ④ 的自执行：颜色是
     *  活引用，用 `collectRaw` 读它得到的不是"四家的值"，而是"四份同一
     *  个当前值"。那种错法**不一定报错**（"四家应当相同"的判据会永远
     *  成立），所以不能靠人自觉 —— 写错名字就红。
     *
     *  抛出的异常由 `check()` 兜住，表现为这条断言红，并带上
     *  `LIVE-COLOR-ESCAPE` 这个标记方便按名字定位。 */
    function collectRaw(fn) {
        var vals = root.perTheme(fn)
        for (var i = 0; i < vals.length; ++i) {
            var v = vals[i]
            if (v !== null && typeof v === "object" && v.r !== undefined)
                throw new Error("LIVE-COLOR-ESCAPE: 这一步的颜色读数必须走 collectSig()（纪律 ④）")
        }
        return vals
    }

    function collect(item, pred, out, d) {
        if (item === null || item === undefined || d > 16) return
        if (pred(item)) out.push(item)
        var ch = item.children
        if (ch === undefined) return
        for (var i = 0; i < ch.length; ++i) root.collect(ch[i], pred, out, d + 1)
    }

    function findIn(item, pred) {
        var out = []
        root.collect(item, pred, out, 0)
        return out.length > 0 ? out[0] : null
    }

    function findAll(item, pred) {
        var out = []
        root.collect(item, pred, out, 0)
        return out
    }

    /** 选中的那一格（格子的 `sel` 是它自己的派生量）。 */
    function selCellOf(calItem) {
        return root.findIn(calItem, function (o) {
            return o.sel === true && o.d !== undefined
        })
    }

    /** 格子里那个高亮块。日期文字走 `Slots.label`（一个 Text，有 `font`），
     *  而 Text 是被 Loader 装进来的、**不在 `children` 里** —— 所以"有 color
     *  有 radius 没有 font"只可能命中那一块。 */
    function markOf(cell) {
        if (cell === null) return null
        return root.findIn(cell, function (o) {
            return o.color !== undefined && o.radius !== undefined && o.font === undefined
        })
    }

    /** QRCode 的占位框：**既不填色、又有描边**的那个矩形。
     *
     *  ⚠ `Rectangle.border.width` 的**默认值就是 1** —— 所以
     *  "`border.width > 0`"根本判别不了"有没有描边"，底板那层没写
     *  `border.width` 也读出 1（M23 已记过这一条，本轮又踩一次：
     *  只判 `border.width > 0` 必然命中底板，而底板的 `border.color`
     *  是默认的不透明黑 —— 四家读出来一样，"四家不全相同"跟着一起红，
     *  看着像令牌断了）。
     *
     *  可靠的结构信号是**两条一起判**：
     *    · `color.a < 0.001` —— 不填色。底板（`root.background`）与
     *      logo 底板都是实心的，只有占位框是 `color: "transparent"`
     *      （见 `QSkinQRCode.qml` 的「占位框」那一段）。
     *    · `border.width > 0` —— 有那一圈线。
     *  再带上 `radius`，把"没有圆角的方格"排除掉。
     *
     *  这条判据是可证伪的：把占位框的 `border.color: Theme.color.border`
     *  删掉，命中的还是它，但 `border.color` 是默认黑 → `[3]` 的
     *  `eq` 与"四家不全相同"两条一起红；把整个占位框删掉则 `frameOf`
     *  返回 null → 也红。 */
    function frameOf(qrItem) {
        return root.findIn(qrItem, function (o) {
            return o.color !== undefined && o.color.a < 0.001
                   && o.radius !== undefined
                   && o.border !== undefined && o.border.width > 0
        })
    }

    /** QRCode 码区那条路径。
     *
     *  ⚠ `ShapePath` **不是 Item**，它挂在 `Shape.data` 上、不在
     *  `children` 里 —— 所以 `findIn` 找不到它（首跑 `path === null`
     *  就是这么来的，而"找不到"被读成了"没接线"）。
     *  先按 Shape 的特征属性找到 Shape，再去它的 `data` 上挑出带
     *  `fillColor` 的那一个。 */
    function shapePathOf(host) {
        var shp = root.findIn(host, function (o) {
            return o.data !== undefined && o.preferredRendererType !== undefined
        })
        if (shp === null) return null
        var d = shp.data
        if (d === undefined) return null
        for (var i = 0; i < d.length; ++i)
            if (d[i] !== undefined && d[i].fillColor !== undefined) return d[i]
        return null
    }

    /* ══════════════════ 断言 ══════════════════ */

    function run() {
        Slots.reset()

        /* ── [0] 白名单账目 ──
         *
         * 四件事一起读：
         *   · 总数**恰好 21** —— 刻意的常量。加一格就来改这里，
         *     改的时候会看到旁边 [2] 的说明"为什么这一批一格都不该开"。
         *   · 五个具名反例不在名单里。它们都是这一批**真的考虑过**的名字
         *     （描述项的标签、日历格子、图片占位、二维码码区、引导面板），
         *     每一个都能配出一张说得通的截图 —— 而单看截图看不出
         *     "契约面被永久撑大了"。
         *   · 白名单外的键必须被丢（写错名字时不许"装上了半格"）。
         *   · `reset()` 之后回到 21 格、`label` 回到 Basic。
         *
         * 判据是"引用相等"而不是"非 null" —— M19 的 spinRing 栽在后者上
         * （四家全没装上，而属性侧一片自洽）。 */
        root.idx = 0
        root.check(function () {
            var names = Slots.slotNames
            var countOk = names.length === 21

            var banned = ["descriptionsLabel", "calendarCell", "imagePlaceholder",
                          "qrModule", "tourPanel"]
            var bannedOk = true
            for (var i = 0; i < banned.length; ++i)
                if (names.indexOf(banned[i]) >= 0) bannedOk = false

            /* ── 白名单外的键必须被丢 ── */
            var labelRef = Slots.label
            var bgRef = Slots.buttonBackground
            Slots.install({ descriptionsLabel: fakeComp, calendarCell: fakeComp })
            var filterOk = Slots.slotNames.length === 21
                           && Slots.label === labelRef
                           && Slots.buttonBackground === bgRef

            /* ── reset() 必须把**真的装上去的**换回来 ──
             *
             * ⚠ 上一版这里是**空转**：`install()` 传的两个键都是非法的，
             * 一格都没装上 → `reset()` 无事可做 → 拿 reset 里**任何一行**
             * 开刀都测不出来。mutate_m24_theme.py 的第三枪
             * （`root.buttonBackground = root.basicButtonBackground`
             * 改成写回自己）就是这么拿到 MISSED 的 ——
             * "查错了格子"只是表层，真因是**这条不变量从没被触发过**。
             *
             * 所以下面先真的装两格（都在白名单里）再 reset。
             * `installedOk` 是必要的前置：不先证明"装上了"，
             * 后面那个"换回来了"就可能只是"压根没变"。 */
            Slots.install({ buttonBackground: fakeComp, label: fakeComp })
            var installedOk = Slots.buttonBackground === fakeComp
                              && Slots.label === fakeComp

            Slots.reset()
            var backOk = Slots.slotNames.length === 21
                         && Slots.label === labelRef
                         && Slots.label === Slots.basicLabel
                         && Slots.buttonBackground === bgRef

            /* ── 逐格：reset() 之后**每一格**都必须等于自己的 Basic ──
             *
             * 这一条同时是一道**结构闸**：名单里每加一格，就必须同时有
             * `basic<Name>` 与 `reset()` 里的一行；缺任一个，这里就红。
             * 槽名 → Basic 属性的映射就是 "basic" + 首字母大写，
             * 21 格逐字对得上（`basicBreadcrumbSeparator` 这种也不例外）。 */
            var missing = []
            for (var k = 0; k < names.length; ++k) {
                var prop = "basic" + names[k].charAt(0).toUpperCase()
                           + names[k].slice(1)
                if (Slots[prop] === undefined || Slots[names[k]] !== Slots[prop])
                    missing.push(names[k])
            }
            var allBasicOk = missing.length === 0

            return countOk && bannedOk && filterOk && installedOk
                   && backOk && allBasicOk
        })

        /* ── [1] 前提账：四家的令牌真有分歧 ──
         *
         * 这一条红了，说明的是**后面几条的鉴别力没了**，而不是某个控件画错。
         * 两种红要能分开 —— 所以这条单独占一个位，而且注释写清它是前提。
         *
         * 五个令牌各自数一遍：只要有一家在某个令牌上与别家相同，后面读那个
         * 令牌的断言就退化成了"等于一个常量"。 */
        root.idx = 1
        root.check(function () {
            return root.distinctCount(root.collectRaw(function () { return Theme.color.brand })) >= 2
                && root.distinctCount(root.collectRaw(function () { return Theme.color.border })) >= 2
                && root.distinctCount(root.collectRaw(function () { return Theme.color.fg })) >= 2
                && root.distinctCount(root.collectRaw(function () { return Theme.radius.lg })) >= 2
                && root.distinctCount(root.collectRaw(function () { return Theme.size.controlLg })) >= 2
        })

        /* ── [2] 四家换肤都不许动这份名单 ──
         *
         * M24 的七件全部复用既有格：`Slots.label`（标签、日期数字、动作、
         * 面板标题）、`Slots.chevronIndicator`（日历翻月）等等。逐家查
         * "名单还是 21" + "`label` 换上了自家那一份又摘得回去"。
         *
         * 为什么这一条会真被违反：新开一格的成本看起来**极低**（往主题里
         * 加一行 `xxXx: root.tdXxXx`），而它把契约面永久撑大了 ——
         * 所以这里要在四家身上各守一次。 */
        root.idx = 2
        root.check(function () {
            var basicLabel = Slots.basicLabel
            var everyOk = true
            var themes = [TDesign, AntDesign, ArcoDesign, Shadcn]
            for (var i = 0; i < themes.length; ++i) {
                var n = root.one(themes[i], function () { return Slots.slotNames.length })
                if (n !== 21) everyOk = false
            }
            Slots.reset()
            return everyOk && Slots.slotNames.length === 21 && Slots.label === basicLabel
        })

        /* ── [3] QSkinQRCode：码区不随主题，框随主题 ──
         *
         * 这是本批**唯一**一处刻意不读令牌的地方（理由在 QSkinQRCode 文件头：
         * 二维码是给机器读的，深色主题下的 `fg` 会让对比度掉到扫不出来的
         * 地步）。把它写成断言，是为了让"哪天有人顺手改成 Theme.color.fg"
         * 这件事会红。
         *
         * 三件事：
         *   · `color` / `background` 四家**逐位相同**，且就是纯黑/纯白
         *   · `matrixText` 四家相同（矩阵是数据的函数，与主题无关）
         *   · 码区**路径真的按这个色填**（否则"属性是纯黑"可能只是没人读它）
         *
         * 然后是反面：占位框那圈**是**走令牌的，且四家不全相同。
         * 读的是 `qrEmpty` —— 占位框在有效的那份上是 `visible: false`，
         * 而"判据不能读渲染上不存在的量"是 M23 用一次误诊换来的规矩。 */
        root.idx = 3
        root.check(function () {
            /* `qr.color` / `qr.background` 是 color 属性 → 走 `collectSig`
             * （纪律 ④：带出区间的颜色是活引用，"四家相同"这条判据在活
             * 引用下**必然成立**，那等于没有判据）。 */
            var cols = root.collectSig(function () { return qr.color })
            var bgs = root.collectSig(function () { return qr.background })
            var mats = root.collectRaw(function () { return qr.matrixText })

            var pureOk = root.distinctCount(cols) === 1
                         && root.distinctCount(bgs) === 1
                         && root.distinctCount(mats) === 1
                         && cols[0] === root.sig(Qt.rgba(0, 0, 0, 1))
                         && bgs[0] === root.sig(Qt.rgba(1, 1, 1, 1))

            /* 路径的 fillColor 就是它 —— ShapePath 不在 `children` 里，
             * 见 `shapePathOf()` 的注释。`fillColor` 是 color 属性，
             * 所以"取签名"必须在区间内（纪律 ④）。
             * 顺带把"四家路径同色"一起读了：路径是从 `matrixText` 推出来的，
             * 与主题无关，四家必须一样。 */
            var pathSigs = root.collectSig(function () {
                var pth = root.shapePathOf(qr)
                return pth === null ? "nil" : pth.fillColor
            })
            var wiredOk = pathSigs[0] !== "nil"
                          && root.distinctCount(pathSigs) === 1
                          && pathSigs[0] === cols[0]

            /* 框：成对读（实际值 / 当家的令牌），要求每家都对上、且四家不全相同。
             * `frameOf` 返回 null 时 `collectToken` 会给出 `eq: false` —— 所以
             * 不必再单独判一次"找着了没有"（`ok` 已经把它包含进去）。 */
            var fr = root.collectToken(function () {
                var w = root.frameOf(qrEmpty)
                return { a: w === null ? null : w.border.color, t: Theme.color.border }
            })
            var frameOk = fr.ok && root.distinctCount(fr.values) >= 2

            return pureOk && wiredOk && frameOk
        })

        /* ── [4] QSkinCalendar：两格两种形态，都是当家令牌 ──
         *
         * 日历的选中是**实底**、今天是**描边**（两者同时成立时实底优先）。
         * 两个实例分别走这两条路径：
         *   · `cal`          value = today  → 选中实底，`color === brand`、无描边
         *   · `calTodayOnly` value ≠ today  → 只是今天，`border.color === brand`、
         *                                     `color` 是透明的
         *
         * 四条一起读才是"令牌在两条路径上都通着"：只读实底会放过"今天那圈
         * 写死了颜色"，而那一圈在深色主题下最容易变成看不见的灰。 */
        root.idx = 4
        root.check(function () {
            /* `m.color` 是 color 属性 → 用 `collectToken`：它在区间内
             * 判等、并只把签名带出来（纪律 ④）。 */
            var sel = root.collectToken(function () {
                var m = root.markOf(root.selCellOf(cal))
                return { a: m === null ? null : m.color, t: Theme.color.brand }
            })

            /* 四处读数（描边色 / 描边宽 / 填充色的 alpha）**必须一次在区间内
             * 读完并归一化** —— `m.border.color` 与 `m.color` 都是 color 属性，
             * 带出区间就只剩"当前主题"那一份（纪律 ④）。 */
            var todPairs = root.perTheme(function () {
                var cell = root.findIn(calTodayOnly, function (o) {
                    return o.sel === false && o.d !== undefined && o.d.day === 15
                })
                var m = root.markOf(cell)
                if (m === null) return { eq: false, a: "nil", w: -1, fillA: -1 }
                return { eq: root.sameTokenQ(m.border.color, Theme.color.brand),
                         a: root.sig(m.border.color),
                         w: m.border.width,
                         fillA: m.color.a }
            })
            var todOk = true
            var todVals = []
            for (var j = 0; j < todPairs.length; ++j) {
                var pj = todPairs[j]
                if (!pj.eq) todOk = false
                if (pj.w !== 1) todOk = false          /* 今天用描边 */
                if (pj.fillA !== 0) todOk = false      /* 且不填色 */
                todVals.push(pj.a)
            }
            var tod = { ok: todOk, values: todVals }

            return sel.ok && tod.ok
                   && root.distinctCount(sel.values) >= 2
                   && root.distinctCount(tod.values) >= 2
        })

        /* ── [5] QSkinDescriptions：统一标签宽 = 组内最宽那个 ──
         *
         * 这条不是"颜色随主题"，是**尺寸随主题字体**：`labelWidthHint` 是量
         * 出来的文本宽（"联系电话"比"姓名"宽），统一宽取最宽者，两个成员
         * 的标签实际占位都等于它。
         *
         * 四家各验一遍，是因为字体族跟着主题换（`Theme.font.family`）——
         * 换了字体这一步就得重新量一遍。写死一个宽度的实现在四家里会有一家
         * 露馅；而只想守"标签对齐"的实现在四家都绿（那也是对的，只是它
         * 同时还得满足"随字体变"）。
         *
         * 冒号是**拼进标签文本**的（Ant 的 colon 同款），与主题无关 ——
         * 一起读，免得将来有人把它挪成一个独立 Text 而这里没人响。 */
        root.idx = 5
        root.check(function () {
            var everyOk = true
            var themes = [TDesign, AntDesign, ArcoDesign, Shadcn]
            for (var i = 0; i < themes.length; ++i) {
                /* eslint-disable no-loop-func */
                var ok = root.one(themes[i], function () {
                    var u = desc._uniformLabelWidth
                    var h0 = da.labelWidthHint
                    var h1 = db.labelWidthHint
                    return h0 > 0 && h1 > h0
                           && u === h1
                           && da._labelW === u && db._labelW === u
                           && da.labelText === "姓名："
                           && db.labelText === "联系电话："
                })
                if (!ok) everyOk = false
            }
            Slots.reset()
            return everyOk
        })

        /* ── [6] QSkinStatistic：格式化是纯函数，颜色才跟主题 ──
         *
         * 两半：
         *   · `formatValue` / `groupDigits` 的结果**四家逐位相同** ——
         *     它们只吃数字与配置，不吃任何令牌。这一条同时是"别把主题
         *     扯进格式化"的守卫（千分位分隔符在有的语言里是空格、
         *     小数点有的语言是逗号，将来真要做 i18n 时这里会先红，
         *     提醒你那是**语言**的事不是**主题**的事）。
         *   · 色档跟随当家令牌：默认档是 `fg`，`valueStyle: "success"`
         *     那份是 `success`。两条都读 —— 只读默认档分不清"永远用
         *     fg"与"正确地跟随"（success 那份会是死的）。 */
        root.idx = 6
        root.check(function () {
            var fmt = root.collectRaw(function () {
                return stat.formatValue(1234567.891, 2, true, null)
                        + "|" + stat.formatValue(-1234.5, 1, true, null)
                        + "|" + stat.groupDigits("1234567")
            })
            var fmtOk = root.distinctCount(fmt) === 1
                        && fmt[0] === "1,234,567.89|-1,234.5|1,234,567"

            var def = root.collectToken(function () {
                return { a: stat._valueColor, t: Theme.color.fg }
            })
            var okd = root.collectToken(function () {
                return { a: statOk._valueColor, t: Theme.color.success }
            })

            return fmtOk
                   && def.ok && root.distinctCount(def.values) >= 2
                   && okd.ok && root.distinctCount(okd.values) >= 2
        })

        /* ── [7] QSkinImage / QSkinComment / QSkinTour 的令牌接线 ──
         *
         * 三件各自最"该跟主题走"的那个量：
         *   · Image 的圆角（`radius.lg`）—— 它同时决定遮罩的开合，
         *     所以这个数变了 `masked` 的行为也跟着变
         *   · Comment 的头像尺寸与行距（`size.controlLg` / `space.md`）
         *     —— 头像尺寸四家不全相同，"四家里有几个不同的值"由 [1] 保证
         *   · Tour 的高亮外扩（`space.xs`）与面板宽（320，**常量**）
         *
         * 顺手把 `fillModeOf` 也读一遍：它是纯函数，四家必须逐位相同 ——
         * 与 [6] 的格式化同一条理由（object-fit 是**语义**，不是外观）。
         *
         * `indent` 与 `panelWidth` 是"故意不跟主题走"的两个常量：
         * 一个嵌套评论的缩进、一个引导面板的宽度，都属于版式而非皮肤。
         * 把它们一起读出来，是为了让"哪天有人把它们接上令牌"这件事有回应。 */
        root.idx = 7
        root.check(function () {
            var modes = root.collectRaw(function () {
                return img.fillModeOf("cover", 400, 400, 200, 200)
                        + "|" + img.fillModeOf("scale-down", 40, 40, 200, 200)
                        + "|" + img.fillModeOf("乱写", 400, 400, 200, 200)
            })
            var modeOk = root.distinctCount(modes) === 1

            var rad = root.collectEq(function () {
                return { a: img.radius, t: Theme.radius.lg }
            })
            var av = root.collectEq(function () {
                return { a: cmt.avatarSize, t: Theme.size.controlLg }
            })
            var gap = root.collectEq(function () {
                return { a: cmt._gap, t: Theme.space.md }
            })
            var pad = root.collectEq(function () {
                return { a: tour.highlightPadding, t: Theme.space.xs }
            })
            var pw = root.collectRaw(function () { return tour.panelWidth })
            var ready = root.collectRaw(function () { return tour.maskReady })

            /* `maskReady` 四家都是 **true** —— 即使这个 `tour` 从来没被
             * `open` 过。这是量出来的事实，也是首跑另一处变红的地方
             * （当时写的是 `=== false`，想当然地以为浮层是惰性创建的）：
             * **Popup 的 contentItem 在组件创建时就存在，而且会被定尺寸**；
             * 会晚一帧的是"0×0 → 真实尺寸"这一步。把它写成断言，是为了
             * 让"哪天有人真把它改成惰性创建"这件事有回应 —— 那时
             * `smoke_m24.qml` 里那道等 `maskReady` 的时序门才有意义。 */
            var constOk = root.distinctCount(pw) === 1 && pw[0] === 320
                          && root.distinctCount(ready) === 1 && ready[0] === true
                          && root.collectRaw(function () { return cmt.indent })[0] === 0

            return modeOk && rad.ok && root.distinctCount(rad.values) >= 1
                   && av.ok && root.distinctCount(av.values) >= 2
                   && gap.ok
                   && pad.ok
                   && constOk
        })

        Slots.reset()
        Qt.exit(root.mask)
    }

    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }

    /* 推迟一轮再断言：Qt Quick Layouts 的尺寸重算在 polish 阶段
     * （见 smoke_sizes.qml）。这一份还要多一样东西 —— `desc` 的
     * `labelWidthHint` 是**量出来的文本宽**，得等字体与文本都就位。 */
    Component.onCompleted: function () {
        try {
            Qt.callLater(root.run)
        } catch (e) {
            Qt.exit(255)
        }
    }
}
