/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinDialog
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 模态对话框（M8 反馈三件套之一）。
 *
 * ── 分工 ─────────────────────────────────────────────────────────────
 *   本文件：开合状态机、Esc / 遮罩点击关闭策略、内容/按钮区结构、
 *           开合动画（opacity + 微缩放，走 motion 令牌）、焦点
 *   插槽：  标题走 Slots.label 伪装 "header" 变体（与表格表头同款）
 *
 * ── 面板视觉为什么零新插槽 ───────────────────────────────────────────
 *   遮罩  令牌 scrim / scrimOpacity（M0 就备好了）
 *   面板  bgElevated（注释里写的本来就是"卡片、弹层"）+ border + radius.lg
 *   标题  label 插槽 header 变体（M5 引入）
 *   按钮  footer 直接用 ButtonBar（foundation 现成的按钮布局系统）
 *
 * 已知取舍：面板暂无阴影 —— 浮层插槽（selectOverlay）的阴影语义
 * 依赖"宿主上报 extender"契约，Dialog 若要阴影应等一条 dialogPanel
 * 契约，而不是把阴影写死在契约层。V1 用 border 立轮廓（shadcn 本就无阴影）。
 *
 * 用法：
 *     QSkinDialog {
 *         id: confirmDialog
 *         title: "删除文件"
 *         panelWidth: 420
 *         Body { text: "删除后不可恢复，确定吗？" }
 *         footer: [                       // 直接给按钮 —— footer 本身就是
 *             QSkinButton { ... },          // 一个 ButtonBar，不必再包一层
 *             QSkinButton { ... }
 *         ]
 *     }
 *     confirmDialog.open()
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    property string title: ""

    /** 面板宽度。高度随内容（hug），不设固定值 */
    property int panelWidth: 440

    /** 点遮罩是否关闭（Esc 永远可关）。确认类对话框建议关掉 */
    property bool dismissOnScrim: true

    /** 内容区（default property）。按钮区用 footer 别名放 ButtonBar */
    default property alias content: bodyHost.data

    property alias footer: footerHost.data

    readonly property alias opened: popup.visible
    /* opened 是 alias，QML 自动生成 openedChanged 通知 —— 不必
     * （也不能）再自定义同名信号 */

    function open()  { popup.open()  }
    function close() { popup.close() }

    implicitWidth: 0
    implicitHeight: 0

    /* ══════════════════════ 模态层 ══════════════════════ */

    Popup {
        id: popup

        /* 挂到窗口 Overlay 层再居中 —— root 本体在调用方布局里
         * 可能只有 0×0，直接 centerIn parent 会飘（M4 的浮层经验） */
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: root.panelWidth
        padding: 0

        modal: true
        closePolicy: root.dismissOnScrim
                     ? Popup.CloseOnEscape | Popup.CloseOnPressOutside
                     : Popup.CloseOnEscape

        /* 遮罩走令牌 —— Popup 的标准附着写法 */
        Overlay.modal: Rectangle {
            color:  Theme.color.scrim
            opacity: Theme.color.scrimOpacity
        }

        /* 面板本体：无插槽化，令牌组合 */
        background: Rectangle {
            color:        Theme.color.bgElevated
            border.color: Theme.color.border
            border.width: 1
            radius:       Theme.radius.lg
        }

        contentItem: QSkinColumn {
            padding: Theme.space.xl
            gap:     Theme.space.lg

            /* 标题（可选）：label 插槽 header 变体 */
            Loader {
                id: titleLabel

                visible: root.title !== ""
                sourceComponent: Slots.label

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

            /* 内容区：撑满面板宽，高度随内容 */
            QSkinColumn {
                id: bodyHost

                fill: true
                gap:  Theme.space.md
            }

            /* 按钮区。平台顺序（Windows 主按钮在左）与危险按钮安全间距
             * 都交给 foundation 的 ButtonBar。
             *
             * ══════════════════════════════════════════════════════════════
             * M22.1：`fill: true` 是**必需**的，不是可选调优
             * ══════════════════════════════════════════════════════════════
             * ButtonBar 的 `align` 默认就是 "end"，但它的宽度默认等于自身
             * implicitWidth（按钮总宽）—— 于是 "end" 没有可推的空间，
             * 按钮停在**面板左内边距**上。
             *
             * 这个错从 M8 一直躺到 M22 才被发现，两个原因叠在一起：
             *   · smoke_m8 只断言了 `dlg.opened`，没有一条碰过按钮区；
             *   · `.cache/keep/` 里**从来没有过** dialog 的截图。
             *   （"属性值对 ≠ 界面画对"的第 7 次，这一次数的是**没量过**。）
             *
             * 抓出它的是 M22 的侦察诊断屏（`.cache/_shot_dlgfooter.qml`，
             * 同屏摆了 ButtonBar 在 Layout 里 / 给显式宽度 / 对话框 footer
             * 三种场景）。实测读数：面板 420、内边距 24，footer 两颗按钮
             * `b1.x=0 / b0.x=68` —— 贴着左边；而同屏的参照场景
             * （`fill: true` 放进 QSkinColumn）量到 `bar.w=400` 且按钮贴右沿。
             * 所以缺口只在**这里**，ButtonBar 那边一行都不用动。
             *
             * 顺带纠正本文件早先那句「Layout.fillWidth 与 width:implicitWidth
             * 绑定牵制」：ButtonBar 自己的文件头已经写明 fill 在 Layout 里
             * 是正常的（Windows / Qt 6.8.3 实测 width 被拉到 760），
             * 本次诊断屏是第二个独立证据。原先那句结论是错的。
             *
             * 另：ButtonBar 的 `stackWhenNarrow` 仍是默认 true ——
             * 内容区宽度（panelWidth − 2×xl）小于 320 时会转成纵向堆叠。
             * 默认面板宽 440/420 都远在这个阈值之上，不动它。 */
            ButtonBar {
                id: footerHost

                fill: true
            }
        }

        /* 开合动画：淡入 + 轻微放大。Dialog 从 0.96 起缩，
         * 比从 1.1 缩小的"反向弹出"更稳重（对齐 Ant/TD 的选择） */
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0;   to: 1;    duration: Theme.motion.normal; easing.type: Theme.motion.easing }
            NumberAnimation { property: "scale";   from: 0.96; to: 1;    duration: Theme.motion.normal; easing.type: Theme.motion.easing }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1;   to: 0;    duration: Theme.motion.fast;   easing.type: Theme.motion.easing }
            NumberAnimation { property: "scale";   from: 1;   to: 0.96; duration: Theme.motion.fast;   easing.type: Theme.motion.easing }
        }
    }
}
