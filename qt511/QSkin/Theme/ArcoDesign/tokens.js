/****************************************************************************
 * QSkin · Quick Design System — Theme / Arco Design / tokens
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Arco Design 设计令牌，映射到 QSkin 的地基令牌形状。
 *
 * ── 取值来源 ────────────────────────────────────────────────────────────
 * 色板：官方 Palette 文档（arco.design/react/en-US/docs/palette）
 *       arcoblue-6 #165DFF / -5 #4080FF / -7 #0E42D2
 *       red-6 #F53F3F / green-6 #00B42A / orange-6 #FF7D00
 *       gray-2 #F2F3F5 / gray-3 #E5E6EB / gray-4 #C9CDD4 / gray-10 #1D2129
 * 语义：官方 Design Token 页（color-text-1/2/3/4、color-border-2、
 *       border-radius-small 2 / medium 4 / large 8、尺寸 mini 24 / small 28 /
 *       default 32 / large 36）
 * 深色：官方暗色模式的语义层（bg-1 #17171A / bg-2 #232324、
 *       文字 #FFFFFF 的 90/70/45/30%），蓝阶红阶为暗色板推导值。
 *
 * ── 与前两套主题的三个关键差异（M3 反向验证的点）─────────────────────────
 *   1. **尺寸刻度整体不同**：28 / 32 / 36（Ant 与 TD 是 24 / 32 / 40）。
 *      size 组不写死「24/32/40 惯例」的价值在这里兑现 —— 刻度本身就是
 *      设计决策，主题有权换掉它。
 *   2. **输入框灰底、聚焦变白**：Arco 的招牌。Basic 的「下沉 → 提亮」
 *      映射恰好就是这个形状，但 Arco 用的是 fill 灰阶不是 sunken 语义 ——
 *      独立插槽把语义对应关系写清楚，而不是偷懒复用 Basic。
 *   3. **默认按钮是灰色实心**（secondary），不是白底描边：
 *      三套主题里唯一一个 default ≠ outline 的。
 *
 * 注意：这里不要加 .pragma library。
 ****************************************************************************/


/* ═══════════════════════════ 浅色 ═══════════════════════════ */

var light = {

    color: {
        // 容器层级（bg-1 页面 / fill-1 / bg-2 容器 / fill-2 组件灰）
        bg:             "#FFFFFF",   // color-bg-1 整体背景
        bgSubtle:       "#F7F8FA",   // color-fill-1
        bgElevated:     "#FFFFFF",   // color-bg-2 一级容器
        bgSunken:       "#F2F3F5",   // gray-2 = color-fill-2  ★ 输入框底

        // 文字层级（color-text-1/2/3/4）
        fg:             "#1D2129",   // gray-10 强调/正文
        fgSecondary:    "#4E5969",   // gray-8  次强调
        fgMuted:        "#86909C",   // gray-6  次要
        fgDisabled:     "#C9CDD4",   // gray-4  置灰

        // 描边
        border:         "#E5E6EB",   // color-border-2 浅/一般
        borderStrong:   "#C9CDD4",   // gray-4  深/控件描边
        divider:        "#E5E6EB",   // 页底色 color-bg-1 是纯白，沿用 border 即可辨

        // 品牌（arcoblue-7/6/5/1）
        brand:          "#165DFF",   // arcoblue-6 常规
        brandHover:     "#4080FF",   // arcoblue-5 悬浮
        brandActive:    "#0E42D2",   // arcoblue-7 点击
        brandSubtle:    "#E8F3FF",   // arcoblue-1
        onBrand:        "#FFFFFF",

        // 语义（red-7/6/5/1、green-6、orange-6）
        success:        "#00B42A",   // green-6
        successSubtle:  "#E8FFEA",   // green-1
        warning:        "#FF7D00",   // orange-6
        warningSubtle:  "#FFF7E8",   // orange-1
        danger:         "#F53F3F",   // red-6
        dangerHover:    "#F76560",   // red-5
        dangerActive:   "#CB272D",   // red-7
        dangerSubtle:   "#FFECE8",   // red-1
        info:           "#165DFF",   // Arco 没有 info 语义色，沿用品牌
        infoSubtle:     "#E8F3FF",

        // 焦点与遮罩
        focus:          "#BEDAFF",   // arcoblue-2（光晕底色）
        scrim:          "#000000",
        scrimOpacity:   0.45,

        /* 扩展键：
         *   focusHalo   输入框聚焦 box-shadow 0 0 0 3px rgba(22,93,255,13%)
         *   fillHover   灰色按钮 hover（color-fill-3 = gray-3）
         *   fillActive  灰色按钮按下（color-fill-4 = gray-4） */
        focusHalo:      "#21165DFF",
        fillHover:      "#E5E6EB",
        fillActive:     "#C9CDD4"
    },

    space: {
        none:  0,
        xxs:   2,
        xs:    4,
        sm:    8,
        md:    12,
        lg:    16,
        xl:    20,   // Arco 常用 spacing-5 = 20
        xxl:   32,
        xxxl:  48
    },

    /* border-radius-small 2 / medium 4 / large 8 */
    radius: {
        none: 0,
        sm:   2,    // small   ★ 复选框
        md:   4,    // medium  ★ 按钮 / 输入框 / 下拉
        lg:   8,    // large   ★ 卡片
        xl:   16,
        full: 999
    },

    font: {
        family:            "Microsoft YaHei",
        monoFamily:        "Consolas",

        xs:                12,  // font-size-body 12
        sm:                14,  // ★ 正文基准
        md:                16,
        lg:                20,
        xl:                24,
        display:           32,

        weightRegular:     400,
        weightMedium:      400, // Arco 按钮统一 400，Medium 档不存在
        weightSemiBold:    500, // Arco 的「加粗」只用 500
        weightBold:        600,

        lineHeightBody:    1.5714,
        lineHeightHeading: 1.5
    },

    /* ── 尺寸：与 Ant / TD 不同的刻度（mini/small/default/large）────────
     * M3 验证点：QSkinButton 的三档尺寸完全由这组令牌驱动，
     * 换成 Arco 刻度时控件代码零改动。 */
    size: {
        controlSm:    28,   // comp-size-small
        controlMd:    32,   // comp-size-default ★ 基准
        controlLg:    36,   // comp-size-large

        iconSm:       14,   // Arco 图标偏小一号
        iconMd:       16,
        iconLg:       20,

        focusRing:    2,
        focusOffset:  0
    }
}


/* ═══════════════════════════ 深色 ═══════════════════════════ */

var dark = {

    color: {
        bg:             "#17171A",   // color-bg-1 深色
        bgSubtle:       "#232324",   // color-bg-3 深色
        bgElevated:     "#232324",   // color-bg-2 深色
        bgSunken:       "#2A2A2B",   // 深色 fill（推导值）

        // #FFFFFF 的 90 / 70 / 45 / 30%
        fg:             "#E6FFFFFF",
        fgSecondary:    "#B3FFFFFF",
        fgMuted:        "#73FFFFFF",
        fgDisabled:     "#4DFFFFFF",

        border:         "#333335",
        borderStrong:   "#48484B",
        divider:        "#333335",   // 深色下 border 本就亮于 bg(#17171A)，沿用

        /* 暗色板 arcoblue（推导值，需视觉校准） */
        brand:          "#3C7EFF",
        brandHover:     "#6AA1FF",
        brandActive:    "#2949C9",
        brandSubtle:    "#0E2A8C",
        onBrand:        "#FFFFFF",

        success:        "#00D25B",
        successSubtle:  "#004D1C",
        warning:        "#FF9A2E",
        warningSubtle:  "#4D1B00",
        danger:         "#F76964",
        dangerHover:    "#F98981",
        dangerActive:   "#C1272D",
        dangerSubtle:   "#4D000A",
        info:           "#3C7EFF",
        infoSubtle:     "#0E2A8C",

        focus:          "#0E2A8C",
        focusHalo:      "#333C7EFF",
        scrim:          "#000000",
        scrimOpacity:   0.60,

        /* Arco 灰色实心按钮（secondary）的 hover / active 两档。
         *
         * ⚠ 这两个键**曾经只在浅色段存在**，而 slots/ACButtonBackground.qml
         *   的 `bg()` 在 default 位（非 hover、非按下）之外的两条分支读它们
         *   —— 深色下于是返回 undefined，Rectangle.color 拿到 undefined
         *   只会报一句 `Unable to assign [undefined] to QColor`，**底色直接
         *   不画**（不是回退到某个色，是这一帧没颜色）。三套 qml 宿主全绿
         *   也照样漏：门跑的场景没在深色下 hover 过灰色按钮。
         *   —— 坑是 2026-10-03 人工开窗口看 HelloQSkin 时从日志里捞出来的。
         *
         * 取值按 Arco 暗色灰阶推导：bg(#17171A) → bgSunken(#2A2A2B) 之上
         * 逐档抬明度，与 border(#333335) / borderStrong(#48484B) 同族。 */
        fillHover:      "#333335",   // gray-3 = color-fill-3 深色
        fillActive:     "#48484B"    // gray-4 = color-fill-4 深色
    },

    space:  light.space,
    radius: light.radius,
    font:   light.font,
    size:   light.size
}


/* ══════════════════════════════════════════════════════════════════════════
 * 已知缺口：深色蓝阶/红阶是暗色板推导值，官方暗色语义层需逐项校准。
 * ══════════════════════════════════════════════════════════════════════════ */
