/****************************************************************************
 * QSkin · Quick Design System — Foundation / Breakpoints
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 响应式断点 —— 等价于 CSS 的 @media (max-width: ...)
 *
 * 用法：
 *     import QSkin.Foundation 1.0
 *
 *     QSkinWindow {                       // QSkinWindow 会自动 attach
 *         Text {
 *             text: Breakpoints.compact ? "窄屏" : "宽屏"
 *         }
 *         Grid {
 *             minChildWidth: Breakpoints.compact ? 9999 : 240   // 窄屏强制单列
 *         }
 *     }
 *
 * 也可以手动挂到任意 Item 上：
 *     Breakpoints.attach(myWindow)
 ****************************************************************************/

pragma Singleton
import QtQuick 2.15

QtObject {

    /* ── 断点阈值（与 Web 端主流约定对齐） ────────────────────── */
    readonly property int compactMax:  767     // ≤ 767  compact（手机 / 极窄面板）
    readonly property int mediumMax:   1279    // 768 – 1279 medium（平板 / 小窗口）

    /* ── 被观测的宽度：由 attach() 绑定 ──────────────────────── */
    property int width: 0

    /* ── 语义判断 ─────────────────────────────────────────── */
    readonly property bool compact:  width > 0 && width <= compactMax
    readonly property bool medium:   width > compactMax && width <= mediumMax
    readonly property bool expanded: width > mediumMax

    readonly property string name: compact ? "compact" : (medium ? "medium" : "expanded")

    /**
     * attach(item)
     * 把断点观测绑定到任意 Item / Window 的宽度上。
     */
    function attach(item) {
        if (!item) return
        width = Qt.binding(function() { return Math.round(item.width) })
    }

    /**
     * atLeast(name) —— 等价于 CSS 的 min-width 媒体查询
     *   Breakpoints.atLeast("medium")
     */
    function atLeast(level) {
        if (level === "compact")  return true
        if (level === "medium")   return !compact
        if (level === "expanded") return expanded
        return true
    }
}
