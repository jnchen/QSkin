/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicSelectOverlay
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「selectOverlay」插槽的 Basic 默认实现 —— 下拉面板的**外壳**。
 *
 * ── 浮层插槽为什么比别的插槽难 ────────────────────────────────────────
 * 一个下拉框同时有两半：
 *
 *     外壳：面板底色、圆角、描边、阴影、内边距      <- 视觉，应当可换肤
 *     列表：model、当前项、上下键导航、回车选中      <- 行为，不可换肤
 *
 * 这两半天生纠缠在一起 —— 列表要显示在面板里面。如果让主题直接整个实现
 * 下拉面板，键盘导航和无障碍就得写 N 遍，契约层就白做了。
 *
 * 拆法沿用 Qt Quick Controls 的思路：**控件持有 ListView，插槽持有外壳**，
 * 控件把 ListView 作为 content 注入插槽，插槽负责把它摆进自己的内容区。
 * 于是主题换的是"面板长什么样"，逻辑一行没动。
 *
 * ── 契约 ──────────────────────────────────────────────────────────────
 *   property var  control   宿主（QSkinSelect），只读其状态
 *   property Item content   宿主注入的 ListView；插槽必须负责
 *                           把它 reparent 进内容区并使其可见
 *   implicitWidth/Height    浮层建议尺寸（面板本体，不含阴影）。
 *                           高度优先取 control.contentHeight（宿主上报的
 *                           精确内容高度，M5 契约扩展）；宿主没上报时
 *                           按「等高行 × 行数」估算
 *   extender                阴影等向外溢出面板边界的宽度（M4 契约回收）。
 *                           宿主据此把 Popup 放大 extender*2（padding），
 *                           否则阴影会被 Popup 边界裁掉。Basic 无阴影，为 0。
 *                           主题的浮层如果画了外扩阴影，必须如实上报。
 *
 * 契约第 3 条在这里尤其要紧：插槽里不要放 MouseArea / Keys。
 * 列表的键盘导航在 QSkinSelect 里，只有一份。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var  control: null
    property Item content: null

    /** 面板内边距 —— 列表与面板边缘的留白 */
    property int padding: Theme.space.xs

    /** 阴影外扩量（M4 契约回收）。Basic 无阴影，恒为 0。 */
    readonly property real extender: 0

    /* 面板高度由"可见行数"决定：超过 maxVisibleRows 就滚动。
     * 这三个值都从宿主读（契约允许插槽读宿主状态），
     * 因为"一个面板最多显示几行"属于外观，主题应当能改。 */
    readonly property int rows: control && control.count !== undefined ? control.count : 0
    readonly property int maxRows: control && control.maxVisibleRows !== undefined
                                   ? control.maxVisibleRows : 6
    readonly property int rowHeight: control && control.rowHeight !== undefined
                                     ? control.rowHeight : Theme.size.controlMd

    /* 宽度：宿主上报什么就取什么 —— 契约**允许**它只报自己知道的那几项
     * （本仓就有宿主只报 count / rowHeight / contentHeight，不知道面板多宽）。
     * 少了 `!== undefined` 守卫，`undefined` 的赋值会失败并报运行期警告
     * `Unable to assign [undefined] to double`；而失败后 QML **保留**上一次
     * 的值（M31 实测：保留下来的正是 200，与这里的兜底同值），
     * 于是界面上完全看不出来，它只在累积日志里露头。
     * 上面 rows / maxRows / rowHeight 三行与这里同源，一并按这个规矩写。 */
    implicitWidth:  control && control.width !== undefined ? control.width : 200
    /* 面板高度：宿主可以经 control.contentHeight 上报内容的**精确**高度
     * （M5 契约扩展——菜单里有分隔线这类不等高条目，宿主最清楚每行多高）；
     * 没上报就按"等高行 × 行数"估算（QSkinSelect 的情形，行高一致，估算即精确）。 */
    implicitHeight: (control && control.contentHeight !== undefined
                     ? control.contentHeight
                     : Math.max(1, Math.min(root.rows, root.maxRows)) * root.rowHeight)
                    + root.padding * 2

    /* ── 面板外壳 ──
     * Basic 实现只给底色 + 描边。阴影交给主题层：
     * TDesign 是 0 4px 12px 的柔和阴影，shadcn 几乎不用阴影，
     * 这类差异放进 Basic 只会逼着每个主题来覆盖。 */
    Rectangle {
        id: panel

        anchors.fill: parent
        radius:       Theme.radius.md
        color:        Theme.color.bgElevated
        border.width: 1
        border.color: Theme.color.border
    }

    /* ── 内容区 ──
     * clip 是必须的：列表滚动时不能溢出圆角面板。 */
    Item {
        id: host

        anchors.fill:    parent
        anchors.margins: root.padding
        clip:            true
    }

    /* 宿主注入的 ListView 声明在 QSkinSelect 里（visible: false，等在这里
     * 被接管）。接管的动作是 reparent —— 一旦换了父节点，
     * ListView 自己写的 anchors.fill: parent 会自动指向 host。 */
    onContentChanged: {
        if (root.content) {
            root.content.parent = host
            root.content.visible = true
        }
    }
}
