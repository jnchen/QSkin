/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinTransfer
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 穿梭框：左右两栏，勾选后把条目搬过去。M26 新增。
 *
 * ── 为什么值得做（覆盖面口径）────────────────────────────────────────
 * Ant 5.x（`Transfer`）、Arco（`Transfer`）、TDesign（`Transfer`）三家都有。
 * 三家的形态高度一致：两栏 + 每行一个勾选框 + 中间一组移动按钮 + 每栏
 * 一个标题栏 + 空态。所以本件不是猜的形态。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 值只有一个：`targetKeys`
 * ════════════════════════════════════════════════════════════════════════
 * 左栏**不是**一份独立的数据，它是"`dataSource` 减去 `targetKeys`"：
 *
 *     sourceItems = dataSource \ targetKeys        按 dataSource 顺序
 *     targetItems = targetKeys ∩ dataSource        按 targetKeys 顺序
 *
 * 两条刻意的语义（都是可证伪的，smoke_m26 里钉着）：
 *
 *   · `targetKeys` 里出现 `dataSource` 里**没有**的键 → 右侧**跳过**它，
 *     不渲染一行空白。理由：键的存活时间比数据长（先落盘再加载数据是
 *     常态），"多出来的键"是正常时序，不是错误。
 *   · 移动过去的新键**追加在尾部**（不排序、不插回原位）。理由：用户
 *     刚搬过去的条目出现在视野里同一个位置，比"按原顺序归位"更容易核对。
 *
 * 勾选状态（`_checkedLeft` / `_checkedRight`）是**内部状态**，不是对外
 * 契约 —— 它随移动清空，也不该被外部当数据用。这与 QSkinTree 的
 * `currentKey`（我停在哪）vs `selectedKeys`（选中了什么）是同一种区分。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 行的勾选**不进 model**（这条决定列表会不会抖）
 * ════════════════════════════════════════════════════════════════════════
 * delegate 拿到的是包装行 `{ key, label, disabled, side }` —— 刻意**不含
 * `checked`**。勾选态在行里用 `root._isChecked(key, side)` 实时求值。
 *
 * 理由：`sourceItems` 是个 `readonly property var`，赋值时 ListView 会
 * **整体重建**（数组换了对象）。如果把 `checked` 塞进包装行，那么每次点
 * 勾选框都会重算数组 → 两栏同时重建 → 滚动位置回到顶部、hover 状态丢失。
 * 那是"属性值对、界面错"的又一种（本项目已记过 5 次以上）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 三条**刻意的裁剪**（写出来，不假装完整）
 * ════════════════════════════════════════════════════════════════════════
 * 1. **不做搜索框。** Ant / Arco / TDesign 都有 `showSearch`。不做是因为它
 *    要复用 QSkinInput 的 `text` / 占位符 / 清空 / 焦点契约，而那等于在
 *    本件里再长出一个输入控件 —— "Transfer 该不该有一行搜索框"是个产品
 *    决定，不该由这个文件顺手替消费者回答。要加的话，`FuzzyMatch.filterBy`
 *    已经在了（M26 裁决四），增量改动是把两个 `_rowsOf` 外面再套一层过滤。
 *
 * 2. **按钮只有两个（单项移动），没有"全部移动"。** 四按钮那一组（`>`
 *    `>>` `<` `<<`）里的"双箭头"用 `Slots.chevronIndicator` 表达不出来
 *    （它只有四向箭头，没有"到尽头"那个字形），而画一套新图标等于给
 *    Transfer 单开一格插槽 —— 裁决三说 M26 零新增插槽。所以"全部移动"
 *    走**方法**：`selectAllSource()` + `moveRight()`，或直接 `moveAllToTarget()`。
 *
 * 3. **键盘只到"能 Tab 到按钮并回车"为止。** 列表内的方向键 / 空格勾选
 *    不做（QSkinTree 有，因为它单列；两栏的焦点该落在哪一边是个设计问题，
 *    三家在这一点上也不一致）。写出来，而不是让读者以为键盘全覆盖。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

/* ── 别名 import 是为了拿 QtQuick 的两个**原生 positioner**。
 *
 * 本文件同时 import 了 QtQuick 与 QSkin.Foundation，而 `foundation/qmldir`
 * 把 `Row` / `Column` / `Grid` 三个名字都注册成了自己的实现（CSS 语义，
 * 内部是 RowLayout / ColumnLayout）。裸名会解析成那一份 —— 而布局会
 * **静默忽略**子项自己写的 width / height。本件要的正是"按子项尺寸摆"，
 * 所以必须拿原生 positioner（前置写法 `QtQuick.Row` 在版本化 import 下
 * 不成立，只能走别名 —— 先例是 `QSkinCarousel.qml` 的轨道）。 */
import QtQuick 2.11 as QQ

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 全部可选条目。每项是一个对象，字段名由下面三个 Role 指定 */
    property var    dataSource: []
    property string keyRole:      "key"
    property string textRole:     "label"
    /** 置空字符串则"没有禁用这个概念"（不是"字段名叫空串"） */
    property string disabledRole: "disabled"

    /* ══════════════════════ 值 ══════════════════════ */

    /** 左侧已搬过去的键。**唯一的对外值**（见文件头） */
    property var targetKeys: []

    /* ══════════════════════ 文案 ══════════════════════ */

    /** 两栏标题。`["", ""]` 时两栏都不画标题条 */
    property var    titles: ["", ""]
    property string emptyText: qsTr("暂无数据")

    /* ══════════════════════ 外观 ══════════════════════ */

    property bool showTitles: true
    property bool enabled:    true
    /** 整个控件的高度（Ant 的 listStyle.height 同义） */
    property int  listHeight: 240
    /** 单栏宽度 */
    property int  panelWidth: 220
    property int  rowHeight:  Theme.size.controlMd

    /* ══════════════════════ 交互态 ══════════════════════ */

    property bool hovered: false

    /* ══════════════════════ 内部状态 ══════════════════════ */

    property var _checkedLeft:  []
    property var _checkedRight: []

    /* ══════════════════════ 派生 ══════════════════════ */

    /** 左栏的行（`dataSource \ targetKeys`，按 dataSource 顺序） */
    readonly property var sourceItems: root._rowsOf("left")
    /** 右栏的行（`targetKeys ∩ dataSource`，按 targetKeys 顺序） */
    readonly property var targetItems: root._rowsOf("right")

    readonly property int sourceCount: root._availableItems().length
    readonly property int targetCount: root._chosenItems().length

    /** 左侧当前勾选的条目数（按钮可用性用它） */
    readonly property int checkedLeftCount:  root._usableCheckedCount("left")
    readonly property int checkedRightCount: root._usableCheckedCount("right")

    /* ══════════════════════ 信号 ══════════════════════ */

    /** 搬动了条目。`toTarget` = 方向（true 表示搬去右侧） */
    signal changed(var keys, bool toTarget, var movedKeys)

    /* ══════════════════════ 尺寸 ══════════════════════ */

    /* QQ.Row 的 implicitWidth = 子项 implicitWidth 之和 + 间距 ——
     * 所以两栏给的是 `implicitWidth` 而不是 `width`（positioner 看前者）。 */
    implicitWidth:  mainRow.implicitWidth
    implicitHeight: root.listHeight

    width:  implicitWidth
    height: implicitHeight

    /* ══════════════════════ 无障碍 ══════════════════════ */

    Accessible.role: Accessible.Grouping
    /* 走 `_titleOf` 而不是直接取 `titles[0]` —— 前者对 null / 长度不足
     * 都做了保护，后者在 `titles: null` 时会抛（读屏路径不该是最先崩的）*/
    Accessible.name: root._titleOf(0) + " → " + root._titleOf(1)
    Accessible.description: root.sourceCount + " → " + root.targetCount

    /* ══════════════════════ 布局 ══════════════════════ */

    QQ.Row {
        id: mainRow

        anchors.fill: parent
        spacing: Theme.space.md

        /* ── 左栏 ── */
        Rectangle {
            id: leftPanel

            implicitWidth: root.panelWidth
            width:  root.panelWidth
            height: mainRow.height

            radius: Theme.radius.md
            color:  Theme.color.bg
            border.width: 1
            border.color: Theme.color.divider

            QQ.Column {
                id: leftCol

                anchors.fill: parent

                Item {
                    id: leftHead

                    width:   leftCol.width
                    height:  root._headHeightOf(0)
                    /* 高度为 0 时**必须**藏起来：Item 不裁剪子项，里面那个
                     * 居中文本会照常露出来（"没标题却冒出字"）。 */
                    visible: height > 0

                    Text {
                        anchors.left:           parent.left
                        anchors.leftMargin:     Theme.space.sm
                        anchors.verticalCenter: parent.verticalCenter
                        text: root._titleOf(0)
                        font.family:    Theme.font.family
                        font.pixelSize: Theme.font.sm
                        font.weight:    Font.Medium
                        color:          Theme.color.fg
                        renderType:     Text.NativeRendering
                    }

                    Rectangle {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color:  Theme.color.divider
                    }
                }

                Item {
                    id: leftBody

                    width:  leftCol.width
                    height: leftCol.height - leftHead.height

                    ListView {
                        id: leftList

                        anchors.fill: parent
                        model: root.sourceItems
                        delegate: transferRowComp
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: true
                        focus: false
                    }

                    /* 空态放在 ListView **外面** —— 放里面会跟着内容滚
                     * （QSkinTree 记过同一条：Flickable 的子项是内容）。 */
                    Text {
                        anchors.centerIn: parent
                        visible: leftList.count === 0
                        text: root.emptyText
                        font.family:    Theme.font.family
                        font.pixelSize: Theme.font.sm
                        color:          Theme.color.fgMuted
                        renderType:     Text.NativeRendering
                    }
                }
            }
        }

        /* ── 中间按钮列 ── */
        Item {
            id: midHost

            implicitWidth: midCol.implicitWidth
            width:  implicitWidth
            height: mainRow.height

            QQ.Column {
                id: midCol

                anchors.centerIn: parent
                spacing: Theme.space.xs

                QSkinButton {
                    icon: Slots.chevronIndicator
                    iconDirection: "right"
                    size: "sm"
                    enabled: root.enabled && root.checkedLeftCount > 0
                    accessibleName: qsTr("把勾选的条目移到右边")
                    onClicked: root.moveRight()
                }

                QSkinButton {
                    icon: Slots.chevronIndicator
                    iconDirection: "left"
                    size: "sm"
                    enabled: root.enabled && root.checkedRightCount > 0
                    accessibleName: qsTr("把勾选的条目移回左边")
                    onClicked: root.moveLeft()
                }
            }
        }

        /* ── 右栏 ── */
        Rectangle {
            id: rightPanel

            implicitWidth: root.panelWidth
            width:  root.panelWidth
            height: mainRow.height

            radius: Theme.radius.md
            color:  Theme.color.bg
            border.width: 1
            border.color: Theme.color.divider

            QQ.Column {
                id: rightCol

                anchors.fill: parent

                Item {
                    id: rightHead

                    width:   rightCol.width
                    height:  root._headHeightOf(1)
                    visible: height > 0

                    Text {
                        anchors.left:           parent.left
                        anchors.leftMargin:     Theme.space.sm
                        anchors.verticalCenter: parent.verticalCenter
                        text: root._titleOf(1)
                        font.family:    Theme.font.family
                        font.pixelSize: Theme.font.sm
                        font.weight:    Font.Medium
                        color:          Theme.color.fg
                        renderType:     Text.NativeRendering
                    }

                    Rectangle {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color:  Theme.color.divider
                    }
                }

                Item {
                    id: rightBody

                    width:  rightCol.width
                    height: rightCol.height - rightHead.height

                    ListView {
                        id: rightList

                        anchors.fill: parent
                        model: root.targetItems
                        delegate: transferRowComp
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: true
                        focus: false
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: rightList.count === 0
                        text: root.emptyText
                        font.family:    Theme.font.family
                        font.pixelSize: Theme.font.sm
                        color:          Theme.color.fgMuted
                        renderType:     Text.NativeRendering
                    }
                }
            }
        }
    }

    /* 行模板引用了外层 id（root / Slots）—— 与 QSkinSelect 的 delegate 同款，
     * 局部关闭即可。注释首行不要以 qmllint 开头，否则会被当成指令解析。 */
    // qmllint disable unqualified

    Component {
        id: transferRowComp

        Rectangle {
            id: row

            property var modelData

            readonly property bool checked:
                root._isChecked(row.modelData.key, row.modelData.side)
            readonly property bool rowDisabled:
                !root.enabled || row.modelData.disabled

            property bool hovered: false

            width:  parent ? parent.width : 0
            height: root.rowHeight

            color: row.hovered && !row.rowDisabled ? Theme.color.bgSubtle
                                                   : "transparent"

            /* 勾选框 */
            Loader {
                id: rowCheckLoader

                x: Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter

                sourceComponent: Slots.checkIndicator

                Binding {
                    target: rowCheckLoader.item
                    property: "control"
                    value: rowCheckProxy
                    when: rowCheckLoader.item !== null
                }
            }

            QtObject {
                id: rowCheckProxy

                readonly property bool checked:       row.checked
                readonly property bool indeterminate: false
                readonly property bool enabled:       !row.rowDisabled
                readonly property bool hovered:       row.hovered
            }

            /* 文字 */
            Loader {
                id: rowLabelLoader

                anchors.left:           rowCheckLoader.right
                anchors.leftMargin:     Theme.space.sm
                anchors.right:          parent.right
                anchors.rightMargin:    Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter

                sourceComponent: Slots.label

                Binding {
                    target: rowLabelLoader.item
                    property: "control"
                    value: rowLabelProxy
                    when: rowLabelLoader.item !== null
                }
            }

            QtObject {
                id: rowLabelProxy

                readonly property string text:  row.modelData.label
                readonly property string variant: "text"
                readonly property int labelAlignment: Text.AlignLeft
                readonly property bool enabled: !row.rowDisabled
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: row.rowDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                enabled: !row.rowDisabled

                onEntered:  row.hovered = true
                onExited:   row.hovered = false
                /* 单击 = 勾选（三家一致）；双击 = 直接把这一条搬过去（Ant 的行为）*/
                onClicked:      root._toggleCheck(row.modelData.key, row.modelData.side)
                onDoubleClicked: root._moveKeys([row.modelData.key],
                                                row.modelData.side === "left")
            }
        }
    }

    // qmllint enable unqualified

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 把左栏勾选的搬到右边 */
    function moveRight() { root._moveChecked("left") }
    /** 把右栏勾选的搬回左边 */
    function moveLeft()  { root._moveChecked("right") }

    /** 把左栏**全部**搬到右边（没有按钮，见文件头裁剪 2） */
    function moveAllToTarget() { root._moveKeys(root._allUsableKeys(root._availableItems()), true) }
    /** 把右栏**全部**搬回左边 */
    function moveAllToSource() { root._moveKeys(root._allUsableKeys(root._chosenItems()), false) }

    /** 勾上左栏全部可用的条目（配 moveRight() 就是"全选后移动"） */
    function selectAllSource() {
        root._checkedLeft = root._allUsableKeys(root._availableItems())
    }
    function selectAllTarget() {
        root._checkedRight = root._allUsableKeys(root._chosenItems())
    }

    /* ══════════════════════ 算路 ══════════════════════ */

    function _keyOf(item) {
        var v = item[root.keyRole]
        return v === undefined || v === null ? "" : String(v)
    }

    function _labelOf(item) {
        var v = item[root.textRole]
        return v === undefined || v === null ? "" : String(v)
    }

    function _isDisabled(item) {
        if (root.disabledRole === "") return false
        return item[root.disabledRole] === true
    }

    /** dataSource \ targetKeys */
    function _availableItems() {
        var inTarget = {}
        for (var i = 0; i < root.targetKeys.length; ++i)
            inTarget[String(root.targetKeys[i])] = true

        var out = []
        for (var j = 0; j < root.dataSource.length; ++j) {
            var it = root.dataSource[j]
            if (!inTarget[root._keyOf(it)]) out.push(it)
        }
        return out
    }

    /** targetKeys ∩ dataSource（顺序跟 targetKeys；找不到的键跳过） */
    function _chosenItems() {
        var byKey = {}
        for (var i = 0; i < root.dataSource.length; ++i) {
            var it = root.dataSource[i]
            byKey[root._keyOf(it)] = it
        }

        var out = []
        for (var j = 0; j < root.targetKeys.length; ++j) {
            var hit = byKey[String(root.targetKeys[j])]
            if (hit !== undefined) out.push(hit)
        }
        return out
    }

    /** 包装成行 —— **不含 checked**（见文件头：含了列表会在勾选时重建） */
    function _rowsOf(side) {
        var items = side === "left" ? root._availableItems() : root._chosenItems()
        var out = []
        for (var i = 0; i < items.length; ++i) {
            var it = items[i]
            out.push({
                key:      root._keyOf(it),
                label:    root._labelOf(it),
                disabled: root._isDisabled(it),
                side:     side
            })
        }
        return out
    }

    function _isChecked(key, side) {
        var list = side === "left" ? root._checkedLeft : root._checkedRight
        return list.indexOf(String(key)) >= 0
    }

    function _toggleCheck(key, side) {
        var k = String(key)
        var list = (side === "left" ? root._checkedLeft
                                    : root._checkedRight).slice(0)
        var i = list.indexOf(k)
        if (i >= 0) list.splice(i, 1)
        else        list.push(k)

        if (side === "left") root._checkedLeft  = list
        else                 root._checkedRight = list
    }

    /** 一栏里"可用的"（未禁用）键 —— 全选与批量移动都只碰这些 */
    function _allUsableKeys(items) {
        var out = []
        for (var i = 0; i < items.length; ++i)
            if (!root._isDisabled(items[i])) out.push(root._keyOf(items[i]))
        return out
    }

    /** 勾选里还能用的条数（禁用项会被排除，所以按钮可用性不能用 _checkedX.length）*/
    function _usableCheckedCount(side) {
        var items = side === "left" ? root._availableItems() : root._chosenItems()
        var out = 0
        for (var i = 0; i < items.length; ++i)
            if (!root._isDisabled(items[i]) && root._isChecked(root._keyOf(items[i]), side))
                out += 1
        return out
    }

    function _moveChecked(fromSide) {
        var keys = []
        var items = fromSide === "left" ? root._availableItems() : root._chosenItems()
        for (var i = 0; i < items.length; ++i) {
            var it = items[i]
            if (!root._isDisabled(it) && root._isChecked(root._keyOf(it), fromSide))
                keys.push(root._keyOf(it))
        }
        root._moveKeys(keys, fromSide === "left")
    }

    /** 搬动的唯一出口 —— 改 targetKeys、清勾选、发信号，都在这里 */
    function _moveKeys(keys, toTarget) {
        if (keys.length === 0) return

        var next
        if (toTarget) {
            next = root.targetKeys.slice(0)
            for (var i = 0; i < keys.length; ++i)
                if (next.indexOf(keys[i]) < 0) next.push(keys[i])
        } else {
            var drop = {}
            for (var j = 0; j < keys.length; ++j) drop[String(keys[j])] = true
            next = []
            for (var k = 0; k < root.targetKeys.length; ++k)
                if (!drop[String(root.targetKeys[k])]) next.push(root.targetKeys[k])
        }

        root.targetKeys = next
        /* 搬完就清掉**那一侧**的勾选（另一侧不动 —— 用户可能正在那边挑）*/
        if (toTarget) root._checkedLeft  = []
        else          root._checkedRight = []

        root.changed(next, toTarget, keys)
    }

    /* ══════════════════════ 小组件 ══════════════════════ */

    function _titleOf(i) {
        if (!root.showTitles) return ""
        var t = root.titles
        if (t === null || t === undefined) return ""
        var v = t[i]
        return v === undefined || v === null ? "" : String(v)
    }

    /** 标题条高度：没标题（或不显示）时给 0，于是 Column 自然收掉那一格 */
    function _headHeightOf(i) {
        return root._titleOf(i) === "" ? 0 : Theme.size.controlSm
    }
}
