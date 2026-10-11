/****************************************************************************
 * QSkin · 示例 —— M11：浮层选择类（DatePicker / TimePicker）
 *
 *   · QSkinDatePicker：基础日期选择、自定义显示格式、范围限制、
 *     带默认值 / 清空、中文格式
 *   · QSkinTimePicker：24 小时制、12 小时制、带秒、15 分钟一档、
 *     工作时间范围限制
 *   · 主题切换：Neutral / TDesign / Ant / Arco / shadcn
 *
 * ── 这个示例想证明的一件事 ────────────────────────────────────────────
 * 日期与时间在传统实现里是两个完全独立的"重控件"，各自带一整套
 * 面板、列表、滚动逻辑。但在 QSkin 里它们只是**同一组插槽的两种内容**：
 *
 *     输入框底板   → inputBackground（与 QSkinInput / QSkinSelect 共用）
 *     弹出面板外壳 → selectOverlay   （与 QSkinSelect 共用）
 *     所有文字     → label           （与按钮/页签/面包屑/进度条共用）
 *
 * 零新增插槽。切一下主题就能看到：日历格子的字号字重、时间列的字号
 * 字重、输入框的边框圆角、面板的底色阴影，全部与页面其它控件同步变化 ——
 * 而这两个控件的源码里没有一行硬编码的颜色和字体。
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

    width: 960
    height: 820
    visible: true
    title: "QSkin · M11 — DatePicker / TimePicker"

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
                Heading { text: "M11 · 浮层选择类" }
                Caption { text: "DatePicker / TimePicker — 两个重控件，零新增插槽" }
            }

            Spacer { }

            QSkinButton { text: "Neutral"; size: "sm"; variant: "text"; onClicked: { Slots.reset(); Theme.reset() } }
            QSkinButton { text: "TDesign"; size: "sm"; variant: "text"; onClicked: TDesign.apply() }
            QSkinButton { text: "Ant";     size: "sm"; variant: "text"; onClicked: AntDesign.apply() }
            QSkinButton { text: "Arco";    size: "sm"; variant: "text"; onClicked: ArcoDesign.apply() }
            QSkinButton { text: "shadcn";  size: "sm"; variant: "text"; onClicked: Shadcn.apply() }
        }

        /* ══════════════════ 日期选择 ══════════════════ */
        QSkinColumn {
            gap: Theme.space.md

            Heading { level: 3; text: "日期选择" }

            QSkinRow {
                gap: Theme.space.lg
                align: "top"

                /* 基础：无默认值，显示占位符，面板初始对齐到今天 */
                QSkinColumn {
                    gap: Theme.space.xs

                    QSkinDatePicker { id: dpBasic; width: 200 }
                    Caption {
                        text: dpBasic.value
                              ? "已选：" + DateUtil.format(dpBasic.value)
                              : "未选择（点开面板看今天）"
                    }
                }

                /* 带默认值 + 自定义显示格式 */
                QSkinColumn {
                    gap: Theme.space.xs

                    QSkinDatePicker {
                        id: dpFmt
                        width: 200
                        value: DateUtil.make(2026, 9, 9)
                        displayFormat: "YYYY/MM/DD"
                    }
                    Caption {
                        text: "displayFormat = \"YYYY/MM/DD\""
                    }
                }

                /* 中文格式 */
                QSkinColumn {
                    gap: Theme.space.xs

                    QSkinDatePicker {
                        id: dpCn
                        width: 200
                        value: DateUtil.today()
                        displayFormat: "YYYY年MM月DD日"
                    }
                    Caption { text: "displayFormat = \"YYYY年MM月DD日\"" }
                }
            }

            /* 范围限制：面板里越界的格子灰掉且不可点 */
            QSkinColumn {
                gap: Theme.space.xs

                QSkinRow {
                    gap: Theme.space.md
                    align: "center"

                    QSkinDatePicker {
                        id: dpRange
                        width: 200
                        minimumDate: DateUtil.make(2026, 9, 10)
                        maximumDate: DateUtil.make(2026, 9, 20)
                        value: DateUtil.make(2026, 9, 15)
                    }

                    QSkinButton {
                        text: "清空"
                        size: "sm"
                        variant: "text"
                        onClicked: { dpRange.value = null; dpBasic.value = null }
                    }

                    QSkinButton {
                        text: "设为今天"
                        size: "sm"
                        variant: "text"
                        onClicked: dpRange.value = DateUtil.today()
                    }

                    Caption { text: "限制在 2026-09-10 ~ 2026-09-20（闭区间）" }
                }
            }
        }

        /* ══════════════════ 时间选择 ══════════════════ */
        QSkinColumn {
            gap: Theme.space.md

            Heading { level: 3; text: "时间选择" }

            QSkinRow {
                gap: Theme.space.lg
                align: "top"

                /* 24 小时制 */
                QSkinColumn {
                    gap: Theme.space.xs

                    QSkinTimePicker {
                        id: tp24
                        width: 200
                        value: DateUtil.makeTime(13, 45)
                    }
                    Caption { text: "24 小时制（HH:mm）" }
                }

                /* 12 小时制 */
                QSkinColumn {
                    gap: Theme.space.xs

                    QSkinTimePicker {
                        id: tp12
                        width: 200
                        value: DateUtil.makeTime(15, 30)
                        displayFormat: "hh:mm A"
                    }
                    Caption { text: "12 小时制（hh:mm A）" }
                }

                /* 带秒 */
                QSkinColumn {
                    gap: Theme.space.xs

                    QSkinTimePicker {
                        id: tpSec
                        width: 200
                        value: DateUtil.makeTime(9, 5, 30)
                        showSeconds: true
                        displayFormat: "HH:mm:ss"
                    }
                    Caption { text: "showSeconds = true（面板多一列，自动变宽）" }
                }
            }

            /* 档位 + 范围 */
            QSkinRow {
                gap: Theme.space.lg
                align: "center"

                QSkinTimePicker {
                    id: tpStep
                    width: 200
                    value: DateUtil.makeTime(10, 30)
                    minuteStep: 15
                }

                QSkinTimePicker {
                    id: tpWork
                    width: 200
                    value: DateUtil.makeTime(10, 0)
                    minimumTime: DateUtil.makeTime(9, 0)
                    maximumTime: DateUtil.makeTime(17, 0)
                }

                Caption {
                    text: "左：15 分钟一档（00/15/30/45）　"
                        + "右：限制 09:00 ~ 17:00（越界赋值会被钳制）"
                }
            }
        }

        /* ══════════════════ 说明 ══════════════════ */
        QSkinColumn {
            gap: Theme.space.xs

            Caption {
                text: "· 日期面板固定 6×7 = 42 格（不同月份行数一致，翻月时面板高度不跳）"
            }
            Caption {
                text: "· 日期面板里非本月的格子灰显但可点，点了会跳到那个月"
            }
            Caption {
                text: "· 时间面板的三列是独立滚动的列表；上下键换档，回车 / 确定 收面板"
            }
            Caption {
                text: "· 两个控件赋越界的值都会就地钳制到 [min, max]，不会留一个越界状态"
            }
            Caption {
                text: "· 全部文字走 label 插槽 —— 切主题看字号字重如何一起变"
            }
        }
    }
}
