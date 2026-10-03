/****************************************************************************
 * QSkin · 冒烟测试 — M18：布局与容器原子
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 守六个控件的**几何与派生**契约。渲染侧不在这个文件里 —— 它守不了。
 *
 * ── 这个文件刻意在做一件不太常见的事：测"账目"而不是"长相" ──────────────
 * Divider 最容易出的错不是"颜色不对"，是**账目对不上**：洞挖宽了 1px，
 * 于是两段线加起来比容器短 1px（右侧留一条缝）；或者挖窄了 1px，
 * 于是两段线重叠（线比容器长）。这两种错在屏幕上几乎看不出来
 * （1px 的缝和高 DPI 下的抗锯齿混在一起），但它是**真的错**。
 *
 * 所以这里的断言写成恒等式，而不是"长度大概是多少"：
 *     洞前段.len + textGap + 洞.w + textGap + 洞后段.len == 容器宽
 * 一侧改了就必然红，且红的时候能直接看出是哪一项多/少了。
 *
 * ── 断言上限 8 条（位掩码退出码的数学约束）─────────────────────────────
 * 详见 tools/test.sh 文件头：Qt.exit() 在 POSIX 下只保留低 8 位，
 * 第 9 条断言会造出"真失败被放大成满屏红"。到顶时的正解是按组件合并
 * 同类项（[7] 就是这么把 Layout 与 Splitter 并在一起的 —— 它俩都是
 * "分地"，只是一按角色分、一按用户的手分）。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int mask: 0
    property int idx: 0

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    /* ══════════════════ 被测控件 ══════════════════
     *
     * 每个用例都套一个**固定尺寸的宿主**：Divider / AspectRatio 这类
     * "撑满父容器"的控件，尺寸来自父容器；把它们直接放在根 Item 上，
     * 根 Item 的尺寸又来自窗口，链条太长，量出来的数不好归因。 */

    /* ── Divider：无文字、撑满 ── */
    Item {
        id: hostPlain
        width: 400; height: 40

        QSkinDivider { id: dPlain; anchors.verticalCenter: parent.verticalCenter }
    }

    /* ── Divider：带文字（显式给文字宽度，绕开 Loader 的一帧延迟）── */
    Item {
        id: hostText
        width: 400; height: 40

        QSkinDivider {
            id: dText
            anchors.verticalCenter: parent.verticalCenter
            text: "分区标题"
            textWidthOverride: 80
            textHeightOverride: 20
        }
    }

    /* ── Divider：文字长到放不下（会被压到上限）── */
    Item {
        id: hostHuge
        width: 400; height: 40

        QSkinDivider {
            id: dHuge
            anchors.verticalCenter: parent.verticalCenter
            text: "一段很长很长很长很长很长很长很长很长很长很长的分区标题"
            textWidthOverride: 1000      /* 故意远超容器宽 */
            textHeightOverride: 20
        }
    }

    /* ── Divider：虚线 ──
     *
     * 容器宽 **403** 是刻意选的：它不被 step(4+4=8) 整除，
     * 于是末段一定会短一截（3px 而不是 4px）。
     *
     * 起初这里写的是 400 —— 400/8 = 50 整除，末段正好是完整的 4px。
     * 当时那句"末段不越界"的检查因此**永远成立**：把实现里的
     * `Math.min(dashLength, 剩余)` 改成 `dashLength`（也就是让末段戳出去）
     * 它照样绿。这是本轮变异测试抓出来的第二条假绿通道 ——
     * 断言写得对，但**输入的数据让它无法为假**。 */
    Item {
        id: hostDash
        width: 403; height: 40

        QSkinDivider {
            id: dDash
            anchors.verticalCenter: parent.verticalCenter
            dashed: true
            dashLength: 4
            dashGap: 4
        }
    }

    /* ── Divider：靠左 / 靠右带文字 ──
     *
     * 这两个用例是为了守住"**靠边那一侧仍留一截线**"。
     * 成因见 QSkinDivider 文件头 ④：属性侧一直自洽（靠左时报 `[398]` 一段、
     * 断言全绿），而抓图上"第一节"贴着左缘、左端一截线都没有。
     * 改实现的依据是两家的真实代码：
     *   · Ant Design  `orientationMargin` 默认 0.05 → 左对齐留 5% 的线；
     *   · Arco Design `@divider-position-text-left: @spacing-9`(=36px)
     *     → 文字框左边必然留 36px 的线。
     * 也就是说"贴着边"在两家都是**退出默认**，不是默认。 */
    Item {
        id: hostAlign
        width: 400; height: 80

        QSkinDivider {
            id: dLeft
            y: 0
            text: "第一节"
            textAlign: "left"
            textWidthOverride: 80
            textHeightOverride: 20
        }

        QSkinDivider {
            id: dRight
            y: 40
            text: "第一节"
            textAlign: "right"
            textWidthOverride: 80
            textHeightOverride: 20
        }
    }

    /* ── AspectRatio ── */
    QSkinAspectRatio {
        id: arOk
        fill: false
        width: 320
        ratio: 16 / 9
    }

    QSkinAspectRatio {
        id: arBad
        fill: false
        width: 320
        ratio: 0            /* 非法值，不该炸成 Infinity / NaN */
    }

    /* ── ScrollArea ── */
    QSkinScrollArea {
        id: saTall
        width: 200; height: 100
        contentHeight: 500
    }

    QSkinScrollArea {
        id: saFit
        width: 200; height: 100
        /* contentHeight 留 -1：跟随视口，也就是"不需要滚" */
    }

    /* ── Card ── */
    QSkinCard {
        id: cardFull
        width: 300
        title: "完整卡片"

        Body { text: "内容" }
    }

    QSkinCard {
        id: cardTitleOnly
        width: 300
        title: "只有标题"
    }

    QSkinCard {
        id: cardFooterOnly
        width: 300

        footer: QSkinButton { text: "确定" }
    }

    /* ── Layout：侧栏折叠 ── */
    QSkinLayout {
        id: lay
        width: 600; height: 400
        siderWidth: 200
        siderCollapsedWidth: 48

        sider: Item { width: 10; height: 10 }
    }

    /* ── Splitter：比例夹取 ── */
    QSkinSplitter {
        id: sp
        width: 400; height: 200
        minSize: 80
        ratio: 0.01            /* 想挤到最左，但必须被 minSize 拦住 */
    }

    /* ══════════════════ 断言 ══════════════════ */

    function run() {
        /* ── [0] Divider 横向撑满父宽，且无文字时就是**一段**铺满 ──
         * "一段"这条不是废话：虚线分支若被误开、或洞逻辑在无文字时
         * 也切了一刀，这里会立刻变成 2 段。 */
        root.expect(Math.abs(dPlain.width - 400) < 0.01
                    && dPlain.segments.length === 1
                    && Math.abs(dPlain.segments[0].pos) < 0.01
                    && Math.abs(dPlain.segments[0].len - 400) < 0.01)

        /* ── [1] 带文字：**三种对齐**各自的"洞 + 两段"账目必须正好 ──
         *   minSegment = 16、textGap = 12（由 [2] 的 16 与这里的 12 共同锁住）
         *
         *   居中  hole.x = (400-80)/2 = 160
         *         左段 [0,148) 右段 [252,400)        两侧各 148
         *   靠左  hole.x = textGap + minSegment = 28
         *         左段 [0,16)  右段 [120,400)         左 16、右 280
         *   靠右  hole.x = 400 - 80 - 28 = 292
         *         左段 [0,280) 右段 [384,400)         左 280、右 16
         *
         *   三条恒等式都等于容器宽 400。**靠边那一侧不许是 0** ——
         *   它的职责就是"留一截线"（Ant / Arco 都如此，见 hostAlign 的注释）。
         *   这一条曾经是绿的：那时的实现让靠左的洞贴在 x=0，也如实报
         *   `[398]` —— 账目没错，是**规格**错了，只有看图才发现。 */
        var s1 = dText.segments
        var sL = dLeft.segments
        var sR = dRight.segments
        root.expect(s1.length === 2
                    && Math.abs(dText.hole.w - 80) < 0.01
                    && Math.abs(dText.hole.x - 160) < 0.01
                    && Math.abs(s1[0].pos - 0) < 0.01
                    && Math.abs(s1[0].len - 148) < 0.01
                    && Math.abs(s1[1].pos - 252) < 0.01
                    && Math.abs(s1[1].len - 148) < 0.01
                    && sL.length === 2
                    && Math.abs(dLeft.hole.x - 28) < 0.01
                    && Math.abs(sL[0].len - 16) < 0.01
                    && Math.abs(sL[1].pos - 120) < 0.01
                    && Math.abs(sL[1].len - 280) < 0.01
                    && sR.length === 2
                    && Math.abs(dRight.hole.x - 292) < 0.01
                    && Math.abs(sR[0].len - 280) < 0.01
                    && Math.abs(sR[1].pos - 384) < 0.01
                    && Math.abs(sR[1].len - 16) < 0.01)

        /* ── [2] 文字长到放不下：文字被压到上限，两侧线仍各留 minSegment ──
         *   上限 = 400 - 2*(minSegment(16) + textGap(12)) = 344
         *   两侧各 16 —— 这就是"宁可 elide 也不让线消失"。 */
        var s2 = dHuge.segments
        root.expect(Math.abs(dHuge.hole.w - 344) < 0.01
                    && s2.length === 2
                    && Math.abs(s2[0].len - 16) < 0.01
                    && Math.abs(s2[1].len - 16) < 0.01)

        /* ── [3] 虚线：段数对、每段不超过 dashLength、**末段不越界** ──
         *   403 / 8 → ceil = 51 段，末段 = min(4, 403-400) = 3。
         *   末段那条是这一组真正要守的东西（见 hostDash 的注释：
         *   容器宽换成整除的数，这条就永远绿）。 */
        var s3 = dDash.segments
        var within = s3.length === 51
        for (var i = 0; i < s3.length; ++i) {
            if (s3[i].len > 4.001) within = false
            if (s3[i].pos + s3[i].len > 403.001) within = false
        }
        root.expect(within
                    && Math.abs(s3[s3.length - 1].len - 3) < 0.01)

        /* ── [4] AspectRatio：高度 = 宽 / 比例；非法比例退化成 1:1 ──
         * 320 / (16/9) = 180 整。ratio = 0 时按 1 处理，不许出现
         * Infinity / NaN —— 那会让整个布局算出一串 NaN 坐标，
         * 而 QML 对 NaN 坐标**不报错**，只是那一堆东西不显示。 */
        root.expect(arOk.implicitHeight === 180
                    && isFinite(arBad.implicitHeight)
                    && arBad.implicitHeight === arBad.width)

        /* ── [5] ScrollArea：尺寸解析 + 滚动判定 ──
         * 这一条真正能证伪的是**尺寸解析**：contentHeight 没给（-1）时
         * 必须退化成"跟随视口"，给了就必须用宿主给的那个数。
         * 下面的 atEnd / atTop 是它的**执行证据**（scrollTo 必须真的落到
         * 夹取后的位置上）。
         *
         * ── 上一版这里写着"Flickable 自己的 contentY setter 就会夹取，
         *    所以'不夹'的实现也会通过"——**那句话是错的，已删** ──
         * M18 抓图给出了反例：直接写 `contentY = 1e6`，Flickable 原样收下
         * 100000（图的自证行印着 contentH=2038 / contentY=100000），
         * 视口停在一片没有内容的坐标上、图里整个左栏空白。
         * 夹取只发生在拖拽 / 惯性滑动那条路径上，不在 setter 里。
         * 所以下面这两条**不是**弱断言：它们量的是 `scrollTo` 自己的夹取，
         * 而那是本控件唯一的合法程序化滚动路径（见 QSkinScrollArea 文件头）。 */
        saTall.scrollTo(undefined, 9999)
        var atEnd = Math.abs(saTall.contentY - 400) < 0.5
        saTall.scrollTo(undefined, -5)
        var atTop = Math.abs(saTall.contentY - 0) < 0.5
        root.expect(saTall.scrollableVertically
                    && !saFit.scrollableVertically
                    && atEnd && atTop)

        /* ── [6] Card：三段派生 + 分割线只在"两段都在"时出现 ──
         * 分割线最容易写成"有头部就画"，那会在**没有内容的卡片**上
         * 留下一条悬空的线（卡片下缘多出一道横杠）。 */
        root.expect(cardFull.hasHeader && cardFull.hasBody && cardFull.hasFooter === false
                    && cardFull.showHeaderRule === true
                    && cardFull.showFooterRule === false
                    && cardTitleOnly.hasHeader === true
                    && cardTitleOnly.hasBody === false
                    && cardTitleOnly.showHeaderRule === false
                    && cardFooterOnly.hasFooter === true
                    && cardFooterOnly.showFooterRule === false)

        /* ── [7] 分地：Layout 按角色分、Splitter 按用户的手分 ──
         * Splitter：容器 400、minSize 80，ratio 想给 0.01（挤到最左），
         * 夹取后界线必须停在 80；给 1.0 则停在 400-80 = 320。
         * 这条防的是"某一栏被拖到 0 宽"—— 那一栏还在，但用户再也抓不到它。
         * Layout：侧栏折叠必须**同时**改变 currentSiderWidth，
         * 否则内容区不会跟着变宽（"折叠了但中间那栏没动"）。 */
        var lo = sp.splitPos
        sp.ratio = 1.0
        var hi = sp.splitPos
        var layBefore = lay.currentSiderWidth
        lay.siderCollapsed = true
        var layAfter = lay.currentSiderWidth

        root.expect(Math.abs(lo - 80) < 0.01
                    && Math.abs(hi - 320) < 0.01
                    && layBefore === 200
                    && layAfter === 48)

        Qt.exit(root.mask)
    }

    /* 推迟一轮：Qt Quick Layouts 把尺寸重算放在 polish 阶段，
     * 在 onCompleted 里同步读会读到重算之前的值（见 smoke_sizes.qml）。 */
    Component.onCompleted: function() { Qt.callLater(root.run) }
}
