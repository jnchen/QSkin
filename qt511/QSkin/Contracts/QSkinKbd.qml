/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinKbd
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 键帽 —— 把"按下 Ctrl + K"这件事画成两枚可以摸到的小方块。
 *
 * ── 为什么不做成两件（M27 裁决六）──────────────────────────────────────
 * shadcn 把 `Kbd` 与 `KbdGroup` 拆成两个导出。本仓不拆，判据与
 * `Collapsible` 那条同源：**Group 不是独立控件，它是 Kbd 的"给一组键"
 * 用法** —— 差别只在键与键之间有没有一道缝。
 *
 * 于是 `keys` 收两种写法：
 *     keys: "Esc"                  一枚
 *     keys: ["Ctrl", "K"]          组合，自动画缝
 * 两者走**同一份**绘制（一个 `Repeater`），没有"组合模式"这条分支。
 *
 * ── 键帽的"厚度"是怎么来的 ──────────────────────────────────────────
 * 每枚键由两个同宽的矩形叠成：
 *     · 底座 —— 高 = keyHeight，颜色 borderStrong
 *     · 键面 —— 高 = keyHeight - thickness，浅底 + 1px 描边
 * 底座比键面**多露出来的那一条**就是厚度。
 *
 * 为什么不用"一条贴底的深色横线"：那条线在圆角处会与键面的圆角打架
 * （要么溢出、要么把角切平）。两层矩形各自圆角，交界处天然干净。
 *
 * `thickness` **不在令牌里**，它是一个固定值（1 或 2）—— 与
 * `QSkinBackTop.arrowRatio` 同类的判断：令牌管色与间距，不管"一枚记号自己
 * 的笔画有多粗"。四家只有 shadcn 有这个件，且它的 Kbd 其实**没有**厚度
 * （`border bg-muted`）—— 这里加上，是因为桌面端（本项目的目标形态）
 * 的键帽在工具栏与快捷键提示里出现，没有厚度会与普通 Tag 混淆。
 * 要关掉它：`thickness: 0`。
 *
 * ── 尺寸：两档，且**总宽可算** ────────────────────────────────────────
 *     implicitWidth  = Σ 每枚键宽 + keyGap ×（键数 - 1）
 *     每枚键宽       = max(minKeyWidth, 文字宽 + keyPaddingX × 2)
 *     implicitHeight = keyHeight
 * 三个数全部可读 → 像素侧"键帽个数与总宽"能写等号（见 M27 像素核验）。
 *
 * ⚠ 上面这条等号**只在委托项声明了 `implicitWidth` 之后才成立**。
 *   M27 收口时实测到：委托项原先是个裸 `Item`（`implicitWidth` 恒 0），
 *   `RowLayout` 只能用"字体就绪之前"的旧宽度定尺寸，且此后**永不重跑** ——
 *   于是这个属性报 29/56/85/25，而键帽实际画成 31.06 / 38.75+22 / 85.33。
 *   完整证据与成因写在下面那个委托项的注释里（不在这里复述第二份）。
 *   → 读这个属性时请记住它现在才是真值；旧日志里的 29/56/85/25 是缺陷值。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    /** "Esc" 或 ["Ctrl", "K"] —— 两种写法同一份绘制 */
    property var keys: []

    /* ══════════════════════ 外观 ══════════════════════ */

    /** sm | md */
    property string size: "md"

    /** 键帽厚度（底座露出来的高度）。0 = 关掉立体感 */
    property int thickness: root.size === "sm" ? 1 : 2

    /* ══════════════════════ 尺寸 ══════════════════════ */

    readonly property int keyHeight: root.size === "sm" ? 18 : 22
    readonly property int minKeyWidth: root.size === "sm" ? 18 : 22
    readonly property int fontSize: root.size === "sm" ? Theme.font.xs : Theme.font.sm
    readonly property int keyPaddingX: Theme.space.xs
    readonly property int keyGap: Theme.space.xs
    readonly property int keyRadius: root.size === "sm" ? Theme.radius.sm : Theme.radius.md

    /* ══════════════════════ 归一化 ══════════════════════ */

    /** 把 keys 归一成字符串数组。空串与非法项**丢掉**（不画空键帽）。 */
    readonly property var keyList: {
        var k = root.keys
        if (k === null || k === undefined) return []
        if (typeof k === "string") return k.length > 0 ? [k] : []
        if (k.length === undefined) return []
        var out = []
        for (var i = 0; i < k.length; ++i) {
            var s = String(k[i])
            if (s.length > 0) out.push(s)
        }
        return out
    }

    /** 键数。供像素核验核对"画了几枚" */
    readonly property int keyCount: root.keyList.length

    /* ══════════════════════ 几何 ══════════════════════ */

    implicitWidth: row.implicitWidth
    implicitHeight: root.keyHeight

    width:  implicitWidth
    height: implicitHeight

    /* ══════════════════════ 无障碍 ══════════════════════ */

    Accessible.role: Accessible.StaticText
    Accessible.name: root.keyList.join(" + ")
    Accessible.description: qsTr("快捷键")

    /* ══════════════════════ 绘制 ══════════════════════ */

    QSkinRow {
        id: row

        anchors.left: parent.left
        anchors.top: parent.top
        gap: root.keyGap

        Repeater {
            model: root.keyList

            /* delegate 抽成**顶层 Component**（`capComp`），不写成内联 ——
             * 内联 delegate 在 qmllint 眼里是一个新作用域，里面引用 `root`
             * 与 `Theme` 会被判 Unqualified access（本件首跑 17 条警告全
             * 来自这里）。`QSkinList` 的 `rowComp` 也是这个写法。 */
            delegate: capComp
        }
    }

    /* ── 这个 delegate 的绑定会引用外层 id（root / Theme），qmllint 报
     * Unqualified access —— `delegate:` 开出的是一个**新的组件作用域**，
     * 静态检查不去链上外层。
     *
     * ⚠ 把它抽成顶层 Component **不解决**这件事：本件首跑是内联 delegate
     * （17 条），抽成 `capComp` 之后仍有 14 条 —— 换形态只是把警告挪了位置。
     * 本仓已把这个坑查清并写在 `QSkinCalendar.qml` 的文件头（那里有四份最小
     * 复现的实测记录），处置取**第三条**：局部关掉这条警告。运行时引用完全
     * 正确（默认的 Unbound 行为就是沿上下文链查找）；换成
     * `pragma ComponentBehavior: Bound` 会给**整个文件**换一套作用域规则，
     * 为一个控件引入它不划算。QSkinSelect / QSkinList / QSkinMenu / QSkinDatePicker
     * 都是这么做的。 */
    // qmllint disable unqualified
    Component {
        id: capComp

        Item {
            id: capSlot

            property int index
            property var modelData

            /* ⚠⚠ 尺寸必须走 `implicitWidth` / `implicitHeight` ——
             *    **只写 `width` / `height` 会静默少留宽度**，这是 M27 像素核验
             *    量出来的真缺陷，不是风格问题。原话照录：
             *
             *    这个委托项是一个**裸 `Item`**，`implicitWidth` 默认 0。
             *    父级是 `QSkinRow` —— 内部一个 `RowLayout`。Qt Quick Layouts 拿
             *    不到子项的 implicit 尺寸时，会退而用子项的 `width` 当尺寸提示，
             *    而这个"读一次"发生在**字体就绪之前**：那一刻 `capText` 还是
             *    回退字体的度量（"Esc" 21、"Ctrl" 22），布局据此定下
             *    `RowLayout.implicitWidth` 与每枚键帽的 x 位置，然后把
             *    子项 `implicitWidth` 视为恒 0 —— **再也没有任何东西变化，
             *    于是布局永不重跑**。
             *
             *    等 Consolas 真正就绪（本机实测：等宽 7.69px/字，
             *    "Esc"→23.06、"Ctrl"→30.75），`width` 的绑定重算、键帽按新宽度
             *    **画出去**，可是布局还停在旧数上：
             *
             *      k1「Esc」  RowLayout w=29   而 capSlot 实宽 31.06  → 超出组件自身
             *      k2「Ctrl,K」RowLayout w=56   而两格实宽 38.75 + 22，
             *                  第二格被放在 x=34（= 旧宽 30 + 缝 4）→ **缝被吃掉，
             *                  两枚键帽直接贴住**（裁图肉眼已确认）
             *      k4「Alt」  RowLayout w=25   而 capSlot 实宽 31.06  → 差 6.06
             *
             *    证据链：`.cache/probe_m27px/p8.qml` 把同一帧的
             *      `RowLayout.implicitWidth` / 每格 `width` / 每格 `implicitWidth`
             *      和一张抓图一起打出来（`.cache/_p8.log` + `.cache/probe_m27px/p8.png`），
             *      三者一对就露。属性侧与冒烟测试当时**全绿** —— 因为没有任何
             *      断言问过"这一格比布局以为的宽了多少"。同一类缺陷本批第二例
             *      （第一例是 `QSkinUpload` 的行没有 `y`）。
             *
             *    给了 implicit 尺寸之后，字体一就绪 `implicitWidth` 就会变
             *    → 布局被标脏 → 重跑，x 位置与 `QSkinKbd.implicitWidth` 一起回到真值。
             */
            implicitWidth: Math.max(root.minKeyWidth, capText.implicitWidth + root.keyPaddingX * 2)
            implicitHeight: root.keyHeight

            width: implicitWidth
            height: implicitHeight

            /* 底座：厚度的来源。它比键面矮，多出来的那条就是厚度 */
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: root.keyHeight
                radius: root.keyRadius
                color: Theme.color.borderStrong
            }

            /* 键面 */
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Math.max(0, root.keyHeight - root.thickness)
                radius: root.keyRadius
                color: Theme.color.bgSubtle
                border.width: 1
                border.color: Theme.color.border

                Text {
                    id: capText

                    /* 居中于**键面**（不是整枚键帽）：实物键帽的字就印在
                     * 上面那块上。底座只是厚度，文字跟着它偏下去是错的。 */
                    anchors.centerIn: parent
                    text: capSlot.modelData
                    color: Theme.color.fgSecondary
                    font.family: Theme.font.monoFamily
                    font.pixelSize: root.fontSize
                }
            }
        }
    }
    // qmllint enable unqualified
}
