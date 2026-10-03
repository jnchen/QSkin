/****************************************************************************
 * QSkin · Quick Design System — Foundation / CornerUtil
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 分组按钮三态圆角的 QML 入口。真正的实现在**同目录**的 `CornerUtil.js` 里，
 * 本文件一行映射都没有 —— 它只做转发。
 *
 * ── 为什么需要一个转发层（而不是让插槽直接 import 那个 .js） ──────────
 * 与 FuzzyMatch / ColorUtil / QRCodeEncoder / MasonryUtil 完全同源，
 * 理由见 FuzzyMatch.qml 文件头：QML 的 `.js` 导入只能是相对路径，而跨模块
 * 的相对路径在本仓对不上（`src/foundation` 被铺成 `QSkin/Foundation`，
 * 目录名跟着模块 URI 走）。同目录相对导入没有这个问题。
 *
 * ── 架构：一份实现，两类消费者 ───────────────────────────────────────
 *     CornerUtil.js      ← 唯一实现（门禁用 node 直接 require 它，
 *                           穷举 position × radius 验角序与边界）
 *        ↑            ↑
 *     本单例（QML）   .cache/_verify_m27.py（node）
 *
 * 契约说明全部在 `.js` 的文件头里（角序约定、为什么默认走 standalone、
 * 三条裁剪）—— 这里不重复，免得两处说法漂移。
 ****************************************************************************/

pragma Singleton
import QtQuick 2.15
import "CornerUtil.js" as Impl

QtObject {
    /** positionOf(index, count) → "standalone" | "first" | "middle" | "last" */
    function positionOf(index, count) {
        return Impl.positionOf(index, count)
    }

    /** corners(position, radius) → { tl, tr, br, bl } */
    function corners(position, radius) {
        return Impl.corners(position, radius)
    }
}
