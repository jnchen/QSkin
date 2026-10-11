/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinAnchor
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 页内锚点 —— 一列小节标题，跟着滚动高亮当前那一段，点一下滚过去。
 * 参照 Ant / Arco 的 `Anchor`。
 *
 * ── 「滚动位置就是状态」的三个件里，它是唯一**双向**的 ──────────────────
 *     QSkinAffix    只读滚动 → 挪自己
 *     QSkinBackTop  只读滚动 → 决定出现
 *     QSkinAnchor   既读（高亮谁）也写（点一下滚过去）
 * 写的那一步最容易与读的那一步分家 —— 于是两边都走
 * `QSkin.Foundation.ScrollUtil`：高亮走 `sectionIndexAt()`、
 * 跳转走 `scrollYForIndex()`。**同一个 offsets 数组、同一个 anchorOffset**，
 * 所以"点完第 k 项，第 k 项就该是高亮的那一项"是一条能证伪的等式。
 *
 * ── offsets 为什么是**输入**而不是本件去挖出来的 ────────────────────────
 * 天真的做法是接一个容器、读它 `children[i].y`。但那样"当前高亮哪一段"
 * 就依赖**真实布局时序**（children 的 y 要等布局跑完才有值，而布局在离屏
 * runner 里的收敛时机与真实窗口不一定同值）—— 这一条正是本项目反复撞的
 * 「测量与实现共享时序假设」。
 *
 * 所以 `offsets` 是一个显式的**数**组：脚本能钉死它，抓图与像素核验就能
 * 逐帧复现。真实使用嫌麻烦时用 `measure(host)` 生成一份（见下）。
 *
 * ── 已知边界（写出来，不假装没有）─────────────────────────────────────
 * · 记号跟着**滚动**走，不跟鼠标悬停（Ant 的 ink 会跟着 hover 移）。
 *   取舍理由：hover 是物理输入，抓图要关掉它才能确定 —— 而滚动位置可以被
 *   脚本钉死。悬停仍然有反馈（文字变主题色），只是不驱动记号。
 * · `affix`（锚点自己吸附在视口里）**没做**：Ant 有 `affix`、Arco 用
 *   `boundary`，本项目暂时没有消费者。要的时候把它做成 `QSkinAffix` 包一层，
 *   而不是在本件里再长一份吸附逻辑。
 * · 列表本身不滚动。太长时由宿主放进 `QSkinScrollArea`。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 小节。每项可以是：
     *    字符串                     普通条目
     *    { text, enabled }          禁用条目 */
    property var model: []

    /** 各段起点，**内容坐标**，升序。与 `model` 按下标一一对应。
     *  它是本件唯一的位置来源 —— 见文件头"为什么是输入"。 */
    property var offsets: []

    /* ══════════════════════ 输入 ══════════════════════ */

    /** 滚动宿主，一个 Flickable */
    property var target: null

    /** 锚点线距**视口顶**的距离（Ant 的 targetOffset）。
     *  滚动判定与跳转目标**共用**这一个数，所以"点完就该高亮"成立。 */
    property int anchorOffset: 0

    /* ══════════════════════ 外观 ══════════════════════ */

    property int itemHeight: 30
    property int spacing: 0
    property int fontSize: Theme.font.sm

    /** 左侧那条竖轨 */
    property bool showRail: true

    /** 活动记号的宽度。四家的 Anchor 活动记号都是这种细竖条 */
    property int inkWidth: 2

    /** 文字相对左边缘的缩进 */
    property int textInset: Theme.space.md

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property int count: root.model ? root.model.length : 0

    /** 显式读一次 contentY —— 高亮唯一的依赖来源 */
    readonly property real _scrollY: root.target ? root.target.contentY : 0

    /** 当前是哪一段。**唯一**的判定点（ScrollUtil） */
    readonly property int currentIndex:
        ScrollUtil.sectionIndexAt(root.offsets, root._scrollY, root.anchorOffset)

    /** 有鼠标停在上面时是第几项（只驱动文字色，不驱动记号） */
    property int hoverIndex: -1

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 用户选了第 index 段（点选或键盘回车） */
    signal selected(int index)

    /**
     * 滚到第 index 段。目标位置有**三**种来源，优先级从高到低：
     *   1. `offsets[index]`（本件自己的口径）
     *   2. `hostOffsets`（宿主临时给的一份，用于"段位置刚变、offsets 还没跟上"）
     *   3. 都不成立 → 不动，避免静默滚到 0
     * 返回是否真的滚了 —— 调用方（含门禁）据此判断"这一项到底有没有被夹取"。
     */
    function scrollTo(index) {
        if (!root.target) return false

        var list = root.offsets
        var y = ScrollUtil.scrollYForIndex(list, index, root.anchorOffset,
                                           root.target.contentHeight,
                                           root.target.height)
        if (y < 0) return false

        root.target.contentY = y
        return true
    }

    /** 选一段：滚过去 + 发信号。滚不动也发（宿主可能需要自己兜底） */
    function select(index) {
        if (index < 0 || index >= root.count) return
        if (!root._enabledAt(index)) return
        root.scrollTo(index)
        root.selected(index)
    }

    /**
     * measure(host) → [数, …]
     *
     * 给真实使用的便利：读 `host` 的直接子项（可见的那些）的 y。
     * **它不是**本件的位置来源 —— 结果要由宿主绑回 `offsets`。
     * 之所以不做成自动绑定：见文件头"为什么是输入"。
     */
    function measure(host) {
        var out = []
        if (!host) return out
        var kids = host.children
        for (var i = 0; i < kids.length; ++i) {
            var k = kids[i]
            if (!k || k.visible === false) continue
            out.push(k.y)
        }
        return out
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    function _itemAt(i) {
        return root.model ? root.model[i] : null
    }

    function _textAt(i) {
        var it = root._itemAt(i)
        if (typeof it === "string") return it
        return (it && it.text !== undefined) ? String(it.text) : ""
    }

    function _enabledAt(i) {
        var it = root._itemAt(i)
        return !(it && it.enabled === false)
    }

    /** 第 index 行的顶边（本件坐标）—— 记号与判据都用它 */
    function rowTop(index) {
        return index * (root.itemHeight + root.spacing)
    }

    /* ══════════════════════ 几何 ══════════════════════ */

    implicitWidth:  root.showRail ? 180 : 160
    implicitHeight: root.count * root.itemHeight
                    + Math.max(0, root.count - 1) * root.spacing

    /* ══════════════════════ 竖轨 ══════════════════════ */

    Rectangle {
        id: rail

        visible: root.showRail && root.count > 0
        x: 0
        y: 0
        width: 1
        height: root.implicitHeight
        color: Theme.color.divider
    }

    /* ══════════════════════ 活动记号 ══════════════════════
     * 跟着**滚动位置**走（`currentIndex`），不跟 hover —— 见文件头。 */

    Rectangle {
        id: ink

        visible: root.showRail && root.currentIndex >= 0
        x: 0
        y: root.rowTop(root.currentIndex)
        width: root.inkWidth
        height: root.itemHeight
        radius: root.inkWidth / 2
        color: Theme.color.brand
    }

    /* ══════════════════════ 行 ══════════════════════ */

    QSkinColumn {
        id: col

        x: 0
        y: 0
        width: root.width
        gap: root.spacing

        Repeater {
            model: root.count

            /* 本代理里要引用外层的 root 与 Theme —— 那在 qmllint 眼里是
             * 非限定访问。与 QSkinMenu 的菜单代理同一处置：局部关掉。
             * （注释首行不要以 qmllint 开头） */
            // qmllint disable unqualified
            delegate: Item {
                id: row

                property int index

                width:  col.width
                height: root.itemHeight

                readonly property bool isEnabled: root._enabledAt(row.index)
                readonly property bool isCurrent: root.currentIndex === row.index
                readonly property bool isHovered: root.hoverIndex === row.index

                /* 伪装成"控件"给 Slots.label 读 —— 与 QSkinMenu 的菜单行同一手法 */
                readonly property string text: root._textAt(row.index)
                readonly property string variant: row.isCurrent
                                                  ? "primary"
                                                  : (row.isHovered ? "default" : "ghost")
                readonly property int labelAlignment: Text.AlignLeft
                property bool enabled: row.isEnabled

                Loader {
                    id: rowLabel

                    anchors.left:  parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: root.textInset
                    anchors.verticalCenter: parent.verticalCenter

                    sourceComponent: Slots.label

                    Binding {
                        target: rowLabel.item
                        property: "control"
                        value: row
                        when: rowLabel.item !== null
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: row.isEnabled

                    onEntered:  root.hoverIndex = row.index
                    onExited:   if (root.hoverIndex === row.index) root.hoverIndex = -1
                    onClicked:  root.select(row.index)
                }
            }
            // qmllint enable unqualified
        }
    }

    /* ══════════════════════ 键盘 ══════════════════════
     * 上下键在小节之间走，回车滚过去。这让本件在没有鼠标时也完整 ——
     * 与项目其它控件的口径一致（交互不进插槽）。 */

    activeFocusOnTab: true
    focus: false

    Keys.onDownPressed:  root._step(1)
    Keys.onUpPressed:    root._step(-1)
    Keys.onEnterPressed: root.select(root.currentIndex)
    Keys.onReturnPressed: root.select(root.currentIndex)

    function _step(delta) {
        if (root.count === 0) return
        var next = Math.max(0, Math.min(root.count - 1, root.currentIndex + delta))
        root.select(next)
    }

    /** 有没有焦点 —— 只用来画焦点环，不影响上面任何判定 */
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: root.activeFocus ? Theme.size.focusRing : 0
        border.color: Theme.color.focus
        radius: Theme.radius.sm
    }

    Accessible.role: Accessible.List
    Accessible.name: qsTr("页内锚点")
}
