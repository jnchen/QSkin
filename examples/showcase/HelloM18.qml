/****************************************************************************
 * QSkin · 示例 —— M18：布局与容器原子
 *
 * 六个控件（Divider / AspectRatio / ScrollArea / Card / Layout / Splitter）
 * 在这一个屏幕里全部用上，而且**互相嵌套** —— 单独摆六个样例看不出
 * "它们能不能一起工作"，而"能不能一起工作"恰恰是容器类控件的全部意义。
 *
 * ── 这一屏的结构就是它的测试用例 ──────────────────────────────────────
 *
 *   QSkinLayout                        ← 骨架：顶栏 / 侧栏 / 内容 / 底栏
 *   ├─ header   标题 + 三个开关
 *   ├─ sider    导航（可折叠，折叠后 240 → 56）
 *   ├─ content  QSkinSplitter          ← 用户可拖的左右分配
 *   │           ├─ 左：QSkinScrollArea  ← 可滚，里面有 4 种 Divider
 *   │           └─ 右：QSkinCard        ← 头部 / 内容 / 尾部 + 分割线
 *   │                  QSkinAspectRatio ← 16:9 的地，里面再放东西
 *   └─ footer   自证状态行
 *
 * ── 想看的七件事 ──────────────────────────────────────────────────────
 *   ① 拖中间那条界线：左右两栏跟着变，**两栏都不会被拖没**
 *      （minSize 80 拦住）；双击界线复位到中分
 *   ② 点「折叠侧栏」：侧栏 240 → 56，**内容区跟着变宽**
 *      （不是"侧栏没了但中间留一块空白"）
 *   ③ 左侧滚动区滚到底：内容比视口高，**右侧卡片纹丝不动**
 *      （滚动被关在 ScrollArea 里，没有外溢到整页）
 *   ④ 四种 Divider：无文字（通线）、居中带文字、靠左带文字、虚线
 *      —— 带文字那两条，线是**断开的**，文字两边留白相等
 *   ⑤ 纵向 Divider 夹在两个词之间（"已读 | 未读"），
 *      高度跟着那一行走，不撑满整页
 *   ⑥ 卡片：标题 / 副标题 / 右上角操作 / 内容 / 底部按钮五段齐全；
 *      分割线只在"上一段和下一段都在"时出现
 *   ⑦ 16:9 的框：无论窗口怎么拉宽，它的高都按比例长
 *
 * ── 为什么底部要有一行"自言自语" ─────────────────────────────────────
 * 抓图与人工核验都需要一个**不依赖眼睛判断**的锚点：这一行把
 * 主题、侧栏宽度、分栏比例、滚动位置直接写出来。图里看到的和它写的
 * 对不上，就是渲染出了问题（M17 起沿用这个做法）。
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

    width: 1280
    height: 920
    visible: true
    title: "QSkin · M18 — 布局与容器原子"

    /* 起始状态钉死，不留悬念：抓图脚本与人工核验都从这里出发（M17 惯例）。
     * 注意这两行必须写在 onCompleted 里 —— 对象声明体中不允许出现
     * 裸表达式语句（`Theme.mode = "x"` 会被当成非法的属性绑定语法，
     * 报 `Expected token ':'`，整个文件加载失败）。 */
    Component.onCompleted: {
        Theme.mode = "light"
        TDesign.apply()
    }

    QtObject {
        id: state

        property int themeIndex: 0
        property var themeNames: ["TDesign", "Ant Design", "Arco Design", "shadcn"]
        property string lastAction: "—"

        function cycleTheme() {
            state.themeIndex = (state.themeIndex + 1) % state.themeNames.length
            switch (state.themeIndex) {
            case 1:  AntDesign.apply();  break
            case 2:  ArcoDesign.apply(); break
            case 3:  Shadcn.apply();     break
            default: TDesign.apply();    break
            }
            state.lastAction = "切换主题 → " + state.themeNames[state.themeIndex]
        }
    }

    /* ══════════════════ 骨架 ══════════════════ */

    QSkinLayout {
        id: layout

        anchors.fill: parent
        siderWidth: 220
        siderCollapsedWidth: 56
        headerColor: Theme.color.bgSubtle
        siderColor:  Theme.color.bgSubtle
        headerSpacing: Theme.space.lg
        siderSpacing:  Theme.space.xs
        footerHeight: 96

        /* ── 顶栏 ──
         * `headerHost` 本身就是一个 QSkinRow（横排），所以这里**直接列子项**。
         * 不要再写 `header: QSkinRow { ... }` 套一层：内层的 `fill: true` 会把
         * 自己的高度绑到外层，而外层的高度又由内层的隐式高算出来，成环
         * —— 结果是标题被裁掉上半截（M18 抓图实录，见 shot_m18.qml 同段注释）。 */
        header: [
            Heading { level: 4; text: "布局与容器" },

            Caption {
                text: "QSkinLayout · QSkinSplitter · QSkinScrollArea · QSkinCard · QSkinAspectRatio · QSkinDivider"
                Layout.fillWidth: true
            },

            QSkinButton {
                text: "折叠侧栏"
                onClicked: {
                    layout.siderCollapsed = !layout.siderCollapsed
                    state.lastAction = layout.siderCollapsed ? "侧栏收起到 56" : "侧栏展开到 220"
                }
            },

            QSkinButton {
                text: "换主题（" + state.themeNames[state.themeIndex] + "）"
                onClicked: state.cycleTheme()
            }
        ]

        /* ── 侧栏 ──
         * 同 header：`siderHost` 本来就是 QSkinColumn（竖排），直接列子项。
         * 折叠到 56 时，这些按钮会被压成 56-2*12 = 32px 宽，文字 elide ——
         * 这正是"折叠"该有的样子（不是把内容挤出去）。 */
        sider: [
            Caption { text: "导航"; Layout.fillWidth: true },

            Repeater {
                model: ["概览", "任务", "文件", "设置"]

                delegate: QSkinButton {
                    required property string modelData
                    required property int index

                    Layout.fillWidth: true
                    text: modelData
                    variant: index === 1 ? "primary" : "default"
                    onClicked: state.lastAction = "点侧栏：" + modelData
                }
            }
        ]

        /* ── 内容：可拖的两栏 ── */
        QSkinSplitter {
            id: splitter

            anchors.fill: parent
            ratio: 0.46
            minSize: 120

            onResized: state.lastAction = "分栏比例 → " + splitter.ratio.toFixed(2)

            /* 左：可滚动的一堆文档内容 */
            first: QSkinScrollArea {
                id: scroller

                anchors.fill: parent
                contentHeight: doc.implicitHeight + Theme.space.lg * 2

                QSkinColumn {
                    id: doc

                    x: Theme.space.lg
                    y: Theme.space.lg
                    width: parent.width - Theme.space.lg * 2
                    gap: Theme.space.md

                    Heading { level: 4; text: "分隔线：四种形态" }

                    Caption { text: "无文字 —— 一整条通线，撑满可用宽度"; Layout.fillWidth: true }
                    QSkinDivider { Layout.fillWidth: true }

                    Caption { text: "居中带文字 —— 线在文字处断开，两侧留白相等"; Layout.fillWidth: true }
                    QSkinDivider {
                        Layout.fillWidth: true
                        text: "分区标题"
                    }

                    Caption { text: "靠左带文字 —— 左边只留一小截，其余全在右侧"; Layout.fillWidth: true }
                    QSkinDivider {
                        Layout.fillWidth: true
                        text: "第一节"
                        textAlign: "left"
                    }

                    Caption { text: "虚线 —— 与实线同一段代码，只是每段短了、之间有空隙"; Layout.fillWidth: true }
                    QSkinDivider {
                        Layout.fillWidth: true
                        dashed: true
                    }

                    Caption { text: "纵向 —— 夹在两个词之间，高度跟着这一行走"; Layout.fillWidth: true }

                    QSkinRow {
                        gap: Theme.space.md
                        align: "center"

                        Body { text: "已读" }
                        QSkinDivider {
                            orientation: "vertical"
                            text: ""
                        }
                        Body { text: "未读" }
                        QSkinDivider {
                            orientation: "vertical"
                        }
                        Body { text: "草稿（纵向分隔线高度默认 32）" }
                    }

                    QSkinDivider {
                        Layout.fillWidth: true
                        text: "下面是让这一栏真的需要滚动的内容"
                    }

                    Repeater {
                        model: 8

                        delegate: QSkinCard {
                            required property int index

                            Layout.fillWidth: true
                            variant: "filled"
                            contentPadding: Theme.space.md

                            title: "第 " + (index + 1) + " 段"
                            subtitle: "用来把滚动条逼出来"

                            Body {
                                Layout.fillWidth: true
                                text: "滚动区的内容比视口高时，右侧才出现滚动条；"
                                      + "内容比视口矮时它不该出现 —— 这两件事由同一个"
                                      + " contentHeight 与视口高的比较决定。"
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            /* 右：卡片 + 定比例封面 */
            second: QSkinScrollArea {
                anchors.fill: parent
                contentHeight: rightCol.implicitHeight + Theme.space.lg * 2

                QSkinColumn {
                    id: rightCol

                    x: Theme.space.lg
                    y: Theme.space.lg
                    width: parent.width - Theme.space.lg * 2
                    gap: Theme.space.md

                    QSkinCard {
                        Layout.fillWidth: true

                        title: "卡片"
                        subtitle: "头部 / 内容 / 尾部三段，分割线只在两段相邻时出现"

                        extra: QSkinRow {
                            gap: Theme.space.xs

                            QSkinButton {
                                text: "次要"
                                size: "sm"
                                onClicked: state.lastAction = "卡片右上角：次要"
                            }
                            QSkinButton {
                                text: "主要"
                                size: "sm"
                                variant: "primary"
                                onClicked: state.lastAction = "卡片右上角：主要"
                            }
                        }

                        Body {
                            Layout.fillWidth: true
                            text: "这张卡片没有 footer，所以内容与尾部之间**不该**有分割线；"
                                  + "头部与内容之间有一条。把 footer 加回来，第二条线才会出现。"
                            wrapMode: Text.WordWrap
                        }

                        footer: QSkinButton {
                            text: "我知道了"
                            onClicked: state.lastAction = "卡片底部按钮"
                        }
                    }

                    QSkinAspectRatio {
                        id: cover

                        Layout.fillWidth: true
                        ratio: 16 / 9

                        Rectangle {
                            anchors.fill: parent
                            color:        Theme.color.brandSubtle
                            radius:       Theme.radius.lg

                            /* 这里用 QSkinColumn 而不是裸 Column：裸 Column 里的子项
                             * 写 anchors 会被警告（Column 自己管 x/y），而
                             * QSkinColumn 内部是 ColumnLayout，子项用 Layout.alignment
                             * 居中才是正路。 */
                            QSkinColumn {
                                anchors.centerIn: parent
                                gap: Theme.space.xs

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "16 : 9"
                                    color: Theme.color.brand
                                    font.family: Theme.font.family
                                    font.pixelSize: Theme.font.lg
                                    font.weight: Theme.font.weightSemiBold
                                }

                                Caption {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "高 = 宽 ÷ 1.777…（拖动窗口宽度看它跟着变）"
                                }
                            }
                        }
                    }

                    QSkinCard {
                        Layout.fillWidth: true
                        variant: "plain"
                        separator: false

                        title: "plain 变体"
                        subtitle: "无底无边，只借它的内边距与结构"

                        Caption {
                            Layout.fillWidth: true
                            text: "层次用三档底色 / 描边表达，而不是阴影 —— "
                                  + "阴影需要 QtQuick.Effects，本项目全程没有引入它。"
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        /* ── 底栏：自证状态 ──
         * 同 header / sider：`footerHost` 已经是 QSkinRow，直接列子项。 */
        footer: [
            Caption {
                text: "theme=" + state.themeNames[state.themeIndex]
                      + "   sider=" + layout.currentSiderWidth + "px"
                      + "   split=" + splitter.ratio.toFixed(2)
                      + "   scrollY=" + Math.round(scroller.contentY)
                Layout.fillWidth: true
            },

            Caption { text: "最近动作：" + state.lastAction }
        ]
    }
}
