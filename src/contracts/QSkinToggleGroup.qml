/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinToggleGroup
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 开关组 —— 一排开关，单选或多选。
 *
 * ── 与 QSkinRadioGroup 是同一套协议、不同的选择规则 ────────────────────────
 *   · 成员用 `group:` 显式挂靠（不用容器包住），布局交给 QSkinRow /
 *     QSkinColumn —— 完整理由见 QSkinRadioGroup 文件头（"组管状态、
 *     容器管排列"）。这里不重复。
 *   · 组的 `value` **统一是数组**。单选只是"长度恒 ≤ 1"的特例：
 *     统一成数组之后，`isSelected(v)` 只有一种写法，而"单选/多选
 *     两种类型"会污染每一个读它的地方。
 *
 * 两处**故意不同**于单选组的地方：
 *
 *   1. **没有 roving tabindex。** 单选组里 Tab 只停在选中的那一个上
 *      （一组的语义是"选一个"）；开关组里每一个都是**独立的控件**，
 *      各自都该能被 Tab 到 —— 这才是 WAI-ARIA 对一组开关按钮的约定。
 *   2. **没有方向键导航。** 同理：方向键在"选一个"的组里才有"上一个 /
 *      下一个"的语义；对一组独立开关，方向键什么也不该做。
 *
 * ── 单选模式下"再点一次"不清空 ─────────────────────────────────────────
 * 与 QSkinRadio 一致：一个单选的开关组通常表达"当前处于哪一档"，
 * 允许清空就会出现"什么都没选"这个通常无意义的状态。
 * 需要能清空就用 `multiple: true`（多选模式点第二次就是取消）。
 ****************************************************************************/

import QtQuick 2.15

QtObject {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 选中的值。**恒为数组** —— 单选是"长度 ≤ 1"的特例（见文件头）。 */
    property var value: []

    onValueChanged: root._sync()

    /** 能否多选。 */
    property bool multiple: false

    /** 多选时最多选几个。0 = 不限。单选模式下恒为 1（由 multiple 决定）。 */
    property int maxSelected: 0

    signal selectionChanged(var value)

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property int count: root._members.length

    /** 单选模式下的当前值（多选时取第一个）。 */
    readonly property var current:
        (root.value && root.value.length > 0) ? root.value[0] : undefined

    readonly property int selectedCount: root.value ? root.value.length : 0

    readonly property int limit: root.multiple
        ? (root.maxSelected > 0 ? root.maxSelected : Number.MAX_VALUE)
        : 1

    /** 成员列表。**每次变化整体赋值**（`property var` 的就地修改不发通知，
     *  而 `selectedCount` 这些绑定全靠这条通知活着）。 */
    property var _members: []

    /* ══════════════════════ 成员协议 ══════════════════════ */

    function _register(toggle) {
        if (toggle === null || toggle === undefined) return
        if (root._members.indexOf(toggle) >= 0) return
        var out = root._members.slice()
        out.push(toggle)
        root._members = out
        root._sync()
    }

    function _unregister(toggle) {
        var i = root._members.indexOf(toggle)
        if (i < 0) return
        var out = root._members.slice()
        out.splice(i, 1)
        root._members = out
    }

    /* ══════════════════════ 选中 ══════════════════════ */

    /** 成员被点击时调这里（QSkinToggle._activate）。 */
    function _toggleFrom(toggle) {
        if (toggle === null || toggle === undefined) return
        if (toggle.enabled === false) return
        var v = toggle.value
        if (v === undefined) return

        if (root.isSelected(v)) {
            /* 单选：再点一次**不动**（见文件头）；多选：取消 */
            if (!root.multiple) return
            root.setValue(root.value.filter(function(x) { return x !== v }))
            return
        }
        if (root.selectedCount >= root.limit) {
            /* 到上限。多选模式下**替换最后一个**，而不是静默忽略 ——
             * 用户点了却没反应，会被读成"这个按钮坏了"。 */
            if (!root.multiple) return
            var out = root.value.slice(0, root.limit - 1)
            out.push(v)
            root.setValue(out)
            return
        }
        var next = root.value.slice()
        next.push(v)
        root.setValue(next)
    }

    /** 值的**唯一**入口：外部赋值与成员点击都经这里推送。 */
    function setValue(v) {
        var next = v ? v : []
        root.value = next
        root.selectionChanged(next)
    }

    function isSelected(v) {
        if (!root.value) return false
        return root.value.indexOf(v) >= 0
    }

    /** 把选中状态推给所有成员。**只由组调用**。 */
    function _sync() {
        var list = root._members
        for (var i = 0; i < list.length; ++i) {
            var t = list[i]
            /* 没写 value 的成员永远不被自动勾上：`undefined === undefined`
             * 为真，不挡住的话它们会集体点亮（同一个坑见 QSkinRadioGroup）。 */
            t.checked = (t.value !== undefined && root.isSelected(t.value))
        }
    }
}
