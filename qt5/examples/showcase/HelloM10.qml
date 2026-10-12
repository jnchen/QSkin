/****************************************************************************
 * QSkin · 示例 —— M10：导航与状态标识（Steps / Breadcrumb / Badge / Tag / Progress）
 *
 *   · QSkinProgress：线形（确定 / 语义色）、环形、不确定态
 *   · QSkinTag：七种语义变体、可关闭、胶囊、小尺寸
 *   · QSkinBadge：数字 / 封顶 99+ / 圆点 / 挂在按钮角上
 *   · QSkinBreadcrumb：短路径 / 长路径自动折叠 / 展开 / 自定义分隔符
 *   · QSkinSteps：横向（含描述）+ 纵向 + 状态覆盖（error）
 *   · 主题切换：Neutral / TDesign / Ant / Arco / shadcn
 *
 * ── 这个示例想证明的一件事 ────────────────────────────────────────────
 * M10 五个控件里有三个（Progress / Tag / Breadcrumb→label，Steps→label×2）
 * 复用现有插槽、零新增排版插槽。所以换主题时它们的文字排版会自动
 * 跟随 —— 切一下主题按钮就能看到：五套主题下这些文字的字号、字重、
 * 颜色全部同步变化，而这些控件源码里没有一行硬编码的字体设置。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0
import QSkin.Theme.AntDesign 1.0
import QSkin.Theme.ArcoDesign 1.0
import QSkin.Theme.Shadcn 1.0

QSkinWindow {
    id: win

    width: 920
    height: 780
    visible: true
    title: "QSkin · M10 — Steps / Breadcrumb / Badge / Tag / Progress"

    /* ── 页面 ── */
    QSkinColumn {
        id: page

        anchors.fill: parent
        padding: Theme.space.xl
        gap: Theme.space.lg

        /* ══════════════════ 头部 + 主题切换 ══════════════════ */
        QSkinRow {
            fill: true
            gap: Theme.space.sm

            QSkinColumn {
                gap: Theme.space.xs
                Heading { text: "M10 · 导航与状态标识" }
                Caption { text: "Steps / Breadcrumb / Badge / Tag / Progress — 五个控件，零新增排版插槽" }
            }

            Spacer { }

            QSkinButton { text: "Neutral"; size: "sm"; variant: "text"; onClicked: { Slots.reset(); Theme.reset() } }
            QSkinButton { text: "TDesign"; size: "sm"; variant: "text"; onClicked: TDesign.apply() }
            QSkinButton { text: "Ant";     size: "sm"; variant: "text"; onClicked: AntDesign.apply() }
            QSkinButton { text: "Arco";    size: "sm"; variant: "text"; onClicked: ArcoDesign.apply() }
            QSkinButton { text: "shadcn";  size: "sm"; variant: "text"; onClicked: Shadcn.apply() }
        }

        /* ══════════════════ 面包屑 ══════════════════ */
        QSkinColumn {
            gap: Theme.space.sm

            Heading { level: 3; text: "面包屑" }

            QSkinBreadcrumb {
                id: bcShort
                model: ["工作台", "项目列表", "QSkin 设计系统"]
            }

            /* 长路径 —— 自动折叠成「首页 / … / 父级 / 当前」，
             * 点省略号展开。首项与末两项永远保留。
             *
             * 注意：QSkinBreadcrumb 是"等宽于内容"的控件（width: implicitWidth），
             * 把按钮锚在它内部会和它的测量互相牵扯 —— 面包屑会被按钮挤扁。
             * 所以按钮放在外面，用 QSkinRow 并排。 */
            QSkinRow {
                gap: Theme.space.sm
                align: "center"

                QSkinBreadcrumb {
                    id: bcLong
                    model: ["首页", "组织架构", "研发中心", "前端团队", "组件库", "QSkin 契约层"]
                }

                QSkinButton {
                    text: bcLong.expanded ? "收起" : "展开"
                    size: "sm"
                    variant: "text"
                    onClicked: bcLong.expanded = !bcLong.expanded
                }
            }

            Caption {
                text: bcLong.expanded
                      ? "已展开：全部 " + bcLong.count + " 项可见（末项为当前位置，不可点）"
                      : "已折叠：保留首项 + 末 " + bcLong.keepLast + " 项，中间收进省略号"
            }
        }

        /* ══════════════════ 步骤条 ══════════════════ */
        QSkinColumn {
            gap: Theme.space.md

            Heading { level: 3; text: "步骤条 · 横向" }

            /* QSkinSteps 自己不做布局填充（基础层控件，等外部给宽度），
             * 想让它横贯整行就包一层 fill 的 QSkinRow。 */
            QSkinRow {
                id: stepsHRow
                fill: true

                QSkinSteps {
                    id: stepsH
                    width: stepsHRow.width
                    currentIndex: 1
                    model: [
                        { title: "填写资料", description: "企业基本信息" },
                        { title: "资格审核", description: "1–2 个工作日" },
                        { title: "签署协议", description: "线上电子签" },
                        { title: "完成开通", description: "" }
                    ]

                    /* 上一步 / 下一步 —— 靠右键按钮推进 currentIndex */
                    QSkinRow {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        gap: Theme.space.sm

                        QSkinButton {
                            text: "上一步"; size: "sm"
                            enabled: stepsH.currentIndex > 0
                            onClicked: stepsH.currentIndex--
                        }
                        QSkinButton {
                            text: "下一步"; size: "sm"; variant: "primary"
                            enabled: stepsH.currentIndex < stepsH.count
                            onClicked: stepsH.currentIndex++
                        }
                    }
                }
            }

            Caption {
                text: "当前第 " + Math.min(stepsH.currentIndex + 1, stepsH.count)
                      + " 步 / 共 " + stepsH.count + " 步"
                      + (stepsH.currentIndex >= stepsH.count ? "（全部完成，圆圈全变打勾）" : "")
            }
        }

        /* ══════════════════ 进度 ══════════════════ */
        QSkinColumn {
            gap: Theme.space.md

            Heading { level: 3; text: "进度" }

            QSkinRow {
                gap: Theme.space.xl
                align: "center"

                /* 线形 · 确定态 · 语义色 */
                QSkinColumn {
                    gap: Theme.space.sm
                    width: 320

                    QSkinProgress { id: pUp;    width: 320; progress: 0.62 }
                    QSkinProgress { id: pOk;    width: 320; progress: 1.0;  status: "success" }
                    QSkinProgress { id: pWarn;  width: 320; progress: 0.86; status: "warning" }
                    QSkinProgress { id: pErr;   width: 320; progress: 0.24; status: "danger" }
                    QSkinProgress { id: pIndet; width: 320; indeterminate: true; showText: false }
                }

                /* 环形 · 确定态 */
                QSkinProgress {
                    id: pRing
                    variant: "circle"
                    circleSize: 108
                    thickness: 10
                    progress: 0.78
                    showText: false        /* 环心文字交给外层摆，避免与环重叠 */
                }

                QSkinProgress {
                    id: pRingOk
                    variant: "circle"
                    circleSize: 108
                    thickness: 10
                    progress: 1.0
                    status: "success"
                    showText: false
                }
            }

            Caption { text: "拖动下面的滑块改第一个进度条的值（确定态平滑推进，不确定态循环流动）" }

            QSkinSlider {
                width: 320
                from: 0; to: 100; value: 62
                onMoved: function(v) { pUp.progress = v / 100 }
            }
        }

        /* ══════════════════ 标签 + 徽标 ══════════════════ */
        QSkinRow {
            gap: Theme.space.xxl
            align: "start"

            QSkinColumn {
                gap: Theme.space.sm
                Heading { level: 3; text: "标签" }

                QSkinRow {
                    gap: Theme.space.sm
                    QSkinTag { text: "默认";   variant: "default" }
                    QSkinTag { text: "进行中"; variant: "primary" }
                    QSkinTag { text: "已上线"; variant: "success" }
                    QSkinTag { text: "待发布"; variant: "warning" }
                    QSkinTag { text: "已废弃"; variant: "danger" }
                }

                QSkinRow {
                    gap: Theme.space.sm
                    QSkinTag { text: "可移除"; variant: "primary"; closable: true
                             onClicked: console.log("tag clicked") }
                    QSkinTag { text: "胶囊"; variant: "success"; pill: true }
                    QSkinTag { text: "小号"; size: "sm" }
                    QSkinTag { text: "禁用"; enabled: false }
                }
            }

            QSkinColumn {
                gap: Theme.space.sm
                Heading { level: 3; text: "徽标" }

                /* 第一行：挂在按钮角上的徽标 */
                Item {
                    width:  badgeRow.width
                    height: badgeRow.height + 16
                    clip: false

                    QSkinRow {
                        id: badgeRow
                        anchors.bottom: parent.bottom
                        gap: Theme.space.xl
                        align: "center"

                        QSkinButton { id: btnInbox; text: "收件箱" }
                        QSkinButton { id: btnBell;  text: "通知" }
                        QSkinButton { id: btnDot;   text: "有更新" }
                    }

                    /* 徽标贴到各自按钮的右上角外侧（溢出到按钮之外）。
                     * 注意：徽标不能是 QSkinRow 的直接子项 —— Layout 会接管
                     * 子项的 x/y，anchorTo 算好的坐标会被覆盖。所以这里
                     * 让它们当外层 Item 的子项。 */
                    QSkinBadge { anchorTo: btnInbox; value: 5 }
                    QSkinBadge { anchorTo: btnBell;  value: 128; max: 99 }
                    QSkinBadge { anchorTo: btnDot;   dot: true; status: "info" }
                }

                /* 第二行：独立形态（不挂载） */
                QSkinRow {
                    gap: Theme.space.md
                    align: "center"

                    QSkinBadge { value: 12 }
                    QSkinBadge { value: 1; status: "success" }
                    QSkinBadge { dot: true; dotSize: 10; status: "warning" }
                    QSkinBadge { value: 0; showZero: true }
                }
            }
        }

        /* ══════════════════ 步骤条 · 纵向 ══════════════════ */
        QSkinColumn {
            gap: Theme.space.md

            Heading { level: 3; text: "步骤条 · 纵向" }

            QSkinSteps {
                id: stepsV
                variant: "vertical"
                currentIndex: 1
                descMaxWidth: 320
                model: [
                    { title: "提交申请",     description: "已提交，等待系统分配审核员" },
                    { title: "人工审核",     description: "审核中，预计 1 个工作日内完成" },
                    { title: "结果通知",     description: "审核完成后通过邮件通知" }
                ]
            }
        }
    }
}
