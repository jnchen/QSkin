/****************************************************************************
 * QSkin · Quick Design System — Foundation / FocusRing
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 键盘焦点环 —— 桌面端最容易被忽略、却最影响体感的一层。
 *
 * Web 世界有 :focus-visible 作为默认约定，Qt Quick 没有：默认控件
 * 拿到焦点后几乎没有任何可见反馈，键盘用户会直接"迷路"。
 * 这个组件把它补上，并且遵守一条重要原则：
 *
 *     **只在键盘导航时显示（activeFocus），鼠标点击不显示。**
 *
 * 用法：
 *     FocusScope {
 *         id: scope
 *         Rectangle { ... }
 *         FocusRing { control: scope }
 *     }
 ****************************************************************************/

import QtQuick 2.11

Rectangle {
    id: ring

    /* 刻意声明为 var 而不是 Item。
     * 声明成 Item 之后，qmllint 会按 QQuickItem 做成员检查 —— 于是下面
     * 读 control.radius 会被判为 "Member not found"。但这里本来就是
     * 鸭子类型：Rectangle 有 radius，普通 Item 没有，取不到就走默认值。
     * 插槽契约一律用 var，让检查器别插手。 */
    property var control: null

    /** 焦点环与控件边缘的间隙 */
    property int offset: Theme.size ? Theme.size.focusOffset : 2

    /** 焦点环粗细 */
    property int thickness: Theme.size ? Theme.size.focusRing : 2

    /** 圆角；默认跟随控件，控件没给就用 md */
    property int radiusOverride: control ? (control.radius !== undefined ? control.radius : Theme.radius.md)
                                         : Theme.radius.md

    visible: ring.control !== null && ring.control.activeFocus === true

    anchors.fill: ring.control
    anchors.margins: -ring.offset

    radius: ring.radiusOverride + ring.offset
    color: "transparent"
    border.width: ring.thickness
    border.color: Theme.color ? Theme.color.focus : "#7C3AED"

    opacity: ring.visible ? 1 : 0
    z: 9999

    Behavior on opacity {
        NumberAnimation { duration: Theme.motion ? Theme.motion.fast : 120 }
    }
}
