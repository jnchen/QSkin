/****************************************************************************
 * QSkin · Quick Design System — Theme / shadcn / slots / SCSelectOverlay
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * shadcn/ui 的下拉面板外壳（Popover 风格）：
 *   圆角   8px（rounded-lg）
 *   描边   1px zinc-200 —— shadcn 面板靠描边划界，阴影只是辅助
 *   阴影   shadow-md 的单层近似
 *   内边距 4px（p-1 —— shadcn Popover 的紧凑内边距）
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    property var  control: null
    property Item content: null

    property int padding: Theme.space.xs   // p-1 = 4px

    /** 阴影外扩 4px，如实上报（M4 契约回收） */
    readonly property real extender: 4

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

    /* shadow-md 单层近似 */
    Rectangle {
        anchors.fill:    parent
        anchors.margins: -4
        radius:          Theme.radius.lg + 4
        color:           "#1A000000"
    }

    Rectangle {
        id: panel

        anchors.fill: parent
        radius:       Theme.radius.lg
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
