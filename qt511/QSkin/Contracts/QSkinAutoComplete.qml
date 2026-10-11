/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinAutoComplete
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 自动完成：一个输入框 + 一份随输入实时过滤的候选。M26 新增。
 *
 * ── 为什么值得做（覆盖面口径）────────────────────────────────────────
 * Ant 5.x（`AutoComplete`）、Arco（`AutoComplete`）、TDesign（`AutoComplete`）
 * 三家都有。shadcn 没有独立件（它把这件事归到 Combobox 的用法说明里）。
 * 三家在契约上高度一致：一个受控的 `value`（输入文字）+ 一份 `options`
 * + 一个 `onSelect`。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 过滤走 `FuzzyMatch.filterBy` —— 候选**不是**"包含就留下"
 * ════════════════════════════════════════════════════════════════════════
 * 打分规则（连续命中 +8、词边界 +6、单字 +1）在 `FuzzyMatch.js` 里只有
 * 一份实现，本件只是它的**第二个消费者**（第一个是 QSkinTreeSelect 的搜索）。
 * 这正是 M26 裁决四要的局面：过滤下沉进地基、不下沉进控件。
 *
 * 两条由 `filterBy` 定义、本件**照抄不重新解释**的语义：
 *   · 并列分数取**原顺序**（`out.sort` 里 `a.index - b.index`）
 *   · 空查询返回 **0 项** —— 所以本件在 `text === ""` 时**自己**返回全部，
 *     而不是把空串喂给 filterBy 然后困惑于"为什么一条都没有"
 *
 * ════════════════════════════════════════════════════════════════════════
 * 输入框是**自绘**的，不是复用 QSkinInput（一个刻意的选择，理由在这）
 * ════════════════════════════════════════════════════════════════════════
 * QSkinInput 的 `text` 是双向的（`text: root.text` + `onTextChanged` 写回），
 * 看着可以直接用。但"选中候选后把 label 填进输入框"要求**程序化设值**
 * 能生效 —— 而 QML 的 TextInput 在用户打字时会打破 `text:` 绑定，于是
 * QSkinInput 内部那个 `text: root.text` 在那之后就不成立了。
 *
 * 也就是说：复用会让"回填"这条**核心路径**依赖一个未经验证的假设。
 * 所以本件自己持有一个 TextInput（外观仍走 `Slots.inputBackground`
 * 外壳，字体/颜色仍走令牌），把文字的生命周期完全握在手里。
 *
 * 📌 遗留：`QSkinInput` 在"用户打过字之后，外部程序化设 text 是否能生效"
 * 这一点**尚未实测**。它影响的不止本件（表单回填、联动赋值都会踩）。
 * M26 收口时在 `COVERAGE.md` 里挂着，冒烟阶段实测。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 两条**刻意的裁剪**
 * ════════════════════════════════════════════════════════════════════════
 * 1. **不做异步取数。** Ant 的 `AutoComplete` 可以只在 `onSearch` 里自己
 *    去请求（它不管数据）。本件是**本地过滤**控件（`options` 给什么就
 *    过滤什么）。要远程取数的话，消费者的正确姿势是订阅 `edited(text)`
 *    自己去拉、再把结果塞回 `options` —— 那样"加载中/失败"的状态归消费者
 *    （它有网络上下文），而不是在这里藏一个看不见的请求。
 *
 * 2. **不做多选 / 标签。** Ant 的 `mode="multiple"` 那是另一件东西
 *    （值变成数组、输入框里出现可删的标签、还要处理光标与分隔符）。
 *    没有第二个设计系统背书（TDesign 的 AutoComplete 也没多选），不做
 *    半截。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Window 2.11
import QtQuick.Controls 2.4
/* ⚠ **不要**给这一句加版本号 —— 带版本号会让 `Shape` 的
 * `preferredRendererType` 附加属性整个不可用（清空按钮的两条斜线会
 * 渲染成硬边阶梯）。同一条已在 `QSkinQRCode.qml` 记过。 */
import QtQuick.Shapes 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 候选。字符串数组，或对象数组（配 `textRole`） */
    property var    options: []
    /** 对象候选里哪个字段是显示文字。空串 = 用 `String(item)` */
    property string textRole: ""

    /* ══════════════════════ 值 ══════════════════════ */

    /** 输入框里的文字。双向：用户打字写它，程序也能写它 */
    property string text: ""
    /** 选中过的候选（原始项）。用户改了字之后**不自动清空** ——
     *  那是消费者的判断（比对 `value` 与当前 `text` 即可） */
    property var    value: null

    /* ══════════════════════ 文案 ══════════════════════ */

    property string placeholderText: qsTr("请输入")
    property string emptyText: qsTr("无匹配项")

    /* ══════════════════════ 外观 ══════════════════════ */

    property bool enabled: true
    property bool allowClear: true
    /** 焦点进来就展开（Ant 的 `defaultOpen` / 受控 `open` 的合并体） */
    property bool openOnFocus: true
    property int  maxVisibleRows: 7
    /** 最多给几条候选。0 = 不限 */
    property int  maxSuggestions: 0
    property int  rowHeight: Theme.size.controlMd
    property int  padding: Theme.space.md

    /* ══════════════════════ 交互态（插槽读）══════════════════════ */

    property bool hovered: false
    property bool pressed: false
    property bool error:   false

    /* ══════════════════════ 状态 ══════════════════════ */

    readonly property bool opened: popup.opened

    /** 键盘光标；`-1` = 没有光标（用户还没按过方向键）*/
    property int _activeIndex: -1

    /** 过滤后的候选。形状统一为 `{ item, index, text }`：
     *  `index` 是它在 **`options` 里的原下标**（`filterBy` 的契约） */
    readonly property var suggestions: root._computeSuggestions()

    readonly property bool _isEmpty: root.suggestions.length === 0

    /** 面板要画几行。候选数被 `maxVisibleRows` 夹住 —— 多出来的部分靠
     *  `ListView` 自己滚，而不是把面板拉到屏幕外。至少 1 行，好让空态
     *  有一格地方站。 */
    readonly property int _panelRows:
        Math.max(1, Math.min(suggestionList.count, root.maxVisibleRows))

    /* 触发器伪装成"控件"给 Slots.label 读 */
    readonly property string variantName: "default"

    /* ══════════════════════ 信号 ══════════════════════ */

    /** 用户改了输入文字（打字或清空）*/
    signal edited(string value)
    /** 选中了一条候选。`index` 是它在 `options` 里的**原下标** */
    signal selected(var item, int index)
    signal cleared()

    /* ══════════════════════ 尺寸 ══════════════════════ */

    implicitWidth:  240
    implicitHeight: Theme.size.controlMd

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true

    Accessible.role:     Accessible.ComboBox
    Accessible.name:     root.text !== "" ? root.text : root.placeholderText
    Accessible.editable: true
    Accessible.onPressAction: root.open()

    /* ══════════════════════ 接口 ══════════════════════ */

    function open() {
        if (!root.enabled) return
        root._activeIndex = -1
        popup.open()
    }
    function close() {
        popup.close()
    }
    /** 收键盘并把输入框清空 —— 同时清 `value`（"清空"是清这一整件事，
     *  不是只擦掉文字；要只擦文字的话直接写 `text: ""`） */
    function clear() {
        if (!root.enabled) return
        if (root.text === "" && root.value === null) return
        root.text  = ""
        root.value = null
        root._activeIndex = -1
        input.text = ""
        if (popup.opened) popup.close()
        root.edited("")
        root.cleared()
    }

    /* ══════════════════════ 算路 ══════════════════════ */

    /** 一条候选的显示文字。与 QSkinTabs 的 `_titleOf` 同一条规则：
     *  给了 textRole 且项是对象 → 取那个字段；否则 `String(item)` */
    function _labelOf(it) {
        if (it === null || it === undefined) return ""
        if (root.textRole !== "" && typeof it === "object") {
            var v = it[root.textRole]
            return v === undefined || v === null ? "" : String(v)
        }
        return String(it)
    }

    function _computeSuggestions() {
        var src = root.options
        if (src === null || src === undefined) return []

        var out = []
        var i

        if (root.text === "") {
            /* 空查询 → 全部。**这一支是刻意冗余，不是必需品**：`FuzzyMatch.score`
             * 对空 query 返回 `{ score: 0, hits: [] }` —— 是个对象，于是
             * `filterBy` 里 `if (r)` 为真、全量进结果，直接走 `filterBy` 与
             * 这一支**等价**。判据在 `tools/check-fuzzy-match.js` 第 149 行
             * （「空 query：全量、0 分、零命中」）。
             *
             * ⚠ 这里原先写着「`filterBy` 对空查询刻意返回 0 项，所以这个分支
             * 必须在这里写出来」—— **那句话是错的**，M26 的变异测试把它量出来了
             * （`.cache/mutate_m26.py` 的 G1：短路这一支，退出码照样 0）。
             * 留着它是为了把「空文本框展开就有得选」写在控件这一层，
             * 不把这件事外包给底层的一个隐式性质。 */
            var n = root.maxSuggestions > 0
                ? Math.min(root.maxSuggestions, src.length) : src.length
            for (i = 0; i < n; ++i)
                out.push({ item: src[i], index: i, text: root._labelOf(src[i]) })
            return out
        }

        var hits = FuzzyMatch.filterBy(root.text, src, {
            textOf: root._labelOf,
            limit:  root.maxSuggestions
        })
        for (i = 0; i < hits.length; ++i) {
            out.push({ item: hits[i].item, index: hits[i].index, text: hits[i].text })
        }
        return out
    }

    function _commit(i) {
        var list = root.suggestions
        if (i < 0 || i >= list.length) return

        var row = list[i]
        root.value = row.item
        root.text  = row.text
        root._activeIndex = -1

        /* 直写输入框：`text: root.text` 那条绑定在用户打过字之后就已经
         * 被 TextInput 打破了，所以"回填"不能只靠改 `root.text`。
         * 这里先改契约、再直写控件；两者写完后相等，`onTextChanged`
         * 里的回写条件因此不成立，不会绕回来。 */
        input.text = row.text

        root.selected(row.item, row.index)
        popup.close()
        root.forceActiveFocus()
    }

    function _moveActive(dir) {
        var n = root.suggestions.length
        if (n === 0) return
        if (!popup.opened) { root.open(); return }

        var next = root._activeIndex + dir
        if (next < -1)   next = n - 1
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
        anchors.leftMargin:  root.padding
        anchors.rightMargin: root.padding + clearBox.width

        TextInput {
            id: input

            anchors.left:           parent.left
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter

            text: root.text
            onTextChanged: {
                if (input.text === root.text) return
                root.text = input.text
                root._activeIndex = -1
                root.edited(root.text)
                /* 有候选才展开；候选空时若面板已开则**保持开着**显示空态
                 * （用户正在输入，面板忽然自己收掉比显示"无匹配项"更糟）*/
                if (root.enabled && root.suggestions.length > 0) popup.open()
            }
            onAccepted:      root._commit(root._activeIndex)
            onEditingFinished: if (popup.opened && root._activeIndex < 0) popup.close()

            font.family:    Theme.font.family
            font.pixelSize: Theme.font.sm
            color:          root.enabled ? Theme.color.fg : Theme.color.fgDisabled

            selectionColor:    Theme.color.brandSubtle
            selectedTextColor: Theme.color.fg

            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            clip: true

            onActiveFocusChanged: {
                if (input.activeFocus && root.openOnFocus && root.enabled) root.open()
            }

            Keys.onEscapePressed: function(event) {
                event.accepted = true
                if (popup.opened) popup.close()
                else              root.clear()
            }
        }

        Text {
            anchors.left:           input.left
            anchors.right:          input.right
            anchors.verticalCenter: input.verticalCenter
            visible: root.text === "" && root.placeholderText !== ""

            text:  root.placeholderText
            font:  input.font
            color: Theme.color.fgMuted

            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }

    /* 清空：自绘两条交叉线（与 QSkinTreeSelect / QSkinCascader 同一套做法，
     * 不开新插槽 —— 裁决三）。 */
    Item {
        id: clearBox

        visible: root.allowClear && root.text !== "" && root.hovered && root.enabled
        width:  Theme.size.controlSm
        height: parent.height
        anchors.right: parent.right
        anchors.rightMargin: Math.round((Theme.size.controlMd - Theme.size.controlSm) / 2)

        Shape {
            id: cross

            anchors.centerIn: parent
            width:  Math.max(8, Math.round(Theme.font.sm * 0.62))
            height: width


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

    /* 只跟踪 hover，不拦截点击 —— 与 QSkinInput 同款（见那份文件头的说明） */
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
            id: suggestionList

            anchors.fill: parent
            clip: true
            focus: false
            model: root.suggestions
            currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            delegate: suggestionComp
        }

        /* 空态放在 ListView **外面**（放里面会跟着内容滚） */
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

    /* 候选行引用了外层 id（root / Slots / suggestionList）—— 与 QSkinSelect
     * 的 delegate 同款，局部关闭即可。
     * 注释首行不要以 qmllint 开头，否则会被当成指令解析。 */
    // qmllint disable unqualified

    Component {
        id: suggestionComp

        Rectangle {
            id: srow

            property var modelData
            property int index

            readonly property bool act: root._activeIndex === srow.index

            width:  suggestionList.width
            height: root.rowHeight

            color: srow.act ? Theme.color.brandSubtle
                            : (srow.hovered ? Theme.color.bgSubtle : "transparent")

            property bool hovered: false

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: srow.hovered = true
                onExited:  srow.hovered = false
                /* 划过就移动光标 —— "指到哪儿"与"回车选中哪儿"必须是同一处 */
                onPositionChanged: root._activeIndex = srow.index
                onClicked: root._commit(srow.index)
            }

            Loader {
                id: srowLabel

                anchors.left:           parent.left
                anchors.leftMargin:     Theme.space.sm
                anchors.right:          parent.right
                anchors.rightMargin:    Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter

                sourceComponent: Slots.label

                Binding {
                    target: srowLabel.item
                    property: "control"
                    value: srowProxy
                    when: srowLabel.item !== null
                }
            }

            QtObject {
                id: srowProxy

                readonly property string text: srow.modelData.text
                readonly property string variant: srow.act ? "text" : "ghost"
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

        y: root.flipUp ? (root.overlayExtender - popup.height - Theme.space.xs)
                       : (root.height + Theme.space.xs - root.overlayExtender)

        /* 面板宽 = 控件宽（定宽，不走外壳 implicitWidth —— 那条会与
         * control.width 形成循环引用，QSkinMenu 在 M4 记过这笔）。 */
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

        onOpened:  panel.forceActiveFocus()
        onClosed:  root.pressed = false
    }

    /** 外壳在面板四周留的空白。从外壳自己的实现里读同一个令牌 ——
     *  比"抄一个数"少一处会漂的地方。 */
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

    /* ══════════════════════ 键盘（触发器上）══════════════════════ */

    Keys.onDownPressed:   function(event) { event.accepted = true; root._moveActive(1) }
    Keys.onUpPressed:     function(event) { event.accepted = true; root._moveActive(-1) }
    Keys.onReturnPressed: function(event) { event.accepted = true; root._commit(root._activeIndex) }
    Keys.onEnterPressed:  function(event) { event.accepted = true; root._commit(root._activeIndex) }
    Keys.onEscapePressed: function(event) {
        event.accepted = true
        if (popup.opened) popup.close()
        else              root.clear()
    }
}
