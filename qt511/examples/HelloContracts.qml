/****************************************************************************
 * QSkin · Quick Design System — M1 契约层演示
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 这一个文件要证明的事：
 *
 *     **换肤 = 换插槽，控件代码一行不动。**
 *
 * 页面上有一排按钮。点右上角的「切成 Sharp 皮肤」，所有按钮会立刻变成
 * 方角、黑底、粗描边的样子 —— 而它们的点击、键盘、禁用、无障碍语义
 * 完全没变，因为那些东西住在 QSkinButton.qml 里，不在插槽里。
 *
 * 建议这样体验：
 *   1. 用 Tab 键在一排按钮间走一遍 —— 焦点环只在键盘导航时出现
 *   2. 按 Space / Enter 触发按钮 —— 和鼠标点击走同一条路径
 *   3. 点「切成 Sharp 皮肤」，再 Tab 一遍 —— 交互一模一样，只是皮换了
 ****************************************************************************/

import QtQuick 2.11
import QtQml.Models 2.11        // ListModel：下拉框的第二种数据源示例
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

/* 这里用 QSkinColumn / QSkinRow 而不是 Column / Row：
 * 本文件同时 import 了 QtQuick 与 QSkin.Foundation，裸写 Row 会和
 * QtQuick.Row 撞名（Foundation 内部则不会，模块内本地类型优先）。
 * foundation/qmldir 里注册了带前缀的别名，跨模块统一用它最省心。 */

QSkinWindow {
    id: win

    width:  980
    height: 780
    title:  "QSkin Contracts · M1 — 一套逻辑，多种皮肤"

    /* ══════════════════════════════════════════════════════════════════
     *  另一套皮肤的全部内容，就下面两个 Component
     * ══════════════════════════════════════════════════════════════════
     * 注意它们只读 control 的状态（pressed / hovered / variant / enabled），
     * 从不修改 —— 这是 Slots.qml 里的契约第二条。 */

    Component {
        id: sharpBackground

        Rectangle {
            property var control: null

            anchors.fill: parent
            radius: 0                       // 方角

            border.width: 2
            border.color: "#111111"

            color: {
                if (!control) return "#FFFFFF"
                if (control.pressed) return "#333333"
                if (control.hovered) return "#111111"
                if (control.variant === "primary") return "#000000"
                if (control.variant === "danger")  return "#7F1D1D"
                return "#FFFFFF"
            }
        }
    }

    Component {
        id: sharpLabel

        Text {
            property var control: null

            text: control ? control.text : ""

            /* 方角风格配全大写 + 字距，是另一套排版口味 */
            font.family:    Theme.font.family
            font.pixelSize: Theme.font.sm
            font.weight:    Font.DemiBold
            font.letterSpacing: 1.2
            font.capitalization: Font.AllUppercase

            color: {
                if (!control) return Theme.color.fg
                if (control.enabled === false) return Theme.color.fgDisabled
                if (control.pressed || control.hovered) return "#FFFFFF"
                if (control.variant === "primary" || control.variant === "danger")
                    return "#FFFFFF"
                return Theme.color.fg
            }

            elide:               Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment:   Text.AlignVCenter
        }
    }

    /* ══════════════════════════ 页面 ══════════════════════════ */

    Flickable {
        anchors.fill: parent
        contentWidth:  width
        contentHeight: page.implicitHeight + 48
        clip: true

        QSkinColumn {
            id: page

            x: 24
            y: 24
            width: win.width - 48
            gap: 24
            align: "start"

            /* ───────────── 头部 ───────────── */

            QSkinRow {
                fill: true
                gap: Theme.space.md
                align: "center"

                QSkinColumn {
                    gap: Theme.space.xxs
                    align: "start"

                    Heading { level: 2; text: "QSkin Contracts · M1" }
                    Caption { text: "五个插槽 + 四个控件。Tab 键走一遍，再点右边换肤。" }
                }

                Spacer { }

                QSkinButton {
                    id: skinButton

                    property bool sharp: false

                    text: sharp ? "切回 Basic 皮肤" : "切成 Sharp 皮肤"
                    variant: "primary"

                    onClicked: {
                        sharp = !sharp
                        if (sharp) {
                            Slots.install({
                                buttonBackground: sharpBackground,
                                label:            sharpLabel
                            })
                        } else {
                            Slots.reset()
                        }
                    }
                }

                QSkinButton {
                    text: Theme.mode === "dark" ? "浅色" : "深色"
                    onClicked: Theme.mode = (Theme.mode === "dark" ? "light" : "dark")
                }
            }

            Rectangle { width: page.width; height: 1; color: Theme.color.border }

            /* ───────────── 按钮 · 五种 variant ───────────── */

            QSkinColumn {
                fill: true
                gap: Theme.space.sm
                align: "start"

                Heading { level: 3; text: "按钮 · variant" }
                Caption { text: "控件只声明「我是主按钮」，长什么样由插槽决定。" }

                QSkinRow {
                    gap: Theme.space.sm

                    QSkinButton { text: "默认";   variant: "default"; onClicked: demo.clicks++ }
                    QSkinButton { text: "主要";   variant: "primary"; onClicked: demo.clicks++ }
                    QSkinButton { text: "危险";   variant: "danger";  onClicked: demo.clicks++ }
                    QSkinButton { text: "幽灵";   variant: "ghost";   onClicked: demo.clicks++ }
                    QSkinButton { text: "文字";   variant: "text";    onClicked: demo.clicks++ }
                }
            }

            /* ───────────── 按钮 · 三种尺寸 ───────────── */

            QSkinColumn {
                fill: true
                gap: Theme.space.sm
                align: "start"

                Heading { level: 3; text: "按钮 · size" }
                Caption { text: "尺寸属于逻辑不在皮肤里 —— 主题只能改 controlSm/Md/Lg 的值。" }

                QSkinRow {
                    gap: Theme.space.sm
                    align: "center"

                    QSkinButton { text: "小"; size: "sm"; onClicked: demo.clicks++ }
                    QSkinButton { text: "中"; size: "md"; onClicked: demo.clicks++ }
                    QSkinButton { text: "大"; size: "lg"; onClicked: demo.clicks++ }
                }
            }

            /* ───────────── 按钮 · 状态 ───────────── */

            QSkinColumn {
                fill: true
                gap: Theme.space.sm
                align: "start"

                Heading { level: 3; text: "按钮 · 状态" }
                Caption { text: "禁用、可选中、带图标。禁用态由插槽用令牌表达。" }

                QSkinRow {
                    gap: Theme.space.sm
                    align: "center"

                    QSkinButton { text: "已禁用"; enabled: false }
                    QSkinButton { id: toggleBtn; text: "可切换"; checkable: true }
                    QSkinButton { text: "带图标"; iconSource: "qrc:/qt-project.org/imports/QtQuick/Controls/Basic/images/check.png" }
                }

                Caption {
                    text: "可切换按钮当前状态：" + (toggleBtn.checked ? "已选中" : "未选中")
                }
            }

            /* ───────────── 输入框 ───────────── */

            QSkinColumn {
                fill: true
                gap: Theme.space.sm
                align: "start"

                Heading { level: 3; text: "输入框" }
                Caption { text: "常态下沉、聚焦提亮。校验失败时红色优先于焦点。" }

                QSkinRow {
                    gap: Theme.space.sm
                    align: "center"

                    QSkinInput {
                        id: nameInput
                        width: 220
                        placeholderText: "请输入名称"
                    }
                    QSkinInput { width: 220; text: "只读示例"; enabled: false }
                    QSkinInput { width: 220; placeholderText: "邮箱格式不对"; error: true }
                }

                Caption { text: "你输入了：" + (nameInput.text === "" ? "（空）" : nameInput.text) }
            }

            /* ───────────── 复选框 ───────────── */

            QSkinColumn {
                fill: true
                gap: Theme.space.sm
                align: "start"

                Heading { level: 3; text: "复选框" }
                Caption { text: "半选（indeterminate）点击后变全选 —— 树形控件的通用约定。" }

                QSkinRow {
                    gap: Theme.space.lg

                    QSkinCheckBox { text: "未选中"; checked: false }
                    QSkinCheckBox { text: "已选中"; checked: true }
                    QSkinCheckBox { text: "半选";   indeterminate: true }
                    QSkinCheckBox { text: "禁用";   enabled: false }
                }
            }

            /* ───────────── 开关 ───────────── */

            QSkinColumn {
                fill: true
                gap: Theme.space.sm
                align: "start"

                Heading { level: 3; text: "开关" }
                Caption { text: "与复选框共用状态，语义不同，所以是独立插槽。" }

                QSkinRow {
                    gap: Theme.space.lg

                    QSkinSwitch { text: "关"; checked: false }
                    QSkinSwitch { text: "开"; checked: true }
                    QSkinSwitch { text: "禁用"; enabled: false; checked: true }
                }
            }

            /* ───────────── 下拉选择 ───────────── */

            QSkinColumn {
                fill: true
                gap: Theme.space.sm
                align: "start"

                Heading { level: 3; text: "下拉选择" }
                Caption {
                    text: "面板外壳来自 selectOverlay 插槽，列表与键盘导航留在控件里 —— "
                          + "换肤换的是外壳，行为一行没动。↑↓ 移动，Enter 选中，Esc 取消。"
                }

                QSkinRow {
                    gap: Theme.space.lg

                    /* 字符串数组 */
                    QSkinSelect {
                        id: colorSelect

                        width: 200
                        model: ["红色", "绿色", "蓝色", "黄色", "紫色"]
                        currentIndex: 0
                        placeholderText: "请选择颜色"

                        onActivated: function(index) {
                            demo.clicks++
                            demo.lastPick = colorSelect.text
                        }
                    }

                    /* ListModel + textRole：八个选项，面板滚到 maxVisibleRows 为止 */
                    QSkinSelect {
                        width: 200
                        textRole: "label"
                        currentIndex: 0

                        model: ListModel {
                            ListElement { label: "TDesign";    value: "tdesign" }
                            ListElement { label: "Ant Design"; value: "ant" }
                            ListElement { label: "Arco";       value: "arco" }
                            ListElement { label: "shadcn/ui";  value: "shadcn" }
                            ListElement { label: "Material";   value: "material" }
                            ListElement { label: "Fluent 2";   value: "fluent" }
                            ListElement { label: "Carbon";     value: "carbon" }
                            ListElement { label: "Chakra";     value: "chakra" }
                        }
                    }

                    QSkinSelect {
                        width: 200
                        enabled: false
                        placeholderText: "禁用状态"
                    }
                }

                Caption { text: "最近一次选择：" + (demo.lastPick !== "" ? demo.lastPick : "（还没有）") }
            }

            /* ───────────── 悬浮提示 ───────────── */

            QSkinColumn {
                fill: true
                gap: Theme.space.sm
                align: "start"

                Heading { level: 3; text: "悬浮提示" }
                Caption { text: "悬停 0.4 秒后出现；气泡本体来自 tooltipOverlay 插槽，换主题会跟着变。" }

                QSkinRow {
                    gap: Theme.space.lg

                    QSkinButton { id: tipTargetA; text: "悬停看提示" }
                    QSkinButton { id: tipTargetB; text: "这个也有"; variant: "primary" }
                }

                QSkinTooltip {
                    text: "Basic 气泡：底色取 Theme.color.fg、文字取 Theme.color.bg，"
                          + "于是明暗切换时自动反转，不需要专用令牌。"
                    target: tipTargetA
                    delay: 400
                }
                QSkinTooltip {
                    text: "靠窗口底部时会自动翻到上方，不会弹出可视区。"
                    target: tipTargetB
                    delay: 400
                }
            }

            /* ───────────── 底部 ───────────── */

            Rectangle { width: page.width; height: 1; color: Theme.color.border }

            Caption {
                text: "点击次数：" + demo.clicks
                      + "　·　Tab / Shift+Tab 导航，Space / Enter 激活"
                      + "　·　当前主题：" + Theme.themeName
            }
        }
    }

    /* 一个纯粹用来存计数的小对象，避免把状态挂在窗口上 */
    QtObject {
        id: demo
        property int clicks: 0
        property string lastPick: ""
    }
}
