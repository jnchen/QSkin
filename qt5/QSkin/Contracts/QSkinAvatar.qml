/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinAvatar
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 头像 —— 一个圆（或圆角方）里放一张图、一个图标，或者几个字。
 *
 * ── 内容的优先级是**固定**的，不是"看调用方心情"─────────────────────────
 *
 *     1. src（图片）        有图就用图
 *     2. icon（图标）       没图就用图标
 *     3. text（文字）       没图没图标就用文字（姓名缩写 / 首字母）
 *
 * 这条顺序是三家共有的（Ant: src > icon > children；TDesign: image >
 * icon > 文字），所以写死在控件里而不是给一个 `priority` 开关 ——
 * 换一家设计语言的差别不在这件事上。
 *
 * ── `text` 不叫 `initials`，也不自动缩写 ────────────────────────────────
 * "张伟"该显示成"张"还是"张伟"？"Ada Lovelace"该是"AL"还是"A"？
 * 中文取姓、西文取首字母、日语取什么 —— 这是**本地化 + 业务**的判断，
 * 不是控件的。控件只负责把它拿到的字符串**尽量大地**放在圆里
 * （见 autoFixFontSize），缩写规则留给调用方。
 *
 * ── 刻意不做"按名字自动配色"────────────────────────────────────────────
 * 那是很多实现会加的一层小聪明（哈希姓名 → 从调色板取色）。
 * 不加的理由是可核验的：**三家设计系统的默认底色都是中性灰**
 * （Ant `#ccc`、TDesign 的 gray 容器色、Arco 的灰底），
 * "谁该是什么颜色"是内容的语义，不是控件的外观契约。
 * 真需要时调用方传 `backgroundColor` —— 一行的事，且这一行会
 * 出现在代码评审里（好事）。
 *
 * ── 圆形裁图：这是本项目唯一一处有代价的技术取舍，写在明面上 ────────────
 *
 * 需求很简单：`shape: "circle"` 的头像放一张方图，四个角必须被裁掉。
 *
 * 实测（`.cache/_probe_clip.qml`，两条路各画一个 120×120 的红方块、
 * 白底，然后去量左上角 4px 处的像素）：
 *
 *     Rectangle { radius: w/2; clip: true } + 子项
 *         → 左上角仍是 #E53935。**Qt 的 clip 只裁包围盒，不裁圆角**
 *           （这是长期存在的行为，不是本版本的 bug）
 *     MultiEffect { maskEnabled; maskSource: 圆角矩形 }
 *         → 左上角是 #FFFFFF，中心是 #E53935。**圆角遮罩成立**
 *
 * 于是这里用了 `QtQuick.Effects` 的 MultiEffect —— 这是本项目
 * **第一次**引入这个模块，与 M18 那句"层次用底色/描边而不是阴影，
 * 所以不引入 QtQuick.Effects"并不矛盾，但差别值得说清楚：
 *
 *     阴影是**可选的表现力** —— 没有阴影，卡片也能靠三档底色分层；
 *     圆角遮罩是**正确性** —— 没有它，"圆形头像"这四个字就是假的。
 *
 * 成本与降级，两条都写在这儿：
 *   · 只在真的有图且有圆角时才开（`layer.enabled`）—— 纯文字/图标
 *     头像的开销与从前完全一样；
 *   · 遮罩需要支持效果的渲染后端（RHI 默认即可）。软件后端下降级为
 *     **方角** —— 图片照常显示，只是四角没被裁掉。这是个可见的降级，
 *     比"头像整个不显示"好得多。
 ****************************************************************************/

import QtQuick 2.15
import QtGraphicalEffects 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    /** 图片地址。用 url 型而不是 string ——
     *  QML 对 url 属性会在**书写它的那个文件**里解析相对路径，
     *  写成 string 再转手传下去会解析到中间某个控件所在的目录。 */
    property url src: ""

    /** 主图加载失败时的备用地址。也失败就退到 icon / text。 */
    property url fallbackSrc: ""

    /** 图标（可选）。会被缩放到头像的 60%，请自行 `anchors.fill: parent`。 */
    property Component icon: null

    /** 文字（姓名缩写 / 首字母）。只在没有图和图标时显示。 */
    property string text: ""

    /** 无障碍名称。也是图片的替代文本。 */
    property string alt: ""

    /* ══════════════════════ 外观 ══════════════════════ */

    /** circle | square */
    property string shape: "circle"

    /** sm | md | lg | xl，或者直接给像素数。
     *  sm=24 / md=32 / lg=40 / xl=64 —— 其中 32 是 Ant 的 default、
     *  40 是 Ant 的 large，两个最常用的档位与官方对齐。 */
    property var size: 40

    /** cover | contain | fill，对应 CSS 的同名值。 */
    property string imageFit: "cover"

    /** 文字放不下时自动缩小字号（Arco 的 autoFixFontSize）。
     *  关掉它长名字会被裁掉 —— 只在"名字长度受控"时才该关。 */
    property bool autoFixFontSize: true

    /** 底色。见文件头"刻意不做自动配色"。 */
    property color backgroundColor: Theme.color.bgSunken

    /** 文字颜色。 */
    property color foregroundColor: Theme.color.fgSecondary

    /* ══════════════════════ 组内叠放 ══════════════════════
     *
     * 这两个属性是给 QSkinAvatarGroup 用的：叠放时后一张要压住前一张，
     * 中间得有一圈**底色的边**把两个圆分开，否则两个头像会糊成一团。
     * 单用时保持 0 即可。 */

    property int ringWidth: 0
    property color ringColor: Theme.color.bgElevated

    /* ══════════════════════ 派生 ══════════════════════ */

    /** 边长（像素）。 */
    readonly property int px:
        typeof root.size === "number" ? Math.max(8, Math.round(root.size))
      : root.size === "sm" ? 24
      : root.size === "lg" ? 40
      : root.size === "xl" ? 64
                           : 32

    /** 圆角半径。圆形 = 半径；方形取主题的 lg 档，但不超过边长的 1/4 ——
     *  否则一个 24px 的小头像会被圆到看不出是方的。 */
    readonly property real cornerRadius:
        root.shape === "circle" ? root.px / 2
                                : Math.min(Theme.radius.lg, root.px / 4)

    readonly property bool _primaryFailed: portrait.status === Image.Error
    readonly property bool _fallbackActive:
        root._primaryFailed && String(root.fallbackSrc) !== ""

    /** 真正要加载的地址。 */
    readonly property url effectiveSource:
        root._fallbackActive ? root.fallbackSrc : root.src

    /** 图片是否可用。**不能**写成"有 src 就显示" ——
     *  加载失败时 Image 本身画不出东西，但下面的图标/文字会被
     *  一个空图挡住。所以判据必须包含 status。 */
    readonly property bool showImage:
        String(root.effectiveSource) !== ""
        && portrait.status !== Image.Error
        && portrait.status !== Image.Null

    readonly property bool showIcon: !root.showImage && root.icon !== null
    readonly property bool showText: !root.showImage && !root.showIcon
                                     && root.text !== ""

    /** 是否需要圆角遮罩。 */
    readonly property bool _needsMask: root.cornerRadius > 0

    implicitWidth:  root.px
    implicitHeight: root.px

    width:  implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: root.alt !== "" ? root.alt : root.text

    /* ══════════════════════ 底板 ══════════════════════ */

    Rectangle {
        id: plate

        anchors.fill: parent
        radius: root.cornerRadius
        color:  root.backgroundColor
    }

    /* ══════════════════════ 图片 ══════════════════════
     *
     * 遮罩的写法：layer.effect 把 Image 渲进一张离屏纹理，再让
     * MultiEffect 用 maskSource 的形状把它裁出来。
     * maskSource 是一块与底板同尺寸、同圆角的白色矩形
     * （白色 = 保留；MultiEffect 取的是 alpha，圆形内不透明、外透明）。 */

    Image {
        id: portrait

        anchors.fill: parent
        visible: root.showImage

        source: root.effectiveSource
        fillMode: root.imageFit === "contain" ? Image.PreserveAspectFit
                : root.imageFit === "fill"    ? Image.Stretch
                                              : Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width:  root.px * 2      /* 头像永远不需要原图分辨率 */
        sourceSize.height: root.px * 2

        /* layer.effect 是**对象声明**（等价于就地造一个 Component），
         * 它里面引用外层的 id 会被 qmllint 判为 Unqualified access ——
         * 与 inline Component 同一个局限，局部关闭。 */
        layer.enabled: root.showImage && root._needsMask
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
            width:  plate.width
            height: plate.height
            radius: root.cornerRadius
            color:  "#FFFFFF"
        }
    }

    /* ══════════════════════ 图标 ══════════════════════ */

    Loader {
        id: iconLoader

        anchors.centerIn: parent
        visible: root.showIcon

        width:  Math.round(root.px * 0.6)
        height: Math.round(root.px * 0.6)

        sourceComponent: root.showIcon ? root.icon : null
    }

    /* ══════════════════════ 文字 ══════════════════════
     *
     * 居中的写法与 QSkinBadge 同源：anchors.fill + 自带垂直居中，
     * 靠 Text 自己的行盒压回中线（只 centerIn 会因字体下行留白而偏高）。
     *
     * 自动缩字号用 Text.fontSizeMode: Text.Fit，而不是自己去量
     * 字符串宽度再算一个系数 —— 后者必须猜平均字宽，中英文混排时
     * 必错，而且中文没有"字母"可数（"张伟"两个字符占的宽度是
     * "Zhang"的 1/3，按长度算会得出完全相反的字号）。 */

    Text {
        id: initialText

        anchors.fill: parent
        anchors.margins: Math.round(root.px * 0.15)
        visible: root.showText

        text: root.text

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment:   Text.AlignVCenter
        wrapMode: Text.NoWrap
        renderType: Text.NativeRendering

        fontSizeMode: root.autoFixFontSize ? Text.Fit : Text.FixedSize
        minimumPixelSize: Math.max(8, Math.round(root.px * 0.22))
        font.family:    Theme.font.family
        font.pixelSize: Math.round(root.px * 0.45)
        font.weight:    Theme.font.weightMedium
        color:          root.foregroundColor
    }

    /* ══════════════════════ 叠放描边 ══════════════════════ */

    Rectangle {
        visible: root.ringWidth > 0
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border.width: root.ringWidth
        border.color: root.ringColor
    }
}
