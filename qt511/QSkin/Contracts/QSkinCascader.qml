/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinCascader
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 级联选择：**逐列展开**，每列只显示当前层的兄弟节点。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 它为什么**不**复用 QSkinTree 的缩进树（与裁决一的原文对齐）
 * ════════════════════════════════════════════════════════════════════════
 * COVERAGE.md 原来写着本件与 QSkinTreeSelect「共享一份缩进树」。落地前逐项
 * 核过，那句话是错的，理由是一句几何事实：
 *
 *     本件同一列里**所有节点的层级完全相同** —— 没有缩进可画。
 *
 * 硬套缩进树会得到一个"每列都缩进"的东西（Ant / Element 的 Cascader 都
 * 不是那样）。所以真实关系分两条：
 *
 *     共享的     TreeUtil 的**算路**。本件用的是 `columnsOf`（M26 新增）
 *     不共享     **渲染**。缩进那套渲染归 QSkinTree；本件画的是若干并列的列
 *
 * ── 与 QSkinTreeSelect 的分工（用户视角）───────────────────────────────
 *   本件：**逐列展开**，一列一层。适合"选一条路径 + 途中改主意"。
 *   兄弟：**一屏整棵树**，层级靠缩进。适合"深层级 + 想跳着选"。
 * 两者都写 `value`，但本件的 value 是**一串键**，兄弟的是**一个键**。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 值的语义：一条**路径**，不是一个点
 * ════════════════════════════════════════════════════════════════════════
 *
 *     value = ["zj", "hz", "xh"]        浙江 / 杭州 / 西湖
 *
 * 于是三件事变成同一件事：
 *     · 回显      = 逐层取标签再 join(separator)
 *     · 展开态    = 这条路径本身（面板打开时按它铺开对应的列）
 *     · 校验      = 路径里任何一段不存在 → `columnsOf` **就地截断**，
 *                   回显自然短一段（不崩、不补全）
 *
 * 截断而不是报错，是 `TreeUtil.columnsOf` 的语义（那是纯函数，没有 UI 可供
 * 它喊人）。这里**不额外包装**成异常 —— 包装了会让"数据还没加载完"这种
 * 正常时序变成一次崩溃。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 两条**刻意的裁剪**（写出来，不假装完整）
 * ════════════════════════════════════════════════════════════════════════
 *
 * 1. **不做多选。** Ant 5.x 给 Cascader 加了 `multiple`，但 TDesign 与
 *    Arco 都没有，而它的形态与单选相差很大（每条路径要变成一枚可删的标签 +
 *    面板里要出现勾选框）。**没有第二个设计系统背书**又没有消费者 ——
 *    不做，而不是做个半截。（M24 的 `QRCode` 那次不同：三家都有。）
 *
 * 2. **展开只有 `click`，没有 `hover`。** Ant 默认 `hover`。不做是因为它与
 *    键盘导航有冲突：鼠标划过一列会把键盘刚建立的光标冲掉，而本项目所有
 *    浮层控件都要能被真鼠标事件测试。要加是一个 `expandTrigger` 属性 +
 *    行上挂 HoverHandler 的事，增量改动。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 焦点与键盘：面板自己持焦点，列**不**抢
 * ════════════════════════════════════════════════════════════════════════
 * 每列的 ListView 都 `focus: false`：它们**能滚**（内容溢出时），但**不收
 * 键盘**。键盘统一由面板 Item 处理（上下在列内、左右跨列、回车进入或提交）。
 * 这样"焦点在第几列"就只有一个来源（`_activeCol`），不会出现"视觉高亮在这
 * 一列、键盘打在那列"—— 那是这类控件最典型的坏味道。
 *
 * 鼠标划过某行会移动光标（`_setActive`）但**不动路径** —— "指到哪儿"与
 * "展开到哪儿"是两件事，混起来就会"鼠标路过一下把面板重排了"。
 ****************************************************************************/

import QtQuick 2.11
/* ── 这个别名 import 是为了拿到 QtQuick 那个**原生 positioner** `Row`。
 *
 * **M29 之后它已不是必需的，但保留** —— 理由分两层：
 *
 *   ① 历史（M29 之前）：`foundation/qmldir` 曾把 `Row` 与 `QSkinRow` 两个名字
 *      都注册到同一个文件上。本文件同时 import 了 QtQuick 与 QSkin.Foundation，
 *      裸名 `Row` 于是**恰好**解析成 QSkin 那个 —— 它有 `gap` / `padding` /
 *      `align` / `fill`、**没有 `spacing`**，内部还是 `RowLayout`（子项自己
 *      写的 `width:` 会被布局忽略）。要拿到原生 positioner 就得走别名，
 *      而且这条解析**没有任何东西在守**，能工作纯属运气。
 *   ② M29 起：qmldir 只注册 `QSkinRow` 一个名字，裸 `Row` **稳定**地指
 *      QtQuick 的 positioner，歧义消失（改名理由见 `foundation/qmldir`
 *      与 `CMakeLists.txt` 的模块头）。
 *
 * 换句话说：裸名现在也能用，但**别顺手改** —— 显式 `QQ.Row` 不依赖 import
 * 顺序，而改它要重拍本件的像素基线，那该由它自己的批次来做（同 COVERAGE
 * §四对"运行期警告那批文件本轮不动"的处置逻辑）。
 * `QtQuick.Row` 这种**前缀**写法在版本化 import 下不成立（实测报
 * "QtQuick is neither a type nor a namespace"），只有别名这一条路。
 * 先例是 `QSkinCarousel.qml` 的轨道，探针在 `.cache/_probe_m23row.qml`。
 * 同族还有 `QSkinButtonGroup` / `QSkinColorPicker` / `QSkinTransfer` / `QSkinUpload`
 * / `slots/BasicButtonContent` —— 它们各自文件里的记录与此段同源。 */
import QtQuick 2.11 as QQ
import QtQuick.Window 2.11
import QtQuick.Controls 2.4
/* ⚠ **不要**给这一句加版本号 —— 带版本号会让 `Shape` 的
 * `preferredRendererType` 附加属性整个不可用（斜边渲染成硬边阶梯）。
 * 同一条已在 `QSkinQRCode.qml` 记过，lint 的 Shape 段也会咬。 */
import QtQuick.Shapes 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    property var    nodes: []
    property string treeKey: "id"
    property string treeChildrenKey: "children"
    property string textRole: ""

    /* ══════════════════════ 值 ══════════════════════ */

    /** 选中的**路径**（键数组）。长度 0 = 未选；给字符串时按单层处理 */
    property var value: []

    /** 统一的只读视图（把"字符串当单层"这条兼容规则收在一处） */
    readonly property var valuePath: {
        var v = root.value
        if (v === null || v === undefined) return []
        if (typeof v === "string" || typeof v === "number") return v === "" ? [] : [v]
        return v
    }

    readonly property bool hasValue: root.valuePath.length > 0

    /** 回显文字（逐层取标签，用 separator 连接） */
    readonly property string text: root._labelsOfPath(root.valuePath).join(root.separator)

    /* ══════════════════════ 文案 ══════════════════════ */

    property string placeholderText: qsTr("请选择")
    property string emptyText: qsTr("暂无数据")
    property string separator: " / "
    /** 点中间层就提交（Ant 的 changeOnSelect）。false = 只有叶子能提交 */
    property bool   changeOnSelect: false
    property bool   allowClear: true
    property bool   enabled: true

    /* ══════════════════════ 外观 ══════════════════════ */

    property int maxVisibleRows: 7
    property int rowHeight: Theme.size.controlMd
    property int columnWidth: 160
    property int padding: Theme.space.md

    /* ══════════════════════ 交互态（插槽读）══════════════════════ */

    property bool hovered: false
    property bool pressed: false
    property bool error: false

    /* ══════════════════════ 状态 ══════════════════════ */

    readonly property bool opened: popup.opened

    /** 面板当前铺开的路径（内部状态）。开面板时从 `value` 起头 */
    property var _path: []
    /** 光标：第几列、列内第几行 */
    property int _activeCol: 0
    property int _activeRow: 0

    /** 各列的内容（TreeUtil.columnsOf —— 与 QSkinTree 共享同一份算路的入口） */
    readonly property var _cols: TreeUtil.columnsOf(root.nodes, root._path, {
        keyField:    root.treeKey,
        childrenKey: root.treeChildrenKey
    })

    readonly property int _colCount: Math.max(1, root._cols.length)

    /** 第一列是否为空（空态用） */
    readonly property bool _isEmpty: root._cols.length === 0
                                     || root._cols[0].nodes.length === 0

    /* 触发器伪装成"控件"给 Slots.label 读 */
    readonly property string variantName: "default"
    readonly property int    labelAlignment: Text.AlignLeft

    /* ══════════════════════ 信号 ══════════════════════ */

    /** 提交了一条路径。`labels` 是同时算好的回显分段 */
    signal picked(var keys, var labels)
    /** 光标在某列上停住了（鼠标划过或键盘移动时）*/
    signal activeChanged(int col, int row)
    signal selectionChanged(var keys)

    /* ══════════════════════ 尺寸 ══════════════════════ */

    implicitWidth:  220
    implicitHeight: Theme.size.controlMd

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true

    Accessible.role:     Accessible.ComboBox
    Accessible.name:     root.text !== "" ? root.text : root.placeholderText
    Accessible.editable: false
    Accessible.onPressAction: root.toggle()

    /* ══════════════════════ 接口 ══════════════════════ */

    function open() {
        if (!root.enabled) return
        root._path = root.valuePath.slice(0)
        root._activeCol = 0
        root._activeRow = 0
        popup.open()
    }
    function close()  { popup.close() }
    function toggle() { if (popup.opened) popup.close(); else root.open() }

    function clear() {
        if (!root.enabled) return
        if (!root.hasValue) return
        root.value = []
        root.selectionChanged([])
    }

    /* ══════════════════════ 算路 ══════════════════════ */

    /** 一条路径逐层的标签。路径里任何一段不存在 → `columnsOf` 就地截断，
     * 于是这里自然只回出前面几段（不崩、不补全） */
    function _labelsOfPath(path) {
        var cols = TreeUtil.columnsOf(root.nodes, path, {
            keyField:    root.treeKey,
            childrenKey: root.treeChildrenKey
        })
        var out = []
        for (var i = 0; i < cols.length; ++i) {
            var c = cols[i]
            if (c.activeIndex < 0) break
            out.push(TreeUtil.labelOf(c.nodes[c.activeIndex], root.textRole))
        }
        return out
    }

    /** 第 col 列里第 row 行的键；越界给 "" */
    function _keyAt(col, row) {
        var cols = root._cols
        if (col < 0 || col >= cols.length) return ""
        var c = cols[col]
        if (row < 0 || row >= c.keys.length) return ""
        return c.keys[row]
    }

    /** 第 col 列的节点数（夹光标用） */
    function _rowsInCol(col) {
        var cols = root._cols
        if (col < 0 || col >= cols.length) return 0
        return cols[col].nodes.length
    }

    /** 第 col 列里第 row 行的节点；越界给 null */
    function _nodeAt(col, row) {
        var cols = root._cols
        if (col < 0 || col >= cols.length) return null
        var c = cols[col]
        if (row < 0 || row >= c.nodes.length) return null
        return c.nodes[row]
    }

    /** 上报给外壳的净内容高：取**最长那一列**的行数（面板高度不该随光标跳） */
    function _panelContentHeight() {
        var cols = root._cols
        var rows = 1
        for (var i = 0; i < cols.length; ++i)
            rows = Math.max(rows, Math.min(cols[i].nodes.length, root.maxVisibleRows))
        return Math.max(1, rows) * root.rowHeight
    }

    /* ══════════════════════ 光标 ══════════════════════ */

    function _setActive(col, row) {
        var c = Math.max(0, Math.min(col, root._colCount - 1))
        var n = root._rowsInCol(c)
        var r = n === 0 ? 0 : Math.max(0, Math.min(row, n - 1))
        if (root._activeCol === c && root._activeRow === r) return
        root._activeCol = c
        root._activeRow = r
        root.activeChanged(c, r)
    }

    function _moveRow(dir) {
        if (root._rowsInCol(root._activeCol) === 0) return
        root._setActive(root._activeCol, root._activeRow + dir)
    }

    function _moveCol(dir) {
        root._setActive(root._activeCol + dir, root._activeRow)
    }

    /** 点了 / 回车了某一列某一行：有孩子就展开（并可选提交），没有就提交 */
    function _activate(col, row) {
        var node = root._nodeAt(col, row)
        if (node === null) return
        root._setActive(col, row)

        var cols = root._cols
        var kids = TreeUtil.childrenOf(node, root.treeChildrenKey)

        /* 路径 = 前面各列已定的键（activeIndex 非负的那些）+ 这一个 */
        var base = []
        for (var i = 0; i < col; ++i)
            if (cols[i].activeIndex >= 0) base.push(cols[i].keys[cols[i].activeIndex])

        var next = base.concat([cols[col].keys[row]])
        root._path = next

        if (kids.length > 0) {
            root._setActive(col + 1, 0)
            if (root.changeOnSelect) root._commit(next)
        } else {
            root._commit(next)
        }
    }

    function _commit(keys) {
        root.value = keys
        var labels = root._labelsOfPath(keys)
        root.selectionChanged(keys)
        root.picked(keys, labels)
        popup.close()
    }

    function _commitActive() {
        root._activate(root._activeCol, root._activeRow)
    }

    /* ══════════════════════ 触发器 ══════════════════════ */

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

    Item {
        id: textArea

        anchors.fill: parent
        anchors.leftMargin:  root.padding
        anchors.rightMargin: root.padding + caret.width + Theme.space.sm

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
            visible: root.text === "" && root.placeholderText !== ""

            text:  root.placeholderText
            font.family:    Theme.font.family
            font.pixelSize: Theme.font.sm
            color:          Theme.color.fgMuted
            elide:          Text.ElideRight
            renderType:     Text.NativeRendering
        }
    }

    /* 清空：自绘两条交叉线（与 QSkinTreeSelect 同一套做法，不开新插槽） */
    Item {
        id: clearBox

        visible: root.allowClear && root.hasValue && root.hovered && root.enabled
        width:  Theme.size.controlSm
        height: parent.height
        anchors.right: caret.left
        anchors.rightMargin: -Theme.space.xs

        Shape {
            id: cross

            anchors.centerIn: parent
            width:  Math.max(8, Math.round(Theme.font.sm * 0.62))
            height: width


            readonly property real sx: width
            readonly property real sy: height

            ShapePath {
                strokeColor: Theme.color.fgMuted
                strokeWidth: Math.max(1, Math.round(cross.sx * 0.13))
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                startX: cross.sx * 0.18
                startY: cross.sy * 0.18
                PathLine { x: cross.sx * 0.82; y: cross.sy * 0.82 }
            }
            ShapePath {
                strokeColor: Theme.color.fgMuted
                strokeWidth: Math.max(1, Math.round(cross.sx * 0.13))
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                startX: cross.sx * 0.82
                startY: cross.sy * 0.18
                PathLine { x: cross.sx * 0.18; y: cross.sy * 0.82 }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed:  root.pressed = true
            onReleased: root.pressed = false
            onClicked:  root.clear()
        }
    }

    Loader {
        id: caret

        anchors.right:       parent.right
        anchors.rightMargin: root.padding
        anchors.verticalCenter: parent.verticalCenter

        sourceComponent: Slots.chevronIndicator

        Binding {
            target: caret.item
            property: "control"
            value: caretProxy
            when: caret.item !== null
        }
    }

    QtObject {
        id: caretProxy

        readonly property string direction: root.opened ? "up" : "down"
        readonly property bool enabled: root.enabled
    }

    FocusRing { control: root }

    MouseArea {
        id: triggerArea

        anchors.fill: parent
        anchors.rightMargin: clearBox.visible ? clearBox.width : 0
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onEntered:  root.hovered = true
        onExited:   root.hovered = false
        onCanceled: root.pressed = false
        onReleased: root.pressed = false
        onPressed:  root.pressed = true
        onClicked:  root.toggle()
    }

    /* ══════════════════════ 浮层内容：若干并列的列 ══════════════════════ */

    Item {
        id: panel

        visible: false
        anchors.fill: parent
        focus: true

        Keys.onUpPressed:     function(event) { event.accepted = true; root._moveRow(-1) }
        Keys.onDownPressed:   function(event) { event.accepted = true; root._moveRow(1) }
        Keys.onLeftPressed:   function(event) { event.accepted = true; root._moveCol(-1) }
        Keys.onRightPressed:  function(event) { event.accepted = true; root._moveCol(1) }
        Keys.onReturnPressed: function(event) { event.accepted = true; root._commitActive() }
        Keys.onEnterPressed:  function(event) { event.accepted = true; root._commitActive() }
        Keys.onEscapePressed: function(event) { event.accepted = true; popup.close() }

        QQ.Row {
            id: colRow

            anchors.fill: parent
            spacing: 0

            /* ── 两层内联 delegate 的 unqualified 关闭 ─────────────────────
             * 本件**不**把 delegate 抽成顶层 Component（QSkinTree / QSkinSelect
             * 的写法），理由是作用域：单元格那一层引用了列那一层的
             * `colItem.index` / `colItem.colData`，而两者抽成**并列**的顶层
             * Component 之后，`colItem` 就不再在单元格的词法作用域里了 ——
             * 那是编译期解析失败，不是一条警告。留在同一个嵌套里，把关闭
             * 范围贴着 Repeater 即可。
             *
             * 注释首行不要以 qmllint 开头。 */
            // qmllint disable unqualified

            Repeater {
                model: root._cols.length

                delegate: Item {
                    id: colItem

                    property int index

                    readonly property var colData: root._cols[colItem.index]

                    width:  root.columnWidth
                    height: colRow.height
                    clip:   true

                    ListView {
                        id: colList

                        anchors.fill: parent
                        clip: true
                        focus: false            /* 焦点归面板 —— 见文件头 */
                        model: colItem.colData.nodes
                        currentIndex: -1
                        highlightMoveDuration: 0
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: cell

                            property int index

                            width:  colList.width
                            height: root.rowHeight

                            readonly property bool act: root._activeCol === colItem.index
                                                        && root._activeRow === cell.index
                            readonly property bool chosen:
                                colItem.colData.activeIndex === cell.index
                            readonly property var  node: colItem.colData.nodes[cell.index]
                            readonly property bool hasKids:
                                TreeUtil.childrenOf(cell.node, root.treeChildrenKey).length > 0

                            color: cell.act ? Theme.color.brandSubtle
                                            : (cell.chosen ? Theme.color.bgSubtle
                                                           : "transparent")

                            Loader {
                                id: cellLabel

                                anchors.left:  parent.left
                                anchors.right: parent.right
                                anchors.leftMargin:  Theme.space.sm
                                anchors.rightMargin: Theme.space.sm
                                            + (cell.hasKids ? Theme.font.md : 0)
                                anchors.verticalCenter: parent.verticalCenter

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

                                readonly property string text:
                                    TreeUtil.labelOf(cell.node, root.textRole)
                                readonly property string variant: cell.act ? "text" : "ghost"
                                readonly property int labelAlignment: Text.AlignLeft
                                readonly property bool enabled: root.enabled
                            }

                            /* 有孩子的行右侧一个朝右的箭头 —— 走同一格插槽，
                             * 于是"箭头长什么样"仍然只有一份答案 */
                            Loader {
                                id: kidCaret

                                visible: cell.hasKids
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.space.sm
                                anchors.verticalCenter: parent.verticalCenter

                                sourceComponent: Slots.chevronIndicator

                                Binding {
                                    target: kidCaret.item
                                    property: "control"
                                    value: rightProxy
                                    when: kidCaret.item !== null
                                }
                            }

                            QtObject {
                                id: rightProxy

                                readonly property string direction: "right"
                                readonly property bool enabled: root.enabled
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: root._setActive(colItem.index, cell.index)
                                onClicked: root._activate(colItem.index, cell.index)
                            }
                        }
                    }

                    /* 列之间一条竖线（最后一列不画）—— 用分隔线令牌，
                     * 于是它跟着主题走，而不是写死一个灰。 */
                    Rectangle {
                        visible: colItem.index < root._cols.length - 1
                        width: 1
                        height: parent.height
                        anchors.right: parent.right
                        color: Theme.color.divider
                    }
                }
            }

            // qmllint enable unqualified
        }

        Text {
            anchors.centerIn: parent
            visible: root._isEmpty
            text: root.emptyText
            font.family:    Theme.font.family
            font.pixelSize: Theme.font.sm
            color:          Theme.color.fgMuted
            renderType:     Text.NativeRendering
        }
    }

    /* ══════════════════════ 浮层 ══════════════════════ */

    readonly property var overlayItem: overlayLoader.item
    readonly property real overlayExtender: root.overlayItem !== null
        && root.overlayItem.extender !== undefined ? root.overlayItem.extender : 0

    Popup {
        id: popup

        y: root.flipUp ? (root.overlayExtender - popup.height - Theme.space.xs)
                       : (root.height + Theme.space.xs - root.overlayExtender)

        /* 面板宽 = 列数 × 列宽 + 外壳自己的左右内边距（外壳会把内容区
         * 再收掉 padding，于是内容区正好等于 列数 × 列宽）。
         * **定宽**，不走外壳的 implicitWidth —— 那条会与 control.width
         * 形成循环引用（QSkinMenu 在 M4 记过这笔）。 */
        width: root._colCount * root.columnWidth + root.themePadding * 2
        padding: root.overlayExtender

        background: Item {}

        contentItem: Loader {
            id: overlayLoader

            sourceComponent: Slots.selectOverlay

            Binding {
                target: overlayLoader.item
                property: "control"
                value: fakeControl
                when: overlayLoader.item !== null
            }
            Binding {
                target: overlayLoader.item
                property: "content"
                value: panel
                when: overlayLoader.item !== null
            }
        }

        contentWidth: width
        contentHeight: Math.max(overlayLoader.implicitHeight,
                                root.rowHeight + Theme.space.xs * 2)

        onOpened: {
            panel.forceActiveFocus()
            root._setActive(root.valuePath.length > 0 ? root.valuePath.length - 1 : 0, 0)
        }
        onClosed: root.pressed = false
    }

    /* 外壳在面板四周留的空白。**不能写死**：`BasicSelectOverlay.padding`
     * 是 `Theme.space.xs`，而主题可以改它（那是外观的一部分）。所以从外壳
     * 自己的实现里读同一个令牌 —— 比"抄一个数"少一处会漂的地方。 */
    readonly property int themePadding: Theme.space.xs

    QtObject {
        id: fakeControl

        readonly property int  count:          root._colCount * root.maxVisibleRows
        readonly property int  maxVisibleRows: root.maxVisibleRows
        readonly property int  rowHeight:      root.rowHeight
        readonly property real contentHeight:  root._panelContentHeight()
        readonly property real width:          popup.width
    }

    readonly property bool flipUp: {
        var win = Window.window
        if (!win) return false
        var gy    = root.mapToItem(win.contentItem, 0, 0).y
        var below = win.height - (gy + root.height)
        return below < popup.height + Theme.space.xs && gy > below
    }

    /* ══════════════════════ 键盘（触发器上）══════════════════════ */

    Keys.onDownPressed:   function(event) { event.accepted = true; if (popup.opened) panel.forceActiveFocus(); else root.open() }
    Keys.onUpPressed:     function(event) { event.accepted = true; if (popup.opened) panel.forceActiveFocus(); else root.open() }
    Keys.onReturnPressed: function(event) { event.accepted = true; if (popup.opened) root._commitActive(); else root.open() }
    Keys.onEnterPressed:  function(event) { event.accepted = true; if (popup.opened) root._commitActive(); else root.open() }
    Keys.onEscapePressed: function(event) {
        event.accepted = true
        if (popup.opened) popup.close()
        else              root.clear()
    }
}
