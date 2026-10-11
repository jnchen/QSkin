/****************************************************************************
 * QSkin · 三分钟上手
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 这是**准入条件 B 的判据**：一个文件、只依赖 README 第六节里出现过的 API、
 * 不碰 `.cache/`、不带抓图模式 —— 直接 `qml` 跑起来就是一个可点的窗口。
 *
 *   ./tools/run.sh HelloQSkin              # 默认主题（neutral）
 *   ./tools/run.sh HelloQSkin tdesign      # 也可以直接指定四套主题之一
 *
 * 页面上用到的东西，逐条都能在 README 第六节找到：
 *   QSkinWindow / QSkinColumn / QSkinRow / QSkinGrid / Spacer / Heading / Body / Caption
 *   QSkinButton / ButtonBar / Theme.space / Theme.radius / Theme.color / Theme.mode
 *   四套主题：TDesign.apply() / AntDesign.apply() / ArcoDesign.apply() / Shadcn.apply()
 *
 * ⚠ 本文件刻意**不演示**的东西：抓图（`tools/shot.sh` 那一套会往 `.cache/keep/`
 * 写文件，不是给使用者看的）、内部属性（下划线开头的 `_xxx`）、
 * 以及任何 README 里没写过的类型名 —— 示例比文档多用一个名字，
 * 就等于替文档撒了一个没人复核的谎。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0
import QSkin.Theme.AntDesign 1.0
import QSkin.Theme.ArcoDesign 1.0
import QSkin.Theme.Shadcn 1.0

QSkinWindow {
    id: win

    visible: true
    width:   880
    height:  600
    title:   "QSkin · 三分钟上手"

    /* ---------- 命令行参数（与 tools/shot.sh 同一套约定：key=value）----------
     * ⚠ argOf 是**每个示例自己**的局部函数，不在 QSkinWindow 里 —— 库不该替
     *   使用者决定怎么解析命令行，示例也只是示范一种写法。
     *   run.sh 会把裸的第二个参数（如 `tdesign`）翻成 `theme=tdesign` 传进来。 */
    readonly property var args: Qt.application.arguments
    function argOf(key, dflt) {
        for (var i = 0; i < win.args.length; ++i) {
            var a = win.args[i]
            if (a.indexOf(key + "=") === 0) return a.substring(key.length + 1)
        }
        return dflt
    }

    /* "neutral" 表示地基出厂状态（未安装任何主题）。 */
    property string current: "neutral"

    function applyTheme(name) {
        if (name === "neutral")     { Slots.reset(); Theme.reset() }
        else if (name === "tdesign") TDesign.apply()
        else if (name === "ant")     AntDesign.apply()
        else if (name === "arco")    ArcoDesign.apply()
        else if (name === "shadcn")  Shadcn.apply()
        win.current = name
    }

    Component.onCompleted: {
        /* run.sh 会把裸的第二个参数翻成 theme=<名> 传进来。 */
        var want = win.argOf("theme", "")
        if (want) win.applyTheme(want)
    }

    QSkinColumn {
        id: page

        x: 24
        y: 24
        width: win.width - 48
        gap: Theme.space.lg
        align: "start"

        /* ── 头部：标题 + 换肤 / 明暗 ─────────────────────────────── */
        QSkinRow {
            fill: true
            gap: Theme.space.sm
            align: "center"

            QSkinColumn {
                gap: Theme.space.xxs
                align: "start"

                Heading { level: 2; text: "三分钟上手" }
                Caption {
                    text: "主题 " + (Theme.themeName || "neutral")
                          + "  ·  控件高 " + Theme.size.controlMd + "px"
                          + "  ·  圆角 " + Theme.radius.md + "px"
                          + "  ·  " + (Breakpoints.name || "-")
                }
            }

            Spacer { }

            QSkinButton {
                text: win.current === "neutral" ? "Neutral ✓" : "Neutral"
                variant: win.current === "neutral" ? "primary" : "default"
                onClicked: function() { win.applyTheme("neutral") }
            }
            QSkinButton {
                text: win.current === "tdesign" ? "TDesign ✓" : "TDesign"
                variant: win.current === "tdesign" ? "primary" : "default"
                onClicked: function() { win.applyTheme("tdesign") }
            }
            QSkinButton {
                text: win.current === "ant" ? "Ant ✓" : "Ant"
                variant: win.current === "ant" ? "primary" : "default"
                onClicked: function() { win.applyTheme("ant") }
            }
            QSkinButton {
                text: win.current === "arco" ? "Arco ✓" : "Arco"
                variant: win.current === "arco" ? "primary" : "default"
                onClicked: function() { win.applyTheme("arco") }
            }
            QSkinButton {
                text: win.current === "shadcn" ? "shadcn ✓" : "shadcn"
                variant: win.current === "shadcn" ? "primary" : "default"
                onClicked: function() { win.applyTheme("shadcn") }
            }
            QSkinButton {
                text: Theme.mode === "dark" ? "深色 ✓" : "深色"
                variant: "ghost"
                onClicked: function() {
                    Theme.mode = (Theme.mode === "dark") ? "light" : "dark"
                }
            }
        }

        /* ── 自适应网格：等价于 CSS 的 repeat(auto-fit, minmax(220px, 1fr)) ── */
        QSkinColumn {
            fill: true
            gap: Theme.space.sm
            align: "start"

            Heading { level: 3; text: "自适应网格" }
            Caption { text: "QSkinGrid { minChildWidth: 220 } —— 拖动窗口宽度看列数变化" }

            QSkinGrid {
                fill: true
                minChildWidth: 220
                gap: Theme.space.md

                Repeater {
                    model: [
                        { title: "gap",     desc: "子项间距，不再手算 x / y" },
                        { title: "padding", desc: "内边距与间距共用同一把 4pt 刻度" },
                        { title: "autoFit", desc: "宽度不够自动减少列数" },
                        { title: "1fr",     desc: "每格等分剩余空间" }
                    ]

                    Rectangle {
                        id: card

                        /* Qt 6 起 delegate 的 modelData 建议显式声明为 required，
                         * 否则 qmllint 报 Unqualified access。 */
                        property var modelData

                        height: 96
                        radius: Theme.radius.lg
                        color: Theme.color.bgElevated
                        border.color: Theme.color.border
                        border.width: 1

                        QSkinColumn {
                            x: Theme.space.md
                            y: Theme.space.md
                            width: parent.width - Theme.space.md * 2
                            gap: Theme.space.xxs
                            align: "start"

                            Body { text: card.modelData.title }
                            Caption { text: card.modelData.desc; wrapMode: Text.WordWrap }
                        }
                    }
                }
            }
        }

        /* ── 按钮排布：业务永远把主按钮写在最后 ─────────────────────── */
        QSkinColumn {
            fill: true
            gap: Theme.space.sm
            align: "start"

            Heading { level: 3; text: "按钮排布" }
            Caption { text: "ButtonBar 自己处理平台顺序、危险间距与窄屏堆叠" }

            ButtonBar {
                width: page.width
                align: "end"

                QSkinButton { text: "取消" }
                QSkinButton { text: "确定" }
            }
        }
    }
}
