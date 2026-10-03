/****************************************************************************
 * QSkin · 冒烟测试 — M21：浮层家族
 *              （Popover / Popconfirm / HoverCard / Dropdown /
 *                ContextMenu / Notification）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 这一批守的是**浮层的账目**：谁登记、谁被顶掉、内容落到哪里、面板摆在
 * 何处。渲染侧不在这个文件里 —— 它守不了（"属性值对 ≠ 界面画对"）。
 *
 * ── 这一批独有的风险：**跨组件的一条规矩** ─────────────────────────────
 * M18~M20 的缺陷都关在单个控件的边界里（派生量算错、推送漏了一条路径、
 * 截断打掉了绑定）。这一批第一次出现"六个件共用同一条规矩"的情形：
 *
 *     同一时刻只能有一个**排他**浮层
 *
 * 它归 `QSkin.Foundation.OverlayStack` 单例（理由见那边的文件头）。于是
 * 风险变成"某个件忘了登记"或"不该登记的那个也登了"—— 两种都是
 * **只跑单个控件的测试永远看不见**的。所以 [1] / [2] 两条刻意跨两个
 * 实例取证，并且各带一个**反面**：
 *
 *   [1] 反面：关掉栈顶之后，栈必须回到空 —— 若 drop() 没写对，
 *       第二次打开就会被"看起来还开着的幽灵"顶掉，而单看一次开合正常。
 *   [2] 反面：HoverCard（exclusive:false）打开后，排他浮层必须**还开着**，
 *       且 HoverCard 自己**不能**出现在栈里。只验前者会放过"它也登记了、
 *       只是碰巧没关成"的实现。
 *
 * ── 还有一类风险：**用的是同一个机制，却退化成两套行为** ─────────────────
 * Dropdown / ContextMenu 把菜单交给了 QSkinMenu（行语义、键盘导航都在那边）。
 * "委托了"这件事不能靠读代码相信 —— [5] 显式走一遍**跳过分隔线**，
 * 用 QSkinMenu 独有的行语义证明调用是真的走到了那边，而不是这里另写了一套。
 *
 * ── 这个文件为什么不像别的冒烟测试那样裸写 root.expect(c1 && c2 && …) ──
 * 因为 M21 是第一个**分回合**断言的冒烟文件（通知卡的排位要等一次 polish，
 * 见 runNotifyA）。分回合意味着 `Qt.exit()` 在最后一个回合才执行 ——
 * 于是断言里任何一处 TypeError 都会让 run() 中断、`Qt.exit` 永不执行，
 * 而 `qml.exe` 是一个开着窗口的 GUI 进程：**测试不是失败，是永远挂着**。
 *
 * 第一次跑这个文件就撞上了：`pc.okButton` 当时还没加（TypeError，
 * 第 318 行），于是 smoke_m21 挂了 2 分 13 秒直到被外部杀掉，
 * 日志里只有一行 "exception occurred during delayed function evaluation"。
 *
 * 两道防线：
 *   ① 每条断言用 `check(closure)` 包起来 —— 闭包里抛异常 = **该位失败**，
 *      不中断、不错位（位掩码编号仍与 [n] 注释一一对应）。
 *   ② 20 秒看门狗兜底，`Qt.exit(255)`。255 会让 8 个位全亮，
 *      而 test.sh 会把 stderr 一起打出来（那里必然有真正的原因）——
 *      这是 test.sh 文件头已经定下的"炸了"信号，不是"8 条真失败"。
 *
 * ── 断言上限 8 条（位掩码退出码的数学约束）──────────────────────────────
 * 详见 tools/test.sh 文件头。合并规则按**组件**：
 *   [0] Popover 注入/开合/登记/定位   [1] OverlayStack 排他
 *   [2] HoverCard 非排他             [3] Popconfirm 两条出口
 *   [4] Dropdown                    [5] ContextMenu 委托
 *   [6] Notification 入列与排位       [7] Notification 上限与清空
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Window 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int mask: 0
    property int idx: 0

    /* 显式给根一个尺寸：qml 运行器会把窗口按根对象调大小，
     * 而下面 [0] 要验"面板落在 target 正下方、中线对齐"——
     * 那需要知道窗口有多宽（窄窗口会触发边界夹取，中线就不再重合）。
     * 900×700 让 target 摆在远离四边的地方，夹取不介入。 */
    width: 900
    height: 700

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

    /* ── [0] Popover：锚定到一个按钮，塞两个探针方块 ──
     * 方块用 objectName 认领，比"数 children 有几个"稳 ——
     * 内容宿主内部还有一个 Layout，数个数会把实现细节写进断言。
     *
     * ── 为什么锚点的 x/y 要写成**绑定**而不是字面量 ─────────────────────
     * 字面量在实例化时就落值，于是"面板到底有没有算对位置"这件事永远
     * 恰好成立 —— 断言会退化成同义反复。M21 实拍就撞上了这个：定位
     * 断言全绿，而屏幕上面板落在窗口左上角。
     *
     * 真实用法里锚点的位置几乎总是**绑定**（居中、跟布局、跟状态）。
     * 绑定是惰性的：QSkinPopover 在实例化自己的内部属性时，目标自己的
     * x/y 可能还没有被任何人读过。所以这里刻意用 `x: root.anchorX`，
     * 把那条路径复现出来 —— 这正是 QSkinPopover 的 targetOrigin 当初
     * 只算一次、停在 (0,0) 的原因（见该文件里 _anchorDeps 的说明）。 */
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
        title: "面板标题"
        panelWidth: 240

        Rectangle { objectName: "m21Probe"; implicitWidth: 120; implicitHeight: 20; color: "#FF0000" }
        Rectangle { objectName: "m21Probe"; implicitWidth: 160; implicitHeight: 24; color: "#00FF00" }
    }

    /* 内容为空的对照件：用来证明"内容真的进了宿主"，而不是宿主本来就非空 */
    QSkinPopover { id: popEmpty; target: anchor }

    /* ── [1] OverlayStack：两个排他浮层 ── */

    QSkinPopover { id: popA; target: anchor; panelWidth: 160
                 Rectangle { implicitWidth: 40; implicitHeight: 16; color: "#000000" } }
    QSkinPopover { id: popB; target: anchor; panelWidth: 160
                 Rectangle { implicitWidth: 40; implicitHeight: 16; color: "#000000" } }

    /* ── [2] HoverCard：声明成非排他 ── */

    QSkinHoverCard {
        id: card

        target: anchor
        /* 不写 0：Timer 的 interval 为 0 且 repeat 默认 true 时会变成
         * "每轮事件循环都触发"的忙等，把 CPU 烧掉还会让 callLater 排不上队。
         * 测试里不等计时器 —— 直接调用 open() / close()。 */
        showDelay: 10
        hideDelay: 10

        Rectangle { implicitWidth: 80; implicitHeight: 20; color: "#0000FF" }
    }

    /* ── [3] Popconfirm ── */

    property int confirmCount: 0
    property int cancelCount: 0

    QSkinPopconfirm {
        id: pc

        target: anchor
        text: "确定要删除这一项吗？"
        description: "删除后不可恢复。"

        onConfirmed: root.confirmCount++
        onCanceled:  root.cancelCount++
    }

    /* ── [4] Dropdown ── */

    property int ddTriggered: -1

    QSkinDropdown {
        id: dd

        x: 60
        y: 420
        text: "动作"
        model: ["编辑", "复制", "separator", { text: "删除", danger: true }]

        onTriggered: function(index) { root.ddTriggered = index }
    }

    /* ── [5] ContextMenu：声明在一个容器里（撑满它） ── */

    property int cmTriggered: -1

    Rectangle {
        id: cmArea

        x: 400
        y: 420
        width: 320
        height: 180
        color: "transparent"

        QSkinContextMenu {
            id: cm

            model: ["复制", "粘贴", "separator", { text: "删除", danger: true }]

            onTriggered: function(index) { root.cmTriggered = index }
        }
    }

    /* ── [6][7] Notification ── */

    property var firstNotice: null

    QSkinNotification {
        id: notify

        defaultDuration: 0          /* 测试里不让它自己溜走 */
    }

    /* ══════════════════ 工具 ══════════════════ */

    /* 内容宿主 QSkinColumn 自己会 `default property alias data: layout.data`
     * 把子节点再转一手（进它内部的 ColumnLayout）。所以这里**递归**找，
     * 只看一层会数到 0 —— 而那正是"内容没注入"的假象。 */
    function countNamed(item, nm) {
        if (item === null || item === undefined) return 0
        var ch = item.children
        if (ch === undefined) return 0
        var n = 0
        for (var i = 0; i < ch.length; ++i) {
            if (ch[i].objectName === nm) n++
            n += root.countNamed(ch[i], nm)
        }
        return n
    }

    /* ══════════════════ 断言 ══════════════════ */

    function run() {
        /* ── [0] Popover：内容注入、面板宽度、开合、登记、定位 ──
         *
         * "内容进了宿主"用**对照**取证：同样是 QSkinPopover，一个塞两枚
         * 探针、一个什么都不塞。因为宿主（QSkinColumn）内部本来就有一个
         * Layout 子项，绝对数字会把实现细节钉进断言；差值不会。
         *
         * 定位写成两条**互相独立**的性质：
         *   · 面板整体在 target 下方，且间距不超过 gap + 阴影外扩量
         *   · 横向中线与 target 的中线重合（±1.5px）
         * 后者是对称性陈述，不重算实现的公式 —— 实现把 gap 漏了、
         * 或者把 targetWidth 当成 targetOrigin.x 用，都会在这里露出来。
         *
         * 面板宽 240 是显式给的，`panelFullWidth` 必须如实反映它 ——
         * 这是"定宽"分支；hug 分支（panelWidth <= 0）由像素核验守。 */
        root.check(function() {
            var injected = root.countNamed(pop.contentHost, "m21Probe")
            var inEmpty  = root.countNamed(popEmpty.contentHost, "m21Probe")

            var closedOk = pop.opened === false && popEmpty.opened === false

            pop.open()
            var openedOk = pop.opened === true
                     && OverlayStack.contains(pop) === true
                     && OverlayStack.exclusiveCount === 1
                     && pop.panelFullWidth === 240

            var tScene = anchor.mapToItem(null, 0, 0)
            var pScene = pop.panel !== null && pop.panel !== undefined
                         ? pop.panel.mapToItem(null, 0, 0)
                         : null
            var below = false
            var centered = false

            if (pScene !== null) {
                var dy = pScene.y - (tScene.y + anchor.height)
                below = dy >= 0 && dy <= pop.gap + pop.panelExtender + 0.5

                var win = root.Window.window
                var wantX = tScene.x + anchor.width / 2 - pop.panelFullWidth / 2
                var m = Theme.space.sm
                var clamped = win !== null
                              && (wantX < m || wantX > win.width - pop.panelFullWidth - m)
                if (clamped) {
                    centered = true          /* 夹取介入时不验中线 */
                } else {
                    var pcx = pScene.x + pop.panelFullWidth / 2
                    var tcx = tScene.x + anchor.width / 2
                    centered = Math.abs(pcx - tcx) <= 1.5
                }
            }

            pop.close()
            var closedClean = pop.opened === false
                              && OverlayStack.contains(pop) === false
                              && OverlayStack.exclusiveCount === 0

            return injected === 2 && inEmpty === 0
                   && injected - inEmpty === 2
                   && closedOk && openedOk
                   && pop.panelPadding > 0
                   && pop.panelExtender >= 0
                   && below && centered
                   && closedClean
        })

        /* ── [1] OverlayStack：新开的顶掉旧开的 ──
         *
         * 反面是"关掉栈顶之后栈回到空"。少了它，一个 drop() 永远不生效的
         * 实现也能过（exclusiveCount 只要满足 <= 1 就看着对）。
         * 这里显式读三次中间值：只读末态分不清"顶掉了"和"根本没开成"。 */
        root.check(function() {
            popA.open()
            var s0 = popA.opened === true && popB.opened === false
                     && OverlayStack.exclusiveCount === 1
                     && OverlayStack.top() === popA

            popB.open()
            var s1 = popB.opened === true && popA.opened === false
                     && OverlayStack.exclusiveCount === 1
                     && OverlayStack.top() === popB
                     && OverlayStack.contains(popA) === false

            popB.close()
            var s2 = OverlayStack.exclusiveCount === 0 && OverlayStack.top() === null

            return s0 && s1 && s2
        })

        /* ── [2] HoverCard：非排他浮层 ──
         *
         * 语义是"悬停提示不该顶掉用户刚点开的东西"。所以两件事要同时成立：
         *   ① 排他浮层还开着（没被顶掉）
         *   ② HoverCard 自己不在栈里（它**不参与**这套规矩）
         * 只验 ① 是不够的：一个"登记了但 request() 里漏掉了关闭"的实现
         * 同样能让 ① 成立。
         *
         * 顺带验 exclusive 的默认值归位：QSkinPopover 默认 true、
         * QSkinHoverCard 覆盖成 false —— 两边都读一次。 */
        root.check(function() {
            popA.open()
            var h0 = popA.opened === true && popA.exclusive === true

            card.open()
            var h1 = card.opened === true
                     && card.exclusive === false
                     && popA.opened === true                        /* 没被顶掉 */
                     && OverlayStack.contains(card) === false        /* 也没入栈 */
                     && OverlayStack.contains(popA) === true
                     && OverlayStack.exclusiveCount === 1

            card.close()
            var h2 = card.opened === false && popA.opened === true

            popA.close()
            return h0 && h1 && h2 && OverlayStack.exclusiveCount === 0
        })

        /* ── [3] Popconfirm：两条出口都要关面板**并且**发信号 ──
         *
         * 两件事分开验：面板没关（用户得再点一次）与信号没发（业务没反应）
         * 是两个不同的缺陷，都会让"删除"这个动作要么卡住要么静默失效。
         * 顺便验 danger 时确认按钮换变体 —— 删除类操作不该是蓝色的。 */
        root.check(function() {
            pc.open()
            var c0 = pc.opened === true
                     && pc.okButton !== null && pc.cancelButton !== null
                     && pc.okButton.text === "确定" && pc.cancelButton.text === "取消"
                     && pc.okButton.variant === "primary"
                     && pc.accessibleName === pc.text

            pc.okButton._activate()
            var c1 = pc.opened === false && root.confirmCount === 1

            pc.open()
            pc.cancelButton._activate()
            var c2 = pc.opened === false && root.cancelCount === 1
                     && root.confirmCount === 1                  /* 取消不该触发确认 */

            pc.danger = true
            pc.open()
            var c3 = pc.okButton.variant === "danger"
            pc.close()

            return c0 && c1 && c2 && c3
        })

        /* ── [4] Dropdown：触发器状态机 + 转发 ──
         *
         * 箭头方向是**派生量**：收起朝下、展开朝上。它与 opened 同源，
         * 但写错方向时属性侧照样是"一个合法字符串"，所以只能靠关系式守。
         *
         * 转发要验 `triggered`，而触发路径必须走 QSkinMenu 自己的
         * `_trigger()`（它负责"关面板 + 发信号"的顺序）—— 直接 emit
         * `dd.triggered` 只是把自己发的信号又听了一遍，什么也没证明。 */
        root.check(function() {
            var d0 = dd.opened === false && dd.iconDirection === "down"
                     && dd.enabled === true
                     && dd.model.length === 4

            dd.toggle()
            var d1 = dd.opened === true && dd.iconDirection === "up"
                     && dd.menu.opened === true
                     && dd.menu.panelWidth === dd.panelWidth
                     && dd.menu.itemHeight === dd.menuItemHeight

            dd.toggle()
            var d2 = dd.opened === false && dd.iconDirection === "down"

            dd.open()
            dd.menu._trigger(1)
            var d3 = dd.opened === false && root.ddTriggered === 1
                     && dd.iconDirection === "down"

            /* 禁用的触发器点不开（QSkinButton.enabled 是鸭子里的一环） */
            dd.enabled = false
            dd.toggle()
            var d4 = dd.opened === false
            dd.enabled = true

            return d0 && d1 && d2 && d3 && d4
        })

        /* ── [5] ContextMenu：只吃右键 + 真的委托给了 QSkinMenu ──
         *
         * `acceptedButtons === Qt.RightButton` 与 `hoverEnabled === false`
         * 合起来才是"对左键与悬停透明"这个承诺的完整形式 —— 少任何一条，
         * 盖上去的那层都会吃掉下面控件的点击或 hover。
         *
         * "委托"用 QSkinMenu 独有的行语义取证：**高亮移动跳过分隔线**。
         * 若这里另写了一套自己的遍历，索引 2（分隔线）就会被停上去。
         * 这是那种"两份实现都能过一半测试"的典型 —— 必须挑一个只有
         * 真正委托才成立的性质。 */
        root.check(function() {
            var k0 = cm.catcher.acceptedButtons === Qt.RightButton
                     && cm.catcher.hoverEnabled === false
                     && cm.menu.model === cm.model

            cm.openAt(30, 40)
            var k1 = cm.opened === true
                     && cm.menu.highlightIndex === 0            /* 首个可用项 */
                     && cm.menu._isSeparator(2) === true
                     && cm.menu._isSeparator(0) === false
                     && cm.menu._contentHeight()
                        === 3 * cm.itemHeight + (1 + Theme.space.xs * 2)

            cm.menu.highlightIndex = 1
            cm.menu._move(1)
            var k2 = cm.menu.highlightIndex === 3               /* 跳过索引 2 的分隔线 */
            cm.menu.highlightIndex = 3
            cm.menu._move(1)
            var k3 = cm.menu.highlightIndex === 0               /* 回绕 */

            cm.menu._trigger(3)
            var k4 = cm.opened === false && root.cmTriggered === 3

            return k0 && k1 && k2 && k3 && k4
        })

        /* ── [6][7] Notification 需要等布局落定（见 runNotifyA）── */

        root.firstNotice = notify.show({ title: "同步失败",
                                         description: "网络不可达，稍后重试",
                                         type: "danger" })
        notify.show("已同步")

        Qt.callLater(root.runNotifyA)
    }

    /* 通知卡的高度来自 QSkinColumn 的隐式高度，而那要等一次 polish。
     * 在这个回合里读 `_items[i].y` 拿到的是"还没排过位"的 0 ——
     * 所以推迟一轮再断（与 smoke_sizes.qml 同一条理由）。 */
    function runNotifyA() {
        /* ── [6] 入列、定宽、自上而下排位 ──
         *
         * 新的在最上面（`_items[0].y === 0`），旧的排在它下面 ——
         * 这条顺序是"用户刚看到的在上面"，反过来会让眼睛追着卡片跑。
         *
         * 排位式子用**另一条路径**算：`旧.y === 新.height + 间距`。
         * 若 _reflow() 把间距漏了（或者用了错的行高），这里立刻红。
         * 宽度是显式给的定值 —— 卡片宽度跟随内容会在标题长短不一时抖。 */
        root.check(function() {
            var items = notify._items
            var n0 = notify.count === 2
                     && items[0] !== null && items[1] !== null
                     && items[0].width === notify.noticeWidth
                     && items[1].width === notify.noticeWidth
                     && items[0].height > 0
                     && items[1].height > 0
                     && items[0].y === 0
                     && items[1].y === items[0].height + Theme.space.sm
                     /* firstNotice 是"同步失败"那张，先发 → 排在下面 */
                     && items[1] === root.firstNotice

            /* 预留区高度必须**恰好等于**实际占用的高度（末张卡的下沿）。
             * 多一分是视觉上空一块，少一分是下一张卡压上来。这是两条独立
             * 算路上的一致性：《_reflow》摆位、《_stackHeight》预留。 */
            var lastBottom = items[1].y + items[1].height
            var n1 = notify.noticeWidth === 320
                     && Math.abs(notify._stackHeight() - lastBottom) <= 0.5

            return n0 && n1
        })

        /* ── [7] 超限挤掉最旧的 ──
         * 再塞三张（共 5 张），上限 4 —— 最旧的（firstNotice）必须出列。
         * 只验 `count === maxVisible` 会让"塞满后原地不动、新卡根本没进来"
         * 的实现蒙混过关，所以同时验：最旧的出列、最新的在列。 */
        notify.show("三")
        var third = notify.show("四")
        notify.show("五")

        root.check(function() {
            var m0 = notify.count === notify.maxVisible
                     && notify._items.indexOf(root.firstNotice) < 0
                     && third !== null
                     && notify._items.indexOf(third) === 1

            notify.dismissAll()
            var m1 = notify.count === 0 && notify._items.length === 0

            return m0 && m1
        })

        Qt.exit(root.mask)
    }

    /* 看门狗：正常路径下走不到这里（测试 1 秒内就结束了）。
     * 255 → 8 个位全亮，配合 test.sh 打出的 stderr 就是"这个文件炸了"。 */
    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }

    /* 推迟一轮：Qt Quick Layouts 把尺寸重算放在 polish 阶段，
     * 在 onCompleted 里同步读会读到重算之前的值（见 smoke_sizes.qml）。 */
    Component.onCompleted: function() { Qt.callLater(root.run) }
}
