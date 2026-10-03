/****************************************************************************
 * QSkin · Quick Design System — Foundation / OverlayStack
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「同一时刻只能有一个**排他**浮层」—— 这件事归谁？
 *
 * ── 三个候选，以及为什么剩了这一个 ──────────────────────────────────────
 *
 *   归插槽  ×
 *     插槽契约第 3 条写着"插槽不能引入新的交互"。关掉别的浮层是一条
 *     交互规则，放进插槽等于让每个主题自己实现一遍关闭策略。
 *
 *   归控件  ×
 *     那就是 M21 的六个件各写一套。它们会写得**不一样** —— 有的在
 *     onOpened 里关、有的在 open() 里关、有的干脆忘了，而且没有任何
 *     一处能一眼看出"这是同一条规矩"。这正是 M1 建契约层要消灭的东西。
 *
 *   归契约层的一个单例  ✓
 *     一份实现、一处可测、六个件只写一行 `OverlayStack.request(this)`。
 *
 * ── 为什么默认不是"所有浮层互相顶掉" ───────────────────────────────────
 *
 * 指针驱动的开合本来就有 Qt 兜底：Popup 的 closePolicy 里
 * `CloseOnPressOutside` 意味着"点开 B 的那一下按在 A 外面"，
 * A 会先关掉。所以**真正缺的只是"程序化开两个"**这条路径。
 *
 * 但即便有 Qt 兜底，也有一类浮层**不该**被顶掉：
 *
 *     Tooltip / HoverCard   —— 悬停提示
 *
 * 鼠标划过一个按钮时冒出提示，不该把用户刚点开的下拉框关掉；反过来，
 * 打开一个下拉框也不该把鼠标底下那个悬停提示吃掉。这两类东西在
 * 交互上不冲突，硬让它们互相排他是错的。
 *
 * 所以本单例只登记**排他**浮层（Popover / Popconfirm / Dropdown /
 * ContextMenu），悬停类的浮层根本不进来。谁进来由控件自己声明
 * （QSkinPopover.exclusive）—— 单例不猜。
 *
 * ── 关闭顺序为什么不能边走边改数组 ──────────────────────────────────────
 *
 * request() 先把新栈写进去、再回头关旧的。反过来写会让被关者在自己
 * 的 onClosed 里调 drop()，而那时我们正遍历着同一个数组 —— 关一个、
 * 少一个、跳一个，是那种"三个浮层时才对、两个时看不出"的错。
 * 这里遍历的是 slice() 出来的副本，且新栈已经就位，被关者的 drop()
 * 找不到自己（不在新栈里）就安静返回。
 ****************************************************************************/

pragma Singleton
import QtQuick 2.15

QtObject {
    id: root

    /** 当前打开着的排他浮层，栈底在前、栈顶在后 */
    property var _stack: []

    /** 同刻打开的排他浮层数。正常情形只可能是 0 或 1 —— 大于 1 就是没接好 */
    readonly property int exclusiveCount: root._stack.length

    /** 栈顶（最后打开的那个）；空栈为 null */
    function top() {
        return root._stack.length > 0 ? root._stack[root._stack.length - 1] : null
    }

    function contains(overlay) {
        return root._stack.indexOf(overlay) >= 0
    }

    /**
     * request(overlay)
     * 登记一个排他浮层。此前打开的其它排他浮层会被关掉。
     * 已在栈里的重复请求是空操作（不重排、不重关）。
     */
    function request(overlay) {
        if (overlay === null || overlay === undefined) return
        if (root._stack.indexOf(overlay) >= 0) return

        var prev = root._stack.slice()
        var next = prev.slice()
        next.push(overlay)
        root._stack = next                      /* 整份赋值 → 触发通知 */

        /* 新栈已就位，现在才去关旧的。被关者在 onClosed 里会调 drop()，
         * 而它已经不在 _stack 里了，drop() 会安静返回。 */
        for (var i = 0; i < prev.length; ++i)
            root._close(prev[i])
    }

    /** 注销（浮层关闭时调）。不在栈里就是空操作 —— 非排他浮层也会调它 */
    function drop(overlay) {
        var i = root._stack.indexOf(overlay)
        if (i < 0) return
        var next = root._stack.slice()
        next.splice(i, 1)
        root._stack = next
    }

    /** 全部关掉（换主题、切页这类场景用） */
    function clear() {
        if (root._stack.length === 0) return
        var prev = root._stack.slice()
        root._stack = []
        for (var i = 0; i < prev.length; ++i)
            root._close(prev[i])
    }

    /* 鸭子类型调用 —— 与 Slots.qml 里 `property var control` 同一手法：
     * 参数声明成 Item 会让 qmllint 按 QQuickItem 做成员检查，
     * 把 close() 报成 Member not found。 */
    function _close(overlay) {
        if (overlay && overlay.close !== undefined) overlay.close()
    }
}
