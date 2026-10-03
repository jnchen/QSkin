/****************************************************************************
 * QSkin · 冒烟测试 3/3 — 主题令牌（Theme.patch / reset / 明暗切换）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件要守住的一类隐蔽故障 ──────────────────────────────────────
 *
 * Theme.light 与 Neutral.light 是**同一个 JS 对象**（Theme.qml 里直接
 * `property var light: Neutral.light`）。如果 patch() 写成
 *
 *     set[group] = merged          // set 就是那个共享对象
 *
 * 那么它改的是默认值本身，reset() 再取 Neutral.light 拿回来的还是改过的
 * 那份 —— 令牌被永久污染，且污染会跨过 reset 一直留到进程结束。
 * 断言 [3] 专门盯这个。
 *
 * 顺带一提，靠 `root.light = root.light` 这种自赋值来"触发绑定刷新"在 QML
 * 里并不可靠：属性写入时引擎可能判定值未变化而直接跳过通知。断言 [2] 盯这个。
 *
 * 位掩码退出码的约定见 smoke_slots.qml 文件头。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int mask: 0
    property int idx: 0

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    QSkinButton { id: b; text: "Token" }

    function run() {
        /* [0] 三份令牌集合都在 */
        root.expect(Theme.light !== null && Theme.dark !== null && Theme.active !== null)

        var md0 = Theme.size.controlMd
        var h0  = b.implicitHeight

        Theme.patch("size", { controlMd: md0 + 8 })

        /* [1] patch 改写了令牌值 */
        root.expect(Theme.size.controlMd === md0 + 8)

        /* [2] patch 能触发绑定刷新，控件高度跟着变 */
        root.expect(b.implicitHeight === md0 + 8)

        Theme.reset()

        /* [3] reset 真的恢复了默认值 —— patch 不许原地污染 Neutral */
        root.expect(Theme.size.controlMd === md0)

        /* [4] 恢复后控件高度也回到原值 */
        root.expect(b.implicitHeight === h0)

        var lightBg = Theme.color.bg
        var lightFg = Theme.color.fg

        Theme.mode = "dark"

        /* [5] 切到深色，背景色确实变了 */
        root.expect(Theme.color.bg !== lightBg)

        /* [6] active 指向深色集合 */
        root.expect(Theme.active === Theme.dark)

        Theme.mode = "light"

        /* [7] 切回浅色完全还原 */
        root.expect(Theme.color.bg === lightBg && Theme.color.fg === lightFg)

        Qt.exit(root.mask)
    }

    Component.onCompleted: function() { Qt.callLater(root.run) }
}
