/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinCalendar
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 常驻月历（M24）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 它与 QSkinDatePicker **不是**同一样东西
 * ════════════════════════════════════════════════════════════════════════
 * 两者都画 42 格月历，共用 `DateUtil.monthGrid`，但契约完全不同：
 *
 *     QSkinDatePicker   一个**输入控件**。它有一个 `value`、一个显示文本、
 *                     一个会开合的浮层。月历是它的**面板**（popup.overlay）。
 *     QSkinCalendar     一块**常驻内容**。它在页面上占位、没有 popup、
 *                     没有显示文本、没有开合。它自己就是月历。
 *
 * 所以本件不是"把 DatePicker 的面板抽出来"：抽出面板会让 DatePicker
 * 多一层间接，而 Calendar 还得自己长一个头部。**共用的是算法**
 * （DateUtil）与**渲染约定**（Slots.label 喂文字、42 格 Repeater），
 * 这两样本来就不在控件里。
 *
 * ════════════════════════════════════════════════════════════════════════
 * `today` 是一个可以外部注入的属性 —— 为了确定性与跨夜刷新
 * ════════════════════════════════════════════════════════════════════════
 * 默认值 `DateUtil.today()` 在**声明期取一次**。
 *
 * 这不是"忘了刷新"，是本项目的一条硬要求：**抓图必须几何确定**。
 * 一个会自己变的控件没法做像素门禁（今天画出来是 14 号、明天是 15 号，
 * 核验器的基准就失效了）。参照实现里 `dayjs()` 每帧取真实时间，
 * 代价是它们的日历截图永远无法自动比对。
 *
 * 需要跨夜刷新的宿主把 `today` 绑到一个 Timer 上 —— 一行的事，
 * 而且这一行会出现在代码评审里（好事，与 QSkinAvatar 不做自动配色的
 * 理由同源）。
 *
 * ── 注意 modelData.isToday **不用** ─────────────────────────────────────
 * `DateUtil.monthGrid` 返回的每格带一个 `isToday`，但那是它内部用**真实
 * 时钟**算的。本件一律用 `DateUtil.sameDay(..., root.today)` 重算 ——
 * 否则注入的 `today` 只管渲染的一半，另一半跟着系统时间走。同一个词
 * 在一份实现里有两个来源，是那种"只在跨年那天的截图里看出来"的错。
 *
 * ════════════════════════════════════════════════════════════════════════
 * panel / fullscreen 两个形态**共用一套几何算路**
 * ════════════════════════════════════════════════════════════════════════
 * 差别只有三处，全部走同一个 `colWidth` / `rowHeight` / `markX,markY`：
 *
 *                     panel（默认）              fullscreen
 *     格子            36 × 36 定尺                宽 = 可用宽 / 7，高 = 88
 *     高亮块          居中（边长 = 格子 - 4）      左上角（固定 28）
 *     日期数字        居中在高亮块里               居中在高亮块里（同一段代码）
 *     附加内容        无（36px 没有第二轮的位置）  高亮块下方，走 dateCell
 *
 * **没有**"两个形态写成两个容器"——那是 QSkinDescriptionsItem 首版翻的车
 * （垂直模式下内容被塞进隐藏容器，属性侧看不出来）。这里只有一个
 * `gridArea`，只是几何按模式算。
 *
 * ════════════════════════════════════════════════════════════════════════
 * `dateCell` 为什么用 `control` 注入，而不是 `required property modelData`
 * ════════════════════════════════════════════════════════════════════════
 * QSkinList / QSkinSelect 的 delegate 收 `modelData`，因为它们把 delegate
 * 交给了 Repeater / ListView —— 那两个会**自动注入**。
 *
 * 本件的 dateCell 挂在 `Loader` 上（一个格子里有没有附加内容要按模式决定，
 * Repeater 做不到"这一格不实例化"）。Loader 不注入任何东西，所以契约
 * 换成本项目插槽那条既有的：被实例化出来的根对象声明
 *
 *     property var control        // 本件注入的鸭子类型对象
 *
 * `control` 暴露：`date`（{year,month,day}）、`inMonth`、`selected`、
 * `isToday`、`disabled`、`text`（补零后的 "YYYY-MM-DD"）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 头部"今天"按钮是**导航**，不是选择
 * ════════════════════════════════════════════════════════════════════════
 * 点它把面板拨回本月，**不改 `value`**。
 *
 * 理由：选择是一条改数据的动作。在一个常驻月历上，用户很可能只是在
 * 浏览、还没决定 —— 一个角标悄悄改掉 value 会让他丢掉原来的选择，
 * 而"拨回去看一眼"是无损的。QSkinDatePicker 的"今天"两点都做（那边
 * 用户本来就在**选**一个日期，拨回今天并选中是同一个意图）。
 * 同一句话在两个控件里含义不同，是因为它们回答的问题不同。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 刻意不做（写进 COVERAGE.md 的待办，不是悄悄少做）
 * ════════════════════════════════════════════════════════════════════════
 *   · range 选择（TDesign `mode: range`）、year / month 两种视图模式
 *   · 周序号列（ISO week）
 *   · 农历 / 节假日角标 —— 那是**数据**，不是控件。参照实现里 Ant 的
 *     `dateCellRender` 就正是留给它的口子，本件的 `dateCell` 同一条路。
 ****************************************************************************/

import QtQuick 2.11
/* 底部两个 Loader 要写 Layout.alignment（它们在一个 RowLayout 里）——
 * 与 QSkinDatePicker / QSkinPopover 同一处需要，见 QSkinDatePicker 里
 * "这里为什么是 Layout.alignment 而不是 anchors" 那段。 */
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    /** 当前选中的日期 {year, month, day}，或 null。 */
    property var value: null

    /** "今天"。—— 声明期取一次，可注入。见文件头。 */
    property var today: DateUtil.today()

    /** 可选的下界 / 上界（含端点）。 */
    property var minimumDate: null
    property var maximumDate: null

    /** 可选的禁用判据：`function(date) { return bool }`。
     *  返回 true 的格子会灰掉且不可点。与 min/max 叠加生效。 */
    property var disabledDate: null

    /* ══════════════════════ 面板浏览状态 ══════════════════════
     * 与 value 解耦 —— 用户可以翻到别的月份看一圈再回来，不改选中的值。
     * 与 QSkinDatePicker 同一套语义。 */

    property int panelYear:  root.today.year
    property int panelMonth: root.today.month

    /* ══════════════════════ 外观 ══════════════════════ */

    /** false = 卡片式面板（定尺 36 的格子）；true = 铺满宽度的大格月历。 */
    property bool fullscreen: false

    /** panel 模式的格子边长（正方形）。 */
    property int cellSize: 36

    /** fullscreen 模式的格子高度。宽度永远是"可用宽 / 7"。 */
    property int fullRowHeight: 88

    /** fullscreen 下高亮块的固定边长（日期数字居中在它里面）。 */
    property int markerSize: 28

    property int padding: Theme.space.sm
    property bool bordered: true
    property bool showHeader: true
    property bool showTodayButton: true

    /** 「今天」按钮上的字。 */
    property string todayText: qsTr("今天")

    /** 面板标题上的**月份**文字。
     *
     *  ⚠ 它取 `DateUtil.monthLabels`，**不是** `qsTr("%1月")` 模板 —— 后者在
     *  英文里没有对应构造：中文给月份加后缀「月」，英文的月份是独立的词
     *  （`Sep`）。同一个标题行里的**星期头**早就走 `DateUtil.weekdayLabels`
     *  了，月标题漏在外面是 M33-7 填英文时撞出来的不一致。
     *  `panelMonth` 恒在 1..12（三个赋值点分别来自 `today()` / `value` /
     *  `addMonths()`），这里仍然夹一次 —— 将来多一个赋值点时不会无声出界。
     *  中文下的渲染与改动前**逐字节相同**（两边都是 "9月"）。 */
    readonly property string monthText:
        DateUtil.monthLabels[Math.max(0, Math.min(11, root.panelMonth - 1))]

    /** 格子附加内容模板（**只**在 fullscreen 下实例化）。
     *  根对象请声明 `property var control`，见文件头。 */
    property Component dateCell: null

    /* ══════════════════════ 事件 ══════════════════════ */

    /** 用户选中了某一天（`select()` 也会发）。程序化改 `value` 不发。 */
    signal selected(var date)

    /** 面板换月（翻页、点"今天"、或 value 被外部改动带走）。 */
    signal panelChange(var panel)

    /* ══════════════════════ 派生几何 ══════════════════════ */

    readonly property int  headerHeight:  root.fullscreen ? 56 : 40
    readonly property int  weekdayHeight: root.fullscreen ? 32 : 28
    readonly property real rowHeight:     root.fullscreen ? root.fullRowHeight
                                                          : root.cellSize
    readonly property int  headerBand:    root.showHeader ? root.headerHeight : 0

    /** 一格宽。fullscreen 下跟着可用宽度走，panel 下是定尺。 */
    readonly property real colWidth:
        root.fullscreen ? Math.max(1, gridArea.width / 7) : root.cellSize

    /* fullscreen 下不定 implicitWidth（宽度由宿主给，铺满）。
     * 这里**不能**写成 gridArea.width + … —— 那会让 implicitWidth
     * 依赖 root.width，宿主写 width: implicitWidth 就是一个环。 */
    implicitWidth: root.fullscreen
        ? 0
        : Math.round(root.cellSize * 7 + root.padding * 2 + (root.bordered ? 2 : 0))

    implicitHeight: Math.round(root.headerBand + root.weekdayHeight
                               + root.rowHeight * 6
                               + root.padding * 2 + (root.bordered ? 2 : 0))

    /** 42 格。换月即重算（纯绑定，没有"忘了重新赋值 model"这条路径）。 */
    readonly property var cells: DateUtil.monthGrid(root.panelYear, root.panelMonth)

    Accessible.role: Accessible.Table

    /* ══════════════════════ 日期可用性 ══════════════════════ */

    function _inRange(d) {
        if (root.minimumDate && DateUtil.compare(d, root.minimumDate) < 0) return false
        if (root.maximumDate && DateUtil.compare(d, root.maximumDate) > 0) return false
        return true
    }

    function _disabledByFn(d) {
        if (root.disabledDate === null || root.disabledDate === undefined) return false
        if (typeof root.disabledDate !== "function") return false
        return root.disabledDate(d) === true
    }

    /** 某天能不能点。 */
    function isEnabled(d) {
        return DateUtil.isValid(d) && root._inRange(d) && !root._disabledByFn(d)
    }

    function _isSelected(d) {
        return root.value !== null && root.value !== undefined
            && DateUtil.compare(d, root.value) === 0
    }

    /* ══════════════════════ 操作 ══════════════════════ */

    /** 拨到某年某月（不改 value）。 */
    function goToMonth(year, month) {
        root.panelYear  = year
        root.panelMonth = month
        root.panelChange({ year: year, month: month })
    }

    function _goMonth(delta) {
        var r = DateUtil.addMonths(root.panelYear, root.panelMonth, delta)
        root.goToMonth(r.year, r.month)
    }

    /** 把面板拨回今天所在月。**不改 value**，见文件头。 */
    function goToToday() {
        var t = root.today
        root.goToMonth(t.year, t.month)
    }

    /** 选中一天。不在范围内 / 被禁用 / 非法 → 返回 false 且什么都不改。 */
    function select(d) {
        if (!root.isEnabled(d)) return false
        root.value = DateUtil.clamp(d, root.minimumDate, root.maximumDate)
        root.selected(root.value)
        return true
    }

    /* ══════════════════════ value 变化时的两件事 ══════════════════════
     *
     * ── 为什么要**先比较再写回** ────────────────────────────────────────
     * 钳制会再写一次 value，从而重入 onValueChanged。两个越界值来回钳制
     * 会打成死循环，所以必须先比、确实需要改才写回。
     * 注意：写入**相等**的值同样会触发信号，所以判据必须是 compare，
     * 不能只判 null。（这段与 QSkinDatePicker 同一处坑，两处保持一致。） */

    onValueChanged: {
        if (root.value !== null && root.value !== undefined) {
            if (!DateUtil.isValid(root.value)) {
                root.value = null
                return
            }
            var c = DateUtil.clamp(root.value, root.minimumDate, root.maximumDate)
            if (DateUtil.compare(c, root.value) !== 0) {
                root.value = c          /* 重入一次，这次已经相等，不会再写 */
                return
            }
            root.goToMonth(root.value.year, root.value.month)
        }
    }

    /* ══════════════════════ 底板 ══════════════════════ */

    Rectangle {
        id: frame

        anchors.fill: parent
        radius: Theme.radius.md
        color:        root.bordered ? Theme.color.bgElevated : "transparent"
        border.width: root.bordered ? 1 : 0
        border.color: Theme.color.border
    }

    /* ══════════════════════ 头部 ══════════════════════ */

    Item {
        id: headerBar

        visible: root.showHeader
        height:  root.showHeader ? root.headerHeight : 0

        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top
        anchors.leftMargin:  root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin:   root.padding

        /* ── 上一月 ── */
        Item {
            id: prevBtn

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: root.headerHeight - Theme.space.sm * 2
            height: width

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius.sm
                color: prevMa.containsMouse ? Theme.color.bgSunken : "transparent"
            }

            /* 箭头走 chevronIndicator 插槽 —— 与 QSkinDatePicker / QSkinPagination
             * 同一格，不再各画一条折线（见 Slots.qml 文件头那段）。 */
            Loader {
                id: prevChevron

                anchors.centerIn: parent
                sourceComponent: Slots.chevronIndicator

                Binding {
                    target: prevChevron.item
                    property: "control"
                    value: prevChevronProxy
                    when: prevChevron.item !== null
                }
            }

            MouseArea {
                id: prevMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._goMonth(-1)
            }
        }

        QtObject {
            id: prevChevronProxy
            readonly property string direction: "left"
            readonly property bool enabled: root.enabled
        }

        QtObject {
            id: nextChevronProxy
            readonly property string direction: "right"
            readonly property bool enabled: root.enabled
        }

        /* ── 下一月 ── */
        Item {
            id: nextBtn

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root.headerHeight - Theme.space.sm * 2
            height: width

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius.sm
                color: nextMa.containsMouse ? Theme.color.bgSunken : "transparent"
            }

            Loader {
                id: nextChevron

                anchors.centerIn: parent
                sourceComponent: Slots.chevronIndicator

                Binding {
                    target: nextChevron.item
                    property: "control"
                    value: nextChevronProxy
                    when: nextChevron.item !== null
                }
            }

            MouseArea {
                id: nextMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._goMonth(1)
            }
        }

        /* ── "今天"：在下一月箭头的左边 ──
         * 放在标题**外面**（标题是居中锚定的），这样窄面板下两者不会叠。 */
        QSkinButton {
            id: todayBtn

            visible: root.showTodayButton
            text: root.todayText
            variant: "text"
            size: "sm"

            anchors.right: nextBtn.left
            anchors.rightMargin: Theme.space.xs
            anchors.verticalCenter: parent.verticalCenter

            onClicked: root.goToToday()
        }

        /* ── 标题：2026年 9月。年份 muted 让月份更突出 ── */
        QSkinRow {
            anchors.centerIn: parent
            gap: 2

            Loader {
                id: yearLabel

                Layout.alignment: Qt.AlignVCenter
                sourceComponent: Slots.label

                Binding {
                    target: yearLabel.item
                    property: "control"
                    value: yearProxy
                    when: yearLabel.item !== null
                }
            }

            Loader {
                id: monthLabel

                Layout.alignment: Qt.AlignVCenter
                sourceComponent: Slots.label

                Binding {
                    target: monthLabel.item
                    property: "control"
                    value: monthProxy
                    when: monthLabel.item !== null
                }
            }
        }
    }

    QtObject {
        id: yearProxy
        readonly property string text: qsTr("%1年").arg(root.panelYear)
        readonly property string variant: "muted"
        readonly property int labelAlignment: Text.AlignHCenter
    }

    QtObject {
        id: monthProxy
        readonly property string text: root.monthText
        readonly property int labelAlignment: Text.AlignHCenter
    }

    /* ══════════════════════ 星期头 ══════════════════════ */

    /* ── 下面两个 delegate 里的**绑定**会引用外层 id（root / DateUtil），
     * 于是 qmllint 报 Unqualified access。这不是笔误，是 `delegate:`
     * 会开出一个新的组件作用域，而静态检查不去链上外层。
     *
     * 实测（`.cache/probe_unq/`，四份最小复现）：
     *   · 把外层引用删干净 → 不报；
     *   · 只要还剩一处就报，**跟 `required property` 无关**
     *     （以为"是 required 导致的"会走错方向）；
     *   · 换成具名 inline Component 当 delegate，一样报；
     *   · 报错自带的 Info 行写着：Set "pragma ComponentBehavior: Bound"。
     *
     * 三条路，本项目都用过。这里选第三条，理由是可量的：
     *
     *   ① `pragma ComponentBehavior: Bound` —— 报错消失，但它给**整个
     *      文件**换一套作用域规则（嵌套组件对外层 id 变成静态绑定）。
     *      QSkinDivider 记过这条取舍：为一个控件引入它不划算。
     *   ② 把渲染参数全部算进 modelData，delegate 退化成纯渲染器
     *      （QSkinDivider 就是这么做的，代价是牺牲 delegate 内部状态）。
     *      这里**不能**照做：格子几何跟着可用宽度走，宽度一变 model
     *      就是一份新数组 → Repeater 视为模型重置，42 个 delegate 整批
     *      重建。拖窗口会每一帧重建 42 个节点，还会顺手清掉悬停态。
     *      现在的写法在 resize 时只是重算绑定，节点一个不换。
     *   ③ 局部关掉这条警告 —— QSkinSelect / QSkinList / QSkinMenu /
     *      QSkinNotification / QSkinInputOTP / QSkinBreadcrumb 与本件的最近亲
     *      QSkinDatePicker 都是这么做的。运行时引用完全正确：默认的
     *      Unbound 行为就是沿上下文链查找。
     */
    // qmllint disable unqualified

    Item {
        id: weekdayBar

        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   headerBar.visible ? headerBar.bottom : parent.top
        anchors.leftMargin:  root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: headerBar.visible ? 0 : root.padding

        height: root.weekdayHeight

        Repeater {
            model: DateUtil.weekdayLabels

            delegate: Item {
                id: wdCell

                property int index
                property var modelData

                x: wdCell.index * root.colWidth
                width: root.colWidth
                height: root.weekdayHeight

                Text {
                    anchors.centerIn: parent
                    text: wdCell.modelData
                    font.family:    Theme.font.family
                    font.pixelSize: Theme.font.xs
                    font.weight:    Theme.font.weightMedium
                    color:          Theme.color.fgMuted
                    renderType:     Text.NativeRendering
                }
            }
        }
    }

    /* ══════════════════════ 日期网格 ══════════════════════
     *
     * 42 格、Repeater + index 直接算行列，不用 GridLayout / GridView：
     * 格子数固定，位置就是 `(index % 7, floor(index / 7))`，
     * 比让 Layout 参与测量的链路短得多（QSkinDatePicker 同款）。 */

    Item {
        id: gridArea

        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   weekdayBar.bottom
        anchors.leftMargin:  root.padding
        anchors.rightMargin: root.padding
        anchors.bottomMargin: root.padding

        height: root.rowHeight * 6

        Repeater {
            model: root.cells

            delegate: Item {
                id: cell

                property int index
                property var modelData

                width:  root.colWidth
                height: root.rowHeight
                x: (cell.index % 7) * root.colWidth
                y: Math.floor(cell.index / 7) * root.rowHeight

                readonly property var  d: cell.modelData
                readonly property bool sel: root._isSelected(cell.d)
                readonly property bool isToday:
                    DateUtil.sameDay(cell.d.year, cell.d.month, cell.d.day, root.today)
                readonly property bool canPick: root.isEnabled(cell.d)

                /* 高亮块的几何：panel 居中，fullscreen 靠左上。
                 * 日期数字**永远**画在这块里面（居中），所以两种模式下
                 * 数字与高亮的关系是同一条契约，只有块的位置在变。 */
                readonly property real markSide:
                    root.fullscreen ? root.markerSize
                                    : Math.max(0, Math.min(cell.width, cell.height) - 4)
                readonly property real markX:
                    root.fullscreen ? 2 : (cell.width - cell.markSide) / 2
                readonly property real markY:
                    root.fullscreen ? 2 : (cell.height - cell.markSide) / 2

                Accessible.role: Accessible.Button
                Accessible.name: DateUtil.format(cell.d, "YYYY-MM-DD")
                Accessible.selected: cell.sel
                Accessible.ignored: !cell.canPick
                Accessible.onPressAction: root.select(cell.d)

                Rectangle {
                    id: mark

                    x: cell.markX
                    y: cell.markY
                    width:  cell.markSide
                    height: cell.markSide
                    radius: root.fullscreen ? Theme.radius.md : Theme.radius.sm

                    color: cell.sel ? Theme.color.brand
                          : (cellMa.containsMouse && cell.canPick
                             ? Theme.color.bgSunken : "transparent")

                    /* 今天用**描边**圈出，选中用**实底** —— 两者可以同时
                     * 成立（今天就是选中那天），此时实底优先、不叠描边。 */
                    border.width: (!cell.sel && cell.isToday) ? 1 : 0
                    border.color: Theme.color.brand
                }

                /* 格子文字走 label 插槽：字号字重全部由主题决定，
                 * 控件里没有一处字体硬编码（QSkinDatePicker 同款约定）。
                 * variant 的选法：选中 primary（反白配品牌底）、
                 * 非本月 / 不可点 muted、其余 default。 */
                Loader {
                    id: cellLabel

                    x: cell.markX
                    y: cell.markY
                    width:  cell.markSide
                    height: cell.markSide
                    sourceComponent: Slots.label

                    Binding {
                        target: cellLabel.item
                        property: "control"
                        value: cellProxy
                        when: cellLabel.item !== null
                    }
                }

                /* 附加内容：只在 fullscreen 且给了 dateCell 时实例化。
                 * Loader（而不是让它常驻）是刻意的 —— 42 个格子里
                 * 常驻 42 个空 Item 与 42 个真实控件是两种开销。 */
                Loader {
                    id: extraLoader

                    x: 2
                    y: cell.markSide + Theme.space.xs
                    width:  Math.max(0, cell.width - 4)
                    height: Math.max(0, cell.height - cell.markSide - Theme.space.sm)

                    visible: root.fullscreen && root.dateCell !== null
                    sourceComponent: visible ? root.dateCell : null

                    Binding {
                        target: extraLoader.item
                        property: "control"
                        value: cellProxy
                        when: extraLoader.item !== null
                    }
                }

                QtObject {
                    id: cellProxy

                    readonly property string text: "" + cell.d.day
                    readonly property bool  enabled: cell.canPick
                    readonly property int   labelAlignment: Text.AlignHCenter
                    readonly property string variant:
                        cell.sel ? "primary"
                                 : ((!cell.d.inMonth || !cell.canPick) ? "muted" : "default")

                    /* 给 dateCell 读的那一份（鸭子类型，见文件头）。 */
                    readonly property var    date: cell.d
                    readonly property bool   inMonth: cell.d.inMonth
                    readonly property bool   selected: cell.sel
                    readonly property bool   isToday: cell.isToday
                    readonly property bool   disabled: !cell.canPick
                    readonly property string dateKey: DateUtil.format(cell.d, "YYYY-MM-DD")
                }

                MouseArea {
                    id: cellMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: cell.canPick ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: cell.canPick
                    onClicked: root.select(cell.d)
                }
            }
        }
    }

    // qmllint enable unqualified
}
