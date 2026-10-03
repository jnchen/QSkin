/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinInput
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 单行输入框。
 *
 * 两个值得说明的决定：
 *
 *   1. hover 用 acceptedButtons: Qt.NoButton 的 MouseArea 跟踪。
 *      普通的 MouseArea 会吞掉点击，TextInput 就拿不到焦点了。
 *      NoButton 的 MouseArea 只接收位置事件，不参与按键派发。
 *
 *   2. placeholder 不进 label 插槽。
 *      它是"提示"而不是"内容"：跟正文字号一致、颜色更淡、不参与换行。
 *      做成插槽只会让主题作者多一个要关心的东西，收益却是零。
 *
 * 宽度给了 200 的默认值：Web 的 input 有默认宽度，Qt 的 TextInput 默认 0，
 * 放进布局里会直接消失 —— 这是"原始感"的典型来源之一。
 *
 * ════════════════════════════════════════════════════════════════════════
 * M30 · 输入族的三个补充形态（Search / Password / InputGroup）
 * ════════════════════════════════════════════════════════════════════════
 * 这三件**都不是新控件**，而是本件上的「语义位 + Component 槽」：
 *
 *   · Search   → `prefix`（放大镜） + `suffix`（清空钮）
 *   · Password → `echoMode: "password"` + `revealed`（显隐由宿主切）
 *   · 成组     → `groupPosition`（父项算，子项只读）
 *
 * 图标一律**不内建**：本件只提供"这儿有个位置"，画什么是宿主的事。
 * 与 QSkinButton.icon 是同一条 —— 控件里没有一笔属于某个设计系统的墨。
 * 可抄的写法在 `examples/` 的输入族例子里。
 *
 * ── `implicitWidth` 为什么还是 200（不随前后缀变） ────────────────────
 * 加前后缀最容易犯的错是把它们"接"在 200 之外 —— 那会让**所有既有
 * 消费者的宽度集体变化**，是纯回归。这里的取法是：200 是**整件的**
 * 缺省宽，前后缀从里面挤（正文区变窄）。于是"没设前后缀 ⇒ 逐字不变"
 * 是**数学上成立**的，不靠谁记得别改。
 * 另：宽度也**不该**跟着文字长 —— 打字时宽度跳动是无法接受的，
 * 所以 implicit 里不含 `contentWidth`。
 *
 * ════════════════════════════════════════════════════════════════════════
 * M30 · 把 M26 挂着的那笔欠账结清：「程序化设值」实测有效
 * ════════════════════════════════════════════════════════════════════════
 * 本件的 `text` 是双向的（`text: root.text` + `onTextChanged` 写回），而 QML 的
 * `TextInput` 在**用户打字时会打破 `text:` 这条绑定** —— 那之后「外部写
 * `root.text`」还能不能落到屏幕上，M26 时**没人实测过**，于是
 * `QSkinAutoComplete` 当初宁愿自绘输入框（不把回填建在未验证的假设上）。
 *
 * M30 实测（`.cache/_probe_m30g.qml` A 系列，24/24 全过）：**四项都成立**。
 *   · 程序化写 `root.text` → 落到屏幕上；
 *   · 不被反向覆盖；
 *   · 清空（写 `""`）生效；
 *   · 长值透传，`displayText` 非空。
 * ⇒ 表单回填 / 联动赋值 / 编辑态初始化都可以放心走本件。
 * ⚠ 这条**不构成** `QSkinAutoComplete` 的回改理由：它当初的取舍是「不把回填建在
 * 未验证的假设上」，现在假设验证了，但自绘已落地且有自己的判据 ——
 * **没有收益就不动**。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

/* ── 为什么根是 FocusScope 而不是 Item（M20 修正）─────────────────────
 * 底板插槽靠 `control.activeFocus` 判断是否聚焦，而焦点真正的持有者是
 * **里面那个 TextInput**。用裸 Item 当根时，`root.activeFocus` 在用户
 * 真正开始打字的那一刻就变回 false —— 于是"聚焦提亮 + 品牌色描边"
 * 只在点击的一瞬间闪一下，接着一直是未聚焦的样子，而键盘正打得起劲。
 *
 * 这个缺陷在属性侧完全看不见（`activeFocus` 是 Qt 自己的属性，谁都
 * 没写错），静态截图里也看不见（抓图时没有任何控件持有焦点）。
 * 抓它的是 M20 给 QSkinTextarea 做焦点态时对照出来的 —— 两个控件根
 * 类型不同，行为却必须一致，于是那个不同自己浮上来了。
 *
 * FocusScope 正是为此而存在：焦点落在它**内部任意子项**上时，
 * `activeFocus` 即为真。它本身就是 Item 的子类，别处一字不用改。 */
FocusScope {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    property string text: ""
    property string placeholderText: ""

    /** 校验失败态；优先级高于 focus，见 BasicInputBackground */
    property bool error: false

    /* ══════════════════════ 前后缀（M30） ══════════════════════ */

    /* 宿主给一个 Component，本件只负责"排在哪、占多宽"。
     * 与 QSkinButton.icon 同构 —— 那里也是 Button 排、内容归宿主。
     * 空（null）时**一个像素都不占**，所以不设前后缀的既有消费者不受影响。 */
    property Component prefix: null
    property Component suffix: null

    /** 前后缀与正文之间的空隙。只在前/后缀真存在时计入。 */
    property int affixGap: Theme.space.sm

    /* 两边各让出多少（含空隙）。用 Loader 自己的 implicitWidth ——
     * Loader 会自动跟随被加载项的 implicitWidth；不要写 `.item.implicitWidth`，
     * qmllint 把 item 的静态类型当 QObject，会报 Member not found
     * （QSkinButton 的 implicitWidth 注释里记过同一条）。 */
    readonly property int prefixSlot: root.prefix !== null
                                      ? root.affixGap + prefixLoader.implicitWidth : 0
    readonly property int suffixSlot: root.suffix !== null
                                      ? root.affixGap + suffixLoader.implicitWidth : 0

    /* ══════════════════════ 密码（M30） ══════════════════════ */

    /** "normal" | "password"。本件不画眼睛 —— 显隐开关由宿主放进 prefix/suffix。 */
    property string echoMode: "normal"

    /** 仅在 echoMode === "password" 时有意义。宿主切换它来"显示密码"。 */
    property bool revealed: false

    /* Qt 的枚举值不进契约：宿主写 "password"，主题侧一个字都不用知道。
     * 实测枚举（探针 G）：Normal=0 / NoEcho=1 / Password=2 / PasswordEchoOnEdit=3 */
    readonly property int effectiveEchoMode:
        root.echoMode !== "password" ? TextInput.Normal
      : root.revealed                ? TextInput.Normal
                                     : TextInput.Password

    /* ══════════════════════ 成组（M30） ══════════════════════
     * 与 QSkinButton 同款：拉模型 —— 子项问父项"我在第几个"，而不是父项
     * 逐个赋值（赋值会打断绑定，且要等 onCompleted）。见 QSkinButtonGroup
     * 文件头里那两条实测（兄弟 onCompleted 逆序 / children 参与绑定会更新）。
     *
     * `isGroupMember` 恒为 true：本件永远是"潜在的组成员"，位置由父项定。
     * 父项不是组（或没有父项）时读到 "standalone"、四角全圆 —— 这正是
     * "新增契约字段必须带默认值"要起的作用：老消费者一行不改。 */
    readonly property bool isGroupMember: true

    /** standalone（默认） | first | middle | last —— 父项算，插槽只读。 */
    readonly property string groupPosition: root._groupPositionOf(root.parent)

    /* ══════════════════════ 状态 ══════════════════════ */

    property bool hovered: false
    property int  padding: Theme.space.md

    signal accepted()
    signal editingFinished()

    /* ══════════════════════ 尺寸 ══════════════════════ */

    /* 200 = **整件**的缺省宽（前后缀从里面挤，见文件头）。
     * 原样保留 —— 改它等于改所有既有消费者的布局。 */
    implicitWidth:  200
    implicitHeight: Theme.size.controlMd

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true

    Accessible.role: Accessible.EditableText
    Accessible.name: root.placeholderText !== "" ? root.placeholderText : qsTr("输入框")

    /* ══════════════════════ 插槽 ══════════════════════ */

    /* 用 Binding 注入宿主引用，而不是 onLoaded 回调 —— 理由见
     * QSkinButton.qml 中的同名注释。 */
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

    /* ══════════════════════ 前后缀（M30） ══════════════════════
     * 排布归本件、内容归宿主 —— 见文件头的三条判决。
     * 竖向上与正文同心地贴在两端。 */

    Loader {
        id: prefixLoader

        sourceComponent: root.prefix

        anchors.left:           parent.left
        anchors.leftMargin:     root.padding
        anchors.verticalCenter: parent.verticalCenter
    }

    Loader {
        id: suffixLoader

        sourceComponent: root.suffix

        anchors.right:          parent.right
        anchors.rightMargin:    root.padding
        anchors.verticalCenter: parent.verticalCenter
    }

    /* ══════════════════════ 正文 ══════════════════════ */

    /* padding 只走水平 —— 上下让 TextInput 占满控件高度，
     * verticalAlignment: AlignVCenter 才能真正在 controlMd(32) 里居中。
     * 之前 anchors.fill + anchors.margins:padding 让 TextInput 高度
     * 缩成 controlMd-2*padding=8px，文字在这 8px 里居中当然偏下。 */
    TextInput {
        id: input

        anchors.left:           parent.left
        anchors.right:          parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin:     root.padding + root.prefixSlot
        anchors.rightMargin:    root.padding + root.suffixSlot

        text: root.text
        onTextChanged: if (input.text !== root.text) root.text = input.text
        onAccepted: root.accepted()
        onEditingFinished: root.editingFinished()

        echoMode: root.effectiveEchoMode

        font.family:    Theme.font.family
        font.pixelSize: Theme.font.sm
        color:          root.enabled ? Theme.color.fg : Theme.color.fgDisabled

        selectionColor:    Theme.color.brandSubtle
        selectedTextColor: Theme.color.fg

        verticalAlignment: TextInput.AlignVCenter
        selectByMouse: true
        clip: true
    }

    /* ══════════════════════ 占位符 ══════════════════════ */

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
    }

    FocusRing { control: root }

    /* 只跟踪 hover，不拦截点击 —— 见文件头说明 */
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.hovered = true
        onExited:  root.hovered = false
    }

    /* ══════════════════════ 内部方法 ══════════════════════ */

    /* 过一层函数的原因与 QSkinButton._groupPositionOf 相同：`parent` 的静态
     * 类型是 QQuickItem，直接写 `parent.isInputGroup` 会被 qmllint 按
     * QQuickItem 做成员检查。函数参数没类型标注 = var。 */
    function _groupPositionOf(p) {
        if (!p || p.isInputGroup !== true) return "standalone"
        return p.positionOf(root)
    }
}
