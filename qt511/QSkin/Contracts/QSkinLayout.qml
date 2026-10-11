/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinLayout
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 页面骨架 —— 后台类界面那种"顶栏固定、内容撑满、侧栏可收起"的骨架。
 *
 * ── 它解决的不是"长什么样"，是"谁占多少地方" ────────────────────────────
 * 手写这套骨架要串起一条不短的 anchors 链：底部那栏要从下面锚、
 * 中间那栏要同时避开上面和下面、侧栏折叠时中间那栏的左边距要跟着变、
 * 折叠还得有动画。这条链每个页面抄一遍，就会抄出 N 个略有出入的版本
 * （最典型的是"侧栏折叠后中间区没跟着变宽"）。
 * 这里把它变成一次性的东西。
 *
 * ── 两种方向，对应 Ant 的两种用法 ──────────────────────────────────────
 *     orientation: "vertical"    顶栏 / 内容 / 底栏（三段）
 *     orientation: "horizontal"  侧栏 / 内容（两段）
 * 完整后台框架 = **嵌套**，而不是给这一个控件再堆更多角色：
 *
 *     QSkinLayout {                                  // 竖：上中下
 *         header: ...
 *         QSkinLayout { orientation: "horizontal"    // 横：左中
 *             sider: ...
 *             ... 页面内容 ...
 *         }
 *         footer: ...
 *     }
 * 好处是每种方向的排布只有一条规则，不必在"竖排里塞侧栏"这种组合上
 * 再发明一套（Ant 本身也是这么嵌套的）。
 *
 * ── 为什么各栏是"属性 + alias 内容"而不是"用户给一整个 Item" ────────────
 * 后者在 QML 里有个绕不开的坑：`header: Rectangle { ... }` 创建出来的对象
 * 视觉父项是本控件，位置要靠 Binding 一条条摆；而用户若自己写了
 * `height: 56`，那条 Binding 就会与他打架（要么报绑定冲突，要么静默让
 * 其中一方失效）。于是这里改成：**骨架自己画栏**，用户只往栏里放内容。
 * 栏的尺寸 / 底色由控件的属性控制（headerHeight / siderWidth / …），
 * 想要更自定义的外观时把底色设为 transparent，自己在内容里画。
 * 这与 QSkinDialog 的 `footer`、QSkinCard 的 `extra` 是同一种收法。
 *
 * ── 默认全透明，不猜视觉 ──────────────────────────────────────────────
 * 三栏底色默认 "transparent"，也不自动画分割线。Ant 的顶栏有深色底是它
 * 的 theme token 决定的，不是骨架的结构属性；QSkin 这边底色由主题令牌给，
 * 骨架只负责"把地方分好"。需要分区时设 headerColor，或往栏里放一条
 * QSkinDivider —— 两者都是显式的，不会替调用方做决定。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 方向 ══════════════════════ */

    /** vertical：顶栏 / 内容 / 底栏    horizontal：侧栏 / 内容 */
    property string orientation: "vertical"

    readonly property bool vertical: root.orientation !== "horizontal"

    /* ══════════════════════ 顶栏 ══════════════════════ */

    /** 顶栏内容。往里面放标题、面包屑、头像等。 */
    property alias header: headerHost.data

    /** 顶栏高度。-1 = 由内容撑出（走 headerHost 的隐式高度）。 */
    property int headerHeight: -1

    property color headerColor: "transparent"
    property int headerPadding: Theme.space.md
    property int headerSpacing: Theme.space.sm

    /* ══════════════════════ 底栏 ══════════════════════ */

    property alias footer: footerHost.data

    /** 底栏高度。-1 = 由内容撑出。 */
    property int footerHeight: -1

    property color footerColor: "transparent"
    property int footerPadding: Theme.space.md
    property int footerSpacing: Theme.space.sm

    /* ══════════════════════ 侧栏 ══════════════════════ */

    property alias sider: siderHost.data

    /** 侧栏宽度（展开时） */
    property int siderWidth: 240

    /** 侧栏折叠后的宽度。默认留出一列图标的宽度，而不是 0 ——
     *  折叠成 0 会让用户彻底失去"这里原本有个侧栏"的线索。 */
    property int siderCollapsedWidth: 56

    /** 是否可折叠。关掉时 siderCollapsed 无效。 */
    property bool siderCollapsible: true

    /** 是否处于折叠态 */
    property bool siderCollapsed: false

    /** 折叠时是否动画过渡 */
    property bool siderAnimated: true

    property color siderColor: "transparent"
    property int siderPadding: Theme.space.md
    property int siderSpacing: Theme.space.sm

    /** 侧栏当前实际宽度（只读，供业务做响应式判断） */
    readonly property int currentSiderWidth:
        (root.siderCollapsed && root.siderCollapsible) ? root.siderCollapsedWidth
                                                      : root.siderWidth

    /* ══════════════════════ 内容 ══════════════════════ */

    /** 主内容。请自己写 anchors.fill: parent —— 内容形态太多（表格、图表、
     *  自定义画布），统一替它设排布方式只会挡住正常的用法。 */
    default property alias contentData: contentHost.data

    /** 内容区的内边距（两侧方向共用） */
    property int contentPadding: 0

    /* ══════════════════════ 尺寸 ══════════════════════ */

    implicitWidth:  root.vertical
                    ? Math.max(headerHost.implicitWidth, contentHost.implicitWidth,
                               footerHost.implicitWidth, root.currentSiderWidth)
                    : root.currentSiderWidth + contentHost.implicitWidth

    implicitHeight: root.vertical
                    ? root._headerH + contentHost.implicitHeight + root._footerH
                    : Math.max(siderHost.implicitHeight, contentHost.implicitHeight)

    /* ══════════════════════ 派生 ══════════════════════ */

    /* 顶栏 / 底栏的高度 = **内容隐式高 + 两侧内边距**。
     *
     * 少加那个 `* 2` 会怎样：headerHost 是 `anchors.fill + margins: headerPadding`，
     * 于是它拿到的高度比 headerBg 少 2×padding。而 headerBg 的高度又只等于
     * implicitHeight —— 中间那 32px 无处可去，内容被上下各裁掉一半。
     * M18 抓图上"布局与容器"这几个字上半截不见了，就是这一处：
     * 高度断言（implicitHeight > 0）全绿，屏幕上文字缺一半。
     *
     * 这条属于「属性值对 ≠ 界面画对」的同一家族 —— 只不过这次的错不在
     * 颜色也不在几何计算，而在**两个都对的量之间少了一个换算**。 */
    readonly property int _headerH:
        !root.vertical ? 0
                       : (root.headerHeight >= 0
                          ? root.headerHeight
                          : headerHost.implicitHeight + root.headerPadding * 2)

    readonly property int _footerH:
        !root.vertical ? 0
                       : (root.footerHeight >= 0
                          ? root.footerHeight
                          : footerHost.implicitHeight + root.footerPadding * 2)

    readonly property int _siderW: root.currentSiderWidth

    /* ══════════════════════ 三栏 ══════════════════════
     *
     * 全部用**显式几何 + 绑定到 root 的尺寸**（不用 anchors 链）。
     * 原因：anchors 链在"某一段的可见性变化"时容易留下悬空的目标
     * （比如 content 锚在 sider 右边，而 sider 被折叠成 0 宽时
     * anchors 仍然成立但看起来像错位），显式几何让每一段的位置都能
     * 单独读懂，也便于像素核验逐段量。 */

    /* ── 顶栏 ── */
    Rectangle {
        id: headerBg

        visible: root.vertical && root._headerH > 0
        color: root.headerColor

        x: 0
        y: 0
        width:  root.width
        height: root._headerH

        QSkinRow {
            id: headerHost

            anchors.fill: parent
            anchors.margins: root.headerPadding
            gap: root.headerSpacing
            align: "center"
            fill: true
        }
    }

    /* ── 侧栏 ──
     * 纵向时它属于中间那一段（避开顶栏与底栏）；横向时它占满整个高度。 */
    Rectangle {
        id: siderBg

        /* data 而不是 children —— 见 QSkinCard 里同一段注释：
         * QSkinColumn 的 children 里有一个它自己的内部 ColumnLayout，
         * 用 children.length 判"有没有侧栏"会永远为真，
         * 于是没有侧栏的骨架也留出 240px 宽的空白。 */
        visible: siderHost.data.length > 0
        color: root.siderColor

        x: 0
        y: root.vertical ? root._headerH : 0
        width:  root._siderW
        height: root.vertical ? Math.max(0, root.height - root._headerH - root._footerH)
                              : root.height

        Behavior on width {
            enabled: root.siderAnimated && root.siderCollapsible
            NumberAnimation {
                duration: Theme.motion.normal
                easing.type: Theme.motion.easing
            }
        }

        QSkinColumn {
            id: siderHost

            anchors.fill: parent
            anchors.margins: root.siderPadding
            gap: root.siderSpacing
            fill: true
        }
    }

    /* ── 内容 ── */
    Item {
        id: contentHost

        x: root._siderW + root.contentPadding
        y: (root.vertical ? root._headerH : 0) + root.contentPadding
        width:  Math.max(0, root.width  - root._siderW - root.contentPadding * 2)
        height: Math.max(0, (root.vertical ? root.height - root._headerH - root._footerH
                                           : root.height)
                            - root.contentPadding * 2)
    }

    /* ── 底栏 ── */
    Rectangle {
        id: footerBg

        visible: root.vertical && root._footerH > 0
        color: root.footerColor

        x: 0
        y: root.height - root._footerH
        width:  root.width
        height: root._footerH

        QSkinRow {
            id: footerHost

            anchors.fill: parent
            anchors.margins: root.footerPadding
            gap: root.footerSpacing
            align: "center"
            fill: true
        }
    }

    Accessible.role: Accessible.Grouping
}
