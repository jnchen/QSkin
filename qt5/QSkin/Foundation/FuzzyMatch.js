/****************************************************************************
 * QSkin · Quick Design System — Foundation
 * 模糊匹配打分器
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 输入 `(query, text)`，输出**分数 + 命中下标**。它不画一笔 ——
 * 画高亮是 Contracts 层 QSkinCommand 的事。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么这是一个 `.js` 而不是一个 QML 单例
 * ════════════════════════════════════════════════════════════════════════
 * 因为门禁要**做独立算路**。
 *
 * 本仓对"算出来的东西要对"的既有做法是像素核验（把屏幕上的墨读回来）。
 * 但打分器的输出是**一个整数 + 一串下标**，存在比像素强得多的核验可能：
 *
 *   ① 用 node 直接跑**这一个文件**，拿分数与命中下标；
 *   ② 用**穷举**所有合法对齐（≤ 2^n 种下标组合）求最优分数与参照实现比。
 *
 * ② 是真正意义上的独立算路：它与本文件的 DP 没有任何共享代码，
 * 也不共享"必须用 DP"这个假设。若打分器长在 QML 控件里，就只能通过
 * 控件属性去摸「控件认为的分数」—— 而"控件认为的"与"算出来的"一致，
 * 什么也证明不了。住在 `.js` 之后，`QSkinCommand` 与核验器是**同一份源码的
 * 两个消费者**，不是看起来一样的两份实现（M18 记过这条：
 * 「出现了第二份画线的代码」）。
 *
 * 所以本文件刻意**不写 `.pragma library`** —— 那条指令是 QML 专有的，
 * node 会当作语法错误。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 匹配规则（全部是**整数**运算，所以断言可以写等号）
 * ════════════════════════════════════════════════════════════════════════
 *
 * 命中 = query 的每个字符依序出现在 text 里（**子序列**，不必连续）。
 *
 *     score = Σ 每个命中字符的
 *               CHAR      1   每个命中字符
 *             + CONSEC    8   紧挨着上一个命中字符（下标恰好差 1）
 *             + BOUNDARY  6   落在**词首**（下标 0 / 前一个是分隔符 /
 *                             前一个小写后一个大写的驼峰边界）
 *
 * 于是三个可观察的性质，都能被穷举核验：
 *   · 连续命中永远优于拆开命中（CONSEC > 0）
 *   · 词首命中优于词中命中（BOUNDARY > 0）
 *   · 长度相同、字符相同的两次匹配，分数相同（**没有**位置衰减项）
 *
 * ── 为什么没有"距离惩罚" ────────────────────────────────────────────
 * 有距离惩罚就得引入浮点（或一个任意的最小距离系数），而浮点会让
 * 「分数相等」这类断言变成 epsilon 比较 —— 本项目已经因为"判据不能要求
 * 一件做不到的事"改过一次判据（M24 的 7% 遮罩）。这里用整数把这件事
 * 从根上去掉：要么分数相等，要么不相等。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 两条**刻意的**确定性选择（它们同时也是判据）
 * ════════════════════════════════════════════════════════════════════════
 *
 * 1. **并列取最左**。同一分数可能对应多种对齐（`query="ab"`, `text="aab"`
 *    可以取 (0,1) 或 (0,2) 或 (1,2)），这里固定取**下标字典序最小**的那一种。
 *    理由：命中下标会被画成高亮，而"同一个输入偶尔高亮在不同的字上"是
 *    抓图与像素核验最怕的那类不确定。
 *
 * 2. **空查询返回 0 分、零命中**，不是 `null`。`null` 会被调用方读成
 *    「不匹配」而把条目全滤掉；0 分则让"稳定排序"保住**声明序** ——
 *    这正是 cmdk / Ant Select 的语义（空输入 = 全量、原序）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 已知边界（写出来，不假装没有）
 * ════════════════════════════════════════════════════════════════════════
 *
 * · 命中下标是 **UTF-16 码元下标**，不做字素簇切分。中文每字一个码元，
 *   没问题；emoji（代理对）会被算成两个码元，高亮时可能劈开一个 emoji。
 *   本项目至今没有把 emoji 放进命令条目，所以不预先还这笔复杂度。
 * · 大小写不敏感是 `toLowerCase()` 级别，不做 locale 折叠
 *   （土耳其语的 `I`/`ı` 会与预期不同）。同一条：没有消费者就不做。
 ****************************************************************************/

/* ═══════════════════════ 打分常量 ═══════════════════════ */

var CHAR     = 1   /* 每个命中字符 */
var CONSEC   = 8   /* 与上一个命中字符相邻 */
var BOUNDARY = 6   /* 落在词首 */

/* ═══════════════════════ 分词辅助 ═══════════════════════ */

/* 词边界分隔符。刻意**不含**大写字母 —— 驼峰由 _isLower/_isUpper 那一对判，
   混进这里会让 "AbCd" 的 A 与 C 都算成"前一个是分隔符"。 */
var SEPARATORS = " \t\n\r-_/\\.:,;|·、，。：；！？（）()[]{}<>#@+*&=%$^~`\"'"

function _isSep(ch) {
    return ch !== "" && SEPARATORS.indexOf(ch) >= 0
}

function _isLower(ch) {
    return ch >= "a" && ch <= "z"
}

function _isUpper(ch) {
    return ch >= "A" && ch <= "Z"
}

/** text 的下标 i 是不是一个"词首" */
function _isBoundary(text, i) {
    if (i === 0) return true
    var prev = text.charAt(i - 1)
    if (_isSep(prev)) return true
    /* 驼峰：小写 → 大写 */
    return _isLower(prev) && _isUpper(text.charAt(i))
}

/** 大小写不敏感的单字符相等 */
function _eq(a, b, caseSensitive) {
    if (a === b) return true
    if (caseSensitive) return false
    return a.toLowerCase() === b.toLowerCase()
}

/* ═══════════════════════ 打分 ═══════════════════════ */

/**
 * score(query, text, opts) → { score, hits } | null
 *
 *   opts.caseSensitive  缺省 false
 *
 * 返回 null 表示**不匹配**（query 不是 text 的子序列）。
 * 空 query 返回 `{ score: 0, hits: [] }` —— 见文件头第 2 条。
 */
function score(query, text, opts) {
    opts = opts || {}
    var caseSensitive = opts.caseSensitive === true

    var q = (query === null || query === undefined) ? "" : String(query)
    var t = (text  === null || text  === undefined) ? "" : String(text)

    if (q.length === 0) return { score: 0, hits: [] }
    if (q.length > t.length) return null

    var m = q.length
    var n = t.length
    var NEG = -1e15   /* 用一个大负数当 -∞，比 undefined 判定便宜且不会误判 */

    /* dp[k][i] = 「已匹配 q[0..k]，且 q[k] 落在 t[i]」可达的最大分数
     * fr[k][i] = 取得该分数时上一个命中字符的下标（首字符为 -1） */
    var dp = []
    var fr = []

    for (var k = 0; k < m; ++k) {
        var row = []
        var rowFrom = []
        for (var i = 0; i < n; ++i) {
            row[i] = NEG
            rowFrom[i] = -1

            if (!_eq(q.charAt(k), t.charAt(i), caseSensitive)) continue

            var bonus = CHAR + (_isBoundary(t, i) ? BOUNDARY : 0)

            if (k === 0) {
                row[i] = bonus
                continue
            }

            /* 前驱 j 必须 < i。并列时保留**最小的 j**（> 而非 >=），
               于是等价对齐里取到的是下标字典序最小的那一种。 */
            var best = NEG
            var from = -1
            for (var j = 0; j < i; ++j) {
                if (dp[k - 1][j] <= NEG) continue
                var v = dp[k - 1][j] + (j === i - 1 ? CONSEC : 0)
                if (v > best) { best = v; from = j }
            }
            if (from >= 0) {
                row[i] = best + bonus
                rowFrom[i] = from
            }
        }
        dp[k] = row
        fr[k] = rowFrom
    }

    /* 末行取最优；并列同样取**最小的 i** */
    var bestI = -1
    var bestScore = NEG
    for (var last = 0; last < n; ++last) {
        if (dp[m - 1][last] > bestScore) {
            bestScore = dp[m - 1][last]
            bestI = last
        }
    }
    if (bestI < 0) return null

    /* 回溯出命中下标（升序） */
    var hits = []
    var at = bestI
    for (var back = m - 1; back >= 0; --back) {
        hits.unshift(at)
        at = fr[back][at]
    }

    return { score: bestScore, hits: hits }
}

/** 只问"匹不匹配"时的薄封装（空 query 视为匹配） */
function matches(query, text, opts) {
    return score(query, text, opts) !== null
}

/**
 * rank(query, texts, opts) → [{ index, score, hits }]
 *
 * 过滤 + 排序。**分数相同保持原下标顺序**（稳定），
 * 所以空 query 会原样返回全部条目。
 */
function rank(query, texts, opts) {
    var list = (texts === null || texts === undefined) ? [] : texts
    var out = []
    for (var i = 0; i < list.length; ++i) {
        var r = score(query, list[i], opts)
        if (r) out.push({ index: i, score: r.score, hits: r.hits })
    }
    /* 显式比较 index，而不是依赖 Array#sort 在 ES2019 起才保证的稳定性 ——
       读代码的人不该需要去查引擎版本。 */
    out.sort(function (a, b) {
        if (b.score !== a.score) return b.score - a.score
        return a.index - b.index
    })
    return out
}

/* ═══════════════════════ 对象数组的过滤（M26）═══════════════════════ */

/**
 * filterBy(query, items, opts) → [{ item, index, text, score, hits }]
 *
 * `rank` 吃的是**字符串数组**。但 `QSkinAutoComplete` / `QSkinMentions` 手上是
 * **对象数组**（`{ label, value }`）。调用方各自 map 一遍再回填是能跑的，
 * 代价是**两套下标对应关系**（排序后要记住原下标才取回对象），
 * 错一次的症状是「选中了错误的候选」—— 一个不会崩、只会选错的 bug。
 *
 * 所以把"取文本"收进 `opts.textOf`，排序仍走**同一个** `score`：
 *
 *     opts.textOf          取文本的方式。字段名字符串，或 (item) => string。
 *                          缺省 String(item)。给 null / "" 当函数用会让
 *                          取到的文本恒为 ""，于是**全都不匹配** ——
 *                          这是刻意的：写错字段名不该悄悄退化成"全量"。
 *     opts.caseSensitive   同 score
 *     opts.limit           只返回前 N 条；≤ 0 / 未给 = 不限
 *
 * 返回项带 **原下标**（`index`），调用方据此取回自己的对象 ——
 * 这是它与 `rank` 唯一的接口差别，`score` / `hits` 的语义逐字相同。
 *
 * 排序规则与 `rank` 逐字相同（分数降序、并列按原下标升序）。于是
 * **空 query 的返回值就是"全量、原序"**（全 0 分，比 index），
 * 不需要为它写一个特例分支 —— 特例分支是两份行为开始漂的地方。
 *
 * 可证伪：`tools/check-fuzzy-match.js` 的第 6 段拿**两段独立算路**交叉 ——
 * 本函数的结果必须逐项等于「`items.map(textOf)` 经 `rank` 过滤后按原下标
 * 回填」的结果。两条路只有一处共享代码（`score`），其余全是各自的。
 */
function filterBy(query, items, opts) {
    var o = opts || {}
    var list = (items === null || items === undefined) ? [] : items
    var textOf = o.textOf

    var out = []
    for (var i = 0; i < list.length; ++i) {
        var it = list[i]
        var t
        if (typeof textOf === "function") {
            t = String(textOf(it))
        } else if (typeof textOf === "string" && textOf !== "") {
            var v = (it === null || it === undefined) ? undefined : it[textOf]
            t = (v === undefined || v === null) ? "" : String(v)
        } else {
            t = (it === null || it === undefined) ? "" : String(it)
        }

        var r = score(query, t, o)
        if (r) out.push({ item: it, index: i, text: t, score: r.score, hits: r.hits })
    }

    out.sort(function (a, b) {
        if (b.score !== a.score) return b.score - a.score
        return a.index - b.index
    })

    var lim = o.limit
    if (lim !== undefined && lim !== null && lim > 0 && out.length > lim)
        out = out.slice(0, lim)

    return out
}

/* ═══════════════════════ 诊断 ═══════════════════════ */

/**
 * explain(query, text, opts) → 便于比对的多行文本
 *
 * 例：
 *     score=15  hits=[0,1]
 *     Sa  [S]earch [a]ll
 *     hit  ^^
 *
 * 门禁失败时能一眼看出"是分数不对还是命中位置不对"，成本几乎为零。
 */
function explain(query, text, opts) {
    var r = score(query, text, opts)
    var t = (text === null || text === undefined) ? "" : String(text)
    if (!r) return "score=null (不匹配)\n" + t

    var mark = ""
    var seen = {}
    for (var i = 0; i < r.hits.length; ++i) seen[r.hits[i]] = true
    var head = ""
    for (var c = 0; c < t.length; ++c) {
        if (seen[c]) { mark += "^"; head += "[" + t.charAt(c) + "]" }
        else         { mark += " "; head += t.charAt(c) }
    }
    return "score=" + r.score + "  hits=[" + r.hits.join(",") + "]\n"
           + head + "\n" + mark + "\n" + t
}

/* node 可直接 require 本文件（QML 侧看不到 module，用 typeof 保护） */
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        score: score,
        matches: matches,
        rank: rank,
        filterBy: filterBy,
        explain: explain,
        CHAR: CHAR,
        CONSEC: CONSEC,
        BOUNDARY: BOUNDARY,
        SEPARATORS: SEPARATORS
    }
}
