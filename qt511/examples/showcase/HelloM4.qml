/****************************************************************************
 * QSkin · 示例 —— M4：契约回收与新控件
 *
 *   · QSkinTabs：激活下划线来自 Slots.tabIndicator，主题一键可换
 *   · QSkinMenu：面板外壳复用 Slots.selectOverlay，阴影不再被裁
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

    width: 960
    height: 640
    visible: true
    title: "QSkin · M4 — Tabs / Menu / 浮层契约"

    QtObject {
        id: state

        property int pane: 0
        property string lastAction: "（尚未触发菜单项）"
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

                Heading { text: "M4 · 契约回收与新控件" }
                Caption { text: "Tabs 下划线走 tabIndicator 插槽 · 菜单外壳复用 selectOverlay · 浮层阴影不再被裁" }
            }

            Spacer { }

            QSkinButton { text: "Neutral"; variant: "ghost"; onClicked: { Slots.reset(); Theme.reset() } }
            QSkinButton { text: "TDesign"; variant: "ghost"; onClicked: TDesign.apply() }
            QSkinButton { text: "Ant";     variant: "ghost"; onClicked: AntDesign.apply() }
            QSkinButton { text: "Arco";    variant: "ghost"; onClicked: ArcoDesign.apply() }
            QSkinButton { text: "shadcn";  variant: "ghost"; onClicked: Shadcn.apply() }
        }

        /* ── 页签导航：下划线视觉全在插槽里 ── */
        QSkinTabs {
            id: tabs

            model: ["项目概览", "成员管理", "操作日志"]
            onActivated: function(index) { state.pane = index }
        }

        /* ── 页签内容区（演示用，非导航控件职责） ──
         * 裸 Item 被 QSkinColumn（ColumnLayout）管理时，横向尺寸要用
         * implicitWidth 表达 —— 写 width 会被 Layouts 静默忽略。 */
        Rectangle {
            implicitWidth: page.width
            height: 150

            radius: Theme.radius.lg
            color:  Theme.color.bgSunken
            border.width: 1
            border.color: Theme.color.border

            QSkinColumn {
                anchors.fill: parent
                anchors.margins: Theme.space.lg
                gap: Theme.space.sm

                Body {
                    text: state.pane === 0 ? "项目概览 —— 激活下划线来自当前主题的 tabIndicator 插槽。"
                        : state.pane === 1 ? "成员管理 —— 切换主题时下划线的粗细、圆角、颜色随之改变。"
                        : "操作日志 —— 左右键可在页签间导航，Home / End 直达首尾。"
                }
                Caption { text: "第 " + (state.pane + 1) + " 个页签处于激活态" }
            }
        }

        /* ── 菜单演示 ── */
        QSkinRow {
            gap: Theme.space.md

            QSkinButton {
                id: moreBtn

                text: "更多操作"
                icon: Slots.chevronIndicator
                iconDirection: "down"
                onClicked: {
                    var p = moreBtn.mapToItem(win.contentItem, 0, moreBtn.height)
                    menu.openAt(p.x, p.y + Theme.space.xs)
                }
            }

            QSkinTooltip { text: "菜单外壳与下拉面板共用同一插槽"; target: moreBtn }

            Body { text: "最近菜单动作：" + state.lastAction }
        }

        /* ── 分隔线 + 说明 ── */
        Rectangle { implicitWidth: page.width; height: 1; color: Theme.color.border }

        /* 长说明要换行 —— 撑满内宽靠 Layout.fillWidth，不是 width（见 HelloFoundation 注释） */
        Caption {
            Layout.fillWidth: true

            text: "M4 契约回收：① 浮层插槽新增 extender 属性，上报阴影外扩量，宿主 Popup 据此放大自身；" +
                  "② indicator 家族新增 tabIndicator，Tabs 下划线的视觉决策交还主题。"
        }
    }

    QSkinMenu {
        id: menu

        model: [
            "重命名",
            "复制链接",
            "separator",
            { text: "移动到…", enabled: false },
            { text: "删除", danger: true }
        ]
        onTriggered: function(index) {
            var it = menu.model[index]
            state.lastAction = typeof it === "string" ? it : it.text
        }
    }
}
