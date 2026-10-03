/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinBackTop
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 回到顶部 —— 内容滚过一段之后，右下角浮出一个圆球，点它滚回起点。
 * 参照 Arco 的 `BackTop`；Ant 把它做成了 `FloatButton.BackTop`（同一件事
 * 的两个名字，见 COVERAGE.md 第一节 `FloatButton` 行）。
 *
 * ── 滚动宿主是**输入**（COVERAGE.md 第七节「M25 五项裁决」之二）─────────
 * 与 QSkinAffix 同一条：`target` 指向一个 `Flickable`，本件不自己造滚动。
 * "该不该出现"只有一处判定 —— `ScrollUtil.backTopVisible(scrollY, threshold)`。
 * 那一格是**闭区间**（`>=`）：改成 `>` 之后"恰好滚到阈值"这一帧就从出现
 * 变成不出现，而两张截图都"看起来对"。变异测试会打在这一点上。
 *
 * ── 圆球为什么是自绘的（裁决四的一条**修正**）───────────────────────────
 * 落地前记的是"底板复用 `buttonBackground`，不为它自绘圆球"。写的时候
 * 实测发现装不下：`buttonBackground` 的插槽契约只读
 * `variant / pressed / hovered / disabled / checkable / checked`，
 * **不读 radius** —— 四家主题的按钮圆角各自由主题写死（都不是圆）。
 * 硬套的结果是 Ant 的 BackTop 变成一个圆角方块。
 *
 * 于是选另一条：**本件直绘**（`Theme.radius.full` + 令牌描边），
 * 与 `QSkinImage` 的放大镜、`QSkinAlert` 的 × 同档。四家的 BackTop 都是
 * **同一种圆球**，分歧只在颜色与直径 —— 令牌表达得了，够不上开插槽。
 *
 * 与 M27 的 `FloatButton` 的关系随之改写成：**那个件落地时才是第二个
 * 消费者**，届时该抽的也不是插槽，而是契约层内部的一个 glyph / plate 组件
 * （`QSkinImage` 文件头记过这条判据）。M27 之前不预先抽。
 *
 * ── M27 落地：上面那句兑现了 ──────────────────────────────────────────
 * 底板抽成了 `FloatPlate.qml`（契约层内部件，与 TimeCell 同档注册），
 * 本件与 `QSkinFloatButton` 各持一个实例。**记号没抽** —— ↑ 仍在本件自绘，
 * 因为两件画的不是同一个东西（本件固定 ↑，FloatButton 是内容槽）；判据是
 * "结构不同就不共用"，与 Slots 里 spinRing / spinDots 分成两格同源。
 *
 * 球径现在只有一份算路：`plate.plateDiameter`，本件转发成 `plateDiameter`。
 * 重构后**像素必须逐字不变** —— 底色、描边、hover 映射、半径算法
 * （`min(w,h)/2`）都原样搬进了 FloatPlate，本文件这一侧只剩"什么时候出现"。
 *
 * ── 箭头为什么用 Shape ────────────────────────────────────────────────
 * 放大镜是"描边圆 + 旋转柄"，Rectangle 就能像素级准确地画出来；
 * 而 ↑ 是**一个折线**（两翼 + 竖杆共点），拿两个旋转矩形拼会在交汇处
 * 留下接缝。一笔折线的 `ShapePath` 更短也更准，代价是按门禁挂上
 * `preferredRendererType: Shape.CurveRenderer`（`tools/lint.sh` 会查）。
 *
 * ── 动画与确定性 ─────────────────────────────────────────────────────
 * `animated` 缺省 true（真实使用当然要滚得好看），但它**只作用于"怎么过去"**：
 * 目标位置是 `ScrollUtil.clampScrollY(0, …)`（恒为 0），出现在哪一帧由
 * `backTopVisible` 这个纯函数决定。把它们分开，测试就不必"等动画收尾" ——
 * 与 QSkinCollapseItem 把 `contentHeight`（自然值）与绘制 `height` 分开同一种处置。
 ****************************************************************************/

import QtQuick 2.15
/* **不带版本号** —— 带了的话 `preferredRendererType` 整个不可用
 * （被 tools/lint.sh 的 Shape 抗锯齿门禁抓到，与 QSkinImage 的写法对齐）。 */
import QtQuick.Shapes 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 输入 ══════════════════════ */

    /** 滚动宿主，一个 Flickable。null = 永不出现（点也不动） */
    property var target: null

    /** 滚过多少像素才出现。四家默认都是 400 */
    property int threshold: 400

    /** 回顶时的过渡。关掉它就是瞬移 —— 抓图与像素核验走这条路 */
    property bool animated: true
    property int duration: Theme.motion.normal

    /* ══════════════════════ 外观 ══════════════════════ */

    property int diameter: 40

    /** 箭头相对圆球的尺寸。0.44 是我在 40px 球上量出来的观感值 ——
     *  它不是令牌能表达的东西（令牌管色与间距，不管一枚记号与它容器的比例）。 */
    property real arrowRatio: 0.44

    /* ══════════════════════ 状态 ══════════════════════ */

    /** 显式读一次 contentY —— 它是本件所有派生的依赖来源 */
    readonly property real _scrollY: root.target ? root.target.contentY : 0

    /** 该不该出现。**唯一**的判定点 */
    readonly property bool showing:
        root.target !== null && ScrollUtil.backTopVisible(root._scrollY, root.threshold)

    property bool hovered: false

    /* ══════════════════════ 接口 ══════════════════════ */

    signal clicked()

    /** 滚回顶部。`animated` 为假时是瞬时赋值（抓图走这条） */
    function scrollToTop() {
        if (!root.target) return
        /* 目标恒为 0 —— 但**不写死**：它走 ScrollUtil 的夹取口径，
         * 于是"回到顶"与 Affix / Anchor 的夹取是同一条算路。 */
        var to = ScrollUtil.clampScrollY(0, root.target.contentHeight,
                                         root.target.height)
        if (!root.animated) {
            root.target.contentY = to
            return
        }
        backAnim.to = to
        backAnim.restart()
    }

    /* ══════════════════════ 几何 ══════════════════════ */

    /** 球的生效直径。**转发自底板** —— 与 QSkinFloatButton 同一条算路
     *  （`FloatPlate.plateDiameter`），冒烟测试钉的就是"两件同值"。 */
    readonly property int plateDiameter: ball.plateDiameter

    implicitWidth:  root.plateDiameter
    implicitHeight: root.plateDiameter

    opacity: root.showing ? 1 : 0
    /* 圆球在内容之外，所以不参与布局上的挤占；但完全透明时不该收事件 */
    visible: root.opacity > 0

    Behavior on opacity {
        enabled: root.animated
        NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
    }

    NumberAnimation {
        id: backAnim
        target: root.target
        property: "contentY"
        duration: root.duration
        easing.type: Theme.motion.easing
    }

    /* ══════════════════════ 圆球 ══════════════════════ */

    FloatPlate {
        id: ball

        anchors.fill: parent
        control: root
        diameter: root.diameter

        /* ── ↑ ──
         * 一笔折线：左翼 → 顶点 → 右翼 → 回顶点 → 竖杆。
         * 顶点与两翼共点，RoundCap / RoundJoin 把交汇处收干净。 */
        Shape {
            id: arrow

            anchors.centerIn: parent
            width:  Math.round(ball.width * root.arrowRatio)
            height: width


            readonly property real sx: width
            readonly property real sy: height

            ShapePath {
                strokeColor: root.hovered ? Theme.color.brand : Theme.color.fgSecondary
                strokeWidth: Math.max(1, Math.round(arrow.sx * 0.11))
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                startX: arrow.sx * 0.22
                startY: arrow.sy * 0.55

                PathLine { x: arrow.sx * 0.50; y: arrow.sy * 0.26 }   /* 顶点 */
                PathLine { x: arrow.sx * 0.78; y: arrow.sy * 0.55 }   /* 右翼 */
                PathLine { x: arrow.sx * 0.50; y: arrow.sy * 0.26 }   /* 回顶点 */
                PathLine { x: arrow.sx * 0.50; y: arrow.sy * 0.86 }   /* 竖杆到底 */
            }
        }

        /* 输入走 MouseArea 而不是 TapHandler / HoverHandler：
         * 本仓的主流写法是 MouseArea（`tests/tst_*.qml` 的真鼠标事件也走它），
         * 而 handler 那几处（QSkinList / QSkinPopover / QSkinHoverCard）各有
         * 手势竞争上的具体理由。这里没有，就不引入第二种写法。 */
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onContainsMouseChanged: root.hovered = containsMouse
            onClicked: {
                root.clicked()
                root.scrollToTop()
            }
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: qsTr("回到顶部")
    Accessible.onPressAction: {
        root.clicked()
        root.scrollToTop()
    }
}
