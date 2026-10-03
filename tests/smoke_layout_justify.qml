/****************************************************************************
 * QSkin · 冒烟测试 — 主轴分配（`justify`）与它的失效条件
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件守的是什么 ──────────────────────────────────────────────────
 *
 * M29 给 `QSkinRow` / `QSkinColumn` 加了 `justify`（≈ CSS `justify-content`），
 * 并把**默认行为**从"Qt 把余量摊进间距（且尾部丢一份）"改成 Web 的
 * `flex-start`（余量留在末端）。这是一次**行为变更**，不是新特性：
 * 以前靠"间距被撑大"歪打正着铺满一整行的写法，现在会缩到左边。
 *
 * 于是两道都要守：
 *   · 新行为**成立**（[0][1][2][5][6]）；
 *   · 而且它**不是恒真式** —— 同样一份意图交给原生 RowLayout，
 *     仍然要把间距撑大（[4]）。没有这条，[0] 可能只是"读了个 0"。
 *
 * [3] 与 [7] 守的是**失效条件**：有 `Layout.fillWidth` / `fillHeight`
 * 子项时，余量被那个子项吃干，`justify` 无从发生。这条与 CSS 一致，
 * 但静态检查（qmllint）看不见 —— 只能靠断言。
 *
 * ── ⚠ 坐标系（M29 第一版就栽在这里，改断言前先读这段）─────────────────
 *
 * **子项的 `x` / `y` 是相对内层 layout 的局部坐标，不是相对本组件的。**
 *
 * M2 / M27 那批断言之所以一直"看起来对"，是因为旧实现里内层 `RowLayout`
 * 用 `anchors.fill: root` 铺满，于是 `layout.x ≡ 0` —— **局部坐标恰好等于
 * 容器坐标**。M29 为了让余量"不存在"把内层改成显式定位，这个巧合就断了：
 * `center` 档 `layout.x = 222`，此时子项 `x = 0` / `48` / `96`（局部），
 * 而容器坐标是 `222` / `270` / `318`。
 *
 * 症状是**只有非零落点的档位红、`start` 档绿** —— 很容易误当成
 * "justify 没实现"。
 *
 * 处置：凡是要问"这个东西落在容器的哪里"，一律 `mapToItem(容器)`。
 * 本文件与 `smoke_layout_gap.qml` 共用下面两个 helper。
 * 注意 `mapToItem` 是**命令式调用、不建立属性依赖** —— 在这里只用于
 * 断言取值（不是绑定），没问题。
 *
 * ── 数字来源（先手算、再与实测对，不照抄实测）────────────────────────────
 * 容器 580 宽、3 枚 40 宽、gap 8：
 *     内容宽  = 3×40 + 2×8 = 136
 *     center  → x0 = (580 − 136) / 2 = 222 → 222 / 270 / 318
 *     end     → x0 = 580 − 136       = 444 → 444 / 492 / 540
 *     start   → x0 = 0                     →   0 /  48 /  96
 * 容器 400 高、3 枚 32 高、gap 8：
 *     内容高  = 3×32 + 2×8 = 112
 *     center  → y0 = (400 − 112) / 2 = 144 → 144 / 184 / 224
 *     end     → y0 = 400 − 112       = 288 → 288 / 328 / 368
 *     Spacer  → 尾项贴底 y = 400 − 32 = 368
 *
 * 位掩码退出码的约定见 smoke_slots.qml 文件头；单文件上限 8 条，
 * 原因见 tools/test.sh 第 0 节（POSIX 只保留低 8 位）。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    width: 900
    height: 700

    property int mask: 0
    property int idx: 0

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    function near(a, b) { return Math.abs(a - b) < 0.5 }

    /* 容器坐标 —— 见文件头「坐标系」一节，别退回 `it.x`。 */
    function gx(it, host) { return it.mapToItem(host, 0, 0).x }
    function gy(it, host) { return it.mapToItem(host, 0, 0).y }

    /* ══════════ 三档 justify（Row，580 / 3×40 / gap 8）══════════════════ */

    QSkinRow {                                        /* [0] start（默认） */
        id: rStart; x: 0; y: 0; width: 580; gap: 8
        Rectangle { width: 40; height: 20; color: "#048"; id: s1 }
        Rectangle { width: 40; height: 20; color: "#048"; id: s2 }
        Rectangle { width: 40; height: 20; color: "#048"; id: s3 }
    }

    QSkinRow {                                        /* [1] center */
        id: rCenter; x: 0; y: 40; width: 580; gap: 8; justify: "center"
        Rectangle { width: 40; height: 20; color: "#084"; id: c1 }
        Rectangle { width: 40; height: 20; color: "#084"; id: c2 }
        Rectangle { width: 40; height: 20; color: "#084"; id: c3 }
    }

    QSkinRow {                                        /* [2] end */
        id: rEnd; x: 0; y: 80; width: 580; gap: 8; justify: "end"
        Rectangle { width: 40; height: 20; color: "#804"; id: e1 }
        Rectangle { width: 40; height: 20; color: "#804"; id: e2 }
        Rectangle { width: 40; height: 20; color: "#804"; id: e3 }
    }

    /* ══════════ [3] 失效条件：有 fillWidth 子项 → justify 无从发生 ══════
     * Spacer 吸干余量，尾项被顶到右沿。此时 justify 写什么都一样 ——
     * 这一档写的是 "center"，若它真去居中了，下面的断言立刻红。
     *
     * ⚠ 让 layout 撑满的是 **Spacer 自己的 `Layout.fillWidth`**（见
     *   `_hasFill` 的判定），**不是** root 上的 `fill: true` ——
     *   root 不在任何 Layout 里，`Layout.fillWidth` 在本档是 no-op。
     *   这里刻意**不写** `fill: true`，免得读者把两件事混成一件。 */
    QSkinRow {
        id: rSpacer; x: 0; y: 150; width: 580; gap: 8
        justify: "center"
        Rectangle { width: 40; height: 20; color: "#c60"; id: p1 }
        Spacer { }
        Rectangle { width: 40; height: 20; color: "#c60"; id: p2 }
    }

    /* ══════════ [4] 反证：原生 RowLayout 同配置 → 仍然摊间距 ═══════════
     * 这是 [0] 的**对照**。若哪天 Qt 改了分配规则、它的行为变得跟 QSkinRow
     * 一样了，这条会红 —— 那是在提醒：QSkinRow 的封装可能已经变成空操作。 */
    RowLayout {
        id: rawRow; x: 0; y: 210; width: 580; height: 32; spacing: 8
        Rectangle { implicitWidth: 40; implicitHeight: 20; color: "#888"; id: w1 }
        Rectangle { implicitWidth: 40; implicitHeight: 20; color: "#888"; id: w2 }
        Rectangle { implicitWidth: 40; implicitHeight: 20; color: "#888"; id: w3 }
    }

    /* ══════════ 两档 justify（Column，400 高 / 3×32 / gap 8）═══════════ */

    QSkinColumn {                                     /* [5] center */
        id: cCenter; x: 0; y: 280; width: 80; height: 400; gap: 8
        justify: "center"
        Rectangle { width: 40; height: 32; color: "#048"; id: m1 }
        Rectangle { width: 40; height: 32; color: "#048"; id: m2 }
        Rectangle { width: 40; height: 32; color: "#048"; id: m3 }
    }

    QSkinColumn {                                     /* [6] end */
        id: cEnd; x: 120; y: 280; width: 80; height: 400; gap: 8
        justify: "end"
        Rectangle { width: 40; height: 32; color: "#804"; id: n1 }
        Rectangle { width: 40; height: 32; color: "#804"; id: n2 }
        Rectangle { width: 40; height: 32; color: "#804"; id: n3 }
    }

    /* ══════════ [7] Column 的失效条件：有 fillHeight 子项 ══════════════ */
    QSkinColumn {
        id: cSpacer; x: 240; y: 280; width: 80; height: 400; gap: 8
        Rectangle { width: 40; height: 32; color: "#c60"; id: q1 }
        Spacer { fillHeight: true }
        Rectangle { width: 40; height: 32; color: "#c60"; id: q2 }
    }

    Component.onCompleted: function() { Qt.callLater(root.run) }

    function run() {
        /* [0] start：余量留在末端，间隙就是 gap。独立算路 40+8=48、+40+8=96 */
        root.expect(root.near(root.gx(s1, rStart), 0)
                 && root.near(root.gx(s2, rStart), 48)
                 && root.near(root.gx(s3, rStart), 96))

        /* [1] center：(580 − 136) / 2 = 222 */
        root.expect(root.near(root.gx(c1, rCenter), 222)
                 && root.near(root.gx(c2, rCenter), 270)
                 && root.near(root.gx(c3, rCenter), 318))

        /* [2] end：580 − 136 = 444 */
        root.expect(root.near(root.gx(e1, rEnd), 444)
                 && root.near(root.gx(e2, rEnd), 492)
                 && root.near(root.gx(e3, rEnd), 540))

        /* [3] 有 fillWidth 子项 → justify 无效：首项贴左、尾项贴右沿。
         *     若 justify 真的生效了，p1 会被推离左沿，而 p2 不会到 540。 */
        root.expect(root.near(root.gx(p1, rSpacer), 0)
                 && root.near(root.gx(p2, rSpacer), 580 - 40))

        /* [4] 反证：原生 RowLayout 仍然把间距撑大、尾部仍丢一份。
         *     与 smoke_layout_gap.qml [1] 同一条 Qt 行为，判据同样收窄到
         *     "间距明显大于 gap"，不钉内部数字。
         *     这一档**不需要** mapToItem：rawRow 的子项直接挂在自己身上，
         *     RowLayout 的 x 就是 0（它没有内层容器）。 */
        root.expect(w2.x > 48 && w3.x > w2.x + 48)

        /* [5] Column center：(400 − 112) / 2 = 144 */
        root.expect(root.near(root.gy(m1, cCenter), 144)
                 && root.near(root.gy(m2, cCenter), 184)
                 && root.near(root.gy(m3, cCenter), 224))

        /* [6] Column end：400 − 112 = 288 */
        root.expect(root.near(root.gy(n1, cEnd), 288)
                 && root.near(root.gy(n2, cEnd), 328)
                 && root.near(root.gy(n3, cEnd), 368))

        /* [7] 有 fillHeight 子项 → justify 让位，Spacer 吸干余量，
         *     尾项贴底 400 − 32 = 368。 */
        root.expect(root.near(root.gy(q1, cSpacer), 0)
                 && root.near(root.gy(q2, cSpacer), 368))

        Qt.exit(root.mask)
    }
}
