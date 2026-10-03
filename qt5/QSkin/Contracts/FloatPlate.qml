/****************************************************************************
 * QSkin · Quick Design System — Contracts / FloatPlate
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「浮球」的底板 —— 右下角浮起来的那一枚圆形浅底球。
 *
 * ── 它是怎么长出来的 ──────────────────────────────────────────────────
 * `QSkinBackTop.qml` 的文件头在 M25 就写下了这件事：
 *
 *   > 与 M27 的 `FloatButton` 的关系随之改写成：**那个件落地时才是第二个
 *   > 消费者**，届时该抽的也不是插槽，而是契约层内部的一个 glyph / plate
 *   > 组件（`QSkinImage` 文件头记过这条判据）。M27 之前不预先抽。
 *
 * 现在第二个消费者到了（`QSkinFloatButton`），所以抽。判据不是"看着像就抽"，
 * 是项目那条已经用在 `MemberOrder` / `ScrollUtil` / `CornerUtil` 上的：
 *
 *     「只要出现第二个消费者，它现在能跑就不再是理由。」
 *
 * ── 它负责什么 / 不负责什么 ────────────────────────────────────────────
 *   负责：圆的**直径与半径**（唯一算路）、底色、描边、hover 与禁用的映射
 *   不负责：里面那枚记号（↑ 或任意图标 —— 归各自的控件）、鼠标事件、
 *           出现/消失的时机（BackTop 的阈值、FloatButton 的显隐由宿主决定）
 *
 * 记号不进来，是因为两件画的**根本不是同一个东西**：BackTop 画 ↑，
 * FloatButton 画宿主给的内容槽。硬塞进这一格，等于把一个"图标容器"
 * 伪装成"球"。这与 Slots.qml 里 spinRing / spinDots 分成两格是同一条判据
 * （**结构不同就不共用**），只是这条发生在契约层内部而不是插槽层。
 *
 * ── 为什么不进插槽层（Slots）─────────────────────────────────────────
 * 球是"同一种圆球，分歧只在颜色与直径"（M25 裁决四量过），令牌表达得了。
 * 参照实现里四家的 BackTop 全是同一枚圆球 —— 没有一家把它做成方形或其他
 * 形状。够不上开插槽的门槛，开了就是给每个主题发一份可以漂移的重复实现。
 *
 * ── 裁剪 ─────────────────────────────────────────────────────────────
 *   · **不做 primary / 实心档**：那要同时把"记号颜色"翻成反色，于是
 *     "记号颜色"也得纳入本件的契约。而 BackTop 只有一档、本项目没有
 *     第二个消费者要实心球 —— 等真出现再加。
 *   · **不做方形档**（Ant 的 `shape="square"`）：同上，没有消费者。
 *   · **不做阴影**：四家参照里阴影由 popover/shadow 令牌统一管，本仓
 *     没有 shadow 令牌（`Theme` 里只有 border / bg 系），现编一个值就是猜。
 *
 * ── 注册说明 ─────────────────────────────────────────────────────────
 * 与 `TimeCell` 同档：注册进 `contracts/qmldir` 只为**同目录**的
 * `QSkinBackTop` / `QSkinFloatButton` 能按名字使用它。它不带 `QSkin` 前缀、
 * 不进组件表的 `QSkin*.qml` 计数 —— 它不是给宿主用的控件，是内部件。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Rectangle {
    id: root

    /* 宿主控件（QSkinBackTop / QSkinFloatButton）。与插槽同款：只读它的状态，
     * 不改；用 var 而不是 Item，免得 qmllint 按 QQuickItem 做成员检查。 */
    property var control: null

    /** 请求直径。实际生效的是 `plateDiameter`（归一化之后）。 */
    property int diameter: 40

    /**
     * 生效直径 —— **两件共用的唯一算路**。
     *
     * `Math.max(1, …)` 只为挡掉 0 与负数（radius 为 0 会让圆球变成方块，
     * 而"看不见的球"比"方球"更难查）。这里**不设最小观感直径**：
     * 参照实现没给过最小值，编一个数就是猜 —— 真出现"球太小糊成一团"，
     * 该由使用方调 `diameter`，不该由底板替它做主。
     */
    readonly property int plateDiameter: Math.max(1, Math.round(root.diameter))

    /** 声明半径。与 `Math.min(width, height)/2` 在尺寸正确时相等 ——
     *  冒烟测试钉的就是这一条（见 tests/smoke_m27.qml）。 */
    readonly property real plateRadius: root.plateDiameter / 2

    readonly property bool hovered:  root.control ? root.control.hovered === true : false
    readonly property bool disabled: root.control ? root.control.enabled === false : false

    /* 实际半径取实际尺寸的一半，而不是直接写 plateRadius：
     * 首帧 width 还是 0（父项尚未定尺寸），写 plateRadius 会先画出一个
     * 半径正确、尺寸为 0 的圆，再跳一下。取实际尺寸则从 0 平滑长出来。
     * 与 plateRadius 的一致性由冒烟测试守。 */
    radius: Math.min(root.width, root.height) / 2

    color: root.disabled ? Theme.color.bgSubtle
                         : (root.hovered ? Theme.color.brandSubtle
                                         : Theme.color.bgElevated)
    border.width: 1
    border.color: root.disabled ? Theme.color.border
                                : (root.hovered ? Theme.color.brand
                                                : Theme.color.border)

    Behavior on color {
        ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
    }
}
