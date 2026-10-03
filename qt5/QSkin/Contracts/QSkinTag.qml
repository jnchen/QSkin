/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinTag
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 标签 —— 用来给一段内容打标记："已上线"、"v2.1.0"、"高危"。
 *
 * ── 和 QSkinButton 的关系：形似而神不同 ──────────────────────────────────
 * 两者都是"一块带文字的圆角底板"，但语义完全相反：
 *   · 按钮是**可操作**的（clicked 是它的主信号）
 *   · 标签是**可读**的，关闭只是附属能力（closable 才有关闭按钮）
 * 所以 Tag 复用 buttonBackground 插槽的**形状语言**（圆角 + 填充），
 * 但走自己的尺寸与内边距，并且不继承按钮的 hover 位移等交互态。
 *
 * 具体复用方式：Tag 把 buttonBackground 的 control 契约完整满足
 * （variant / hovered / pressed / enabled / checked / text 全都有），
 * 但额外暴露 `tag: true` 与 `emphasis`，主题插槽可以据此分叉：
 *   TDButtonBackground 里会检查 control.tag —— 标签用更小的圆角、
 *   更浅的底色，而按钮仍是标准形态。这是「一个插槽服务两种控件」的
 *   鸭子类型用法，与 label 插槽服务的宿主最广是同一个思路。
 *
 * ── variant 语义（沿用按钮那一套，不另造词汇）──────────────────────────
 *   default  中性灰底
 *   primary  品牌色浅底（brandSubtle + brand 文字）
 *   success / warning / danger   对应语义色的浅底 + 深字
 *
 * 为什么用浅底而不是实心：标签在表格里会连续出现十几个，
 * 实心色块会让整张表变成色卡。三大设计系统的 Tag 默认都是浅底。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Shapes 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    property string text: ""

    /* ══════════════════════ 外观 ══════════════════════ */

    /** default | primary | success | warning | danger */
    property string variant: "default"

    /** sm | md */
    property string size: "md"

    /** 是否圆角全开（胶囊形）。TDesign 的 Tag 默认胶囊，Ant 默认小圆角 ——
     *  这里给个开关，默认跟随主题插槽的决定。 */
    property bool pill: false

    /* ══════════════════════ 行为 ══════════════════════ */

    /** 显示关闭按钮 */
    property bool closable: false

    property bool hovered: false
    property bool pressed: false

    signal clicked()
    signal closed()

    /* ══════════════════════ 状态（供插槽读取） ══════════════════════ */

    /** 供插槽做鸭子类型分叉：告诉主题"我是标签，不是按钮"。
     *  见文件头关于"一个插槽服务两种控件"的说明。 */
    readonly property bool tag: true

    /** 标签默认是浅底（subtle）还是实心（solid）。
     *  主题可以据此选色，默认浅底。 */
    property bool solid: false

    /** 供 label 插槽的 isButtonHost() 判断使用 —— 标签有图标位，
     *  所以它也报 iconSize。这与按钮同款，让 label 走按钮那条
     *  "实心才用 onBrand 白字"的分支逻辑。 */
    property int iconSize: Theme.size.iconSm

    /* ══════════════════════ 尺寸 ══════════════════════ */

    readonly property int controlHeight: root.size === "sm" ? 20 : Theme.size.controlSm

    /* 标签比按钮紧凑得多：字号小一档、内边距也小一档。
     * 这是设计语言无关的判断 —— 标签在视觉层级上就该比按钮轻。 */
    readonly property int contentPadding: root.size === "sm" ? Theme.space.sm
                                                                 : Theme.space.md

    readonly property int closeSize: root.size === "sm" ? 12 : 14

    /* 供 label 插槽读取 */
    readonly property int labelAlignment: Text.AlignLeft

    implicitWidth:  content.implicitWidth + root.contentPadding * 2
    implicitHeight: root.controlHeight

    width:  implicitWidth
    height: implicitHeight

    /* 有 clicked 监听时才可聚焦 —— 纯展示的标签不该进 Tab 顺序，
     * 否则一张表里十几个标签会把键盘导航彻底堵死。
     * 这是标签与按钮在无障碍上的关键分野。 */
    activeFocusOnTab: root.closable || root.clicked !== null

    /* ══════════════════════ 无障碍 ══════════════════════ */

    Accessible.role: Accessible.StaticText
    Accessible.name: root.text
    Accessible.description: root.closable ? qsTr("可移除标签") : qsTr("标签")

    /* ══════════════════════ 插槽 ══════════════════════ */

    Loader {
        id: bgLoader

        anchors.fill: parent
        sourceComponent: Slots.buttonBackground

        Binding {
            target: bgLoader.item
            property: "control"
            value: root
            when: bgLoader.item !== null
        }
    }

    QSkinRow {
        id: content

        anchors.verticalCenter: parent.verticalCenter
        x: root.contentPadding
        gap: Theme.space.xs
        align: "center"

        Loader {
            id: labelLoader
            sourceComponent: Slots.label

            Binding {
                target: labelLoader.item
                property: "control"
                value: root
                when: labelLoader.item !== null
            }
        }

        /* 关闭按钮：一个 × 形，用 Shape 画而不是打 "×" ——
         * 字体字形覆盖率问题（同 BasicCheckIndicator 的勾）。 */
        Item {
            id: closeBtn

            visible: root.closable
            width:  root.closeSize
            height: root.closeSize
            /* 纵向居中：这里**不写** anchors —— 本件是 QSkinRow 内层 RowLayout 的
             * 直接子项，在它身上挂 anchors 是 Qt 明说的 undefined behavior
             * （运行期报 `Detected anchors on an item that is managed by a layout`）。
             * 居中由 QSkinRow 的 `align: "center"` 经 `_applyAlign()` 统一施加
             * （它给每个子项写 `Layout.alignment: Qt.AlignVCenter`），
             * 所以这一行是**多余**的，删掉不动落点（改后实测见下方 M31 记录）。 */

            property bool hovered: false

            /* × 形：两条对角线 */
            Shape {
                // CurveRenderer 才有原生抗锯齿；默认的 GeometryRenderer 是硬边（见 README「图标锯齿」）
                anchors.centerIn: parent
                width:  closeBtn.width
                height: closeBtn.height
                opacity: closeBtn.hovered ? 1.0 : 0.65

                Behavior on opacity {
                    NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
                }

                ShapePath {
                    strokeWidth: 1.5
                    strokeColor: d.closeColor()
                    fillColor:   "transparent"
                    capStyle:    ShapePath.RoundCap

                    startX: closeBtn.width * 0.28
                    startY: closeBtn.height * 0.28
                    PathLine { x: closeBtn.width * 0.72; y: closeBtn.height * 0.72 }
                }
                ShapePath {
                    strokeWidth: 1.5
                    strokeColor: d.closeColor()
                    fillColor:   "transparent"
                    capStyle:    ShapePath.RoundCap

                    startX: closeBtn.width * 0.72
                    startY: closeBtn.height * 0.28
                    PathLine { x: closeBtn.width * 0.28; y: closeBtn.height * 0.72 }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: closeBtn.hovered = true
                onExited:  closeBtn.hovered = false
                onClicked: function(mouse) {
                    mouse.accepted = true      /* 不要穿透到底板的 MouseArea */
                    root.closed()
                }
            }
        }
    }

    FocusRing { control: root }

    /* ══════════════════════ 交互 ══════════════════════ */

    MouseArea {
        id: ma

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onEntered:  root.hovered = true
        onExited:   root.hovered = false
        onCanceled: root.pressed = false
        onReleased: root.pressed = false

        onPressed: function(mouse) {
            if (mouse.button !== Qt.LeftButton) return
            root.pressed = true
            if (root.activeFocusOnTab) root.forceActiveFocus()
        }
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) root._activate()
        }
    }

    Keys.onDeletePressed: if (root.closable) root.closed()
    Keys.onReturnPressed: root._activate()
    Keys.onEnterPressed:  root._activate()

    /* ══════════════════════ 内部 ══════════════════════ */

    function _activate() {
        if (!root.enabled) return
        root.clicked()
    }

    QtObject {
        id: d

        function closeColor() {
            var s = root.variant
            if (s === "primary" || s === "success" || s === "warning" || s === "danger") {
                /* 浅底标签的 × 用对应语义色，与文字同色系 */
                switch (s) {
                case "primary": return Theme.color.brand
                case "success": return Theme.color.success
                case "warning": return Theme.color.warning
                case "danger":  return Theme.color.danger
                }
            }
            return Theme.color.fgMuted
        }
    }
}
