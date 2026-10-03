/****************************************************************************
 * QSkin · 冒烟测试 — M23：Collapse / Segmented / Timeline / Carousel
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 这一批把**四种"容器"**放进同一个门禁里：折叠面板（收子项）、时间轴
 * （收子项 + 全序）、分段控制器（数据驱动 + 登记）、轮播（数据驱动）。
 * 五件实现、两条插槽（segmentThumb / timelineDot）。
 *
 * 属性侧能守的只有"**问对了没有**"（归一、派生、全序、钳位、默认值），
 * 守不了"画对了没有"。本批中后者**尤其**重要 —— 见下面第一段。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这一批最贵的一条教训：`Row` 这个名字在 Contracts 里会解析错
 * ════════════════════════════════════════════════════════════════════════
 * 轮播的轨道要的是一个**positioner**（"按顺序横排、每页的宽度由每页自己
 * 说了算"），首版写的是裸名 `Row { id: strip }`。而 `QSkinCarousel.qml` 同时
 * `import QtQuick` 与 `import QSkin.Foundation`，foundation/qmldir 里明写着
 * "Row / Column / Grid 这三个名字和 QtQuick 自带的 positioner 同名……
 * 跨模块使用时，同名类型要靠 import 顺序消歧义，太脆弱"。
 *
 * 实测（`.cache/_probe_m23row.qml`，回传通道是退出码）：**裸名 `Row` 解析
 * 成 `QSkin.Foundation.Row`** —— 一个 RowLayout 外壳，不是 positioner。
 * 后果是每一页的 `width: viewport.width` 被 Layout 覆盖（Layout 决定子项
 * 用的是 `implicitWidth`，而页面 Item 没有隐式宽），页面缩成 0 宽、
 * 整条轨道一片空白 —— **而属性侧一切自洽**（`count` 对、`currentIndex` 对、
 * `x` 照样在动）。它只被 [6] / [7] 那两条"页面宽度"判据抓住。
 *
 * 这是 M22 那个陷阱（`height: root.glyphSize` 在 ColumnLayout 里是空操作）
 * 在**同一个仓库里的第二次现形**，所以本文件的 [7] 专门读页面与轨道的几何，
 * 而不是只读下标与偏移公式。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 全序为什么必须由组答，而不能数出来
 * ════════════════════════════════════════════════════════════════════════
 * 折叠面板的"第一块不画上分隔线"与时间轴的"第一颗点之上不画线"都依赖
 * **全序**。而 Qt 对兄弟节点的 `onCompleted` 是**逆声明序**触发的
 * （M20 实测：三个同级 QtObject 各自报号得到 "321"）—— 于是"按注册先后
 * 维护成员列表"这条写法会把顺序整体反转，而**属性侧每个成员自己都对**：
 * 只是"第一块"变成了"最后一块"。
 *
 * 所以三件容器（Collapse / Timeline / Segmented）都走
 * `QSkin.Foundation.MemberOrder.sortByDeclaration`，而 [2] 直接读成员数组的
 * **下标顺序**（`_panels[0] === ciA`）—— 这一条是那次实测的可证伪形式。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 分回合：只有轮播的**几何**需要等
 * ════════════════════════════════════════════════════════════════════════
 * `strip.x` 参与 `Theme.motion.normal` 的动画（`_clamp` / `goTo` 之后立刻读
 * 到的是**中间值** —— M22 记过这条）。而"偏移是宽度的整数倍"这条判据恰恰
 * 只能在收尾之后读。所以 [0]~[6] 在 `run()` 里，[7] 推到 Timer 之后
 * （`Theme.motion.normal + 80`，与 shot/gate 脚本同一套余量）。
 *
 * 这里**没有**用"先把 animate 关掉再读"这条捷径：那会让判据绕开动画，
 * 而"动画没跑完就被读"正是要防的那件事。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么这个文件用 check(closure) 而不是裸写 root.expect(a && b)
 * ════════════════════════════════════════════════════════════════════════
 * 与 smoke_m21 / smoke_m22 同源：分回合意味着 `Qt.exit()` 只在最后一回合
 * 执行，于是断言里任何一处 TypeError 都会让 run() 中断、`Qt.exit` 永不执行，
 * 而 `qml.exe` 是一个开着窗口的 GUI 进程 —— **测试不是失败，是永远挂着**。
 *
 * 两道防线：① 每条断言用 `check(closure)` 包住（闭包抛异常 = 该位失败，
 * 不中断、不错位）；② 20 秒看门狗 `Qt.exit(255)`。
 * ⚠ 代价：`check` 会把 TypeError **吞成一声不响的"这一条失败"** ——
 *   红了先怀疑调用姿势（比如给必填参数的信号忘了传参）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 断言上限 8 条（位掩码退出码的数学约束，见 tools/test.sh 文件头）
 * ════════════════════════════════════════════════════════════════════════
 *   [0] Collapse · expandedKeys 归一 + 排他（留最后 / 被挤者收 collapsed）
 *   [1] Collapse · 展开态只有一个事实来源（组改写 ↔ 面板跟随）
 *   [2] CollapseItem · 独立模式（= Collapsible）+ 全序按**声明序**
 *   [3] Segmented · options 归一（对象 / 字符串 / null / 数字）
 *   [4] Segmented · 选中：禁用跳过、越界不选、两端回绕、恰好 N 次
 *   [5] Timeline · 两段线的可见性按全序 + 容器 gap:0 + 点对齐首行中线
 *   [6] Carousel · 默认值 / count（数字与数组）/ 数据到 delegate / 钳位与回卷
 *   [7] Carousel · 页面宽高 = 视口 + 偏移 = 宽度的整数倍（等动画收尾）
 *
 * ── 刻意**没验**的两件事（别以为是漏了）──────────────────────────────────
 *   · **焦点移动**（`_moveFocus` / `_move` 里的 `forceActiveFocus`）：
 *     离屏 `qml` 运行器下的焦点状态不可靠，验了会得到"大部分时候绿"的
 *     判据。键盘的**落地**行为归 tests/tst_*.qml 的真鼠标/真键盘事件，
 *     以及像素核验里的焦点环。
 *   · **时间轴的点击/键盘**：时间轴条目本来就没有交互（无 MouseArea、
 *     无 Keys），没有可验的行为。
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

    /** 跑一段会写断言的代码；抛异常算这一条失败（见文件头）。 */
    function check(block) {
        var ok = false
        try { ok = block() === true } catch (e) { ok = false }
        root.expect(ok)
    }

    /* ══════════════════ 被测对象 ══════════════════ */

    /* ── [0][1][2] 折叠面板 ──
     * 三块显式给 key（"a"/"b"/"c"）：留空也能用（用声明序下标），
     * 但那是"重排会换号"的那一档，判据里用显式键更稳 —— 下标那一档
     * 由 [2] 的 `_keyOf` 顺带取证。 */
    property int colExpandedCount: 0
    property int colCollapsedCount: 0

    QSkinCollapse {
        id: colAcc

        x: 10
        y: 10
        width: 300

        accordion: true

        onExpanded:  root.colExpandedCount++
        onCollapsed: root.colCollapsedCount++

        QSkinCollapseItem {
            id: ciA
            key: "a"
            title: "基本信息"
            Body { text: "姓名 / 手机号" }
        }

        QSkinCollapseItem {
            id: ciB
            key: "b"
            title: "权限"
            Body { text: "管理员" }
        }

        QSkinCollapseItem {
            id: ciC
            key: "c"
            title: "操作日志"
            Body { text: "最近 30 天" }
        }
    }

    /** 一块**给不出 key** 的成员：用来验"留空则用声明序下标"。
     *  它挂在另一个组上，免得把上面那个组的键序搅乱。 */
    QSkinCollapse {
        id: colAnon

        x: 10
        y: 260
        width: 300

        QSkinCollapseItem { id: ca0; title: "第一块" }
        QSkinCollapseItem { id: ca1; title: "第二块" }
    }

    /** 独立使用 = shadcn 的 `Collapsible`（无组、不画分隔线）。
     *  属性名是 `framed` 而不是 `bordered` —— 后者是组上的名字
     *  （组管外框 + 块间分隔线），成员上只管自己那一条上分隔线。 */
    QSkinCollapseItem {
        id: ciSolo

        x: 10
        y: 460
        width: 300
        title: "高级选项"
        framed: false

        Body { text: "超时 30s" }
    }

    /* ── [3][4] 分段控制器 ──
     * 选项文字**故意长短不一**（2 / 4 / 3 / 7 个字）：活动块若是按
     * "总宽 / 段数"等分的，在等宽选项上完全看不出来 —— 见 [4]。 */
    property int segChanges: 0

    QSkinSegmented {
        id: seg

        x: 340
        y: 10
        width: 520

        options: [
            { value: "overview", label: "概览" },
            { value: "detail",   label: "详细报表" },
            { value: "blocked",  label: "受限项", disabled: true },
            { value: "all",      label: "全部指标与图表" }
        ]
        value: "overview"

        onSelectionChanged: root.segChanges++
    }

    /** 字符串选项 + 一个 null + 一个数字：全在归一那一层收匀。 */
    QSkinSegmented {
        id: segRaw

        x: 340
        y: 60
        width: 320

        options: [ "日", "周", "月", null, 7 ]
    }

    /* ── [5] 时间轴 ──
     * 三条：第一条带标签（首行是标签）、中间也是、最后一条**不给标签**
     * 而只给内容 —— 那一档正是"取 children[0] 会算出 0 高"的现场。 */
    QSkinTimeline {
        id: tl

        x: 340
        y: 200
        width: 300

        QSkinTimelineItem {
            id: ti1
            type: "success"
            label: "09:12"
            Body { text: "构建通过" }
        }

        QSkinTimelineItem {
            id: ti2
            type: "danger"
            label: "09:40"
            Body { text: "部署失败" }
        }

        QSkinTimelineItem {
            id: ti3
            label: ""
            Body { text: "等待复审" }
        }
    }

    /* ── [6][7] 轮播 ──
     * 数组 model → 每页拿到的是**数据**（不是下标）。 */
    QSkinCarousel {
        id: car

        x: 340
        y: 520
        width: 480
        height: 180

        model: [ "第一页", "第二页", "第三页" ]
        delegate: pageTpl
    }

    /** 数字 model（只要页数）+ 四个默认值 + 钳位/回卷的场地。 */
    QSkinCarousel {
        id: car2

        x: 860
        y: 520
        width: 320
        height: 160

        model: 4
    }

    /** 轮播的一页。`objectName` 只给测试认领用，不参与渲染。
     *
     *  ⚠ 两个字必须声明成**普通属性**，不能写 `required property` ——
     *  required 属性只能由 Repeater 直接注入给它的 delegate，而每一页外面
     *  还有一层 Loader（"每页 = 视口大小"所必需）。实测
     *  （`.cache/_probe_m23carq.qml`）：`modelData` 穿得过 Loader、`index`
     *  穿不过；写成 required 的后果是**整页构造失败**。
     *  注入走 `onLoaded`，与 QSkinList 的 cellLoader 同一个解法。
     *
     *  `served` 记下**宿主注进来的是什么**（而不是读 `car.model`）——
     *  后者只能证明"控件存了数据"，证明不了"送出去了"。 */
    Component {
        id: pageTpl

        Rectangle {
            id: pageRoot

            objectName: "m23Page"

            property int index: -1
            property var modelData: undefined

            property var served: modelData

            color: "#DDDDDD"

            /* 用户那一页的画法：这里只放一句话，够认领。 */
            Body {
                anchors.centerIn: parent
                text: String(pageRoot.served)
            }
        }
    }

    /* ══════════════════ 工具 ══════════════════ */

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

    /** 深度上限 16：给上限是为了万一遇到环时不会死循环。 */
    function collect(item, pred, out, d) {
        if (item === null || item === undefined || d > 16) return
        if (pred(item)) out.push(item)
        var ch = item.children
        if (ch === undefined) return
        for (var i = 0; i < ch.length; ++i) root.collect(ch[i], pred, out, d + 1)
    }

    /** 按文字认领一个 Text（Body / Caption 都是 Text，属性名是 `text`）。
     *  先验类型再取值 —— 子项里混着 QtObject 与 ShapePath，谓词里一句
     *  `o.text` 在那些节点上是 undefined，不报错但会把 `===` 判成假。 */
    function textNodeOf(item, s) {
        return root.findIn(item, function (o) {
            if (typeof o.text !== "string" || o.text !== s) return false
            if (o.font === undefined || o.font === null) return false
            return o.font.pixelSize !== undefined
        })
    }

    /** 时间轴条目里那两段线：都是 `width === 2` 的 Rectangle。
     *  上段线 `y === 0`，下段线的 y 跟着点走。 */
    function lineAboveOf(item) {
        return root.findIn(item, function (o) {
            return o.width === 2 && o.y === 0 && o.color !== undefined
                && typeof o.visible === "boolean"
        })
    }

    /** 下段线 = 那条 y > 0 的。 */
    function lineBelowOf(item) {
        return root.findIn(item, function (o) {
            return o.width === 2 && o.y > 0 && o.color !== undefined
                && typeof o.visible === "boolean"
        })
    }

    /** 轮播的视口（唯一一个 `clip: true` 的节点） */
    function viewportOf(carousel) {
        return root.findIn(carousel, function (o) { return o.clip === true })
    }

    /** 轮播的轨道 = 视口的第一个孩子（见 QSkinCarousel 的文件头：
     *  它必须写成 `QtQuick.Row`，否则会被 Layout 覆盖尺寸）。 */
    function stripOf(carousel) {
        var vp = root.viewportOf(carousel)
        if (vp === null) return null
        var ch = vp.children
        if (ch === undefined || ch.length === 0) return null
        return ch[0]
    }

    /* ══════════════════ 断言 ══════════════════ */

    function run() {
        /* ── [0] expandedKeys 的归一与排他 ──
         *
         * 三件事分开读，因为错法不同：
         *   · **归一**：单值 / null / 数字进来都要收成 `string[]`。
         *     参照实现里"排他时是单值、多开时是数组"，读取方每次都要判类型
         *     —— 本件对外永远一个形状，这一条就是那件事的可证伪形式。
         *   · **排他**：塞两个键进去，只留**最后**那个。留第一个也会让
         *     "最多一个"成立，所以必须读**留下的是哪一个**（`[0] === "c"`）。
         *   · **被挤掉的那块要收到 collapsed**：只读 expandedKeys 看不出
         *     宿主有没有被告知 —— 而宿主的状态与实际不符是这类控件最典型的
         *     事故（它只在下一次渲染时现形）。
         *
         * 末尾还读一次"把 accordion 反过来改"：`expandedKeys` 有两个键、
         * 此时把 `accordion` 置真，也必须收敛。第一版漏了这一条路
         * （只在 `onExpandedKeysChanged` 里收敛），本条在修之前是红的。 */
        root.check(function() {
            /* 归一：单值字符串 */
            colAcc.expandedKeys = "b"
            var single = colAcc._keys().length === 1
                         && colAcc.isExpanded("b")
                         && ciB.expanded === true
                         && ciA.expanded === false

            /* 归一：null → 空集 */
            colAcc.expandedKeys = null
            var nothing = colAcc.isExpanded("a") === false
                          && colAcc.isExpanded("b") === false
                          && ciB.expanded === false

            /* 归一：数字 → 它的字符串形式 */
            colAcc.expandedKeys = 7
            var numOk = colAcc.isExpanded(7) === true
                        && colAcc.isExpanded("7") === true
                        && ciA.expanded === false && ciC.expanded === false

            /* 排他：留最后那个，且被挤掉的收到 collapsed */
            colCollapsedCount = 0
            colAcc.expandedKeys = ["a", "c"]
            var excl = colAcc.expandedKeys.length === 1
                       && colAcc.expandedKeys[0] === "c"
                       && ciC.expanded === true
                       && ciA.expanded === false
                       && root.colCollapsedCount === 1

            /* 排他：**反过来改 accordion** 也要收敛 */
            colAcc.accordion = false
            colAcc.expandedKeys = ["a", "c"]
            var multi = colAcc.expandedKeys.length === 2
                        && ciA.expanded === true && ciC.expanded === true
            colAcc.accordion = true
            var reEnforced = colAcc.expandedKeys.length === 1
                             && colAcc.expandedKeys[0] === "c"
                             && ciA.expanded === false && ciC.expanded === true

            colAcc.expandedKeys = []
            return single && nothing && numOk && excl && multi && reEnforced
        })

        /* ── [1] 展开态只有**一个**事实来源 ──
         *
         * 本件最要紧的一条结构约定（见 QSkinCollapseItem 文件头）：
         *
         *     expanded = 组在场 ? 组说了算 : 自己的 open
         *
         * 反过来写（面板自己存一份、再往组里同步一份）的缺陷是：组被外部
         * 改写时面板那份还亮着。所以这里**只改组、读面板**：若面板自己
         * 存了状态，`ciA.expanded` 就不会跟着走。
         *
         * 三个入口（expand / collapse / toggle）都过一遍：它们各自可能
         * 绕过收敛路（比如 toggle 直接改面板自己的布尔），只验一个会放过
         * 另外两个。计数器的口径也一并读 —— `expanded` / `collapsed`
         * 应当**恰好**各发一次，多一次说明写入口重复发了信号。 */
        root.check(function() {
            colAcc.accordion = true
            colAcc.expandedKeys = []

            colExpandedCount = 0
            colCollapsedCount = 0

            colAcc.expand("a")
            var eOk = ciA.expanded === true && ciB.expanded === false
                      && colExpandedCount === 1 && colCollapsedCount === 0

            colAcc.expand("a")            /* 已经是展开态：不该再发信号 */
            var idemOk = colExpandedCount === 1 && ciA.expanded === true

            colAcc.collapse("a")
            var cOk = ciA.expanded === false
                      && colExpandedCount === 1 && colCollapsedCount === 1

            colAcc.collapse("a")          /* 已经是收起态：不该再发信号 */
            var cIdemOk = colCollapsedCount === 1

            colAcc.toggle("b")
            var tOk = ciB.expanded === true && ciA.expanded === false
                      && colExpandedCount === 2

            colAcc.toggle("b")
            var tBackOk = ciB.expanded === false && colCollapsedCount === 2

            /* 组被外部整体改写 → 面板必须跟着（这一条是"单一事实来源"的
             * 正面证据：面板没有自己的一份）。 */
            colAcc.expandedKeys = ["c"]
            var externalOk = ciC.expanded === true
                             && ciA.expanded === false && ciB.expanded === false

            /* 一个被禁用的成员：读不出展开态，也不该被 toggle 打开 */
            ciB.disabled = true
            colAcc.toggle("b")
            var disabledOk = ciB.expanded === false
            ciB.disabled = false

            colAcc.expandedKeys = []
            return eOk && idemOk && cOk && cIdemOk && tOk && tBackOk
                   && externalOk && disabledOk
        })

        /* ── [2] 独立模式，以及全序按**声明序** ──
         *
         * 全序那条是这一批的第二条硬判据。读的是成员数组的**下标顺序**：
         * 兄弟节点的 onCompleted 是逆声明序触发的（M20 实测 "321"），
         * 所以"按注册先后 push"会得到 ["c","b","a"] —— 这一条立刻红。
         *
         * `_keyOf` 的"留空用声明序下标"也在这里取证：colAnon 的两块都没有
         * key，它们的键必须是 "0" / "1"（**按声明序**，不是按注册序）。
         * —— 这一条同时是"成员自己沿 parent 链找到了组"的正面证据：
         * 键算不出来（`_panels` 是空的）时 `_keyOf` 会回落到下标路径，
         * 而那条路径依赖的正是同一个 `_panels`，于是它也会错。
         *
         * 独立模式（shadcn 的 Collapsible）：没有组时 `isFirst` 为真
         * （"只有一条"），且 `open` 自己说了算。 */
        root.check(function() {
            var lenOk = colAcc._panels.length === 3
            var orderOk = colAcc._panels[0] === ciA
                          && colAcc._panels[1] === ciB
                          && colAcc._panels[2] === ciC

            var firstOk = ciA.isFirst === true
                          && ciB.isFirst === false
                          && ciC.isFirst === false

            var anonOk = colAnon._keyOf(ca0) === "0"
                         && colAnon._keyOf(ca1) === "1"

            var soloOk = ciSolo.collapse === null
                         && ciSolo.isFirst === true
                         && ciSolo.expanded === false
            ciSolo.open = true
            soloOk = soloOk && ciSolo.expanded === true
                             && ciSolo.isFirst === true
            ciSolo.open = false

            return lenOk && orderOk && firstOk && anonOk && soloOk
        })

        /* ── [3] Segmented 的归一 ──
         *
         * 四种形状的元素都要收成 `{value, label, disabled}`：
         *   · 对象 → 取它自己的字段（`value` 缺省时回落到 `label`）
         *   · 字符串 → 值 = 文字
         *   · **null / undefined → 丢掉**（不是变成一项空选项 ——
         *     那会让 `count` 与屏幕上的段数不一致，而两者都"看着合理"）
         *   · 数字 → 值仍是数字，文字是它的字符串形式
         *
         * `count` 与 `_options().length` 必须一致：前者是派生属性，后者是
         * 纯函数，两条算路各写一遍时最容易漂移。 */
        root.check(function() {
            var o = seg._options()
            var shapeOk = o.length === 4
                          && o[0].value === "overview" && o[0].label === "概览"
                          && o[0].disabled === false
                          && o[1].value === "detail" && o[1].label === "详细报表"
                          && o[2].value === "blocked" && o[2].disabled === true
                          && o[3].label === "全部指标与图表"

            var cntOk = seg.count === 4 && seg._options().length === 4

            var raw = segRaw._options()
            var rawOk = raw.length === 4                  /* null 被丢掉 */
                        && raw[0].value === "日" && raw[0].label === "日"
                        && raw[2].value === "月"
                        && raw[3].value === 7 && raw[3].label === "7"
                        && segRaw.count === 4

            /* 未选中 / 值不在选项里 → currentIndex 是 -1（不是 0）
             * —— 0 会让"活动块停在第一段"看起来像选中了它。 */
            var noneOk = segRaw.currentIndex === -1
            segRaw.value = "周"
            noneOk = noneOk && segRaw.currentIndex === 1
            segRaw.value = "不存在的值"
            noneOk = noneOk && segRaw.currentIndex === -1
            segRaw.value = undefined

            /* 选项**整体换掉**之后，归一结果必须跟着变
             * （旧值缓存起来就会在这里露头）。 */
            var keep = segRaw.options
            segRaw.options = [ "甲", "乙" ]
            var swapOk = segRaw.count === 2
            segRaw.options = keep

            return shapeOk && cntOk && rawOk && noneOk && swapOk
        })

        /* ── [4] Segmented 的选中：禁用跳过、越界不选、两端回绕 ──
         *
         * `selectionChanged` 用**计数器**读，而不是读末值 ——
         * "恰好发了 N 次"这件事只有计数能表达（M22 的出口判据同款）。
         *
         * 回绕与跳禁用都**只**在"读下标序列"时才看得出来：单独读末值
         * 分不清"跳过了禁用项"与"恰好走到那儿"。所以这里把每一次移动的
         * 结果都读一遍，而不是只在末尾读一次。
         *
         * 最后是活动块：`_thumbX()` / `_thumbW()` 必须等于**当前段项的实际
         * 盒子**。断言里同时读"三段宽度不全相等"—— 没有后者，一个按
         * "总宽 / 段数"等分的实现在等宽选项上照样能过。 */
        root.check(function() {
            seg.value = "overview"
            segChanges = 0

            seg._move(1)
            var m1 = seg.value === "detail"
            seg._move(1)                    /* 跳过 disabled 的 index 2 */
            var m2 = seg.value === "all"
            seg._move(1)                    /* 从末尾回绕 */
            var m3 = seg.value === "overview"
            seg._move(-1)                   /* 反向回绕 */
            var m4 = seg.value === "all"
            seg._move(-1)                   /* 反向跳过 disabled */
            var m5 = seg.value === "detail"

            var countOk = root.segChanges === 5
                          && seg.currentIndex === 1

            seg._selectIndex(2)             /* 禁用项：不该选上 */
            var disOk = seg.value === "detail" && root.segChanges === 5
            seg._selectIndex(99)            /* 越界：不该选上 */
            seg._selectIndex(-1)
            var rangeOk = seg.value === "detail" && root.segChanges === 5

            seg.enabled = false
            seg._selectIndex(0)             /* 整件禁用：不该选上 */
            var offOk = seg.value === "detail" && root.segChanges === 5
            seg.enabled = true

            /* 活动块量的是实际盒子（当前下标 = 1） */
            var s = seg._segs
            var geoOk = s.length === 4
                        && seg._thumbX() === s[1].x
                        && seg._thumbW() === s[1].width
                        && seg._thumbW() > 0
                        && Math.abs(s[0].width - s[3].width) > 1

            return m1 && m2 && m3 && m4 && m5 && countOk
                   && disOk && rangeOk && offOk && geoOk
        })

        /* ── [5] Timeline：两段连线 + 点对齐内容首行 ──
         *
         * ── 线的两个端点 ─────────────────────────────────────────────────
         * 时间轴读起来是一条**穿过**所有点的线，而不是"N 段各自带线的行"。
         * 差别只落在两个端点上，而那是唯一"只在渲染上成立"的形状问题
         * （像素侧要量的正是"第一行点上方无墨 / 最后一行点下方无墨"）。
         *
         * 三条各读各的：
         *   · 首条：上段线不可见（且它下面的那条可见 —— 只读"不可见"会
         *     放过"两条都不画"的实现）
         *   · 中间：两条都可见（这条才证明 `!first` 那个条件真的在起作用；
         *     没有它，"全部不可见"的实现能过前一条）
         *   · 末条：下段线不可见、上段线可见
         *
         * ── 容器 gap: 0 ──────────────────────────────────────────────────
         * 线是**条目自己画的**。容器若在两个条目之间留间距，那一段没有任何
         * 人画线 —— 线就断了。所以 `tl.implicitHeight` 必须**恰好**等于三条
         * 之和；大一点点就说明中间有真空。
         *
         * ── 点为什么不能取 `children[0]` ─────────────────────────────────
         * 点的中心跟着**内容列里第一条真正可见的行**走。`label` 是内容列的
         * 第一个孩子，但它常常是空的（不可见、高 0）—— 直接取 `children[0]`
         * 会算出 0，点跑到行顶上去。ti3 就是这个现场：它没有标签。
         * 两条一起读：ti1 的点对齐**标签**中线，ti3 的点对齐**正文**中线，
         * 且 ti3 的点中心必须 > 0。 */
        root.check(function() {
            var up1 = root.lineAboveOf(ti1)
            var dn1 = root.lineBelowOf(ti1)
            var up2 = root.lineAboveOf(ti2)
            var dn2 = root.lineBelowOf(ti2)
            var up3 = root.lineAboveOf(ti3)
            var dn3 = root.lineBelowOf(ti3)

            var found = up1 !== null && dn1 !== null && up2 !== null
                        && dn2 !== null && up3 !== null && dn3 !== null

            var endOk = up1.visible === false && dn1.visible === true
                        && up3.visible === true && dn3.visible === false
                        && up2.visible === true && dn2.visible === true

            var gapOk = Math.abs(tl.implicitHeight
                                 - (ti1.implicitHeight + ti2.implicitHeight
                                    + ti3.implicitHeight)) <= 0.51

            var lastGapOk = dn1.height > 0 && dn2.height > 0

            /* 点对齐首行中线 */
            var cap1 = root.textNodeOf(ti1, "09:12")
            var body1 = root.textNodeOf(ti1, "构建通过")
            var body3 = root.textNodeOf(ti3, "等待复审")
            var cap3 = root.textNodeOf(ti3, "")

            var alignOk = cap1 !== null && body1 !== null && body3 !== null
                          && cap1.visible === true
                          && Math.abs(ti1.dotCenterY - (cap1.y + cap1.height / 2)) <= 0.51

            /* ti3 没有标签：第一个可见的行是正文。若取了 children[0]
             * （那个不可见的 Caption），这里会算出约 0。 */
            var skipOk = body3 !== null
                         && ti3.dotCenterY > 0.5
                         && Math.abs(ti3.dotCenterY - (body3.y + body3.height / 2)) <= 0.51
                         && (cap3 === null || cap3.visible === false)

            return found && endOk && gapOk && lastGapOk && alignOk && skipOk
        })

        /* ── [6] Carousel：默认值 / count / 数据到 delegate / 钳位与回卷 ──
         *
         * `autoplay` 的默认值**本身就是门禁的一部分**（见 QSkinCarousel 文件头）：
         * 一个会自己动的控件是不可抓的 —— 抓到的图取决于快门那一刻它转到
         * 哪儿。所以这一条读的是"默认关"，而不是"能关"。
         *
         * `count` 两种 model 形状都要读：数字（只要页数）与数组（数据）。
         * 数字形状还要读**非整数**（4.7 → 4）与**空**（0 → 0）：不取整的话
         * `Repeater` 会收到一个小数模型。空模型则要走通"count 为 0 时
         * `goTo`/`next` 直接返回"那条路（它保证下标被夹回 0）。
         *
         * ⚠ **负数刻意没验**：`count` 那行有 `Math.max(0, …)` 兜着，但要把
         *   它变成可证的，得把一个负的模型交给 `Repeater` —— 那是 Qt 侧的
         *   边界行为（非数字非数组的模型会被当成"单项"），拿它造判据会引入
         *   一个与本案无关的依赖。如实记为"防御性的一行"。
         *
         * 数据到 delegate：读**页面自己报上来的** `served`，而不是读
         * `car.model` —— 后者只能证明"我存了数据"，证明不了"送出去了"。
         *
         * 钳位：页数从 4 变 2 时下标必须跟着落在界内。不钳的话整条轨道会
         * 被平移到"没有页"的地方（一片空白，而属性上看不出错）。
         * 回卷：`loop: false` 时到端点**停住**，置回 true 才回卷。 */
        root.check(function() {
            var defOk = car.autoplay === false
                        && car.interval === 3000
                        && car.showDots === true
                        && car.showArrows === false
                        && car.loop === true
                        && car.currentIndex === 0

            var cntOk = car.count === 3 && car2.count === 4

            var oddOk = false
            var keep = car2.model
            car2.model = 4.7
            oddOk = car2.count === 4
            car2.model = 0
            oddOk = oddOk && car2.count === 0 && car2.currentIndex === 0
            car2.model = keep

            var pages = root.findAll(car, function (o) {
                return o.objectName === "m23Page"
            })
            var dataOk = pages.length === 3
                         && pages[0].served === "第一页"
                         && pages[1].served === "第二页"
                         && pages[2].served === "第三页"
                         && pages[0].index === 0 && pages[2].index === 2

            /* 钳位 */
            car2.currentIndex = 3
            car2.model = 2
            var clampOk = car2.currentIndex === 1 && car2.count === 2

            /* 回卷 / 停住 */
            car2.loop = false
            car2.currentIndex = 1
            car2.next()
            var stopOk = car2.currentIndex === 1
            car2.prev()
            stopOk = stopOk && car2.currentIndex === 0
            car2.prev()
            stopOk = stopOk && car2.currentIndex === 0

            car2.loop = true
            car2.prev()
            var wrapOk = car2.currentIndex === 1
            car2.next()
            wrapOk = wrapOk && car2.currentIndex === 0

            /* 没有 delegate 的实例：换页不该炸（页面里那个 Loader 的
             * sourceComponent 是 null，留白而不是报错）。 */
            car2.goTo(1)
            var bareOk = car2.currentIndex === 1
            car2.model = 4
            car2.currentIndex = 0

            /* 给 [7] 造状态：把下标钉到最后一页（动画就此开始跑）。 */
            car.goTo(2)

            return defOk && cntOk && oddOk && dataOk && clampOk
                   && stopOk && wrapOk && bareOk
        })

        root.phase = 0
        step.start()
    }

    /* ══════════════════ [7] 几何（等动画收尾）══════════════════ */

    property int phase: 0

    function roundGeom() {
        root.check(function() {
            var vp = root.viewportOf(car)
            var st = root.stripOf(car)
            if (vp === null || st === null) return false

            var w = vp.width
            var h = vp.height
            var n = car.count

            /* 偏移是**宽度的整数倍** —— 一页宽乘以下标就是偏移。
             * 这条在结构上成立（`x` 是轨道唯一的动画量），而它成立的前提是
             * 每一页真的有那么宽 —— 正是接下来那一项。 */
            var offsetOk = w > 0 && n === 3 && car.currentIndex === 2
                           && Math.abs(st.x - (-car.currentIndex * w)) <= 0.51

            /* 每一页的宽高 = 视口的宽高。
             * ⚠ 这一条抓的是"轨道用了裸名 `Row`"那个缺陷：Layout 会用
             * implicitWidth（页面 Item 的隐式宽是 0）覆盖显式宽度，
             * 于是页面缩成 0 宽、屏幕上一片空白，而 [6] 全绿。 */
            var pages = root.findAll(car, function (o) {
                return o.objectName === "m23Page"
            })
            var pageOk = pages.length === n
            for (var i = 0; i < pages.length; ++i) {
                if (Math.abs(pages[i].width - w) > 0.51) pageOk = false
                if (Math.abs(pages[i].height - h) > 0.51) pageOk = false
            }

            /* 轨道总宽 = 页数 × 页宽（它也得溢出视口，否则 clip 无从谈起） */
            var stripOk = Math.abs(st.width - n * w) <= 0.51

            /* 指示点是**两档宽**的（当前那颗更宽）：同宽度的一排点会让
             * "我在第几页"只能靠透明度表达 —— 而透明度在浅色底上很弱。
             * 挑"最宽的恰好一个"来读，而不是读具体的 16 / 6（那是主题的数）。 */
            var dots = []
            root.collect(car, function (o) {
                if (typeof o.opacity === "number" && o.radius !== undefined
                        && o.height === 4 && o.width > 0) dots.push(o)
            }, dots, 0)
            var dotOk = dots.length === n
            if (dots.length === n) {
                var widest = 0
                var ties = 0
                for (var j = 0; j < dots.length; ++j)
                    if (dots[j].width > widest) widest = dots[j].width
                for (var k = 0; k < dots.length; ++k)
                    if (dots[k].width === widest) ties++
                dotOk = ties === 1 && dots[car.currentIndex].width === widest
            }

            return offsetOk && pageOk && stripOk && dotOk
        })
        Qt.exit(root.mask)
    }

    /* 退场/平移动画：`strip.x` 走 Theme.motion.normal。
     * 比它多 80ms 是为了让"动画结束"这条链走完；写成符号而不是常量是因为
     * 各主题的 motion 可以不同。 */
    Timer {
        id: step

        interval: Theme.motion.normal + 80
        running: false
        repeat: false
        onTriggered: root.roundGeom()
    }

    /* 看门狗：正常路径下走不到这里（测试几秒内就结束）。
     * 255 → 8 个位全亮，配合 test.sh 打出的 stderr 就是"这个文件炸了"。 */
    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }

    /* 推迟一轮：Qt Quick Layouts 把尺寸重算放在 polish 阶段，
     * 在 onCompleted 里同步读会读到重算之前的值（见 smoke_sizes.qml）。
     * [4] 的活动块、[5] 的点中心读的都是布局算出来的值。 */
    Component.onCompleted: function() { Qt.callLater(root.run) }
}
