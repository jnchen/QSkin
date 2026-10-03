/****************************************************************************
 * QSkin · 冒烟测试 — M30 查缺补漏（跨主题侧）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件守的是什么 ──────────────────────────────────────────────────
 *
 * 五档主题（Neutral + 四家）**每一档都要过同 8 条判据**。判据累积在
 * `acc[]` 里，跑完五档才统一 `expect` —— 位掩码只有 8 位，分不了 40 条。
 * 明细打在 stdout 上供人定位，退出码只管"哪一条有档位不成立"。
 *
 *   [0] 成组方位：三枚在一起是 first / middle / last
 *   [1] standalone 的两条边界：组里只有一枚、以及根本不在组里
 *   [2] 底板**四角** first = [r,0,0,r]      ← 读插槽 Rectangle 的实际属性
 *   [3] 底板**四角** middle = [0,0,0,0] 且 last = [0,r,r,0]
 *   [4] 孤立那枚四角全圆 [r,r,r,r]（回归：老消费者逐字不变）
 *   [5] `implicitWidth` 恒 200（有／无前后缀一样）；且无前后缀时
 *       TextInput 的左右 margin == padding（回归）
 *   [6] 密码：`echoMode:"password"` → 内部 TextInput 真的进 Password(2)；
 *       `revealed` → 真的回 Normal(0)
 *   [7] label 的 `link` 变体取色 == `Theme.color.brand`
 *       ⚠ **shadcn 是四家里的例外**（它的 `--primary` 就是近黑 → 取 `fg`）
 *
 * ── ⚠⚠ 本文件最容易写错的一件事：读颜色必须先等动画 ────────────────────
 *
 * `label.color` 上挂着 `Behavior on color { ColorAnimation {...} }`。
 * 切主题那一刻绑定的**目标值**已经算对了，但属性的**当前值**要等动画跑完。
 * "apply() 之后立即读"拿到的是**动画起点** —— 而且这个假读数**看起来
 * 完全合理**（它是上一个主题的合法颜色）。
 *
 * 实测取证见 `.cache/_probe_m30i.qml`：同一实例同一时刻 `font.weight`
 * （无 Behavior）立即跟随 variant，而 `color` 不跟随；等
 * `Theme.motion.fast` 之后 `case "link"` 全部命中。
 *
 * ⇒ **凡是读颜色的门禁，都要走这里的 `settle` 回合。读几何不用**
 *   （几何上没有 Behavior）。
 *
 * 位掩码退出码的约定见 smoke_slots.qml 文件头；单文件上限 8 条，
 * 原因见 tools/test.sh 第 0 节（POSIX 只保留低 8 位）。
 ****************************************************************************/

import QtQuick
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0
import QSkin.Theme.AntDesign 1.0
import QSkin.Theme.ArcoDesign 1.0
import QSkin.Theme.Shadcn 1.0

Item {
    id: root

    width: 1200
    height: 800

    property int mask: 0
    property int idx: 0

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    /* ══════════════ 五档（第 0 档是 Neutral）══════════════ */

    property var themes: [null, TDesign, AntDesign, ArcoDesign, Shadcn]
    property int cur: 0
    property var acc: [true, true, true, true, true, true, true, true]

    function accSet(i, cond) {
        if (!cond) root.acc[i] = false
    }

    /* ══════════════ 夹具 ══════════════ */

    QSkinInputGroup {
        id: grp3
        QSkinInput { id: g1 }
        QSkinInput { id: g2 }
        QSkinInput { id: g3 }
    }
    QSkinInputGroup {
        id: grp1
        QSkinInput { id: solo }
    }
    QSkinInput { id: lonely }

    QSkinInput { id: inpPlain }
    QSkinInput {
        id: inpAffix
        prefix: Component { Rectangle { implicitWidth: 16; implicitHeight: 16 } }
        suffix: Component { Rectangle { implicitWidth: 20; implicitHeight: 20 } }
    }

    QSkinInput { id: inpPw;      echoMode: "password" }
    QSkinInput { id: inpPwShown; echoMode: "password"; revealed: true }

    /* ⚠ `x/y` 是必须的：`-platform offscreen` 会把指针停在 (0,0)，
     * 放在原点的控件会被 `MouseArea` 判成 hover —— 于是 TDesign / Ant
     * 的 `case "link"` 走 `hovered() ? brandHover : brand`，读到 brandHover。
     * （Arco 不看 hovered，所以它反而"对" —— 那种对是巧合，不是证据。）
     * 离原点足够远即可；判据前还会再显式清一次。 */
    QSkinLink { id: lk; text: "LINKM30"; x: 900; y: 700 }

    /* ══════════════ 遍历工具 ══════════════ */

    function collect(item, pred, out, d) {
        if (item === null || item === undefined || d > 16) return
        if (pred(item)) out.push(item)
        var kids = item.children
        if (kids === undefined || kids === null) return
        for (var i = 0; i < kids.length; ++i) root.collect(kids[i], pred, out, d + 1)
    }
    function findAll(item, pred) {
        var out = []
        root.collect(item, pred, out, 0)
        return out
    }
    function findIn(item, pred) {
        var out = root.findAll(item, pred)
        return out.length > 0 ? out[0] : null
    }
    /* TextInput 的 echoMode 是**枚举(number)**；QSkinInput 的是 string ——
     * 这条把两者分开（M30 探针 H 第一版就栽在没分）。 */
    function isTextInput(x) {
        if (x === null || x === undefined) return false
        return typeof x.echoMode === "number" && x.text !== undefined
    }
    /* 底板插槽由 QSkinInput 用 Loader 挂载，插槽根一定带 control（契约）。 */
    function isSlotLoader(x) {
        if (x === null || x === undefined) return false
        return x.item !== undefined && x.item !== null && x.item.control !== undefined
    }
    function isRect(x) {
        if (x === null || x === undefined) return false
        return x.topLeftRadius !== undefined && x.border !== undefined
    }
    function cornersSig(r) {
        return r.topLeftRadius + "," + r.topRightRadius + ","
             + r.bottomRightRadius + "," + r.bottomLeftRadius
    }
    /** 一枚输入框底板插槽里所有 Rectangle 的四角签名 */
    function plateCorners(inp) {
        var lds = root.findAll(inp, root.isSlotLoader)
        var out = []
        for (var j = 0; j < lds.length; ++j) {
            var rs = root.findAll(lds[j].item, root.isRect)
            for (var k = 0; k < rs.length; ++k) out.push(root.cornersSig(rs[k]))
        }
        return out
    }
    function hasCorner(list, sig) { return list.indexOf(sig) >= 0 }

    /* ══════════════ 回合驱动 ══════════════ */

    Timer {
        id: settle
        running: false
        repeat: false
        onTriggered: root.judge()
    }

    Component.onCompleted: Qt.callLater(root.nextTheme)

    function nextTheme() {
        if (root.cur >= root.themes.length) { root.finish(); return }
        var th = root.themes[root.cur]
        if (th === null) {
            Slots.reset()
            Theme.reset()
        } else {
            th.apply()
        }
        /* 读颜色前的沉降窗口 —— 见文件头那段。 */
        settle.interval = Theme.motion.fast + 80
        settle.start()
    }

    /* ══════════════ 判据（每一档都跑同一份）══════════════ */

    function judge() {
        var r = Theme.radius.md
        var nm = root.cur === 0 ? "Neutral"
               : root.cur === 1 ? "TDesign"
               : root.cur === 2 ? "AntDesign"
               : root.cur === 3 ? "ArcoDesign" : "Shadcn"
        var bits = []

        /* [0] 成组方位 */
        var c0 = root.all([g1.groupPosition === "first",
                           g2.groupPosition === "middle",
                           g3.groupPosition === "last"])
        root.accSet(0, c0); bits.push(c0 ? "0:ok" : "0:NG")

        /* [1] standalone 的两条边界 */
        var c1 = root.all([solo.groupPosition === "standalone",
                           lonely.groupPosition === "standalone"])
        root.accSet(1, c1); bits.push(c1 ? "1:ok" : "1:NG")

        /* [2] first 的底板四角 */
        var pc1 = root.plateCorners(g1)
        var c2 = root.hasCorner(pc1, r + ",0,0," + r)
        root.accSet(2, c2); bits.push(c2 ? "2:ok" : "2:NG")

        /* [3] middle 与 last 的底板四角 */
        var pc2 = root.plateCorners(g2)
        var pc3 = root.plateCorners(g3)
        var c3 = root.hasCorner(pc2, "0,0,0,0") && root.hasCorner(pc3, "0," + r + "," + r + ",0")
        root.accSet(3, c3); bits.push(c3 ? "3:ok" : "3:NG")

        /* [4] 孤立那枚四角全圆 */
        var pcL = root.plateCorners(lonely)
        var c4 = root.hasCorner(pcL, r + "," + r + "," + r + "," + r)
        root.accSet(4, c4); bits.push(c4 ? "4:ok" : "4:NG")

        /* [5] implicitWidth 与 margin */
        var tiP = root.findIn(inpPlain, root.isTextInput)
        var tiA = root.findIn(inpAffix, root.isTextInput)
        var c5 = tiP !== null && tiA !== null
              && inpPlain.implicitWidth === 200 && inpAffix.implicitWidth === 200
              && tiP.anchors.leftMargin === inpPlain.padding
              && tiP.anchors.rightMargin === inpPlain.padding
              && tiA.anchors.leftMargin === inpAffix.padding + inpAffix.prefixSlot
              && tiA.anchors.rightMargin === inpAffix.padding + inpAffix.suffixSlot
        root.accSet(5, c5); bits.push(c5 ? "5:ok" : "5:NG")

        /* [6] 密码态 */
        var tiPw = root.findIn(inpPw, root.isTextInput)
        var tiSh = root.findIn(inpPwShown, root.isTextInput)
        var tiNo = root.findIn(inpPlain, root.isTextInput)
        var c6 = tiPw !== null && tiSh !== null && tiNo !== null
              && tiPw.echoMode === TextInput.Password
              && tiSh.echoMode === TextInput.Normal
              && tiNo.echoMode === TextInput.Normal
        root.accSet(6, c6); bits.push(c6 ? "6:ok" : "6:NG")

        /* [7] label 的 link 取色（**已经等过动画**）。
         * ⚠ 这里**不要**去写 `lk.hovered = false` —— 那会改色、再触发一次
         * 动画，于是又读到旧的（等于把上面那个坑原地重挖一遍）。
         * hover 靠夹具的 x/y 挡开，见那段注释。 */
        var l = root.findIn(lk, function (it) {
            return it !== null && it !== undefined
                    && it.text === "LINKM30" && typeof it.font === "object"
        })
        var want = (root.cur === 4) ? Theme.color.fg : Theme.color.brand
        var got = (l === null) ? "#none" : String(l.color)
        var c7 = (l !== null) && (got.toLowerCase() === String(want).toLowerCase())
        root.accSet(7, c7)
        bits.push("7:(" + got + " vs " + want + ")")

        console.log("   [" + nm + "] " + bits.join("  "))

        var th = root.themes[root.cur]
        if (th !== null) th.remove()
        root.cur++
        Qt.callLater(root.nextTheme)
    }

    function all(conds) {
        for (var i = 0; i < conds.length; ++i)
            if (conds[i] !== true) return false
        return true
    }

    /* ══════════════ 收口 ══════════════ */

    function finish() {
        for (var i = 0; i < root.acc.length; ++i) root.expect(root.acc[i])
        if (root.idx !== 8) root.mask = 255
        Qt.exit(root.mask)
    }

    /* 看门狗：五档 × 沉降 ≈ 1 秒内跑完。255 一律不算抓住。 */
    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }
}
