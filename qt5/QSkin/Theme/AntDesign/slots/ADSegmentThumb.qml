/****************************************************************************
 * QSkin · Quick Design System — Theme / Ant Design / slots / ADSegmentThumb
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「segmentThumb」的 Ant Design 实现 —— 分段控制器里那块滑动的底。
 *
 * ── 它与 Basic 的差别只有一处：**不画描边** ──────────────────────────────
 *   Basic   `bgElevated` + 1px `border`
 *   Ant     `bgElevated`，无描边
 *
 * 这一处差别是**故意的**，不是"没改完"：参照实现里这块底是"白块 + 阴影"
 * （靠阴影从轨道上抬起），而不是靠一圈描边。而本项目的令牌表**没有 shadow
 * 组**（只有 color / space / radius / font / size / motion，四份 tokens.js
 * 都一样），所以"阴影"这半边表达不了。
 *
 * 于是这一格保留能保留的那一半：**无边框**。剩下"怎么让它抬起来"交给
 * 底色本身的对比 —— 浅色主题里 `bgElevated` 与轨道的 `bgSubtle` 本来就
 * 分得开（这正是那两块令牌的定义）。
 *
 * > 记一笔债：等真的出现**第二个**需要阴影的消费者（卡片 / 浮层 /
 * > 抬起的按钮都已经在门口等着了），该做的是给四家各加一组阴影令牌，
 * > 而不是在这里写死一个 DropShadow。届时这一格的注释要跟着改。
 *
 * ── 为什么这一格值得存在（而不是"Basic 已经够像了，不复用算了"）──────
 * 它存在的理由**不是**这一处描边差别，而是两条：
 *   ① 同主题内**两种取值要并存**：Ant 自己的开关打开态是品牌色实心轨道，
 *      而分段选中是中性抬起的白块 —— 一格 `toggleBackground` 装不下两种。
 *      完整论证见 contracts/slots/BasicSegmentThumb.qml 文件头。
 *   ② 它证明这一格**真的被装载了**。项目在 M19 栽过一次"主题的键名写错、
 *      插槽静默留在 Basic"，那次的判据是"装上去的必须**不等于** Basic"，
 *      而不是"非 null"（非 null 在没装的时候也成立 —— 它是 Basic）。
 *      本件与 Basic 的那一处差别，就是那条判据的抓手。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Rectangle {
    id: root

    property var control: null

    anchors.fill: parent

    /* 圆角比轨道（`radius.md`）**小一档**：嵌套元素的角要比外框紧，
     * 否则两圈圆角在视觉上会打架（Basic 同款处理）。 */
    radius: Theme.radius.sm

    color: Theme.color.bgElevated

    /* ── 无描边 —— 见文件头。
     *
     * ⚠ 这一行是**显式**写的，不是可省的多余话。实测
     * （`.cache/_probe_m23th.qml`，回传通道是退出码）：
     *
     *     BasicSegmentThumb（显式 1px + border 色）
     *         border.width = 1   border.color.a = 1   border.color = Theme.color.border
     *     ADSegmentThumb（**不写** border.*）
     *         border.width = 1   border.color.a = 1   border.color = 不透明黑
     *
     * 也就是说 `Rectangle` 的 `border.width` 默认读到 1、`border.color`
     * 读到**不透明黑** —— 而画面上一根线都没有（M22 已在
     * contracts/slots/BasicStatusGlyph.qml 的注释里量过像素，记过同一件事）。
     *
     * 后果是"这一格不画描边"这句契约在**属性侧完全读不出来**：
     * 两份实现的四个量里只有 `border.color` 的 rgb 可分（Basic 是
     * bg 相邻的描边色、这里是黑），而那是个**假**差别 —— 黑边根本没画。
     * 靠它写断言，等于让核验器去读一个渲染上不存在的量。
     *
     * 显式写 0 之后，"无描边"变成一条可被读出来、也可被改坏的性质：
     * `border.width === 0` 与"画面上没有那圈线"是同向的。 */
    border.width: 0

    opacity: (root.control && root.control.enabled === false) ? 0.5 : 1

    Behavior on opacity {
        NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
    }
}
