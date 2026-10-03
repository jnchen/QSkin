/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinAlert
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 行内提示条（M22）。
 *
 * ── 它与 QSkinToast / QSkinNotification 的分工（三个都别丢）─────────────────
 *     QSkinToast         一句话、居中、自动消失、不打断 —— "已保存"
 *     QSkinNotification  有标题、右上角、可手动关 —— "同步失败，点这里重试"
 *     QSkinAlert         **留在页面里**，跟内容一起滚动 —— "当前套餐将于
 *                      3 天后到期" / "该字段已废弃，请改用 X"
 *
 * 前两个是**浮层**（脱离文档流、位置与内容无关）；Alert 是**行内**元素，
 * 它出现的意义是"这句话就长在这里"。所以它不归 OverlayStack 管，
 * 也没有停留时长、没有堆叠 —— 这一条是选它还是选 Toast 的唯一判据。
 *
 * ── 覆盖到哪一步 ────────────────────────────────────────────────────────
 * 已实现：type（4 种语义）/ title / description / showIcon / closable /
 *         action（行尾操作区）
 *
 * 刻意**没做**的（消费者为零，按项目规矩"没有消费者就不做"）：
 *   · `banner`（Ant / Arco 有）—— 整页横幅模式，差异只是圆角归零 +
 *     通栏。等真有"页面级告警条"的需求再加，现在加只会多一条没测过的分支。
 *   · `icon`（Ant 有）—— 自定义图标。没有消费者；而"换整块提示的视觉"
 *     更该走主题层（statusGlyph 插槽），不该由调用点逐个覆盖。
 *   · `afterClose` 回调 —— `close` 信号已经够用。
 *
 * ── 为什么标题走 label 插槽（与 QSkinDialog / QSkinNotification 同一格）────
 * 项目的惯例是"标题不许自己画一个 Text"（QSkinDialog / QSkinNotification /
 * QSkinLabel 三处都写了这条）。这里照办 —— 换主题时提示条的标题与
 * 对话框标题一起变，不会有一条掉队。
 *
 * ── 已知的债：这是第三份 ✕ ──────────────────────────────────────────────
 * 关闭按钮那个 ✕ 在本仓库已经是**第三份**（QSkinTag 一份、
 * QSkinNotification 一份、这里一份）。项目有条判据写着「反复申明的规则
 * 被反复违反时，缺的不是自觉，是那个格子」——所以正解是一个**跨控件
 * 共用的关闭按钮**。
 *
 * 它**不能**做成插槽：契约第 3 条禁止插槽引入交互（MouseArea / Keys），
 * 而关闭按钮必须有可点区域与 hover 态。所以它该是一个契约层的组件
 * （QSkinCloseButton 之类），由 QSkinTag / QSkinNotification / QSkinAlert 共用。
 *
 * 本批没有顺手做它，理由是**优先级**：M22 的目标是补覆盖度缺口
 * （Alert / Result / AlertDialog 三件），而这次重构会动到 M21 已经
 * 像素核验过的 QSkinNotification。已明确记进 COVERAGE.md 的待做，
 * 等第四个消费者出现时和它一起收 —— 不是"忘了"，是排在后面。
 * 当前这份的几何与 QSkinNotification 那一份**逐点相同**，所以三份之间
 * 至少不会互相不一致。
 *
 * 用法：
 *     QSkinAlert {
 *         type: "warning"
 *         title: "当前套餐即将到期"
 *         description: "3 天后将自动降级到免费版。"
 *         closable: true
 *         onClose: dismiss()
 *     }
 ****************************************************************************/

import QtQuick 2.15
/* Layout.* 附加属性来自这里。QSkinDialog 那边是从 QtQuick.Controls 间接
 * 拿到的，而这三件不用 Controls，得显式引 —— 否则 qmllint 会报
 * "unknown attached property scope Layout"。 */
import QtQuick.Layouts 1.15
/* 关闭按钮那个 ✕ 是 Shape 画的（不用 "×" 字符，见文件头）。 */
import QtQuick.Shapes
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** info | success | warning | danger（缺省 info；不认识的值按 info） */
    property string type: "info"

    /** 标题（可选）。空则整行不占位 */
    property string title: ""

    /** 说明文字（可选）。多行自动换行 */
    property string description: ""

    /** 是否显示左侧语义记号 */
    property bool showIcon: true

    /** 是否显示右上角关闭按钮 */
    property bool closable: false

    /** 行尾操作区（Ant / Arco 的 `action`）。没塞东西就整块不占位，
     *  连它前面的间距都不会留下 —— 判据见下面 actionHost 的注释。 */
    property alias action: actionHost.data

    signal close()

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property string _type: (root.type === "success" || root.type === "warning"
                                     || root.type === "danger") ? root.type : "info"

    readonly property color toneColor: root._type === "success" ? Theme.color.success
                                     : root._type === "warning" ? Theme.color.warning
                                     : root._type === "danger"  ? Theme.color.danger
                                                                : Theme.color.info

    readonly property color toneSubtle: root._type === "success" ? Theme.color.successSubtle
                                      : root._type === "warning" ? Theme.color.warningSubtle
                                      : root._type === "danger"  ? Theme.color.dangerSubtle
                                                                 : Theme.color.infoSubtle

    readonly property bool hasTitle:       root.title !== ""
    readonly property bool hasDescription: root.description !== ""

    /* 宽度由调用方给（行内元素本就该吃满所在栏宽），高度随内容。
     * implicitWidth 只用来在"没人给宽度"时提供一个合理下限。 */
    implicitWidth:  360
    implicitHeight: layout.implicitHeight

    /* ══════════════════════ 底板 ══════════════════════
     * 语义色的用法：**底色用 subtle 档、描边用本色**。
     *
     * Ant / Arco 的描边用的是本色的"中间档"（Ant info 是 #91caff 而不是
     * #1677ff），而令牌集里只有 subtle 与本色两档，没有中间档 ——
     * 于是这里用本色，视觉上比 Ant 硬一点。这是**已知偏差**，两条出路
     * 都不是这一批该走的：给四家各加四个 <type>Border 令牌（4×4×2 = 32
     * 个值只为一条描边），或者让组件算一个透明度（那就把颜色混色逻辑
     * 从主题搬进了控件，本末倒置）。
     *
     * 所以先按本色画，交给像素核验去看它到底有多硬 —— 深色模式下
     * subtle 本身就是深色块（如 tdesign dark 的 infoSubtle = #062E9A），
     * 描边在那种底色上其实读不出来，两档之间的差也随之消失。 */
    Rectangle {
        anchors.fill: parent

        radius: Theme.radius.lg
        color:  root.toneSubtle
        border.width: 1
        border.color: root.toneColor
    }

    /* ══════════════════════ 布局 ══════════════════════ */

    QSkinRow {
        id: layout

        anchors.fill: parent
        padding: Theme.space.md
        gap:     Theme.space.sm

        /* 交叉轴对齐跟着"有没有说明文字"走 —— 这是 Ant 的真实行为：
         * 带说明的提示条（可能换行多行）用 flex-start，记号贴标题首行；
         * 只有一行的提示条用 center，记号与文字居中对齐。
         *
         * 一条属性两种取值，不是随手加的：单行提示条若也贴顶，
         * 行尾那颗按钮（32 高）会把行高撑起来，于是文字看起来吊在顶上。
         * Row/Column 的 manageAlignment 会把这条播给每个子项，
         * 所以按钮与关闭钮跟着一起对齐 —— 一致正是要的。 */
        align: root.hasDescription ? "start" : "center"

        /* ── 语义记号 ──
         * 走 statusGlyph 插槽（M22 新增的第六族）。尺寸显式给 20：
         * 记号在 Alert 里与标题同级，比正文大一号才立得住。 */
        Loader {
            id: iconLoader

            visible: root.showIcon
            sourceComponent: Slots.statusGlyph

            /* Layout 的交叉轴对齐由上面 QSkinRow 的 align 管；这里只补一点
             * 上边距，让记号的中点落在标题首行的中线上。 */
            Layout.topMargin: Theme.space.xxs

            Binding {
                target: iconLoader.item
                property: "control"
                value: glyphCtl
                when: iconLoader.status === Loader.Ready
            }
        }

        QtObject {
            id: glyphCtl

            readonly property string status: root._type
            readonly property int size: Theme.size.iconMd
        }

        /* ── 文字列 ── */
        QSkinColumn {
            Layout.fillWidth: true
            gap: Theme.space.xxs

            Loader {
                id: titleLabel

                visible: root.hasTitle
                sourceComponent: Slots.label
                Layout.fillWidth: true

                Binding {
                    target: titleLabel.item
                    property: "control"
                    value: titleCtl
                    when: titleLabel.status === Loader.Ready
                }
            }

            QtObject {
                id: titleCtl

                readonly property string text: root.title
                readonly property string variant: "header"
                readonly property int labelAlignment: Text.AlignLeft
            }

            Body {
                Layout.fillWidth: true

                visible: root.hasDescription
                text:    root.description
                tone:    "secondary"
            }
        }

        /* ── 行尾操作区 ──
         * visible 绑到 implicitWidth 而**不是** `data.length`：
         * 空的 QSkinRow 的 implicitWidth 恰好是 0，而这个属性是可通知的
         * 绑定属性；list 的 length 不保证通知。判据写成
         * "宽度为 0 就不显示"，于是"塞了东西"与"占位与否"天然一致 ——
         * RowLayout 会跳过不可见子项，连它前面的 spacing 也不会留下。 */
        QSkinRow {
            id: actionHost

            visible: actionHost.implicitWidth > 0
            gap: Theme.space.xs
            Layout.fillWidth: false
        }

        /* ── 关闭按钮 ──
         * ✕ 用 Shape 画，不用 "×" 字符 —— 项目既有规则（见
         * BasicChevronIndicator 文件头那份四处清单）。几何与
         * QSkinNotification 那一份逐点相同（24% → 76% 对角、
         * 笔宽 = 边长 14%、圆端点），所以第三份与第二份至少长得一样。 */
        Item {
            id: closeBtn

            visible: root.closable

            Layout.alignment: Qt.AlignTop
            Layout.topMargin:  Theme.space.xxs

            width:  Theme.size.iconSm
            height: Theme.size.iconSm

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: Math.max(1, closeBtn.width * 0.14)
                    strokeColor: closeMouse.containsMouse
                                 ? Theme.color.fg : Theme.color.fgMuted
                    fillColor:   "transparent"
                    capStyle:    ShapePath.RoundCap

                    startX: closeBtn.width * 0.24
                    startY: closeBtn.height * 0.24
                    PathLine { x: closeBtn.width * 0.76; y: closeBtn.height * 0.76 }
                }

                ShapePath {
                    strokeWidth: Math.max(1, closeBtn.width * 0.14)
                    strokeColor: closeMouse.containsMouse
                                 ? Theme.color.fg : Theme.color.fgMuted
                    fillColor:   "transparent"
                    capStyle:    ShapePath.RoundCap

                    startX: closeBtn.width * 0.76
                    startY: closeBtn.height * 0.24
                    PathLine { x: closeBtn.width * 0.24; y: closeBtn.height * 0.76 }
                }
            }

            MouseArea {
                id: closeMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.close()
            }
        }
    }

    /* 无障碍：整条提示是一个状态消息。名字取标题（没有则取说明），
     * 空标题空说明时不报名字，免得读屏念出一串空白。 */
    Accessible.role: Accessible.AlertMessage
    Accessible.name: root.hasTitle ? root.title
                    : root.hasDescription ? root.description
                                          : ""
}
