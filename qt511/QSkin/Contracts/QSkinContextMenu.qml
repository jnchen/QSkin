/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinContextMenu
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 右键菜单 —— 在某个区域的任意位置点右键，菜单出现在指针处。
 *
 * ── 用法：声明在**要响应右键的那个 Item 里** ────────────────────────────
 *
 *     Rectangle {
 *         width: 240; height: 160
 *
 *         QSkinContextMenu {
 *             model: ["复制", "粘贴", "separator", { text: "删除", danger: true }]
 *             onTriggered: function(i) { ... }
 *         }
 *     }
 *
 * 本组件自己 `anchors.fill: parent`，于是它接管的就是"声明它的那个容器的
 * 整块区域"—— 与 QSkinToast 撑满调用方是同一个手法。
 *
 * ── 为什么不是"给一个 target、我把事件挂上去" ───────────────────────────
 * 那要求把 MouseArea reparent 到 target 上，而项目对这件事有过明确结论
 * （见 QSkinTooltip 文件头：盖一层 MouseArea 可能改变 target 的层级与事件
 * 顺序）。QSkinTooltip 当年能绕开，是因为它要的是 hover，而所有 QSkin 控件
 * 都按契约暴露了 hovered；右键没有对应的鸭子类型钩子。
 *
 * 所以这里换了条路：**不碰 target，而是让调用方把菜单声明在目标容器内部**。
 * 容器是它自己的，撑满它不改变任何别人的事件顺序。
 *
 * ── 只吃右键 ────────────────────────────────────────────────────────────
 * MouseArea 的 acceptedButtons 只有 Qt.RightButton，左键按下不被接受，
 * 会照常落到下面的内容上；也不开 hoverEnabled，所以下面控件的 hover
 * 状态完全不受影响。于是"盖了一层"这件事对左键与悬停是透明的。
 *
 * 契约第 3 条提醒：菜单的键盘导航（上下键跳过分隔线 / Esc 关闭）在
 * QSkinMenu 里，这里不重复实现。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 与 QSkinMenu 完全同一套格式（字符串 / 对象 / "separator"） */
    property var model: []

    /* ══════════════════════ 外观 ══════════════════════ */

    property int panelWidth: 180
    property int maxVisibleRows: 10
    property int itemHeight: Theme.size.controlMd

    /* ══════════════════════ 接口 ══════════════════════ */

    readonly property bool opened: ctxMenu.opened

    signal triggered(int index)

    /* ── 可核验抓手 ────────────────────────────────────────────────────
     * 内部 id 刻意不叫 `menu` / `catcher`：属性名与 id 同名时，
     * 组件内部引用那个标识符会落到哪一个身上并不好读 —— 名字分开，
     * 谁是谁一眼看得出。（QSkinDropdown 同样处理。）
     *
     * 这两项都不是"顺手公开"：
     *   menu     门禁要靠它验"委托真的发生了"（行语义、跳分隔线）
     *   catcher  门禁要靠它验"只吃右键、不吃 hover"这条承诺
     * 两者都无法从外部观察，不给就守不住。 */
    readonly property alias menu:    ctxMenu
    readonly property alias catcher: rightClickCatcher

    /** 手动在指定位置开（坐标相对本容器，与 QSkinMenu.openAt 一致） */
    function openAt(x, y) { ctxMenu.openAt(x, y) }
    function close()      { ctxMenu.close() }

    /* 撑满调用方 —— 接管的就是"声明它的那个容器" */
    anchors.fill: parent

    /* ══════════════════════ 右键手势 ══════════════════════ */

    MouseArea {
        id: rightClickCatcher

        anchors.fill: parent

        acceptedButtons: Qt.RightButton

        onClicked: function(mouse) { ctxMenu.openAt(mouse.x, mouse.y) }
    }

    /* ══════════════════════ 菜单 ══════════════════════ */

    QSkinMenu {
        id: ctxMenu

        model:          root.model
        panelWidth:     root.panelWidth
        maxVisibleRows: root.maxVisibleRows
        itemHeight:     root.itemHeight

        onTriggered: function(index) { root.triggered(index) }
    }
}
