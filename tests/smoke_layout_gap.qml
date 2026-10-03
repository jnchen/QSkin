/****************************************************************************
 * QSkin · 冒烟测试 — 布局「翻译层」的有损处
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件守的是什么 ──────────────────────────────────────────────────
 *
 * `smoke_layout.qml` 守的是 `fill` 语义（hug / 撑满）。这个文件守的是另一
 * 类东西：**QSkin 的 Row / Column / Grid 是把 Web 布局语义翻译成 Qt Quick
 * Layouts**，而这次翻译是**有损**的。有损处如果不逐条钉死，就会在没人
 * 注意的时候悄悄改变形状 —— 写的人以为自己写的是 CSS，跑的是 Qt。
 *
 * 本文件把「翻译损失」分成两类，各占几条：
 *
 *   · **已补的**（QSkin 用封装绕开了 Qt 的默认行为）
 *     → 断言「Web 语义成立」。改坏封装会红。
 *   · **没补的**（Qt 的默认行为直接漏出来）
 *     → 断言「漏出来这件事本身」。哪天补上了会红，那是在提醒你
 *       回头改文档，不是 bug。
 *
 * 第二类看着别扭，但它是唯一诚实的写法：把"已知缺陷"写成断言，
 * 比写在注释里强 —— 注释不会红。
 *
 * ⚠ M29 之后**第二类只剩 [1]**（原生 ColumnLayout 那条反证）——
 *   Row 那一侧的 [6] 已经补掉并翻面成"钉住新语义"，详见它的注释。
 *   特意点这一笔，是因为"两类的数目"本身会误导人：这里若只写"各占几条"，
 *   读者会以为反证还有两处，而实际只剩一处。
 *
 * ⚠ 本文件的断言一律用 `gx/gy`（mapToItem 到容器）读落点，**不要**退回
 *   `子项.x` —— 那是相对内层 layout 的局部坐标。原实现内层铺满容器，
 *   `layout.x ≡ 0`，两者恰好相等，所以这个错误长期不可见；M29 把内层改成
 *   显式定位后它才暴露（详见 smoke_layout_justify.qml 文件头）。
 *
 * ── 数字来源 ────────────────────────────────────────────────────────────
 * 本文件里所有期望值都是**先手算、再与实测对**，不是照抄实测：
 *
 *   [0][2] 3×32 + gap8×2  →  子项 y = 0 / 40 / 80，hug 高 = 112
 *   [3]    (580 - 12×2) / 3 = 185.333…   落到子项手上必须是整数
 *   [4]    floor((300 + 12) / (160 + 12)) = 1
 *   [5]    40×5 + 8×4 = 232，末项 x = 232 - 40 = 192
 *
 * 探针（可复算，留档 `.cache/keep/`）：`_probe_layoutgap.qml` /
 * `_probe_layoutgap2.qml`，另有 `.cache/keep/_probe_ga2*.qml` 专门量落点。
 * ⚠ 这组探针推翻了**两个**旧结论，而推翻第二个的正是本文件自己：
 *   ① QSkinColumn.qml 文件头原来记的「原生 ColumnLayout 400 高 / 3×32 →
 *      y = 0/136/272」与实测不符 —— 但它**不是** 0/184/320，而是
 *      **48/184/320**（整组垂直居中，上下各留白 48），间距是 **104**
 *      不是 152（152 = 184−32，是忘了第一枚子项自己有 48 起始偏移）。
 *   ② 本文件第一版在 [7] 写的「两枚时落点完全相同（都是首 0、尾 540）」
 *      **也是错的** —— 没有 Spacer 时尾项是 **392** 不是 540。
 *      是 `mutate_m27_gate.py` 的 GA2 把它打出来的：那一枪预期"绿"
 *      （判据失明），实测"红"，于是去量落点，才发现理由站不住。
 * 教训：这两条都是**注释**，不是断言 —— 注释不会红，所以它错了三次
 * 都没人知道（[1]、QSkinColumn.qml、COVERAGE.md 各一处）。
 *
 * 位掩码退出码的约定见 smoke_slots.qml 文件头；单文件上限 8 条，
 * 原因见 tools/test.sh 第 0 节（POSIX 只保留低 8 位）。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    width: 900; height: 700

    property int mask: 0
    property int idx: 0

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    function near(a, b) { return Math.abs(a - b) < 0.5 }

    /* 容器坐标 —— 子项的 `x`/`y` 是相对**内层 layout** 的局部坐标。
     * M29 之前内层是 `anchors.fill: root`（`layout.x ≡ 0`），局部恰好
     * 等于容器；改成显式定位之后这个巧合断了 —— `center`/`end` 档会
     * 差一个 `layout.x`。凡是要问"落在容器的哪里"，一律先 mapToItem。
     * 完整说明（含 M29 那次误诊）见 smoke_layout_justify.qml 文件头。 */
    function gx(it, host) { return it.mapToItem(host, 0, 0).x }
    function gy(it, host) { return it.mapToItem(host, 0, 0).y }

    /* ── [0][1] 同一份视觉意图，两种归宿 ─────────────────────────────
     * 意图：容器 400 高，放 3 个 32 高的块，间距 8。
     * Web 的 `display:flex; flex-direction:column; gap:8px` 给 y = 0/40/80。 */

    /* [0] QSkinColumn —— 已补：内部 layout 不撑满，余量不存在，gap 是真 gap */
    QSkinColumn {
        id: colFixed; x: 0; y: 0; width: 80; height: 400; gap: 8
        Rectangle { width: 40; height: 32; color: "#c00" }
        Rectangle { width: 40; height: 32; color: "#0c0"; id: c2 }
        Rectangle { width: 40; height: 32; color: "#00c"; id: c3 }
    }

    /* [1] 原生 ColumnLayout —— 没补的那一面：Qt 把余量**分进间距**。
     *     实测 y = **48 / 184 / 320**（整组垂直居中，上下各留白 48），
     *     间距从 8 变成 **104**（13 倍）—— **不是** 152（19 倍）：
     *     152 = 184 − 32，是忘了第一枚子项自己就有 48 的起始偏移。
     *     复算：48 + 32 + 104 + 32 + 104 + 32 + 48 = 400 ✓
     *     分配形状 = 边缘半份 / 间隙整份（≈ CSS 的 `space-around`）。
     *     ⚠ 这个形状**不能**拿去推 QSkinRow —— 见 [6]，那边是另一种形状。
     *     这条是 [0] 的**反证**：它证明 [0] 抓的是 QSkin 的封装，不是恒真式。 */
    ColumnLayout {
        id: rawCol; x: 120; y: 0; width: 80; height: 400; spacing: 8
        /* ⚠ 这三枚**只能**写 implicit 尺寸，不能写 width/height。
         *   qmllint 会直接报："Detected width on an item that is managed
         *   by a layout. This is undefined behavior" —— 与 QSkinRow.qml 文件头
         *   那条是同一件事，只是**隔着 QSkin 封装 qmllint 就看不见了**
         *   （下面 QSkinColumn 的子项写 width/height 它一声不吭）。
         *   这正是本文件存在的理由之一：静态检查够不到的地方得有人守。
         *   另注：写 implicit 还是写 width 对结果**没有影响** ——
         *   `_probe_layoutgap2.qml` 两档实测都是 48/184/320。 */
        Rectangle { implicitWidth: 40; implicitHeight: 32; color: "#c00" }
        Rectangle { implicitWidth: 40; implicitHeight: 32; color: "#0c0"; id: rw2 }
        Rectangle { implicitWidth: 40; implicitHeight: 32; color: "#00c"; id: rw3 }
    }

    /* ── [2] hug 高度：内容决定，不吞余量 ── */
    QSkinColumn {
        id: colHug; x: 240; y: 0; width: 80; gap: 8
        Rectangle { width: 40; height: 32; color: "#c00" }
        Rectangle { width: 40; height: 32; color: "#0c0" }
        Rectangle { width: 40; height: 32; color: "#00c" }
    }

    /* ── [3] Grid 分数列宽：算出来是实数，落到子项手上是整数 ── */
    QSkinGrid {
        id: gWide; x: 0; y: 450; width: 580; fill: true
        minChildWidth: 160; gap: 12
        Rectangle { height: 20; color: "#333"; id: w0 }
        Rectangle { height: 20; color: "#555"; id: w1 }
        Rectangle { height: 20; color: "#777"; id: w2 }
    }

    /* ── [4] Grid 窄屏降级：公式复算 ── */
    QSkinGrid {
        id: gNarrow; x: 600; y: 450; width: 300; fill: true
        minChildWidth: 160; gap: 12
        Rectangle { height: 20; color: "#333" }
        Rectangle { height: 20; color: "#555" }
    }

    /* ── [5] Row 的 gap 是真 gap（不撑满时） ── */
    QSkinRow {
        id: row5; x: 0; y: 520; gap: 8
        Rectangle { width: 40; height: 20; color: "#048" }
        Rectangle { width: 40; height: 20; color: "#048" }
        Rectangle { width: 40; height: 20; color: "#048" }
        Rectangle { width: 40; height: 20; color: "#048" }
        Rectangle { width: 40; height: 20; color: "#048"; id: r5last }
    }

    /* ── [6] M29 已补：没有 fillWidth 子项 → 内容收缩，余量留在末端 ──────
     *     这一条原来是**反着的**：它钉住"间距被撑大"这条已知缺陷，
     *     留给后人"补上之后回来改文档"。M29 补上了（`justify` 默认
     *     `"start"`），于是它翻面成"钉住新语义"。
     *
     *     旧行为的现场并没有丢 —— 它现在只出现在**原生** RowLayout 上，
     *     而那正好由 `smoke_layout_justify.qml` 的 [4] 当着反证；
     *     本文件的 [1] 也用原生 ColumnLayout 反证了同一件事。
     *     所以"QSkin 的封装确实在做事"这件事仍然有门守着，
     *     而不是靠"我们改过了"这句话。
     *
     *     ⚠ root 上的 `fill: true` 在本档是 **no-op**（root 不在 Layout 里），
     *       所以这里不写它 —— 让 layout 收缩的是"没有任何子项声明
     *       `Layout.fillWidth`"，与 `fill` 无关。混在一起会让读者以为是
     *       `fill` 起了作用。 */
    QSkinRow {
        id: rowJust; x: 0; y: 560; width: 580; gap: 8
        Rectangle { width: 40; height: 20; color: "#804" }
        Rectangle { width: 40; height: 20; color: "#804"; id: j1 }
        Rectangle { width: 40; height: 20; color: "#804"; id: j2 }
    }

    /* ── [7] 解药：Spacer 吸干余量后，间距回到 gap ──
     *     为什么放**三**枚（A / Spacer / B / C）而不是两枚（A / Spacer / B）：
     *     两枚只能回答"Spacer 生没生效"（生效 → 尾项贴右 540，
     *     没生效 → 尾项停在 392），说不出"**哪一段**被吃掉"。
     *     三枚里 **B 的落点 492** 把这件事钉死：A→B 被 Spacer 撑开，
     *     而 **B→C 仍是 gap 8**（492 + 40 + 8 = 540 = 右沿）。
     *
     *     ⚠ 本文件第一版写的理由是「两枚时落点完全相同（都是首 0、
     *       尾 540），判据区分不了」—— **这句是错的**，已被
     *       `mutate_m27_gate.py` 的 GA2 / GA3 证伪：没有 Spacer 时尾项是
     *       **392**，不是 540，两枚其实**分得开**。
     *       留着这段更正，是因为那个错同时污染了 [1]、`QSkinColumn.qml` 与
     *       `COVERAGE.md` 三处 —— 一条没被证伪的注释就是这么传播的。 */
    QSkinRow {
        id: rowSpacer; x: 0; y: 600; width: 580; gap: 8
        Rectangle { width: 40; height: 20; color: "#084"; id: s0 }
        Spacer { }
        Rectangle { width: 40; height: 20; color: "#084"; id: s1 }
        Rectangle { width: 40; height: 20; color: "#084"; id: s2 }
    }

    Component.onCompleted: function() { Qt.callLater(root.run) }

    function run() {
        /* [0] QSkinColumn：主轴不撑满，gap 就是 gap —— 与 Web flex-start 同形 */
        root.expect(root.near(root.gy(c2, colFixed), 40)
                 && root.near(root.gy(c3, colFixed), 80))

        /* [1] 反证：同样意图交给原生 ColumnLayout，间距被均分撑大。
         *     判据收窄到"明显大于 gap"，不钉 184 这个内部数字 ——
         *     Qt 若微调分配规则，语义（间距 ≠ gap）不变，这条不该假红。 */
        root.expect(rw2.y > 48 && rw3.y > rw2.y + 48)

        /* [2] hug：3×32 + 8×2 = 112，多给的高度不参与分配 */
        root.expect(root.near(colHug.height, 112))

        /* [3] 分数列宽被逐枚取整：columnWidth 是实数，子项宽是整数，
         *     但三列 + 两道 gap 必须正好填满 580（不许有累积误差）。
         *     期望值独立算：(580 - 12×2) / 3 */
        var expectCw = (580 - 12 * 2) / 3
        var ints = w0.width === Math.floor(w0.width)
                && w1.width === Math.floor(w1.width)
                && w2.width === Math.floor(w2.width)
        root.expect(gWide.columnCount === 3
                 && Math.abs(gWide.columnWidth - expectCw) < 0.01
                 && ints
                 && Math.abs(w0.width - expectCw) > 0.1      // 取整确实发生了
                 && root.near(w0.width + w1.width + w2.width + 24, 580))

        /* [4] 列数公式：floor((300 + 12) / (160 + 12)) = floor(1.81) = 1 */
        root.expect(gNarrow.columnCount === 1)

        /* [5] Row 不撑满时 gap 是真 gap：40×5 + 8×4 = 232 */
        root.expect(root.near(row5.implicitWidth, 232)
                 && root.near(root.gx(r5last, row5), 192))

        /* [6] M29 新语义：默认 justify = "start" → 余量留在末端，间隙 = gap。
         *     独立算路：内容宽 = 3×40 + 2×8 = 136；
         *               第二枚左沿 = 40 + 8 = 48；
         *               第三枚右沿 = 136；
         *               余量 = 580 − 136 = **444，落在末端**。
         *     第三项才是本条真正要钉的东西：若 Qt 把余量又摊回间距
         *     （旧行为，j1 会被推到 196），或 justify 被算成 center
         *     （j1 会到 222），前两项尚可能碰巧成立，这一项必红。 */
        var j1x = root.gx(j1, rowJust)
        var j2r = root.gx(j2, rowJust) + j2.width
        root.expect(root.near(j1x, 48) && root.near(j2r, 136)
                 && root.near(rowJust.width - j2r, 444))

        /* [7] Spacer 只吃掉 A→B 那一段；B→C 仍是 gap 8。
         *     独立算路：尾项右沿贴 580 → s2.x = 540 → s1.x = 540 - 8 - 40 = 492。
         *     均分（没 Spacer 时）会把 s1 推到 ~270，这条立刻红。 */
        root.expect(root.near(root.gx(s0, rowSpacer), 0)
                 && root.near(root.gx(s2, rowSpacer), 580 - 40)
                 && root.near(root.gx(s1, rowSpacer), 580 - 40 - 8 - 40))

        Qt.exit(root.mask)
    }
}
