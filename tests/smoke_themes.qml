/****************************************************************************
 * QSkin · 冒烟测试 7 — 主题矩阵（M3）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 四套主题逐一 apply → 验证令牌注入 → remove → 验证还原。
 * 守住的是 M3 反向验证的核心承诺：主题只能通过 Theme.install /
 * Slots.install 影响系统，且互不残留。
 *
 * 注意：install 是异步生效吗？不是 —— Theme.install / Slots.install
 * 都是同步函数，断言可以紧跟其后（见 smoke_slots.qml）。
 *
 * 位掩码退出码的约定见 smoke_slots.qml 文件头。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0
import QSkin.Theme.AntDesign 1.0
import QSkin.Theme.ArcoDesign 1.0
import QSkin.Theme.Shadcn 1.0

Item {
    id: root

    property int mask: 0
    property int idx: 0

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    Component.onCompleted: function() { Qt.callLater(root.run) }

    function run() {
        /* [0] TDesign：品牌蓝 #0052D9（--td-brand-color） */
        TDesign.apply()
        root.expect(Theme.color.brand === "#0052D9" && Slots.buttonBackground !== null)

        /* [1] Ant：#1677FF、圆角 6（borderRadius）、控件高 32 */
        AntDesign.apply()
        root.expect(Theme.color.brand === "#1677FF"
                    && Theme.radius.md === 6
                    && Theme.size.controlMd === 32)

        /* [2] Arco：#165DFF、圆角 4、控件高 32（但 sm=28/lg=36 与 Ant 不同） */
        ArcoDesign.apply()
        root.expect(Theme.color.brand === "#165DFF"
                    && Theme.radius.md === 4
                    && Theme.size.controlSm === 28
                    && Theme.size.controlLg === 36)

        /* [3] shadcn：primary 近黑 #18181B、圆角 6、控件高 36（h-9） */
        Shadcn.apply()
        root.expect(Theme.color.brand === "#18181B"
                    && Theme.radius.md === 6
                    && Theme.size.controlMd === 36)

        /* [4] shadcn 深色：primary 反转成白（反色按钮签名） */
        Theme.mode = "dark"
        root.expect(Theme.color.brand === "#FAFAFA" && Theme.color.onBrand === "#18181B")
        Theme.mode = "light"

        /* [5] remove 后令牌完全还原（Neutral 出厂值） */
        Shadcn.remove()
        root.expect(Theme.color.brand === "#7C3AED"
                    && Theme.size.controlMd === 32
                    && Theme.size.controlLg === 40)

        /* [6] remove 后插槽回到 Basic */
        root.expect(Slots.buttonBackground !== null && Slots.buttonBackground !== root._never)

        /* [7] 换肤不死循环：Ant → shadcn 直切也干净 */
        AntDesign.apply()
        Shadcn.apply()
        root.expect(Theme.color.brand === "#18181B")
        Shadcn.remove()
        root.expect(Theme.color.brand === "#7C3AED")

        Qt.exit(root.mask)
    }

    property var _never: null
}
