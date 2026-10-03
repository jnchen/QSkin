/****************************************************************************
 * QSkin · Quick Design System — Theme / Ant Design / tokens
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Ant Design v5 设计令牌，映射到 QSkin 的地基令牌形状。
 *
 * ── 取值来源 ────────────────────────────────────────────────────────────
 * 浅色 seed token：官方《Customize Theme》文档
 *       https://ant.design/docs/react/customize-theme
 *       colorPrimary #1677FF / colorError #FF4D4F / colorSuccess #52C41A /
 *       colorWarning #FAAD14 / borderRadius 6 / controlHeight 32。
 * 文字梯度是 v5 派生算法的输出：colorText rgba(0,0,0,88%)、
 *       secondary 65%、tertiary 45%、quaternary 25%（对应 #AARRGGBB）。
 * 深色：darkAlgorithm 的输出（官方暗色 Demo 的实测值）：
 *       colorBgContainer #141414、colorBgLayout #000000、
 *       colorBorder #424242、文字 rgba(255,255,255,85/65/45/25%)。
 *
 * ── 与 TDesign 的三个关键差异（M3 反向验证的点）──────────────────────────
 *   1. 圆角大一档：按钮 6px（TDesign 是 3px），由 radius.md 驱动。
 *   2. 默认按钮 hover 也是「描边 + 文字变蓝、底色不动」—— 和 TDesign
 *      同款签名，说明这条映射不是某家的怪癖，值得沉淀进插槽。
 *   3. controlHeight 32 / SM 24 / LG 40 与地基一致，size 组显式自证。
 *
 * 注意：这里不要加 .pragma library，理由同 neutral.js / tdesign/tokens.js。
 ****************************************************************************/


/* ═══════════════════════════ 浅色 ═══════════════════════════ */

var light = {

    color: {
        // 容器层级（v5: colorBgLayout / colorFillTertiary / colorBgContainer / colorFillSecondary）
        bg:             "#F5F5F5",   // colorBgLayout  页面灰
        bgSubtle:       "#FAFAFA",   // colorFillQuaternary
        bgElevated:     "#FFFFFF",   // colorBgContainer
        bgSunken:       "#F0F0F0",   // colorFillTertiary  hover 填充

        // 文字层级（rgba(0,0,0,x%) → #AARRGGBB）
        fg:             "#E0000000", // colorText            88%
        fgSecondary:    "#A6000000", // colorTextSecondary   65%
        fgMuted:        "#73000000", // colorTextTertiary    45%
        fgDisabled:     "#40000000", // colorTextQuaternary  25%

        // 描边
        border:         "#F0F0F0",   // colorBorderSecondary 分割线
        borderStrong:   "#D9D9D9",   // colorBorder          控件描边
        divider:        "#D9D9D9",   // 推导：colorBorder。页底色 colorBgLayout 是 #F5F5F5，
                                     // colorBorderSecondary 在它上面只差 5 阶、不可辨

        // 品牌（蓝阶 Blue-5/6/7 由派生算法生成）
        brand:          "#1677FF",   // colorPrimary
        brandHover:     "#4096FF",   // colorPrimaryHover  Blue-5
        brandActive:    "#0958D9",   // colorPrimaryActive Blue-7
        brandSubtle:    "#E6F4FF",   // colorPrimaryBg     Blue-1
        onBrand:        "#FFFFFF",   // colorTextLightSolid

        // 语义
        success:        "#52C41A",   // colorSuccess
        successSubtle:  "#F6FFED",   // colorSuccessBg
        warning:        "#FAAD14",   // colorWarning
        warningSubtle:  "#FFFBE6",   // colorWarningBg
        danger:         "#FF4D4F",   // colorError
        dangerHover:    "#FF7875",   // colorErrorHover  Red-4
        dangerActive:   "#D9363E",   // colorErrorActive Red-6
        dangerSubtle:   "#FFF1F0",   // colorErrorBg     Red-1
        info:           "#1677FF",   // colorInfo 沿用品牌色
        infoSubtle:     "#E6F4FF",

        // 焦点与遮罩
        focus:          "#1677FF",   // colorPrimary（FocusRing 用）
        scrim:          "#000000",
        scrimOpacity:   0.45,

        /* 扩展键：Input 聚焦的 box-shadow 0 0 0 2px controlOutline */
        focusHalo:      "#1A0591FF"  // rgba(5,145,255,10%)
    },

    space: {
        none:  0,
        xxs:   2,
        xs:    4,    // sizeUnit
        sm:    8,    // sizeStep × 2
        md:    12,
        lg:    16,   // paddingContentHorizontal
        xl:    24,   // paddingContentHorizontalLG
        xxl:   32,
        xxxl:  48
    },

    /* v5: borderRadiusSM 4 / borderRadius 6 / borderRadiusLG 8 */
    radius: {
        none: 0,
        sm:   4,    // borderRadiusSM  ★ 复选框
        md:   6,    // borderRadius    ★ 按钮 / 输入框
        lg:   8,    // borderRadiusLG  ★ 卡片 / 下拉
        xl:   12,   // borderRadiusXL
        full: 999
    },

    font: {
        family:            "Microsoft YaHei",
        monoFamily:        "Consolas",

        xs:                12,  // fontSizeSM
        sm:                14,  // fontSize      ★ 正文基准
        md:                16,  // fontSizeLG
        lg:                20,  // fontSizeXL
        xl:                24,  // fontSizeHeading3
        display:           38,  // fontSizeHeading1

        weightRegular:     400,
        weightMedium:      500,
        weightSemiBold:    600,
        weightBold:        700,

        lineHeightBody:    1.5714,  // lineHeight 22/14
        lineHeightHeading: 1.2105   // headingLineHeight 46/38
    },

    size: {
        controlSm:    24,   // controlHeightSM
        controlMd:    32,   // controlHeight   ★ 基准
        controlLg:    40,   // controlHeightLG

        iconSm:       16,
        iconMd:       20,
        iconLg:       24,

        focusRing:    2,
        focusOffset:  0     // box-shadow 0 0 0 2px 紧贴边框
    }

    /* motion 组：v5 的 motionUnit/motionEase* 是算法参数而非成品时长，
     * 换算意义不大，留空走地基默认。 */
}


/* ═══════════════════════════ 深色 ═══════════════════════════ */

var dark = {

    color: {
        /* darkAlgorithm 的层级关系：页面最暗，容器比页面亮 */
        bg:             "#000000",   // colorBgLayout
        bgSubtle:       "#141414",   // colorFillQuaternary 深色
        bgElevated:     "#141414",   // colorBgContainer
        bgSunken:       "#1D1D1D",   // colorFillSecondary 深色

        // rgba(255,255,255,x%)：85 / 65 / 45 / 25
        fg:             "#D9FFFFFF",
        fgSecondary:    "#A6FFFFFF",
        fgMuted:        "#73FFFFFF",
        fgDisabled:     "#40FFFFFF",

        border:         "#2B2B2B",   // colorBorderSecondary 深色
        borderStrong:   "#424242",   // colorBorder 深色
        divider:        "#2B2B2B",   // 深色下 border 本就亮于 bg(#000000)，沿用

        /* 深色蓝阶（darkAlgorithm 输出） */
        brand:          "#1668DC",
        brandHover:     "#3C89E8",
        brandActive:    "#1554AD",
        brandSubtle:    "#111A2C",   // colorPrimaryBg 深色（推导值）
        onBrand:        "#FFFFFF",

        success:        "#49AA19",   // colorSuccess 深色
        successSubtle:  "#10231B",   // 推导值
        warning:        "#D89614",   // colorWarning 深色
        warningSubtle:  "#2B2111",   // 推导值
        danger:         "#DC4446",   // colorError 深色
        dangerHover:    "#E76E70",   // Red-4 深色
        dangerActive:   "#B33B3E",   // Red-6 深色
        dangerSubtle:   "#2C1618",   // 推导值
        info:           "#1668DC",
        infoSubtle:     "#111A2C",

        focus:          "#3C89E8",
        focusHalo:      "#261A3A5E", // rgba(60,137,232,15%) 推导值
        scrim:          "#000000",
        scrimOpacity:   0.60
    },

    space:  light.space,
    radius: light.radius,
    font:   light.font,
    size:   light.size
}


/* ══════════════════════════════════════════════════════════════════════════
 * 已知缺口（写给后续校准）：
 *   1. 深色语义底色（success/warning/dangerSubtle）是 darkAlgorithm
 *      派生结果的近似值，官方未逐项公开，需要视觉校准。
 *   2. focusHalo 浅色值取自 controlOutline rgba(5,145,255,10%)。
 * ══════════════════════════════════════════════════════════════════════════ */
