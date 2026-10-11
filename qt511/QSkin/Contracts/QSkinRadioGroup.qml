/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinRadioGroup
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 单选组 —— 单选框的**排他性**住在这一层。
 *
 * ── 为什么它是 QtObject 而不是布局容器 ──────────────────────────────────
 * 第一版设计是"组当容器、用 default property 收 QSkinRadio 子项"。放弃它，
 * 理由是**布局不该由组决定**：
 *
 *   · 一眼看上去它只需要"横着放还是竖着放"，但真实表单里单选组后面
 *     常跟着一段说明、一个"其他___"输入框、或者要排成两列 ——
 *     一旦组自己是个 positioner，这些都得绕过去。
 *   · 项目已经有 QSkinRow / QSkinColumn / QSkinGrid 三个布局原子。让组再长出
 *     第四个"只能排单选"的布局，等于在项目里放第二个能排东西的东西。
 *
 * 所以分工是：**组管状态，布局容器管排列。** 成员用 `group:` 显式挂靠 ——
 * 与 QtQuick.Controls 的 `ButtonGroup` 同一套约定，用户不用重新学。
 *
 *     QSkinRadioGroup { id: sizeGrp; value: "md" }
 *
 *     QSkinRow {
 *         gap: Theme.space.lg
 *         QSkinRadio { group: sizeGrp; value: "sm"; text: "小" }
 *         QSkinRadio { group: sizeGrp; value: "md"; text: "中" }
 *         QSkinRadio { group: sizeGrp; value: "lg"; text: "大" }
 *     }
 *
 * ── 谁驱动 checked ──────────────────────────────────────────────────────
 * 方向是**单向**的：组 → 成员。成员只在激活时调一次 `_selectFrom()`，
 * 之后由组把 `value` 推给所有成员。这样"同时勾上两项"在结构上不可能
 * 发生 —— 而不是靠"记得把别人关掉"的自觉。
 *
 * ── 一个只在这个设计下才有的坑 ──────────────────────────────────────────
 * `undefined === undefined` 为真。所以推 checked 时必须**要求 value 有值**：
 * 一个没写 `value` 的单选框，在 `group.value` 也没设时会把自己勾上。
 * 这类"空值相等"型缺陷在属性断言里长得和正确行为一模一样，故显式挡掉
 * （见 `_sync()`）。
 *
 * ── 第二个只在这个设计下才有的坑：成员顺序 ──────────────────────────────
 * 成员的登记走 `Component.onCompleted`，而 Qt 对**兄弟节点**的 onCompleted
 * 是**逆声明序**触发的（实测三个同级对象拿到 "321"）。于是 `_members`
 * 一开始是反的，方向键倒着走、roving tabindex 落在最后一个成员上。
 *
 * 它躲过了属性断言一轮 —— 因为**每个派生量单独看都是对的**，只有"前 /
 * 后"这种顺序关系错了。抓出它的是 `smoke_m20.qml` 的 [1]（[1] 里
 * grpC 那一段特意写了"一个都没选时该落到第一个可用成员"）。
 *
 * 修法是不信回调顺序，按 `children` 下标路径（= 声明序）排序。
 *
 * ⚠ M23 起，那份排序**搬去了 `QSkin.Foundation.MemberOrder`**（同一条逻辑
 *   又要被 Collapse / Timeline / Segmented 用，见那边文件头）。这里只剩
 *   调用，实测记录也留在那边 —— 别在这儿再抄一份。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

QtObject {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 当前选中的值。初始为 undefined = 一项都不选。 */
    property var value: undefined

    signal selectionChanged(var value)

    /* 值的**唯一**入口：外部赋值与成员点击都经这里推送。
     * 少了这一句，"宿主直接改 group.value"就只会改一个变量 ——
     * 属性侧读起来一切正常，屏幕上一个单选框都不动。 */
    onValueChanged: root._sync()

    /* ══════════════════════ 派生 ══════════════════════ */

    /** 挂靠到本组的单选框个数。 */
    readonly property int count: root._members.length

    /** 是否有任意一项处于选中态 —— roving tabindex 要用它决定
     *  "一个都没选时让谁可 Tab 到"（WAI-ARIA：此时该是第一项）。 */
    readonly property bool hasSelection: root._computeHasSelection()

    /**
     * 成员列表。**每次变化都整体赋值**，不是就地 push/splice ——
     * `property var` 的就地修改不会发通知，而 `hasSelection` /
     * `activeFocusOnTab` 这些绑定全靠这个通知活着。
     * （M19 的 QSkinList 用 `data.length` 而不是 `children.length` 是
     * 同一族的小心翼翼：QML 的通知语义和 JS 的直觉不一样。）
     */
    property var _members: []

    /* ══════════════════════ 成员协议 ══════════════════════
     * 由 QSkinRadio 在 Component.onCompleted / onDestruction 里调用。
     * 成员自己不写 checked —— 那是组的活。 */

    function _register(radio) {
        if (radio === null || radio === undefined) return
        if (root._members.indexOf(radio) >= 0) return
        var out = root._members.slice()
        out.push(radio)
        /* 按**声明序**重排 —— 不能信注册回调的先后。
         * 排序在 Foundation 里（M23 抽出去的），理由见那边文件头。 */
        root._members = MemberOrder.sortByDeclaration(out)  /* 整体赋值 → 触发通知 */
        root._sync()
    }

    function _unregister(radio) {
        var i = root._members.indexOf(radio)
        if (i < 0) return
        var out = root._members.slice()
        out.splice(i, 1)
        root._members = out
    }

    /* ══════════════════════ 选中 ══════════════════════ */

    /** 成员被点击时调这里（QSkinRadio._activate）。 */
    function _selectFrom(radio) {
        if (radio === null || radio === undefined) return
        if (radio.enabled === false) return
        if (root.value === radio.value) return
        /* 只写 value —— 推送交给下面的 onValueChanged。
         * 这样"宿主直接写 group.value"与"用户点了一个成员"走**同一条**
         * 路径，不存在"哪种写法会漏掉同步"的区别。 */
        root.value = radio.value
        root.selectionChanged(root.value)
    }

    /** 方向键在组内移动：**跳过禁用的成员、两端回绕**。
     *  移动后焦点跟着走，并且**立即选中**（WAI-ARIA 单选组约定）。 */
    function _moveFrom(radio, delta) {
        var list = root._members
        var n = list.length
        if (n === 0) return
        var i = list.indexOf(radio)
        if (i < 0) i = 0
        var step = delta >= 0 ? 1 : -1
        var j = i
        for (var k = 0; k < n; ++k) {
            j = (j + step + n) % n
            var cand = list[j]
            if (cand.enabled === false) continue
            if (cand.value === undefined) continue
            cand.forceActiveFocus(Qt.OtherFocusReason)
            root.value = cand.value
            root.selectionChanged(root.value)
            return
        }
    }

    /** roving tabindex：一组里只有选中的那个可以 Tab 到；
     *  一个都没选时让**第一个可用成员**可 Tab 到。 */
    function _isTabStop(radio) {
        var list = root._members
        if (list.length === 0) return true
        if (radio.checked === true) return true
        if (root.hasSelection) return false
        for (var i = 0; i < list.length; ++i) {
            if (list[i] === radio) return list[i].enabled !== false
            if (list[i].enabled !== false && list[i].value !== undefined) return false
        }
        return false
    }

    /** 把当前 value 推给所有成员。**只由组调用**。 */
    function _sync() {
        var list = root._members
        for (var i = 0; i < list.length; ++i) {
            var r = list[i]
            /* 没写 value 的成员永远不被自动勾上 —— 见文件头"空值相等" */
            r.checked = (r.value !== undefined && r.value === root.value)
        }
    }

    function _computeHasSelection() {
        var list = root._members
        for (var i = 0; i < list.length; ++i)
            if (list[i].checked === true) return true
        return false
    }
}
