/****************************************************************************
 * QSkin · 示例 —— M13：横向滚动 + 左侧固定列
 *
 *   · contentWidth 1400 > 容器宽 → 内容比容器宽，出现横向滚动
 *   · fixedColumns: 1 → 最左 1 列（+ 多选时的 checkbox 列）钉在左沿
 *   · 拖表格内部可平移（Flickable 拖动）；滚轮纵向、横向滚轮横向
 *   · 工具条按钮可以在运行时切换 fixedColumns 0/1/2 与 contentWidth 0/1400
 *   · 主题切换：Neutral / TDesign / Ant / Arco / shadcn（+ 浅深）
 *
 * 想看的三个对比：
 *   ① fixedColumns 0 ↔ 1 —— 钉住的那列在横滚时纹丝不动，右边照常滑
 *   ② contentWidth 0 ↔ 1400 —— 0 时撑满容器（= M12 行为），不出现横滚
 *   ③ 横滚开起来之后，固定区右沿那一道品牌色渐隐条才出现
 *
 * ── 为什么这里到处写 Layout.fillWidth 而不是 width: page.width ──────────
 * QSkinColumn / QSkinRow 内部是 ColumnLayout / RowLayout，子项宽度由 Layout
 * 按 preferredWidth 决定。**矩形**子项给显式 width 是有效的，但
 * **Text 系（Caption / Body / Heading）的显式 width 会被静默忽略** ——
 * Layout 拿 Text 的 implicitWidth（不换行的整行宽）当 preferredWidth，
 * 于是 wrapMode: WordWrap 形同虚设，长文本一路溢出到窗口右沿外面。
 * 症状见 M13 第一版截图。正解：import QtQuick.Layouts + Layout.fillWidth。
 *
 * 另外这个 import 不能省：`Layout` 是 QtQuick.Layouts 里的附加类型，
 * 用它的**文件**必须自己 import，import 不传递。漏了会报
 * "Non-existent attached object"，而且本环境默认看不到这条报错
 * （详见 README 第十一节第 4 条：QT_FORCE_STDERR_LOGGING=1）。
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

    width: 980
    height: 680
    visible: true
    title: "QSkin · M13 — 横向滚动 + 左侧固定列"

    QtObject {
        id: state

        property int selectedRow: -1
        property int contentW: 1400
    }

    /* 行数用数值（排序比较器对 number 走数值序；字符串会掉进字典序） */
    ListModel {
        id: files

        ListElement { name: "Slots.qml";         mod: "契约层"; lines: 420;  status: "已同步"; owner: "林一"; commit: "2026-09-11 09:12"; note: "插槽注册表" }
        ListElement { name: "Theme.qml";         mod: "基础层"; lines: 260;  status: "已同步"; owner: "陈二"; commit: "2026-09-10 22:41"; note: "令牌入口" }
        ListElement { name: "QSkinTable.qml";      mod: "契约层"; lines: 1010; status: "评审中"; owner: "张三"; commit: "2026-09-11 14:02"; note: "横滚 + 左固定列" }
        ListElement { name: "QSkinMenu.qml";       mod: "契约层"; lines: 330;  status: "已同步"; owner: "张三"; commit: "2026-09-06 17:30"; note: "分隔线计高修复" }
        ListElement { name: "tokens-tdesign.js"; mod: "主题层"; lines: 180;  status: "已同步"; owner: "李四"; commit: "2026-09-02 11:05"; note: "官方令牌" }
        ListElement { name: "tokens-shadcn.js";  mod: "主题层"; lines: 165;  status: "草稿";   owner: "李四"; commit: "2026-09-03 15:48"; note: "待补深色" }
        ListElement { name: "smoke_m13.qml";     mod: "测试";   lines: 240;  status: "评审中"; owner: "王五"; commit: "2026-09-11 13:20"; note: "8 条断言" }
        ListElement { name: "README.md";         mod: "文档";   lines: 1423; status: "已同步"; owner: "林一"; commit: "2026-09-11 14:35"; note: "M13 章节" }
    }

    /* ListModel → QSkinTable 要的普通对象数组（get() 返回的就是纯对象） */
    function rowsFrom(model) {
        var out = []
        for (var i = 0; i < model.count; ++i) out.push(model.get(i))
        return out
    }

    QSkinColumn {
        id: page

        anchors.fill: parent
        padding: Theme.space.xl
        gap: Theme.space.md

        /* ── 头部：标题 + 主题切换 ── */
        QSkinRow {
            fill: true
            gap: Theme.space.sm

            Heading { text: "M13 · 横向滚动 + 左侧固定列" }

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

        /* 说明单独占一行 —— Layout.fillWidth 让它换行，而不是溢出到窗口外 */
        Caption {
            Layout.fillWidth: true

            text: table.contentWidth > 0
                  ? "内容总宽 " + table.contentWidth + "px，容器 " + Math.round(table.width)
                    + "px —— 超出部分横向滚动；最左 " + table.fixedColumns
                    + " 列（含多选列）钉在左沿，纵向跟随表体。拖表格内部可平移，或用下面的按钮。"
                  : "contentWidth = 0 —— 内容撑满容器，不出现横向滚动（= M12 的行为）。"
        }

        /* ── 工具条：M13 的两个开关 + 滚动入口 ── */
        QSkinRow {
            fill: true
            gap: Theme.space.sm

            QSkinButton {
                text: table.fixedColumns === 0 ? "固定列：无" : "固定列：左 " + table.fixedColumns
                onClicked: table.fixedColumns = (table.fixedColumns + 1) % 3
            }

            QSkinButton {
                text: "内容宽：" + table.contentWidth
                onClicked: table.contentWidth = table.contentWidth > 0 ? 0 : state.contentW
            }

            QSkinButton { text: "左移"; icon: Slots.chevronIndicator; iconDirection: "left"
                        onClicked: table.scrollTo(table.scrollX - 240) }
            QSkinButton { text: "右移"; icon: Slots.chevronIndicator; iconDirection: "right"
                        onClicked: table.scrollTo(table.scrollX + 240) }
            QSkinButton { text: "滚到最左"; variant: "ghost"; onClicked: table.scrollTo(0) }
            QSkinButton { text: "滚到最右"; variant: "ghost"; onClicked: table.scrollTo(99999) }

            Spacer { }

            Body {
                text: table._canScrollX
                      ? "位置 " + Math.round(table.scrollX) + " / " + table._maxScrollX
                      : "无横向溢出"
            }
        }

        /* ── 表格：撑满容器，内容 1400 ── */
        QSkinTable {
            id: table

            Layout.fillWidth: true
            contentWidth: state.contentW   /* 0 = 撑满容器（M12 行为）*/
            fixedColumns: 1                /* 最左 1 列钉住 */
            checkable: true
            emptyText: "没有文件"

            columns: [
                { title: "文件名",   dataIndex: "name",   width: 240, sortable: true },
                { title: "模块",     dataIndex: "mod",    width: 140, sortable: true },
                { title: "行数",     dataIndex: "lines",  align: "right", width: 110, sortable: true },
                { title: "状态",     dataIndex: "status", width: 140, sortable: true },
                { title: "负责人",   dataIndex: "owner",  width: 140, sortable: true },
                { title: "最近提交", dataIndex: "commit", width: 220, sortable: true },
                { title: "说明",     dataIndex: "note" }
            ]
            /* rowsFrom 是外层根的函数 —— 跨作用域引用，qmllint 静态解析
             * 不到（与 QSkinSelect delegate 同款局限），局部关闭。 */
            // qmllint disable unqualified
            rows: rowsFrom(files)
            // qmllint enable unqualified

            selectedRow: state.selectedRow
            onRowClicked: function(index) { state.selectedRow = index }
        }

        Caption {
            Layout.fillWidth: true

            text: "M13 契约：contentWidth（0 = 撑满容器 / > 0 = 按此宽度排布，超出即横滚）"
                  + " + fixedColumns（最左 N 列不参与横滚；checkable 时 checkbox 列天然属于固定区）。"
                  + "单元格代码与 colLayout 返回契约一行未改 —— 双区结构由 clip 自动切分列归属。"
        }
    }
}
