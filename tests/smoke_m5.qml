/****************************************************************************
 * QSkin · 冒烟测试 —— M5：QSkinTable / 浮层 contentHeight 契约扩展
 *
 * 断言写法见 tools/test.sh 文件头：≤ 8 条，bit n = 断言 [n]。
 * 尺寸断言必须在事件循环跑过至少一轮之后（Layouts 的 polish 时序）。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0

/* 直接实例化 TDesign 的浮层外壳，验证 contentHeight 契约在主题层生效 */
import "../src/themes/tdesign/slots"

Item {
    id: root

    property int failures: 0
    property int clicks: 0

    function expect(ok) { if (!ok) root.failures++ }

    QSkinTable {
        id: table

        width: 400
        columns: [
            { title: "文件名", dataIndex: "name", width: 200 },
            { title: "大小",   dataIndex: "size", align: "right" },
            { title: "状态",   dataIndex: "status" }
        ]
        rows: [
            { name: "a.qml", size: "4 KB", status: "已同步" },
            { name: "b.qml", size: "12 KB", status: "草稿" }
        ]
        onRowClicked: root.clicks++
    }

    QSkinTable { id: emptyTable; width: 400; columns: [{ title: "A", dataIndex: "a" }] }

    QSkinMenu {
        id: menu

        /* 4 个条目 + 1 条分隔线：contentHeight = 4*32 + (1+4*2) = 137 */
        model: ["重命名", "复制链接", "separator", "移动到…", "删除"]
        onTriggered: root.clicks += 10
    }

    /* Basic 外壳：宿主上报 contentHeight 时优先采用（108），
     * 未上报时按等高行估算（3 行 × 32 + padding*2 = 104） */
    QtObject {
        id: fakeCtl

        property real contentHeight: 100
        property int  count: 3
        property int  maxVisibleRows: 6
        property int  rowHeight: 32
        property real width: 180
    }

    QtObject {
        id: fakeCtlPlain

        property int  count: 3
        property int  maxVisibleRows: 6
        property int  rowHeight: 32
        property real width: 180
    }

    Loader {
        id: shellPrecise
        sourceComponent: Slots.selectOverlay
    }
    Loader {
        id: shellPlain
        sourceComponent: Slots.selectOverlay
    }
    Binding { target: shellPrecise.item; property: "control"; value: fakeCtl;       when: shellPrecise.item !== null }
    Binding { target: shellPlain.item;   property: "control"; value: fakeCtlPlain;  when: shellPlain.item   !== null }

    /* 表头变体经 Slots.label 渲染：Basic 的 header → 半粗 */
    QtObject {
        id: headerCtl

        property string text: "表头"
        property string variant: "header"
        property int labelAlignment: Text.AlignLeft
    }

    Loader {
        id: headerLabel
        sourceComponent: Slots.label
    }
    Binding { target: headerLabel.item; property: "control"; value: headerCtl; when: headerLabel.item !== null }

    TDSelectOverlay { id: tdOverlay; control: fakeCtl }

    Timer { id: stage1Timer; interval: 300; running: true; onTriggered: root.stage1() }
    Timer { id: stage2Timer; interval: 300; running: false; onTriggered: root.stage2() }

    function stage1() {
        /* [0] 表格尺寸：表头 + 2 行；列布局 = 定宽 200 + 两列平分剩余 200 */
        root.expect(table.implicitHeight === table.headerHeight + table.rowHeight * 2
                    && table.colLayout.xs[0] === 0
                    && table.colLayout.xs[1] === 200
                    && table.colLayout.widths[1] === 100
                    && table.colLayout.widths[2] === 100)

        /* [1] 单元格取值与对齐：dataIndex 映射、右对齐列生效 */
        root.expect(table._cellText(table.rows[1], table.columns[0]) === "b.qml"
                    && table._alignOf(table.columns[1]) === Text.AlignRight
                    && table._alignOf(table.columns[0]) === Text.AlignLeft)

        /* [2] 行点击 / 选中 / 上键回退 */
        table._select(1)
        table._move(-1)
        root.expect(table.selectedRow === 0 && root.clicks === 1)

        /* [3] 空表：表体保底 2 行高的占位区 */
        root.expect(emptyTable.rowCount === 0
                    && emptyTable.implicitHeight === emptyTable.headerHeight + emptyTable.rowHeight * 2)

        /* [4] 菜单内容精确高度：4 行 × 32 + 分隔线(1 + 4*2) = 137（M4 的瑕疵在这条上回归） */
        root.expect(menu._contentHeight() === 137)

        /* [5] Basic 外壳：上报 contentHeight → 100 + 4*2 = 108；未上报 → 3*32 + 8 = 104 */
        root.expect(shellPrecise.item !== null && shellPlain.item !== null
                    && shellPrecise.item.implicitHeight === 108
                    && shellPlain.item.implicitHeight === 104)

        /* [6] header 变体走 label 插槽：Basic 渲染为半粗字重 */
        root.expect(headerLabel.item !== null
                    && headerLabel.item.font.weight === Theme.font.weightSemiBold)

        menu.openAt(20, 20)
        stage2Timer.start()
    }

    function stage2() {
        /* [7] 菜单展开 + 触发；主题浮层的 contentHeight 契约同步生效
         * （TDesign 外壳：100 + padding*2，与 Basic 同一条契约） */
        menu._trigger(0)
        root.expect(menu.opened === false
                    && root.clicks === 11
                    && tdOverlay.implicitHeight === fakeCtl.contentHeight + tdOverlay.padding * 2)

        Qt.exit(root.failures & 0xFF)
    }
}
