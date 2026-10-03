/****************************************************************************
 * QSkin · 示例 —— M23：折叠、分段、时间轴、轮播
 *
 * 五件（Collapse / CollapseItem / Segmented / Timeline / TimelineItem /
 * Carousel）在这一屏里全部用上，而且是**同一屏内在场** —— 单独摆五个样例
 * 看不出"它们是不是同一个系统里的东西"，而"同一系统"正是这一批的全部意义：
 *
 *   · `QSkinCollapse`     手风琴与多开两种。`Collapsible`（单块）不是独立件，
 *                       就是它的"不给组"用法 —— 这一屏里两块**都挂组**
 *                       （挂组才有全序、才画分隔线），不挂组的样子见冒烟。
 *   · `QSkinSegmented`    `options` 是数据驱动的（日/周/月是同一句话的不同取值）；
 *                       活动块**只有一个实例**、按当前段的**实际盒子**摆。
 *   · `QSkinTimeline`     连接线只在点与点之间（容器 `gap: 0`，呼吸空间由条目的
 *                       `bottomGap` 承担 —— 用容器的 gap 会在两条之间留出一段
 *                       **没人画线**的真空）。
 *   · `QSkinCarousel`     `autoplay` 默认**关**（抓图确定性）；每页外面套一层
 *                       Loader（"每页 = 视口大小"所必需）。
 *
 * ── 两格新插槽在这一屏里各现身一次 ────────────────────────────────────
 * 这一批只新开两格（其余全复用：折叠的箭头走 `chevronIndicator`、
 * 标题走 `label`）：
 *
 *   `segmentThumb`  分段的活动块。**只有一个实例** —— 所以换段时它在"滑"，
 *                   而不是每段各自显各的（那样位移这件事就没了）。
 *   `timelineDot`   时间轴的点。末点画成**空心**（本仓取法），非末条实心 ——
 *                   这一屏里最后一颗点必须是空心的，看图即可核对。
 *
 * 切到 Ant 再抓一次：分段的块**没有描边**（Basic 有一圈 1px）——
 * 这是 `ADSegmentThumb` 与 `BasicSegmentThumb` 的唯一差别，也是
 * "这一格真的被装载了"的抓手（判据必须写"不等于 Basic"，不能写"非 null"）。
 *
 * ── 这一屏的结构就是它的测试用例 ──────────────────────────────────────
 *
 *   QSkinWindow
 *   ├─ Rectangle                        页底（抓图要自己铺，见下）
 *   └─ QSkinColumn                        页
 *      ├─ QSkinRow                        标题行
 *      ├─ QSkinRow                        主区，左窄右宽
 *      │  ├─ QSkinColumn（左）
 *      │  │  ├─ QSkinCard「折叠面板」       ← 手风琴（3 块）+ 多开（2 块）
 *      │  │  └─ QSkinCard「分段控制器」      ← 3 段（含一项禁用）+ 2 段
 *      │  └─ QSkinColumn（右）
 *      │     ├─ QSkinCard「时间轴」          ← 四种语义 + 末点空心 + 一枚自定义点
 *      │     └─ QSkinCard「轮播」            ← 3 页 + 指示点（autoplay 关）
 *      └─ QSkinColumn id: selfTest         自证行（见下）
 *
 * ── 想看的六件事 ──────────────────────────────────────────────────────
 *   ① 手风琴那一组**永远最多开一块** —— 点第二块，第一块自己关
 *      （收敛放在**属性变化**上：`onExpandedKeysChanged` 与
 *      `onAccordionChanged` 两处走同一个函数，所以改 `accordion`
 *      也会立刻收敛，而不只是点的时候）。
 *   ② 分段的块宽**不等于**总宽 / 段数："列表"与"卡片视图"不一样宽，
 *      块宽跟着当前段的实际盒子走。等分公式在这一屏上就会错位。
 *   ③ 分段里那项 `disabled: true` 是**跳过去**的，不是停下来。
 *   ④ 时间轴最后一颗点是**空心**的（其余实心）；第一颗点**上方没有线**、
 *      最后一颗点**下方没有线**。
 *   ⑤ 轮播切页是**整页平移**：偏移量是视口宽的整数倍（`scene=page2` 抓一张）。
 *   ⑥ 切到 shadcn 再跑一次：分段的块仍然是一块抬起的底，但角的圆度、
 *      底纹对比都跟着令牌走 —— 两格插槽都没有写死的色值。
 *
 * ── 抓图（这个文件同时是截图入口，图存到 .cache/keep/）────────────────
 *     ./tools/shot.sh examples/showcase/HelloM23.qml theme=tdesign scene=base  shot=1
 *     ./tools/shot.sh examples/showcase/HelloM23.qml theme=tdesign scene=page2 shot=1
 *     ./tools/shot.sh examples/showcase/HelloM23.qml theme=tdesign scene=card  shot=1
 *     ./tools/shot.sh examples/showcase/HelloM23.qml theme=tdesign scene=open  shot=1
 *     ./tools/shot.sh examples/showcase/HelloM23.qml theme=ant    scene=base  shot=1
 *     ./tools/shot.sh examples/showcase/HelloM23.qml theme=shadcn mode=dark scene=base shot=1
 *
 * ── 本环境实测结论（沿用 M16~M22，别再踩）──────────────────────────────
 * ① 根节点必须是 Window（见 QSkinWindow）。Item 作根节点事件循环起不来。
 * ② 抓图用 `Item.grabToImage`，不要用 `Window.grabWindow`（返回空图且静默）。
 * ③ 抓 `win.contentItem` —— 未设 parent 的 `Popup` 会被 Qt 挂到窗口的
 *    `Overlay.overlay` 上，抓画布等于把它整块丢掉。
 * ④ 抓图要自己铺底（`grabToImage` **不含** Window 的 `color`）。用
 *    `Theme.color.bg`。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0
import QSkin.Theme.AntDesign 1.0
import QSkin.Theme.ArcoDesign 1.0
import QSkin.Theme.Shadcn 1.0

QSkinWindow {
    id: win

    width: 1440
    height: 1010
    visible: true
    title: "QSkin · M23 — 折叠、分段、时间轴、轮播"

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

    /* 场景开关写成绑定，不做命令式赋值 —— 少一个时序变量（M18 教训）。
     *
     * `open`  : 两块折叠面板都打开（看展开态的内容与分隔线）
     * `page2` : 轮播切到第 2 页（看平移偏移是不是视口宽的整数倍）
     * `card`  : 分段切到「卡片视图」—— 它比「列表」宽，于是活动块的宽度
     *           必须跟着变。这是"块宽 ≠ 总宽 / 段数"的**像素侧**判据：
     *           等分实现下 base 与 card 两张图的块宽会一模一样。 */
    readonly property bool scOpen:  win.scene === "open"
    readonly property bool scPage2: win.scene === "page2"
    readonly property bool scCard:  win.scene === "card"

    /* 业务回执（自证行里读） */
    property int segChanges: 0
    property int tabChanges: 0

    Component.onCompleted: function () {
        win.applyTheme()
        if (win.scPage2) car.goTo(1)
        if (win.scCard) seg.value = "card"
    }

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

            Heading { level: 3; text: "折叠 · 分段 · 时间轴 · 轮播" }

            Caption {
                Layout.fillWidth: true
                text: "QSkinCollapse · QSkinSegmented · QSkinTimeline · QSkinCarousel"
                      + "（这一批只新开两格插槽：segmentThumb / timelineDot）"
            }

            Caption { text: win.themeName + " / " + win.mode + " / " + win.scene }
        }

        /* ══════════ 主区：左窄右宽 ══════════ */
        QSkinRow {
            Layout.fillWidth: true
            Layout.fillHeight: true
            gap: Theme.space.md

            QSkinColumn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 4
                gap: Theme.space.md

                /* ══════ 折叠面板 ══════ */
                QSkinCard {
                    Layout.fillWidth: true
                    title: "折叠面板"
                    subtitle: "上面一组是手风琴（永远最多开一块）；下面一组可多开。"
                              + "箭头走 chevronIndicator、标题走 label —— 都没有另开格"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        /* ── 手风琴 ── */
                        QSkinCollapse {
                            id: colAcc

                            Layout.fillWidth: true
                            accordion: true
                            expandedKeys: win.scOpen ? [ "ship" ] : [ "order" ]

                            QSkinCollapseItem {
                                key: "order"
                                title: "订单基本信息"
                                Body {
                                    Layout.fillWidth: true
                                    text: "下单时间 09:12 · 支付方式 余额 · 收货人 王某"
                                }
                            }

                            QSkinCollapseItem {
                                key: "ship"
                                title: "配送与签收"
                                Body {
                                    Layout.fillWidth: true
                                    text: "已由 顺丰 承运，预计 09-16 前送达。"
                                }
                            }

                            QSkinCollapseItem {
                                key: "after"
                                title: "售后条款"
                                Body {
                                    Layout.fillWidth: true
                                    text: "七天无理由；生鲜类不适用。"
                                }
                            }
                        }

                        /* ── 多开 + 一块禁用 ── */
                        QSkinCollapse {
                            id: colMulti

                            Layout.fillWidth: true
                            accordion: false
                            expandedKeys: win.scOpen ? [ "a", "b" ] : []

                            QSkinCollapseItem {
                                key: "a"
                                title: "可多开的一组"
                                Body {
                                    Layout.fillWidth: true
                                    text: "这一组同时开着两块也不会互相挤掉。"
                                }
                            }

                            QSkinCollapseItem {
                                key: "b"
                                title: "第二块"
                                Body {
                                    Layout.fillWidth: true
                                    text: "手风琴那一组做不到这件事。"
                                }
                            }

                            QSkinCollapseItem {
                                key: "c"
                                title: "这一块被禁用（展不开）"
                                disabled: true
                                Body {
                                    Layout.fillWidth: true
                                    text: "禁用的成员连键盘也进不去。"
                                }
                            }
                        }
                    }
                }

                /* ══════ 分段控制器 ══════ */
                QSkinCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "分段控制器"
                    subtitle: "活动块宽 ≠ 总宽 / 段数 —— 它跟着当前段的**实际盒子**走，"
                              + "所以长短不一的标题不会错位"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.md

                        QSkinSegmented {
                            id: seg

                            Layout.fillWidth: true
                            options: [
                                { value: "list",  label: "列表" },
                                { value: "card",  label: "卡片视图" },
                                { value: "chart", label: "图表与明细报表" },
                                { value: "blocked", label: "暂不可用", disabled: true }
                            ]
                            value: "list"
                            onSelectionChanged: win.segChanges++
                        }

                        Caption {
                            Layout.fillWidth: true
                            text: "上面那项「暂不可用」是**跳过去**的：左右键不会停在它上面。"
                        }

                        QSkinSegmented {
                            id: seg2

                            Layout.fillWidth: true
                            options: [ "日", "周", "月" ]
                            value: "周"
                        }
                    }
                }
            }

            QSkinColumn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 6
                gap: Theme.space.md

                /* ══════ 时间轴 ══════ */
                QSkinCard {
                    Layout.fillWidth: true
                    title: "时间轴"
                    subtitle: "线只在点与点之间 —— 第一颗点上方无线、最后一颗点下方无线；"
                              + "最后一颗是**空心**的（本仓取法）"

                    QSkinTimeline {
                        id: tl

                        Layout.fillWidth: true

                        QSkinTimelineItem {
                            id: ti1
                            type: "primary"
                            label: "09:12"
                            Body { text: "已下单" }
                        }

                        QSkinTimelineItem {
                            id: ti2
                            type: "success"
                            label: "09:20"
                            Body { text: "支付成功 · 余额支付 ¥128.00" }
                        }

                        QSkinTimelineItem {
                            id: ti3
                            type: "warning"
                            label: "10:05"
                            Body { text: "仓库拣货中（地址有变更待确认）" }
                        }

                        QSkinTimelineItem {
                            id: ti4
                            Body { text: "出库 —— 最后一颗点是空心的" }
                        }
                    }
                }

                /* ══════ 轮播 ══════ */
                QSkinCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "轮播"
                    subtitle: "autoplay 默认**关**（抓图确定性）；每页外面套一层 Loader，"
                              + "所以每页都等于视口大小。指示点没有进插槽 —— 理由见 QSkinCarousel 文件头"

                    QSkinColumn {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        gap: Theme.space.sm

                        QSkinCarousel {
                            id: car

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            model: [ "第一页", "第二页", "第三页" ]
                            delegate: pageTpl
                            onCurrentIndexChanged: win.tabChanges++
                        }

                        Caption {
                            Layout.fillWidth: true
                            text: "切页是整页平移：偏移量 = 视口宽 × 页号（scene=page2 抓一张即可量）"
                        }
                    }
                }
            }
        }

        /* ══════════ 自证行 ══════════
         * 抓图与人工核验都需要一个**不依赖眼睛判断**的锚点：把这一屏的读数
         * 直接印在图上 —— 图里看到的和它写的对不上，就是渲染出了问题
         * （M17 起沿用这个做法，这是第 8 个这么干的示例屏）。 */
        QSkinColumn {
            id: selfTest

            Layout.fillWidth: true
            gap: 2

            Caption {
                Layout.fillWidth: true
                text: "theme=" + win.themeName + "  mode=" + win.mode
                      + "  scene=" + win.scene
                      + "    collapse: 手风琴 accordion=" + colAcc.accordion
                      + " keys=" + colAcc.expandedKeys.length
                      + " 块数=" + colAcc._panels.length
                      + "   多开 keys=" + colMulti.expandedKeys.length
                      + " 禁用块可开=" + colMulti.isExpanded("c")
            }

            Caption {
                Layout.fillWidth: true
                text: "segmented: value=" + seg.value
                      + " idx=" + seg.currentIndex
                      + " 段数=" + seg.count
                      + " thumb x=" + Math.round(seg._thumbX())
                      + " w=" + Math.round(seg._thumbW())
                      + " 跳禁用=" + (seg.currentIndex === 3 ? "否" : "是")
                      + "    |    两段组 idx=" + seg2.currentIndex
                      + " w=" + Math.round(seg2._thumbW())
                      + "    选中变化=" + win.segChanges
                      + " 次"
            }

            Caption {
                Layout.fillWidth: true
                text: "timeline: 条数=" + tl._items.length
                      + " 点径=" + ti1.dotSize
                      + " 呼吸=" + ti1.bottomGap
                      + "   首(primary) isFirst=" + ti1.isFirst
                      + " isLast=" + ti1.isLast
                      + "   末(默认档) isLast=" + ti4.isLast
                      + " type=" + ti4.type
                      + "    成功型/警示型=" + ti2.type + "/" + ti3.type
            }

            Caption {
                Layout.fillWidth: true
                text: "carousel: 页数=" + car.count
                      + " 当前=" + car.currentIndex
                      + " loop=" + car.loop
                      + " autoplay=" + car.autoplay
                      + " 视口宽=" + Math.round(car.width)
                      + "    切页=" + win.tabChanges + " 次"
            }
        }
    }

    /* ---------- 轮播的一页 ----------
     * ⚠ 两个属性必须声明成**普通属性**，不能写 `required property` ——
     * required 只能由 Repeater 直接注入给它的 delegate，而每一页外面还有
     * 一层 Loader（"每页 = 视口大小"所必需）。实测：`modelData` 穿得过
     * Loader、`index` 穿不过；写成 required 的后果是整页构造失败。
     * 注入走 `onLoaded`，与 QSkinList 的 cellLoader 同一个解法。 */
    Component {
        id: pageTpl

        Rectangle {
            id: pageRoot

            property int index: -1
            property var modelData: undefined

            color: Theme.color.bgSubtle
            radius: Theme.radius.md
            border.width: 1
            border.color: Theme.color.border

            QSkinColumn {
                anchors.centerIn: parent
                gap: Theme.space.xxs

                Heading {
                    level: 4
                    text: String(pageRoot.modelData)
                }

                Caption {
                    text: "第 " + (pageRoot.index + 1) + " 页"
                }
            }

            /* ── 页码记号：`index + 1` 个小方块 ──
             * 这是**为像素核验准备的**，不是装饰。
             *
             * 轮播"整页平移"这件事在像素上有个反直觉的性质：**偏移量本身
             * 不可见** —— 每页都等于视口大小，所以第 1 页与第 2 页的画面
             * 结构完全重合，只有文字内容不同，而文字不便机器判读。
             *
             * 放一组"个数 = 页号 + 1"的方块之后，"现在在第几页"变成一件
             * **可数**的事：`_verify_m23.py` 数一下方块个数就够。
             * 它也顺带给这一屏加了一点真实轮播该有的信息量。 */
            QSkinRow {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Theme.space.md
                gap: Theme.space.xxs

                Repeater {
                    model: pageRoot.index + 1

                    delegate: Rectangle {
                        width: 8
                        height: 8
                        radius: 1
                        color: Theme.color.brand
                    }
                }
            }
        }
    }

    /* ---------- 抓图（仅 shot 模式）----------
     * 1500ms 与 M17 起的其它屏一致：等淡入动画与布局收尾，否则抓到的是中间帧。
     * 轮播的平移动画只在 `animate` 打开时才跑，而默认是关的 —— 所以换页之后
     * 立刻抓也是终态（这一条正是"默认值也是门禁的一部分"）。 */
    Timer {
        interval: 1500
        running: win.shotMode
        onTriggered: {
            var base = Qt.resolvedUrl("../../.cache/keep/").toString().replace("file:///", "")
            var name = "m23_example_" + win.themeName + "_" + win.mode
                       + "_" + win.scene + ".png"
            win.contentItem.grabToImage(function (res) {
                Qt.exit(res.saveToFile(base + name) ? 0 : 9)
            })
        }
    }
}
