/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinPagination
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 分页条（M7）。
 *
 * ── 分工 ─────────────────────────────────────────────────────────────
 *   本文件：页码窗口计算（首末页恒显 + 当前页±2 + 省略号）、上下页、
 *           翻页信号、总数显示；键盘 Tab 序
 *   插槽：  页码按钮复用 QSkinButton（当前页 primary，其余 text 变体），
 *           总数文字复用 Slots.label —— 零新插槽
 *
 * 用法：
 *     QSkinPagination {
 *         total: 105
 *         page: 1
 *         pageSize: 10
 *         showTotal: true
 *         onPaged: (p) => fetchPage(p)      // 服务端分页：自己拉数据
 *     }
 *
 * 与 QSkinTable 的关系是**正交**的，两种用法都成立：
 *   · 客户端分页：QSkinTable 设 pageSize > 0，自己切片（见 QSkinTable 文件头）
 *   · 服务端分页：Table 只收当前页数据，Pagination 独立摆，翻页回调拉数据
 *
 * 页码窗口规则（与 Ant Design 对齐）：
 *   总页数 ≤ 7        全部显示
 *   否则               1 … (page-2..page+2) … pageCount
 *   窗口贴边时省略号自然消失（page ≤ 4 / page ≥ pageCount-3）
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 总条数 */
    property int total: 0

    /** 当前页，1 起 */
    property int page: 1

    /** 每页条数 */
    property int pageSize: 10

    /** 显示"共 N 条"文字 */
    property bool showTotal: false

    /** 总页数。total 为 0 时为 0（翻页按钮全部禁用） */
    readonly property int pageCount: root.pageSize > 0
                                     ? Math.ceil(root.total / root.pageSize)
                                     : 0

    /** 翻页。goTo() 与点击按钮都会触发；page 已夹取到 [1, pageCount] */
    signal paged(int page)

    implicitWidth: bar.implicitWidth
    implicitHeight: bar.implicitHeight

    /* total / pageSize 变化导致页数缩水时，把 page 夹回有效范围 */
    onPageCountChanged: {
        if (root.pageCount > 0 && root.page > root.pageCount) {
            root.page = root.pageCount
            root.paged(root.page)
        }
    }

    function goTo(p) {
        var next = Math.max(1, Math.min(p, Math.max(1, root.pageCount)))
        if (next !== root.page) {
            root.page = next
            root.paged(next)
        }
    }

    /* ══════════════════════ 页码窗口 ══════════════════════ */

    /** [1, "..", 4, 5, 6, "..", 11]。"..":省略号占位 */
    function _pageList() {
        var count = root.pageCount
        if (count <= 0)  return []
        if (count <= 7) {
            var all = []
            for (var i = 1; i <= count; ++i) all.push(i)
            return all
        }
        var out = [1]
        var from = Math.max(2,     root.page - 2)
        var to   = Math.min(count - 1, root.page + 2)
        if (from > 2) out.push("..")
        for (var j = from; j <= to; ++j) out.push(j)
        if (to < count - 1) out.push("..")
        out.push(count)
        return out
    }

    /* ══════════════════════ 视觉 ══════════════════════ */

    QSkinRow {
        id: bar

        gap: Theme.space.xs

        /* 总数文字走 label 插槽 —— 与菜单行 / 表格单元格同一套伪装约定 */
        Loader {
            id: totalLabel

            sourceComponent: Slots.label
            visible: root.showTotal

            Binding {
                target: totalLabel.item
                property: "control"
                value: totalCtl
                when: totalLabel.status === Loader.Ready
            }
        }

        QtObject {
            id: totalCtl

            readonly property string text: qsTr("共 %1 条").arg(root.total)
            readonly property string variant: "default"
            readonly property int labelAlignment: Text.AlignLeft
        }

        /* 上下页用**画出来的**箭头，不再拿按钮文字打 "‹" / "›"。
         * QSkinButton 保留 —— 焦点、键盘激活、按下态、禁用态都在它身上，
         * 换成裸 Item + Shape 会把这些一起丢掉（QSkinDatePicker 的翻月
         * 按钮就是这样，所以它这一轮也跟着收编）。
         *
         * accessibleName 是必须的：图标按钮的 text 是空的，不给这一项
         * 读屏软件只会念出"按钮"。改造前它念的是 "‹" —— 同样没有意义。 */
        QSkinButton {
            icon:          Slots.chevronIndicator
            iconDirection: "left"
            accessibleName: qsTr("上一页")
            variant: "text"
            size: "sm"
            enabled: root.page > 1
            onClicked: root.goTo(root.page - 1)
        }

        /* delegate 里引用外层 id（root）—— 与 QSkinSelect delegate 同款
         * qmllint 静态检查局限，局部关闭。注释首行不以 qmllint 开头。 */
        // qmllint disable unqualified
        Repeater {
            model: root._pageList()

            /* 根 Item 承载 required property；互斥子项取可见者的尺寸 */
            delegate: Item {
                id: pageSlot

                required property var modelData

                readonly property bool isDots: pageSlot.modelData === ".."
                readonly property bool isCurrent: pageSlot.modelData === root.page

                implicitWidth:  pageSlot.isDots ? dots.implicitWidth  : pageBtn.implicitWidth
                implicitHeight: pageSlot.isDots ? dots.implicitHeight : pageBtn.implicitHeight

                Text {
                    id: dots

                    anchors.verticalCenter: parent.verticalCenter
                    visible: pageSlot.isDots
                    text: "…"
                    font.family:    Theme.font.family
                    font.pixelSize: Theme.font.sm
                    color: Theme.color.fgMuted
                    renderType: Text.NativeRendering
                }

                QSkinButton {
                    id: pageBtn

                    anchors.verticalCenter: parent.verticalCenter
                    visible: !pageSlot.isDots
                    text: String(pageSlot.modelData)
                    variant: pageSlot.isCurrent ? "primary" : "text"
                    size: "sm"
                    onClicked: root.goTo(Number(pageSlot.modelData))
                }
            }
        }
        // qmllint enable unqualified

        QSkinButton {
            icon:          Slots.chevronIndicator
            iconDirection: "right"
            accessibleName: qsTr("下一页")
            variant: "text"
            size: "sm"
            enabled: root.page < root.pageCount && root.pageCount > 0
            onClicked: root.goTo(root.page + 1)
        }
    }
}
