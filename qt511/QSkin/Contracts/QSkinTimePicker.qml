/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinTimePicker
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 时间选择器。点输入框展开时/分（/秒）三列滚轮，选中即写回。
 *
 *     QSkinTimePicker {
 *         onActivated: function(t) { console.log(DateUtil.formatTime(t)) }
 *     }
 *
 * ── 插槽：零新增 ──────────────────────────────────────────────────────
 *
 *     Slots.inputBackground    输入框底板（与 QSkinInput / QSkinSelect / DatePicker 共用）
 *     Slots.selectOverlay      面板外壳（共用）
 *     Slots.label              所有文字：显示值、列里的候选项
 *
 * 与 QSkinDatePicker 是同一套骨架换了内容区 —— 这正是契约层该有的样子：
 * 两个品类完全不同、骨架完全相同的控件，通过复用同一组插槽实现，
 * 主题一行不用改就同时覆盖了它们。
 *
 * ── 四个值得说明的决定 ────────────────────────────────────────────────
 *
 *   1. **不做真实"滚轮"惯性滚动**，而是「可滚动列表 + 点击选中」。
 *      惯性滚轮需要处理速度衰减、吸附对齐、快速甩动的越界回弹 —— 那是
 *      一整套独立的交互系统，成本远超收益。列表点击能覆盖绝大多数场景，
 *      而且天然可键盘操作（↑↓ + Enter）。
 *
 *   2. **选中的项自动滚到中间**，制造"滚轮停在中间"的视觉结果。
 *      列表本身仍是普通的 ListView，只是打开时和每次上下键之后
 *      调 positionViewAtIndex 把当前项对齐到视图中部。
 *
 *   3. **列宽的分配**：时/分/秒各占等宽（hourWidth），中间用冒号分隔。
 *      秒列可以用 showSeconds 关掉，关了之后面板自动收窄 ——
 *      不是留着空白，而是列数真的少一列。
 *
 *   4. **step 参数支持"每 15 分钟一档"**。这是表单里很常见的需求
 *      （预约时间、排班），而生成候选项列表是纯计算，已经在
 *      DateUtil.minutesList(step) 里，控件只负责显示。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Controls 2.4
import QtQuick.Shapes 1.11
import QSkin.Foundation 1.0
import QtQuick.Window 2.11

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    /**
     * 当前时间：{hour, minute, second}，或 null。
     * hour 是 24 小时制（0~23）。赋越界值会先钳制到 [minimumTime, maximumTime]。
     */
    property var value: null

    property string placeholderText: qsTr("请选择时间")

    /** 底部「确定」按钮上的字。 */
    property string okText: qsTr("确定")

    /** 显示格式，见 DateUtil.formatTime。含 "A" 或 "hh" 走 12 小时制。 */
    property string displayFormat: "HH:mm"

    /* ══════════════════════ 约束 ══════════════════════ */

    property var minimumTime: null
    property var maximumTime: null

    /* ══════════════════════ 候选项粒度 ══════════════════════ */

    /** 小时档位间隔（1 = 每个小时都有） */
    property int hourStep: 1

    /** 分钟档位间隔（15 → 00 / 15 / 30 / 45） */
    property int minuteStep: 1

    /** 秒档位间隔 */
    property int secondStep: 1

    /** 是否显示秒列。关了之后面板少一列、宽度自动收窄。 */
    property bool showSeconds: false

    /** 三列的头（时/分/秒）。宿主可整组替换，例如换成 "HH"/"MM"/"SS"。 */
    property var columnLabels: [qsTr("时"), qsTr("分"), qsTr("秒")]

    /* ══════════════════════ 外观 ══════════════════════ */

    property int padding: Theme.space.md

    /** 每个候选项行高 */
    property int rowHeight: Theme.size.controlSm

    /** 列宽 */
    property int columnWidth: 56

    /** 滚动区可见高度（= rowHeight × visibleRows 的视觉高度） */
    property int columnHeight: rowHeight * 5

    /** 面板内边距 */
    property int panelPadding: Theme.space.sm

    /* ══════════════════════ 状态 ══════════════════════ */

    property bool hovered: false
    property bool pressed: false

    readonly property bool opened: popup.opened

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 用户选定了时间。参数是 {hour, minute, second}。 */
    signal activated(var time)

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

    /* ══════════════════════ 给 Slots.label 读的鸭子类型接口 ══════ */

    readonly property string text: root._displayText()
    readonly property string variantName: "default"
    readonly property int    labelAlignment: Text.AlignLeft

    /* ══════════════════════ 候选项 ══════════════════════ */

    readonly property var hours:   DateUtil.hoursList(root.hourStep)
    readonly property var minutes: DateUtil.minutesList(root.minuteStep)
    readonly property var seconds: DateUtil.secondsList(root.secondStep)

    /* ══════════════════════ 显示 / 交互 ══════════════════════ */

    function _displayText() {
        return root.value ? DateUtil.formatTime(root.value, root.displayFormat) : ""
    }

    /** 当前值（或就近兜底）在某列候选项里的下标 */
    function _indexOf(list, v) {
        for (var i = 0; i < list.length; ++i) if (list[i] === v) return i
        return -1
    }

    /** 取某列当前应选中的下标；值不在候选项里时取最接近的上一档 */
    function _currentIndex(list, v) {
        var exact = root._indexOf(list, v)
        if (exact >= 0) return exact
        /* 例如 minuteStep=15 而当前值是 7 分 → 落到 0 分那一档 */
        var best = 0
        for (var i = 0; i < list.length; ++i) {
            if (list[i] <= v) best = i
        }
        return best
    }

    /** 组装一个时间对象，未提供的字段沿用当前值（或零） */
    function _compose(h, m, s) {
        var cur = root.value
                        ? root.value
                        : { hour: 0, minute: 0, second: 0 }
        return {
            hour:   h === undefined || h === null ? cur.hour   : h,
            minute: m === undefined || m === null ? cur.minute : m,
            second: s === undefined || s === null ? cur.second : s
        }
    }

    function _toggle() {
        if (popup.opened) popup.close()
        else              popup.open()
    }

    /* 赋值时就地钳制到 [minimumTime, maximumTime]。
     * 与 QSkinDatePicker 同款：钳制会再写一次 value、重入本函数，
     * 所以先比较、确实需要改才写回，否则会死循环。
     * （写相等值同样触发信号，所以必须用 compareTime 判断，不能只判 null。） */
    onValueChanged: {
        if (root.value !== null && root.value !== undefined) {
            var c = DateUtil.clampTime(root.value, root.minimumTime, root.maximumTime)
            if (DateUtil.compareTime(c, root.value) !== 0)
                root.value = c          /* 重入一次，这次已相等，不会再写 */
        }
    }

    function _pick(h, m, s) {
        var t = root._compose(h, m, s)
        root.value = DateUtil.clampTime(t, root.minimumTime, root.maximumTime)
        popup.close()
        root.activated(root.value)
    }

    /* 列选中变化时：更新值但不关闭面板 —— 用户可能还要接着选下一列。
     * 只有点"确定"或按 Enter 才收。这是与 DatePicker 的关键差异：
     * 日期是"选一个就完事"，时间是"配一组才完事"。 */
    function _changeHour(idx) {
        var v = root._compose(root.hours[idx], null, null)
        root.value = DateUtil.clampTime(v, root.minimumTime, root.maximumTime)
    }
    function _changeMinute(idx) {
        var v = root._compose(null, root.minutes[idx], null)
        root.value = DateUtil.clampTime(v, root.minimumTime, root.maximumTime)
    }
    function _changeSecond(idx) {
        var v = root._compose(null, null, root.seconds[idx])
        root.value = DateUtil.clampTime(v, root.minimumTime, root.maximumTime)
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

    /* ══════════════════════ 时钟图标 ══════════════════════
     * 与 DatePicker 的日历图标同理，用 Shape 画避免 emoji 字体覆盖问题。
     * 圆形 + 指针，是最通用的时钟简笔。 */

    Item {
        id: icon

        anchors.right: parent.right
        anchors.rightMargin: root.padding
        anchors.verticalCenter: parent.verticalCenter

        width:  Theme.size.iconSm
        height: Theme.size.iconSm

        Shape {
            anchors.fill: parent

            ShapePath {
                strokeWidth: 1.4
                strokeColor: root.enabled ? Theme.color.fgSecondary : Theme.color.fgDisabled
                fillColor:   "transparent"
                startX: icon.width / 2; startY: 0.8
                PathAngleArc {
                    centerX: icon.width / 2; centerY: icon.height / 2
                    radiusX: icon.width / 2 - 0.8; radiusY: icon.height / 2 - 0.8
                    startAngle: -90; sweepAngle: 360
                }
            }

            /* 时针：12 点方向 */
            ShapePath {
                strokeWidth: 1.4
                strokeColor: root.enabled ? Theme.color.fgSecondary : Theme.color.fgDisabled
                fillColor:   "transparent"
                startX: icon.width / 2; startY: icon.height / 2
                PathLine { x: icon.width / 2; y: icon.height * 0.28 }
            }

            /* 分针：3 点方向 */
            ShapePath {
                strokeWidth: 1.4
                strokeColor: root.enabled ? Theme.color.fgSecondary : Theme.color.fgDisabled
                fillColor:   "transparent"
                startX: icon.width / 2; startY: icon.height / 2
                PathLine { x: icon.width * 0.76; y: icon.height / 2 }
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

    /* 列数决定面板宽度：时 + 分（+ 秒），列之间留分隔符的位置 */
    readonly property int columnCount: root.showSeconds ? 3 : 2
    readonly property int separatorWidth: root.rowHeight * 0.6

    readonly property int panelWidth:
        root.columnWidth * root.columnCount
        + root.separatorWidth * (root.columnCount - 1)
        + root.panelPadding * 2 + 2

    /* 面板高度：列高 + 列头 + "确定"按钮行 + 内距。
     * 三段高度都取整 —— 非整数高度在 anchors 链式堆叠里会被逐段舍入，
     * 累积下来会把底部按钮挤出可视区（与日历面板同源的坑）。 */
    readonly property int headerHeight: Math.round(root.rowHeight * 0.9)
    /* 脚部高度 = 按钮高 + 上下留白。原来写死 rowHeight*1.6，
     * 在 rowHeight=24 时只有 38，按钮高 30 居中后上下各 4px，
     * 视觉上"确定"紧贴最后一行的数字。改成显式留白，
     * 并把按钮高也定义成具名属性，两者绑在一起算。 */
    readonly property int buttonHeight: Math.round(root.rowHeight * 1.25)
    readonly property int footerGap:    Math.round(root.rowHeight * 0.5)
    readonly property int footerHeight: root.buttonHeight + root.footerGap

    readonly property int panelHeight:
        root.columnHeight + root.headerHeight + root.footerHeight
        + root.panelPadding * 2 + 4

    Popup {
        id: popup

        y: root.flipUp ? (root.overlayExtender - popup.height - Theme.space.xs)
                       : (root.height + Theme.space.xs - root.overlayExtender)

        width:  root.panelWidth + root.overlayExtender * 2
        padding: root.overlayExtender

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
            root._syncColumns()
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

    /* 打开面板 / 键盘上下键之后，把三列各自滚到当前值的位置。
     *
     * 用 positionViewAtIndex(..., Center) 而不失算出精确 contentY：
     * ListView 自己知道每项多高、有多少项，让它算比我们手算可靠。 */
    function _syncColumns() {
        if (!root.value) {
            /* 没值时滚到今天所在时间，给用户一个合理的起点 */
            var n = DateUtil.now()
            root.value = DateUtil.clampTime({ hour: n.hour, minute: n.minute, second: n.second },
                                            root.minimumTime, root.maximumTime)
        }
        var hi = root._currentIndex(root.hours,   root.value.hour)
        var mi = root._currentIndex(root.minutes, root.value.minute)
        var si = root._currentIndex(root.seconds, root.value.second)

        hourList.currentIndex = hi
        minuteList.currentIndex = mi
        secondList.currentIndex = si

        hourList.positionViewAtIndex(hi, ListView.Center)
        minuteList.positionViewAtIndex(mi, ListView.Center)
        secondList.positionViewAtIndex(si, ListView.Center)
    }

    /* 键盘：↑↓ 换档，Enter 确认，Esc 关闭。
     * 落在哪一列由当前焦点决定（面板里列自己也有焦点）。 */
    Keys.onPressed: function(ev) {
        if (!popup.opened) {
            if (ev.key === Qt.Key_Enter || ev.key === Qt.Key_Return
                    || ev.key === Qt.Key_Space || ev.key === Qt.Key_Down) {
                root._toggle(); ev.accepted = true
            }
            return
        }
        if (ev.key === Qt.Key_Escape) {
            popup.close(); ev.accepted = true
        } else if (ev.key === Qt.Key_Enter || ev.key === Qt.Key_Return) {
            root._confirm(); ev.accepted = true
        }
    }

    /* 确认并关闭。把值再钳一次 —— 用户可能从最后一次钳制之后又改过列。 */
    function _confirm() {
        if (root.value)
            root.value = DateUtil.clampTime(root.value, root.minimumTime, root.maximumTime)
        popup.close()
        if (root.value) root.activated(root.value)
    }

    /* ══════════════════════ 面板内容 ══════════════════════ */

    /* 下面的 Repeater / ListView delegate 引用了外层 id（root / Slots）——
     * inline Component 的静态检查局限，同 QSkinDatePicker 局部关闭。 */
    // qmllint disable unqualified

    Item {
        id: bodyRoot

        width:  root.panelWidth - root.panelPadding * 2
        /* 内容区高度按三段内容精确给，不靠 panelHeight 反推 ——
         * 反推会带上 +4 的描边余量，让脚部多出的 4px 跑到按钮下方，
         * 按钮就不是贴底的。 */
        height: root.headerHeight + root.columnHeight + root.footerHeight

        /* ── 列头：时 / 分 / 秒 ── */
        Item {
            id: headerRow

            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.top:   parent.top
            height: root.headerHeight

            QSkinRow {
                anchors.centerIn: parent
                gap: root.separatorWidth

                Repeater {
                    model: root.showSeconds ? root.columnLabels : root.columnLabels.slice(0, 2)

                    delegate: Item {
                        width: root.columnWidth
                        height: root.headerHeight

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.family:    Theme.font.family
                            font.pixelSize: Theme.font.xs
                            color:          Theme.color.fgMuted
                            renderType:     Text.NativeRendering
                        }
                    }
                }
            }
        }

        /* ── 三列候选项 ── */
        Item {
            id: columnArea

            anchors.top: headerRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.columnHeight

            /* 列的"选中窗口"——滚轮只露出 5 行、选中行居中。
             *
             * 一开始试的是上下边缘渐隐（面板底色 → 透明），但底色本身
             * 就是面板底色，白底主题下等于没画，换肤后深浅不一，提示
             * 强度不可控。改成在**中间那一行**上下各画一条极细的品牌色
             * 横线，把"当前值在这一行"直接框出来：任何底色上都看得见，
             * 且与日历的选中色块是同一套语言。横线内联在各列里
             * （见下方三处），不引入新插槽。 */

            QSkinRow {
                id: columnsRow

                anchors.centerIn: parent
                gap: 0

                /* ── 小时列 ── */
                Item {
                    width: root.columnWidth
                    height: root.columnHeight

                    ListView {
                        id: hourList
                        anchors.fill: parent
                        clip: true
                        model: root.hours
                        currentIndex: -1
                        spacing: 0

                        delegate: TimeCell {
                            cellValue: modelData
                            selected: hourList.currentIndex === index
                            onPicked: root._changeHour(index)
                            onStep: function(dir) {
                                var n = hourList.currentIndex + dir
                                if (n < 0 || n >= root.hours.length) return
                                hourList.currentIndex = n
                                root._changeHour(n)
                                hourList.positionViewAtIndex(n, ListView.Center)
                            }
                        }
                    }

                    /* 选中窗口的上下细线。直接内联而不是抽 Component：
                     * 抽 Component 后放进 Row（Layout）里，Loader 会被
                     * 当成待布局子项，实测实例化不出可视内容。
                     * 三列各两份矩形，共 6 行，换来的是"一定画得出来"。 */
                    Rectangle {
                        x: (root.columnWidth - width) / 2
                        width: root.columnWidth * 0.72
                        y: root.rowHeight * 2 + 2
                        height: 2
                        radius: 1
                        color: Theme.color.brand
                        opacity: 0.7
                    }
                    Rectangle {
                        x: (root.columnWidth - width) / 2
                        width: root.columnWidth * 0.72
                        y: root.rowHeight * 3 - 4
                        height: 2
                        radius: 1
                        color: Theme.color.brand
                        opacity: 0.7
                    }
                }

                /* ── 冒号 ── */
                Item {
                    width: root.separatorWidth
                    height: root.columnHeight

                    Text {
                        anchors.centerIn: parent
                        text: ":"
                        font.family:    Theme.font.family
                        font.pixelSize: Theme.font.md
                        font.weight:    Theme.font.weightMedium
                        color:          Theme.color.fgMuted
                        renderType:     Text.NativeRendering
                    }
                }

                /* ── 分钟列 ── */
                Item {
                    width: root.columnWidth
                    height: root.columnHeight

                    ListView {
                        id: minuteList
                        anchors.fill: parent
                        clip: true
                        model: root.minutes
                        currentIndex: -1
                        spacing: 0

                        delegate: TimeCell {
                            cellValue: modelData
                            selected: minuteList.currentIndex === index
                            onPicked: root._changeMinute(index)
                            onStep: function(dir) {
                                var n = minuteList.currentIndex + dir
                                if (n < 0 || n >= root.minutes.length) return
                                minuteList.currentIndex = n
                                root._changeMinute(n)
                                minuteList.positionViewAtIndex(n, ListView.Center)
                            }
                        }
                    }

                    /* 选中窗口的上下细线。直接内联而不是抽 Component：
                     * 抽 Component 后放进 Row（Layout）里，Loader 会被
                     * 当成待布局子项，实测实例化不出可视内容。
                     * 三列各两份矩形，共 6 行，换来的是"一定画得出来"。 */
                    Rectangle {
                        x: (root.columnWidth - width) / 2
                        width: root.columnWidth * 0.72
                        y: root.rowHeight * 2 + 2
                        height: 2
                        radius: 1
                        color: Theme.color.brand
                        opacity: 0.7
                    }
                    Rectangle {
                        x: (root.columnWidth - width) / 2
                        width: root.columnWidth * 0.72
                        y: root.rowHeight * 3 - 4
                        height: 2
                        radius: 1
                        color: Theme.color.brand
                        opacity: 0.7
                    }
                }

                /* ── 第二个冒号 + 秒列（仅当 showSeconds）── */
                Item {
                    visible: root.showSeconds
                    width:  root.showSeconds ? root.separatorWidth : 0
                    height: root.columnHeight

                    Text {
                        anchors.centerIn: parent
                        text: ":"
                        font.family:    Theme.font.family
                        font.pixelSize: Theme.font.md
                        font.weight:    Theme.font.weightMedium
                        color:          Theme.color.fgMuted
                        renderType:     Text.NativeRendering
                    }
                }

                Item {
                    visible: root.showSeconds
                    width:  root.showSeconds ? root.columnWidth : 0
                    height: root.columnHeight

                    ListView {
                        id: secondList
                        anchors.fill: parent
                        visible: root.showSeconds
                        clip: true
                        model: root.seconds
                        currentIndex: -1
                        spacing: 0

                        delegate: TimeCell {
                            cellValue: modelData
                            selected: secondList.currentIndex === index
                            onPicked: root._changeSecond(index)
                            onStep: function(dir) {
                                var n = secondList.currentIndex + dir
                                if (n < 0 || n >= root.seconds.length) return
                                secondList.currentIndex = n
                                root._changeSecond(n)
                                secondList.positionViewAtIndex(n, ListView.Center)
                            }
                        }
                    }

                    /* 选中窗口的上下细线。直接内联而不是抽 Component：
                     * 抽 Component 后放进 Row（Layout）里，Loader 会被
                     * 当成待布局子项，实测实例化不出可视内容。
                     * 三列各两份矩形，共 6 行，换来的是"一定画得出来"。 */
                    Rectangle {
                        x: (root.columnWidth - width) / 2
                        width: root.columnWidth * 0.72
                        y: root.rowHeight * 2 + 2
                        height: 2
                        radius: 1
                        color: Theme.color.brand
                        opacity: 0.7
                    }
                    Rectangle {
                        x: (root.columnWidth - width) / 2
                        width: root.columnWidth * 0.72
                        y: root.rowHeight * 3 - 4
                        height: 2
                        radius: 1
                        color: Theme.color.brand
                        opacity: 0.7
                    }
                }
            }
        }

        /* ── 底部：确定 ──
         * 底部按钮走 buttonBackground / buttonContent 两个插槽？
         * 不用 —— 那需要把 QSkinButton 塞进来，而面板里放一个交互控件
         * 会破坏"插槽不引入新交互"的边界（这是控件自己的按钮，
         * 不是插槽的）。这里用一个轻量自绘按钮，视觉上沿用品牌色，
         * 主题要改它的样子可以在 QSkinButton 里找到同样的语义色。 */
        Item {
            id: footer

            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.top:   columnArea.bottom
            height: root.footerHeight

            /* 按钮贴底对齐（不是居中）—— 脚部的留白统一放在按钮**上方**，
             * 于是按钮与列区之间总有一段稳定的呼吸空间，
             * 面板底边与按钮的距离也固定，不受行高变化影响。 */
            Rectangle {
                id: okBtn

                anchors.right:  parent.right
                anchors.bottom: parent.bottom
                width:  root.columnWidth + root.separatorWidth
                height: root.buttonHeight
                radius: Theme.radius.sm

                color: okMa.pressed ? Theme.color.brandActive
                                    : (okMa.containsMouse ? Theme.color.brandHover
                                                          : Theme.color.brand)

                Text {
                    anchors.centerIn: parent
                    text: root.okText
                    font.family:    Theme.font.family
                    font.pixelSize: Theme.font.sm
                    font.weight:    Theme.font.weightMedium
                    color:          Theme.color.onBrand
                    renderType:     Text.NativeRendering
                }

                MouseArea {
                    id: okMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._confirm()
                }
            }
        }
    }
}
