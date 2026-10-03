/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinPopconfirm
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 气泡确认 —— "删之前再问一句"的那个气泡。
 *
 * ── 为什么它是 QSkinPopover 派生，而不是自己做一个 Popup ──────────────────
 * 它需要的东西**一样都不少**：锚定到某个按钮、下方放不下就翻上去、
 * 窗口边界夹取、点外部关掉、Esc 关掉、"同刻只有一个浮层"。
 * 这些正好是 QSkinPopover 的全部内容 —— 自己再写一遍就是项目里第二份
 * 定位代码，然后第三份、第四份。
 *
 * 所以本文件只回答两件事：
 *   · 内容长什么样（一段话 + 两个按钮）
 *   · 按钮按下时往外交代什么（confirmed / canceled）
 *
 * ── 为什么按钮区是 ButtonBar 而不是 QSkinRow + Spacer ────────────────────
 * 按钮的**顺序与危险间距**是平台规则（Windows 主按钮在左、macOS 在右），
 * ButtonBar 已经在处理，而且 QSkinDialog 的按钮区用的就是它 ——
 * 同一个产品里两处按钮排列不应该有两套规矩。
 *
 * 但有一处必须显式关掉：`stackWhenNarrow`。气泡确认的面板本来就窄
 * （默认 250），ButtonBar 的堆叠阈值是 320，不关掉的话两个按钮会永远
 * 竖排 —— 那是给窄屏对话留的行为，不是给气泡的。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

QSkinPopover {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    /** 主文案（一句话说清要确认什么） */
    property string text: ""

    /** 补充说明，可选 */
    property string description: ""

    property string okText: qsTr("确定")
    property string cancelText: qsTr("取消")

    /** 危险操作 —— 确认按钮换成 danger 变体（删除类操作应当它是红的） */
    property bool danger: false

    /* ══════════════════════ 接口 ══════════════════════ */

    signal confirmed()
    signal canceled()

    /* ── 可核验抓手 ────────────────────────────────────────────────────
     * 两个按钮是这一族**唯一的出口**。门禁如果够不着它们，就只能
     * `emit confirmed()` 自证 —— 那等于把信号又听了一遍，什么都没证明。
     * 交出来的是真按钮，于是"点它"走的是完整路径（close + 发信号）。 */
    readonly property alias okButton:     okBtn
    readonly property alias cancelButton: cancelBtn

    /* 面板宽度默认 250：一句话 + 两个按钮在这一档最稳。
     * 调用方仍可覆盖（实例上的绑定优先级更高）。 */
    panelWidth: 250

    accessibleRole: Accessible.Dialog
    accessibleName: root.text !== "" ? root.text : root.description

    QSkinColumn {
        gap: Theme.space.md

        /* 两段文字都要 Layout.fillWidth：面板是定宽的，不填满就不会折行，
         * 长文案会直接把面板撑宽（或溢出）。 */
        Body {
            Layout.fillWidth: true

            visible: root.text !== ""
            text:    root.text
        }

        Body {
            Layout.fillWidth: true

            visible: root.description !== ""
            text:    root.description
            tone:    "secondary"
        }

        ButtonBar {
            Layout.fillWidth: true

            /* 见文件头：气泡面板窄，堆叠行为在这里只会帮倒忙 */
            stackWhenNarrow: false

            /* 声明顺序 = 取消在前、确认在后。主按钮"写在最后"是
             * ButtonBar 的既定约定，由它按平台决定最终显示在左还是右。 */
            QSkinButton {
                id: cancelBtn

                text: root.cancelText
                onClicked: {
                    root.close()
                    root.canceled()
                }
            }

            QSkinButton {
                id: okBtn

                text:    root.okText
                variant: root.danger ? "danger" : "primary"
                onClicked: {
                    root.close()
                    root.confirmed()
                }
            }
        }
    }
}
