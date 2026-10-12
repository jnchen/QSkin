/****************************************************************************
 * QSkin · 示例 —— M20：表单选择类
 *
 * 八个控件（Radio / RadioGroup / Toggle / ToggleGroup / Textarea / Label /
 * Rate / InputOTP）在这一屏里全部用上，而且**互相嵌套**。单独摆八个样例
 * 看不出"它们能不能一起工作"，而"一起工作"正是这一批的全部意义：
 *
 *   · 每一组选择都由 QSkinLabel 起头 —— 必填星标是 Shape 画的，不是字形；
 *   · Radio 与 Toggle 分别挂到 RadioGroup / ToggleGroup 上，值由**组**
 *     统一保管：宿主改组的 value，成员自己会动（M20 修掉的那个缺陷）；
 *   · 必填文本域在"内容超长"时截断，计数器跟着变 —— 计数器与截断是
 *     同一件事的两面，分开放就会各说各话；
 *   · 验证码用**固定分隔符方框**排版，所以"第 i 格中心在哪"是可以算出来的
 *     （这也让像素核验量得到同一个数）；
 *   · 评分用半星，只读的那一条与可交互的并排，一眼能看出同样的形态。
 *
 * ── 这一屏的结构就是它的测试用例 ──────────────────────────────────────
 *
 *   QSkinWindow
 *   └─ QSkinColumn                       页
 *      ├─ QSkinRow                       标题行
 *      ├─ QSkinRow                       主区，左窄右宽
 *      │  ├─ QSkinColumn
 *      │  │  ├─ QSkinCard「账号类型」      ← QSkinLabel(必填) + QSkinRadioGroup(3)
 *      │  │  └─ QSkinCard「通知方式」      ← QSkinLabel + QSkinToggleGroup(3, 多选)
 *      │  └─ QSkinColumn
 *      │     ├─ QSkinCard「备注」          ← QSkinLabel + QSkinTextarea(自增长+计数)
 *      │     ├─ QSkinCard「短信验证码」    ← QSkinLabel + QSkinInputOTP(分隔符)
 *      │     └─ QSkinCard「体验评分」      ← QSkinRate(半星) + QSkinRate(只读)
 *      └─ QSkinColumn id: selfTest       自证行（见下）
 *
 * ── 想看的六件事 ──────────────────────────────────────────────────────
 *   ① 单选组里**只有一个**被选中；选中那个的外圈画法由主题决定
 *      （TDesign / Ant 是实心 8px 白点，shadcn 是描边 10px 品牌点）
 *   ② 开关组：选中的底板与未选中的**明显不同**，且默认变体取 outline
 *      （因为五家对 variant: "default" 的理解不一致 —— 见 SCButtonBackground
 *      文件头那段"诚实记一笔"）
 *   ③ 三个开关是**多选**：可以同时亮两个。单选组反过来，再点已选中的
 *      那个不会把它取消
 *   ④ 文本域：自动增长时下夹 3 行，计数器在右下角，长度到顶就截断
 *   ⑤ 验证码：六格、每三格后有一条分隔符；格子是**等距方框**，
 *      所以整宽 = 6 格外加 1 条分隔的算术和，不是按文字量排出来的
 *   ⑥ 评分：3.5 应当画出**三颗实心星 + 一颗半星**（左半实心、右半空），
 *      只读的那条形态一样、只是不可点
 *
 * ── 为什么底部要有一行"自言自语" ─────────────────────────────────────
 * 抓图与人工核验都需要一个**不依赖眼睛判断**的锚点：这一行把主题、
 * 组的选中值、文本域的行数与字符数、验证码的格数/分隔数/总宽、
 * 评分的吸附值与星径直接写出来。图里看到的和它写的对不上，
 * 就是渲染出了问题（M17 起沿用这个做法）。
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
    title: "QSkin · M20 — 表单选择类"

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
    readonly property bool scInvalid:  win.scene === "invalid"
    readonly property bool scDisabled: win.scene === "disabled"

    /* ── 组（QtObject，不参与视觉树）── */
    QSkinRadioGroup  { id: typeGroup;  value: "pro" }
    QSkinToggleGroup { id: notifyGroup; multiple: true
                     value: win.scDisabled ? [] : ["email", "im"] }

    Component.onCompleted: win.applyTheme()

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

            Heading { level: 3; text: "表单选择类" }

            Caption {
                Layout.fillWidth: true
                text: "QSkinRadio · QSkinRadioGroup · QSkinToggle · QSkinToggleGroup"
                      + " · QSkinTextarea · QSkinLabel · QSkinRate · QSkinInputOTP"
            }

            Caption { text: win.themeName + " / " + win.mode + " / " + win.scene }
        }

        /* ══════════ 主区：左窄右宽 ══════════ */
        QSkinRow {
            Layout.fillWidth: true
            Layout.fillHeight: true
            gap: Theme.space.lg

            QSkinColumn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 4
                gap: Theme.space.lg

                /* ── 单选组 ── */
                QSkinCard {
                    Layout.fillWidth: true
                    title: "账号类型"
                    subtitle: "一组里只有一个能被选中；再点已选中的不会取消"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        QSkinLabel {
                            id: lbType
                            text: "套餐"
                            required: true
                        }

                        QSkinRadio {
                            id: rBasic
                            group: typeGroup
                            value: "basic"
                            text: "基础版"
                            enabled: !win.scDisabled
                        }
                        QSkinRadio {
                            id: rPro
                            group: typeGroup
                            value: "pro"
                            text: "专业版"
                            enabled: !win.scDisabled
                        }
                        /* 禁用成员必须**留在组里**（占位、可被跳过），
                         * 而不是从组里摘出去 —— 摘出去会让方向键的
                         * 回绕路径随可用成员数变化，那是一处很难查的跳动。 */
                        QSkinRadio {
                            id: rTeam
                            group: typeGroup
                            value: "team"
                            text: "团队版（暂不可选）"
                            enabled: false
                        }
                    }
                }

                /* ── 多选开关组 ── */
                QSkinCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "通知方式"
                    subtitle: "多选：可以同时亮两个；默认变体取 outline"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        QSkinLabel { text: "接收渠道" }

                        QSkinRow {
                            gap: Theme.space.sm

                            QSkinToggle {
                                id: tMail
                                group: notifyGroup
                                value: "email"
                                text: "邮件"
                                enabled: !win.scDisabled
                            }
                            QSkinToggle {
                                id: tIm
                                group: notifyGroup
                                value: "im"
                                text: "站内信"
                                enabled: !win.scDisabled
                            }
                            QSkinToggle {
                                id: tSms
                                group: notifyGroup
                                value: "sms"
                                text: "短信"
                                enabled: !win.scDisabled
                            }
                        }

                        Caption {
                            Layout.fillWidth: true
                            text: "已选 " + notifyGroup.selectedCount + " 项，上限 "
                                  + notifyGroup.limit + "。到上限后新点的那一个会替换掉最后一个 —— "
                                  + "这样用户不必先去取消。"
                        }
                    }
                }
            }

            QSkinColumn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 5
                gap: Theme.space.lg

                /* ── 文本域 ── */
                QSkinCard {
                    Layout.fillWidth: true
                    title: "备注"
                    subtitle: "自增长 2~4 行，最多 48 字；到顶之后输入被截断"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        QSkinLabel {
                            id: lbNote
                            text: "补充说明"
                        }

                        QSkinTextarea {
                            id: noteArea

                            Layout.fillWidth: true
                            rows: 2
                            autoGrow: true
                            maxRows: 4
                            maxLength: 48
                            maxCount: true
                            error: win.scInvalid
                            placeholderText: "写点什么…（想换行按 Ctrl+Enter 提交）"
                            text: "希望支持批量导入。"
                            enabled: !win.scDisabled
                        }
                    }
                }

                /* ── 验证码 ── */
                QSkinCard {
                    Layout.fillWidth: true
                    title: "短信验证码"
                    subtitle: "六格，每三格后一条分隔符；格子是等距方框，不按文字量排版"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        QSkinLabel {
                            id: lbOtp
                            text: "验证码"
                            required: true
                        }

                        QSkinRow {
                            gap: Theme.space.md

                            QSkinInputOTP {
                                id: otp

                                length: 6
                                separator: "-"
                                separatorEvery: 3
                                error: win.scInvalid
                                value: win.scDisabled ? "" : "481"
                                enabled: !win.scDisabled
                            }

                            Caption {
                                text: otp.isComplete ? "已填满" : ("已填 " + otp.filledCount + "/" + otp.cellCount)
                            }
                        }
                    }
                }

                /* ── 评分 ── */
                QSkinCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "体验评分"
                    subtitle: "半星档：3.5 画出三颗实心 + 一颗半星；只读的那条形态一样"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        QSkinLabel { text: "可交互（可点、可方向键）" }

                        QSkinRate {
                            id: rateHalf

                            value: 3.5
                            allowHalf: true
                            enabled: !win.scDisabled
                        }

                        QSkinLabel {
                            Layout.topMargin: Theme.space.sm
                            text: "只读（形态相同，只是不可点）"
                            variant: "muted"
                        }

                        QSkinRate {
                            id: rateRo

                            value: 4.5
                            allowHalf: true
                            readOnly: true
                            size: "sm"
                        }
                    }
                }
            }
        }

        /* ══════════ 自证行 ══════════ */
        QSkinColumn {
            id: selfTest

            Layout.fillWidth: true
            gap: 2

            Caption {
                Layout.fillWidth: true
                text: "theme=" + win.themeName + "  mode=" + win.mode + "  scene=" + win.scene
                      + "    radio: g=" + typeGroup.count + " val=" + typeGroup.value
                      + " has=" + typeGroup.hasSelection
                      + " checked=[" + rBasic.checked + "," + rPro.checked + "," + rTeam.checked + "]"
            }

            Caption {
                Layout.fillWidth: true
                text: "toggle: g=" + notifyGroup.count + " val=[" + notifyGroup.value + "]"
                      + " sel=" + notifyGroup.selectedCount + " limit=" + notifyGroup.limit
                      + "    label: req=" + lbType.required + " marker=" + lbType.markerSize
                      + " w=" + lbType.implicitWidth + "  opt=" + lbNote.implicitWidth
            }

            Caption {
                Layout.fillWidth: true
                text: "textarea: chars=" + noteArea.charCount + " rows=" + noteArea.visibleRows
                      + " logical=" + noteArea.logicalRows + " lh=" + noteArea.lineHeight
                      + " h=" + noteArea.implicitHeight + " counter=" + noteArea.showCount
                      + "    rate: half=" + rateHalf.snapped + " ro=" + rateRo.snapped
                      + " star=" + rateHalf.starSize + " step=" + rateHalf.step
                      + "    otp: cells=" + otp.cellCount + " seps=" + otp.sepCount
                      + " W=" + otp.implicitWidth + " filled=" + otp.filledCount
                      + " idx=" + otp.activeIndex
            }
        }
    }
}
