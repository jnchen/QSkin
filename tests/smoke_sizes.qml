/****************************************************************************
 * QSkin · 冒烟测试 2/3 — 控件隐式尺寸
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件存在的原因：一个花了很久才查清的假故障 ────────────────────
 *
 * 曾经这里报「md 按钮宽度未包含内容宽度：implicitWidth = 32」，
 * 看起来像是 QSkinButton 的宽度计算写错了 —— 32 恰好等于 contentPadding*2，
 * 也就是说内容宽度贡献了 0，按钮塌成了一个正方形。
 *
 * 逐层拆开测，真相是：
 *
 *   Loader -> Rectangle(implicitWidth 100)    = 100   跟随正常
 *   Loader -> Item -> Loader -> Text          = 80    两层嵌套正常
 *   QSkinRow { Text }                           = 81    Foundation 的 Row 正常
 *   QSkinRow { Loader }                         = 81    Row 里的 Loader 正常
 *   Slots.label                               = 93    文字插槽正常
 *   Slots.buttonContent                       = 0  <== 只有这里断
 *
 * 区别在于：buttonContent 内部的 labelDelegate 是**后置注入**的（先 null，
 * 再由 Binding 赋值）。而 Qt Quick Layouts 把尺寸重算推迟到渲染循环的
 * polish 阶段，不会在绑定求值的那一刻同步完成。所以在
 * Component.onCompleted 里同步读 implicitWidth，读到的是重算之前的值。
 *
 * 实测延迟一读：
 *
 *   Slots.buttonContent   0ms -> 94    16ms -> 94    200ms -> 94
 *   QSkinButton             0ms -> 126   16ms -> 126   200ms -> 126
 *   （126 = 16*2 内边距 + 94 内容宽，完全正确）
 *
 * 也就是说尺寸在**下一个事件循环**就位，早于首帧渲染，界面上看不到跳变。
 * 真正会踩坑的只有「在 Component.onCompleted 里同步读尺寸」这一种写法
 * ——而那正是原先那版测试自己的写法。代码没错，是测量时机错了。
 *
 * 因此本文件用 Qt.callLater 推迟一轮再断言。任何人改动 QSkinButton 的
 * implicitWidth 而忘了这条约束，都会在这里被逮住。
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

    /* ── 被测控件 ──
     * md / sm / lg 刻意用**同一段文字**，这样宽度差异只来自内边距与字号，
     * 断言 [4] 才有意义。 */

    QSkinButton   { id: bMd; text: "Medium Button" }
    QSkinButton   { id: bSm; text: "Medium Button"; size: "sm" }
    QSkinButton   { id: bLg; text: "Medium Button"; size: "lg" }
    QSkinInput    { id: inp; placeholderText: "name" }
    QSkinCheckBox { id: cb;  text: "Remember me" }
    QSkinSwitch   { id: sw }

    function run() {
        /* [0] md 高度等于令牌里的中等控件高度 */
        root.expect(bMd.implicitHeight === Theme.size.controlMd)

        /* [1] sm 更矮 */
        root.expect(bSm.implicitHeight < bMd.implicitHeight)

        /* [2] lg 更高 */
        root.expect(bLg.implicitHeight > bMd.implicitHeight)

        /* [3] 宽度真的包含了内容 —— 这条就是当年塌成 32px 的那条 */
        root.expect(bMd.implicitWidth > bMd.contentPadding * 2)

        /* [4] 同文本下 lg 更宽 */
        root.expect(bLg.implicitWidth > bMd.implicitWidth)

        /* [5] 输入框有默认宽度（Qt 的 TextInput 默认 0，会直接消失） */
        root.expect(inp.implicitWidth > 0
                    && inp.implicitHeight === Theme.size.controlMd)

        /* [6] 勾选框尺寸有效 */
        root.expect(cb.implicitWidth > 0 && cb.implicitHeight > 0)

        /* [7] 开关尺寸有效 */
        root.expect(sw.implicitWidth > 0 && sw.implicitHeight > 0)

        Qt.exit(root.mask)
    }

    /* Qt.callLater 而不是直接跑：见文件头。 */
    Component.onCompleted: function() { Qt.callLater(root.run) }
}
