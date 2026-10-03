/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinCollapse
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 折叠面板组（M23）。管三件事：**哪些块是展开的**、**排他还是多开**、
 * **外框与块之间的分隔线**。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么它是一个**布局容器**，而 QSkinRadioGroup 不是
 * ════════════════════════════════════════════════════════════════════════
 * QSkinRadioGroup 的文件头论证过"组管状态、布局容器管排列"，结论是它必须
 * 是 QtObject 而不是 positioner。同一条判据在这里得到**相反**的答案 ——
 * 差别是具体的一条，写下来免得下次有人以为两者不一致：
 *
 *   · 单选组的排列是**开放的**：真实表单里它后面可能跟一段说明、一个
 *     "其他___"输入框、或者要排成两列。组自己当 positioner 会挡路。
 *   · 折叠组没有任何排列自由度：**Accordion 就是竖着叠的一列**，
 *     四家的实现对这一点没有分歧，也不存在"折叠面板排成两列"的用法。
 *
 * 而且组还有**它自己的视觉**要画：整组的外框（圆角 + 描边）与块之间的
 * 分隔线。这两样东西**只能由知道成员顺序的那一层画** —— 让每块自己画
 * 一条顶边也能做（本件就是这么做的），但"外框"必须有一个共同祖先，
 * 否则每块都会长出自己的一圈框。
 *
 * 所以：**这里当容器，成员仍用 default property 收**。
 * 单块的排列由内部的 QSkinColumn 负责，组只负责"框 + 序 + 状态"。
 *
 * ════════════════════════════════════════════════════════════════════════
 * `expandedKeys` 是**唯一**的事实来源，且永远是数组
 * ════════════════════════════════════════════════════════════════════════
 * 参照实现里"展开的键"有两种形状（排他时是单值、多开时是数组），
 * 于是读取方每次都要先判类型。本件不这么做：**对外永远是 `string[]`**。
 * 排他只是"写的时候把别人清掉"，不是"另一种数据类型"。
 *
 * 好处是判据可以写得很硬：`expandedKeys.length <= 1`（排他时恒真）。
 * 若允许单值形状，那句话就得分两支写，而分支多的判据最容易漏。
 *
 * ── 两条不变量都在写入口收敛，而不是靠调用方自觉 ──────────────────────
 *   ① **排他**：`accordion: true` 时，无论谁塞进来几个键，最多只留一个。
 *      实现放在**属性变化**上（`onExpandedKeysChanged` **与**
 *      `onAccordionChanged` 两处，走同一个 `_enforceAccordion`）——
 *      于是"用户点表头"与"宿主直接赋值"走**同一条**收敛路，不存在
 *      "哪种写法会漏掉约束"。两处都要，理由见 `_enforceAccordion` 的注释。
 *   ② **整体赋值**：每次变化都换一个新数组，不就地 push/splice ——
 *      `property var` 的就地修改不发通知，而所有派生属性都靠那个通知活着
 *      （M19 的 QSkinList / M20 的 QSkinRadioGroup 都记过这条）。
 *
 * 用法：
 *     QSkinCollapse {
 *         accordion: true
 *         QSkinCollapseItem { key: "a"; title: "基本信息"; QSkinBody { text: "…" } }
 *         QSkinCollapseItem { key: "b"; title: "权限";     QSkinBody { text: "…" } }
 *     }
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 排他：最多只有一块展开。打开一块会**收起其余**。 */
    property bool accordion: false

    /** 展开的键集合。**永远是 string[]**（见文件头）。 */
    property var expandedKeys: []

    /** 外框与块之间的分隔线。关掉它就是"一堆能开合的区域"
     *  （shadcn 的 Collapsible 那一档的组形态）。 */
    property bool bordered: true

    /** 整组可用性。成员的表头据此禁用（成员自己的 disabled 也生效，取与）。 */
    property bool enabled: true

    /** 成员（default property） */
    default property alias panels: stack.data

    signal expanded(string key)
    signal collapsed(string key)

    /** 成员沿 `parent` 链往上找组时认这个标记（见 QSkinCollapseItem._findGroup）。
     *  用标记而不是"有没有 `_register` 这个方法"：QSkinRadioGroup 也有
     *  同名方法，靠函数名撞运气会让成员接错线。 */
    readonly property bool _isCollapseGroup: true

    /* ══════════════════════ 成员登记 ══════════════════════
     * 协议与 QSkinRadioGroup 同源（那边文件头有完整论证），**只有一处不同**：
     * 成员自己沿 `parent` 链找上来，调用方不用写 `collapse: 组名`。
     *
     * 差别的原因是这个组**是容器**（成员写在它里面），而 QSkinRadioGroup
     * 不是（成员写在调用方自己的布局里）。既然"写在组里"就是成员资格，
     * 再让调用方逐块重复一遍 `collapse: col` 就是纯机械劳动 ——
     * 而忘写它的表现是"点了表头没反应"，不报错。
     * 实测与完整理由写在 QSkinCollapseItem._findGroup 的注释里。
     *
     * 顺序由 MemberOrder 按**声明序**矫正 —— 兄弟节点的 onCompleted 是
     * 逆序触发的，照登记先后排会让"第一块"整体反转。 */

    property var _panels: []

    function _register(item) {
        if (item === null || item === undefined) return
        if (root._panels.indexOf(item) >= 0) return
        var out = root._panels.slice()
        out.push(item)
        root._panels = MemberOrder.sortByDeclaration(out)
    }

    function _unregister(item) {
        var i = root._panels.indexOf(item)
        if (i < 0) return
        var out = root._panels.slice()
        out.splice(i, 1)
        root._panels = out
    }

    /* ══════════════════════ 键与展开态 ══════════════════════ */

    /** 成员的键：显式给的 `key`，没给就用**声明序下标**（字符串）。
     *
     *  为什么允许留空：写一个 key 是纯机械劳动，而"第几块"本来就有一个
     *  确定的答案。代价是**重排会换号** —— 所以留空只适合"展开态不跨
     *  重排保留"的场景，控件在文件头写明了这一点。 */
    function _keyOf(item) {
        if (item === null || item === undefined) return ""
        if (item.key !== undefined && item.key !== "") return String(item.key)
        return String(MemberOrder.indexOf(root._panels, item))
    }

    function isExpanded(key) {
        var list = root._keys()
        for (var i = 0; i < list.length; ++i)
            if (list[i] === String(key)) return true
        return false
    }

    /** 归一成一个**数组**：外部可能塞单值、null、undefined
     *  （参照实现里这几种都合法），这里一次性收匀。
     *  写成纯函数而不是就地改属性 —— 属性以这个函数为准。 */
    function _keys() {
        var v = root.expandedKeys
        if (v === null || v === undefined) return []
        if (typeof v === "string" || typeof v === "number") return [String(v)]
        var out = []
        for (var i = 0; i < v.length; ++i) out.push(String(v[i]))
        return out
    }

    /** 排他收敛（不变量 ①）。放在**两个**属性变化上，于是"任何入口"都过这里。
     *
     *  ⚠ `onAccordionChanged` 那一句不能省。第一版只有 `onExpandedKeysChanged`
     *    一处，于是这条路径会漏掉：
     *
     *        expandedKeys = ["a","c"]     // 多开时两块都开着
     *        accordion = true             // 宿主把组切成排他
     *        → 两块**仍然都开着**，直到下一次有人写 expandedKeys
     *
     *    那会让文件头那句"`accordion: true` 时 `expandedKeys.length <= 1`
     *    恒真"变成一句**假话** —— 而它是这一族判据的立身之本。收敛放在
     *    属性变化上而不是写入口里，正是为了这种"没人经过写入口"的路径。 */
    onExpandedKeysChanged: root._enforceAccordion()
    onAccordionChanged:    root._enforceAccordion()

    function _enforceAccordion() {
        if (!root.accordion) return
        var list = root._keys()
        if (list.length <= 1) return
        /* 留**最后一个** —— 用户刚点的那一块总是排在最后。
         * 留第一个会让"点了 B 却打开了 A"，而两者都是"合法的单值"。 */
        var kept = list[list.length - 1]
        root.expandedKeys = [kept]
        /* 被挤掉的块要收到 collapsed —— 否则宿主的状态与实际不符。 */
        for (var i = 0; i < list.length - 1; ++i)
            root.collapsed(list[i])
    }

    /* ══════════════════════ 写入口 ══════════════════════ */

    function expand(key) {
        root._set(String(key), true)
    }

    function collapse(key) {
        root._set(String(key), false)
    }

    function toggle(key) {
        root._set(String(key), !root.isExpanded(key))
    }

    function _set(key, on) {
        /* 展开一个被禁用的成员：拒绝。守卫放在**这里**而不是只放在成员那一侧
         * （`_toggleByItem`），因为 `toggle` / `expand` 是对外公开的 API ——
         * 宿主直接调它们时会绕过成员侧的那道判。实测（smoke_m23 的 [1]
         * 就是照成员侧写的第一版）：`ciB.disabled = true` 之后调
         * `col.toggle("b")` 照样把它打开了，而"禁用"的含义正是"打不开"。
         * 收敛放在必经之路上，与 `_enforceAccordion` 是同一条纪律。 */
        if (on && !root._canExpandKey(key)) return

        var list = root._keys()
        var at = list.indexOf(key)
        if (on && at >= 0) return
        if (!on && at < 0) return

        if (on) {
            if (root.accordion) list = [key]
            else                list = list.concat([key])
        } else {
            var out = []
            for (var i = 0; i < list.length; ++i)
                if (list[i] !== key) out.push(list[i])
            list = out
        }
        root.expandedKeys = list        /* 整体赋值 → 通知 */
        if (on) root.expanded(key); else root.collapsed(key)
    }

    /** 这个键对应的成员现在能不能被展开。
     *
     *  找不到对应成员时**放行**：`expandedKeys` 是公开可写的，宿主可能塞
     *  一个还没挂上来的键（先设状态、成员后到）。那种情况不该被当成"禁用"。 */
    function _canExpandKey(key) {
        var list = root._panels
        for (var i = 0; i < list.length; ++i)
            if (root._keyOf(list[i]) === key) return list[i].disabled !== true
        return true
    }

    /* ══════════════════════ 成员侧的入口 ══════════════════════ */

    function _isExpandedByItem(item) {
        return root.isExpanded(root._keyOf(item))
    }

    /** 成员侧的开合入口。**不再自带禁用判** —— 那道守卫在 `_set` 里，
     *  于是"点表头"与"宿主直接调 toggle"走同一条约束路（见 `_set`）。 */
    function _toggleByItem(item) {
        root.toggle(root._keyOf(item))
    }

    /** 上下键在组内移动焦点：**跳过禁用的块、两端回绕**。
     *  与 QSkinRadioGroup._moveFrom 同一套约定（那边只多一步"顺带选中"，
     *  因为单选组的约定是移动即选中；折叠面板不该这样 —— 只是移动焦点）。 */
    function _moveFocus(item, delta) {
        var list = root._panels
        var n = list.length
        if (n === 0) return
        var i = list.indexOf(item)
        if (i < 0) i = 0
        var step = delta >= 0 ? 1 : -1
        var j = i
        for (var k = 0; k < n; ++k) {
            j = (j + step + n) % n
            if (list[j].disabled === true) continue
            list[j]._focusHeader()
            return
        }
    }

    /* ══════════════════════ 视觉 ══════════════════════ */

    implicitWidth:  320
    implicitHeight: stack.implicitHeight

    /* 外框。它必须由组画 —— 每块自己画一圈框会让相邻两块出现双线。 */
    Rectangle {
        id: frame

        anchors.fill: parent
        visible: root.bordered

        radius: Theme.radius.lg
        color:  Theme.color.bg
        border.width: 1
        border.color: Theme.color.border
    }

    QSkinColumn {
        id: stack

        anchors.fill: parent
        gap: 0
    }
}
