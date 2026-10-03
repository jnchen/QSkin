/****************************************************************************
 * QSkin · Quick Design System — M0 演示
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 运行：
 *     QML2_IMPORT_PATH=<仓库>/src qml examples/HelloFoundation.qml
 *
 * 这个示例刻意**不使用任何控件库**：下面所有按钮、卡片都是 Rectangle + Text。
 * 目的就是证明一件事 ——
 * 即使还没有控件层和主题层，光靠地基层的
 *「间距刻度 / 排版阶梯 / 自适应网格 / 按钮布局 / 焦点环」，
 * 手写出来的界面也不会显得原始。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

QSkinWindow {
    id: win

    width:  1120
    height: 840
    visible: true
    title: "QSkin Foundation · M0 演示"

    Rectangle { anchors.fill: parent; color: Theme.color.bg }

    /* 页面主列：显式给宽高，不使用 anchors（避免与组件的 hug 默认尺寸冲突） */
    QSkinColumn {
        id: page

        x: Theme.space.xl
        y: Theme.space.xl
        width:  win.width  - Theme.space.xl * 2
        height: win.height - Theme.space.xl * 2
        gap: Theme.space.lg
        align: "start"


        /* ─────────────────────────── 头部 ─────────────────────────── */

        QSkinRow {
            fill: true
            gap: Theme.space.md
            align: "center"

            QSkinColumn {
                gap: Theme.space.xxs
                align: "start"

                Heading { level: 2; text: "QSkin Foundation · M0" }
                Body {
                    text: "地基层：布局 · 间距 · 排版 · 断点 · 焦点环"
                    tone: "secondary"
                }
            }

            /* 弹性占位，把右侧的明暗切换按钮顶到行尾。
             * 用 Spacer 而不是 Item { Layout.fillWidth: true }：
             * 后者要求使用方自己 import QtQuick.Layouts，那是地基的内部实现，
             * 不该泄漏到业务代码里。 */
            Spacer { }

            /* 明暗切换 */
            Rectangle {
                width: 120
                height: Theme.size.controlMd
                radius: Theme.radius.md
                color: Theme.mode === "dark" ? Theme.color.bgSunken : Theme.color.brandSubtle
                border.color: Theme.color.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: Theme.mode === "dark" ? "切到浅色" : "切到深色"
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.sm
                    color: Theme.color.fg
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Theme.mode = (Theme.mode === "dark" ? "light" : "dark")
                }
            }
        }

        Rectangle { width: page.width; height: 1; color: Theme.color.border }


        /* ─────────────────────── 自适应网格 ─────────────────────── */

        QSkinColumn {
            fill: true
            gap: Theme.space.sm
            align: "start"

            Heading { level: 3; text: "自适应网格" }
            Caption { text: "等价于 CSS 的 repeat(auto-fit, minmax(220px, 1fr)) —— 拖动窗口宽度试试" }

            QSkinGrid {
                fill: true
                minChildWidth: 220
                gap: Theme.space.md

                Repeater {
                    model: [
                        { title: "gap",        desc: "≈ CSS gap，一行搞定子项间距，不再手算 x/y" },
                        { title: "padding",    desc: "≈ CSS padding，内边距与间距共用同一把刻度" },
                        { title: "autoFit",    desc: "≈ minmax() 下限，宽度不够自动减少列数" },
                        { title: "1fr",        desc: "每格等分剩余空间，无需手写百分比宽度" },
                        { title: "Breakpoints",desc: "compact / medium / expanded 三档响应式" },
                        { title: "FocusRing",  desc: "键盘焦点可见，鼠标点击不打扰" }
                    ]

                    Rectangle {
                        id: card

                        /* Qt 6 起 delegate 的 modelData / index 建议显式声明为
                         * required property，否则 qmllint 报 Unqualified access。 */
                        required property var modelData

                        height: 104
                        radius: Theme.radius.lg
                        color: Theme.color.bgElevated
                        border.color: Theme.color.border
                        border.width: 1

                        QSkinColumn {
                            x: Theme.space.md
                            y: Theme.space.md
                            width: parent.width - Theme.space.md * 2
                            gap: Theme.space.xs
                            align: "start"

                            /* 限定为 card.modelData：直接写 modelData 会触发
                             * qmllint 的 Unqualified access —— 这属于跨层作用域
                             * 访问，加上 id 才能通过静态检查。 */
                            Heading { level: 4; text: card.modelData.title }
                            /* 文本在 Layout 容器里**不能**用显式 width 约束 ——
                             * Layout 取 preferredWidth（= Text.implicitWidth，
                             * 即"不换行的整行宽"），width 会被静默覆盖，
                             * wrapMode 形同虚设。要撑满内宽用 Layout.fillWidth。 */
                            Body {
                                Layout.fillWidth: true
                                text: card.modelData.desc
                                tone: "secondary"
                            }
                        }
                    }
                }
            }
        }


        /* ─────────────────────── 按钮布局系统 ─────────────────────── */

        QSkinColumn {
            fill: true
            gap: Theme.space.sm
            align: "start"

            Heading { level: 3; text: "按钮布局系统" }
            Caption {
                text: "主按钮永远写在最后；Windows 上自动挪到最左，macOS / Linux 保持在最右。" +
                      "「删除」被标为危险操作，两侧自动加大安全间距。"
            }

            Rectangle {
                width: page.width
                height: 96
                radius: Theme.radius.lg
                color: Theme.color.bgSubtle
                border.color: Theme.color.border
                border.width: 1

                ButtonBar {
                    x: Theme.space.md
                    y: Theme.space.md
                    width: parent.width - Theme.space.md * 2
                    align: "end"
                    dangerIndexes: [0]

                    Rectangle {
                        height: Theme.size.controlMd
                        implicitWidth: 88
                        radius: Theme.radius.md
                        color: Theme.color.dangerSubtle
                        border.color: Theme.color.danger
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "删除"
                            font.family: Theme.font.family
                            font.pixelSize: Theme.font.sm
                            color: Theme.color.danger
                        }
                    }
                    Rectangle {
                        height: Theme.size.controlMd
                        implicitWidth: 88
                        radius: Theme.radius.md
                        color: Theme.color.bgElevated
                        border.color: Theme.color.borderStrong
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "取消"
                            font.family: Theme.font.family
                            font.pixelSize: Theme.font.sm
                            color: Theme.color.fg
                        }
                    }
                    Rectangle {
                        height: Theme.size.controlMd
                        implicitWidth: 88
                        radius: Theme.radius.md
                        color: Theme.color.brand
                        Text {
                            anchors.centerIn: parent
                            text: "确定"
                            font.family: Theme.font.family
                            font.pixelSize: Theme.font.sm
                            font.bold: true
                            color: Theme.color.onBrand
                        }
                    }
                }
            }
        }


        /* ─────────────────────── 焦点环 ─────────────────────── */

        QSkinColumn {
            fill: true
            gap: Theme.space.sm
            align: "start"

            Heading { level: 3; text: "键盘焦点环" }
            Caption { text: "用 Tab / Shift+Tab 在下面三个按钮间切换 —— 只有键盘导航才显示焦点环" }

            QSkinRow {
                gap: Theme.space.md
                align: "center"

                Repeater {
                    model: ["上一步", "下一步", "完成"]

                    FocusScope {
                        id: fs
                        required property int index
                        required property var modelData

                        width: 104
                        height: Theme.size.controlMd
                        activeFocusOnTab: true
                        focus: index === 0

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius.md
                            color: fs.activeFocus ? Theme.color.brandSubtle : Theme.color.bgElevated
                            border.color: fs.activeFocus ? Theme.color.brand : Theme.color.border
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: fs.modelData
                                font.family: Theme.font.family
                                font.pixelSize: Theme.font.sm
                                color: fs.activeFocus ? Theme.color.brand : Theme.color.fg
                            }
                        }

                        FocusRing { control: fs }
                    }
                }
            }
        }


        /* ─────────────────────── 当前状态 ─────────────────────── */

        Rectangle {
            width: page.width
            height: 52
            radius: Theme.radius.md
            color: Theme.color.bgSunken
            border.color: Theme.color.border
            border.width: 1

            QSkinRow {
                x: Theme.space.md
                y: Theme.space.sm
                gap: Theme.space.lg
                align: "center"

                Caption {
                    text: "主题: " + Theme.themeName +
                          "   |   模式: " + Theme.mode +
                          "   |   断点: " + Breakpoints.name +
                          " (" + Breakpoints.width + "px)"
                }
            }
        }
    }
}
