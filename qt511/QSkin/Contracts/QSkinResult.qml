/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinResult
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 结果页（M22）。操作走完之后的"整页交代" —— 提交成功、订单失败、
 * 页面不存在。它与 QSkinAlert 的分工很清楚：
 *
 *     QSkinAlert    一句话，塞在流程里，宽高跟内容走
 *     QSkinResult   一整个区域/一屏，居中、有主标题、有后续动作出口
 *
 * ── 覆盖到哪一步 ────────────────────────────────────────────────────────
 * 已实现：status（7 个取值）/ title / subtitle / extra（操作区）/
 *         glyphSize（记号边长）
 *
 * ── 关于 404 / 403 / 500：这里**不画插图**，画状态码 ────────────────────
 * Ant 与 Arco 的这三个状态用的是一张**插画**（Ant 甚至是独立的一套
 * SVG 素材）。本项目全程不引入图片素材（没有 svg/png 资源目录，
 * 见 QSkinButton 文件头对 `iconSource` 那条 url 通路的记录），
 * 也没有能力把 Ant 那套插画凭审美重新画对。
 *
 * 所以这三个状态走另一条路：**把状态码本身画成大号数字**。
 * 这不是偷懒 —— 它是真实产品里常见且完全成立的处理，而且有一个
 * 附带好处：数字是文字，不参与"像不像"的审美判断，
 * 像素核验可以像量任何文字一样量它。
 *
 * 这是一处**明确的、有理由的偏差**，不是"忘了画插图"。
 *
 * ── 其余四个语义状态走 statusGlyph 插槽 ────────────────────────────────
 * success / info / warning / error 都用 M22 新增的语义记号，
 * 尺寸由 glyphSize 给（默认 64，跨 16~64 那个数量级的上端）。
 * 换主题时这枚记号跟着换（shadcn 那边是描边圆环，warning 是三角）。
 *
 * ── 为什么宽度不给死 ────────────────────────────────────────────────────
 * 结果页多数时候吃掉整栏宽度，所以这里只声明 implicitWidth（窄容器里的
 * 下限），实际宽度交给调用方 —— 与 QSkinAlert 同一条取舍。
 *
 * 用法：
 *     QSkinResult {
 *         status: "success"
 *         title: "提交成功"
 *         subtitle: "审核结果会在 1 个工作日内发送到你的邮箱。"
 *         extra: [ QSkinButton { text: "返回列表"; variant: "primary" } ]
 *     }
 ****************************************************************************/

import QtQuick 2.11
/* Layout.* 附加属性来自这里（见 QSkinAlert.qml 同处的说明）。 */
import QtQuick.Layouts 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** success | info | warning | error | 404 | 403 | 500
     *  （`error` 与 `danger` 等价；不认识的值按 info） */
    property string status: "info"

    /** 主标题 */
    property string title: ""

    /** 补充说明（可选） */
    property string subtitle: ""

    /** 语义记号边长（px）。默认 64 —— 结果页里这枚记号是视觉主体，
     *  比 QSkinAlert 的 20 大三倍多。做成属性而不是写死在内部，
     *  是因为"结果页要多大一枚记号"是版式决定，调用方该能改。 */
    property int glyphSize: 64

    /** 操作区（Ant / Arco 的 `extra`）。没塞东西就整块不占位。 */
    property alias extra: extraHost.data

    /* ══════════════════════ 状态解析 ══════════════════════ */

    /** 三个"错误码"状态：画数字，不画记号 */
    readonly property bool _isCode: root.status === "404"
                                    || root.status === "403"
                                    || root.status === "500"

    /** 交给 statusGlyph 的语义值（只在前四个状态里用得上）。
     *  `error` / `danger` 都归 danger —— Arco 用前者、Ant 用后者，
     *  这里两个都收，免得调用方要记住是哪一家的口径。 */
    readonly property string _glyphStatus: root.status === "success" ? "success"
                                         : root.status === "warning" ? "warning"
                                         : (root.status === "error" || root.status === "danger")
                                                                     ? "danger"
                                                                     : "info"

    /** 主色。三个错误码按语义分开：403 / 404 是"你走错了路"（警告色），
     *  500 是"我们坏了"（危险色）。 */
    readonly property color toneColor: root.status === "500"     ? Theme.color.danger
                                     : root.status === "404"
                                       || root.status === "403"  ? Theme.color.warning
                                     : root._glyphStatus === "success" ? Theme.color.success
                                     : root._glyphStatus === "warning" ? Theme.color.warning
                                     : root._glyphStatus === "danger"  ? Theme.color.danger
                                                                       : Theme.color.info

    readonly property bool hasTitle:    root.title !== ""
    readonly property bool hasSubtitle: root.subtitle !== ""

    implicitWidth:  420
    implicitHeight: layout.implicitHeight

    /* ══════════════════════ 布局 ══════════════════════
     * 整体居中：QSkinColumn 的 `align: "center"` 会把每个子项的
     * Layout.alignment 设成 AlignHCenter（见 QSkinColumn.qml 的 _alignmentEnum）。
     * 文字那两项另外声明了 Layout.fillWidth —— 撑满后 align 不再起作用，
     * 所以它们的居中靠自身的 horizontalAlignment（走 label 插槽的
     * labelAlignment 与 Body 的 horizontalAlignment）。
     *
     * 这条"fill 压过 align"的先后顺序是 Qt 的既有行为，不是这里定的；
     * 写出来是因为它是本文件排版成立的前提，改动前得先知道。 */
    QSkinColumn {
        id: layout

        anchors.left:  parent.left
        anchors.right: parent.right

        /* 垂直位置用普通表达式而**不是** anchors.verticalCenter：
         * root.height 默认来自 layout.implicitHeight，写成居中锚点就成环。
         * 这条表达式两段都成立 —— 高度就是内容高时 y=0（贴顶），
         * 调用方给了更高的盒子时内容居中。 */
        y: Math.max(0, Math.round((root.height - layout.implicitHeight) / 2))

        padding: Theme.space.xxl
        gap:     Theme.space.md
        align:   "center"

        /* ── 语义记号（四个语义状态）── */
        Loader {
            id: glyphLoader

            visible: !root._isCode
            sourceComponent: Slots.statusGlyph

            Binding {
                target: glyphLoader.item
                property: "control"
                value: glyphCtl
                when: glyphLoader.status === Loader.Ready
            }
        }

        QtObject {
            id: glyphCtl

            readonly property string status: root._glyphStatus
            readonly property int size: root.glyphSize
        }

        /* ── 状态码（404 / 403 / 500）──
         * 高度锁成 glyphSize，与上面那枚记号**占同一个视觉盒子** ——
         * 于是换 status 时整页高度不会跳一下。
         * 字号取盒子的 75%：数字的视觉高度比同号字号的方块小，
         * 75% 才让两种状态看起来一样大。
         *
         * ── 为什么是 Layout.preferredHeight 而不是 height（M22.2 修）──────
         * 这里原来写的是 `height: root.glyphSize`，**它是个空操作**：
         * 本 Text 是 QSkinColumn（ColumnLayout）的子项，而 Layout 会用
         * `implicitHeight` 覆盖子项显式声明的 `height` —— 于是那个 Text
         * 实际是 48 高（= 它自己的字号），不是 64。
         *
         * 后果不是"看起来小一点"，而是**上面那句承诺没兑现**。实测
         * （`.cache/_probe_m22res.qml`，干净控制实验）：
         *
         *     QSkinResult  status=404     implicitHeight = 138
         *     QSkinResult  status=success implicitHeight = 154   ← 差 16
         *     裸 ColumnLayout 里 Text { height: 64 }  →  实测 48
         *     同上改用 Layout.preferredHeight: 64     →  实测 64
         *
         * 所以 404 ↔ success 切换时整页会跳 16px，而属性侧一片自洽
         * （`glyphSize` 读到 64、`font.pixelSize` 读到 48，都对）。
         *
         * 这是"**Layout 忽略子项显式尺寸**"这一族缺陷在本仓库的**第三处**
         * （前两处：QSkinDialog 的 footer ButtonBar、`.cache/shot_m22.qml`
         * 的结果列 —— 那一处还让结果页超出窗口右沿 20px）。三处的根因
         * 同一个：Layout 的子项只能通过 `Layout.*` 附加属性表达尺寸。
         * 遇到"我明明给了宽高却不起作用"时，先查这一条。 */
        Text {
            id: codeText

            visible: root._isCode
            text:    root.status

            Layout.preferredHeight: root.glyphSize
            font.family:    Theme.font.family
            font.pixelSize: Math.round(root.glyphSize * 0.75)
            font.weight:    Theme.font.weightSemiBold
            color: root.toneColor

            verticalAlignment:   Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            renderType:          Text.NativeRendering
        }

        /* ── 主标题（label 插槽 header 变体，与 QSkinDialog / QSkinAlert 同格）── */
        Loader {
            id: titleLabel

            visible: root.hasTitle
            sourceComponent: Slots.label
            Layout.fillWidth: true

            Binding {
                target: titleLabel.item
                property: "control"
                value: titleCtl
                when: titleLabel.status === Loader.Ready
            }
        }

        QtObject {
            id: titleCtl

            readonly property string text: root.title
            readonly property string variant: "header"
            readonly property int labelAlignment: Text.AlignHCenter
        }

        /* ── 补充说明 ── */
        Body {
            Layout.fillWidth: true

            visible: root.hasSubtitle
            text:    root.subtitle
            tone:    "secondary"

            horizontalAlignment: Text.AlignHCenter
        }

        /* ── 操作区 ──
         * 与 QSkinAlert 的 action 同一条判据：visible 绑到 implicitWidth，
         * 空的 QSkinRow 宽度恰好是 0，于是"没塞东西"与"不占位"天然一致。 */
        QSkinRow {
            id: extraHost

            visible: extraHost.implicitWidth > 0
            gap: Theme.space.sm
        }
    }
}
