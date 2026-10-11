/****************************************************************************
 * QSkin · 示例 —— M21：浮层家族
 *
 * 六个件（Popover / Popconfirm / HoverCard / Dropdown / ContextMenu /
 * Notification）在这一屏里全部用上，而且**互相挨着**。单独摆六个样例看不出
 * "它们能不能一起工作"，而"一起工作"正是这一批的全部意义：
 *
 *   · 五个"锚定到某个控件"的浮层，走的是**两条腿**：
 *       气泡一族（Popover / Popconfirm / HoverCard）→ QSkinPopover 派生
 *       菜单一族（Dropdown / ContextMenu）        → 触发器 + QSkinMenu
 *     两条腿共用同一格外壳（Slots.selectOverlay），所以换肤时它们的
 *     底色 / 圆角 / 阴影 / 内边距是**一起**变的 —— 这正是"不为气泡新开
 *     一格"这条架构判断在屏幕上的样子。
 *   · Notification 是这个家族里唯一**不走 Popup** 的成员：它不是"锚定到
 *     某个控件"的浮层，而是一块固定在窗口右上角的堆叠区。
 *   · 排他规则只在气泡一族里生效（OverlayStack）：开一个 QSkinPopover 会
 *     关掉另一个，但 HoverCard 不该顶掉它、菜单也不参与。
 *
 * ── 这一屏的结构就是它的测试用例 ──────────────────────────────────────
 *
 *   QSkinWindow
 *   ├─ QSkinNotification                   通知堆叠（视觉固定在右上角）
 *   └─ QSkinColumn                         页
 *      ├─ QSkinRow                        标题行
 *      ├─ QSkinRow                        主区，左窄右宽
 *      │  ├─ QSkinColumn
 *      │  │  ├─ QSkinCard「账户操作」      ← QSkinDropdown + QSkinPopover
 *      │  │  └─ QSkinCard「危险操作」      ← QSkinPopconfirm(danger)
 *      │  └─ QSkinColumn
 *      │     ├─ QSkinCard「悬停说明」      ← QSkinHoverCard
 *      │     ├─ QSkinCard「右键菜单」      ← QSkinContextMenu（撑满虚线框）
 *      │     └─ QSkinCard「通知」          ← 四个按钮驱动堆叠
 *      └─ QSkinColumn id: selfTest        自证行（见下）
 *
 * ── 想看的七件事 ──────────────────────────────────────────────────────
 *   ① 下拉菜单的箭头**收起朝下、展开朝上**（这个方向是派生量，不是常量）
 *   ② 面板宽 260/250/280/180 都是**显式给**的：面板定宽，内容不会把它撑开，
 *      也不会因为标题长短而抖动
 *   ③ 气泡的阴影**不被裁**：外壳如实上报 extender，宿主把 Popup 放大
 *      extender×2 —— TDesign 是 3、Ant 是 3、Arco 是 2、shadcn 是 4，
 *      四家的浮层外扩量各不相同，换个主题看阴影边缘就懂了
 *   ④ 内边距属于外观：TDesign 的浮层内边距是 8（--td-pop-padding-l），
 *      其余三家是 4 —— 参数在下面自证行里直接读出来
 *   ⑤ 右键菜单只吃右键：在虚线框里点左键什么都不会发生，悬停也不会被吃掉
 *   ⑥ 通知卡新的在最上面，超上限（4）时**最旧的那张**出列
 *   ⑦ 通知卡的语义色来自令牌（左侧那条 3px 竖条）：切到深色主题时
 *      danger 不是同一个红 —— 写死色值在这里会立刻穿帮
 *
 * ── 为什么底部要有一行"自言自语" ─────────────────────────────────────
 * 抓图与人工核验都需要一个**不依赖眼睛判断**的锚点：这一行把主题、浮层的
 * 宽/内边距/外扩量、排他栈的当前深度、菜单的内容高度、通知的排位直接写出来。
 * 图里看到的和它写的对不上，就是渲染出了问题（M17 起沿用这个做法）。
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
    height: 1010
    visible: true
    title: "QSkin · M21 — 浮层家族"

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
     * 全部写成绑定，不做命令式赋值 —— 少一个时序变量（M18 教训）。
     *   base     日常态：所有浮层关着，两条通知挂在右上角
     *   open     三个浮层同时开着（气泡 + 悬停卡 + 右键菜单），看阴影与落点
     *   crowded  六条通知 → 超过上限 4，最旧的两条出列 */
    readonly property bool scOpen:    win.scene === "open"
    readonly property bool scCrowded: win.scene === "crowded"

    /* ── 业务回执（自证行里读）── */
    property string lastAction: "—"
    property int confirmCount: 0
    property int cancelCount: 0

    Component.onCompleted: {
        win.applyTheme()
        notify.show({ title: "同步失败",
                      description: "网络不可达，稍后重试",
                      type: "danger" })
        /* ── 这里原本写的是 `notify.show("已同步", "success")` ────────────
         * `show()` 只收**一个**参数，第二个会被 JS 静默丢掉；而 `_spec()`
         * 对字符串的处理是「当标题，type 记 info」。于是这一行真实渲染出来
         * 是一条 **info** 通知 —— 不报错、不崩，只是意图没了。属性侧再怎么
         * 断言也抓不到，因为它读到的 title 完全正确。
         * 字符串简写只表达标题；要带语义就必须给对象。 */
        notify.show({ title: "已同步",
                      description: "共 128 条",
                      type: "success" })
        if (win.scOpen) {
            quotaPop.open()
            hoverCard.open()
            ctx.openAt(132, 44)
        }
        if (win.scCrowded) {
            for (var i = 1; i <= 5; ++i) notify.show("第 " + i + " 条")
        }
    }

    /* ══════════════════ 通知堆叠 ══════════════════
     * 声明在窗口这一层：它自己 anchors.fill，视觉固定在右上角。
     * defaultDuration: 0 —— 示例屏不让它自己溜走，否则抓图时机会飘。 */
    QSkinNotification {
        id: notify

        maxVisible: 4
        defaultDuration: 0
    }

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

            Heading { level: 3; text: "浮层家族" }

            Caption {
                Layout.fillWidth: true
                text: "QSkinPopover · QSkinPopconfirm · QSkinHoverCard · QSkinDropdown"
                      + " · QSkinContextMenu · QSkinNotification"
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

                /* ── 下拉动作菜单 ── */
                QSkinCard {
                    Layout.fillWidth: true
                    title: "账户操作"
                    subtitle: "自带触发器；箭头方向是派生量（收起朝下、展开朝上）"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        QSkinRow {
                            gap: Theme.space.md

                            QSkinDropdown {
                                id: dd

                                text: "更多操作"
                                model: ["编辑资料", "复制 ID", "separator",
                                        { text: "转交所有权", enabled: false },
                                        { text: "删除账号", danger: true }]

                                onTriggered: function(index) {
                                    win.lastAction = "dropdown #" + index
                                }
                            }

                            /* 气泡基座本身：锚定到按钮、下方展开、点外部关闭
                             *
                             * ── variant 必须是 "text"，不能写 "outline" ──
                             * `variant` 在 QSkinButton 上只是个自由字符串，**长相由
                             * 主题外壳决定**；四家的 ButtonBackground 只认
                             * `primary / default / danger / ghost / text` 五个。
                             * 写 "outline" 不会有任何报错，也不会落到任何 case ——
                             * 静默地长得和 default 一样。`outline` 是 **QSkinToggle**
                             * 的变体名，两个控件的词汇表不通用。 */
                            QSkinButton {
                                id: quotaAnchor

                                text: "额度说明"
                                variant: "text"
                                onClicked: quotaPop.toggle()
                            }
                        }

                        Caption {
                            Layout.fillWidth: true
                            text: "菜单的行语义（分隔线占多高、危险项怎么标、上下键"
                                  + "怎么跳过分隔线与禁用项）都长在 QSkinMenu 里 —— "
                                  + "这里只负责把位置算给它。"
                        }
                    }

                    /* ── 浮层基座：任意内容 + 锚定 ──
                     * 声明在卡片里、target 指向同卡片里的按钮 —— 定位走的是
                     * 场景坐标相减，所以"声明在哪一层"不影响结果。 */
                    QSkinPopover {
                        id: quotaPop

                        target: quotaAnchor
                        title: "图片额度怎么算"
                        panelWidth: 260
                        placement: "bottom"

                        Body {
                            Layout.fillWidth: true
                            text: "每张原图按最长边折算：≤1024 记 1 次，"
                                  + "≤2048 记 2 次，再往上每翻一倍加 1 次。"
                        }
                        Caption {
                            Layout.fillWidth: true
                            text: "面板宽 260 是显式给的 —— 折行文案必须显式定宽，"
                                  + "否则「面板宽 ← 内容宽 ← 文字不折行」会自洽地"
                                  + "一直不折行。"
                        }
                    }
                }

                /* ── 气泡确认 ── */
                QSkinCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "危险操作"
                    subtitle: "两个出口都关面板**并且**发信号；danger 时确认键换变体"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        Body {
                            Layout.fillWidth: true
                            text: "删除类操作不该是蓝色的 —— 主按钮换成 danger 变体，"
                                  + "并且默认不响应「点外部关闭」（确认类内容建议关掉它）。"
                            tone: "secondary"
                        }

                        QSkinRow {
                            gap: Theme.space.md

                            QSkinButton {
                                id: delAnchor

                                text: "删除该项目"
                                variant: "danger"
                                onClicked: delConfirm.open()
                            }

                            Caption {
                                text: "确认 " + win.confirmCount
                                      + " 次 / 取消 " + win.cancelCount + " 次"
                            }
                        }
                    }

                    QSkinPopconfirm {
                        id: delConfirm

                        target: delAnchor
                        text: "确定要删除「季度汇报」吗？"
                        description: "删除后不可恢复，协作者会立即失去访问权。"
                        danger: true

                        onConfirmed: win.confirmCount++
                        onCanceled:  win.cancelCount++
                    }
                }
            }

            QSkinColumn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 5
                gap: Theme.space.lg

                /* ── 悬停卡片 ── */
                QSkinCard {
                    Layout.fillWidth: true
                    title: "悬停说明"
                    subtitle: "指针要能移进卡片里；它不参与「同刻只有一个浮层」"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        QSkinRow {
                            gap: Theme.space.md

                            QSkinButton {
                                id: metricAnchor
                                text: "指到我身上"
                            }

                            Caption {
                                text: "移出后 " + hoverCard.hideDelay + "ms 才收，"
                                      + "路上给指针留了缓冲"
                            }
                        }

                        Caption {
                            Layout.fillWidth: true
                            text: "与 Tooltip 的分界：Tooltip 一移开就消失、指针进不去；"
                                  + "HoverCard 里的链接与按钮是**可以点**的。"
                        }
                    }

                    QSkinHoverCard {
                        id: hoverCard

                        target: metricAnchor
                        title: "该指标怎么算"
                        panelWidth: 280
                        showDelay: 260
                        hideDelay: 160

                        Body {
                            Layout.fillWidth: true
                            text: "活跃度 = 近 28 天内有过写操作的天数 ÷ 28。"
                                  + "只读不写不计入。"
                        }
                    }
                }

                /* ── 右键菜单 ── */
                QSkinCard {
                    Layout.fillWidth: true
                    title: "右键菜单"
                    subtitle: "只吃右键、不吃悬停 —— 盖上去对这层是透明的"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        Rectangle {
                            id: ctxArea

                            Layout.fillWidth: true
                            implicitHeight: 96

                            color: "transparent"
                            radius: Theme.radius.md
                            border.width: 1
                            border.color: Theme.color.border

                            Caption {
                                anchors.centerIn: parent
                                text: "在这块区域里点右键"
                            }

                            QSkinContextMenu {
                                id: ctx

                                model: ["复制", "粘贴", "separator",
                                        { text: "删除", danger: true }]

                                onTriggered: function(index) {
                                    win.lastAction = "context #" + index
                                }
                            }
                        }

                        Caption {
                            Layout.fillWidth: true
                            text: "声明在**要响应右键的那个容器里**，它自己撑满容器。"
                                  + "不碰 target、不 reparent MouseArea —— 那会改变"
                                  + "下面控件的层级与事件顺序。"
                        }
                    }
                }

                /* ── 通知 ── */
                QSkinCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "通知"
                    subtitle: "新的在最上面；超过 maxVisible 时最旧的出列"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        QSkinRow {
                            gap: Theme.space.sm

                            QSkinButton {
                                text: "同步失败"
                                onClicked: notify.show({ title: "同步失败",
                                                         description: "网络不可达，稍后重试",
                                                         type: "danger" })
                            }
                            QSkinButton {
                                text: "已同步"
                                variant: "text"
                                onClicked: notify.show({ title: "已同步",
                                                         description: "共 128 条",
                                                         type: "success" })
                            }
                            QSkinButton {
                                text: "清空"
                                variant: "ghost"
                                onClicked: notify.dismissAll()
                            }
                        }

                        Caption {
                            Layout.fillWidth: true
                            text: "左侧那条 3px 竖条是这个家族里唯一的语义色表达"
                                  + "（比图标字形稳、比整块底色稳）—— 它跟的是"
                                  + "Theme.color.danger / success / warning / info。"
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
                      + "    popover: w=" + quotaPop.panelWidth
                      + " pad=" + quotaPop.panelPadding + " ext=" + quotaPop.panelExtender
                      + " gap=" + quotaPop.gap + " opened=" + quotaPop.opened
                      + "  popconfirm: w=" + delConfirm.panelWidth + " opened=" + delConfirm.opened
            }

            Caption {
                Layout.fillWidth: true
                text: "stack: depth=" + OverlayStack.exclusiveCount
                      + " topPop=" + (OverlayStack.top() === quotaPop)
                      + " hoverCard.exclusive=" + hoverCard.exclusive
                      + "    dropdown: opened=" + dd.opened + " arrow=" + dd.iconDirection
                      + " menuW=" + dd.menu.panelWidth + " rowH=" + dd.menu.itemHeight
                      + " contentH=" + dd.menu._contentHeight()
            }

            Caption {
                Layout.fillWidth: true
                text: "contextMenu: opened=" + ctx.opened
                      + " rightOnly=" + (ctx.catcher.acceptedButtons === Qt.RightButton)
                      + " hoverOff=" + (ctx.catcher.hoverEnabled === false)
                      + "    notify: count=" + notify.count + " max=" + notify.maxVisible
                      + " w=" + notify.noticeWidth + " stackH=" + notify._stackHeight()
                      + " first=" + (notify._items.length > 0
                                     ? ("y=" + notify._items[0].y + " h=" + notify._items[0].height)
                                     : "—")
                      + "    last=" + win.lastAction
            }
        }
    }
}
