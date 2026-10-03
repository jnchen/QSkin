/****************************************************************************
 * QSkin · 冒烟测试 — M30 查缺补漏（纯函数谱 · 第三份）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 为什么还要第三份 ────────────────────────────────────────────────────
 *
 * `smoke_m30.qml` 守的是 `QSkinCountdown` 的**时间字段与事件**（[4][5]），
 * `smoke_m30_theme.qml` 守的是输入族与 Link 的跨主题侧。**两份都没碰
 * `text`** —— 也就是这个控件唯一"看得见"的那条路：`formatRemaining` 的
 * 三档格式、`toMillis` 的容错、以及 `formatter` 的转调。
 *
 * 这条缝是在收口时补 lint 才浮出来的：`formatter` 是 `var` 属性，qmllint
 * 报 `use-proper-function`，我把它改成"过一层 `_format()`"——**那一刻
 * 等于改了一条没有任何判据守者的绑定**。所以本文件的首要目的不是"多测
 * 几个格式"，而是**让那次重构变成可证伪的**（见 [7] 与变异 G8/G9）。
 *
 * 判据取向与 `QSkinStatistic.formatValue` 的冒烟一致：**纯函数直接喂全谱**，
 * 期望值**手算后写成字面量**，不重跑实现里的公式（那样是拿错误的实现
 * 验证错误的实现 —— M11.1 记过这条）。
 *
 *   [0] `toMillis` 正路：有限数 / `Date` / ISO 串
 *   [1] `toMillis` 坏入参**全部归 0**（不把 NaN 透到屏幕上）
 *   [2] `formatRemaining` 的 `hms` 基本形状与补零
 *   [3] ★ `hms` **不折天**（26 小时必须显示 `26:00:00`，不是 `02:00:00`）
 *   [4] `formatRemaining` 的 `dhms`
 *   [5] `auto` 的两条分支（有天走 dhms / 无天走 hms）
 *   [6] 负数与非数**下钳到 0**（给 `00:00:00`，不给乱码）
 *   [7] ★ `_format()` 的路由：有 `formatter` 用它、没有则回落 `formatRemaining`
 *
 * 位掩码退出码的约定见 smoke_slots.qml 文件头；单文件上限 8 条，
 * 原因见 tools/test.sh 第 0 节（POSIX 只保留低 8 位）。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Contracts 1.0

Item {
    id: root

    width: 600
    height: 400

    property int mask: 0
    property int idx: 0

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    /* ══════════ 夹具 ══════════ */

    /* 时间锚：不用 0（0 是 epoch，容易把期望算错），也不用 Date.now()（门禁要确定性）。 */
    readonly property var t0: new Date(2026, 0, 1, 0, 0, 0).getTime()

    /* ISO 串那一格的期望值**手算**：
     *   1970→2026 共 56 年，其中闰年 1972..2024 共 (2024-1972)/4+1 = 14 个
     *   天数 = 56×365 + 14 = 20454
     *   毫秒 = 20454 × 86400 × 1000 = 1767225600000
     * 写成字面量而不是 `Date.UTC(...)`，是为了不让判据与实现共享同一条算路。 */
    readonly property double isoExpect: 1767225600000

    QSkinCountdown { id: cdProbe; deadline: root.t0 + 10000; now: root.t0; style: "hms" }

    /* [7] 两个对照件：一个自带 formatter，一个不给（必须回落）。 */
    QSkinCountdown {
        id: cdCustom
        deadline: root.t0 + 10000
        now: root.t0
        style: "hms"
        formatter: function (ms, parts) { return "F" + ms + "/" + parts.totalSeconds }
    }
    QSkinCountdown {
        id: cdFallback
        deadline: root.t0 + 10000
        now: root.t0
        style: "dhms"           /* 故意与 hms 的期望不同，好让"回落没发生"现形 */
    }

    /* ══════════ 断言 ══════════ */

    function run() {
        /* [0] toMillis 正路 */
        root.expect(cdProbe.toMillis(1234.5) === 1234.5
                 && cdProbe.toMillis(new Date(2026, 0, 1, 0, 0, 0)) === root.t0
                 && cdProbe.toMillis("2026-01-01T00:00:00Z") === root.isoExpect)

        /* [1] 坏入参全部归 0 —— 一个 NaN 都不许透出去 */
        root.expect(cdProbe.toMillis(null) === 0
                 && cdProbe.toMillis(undefined) === 0
                 && cdProbe.toMillis("不是日期") === 0
                 && cdProbe.toMillis(NaN) === 0
                 && cdProbe.toMillis(Infinity) === 0
                 && cdProbe.toMillis({}) === 0)

        /* [2] hms 基本形状：3661 s → 01:01:01（补零三处） */
        root.expect(cdProbe.formatRemaining(3661000, "hms") === "01:01:01")

        /* [3] ★ hms 不折天：26 h → 26:00:00。
         *     折天的实现会给出 02:00:00 —— 这正是 G8 那一枪打的位。 */
        root.expect(cdProbe.formatRemaining(26 * 3600 * 1000, "hms") === "26:00:00")

        /* [4] dhms：90061 s → 1 天 1 时 1 分 1 秒，天不补零 */
        root.expect(cdProbe.formatRemaining(90061000, "dhms") === "1:01:01:01")

        /* [5] auto 的两条分支 */
        root.expect(cdProbe.formatRemaining(26 * 3600 * 1000, "auto") === "1:02:00:00"
                 && cdProbe.formatRemaining(3600 * 1000, "auto") === "01:00:00")

        /* [6] 负数与非数下钳到 0 */
        root.expect(cdProbe.formatRemaining(-5000, "hms") === "00:00:00"
                 && cdProbe.formatRemaining(NaN, "hms") === "00:00:00"
                 && cdProbe.formatRemaining(-5000, "dhms") === "0:00:00:00")

        /* [7] ★ 路由：有 formatter 就用它的返回值；没给就回落 formatRemaining。
         *     右半边读的是**同一个控件自己算出来的**期望 —— 这里不共享实现，
         *     因为 `formatRemaining` 本身已被 [2]~[6] 逐档钉死。
         *     这条守的正是"_format 这一层"：把 formatter 那支删掉（G9）它就红。 */
        root.expect(cdCustom.text === "F10000/10"
                 && cdFallback.text === cdFallback.formatRemaining(10000, "dhms"))

        /* 自证：8 条断言真的都跑了（「检查了 0 条」与「全过」退出码一样）。 */
        if (root.idx !== 8) root.mask = 255

        Qt.exit(root.mask)
    }

    /* 看门狗：异常会吞掉 Qt.exit。255 → 8 位全亮 = "这个文件炸了"。 */
    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }

    Component.onCompleted: function() { Qt.callLater(root.run) }
}
