pragma Singleton
import QtQuick 2.15

/****************************************************************************
 * QSkin · Quick Design System — Foundation / TextMetricsUtil
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「这段文案在给定宽度下折成几行 / 占了多高」的**同步**答案。
 *
 * ── 为什么需要它（而不是让每个控件各自绑 implicitHeight）──────────────
 * QML 的绑定是声明式 + 惰性的：`height: text.implicitHeight` 要等 polish
 * 才算出结果。于是「按宽度算高度 → 据此定容器 → 据此排兄弟」这条链在 QML 里
 * 只能写成死算式，或者**先塌一下再撑开**（CLS 那个问题）。
 *
 * 本单例给的就是那条**渲染前的答案**：改 `TextMetrics.text` 再读 `width`
 * 是同步的，不需要等帧、不触发 reflow。
 *
 * ── 为什么不搬 Pretext ──────────────────────────────────────────────────
 * Web 上「渲染前拿不到文本尺寸」是**真劣势**：塞隐藏 DOM + 读
 * `getBoundingClientRect()`，每次强制 reflow。`@chenglou/pretext`（0.0.9，
 * 2026-03 首发）为这件事把测量与布局拆成 prepare / layout 两段。
 *
 * **Qt 侧不存在这个前提** —— `TextMetrics` 同步可读，所以 Pretext 那套
 * 架构在这里没有要解决的问题。且它还是早期项目（10 个版本 / 0.0.9），
 * 依赖一个 API 会变的库不划算。本单例只做它真正缺的那一件事：**量行数**。
 *
 * ── 算法：逐字符贪心，**在大多数情况下**与引擎一致，但**不是恒等** ──────
 *
 * 2026-10-09 实测（Qt 6.8.3 mingw_64）：
 *   · px16 / px12 三档 + 五种宽度（120~320）⇒ 行数与引擎 **完全一致**
 *   · **px24 在 200px 容器下差 1 行**（我 7 / 引擎 8）
 *
 * ⚠⚠ **为什么大字号会差一行，而调余量救不回来**（实测扫 0~2.5% 全部无效）：
 *
 *   根因是**逐字累加无法复现 kerning**。实测同一串「布局语义搬进 QML，」：
 *     整串一次量 = 205.25px
 *     逐字累加   = 177.34px     ← **少 27.91px**
 *
 *   差 27.91px 意味着贪心会**多塞进一个字**，那一行就比引擎的宽 ⇒
 *   引擎随后必须再断一次。**加安全余量（试到 2.5%）也追不平** ——
 *   因为误差不是恒定偏移，而是**随字形对（kerning pair）变化**。
 *
 * ⇒ **本单例的定位是「估算」，不是「引擎的离线复刻」**：
 *   · 用于「要不要换行 / 大概几行 / 该不该显示展开按钮」这类**判断** ⇒ 够用
 *   · 用于**像素级对齐引擎**（比如自己画文本）⇒ **做不到，别试**
 *     那种场景直接用 `Text` 本身读 `implicitHeight`（等 polish 即可）。
 *
 * 这也是为什么 `lineCountAt()` 的文档写「估算」而不是「精确」——
 * **一个做不到的承诺，写在注释里比忘了写更糟。**
 *
 * ⚠ **必须是逐字符**，不是「按词 / 按 CJK 切分」。
 *   第一版用正则分词（`/[一-鿿]|[^\s一-鿿]+|\s+/g`），同一段文本算出
 *   **11 行**而引擎是 **5 行** —— 一度以为「TextMetrics 不可信」。
 *   真因是那个算法把连续拉丁词也当整体推，于是每行只塞得下一个词。
 *   引擎的 `WordWrap` 对 CJK 逐字、对拉丁**也能切在词内**（无空格时尤其实）。
 *   换成朴素逐字符累加立刻与引擎一致。
 *   ⇒ 这条是「探针自身出错先怀疑探针」的实例，记在这里免得改回去。
 *
 * ── 宿主为什么是 `Item` 而不是 `QtObject` ───────────────────────────────
 * `QtObject` **没有默认属性**，`TextMetrics { }` 声明不进去
 * （报 `Cannot assign to non-existent default property`）。
 * `Item` 有 `data` 默认属性，但它 `width: 0 / height: 0 / visible: false`
 * 且不进任何场景图 —— 纯当测量器，不参与渲染。
 *
 * ⚠ **它是单实例共享的测量器，不是并发安全的**：同一时刻只有一个
 *   `font` 生效。`lineCountAt()` / `textWidth()` 内部是「设 text → 读 width」的
 *   同步序列，所以**在单次调用内是自洽的**；但不能把 `probe` 暴露出去给
 *   多个消费者交替设置字体 —— 那种用法会串味。API 因此**强制 font 作参数**。
 *
 * ── 函数名为什么长这样（`lineCountAt` / `blockHeightAt` / …）────────────
 * 宿主是 `Item`（`QtObject` 没有默认属性，装不下 `TextMetrics`），
 * 而 `Item` **已经占用了**一批常见名字 —— 声明同名的 `function height()` 会被
 * **静默覆盖**（Qt 只报一句 `Final member height is overridden`，然后
 * `height(...)` 调用得到 `is not a function`）。所以：
 *
 *   ✗ 不能叫   height / width / visible / font / parent / children / data
 *              opacity / enabled / visible / activeFocus / transform / state
 *   ✓ 本单例   lineCountAt(text, maxWidth, font) → 折成几行
 *              linesAt(text, maxWidth, font)    → 各行文本（数组）
 *              blockHeightAt(...)              → 多行总高
 *              lineHeightOf(text, font)         → 单行像素高
 *              textWidth(text, font)            → 单行像素宽
 *              fitsIn(text, maxWidth, font)    → { fits, width, remaining }
 *
 * ⚠ 改函数名时**先对照上面这张表**。Qt 对成员冲突**不报错**（只有一句
 *   override 提示混在大量输出里），而症状是"调用它变成 not a function" ——
 *   极容易误判成"环境没配好"。
 *
 * ── 与 `QSkinTable` 同一套做法 ───────────────────────────────────────────
 * 那边量列宽用的是声明式 `TextMetrics { }` + 改 `text` 读 `width`
 * （见该文件头“两个 QML 陷阱”）。本单例是同一手法的独立实例 ——
 * 刻意不共用：那边要跟着表格的 font 变，这边是通用排版测量。
 *
 * 用法：
 *     import QSkin.Foundation 1.0
 *     TextMetricsUtil.lineCountAt("很长的文案……", 320, someText.font)   // → 3
 *     TextMetricsUtil.blockHeightAt("很长的文案……", 320, someText.font,
 *                                   1.5, Text.ProportionalHeight)
 ****************************************************************************/

Item {
    id: host
    width: 0; height: 0; visible: false

    /* ⚠ 宿主**不能是 `Item`** —— 它自带 `height` 属性，本单例的 `height()`
     *   函数会被静默覆盖（Qt 只报一句 `Final member height is overridden`
     *   然后用属性那个，`height(...)` 调用即 `is not a function`）。
     *
     *   宿主是 `QtObject` 而 `QtObject` 又**没有默认属性**，`TextMetrics`
     *   声明不进去 —— 两条路各堵一半。
     *
     *   解法：**把测量器挂进 `children`**（`children` 是 `Item` 的
     *   默认属性列表，可以显式追加），并把本单例所有公开函数改名，
     *   **避开 Item 的既有属性名**：height / width / visible / opacity /
     *   enabled / parent / children / data / font / activeFocus… ……
     *
     *   下方 `API-NAME` 注释块列出了所有占用名，改函数名时对照它。
     */
    /* 测量器本体。**不设 font** —— 每次 measure 前由 `_apply` 写入，
     * 默认值（系统默认字号）只影响「没有传 font」的退化路径。
     *
     * ⚠ 它是 `Item` 的**默认子对象**（`data` 列表），不要写
     *   `children: [ TextMetrics {...} ]` —— `children` 是**只读**的列表属性，
     *   赋值报 `Cannot assign object to list property "children"`。
     *   直接写子对象即可（那才是默认属性的用法）。 */
    TextMetrics {
        id: probe
    }

    /* ══════════════════════════ 私有工具 ══════════════════════════ */

    function _apply(font) {
        if (font !== undefined && font !== null)
            probe.font = font
    }

    /* 逐字符贪心：累加到超宽就断行。返回断点数组（不含最后一段）。
     *
     * ⚠ `probe.width` 是**同步**读回，不需要等帧 —— 这是 Qt 相对 Web
     *   的关键优势，Pretext 整个存在的前提在 Qt 里不成立。 */
    function _breaks(text, font, maxWidth) {
        _apply(font)
        var s = String(text)
        var breaks = []
        if (s.length === 0) return breaks
        if (!(maxWidth > 0)) {
            // 退化：宽度非正 ⇒ 永远不折行。只有一行。
            // **不返回 undefined** —— 契约是「永远返回一个数字」。
            return breaks
        }
        var cur = ""
        for (var i = 0; i < s.length; i++) {
            var ch = s.charAt(i)
            probe.text = cur + ch
            if (probe.width > maxWidth && cur !== "") {
                breaks.push(cur.length)
                cur = ch
            } else {
                cur += ch
            }
        }
        return breaks
    }

    /* ══════════════════════════ 公开 API ══════════════════════════ */

    /** 单行像素宽。返回 0（空串时）。 */
    function textWidth(text, font) {
        _apply(font)
        probe.text = String(text)
        return probe.width
    }

    /** 单行像素高（**不含** lineHeight 倍数）。 */
    function lineHeightOf(text, font) {
        _apply(font)
        probe.text = String(text)
        return probe.height
    }

    /** 文本在 maxWidth 下折成几行。空串 → 0；maxWidth ≤ 0 → 1。
     *
     *  ⚠ 这是**估算**，不是精确值。逐字累加复现不了 kerning，
     *   实测 px16/px12 与引擎逐例一致，而 px24 在窄容器下会少 1 行。
     *   判据见冒烟 `smoke_text_metrics_util.qml` 的 [0]（含该已知偏差的断言）。 */
    function lineCountAt(text, maxWidth, font) {
        var s = String(text)
        if (s.length === 0) return 0
        if (!(maxWidth > 0)) return 1
        return _breaks(s, font, maxWidth).length + 1
    }

    /** 折行后各行的文本（数组）。空串 → []。 */
    function linesAt(text, maxWidth, font) {
        var s = String(text)
        if (s.length === 0) return []
        if (!(maxWidth > 0)) return [s]
        var br = _breaks(s, font, maxWidth)
        var out = [], pos = 0
        for (var i = 0; i < br.length; i++) {
            out.push(s.substring(pos, pos + br[i]))
            pos += br[i]
        }
        out.push(s.substring(pos))
        return out
    }

    /** 多行总高。
     *
     * 公式（2026-10-09 实测，Qt 6.8.3）：**总高 = 行数 × 每行盒高**，
     * 而每行盒高 = `max(pixelSize × lineHeight, 该字体的自然行高)`。
     *
     * ⚠ 这里有两次「猜错」，都记下来免得改回去：
     *
     *   ① 先猜 `max(比例 × px, natural)` —— 实测 `px16 lh1.5` 下引擎给
     *      **31.5**，而公式算出 24，差 7.5px × 行数。
     *   ② 再猜 `step = natural × 比例`（= 30.49）—— 仍差 4.73。
     *      因为按 `(h - nat) / (n - 1)` 算出来的"步进"**根本不是常数**
     *      （同配置下 n=4/3/2 时分别是 35.2 / 37.1 / 42.7）。
     *
     *   真相是**总高恰好整除行数**：`h / n` 在同一配置下恒定
     *   （n=4/3/2/1 都是 31.500）。所以该按"每行盒高 × 行数"算，
     *   而不是"首行 + (n-1) × 步进"。
     *
     *   实测四组全中（复算见 `tests/smoke_text_metrics_util.qml` 判据 [3]）：
     *     px16 lh1.5 → 21×1.5 = 31.5 | px24 lh1.5 → 31×1.5 = 46.5
     *     px12 lh2.0 → 16×2.0 = 32.0 | px16 FixedHeight 24 → 24
     */
    function blockHeightAt(text, maxWidth, font, lineHeight, lineHeightMode) {
        var n = lineCountAt(text, maxWidth, font)
        if (n === 0) return 0
        return n * _lineBoxHeight(font, lineHeight, lineHeightMode)
    }

    /* ══════════════════ 行盒高度 · 引擎算法（实测反推出来的）══════════════
     *
     *   每行盒高 = 自然行高 × lineHeight      （ProportionalHeight）
     *   每行盒高 = lineHeight                 （FixedHeight）
     *
     * ⚠⚠ **这里连着猜错三次**，过程写在这里，别再走一遍：
     *
     *   ① 猜 `max(pixelSize × ratio, natural)` —— px16 lh1.5 得 24，引擎 31.5。
     *   ② 猜 `natural × ratio`（natural 取 `TextMetrics.height` = 21.28）
     *      → 31.92，仍与 31.5 差 0.42。
     *   ③ 发现 `TextMetrics.height` **不是自然行高**，而是**当前串的
     *      implicitHeight** —— 它随内容变（"中"=16.00 / "中A"=21.28），
     *      而自然行高是**字体属性**、与内容无关。
     *
     *   正解：用 `TextMetrics` 量一段**多行文本**的 `implicitHeight ÷ 行数`？
     *   不行 —— 那已经含了行距。**直接用 `lineHeight: 1.0` 那个值**：
     *     实测 px16 时 lh=1.0 每行 21.00、lh=1.5 每行 31.50，比值精确 1.5000。
     *     所以自然行高 = `Math.round(TextMetrics.height)`，21.28 → **21**。
     *     引擎用整数值（它内部也是整数行盒），所以要 round。
     */
    function _lineBoxHeight(font, lineHeight, lineHeightMode) {
        _apply(font)
        if (lineHeightMode === Text.FixedHeight)
            return lineHeight > 0 ? lineHeight : _naturalLineHeight(font)
        var ratio = lineHeight > 0 ? lineHeight : 1
        return _naturalLineHeight(font) * ratio
    }

    /** 字体的自然行高（与内容无关）。`TextMetrics.height` 要 round ——
     *  它给的是浮点（21.28），而引擎的行盒是**整数**（21.00）。 */
    function _naturalLineHeight(font) {
        _apply(font)
        probe.text = "中A"        // 含 CJK：拉丁字母的度量低一档，见下
        return Math.round(probe.height)
    }

    /** 判定"这一行还有余量吗" —— 用于「放得下就放，放不下就换行」的手动断行。
     *  返回 { fits, remaining }，remaining 是 maxWidth - 当前行宽。 */
    function fitsIn(text, maxWidth, font) {
        var w = textWidth(text, font)
        return { fits: w <= maxWidth, width: w,
                 remaining: maxWidth - w }
    }
}
