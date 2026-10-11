/****************************************************************************
 * QSkin · Quick Design System — Foundation / MasonryUtil
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 瀑布流列分配的 QML 入口。真正的实现在**同目录**的 `MasonryUtil.js` 里，
 * 本文件一行算法都没有 —— 它只做转发。
 *
 * ── 为什么需要一个转发层（而不是让 QSkinMasonry 直接 import 那个 .js） ──
 * 与 FuzzyMatch / ColorUtil / QRCodeEncoder 完全同源，理由见
 * FuzzyMatch.qml 文件头：QML 的 `.js` 导入只能是相对路径，而跨模块的
 * 相对路径在本仓对不上（`src/foundation` 被铺成 `QSkin/Foundation`，
 * 目录名跟着模块 URI 走）。同目录相对导入没有这个问题。
 *
 * ── 架构：一份实现，两个消费者 ───────────────────────────────────────
 *     MasonryUtil.js     ← 唯一实现（门禁用 node 直接 require 它，
 *                           再对输出验四条不变量 + 比对手推表）
 *        ↑            ↑
 *     本单例（QML）   .cache/_verify_m27.py（node）
 *
 * 契约说明全部在 `.js` 的文件头里（贪心定义、并列取最左、四条不变量、
 * 四条已知边界）—— 这里不重复，免得两处说法漂移。
 ****************************************************************************/

pragma Singleton
import QtQuick 2.11
import "MasonryUtil.js" as Impl

QtObject {
    /**
     * layout(heights, columns, gap, width) →
     *   { items, columnHeights, contentHeight, colWidth, actualColumns }
     *   items[i] = { index, col, x, y, w, h }
     */
    function layout(heights, columns, gap, width) {
        return Impl.layout(heights, columns, gap, width)
    }

    /** 列数自动：列宽不小于 minColumnWidth 时最多几列（至少 1） */
    function columnsFor(width, minColumnWidth, gap) {
        return Impl.columnsFor(width, minColumnWidth, gap)
    }
}
