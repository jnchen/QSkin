/****************************************************************************
 * QSkin · Quick Design System — Foundation
 * 默认令牌集：中性（Neutral）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 这份文件刻意不绑定任何设计语言 —— 这是「UI 无关」地基的关键。
 * 主题层（TDesign / Ant Design / Arco / shadcn）只需要提供同形状的对象，
 * 就能通过 Theme.install() 整体替换，业务代码一行不改。
 *
 * 令牌组：color / space / radius / font / size / motion
 * 主题可以只覆盖其中任意几组，未提供的组保留这里的默认值。
 *
 * 注意：这里**不要**加 .pragma library。
 * 加了之后 QML 会把它当作共享的只读库，Theme.patch() 的就地改写可能失效；
 * 而且本文件只被 Theme.qml 引用一次，复制带来的内存开销可以忽略。
 ****************************************************************************/


/* ═══════════════════════════ 浅色 ═══════════════════════════ */

var light = {

    /* ── 色彩 ──────────────────────────────────────────────────
     * 命名沿用 Web 设计系统的语义约定（bg / fg / border / brand / 语义色），
     * 而不是 Qt 的 palette 命名，方便直接照抄 Web 端的设计稿标注。
     * ──────────────────────────────────────────────────────── */
    color: {
        // 容器层级
        bg:             "#FFFFFF",
        bgSubtle:       "#F7F7FA",   // 页面侧边、表头
        bgElevated:     "#FFFFFF",   // 卡片、弹层
        bgSunken:       "#F0F0F4",   // 输入框底、代码块

        // 文字层级
        fg:             "#18181D",
        fgSecondary:    "#55555F",
        fgMuted:        "#8A8A96",
        fgDisabled:     "#B4B4BE",

        // 描边
        border:         "#E2E2E9",
        borderStrong:   "#C6C6D0",

        /* divider —— "裸放在页面底上的线"。
         *
         * 为什么不复用 border：`border` 的语义是**容器自己的边框**，它的
         * 参照物是那个容器（卡片 / 输入框 / 菜单）的**面**。而 Divider、
         * 分栏栏杆、滚动条这三样东西不挂在任何容器上，它们直接躺在
         * `bg`（页面底）上 —— 参照物不同，能用的深浅就不同。
         *
         * 这不是推演出来的洁癖，是 M18 抓图上撞出来的实据：在 TDesign
         * 主题（页底色 #EEEEEE）上，一整屏 Divider + 分栏栏杆 + 滚动条
         * 全都不见了，而属性断言一片绿。原因就是 TDesign 的 `border`
         * （#E7E7E7）比它自己的页底色还浅 7 阶。
         *
         * 硬约束：**每一套主题的 divider 都必须在自己那套的 bg 上可辨识**。
         * 白底主题（neutral / arco / shadcn）可以直接沿用 border；
         * 灰底主题（tdesign / ant）必须借下一档。 */
        divider:        "#E2E2E9",

        // 品牌
        brand:          "#7C3AED",
        brandHover:     "#6D28D9",
        brandActive:    "#5B21B6",
        brandSubtle:    "#F3E8FF",
        onBrand:        "#FFFFFF",

        // 语义
        success:        "#16A34A",
        successSubtle:  "#DCFCE7",
        warning:        "#D97706",
        warningSubtle:  "#FEF3C7",
        danger:         "#DC2626",
        dangerHover:    "#B91C1C",
        dangerActive:   "#991B1B",
        dangerSubtle:   "#FEE2E2",
        info:           "#0284C7",
        infoSubtle:     "#E0F2FE",

        // 焦点与遮罩
        focus:          "#7C3AED",
        scrim:          "#0B0B10",
        scrimOpacity:   0.40
    },

    /* ── 间距：4pt 基线 ─────────────────────────────────────
     * 组件内边距、卡片留白、区块间距共用同一把尺子。
     * 禁止在业务代码里出现 10 / 15 / 18 这类不在刻度上的数字。
     * ──────────────────────────────────────────────────── */
    space: {
        none:  0,
        xxs:   2,
        xs:    4,
        sm:    8,
        md:    12,
        lg:    16,
        xl:    24,
        xxl:   32,
        xxxl:  48
    },

    /* ── 圆角 ─────────────────────────────────────────────── */
    radius: {
        none: 0,
        sm:   2,
        md:   4,
        lg:   8,
        xl:   16,
        full: 999
    },

    /* ── 排版：字号阶梯 12 → 32 ─────────────────────────────
     * lineHeight 单位为倍率，配合 Text.ProportionalHeight 使用。
     * ──────────────────────────────────────────────────── */
    font: {
        family:            "Inter",
        monoFamily:        "JetBrains Mono",

        xs:                12,
        sm:                14,
        md:                16,
        lg:                20,
        xl:                24,
        display:           32,

        weightRegular:     400,
        weightMedium:      500,
        weightSemiBold:    600,
        weightBold:        700,

        lineHeightBody:    1.5,
        lineHeightHeading: 1.25
    },

    /* ── 尺寸：控件高度与图标 ────────────────────────────────
     * 桌面端指针精度高，最小点击目标可以到 24；
     * 触屏场景请统一用 controlLg(40)。
     * ──────────────────────────────────────────────────── */
    size: {
        controlSm:    24,
        controlMd:    32,
        controlLg:    40,

        iconSm:       16,
        iconMd:       20,
        iconLg:       24,

        focusRing:    2,
        focusOffset:  2
    },

    /* ── 动效：时长(ms) + 曲线 ───────────────────────────────
     * easing 存的是 QEasingCurve::Type 的数值（.js 里取不到 Easing 枚举），
     * 注释里给出对应的 QML 枚举名，便于对照。
     * ──────────────────────────────────────────────────── */
    motion: {
        instant: 0,
        fast:    120,
        normal:  200,
        slow:    320,

        easing:      6,   // Easing.OutCubic
        easingIn:    5,   // Easing.InCubic
        easingOut:   6    // Easing.OutCubic
    }
}


/* ═══════════════════════════ 深色 ═══════════════════════════ */

var dark = {

    color: {
        bg:             "#141419",
        bgSubtle:       "#1C1C24",
        bgElevated:     "#23232C",
        bgSunken:       "#0F0F14",

        fg:             "#F2F2F5",
        fgSecondary:    "#A8A8B5",
        fgMuted:        "#75757F",
        fgDisabled:     "#4E4E58",

        border:         "#2E2E39",
        borderStrong:   "#43434F",
        divider:        "#2E2E39",   // 深色下 border 本就亮于 bg，沿用

        brand:          "#A855F7",
        brandHover:     "#C084FC",
        brandActive:    "#9333EA",
        brandSubtle:    "#2E1065",
        onBrand:        "#FFFFFF",

        success:        "#22C55E",
        successSubtle:  "#0B3B22",
        warning:        "#F59E0B",
        warningSubtle:  "#3D2A05",
        danger:         "#EF4444",
        dangerSubtle:   "#3D1215",
        info:           "#38BDF8",
        infoSubtle:     "#082F44",

        focus:          "#C084FC",
        scrim:          "#000000",
        scrimOpacity:   0.55
    },

    space: light.space,
    radius: light.radius,
    font: light.font,
    size: light.size,
    motion: light.motion
}
