/****************************************************************************
 * QSkin · Quick Design System — Foundation / Theme
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 全局令牌入口 —— M0 地基的唯一锚点。
 *
 * 用法：
 *     import QSkin.Foundation 1.0
 *     Rectangle {
 *         color:  Theme.color.bg
 *         radius: Theme.radius.md
 *     }
 *
 * 切换明暗：
 *     Theme.mode = "dark"
 *
 * 切换主题（TDesign / Ant / Arco / shadcn）：
 *     TDesign.apply()
 *
 * ── 为什么是「组级替换」而不是「逐项赋值」 ────────────────────────
 * QML 的属性绑定天然是响应式的：把 Theme.light 整个换成另一个对象，
 * 所有写了 Theme.color.bg 的地方会在同一帧内自动更新。
 * 这比 CSS 变量少了一层"级联传播"的心智负担，也意味着
 * 主题作者完全不需要碰控件代码 —— 只需要提交一份 token 对象。
 ****************************************************************************/

pragma Singleton
import QtQuick 2.15
import "tokens/neutral.js" as Neutral

QtObject {
    id: root

    /* ─────────────────────────── 状态 ─────────────────────────── */

    /** 明暗模式："light" | "dark" */
    property string mode: "light"

    /** 当前主题名（用于调试显示，主题层不依赖它） */
    property string themeName: "Neutral"

    /* ─────────────────── 令牌集合（主题层整体替换这里） ─────────────────── */

    property var light: Neutral.light
    property var dark:  Neutral.dark

    /** 当前生效的令牌集合 */
    readonly property var active: root.mode === "dark" ? root.dark : root.light

    /* ───────────── 业务代码只写这一层：短路径，不含主题判断 ───────────── */

    readonly property var color:  root.active ? root.active.color  : null
    readonly property var space:  root.active ? root.active.space  : null
    readonly property var radius: root.active ? root.active.radius : null
    readonly property var font:   root.active ? root.active.font   : null
    readonly property var size:   root.active ? root.active.size   : null
    readonly property var motion: root.active ? root.active.motion : null


    /* ─────────────────────────── 主题装载 ─────────────────────────── */

    /**
     * install(theme, name)
     *
     * theme 需要提供如下形状（light / dark 至少给一个）：
     *
     *     QtObject {
     *         property string name: "TDesign"
     *         property var light: { color: {...}, space: {...}, radius: {...},
     *                               font: {...}, size: {...}, motion: {...} }
     *         property var dark:  { ... }
     *     }
     *
     * 规则：
     *   1. 只替换 theme 真正提供的明暗集合，另一个保留当前值
     *   2. 集合内部缺失的组（比如主题不定义 space）保留地基默认值
     *   3. 因此主题作者只需要写自己真正想改的那部分
     */
    function install(theme, name) {
        if (!theme) {
            console.warn("QSkin.Theme.install(): theme is null")
            return
        }
        /* 合并基准是**出厂默认**（Neutral），不是当前集合 ——
         * 连续切换主题时不会互相残留：切到 B 不会带着 A 的令牌。
         * 这同时也兑现了 README 规则 2：「集合内部缺失的组保留地基默认值」。
         * M4 之前 install 是整体替换，四套主题都没定义 motion 组，
         * apply 之后 Theme.motion 变成 undefined，全部控件里的
         * Behavior 动效当场断掉（截图验证时抓到的真 bug）。 */
        if (theme.light !== undefined && theme.light !== null)
            root.light = root._mergeGroup(Neutral.light, theme.light)
        if (theme.dark !== undefined && theme.dark !== null)
            root.dark = root._mergeGroup(Neutral.dark, theme.dark)

        var n = name || (theme.name !== undefined ? theme.name : null)
        if (n) root.themeName = n
    }

    /** 以 base（出厂默认）为基准，逐组并入 overlay（主题）提供的组 */
    function _mergeGroup(base, overlay) {
        var out = {}
        for (var g in base) {
            if (overlay[g] === undefined || overlay[g] === null) {
                out[g] = base[g]                       // 规则 2：缺失组 → 地基默认
            } else if (typeof base[g] === "object" && typeof overlay[g] === "object") {
                var m = {}
                for (var k in base[g])    m[k]  = base[g][k]
                for (var k2 in overlay[g]) m[k2] = overlay[g][k2]
                out[g] = m
            } else {
                out[g] = overlay[g]
            }
        }
        /* 主题提供了地基没有的组 → 原样保留 */
        for (var g2 in overlay)
            if (out[g2] === undefined) out[g2] = overlay[g2]
        return out
    }

    /**
     * patch(group, values, target)
     * 细粒度覆盖某一组里的某几个令牌，用于「主题 + 品牌微调」。
     *   Theme.patch("color", { brand: "#0052D9" })        // 改当前明暗
     *   Theme.patch("color", { brand: "#0052D9" }, "dark")// 只改深色
     */
    function patch(group, values, target) {
        if (!values) return

        var onDark
        if (target === "dark")       onDark = true
        else if (target === "light") onDark = false
        else                         onDark = (root.mode === "dark")

        var set = onDark ? root.dark : root.light
        if (!set || !set[group]) {
            console.warn("QSkin.Theme.patch(): unknown group '" + group + "'")
            return
        }

        /* ── 这里刻意**不**原地改 set ──────────────────────────────
         *
         * root.light 与 Neutral.light 是同一个 JS 对象（见本文件上方的
         * 属性声明，是直接引用，不是拷贝）。如果写成
         *
         *     set[group] = merged
         *     root.light = root.light      // 想靠自赋值触发绑定刷新
         *
         * 那么改动会写进出厂默认令牌本身，reset() 再取 Neutral.light
         * 拿回来的还是被改过的那份 —— 令牌被永久污染，跨过 reset 一直
         * 留到进程结束，而且极难察觉（界面看起来"就是对的"，只是再也
         * 回不到默认值）。这个 bug 是被 tests/smoke_theme.qml 的
         * 断言 [3] 抓出来的。
         *
         * 改成整份复制出一个新对象再换上去，两个问题一起解决：
         *   1. 原集合不被触碰，Neutral 保持干净，reset() 能真正恢复
         *   2. 顶层对象身份一定变化，属性写入不会被引擎判定为
         *      "值没变"而跳过 —— 自赋值的触发并不可靠
         */
        var next = {}
        for (var g in set) next[g] = set[g]

        var merged = {}
        for (var k  in set[group]) merged[k]  = set[group][k]
        for (var k2 in values)     merged[k2] = values[k2]
        next[group] = merged

        if (onDark) root.dark = next
        else        root.light = next
    }

    /** 恢复地基默认令牌 */
    function reset() {
        root.light = Neutral.light
        root.dark  = Neutral.dark
        root.themeName = "Neutral"
    }
}
