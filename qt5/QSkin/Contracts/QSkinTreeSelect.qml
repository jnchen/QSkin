/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinTreeSelect
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 树形选择：**一个输入框，点开是一棵树**。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 「缩进树」只有一份，它归 QSkinTree —— 本件复用其实例
 * ════════════════════════════════════════════════════════════════════════
 * COVERAGE.md 原来写着 TreeSelect 与 Cascader「共享一份缩进树」。落地时
 * 逐项核过，**那句话是错的**（M26 裁决一）：Cascader 是多列、同一列里所有
 * 节点层级相同，**没有缩进可画**。真实关系是两条：
 *
 *     共享的     TreeUtil 的**算路**（keyOf / childrenOf / flatten / columnsOf）
 *     不共享     **渲染**。缩进渲染只有 QSkinTree 一份（M17 落地）
 *
 * 所以本件**不自己画行**：把 `QSkinTree` 作为浮层内容注入。缩进量、chevron、
 * 展开、勾选列、键盘导航、点箭头不吃行选中 —— 那些全部只有一份实现，
 * 在这里一行都没有。将来「树的行该怎么画」改动时，只改一个地方。
 *
 * ── 与 QSkinCascader 的分工（用户视角）─────────────────────────────────
 *   本件：**一屏看到整棵树**，层级靠缩进。适合"深层级 + 想跳着选"。
 *   兄弟：**逐列展开**，每列只显示当前层。适合"选一条路径 + 中途改主意"。
 * 两者都会写 `value`，但本件的 value 是一个键，兄弟的是一串键。
 *
 * ── 分工（契约层内部）────────────────────────────────────────────────
 *   本文件：value / values 的语义、触发器回显（含路径）、搜索的展开定位、
 *           Popup 开合与翻转、Esc / 清空、Accessible.ComboBox
 *   插槽：  Slots.inputBackground（触发器底板）、Slots.label（回显文字）、
 *           Slots.chevronIndicator（箭头）、Slots.selectOverlay（浮层面板）
 *
 * ════════════════════════════════════════════════════════════════════════
 * 搜索的能力边界（写清楚，不夸大）
 * ════════════════════════════════════════════════════════════════════════
 * 打开 `showSearch` 后，输入会把**命中项的祖先链全部展开**、把当前节点移到
 * 第一个命中项、并滚到它。做的是三件事：
 *
 *     · 用 FuzzyMatch.filterBy 打分过滤（与 QSkinCommand 同一份打分）
 *     · 把命中项的祖先全展开（否则命中项藏在一个收起的分支里，看不见）
 *     · 展开集合是**并集**（不收起用户自己展开过的分支）
 *
 * **不做**"隐藏不匹配的节点"，也**不做**命中高亮。前者会把树变成一个
 * 筛过的列表（用户失去上下文与层级感）；后者需要在 QSkinTree 的行里加一层
 * 高亮渲染，而 QSkinTree 至今没有这个需求。两者都不是"忘了做"，是这一版的
 * 能力边界 —— 需要时再加，且加在 QSkinTree 上（所有树一起受益）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 值的语义：单选一个键、多选一串键
 * ════════════════════════════════════════════════════════════════════════
 *   multiple: false   写 `value`（单个键），读 `selectedKeys`（长度 0/1 的数组）
 *   multiple: true    写 `values`（键数组），多选时**不关面板**（要连着点）
 *
 * `selectedKeys` 是给调用方的**统一视图** —— 不必为了"取已选"先判断是不是
 * 多选。这在像素核验与主题测试里直接用得上（一处读，两种模式都能跑）。
 *
 * ── 多选为什么真的走 QSkinTree 的勾选（而不是"点了就加进数组"）──────────
 * 因为父子联动（`checkStrictly: false` 时的级联与半选）是六十行有前置条件的
 * 算路，QSkinTree 已经用 TreeUtil 实现了、也已被 M17 的测试钉住。自己再写一遍
 * 的结果是"树里勾选是级联的、下拉里不是" —— 同一个用户看到两套规则。
 *
 * ── 树的选择状态为什么**不**写成绑定 ─────────────────────────────────
 * `QSkinTree.selectedKeys` 是可写属性，它内部 `_commitKeys` 会**直接赋值**，
 * 一次赋值就把绑定打断。写成 `selectedKeys: root.values` 的后果是：用户点
 * 第一下之后绑定消失，此后程序改 `values` 树不再跟随 —— 一个"用一会儿才
 * 坏"的 bug。所以走 `_syncTreeSelection()` 显式同步（`QSkinSelect` 对
 * `currentIndex` 用的是同一个办法）。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
/* ⚠ **不要**给这一句加版本号 —— 带版本号会让 `Shape` 的
 * `preferredRendererType` 附加属性整个不可用（清空按钮的两条斜线
 * 会渲染成硬边阶梯）。同一条已在 `QSkinQRCode.qml` 记过。 */
import QtQuick.Shapes 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 树数据（对象数组；层级字段由 treeChildrenKey 指定） */
    property var    nodes: []
    property string treeKey: "id"
    property string treeChildrenKey: "children"
    property string textRole: ""

    /** 多选。true 时走树自己的勾选（含级联与半选） */
    property bool multiple: false
    /** 父子独立（不复选级联）。只有 multiple 时有意义 */
    property bool checkStrictly: false
    /** 初次展开全部。默认 true —— 下拉里"点开先看到全部"比"点开是空的"好 */
    property bool defaultExpandAll: true

    /* ══════════════════════ 值 ══════════════════════ */

    /** 单选：选中的键。`""` = 未选 */
    property var value: ""
    /** 多选：选中的键数组 */
    property var values: []

    /** 统一的只读视图 —— 单选与多选都能直接用 */
    readonly property var selectedKeys: {
        if (root.multiple)
            return (root.values === null || root.values === undefined) ? [] : root.values
        var v = root.value
        if (v === "" || v === null || v === undefined) return []
        return [v]
    }

    readonly property bool hasValue: root.selectedKeys.length > 0

    /* ══════════════════════ 文案 ══════════════════════ */

    property string placeholderText: qsTr("请选择")
    property string emptyText: qsTr("暂无数据")
    property string searchPlaceholderText: qsTr("搜索节点")
    /** 打开浮层顶部的过滤框 */
    property bool   showSearch: false
    /** 回显时带上从根到该节点的完整路径（用 separator 连接） */
    property bool   showPath: false
    property string separator: " / "
    /** 允许清空（悬停时触发器右侧出现 ×） */
    property bool   allowClear: true
    property bool   enabled: true

    /* ══════════════════════ 外观（供插槽 / 主题读）══════════════════════ */

    property int maxVisibleRows: 6
    property int rowHeight: Theme.size.controlMd
    property int padding: Theme.space.md
    /** 面板定宽。0 = 跟随控件宽度 */
    property int panelWidth: 0
    /** 搜索框高度 */
    property int searchHeight: Theme.size.controlSm

    /* ══════════════════════ 交互态（插槽读）══════════════════════ */

    property bool hovered: false
    property bool pressed: false
    property bool error: false

    /* ══════════════════════ 状态 ══════════════════════ */

    readonly property bool opened: popup.opened

    /** 触发器上显示的文字 */
    readonly property string text: {
        var ks = root.selectedKeys
        if (ks.length === 0) return ""
        if (!root.multiple || ks.length === 1) return root._labelOf(ks[0])
        return qsTr("%1 等 %2 项").arg(root._labelOf(ks[0])).arg(ks.length)
    }

    /* 触发器伪装成"控件"给 Slots.label 读 —— 与 QSkinSelect 同一套约定 */
    readonly property string variantName: "default"
    readonly property int    labelAlignment: Text.AlignLeft

    /** 供浮层外壳读（无 contentHeight 时按它估算） */
    readonly property int count: root._rowCount()

    /* ══════════════════════ 信号 ══════════════════════ */

    /** 随手点了一个节点。多选时每点一次都发；单选时紧接着会关闭面板 */
    signal nodeSelected(var node, var key)
    /** 选中集合变化（单选给长度 0/1 的数组） */
    signal selectionChanged(var keys)
    /** 搜索词变化 */
    signal searchChanged(string query)

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

    function open()   { if (root.enabled) popup.open() }
    function close()  { popup.close() }
    function toggle() { if (popup.opened) popup.close(); else popup.open() }

    /** 清空（单选清 value、多选清 values） */
    function clear() {
        if (!root.enabled) return
        if (root.multiple) {
            if (root.selectedKeys.length === 0) return
            root.values = []
            root.selectionChanged([])
        } else {
            if (root.selectedKeys.length === 0) return
            root.value = ""
            root.selectionChanged([])
        }
    }

    /* ══════════════════════ 全树索引 ══════════════════════
     *
     * 一次算出「键 → 节点」与「键 → 父键」两个映射，供回显路径与搜索的
     * 祖先链使用。**刻意全展开**（isExpanded 恒 true）：回显要的是"这个键
     * 的路径"，与树当前展开到哪儿无关 —— 用户收起某个分支，已经选中的项
     * 不该因此丢了路径。
     *
     * 两个映射放同一个函数里算，是因为它们必须**同源**：分两次 flatten，
     * 万一改了 opts 就会出现"路径按 A 棵树、父键按 B 棵树"的漂移。 */

    readonly property var _index: {
        var f = TreeUtil.flatten(root.nodes, {
            keyField:    root.treeKey,
            childrenKey: root.treeChildrenKey,
            isExpanded:  function() { return true }
        })
        var byKey = {}
        var parent = {}
        for (var i = 0; i < f.meta.length; ++i) {
            byKey[f.meta[i].key] = f.rows[i]
            parent[f.meta[i].key] = f.meta[i].parentKey
        }
        return { "byKey": byKey, "parent": parent }
    }

    /** 某个键从根到自身的标签数组；键不存在时给空数组 */
    function _pathOf(key) {
        var idx = root._index
        var out = []
        var k = (key === null || key === undefined) ? "" : String(key)
        var guard = 0
        while (k !== "" && idx.byKey[k] !== undefined && guard < 500) {
            out.unshift(TreeUtil.labelOf(idx.byKey[k], root.textRole))
            k = idx.parent[k]
        }
        return out
    }

    /** 回显文字：showPath 时给完整路径，否则只给节点自己的标签 */
    function _labelOf(key) {
        var parts = root._pathOf(key)
        if (parts.length === 0) return ""
        return root.showPath ? parts.join(root.separator) : parts[parts.length - 1]
    }

    /** 树的可见行数（浮层高度按它算） */
    function _rowCount() {
        return tree === null ? 0 : tree.visibleCount
    }

    /** 上报给外壳的**净内容高**（不含外壳自己的内边距） */
    function _panelContentHeight() {
        var h = 0
        if (root.showSearch) h += root.searchHeight
        var rows = Math.max(1, Math.min(root._rowCount(), root.maxVisibleRows))
        return h + rows * root.rowHeight
    }

    /** 把 `values` 灌进树。见文件头「树的选择状态为什么不写成绑定」
     *
     *  ⚠ 同步期间要挡住**回流**（`_syncing`）：树的 `setSelectedKeys` 会做
     *  级联闭包，然后 `keySelectionChanged` 把闭包报回来。程序化同步不是
     *  用户操作，把闭包写回 `values` 的后果是"我给的两个叶子被改写成四个"
     *  —— `values: ["hz","nb"]` 会变成 `["zj","hz","xh","nb"]`，回显也跟着
     *  从「杭州 等 2 项」变成「浙江 等 4 项」（M26 冒烟实测）。
     *  级联闭包该活的活在树上（勾选框画的是它），`values` 是**调用方给的
     *  那一份**。用户真的点了勾选时照旧回流。 */
    property bool _syncing: false

    function _syncTreeSelection() {
        root._syncing = true
        tree.setSelectedKeys(root.multiple ? root.selectedKeys : [])
        root._syncing = false
    }

    Component.onCompleted: root._syncTreeSelection()
    onValuesChanged:       root._syncTreeSelection()
    onMultipleChanged:     root._syncTreeSelection()

    /* ══════════════════════ 搜索 ══════════════════════ */

    function _runSearch(q) {
        var query = (q === null || q === undefined) ? "" : String(q)
        root.searchChanged(query)
        if (query === "") return

        var f = TreeUtil.flatten(root.nodes, {
            keyField:    root.treeKey,
            childrenKey: root.treeChildrenKey,
            isExpanded:  function() { return true }
        })
        var hits = FuzzyMatch.filterBy(query, f.rows, {
            textOf: function(n) { return TreeUtil.labelOf(n, root.textRole) }
        })
        if (hits.length === 0) return

        /* 命中项的祖先链 —— 不展开的话命中项藏在一个收起的分支里，
         * "搜到了但看不见"比"搜不到"更让人困惑 */
        var want = {}
        for (var i = 0; i < hits.length; ++i) {
            var cur = f.meta[hits[i].index].parentKey
            var guard = 0
            while (cur !== "" && cur !== undefined && cur !== null && guard < 500) {
                want[String(cur)] = true
                cur = root._index.parent[String(cur)]
            }
        }
        /* 并集：用户自己展开过的分支不收起（搜索是"帮我找"，不是"重排"）
         *
         * ⚠ 不能只并 `tree.expandedKeys` —— 那只是**被显式设置过**的键。
         * `defaultExpandAll: true` 时初始记录是空的，而界面明明全展开着，
         * 只并显式记录的结果是"搜一次就收起一大片"：可见行 5 → 4（M26
         * 冒烟实测，`setExpandedKeys` 会把不在表里的一律收起）。
         * 所以要问**有效**展开态 —— 遍历展平行问 `tree.isExpanded()`。 */
        for (var j = 0; j < f.rows.length; ++j) {
            var hk = f.meta[j].key
            if (tree.isExpanded(hk)) want[String(hk)] = true
        }

        var keys = []
        for (var k in want) if (want[k]) keys.push(k)
        tree.setExpandedKeys(keys)

        var first = f.meta[hits[0].index].key
        tree.currentKey = first
        tree.scrollToKey(first)
    }

    /* ══════════════════════ 触发器：底板 ══════════════════════ */

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

    /* ══════════════════════ 触发器：回显文字 ══════════════════════ */

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

    /* ══════════════════════ 触发器：清空 ══════════════════════
     *
     * 自绘两条交叉线（**不是**字符 "×" —— 项目的字符图标门禁按同一条规则
     * 扫全仓，QSkinTag 的 × 也是这么画的）。
     *
     * 为什么不给它开一格插槽：M26 裁决三定的是**零新增插槽**，而"清空按钮
     * 长什么样"在四家之间只有细微差别（线宽 / 圆钝）。裁决三的理由在这里
     * 成立 —— 它与所在控件同生共死，不是"主题会想换的东西"。
     * 真到了要换的那天再从 `buttonContent` 或新开一格，是增量改动。 */

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

    /* ══════════════════════ 触发器：展开箭头 ══════════════════════ */

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

    /* ══════════════════════ 触发器：点击 ══════════════════════ */

    MouseArea {
        id: triggerArea

        anchors.fill: parent
        /* 把 × 那一块让出去（它自己有 MouseArea）。不可见时不留空档，
         * 否则右侧那一条点不动 —— 一个只有悬停过才知道存在的死区。 */
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

    /* ══════════════════════ 浮层内容 ══════════════════════
     *
     * 一个「搜索框 + 一棵树」的竖条。`visible: false` 等着被 overlay 插槽
     * reparent 进面板 —— 在那之前显示出来的话会画在输入框内部
     * （与 QSkinSelect / QSkinMenu 同一套手法）。 */

    Item {
        id: panel

        visible: false
        anchors.fill: parent          /* reparent 后自动指向外壳的内容区 */
        implicitHeight: root._panelContentHeight()

        Item {
            id: searchBox

            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.top:   parent.top
            height: root.showSearch ? root.searchHeight : 0
            visible: root.showSearch

            Loader {
                id: searchBgLoader

                anchors.fill: parent
                sourceComponent: Slots.inputBackground

                Binding {
                    target: searchBgLoader.item
                    property: "control"
                    value: searchProxy
                    when: searchBgLoader.item !== null
                }
            }

            TextInput {
                id: searchInput

                anchors.fill: parent
                anchors.leftMargin:  Theme.space.sm
                anchors.rightMargin: Theme.space.sm
                verticalAlignment:   TextInput.AlignVCenter
                clip: true

                font.family:    Theme.font.family
                font.pixelSize: Theme.font.sm
                color:          Theme.color.fg
                selectByMouse:  true

                onTextChanged: root._runSearch(text)

                Keys.onDownPressed: function(event) {
                    event.accepted = true
                    tree.forceActiveFocus()
                    tree._moveCurrent(1)
                }
                Keys.onEscapePressed: function(event) {
                    event.accepted = true
                    if (searchInput.text !== "") searchInput.text = ""
                    else popup.close()
                }
            }

            Text {
                anchors.fill:        parent
                anchors.leftMargin:  Theme.space.sm
                anchors.rightMargin: Theme.space.sm
                verticalAlignment:   Text.AlignVCenter
                visible:             searchInput.text === ""
                text:                root.searchPlaceholderText
                font.family:         Theme.font.family
                font.pixelSize:      Theme.font.sm
                color:               Theme.color.fgMuted
                elide:               Text.ElideRight
                renderType:          Text.NativeRendering
            }
        }

        /* ── 树：**复用一个 QSkinTree 实例**，行渲染没有第二份 ── */
        QSkinTree {
            id: tree

            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    searchBox.bottom
            anchors.bottom: parent.bottom

            nodes:           root.nodes
            treeKey:         root.treeKey
            treeChildrenKey: root.treeChildrenKey
            textRole:        root.textRole
            emptyText:       root.emptyText
            rowHeight:       root.rowHeight
            padding:         Theme.space.xs
            maxHeight:       0                    /* 不限 —— 高度由外壳决定 */
            defaultExpandAll: root.defaultExpandAll
            enabled:         root.enabled

            /* 单选走"行高亮 + 点击"，多选走"勾选"（级联与半选只有一份实现） */
            selectable:    true
            checkable:     root.multiple
            checkStrictly: root.checkStrictly

            /* 刻意**不给**绑定 —— 见文件头那段说明。同步走 _syncTreeSelection() */
            selectedKeys: []

            onNodeClicked: function(node, key, level) {
                root.nodeSelected(node, key)
                if (!root.multiple) {
                    root.value = key
                    root.selectionChanged([key])
                    popup.close()
                }
            }

            onKeySelectionChanged: function(keys) {
                /* 程序化同步（`_syncTreeSelection`）报回来的级联闭包不回填 ——
                 * 那不是用户的操作，见 `_syncing` 那段说明。 */
                if (root._syncing) return
                root.values = keys
                root.selectionChanged(keys)
            }
        }
    }

    QtObject {
        id: searchProxy

        readonly property bool enabled:     root.enabled
        readonly property bool hovered:     false
        readonly property bool error:       false
        readonly property bool activeFocus: searchInput.activeFocus
    }

    /* ══════════════════════ 浮层 ══════════════════════ */

    readonly property var overlayItem: overlayLoader.item
    readonly property real overlayExtender: root.overlayItem !== null
        && root.overlayItem.extender !== undefined ? root.overlayItem.extender : 0

    Popup {
        id: popup

        y: root.flipUp ? (root.overlayExtender - popup.height - Theme.space.xs)
                       : (root.height + Theme.space.xs - root.overlayExtender)

        /* 面板宽度：panelWidth > 0 时定宽，否则跟随控件。
         * 注意**不能**依赖外壳的 implicitWidth（它按 control.width 取值），
         * 否则会形成 popup.width ↔ control.width 的循环引用 —— 这条是
         * QSkinMenu 在 M4 就记下来的（那份文件第 128 行）。 */
        width: root.panelWidth > 0 ? root.panelWidth : root.width
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
            if (root.showSearch) searchInput.forceActiveFocus()
            else                 tree.forceActiveFocus()
            var ks = root.selectedKeys
            if (ks.length > 0) tree.scrollToKey(ks[0])
        }
        onClosed: {
            root.pressed = false
            if (root.showSearch && searchInput.text !== "") searchInput.text = ""
        }
    }

    /* 外壳靠这几项决定面板高度。`contentHeight` 是 M5 契约扩展：
     * 本件的内容里有搜索框（与行不等高），旧公式「行数 × 行高」会漏掉它。 */
    QtObject {
        id: fakeControl

        readonly property int  count:          root.count
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

    Keys.onDownPressed: function(event) {
        event.accepted = true
        if (!popup.opened) popup.open()
        else               tree.forceActiveFocus()
    }
    Keys.onUpPressed: function(event) {
        event.accepted = true
        if (!popup.opened) popup.open()
        else               tree.forceActiveFocus()
    }
    Keys.onReturnPressed: function(event) {
        event.accepted = true
        if (!popup.opened) popup.open()
        else               tree._activateRow(tree.currentIndex)
    }
    Keys.onEnterPressed: function(event) {
        event.accepted = true
        if (!popup.opened) popup.open()
        else               tree._activateRow(tree.currentIndex)
    }
    Keys.onEscapePressed: function(event) {
        event.accepted = true
        if (popup.opened) popup.close()
        else              root.clear()
    }
}
