/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinDrawer
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 抽屉（M8 反馈三件套之二）。
 *
 * ── 分工 ─────────────────────────────────────────────────────────────
 *   本文件：四边滑入（left / right / top / bottom）、开合状态机、
 *           Esc / 遮罩关闭、按边滑动的开合动画
 *   插槽：  无 —— 与 QSkinDialog 同一套令牌组合（scrim / bgElevated /
 *           border / radius），同一取舍（V1 无阴影）
 *
 * 用法：
 *     QSkinDrawer {
 *         id: settingsDrawer
 *         edge: "right"              // left | right | top | bottom
 *         panelWidth: 360            // 水平边用宽；垂直边用 panelHeight
 *         Heading { text: "设置" }
 *         // ... 内容
 *     }
 *     settingsDrawer.open()
 *
 * 设计取舍：抽屉面板贴边的两个角不做圆角（贴边直角、朝内圆角），
 * 视觉上"从墙里拉出来"。Ant / Arco 都是这个处理。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Controls 2.4
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 从哪条边滑入：left | right | top | bottom */
    property string edge: "right"

    /** 水平边的面板宽 */
    property int panelWidth:  360

    /** 垂直边的面板高 */
    property int panelHeight: 320

    /** 抽屉内部可选标题（与 Dialog 同款，label 插槽 header 变体） */
    property string title: ""

    /** 点遮罩是否关闭（Esc 永远可关） */
    property bool dismissOnScrim: true

    default property alias content: bodyHost.data

    readonly property alias opened: popup.visible
    /* opened 是 alias，QML 自动生成 openedChanged 通知 */

    function open()  { popup.open()  }
    function close() { popup.close() }

    /* ══════════════════════ 内部 ══════════════════════ */

    readonly property bool _horizontal: root.edge === "left" || root.edge === "right"
    readonly property int  _panelSpan:  root._horizontal ? root.panelWidth : root.panelHeight

    Popup {
        id: popup

        /* 挂到窗口 Overlay 层再贴边 —— root 本体在调用方布局里
         * 可能只有 0×0，贴 parent 会贴错边（同 QSkinDialog） */
        parent: Overlay.overlay

        /* 位置：四边贴边 + 全深/全宽
         *
         * ⚠ 每一条都带 `parent ?` 守卫，不是防御性写法，是必需的：
         * `parent` 绑的是 `Overlay.overlay`，而**构造期它还是 null**
         * （本件在窗口里的挂载顺序晚于属性求值）。少了守卫，
         * `parent.height` 会抛 `TypeError: Cannot read property 'height' of null`
         * —— smoke_m8 只声明不打开，这条错误就每次都在累积日志里出现。
         * 打开之后 parent 非空，读数与加守卫前逐字相同（M31 出图核过）。 */
        x:      root.edge === "left"   ? 0
              : root.edge === "right"  ? (parent ? parent.width  - width : 0)
              : 0
        y:      root.edge === "top"    ? 0
              : root.edge === "bottom" ? (parent ? parent.height - height : 0)
              : 0

        width:  root._horizontal ? root._panelSpan  : (parent ? parent.width  : 0)
        height: root._horizontal ? (parent ? parent.height : 0) : root._panelSpan

        padding: 0

        modal: true
        closePolicy: root.dismissOnScrim
                     ? Popup.CloseOnEscape | Popup.CloseOnPressOutside
                     : Popup.CloseOnEscape

        Overlay.modal: Rectangle {
            color:   Theme.color.scrim
            opacity: Theme.color.scrimOpacity
        }

        /* 面板：贴边全直角 —— 对齐 Ant Design Drawer 的处理
         * （抽屉从"墙里"拉出，四角直角最自然；TD 的朝内圆角留给
         * 未来的 dialogPanel 契约，不在契约层写死） */
        background: Rectangle {
            color:        Theme.color.bgElevated
            border.color: Theme.color.border
            border.width: 1
            radius:       0
        }

        contentItem: QSkinColumn {
            padding: Theme.space.xl
            gap:     Theme.space.lg

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

            QSkinColumn {
                id: bodyHost

                fill: true
                gap:  Theme.space.md
            }
        }

        /* 开合动画：沿边滑动。位移方向 = 抽屉藏起来的方向 */
        enter: Transition {
            NumberAnimation { property: root._horizontal ? "x" : "y"
                             ; from: root.edge === "left" || root.edge === "top"
                                     ? -root._panelSpan : root._panelSpan
                             ; to: popup.x
                             ; duration: Theme.motion.normal
                             ; easing.type: Theme.motion.easing }
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
        exit: Transition {
            NumberAnimation { property: root._horizontal ? "x" : "y"
                             ; from: popup.x
                             ; to: root.edge === "left" || root.edge === "top"
                                     ? -root._panelSpan : root._panelSpan
                             ; duration: Theme.motion.fast
                             ; easing.type: Theme.motion.easing }
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }
}
