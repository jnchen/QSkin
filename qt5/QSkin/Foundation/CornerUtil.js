/****************************************************************************
 * QSkin · Quick Design System — Foundation
 * 分组按钮的「三态圆角」映射
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 输入「这一枚按钮处在组的哪个位置」，输出**四个角各自的半径**。
 * 它不画一笔 —— 画是插槽（buttonBackground）的事。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么这是一份下沉的纯函数，而不是五份插槽里各写一个 switch
 * ════════════════════════════════════════════════════════════════════════
 * 三态圆角有**五个消费者**：`slots/BasicButtonBackground` 与四家主题的
 * `TD/AD/AC/SCButtonBackground`。五份里各写一遍 `position === "first"`
 * 的 switch，就是五份可能漂移的语义。
 *
 * 项目的判据在这儿是硬的：**出现第二个消费者，就不该各写一套**。
 * 与 `groupPosition` 本身是"由父项算、子项只读"同一个理由。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么能下沉（它凭什么可被独立算路打）
 * ════════════════════════════════════════════════════════════════════════
 * 与 ScrollUtil / FuzzyMatch / ColorUtil / MasonryUtil 同源：
 * 输入输出全是字符串与数，**没有任何像素、没有任何 QML 类型**。
 * 于是门禁可以用 node 直接 require 这一个文件，而且能打的地方比
 * "看起来对不对"多得多：
 *
 *   ① 穷举 position × radius，验**角序约定**（下方那条约定）；
 *   ② 验 standalone 是**恒等**映射 —— 不分组时四角全等，
 *      即"不读新字段的主题行为逐字不变"这句承诺的数学形式；
 *   ③ 验 first / last **互补**（first 的 tl/bl 与 last 的 tr/br 镜像）；
 *   ④ 验 middle 四角全零 —— 它单独可以被"全零"满足，
 *      所以必须与 ①③ 一起才说明映射真的在跑；
 *   ⑤ 验 `positionOf(i, n)` 的边界：n<=1 → standalone（单枚按钮在
 *      组里仍然四角全圆）、越界 → standalone、i=0/n-1/中间三态。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 角序约定（这条是**被审计的对象**，不只是注释）
 * ════════════════════════════════════════════════════════════════════════
 * 返回值键名一律 **tl / tr / br / bl**，顺时针。这个顺序不是随意的：
 * QML 的 `Rectangle` 属性名是 `topLeftRadius` / `topRightRadius` /
 * `bottomRightRadius` / `bottomLeftRadius`，小写缩写正好一一对应，
 * 插槽侧才能写成一行一个、看不出翻译层：
 *
 *     topLeftRadius:     c.tl
 *     topRightRadius:    c.tr
 *     bottomRightRadius: c.br
 *     bottomLeftRadius:  c.bl
 *
 * 写错一格的表现是**镜像**（first 变成右侧圆角）—— 四个数字全对、
 * 属性全对、界面全错。这是本项目第五次重复的那类失败，所以判据必须
 * 钉到"哪一个键"上，而不是"圆角数对不对"。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 裁剪（如实记，别在别处补全）
 * ════════════════════════════════════════════════════════════════════════
 *   · **只支持 LTR**。"first" 指声明序第一个，也就是最左边那一枚。
 *     参照实现里 ButtonGroup 在 RTL 下首尾互换 —— 本项目没有 RTL 消费者，
 *     所以不建这条通路（`direction` 参数一个消费者都没有，写它就是猜）。
 *   · **不做垂直分组**（竖排按钮组，TDesign 有 vertical 档）。
 *     竖排时该圆的是上/下两角，映射表是另一张。没有消费者，不写。
 *   · 非法 radius（负数 / NaN / 非数）按 **0** 处理，不抛 —— 与
 *     MasonryUtil 对非法高度的处置一致：渲染路径不该因为一个坏入参
 *     把整块界面弄崩。
 *
 * 所以本文件刻意**不写 `.pragma library`** —— 那条指令是 QML 专有的，
 * node 会当作语法错误（与 FuzzyMatch.js / MasonryUtil.js 同一条）。
 ****************************************************************************/

/** 半径归一化：非数、负数、NaN 一律 0 */
function _r(radius) {
    var v = Number(radius)
    if (!isFinite(v) || v < 0) return 0
    return v
}

/**
 * positionOf(index, count) → "standalone" | "first" | "middle" | "last"
 *
 * 用「第几个 / 一共几个」而不是去问控件，是为了让这条语义可被穷举。
 * 边界一律回落到 standalone：
 *   count <= 1  → 组里只有一枚按钮，它四角全圆（不是"首尾合一"的怪态）
 *   index 越界  → standalone（宁可多圆，也不要少画一个角）
 */
function positionOf(index, count) {
    var i = Number(index)
    var n = Number(count)
    if (!isFinite(i) || !isFinite(n) || n <= 1) return "standalone"
    if (i < 0 || i >= n) return "standalone"
    if (i === 0) return "first"
    if (i === n - 1) return "last"
    return "middle"
}

/**
 * corners(position, radius) → { tl, tr, br, bl }
 *
 * 未知 position 一律走 standalone 分支（四角全圆）—— 默认值是"更圆"，
 * 不是"更方"。理由：方角会让一枚独立按钮看起来像被谁裁掉了角，而
 * 多圆只会让它看起来像一枚普通按钮。**坏入参的失败方向选小的那个。**
 */
function corners(position, radius) {
    var r = _r(radius)
    switch (position) {
    case "first":  return { tl: r, tr: 0, br: 0, bl: r }
    case "last":   return { tl: 0, tr: r, br: r, bl: 0 }
    case "middle": return { tl: 0, tr: 0, br: 0, bl: 0 }
    default:       return { tl: r, tr: r, br: r, bl: r }
    }
}

/* node 可直接 require 本文件（QML 侧看不到 module，用 typeof 保护） */
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        positionOf: positionOf,
        corners: corners
    }
}
