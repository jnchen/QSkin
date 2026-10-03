/****************************************************************************
 * QSkin · Quick Design System — Theme / shadcn / tokens
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * shadcn/ui（zinc 基调）设计令牌，映射到 QSkin 的地基令牌形状。
 *
 * ── 取值来源 ────────────────────────────────────────────────────────────
 * 官方 themes.json（ui.shadcn.com/themes，zinc 基调，经典 0.5rem 圆角版）：
 *   light: background #FFFFFF / foreground #09090B / muted #F4F4F5 /
 *          muted-foreground #71717A / border #E4E4E7 / input #E4E4E7 /
 *          primary #18181B / primary-foreground #FAFAFA /
 *          ring #A1A1AA / destructive #EF4444（经典版 destructive 为 red-500）
 *   dark:  background #09090B / card #09090B / muted #27272A /
 *          border #27272A / primary #FAFAFA / primary-foreground #18181B /
 *          destructive #7F1D1D（暗色降档）
 * 圆角：--radius 8px，sm = -4px、md = -2px（按钮 rounded-md = 6px）
 * 尺寸：按钮 h-8 / h-9 / h-10 → 32 / 36 / 40
 *
 * ── 与前三套的关键差异（M3 反向验证的点）────────────────────────────────
 *   1. **无品牌色**：primary 是近黑，语义色只有 destructive ——
 *      令牌里 brand 一族填的是灰阶，这是契约层能容纳的极端情况：
 *      「品牌色」只是一种常见的语义槽位，不是必需品。
 *   2. **按钮文字是 500 字重**（font-medium）：三套里唯一不用 400 的。
 *      label 插槽的字重自由度在这里兑现。
 *   3. **尺寸 32 / 36 / 40**：又一套与 Ant（24/32/40）、Arco（28/32/36）
 *      不同的刻度 —— 证明 size 组的换挡完全由令牌驱动。
 *
 * 注意：这里不要加 .pragma library。
 ****************************************************************************/


/* ═══════════════════════════ 浅色 ═══════════════════════════ */

var light = {

    color: {
        // 容器层级
        bg:             "#FFFFFF",   // background
        bgSubtle:       "#FAFAFA",   // zinc-50
        bgElevated:     "#FFFFFF",   // card
        bgSunken:       "#F4F4F5",   // muted / accent zinc-100

        // 文字层级
        fg:             "#09090B",   // foreground zinc-950
        fgSecondary:    "#52525B",   // zinc-600（推导档）
        fgMuted:        "#71717A",   // muted-foreground zinc-500
        fgDisabled:     "#A1A1AA",   // zinc-400

        // 描边
        border:         "#E4E4E7",   // border zinc-200
        borderStrong:   "#D4D4D8",   // zinc-300（推导档）
        divider:        "#E4E4E7",   // 页底色 background 是纯白，沿用 border 即可辨

        /* ★ 无品牌色：brand 一族 = 中性近黑。这是 shadcn 的身份本身。 */
        brand:          "#18181B",   // primary zinc-900
        brandHover:     "#2E2E33",   // primary/90（hover 时 90% 不透明度）
        brandActive:    "#27272A",   // zinc-800
        brandSubtle:    "#F4F4F5",   // accent = muted
        onBrand:        "#FAFAFA",   // primary-foreground zinc-50

        // 语义
        success:        "#16A34A",   // shadcn 无 success 语义色，保留地基绿
        successSubtle:  "#DCFCE7",
        warning:        "#D97706",
        warningSubtle:  "#FEF3C7",
        danger:         "#EF4444",   // destructive（经典版 red-500）
        dangerHover:    "#DC2626",   // red-600
        dangerActive:   "#B91C1C",   // red-700
        dangerSubtle:   "#FEE2E2",   // red-100
        info:           "#18181B",   // shadcn 无 info，沿用 primary 黑
        infoSubtle:     "#F4F4F5",

        // 焦点与遮罩
        focus:          "#A1A1AA",   // ring zinc-400
        scrim:          "#000000",
        scrimOpacity:   0.50,

        /* 扩展键：focus-visible 的 ring（2px + 2px offset） */
        focusHalo:      "#A1A1AA"
    },

    space: {
        none:  0,
        xxs:   2,
        xs:    4,
        sm:    8,
        md:    12,
        lg:    16,
        xl:    24,   // px-6（按钮水平内边距）
        xxl:   32,
        xxxl:  48
    },

    /* --radius 8 / sm=-4 / md=-2 */
    radius: {
        none: 0,
        sm:   4,    // rounded-sm   ★ 复选框
        md:   6,    // rounded-md   ★ 按钮 / 输入框
        lg:   8,    // rounded-lg   ★ 卡片 / 下拉
        xl:   12,   // rounded-xl
        full: 999
    },

    font: {
        family:            "Inter",     // shadcn 默认走系统字体栈，Inter 最接近
        monoFamily:        "JetBrains Mono",

        xs:                12,
        sm:                14,  // text-sm ★ 正文基准
        md:                16,  // text-base（shadcn 里反而不常用）
        lg:                18,  // text-lg
        xl:                24,
        display:           36,

        weightRegular:     400,
        weightMedium:      500, // ★ font-medium —— shadcn 按钮的签名
        weightSemiBold:    600,
        weightBold:        700,

        lineHeightBody:    1.4286,  // 20/14（leading-5）
        lineHeightHeading: 1.2222   // 44/36（text-4xl tracking-tight）
    },

    size: {
        controlSm:    32,   // h-8 （size=sm）
        controlMd:    36,   // h-9 ★ 默认 —— 又一套不同的刻度
        controlLg:    40,   // h-10（size=lg）

        iconSm:       16,
        iconMd:       20,
        iconLg:       24,

        focusRing:    2,
        focusOffset:  2     // ring-2 ring-offset-2 —— shadcn 的光晕离边框有间隙
    }
}


/* ═══════════════════════════ 深色 ═══════════════════════════ */

var dark = {

    color: {
        /* zinc 暗色：页面与卡片同色（#09090B），层级靠描边和 muted 区分 */
        bg:             "#09090B",
        bgSubtle:       "#18181B",
        bgElevated:     "#09090B",   // card = background（shadcn 官方如此）
        bgSunken:       "#27272A",   // muted zinc-800

        fg:             "#FAFAFA",
        fgSecondary:    "#D4D4D8",   // 推导档
        fgMuted:        "#A1A1AA",
        fgDisabled:     "#52525B",

        border:         "#27272A",
        borderStrong:   "#3F3F46",   // 推导档
        divider:        "#27272A",   // 深色下 border 本就亮于 bg(#09090B)，沿用

        /* ★ 深色下 primary 是**白**——反色按钮，shadcn 的招牌 */
        brand:          "#FAFAFA",
        brandHover:     "#E4E4E7",
        brandActive:    "#D4D4D8",
        brandSubtle:    "#27272A",
        onBrand:        "#18181B",   // primary-foreground 反转

        success:        "#22C55E",
        successSubtle:  "#14532D",
        warning:        "#F59E0B",
        warningSubtle:  "#451A03",
        danger:         "#7F1D1D",   // destructive 暗色（red-900 降档）
        dangerHover:    "#991B1B",   // red-800
        dangerActive:   "#B91C1C",   // red-700（暗色下反向升档）
        dangerSubtle:   "#450A0A",
        info:           "#FAFAFA",
        infoSubtle:     "#27272A",

        focus:          "#D4D4D8",   // ring 暗色
        focusHalo:      "#52525B",
        scrim:          "#000000",
        scrimOpacity:   0.65
    },

    space:  light.space,
    radius: light.radius,
    font:   light.font,
    size:   light.size
}


/* ══════════════════════════════════════════════════════════════════════════
 * 已知缺口：
 *   1. 经典 zinc 主题的 destructive 是 red-500/#EF4444；2024 后的新版
 *      themes.json 换成了 oklch 色彩空间的深红。这里取经典值，视觉更接近
 *      大家印象里的 shadcn。
 *   2. shadcn 的 link 变体带下划线，QSkin 的 label 契约没有下划线语义 ——
 *      SCLabel 用 hovered 时的 underline 近似（见该文件）。
 * ══════════════════════════════════════════════════════════════════════════ */
