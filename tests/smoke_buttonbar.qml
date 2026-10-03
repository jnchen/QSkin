/****************************************************************************
 * QSkin · 冒烟测试 —— M9.x：ButtonBar 异步测量收敛
 *
 * 断言写法见 tools/test.sh 文件头：≤ 8 条，bit n = 断言 [n]。
 *
 * ── 这个文件守的是什么 ──────────────────────────────────────────────────
 * M9.x 发现的一个真 bug：两个按钮的 ButtonBar，其中一个按钮量不出真实
 * 宽度（只露出一个 / 右边被裁）。根因有两半，都很隐蔽：
 *
 *   1. QSkinButton 的 implicitWidth 经四层 Loader 异步收敛
 *      （32 → 真实值 88 / 60），ButtonBar 在 Component.onCompleted
 *      只量一轮就锁死，之后没有事件把它拉回来；
 *   2. 横排分支给子项写了 width，此后 measure() 若优先读 width，
 *      就会一直读到那个陈旧值，implicitWidth 的收敛再也传不进来。
 *
 * 修法是「哨兵 + 优先级」两半配套：
 *   · implicitSum 把子项隐式尺寸纳入依赖图，收敛时驱动 relayout；
 *   · measure() 优先读 implicitWidth，保证量到的是当前真值。
 *
 * 本测试在「首轮测量之后」再断言，专门覆盖第 1 半 —— 也就是必须等
 * Loader 收敛完（多帧 + 事件循环）才有正确结果的特性。断言在 600ms
 * 的 Timer 里跑；Component.onCompleted 里读到的还是 32，那是正常的。
 *
 * [0] 两个按钮的隐式尺寸之和 > 单按钮高度（说明哨兵读到了真实值，
 *     而不是 Loader 未加载时的最小值）
 * [1] 横排模式下 flatW == 两按钮 implicitWidth 之和 + gap（无陈旧值）
 * [2] 两个按钮互不重叠、且都不越出 bar 宽度（不被裁）
 * [3] 两个按钮的实际宽度都等于各自的 implicitWidth（没被写坏）
 * [4] implicitSum 只读属性等于两按钮 implicit 宽高之和（可测性钩子）
 * [5] 隐藏一个按钮后 implicitSum 变小（visible 过滤契约）
 * [6] 窄约束（width 200）下必须堆叠，且 implicitWidth ≤ 200
 *     —— 守「去掉 width: implicitWidth 后 widthConstrained 判定仍成立」
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int failures: 0

    /** bit n = 断言 [n] 失败 */
    function bit(n, ok) { if (!ok) root.failures |= (1 << n) }

    /* ── 被测对象 ─────────────────────────────────────────────── */

    /* 两个按钮 + fill: true。放在一个显式定宽的 Item 里（裸 Item，
     * 不是 Layout）—— fill 在这里是 no-op，但正因如此宽度会 hug，
     * 于是「两个按钮是否都按真实尺寸排布」这件事会被直接暴露出来：
     * 一旦测量锁死在 32，第二个按钮就会溢出容器。 */
    Item {
        id: host
        x: 0; y: 0
        width: 400
        height: 80

        ButtonBar {
            id: bar
            fill: true
            align: "end"
            gap: 16

            QSkinButton { id: btnGhost; text: "重置"; variant: "ghost" }
            QSkinButton { id: btnPrimary; text: "提交表单" }
        }
    }

    /* 另一组资产：窄约束下必须堆叠（M3 死锁修复的回归哨兵）。
     * 这条同时验证「去掉 width: implicitWidth 显式绑定」没有破坏
     * widthConstrained 判定 —— 它的依据正是 width ≠ implicitWidth。 */
    ButtonBar {
        id: narrowBar
        x: 0; y: 160
        width: 200

        QSkinButton { text: "确定继续" }
        QSkinButton { text: "保存草稿"; variant: "ghost" }
        QSkinButton { text: "放弃更改"; variant: "text" }
    }

    /* ── 断言 ─────────────────────────────────────────────────── */

    Timer {
        interval: 600
        running: true
        repeat: false
        onTriggered: root.check()
    }

    function check() {
        /* [0] 两个按钮的 implicitWidth 都必须大于 controlHeight(32) ——
         *     文案「重置」(2 字) / 「提交表单」(4 字) 加内边距必然更宽。
         *     若还停在 32，说明 Loader 收敛没被纳入依赖图。 */
        root.bit(0, btnGhost.implicitWidth > 40 && btnPrimary.implicitWidth > 40)

        /* [1] flatW 必须等于真实之和 + gap。修复前这里是 32+16+60=108，
         *     而真实值应为 88+16+60=164。 */
        var flatW = btnPrimary.width + btnGhost.width + bar.gap
        root.bit(1, Math.abs(bar.implicitWidth - flatW) < 0.5)

        /* [2] 两个按钮必须互不重叠且都不越界 —— 这是「只露出一个」的直接
         *     反面。修复前 ghost.x=48 而 primary 宽 88，两者压在一起。 */
        var overlap = (btnPrimary.x < btnGhost.x + btnGhost.width)
                   && (btnGhost.x < btnPrimary.x + btnPrimary.width)
        root.bit(2, !overlap
                   && btnPrimary.x >= -0.5
                   && (btnGhost.x + btnGhost.width) <= bar.width + 0.5)

        /* [3] 写坏检查：按钮的实际 width 必须等于自己的 implicitWidth，
         *     不能被 measure/assign 逻辑改掉。 */
        root.bit(3, Math.abs(btnGhost.width - btnGhost.implicitWidth) < 0.5
                   && Math.abs(btnPrimary.width - btnPrimary.implicitWidth) < 0.5)

        /* [4] 哨兵求和暴露成只读属性，且等于两个按钮 implicit 之和
         *     （宽 + 高）。这是可测性钩子，也顺带验证它没被算错。 */
        var expectSum = (btnGhost.implicitWidth + btnGhost.implicitHeight)
                      + (btnPrimary.implicitWidth + btnPrimary.implicitHeight)
        root.bit(4, Math.abs(bar.implicitSum - expectSum) < 0.5)

        /* [5] 可见性过滤：隐藏一个按钮后，它的尺寸不应再计入总和。
         *     kids() 会跳过 visible === false 的子项，这是布局契约的一部分
         *     （条件性按钮的场景：权限不足时不渲染"删除"）。 */
        var sumVisible = bar.implicitSum
        btnGhost.visible = false
        var sumHidden = bar.implicitSum
        root.bit(5, sumHidden < sumVisible)

        /* [6] 窄约束堆叠回归：width 200 < 三按钮 flatW → 必须堆叠。
         *     这条守的是「去掉 width: implicitWidth 显式绑定之后，
         *     widthConstrained（width ≠ implicitWidth）判定依然成立」。 */
        root.bit(6, narrowBar.stacked && narrowBar.implicitWidth <= 200)

        Qt.exit(Math.min(255, root.failures))
    }
}
