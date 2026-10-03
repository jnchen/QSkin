/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinInputOTP
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 验证码输入（N 格一位）。
 *
 * ── 关键决定：**一个真的 TextInput，N 个假的格子**────────────────────────
 * 最直觉的写法是"每格一个 TextInput，输完自动跳下一格"。那个写法会在
 * 真实使用里碎成一地，而每一处都只在特定操作下才暴露：
 *
 *     粘贴 "123456"      → 只落进第一格一个字符，或者整串塞进第一格
 *     退格               → 格是空的，光标却停在这一格，删不掉上一格
 *     左右方向键         → 光标在"格子之间"移动，而格子是独立的输入框
 *     中文输入法         → 拼字过程中每个格都收到半截拼音
 *     Ctrl+A / 拖选      → 只能选中一格
 *
 * 根因是：**它们其实是同一段文本被切成了 N 段来显示**。所以本实现让
 * 一个真的 TextInput 持有全部文本（它是唯一有焦点、唯一能被编辑的
 * 东西），N 个格子只是**投影**：第 i 格显示 `value[i]`，谁高亮由
 * `activeIndex` 决定。
 *
 * 上面那张清单因此全部自动成立 —— 因为那些行为本来就属于一个普通
 * 输入框，而这里就是一个普通输入框。
 *
 * ── 格子复用输入框底板 ──────────────────────────────────────────────────
 * `Slots.inputBackground` 的第三个宿主（前两个是 QSkinInput / QSkinTextarea）。
 * 一个格子就是一个迷你输入框："错误时红、聚焦时提亮、常态下沉"三条
 * 规则对它一字不改 —— 这又是契约层切对了地方的一个样本。
 * 于是"哪一格的边框亮着"这件事由 `activeIndex` 单独喂给那个格子。
 *
 * ── 几何必须是纯算术 ────────────────────────────────────────────────────
 * 第 i 格的 x 由一个函数 `xOf(i)` 给出：`i × 步长 + 它前面几个分隔符 ×
 * 分隔符步长`。分隔符**占固定方框**（不按自己的文字宽度排版）——
 * 否则 6 格的位置就依赖字体，"第 3 格的中心在哪"变成一个只能在渲染后
 * 才知道的数，属性侧就再也断言不了它。
 *
 * ── 两处细节 ────────────────────────────────────────────────────────────
 * · 遮罩用圆点、不用 "•"：字符字形随字体回退走，而这个记号出现在每一格上。
 * · 数字过滤走 JS 而不是 validator：与 QSkinTextarea 的 maxLength 硬截断
 *   同一手法（先规整、再回写），两处读起来是一件事；顺带绕开
 *   Qt5 的 RegExpValidator / Qt6 的 RegularExpressionValidator 改名。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

/* 根是 FocusScope：底板的聚焦态靠 `control.activeFocus`，而焦点真正的
 * 持有者是里面那个 TextInput。理由与 QSkinTextarea 完全一致（那里写了
 * 完整论证），两个输入类控件必须在这件事上同构。 */
FocusScope {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 位数。 */
    property int length: 6

    /** 当前内容。**字符串**，因为验证码的前导零是有意义的
     *  （"0123" 与 "123" 是两个不同的验证码）。 */
    property string value: ""

    /** 只接受数字。关掉后可以当"分格短码"用。 */
    property bool digitsOnly: true

    /** 只读（展示用）。 */
    property bool readOnly: false

    /** 校验失败态 */
    property bool error: false

    /** 遮罩（口令式）。 */
    property bool masked: false

    /* ══════════════════════ 分隔 ══════════════════════ */

    /** 分隔符文本（"-" / "·" / ""）。空串 = 不分隔。 */
    property string separator: ""

    /** 每隔几格插一个分隔符。0 = 不插。 */
    property int separatorEvery: 0

    /* ══════════════════════ 外观 ══════════════════════ */

    /** 格子边长。 */
    property int cellSize: Theme.size.controlLg

    /** 格间距 */
    property int gap: Theme.space.sm

    /** 分隔符方框宽度。**固定值，不按文字量** —— 见文件头。 */
    property int separatorWidth: Theme.space.lg

    /** 遮罩圆点直径 */
    readonly property int dotSize: Math.max(6, Math.round(root.cellSize / 5))

    /* ══════════════════════ 信号 ══════════════════════ */

    /** 填满时触发一次（同一个值不会重复触发）。 */
    signal completed(string value)
    signal accepted()

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property int cellCount: Math.max(0, root.length)

    /** 一格占据的横向步长 —— 像素核验量的就是它。 */
    readonly property int stride: root.cellSize + root.gap

    readonly property int sepStride: root.separatorWidth + root.gap

    readonly property bool hasSeparators: root.separator !== "" && root.separatorEvery > 0

    /** 一共要插几个分隔符 */
    readonly property int sepCount: root.hasSeparators && root.cellCount > 1
        ? Math.floor((root.cellCount - 1) / root.separatorEvery) : 0

    /** 已填入的位数 */
    readonly property int filledCount: Math.min(root.value.length, root.cellCount)

    /* 判定"填满了"的**唯一**算法。`onValueChanged` 也必须走这个函数，
     * 不能在这里读一条绑定 —— 见 `_isComplete()` 的注释。 */
    readonly property bool isComplete: root._isComplete(root.value)

    /** 当前光标所在的格。**未聚焦时是 -1** —— 没聚焦还亮着一个格子，
     *  是在跟用户说"你正在这里输入"，而那句话是假的。 */
    readonly property int activeIndex: input.activeFocus
        ? Math.min(root.value.length, root.cellCount - 1) : -1

    readonly property bool hasFocus: input.activeFocus

    implicitWidth:  root.cellCount > 0
                    ? root.xOf(root.cellCount - 1) + root.cellSize : 0
    implicitHeight: root.cellSize

    width:  implicitWidth
    height: implicitHeight

    activeFocusOnTab: !root.readOnly

    Accessible.role: Accessible.EditableText
    Accessible.name: qsTr("验证码，共 %1 位").arg(root.cellCount)

    /* ══════════════════════ 格子（投影）══════════════════════ */

    Repeater {
        model: root.cellCount
        delegate: cellComp
    }

    // qmllint disable unqualified
    Component {
        id: cellComp

        Item {
            id: cell

            required property int index

            x:      root.xOf(cell.index)
            width:  root.cellSize
            height: root.cellSize

            /* 这一格是"当前输入位" */
            readonly property bool active: cell.index === root.activeIndex
            readonly property bool filled: cell.index < root.filledCount

            /* 底板的宿主代理。底板只认那五个名字（见 BasicInputBackground），
             * 所以这里把"整个控件的错误态"和"这一格的高亮"拼起来 ——
             * 与 QSkinTable 的表头、BasicButtonContent 的 iconProxy 同一套约定。 */
            QtObject {
                id: cellCtl

                readonly property bool error:       root.error
                readonly property bool activeFocus: cell.active
                readonly property bool hovered:     root._hoverIndex === cell.index
                readonly property bool enabled:     root.enabled
            }

            Loader {
                id: cellBgLoader

                anchors.fill: parent
                sourceComponent: Slots.inputBackground

                Binding {
                    target: cellBgLoader.item
                    property: "control"
                    value: cellCtl
                    when: cellBgLoader.item !== null
                }
            }

            /* 已填入的字符 */
            Text {
                anchors.centerIn: parent
                visible: cell.filled && !root.masked
                text:    cell.filled ? root.value.charAt(cell.index) : ""

                font.family:    Theme.font.family
                font.pixelSize: Theme.font.md
                font.weight:    Theme.font.weightMedium
                color:          root.error ? Theme.color.danger : Theme.color.fg
            }

            /* 遮罩：一个圆点（不是 "•"） */
            Rectangle {
                anchors.centerIn: parent
                width:  root.dotSize
                height: root.dotSize
                radius: width / 2
                visible: cell.filled && root.masked
                color:   root.error ? Theme.color.danger : Theme.color.fg
            }
        }
    }
    // qmllint enable unqualified

    /* ══════════════════════ 分隔符 ══════════════════════ */

    Repeater {
        model: root.sepCount
        delegate: sepComp
    }

    // qmllint disable unqualified
    Component {
        id: sepComp

        Text {
            id: sepText

            required property int index

            /* 第 index 个分隔符落在 (index+1)×separatorEvery 格之前 */
            x: root.xOf((sepText.index + 1) * root.separatorEvery)
               - root.separatorWidth - root.gap
            width:  root.separatorWidth
            height: root.cellSize

            text: root.separator
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment:   Text.AlignVCenter

            font.family:    Theme.font.family
            font.pixelSize: Theme.font.sm
            color:          Theme.color.fgMuted
        }
    }
    // qmllint enable unqualified

    /* ══════════════════════ 真正的输入框 ══════════════════════
     * 撑满整个控件、透明。它是唯一持有焦点的东西 —— 用户点到哪一格、
     * 拖选、粘贴、退格，全都是这一个输入框的常规行为。
     * `opacity: 0` 只影响绘制，不影响焦点与鼠标命中。 */

    TextInput {
        id: input

        anchors.fill: parent
        opacity: 0

        text: root.value
        onTextChanged: {
            /* 数字过滤：先规整、再回写（与 QSkinTextarea 的截断同一手法）。
             * 回写会再触发一次 onTextChanged，那时 cleaned === text，
             * 直接落到下面的同步分支。 */
            if (root.digitsOnly) {
                var cleaned = input.text.replace(/[^0-9]/g, "")
                if (cleaned !== input.text) {
                    /* 同 QSkinTextarea：只写 root.value，由 `text: root.value`
                     * 那条绑定把它推回来 —— 直接写 input.text 会把绑定打掉。 */
                    root.value = cleaned
                    return
                }
            }
            if (input.text !== root.value) root.value = input.text
        }

        maximumLength: root.cellCount
        readOnly: root.readOnly
        selectByMouse: true
        clip: true

        font.family:    Theme.font.family
        font.pixelSize: Theme.font.md
        color:          Theme.color.fg
        selectionColor: Theme.color.brandSubtle
        selectedTextColor: Theme.color.fg

        inputMethodHints: root.digitsOnly ? Qt.ImhDigitsOnly : Qt.ImhNone

        onAccepted: root.accepted()
    }

    /* 悬停格追踪。`acceptedButtons: Qt.NoButton` 只收位置事件、
     * 不参与按键派发，所以点击照旧落到下面的输入框上（与 QSkinInput 同一手法）。 */
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.IBeamCursor

        onExited: root._hoverIndex = -1
        onPositionChanged: function(mouse) {
            root._hoverIndex = root.indexOfX(mouse.x)
        }
    }

    FocusRing { control: root }

    /* ══════════════════════ 内部 ══════════════════════ */

    property int _hoverIndex: -1
    property string _lastEmitted: ""

    onValueChanged: {
        /* 这里必须走 `_isComplete(...)`，**不能读 `root.isComplete`**：
         * QML 的绑定是**惰性**的 —— 依赖变了只把它标脏，下次读的时候
         * 才重算。而 `valueChanged` 先于那次重算触发，于是 handler 里
         * 读到的是**上一次**的结果。
         *
         * 实测：`value` 已经是 "123456"（6 位、cellCount 也是 6），
         * handler 里读 `isComplete` 仍是 false —— 于是 `completed` 信号
         * 一次都不发（连续填满两次也不发）。而**从外面**读同一个属性
         * 拿到的是 true，所以这个缺陷在渲染侧与外部观测里完全隐形，
         * 只有"信号没触发"这一个可观测后果 —— 分格验证码不发完成信号，
         * 用户提交不了。
         *
         * 与 smoke_m20_theme.qml 里那条「`Behavior on color` 让"赋值后
         * 立即读"变成读到动画起点」是同一族教训：
         * **测量本身也要有确定的时序。** */
        if (root._isComplete(root.value) && root.value !== root._lastEmitted) {
            root._lastEmitted = root.value
            root.completed(root.value)
        }
    }

    /** 「填满了」的判定（见 `isComplete` 与 `onValueChanged` 处的注释）。 */
    function _isComplete(v) {
        return root.cellCount > 0 && String(v).length === root.cellCount
    }

    /** 第 i 格的横坐标。**纯算术** —— 不依赖字体、不依赖已画出来的东西，
     *  所以属性侧断言的数与像素量出来的数是同一个。 */
    function xOf(i) {
        var seps = root.hasSeparators
            ? Math.floor(i / root.separatorEvery)
            : 0
        return i * root.stride + seps * root.sepStride
    }

    /** 横坐标 → 格号。判界用相邻两格的**几何中缝**：
     *      `(第 i-1 格右缘 + 第 i 格左缘) / 2`
     *  这样点进格间的空隙（含分隔符区）时归给**右边**那一格 ——
     *  点缝里不该让光标跳回上一格，那是用户的"下一格"直觉。
     *  第一版写成 `x >= xOf(i) - gap/2`，在带分隔符的布局下会把
     *  一整段分隔符区判给左边那格（因为分隔符把缝拉宽了）。 */
    function indexOfX(x) {
        for (var i = root.cellCount - 1; i >= 1; --i) {
            if (x >= (root.xOf(i - 1) + root.cellSize + root.xOf(i)) / 2)
                return i
        }
        return 0
    }

    /** 把焦点交给输入框。宿主（或测试）用它模拟"点进来了"。 */
    function forceInputFocus() {
        input.forceActiveFocus()
    }
}
