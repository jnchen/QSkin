/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinColorPicker
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 取色器：触发器上一个色块，面板里一条**色域面** + 一条**色相条** + 一排
 * 预设色。M26 新增。
 *
 * ── 为什么值得做（覆盖面口径）────────────────────────────────────────
 * Ant 5.x、Arco、TDesign 三家都有 ColorPicker；shadcn 没有（那是第三方
 * 拼的）。三家在"面板里有什么"这件事上高度一致：一个二维取色面、一条
 * 色相滑轨、一排预设。所以本件不是猜的形态。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 色域面 / 色相条 / 色板是**控件自绘**，不走主题（M26 裁决三）
 * ════════════════════════════════════════════════════════════════════════
 * 本文件里出现了一些**写死的色值**（`#FF0000`、`#FFFFFF`、`#000000`）。
 * 它们不是"没走主题的疏漏"，而是刻意的：
 *
 *     这些是**算法结果的显示**，不是主题差异。
 *
 * 色相条的七个停靠点就是 `hsvToRgb(60k, 1, 1)` 的六个顶点 + 首色回卷 ——
 * 换了主题它也不会变成别的颜色（那样反而错）。同一个道理：色域面的
 * "白 → 纯色相"与"透明 → 黑"两层叠加是 **s/v 坐标的定义**，不是外观。
 *
 * 对照：勾选框的勾、箭头的形状、下划线的粗细 —— 那些每家不一样，所以
 * 走插槽。这里没有新插槽（裁决三：M26 零新增插槽，白名单仍是 21 格）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 色相是**内部状态**，不是从 value 反推出来的（这条决定手感）
 * ════════════════════════════════════════════════════════════════════════
 * `value` 是 `color` 类型（0..255 由浮点承载），而 HSV 是从它反算的。
 * 反算有量化误差，误差量级由 `d = s·v` 决定（`ColorUtil.js` 文件头有一张
 * 实测表：d=0.01 → 色相误差可达 29°）。
 *
 * 后果：如果每次拖动都"改 value → 从 value 反推 hue → 画色相条"，那么
 * 把光标拖到色域面**左上角**（s=0，纯白）时色相**无处可推**（白色没有
 * 色相），色相条会自己跳回 0°—— 用户手感是"滑到边缘色相就丢了"。
 *
 * 所以三件事分开：
 *     `_hueState` / `_satState` / `_valState`  拖动时的**真值**，只增不减
 *     `value`                                  对外契约，由 state 算出
 *     外部改 `value` 时                          重新反推 state（`_internal`
 *                                              标志挡住自家回流）
 * 这条与 `QSkinTabs` 的 `_syncContent` 是同一族问题：**声明式绑定会被函数
 * 赋值静默打断**，所以凡是"既要绑定又要写"的地方，都用一个显式函数管。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 三条**刻意的裁剪**（写出来，不假装完整）
 * ════════════════════════════════════════════════════════════════════════
 * 1. **不做透明度（alpha）。** Ant 有 `disabledAlpha`，Arco 有 alpha 条。
 *    不做的理由是地基：`ColorUtil` 的往返恒等式与色相反推误差表全部建立在
 *    **不透明色**上（`.js` 文件头写明"不做 alpha"）。先有 alpha 通道，
 *    才有 alpha 条 —— 反过来做会得到一条"看着能拖、拖动后颜色不对"的滑轨。
 *
 * 2. **不做 hex 输入框。** 面板底部只**显示** hex。要能输入就得复用
 *    QSkinInput 的校验 / 焦点 / 提交契约，而那是另一个消费者的需求
 *    （"表单里的颜色字段"），不是一个浮层控件该顺手塞进来的东西。
 *
 * 3. **键盘不做精细步进。** 方向键在色域面上"一次挪一格"这种交互三家
 *    都没有（Ant 的键盘支持是 Tab 到滑轨后方向键**粗调**）。本件的键盘
 *    只有：触发器上 Down/上 Up/回车开面板、Esc 关面板。写出来，而不是
 *    让读者以为"键盘全覆盖"。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Window 2.11
import QtQuick.Controls 2.4
import QSkin.Foundation 1.0

/* ── 别名 import 是为了拿 QtQuick 那两个**原生 positioner**。
 *
 * 本文件同时 import 了 QtQuick 与 QSkin.Foundation，而 `foundation/qmldir`
 * 把 `Row` / `Column` / `Grid` 三个名字**都注册成了自己的实现**
 * （理由是它们要在 CSS 语义下暴露 gap / padding / align）。于是裸名
 * `Column` 解析成的是 QSkin.Foundation.Column —— 它内部是 ColumnLayout，
 * **子项自己写的 width / height 会被布局静默忽略**。
 *
 * 本件要的是"按子项尺寸纵向堆叠"，所以必须拿原生 positioner。前缀写法
 * `QtQuick.Column` 在版本化 import 下不成立（实测报 "QtQuick is neither
 * a type nor a namespace"），只能走别名 —— 先例是 `QSkinCarousel.qml`。 */
import QtQuick 2.11 as QQ

/* ⚠ **不要**给 Shapes 那类 import 加版本号（本件不用 Shapes，留着这句是
 * 给后来改这个文件的人：`import QtQuick.Shapes 2.15` 会让 Shape 的
 * `preferredRendererType` 整个不可用）。同一条已记在 `QSkinQRCode.qml`。 */

Item {
    id: root

    /* ══════════════════════ 值 ══════════════════════ */

    /** 当前颜色。**不含透明度**（见文件头裁剪 1） */
    property color value: "#1677FF"

    /** 归一化的大写 6 位 hex（只读视图，用于显示与比对） */
    readonly property string hex: {
        var c = root._rgbOf(root.value)
        return ColorUtil.rgbToHex(c.r, c.g, c.b)
    }

    /* ── HSV 真值。拖动改这里，`value` 由它算出（见文件头）── */

    property real _hueState: 0
    property real _satState: 1
    property real _valState: 1

    /** 自家人写 `value` 时置位，挡住 `onValueChanged` 的反推回流 */
    property bool _internal: false

    /* 只读的 HSV 视图（面板画光标用）*/
    readonly property real hue:        root._hueState
    readonly property real saturation: root._satState
    readonly property real brightness: root._valState

    /* ══════════════════════ 外观 ══════════════════════ */

    property bool showText: true
    property bool enabled: true

    property int panelWidth: 240
    property int panelPadding: Theme.space.md
    property int svAreaHeight: 150
    property int hueBarHeight: 12
    property int swatchSize: 20
    property int cursorSize: 14

    /* ══════════════════════ 预设色 ══════════════════════ */

    /** hex 字符串数组。默认给一圈等距色相 —— **算出来的**，不是抄的色值表 */
    property var  presets: ColorUtil.swatchRing(12, 0.9, 0.95)
    property bool showPresets: true

    /* ══════════════════════ 交互态（给外壳读）══════════════════════ */

    property bool hovered: false
    property bool pressed: false
    property bool error:   false

    /* ══════════════════════ 状态 ══════════════════════ */

    readonly property bool opened: popup.opened

    /* 触发器上那个色块给插槽读的字段（与 QSkinSelect 的选项行同一套约定） */
    readonly property string variantName: "default"

    /* ══════════════════════ 信号 ══════════════════════ */

    /** 颜色变了（拖动过程中会**连续**发） */
    signal colorChanged(color c)
    /** 面板关闭时发一次（等价于 Ant 的 onChangeComplete） */
    signal picked(color c)

    /* ══════════════════════ 尺寸 ══════════════════════ */

    /* 文字区宽度**不用** `textLoader.implicitWidth` —— 那是 Loader 的
     * implicitWidth，要等插槽 polish 之后才就绪（QSkinTabs 记过这个时序），
     * 拿来当控件隐式宽度会让首帧窄一下。hex 恒为 7 个字符（`#RRGGBB`），
     * 宽度由字号推出：等宽数字的经验字宽约字号的 0.6 倍。
     * 0.6 是字体度量比例、7 是 hex 的位数 —— 都不是主题令牌。 */
    readonly property int hexTextWidth: Math.round(Theme.font.sm * 0.6 * 7)

    implicitWidth:  root.showText
        ? root.chipInset + Theme.size.controlSm + Theme.space.xs
          + root.hexTextWidth + root.chipInset
        : Theme.size.controlMd
    implicitHeight: Theme.size.controlMd

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: true
    focus: false

    Accessible.role: Accessible.ComboBox
    Accessible.name: root.hex
    Accessible.onPressAction: root.toggle()

    /* ══════════════════════ 接口 ══════════════════════ */

    function open() {
        if (!root.enabled) return
        root._syncStateFromValue()
        popup.open()
    }
    function close()  { popup.close() }
    function toggle() { if (popup.opened) popup.close(); else root.open() }

    /** 直接设一个 hex（非法值忽略 —— 不动现有颜色，也不报错） */
    function setHex(s) {
        var norm = ColorUtil.normalizeHex(s)
        if (norm === "") return false
        var c = ColorUtil.hexToRgb(norm)
        if (c === null) return false
        root._internal = true
        root.value = Qt.rgba(c.r / 255, c.g / 255, c.b / 255, 1)
        root._internal = false
        root._syncStateFromValue()
        root.colorChanged(root.value)
        return true
    }

    /* ══════════════════════ 算路 ══════════════════════ */

    /** Qt 的 color → 0..255 整数三通道 */
    function _rgbOf(c) {
        return {
            r: Math.round(c.r * 255),
            g: Math.round(c.g * 255),
            b: Math.round(c.b * 255)
        }
    }

    /** 外部改了 `value`（或刚开面板）→ 把 state 反推回来 */
    function _syncStateFromValue() {
        var c  = root._rgbOf(root.value)
        var hs = ColorUtil.rgbToHsv(c.r, c.g, c.b)
        root._hueState = hs.h
        root._satState = hs.s
        root._valState = hs.v
    }

    /** 拖动 → 只改 state，`value` 由 state 算出（色相因此在边缘也不会丢） */
    function _applyHsv(h, s, v) {
        root._internal  = true
        root._hueState  = h
        root._satState  = s
        root._valState  = v

        var c = ColorUtil.hsvToRgb(h, s, v)
        root.value = Qt.rgba(c.r / 255, c.g / 255, c.b / 255, 1)
        root._internal = false

        root.colorChanged(root.value)
    }

    onValueChanged: {
        if (root._internal) return
        root._syncStateFromValue()
    }

    Component.onCompleted: root._syncStateFromValue()

    /* 色相条的纯色端：hue 的满饱和满明度 —— 由 ColorUtil 算，不写死 */
    readonly property color _pureHue: {
        var c = ColorUtil.hsvToRgb(root._hueState, 1, 1)
        return Qt.rgba(c.r / 255, c.g / 255, c.b / 255, 1)
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

    /** 触发器左侧的色块 —— 白底上要有描边，否则纯白选不"看得见" */
    Rectangle {
        id: chip

        anchors.left:           parent.left
        anchors.leftMargin:     root.chipInset
        anchors.verticalCenter: parent.verticalCenter

        width:  Theme.size.controlSm
        height: Theme.size.controlSm
        radius: Theme.radius.sm

        color:  root.value
        border.width: 1
        border.color: Theme.color.divider
    }

    Loader {
        id: textLoader

        anchors.left:           chip.right
        anchors.leftMargin:     Theme.space.xs
        anchors.right:          parent.right
        anchors.rightMargin:    root.chipInset
        anchors.verticalCenter: parent.verticalCenter

        visible: root.showText
        sourceComponent: root.showText ? Slots.label : null

        Binding {
            target: textLoader.item
            property: "control"
            value: textProxy
            when: textLoader.item !== null
        }
    }

    /* 触发器上的文字代理：值是 hex，不是"已选内容" —— 所以另起一个
     * QtObject，而不是让 root 自己去冒充插槽读得懂的那个东西。 */
    QtObject {
        id: textProxy

        readonly property string text:     root.hex
        readonly property string variant:  "text"
        readonly property int    labelAlignment: Text.AlignLeft
        readonly property bool   enabled:  root.enabled
    }

    FocusRing { control: root }

    MouseArea {
        id: triggerArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onEntered:  root.hovered = true
        onExited:   root.hovered = false
        onCanceled: root.pressed = false
        onReleased: root.pressed = false
        onPressed:  root.pressed = true
        onClicked:  root.toggle()
    }

    /* 触发器上的横向内边距（色块左侧、文字右侧用同一个数）。取控制尺寸
     * 与色块尺寸之差的一半 —— 于是色块在行内**光学居中**，而这个数是从
     * **令牌**推出来的，不是写死的。下界用 space.xs 兜住"某些主题把
     * controlSm 做得与 controlMd 一样大"那种情况（否则会贴边）。 */
    readonly property int chipInset: Math.max(
        Theme.space.xs,
        Math.round((Theme.size.controlMd - Theme.size.controlSm) / 2))

    /* ══════════════════════ 浮层内容 ══════════════════════ */

    Item {
        id: panel

        visible: false
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: function(event) { event.accepted = true; popup.close() }

        QQ.Column {
            id: panelCol

            anchors.fill:      parent
            anchors.margins:   root.panelPadding
            spacing:           Theme.space.sm

            /* ── 色域面：x = 饱和度、y = 明度（y 正向**减小**，见 ColorUtil.js）── */
            Item {
                id: svArea

                width:  panelCol.width
                height: root.svAreaHeight

                /* 底：白 → 当前色相的纯色（横向） */
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 1; color: "#FFFFFF" }
                        GradientStop { position: 0; color: root._pureHue }
                    }
                }

                /* 覆盖：透明 → 黑（纵向）。两层叠加得到 s/v 平面 ——
                 * 这是坐标定义，不是外观，所以不走主题。 */
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#00000000" }
                        GradientStop { position: 1; color: "#FF000000" }
                    }
                }

                /* 光标环：白环 + 一圈极淡的黑边（白环落在白底上也要看得见）*/
                Item {
                    id: svCursor

                    width:  root.cursorSize
                    height: root.cursorSize
                    visible: root.enabled

                    x: ColorUtil.pointFromSv(root._satState, root._valState,
                                             svArea.width, svArea.height).x - width / 2
                    y: ColorUtil.pointFromSv(root._satState, root._valState,
                                             svArea.width, svArea.height).y - height / 2

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: "#33000000"
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width:  root.cursorSize - 2
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: "#FFFFFF"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.CrossCursor
                    enabled: root.enabled

                    function _pick(mx, my) {
                        var sv = ColorUtil.svFromPoint(mx, my, svArea.width, svArea.height)
                        root._applyHsv(root._hueState, sv.s, sv.v)
                    }

                    onPressed:        function(ev) { _pick(ev.x, ev.y) }
                    onPositionChanged: function(ev) { if (pressed) _pick(ev.x, ev.y) }
                }
            }

            /* ── 色相条 ──────────────────────────────────────────────
             * 七个停靠点 = `swatchRing(6, 1, 1)` 的六个色相（0/60/…/300）
             * + 首色回卷。这条等式由 `tools/check-color-util.js` 的
             * `[顶点]` 段钉着 —— 所以这里不重复"六个顶点是什么"。 */
            Item {
                id: hueArea

                width:  panelCol.width
                height: root.hueBarHeight

                Rectangle {
                    id: hueBar

                    anchors.fill: parent
                    radius: Math.min(3, height / 2)

                    gradient: Gradient {
                        GradientStop { position: 1.0000; color: "#FF0000" }
                        GradientStop { position: 0.1667; color: "#FFFF00" }
                        GradientStop { position: 0.3333; color: "#00FF00" }
                        GradientStop { position: 0.5000; color: "#00FFFF" }
                        GradientStop { position: 0.6667; color: "#0000FF" }
                        GradientStop { position: 0.8333; color: "#FF00FF" }
                        GradientStop { position: 0.0000; color: "#FF0000" }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin:    -Theme.space.xs
                        anchors.bottomMargin: -Theme.space.xs
                        hoverEnabled: true
                        cursorShape: Qt.CrossCursor
                        enabled: root.enabled

                        function _pick(mx) {
                            root._applyHsv(ColorUtil.hueFromX(mx, hueBar.width),
                                           root._satState, root._valState)
                        }

                        onPressed:        function(ev) { _pick(ev.x) }
                        onPositionChanged: function(ev) { if (pressed) _pick(ev.x) }
                    }
                }

                /* 游标：一根白色短竖条，压在色相条上 */
                Item {
                    id: hueCursor

                    width:  4
                    height: hueBar.height + 4
                    visible: root.enabled
                    x: ColorUtil.xFromHue(root._hueState, hueBar.width) - width / 2
                    anchors.verticalCenter: hueBar.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: "#FFFFFF"
                        border.width: 1
                        border.color: "#33000000"
                    }
                }
            }

            /* ── 预设色板 ───────────────────────────────────────── */
            Item {
                id: swatchArea

                width:  panelCol.width
                height: root.showPresets ? swatchFlow.height : 0
                visible: root.showPresets

                Flow {
                    id: swatchFlow

                    width: parent.width
                    spacing: Theme.space.xs

                    Repeater {
                        model: root.presets
                        delegate: presetSwatchComp
                    }
                }
            }

            /* ── hex 回显（只读，见文件头裁剪 2）─────────────────── */
            Item {
                width:  panelCol.width
                height: hexText.height

                Text {
                    id: hexText

                    text: root.hex
                    font.family:    Theme.font.family
                    font.pixelSize: Theme.font.sm
                    color:          Theme.color.fg
                    renderType:     Text.NativeRendering
                }
            }
        }
    }

    /* 预设色块引用了外层 id（root / Slots 之外还有 root.presets）——
     * 与 QSkinSelect 的 delegate 同款，局部关闭即可。
     * 注释首行不要以 qmllint 开头，否则会被当成指令解析。 */
    // qmllint disable unqualified

    Component {
        id: presetSwatchComp

        Rectangle {
            id: swatch

            property var modelData
            property int index

            width:  root.swatchSize
            height: root.swatchSize
            radius: Math.min(3, height / 4)

            color: swatch.modelData.hex
            border.width: root._swatchIsCurrent(swatch.modelData.hex) ? 2 : 1
            border.color: root._swatchIsCurrent(swatch.modelData.hex)
                          ? Theme.color.fg : Theme.color.divider

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.enabled
                onClicked: root.setHex(swatch.modelData.hex)
            }
        }
    }

    // qmllint enable unqualified

    /** 这个预设是不是当前颜色（用它画"已选"描边） */
    function _swatchIsCurrent(hexStr) {
        var norm = ColorUtil.normalizeHex(hexStr)
        return norm !== "" && norm === root.hex
    }

    /* ══════════════════════ 浮层 ══════════════════════ */

    readonly property var overlayItem: overlayLoader.item
    readonly property real overlayExtender: root.overlayItem !== null
        && root.overlayItem.extender !== undefined ? root.overlayItem.extender : 0

    Popup {
        id: popup

        y: root.flipUp ? (root.overlayExtender - popup.height - Theme.space.xs)
                       : (root.height + Theme.space.xs - root.overlayExtender)

        /* **定宽**，不走外壳的 implicitWidth —— 那条会与 control.width
         * 形成循环引用（QSkinMenu 在 M4 记过这笔，裁决二重申）。 */
        width: root.panelWidth
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
        contentHeight: root._panelContentHeight()

        onOpened: {
            root._syncStateFromValue()
            panel.forceActiveFocus()
        }
        onClosed: {
            root.pressed = false
            root.picked(root.value)
        }
    }

    /** 外壳在面板四周留的空白。**不能写死**：`BasicSelectOverlay.padding`
     * 是 `Theme.space.xs`，而主题可以改它（那是外观的一部分）。所以从
     * 外壳自己的实现里读同一个令牌 —— 比"抄一个数"少一处会漂的地方。 */
    readonly property int themePadding: Theme.space.xs

    /** 面板净内容高：色域面 + 色相条 + 色板 + hex + 三个间距。
     *  从子项**实测**累加，不是写死一个数 —— 改了 svAreaHeight 它跟着走。 */
    function _panelContentHeight() {
        var h = root.svAreaHeight + root.hueBarHeight + hexText.height
        h += Theme.space.sm * 2
        if (root.showPresets) {
            var perRow = Math.max(1, Math.floor(
                (root.panelWidth - root.panelPadding * 2 + Theme.space.xs)
                / (root.swatchSize + Theme.space.xs)))
            var rows = Math.ceil(root.presets.length / perRow)
            h += rows * root.swatchSize + (rows - 1) * Theme.space.xs
            h += Theme.space.sm
        }
        return h + root.panelPadding * 2
    }

    QtObject {
        id: fakeControl

        readonly property real width:  popup.width
        readonly property real height: root._panelContentHeight()
    }

    readonly property bool flipUp: {
        var win = Window.window
        if (!win) return false
        var gy    = root.mapToItem(win.contentItem, 0, 0).y
        var below = win.height - (gy + root.height)
        return below < popup.height + Theme.space.xs && gy > below
    }

    /* ══════════════════════ 键盘（触发器上）══════════════════════ */

    Keys.onDownPressed:   function(event) { event.accepted = true; if (popup.opened) panel.forceActiveFocus(); else root.open() }
    Keys.onUpPressed:     function(event) { event.accepted = true; if (popup.opened) panel.forceActiveFocus(); else root.open() }
    Keys.onReturnPressed: function(event) { event.accepted = true; if (popup.opened) popup.close(); else root.open() }
    Keys.onEnterPressed:  function(event) { event.accepted = true; if (popup.opened) popup.close(); else root.open() }
    Keys.onEscapePressed: function(event) { event.accepted = true; if (popup.opened) popup.close() }
}
