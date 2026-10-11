/****************************************************************************
 * QSkin · Quick Design System — Foundation / Body
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 正文排版预设。默认行高 1.5 —— 中英文混排下这是可读性的下限，
 * 也是"手写 QML 显得原始"最常见的成因之一。
 *
 * 用法：
 *     Body { text: "保存成功" }
 *     Body { text: "次要说明"; tone: "secondary" }
 *     Body { text: "重点"; strong: true }
 *     Body { text: "已废止"; strike: true; tone: "muted" }
 *
 * ── 行内修饰是**四个开关**，不是四个新类型（M30 裁决）──────────────────
 * Ant 的 `Typography.Text` 有一组行内写法：`strong` / `italic` /
 * `underline` / `delete`（外加 `code` / `mark` / `keyboard`）。本仓把它们
 * 收成正文预设上的四个布尔位 —— 理由是可核验性：四个位是 2^4 种组合，
 * 其中**任意组合都是合法语义**（"加粗的已删除文字"是真实存在的写法），
 * 拆成 `StrongText` / `ItalicText` / … 只会得到四个各写一遍字体映射的文件，
 * 还得再补一份"既加粗又删除"的组合。
 *
 * `code` / `mark` 两档**刻意不做**，理由与 `QSkinCountdown` 那笔不同：
 * 它们要的不是字形而是**背板**（Ant 的 `code` 是 mono + 浅底 + 圆角，
 * `mark` 是黄底）。`Text` 没有背景层，要画就得包一层 Rectangle ——
 * 那时它就不再是"正文预设"，而是一个内联容器，尺寸语义也随之改变
 * （隐式宽要按文字算、还要留内边距）。`mono` 已经覆盖了 code 的**字形**
 * 那一半；背板那一半归 QSkinTag / 内联代码件，不归排版预设。
 ****************************************************************************/

import QtQuick 2.11

Text {
    id: root

    /** default | secondary | muted | disabled */
    property string tone: "default"

    /** 是否为等宽字体（代码、日志、数值对齐） */
    property bool mono: false

    /* ══════════════════════ 行内修饰（M30）══════════════════════
     * 四个**纯字体位** —— 只改字形，一个像素的布局都不动：字重、倾斜、
     * 下划线、删除线全都是绘制期的事，`implicitWidth` 会跟着字体度量走
     * （字重会变宽，那是字体自己的事），但不会引入新的盒子。
     *
     * 这就是它们与 `Paragraph.maxLines` 的分界：那一件动的是**行数**，
     * 属布局；这四条属字形。 */

    /** 加粗（Ant `Text strong` = 600） */
    property bool strong: false

    /** 倾斜 */
    property bool italic: false

    /** 下划线 */
    property bool underline: false

    /** 删除线（Ant `Text delete`） */
    property bool strike: false

    text: ""

    font.family:    root.mono ? Theme.font.monoFamily : Theme.font.family
    font.pixelSize: Theme.font.sm
    /* `strong` 为 false 时求值结果与改前**逐字相同**（都是 weightRegular），
     * 所以这个三元不会改动任何既有像素 —— 四家主题的排版基线一动不动。 */
    font.weight:    root.strong ? Theme.font.weightSemiBold
                                : Theme.font.weightRegular
    font.italic:    root.italic
    font.underline: root.underline
    font.strikeout: root.strike

    lineHeight:     Theme.font.lineHeightBody
    lineHeightMode: Text.ProportionalHeight

    color: root.tone === "secondary" ? Theme.color.fgSecondary
         : root.tone === "muted"     ? Theme.color.fgMuted
         : root.tone === "disabled"  ? Theme.color.fgDisabled
                                     : Theme.color.fg

    verticalAlignment:   Text.AlignTop
    horizontalAlignment: Text.AlignLeft

    wrapMode:   Text.WordWrap
    renderType: Text.NativeRendering
}
