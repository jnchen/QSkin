/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinInputGroup
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 一组紧邻的输入框（以及可以混进来的按钮）。它**不改任何成员的样子**，
 * 只改一件事：圆角 —— 与 `QSkinButtonGroup` 是同族件。
 *
 *   ┌───────────┬──────────────┬──────────────┬──────────────┐
 *   │           │ first        │ middle       │ last         │
 *   ├───────────┼──────────────┼──────────────┼──────────────┤
 *   │ 左上      │ ● 圆         │ ─ 方         │ ─ 方         │
 *   │ 右上      │ ─ 方         │ ─ 方         │ ● 圆         │
 *   │ 右下      │ ─ 方         │ ─ 方         │ ● 圆         │
 *   │ 左下      │ ● 圆         │ ─ 方         │ ─ 方         │
 *   └───────────┴──────────────┴──────────────┴──────────────┘
 *
 * 组里只有一枚时它仍是 **standalone**（四角全圆），不是"首尾合一"的
 * 怪态 —— 这条边界在 `Foundation/CornerUtil.js` 的 `positionOf` 里。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 成员协议是**通用的**，不是"输入框专用"
 * ════════════════════════════════════════════════════════════════════════
 * 判据只有一条：`isGroupMember === true`。`QSkinInput` 与 `QSkinButton` 都
 * 恒声明它，于是**两件可以混排在同一个组里** —— 那正是 Ant `Input.Search`
 * 的形状（输入框 + 右侧搜索按钮共享边框）。刻意不写"只收 QSkinInput"的
 * 检查：那会把一个真需求挡在门外，而它一个像素的代价都没有。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 根类型为什么是 `QQ.Row`（照 QSkinButtonGroup 的实测结论，不重推）
 * ════════════════════════════════════════════════════════════════════════
 * `QSkinRow` **不能用**：`Foundation/QSkinRow.qml` 是
 *     Item { default property alias data: layout.data }
 * —— 子项被重新挂到**内层**那个真 Row 上，于是成员的 `parent` 不是组本身，
 * `parent.isInputGroup` 恒为 undefined，整个三态圆角**静默失效**（属性全
 * 是默认值、界面全圆角，而没有任何一处报错）。
 *
 * 写成 `import QtQuick 2.15 as QQ` + `QQ.Row` 是显式写法，不依赖 import
 * 顺序。完整的三条实测（`QSkinRow` 不行 / 裸 `Row` 的歧义 / 限定名不合法）
 * 在 `QSkinButtonGroup.qml` 的文件头里，本件不重抄。
 * M30 探针 G 又单独量了一遍：`QQ.Row` 里两枚 `QSkinInput` 的
 * `parent === 容器` 为 **true**，紧邻时 x = 0 / 200。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 裁剪（如实记，别在别处补全）
 * ════════════════════════════════════════════════════════════════════════
 *   · **不排间距**：`spacing` 恒 0，与 QSkinButtonGroup 一致（"连在一起的一枚"）。
 *
 *   · **不做"相邻边框合并"** —— 这一条是**已知有损，如实记账**：
 *     两枚成员紧邻时，第一枚的右边框与第二枚的左边框各占 1px，中间是
 *     **2px 同色线**。Ant 的参照实现用「负外边距 -1px」吃掉一道。
 *     本件刻意不做，理由是那需要容器知道**成员的边框宽**（`1`），而边框
 *     宽是主题插槽的自由 —— 写死 `spacing: -1` 就是把一个跨层的硬编码
 *     假设焊进契约（"量法不能与被测量共享假设"的同一条）。
 *     代价评估：两道线**同色**，浅色下只是看起来略粗，几乎不可辨；
 *     聚焦/报错时只有一枚变色，也不冲突。真要做，正确的位置是让成员
 *     上报 `groupOverlap`、容器按值回缩 —— 没有消费者之前不建这条通路。
 *
 *   · **不排间距以外的任何东西**：`spacing` 之外不碰成员的几何。
 *
 *   · **不做竖排** / **不做 RTL** —— 同 QSkinButtonGroup 的两条裁剪
 *     （竖排该圆的是上/下两角，是另一张映射表；LTR 见 CornerUtil.js）。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick 2.15 as QQ
import QSkin.Foundation 1.0

QQ.Row {
    id: root

    /* 紧邻 —— 见文件头「裁剪」第 1 条。写成属性而不是常量，是为了让
     * "这里为什么不给间距"有一个可读的答案，也方便探针把它设成非 0
     * 来确认**分组语义不依赖间距**。 */
    spacing: 0

    /** 成员协议：QSkinInput（以及 QSkinButton）反向读它。与 isButtonGroup 同款。 */
    readonly property bool isInputGroup: true

    /** 无障碍名称。分组本身不是可交互控件，但读屏该知道"这是一组" */
    property string accessibleName: ""

    Accessible.role: Accessible.Grouping
    Accessible.name: root.accessibleName

    /** 成员个数（只数带 isGroupMember 标记的子项）。 */
    readonly property int count: root._memberCount()

    /* ══════════════════════ 成员协议 ══════════════════════
     * 由成员在求值时反向调用（拉模型 —— 理由见 QSkinButtonGroup 文件头：
     * 父项逐个赋值会打断绑定，且要等 onCompleted，而兄弟 onCompleted
     * 是逆声明序触发的）。 */

    /**
     * positionOf(item) → "standalone" | "first" | "middle" | "last"
     *
     * 只数**参与者**：组里可能出现不是输入框的东西（分隔符、Spacer、
     * 一个 Loader），它们不该影响"谁是第一个 / 谁是最后一个"。
     * 这与 QSkinButtonGroup 只数 isGroupMember 是同一条。
     *
     * 方位名本身不在这里算 —— 交给 `CornerUtil.positionOf(idx, n)`。
     * 那条映射要能被 node 穷举（M27 裁决四），留在 QML 里就打不到了。
     */
    function positionOf(item) {
        if (item === null || item === undefined) return "standalone"
        var cs = root.children
        var idx = -1
        var n = 0
        for (var i = 0; i < cs.length; ++i) {
            var c = cs[i]
            if (!root._isMember(c)) continue
            if (c === item) idx = n
            n++
        }
        return CornerUtil.positionOf(idx, n)
    }

    /** memberAt(i) → 第 i 个参与者；越界给 null */
    function memberAt(i) {
        var cs = root.children
        var n = 0
        for (var k = 0; k < cs.length; ++k) {
            if (!root._isMember(cs[k])) continue
            if (n === i) return cs[k]
            n++
        }
        return null
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    function _memberCount() {
        var cs = root.children
        var n = 0
        for (var i = 0; i < cs.length; ++i)
            if (root._isMember(cs[i])) n++
        return n
    }

    /* 过一层函数的原因与 QSkinButton._isMember 相同：
     * `children` 的元素静态类型是 QQuickItem，直接写 c.isGroupMember
     * 会被 qmllint 按 QQuickItem 做成员检查。函数参数没类型标注 = var。 */
    function _isMember(c) {
        return !!c && c.isGroupMember === true
    }
}
