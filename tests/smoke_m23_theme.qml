/****************************************************************************
 * QSkin · 冒烟测试 — M23：segmentThumb / timelineDot 两格插槽的**装载**契约
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件为什么存在 ──────────────────────────────────────────────────
 * M23 五件（Collapse / CollapseItem / Segmented / Timeline / TimelineItem /
 * Carousel）一共只新开**两格**插槽，其余全部复用：
 *
 *     QSkinCollapseItem  →  Slots.label（标题）、Slots.chevronIndicator（箭头）
 *     QSkinSegmented     →  Slots.segmentThumb          ← 新
 *     QSkinTimelineItem  →  Slots.timelineDot           ← 新
 *     QSkinCarousel      →  Slots.chevronIndicator
 *
 * 也就是说这一批面对的具体诱惑是"每见到一个形状就开一格"：
 * 折叠的箭头可以叫 collapseChevron、轮播的指示点可以叫 carouselDot、
 * 分段的底可以叫 toggleBackground。**四格里只有两格该存在** ——
 * 而单看任何一张截图都看不出多开的那两格有什么不对（它们都长得对，
 * 只是契约面被永久撑大了）。
 *
 * 所以 [0] 数账：[白名单总数 === 21] + [两个具名反例不在名单里]。
 * 前者是刻意的常量 —— 加一格就必须来改这个数，改的时候会看到旁边
 * 那三行说明"为什么加"。
 *
 * ── 两格新插槽各自的"必须存在"证据在属性侧长什么样 ──────────────────────
 *   segmentThumb   Ant 的那份**不画描边**（Basic 画一圈 border）
 *   timelineDot    末点画成**空心**（非末点实心）
 *
 * 这两条都是**形态**上的差别，与 M22 的 statusGlyph（实心盘 vs 描边环）
 * 是同一条判据的第 N 次应用。而 M22 已经踩过一次相关的坑：
 *
 *     `Rectangle.border.width` **默认读到 1**、`border.color` 读到
 *     **不透明黑**，而画面上一根线都没有（M22 量过像素：盘边缘是
 *     "底板与语义色各半"，不是"与黑色各半"）。
 *
 * 本轮为 segmentThumb 又实测了一遍（`.cache/_probe_m23th.qml`，回传通道
 * 是退出码），结论一样：
 *
 *     BasicSegmentThumb（显式 1px + border 色）  border.width=1  color.a=1
 *     ADSegmentThumb（首版**不写** border.*）     border.width=1  color.a=1
 *
 * 于是 ADSegmentThumb 当场补了**显式**的 `border.width: 0` —— 让"无描边"
 * 从一条不可读的默认值变成一条可被读出来、也可被改坏的性质。
 * [1] / [2] 读的就是这个显式量。
 *
 * ── 一个必须提防的坑：判据不能读"渲染上不存在"的量 ──────────────────────
 * 上一条的推论：`border.color` 在两份实现里**必然不同**（Basic 是
 * `Theme.color.border`、Ant 是默认黑），但那个差别是**假的** ——
 * 黑边根本没画。拿它当"Ant 无描边"的证据，等于让核验器去读一个
 * 画面上不存在的量。所以这里判"Ant 无描边"用的是 `border.width === 0`，
 * 而"Basic 有描边"用的是 `border.width === 1 && border.color.a === 1`。
 *
 * ── 三个回合，以及"为什么不能挤在一起" ─────────────────────────────────
 * 这个文件分三批跑，不是摆样子 —— 每一条分界线都由一个**实测到的**时序
 * 约束划出来（三条都是这轮现踩的）：
 *
 *   回合 1  run()      纯属性与引用：读白名单、四家装载账、`tone` 的取值
 *                      支路。造好回合 2/3 要用的实例，最后把两格假件装上去。
 *   回合 2  step       [5]（`anchors.fill` 要一帧才生效）、[7]，
 *                      以及 [4] —— **装载与读取不能挤在同一个同步块**：
 *                      `Loader` 换源之后 `item` 要到下一个事件循环才存在，
 *                      同一块里读会读到 null，而 null 一旦被解引用就会让
 *                      整条断言抛异常、被 `check` 吞成一声不响的"失败"。
 *   回合 3  step2      [2] 的盒子。`thumbLoader` 挂了 `Behavior on x/width`，
 *                      换段之后立刻读 `ld.x` 拿到的是**动画起点**。
 *
 * ── 位号是**显式**写的，不能靠 idx 自增 ─────────────────────────────────
 * `expect()` 是"用当前 idx 置位、然后 idx++"。这一批的条目编号不是连续的
 * （[0][1][3][4][6] 在第一回合，[2][5][7] 在后两回合），于是**自增会静默错位**：
 * 五个断言会落在 bit0~bit4 上，而上方的注释写着 [3]/[4]/[6]。
 *
 * 代价是一次真实的误诊：`exit=12` 被读成"`[2]` 与 `[3]` 失败"，实际是
 * "`[3]` 与 `[4]` 那两条（落在 bit2/bit3）失败"。所以每个 `root.check`
 * 前面都有一行显式的 `root.idx = n` —— 那几行不是废话，是防止下一次误诊。
 *
 * ── 断言上限 8 条（位掩码退出码，见 tools/test.sh 文件头）──────────────
 *   [0] 白名单账目（21 格 + 没有多开格 + 白名单外键被丢）
 *   [1] 四家的覆盖账（segmentThumb 只有 Ant ≠ Basic；timelineDot 四家同 Basic）
 *   [2] QSkinSegmented 真的读了这一格，且盒子 = 宿主算的位置，只有一个实例
 *   [3] QSkinSegmented **没有**读 tabIndicator / toggleBackground（"不复用"的可执行形式）
 *   [4] QSkinTimelineItem 真的读了这一格，control 四个字段逐值跟着走
 *   [5] Basic 的末点空心 + 描边宽随 dotSize 走（属性侧，与像素填充率互为独立算路）
 *   [6] `color` 可选字段的两条支路 + 未知 type 归到 default
 *   [7] 两格插槽都没有交互；两个宿主各自实例化一份（不共享实例）
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

    /* 回合 2 要用的实例（回合 1 里造好、设好尺寸，回合 2 读布局后的值） */
    property var dotLast: null
    property var dotMid: null
    property var dotSmall: null
    property var realThumb: null
    property var realDot: null

    width: 900
    height: 700

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    /** 跑一段会写断言的代码；抛异常算这一条失败。 */
    function check(block) {
        var ok = false
        try { ok = block() === true } catch (e) { ok = false }
        root.expect(ok)
    }

    /* ══════════════════ 被测对象 ══════════════════ */

    QSkinSegmented {
        id: segA

        x: 10
        y: 10
        width: 320
        options: [ "概览", "详细报表", "全部指标" ]
        value: "概览"
    }

    QSkinSegmented {
        id: segB

        x: 10
        y: 60
        width: 320
        options: [ "一", "二" ]
        value: "一"
    }

    QSkinTimeline {
        id: tlA

        x: 400
        y: 10
        width: 300

        /* 内容走 default property（`content`），不是 `title` —— 与
         * QSkinList / QSkinCard 同一条约定：控件负责"放什么位置的什么字"，
         * 具体是 Body 还是别的文本件由调用方定。 */
        QSkinTimelineItem { id: ti1; label: "09:00"; Body { text: "下单" } }
        QSkinTimelineItem { id: ti2; type: "success"; label: "10:30"; Body { text: "审核" } }
        QSkinTimelineItem { id: ti3; Body { text: "发货" } }
    }

    QSkinTimeline {
        id: tlB

        x: 400
        y: 220
        width: 300

        QSkinTimelineItem { id: ti4; Body { text: "独立的一份" } }
    }

    /* ══════════════════ 假件 ══════════════════ */

    /* 四个判据共用一个假件：凡是"这一格被装载了"的取证，都靠这个
     * objectName 认领。`control` 是鸭子对象，由宿主推上来 ——
     * 所以断言读的是**宿主推了什么**，而不是"假件自己算了什么"。 */
    Component {
        id: fakeComps

        Rectangle {
            objectName: "m23FakeOther"
            property var control: null
            anchors.fill: parent
        }
    }

    /* ══════════════════ 工具 ══════════════════ */

    QtObject {
        id: cvt
        property color c: "#000000"
    }

    /** 两个 **color 值**逐通道比较。
     *
     *  ⚠ 只接受 color —— **传字符串一律返回 false**，那是它与
     *  `sameTokenQ` 的分工：令牌字符串要先经 `cvt.c = token` 变成 color
     *  再进来。直接把 "#123456" 塞进来会得到一声不响的 false，
     *  表现为"断言红了但看不出为什么"（M23 实录，见 [4] 的注释）。 */
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

    function findAll(item, pred) {
        var out = []
        root.collect(item, pred, out, 0)
        return out
    }

    /** 宿主里装某一格的那个 Loader。
     *  判据是"`sourceComponent` 就是这一格的当前实现" —— 所以它同时是一条
     *  断言：若哪天某个控件把这块底写死成自己的 Component（不再读插槽），
     *  这里返回 null，而不是"找到一个长得像的 Item"继续骗过下面的判据。 */
    function slotLoaderOf(host, comp) {
        return root.findIn(host, function (o) {
            return o.sourceComponent !== undefined && o.sourceComponent === comp
        })
    }

    function thumbLoaderOf(seg) {
        return root.slotLoaderOf(seg, Slots.segmentThumb)
    }

    function dotLoaderOf(ti) {
        return root.slotLoaderOf(ti, Slots.timelineDot)
    }

    /** 插槽实例里那个"圆形容器"（半径等于半宽）。
     *  BasicSegmentThumb 的**根**是 Rectangle 但 radius 固定 sm（不是半宽），
     *  所以不会被误命中；BasicTimelineDot 的 disc 才是。 */
    function discOf(inst) {
        return root.findIn(inst, function (o) {
            if (o.radius === undefined || o.width === undefined) return false
            if (o.width <= 0 || o.color === undefined) return false
            return Math.abs(o.radius - o.width / 2) < 0.51
        })
    }

    /* ══════════════════ 假 control（[5][6] 用） ══════════════════ */

    QtObject {
        id: ctlLast

        property string type: "danger"
        property bool last: true
        property int dotSize: 24
        property var color: undefined
    }

    QtObject {
        id: ctlMid

        property string type: "danger"
        property bool last: false
        property int dotSize: 24
        property var color: undefined
    }

    QtObject {
        id: ctlSmall

        property string type: "danger"
        property bool last: true
        property int dotSize: 10
        property var color: undefined
    }

    QtObject {
        id: ctlTone

        property string type: "primary"
        property bool last: false
        property int dotSize: 10
        property var color: undefined
    }

    /* ══════════════════ 断言 ══════════════════ */

    function run() {
        /* 先把装扮回出厂 —— 否则读到的是上一轮留下的引用，
         * "等于 Basic" 这类断言会静默失去意义。 */
        Slots.reset()

        /* ── [0] 白名单账目 ──
         *
         * 三件事一起读：
         *   · 两格新插槽在名单里，且 reset 之后装的是 Basic
         *   · 名单**总数恰好 21** —— 刻意的常量。加一格就来改这里，
         *     改的时候会看到下面 [1] 那段"为什么这两格值得"。
         *   · 四个具名反例都不在：轮播指示点（QSkinCarousel 文件头写了理由：
         *     三家形态同一路货、差异全在两个数上）、折叠箭头（复用
         *     chevronIndicator）、以及两个写错方向的近似名字。
         *
         * 白名单外键被丢掉的行为也在此取证：`install` 是按白名单**过滤**的，
         * 键名写错会被安静地丢掉（Slots 为此刻意打一条 warn ——
         * "静默通过是最危险的一种通过"）。 */
        root.idx = 0
        root.check(function() {
            var names = Slots.slotNames

            var bothOk = names.indexOf("segmentThumb") >= 0
                         && names.indexOf("timelineDot") >= 0
                         && Slots.segmentThumb === Slots.basicSegmentThumb
                         && Slots.timelineDot === Slots.basicTimelineDot

            var countOk = names.length === 21

            var noExtra = names.indexOf("carouselDot") < 0
                          && names.indexOf("dotIndicator") < 0
                          && names.indexOf("collapseChevron") < 0
                          && names.indexOf("collapseIcon") < 0

            /* 白名单外的键必须被丢掉（写错名字时不能"装上了半格"） */
            var before = Slots.segmentThumb
            Slots.install({ segmentThumbX: fakeComps })
            var filterOk = Slots.segmentThumb === before

            return bothOk && countOk && noExtra && filterOk
        })

        /* ── [1] 四家的覆盖账 ──
         *
         * `segmentThumb`：**只有 Ant** 覆盖。它的那份与 Basic 的差别是
         * "不画描边"（`border.width: 0` vs 1）—— 显式写的，见文件头。
         * `timelineDot`：四家**都不**覆盖。这不是"忘了做"，有两条理由：
         *   · 形态（实心/空心圆）四家一致 —— 差异全在颜色上
         *   · 而颜色走的是 `Theme.color.*` 令牌，四家**自动**各自成立
         *     （BasicTimelineDot 的 `_toneFromType()` 读的就是令牌）
         * 换句话说这一格的"主题差异"已经由令牌表达了，不需要再开一份实现。
         * 这与 M22 的 statusGlyph"只有 shadcn 覆盖"是同一种账。
         *
         * 逐家都查一次"等于 / 不等于 Basic"，而不是只查 Ant：
         * 只查 Ant 会放过"某一家顺手也装了一份长得一样的"。
         * 断言写成 `=== base`（引用相等）而不是"非 null" —— M19 的
         * spinRing 就栽在后者上（四家全没装上，而属性侧一片自洽）。 */
        root.idx = 1
        root.check(function() {
            var bSeg = Slots.segmentThumb
            var bDot = Slots.timelineDot

            var tdOk = true
            var anSeg = false
            var anDot = false
            var acOk = true
            var scOk = true

            TDesign.apply()
            tdOk = Slots.segmentThumb === bSeg && Slots.timelineDot === bDot
            TDesign.remove()

            AntDesign.apply()
            anSeg = Slots.segmentThumb !== bSeg && Slots.segmentThumb !== null
            anDot = Slots.timelineDot === bDot
            AntDesign.remove()

            var backAfterAnt = Slots.segmentThumb === bSeg

            ArcoDesign.apply()
            acOk = Slots.segmentThumb === bSeg && Slots.timelineDot === bDot
            ArcoDesign.remove()

            Shadcn.apply()
            scOk = Slots.segmentThumb === bSeg && Slots.timelineDot === bDot
            Shadcn.remove()

            Slots.reset()
            var backOk = Slots.segmentThumb === bSeg && Slots.timelineDot === bDot

            return tdOk && anSeg && anDot && backAfterAnt && acOk && scOk && backOk
        })

        /* ── [3] QSkinSegmented **没有**读这两格（"不复用"的可执行形式）──
         *
         * BasicSegmentThumb 的文件头花了两大段论证"为什么不复用
         * tabIndicator、也不复用 toggleBackground"。那两段话如果不变成
         * 判据，将来有人"顺手复用一下"时没有任何东西会响。
         *
         * 所以往这两格各装一个带 objectName 的假件，再到分段控制器里找
         * 那个 objectName —— 找不到才算对。 */
        root.idx = 3
        root.check(function() {
            Slots.reset()
            Slots.install({ tabIndicator: fakeComps, toggleBackground: fakeComps })

            var hit = root.findIn(segA, function (o) {
                return o.objectName === "m23FakeOther"
            })

            Slots.reset()

            /* 反向对照：同一时间装 segmentThumb 是**找得到**的 ——
             * 否则"找不到"可能只是"这个函数本来就找不到东西"。 */
            Slots.install({ segmentThumb: fakeComps })
            var found = root.thumbLoaderOf(segA) !== null
            Slots.reset()

            return hit === null && found
        })

        /* ── [4] QSkinTimelineItem 真的读了 timelineDot ──
         *
         * 装假件之后四件事必须同时成立：
         *   · 假件**出现在条目的子树里**（不是自己画了一个点）
         *   · `control.type` 跟着条目的 `type` 走，**且原样透传**
         *     （归一化是插槽的事：宿主传 "nonsense" 就该收到 "nonsense"，
         *     由 [6] 在 Basic 上验它会被归到 default）
         *   · `control.last` 与条目的 `isLast` 一致（ti3 是末条）
         *   · `control.dotSize` 跟着 `dotSize` 变（两次不同取值）
         *   · `control.color` 走"给了就外传、没给就是 undefined"
         *
         * `color` 那一支刻意**两条都读**：只读一次分不清"外传了 color"
         * 与"永远外传 undefined"。 */
        Slots.install({ timelineDot: fakeComps })

        /* ── [6] Basic 的两条取值支路 ──
         *
         * `tone` 的定义是"宿主算好的语义色优先；没给就按 type 自己推"。
         * 两条支路各自独立：
         *   · 不给 color：五种 type 各读一次（四档语义色 + 未知值归 default）
         *   · 给了 color：必须**用它**，而不是仍按 type 推
         *
         * 最后把 color 收回 undefined，读一次确认**会退回去** ——
         * 只验"给了就用"会放过"一旦给过就永远用它"的实现。 */
        root.idx = 6
        root.check(function() {
            var d = Slots.basicTimelineDot.createObject(root, { control: ctlTone })
            if (d === null) return false

            ctlTone.type = "primary"
            var p = root.sameTokenQ(d.tone, Theme.color.brand)
            ctlTone.type = "success"
            var s = root.sameTokenQ(d.tone, Theme.color.success)
            ctlTone.type = "warning"
            var w = root.sameTokenQ(d.tone, Theme.color.warning)
            ctlTone.type = "danger"
            var g = root.sameTokenQ(d.tone, Theme.color.danger)
            ctlTone.type = "不存在的档位"
            var u = root.sameTokenQ(d.tone, Theme.color.borderStrong)

            ctlTone.color = Qt.rgba(0.1, 0.2, 0.3, 1)
            var given = root.sameColorQ(d.tone, Qt.rgba(0.1, 0.2, 0.3, 1))
            ctlTone.color = undefined
            var back = root.sameTokenQ(d.tone, Theme.color.borderStrong)

            d.destroy()

            return p && s && w && g && u && given && back
        })

        /* ── 为回合 2 做准备 ── */

        /* [5] 的三个点：同一份 Basic 实现，三个不同的假 control。
         * 尺寸显式给 —— createObject 出来的件没有布局会撑它，`anchors.fill`
         * 要等一帧才生效，所以这里先钉死宽高，回合 2 再读 disc。 */
        root.dotLast = Slots.basicTimelineDot.createObject(root, { control: ctlLast })
        root.dotMid = Slots.basicTimelineDot.createObject(root, { control: ctlMid })
        root.dotSmall = Slots.basicTimelineDot.createObject(root, { control: ctlSmall })

        if (root.dotLast !== null) {
            root.dotLast.width = 24
            root.dotLast.height = 24
        }
        if (root.dotMid !== null) {
            root.dotMid.width = 24
            root.dotMid.height = 24
        }
        if (root.dotSmall !== null) {
            root.dotSmall.width = 10
            root.dotSmall.height = 10
        }

        /* [7] 的两份**真件**（不经 Loader，随时可造，与装载状态无关） */
        root.realThumb = Slots.basicSegmentThumb.createObject(root, {
            width: 40, height: 24
        })
        root.realDot = Slots.basicTimelineDot.createObject(root, {
            width: 10, height: 10
        })

        /* [2] / [4] 的假件一起装。装完之后**不能**在同一块里读 ——
         * `Loader` 换源之后 `item` 要到下一个事件循环才存在，
         * 同一块里读到的是 null（本文件第一版就栽在这里）。 */
        Slots.install({ timelineDot: fakeComps, segmentThumb: fakeComps })

        step.start()
    }

    Timer {
        id: step

        interval: Theme.motion.normal + 120
        running: false
        repeat: false

        onTriggered: {
            try {

                /* ── [5] Basic 的末点空心 ──
                 *
                 * 文件头承诺"非末条实心、末条空心"。属性侧的证据是
                 * `disc.color.a`（1 vs 0）与 `disc.border.width`
                 * （0 vs max(1, round(size×0.16))）。
                 *
                 * 与像素侧那条**填充率**判据（实心约 0.78、空心约 0.2）
                 * 是两条互不依赖的算路 —— 项目一贯的偏好：同一个事实用
                 * 两条独立的路取证，任一条瞎了另一条还在。
                 *
                 * 三个实例一起读：末条 24、非末条 24、末条 10。
                 * 只读一个尺寸分不清"描边宽跟着 dotSize 缩放"与"写死了一个数"；
                 * 只读末条分不清"空心"与"整体就没填充"。 */
                root.idx = 5
                root.check(function() {
                    var dl = root.discOf(root.dotLast)
                    var dm = root.discOf(root.dotMid)
                    var ds = root.discOf(root.dotSmall)

                    var lastOk = dl !== null
                                 && dl.color.a === 0
                                 && dl.width === 24
                                 && Math.abs(dl.radius - 12) < 0.51
                                 && dl.border.width === Math.max(1, Math.round(24 * 0.16))
                                 && root.sameTokenQ(dl.border.color, Theme.color.danger)

                    var midOk = dm !== null
                                && dm.color.a === 1
                                && dm.width === 24
                                && dm.border.width === 0
                                && root.sameTokenQ(dm.color, Theme.color.danger)

                    var sizeOk = ds !== null
                                 && ds.color.a === 0
                                 && ds.width === 10
                                 && Math.abs(ds.radius - 5) < 0.51
                                 && ds.border.width === Math.max(1, Math.round(10 * 0.16))

                    return lastOk && midOk && sizeOk
                })

                /* ── [7] 没有交互 + 实例互相独立 ──
                 *
                 * 两格插槽的契约第 3 条都写着"插槽里不许放 MouseArea"。
                 * 这一条只能靠读代码守，这里把它变成可执行判据 ——
                 * 它是"盖在内容的上层"的隐患（底自己吃掉点击），
                 * 而截图上看不出来。
                 *
                 * 独立性：两个分段控制器 / 两个时间轴条目各装一份。
                 * 若哪天有人图省事在 Slots 里放一个"共享实例"，两处会变成
                 * **同一个对象** —— 于是两边互相改尺寸，而单看哪一边都对。 */
                root.idx = 7
                root.check(function() {
                    var isMouse = function (o) {
                        return typeof o.containsMouse === "boolean"
                    }
                    var quietOk = root.realThumb !== null
                                  && root.findIn(root.realThumb, isMouse) === null
                                  && root.realDot !== null
                                  && root.findIn(root.realDot, isMouse) === null

                    var t1 = root.thumbLoaderOf(segA)
                    var t2 = root.thumbLoaderOf(segB)
                    var d1 = root.dotLoaderOf(ti1)
                    var d2 = root.dotLoaderOf(ti4)
                    var indepOk = t1 !== null && t2 !== null
                                  && t1.item !== null && t1.item !== undefined
                                  && t2.item !== null && t2.item !== undefined
                                  && t1.item !== t2.item
                                  && d1 !== null && d2 !== null
                                  && d1.item !== null && d1.item !== undefined
                                  && d2.item !== null && d2.item !== undefined
                                  && d1.item !== d2.item

                    return quietOk && indepOk
                })

                /* ── [4] QSkinTimelineItem 真的读了 timelineDot ──
                 *
                 * 装假件之后五件事必须同时成立：
                 *   · 假件**出现在条目的子树里**（不是自己画了一个点）
                 *   · `control.type` 跟着条目的 `type` 走，**且原样透传**
                 *     （归一化是插槽的事：宿主传 "nonsense" 就该收到
                 *     "nonsense"，由 [6] 在 Basic 上验它会被归到 default）
                 *   · `control.last` 与条目的 `isLast` 一致（ti3 是末条）
                 *   · `control.dotSize` 跟着 `dotSize` 变（两次不同取值）
                 *   · `control.color` 走"给了就外传、没给就是 undefined"
                 *
                 * ⚠ 每一处 `control` 的读取都要先确认 `ld.item` 还在。
                 * 装载与读取若挤在同一个同步块里，`Loader` 换源之后
                 * `item` 要到下一个事件循环才存在 —— 读到 null 会让
                 * **整条断言抛异常**，被 `check` 吞成一声不响的"失败"。
                 * 本文件第一版就是这样红的，而拆条探针
                 * （`.cache/_probe_m23t2.qml`）实测四个子条件全真。 */
                root.idx = 4
                root.check(function() {
                    var ld = root.dotLoaderOf(ti2)
                    if (ld === null || ld.item === null || ld.item === undefined)
                        return false
                    var ctl = ld.item.control
                    if (ctl === null || ctl === undefined) return false

                    var found = ld.item.objectName === "m23FakeOther"

                    ti2.type = "primary"
                    var t1 = ctl.type === "primary"
                    ti2.type = "warning"
                    var t2 = ctl.type === "warning"
                    ti2.type = "nonsense"
                    var t3 = ctl.type === "nonsense"
                    ti2.type = "success"

                    var l1 = root.dotLoaderOf(ti1)
                    var l3 = root.dotLoaderOf(ti3)
                    if (l1 === null || l1.item === null || l1.item === undefined
                            || l3 === null || l3.item === null || l3.item === undefined)
                        return false
                    if (l1.item.control === null || l1.item.control === undefined
                            || l3.item.control === null || l3.item.control === undefined)
                        return false
                    var lastOk = l1.item.control.last === ti1.isLast
                                 && l3.item.control.last === ti3.isLast
                                 && ti1.isLast === false && ti3.isLast === true

                    ti2.dotSize = 24
                    var s1 = ctl.dotSize === 24
                    ti2.dotSize = 10
                    var s2 = ctl.dotSize === 10

                    var undefOk = ctl.color === undefined
                    ti2.color = "#123456"
                    /* ⚠ `sameColorQ` 只接受**两个 color 值**，字符串会被它
                     * 直接判 false（见那个函数的第一行 —— 它与 `sameTokenQ`
                     * 的分工就是"令牌字符串要先转成 color"）。这里第一版
                     * 直接传了 "#123456"，于是 [4] 红，而拆条探针里
                     * 换成"只读不比较字符串"的判据就全绿。 */
                    cvt.c = "#123456"
                    var givenOk = ctl.color !== undefined
                                  && root.sameColorQ(ctl.color, cvt.c)
                    ti2.color = "transparent"

                    return found && t1 && t2 && t3 && lastOk && s1 && s2
                           && undefOk && givenOk
                })

                /* 为 [2] 的盒子取证做准备：换到**另一个**段，并等动画收尾。
                 * 换段是必要的 —— 否则 [2] 只是"恰好在第一段上读了一次"，
                 * 而"等分公式"与"读当前段盒子"在第一段上是同一个答案。 */
                segA.value = "详细报表"
                step2.start()
            } catch (e) {
                /* 回合 2 里抛异常 = 这个文件炸了。255 让 8 个位全亮，
                 * 配合 test.sh 打出的 stderr 就能认出来。 */
                Qt.exit(255)
            }
        }
    }

    /* 第三回合：等切换动画收尾，再读活动块的盒子。
     *
     * 为什么不能挤在上一回合：`QSkinSegmented` 的 `thumbLoader` 挂了
     * `Behavior on x / on width` —— 换段之后立刻读 `ld.x` 拿到的是
     * **动画起点**。实测（`.cache/_probe_m23t2.qml`，回传通道是退出码）：
     * 八条子条件里**只有"盒子"这一条红**，其余七条全绿。
     *
     * 这一回合顺带让 `control.enabled` 的两态也读在确定的装载状态上。 */
    Timer {
        id: step2

        interval: Theme.motion.normal + 120
        running: false
        repeat: false

        onTriggered: {
            try {
                /* ── [2] QSkinSegmented 的盒子 = 宿主算的位置 ──
                 *
                 * 契约是"活动块**只有一个**实例，宿主把它摆到当前段的位置
                 * 与尺寸上"。三件事一起读：
                 *   · 假件只有一个（不是每段一个各显各的 —— 那样"动"就没了）
                 *   · 它的 x / width 等于宿主按**当前段的实际盒子**算出的值
                 *     （等分公式在文字长短不一时会错位，而等宽选项上看不出来）
                 *   · 高度撑满轨道（`anchors.margins: root.inset` 那一层）
                 * 最后读 `control.enabled` 的两态。 */
                root.idx = 2
                root.check(function() {
                    var ld = root.thumbLoaderOf(segA)
                    var found = ld !== null && ld.item !== null
                                && ld.item.objectName === "m23FakeOther"

                    var oneOk = root.findAll(segA, function (o) {
                        return o.objectName === "m23FakeOther"
                    }).length === 1

                    var boxOk = ld !== null
                                && ld.x === segA._thumbX()
                                && ld.width === segA._thumbW()
                                && ld.width > 0
                                && ld.y === 0
                                && ld.parent !== null
                                && ld.height === ld.parent.height

                    segA.enabled = false
                    var offOk = ld !== null && ld.item.control.enabled === false
                    segA.enabled = true
                    var onOk = ld !== null && ld.item.control.enabled === true

                    return found && oneOk && boxOk && offOk && onOk
                })

                Slots.reset()
                Qt.exit(root.mask)
            } catch (e) {
                Qt.exit(255)
            }
        }
    }

    /* 看门狗：正常路径下走不到这里。 */
    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }

    /* 推迟一轮：Qt Quick Layouts 把尺寸重算放在 polish 阶段，
     * 在 onCompleted 里同步读会读到重算之前的值（见 smoke_sizes.qml）。
     * 回合 1 里造实例、回合 2 里读布局后的盒子，也是同一个理由。 */
    Component.onCompleted: function() {
        try {
            Qt.callLater(root.run)
        } catch (e) {
            Qt.exit(255)
        }
    }
}
