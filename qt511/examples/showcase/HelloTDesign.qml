/****************************************************************************
 * QSkin · Quick Design System — M2 主题层演示：TDesign for Qt Quick
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 这一个文件要证明的事：
 *
 *     **一套真实的设计语言 = 一份令牌 + 五个插槽，控件代码零改动。**
 *
 * 页面上的按钮、输入框、复选框、下拉框，全部是 M1 写的那几个 QSkinButton /
 * QSkinInput / QSkinCheckBox / QSkinSwitch / QSkinSelect。TDesign 主题没有碰过
 * 它们任何一行源码，只做了两件事：
 *
 *     Theme.install(...)   —— 交一份令牌
 *     Slots.install({...}) —— 交五个插槽
 *
 * 建议这样体验：
 *   1. 把鼠标移到「默认按钮」上 —— 底色不动，只有描边和文字变蓝。
 *      这是 TDesign 的招牌动作，也是 Basic 主题做不出来的地方。
 *   2. 点输入框 —— 出现 2px 的浅蓝外发光（--td-brand-color-focus）。
 *   3. 点右上角「切回 Neutral」—— 整页在同一帧内换回中性主题。
 *   4. 点「深色」—— 只动令牌，不动任何控件代码。
 *   5. 全程用 Tab 键走一遍 —— 焦点、键盘触发、无障碍语义完全没变，
 *      因为那些东西住在契约层，不在主题层。
 ****************************************************************************/

import QtQuick 2.11
import QtQml.Models 2.11
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0

QSkinWindow {
    id: win

    visible: true
    width:   980
    height:  880
    title:   "QSkin · TDesign for Qt Quick — M2"

    property bool tdOn: true

    /* 主题装载就这一行。放在 onCompleted 而不是直接写在属性初始化里，
     * 是为了让窗口先按地基令牌画出来 —— 这样"换肤"是个可见的动作，
     * 而不是一上来就已经是 TDesign 了。 */
    Component.onCompleted: function() { TDesign.apply() }

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

            /* ═══════════════ 头部 ═══════════════ */

            QSkinRow {
                fill: true
                gap: Theme.space.md
                align: "center"

                QSkinColumn {
                    gap: Theme.space.xxs
                    align: "start"

                    Heading { level: 2; text: "TDesign for Qt Quick" }
                    Caption {
                        text: "当前主题：" + Theme.themeName
                              + "  ·  令牌 " + Theme.radius.md + "px 圆角"
                              + "  ·  插槽覆盖 5 / 8"
                    }
                }

                Spacer { }

                QSkinButton {
                    text: Theme.mode === "dark" ? "浅色" : "深色"
                    onClicked: function() {
                        Theme.mode = (Theme.mode === "dark") ? "light" : "dark"
                    }
                }

                QSkinButton {
                    variant: win.tdOn ? "default" : "primary"
                    text:    win.tdOn ? "切回 Neutral" : "换上 TDesign"
                    onClicked: function() {
                        if (win.tdOn) { TDesign.remove(); win.tdOn = false }
                        else          { TDesign.apply();  win.tdOn = true  }
                    }
                }
            }

            Rectangle { width: page.width; height: 1; color: Theme.color.border }

            /* ═══════════════ 按钮变体 ═══════════════ */

            QSkinColumn {
                fill: true
                gap: Theme.space.xs
                align: "start"

                Heading { level: 3; text: "按钮变体" }
                Caption { text: "把鼠标移到「默认」上：底色不变，描边与文字变品牌色。" }

                QSkinRow {
                    fill: true
                    gap: Theme.space.sm
                    align: "center"

                    QSkinButton { text: "默认"    }
                    QSkinButton { text: "主要";   variant: "primary" }
                    QSkinButton { text: "危险";   variant: "danger"  }
                    QSkinButton { text: "描边";   variant: "ghost"   }
                    QSkinButton { text: "文字";   variant: "text"    }
                    QSkinButton { text: "禁用";   enabled: false     }
                }
            }

            /* ═══════════════ 尺寸 ═══════════════ */

            QSkinColumn {
                fill: true
                gap: Theme.space.xs
                align: "start"

                Heading { level: 3; text: "尺寸" }
                Caption { text: "24 / 32 / 40 —— --td-comp-size-xs / m / xl" }

                QSkinRow {
                    fill: true
                    gap: Theme.space.sm
                    align: "center"

                    QSkinButton { text: "小"; size: "sm" }
                    QSkinButton { text: "中"; size: "md" }
                    QSkinButton { text: "大"; size: "lg" }
                    QSkinButton { text: "小·主要"; size: "sm"; variant: "primary" }
                    QSkinButton { text: "大·主要"; size: "lg"; variant: "primary" }
                }
            }

            Rectangle { width: page.width; height: 1; color: Theme.color.border }

            /* ═══════════════ 输入框 ═══════════════ */

            QSkinColumn {
                fill: true
                gap: Theme.space.xs
                align: "start"

                Heading { level: 3; text: "输入框" }
                Caption { text: "常态白底（不是下沉）+ 聚焦时的 2px 浅蓝外发光。" }

                QSkinRow {
                    fill: true
                    gap: Theme.space.sm
                    align: "center"

                    QSkinInput { width: 220; text: "有内容" }
                    QSkinInput { width: 220; placeholderText: "请输入" }
                    QSkinInput { width: 220; placeholderText: "邮箱格式不对"; error: true }
                    QSkinInput { width: 220; text: "只读"; enabled: false }
                }
            }

            /* ═══════════════ 选择控件 ═══════════════ */

            QSkinColumn {
                fill: true
                gap: Theme.space.xs
                align: "start"

                Heading { level: 3; text: "复选框与开关" }
                Caption { text: "未选中的方框是白色 —— 页面底色是 #EEEEEE，用 bg 会糊成一片。" }

                QSkinRow {
                    fill: true
                    gap: Theme.space.lg
                    align: "center"

                    QSkinCheckBox { text: "未选中" }
                    QSkinCheckBox { text: "已选中";   checked: true }
                    QSkinCheckBox { text: "半选";     indeterminate: true }
                    QSkinCheckBox { text: "禁用";     enabled: false }

                    QSkinSwitch { }
                    QSkinSwitch { checked: true }
                    QSkinSwitch { enabled: false }
                }
            }

            /* ═══════════════ 下拉 ═══════════════ */

            QSkinColumn {
                fill: true
                gap: Theme.space.xs
                align: "start"

                Heading { level: 3; text: "下拉选择" }
                Caption { text: "面板 6px 圆角 + 8px 内边距 + 柔和阴影，列表逻辑仍在 QSkinSelect 里。" }

                QSkinRow {
                    fill: true
                    gap: Theme.space.sm
                    align: "center"

                    QSkinSelect {
                        width: 220
                        placeholderText: "请选择"
                        model: ["选项一", "选项二", "选项三", "选项四", "选项五",
                                "选项六", "选项七", "选项八"]
                    }

                    QSkinSelect {
                        width: 220
                        model: ["设计", "研发", "测试"]
                        currentIndex: 0
                    }
                }
            }

            Rectangle { width: page.width; height: 1; color: Theme.color.border }

            Caption {
                text: "令牌来源：TDesign 官方 Design Token 文档（Vue Next）与《Dark Mode 深色模式》。"
            }
        }
    }
}
