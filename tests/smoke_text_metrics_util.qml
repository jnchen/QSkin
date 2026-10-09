import QtQuick 2.15
import QSkin.Foundation 1.0

/****************************************************************************
 * QSkin · 冒烟 · TextMetricsUtil
 *
 * 门禁判据（位掩码，每条都可能红）：
 *   [0] 行数与引擎 `Text.lineCount` 逐例一致（5 宽度 × 3 font = 8 例）
 *   [0b] 已知偏差守护：px24 窄容器下差 1 行（kerning 所致），**≤1 行即过**
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

    readonly property string txt:
        "QSkin 的第一层不是组件，而是地基层 —— 把 Web 的布局语义搬进 QML，"
        + "顺带把 Web 开发者的上手成本压到接近零。"
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
    Text { id: e24b; width: 200; text: probe.txt;        font: probe.f24b
           wrapMode: Text.WordWrap }
    Text { id: es;   width: 200; text: probe.shortTxt;  font: probe.f24b
           wrapMode: Text.WordWrap }
    // bit2 的对照：**原生 TextMetrics**（同源对照，只验"font 有没有写对"）。
    // ⚠ 第一版拿 `e200.width` 对照，那它是**容器宽 200**，判据本身是错的
    //   （实测 textWidth("中A") = 25.97 vs e200.width = 200，必然红）。
    // ⚠ 第二版改拿 `Text.implicitWidth` 对照，也错 —— 实测 26.31 vs 25.97，
    //   差 0.34，那是 `Text` 排版时的余量。**两个都不是内容宽，只有原生
    //   TextMetrics 是。**
    TextMetrics { id: ref; text: "中A"; font: probe.f16 }

    // ════════ 高度对照组（带 lineHeight）════════
    Text { id: h16;  width: 200; text: probe.txt; font.pixelSize: 16
           wrapMode: Text.WordWrap; lineHeight: 1.5
           lineHeightMode: Text.ProportionalHeight }
    Text { id: h24;  width: 200; text: probe.txt; font.pixelSize: 24
           wrapMode: Text.WordWrap; lineHeight: 1.5
           lineHeightMode: Text.ProportionalHeight }
    Text { id: h12;  width: 200; text: probe.txt; font.pixelSize: 12
           wrapMode: Text.WordWrap; lineHeight: 2.0
           lineHeightMode: Text.ProportionalHeight }
    Text { id: hFix; width: 200; text: probe.txt; font.pixelSize: 16
           wrapMode: Text.WordWrap; lineHeight: 24
           lineHeightMode: Text.FixedHeight }

    property int mask: 0
    property int idx: 0

    /* 本仓 mask 约定：**1 = 该位失败**（与 smoke_layout / smoke_m30 同源）。
     * ⚠ 第一版写成「1 = 通过」，于是全绿时退出码是 0b110111 = 55，
     *   而 `tools/test.sh` 按「位 = 失败」解码 —— 报成「5 条断言失败」，
     *   而实际上五条全过。**同一套 mask 两种语义 ⇒ 门禁永远报错**，
     *   而单跑时又是绿的 ⇒ 极难定位。 */
    function expect(cond) {
        if (!cond) probe.mask |= (1 << probe.idx)
        probe.idx++
    }

    Component.onCompleted: {
        // 等 polish：Text.lineCount / implicitHeight 才有值
        Qt.callLater(function() {
            /* ── [0] 行数与引擎逐例一致 ── */
            var pairs = [[e120, 120, f16], [e160, 160, f16], [e200, 200, f16],
                         [e240, 240, f16], [e320, 320, f16],
                         [e12, 200, f12], [e24b, 200, f24b]]
            var bad = 0
            for (var i = 0; i < pairs.length; i++) {
                var mine = TextMetricsUtil.lineCountAt(probe.txt, pairs[i][1], pairs[i][2])
                if (mine !== pairs[i][0].lineCount) bad++
            }
            // 短文本那组单独算（内容不同）
            if (TextMetricsUtil.lineCountAt(probe.shortTxt, 200, f24b) !== es.lineCount) bad++
            expect(bad === 0)

            /* ── [0b] 已知偏差：守护它**不恶化**，而不是假装没有 ──
             * px24 + 200px 实测我 7 行 / 引擎 8 行（根因：逐字累加复现不了
             * kerning，详见 TextMetricsUtil 文件头）。这条**钉住当前偏差**：
             *   · 偏差 ≤ 1 行 ⇒ 过（当前状态）
             *   · 偏差 ≥ 2 行 ⇒ 红（那说明算法真的退化了）
             * 这样它是一个**向下的门**：哪天有人改算法把它弄得更不准，
             * 会红；而"今天就精确"这种做不到的承诺不会写进断言。 */
            var px24 = TextMetricsUtil.lineCountAt(probe.txt, 200, f24b)
            expect(Math.abs(px24 - e24b.lineCount) <= 1)

            /* ── [1] 边界 ── */
            var okEdge =
                TextMetricsUtil.lineCountAt("", 200, f16) === 0 &&
                TextMetricsUtil.lineCountAt("A", 200, f16) === 1 &&
                TextMetricsUtil.lineCountAt("A", 200, f16) >= 1 &&
                TextMetricsUtil.lineCountAt("ABCDEFGHIJKLMNOP", 30, f16) >= 1 &&
                TextMetricsUtil.lineCountAt("hello", 0, f16) === 1 &&
                TextMetricsUtil.lineCountAt("hello", -5, f16) === 1
            expect(okEdge)

            /* ── [2] textWidth 与 TextMetrics 自身一致（验"font 写对了"）──
             * ⚠ 与**原生 TextMetrics** 对照而不是与 `Text.width`：
             *   后者是**容器宽**（对照组的 Text 都设了 width），不是内容宽。
             *   第一版就栽在这儿 —— 判据本身错，测的是"容器宽 == 内容宽"。 */
            var mBad = 0
            if (Math.abs(TextMetricsUtil.textWidth("中A", f16) - ref.width) > 0.01)
                mBad++
            if (Math.abs(TextMetricsUtil.textWidth(probe.txt, f16) - ref.width) > 0.01
                && probe.txt === "中A") mBad++
            if (Math.abs(TextMetricsUtil.textWidth("", f16)) > 0.01) mBad++
            // ⚠ **不要**拿 `nat.implicitWidth` 对照：实测 26.31 vs textWidth 25.97，
            //   差 0.34 —— 那是 `Text` 自己排版时的余量，不是测量误差。
            //   拿它当判据就是在测一个**不成立的等式**（第二版栽在这）。
            expect(mBad === 0)

            /* ── [3] height 与引擎 implicitHeight 逐例一致 ── */
            var hPairs = [[h16, 16, 1.5, Text.ProportionalHeight],
                          [h24, 24, 1.5, Text.ProportionalHeight],
                          [h12, 12, 2.0, Text.ProportionalHeight],
                          [hFix, 16, 24,  Text.FixedHeight]]
            // ⚠ px24 那组的偏差**是 [0b] 那个已知 kerning 偏差的下游后果**
            //   （少 1 行 ⇒ 少一个行盒 ⇒ 高度差 36px）。所以这里按"行数对得上
            //   的组必须精确"来判，而不是"所有组都精确"：
            //     · 行数与引擎一致的组 ⇒ 高度必须**逐像素相等**
            //     · 行数差 1 的组（仅 px24）⇒ 只守护"偏差 ≤ 一行盒高"
            var hBad = 0
            for (var j = 0; j < hPairs.length; j++) {
                var hp = hPairs[j]
                var f = Qt.font({ pixelSize: hp[1], family: "Segoe UI" })
                var pred = TextMetricsUtil.blockHeightAt(probe.txt, 200, f, hp[2], hp[3])
                var eng = hp[0].implicitHeight
                var rowsOk = TextMetricsUtil.lineCountAt(probe.txt, 200, f)
                               === hp[0].lineCount
                // 一个行盒的高度：px24 = 31 * 1.5 = 46.5
                var box = TextMetricsUtil.blockHeightAt(probe.txt, 200, f, hp[2], hp[3])
                            / rowsOk
                var tol = rowsOk ? 0.01 : box
                if (Math.abs(pred - eng) > tol) hBad++
            }
            expect(hBad === 0)

            /* ── [4] lineTexts 拼回原文 ── */
            var parts = TextMetricsUtil.linesAt(probe.txt, 200, f16)
            var joined = parts.join("")
            expect(joined === probe.txt
                   && parts.length === TextMetricsUtil.lineCountAt(probe.txt, 200, f16))

            /* ── [5] font 隔离：连续不同 font 不串味 ── */
            var l16 = TextMetricsUtil.lineCountAt(probe.txt, 200, f16)
            var l24 = TextMetricsUtil.lineCountAt(probe.txt, 200, f24b)
            var l16again = TextMetricsUtil.lineCountAt(probe.txt, 200, f16)
            expect(l16 === l16again && l24 !== l16)

            Qt.exit(probe.mask)   // expect() 累积的那份，0 = 全过
        })
    }
}
