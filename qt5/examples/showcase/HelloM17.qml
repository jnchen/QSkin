/****************************************************************************
 * QSkin · 示例 —— M17：QSkinTree（一维树）+ 与 QSkinTable 树形模式并排对拍
 *
 * 这轮做了两件事，示例按这两件事来摆：
 *
 *   ① 树逻辑下沉到 `QSkin.Foundation.TreeUtil`（纯计算、无 UI 决策）。
 *      **能看见的证据**：下面左右两个控件用**同一份数据**、做**同一串操作**，
 *      勾选结果必须逐字相同。谁要是自己留了一份树算法，这一屏就会出现
 *      "左边勾了右边没动"。
 *
 *   ② 新做 QSkinTree。它和 QSkinTable 树形模式共用词汇表（treeKey /
 *      expandedKeys / selectedKeys / checkStrictly …），因为它俩背后是
 *      同一份实现。**换控件不用换词汇**，这是下沉真正买来的东西。
 *
 * ── 想看的五件事 ───────────────────────────────────────────────────────
 *   ① 点左边 src 的勾选框 → 整棵子树亮；右边表格**同步**亮（同一个集合）
 *   ② 只勾 src/contracts 里的 QSkinTable.qml → src 与 contracts 转**半选**
 *      （横线，不是勾）。半选是**推导**出来的，不写进 selectedKeys
 *      —— 状态栏里能看到"完全选中 N 个"与"半选 M 个"是两组独立的数
 *   ③ 点一下「全部收起」再勾 src → src 全选；再「全部展开」→ 那些**看不见
 *      的**后代已经是勾上的。级联只看结构、不看可见性，这是最容易写错
 *      的一处（拿可见行去算的实现会在这里漏掉整枝）
 *   ④ 点树里任意一行 → 出现行高亮。再点「全部收起」→ 高亮**不见了**。
 *      再「全部展开」→ 高亮回到**原来那个节点**上，而不是第 N 行。
 *      游标按键记、不按下标 —— 这是 M14/M15 换来的结论
 *   ⑤ 键盘：先点一下树（拿到焦点），然后 ↑↓ 移动、←→ 展开/收起
 *      （没有可展开的东西时 ←→ 退化成移动）、空格切勾选、回车等同点击。
 *      左右键的退化行为是资源管理器 / Finder 的通行做法
 *
 * ── 这个文件是渲染侧的验收口 ───────────────────────────────────────────
 * `tests/smoke_m17.qml` 守的是**属性值**（8 条断言，每条都被变异测试证伪过）。
 * 但属性值对 ≠ 界面画对 —— M14 实录：6 处渲染点漏了 1 处，断言永远绿。
 * 所以下面这一屏存在的理由就是"看得见"：
 *   · 箭头朝哪个方向（展开 = down / 收起 = right）
 *   · 叶子**不画**箭头，但那个位子照样空着（否则同层文字左沿不齐）
 *   · 缩进在窄窗里会停住（宁可少缩，也不让文字被挤没）
 *   · 勾选框半选是横线、不是勾
 *   · 四套主题下这些形状都由插槽决定，控件自己不画
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

    width: 1240
    height: 800
    visible: true
    title: "QSkin · M17 — QSkinTree + TreeUtil 下沉"

    QtObject {
        id: state

        property string lastEvent: "—"
        property bool disabledOn: false
        property bool compact: false
    }

    /* ── 两层到三层的树：11 个节点，缩进正好三档 ────────────────────────
     *   src                     (0)
     *     contracts             (1)
     *       QSkinTable.qml        (2)
     *       QSkinSelect.qml       (2)
     *       QSkinTree.qml         (2)   ← M17 新加的那个，顺手把自己写进去
     *     foundation            (1)
     *       TreeUtil.qml        (2)
     *       Theme.qml           (2)
     *   docs                    (0)
     *     README.md             (1)
     *   tests                   (0)
     *     smoke_m17.qml         (1)
     *
     * 刻意留出三种形状：
     *   contracts 有**三个**子  → 半选演示的主场
     *   foundation 有**两个**子 → 取消一个就半选
     *   docs / tests 只有**一个**子 → 勾满即父全选，永远不半选
     */
    property var treeData: [
        { id: "src", name: "src", kind: "目录", lines: 0, status: "已同步",
          owner: "林一", time: "2026-09-12 01:10", children: [
            { id: "contracts", name: "contracts", kind: "目录", lines: 0, status: "评审中",
              owner: "张三", time: "2026-09-12 01:10", children: [
                { id: "qml-table",  name: "QSkinTable.qml",  kind: "文件", lines: 2090,
                  status: "评审中", owner: "张三", time: "2026-09-12 01:10" },
                { id: "qml-select", name: "QSkinSelect.qml", kind: "文件", lines: 610,
                  status: "已同步", owner: "李四", time: "2026-09-05 10:30" },
                { id: "qml-tree",   name: "QSkinTree.qml",   kind: "文件", lines: 877,
                  status: "新增",   owner: "林一", time: "2026-09-12 23:40" }
            ] },
            { id: "foundation", name: "foundation", kind: "目录", lines: 0, status: "已同步",
              owner: "陈二", time: "2026-09-10 22:41", children: [
                { id: "qml-treeutil", name: "TreeUtil.qml", kind: "文件", lines: 510,
                  status: "新增",   owner: "林一", time: "2026-09-12 23:40" },
                { id: "qml-theme",    name: "Theme.qml",    kind: "文件", lines: 260,
                  status: "已同步", owner: "陈二", time: "2026-09-10 22:41" }
            ] }
        ] },
        { id: "docs", name: "docs", kind: "目录", lines: 0, status: "已同步",
          owner: "林一", time: "2026-09-11 14:35", children: [
            { id: "readme", name: "README.md", kind: "文件", lines: 1530,
              status: "已同步", owner: "林一", time: "2026-09-11 14:35" }
        ] },
        { id: "tests", name: "tests", kind: "目录", lines: 0, status: "评审中",
          owner: "王五", time: "2026-09-12 23:40", children: [
            { id: "smoke-17", name: "smoke_m17.qml", kind: "文件", lines: 694,
              status: "评审中", owner: "王五", time: "2026-09-12 23:40" }
        ] }
    ]

    /** 两边都做一遍同一个操作 —— 对拍的唯一手法 */
    function both(fn) { fn(tree); fn(table) }

    function keysText(t) {
        return t.selectedKeys.length > 0 ? t.selectedKeys.join(", ") : "（空）"
    }

    function indText(t) {
        return t.indeterminateKeys.length > 0 ? t.indeterminateKeys.join(", ") : "（无）"
    }

    /* 对拍判据。两边结果一致 → 下沉就没分叉。
     * 排过序再比，因为"顺序不同"不是语义差异（TreeUtil 两边都出前序，
     * 所以实际上也不会不同 —— 但断言不该依赖这个巧合）。 */
    function aligned(a, b) {
        var x = a.selectedKeys.slice().sort().join(",")
        var y = b.selectedKeys.slice().sort().join(",")
        var m = a.indeterminateKeys.slice().sort().join(",")
        var n = b.indeterminateKeys.slice().sort().join(",")
        return x === y && m === n
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

            Heading { text: "M17 · QSkinTree + TreeUtil 下沉" }

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

            text: "左边是 M17 新做的 **QSkinTree**（一维树），右边是 M14/M15 就有的"
                  + " **QSkinTable 树形模式**。两个控件、同一份数据、同一串操作 ——"
                  + "勾选结果必须逐字相同。它们背后是**同一份**树算法"
                  + "（QSkin.Foundation.TreeUtil，M17 从 QSkinTable 里搬出来沉下去的），"
                  + "所以这不是'两套实现碰巧对上'，而是'根本没有第二套实现'。"
        }

        /* ── 工具条 ── */
        QSkinRow {
            fill: true
            gap: Theme.space.sm

            QSkinButton {
                text: "全选"
                onClicked: { win.both(function(t) { t.selectAll() }); state.lastEvent = "selectAll()" }
            }

            QSkinButton {
                text: "清空"
                onClicked: { win.both(function(t) { t.clearSelection() }); state.lastEvent = "clearSelection()" }
            }

            QSkinButton {
                text: "父子关联：" + (tree.checkStrictly ? "关" : "开")
                onClicked: {
                    /* checkStrictly 必须两边一起改，否则对拍立刻分叉 —— 那是对拍
                     * 的正确行为（它测的是"同一道题两控件答案是否相同"） */
                    tree.checkStrictly = !tree.checkStrictly
                    table.checkStrictly = tree.checkStrictly
                    state.lastEvent = "checkStrictly = " + tree.checkStrictly
                }
            }

            QSkinButton {
                text: "全部展开"
                onClicked: { win.both(function(t) { t.expandAll() }); state.lastEvent = "expandAll()" }
            }

            QSkinButton {
                text: "全部收起"
                onClicked: { win.both(function(t) { t.collapseAll() }); state.lastEvent = "collapseAll()" }
            }

            Spacer { }
        }

        QSkinRow {
            fill: true
            gap: Theme.space.sm

            QSkinButton {
                text: "禁用 src：" + (state.disabledOn ? "开" : "关")
                onClicked: {
                    state.disabledOn = !state.disabledOn
                    tree.disabledKeys = state.disabledOn ? ["src"] : []
                    state.lastEvent = "disabledKeys = [" + (state.disabledOn ? "src" : "") + "]"
                }
            }

            QSkinButton {
                variant: "ghost"
                text: "行高：" + tree.rowHeight
                onClicked: {
                    state.compact = !state.compact
                    tree.rowHeight = state.compact ? 32 : 40
                    state.lastEvent = "rowHeight = " + tree.rowHeight
                }
            }

            QSkinButton {
                variant: "ghost"
                text: "勾选框：" + (tree.checkable ? "显示" : "隐藏")
                onClicked: {
                    tree.checkable = !tree.checkable
                    state.lastEvent = "checkable = " + tree.checkable
                }
            }

            Spacer { }

            Body { text: "焦点在：" + (tree.currentKey === "" ? "（无）" : tree.currentKey) }
        }

        /* ── 主区：树 | 表格，同一份数据 ── */
        QSkinRow {
            Layout.fillWidth: true
            Layout.fillHeight: true
            gap: Theme.space.lg
            align: "start"

            /* ══════════ 左：QSkinTree ══════════ */
            QSkinColumn {
                fill: true
                gap: Theme.space.xs

                Heading { level: 4; text: "QSkinTree —— nodes / 键寻址" }

                Caption {
                    Layout.fillWidth: true
                    text: "点一下树拿焦点，再按 ↑↓ 移动、←→ 展开收起、空格切勾选、回车等同点击。"
                }

                QSkinTree {
                    id: tree

                    Layout.fillWidth: true
                    Layout.preferredHeight: 420

                    nodes: win.treeData
                    treeKey: "id"
                    treeChildrenKey: "children"
                    textRole: "name"

                    checkable: true
                    defaultExpandAll: true
                    maxHeight: 420

                    onExpandToggled: function(key, expanded) {
                        state.lastEvent = (expanded ? "展开 " : "收起 ") + key
                    }
                    onNodeClicked: function(node, key, level) {
                        state.lastEvent = "点击 " + key + "（第 " + level + " 层）"
                    }
                    onKeySelectionChanged: function(keys) {
                        /* 只在**树**这一侧报事件 —— 两边都报会把状态栏刷成
                         * "同一件事说了两遍"，而对拍看的是下面的同/异 */
                        state.lastEvent = "勾选键 = [" + keys.join(", ") + "]"
                    }
                }

                Caption {
                    Layout.fillWidth: true
                    text: "完全选中 " + tree.selectedKeys.length + " 个"
                          + "　·　半选 " + tree.indeterminateKeys.length + " 个"
                          + "　·　可见行 " + tree.visibleCount + "/" + tree._treeIndex.count
                }
            }

            /* ══════════ 右：QSkinTable 树形模式（对拍基准）══════════ */
            QSkinColumn {
                fill: true
                gap: Theme.space.xs

                Heading { level: 4; text: "QSkinTable treeMode —— rows / 键语义（M14+M15）" }

                Caption {
                    Layout.fillWidth: true
                    text: "表格这侧是上一轮的产物，M17 只是把它的树算法换成了 TreeUtil。"
                          + "它多出来的列头、分隔线、列宽都还在 —— 树控件不画这些。"
                }

                QSkinTable {
                    id: table

                    Layout.fillWidth: true
                    /* ⚠ **不要写 `Layout.preferredHeight`**。

                       表格有 13 行 × rowHeight(40) + 表头 40 ≈ 560px，
                       把高度按成 420 就**内容溢出**，而 Qt 的 Layout
                       **不会**因为子项画出去而给别的项让位 —— 下面
                       那行「完全选中 N 个」被压住，两行字叠在一起。

                       `QSkinTable.implicitHeight` 已经是
                       `headerHeight + 行数 × rowHeight`，不设就是
                       **按内容撑**，这才是「内容有多少给多少」。

                       （M13/M14/M15/M16 与 HelloIcons 都没设，
                       只有本页设了 —— 孤例。）*/

                    treeMode: true
                    checkable: true
                    defaultExpandAll: true
                    treeIndentWidth: 20
                    emptyText: "没有节点"

                    columns: [
                        { title: "名称",     dataIndex: "name",   width: 200 },
                        { title: "类型",     dataIndex: "kind",   width: 70 },
                        { title: "行数",     dataIndex: "lines",  width: 80, align: "right" },
                        { title: "状态",     dataIndex: "status", width: 90 },
                        { title: "负责人",   dataIndex: "owner",  width: 80 },
                        { title: "更新时间", dataIndex: "time" }
                    ]

                    rows: win.treeData

                    onExpandToggled: function(key, expanded) {
                        state.lastEvent = (expanded ? "展开 " : "收起 ") + key
                    }
                }

                Caption {
                    Layout.fillWidth: true
                    text: "完全选中 " + table.selectedKeys.length + " 个"
                          + "　·　半选 " + table.indeterminateKeys.length + " 个"
                          + "　·　可见行 " + table.displayRows.length
                }
            }
        }

        /* ── 状态栏：这行是"下沉没分叉"的唯一判据 ── */
        Caption {
            Layout.fillWidth: true

            text: "两控件对拍：" + (win.aligned(tree, table)
                                   ? "**一致** ✓（同一份 TreeUtil）"
                                   : "**分叉** ✗ —— 有人自己留了一份树算法")
                  + "　·　树侧 [" + win.keysText(tree) + "]　半选 [" + win.indText(tree) + "]"
                  + "　·　上次操作：" + state.lastEvent
        }
    }
}
