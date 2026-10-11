/****************************************************************************
 * QSkin · Quick Design System — Foundation
 * 瀑布流（Masonry）的列分配
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 输入一串高度与列数，输出每一项落在**哪一列、什么坐标**，以及总高。
 * 它不画一笔 —— 画是 Contracts 层 QSkinMasonry 的事。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么这是一个 `.js` 而不是 QML 控件里的私有函数
 * ════════════════════════════════════════════════════════════════════════
 * 与 ScrollUtil / FuzzyMatch / ColorUtil 同源：**要能被独立算路打**。
 *
 * 分配结果全是整数（在列宽可整除的输入上），所以门禁可以：
 *   ① 用 node 直接 require 这一个文件，拿 items / columnHeights / 总高；
 *   ② 对输出验**四条不变量**（见下），而**不重跑**分配算法；
 *   ③ 对一组确认的输入，与**手推**的 (col, x, y) 表逐项比对。
 *
 * ② 是关键：如果核验器"自己再跑一遍同一个贪心"，那两边一致只能说明
 * "没有随机性"，什么也没证明。从**输出**反推性质才是有信息量的。
 * 住在 `.js` 之后，`QSkinMasonry` 与核验器是同一份源码的两个消费者。
 *
 * 所以本文件刻意**不写 `.pragma library`** —— 那条指令是 QML 专有的，
 * node 会当作语法错误（与 FuzzyMatch.js 同一条）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 算法（全部整数运算，所以断言可以写等号）
 * ════════════════════════════════════════════════════════════════════════
 *
 * 逐项处理，每项落进**当前最矮的列**；并列时取**最左**那一列。
 * 这是一条贪心，不是全局最优 —— 本项目不假装它最优（见"已知边界"）。
 *
 * 为什么要把"并列取最左"写进文件头而不是留在代码里：它**不影响总高**，
 * 只影响像素位置。这正是"属性值对、界面画错"最喜欢的藏身处 ——
 * 把它提成一条可证伪的判据（不变量 2），它才不再是注释。
 *
 * 末项之后**不留缝**：总高 = 最长列的底边，不是 `colHeights` 里那个
 * 含尾巴缝的值。否则容器底部会多出 `gap` 那么高的空白，而"看起来只是
 * 多了一点 padding"。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 四条不变量（门禁拿它们当判据）
 * ════════════════════════════════════════════════════════════════════════
 *
 *   I1  **y 的一致性**：每项的 `y` == 同列中**所有 index 更小**的项的高度
 *       之和 + 那些项的数量 × gap。（从输出反推，不重跑贪心。）
 *   I2  **落列规则**：对每项 i，令 `colHeightAt(i, c)` = 只累加 col==c
 *       且 index<i 的项；则 `items[i].col` 必须是使 `colHeightAt(i, ·)`
 *       取最小值的**最左**列。（同样只用输出里的 col/index。）
 *   I3  **总高**：`contentHeight` == `max(y + h)`，且**不含**末项的尾巴缝。
 *   I4  **不重叠**：任意两项的矩形不相交。
 *
 * I2 与 I4 一起才说明"贪心真的在跑"：I4 单独可以被"所有项都塞进第一列"
 * 满足（只要项不重叠），I2 单独可以被"每项轮着换列"满足。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 已知边界（写出来，不假装没有）
 * ════════════════════════════════════════════════════════════════════════
 *
 * 1. **贪心不是最优**。存在分配使"最高列更矮"，但那要全局搜索；
 *    瀑布流的语义（内容按声明序、从上往下铺）决定了贪心是对的形态。
 *    所以门禁**不断言**"没有更好的分配"—— 那是一件做不到的事。
 * 2. **非法高度按 0 处理，但项不丢**。`null` / `NaN` / 负数 → 高度 0，
 *    `items.length` 恒等于输入长度。丢掉一项会让调用方的下标对应关系
 *    整体错位，那比高度为 0 难查得多。
 * 3. **列宽不取整**。`colWidth = (width - gap*(columns-1)) / columns`，
 *    是精确的除法结果。取整会让最后一列右边多出余数宽的空隙，而
 *    "为什么右边空一条"在像素图上很难归因。断言请挑能整除的输入。
 * 4. **`columns < 1` 退化成空布局**（不是"按 1 列"）：`columns` 是调用方
 *    算出来的，能算出 0 就说明它没算 —— 假装成 1 列会把调用方的错掩掉。
 ****************************************************************************/

/** 高度归一：非有限数 / 负数 → 0 */
function _h(v) {
    var n = Number(v)
    if (!isFinite(n) || n < 0) return 0
    return n
}

/** 缝宽归一：非有限数 / 负数 → 0；小数向下取整 */
function _gap(v) {
    var n = Number(v)
    if (!isFinite(n) || n < 0) return 0
    return Math.floor(n)
}

/**
 * layout(heights, columns, gap, width) →
 *   { items, columnHeights, contentHeight, colWidth, actualColumns }
 *
 *   items[i] = { index, col, x, y, w, h }
 *   columnHeights[c] = 该列**含末项尾巴缝**的累加高度（见 I3 的说明）
 */
function layout(heights, columns, gap, width) {
    var hs = (heights === null || heights === undefined) ? [] : heights
    var g = _gap(gap)
    var w = Number(width)
    if (!isFinite(w) || w < 0) w = 0

    var cols = Math.floor(Number(columns))
    if (!isFinite(cols) || cols < 1) {
        return { items: [], columnHeights: [], contentHeight: 0,
                 colWidth: 0, actualColumns: 0 }
    }

    var colWidth = (w - g * (cols - 1)) / cols
    if (colWidth < 0) colWidth = 0

    var colH = []
    for (var c = 0; c < cols; ++c) colH.push(0)

    var items = []
    for (var i = 0; i < hs.length; ++i) {
        /* 最矮列。**只比较 `<`** —— 先出现的列在并列时留下，
         * 这就是"并列取最左"的全部实现（不变量 I2 守着它）。 */
        var best = 0
        for (var k = 1; k < cols; ++k) if (colH[k] < colH[best]) best = k

        var h = _h(hs[i])
        items.push({ index: i, col: best,
                     x: best * (colWidth + g), y: colH[best],
                     w: colWidth, h: h })
        colH[best] += h + g
    }

    /* 底边：最长列**去掉尾巴那道缝**。cols>=1 时 colH 非空。 */
    var contentHeight = 0
    for (var m = 0; m < cols; ++m) if (colH[m] > contentHeight) contentHeight = colH[m]
    if (items.length > 0) contentHeight -= g

    return { items: items, columnHeights: colH, contentHeight: contentHeight,
             colWidth: colWidth, actualColumns: cols }
}

/**
 * columnsFor(width, minColumnWidth, gap) → 能放下几列（至少 1）
 *
 * 给"列数自动"用：列宽不小于 minColumnWidth 的前提下最多几列。
 * 解 `n*minW + (n-1)*gap <= width` → `n <= (width+gap)/(minW+gap)`。
 */
function columnsFor(width, minColumnWidth, gap) {
    var w = Number(width)
    var mw = Number(minColumnWidth)
    var g = _gap(gap)
    if (!isFinite(w) || !isFinite(mw) || mw <= 0 || w <= 0) return 1
    var n = Math.floor((w + g) / (mw + g))
    return n < 1 ? 1 : n
}

/* node 可直接 require 本文件（QML 侧看不到 module，用 typeof 保护） */
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        layout: layout,
        columnsFor: columnsFor
    }
}
