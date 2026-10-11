/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinAlertDialog
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 确认对话框**预设**（M22）。它不是 QSkinDialog 的替代品，是它的一个取值 ——
 *
 *     QSkinDialog       要自己摆内容与按钮的通用模态框
 *     QSkinAlertDialog  "问我一句，然后给我一个答复" 这个具体形状
 *
 * ── 它与 QSkinDialog 的三条差异（都是 Ant / TDesign / Arco / shadcn 的共识）
 *   1. 点遮罩**不关**（`dismissOnScrim` 默认 false）。确认框的语义是
 *      "必须选一个"，误触遮罩就关掉会让调用方永远等不到答复。
 *   2. 语义记号 + 标题 + 说明的固定排版（Ant 的 Modal.confirm、
 *      TDesign Dialog 的 `theme`、Arco 的 Modal.confirm 都是这个形状）。
 *   3. 按钮区是**固定的两个**：取消 + 确定。只开放文案与语义类型。
 *
 * ── "预设"的边界为什么划在按钮区 ────────────────────────────────────────
 * 有人会想要"确认框里换一套按钮"。那正是 QSkinDialog 的职责 ——
 * 给预设再加一个 footer 口子，等于把 Dialog 的灵活性与 AlertDialog 的
 * 约定混进同一格，两边都变得要先读文档才知道自己拿到的是哪个。
 * 所以：**要自定义按钮行就往回退到 QSkinDialog**，这里只管"取消 + 确定"。
 *
 * ── 出口统一（一个容易做错的地方）────────────────────────────────────────
 * 关闭这个对话框有四条路：点取消、点确定、按 Esc、点遮罩（默认已关掉，
 * 但调用方可以打开）。四条路都必须发出**恰好一个**信号，否则会出现
 * "用户按 Esc 关掉了，调用方还在等一个永远不来的回调"。
 *
 * 所以两个按钮都**只调 close()**，由 `opened` 的下降沿决定发哪一个，
 * 而"点的是确定"这件事先记在 `_confirmIntent` 里。这样新加的关闭路径
 * 自动被覆盖 —— 不必在四个地方各记得发一次信号。
 *
 * ── 零新增插槽 ──────────────────────────────────────────────────────────
 * 记号走 `statusGlyph`（M22 新增的那一格）、标题走 `label` 的 header 变体、
 * 按钮区走 `ButtonBar`（QSkinDialog 现成的）、底板与遮罩走令牌。
 * 所以这一件没有为自己的外观新开任何一格。
 *
 * 用法：
 *     QSkinAlertDialog {
 *         id: confirm
 *         type: "danger"
 *         title: "删除这 3 个文件？"
 *         description: "删除后不可恢复。"
 *         confirmText: "删除"
 *         onConfirmed: doDelete()
 *     }
 *     confirm.open()
 ****************************************************************************/

import QtQuick 2.11
/* Layout.* 附加属性来自这里（见 QSkinAlert.qml 同处的说明）。 */
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** info | success | warning | danger（缺省 warning）
     *  —— 与 QSkinAlert / QSkinNotification 同一个四值语义轴。
     *  warning 是缺省：Ant 的 Modal.confirm 就是用感叹号，
     *  而"确认"这件事本身多半带着一点"请注意"。 */
    property string type: "warning"

    /** 是否显示标题左侧的语义记号（关掉它 = Ant 的 `icon: null`） */
    property bool showIcon: true

    property string title: ""
    property string description: ""

    /** 面板宽度。高度随内容（hug） */
    property int panelWidth: 420

    property string cancelText: qsTr("取消")
    property string confirmText: qsTr("确定")

    /** 确定按钮的 variant。留空则由 `type` 推：
     *  danger → "danger"，其余 → "primary"。 */
    property string confirmVariant: ""

    /** 点遮罩是否关闭。确认框默认**关掉**（见文件头第 1 条） */
    property bool dismissOnScrim: false

    readonly property bool opened: dlg.opened

    /** 额外内容（表单、清单……）。排在说明文字之下。 */
    default property alias content: customHost.data

    /** 用户选了"确定"。Esc / 遮罩关闭走的也是下面那一个信号 */
    signal confirmed()

    /** 用户放弃了（取消 / Esc / 遮罩） */
    signal cancelled()

    function open()  { dlg.open()  }
    function close() { dlg.close() }

    implicitWidth:  0
    implicitHeight: 0

    /* ══════════════════════ 出口 ══════════════════════ */

    /** 已按下确定：等对话框真正关上时据此决定发哪个信号 */
    property bool _confirmIntent: false

    readonly property string _type: (root.type === "success" || root.type === "danger"
                                     || root.type === "warning") ? root.type : "info"

    readonly property string _confirmVariant: root.confirmVariant !== "" ? root.confirmVariant
                                             : root._type === "danger"   ? "danger"
                                                                         : "primary"

    /* 下降沿即出口。`QSkinDialog.opened` 是 `popup.visible` 的别名，
     * 而 Popup 定义了 exit Transition —— 所以它会等**退场动画播完**
     * 才变 false（约一个 motion.fast 的时间）。这不是延迟 bug，
     * 是"关上之后才通知"；调用方看到信号时对话框已经不在屏幕上了。 */
    onOpenedChanged: {
        if (root.opened) { root._confirmIntent = false; return }
        if (root._confirmIntent) root.confirmed()
        else                     root.cancelled()
        root._confirmIntent = false
    }

    /* ══════════════════════ 本体 ══════════════════════
     *
     * `title` 刻意**不**传给 QSkinDialog —— 那一格是"对话框自带标题行"，
     * 而这里要的是"记号 + 标题"同一行的确认框排版。所以对话框自己的标题
     * 留空（它那一行会整行消失），标题由下面这一行里的 label 插槽渲染。
     * 两者用的是**同一格插槽**，所以换主题时不会有一条掉队。 */
    QSkinDialog {
        id: dlg

        panelWidth:     root.panelWidth
        dismissOnScrim: root.dismissOnScrim

        /* ── 记号 + 标题 + 说明 ── */
        QSkinRow {
            Layout.fillWidth: true
            gap:   Theme.space.sm
            align: "start"

            Loader {
                id: glyphLoader

                visible: root.showIcon
                sourceComponent: Slots.statusGlyph

                Layout.topMargin: Theme.space.xxs

                Binding {
                    target: glyphLoader.item
                    property: "control"
                    value: glyphCtl
                    when: glyphLoader.status === Loader.Ready
                }
            }

            QtObject {
                id: glyphCtl

                readonly property string status: root._type
                /* iconLg（24）—— 对话框标题比 Alert 的 20 大一档，
                 * 记号跟着大一档，两者在各自场景里与标题同高。 */
                readonly property int size: Theme.size.iconLg
            }

            QSkinColumn {
                Layout.fillWidth: true
                gap: Theme.space.xxs

                Loader {
                    id: titleLabel

                    visible: root.title !== ""
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

                    visible: root.description !== ""
                    text:    root.description
                    tone:    "secondary"
                }
            }
        }

        /* ── 额外内容 ──
         * 空的时候必须整块消失，否则内容列（gap = lg）会白留一段间距 ——
         * 判据与 QSkinAlert 的 action / QSkinResult 的 extra 相同：
         * 绑到 implicitHeight（空列恰好为 0，而这个属性可通知）。 */
        QSkinColumn {
            id: customHost

            Layout.fillWidth: true
            visible: customHost.implicitHeight > 0
            gap: Theme.space.sm
        }

        /* ── 按钮区 ──
         * 主按钮写在**最后**（取消在前、确定在后）—— ButtonBar 会按平台
         * 惯例决定它显示在左还是右（Windows 主按钮在左），也会在危险按钮
         * 两侧自动加安全间距。这两件事都不该在这里重复一遍。
         *
         * 两个按钮都只调 close()：信号由上面的下降沿统一发。 */
        footer: [
            QSkinButton {
                text: root.cancelText
                onClicked: dlg.close()
            },
            QSkinButton {
                text: root.confirmText
                variant: root._confirmVariant
                onClicked: {
                    root._confirmIntent = true
                    dlg.close()
                }
            }
        ]
    }
}
