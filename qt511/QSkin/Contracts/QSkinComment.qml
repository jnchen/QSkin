/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinComment
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 评论（M24）—— 头像 + 作者/时间 + 正文 + 动作行。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这个件在参照实现里的状态是"已废弃"（Ant v5 的 Comment 标了 deprecated），
 * 所以本件的目标不是把它做厚，而是**把边界画对**：
 * ════════════════════════════════════════════════════════════════════════
 * 不做成"评论列表"、不做成"回复树"、不做成"评论区"。
 * 一条评论就是一个块 —— 列表用 QSkinList / 一个 QSkinColumn 摆，
 * 回复树用**嵌套**（下面那段）。把这三件事揉进一个控件，
 * 是这个件被各家废弃之后留下的那个空档，不要去填它。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 嵌套不新开属性
 * ════════════════════════════════════════════════════════════════════════
 * 把一条 QSkinComment 放进上一条的**默认子项**里，给它 `indent` 即可：
 *
 *     QSkinComment {
 *         author: "张伟"; content: "这个方案我同意"
 *         QSkinComment {
 *             indent: Theme.space.xl
 *             author: "李娜"; content: "同意 +1"
 *         }
 *     }
 *
 * 需要顶层一个 `replies` 数组属性吗？不需要 —— 那等于在控件里写一层
 * 只有一种用法的 listview。
 *
 * ── 线程连接线（左边那条竖线）**故意不画** ─────────────────────────────
 * 三条参照里 Ant / TDesign / Arco 的嵌套评论都只有缩进、没有竖线。
 * 竖线属于"评论列表"这个视图的装饰（它的职责是让读者看清层级跨度），
 * 不属于"一条评论"。要就自己摆一根 QSkinDivider —— 一行的事，
 * 而且那一行会出现在代码评审里（好事）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 文字用**哪一层**：这是本件最该被抄走的一条
 * ════════════════════════════════════════════════════════════════════════
 *     控件的字（单行、受状态影响、主题要能整体换掉）→ `Slots.label`
 *     内容的字（多行、随宽度换行）                → Body / Caption
 *
 * 理由不是审美，是一条**能力**约束：BasicLabel 是
 * `wrapMode: 默认（NoWrap）` + `elide: ElideRight`，它服务的是按钮、
 * 表头、菜单项、日期格子这些单行场景。拿它渲染评论正文，长评论会被
 * **截成一行加省略号**，而属性侧一切正常（text 是对的、字号是对的），
 * 只有看懂渲染的人才发现正文没了。M17 那句"属性值对 ≠ 界面画对"
 * 在这里是一次结构性的重演。
 *
 * 于是本件：作者名用 `Body`（14/1.5 行高，加一档字重）、时间用
 * `Caption`（12，muted）、正文用 `Body`。三样都读 `Theme.font.*`，
 * 主题照样管得住 —— 换主题时字号字重跟着走，与走插槽是同一个结果。
 * **动作行**（"回复 / 删除"）反过来：它是单行可点文字，走
 * `Slots.label` 的 `ghost` 变体（品牌色 = 看起来可点）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 时间戳是**字符串**，不做相对时间
 * ════════════════════════════════════════════════════════════════════════
 * "3 分钟前"要不要变形、什么时候从"刚刚"变成"1 分钟前"、用不用本地化
 * 复数 —— 这三件事都是业务与 i18n 的判断。更要紧的是：相对时间让控件
 * **依赖时钟**，于是它无法被确定性抓图核验（同一个组件今天拍是"3 分钟前"、
 * 明天拍是"1 天前"，像素门禁的基准就废了）。
 *
 * QSkinCalendar 的 `today` 也是同一条取舍，两处口径一致。
 * 需要相对时间的宿主自己格式化好再传进来 —— 一行 `Date.now()` 的事。
 ****************************************************************************/

import QtQuick 2.11
/* 内容列里的文字与加载器要写 Layout.fillWidth（它们在一个 ColumnLayout
 * 里）—— 与 QSkinDialog / QSkinPopover 同一处需要。 */
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    /** 作者名。同时是头像的替代文本（没给 avatarAlt 时）。 */
    property string author: ""

    /** 头像地址。 */
    property url avatar: ""

    /** 头像的替代文本。 */
    property string avatarAlt: ""

    /** 头像上显示的文字（姓名缩写 / 首字母）。
     *  不给就退到 `author` **全文** —— QSkinAvatar 刻意不自动缩写
     *  （见其文件头："张伟"该显示成"张"还是"张伟"是本地化判断），
     *  想要缩写请在这一格里给。 */
    property string avatarText: ""

    /** 时间戳。**已经格式化好的字符串**，见文件头。 */
    property string datetime: ""

    /** 正文（纯文本，会换行）。富内容请用默认子项。 */
    property string content: ""

    /** 动作行。数组，每项是 `"回复"` 或 `{ text: "删除", disabled: true }`。
     *  点击发 `actionClicked(index)` —— 控件不猜"回复"该做什么。 */
    property var actions: []

    /** 默认子项：正文下面追加的内容（富文本、图片、**嵌套的 QSkinComment**）。
     *  这些子项被放进一个 ColumnLayout，所以横向上需要
     *  `Layout.fillWidth: true` 才会铺满。 */
    default property alias body: contentHost.data

    /* ══════════════════════ 外观 ══════════════════════ */

    /** 左侧缩进（px）。嵌套时给 Theme.space.xl。 */
    property int indent: 0

    /** 头像边长。 */
    property int avatarSize: Theme.size.controlLg

    /* ══════════════════════ 事件 ══════════════════════ */

    signal actionClicked(int index)

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property int _gap: Theme.space.md

    readonly property int _actionCount:
        (root.actions && root.actions.length !== undefined) ? root.actions.length : 0

    readonly property bool _hasHeader: root.author !== "" || root.datetime !== ""

    /* 与 QSkinImage / QSkinCard 同一条：宽度由宿主给（正文换行需要知道
     * 可用宽度），高度随内容。 */
    implicitWidth: 0
    implicitHeight: Math.max(root.avatarSize, bodyColumn.implicitHeight)

    Accessible.role: Accessible.Grouping
    Accessible.name: root.author

    /* ══════════════════════ 头像 ══════════════════════ */

    QSkinAvatar {
        id: authorAvatar

        x: root.indent
        y: 0
        size: root.avatarSize

        src: root.avatar
        alt: root.avatarAlt !== "" ? root.avatarAlt : root.author
        text: root.avatarText !== "" ? root.avatarText : root.author
    }

    /* ══════════════════════ 正文列 ══════════════════════ */

    QSkinColumn {
        id: bodyColumn

        x: root.indent + root.avatarSize + root._gap
        y: 0
        width: Math.max(0, root.width - bodyColumn.x)
        gap: Theme.space.xs

        /* ── 作者 · 时间 ── */
        QSkinRow {
            Layout.fillWidth: true
            visible: root._hasHeader
            align: "baseline"
            gap: Theme.space.sm

            Body {
                text: root.author
                font.weight: Theme.font.weightMedium
            }

            Caption {
                visible: root.datetime !== ""
                text: root.datetime
                tone: "muted"
            }
        }

        /* ── 正文 + 富内容（唯一的内容宿主）── */
        QSkinColumn {
            id: contentHost

            Layout.fillWidth: true
            gap: Theme.space.xs

            Body {
                Layout.fillWidth: true
                visible: root.content !== ""
                text: root.content
            }
        }

        /* ── 动作行 ──
         * 这一格里的字是**控件的字**（单行 + 可点），所以走 Slots.label。 */
        QSkinRow {
            Layout.fillWidth: true
            visible: root._actionCount > 0
            gap: Theme.space.md

            Repeater {
                model: root.actions

                /* 这个 delegate 的**绑定**引用外层 id（root）会触发
                 * qmllint 的 Unqualified access —— 原因与取舍见
                 * QSkinCalendar 里那段完整归因（同一个结构，同一份实测）。
                 * 本件照同一口径局部关闭。 */
                // qmllint disable unqualified
                delegate: Item {
                    id: actionItem

                    property int index
                    property var modelData

                    readonly property string actionText:
                        typeof actionItem.modelData === "string"
                            ? actionItem.modelData
                            : (actionItem.modelData && actionItem.modelData.text !== undefined
                               ? "" + actionItem.modelData.text : "")
                    readonly property bool actionDisabled:
                        actionItem.modelData !== null
                        && typeof actionItem.modelData === "object"
                        && actionItem.modelData.disabled === true

                    width:  actionLabel.implicitWidth
                    height: actionLabel.implicitHeight

                    Loader {
                        id: actionLabel

                        anchors.fill: parent
                        sourceComponent: Slots.label

                        Binding {
                            target: actionLabel.item
                            property: "control"
                            value: actionProxy
                            when: actionLabel.item !== null
                        }
                    }

                    QtObject {
                        id: actionProxy
                        readonly property string text: actionItem.actionText
                        readonly property string variant: "ghost"
                        readonly property int labelAlignment: Text.AlignLeft
                        readonly property bool enabled: !actionItem.actionDisabled
                    }

                    /* 悬停反馈：label 插槽的颜色由主题定，不能在控件里改，
                     * 所以用一根下划线表达"这个能点"。 */
                    Rectangle {
                        anchors.left:  parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color:  Theme.color.brand
                        visible: actionMa.containsMouse && !actionItem.actionDisabled
                    }

                    MouseArea {
                        id: actionMa

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !actionItem.actionDisabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.actionClicked(actionItem.index)
                    }
                }
                // qmllint enable unqualified
            }
        }
    }
}
