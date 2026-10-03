/****************************************************************************
 * QSkin · 模糊匹配门禁（M25.1 起）—— FuzzyMatch 的独立算路交叉验证
 *
 * 被测对象 = src/foundation/FuzzyMatch.js（DP 求最优对齐）
 * 参照实现 = **本文件里的穷举**（枚举所有 C(n,m) 种下标组合，按定义算分，
 *            取最大；并列取下标字典序最小）
 *
 * 用法：
 *     node tools/check-fuzzy-match.js
 * 退出码 0 = 全绿。
 *
 * 一般不用直接调 —— ./tools/test.sh 会自动带上这一步。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么它必须住在 tools/ 而不是 .cache/
 * ════════════════════════════════════════════════════════════════════════
 * 它最初是 `.cache/_m25fuzzy_probe.js` —— 一个住在**可丢弃目录**里的闸。
 * 本仓对这件事有一条既有判据（M23 升格 comprehension 闸时记下的原话）：
 *
 *     **一个住在可丢弃目录里的闸不算闸。**
 *
 * `tools/clean-cache.sh --all` 一次就把它清掉了，而清掉之后：
 *   · `FuzzyMatch.js` 失去唯一会独立算路的裁判；
 *   · `smoke_m25.qml` 的 [1] 仍然绿 —— 它读的是**控件**认为的分数，
 *     而"控件认为的"与"算出来的"一致，什么也证明不了；
 *   · 更糟的是**没有人会发现**：没有哪个门禁会报"我的裁判不见了"。
 *
 * 而且它有一个 M25 里独一份的性质：**它是唯一不需要 Qt 的闸**。
 * 没有 qml.exe、没有 import 树、没有首帧 —— 一条 `node` 就跑完。
 * 这种闸放在可丢弃目录里是最亏的。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么参照实现自己抄一遍常量，而不是 require 过来
 * ════════════════════════════════════════════════════════════════════════
 * 因为要能抓住"常量被改坏"。若两边共用同一组常量对象，把 CHAR 从 1 改成 2
 * 两边会**一起**变，判据静默失灵（本项目原话：「量法不能与被测量共享
 * 硬编码假设」）。这里的 1 / 8 / 6 与分隔符表都是从文件头的规则**另抄一份**
 * 的 —— 抄错就是红，正是想要的效果。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 三段判据，以及每一段在防什么
 * ════════════════════════════════════════════════════════════════════════
 *
 *   ① 手写用例（17 条）—— 每条都写清楚**期望从哪来**。防的是"常识级的
 *      规则被改动"（空 query、长短、大小写、驼峰、中文）。
 *
 *   ② 随机穷举（300 条，固定种子）—— text 最长 12，**枚举所有 C(n,m) 种
 *      对齐**。防的是"手写用例想不到的组合"。种子与字母表都打印出来，
 *      因为"同一个种子"这件事本身要有前提（见下面的 LCG 注释）。
 *
 *   ③ 序列化接口的一致性（M25.1 升格时补的，原本缺）：
 *      · `matches()` 必须与 `score() !== null` 在**每一条**用例上一致
 *        —— 它是薄封装，但薄封装也会与本体走岔（判 null 的写法改了而
 *        本体没改）。这条的覆盖面就是上面全部的 317 条用例，成本为零。
 *      · `SEPARATORS` 必须与参照表**逐字符相等**。为什么不能只靠 ①②：
 *        字母表 "abcABC_ x" 里只有 `_` 与空格，把 `-` 或 `.` 从分隔符表里
 *        悄悄删掉，①②一条都不会红 —— 而那会让 "open-file" 这类条目的
 *        `o` 与 `f` 都不再算词首，分数整体变化却没有判据看得见。
 *      · `explain()` 的输出必须**同时**含分数与命中下标（它是给人读的
 *        诊断通道；诊断通道说谎比没有更坏）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 怎么证伪这道闸
 * ════════════════════════════════════════════════════════════════════════
 * 见 `.cache/mutate_m25_data.py` 的 `--fuzzy` 那一段：CHAR/CONSEC/BOUNDARY
 * 三个常量各打一枪、并列取最左打一枪、空 query 打一枪、驼峰边界打一枪、
 * 分隔符表打一枪、rank 稳定性打一枪、`matches()` 打一枪。
 * 每一枪都声明**预期红的段**，实测面不符就报出来。
 ****************************************************************************/

"use strict"

var path = require("path")
var SRC = path.join(__dirname, "..", "src", "foundation", "FuzzyMatch.js")
var FM = require(SRC)

/* ── 参照侧常量（**另一份**，故意不共享） ── */
var R_CHAR = 1
var R_CONSEC = 8
var R_BOUNDARY = 6
var R_SEP = " \t\n\r-_/\\.:,;|·、，。：；！？（）()[]{}<>#@+*&=%$^~`\"'"

function rIsSep(ch) { return ch !== "" && R_SEP.indexOf(ch) >= 0 }
function rIsLower(ch) { return ch >= "a" && ch <= "z" }
function rIsUpper(ch) { return ch >= "A" && ch <= "Z" }
function rIsBoundary(t, i) {
    if (i === 0) return true
    var prev = t.charAt(i - 1)
    if (rIsSep(prev)) return true
    return rIsLower(prev) && rIsUpper(t.charAt(i))
}
function rEq(a, b, cs) {
    if (a === b) return true
    if (cs) return false
    return a.toLowerCase() === b.toLowerCase()
}

/** 下标序列的字典序比较：a 是否小于 b */
function lexLess(a, b) {
    for (var i = 0; i < a.length; ++i) {
        if (a[i] !== b[i]) return a[i] < b[i]
    }
    return false
}

/**
 * 穷举最优：枚举所有 size=m 的升序下标组合，
 * 过滤出真匹配的，按**定义**算分，取最大；并列取字典序最小的下标序列。
 */
function brute(q, t, cs) {
    var n = t.length, m = q.length
    if (m === 0) return { score: 0, hits: [] }
    if (m > n) return null

    var best = null
    var idx = new Array(m)

    function rec(start, depth) {
        if (depth === m) {
            for (var k = 0; k < m; ++k) {
                if (!rEq(q.charAt(k), t.charAt(idx[k]), cs)) return
            }
            var s = 0
            for (var k2 = 0; k2 < m; ++k2) {
                s += R_CHAR
                if (k2 > 0 && idx[k2] === idx[k2 - 1] + 1) s += R_CONSEC
                if (rIsBoundary(t, idx[k2])) s += R_BOUNDARY
            }
            if (best === null || s > best.score
                || (s === best.score && lexLess(idx, best.hits))) {
                best = { score: s, hits: idx.slice() }
            }
            return
        }
        for (var i = start; i < n; ++i) {
            idx[depth] = i
            rec(i + 1, depth + 1)
        }
    }
    rec(0, 0)
    return best
}

/* ═══════════════════════ 用例 ═══════════════════════ */

/* 一组手写的边界用例 —— 每条都写清楚**期望从哪来** */
var CASES = [
    /* [query, text, caseSensitive, 说明] */
    ["", "anything", false, "空 query：全量、0 分、零命中"],
    ["a", "abc", false, "词首单字符：1 + 6"],
    ["ab", "aab", false, "并列对齐取最左（0,1 连续优于 1,2）"],
    ["ab", "ab_ab", false, "真并列：两处都是 16 分，取下标更小的"],
    ["abc", "a_b_c", false, "全词首：7+7+7"],
    ["zz", "abc", false, "不匹配 → null"],
    ["abcd", "abc", false, "query 比 text 长 → null"],
    ["北", "北京", false, "中文单字"],
    ["北京", "中国北京", false, "中文双字（连续命中）"],
    ["sa", "searchAll", false, "驼峰边界（A 算词首，且不连续）"],
    ["se", "searchAll", false, "驼峰内连续"],
    ["S", "search", true, "大小写敏感 → 不匹配"],
    ["a", "A", false, "大小写不敏感"],
    ["a", "A", true, "同上，敏感 → 不匹配"],
    ["1", "item1", false, "数字"],
    ["se", "SEARCH", false, "全大写（无驼峰，无词首加成）"],
    ["", "", false, "空 + 空"],
    ["a", "", false, "text 空 → null"],
]

var pass = 0
var caseFail = 0      /* 只数手写用例的失败 —— `fail` 是全文件的失败计数，
                       * 用它来标"手写用例 ✓/✗"会把别的段的红算到手写头上 */
var fail = 0
var MAXN = 12   /* 穷举规模上限：C(12,6)=924，够快 */

/* ── 为什么失败行要带一个**段名** ─────────────────────────────────────
 * 与 tests/smoke_*.qml 的 `✗ [n]` 同一种处置，理由也一样：
 * **"错了"与"错在哪一段"是两种信息**，后者必须能被机器解析。
 * `.cache/mutate_m25_data.py` 靠这个段名判断"这一枪的辐射面"是不是
 * 与我声明的一致 —— 如果失败行只有自由文本，它就只能去 grep 关键词，
 * 而那正是本仓在 test.sh 文件头里否决过的做法。
 *
 * 段名只有五个：手写 / 随机 / rank / matches / 常量表。 */
var SECTIONS = ["手写", "随机", "rank", "matches", "常量表", "filter"]

function report(sec, tag, detail) {
    fail++
    /* 自校验：段名必须来自那张表。打错一个段名（比如 `rank` 写成 `Rank`）
     * 会让变异脚本的"辐射面"比对静默失真 —— 它只会看到"一个不认识的组"，
     * 而那正是本仓最想避免的"看起来有结构、其实没约束"。 */
    if (SECTIONS.indexOf(sec) < 0) {
        console.log("  !! 段名 `" + sec + "` 不在 SECTIONS 里 —— 本文件的判据组织坏了")
    }
    console.log("  ✗ [" + sec + "] " + tag)
    console.log("    " + detail)
}

console.log("==> 被测：" + SRC)
console.log("==> 基线自检：DP 与穷举必须逐例一致")
console.log("")

/* 每一例都同时验三样：score / hits / matches() 的一致性。
 * `matchesOk` 单独累计 —— 它红了与分数红是两种病：前者是"薄封装与本体
 * 走岔"，后者是"打分本身错了"，报告要能分开。 */
var matchesPass = 0
var matchesFail = 0

for (var i = 0; i < CASES.length; ++i) {
    var q = CASES[i][0], t = CASES[i][1], cs = CASES[i][2], why = CASES[i][3]
    var opts = { caseSensitive: cs }
    var got = FM.score(q, t, opts)
    var exp = brute(q, t, cs)

    var tag = "[手写 " + i + "] q=" + JSON.stringify(q) + " t=" + JSON.stringify(t)
              + (cs ? " (cs)" : "") + " —— " + why

    var bad = false
    if (exp === null) {
        if (got !== null) { report("手写", tag, "期望 null（不匹配），得到 " + JSON.stringify(got)); bad = true }
    } else {
        if (got === null) { report("手写", tag, "期望 " + JSON.stringify(exp) + "，得到 null"); bad = true }
        else if (got.score !== exp.score) {
            report("手写", tag, "分数：期望 " + exp.score + "，得到 " + got.score
                        + "\n    " + FM.explain(q, t, opts).split("\n").join("\n    "))
            bad = true
        } else if (got.hits.join(",") !== exp.hits.join(",")) {
            report("手写", tag, "命中下标：期望 [" + exp.hits + "]，得到 [" + got.hits + "]")
            bad = true
        }
    }
    if (!bad) pass++
    else caseFail++

    /* `matches()` 与**本体**的一致性：判据就是定义，不需要第三份期望。
     *
     * ⚠ 首版这里比的是 `exp`（穷举的结果），而不是 `got`（本体）。
     *   那等于把"score 与穷举一致"又测了一遍 —— 于是**任何**能让分数走岔的
     *   变异都会连带把这一段点红，而头里承诺的却是"薄封装与本体走岔"。
     *   两种写法都"有牙"，但只有比本体这一种**只**抓薄封装，
     *   所以 [matches] 段才有资格单独成立（见文件头第三段）。
     *   抓出这件事的是 `.cache/mutate_m25_data.py` 的 F10：它的实测面里
     *   多出了一个 `matches` —— 顺着查下来是判据写错了对象。 */
    var wantsMatch = (got !== null)
    if (FM.matches(q, t, opts) === wantsMatch) matchesPass++
    else {
        matchesFail++
        report("matches", "[手写 " + i + "] q=" + JSON.stringify(q) + " t=" + JSON.stringify(t),
               "score() 给出 " + (wantsMatch ? "匹配" : "不匹配")
               + "，而 matches() 说 " + (FM.matches(q, t, opts) ? "匹配" : "不匹配")
               + " —— 薄封装与本体走岔了")
    }
}

/* ── 随机模糊测试：短串穷举，覆盖手写用例想不到的组合 ── */
var ALPHABET = "abcABC_ x"
/* 最小标准 LCG（Park–Miller）。乘数 16807 与模 2^31-1 保证中间积
 * < 2^53，全程**整数精确** —— 换个更大的乘数就会掉进浮点精度里，
 * 于是"同一个种子"在别的引擎上可能给出不同的串。
 *
 * ⚠ 字母表刻意只含 `_` 与空格两种分隔符。所以**它抓不到"某个分隔符被
 *   从表里删掉"**（`-` / `.` / `,` 等一个都不在语料里）—— 那由下面
 *   第三段的表比较负责。两段是互补的，不能拿掉任何一段。 */
var rng = 20260915
function nextRand(mod) {
    rng = (rng * 16807) % 2147483647
    return rng % mod
}

var RAND_N = 300
var randPass = 0
var randFail = 0
for (var r = 0; r < RAND_N; ++r) {
    var tn = 1 + nextRand(MAXN)
    var tt = ""
    for (var c = 0; c < tn; ++c) tt += ALPHABET.charAt(nextRand(ALPHABET.length))
    var qn = nextRand(5)
    var qq = ""
    for (var c2 = 0; c2 < qn; ++c2) qq += ALPHABET.charAt(nextRand(ALPHABET.length))

    var o2 = { caseSensitive: false }
    var g2 = FM.score(qq, tt, o2)
    var e2 = brute(qq, tt, false)

    if (e2 === null) {
        if (g2 !== null) { randFail++; report("随机", "[" + r + "]", JSON.stringify(qq) + " / " + JSON.stringify(tt) + " 期望 null，得到 " + JSON.stringify(g2)); continue }
    } else {
        if (g2 === null) { randFail++; report("随机", "[" + r + "]", JSON.stringify(qq) + " / " + JSON.stringify(tt) + " 期望非 null，得到 null"); continue }
        if (g2.score !== e2.score || g2.hits.join(",") !== e2.hits.join(",")) {
            randFail++
            report("随机", "[" + r + "]", JSON.stringify(qq) + " / " + JSON.stringify(tt)
                   + " 期望 " + e2.score + "[" + e2.hits + "]，得到 " + g2.score + "[" + g2.hits + "]")
            continue
        }
    }
    if (FM.matches(qq, tt, o2) === (g2 !== null)) matchesPass++
    else {
        matchesFail++
        report("matches", "[随机 " + r + "] " + JSON.stringify(qq) + " / " + JSON.stringify(tt),
               "matches() 与 score() 不一致")
    }
    randPass++
}

/* ── rank 的稳定性：分数相同必须保持声明序 ── */
var rankPass = 0
var rankFail = 0
var texts = ["zzz", "ab", "aab", "ab", "yyy", "ba"]
var ranked = FM.rank("ab", texts)
/* 现场算一遍期望，而不是写死 —— 写死的期望会与实现一起过期 */
var scored = []
for (var s = 0; s < texts.length; ++s) {
    var rs = FM.score("ab", texts[s])
    if (rs) scored.push({ i: s, v: rs.score })
}
scored.sort(function (a, b) { return b.v - a.v || a.i - b.i })
var wantIdx = scored.map(function (o) { return o.i }).join(",")
var gotIdx = ranked.map(function (o) { return o.index }).join(",")
if (wantIdx === gotIdx) rankPass++
else { rankFail++; report("rank", "[稳定性]", "期望顺序 [" + wantIdx + "]，得到 [" + gotIdx + "]") }

/* 空 query 的 rank 必须原样返回全部、且保持原序 */
var allRank = FM.rank("", texts)
var allIdx = allRank.map(function (o) { return o.index }).join(",")
if (allIdx === "0,1,2,3,4,5" && allRank.length === texts.length) rankPass++
else { rankFail++; report("rank", "[空 query]", "期望 [0,1,2,3,4,5] 共 6 条，得到 [" + allIdx + "] 共 " + allRank.length + " 条") }

/* ── 第三段：常量表与诊断通道（M25.1 升格时补的） ── */
var tablePass = 0
var tableFail = 0

if (FM.SEPARATORS === R_SEP) tablePass++
else {
    tableFail++
    var missing = ""
    for (var mi = 0; mi < R_SEP.length; ++mi) {
        if (FM.SEPARATORS.indexOf(R_SEP.charAt(mi)) < 0) missing += JSON.stringify(R_SEP.charAt(mi)) + " "
    }
    report("常量表", "[分隔符表]", "与参照表不相等。参照有而 FM.SEPARATORS 缺的字符：" + (missing || "（无 —— 是多了字符或顺序不同）")
           + "\n    参照长度 " + R_SEP.length + "，被测长度 " + FM.SEPARATORS.length)
}

if (FM.CHAR === R_CHAR && FM.CONSEC === R_CONSEC && FM.BOUNDARY === R_BOUNDARY) tablePass++
else {
    tableFail++
    report("常量表", "[打分常量]", "期望 CHAR=" + R_CHAR + " CONSEC=" + R_CONSEC + " BOUNDARY=" + R_BOUNDARY
           + "，得到 CHAR=" + FM.CHAR + " CONSEC=" + FM.CONSEC + " BOUNDARY=" + FM.BOUNDARY
           + "\n    （分数全谱已经对过穷举，所以这条红了多半意味着常量与穷举共享了同一个错值）")
}

/* explain()：给人读的诊断通道 —— 必须同时含分数与命中下标。
 * 用一条**必然命中**的样例（否则 "score=null" 那条分支也会过，
 * 而它并不含 hits）。
 *
 * ⚠ 期望值 14 是这样来的（不是猜的）：`a` 在下标 0 → 词首，7；
 *   `b` 在下标 2，前一个字符是 `_`（分隔符）→ 也算词首，7；合计 14。
 *   首版我写的是 15（凭"a 词首 + b 词首 = 7+7"之外的记忆多加了 1），
 *   当场被这条断言自己抓红 —— 期望值必须是**现场推的**，不是记的。 */
var ex = FM.explain("ab", "a_b", null)
if (ex.indexOf("score=14") >= 0 && ex.indexOf("hits=[0,2]") >= 0) tablePass++
else {
    tableFail++
    report("常量表", "[explain 输出]", "期望含 `score=14` 与 `hits=[0,2]`，实际输出：\n    "
           + ex.split("\n").join("\n    "))
}

/* matches() 对空 query 的语义：视为**匹配**（与 score 的 0 分一致）。
 * 单独钉一条，因为它是"过滤全量"那条语义的唯一入口。 */
if (FM.matches("", "anything") === true && FM.matches("", "") === true) tablePass++
else {
    tableFail++
    report("常量表", "[matches 空 query]", "空 query 必须视为匹配（cmdk / Ant Select 的语义：空输入 = 全量）；"
           + "得到 matches(\"\",\"anything\")=" + FM.matches("", "anything")
           + " matches(\"\",\"\")=" + FM.matches("", ""))
}

/* ═══════════════════════ [filter] 对象数组的过滤（M26） ═══════════════════════ */

/* `filterBy` 的判据不能是"再写一遍期望" —— 那只是把同一份逻辑抄第二遍，
 * 两边一起错就一起过。用**两段独立算路交叉**：
 *
 *     A 路：FM.filterBy(q, items, { textOf: "label" })
 *     B 路：items.map(label) → FM.rank(q, texts) → 按返回的 index 回填对象
 *
 * 两条路只有一处共享代码（`score`），其余（取字段、回填、下标对应）全是
 * 各自的。任何一条算错了都会在结果上分叉。
 *
 * 另有四条判据钉住 JS 文件头里写下的**刻意语义**，它们不能用交叉验证
 * 替代（因为它们是接口约定，不是计算结果）：
 *   · 字段名写错 → 0 项（**不许悄悄退化成"全量"**）
 *   · `index` 是**原下标**，不是排序后位置（这正是 filterBy 存在的理由）
 *   · `item` 与原对象**同一引用**（调用方要拿回去用）
 *   · 缺省 `String(item)` 与 `rank` 的关系
 */
var filterN = 0, filterPass = 0, filterFail = 0

;(function () {
    var ITEMS = [
        { label: "Alpha Beta", value: 1 },
        { label: "alpha", value: 2 },
        { label: "Beta Gamma", value: 3 },
        { label: "gamma delta", value: 4 },
        { label: "ab", value: 5 },
        { label: "", value: 6 },
        { label: null, value: 7 },
        "plain string",
        { label: "ALPHA-beta", value: 9 }
    ]
    var QUERIES = ["", "a", "ab", "al", "beta", "g", "zz", "AB", "  ", "delta", "alphabeta"]

    function textOfLabel(it) {
        var v = (it === null || it === undefined) ? undefined : it.label
        return (v === undefined || v === null) ? "" : String(v)
    }

    /* ── 判据 1：两段算路逐项一致 ── */
    QUERIES.forEach(function (q) {
        filterN++
        var a = FM.filterBy(q, ITEMS, { textOf: "label" })

        var texts = ITEMS.map(textOfLabel)
        var b = FM.rank(q, texts).map(function (r) {
            return { item: ITEMS[r.index], index: r.index, text: texts[r.index],
                     score: r.score, hits: r.hits }
        })

        var same = (a.length === b.length)
        if (same) {
            for (var i = 0; i < a.length; ++i) {
                if (a[i].index !== b[i].index || a[i].score !== b[i].score
                    || a[i].text !== b[i].text
                    || a[i].hits.join(",") !== b[i].hits.join(",")) {
                    same = false
                    break
                }
            }
        }

        if (same) filterPass++
        else {
            filterFail++
            var da = a.map(function (x) { return x.index + ":" + x.score }).join(" ")
            var db = b.map(function (x) { return x.index + ":" + x.score }).join(" ")
            report("filter", "[两段算路交叉] q=" + JSON.stringify(q),
                   "A 路 " + a.length + " 项 [" + da + "] ／ B 路 " + b.length + " 项 [" + db + "]")
        }
    })

    /* ── 判据 2：字段名写错必须给 0 项，**不许**退化成"全量" ── */
    filterN++
    var typo = FM.filterBy("ab", ITEMS, { textOf: "labl" })
    var nullField = FM.filterBy("ab", ITEMS, { textOf: null })
    if (typo.length === 0 && nullField.length === 0) filterPass++
    else {
        filterFail++
        report("filter", "[字段名写错 → 0 项]",
               "textOf:\"labl\" 得到 " + typo.length + " 项、textOf:null 得到 " + nullField.length
               + " 项，都必须为 0 —— 写错字段名悄悄变成「全量」是最坏的失败形态"
               + "（列表看着正常、结果全错）")
    }

    /* ── 判据 3：`index` 是**原下标** ──
     * 用一份"排序后位置 ≠ 原下标"的数据：能匹配的那条在**末尾**。
     * 若实现把排序后的位置当 index 返回，这里会读到 0。 */
    filterN++
    var ORDERED = ["zzz", "yyy", "the ab"]
    var got = FM.filterBy("ab", ORDERED, {})
    if (got.length === 1 && got[0].index === 2 && got[0].text === "the ab") filterPass++
    else {
        filterFail++
        report("filter", "[index 是原下标]",
               "filterBy(\"ab\", [\"zzz\",\"yyy\",\"the ab\"]) 应当返回 1 项且 index=2，实测 "
               + JSON.stringify(got.map(function (x) { return { index: x.index, text: x.text } })))
    }

    /* ── 判据 4：`item` 与原对象同一引用（=== 而不是"长得一样"） ── */
    filterN++
    var OBJS = [{ label: "ab" }, { label: "zz" }]
    var ref = FM.filterBy("ab", OBJS, { textOf: "label" })
    if (ref.length === 1 && ref[0].item === OBJS[0]) filterPass++
    else {
        filterFail++
        report("filter", "[item 是原引用]", "返回项的 item 必须与传入的同一对象（===）；"
               + "实测 " + (ref.length === 1 ? "item === OBJS[0] 为 " + (ref[0].item === OBJS[0]) : "长度 " + ref.length))
    }

    /* ── 判据 5：缺省 `String(item)` 与 `rank` 一致（字符串数组上两者同构） ── */
    filterN++
    var LIT = ["alpha", "beta", "zz", "ab"]
    var byDefault = FM.filterBy("ab", LIT, {})
    var byRank = FM.rank("ab", LIT)
    var sameIdx = (byDefault.length === byRank.length)
    if (sameIdx) {
        for (var k = 0; k < byDefault.length; ++k) {
            if (byDefault[k].index !== byRank[k].index || byDefault[k].score !== byRank[k].score) {
                sameIdx = false
                break
            }
        }
    }
    if (sameIdx) filterPass++
    else {
        filterFail++
        report("filter", "[缺省 String(item) = rank]",
               "filterBy(q, 字符串数组) 不带 textOf 时应当与 rank 同序同分："
               + "filterBy 得 [" + byDefault.map(function (x) { return x.index + ":" + x.score }).join(" ")
               + "]，rank 得 [" + byRank.map(function (x) { return x.index + ":" + x.score }).join(" ") + "]")
    }

    /* ── 判据 6：`limit` ── */
    filterN++
    var all = FM.filterBy("a", ITEMS, { textOf: "label" })
    var lim = FM.filterBy("a", ITEMS, { textOf: "label", limit: 2 })
    var lim0 = FM.filterBy("a", ITEMS, { textOf: "label", limit: 0 })
    if (lim.length === Math.min(2, all.length) && lim0.length === all.length) filterPass++
    else {
        filterFail++
        report("filter", "[limit]",
               "limit:2 得 " + lim.length + " 项（全量 " + all.length + "）、limit:0 得 "
               + lim0.length + " 项（0 / 负数 / 未给都表示不限）")
    }

    /* ── 判据 7：`textOf` 给函数 与 给字段名 等价 ── */
    filterN++
    var byFn  = FM.filterBy("beta", ITEMS, { textOf: textOfLabel })
    var byStr = FM.filterBy("beta", ITEMS, { textOf: "label" })
    var sameFn = (byFn.length === byStr.length)
    if (sameFn) {
        for (var m = 0; m < byFn.length; ++m) {
            if (byFn[m].index !== byStr[m].index || byFn[m].score !== byStr[m].score) {
                sameFn = false
                break
            }
        }
    }
    if (sameFn) filterPass++
    else {
        filterFail++
        report("filter", "[函数与字段名等价]",
               "textOf 给函数与给字段名必须同结果；实测 "
               + byFn.map(function (x) { return x.index }).join(",") + " vs "
               + byStr.map(function (x) { return x.index }).join(","))
    }
})()

/* ═══════════════════════ 结论 ═══════════════════════ */

console.log("")
console.log("手写用例   " + pass + " / " + CASES.length
            + (caseFail ? "   ✗" : "   ✓"))
console.log("随机穷举   " + randPass + " / " + RAND_N
            + (randFail ? "   ✗" : "   ✓") + "   (种子 20260915，字母表 \""
            + ALPHABET + "\"，最长 text " + MAXN + ")")
console.log("rank       " + rankPass + " / 2" + (rankFail ? "   ✗" : "   ✓"))
console.log("matches    " + matchesPass + " 条一致"
            + (matchesFail ? "   ✗ 有 " + matchesFail + " 条不一致" : "   ✓"))
console.log("常量表     " + tablePass + " / 4" + (tableFail ? "   ✗" : "   ✓"))
console.log("filter     " + filterPass + " / " + filterN + (filterFail ? "   ✗" : "   ✓")
            + "   (对象数组：两段独立算路交叉 + 接口约定)")
console.log("")

if (fail || randFail || rankFail || matchesFail || tableFail || filterFail) {
    console.log("FUZZY_FAIL")
    process.exit(1)
}
console.log("FUZZY_OK")
