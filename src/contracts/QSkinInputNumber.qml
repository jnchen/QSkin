/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinInputNumber
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 数字输入框（M9）：文本输入 + 步进器（上下箭头）。
 *
 * ── 分工 ─────────────────────────────────────────────────────────────
 *   本文件：取值状态机 —— 步进/键盘/提交钳制
 *   插槽：  inputBackground（与 QSkinInput 同款输入框底板，含 error 态）
 *
 * ── 提交时机（关键取舍）───────────────────────────────────────────────
 *   输入过程中**不做**逐步解析：用户打 "-"、"1e" 这类中间态时强制
 *   解析会把光标跳来跳去。解析收口在三处：回车、失焦、点步进器。
 *   解析失败（空串/非数字）静默回滚到当前 value —— 与 Ant Design 一致。
 *
 * ── 为什么不给滚轮 ───────────────────────────────────────────────────
 *   数字框滚轮极易误触（路过就变值），Ant / Arco 都不启用，
 *   要调值请点步进器或用 ↑/↓。QSkinSlider 才是滚轮的地盘。
 *
 * ── 与 FormItem 的取值契约 ────────────────────────────────────────────
 *   本控件**不暴露 text 属性**（内部 TextInput 不外泄）——
 *   QSkinFormItem._value() 按序探测 checked / text / value，
 *   没有前两者才会落到 value。暴露 text 会让表单把草稿文字当值。
 *
 * ── 为什么步进箭头用 Canvas 而不是 Unicode 字形 ──────────────────────
 *   "▴/▾" 这类字形在不同系统字体栈里回退不可控（有的粗有的细有的
 *   干脆缺字形），Canvas 线条在所有平台渲染一致。
 *
 * 用法：
 *     QSkinInputNumber {
 *         value: 1; min: 1; max: 99; step: 1
 *         onValueModified: function(v) { total = v * price }
 *     }
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    property real value: 0
    property real min: 0
    property real max: 999999

    /** 步进器/方向键的单步增量 */
    property real step: 1

    /** 小数位数。显示与提交都按它舍入 */
    property int decimals: 0

    property string placeholderText: ""

    /** 校验失败态（与 QSkinInput 同语义，走 inputBackground 插槽） */
    property bool error: false

    property bool hovered: false
    property int  padding: Theme.space.md

    /** 步进/键盘/提交导致 value 变化时发出（外部绑定改 value 不发） */
    signal valueModified(real v)
    signal editingFinished()

    /* ══════════════════════ 尺寸 ══════════════════════ */

    implicitWidth:  120
    implicitHeight: Theme.size.controlMd

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true

    Accessible.role: Accessible.EditableText
    Accessible.name: qsTr("数字输入框")

    /* ══════════════════════ 插槽 ══════════════════════ */

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

    /* ══════════════════════ 文本输入 ══════════════════════ */

    TextInput {
        id: input

        anchors.left:           parent.left
        anchors.right:          spinnerCol.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin:     root.padding
        anchors.rightMargin:    Theme.space.xs

        /* 声明式绑定显示当前值；用户一旦敲键，绑定断开，文本成为
         * "草稿"，等提交后由 _commit() 重建绑定（见文件头提交时机） */
        text: root._format(root.value)

        font.family:    Theme.font.family
        font.pixelSize: Theme.font.sm
        color:          root.enabled ? Theme.color.fg : Theme.color.fgDisabled

        selectionColor:    Theme.color.brandSubtle
        selectedTextColor: Theme.color.fg

        verticalAlignment: TextInput.AlignVCenter
        selectByMouse: true
        clip: true

        onAccepted:        root._commit()
        onEditingFinished: root._commit()

        /* 失焦即提交 —— 步进器被点击时焦点未必离开 TextInput，
         * 所以 _step() 里先手动 _commit() 草稿 */
        onActiveFocusChanged: if (!activeFocus) root._commit()

        Keys.onUpPressed:   function(event) { event.accepted = true; root._step(1) }
        Keys.onDownPressed: function(event) { event.accepted = true; root._step(-1) }

        /* PageUp/PageDown 不在 Keys 专用处理器列表里，走通用 onPressed */
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_PageUp) {
                event.accepted = true
                root._step(10)
            } else if (event.key === Qt.Key_PageDown) {
                event.accepted = true
                root._step(-10)
            }
        }
    }

    /* 占位符：只在草稿为空时出现（常态下文本框永远显示格式化数值，
     * 用户清空输入才是占位符的地盘）。与 QSkinInput 同款：提示不是
     * 内容，不进插槽 */
    Text {
        anchors.left:           input.left
        anchors.verticalCenter: input.verticalCenter
        visible: input.text === "" && root.placeholderText !== ""

        text:  root.placeholderText
        font:  input.font
        color: Theme.color.fgMuted

        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    /* ══════════════════════ 步进器 ══════════════════════ */

    Item {
        id: spinnerCol

        width: 24
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom

        /* 与文本的分隔线 */
        Rectangle {
            width: 1
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.space.xs
            color: Theme.color.border
        }

        /* ── 上半区（增） ── */

        Item {
            id: upHalf

            property bool hot: false

            height: spinnerCol.height / 2
            anchors.left:  spinnerCol.left
            anchors.right: spinnerCol.right
            anchors.top:   spinnerCol.top

            Canvas {
                id: chevUp

                anchors.centerIn: parent
                width: 10
                height: 6

                property color c: !root.enabled ? Theme.color.fgDisabled
                                : upHalf.hot    ? Theme.color.fg
                                :                 Theme.color.fgSecondary

                onCChanged: chevUp.requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = String(chevUp.c)
                    ctx.lineWidth = 1.5
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.moveTo(1.5, 4.5); ctx.lineTo(5, 1); ctx.lineTo(8.5, 4.5)
                    ctx.stroke()
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                onEntered: if (root.enabled) upHalf.hot = true
                onExited:  upHalf.hot = false
                onClicked: root._step(1)
            }
        }

        /* ── 下半区（减） ── */

        Item {
            id: downHalf

            property bool hot: false

            height: spinnerCol.height / 2
            anchors.left:   spinnerCol.left
            anchors.right:  spinnerCol.right
            anchors.bottom: spinnerCol.bottom

            Canvas {
                id: chevDown

                anchors.centerIn: parent
                width: 10
                height: 6

                property color c: !root.enabled  ? Theme.color.fgDisabled
                                : downHalf.hot   ? Theme.color.fg
                                :                  Theme.color.fgSecondary

                onCChanged: chevDown.requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = String(chevDown.c)
                    ctx.lineWidth = 1.5
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.moveTo(1.5, 1.5); ctx.lineTo(5, 5); ctx.lineTo(8.5, 1.5)
                    ctx.stroke()
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                onEntered: if (root.enabled) downHalf.hot = true
                onExited:  downHalf.hot = false
                onClicked: root._step(-1)
            }
        }
    }

    FocusRing { control: root }

    /* 只跟踪 hover（整框），不拦截点击 —— 与 QSkinInput 同款 */
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.hovered = true
        onExited:  root.hovered = false
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    function _format(v) {
        return Number(v).toFixed(root.decimals)
    }

    /** 吸附小数位 + 钳制到 [min, max] */
    function _clamp(v) {
        var p = Math.pow(10, root.decimals)
        v = Math.round(v * p) / p
        v = Math.max(root.min, Math.min(root.max, v))
        return Number(v.toPrecision(12))
    }

    /** 解析草稿文本。可解析返回钳制后的值，否则 null（回滚） */
    function _commitText(s) {
        var v = parseFloat(s)
        if (isNaN(v)) return null
        return root._clamp(v)
    }

    /** 提交：解析草稿 → 落值 → 重建显示绑定 */
    function _commit() {
        var v = root._commitText(input.text)
        if (v === null) v = root.value           // 非法输入回滚
        var changed = (v !== root.value)
        if (changed) root.value = v
        input.text = Qt.binding(function() { return root._format(root.value) })
        if (changed) root.valueModified(v)
        root.editingFinished()
    }

    function _step(dir) {
        if (!root.enabled) return
        root._commit()                            // 先落草稿再步进
        root._setValue(root.value + dir * root.step)
    }

    function _setValue(v) {
        v = root._clamp(v)
        if (v !== root.value) {
            root.value = v
            root.valueModified(v)
        }
    }
}
