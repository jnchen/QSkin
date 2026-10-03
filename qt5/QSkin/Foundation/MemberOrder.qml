/****************************************************************************
 * QSkin · Quick Design System — Foundation / MemberOrder
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 成员列表的**声明序**工具。给"一组同族控件互相登记、组再统一管状态"这类
 * 结构用（QSkinRadioGroup / QSkinToggleGroup / M23 的 Collapse / Timeline）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 它解决的是一个 Qt 的硬事实：**兄弟节点的 onCompleted 是逆声明序触发的**
 * ════════════════════════════════════════════════════════════════════════
 * 成员的登记走 `Component.onCompleted`，而 Qt 对**兄弟节点**的 onCompleted
 * 是**逆声明序**触发的。实测：三个同级 QtObject 各自在 onCompleted 里追加
 * 自己的编号，追出来的是 "321" 而不是 "123"。
 *
 * 照注册顺序排的后果都只在屏幕上看得见：
 *   · 方向键倒着走 —— 从第 1 个按 →，跳到的是最后一个；
 *   · 一个都没选时「可 Tab 到的那一个」落在**最后一个**成员上
 *     （WAI-ARIA 要的是第一项）；
 *   · 折叠面板的"第一个不画上分隔线 / 最后一个不画下分隔线"整体反转；
 *   · 时间轴的"第一颗点之上不画线 / 最后一颗点之下不画线"整体反转。
 *
 * 而 `children` 列表本身**是**声明序的（同一次实测里，Shape 与 Loader 的
 * children 下标与声明顺序一致），所以拿它的下标当键。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么它现在是地基层的一个单例，而不是各控件的私有函数
 * ════════════════════════════════════════════════════════════════════════
 * 这三段代码最初是 QSkinRadioGroup 私有的（M20）。M23 的三件容器
 * （Collapse / Timeline / Segmented）全都需要同一件事 —— 按声明序排成员 ——
 * 于是它到了第二个消费者的门口。
 *
 * 项目的判据（M17 起反复用的那条）：
 *
 *     「只要出现第二个消费者，它现在能跑就不再是理由。」
 *
 * 而本项目已经有**一次**因为没做这件事而付过账：`chevronIndicator` 那一格
 * 空了五个里程碑，期间四个控件各画一遍展开箭头，其中一种还是打字符
 * （见 Slots.qml 文件头）。同一份排序逻辑抄四遍，就是同一件事的第二次。
 *
 * 所以它是**抽出来的**，不是新写的 —— 原实现连同它的实测记录一起搬过来，
 * 一行没改。QSkinRadioGroup 改为调用这里，用 `smoke_m20.qml` 的 [1] 守回归
 * （那一条 [1] 里特意写了"一个都没选时该落到第一个可用成员"）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 用法
 * ════════════════════════════════════════════════════════════════════════
 *     function _register(m) {
 *         var out = root._members.slice()
 *         out.push(m)
 *         out = MemberOrder.sortByDeclaration(out)   // ← 就这一句
 *         root._members = out                        // 整体赋值 → 触发通知
 *     }
 *
 * 注意"整体赋值"那半句：`property var` 的**就地** push/splice 不发通知，
 * 而 `count` / `hasSelection` 这类派生属性全靠那个通知活着。本文件只管排序，
 * 不管通知 —— 那是调用方的事，但它俩总是成对出现，所以在这里提一句。
 ****************************************************************************/

pragma Singleton
import QtQuick 2.15

QtObject {
    id: root

    /**
     * 按**声明序**排好一列成员。
     *
     * 不改入参（返回新数组）：调用方通常要把结果整体赋给一个
     * `property var`，就地改会静默地不通知。
     */
    function sortByDeclaration(list) {
        if (list === null || list === undefined) return []
        var out = list.slice()
        out.sort(function (a, b) {
            return root.compareOrder(root.orderPath(a), root.orderPath(b))
        })
        return out
    }

    /**
     * 成员在场景树里的**声明序路径**：从根往下一路记下每层 children 的下标。
     *
     * 用**路径**而不是单层下标：成员可能被放在不同的布局容器里
     * （`QSkinRow` / `QSkinColumn`），单层下标在父子之间没有可比性。
     * 路径按字典序比较 = 先序遍历顺序 = 屏幕上的阅读顺序。
     */
    function orderPath(item) {
        var path = []
        var n = item
        while (n && n.parent) {
            path.unshift(root.childIndex(n.parent, n))
            n = n.parent
        }
        return path
    }

    /** `children` 的 indexOf。手写循环而不是用 `children.indexOf()`：
     *  QML 暴露给 JS 的序列类型对 Array 方法的支持随版本有差异，
     *  而同族的 `_applyAlign`（Foundation/QSkinRow.qml）也是手写循环。 */
    function childIndex(parent, item) {
        if (parent === null || parent === undefined) return -1
        var cs = parent.children
        if (cs === undefined) return -1
        for (var i = 0; i < cs.length; ++i)
            if (cs[i] === item) return i
        return -1
    }

    /** 字典序比较（短的那个在前）。 */
    function compareOrder(a, b) {
        var n = Math.min(a.length, b.length)
        for (var i = 0; i < n; ++i)
            if (a[i] !== b[i]) return a[i] - b[i]
        return a.length - b.length
    }

    /** 成员是不是这一列的**最后一个**（按声明序）。
     *  折叠面板 / 时间轴靠它决定"这一段分隔线画不画"。
     *  空列表返回 false —— 给"还没登记完"一个安全的答案。 */
    function isLast(list, item) {
        if (list === null || list === undefined || list.length === 0) return false
        return list[list.length - 1] === item
    }

    /** 成员在这一列里的**声明序下标**；不在列里返回 -1。 */
    function indexOf(list, item) {
        if (list === null || list === undefined) return -1
        for (var i = 0; i < list.length; ++i)
            if (list[i] === item) return i
        return -1
    }
}
