/****************************************************************************
 * QSkin · 冒烟测试 — M19.1：加载指示器两个新插槽的**装载**
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件为什么必须存在（它当场抓到过一个真缺陷）────────────────────
 * M19 给插槽家族加了两个新格：
 *
 *     spinRing   环形加载指示器   Basic / TDesign / Ant / shadcn 四家实现
 *     spinDots   点阵加载指示器   Basic / Arco 两家实现
 *
 * 四家主题各自写好了实现类（TDSpinRing / ADSpinRing / SCSpinRing /
 * ACSpinDots），也各自在自己的 `apply()` 里写了一行 install ——
 * **四行的键名全部写错了**：
 *
 *     Slots.install({ …, tdSpinRing: root.tdSpinRing })   ← 键名带了主题前缀
 *                                        ^^^^^^^^^
 * 而 install 是**按槽位名白名单索引**的（`set["spinRing"]`），
 * 于是四次装载全部命中 undefined、被安静跳过。后果是：
 *
 *     · 四家主题下 `Slots.spinRing` 都**不是 null** —— 它是 Basic 的；
 *     · 控件照样画出一圈弧，不报错、不告警；
 *     · 屏幕上"有个加载圈"，只是它不是这一家的那一个。
 *
 * 也就是说"非 null"这种断言**永远抓不到它**。抓得住的是：
 * **装上去的必须不等于 Basic**，以及**装上去的要带着这一家的形态参数**。
 * 这个文件的 [0] 与 [1] 就是这两条。
 *
 * 修完之后 `Slots.install` 也加了白名单外的键会 warn，把它从
 * "静默失败"降级成"看得见的失败"（见 Slots.qml 里 install 的注释）。
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

    /* ── 用来冒充插槽的两个假件 ──
     * 只用来验证 install 的**装载语义**（谁被换、谁保持），
     * 不参与"形态对不对"的判断。 */
    Component {
        id: fakeRing
        Item { implicitWidth: 7; implicitHeight: 7 }
    }

    Component {
        id: fakeDots
        Item { implicitWidth: 9; implicitHeight: 9 }
    }

    /* ── 把插槽实例化出来读它的形态参数 ──
     *
     * 读法走"按名字取属性"（`o[name]`）：插槽的静态类型是 QQuickItem，
     * 上面那些 `sweepAngle` / `segSweep` / `dotCount` 都是各家自己加的，
     * 静态检查看不到。这是刻意的鸭子类型读取 —— 正是本文件要验的东西。
     * 取不到时返回 dflt，于是"属性没了"会变成断言失败而不是 JS 异常
     * （异常会让 run() 中途退出，连 Qt.exit 都执行不到，退出码变成
     * 一个与位掩码无关的数 —— 那种红最难读）。 */
    // qmllint disable missing-property
    function _make(comp) {
        return comp ? comp.createObject(root) : null
    }

    function _num(o, name, dflt) {
        if (!o) return dflt
        var v = o[name]
        return v === undefined || v === null ? dflt : v
    }

    /* `control` 的出厂值就是 null，所以不能用 _num（它把 null 当缺省值）。
     * 单独一条：只问"这个属性在不在"。 */
    function _hasControl(o) {
        return o ? o.control !== undefined : false
    }
    // qmllint enable missing-property

    /* 颜色比对：走 0..255 的整数值，浮点误差不会造成假红。 */
    QtObject {
        id: cvt
        property color c: "#000000"
    }

    function sameColor(actual, hex) {
        cvt.c = hex
        return Math.round(actual.r * 255) === Math.round(cvt.c.r * 255)
            && Math.round(actual.g * 255) === Math.round(cvt.c.g * 255)
            && Math.round(actual.b * 255) === Math.round(cvt.c.b * 255)
    }

    function run() {
        var basicRing = Slots.basicSpinRing
        var basicDots = Slots.basicSpinDots

        /* ═══ [0] 四家各自装上自己那一格，没覆盖的保持 Basic ═══
         *
         * 覆盖矩阵是**刻意不对称**的（这是这一批最值得守的一件事）：
         *     TDesign / Ant / shadcn  →  覆盖 spinRing，不覆盖 spinDots
         *     Arco                    →  覆盖 spinDots，不覆盖 spinRing
         * 于是四家合计把两格都盖满了，且任何一家单独看都是"缺一格"。
         *
         * 所以断言写成两边都查：**该换的换了**（≠ Basic）**且**
         * **不该动的没动**（=== Basic）。只查前一半会放过"全家都装同一份"，
         * 只查后一半会放过"一家都没装上"（就是这次踩到的那个）。 */
        Slots.reset()

        TDesign.apply()
        var tdOk = Slots.spinRing !== basicRing && Slots.spinDots === basicDots
        TDesign.remove()

        AntDesign.apply()
        var adOk = Slots.spinRing !== basicRing && Slots.spinDots === basicDots
        AntDesign.remove()

        Shadcn.apply()
        var scOk = Slots.spinRing !== basicRing && Slots.spinDots === basicDots
        Shadcn.remove()

        ArcoDesign.apply()
        var acOk = Slots.spinDots !== basicDots && Slots.spinRing === basicRing
        ArcoDesign.remove()

        root.expect(tdOk && adOk && scOk && acOk)

        /* ═══ [1] 装上的确实是这一家：按**形态参数**核 ═══
         *
         * [0] 只能证明"换了个对象"，证明不了"换对了对象"——
         * 把 TDSpinRing 的名字换成 ADSpinRing 的实例，[0] 照样绿。
         * 所以这里逐家读形态参数。三家环的形态语言完全不同：
         *
         *     TDesign   一段 300°（缺口很小，"快合上了"）
         *     Ant       四段 70°、间隔 90°（"齿轮在咬"）
         *     shadcn    两段 120°、对角（"拧"）
         *     Arco      四个点（点阵形态，走 spinDots 那一格）
         *
         * 这是"主题身份"最直接的读数：这三组数字就是这三家的签名。 */
        TDesign.apply()
        var rTd = _make(Slots.spinRing)
        var tdMorph = _num(rTd, "sweepAngle", -1) === 300
                   && _num(rTd, "startAngle", -1) === -90
        TDesign.remove()

        AntDesign.apply()
        var rAd = _make(Slots.spinRing)
        var adMorph = _num(rAd, "segSweep", -1) === 70
                   && _num(rAd, "segStep", -1) === 90
        AntDesign.remove()

        Shadcn.apply()
        var rSc = _make(Slots.spinRing)
        var scMorph = _num(rSc, "segCount", -1) === 2
                   && _num(rSc, "segSweep", -1) === 120
        Shadcn.remove()

        ArcoDesign.apply()
        var dAc = _make(Slots.spinDots)
        var acMorph = _num(dAc, "dotCount", -1) === 4
        ArcoDesign.remove()

        root.expect(tdMorph && adMorph && scMorph && acMorph)

        /* ═══ [2] reset 之后回到 Basic 的**行为**，不只是引用 ═══
         *
         * "回到 Basic"有两层意思，缺一层就会漏：引用换回去了，
         * 但 Basic 那份实现自己被人改过（比如也改成 300°）——
         * 换肤就变成了"看起来回到出厂，其实没回"。
         * 所以引用与形态一起查：Basic 是 270° / 三个点。 */
        Slots.reset()
        var rBasic = _make(Slots.spinRing)
        var dBasic = _make(Slots.spinDots)

        root.expect(Slots.spinRing === basicRing
                    && Slots.spinDots === basicDots
                    && _num(rBasic, "sweepAngle", -1) === 270
                    && _num(dBasic, "dotCount", -1) === 3)

        /* ═══ [3] install 的装载语义：只替换**提供了**的格子 ═══
         *
         * 这条契约的意义在于主题可以只提交自己关心的那几格，
         * 其余自动继承 —— 没有它，每家主题都得把 16 格抄一遍，
         * 而抄漏一格的表现是"这一格退回 Basic"，极难发现。
         *
         * 两次 install 是刻意的次序测试：第二次只提了 spinRing，
         * 于是第一次装的 spinDots **必须还在**（不能被顺带清掉）。 */
        Slots.reset()
        Slots.install({ spinDots: fakeDots })
        var afterOne = Slots.spinDots === fakeDots && Slots.spinRing === basicRing
        Slots.install({ spinRing: fakeRing })
        var afterTwo = Slots.spinRing === fakeRing && Slots.spinDots === fakeDots
        Slots.reset()

        root.expect(afterOne && afterTwo
                    && Slots.spinDots === basicDots && Slots.spinRing === basicRing)

        /* ═══ [4] install 的**反面**：白名单外的键被忽略 ═══
         *
         * 这是 M19 那个真缺陷的**回归护栏**，本文件存在的主要理由。
         * 传一个白名单外的键（`tdSpinRing` —— 就是当初写错的那个名字），
         * 必须什么都不发生。这条曾经会红（那时键名写错，静默忽略 ——
         * 讽刺的是"必须什么都不发生"正是当时的行为）……
         * 所以它单独一条不够，要配合 [0][1] 一起看：
         * [4] 守"错的键不生效"，[0][1] 守"对的键要生效"。
         *
         * 后一半守 null：install 对 null 值跳过而不是把它写进去 ——
         * 否则 `Slots.install({ spinRing: null })` 会让控件拿到 null，
         * 加载圈整个消失（而"没有加载圈"在静态截图上很不容易被发现）。 */
        Slots.reset()
        Slots.install({ tdSpinRing: fakeRing })
        var unknownIgnored = Slots.spinRing === basicRing
        Slots.install({ spinRing: null })
        var nullSkipped = Slots.spinRing === basicRing
        Slots.reset()

        root.expect(unknownIgnored && nullSkipped)

        /* ═══ [5] 两格是两格：都存在、互不相同、都在白名单里 ═══
         *
         * 白名单那两项不是装饰：slotNames 是 install 唯一的索引源，
         * 名字漏进白名单的话，任何主题都**装不上**这一格，
         * 而漏掉的表现与"主题没实现它"完全一样（都用 Basic）。 */
        root.expect(Slots.spinRing !== null
                    && Slots.spinDots !== null
                    && Slots.spinRing !== Slots.spinDots
                    && Slots.slotNames.indexOf("spinRing") >= 0
                    && Slots.slotNames.indexOf("spinDots") >= 0)

        /* ═══ [6] 插槽根的契约：自报尺寸、暴露 control ═══
         *
         * 插槽家族对根有两条约定（见 Slots.qml 文件头）：
         *   · 必须自己声明 implicitWidth / implicitHeight
         *   · 必须暴露 `control` 属性接收宿主
         *
         * 这里的尺寸断言用**默认值 24**：插槽在没接宿主（control 为 null）
         * 时也必须给出一个可用的尺寸，否则在设计器里拖出来是一片空白，
         * 看不出这是个加载圈。四家实现各自都按自己的线宽规则算过，
         * 但边长这一项四家一致（都取 md 档 = 24）—— 不一致的话
         * 换肤会带着布局一起跳一下。
         *
         * rTd / rAd / rSc / dAc 是 [1] 里创建的那几个实例，
         * 它们此刻仍然活着（owner 是 root），可以直接复用。 */
        var W = 24
        root.expect(_hasControl(rTd) && _hasControl(rAd) && _hasControl(rSc)
                    && _hasControl(dAc) && _hasControl(rBasic) && _hasControl(dBasic)
                    && _num(rTd, "implicitWidth", -1) === W
                    && _num(rAd, "implicitWidth", -1) === W
                    && _num(rSc, "implicitWidth", -1) === W
                    && _num(dAc, "implicitWidth", -1) === W
                    && _num(rBasic, "implicitWidth", -1) === W
                    && _num(dBasic, "implicitWidth", -1) === W)

        /* ═══ [7] 插槽的颜色来自令牌，不是硬编码 ═══
         *
         * 这是最后一条，也是唯一一条跨主题的：先在 TDesign 下造一个环，
         * 然后**切到 Ant** 再读它的 tint。
         *
         * 期望它跟着变成 Ant 的品牌色（#1677FF）—— 因为插槽只负责形态，
         * 颜色必须来自 Theme.color.brand 这一个令牌。写死成
         * `#0052D9`（TDesign 的品牌蓝）的实现会在这里红：
         * 那是"形态对了、颜色错了"，静态截图上完全看不出来。
         *
         * 顺带证明切主题时**已经在场的插槽实例**也会跟着变色 ——
         * 这关系到"运行时换肤不重建界面"这条承诺。 */
        TDesign.apply()
        var live = _make(Slots.spinRing)
        AntDesign.apply()
        var followsTheme = sameColor(_num(live, "tint", Qt.rgba(0, 0, 0, 1)), "#1677FF")
        AntDesign.remove()
        Slots.reset()

        root.expect(followsTheme)

        Qt.exit(root.mask)
    }

    Component.onCompleted: function() { Qt.callLater(root.run) }
}
