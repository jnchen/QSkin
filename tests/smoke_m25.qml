/****************************************************************************
 * QSkin · 冒烟测试 — M25：Anchor / Affix / BackTop / PageHeader / Command /
 *                        Menubar / NavigationMenu / Sidebar
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这一批第一次以「滚动位置」为状态 —— 于是断言也必须先解决"滚动从哪来"
 * ════════════════════════════════════════════════════════════════════════
 * Anchor / Affix / BackTop 三件的状态**完全由 `contentY` 决定**，而
 * 本项目抓图纪律的头一条是"同一份源码要出同一张图"。落地前定的处置是
 * （COVERAGE.md 第七节「M25 五项裁决」的裁决二）：
 *
 *     **滚动宿主是输入**。三件都吃 `target: Flickable`，自己不造滚动。
 *
 * 这同时解决了测试侧的问题：本文件真的建一个 `Flickable`，然后
 * `scroller.contentY = N` —— 瞬时赋值、不经动画、不碰真实输入。
 * 于是"跟随滚动"这件事在这里是被**真驱动**的，不是被模拟的。
 *
 * ⚠ 这也意味着：**这一条只能在真 Flickable 上验。** 把 `target` 设成
 * 一个假对象（只造 `contentY` 属性的 QtObject）会通过每一条纯函数断言，
 * 却放过"`mapToItem` 到底有没有被通知到"这一类缺陷 —— 下面 [4] 里
 * 有一处正是这么抓出来的（见那份注释）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么 [1] 要把纯函数铺得这么开
 * ════════════════════════════════════════════════════════════════════════
 * ScrollUtil 七个函数与 FuzzyMatch 的打分器都是**全整数**运算，
 * 所以它们的期望值可以写等号、可以从文件头那段规则**手推**出来 ——
 * 这是本仓能做到的最强的一类断言（M24 的二维码、M20 的令牌同理）。
 *
 * 手推的依据写在每条断言旁边：比如 `score("ab","abc") === 16` 里的
 * 16 = 7（'a' 落在词首：CHAR 1 + BOUNDARY 6）+ 9（'b' 紧邻：CHAR 1
 * + CONSEC 8）。**没有距离惩罚项**，所以 `"ab"` 在 `"a_b"` 上得 14
 * （1+6 与 1+6）而**不是** 8 —— 这两条一起才说明"词首 6 分 < 相邻 8 分"
 * 这个序是真的。
 *
 * FuzzyMatch 还有一份更强的独立算路在 `.cache/_m25fuzzy_probe.js`（node，
 * 穷举所有合法对齐）。那份与这里不重复：那边守**实现**，这里守**接进
 * QML 之后行为没变**（同一个 `score()` 经单例转发仍得到同样的数）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 三条"故意不这么写"（别以为是漏了）
 * ════════════════════════════════════════════════════════════════════════
 * ① **不建假 Flickable。** 见上。
 * ② **不验真鼠标点击 / hover。** 侧栏行、菜单标题、返回按钮的点击
 *    归 `tests/tst_*.qml`（真事件）与像素核验。这里只断言**输入侧**
 *    的事实（`MouseArea.enabled`、`_enabledAt(i)`）。
 * ③ **不验像素。** `Slots.label` 里那行文字到底画在哪儿，这里一个字
 *    都读不到（它是被 Loader 装进去的、不在 `children` 里）——
 *    归 `.cache/shot_m25.qml` + `.cache/_verify_m25px.py`。
 *    本文件唯一读得到的结构信号是 `Loader.visible`（见 [7] 的 iconOnly）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 断言清单（位掩码退出码，见 tools/test.sh 文件头；上限 8 条）
 * ════════════════════════════════════════════════════════════════════════
 *   [0] 插槽白名单账目：21 格 / 六个具名反例不在 / 白名单外的键被丢 /
 *       真装两格后 reset 逐格回到 Basic（含 basic* 存在性）
 *   [1] ScrollUtil 七函数全谱 + FuzzyMatch 打分/排序（手推期望值）
 *   [2] QSkinCommand：筛选（text/keywords 取高分）+ 排序 + 空查询保持声明序
 *       + 分组收拢 + activate 报**原 model 下标** + 禁用不发信号
 *   [3] QSkinCommand 几何与状态：flatRows 的标题只在有活条目时出现 +
 *       rowY 逐行累加 + listHeight 受 maxVisibleRows 截断 +
 *       activeRowSafe 的三种夹取 + _step 跳标题行且到头不绕回
 *   [4] QSkinAnchor：真 Flickable 驱动 → currentIndex 跟随 + 一段之前退到第一段
 *       + scrollTo 的夹取与非法下标 + rowTop + select 发信号 + _enabledAt
 *   [5] QSkinAffix：真 Flickable 驱动 → reached/pinned/pushedOut 三态（两个
 *       实例的对照）+ _itemY 不随滚动变 + z 跟 pinned
 *   [6] QSkinBackTop：阈值**闭区间**（恰好等于时算出现）+ 滚回顶 +
 *       target 为 null 的两条守卫 + implicitWidth == diameter
 *   [7] PageHeader / Menubar / NavigationMenu / Sidebar / SidebarItem：
 *       页头公式与通栏线、菜单条的 titleX 与布局互推（含新加的 `closed`
 *       信号真的会发）、导航菜单的 activeIndex、侧栏 currentWidth 四档与
 *       不可选行、侧栏行的 variant 与 iconOnly
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

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

    /** 跑一段会写断言的代码；抛异常算这一条失败。
     *  理由与 smoke_m21~m24 同源：分回合时任何 TypeError 都会让 run()
     *  中断、Qt.exit 永不执行，而 qml.exe 是个开着窗口的 GUI 进程 ——
     *  测试不是失败，是永远挂着（tools/test.sh 的超时看门狗兜这一层）。 */
    function check(block) {
        var ok = false
        try { ok = block() === true } catch (e) { ok = false }
        root.expect(ok)
    }

    /** 一次性把所有断言包进一个 check（本文件用它把"同一条 bit"内的
     *  若干子断言合成一条 —— 位掩码只有 8 位，到顶时的正解是合并同类项，
     *  不是往上加位。见 tools/test.sh 文件头）。 */
    function all(conds) {
        for (var i = 0; i < conds.length; ++i)
            if (conds[i] !== true) return false
        return true
    }

    /* ══════════════════ 遍历辅助（与 smoke_m23 / m24 同一份）══════════════ */

    function findAll(item, pred) {
        var out = []
        root.collect(item, pred, out, 0)
        return out
    }

    function findIn(item, pred) {
        var out = []
        root.collect(item, pred, out, 0)
        return out.length > 0 ? out[0] : null
    }

    /** 深度上限 16：万一遇到环也不会死循环。 */
    function collect(item, pred, out, d) {
        if (item === null || item === undefined || d > 16) return
        if (pred(item)) out.push(item)
        var ch = item.children
        if (ch === undefined) return
        for (var i = 0; i < ch.length; ++i) root.collect(ch[i], pred, out, d + 1)
    }

    /* ══════════════════ 小工具 ══════════════════ */

    function arrEq(a, b) {
        if (a === null || b === null || a === undefined || b === undefined) return false
        if (a.length !== b.length) return false
        for (var i = 0; i < a.length; ++i)
            if (a[i] !== b[i]) return false
        return true
    }

    function joinKeys(rows, key) {
        var out = []
        for (var i = 0; i < rows.length; ++i) out.push(String(rows[i][key]))
        return out.join("|")
    }

    /** 行数组里第 i 条的文字（条目行取 `item.text`，标题行取 `heading`） */
    function rowTexts(rows) {
        var out = []
        for (var i = 0; i < rows.length; ++i) {
            var r = rows[i]
            out.push(r.kind === "heading" ? r.heading : (r.item ? r.item.text : "?"))
        }
        return out
    }

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
    }

    function sameTokenQ(actual, token) {
        if (token === undefined || token === null) return false
        cvt.c = token
        return root.sameColorQ(actual, cvt.c)
    }

    /** 只挑"代码里读得到的"那一个 Loader / 矩形之类，避免误命中注释 */
    function loaderOfLabel(item) {
        return root.findIn(item, function (o) {
            return o.sourceComponent === Slots.label
        })
    }

    /* 装配用的假插槽实现 */
    Component {
        id: fakeComp

        Rectangle {
            color: "#FF00FF"
        }
    }

    /* ══════════════════════════════════════════════════════════════════
     * 被测对象
     * ══════════════════════════════════════════════════════════════════ */

    /* ── 三件滚动控件的**真实**宿主：一个真 Flickable ──
     *
     * 视口 200×100，内容高 1000 → 合法 contentY 是 [0, 900]。
     * 子项直接写在 Flickable 里（会进 contentItem），于是
     * `mapToItem(target, 0, 0).y` 真的跟着 `contentY` 走。 */
    Flickable {
        id: scroller

        x: 10
        y: 10
        width: 200
        height: 100
        contentWidth: 200
        contentHeight: 1000

        /* y 恒为 50（内容坐标）—— 两个 Affix 都用它 */
        QSkinAffix {
            id: affixPin

            target: scroller
            y: 50
            width: 100
            stickyTop: 10
            holderHeight: 60          /* > 内容高 → 会「钉住」 */

            Rectangle {
                width: 100
                height: 30
            }
        }

        QSkinAffix {
            id: affixPush

            target: scroller
            y: 50
            width: 100
            stickyTop: 10
            holderHeight: 20          /* < 内容高 → 只会「被顶出去」 */

            Rectangle {
                width: 100
                height: 30
            }
        }
    }

    QSkinAnchor {
        id: anchor

        x: 240
        y: 10
        target: scroller
        model: ["一", "二", { text: "三", enabled: false }]
        offsets: [50, 300, 600]
        anchorOffset: 10
        itemHeight: 30
        spacing: 0

        property int selectedCount: 0
        property int lastSelected: -1
        onSelected: function (i) { anchor.selectedCount++; anchor.lastSelected = i }
    }

    QSkinBackTop {
        id: backTop

        x: 440
        y: 10
        target: scroller
        threshold: 400
        animated: false           /* 抓图与断言都走瞬时那条 */
        diameter: 40
    }

    QSkinBackTop {
        id: backTopNull

        x: 500
        y: 10
        target: null
        threshold: 400
    }

    /* ── QSkinCommand ──
     *
     * 模型刻意**两处**埋了需要区分的东西：
     *   · `复制路径` 声明在前、`打开 README` 声明在后，但查 "o" 时
     *     后者分数更高（词首 7 > 词中 1）→ 排序必须把它们换位。
     *   · `删除全部` 是 danger + disabled → 命中它也不能发信号。 */
    QSkinCommand {
        id: cmd

        x: 10
        y: 140
        model: [
            { heading: "建议", items: [
                { text: "新建文件", keywords: "create new file", shortcut: "⌘N" },
                { text: "打开设置", keywords: "settings preference", shortcut: "⌘," },
                { text: "删除全部", danger: true, enabled: false }
            ] },
            { heading: "其他", items: [
                { text: "复制路径", keywords: "copy path" },
                { text: "打开 README", keywords: "open readme" }
            ] }
        ]

        property int selCount: 0
        property int lastGroup: -1
        property int lastItem: -1
        property string lastText: ""

        onSelected: function (g, i, t) {
            cmd.selCount++
            cmd.lastGroup = g
            cmd.lastItem = i
            cmd.lastText = t
        }
    }

    QSkinCommand {
        id: cmdEmpty

        x: 460
        y: 140
        model: []
    }

    /* ── QSkinPageHeader 三态 ── */
    QSkinPageHeader {
        id: ph

        x: 10
        y: 640
        width: 400
        title: "标题"
        subtitle: "副标题"
        showBack: true

        extra: [ QSkinButton { text: "操作" } ]
    }

    QSkinPageHeader {
        id: phEmpty

        x: 430
        y: 640
        width: 300
    }

    /* `phNoDiv` 必须是 `ph` 的**逐项复制、只关掉分隔线** ——
     * 否则下面那条 `implicitHeight === ph.implicitHeight - 1` 比的是
     * 两个形状不同的页头，红起来看着像"分隔线少了 1px 之外还少了别的"。 */
    QSkinPageHeader {
        id: phNoDiv

        x: 750
        y: 640
        width: 400
        title: "标题"
        subtitle: "副标题"
        showBack: true
        showDivider: false

        extra: [ QSkinButton { text: "操作" } ]
    }

    QSkinPageHeader {
        id: phCrumbOnly

        x: 10
        y: 760
        width: 300

        breadcrumb: [ QSkinBreadcrumb { } ]
    }

    /* ── QSkinMenu（裸的，用来验新加的 `closed` 信号）── */
    QSkinMenu {
        id: bareMenu

        x: 460
        y: 760
        model: ["甲", "乙"]

        property int closedCount: 0
        onClosed: bareMenu.closedCount++
    }

    /* ── QSkinMenubar ── */
    QSkinMenubar {
        id: mb

        x: 460
        y: 800
        model: [
            { text: "文件", items: ["新建", "打开"] },
            { text: "编辑", items: ["撤销"] },
            { text: "帮助", items: ["关于"], enabled: false }
        ]

        property int triggeredCount: 0
        onTriggered: function (m, i) { mb.triggeredCount++ }
    }

    /* ── QSkinNavigationMenu ── */
    QSkinNavigationMenu {
        id: nav

        x: 700
        y: 800
        model: [
            { text: "产品", content: navPanel },
            { text: "文档" },
            { text: "禁用", enabled: false }
        ]

        property int activatedCount: 0
        onActivated: function (i) { nav.activatedCount++ }
    }

    Component {
        id: navPanel

        Rectangle {
            width: 200
            height: 80
        }
    }

    /* ── QSkinSidebar 四档宽度 + 三种 variant ── */
    QSkinSidebar {
        id: sidebar

        x: 10
        y: 820
        height: 60
        animated: false            /* 判据读 currentWidth，但关掉动画更干净 */
        collapsible: "icon"
        expandedWidth: 240
        iconWidth: 56
        model: [
            { header: "分组" },
            "separator",
            { text: "首页" },
            { text: "设置" }
        ]
    }

    QSkinSidebar {
        id: sidebarFlat

        x: 280
        y: 820
        height: 60
        animated: false
        variant: "floating"
        visible: false
    }

    /* ── QSkinSidebarItem 单行 ── */
    QSkinSidebarItem {
        id: sbiActive

        x: 700
        y: 860
        width: 200
        text: "首页"
        active: true
    }

    QSkinSidebarItem {
        id: sbiIdle

        x: 920
        y: 860
        width: 200
        text: "设置"
    }

    QSkinSidebarItem {
        id: sbiIcon

        x: 1140
        y: 860
        width: 40
        text: "首页"
        iconOnly: true
    }

    /* ══════════════════════════════════════════════════════════════════
     * 断言
     * ══════════════════════════════════════════════════════════════════ */

    function run() {
        Slots.reset()

        /* ── [0] 插槽白名单账目 ──
         *
         * M25 与 M24 一样**一格新插槽都没开**（裁决四）。这一条就是
         * `COVERAGE.md` 里承诺过的那条可证伪判据，那条承诺的原话是：
         *     "判据仍是 M21 那条：只为'同一主题里两种取值必须并存'的
         *      **形态**分歧开格。这条要能被证伪，所以
         *      `tests/smoke_m25.qml` 里钉一条 `Slots.slotNames.length === 21`。"
         *
         * 六个具名反例是这一批**真的考虑过**的名字（锚点记号 / 浮球底板 /
         * 回顶箭头 / 页头返回箭头 / 菜单面板 / 侧栏折叠箭头），每一个都能
         * 配出一张说得通的截图 —— 而单看截图看不出"契约面被永久撑大了"。 */
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

            /* 先真装两格（都在白名单里）再 reset —— 不先证明"装上了"，
             * 后面那个"换回来了"就可能只是"压根没变"（M24 记过这条）。 */
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

        /* ── [1] ScrollUtil 七函数 + FuzzyMatch 打分 ── */
        root.idx = 1
        root.check(function () {
            /* ── sectionIndexAt ──
             * 边界两条都是刻意的：闭区间（v <= line）、一段之前返回**第一段**。 */
            var si = [
                ScrollUtil.sectionIndexAt([0, 100, 200], 50, 0) === 0,
                ScrollUtil.sectionIndexAt([0, 100, 200], 99, 0) === 0,
                ScrollUtil.sectionIndexAt([0, 100, 200], 100, 0) === 1,   /* 闭区间 */
                ScrollUtil.sectionIndexAt([0, 100, 200], 0, 50) === 0,
                ScrollUtil.sectionIndexAt([0, 100, 200], 50, 50) === 1,   /* line=100 */
                ScrollUtil.sectionIndexAt([0, 100, 200], 1000, 0) === 2,
                ScrollUtil.sectionIndexAt([50, 100], 0, 0) === 0,        /* 一段之前 → 第一段 */
                ScrollUtil.sectionIndexAt([], 0, 0) === -1,
                ScrollUtil.sectionIndexAt(null, 0, 0) === -1,
                /* 非有限数被跳过，但返回值仍是**原数组下标** */
                ScrollUtil.sectionIndexAt([null, 100], 150, 0) === 1,
                ScrollUtil.sectionIndexAt([0, NaN, 200], 150, 0) === 0
            ]

            /* ── affixOffsetY / affixDeltaY ──
             * 表里第二行是"钉住了"、第四行是"被顶出去了"（holder < item）。 */
            var cases = [
                /* itemY, holderH, itemH, scrollY, stickyTop, 期望 offsetY, 期望 deltaY */
                [50, 60, 30,  0, 10, 50,   0],
                [50, 60, 30, 45, 10, 10,   5],
                [50, 60, 30, 80, 10,  0,  30],
                [50, 20, 30, 45, 10, -5, -10],
                [100, 40, 40, 50,  0, 50,  0],
                [0, 0, 0, 0, 0, 0, 0]
            ]
            var affOk = true
            for (var a = 0; a < cases.length; ++a) {
                var c = cases[a]
                var off = ScrollUtil.affixOffsetY(c[0], c[1], c[2], c[3], c[4])
                var del = ScrollUtil.affixDeltaY(c[0], c[1], c[2], c[3], c[4])
                if (off !== c[5]) affOk = false
                if (del !== c[6]) affOk = false
                /* 文件头点名的那条关系（不是注释，是断言）：
                 *   affixDeltaY(...) === affixOffsetY(...) - (itemY - scrollY) */
                if (del !== off - (c[0] - c[3])) affOk = false
            }

            /* ── backTopVisible：闭区间 ── */
            var btv = ScrollUtil.backTopVisible(400, 400) === true
                      && ScrollUtil.backTopVisible(399, 400) === false
                      && ScrollUtil.backTopVisible(0, 0) === true

            /* ── maxScrollY / clampScrollY ── */
            var cl = [
                ScrollUtil.maxScrollY(1000, 100) === 900,
                ScrollUtil.maxScrollY(50, 100) === 0,
                ScrollUtil.clampScrollY(-5, 1000, 100) === 0,
                ScrollUtil.clampScrollY(5000, 1000, 100) === 900,
                ScrollUtil.clampScrollY(300, 1000, 100) === 300
            ]

            /* ── scrollYForIndex：含"够不到锚点线就被夹取"那一格 ── */
            var sy = [
                ScrollUtil.scrollYForIndex([50, 300, 600], 0, 10, 1000, 100) === 40,
                ScrollUtil.scrollYForIndex([50, 300, 600], 1, 10, 1000, 100) === 290,
                ScrollUtil.scrollYForIndex([50, 300, 600], 2, 10, 1000, 100) === 590,
                ScrollUtil.scrollYForIndex([50, 300, 600], 2, 10, 650, 100) === 550,
                ScrollUtil.scrollYForIndex([50, 300, 600], 9, 10, 1000, 100) === -1,
                ScrollUtil.scrollYForIndex([50, 300, 600], -1, 10, 1000, 100) === -1,
                ScrollUtil.scrollYForIndex(null, 0, 0, 100, 100) === -1,
                ScrollUtil.scrollYForIndex([NaN], 0, 0, 100, 100) === -1
            ]

            /* ── FuzzyMatch 打分：每一条的期望值都在注释里推过 ──
             * CHAR=1 / CONSEC=8 / BOUNDARY=6（从单例读，不写死魔数）。
             *   bnd = 命中且落在词首 = 1 + 6 = 7
             *   adj = 命中且紧邻前一个 = 1 + 8 = 9      ← 只有一份 CHAR
             * 这两个数一起才说明"词首 6 分 < 相邻 8 分"这个序是真的。 */
            var bnd = FuzzyMatch.charBonus + FuzzyMatch.boundaryBonus      /* 7 */
            var adj = FuzzyMatch.charBonus + FuzzyMatch.consecBonus        /* 9 */
            var r1 = FuzzyMatch.score("ab", "abc")                        /* 7 + 9 = 16 */
            /* "aab" 上两种对齐是 (0,2)=7+1=8 与 (1,2)=1+9=10 —— **不是并列**，
             * 相邻那 8 分压过了词首那 6 分，所以取 (1,2)。
             * 这条同时说明"词首 6 < 相邻 8"这个序是真的（首版把它当成并列，
             * 期望写成 16/[0,1]，红在了这里）。 */
            var r2 = FuzzyMatch.score("ab", "aab")
            /* 真并列：'a' 在 1 与 2 都不是词首、都不相邻 → 同为 1 分，
             * 取**最左**的那个下标。 */
            var r2b = FuzzyMatch.score("a", "baa")
            var r3 = FuzzyMatch.score("", "任意")
            var r4 = FuzzyMatch.score("xyz", "abc")
            var r5 = FuzzyMatch.score("cp", "copyPath")                   /* 7 + 7（驼峰） */
            var r6 = FuzzyMatch.score("ab", "a_b")                        /* 7 + 7（下划线） */
            var r7 = FuzzyMatch.score("AB", "ab")                         /* 大小写不敏感 */
            var r8 = FuzzyMatch.score("AB", "ab", { caseSensitive: true })
            var r9 = FuzzyMatch.score("建", "新建文件")                    /* 词中 → 1 */

            var fzOk = r1 !== null && r1.score === bnd + adj && root.arrEq(r1.hits, [0, 1])
                    && r2 !== null && r2.score === FuzzyMatch.charBonus + adj
                       && root.arrEq(r2.hits, [1, 2])
                    && r2b !== null && r2b.score === FuzzyMatch.charBonus
                       && root.arrEq(r2b.hits, [1])
                    && r3 !== null && r3.score === 0 && r3.hits.length === 0
                    && r4 === null
                    && r5 !== null && r5.score === bnd + bnd && root.arrEq(r5.hits, [0, 4])
                    && r6 !== null && r6.score === bnd + bnd && root.arrEq(r6.hits, [0, 2])
                    && r7 !== null && r7.score === bnd + adj
                    && r8 === null
                    && r9 !== null && r9.score === FuzzyMatch.charBonus
                    && FuzzyMatch.matches("ab", "xaxb") === true
                    && FuzzyMatch.matches("ab", "ba") === false

            /* `explain` 是给人读的通道，只判它带上了那两个数 */
            var ex = FuzzyMatch.explain("ab", "abc")
            var exOk = ex.indexOf("score=" + (bnd + adj)) >= 0
                       && ex.indexOf("hits=[0,1]") >= 0

            /* rank：空查询保持声明序；有查询按分降序。
             * "open readme" 的 'o' 在词首（7），"copy path" 的 'o' 在词中（1）。 */
            var rk0 = FuzzyMatch.rank("", ["b", "a", "c"])
            var rk1 = FuzzyMatch.rank("o", ["copy path", "open readme"])
            var rankOk = rk0.length === 3
                         && rk0[0].index === 0 && rk0[1].index === 1 && rk0[2].index === 2
                         && rk0[0].score === 0 && rk0[1].score === 0 && rk0[2].score === 0
                         && rk1.length === 2 && rk1[0].index === 1 && rk1[1].index === 0
                         && rk1[0].score === bnd && rk1[1].score === FuzzyMatch.charBonus

            return root.all(si) && affOk && btv && root.all(cl) && root.all(sy)
                   && fzOk && exOk && rankOk
        })

        /* ── [2] QSkinCommand：筛选 / 排序 / 分组 / 信号 ── */
        root.idx = 2
        root.check(function () {
            /* 空查询：全量、保持声明序、分组顺序不变 */
            cmd.query = ""
            var g0 = cmd.filteredGroups
            var emptyOk = g0.length === 2
                          && g0[0].heading === "建议" && g0[0].items.length === 3
                          && g0[1].heading === "其他" && g0[1].items.length === 2
                          && g0[1].items[0].text === "复制路径"
                          && g0[1].items[1].text === "打开 README"
                          && cmd.matchCount === 5

            /* 有查询：组内按分降序（`复制路径` 声明在前但排到后面）；
             * 且 index 字段是**原 model 下标**（打开 README 是第 1 条） */
            cmd.query = "o"
            var g1 = cmd.filteredGroups
            var ordOk = g1.length === 1 && g1[0].heading === "其他"
                        && g1[0].items.length === 2
                        && g1[0].items[0].text === "打开 README"
                        && g1[0].items[0].score === FuzzyMatch.charBonus + FuzzyMatch.boundaryBonus
                        && g1[0].items[1].text === "复制路径"
                        && g1[0].items[1].score === FuzzyMatch.charBonus
                        && g1[0].items[0].itemIndex === 1
                        && g1[0].items[1].itemIndex === 0
                        && g1[0].items[0].groupIndex === 1
                        && g1[0].items[0].matchedOn === "keywords"
                        && g1[0].items[0].shortcut === ""

            /* 命中 `text` 时 matchedOn 是 "text"；中文词中只拿 CHAR */
            cmd.query = "建"
            var g2 = cmd.filteredGroups
            var cnOk = g2.length === 1 && g2[0].items.length === 1
                       && g2[0].items[0].text === "新建文件"
                       && g2[0].items[0].score === FuzzyMatch.charBonus
                       && g2[0].items[0].matchedOn === "text"
                       && root.arrEq(g2[0].items[0].hits, [1])

            /* 筛光了 → 空；空模型也一样 */
            cmd.query = "zzz"
            var noneOk = cmd.filteredGroups.length === 0
                         && cmd.matchCount === 0
                         && cmd.activeEntry === null
                         && cmdEmpty.filteredGroups.length === 0
                         && cmdEmpty.matchCount === 0

            /* disabled 的条目**不许**发信号（危险 + 禁用那条） */
            cmd.query = "删"
            cmd.activeRow = 1
            var beforeCount = cmd.selCount
            cmd.activate()
            var disabledOk = cmd.selCount === beforeCount
                             && cmd.activeEntry !== null
                             && cmd.activeEntry.enabled === false
                             && cmd.activeEntry.danger === true

            /* `activate()` 报的是**原 model 下标**，不是 flatRows 下标 */
            cmd.query = "o"
            cmd.activeRow = 2                        /* flatRows: [标题, README, 复制路径] */
            cmd.activate()
            var emitOk = cmd.selCount === beforeCount + 1
                         && cmd.lastGroup === 1
                         && cmd.lastItem === 0    /* 复制路径 = 原 model 第 1 组的第 0 条 */
                         && cmd.lastText === "复制路径"

            /* 键盘步进发的也是同一条路 */
            cmd.query = "o"
            cmd.activeRow = 1                        /* README */
            var c2 = cmd.selCount
            cmd.activate()                           /* 走 activeEntry 那条 */
            var kbOk = cmd.selCount === c2 + 1 && cmd.lastText === "打开 README"

            cmd.query = ""
            return emptyOk && ordOk && cnOk && noneOk && disabledOk && emitOk && kbOk
        })

        /* ── [3] QSkinCommand 几何与高亮夹取 ── */
        root.idx = 3
        root.check(function () {
            /* flatRows：标题**只在**这个分组还有活条目时才出现。
             * 查 "o" 时「建议」组一条不剩 → 它的标题也不该出现。 */
            cmd.query = ""
            var f0 = cmd.flatRows
            var flatOk = f0.length === 7                       /* 2 标题 + 5 条目 */
                         && root.joinKeys(f0, "kind")
                            === "heading|item|item|item|heading|item|item"
                         && root.rowTexts(f0).join("|")
                            === "建议|新建文件|打开设置|删除全部|其他|复制路径|打开 README"
                         && root.arrEq(cmd.itemRows, [1, 2, 3, 5, 6])
                         && cmd.matchCount === 5

            cmd.query = "o"
            var f1 = cmd.flatRows
            var flat2Ok = f1.length === 3
                          && root.joinKeys(f1, "kind") === "heading|item|item"
                          && f1[0].heading === "其他"
                          && root.arrEq(cmd.itemRows, [1, 2])

            cmd.query = "删"
            var f2 = cmd.flatRows
            var flat3Ok = f2.length === 2 && f2[0].kind === "heading"
                          && f2[0].heading === "建议"          /* 组里还有一条活的 → 标题留着 */
                          && root.arrEq(cmd.itemRows, [1])

            /* rowY：标题行与条目行不等高，所以是逐行累加 */
            cmd.query = ""
            var hh = cmd.headingHeight
            var rh = cmd.rowHeight
            var rowYOk = cmd.rowY(0) === 0
                         && cmd.rowY(1) === hh
                         && cmd.rowY(2) === hh + rh
                         && cmd.rowY(3) === hh + rh * 2
                         && cmd.rowY(4) === hh + rh * 3
                         && cmd.rowY(5) === hh * 2 + rh * 3
                         && cmd.rowY(99) === hh * 2 + rh * 5   /* 越界 = 全部高度 */

            /* listHeight：最多展示 maxVisibleRows 条**条目**。
             * 截断发生在第 maxVisibleRows+1 条条目上 —— 它之后的标题
             * 也就不再计高（这正是 `listHeight()` 与 `flatRows` 分开的原因：
             * 视图高度是"截断后的高度"，不是"内容的高度"）。 */
            var listOk = cmd.listHeight() === hh * 2 + rh * 5
            cmd.maxVisibleRows = 2
            listOk = listOk && cmd.listHeight() === hh + rh * 2
            cmd.maxVisibleRows = 8
            var listOk2 = cmd.listHeight() === hh * 2 + rh * 5

            /* activeRowSafe 三种夹取：停在标题行 / 越界 / 正常 */
            cmd.query = ""
            cmd.activeRow = 0                                   /* 标题行 */
            var safeA = cmd.activeRowSafe === 1 && cmd.activeEntry.text === "新建文件"
            cmd.activeRow = 999                                 /* 越界 */
            var safeB = cmd.activeRowSafe === 1
            cmd.activeRow = 6                                   /* 合法条目行 */
            var safeC = cmd.activeRowSafe === 6 && cmd.activeEntry.text === "打开 README"

            /* _step 跳标题行、到头不绕回 */
            cmd.activeRow = 3
            cmd._step(1)
            var stepA = cmd.activeRow === 5                     /* 3 → 跳过标题行 4 */
            cmd._step(1)
            var stepB = cmd.activeRow === 6
            cmd._step(1)
            var stepC = cmd.activeRow === 6                     /* 尽头不绕回 */
            cmd._step(-1)
            var stepD = cmd.activeRow === 5

            cmd.activeRow = 0
            return flatOk && flat2Ok && flat3Ok && rowYOk
                   && listOk && listOk2 && safeA && safeB && safeC
                   && stepA && stepB && stepC && stepD
        })

        /* ── [4] QSkinAnchor：真 Flickable 驱动 ──
         *
         * ⚠ 这一条只能在**真** Flickable 上验：`currentIndex` 读 `target.contentY`，
         * 那是 QML 属性、依赖捕获正常。但 Affix 那一路（[5]）依赖的是
         * `mapToItem` —— 一个 C++ 调用，内部读内容项的位置**不经过**
         * QML 的依赖包装层。假对象会两条都放过。 */
        root.idx = 4
        root.check(function () {
            var countOk = anchor.count === 3

            scroller.contentY = 0
            var i0 = anchor.currentIndex                       /* line=10 → 第 0 段 */
            scroller.contentY = 290
            var i1 = anchor.currentIndex                       /* line=300 → 第 1 段 */
            scroller.contentY = 590
            var i2 = anchor.currentIndex                       /* line=600 → 第 2 段 */
            scroller.contentY = 900                            /* 到底 */
            var i3 = anchor.currentIndex
            var followOk = i0 === 0 && i1 === 1 && i2 === 2 && i3 === 2

            /* 锚点线在第一段之前 → 仍然是第一段（不是 -1）—— 刻意的语义 */
            var saved = anchor.offsets
            anchor.offsets = [50, 300, 600]
            scroller.contentY = 0
            var beforeFirst = anchor.currentIndex
            anchor.offsets = saved

            /* scrollTo：目标 = offsets[i] - anchorOffset，再夹进合法范围 */
            scroller.contentY = 0
            var st1 = anchor.scrollTo(1)
            var y1 = scroller.contentY
            var st2 = anchor.scrollTo(2)
            var y2 = scroller.contentY
            var st3 = anchor.scrollTo(0)
            var y3 = scroller.contentY
            var st4 = anchor.scrollTo(99)
            var y4 = scroller.contentY
            var scrollOk = st1 === true && y1 === 290
                           && st2 === true && y2 === 590
                           && st3 === true && y3 === 40          /* 50-10，未被夹取 */
                           && st4 === false && y4 === y3         /* 非法下标：不动 */

            /* rowTop：等间距的行顶边 */
            var rowTopOk = anchor.rowTop(0) === 0
                           && anchor.rowTop(1) === 30
                           && anchor.rowTop(2) === 60

            /* select：滚过去 + 发信号；禁用的那一项不发 */
            scroller.contentY = 900
            anchor.select(0)
            var selY = scroller.contentY
            var selOk = selY === 40 && anchor.selectedCount === 1

            scroller.contentY = 900
            anchor.select(2)                                   /* enabled: false */
            var disOk = scroller.contentY === 900 && anchor.selectedCount === 1

            /* 文本归一：字符串 / 对象两种写法都要读得出来 */
            var txtOk = anchor._textAt(0) === "一"
                        && anchor._textAt(2) === "三"
                        && anchor._enabledAt(2) === false
                        && anchor._enabledAt(1) === true

            scroller.contentY = 0
            return countOk && followOk && beforeFirst === 0 && scrollOk
                   && rowTopOk && selOk && disOk && txtOk
        })

        /* ── [5] QSkinAffix：真 Flickable 驱动 ──
         *
         * 两个实例是一组**对照**：holder > 内容高 → 只会"钉住"；
         * holder < 内容高 → 只会"被顶出去"。两种形态在结构上互斥
         * （见 QSkinAffix 文件头的"已知边界"），所以一个实例测不出两条。 */
        root.idx = 5
        root.check(function () {
            var holderOk = affixPin._holderH === 60
                           && affixPush._holderH === 20
                           && affixPin._itemH === 30
                           && affixPin.implicitHeight === 60

            /* 不滚：两件都在原位，谁也不是 reached */
            scroller.contentY = 0
            var atTop = affixPin._deltaY === 0 && affixPin.reached === false
                        && affixPin.pinned === false && affixPin.pushedOut === false
                        && affixPush._deltaY === 0 && affixPush.reached === false
                        && affixPin.z === 0

            /* 滚过线：pin 钉住、push 被顶出去 */
            scroller.contentY = 45
            var mid = affixPin.reached === true
                      && affixPin.pinned === true
                      && affixPin.pushedOut === false
                      && affixPin._deltaY === 5
                      && affixPin.z === 1

            var mid2 = affixPush.reached === true
                       && affixPush.pinned === false
                       && affixPush.pushedOut === true
                       && affixPush._deltaY === -10
                       && affixPush.z === 0

            /* 内容坐标里的顶边**不随滚动变** —— 它是这个件最容易被写坏的
             * 一个量（写成 viewportY + scrollY 的自洽循环就永远为真，
             * 写成只读 mapToItem 就会在滚动后失真）。 */
            var itemYs = []
            var ys = [0, 45, 80, 300]
            for (var k = 0; k < ys.length; ++k) {
                scroller.contentY = ys[k]
                itemYs.push(affixPin._itemY)
            }
            var invOk = itemYs[0] === 50 && itemYs[1] === 50
                        && itemYs[2] === 50 && itemYs[3] === 50

            /* 再远一点：钉住状态一直持续（deltaY 恒为 holder-item） */
            scroller.contentY = 300
            var farOk = affixPin.pinned === true && affixPin._deltaY === 30
                        && affixPush.pushedOut === true && affixPush._deltaY === -10

            /* 与纯函数逐字对上（判定只有一份算路的证据） */
            var wireOk = affixPin._deltaY
                         === ScrollUtil.affixDeltaY(affixPin._itemY, affixPin._holderH,
                                                    affixPin._itemH, affixPin._scrollY,
                                                    affixPin.stickyTop)

            scroller.contentY = 0
            return holderOk && atTop && mid && mid2 && invOk && farOk && wireOk
        })

        /* ── [6] QSkinBackTop ── */
        root.idx = 6
        root.check(function () {
            scroller.contentY = 0
            var s0 = backTop.showing === false && backTop.visible === false
            scroller.contentY = 399
            var s1 = backTop.showing === false
            scroller.contentY = 400
            var s2 = backTop.showing === true          /* 闭区间：恰好等于就算出现 */
            scroller.contentY = 900
            var s3 = backTop.showing === true && backTop.visible === true

            /* 滚回顶：目标恒为 0，但走 ScrollUtil 的夹取口径 */
            backTop.scrollToTop()
            var backOk = scroller.contentY === 0 && backTop.showing === false

            /* target 为 null：两条守卫 */
            var backTopNullOk = backTopNull.showing === false
            backTopNull.scrollToTop()                  /* 不许崩 */
            backTopNullOk = backTopNullOk && backTopNull.showing === false

            var geomOk = backTop.implicitWidth === 40
                         && backTop.implicitHeight === 40
                         && backTop.diameter === 40

            scroller.contentY = 0
            return s0 && s1 && s2 && s3 && backOk && backTopNullOk && geomOk
        })

        /* ── [7] 页头 / 菜单条 / 导航菜单 / 侧栏 ── */
        root.idx = 7
        root.check(function () {
            /* ── PageHeader ──
             * 空页头**不撑出一整行**：所有宿主都空 → 内容列 implicitHeight 0
             * → implicitHeight 只剩上下内边距 + 那条分隔线。 */
            var phOk = ph.hasTitleRow === true
                       && ph.hasExtra === true
                       && phEmpty.hasTitleRow === false
                       && phEmpty.implicitHeight === Theme.space.lg * 2 + 1
                       && phCrumbOnly.hasBreadcrumb === true
                       && phCrumbOnly.hasTitleRow === false

            /* 分隔线**通栏**：左右端点就是本件的左右端点（像素判据可写等号） */
            var div = root.findIn(ph, function (o) {
                return o.height === 1 && o.color !== undefined
                       && Math.round(o.color.r * 255) === Math.round(ph.dividerColor.r * 255)
            })
            var divOk = div !== null
                        && Math.abs(div.width - ph.width) < 0.6
                        && Math.abs(div.x) < 0.6

            /* showDivider: false → 少 1px，且那条线不可见 */
            var phNoDivOk = phNoDiv.implicitHeight === ph.implicitHeight - 1
            var div2 = root.findIn(phNoDiv, function (o) { return o.height === 1 })
            phNoDivOk = phNoDivOk && div2 !== null && div2.visible === false

            /* ── QSkinMenu 新加的 `closed` 信号 ──
             * 这个信号是 M25 装出来的：`QSkinMenubar` 要在面板关掉时复位
             * `activeIndex`，而它原先挂在 `onClosed` 上（那是 Popup 的）——
             * 那个 handler **从来没跑过**，只有 qmllint 的
             * "no matching signal found for handler" 抓到过。 */
            bareMenu.open()
            var bareOpened = bareMenu.opened === true
            bareMenu.close()
            var bareClosed = bareMenu.closedCount === 1 && bareMenu.opened === false

            /* ── QSkinMenubar ── */
            var mbOk = mb.count === 3
                       && mb._textAt(0) === "文件"
                       && mb._enabledAt(2) === false
                       && mb._itemsAt(0).length === 2

            /* titleX 与**布局**互推：第 i 个标题在**本件坐标系**里的 x
             * 必须等于 titleX(i)。这条同时守住文件头那句"面板左缘对齐
             * 标题左缘" —— 它是像素判据的前提，这里先用属性把它钉住。
             *
             * ⚠ 必须 `mapToItem(mb, …)`：直接读 `btn.x` 拿到的是它在
             * **父项（那一排的 QSkinRow）里**的坐标，比 titleX 小一整份
             * padding（本件首跑就是这么红的：0/54/108 对 2/56/110）。 */
            var xs = []
            for (var i = 0; i < mb.count; ++i) {
                var want = mb._textAt(i)
                var btn = root.findIn(mb, (function (t) {
                    return function (o) {
                        return o.text === t && o.implicitWidth > 0
                    }
                })(want))
                xs.push(btn === null ? -1 : btn.mapToItem(mb, 0, 0).x)
            }
            var titleOk = Math.abs(xs[0] - mb.titleX(0)) < 0.01
                          && Math.abs(xs[1] - mb.titleX(1)) < 0.01
                          && Math.abs(xs[2] - mb.titleX(2)) < 0.01
                          && mb.titleX(0) === mb.padding
                          && mb.titleX(1) > mb.titleX(0)
                          && mb.titleX(2) > mb.titleX(1)

            /* 打开 → 关掉（**绕过** mb.close()，直接关内层那个 QSkinMenu）——
             * 这条路径才是 onClosed 存在的理由：点外面 / Esc 关掉时不会
             * 经过 close()，那时 activeIndex 必须也能复位。 */
            mb.openAt(1)
            var mbOpenOk = mb.activeIndex === 1 && mb.opened === true
            var inner = root.findIn(mb, function (o) {
                return o !== mb && o.highlightIndex !== undefined && o.model !== undefined
            })
            if (inner !== null) inner.close()
            var mbCloseOk = mb.activeIndex === -1 && mb.opened === false

            /* ── QSkinNavigationMenu ── */
            var navOk = nav.count === 3
                        && nav._textAt(0) === "产品"
                        && nav._hasPanel(0) === true
                        && nav._hasPanel(1) === false
                        && nav._enabledAt(2) === false
                        && nav.opened === false
            nav.open(0)
            var navOpenOk = nav.activeIndex === 0 && nav.opened === true
            nav.close()
            var navCloseOk = nav.activeIndex === -1 && nav.opened === false

            /* ── QSkinSidebar 的 currentWidth 四档 ── */
            sidebar.collapsible = "icon"
            sidebar.collapsed = false
            var w1 = sidebar.currentWidth
            sidebar.collapsed = true
            var w2 = sidebar.currentWidth
            var i2 = sidebar.iconOnly
            sidebar.collapsible = "offcanvas"
            var w3 = sidebar.currentWidth
            var i3 = sidebar.iconOnly
            sidebar.collapsible = "none"
            var w4 = sidebar.currentWidth
            sidebar.collapsed = false
            var widthOk = w1 === 240 && w2 === 56 && i2 === true
                          && w3 === 0 && i3 === false
                          && w4 === 240

            /* toggle() 在 "none" 档下不该折（那是"永不折叠"的意思） */
            sidebar.collapsible = "none"
            sidebar.toggle()
            var noToggleOk = sidebar.collapsed === false
            sidebar.collapsible = "icon"
            sidebar.toggle()
            var toggleOk = sidebar.collapsed === true
            sidebar.collapsed = false

            /* 分区标题与分割线**不是**可选项；项才是 */
            var selOk = sidebar._isSeparator(1) === true
                        && sidebar._isHeader(0) === true
                        && sidebar._isSelectable(0) === false
                        && sidebar._isSelectable(1) === false
                        && sidebar._isSelectable(2) === true
                        && sidebar._isSelectable(3) === true
                        && sidebar._textAt(0) === "分组"
                        && sidebar._textAt(2) === "首页"

            /* variant 决定底板色 / 圆角 / 外边距（三档，各有取值） */
            sidebarFlat.variant = "floating"
            var vFloat = sidebarFlat._radius === Theme.radius.lg
                         && sidebarFlat._margin === Theme.space.sm
                         && root.sameTokenQ(sidebarFlat._bg, Theme.color.bgElevated)
            sidebarFlat.variant = "inset"
            var vInset = sidebarFlat._radius === Theme.radius.lg
                         && sidebarFlat._margin === 0
                         && root.sameTokenQ(sidebarFlat._bg, Theme.color.bgElevated)
            sidebarFlat.variant = "sidebar"
            var vPlain = sidebarFlat._radius === 0
                         && sidebarFlat._margin === 0
                         && root.sameTokenQ(sidebarFlat._bg, Theme.color.bgSubtle)

            /* ── QSkinSidebarItem ── */
            var sbiOk = sbiActive.variant === "primary"
                        && sbiIdle.variant === "ghost"
                        && sbiActive.labelAlignment === Text.AlignLeft
                        && sbiIdle.labelAlignment === Text.AlignLeft

            /* iconOnly 的结构信号：文字走 Loader，`visible` 是这里唯一读得到
             * 的东西（文字画在哪儿归像素核验）。 */
            var ldrIdle = root.loaderOfLabel(sbiIdle)
            var ldrIcon = root.loaderOfLabel(sbiIcon)
            var iconOnlyOk = ldrIdle !== null && ldrIdle.visible === true
                             && ldrIcon !== null && ldrIcon.visible === false

            return phOk && divOk && phNoDivOk && bareOpened && bareClosed
                   && mbOk && titleOk && mbOpenOk && mbCloseOk
                   && navOk && navOpenOk && navCloseOk
                   && widthOk && noToggleOk && toggleOk && selOk
                   && vFloat && vInset && vPlain && sbiOk && iconOnlyOk
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

    /* 推迟一轮再断言：Qt Quick Layouts 的尺寸重算在 polish 阶段
     * （见 smoke_sizes.qml）。这一份还要等布局跑完 —— [7] 里
     * "标题的实际 x 必须等于 titleX(i)" 这一条读的是**布局结果**。 */
    Component.onCompleted: function () {
        try {
            Qt.callLater(root.run)
        } catch (e) {
            Qt.exit(255)
        }
    }
}
