/****************************************************************************
 * QSkin · Quick Design System — Foundation / QRCodeEncoder
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 二维码编码器的 QML 入口。真正的实现在**同目录**的 `QRCodeEncoder.js` 里，
 * 本文件一个字都不算 —— 它只做转发。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么需要一个转发层（而不是让 QSkinQRCode 直接 import 那个 .js）
 * ════════════════════════════════════════════════════════════════════════
 * 因为 **QML 的 `.js` 导入只能是相对路径，而跨模块的相对路径在本仓是对不上的**。
 *
 * `src/` 被铺进 import 树时目录名会变（`src/foundation` → `QSkin/Foundation`），
 * 因为目录名要跟模块 URI 对应。于是从 `QSkin/Contracts/QSkinQRCode.qml` 往上找
 * 只能是 `../Foundation/QRCodeEncoder.js` —— 一旦写成源树里那个小写的
 * `../foundation/…`，**在 Windows 上会因为文件系统大小写不敏感而恰好能跑**，
 * 到 Linux 上就断。这种"在开发机上永远发现不了"的路径是最不该写进源码的。
 *
 * 同目录的相对导入（`import "QRCodeEncoder.js"`）没有这个问题：目录怎么被搬，
 * 两者都在一起。
 *
 * ── 于是架构是：一份实现，两个消费者 ─────────────────────────────────
 *     QRCodeEncoder.js     ← 唯一实现（门禁用 node 直接跑它）
 *        ↑              ↑
 *     本单例（QML）     .cache/_verify_m24.py（node）
 *
 * 这正是本仓在 M18 记下的那条：「出现了第二份画线的代码」。编码逻辑若长在
 * 控件里，门禁就只能通过控件属性去摸"控件认为的矩阵" —— 而"控件认为的"
 * 与"算出来的"一致，什么也证明不了。
 ****************************************************************************/

pragma Singleton
import QtQuick 2.15
import "QRCodeEncoder.js" as Impl

QtObject {
    /**
     * encode(text, ecc, opts) → { ok, error, mode, version, ecc, mask,
     *                             size, modules, dataCodewords, codewords }
     *
     * ecc  : "L" | "M" | "Q" | "H"（缺省 M）
     * opts : { version: 1..40, mask: 0..7 } —— 都给成可选，钉死它们是为了
     *        能被验证（见 `.js` 头部"掩码：为什么掩码号相同不能当判据"）。
     *
     * 空文本会被**显式拒绝**（ok=false）：零长度载荷任何模式下都读不出，
     * 那是退化输入而不是编码缺陷。控件侧据此显示占位符。
     */
    function encode(text, ecc, opts) {
        return Impl.encode(text, ecc, opts)
    }

    /** 矩阵 → 便于人眼/日志核对的文本（'#' 深 '.' 浅） */
    function matrixToText(modules) {
        return Impl.matrixToText(modules)
    }

    /** 四档纠错等级，按容量从大到小 —— 控件用它做输入校验 */
    readonly property var eccNames: Impl.eccNames

    /** 版本 v 的剩余位数表（REMAINDER_BITS[v-1]），门禁 [0] 组要用 */
    readonly property var remainderBits: Impl.REMAINDER_BITS
}
