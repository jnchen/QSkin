/****************************************************************************
 * QSkin · 示例 —— M24：描述列表、统计数值、图片、二维码、日历、评论、漫游
 *
 * ── 七件都在这一屏上，每件的看点 ──────────────────────────────────────
 *   A  `QSkinDescriptions`  两列布局里**标签是右对齐**的；同一组里所有标签
 *      共享一个宽度，且那个宽度 = **组内最宽那个标签**（不是常量、不是
 *      最长值）。看「联系电话」那一项 —— 它把整组的标签列撑开了。改成
 *      `bordered: true` 之后标签变成左对齐、上面与左边各多一条分隔线
 *      （`scene=alt` 就是这件事）。
 *   B  `QSkinCalendar`      **选中**是一块实底（当家的 brand），**今天**是
 *      一圈描边、里面不填色。两个状态在 9 月 8 日与 9 月 15 日各占一个，
 *      所以同一张图上能同时看到两种待遇。`today` 是**注入**的
 *      （`DateUtil.make(2026, 9, 15)`），不是真实时钟 —— 一个会自己变的
 *      控件没法做像素门禁（理由见那份文件头）。
 *   C  `QSkinStatistic`     三档色各自走令牌：默认用 `fg`、增长用 `success`、
 *      出错率用 `danger`。数值的字号是 `Theme.font.xl`，处在标题与说明
 *      之间明显的数量级台阶上。
 *   D  `QSkinQRCode`        码区**永远是纯黑白**（走的是它自己的 `color` /
 *      `background`，**不**跟主题），静默边用 `background` 铺、落在卡片
 *      底色上时就是那一圈白。`scene=alt` 里 `value` 留空 → 占位框。
 *   E  `QSkinImage`         圆角是**真遮罩**（不是画一个圆角底再把图盖上去），
 *      所以四个角上的卡底色是**透出来**的。`scene=alt` 里给一个取不到的
 *      `src` → 错误态，走自定义的 errorComponent。
 *   F  `QSkinComment`       子评论靠默认子项（`body`）嵌套，缩进是
 *      `indent: Theme.space.xl`；动作行里那枚「删除」是 `disabled: true`。
 *   G  `QSkinTour`          模态浮层，`scene=tour` 打开。面板在目标的**下方**
 *      展开，遮罩上挖的洞正好落在目标卡片上（洞的位置在自证行里读数）。
 *
 * ── 抓图（这个文件同时是截图入口，图存到 .cache/keep/）────────────────
 *     ./tools/shot.sh examples/showcase/HelloM24.qml theme=tdesign scene=base  shot=1
 *     ./tools/shot.sh examples/showcase/HelloM24.qml theme=tdesign scene=alt   shot=1
 *     ./tools/shot.sh examples/showcase/HelloM24.qml theme=tdesign scene=tour  shot=1
 *     ./tools/shot.sh examples/showcase/HelloM24.qml theme=ant    scene=base  shot=1
 *     ./tools/shot.sh examples/showcase/HelloM24.qml theme=arco   scene=base  shot=1
 *     ./tools/shot.sh examples/showcase/HelloM24.qml theme=shadcn mode=dark scene=base shot=1
 *
 * ── 为什么这里有一张 .png（本仓唯一的二进制）──────────────────────────
 * `examples/assets/m24-sample.png`（1.2 KB，360×240）是 M24 才加的。
 * 在它之前，本仓的示例全是纯矢量 —— 但 `QSkinImage` 是**第一个真的要把
 * 一张外部位图显示出来**的件，没有图就只剩空态与错误态两条路可看。
 * 它是**造出来的**、确定性的（一段竖直渐变 + 一颗圆 + 地平线 + 三个小
 * 方块），不是照片，所以既不涉及版权也不随环境变。
 *
 * ── 本环境实测结论（沿用 M16~M23，别再踩）──────────────────────────────
 * ① 根节点必须是 Window（见 QSkinWindow）。Item 作根节点事件循环起不来。
 * ② 抓图用 `Item.grabToImage`，不要用 `Window.grabWindow`（返回空图且静默）。
 * ③ 抓 `win.contentItem` —— 未设 parent 的 `Popup`（比如漫游的遮罩）会被
 *    Qt 挂到窗口的 `Overlay.overlay` 上，抓画布等于把它整块丢掉。
 *    **所以 `scene=tour` 那一张要看得到遮罩，必须抓 overlay 而不是画布**
 *    —— 见文件末尾 Timer 里的分叉。
 * ④ 抓图要自己铺底（`grabToImage` **不含** Window 的 `color`）。用
 *    `Theme.color.bg`。
 * ⑤ `grabToImage` 带 `devicePixelRatio`：本机 DPR=1.5，1440 宽的窗口抓到
 *    的是 2160×1515。核验脚本按比例换算，别按 1:1 读。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0
import QSkin.Theme.AntDesign 1.0
import QSkin.Theme.ArcoDesign 1.0
import QSkin.Theme.Shadcn 1.0

QSkinWindow {
    id: win

    width: 1440
    /* ⚠ 高度是**量出来的**，不是估的 —— 而且取的是**最差的那一对**。
     *
     * 抓图那一帧会打一行 `M24-PAGE … overflow=…`（见文件末尾），实测：
     *     tdesign base  implicit=1163   overflow  -12（在 1175 下）
     *     tdesign alt   implicit=1203
     *     ant     alt   implicit=1198
     *     arco    alt   implicit=1206   ← 最差
     *     shadcn  alt   implicit=1116
     * `scene=alt` 更高的原因是**带边框形态的单元格有 padding**（`_cellPad`），
     * 整页比 base 高 40~70px，按 base 定高会把底部的自证行顶出画面。
     * 所以这里按 1206 定 1225，留 19px 余量；代价是 base 在底部多出一段
     * 空白 —— 那是页面正常的下边距，比"切掉一块"好。
     * 改这一屏的内容之后要**重新量**，别按老数字调。 */
    height: 1225
    visible: true
    title: "QSkin · M24 — 描述列表、统计数值、图片、二维码、日历、评论、漫游"

    /* ---------- 命令行参数 ---------- */
    readonly property var args: Qt.application.arguments

    function argOf(key, dflt) {
        for (var i = 0; i < win.args.length; ++i) {
            var a = win.args[i]
            if (a.indexOf(key + "=") === 0) return a.substring(key.length + 1)
        }
        return dflt
    }

    readonly property string themeName: win.argOf("theme", "tdesign")
    readonly property string mode:      win.argOf("mode", "light")
    readonly property string scene:     win.argOf("scene", "base")
    readonly property bool shotMode:    win.argOf("shot", "") !== ""

    function applyTheme() {
        Theme.mode = win.mode
        switch (win.themeName) {
            case "ant":    AntDesign.apply();   break
            case "arco":   ArcoDesign.apply();  break
            case "shadcn": Shadcn.apply();      break
            default:       TDesign.apply();     break
        }
    }

    /* ---------- 场景开关 ----------
     * 写成绑定、不做命令式赋值 —— 少一个时序变量（M18 教训）。
     *
     * `alt`  : 退化态一览。二维码 `value` 留空（空载荷）、图片给一个取不到的
     *          `src`（错误态）、描述列表切成带边框那种形态。三件退化态放
     *          在同一张图上，是为了让"退化时还剩什么"一眼可比。
     * `tour` : 漫游打开，洞落在二维码卡片上。 */
    readonly property bool scAlt:  win.scene === "alt"
    readonly property bool scTour: win.scene === "tour"

    /* ---------- 确定性：把"今天"与"选中"钉死 ----------
     * 两个日期都给**注入值**：`today` 走的是与真实时钟无关的那条路。
     * 中间隔了 7 天，于是"实底（选中）"与"描边（今天）"在同一张图上各
     * 占一格 —— 只给一个日期的话，另一种待遇在像素上根本看不见。 */
    readonly property var fixedToday: DateUtil.make(2026, 9, 15)
    readonly property var fixedValue: DateUtil.make(2026, 9, 8)

    /* ---------- 业务回执（自证行里读）---------- */
    property int descClicks: 0
    property int cmtActions: 0
    property int calPicks:   0

    Component.onCompleted: win.applyTheme()

    /* ---------- 页底（抓图要自己铺，见文件头 ④）---------- */
    Rectangle {
        anchors.fill: parent
        color: Theme.color.bg
    }

    /* ══════════════════════ 页面 ══════════════════════ */

    QSkinColumn {
        id: page

        anchors.fill: parent
        padding: Theme.space.lg
        gap: Theme.space.md

        /* ── 标题行 ── */
        QSkinRow {
            Layout.fillWidth: true
            gap: Theme.space.md

            QSkinColumn {
                Layout.fillWidth: true
                gap: Theme.space.xxs

                Heading {
                    level: 3
                    text: "M24 · 七件"
                }

                Caption {
                    Layout.fillWidth: true
                    text: "描述列表 · 统计数值 · 图片 · 二维码 · 日历 · 评论 · 漫游"
                          + "　｜　二维码走数据侧门禁（另一条算路 + 扫码器回读），"
                          + "其余六件走像素侧"
                }
            }
        }

        /* ── 主区：左窄右宽 ── */
        QSkinRow {
            Layout.fillWidth: true
            Layout.fillHeight: true
            gap: Theme.space.md

            /* ═══════ 左列：二维码 + 日历 ═══════ */
            QSkinColumn {
                Layout.preferredWidth: 470
                Layout.fillHeight: true
                gap: Theme.space.md

                /* ── A · 二维码（同时是漫游的目标）── */
                QSkinCard {
                    id: qrCard

                    Layout.fillWidth: true
                    title: "QSkinQRCode"
                    subtitle: "码区不跟主题（永远纯黑白）；静默边用 background 铺，"
                              + "落在卡片底色上就是那一圈白。"

                    QSkinQRCode {
                        id: qr

                        Layout.alignment: Qt.AlignHCenter
                        /* `alt` 场景留空 → 空载荷（占位框 + emptyText）。
                         * 空串是被**显式拒绝**的（见 [7] 那一组）。 */
                        value: win.scAlt ? "" : "https://workbuddy.cn/qds/m24"
                        ecc: "M"
                        moduleSize: 4
                        quietZone: 4
                        emptyText: "暂无内容"
                    }

                    Caption {
                        Layout.fillWidth: true
                        /* ⚠ `codeSide` 的单位是**模块**，不是像素 —— 像素边长
                         * 要乘 `moduleSize`（也就是 `implicitWidth`）。
                         * 第一版这里写成 `+ qr.codeSide + "px"`，打出「37px」
                         * 而真值是 148px；**属性断言不会红**，因为冒烟
                         * 测试读的正是模块口径（见 QSkinQRCode 的 `codeSide` 文档）。 */
                        text: "版本 v" + qr.version
                              + "　" + qr.moduleCount + "×" + qr.moduleCount + " 模块"
                              + "　掩码 " + qr.mask
                              + "　边长 " + (qr.codeSide * qr.moduleSize) + "px"
                              + "（模块口径 " + qr.codeSide + "）"
                              + "　状态 " + qr.status
                    }
                }

                /* ── B · 日历 ── */
                QSkinCard {
                    Layout.fillWidth: true
                    title: "QSkinCalendar"
                    subtitle: "选中是一块实底，今天是一圈描边、里面不填色。"
                              + "两个日期各占一格，所以两种待遇同框可比。"

                    QSkinCalendar {
                        id: cal

                        Layout.fillWidth: true
                        today: win.fixedToday
                        value: win.fixedValue
                        /* 上面板跟着注入的 today 走（默认就是 today 的年月）。 */
                        onSelected: function (d) { win.calPicks++ }
                    }
                }
            }

            /* ═══════ 右列：描述 / 统计 + 图片 / 评论 ═══════ */
            QSkinColumn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                gap: Theme.space.md

                /* ── C · 描述列表：两种形态 ── */
                QSkinCard {
                    Layout.fillWidth: true
                    title: "QSkinDescriptions"
                    subtitle: "同一份数据的两种形态：无边框（标签右对齐、带冒号）"
                              + "与带边框（标签左对齐、上/左各有分隔线）。"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.md

                        /* 组 A：无边框 · 两列。`alt` 场景切成带边框，
                         * 于是同一份数据换一种形态 —— 标签对齐方向会跟着翻。 */
                        QSkinDescriptions {
                            id: descA

                            Layout.fillWidth: true
                            column: 2
                            bordered: win.scAlt
                            onItemClicked: function (offset) { win.descClicks++ }

                            QSkinDescriptionsItem {
                                label: "订单号"
                                Body { text: "QSkin-2026-0915" }
                            }
                            QSkinDescriptionsItem {
                                label: "状态"
                                Body { text: "已交付" }
                            }
                            /* 「联系电话」是组内最宽的标签 —— 组里所有标签的
                             * 宽度都跟着它走（不是常量）。 */
                            QSkinDescriptionsItem {
                                label: "联系电话"
                                Body { text: "138-0000-8888" }
                            }
                            QSkinDescriptionsItem {
                                label: "交付日期"
                                Body { text: "2026-09-15" }
                            }
                            /* 可点的那一项：`clickable: true` 才发 itemClicked。
                             * 上面三项都是"沉默的"——所以回执数只因为这一项涨。 */
                            QSkinDescriptionsItem {
                                label: "操作"
                                clickable: true
                                Body { text: "查看详情" }
                            }
                            QSkinDescriptionsItem {
                                label: "备注"
                                Body { text: "无" }
                            }
                        }

                        /* 组 B：带边框 · 两列。恒为带边框形态，与组 A 对照。 */
                        QSkinDescriptions {
                            Layout.fillWidth: true
                            column: 2
                            bordered: true

                            QSkinDescriptionsItem {
                                label: "项目"
                                Body { text: "QSkin · Quick Design System" }
                            }
                            QSkinDescriptionsItem {
                                label: "里程碑"
                                Body { text: "M24" }
                            }
                        }
                    }
                }

                /* ── D · 统计数值 + E · 图片 ── */
                QSkinRow {
                    Layout.fillWidth: true
                    gap: Theme.space.md

                    QSkinCard {
                        Layout.fillWidth: true
                        title: "QSkinStatistic"
                        subtitle: "三档色各走令牌。`alt` 场景里第三个转成加载态。"

                        QSkinColumn {
                            Layout.fillWidth: true
                            gap: Theme.space.sm

                            QSkinStatistic {
                                Layout.fillWidth: true
                                title: "总访问量"
                                value: 128456
                                separator: true
                                extra: "近 30 天"
                            }

                            QSkinStatistic {
                                id: statUp

                                Layout.fillWidth: true
                                title: "同比增长"
                                prefix: "+"
                                suffix: "%"
                                value: 12.5
                                precision: 1
                                valueStyle: "success"
                                extra: "较上季度"
                            }

                            QSkinStatistic {
                                Layout.fillWidth: true
                                title: "错误率"
                                suffix: "%"
                                value: 3.2
                                precision: 1
                                valueStyle: "danger"
                                extra: "阈值 5%"
                                /* 加载态换的是**值**，标题与 extra 照常显示
                                 * —— "标题已经拿到了、数还没拿到"是仪表盘
                                 * 的常态。 */
                                loading: win.scAlt
                                loadingWidth: 72
                            }
                        }
                    }

                    QSkinCard {
                        Layout.preferredWidth: 430
                        title: "QSkinImage"
                        subtitle: "圆角是真遮罩：四个角上是卡底色透出来，"
                                  + "不是画一块圆角底再盖图。"

                        QSkinColumn {
                            Layout.fillWidth: true
                            gap: Theme.space.sm

                            QSkinImage {
                                id: imgA

                                Layout.fillWidth: true
                                Layout.preferredHeight: 150
                                /* `alt` 场景给一个**取不到**的 src → 错误态。
                                 * 这里的 src 必须写成绝对 URL：相对路径是按
                                 * **绑定所在的文档**解析的（M22 记过同款）。 */
                                src: win.scAlt
                                     ? Qt.resolvedUrl("../assets/does-not-exist.png")
                                     : Qt.resolvedUrl("../assets/m24-sample.png")
                                alt: "样例图"
                                fit: "cover"
                                radius: Theme.radius.lg
                                preview: true
                            }

                            Caption {
                                Layout.fillWidth: true
                                text: "状态 " + imgA.status
                                      + "　fit " + imgA.fit
                                      + "　圆角 " + Math.round(imgA.radius) + "px"
                                      + "　可预览 " + imgA.preview
                            }
                        }
                    }
                }

                /* ── F · 评论（父 + 子）── */
                QSkinCard {
                    Layout.fillWidth: true
                    title: "QSkinComment"
                    subtitle: "子评论走默认子项（body）嵌套，缩进给 "
                              + "Theme.space.xl；动作行里那枚「删除」是禁用的。"

                    QSkinComment {
                        Layout.fillWidth: true
                        author: "李雷"
                        avatarText: "李"
                        datetime: "2026-09-15 10:20"
                        content: "二维码那一块建议把静默边算进 `codeSide`，"
                                 + "否则贴到深色底上会看不出边界。"
                        actions: ["回复", "引用", ({ text: "删除", disabled: true })]
                        onActionClicked: function (index) { win.cmtActions++ }

                        QSkinComment {
                            Layout.fillWidth: true
                            indent: Theme.space.xl
                            author: "韩梅梅"
                            avatarText: "韩"
                            datetime: "2026-09-15 10:34"
                            content: "已经这么做了：`codeSide` 里就含着两倍静默边。"
                            actions: ["回复"]
                            onActionClicked: function (index) { win.cmtActions++ }
                        }
                    }
                }

                /* 撑开剩余高度，让上面几块贴着顶部（而不是被拉散）。 */
                Item { Layout.fillHeight: true }
            }
        }

        /* ── 自证行 ──
         * 人看图就能核对状态：主题、场景、码的版本与掩码、日历的两个日期、
         * 描述列表的形态与标签宽、图片状态、漫游的进度与洞是否就绪。
         * 这里面**每一个**读数在核验脚本里都有对应的机器判据。 */
        QSkinColumn {
            id: selfTest

            Layout.fillWidth: true
            gap: Theme.space.xxs

            Caption {
                Layout.fillWidth: true
                text: "自证 · theme=" + win.themeName + " mode=" + win.mode
                      + " scene=" + win.scene
                      + "　｜　码 v" + qr.version + " " + qr.moduleCount + "×"
                      + qr.moduleCount + " 掩码=" + qr.mask
                      + " 边长=" + (qr.codeSide * qr.moduleSize) + "px"
                      + " valid=" + qr.valid
                      + " 状态=" + qr.status
            }

            Caption {
                Layout.fillWidth: true
                text: "日历 " + cal.panelYear + "-" + DateUtil.pad2(cal.panelMonth)
                      + " 今天=" + DateUtil.format(cal.today, "YYYY-MM-DD")
                      + " 选中=" + (cal.value === null
                                    ? "无" : DateUtil.format(cal.value, "YYYY-MM-DD"))
                      + "　｜　描述 列=" + descA.column + " 边框=" + descA.bordered
                      + " 标签宽=" + Math.round(descA._uniformLabelWidth)
                      + "　｜　图片=" + imgA.status
                      + "　｜　漫游 open=" + tour.open + " current=" + tour.current
                      + "/" + tour.count + " 就绪=" + tour.maskReady
            }
        }
    }

    /* ══════════════════════ G · 漫游 ══════════════════════ */
    QSkinTour {
        id: tour

        open: win.scTour
        current: 0
        highlightPadding: 6
        steps: [
            { target: qrCard,
              title: "二维码",
              description: "静默边算在 codeSide 里，贴在任意底色上都有边界。" },
            { target: cal,
              title: "日历",
              description: "选中是实底、今天是描边 —— 两种状态在令牌上同源。" },
            { title: "没有目标的一步",
              description: "target 缺省时洞收成零矩形，遮罩整片压住 —— "
                           + "这一步专门用来看那种形态。" }
        ]
    }

    /* ---------- 抓图（仅 shot 模式）----------
     * 1500ms 与 M17 起的其它屏一致：等淡入动画与布局收尾。
     *
     * ⚠ `scene=tour` 抓的**不是** `win.contentItem` —— 漫游的遮罩是一个
     * 未设 parent 的 Popup，Qt 会把它挂到窗口的 `Overlay.overlay` 上，
     * 抓画布等于把整个遮罩丢掉（文件头 ③）。所以那一支抓 overlay。
     * 抓 overlay 时**必须**带上画布那层：overlay 自己是透明的，不含底。
     * 于是先把画布抓出来合成 —— `grabToImage` 不支持直接抓两层，
     * 这里改成抓 `win.contentItem` 的父（也就是窗口的内容根），
     * 它的孩子里既有画布也有 overlay。 */
    Timer {
        interval: 1500
        running: win.shotMode
        onTriggered: {
            /* 抓图那一帧核对「页面自然高装下了没有」。
             *
             * 为什么要在这里报数：溢出为正意味着**底部有内容被切掉**，而这在
             * 图上只看得出"少了一块"，看不出少了多少、也不知道是哪一块 ——
             * `scene=alt` 就撞过一次（带边框形态的单元格有 padding，整页比
             * base 高约 70px，把自证行顶出去了）。所以让它在日志里报数，
             * 抓图脚本 grep 这一行就能判。 */
            console.log("M24-PAGE theme=" + win.themeName + " mode=" + win.mode
                        + " scene=" + win.scene
                        + " page=" + Math.round(page.height)
                        + " implicit=" + Math.round(page.implicitHeight)
                        + " overflow=" + Math.round(page.implicitHeight - page.height))
            var base = Qt.resolvedUrl("../../.cache/keep/").toString().replace("file:///", "")
            var name = "m24_example_" + win.themeName + "_" + win.mode
                       + "_" + win.scene + ".png"
            win.contentItem.grabToImage(function (res) {
                Qt.exit(res.saveToFile(base + name) ? 0 : 9)
            })
        }
    }
}
