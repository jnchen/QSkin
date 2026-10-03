/****************************************************************************
 * QSkin · 主题装载测试 — M26：TreeSelect / Cascader / Tabs 内容区 /
 *                          Transfer / ColorPicker / AutoComplete / Mentions
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这一份量什么、不量什么
 * ════════════════════════════════════════════════════════════════════════
 * 量的是「**四家换肤之后，这一批的皮肤确实换成了这一家**」。
 *
 * 不量**渲染出来的颜色**。七件里五件的面板外壳是 `Slots.selectOverlay`、
 * 触发器底板是 `Slots.inputBackground` —— 那些颜色的最终去向在**像素**上，
 * 已经由 `.cache/_verify_m26px.py`（五张图 · 四家亮色 + tdesign 暗色）
 * 逐像素核过了。这里再量一遍属性只会量到同一批绑定的中间值，
 * 不是独立算路。
 *
 * 所以本文件的判据分三类：
 *   ① **刻度**：控件的行高 / 内边距 / 触发器高 / 页签高 —— 它们是
 *      `Theme.size.*` / `Theme.space.*` 的直接绑定，逐家能对上，且
 *      `controlSm/Md/Lg` 四家**确实有分歧**（前提账在 [1]）。
 *   ② **外壳**：`overlayItem` 装的是不是**这一家自己**的那一格插槽，
 *      以及它上报的 `extender`。`extender` 用**现场造一个实例**读出，
 *      不从控件里反推（被测量不能当基准）。
 *   ③ **名单**：21 格白名单不许被这一批碰坏（本批零新增插槽 —— 裁决三）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 断言清单（位掩码退出码，见 tools/test.sh 文件头；上限 8 条）
 * ════════════════════════════════════════════════════════════════════════
 *   [0] 白名单账目：21 格 / 六个具名反例不在 / 白名单外的键被安静丢掉 /
 *       install↔reset 往返（`label` 回到 `basicLabel`）
 *   [1] 前提账：**有分歧**的令牌（controlSm/Md/Lg · radius.md · brand ·
 *       divider）至少取到两个值；**四家共用**的（space.md · space.xs ·
 *       chipInset 的实际值）记录下来 —— 后者没有鉴别力，别拿它当判据
 *   [2] 槽里装的是**这一家自己的**那四格（selectOverlay / inputBackground /
 *       label / tabIndicator），且四家的外壳确实是四个不同的 Component
 *   [3] 五件浮层件：`overlayItem !== null`，且 `overlayExtender` 等于
 *       这一家插槽自己上报的 `extender`（2 组不同值 → 有鉴别力）
 *   [4] 纵向刻度：TreeSelect / Cascader / AutoComplete 高 = controlMd；
 *       Mentions 高 = controlLg×2；Tabs 的 tabHeight = controlLg、
 *       contentSpacing = space.md、有内容区时总高 = 三段和
 *   [5] 行高与内边距：三件的 rowHeight = controlMd、padding = space.md；
 *       Mentions.inputHeight = controlLg×2；Transfer 行高 = controlMd、
 *       标题条高 = controlSm
 *   [6] 暗色：四家下 M26 的**几何逐位不变**，而 `Theme.color.bg` 必须
 *       与亮色**不同**（后者证明模式真的切了，前者证明这批件不是靠
 *       明暗两套尺寸凑出来的）
 *   [7] 收尾：`Slots.reset()` 后回到 Basic（21 格 · label · selectOverlay），
 *       且 `Theme.mode` 回到 "light"
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

    width: 1200
    height: 900

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    function check(block) {
        var ok = false
        try { ok = block() === true } catch (e) { ok = false }
        root.expect(ok)
    }

    function all(conds) {
        for (var i = 0; i < conds.length; ++i)
            if (conds[i] !== true) return false
        return true
    }

    /* ══════════════════ 换肤区间底座（与 smoke_m25_theme 同一份）══════════════════ */

    /** 换肤 → 量 → 换回。**所有**要读"当下这一家"的值都必须在这个区间里读。 */
    function one(theme, fn) {
        var v = null
        theme.apply()
        try { v = fn() } finally { theme.remove() }
        return v
    }

    function perTheme(fn) {
        return [ root.one(TDesign, fn),
                 root.one(AntDesign, fn),
                 root.one(ArcoDesign, fn),
                 root.one(Shadcn, fn) ]
    }

    /** 数值版：`fn` 返回 `{ a: 实际值, t: 当家令牌 }`，**在区间内**成对读。
     *  期望值来自令牌本身，所以"改了令牌忘了改控件"会红，
     *  而"两边一起改"不会 —— 那是设计变更，不是缺陷。 */
    function collectEq(fn) {
        var pairs = root.perTheme(function () {
            var p = fn()
            if (p === null || p === undefined || p.a === undefined)
                return { eq: false, a: "nil" }
            return { eq: p.a === p.t, a: root.sig(p.a) }
        })
        var ok = true
        var vals = []
        for (var i = 0; i < pairs.length; ++i) {
            if (!pairs[i].eq) ok = false
            vals.push(pairs[i].a)
        }
        return { ok: ok, values: vals }
    }

    /** 值的**可比签名**：数字取两位小数，颜色对象走整数通道，
     *  其余对象（Component / QObject）按**引用**取号。
     *
     *  ⚠ 最后那条 `obj#n` 不能省成 `"?"` —— 对 Component 这种拿不到标量的
     *  值，一律返回同一个字符串会让 `distinctCount` 把"四家四个不同的外壳"
     *  算成 1。那是一条**静默**的错判（[2] 的"四家必须四个不同 Component"
     *  会永远为假或永远为真，看你怎么写），M26 第一趟就是这么撞上去的。 */
    property var ids: []

    function sig(v) {
        if (v === undefined || v === null) return "nil"
        if (typeof v === "number") return String(Math.round(v * 100) / 100)
        if (typeof v === "boolean") return String(v)
        if (typeof v === "string") return v
        if (v.r !== undefined) {
            cvt.c = v
            return Math.round(cvt.c.r * 255) + ","
                   + Math.round(cvt.c.g * 255) + ","
                   + Math.round(cvt.c.b * 255)
        }
        var i = root.ids.indexOf(v)
        if (i < 0) {
            root.ids.push(v)
            i = root.ids.length - 1
        }
        return "obj#" + i
    }

    function distinctCount(arr) {
        var seen = []
        for (var i = 0; i < arr.length; ++i) {
            var s = root.sig(arr[i])
            if (seen.indexOf(s) < 0) seen.push(s)
        }
        return seen.length
    }

    Item { id: cvt; visible: false; width: 0; height: 0; property color c: "transparent" }

    /** 这一格的插槽自己上报的阴影外扩量（`extender`）。
     *  **现场造一个实例来读** —— 不从控件里反推：控件上的
     *  `overlayExtender` 正是被检查的那条绑定，拿它当基准就是自证。 */
    function slotExtender(comp) {
        if (comp === undefined || comp === null) return "nil"
        var o = comp.createObject(root)
        if (o === null || o === undefined) return "nil"
        var v = o.extender
        o.destroy()
        return v
    }

    /* ══════════════════ 夹具 ══════════════════ */

    property var tree: [
        { id: "zj", label: "浙江", children: [
            { id: "hz", label: "杭州" }
        ] },
        { id: "js", label: "江苏", children: [] }
    ]

    property var people: [
        { id: "a", label: "甲" },
        { id: "b", label: "乙" }
    ]

    Component { id: fakeComp; Item { } }

    Component {
        id: bodyPane

        Item { implicitHeight: 50 }
    }

    QSkinTreeSelect   { id: ts;  nodes: root.tree;   textRole: "label"; value: "hz" }
    QSkinCascader     { id: cas; nodes: root.tree;   textRole: "label"; value: ["zj"] }
    QSkinAutoComplete { id: ac;  options: root.people; textRole: "label"; openOnFocus: false }
    QSkinMentions     { id: mn;  options: root.people; textRole: "label" }
    QSkinColorPicker  { id: cp;  value: "#1677FF" }

    QSkinTabs {
        id: tabsPlain
        model: ["一", "二"]
    }

    QSkinTabs {
        id: tabsBody
        model: ["一", "二"]
        contentHeight: 80
        contentDelegate: bodyPane
    }

    QSkinTransfer {
        id: tr
        dataSource: [ { key: "a", label: "甲" } ]
        titles: ["待选", "已选"]
    }

    /* ══════════════════════════════════════════════════════════════════════
     * 跑
     * ══════════════════════════════════════════════════════════════════════ */

    function run() {
        Slots.reset()
        Theme.mode = "light"

        /* ───────────── [0] 白名单账目 ───────────── */
        root.idx = 0
        root.check(function () {
            var names = Slots.slotNames
            var countOk = names.length === 21

            /* 六个具名反例：它们是上一批**刻意不新开**的格子，各有归属 */
            var banned = ["anchorInk", "floatPlate", "backTopArrow",
                          "pageBackArrow", "menuPanel", "sidebarCollapseArrow"]
            var bannedOk = true
            for (var i = 0; i < banned.length; ++i)
                if (names.indexOf(banned[i]) >= 0) bannedOk = false

            var labelRef = Slots.label
            var ovRef    = Slots.selectOverlay
            var ibRef    = Slots.inputBackground

            /* 白名单外的键被**安静地丢掉**（不报错、不占格）*/
            Slots.install({ anchorInk: fakeComp, floatPlate: fakeComp })
            var filterOk = Slots.slotNames.length === 21
                           && Slots.label === labelRef

            Slots.install({ label: fakeComp })
            var installedOk = Slots.label === fakeComp

            Slots.reset()
            var backOk = Slots.slotNames.length === 21
                         && Slots.label === labelRef
                         && Slots.selectOverlay === ovRef
                         && Slots.inputBackground === ibRef
                         && Slots.label === Slots.basicLabel

            /* 每一格的 `basic*` 兜底都在，且 reset 后 `Slots.<格>` 就是它 */
            var missing = []
            for (var k = 0; k < names.length; ++k) {
                var prop = "basic" + names[k].charAt(0).toUpperCase()
                           + names[k].slice(1)
                if (Slots[prop] === undefined || Slots[names[k]] !== Slots[prop])
                    missing.push(names[k])
            }

            return countOk && bannedOk && filterOk && installedOk
                   && backOk && missing.length === 0
        })

        /* ───────────── [1] 前提账 ───────────── */
        root.idx = 1
        root.check(function () {
            /* 有分歧的：拿它们当判据才有鉴别力 */
            var diverge = [
                function () { return Theme.size.controlSm },
                function () { return Theme.size.controlMd },
                function () { return Theme.size.controlLg },
                function () { return Theme.radius.md },
                function () { return Theme.color.brand },
                function () { return Theme.color.divider }
            ]
            for (var i = 0; i < diverge.length; ++i)
                if (root.distinctCount(root.perTheme(diverge[i])) < 2) return false

            /* 四家**共用**的：记录下来，别拿它当判据。
             *
             * `chipInset` 是个好例子 —— 它的算式是
             *     max(Theme.space.xs, round((controlMd - controlSm) / 2))
             * 而 `space.xs` 四家都是 4，于是四家都落在 4：即使实现里
             * 写死一个 4，这条也照样绿。**这不是缺陷**，是这枚令牌在
             * 四家里的取值恰好相同；写在这里是为了让"它没有鉴别力"
             * 这件事一直可见（真值断言在 tests/smoke_m26.qml [5]）。 */
            var uniform = [
                function () { return Theme.space.md },
                function () { return Theme.space.xs },
                function () { return Theme.font.sm },
                function () { return cp.chipInset }
            ]
            for (var k = 0; k < uniform.length; ++k)
                if (root.distinctCount(root.perTheme(uniform[k])) !== 1) return false

            return true
        })

        /* ───────────── [2] 槽里装的是这一家自己的那四格 ───────────── */
        root.idx = 2
        root.check(function () {
            var table = [
                { th: TDesign,    overlay: TDesign.tdSelectOverlay,
                  bg: TDesign.tdInputBackground,       label: TDesign.tdLabel,
                  tab: TDesign.tdTabIndicator },
                { th: AntDesign,  overlay: AntDesign.adSelectOverlay,
                  bg: AntDesign.adInputBackground,     label: AntDesign.adLabel,
                  tab: AntDesign.adTabIndicator },
                { th: ArcoDesign, overlay: ArcoDesign.acSelectOverlay,
                  bg: ArcoDesign.acInputBackground,    label: ArcoDesign.acLabel,
                  tab: ArcoDesign.acTabIndicator },
                { th: Shadcn,     overlay: Shadcn.scSelectOverlay,
                  bg: Shadcn.scInputBackground,        label: Shadcn.scLabel,
                  tab: Shadcn.scTabIndicator }
            ]

            var ok = true
            var seen = []
            for (var i = 0; i < table.length; ++i) {
                var r = table[i]
                /* 同步调用 —— 这个闭包在本次迭代里就被求值了，不存在
                 * "循环变量被后面几圈改掉"那类问题（那是异步才有的）。 */
                var got = root.one(r.th, function () {
                    return [ Slots.selectOverlay, Slots.inputBackground,
                             Slots.label, Slots.tabIndicator, Slots.slotNames.length ]
                })
                if (got[0] !== r.overlay || got[1] !== r.bg
                    || got[2] !== r.label || got[3] !== r.tab) ok = false
                if (got[4] !== 21) ok = false
                seen.push(got[0])
            }

            /* 四家必须是**四个不同**的外壳 —— 不然"接上了主题"这件事
             * 从属性上根本量不出来（四家同一个 Component 就白装了）*/
            return ok && root.distinctCount(seen) === 4
        })

        /* ───────────── [3] 五件浮层的壳 ───────────── */
        root.idx = 3
        root.check(function () {
            var rows = root.perTheme(function () {
                return {
                    ctl:   ts.overlayExtender,
                    theme: root.slotExtender(Slots.selectOverlay),
                    mounted: ts.overlayItem !== null && cas.overlayItem !== null
                             && ac.overlayItem !== null && cp.overlayItem !== null
                             && mn.overlayItem !== null
                }
            })

            var ok = true
            var vals = []
            for (var i = 0; i < rows.length; ++i) {
                if (!rows[i].mounted) ok = false           /* 五个壳都装上了 */
                if (rows[i].ctl !== rows[i].theme) ok = false
                vals.push(rows[i].ctl)
            }
            /* arco 报 2、其余报 3 或 4 —— 至少要取到两个不同的值 */
            return ok && root.distinctCount(vals) >= 2
        })

        /* ───────────── [4] 纵向刻度 ───────────── */
        root.idx = 4
        root.check(function () {
            var hTs  = root.collectEq(function () {
                return { a: ts.implicitHeight, t: Theme.size.controlMd } })
            var hCas = root.collectEq(function () {
                return { a: cas.implicitHeight, t: Theme.size.controlMd } })
            var hAc  = root.collectEq(function () {
                return { a: ac.implicitHeight, t: Theme.size.controlMd } })
            var hMn  = root.collectEq(function () {
                return { a: mn.implicitHeight, t: Theme.size.controlLg * 2 } })
            var hTab = root.collectEq(function () {
                return { a: tabsPlain.tabHeight, t: Theme.size.controlLg } })
            var gTab = root.collectEq(function () {
                return { a: tabsBody.contentSpacing, t: Theme.space.md } })
            var hBody = root.collectEq(function () {
                return { a: tabsBody.implicitHeight,
                         t: Theme.size.controlLg + Theme.space.md + 80 } })

            var ok = hTs.ok && hCas.ok && hAc.ok && hMn.ok
                     && hTab.ok && gTab.ok && hBody.ok

            /* 鉴别力：触发器那一档与页签总高必须**真的**随主题变
             * （arco 的 controlLg = 36、shadcn 的 controlMd = 36）*/
            var disc = root.distinctCount(hTs.values) >= 2
                       && root.distinctCount(hMn.values) >= 2
                       && root.distinctCount(hBody.values) >= 2
            return ok && disc
        })

        /* ───────────── [5] 行高与内边距 ───────────── */
        root.idx = 5
        root.check(function () {
            var rTs  = root.collectEq(function () {
                return { a: ts.rowHeight,  t: Theme.size.controlMd } })
            var rCas = root.collectEq(function () {
                return { a: cas.rowHeight, t: Theme.size.controlMd } })
            var rAc  = root.collectEq(function () {
                return { a: ac.rowHeight,  t: Theme.size.controlMd } })
            var rTr  = root.collectEq(function () {
                return { a: tr.rowHeight,  t: Theme.size.controlMd } })

            var pTs  = root.collectEq(function () {
                return { a: ts.padding,  t: Theme.space.md } })
            var pCas = root.collectEq(function () {
                return { a: cas.padding, t: Theme.space.md } })
            var pAc  = root.collectEq(function () {
                return { a: ac.padding,  t: Theme.space.md } })

            var hMnIn = root.collectEq(function () {
                return { a: mn.inputHeight, t: Theme.size.controlLg * 2 } })
            var hTrHead = root.collectEq(function () {
                return { a: tr._headHeightOf(0), t: Theme.size.controlSm } })
            /* 面板内边距也吃主题（浮层外壳自己的 padding 归插槽，这里量控件侧）*/
            var pCp = root.collectEq(function () {
                return { a: cp.themePadding, t: Theme.space.xs } })

            var ok = rTs.ok && rCas.ok && rAc.ok && rTr.ok
                     && pTs.ok && pCas.ok && pAc.ok
                     && hMnIn.ok && hTrHead.ok && pCp.ok

            var disc = root.distinctCount(rTs.values) >= 2
                       && root.distinctCount(hTrHead.values) >= 2
                       && root.distinctCount(hMnIn.values) >= 2
            return ok && disc
        })

        /* ───────────── [6] 暗色：几何不变，而模式确实切了 ───────────── */
        root.idx = 6
        root.check(function () {
            /* 这批件的几何只读 `size.*` / `space.*`，而这两组在明暗里
             * **同一份**。写下来是为了让"哪天有人把尺寸也做成明暗两套"
             * 这件事有回应 —— 那时候要么改这条，要么承认它是缺陷。 */
            var geoms = function () {
                return [ ts.implicitHeight, cas.implicitHeight, ac.implicitHeight,
                         mn.implicitHeight, tabsPlain.tabHeight,
                         tabsBody.implicitHeight, tr.rowHeight,
                         tr._headHeightOf(0), cp.implicitWidth ]
            }

            var themes = [TDesign, AntDesign, ArcoDesign, Shadcn]
            var ok = true
            for (var i = 0; i < themes.length; ++i) {
                themes[i].apply()

                Theme.mode = "light"
                var gl = geoms()
                var bl = root.sig(Theme.color.bg)

                Theme.mode = "dark"
                var gd = geoms()
                var bd = root.sig(Theme.color.bg)

                Theme.mode = "light"
                themes[i].remove()

                /* 模式没真换 → 下面那条"几何不变"就没有意义（前提账）*/
                if (bl === bd) ok = false
                for (var k = 0; k < gl.length; ++k)
                    if (gl[k] !== gd[k]) ok = false
            }
            return ok
        })

        /* ───────────── [7] 收尾 ───────────── */
        root.idx = 7
        root.check(function () {
            Slots.reset()
            return Slots.slotNames.length === 21
                   && Slots.label === Slots.basicLabel
                   && Slots.selectOverlay === Slots.basicSelectOverlay
                   && Slots.inputBackground === Slots.basicInputBackground
                   && Theme.mode === "light"
        })

        Qt.exit(root.mask)
    }

    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }

    /* 推迟一轮再断言：尺寸绑定由 polish 阶段求值（见 smoke_sizes.qml 的
     * 时序说明）—— [4]/[5]/[6] 读的全是布局结果。 */
    Component.onCompleted: function () {
        try {
            Qt.callLater(root.run)
        } catch (e) {
            Qt.exit(255)
        }
    }
}
