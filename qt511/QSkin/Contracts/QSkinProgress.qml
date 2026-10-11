/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinProgress
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 进度条。
 *
 * ── 一句话说清它的契约归属 ──────────────────────────────────────────────
 * 进度条是**纯展示**控件：没有 hovered / pressed / checked，没有键盘，
 * 不产生任何交互。它只读一个 0~1 的 progress，把它画成一条长度。
 * 所以它的状态机是空的，逻辑全在"取值怎么算、文字怎么显示"上。
 *
 * ── 三种形态 ────────────────────────────────────────────────────────────
 *   variant: "line"     水平条（默认）
 *   variant: "circle"   环形
 *   indeterminate: true 不确定进度（转圈 / 流动）—— 用在"不知道要多久"
 *                       的场景（网络请求、文件扫描），这时 progress 被忽略
 *
 * ── 插槽分工 ────────────────────────────────────────────────────────────
 *   Slots.progressTrack  轨道 + 已填充区 + 光环。视觉差异全在这里：
 *                        TDesign 是细圆角条，Ant 是 8px 圆角，
 *                        shadcn 是 8px 方头条 —— 壳子只管往哪儿摆。
 *   Slots.label          百分比文字（复用！不新开插槽）
 *
 * 「复用 label 插槽」这件事是本节最值得记的结论：进度条右侧那串
 * "62%" 与按钮文字、页签文字在视觉上是同一类东西 —— 都是"主题决定
 * 字号字重颜色"的文本。给进度条单独开一个 progressText 插槽，等于
 * 让主题作者多写一遍相同的东西，没有换来任何表现力。
 * 契约层切得对，就体现在这里：新控件不需要新插槽。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Shapes 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 取值 ══════════════════════ */

    /** 0.0 ~ 1.0。超出会被钳制 —— 业务传 1.2 是常见失误，
     *  与其让进度条画出界，不如在这里收干净。 */
    property real progress: 0

    /** 不确定进度。true 时 progress 被忽略，轨道走循环动画。 */
    property bool indeterminate: false

    /* ══════════════════════ 外观 ══════════════════════ */

    /** line | circle */
    property string variant: "line"

    /** 线的粗细 / 环的线宽 */
    property int thickness: 8

    /** 语义色：default | success | warning | danger
     *  进度条的含义随场景变（上传成功变绿、磁盘将满变红），
     *  所以它需要一个语义字段让插槽去查色。 */
    property string status: "default"

    /** 是否在右侧（line）或下方（circle）显示百分比文字 */
    property bool showText: true

    /** 告诉 label 插槽按左对齐排百分比文字。
     *  label 的默认对齐是居中（第一个使用者是按钮），而进度条的数字
     *  要贴着自己的文字槽左端走，否则会飘到中间去。这里复用的是
     *  QSkinSelect / QSkinMenu 用的同一条可选覆盖约定，不是给 label 开新口子。 */
    readonly property int labelAlignment: Text.AlignLeft

    /** 百分比文字与轨道之间的间距（line 形态：文字在轨道右侧）。 */
    property int textGap: Theme.space.sm

    /** 百分比文字的宽度。line 形态下从轨道宽度里让出来。
     *  不写成动态测量 —— 那会把 label 的隐式宽度拉进依赖图，触发
     *  「宽度等于内容」组件的双向收敛（和 ButtonBar / Breadcrumb 同一个坑）。
     *  给个固定值，四位字符以内都装得下。 */
    property int textWidth: 40

    /** line 形态下是否把文字放在轨道右侧（true）。
     *  false 则叠在轨道上（旧行为，只适合轨道颜色与文字对比足够时）。 */
    property bool textBeside: true

    /* ══════════════════════ 尺寸 ══════════════════════ */

    /** 环形直径。line 形态下忽略。 */
    property int circleSize: 96

    readonly property real clamped: Math.max(0, Math.min(1, root.progress))

    /** 百分比文字。插槽只读它，不自己算 —— 见 Slots.label 的契约：
     *  插槽可以读宿主状态，但不该做业务判断。 */
    readonly property string text: Math.round(root.clamped * 100) + "%"

    /** line 形态下文字是否占在轨道右侧的独立槽位里。
     *  两种情况不占位：不显示文字、或显式要求叠放（textBeside: false）。*/
    readonly property bool _textBesideLine:
        root.showText && root.variant !== "circle" && root.textBeside

    /** 轨道实际可用的宽度 —— 让出文字槽与间距。 */
    readonly property real _trackWidth:
        root._textBesideLine ? Math.max(0, root.width - root.textWidth - root.textGap)
                             : root.width

    implicitWidth:  root.variant === "circle"
                    ? root._circleW()
                    : (root._textBesideLine ? 200 + root.textGap + root.textWidth : 200)
    implicitHeight: root.variant === "circle"
                    ? root._circleH()
                    : (root.showText ? Theme.size.controlSm : root.thickness)

    width:  implicitWidth
    height: implicitHeight

    /* 进度条不可聚焦、不可点击 —— 无障碍语义是 ProgressBar，
     * 让读屏软件把它当作"正在进行的任务"，而不是一个可操作控件。 */
    Accessible.role: Accessible.ProgressBar
    Accessible.name: root.variant === "circle" ? qsTr("进度") : qsTr("任务进度")
    Accessible.description: root.indeterminate ? qsTr("进行中")
                                               : root.text

    /* ══════════════════════ 插槽 ══════════════════════ */

    Loader {
        id: trackLoader

        /* 轨道只占左侧 —— 右侧让给百分比文字。
         * circle 形态没有这回事，整块都给环。 */
        anchors.left:           parent.left
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        width:                  root.variant === "circle" ? root.width
                                                           : root._trackWidth

        sourceComponent: Slots.progressTrack

        Binding {
            target: trackLoader.item
            property: "control"
            value: root
            when: trackLoader.item !== null
        }
    }

    /* 百分比文字。复用 Slots.label —— 理由见文件头。
     *
     * 位置：**在轨道右侧的独立槽位里**，不叠在轨道上。
     *
     * 为什么必须让出去（而不是叠放）：叠放时文字用的是 label 的默认
     * 前景色（深色），而进度条本身也是深色 —— 100% 时填充铺满整条，
     * 深字压在深底上，视觉上就像文字"溢出到条外"了。让出独立槽位后，
     * 文字永远落在背景色上，任何进度值都可读。
     *
     * 这也是 TDesign / Ant Design 的通行做法：百分比在条的外面。 */
    Loader {
        id: textLoader

        sourceComponent: (root.showText && root.variant !== "circle") ? Slots.label : null

        width: root.textWidth
        anchors.right:          parent.right
        anchors.verticalCenter: parent.verticalCenter

        Binding {
            target: textLoader.item
            property: "control"
            value: root
            when: textLoader.item !== null
        }
    }

    /* circle 形态的文字：环下方居中。
     * 单独开一个 Loader —— 两种形态的锚点种类不同（line 是
     * left/right/verticalCenter，circle 是 top/horizontalCenter），
     * 写在一个 Loader 上会被 QML 判定为锚点组合冲突。 */
    Loader {
        id: ringTextLoader

        sourceComponent: (root.showText && root.variant === "circle") ? Slots.label : null

        width: root.circleSize
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:              trackLoader.bottom
        anchors.topMargin:        Theme.space.xs

        Binding {
            target: ringTextLoader.item
            property: "control"
            value: root
            when: ringTextLoader.item !== null
        }
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    /** circle 形态要多高：环 + 下方文字 */
    function _circleH() {
        var h = root.circleSize
        if (root.showText && root._textBelowRing()) h += Theme.space.xs + Theme.font.sm * 1.5
        return h
    }

    function _circleW() {
        return root.circleSize
    }

    /* 文字放环内还是环下 —— 交给主题插槽决定，这里默认放环下。
     * 真相来源在插槽的 textBelowRing 属性上；读不到时用默认值。
     *
     * 插槽契约是鸭子类型，qmllint 按 QObject 做成员检查会误报
     * Member not found。这类"读取插槽自定义属性"的检查只能局部
     * 关掉 —— 与 QSkinRow.qml 里关掉 Layout 附加属性检查同一个理由：
     * 运行时行为正确，不能为了消警告去全局降级检查级别。 */
    // qmllint disable missing-property
    function _textBelowRing() {
        var it = trackLoader.item
        if (it && it.textBelowRing !== undefined) return it.textBelowRing === true
        return true
    }
    // qmllint enable missing-property
}
