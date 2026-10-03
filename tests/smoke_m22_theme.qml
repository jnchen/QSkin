/****************************************************************************
 * QSkin · 冒烟测试 — M22.1：statusGlyph 插槽的**装载**契约
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件为什么存在 ──────────────────────────────────────────────────
 * M22 新增了 Slots 的**第六个家族**：`glyph`（语义状态记号）。前五族是
 * button / input / check·switch·radio·toggle / slider·progress /
 * tab·breadcrumb·step·chevron / label —— 每一族都可能被"再多开一格"
 * 悄悄撑大。这一族面对的具体诱惑是：
 *
 *     三个控件都要按语义画记号，那就给三个控件各开一格
 *     （alertGlyph / resultGlyph / dialogGlyph）。
 *
 * COVERAGE.md 与 BasicStatusGlyph 的文件头都写明这一族**必须只有一格**：
 * 三处画的是同一枚记号，差异只在尺寸（由宿主管）与形态（由主题管）。
 * 一旦各开一格，就会立刻退化成"三枚长得差不多但换肤时各自为政"的记号，
 * 而**单看任何一张截图都看不出** —— 三格都长得对，只是其中某一格不跟了。
 *
 * 所以 [0] 不用"读引用换没换"这种弱判据，而是数白名单里带 "lyph" 的
 * 名字**恰好一个**：多一格就红。
 *
 * ── 为什么"形态"这条能在属性侧守（而不只是靠像素）──────────────────
 * BasicStatusGlyph（TD / Ant / Arco 共用）与 SCStatusGlyph（shadcn）
 * 的形态分歧是两个**结构**上的事实，不只在像素上：
 *
 *     Basic   圆容器 = Rectangle{ radius: width/2, color: 语义色 }  无描边
 *     shadcn  圆容器 = Rectangle{ radius: width/2, color: transparent,
 *                                border.width: width/12, border.color: 语义色 }
 *
 * 于是 [2] 读三个量（填充色 / 描边宽 / 描边色）就能分辨同一件事 ——
 * 与 `.cache/_verify_m22.py` 那条**填充率**判据（实心 0.68~0.81 vs
 * 描边 0.38~0.45）是两条互不依赖的算路。项目一贯的偏好：同一个事实
 * 用两条独立的路取证，任一条瞎了另一条还在。
 *
 * ⚠ 但两处的**取值来源必须一致**：像素侧那 8 张图量的是 `.cache/shot_m22.qml`
 * 的 rig，本文件量的是这里自己声明的实例。两者若对角色的理解不同
 * （比如一边按 warning、一边按 danger），结论就不能互相印证。
 * [2] 因此显式把 `al.type` 钉成 "danger" —— 与抓图屏上第 4 条一致。
 *
 * ── 一个必须提防的坑：假件是 Component，`control` 是鸭子对象 ────────
 * 假件的 `control` 只提供契约里写明的两个字段（status / size）。宿主
 * 通过 `Binding { property: "control" }` 推给它 —— 所以这里的断言读的是
 * **宿主推了什么**，而不是"假件自己算了什么"。这正是取证点：宿主若
 * 自己算尺寸、不推给插槽，[5] / [6] 立刻红。
 *
 * ── 断言上限 8 条（位掩码退出码，见 tools/test.sh 文件头）──────────────
 *   [0] 这一族只有一格 + 装载基线      [1] 四家里只有 shadcn 覆盖
 *   [2] 形态分歧（实心 vs 描边）        [3] 尺寸契约（含缺省分支）
 *   [4] 实例互相独立 + 没有交互         [5] QSkinAlert 真的在读这一格
 *   [6] QSkinResult 真的在读这一格        [7] QSkinAlertDialog 也读同一格
 *
 * [7] 是"零新增插槽"的正面证据：对话框的记号长在 `Popup` 里（`Popup`
 * 不是 `Item`，从控件往下遍历走不到，见 smoke_m22.qml 文件头），
 * 所以它从**窗口树**里认领（打开期间才存在）。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Window 2.15
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

    width: 900
    height: 700

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    /** 跑一段会写断言的代码；抛异常算这一条失败。
     *
     *  ⚠ 这道防线有代价：它会把 TypeError（例如调用一个必填参数的信号
     *  却忘了传参 —— Qt 6 的 `MouseArea.clicked` 就是这样）**吞成一声
     *  不响的"这一条失败"**，看起来像实现没接线。smoke_m22.qml 的文件头
     *  记了那次实录。红了先怀疑调用姿势，再怀疑实现。 */
    function check(block) {
        var ok = false
        try { ok = block() === true } catch (e) { ok = false }
        root.expect(ok)
    }

    /* ══════════════════ 被测对象 ══════════════════ */

    QSkinAlert {
        id: al

        x: 10
        y: 10
        width: 380
        type: "danger"
        title: "删除失败"
    }

    QSkinResult {
        id: res

        x: 420
        y: 10
        width: 368
        status: "success"
        title: "提交成功"
    }

    QSkinAlertDialog {
        id: ad

        type: "warning"
        title: "确认删除？"
        cancelText: "放弃"
        confirmText: "删除"
    }

    /* ── 尺寸契约（[3]）的两条支路 ──
     * 契约写着"插槽自己声明 implicitWidth/implicitHeight（= size）"，
     * 而 `size` 来自宿主推的 `control`。所以两条支路：
     *   bareGlyph  没有 control → 落到主题缺省 Theme.size.iconMd
     *   probeGlyph 一个只报 size=48 的鸭子 → 隐式尺寸必须变成 48
     * 这两条与三个真实控件无关，是**契约本身**的可证伪形式。 */
    Loader {
        id: bareGlyph

        x: 10
        y: 200
        sourceComponent: Slots.statusGlyph
    }

    Loader {
        id: probeGlyph

        x: 60
        y: 200
        sourceComponent: Slots.statusGlyph

        Binding {
            target: probeGlyph.item
            property: "control"
            value: probeCtl
            when: probeGlyph.status === Loader.Ready
        }
    }

    QtObject {
        id: probeCtl

        readonly property string status: "info"
        readonly property int size: 48
    }

    /* ══════════════════ 假件 ══════════════════ */

    /** 假记号：带上一个可被认领的 objectName。
     *  它的 `implicitWidth` 刻意**不等于** size —— 这样"宿主推了 size"
     *  这件事只能从 `control` 上读出来，不会被假件自己的尺寸混过去。 */
    Component {
        id: fakeGlyph

        Item {
            objectName: "m22FakeGlyph"
            property var control: null
            implicitWidth: 30
            implicitHeight: 30
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

    /** 一个宿主里的记号实例：认领方式不是"某个 Item"，而是
     *  **`sourceComponent === Slots.statusGlyph` 的那个 Loader 的 item**。
     *
     *  这一条同时是断言：若哪天某个控件把记号写死成自己的 Component
     *  （不再读插槽），这里返回 null —— 而不是"找到了一个长得像的 Item"
     *  继续骗过下面所有判据。 */
    function glyphOf(host) {
        var ld = root.findIn(host, function (o) {
            return o.sourceComponent !== undefined && o.sourceComponent === Slots.statusGlyph
        })
        if (ld === null) return null
        return (ld.item === undefined) ? null : ld.item
    }

    /** 记号里那个**圆形容器**。
     *  Basic 是实心盘（color = 语义色、无描边）；shadcn 是圆环
     *  （color = transparent、border 是语义色）。两者都是
     *  `Rectangle { radius: width/2 }`，所以按"半径等于半宽"认领。 */
    function discOf(glyph) {
        return root.findIn(glyph, function (o) {
            if (o.radius === undefined || o.width === undefined) return false
            if (o.width <= 0 || o.color === undefined) return false
            return Math.abs(o.radius - o.width / 2) < 0.51
        })
    }

    /** 在窗口树里找**对话框**那枚记号。
     *
     *  两次过滤都不能少：
     *    · 从 `window.contentItem` 起步（Popup 的内容挂在窗口 overlay 上，
     *      不在控件子树里，见文件头）
     *    · 再用 `underNode(o, root)` 把 root 自己那一支摘掉 —— 本文件里
     *      Alert 与 Result 也装着同一枚假件，而 root 正是 contentItem
     *      的子项，先撞上的会是它们，而不是对话框那枚
     *
     *  `Popup` 的内容**只在打开期间存在**，所以这个函数必须等一个回合
     *  之后才能返回非 null。 */
    function glyphInWindow() {
        var win = root.Window.window
        if (win === null || win === undefined) return null
        if (win.contentItem === null || win.contentItem === undefined) return null
        var hits = root.findAll(win.contentItem, function (o) {
            return o.objectName === "m22FakeGlyph" && !root.underNode(o, root)
        })
        return hits.length > 0 ? hits[0] : null
    }

    /** `o` 是不是 `anc` 的后代（沿 parent 链走）。 */
    function underNode(o, anc) {
        var p = o
        var guard = 0
        while (p !== null && p !== undefined && guard < 64) {
            if (p === anc) return true
            p = p.parent
            guard++
        }
        return false
    }

    /* ══════════════════ 断言 ══════════════════ */

    function run() {
        /* 先把装扮回出厂，再取"Basic 是哪一份"—— 否则拿到的是上一轮
         * 留下的引用，"不等于 Basic" 这类断言会静默地失去意义。 */
        Slots.reset()
        root.basicGlyph = Slots.statusGlyph

        /* ── [0] 装载基线，以及"这一族只有一格" ──
         *
         * 三条一起读：
         *   · reset 之后装的是 Basic
         *   · 白名单里名字带 "lyph" 的**恰好一个**（= statusGlyph）——
         *     多一格就红，这是本文件存在的主要理由
         *   · 三个"每控件一格"的疑似名字都不在
         *
         * 白名单外键被忽略的行为也在此顺带取证：`install` 是**按白名单
         * 过滤**的，键名写错会被安静地丢掉（Slots.qml 为此刻意打一条
         * warn —— "静默通过是最危险的一种通过"）。 */
        root.check(function() {
            var basicOk = root.basicGlyph !== null
                          && Slots.statusGlyph === root.basicGlyph

            var names = Slots.slotNames
            var n = 0
            for (var i = 0; i < names.length; ++i) {
                if (String(names[i]).indexOf("lyph") >= 0) n++
            }
            var oneOk = n === 1 && names.indexOf("statusGlyph") >= 0

            var noPerWidget = names.indexOf("alertGlyph") < 0
                              && names.indexOf("resultGlyph") < 0
                              && names.indexOf("dialogGlyph") < 0
                              && names.indexOf("glyph") < 0

            /* 白名单外的键必须被丢掉（写错名字时不能"装上了半格"） */
            var before = Slots.statusGlyph
            Slots.install({ alertGlyph: fakeGlyph })
            var filterOk = Slots.statusGlyph === before

            return basicOk && oneOk && noPerWidget && filterOk
        })

        /* ── [1] 四家主题里只有 shadcn 覆盖这一格 ──
         *
         * 这是 BasicStatusGlyph 文件头那条"2 份实现而不是 5 份"的可证伪
         * 形式：TD / Ant / Arco 在这一格的差异只有**尺寸**，而尺寸由宿主
         * 给，形态与 Basic 一致 → 继承即可。
         *
         * 逐家都查一次"等于 / 不等于 basic"，而不是只查 shadcn：
         * 只查 shadcn 会放过"某一家顺手也装了一份长得一样的"。
         * 断言写成 `=== basic`（引用相等）而不是"非 null" ——
         * M19 的 spinRing 就栽在后者上（四家全没装上，而属性侧一片自洽）。 */
        Slots.reset()
        root.check(function() {
            var base = root.basicGlyph

            TDesign.apply()
            var td = Slots.statusGlyph === base
            TDesign.remove()

            AntDesign.apply()
            var an = Slots.statusGlyph === base
            AntDesign.remove()

            ArcoDesign.apply()
            var ac = Slots.statusGlyph === base
            ArcoDesign.remove()

            Shadcn.apply()
            var sc = Slots.statusGlyph !== base && Slots.statusGlyph !== null
            Shadcn.remove()

            Slots.reset()
            var back = Slots.statusGlyph === base

            return td && an && ac && sc && back
        })

        /* ── [2] 形态分歧：实心盘 vs 描边环 ──
         *
         * 与像素侧那条**填充率**判据是两条独立算路（见文件头）。
         * `al.type` 显式钉成 "danger"：shadcn 的圆容器在 warning 下会
         * 让位给三角形（`visible: root.status !== "warning"`），
         * 挑 danger 才能让两边都拿圆容器比。
         *
         * ── ⚠ 判别量只能是 `color.a`，不能是 `border.width` ────────────
         * 第一版写的是"Basic 侧断言 border.width < 1"，实测当场红：
         *
         *     Basic   color=(0.86,0.15,0.15) color.a=1  border.w=1
         *             border.color=(0,0,0) alpha=1
         *     shadcn  color.a=0              border.w=1.667（= size/12）
         *             border.color=(0.94,0.27,0.27)（语义色）
         *
         * 也就是说 `Rectangle` 的 `border.width` **默认读到 1**、
         * `border.color` 读到**不透明的黑** —— 但画面上一根线都没有。
         * 直接量像素（.cache/m22_tdesign_light_base.png 的盘边缘）：
         *
         *     底板 (242,243,255) → (16,93,220) → (0,82,217)
         *
         * 中间那一个像素是"底板与语义色各半"，**不是与黑色各半**。
         * 结论：`border.*` 的默认值在属性上"存在"，在绘制上"不存在" ——
         * 拿它当判据会得出与像素相反的结论。
         *
         * 所以两侧各读各的**语义色落在哪个量上**：
         *   Basic  填充是语义色（实心）
         *   shadcn 填充透明、语义色落在描边上（描边环）
         * 这正是两种形态的定义，而且两个量都是"画面真用了的"那一批。 */
        Slots.reset()
        al.type = "danger"
        root.check(function() {
            var ga = root.glyphOf(al)
            var da = root.discOf(ga)
            var basicOk = da !== null
                          && da.color.a === 1
                          && root.sameTokenQ(da.color, Theme.color.danger)

            Shadcn.apply()
            var gs = root.glyphOf(al)
            var ds = root.discOf(gs)
            var scOk = ds !== null
                       && ds.color.a === 0
                       && ds.border.width > 0
                       && root.sameTokenQ(ds.border.color, Theme.color.danger)
            Shadcn.remove()

            var gb = root.glyphOf(al)
            var db = root.discOf(gb)
            var back = db !== null
                       && db.color.a === 1
                       && root.sameTokenQ(db.color, Theme.color.danger)

            return basicOk && scOk && back
        })

        /* ── [3] 尺寸契约：implicitWidth/Height 跟着宿主推的 size ──
         *
         * 契约是"插槽自己声明 implicitWidth/implicitHeight（= size）"。
         * 两条支路各自独立：
         *   · 没有 control → 落到 Theme.size.iconMd（"不给定尺寸就按主题
         *     缺省摆"这句承诺的可证伪形式）
         *   · control 报 48 → 隐式尺寸必须**立刻**是 48
         *
         * 再与真实宿主对一次：`glyphOf(al).implicitWidth === control.size`
         * —— 把"声明"和"上报"绑在同一条式子里，不写死任何常量。
         * 后面 [6] 还会在改 glyphSize 之后再读一遍（只读缺省值那一遍
         * 分不清"读了 size"和"写死了 20"）。 */
        Slots.reset()
        root.check(function() {
            var bare = bareGlyph.item
            var defOk = bare !== null
                        && bare.control === null
                        && bare.implicitWidth === Theme.size.iconMd
                        && bare.implicitHeight === Theme.size.iconMd

            var pi = probeGlyph.item
            var sizedOk = pi !== null
                          && pi.control === probeCtl
                          && pi.implicitWidth === 48
                          && pi.implicitHeight === 48

            var ga = root.glyphOf(al)
            var hostOk = ga !== null
                         && ga.control !== null
                         && ga.implicitWidth === ga.control.size
                         && ga.implicitHeight === ga.control.size

            return defOk && sizedOk && hostOk
        })

        /* ── [4] 实例互相独立，且没有交互 ──
         *
         * 独立性：三个控件各自的 Loader 会各自实例化一份假件/真件。
         * 若哪天有人图省事在 Slots 里放一个"共享实例"，两份会变成
         * **同一个对象** —— 于是两个宿主互相改尺寸（Alert 的 20 会把
         * Result 的 64 顶掉），而单看任何一个宿主的属性都对。
         *
         * 无交互：插槽契约第 3 条明文禁止 MouseArea / Keys。这一条现在
         * 只有靠读代码守，这里把它变成可执行判据 —— 它是"盖在内容的
         * 上层"的隐患（记号自己吃掉点击），而截图上看不出来。 */
        Slots.reset()
        root.check(function() {
            var ga = root.glyphOf(al)
            var gr = root.glyphOf(res)

            var indepOk = ga !== null && gr !== null
                          && ga !== gr
                          && ga.control !== gr.control

            var isMouse = function (o) { return typeof o.containsMouse === "boolean" }
            var quietOk = ga !== null && root.findIn(ga, isMouse) === null
                          && gr !== null && root.findIn(gr, isMouse) === null

            return indepOk && quietOk
        })

        /* ── [5] QSkinAlert 真的在读这一格 ──
         *
         * 装假件之后两件事必须同时成立：
         *   · 假件**出现在 Alert 的子树里**（不是自己画了一个记号）
         *   · 假件拿到的 `control.status` 跟着 `type` 走，且是**归一化后**
         *     的值（"nonsense" 应当变成 "info"）
         *   · 尺寸是主题的 iconMd，不是控件自己写死的数
         *
         * 逐值读四态：只读一个值分不清"读了 status"与"恰好对上一次"。 */
        Slots.install({ statusGlyph: fakeGlyph })
        root.check(function() {
            var g = root.glyphOf(al)
            var found = g !== null && g.objectName === "m22FakeGlyph"

            al.type = "success"
            var s1 = g !== null && g.control.status === "success"
            al.type = "warning"
            var s2 = g !== null && g.control.status === "warning"
            al.type = "danger"
            var s3 = g !== null && g.control.status === "danger"
            al.type = "info"
            var s4 = g !== null && g.control.status === "info"
            al.type = "nonsense"
            var s5 = g !== null && g.control.status === "info"
            al.type = "danger"

            var sizeOk = g !== null && g.control.size === Theme.size.iconMd

            return found && s1 && s2 && s3 && s4 && s5 && sizeOk
        })

        /* ── [6] QSkinResult 也读这一格，且尺寸跟着 `glyphSize` 走 ──
         *
         * 这一条与 [3] 的分工： [3] 是"插槽按 control.size 声明"，
         * 这里是"**宿主把 glyphSize 推给插槽**"。少了后者，一个把
         * 64 写死在控件里的实现能过 [3]（插槽本身没错，是宿主没推）。
         *
         * `error → danger` 的映射也在这里复核一遍：QSkinResult 的 `_glyphStatus`
         * 把 error / danger 都归 danger（Arco 用前者、Ant 用后者）。
         * smoke_m22.qml 的 [2] 读的是 `_glyphStatus` 本身，这里读的是
         * **它有没有被推给插槽** —— 两条路，同一个事实。 */
        root.check(function() {
            var g = root.glyphOf(res)
            var found = g !== null && g.objectName === "m22FakeGlyph"

            res.status = "error"
            var eOk = g !== null && g.control.status === "danger"
            res.status = "warning"
            var wOk = g !== null && g.control.status === "warning"

            res.status = "success"
            var sOk = g !== null && g.control.status === "success"

            var d64 = g !== null && g.control.size === 64
                      && g.control.size === res.glyphSize

            res.glyphSize = 32
            var d32 = g !== null && g.control.size === 32
                      && g.control.size === res.glyphSize
            res.glyphSize = 64

            return found && eOk && wOk && sOk && d64 && d32
        })

        /* ── [7] QSkinAlertDialog 也读**同一格**（异步，见文件头）──
         * "零新增插槽"在对话框这一侧的正面证据：它没有为自己开一格，
         * 装给 statusGlyph 的假件在它里面照样出现。
         * 尺寸读的是 iconLg（对话框标题比 Alert 的 20 大一档）。 */
        Slots.reset()
        Slots.install({ statusGlyph: fakeGlyph })
        ad.open()
        step.start()
    }

    /** Basic 那一份的引用（[0] 之后才拿得到，[1] 起用） */
    property var basicGlyph: null

    Timer {
        id: step

        interval: Theme.motion.fast + 80
        running: false
        repeat: false

        onTriggered: {
            root.check(function() {
                var g = root.glyphInWindow()
                if (g === null) return false
                return g.control !== null
                       && g.control.status === ad._type
                       && g.control.size === Theme.size.iconLg
            })

            /* 收尾：把插槽还给 Basic，免得计时器还没停就退出 */
            Slots.reset()
            ad.close()
            Qt.exit(root.mask)
        }
    }

    /* 看门狗：正常路径下走不到这里。255 → 8 位全亮，
     * 配合 test.sh 打出的 stderr 就是"这个文件炸了"。 */
    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }

    Component.onCompleted: function() { Qt.callLater(root.run) }
}
