/****************************************************************************
 * QSkin · Quick Design System — Foundation / ScrollUtil
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 滚动位置的**纯计算**：把 `contentY` 换算成「当前是哪一段 / 该不该贴住 /
 * 该不该出现 / 该滚到哪」。它不持有 Flickable，也不画一笔 ——
 * 谁长什么样、记号多宽、淡入多久，都是契约层与主题层的事。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么它必须存在 —— 这一批第一次遇到「滚动位置就是状态」
 * ════════════════════════════════════════════════════════════════════════
 *
 * M25 有三个件的状态**完全由滚动位置决定**：
 *
 *     QSkinAnchor   跟着滚 → 哪一段高亮
 *     QSkinAffix    跟着滚 → 钉住了没有、钉在哪
 *     QSkinBackTop  跟着滚 → 出现了没有
 *
 * 这与本项目抓图纪律的头一条**正面冲突**：抓图要确定性。
 * 于是落地前定了两条（写在 COVERAGE.md 第七节的「M25 五项裁决」里）：
 *
 *   1. 三个件都**不自己造滚动**，统一吃一个 `target: Flickable`。
 *      这个契约是现成的 —— `QSkinScrollArea` 已经用
 *      `property alias flickable` / `property alias contentY` 交出来了。
 *      抓图脚本直接写 `target.contentY = N`（瞬时赋值，不经动画）。
 *
 *   2. 判定一律**只在这里**。理由是本项目 M20 那条：
 *      **handler 与属性绑定必须走同一条算路** —— 否则「点到哪」与
 *      「高亮哪」是两条算路，属性门禁与像素门禁会各测一份，
 *      两者打架时谁也说不清是哪一份错了。
 *
 * 这两条合起来的效果：属性侧与像素侧读的是**同一个函数、同一个输入**，
 * 而那个输入是可以被脚本钉死的。
 *
 * ═══════════════════════ 与动画的关系（M23 那条教训） ═══════════════════
 *
 * 滚到某一段可以带过渡（QSkinBackTop 的 `animated`）。但**"目标位置"是一个
 * 算出来的量**，动画只作用在「怎么过去」上 —— 与 QSkinCollapseItem 把
 * `contentHeight`（自然值）与绘制用的 `height`（过渡中的值）分开是同一种处置。
 *
 * 于是测试读 `scrollYForIndex(...)`，不读过渡中的 `contentY`。
 * 否则每条断言前面都要加一句"等动画收尾"，而那正是本项目最怕的
 * 「测量与实现共享时序假设」。
 *
 * ═══════════════════════ 一个会把判据坑掉的事实 ═══════════════════════
 *
 * `scrollYForIndex()` 的返回值是**夹取过的**。而最后一段常常够不到锚点线 ——
 * 内容不够长时 `clampScrollY` 会把它截在 `contentHeight - viewportHeight`。
 * 所以像素判据挑样本时**必须挑一个不会被夹取的段**，不然量出来的是
 * 「差了一段距离」，会看起来像实现错了。
 * （这条不是在防呆：M25 第一次写判据时就差一点挑到最后一段。）
 ****************************************************************************/

pragma Singleton
import QtQuick 2.15

QtObject {
    id: root

    /**
     * sectionIndexAt(offsets, scrollY, anchorOffset) → int
     *
     *   offsets       各段起点，**内容坐标**，升序
     *   scrollY       当前 contentY
     *   anchorOffset  锚点线距**视口顶**的距离（Ant 的 targetOffset）
     *
     * 返回锚点线落在哪一段里：最后一个满足 `offsets[i] <= scrollY + anchorOffset`
     * 的下标。
     *
     * 两条边界语义是**刻意的**，也是判据会打的地方：
     *   · 锚点线在第一段之前 → 返回**第一段**（不是 -1）。Ant 的行为是
     *     页面刚打开时第一项就已经是高亮的。
     *   · `offsets` 里非有限数的项被跳过，但返回值仍是**原数组下标**
     *     （调用方要靠它去索引自己的条目）。一个有效的都没有 → -1。
     */
    function sectionIndexAt(offsets, scrollY, anchorOffset) {
        if (!offsets) return -1

        var line = Number(scrollY) + Number(anchorOffset)
        var first = -1
        var last = -1

        for (var i = 0; i < offsets.length; ++i) {
            var v = offsets[i]
            if (typeof v !== "number" || !isFinite(v)) continue
            if (first < 0) first = i
            if (v <= line) last = i
        }

        if (last >= 0) return last
        return first
    }

    /**
     * affixOffsetY(itemY, holderHeight, itemHeight, scrollY, stickyTop) → real
     *
     *   itemY         占位块在**内容坐标**里的顶边
     *   holderHeight  占位块的高度
     *   itemHeight    被钉住的**内容本身**的高度
     *   scrollY       当前 contentY
     *   stickyTop     钉住后距视口顶的距离
     *
     * 返回：被钉内容应当画在**视口坐标**里的 y。
     *
     *     natural   = itemY - scrollY                还没到线 → 原位
     *     pushedTop = itemY + holderHeight - itemHeight - scrollY
     *                 占位块的底边再往上减一个自身高度
     *     → min(stickyTop, pushedTop)
     *
     * 「还没到线」与「被顶出去」是两件事，所以先判前者：
     * `natural >= stickyTop` 时原样返回 —— 否则一个比占位块还高的内容
     * （holderHeight < itemHeight）会在第一帧就跳到 `pushedTop`。
     */
    function affixOffsetY(itemY, holderHeight, itemHeight, scrollY, stickyTop) {
        var natural = Number(itemY) - Number(scrollY)
        if (natural >= Number(stickyTop)) return natural

        var pushedTop = Number(itemY) + Number(holderHeight)
                        - Number(itemHeight) - Number(scrollY)
        return Math.min(Number(stickyTop), pushedTop)
    }

    /**
     * affixDeltaY(itemY, holderHeight, itemHeight, scrollY, stickyTop) → real
     *
     * `affixOffsetY(...)` **减去自然位置**。控件真正要的是这个数：
     * 被钉内容住在 root 里，所以 `y: affixDeltaY(...)` 就够了 ——
     * 而 `affixOffsetY` 是**视口坐标**，直接拿来做 y 会多算一次原位。
     *
     * 它与 `affixOffsetY` 的关系是一条断言（不是注释）：
     *     affixDeltaY(...) === affixOffsetY(...) - (itemY - scrollY)
     * `tests/smoke_m25.qml` 会在若干组输入上逐条核对它 ——
     * 两个都从同一个定义出发，就没有"两条算路"。
     *
     * 符号：> 0 = 往下让（贴住了），= 0 = 在原位，< 0 = 被顶出去。
     */
    function affixDeltaY(itemY, holderHeight, itemHeight, scrollY, stickyTop) {
        var natural = Number(itemY) - Number(scrollY)
        return root.affixOffsetY(itemY, holderHeight, itemHeight, scrollY, stickyTop)
               - natural
    }

    /**
     * backTopVisible(scrollY, threshold) → bool
     *
     * **闭区间**（`>=`）。这一格是判据会打的地方：改成 `>` 之后
     * 「恰好滚到阈值」这一帧就从出现变成不出现，而两张图都"看起来对"。
     */
    function backTopVisible(scrollY, threshold) {
        return Number(scrollY) >= Number(threshold)
    }

    /**
     * maxScrollY(contentHeight, viewportHeight) → real
     * 合法的 contentY 上界（下界恒为 0）。内容比视口短时为 0。
     */
    function maxScrollY(contentHeight, viewportHeight) {
        return Math.max(0, Number(contentHeight) - Number(viewportHeight))
    }

    /**
     * clampScrollY(y, contentHeight, viewportHeight) → real
     * 把任意 y 夹进 `[0, maxScrollY]`。
     */
    function clampScrollY(y, contentHeight, viewportHeight) {
        var hi = root.maxScrollY(contentHeight, viewportHeight)
        return Math.max(0, Math.min(hi, Number(y)))
    }

    /**
     * scrollYForIndex(offsets, index, anchorOffset, contentHeight, viewportHeight)
     *     → real | -1
     *
     * 点第 `index` 段时应当滚到哪 —— **已经是目标值**，不用再夹一次。
     * 单看这个函数读不出夹取发生过；要判断某一段够不够得到锚点线，
     * 比 `offsets[index] - anchorOffset` 与返回值是否相等。
     * （文件头「一个会把判据坑掉的事实」讲的就是这件事。）
     *
     * 下标非法 / 该段位置不是有限数 → 返回 -1（调用方据此跳过滚动，
     * 不要静默滚到 0）。
     */
    function scrollYForIndex(offsets, index, anchorOffset, contentHeight, viewportHeight) {
        if (!offsets) return -1
        if (!(index >= 0) || index >= offsets.length) return -1

        var v = offsets[index]
        if (typeof v !== "number" || !isFinite(v)) return -1

        return root.clampScrollY(v - Number(anchorOffset),
                                 contentHeight, viewportHeight)
    }
}
