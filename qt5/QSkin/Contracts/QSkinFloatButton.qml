/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinFloatButton
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 悬浮按钮 —— 浮在内容之上的一枚圆球，点它做一件事。
 * 参照 Ant 的 `FloatButton`（Arco 那边同一件事叫 `BackTop`，
 * 见 COVERAGE.md 第一节 `FloatButton` 行）。
 *
 * ── 与 QSkinBackTop 的关系：共用底板，各画各的记号 ──────────────────────
 * 两件的球是**同一枚球**，于是底板抽成了 `FloatPlate`（契约层内部件）。
 * 这是 `QSkinBackTop.qml` 文件头在 M25 就预留的动作，判据是项目那条：
 *
 *     「只要出现第二个消费者，它现在能跑就不再是理由。」
 *
 * 但它**不是** BackTop 的泛化 —— 两件只共用"底板"这一层：
 *
 *   ┌──────────┬─────────────────────┬──────────────────────────────┐
 *   │          │ QSkinBackTop          │ QSkinFloatButton               │
 *   ├──────────┼─────────────────────┼──────────────────────────────┤
 *   │ 记号     │ 固定的 ↑（自绘折线）│ 宿主给的内容槽（Component）   │
 *   │ 出现时机 │ 滚过阈值（ScrollUtil）│ 完全由宿主决定（本件不管）   │
 *   │ 额外     │ 滚回顶部            │ 角标 + 提示                  │
 *   └──────────┴─────────────────────┴──────────────────────────────┘
 *
 * 把 BackTop 改写成"FloatButton + 一个 ↑ 图标"看着更省，但那样
 * BackTop 的公开面（`target` / `threshold` / `showing` / `scrollToTop()`）
 * 就得长出浮球之上，或者反过来让浮球认识 Flickable —— 两条都把
 * "该不该出现"这一格判定的归属搞糊了。**同层共用底板，比互相继承更便宜。**
 *
 * ── 记号槽为什么不给宽高 ──────────────────────────────────────────────
 * `BasicChevronIndicator` 的文件头明确要求宿主**不要**给宽高：
 * 线宽是 `width * 0.16` 算出来的，宿主一改尺寸，线宽就跟着失真。
 * 所以这里只给一个**建议尺寸** `iconSize`（默认是球径的 44%，与 BackTop
 * 的 arrowRatio 同一个比例），画多大由记号自己决定。
 *
 * ⚠ 拿 `Slots.chevronIndicator` 当记号会明显偏小 —— 它按 `iconSm/2` 定尺寸，
 * 不读 `iconSize`。这不是 bug，是两件对"记号尺寸归谁"的回答不同。
 *
 * ── 裁剪 ─────────────────────────────────────────────────────────────
 *   · **不做方位/吸附**（Ant 的 `placement`、`QSkinBackTop` 的位置由宿主锚定）：
 *     本件不碰自己的 x/y，宿主用什么容器摆它都行。
 *   · **不做文字档**（Ant 的 `description` 长文案）：`tip` 已经走悬浮提示，
 *     球面上再放一行字会与"圆球"这个形体打架。
 *   · **不做 primary / 方形档**：见 FloatPlate 的裁剪（同一条）。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    /** 球面上的记号。`null` = 一个光球（合法状态，用于纯角标提示）。
     *  与 `QSkinButton.icon` 同源：走 Component 而不是"打一个字符"，
     *  因为项目里没有任何图标资源，且"图标不用字符"是既有规矩。 */
    property Component icon: null

    /** 方向类记号的朝向：up | down | left | right。 */
    property string iconDirection: "down"

    /* ⚠ 这一条是**实测补出来的**（`.cache/probe_m27px/p1.qml`）。
     *
     * 记号槽被注入的 `control` 就是**本件**，而 `Slots.chevronIndicator`
     * 读的是 `control.direction` —— 本件原先只声明了 `iconDirection`，
     * 于是那个读法恒为 `undefined`、落到默认值 `"down"`：
     * 实测 `iconDirection: "up"` 与 `"right"` 得到的记号角**都是 90°**。
     * 也就是说 `iconDirection` 当时**没有任何消费者**，是个死属性。
     *
     * 两条修法（把 `direction` 暴露出来 / 给记号注入一个代理）里取前者：
     * 本件文件头那句注释写的就是"喂给 control.direction"，而
     * `BasicButtonContent` 那边的做法是**插槽自己翻译**（它读
     * `control.iconDirection`）—— 两条路都有人走过，但 chevron 是
     * 二十多个消费者共用的槽，改它要动所有人。这里只加一行别名，
     * 让"注入的 control 答得上 `direction`"这件事成立。
     * 门禁：`tests/smoke_m27.qml [6]` 断言记号的角跟着 `iconDirection` 走。 */
    readonly property string direction: root.iconDirection

    /** 给记号的**建议**尺寸。不强行施加 —— 见文件头。 */
    property int iconSize: Math.round(root.plateDiameter * 0.44)

    /** 悬浮提示文案。空串 = 不创建提示（连 Timer 都不会有）。 */
    property string tip: ""

    /** 角标数字。<= 0 = 不显示角标。 */
    property int badge: 0
    property int badgeMax: 99

    /* ══════════════════════ 外观 ══════════════════════ */

    property int diameter: 40

    /* ══════════════════════ 状态 ══════════════════════ */

    property bool hovered: false

    signal clicked()

    /* ══════════════════════ 几何 ══════════════════════ */

    /** 球的生效直径。**转发自底板** —— 与 BackTop 走同一条算路。 */
    readonly property int plateDiameter: plate.plateDiameter

    implicitWidth:  root.plateDiameter
    implicitHeight: root.plateDiameter

    width:  implicitWidth
    height: implicitHeight

    /* ══════════════════════ 无障碍 ══════════════════════ */

    Accessible.role: Accessible.Button
    /* 球面上的字是空的（记号是矢量），读屏需要一个名字。
     * 缺省文案只是兜底：宿主给了 tip 就用 tip。 */
    Accessible.name: root.tip !== "" ? root.tip : qsTr("悬浮按钮")
    Accessible.onPressAction: if (root.enabled) root.clicked()

    /* ══════════════════════ 圆球 ══════════════════════ */

    FloatPlate {
        id: plate

        anchors.fill: parent
        control: root
        diameter: root.diameter

        Loader {
            id: glyph

            anchors.centerIn: parent
            sourceComponent: root.icon

            /* 只在记号**声明了** control 时才注入。
             *
             * 与 QSkinButton 的插槽注入不同：那边插槽一定是本仓的
             * `Slots.buttonContent`（必定声明 control），而这里的记号是
             * 宿主随手给的任意 Component —— 无条件注入会报
             *     QML Binding: Property 'control' does not exist on
             *     QQuickRectangle
             * （实测于 .cache/probe_group/float.qml：探针给的就是一个
             *  光 Rectangle）。报错不致命，但会让每次运行都刷一行。 */
            Binding {
                target: glyph.item
                property: "control"
                value: root
                when: root._hasControl(glyph.item)
            }
        }

        MouseArea {
            id: ma

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            onContainsMouseChanged: root.hovered = containsMouse
            onCanceled: root.hovered = false
            /* enabled 的守卫写在这里而不是只靠 Item.enabled 的传播：
             * 后者在"父项 disabled"时的行为依赖 Qt 的事件投递细节，
             * 而这条守卫只看本件自己的状态，读代码就能确认。 */
            onClicked: if (root.enabled) root.clicked()
        }
    }

    /* ══════════════════════ 角标 ══════════════════════
     * 与 HelloM10 的用法一致：角标是**宿主的兄弟**（这里宿主是 root），
     * 而不是球本身的子项 —— 子项会被球的圆角与定位规则卷进去。 */
    QSkinBadge {
        id: badgeItem

        anchorTo: plate
        value: root.badge
        max: root.badgeMax
        visible: root.badge > 0
    }

    /* ══════════════════════ 提示 ══════════════════════
     * 走 Loader 而不是 `visible: tip !== ""`：tip 为空时**连 QSkinTooltip
     * 都不创建**（它内部挂了 Timer，空文案不该白养一条计时器）。
     * QSkinTooltip 读 `target.hovered`，本件有。 */
    readonly property bool tipOpened: root._openedOf(tipLoader.item)

    /* 过一层函数：Loader.item 的静态类型是 QObject，直接写
     * `tipLoader.item.opened` 会被 qmllint 报 Member "opened" not found
     * （实测：lint 第 243 个文件那条警告就是它）。参数没类型标注 = var。 */
    function _openedOf(o) {
        return !!o && o.opened === true
    }

    /* 记号有没有声明 control。过一层函数是为了避开 qmllint 的成员检查
     * （Loader.item 的静态类型是 QObject）。 */
    function _hasControl(o) {
        return !!o && o.control !== undefined
    }

    Loader {
        id: tipLoader

        active: root.tip !== ""
        sourceComponent: tipComp

        /* 与 QSkinButton 里的写法同款：插槽/子件在 Component 里引用外层 id
         * 会被 qmllint 判 Unqualified access，局部关掉。 */
        // qmllint disable unqualified
        Component {
            id: tipComp

            QSkinTooltip {
                text: root.tip
                target: root
            }
        }
        // qmllint enable unqualified
    }
}
