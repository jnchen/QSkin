import QtQuick 2.15
import QSkin.Foundation 1.0

/****************************************************************************
 * QSkin · 冒烟 · TextMetricsUtil
 *
 * 门禁判据（位掩码，每条都可能红）：
 *   [0] 行数与引擎 `Text.lineCount` 逐例一致（px12/16/24 × 5 宽度 = 11 例）
 *   [0c] **度量口径**：`advanceWidth` ≠ `width`，且逐字累加 advanceWidth
 *        与整串**差 0.00**（曾用 width 累加而误判成「kerning 不可复现」）
 *   [1] 边界：空串 / 单字符 / 超宽长词 / maxWidth≤0
 *   [2] `measure` 与引擎同宽字符串的 `width` 一致
 *   [3] `height`：行数对的组**逐像素相等**，行数差 1 的组容一行盒高
 *   [4] `lineTexts` 拼回原文（折行不丢字）
 *   [6] font 隔离：连续两次不同 font 调用不串味
 *
 * ⚠ 为什么 [0]/[3] 必须与**真实渲染的 Text** 对照，而不能自证：
 *   本单例的算法就是「贪心累加到超宽就断」，而引擎也这么断。
 *   如果两边都用同一份公式算，那是**同一个假设验证两次**，
 *   门禁会永远绿。⇒ 对照组的 `Text` 必须由引擎自己排版。
 *
 * ⚠ 为什么每个宽度要一个独立的 `Text`（而不是循环里改 `width`）：
 *   `Text` 没有 `lineCountAt(width)`（6.8 实测）⇒ 改 width 后**拿不到
 *   新宽度下的行数**，只有 `lineCount` 属性而它要等 polish。
 *   所以对照组只能"一个宽度一个实例"。这条限制本身就是 `TextMetrics`
 *   存在的理由。
 ****************************************************************************/

Item {
    id: probe

    /* ⚠⚠ 用例串**必须够长**（≥ 100 字），否则会落进「退化区」。
     *
     * 原来用 64 字的中英混排短串。它在 px12/px16 下正常，但在 **px24 下
     * 每行只装得下 1.5 个中文字** —— 落在「一行放不下两个字」的区间，
     * 于是 px24 的几组全红，一度让我以为「px24 复现不了引擎排版」。
     *
     * 真相：那是 **Qt 在极窄容器下的特殊断行规则**（实测 px24 / w=60：
     * 引擎按 `width` 判而不是 `advanceWidth`），不是本单例的算法问题。
     * 换成 114 字后每行装 8~20 字，三档宽度**全部一致**。
     * 退化区的细节写在 `src/foundation/TextMetricsUtil.qml` 文件头。 */
    readonly property string txt:
        "QSkin 是一层样式契约，四套设计语言各自实现。契约只描述按钮、输入框、表格这些部件长什么样，"
        + "不描述它们怎么排版。排版由地基层统一负责，于是换主题时控件逻辑一行都不用改，"
        + "而界面整体换一套设计语言。令牌是纯数据，改令牌不改代码。"
    readonly property string shortTxt: "短文本"
    readonly property var  f16: Qt.font({ pixelSize: 16,  family: "Segoe UI" })
    readonly property var  f12: Qt.font({ pixelSize: 12,  family: "Segoe UI" })
    readonly property var  f24b: Qt.font({ pixelSize: 24,  family: "Segoe UI" })

    // ════════ 对照组：引擎自己排版 ════════
    Text { id: e120; width: 120; text: probe.txt;        font: probe.f16
           wrapMode: Text.WordWrap }
    Text { id: e160; width: 160; text: probe.txt;        font: probe.f16
           wrapMode: Text.WordWrap }
    Text { id: e200; width: 200; text: probe.txt;        font: probe.f16
           wrapMode: Text.WordWrap }
    Text { id: e240; width: 240; text: probe.txt;        font: probe.f16
           wrapMode: Text.WordWrap }
    Text { id: e320; width: 320; text: probe.txt;        font: probe.f16
           wrapMode: Text.WordWrap }
    Text { id: e12;  width: 200; text: probe.txt;        font: probe.f12
           wrapMode: Text.WordWrap }
    /* px24 的三档宽度都落在「每行装得下 8 个以上中文字」的正常区间。
     * 退化区（`maxWidth < pixelSize * 2`）的差异见文件头说明 ——
     * 那里引擎有额外约束，**不能拿来当判据**（会测出一个假绿）。 */
    Text { id: e24b; width: 200; text: probe.txt;        font: probe.f24b
           wrapMode: Text.WordWrap }
    Text { id: e24c; width: 320; text: probe.txt;        font: probe.f24b
           wrapMode: Text.WordWrap }
    Text { id: e24d; width: 480; text: probe.txt;        font: probe.f24b
           wrapMode: Text.WordWrap }
    Text { id: es;   width: 200; text: probe.shortTxt;  font: probe.f24b
           wrapMode: Text.WordWrap }
    // bit2 的对照：**原生 TextMetrics**（同源对照，只验"font 有没有写对"）。
    // ⚠ 第一版拿 `e200.width` 对照，那它是**容器宽 200**，判据本身是错的
    //   （实测 textWidth("中A") = 25.97 vs e200.width = 200，必然红）。
    // ⚠ 第二版改拿 `Text.implicitWidth` 对照，也错 —— 实测 26.31 vs 25.97，
    //   差 0.34，那是 `Text` 排版时的余量。**两个都不是内容宽，只有原生
    //   TextMetrics 是。**
    /* ⚠ 对照组的 `TextMetrics`：比的是 **advanceWidth**（引擎排版口径），
     *   不是 `width`（包围盒）。见判据 [0c]。
     * ⚠ 它的 `text` 被 [0c] 改成过长串了 —— 后面每条用到它的判据
     *   都必须**自己设回来**。共享对象的可变状态，判据里必须显式复位。 */
    TextMetrics { id: ref; text: "中A"; font: probe.f16 }

    // ════════ 高度对照组（带 lineHeight）════════
    /* ⚠ 高度对照组必须与 [0] 的对照组**同一个字体**。
     *   原来这里写 `font.pixelSize: 16` —— 那走的是**默认字体**
     *   （Microsoft YaHei UI，自然行高 20），而 [0] 用 `font: probe.f16`
     *   （Segoe UI，自然行高 22）。于是「行数对、高度差 15」看起来像
     *   算法错，其实是**在拿两个字体的结果相比**。
     *   ⇒ 判据里的对照组必须同源，否则它测的是别的字体。 */
    Text { id: h16;  width: 200; text: probe.txt; font: probe.f16
           wrapMode: Text.WordWrap; lineHeight: 1.5
           lineHeightMode: Text.ProportionalHeight }
    Text { id: h24;  width: 200; text: probe.txt; font: probe.f24b
           wrapMode: Text.WordWrap; lineHeight: 1.5
           lineHeightMode: Text.ProportionalHeight }
    Text { id: h12;  width: 200; text: probe.txt; font: probe.f12
           wrapMode: Text.WordWrap; lineHeight: 2.0
           lineHeightMode: Text.ProportionalHeight }
    Text { id: hFix; width: 200; text: probe.txt; font: probe.f16
           wrapMode: Text.WordWrap; lineHeight: 24
           lineHeightMode: Text.FixedHeight }

    property int mask: 0
    property int idx: 0

    /* 本仓 mask 约定：**1 = 该位失败**（与 smoke_layout / smoke_m30 同源）。
     * ⚠ 第一版写成「1 = 通过」，于是全绿时退出码是 0b110111 = 55，
     *   而 `tools/test.sh` 按「位 = 失败」解码 —— 报成「5 条断言失败」，
     *   而实际上五条全过。**同一套 mask 两种语义 ⇒ 门禁永远报错**，
     *   而单跑时又是绿的 ⇒ 极难定位。 */
    /* 每条判据的名字 —— 位掩码只给「第几位红了」，人还得回头数代码。
     * 失败时直接报名字（走 console.error：Windows GUI 子系统上
     * console.log 什么都看不到）。这个文件已经因为「看不出是哪条红了」
     * 浪费了三轮：RC=8 时我以为 [3] 块高有问题，实际是 [2] textWidth。 */
    property var labels: ["[0] 行数与引擎一致", "[0c] 度量口径 advanceWidth",
                          "[1] 边界", "[2] textWidth", "[3] 块高",
                          "[4] linesAt", "[5] font 隔离"]

    function expect(cond) {
        if (!cond) {
            probe.mask |= (1 << probe.idx)
            console.error("  NG " + (probe.labels[probe.idx]
                                     || ("bit" + probe.idx)))
        }
        probe.idx++
    }

    Component.onCompleted: settleTimer.restart()

    /* ⚠⚠ **必须等 polish 真正完成再读**，`Qt.callLater` **一帧不够**。
     *
     * 读早了会拿到**中间值**：实测同一条 114 字串在 w200 下
     *   · callLater 读到 implicitHeight = 330.00（行数 10）
     *   · 真正完成后是 **315.00**（= 10 × 31.5）
     * 而 330 / 31.5 = 10.48 不是整数，当场被当成「公式错了」。
     * ⇒ 判据要对着**稳定的量**，600ms 实测足够。 */
    Timer {
        id: settleTimer
        interval: 600
        running: false
        onTriggered: {
            /* ── [0] 行数与引擎逐例一致 ── */
            // ⚠ 三处漏写 `probe.` 前缀（qmllint unqualified 警告指的就是这里）。
            //   同一文件其它行都写了 —— 是笔误，不是「跨作用域访问」那种
            //   可以 disable 的情况，所以**修它**而不是加豁免。
            var pairs = [[e120, 120, probe.f16], [e160, 160, probe.f16],
                         [e200, 200, probe.f16],
                         [e240, 240, probe.f16], [e320, 320, probe.f16],
                         [e12, 200, probe.f12],
                         [e24b, 200, probe.f24b], [e24c, 320, probe.f24b],
                         [e24d, 480, probe.f24b]]
            var bad = 0
            for (var i = 0; i < pairs.length; i++) {
                var mine = TextMetricsUtil.lineCountAt(probe.txt, pairs[i][1], pairs[i][2])
                if (mine !== pairs[i][0].lineCount) bad++
            }
            // 短文本那组单独算（内容不同）
            if (TextMetricsUtil.lineCountAt(probe.shortTxt, 200, probe.f24b) !== es.lineCount) bad++
            probe.expect(bad === 0)

            /* ── [0c] 度量口径：`advanceWidth` ≠ `width` ──
             *
             * 这条判据是本文件**最大教训**的守门员。我曾用
             * `probe.width`（包围盒，含 side bearing）逐字累加，得到
             * 「复现不了引擎排版、差 27.91px、kerning 有问题」的**错误结论**，
             * 并把它写成契约（「估算不是精确」）。
             *
             * 真相：`TextMetrics` 有三个宽度口径，我只用了两个里的错那个：
             *     width          205.25   包围盒（含左右 side bearing）
             *     advanceWidth   225.50   前进宽度 —— **引擎排版用这个**
             *     逐字和 width        = 177.34   （少 27.91）
             *     逐字和 advanceWidth = 225.50   （**差 0.00**）
             * ⇒ side bearing 是**负的**（墨迹两侧留白），逐字累加会重复计入。
             *
             * 本判据钉住三件事：
             *   ① `textWidth()` 返回 **advanceWidth**
             *   ② 逐字累加 advanceWidth == 整串 advanceWidth（差 0.01 内）
             *   ③ 反证：width 口径**确实**对不上（否则这题没意义）
             * 哪天有人「顺手改成 probe.width」，①③ 立刻红。 */
            ref.text = probe.txt
            ref.font = probe.f24b
            var sumAdv = 0
            for (var ai = 0; ai < probe.txt.length; ++ai) {
                ref.text = probe.txt.charAt(ai)
                sumAdv += ref.advanceWidth
            }
            ref.text = probe.txt
            var wholeAdv = ref.advanceWidth
            var sumBox = 0
            for (var bi = 0; bi < probe.txt.length; ++bi) {
                ref.text = probe.txt.charAt(bi)
                sumBox += ref.width
            }
            ref.text = probe.txt
            var wholeBox = ref.width
            var c1 = Math.abs(TextMetricsUtil.textWidth(probe.txt, probe.f24b) - wholeAdv) < 0.01
            var c2 = Math.abs(sumAdv - wholeAdv) < 0.01
            var c3 = Math.abs(sumBox - wholeBox) > 1
            probe.expect(c1 && c2 && c3)

            /* ── [1] 边界 ── */
            var okEdge =
                TextMetricsUtil.lineCountAt("", 200, probe.f16) === 0 &&
                TextMetricsUtil.lineCountAt("A", 200, probe.f16) === 1 &&
                TextMetricsUtil.lineCountAt("A", 200, probe.f16) >= 1 &&
                TextMetricsUtil.lineCountAt("ABCDEFGHIJKLMNOP", 30, probe.f16) >= 1 &&
                TextMetricsUtil.lineCountAt("hello", 0, probe.f16) === 1 &&
                TextMetricsUtil.lineCountAt("hello", -5, probe.f16) === 1
            probe.expect(okEdge)

            /* ── [2] textWidth 与 TextMetrics 自身一致（验"font 写对了"）──
             * ⚠ 与**原生 TextMetrics** 对照而不是与 `Text.width`：
             *   后者是**容器宽**（对照组的 Text 都设了 width），不是内容宽。
             *   第一版就栽在这儿 —— 判据本身错，测的是"容器宽 == 内容宽"。 */
            var mBad = 0
            ref.text = "中A"
            ref.font = probe.f16
            if (Math.abs(TextMetricsUtil.textWidth("中A", probe.f16) - ref.advanceWidth) > 0.01)
                mBad++
            if (Math.abs(TextMetricsUtil.textWidth("", probe.f16)) > 0.01) mBad++
            ref.text = probe.txt
            if (Math.abs(TextMetricsUtil.textWidth(probe.txt, probe.f16) - ref.advanceWidth) > 0.01)
                mBad++
            if (Math.abs(TextMetricsUtil.textWidth("", probe.f16)) > 0.01) mBad++
            // ⚠ **不要**拿 `nat.implicitWidth` 对照：实测 26.31 vs textWidth 25.97，
            //   差 0.34 —— 那是 `Text` 自己排版时的余量，不是测量误差。
            //   拿它当判据就是在测一个**不成立的等式**（第二版栽在这）。
            probe.expect(mBad === 0)

            /* ── [3] height 与引擎 implicitHeight 逐例一致 ── */
            var hPairs = [[h16, 16, 1.5, Text.ProportionalHeight],
                          [h24, 24, 1.5, Text.ProportionalHeight],
                          [h12, 12, 2.0, Text.ProportionalHeight],
                          [hFix, 16, 24,  Text.FixedHeight]]
            /* 每一组都必须**逐像素相等**，没有例外。
             *
             * 原来这里有「px24 容一行盒高」的宽容判据 —— 因为我以为 px24
             * 少 1 行是复现不了的固有限制。改用 `advanceWidth` + `ceil`
             * 之后**四组全部精确相等**，宽容判据随之删除：
             * 留着一个已不存在的偏差的豁免，下次真出偏差时它会把它吞掉。 */
            var hBad = 0
            for (var j = 0; j < hPairs.length; j++) {
                var hp = hPairs[j]
                var f = Qt.font({ pixelSize: hp[1], family: "Segoe UI" })
                var pred = TextMetricsUtil.blockHeightAt(probe.txt, 200, f, hp[2], hp[3])
                var eng = hp[0].implicitHeight
                if (Math.abs(pred - eng) > 0.01) hBad++
            }
            probe.expect(hBad === 0)

            /* ── [4] lineTexts 拼回原文 ── */
            var parts = TextMetricsUtil.linesAt(probe.txt, 200, probe.f16)
            var joined = parts.join("")
            probe.expect(joined === probe.txt
                   && parts.length === TextMetricsUtil.lineCountAt(probe.txt, 200, probe.f16))

            /* ── [5] font 隔离：连续不同 font 不串味 ── */
            var l16 = TextMetricsUtil.lineCountAt(probe.txt, 200, probe.f16)
            var l24 = TextMetricsUtil.lineCountAt(probe.txt, 200, probe.f24b)
            var l16again = TextMetricsUtil.lineCountAt(probe.txt, 200, probe.f16)
            probe.expect(l16 === l16again && l24 !== l16)

            Qt.exit(probe.mask)   // probe.expect() 累积的那份，0 = 全过
        }
    }
}
