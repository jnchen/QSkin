/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinTour
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 引导漫游（M24）—— 把用户带过一串"看这里"。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 一个 `steps` 数组，每一步瞄准一个**真实存在的 Item**
 * ════════════════════════════════════════════════════════════════════════
 *
 *     QSkinTour {
 *         open: true
 *         steps: [
 *             { target: btnNew,   title: "新建", description: "从这里开始" },
 *             { target: sideNav,  title: "导航", description: "整站入口" },
 *             { title: "完成", description: "没有了" }        // 没有 target
 *         ]
 *     }
 *
 * `target` 是一个 **Item 引用**（不是选择器字符串，也不是坐标）。
 * 参照实现里 Ant 收 `() => HTMLElement`、TDesign 收 `() => Element` ——
 * 都要一个"运行时去找"的间接层，因为 DOM 里没有更直接的表达。
 * QML 里有：Item 是活的对象，能 `mapToItem`。所以这一步省掉。
 *
 * `title` / `description` 收**字符串或函数**：函数形式给"第 N 步"
 * 这类随步数变的文案（Ant 的 `title: (current) => …` 同款）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 挖洞用**四块遮罩矩形**围出来，不用着色器
 * ════════════════════════════════════════════════════════════════════════
 * 上 / 下 / 左 / 右四块拼成一个"中间空掉"的遮罩。不引入
 * QtQuick.Effects 的 ShaderEffect 来做 alpha 挖洞，理由是**可核验**：
 *
 *   · 四块矩形的位置就是四个纯数字（`_maskRects` 那个对象），
 *     可以在冒烟测试里直接断言 —— "上块的底边 = 洞的顶边"这种等式
 *     是能证伪的；着色器里的一个 `smoothstep` 不行。
 *   · 它在软件渲染后端上也照样工作（QSkinImage 的圆角遮罩在那里会降级，
 *     这里不会）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 洞的几何：两个坑，都是"依赖没登记住"
 * ════════════════════════════════════════════════════════════════════════
 * **坑一 —— `mapToItem()` 是 C++ 调用。** QML 的绑定依赖捕获，是靠属性读
 * 经 JS 包装层时登记的。`mapToItem()` 是一次 C++ 调用，它内部读
 * `x/y/width/height` 时**不经过**那层包装 —— 于是父级把目标控件挪了位置，
 * 这个绑定**不会重算**。修法是显式读一遍那四个属性（`_computeHole()` 里
 * 那行 `var _ = …`），让依赖真的被登记。
 *
 * **坑二 —— 拿浮层自己的坐标系当参照。** 初版写成
 * `t.mapToItem(maskLayer, 0, 0)`，并且把洞钳进 `maskLayer.width/height`。
 * 而浮层是**惰性实例化**的：`open = true` 之后还要等一帧，contentItem 才
 * 被交给 Popup 并定尺寸。于是这个绑定在首帧就被求值过一次 —— 那时
 * `maskLayer` 是 0×0，钳出来是 `{0,0,0,0}` —— 而浮层定尺寸之后**没有谁
 * 去作废它**。实测（M24）：`maskReady` 早已是 true、`_mask` 也已经是
 * 1200 宽，`_hole` 连读五轮还是 `{0,0,0,0}`；同一个回合里手动逼它重算
 * 一次，值立刻是对的。**这不是"变换还没定型"，是缓存没被作废。**
 *
 * 两处修法：
 *   1. 洞算在**场景坐标**里（`mapToItem(null, …)`）。maskLayer 是铺满
 *      窗口、padding 为 0 的 contentItem，**它的局部坐标就是场景坐标**，
 *      所以结果不变，但不再依赖浮层什么时候落位。这条不变量的真正取证
 *      在像素核验（洞按场景坐标画出来落在哪儿），不在属性侧。
 *   2. 要钳的窗口尺寸走 `_vw`/`_vh` —— 它们是 **root 自己的绑定**，读它们
 *      才会登记依赖；直接读 `maskLayer.width` 在浮层定尺寸时不一定能把
 *      本绑定叫醒（就是上面那次僵住）。
 *
 * 这两个坑是同一个族的第二次与第三次，教训都一样：**"不写也能跑、
 * 只在某个时序之后才错"的依赖，必须用一次显式读把它钉在绑定上。**
 *
 * ════════════════════════════════════════════════════════════════════════
 * 面板上下翻转，洞留在原地
 * ════════════════════════════════════════════════════════════════════════
 * 目标下方放得下就放下方，放不下就放上方；横向在洞上居中，并钳在窗口内。
 * 没有 `placement` 属性去暴露"上/下/左/右"四种朝向 —— 一个引导气泡的
 * 朝向是**算出来的**，让宿主再指定一次只会得到两个互相矛盾的输入。
 * （QSkinDatePicker 的 `flipUp` 是同一条判据，那边也是算出来的。）
 *
 * ════════════════════════════════════════════════════════════════════════
 * 步骤指示用 `1 / 3` 计数，不画点阵
 * ════════════════════════════════════════════════════════════════════════
 * Ant 画点阵、TDesign 画计数，两者表达的是同一个信息。这里取计数，
 * 因为点阵要一个 Repeater，而它的 delegate 只拿得到 `index` ——
 * "哪一个是当前步"必须从外层读，于是又一个"delegate 绑定引用外层 id"
 * 的场景（QSkinCalendar 里有一段完整的归因与实测）。为一行圆点再关一次
 * 静态检查不划算。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 模态，所以不登记 OverlayStack
 * ════════════════════════════════════════════════════════════════════════
 * 与 QSkinImage 的预览、QSkinDialog、QSkinDrawer 同一档：只写 `modal: true`。
 * OverlayStack 管的是**非**模态的排他浮层（见其文件头）。这一步是
 * 必须的 —— 漫游期间用户不能去点被遮住的任何东西。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 刻意不做
 * ════════════════════════════════════════════════════════════════════════
 *   · 自动滚动到目标（目标在滚动容器里时需要）。它要控件知道
 *     "谁是可滚的祖先"，还要处理滚动动画与洞位置的时间同步 ——
 *     那是另一个件的量（Ant 的 Tour 也只负责把元素滚进视口）。
 *   · 高亮的"呼吸"动效。
 ****************************************************************************/

import QtQuick 2.11
/* Popup 在 Controls 里。模态浮层 —— 与 QSkinDialog / QSkinImage 的预览同档。 */
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 步骤数组。每项：{ target?: Item, title, description }。
     *  `title` / `description` 可以是字符串或函数（见文件头）。 */
    property var steps: []

    /** 当前步（0 起）。 */
    property int current: 0

    /** 是否显示。程序化开合读 `opened`。 */
    property bool open: false

    /* ══════════════════════ 外观 ══════════════════════ */

    /** 是否画遮罩（关掉就只剩高亮框与面板）。 */
    property bool mask: true

    /** 是否显示"跳过"。 */
    property bool closable: true

    /** 高亮框向外扩张的量（洞比目标大一圈，看起来不顶边）。 */
    property int highlightPadding: Theme.space.xs

    /** 面板宽度。 */
    property int panelWidth: 320

    /** 高亮框的描边色。 */
    property color highlightColor: Theme.color.brand

    property string prevText:  qsTr("上一步")
    property string nextText:  qsTr("下一步")
    property string finishText: qsTr("完成")
    property string skipText:  qsTr("跳过")

    /* ══════════════════════ 事件 ══════════════════════ */

    signal changed(int current)
    signal finished()
    signal skipped()

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property int count:
        (root.steps && root.steps.length !== undefined) ? root.steps.length : 0

    readonly property var currentStep:
        (root.current >= 0 && root.current < root.count) ? root.steps[root.current] : null

    readonly property bool isFirst: root.current <= 0
    readonly property bool isLast:  root.current >= root.count - 1

    readonly property bool opened: popup.visible

    /** **几何什么时候才有意义** —— 浮层是惰性实例化的：
     *  `open = true` 之后 contentItem 还要等一帧才被交给 Popup 并定尺寸，
     *  在那之前 `_vw`/`_vh` 是 0，遮罩四块全是 0 尺寸（什么都不画）。
     *
     *  所以任何"读遮罩几何"的人（冒烟测试、抓图脚本）都必须先等这个读数
     *  变 true。**注意它管的是"浮层铺开了没有"，不是"洞算得对不对"** ——
     *  洞现在算在场景坐标里，从第一次求值起就是对的（见文件头"坑二"）。
     *  这个读数存在是因为：浮层 0×0 时读几何没有意义，而它的取值就是
     *  `_vw` —— 一个能被证伪的量。 */
    readonly property bool maskReady: root._vw > 0

    implicitWidth: 0
    implicitHeight: 0

    Accessible.role: Accessible.Dialog
    Accessible.name: root._text(root.currentStep ? root.currentStep.title : "")

    /* ══════════════════════ 文案取法 ══════════════════════ */

    /** 字符串原样、函数调用一次、其余按字符串处理（null → ""）。 */
    function _text(v) {
        if (v === null || v === undefined) return ""
        if (typeof v === "function") {
            var r = v(root.current)
            return r === null || r === undefined ? "" : String(r)
        }
        return String(v)
    }

    /* ══════════════════════ 几何 ══════════════════════
     *
     * 两个纯函数、两个 `readonly var` 绑定。分两个是因为它们的依赖不同：
     * 洞只跟目标控件的几何走，面板还跟自己的高度走。
     *
     * `_vw`/`_vh` 是浮层的视口尺寸（= 窗口尺寸）。**它必须是 root 自己的
     * 绑定**：三个几何函数都从 JS 里读它，而只有"读 root 自己的属性"这种
     * 读法才会被登记成依赖 —— 直接读 `maskLayer.width` 在浮层定尺寸时
     * 叫不醒它们（M24 实测，见文件头"坑二"）。 */

    readonly property real _vw: maskLayer !== null ? maskLayer.width  : 0
    readonly property real _vh: maskLayer !== null ? maskLayer.height : 0

    function _computeHole() {
        var st = root.currentStep
        var t = (st && st.target !== undefined && st.target !== null) ? st.target : null
        if (t === null || maskLayer === null) return null

        /* ⚠ 这一行是**必须**的，不是冗余 —— 见文件头"坑一"。
         * mapToItem 在 C++ 里读这四个属性，不经 JS 包装层，依赖不会
         * 被登记；显式读一遍才能让目标移动时本绑定重算。 */
        var _ = t.x + t.y + t.width + t.height

        /* 场景坐标，不是浮层坐标 —— 见文件头"坑二"。 */
        var p = t.mapToItem(null, 0, 0)
        var pad = root.highlightPadding
        var x = p.x - pad
        var y = p.y - pad
        var w = t.width  + pad * 2
        var h = t.height + pad * 2

        /* 还没定尺寸（=0）时**不钳**：那是"窗口多大还不知道"，而不是
         * "洞在窗口外面"。拿 0 去钳会把洞钳成一个零矩形 —— 初版的
         * `{0,0,0,0}` 就是这么来的。等 `_vw` 到了，这个绑定会重算。 */
        var W = root._vw
        var H = root._vh
        if (W <= 0 || H <= 0) return { x: x, y: y, w: w, h: h }

        /* 钳进窗口，免得洞的一部分落在外面（那时遮罩会出现负宽度） */
        var bx = Math.max(0, Math.min(W, x))
        var by = Math.max(0, Math.min(H, y))
        var bw = Math.max(0, Math.min(W, x + w) - bx)
        var bh = Math.max(0, Math.min(H, y + h) - by)

        return { x: bx, y: by, w: bw, h: bh }
    }

    /** 四块遮罩矩形。洞为 null 时退化成"整屏一块"。 */
    function _computeMask() {
        var W = root._vw
        var H = root._vh
        var o = root._hole

        if (o === null)
            return { top:    { x: 0, y: 0, w: W, h: H },
                     bottom: { x: 0, y: 0, w: 0, h: 0 },
                     left:   { x: 0, y: 0, w: 0, h: 0 },
                     right:  { x: 0, y: 0, w: 0, h: 0 },
                     frame:  { x: 0, y: 0, w: 0, h: 0 } }

        return {
            top:    { x: 0, y: 0, w: W, h: o.y },
            bottom: { x: 0, y: o.y + o.h, w: W, h: Math.max(0, H - (o.y + o.h)) },
            left:   { x: 0, y: o.y, w: o.x, h: o.h },
            right:  { x: o.x + o.w, y: o.y, w: Math.max(0, W - (o.x + o.w)), h: o.h },
            frame:  { x: o.x, y: o.y, w: o.w, h: o.h }
        }
    }

    /** 面板位置：洞下方放得下就放下方，否则放上方；横向居中并钳在窗口内。
     *  没有洞就居中。 */
    function _computePanel() {
        var W = root._vw
        var H = root._vh
        var pw = Math.min(root.panelWidth, Math.max(0, W - Theme.space.lg * 2))
        /* panelColumn 的高度在它自己被布局之前是 0；用 0 计算会得到
         * 一个贴边的位置，而布局完成后这个绑定会因为读到了真实高度
         * 而重算 —— 依赖是登记的（JS 层读 implicitHeight）。 */
        var ph = panelColumn.implicitHeight
        var o = root._hole
        var gap = Theme.space.sm

        if (o === null)
            return { x: Math.round((W - pw) / 2), y: Math.round((H - ph) / 2), w: pw }

        var below = o.y + o.h + gap
        var y = (below + ph <= H) ? below : Math.max(gap, o.y - gap - ph)
        var x = Math.max(gap, Math.min(W - pw - gap, o.x + o.w / 2 - pw / 2))

        return { x: Math.round(x), y: Math.round(y), w: pw }
    }

    /* ══════════════════════ 操作 ══════════════════════ */

    function goTo(i) {
        if (root.count <= 0) return
        var n = Math.max(0, Math.min(root.count - 1, i))
        if (n === root.current) return
        root.current = n
        root.changed(n)
    }

    function next() {
        if (root.isLast) { root.finish(); return }
        root.goTo(root.current + 1)
    }

    function prev() { root.goTo(root.current - 1) }

    function finish() {
        root._closing = true
        popup.close()
        root.finished()
    }

    function skip() {
        root._closing = true
        popup.close()
        root.skipped()
    }

    /** 标记"这次关闭是完成的/跳过的"，用来区分 Esc。 */
    property bool _closing: false

    onOpenChanged: {
        if (root.open && !popup.visible) {
            root._closing = false
            popup.open()
        } else if (!root.open && popup.visible) {
            root._closing = true
            popup.close()
        }
    }

    /* ══════════════════════ 浮层 ══════════════════════ */

    Popup {
        id: popup

        parent: Overlay.overlay
        width:  parent ? parent.width  : 0
        height: parent ? parent.height : 0
        padding: 0

        modal: true
        closePolicy: Popup.CloseOnEscape

        background: null

        onClosed: {
            if (root.open) root.open = false
            /* Esc 关掉 = 用户自己退出了 —— 那是一次 skipped。
             * finish() / skip() 已经把 _closing 置上，不会重复发。 */
            if (!root._closing) root.skipped()
            root._closing = false
        }

        contentItem: Item {
            id: maskLayer

            /* ══════ 遮罩四块 ══════ */
            Rectangle {
                x: root._mask.top.x; y: root._mask.top.y
                width: root._mask.top.w; height: root._mask.top.h
                color:   Theme.color.scrim
                opacity: root.mask ? Theme.color.scrimOpacity : 0
            }
            Rectangle {
                x: root._mask.bottom.x; y: root._mask.bottom.y
                width: root._mask.bottom.w; height: root._mask.bottom.h
                color:   Theme.color.scrim
                opacity: root.mask ? Theme.color.scrimOpacity : 0
            }
            Rectangle {
                x: root._mask.left.x; y: root._mask.left.y
                width: root._mask.left.w; height: root._mask.left.h
                color:   Theme.color.scrim
                opacity: root.mask ? Theme.color.scrimOpacity : 0
            }
            Rectangle {
                x: root._mask.right.x; y: root._mask.right.y
                width: root._mask.right.w; height: root._mask.right.h
                color:   Theme.color.scrim
                opacity: root.mask ? Theme.color.scrimOpacity : 0
            }

            /* ══════ 高亮框 ══════
             * 只描边、不填色 —— 填了就又把目标盖住了。 */
            Rectangle {
                x: root._mask.frame.x; y: root._mask.frame.y
                width: root._mask.frame.w; height: root._mask.frame.h
                visible: root._hole !== null
                radius: Theme.radius.md
                color: "transparent"
                border.width: 2
                border.color: root.highlightColor
            }

            /* ══════ 面板底 ══════
             * QSkinColumn 没有底色，所以垫一块 Rectangle。它是**兄弟**节点
             * （不是面板的子项）：QSkinColumn 内部是 ColumnLayout，往它里面
             * 塞一块 anchors.fill: parent 的矩形属于"布局管理的项上写
             * anchors"——未定义行为，不报错、不生效、某天悄悄歪掉
             * （QSkinDatePicker 记过这条）。位置靠读同一个 `_panel` 跟住。 */
            Rectangle {
                x: root._panel.x
                y: root._panel.y
                width:  root._panel.w
                height: panelColumn.implicitHeight
                radius: Theme.radius.lg
                color:        Theme.color.bgElevated
                border.width: 1
                border.color: Theme.color.border
            }

            /* ══════ 面板 ══════ */
            QSkinColumn {
                id: panelColumn

                x: root._panel.x
                y: root._panel.y
                width: root._panel.w
                padding: Theme.space.lg
                gap: Theme.space.sm

                /* ── 标题行：标题 + 计数 ── */
                QSkinRow {
                    Layout.fillWidth: true
                    align: "baseline"
                    gap: Theme.space.sm

                    Body {
                        Layout.fillWidth: true
                        text: root._text(root.currentStep ? root.currentStep.title : "")
                        font.weight: Theme.font.weightSemiBold
                    }

                    Caption {
                        visible: root.count > 1
                        text: (root.current + 1) + " / " + root.count
                        tone: "muted"
                    }
                }

                /* ── 描述 ── */
                Body {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root._text(root.currentStep ? root.currentStep.description : "")
                    tone: "secondary"
                }

                /* ── 底部按钮 ── */
                QSkinRow {
                    Layout.fillWidth: true
                    gap: Theme.space.sm

                    Spacer { }

                    QSkinButton {
                        visible: root.closable
                        text: root.skipText
                        variant: "text"
                        size: "sm"
                        onClicked: root.skip()
                    }

                    QSkinButton {
                        visible: !root.isFirst
                        text: root.prevText
                        variant: "default"
                        size: "sm"
                        onClicked: root.prev()
                    }

                    QSkinButton {
                        text: root.isLast ? root.finishText : root.nextText
                        variant: "primary"
                        size: "sm"
                        onClicked: root.next()
                    }
                }
            }
        }
    }

    /* ══════════════════════ 两个几何绑定 ══════════════════════
     * 放在文件末尾是有意的：它们读 maskLayer / panelColumn（都在上面
     * 声明）。QML 允许前向 id 引用，但把"谁依赖谁"写成阅读顺序更省事。 */

    readonly property var _hole:  root._computeHole()
    readonly property var _mask:  root._computeMask()
    readonly property var _panel: root._computePanel()
}
