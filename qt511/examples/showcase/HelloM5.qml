/****************************************************************************
 * QSkin · 示例 —— M5/M6/M7：数据表格
 *
 *   · QSkinTable：粘性表头 / 行 hover / 选中 / 空状态（M5）
 *   · M6：列排序（点表头 asc→desc 循环）+ 多选（首列 checkbox、表头三态全选）
 *   · M7：客户端分页（pageSize > 0 自动切片）+ QSkinPagination 分页条联动
 *   · 表头与单元格文字都走 Slots.label —— 表头伪装成 "header" 变体
 *   · 右键表格行呼出 QSkinMenu：分隔线计高修复的回归现场
 *   · 主题切换：Neutral / TDesign / Ant / Arco / shadcn
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0
import QSkin.Theme.AntDesign 1.0
import QSkin.Theme.ArcoDesign 1.0
import QSkin.Theme.Shadcn 1.0

QSkinWindow {
    id: win

    width: 960
    height: 680
    visible: true
    title: "QSkin · M5/M6 — Table"

    QtObject {
        id: state

        property int selectedRow: -1
        property string lastAction: "（尚未触发菜单项）"
    }

    /* size 用数值（KB）：排序比较器对 number 走数值序，字符串会掉进
     * 字典序（"12 KB" < "4 KB"）—— 排序演示的正确性靠数据形态保证 */
    ListModel {
        id: files

        ListElement { name: "design-tokens.json"; size: 4;  status: "已同步"; owner: "林一" }
        ListElement { name: "Slots.qml";          size: 12; status: "草稿";   owner: "陈二" }
        ListElement { name: "Theme.qml";          size: 9;  status: "已同步"; owner: "林一" }
        ListElement { name: "QSkinButton.qml";      size: 7;  status: "已同步"; owner: "张三" }
        ListElement { name: "QSkinTable.qml";       size: 11; status: "评审中"; owner: "陈二" }
        ListElement { name: "QSkinMenu.qml";        size: 8;  status: "已同步"; owner: "张三" }
        ListElement { name: "tokens-tdesign.js";  size: 5;  status: "已同步"; owner: "李四" }
        ListElement { name: "tokens-shadcn.js";   size: 5;  status: "草稿";   owner: "李四" }
        ListElement { name: "smoke_m5.qml";       size: 6;  status: "评审中"; owner: "王五" }
        ListElement { name: "HelloM5.qml";        size: 7;  status: "草稿";   owner: "王五" }
        ListElement { name: "README.md";          size: 21; status: "已同步"; owner: "林一" }
        ListElement { name: "LICENSE-MIT";        size: 1;  status: "已同步"; owner: "— " }
    }

    /* ListModel → QSkinTable 要的普通对象数组。列表项会带额外的
     * ListModel 内部字段吗？get() 返回的就是纯对象，直接喂。 */
    function rowsFrom(model) {
        var out = []
        for (var i = 0; i < model.count; ++i) out.push(model.get(i))
        return out
    }

    QSkinColumn {
        id: page

        anchors.fill: parent
        padding: Theme.space.xl
        gap: Theme.space.lg

        /* ── 头部：标题 + 主题切换 ── */
        QSkinRow {
            fill: true
            gap: Theme.space.sm

            QSkinColumn {
                gap: Theme.space.xs

                Heading { text: "M5/M6/M7 · 数据表格" }
                Caption { text: "粘性表头 · 表头文字复用 label 插槽 · 点表头排序 · 首列多选 · 客户端分页 · 右键行呼出菜单" }
            }

            Spacer { }

            QSkinButton { text: "Neutral"; variant: "ghost"; onClicked: { Slots.reset(); Theme.reset() } }
            QSkinButton { text: "TDesign"; variant: "ghost"; onClicked: TDesign.apply() }
            QSkinButton { text: "Ant";     variant: "ghost"; onClicked: AntDesign.apply() }
            QSkinButton { text: "Arco";    variant: "ghost"; onClicked: ArcoDesign.apply() }
            QSkinButton { text: "shadcn";  variant: "ghost"; onClicked: Shadcn.apply() }
        }

        /* ── 表格 ── */
        QSkinTable {
            id: table

            implicitWidth: page.width
            pageSize: 8                   /* 客户端分页（M7）：每页 8 行 */
            emptyText: "没有文件"

            columns: [
                { title: "文件名",   dataIndex: "name",   width: 280, sortable: true },
                { title: "大小(KB)", dataIndex: "size",   align: "right", width: 96, sortable: true },
                { title: "状态",     dataIndex: "status", sortable: true },
                { title: "负责人",   dataIndex: "owner",  width: 120, sortable: true }
            ]
            /* rowsFrom 是外层根的函数 —— 跨作用域引用，qmllint 静态解析
             * 不到（与 QSkinSelect delegate 同款局限），局部关闭。 */
            // qmllint disable unqualified
            rows: rowsFrom(files)
            // qmllint enable unqualified

            selectedRow: state.selectedRow
            onRowClicked: function(index) { state.selectedRow = index }
            checkable: true
            onSelectionChanged: state.lastAction = "勾选变更（" + selectedIndexes.length + " 项）"

            /* 右键呼出菜单。这里在 QSkinTable（别的文件的作用域）内部引用
             * 外层 id —— 与 QSkinSelect delegate 同款 qmllint 局限，局部关闭。 */
            // qmllint disable unqualified
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                cursorShape: Qt.ArrowCursor
                onClicked: function(mouse) {
                    menu.openAt(mouse.x, mouse.y)
                }
            }
            // qmllint enable unqualified
        }

        /* ── 状态行 + 分页条（与表格客户端分页联动） ── */
        QSkinRow {
            gap: Theme.space.md

            Body {
                text: state.selectedRow >= 0
                      ? "已选中第 " + (state.selectedRow + 1) + " 行："
                        + table.rows[table._sourceIndex(state.selectedRow)].name
                      : "点击行选中；点表头排序（升→降循环）；勾选 checkbox 多选，表头 checkbox 全选。"
            }

            Spacer { }

            QSkinPagination {
                total: table.rowCount
                page: table.page
                pageSize: table.pageSize
                showTotal: true
                onPaged: function(p) { table.page = p }
            }
        }

        /* ── 菜单演示（分隔线计高回归） ── */
        QSkinRow {
            gap: Theme.space.md

            QSkinButton {
                id: moreBtn

                text: "更多操作"
                icon: Slots.chevronIndicator
                iconDirection: "down"
                onClicked: {
                    var p = moreBtn.mapToItem(win.contentItem, 0, moreBtn.height)
                    menu.openAt(p.x, p.y + Theme.space.xs)
                }
            }

            QSkinTooltip { text: "分隔线不再按整行计高，面板底部没有多余空白"; target: moreBtn }

            Body { text: "最近菜单动作：" + state.lastAction }
        }

        /* 长说明要换行 —— 撑满内宽靠 Layout.fillWidth，不是 width（见 HelloFoundation 注释） */
        Caption {
            Layout.fillWidth: true

            text: "M5 契约扩展：浮层 contentHeight 上报、label 插槽 header 变体。" +
                  "M6 纯行为扩展：列排序（内置比较器 + sortChanged 信号）、多选（selectedIndexes 存数据下标）。" +
                  "M7 分页：QSkinPagination 独立控件 + 表格客户端分页（pageSize > 0 自动切片），勾选跨页跟数据走。"
        }
    }

    QSkinMenu {
        id: menu

        model: [
            "打开",
            "下载",
            "separator",
            "重命名",
            { text: "删除", danger: true }
        ]
        onTriggered: function(index) {
            var it = menu.model[index]
            state.lastAction = typeof it === "string" ? it : it.text
        }
    }
}
