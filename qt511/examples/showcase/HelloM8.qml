/****************************************************************************
 * QSkin · 示例 —— M8：反馈三件套 + 表单校验
 *
 *   · QSkinDialog：模态确认框（标题 / 内容 / ButtonBar / Esc / 遮罩）
 *   · QSkinDrawer：右侧抽屉（四边可切、贴边直角、滑动动画）
 *   · QSkinToast：轻提示队列（四型语义色、自动消失、最多 3 条同屏）
 *   · QSkinForm / QSkinFormItem：required / minLength / pattern 规则、
 *     出错后实时重校、错误文字走 label 插槽 danger 变体
 *   · 主题切换：Neutral / TDesign / Ant / Arco / shadcn
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

    width: 880
    height: 520
    visible: true
    title: "QSkin · M8 — Dialog / Drawer / Toast / Form"

    /* Toast 锚定到窗口顶部居中（放窗口直接子级；z=1000 保证盖在 page 上） */
    QSkinToast {
        id: toast
        z: 1000
    }

    /* 仅截图脚本用：autoShow=true 时启动即推送三条 Toast */
    property bool autoShow: false
    Component.onCompleted: {
        if (autoShow) {
            toast.show("保存成功", "success", 60000)
            toast.show("草稿未保存", "warning", 60000)
            toast.show("删除失败，请重试", "danger", 60000)
        }
    }

    QSkinColumn {
        id: page

        anchors.fill: parent
        padding: Theme.space.xl
        gap: Theme.space.lg

        /* ── 头部：标题 + 主题切换 ── */
        QSkinRow {
            fill: true
            gap: Theme.space.sm

            QSkinColumn {
                gap: Theme.space.xs

                Heading { text: "M8 · 反馈三件套 + 表单校验" }
                Caption { text: "Dialog / Drawer 面板全走令牌（scrim / bgElevated / radius）· Toast 队列 · Form 规则校验" }
            }

            Spacer { }

            /* variant:text + size:sm —— 5 个主题按钮排一行，ghost/size:md
             * 在 880 宽窗口里放不下，"shadcn" 被截到屏幕外。
             * text 变体去掉边框（省 padding），size:sm 把 padding 从
             * Theme.space.lg(16) 降到 Theme.space.md(12)，每按钮
             * 净省 8px，5 个正好让 shadcn 落进窗口（M8+ 视觉打磨） */
            QSkinButton { text: "Neutral"; size: "sm"; variant: "text"; onClicked: { Slots.reset(); Theme.reset() } }
            QSkinButton { text: "TDesign"; size: "sm"; variant: "text"; onClicked: TDesign.apply() }
            QSkinButton { text: "Ant";     size: "sm"; variant: "text"; onClicked: AntDesign.apply() }
            QSkinButton { text: "Arco";    size: "sm"; variant: "text"; onClicked: ArcoDesign.apply() }
            QSkinButton { text: "shadcn";  size: "sm"; variant: "text"; onClicked: Shadcn.apply() }
        }

        /* ── 表单 ── */
        QSkinForm {
            id: form

            fill: true
            gap: Theme.space.lg

            QSkinFormItem {
                label: "用户名"; required: true
                rules: [
                    { required: true, message: "请输入用户名" },
                    { minLength: 2,   message: "至少 2 个字符" },
                    { maxLength: 12,  message: "最多 12 个字符" }
                ]

                QSkinInput {
                    width: 280
                    placeholderText: "2-12 字符"
                }
            }

            QSkinFormItem {
                label: "邮箱"
                rules: [ { pattern: /^.+@.+$/, message: "邮箱格式不对" } ]

                QSkinInput {
                    width: 280
                    placeholderText: "name@example.com"
                }
            }

            QSkinFormItem {
                label: "我已阅读条款"; required: true
                rules: [ { required: true, message: "请勾选条款" } ]

                QSkinCheckBox { }
            }
        }

        /* ── 动作区：ButtonBar 撑满 + 右对齐（M9.x 复测确认 fill:true 正常） ── */
        ButtonBar {
            fill: true
            align: "end"
            gap: Theme.space.md

            QSkinButton {
                text: "重置"
                variant: "ghost"
                onClicked: {
                    form.clearAllErrors()
                    toast.show("已清空校验状态", "info")
                }
            }
            QSkinButton {
                text: "提交表单"
                onClicked: {
                    if (form.validateAll()) {
                        toast.show("表单已提交", "success")
                        form.clearAllErrors()
                    } else {
                        toast.show("请检查表单错误", "danger")
                    }
                }
            }
        }

        /* ── 浮层入口 ── */
        QSkinRow {
            gap: Theme.space.sm

            QSkinButton {
                text: "打开对话框"
                variant: "ghost"
                onClicked: confirmDialog.open()
            }

            QSkinButton {
                text: "打开抽屉"
                variant: "ghost"
                onClicked: settingsDrawer.open()
            }
        }

        /* ── Toast 四型演示 ── */
        QSkinRow {
            gap: Theme.space.sm

            QSkinButton { text: "info";    variant: "text"; onClicked: toast.show("这是一条普通提示", "info") }
            QSkinButton { text: "success"; variant: "text"; onClicked: toast.show("保存成功", "success") }
            QSkinButton { text: "warning"; variant: "text"; onClicked: toast.show("草稿未保存", "warning") }
            QSkinButton { text: "danger";  variant: "text"; onClicked: toast.show("删除失败，请重试", "danger") }
            QSkinButton { text: "连发 5 条"; variant: "text"; onClicked: {
                for (var i = 1; i <= 5; ++i)
                    toast.show("第 " + i + " 条排队消息", "info")
            } }
        }
    }

    /* ── 模态确认框 ── */
    QSkinDialog {
        id: confirmDialog

        title: "提交表单"
        panelWidth: 400
        dismissOnScrim: false          /* 确认类：逼用户做选择 */

        Body { text: "提交后信息将不可修改，确定提交吗？" }

        /* footer 直接用 ButtonBar：fill 撑满面板宽，confirm 写在最后、
         * 由 followPlatform 决定它显示在左（Windows）还是右（macOS/Linux）。
         * dangerIndexes 给"取消"旁边留出安全间距，防误点。 */
        footer: ButtonBar {
            fill: true
            align: "end"
            gap: Theme.space.sm
            dangerIndexes: [0]

            QSkinButton {
                text: "取消"
                variant: "ghost"
                onClicked: confirmDialog.close()
            }

            QSkinButton {
                text: "确定提交"
                onClicked: {
                    confirmDialog.close()
                    toast.show("已提交", "success")
                }
            }
        }
    }

    /* ── 抽屉（四边可切） ── */
    QSkinDrawer {
        id: settingsDrawer

        edge: "right"
        panelWidth: 320
        title: "抽屉设置"

        QSkinColumn {
            fill: true
            gap: Theme.space.md

            Body { text: "从四条边滑入试试：" }

            QSkinRow {
                gap: Theme.space.sm

                QSkinButton { text: "左"; variant: "ghost"; onClicked: settingsDrawer.edge = "left" }
                QSkinButton { text: "右"; variant: "ghost"; onClicked: settingsDrawer.edge = "right" }
                QSkinButton { text: "上"; variant: "ghost"; onClicked: settingsDrawer.edge = "top" }
                QSkinButton { text: "下"; variant: "ghost"; onClicked: settingsDrawer.edge = "bottom" }
            }

            /* 开关组：填满抽屉下半截 —— 全高抽屉内容短时，
             * 用真实设置项而不是留白（M9 视觉收口） */
            QSkinColumn {
                fill: true
                gap: Theme.space.md

                QSkinSwitch { text: "接收通知" }
                QSkinSwitch { text: "自动保存草稿"; checked: true }
                QSkinSwitch { text: "同步到云端（不可用）"; enabled: false }

                /* 撑满内宽靠 Layout.fillWidth，不是 width（见 HelloFoundation 注释） */
                Caption {
                    Layout.fillWidth: true
                    text: "Esc 或点遮罩关闭。面板走 bgElevated + border 令牌，贴边直角（对齐 Ant Design Drawer）。"
                }
            }
        }
    }
}
