/****************************************************************************
 * QSkin · Quick Design System — Theme / TDesign / slots / TDSelectOverlay
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * TDesign 的下拉面板外壳。契约与 Basic 完全一致（见 BasicSelectOverlay
 * 文件头）：控件持有 ListView，插槽持有外壳，控件把列表注入 content。
 *
 * 与 Basic 的差别：
 *   圆角   6px（--td-radius-medium），比按钮的 3px 大一档
 *   内边距 8px（--td-pop-padding-l）
 *   描边   #DCDCDC（--td-component-border）
 *   阴影   --td-shadow-2 的廉价近似
 *
 * 关于阴影：官方 shadow-2 是三层叠加的 box-shadow。QML 里正经做法是
 * DropShadow / MultiEffect，但它们属于额外的图形特效模块 —— 最小化安装的
 * Qt（只有 qtbase + qtdeclarative）未必带，一旦 import 失败整个面板就没了。
 * 所以这里用两层向外扩张的低透明度圆角矩形近似，零依赖。
 *
 * 代价的解法（M4 契约回收）：浮层用 extender 属性如实上报阴影外扩量，
 * 宿主 Popup 据此把自己放大 extender*2 —— 阴影不再被裁。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var  control: null
    property Item content: null

    /** --td-pop-padding-l = --td-size-4 = 8px */
    property int padding: Theme.space.sm

    /** 阴影两层最外扩 3px，如实上报（M4 契约回收） */
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

    /* ── 阴影：两层外扩矩形，声明顺序决定它们画在面板下面 ── */
    Rectangle {
        anchors.fill:    parent
        anchors.margins: -3
        radius:          Theme.radius.lg + 3
        color:           "#14000000"   // 8% 黑，对应 shadow-2 的最外一层
    }
    Rectangle {
        anchors.fill:    parent
        anchors.margins: -1
        radius:          Theme.radius.lg + 1
        color:           "#1F000000"   // 12% 黑，紧贴面板的一层
    }

    /* ── 面板外壳 ── */
    Rectangle {
        id: panel

        anchors.fill: parent
        radius:       Theme.radius.lg
        color:        Theme.color.bgElevated
        border.width: 1
        border.color: Theme.color.borderStrong
    }

    /* ── 内容区：clip 是必须的，否则滚动时列表会溢出圆角 ── */
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
