/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinCommand
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 命令面板 —— 一个输入框 + 一串按模糊匹配筛过的动作。参照 shadcn 的
 * `Command`（它下面用的是 cmdk）。
 *
 * ── 它是一个**面板**，不是一个对话框 ─────────────────────────────────
 * shadcn 把两件事拆成两个名字：`Command` 是面板、`CommandDialog` 是把它
 * 装进 Dialog 之后的形态。本仓按同样的分法：本件只做面板。
 * 模态形态用 `QSkinDialog` 包一层即可（本仓已有 `QSkinAlertDialog` 这个
 * "预设而非新控件"的先例）：
 *
 *     QSkinDialog {
 *         QSkinCommand { model: [...] ; onSelected: { ...; dialog.close() } }
 *     }
 *
 * 这么做而不是内置一个 `modal` 开关，是因为模态那一套（遮罩 / 焦点陷阱 /
 * Esc / 点击外部）已经在 `QSkinDialog` 里且在四主题上验过。本件再长一份，
 * 就是第二份模态（本项目记过这个病：同一个 affordance 四种画法）。
 *
 * ── 筛选是**算出来的**，且算法在地基层只有一份 ─────────────────────────
 * `QSkin.Foundation.FuzzyMatch` —— 打分器的定义、并列取最左、空查询语义
 * 全在那份文件头里。本件一行匹配都没有：它把 `model` 展平、逐条问分、
 * 按分排序、再按原分组顺序收拢。于是：
 *
 *     · 门禁可以绕开 UI，用 node 直接打那份实现（含**穷举**交叉验证）
 *     · 本件的行为判据只需断言"结果集与顺序"，不必重算分数
 *
 * ── 为什么不用 ListView 的 section 机制来分组 ──────────────────────────
 * 因为分组的**顺序**必须由"原 model 的分组顺序"决定，而 section 是按
 * 排序键现算的。筛选后每个分组里可能一条都不剩 —— 那种分组连标题都不该
 * 出现。"哪些标题还有活着的条目"是筛选的结果，不是视图的推测。
 * 所以这里展平成一维（标题行 + 条目行）再交给 ListView。
 *
 * ── 逐字符高亮**未做**（如实记一笔，别当成漏写）───────────────────────
 * cmdk 会把命中的字符着色。本仓不做，理由是**它没法被本批的判据证伪**：
 * 每个命中字符的相位宽度要用 `TextMetrics` 量，而 `TextMetrics` 一次只
 * 给一个前缀宽 —— N 个命中就是 N 组测量与 N 条绑定依赖，量出来的位置还
 * 没有一条独立算路可以核对（像素判据要"命中字符下方有色带"，
 * 而色带的位置本身来自同一个测量）。与其画一个量不准的色带，
 * 不如先把"筛得对、排得对"做对。
 *
 * 命中下标**照样算出来并暴露**（`filteredGroups[i].items[j].hits`），
 * 所以将来做高亮时数据已经在手上。`FuzzyMatch.hitRuns()` 也一并备好了。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /**
     * 分组。每项：
     *   { heading: "建议", items: [ 条目, … ] }
     *
     * 条目（与 `QSkinMenu` 的行模型**不共用**：那边是"动作菜单"，
     * 语义是危险/禁用；这边还要 `keywords` 与 `shortcut`）：
     *   { text, keywords: "别名 空格分隔", shortcut: "⌘K", enabled, danger }
     */
    property var model: []

    /** 搜索词。空串 = 全量、保持声明序（见 FuzzyMatch 文件头第 2 条） */
    property string query: ""

    /** 输入框的提示文字 */
    property string placeholder: qsTr("输入命令或搜索…")

    /** 一条都没筛出来时显示的字 */
    property string emptyText: qsTr("没有匹配的命令")

    /* ══════════════════════ 外观 ══════════════════════ */

    property int padding: Theme.space.xs
    property int inputHeight: Theme.size.controlLg
    property int rowHeight: Theme.size.controlMd
    property int maxVisibleRows: 8
    property int headingHeight: Theme.size.controlSm
    property int radius: Theme.radius.md

    /** 面板宽度。>0 时定宽（命令面板通常定宽，避免筛选时抖） */
    property int panelWidth: 420

    /* ══════════════════════ 状态 ══════════════════════ */

    /** 高亮行的下标 —— 指向 `flatRows`（标题行也会被指到，但上/下键会跳开） */
    property int activeRow: 0

    /** 输入框有没有焦点（只用于画焦点态） */
    readonly property bool inputFocused: input.activeFocus

    /* ══════════════════════ 派生：筛选 ══════════════════════ */

    /** 筛过的分组，只保留还有条目的分组；组内保持声明序，组间保持声明序。
     *  每组里的条目带 `score` 与 `hits`（高亮用得上，本批不用）。 */
    readonly property var filteredGroups: root._filter(root.model, root.query)

    /** 展平成"标题行 + 条目行"喂给 ListView */
    readonly property var flatRows: root._flatten(root.filteredGroups)

    /** 活着的条目在 flatRows 里的下标（上/下键沿它走） */
    readonly property var itemRows: root._itemRows(root.flatRows)

    readonly property int matchCount: root.itemRows.length

    /** 高亮**实际落在**哪一行 —— 把 `activeRow` 沿"条目行"夹取之后的结果。
     *  夹取发生在**读**的时候：`activeRow` 可能指向一个被筛掉的标题行，
     *  而"哪一行被画成高亮"必须是一个可被断言的值。
     *  行代理只读这一个数（O(1)），不再各自去调 `_indexOfActive()`。 */
    readonly property int activeRowSafe: root._resolveActiveRow()

    /** 当前高亮的那一条条目行，找不到就是 null */
    readonly property var activeEntry: root._entryAt(root.activeRowSafe)

    /* ══════════════════════ 信号 ══════════════════════ */

    /** 用户触发了第 groupIndex 组的第 itemIndex 条（下标指向**原 model**） */
    signal selected(int groupIndex, int itemIndex, string text)

    /** 用户按了 Esc（面板自己不关 —— 关不关是宿主/对话框的事） */
    signal dismissed()

    /* ══════════════════════ 接口 ══════════════════════ */

    function clearQuery()  { root.query = "" }
    function focusInput()  { input.forceActiveFocus() }

    /** 触发当前高亮的那一条 */
    function activate() {
        var e = root.activeEntry
        if (e) root._emit(e)
    }

    /* ══════════════════════ 内部：纯计算 ══════════════════════ */

    /** 一条条目要拿去比对的文本：`text` 与 `keywords` 里取分高的那个 */
    function _scoreOf(query, item) {
        var best = null
        var t = (item && item.text !== undefined) ? String(item.text) : ""
        var r = FuzzyMatch.score(query, t)
        if (r) best = { score: r.score, hits: r.hits, on: "text" }

        if (item && item.keywords !== undefined && item.keywords !== null) {
            var kw = String(item.keywords)
            var r2 = FuzzyMatch.score(query, kw)
            if (r2 && (!best || r2.score > best.score))
                best = { score: r2.score, hits: r2.hits, on: "keywords" }
        }
        return best
    }

    function _filter(model, query) {
        var out = []
        if (!model) return out

        for (var g = 0; g < model.length; ++g) {
            var grp = model[g]
            if (!grp) continue

            var src = grp.items ? grp.items : []
            var kept = []
            for (var i = 0; i < src.length; ++i) {
                var it = src[i]
                if (!it) continue

                var r = root._scoreOf(query, it)
                if (!r) continue

                kept.push({
                    groupIndex: g,
                    itemIndex:  i,
                    text:       (it.text !== undefined) ? String(it.text) : "",
                    shortcut:   (it.shortcut !== undefined) ? String(it.shortcut) : "",
                    enabled:    it.enabled !== false,
                    danger:     it.danger === true,
                    score:      r.score,
                    hits:       r.hits,
                    matchedOn:  r.on
                })
            }

            if (kept.length === 0) continue

            /* 组内排序：空查询时**不排**（保持声明序 —— FuzzyMatch 的
             * 空查询语义就是"全量、原序"）。有查询时按分降序，
             * 并列保持声明序（`>` 而非 `>=`，与 FuzzyMatch.rank 同一条）。 */
            if (query.length > 0) {
                kept.sort(function (a, b) {
                    if (b.score !== a.score) return b.score - a.score
                    return a.itemIndex - b.itemIndex
                })
            }

            out.push({
                heading: (grp.heading !== undefined) ? String(grp.heading) : "",
                items:   kept
            })
        }
        return out
    }

    function _flatten(groups) {
        var rows = []
        if (!groups) return rows
        for (var g = 0; g < groups.length; ++g) {
            var grp = groups[g]
            if (grp.heading !== "")
                rows.push({ kind: "heading", heading: grp.heading, item: null })
            for (var i = 0; i < grp.items.length; ++i)
                rows.push({ kind: "item", heading: "", item: grp.items[i] })
        }
        return rows
    }

    function _itemRows(rows) {
        var out = []
        if (!rows) return out
        for (var i = 0; i < rows.length; ++i)
            if (rows[i].kind === "item") out.push(i)
        return out
    }

    /** 当前高亮落在第几个**条目行**里（下标指向 `itemRows`）。
     *  在**读**的时候夹取（而不是在 query 变化时改状态）——
     *  否则"清空查询"和"打字"两条路会走出不同的 `activeRow`。
     *  找不到（停在标题行上、或那一行被筛掉了）→ 退到第一条。 */
    function _activeItemRowIndex() {
        var rows = root.itemRows
        for (var k = 0; k < rows.length; ++k)
            if (rows[k] === root.activeRow) return k
        return rows.length > 0 ? 0 : -1
    }

    /** 高亮**实际落在**的 `flatRows` 下标；一条都没筛出来就是 -1。
     *  这是行代理唯一要读的数 —— 它拿 `rowSlot.index` 直接比一次。
     *  （上一版是"每行各遍历一遍 `itemRows`"，行数一多就是 O(n²)，
     *  而且那份遍历还把 `activeRow` 的语义抄了第二遍。） */
    function _resolveActiveRow() {
        var k = root._activeItemRowIndex()
        return k < 0 ? -1 : root.itemRows[k]
    }

    function _entryAt(flatIndex) {
        if (flatIndex < 0 || flatIndex >= root.flatRows.length) return null
        var row = root.flatRows[flatIndex]
        return row ? row.item : null
    }

    function _emit(entry) {
        if (!entry || entry.enabled === false) return
        root.selected(entry.groupIndex, entry.itemIndex, entry.text)
    }

    /** 上/下键：沿条目行走，跳过标题行，到头就停（不绕回） */
    function _step(delta) {
        var rows = root.itemRows
        if (rows.length === 0) return
        var k = root._activeItemRowIndex()
        if (k < 0) k = 0
        var next = Math.max(0, Math.min(rows.length - 1, k + delta))
        root.activeRow = rows[next]
    }

    /** 高亮行该画在哪 —— 纯计算，不读布局结果。
     *  标题行与条目行不等高，所以是"逐行累加"。 */
    function rowY(index) {
        var y = 0
        var rows = root.flatRows
        for (var i = 0; i < index && i < rows.length; ++i)
            y += (rows[i].kind === "heading") ? root.headingHeight : root.rowHeight
        return y
    }

    function listHeight() {
        var rows = root.flatRows
        var total = 0
        var shown = 0
        for (var i = 0; i < rows.length; ++i) {
            var h = (rows[i].kind === "heading") ? root.headingHeight : root.rowHeight
            if (rows[i].kind === "item") {
                if (shown >= root.maxVisibleRows) break
                shown++
            }
            total += h
        }
        return total
    }

    /* ══════════════════════ 几何 ══════════════════════ */

    implicitWidth:  root.panelWidth > 0 ? root.panelWidth : 360
    implicitHeight: root.padding * 2 + root.inputHeight + 1
                    + (root.matchCount > 0 ? root.listHeight() + root.padding
                                           : root.headingHeight * 2)

    /* ══════════════════════ 面板 ══════════════════════ */

    Rectangle {
        id: panel

        anchors.fill: parent
        radius: root.radius
        color: Theme.color.bgElevated
        border.width: 1
        border.color: Theme.color.border
    }

    /* ══════════════════════ 输入 ══════════════════════
     * 命令面板的输入框**天生无边框**（三家参照都是这样：它是面板内部的
     * 一行，而不是一个表单控件），所以这里不套 `inputBackground` 插槽 ——
     * 那格的契约是"带描边的输入底板"。底下一条分隔线走 divider 令牌。 */

    Item {
        id: inputBar

        x: root.padding
        y: root.padding
        width:  Math.max(0, root.width - root.padding * 2)
        height: root.inputHeight

        Text {
            id: placeholderText

            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.space.sm
            anchors.verticalCenter: parent.verticalCenter

            visible: input.text === ""
            text: root.placeholder
            elide: Text.ElideRight
            color: Theme.color.fgMuted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.md
        }

        TextInput {
            id: input

            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.space.sm
            anchors.verticalCenter: parent.verticalCenter

            clip: true
            color: Theme.color.fg
            selectionColor: Theme.color.brandSubtle
            selectedTextColor: Theme.color.fg
            font.family: Theme.font.family
            font.pixelSize: Theme.font.md
            /* 控件的 `query` 是**一个方向**的输入（宿主也可以程序化设它），
             * 而输入框的文字变化要回写 —— 只在 onTextChanged 里写，
             * 不把两边绑成互相覆盖的两条 binding。 */
            text: root.query

            onTextChanged: if (root.query !== text) root.query = text

            /* 键处理器写显式 `function(event)` —— 本仓既有写法
             * （QSkinInputNumber / QSkinCollapseItem 同款）。写成 `{ … }`
             * 的话 `event` 是个未限定访问，qmllint 会报。 */
            Keys.onDownPressed:   function(event) { root._step(1);            event.accepted = true }
            Keys.onUpPressed:     function(event) { root._step(-1);           event.accepted = true }
            Keys.onReturnPressed: function(event) { root.activate();          event.accepted = true }
            Keys.onEnterPressed:  function(event) { root.activate();          event.accepted = true }
            Keys.onEscapePressed: function(event) { root.dismissed();         event.accepted = true }
        }
    }

    Rectangle {
        id: inputDivider

        x: root.padding
        y: inputBar.y + inputBar.height
        width:  inputBar.width
        height: 1
        color: Theme.color.divider
    }

    /* ══════════════════════ 列表 ══════════════════════ */

    ListView {
        id: list

        visible: root.matchCount > 0

        x: root.padding
        y: inputDivider.y + inputDivider.height + root.padding
        width:  Math.max(0, root.width - root.padding * 2)
        height: root.listHeight()

        clip: true
        interactive: root.matchCount > root.maxVisibleRows
        model: root.flatRows
        boundsBehavior: Flickable.StopAtBounds

        /* 高亮行始终在视野里。用 contentY 直接算（不经动画），
         * 与 QSkinBackTop 同一条"目标位置是算出来的量"。 */
        onCountChanged: list._ensureVisible()
        onHeightChanged: list._ensureVisible()

        function _ensureVisible() {
            var fi = root.activeRowSafe
            if (fi < 0) return
            var y = root.rowY(fi)
            var h = root.rowHeight
            if (y < list.contentY) list.contentY = y
            else if (y + h > list.contentY + list.height)
                list.contentY = Math.min(list.contentHeight - list.height, y + h - list.height)
        }

        // qmllint disable unqualified
        /* 行代理 —— 与 `QSkinMenu` 的菜单行同一手法：**这一行自己**就是喂给
         * `Slots.label` 的伪控件（它读 `text` / `variant` / `labelAlignment`
         * / `enabled`，不声明 `iconSize` 所以不会被当成按钮宿主）。
         *
         * 上一版这里挂了一个**共享的** `QtObject` 当代理，两处都错：
         *   · 它是 `readonly property string text: ""` —— 每一行读到的
         *     都是空串（Binding 只改了一个没人读的 `_unused`）；
         *   · 一个代理喂所有行 —— 就算文字对了，也永远是同一份文字。
         * 而这件事**属性断言抓不到**（断言测的是 `filteredGroups`，
         * 不是画出来的那行字）—— 归渲染侧的像素核验管。
         */
        delegate: Item {
            id: rowSlot

            property int index
            property var modelData

            width:  list.width
            height: (rowSlot.modelData && rowSlot.modelData.kind === "heading")
                    ? root.headingHeight : root.rowHeight

            readonly property bool isHeading: rowSlot.modelData
                                              && rowSlot.modelData.kind === "heading"
            readonly property var  entry: rowSlot.modelData ? rowSlot.modelData.item : null
            readonly property bool isEnabled: !rowSlot.isHeading && rowSlot.entry !== null
                                              && rowSlot.entry.enabled !== false
            /* 高亮落在哪一行：**读一个数**就够（见 `_resolveActiveRow`） */
            readonly property bool isActive: !rowSlot.isHeading && rowSlot.entry !== null
                                             && rowSlot.index === root.activeRowSafe

            /* ── 伪装成"控件"给 Slots.label 读 ── */
            readonly property string text: rowSlot.entry && rowSlot.entry.text !== undefined
                                           ? String(rowSlot.entry.text) : ""
            /* danger 的命令（删除 / 清空之类）在**非按钮宿主**上取 danger 前景色，
             * 这是 `BasicLabel` 已有的分支（QSkinMenu 同款）。 */
            readonly property string variant: (rowSlot.entry && rowSlot.entry.danger === true)
                                              ? "danger" : "default"
            readonly property int labelAlignment: Text.AlignLeft

            opacity: rowSlot.isEnabled ? 1 : 0.4

            /* 高亮底 —— 标题行不给、被禁用的条目也不给 */
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Theme.radius.sm
                color: Theme.color.bgSunken
                visible: rowSlot.isActive && rowSlot.isEnabled
            }

            /* ── 分组标题 ── */
            Text {
                visible: rowSlot.isHeading
                anchors.left:  parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.space.sm
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.space.xxs
                text: rowSlot.modelData ? rowSlot.modelData.heading : ""
                elide: Text.ElideRight
                color: Theme.color.fgMuted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.xs
                font.weight: Theme.font.weightMedium
            }

            /* ── 条目文字 ── */
            Loader {
                id: entryLabel

                visible: !rowSlot.isHeading
                anchors.left:  parent.left
                anchors.right: shortcutText.left
                anchors.leftMargin: Theme.space.sm
                anchors.rightMargin: Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter

                sourceComponent: Slots.label

                Binding {
                    target: entryLabel.item
                    property: "control"
                    value: rowSlot
                    when: entryLabel.item !== null
                }
            }

            /* ── 右侧快捷键提示 ── */
            Text {
                id: shortcutText

                visible: !rowSlot.isHeading && rowSlot.entry !== null
                         && rowSlot.entry.shortcut !== ""
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter
                text: rowSlot.entry ? rowSlot.entry.shortcut : ""
                color: Theme.color.fgMuted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.xs
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                enabled: rowSlot.isEnabled

                onContainsMouseChanged: {
                    if (containsMouse) root.activeRow = rowSlot.index
                }
                onClicked: root._emit(rowSlot.entry)
            }
        }
        // qmllint enable unqualified
    }

    /* 空态 */
    Text {
        id: empty

        visible: root.matchCount === 0
        x: root.padding
        y: inputDivider.y + inputDivider.height
        width:  Math.max(0, root.width - root.padding * 2)
        height: root.headingHeight * 2

        text: root.emptyText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        color: Theme.color.fgMuted
        font.family: Theme.font.family
        font.pixelSize: Theme.font.sm
    }

    Component.onCompleted: Qt.callLater(root.focusInput)

    Accessible.role: Accessible.ComboBox
    Accessible.name: qsTr("命令面板")
    Accessible.onPressAction: root.focusInput()
}
