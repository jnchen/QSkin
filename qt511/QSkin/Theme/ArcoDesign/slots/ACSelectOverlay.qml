/****************************************************************************
 * QSkin · Quick Design System — Theme / Arco Design / slots / ACSelectOverlay
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Arco Design 的下拉面板外壳。与 Ant 的差异：
 *   圆角   4px（radius.medium）vs Ant 8px
 *   描边   有（color-border-2 #E5E6EB）—— Arco 面板靠描边 + 浅阴影
 *   阴影   color-shadow-1 单层近似
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    property var  control: null
    property Item content: null

    property int padding: Theme.space.xs   // 4px

    /** 阴影外扩 2px，如实上报（M4 契约回收） */
    readonly property real extender: 2

    readonly property int rows: control && control.count !== undefined ? control.count : 0
    readonly property int maxRows: control && control.maxVisibleRows !== undefined
                                   ? control.maxVisibleRows : 6
    readonly property int rowHeight: control && control.rowHeight !== undefined
                                     ? control.rowHeight : Theme.size.controlMd

    /* 守卫的理由见 BasicSelectOverlay.qml 同名行 */
    implicitWidth:  control && control.width !== undefined ? control.width : 200
    implicitHeight: (control && control.contentHeight !== undefined
                     ? control.contentHeight
                     : Math.max(1, Math.min(root.rows, root.maxRows)) * root.rowHeight)
                    + root.padding * 2

    /* 单层浅阴影（color-shadow-1） */
    Rectangle {
        anchors.fill:    parent
        anchors.margins: -2
        radius:          Theme.radius.md + 2
        color:           "#14000000"
    }

    Rectangle {
        id: panel

        anchors.fill: parent
        radius:       Theme.radius.md
        color:        Theme.color.bgElevated
        border.width: 1
        border.color: Theme.color.border
    }

    Item {
        id: host

        anchors.fill:    parent
        anchors.margins: root.padding
        clip:            true
    }

    onContentChanged: {
        if (root.content) {
            root.content.parent = host
            root.content.visible = true
        }
    }
}
