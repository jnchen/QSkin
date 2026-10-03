/****************************************************************************
 * QSkin · Quick Design System — M3 主题矩阵演示：四套设计语言，一个页面
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 这是 M3 反向验证的可见成果：
 *
 *     Neutral / TDesign / Ant Design / Arco Design / shadcn ——
 *     五种外观，页面上所有控件都是 M1 那六个，源码零改动。
 *
 * 各家签名在同一个页面里直接对比：
 *   TDesign   3px 圆角、默认按钮 hover 描边变蓝、灰页面 #EEEEEE
 *   Ant       6px 圆角、下拉面板无描边、控件 24/32/40
 *   Arco      4px 圆角、灰底输入框聚焦变白、默认按钮是灰色实心、28/32/36
 *   shadcn    近黑主按钮、按钮文字 500 字重、聚焦环带 offset、36 基准高
 *
 * 建议这样体验：
 *   1. 依次点右上角五个主题按钮 —— 整页同帧换肤。
 *   2. 每次换肤后把鼠标放到「默认按钮」上 —— 四家表达各不相同。
 *   3. 点一下输入框 —— Arco 变白、Ant/TD 出光晕、shadcn 出带间隙的环。
 *   4. 「深色」按钮只动令牌 —— 任何主题下都可用。
 ****************************************************************************/

import QtQuick 2.15
import QtQml.Models 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0
import QSkin.Theme.AntDesign 1.0
import QSkin.Theme.ArcoDesign 1.0
import QSkin.Theme.Shadcn 1.0

QSkinWindow {
    id: win

    visible: true
    width:   980
    height:  880
    title:   "QSkin · 主题矩阵 — M3"

    /* 当前主题。"neutral" 表示地基出厂状态。 */
    property string current: "neutral"

    function applyTheme(name) {
        if (name === "neutral") { Slots.reset(); Theme.reset() }
        else if (name === "tdesign")   TDesign.apply()
        else if (name === "ant")       AntDesign.apply()
        else if (name === "arco")      ArcoDesign.apply()
        else if (name === "shadcn")    Shadcn.apply()
        win.current = name
    }

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

            /* ═══════════════ 头部 + 主题切换 ═══════════════ */

            QSkinRow {
                fill: true
                gap: Theme.space.md
                align: "center"

                QSkinColumn {
                    gap: Theme.space.xxs
                    align: "start"

                    Heading { level: 2; text: "QSkin 主题矩阵" }
                    Caption {
                        text: "当前主题：" + Theme.themeName
                              + "  ·  按钮 " + Theme.size.controlMd + "px"
                              + "  ·  圆角 " + Theme.radius.md + "px"
                    }
                }

                Spacer { }

                QSkinButton {
                    text:    "Neutral"
                    variant: win.current === "neutral" ? "primary" : "default"
                    onClicked: function() { win.applyTheme("neutral") }
                }
                QSkinButton {
                    text:    "TDesign"
                    variant: win.current === "tdesign" ? "primary" : "default"
                    onClicked: function() { win.applyTheme("tdesign") }
                }
                QSkinButton {
                    text:    "Ant"
                    variant: win.current === "ant" ? "primary" : "default"
                    onClicked: function() { win.applyTheme("ant") }
                }
                QSkinButton {
                    text:    "Arco"
                    variant: win.current === "arco" ? "primary" : "default"
                    onClicked: function() { win.applyTheme("arco") }
                }
                QSkinButton {
                    text:    "shadcn"
                    variant: win.current === "shadcn" ? "primary" : "default"
                    onClicked: function() { win.applyTheme("shadcn") }
                }
                QSkinButton {
                    text: Theme.mode === "dark" ? "浅色" : "深色"
                    onClicked: function() {
                        Theme.mode = (Theme.mode === "dark") ? "light" : "dark"
                    }
                }
            }

            Rectangle { width: page.width; height: 1; color: Theme.color.border }

            /* ═══════════════ 按钮 ═══════════════ */

            QSkinColumn {
                gap: Theme.space.sm
                align: "start"

                Heading { level: 4; text: "按钮变体" }
                Caption { text: "注意「默认」按钮 —— 四个主题对它的回答各不相同。" }

                QSkinRow {
                    gap: Theme.space.md
                    QSkinButton { text: "默认" }
                    QSkinButton { text: "主要"; variant: "primary" }
                    QSkinButton { text: "危险"; variant: "danger" }
                    QSkinButton { text: "描边"; variant: "ghost" }
                    QSkinButton { text: "文字"; variant: "text" }
                    QSkinButton { text: "禁用"; enabled: false }
                }

                QSkinRow {
                    gap: Theme.space.md
                    align: "center"
                    Caption { text: "尺寸" }
                    QSkinButton { text: "小"; size: "sm" }
                    QSkinButton { text: "中" }
                    QSkinButton { text: "大"; size: "lg" }
                    QSkinButton { text: "小·主要"; size: "sm"; variant: "primary" }
                    QSkinButton { text: "大·主要"; size: "lg"; variant: "primary" }
                }
            }

            Rectangle { width: page.width; height: 1; color: Theme.color.border }

            /* ═══════════════ 输入 ═══════════════ */

            QSkinColumn {
                gap: Theme.space.sm
                align: "start"

                Heading { level: 4; text: "输入框" }
                Caption { text: "Arco 灰底聚焦变白；Ant/TD 白底描边发光；shadcn 纯描边 + 带间隙的环。" }

                QSkinRow {
                    gap: Theme.space.md
                    QSkinInput  { width: 200; placeholderText: "请输入" }
                    QSkinInput  { width: 200; placeholderText: "邮箱格式不对"; error: true }
                    QSkinInput  { width: 200; placeholderText: "禁用"; enabled: false }
                }
            }

            /* ═══════════════ 选择 ═══════════════ */

            QSkinColumn {
                gap: Theme.space.sm
                align: "start"

                Heading { level: 4; text: "复选框 / 开关 / 下拉" }

                QSkinRow {
                    gap: Theme.space.xl
                    align: "center"

                    QSkinCheckBox { text: "未选中" }
                    QSkinCheckBox { text: "已选中"; checked: true }
                    QSkinCheckBox { text: "半选"; checked: true; indeterminate: true }
                    QSkinCheckBox { text: "禁用"; enabled: false }

                    QSkinSwitch { }
                    QSkinSwitch { checked: true }

                    QSkinSelect {
                        width: 180
                        placeholderText: "请选择"
                        model: ListModel {
                            ListElement { label: "设计" }
                            ListElement { label: "研发" }
                            ListElement { label: "产品" }
                        }
                    }
                }
            }

            Rectangle { width: page.width; height: 1; color: Theme.color.border }

            Caption {
                text: "令牌来源：TDesign / Ant Design v5 / Arco Design 官方 Design Token 文档、shadcn/ui themes.json（zinc）。"
            }
        }
    }
}
