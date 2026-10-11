/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinTextarea
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 多行文本框。
 *
 * ── 它复用了 QSkinInput 的底板插槽 ────────────────────────────────────────
 * `Slots.inputBackground` 只有一份实现，两个控件共用。这不是省事，是
 * **验证契约层切对了地方**：那个插槽里全部的逻辑都是"error > focus >
 * hover > 常态"的四态优先级，而"输入框是圆的还是方的、单行还是多行"
 * 一条都不影响它。所以换肤时，文本框与输入框**必然一起变** —— 它们
 * 本来就不该长得不一样。
 *
 * ── 高度由"行数"算，不由"内容"算（一个刻意的取舍）──────────────────────
 * autoGrow 只跟随**换行符**（逻辑行），不跟随**折行**。理由是可核验性：
 * 折行数要等 TextEdit 度量完成才有值，属性侧读不到；硬算一个
 * `contentHeight / lineHeight` 得到的数**与渲染出来的不是同一个东西**
 * （字体回退一变就偏），于是断言只能写成"大概多少"——那就等于没有断言。
 *
 * 项目里那条规矩正是冲这个来的：**量法不能与被测量共享硬编码假设。**
 * 所以：
 *   · 逻辑行 → 可断言、可复现，autoGrow 跟它走；
 *   · 折行 → 由内部滚动承接（`clip: true`）。
 *
 * 代价说清楚：一行很长的文字在 autoGrow 下不会把框撑高。这是取舍，
 * 不是遗漏 —— 想要撑高就把 `rows` 设大，或者用固定的 `rows`。
 *
 * ── 字数上限是"截断"，而且**没有**"超限标红"那个分支 ────────────────────
 * `maxLength` 走**硬截断**：输入超限时把多余字符丢掉。与 Ant / TDesign
 * 的 `maxLength` 一致，而且让计数器永远不可能显示一个大于上限的数 ——
 * 它不可能说谎。
 *
 * 第一版还写了一个 `isOverLimit` + 计数器转 danger 的分支。实现成硬截断
 * 之后它**永远为假**：任何超限的文本在进到 root.text 之前就已经被剪掉了。
 * 一个恒为假的分支不是功能，是负债 —— 它既骗读代码的人（以为这里有
 * 处理），又骗覆盖率（那几行永远不会被执行到）。所以删掉。
 *
 * 这条与项目那句「清单上写着的格子，要么实现它，要么别写它」同源，
 * 只是这次被删的不是一格插槽，是一个属性。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

/* ── 为什么根是 FocusScope 而不是 Item ─────────────────────────────────
 * 输入类控件的底板要靠 `control.activeFocus` 判断"是否聚焦"（见
 * BasicInputBackground 的四态优先级）。而焦点真正的持有者是**里面那个
 * TextEdit** —— 用普通 Item 当根时，`root.activeFocus` 在用户开始打字
 * 的瞬间就变回 false，于是"聚焦提亮"只在点击的一瞬间闪一下，接着
 * 一直是未聚焦的样子。
 *
 * FocusScope 解决的正是这件事：只要焦点落在它**内部任意子项**上，
 * `activeFocus` 就为真。所以它是这类控件的正确根类型。
 *
 * 单独一提：QSkinInput（M2）的根是裸 Item，因此有同样的问题。
 * 本轮一并改掉了 —— 见 QSkinInput.qml 里的同名注释。 */
FocusScope {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    property string text: ""
    property string placeholderText: ""

    /** 校验失败态；优先级高于 focus，见 BasicInputBackground */
    property bool error: false

    /* ══════════════════════ 尺寸与增长 ══════════════════════ */

    /** 最小行数（同时也是固定高度模式下的行数）。 */
    property int rows: 3

    /** 随换行符增长。false 时高度恒定 = rows 行。 */
    property bool autoGrow: false

    /** 增长上限（行）。0 = 不限。只在 autoGrow 时有意义。 */
    property int maxRows: 0

    property int padding: Theme.space.md

    /* ══════════════════════ 字数 ══════════════════════ */

    /** 上限。0 = 不限。超限输入被**截断**（见文件头）。 */
    property int maxLength: 0

    /** 显示右下角计数器 */
    property bool maxCount: false

    /* ══════════════════════ 状态 ══════════════════════ */

    property bool hovered: false
    property alias readOnly: editor.readOnly

    signal accepted()
    signal editingFinished()

    /* ══════════════════════ 派生 ══════════════════════ */

    /** 一行的高度。取令牌而非常量 —— 行距属于主题（见 tokens.js 里
     *  lineHeightBody 的注释：它是 22/14 这个比值，不是 22）。 */
    readonly property int lineHeight:
        Math.round(Theme.font.sm * Theme.font.lineHeightBody)

    /** 计数器占的那条底边（含它与正文之间的呼吸）。 */
    readonly property int counterStrip: root.showCount ? root.counterHeight : 0
    readonly property bool showCount: root.maxCount && root.maxLength > 0

    /** 计数器文本的行高（比正文小一档） */
    readonly property int counterHeight: Math.round(Theme.font.xs * 1.4)

    /** 已输入字数。配合 maxCount 显示在右下角。 */
    readonly property int charCount: root.text.length

    /** 编辑器**当前真正持有**的文本。它与 `text` 应当永远相等 ——
     *  不相等就说明那条 `text: root.text` 的**绑定被打掉了**
     *  （截断写成直接赋 `editor.text` 就会这样：截断那一下生效了，
     *  但此后宿主再改 `text` 就推不进编辑器）。
     *
     *  为什么必须公开它：这个缺陷**只读 `text` 是看不见的** ——
     *  宿主写的就是 `text`，`charCount` 跟着它走，一切自洽；
     *  不一致的那一边在编辑器里。
     *
     *  与 `QSkinRate.fracAt()` 同一手法：**把属性侧与像素侧要量的
     *  那个数公开出来，两边指的是同一个东西**，「属性对而界面错」
     *  才无处可藏。（实测：smoke_m20 的 [3] 原本只读 charCount，
     *  对着"截断直写 editor.text"这个变异**逃掉了**。） */
    readonly property string editorText: editor.text

    /** 逻辑行数。**只数换行符**，不数折行 —— 见文件头。 */
    readonly property int logicalRows: root._countLines(root.text)

    /** 真正画出来的行数：下夹 rows，上夹 maxRows。
     *  maxRows 为 0 时不设上限（`Math.min(x, Infinity)` 即为 x）。 */
    readonly property int visibleRows:
        Math.min(root.maxRows > 0 ? root.maxRows : Number.MAX_VALUE,
                 Math.max(root.rows, root.autoGrow ? root.logicalRows : root.rows))

    implicitWidth:  240
    implicitHeight: root.visibleRows * root.lineHeight + root.padding * 2
                    + root.counterStrip

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true

    Accessible.role: Accessible.EditableText
    Accessible.name: root.placeholderText !== "" ? root.placeholderText : qsTr("多行文本框")
    Accessible.multiLine: true

    /* ══════════════════════ 插槽 ══════════════════════ */

    /* 与 QSkinInput 同一格 —— 文本框与输入框的底**必须**长得一样 */
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

    /* ══════════════════════ 正文 ══════════════════════ */

    TextEdit {
        id: editor

        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin:   root.padding
        anchors.rightMargin:  root.padding
        anchors.topMargin:    root.padding
        anchors.bottomMargin: root.padding + root.counterStrip

        text: root.text
        onTextChanged: {
            /* 硬截断。**只写 root.text，绝不写 editor.text** ——
             * `text: root.text` 是一条**绑定**，任何对 editor.text 的
             * 直接赋值（`editor.remove()` 也算）都会把这条绑定打掉，
             * 此后宿主再改 root.text 就同步不进来了。
             * 所以这里只把"应该是什么"告诉 root，由绑定去把它推回来。
             * （QSkinInput 从 M2 起就是这么做的，这里与它同构。）
             *
             * `return` 那一下也必要：截断后 root.text 变了、绑定会把
             * editor.text 更新一次，那次 onTextChanged 落到下面分支
             * 时两者已相等，不会来回震荡。 */
            if (root.maxLength > 0 && editor.length > root.maxLength) {
                root.text = editor.text.substring(0, root.maxLength)
                return
            }
            if (editor.text !== root.text) root.text = editor.text
        }

        font.family:    Theme.font.family
        font.pixelSize: Theme.font.sm
        color:          root.enabled ? Theme.color.fg : Theme.color.fgDisabled

        selectionColor:    Theme.color.brandSubtle
        selectedTextColor: Theme.color.fg

        wrapMode: TextEdit.Wrap
        selectByMouse: true
        clip: true
        persistentSelection: true

        /* Ctrl+Enter 提交。Keys 附加处理器默认在控件自身的 keyPressEvent
         * **之前**跑，所以置 accepted 能挡住"插入一个换行"。 */
        Keys.onPressed: function(event) {
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                && (event.modifiers & Qt.ControlModifier)) {
                event.accepted = true
                root.accepted()
            }
        }

        /* 失焦即"编辑完成"。用 activeFocus 而不是 focus —— 后者在
         * 焦点离开窗口时仍是 true。 */
        onActiveFocusChanged: if (!activeFocus) root.editingFinished()
    }

    /* ══════════════════════ 占位符 ══════════════════════ */

    Text {
        anchors.left:  editor.left
        anchors.right: editor.right
        anchors.top:   editor.top
        visible: root.text === "" && root.placeholderText !== ""

        text:  root.placeholderText
        font:  editor.font
        color: Theme.color.fgMuted

        wrapMode: Text.WordWrap
        elide: Text.ElideRight
    }

    /* ══════════════════════ 计数器 ══════════════════════ */

    /* 用裸 Text 而不是 Caption：计数器与正文一样受"禁用"影响
     * （禁用时该跟着变浅），而 Caption 的颜色是固定的。
     * 与 QSkinInput 的占位符同一处理 —— 辅助文字不占插槽。 */
    Text {
        id: counter

        anchors.right:  editor.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.padding - root.counterHeight * 0.25

        visible: root.showCount
        text:    root.charCount + " / " + root.maxLength

        font.family:    Theme.font.family
        font.pixelSize: Theme.font.xs
        color:          root.enabled ? Theme.color.fgMuted : Theme.color.fgDisabled
    }

    FocusRing { control: root }

    /* 只跟踪 hover，不拦截点击 */
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.hovered = true
        onExited:  root.hovered = false
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    /** 逻辑行数。空串算 1 行（否则空文本框会算出 0 行的高度）。 */
    function _countLines(s) {
        if (s === null || s === undefined || s === "") return 1
        return String(s).split("\n").length
    }

    /** 把焦点交给编辑器 —— 宿主点击控件空白处时用得上 */
    function forceEditorFocus() {
        editor.forceActiveFocus()
    }
}
