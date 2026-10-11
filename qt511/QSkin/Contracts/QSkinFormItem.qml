/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinFormItem
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 表单字段（M8）：标签 + 控件 + 校验规则 + 错误提示。
 *
 * ── 分工 ─────────────────────────────────────────────────────────────
 *   本文件：标签行（required 星号）、规则求值、错误显隐与实时重校
 *   插槽：  标签与错误文字都走 Slots.label（默认 / danger 变体）
 *           —— danger 分支经 M4 的 isButtonHost 分流，FormItem 伪装
 *           控件无 iconSize，正确落到 Theme.color.danger
 *
 * ── rules 规则数组（按序求值，首个不过即停）────────────────────────
 *     { required: true,            message: "必填" }
 *     { minLength: 3,              message: "至少 3 个字符" }
 *     { maxLength: 20,             message: "最多 20 个字符" }
 *     { pattern: /^1\d{10}$/,      message: "手机号格式不对" }
 *     { test: function(v) { return v === "admin" ? "用户名已被占用" : true },
 *       message: "" }               // test 返回 false 用 message；
 *                                   // 返回非空字符串直接当错误消息
 *
 * ── 取值（鸭子类型，按序探测）───────────────────────────────────────
 *     control.text → control.checked → control.value → null
 *
 * 用法：
 *     QSkinFormItem {
 *         label: "用户名"; required: true
 *         rules: [{ required: true, message: "请输入用户名" },
 *                 { minLength: 2,   message: "至少 2 个字符" }]
 *         QSkinInput { placeholderText: "2-20 字符" }     // default property
 *     }
 *
 * 校验时机：validate() 显式触发；一旦出过错，值变化即实时重校
 * （用户改对了错误立刻消失 —— ignoreUnknownSignals 兼容无 text 的控件）。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    property string label: ""

    /** 是否必填：标签后补红色星号 */
    property bool required: false

    /** 校验规则数组，见文件头 */
    property var rules: []

    /** 规则里没给 `message` 时用的默认错误文案 */
    property string defaultMessage: qsTr("格式不正确")

    /** 当前错误文案（空串 = 无错）。validate() 后更新 */
    readonly property string errorText: root._errorText

    /** 校验。通过返回 true 并清错误；不过返回 false 并显示错误。
     * 一旦出过错（_touched），后续值变化持续实时重校 ——
     * 用"当前有错"当开关的话，错误被清空那一刻跟踪就停摆，
     * "填错 → 改对 → 再改错"的最后一步不会重新报错（M8 实测） */
    function validate() {
        var v = root._value()
        var err = ""
        for (var i = 0; i < root.rules.length && err === ""; ++i) {
            var r = root.rules[i]
            if (!r) continue
            if (r.required === true && root._isEmpty(v))
                err = root._msg(r)
            else if (r.minLength !== undefined && !root._isEmpty(v)
                     && String(v).length < r.minLength)
                err = root._msg(r)
            else if (r.maxLength !== undefined && !root._isEmpty(v)
                     && String(v).length > r.maxLength)
                err = root._msg(r)
            else if (r.pattern !== undefined && !root._isEmpty(v)
                     && !r.pattern.test(String(v)))
                err = root._msg(r)
            else if (r.test !== undefined && !root._isEmpty(v)) {
                var verdict = r.test(v)
                if (verdict === false)      err = root._msg(r)
                else if (typeof verdict === "string" && verdict !== "")
                    err = verdict
            }
        }
        root._errorText = err
        if (err !== "") root._touched = true
        return err === ""
    }

    /** 清除错误显示（不触发校验）。跟踪状态一并重置 */
    function clearError() { root._errorText = ""; root._touched = false }

    /* ══════════════════════ 内部 ══════════════════════ */

    /* 放进来的控件（default property） */
    default property alias data: fieldHost.data

    property string _errorText: ""
    property bool   _touched: false

    /* ColumnLayout 里填满宽（QSkinForm 是 QSkinColumn） */
    implicitWidth:  fieldHost.implicitWidth
    implicitHeight: fieldHost.implicitHeight

    QSkinColumn {
        id: fieldHost

        anchors.fill: parent
        fill:  true
        gap:   Theme.space.xs

        /* 标签行：label 插槽默认变体 + required 星号 */
        QSkinRow {
            gap: Theme.space.xs

            Loader {
                id: labelLoader

                visible: root.label !== ""
                sourceComponent: Slots.label

                Binding {
                    target: labelLoader.item
                    property: "control"
                    value: labelCtl
                    when: labelLoader.status === Loader.Ready
                }
            }

            QtObject {
                id: labelCtl

                readonly property string text: root.label
                readonly property string variant: "default"
                readonly property int labelAlignment: Text.AlignLeft
            }

            Text {
                visible: root.required
                text: "*"
                font.family:    Theme.font.family
                font.pixelSize: Theme.font.sm
                color: Theme.color.danger
                renderType: Text.NativeRendering
            }
        }

        /* 错误行：label 插槽 danger 变体。visible false 在
         * ColumnLayout 里不占位（M4 验证过的行为） */
        Loader {
            id: errorLoader

            visible: root._errorText !== ""
            sourceComponent: Slots.label

            Binding {
                target: errorLoader.item
                property: "control"
                value: errorCtl
                when: errorLoader.status === Loader.Ready
            }
        }

        QtObject {
            id: errorCtl

            readonly property string text: root._errorText
            readonly property string variant: "danger"
            readonly property int labelAlignment: Text.AlignLeft
        }
    }

    /* 控件取值：按序探测 text / checked / value（鸭子类型）。
     * 只认 Item 类型子对象 —— 本文件声明的 QtObject 伪装件
     * （labelCtl / errorCtl）也有 text 属性，不过滤会把标签文字
     * 当成控件值（M8 实测踩坑）。Item 的判据用 visible。 */
    function _firstControl() {
        var kids = fieldHost.data
        for (var i = 0; i < kids.length; ++i) {
            var k = kids[i]
            if (k && k.visible !== undefined
                  && (k.text !== undefined || k.checked !== undefined || k.value !== undefined))
                return k
        }
        return null
    }

    /* 控件取值：checked 优先于 text —— QSkinCheckBox 两者都有
     * （text 是标签文字，默认 ""），text 优先会让空标签短路掉
     * checked，勾选类控件的 required 永远校验不过（M8 实测踩坑） */
    function _value() {
        var c = root._firstControl()
        if (!c) return null
        if (c.checked !== undefined) return c.checked
        if (c.text !== undefined)    return c.text
        if (c.value !== undefined)   return c.value
        return null
    }

    function _isEmpty(v) {
        return v === null || v === undefined || v === "" || v === false
    }

    function _msg(rule) {
        return rule.message !== undefined ? String(rule.message) : root.defaultMessage
    }

    /* 出过错之后实时重校：值变了错误立刻消失/更新。
     * ignoreUnknownSignals：无 text 的控件（如纯 Checkbox）不警告。
     *
     * target 不能写成函数绑定（target: root._firstControl()）——
     * 构建期求值一次后不再刷新，此时用户控件可能还没进 data 列表，
     * 永远挂错对象（M8 实测：改 checked 从不触发重校）。
     * 组件完成时子对象已全部就位，显式赋值一次即可。 */
    property var _control: null

    Component.onCompleted: root._control = root._firstControl()

    Connections {
        target: root._control
        ignoreUnknownSignals: true

        function onTextChanged() {
            if (root._touched) root.validate()
        }

        function onCheckedChanged() {
            if (root._touched) root.validate()
        }

        /* M9：取值走 value 的控件（QSkinInputNumber / QSkinSlider）。
         * ignoreUnknownSignals 让无这些信号的控件（Input/CheckBox）不警告 */
        function onValueModified() {
            if (root._touched) root.validate()
        }

        function onMoved() {
            if (root._touched) root.validate()
        }
    }
}
