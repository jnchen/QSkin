/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinToast
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 轻提示（M8 反馈三件套之三）。
 *
 * ── 分工 ─────────────────────────────────────────────────────────────
 *   本文件：show() 队列（最多同时 maxVisible 条，多的排队）、
 *           自动消失（duration）、出入场动画（opacity + 上移）、
 *           语义四型 info / success / warning / danger
 *   插槽：  文字走 Slots.label 默认变体 —— 零新插槽
 *
 * ── 用法 ─────────────────────────────────────────────────────────────
 *   放在 QSkinWindow 根部（任意位置，组件自身零占位、不拦截鼠标）：
 *
 *     QSkinWindow {
 *         QSkinToast { id: toast }        // 摆哪都行，视觉固定在顶部居中
 *         ...
 *         onClicked: toast.show("已保存", "success")
 *     }
 *
 *   show(text, type, duration)：
 *     type    info | success | warning | danger（默认 info）
 *     duration 毫秒，默认 3000
 *
 * 视觉：底部圆角胶囊（bgElevated + border），左侧状态点着语义色。
 * 不用整块 subtle 底色 —— 深色模式下 subtle 色和遮罩糊在一起。
 * 状态点比图标字符更稳（不依赖字体符号渲染差异）。
 *
 * 位置取舍：顶部居中（对齐 Ant/Arco）。macOS 惯例是右侧边缘，
 * 需要时给 Toast 加 position 属性即可，V1 不做。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 同屏最多条数，超出的排队等前面消失 */
    property int maxVisible: 3

    /** 默认停留时长（毫秒） */
    property int defaultDuration: 3000

    function show(text, type, duration) {
        var t = (type === undefined || type === null) ? "info" : String(type)
        var d = (duration === undefined || duration === null) ? root.defaultDuration : duration
        _queue.push({ text: String(text), type: t, duration: d })
        _pump()
    }

    /** 清空：立即可见与排队的全部消失 */
    function dismissAll() {
        _queue = []
        for (var i = 0; i < _items.length; ++i)
            _items[i]._dismiss()
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    /* Toast 自身撑满调用方容器（让 toastHost 的 anchors 跟到窗口大小）。
     * Item 默认不拦截鼠标（M8 实测：放窗口直接子级时 root 是 0×0，
     * 锚到 root 的顶部 = 屏幕 0,0 不可见）。
     * z 提最高 —— Toast 是反馈层，应盖在页面内容之上（即便调用方
     * 把 QSkinToast 写在 QSkinWindow 子级前几位，后声明的 page 也不会
     * 把它盖掉） */
    anchors.fill: parent
    z: 1000

    property var _queue: []
    property var _items: []      /* 活着的条目（toastComp 实例） */

    function _pump() {
        while (_items.length < root.maxVisible && _queue.length > 0) {
            var spec = _queue.shift()
            var item = toastComp.createObject(toastHost, { spec: spec })
            if (item) _items.push(item)
        }
    }

    function _reap(item) {
        var next = []
        for (var i = 0; i < _items.length; ++i)
            if (_items[i] !== item) next.push(_items[i])
        _items = next
        item.destroy(Theme.motion.slow)   /* 等退场动画播完再销毁 */
        _pump()
    }

    function _typeColor(t) {
        if (t === "success") return Theme.color.success
        if (t === "warning") return Theme.color.warning
        if (t === "danger")  return Theme.color.danger
        return Theme.color.info
    }

    /* 顶部居中的堆叠宿主。锚到本组件（已撑满调用方）→ 锚到窗口。
     *
     * 不依赖 QSkinColumn 的 implicitHeight 链路 —— 3 个 toast 同步连发
     * 时 binding 链（host.height ← layout.implicitHeight ← 子项累加）
     * 刷新不到位，3 个 Rectangle 都落在 y=0，只有最后画的那个可见，
     * 盖住前两条（M8+ 实测：截图仅见 "C-danger"）。
     * 这里改成手动摆位：_pump() 给新 toast 设 y = index * (h + gap)，
     * 锚到水平居中。子项增删走 host.childrenChanged → _reflow()。 */
    Item {
        id: toastHost

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.space.xl

        property int _gap: Theme.space.sm
        property int _rowH: Theme.size.controlMd

        function _reflow() {
            var kids = toastHost.children
            for (var i = 0; i < kids.length; ++i) {
                kids[i].y = i * (toastHost._rowH + toastHost._gap)
                kids[i].anchors.horizontalCenter = toastHost.horizontalCenter
            }
            toastHost.height = Math.max(0,
                kids.length * toastHost._rowH
                + Math.max(0, kids.length - 1) * toastHost._gap)
        }

        onChildrenChanged: toastHost._reflow()
    }

    /* delegate 里引用外层 id（root）—— 与 QSkinSelect delegate 同款
     * qmllint 静态检查局限，局部关闭。注释首行不以 qmllint 开头。 */
    // qmllint disable unqualified
    Component {
        id: toastComp

        Rectangle {
            id: toast

            /* spec 由 createObject 注入 */
            property var spec

            function _dismiss() {
                toast.state = "leaving"
            }

            /* 宽度跟文字（Loader 的 implicitWidth 自动跟随被加载项 ——
             * 与 QSkinButton 的 contentLoader 同款写法，别写 .item.xxx） */
            width:  Math.max(160, toastLabel.implicitWidth + statusDot.width + Theme.space.xl)
            height: Theme.size.controlMd
            radius: Theme.radius.full

            color:        Theme.color.bgElevated
            border.color: Theme.color.border
            border.width: 1

            /* 默认可见，且**不靠状态机进场** —— qml.exe 截图工具无事件
             * 循环时 Timer/State 可能不触发，避免 Toast 一直卡在
             * opacity=0（M8 实测）。淡出仍由下面的状态机负责。 */
            opacity: 1
            state: "shown"
            /* ⚠ 这两条的写法是被两条约束**夹**出来的，别随手改回去 —— M31 第二件实测：
             *
             *   `PropertyChanges { opacity: 1 }`（不写 target）
             *     → 运行期报 `Cannot assign to non-existent property "opacity"`。
             *       赋值被当成落在 PropertyChanges **自身**上，而它没有 opacity。
             *       后果不是"少了个动画"，是**淡出从来没发生过**：`_dismiss()`
             *       的全部内容就是 `toast.state = "leaving"`，赋值失败后 opacity
             *       停在 1，退场实际表现为"停满 fast+20ms，再瞬间消失"。
             *
             *   `PropertyChanges { target: toast; opacity: 1 }`
             *     → 运行期好了（opacity 真的会到 0），但 qmllint 报 4 条
             *       `Quick.property-changes-parsed`（custom-parsed 绑定），lint 红。
             *
             *   `PropertyChanges { toast.opacity: 1 }` ← **当前写法**
             *     → 两边都过：不带 custom-parsed 绑定，qmllint 零警告；
             *       运行期真把 opacity 推到 0（场景实测，读数见 ROADMAP §6.4）。
             *
             * 补 `target` 这类写法之所以在别处看着"能跑"，是因为多数文件的
             * PropertyChanges 本来就带 `target:`；本件是漏写，而漏写的失败
             * 被"默认 opacity: 1"整个盖住了（M27 已识别，M31 判决并修）。
             * ⚠ 这是**行为变更**（画面会变），裁决见 ROADMAP §6.4。 */
            states: [
                State { name: "shown";     PropertyChanges { toast.opacity: 1 } },
                State { name: "leaving";   PropertyChanges { toast.opacity: 0 } }
            ]
            transitions: [
                Transition {
                    from: "shown"; to: "leaving"
                    NumberAnimation { property: "opacity"; duration: Theme.motion.fast; easing.type: Theme.motion.easing }
                }
            ]

            /* 状态点：语义色。比图标字符稳 —— 不吃字体符号渲染差异 */
            Rectangle {
                id: statusDot

                width:  height
                height: 8
                radius: height / 2
                anchors.left:          parent.left
                anchors.leftMargin:    Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                color: root._typeColor(toast.spec ? toast.spec.type : "info")
            }

            /* 文字走 label 插槽（默认变体） */
            Loader {
                id: toastLabel

                anchors.left:          statusDot.right
                anchors.leftMargin:    Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter

                sourceComponent: Slots.label

                Binding {
                    target: toastLabel.item
                    property: "control"
                    value: toastCtl
                    when: toastLabel.status === Loader.Ready
                }
            }

            QtObject {
                id: toastCtl

                readonly property string text: toast.spec ? toast.spec.text : ""
                readonly property string variant: "default"
                readonly property int labelAlignment: Text.AlignLeft
            }

            /* 入场 → 停留 → 退场。Timer 不可重入，销毁即失效 */
            Timer {
                interval: toast.spec ? Math.max(600, toast.spec.duration) : 600
                running: true
                onTriggered: {
                    toast.state = "leaving"
                    /* 退场动画时长后再 reap（排队下一条顶上来） */
                    reapTimer.start()
                }
            }

            Timer {
                id: reapTimer

                interval: Theme.motion.fast + 20
                onTriggered: root._reap(toast)
            }

            Component.onCompleted: {
                /* 进场 → 停留 → 退场。Qt.callLater 在无渲染循环的
                 * qml 截图工具里不触发（M8 实测）—— Timer 一拍起。 */
                enterTimer.start()
            }

            Timer {
                id: enterTimer

                interval: 20
                onTriggered: toast.state = "shown"
            }

            Accessible.role: Accessible.AlertMessage
            Accessible.name: toast.spec ? toast.spec.text : ""
        }
    }
    // qmllint enable unqualified
}
