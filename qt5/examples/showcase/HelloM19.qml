/****************************************************************************
 * QSkin · 示例 —— M19：数据展示类
 *
 * 六个控件（List / Avatar / AvatarGroup / Empty / Skeleton / Spin）
 * 在这一个屏幕里全部用上，而且**互相嵌套** —— 单独摆六个样例看不出
 * "它们能不能一起工作"，而"一起工作"恰恰是这一批的全部意义：
 *
 *   · List 的每一行里放一个 Avatar；
 *   · List 加载中的时候，它**同时**用 Skeleton（每一行）和 Spin（标题栏角上）
 *     —— 这正是这两个控件的分工界面：骨架画"已知的结构"，转圈画"未知的等待"；
 *   · List 一条数据都没有的时候，空态由 Empty 承担，而 Empty 的
 *     主操作按钮把用户带出去（"新建"），不是干等着；
 *   · AvatarGroup 处理"人多到一个头像放不下"的情形，折成 "+N"。
 *
 * ── 这一屏的结构就是它的测试用例 ──────────────────────────────────────
 *
 *   QSkinWindow
 *   └─ QSkinColumn                      页
 *      ├─ QSkinRow                     标题行（标题 + 主题/场景 + 一个 Spin）
 *      ├─ QSkinRow                     主区，左宽右窄
 *      │  ├─ QSkinCard「团队动态」      ← QSkinList（头部放 Spin、尾部放"加载更多"）
 *      │  └─ QSkinColumn
 *      │     ├─ QSkinCard「待办」        ← QSkinEmpty（带主操作）
 *      │     └─ QSkinCard「成员」        ← QSkinAvatarGroup + 四种单个 QSkinAvatar
 *      ├─ QSkinRow                     骨架屏 / 指示器
 *      │  ├─ QSkinCard「加载中」         ← QSkinSkeleton 包住真实内容
 *      │  └─ QSkinCard「加载指示器」      ← 三档尺寸 + 点阵变体
 *      └─ QSkinColumn id: selfTest     自证行（见下）
 *
 * ── 想看的七件事 ──────────────────────────────────────────────────────
 *   ① 列表行的三档底色：隔行（stripe）/ 悬停 / 按下 —— 三档必须**深浅分明**，
 *      复用同一档会让"悬停在隔行条目上"看不出任何变化
 *   ② 加载中：**骨架屏与"加载更多"不能同时在** —— 那会读成
 *      "一边在加载，一边还有下一页"
 *   ③ 空态：列表一条都没有时是 Empty 里的插图 + 文案 + 按钮，
 *      不是一行光秃秃的"暂无数据"
 *   ④ 头像的内容优先级：图片 > 图标 > 文字。四种头像并排，
 *      应当依次是"有图的/只有文字的/带描边的/方形的"
 *   ⑤ 头像组：8 个人、最多画 4 个 → 画面上是 4 个 + 一个 "+4"，
 *      五个圆**等距叠放**（间距 = step），不是散开或者压成一片
 *   ⑥ 骨架屏：图片在左、文字在右，三行文字**最后一行更短**
 *      （全等长会读成"表格"而不是"一段话"）
 *   ⑦ 加载指示器：三档尺寸的线宽不一样（16px / 24px / 32px），
 *      点阵变体是**四个点**而不是三个
 *
 * ── 为什么底部要有一行"自言自语" ─────────────────────────────────────
 * 抓图与人工核验都需要一个**不依赖眼睛判断**的锚点：这一行把主题、
 * 列表状态、头像叠放步长、骨架落位、指示器尺寸直接写出来。图里看到的
 * 和它写的对不上，就是渲染出了问题（M17 起沿用这个做法）。
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
    height: 1040
    visible: true
    title: "QSkin · M19 — 数据展示类"

    /* 起始状态钉死，不留悬念（M17 惯例）。这几行必须写在 onCompleted 里
     * —— 对象声明体中不允许出现裸表达式语句。 */

    /* ── 抓图参数（示例屏默认走 tdesign/base）── */
    readonly property var args: Qt.application.arguments
    function argOf(key, dflt) {
        for (var i = 0; i < win.args.length; ++i) {
            var a = win.args[i]
            if (a.indexOf(key + "=") === 0) return a.substring(key.length + 1)
        }
        return dflt
    }
    readonly property string themeName: win.argOf("theme", "tdesign")
    readonly property string scene:     win.argOf("scene", "base")
    readonly property string mode:      win.argOf("mode", "light")

    function applyTheme() {
        Theme.mode = win.mode
        switch (win.themeName) {
            case "ant":    AntDesign.apply();   break
            case "arco":   ArcoDesign.apply();  break
            case "shadcn": Shadcn.apply();      break
            default:       TDesign.apply();     break
        }
    }

    /* ── 场景开关 ──
     * 全部写成绑定，不做命令式赋值 —— 少一个时序变量（M18 教训）。 */
    readonly property bool scEmpty:    win.scene === "list-empty"
    readonly property bool scLoading:  win.scene === "list-loading"
    readonly property bool scStriped:  win.scene === "list-striped"
    readonly property bool scNoMore:   win.scene === "list-nomore"
    readonly property bool scSkeleton: win.scene === "skeleton"
    readonly property bool scStop:     win.scene === "stopped"

    readonly property var members: win.scEmpty ? [] : ["张伟", "李娜", "王芳", "刘洋", "陈晨", "赵磊", "孙悦"]
    readonly property var team:    ["张伟", "李娜", "王芳", "刘洋", "陈晨", "赵磊", "孙悦", "周航"]

    /* ══════════════════ 页面 ══════════════════ */

    Rectangle {
        anchors.fill: parent
        color: Theme.color.bg
    }

    QSkinColumn {
        id: page

        anchors.fill: parent
        padding: Theme.space.xl
        gap: Theme.space.lg

        /* ── 标题行 ── */
        QSkinRow {
            Layout.fillWidth: true
            gap: Theme.space.md

            Heading { level: 3; text: "数据展示类" }

            Caption {
                Layout.fillWidth: true
                text: "QSkinList · QSkinAvatar · QSkinAvatarGroup · QSkinEmpty · QSkinSkeleton · QSkinSpin"
            }

            /* 标题角上这个小转圈是**独立模式**的 Spin（没有内容可包），
             * 尺寸走 sm 档 16px —— 它的线宽必须是 2px，
             * 与 32px 那个的 3px 并排看能看出差别。 */
            QSkinSpin {
                id: spinTitle
                size: "sm"
                spinning: !win.scStop
                tip: "同步中"
            }

            Caption { text: win.themeName + " / " + win.mode + " / " + win.scene }
        }

        /* ══════════ 主区：左宽右窄 ══════════ */
        QSkinRow {
            Layout.fillWidth: true
            Layout.fillHeight: true
            gap: Theme.space.lg

            /* ── 左：团队动态（List）── */
            QSkinCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 3
                Layout.fillHeight: true
                title: "团队动态"
                subtitle: "头部与尾部由 List 自己的 header / footer 提供"

                extra: QSkinRow {
                    gap: Theme.space.sm

                    Caption { text: "共 " + list.count + " 条" }
                }

                QSkinList {
                    id: list

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    model:           win.members
                    stripe:          win.scStriped
                    loading:         win.scLoading
                    loadingText:     "正在拉取动态…"
                    loadMore:        !win.scLoading && !win.scEmpty && !win.scNoMore
                    noMore:          win.scNoMore
                    emptyText:       "还没有动态"
                    emptyImage:      ""
                    clickable:       true

                    delegate: memberRow

                    header: QSkinRow {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        Body { text: "最近更新" }
                        Caption {
                            Layout.fillWidth: true
                            text: list.loading ? "加载中" : "已同步"
                        }
                    }

                    footer: QSkinRow {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        Caption {
                            Layout.fillWidth: true
                            text: list.noMore ? "没有更多了"
                                              : (list.loadMore ? "还有下一页" : "—")
                        }
                        QSkinButton {
                            text: list.loadMoreText
                            size: "sm"
                            visible: list.loadMore
                        }
                    }
                }
            }

            /* ── 右：空态 + 成员 ── */
            QSkinColumn {
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                Layout.fillHeight: true
                gap: Theme.space.lg

                QSkinCard {
                    Layout.fillWidth: true
                    title: "待办事项"

                    QSkinEmpty {
                        id: emptyCard

                        Layout.fillWidth: true
                        size: "sm"
                        title: "今天没有待办"
                        description: "所有任务都完成了。可以新建一条，或者去动态里看看别人在做什么。"
                        textMaxWidth: 320

                        action: QSkinButton {
                            text: "新建任务"
                            size: "sm"
                            variant: "primary"
                        }
                    }
                }

                QSkinCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "成员"
                    subtitle: "8 人，最多画 4 个 —— 折成 +4"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.md

                        QSkinAvatarGroup {
                            id: team8

                            size: 36
                            overlapRatio: 0.3
                            ringWidth: 2
                            max: 4
                            model: win.team
                        }

                        QSkinRow {
                            Layout.fillWidth: true
                            gap: Theme.space.md

                            /* 四种头像并排：依次是「只有文字」「带描边」
                             * 「更小一档」「方形」。 */
                            QSkinAvatar {
                                id: avText
                                size: "md"
                                text: "张"
                            }

                            QSkinAvatar {
                                id: avRing
                                size: "md"
                                text: "李"
                                ringWidth: 2
                                ringColor: Theme.color.brand
                                backgroundColor: Theme.color.brandSubtle
                                foregroundColor: Theme.color.brand
                            }

                            QSkinAvatar {
                                id: avSm
                                size: "sm"
                                text: "王"
                            }

                            QSkinAvatar {
                                id: avSquare
                                size: "lg"
                                shape: "square"
                                text: "刘"
                            }
                        }

                        Caption {
                            id: avInfo
                            Layout.fillWidth: true
                            text: "px=" + avText.px + "/" + avSm.px + "/" + avSquare.px
                                  + "  r=" + avSquare.cornerRadius
                                  + "  内容=" + (avText.showText ? "文字" : "?")
                        }
                    }
                }
            }
        }

        /* ══════════ 骨架屏 / 指示器 ══════════ */
        QSkinRow {
            Layout.fillWidth: true
            gap: Theme.space.lg

            QSkinCard {
                Layout.fillWidth: true
                title: "加载中（骨架屏）"
                subtitle: "骨架画「已知的结构」，转圈画「未知的等待」"

                QSkinSkeleton {
                    id: skel

                    Layout.fillWidth: true
                    loading: win.scSkeleton
                    delay: 0
                    animation: "wave"
                    image: true
                    imagePosition: "left"
                    imageSize: 72
                    avatar: false
                    title: true
                    titleWidth: 0.30
                    paragraph: true
                    rows: 3
                    rowWidth: 1.0
                    lastRowWidth: 0.61
                    baseWidth: 360

                    /* 内容一直在对象树里，只关 visible —— 骨架结束时
                     * 不用重建，滚动位置 / 展开态 / 半截输入都留着。 */
                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.xs

                        Heading { level: 6; text: "季度回顾" }
                        Body {
                            Layout.fillWidth: true
                            text: "三行文字，最后一行更短 —— 全等长会读成表格。"
                            wrapMode: Text.WordWrap
                        }
                        Caption { text: "改于 10 分钟前" }
                    }
                }
            }

            QSkinCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                title: "加载指示器"
                subtitle: "三档尺寸 + 点阵变体"

                QSkinRow {
                    Layout.fillWidth: true
                    gap: Theme.space.xl

                    QSkinSpin { id: spinSm; size: "sm"; spinning: !win.scStop }
                    QSkinSpin { id: spinMd; size: "md"; spinning: !win.scStop }
                    QSkinSpin { id: spinLg; size: "lg"; spinning: !win.scStop }
                    QSkinSpin {
                        id: spinDots
                        variant: "dots"
                        size: "lg"
                        spinning: !win.scStop
                        color: Theme.color.success
                    }

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: 2

                        Body { text: win.scStop ? "已停下" : "同步中…" }
                        Caption {
                            text: "环 " + spinSm.strokeWidth + "/" + spinMd.strokeWidth
                                  + "/" + spinLg.strokeWidth + "px"
                                  + "  点阵 " + spinDots.strokeWidth + "px"
                        }
                    }
                }
            }
        }

        /* ══════════ 自证行 ══════════
         * 这三行是这张图唯一"可以被机器读"的部分。核验脚本先从图里读出它，
         * 再拿它去和像素比对 —— 图上写的与图上画的对不上，就是渲染出了问题。 */
        QSkinColumn {
            id: selfTest

            Layout.fillWidth: true
            gap: 2

            Caption {
                Layout.fillWidth: true
                text: "theme=" + win.themeName + "  mode=" + win.mode + "  scene=" + win.scene
                      + "    list: n=" + list.count + " split=" + list.splitActive
                      + " empty=" + list.hasEmptyState + " status=" + list.hasStatusRow
                      + " stripe=" + list.stripe
            }

            Caption {
                Layout.fillWidth: true
                text: "avatar: group n=" + team8.count + " vis=" + team8.visibleCount
                      + " ovf=" + team8.overflowCount + " slot=" + team8.slotCount
                      + " px=" + team8.px + " overlap=" + team8.overlap + " step=" + team8.step
                      + " W=" + team8.implicitWidth
                      + "   |   empty: k=" + emptyCard._k + " iw=" + emptyCard._iw
                      + " ih=" + emptyCard._ih + " act=" + emptyCard.hasAction
            }

            Caption {
                Layout.fillWidth: true
                text: "skeleton: load=" + skel.loading + " active=" + skel.active
                      + " imgRow=" + skel._imgRow + " txtRow=" + skel._txtRow
                      + " imgSpan=" + skel._imgSpan + " txtSpan=" + skel._txtSpan
                      + "   |   spin: sm=" + spinSm.indicatorSize + " md=" + spinMd.indicatorSize
                      + " lg=" + spinLg.indicatorSize + " dots=" + spinDots.indicatorSize
                      + " spin=" + spinMd.spinning
            }
        }
    }

    /* ══════════════════ 列表行 ══════════════════
     *
     * delegate 是个 inline Component：QSkinList 走 Loader.onLoaded 往里注入
     * modelData / index，所以这两个属性**必须声明**（不声明的话每次加载
     * 都会打一条运行期警告，而警告不会让任何测试变红）。 */
    Component {
        id: memberRow

        QSkinRow {
            id: rowItem

            property var modelData
            property int index

            gap: Theme.space.md

            QSkinAvatar {
                size: "sm"
                shape: "circle"
                text: String(rowItem.modelData).charAt(0)
            }

            QSkinColumn {
                Layout.fillWidth: true
                gap: 2

                Body { text: String(rowItem.modelData) + " 更新了「接口文档」" }
                Caption { text: (rowItem.index + 1) * 7 + " 分钟前" }
            }

            Caption { text: "#" + (rowItem.index + 1) }
        }
    }

    Component.onCompleted: function() { win.applyTheme() }
}
