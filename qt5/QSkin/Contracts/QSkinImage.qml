/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinImage
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 图片（M24）—— 一个框里放一张图，管好它的四件事：
 *
 *     放不放得下（fit）· 加载中长什么样 · 加载失败长什么样 · 点开之后是什么
 *
 * ════════════════════════════════════════════════════════════════════════
 * `src` 而不是 `source`
 * ════════════════════════════════════════════════════════════════════════
 * 与 QSkinAvatar 对齐（qdscollapse / qdsavatar 早于本件定下的词汇）。
 * 类型必须是 **url** 而不是 string：QML 对 url 型属性会在**书写它的那个
 * 文件**里解析相对路径。写成 string 再转手传下来，相对路径会解析到
 * 中间某个控件所在的目录 —— 这是那种"只在一个部署布局下才错"的 bug。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么是**两个** Image 节点，而不是一个 + 派生的 effectiveSource
 * ════════════════════════════════════════════════════════════════════════
 * 备用图（fallbackSrc）的常见写法是：
 *
 *     source: primaryFailed ? fallbackSrc : src
 *
 * 这是**一个环**：`source` 由 `status` 派生，而 `status` 又由 `source` 决定。
 * 主图失败 → source 换成备用图 → status 变成 Loading → primaryFailed 转回
 * false → source 换回主图 → 再失败 …… 屏幕上表现为一两帧的来回跳。
 *
 * 本件用两个独立节点把环剪开：每个节点的 `source` 只依赖**另一个节点之外**
 * 的东西（自己的 src / fallbackSrc 输入，以及**主图**的 status）。
 * 备用图的 status 只进判定、不再回写任何 source。
 *
 *     主图.status ──→ 要不要去取备用图
 *     备用图.status ─→ 只决定"现在显示谁"、"算不算彻底失败"
 *
 * 代价是一个常驻节点，且备用图**只在主图真的报错之后**才去取
 * （`spared.source` 在主图成功时是空串），所以正常路径下它不解码任何东西。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 判"有没有图"**必须过 `String()`** —— 本项目第三次撞上它
 * ════════════════════════════════════════════════════════════════════════
 * `url` 型属性交给 JS 的是 QUrl 对象，不是字符串：
 *
 *     property url u: ""
 *     u === ""     -> false        u == ""  -> true        String(u) -> ""
 *
 * QSkinEmpty 在这里丢了整块插图（见其文件头，那是两次），QSkinAvatar 的
 * `showImage` 是同一条修正。本件所有"给没给地址"的判断一律走
 * `String(...) !== ""`。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 圆角：MultiEffect 遮罩的**第二个**消费者
 * ════════════════════════════════════════════════════════════════════════
 * 沿用 QSkinAvatar 的实测结论，不重做一遍：`Rectangle.clip` 只裁包围盒、
 * 不裁圆角（Qt 的长期行为），所以圆角图片必须走
 * `layer.enabled + MultiEffect { maskEnabled; maskSource: 圆角矩形 }`。
 *
 * 遮罩矩形**必须与图片同圆角**，否则裁出来的是方角 —— 这是两个节点之间
 * 唯一需要对齐的量，所以它们共用同一个 `root.radius`。
 *
 * 成本与降级与 QSkinAvatar 完全一样，直接搬过来：
 *   · `radius === 0` 时（或没有图时）`layer.enabled` 为 false，
 *     开销与不加遮罩完全相同；
 *   · 软件后端下降级为**方角**（图照常显示，只是四角没被裁）。可见的
 *     降级好过整块不显示。
 * 与 M18 那句"不引入 QtQuick.Effects"不矛盾：阴影是可选的表现力，
 * 圆角遮罩是正确性。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 比例约束**不做** —— 因为 QSkinAspectRatio 已经存在
 * ════════════════════════════════════════════════════════════════════════
 * 本件不提供 `ratio`。要固定比例就套一层：
 *
 *     QSkinAspectRatio {
 *         ratio: 16 / 9
 *         width: parent.width
 *         QSkinImage { anchors.fill: parent; src: "…" }
 *     }
 *
 * 这是 M19 抽出 QSkinAspectRatio 的**用途兑现**，不是省事：比例是"容器"
 * 的属性，把它塞进图片框会让同一件事在两个控件里各有一套算法
 * （而且必然有一套会漏掉 `implicitHeight` 与 Layout 的互动）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 预览是**模态**，所以它不登记 OverlayStack
 * ════════════════════════════════════════════════════════════════════════
 * OverlayStack 管的是"**非**模态的排他浮层"（Popover / Popconfirm /
 * Dropdown / ContextMenu —— 见其文件头）。模态浮层由 Qt 的 modality 兜底，
 * 项目里 Dialog / Drawer 都只写 `modal: true` 而**不**入栈（实据：
 * QSkinDialog.qml:81、QSkinDrawer.qml:85 各一行 `modal: true`，全仓
 * `OverlayStack` 的调用点只有 QSkinPopover 一处）。全屏看图属于后者，
 * 于是它跟着 Dialog 那一档走 —— 同一份判据，不是"这次懒得接"。
 *
 * 遮罩比 Dialog 重一档，但**不写死 0.9**：深色主题的 `scrimOpacity`
 * 本来就是 0.55，加常数会溢出。取 `min(0.9, scrimOpacity + 0.35)`
 * —— 浅色 0.75 / 深色 0.90，两边都落在"遮住上下文、但还看得出后面有东西"。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 刻意**不做**的两件（都写进 COVERAGE.md 的待办，不是悄悄少做）
 * ════════════════════════════════════════════════════════════════════════
 *   1. 缩放 / 旋转 / 双击复位工具栏（Ant 的 preview 有）。
 *      它需要一个视图状态机（倍数、拖拽偏移、复位）与手势处理，
 *      那是 **QSkinImageViewer** 的量，不是"图片框"的量。判据用项目自己的
 *      那条：**两件事挤在一格，任何一次改动都会顺带改掉另一件**
 *      （M4 把 switch/check 拆开是它的正面）。
 *   2. 加载中的动效骨架条。图片的加载窗口通常只有几十毫秒，
 *      上一屏闪一下比没有还难看。要动效就给 `placeholderComponent`。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 悬停遮罩里的放大镜、预览关闭按钮 —— 如实记一笔
 * ════════════════════════════════════════════════════════════════════════
 * 放大镜用两个 Rectangle 画（一个描边圆 + 一根旋转 45° 的柄），
 * **不需要 Shape**：圆的描边由 Rectangle 的 border + radius 给出，
 * 像素级准确，也就不必再挂 preferredRendererType。
 *
 * 关闭按钮的 × 是**第三次**抄 QSkinAlert 的那六个坐标（0.24 / 0.76，
 * 笔宽 = 边长的 0.14）。这里如实标注，免得它变成第四次：
 * 「同一个 affordance 在同一仓库里有 N 种画法」是本项目已经付过四次
 * 代价的病（见 Slots.qml 文件头「展开箭头」那段）。但**收进插槽的条件是
 * 「形态有分歧」**（四家的 × 完全一致，分歧只在尺寸/颜色），所以它现在
 * 够不上一个插槽 —— 够格的是另一件事：**重复**。触发点是"第四次"，
 * 到那时应当抽的也不是插槽，而是契约层的一个内部 glyph 组件。
 ****************************************************************************/

import QtQuick 2.15
/* Popup 在 Controls 里。项目其它浮层宿主（QSkinDialog / QSkinPopover /
 * QSkinTooltip）一律 import 这个模块，本件跟着走 —— 预览是模态浮层，
 * 与 Dialog 同一档（见文件头"预览是模态"。） */
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.15
import QtQuick.Shapes 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    /** 图片地址。见文件头"src 而不是 source"。 */
    property url src: ""

    /** 主图加载失败时的备用地址。也失败就退到 errorComponent / 内置矢量。 */
    property url fallbackSrc: ""

    /** 无障碍名称，也是图片的替代文本。 */
    property string alt: ""

    /* ══════════════════════ 外观 ══════════════════════ */

    /** cover | contain | fill | none | scale-down，对应 CSS object-fit 同名值。 */
    property string fit: "cover"

    /** 圆角。0 表示不遮罩（省掉一次离屏渲染），见文件头。 */
    property real radius: Theme.radius.lg

    /* ══════════════════════ 占位 / 失败 ══════════════════════ */

    /** 加载中是否显示占位块。 */
    property bool showPlaceholder: true

    /** 自定义占位内容（尺寸由本件给满，内部请用 anchors 自适应）。 */
    property Component placeholderComponent: null

    /** 自定义失败内容。不给就用内置矢量。 */
    property Component errorComponent: null

    /* ══════════════════════ 预览 ══════════════════════ */

    /** 点图打开全屏预览。 */
    property bool preview: false

    /** 预览用的地址。默认与当前生效地址相同。 */
    property url previewSrc: ""

    /** 悬停时显示遮罩（放大镜）。触屏没有 hover，因此不会出现。 */
    property bool previewMask: true

    /* ══════════════════════ 覆盖层 ══════════════════════
     *
     * 子项会**叠在图片之上**、同一个圆角框内（Ant 的 children 口径）。
     * 唯一一个内容宿主，直接挂在根上 —— "两个形态写成两个容器"那个坑
     * （QSkinDescriptionsItem 首版）在这里没有土壤：本件只有一个形态。 */

    default property alias overlay: overlayHost.data

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property bool hasSource:   String(root.src) !== ""
    readonly property bool hasFallback: String(root.fallbackSrc) !== ""

    readonly property bool _showPrimary:
        root.hasSource
        && portrait.status !== Image.Error
        && portrait.status !== Image.Null

    /** 主图确实取不出来了，才去取备用图。 */
    readonly property bool _loadFallback: root.hasFallback && !root._showPrimary

    readonly property bool _showFallback:
        root._loadFallback
        && spared.status !== Image.Error
        && spared.status !== Image.Null

    /** 图片是否可用。**不能**写成"有 src 就显示"：加载失败时 Image 画不出
     *  东西，但下面那层占位块会被一个空图挡住（QSkinAvatar showImage 同款）。 */
    readonly property bool showImage: root._showPrimary || root._showFallback

    /** 彻底失败：主图报错，且（没有备用图 或 备用图也报错）。 */
    readonly property bool _errored:
        portrait.status === Image.Error
        && (!root.hasFallback || spared.status === Image.Error)

    /** empty | loading | ready | error */
    readonly property string status:
        !root.hasSource ? "empty"
      : root.showImage  ? "ready"
      : root._errored   ? "error"
                        : "loading"

    /** 当前真正在显示的地址。预览与"另存"这类动作读它。 */
    readonly property url effectiveSource:
        root._showFallback ? root.fallbackSrc : root.src

    readonly property bool hovered: hoverMa.containsMouse
    readonly property bool previewVisible: previewPopup.visible

    /** 预览里显示的地址：显式给了 previewSrc 就用它，否则用当前生效地址。 */
    readonly property url previewSource:
        String(root.previewSrc) !== "" ? root.previewSrc : root.effectiveSource

    /** 是否开着圆角遮罩（供测试与主题核对，别让"降级了"没人知道）。 */
    readonly property bool masked: root.showImage && root.radius > 0

    signal clicked()
    signal loaded()
    signal errored()
    signal previewOpened()
    signal previewClosed()

    /* 状态迁移即事件。声明期到首次就绪也会走一次 —— 这是想要的：
     * "图来了"就是一次 loaded，不论它来得有多快。 */
    onStatusChanged: {
        if (root.status === "ready") root.loaded()
        else if (root.status === "error") root.errored()
    }

    /* 本件不定 implicit 尺寸 —— 图片的可用尺寸只有宿主知道。
     * 宿主请给 width/height，或放进 QSkinAspectRatio / Layout 里。 */
    implicitWidth: 0
    implicitHeight: 0

    /* 只有 `fit: "none"` 会溢出（原尺寸不缩放），也只有它需要裁。
     * 其余四种 fillMode 里 Qt 自己就裁在 item 边界内。
     * 注意：这是**包围盒**裁剪，不裁圆角 —— 圆角归 maskSrc 那条路。 */
    clip: root.fit === "none"

    Accessible.role: Accessible.Graphic
    Accessible.name: root.alt

    /* ══════════════════════ object-fit 映射 ══════════════════════
     *
     * **公开纯函数**，与 QSkinStatistic.formatValue 同一姿态：映射有五个
     * 取值、其中两个（none / scale-down）不是 Qt 枚举的一一对应，所以
     * 它有真正的判断要测。藏在一个内层 QtObject 里的话，冒烟测试只能
     * 去读 `fillMode` 这个**渲染参数**，而读不到"为什么是它"。
     *
     * 参数一律显式传入（不读 root.*），于是它可以被单独调用来验：
     *
     *     QSkinImage.fillModeOf("scale-down", 40, 40, 200, 200)  → Image.Pad
     *     QSkinImage.fillModeOf("scale-down", 400, 400, 200, 200) → PreserveAspectFit
     *
     * 前一条正是"scale-down ≠ contain"的可证伪形式。
     */
    function fillModeOf(fit, naturalWidth, naturalHeight, boxWidth, boxHeight) {
        if (fit === "scale-down") {
            /* 图比框小 → 原尺寸（Pad）；否则缩到放得下。
             * 自然尺寸未知（0）时按"缩到放得下"处理 —— 那是保守的一侧，
             * 且只在解码完成前的那一帧成立。 */
            if (naturalWidth > 0 && naturalHeight > 0
                    && naturalWidth <= boxWidth && naturalHeight <= boxHeight)
                return Image.Pad
            return Image.PreserveAspectFit
        }
        switch (fit) {
        case "contain":    return Image.PreserveAspectFit
        case "fill":       return Image.Stretch
        case "none":       return Image.Pad
        default:           return Image.PreserveAspectCrop
        }
    }

    function openPreview() {
        if (!root.showImage || !root.preview) return
        previewPopup.open()
    }

    function closePreview() { previewPopup.close() }

    /* ══════════════════════ 底 ══════════════════════ */

    Rectangle {
        anchors.fill: parent
        color:  Theme.color.bgSunken
        radius: root.radius
    }

    /* ══════════════════════ 主图 / 备用图 ══════════════════════ */

    Image {
        id: portrait

        anchors.fill: parent
        visible:      root._showPrimary
        source:       root.src
        fillMode:     d.fillMode()
        asynchronous: true

        /* layer.effect 是**对象声明**（等价于就地造一个 Component），
         * 里面引用外层 id 会被 qmllint 判为 Unqualified access ——
         * 与 QSkinAvatar 同一处局限，局部关闭。 */
        layer.enabled: root.masked && root._showPrimary
        // qmllint disable unqualified
        layer.effect: OpacityMask {
            maskSource: maskSrc
        }
        // qmllint enable unqualified
    }

    Image {
        id: spared

        anchors.fill: parent
        visible: root._showFallback

        /* 主图成功时**是空串**：备用图不解码任何东西（见文件头）。 */
        source: root._loadFallback ? root.fallbackSrc : ""
        fillMode:     d.fillMode()
        asynchronous: true

        layer.enabled: root.masked && root._showFallback
        // qmllint disable unqualified
        layer.effect: OpacityMask {
            maskSource: maskSrc
        }
        // qmllint enable unqualified
    }

    ShaderEffectSource {
        id: maskSrc

        hideSource: true
        sourceItem: Rectangle {
            width:  root.width
            height: root.height
            radius: root.radius
            color:  "#FFFFFF"
        }
    }

    QtObject {
        id: d

        /** 内置失败记号的边长：跟着框走，但有上下限 ——
         *  下限保证 32×32 的小头像位也看得见，上限免得 800×600 的
         *  画框里出现一个占满屏的"破图"。 */
        readonly property real size:
            Math.max(24, Math.min(72, Math.round(Math.min(root.width, root.height) * 0.3)))

        /* 映射本身是公开纯函数（见根上的 fillModeOf）。
         * 这里只负责把"当前状态的四个量"喂进去 —— 自然尺寸读 Image 自己的
         * `implicitWidth/Height`（加载完成后才有值，之前是 0），所以图片
         * 解码完成的那一帧 fit 可能从 Pad 翻到 Fit。那是一次真实的、
         * 可见的重排，不是抖动：在它之前本来就没有图可画。 */
        function fillMode() {
            return root.fillModeOf(root.fit,
                                   portrait.implicitWidth, portrait.implicitHeight,
                                   root.width, root.height)
        }
    }

    /* ══════════════════════ 加载中占位 ══════════════════════ */

    Loader {
        id: placeholderLoader

        anchors.fill: parent
        visible: root.showPlaceholder && root.status === "loading"
                 && root.placeholderComponent !== null
        sourceComponent: root.placeholderComponent
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color:  Theme.color.bgSunken
        visible: root.showPlaceholder && root.status === "loading"
                 && root.placeholderComponent === null
    }

    /* ══════════════════════ 失败 ══════════════════════ */

    Loader {
        id: errorLoader

        anchors.fill: parent
        visible: root.status === "error" && root.errorComponent !== null
        sourceComponent: root.errorComponent
    }

    /* 内置失败记号：一个描边框 + 地平线 + 一枚"太阳" + 一道斜杠。
     * 全部用 Rectangle —— 圆角矩形没有斜边，Shape 的唯一优势（原生抗锯齿）
     * 用不上，反而要多挂一个 preferredRendererType（QSkinEmpty 同款判断）。
     *
     * 斜杠的几何：一根长 `g * √2` 的细条绕中心转 45°，其**包围盒恰好是
     * g × g**，与父框等大，所以不需要 clip 也不会溢出。 */
    Item {
        id: errArt

        anchors.centerIn: parent
        visible: root.status === "error" && root.errorComponent === null

        width:  d.size
        height: d.size

        Rectangle {
            anchors.fill: parent
            radius: Math.round(errArt.width * 0.12)
            color:  "transparent"
            border.width: Math.max(1, Math.round(errArt.width * 0.045))
            border.color: Theme.color.borderStrong
        }

        Rectangle {
            x: Math.round(errArt.width * 0.14)
            y: Math.round(errArt.height * 0.66)
            width:  Math.round(errArt.width * 0.44)
            height: Math.max(1, Math.round(errArt.height * 0.045))
            radius: height / 2
            color:  Theme.color.borderStrong
        }

        Rectangle {
            x: Math.round(errArt.width * 0.22)
            y: Math.round(errArt.height * 0.34)
            width:  Math.round(errArt.width * 0.14)
            height: width
            radius: width / 2
            color:  Theme.color.borderStrong
        }

        Rectangle {
            anchors.centerIn: parent
            width:  Math.round(errArt.width * 1.4142)
            height: Math.max(1, Math.round(errArt.height * 0.045))
            radius: height / 2
            rotation: 45
            color:  Theme.color.borderStrong
        }
    }

    /* ══════════════════════ 悬停遮罩 ══════════════════════ */

    Rectangle {
        id: hoverMask

        anchors.fill: parent
        radius: root.radius
        color:  Theme.color.scrim
        opacity: 0.32

        visible: root.preview && root.previewMask && root.showImage
                 && root.hovered
    }

    Rectangle {
        /* 悬停高亮亮一档，但只亮在预览可用时 —— 否则那是一次"点了没反应"。 */
        anchors.fill: parent
        radius: root.radius
        color:  "transparent"
        border.width: 1
        border.color: Theme.color.brand
        visible: root.preview && root.showImage && root.hovered
                 && hoverMa.pressed
    }

    /* 放大镜：描边圆 + 旋转 45° 的柄。颜色用 onBrand（= 四家的 #FFFFFF），
     * 与 BasicStatusGlyph 同一条理由：写死 "#FFFFFF" 在浅色下是数值空操作，
     * 但那就把"这个颜色属于主题"悄悄丢掉了。 */
    Item {
        id: magnifier

        anchors.centerIn: parent
        visible: hoverMask.visible

        width:  magSize
        height: magSize

        readonly property real magSize: 24

        Rectangle {
            x: 1; y: 1
            width:  Math.round(parent.width * 0.62)
            height: width
            radius: width / 2
            color:  "transparent"
            border.width: Math.max(1.5, parent.width * 0.075)
            border.color: Theme.color.onBrand
        }

        Rectangle {
            /* 柄的起端落在圆边上、末端落在框角，两端各让出半个笔宽。 */
            readonly property real k: parent.width / 24

            width:  Math.round(9 * k)
            height: Math.max(1.5, Math.round(2 * k))
            radius: height / 2
            color:  Theme.color.onBrand

            x: Math.round(13.3 * k)
            y: Math.round(17.1 * k)
            rotation: 45
            transformOrigin: Item.Center
        }
    }

    /* ══════════════════════ 覆盖层（子项） ══════════════════════ */

    Item {
        id: overlayHost

        anchors.fill: parent
    }

    /* ══════════════════════ 点击 ══════════════════════ */

    MouseArea {
        id: hoverMa

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.preview
        cursorShape: hoverMa.enabled && root.showImage
                     ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.clicked()
            root.openPreview()
        }
    }

    /* ══════════════════════ 预览（模态） ══════════════════════ */

    Popup {
        id: previewPopup

        /* 挂到窗口 Overlay 层 —— root 本体在调用方布局里可能只有 0×0，
         * 直接 centerIn parent 会飘（M4 的浮层经验，QSkinDialog 同款）。 */
        parent: Overlay.overlay
        anchors.centerIn: parent
        width:  parent ? parent.width  : 0
        height: parent ? parent.height : 0
        padding: 0

        modal: true
        closePolicy: Popup.CloseOnEscape

        onOpened:   root.previewOpened()
        onClosed:   root.previewClosed()

        Overlay.modal: Rectangle {
            color:   Theme.color.scrim
            opacity: Math.min(0.9, Theme.color.scrimOpacity + 0.35)
        }

        background: null

        contentItem: Item {
            /* 点空白处关闭。Popup 本身铺满全窗，没有"外面"可按，
             * 所以这个 MouseArea 是遮罩自己的点击面。 */
            MouseArea {
                anchors.fill: parent
                onClicked: previewPopup.close()
            }

            Image {
                id: previewImage

                anchors.fill: parent
                anchors.margins: Theme.space.xxl
                source: previewPopup.visible ? root.previewSource : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true

                /* 空 MouseArea 只为**吞掉**点击 —— 点图不该关掉预览
                 * （Ant 的行为：只有点遮罩才关）。 */
                MouseArea { anchors.fill: parent }
            }

            /* 关闭按钮：圆形底 + 两道对角线。坐标抄 QSkinAlert 的 ×
             * （0.24 / 0.76），见文件头那段"如实记一笔"。 */
            Item {
                id: previewClose

                anchors.top:  parent.top
                anchors.right: parent.right
                anchors.margins: Theme.space.xl
                width:  Theme.size.controlMd
                height: Theme.size.controlMd

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color:  Theme.color.scrim
                    opacity: closeMa.containsMouse ? 0.55 : 0.32
                }

                Shape {
                    anchors.fill: parent

                    ShapePath {
                        strokeWidth: Math.max(1, previewClose.width * 0.14)
                        strokeColor: Theme.color.onBrand
                        fillColor:   "transparent"
                        capStyle:    ShapePath.RoundCap

                        startX: previewClose.width * 0.24
                        startY: previewClose.height * 0.24
                        PathLine { x: previewClose.width * 0.76
                                   y: previewClose.height * 0.76 }
                    }

                    ShapePath {
                        strokeWidth: Math.max(1, previewClose.width * 0.14)
                        strokeColor: Theme.color.onBrand
                        fillColor:   "transparent"
                        capStyle:    ShapePath.RoundCap

                        startX: previewClose.width * 0.76
                        startY: previewClose.height * 0.24
                        PathLine { x: previewClose.width * 0.24
                                   y: previewClose.height * 0.76 }
                    }
                }

                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: previewPopup.close()
                }
            }
        }
    }
}
