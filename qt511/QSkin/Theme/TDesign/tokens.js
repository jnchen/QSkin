/****************************************************************************
 * QSkin · Quick Design System — Theme / TDesign / tokens
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * TDesign 设计令牌，映射到 QSkin 的地基令牌形状。
 *
 * ── 取值来源 ────────────────────────────────────────────────────────────
 * 浅色：全部取自 TDesign 官方 Design Token 文档（Vue Next）
 *       https://tdesign.tencent.com/starter/docs/vue-next/design-token
 *       每个值后面的注释都写了官方 token 名，可逐条核对。
 *
 * 深色：取自官方《Dark Mode 深色模式》文档
 *       https://tdesign.tencent.com/design/dark
 *       文字色 #fff 的 90/60/40/26% 与深色蓝阶 Blue*、红阶 Red* 为官方值；
 *       少数官方未定义的槽位（bgSunken）明确标注为「推导值」。
 *
 * ── 一个刻意的设计决定：不提供 motion 组 ────────────────────────────────
 * TDesign 公开文档里没有独立的动效时长 token 体系（组件内多为硬编码
 * 0.2s + cubic-bezier(0.38,0,0.24,1)）。与其编一串数字，不如直接留空 ——
 * Theme.install() 的组级回退会让地基值继续生效。
 * 这也是「主题只写自己真正要改的部分」这条规则最好的示范。
 *
 * 注意：这里**不要**加 .pragma library，理由同地基的 neutral.js。
 ****************************************************************************/


/* ═══════════════════════════ 浅色 ═══════════════════════════ */

var light = {

    /* ── 色彩 ────────────────────────────────────────────────
     * TDesign 的文字色是**带透明度**的（rgba(0,0,0,90%) 而不是
     * 拍平成 #E5E5E5）。CSS 用 rgba()，QML 的 #AARRGGBB 同样能表达，
     * 所以这里原样保留透明度 —— 叠在任何底色上都是官方的观感，
     * 拍平反而会在换容器底色时露馅。
     * ──────────────────────────────────────────────────── */
    color: {
        // 容器层级
        bg:             "#EEEEEE",   // --td-bg-color-page      = gray-color-2
        bgSubtle:       "#F3F3F3",   // --td-bg-color-secondarycontainer = gray-color-1
        bgElevated:     "#FFFFFF",   // --td-bg-color-container
        bgSunken:       "#E7E7E7",   // --td-bg-color-component = gray-color-3

        // 文字层级（rgba(0,0,0,x) 的 #AARRGGBB 形式）
        fg:             "#E5000000", // --td-text-color-primary   90%
        fgSecondary:    "#99000000", // --td-text-color-secondary 60%
        fgMuted:        "#66000000", // --td-text-color-placeholder 40%
        fgDisabled:     "#42000000", // --td-text-color-disabled  26%

        // 描边
        border:         "#E7E7E7",   // --td-border-level-1-color = gray-color-3
        borderStrong:   "#DCDCDC",   // --td-component-border     = gray-color-4
        divider:        "#DCDCDC",   // 推导：gray-color-4。页底色是 gray-color-2(#EEEEEE)，
                                     // 上面那档(#E7E7E7)只差 7 阶、屏幕上什么都看不见

        // 品牌（色阶 brand-color-1..10）
        brand:          "#0052D9",   // --td-brand-color        = brand-color-7
        brandHover:     "#366EF4",   // --td-brand-color-hover  = brand-color-6
        brandActive:    "#003CAB",   // --td-brand-color-active = brand-color-8
        brandSubtle:    "#F2F3FF",   // --td-brand-color-light  = brand-color-1
        onBrand:        "#FFFFFF",   // --td-text-color-anti

        // 语义
        success:        "#2BA471",   // --td-success-color = success-color-5
        successSubtle:  "#E3F9E9",   // success-color-1
        warning:        "#E37318",   // --td-warning-color = warning-color-5
        warningSubtle:  "#FFF1E9",   // warning-color-1
        danger:         "#D54941",   // --td-error-color       = error-color-6
        dangerHover:    "#F6685D",   // --td-error-color-hover = error-color-5
        dangerActive:   "#AD352F",   // --td-error-color-active= error-color-7
        dangerSubtle:   "#FFF0ED",   // error-color-1
        info:           "#0052D9",   // TDesign 没有 info 语义色，沿用品牌色
        infoSubtle:     "#F2F3FF",

        // 焦点与遮罩
        focus:          "#D9E1FF",   // --td-brand-color-focus = brand-color-2
        scrim:          "#000000",   // --td-mask-active rgba(0,0,0,60%)
        scrimOpacity:   0.60,

        /* TDesign 扩展键（地基没有，多出来不影响任何现有引用）
         * focusHalo 存在的理由见文件末尾的「已知缺口」注释。 */
        focusHalo:      "#D9E1FF"
    },

    /* ── 间距：--td-size-* 刻度 ─────────────────────────────*/
    space: {
        none:  0,
        xxs:   2,   // --td-size-1
        xs:    4,   // --td-size-2
        sm:    8,   // --td-size-4
        md:    12,  // --td-size-5
        lg:    16,  // --td-size-6
        xl:    24,  // --td-size-8
        xxl:   32,  // --td-size-10
        xxxl:  48,  // --td-size-13

        /* TDesign 刻度里地基没有的三档，单独命名以免和上面的语义名混用。
         *
         * 这三档 + 下面 radius 的 xxl **目前没有消费者**，但**有意保留** ——
         * 它们对着官方刻度表（--td-size-3/7/9）可核验，删掉之后下一次要
         * 用 20 或 28 的人只能凭感觉填一个不在刻度上的数字（本仓禁止）。
         * 所以每行标了 `token-gate: extend`：令牌名门禁会认这个标记。
         * 标记是**义务**而不是装饰 —— 去掉它，./tools/lint.sh 就会变红。 */
        size6:  6,  // --td-size-3    token-gate: extend
        size20: 20, // --td-size-7    token-gate: extend
        size28: 28  // --td-size-9    token-gate: extend
    },

    /* ── 圆角 ───────────────────────────────────────────────
     * TDesign 的圆角比地基小一档：按钮 3px、卡片 6px。
     * 这是它和 shadcn（6px 起步）最容易一眼分辨的特征。
     * ──────────────────────────────────────────────────── */
    radius: {
        none: 0,
        sm:   2,    // --td-radius-small
        md:   3,    // --td-radius-default   ★ 按钮 / 输入框
        lg:   6,    // --td-radius-medium    ★ 卡片 / 下拉
        xl:   9,    // --td-radius-large
        full: 999,  // --td-radius-round
        xxl:  12    // --td-radius-extraLarge（TDesign 独有）  token-gate: extend
    },

    /* ── 排版 ───────────────────────────────────────────────
     * 字号取 --td-font-size-body-* / title-* / headline-*。
     * 行高按官方配对换算成倍率（body-medium 14/22 → 1.571）。
     *
     * family 只能填一个名字：TDesign 官方字体栈是
     *   PingFang SC, Microsoft YaHei, Arial
     * 而 QML 的 font.family 是单值属性。这里按 Windows 桌面端
     * 这个主要目标平台填 "Microsoft YaHei"；跨平台请改用
     * Qt 6 的 font.families（列表）或在启动时按平台覆写这一项。
     * ──────────────────────────────────────────────────── */
    font: {
        family:            "Microsoft YaHei",
        monoFamily:        "Consolas",

        xs:                12,  // --td-font-size-body-small
        sm:                14,  // --td-font-size-body-medium  ★ 正文基准
        md:                16,  // --td-font-size-body-large
        lg:                20,  // --td-font-size-title-large
        xl:                24,  // --td-font-size-headline-small
        display:           36,  // --td-font-size-headline-large

        weightRegular:     400,
        weightMedium:      500,
        weightSemiBold:    600,
        weightBold:        700,

        lineHeightBody:    1.571,  // 22 / 14
        lineHeightHeading: 1.4     // 28 / 20
    },

    /* ── 尺寸：--td-comp-size-* ─────────────────────────────
     * 与地基刻度完全一致（24 / 32 / 40），显式写在这里是为了让
     * 主题自证 —— 删掉这一组，Theme.install 的组级回退会让它照常工作。
     * ──────────────────────────────────────────────────── */
    size: {
        controlSm:    24,   // --td-comp-size-xs
        controlMd:    32,   // --td-comp-size-m
        controlLg:    40,   // --td-comp-size-xl

        iconSm:       16,
        iconMd:       20,
        iconLg:       24,

        focusRing:    2,
        focusOffset:  0     // TDesign 的光晕是 box-shadow 0 0 0 2px，紧贴边框
    }

    /* motion 组：刻意留空，见文件头说明 */
}


/* ═══════════════════════════ 深色 ═══════════════════════════ */

var dark = {

    color: {
        /* 深色下的层级关系是**反过来**的：页面最暗，卡片比页面亮。
         * 官方 ref：bgColorPage = gray-color-14，bgColorContainer = gray-color-13。
         * 灰阶本身与浅色共用同一条（gray-1 最亮 → gray-14 最暗）。 */
        bg:             "#181818",   // gray-color-14
        bgSubtle:       "#2C2C2C",   // gray-color-12  次级容器
        bgElevated:     "#242424",   // gray-color-13  容器（卡片 / 弹层）

        /* 推导值：官方没有定义深色下的「下沉」槽位。
         * 按 gray-color-14 再降一档得到，需要视觉校准。 */
        bgSunken:       "#0F0F0F",

        // 官方《深色模式》文档：文字为 #ffffff 的 90 / 60 / 40 / 26%
        fg:             "#E5FFFFFF",
        fgSecondary:    "#99FFFFFF",
        fgMuted:        "#66FFFFFF",
        fgDisabled:     "#42FFFFFF",

        border:         "#383838",   // gray-color-11
        borderStrong:   "#5E5E5E",   // gray-color-9
        divider:        "#383838",   // 深色下 border 本就亮于 bg(#181818)，沿用

        /* 深色蓝阶（官方《深色模式》Blue1..10）
         *   Blue5 #0957D9  Blue6 #2174FF  Blue7 #478DFF
         * 沿用与浅色一致的约定：hover 更亮、active 更暗。
         * 注：Flutter 版深色 ref 写的 brandNormalColor = brandColor8，
         * 两套口径不一致，Web 端实际值仍需以官方深色 token 校准一次。 */
        brand:          "#2174FF",   // Blue6
        brandHover:     "#478DFF",   // Blue7
        brandActive:    "#0957D9",   // Blue5
        brandSubtle:    "#062E9A",   // Blue2
        onBrand:        "#FFFFFF",

        success:        "#2BA471",
        successSubtle:  "#003B23",   // success-color-9
        warning:        "#E37318",
        warningSubtle:  "#3B1700",   // warning-color-10
        danger:         "#FB6E77",   // 深色红阶 Red6
        dangerHover:    "#FF9195",   // Red7
        dangerActive:   "#E35661",   // Red5
        dangerSubtle:   "#730524",   // Red1
        info:           "#2174FF",
        infoSubtle:     "#062E9A",

        focus:          "#1E2C60",   // 深色 ref: brandFocusColor = Blue1
        focusHalo:      "#1E2C60",
        scrim:          "#000000",
        scrimOpacity:   0.60
    },

    /* 其余组与浅色共用同一份对象 —— 这些刻度不随明暗变化。 */
    space:  light.space,
    radius: light.radius,
    font:   light.font,
    size:   light.size
}


/* ══════════════════════════════════════════════════════════════════════════
 * 已知缺口（写给 M3，也写给想复刻这套令牌的人）
 *
 * 1. focus 令牌是**浅色光晕**（#D9E1FF），TDesign 靠它配合品牌色边框使用；
 *    而 QSkin 地基的 FocusRing.qml 是画在控件外的独立描边，直接套用会在
 *    浅底上几乎看不见。M2 暂用官方值 + 额外的 focusHalo 键占位，
 *    M3 需要把焦点环拆成「内环色 + 外环色」两个令牌才能两全。
 *
 * 2. 深色的 bgSunken 是推导值，官方未定义。
 *
 * 3. 官方字体栈有三个名字，QML 的 font.family 只能填一个，见上方 font 注释。
 * ══════════════════════════════════════════════════════════════════════════ */
