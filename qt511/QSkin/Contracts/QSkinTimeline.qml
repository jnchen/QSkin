/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinTimeline
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 时间轴（M23）—— 把若干 `QSkinTimelineItem` 竖着叠起来，并**管两件事**：
 * 全序（谁是第一/最后，决定线的两个端点）、以及行距。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 行距为什么是 0，间距改由**条目自己**的底部留白承担
 * ════════════════════════════════════════════════════════════════════════
 * 连接线是**条目自己画的**（上段 + 下段，见 QSkinTimelineItem 文件头）。
 * 于是若容器在两个条目之间留间距，线就会**断开** —— 上一条的下段线止于
 * 自己的行底，下一条的上段线从自己的行顶开始，中间那一截没有任何人画。
 *
 * 而"线要连贯"是这条控件最要紧的视觉承诺：它读起来是一根**穿过**所有点
 * 的线，不是 N 段各自带线的行。
 *
 * 所以：`gap: 0`，条目之间的呼吸空间由条目自己的 `bottomGap` 给
 * （最后一条不给 —— 否则整条时间轴下面会多出一截空白）。
 * 这样"线连贯"在结构上成立，而不是靠两个数恰好相等。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么它是容器，而 QSkinRadioGroup 不是
 * ════════════════════════════════════════════════════════════════════════
 * 判据与 QSkinCollapse 完全一致（那边写得详细，这里给结论）：时间轴与折叠
 * 面板一样**没有排列自由度** —— 它就是竖着叠的一列（横向时间轴是另一个
 * 控件，见 QSkinTimelineItem 文件头"刻意没做"）。而它需要一层的**全序**
 * 来回答"第一颗点之上不画线"。
 *
 * 对比：单选组的排列是开放的（后面可能跟说明、输入框、要排两列），
 * 所以那里组必须是 QtObject。**判据不是"组该不该是容器"，而是
 * "这个组的排列有没有自由度"。**
 *
 * 用法：
 *     QSkinTimeline {
 *         QSkinTimelineItem { type: "success"; label: "09:12"; QSkinBody { text: "构建通过" } }
 *         QSkinTimelineItem { type: "danger";  label: "09:40"; QSkinBody { text: "部署失败" } }
 *         QSkinTimelineItem {                  label: "现在";  QSkinBody { text: "等待复审" } }
 *     }
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 条目（default property） */
    default property alias items: stack.data

    /** 整条时间轴的可用性（条目可读它，本件不据此改视觉） */
    property bool enabled: true

    /** 条目沿 `parent` 链往上找组时认这个标记（见 QSkinTimelineItem._findGroup）。
     *  用标记而不是"有没有 `_register` 这个方法"：QSkinRadioGroup 也有同名
     *  方法，靠函数名撞运气会让条目接错线。 */
    readonly property bool _isTimelineGroup: true

    /* ══════════════════════ 成员登记 ══════════════════════
     * 与 QSkinCollapse 完全同一套协议（那边文件头有论证，QSkinTimelineItem 的
     * `_findGroup` 有实测）：成员自己沿 parent 链找上来登记，调用方不用写
     * `timeline: 组名`。顺序由 MemberOrder 按**声明序**矫正。 */

    property var _items: []

    function _register(item) {
        if (item === null || item === undefined) return
        if (root._items.indexOf(item) >= 0) return
        var out = root._items.slice()
        out.push(item)
        root._items = MemberOrder.sortByDeclaration(out)
    }

    function _unregister(item) {
        var i = root._items.indexOf(item)
        if (i < 0) return
        var out = root._items.slice()
        out.splice(i, 1)
        root._items = out
    }

    /* ══════════════════════ 视觉 ══════════════════════ */

    implicitWidth:  320
    implicitHeight: stack.implicitHeight

    /* gap 必须是 0 —— 理由见文件头。别"顺手加一点间距"。 */
    QSkinColumn {
        id: stack

        anchors.fill: parent
        gap: 0
    }
}
