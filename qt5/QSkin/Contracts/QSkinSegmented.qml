/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinSegmented
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 分段控制器（M23）—— 一排紧邻的选项，**单项选中**，选中项底下有一块
 * 会滑过去的底。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 它是"单项选中"的第三种形态 —— 但**不是**单选组的第三个实现
 * ════════════════════════════════════════════════════════════════════════
 * 项目里已有的两种（M20）：
 *
 *     QSkinRadioGroup  值由**组**保管，成员自己去挂在组上、自己动
 *     QSkinToggle      一条正交的开关轴（与 `variant` 并存），可多选
 *
 * 这一件与它们的关系是"**同一件事的第三种外观**"，而不是第三套状态机：
 *
 *   · 值只有**一个**（`value`），—— 与单选组同一个语义
 *   · 但成员**不是**用户声明的子控件，而是 `options` 里的一行数据 ——
 *     因为分段控制器的每一段是"同一句话的不同取值"（日/周/月），
 *     不是"各自独立的一块 UI"。让用户为每一段写一个控件，等于让他在
 *     调用点上把同一个 Text 写三遍。
 *
 * 所以它选的是**数据驱动**（与 QSkinMenu / QSkinBreadcrumb 同一条路），
 * 而不是 QSkinRadioGroup 那种"成员挂靠"。
 *
 * ── 与 QSkinRadio 的关系：共用**语义**，不共用实现 ────────────────────────
 * 有人会问"那它为什么不直接包一个 QSkinRadioGroup"。因为它与单选组在三个
 * 地方不同，每一个都写在屏幕上：排版（紧邻无缝、无标签间距）、
 * 视觉（一块滑动的底，而不是每项一个圆点）、键盘（左右键**立即选中**，
 * 而单选组是"移动即选中"—— 看着一样，实现上它必须自己走，因为它的成员
 * 不是可 Tab 的独立控件）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 活动块的位置是**量出来的**，不是算出来的
 * ════════════════════════════════════════════════════════════════════════
 * 每段的宽度由它自己的文字决定（"列表"与"卡片视图"不一样宽）。
 * 于是活动块的 x/width 只能**读当前段的实际盒子** —— 若改成等分公式
 * （`i × (总宽 / 段数)`），在文字长短不一的场景下活动块会与文字错位，
 * 而这个错位**在等宽选项上完全看不出来**（那是最容易被演示数据骗过的一类）。
 *
 * 走的是段项自己登记 + `MemberOrder` 排声明序（与折叠面板同一套协议）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 刻意**没做**的（消费者为零，按项目规矩"没有消费者就不做"）
 * ════════════════════════════════════════════════════════════════════════
 *   · `size`（大/中/小）—— 参照实现有这一档验收（Ant 的 6 个尺寸组合）。
 *     没有消费者；而"换个尺寸"更该由主题改 `size.controlMd` 一次性回答。
 *   · 选项里的**图标** —— 需要调用方塞节点，而"塞节点"这件事在本项目
 *     已经有插槽这条路（`contentItem` 家族）。为它单开一条 API 会引入
 *     第二套"把用户的东西放进控件"的机制。
 *   · `block` 之外的对齐 —— 分段控制器本来就是"贴着放的一排"。
 *
 * 用法：
 *     QSkinSegmented {
 *         options: ["日", "周", "月"]
 *         value: "周"
 *         onSelectionChanged: console.log(value)
 *     }
 *
 *     QSkinSegmented {
 *         options: [ { value: "list", label: "列表" },
 *                    { value: "card", label: "卡片视图" },
 *                    { value: "extra", label: "更多", disabled: true } ]
 *     }
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 选项。元素可以是字符串（值 = 文字）或对象：
     *  `{ value, label, disabled }`。未知形状的元素按字符串处理。 */
    property var options: []

    /** 当前选中值。初始 undefined = 一项都不选。 */
    property var value: undefined

    /** 整件的可用性 */
    property bool enabled: true

    /** 轨道内边距：活动块与轨道边之间留多少 */
    property int inset: Theme.space.xxs

    signal selectionChanged(var value)

    /* ══════════════════════ 归一 ══════════════════════ */

    readonly property int count: root._options().length

    /** 归一成一个统一形状的数组。**每次都新建**（不缓存）——
     *  缓存会引入"options 改了但归一结果没跟着变"的陈旧值，
     *  而 `options` 是一个普通 `var` 属性、外部可以整体换掉。 */
    function _options() {
        var src = root.options
        if (src === null || src === undefined) return []
        var out = []
        for (var i = 0; i < src.length; ++i) {
            var o = src[i]
            if (o === null || o === undefined) continue
            if (typeof o === "object") {
                out.push({
                    value:    o.value !== undefined ? o.value : o.label,
                    label:    o.label !== undefined ? String(o.label) : String(o.value),
                    disabled: o.disabled === true
                })
            } else {
                out.push({ value: o, label: String(o), disabled: false })
            }
        }
        return out
    }

    /** 当前选中项的下标；没有选中或值不在选项里 → -1。 */
    readonly property int currentIndex: root._indexOfValue(root.value)

    function _indexOfValue(v) {
        var list = root._options()
        if (v === undefined || v === null) return -1
        for (var i = 0; i < list.length; ++i)
            if (list[i].value === v) return i
        return -1
    }

    /* ══════════════════════ 段项登记 ══════════════════════ */

    /** 已就位的段项，按**声明序**（= 归一后的下标序）。 */
    property var _segs: []

    function _registerSeg(it) {
        if (it === null || it === undefined) return
        if (root._segs.indexOf(it) >= 0) return
        var out = root._segs.slice()
        out.push(it)
        root._segs = MemberOrder.sortByDeclaration(out)
    }

    function _unregisterSeg(it) {
        var i = root._segs.indexOf(it)
        if (i < 0) return
        var out = root._segs.slice()
        out.splice(i, 1)
        root._segs = out
    }

    function _segAt(i) {
        if (i < 0 || i >= root._segs.length) return null
        return root._segs[i]
    }

    /* 活动块的目标盒子。两条函数读的是**同一个**来源，于是它们永远一致；
     * 而各自都建立了对"当前段项"的 x / width 的依赖，布局一改就重算。 */
    function _thumbX() { var s = root._segAt(root.currentIndex); return s === null ? 0 : s.x }
    function _thumbW() { var s = root._segAt(root.currentIndex); return s === null ? 0 : s.width }

    /* ══════════════════════ 选中 ══════════════════════ */

    /** 唯一的写入口：外部赋值与点击都经这里（QSkinRadioGroup 同款约定）。 */
    function _selectIndex(i) {
        var list = root._options()
        if (i < 0 || i >= list.length) return
        if (list[i].disabled) return
        if (!root.enabled) return
        if (root.value === list[i].value) return
        root.value = list[i].value
        root.selectionChanged(root.value)
    }

    /** 左右键移动：**跳过禁用项、两端回绕、立即选中**。
     *  WAI-ARIA 的 tablist / radiogroup 约定都是这一条。 */
    function _move(delta) {
        var n = root.count
        if (n === 0) return
        var list = root._options()
        var i = root.currentIndex
        if (i < 0) i = delta >= 0 ? -1 : 0
        var step = delta >= 0 ? 1 : -1
        for (var k = 0; k < n; ++k) {
            i = (i + step + n) % n
            if (list[i].disabled) continue
            root._selectIndex(i)
            return
        }
    }

    /* ══════════════════════ 视觉 ══════════════════════ */

    implicitHeight: Theme.size.controlMd
    /* 宽度 = 一排段项的自然宽 + 两侧轨道内边距。
     * 读的是 `row.implicitWidth`（QSkinRow 是 Layout，它会算隐式尺寸），
     * **不是** `viewport.implicitWidth` —— 后者是个普通 Item，
     * 隐式尺寸恒为 0，写上去会得到一个"永远 120 宽"的控件。 */
    implicitWidth:  Math.max(row.implicitWidth + root.inset * 2, 120)

    /* ── 轨道 ──
     * 底用 subtle 档、无描边 —— 分段控制器读起来是"一块凹进去的底"，
     * 而不是"一个输入框"。 */
    Rectangle {
        id: track

        anchors.fill: parent
        radius: Theme.radius.md
        color:  Theme.color.bgSubtle
        opacity: root.enabled ? 1 : 0.6
    }

    Item {
        id: viewport

        anchors.fill: parent
        anchors.margins: root.inset

        /* ── 活动块 ──
         * 声明在段项**之前** → 画在它们**下面**。
         *
         * 高度撑满 viewport：参照实现里活动块比轨道矮一点（轨道有 padding），
         * 这一点由 `inset` 表达，不在插槽里再缩一次 —— 插槽锚填宿主给的盒子。
         *
         * 宽度为 0 时不画：一开始（还没登记完段项）thumb 的盒子是 0×h，
         * 画出来是一条竖线。 */
        Loader {
            id: thumbLoader

            x:      root._thumbX()
            y:      0
            width:  root._thumbW()
            height: viewport.height
            visible: root._thumbW() > 0
            sourceComponent: Slots.segmentThumb

            /* x / width 走动画 = "滑过去"。只在**位置**变化时跑；
             * 首次出现时从 0 滑到第一个段是多余的动静，所以延到
             * 组件完成后再开（chevronIndicator 记过同一个坑）。 */
            Behavior on x {
                enabled: root.animate
                NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
            }
            Behavior on width {
                enabled: root.animate
                NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
            }

            Binding {
                target: thumbLoader.item
                property: "control"
                value: thumbCtl
                when: thumbLoader.status === Loader.Ready
            }
        }

        QtObject {
            id: thumbCtl

            readonly property bool enabled: root.enabled
        }

        /* ── 段项 ── */
        QSkinRow {
            id: row

            anchors.fill: parent
            gap: 0

            Repeater {
                model: root._options()
                delegate: segComp
            }
        }
    }

    /** 首次出现时不许动画（见上面两个 Behavior）。 */
    property bool animate: false
    Component.onCompleted: root.animate = true

    /* ══════════════════════ 段项实现 ══════════════════════ */

    /* delegate 引用了外层 id（root）—— 与 QSkinList / QSkinSelect 同款
     * qmllint 局限，局部关闭。注释首行不要以 qmllint 开头。 */
    // qmllint disable unqualified

    Component {
        id: segComp

        Item {
            id: seg

            /* Repeater 注入的两个上下文变量，声明成 required 属性收下 ——
             * 这是 Qt 6 的推荐写法（上下文属性求值更慢、且 qmllint 看不见
             * 类型）。照 QSkinList.qml:357-358。 */
            required property int index
            required property var modelData

            readonly property var _opt: modelData
            readonly property bool _active: root.value === seg._opt.value
            readonly property bool _usable: root.enabled && !seg._opt.disabled

            implicitWidth:  textItem.implicitWidth + Theme.space.lg * 2
            implicitHeight: viewport.height

            Text {
                id: textItem

                anchors.centerIn: parent

                text: seg._opt.label

                font.family:    Theme.font.family
                font.pixelSize: Theme.font.sm
                font.weight:    seg._active ? Theme.font.weightMedium
                                            : Theme.font.weightRegular

                /* 选中项用前景色"立"起来，未选中的退一档 ——
                 * 分段控制器的可读性靠这个，而不是靠活动块本身
                 * （活动块在一部分主题里与轨道底色很接近）。 */
                color: !seg._usable ? Theme.color.fgDisabled
                     : seg._active  ? Theme.color.fg
                                    : Theme.color.fgSecondary

                Behavior on color {
                    ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
                }
            }

            Accessible.role: Accessible.RadioButton
            Accessible.name: seg._opt.label
            Accessible.focusable: seg._usable
            Accessible.checked: seg._active

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                enabled: seg._usable
                cursorShape: seg._usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root._selectIndex(index)
            }

            /* 键盘只挂在**当前选中项**上（roving tabindex）：整件是一个
             * Tab 停靠点，不是 N 个 —— 与 QSkinRadioGroup 的约定一致。 */
            Item {
                anchors.fill: parent
                activeFocusOnTab: seg._usable && seg._active
                Keys.onLeftPressed:  function(event) { root._move(-1); event.accepted = true }
                Keys.onRightPressed: function(event) { root._move(1);  event.accepted = true }
            }

            Component.onCompleted: root._registerSeg(seg)
            Component.onDestruction: root._unregisterSeg(seg)
        }
    }

    // qmllint enable unqualified
}
