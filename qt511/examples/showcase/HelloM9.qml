/****************************************************************************
 * QSkin · 示例 —— M9：Switch / Slider / InputNumber + ButtonBar self-width 修复
 *
 *   · QSkinSwitch：三态演示（默认/勾选/禁用）
 *   · QSkinSlider：连续（值实时回显）、步进（stepSize 10）、禁用
 *   · QSkinInputNumber：基本 / 小数（decimals 2）；步进器点击、
 *     键盘输入、提交时钳制到 [min, max]
 *   · QSkinForm + InputNumber / Slider 演示取值契约 + 实时重校
 *   · ButtonBar 在 Form 操作区和抽屉底部都用上，证明 M3 的
 *  self-width 死锁已修（hug 模式不再误堆叠）
 *   · Drawer 用真实设置项（开关 + 滑块 + 数字输入）填满全高面板
 *   · 主题切换：Neutral / TDesign / Ant / Arco / shadcn
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

    width: 880
    height: 720
    visible: true
    title: "QSkin · M9 — Switch / Slider / InputNumber"

    /* ── 页面 ── */
    QSkinColumn {
        id: page

        anchors.fill: parent
        padding: Theme.space.xl
        gap: Theme.space.lg

        /* ── 头部 ── */
        QSkinRow {
            fill: true
            gap: Theme.space.sm

            QSkinColumn {
                gap: Theme.space.xs
                Heading { text: "M9 · 取值控件 + ButtonBar 修复" }
                Caption { text: "Switch / Slider / InputNumber + 主题切换 + 抽屉里的真实设置" }
            }

            Spacer { }

            QSkinButton { text: "Neutral"; size: "sm"; variant: "text"; onClicked: { Slots.reset(); Theme.reset() } }
            QSkinButton { text: "TDesign"; size: "sm"; variant: "text"; onClicked: TDesign.apply() }
            QSkinButton { text: "Ant";     size: "sm"; variant: "text"; onClicked: AntDesign.apply() }
            QSkinButton { text: "Arco";    size: "sm"; variant: "text"; onClicked: ArcoDesign.apply() }
            QSkinButton { text: "shadcn";  size: "sm"; variant: "text"; onClicked: Shadcn.apply() }
        }

        /* ── Switch 三态 ── */
        QSkinColumn {
            gap: Theme.space.md
            Heading { level: 3; text: "开关" }
            QSkinRow { gap: Theme.space.xl
                QSkinSwitch { id: sw1; text: "默认关" }
                QSkinSwitch { id: sw2; text: "默认开"; checked: true }
                QSkinSwitch { id: sw3; text: "禁用"; enabled: false }
            }
        }

        /* ── Slider 三态 ── */
        QSkinColumn {
            gap: Theme.space.md
            Heading { level: 3; text: "滑块" }

            QSkinRow {
                fill: true
                gap: Theme.space.lg
                align: "center"

                QSkinSlider {
                    id: sld1
                    width: 240
                    from: 0; to: 100; value: 30
                    onMoved: function(v) { sld1Lbl.text = "连续 " + Math.round(v) }
                }
                Caption { id: sld1Lbl; text: "连续 30" }
            }

            QSkinRow {
                fill: true
                gap: Theme.space.lg
                align: "center"

                QSkinSlider {
                    id: sld2
                    width: 240
                    from: 0; to: 100; stepSize: 10; value: 40
                    onMoved: function(v) { sld2Lbl.text = "步进 10 → " + Math.round(v) }
                }
                Caption { id: sld2Lbl; text: "步进 10 → 40" }
            }

            QSkinRow {
                fill: true
                gap: Theme.space.lg
                align: "center"

                QSkinSlider {
                    width: 240
                    from: 0; to: 100; value: 50
                    enabled: false
                }
                Caption { text: "禁用" }
            }
        }

        /* ── InputNumber 三态 ── */
        QSkinColumn {
            gap: Theme.space.md
            Heading { level: 3; text: "数字输入" }

            QSkinRow {
                fill: true
                gap: Theme.space.lg
                align: "center"

                QSkinInputNumber { id: n1; min: 0; max: 99; step: 1; value: 1 }
                Caption { text: "整数 0–99，步长 1" }
            }

            QSkinRow {
                fill: true
                gap: Theme.space.lg
                align: "center"

                QSkinInputNumber {
                    id: n2
                    min: 0.00; max: 1000.00; step: 0.5; decimals: 2
                    value: 99.50
                }
                Caption { text: "小数 2 位，步长 0.5" }
            }

            QSkinRow {
                fill: true
                gap: Theme.space.lg
                align: "center"

                QSkinInputNumber { min: 0; max: 10; value: 0; enabled: false }
                Caption { text: "禁用" }
            }
        }

        /* ── Form + Slider / InputNumber（实时重校） ── */
        QSkinForm {
            id: form

            fill: true
            gap: Theme.space.md

            QSkinColumn {
                gap: Theme.space.md
                Heading { level: 3; text: "表单校验" }

                QSkinRow {
                    fill: true
                    gap: Theme.space.xl
                    align: "center"

                    QSkinFormItem {
                        id: qtyField
                        label: "数量"; required: true
                        rules: [
                            { required: true, message: "请填写数量" },
                            { test: function(v) { return v >= 5 }, message: "至少 5 件" },
                            { test: function(v) { return v <= 99 }, message: "最多 99 件" }
                        ]
                        QSkinInputNumber { min: 1; max: 99; value: 1 }
                    }

                    QSkinFormItem {
                        id: rateField
                        label: "折扣"
                        rules: [ { test: function(v) { return v <= 80 }, message: "不能超过 80%" } ]
                        QSkinSlider { width: 200; from: 0; to: 100; value: 30 }
                    }
                }

                /* ButtonBar 撑满 + 右对齐 —— M9.x 复测确认 fill:true 在
                 * Qt 6.8.x 下工作正常（此前 M9 的"架构性冲突"结论是探针
                 * 假象：动态创建的 Window 里 anchors.fill:parent 不解析，
                 * 导致列宽基准失真）。这里回归 ButtonBar 的规范用法。 */
                ButtonBar {
                    fill: true
                    align: "end"
                    gap: Theme.space.sm
                    dangerIndexes: [1]

                    QSkinButton { text: "清空错误"; variant: "ghost"; onClicked: form.clearAllErrors() }
                    QSkinButton { text: "打开设置抽屉"; variant: "ghost"; onClicked: settingsDrawer.open() }
                    QSkinButton {
                        text: "提交校验"
                        onClicked: {
                            if (form.validateAll()) toast.show("校验通过", "success")
                            else                    toast.show("请检查错误", "danger")
                        }
                    }
                }
            }
        }
    }

    /* ── 浮层层 ── */
    QSkinToast { id: toast; z: 1000 }

    /* ── 设置抽屉：填满全高面板的真实内容 ── */
    QSkinDrawer {
        id: settingsDrawer
        edge: "right"
        panelWidth: 360
        title: "偏好设置"

        QSkinColumn {
            fill: true
            gap: Theme.space.lg

            QSkinColumn {
                fill: true
                gap: Theme.space.md

                Body { text: "通知" }
                QSkinSwitch { text: "接收推送通知"; checked: true }
                QSkinSwitch { text: "邮件订阅" }
                QSkinSwitch { text: "桌面弹窗（不可用）"; enabled: false }
            }

            QSkinColumn {
                fill: true
                gap: Theme.space.md

                Body { text: "外观" }
                QSkinSlider {
                    width: parent.width - Theme.space.xl * 2
                    from: 0; to: 100; value: 60
                }
                Caption { text: "界面密度（向左更紧凑，向右更舒展）" }
            }

            QSkinColumn {
                fill: true
                gap: Theme.space.md

                Body { text: "自动保存" }
                QSkinInputNumber { min: 1; max: 60; value: 5 }
                Caption { text: "每隔多少分钟保存一次草稿" }
            }

            QSkinRow {
                fill: true
                gap: Theme.space.md

                Spacer { }

                QSkinButton { text: "恢复默认"; variant: "ghost"; onClicked: toast.show("已恢复默认", "info") }
                QSkinButton { text: "保存设置"; onClicked: { toast.show("已保存", "success"); settingsDrawer.close() } }
            }
        }
    }
}