/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinDropdown
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 下拉动作菜单 —— 点一个按钮，下面掉出一串动作。
 *
 * ── 它和 QSkinMenu 差在哪（COVERAGE.md 上写着"语义不同"）──────────────────
 * QSkinMenu 是**被动**的：它不关心你怎么触发，你调 open() / openAt(x,y)。
 * 右键菜单、快捷键菜单、程序化菜单都直接用它。
 *
 * QSkinDropdown 是**主动**的：它自带一个触发器（一个带方向箭头的按钮），
 * 并且把"点一下开、再点一下关、箭头跟着翻"这套状态机接好。
 * 业务侧写 `QSkinDropdown { model: [...] }` 就够了，不必自己摆按钮、
 * 也不必自己算菜单该出现在哪。
 *
 * ── 为什么菜单条目不是自己实现的 ────────────────────────────────────────
 * 菜单的行语义（分隔线占多高、危险项怎么标、上下键怎么跳过分隔线与禁用项）
 * 已经完整地长在 QSkinMenu 里。这里重新实现一遍，得到的只会是第二套
 * 键盘导航 —— 而那正是契约层存在的理由。
 *
 * 所以本文件只做三件事：**受托管的触发器、开合状态、把位置算给菜单**。
 *
 * ── 已知取舍：菜单只在下方展开 ──────────────────────────────────────────
 * 靠窗口底部时会被裁。要翻转得先知道菜单高度，而高度要等浮层量完才有 ——
 * 那是一条"先开再挪"的路径，属于 QSkinMenu 那一层的事（它的 openAt 目前
 * 只接受绝对坐标）。V1 交给调用方自己选位置，不在这里塞一份半成品翻转。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

QSkinButton {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 菜单项。格式与 QSkinMenu 完全一致：
     *    字符串                       普通条目
     *    { text, danger, enabled }    危险条目 / 禁用条目
     *    "separator" 或 {separator:true}   分隔线 */
    property var model: []

    /* ══════════════════════ 外观 ══════════════════════ */

    /** 菜单面板宽度。菜单条目宽窄不一，跟随内容会在开合间抖动，
     *  所以定宽（与 QSkinMenu.panelWidth 同一考虑） */
    property int panelWidth: 180
    property int maxVisibleRows: 10
    property int menuItemHeight: Theme.size.controlMd

    /** 触发器与菜单之间的间距 */
    property int menuGap: Theme.space.xs

    /* ══════════════════════ 接口 ══════════════════════ */

    readonly property bool opened: ddMenu.opened

    /** 内部菜单。转发 model / 面板参数之外，调用方偶尔需要直接够到它
     *  （例如程序化触发某一项、读 highlightIndex）。这里如实交出来，
     *  而不是逼着调用方再包一层 —— 门禁也靠它够得着真正的触发路径。
     *
     *  内部 id 不叫 `menu`：属性名与 id 同名时，组件内部引用那个标识符
     *  会落到哪一个身上并不好读。名字分开，谁是谁一眼看得出。 */
    readonly property alias menu: ddMenu

    /** 用户触发了第 index 项（与 QSkinMenu 同名同参，转发） */
    signal triggered(int index)

    function open() {
        if (!root.enabled) return
        /* 菜单声明在本组件内部，所以它的 popup 坐标以本组件为原点 ——
         * 贴着下沿展开、左对齐（bottom-start，与 Ant/TDesign 同款）。 */
        ddMenu.openAt(0, root.height + root.menuGap)
    }
    function close()  { ddMenu.close() }
    function toggle() { root.opened ? root.close() : root.open() }

    /* ══════════════════════ 触发器 ══════════════════════
     * 方向箭头走 chevronIndicator 插槽 —— "箭头长什么样"是主题差异
     * （线宽 / 端点 / 尺寸），不是这里的决定。展开语义留在控件里：
     * 收起朝下、展开朝上。 */

    icon: Slots.chevronIndicator
    iconDirection: root.opened ? "up" : "down"

    onClicked: root.toggle()

    /* ══════════════════════ 菜单 ══════════════════════ */

    QSkinMenu {
        id: ddMenu

        model:          root.model
        panelWidth:     root.panelWidth
        maxVisibleRows: root.maxVisibleRows
        itemHeight:     root.menuItemHeight

        onTriggered: function(index) { root.triggered(index) }
    }
}
