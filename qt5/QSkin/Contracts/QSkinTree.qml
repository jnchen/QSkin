/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinTree
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ════════════════════════════════════════════════════════════════════════
 * 树形控件。一维的：展平后的节点序列，一层贴一层往下排。
 * ════════════════════════════════════════════════════════════════════════
 *
 * 它和 QSkinTable 的树形模式（treeMode）共用**同一套树逻辑**，都在
 * `QSkin.Foundation.TreeUtil` 里（M17 下沉）。所以下面这些名字与 QSkinTable
 * 逐字相同 —— 不是巧合，是同一份语义：
 *
 *     treeKey / treeChildrenKey / defaultExpandAll / checkStrictly
 *     expandedKeys / isExpanded / setExpanded / toggleExpand
 *     expandAll / collapseAll / expandToggled
 *     selectedKeys / indeterminateKeys / isSelected / isIndeterminate
 *     setSelected / toggleSelected / setSelectedKeys / selectAll / clearSelection
 *     keySelectionChanged
 *
 * 换控件不用换词汇表，因为它们背后的算法是同一份。
 *
 * ── 与 QSkinTable 树形模式的三个刻意不同 ─────────────────────────────────
 *
 *   1. **数据入口叫 `nodes` 而不是 `rows`。**
 *      表格的 `rows` 对应的是"二维表里的一行"，树没有行、没有列，只有节点。
 *      为了跟表格对齐而沿用 `rows`，会让人以为这里能配 `columns`。
 *      一致性应该体现在**有共同语义**的地方（上面那一串），不是所有字段。
 *
 *   2. **多一个"当前节点"（`currentKey`）。**
 *      表格的 `selectedRow` 是行下标，树用不了（M14 的结论：展平后的下标
 *      会随折叠漂移）。这里按键记 —— 于是**折叠一个分支不会让游标指到
 *      别的节点上**，这正是 M14/M15 那两轮在表格上换来的结论，用在键盘
 *      导航上刚好合适。`currentKey` 是"指针停在哪"，与勾选（`selectedKeys`）
 *      是两件事：勾选回答"选中了什么"，current 回答"我现在在哪"。
 *
 *   3. **不画表头、不画列、不画分隔线。** 那是表格的骨架。
 *
 * ── 关于插槽：这是第一个"没动一格就装下"的控件家族（M17）─────────────
 *
 * Slots.qml 从 M1 起就写着五个家族：background / contentItem / indicator /
 * overlay / label。M17 之前，每个新控件都多少要动一下这份清单（M4 补
 * tabIndicator、M15.1 补 chevronIndicator、M8 的 Dialog 走令牌组合）。
 *
 * 树这次**一格没动**：
 *
 *     展开箭头   → Slots.chevronIndicator（M15.1 补的那一格，第二次被复用）
 *     勾选框     → Slots.checkIndicator
 *     节点文字   → Slots.label
 *     行底色     → 令牌组合（bgSunken / brandSubtle），与 QSkinTable 行同款
 *
 * 这条结果值得记下来：**M15.1 补 `chevronIndicator` 时，它的消费者只有
 * QSkinTable 一个**（而且是那一轮才接上的）。如果当时按"只有一个用家"的
 * 直觉跳过它，M17 就得再画一个箭头 —— 并且是第四种画法（前三种见
 * Slots.qml 文件头的清单）。
 *
 * 反过来说，什么事**会**需要新开一格：给树加"层级连接线"（Ant / Element
 * 的 showLine）。连接线是纯装饰、四种设计语言画法完全不同，那时候它就该
 * 是一个新插槽。M17 不做，但把话留在这里。
 *
 * ── 未包含（留给后续里程碑）────────────────────────────────────────────
 *   横向虚拟滚动（节点多时全量建 Item）、拖拽排序 / 拖拽移动节点、
 *   懒加载（异步 child）、节点连接线、搜索过滤高亮、
 *   多列（名称 + 备注 + 操作）、右键上下文菜单。
 *
 *   前四条是同一类：都需要先决定"节点被复用还是重建"，而 QSkinTree 目前
 *   与 QSkinTable 一样是**全量建 Item**（靠 clip 裁掉不可见的）。节点上千
 *   时会先卡在创建上，那时再谈虚拟化 —— 顺序反了会把简单问题变复杂。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 根节点数组。子节点挂在 `treeChildrenKey` 字段下，层级不限深 */
    property var nodes: []

    /** 节点唯一键字段名。展开状态与勾选都按它记 —— 不按结构路径：
     * 路径会随同级排序漂移，键不会。
     *
     * 节点上取不到该字段时回退到结构路径（前缀 "#"，如 "#0/2"）。
     * 此时**同级一排序展开状态就会跟着错位** —— 所以"节点必须带唯一 id"
     * 是使用方的约定，回退只是"数据没写 id"时不至于白屏的兜底。 */
    property string treeKey: "id"

    /** 子节点字段名 */
    property string treeChildrenKey: "children"

    /** 节点标签取哪个字段。为空时退化成 String(节点) */
    property string textRole: ""

    /** 没有任何节点时显示的文案 */
    property string emptyText: qsTr("暂无数据")

    /* ══════════════════════ 展开 ══════════════════════ */

    /** 还没被显式展开 / 收起过的节点，默认是否展开 */
    property bool defaultExpandAll: false

    /** 某个节点被展开 / 收起。`key` 是 treeKey 字段的值（取不到时是 "#路径"） */
    signal expandToggled(var key, bool expanded)

    /** 内部展开状态 { 键: true|false }。**只记录被显式设置过的**节点，
     * 没记录的取 `defaultExpandAll` —— 这样 expandAll / collapseAll 是
     * 落成显式状态，而"换数据后新出现的节点"仍然吃默认值，不需要任何
     * 重置逻辑。 */
    property var _expandState: ({})

    /** 已展开的键（无序数组）。非只读的批量写入请走 `setExpandedKeys()`：
     * 展开状态是一个**集合**，写成数组属性让它可读可写会引入"写一半"
     * 的中间态，而展平层读的正是它。 */
    readonly property var expandedKeys: {
        var out = []
        var st = root._expandState
        if (st === null || st === undefined) return out
        for (var k in st) if (st[k] === true) out.push(k)
        return out
    }

    /* ══════════════════════ 当前节点（行高亮）══════════════════════ */

    /** 是否响应点击 / 键盘的行高亮。关掉之后树变成纯展示 */
    property bool selectable: true

    /** 当前节点（"我停在哪"）。按键记，不按下标 —— 见文件头的说明 */
    property string currentKey: ""

    /** 点击了一个节点（不含点箭头 / 点勾选框）*/
    signal nodeClicked(var node, var key, int level)

    /* ══════════════════════ 勾选 ══════════════════════ */

    /** 是否显示勾选框。勾选走**键语义**（`selectedKeys`），与 `currentKey`
     * 是两件事：勾选回答"选中了什么"，current 回答"我正在看哪个"。 */
    property bool checkable: false

    /** 关掉级联与半选（父子独立，Ant / TDesign 的"父子不关联"）。 */
    property bool checkStrictly: false

    /** 完全选中的键。不变量：**父在集合 ⟺ 所有直接子都在集合**。
     * 半选的节点**不在其中**，见 `indeterminateKeys`。 */
    property var selectedKeys: []

    /** 是否禁止交互（灰色、不响应点击与键盘）。节点级禁用看 `disabledKeys` */
    property bool enabled: true

    /** 被禁用的节点键。禁用的节点不可勾、不可选中，但**能展开** ——
     * "点不开"和"不能选"是两回事，把展开也一起禁掉会让人以为控件坏了。 */
    property var disabledKeys: []

    /** 勾选集合变化（级联之后的完整数组，按树的前序排） */
    signal keySelectionChanged(var keys)

    /* ══════════════════════ 几何 ══════════════════════ */

    /** 行高。桌面端指针精度高，32 是可用的最小值；触屏请给 40+ */
    property int rowHeight: Theme.size.controlMd

    /** 每级缩进量 */
    property int indentWidth: Theme.space.lg

    /** 箭头位宽度。**叶子节点也占这个位** —— 否则同一层的兄弟文字左沿
     * 会不齐（M14 的教训，表格那边一样）。 */
    property int chevronWidth: Theme.font.md

    /** 勾选框位宽度（`checkable` 时才占） */
    property int checkColumnWidth: Theme.size.controlSm

    /** 缩进之后至少留给文字的宽度。缩到"再缩就没字了"就停住 ——
     * 与 `minColumnWidth` 同一条原则：宁可少缩进，也不让内容消失。 */
    property int minLabelWidth: 64

    /** 行左右内边距 */
    property int padding: Theme.space.md

    /** 行高亮的圆角。树的行是"一片一片"的，与表格的整片行不同 */
    property int radius: Theme.radius.md

    /** 最大高度。超过就在这里纵向滚动（0 = 不限制，按内容撑高） */
    property int maxHeight: 320

    /* ══════════════════════ 尺寸 ══════════════════════ */

    readonly property int _contentHeight: root.visibleCount * root.rowHeight

    readonly property int _viewHeight: root.maxHeight > 0
                                        ? Math.min(root._contentHeight, root.maxHeight)
                                        : (root.visibleCount > 0 ? root._contentHeight
                                                                 : root.rowHeight * 2)

    implicitWidth:  Math.round(Theme.size.controlSm * 8)      /* 192，只有下限意义 */
    implicitHeight: root._viewHeight

    activeFocusOnTab: true
    focus: false

    /* ══════════════════════ 无障碍 ══════════════════════ */

    Accessible.role: Accessible.List
    Accessible.name: qsTr("树形控件")

    /* ══════════════════════ 全树索引（TreeUtil）══════════════════════
     *
     * 与 `visibleRows` 是**两套并行的树视图**，职责刻意分开：
     *   受折叠影响、剪枝的   → visibleRows（渲染 / 键盘 / 滚动）
     *   不受折叠影响、全树的 → 就是它（勾选级联 / 祖先链 / 后代集）
     *
     * 合并它们会得到一个能跑但**语义错**的控件：折叠起来的分支不参与
     * 级联 —— 即"折叠会悄悄改变勾选结果"。这与 QSkinTable 那边是同一条
     * 不变量，同一个 TreeUtil 保证两边一致。 */
    readonly property var _treeIndex: {
        var src = root.nodes !== null && root.nodes !== undefined ? root.nodes : []
        return TreeUtil.index(src, root.treeKey, root.treeChildrenKey)
    }

    /* ══════════════════════ 可见行 ══════════════════════
     *
     * 展平一次，渲染 / 键盘 / 滚动全都读这一份。
     *
     * 元素形状：
     *   { node, key, level, parentKey, hasChildren, expanded }
     *
     * 每个可见行都要被渲染 **和** 被键盘问到，所以这里把 TreeUtil 的
     * `rows`（节点数组）与 `meta`（树信息）**按行合起来** —— 分成两个
     * 同序数组的话，每个渲染点都得自己对齐两份数组，而"两个数组错位一位"
     * 是那种看起来只是"高亮跳了一格"的错。 */
    readonly property var visibleRows: {
        var src = root.nodes !== null && root.nodes !== undefined ? root.nodes : []
        var f = TreeUtil.flatten(src, {
            keyField:    root.treeKey,
            childrenKey: root.treeChildrenKey,
            isExpanded:  function(k) { return root._isExpanded(k) }
        })
        var out = []
        for (var i = 0; i < f.rows.length; ++i) {
            var m = f.meta[i]
            out.push({ node: f.rows[i], key: m.key, level: m.level,
                       parentKey: m.parentKey, hasChildren: m.hasChildren,
                       expanded: m.expanded })
        }
        return out
    }

    /** 可见行数。**折叠的分支不算** —— 空态、内容高、滚动范围都按它算 */
    readonly property int visibleCount: root.visibleRows.length

    /** 当前节点在可见行里的位置；不在（或没有当前节点）给 -1。
     *
     * 这是个**派生量**，不存状态。存下来就会出现"折叠之后下标指到别人
     * 身上"——那正是 M14 判定 `selectedIndexes` 在树上不可用的原因。
     * 按键现查，代价是一次线性扫描（可见行数 = 屏幕上能看到的行数量级）。 */
    readonly property int currentIndex: {
        var rs = root.visibleRows
        var k = root.currentKey
        if (k === "" || k === undefined || k === null) return -1
        for (var i = 0; i < rs.length; ++i) if (rs[i].key === String(k)) return i
        return -1
    }

    /** 缩进上限 —— 只做减法，公式在 TreeUtil 里（表格按列宽调、树按控件宽
     * 调，同一条：宁可停止缩进，也不让文字被挤没） */
    readonly property int _indentLimit:
        TreeUtil.maxIndent(root.width - root._checkLead, root.padding,
                           root.chevronWidth, root.minLabelWidth)

    /** 勾选框占位（不显示时是 0，于是后面的文字自然左移） */
    readonly property int _checkLead: root.checkable ? root.checkColumnWidth : 0

    /** 某一层的缩进量（已夹到上限） */
    function _leadOf(level) {
        return root.padding
               + Math.min(level * root.indentWidth, root._indentLimit)
    }

    /** 节点标签文字。走 TreeUtil，与表格的取值口径一致 */
    function textOf(node) { return TreeUtil.labelOf(node, root.textRole) }

    /* ══════════════════════ 渲染 ══════════════════════ */

    Flickable {
        id: flick

        anchors.fill: parent

        contentWidth:  width
        contentHeight: root._contentHeight

        clip: true
        interactive: root._contentHeight > flick.height
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: rowHost

            width:  flick.width
            height: root._contentHeight

            Repeater {
                model: root.visibleCount
                delegate: treeRowComp
            }
        }

        /* 滚轮落在空白处也要能滚 —— Flickable 默认只认"内容上的"手势，
         * 而树的行是稀疏的（行宽铺满，但内容区可能比视口窄）。
         * 用 WheelHandler 显式接管，行为与 QSkinTable 的固定区一致。 */
        WheelHandler {
            onWheel: function(ev) {
                flick.contentY = root._clampScrollY(flick.contentY - ev.angleDelta.y)
            }
        }
    }

    /** 空状态：居中。放 Flickable 外面 —— 放里面会跟着内容滚 */
    Text {
        anchors.centerIn: parent
        text: root.emptyText
        visible: root.visibleCount === 0
        font.family:    Theme.font.family
        font.pixelSize: Theme.font.sm
        color: Theme.color.fgMuted
        renderType: Text.NativeRendering
    }

    /* 键盘焦点环。树是"整块可聚焦"的（不是每个节点一个焦点）——
     * 这是桌面树的通行做法，也是 Accessible 只上报 ListItem 的原因。 */
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: root.activeFocus ? Theme.size.focusRing : 0
        border.color: Theme.color.focus
        radius: root.radius
        visible: root.activeFocus
        z: 10
    }

    /* ══════════════════════ 悬停 ══════════════════════ */

    /** 悬停行下标。-1 = 没有。提到 root 上而不是行里各自记 ——
     * 与 QSkinTable 同一条理由：行是可复用的委托，状态挂在行上会在
     * 重建时丢失，表现为"鼠标没动但高亮跳走了"。 */
    property int _hoverIndex: -1

    /* ══════════════════════ 展开 API ══════════════════════ */

    /** 某个键当前是否展开。没被显式设置过 → 吃 `defaultExpandAll` */
    function isExpanded(key) { return root._isExpanded(key) }

    function _isExpanded(key) {
        var st = root._expandState
        var s = (st !== null && st !== undefined) ? st[String(key)] : undefined
        return s === undefined ? root.defaultExpandAll : s === true
    }

    /** 展开 / 收起一个节点。状态本来就一致时**既不写状态也不发信号**
     * （与 QSkinTable 的同名函数一条约定：免得把无变化的操作也广播出去）。 */
    function setExpanded(key, expanded) {
        if (key === undefined || key === null) return
        var k = String(key)
        var on = expanded === true
        if (root._isExpanded(k) === on) return

        /* 整份换新对象而不是原地改：原地改**不会触发绑定重算**
         * （与 Theme.patch 同一条教训 —— `_expandState` 被 visibleRows
         * 的绑定读着，原地改等于让界面停在旧状态） */
        var next = {}
        var st = root._expandState
        for (var p in st) next[p] = st[p]
        next[k] = on
        root._expandState = next
        root.expandToggled(k, on)
    }

    function toggleExpand(key) { root.setExpanded(key, !root._isExpanded(key)) }

    /** 全展开 / 全收起。落成**显式状态**（不是改默认值）——
     * 否则之后新增的节点会因为"没被记录"而吃 `defaultExpandAll`，
     * 表现为"点了全收起，插进来一个新根节点它却是展开的"。 */
    function expandAll()   { root._setAllExpanded(true) }
    function collapseAll() { root._setAllExpanded(false) }

    function _setAllExpanded(on) {
        var src = root.nodes !== null && root.nodes !== undefined ? root.nodes : []
        var keys = TreeUtil.allKeys(src, root.treeKey, root.treeChildrenKey)
        var next = {}
        for (var i = 0; i < keys.length; ++i) next[keys[i]] = on
        root._expandState = next
    }

    /** 整份设定展开集合（不在 keys 里的一律收起） */
    function setExpandedKeys(keys) {
        var src = root.nodes !== null && root.nodes !== undefined ? root.nodes : []
        var all = TreeUtil.allKeys(src, root.treeKey, root.treeChildrenKey)
        var want = TreeUtil.keySet(keys)
        var next = {}
        for (var i = 0; i < all.length; ++i) next[all[i]] = want[all[i]] === true
        root._expandState = next
    }

    /* ══════════════════════ 勾选 API ══════════════════════
     *
     * 与 QSkinTable 的树形勾选同名同语义（同一份 TreeUtil 实现）。
     * QSkinTree 上 `checkStrictly` 一起作用，除此之外**没有平铺模式** ——
     * 树控件只有树，不存在"下标寻址"那套分叉。 */

    readonly property var _keySet: TreeUtil.keySet(root.selectedKeys)

    readonly property var _subtreeHasChecked: {
        if (root.checkStrictly) return {}
        return TreeUtil.subtreeHasChecked(root._treeIndex, root._keySet)
    }

    /** **半选**的键，按树的前序排好。半选 = 自己没被完全选中、但子树里
     * 有被完全选中的节点。叶子永远不在这里。`checkStrictly` 下恒空。 */
    readonly property var indeterminateKeys: {
        if (root.checkStrictly) return []
        return TreeUtil.indeterminateKeys(root._treeIndex, root._keySet,
                                          root._subtreeHasChecked)
    }

    /** 被**完全选中**的节点对象（半选的祖先不在其中 —— 要半选读
     * `indeterminateKeys`）。这是"想直接拿数据"时的出口。 */
    readonly property var selectedRows:
        TreeUtil.rowsOfKeys(root._treeIndex, root.selectedKeys)

    /** 已完全选中的节点数。筛掉数据里已不存在的陈旧键 ——
     * 否则换了数据之后"全选"会一直亮着。 */
    readonly property int checkedCount:
        TreeUtil.countExisting(root._keySet, root._treeIndex)

    readonly property bool allChecked:
        root._treeIndex.count > 0 && root.checkedCount >= root._treeIndex.count
    readonly property bool someChecked: root.checkedCount > 0 && !root.allChecked

    /** 某个键是否**完全选中**（它自己 + 全部后代都在集合里） */
    function isSelected(key) {
        if (key === undefined || key === null) return false
        return root._keySet[String(key)] === true
    }

    /** 某个键是否**半选**。`checkStrictly` 下恒 false */
    function isIndeterminate(key) {
        if (key === undefined || key === null) return false
        var k = String(key)
        if (root._keySet[k] === true) return false
        return root._subtreeHasChecked[k] === true
    }

    /** 节点是否被禁用 */
    function isDisabled(key) {
        if (key === undefined || key === null) return false
        var d = root.disabledKeys
        if (d === null || d === undefined) return false
        return d.indexOf(String(key)) >= 0
    }

    /** 勾 / 取消一个节点。**默认级联**：它自己 + 全部后代设成同一状态，
     * 然后自下而上重算祖先的"完全选中" */
    function setSelected(key, selected) {
        if (key === undefined || key === null) return
        if (!root.enabled || root.isDisabled(key)) return
        var idx = root._treeIndex
        var k = String(key)
        if (idx.byKey[k] === undefined) return
        var on = selected === true

        if (root.checkStrictly) {
            /* 严格模式：只动自己，也不重算祖先（祖先状态与子无关） */
            if ((root._keySet[k] === true) === on) return
            var s0 = TreeUtil.cloneSet(root._keySet)
            if (on) s0[k] = true
            else    delete s0[k]
            root._commitKeys(s0, idx)
            return
        }

        var next = TreeUtil.cloneSet(root._keySet)
        TreeUtil.applyCascade(idx, k, on, next)
        TreeUtil.refreshAncestorsOf(idx, k, next)
        root._commitKeys(next, idx)
    }

    /** 切换一个节点。**半选 → 全选** —— 与 QSkinCheckBox 的通用约定一致
     * （半选状态下点击进全选，而不是跳到空选）。
     *
     * 判据只有 `!isSelected(key)`。半选的节点**本来就不在集合里**，
     * 所以"在不在集合"已经足够区分半选与全选 —— 把 `isIndeterminate`
     * 也或进去会把半选算成"要取消"，变成点一下清空。
     * 详见 QSkinTable 同名函数上的三段状态推演（那个 bug 从 M15 潜伏到 M17）。 */
    function toggleSelected(key) {
        root.setSelected(key, !root.isSelected(key))
    }

    /** 整份设定选中键，并做**级联闭包**：给了父 → 后代自动补进来；
     * 给了全部直接子 → 父自动补上来；数据里不存在的键直接丢弃。
     * 传 null / [] 即清空。 */
    function setSelectedKeys(keys) {
        var idx = root._treeIndex
        root._commitKeys(TreeUtil.normalize(idx, keys, root.checkStrictly), idx)
    }

    /** 全选（所有根全选 → 级联自动带下全部后代） */
    function selectAll() {
        var idx = root._treeIndex
        var set = {}
        for (var i = 0; i < idx.roots.length; ++i)
            TreeUtil.applyCascade(idx, idx.roots[i], true, set)
        root._commitKeys(set, idx)
    }

    /** 清空勾选 */
    function clearSelection() { root._commitKeys({}, root._treeIndex) }

    /** 提交新集合：转数组 → 没变就不写 → 变了就写并发信号 */
    function _commitKeys(set, idx) {
        var arr = TreeUtil.keysToArray(set, idx)
        if (TreeUtil.sameKeys(root.selectedKeys, arr)) return
        root.selectedKeys = arr
        root.keySelectionChanged(arr)
    }

    /* ══════════════════════ 滚动 ══════════════════════
     *
     * `Flickable.contentY` 在 Flickable **自己**滚的时候会自动夹在合法
     * 范围内，外部赋值却不会 —— 直接写会冲出边界，而且因为 StopAtBounds
     * 它不会自己弹回来（M13 的教训）。凡是从函数里写一律过这道钳制。 */

    function _clampScrollY(v) {
        var max = Math.max(0, flick.contentHeight - flick.height)
        return Math.max(0, Math.min(v, max))
    }

    /** 把第 i 行滚进视野（已经在视野里就不动）。键盘导航用 */
    function _scrollIntoView(i) {
        var top  = i * root.rowHeight
        var bot  = top + root.rowHeight
        var view = flick.height
        if (top < flick.contentY)                     flick.contentY = root._clampScrollY(top)
        else if (bot > flick.contentY + view)         flick.contentY = root._clampScrollY(bot - view)
    }

    /** 把某个键对应的节点滚进视野（节点不在可见行里则什么都不做） */
    function scrollToKey(key) {
        var k = String(key)
        var rs = root.visibleRows
        for (var i = 0; i < rs.length; ++i)
            if (rs[i].key === k) { root._scrollIntoView(i); return }
    }

    /* ══════════════════════ 交互 ══════════════════════ */

    /** 选中一个可见行（点击 / 键盘共用） */
    function _activateRow(i) {
        var rs = root.visibleRows
        if (i < 0 || i >= rs.length) return
        var r = rs[i]
        if (root.isDisabled(r.key)) return
        root.currentKey = r.key
        root.nodeClicked(r.node, r.key, r.level)
    }

    /* ── 键盘 ──
     *
     * 全部**按键寻址**，不按下标：折叠一个分支之后，光标仍然停在同一个
     * 节点上（而不是同一个下标上）。这是 M14/M15 的结论在键盘上的翻版。
     *
     * 上下移动、左右展开/收起是桌面树的常规操作；空格切勾选；
     * 回车等同点击。左右键在"没有可展开/可收起的东西"时退化成移动 ——
     * 这是 Windows 资源管理器与 macOS Finder 的共同行为。 */

    Keys.onUpPressed:    root._moveCurrent(-1)
    Keys.onDownPressed:  root._moveCurrent(1)
    Keys.onLeftPressed:  root._collapseOrParent()
    Keys.onRightPressed: root._expandOrChild()

    Keys.onSpacePressed: {
        var i = root.currentIndex
        if (root.checkable && i >= 0) root.toggleSelected(root.visibleRows[i].key)
    }
    Keys.onReturnPressed: root._activateRow(root.currentIndex)
    Keys.onEnterPressed:  root._activateRow(root.currentIndex)

    function _moveCurrent(dir) {
        if (!root.selectable) return
        var rs = root.visibleRows
        if (rs.length === 0) return
        var i = root.currentIndex
        /* 没有当前节点时：向下从第一行开始，向上从最后一行开始 ——
         * 比"什么都不做"更符合"按一下就进入列表"的直觉 */
        var next = i < 0 ? (dir > 0 ? 0 : rs.length - 1) : i + dir
        next = Math.max(0, Math.min(next, rs.length - 1))
        root.currentKey = rs[next].key
        root._scrollIntoView(next)
    }

    function _expandOrChild() {
        var i = root.currentIndex
        if (i < 0) return
        var rs = root.visibleRows
        var r = rs[i]
        if (r.hasChildren && !r.expanded) { root.setExpanded(r.key, true); return }
        /* 已经展开 → 进第一个子节点。前序展平里"第一个子"就是下一行，
         * 所以这一步不需要去问结构，也不会问错 */
        if (r.hasChildren && i + 1 < rs.length) {
            root.currentKey = rs[i + 1].key
            root._scrollIntoView(i + 1)
        }
    }

    function _collapseOrParent() {
        var i = root.currentIndex
        if (i < 0) return
        var rs = root.visibleRows
        var r = rs[i]
        if (r.hasChildren && r.expanded) { root.setExpanded(r.key, false); return }
        if (r.parentKey === "") return
        /* 父节点一定在可见行里、且一定在本行**上方**（前序展平：
         * 父先于子被写出）—— 所以往回扫一定先遇到它。
         * 这也说明为什么不需要立刻停：中间的兄弟行会被跳过。 */
        for (var j = i - 1; j >= 0; --j) {
            if (rs[j].key === r.parentKey) {
                root.currentKey = rs[j].key
                root._scrollIntoView(j)
                return
            }
        }
    }

    /* ══════════════════════ 行委托 ══════════════════════
     *
     * 引用了外层 id（root / Slots）—— inline Component 的静态检查局限，
     * 与 QSkinTable / QSkinSelect 的 delegate 同款，局部关闭即可。
     * 注释首行不要以 qmllint 开头。 */
    // qmllint disable unqualified

    Component {
        id: treeRowComp

        Item {
            id: trow

            required property int index

            /* 裸 Item 宿主（rowHost）**不会**自动排布子项 —— 那是 Column 的活。
             * 行的纵向位置必须自己声明，见 QSkinTable 的 rowComp 同款一行。
             *
             * 这一行是 M17 抓图抓出来的：8 条属性断言全绿（visibleCount = 11、
             * visibleRows 每一行的 node / key / level 都对），而屏幕上 11 行
             * **全部叠在第 0 行上** —— 文字糊成一团黑。属性值对 ≠ 界面画对，
             * 这是本项目第 5 次撞同一面墙（M14 记过 6 处渲染点漏 1 处）。 */
            y:      trow.index * root.rowHeight

            /* 宽度取 parent.width —— 行的宿主就是滑动的 rowHost，
             * 于是"行宽 = 视口宽"自动成立 */
            width:  parent.width
            height: root.rowHeight

            /** 本行的展平信息。`visibleRows` 是按行合好的结构（见其注释） */
            readonly property var row: index < root.visibleRows.length
                                      ? root.visibleRows[index] : null

            readonly property string nodeKey: row !== null ? row.key : ""
            readonly property bool   expanded:    row !== null && row.expanded
            readonly property bool   hasChildren: row !== null && row.hasChildren
            readonly property bool   nodeDisabled: root.isDisabled(nodeKey)

            /** 悬停态提到 root 上（root._hoverIndex）而不是行里各自记 ——
             * 行是复用委托，状态挂在行上会在重建时丢失 */
            readonly property bool hovered: root._hoverIndex === index

            readonly property bool isCurrent: root.currentKey !== ""
                                              && root.currentKey === trow.nodeKey
            readonly property bool checked:       root.isSelected(trow.nodeKey)
            readonly property bool indeterminate: root.isIndeterminate(trow.nodeKey)

            /** 内容起点（含内边距与层级缩进，已夹到上限） */
            readonly property int lead: root._leadOf(row !== null ? row.level : 0)
            readonly property int chevronX: trow.lead
            readonly property int checkX:   trow.lead + root.chevronWidth
            readonly property int labelX:   trow.checkX + root._checkLead

            Accessible.role: Accessible.ListItem
            Accessible.name: root.textOf(trow.row !== null ? trow.row.node : null)
            Accessible.selected: trow.isCurrent
            Accessible.checked: root.checkable && trow.checked
            Accessible.checkable: root.checkable
            Accessible.onPressAction: root._activateRow(trow.index)

            /* ── 行底色 ──
             * 当前行（brandSubtle）优先于悬停（bgSunken）：两者同时成立时
             * 让人看到"我选的是这个"，而不是"我鼠标划过的那个"。
             * 与 QSkinTable 的行底色同一组令牌。 */
            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: trow.isCurrent ? Theme.color.brandSubtle : Theme.color.bgSunken
                visible: trow.isCurrent || trow.hovered
                Behavior on color {
                    ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
                }
            }

            /* ── 展开箭头 ──
             * 声明在行 MouseArea **之前** 也要有热区，所以这里结构是：
             * 先把视觉摆好、MouseArea 分层次声明（行 → 勾选框 → 箭头），
             * 同级后声明的在上层，点击先落到最上层。 */
            Item {
                id: chevronBox

                x: trow.chevronX
                y: 0
                width: root.chevronWidth
                height: trow.height

                /* 不写宽高：Loader 会自己去取条目的 implicitWidth/Height。
                 * 尺寸由**插槽**决定（图标多大本来就是主题差异之一），
                 * 宿主只负责把它居中 —— 与 QSkinTable 的箭头同款。 */
                Loader {
                    id: chevronLoader

                    anchors.centerIn: parent

                    /* 叶子节点**不画箭头**，但占位照样保留（chevronBox
                     * 的宽度不变）—— 同一层兄弟的文字左沿才会齐。 */
                    visible: trow.hasChildren
                    sourceComponent: trow.hasChildren ? Slots.chevronIndicator : null

                    Binding {
                        target: chevronLoader.item
                        property: "control"
                        value: chevronProxy
                        when: chevronLoader.item !== null
                    }
                }

                QtObject {
                    id: chevronProxy

                    /** 展开 → "down"，收起 → "right"。
                     * **展开语义不进插槽**：控件自己把状态翻译成方向，
                     * 插槽只回答"朝右的箭头长什么样"（M15.1 的契约）。 */
                    readonly property string direction: trow.expanded ? "down" : "right"
                    readonly property bool enabled: !trow.nodeDisabled && root.enabled
                }
            }

            /* ── 勾选框 ── */
            Item {
                id: checkBox

                visible: root.checkable
                x: trow.checkX
                y: 0
                width: root.checkColumnWidth
                height: trow.height

                Loader {
                    id: checkLoader

                    anchors.centerIn: parent
                    sourceComponent: Slots.checkIndicator

                    Binding {
                        target: checkLoader.item
                        property: "control"
                        value: checkProxy
                        when: checkLoader.item !== null
                    }
                }

                QtObject {
                    id: checkProxy

                    readonly property bool checked:       trow.checked
                    readonly property bool indeterminate: trow.indeterminate
                    readonly property bool enabled: !trow.nodeDisabled && root.enabled
                    readonly property bool hovered: trow.hovered
                }
            }

            /* ── 节点文字 ──
             * 走共用的 label 插槽（与按钮 / 菜单项 / 表格单元格同一个）。
             * 宿主是"透明行"，所以 variant 用默认值 → 前景色。 */
            Loader {
                id: labelLoader

                x: trow.labelX
                y: 0
                width:  Math.max(0, trow.width - trow.labelX - root.padding)
                height: trow.height

                sourceComponent: Slots.label

                Binding {
                    target: labelLoader.item
                    property: "control"
                    value: labelProxy
                    when: labelLoader.item !== null
                }
            }

            QtObject {
                id: labelProxy

                readonly property string text: root.textOf(trow.row !== null ? trow.row.node : null)
                /* 默认前景色。当前行**不**换成品牌色 —— 那是把"选中该长什么样"
                 * 这个视觉决策写进控件；行底色（brandSubtle）已经表达了它，
                 * 而颜色本身属于主题。要品牌色文字，改 label 插槽的取值规则。 */
                readonly property string variant: "default"
                readonly property int labelAlignment: Text.AlignLeft
                readonly property bool enabled: !trow.nodeDisabled && root.enabled
            }

            /* ── 热区（自下而上三层）──
             * 行 → 勾选框 → 箭头。同级后声明的在上层，所以：
             *   · 点箭头只切换展开，不会顺手把行也选中
             *   · 点勾选框只切勾选，不会把行也选中
             *   · 其余位置点行 = 选中
             * 少了这个顺序，症状是"点箭头反而选中了行"（M14 踩过）。 */
            MouseArea {
                anchors.fill: parent
                enabled: root.enabled && root.selectable
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onPositionChanged: root._hoverIndex = trow.index
                onEntered: root._hoverIndex = trow.index
                onExited:  if (root._hoverIndex === trow.index) root._hoverIndex = -1

                onClicked: {
                    root.forceActiveFocus()
                    root._activateRow(trow.index)
                }
                /* 双击展开 / 收起 —— 桌面树的通行做法（资源管理器 / Finder）。
                 * 双击必然先触发两次单击，所以"选中 + 展开"会一起发生，
                 * 这正是想要的结果。 */
                onDoubleClicked: {
                    if (trow.hasChildren) root.toggleExpand(trow.nodeKey)
                }
            }

            MouseArea {
                x: checkBox.x
                y: 0
                width:  root.checkColumnWidth
                height: trow.height
                visible: root.checkable
                enabled: root.enabled && !trow.nodeDisabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    root.forceActiveFocus()
                    root.toggleSelected(trow.nodeKey)
                }
            }

            MouseArea {
                /* 热区**正好**盖住箭头那一格（每行位置不同，因为缩进不同）：
                 * x 从 `lead` 起、宽 `chevronWidth`。
                 *
                 * 不做成"整行左侧一大片"是刻意的 —— 那会吃掉勾选框左边的
                 * 空白，而用户在那块空白上点一下，期待的是"选中这一行"，
                 * 不是"展开它"。 */
                x: trow.chevronX
                y: 0
                width:  root.chevronWidth
                height: trow.height
                enabled: root.enabled && trow.hasChildren
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    root.forceActiveFocus()
                    root.toggleExpand(trow.nodeKey)
                }
            }
        }
    }

    // qmllint enable unqualified
}
