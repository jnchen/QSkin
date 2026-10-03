/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinButton
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 契约层的第一个控件。请对照着看它的分工：
 *
 *   ┌─ 这个文件负责（逻辑，换肤时**一行不动**）──────────────────┐
 *   │  状态机：hovered / pressed / checked / enabled             │
 *   │  键  盘：Tab 聚焦、Enter / Space 激活                       │
 *   │  无障碍：Accessible.role / name / checked / pressAction     │
 *   │  尺  寸：控件高度与内边距（尺寸是逻辑，不是皮肤）            │
 *   └────────────────────────────────────────────────────────────┘
 *
 *   ┌─ 插槽负责（视觉，换肤时**整个替换**）──────────────────────┐
 *   │  Slots.buttonBackground：圆角、底色、描边、按下态            │
 *   │  Slots.buttonContent  ：图标与文字的排布                    │
 *   │  Slots.label          ：字号、字重、颜色                    │
 *   └────────────────────────────────────────────────────────────┘
 *
 * 于是「写一套 Ant Design 主题」退化成「换三个插槽文件」，
 * 键盘、无障碍、状态机这些最容易写错的部分一次写对、到处复用。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    property string text: ""
    property url    iconSource: ""
    property int    iconSize: Theme.size.iconSm

    /** 画出来的图标（不是图片）。给 iconSource 填不上位置的场合用。
     *
     * ── 为什么要有这个，而不只是 iconSource ──────────────────────────
     * 项目里没有任何图标**资源**（没有 svg/png 素材目录），所以
     * iconSource 这条 url 通路到今天为止一次都没被真正用过。而
     * 「上下页 / 展开 / 折叠」这类控件需要的是**画出来的**字形 ——
     * 项目对这件事的既有结论很明确（见 BasicCheckIndicator /
     * QSkinSelect / QSkinTag / QSkinInputNumber 四份文件头）：
     * 图标用矢量画，不用字符，也不用外部素材。
     *
     * 所以这里给的是一个 Component，接的是 Slots 里的插槽 ——
     * 图标长什么样跟着主题走（线宽、端点、尺寸），与其它插槽一致。
     *
     * 用法：
     *     QSkinButton {
     *         icon: Slots.chevronIndicator
     *         accessibleName: "上一页"          // 图标按钮必须给
     *         onClicked: ...
     *     }
     */
    property Component icon: null

    /** 方向类图标（箭头）的朝向：up | down | left | right。
     *  只在 icon 是方向箭头时有意义；buttonContent 会把它翻译成
     *  图标插槽认识的 control.direction。 */
    property string iconDirection: "down"

    /* ══════════════════ 外观（给插槽读的语义标签） ══════════════════
     * 这里只声明"这是个主要按钮"，不决定它长什么样。
     * primary 在 TDesign 是蓝底 3px 圆角，在 shadcn 是黑底 6px 圆角 ——
     * 那是插槽的事。 */

    /** default | primary | danger | ghost | text */
    property string variant: "default"

    /** sm | md | lg */
    property string size: "md"

    /* ══════════════════════ 分组（QSkinButtonGroup） ══════════════════════
     *
     * 分组改变的是**圆角**：首尾各留一侧、中段四方（见
     * COVERAGE.md 第七节的 M27 裁决四）。圆角值四家不同，所以这个决定
     * 只能由主题回答 —— 于是它必须成为一条**契约字段**，插槽读
     * `control.groupPosition`。
     *
     * ── 为什么是绑定，不是父项在 onCompleted 里逐个赋值 ────────────────
     * 父项写 `child.groupPosition = ...` 会**打断绑定**，从此这个属性再也
     * 不跟随声明序 —— 那正是 M26 `QSkinTree` 记过的"用一会儿才坏"的 bug
     * （`_commitKeys` 直接赋值打断绑定）。写成绑定之后，读的是**当前**
     * 场景树，谁在组里第几个由 `QSkinButtonGroup.positionOf()` 现算。
     *
     * ── 与 QSkinTag 的关系（回归的护栏） ──────────────────────────────────
     * QSkinTag 复用 buttonBackground 这一格（见 QSkinTag 文件头），但它不是
     * 按钮组的成员 —— 于是读到默认值 "standalone"、四角全圆，**逐字不变**。
     * 这正是"新增契约字段必须带默认值"要起的作用：老消费者一行不改。
     */
    readonly property bool isGroupMember: true

    /** standalone（默认） | first | middle | last —— 父项算，插槽只读。 */
    readonly property string groupPosition: root._groupPositionOf(root.parent)

    /* ══════════════════════ 行为 ══════════════════════ */

    /** 无障碍名称，缺省回落到 text。图标按钮必须给。 */
    property string accessibleName: ""

    property bool checkable: false
    property bool checked: false

    /* ══════════════════════ 状态 ══════════════════════
     * 由下面的状态机写，插槽只读。见 Slots.qml 的契约三条。 */

    property bool hovered: false
    property bool pressed: false

    signal clicked()
    signal pressAndHold()
    signal toggled()

    /* ══════════════════════ 尺寸 ══════════════════════
     * 尺寸属于逻辑：主题可以改 controlSm/Md/Lg 的**值**，
     * 但不该由主题决定"按钮到底多高"。 */

    readonly property int controlHeight: root.size === "sm" ? Theme.size.controlSm
                                       : root.size === "lg" ? Theme.size.controlLg
                                       : Theme.size.controlMd

    readonly property int contentPadding: root.size === "sm" ? Theme.space.md
                                        : root.size === "lg" ? Theme.space.xl
                                        : Theme.space.lg

    /* Loader 的 implicitWidth 自动跟随被加载项的 implicitWidth，所以直接取
     * Loader 的即可。不要写 contentLoader.item.implicitWidth —— qmllint 会把
     * item 的静态类型当成 QObject，报 Member "implicitWidth" not found。 */
    implicitWidth: Math.max(root.controlHeight,
                            root.contentPadding * 2 + contentLoader.implicitWidth)
    implicitHeight: root.controlHeight

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true

    /* ══════════════════════ 无障碍 ══════════════════════ */

    Accessible.role:      root.checkable ? Accessible.CheckBox : Accessible.Button
    /* 图标按钮的 text 是空的，读屏软件会念成"按钮"甚至一个符号。
     * 实测 QSkinPagination 的上下页在改造前报的就是 "‹" —— 没有任何意义。
     * 所以留一个显式出口，缺省回落到 text。 */
    Accessible.name:      root.accessibleName !== "" ? root.accessibleName : root.text
    Accessible.checkable: root.checkable
    Accessible.checked:   root.checked
    Accessible.onPressAction: root._activate()

    /* ══════════════════════ 插槽 ══════════════════════
     *
     * 注入宿主引用用 Binding 而不是 onLoaded 回调：
     *   · 回调里写 item.control = root，qmllint 会按 QObject 做成员检查并报错
     *   · Binding 用字符串属性名，静态检查友好
     *   · 换肤导致 sourceComponent 变化时，Binding 会自动重新应用，
     *     不需要再写一遍 onLoaded 逻辑
     */

    Loader {
        id: backgroundLoader

        anchors.fill: parent
        sourceComponent: Slots.buttonBackground

        Binding {
            target: backgroundLoader.item
            property: "control"
            value: root
            when: backgroundLoader.item !== null
        }
    }

    Loader {
        id: contentLoader

        anchors.centerIn: parent
        sourceComponent: Slots.buttonContent

        Binding {
            target: contentLoader.item
            property: "control"
            value: root
            when: contentLoader.item !== null
        }

        /* label 插槽在这里接线，而不是在 Slots.qml 里：
         *   · Slots.qml 是 QtObject，没有 default property，放不了 Loader
         *   · Component 内部引用外部 id 会被 qmllint 判为 Unqualified access
         *   · 主题替换 Slots.label 之后，这个 Binding 会自动跟随更新，
         *     按钮文字跟着换肤，不需要通知任何人 */
        Binding {
            target: contentLoader.item
            property: "labelDelegate"
            value: Slots.label
            when: contentLoader.item !== null
        }

        /* 图标插槽同理。注意 value 就是 root.icon，可能为 null ——
         * 那时 buttonContent 退回 Image + iconSource。 */
        Binding {
            target: contentLoader.item
            property: "iconDelegate"
            value: root.icon
            when: contentLoader.item !== null
        }
    }

    FocusRing { control: root }

    /* ══════════════════════ 交互 ══════════════════════ */

    MouseArea {
        id: ma

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onEntered:  root.hovered = true
        onExited:   root.hovered = false
        onCanceled: root.pressed = false
        onReleased: root.pressed = false

        onPressed: function(mouse) {
            if (mouse.button !== Qt.LeftButton) return
            root.pressed = true
            root.forceActiveFocus()
        }
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) root._activate()
        }
        onPressAndHold: root.pressAndHold()
    }

    /* 键盘：Enter / Space 激活，且 Space 要有按下反馈。
     * 信号参数必须写成 function(event) —— 直接写 `event.accepted = true`
     * 会触发 qmllint 的 Unqualified access。 */
    Keys.onReturnPressed: root._activate()
    Keys.onEnterPressed:  root._activate()
    Keys.onSpacePressed: function(event) { event.accepted = true; root.pressed = true }
    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Space) {
            event.accepted  = true
            root.pressed = false
            root._activate()
        }
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    /**
     * 问父项"我在组的第几个"。父项不是按钮组时回落到 standalone。
     *
     * 为什么要过一层函数、而不是直接写 `root.parent.isButtonGroup`：
     * `parent` 的静态类型是 QQuickItem，qmllint 会按它做**成员检查**并报
     * Member "isButtonGroup" not found（同一条理由让插槽把 `control`
     * 声明成 var —— 见 BasicButtonBackground 的注释）。函数参数没有类型
     * 标注时是 var，检查就停在边界上。
     */
    function _groupPositionOf(p) {
        if (!p || p.isButtonGroup !== true) return "standalone"
        return p.positionOf(root)
    }

    function _activate() {
        if (!root.enabled) return
        if (root.checkable) {
            root.checked = !root.checked
            root.toggled()
        }
        root.clicked()
    }
}
