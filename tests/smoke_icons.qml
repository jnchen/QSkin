/****************************************************************************
 * QSkin · 冒烟测试 —— 图标归位：chevronIndicator 插槽与四个使用者
 *
 * 断言写法见 tools/test.sh 文件头：≤ 8 条，bit n = 断言 [n]。
 *
 * ── 这轮要守的核心不变量 ───────────────────────────────────────────────
 * Slots.qml 从 M1 起就把 indicator 家族写成「勾选框、开关轨道、**展开箭头**」，
 * 但「展开箭头」这一格从来没实现过，于是四处各自绕过去，其中两处直接打了
 * Unicode 字符当图标（QSkinTable 的 "▾"/"▸" 与 "↑"/"↓"，QSkinPagination 的
 * "‹"/"›"）。项目自己对这件事的结论写在四份文件头里（BasicCheckIndicator /
 * QSkinSelect / QSkinTag / QSkinInputNumber），理由都是字形覆盖率与回退不可控。
 *
 * 这一轮要守的两条不变量都不好靠"读代码"保证：
 *
 *   ① **没有任何控件把几何符号当文字画出来**。
 *      断言方式不是 grep 源码（那是 lint 的活），而是**遍历运行时的对象树**
 *      —— 一个控件可能间接持有别人建出来的 Text，源码里根本看不出来
 *      （Repeater 的委托、Loader 的产物都是）。
 *   ② **箭头真的画出来了**。插槽没加载、宿主代理没绑上、direction 传错，
 *      这三种坏法都不会抛错，只会静默地少画一个箭头。所以断言落在
 *      「能扫到带 angle 的箭头对象，且角度对得上」。
 *
 * ── 为什么每条断言都要给定扫描**范围** ──────────────────────────────────
 * 第一版把整个 root 扫一遍，结果五个控件的箭头混在一起数。所以下面
 * 一律用 anglesOf(scope) 限定在那个控件的子树里。
 *
 * ── 为什么叶子节点的箭头不算数 ──────────────────────────────────────────
 * QSkinTable 的行是 Repeater 建的，**没有虚拟化**，所有可见行连同叶子都在
 * 对象树里。而叶子的 treeToggle 是 visible:false，它的 Loader 照样把箭头
 * 建了出来。所以扫描时要求整条**祖先链**都 visible。
 *
 * ── 为什么断言数的是"位置数"而不是"实例数" ──────────────────────────────
 * 表体有**两个宿主**（M13）：固定区投影 + 滚动区 Flickable。两边共用同一套
 * **内容坐标**，靠各自的 clip 把不属于自己那区的部分切掉 —— 所以同一个
 * treeToggle 会被实例化两次，x 相同、视觉上只出现一次。
 *
 * checkable 打开时固定区宽度 > 0，bodyFixed 变 visible，两个宿主的实例就
 * **都**能通过祖先可见性检查（第一版就是这么错的：以为收起的树该有 2 个
 * 箭头，实测 4 个，断言全红）。
 *
 * 正解是把不变量落在**去重后的落点数**上：一个"有子节点"的行 = 一个箭头
 * 位置，与宿主怎么切无关。这比数实例数稳，也比"只扫某一个宿主"诚实
 * —— 后者要在测试里复刻 _fixedWidth 的算法，参照系又偏了。
 *
 * 去重键必须是**映射到共同坐标系的落点**，不能取 .x：同层兄弟缩进相同、
 * x 一模一样（踩过：收起态该有 2 个箭头，按 x 去重只剩 1 个）。
 *
 * 断言分工：
 *   [0] chevron 插槽本体：可加载、尺寸 > 0、四方向 → 角度 0/90/180/270
 *   [1] 语义归属：只靠 control.direction 驱动；首次出现不动画
 *   [2] 四套主题各自覆盖，五份实现互不相同，reset() 复原
 *   [3] **扫描器本身有效**（正向对照）：故意塞一个字符 Text 能被抓到
 *   [4] QSkinTable 树形：收起 2 个箭头全朝右、展开 3 个其中 1 个朝下
 *   [5] QSkinButton.icon 通路（iconDirection 透传）+ QSkinSelect 的 caret
 *   [6] QSkinPagination 上下页：文字为空、图标非空、无障碍名、禁用态
 *   [7] 五个控件同挂载后全树无一几何符号 Text
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

    property int failures: 0

    function bit(n, ok) { if (!ok) root.failures |= (1 << n) }

    /* 被禁的几何符号（被当图标用的那批）。刻意不含 "/" ">" "…" ——
     * 它们不在黑名单里这件事本身由 [3] 守着。 */
    readonly property var banned: ["\u25BE", "\u25B8", "\u25B4", "\u25C2",
                                   "\u25B6", "\u251C", "\u2191", "\u2193",
                                   "\u2039", "\u203A", "\u2713", "\u2717",
                                   "\u00D7"]

    /* ══════════════════ 两个扫描器 ══════════════════ */

    /** 收集「text 恰好是某个几何符号」的对象。
     *  用 children 而不是 findChildren：Repeater 与 Loader 建出来的东西
     *  都在 children 里，findChildren 会漏。 */
    function collectGlyphs(item, out) {
        var kids = item.children
        if (!kids) return out
        for (var i = 0; i < kids.length; ++i) {
            var c = kids[i]
            if (c.text !== undefined && typeof c.text === "string"
                    && root.banned.indexOf(c.text) >= 0)
                out.push(c.text)
            root.collectGlyphs(c, out)
        }
        return out
    }

    /** 整条祖先链都 visible 吗 —— 见文件头"为什么叶子节点的箭头不算数" */
    function chainVisible(item) {
        var p = item
        while (p) {
            if (p.visible === false) return false
            p = p.parent
        }
        return true
    }

    /** 收集 chevron 插槽的实例 = 带 angle 属性的对象，连它的 x 一起带走。
     *  angle 是 BasicChevronIndicator 独有的只读属性，别处没人用这个名字。
     *  x 用来去重（两个宿主的实例 x 相同，见文件头）。 */
    function collectChevrons(item, out) {
        var kids = item.children
        if (!kids) return out
        for (var i = 0; i < kids.length; ++i) {
            var c = kids[i]
            if (c.angle !== undefined && typeof c.angle === "number"
                    && root.chainVisible(c))
                out.push({ key: root.keyOf(c), angle: c.angle })
            root.collectChevrons(c, out)
        }
        return out
    }

    /** 一个箭头实例的**视觉落点**。不能用 .x —— 同层兄弟的 x 天然相同
     *  （缩进一致），拿它去重会把 a 和 b 合成一个。必须映射到共同坐标系，
     * 这样"两个宿主的同一个位置"重合、而"同一层的不同行"分开。 */
    function keyOf(item) {
        var pt = item.mapToItem(null, 0, 0)
        return Math.round(pt.x) + "," + Math.round(pt.y)
    }

    /** 收集"没要求抗锯齿渲染器"的 Shape。
     *
     * Qt 6 的 RHI 后端下 Shape 默认用 GeometryRenderer（枚举 1）：把路径
     * 三角化后丢给 GPU，**不做抗锯齿**，斜线（勾、箭头、排序三角）的边缘
     * 会是纯色阶梯。有原生抗锯齿的是 CurveRenderer（枚举 4）。
     *
     * ── 为什么看 preferredRendererType 而不是 rendererType ──────────────
     * rendererType 是**实际**选择，本来更有说服力，但它要等渲染后端初始化
     * 才有值。冒烟测试的根是个没有 Window 的裸 Item，什么都不渲染 —— 实测
     * 此时所有 Shape 的 rendererType 恒为 0（UnknownRenderer），拿它写的
     * 断言永远不会红，是一条假断言（本轮真踩过：变异掉一个 Shape 的渲染器，
     * 测试照样全绿）。
     *
     * preferredRendererType 是**请求**值，属性一赋值就有，在非渲染环境下
     * 依然可靠。真机上"请求是否被后端接受"由截图核验负责 —— 见 README。
     *
     * 枚举直接写字面量：为一个枚举值多引一个模块不划算，且 0/1/4 都实测过。 */
    function collectHardShapes(item, out) {
        var kids = item.children
        if (!kids) return out
        for (var i = 0; i < kids.length; ++i) {
            var c = kids[i]
            if (c.preferredRendererType !== undefined
                    && c.preferredRendererType !== 4) {
                var pt = c.mapToItem(null, 0, 0)
                out.push("Shape(pref=" + c.preferredRendererType + ")@"
                         + Math.round(pt.x) + "," + Math.round(pt.y))
            }
            root.collectHardShapes(c, out)
        }
        return out
    }

    /** 限定在 scope 子树里的箭头（原始实例列表，含两个宿主的重复） */
    function chevronsOf(scope) { return root.collectChevrons(scope, []) }
    function glyphs() { return root.collectGlyphs(root, []) }

    /** 去重后的**位置数** = 视觉上真正出现的箭头个数 */
    function seats(list) {
        var seen = []
        for (var i = 0; i < list.length; ++i)
            if (seen.indexOf(list[i].key) < 0) seen.push(list[i].key)
        return seen.length
    }

    /** 位置去重之后的角度列表 */
    function anglesOf(list) {
        var seen = [], out = []
        for (var i = 0; i < list.length; ++i)
            if (seen.indexOf(list[i].key) < 0) {
                seen.push(list[i].key)
                out.push(list[i].angle)
            }
        return out
    }

    /** 读插槽实例的属性。**参数故意不写类型** —— qmllint 把 Loader.item
     *  的静态类型当成 QObject，直接写 probe.item.angle 会报
     *  Member "angle" not found。经一层 var 中转就不再追。 */
    function slotProp(loader, name) {
        var it = loader.item
        return (it === null || it === undefined) ? undefined : it[name]
    }

    /** 角度列表里有没有 target（给 0.5 的浮点余量） */
    function hasAngle(list, target) {
        for (var i = 0; i < list.length; ++i)
            if (Math.abs(list[i] - target) <= 0.5) return true
        return false
    }

    /** 递归找带某个 iconDirection 的按钮（分页上下页） */
    function findButton(node, dir) {
        var cs = node.children
        if (!cs) return null
        for (var i = 0; i < cs.length; ++i) {
            if (cs[i].iconDirection === dir
                    && cs[i].accessibleName !== undefined)
                return cs[i]
            var hit = root.findButton(cs[i], dir)
            if (hit !== null) return hit
        }
        return null
    }

    /* ══════════════════ 插槽探针 ══════════════════
     * 包在 visible:false 的壳里：[0][1] 直接读 probe.item 的属性，
     * 而 [4]~[7] 按范围扫描时它会因为祖先不可见而被排除。 */

    Item {
        visible: false

        QtObject {
            id: ctl
            property string direction: "right"
            property bool   enabled: true
        }

        Loader {
            id: probe
            sourceComponent: Slots.chevronIndicator
            Binding {
                target: probe.item
                property: "control"
                value: ctl
                when: probe.item !== null
            }
        }
    }

    /* ══════════════════ 被测控件 ══════════════════ */

    QSkinTable {
        id: tree
        width: 420
        treeMode: true
        checkable: true
        treeColumn: 0
        treeIndentWidth: 20
        columns: [{ title: "名称", dataIndex: "name", sortable: true }]
        rows: [
            { id: "a", name: "A 根", children: [
                { id: "a1", name: "A1 枝", children: [
                    { id: "a1x", name: "A1X 叶" },
                    { id: "a1y", name: "A1Y 叶" }
                ] },
                { id: "a2", name: "A2 叶" }
            ] },
            { id: "b", name: "B 根", children: [
                { id: "b1", name: "B1 叶" }
            ] }
        ]
    }

    QSkinButton {
        id: iconBtn
        icon: Slots.chevronIndicator
        iconDirection: "left"
        accessibleName: "上一页"
    }

    QSkinPagination {
        id: pager
        total: 25
        pageSize: 10
        page: 1
    }

    QSkinSelect {
        id: select
        width: 200
    }

    QSkinDatePicker {
        id: picker
        width: 200
    }

    /* 正向对照：故意违反规则的一个 Text。[7] 之前会被清空。 */
    Text {
        id: canary
        text: "\u25BE"
    }

    Component.onCompleted: {
        /* ── [3] 先验扫描器本身 ──────────────────────────────────────
         * 必须最先做：否则后面"一个都没扫到"可能只是扫描器坏了。 */
        var seen = root.glyphs()
        root.bit(3, seen.indexOf("\u25BE") >= 0        /* 金丝雀被抓到 */
                    && root.banned.indexOf("/") < 0    /* 分隔符不在黑名单 */
                    && root.banned.indexOf("\u2026") < 0)

        /* ── [0] 插槽本体 ── */
        /* 取 Loader 的 implicitWidth 而不是 probe.item.implicitWidth ——
         * qmllint 把 Loader.item 静态类型当 QObject，会报
         * Member "implicitWidth" not found。Loader 的 implicit 尺寸本来
         * 就自动跟随被加载项，取它即可（同 QSkinButton.qml 那段注释）。 */
        var ok0 = probe.item !== null
                  && probe.implicitWidth > 0
                  && probe.implicitHeight > 0
        ctl.direction = "right"
        ok0 = ok0 && root.slotProp(probe, "angle") === 0
        ctl.direction = "down"
        ok0 = ok0 && root.slotProp(probe, "angle") === 90
        ctl.direction = "left"
        ok0 = ok0 && root.slotProp(probe, "angle") === 180
        ctl.direction = "up"
        ok0 = ok0 && root.slotProp(probe, "angle") === 270
        root.bit(0, ok0)

        /* ── [1] 语义归属：插槽只认 direction ── */
        ctl.direction = "right"
        var a1 = root.slotProp(probe, "angle")
        ctl.direction = "down"
        var a2 = root.slotProp(probe, "angle")
        /* 把 direction 从 right 改成 down 就该得到 90°，
         * 不需要任何别的输入 —— 插槽不认识 expanded。 */
        root.bit(1, a1 === 0 && a2 === 90 && root.slotProp(probe, "animate") === true)

        /* ── [2] 四套主题覆盖，五份实现互不相同 ── */
        var ok2 = TDesign.tdChevronIndicator          !== Slots.basicChevronIndicator
                  && AntDesign.adChevronIndicator     !== Slots.basicChevronIndicator
                  && ArcoDesign.acChevronIndicator    !== Slots.basicChevronIndicator
                  && Shadcn.scChevronIndicator        !== Slots.basicChevronIndicator
                  && TDesign.tdChevronIndicator       !== AntDesign.adChevronIndicator
                  && TDesign.tdChevronIndicator       !== ArcoDesign.acChevronIndicator
                  && TDesign.tdChevronIndicator       !== Shadcn.scChevronIndicator
                  && AntDesign.adChevronIndicator     !== ArcoDesign.acChevronIndicator
                  && AntDesign.adChevronIndicator     !== Shadcn.scChevronIndicator
                  && ArcoDesign.acChevronIndicator    !== Shadcn.scChevronIndicator
        TDesign.apply()
        ok2 = ok2 && Slots.chevronIndicator === TDesign.tdChevronIndicator
        Shadcn.apply()
        ok2 = ok2 && Slots.chevronIndicator === Shadcn.scChevronIndicator
        Shadcn.remove()
        ok2 = ok2 && Slots.chevronIndicator === Slots.basicChevronIndicator
        root.bit(2, ok2)

        /* ── [4] QSkinTable 树形：箭头真的画出来了 ──────────────────────
         * 收起时可见行 = [a, b]，两行都有子 → 两个箭头，都朝右（0°）。
         * 展开 a 后可见行 = [a, a1, a2, b]，a 与 a1 有子 → 三个箭头，
         * 其中 a 翻到 90°（朝下）。a2 / b1 是叶子，不画。 */
        var ok4 = root.seats(root.chevronsOf(tree)) === 2      /* a、b 两个位置 */
                  && !root.hasAngle(root.anglesOf(root.chevronsOf(tree)), 90)

        tree.toggleExpand("a")
        var a4 = root.chevronsOf(tree)
        ok4 = ok4 && root.seats(a4) === 3                      /* 多出 a1 */
                  && root.hasAngle(root.anglesOf(a4), 90)      /* a 展开了 */
                  && root.hasAngle(root.anglesOf(a4), 0)       /* a1 / b 还收着 */

        /* 全展开：有子节点的只有 a、a1、b 三个 → 三个位置，全部朝下 */
        tree.expandAll()
        var all4 = root.chevronsOf(tree)
        ok4 = ok4 && root.seats(all4) === 3
                  && !root.hasAngle(root.anglesOf(all4), 0)

        tree.collapseAll()
        var col4 = root.chevronsOf(tree)
        ok4 = ok4 && root.seats(col4) === 2
                  && !root.hasAngle(root.anglesOf(col4), 90)
        root.bit(4, ok4)

        /* ── [5] QSkinButton 的图标通路 + QSkinSelect 的 caret ── */
        var btnAngles = root.anglesOf(root.chevronsOf(iconBtn))
        var selAngles = root.anglesOf(root.chevronsOf(select))
        var ok5 = iconBtn.icon !== null
                  && iconBtn.accessibleName === "上一页"
                  && root.seats(root.chevronsOf(iconBtn)) === 1
                  && btnAngles[0] === 180        /* iconDirection "left" → 180° */
                  && selAngles.length === 1
                  && selAngles[0] === 90         /* 未展开的下拉箭头朝下 */
        root.bit(5, ok5)

        /* ── [6] 分页上下页 ── */
        var prev = root.findButton(pager, "left")
        var next = root.findButton(pager, "right")
        var ok6 = prev !== null && next !== null
                  && prev.text === "" && next.text === ""
                  && prev.icon !== null && next.icon !== null
                  && prev.accessibleName === "上一页"
                  && next.accessibleName === "下一页"
                  && prev.enabled === false          /* 第 1 页，上一页禁用 */
                  && next.enabled === true           /* 还有第 2、3 页 */
                  && root.seats(root.chevronsOf(prev)) === 1
                  && root.seats(root.chevronsOf(next)) === 1
        pager.page = 3
        ok6 = ok6 && prev.enabled === true && next.enabled === false
        pager.page = 1
        ok6 = ok6 && prev.enabled === false
        root.bit(6, ok6)

        /* ── [7] 全树静态扫描：无几何符号 Text，也无硬边 Shape ──
         * 先把金丝雀清掉（它本来就是用来证明扫描器有效的），
         * 再把树展开到最满，最后扫一遍整个 root。
         * 两条都是"全树找违规"，合在一位退出码里报 —— 位掩码只有 8 位，
         * 且它们失败时该做的事是同一件：看是哪个控件没守规矩。 */
        canary.text = ""
        tree.expandAll()
        tree.sortColumn = 0
        tree.sortDirection = "desc"
        var found = root.glyphs()
        var hard  = root.collectHardShapes(root, [])
        if (hard.length > 0)
            console.log("HARD_EDGE_SHAPES: " + hard.join("  "))
        root.bit(7, found.length === 0 && hard.length === 0)

        Qt.exit(Math.min(255, root.failures))
    }
}
