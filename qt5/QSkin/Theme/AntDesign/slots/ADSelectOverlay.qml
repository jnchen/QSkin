/****************************************************************************
 * QSkin · Quick Design System — Theme / Ant Design / slots / ADSelectOverlay
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Ant Design 的下拉面板外壳。与 TDesign 的差异：
 *   圆角   8px（radius.lg = borderRadiusLG）vs TD 6px
 *   内边距 4px（Ant 菜单的紧凑内边距）vs TD 8px
 *   描边   Ant 面板**无描边**，靠阴影划边界 —— 省掉边框是 Ant 的签名
 *   阴影   colorBoxShadow（两级近似，画法理由见 TDSelectOverlay）
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var  control: null
    property Item content: null

    property int padding: Theme.space.xs   // 4px

    /** 阴影外扩 3px，如实上报（M4 契约回收） */
    readonly property real extender: 3

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

    /* ── 阴影：两级外扩矩形 ── */
    Rectangle {
        anchors.fill:    parent
        anchors.margins: -3
        radius:          Theme.radius.lg + 3
        color:           "#12000000"   // colorBoxShadow 外层近似
    }
    Rectangle {
        anchors.fill:    parent
        anchors.margins: -1
        radius:          Theme.radius.lg + 1
        color:           "#1F000000"
    }

    /* ── 面板外壳：无描边（Ant 签名）── */
    Rectangle {
        id: panel

        anchors.fill: parent
        radius:       Theme.radius.lg
        color:        Theme.color.bgElevated
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
