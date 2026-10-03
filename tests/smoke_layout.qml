/****************************************************************************
 * QSkin · 冒烟测试 6 — 布局撑满语义（fill）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件守住的是 QSkin 最隐蔽的一个地基陷阱 ──────────────────────────
 *
 * Row / Column / Grid 内部是 Qt Quick Layouts。**Layouts 决定子项尺寸
 * 用的是 implicitWidth，不是 width** —— 而这三个组件恰好都定义了
 * implicitWidth（用来实现 hug）。
 *
 * 于是用户写的
 *
 *     QSkinRow { width: page.width }      // ✗ 被静默忽略，行退化成 hug
 *     Rectangle { width: page.width }   // ✓ 有效（Rectangle 没定义 implicitWidth）
 *
 * 两种写法一行之差、行为天壤之别，而且**没有任何报错**。
 * 这个 bug 是 M2 主题的截图验证抓出来的：示例头部一行的 Spacer 从来
 * 没把右侧按钮顶到行尾，之前所有跑测试的人都以为布局是对的。
 *
 * 正确写法是 fill: true（等价 Layout.fillWidth）。本文件逐项验证：
 * hug 是默认、fill 能撑满、Rectangle 的旧写法不受影响。
 *
 * 位掩码退出码的约定见 smoke_slots.qml 文件头。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    width: 600; height: 800

    property int mask: 0
    property int idx: 0

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    function near(a, b) { return Math.abs(a - b) < 0.5 }

    /* 容器坐标 —— 子项的 `x`/`y` 是相对**内层 layout** 的局部坐标。
     * 本文件所有档位的内层恰好都落在容器原点，两种读法同值；但那是巧合
     * 而不是保证（M29 的 center/end 档就断了）。说明见
     * smoke_layout_justify.qml 文件头「坐标系」。 */
    function gx(it, host) { return it.mapToItem(host, 0, 0).x }

    QSkinColumn {
        id: page
        x: 10; y: 10
        width: 580

        /* 默认：hug */
        QSkinRow {
            id: rHug; height: 30
            Text { text: "AAA" }
            Rectangle { width: 40; height: 20; color: "red" }
        }

        /* fill: true → 撑满，Spacer 把尾巴顶到行尾 */
        QSkinRow {
            id: rFill; height: 30; fill: true
            Text { text: "AAA" }
            Spacer { }
            Rectangle { width: 40; height: 20; color: "red"; id: rFillTail }
        }

        /* 显式 fill: false → 仍 hug（width: xxx 写了也会被布局忽略） */
        QSkinRow {
            id: rOff; height: 30; fill: false
            Rectangle { width: 40; height: 20; color: "red"; id: rOffTail }
        }

        /* Column 同理 */
        QSkinColumn {
            id: cFill; fill: true; height: 30
            Rectangle { width: 40; height: 20; color: "blue" }
        }

        /* Grid：不 fill 时 avail 由内容宽决定，auto-fit 会算错列数 */
        QSkinGrid {
            id: gFill; fill: true; minChildWidth: 160
            Rectangle { width: 40; height: 20; color: "green" }
            Rectangle { width: 40; height: 20; color: "green" }
            Rectangle { width: 40; height: 20; color: "green" }
        }

        QSkinGrid {
            id: gHug; minChildWidth: 160
            Rectangle { width: 40; height: 20; color: "green" }
        }

        /* Rectangle 没有 implicitWidth → 旧写法仍然有效 */
        Rectangle { width: 580; height: 1; color: "#000000"; id: divider }
    }

    Component.onCompleted: function() { Qt.callLater(root.run) }

    function run() {
        /* [0] Row 默认 hug */
        root.expect(rHug.width < 580)

        /* [1] fill: true 撑满列宽 */
        root.expect(root.near(rFill.width, 580))

        /* [2] Spacer 真的把尾元素顶到了行尾（行 = rFill 这一条） */
        root.expect(root.near(root.gx(rFillTail, rFill), 580 - 40))

        /* [3] fill: false 保持 hug */
        root.expect(near(rOff.width, 40) && near(root.gx(rOffTail, rOff), 0))

        /* [4] Column 的 fill 同样生效 */
        root.expect(root.near(cFill.width, 580))

        /* [5] Grid fill 后 auto-fit 按真实宽度算列数
         *     (580 + 12) / (160 + 12) = 3.38 → 3 列 */
        root.expect(gFill.columnCount === 3)

        /* [6] Grid 不 fill 时是 hug，列数不会凭空变成 3 */
        root.expect(gHug.width < 580 && gHug.columnCount === 1)

        /* [7] Rectangle 旧写法向后兼容 */
        root.expect(root.near(divider.width, 580))

        Qt.exit(root.mask)
    }
}
