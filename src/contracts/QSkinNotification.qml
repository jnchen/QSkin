/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinNotification
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 通知卡（右上角堆叠）。M21 浮层家族里唯一**不走 Popup** 的成员 ——
 * 它不是一个"锚定到某个控件"的浮层，而是一块固定在窗口角落的堆叠区。
 *
 * ── 与 QSkinToast 的分工（两个都别丢）─────────────────────────────────────
 *     Toast         一句话、居中、自动消失、不打断 —— "已保存"
 *     Notification  有标题、右上角、可手动关 —— "同步失败，点这里重试"
 *
 * 前者是"知道了"，后者是"这里有件事，你可能要处理"。所以通知卡多了
 * 标题、多了关闭按钮、位置在右上（对齐 Ant / TDesign），停留也更久。
 *
 * ── 用法 ────────────────────────────────────────────────────────────────
 * 放在 QSkinWindow 根部（组件自身零占位、不拦截鼠标）：
 *
 *     QSkinNotification { id: notify }         // 摆哪都行，视觉固定在右上
 *     ...
 *     notify.show({ title: "同步失败", description: "网络不可达，稍后重试",
 *                   type: "danger" })
 *     notify.show("已同步", "success")        // 也接受一行字符串
 *
 * ── 堆叠为什么是手动摆位，不用 QSkinColumn ────────────────────────────────
 * 直接抄 QSkinToast 踩过的坑（那边文件头有实测记录）：三条通知同步连发时，
 * host.height ← layout.implicitHeight ← 子项累加 这条绑定链刷新不到位，
 * 三条会全部落在 y=0 互相盖住，屏幕上只看得到最后一条。
 *
 * 这里的手法是：`noticeHost.height` 绑定到一个会**读子项 height** 的函数
 * （_stackHeight）—— 读进依赖图，于是任何一张卡长高，绑定就重算，
 * onHeightChanged 再驱动 _reflow() 把 y 排好。比定时轮询干净，
 * 也不必把行高写死。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 同屏最多几张，超出的把最旧的挤掉 */
    property int maxVisible: 4

    /** 默认停留时长（毫秒）。传 0 表示不自动消失 */
    property int defaultDuration: 4500

    /** 卡片宽度 */
    property int noticeWidth: 320

    /** 当前显示中的通知数 */
    readonly property int count: root._items.length

    /**
     * show(spec)
     *   spec 可以是字符串（当作标题），也可以是对象：
     *     { title, description, type, duration }
     *   type: info | success | warning | danger（默认 info）
     */
    function show(spec) {
        var s = root._spec(spec)
        var item = noticeComp.createObject(noticeHost, { spec: s })
        if (!item) return null

        /* 新的排在最上面：_items[0] 就是 y=0 的那张 */
        var next = [item]
        for (var i = 0; i < root._items.length; ++i) next.push(root._items[i])
        root._items = next

        /* 超限的先移出列表（立刻塌陷布局），再让它播退场 */
        while (root._items.length > root.maxVisible) {
            var victim = root._items[root._items.length - 1]
            root._items = root._items.slice(0, root._items.length - 1)
            if (victim) victim._dismiss()
        }

        Qt.callLater(root._reflow)
        return item
    }

    /** 全部关掉 */
    function dismissAll() {
        var prev = root._items.slice()
        root._items = []
        for (var i = 0; i < prev.length; ++i)
            if (prev[i]) prev[i]._dismiss()
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    /* 撑满调用方容器（让 noticeHost 的 anchors 跟得到窗口边）。
     * z 提最高：通知是反馈层，应当盖在页面内容之上。
     * Item 默认不拦截鼠标 —— 空白处不会挡住底下的界面。 */
    anchors.fill: parent
    z: 1000

    /** 活着且**可见**的卡片，[0] 在最上面 */
    property var _items: []

    function _spec(v) {
        var d = root.defaultDuration
        if (v === null || v === undefined)
            return { title: "", description: "", type: "info", duration: d }
        if (typeof v === "string")
            return { title: String(v), description: "", type: "info", duration: d }
        return {
            title:       (v.title === undefined || v.title === null) ? "" : String(v.title),
            description: (v.description === undefined || v.description === null) ? "" : String(v.description),
            type:        (v.type === undefined || v.type === null) ? "info" : String(v.type),
            duration:    (v.duration === undefined || v.duration === null) ? d : v.duration
        }
    }

    function _typeColor(t) {
        if (t === "success") return Theme.color.success
        if (t === "warning") return Theme.color.warning
        if (t === "danger")  return Theme.color.danger
        return Theme.color.info
    }

    /** 卡片总高。**在绑定里读每个子项的 height** —— 这一步就是依赖登记，
     *  任何一张卡长高都会让 noticeHost.height 重算，进而触发 _reflow() */
    function _stackHeight() {
        var y = 0
        for (var i = 0; i < root._items.length; ++i) {
            var c = root._items[i]
            if (!c) continue
            y += (c.height || 0) + Theme.space.sm
        }
        return Math.max(0, y - Theme.space.sm)
    }

    function _reflow() {
        var y = 0
        for (var i = 0; i < root._items.length; ++i) {
            var c = root._items[i]
            if (!c) continue
            c.x = 0
            c.y = y
            c.width = root.noticeWidth
            y += c.height + Theme.space.sm
        }
    }

    function _reap(item) {
        var next = []
        for (var i = 0; i < root._items.length; ++i)
            if (root._items[i] !== item) next.push(root._items[i])
        root._items = next
        item.destroy(Theme.motion.slow)     /* 等退场动画播完再销毁 */
        Qt.callLater(root._reflow)
    }

    /* 右上角堆叠宿主。宽高都由 root 决定，卡片自己往里摆。 */
    Item {
        id: noticeHost

        anchors.top:         parent.top
        anchors.right:       parent.right
        anchors.topMargin:   Theme.space.xl
        anchors.rightMargin: Theme.space.xl

        width:  root.noticeWidth
        height: root._stackHeight()

        onHeightChanged: root._reflow()
        onWidthChanged:  root._reflow()
    }

    /* delegate 里引用外层 id（root / Theme）—— 与 QSkinToast / QSkinSelect
     * 同款 qmllint 静态检查局限，局部关闭。注释首行不以 qmllint 开头。 */
    // qmllint disable unqualified
    Component {
        id: noticeComp

        Rectangle {
            id: notice

            /* spec 由 createObject 注入 */
            property var spec

            function _dismiss() { notice.state = "leaving" }

            width:  root.noticeWidth
            height: col.implicitHeight + Theme.space.lg * 2

            radius: Theme.radius.lg
            color:  Theme.color.bgElevated
            border.width: 1
            border.color: Theme.color.border

            /* 默认可见。qml.exe 抓图时没有事件循环，State/Timer 可能不触发，
             * 卡在 opacity=0 会让截图变成"通知没出现"（M8 实测）。 */
            opacity: 1
            state: "shown"
            /* 状态的写法走**点号形式**（`notice.opacity:`）而不是
             * `PropertyChanges { target: notice; opacity: … }`。
             *
             * 两种写法运行时都对，差别在 qmllint 6.8.3：显式 `target:` 会让
             * `opacity` 被当成"custom-parsed binding"而报两条
             * [Quick.property-changes-parsed]，把一个原本干净的门禁顶到 4 条
             * 警告（M21 收口时实测）。点号形式把 target 与属性写在同一个
             * 限定名里，既没有"少写 target 导致 PropertyChanges 找不到默认
             * 作用对象"那个运行时告警，也不触发静态检查这一条。
             *
             * 另一条路是删掉 `target:` 只留 `opacity: 1` —— 那是**不行**的：
             * 这个 Rectangle 是一个 Component 的根对象，省略 target 时
             * PropertyChanges 找不到默认作用对象，运行时刷一屏
             * "Cannot assign to non-existent property opacity"（实测 5 张卡
             * × 2 个状态 = 10 次），而状态切换静默失效 —— 退场动画再也没有了，
             * 只是从告警里才看得出来。 */
            states: [
                State { name: "shown"
                        PropertyChanges { notice.opacity: 1 } },
                State { name: "leaving"
                        PropertyChanges { notice.opacity: 0 } }
            ]
            transitions: [
                Transition {
                    from: "shown"; to: "leaving"
                    NumberAnimation {
                        property: "opacity"
                        duration: Theme.motion.fast
                        easing.type: Theme.motion.easing
                    }
                }
            ]

            /* ── 语义色：左侧一条竖直圆角条 ──
             * 比图标字形稳（不吃字体符号在不同系统上的回退差异），
             * 也比整块 subtle 底色稳（深色模式下 subtle 会和页面糊在一起）。 */
            Rectangle {
                anchors.left:         parent.left
                anchors.top:          parent.top
                anchors.bottom:       parent.bottom
                anchors.leftMargin:   Theme.space.sm
                anchors.topMargin:    Theme.space.md
                anchors.bottomMargin: Theme.space.md

                width: 3
                radius: width / 2
                color: root._typeColor(notice.spec ? notice.spec.type : "info")
            }

            QSkinColumn {
                id: col

                anchors.left:  parent.left
                anchors.right: parent.right
                anchors.top:   parent.top

                anchors.leftMargin:  Theme.space.lg
                anchors.topMargin:   Theme.space.lg
                /* 给右上角的关闭按钮让位，标题长时不会钻到它下面 */
                anchors.rightMargin: Theme.space.lg + closeBtn.width + Theme.space.sm

                gap: Theme.space.xs

                /* 标题（可选）：label 插槽 header 变体 —— 与 QSkinDialog 标题
                 * 是同一格，主题改标题字号字重，这里跟着变。 */
                Loader {
                    id: titleLabel

                    visible: notice.spec !== null && notice.spec.title !== ""
                    Layout.fillWidth: true
                    sourceComponent: Slots.label

                    Binding {
                        target: titleLabel.item
                        property: "control"
                        value: titleCtl
                        when: titleLabel.status === Loader.Ready
                    }
                }

                QtObject {
                    id: titleCtl

                    readonly property string text: notice.spec ? notice.spec.title : ""
                    readonly property string variant: "header"
                    readonly property int labelAlignment: Text.AlignLeft
                }

                Body {
                    Layout.fillWidth: true

                    visible: notice.spec !== null && notice.spec.description !== ""
                    text:    notice.spec ? notice.spec.description : ""
                    tone:    "secondary"
                }
            }

            /* ── 关闭按钮 ──
             * ✕ 用 Shape 画，不用 "×" 字符 —— 项目既有规则，四处都写过
             * （见 BasicChevronIndicator 文件头那份清单）。 */
            Item {
                id: closeBtn

                width:  Theme.size.iconSm
                height: Theme.size.iconSm

                anchors.right:       parent.right
                anchors.top:         parent.top
                anchors.rightMargin: Theme.space.md
                anchors.topMargin:   Theme.space.md

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: Math.max(1, closeBtn.width * 0.14)
                        strokeColor: closeMouse.containsMouse
                                     ? Theme.color.fg : Theme.color.fgMuted
                        fillColor:   "transparent"
                        capStyle:    ShapePath.RoundCap

                        startX: closeBtn.width * 0.24
                        startY: closeBtn.height * 0.24
                        PathLine {
                            x: closeBtn.width * 0.76
                            y: closeBtn.height * 0.76
                        }
                    }

                    ShapePath {
                        strokeWidth: Math.max(1, closeBtn.width * 0.14)
                        strokeColor: closeMouse.containsMouse
                                     ? Theme.color.fg : Theme.color.fgMuted
                        fillColor:   "transparent"
                        capStyle:    ShapePath.RoundCap

                        startX: closeBtn.width * 0.76
                        startY: closeBtn.height * 0.24
                        PathLine {
                            x: closeBtn.width * 0.24
                            y: closeBtn.height * 0.76
                        }
                    }
                }

                MouseArea {
                    id: closeMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: notice._dismiss()
                }
            }

            /* 停留 → 退场 → 销毁。duration 为 0 表示不自动消失 */
            Timer {
                interval: (notice.spec && notice.spec.duration > 0)
                          ? notice.spec.duration : 0
                running: interval > 0
                onTriggered: {
                    notice.state = "leaving"
                    reapTimer.start()
                }
            }

            Timer {
                id: reapTimer

                interval: Theme.motion.fast + 20
                onTriggered: root._reap(notice)
            }

            Accessible.role: Accessible.AlertMessage
            Accessible.name: notice.spec
                             ? (notice.spec.title !== "" ? notice.spec.title
                                                         : notice.spec.description)
                             : ""
        }
    }
    // qmllint enable unqualified
}
