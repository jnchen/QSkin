/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinForm
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 表单容器（M8）：聚合子级 QSkinFormItem，一把校验。
 *
 * 就是个 QSkinColumn + validateAll —— 表单的"样子"全在 FormItem，
 * 容器只做两件事：统一间距、统一校验入口。
 *
 * 用法：
 *     QSkinForm {
 *         id: form
 *         QSkinFormItem { label: "用户名"; required: true; rules: [...] ; QSkinInput {} }
 *         QSkinFormItem { label: "邮箱";   rules: [{ pattern: /.../ }] ;  QSkinInput {} }
 *         QSkinFormItem { label: "同意条款"; required: true; rules: [{ required: true, message: "请勾选" }] ; QSkinCheckBox { text: "已阅读" } }
 *     }
 *
 *     QSkinButton {
 *         text: "提交"
 *         onClicked: {
 *             if (form.validateAll()) submit()
 *             else toast.show("请检查表单", "danger")
 *         }
 *     }
 *
 * 校验顺序 = 声明顺序；全部字段都会被校验（不是遇错即停，
 * 一次报全 —— 用户改一处就能看到其余还有什么错）。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

QSkinColumn {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 校验全部字段。全过返回 true；有错返回 false 并让各字段显示错误 */
    function validateAll() {
        var ok = true
        var items = root._fieldItems()
        for (var i = 0; i < items.length; ++i)
            if (!items[i].validate()) ok = false
        return ok
    }

    /** 全部字段的当前错误（调试与测试用）：[{ label, errorText }] */
    function errors() {
        var out = []
        var items = root._fieldItems()
        for (var i = 0; i < items.length; ++i)
            if (items[i].errorText !== "")
                out.push({ label: items[i].label, errorText: items[i].errorText })
        return out
    }

    /** 清除全部错误显示 */
    function clearAllErrors() {
        var items = root._fieldItems()
        for (var i = 0; i < items.length; ++i)
            items[i].clearError()
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    /* 找子级 QSkinFormItem：鸭子识别（有 validate + errorText）。
     * data 而非 children —— FormItem 里还有 Loader 等非直接子级。 */
    function _fieldItems() {
        var out = []
        var kids = root.data
        for (var i = 0; i < kids.length; ++i) {
            var k = kids[i]
            if (k && k.validate !== undefined && k.errorText !== undefined)
                out.push(k)
        }
        return out
    }
}
