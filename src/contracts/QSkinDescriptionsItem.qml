/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinDescriptionsItem
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 描述列表里的**一组**「标签 : 值」（M24）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 四种形态都由这一件承担，而不是四个组件
 * ════════════════════════════════════════════════════════════════════════
 *            水平（标签在左）              垂直（标签在上）
 *   无边框   标签右对齐 + 冒号 + 值        标签一行（muted）+ 值
 *   有边框   label 格（底纹）+ value 格     同一个格子里上下两段
 *
 * 差别只在**两个盒子往哪摆**。做成四个组件意味着四份成员登记、四份
 * "找组"逻辑 —— 而它们本来共享同一份（见 QSkinDescriptions 文件头）。
 * 所以本件读组的状态、自己算几何；单独使用（不给组）时退回
 * "无边框 + 水平"，也就是最常用的那一档。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么"值"只有**一个**宿主，而且它直接挂在根上
 * ════════════════════════════════════════════════════════════════════════
 * 首版把两个形态写成两个容器（一个 QSkinRow + 一个 QSkinColumn），
 * `default property alias content` 指向其中一个 —— 于是**垂直形态下
 * 值被塞进了那个隐藏的容器**，屏幕上只剩标签。属性侧完全看不出来
 * （`contentHost.data.length` 是对的，只是没人渲染它）。
 *
 * 所以现在只有一个 `contentHost`，直接挂在根上，几何按模式算：
 *
 *     水平：x = 左边距 + 标签格宽，纵向居中（对齐 QSkinRow 的 align: center）
 *     垂直：标签在上、值在下方（顶对齐）
 *
 * 几何写在一个纯函数里（`_inner()`），绑定与"量高度"走同一条算路 ——
 * 两份算路的控件迟早会在某一档上错开（M20 记过这条）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 格线只画**左**与**上** —— 这是"不出现双线"的唯一做法
 * ════════════════════════════════════════════════════════════════════════
 * 相邻两格各画一圈框，中间那条边会变成 2px。所以内部格线按
 * "左邻居存在 / 上邻居存在"画（`col > 0` / `row > 0`），四条外边由
 * **容器**画。这样最后一行不满时，右侧那片补白只是"没有内部格线"，
 * 不会缺边框。
 *
 * ════════════════════════════════════════════════════════════════════════
 * `span` 是"占几列"，不是"在第几列"
 * ════════════════════════════════════════════════════════════════════════
 * 从第几列开始，只有知道**前面所有成员的 span 之和**才算得出来 ——
 * 那件事归组（`_offsetOf`）。成员只把 `span` 翻成 `Layout.columnSpan`。
 *
 * `Layout.fillHeight` 只在有边框时打开：表格的行高必须由**最高的一格**
 * 决定，否则同一行里两格的下边缘会错开 —— 那是表格最显眼的破绽。
 *
 * 用法（写在 QSkinDescriptions 里面）：
 *     QSkinDescriptionsItem { label: "订单号"; Body { text: "SO-2026-0914" } }
 *     QSkinDescriptionsItem { label: "备注"; span: 2; Body { text: "…" } }
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 标签文字。空则只排值（那一档用来放"跨整行的说明"） */
    property string label: ""

    /** 占几列。会被夹到 [1, group.column] */
    property int span: 1

    /** 值（default property）—— 直接写内容，不走字符串 */
    default property alias content: contentHost.data

    /** 所属的描述列表。**一般不写** —— 成员自己沿 `parent` 链找组
     *  （协议见 QSkinCollapseItem 文件头）。显式给只在"隔着容器"时用。 */
    property var descriptions: null

    /** 整组是否可点（点了发 `clicked`，并让组发 `itemClicked`） */
    property bool clickable: false

    signal clicked()

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property var _group: (root.descriptions !== null
                                   && root.descriptions !== undefined)
                                  ? root.descriptions : root._foundGroup

    property var _foundGroup: null

    readonly property bool _bordered: root._group !== null
                                      ? root._group.bordered === true : false

    readonly property bool _vertical: root._group !== null
                                      ? root._group._vertical === true : false

    /** 水平 + 无边框才画冒号：有边框时标签有自己的格子，冒号多余；
     *  垂直时它在上一行，更不该有。 */
    readonly property bool _colon: !root._bordered && !root._vertical
                                   && (root._group === null
                                       ? true : root._group.colon !== false)

    readonly property int _cellPad: root._bordered ? Theme.space.md : 0

    readonly property int _cols: root._group !== null
                                 ? Math.max(1, root._group.column) : 1

    readonly property int _offset: root._group !== null
                                   ? root._group._offsetOf(root) : 0

    /** 标签列的统一宽度（组的 `_uniformLabelWidth`，见那份文件头）。
     *  单独使用（没有组）时退回量自己。 */
    readonly property real _labelW: root._group !== null
                                    ? root._group._uniformLabelWidth
                                    : root.labelWidthHint

    /** 左邻居 / 上邻居存在 → 画那条内部格线 */
    readonly property bool _leftLine: root._bordered && (root._offset % root._cols) > 0
    readonly property bool _topLine:  root._bordered
                                      && Math.floor(root._offset / root._cols) > 0

    /** 渲染出来的那个 label。**声明成 `var` 而不是走 `labelLoader.item`**：
     *  `Loader.item` 的静态类型是 QObject，qmllint 会在它上面报
     *      Member "implicitWidth" not found on type "QObject"
     *  插槽契约本来就是鸭子类型（见 BasicLabel 文件头），该用 var。
     *  QSkinDivider 量自己的 label 用的是同一个写法。 */
    readonly property var _labelItem: labelLoader.item

    /** 本件标签的实际渲染宽度 —— 组用它算统一宽度。
     *  **必须量渲染出来的那个 label**（而不是另起一个 Text）：主题换掉
     *  label 之后字号/字重会变，自己量的那个还是旧数。 */
    readonly property real labelWidthHint:
        (labelLoader.status === Loader.Ready && root._labelItem !== null)
        ? root._labelItem.implicitWidth : 0

    /** 标签文字（冒号拼在这里，而不是另起一个 Text）—— Ant 的 `colon`
     *  也是这么做的：冒号属于**标签文本**，不属于值。 */
    readonly property string labelText:
        root.label + (root._colon && root.label !== "" ? qsTr("：") : "")

    /** 标签那一格的高度（单行；空标签为 0） */
    readonly property real _labelH:
        root.label !== "" && labelLoader.status === Loader.Ready
        ? Math.max(root._labelItem.implicitHeight, 1) : 0

    /** 标签那一格的宽度：有边框时它是一格（含左右内距），否则就是文字宽 */
    readonly property real _labelW2: root.label !== ""
                                     ? (root._bordered ? root._labelW + root._cellPad * 2
                                                       : root._labelW)
                                     : 0

    /* ══════════════════════ 几何（纯函数，绑定与量高共用）══════════════════════ */

    /** 内部几何：{ labelX, labelY, labelW, labelH, contentX, contentY, contentW, h }
     *  所有值都在**本件的坐标系**里，且 `h` 是不含内距的净高。
     *
     *  ── `labelX` 是 0，不是 `pad`（M24 像素核验抓出来的真缺陷）──────────
     *  底纹格就是**单元格本身**（见上面那段注释："标签是一格带底纹的**单元格**"），
     *  所以它必须从单元格的左边界起、铺到右边界，两侧靠 `Loader` 的
     *  `leftMargin/rightMargin` 留内距。原先写的是 `labelX: pad` +
     *  `labelW: width - pad*2`，于是底纹格两侧各空出一个 `pad` 的页底色 ——
     *  **单元格里出现一条不属于任何东西的空带**，看着像一块浮起来的标签片。
     *
     *  这一条**属性侧抓不到**：`_uniformLabelWidth` 照样返回一个数、
     *  `labelAlignment` 照样是 AlignLeft，冒烟测试全绿。抓到它的是 [P5]
     *  那条"底纹格的左右边界必须与单元格一致"——量的是 `bgSubtle` 的
     *  连通段端点。tdesign 亮色实测：格 720..980，底纹段 732..967.3。
     *
     *  顺带修掉的第二件：`Loader` 的 `leftMargin` 也会加一次 `pad`，而
     *  `labelX` 再加一次 —— 标签文字因此比值多缩进了整整一个 `pad`
     *  （实测标签 744 / 值 732.7）。`labelX: 0` 之后两者都是 `pad`。 */
    function _inner() {
        var pad  = root._cellPad
        var lh   = root._labelH
        var lw   = root._labelW2
        var ch   = contentHost.implicitHeight
        var gap  = root.label !== "" ? Theme.space.xxs : 0

        if (root._vertical) {
            return {
                labelX: 0, labelY: pad,
                labelW: Math.max(0, root.width), labelH: lh,
                contentX: pad, contentY: pad + lh + gap,
                contentW: Math.max(0, root.width - pad * 2),
                h: pad * 2 + lh + gap + ch
            }
        }
        /* 水平：标签在左、值在右；两者都纵向居中（对齐 QSkinRow 的 center）。
         * `lw` 已经含了有边框时的两侧内距（`_labelW2`），所以底纹格从 0 起
         * 就是"文字 + 两侧 pad"，标签文字正好落在 `pad` 上。 */
        var inner = Math.max(lh, ch)
        return {
            labelX: 0,
            labelY: pad + (inner - lh) / 2,
            labelW: lw, labelH: lh,
            contentX: pad + lw,
            contentY: pad + (inner - ch) / 2,
            contentW: Math.max(0, root.width - pad * 2 - lw),
            h: pad * 2 + inner
        }
    }

    readonly property var _geo: root._inner()

    implicitHeight: root._geo.h
    implicitWidth:  root._bordered
                    ? (root._cellPad * 4 + root._labelW + 80)
                    : (root._labelW + Theme.space.md + 80)

    /* 表格行高由最高的一格决定（见文件头）。 */
    Layout.columnSpan: Math.max(1, Math.min(root.span, root._cols))
    Layout.fillHeight:  root._bordered

    /* ══════════════════════ 格线 ══════════════════════ */

    Rectangle {
        visible: root._leftLine
        x: 0; y: 0
        width: 1
        height: parent.height
        color: Theme.color.border
    }

    Rectangle {
        visible: root._topLine
        x: 0; y: 0
        width: parent.width
        height: 1
        color: Theme.color.border
    }

    /* ══════════════════════ 标签 ══════════════════════ */

    Item {
        id: labelWrap

        visible: root.label !== ""
        x: root._geo.labelX
        y: root._geo.labelY
        width:  root._geo.labelW
        height: root._geo.labelH

        /* 有边框时标签是一格**带底纹**的单元格（Ant / Arco 都这样把
         * "标签"与"值"分开）。无边框时它只是一段文字，底纹是透明的 ——
         * 于是同一个 Item 承担两种外观，差别只在颜色与内距。 */
        Rectangle {
            anchors.fill: parent
            color: root._bordered ? Theme.color.bgSubtle : "transparent"
        }

        Loader {
            id: labelLoader

            anchors.fill: parent
            anchors.leftMargin:  root._bordered ? root._cellPad : 0
            anchors.rightMargin: root._bordered ? root._cellPad : 0

            sourceComponent: Slots.label
            active: root.label !== ""

            Binding {
                target: labelLoader.item
                property: "control"
                value: labelCtl
                when: labelLoader.status === Loader.Ready
            }
        }

        QtObject {
            id: labelCtl

            readonly property string text: root.labelText
            readonly property string variant: root._bordered ? "default" : "muted"
            /* 无边框时右对齐（它贴着值）；有边框时左对齐（它是一格）。 */
            readonly property int labelAlignment: root._bordered
                                                  ? Text.AlignLeft
                                                  : Text.AlignRight
        }
    }

    /* ══════════════════════ 值（唯一宿主）══════════════════════ */

    QSkinColumn {
        id: contentHost

        x: root._geo.contentX
        y: root._geo.contentY
        width:  root._geo.contentW
        height: implicitHeight
        gap: Theme.space.xxs
        padding: 0
    }

    /* ══════════════════════ 行为 ══════════════════════ */

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root._activate()
    }

    function _activate() {
        if (!root.clickable) return
        root.clicked()
        if (root._group !== null) root._group.itemClicked(root._offset)
    }

    /* 向组登记（协议与 QSkinCollapseItem 同源）。 */
    Component.onCompleted: {
        if (root._group === null) {
            var g = root._findGroup()
            if (g !== null) root._foundGroup = g
        }
        if (root._group !== null) root._group._register(root)
    }
    Component.onDestruction: if (root._group !== null) root._group._unregister(root)

    /** 沿 `parent` 链找最近的描述列表。用**标记**而不是"有没有 `_register`"
     *  —— QSkinRadioGroup / QSkinCollapse 都有同名方法，靠函数名撞运气会接错线。 */
    function _findGroup() {
        var p = root.parent
        var guard = 0
        while (p !== null && p !== undefined && guard < 16) {
            // qmllint disable missing-property
            if (p._isDescriptionsGroup === true) return p
            // qmllint enable missing-property
            p = p.parent
            guard++
        }
        return null
    }
}
