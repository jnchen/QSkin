/****************************************************************************
 * QSkin · Quick Design System — Contracts / TimeCell
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * QSkinTimePicker 三列滚轮里的**一个候选项**。内部私有组件，不对外注册。
 *
 * ── 为什么单独拆一个文件 ──────────────────────────────────────────────
 * 三列（时 / 分 / 秒）的格子长得一模一样，只有"选中了要不要回调"
 * 这一处不同。写成三个内联 delegate 就是三份重复的像素级代码 ——
 * 以后要改格子高度或选中底色，得改三处、还容易漏一处。
 *
 * 拆成独立组件后，QSkinTimePicker 里三处 delegate 都只是
 * `TimeCell { ... }` 加各自的回调，视觉只有一份定义。
 *
 * ── 文字走 label 插槽 ────────────────────────────────────────────────
 * 与日历格子同款：用一个代理对象伪装成"控件"，把 text / variant
 * 喂给 Slots.label，于是主题的 label 同时决定了输入框、下拉、日历、
 * 时间的文字外观，控件里没有字体硬编码。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ListView / Repeater 会往 delegate 根节点注入 index 与 modelData，
     * 但必须在这里显式声明为 required property 才能被引用 ——
     * 这是 Qt 6 的硬要求（Qt 5 的隐式注入已废弃）。不声明的话，
     * 宿主写 `cellValue: modelData` 会报 modelData 未定义，
     * 整个组件加载直接失败（表现为 "Did not load any objects"）。 */
    required property int index
    required property var modelData

    /** 这一格代表的值（小时数 / 分钟数 / 秒数） */
    required property int cellValue
    /** 是否是当前选中的那一格 */
    required property bool selected

    /** 单击选中这一格 */
    signal picked()
    /** 键盘上下键换档；dir 为 -1 上一档、+1 下一档 */
    signal step(int dir)

    property int rowHeight: Theme.size.controlSm

    width:  parent ? parent.width : 0
    height: root.rowHeight

    /* 选中底色：品牌色块 + 反白字，与日历的选中格保持同一套语言 */
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Theme.radius.sm
        color: root.selected ? Theme.color.brand
                             : (cellMa.containsMouse ? Theme.color.bgSunken : "transparent")
    }

    Loader {
        id: labelLoader

        anchors.fill: parent
        sourceComponent: Slots.label

        Binding {
            target: labelLoader.item
            property: "control"
            value: cellProxy
            when: labelLoader.item !== null
        }
    }

    /* 伪装成"控件"喂给 label。两位补零（09 / 05），
     * 让列内所有数字等宽，滚动时不会左右抖。 */
    QtObject {
        id: cellProxy
        readonly property string text: DateUtil.pad2(root.cellValue)
        readonly property string variant: root.selected ? "primary" : "default"
        readonly property int    labelAlignment: Text.AlignHCenter
    }

    MouseArea {
        id: cellMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }

    /* 键盘：面板打开时焦点在列上，↑↓ 换档。
     * 放在格子上而不是 ListView 上，是为了让"换档"与"滚动跟随"
     * 这对动作绑定在同一处，不会因为某个 ListView 忘了处理而漏掉。 */
    focus: root.selected
    Keys.onUpPressed:   function(ev) { root.step(-1); ev.accepted = true }
    Keys.onDownPressed: function(ev) { root.step(1);  ev.accepted = true }
}
