/****************************************************************************
 * QSkin · 冒烟测试 — M25 的主题接线
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这一轮的主题故事：**一格新插槽都没有**，而且九件里有**一件根本不读令牌**
 * ════════════════════════════════════════════════════════════════════════
 * 前几轮的主题测试，主体都是"逐家数插槽实现"（谁覆盖了哪一格、装上的是不是
 * 自家那一份）。M25 的九件**一格都没开**（裁决四，理由写在
 * `src/contracts/qmldir` 的 M25 段里，`Slots` 仍是 21 格）。
 *
 * 于是这份文件的主题账换了三个问法：
 *   · 名单**没有**被撑大（四家都不许新开格）—— [0] / [2]
 *   · 令牌**真的**通到了九件的取色/取尺寸处    —— [3] ~ [7]
 *   · 例外是 `QSkinAffix`：它**一格令牌都不读**，因为它不画一笔
 *     （只把内容沿 y 平移），这是一条要被守住的**设计事实**，不是遗漏 —— [7]
 *
 * ════════════════════════════════════════════════════════════════════════
 * [1] 是**前提账**，不是又一条断言 —— 而且它有两半
 * ════════════════════════════════════════════════════════════════════════
 * 后面每一条"某属性等于当家的令牌"都隐含一个前提：**四家的那个令牌真的
 * 不一样**。要是四家共用同一个值，那么"等于当家的令牌"与"写死一个常量"
 * 是同一句话，那条断言永远不会红 —— 而它看起来像有个守卫。
 * （M20 踩过：那一轮初版主张分歧在"开态底色"，可 shadcn 的
 *  `brandSubtle === bgSunken`，那一枪无论怎么打都不会红。）
 *
 * 所以这里把"先算一遍"单独做成一条断言：它红了说明的是**后面几条的鉴别力
 * 没了**，而不是"某个控件画错了"。两种红要能分开。
 *
 * 但"先算一遍"也把我自己的期望算出来两处错（本轮首跑就红了）：
 *     bgElevated 四家全是 #FFFFFF、space.xxs/xs/sm/lg/md 四家是同一套刻度。
 * 于是 [1] 的第二半专门**记录**这批"四家共用"的令牌 —— 它们不是缺陷，
 * 是事实；记录下来是为了让"下面某几条其实没有鉴别力"这件事**一直可见**：
 * 凡是"某处 == `bgElevated` / `space.*`"的断言，只能钉住**语义**
 * （"面板底就是浮层底"、"页头内边距就是 lg"），不能当作"令牌线路通了"的证据。
 * 真正证明那几条线路的是 #99 的装载侧变异（把某家的令牌改掉，再看控件跟不跟）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 五条采集纪律（前三条来自 M23/M24，④ 来自本轮上一批，⑤ 是本轮新加的）
 * ════════════════════════════════════════════════════════════════════════
 * ① **期望值必须在 `apply()` 区间之内读。** 出了区间读到的是上一家的数。
 * ② **`fn` 抛异常也必须把主题摘掉**（`one()` 用 `try / finally`），
 *    否则一处失败会变成满屏乱码。
 * ③ **`Theme.color.*` 是十六进制字符串，不是 color 对象** —— 判等只能走
 *    `sameTokenQ`（过一遍 `property color` 再比）。
 * ④ **`color` 属性读进 JS 拿到的是"活引用"，不是快照。** 任何"区间内采集、
 *    区间外判等"的写法都会把**四家读成同一份**（当前主题的值），而报告长成
 *    "控件根本没跟主题"。所以颜色读数一律在区间内 `sig()` 过一遍带回签名。
 * ⑤ **挂了 `Behavior on color` 的底色，区间内也读不到真值 —— 必须现场造实例。**
 *    换主题会让绑定重算，`Behavior` 接手动画，而本节是**同步**读：
 *    拿到的是动画**起点**（上一家的值，通常是 Neutral 的）。
 *    造实例时**把状态一起给**（`createObject(root, {...})`）—— 初始求值不算
 *    "变化"，`Behavior` 不介入。M20 在 `BasicToggleBackground` 上记过同一条，
 *    本轮它从"某个插槽的坑"升级成"**任何有状态底色的件**都适用"。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 本轮两个"探针找到了错误对象"的坑（都被实测抓出来）
 * ════════════════════════════════════════════════════════════════════════
 * · **`ringOf(mb)` 命中的不是菜单条的环，而是它内部第一个 `QSkinButton` 自己的环**
 *   —— DFS 先撞上子件。两者的 `border.color` 都是 `focus`（颜色那条照样绿），
 *   但半径一个等于 `Theme.radius.sm`、一个是"按钮圆角 + 焦点间隙"的派生量，
 *   于是断言会红在一个**根本不是被测件**的对象上。区分只能靠**结构信号**：
 *   控件自己的环是 `anchors.fill: parent`，即"尺寸等于控件尺寸"（`selfRing`）。
 *   这与 M23 记的"不要用颜色定位容器"是同一条：**用结构，不用值**。
 * · **`plateOf` 用 `o.border === undefined` 排除焦点环，把真底板一起判掉了**
 *   —— 底板的 `border` 组是存在的（`border.width: 1`、色透明）。
 *   于是探针永远返回 null，"五档状态色"整段静默失效。改用"铺满本行"这个
 *   结构信号（`.cache/_diag2_m25_theme.qml`：`plateCand count=1` 而旧探针一项不认）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 断言清单（位掩码退出码，见 tools/test.sh 文件头；上限 8 条）
 * ════════════════════════════════════════════════════════════════════════
 *   [0] 白名单账目：21 格 / 六个具名反例不在 / 白名单外的键被丢 /
 *                   真装两格后 reset 逐格回到 Basic（含 basic* 存在性）
 *   [1] **前提账（两半）**：四家**真有分歧**的那些（brand · border ·
 *       bgSunken · fgSecondary · divider · focus · brandSubtle · bgSubtle ·
 *       radius.sm/md/lg · size.controlSm/Md/Lg）必须至少两种值；
 *       四家**共用同一个值**的那些（bgElevated · space.*）必须恰好一种 ——
 *       后半是**记录**，它让"哪些断言没有鉴别力"这件事一直看得见
 *   [2] 四家换肤都不许动这份名单（仍是 21，且 `label` 回到 Basic，
 *       且六个具名反例在四家装好之后依然不在名单里）
 *   [3] QSkinBackTop：圆球两档（静息 / hover）的底色与描边都等于当家令牌；
 *       箭头端色 = fgSecondary / brand（走 ShapePath）；`showing` 是纯滚动量，
 *       四家逐位相同。**颜色一律现场造实例**（纪律 ⑤）
 *   [4] QSkinAnchor：竖轨 = divider、活动记号 = brand 且几何由 rowTop/inkWidth
 *       决定、焦点环 = focus + focusRing + radius.sm
 *   [5] QSkinCommand：面板底 / 边框 / 圆角、输入分隔线、三层行高与三档字号
 *   [6] QSkinPageHeader + QSkinSidebar：页头分隔线与字号/内边距；侧栏三档
 *       `_bg` / `_radius` / `_margin` 与内边缘线；**外加"sidebar 档与 floating
 *       档的底色在四家下都不同"**（把两档写反了它也会红 —— 换肤不动的量）
 *   [7] QSkinMenubar + QSkinNavigationMenu + QSkinSidebarItem 的令牌接线（焦点环走
 *       `selfRing`；侧栏五档状态色现场造实例），外加 QSkinAffix
 *       「一格令牌都不读」这条设计事实
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

    /* ══════════════════ 遍历辅助（与 smoke_m24_theme 同一份）══════════════ */

    function collect(item, pred, out, d) {
        if (item === null || item === undefined || d > 16) return
        if (pred(item)) out.push(item)
        var ch = item.children
        if (ch === undefined) return
        for (var i = 0; i < ch.length; ++i) root.collect(ch[i], pred, out, d + 1)
    }

    function findIn(item, pred) {
        var out = []
        root.collect(item, pred, out, 0)
        return out.length > 0 ? out[0] : null
    }

    /* ══════════════════ 被测对象 ══════════════════ */

    /* BackTop 需要一个真 Flickable 才会 showing（且 showing 必须与主题无关）。
     * `contentY: 500` 是声明期绑定的常量 —— 没有动画，四家读到的是同一帧。
     *
     * 只有**这一个**静态实例：它的用途是 `showing`（纯布尔，没有 Behavior）。
     * 颜色读数一律走 `btComp` 现场造（纪律 ⑤）—— 静态实例的圆球底色在被
     * 换主题重算之后，区间内读到的是动画起点。 */
    Flickable {
        id: fl

        x: 0
        y: 0
        width: 100
        height: 100
        contentWidth: 100
        contentHeight: 1000
        contentY: 500
    }

    QSkinBackTop {
        id: btIdle

        x: 10
        y: 10
        width: 40
        height: 40
        target: fl
        threshold: 400
    }

    QSkinAnchor {
        id: anchor

        x: 120
        y: 10
        width: 160
        model: ["一", "二", "三"]
        offsets: [0, 100, 200]
        anchorOffset: 0
        itemHeight: 30
        inkWidth: 2
    }

    QSkinCommand {
        id: cmd

        x: 10
        y: 120
        width: 420
        model: [
            { heading: "建议", items: [{ text: "新建文件" }, { text: "打开设置" }] }
        ]
    }

    QSkinPageHeader {
        id: ph

        x: 460
        y: 120
        width: 400
        title: "标题"
        subtitle: "副标题"
        showBack: true
    }

    QSkinSidebar {
        id: sidebar

        x: 10
        y: 400
        height: 300
        animated: false
        model: [{ header: "分组" }, { text: "首页" }]
    }

    QSkinSidebar {
        id: sidebarFloat

        x: 280
        y: 400
        height: 100
        animated: false
        variant: "floating"
        visible: false
    }

    QSkinSidebar {
        id: sidebarInset

        x: 500
        y: 400
        height: 100
        animated: false
        variant: "inset"
        visible: false
    }

    QSkinMenubar {
        id: mb

        x: 10
        y: 720
        model: [{ text: "文件", items: ["新建"] }, { text: "编辑", items: ["撤销"] }]
    }

    QSkinNavigationMenu {
        id: nav

        x: 400
        y: 720
        model: [{ text: "产品" }, { text: "文档" }]
    }

    QSkinSidebarItem {
        id: sbiIdle

        x: 10
        y: 800
        width: 200
        height: 40
        text: "首页"
    }

    QSkinSidebarItem {
        id: sbiActive

        x: 240
        y: 800
        width: 200
        height: 40
        text: "首页"
        active: true
    }

    QSkinSidebarItem {
        id: sbiActiveHot

        x: 470
        y: 800
        width: 200
        height: 40
        text: "首页"
        active: true
        hovered: true
    }

    QSkinSidebarItem {
        id: sbiHover

        x: 700
        y: 800
        width: 200
        height: 40
        text: "首页"
        hovered: true
    }

    QSkinSidebarItem {
        id: sbiPress

        x: 930
        y: 800
        width: 200
        height: 40
        text: "首页"
        pressed: true
    }

    /* Affix 无 target：`_itemH` / `_holderH` 与令牌无关，本来就是纯几何 */
    QSkinAffix {
        id: affix

        x: 10
        y: 860
        width: 100
        holderHeight: 60

        Rectangle {
            width: 100
            height: 30
        }
    }

    /* 装配用的假插槽实现 */
    Component {
        id: fakeComp

        Rectangle {
            color: "#FF00FF"
        }
    }

    /* ══ 两个"现场造"的工厂（纪律 ⑤）══
     * 这两件身上都有 `Behavior on color`，而它们的底色正是本文件要读的东西。
     * 静态实例的底色在被换主题重算之后就再也同步读不到了 —— 所以每一档状态
     * 都现场造一个，并把**状态在创建时一起给**。 */

    Component {
        id: btComp

        QSkinBackTop {
            width: 40
            height: 40
        }
    }

    Component {
        id: sbiComp

        QSkinSidebarItem {
            width: 200
            height: 40
            text: "首页"
        }
    }

    /* ══════════════════ 工具 ══════════════════ */

    QtObject {
        id: cvt
        property color c: "#000000"
    }

    function sameColorQ(a, b) {
        if (a === null || a === undefined || b === null || b === undefined) return false
        if (typeof a === "string" || typeof b === "string") return false
        if (a.r === undefined || b.r === undefined) return false
        return Math.round(a.r * 255) === Math.round(b.r * 255)
            && Math.round(a.g * 255) === Math.round(b.g * 255)
            && Math.round(a.b * 255) === Math.round(b.b * 255)
            && Math.round(a.a * 100) === Math.round(b.a * 100)
    }

    function sameTokenQ(actual, token) {
        if (token === undefined || token === null) return false
        cvt.c = token
        return root.sameColorQ(actual, cvt.c)
    }

    /** 值的**可比签名**：数字取两位小数、颜色经 `property color` 规范化
     *  成整数通道（**带 alpha**）。它是"活引用 → 快照"的那个转换点 ——
     *  颜色读数**必须在 apply() 区间内**过这一遍（纪律 ④）。 */
    function sig(v) {
        if (v === undefined || v === null) return "nil"
        if (typeof v === "number") return String(Math.round(v * 100) / 100)
        if (typeof v === "boolean") return String(v)
        if (typeof v === "string") return v
        if (v.r !== undefined) {
            cvt.c = v
            return Math.round(cvt.c.r * 255) + ","
                   + Math.round(cvt.c.g * 255) + ","
                   + Math.round(cvt.c.b * 255) + ","
                   + Math.round(cvt.c.a * 100) / 100
        }
        return "?"
    }

    function distinctCount(arr) {
        var seen = []
        for (var i = 0; i < arr.length; ++i) {
            var s = root.sig(arr[i])
            if (seen.indexOf(s) < 0) seen.push(s)
        }
        return seen.length
    }

    /** 一组"逐主题各自算出来的布尔"是不是全真。
     *  用于那些**比较两处读数**的断言（比不出签名，只能自己判）。 */
    function everyTrue(arr) {
        for (var i = 0; i < arr.length; ++i)
            if (arr[i] !== true) return false
        return true
    }

    function one(theme, fn) {
        var v = null
        theme.apply()
        try {
            v = fn()
        } finally {
            theme.remove()
        }
        return v
    }

    function perTheme(fn) {
        return [ root.one(TDesign, fn),
                 root.one(AntDesign, fn),
                 root.one(ArcoDesign, fn),
                 root.one(Shadcn, fn) ]
    }

    /** 颜色版：`fn` 返回 `{ a: 实际值, t: 当家的令牌 }`，**在区间内**成对读。
     *  判等要走 `sameTokenQ`（`Theme.color.*` 是字符串，`sameColorQ` 会判掉）。 */
    function collectToken(fn) {
        var pairs = root.perTheme(function () {
            var p = fn()
            if (p === null || p === undefined
                || p.a === null || p.a === undefined)
                return { eq: false, a: "nil" }
            return { eq: root.sameTokenQ(p.a, p.t), a: root.sig(p.a) }
        })
        var ok = true
        var vals = []
        for (var i = 0; i < pairs.length; ++i) {
            if (!pairs[i].eq) ok = false
            vals.push(pairs[i].a)
        }
        return { ok: ok, values: vals }
    }

    /** 数值版。**数值是原语，带出区间是安全的。** */
    function collectEq(fn) {
        var pairs = root.perTheme(fn)
        var ok = true
        var vals = []
        for (var i = 0; i < pairs.length; ++i) {
            var p = pairs[i]
            if (p === null || p === undefined || p.a === null || p.a === undefined) {
                ok = false
                continue
            }
            if (p.a !== p.t) ok = false
            vals.push(p.a)
        }
        return { ok: ok, values: vals }
    }

    /** 颜色读数的出口（纪律 ④）。 */
    function collectSig(fn) {
        return root.perTheme(function () { return root.sig(fn()) })
    }

    /** 原语版。**只许给字符串 / 数字 / 布尔**；拿到 color 当场抛异常 ——
     *  这是纪律 ④ 的自执行（写错名字就红，而不是静默四家同一份）。 */
    function collectRaw(fn) {
        var vals = root.perTheme(fn)
        for (var i = 0; i < vals.length; ++i) {
            var v = vals[i]
            if (v !== null && typeof v === "object" && v.r !== undefined)
                throw new Error("LIVE-COLOR-ESCAPE: 颜色读数必须走 collectSig()（纪律 ④）")
        }
        return vals
    }

    /* ── 结构探针 ── */

    /** BackTop 的圆球：既是圆（`radius == width/2`）又带一圈描边。 */
    function ballOf(bt) {
        return root.findIn(bt, function (o) {
            return o.radius !== undefined && o.border !== undefined
                   && o.color !== undefined && o.border.width === 1
                   && Math.abs(o.radius - o.width / 2) < 0.01
        })
    }

    /** ShapePath **不是 Item**（挂在 `Shape.data` 上，不在 `children` 里）——
     *  与 smoke_m24 的 `shapePathOf` 同一手法。 */
    function shapePathOf(host) {
        var shp = root.findIn(host, function (o) {
            return o.data !== undefined && o.preferredRendererType !== undefined
        })
        if (shp === null) return null
        var d = shp.data
        if (d === undefined) return null
        for (var i = 0; i < d.length; ++i)
            if (d[i] !== undefined && d[i].strokeColor !== undefined) return d[i]
        return null
    }

    /** 焦点环：不填色（`color.a == 0`）却带描边的那个矩形。 */
    function ringOf(host) {
        return root.findIn(host, function (o) {
            return o.border !== undefined && o.color !== undefined
                   && o.color.a < 0.001 && o.radius !== undefined
        })
    }

    /** 侧栏行底板：**铺满本行**、有圆角、有底色的那个矩形。
     *
     * ⚠ 不能用"没有描边"来排除焦点环 —— 底板的 `border` 组是存在的
     *   （`border.width: 1`、色透明）。初版写的 `o.border === undefined`
     *   会把真底板一起判掉，于是 `plateOf` 永远返回 null，
     *   "五档状态色"整段静默失效（`check()` 只要拿到 null 就记红，但报出来
     *   的是"结构找不着"，与"色不对"完全两回事）。
     *   实测：`.cache/_diag2_m25_theme.qml` 里 `plateCand count=1  sbi=200x40`，
     *   而旧探针一项都不认。
     *   **"铺满本行"才是那个结构信号**（底板是 `anchors.fill` 的那个）。 */
    function plateOf(sbi) {
        return root.findIn(sbi, function (o) {
            return o.radius !== undefined && o.color !== undefined
                   && Math.abs(o.width - sbi.width) < 0.6
                   && Math.abs(o.height - sbi.height) < 0.6
        })
    }

    /** 控件**自己那一圈**焦点环：铺满整个控件的那个透明矩形。
     *
     * 为什么不能直接用 `ringOf`：后者取 DFS 里**第一个**命中的，而菜单条/
     * 导航菜单内部先放着一排 `QSkinButton`，每个按钮自己也有一个环 ——
     * `ringOf(mb)` 撞上的是**子件**的环。两者的 `border.color` 都是
     * `Theme.color.focus`（所以颜色那条照样绿），但半径一个是
     * `Theme.radius.sm`、另一个是"按钮圆角 + 焦点间隙"的派生量，
     * 于是 `radius === Theme.radius.sm` 会红在一个**根本不是被测件**的对象上。
     * 实测：`mb ringCand count=3`，前两个是 56×28 的按钮环（rr=3|6|4|8），
     * 第三个才是 106×36 的条环（rr=2|4|2|4 = `radius.sm`）。
     * 区分只能靠结构：控件自己的环是 `anchors.fill: parent` ——
     * **尺寸等于控件尺寸**。这与 M23 记的"不要用颜色定位容器"是同一条：用结构。 */
    function selfRing(host) {
        return root.findIn(host, function (o) {
            return o.border !== undefined && o.color !== undefined
                   && o.color.a < 0.001 && o.radius !== undefined
                   && Math.abs(o.width - host.width) < 0.6
                   && Math.abs(o.height - host.height) < 0.6
        })
    }

    /* ── 现场造的取证入口（纪律 ⑤）──
     * **只能在 `apply()` 区间内调用**，而且读到的颜色要在区间内 `sig()` 掉。
     * 造出来的实例不回收：它们的读数已经被 `collectToken` / `collectSig`
     * 在区间内快照成签名，而**回收会打断那次快照**（`collectToken` 是先拿
     * `fn()` 的返回值、再读 `p.a`，中间那一瞬还在区间内 —— 这时对象不能死）。 */

    /** 造一个带 hovered 的 BackTop，返回它的圆球。 */
    function ballFrom(hovered) {
        var o = btComp.createObject(root, { "target": fl,
                                            "hovered": hovered === true })
        return o === null ? null : root.ballOf(o)
    }

    /** 造一个带 hovered 的 BackTop，返回它的箭头（ShapePath）。 */
    function arrowFrom(hovered) {
        var o = btComp.createObject(root, { "target": fl,
                                            "hovered": hovered === true })
        return o === null ? null : root.shapePathOf(o)
    }

    /** 造一个带状态的行，返回它的底板。 */
    function plateFrom(active, hovered, pressed) {
        var o = sbiComp.createObject(root, { "active": active === true,
                                             "hovered": hovered === true,
                                             "pressed": pressed === true })
        return o === null ? null : root.plateOf(o)
    }

    /* ══════════════════════════════════════════════════════════════════
     * 断言
     * ══════════════════════════════════════════════════════════════════ */

    function run() {
        Slots.reset()

        /* ── [0] 白名单账目 ── */
        root.idx = 0
        root.check(function () {
            var names = Slots.slotNames
            var countOk = names.length === 21

            var banned = ["anchorInk", "floatPlate", "backTopArrow",
                          "pageBackArrow", "menuPanel", "sidebarCollapseArrow"]
            var bannedOk = true
            for (var i = 0; i < banned.length; ++i)
                if (names.indexOf(banned[i]) >= 0) bannedOk = false

            var labelRef = Slots.label
            var bgRef = Slots.buttonBackground
            Slots.install({ anchorInk: fakeComp, floatPlate: fakeComp })
            var filterOk = Slots.slotNames.length === 21
                           && Slots.label === labelRef
                           && Slots.buttonBackground === bgRef

            Slots.install({ buttonBackground: fakeComp, label: fakeComp })
            var installedOk = Slots.buttonBackground === fakeComp
                              && Slots.label === fakeComp

            Slots.reset()
            var backOk = Slots.slotNames.length === 21
                         && Slots.label === labelRef
                         && Slots.label === Slots.basicLabel
                         && Slots.buttonBackground === bgRef

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

        /* ── [1] 前提账：分两半（**真有分歧**的 / **四家共用**的）──
         *
         * 前半红了说明的是**后面几条的鉴别力没了**：每一项都至少要有两个
         * 不同的值（不是"四个都不同"—— 有的令牌两家会撞在一起，
         * 那不影响"不等于常量"）。
         *
         * 后半是把"四家共用"的那批**记录**下来：它们不是缺陷，是事实。
         * 记下来的意义是让"下面某几条其实没有鉴别力"一直可见 ——
         * 实测（`.cache/_diag_m25_theme.qml`）：
         *     [1] bgElevated :: n=1 #FFFFFF ×4
         *     [1] space.lg   :: n=1 16 ×4   （space.xxs/xs/sm/md 同样）
         * 初版把这六项也放进"必须有分歧"那一组，于是这一条**从写下起就是红的**
         * —— 红的原因是我的期望错，不是实现错。 */
        root.idx = 1
        root.check(function () {
            var diverge = [
                function () { return Theme.color.brand },
                function () { return Theme.color.border },
                function () { return Theme.color.bgSunken },
                function () { return Theme.color.fgSecondary },
                function () { return Theme.color.divider },
                function () { return Theme.color.focus },
                function () { return Theme.color.brandSubtle },
                function () { return Theme.color.bgSubtle },
                function () { return Theme.radius.sm },
                function () { return Theme.radius.md },
                function () { return Theme.radius.lg },
                function () { return Theme.size.controlSm },
                function () { return Theme.size.controlMd },
                function () { return Theme.size.controlLg }
            ]
            for (var i = 0; i < diverge.length; ++i)
                if (root.distinctCount(root.collectRaw(diverge[i])) < 2)
                    return false

            var uniform = [
                function () { return Theme.color.bgElevated },
                function () { return Theme.space.xxs },
                function () { return Theme.space.xs },
                function () { return Theme.space.sm },
                function () { return Theme.space.lg },
                function () { return Theme.space.md }
            ]
            for (var k = 0; k < uniform.length; ++k)
                if (root.distinctCount(root.collectRaw(uniform[k])) !== 1)
                    return false

            return true
        })

        /* ── [2] 四家换肤都不许动这份名单 ── */
        root.idx = 2
        root.check(function () {
            var basicLabel = Slots.basicLabel
            var banned = ["anchorInk", "floatPlate", "backTopArrow",
                          "pageBackArrow", "menuPanel", "sidebarCollapseArrow"]
            var everyOk = true
            var themes = [TDesign, AntDesign, ArcoDesign, Shadcn]
            for (var i = 0; i < themes.length; ++i) {
                var ok = root.one(themes[i], function () {
                    if (Slots.slotNames.length !== 21) return false
                    for (var b = 0; b < banned.length; ++b)
                        if (Slots.slotNames.indexOf(banned[b]) >= 0) return false
                    return true
                })
                if (!ok) everyOk = false
            }
            Slots.reset()
            return everyOk && Slots.slotNames.length === 21 && Slots.label === basicLabel
        })

        /* ── [3] QSkinBackTop ──
         *
         * 两档（静息 / hover）各读一遍：只读静息档会放过"hover 那条分支
         * 写死了颜色"，而那是这一批唯一一个"鼠标在上面时换一套色"的件。
         *
         * ⚠ **颜色读数一律现场造**（纪律 ⑤）。静态那个 `btIdle` 也能找到圆球、
         *   它的 `border.color` 也读得对，唯独圆球**底色**读不到真值 ——
         *   底色上有
         *       Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
         *   换主题让绑定重算、Behavior 接手动画，而这里是**同步**读：
         *   拿到的是动画起点。四家读到**同一个** `#F3E8FF`（Neutral 的
         *   `brandSubtle`）时的样子，与"主题根本没接上"一模一样。
         *   实测（`.cache/_diag_m25_theme.qml`，静态实例）：
         *       [3] hot.bg  :: ok=false n=1 actual=243,232,255,1 ×4
         *       [3] hot.bd  :: ok=true  n=4      ← 描边没有 Behavior，读得对
         *   现场造实例时**状态在创建时一起给**：初始求值不算"变化"，
         *   Behavior 不介入。同一手法下的实测（`.cache/_diag2_m25_theme.qml`）：
         *       [Q3] td hot bg=242,243,255  ant bg=230,244,255
         *            arco bg=232,243,255    sc  bg=244,244,245
         *   —— 恰好等于四家的 `brandSubtle`。 */
        root.idx = 3
        root.check(function () {
            var bgIdle = root.collectToken(function () {
                var b = root.ballFrom(false)
                return { a: b === null ? null : b.color, t: Theme.color.bgElevated }
            })
            var bdIdle = root.collectToken(function () {
                var b = root.ballFrom(false)
                return { a: b === null ? null : b.border.color, t: Theme.color.border }
            })
            var bgHot = root.collectToken(function () {
                var b = root.ballFrom(true)
                return { a: b === null ? null : b.color, t: Theme.color.brandSubtle }
            })
            var bdHot = root.collectToken(function () {
                var b = root.ballFrom(true)
                return { a: b === null ? null : b.border.color, t: Theme.color.brand }
            })

            /* 箭头端色走 ShapePath（它拿不到 `control`，只能读 `strokeColor`）。
             * ⚠ `strokeColor` 也是 color 属性 → 必须 `collectToken` 在区间内判等。 */
            var strIdle = root.collectToken(function () {
                var p = root.arrowFrom(false)
                return { a: p === null ? null : p.strokeColor, t: Theme.color.fgSecondary }
            })
            var strHot = root.collectToken(function () {
                var p = root.arrowFrom(true)
                return { a: p === null ? null : p.strokeColor, t: Theme.color.brand }
            })

            /* "不等于常量"这一组要能鉴别 —— 与 [1] 的前半同一批令牌。
             * `bgIdle` 不在里面：`bgElevated` 四家同白（见 [1]），
             * 它只证明"静息档画的是浮层底"这条语义。 */
            var distinctOk = root.distinctCount(bdIdle.values) >= 2
                             && root.distinctCount(bgHot.values) >= 2
                             && root.distinctCount(bdHot.values) >= 2
                             && root.distinctCount(strIdle.values) >= 2
                             && root.distinctCount(strHot.values) >= 2

            /* `showing` 是**纯滚动量**：四家逐位相同，且就是 true
             * （contentY 500 > threshold 400，与主题无关）。
             * 布尔量没有 Behavior，静态实例照读。 */
            var showing = root.collectRaw(function () { return btIdle.showing })
            var showOk = root.distinctCount(showing) === 1 && showing[0] === true

            /* 圆球的形状是 `radius = width/2`，与主题令牌无关（它是圆，
             * 不是"跟着圆角令牌走的方块"）。hover 也不改几何。 */
            var b1 = root.ballFrom(false)
            var b2 = root.ballFrom(true)
            var geomOk = b1 !== null && b2 !== null
                         && Math.abs(b1.radius - b1.width / 2) < 0.01
                         && Math.abs(b2.radius - b2.width / 2) < 0.01

            return bgIdle.ok && bdIdle.ok && bgHot.ok && bdHot.ok
                   && strIdle.ok && strHot.ok && distinctOk && showOk && geomOk
        })

        /* ── [4] QSkinAnchor ── */
        root.idx = 4
        root.check(function () {
            var rail = root.findIn(anchor, function (o) {
                return o.width === 1 && o.color !== undefined
            })
            var ink = root.findIn(anchor, function (o) {
                return o.color !== undefined && o.radius !== undefined
                       && Math.abs(o.radius - anchor.inkWidth / 2) < 0.01
                       && o.width === anchor.inkWidth
            })
            var ring = root.ringOf(anchor)
            var foundOk = rail !== null && ink !== null && ring !== null
            if (!foundOk) return false

            var railT = root.collectToken(function () {
                return { a: rail.color, t: Theme.color.divider }
            })
            var inkT = root.collectToken(function () {
                return { a: ink.color, t: Theme.color.brand }
            })
            var ringC = root.collectToken(function () {
                return { a: ring.border.color, t: Theme.color.focus }
            })
            var ringR = root.collectEq(function () {
                return { a: ring.radius, t: Theme.radius.sm }
            })

            /* 记号的几何由**纯函数**决定（rowTop / inkWidth / itemHeight），
             * 与主题无关 —— 它跟着滚动位置走，那是 [4] 在 smoke_m25 里
             * 用真 Flickable 驱动过的那条。这里只确认它不是"跟着令牌走的
             * 一个量"（否则换主题会让记号跳位）。
             *
             * ⚠ 初版在这里写了一条 `collectEq(function(){ return {a: ink.y, t: ink.y} })`
             *   —— 两边读的是**同一个量**，永远相等。那不是断言，是装饰
             *   （"从写下起就不会红"，比没有更糟：它看起来像个守卫）。
             *   改成**逐主题真的比一遍**：记号的位置必须落在
             *   `rowTop(currentIndex)` 上，而且这个位置四家逐位相同。 */
            var rowTopSig = root.collectSig(function () {
                return anchor.rowTop(anchor.currentIndex)
            })
            var geomOk = ink.x === 0
                         && ink.height === anchor.itemHeight
                         && root.everyTrue(root.perTheme(function () {
                                return ink.y === anchor.rowTop(anchor.currentIndex)
                            }))
                         && root.distinctCount(rowTopSig) === 1

            var distinctOk = root.distinctCount(railT.values) >= 2
                             && root.distinctCount(inkT.values) >= 2
                             && root.distinctCount(ringC.values) >= 2

            return railT.ok && inkT.ok && ringC.ok && ringR.ok
                   && geomOk && distinctOk
        })

        /* ── [5] QSkinCommand ── */
        root.idx = 5
        root.check(function () {
            var panel = root.findIn(cmd, function (o) {
                return o.radius !== undefined && o.border !== undefined
                       && o.color !== undefined && o.border.width === 1
                       && Math.abs(o.width - cmd.width) < 0.6
            })
            var div = root.findIn(cmd, function (o) {
                return o.height === 1 && o.color !== undefined
            })
            if (panel === null || div === null) return false

            var panelBg = root.collectToken(function () {
                return { a: panel.color, t: Theme.color.bgElevated }
            })
            var panelBd = root.collectToken(function () {
                return { a: panel.border.color, t: Theme.color.border }
            })
            var panelR = root.collectEq(function () {
                return { a: panel.radius, t: Theme.radius.md }
            })
            var divT = root.collectToken(function () {
                return { a: div.color, t: Theme.color.divider }
            })

            /* 三层行高 + 三档字号：都是"随主题变"的量 */
            var hRow = root.collectEq(function () {
                return { a: cmd.rowHeight, t: Theme.size.controlMd }
            })
            var hHead = root.collectEq(function () {
                return { a: cmd.headingHeight, t: Theme.size.controlSm }
            })
            var hInput = root.collectEq(function () {
                return { a: cmd.inputHeight, t: Theme.size.controlLg }
            })

            /* `panelBg` **不进**这一组：`bgElevated` 四家同白（见 [1]），
             * "面板底等于浮层底"只能钉语义，鉴别力得由下面几条提供。 */
            var distinctOk = root.distinctCount(panelBd.values) >= 2
                             && root.distinctCount(panelR.values) >= 2
                             && root.distinctCount(divT.values) >= 2
                             && root.distinctCount(hRow.values) >= 2
                             && root.distinctCount(hHead.values) >= 2
                             && root.distinctCount(hInput.values) >= 2

            return panelBg.ok && panelBd.ok && panelR.ok && divT.ok
                   && hRow.ok && hHead.ok && hInput.ok && distinctOk
        })

        /* ── [6] QSkinPageHeader + QSkinSidebar ── */
        root.idx = 6
        root.check(function () {
            /* ── 页头：分隔线颜色 + 三个内边距 + 两档字号 ── */
            var pdf = root.collectToken(function () {
                return { a: ph.dividerColor, t: Theme.color.divider }
            })
            var pPad = root.collectEq(function () {
                return { a: ph.padding, t: Theme.space.lg }
            })
            var pGap = root.collectEq(function () {
                return { a: ph.spacing, t: Theme.space.sm }
            })
            var pTSp = root.collectEq(function () {
                return { a: ph.titleSpacing, t: Theme.space.xxs }
            })

            /* 分隔线本体真的铺满页头（通栏），且颜色就是 `dividerColor` */
            var div = root.findIn(ph, function (o) {
                return o.height === 1 && o.color !== undefined
            })
            var divOk = div !== null
                        && Math.abs(div.width - ph.width) < 0.6
                        && root.collectToken(function () {
                               return { a: div.color, t: Theme.color.divider }
                           }).ok

            /* ── 侧栏三档：`_bg` / `_radius` / `_margin` ──
             * `floating` 与 `inset` 都是 bgElevated + radius.lg，但外边距不同；
             * `sidebar`（默认）是 bgSubtle + 无圆角 + 无外边距。
             * 三档一起读才说明"variant 真的分了三支"。 */
            var sSide = root.collectToken(function () {
                return { a: sidebar._bg, t: Theme.color.bgSubtle }
            })
            var sSideR = root.collectEq(function () {
                return { a: sidebar._radius, t: 0 }
            })
            var sSideM = root.collectEq(function () {
                return { a: sidebar._margin, t: 0 }
            })
            var sFloat = root.collectToken(function () {
                return { a: sidebarFloat._bg, t: Theme.color.bgElevated }
            })
            var sFloatR = root.collectEq(function () {
                return { a: sidebarFloat._radius, t: Theme.radius.lg }
            })
            var sFloatM = root.collectEq(function () {
                return { a: sidebarFloat._margin, t: Theme.space.sm }
            })
            var sInset = root.collectToken(function () {
                return { a: sidebarInset._bg, t: Theme.color.bgElevated }
            })
            var sInsetM = root.collectEq(function () {
                return { a: sidebarInset._margin, t: 0 }
            })

            /* 内边缘线走 divider；它是"贴内容那一边的那条线" */
            var edge = root.findIn(sidebar, function (o) {
                return o.width === 1 && o.color !== undefined
            })
            var edgeOk = edge !== null
                         && root.collectToken(function () {
                                return { a: edge.color, t: Theme.color.divider }
                            }).ok

            /* `sFloat` / `sInset` 的底色都是 `bgElevated`（四家同白，见 [1]），
             * 所以它们**不进**"必须有分歧"这一组。真正证明"三档真的分了三支"
             * 的是下面这条：**sidebar 档与 floating 档的底色在四家下都不同**
             * （`bgSubtle` vs `bgElevated`）。只读"各自等于自己的令牌"是读不出
             * 这一条的 —— 把两档的 `_bg` 写反，那两条照样绿。 */
            var splitOk = root.everyTrue(root.perTheme(function () {
                return root.sig(sidebar._bg) !== root.sig(sidebarFloat._bg)
            }))
            var distinctOk = root.distinctCount(pdf.values) >= 2
                             && root.distinctCount(sSide.values) >= 2

            return pdf.ok && pPad.ok && pGap.ok && pTSp.ok && divOk
                   && sSide.ok && sSideR.ok && sSideM.ok
                   && sFloat.ok && sFloatR.ok && sFloatM.ok
                   && sInset.ok && sInsetM.ok && edgeOk && splitOk && distinctOk
        })

        /* ── [7] Menubar / NavigationMenu / SidebarItem / Affix ── */
        root.idx = 7
        root.check(function () {
            /* ── 菜单条与导航菜单：尺寸档 + 焦点环 ── */
            var mbH = root.collectEq(function () {
                return { a: mb.itemHeight, t: Theme.size.controlMd }
            })
            var mbGap = root.collectEq(function () {
                return { a: mb.gap, t: Theme.space.xxs }
            })
            var mbPad = root.collectEq(function () {
                return { a: mb.padding, t: Theme.space.xxs }
            })
            /* `barHeight` 是**派生量**：itemHeight + padding*2。
             * ⚠ 别写成"四家同一个数" —— shadcn 的 `itemHeight` 是 36、
             *   其余三家 32，于是 `barHeight` 恰好有两种值（36 / 40）。
             *   初版写的是 `distinctCount === 1`，从写下起就是红的
             *   （又一次"期望错，不是实现错"）。派生式的两边都在区间内算，
             *   换肤真的能改它。 */
            var mbBar = root.collectEq(function () {
                return { a: mb.barHeight, t: mb.itemHeight + mb.padding * 2 }
            })

            /* 焦点环：**控件自己那一圈**（`selfRing`），不是内部按钮的 ——
             * 见 `selfRing` 的注释：`ringOf` 会先撞上子件里的环。 */
            var mbRing = root.selfRing(mb)
            var navRing = root.selfRing(nav)
            var ringOk = mbRing !== null && navRing !== null
                         && root.collectToken(function () {
                                return { a: mbRing.border.color, t: Theme.color.focus }
                            }).ok
                         && root.collectEq(function () {
                                return { a: mbRing.radius, t: Theme.radius.sm }
                            }).ok
                         && root.collectToken(function () {
                                return { a: navRing.border.color, t: Theme.color.focus }
                            }).ok
                         && root.collectEq(function () {
                                return { a: navRing.radius, t: Theme.radius.sm }
                            }).ok
                         /* 没拿到键盘焦点时环**不可见**（粗细 0）。这条与主题
                          * 无关、四家逐位相同 —— 它排除的正是"粗细写死成 2"，
                          * 那会让"只在键盘导航时显示"这条约定失效。 */
                         && root.distinctCount(root.collectRaw(function () {
                                return mbRing.border.width
                            })) === 1
                         && root.collectRaw(function () {
                                return mbRing.border.width
                            })[0] === 0

            var navPad = root.collectEq(function () {
                return { a: nav.padding, t: Theme.space.xxs }
            })
            var navGap = root.collectEq(function () {
                return { a: nav.gap, t: Theme.space.xs }
            })
            var navPPad = root.collectEq(function () {
                return { a: nav.panelPadding, t: Theme.space.md }
            })
            var navPGap = root.collectEq(function () {
                return { a: nav.panelGap, t: Theme.space.sm }
            })
            var navPOff = root.collectEq(function () {
                return { a: nav.panelOffset, t: Theme.space.xs }
            })
            var navH = root.collectEq(function () {
                return { a: nav.itemHeight, t: Theme.size.controlMd }
            })

            /* ── 侧栏行底板：三档互斥 ──
             * `active` 用 brandSubtle（"我在这一页"）、`hovered` 用 bgSunken
             * （"鼠标在这"）—— 两者必须能**同时被看懂**，所以不能取同一个色。
             * 这条正是"为什么不需要新开一格插槽"的理由：分歧是**状态**，
             * 不是"同一主题里两种必须并存的形态"。 */
            /* 五档状态的底板**结构上都要在**（铺满本行那一块）—— 结构这条走静态
             * 实例（几何/圆角没有 Behavior），颜色那条走现场造。 */
            var structOk = root.plateOf(sbiIdle) !== null
                           && root.plateOf(sbiActive) !== null
                           && root.plateOf(sbiActiveHot) !== null
                           && root.plateOf(sbiHover) !== null
                           && root.plateOf(sbiPress) !== null
            if (!structOk) return false

            /* ⚠ 五档的**色**必须现场造（纪律 ⑤）：底板底色上有 `Behavior on color`，
             *   静态实例在被换主题重算之后，区间内读到的是动画起点。实测
             *   （`.cache/_diag2_m25_theme.qml`，静态实例）：
             *       active      → 243,232,255 ×4 = Neutral 的 brandSubtle
             *       hover/press → 240,240,244 ×4 = Neutral 的 bgSunken
             *   四家一模一样的读数，看起来完全像"主题没接上"。 */
            var tIdle = root.collectSig(function () {
                var p = root.plateFrom(false, false, false)
                return p === null ? null : p.color
            })
            var tActive = root.collectToken(function () {
                var p = root.plateFrom(true, false, false)
                return { a: p === null ? null : p.color, t: Theme.color.brandSubtle }
            })
            /* active 与 hovered 同时成立时，**活动态赢**（互斥的优先级） */
            var tActiveHot = root.collectToken(function () {
                var p = root.plateFrom(true, true, false)
                return { a: p === null ? null : p.color, t: Theme.color.brandSubtle }
            })
            var tHover = root.collectToken(function () {
                var p = root.plateFrom(false, true, false)
                return { a: p === null ? null : p.color, t: Theme.color.bgSunken }
            })
            /* 按下那档盖过活动态 */
            var tPress = root.collectToken(function () {
                var p = root.plateFrom(false, false, true)
                return { a: p === null ? null : p.color, t: Theme.color.bgSunken }
            })
            var idleOk = root.distinctCount(tIdle) === 1
                         && tIdle[0] === root.sig(Qt.rgba(0, 0, 0, 0))

            var plateGeom = root.collectEq(function () {
                var p = root.plateOf(sbiActive)
                return { a: p === null ? null : p.radius, t: Theme.radius.md }
            })
            var sbiH = root.collectEq(function () {
                return { a: sbiActive.itemHeight, t: Theme.size.controlLg }
            })

            /* ── Affix：**一格令牌都不读** ──
             * 它不画一笔（只把内容沿 y 平移），所以四家下 `_holderH` /
             * `_itemH` / `implicitHeight` 必须**逐位相同** —— 这不是"漏了
             * 接令牌"，是它本来就没有皮肤。把它写成断言，是为了让"哪天有人
             * 顺手给它加个底色"这件事有回应。 */
            var affH = root.collectRaw(function () { return affix._holderH })
            var affIH = root.collectRaw(function () { return affix.implicitHeight })
            var affItemH = root.collectRaw(function () { return affix._itemH })
            var affOk = root.distinctCount(affH) === 1 && affH[0] === 60
                        && root.distinctCount(affIH) === 1 && affIH[0] === 60
                        && root.distinctCount(affItemH) === 1 && affItemH[0] === 30

            var distinctOk = root.distinctCount(tActive.values) >= 2
                             && root.distinctCount(tActiveHot.values) >= 2
                             && root.distinctCount(tHover.values) >= 2
                             && root.distinctCount(tPress.values) >= 2

            return mbH.ok && mbGap.ok && mbPad.ok && mbBar.ok
                   && ringOk && navPad.ok && navGap.ok && navPPad.ok
                   && navPGap.ok && navPOff.ok && navH.ok
                   && tActive.ok && tActiveHot.ok && tHover.ok && tPress.ok
                   && idleOk && plateGeom.ok && sbiH.ok && affOk && distinctOk
        })

        Slots.reset()
        Qt.exit(root.mask)
    }

    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }

    Component.onCompleted: function () {
        try {
            Qt.callLater(root.run)
        } catch (e) {
            Qt.exit(255)
        }
    }
}
