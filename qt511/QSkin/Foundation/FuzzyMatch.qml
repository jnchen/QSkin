/****************************************************************************
 * QSkin · Quick Design System — Foundation / FuzzyMatch
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 模糊匹配打分器的 QML 入口。真正的实现在**同目录**的 `FuzzyMatch.js` 里，
 * 本文件一行算法都没有 —— 它只做转发。
 *
 * ── 为什么需要一个转发层（而不是让 QSkinCommand 直接 import 那个 .js） ──
 * 与 QRCodeEncoder.qml 完全同源，理由见那份文件头：QML 的 `.js` 导入只能是
 * 相对路径，而跨模块的相对路径在本仓对不上（`src/foundation` 被铺成
 * `QSkin/Foundation`，目录名跟着模块 URI 走）。从 `QSkin/Contracts/QSkinCommand.qml`
 * 往上写 `../foundation/…` 在 Windows 上因为大小写不敏感**恰好能跑**，
 * 到 Linux 就断 —— 这种"开发机上永远发现不了"的路径不该进源码。
 *
 * 同目录相对导入（`import "FuzzyMatch.js"`）没有这个问题。
 *
 * ── 架构：一份实现，两个消费者 ───────────────────────────────────────
 *     FuzzyMatch.js      ← 唯一实现（门禁用 node 直接 require 它，
 *                          再用**穷举**所有合法对齐做独立算路比对）
 *        ↑            ↑
 *     本单例（QML）   .cache/_verify_m25.py（node）
 *
 * 契约说明全部在 `.js` 的文件头里（打分常量、并列取最左、空查询语义、
 * UTF-16 码元下标这条已知边界）—— 这里不重复，免得两处说法漂移。
 ****************************************************************************/

pragma Singleton
import QtQuick 2.11
import "FuzzyMatch.js" as Impl

QtObject {
    /**
     * score(query, text, opts) → { score, hits } | null
     *   opts.caseSensitive 缺省 false
     *   null = 不匹配；空 query 返回 { score: 0, hits: [] }
     */
    function score(query, text, opts) {
        return Impl.score(query, text, opts)
    }

    /** 只问"匹不匹配" */
    function matches(query, text, opts) {
        return Impl.matches(query, text, opts)
    }

    /** 过滤 + 稳定排序（分数相同保持原序） */
    function rank(query, texts, opts) {
        return Impl.rank(query, texts, opts)
    }

    /**
     * 对象数组的过滤：filterBy(query, items, opts) →
     *   [{ item, index, text, score, hits }]
     *   opts.textOf  取文本的方式（字段名 / 函数 / 缺省 String(item)）
     *   opts.limit   只取前 N 条
     * 返回项带**原下标**，调用方据此取回自己的对象。
     * 语义与 rank 的差别只有这一条（rank 只吃字符串数组），排序规则相同。
     */
    function filterBy(query, items, opts) {
        return Impl.filterBy(query, items, opts)
    }

    /** 诊断用：把对齐画成 ^ 与 [] */
    function explain(query, text, opts) {
        return Impl.explain(query, text, opts)
    }

    /* 三个打分常量暴露出来，是为了让冒烟测试与像素核验**读同一个数** ——
       否则"高亮该有多宽"这类判据会在两侧各写一份魔数。 */
    readonly property int charBonus:     Impl.CHAR
    readonly property int consecBonus:   Impl.CONSEC
    readonly property int boundaryBonus: Impl.BOUNDARY
}
