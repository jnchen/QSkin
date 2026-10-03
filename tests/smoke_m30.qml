/****************************************************************************
 * QSkin · 冒烟测试 — M30 查缺补漏（逻辑侧）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件守的是什么 ──────────────────────────────────────────────────
 *
 * M30 六件里，**三件的正确性不依赖主题**（Paragraph / Body 修饰位 /
 * Countdown），另外两件（Link / InputGroup）也各有一半是纯逻辑。
 * 本文件收这两半；跨主题取色与分组圆角在 `smoke_m30_theme.qml`。
 *
 *   [0] `Paragraph(maxLines: 0)` 与 `Body` **逐字同构**，且上限被归一成
 *       `unlimitedLines`。前半句是"Paragraph 不是新排版"的数学形式 ——
 *       少了它，[1] 可以被"另写一份行高/字号"满足，而那正是本项目反复
 *       付代价的地方；后半句守的是 `maxLines <= 0` 的那句兜底。
 *
 *       ⚠⚠ **后半句不是冗余，别删** —— 探针 J 实测（`.cache/_probe_m30j`）：
 *         · `Text.maximumLineCount = 0` / `-5` 时，`lineCount` / `truncated`
 *           / 隐式高**与默认逐字相同**（Qt 把 <=0 当"不限"）；
 *         · 而属性**回读原样保留 0 / -5**（没有被 Qt 归一）。
 *       于是**渲染侧分辨不出有没有那句兜底**：把
 *       `maxLines > 0 ? maxLines : unlimitedLines` 改成裸的 `maxLines`，
 *       前半句照样绿（变异证伪器 G1 第一版就栽在这里 —— 我声明的红面是
 *       "渲染会变"，实测绿）。兜底唯一可观测的产物就是**归一后的属性值**，
 *       所以判据必须落在属性侧。
 *
 *   [1] `maxLines: 2` 真的截断（行数 + `truncated`）。
 *       ⚠ 单配 `elide` 对**换行**文本无效（折行后每行都装得下），
 *       必须 `maximumLineCount` + `elide` 一起给 —— 这条断言是那份说明的守卫。
 *   [2] `Body` 四个行内修饰位可设、且真的落到 `font.*`。
 *   [3] **回归**：`strong: false` 时字重是 `weightRegular` ——
 *       "四个位都不设 ⇒ 与加它们之前逐字相同"。没有这条，[2] 可以被
 *       "把默认字重改成 SemiBold"满足，而那是四家排版基线的静默漂移。
 *   [4] `QSkinCountdown` **注入 `now` 即冻结**（不自己走）—— 这是它能被
 *       门禁打的前提（会自己变的控件没法做像素门禁）。
 *   [5] 到期发 `finished`，且**恰好一次**（再往后推不再发）。
 *       ⚠ 这条守的是一个真栽过的坑：`done` 是 `remainingMs <= 0` 的**派生**
 *       绑定，在 `onRemainingMsChanged` 里读它会拿到**上一次**的值 →
 *       到期那一刻读到 false → 事件永不发。修法是只读刚刚变了的那个值。
 *       所以本文件里改完 `now` 必须**显式读一次 `remainingMs`** 物化跳变。
 *   [6] `QSkinLink.activate()` 的出口：能点的发信号、`enabled: false` 的不发。
 *   [7] `QSkinLink.labelUnderline` 三态（auto / always / never）。
 *
 * 位掩码退出码的约定见 smoke_slots.qml 文件头；单文件上限 8 条，
 * 原因见 tools/test.sh 第 0 节（POSIX 只保留低 8 位）。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    width: 900
    height: 600

    property int mask: 0
    property int idx: 0

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    /* ══════════ 夹具 ══════════ */

    readonly property string longText: "第一行\n第二行\n第三行\n第四行"

    Body { id: bodyRef;  text: root.longText }
    Paragraph { id: para0;   text: root.longText; maxLines: 0 }
    Paragraph { id: paraNeg; text: root.longText; maxLines: -5 }
    Paragraph { id: para2;   text: root.longText; maxLines: 2 }

    Body { id: bPlain;  text: "X" }
    Body { id: bStrong; text: "X"; strong:    true }
    Body { id: bItalic; text: "X"; italic:    true }
    Body { id: bUL;     text: "X"; underline: true }
    Body { id: bSO;     text: "X"; strike:    true }

    /* 时间锚：不用 0（0 是 epoch，剩余会是"整个时间戳差"，容易把期望算错）。
     * 也不用 Date.now() —— 门禁要确定性。 */
    readonly property var t0: new Date(2026, 0, 1, 0, 0, 0).getTime()

    QSkinCountdown { id: cdFreeze; deadline: root.t0 + 10000; now: root.t0 }

    property int fired: 0
    QSkinCountdown {
        id: cdDone
        deadline: root.t0 + 1000
        now: root.t0
        onFinished: root.fired += 1
    }

    property int clicks: 0
    QSkinLink { id: lkOn;   text: "LK"; onClicked: root.clicks += 1 }
    QSkinLink { id: lkOff;  text: "LK"; enabled: false; onClicked: root.clicks += 1 }

    QSkinLink { id: lkAutoNo;    text: "LK" }
    QSkinLink { id: lkAutoHover; text: "LK"; hovered: true }
    QSkinLink { id: lkAlways;    text: "LK"; underline: "always" }
    QSkinLink { id: lkNever;     text: "LK"; underline: "never"; hovered: true }

    /* ══════════ 断言 ══════════ */

    function run() {
        /* [0] Paragraph 与 Body 同构 **且** <=0 的上限被归一。
         * 两半各守一件事，缺一不可 —— 理由见文件头那段（探针 J 实测）。 */
        root.expect(para0.implicitWidth === bodyRef.implicitWidth
                 && para0.implicitHeight === bodyRef.implicitHeight
                 && para0.maximumLineCount === para0.unlimitedLines
                 && paraNeg.maximumLineCount === paraNeg.unlimitedLines)

        /* [1] maxLines: 2 真的截断 */
        root.expect(para2.lineCount === 2 && para2.truncated === true)

        /* [2] 四个修饰位落到 font.* */
        root.expect(bStrong.font.weight === Theme.font.weightSemiBold
                 && bItalic.font.italic === true
                 && bUL.font.underline === true
                 && bSO.font.strikeout === true)

        /* [3] 回归：全不设 == 加它们之前 */
        root.expect(bPlain.font.weight === Theme.font.weightRegular
                 && bPlain.font.italic === false
                 && bPlain.font.underline === false
                 && bPlain.font.strikeout === false)

        /* [4] 注入 now 即冻结 */
        root.expect(cdFreeze.remainingMs === 10000
                 && cdFreeze.ticking === false
                 && cdFreeze.done === false)

        /* [5] 到期恰好一次 —— 改完 now 显式读一次 remainingMs 物化跳变 */
        cdDone.now = root.t0 + 2000
        var r1 = cdDone.remainingMs
        var f1 = root.fired
        cdDone.now = root.t0 + 3000          /* 再往后推，不该再发 */
        var r2 = cdDone.remainingMs
        root.expect(r1 <= 0 && f1 === 1 && r2 <= 0 && root.fired === 1)

        /* [6] activate() 的出口 */
        lkOn.activate()
        lkOff.activate()
        root.expect(root.clicks === 1)

        /* [7] labelUnderline 三态 */
        root.expect(lkAutoNo.labelUnderline === false
                 && lkAutoHover.labelUnderline === true
                 && lkAlways.labelUnderline === true
                 && lkNever.labelUnderline === false)

        /* 自证：8 条断言真的都跑了。「检查了 0 条」与「全过」在退出码上
         * 长得一模一样 —— 这条把它分开（少跑 / 多跑都算炸）。 */
        if (root.idx !== 8) root.mask = 255

        Qt.exit(root.mask)
    }

    /* 看门狗：正常路径走不到这里。255 → 8 位全亮 = "这个文件炸了"。
     * 分回合不是必须的（本文件全同步），但异常仍会吞掉 Qt.exit。 */
    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }

    /* 推迟一轮：字体就绪与布局 polish 都可能晚于 onCompleted，
     * Paragraph 的两条判据读的正是布局算出来的尺寸。 */
    Component.onCompleted: function() { Qt.callLater(root.run) }
}
