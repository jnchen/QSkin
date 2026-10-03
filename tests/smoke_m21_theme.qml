/****************************************************************************
 * QSkin · 冒烟测试 — M21.1：浮层家族的**装载**契约
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件为什么存在（与 M19/M20 的装载测试同源，但问题不一样）────────
 * 前几批的装载风险是"装上了，但装错了那一份"。M21 的风险更靠前一步：
 *
 *     **根本不该新开一格。**
 *
 * COVERAGE.md 写着这一族"Popover 是基座，其余五个都是 Popover + 一份内容"。
 * 落到插槽上就是一条架构判断（见 QSkinPopover 文件头）：
 *
 *     浮层面板的外观**复用 selectOverlay**，不为 Popover 新开插槽。
 *
 * 这条判断最容易在半年后被无声推翻 —— 某人要一个"气泡专用的圆角"，
 * 顺手加一格 `popoverOverlay`，于是六件浮层与 QSkinMenu / QSkinSelect 开始
 * 各走各的外观，而**单看任何一张截图都看不出**：两格都长得对，
 * 只是换肤时其中一格不再跟随。
 *
 * 所以 [0] 不去查"引用换没换"（那太弱），而是**给它一个假外壳**：
 * 如果 Popover 真的读 selectOverlay，假外壳的 padding/extender 必须
 * 立刻出现在 Popover 上。若哪天新开了一格，这一条就红 —— 那正是
 * "抽象被推翻"这个事件本身。
 *
 * ── 五家浮层外壳的 (padding, extender) 矩阵 ─────────────────────────────
 *
 *     Basic     (4, 0)     ← 出厂，无阴影
 *     TDesign   (8, 3)     ← 唯一改内边距的（--td-pop-padding-l）
 *     Ant       (4, 3)
 *     Arco      (4, 2)
 *     shadcn    (4, 4)
 *
 * 五组 (padding, extender) **两两不同**，所以逐家读这两个数就能证明
 * "每一家装了自己那一份"。Ant 与 TDesign 的 extender 都是 3，
 * 但 padding 8 ≠ 4，仍然分得开。
 *
 * extender 不是装饰数：它是 M4 回收的契约（`Popup` 把自己放大
 * extender×2，主题画的阴影才不被裁）。它在**位置上**的可观测后果是
 *
 *     面板场景原点 − target 底边 === gap + extender
 *
 * 所以每一家除了读数，还要把这条差式量一遍 —— 只读属性的话，
 * "宿主读了 extender 但没用上"（阴影仍被裁）会逃掉。
 *
 * ── 断言上限 8 条 ───────────────────────────────────────────────────────
 * 位掩码退出码见 tools/test.sh 文件头。
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
     *  不带它的话，run() 里任何一处 TypeError 都会让 `Qt.exit` 永不执行,
     *  而 qml.exe 是开着窗口的 GUI 进程 —— 测试不是失败，是永远挂着。
     *  （smoke_m21.qml 里真的撞过一次，见那份文件头。） */
    function check(block) {
        var ok = false
        try { ok = block() === true } catch (e) { ok = false }
        root.expect(ok)
    }

    /* ══════════════════ 被测对象 ══════════════════ */

    /* 锚点位置写成**绑定**（不是字面量）：本文件 [1]~[5] 用 belowGap 验
     * "面板顶边 − 锚点底边 === gap + extender"，而字面量会让锚点在
     * 实例化时就落值，于是下面的判据永远恰好成立 —— 退化成同义反复。
     * smoke_m21.qml 那边有同一处说明；QSkinPopover 的 targetOrigin 当初
     * 就是在这里栽的（绑定惰性求值 → 只算一次 → 停在 (0,0)）。 */
    readonly property int anchorX: 396
    readonly property int anchorY: 200

    QSkinButton {
        id: anchor
        x: root.anchorX
        y: root.anchorY
        width: 120
        height: 32
        text: "目标"
    }

    QSkinPopover {
        id: pop

        target: anchor
        panelWidth: 240

        Rectangle { implicitWidth: 60; implicitHeight: 20; color: "#FF0000" }
    }

    QSkinDropdown {
        id: dd
        x: 60
        y: 420
        text: "动作"
        model: ["编辑", "复制"]
    }

    QSkinNotification {
        id: notify
        defaultDuration: 0
    }

    /* ══════════════════ 假件 ══════════════════
     *
     * 假外壳的 (11, 7) 与五家的任何一组都不同 —— 读到它只可能是
     * "真的去读了当家的那一格"。 */
    Component {
        id: fakeOverlay
        Item {
            property var  control: null
            property Item content: null
            property int  padding: 11
            readonly property real extender: 7
            implicitWidth: 40
            implicitHeight: 20
        }
    }

    /* 假 label 带一个可被认领的 objectName —— 用来证明"通知卡的标题
     * 走的是 label 插槽"，而不是它自己画了一个 Text。 */
    Component {
        id: fakeLabel
        Item {
            objectName: "m21FakeLabel"
            property var control: null
            implicitWidth: 40
            implicitHeight: 18
        }
    }

    /* ══════════════════ 工具 ══════════════════ */

    /** 面板场景原点 − target 底边。见文件头：这应当恒等于 gap + extender。 */
    function belowGap(p) {
        if (!p || !p.panel || !p.target) return -999
        var t = p.target.mapToItem(null, 0, 0)
        var a = p.panel.mapToItem(null, 0, 0)
        return a.y - (t.y + p.target.height)
    }

    /** 在子树里按 objectName 找第一个命中者。
     *  守卫必须落在 `children` 上 —— 一开始写的是 `item.name === undefined`，
     *  而 QtQuick 的 Item **没有** name 属性，于是每一层都直接返回 null，
     *  断言恒假（注意：恒假与"没装上一份"在退出码上长得一模一样）。 */
    function findNamed(item, nm) {
        if (item === null || item === undefined) return null
        if (item.objectName === nm) return item
        var ch = item.children
        if (ch === undefined) return null
        for (var i = 0; i < ch.length; ++i) {
            var hit = root.findNamed(ch[i], nm)
            if (hit !== null) return hit
        }
        return null
    }

    /* ══════════════════ 断言 ══════════════════ */

    function run() {
        /* 先把装扮回出厂，再取"Basic 是哪一份"—— 否则拿到的是上一轮
         * 留下的引用，"不等于 Basic" 这类断言会静默地失去意义。 */
        Slots.reset()

        var basicOverlay = Slots.selectOverlay
        var basicLabel   = Slots.label
        var basicChevron = Slots.chevronIndicator

        /* ── [0] 复用而非新开：Popover 真的在读 selectOverlay ──
         *
         * 给它一个假外壳（11 / 7），Popover 必须立刻跟随。
         * 后半条是"没有为这一族新开格子"的表述式断言：
         * slotNames 是 install 唯一的索引源，多一格就会在这里出现。 */
        Slots.reset()
        root.check(function() {
            var beforeFake = pop.panelPadding === 4 && pop.panelExtender === 0

            Slots.install({ selectOverlay: fakeOverlay })
            pop.open()
            var follows = pop.panelPadding === 11
                          && pop.panelExtender === 7
                          && Math.abs(root.belowGap(pop) - (pop.gap + 7)) <= 0.5
            pop.close()

            var noNewSlot = Slots.slotNames.indexOf("popoverOverlay") < 0
                            && Slots.slotNames.indexOf("popover") < 0
                            && Slots.slotNames.indexOf("overlay") < 0

            Slots.reset()
            var afterReset = Slots.selectOverlay === basicOverlay
                             && pop.panelPadding === 4 && pop.panelExtender === 0

            return beforeFake && follows && noNewSlot && afterReset
        })

        /* ── [1] Basic：(4, 0)，且"没有阴影"这件事也落在位置上 ──
         * extender = 0 时面板应当**紧贴** gap 展开 —— 差式仍然是同一条。 */
        Slots.reset()
        root.check(function() {
            pop.open()
            var ok = pop.panelPadding === 4
                     && pop.panelExtender === 0
                     && Math.abs(root.belowGap(pop) - pop.gap) <= 0.5
            pop.close()
            return ok
        })

        /* ── [2] TDesign：(8, 3) —— 四家里唯一改内边距的那一家 ──
         * 内边距 8 与 4 的差别会直接影响**内容区宽度**（面板定宽 240 时
         * 内容区 224 vs 232），所以这一条同时守住了"内边距属于外观"。 */
        TDesign.apply()
        root.check(function() {
            pop.open()
            var ok = pop.panelPadding === 8
                     && pop.panelExtender === 3
                     && Math.abs(root.belowGap(pop) - (pop.gap + 3)) <= 0.5
            pop.close()
            return ok
        })
        TDesign.remove()

        /* ── [3] Ant / Arco / shadcn 三家各自跟随 ──
         * 三家 extender 互不相同（3 / 2 / 4），一次断言就能证明没有串台：
         * 若哪一家装成了 Basic 的 0，或者两家装成同一份，这里都会红。 */
        /* 三家一起放进**同一条**断言：位掩码只有 8 位，逐家占一位会顶格。
         * 合并不损失证伪力 —— 任何一家串台都会让这一条红。 */
        root.check(function() {
            AntDesign.apply()
            pop.open()
            var adOk = pop.panelPadding === 4 && pop.panelExtender === 3
                       && Math.abs(root.belowGap(pop) - (pop.gap + 3)) <= 0.5
            pop.close()
            AntDesign.remove()

            ArcoDesign.apply()
            pop.open()
            var acOk = pop.panelPadding === 4 && pop.panelExtender === 2
                       && Math.abs(root.belowGap(pop) - (pop.gap + 2)) <= 0.5
            pop.close()
            ArcoDesign.remove()

            Shadcn.apply()
            pop.open()
            var scOk = pop.panelPadding === 4 && pop.panelExtender === 4
                       && Math.abs(root.belowGap(pop) - (pop.gap + 4)) <= 0.5
            pop.close()
            Shadcn.remove()

            return adOk && acOk && scOk
        })

        /* ── [4] 换肤时**已经在场**的 Popover 也得跟着变 ──
         *
         * 前面三条都是"建好再读"。真正会出事的是另一种时序：Popover
         * 已经开着，用户换了主题（或者宿主改了 `Slots.install`），
         * 那格插槽换了实现类 —— 此时 Loader 必须重新加载，
         * 否则浮层会带着**上一家的内边距与阴影**继续开着，
         * 而页面其余部分已经是新主题了。
         *
         * 断言点选在"值必须变"上：读两次、两次不同、且每次都等于当家的数。 */
        Slots.reset()
        root.check(function() {
            pop.open()
            var live0 = pop.panelExtender === 0 && pop.panelPadding === 4

            Shadcn.apply()
            var live1 = pop.panelExtender === 4 && pop.panelPadding === 4
            Shadcn.remove()

            var live2 = pop.panelExtender === 0 && pop.panelPadding === 4
            pop.close()

            return live0 && live1 && live2
        })

        /* ── [5] Dropdown 的方向箭头走 chevronIndicator ──
         *
         * 项目有一条硬规矩"图标用矢量画，不用字符"（四处出处见
         * BasicChevronIndicator 文件头）。后来它被提升成插槽 ——
         * 于是"某个控件还在用字符箭头"这件事只能靠**引用**来守：
         * 只要 Dropdown 的 icon 不是当家的那一格，这条就红。
         *
         * 四家都换掉了 Basic（Install 里逐个有 chevronIndicator），
         * 所以逐家都要查一次"不等于 basic"，否则"全家装同一份"会逃掉。 */
        Slots.reset()
        root.check(function() {
            var cBasic = dd.icon === basicChevron

            TDesign.apply()
            var cTd = dd.icon === Slots.chevronIndicator
                       && Slots.chevronIndicator !== basicChevron
            TDesign.remove()

            AntDesign.apply()
            var cAd = dd.icon === Slots.chevronIndicator
                       && Slots.chevronIndicator !== basicChevron
            AntDesign.remove()

            Shadcn.apply()
            var cSc = dd.icon === Slots.chevronIndicator
                       && Slots.chevronIndicator !== basicChevron
            Shadcn.remove()

            ArcoDesign.apply()
            var cAc = dd.icon === Slots.chevronIndicator
                       && Slots.chevronIndicator !== basicChevron
            ArcoDesign.remove()

            Slots.reset()
            return cBasic && cTd && cAd && cSc && cAc
        })

        /* ── [6] 通知卡的标题走 label 插槽 ──
         *
         * 与 QSkinDialog 标题、QSkinLabel 是同一格 —— "主题改标题字号字重，
         * 通知卡跟着变"。这条如果断了，症状是"换肤后通知卡的标题还留着
         * 上一家的字"，很难在截图上一眼看出来。
         *
         * 取证方式：把 label 装成一个带 objectName 的假件，
         * 再发一张带标题的通知，卡片子树里**必须**出现它。 */
        Slots.reset()
        root.check(function() {
            Slots.install({ label: fakeLabel })
            var withTitle = notify.show({ title: "同步失败", description: "网络不可达" })
            var foundLabel = withTitle !== null
                             && notify.count === 1
                             && root.findNamed(withTitle, "m21FakeLabel") !== null
            notify.dismissAll()

            Slots.reset()
            var withBasic = notify.show({ title: "同步失败", description: "网络不可达" })
            var goneAfterReset = withBasic !== null
                                 && notify.count === 1
                                 && root.findNamed(withBasic, "m21FakeLabel") === null
            notify.dismissAll()

            return foundLabel && goneAfterReset && Slots.label === basicLabel
        })

        /* ── [7] 通知卡的颜色全部来自令牌，不写死 ──
         *
         * 左侧那条 3px 竖条是"这条通知有多要紧"的唯一视觉表达。
         * 四个 type 各发一张，读出竖条颜色与 `Theme.color.*` 逐一对上。
         *
         * 写死色值会在换主题时立刻穿帮（深色主题下 danger 不是同一个红），
         * 而"穿帮了但没人发现"的原因正是：竖条只有 3px 宽。
         * 所以这一条不看截图，看令牌。
         *
         * 卡片本体的底色 / 描边也一并查：写死 `"#FFFFFF"` 在深色主题里
         * 就是一块刺眼的白 —— 这比竖条的错法更明显，但**更容易**被写成
         * 常量，因为"通知卡当然是白的"看起来太自然了。
         *
         * ── 为什么末尾要在**深色**下再查一遍（M21 变异测试补的）──────────
         * 这条断言原本只跑浅色。问题是：neutral 浅色的 `bgElevated` **就是**
         * `#FFFFFF`，于是"把底色写死成 #FFFFFF"在浅色下是一个**数值空操作** ——
         * 断言读的是值、不是令牌身份，所以它一个字都抓不到。
         *
         * 这不是"变异选得不好"，是**断言没测到它声称要测的东西**：它写着
         * "颜色全部来自令牌"，可最难防的那种写死恰好只在深色下才现形。
         * `.cache/mutate_m21_theme.py` 的 [7·b] 一枪打在这里、当场 MISS，
         * 补的就是这一段。（与 M20 [3] 那次同源：判据要挑**可观测的那条轴**，
         * 而这一格的轴是明暗切换。） */
        Slots.reset()
        root.check(function() {
            var cDanger  = notify.show({ title: "a", type: "danger" })
            var cSuccess = notify.show({ title: "b", type: "success" })
            var cWarning = notify.show({ title: "c", type: "warning" })
            var cInfo    = notify.show({ title: "d" })              /* 缺省 → info */

            var b0 = root.sameColor(root.findBar(cDanger),  Theme.color.danger)
            var b1 = root.sameColor(root.findBar(cSuccess), Theme.color.success)
            var b2 = root.sameColor(root.findBar(cWarning), Theme.color.warning)
            var b3 = root.sameColor(root.findBar(cInfo),    Theme.color.info)

            var b4 = root.sameColor(cDanger, Theme.color.bgElevated)
            var b5 = cDanger !== null && cDanger.border !== undefined
                     && root.sameTokenQ(cDanger.border.color, Theme.color.border)

            /* 换到深色：此时 bgElevated 是 #23232C、danger 是 #EF4444 ——
             * 任何"写死浅色那一套"的实现在这里都会露出来。 */
            Theme.mode = "dark"
            var cDark = notify.show({ title: "e", type: "danger" })
            var b6 = root.sameColor(cDark, Theme.color.bgElevated)
                     && root.sameColor(root.findBar(cDark), Theme.color.danger)
                     && !root.sameColor(cDark, "#FFFFFF")
            Theme.mode = "light"

            notify.dismissAll()
            return b0 && b1 && b2 && b3 && b4 && b5 && b6
        })

        Qt.exit(root.mask)
    }

    /* 语义竖条：宽 3、圆角 1.5、贴在卡片左沿。用"宽 3"认领，
     * 比按树位置取稳 —— 卡片的内部结构还可能变。 */
    function findBar(item) {
        if (item === null || item === undefined) return null
        if (item.width === 3 && item.color !== undefined
            && item.radius !== undefined && item.radius < 2)
            return item
        var ch = item.children
        if (ch === undefined) return null
        for (var i = 0; i < ch.length; ++i) {
            var hit = root.findBar(ch[i])
            if (hit !== null) return hit
        }
        return null
    }

    QtObject {
        id: cvt
        property color c: "#000000"
    }

    /** 两个 QColor 是否同色（按 0..255 取整，浮点误差不造成假红）。
     *  QML 里 QColor 是值类型，`!==` 比的是对象身份不是颜色，
     *  所以颜色一律走这个函数比。
     *
     *  ⚠ 入参**必须是 QColor**。写成"某处直接塞了令牌字符串"是不会报错的：
     *  `"#E2E2E9".r` 是 undefined，比较结果 false，看起来就像"颜色不对"。
     *  真踩过 —— 一个恒假的判据伪装成了实现缺陷。所以这里显式挡一道。 */
    function sameColorQ(a, b) {
        if (a === null || a === undefined || b === null || b === undefined) return false
        if (typeof a === "string" || typeof b === "string") return false
        if (a.r === undefined || b.r === undefined) return false
        return Math.round(a.r * 255) === Math.round(b.r * 255)
            && Math.round(a.g * 255) === Math.round(b.g * 255)
            && Math.round(a.b * 255) === Math.round(b.b * 255)
    }

    /** 一个 Item 的 `color` 是否等于某个令牌。令牌是字符串，先转成 color。 */
    function sameColor(rect, token) {
        if (rect === null || token === undefined || token === null) return false
        cvt.c = token
        return root.sameColorQ(rect.color, cvt.c)
    }

    /** 任意一个 QColor 值是否等于某个令牌。分组的 `border.color` 走这条
     *  （它不在 Item 根上，`sameColor` 够不着）。 */
    function sameTokenQ(actual, token) {
        if (token === undefined || token === null) return false
        cvt.c = token
        return root.sameColorQ(actual, cvt.c)
    }

    /* 看门狗：正常路径下走不到这里（测试 1 秒内就结束了）。
     * 255 → 8 个位全亮，配合 test.sh 打出的 stderr 就是"这个文件炸了"。 */
    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }

    Component.onCompleted: function() { Qt.callLater(root.run) }
}
