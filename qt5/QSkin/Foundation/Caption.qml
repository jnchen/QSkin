/****************************************************************************
 * QSkin · Quick Design System — Foundation / Caption
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 辅助文字：表单说明、错误提示、时间戳、快捷键提示。
 * 12px 是桌面端可读性的下限，再小就不该用文字承载信息了。
 *
 * 用法：
 *     Caption { text: "最多 32 个字符" }
 *     Caption { text: "该邮箱已被占用"; tone: "danger" }
 ****************************************************************************/

import QtQuick 2.15

Text {
    id: root

    /** default | secondary | muted | danger | warning | success */
    property string tone: "secondary"

    text: ""

    font.family:    Theme.font.family
    font.pixelSize: Theme.font.xs
    font.weight:    Theme.font.weightRegular

    lineHeight:     1.45
    lineHeightMode: Text.ProportionalHeight

    color: root.tone === "danger"    ? Theme.color.danger
         : root.tone === "warning"   ? Theme.color.warning
         : root.tone === "success"   ? Theme.color.success
         : root.tone === "muted"     ? Theme.color.fgMuted
         : root.tone === "default"   ? Theme.color.fg
                                     : Theme.color.fgSecondary

    verticalAlignment:   Text.AlignVCenter
    horizontalAlignment: Text.AlignLeft

    wrapMode:   Text.WordWrap
    renderType: Text.NativeRendering
}
