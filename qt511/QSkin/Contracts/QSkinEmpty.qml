/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinEmpty
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 空态 —— "这里本该有东西，但现在没有"。
 *
 * ── 为什么它值得是一个独立控件 ──────────────────────────────────────────
 * 在这个控件出现之前，QSkin 里已经有 6 处各自画了一遍空态文字
 * （Select / Table / Tree / List / Breadcrumb / DatePicker 的 emptyText），
 * 深浅、字号、留白各不相同。这些地方真正需要的不是"一句灰字"，
 * 而是一整块**结构**：插图 + 说明 + 一个把用户带出去的按钮。
 * 把这个结构收进一个控件，六个调用点才能同时变好。
 *
 * ── 插图画的是矢量，不是字符，也不是位图 ────────────────────────────────
 * 项目规矩「图标不用字符」在这里落地成一件具体的事：内置插图画成
 * **两张错开的纸**（一深一浅、前一张带描边与三条内容线），
 * 而不是找一个 "📄" 或者 "∅" 之类的字形。
 *
 * 三个理由，按重要性排：
 *   ① 字形在不同机器上的回退链不可控（M15.1 那条规矩的原始动机）；
 *   ② 字号缩放时纸的**描边宽度**不跟着缩放，放大后线细得像掉了；
 *   ③ 插图是要跟主题走的 —— 深色主题下纸得换底色，字符办不到。
 *
 * ── 为什么插图用一排 Rectangle、不用 Shape ──────────────────────────────
 * 这张插图**没有一条斜线**（全是圆角矩形），于是 Shape 的唯一优势
 * （原生抗锯齿）用不上，反而会引入一个必须记得写 preferredRendererType
 * 的坑（见 tools/check-shape-aa.py）。圆角矩形用 Rectangle 画，
 * 任何渲染后端下都对，而且几何全是整数、像素核验好量。
 *
 * ── 三种"换插图"的方式，本实现只收两种 ─────────────────────────────────
 *   imageSource: "qrc:/my-empty.svg"   换成自己的图（Arco 的 imgSrc 口径）
 *   imageSource: ""                     用内置矢量（Ant 的 PRESENTED_IMAGE
 *                                       口径 / TDesign 的默认插图）
 * 第三种（Ant 的 `image` 收 ReactNode、TDesign 的 image 是具名插槽）
 * 在本项目里被**刻意不做**：那等于给插图开一个 Component 槽，而
 * "换掉整块空态"的正当做法是调用方自己摆一个 QSkinColumn ——
 * 中间那半截 API 只会让主题作者多一个要照顾的格子。
 *
 * ── 判"有没有自定义插图"**必须过 String()**（M19 抓图抓出来的）──────────
 *
 * 第一版写的是裸比较：
 *
 *     visible: root.imageSource !== ""      // 恒为 true
 *     visible: root.imageSource === ""      // 恒为 false
 *
 * 两个都错，而且错得**完全看不见**：属性侧一切正常（`_iw`/`_ih` 算得出、
 * `implicitWidth` 对、空态文字位置也对），只有像素上能看出——
 * 内置插图**一个像素都没有**，整块空态只剩一行"暂无数据"。
 *
 * 根因是 `url` 型的 JS 表示。实测（`.cache/_probe_url.qml`）：
 *
 *     property url u: ""
 *     typeof u      -> "object"        ← url 交给 JS 是 QUrl 对象，不是字符串
 *     u === ""      -> false
 *     u ==  ""      -> true            ← 只有宽松比较才走一次隐式转换
 *     String(u)     -> ""              ← 显式转换才是可靠的判据
 *
 * 于是 `!==` 恒真、`===` 恒假，两条绑定一起失效：自定义图那格"可见"
 * 但 source 为空（画不出东西），内置图那格直接被藏掉。
 *
 * 规矩：**url 型属性与空串比较，一律先 String()。** QSkinAvatar 早先
 * 也是踩了同一个坑才改成 `String(effectiveSource) !== ""` 的
 * （见 QSkinAvatar 的 showImage）—— 这是本项目第二次撞上它，
 * 所以这次把 `hasCustomArt` 提成**公开**属性，让属性侧的门禁也能钉住它
 * （`smoke_m19.qml` 断言"没给 imageSource 时 hasCustomArt 为 false"；
 * 若有人把它改回裸比较，那条断言立刻变红）。
 *
 * ── 尺寸 ────────────────────────────────────────────────────────────────
 * 三档（sm / md / lg）只改**插图与留白的比例**，不改文字字号 ——
 * 空态的文字是"说明"，它在任何档位下都该读得清。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    /** 一句话标题（可选，比描述重一档）。留空则不占位。 */
    property string title: ""

    /** 说明文字。 */
    property string description: qsTr("暂无数据")

    /** 主操作区。放一个"新建"按钮之类，把用户带出去。
     *
     *      QSkinEmpty {
     *          description: "还没有项目"
     *          action: QSkinButton { text: "新建项目"; variant: "primary" }
     *      }
     *
     *  用 `data` 别名而不是 Component：这里装的是一份**内容**，
     *  和 QSkinCard 的 footer 是同一个道理。 */
    property alias action: actionHost.data

    /* ══════════════════════ 插图 ══════════════════════ */

    /** 自定义插图的 URL。空串 = 用内置的矢量插图。
     *  用 url 型而不是 string：QML 对 url 属性会在**书写它的那个文件**里
     *  解析相对路径，写成 string 再转手传下去会解析到中间控件的目录。 */
    property url imageSource: ""

    /** 内置插图的形态：
     *    default  两张错开的纸（有"还有东西没进来"的暗示）
     *    simple   一张纸（Ant 的 PRESENTED_IMAGE_SIMPLE 口径，更安静） */
    property string imageVariant: "default"

    /** 自定义插图的高度（宽度按原比例自适应）。只对 imageSource 有效。 */
    property int imageHeight: Math.round(100 * root._k)

    /* ══════════════════════ 尺寸 ══════════════════════ */

    /** sm | md | lg —— 只缩放插图与留白。 */
    property string size: "md"

    /** 说明文字的最大宽度。超过就换行 ——
     *  空态的文案常常是两句，不限宽会拉成一整行细长条。
     *
     *  ⚠ 它同时决定**整块空态的宽度**（`implicitWidth = max(插图宽, 它)`）。
     *  所以放进比自己更窄的容器时，调用方要把它调小 —— 控件不会自己缩，
     *  它会照隐式宽度撑开，而撑出去的代价是"整块看起来没居中"：
     *  插图是在本控件内部居中的，块本身偏了，插图就跟着偏。
     *  QSkinList 的空态就是这么做的（见 QSkinList 空态段的 `_emptyAvailW`）。 */
    property int textMaxWidth: 320

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property bool hasTitle: root.title !== ""
    readonly property bool hasAction: actionHost.data.length > 0
    readonly property bool hasText: root.hasTitle || root.description !== ""

    /** 是不是给了自定义插图。**必须过 String()** —— `imageSource` 是
     *  url 型，交给 JS 的是 QUrl 对象，`imageSource === ""` 恒为 false。
     *  理由与实测见文件头「判"有没有自定义插图"必须过 String()」。 */
    readonly property bool hasCustomArt: String(root.imageSource) !== ""

    /** 插图缩放系数。三档之间的比例是 0.75 / 1 / 1.35 ——
     *  不是等比数列（那样 lg 会比 md 大太多，空态会开始抢视线）。 */
    readonly property real _k: root.size === "sm" ? 0.75
                             : root.size === "lg" ? 1.35
                                                  : 1.0

    /** 插图的外框。内置插图按"两张错开 14px 的纸"算出包围盒：
     *  单张 72×88，错开量 14、12，于是总包围盒 86×100。 */
    readonly property int _iw: Math.round((root.imageVariant === "simple" ? 72 : 86) * root._k)
    readonly property int _ih: Math.round((root.imageVariant === "simple" ? 88 : 100) * root._k)

    /** 三段之间的距离。插图到文字要更宽 —— 它们不是同一件事。 */
    readonly property int _gapVisual: root.size === "sm" ? Theme.space.md : Theme.space.lg
    readonly property int _gapText:   root.size === "sm" ? Theme.space.xxs : Theme.space.xs

    implicitWidth:  Math.max(root._iw, root.hasText ? root.textMaxWidth : 0)
    implicitHeight: column.implicitHeight

    width:  implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.Grouping
    Accessible.name: root.hasTitle ? root.title : root.description

    /* ══════════════════════ 排布 ══════════════════════ */

    QSkinColumn {
        id: column

        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top

        gap: root._gapVisual
        padding: 0
        align: "center"

        /* ── 插图区 ── */
        Item {
            id: artHost

            Layout.alignment: Qt.AlignHCenter
            implicitWidth:  root._iw
            implicitHeight: root._ih

            Image {
                id: customArt

                anchors.centerIn: parent
                visible: root.hasCustomArt

                source: root.imageSource
                fillMode: Image.PreserveAspectFit

                /* 不给 sourceSize 时会按原图尺寸解码，一张 4000px 的
                 * 插图为了画 100px 也要占十几兆 —— 空态是最常被忽略的
                 * 一处性能坑，因为它在开发时常常是"最后才补上"的。 */
                width:  root._iw
                height: root.imageHeight
                sourceSize.width:  Math.max(1, Math.round(root._iw))
                sourceSize.height: Math.max(1, Math.round(root.imageHeight))
                asynchronous: true
            }

            /* ── 内置矢量插图：两张错开的纸 ──
             * 几何全部按 _k 取整，不靠 Item.scale ——
             * scale 会把 1px 的描边糊成 1.5px 的灰边，
             * 而且像素核验量出来的边界会飘。 */
            Item {
                id: art

                visible: !root.hasCustomArt
                anchors.fill: parent

                /* 后一张纸：只有底色，没有描边 ——
                 * 它的作用是"暗示还有一叠"，不该和前面那张抢注意力。 */
                Rectangle {
                    visible: root.imageVariant !== "simple"
                    x: 0
                    y: 0
                    width:  root._px(72)
                    height: root._px(88)
                    radius: root._px(6)
                    color:  Theme.color.bgSunken
                }

                /* 前一张纸 */
                Rectangle {
                    id: sheet

                    x: root.imageVariant === "simple" ? 0 : root._px(14)
                    y: root.imageVariant === "simple" ? 0 : root._px(12)

                    width:  root._px(72)
                    height: root._px(88)
                    radius: root._px(6)

                    color: Theme.color.bgElevated
                    border.width: 1
                    border.color: Theme.color.border

                    /* 三条内容线。长度递减 —— 等长会读成"表格"，
                     * 递减才读成"没写完的一页"。 */
                    readonly property real _lineX: root._px(14)
                    readonly property real _lineW: root._px(44)

                    Rectangle {
                        x: sheet._lineX
                        y: root._px(22)
                        width: sheet._lineW
                        height: root._px(5)
                        radius: root._px(2.5)
                        color: Theme.color.divider
                    }

                    Rectangle {
                        x: sheet._lineX
                        y: root._px(38)
                        width: sheet._lineW
                        height: root._px(5)
                        radius: root._px(2.5)
                        color: Theme.color.divider
                    }

                    Rectangle {
                        x: sheet._lineX
                        y: root._px(54)
                        width: root._px(26)
                        height: root._px(5)
                        radius: root._px(2.5)
                        color: Theme.color.divider
                    }
                }
            }
        }

        /* ── 标题 + 描述 ──
         * 包一层：两者之间只隔 _gapText（4px），而它们整体与插图之间
         * 隔 _gapVisual（16px）。**间距表达的是"这两样是不是一件事"**。
         * 直接用 Layout.topMargin 拉近是不行的 —— 负的 topMargin
         * 会被 QtQuick.Layouts 静默忽略（不是报错），看起来像"没生效"。 */
        QSkinColumn {
            id: textCol

            fill: true
            gap: root._gapText
            padding: 0
            align: "center"
            visible: root.hasText

            Text {
                id: titleText

                visible: root.hasTitle

                width: root.textMaxWidth
                text: root.title

                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                renderType: Text.NativeRendering

                font.family:    Theme.font.family
                font.pixelSize: Theme.font.md
                font.weight:    Theme.font.weightMedium
                color:          Theme.color.fg
            }

            Text {
                id: descText

                visible: root.description !== ""

                width: root.textMaxWidth
                text: root.description

                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                renderType: Text.NativeRendering

                font.family:    Theme.font.family
                font.pixelSize: Theme.font.sm
                color:          Theme.color.fgSecondary
            }
        }

        /* ── 操作区 ── */
        QSkinRow {
            id: actionHost

            visible: actionHost.data.length > 0
            gap: Theme.space.sm
            align: "center"
        }
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    /** 按缩放系数取整。写成函数而不是在每处写 Math.round(v * root._k)：
     *  取整规则只有一处，改的时候不会漏。 */
    function _px(v) {
        return Math.round(v * root._k)
    }
}
