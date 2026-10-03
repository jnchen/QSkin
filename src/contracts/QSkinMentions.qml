/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinMentions
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 提及：多行文本框，打 `@` 之后列出人（或任何东西）让你挑。M26 新增。
 *
 * ── 为什么值得做（覆盖面口径）────────────────────────────────────────
 * Ant 5.x（`Mentions`）、Arco（`Mentions`）、TDesign（`Mentions`）三家都有。
 * 三家在契约上一致：`prefix`（触发符，默认 `@`）、`split`（插入后的分隔符，
 * 默认空格）、`options`（候选）、`onSelect`。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 与 `QSkinAutoComplete` 的分工（两件长得像，判据只有一条）
 * ════════════════════════════════════════════════════════════════════════
 *
 *     QSkinAutoComplete   替**整段**文字：输入框里那串字就是查询词，
 *                       选中一条候选 = 用它的 label **换掉**输入框内容
 *     QSkinMentions       在**光标处**插入：`@` 之后的那个词才是查询词，
 *                       选中一条候选 = 只把 `@词` 这一段**换成** `@标签 `
 *
 * 判据：**选中候选之后，用户前面打的字还在不在？** 在 → Mentions。
 *
 * 所以本件必须知道"光标在哪、`@` 在哪、中间那个词是什么"。这三件事
 * 由 `_context()` 一个函数负责（光标左边扫最近的 `prefix`、右边不许出现
 * `split`）——**没有第二处**会去猜这个状态。
 *
 * ════════════════════════════════════════════════════════════════════════
 * `value` 是"插入过的项"，不是从 `text` 反解出来的
 * ════════════════════════════════════════════════════════════════════════
 * `value` 累积用户挑过的候选。它**不会**在用户手工删掉文中的 `@某人` 之后
 * 自动缩水 —— 那需要反向解析 `text`（要把 `@`、空格、标签里的空格都考虑
 * 进去，还要定义"标签被改了一个字算不算同一个"）。那是另一份契约，不是
 * 顺手能补的。
 *
 * 于是：需要"文中到底提了谁"的消费者，应当**自己解析 `text`**（格式是
 * `prefix + label + split`，词法简单）；`value` 只回答"用户挑过哪些"。
 * 写出来，而不是留一个"看起来在同步、其实会漂"的字段。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 三条**刻意的裁剪**
 * ════════════════════════════════════════════════════════════════════════
 * 1. **不做多触发符。** Ant 支持 `prefix: ['@', '#']` 这种数组。本件只收
 *    一个字符串 —— 多个触发符意味着候选集也要跟着分叉（`@` 找人、`#` 找
 *    话题），那是两份数据源，该由消费者摆两个组件或自己分发。
 *
 * 2. **不做富文本渲染。** 三家都有"高亮已提及的名字"的能力（Ant 的
 *    `style` / TDesign 的 `highlight`）。本件插的是纯文本 —— 富文本要
 *    换掉整个编辑内核（TextEdit → 带 doc 模型的控件），不是一层皮。
 *
 * 3. **光标用 `Keys.priority: Keys.BeforeItem`。** 这条不是裁剪而是必须：
 *    面板打开时上下键要**导航候选**，但 TextEdit 默认会拿上下键去移动
 *    光标。所以按键必须先到我们的 handler —— 见那个属性上的注释。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
/* ⚠ **不要**给这一句加版本号（原因同 QSkinQRCode.qml）*/
import QtQuick.Shapes
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 候选。字符串数组，或对象数组（配 `textRole`） */
    property var    options: []
    property string textRole: ""

    /* ══════════════════════ 值 ══════════════════════ */

    /** 文本框里的文字。双向 */
    property string text: ""
    /** 用户**挑过**的候选（累积）。不会因为手工删文而缩水 —— 见文件头 */
    property var    value: []

    /* ══════════════════════ 文案 ══════════════════════ */

    property string prefix: "@"
    /** 插入后跟的分隔符。也是"这个词说完了"的判据 */
    property string split:  " "
    property string placeholderText: qsTr("请输入，@ 可提及")
    property string emptyText: qsTr("无匹配项")

    /* ══════════════════════ 外观 ══════════════════════ */

    property bool enabled: true
    property bool allowClear: true
    property int  maxVisibleRows: 6
    property int  maxSuggestions: 0
    property int  rowHeight: Theme.size.controlMd
    property int  padding: Theme.space.md
    /** 文本框高度（Mentions 是多行的） */
    property int  inputHeight: Theme.size.controlLg * 2

    /* ══════════════════════ 交互态（插槽读）══════════════════════ */

    property bool hovered: false
    property bool pressed: false
    property bool error:   false

    /* ══════════════════════ 状态 ══════════════════════ */

    readonly property bool opened: popup.opened

    property int _activeIndex: -1

    /** 当前 `@` 语境：`{ start, word }`，或 `null`（光标不在任何 `@` 语境里）*/
    readonly property var _context: root._computeContext()

    readonly property bool _inMention: root._context !== null

    readonly property var suggestions: root._computeSuggestions()

    readonly property bool _isEmpty: root.suggestions.length === 0

    readonly property int _panelRows:
        Math.max(1, Math.min(suggestionsList.count, root.maxVisibleRows))

    /* ══════════════════════ 信号 ══════════════════════ */

    signal edited(string value)
    /** 插入了一条候选。`index` 是它在 `options` 里的**原下标** */
    signal selected(var item, int index)
    signal cleared()

    /* ══════════════════════ 尺寸 ══════════════════════ */

    implicitWidth:  240
    implicitHeight: root.inputHeight

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true

    Accessible.role:     Accessible.EditableText
    Accessible.name:     root.text !== "" ? root.text : root.placeholderText
    Accessible.editable: true

    /* ══════════════════════ 接口 ══════════════════════ */

    function open() {
        if (!root.enabled || !root._inMention) return
        popup.open()
    }
    function close() { popup.close() }

    function clear() {
        if (!root.enabled) return
        root.text  = ""
        root.value = []
        input.text = ""
        root._activeIndex = -1
        if (popup.opened) popup.close()
        root.edited("")
        root.cleared()
    }

    /** 在文末追加一个提及（不经过输入框 —— 给"从外部插一个"用）*/
    function appendMention(label) {
        var t = root.text
        /* 文末已经落在分隔符上就不再加一个：`appendMention` 自己就是以
         * 分隔符收尾的，连叫两次会得到两个空格（M26 冒烟实测）。 */
        var tail = (root.split === "") ? "" : t.slice(Math.max(0, t.length - root.split.length))
        var sep = (t === "" || (root.split !== "" && tail === root.split)) ? "" : root.split
        t = t + sep + root.prefix + label + root.split
        root.text  = t
        input.text = t
        input.cursorPosition = t.length
        root.edited(t)
    }

    /* ══════════════════════ 算路 ══════════════════════ */

    function _labelOf(it) {
        if (it === null || it === undefined) return ""
        if (root.textRole !== "" && typeof it === "object") {
            var v = it[root.textRole]
            return v === undefined || v === null ? "" : String(v)
        }
        return String(it)
    }

    /** 光标处的 `@` 语境。
     *
     *  规则两条，都只看向**光标左边**：
     *    · 从光标往左找最近的 `prefix`；找不到 → 不在提及里
     *    · 那个 `prefix` 之后到光标之间若已经含 `split` → 这段词已经说完了
     *
     *  刻意**不**处理"`@` 前面紧挨着字母"（email 里的 @）。三家都不处理，
     *  而处理它需要一个转义约定 —— 那会改掉插入格式，不是本地能决定的。 */
    function _computeContext() {
        var t = input.text
        if (t === undefined || t === null) return null
        var pos = input.cursorPosition
        if (pos <= 0) return null

        var idx = t.lastIndexOf(root.prefix, pos - 1)
        if (idx < 0) return null

        var word = t.substring(idx + root.prefix.length, pos)
        if (root.split !== "" && word.indexOf(root.split) >= 0) return null

        return { start: idx, word: word }
    }

    function _computeSuggestions() {
        if (!root._inMention) return []

        var src = root.options
        if (src === null || src === undefined) return []

        var out = []
        var i
        var word = root._context.word

        if (word === "") {
            var n = root.maxSuggestions > 0
                ? Math.min(root.maxSuggestions, src.length) : src.length
            for (i = 0; i < n; ++i)
                out.push({ item: src[i], index: i, text: root._labelOf(src[i]) })
            return out
        }

        var hits = FuzzyMatch.filterBy(word, src, {
            textOf: root._labelOf,
            limit:  root.maxSuggestions
        })
        for (i = 0; i < hits.length; ++i)
            out.push({ item: hits[i].item, index: hits[i].index, text: hits[i].text })
        return out
    }

    /** 把 `@词` 这一段换成 `@标签 ` —— 只动这一段，用户前面打的字一个不碰 */
    function _commit(i) {
        var list = root.suggestions
        if (i < 0 || i >= list.length) return

        var ctx = root._context
        if (ctx === null) return

        var row = list[i]
        var t   = input.text
        var cut = input.cursorPosition           // `@词` 的右边界 = 光标处

        var head = t.substring(0, ctx.start)
        var tail = t.substring(cut)
        var ins  = root.prefix + row.text + root.split

        var next = head + ins + tail
        input.text = next
        input.cursorPosition = (head + ins).length

        root.text = next
        root.value = root.value.concat([row.item])
        root._activeIndex = -1

        root.selected(row.item, row.index)
        popup.close()
        input.forceActiveFocus()
    }

    function _moveActive(dir) {
        var n = root.suggestions.length
        if (n === 0) return
        if (!popup.opened) { root.open(); return }

        var next = root._activeIndex + dir
        if (next < -1)    next = n - 1
        if (next > n - 1) next = 0
        root._activeIndex = next
    }

    /* ══════════════════════ 触发器 ══════════════════════ */

    Loader {
        id: backgroundLoader

        anchors.fill: parent
        sourceComponent: Slots.inputBackground

        Binding {
            target: backgroundLoader.item
            property: "control"
            value: root
            when: backgroundLoader.item !== null
        }
    }

    Item {
        id: textArea

        anchors.fill: parent
        anchors.leftMargin:   root.padding
        anchors.rightMargin:  root.padding + clearBox.width
        anchors.topMargin:    Theme.space.sm
        anchors.bottomMargin: Theme.space.sm

        TextEdit {
            id: input

            anchors.fill: parent

            text: root.text
            wrapMode: TextEdit.Wrap

            onTextChanged: {
                if (input.text === root.text) return
                root.text = input.text
                root._activeIndex = -1
                root.edited(root.text)
                /* ⚠ 这里读的是**函数**不是 `_inMention` 这个绑定 —— 见下面
                 * `onCursorPositionChanged` 里那段说明（同一条坑）。 */
                if (root.enabled && root._computeContext() !== null) popup.open()
                else if (popup.opened) popup.close()
            }

            /* 光标动了 → `@` 语境可能变了（用户可能往回走近那个 `@`）
             *
             * ⚠ **不能读 `root._inMention`**：它是 `_computeContext()` 的
             * 派生绑定，而"绑定是惰性的"这条法则在**信号处理器里**有更狠的
             * 一面 —— 触发器自己的那条 notify 已经发了，派生绑定却还没重算，
             * 于是处理器里读到的是**上一次**的值。最小复现
             * （`.cache/_ab/probe_lazy.qml`，一个 TextEdit + 一个派生绑定）：
             *     H1 cursorPosition=4 inMention=false     ← 处理器里（新光标、旧派生）
             *     SET cp=4 -> inMention=true              ← 紧接着读就是对的
             * 后果不是"偶尔慢一拍"，是面板**永远不开**（用户敲了 `@` 却看不到
             * 候选，只能去按上下键）。所以这里直接问函数 —— 函数读的是当下
             * 的 `input.text` / `input.cursorPosition`，拿的必是真值。 */
            onCursorPositionChanged: {
                if (!root.enabled) return
                root._activeIndex = -1
                if (root._computeContext() !== null) popup.open()
                else if (popup.opened) popup.close()
            }

            font.family:    Theme.font.family
            font.pixelSize: Theme.font.sm
            color:          root.enabled ? Theme.color.fg : Theme.color.fgDisabled

            selectionColor:    Theme.color.brandSubtle
            selectedTextColor: Theme.color.fg

            selectByMouse: true
            clip: true

            /* ── 上下键先给我们，再轮到 TextEdit ──────────────────────────
             * 面板开着时上下键必须**导航候选**；而 TextEdit 的默认行为是
             * 移动光标（它会 accept 掉，于是挂在后面的 `Keys` 根本不会跑）。
             * `Keys.priority: Keys.BeforeItem` 让我们的 handler 先行；
             * 面板没开时**不 accept**，按键照旧落回 TextEdit 移动光标。 */
            Keys.priority: Keys.BeforeItem
            Keys.onUpPressed: function(event) {
                if (popup.opened) { event.accepted = true; root._moveActive(-1) }
            }
            Keys.onDownPressed: function(event) {
                if (popup.opened) { event.accepted = true; root._moveActive(1) }
            }
            Keys.onReturnPressed: function(event) {
                /* 面板开着 → 回车选候选；没开 → 回车在文本框里**换行**
                 * （不 accept，落回 TextEdit）*/
                if (popup.opened) { event.accepted = true; root._commit(root._activeIndex) }
            }
            Keys.onEscapePressed: function(event) {
                event.accepted = true
                if (popup.opened) popup.close()
            }
        }

        Text {
            anchors.left:  input.left
            anchors.top:   input.top
            anchors.right: input.right
            visible: root.text === "" && root.placeholderText !== ""

            text:  root.placeholderText
            font:  input.font
            color: Theme.color.fgMuted

            wrapMode: Text.Wrap
            elide:    Text.ElideRight
            renderType: Text.NativeRendering
        }
    }

    /* 清空：自绘两条交叉线（与 QSkinTreeSelect / QSkinCascader / QSkinAutoComplete
     * 同一套做法，不开新插槽 —— 裁决三）。 */
    Item {
        id: clearBox

        visible: root.allowClear && root.text !== "" && root.hovered && root.enabled
        width:  Theme.size.controlSm
        height: Theme.size.controlSm
        anchors.right: parent.right
        anchors.top:   parent.top
        anchors.margins: Math.round((Theme.size.controlMd - Theme.size.controlSm) / 2)

        Shape {
            id: cross

            anchors.centerIn: parent
            width:  Math.max(8, Math.round(Theme.font.sm * 0.62))
            height: width

            preferredRendererType: Shape.CurveRenderer

            readonly property real sx: width
            readonly property real sy: height

            ShapePath {
                strokeColor: Theme.color.fgMuted
                strokeWidth: Math.max(1, Math.round(cross.sx * 0.13))
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                startX: cross.sx * 0.18
                startY: cross.sy * 0.18
                PathLine { x: cross.sx * 0.82; y: cross.sy * 0.82 }
            }
            ShapePath {
                strokeColor: Theme.color.fgMuted
                strokeWidth: Math.max(1, Math.round(cross.sx * 0.13))
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                startX: cross.sx * 0.82
                startY: cross.sy * 0.18
                PathLine { x: cross.sx * 0.18; y: cross.sy * 0.82 }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed:  root.pressed = true
            onReleased: root.pressed = false
            onClicked:  root.clear()
        }
    }

    /* 只跟踪 hover，不拦截点击（与 QSkinInput 同款）*/
    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.hovered = true
        onExited:  root.hovered = false
    }

    FocusRing { control: root }

    /* ══════════════════════ 浮层内容 ══════════════════════ */

    Item {
        id: panel

        visible: false
        anchors.fill: parent
        focus: true

        Keys.onUpPressed:     function(event) { event.accepted = true; root._moveActive(-1) }
        Keys.onDownPressed:   function(event) { event.accepted = true; root._moveActive(1) }
        Keys.onReturnPressed: function(event) { event.accepted = true; root._commit(root._activeIndex) }
        Keys.onEnterPressed:  function(event) { event.accepted = true; root._commit(root._activeIndex) }
        Keys.onEscapePressed: function(event) { event.accepted = true; popup.close() }

        ListView {
            id: suggestionsList

            anchors.fill: parent
            clip: true
            focus: false
            model: root.suggestions
            currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            delegate: mentionComp
        }

        Text {
            anchors.centerIn: parent
            visible: root._isEmpty
            text: root.emptyText
            font.family:    Theme.font.family
            font.pixelSize: Theme.font.sm
            color:          Theme.color.fgMuted
            renderType:     Text.NativeRendering
        }
    }

    /* 候选行引用了外层 id（root / Slots / suggestionsList）—— 与 QSkinSelect
     * 的 delegate 同款，局部关闭即可。
     * 注释首行不要以 qmllint 开头，否则会被当成指令解析。 */
    // qmllint disable unqualified

    Component {
        id: mentionComp

        Rectangle {
            id: mrow

            required property var modelData
            required property int index

            readonly property bool act: root._activeIndex === mrow.index

            property bool hovered: false

            width:  suggestionsList.width
            height: root.rowHeight

            color: mrow.act ? Theme.color.brandSubtle
                            : (mrow.hovered ? Theme.color.bgSubtle : "transparent")

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: mrow.hovered = true
                onExited:  mrow.hovered = false
                onPositionChanged: root._activeIndex = mrow.index
                onClicked: root._commit(mrow.index)
            }

            Loader {
                id: mrowLabel

                anchors.left:           parent.left
                anchors.leftMargin:     Theme.space.sm
                anchors.right:          parent.right
                anchors.rightMargin:    Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter

                sourceComponent: Slots.label

                Binding {
                    target: mrowLabel.item
                    property: "control"
                    value: mrowProxy
                    when: mrowLabel.item !== null
                }
            }

            QtObject {
                id: mrowProxy

                readonly property string text: mrow.modelData.text
                readonly property string variant: mrow.act ? "text" : "ghost"
                readonly property int labelAlignment: Text.AlignLeft
                readonly property bool enabled: root.enabled
            }
        }
    }

    // qmllint enable unqualified

    /* ══════════════════════ 浮层 ══════════════════════ */

    readonly property var overlayItem: overlayLoader.item
    readonly property real overlayExtender: root.overlayItem !== null
        && root.overlayItem.extender !== undefined ? root.overlayItem.extender : 0

    Popup {
        id: popup

        /* 面板贴着**光标那一行**会更好，但那要拿到 TextEdit 的行几何
         * （`positionToRectangle`），而在文本框里弹出会盖住下面的字。
         * 三家都是"贴控件下沿"，本件跟随。 */
        y: root.flipUp ? (root.overlayExtender - popup.height - Theme.space.xs)
                       : (root.height + Theme.space.xs - root.overlayExtender)

        width: root.width
        padding: root.overlayExtender

        background: Item {}

        contentItem: Loader {
            id: overlayLoader

            sourceComponent: Slots.selectOverlay

            Binding {
                target: overlayLoader.item
                property: "control"
                value: fakeControl
                when: overlayLoader.item !== null
            }
            Binding {
                target: overlayLoader.item
                property: "content"
                value: panel
                when: overlayLoader.item !== null
            }
        }

        contentWidth:  width
        contentHeight: root._panelRows * root.rowHeight

        onOpened: panel.forceActiveFocus()
        onClosed: root.pressed = false
    }

    readonly property int themePadding: Theme.space.xs

    QtObject {
        id: fakeControl

        readonly property int  count:          root._panelRows
        readonly property int  maxVisibleRows: root.maxVisibleRows
        readonly property int  rowHeight:      root.rowHeight
        readonly property real contentHeight:  root._panelRows * root.rowHeight
        readonly property real width:          popup.width
    }

    readonly property bool flipUp: {
        var win = Window.window
        if (!win) return false
        var gy    = root.mapToItem(win.contentItem, 0, 0).y
        var below = win.height - (gy + root.height)
        return below < popup.height + Theme.space.xs && gy > below
    }
}
