/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinPageHeader
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 页头 —— 一页顶上的那块：返回 / 面包屑 / 标题 / 副标题 / 标签 /
 * 右侧操作区 / 正文 / 底部条，底下一条分隔线。参照 Arco 的 `PageHeader`
 * （Ant 官方已把它的 `PageHeader` 标为废弃、建议用 Breadcrumb + Typography
 * 手搭 —— 但 Arco 有它，按本清单的入列判据「三家任一有 → 入列」它就该在）。
 *
 * ── 它解决的也是"抄一遍"的问题（与 QSkinLayout 同一个理由）─────────────
 * 后台里每个详情页都要一条"返回 + 标题 + 操作按钮"，手搭十遍就有十个
 * 略有出入的版本（最典型的是标题与按钮的基线终于对齐了没有、分隔线到底
 * 通栏还是缩进）。这里把它变成一次性的东西：**骨架自己排**，
 * 用户只往槽里放内容 —— 与 QSkinLayout「各栏是属性 + alias 内容」同一种收法。
 *
 * ── 六个槽，都是 alias（不是"给一整个 Item"）──────────────────────────
 *     breadcrumb  面包屑。放一个 QSkinBreadcrumb 进去即可，本件不重造它
 *     tags        标题下方的标签行。放 QSkinTag
 *     extra       右侧操作区。放按钮组
 *     content     **默认属性**：标题下方的正文
 *     footer      底部条（页头自己的，不是页脚）
 * 加上 title / subtitle 两个字符串属性、以及可选的返回按钮。
 *
 * 返回箭头走 `chevronIndicator` 插槽（`direction: "left"`）——
 * "箭头长什么样"是主题差异，本件只回答"什么时候朝左"。
 *
 * ── 已知边界 ─────────────────────────────────────────────────────────
 * · **不做** Ant 那种"标题旁挂头像/多行标题带滚动联动"。没有消费者。
 * · 分隔线一律通栏（不缩进）—— Arco 通栏、Ant 缩进到内容宽度。
 *   选通栏是因为它更能表达"这条线属于页面而不是属于那块内容"，
 *   而且它是**几何上更简单**的那一种：通栏的左右端点就是容器的左右端点，
 *   像素判据可以写等号（缩进版要先算一个内边距，多一处约定可漂移的地方）。
 * · 六个槽全空时本件高度 = 上下内边距 + 分隔线（不会塌成 0），
 *   免得宿主在"数据还没到"的那一帧看到它跳高。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    property string title: ""
    property string subtitle: ""

    /** 显示返回按钮。点了发 `backClicked()` —— 本件不自己导航（它不知道往哪回） */
    property bool showBack: false

    /* ══════════════════════ 槽 ══════════════════════ */

    property alias breadcrumb: crumbHost.data
    property alias tags:       tagHost.data
    property alias extra:      extraHost.data
    property alias footer:     footerHost.data
    default property alias contentData: contentHost.data

    /* ══════════════════════ 外观 ══════════════════════ */

    property color bgColor: "transparent"
    property int padding: Theme.space.lg
    property int spacing: Theme.space.sm

    /** 标题与副标题之间更紧一点，它们是一个整体 */
    property int titleSpacing: Theme.space.xxs

    property bool showDivider: true
    property color dividerColor: Theme.color.divider

    /* ══════════════════════ 信号 ══════════════════════ */

    signal backClicked()

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property bool hasBreadcrumb: crumbHost.data.length > 0
    readonly property bool hasTags:       tagHost.data.length > 0
    readonly property bool hasFooter:     footerHost.data.length > 0
    readonly property bool hasExtra:      extraHost.data.length > 0

    /** 标题行本身：有返回按钮、或有标题、或有右侧操作区时才算存在。
     *  否则空页头会撑出一整行高度。 */
    readonly property bool hasTitleRow: root.showBack
                                        || root.title !== ""
                                        || root.subtitle !== ""
                                        || root.hasExtra

    /* ══════════════════════ 几何 ══════════════════════ */

    implicitWidth:  480
    implicitHeight: root.padding * 2 + col.implicitHeight
                    + (root.showDivider ? 1 : 0)

    Rectangle {
        id: bg
        anchors.fill: parent
        color: root.bgColor
    }

    QSkinColumn {
        id: col

        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.margins: root.padding
        gap: root.spacing

        /* ── 面包屑 ── */
        QSkinRow {
            id: crumbHost
            visible: root.hasBreadcrumb
            Layout.fillWidth: true
            gap: root.spacing
        }

        /* ── 标题行 ── */
        QSkinRow {
            id: titleRow

            visible: root.hasTitleRow
            Layout.fillWidth: true
            gap: root.spacing
            align: "center"

            QSkinButton {
                id: backBtn

                visible: root.showBack
                Layout.alignment: Qt.AlignVCenter
                size: "sm"
                variant: "ghost"
                icon: Slots.chevronIndicator
                iconDirection: "left"
                accessibleName: qsTr("返回")
                onClicked: root.backClicked()
            }

            /* 标题块吃掉余量 —— QSkinRow 里只要有**一个** fillWidth 的子项，
             * 余量就归它（见 QSkinRow.qml 那段注释）。 */
            QSkinColumn {
                id: titleCol

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                gap: root.titleSpacing

                Text {
                    id: titleText

                    width: titleCol.width
                    visible: root.title !== ""
                    text: root.title
                    elide: Text.ElideRight
                    color: Theme.color.fg
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.lg
                    font.weight: Theme.font.weightSemiBold
                }

                Text {
                    id: subText

                    width: titleCol.width
                    visible: root.subtitle !== ""
                    text: root.subtitle
                    elide: Text.ElideRight
                    color: Theme.color.fgSecondary
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.sm
                    font.weight: Theme.font.weightRegular
                }
            }

            QSkinRow {
                id: extraHost

                visible: root.hasExtra
                Layout.alignment: Qt.AlignVCenter
                gap: Theme.space.xs
            }
        }

        /* ── 标签行 ── */
        QSkinRow {
            id: tagHost
            visible: root.hasTags
            Layout.fillWidth: true
            gap: Theme.space.xs
        }

        /* ── 正文（默认属性）── */
        QSkinColumn {
            id: contentHost

            visible: contentHost.data.length > 0
            Layout.fillWidth: true
            gap: root.spacing
        }

        /* ── 底部条 ── */
        QSkinRow {
            id: footerHost
            visible: root.hasFooter
            Layout.fillWidth: true
            gap: Theme.space.xs
        }
    }

    /* ── 分隔线 ──
     * 通栏：左右端点就是本件的左右端点（见文件头"已知边界"）。 */
    Rectangle {
        id: divider

        visible: root.showDivider
        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.dividerColor
    }

    Accessible.role: Accessible.Grouping
    Accessible.name: root.title
}
