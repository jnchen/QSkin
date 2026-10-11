/****************************************************************************
 * QSkin · 示例 —— M14：QSkinTable 树形展开
 *
 *   · treeMode: true → rows 是树根数组，子节点挂在 children 下，层级不限深
 *   · 点行首箭头展开 / 收起；折叠是**整枝**剪掉 —— 父收起时子辈连同它们
 *     自己的展开状态一起不出现，层级不限深也只需展平一遍
 *   · 展开状态按 treeKey（默认 "id"）记，**不按结构路径**：路径会随同级
 *     排序漂移，键不会
 *   · 点表头（或工具条）排序 → 只有**同级兄弟**换序，绝不跨层搬行
 *   · 树列宽 260 ↔ 120 → 窄到装不下时缩进被夹住，而不是把文字挤没
 *   · 视图 树形 ↔ 平铺 → 平铺时 children 被忽略
 *   · 勾选列在两种视图下**都出现**（M15 撤掉了互斥）；差别在**寻址**：
 *     平铺用 selectedIndexes（数据下标），树形用 selectedKeys（键）
 *
 * 想看的四个对比：
 *   ① 全部收起 → 点 src 的箭头：只有 src 那一枝打开，其余仍收着
 *   ② 点「排序」：顶层与每层兄弟各自换序，父子关系纹丝不动
 *      （判据不是"顺序对不对"，而是"键 → 层级的归属一个都没变"）
 *   ③ 树列切到 120：二级缩进不再比一级更右（上限生效），文字没被挤没；
 *      上限 = 列宽 − 左右内边距 − 箭头位 − treeMinLabelWidth
 *   ④ 切到平铺：勾选列还在，但可勾的**行**变少了 —— 平铺下只有顶层
 *      3 个根（嵌套节点不单独成行），树形下 9 个节点都能勾。
 *      勾选语义本身见 HelloM15.qml
 *
 * ── 为什么到处写 Layout.fillWidth 而不是 width: page.width ──────────────
 * QSkinColumn / QSkinRow 内部是 ColumnLayout / RowLayout，子项宽度由 Layout
 * 按 preferredWidth 决定。**Text 系（Caption / Body / Heading）的显式
 * width 会被静默忽略**（Layout 拿 Text 的 implicitWidth 当 preferredWidth），
 * 于是 wrapMode: WordWrap 形同虚设、长文本溢出窗口右沿。
 * 正解是 import QtQuick.Layouts + Layout.fillWidth。完整说明见 M13 章节。
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

    width: 1080
    height: 720
    visible: true
    title: "QSkin · M14 — QSkinTable 树形展开"

    QtObject {
        id: state

        property int selectedRow: -1
        property bool narrowCol: false
        property string lastEvent: "—"
    }

    /* ── 三层树 ──────────────────────────────────────────────────────────
     * 全展开 11 个可见行，缩进三档 0 / 1×indent / 2×indent：
     *   src        (0)
     *     contracts    (1)   QSkinTable.qml(2)   QSkinSelect.qml(2)
     *     foundation   (1)   Theme.qml(2)      QSkinRow.qml(2)
     *   docs       (0)     README.md(1)
     *   tests      (0)     smoke_m14.qml(1)
     * 名称与行数刻意错开，好让"同级排序"真的会换序。 */
    property var treeData: [
        { id: "src", name: "src", kind: "目录", lines: 0, status: "已同步",
          owner: "林一", time: "2026-09-11 09:12", children: [
            { id: "contracts", name: "contracts", kind: "目录", lines: 0, status: "评审中",
              owner: "张三", time: "2026-09-11 14:02", children: [
                { id: "qml-table",  name: "QSkinTable.qml",  kind: "文件", lines: 1572,
                  status: "评审中", owner: "张三", time: "2026-09-11 14:02" },
                { id: "qml-select", name: "QSkinSelect.qml", kind: "文件", lines: 610,
                  status: "已同步", owner: "张三", time: "2026-09-05 10:30" }
            ] },
            { id: "foundation", name: "foundation", kind: "目录", lines: 0, status: "已同步",
              owner: "陈二", time: "2026-09-10 22:41", children: [
                { id: "qml-theme", name: "Theme.qml", kind: "文件", lines: 260,
                  status: "已同步", owner: "陈二", time: "2026-09-10 22:41" },
                { id: "qml-row",   name: "QSkinRow.qml",   kind: "文件", lines: 180,
                  status: "已同步", owner: "陈二", time: "2026-09-04 16:05" }
            ] }
        ] },
        { id: "docs", name: "docs", kind: "目录", lines: 0, status: "已同步",
          owner: "林一", time: "2026-09-11 14:35", children: [
            { id: "readme", name: "README.md", kind: "文件", lines: 1530,
              status: "已同步", owner: "林一", time: "2026-09-11 14:35" }
        ] },
        { id: "tests", name: "tests", kind: "目录", lines: 0, status: "评审中",
          owner: "王五", time: "2026-09-11 13:20", children: [
            { id: "smoke-14", name: "smoke_m14.qml", kind: "文件", lines: 426,
              status: "评审中", owner: "王五", time: "2026-09-11 13:20" }
        ] }
    ]

    /* 名称列的宽度：窄列模式给 120，好让缩进上限真的夹住（见上文 ③） */
    function nameColWidth() { return state.narrowCol ? 120 : 260 }

    QSkinColumn {
        id: page

        anchors.fill: parent
        padding: Theme.space.xl
        gap: Theme.space.md

        /* ── 头部：标题 + 主题切换 ── */
        QSkinRow {
            fill: true
            gap: Theme.space.sm

            Heading { text: "M14 · QSkinTable 树形展开" }

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

            text: table.treeMode
                  ? "treeMode 开 —— rows 是树根数组，子节点挂在 " + table.treeChildrenKey
                    + " 下（层级不限深）。点行首箭头展开 / 收起，折叠是整枝剪掉；"
                    + "展开状态按 treeKey = \"" + table.treeKey + "\" 记，不按结构路径。"
                    + "树形下排序只作用于同级节点；勾选走键（selectedKeys），"
                    + "所以折叠分支里的节点照样能被勾上。"
                  : "treeMode 关 —— children 被忽略，只剩 " + table.displayRows.length
                    + " 个顶层节点（嵌套节点不单独成行）。勾选改回 selectedIndexes"
                    + "（数据下标）—— 平铺模式下这两种寻址恰好等价，"
                    + "但树形一折叠就分道扬镳（详见 HelloM15.qml）。"
        }

        /* ── 工具条：M14 的四个开关 ── */
        QSkinRow {
            fill: true
            gap: Theme.space.sm

            QSkinButton {
                text: "全部展开"
                onClicked: { table.expandAll(); state.lastEvent = "expandAll()" }
            }

            QSkinButton {
                text: "全部收起"
                onClicked: { table.collapseAll(); state.lastEvent = "collapseAll()" }
            }

            /* 循环切列：无 → 名称 → 类型 → 行数 → 无。
             * 真实用法是点表头（sortable: true），这里为了一键演示。 */
            QSkinButton {
                text: "排序：" + (table.sortColumn < 0 || table.sortColumn >= table.columnCount
                                 ? "无"
                                 : table.columns[table.sortColumn].title
                                   + (table.sortDirection === "desc" ? " ↓" : " ↑"))
                onClicked: {
                    var next = table.sortColumn + 1
                    if (next >= 3) { table.sortColumn = -1; table.sortDirection = "asc" }
                    else           { table.sortColumn = next; table.sortDirection = "asc" }
                    state.lastEvent = table.sortColumn < 0
                                      ? "清除排序"
                                      : "排序第 " + table.sortColumn + " 列（只动同级）"
                }
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

            QSkinButton {
                text: table.treeMode ? "视图：树形" : "视图：平铺"
                onClicked: {
                    table.treeMode = !table.treeMode
                    state.lastEvent = "treeMode = " + table.treeMode
                }
            }

            Spacer { }

            Body {
                text: "可见行 " + table.displayRows.length
                      + " · 树列 " + Math.round(table._treeColumnWidth()) + "px"
                      + " · 缩进上限 " + table._treeMaxIndent(table._treeColumnWidth()) + "px"
            }
        }

        /* ── 表格：树形 + 默认全展开 + 勾选（M15 起两种视图都出现） ── */
        QSkinTable {
            id: table

            Layout.fillWidth: true
            treeMode: true
            defaultExpandAll: true
            checkable: true
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
            onExpandToggled: function(key, expanded) {
                state.lastEvent = (expanded ? "展开 " : "收起 ") + key
            }
        }

        Caption {
            Layout.fillWidth: true

            text: "上次操作：" + state.lastEvent
                  + "　·　已展开的键："
                  + (table.expandedKeys.length > 0
                     ? table.expandedKeys.join(", ")
                     : "（无 —— 只列被「显式」展开的键，没被设置过的节点走 defaultExpandAll = "
                       + table.defaultExpandAll + "）")
        }
    }
}
