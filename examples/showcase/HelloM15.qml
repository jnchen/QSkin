/****************************************************************************
 * QSkin · 示例 —— M15：QSkinTable 树形 + 键语义勾选（级联 / 半选态）
 *
 *   · treeMode + checkable 同时开 → 勾选列**出现**（M14 时是互斥的，M15 撤了）
 *   · 寻址换成**键**：`selectedKeys`（完全选中的键）而不是 `selectedIndexes`
 *     （数据下标）—— 折叠分支里的节点不在 rows 里，下标会指到别的行上
 *   · 勾一个父 → 父与全部后代一起选中；取消一个孙 → 祖先逐个退出集合、
 *     转成**半选**（蓝底横线，不是勾）
 *   · 级联只看**结构**、不看**可见性**：全部收起之后再勾父，展开照样全亮
 *   · checkStrictly → 父子不关联：勾父不带子，也不会有半选
 *
 * 想看的四个对比：
 *   ① 点 src 那一行的勾选框 → src 与它整棵子树一起亮；再点 contracts 行
 *      的勾选框（此时它是全选）→ 整枝取消，src 保持全选（docs / tests 还没勾）
 *   ② 点 contracts 的勾选框 → 它整枝亮了，**src 变成半选**（横线）。
 *      再单独取消 QSkinSelect.qml → contracts 退回半选，src 仍是半选 ——
 *      这就是"祖先状态是推导出来的、不写进集合"的直观表现
 *   ③ 点「全部收起」→ 只剩三个根；此时点 src 的勾选框 → src 全选。
 *      再点「全部展开」→ 被折叠的那些子节点**已经是勾上的**。
 *      级联如果拿可见行算，这里会漏掉它们
 *   ④ 打开「父子关联」→ 变严格模式：再点 contracts 的勾选框，子节点
 *      一个都不亮，src 也不会半选
 *
 * ── 为什么到处写 Layout.fillWidth 而不是 width: page.width ──────────────
 * QSkinColumn / QSkinRow 内部是 ColumnLayout / RowLayout，子项宽度由 Layout
 * 按 preferredWidth 决定。**Text 系（Caption / Body / Heading）的显式
 * width 会被静默忽略**（Layout 拿 Text 的 implicitWidth 当 preferredWidth），
 * 于是 wrapMode: WordWrap 形同虚设、长文本溢出窗口右沿。
 * 正解是 import QtQuick.Layouts + Layout.fillWidth。完整说明见 M13 章节。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0
import QSkin.Theme.AntDesign 1.0
import QSkin.Theme.ArcoDesign 1.0
import QSkin.Theme.Shadcn 1.0

QSkinWindow {
    id: win

    width: 1180
    height: 760
    visible: true
    title: "QSkin · M15 — QSkinTable 树形勾选（级联 / 半选态）"

    QtObject {
        id: state

        property int selectedRow: -1
        property bool narrowCol: false
        property string lastEvent: "—"
    }

    /* ── 三层树：9 个节点，缩进正好三档 0 / 1×indent / 2×indent ──────────
     *   src                     (0)
     *     contracts             (1)
     *       QSkinTable.qml        (2)
     *       QSkinSelect.qml       (2)
     *     foundation            (1)
     *       Theme.qml           (2)
     *   docs                    (0)
     *     README.md             (1)
     *   tests                   (0)
     *     smoke_m15.qml         (1)
     *
     * 故意留出两种形状：contracts 有**两个**子（半选要靠它演示），
     * foundation 只有**一个**子（勾满即父全选，不会半选）。 */
    property var treeData: [
        { id: "src", name: "src", kind: "目录", lines: 0, status: "已同步",
          owner: "林一", time: "2026-09-12 01:10", children: [
            { id: "contracts", name: "contracts", kind: "目录", lines: 0, status: "评审中",
              owner: "张三", time: "2026-09-12 01:10", children: [
                { id: "qml-table",  name: "QSkinTable.qml",  kind: "文件", lines: 2045,
                  status: "评审中", owner: "张三", time: "2026-09-12 01:10" },
                { id: "qml-select", name: "QSkinSelect.qml", kind: "文件", lines: 610,
                  status: "已同步", owner: "李四", time: "2026-09-05 10:30" }
            ] },
            { id: "foundation", name: "foundation", kind: "目录", lines: 0, status: "已同步",
              owner: "陈二", time: "2026-09-10 22:41", children: [
                { id: "qml-theme", name: "Theme.qml", kind: "文件", lines: 260,
                  status: "已同步", owner: "陈二", time: "2026-09-10 22:41" }
            ] }
        ] },
        { id: "docs", name: "docs", kind: "目录", lines: 0, status: "已同步",
          owner: "林一", time: "2026-09-11 14:35", children: [
            { id: "readme", name: "README.md", kind: "文件", lines: 1530,
              status: "已同步", owner: "林一", time: "2026-09-11 14:35" }
        ] },
        { id: "tests", name: "tests", kind: "目录", lines: 0, status: "评审中",
          owner: "王五", time: "2026-09-12 01:10", children: [
            { id: "smoke-15", name: "smoke_m15.qml", kind: "文件", lines: 320,
              status: "评审中", owner: "王五", time: "2026-09-12 01:10" }
        ] }
    ]

    function nameColWidth() { return state.narrowCol ? 120 : 260 }

    function keysText() {
        return table.selectedKeys.length > 0 ? table.selectedKeys.join(", ") : "（空）"
    }

    QSkinColumn {
        id: page

        anchors.fill: parent
        padding: Theme.space.xl
        gap: Theme.space.sm

        /* ── 头部：标题 + 主题切换 ── */
        QSkinRow {
            fill: true
            gap: Theme.space.sm

            Heading { text: "M15 · QSkinTable 树形勾选（级联 / 半选态）" }

            Spacer { }

            QSkinButton { text: "Neutral"; variant: "ghost"; onClicked: { Slots.reset(); Theme.reset() } }
            QSkinButton { text: "TDesign"; variant: "ghost"; onClicked: TDesign.apply() }
            QSkinButton { text: "Ant";     variant: "ghost"; onClicked: AntDesign.apply() }
            QSkinButton { text: "Arco";    variant: "ghost"; onClicked: ArcoDesign.apply() }
            QSkinButton { text: "shadcn";  variant: "ghost"; onClicked: Shadcn.apply() }
            QSkinButton {
                variant: "ghost"
                text: Theme.mode === "dark" ? "浅色" : "深色"
                onClicked: Theme.mode = (Theme.mode === "dark") ? "light" : "dark"
            }
        }

        Caption {
            Layout.fillWidth: true

            text: "treeMode + checkable —— 勾选走**键**（selectedKeys），不走数据下标"
                  + "（折叠分支里的节点不在 rows 里，下标会指到别的行上）。"
                  + "勾父带下整棵子树；取消一个子孙会让祖先逐个退出集合并转成半选。"
                  + "级联只看结构、不看可见性：收起的分支照样参与计算。"
        }

        /* ── 工具条 ── */
        QSkinRow {
            fill: true
            gap: Theme.space.sm

            QSkinButton {
                text: "全选"
                onClicked: { table.selectAll(); state.lastEvent = "selectAll()" }
            }

            QSkinButton {
                text: "清空"
                onClicked: { table.clearSelection(); state.lastEvent = "clearSelection()" }
            }

            QSkinButton {
                text: "父子关联：" + (table.checkStrictly ? "关" : "开")
                onClicked: {
                    table.checkStrictly = !table.checkStrictly
                    state.lastEvent = "checkStrictly = " + table.checkStrictly
                }
            }

            QSkinButton {
                text: "全部展开"
                onClicked: { table.expandAll(); state.lastEvent = "expandAll()" }
            }

            QSkinButton {
                text: "全部收起"
                onClicked: { table.collapseAll(); state.lastEvent = "collapseAll()" }
            }

            QSkinButton {
                text: state.narrowCol ? "树列：120（窄）" : "树列：260"
                onClicked: {
                    state.narrowCol = !state.narrowCol
                    /* M12 的列宽快照优先级高于 columns 里的显式 width ——
                     * 拖过列宽之后不清掉快照，这里的宽度切换就不生效。 */
                    table.resetColumnWidths()
                    state.lastEvent = "树列宽 " + win.nameColWidth()
                }
            }

            Spacer { }

            Body {
                text: "可见行 " + table.displayRows.length
                      + " · 全树 " + table._treeIndex.count + " 节点"
            }
        }

        /* ── 表格：树形 + 勾选 + 默认全展开 ── */
        QSkinTable {
            id: table

            Layout.fillWidth: true
            treeMode: true
            checkable: true
            defaultExpandAll: true
            emptyText: "没有节点"

            columns: [
                { title: "名称",     dataIndex: "name",   width: win.nameColWidth(),
                  sortable: true, resizable: true },
                { title: "类型",     dataIndex: "kind",   width: 80,  sortable: true },
                { title: "行数",     dataIndex: "lines",  width: 90,  align: "right", sortable: true },
                { title: "状态",     dataIndex: "status", width: 100, sortable: true },
                { title: "负责人",   dataIndex: "owner",  width: 90,  sortable: true },
                { title: "更新时间", dataIndex: "time" }
            ]

            rows: win.treeData
            selectedRow: state.selectedRow
            onRowClicked: function(index) { state.selectedRow = index }
            onKeySelectionChanged: function(keys) {
                state.lastEvent = "选中键 = [" + keys.join(", ") + "]"
            }
            onExpandToggled: function(key, expanded) {
                state.lastEvent = (expanded ? "展开 " : "收起 ") + key
            }
        }

        /* ── 状态栏：三组数各报各的，半选是**独立**的一类 ── */
        Caption {
            Layout.fillWidth: true

            text: "完全选中 " + table.selectedKeys.length + " 个："
                  + win.keysText()
                  + "　·　半选 " + table.indeterminateKeys.length + " 个："
                  + (table.indeterminateKeys.length > 0
                     ? table.indeterminateKeys.join(", ")
                     : "（无）")
                  + "　·　selectedRows " + table.selectedRows.length + " 行"
        }

        Caption {
            Layout.fillWidth: true

            text: "上次操作：" + state.lastEvent
                  + "　·　表头三态：" + (table._allSelected ? "全选"
                                        : (table._someSelected ? "半选" : "未选"))
                  + "　·　缩进上限 " + table._treeMaxIndent(table._treeColumnWidth()) + "px"
        }
    }
}
