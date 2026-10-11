/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinSteps
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 步骤条 —— 把一个多步流程的"走到哪了"画出来。
 *
 * ── 状态机是本控件的全部 ──────────────────────────────────────────────
 *
 * 每个步骤的状态由 currentIndex 与它自己的下标比较得出，**不由数据传入**：
 *
 *     idx <  currentIndex  →  "finish"   已完成（打勾）
 *     idx === currentIndex →  "process"  进行中（高亮 + 可转圈）
 *     idx >  currentIndex  →  "wait"     未开始（弱化）
 *
 * 为什么不让业务自己传 status：那样每一步都要业务判断一次，十个页面
 * 就写错十个。让下标推导状态，业务只需要维护一个 currentIndex ——
 * 这是"逻辑属于契约层"的典型例子。status 属性可以覆盖单步（比如
 * 某步失败了要单独标红），但默认永远是从下标推导。
 *
 * ── variant 两种方向 ──────────────────────────────────────────────────
 *   horizontal  横向（默认）。步骤横向铺开，下方标题。
 *   vertical    纵向。左侧竖线串联，右侧标题 + 描述。用在窄容器里。
 *
 * ── 插槽分工（M10 里最省的一个）────────────────────────────────────────
 *   圆圈 / 打勾 / 连接线   → Slots.stepIndicator（indicator 家族）
 *   标题文字               → Slots.label（复用！）
 *   描述文字               → Slots.label（复用！描述走 muted 色）
 *
 * label 插槽一个顶两个：标题与描述只差"前景强弱"，用 variant 就能分叉
 * （title 用 "text"，desc 用 "muted"）—— 不需要两个插槽。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 字符串数组（只显示标题），或对象数组。
     *  对象支持的字段：title / description / status（可选，覆盖推导值） */
    property var model: null

    /** 当前进行到第几步（0 基）。
     *  等于 count 时表示"全部完成" —— 最后一步也变成 finish。
     *  这比"把最后一步设成 process 再靠外部标记完成"干净。 */
    property int currentIndex: 0

    property string titleRole: "title"
    property string descRole:  "description"

    /* ══════════════════════ 外观 ══════════════════════ */

    /** horizontal | vertical */
    property string variant: "horizontal"

    /** 是否在"进行中"的步骤上显示转圈动画 */
    property bool animated: true

    /** 横向时每步的最小宽度（标题长时不会挤在一起） */
    property int stepMinWidth: 120

    /** 纵向时描述文字的最大宽度（防止一行太长） */
    property int descMaxWidth: 400

    readonly property int count: _countOf()

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 用户点击了某一步 */
    signal activated(int index)

    /** 某一步的推导状态 —— 供外部只读查询与测试断言 */
    function statusOf(i) {
        /* 单步覆盖优先 */
        var ov = _statusOverride(i)
        if (ov !== "") return ov

        if (i < root.currentIndex) return "finish"
        if (i === root.currentIndex) return "process"
        return "wait"
    }

    function titleOf(i)      { return _fieldOf(i, root.titleRole, true) }
    function descriptionOf(i){ return _fieldOf(i, root.descRole, false) }

    /* ══════════════════════ 尺寸 ══════════════════════ */

    implicitWidth:  root.variant === "vertical" ? _vWidth() : _hWidth()
    implicitHeight: root.variant === "vertical" ? _vHeight() : _hHeight()

    width:  implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("步骤 %1 / %2").arg(Math.min(root.currentIndex + 1, root.count)).arg(root.count)

    /* ══════════════════════ 排布 ══════════════════════ */

    /* 纵向：一个 QSkinColumn 装所有步骤项（每个步骤项内含指示器 + 文字） */
    QSkinColumn {
        id: vBox

        visible: root.variant === "vertical"
        anchors.left: parent.left
        anchors.top:  parent.top
        gap: Theme.space.lg
        padding: 0
        align: "start"

        Repeater {
            model: root.variant === "vertical" ? root.count : 0
            delegate: vStepComp
        }
    }

    /* 横向：一个 QSkinRow 装所有步骤项（步骤项内部再横排 圆+线+文字） */
    QSkinRow {
        id: hBox

        visible: root.variant !== "vertical"
        anchors.left: parent.left
        anchors.top:  parent.top
        gap: 0
        padding: 0
        align: "start"

        Repeater {
            model: root.variant === "vertical" ? 0 : root.count
            delegate: hStepComp
        }
    }

    // qmllint disable unqualified

    /* ── 纵向步骤项 ── */
    Component {
        id: vStepComp

        Item {
            id: vStep

            property int index

            width:  root._vWidth()
            height: vInner.implicitHeight

            readonly property string st: root.statusOf(vStep.index)

            QSkinRow {
                id: vInner

                anchors.left: parent.left
                anchors.top:  parent.top
                gap: Theme.space.md
                padding: 0
                align: "start"

                /* 指示器区：竖线 + 圆 */
                QSkinColumn {
                    id: vRail

                    gap: 0
                    padding: 0
                    align: "center"
                    width: 24

                    Loader {
                        id: vDotLoader

                        sourceComponent: Slots.stepIndicator

                        Binding {
                            target: vDotLoader.item
                            property: "control"
                            value: vStep
                            when: vDotLoader.item !== null
                        }
                    }

                    /* 连接线（最后一步不画） */
                    Rectangle {
                        width:  2
                        height: Math.max(0, vStep.height - 24 - Theme.space.xs)
                        color: vStep.st === "finish" ? Theme.color.brand
                                                     : Theme.color.border
                        visible: vStep.index < root.count - 1

                        Behavior on color {
                            ColorAnimation { duration: Theme.motion.normal; easing.type: Theme.motion.easing }
                        }
                    }
                }

                /* 文字区 */
                QSkinColumn {
                    gap: Theme.space.xxs
                    padding: 0
                    align: "start"

                    /* 纵向时指示器宽 24 + gap 12，文字区从 36 起 */
                    Loader {
                        id: vTitleLoader
                        sourceComponent: Slots.label

                        Binding {
                            target: vTitleLoader.item
                            property: "control"
                            value: vStep.titleHost
                            when: vTitleLoader.item !== null
                        }
                    }

                    Loader {
                        id: vDescLoader
                        sourceComponent: Slots.label
                        visible: vStep.hasDescription

                        Binding {
                            target: vDescLoader.item
                            property: "control"
                            value: vStep.descriptionHost
                            when: vDescLoader.item !== null
                        }
                    }
                }
            }

            /* ── 宿主契约对象：给 label / stepIndicator 插槽读 ──
             * 不直接把 vStep 交给插槽，因为它没有 text / variant 这些
             * label 需要的属性；包一层更干净。 */
            readonly property QtObject titleHost: QtObject {
                readonly property string text: root.titleOf(vStep.index)
                readonly property string variant: vStep.st === "wait" ? "muted" : "text"
                readonly property bool   active: vStep.st === "process"
                readonly property bool   done:   vStep.st === "finish"
                readonly property string status: vStep.st
                readonly property string variant2: ""
                readonly property int    labelAlignment: Text.AlignLeft
            }

            readonly property QtObject descriptionHost: QtObject {
                readonly property string text: root.descriptionOf(vStep.index)
                readonly property string variant: "muted"
                readonly property bool   active: vStep.st === "process"
                readonly property bool   done:   vStep.st === "finish"
                readonly property string status: vStep.st
                readonly property int    labelAlignment: Text.AlignLeft
            }

            /* 给 stepIndicator 插槽读的宿主身份 */
            readonly property string text:  root.titleOf(vStep.index)
            readonly property string status: vStep.st
            readonly property bool   first: vStep.index === 0
            readonly property bool   last:  vStep.index === root.count - 1
            readonly property bool   active: vStep.st === "process"
            readonly property bool   done:   vStep.st === "finish"
            readonly property int    stepSize: 24

            /* 是否有描述文字 —— 直接算成 bool 暴露，避免外层去读
             * descriptionHost.text（跨 QtObject 的成员访问会被 qmllint
             * 按 QObject 检查并误报 Member not found）。 */
            readonly property bool hasDescription:
                root.descriptionOf(vStep.index) !== ""

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.activated(vStep.index)
            }
        }
    }

    /* ── 横向步骤项 ── */
    Component {
        id: hStepComp

        Item {
            id: hStep

            property int index

            /* 横向：每步等宽，最后一步不需要连接线所以略窄 */
            width:  Math.max(root.stepMinWidth,
                             root.implicitWidth / Math.max(1, root.count))
            height: hInner.implicitHeight

            readonly property string st: root.statusOf(hStep.index)

            QSkinColumn {
                id: hInner

                anchors.left: parent.left
                anchors.top:  parent.top
                gap: Theme.space.sm
                padding: 0
                align: "start"

                /* 指示器行：圆 + 右侧连接线（撑满剩余宽度） */
                QSkinRow {
                    id: hDotRow

                    gap: Theme.space.sm
                    padding: 0
                    align: "center"

                    Loader {
                        id: hDotLoader

                        sourceComponent: Slots.stepIndicator

                        Binding {
                            target: hDotLoader.item
                            property: "control"
                            value: hStep
                            when: hDotLoader.item !== null
                        }
                    }

                    /* 连接线：从当前圆右侧一直到本步宽度末尾 */
                    Rectangle {
                        width: Math.max(0, hStep.width - hStep.stepSize
                                          - Theme.space.sm)
                        height: 2
                        color: hStep.st === "finish" ? Theme.color.brand
                                                     : Theme.color.border
                        visible: hStep.index < root.count - 1

                        Behavior on color {
                            ColorAnimation { duration: Theme.motion.normal; easing.type: Theme.motion.easing }
                        }
                    }
                }

                /* 标题 */
                Loader {
                    id: hTitleLoader
                    sourceComponent: Slots.label

                    Binding {
                        target: hTitleLoader.item
                        property: "control"
                        value: hStep.titleHost
                        when: hTitleLoader.item !== null
                    }
                }

                /* 描述（可选） */
                Loader {
                    id: hDescLoader
                    sourceComponent: Slots.label
                    visible: hStep.hasDescription

                    Binding {
                        target: hDescLoader.item
                        property: "control"
                        value: hStep.descriptionHost
                        when: hDescLoader.item !== null
                    }
                }
            }

            readonly property QtObject titleHost: QtObject {
                readonly property string text: root.titleOf(hStep.index)
                readonly property string variant: hStep.st === "wait" ? "muted" : "text"
                readonly property bool   active: hStep.st === "process"
                readonly property bool   done:   hStep.st === "finish"
                readonly property string status: hStep.st
                readonly property int    labelAlignment: Text.AlignLeft
            }

            readonly property QtObject descriptionHost: QtObject {
                readonly property string text: root.descriptionOf(hStep.index)
                readonly property string variant: "muted"
                readonly property bool   active: hStep.st === "process"
                readonly property bool   done:   hStep.st === "finish"
                readonly property string status: hStep.st
                readonly property int    labelAlignment: Text.AlignLeft
            }

            readonly property string text:  root.titleOf(hStep.index)
            readonly property string status: hStep.st
            readonly property bool   first: hStep.index === 0
            readonly property bool   last:  hStep.index === root.count - 1
            readonly property bool   active: hStep.st === "process"
            readonly property bool   done:   hStep.st === "finish"
            readonly property int    stepSize: 24

            readonly property bool hasDescription:
                root.descriptionOf(hStep.index) !== ""

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.activated(hStep.index)
            }
        }
    }

    // qmllint enable unqualified

    /* ══════════════════════ 内部 ══════════════════════ */

    function _countOf() {
        var m = root.model
        if (m === null || m === undefined) return 0
        if (typeof m === "number") return m
        if (typeof m.get === "function") return m.count
        return m.length
    }

    function _itemAt(i) {
        var m = root.model
        if (m === null || m === undefined) return null
        if (typeof m === "number") return null
        return (typeof m.get === "function") ? m.get(i) : m[i]
    }

    /** 取一个字段。onlyTitle 时，字符串模型的每一项本身就是标题。 */
    function _fieldOf(i, role, isTitle) {
        var m = root.model
        if (m === null || m === undefined) return ""

        if (typeof m === "number") {
            return isTitle ? qsTr("步骤 %1").arg(i + 1) : ""
        }

        var it = _itemAt(i)
        if (it === null || it === undefined) return ""

        if (typeof it === "object") {
            var v = it[role]
            if (v === undefined || v === null) return ""
            return String(v)
        }

        /* 裸字符串数组：只有标题有值 */
        return isTitle ? String(it) : ""
    }

    function _statusOverride(i) {
        var it = _itemAt(i)
        if (it === null || it === undefined) return ""
        if (typeof it !== "object") return ""
        var s = it.status
        if (s === undefined || s === null) return ""
        return String(s)
    }

    /* ── 尺寸计算 ──
     * 这两个函数里刻意不读 Loader.item 的尺寸：Loader 是异步的，
     * 在 implicitWidth 求值时 item 可能还是 null，会把整个控件
     * 算成 0 宽（M9.x 那个 bug 的同族陷阱）。所以用令牌估一个稳定的
     * 尺寸，再让 stepMinWidth 兜底 —— 宁可估，不要不收敛。 */

    function _hWidth() {
        return Math.max(1, root.count) * root.stepMinWidth
    }

    function _hHeight() {
        /* 圆(24) + gap(8) + 标题行 + 可能的描述行(2 行) */
        var h = 24 + Theme.space.sm + Theme.font.sm * 1.5 + Theme.space.xxs
        for (var i = 0; i < root.count; ++i) {
            if (root.descriptionOf(i) !== "") {
                h += Theme.font.sm * 1.5
                break
            }
        }
        return h
    }

    function _vWidth() {
        return root.stepMinWidth + root.descMaxWidth
    }

    function _vHeight() {
        return Math.max(1, root.count) * 48
    }
}
