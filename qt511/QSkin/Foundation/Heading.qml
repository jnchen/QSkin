/****************************************************************************
 * QSkin · Quick Design System — Foundation / Heading
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 标题排版预设。字号、字重、行高、颜色全部走令牌，
 * 业务代码里不允许出现裸的 font.pixelSize / color。
 *
 * 用法：
 *     Heading { level: 1; text: "设置" }
 ****************************************************************************/

import QtQuick 2.11

Text {
    id: root

    /** 1 = display / 2 = xl / 3 = lg / 4 = md */
    property int level: 2

    text: ""

    font.family:    Theme.font.family
    font.pixelSize: root.level === 1 ? Theme.font.display
                  : root.level === 2 ? Theme.font.xl
                  : root.level === 3 ? Theme.font.lg
                                     : Theme.font.md
    font.weight:    Theme.font.weightBold

    lineHeight:     Theme.font.lineHeightHeading
    lineHeightMode: Text.ProportionalHeight

    color:          Theme.color.fg

    verticalAlignment:   Text.AlignVCenter
    horizontalAlignment: Text.AlignLeft

    elide:       Text.ElideRight
    wrapMode:    Text.WordWrap
    renderType:  Text.NativeRendering
}
