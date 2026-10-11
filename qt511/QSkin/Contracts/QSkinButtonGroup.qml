/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinButtonGroup
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 一组紧邻的按钮。它**不改任何按钮的样子**，只改一件事：圆角。
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
 * 组里只有一枚按钮时它仍是 **standalone**（四角全圆），不是"首尾合一"的
 * 怪态 —— 这条边界写在 `Foundation/CornerUtil.js` 的 `positionOf` 里。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 根类型为什么是 `QQ.Row`，而不是 `QSkinRow`，也不是裸 `Row`
 * ════════════════════════════════════════════════════════════════════════
 * 三条都是量出来的，不是猜的（`.cache/probe_group/` 四份最小复现）：
 *
 *   ① `QSkinRow` **不能用**。Foundation/QSkinRow.qml 是
 *          Item { default property alias data: layout.data }
 *      —— 子项被重新挂到**内层**那个真 Row 上，于是按钮的 `parent`
 *      不是组本身，`parent.isButtonGroup` 恒为 undefined，
 *      整个三态圆角会静默失效（属性全是默认值，界面全圆角）。
 *
 *   ② **裸 `Row` 也不能用**（⚠ **M29 起这条已不成立**，见下）。同一份探针里，
 *      同时 import QtQuick 与 QSkin.Foundation 之后写 `Row { spacing: 3 }` 报
 *          Cannot assign to non-existent property "spacing"
 *      —— 后导入的 QSkin.Foundation 把 QtQuick 的 Row **遮住**了。
 *      这正是 Foundation/QSkinRow.qml 文件头警告过的那个歧义。
 *
 *      ⚠ **M29 更新**：`foundation/qmldir` 现在只注册 `QSkinRow` 一个名字，
 *      裸 `Row` 于是稳定地指 QtQuick 的 positioner，**歧义消失**（改名与
 *      理由见该 qmldir 与 `CMakeLists.txt` 的模块头）。本件仍然写 `QQ.Row`
 *      —— 那是显式写法、不依赖 import 顺序，比裸名更稳；改成裸名要重拍
 *      本件的像素基线，留给它自己的批次。完整的两层说明在
 *      `QSkinCascader.qml` 的同源段落里。
 *
 *   ③ **限定名 `QtQuick.Row` 不合法**：
 *          QtQuick.Row - QtQuick is neither a type nor a namespace
 *      （模块没有带命名空间导入时，用不了限定名。）
 *
 *   ④ 正确写法是 `import QtQuick 2.15 as QQ` + `QQ.Row` —— 实测生效，
 *      且 `child.parent === 组` 为 **true**、`spacing: 0` 下第二枚的
 *      `x` = 30（= 第一枚的宽）、`implicitWidth` = 60。Foundation/QSkinRow.qml
 *      文件头里那句 `QQ.Row { ... }` 说的是同一件事。
 *
 * 所以这个文件有**两个** QtQuick 导入（一个裸的给 Rectangle 等类型用，
 * 一个带 as QQ 的专门用来点名 `QQ.Row`）。看着冗余，其实是唯一写法。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 位置为什么是"子项问父项"，而不是"父项逐个赋值"
 * ════════════════════════════════════════════════════════════════════════
 * 父项写 `child.groupPosition = "first"` 会**打断绑定**（M26 QSkinTree 的
 * `_commitKeys` 记过这条："用一会儿才坏"的 bug 最难查），而且它得等
 * `Component.onCompleted` —— 本仓已实测过**兄弟节点的 onCompleted 是
 * 逆声明序触发的**（MemberOrder 文件头）。
 *
 * 拉模型没有这两个问题：`QSkinButton.groupPosition` 是一条绑定，读
 * `parent.positionOf(this)`，而 `positionOf` 读的是**当前**的 `children`。
 *
 * ③' 那条"绑定会不会跟着场景树变"是**实测过的**（探针 D）：
 * `children.length` 参与绑定时，追加一枚子项后绑定值 1 → 2 会更新。
 * 于是运行时往组里塞一枚按钮，圆角会自动重算 —— 这一条进了冒烟测试。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 裁剪（如实记，别在别处补全）
 * ════════════════════════════════════════════════════════════════════════
 *   · **不排间距**：`spacing` 恒 0。分组的全部意思就是"它们是连在一起的一枚"，
 *     要间距就该用两个组或 `QSkinRow`。需要"危险按钮两侧留白"的是
 *     **Foundation/ButtonBar**，那件事归它，不归这里。
 *   · **不做竖排**（TDesign 有 vertical 档）：竖排该圆的是上/下两角，
 *     是另一张映射表，且本项目没有消费者。
 *   · **不做 RTL**：首尾按声明序（= 视觉左到右）。见 CornerUtil.js。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick 2.11 as QQ
import QSkin.Foundation 1.0

QQ.Row {
    id: root

    /* 紧邻 —— 见文件头「裁剪」第 1 条。写成属性而不是常量，是为了让
     * "这里为什么不给间距"有一个可读的答案，也方便探针把它设成非 0
     * 来确认**分组语义不依赖间距**。 */
    spacing: 0

    /** 成员协议：QSkinButton 反向读它。与 QSkinRadioGroup 的 isRadioGroup 同款。 */
    readonly property bool isButtonGroup: true

    /** 无障碍名称。分组本身不是可交互控件，但读屏该知道"这是一组" */
    property string accessibleName: ""

    Accessible.role: Accessible.Grouping
    Accessible.name: root.accessibleName

    /** 成员个数（只数带 isGroupMember 标记的子项）。 */
    readonly property int count: root._memberCount()

    /* ══════════════════════ 成员协议 ══════════════════════
     * 由成员在求值时反向调用（拉模型 —— 见文件头）。 */

    /**
     * positionOf(item) → "standalone" | "first" | "middle" | "last"
     *
     * 只数**参与者**：组里可能出现不是按钮的东西（分隔符、Spacer、
     * 一个 Loader），它们不该影响"谁是第一个 / 谁是最后一个"。
     * 这与 QSkinRadioGroup 只登记 QSkinRadio 是同一条。
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

    /* 过一层函数的原因与 QSkinButton._groupPositionOf 相同：
     * `children` 的元素静态类型是 QQuickItem，直接写 c.isGroupMember
     * 会被 qmllint 按 QQuickItem 做成员检查。函数参数没类型标注 = var。 */
    function _isMember(c) {
        return !!c && c.isGroupMember === true
    }
}
