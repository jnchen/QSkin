/****************************************************************************
 * QSkin · Quick Design System — Foundation / ColorUtil
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 颜色换算的 QML 入口。真正的实现在**同目录**的 `ColorUtil.js` 里，
 * 本文件一行算法都没有 —— 它只做转发。
 *
 * ── 为什么需要一个转发层（而不是让 QSkinColorPicker 直接 import 那个 .js）──
 * 与 QRCodeEncoder.qml / FuzzyMatch.qml 完全同源，理由见那两份文件头：
 * QML 的 `.js` 导入只能是相对路径，而跨模块的相对路径在本仓对不上
 * （`src/foundation` 被铺成 `QSkin/Foundation`，目录名跟着模块 URI 走）。
 * 同目录相对导入（`import "ColorUtil.js"`）没有这个问题。
 *
 * ── 架构：一份实现，两个消费者 ───────────────────────────────────────
 *     ColorUtil.js      ← 唯一实现（门禁用 node 直接 require 它，
 *                          再写一份**走 HSL 中转**的换算做独立算路比对）
 *        ↑            ↑
 *     本单例（QML）   .cache/_verify_m26color.js（node）
 *
 * 契约说明全部在 `.js` 的文件头里（三条刻意的确定性选择、y 轴方向、
 * 已知边界）—— 这里不重复，免得两处说法漂移。
 ****************************************************************************/

pragma Singleton
import QtQuick 2.11
import "ColorUtil.js" as Impl

QtObject {
    /* ── HSV ↔ RGB ── */

    /** hsvToRgb(h, s, v) → { r, g, b }（0..255 整数） */
    function hsvToRgb(h, s, v) {
        return Impl.hsvToRgb(h, s, v)
    }

    /** rgbToHsv(r, g, b) → { h, s, v }；灰阶的 h 固定为 0 */
    function rgbToHsv(r, g, b) {
        return Impl.rgbToHsv(r, g, b)
    }

    /* ── HEX ── */

    /** rgbToHex(r,g,b) → "#RRGGBB"（大写、恒 6 位） */
    function rgbToHex(r, g, b) {
        return Impl.rgbToHex(r, g, b)
    }

    /** hexToRgb(str) → { r, g, b } | null（非法值给 null，不给黑） */
    function hexToRgb(str) {
        return Impl.hexToRgb(str)
    }

    /** 校验 + 归一化：非法返回 ""，合法返回大写 6 位形式 */
    function normalizeHex(str) {
        return Impl.normalizeHex(str)
    }

    /* ── 取色几何（y 正向 = 明度减小，见 .js 文件头那张四角图）── */

    function svFromPoint(x, y, w, h) { return Impl.svFromPoint(x, y, w, h) }
    function pointFromSv(s, v, w, h) { return Impl.pointFromSv(s, v, w, h) }
    function hueFromX(x, w)          { return Impl.hueFromX(x, w) }
    function xFromHue(h, w)          { return Impl.xFromHue(h, w) }

    /** 预设色块：n 个等距色相、固定 s / v —— 算出来的，不是抄来的色值表 */
    function swatchRing(n, s, v) { return Impl.swatchRing(n, s, v) }

    /* 色相上限暴露出来，是为了让冒烟测试与像素核验**读同一个数** ——
       否则"色相条 100% 处是 360°"这类判据会在两侧各写一份魔数。 */
    readonly property real hueMax: Impl.HUE_MAX
}
