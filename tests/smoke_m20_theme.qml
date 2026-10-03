/****************************************************************************
 * QSkin · 冒烟测试 — M20.1：单选指示器 / 开关底板 两格新插槽的**装载**
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件为什么必须存在 ─────────────────────────────────────────────
 * 与 smoke_m19_theme.qml 同源：新插槽最典型的坏法是"装上了，但装错了
 * 一份"，而"非 null"这种断言**永远抓不到它**。抓得住的是两条：
 * **装上去的必须不等于 Basic**，以及**装上去的要带着这一家的签名参数**。
 *
 * ── 本文件额外承担的职责：把一次事实更正变成可证伪的 ────────────────────
 * M20 初版把 `ADRadioIndicator` 写成了**描边策略**，并在文件头用一张
 * 对照表论证"Ant 与 Basic 恰好相反"。查 Ant Design 源码
 * `components/radio/style/index.ts` 后确认默认主题是
 * `radioBgColor = colorPrimary` + `radioColor = colorWhite` —— **实心**。
 * 初版实现的是它那个非默认的 wireframe 主题。
 *
 * 于是这一批的覆盖矩阵变成（圆心直径是各家的官方数）：
 *
 *     TDesign  实心  8     ← 覆盖（8 ≠ Basic 的 6）
 *     Ant      实心  8     ← 覆盖
 *     shadcn   描边  10    ← 覆盖
 *     Arco     实心  5.6   ← **复用 Basic**（5.6 与 6 差 0.4px，肉眼不可分）
 *
 * [0] 与 [1] 把这张表逐格钉死。特别注意 [1] 里 TDesign 与 Ant 的
 * dotSize **必须相等且都等于 8** —— 这不是冗余：两家策略相同、直径相同，
 * 唯一能证明"它们各自装了自己那一份"的，是 [0] 里 TDesign/Ant 的引用
 * 互不相同。两条一起看才有意义，各自单独看都可能被"全家装同一份"骗过。
 *
 * ── 本文件踩到的三个坑（都会让断言红/绿得看不出因果）──────────────────
 * ① **`Behavior on color` 会把立即读取变成"读到动画起点"**
 *    两份 toggleBackground 的底色上都有
 *        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
 *    于是「赋值 → 立刻读」拿到的是**旧值**，目标值要等动画跑完才到。
 *    而 Basic 的旧值恰好是 #ffffff —— 与"未勾选的常态底色"一模一样，
 *    于是失败信息读起来像"勾选态没生效"，其实只是读早了。
 *    解法：**创建时就带上 control**（`createObject(root, { control: … })`）,
 *    初始求值不算"变化"，Behavior 不介入。
 *    这个坑与 M10 抓图里那次"取样时机"是同一类：**测量本身也要有确定的时序**。
 *
 * ② **`bgSunken` / `brandSubtle` 是主题相关的令牌**
 *    Basic 族下 `bgSunken = #F0F0F4`，shadcn 下是 `#F4F4F5`。
 *    期望值必须在对应的 `apply()` 区间**之内**读 —— 出了区间读到的是
 *    上一家的数（或者 Basic 的），于是 shadcn 那条会以一个
 *    差 4 阶的颜色差失败，看起来像"令牌没接上"。
 *
 * ③ **"两家在这条轴上不同"要先算一遍，再写断言**（本轮新踩）
 *    初版 [3] 主张分歧在"开态底色"，可 shadcn 的
 *        brandSubtle = bgSunken = "#F4F4F5"
 *    —— 它没有品牌色，accent 就是 muted。于是那一枪无论怎么打都不会红，
 *    变异测试报 MISSED，而它报得**对**：那确实不是可证伪的差别。
 *    教训：设计语言的分歧写在文件头里是**意图**，能不能被测出来要另算；
 *    一条永远绿的断言比没有断言更糟 —— 它让人以为这里有守卫。
 *    （对照 `BasicToggleBackground` 文件头表格的第一行，那条在 Basic 族
 *      身上成立、在 shadcn 身上退化。逐轴摊开见 [3] 的注释。）
 *
 * ── 断言顺序约定 ────────────────────────────────────────────────────────
 * 位掩码退出码见 smoke_slots.qml 文件头。每条断言上方标了 [n]。
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

    /* ── 冒充插槽的两个假件（只验装载语义，不验形态） ── */
    Component {
        id: fakeRadio
        Item { implicitWidth: 3; implicitHeight: 3 }
    }

    Component {
        id: fakeToggle
        Item { implicitWidth: 5; implicitHeight: 5 }
    }

    /* ── 喂给插槽的假宿主 ──
     * 插槽是鸭子类型：它只读 control 的 checked / hovered / enabled / variant。
     * 用一个 QtObject 就能把它喂饱 —— 不必真造一个 QSkinRadio，
     * 这样"装载"这条链路的验证不被控件实现的任何细节干扰。
     * 一个共享实例即可：每条用例先改字段、再拿它去建插槽。 */
    QtObject {
        id: ctl
        property string variant: "outline"
        property bool checked: false
        property bool pressed: false
        property bool hovered: false
        property bool enabled: true
    }

    // qmllint disable missing-property
    function _make(comp) {
        return comp ? comp.createObject(root) : null
    }

    /** 按指定状态造一个插槽实例。
     *  **状态必须在创建时一起给**（见文件头坑 ①）：先建后设会读到
     *  `Behavior on color` 的动画起点，而那个起点与"常态底色"同色，
     *  失败信息会指向完全错误的方向。 */
    function _makeIn(comp, checked, variant, enabled) {
        ctl.checked = checked
        ctl.variant = variant === undefined ? "outline" : variant
        ctl.hovered = false
        ctl.enabled = enabled === undefined ? true : enabled
        return comp ? comp.createObject(root, { "control": ctl }) : null
    }

    function _num(o, name, dflt) {
        if (!o) return dflt
        var v = o[name]
        return v === undefined || v === null ? dflt : v
    }

    function _hasControl(o) {
        return o ? o.control !== undefined : false
    }

    /** 开关底板的根**就是** Rectangle，色直接挂在根上。
     *  （单选指示器的根是 Item，色在外圈子项上 —— 本文件不读它，
     *   那边的主题身份由 dotSize 这一个数回答就够了。） */
    function _fill(o) {
        if (!o || o.color === undefined) return Qt.rgba(0, 0, 0, 0)
        return o.color
    }

    /** 描边读数。`border` 是分组属性，JS 里直接点得进去。
     *  两份 toggleBackground 的根都是 Rectangle，描边挂在根上。 */
    function _borderColor(o) {
        if (!o || o.border === undefined) return Qt.rgba(0, 0, 0, 0)
        return o.border.color
    }

    function _borderWidth(o) {
        return (o && o.border !== undefined) ? o.border.width : -1
    }
    // qmllint enable missing-property

    QtObject {
        id: cvt
        property color c: "#000000"
    }

    /* 令牌是**字符串**（`Theme.color.bg === "#FFFFFF"`），
     * 而插槽的 .color 是 QColor。赋值给 `property color` 会做转换，
     * 于是两边都能按 0..255 取整比较，浮点误差不会造成假红。 */
    function sameColor(actual, token) {
        cvt.c = token
        return Math.round(actual.r * 255) === Math.round(cvt.c.r * 255)
            && Math.round(actual.g * 255) === Math.round(cvt.c.g * 255)
            && Math.round(actual.b * 255) === Math.round(cvt.c.b * 255)
            && Math.round(actual.a * 255) === Math.round(cvt.c.a * 255)
    }

    function isClear(c) { return Math.round(c.a * 255) === 0 }

    function run() {
        var basicRadio = Slots.basicRadioIndicator
        var basicToggle = Slots.basicToggleBackground

        /* ═══ [0] 覆盖矩阵：该换的换了、不该动的没动 ═══
         *
         * 这一格的不对称是**算出来**的，不是随手定的：
         * TDesign 的圆心 8 与 Basic 的 6 差 2px（小圆点上 33% 的相对差）
         * → 必须自己一格；Arco 的 5.6 与 6 差 0.4px → 复用站得住。
         * 所以 Arco 那条断言写的是 `=== basicRadio`，与另外三家相反。
         *
         * 只查前一半（"换了"）会放过"全家都装同一份"；
         * 只查后一半（"没动"）会放过"一家都没装上"（M19 踩过的那个）。 */
        Slots.reset()

        TDesign.apply()
        var tdRadio = Slots.radioIndicator !== basicRadio
                  && Slots.toggleBackground === basicToggle
        TDesign.remove()

        AntDesign.apply()
        var adRadio = Slots.radioIndicator !== basicRadio
                  && Slots.toggleBackground === basicToggle
        AntDesign.remove()

        Shadcn.apply()
        var scRadio = Slots.radioIndicator !== basicRadio
                  && Slots.toggleBackground !== basicToggle
        Shadcn.remove()

        ArcoDesign.apply()
        var acRadio = Slots.radioIndicator === basicRadio
                  && Slots.toggleBackground === basicToggle
        ArcoDesign.remove()

        root.expect(tdRadio && adRadio && scRadio && acRadio)

        /* ═══ [1] 装上的确实是这一家：按**圆心直径**核 ═══
         *
         * [0] 只证明"换了个对象"——把 ADRadioIndicator 的实例塞进
         * TDesign 那一格，[0] 照样绿。所以这里逐家读各家官方的那个数。
         *
         * 四个数里 8 出现两次（TDesign / Ant）是**对的**：两家策略与直径
         * 确实相同，它们分开的理由在 [0]（两个不同的实现类）。
         * 把这条与 [0] 合起来看，才是"各家装了自己那一份"的完整证据。 */
        TDesign.apply()
        var tdDot = _num(_make(Slots.radioIndicator), "dotSize", -1) === 8
        TDesign.remove()

        AntDesign.apply()
        var adDot = _num(_make(Slots.radioIndicator), "dotSize", -1) === 8
        AntDesign.remove()

        Shadcn.apply()
        var scDot = _num(_make(Slots.radioIndicator), "dotSize", -1) === 10
        Shadcn.remove()

        root.expect(tdDot && adDot && scDot)

        /* ═══ [2] reset 之后回到 Basic 的**行为**，不只是引用 ═══
         *
         * 与 M19 同一条理由：引用换回去了，但 Basic 那份自己被人改过
         * （比如也改成 8）—— 换肤就变成"看起来回到出厂，其实没回"。
         * 所以引用与形态一起查。 */
        Slots.reset()
        var rBasic = _make(Slots.radioIndicator)

        root.expect(Slots.radioIndicator === basicRadio
                    && Slots.toggleBackground === basicToggle
                    && _num(rBasic, "dotSize", -1) === 6)

        /* ═══ [3] 开关底板的主题身份：**靠开态描边**区分 ═══
         *
         * ★ 这一条的措辞是被一次**变异逃逸**改出来的，值得记下来。
         *
         * 初版写的是「唯一能一眼分出来的是勾选之后铺什么底」——
         * Basic 族 → brandSubtle（品牌浅底），shadcn → bgSunken（中性灰）。
         * 这句话在 Basic 族身上成立，**在 shadcn 自己身上是错的**：
         * shadcn 没有品牌色（`tokens.js` 里 brand 一族填的是灰阶），
         *         brandSubtle = "#F4F4F5"   // accent = muted
         *         bgSunken    = "#F4F4F5"   // muted zinc-100
         * 是同一个数。于是「把 bgSunken 换成 brandSubtle」这一枪
         * **在屏幕上、在属性上都不可观测**，变异测试报 MISSED ——
         * 而它报得对：那确实不是一条能被证伪的差别。
         *
         * 把两份实现逐轴摊开（都以 shadcn 令牌求值、outline + 开态）：
         *
         *     轴        Basic（四家共用）        shadcn
         *     ───────────────────────────────────────────────────────
         *     底色      brandSubtle #F4F4F5      bgSunken #F4F4F5   ← 同值
         *     描边宽    1                        1                  ← 同值
         *     描边色    brand #18181B            "transparent"      ← 只有这条
         *
         * 所以这一格可观测的身份落在**描边**上，不在底色上。
         * 两家在这条轴上是**相反**的：Basic 认为"选中的东西该有轮廓"，
         * 于是开态给一圈品牌色；shadcn 认为底色已经说清了，把轮廓
         * 让给常态（关着的时候才需要边框告诉用户"这里有个框"）。
         *
         * 断言因此成对：**开态描边必须透明** + **常态描边必须正在用
         * border 那一档色**。第二条是第一条的标尺 —— 只查"开态是透明的"，
         * 会被"干脆一行描边都不画"骗过（那也是一种 bug，但成因完全不同）。
         * 两条一起，量的是"轮廓在哪个状态出现"，不是"有没有轮廓"。
         *
         * 底色那半仍然留着（`onBasic` / `onSc`）：它守的是 Basic 族那一侧
         * —— 在 Basic / TDesign / Ant / Arco 的令牌下 brandSubtle 与
         * bgSunken 是**不同的数**（中性 #F3E8FF vs #F4F4F5 之类），
         * 于是"开关开态铺品牌浅底"这条在那里是可证伪的。
         *
         * "常态不画底"顺带钉一下：outline 变体两份都有底
         * （Basic 是 Theme.color.bg，shadcn 是 transparent），
         * 而 default 变体两家都不画底 —— 这正是当初把 toggleBackground
         * 从 buttonBackground 里分出来的理由（见那份文件头的三条证据）。 */
        var onBasicSlot = _makeIn(Slots.basicToggleBackground, true, "outline")
        var onBasic = sameColor(_fill(onBasicSlot), Theme.color.brandSubtle)

        var offBasicSlot = _makeIn(Slots.basicToggleBackground, false, "outline")
        var offBasicOk = sameColor(_fill(offBasicSlot), Theme.color.bg)

        var offDefaultSlot = _makeIn(Slots.basicToggleBackground, false, "default")
        var offDefaultOk = isClear(_fill(offDefaultSlot))

        Slots.reset()
        Shadcn.apply()
        var onScSlot = _makeIn(Slots.toggleBackground, true, "outline")
        var onSc = sameColor(_fill(onScSlot), Theme.color.bgSunken)

        /* ★ 描边必须在建 `offScSlot` **之前**读：两份实例共用同一个假宿主
         * （`ctl`），而 `_makeIn` 会把 `ctl.checked` 改成 false ——
         * `onScSlot.control` 就是 `ctl`，迟一步读到的已经是关闭态。
         * （这与文件头坑 ① 同源：测量本身要有确定的时序。） */
        var scEdgeOn = isClear(_borderColor(onScSlot))
                       && _borderWidth(onScSlot) === 1

        var offScSlot = _makeIn(Slots.toggleBackground, false, "outline")
        var offScOk = isClear(_fill(offScSlot))
        var scEdgeOff = sameColor(_borderColor(offScSlot), Theme.color.border)
        /* 常态可见性在 [4] 里断言，这里只把 shadcn 那一份的 opacity 存下来 */
        var scOpacityOn = _num(onScSlot, "opacity", -1)
        Shadcn.remove()

        root.expect(onBasic && onSc && offBasicOk && offScOk && offDefaultOk
                    && scEdgeOn && scEdgeOff)

        /* ═══ [4] 开关底板：**常态必须可见**（opacity 不为 0）═══
         *
         * 这是新增这一格的核心理由之一：Basic 的 buttonBackground 在
         * ghost 变体下常态 `opacity: 0`（"悬停才浮出来"的幽灵按钮），
         * 而开关如果不画出来，就没有任何东西告诉用户"这里可以点"。
         *
         * 两份实现都写着 `opacity: disabled ? 0.5 : 1`。只读一个数，
         * 却守住了一条设计规矩。禁用档也一起查 —— 一个"禁用却仍然
         * 全不透明"的开关会看起来完全可用。 */
        var visBasic = _makeIn(Slots.basicToggleBackground, false, "outline")
        var visBasicOn = _num(visBasic, "opacity", -1) === 1

        var disBasic = _makeIn(Slots.basicToggleBackground, false, "outline", false)
        var disOpacity = _num(disBasic, "opacity", -1)

        root.expect(visBasicOn && scOpacityOn === 1
                    && Math.abs(disOpacity - 0.5) < 0.01)

        /* ═══ [5] install 的装载语义：只替换**提供了**的格子 ═══
         *
         * 两次 install 是刻意的次序测试：第二次只提 radioIndicator，
         * 于是第一次装的 toggleBackground **必须还在**。
         * 这条契约让主题可以只提交自己关心的那几格，其余自动继承 ——
         * 没有它，每家主题都得把 18 格抄一遍，抄漏一格的表现是
         * "这一格退回 Basic"，极难发现。 */
        Slots.reset()
        Slots.install({ toggleBackground: fakeToggle })
        var afterOne = Slots.toggleBackground === fakeToggle
                    && Slots.radioIndicator === basicRadio
        Slots.install({ radioIndicator: fakeRadio })
        var afterTwo = Slots.radioIndicator === fakeRadio
                    && Slots.toggleBackground === fakeToggle
        Slots.reset()

        root.expect(afterOne && afterTwo
                    && Slots.radioIndicator === basicRadio
                    && Slots.toggleBackground === basicToggle)

        /* ═══ [6] install 的**反面**：白名单外的键被忽略、null 被跳过 ═══
         *
         * 这条是 M19 那个真缺陷（四行 install 的键名全带了主题前缀
         * `tdSpinRing`，被静默忽略）的同类护栏 —— M20 的装载行同样是
         * 手写的键名，同样会写错。
         *
         * 后一半守 null：install 对 null 跳过而不是写进去，
         * 否则 `Slots.install({ radioIndicator: null })` 会让控件拿到
         * null，整个单选圈消失（而"没有圈"在静态截图上很不容易发现）。 */
        Slots.reset()
        Slots.install({ tdRadioIndicator: fakeRadio })
        var unknownIgnored = Slots.radioIndicator === basicRadio
        Slots.install({ radioIndicator: null })
        var nullSkipped = Slots.radioIndicator === basicRadio
        Slots.reset()

        root.expect(unknownIgnored && nullSkipped)

        /* ═══ [7] 插槽根的契约：暴露 control、在两格白名单里 ═══
         *
         * 白名单那两项不是装饰：slotNames 是 install 唯一的索引源，
         * 名字漏进白名单的话，任何主题都**装不上**这一格，
         * 而漏掉的表现与"主题没实现它"完全一样（都用 Basic）。
         *
         * 单选圈的尺寸断言用 16：五家一致。这也是"外圈尺寸不该由主题
         * 自己决定"的一条约定 —— 不一致会让换肤带着布局一起跳一下。
         * 开关底板刻意**不**断言尺寸：它 `anchors.fill: parent`，
         * 尺寸由宿主给，不自报隐式尺寸是它的正确行为。 */
        Slots.reset()
        var cBasic = _make(Slots.radioIndicator)

        TDesign.apply()
        var cTd = _make(Slots.radioIndicator)
        var tdSize = _num(cTd, "implicitWidth", -1) === 16
        TDesign.remove()

        root.expect(_hasControl(cBasic) && _hasControl(cTd)
                    && tdSize
                    && _num(cBasic, "implicitWidth", -1) === 16
                    && Slots.slotNames.indexOf("radioIndicator") >= 0
                    && Slots.slotNames.indexOf("toggleBackground") >= 0)

        Qt.exit(root.mask)
    }

    Component.onCompleted: function() { Qt.callLater(root.run) }
}
