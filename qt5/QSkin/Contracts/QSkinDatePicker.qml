/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinDatePicker
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 日期选择器。点输入框展开日历面板，选一天后收起。
 *
 *     QSkinDatePicker {
 *         onActivated: function(date) { console.log(DateUtil.format(date)) }
 *     }
 *
 * ── 插槽：零新增 ──────────────────────────────────────────────────────
 *
 *     Slots.inputBackground    输入框底板（与 QSkinInput / QSkinSelect 共用）
 *     Slots.selectOverlay      日历面板外壳（与 QSkinSelect 共用）
 *     Slots.label              所有文字：显示值、月份标题、星期头、日格子
 *
 * 日历的"格子"看着像新东西，其实结构上就是**网格里的一堆文字**：
 * 每个格子 = 一个定位用的 Rectangle + 一个 label 实例。颜色、字号、
 * 字重全由 label 的 variant 决定，控件里没有一行硬编码字体。
 * 换个主题，日历的字号字重跟着输入框一起变。
 *
 * ── 三个值得说明的决定 ────────────────────────────────────────────────
 *
 *   1. **面板宽度不跟输入框走**，而是按内容算（7 列 × 格子 + 内距）。
 *      QSkinSelect 的做法是 contentWidth: root.width，因为下拉列表
 *      天然和输入框同宽。日历是 7 列方格，跟一个 200px 的输入框同宽
 *      会挤成一条；反过来若把输入框撑到日历那么宽又很怪。
 *      所以这里覆写 Popup 的 contentWidth，让面板自成尺寸。
 *
 *   2. **网格固定 42 格**（见 DateUtil.monthGrid）。不同月份占 4~6 行，
 *      不固定的话翻月时面板高度会跳。多出来的格子属于相邻月，灰显可点，
 *      这是通行做法。
 *
 *   3. **输入框是只读的**。日历的值由面板产生，不接键盘直接键入 ——
 *      日期格式（YYYY-MM-DD / YYYY/MM/DD / MM月DD日…）千变万化，
 *      让用户盲打再猜格式的体验远不如点两下。需要键入的场景请用
 *      QSkinInput + DateUtil.parse 自己接。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Shapes 1.15
/* 只为 Layout.alignment —— 标题行用的是 QSkin.Foundation 的 Row（= RowLayout），
 * 它的子项不能用 anchors，详见那段注释。 */
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0
import QtQuick.Window 2.15

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    /**
     * 当前选中日期：{year, month, day}，或 null。
     * 赋 null 会清空。赋越界日期会先钳到 [minimumDate, maximumDate]。
     * 注意 month 是 1~12（不是 JS Date 的 0~11）。
     */
    property var value: null

    property string placeholderText: qsTr("请选择日期")

    /** 显示格式，见 DateUtil.format。 */
    property string displayFormat: "YYYY-MM-DD"

    /* ══════════════════════ 约束 ══════════════════════ */

    property var minimumDate: null
    property var maximumDate: null

    /* ══════════════════════ 外观 ══════════════════════ */

    property int padding: Theme.space.md

    /** 单个日格子的边长。7 列 + 6 行 的网格尺寸由它推出。 */
    property int cellSize: 32

    /** 面板内边距 */
    property int panelPadding: Theme.space.sm

    /* ══════════════════════ 状态 ══════════════════════ */

    property bool hovered: false
    property bool pressed: false

    readonly property bool opened: popup.opened

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 用户选定了某一天。参数是 {year, month, day}。 */
    signal activated(var date)

    /* 注意：不要再声明 openedChanged()。
     * readonly 的 opened 是只读属性，QML 会自动为它生成一个
     * openedChanged 信号。自己再声明一个同名的，qmllint 直接报
     * duplicated-name，运行时也会撞车。要监听开合，用
     * onOpenedChanged: 即可（它由属性自动提供）。 */

    /* ══════════════════════ 尺寸 ══════════════════════ */

    implicitWidth:  200
    implicitHeight: Theme.size.controlMd

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true

    Accessible.role: Accessible.ComboBox
    Accessible.name: root._displayText() !== "" ? root._displayText() : root.placeholderText
    Accessible.editable: false
    Accessible.onPressAction: root._toggle()

    /* ══════════════════════ 给 Slots.label 读的鸭子类型接口 ══════
     * 与 QSkinButton / QSkinSelect 保持同一套，label 插槽原样可用。 */

    readonly property string text: root._displayText()
    readonly property string variantName: "default"
    readonly property int    labelAlignment: Text.AlignLeft

    /* ══════════════════════ 内部：面板浏览状态 ══════════════════════
     * panelYear / panelMonth 是"面板正显示哪个月"，与 value 解耦 ——
     * 用户可以翻到别的月份看一圈再翻回来，不改选中的值。 */

    property int panelYear:  DateUtil.today().year
    property int panelMonth: DateUtil.today().month

    /** 面板标题上的**月份**文字 —— 与 `QSkinCalendar.monthText` 同源同理由：
     *  取 `DateUtil.monthLabels`，不用 `qsTr("%1月")`（后缀式模板在英文里
     *  没有对应构造，展开见 `QSkinCalendar` 那段注释）。`panelMonth` 恒在
     *  1..12（`today()` / `value` / `addMonths()` 三个赋值点），仍夹一次。 */
    readonly property string monthText:
        DateUtil.monthLabels[Math.max(0, Math.min(11, root.panelMonth - 1))]

    /* 每次展开时把面板对齐到：有值就对齐到值所在月，否则回到今天所在月。
     * 否则上次翻到 2030 年、关掉再开，会停在一个与当前值无关的月份。 */
    function _syncPanelToValue() {
        if (root.value) {
            root.panelYear  = root.value.year
            root.panelMonth = root.value.month
        } else {
            var t = DateUtil.today()
            root.panelYear  = t.year
            root.panelMonth = t.month
        }
    }

    /* 赋值时就地钳制到 [minimumDate, maximumDate]。
     *
     * 这里有个必须小心的点：钳制会**再写一次 value**，从而重入
     * onValueChanged。所以要先比较、确实需要改才写回，
     * 否则两个越界值来回钳制会打成死循环。
     * （写入相等值同样会触发信号，所以必须用 compare 判断，不能只判 null。） */
    onValueChanged: {
        if (root.value !== null && root.value !== undefined) {
            var c = DateUtil.clamp(root.value, root.minimumDate, root.maximumDate)
            if (DateUtil.compare(c, root.value) !== 0) {
                root.value = c          /* 重入一次，这次已经相等，不会再写 */
                return
            }
        }
        root._syncPanelToValue()
    }

    function _displayText() {
        return root.value ? DateUtil.format(root.value, root.displayFormat) : ""
    }

    /* ══════════════════════ 日期可用性 ══════════════════════ */

    /** 某天是否在 [minimumDate, maximumDate] 内 */
    function _inRange(y, m, d) {
        var cand = { year: y, month: m, day: d }
        if (root.minimumDate && DateUtil.compare(cand, root.minimumDate) < 0) return false
        if (root.maximumDate && DateUtil.compare(cand, root.maximumDate) > 0) return false
        return true
    }

    /** 是否与当前值同一天 */
    function _isSelected(y, m, d) {
        return root.value !== null && root.value !== undefined
            && root.value.year === y && root.value.month === m && root.value.day === d
    }

    /* ══════════════════════ 交互 ══════════════════════ */

    function _toggle() {
        if (popup.opened) popup.close()
        else              popup.open()
    }

    function _pick(y, m, d) {
        var picked = { year: y, month: m, day: d }
        /* 钳制兜底：理论上灰掉的格子不可点，但键盘导航可能走到边界外 */
        root.value = DateUtil.clamp(picked, root.minimumDate, root.maximumDate)
        popup.close()
        root.activated(root.value)
    }

    function _goMonth(delta) {
        var r = DateUtil.addMonths(root.panelYear, root.panelMonth, delta)
        root.panelYear  = r.year
        root.panelMonth = r.month
        grid.model = DateUtil.monthGrid(root.panelYear, root.panelMonth)
    }

    function _goToday() {
        var t = DateUtil.today()
        root.panelYear  = t.year
        root.panelMonth = t.month
        grid.model = DateUtil.monthGrid(root.panelYear, root.panelMonth)
    }

    /* ══════════════════════ 插槽：底板 ══════════════════════ */

    Loader {
        id: backgroundLoader

        anchors.fill: parent
        sourceComponent: Slots.inputBackground

        Binding {
            target: backgroundLoader.item
            property: "control"
            value: root
            when: backgroundLoader.item !== null
        }
    }

    /* ══════════════════════ 显示值 / 占位符 ══════════════════════ */

    Item {
        anchors.fill: parent
        anchors.leftMargin:  root.padding
        anchors.rightMargin: root.padding + icon.width + Theme.space.sm

        Loader {
            id: textLoader

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            sourceComponent: Slots.label

            Binding {
                target: textLoader.item
                property: "control"
                value: root
                when: textLoader.item !== null
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root._displayText() === "" && root.placeholderText !== ""

            text:  root.placeholderText
            font.family:    Theme.font.family
            font.pixelSize: Theme.font.sm
            color:          Theme.color.fgMuted
            elide:          Text.ElideRight
            renderType:     Text.NativeRendering
        }
    }

    /* ══════════════════════ 日历图标 ══════════════════════
     * 用 Shape 画而不是 Text "📅"：emoji 的字体覆盖不可靠，
     * 换台机器就可能变成豆腐块。与 QSkinSelect 的 caret 同理。
     * 图形是"日历"的通用简笔：外框 + 顶部装订条 + 两个挂钩。 */

    Item {
        id: icon

        anchors.right: parent.right
        anchors.rightMargin: root.padding
        anchors.verticalCenter: parent.verticalCenter

        width:  Theme.size.iconSm
        height: Theme.size.iconSm

        Shape {
            anchors.fill: parent

            /* 外框 */
            ShapePath {
                strokeWidth: 1.4
                strokeColor: root.enabled ? Theme.color.fgSecondary : Theme.color.fgDisabled
                fillColor:   "transparent"
                startX: 1; startY: 4
                PathLine { x: icon.width - 1; y: 4 }
                PathLine { x: icon.width - 1; y: icon.height - 1 }
                PathLine { x: 1; y: icon.height - 1 }
                PathLine { x: 1; y: 4 }
            }

            /* 顶部装订条 */
            ShapePath {
                strokeWidth: -1
                fillColor:   root.enabled ? Theme.color.fgSecondary : Theme.color.fgDisabled
                startX: 1; startY: 4
                PathLine { x: icon.width - 1; y: 4 }
                PathLine { x: icon.width - 1; y: 7 }
                PathLine { x: 1; y: 7 }
                PathLine { x: 1; y: 4 }
            }

            /* 两个挂钩 */
            ShapePath {
                strokeWidth: 1.4
                strokeColor: root.enabled ? Theme.color.fgSecondary : Theme.color.fgDisabled
                fillColor:   "transparent"
                startX: icon.width * 0.3; startY: 1
                PathLine { x: icon.width * 0.3; y: 4 }
            }
            ShapePath {
                strokeWidth: 1.4
                strokeColor: root.enabled ? Theme.color.fgSecondary : Theme.color.fgDisabled
                fillColor:   "transparent"
                startX: icon.width * 0.7; startY: 1
                PathLine { x: icon.width * 0.7; y: 4 }
            }
        }
    }

    FocusRing { control: root }

    /* ══════════════════════ 鼠标 ══════════════════════ */

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: root.hovered = true
        onExited:  root.hovered = false
        onPressed: root.pressed = true
        onReleased: root.pressed = false
        onClicked: root._toggle()
    }

    /* ══════════════════════ 浮层 ══════════════════════ */

    readonly property var  overlayItem: overlayLoader.item
    readonly property real overlayExtender: root.overlayItem !== null
        && root.overlayItem.extender !== undefined ? root.overlayItem.extender : 0

    /* 面板宽度按内容算：7 列格子 + 面板内距 + 描边余量。
     * 见文件头「决定 1」。 */
    readonly property int panelWidth: cellSize * 7 + panelPadding * 2 + 2

    /* 面板高度：标题行 + 星期头 + 6 行格子 + 内距。
     *
     * 这三个高度用 Math.round 取整：cellSize * 0.9 在 cellSize=32 时是 28.8，
     * 非整数高度在 anchors 链式堆叠里会被逐段舍入，且 Text 的 NativeRendering
     * 在半个像素上行高也会漂 —— 曾经因此把第 6 行挤出可视区。
     * 取整后「三行高之和」与「面板高 - 内距」严格吻合，格子不会被裁。 */
    readonly property int headerHeight:  Math.round(cellSize * 1.0)
    readonly property int weekdayHeight: Math.round(cellSize * 0.9)
    readonly property int gridHeight:    cellSize * 6

    readonly property int panelHeight: headerHeight + weekdayHeight + gridHeight
                                     + panelPadding * 2 + 2

    Popup {
        id: popup

        /* 与 QSkinSelect 同款上下翻转：下方不够就朝上弹。
         * 这里比的是 panelWidth / panelHeight（面板实际尺寸），
         * 不是输入的宽高 —— 面板比输入框大得多，用输入框的尺寸判断会误翻。 */
        y: root.flipUp ? (root.overlayExtender - popup.height - Theme.space.xs)
                       : (root.height + Theme.space.xs - root.overlayExtender)

        width:  root.panelWidth + root.overlayExtender * 2
        padding: root.overlayExtender

        /* 面板外观完全由 overlay 插槽负责 */
        background: Item {}

        contentItem: Loader {
            id: overlayLoader

            sourceComponent: Slots.selectOverlay

            Binding {
                target: overlayLoader.item
                property: "control"
                value: root
                when: overlayLoader.item !== null
            }
            Binding {
                target: overlayLoader.item
                property: "content"
                value: bodyRoot
                when: overlayLoader.item !== null
            }
        }

        contentWidth:  root.panelWidth
        contentHeight: root.panelHeight

        onOpened: {
            root._syncPanelToValue()
            grid.model = DateUtil.monthGrid(root.panelYear, root.panelMonth)
        }
        onClosed: {
            root.pressed = false
        }
    }

    readonly property bool flipUp: {
        var win = Window.window
        if (!win) return false
        var gy    = root.mapToItem(win.contentItem, 0, 0).y
        var below = win.height - (gy + root.height)
        return below < root.panelHeight + Theme.space.xs && gy > below
    }

    /* ══════════════════════ 面板内容 ══════════════════════ */

    /* 下面星期头与日期网格的 delegate 都引用了外层 id（root / Slots）——
     * inline Component 的静态检查局限，与 QSkinBreadcrumb / QSkinSteps /
     * QSkinSelect 同款，局部关闭。运行时是沿上下文链查找的，引用完全正确。 */
    // qmllint disable unqualified

    Item {
        id: bodyRoot

        /* 这个 Item 会被 overlay 插槽 reparent 进面板内容区。
         * 尺寸由控件给定（面板宽 - 内距），所以内部可以正常用 anchors。 */
        width:  root.panelWidth - root.panelPadding * 2
        /* 内容区高度按三段内容精确给，不靠 panelHeight 反推 ——
         * 反推会带上 +2 的描边余量，让网格下方多出 2px 空白，
         * 翻月时面板高度会跟着这 2px 一起抖。 */
        height: root.headerHeight + root.weekdayHeight + root.gridHeight

        /* ── 月份标题行：上月箭头 · 2026年 9月 · 下月箭头 ── */
        Item {
            id: headerBar

            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.top:   parent.top
            height: root.headerHeight

            /* 上一个月 */
            Item {
                id: prevBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.cellSize; height: root.cellSize

                Rectangle {
                    anchors.centerIn: parent
                    width: root.cellSize - 8; height: root.cellSize - 8
                    radius: Theme.radius.sm
                    color: prevMa.containsMouse ? Theme.color.bgSunken : "transparent"
                }
                /* 箭头走 chevronIndicator 插槽。这里原本自己画了一条
                 * 7×11 的折线 —— 而同一个「上一页 / 下一页」的记号，
                 * QSkinPagination 那边打的是字符 "‹"。同一种记号两种画法，
                 * 正是这次要清零的那类不自洽。 */
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

            /* 伪装成控件给 chevronIndicator 读 —— 与表头 hcell、
             * 分页 totalCtl 同一套约定。 */
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

            /* 标题：2026年 9月。年份和月份分两个 label，
             * 年份用 muted 让月份更突出 —— 翻月时用户的注意力在月份上。
             *
             * ── 这里为什么是 Layout.alignment 而不是 anchors（实测抓出来的）──
             * 这个 `Row` 是 **QSkin.Foundation 的 Row**（= RowLayout），不是
             * QtQuick 的 positioner —— 两个证据：① 它认 `gap`（positioner
             * 只有 spacing，写 gap 会报"不存在的属性"）；② 运行时报
             * "Detected anchors on an item that is managed by a layout"。
             *
             * 谁把它判成 positioner，就会顺手写 anchors.verticalCenter ——
             * 而这个锚点在 Layout 接管几何之后是**未定义行为**：不报错、
             * 不生效，只是某一天悄悄歪掉。同一类坑在 README 第十节记过。
             * 正确写法是 Layout.alignment（需要 import QtQuick.Layouts）。
             *
             * 父级 headerBar 是普通 Item，所以外面那个 anchors.centerIn 合法。 */
            QSkinRow {
                anchors.centerIn: parent
                gap: 2

                Loader {
                    id: yearLoader
                    Layout.alignment: Qt.AlignVCenter
                    sourceComponent: Slots.label
                    Binding { target: yearLoader.item; property: "control"; value: yearProxy
                              when: yearLoader.item !== null }
                }
                Loader {
                    id: monthLoader
                    Layout.alignment: Qt.AlignVCenter
                    sourceComponent: Slots.label
                    Binding { target: monthLoader.item; property: "control"; value: monthProxy
                              when: monthLoader.item !== null }
                }
            }

            /* 下一个月 */
            Item {
                id: nextBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: root.cellSize; height: root.cellSize

                Rectangle {
                    anchors.centerIn: parent
                    width: root.cellSize - 8; height: root.cellSize - 8
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
        }

        /* ── 星期头 ── */
        QSkinRow {
            id: weekdayBar

            anchors.top: headerBar.bottom
            anchors.left: parent.left
            width: parent.width
            height: root.weekdayHeight

            Repeater {
                model: DateUtil.weekdayLabels
                delegate: Item {
                    width: root.cellSize
                    height: root.weekdayHeight

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.family:    Theme.font.family
                        font.pixelSize: Theme.font.xs
                        font.weight:    Theme.font.weightMedium
                        color:          Theme.color.fgMuted
                        renderType:     Text.NativeRendering
                    }
                }
            }
        }

        /* ── 6×7 日期网格 ──
         * 用 Repeater + 42 项而不是 GridLayout/GridView：
         * 格子数固定 42，位置用 index 直接算行列，
         * 比让 Layout 参与测量的链路短得多，也避免了
         * "Layout 接管子项 x/y"带来的定位不确定。 */
        Item {
            id: grid

            property var model: []

            anchors.top: weekdayBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.gridHeight

            Repeater {
                model: grid.model

                delegate: Item {
                    id: cell

                    required property int index
                    required property var modelData

                    width:  root.cellSize
                    height: root.cellSize
                    x: (cell.index % 7) * root.cellSize
                    y: Math.floor(cell.index / 7) * root.cellSize

                    readonly property var d: cell.modelData
                    readonly property bool sel: root._isSelected(cell.d.year, cell.d.month, cell.d.day)
                    readonly property bool enabledDay: root._inRange(cell.d.year, cell.d.month, cell.d.day)

                    /* 选中底色用品牌色；今天用描边圈出；其余靠文字变灰区分 */
                    Rectangle {
                        anchors.centerIn: parent
                        width:  root.cellSize - 4
                        height: root.cellSize - 4
                        radius: Theme.radius.sm
                        color: cell.sel ? Theme.color.brand
                                        : (cellMa.containsMouse && cell.enabledDay
                                           ? Theme.color.bgSunken : "transparent")

                        border.width: (!cell.sel && cell.d.isToday) ? 1 : 0
                        border.color: Theme.color.brand
                    }

                    /* 格子文字走 label 插槽。
                     * 用一个代理对象伪装成"控件"，把要显示的文字和
                     * 语义变体喂给 label —— 这样日历的字号字重完全由
                     * 主题的 label 决定，控件里没有字体硬编码。
                     *
                     * variant 的选法：
                     *   selected  → primary（反白，与选中底色配对）
                     *   非本月    → muted（存在但不抢眼）
                     *   超出范围  → 也走 muted（灰掉，且不可点）
                     *   其余      → default */
                    Loader {
                        id: cellLabel

                        anchors.fill: parent
                        sourceComponent: Slots.label

                        Binding {
                            target: cellLabel.item
                            property: "control"
                            value: cellProxy
                            when: cellLabel.item !== null
                        }
                    }

                    QtObject {
                        id: cellProxy
                        readonly property string text: "" + cell.d.day
                        readonly property bool  enabled: cell.enabledDay
                        readonly property int   labelAlignment: Text.AlignHCenter
                        readonly property string variant:
                            cell.sel ? "primary"
                                     : ((!cell.d.inMonth || !cell.enabledDay) ? "muted" : "default")
                    }

                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: cell.enabledDay ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: cell.enabledDay
                        onClicked: root._pick(cell.d.year, cell.d.month, cell.d.day)
                    }
                }
            }
        }
    }

    /* 月份标题的两个代理（给 label 喂文字） */
    QtObject {
        id: yearProxy
        readonly property string text: qsTr("%1年").arg(root.panelYear)
        readonly property string variant: "muted"
        readonly property int    labelAlignment: Text.AlignHCenter
    }
    QtObject {
        id: monthProxy
        readonly property string text: root.monthText
        readonly property string variant: "default"
        readonly property int    labelAlignment: Text.AlignHCenter
        /* 月份标题比正文重一点，让它在年份旁边站住 */
        readonly property bool   header: true
    }
}
