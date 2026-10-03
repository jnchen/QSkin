/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicBreadcrumbSeparator
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「breadcrumbSeparator」插槽的 Basic 默认实现 —— 面包屑项之间的分隔符。
 *
 * 为什么值得单独成槽：分隔符是**各设计语言差异最显眼**的一处小细节。
 *   TDesign   "/"   弱前景、14px
 *   Ant       "/"   弱前景、14px
 *   Arco      ">"   弱前景、12px
 *   shadcn    "›"   更弱前景、16px（斜体感的单尖括号）
 * 把它硬编码成 "/" 会让另外三套主题一眼假。差异属于主题，所以收进插槽。
 *
 * ── 契约 ──────────────────────────────────────────────────────────────
 *   property var control   宿主 = 一个面包屑条目（QSkinBreadcrumb 内的 crumb）
 *   宿主保证暴露：last（bool，本项是否为"当前位置"）
 *   尺寸：插槽自报 implicitWidth / implicitHeight，宿主据此排布。
 *
 * 用 Text 画而不是 Shape：分隔符**就是**一个字符，字形本身就是设计决策
 * （"/" 与 "›" 的差异不是路径差异，是字体差异）。这与复选框的勾不同 ——
 * 那个用 Shape 是因为 U+2713 的字体覆盖率不稳，而 "/" ">" "›"
 * 在 Inter 里都稳稳存在。
 *
 * 契约第 3 条：分隔符没有交互，插槽里不许放 MouseArea。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Text {
    id: root

    property var control: null

    text: "/"

    font.family:    Theme.font.family
    font.pixelSize: Theme.font.sm
    color:          Theme.color.fgMuted

    verticalAlignment: Text.AlignVCenter

    /* 宽度取字形自然宽 —— 不强制固定宽，因为 ">" 比 "/" 窄、
     * "›" 更窄，固定宽会让间距看起来忽大忽小。 */
    width:  implicitWidth
    height: implicitHeight
}
