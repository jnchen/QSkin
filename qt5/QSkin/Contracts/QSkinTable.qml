/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinTable
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 数据表格。M5 新增 —— 第一个"复杂控件"。
 *
 * ── 复杂控件的契约策略：不加新插槽 ────────────────────────────────────
 * 写完 Tabs / Menu 之后回头看表格，会发现它不需要新插槽：
 *
 *   表头底色    令牌就够 —— Neutral 的 bgSubtle 注释里写的本来就是"表头"，
 *               四套主题的 tokens.js 各自带上自己的表头灰
 *   行分隔线    令牌 border / borderStrong
 *   行 hover    令牌 bgSunken（与菜单项、下拉选项同一个下沉色）
 *   表头文字    复用 Slots.label，伪装成 variant "header"（M5 变体扩展）
 *   单元格文字  复用 Slots.label，默认变体
 *
 * 主题作者照旧八成抄令牌、两成在 label 里答一个 header 字重。
 * 控件侧一行颜色都没有 —— 契约第 2、3 条照常生效。
 *
 * ── 分工 ─────────────────────────────────────────────────────────────
 *   本文件：列布局（等分未定宽列 / 手动拖宽）、粘性表头、行 hover / 选中、
 *           排序（M6）、多选（M6）、空状态、上下键导航、垂直滚动、
 *           列宽拖拽 + 双击自适应（M12）、
 *           横向滚动 + 左侧固定列（M13）、
 *           树形展开（M14）、
 *           树形勾选：键语义 + 级联 + 半选态（M15）、Accessible.Table
 *   插槽：  Slots.label（表头 + 单元格文字）；checkbox 列直接复用 QSkinCheckBox
 *
 * 用法：
 *     QSkinTable {
 *         width: 560
 *         columns: [
 *             { title: "文件名", dataIndex: "name", width: 220,
 *               sortable: true, resizable: true },
 *             { title: "大小",   dataIndex: "size", align: "right", sortable: true },
 *             { title: "状态",   dataIndex: "status" }
 *         ]
 *         rows: [{ name: "a.qml", size: 4096, status: "已同步" }, ...]
 *         checkable: true                          // 首列出现 checkbox
 *         onRowClicked: (viewIndex) => { ... }     // 下标是当前显示顺序
 *         onSelectionChanged: doSomethingWith(selectedIndexes)  // 数据下标
 *         pageSize: 8                              // 客户端分页（M7）
 *         onPaged: (p) => pager.syncTo(p)          // 与 QSkinPagination 联动
 *         onColumnResized: (i, w) => { ... }       // 列宽拖完的回调（M12）
 *         contentWidth: 1200                       // 内容总宽（M13，超容器即横滚）
 *         fixedColumns: 1                          // 钉住最左 1 列（M13）
 *         fixedRightColumns: 1                     // 钉住最右 1 列（M16）
 *         treeMode: true                           // 树形（M14）
 *         checkable: true                          // 树形 + 勾选 → 走**键**寻址（M15）
 *         onKeySelectionChanged: (keys) => { ... } // 完全选中的键（半选不在其中）
 *         onSelectedKeysChanged: ...               // 同上，属性式写法
 *     }
 *
 * ── 两套下标，务必分清（M6）──────────────────────────────────────────
 *   显示下标  viewIndex   行的当前顺序。排序会打乱它 —— rowClicked /
 *             selectedRow 都用它，只适合"点过就消费"的场景
 *   数据下标  sourceIndex 行在 rows 里的原始位置。selectedIndexes 用它，
 *             checkbox 勾选的是"这条数据"，排序翻转后勾选不跟着跑
 *   换算：root._sourceIndex(viewIndex)
 *
 * ── 客户端分页（M7）──────────────────────────────────────────────────
 *   pageSize > 0 时启用：displayRows 先排序、再按 page 切片，表体只出
 *   当前页。selectedIndexes 存数据下标，跨页勾选仍然成立。selectedRow
 *   是显示下标，翻页即清空（页变了，位置失去意义）。
 *   服务端分页不用开 pageSize —— rows 只喂当前页数据，页码由外层
 *   QSkinPagination 自己管，两者正交。
 *
 * ── 列宽可拖（M12）──────────────────────────────────────────────────
 *   给列定义加 `resizable: true`，该列表头右沿出现拖拽热区：
 *   拖动改宽、双击按内容自适应。宽度存在 `columnWidths`（{下标: 宽度}），
 *   清空它即回到等分模式。拖拽一旦发生会把所有列的快照下来
 *   （原因见 setColumnWidth 的注释：不这么做，等分会在容器 resize 时
 *   把用户拖出的宽度洗掉）。最后一列不给拖 —— 它的右沿是表格边界。
 *
 * ── 横向滚动 + 左右固定列（M13 / M16）────────────────────────────────
 *   给 `contentWidth` 一个大于容器宽的值，内容就按那个宽度排布，
 *   多出来的部分靠横向滚动去看；`fixedColumns: N` 把最左 N 列钉住、
 *   `fixedRightColumns: M` 把最右 M 列钉住（M16），它们都不跟着横滚走。
 *   前者是后者的前提 —— 没有"内容比容器宽"这个前提，横向滚动根本
 *   无从谈起（M12 之前的列布局永远恰好撑满容器）。
 *
 *   实现是**三区**而非叠层：左右两个固定区各是一个 clip 的 Item
 *   （只跟纵向），中间区是一个 Flickable（横纵都管），三区互不重叠。
 *   列宽与 colLayout 全程用"内容坐标系"，分区的位移只落在宿主 Item 的
 *   x/y 上 —— 单元格自己一个字都不用改。
 *
 *   钉在右边和钉在左边是**两个不同的约束**：左固定区让内容左端贴左沿，
 *   右固定区让内容**右端**贴右沿。两边的列宽不同、且中间区宽度会随
 *   容器变 —— 所以"哪些列落在哪个区"不是按宽度切出来的，而是每区各自
 *   按自己的贴边约束把整个内容铺进去、再靠 clip 只露出自己那一段。
 *
 * ── 树形展开（M14）──────────────────────────────────────────────────
 *   `treeMode: true` 时 `rows` 是**树根数组**：子节点挂在 `treeChildrenKey`
 *   （默认 "children"）指向的字段下，层级不限深。展开状态按 `treeKey`
 *   （默认 "id"）记 —— **不按结构路径**，路径会随同级排序漂移，键不会。
 *
 *   树的每一步都只作用在**可见行序列**上：折叠起来的分支不进行数、不进分页、
 *   不渲染。`rowMeta` 是每个可见行的树信息
 *   （{ key, level, hasChildren, expanded, parentKey, sourceIndex }），
 *   缩进量、箭头状态、箭头热区全部从它推导，行 / 单元格不各算一份。
 *
 *   一条明确的边界：排序只作用于**同级节点**（递归地对每一层兄弟排序），
 *   绝不跨层搬行 —— 跨层移动会让别的节点凭空多出 / 少掉子节点，树就散了。
 *
 *   缩进从列宽里扣，而且**有上限**：第一列窄到装不下时停止继续缩进，
 *   而不是把文字挤没（上限 = 列宽 − 左右内边距 − 箭头位 − treeMinLabelWidth）。
 *   与 M13 的 minColumnWidth 同一条原则：宁可少缩进，也不让内容消失。
 *
 *   树形下的勾选见下一节（M15）—— M14 曾把"树形 + 勾选"整体挡在外面
 *   （理由：下标寻址在折叠分支上会指错行）。M15 的解法不是继续挡，
 *   而是**换一套寻址**。
 *
 * ── 树形勾选：键语义 + 级联 + 半选态（M15）────────────────────────────
 *   树形模式下开 `checkable`，勾选走 **`selectedKeys`（键数组）**，而不是
 *   `selectedIndexes`（数据下标）。原因就是 M14 那一条：折叠分支里的节点
 *   压根不在 `rows` 里，下标指的是别的行。
 *
 *   ── 两套并行的树视图（本节的枢纽）───────────────────────────────
 *       _visibleRows   受折叠影响，**剪枝**  → 渲染 / 分页（M14）
 *       _treeIndex     不受折叠影响，**全树** → 级联 / 祖先链 / 后代集（M15）
 *
 *   级联**不能**用可见行序列算：把父节点折叠起来，它的孩子就不在可见行
 *   里了 —— 父会从"半选"突然变成"全选"，因为"有孩子没被勾"这个事实
 *   被折叠藏起来了。勾选是**数据状态**，与"当前看不看得见"无关。
 *
 *   这与 M14 的「展平层不读 page」是同一条原则的两个方向：
 *   渲染要尽量少（少画看不见的），状态要尽量全（别忘了看不见的）。
 *
 *   ── 集合里只存"完全选中" ────────────────────────────────────────
 *   `selectedKeys` 的语义是**完全选中**（它自己 + 全部后代都在里面）。
 *   半选**不写进集合**，它是从结构现算出来的：某节点的子树里有被完全
 *   选中的节点、而它自己不在集合里 → 半选（读 `indeterminateKeys`）。
 *
 *   这条不变量（父在集合 ⟺ 所有直接子都在集合）由
 *   `TreeUtil.refreshAncestorsOf` 在每次写入后自下而上维护。于是集合永远
 *   自洽，不会出现"父在集合里、子却不在"这种脏状态。
 *
 *   行为：勾父 → 父与全部后代进集合；取消一个子孙 → 该子孙出集合，
 *   祖先逐个退出集合并转半选。表头三态 = 全选（所有根在集合）/
 *   半选（有选中但未全选）/ 未选。
 *
 *   `checkStrictly: true` 关掉级联与半选（父子独立，Ant / TDesign 的
 *   "父子不关联"）。
 *
 * ── 树逻辑的下沉（M17）────────────────────────────────────────────────
 * 建索引 / 展平 / 展开遍历 / 级联勾选 / 半选推导原先都在这个文件里。做
 * QSkinTree 时它们被搬到了 `QSkin.Foundation.TreeUtil`：那是**纯计算**，没有
 * 行高、没有列宽、没有颜色，本就不属于契约层。
 *
 * 搬走之后本表的树形行为**一字未改** —— 证据是 `smoke_m13` / `smoke_m14` /
 * `smoke_m15` / `smoke_m16` 在重构后断言一条没动仍然全绿。
 *
 * 未包含（留给后续里程碑）：横向虚拟滚动、树形行的拖拽排序、合并单元格。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Shapes 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /**
     * 列定义。每列：
     *   { title, dataIndex, width?, align? }
     *   width 未给出的列平分剩余宽度；align 取 "left" / "right"。
     */
    property var columns: []

    /** 行数据：对象数组，键与列的 dataIndex 对应 */
    property var rows: []

    /* ══════════════════════ 外观（供插槽读取） ══════════════════════ */

    property int rowHeight:    Theme.size.controlLg
    property int headerHeight: Theme.size.controlLg

    /** 表体最大高度；0 表示不限高（表体随行数增长），超过则出现滚动 */
    property int maxHeight: 0

    /** 行数为 0 时的占位文案 */
    property string emptyText: qsTr("暂无数据")

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 用户点击 / 回车确认了第 index 行 */
    signal rowClicked(int index)

    /** 当前选中行（显示下标）；-1 表示无选中。上下键可移动 */
    property int selectedRow: -1

    /* ── 排序（M6）── 列定义里标 sortable: true 的列，点表头切换升 / 降 */
    property int    sortColumn:    -1      /* -1 = 未排序 */
    property string sortDirection: "asc"   /* "asc" | "desc" */

    signal sortChanged(int column, string direction)

    /* 排序三角首次出现时不许动画。
     * 光靠 Behavior 不够：绑定第一次求值也会被当成一次变化，
     * 于是 sortColumn 一开始就设好时，表头会自己翻一下。
     * 同一个坑在 BasicChevronIndicator 里也有记录。 */
    property bool _sortIconAnimate: false
    Component.onCompleted: root._sortIconAnimate = true

    /* ── 多选（M6）── checkable 打开首列 checkbox；
     * selectedIndexes 存的是数据下标（排序打乱后勾选仍跟数据走）。
     * **平铺模式的寻址方式** —— 树形模式请用 selectedKeys（M15）。 */
    property bool checkable: false
    property var  selectedIndexes: []

    /** checkbox 列宽。复选框本体的热区由 QSkinCheckBox 自己管 */
    property int checkColumnWidth: Theme.size.iconLg + Theme.space.md * 2

    /* ── 树形勾选（M15）────────────────────────────────────────────────
     *
     * 树形模式下**改成键寻址**。折叠分支里的节点不在 `rows` 里，
     * `selectedIndexes`（数据下标）会指到别的行上 —— 见文件头的
     * 「树形勾选」一节。
     *
     * 两个属性都在、都能读，但**只有一套对当前视图有意义**：
     * `_treeOn` 是唯一判据。混用是 bug，不是特性。 */

    /** **完全选中**的键（无序写、树序读 —— 写入后按树的前序排好）。
     * 半选的节点**不在其中**，见 `indeterminateKeys`。 */
    property var selectedKeys: []

    /** 选中的键集合变了（树形模式）。参数是排好序的键数组 */
    signal keySelectionChanged(var keys)

    /** 父子不关联：关掉级联与半选。树形的"严格模式"（Ant / TDesign 同名） */
    property bool checkStrictly: false

    /* ── 列宽可拖（M12）──
     *
     * 用法：给列定义加 `resizable: true`，表头右沿出现拖拽热区。
     * 拖动只改被拖的那一列 —— 与「等分模式」的差别见下。
     *
     * ── 为什么拖一列会让「等分」退化成「固定」──────────────
     * 原布局里 width 未给出的列是**平分剩余宽度**的（flex 那套）。
     * 一旦用户拖了某一列，那一列就有了确定宽度，可剩下的列还在等分 ——
     * 于是总宽一旦变化（比如容器 resize），用户拖出来的比例会被等分
     * 重新洗牌，看起来像"我拖的宽度又变了"。
     *
     * 所以这里采取的做法是：**拖拽一旦发生，就把所有列在当前时刻的
     * 实际宽度"快照"下来**，之后布局进入"全部显式"模式。
     * 代价是容器 resize 后不再自动等分（用户已经手动调过了，
     * 让他自己负责更符合直觉）；好处是拖出来的宽度在任何时候都稳。
     *
     * 覆盖值存成 `{ 列下标: 宽度 }`。清空它即回到纯等分模式。 */
    property var columnWidths: ({})

    /** 列宽下限，防止拖到 0 宽导致内容彻底消失 */
    property int minColumnWidth: 48

    /** 表头右沿拖拽热区的宽度（命中范围比视觉线宽，便于抓取） */
    property int resizeHandleWidth: 8

    /** 用户拖完了某一列。index 是列下标，width 是拖后的新宽度 */
    signal columnResized(int index, int width)

    /* ── 横向滚动 + 左侧固定列（M13）──────────────────────────────────
     *
     * ── 为什么先要一个"内容总宽" ──────────────────────────────────
     * M12 之前列布局是**撑满容器**的：定宽列先占，剩余空间由未定宽列
     * 平分。这套模型下内容永远恰好装进容器 —— 没有"装不下"的时候，
     * 横向滚动也就无从谈起。
     *
     * 所以固定列必须先把前提补上：**内容可以比容器宽**。
     * `contentWidth` 就是这个前提，给了它之后：
     *
     *     0（默认）  → 内容撑满容器，不出现横向滚动（= M12 的行为）
     *     > 0        → 内容按这个宽度排布，超出容器即横向滚动
     *
     * `colLayout` 的等分基准、`setColumnWidth` 的拖宽上限，都跟着从
     * "容器宽"换成"内容宽" —— 否则拖宽会被容器卡住，横滚等于白做。
     *
     * ── 三区结构（M13 双区 → M16 左右都能钉）─────────────────────
     * `fixedColumns: N` 钉住**最左 N 列**，`fixedRightColumns: M` 钉住
     * **最右 M 列**。checkable 时 checkbox 列天然属于左固定区 ——
     * 它不是数据列，本来就不该被横滚带走。
     *
     *   左固定区  clip 的 Item，宽 = `_leftWidth`，永不横向位移；
     *             纵向靠 `y: -body.contentY` 跟随表体
     *   中间区    一个 Flickable，横向纵向都由它管
     *   右固定区  与左固定区同构 —— 也是只读投影 + clip，
     *             只是内容的落点对齐到**内容右端**而不是左端
     *
     * 三区**互不重叠**，所以不需要谁盖住谁，也没有 z 序问题 ——
     * 这是刻意避开"叠层式固定列"的：叠层要额外给固定区画不透明底色
     * 去挡住下面滑过的单元格，还得让底色跟着行的 hover / 选中一起变，
     * 一处没对上就是"钉住的那列在悬停时不变色"。
     *
     * ── 为什么单元格代码可以一行不改 ────────────────────────────────
     * 列宽与 colLayout 全程是**内容坐标系**（x 从 0 起，含 checkbox
     * 前置宽度）。三区**共用这一套坐标，且宿主局部坐标 == 内容坐标**
     * —— 每个宿主都以内容原点为原点，各自靠 clip 只露出自己那一段。
     * 于是"哪些列落在哪个区"由 clip 自动切分，不需要给单元格加
     * zone 偏移、也不需要 visible 过滤。M12 那 6 处 colLayout 断言
     * 到 M16 原样成立，靠的就是这条。
     *
     * 三区各自的横坐标由一条独立约束定出来：
     *   左固定区  x = 0                       内容 0 贴左沿
     *   中间区    x = `_leftWidth`            再减 contentX 得到滚动
     *   右固定区  x = width - `_rightWidth`   内容**右端**贴右沿
     *
     * 中间区与右固定区在"滚到底"时正好接上：中间区能露出的最后一个
     * 内容坐标 = 内容总宽 - 右固定宽，正是右固定区的左沿。这个等式
     * 与滚多远无关（见 `_maxScrollX`）—— 也就是说右固定列**不会**
     * 在中间区滚到任意位置时挡住它本来该显示的内容，而是恰好补上
     * 中间区够不到的那一段。 */

    /** 内容总宽。0 = 撑满容器；> 0 = 按此宽度排布，超出容器即横向滚动 */
    property int contentWidth: 0

    /** 左侧固定列数。最左 N 列不参与横向滚动（0 = 不固定）。
     * 该列宽总和即固定区宽度；默认左右各留一条 1px 边界线。 */
    property int fixedColumns: 0

    /** 右侧固定列数。最右 N 列不参与横向滚动（0 = 不固定）。
     *
     * 与 `fixedColumns` 合计不会超过列数 —— 超出的部分被夹掉。
     * **一列不能同时钉在两边**：两个区的 clip 窗口都会覆盖到它，于是
     * 它被画两次；而它到底是"最左第 3 列"还是"最右第 2 列"没有答案。
     * 夹掉之后 `T = 左固定 + 中间 + 右固定` 是个真正的划分，而不是
     * 一个会把同一段内容算两遍的加法。 */
    property int fixedRightColumns: 0

    /** 固定区边缘那一道渐隐指示条的宽度。左右两个区共用这一个值 ——
     * 它是同一种记号（"这边还有内容被钉住了"），分成两个属性只会
     * 让主题作者把它调成两个不一样的值。 */
    property int fixedShadowWidth: 12

    /** 列布局的基准宽度：内容总宽（未设时取容器宽） */
    readonly property int _layoutWidth: root.contentWidth > 0 ? root.contentWidth : root.width

    /** 固定列数（夹到有效范围） */
    readonly property int _fixedCount: Math.max(0, Math.min(root.fixedColumns, root.columnCount))

    /** 固定区宽度 = checkbox 列（若有）+ 前 _fixedCount 列的宽度。
     *
     * 注意 `checkable` 但 `fixedColumns = 0` 时它也 > 0 —— checkbox 列
     * 必须钉住，否则横滚会把它一起带走，而它并不在 columns 里，
     * 用户没法通过任何列定义把它找回来。 */
    readonly property int _fixedWidth: {
        var w = root._showCheckColumn ? root.checkColumnWidth : 0
        var L = root.colLayout
        for (var i = 0; i < root._fixedCount; ++i) w += L.widths[i]
        return w
    }

    /** 内容**实际**总宽（含 checkbox 前置宽度）。
     * 用实测列宽而不是 `_layoutWidth`：列宽被 `minColumnWidth` 顶住时
     * 两者会分叉，而横滚范围必须跟实际内容走，否则会出现
     * "内容明明溢出了、却滚不动"这种最难受的状态。 */
    readonly property int _contentTotal: {
        var L = root.colLayout
        var t = root._showCheckColumn ? root.checkColumnWidth : 0
        for (var i = 0; i < L.widths.length; ++i) t += L.widths[i]
        return t
    }

    /* ── 右侧固定列（M16）── */

    /** 右固定列数（夹到有效范围）。上限是"剩下的、还没被左边钉走的列数" */
    readonly property int _rightCount: Math.max(0, Math.min(root.fixedRightColumns,
                                                            root.columnCount - root._fixedCount))

    /** 右固定列宽总和。与 `_fixedWidth` 对称 —— 它是**内容侧**的概念：
     * 回答"哪几列不参与滚动"，不回答"屏幕上占多宽"（那是 `_rightWidth`）。 */
    readonly property int _rightTotal: {
        var w = 0
        var L = root.colLayout
        for (var i = root.columnCount - root._rightCount; i < root.columnCount; ++i)
            w += L.widths[i]
        return w
    }

    /* ── 屏幕侧的三区宽度（M16）────────────────────────────────────────
     *
     * 与内容侧的 `_fixedWidth` / `_rightTotal` **必须分开**。
     * 内容侧回答"哪几列不参与滚动"，屏幕侧回答"三个区各占多宽"。
     * 容器不比钉住列窄时两者相等；一旦容器更窄就分叉 —— 那时若还拿
     * 内容宽去摆区，左固定区会横着撞进中间区（`headerScroll.x` 变负），
     * 右固定区会滑出容器左沿。M13 只有左边时这个分叉不会暴露（左区
     * 溢出容器只是自己被裁掉），加了右区才必须补上。
     *
     * 分配次序是**左优先**：左固定区里有 checkbox 列 —— 那是"全选"的
     * 唯一入口，不在 `columns` 里，用户没法从别处把它找回来；右固定列
     * 只是便利。所以先给左区，右区吃剩下的，中间区吃最后的。
     *
     * 不变式：`_leftWidth + _middleWidth + _rightWidth === root.width`。 */
    readonly property int _leftWidth:  Math.min(root._fixedWidth, root.width)

    readonly property int _rightWidth: Math.max(0, Math.min(root._rightTotal,
                                                            root.width - root._leftWidth))

    readonly property int _middleWidth: Math.max(0, root.width - root._leftWidth - root._rightWidth)

    /** 可横向滚动的内容宽度（= 内容总宽 - 左固定 - 右固定）。
     * 三区不重叠（`_rightCount` 已经把重叠夹掉），所以这里是个真减法，
     * 不会出现"同一段内容被减两遍"。 */
    readonly property int _scrollableContentWidth: Math.max(0, root._contentTotal
                                                              - root._fixedWidth - root._rightTotal)

    /** 横向可滚动上限；0 = 没有横向溢出。
     *
     * 两种写法等价，这里刻意选了"可滚内容 - 中间区视口"这种 —— 因为它
     * 把 `_fixedWidth` / `_rightTotal` 都消掉了：代入 `_middleWidth =
     * width - 左 - 右` 之后得到 `内容总宽 - width`。**能滚多远只跟
     * "内容 vs 容器"有关，跟钉住多少无关**，这是三区结构最重要的一条
     * 性质：钉住不会凭空造出或吃掉滚动范围。
     *
     * 但要留 `_middleWidth` 这个因子：容器比钉住列还窄时中间区视口是 0，
     * 此时"可滚内容"再多也没有一寸地方让它滚，上限必须是 0。（M13 那版
     * 为左边单独写过一次 `max(0, width - _fixedWidth)`，正是这个因子 ——
     * 三区化之后它自然落在 `_middleWidth` 里。） */
    readonly property int _maxScrollX: root._middleWidth <= 0
                                       ? 0
                                       : Math.max(0, root._scrollableContentWidth
                                                     - root._middleWidth)

    /** 当前是否存在横向溢出（会同时决定固定区指示条与空状态的对齐） */
    readonly property bool _canScrollX: root._maxScrollX > 0

    /** 品牌色的 `color` 形态。
     *
     * 令牌里的 `brand` 是**十六进制字符串**（`"#0052D9"`），不是 color 值。
     * JS 字符串没有 `.r/.g/.b`，取到的是 undefined → `Qt.rgba()` 收到 NaN
     * → 静默退化成"黑色 + 指定透明度"。症状很隐蔽：浅色主题上看起来
     * 就是一层正常阴影，深色主题上直接隐形（黑色叠黑色）。
     * 声明成 `color` 类型让 QML 做一次强制转换，`.r/.g/.b` 才是数字。
     *
     * 凡是"要给令牌色调透明度 / 做插值"的地方都得先过这一手 ——
     * 直接写 `color:` 的地方反而没事（那里 QML 会自动转换）。 */
    readonly property color _brandColor: Theme.color.brand

    /** 当前鼠标悬停的行（显示下标）；-1 = 无。
     *
     * 提到根上而不是留在行里：行被拆进了左固定 / 中间 / 右固定**三个
     * 宿主**，悬停其中一个区时另两个区也得跟着亮 —— 否则一整行只有
     * 一节有反馈，看起来像选中错位。 */
    property int hoveredRow: -1

    /* ══════════════════════ 树形（M14）══════════════════════ */

    /** 树形模式：`rows` 是树根数组，子节点在 `treeChildrenKey` 字段下。
     * `treeMode` 为真时排序只作用于同级节点，不会把行跨层搬走；
     * 勾选改走键寻址（`selectedKeys`，M15）。 */
    property bool treeMode: false

    /** 子节点字段名 */
    property string treeChildrenKey: "children"

    /** 行唯一键字段名。展开状态按它记 —— 不按结构路径：路径会随
     * 同级排序漂移，键不会。行上取不到该字段时回退到结构路径
     * （前缀 "#"，如 "#0/2"），此时同级一排序展开状态就会跟着错位。 */
    property string treeKey: "id"

    /** 箭头画在哪一列（数据列下标） */
    property int treeColumn: 0

    /** 每级缩进量 */
    property int treeIndentWidth: Theme.space.lg

    /** 箭头位宽度。叶子节点也占这个位 —— 否则同一层的兄弟文字左沿不齐 */
    property int treeChevronWidth: Theme.font.md

    /** 缩进之后至少留给文字的宽度。缩到"再缩就没字了"就停住，
     * 与 minColumnWidth 同一条原则：宁可少缩进，也不让内容消失。 */
    property int treeMinLabelWidth: 64

    /** 还没被显式展开 / 收起过的节点，默认是否展开 */
    property bool defaultExpandAll: false

    /** 某个节点被展开 / 收起。`key` 是 treeKey 字段的值（取不到时是 "#路径"） */
    signal expandToggled(var key, bool expanded)

    /** 内部展开状态 { 键: true|false }。**只记录被显式设置过的**节点，
     * 没记录的取 defaultExpandAll —— 这样 expandAll / collapseAll 是
     * 落成显式状态，而"换数据后新出现的节点"仍然吃默认值。 */
    property var _expandState: ({})

    /** 树形是否生效 */
    readonly property bool _treeOn: root.treeMode

    /** 勾选列是否出现。
     *
     * **M15 起树形模式也出现** —— 判据退回纯粹的 `checkable`。
     * M14 那版写的是 `checkable && !treeMode`，理由是"下标寻址在折叠
     * 分支上会指错行"。但那个理由针对的是**寻址方式**，不是"能不能勾"：
     * 换掉寻址（`selectedKeys`）之后，勾选列没有任何理由缺席。
     *
     * 这个 readonly 之所以重要，是因为它有 4 个几何读者
     * （`_fixedWidth` / `_contentTotal` / `setColumnWidth` 的左侧占位 /
     * `colLayout` 的 lead）：改这一处，checkbox 列的占位在四个地方
     * 同时生效 —— 不需要逐个去改。 */
    readonly property bool _showCheckColumn: root.checkable

    /* ── 全树结构索引（M15）────────────────────────────────────────────
     *
     * 与 `_visibleRows` 是**两套并行的树视图**，职责刻意分开：
     *   受折叠影响、剪枝的  → 渲染 / 分页（M14 的 `_visibleRows`）
     *   不受折叠影响、全树的 → 级联 / 祖先链 / 后代集（就是它）
     * 原因见文件头「两套并行的树视图」。
     *
     * 形状：{ byKey: { 键 → { node, parentKey, childKeys, level } },
     *         roots: [顶层键], order: [全部键（前序）], count: 节点总数 }
     *
     * **M17 起这棵索引由 `QSkin.Foundation.TreeUtil` 提供。** 做 QSkinTree 时
     * 如果把它复制一份，从那天起就有两种"级联算不算折叠节点"的实现；
     * 腾出去之后本表与 QSkinTree 共用同一组函数，不可能给出不同答案 ——
     * 键的取法（含回退路径的拼法）也只剩那一处了。
     *
     * 这个属性名保留：`examples/showcase/HelloM15.qml` 读 `_treeIndex.count` 显示
     * 节点总数。 */
    readonly property var _treeIndex: {
        if (!root._treeOn) return { byKey: {}, roots: [], order: [], count: 0 }
        var src = root.rows !== null && root.rows !== undefined ? root.rows : []
        return TreeUtil.index(src, root.treeKey, root.treeChildrenKey)
    }

    /* ── 选中集合与派生（M15）────────────────────────────────────────── */

    /** `selectedKeys` 的**对象化**版本，查询 O(1)。
     * 级联里一次写入要问几百次"这个键在不在集合里"，用 `indexOf`
     * 会退化成 O(n²)。整份换新数组才会触发重算（同 `_expandState`）。 */
    readonly property var _keySet: TreeUtil.keySet(root.selectedKeys)

    /** 键 → 该节点的**子树里是否有被完全选中的节点**（不含自己）。
     *
     * 半选判据 = 「自己不在集合」且「这个值为 true」。**预计算**而不是
     * 每次现算：`isIndeterminate` 每个渲染行都要问一次，现算就是每行
     * 一次子树遍历。
     *
     * 自底向上（后序）一次算完。`checkStrictly` 时给空表 —— 没有联动
     * 就没有半选的语义。 */
    readonly property var _subtreeHasChecked: {
        if (!root._treeOn || root.checkStrictly) return {}
        return TreeUtil.subtreeHasChecked(root._treeIndex, root._keySet)
    }

    /** **半选**的键，按树的前序排好。半选 = 自己没被完全选中、但子树里
     * 有被完全选中的节点。叶子永远不在这里。`checkStrictly` 下恒空。 */
    readonly property var indeterminateKeys: {
        if (!root._treeOn || root.checkStrictly) return []
        return TreeUtil.indeterminateKeys(root._treeIndex, root._keySet,
                                          root._subtreeHasChecked)
    }

    /** 被**完全选中**的行对象，两种模式通用（平铺看 selectedIndexes、
     * 树形看 selectedKeys）。半选的行不在其中 —— 要半选请读
     * `indeterminateKeys`。
     *
     * 这是"想直接拿数据"时的出口：不必自己再做一遍键 → 行对象的映射
     * （那步正是最容易写错的：树形的节点根本不在 `rows` 里）。 */
    readonly property var selectedRows: {
        var out = []
        if (root._treeOn)
            return TreeUtil.rowsOfKeys(root._treeIndex, root.selectedKeys)
        var src = root.rows
        var sel = root.selectedIndexes
        if (src === null || src === undefined || sel === null || sel === undefined) return out
        for (var j = 0; j < sel.length; ++j) {
            var s = sel[j]
            if (s >= 0 && s < src.length) out.push(src[s])
        }
        return out
    }

    /** 树形模式下已展开的键（无序数组）。非树形时为空 */
    readonly property var expandedKeys: {
        var out = []
        var st = root._expandState
        if (st === null || st === undefined) return out
        for (var k in st) if (st[k] === true) out.push(k)
        return out
    }

    /** 把某一列的宽度设为指定值（同时冻结其余列的当前宽度）。
     * 传 -1 或负数则忽略。这是拖拽的落地口，也可程序化调用。
     *
     * ── 两条约束 ─────────────────────────────────────────────────
     * ① 下限 `minColumnWidth`：防止拖到 0 宽让内容彻底消失。
     * ② 右侧留位：拖某一列时，它右侧的列不能总宽溢出**内容宽** ——
     *    否则内容会被顶出右沿（表体是 clip 的，用户看到的是
     *    "右边的列不见了"）。这里把目标列的上限压到
     *    「内容宽 - 该列左侧所有列宽 - 右侧每列留 minColumnWidth」。
     *    checkable 时前置的 checkbox 列也要算进左侧占位。
     *
     * 基准是 `_layoutWidth`（M13 起）而不是 `root.width`：
     * 开了横向滚动之后，"内容装得下"的判据是内容宽 —— 拖宽只会让
     * 内容变宽、横滚范围变大，不该被容器宽卡住。contentWidth = 0 时
     * 两者相等，行为与 M12 完全一致。 */
    function setColumnWidth(index, width) {
        if (index < 0 || index >= root.columnCount) return

        var layout = root.colLayout
        var lead   = root._showCheckColumn ? root.checkColumnWidth : 0

        /* 左侧已占 */
        var leftTotal = lead
        for (var i = 0; i < index; ++i) leftTotal += layout.widths[i]

        /* 右侧每列至少保留 minColumnWidth */
        var rightMin = 0
        for (var j = index + 1; j < root.columnCount; ++j) rightMin += root.minColumnWidth

        var maxW = root._layoutWidth - leftTotal - rightMin
        var w = Math.max(root.minColumnWidth, Math.round(width))
        /* 上限不可低于下限（容器太窄时保下限，宁可溢出也不把列压没） */
        var upper = Math.max(root.minColumnWidth, maxW)
        w = Math.min(w, upper)

        /* 先把当前实际布局快照下来（含未拖过的列），
         * 再覆盖目标列 —— 这样快照与覆盖是同一个基准，不会互相污染 */
        var snap = {}
        for (var k = 0; k < root.columnCount; ++k)
            snap[k] = layout.widths[k]
        snap[index] = w
        root.columnWidths = snap
        root.columnResized(index, w)
    }

    /** 回到等分模式（丢弃所有手动宽度） */
    function resetColumnWidths() {
        root.columnWidths = ({})
    }

    /** 某一列是否可拖：列定义显式标了 resizable: true。
     * 最后一列不给拖 —— 它的右沿是表格右边界，
     * 拖了会把内容顶出可视区，且用户无法把它拖回来。 */
    function _resizableAt(index) {
        if (index < 0 || index >= root.columnCount - 1) return false
        var c = root.columns[index]
        if (!c || c.resizable !== true) return false
        /* 可拖的列必须有**确定宽度**（手动覆盖值 或 列定义 width），
         * 不能是靠等分算出来的。
         *
         * 注意不能写成 `colLayout.widths[index] > 0`：等分分支会给
         * 每个自动列都填上 share，只要容器不是极窄 share 就 > 0，
         * 那个判断恒真 —— 等于这条规则不存在。必须回查宽度来源。 */
        return root._hasExplicitWidth(index)
    }

    /** 该列当前是否持有"确定宽度"（而非依赖容器等分）。
     * 两个来源：用户手动拖出来的覆盖值 > 列定义里的 width。
     * 两者都没有 → 这列是等分列，从它起拖语义含糊（拖的瞬间
     * 既要定它的宽、又要重算其余列如何分剩余空间）。 */
    function _hasExplicitWidth(index) {
        if (root.columnWidths !== null && root.columnWidths !== undefined
            && root.columnWidths[index] !== undefined) {
            return root.columnWidths[index] > 0
        }
        var c = root.columns[index]
        return !!c && c.width !== undefined && c.width > 0
    }

    /** 双击拖拽热区 → 该列按内容宽度自适应。
     * 这是"列宽可拖"的标配配套：用户拖歪了想复原时不必手调。 */
    function _autoFitColumn(index) {
        if (index < 0 || index >= root.columnCount) return
        var maxW = root.minColumnWidth
        /* 表头文字也要参与量宽，否则"文件名"三字可能被内容更窄的列压掉 */
        var head = root.columns[index] && root.columns[index].title !== undefined
                   ? String(root.columns[index].title) : ""
        maxW = Math.max(maxW, root._measureText(head, true))

        var col = root.columns[index]
        for (var i = 0; i < root.rowCount; ++i) {
            var t = root._cellText(root.rows[i], col)
            maxW = Math.max(maxW, root._measureText(t, false))
        }
        root.setColumnWidth(index, maxW)
    }

    /** 量一段文字的像素宽。用一个不可见的 TextMetrics 做真实测量
     * （QFontMetrics 在纯 QML 里拿不到，而 TextMetrics 是 QtQuick 自带的）。
     * header 为真时按表头字重量 —— 表头通常比单元格更粗。 */
    function _measureText(text, header) {
        measureProbe.isHeader = header === true
        measureProbe.text = text === undefined || text === null ? "" : String(text)
        return measureProbe.advanceWidth
    }

    signal selectionChanged()

    /* ── 客户端分页（M7）── pageSize > 0 时 displayRows 先排序再按
     * page 切片；翻页发 paged。与 QSkinPagination 正交：外部把两者
     * 的 page 属性互相绑定即可联动 */
    property int pageSize: 0
    property int page:     1

    /* 页数按**可见行**算（树形下折叠的分支不占页码）—— 见 `_view.total` */
    readonly property int pageCount: root.pageSize > 0 && root._viewTotal > 0
                                     ? Math.ceil(root._viewTotal / root.pageSize)
                                     : 1

    signal paged(int page)

    /** 当前排序键与方向；`null` = 没在排（列下标越界 / 该列没有 dataIndex）。
     * 树形与非树形共用这一份判断，避免两处各写一遍。 */
    readonly property var _sortSpec: {
        if (root.sortColumn < 0 || root.sortColumn >= root.columnCount) return null
        var col = root.columns[root.sortColumn]
        if (!col || col.dataIndex === undefined) return null
        return { key: col.dataIndex, dir: root.sortDirection === "desc" ? -1 : 1 }
    }

    /** 展平结果、**未分页**：可见行 + 每行的树信息 + 可见行总数。
     *
     * M14 起这是唯一行来源：
     *   非树形 → 排序（与 M5~M13 逐字等价）
     *   树形   → 递归展平（各级兄弟可排序）
     *
     * ── 为什么它必须与分页分开成一个属性 ────────────────────────────
     * 它刻意**不读 `page` / `pageSize`**。原因：`pageCount` 依赖它的
     * 总数，而 `pageCount` 变化时 `onPageCountChanged` 会反过来写
     * `page`（把页码夹回有效范围）。一旦展平这一层也读了 `page`，
     * 就构成 `page → 展平 → 总数 → pageCount → page` 的**环**：
     * QML 会报 "Binding loop detected"，把该绑定标记为不可靠，
     * 数值从此冻在某一轮、且不会自己恢复（M14 实测踩到，表现是
     * 树形的所有断言一起失败，看起来像展平写错了）。
     * 分页因此单独放在 `_view` 里，两条链各自单向。 */
    readonly property var _visibleRows: {
        var src = root.rows !== null && root.rows !== undefined ? root.rows : []
        var pair = root._treeOn ? root._flattenTree(src) : root._flattenPlain(src)
        return { rows: pair.rows, meta: pair.meta, total: pair.rows.length }
    }

    /** 可见行序列 + 每行的树信息 + **未分页**的可见行数。
     * `total` 单独带出来，因为树形的页数必须按**可见行**算 ——
     * 折叠起来的分支不该占页码，而 displayRows 已经被切片了，量不出总数。 */
    readonly property var _view: {
        var all = root._visibleRows
        if (root.pageSize > 0 && root.page > 0) {
            var from = (root.page - 1) * root.pageSize
            return { rows: all.rows.slice(from, from + root.pageSize),
                     meta: all.meta.length > 0 ? all.meta.slice(from, from + root.pageSize)
                                               : all.meta,
                     total: all.total }
        }
        return all
    }

    /** 行的当前显示顺序。未排序、未分页、非树形时与 rows 相同（同一引用，不复制） */
    readonly property var displayRows: root._view.rows

    /** 每个**可见行**的树信息，与 displayRows 同序同长。非树形时为空数组。
     * 元素：{ key, level, parentKey, hasChildren, expanded, sourceIndex }
     * （sourceIndex 只有顶层节点有意义 —— 它们是 rows 里的下标；嵌套节点是 -1） */
    readonly property var rowMeta: root._view.meta

    /** **未分页**的可见行数。只依赖 `_visibleRows`（不读 page），
     * 否则会与 pageCount → page 构成环 —— 见 `_visibleRows` 的注释 */
    readonly property int _viewTotal: root._visibleRows.total

    /** 非树形：排序（不排序时原样返回同一个数组引用，不复制） */
    function _flattenPlain(src) {
        var sp = root._sortSpec
        var arr = src
        if (sp !== null) {
            var key = sp.key
            var dir = sp.dir
            arr = src.slice()
            arr.sort(function(a, b) { return dir * root._compare(a, b, key) })
        }
        return { rows: arr, meta: [] }
    }

    /** 树形：递归展平出**可见**行。折叠的分支整枝跳过。
     *
     * 每一层兄弟各自排序 —— 这是"树形下的排序"唯一说得通的定义：
     * 跨层重排会让节点换爹，树就散了。
     *
     * 排序用**原始下标**做中介（`order`），不直接重排传入的数组：
     * 一来不修改使用方的数据，二来下标还得用来拼回退路径。 */
    function _flattenTree(src) {
        var sp = root._sortSpec
        var cmp = null
        if (sp !== null) {
            var key = sp.key
            var dir = sp.dir
            cmp = function(a, b) { return dir * root._compare(a, b, key) }
        }
        return TreeUtil.flatten(src, {
            keyField:    root.treeKey,
            childrenKey: root.treeChildrenKey,
            isExpanded:  function(k) { return root._isExpanded(k) },
            compare:     cmp,
            sourceIndex: true
        })
    }

    readonly property int rowCount:    root.rows    !== null && root.rows    !== undefined ? root.rows.length    : 0
    readonly property int columnCount: root.columns !== null && root.columns !== undefined ? root.columns.length : 0

    /** 当前页实际显示的行数（客户端分页时 < rowCount） */
    readonly property int viewRowCount: root.displayRows !== null && root.displayRows !== undefined
                                        ? root.displayRows.length : 0

    /* 翻页后显示位置失去意义，选中清空；勾选是数据下标，跨页保留 */
    onPageChanged: root.selectedRow = -1

    /* 行数 / 页长变化导致页数缩水时，把 page 夹回有效范围 */
    onPageCountChanged: {
        if (root.page > root.pageCount) {
            root.page = root.pageCount
            root.paged(root.page)
        }
    }

    /* ══════════════════════ 尺寸 ══════════════════════ */

    /* 未定宽时退化成各显式宽度之和（若全都不定宽则为 0，由使用方给 width）。
     * 刻意不走 colLayout：colLayout 依赖 root.width，再喂回 implicitWidth
     * 会构成 implicitWidth ↔ width 的循环绑定。
     * M13：显式设了 contentWidth 时它才是诚实的自然宽度（内容总宽）。 */
    implicitWidth: {
        if (root.contentWidth > 0) return root.contentWidth
        var total = 0
        for (var i = 0; i < root.columnCount; ++i)
            if (root.columns[i] && root.columns[i].width !== undefined)
                total += root.columns[i].width
        return total
    }

    readonly property int _contentHeight: root.viewRowCount * root.rowHeight
    readonly property int _bodyHeight:    root.maxHeight > 0
                                          ? Math.min(root._contentHeight, root.maxHeight)
                                          : (root.viewRowCount > 0 ? root._contentHeight
                                                                   : root.rowHeight * 2)
    implicitHeight: root.headerHeight + root._bodyHeight

    activeFocusOnTab: true

    /* ══════════════════════ 无障碍 ══════════════════════ */

    Accessible.role: Accessible.Table
    Accessible.name: qsTr("表格")

    /* 文字量宽探针（M12 列宽自适应用）。
     * 只建一份、改属性复用 —— 每列各建一个 TextMetrics 会让
     * 「双击自适应」瞬间创建 N 个对象，纯属浪费。
     *
     * 字号/字重必须与 BasicLabel 的实际渲染一致 ——
     * 探针量与真实排版对不上，自适应出来的宽度就会差一截。
     * 这里对齐 Slots.label 的实现：
     *   字号恒为 font.sm；header 变体走 weightSemiBold，其余 weightRegular。
     * 主题若改了 label 的字号，这里会跟着偏 —— 已知代价，
     * 换来的是"不给量宽单独开插槽"。
     *
     * ── 两个 QML 陷阱（M12 都踩过，务必保留这些写法）─────────────
     *
     * ① 自定义属性名不能叫 `text` —— TextMetrics 自带只读的 `text`，
     *    同名声明会让这个组件整个加载失败（"Did not load any objects"，
     *    且不报冲突原因，qmllint 也不拦）。
     *
     * ② 字重**不能**绕一圈：早期写成
     *        readonly property int _measureWeight:
     *            measureProbe.isHeader ? bold : regular
     *        TextMetrics { font.weight: root._measureWeight }
     *    看起来只是"把三元抽成属性"，实际形成了
     *        measureProbe.font.weight → _measureWeight → measureProbe.isHeader
     *    的**循环依赖**。QML 遇到环不会报错，只是把这条链标记为
     *    不可靠，连带同一轮求值的兄弟绑定一起失效 —— 症状是
     *    "colLayout 数值全对、但只有第一列画得出来"，
     *    差了两小时才定位到。正解是让 font.weight 直接依赖 isHeader，
     *    把三元写进 TextMetrics 内部的 Binding，不经过中间属性。 */
    TextMetrics {
        id: measureProbe

        font.family:    Theme.font.family
        font.pixelSize: Theme.font.sm
        font.weight:    measureProbe.isHeader
                        ? Theme.font.weightSemiBold
                        : Theme.font.weightRegular

        /* 自定义属性名不能叫 `text` —— 见上面 ① */
        property bool isHeader: false
    }

    /* ══════════════════════ 列布局 ══════════════════════ */

    /** 每列的 x 偏移与宽度。width / columns / contentWidth 变化时自动重算。
     * checkable 时 x=0 处留给 checkbox 列，数据列整体右移。
     *
     * 全程是**内容坐标系** —— 下标 0 是具体哪个屏幕位置，由分区宿主的
     * x 决定（见 M13 双区结构注释）。这样列宽计算与"钉住哪几列"完全解耦。
     *
     * 宽度来源的优先级（M12）：
     *   1. `columnWidths[i]` —— 用户拖拽出来的手动宽度
     *   2. `columns[i].width` —— 列定义里写死的宽度
     *   3. 平分剩余 —— 两者都没有的列按剩余空间等分
     * 第 1 层存在时，通常意味着**所有**列都已被快照（见 setColumnWidth），
     * 所以第 3 层不会参与；但即便只有部分列有覆盖值，这个优先级
     * 也能给出合理结果（有覆盖的用覆盖，其余继续等分）。
     *
     * 等分的基准是 `_layoutWidth`（M13 起）：开了横滚之后，未定宽列
     * 分的是**内容宽**的剩余，不是容器宽的剩余 —— 否则它们会被容器
     * 压扁，横滚区里永远空着右边一大块。
     *
     * 等分结果有 `minColumnWidth` 下限。容器（或内容宽）窄到装不下时，
     * 宁可让内容溢出、由横滚兜住，也不把列压成 0 宽 —— 0 宽的列
     * 是"数据凭空消失"，比"要横滚一下"严重得多。 */
    readonly property var colLayout: {
        var widths = []
        var fixedTotal = 0
        var freeCount = 0
        var lead = root._showCheckColumn ? root.checkColumnWidth : 0
        for (var i = 0; i < root.columnCount; ++i) {
            var w = 0
            if (root.columnWidths !== null && root.columnWidths !== undefined
                && root.columnWidths[i] !== undefined) {
                w = root.columnWidths[i]
            } else if (root.columns[i] && root.columns[i].width !== undefined) {
                w = root.columns[i].width
            }
            if (w > 0) fixedTotal += w
            else       freeCount  += 1
            widths.push(w)
        }
        var share = freeCount > 0
                    ? Math.max(root.minColumnWidth,
                               Math.floor((root._layoutWidth - lead - fixedTotal) / freeCount))
                    : 0
        var xs = []
        var x = lead
        for (var j = 0; j < widths.length; ++j) {
            if (widths[j] <= 0) widths[j] = share
            xs.push(x)
            x += widths[j]
        }
        return { xs: xs, widths: widths }
    }

    function _alignOf(col) {
        return col && col.align === "right" ? Text.AlignRight : Text.AlignLeft
    }

    function _cellText(rowData, col) {
        if (!rowData || !col || col.dataIndex === undefined) return ""
        var v = rowData[col.dataIndex]
        return v === undefined || v === null ? "" : String(v)
    }

    /* ══════════════════════ 表头（粘性） ══════════════════════ */

    Item {
        id: header

        width:  parent.width
        height: root.headerHeight

        /* 底色与下边框铺满整表宽、不参与横向滚动 ——
         * 它们表达的是"表头这一条带"，而不是"某些列" */
        Rectangle {
            anchors.fill: parent
            color: Theme.color.bgSubtle
        }

        /* 表头下沿用 borderStrong，比行分隔线重一档 */
        Rectangle {
            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.color.borderStrong
        }

        /* ── 左固定区（M13）：钉在左沿，不随横向滚动位移 ── */
        Item {
            id: headerFixed

            x: 0
            y: 0
            width:  root._leftWidth
            height: parent.height
            visible: root._leftWidth > 0
            clip: true

            Repeater {
                model: root.columnCount
                delegate: headerCellComp
            }

            /* 全选 checkbox（checkable 时）。半选 = 有勾选但未全选；
             * 半选 / 未选状态下点击都进全选 —— QSkinCheckBox 的通用约定。
             * 它必须待在固定区：横滚把它带走的话，用户就再也点不到全选了。 */
            Item {
                id: headerCheckCol

                visible: root._showCheckColumn
                x: 0
                width: root.checkColumnWidth
                height: parent.height

                QSkinCheckBox {
                    id: headerCheck

                    anchors.centerIn: parent
                    onClicked: root._toggleAll()

                    /* 与数据行同一套写法（见那里的长注释）。表头这里**更早**
                     * 就会露馅：树形下点任意一个深层节点，表头都可能从
                     * "未选"跳到"半选"，而直接绑定的写法在第一次点击后
                     * 绑定已经拆掉了 —— 表头会僵在原地。 */
                    Binding { target: headerCheck; property: "checked"
                              value: root._allSelected
                              }
                    Binding { target: headerCheck; property: "indeterminate"
                              value: root._someSelected
                              }
                }
            }
        }

        /* ── 中间区（M13）：整块内容左移，横向跟随表体 contentX ──
         * 宿主减一个 `_leftWidth`，不是减它自己的 x —— 目标是让
         * **宿主局部坐标 == 内容坐标**（内容原点落在屏幕 0 处），
         * 这样单元格、树形箭头那些按内容坐标算出来的 x 可以直接用。 */
        Item {
            id: headerScroll

            x: root._leftWidth
            y: 0
            width:  root._middleWidth
            height: parent.height
            clip: true

            Item {
                id: headerScrollHost

                x: -root._leftWidth - body.contentX
                y: 0
                width:  root._layoutWidth
                height: parent.height

                Repeater {
                    model: root.columnCount
                    delegate: headerCellComp
                }
            }
        }

        /* ── 右固定区（M16）──
         * 与左固定区同构，只差一处：内容的**右端**贴右沿，而不是左端贴
         * 左沿。于是宿主的 x 是 `_rightWidth - 内容总宽` —— 内容坐标 c
         * 落在屏幕 `width - 内容总宽 + c`，c 取内容总宽时正好是 `width`。
         * 换个说法：宿主局部坐标仍然 == 内容坐标，所以单元格与树形箭头
         * 那套内容坐标算法在两个固定区里算出来的 x 一模一样。 */
        Item {
            id: headerRight

            x: root.width - root._rightWidth
            y: 0
            width:  root._rightWidth
            height: parent.height
            visible: root._rightWidth > 0
            clip: true

            Item {
                id: headerRightHost

                x: root._rightWidth - root._contentTotal
                y: 0
                width:  root._contentTotal
                height: parent.height

                Repeater {
                    model: root.columnCount
                    delegate: headerCellComp
                }
            }
        }
    }

    /* ══════════════════════ 表体（可滚动） ══════════════════════ */

    Item {
        id: bodyLayer

        y: root.headerHeight
        width:  parent.width
        height: root._bodyHeight

        /* ── 左固定区（M13）：不横向滚动，纵向靠 y 跟随表体 ──
         * 刻意**不做成第二个 Flickable** —— 两个 Flickable 互相绑
         * contentY 会来回打架（A 滚动触发 B 更新、B 更新又触发 A），
         * 表现为拖动时的高频抖动。这里只有一个滚动源（body），
         * 两个固定区都只是它的"只读投影"。
         *
         * 行的宽度取 `parent.width`（见 rowComp 里的说明）—— 于是同一个
         * 行组件在三个宿主里各自只铺满自己那一段，拼起来正好一整行，
         * 不互相盖住、也不重复响应。 */
        Item {
            id: bodyFixed

            x: 0
            y: 0
            width:  root._leftWidth
            height: parent.height
            visible: root._leftWidth > 0
            clip: true

            Item {
                id: bodyFixedHost

                x: 0
                y: -body.contentY
                width:  root._leftWidth
                height: root._contentHeight

                Repeater {
                    model: root.viewRowCount
                    delegate: rowComp
                }
            }

            /* 滚轮落在固定列上时转交给表体 —— 固定区不是 Flickable，
             * 自己滚不动。少了这一段，鼠标停在钉住的那列上滚动会毫无反应，
             * 用户八成会判定成"表格卡住了"。 */
            WheelHandler {
                onWheel: function(ev) {
                    var dy = ev.angleDelta.y
                    var dx = ev.angleDelta.x
                    if (dy !== 0) body.contentY = root._clampScrollY(body.contentY - dy)
                    if (dx !== 0) body.contentX = root._clampScrollX(body.contentX - dx)
                }
            }
        }

        /* ── 中间区（M13）：横纵都由这一个 Flickable 管 ── */
        Flickable {
            id: body

            x: root._leftWidth
            y: 0
            width:  root._middleWidth
            height: parent.height

            contentWidth:  Math.max(root._scrollableContentWidth, body.width)
            contentHeight: root._contentHeight
            clip: true
            interactive: root._contentHeight > body.height || body.contentWidth > body.width
            boundsBehavior: Flickable.StopAtBounds

            ScrollIndicator.vertical: ScrollIndicator { }
            ScrollIndicator.horizontal: ScrollIndicator { }

            /* 宿主减一个 `_leftWidth`：于是**这个宿主的局部坐标就是内容
             * 坐标**（局部 0 = 内容 0），三个区的单元格可以直接用同一套
             * colLayout 内容坐标 —— 落在别人区里的那些被 clip 切掉，
             * 不需要 visible 过滤，也不需要 zone 偏移。
             *
             * 宽度必须覆盖到内容坐标的右端 = max(内容总宽, 表格宽)。
             *
             * 不能取 body.contentWidth —— 那是**可滚**宽度，比内容总宽
             * 少了「左固定 + 右固定」一截（M13 初版就是这么写的，当时
             * 少了左固定那一截）。症状是横滚到底时每一行的底色与分隔线
             * 都短一截，末列底下没有行线；而当时那条"最大行宽 == 可滚宽"
             * 的断言把 bug 当成了期望值，于是截图核验也说服自己"这是正确
             * 的渲染"。教训与 M11.1 同一条：参照系本身错了，验证就会替
             * bug 背书。 */
            Item {
                id: rowsHost

                x: -root._leftWidth
                y: 0
                width:  Math.max(root._contentTotal, root.width)
                height: root._contentHeight

                Repeater {
                    model: root.viewRowCount
                    delegate: rowComp
                }
            }
        }

        /* ── 右固定区（M16）：与左固定区同构的只读投影 ──
         * 同样不是 Flickable —— 只有一个滚动源（body），它只跟纵向。
         * 宿主局部坐标也 == 内容坐标，落点由 x 定：内容右端贴右沿。 */
        Item {
            id: bodyRight

            x: root.width - root._rightWidth
            y: 0
            width:  root._rightWidth
            height: parent.height
            visible: root._rightWidth > 0
            clip: true

            Item {
                id: bodyRightHost

                x: root._rightWidth - root._contentTotal
                y: -body.contentY
                width:  root._contentTotal
                height: root._contentHeight

                Repeater {
                    model: root.viewRowCount
                    delegate: rowComp
                }
            }

            /* 与左固定区同一段滚轮转发。少了它，鼠标停在右固定列上
             * 滚动同样会"表格卡住了"。 */
            WheelHandler {
                onWheel: function(ev) {
                    var dy = ev.angleDelta.y
                    var dx = ev.angleDelta.x
                    if (dy !== 0) body.contentY = root._clampScrollY(body.contentY - dy)
                    if (dx !== 0) body.contentX = root._clampScrollX(body.contentX - dx)
                }
            }
        }

        /* 空状态：跨**整表**宽度居中。放进滚动区的话会偏向固定列一侧 */
        Text {
            anchors.centerIn: parent
            text: root.emptyText
            visible: root.viewRowCount === 0
            font.family:    Theme.font.family
            font.pixelSize: Theme.font.sm
            color: Theme.color.fgMuted
            renderType: Text.NativeRendering
        }
    }

    /* ── 左固定区右沿的渐隐指示条（M13）──
     * 只在横向真的滚开之后出现：它的语义是"这一列是钉住的，
     * 底下还有内容能往左拖"，没滚开时三区视觉上是连续的，
     * 画一条线反而会让人以为那里有边界。
     *
     * ── 为什么挂在 root 上而不是表体里 ────────────────────────────
     * 它必须**贯穿表头 + 表体**。只画在表体里的话，表头那一条带
     * 仍然横贯整个宽度，边界看起来像"从表头下面才开始的"，
     * 而表头恰恰是用户最先找列的地方（M13 截图验证时抓到的真 bug）。
     * 声明成 root 的最后一个子项，天然盖在表头与表体之上。
     *
     * 用品牌色渐隐而不是"深色阴影"：阴影靠明度差表达，白底主题上
     * 还行、深色主题上等于没画（同 M11 滚轮选中窗口踩过的坑）。
     * 品牌色是饱和色，两种底色上都立得住。 */
    Rectangle {
        id: fixedShadow

        x: root._leftWidth
        y: 0
        width:  root.fixedShadowWidth
        height: root.headerHeight + root._bodyHeight
        visible: root._leftWidth > 0 && body.contentX > 0.5

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: Qt.rgba(root._brandColor.r, root._brandColor.g,
                               root._brandColor.b, 0.22)
            }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    /* ── 右固定区左沿的渐隐指示条（M16）──
     * 与左边那道镜像。出现条件也镜像：左边是"已经往右滚了"，右边是
     * **还没滚到底** —— 那正是右固定区底下压着内容的时候。滚到底之后
     * 中间区与右固定区视觉上连续，这条线就该消失。
     *
     * 多一个 `_middleWidth` 条件：三区都很窄时两道指示条会在中间挤成
     * 一团，比不画更难看。左区那道（M13 就有）刻意不加这个条件 ——
     * 它的出现条件是"用户已经滚了"，此时它必须可见，不该被一个宽度
     * 阈值悄悄抹掉；右区这道是新加的，让它退让。 */
    Rectangle {
        id: rightShadow

        x: root.width - root._rightWidth - root.fixedShadowWidth
        y: 0
        width:  root.fixedShadowWidth
        height: root.headerHeight + root._bodyHeight
        visible: root._rightWidth > 0
                 && body.contentX < root._maxScrollX - 0.5
                 && root._middleWidth >= root.fixedShadowWidth * 2

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop {
                position: 1.0
                color: Qt.rgba(root._brandColor.r, root._brandColor.g,
                               root._brandColor.b, 0.22)
            }
        }
    }

    /* headerCellComp / rowComp / cellComp 引用了外层 id（root / Slots）——
     * inline Component 的静态检查局限，与 QSkinSelect 的 delegate 同款，
     * 局部关闭即可。注释首行不要以 qmllint 开头。 */
    // qmllint disable unqualified

    Component {
        id: headerCellComp

        Item {
            id: hcell

            required property int index

            x:      root.colLayout.xs[index]
            width:  root.colLayout.widths[index]
            height: root.headerHeight

            readonly property var  col: root.columns[index]
            readonly property bool sortable: hcell.col !== null && hcell.col !== undefined
                                             && hcell.col.sortable === true
            readonly property bool isSortCol: root.sortColumn === hcell.index

            /* 伪装成"控件"给 Slots.label 读：header 变体 → 各主题表头字重 */
            readonly property string text: hcell.col && hcell.col.title !== undefined
                                           ? String(hcell.col.title) : ""
            readonly property string variant: "header"
            readonly property int labelAlignment: root._alignOf(hcell.col)

            Loader {
                id: hcellLabel

                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.leftMargin:     Theme.space.md
                /* 排序列给箭头留位，避免右对齐列的文字压到箭头上 */
                anchors.rightMargin:    Theme.space.md + (hcell.sortable ? hcellSortIcon.width : 0)
                anchors.verticalCenter: parent.verticalCenter

                sourceComponent: Slots.label

                Binding {
                    target: hcellLabel.item
                    property: "control"
                    value: hcell
                    when: hcellLabel.item !== null
                }
            }

            /* 排序方向指示：一个小实心三角，朝上 / 朝下。
             *
             * 这里**不**走插槽 —— 排序方向是**状态**，不是语言差异：
             * 升序朝上、降序朝下，四套设计系统都一样。插槽是用来装
             * 「各家不同」的，状态塞进去会让换肤开始换行为。
             * 所以就地画（与 QSkinMenu 自绘 hover 底色同一先例）。
             *
             * 也不打字符 "↑"/"↓" —— 项目对"图标用字符"的结论写在
             * BasicCheckIndicator / QSkinSelect / QSkinTag / QSkinInputNumber
             * 四份文件头里，理由都是字形覆盖率与回退不可控。 */
            Shape {
                id: hcellSortIcon

                anchors.right:           parent.right
                anchors.rightMargin:     Theme.space.md
                anchors.verticalCenter:  parent.verticalCenter
                visible: hcell.sortable && hcell.isSortCol

                width:  Math.round(Theme.font.sm * 0.6)
                height: Math.round(Theme.font.sm * 0.36)

                /* 朝上的三角是底形，降序翻过来。翻的是同一个图形，
                 * 所以宽高不变、占位也不变。 */
                rotation: root.sortDirection === "desc" ? 180 : 0
                transformOrigin: Item.Center

                Behavior on rotation {
                    enabled: root._sortIconAnimate
                    NumberAnimation {
                        duration: Theme.motion.fast
                        easing.type: Theme.motion.easing
                    }
                }

                ShapePath {
                    strokeWidth: -1                     // 只填充不描边
                    fillColor:   Theme.color.brand

                    startX: 0;                             startY: 0
                    PathLine { x: hcellSortIcon.width;     y: 0 }
                    PathLine { x: hcellSortIcon.width / 2; y: hcellSortIcon.height }
                    PathLine { x: 0;                       y: 0 }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: hcell.sortable
                cursorShape: Qt.PointingHandCursor
                onClicked: root._toggleSort(hcell.index)
            }

            /* ── 列宽拖拽热区（M12）──
             * 声明在排序 MouseArea **之后** —— 同级后声明的在上层，
             * 所以贴边这一条只吃拖拽、不会误触排序。
             *
             * 为什么热区探出单元格右沿半个宽度：
             * 视觉上的分隔线在单元格边界上，而人的手会瞄在线的两侧。
             * 一半在内一半在外，抓取成功率明显更高。 */
            Item {
                id: resizeHandle

                visible: root._resizableAt(hcell.index)
                x: parent.width - root.resizeHandleWidth / 2
                y: 0
                width:  root.resizeHandleWidth
                height: parent.height
                z: 10

                /* 视觉线只在 hover / 拖动时出现 —— 常态下表头是干净的，
                 * 用户把鼠标移上去才知道"这里可以拖"。
                 * 这是桌面表格的通行做法，也避免 N 列各画一条竖线。 */
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top:    parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    color: Theme.color.brand
                    opacity: (resizeArea.dragging || resizeArea.containsMouse) ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
                    }
                }

                MouseArea {
                    id: resizeArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SplitHCursor
                    preventStealing: true

                    property real startX: 0
                    property real startWidth: 0
                    property bool dragging: false

                    onPressed: function(mouse) {
                        resizeArea.startX = mapToItem(root, mouse.x, 0).x
                        resizeArea.startWidth = root.colLayout.widths[hcell.index]
                        resizeArea.dragging = true
                    }
                    onPositionChanged: function(mouse) {
                        if (!resizeArea.dragging) return
                        var nowX = mapToItem(root, mouse.x, 0).x
                        root.setColumnWidth(hcell.index,
                                            resizeArea.startWidth + (nowX - resizeArea.startX))
                    }
                    onReleased: resizeArea.dragging = false
                    onCanceled: resizeArea.dragging = false

                    /* 双击 → 按内容自适应 */
                    onDoubleClicked: root._autoFitColumn(hcell.index)
                }
            }
        }
    }

    Component {
        id: rowComp

        Item {
            id: row

            required property int index

            /* 裸 Item 容器不会自动排布子项（那是 Column 的活），
             * 行的纵向位置必须自己声明。 */
            y:      row.index * root.rowHeight
            /* 宽度跟随**宿主**而不是 root：同一个 rowComp 被实例化三次
             * —— 左固定区宿主宽 = `_leftWidth`，中间区宿主宽 = 内容宽，
             * 右固定区宿主宽 = `_contentTotal`。这样行的底色 / 分隔线 /
             * 点击热区各自只覆盖自己那一段，三段拼起来正好是一整行，
             * 不会互相盖住、也不会重复响应。
             * （Repeater 的 delegate 会被挂到 Repeater 的父项下，
             *   所以 row.parent 就是那三个宿主 Item。） */
            width:  parent.width
            height: root.rowHeight

            readonly property var rowData: root.displayRows !== null && root.displayRows !== undefined
                                           ? root.displayRows[row.index] : null
            readonly property bool isSelected: root.selectedRow === row.index
            readonly property bool isChecked: root._viewIsChecked(row.index)
            /** 树形下的半选（部分子项被选中）。平铺模式恒 false */
            readonly property bool isIndeterminate: root._viewIsIndeterminate(row.index)

            /* 悬停态提到 root 上（root.hoveredRow）—— 行被拆成两个宿主后，
             * 只标自己那一半会让整行看起来"只有半截变色" */
            readonly property bool hovered: root.hoveredRow === row.index

            Accessible.role: Accessible.ListItem
            Accessible.name: {
                var parts = []
                for (var i = 0; i < root.columnCount; ++i)
                    parts.push(root._cellText(row.rowData, root.columns[i]))
                return parts.join(", ")
            }

            /* hover / 选中底色 */
            Rectangle {
                anchors.fill: parent
                radius: 0
                color: row.isSelected ? Theme.color.brandSubtle : Theme.color.bgSunken
                visible: (row.hovered || row.isSelected)
                Behavior on color {
                    ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
                }
            }

            /* 行分隔线 */
            Rectangle {
                anchors.left:  parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.color.border
            }

            Repeater {
                model: root.columnCount
                delegate: cellComp
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onPositionChanged: root.hoveredRow = row.index
                onEntered:  root.hoveredRow = row.index
                onExited:   if (root.hoveredRow === row.index) root.hoveredRow = -1
                onClicked:  root._select(row.index)
            }

            /* checkbox 列（checkable 时）。声明在行 MouseArea 之后 ——
             * 同级后声明的在上层，点击先落在 checkbox 上，不会误触行。
             *
             * 判据是 `_showCheckColumn`（M15 起就 = `checkable`）。这里曾
             * 漏改过（表头改了、行没改），症状是树形下勾选框照常出现、
             * 表头却没有全选框 —— **两边不一致**才是露出的马脚。
             * M15 的应对是把两个渲染点都收回 `_view*` 出口、不再各自
             * 展开条件，见那对函数的注释。 */
            Item {
                id: rowCheckCol

                visible: root._showCheckColumn
                x: 0
                width: root.checkColumnWidth
                height: parent.height

                QSkinCheckBox {
                    id: rowCheck

                    anchors.centerIn: parent
                    onClicked: root._viewToggleCheck(row.index)

                    /* ── 为什么用 Binding，而不是直接写 `checked: ...` ──
                     * QSkinCheckBox._activate() 里会**命令式**写
                     * checked / indeterminate（半选点一下 → 全选）。
                     * QML 里命令式赋值会把同名绑定**永久拆掉** ——
                     * 平铺模式下看不出来（写进去的值恰好就是新状态，
                     * 界面停在正确的位置），但树形级联下会露馅：
                     * 勾满一个父、再取消它的一个子，父该转成半选 ——
                     * 而它的绑定已经没了，界面停在"全选"一动不动。
                     * 这是**跨刷新**才显形的错，属性断言抓不到，
                     * 只有截图能抓到。
                     * RestoreBindingOrValue 让绑定在被写之后自动恢复。 */
                    Binding { target: rowCheck; property: "checked"
                              value: row.isChecked
                              }
                    Binding { target: rowCheck; property: "indeterminate"
                              value: row.isIndeterminate
                              }
                }
            }

            /* ── 树形展开箭头（M14）──
             * 与 checkbox 列同一个理由：必须声明在行 MouseArea **之后**
             * —— 同级后声明的在上层，否则点击先被整行吃掉，变成
             * "点了箭头反而选中了行"。
             *
             * 箭头画在行里、而不是画进单元格，正是上面那条约束的推论：
             * 单元格是 Repeater 的子项，层级永远在行 MouseArea 之下，
             * 挂在它身上的热区一次点击都收不到。
             *
             * 位置用**内容坐标系**（与单元格同一套）：固定区宿主的局部
             * 坐标就是内容坐标，滚动区宿主整体左移了一个固定区宽，
             * 所以两边算出来的 x 相同，箭头自动落在正确的那一区里。
             *
             * 叶子节点不画箭头但**照样占位**（缩进由 cellComp 的
             * treeLead 负责），否则同层兄弟的文字左沿会不齐。 */
            Item {
                id: treeToggle

                readonly property var  meta: root._treeOn ? root._metaAt(row.index) : null
                readonly property bool shown: treeToggle.meta !== null
                                              && treeToggle.meta.hasChildren

                /* 与 cellComp.treeLead 同一套上限算法 —— 两处各算一份的话，
                 * 窄列上箭头和文字会错位 */
                readonly property int indent: {
                    if (treeToggle.meta === null) return 0
                    return Math.min(treeToggle.meta.level * root.treeIndentWidth,
                                    root._treeMaxIndent(root._treeColumnWidth()))
                }

                x:       root._treeColumnX() + Theme.space.md + treeToggle.indent
                y:       0
                width:   root.treeChevronWidth
                height:  parent.height
                visible: treeToggle.shown

                /* 箭头本身走 chevronIndicator 插槽 ——
                 * indicator 家族从 M1 起就列着「展开箭头」，但那一格一直
                 * 是空的。这里之前打的是字符 "▾"/"▸"，正是 BasicCheckIndicator
                 * / QSkinSelect / QSkinTag / QSkinInputNumber 四份文件头反复写明
                 * 不该做的事：Unicode 几何符号的字体覆盖率与回退不可控。
                 *
                 * **展开语义留在控件里**：收起 → 朝右，展开 → 朝下。
                 * 插槽只回答"朝右的箭头长什么样"，不解释 expanded ——
                 * 状态机是契约层的职责（Slots.qml 契约第 2 条）。 */
                Loader {
                    id: treeChevron

                    anchors.centerIn: parent
                    sourceComponent: Slots.chevronIndicator

                    Binding {
                        target: treeChevron.item
                        property: "control"
                        value: treeChevronProxy
                        when: treeChevron.item !== null
                    }
                }

                /* 伪装成控件给插槽读 —— 与表头 hcell、分页 totalCtl 同一套约定 */
                QtObject {
                    id: treeChevronProxy

                    readonly property string direction: treeToggle.meta !== null
                                                        && treeToggle.meta.expanded
                                                        ? "down" : "right"
                    readonly property bool enabled: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleExpand(treeToggle.meta.key)
                }
            }
        }
    }

    Component {
        id: cellComp

        Item {
            id: cell

            required property int index

            x:      root.colLayout.xs[index]
            width:  root.colLayout.widths[index]
            height: root.rowHeight

            readonly property var col: root.columns[index]

            /* 行宿主 = 本单元被 Repeater 挂进去的那一行（rowComp 实例）。
             * 不能直接引用 rowComp 里的 id —— 两个 inline Component 之间
             * id 不互通（声明作用域不同），运行时解析不到。 */
            readonly property var rowItem: cell.parent

            /* 伪装成"控件"给 Slots.label 读 —— 与菜单行 / 下拉选项同一套约定。
             * rowItem 在委托刚建 / 正在销毁的那一瞬是 null（Repeater 重建
             * 期间），这里必须兜一下：不兜的话会刷一串 TypeError，
             * 且那条绑定在 parent 变更后会重新求值，不需要别的处理。 */
            readonly property string text: root._cellText(rowItem ? rowItem.rowData : null, cell.col)
            readonly property string variant: "default"
            readonly property int labelAlignment: root._alignOf(cell.col)

            /* 树形：本行的树信息。只有箭头所在列拿得到，别的列是 null */
            readonly property var meta: root._treeOn && cell.index === root.treeColumn
                                        ? root._metaAt(cell.rowItem ? cell.rowItem.index : -1)
                                        : null

            /** 树形列的文字要往右让出的量 = 箭头位 + 缩进。
             * 叶子节点也占箭头位 —— 同一层兄弟的文字左沿才会齐。
             * 缩进走 `_treeMaxIndent` 的上限，与行里的箭头位置同源。 */
            readonly property int treeLead: {
                if (cell.meta === null) return 0
                return root.treeChevronWidth
                       + Math.min(cell.meta.level * root.treeIndentWidth,
                                  root._treeMaxIndent(cell.width))
            }

            Loader {
                id: cellLabel

                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.leftMargin:     Theme.space.md + cell.treeLead
                anchors.rightMargin:    Theme.space.md
                anchors.verticalCenter: parent.verticalCenter

                sourceComponent: Slots.label

                Binding {
                    target: cellLabel.item
                    property: "control"
                    value: cell
                    when: cellLabel.item !== null
                }
            }
        }
    }

    // qmllint enable unqualified

    /* ══════════════════════ 键盘 ══════════════════════ */

    Keys.onUpPressed:   root._move(-1)
    Keys.onDownPressed: root._move(1)

    Keys.onReturnPressed: {
        if (root.selectedRow >= 0) root.rowClicked(root.selectedRow)
    }
    Keys.onEnterPressed: {
        if (root.selectedRow >= 0) root.rowClicked(root.selectedRow)
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    /** 当前横向滚动位置（内容坐标，0 = 最左）。
     * 直接给的是 body.contentX 的别名 —— 写入请走 `scrollTo()`：
     * 别名写入不钳制，写超界会把内容拖出表格外且 StopAtBounds 不会弹回。 */
    property alias scrollX: body.contentX

    /** 把横向滚动移到 x（自动钳到合法范围）。外部同步 / 复位横滚用这个 */
    function scrollTo(x) {
        body.contentX = root._clampScrollX(x)
    }

    /* ── 滚动位置钳制（M13）──
     * 固定区的滚轮转发需要手动改 body.contentY/contentX，而
     * `Flickable.contentX` 在 Flickable **自己**滚的时候会自动夹在
     * 合法范围内，外部赋值却不会 —— 直接写会冲出边界，露出表格外的
     * 空白，而且因为 StopAtBounds，它不会自己弹回来。 */
    function _clampScrollX(v) {
        var max = Math.max(0, body.contentWidth - body.width)
        return Math.max(0, Math.min(v, max))
    }

    function _clampScrollY(v) {
        var max = Math.max(0, body.contentHeight - body.height)
        return Math.max(0, Math.min(v, max))
    }

    function _select(i) {
        root.selectedRow = i
        root.forceActiveFocus()
        root.rowClicked(i)
    }

    function _move(dir) {
        if (root.viewRowCount === 0) return
        var next = root.selectedRow + dir
        if (next < 0)                      next = 0
        if (next >= root.viewRowCount)     next = root.viewRowCount - 1
        root.selectedRow = next
        root.forceActiveFocus()
    }

    /* ── 树形：展开 / 收起（M14）──
     * 对外只有四个入口：isExpanded / setExpanded / toggleExpand /
     * expandAll + collapseAll。状态查询走 isExpanded(key)，
     * 批量读用 readonly 的 expandedKeys。 */

    /** 某个键当前是否展开 */
    function isExpanded(key) { return root._isExpanded(key) }

    function _isExpanded(key) {
        var st = root._expandState
        var s = (st !== null && st !== undefined) ? st[key] : undefined
        /* 没被显式设置过的节点吃默认值 —— 于是"换数据后新出现的节点"
         * 不需要任何重置逻辑，而 expandAll / collapseAll 是落成显式状态 */
        return s === undefined ? root.defaultExpandAll : s === true
    }

    /** 展开 / 收起一个节点。状态本来就一致时既不写状态也不发信号 */
    function setExpanded(key, expanded) {
        if (key === undefined || key === null) return
        var k = String(key)
        var on = expanded === true
        if (root._isExpanded(k) === on) return

        /* 整份换新对象而不是原地改：原地改不会触发绑定重算
         * （与 Theme.patch 同一条教训 —— `_expandState` 被 displayRows
         * 的绑定读着，原地改等于让界面停在旧状态） */
        var next = {}
        var st = root._expandState
        for (var p in st) next[p] = st[p]
        next[k] = on
        root._expandState = next
        root.expandToggled(k, on)
    }

    function toggleExpand(key) { root.setExpanded(key, !root._isExpanded(key)) }

    /** 全展开 */
    function expandAll()   { root._setAllExpanded(true) }

    /** 全收起 */
    function collapseAll() { root._setAllExpanded(false) }

    function _setAllExpanded(on) {
        var src = root.rows !== null && root.rows !== undefined ? root.rows : []
        var keys = TreeUtil.allKeys(src, root.treeKey, root.treeChildrenKey)
        var next = {}
        for (var i = 0; i < keys.length; ++i) next[keys[i]] = on
        root._expandState = next
    }

    /* 方向键：右展开、左收起（已经收起则跳到父节点）—— 树的常规操作，
     * 与上下键选行配套。非树形时不响应，免得抢走外层的左右键 */
    function _expandSelectedRow() {
        var m = root._metaAt(root.selectedRow)
        if (m !== null && m.hasChildren) root.setExpanded(m.key, true)
    }

    function _collapseSelectedRow() {
        var m = root._metaAt(root.selectedRow)
        if (m === null || !m.hasChildren) return
        if (m.expanded) { root.setExpanded(m.key, false); return }
        for (var i = root.selectedRow - 1; i >= 0; --i) {
            if (root.rowMeta[i].key === m.parentKey) { root.selectedRow = i; return }
        }
    }

    /* ── 排序（M6）── */

    function _toggleSort(col) {
        if (root.sortColumn === col) {
            root.sortDirection = root.sortDirection === "asc" ? "desc" : "asc"
        } else {
            root.sortColumn = col
            root.sortDirection = "asc"
        }
        root.sortChanged(root.sortColumn, root.sortDirection)
    }

    function _compare(a, b, key) {
        var av = a && a[key] !== undefined && a[key] !== null ? a[key] : null
        var bv = b && b[key] !== undefined && b[key] !== null ? b[key] : null
        if (av === null) return -1
        if (bv === null) return 1
        if (typeof av === "number" && typeof bv === "number") return av - bv
        var as = String(av), bs = String(bv)
        return as < bs ? -1 : (as > bs ? 1 : 0)
    }

    /* ── 两套下标换算（M6）── */

    /** 显示下标 → 数据下标。未排序且未分页时就是自身；否则经
     *  displayRows 的对象引用反查（切片 / 排序都不复制对象，引用相等成立）。
     *
     *  树形（M14）走另一条路：展平时就把原始下标记进了 `rowMeta`，
     *  这里直接取，O(1)。**不能**沿用下面的快路径 —— 折叠与同级排序都会
     *  让 viewIndex ≠ rows 下标，快路径会静默返回错误的行；而下面那条
     *  "按对象引用反查"对嵌套子节点也必然落空（它们压根不在 rows 里）。 */
    function _sourceIndex(viewIndex) {
        if (root._treeOn) {
            var m = root._metaAt(viewIndex)
            return m !== null ? m.sourceIndex : -1
        }
        var unsorted = root.sortColumn < 0 || root.sortColumn >= root.columnCount
        if (unsorted && root.pageSize <= 0) return viewIndex
        var rec = root.displayRows[viewIndex]
        var src = root.rows
        for (var i = 0; i < src.length; ++i)
            if (src[i] === rec) return i
        return -1
    }

    /** 可见行的树信息；越界 / 未就绪返回 null */
    function _metaAt(viewIndex) {
        if (viewIndex === undefined || viewIndex === null || viewIndex < 0) return null
        var ms = root.rowMeta
        if (ms === null || ms === undefined || viewIndex >= ms.length) return null
        return ms[viewIndex]
    }

    /* ── 树形：几何（单元格与行两处共用，不能各算一份）──────────── */

    /** 树形列的内容坐标 x；列下标越界时给 0 */
    function _treeColumnX() {
        var L = root.colLayout
        if (root.treeColumn < 0 || root.treeColumn >= L.xs.length) return 0
        return L.xs[root.treeColumn]
    }

    /** 树形列的宽度；列下标越界时给 0 */
    function _treeColumnWidth() {
        var L = root.colLayout
        if (root.treeColumn < 0 || root.treeColumn >= L.widths.length) return 0
        return L.widths[root.treeColumn]
    }

    /** 缩进量的上限：列宽里扣掉左右内边距、箭头位、以及留给文字的最小宽度。
     * 上限存在的意义与 minColumnWidth 一致 —— 宁可停止缩进，也不能让
     * 文字被挤成看不见。 */
    function _treeMaxIndent(colWidth) {
        return Math.max(0, colWidth - Theme.space.md * 2
                           - root.treeChevronWidth - root.treeMinLabelWidth)
    }

    /* ── 多选（M6）＋ 树形勾选（M15）────────────────────────────────────
     *
     * 对外入口（树形）：
     *   isSelected(key) / isIndeterminate(key)
     *   setSelected(key, on) / toggleSelected(key) / setSelectedKeys(keys)
     *   selectAll() / clearSelection()
     * 只读派生：selectedKeys / indeterminateKeys / selectedRows
     *
     * 平铺模式下这几条**全部不参与**，`selectedIndexes` 的 M6 语义
     * 一字未改 —— 零回归是这一节设计的硬约束。 */

    /** 已**完全选中**的节点数。树形时会筛掉数据里已不存在的陈旧键，
     * 否则换了数据之后表头会一直显示"全选"。 */
    readonly property int _checkedCount: {
        if (!root._treeOn) {
            var sel = root.selectedIndexes
            return (sel === null || sel === undefined) ? 0 : sel.length
        }
        return TreeUtil.countExisting(root._keySet, root._treeIndex)
    }

    readonly property bool _allSelected: root._treeOn
        /* 树形下"所有根都在集合" ⟺ "所有节点都在集合"（级联不变量），
         * 所以只数根就够了；count 兜住空树 */
        ? (root._treeIndex.count > 0 && root._checkedCount >= root._treeIndex.count)
        : (root.rowCount > 0 && root.selectedIndexes.length >= root.rowCount)

    readonly property bool _someSelected: root._checkedCount > 0 && !root._allSelected

    /* ── 渲染出口（M15）──────────────────────────────────────────────
     * **每一个渲染点都必须走这两个函数** —— 这是 M14 那条教训的直接产物：
     * 断言测的是属性值、不是渲染结果，只要有一处渲染点自己复制判据
     * （M14 就是数据行那处漏改了，表头改了），断言就永远绿、界面照错。
     * 所以勾选态的两个渲染点（表头 / 数据行）与这两个出口严格一一对应，
     * 不再各自展开条件。 */

    function _viewIsChecked(viewIndex) {
        if (root._treeOn) {
            var m = root._metaAt(viewIndex)
            return m !== null && root.isSelected(m.key)
        }
        var s = root._sourceIndex(viewIndex)
        return s >= 0 && root.selectedIndexes.indexOf(s) >= 0
    }

    /** 该可见行是否半选。**只有树形会有** —— 平铺没有祖先、
     * 也就没有"部分子项被选中"这回事 */
    function _viewIsIndeterminate(viewIndex) {
        if (!root._treeOn) return false
        var m = root._metaAt(viewIndex)
        return m !== null && root.isIndeterminate(m.key)
    }

    function _viewToggleCheck(viewIndex) {
        if (root._treeOn) {
            var m = root._metaAt(viewIndex)
            if (m !== null) root.toggleSelected(m.key)
            return
        }
        root._toggleCheck(root._sourceIndex(viewIndex))
    }

    /** 平铺模式的单点勾选（数据下标）。M6 原逻辑，一字未改 */
    function _toggleCheck(sourceIndex) {
        if (sourceIndex < 0) return
        var next = []
        for (var i = 0; i < root.selectedIndexes.length; ++i)
            if (root.selectedIndexes[i] !== sourceIndex) next.push(root.selectedIndexes[i])
        if (next.length === root.selectedIndexes.length) next.push(sourceIndex)
        root.selectedIndexes = next
        root.selectionChanged()
    }

    /** 表头全选 / 全不选（半选状态下点击也进全选） */
    function _toggleAll() {
        if (root._allSelected) root.clearSelection()
        else                   root.selectAll()
    }

    function _allSourceIndexes() {
        var out = []
        for (var i = 0; i < root.rowCount; ++i) out.push(i)
        return out
    }

    /* ── 树形勾选：查询与写入（M15）──────────────────────────────────── */

    /** 某个键是否**完全选中**（它自己 + 全部后代都在集合里）。
     * 半选是另一个查询，见 `isIndeterminate`。 */
    function isSelected(key) {
        if (key === undefined || key === null) return false
        return root._keySet[String(key)] === true
    }

    /** 某个键是否**半选**。`checkStrictly` 下恒 false */
    function isIndeterminate(key) {
        if (key === undefined || key === null) return false
        var k = String(key)
        if (root._keySet[k] === true) return false
        return root._subtreeHasChecked[k] === true
    }

    /** 勾 / 取消一个节点。**默认级联**：它自己 + 全部后代设成同一状态，
     * 然后自下而上重算祖先的"完全选中"。
     *
     * 状态本来就一致时既不写集合也不发信号 —— 与 `setExpanded` 同一条
     * 约定（免得把无变化的操作也广播出去）。 */
    function setSelected(key, selected) {
        if (key === undefined || key === null) return
        var idx = root._treeIndex
        var k = String(key)
        if (idx.byKey[k] === undefined) return
        var on = selected === true

        if (root.checkStrictly) {
            /* 严格模式：只动自己，也不重算祖先（祖先状态与子无关） */
            var set0 = root._keySet
            if ((set0[k] === true) === on) return
            var s0 = TreeUtil.cloneSet(set0)
            if (on) s0[k] = true
            else    delete s0[k]
            root._commitKeys(s0, idx)
            return
        }

        var next = TreeUtil.cloneSet(root._keySet)
        TreeUtil.applyCascade(idx, k, on, next)
        TreeUtil.refreshAncestorsOf(idx, k, next)
        root._commitKeys(next, idx)
    }

    /** 切换一个节点。**半选 → 全选** —— 与 QSkinCheckBox 的通用约定一致
     * （半选状态下点击进全选，而不是跳到空选）。
     *
     * 判据只有 `!isSelected(key)`，**不要把 isIndeterminate 加进去**。
     * M17 实测过这个错：写成 `!(isSelected || isIndeterminate)` 时，
     * 半选（isSelected=false、isIndeterminate=true）会被算成"要取消"，
     * 于是半选点一下变成**清空**，与上面这条约定正好相反。
     *
     * 三种状态过一遍就清楚了：
     *   空选   isSelected=false  → 取反 true  → 全选 ✓
     *   半选   isSelected=false  → 取反 true  → 全选 ✓（就是这条约定）
     *   全选   isSelected=true   → 取反 false → 清空 ✓
     * 半选的节点**本来就不在集合里**，所以"在不在集合"已经足够区分
     * "半选"和"全选"了，`isIndeterminate` 是多余且有害的一项。
     *
     * 这个 bug 从 M15 潜伏到 M17：`toggleSelected` 一直没有测试覆盖
     * （既有测试全走 `setSelected` / `selectAll` / `setSelectedKeys`），
     * 注释与实现相反也没人发现。`smoke_m17.qml` 的 [6] 现在守着它。 */
    function toggleSelected(key) {
        root.setSelected(key, !root.isSelected(key))
    }

    /** 整份设定选中键，并做**级联闭包**：
     *   给了父 → 后代自动补进来；
     *   给了全部直接子 → 父自动补上来；
     *   数据里不存在的键（陈旧）直接丢弃。
     * 传 null / [] 即清空。
     *
     * 为什么要闭合，而不是原样照收：`selectedKeys` 的不变量是
     * "父在集合 ⟺ 所有直接子都在集合"。照收会收到一个自相矛盾的集合，
     * 之后 `isIndeterminate` 就会给出莫名其妙的答案 ——
     * 宁可在这里多走一遍，也不让脏集合流进状态。 */
    function setSelectedKeys(keys) {
        var idx = root._treeIndex
        root._commitKeys(TreeUtil.normalize(idx, keys, root.checkStrictly), idx)
    }

    /** 全选。树形 = 所有根全选（级联自动带下全部后代）；
     *  平铺 = 勾选全部行（与 M6 表头全选一致，跨页同样成立） */
    function selectAll() {
        if (root._treeOn) {
            var idx = root._treeIndex
            var set = {}
            for (var i = 0; i < idx.roots.length; ++i)
                TreeUtil.applyCascade(idx, idx.roots[i], true, set)
            root._commitKeys(set, idx)
            return
        }
        root.selectedIndexes = root._allSourceIndexes()
        root.selectionChanged()
    }

    /** 清空选中 */
    function clearSelection() {
        if (root._treeOn) { root._commitKeys({}, root._treeIndex); return }
        root.selectedIndexes = []
        root.selectionChanged()
    }

    /* ── 树形勾选：内部（M15）──────────────────────────────────────────
     *
     * 算法本身全部在 `TreeUtil` 里（M17 下沉）：级联向下、自下而上闭合、
     * 祖先链重算、集合 → 前序数组、等价比较。
     *
     * 这里只留"提交"—— 因为它牵着**本控件的信号与绑定**，那是契约层的
     * 事，不该下沉到地基层。
     *
     * 为什么非下沉不可（而不仅是"重复了几行"）：级联算法一旦有第二份
     * 实现，`selectedKeys` 的不变量（父在集合 ⟺ 所有直接子都在集合）
     * 就有了两个版本，QSkinTree 的勾选会开始与这里给出不同答案。 */

    /** 提交新集合：转数组 → 没变就不写 → 变了就写并发信号 */
    function _commitKeys(set, idx) {
        var arr = TreeUtil.keysToArray(set, idx)
        if (TreeUtil.sameKeys(root.selectedKeys, arr)) return
        root.selectedKeys = arr
        root.keySelectionChanged(arr)
    }
}
