/****************************************************************************
 * QSkin · 冒烟测试 —— M4：tabIndicator 契约 / extender 契约 / QSkinTabs / QSkinMenu
 *
 * 断言写法见 tools/test.sh 文件头：≤ 8 条，bit n = 断言 [n]。
 * 尺寸断言必须在事件循环跑过至少一轮之后（Layouts 的 polish 时序）。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0

/* 直接实例化 TDesign 的浮层外壳，验证主题上报的 extender 值 */
import "../src/themes/tdesign/slots"

Item {
    id: root

    property int failures: 0
    property int activations: 0
    property int triggers: 0

    function expect(ok) { if (!ok) root.failures++ }

    QSkinTabs {
        id: tabs
        model: ["全部", "待办", "已完成"]
        onActivated: root.activations++
    }

    QSkinMenu {
        id: menu
        model: ["复制", "粘贴", { text: "删除", danger: true }, "separator", "刷新"]
        onTriggered: root.triggers++
    }

    QSkinSelect { id: sel; model: 3 }

    /* Basic 外壳实例，验证契约里的 extender === 0 */
    Loader {
        id: basicOverlay
        sourceComponent: Slots.selectOverlay
    }

    /* 经 property var 中转绕开 Loader.item 的静态类型误报
     * （局部 var 会被 qmllint 沿赋值传播 QObject 类型，property var 不会） */
    readonly property var basicOverlayItem: basicOverlay.item

    TDSelectOverlay { id: tdOverlay }

    Timer { id: stage1Timer; interval: 300; running: true; onTriggered: root.stage1() }
    Timer { id: stage2Timer; interval: 300; running: false; onTriggered: root.stage2() }

    function stage1() {
        /* [0] tabIndicator 契约存在；Basic 浮层 extender 恒为 0 */
        root.expect(Slots.tabIndicator !== null
                    && basicOverlayItem !== null && basicOverlayItem.extender === 0)

        /* [1] 页签尺寸：宽度由文字撑开（polish 后），高度 = tabHeight */
        root.expect(tabs.implicitWidth > 0 && tabs.height === tabs.tabHeight)

        /* [2] 激活 + 键盘移动 */
        tabs._activate(1)
        tabs._move(1)
        root.expect(tabs.currentIndex === 2 && root.activations === 2)

        /* [3] 菜单 model：5 项、下标 3 是分隔线、首启用项为 0 */
        root.expect(menu._itemCount() === 5
                    && menu._isSeparator(3) && !menu._isSeparator(0)
                    && menu._firstEnabled() === 0)

        menu.openAt(20, 20)
        stage2Timer.start()
    }

    function stage2() {
        /* [4] 菜单已展开 */
        root.expect(menu.opened)

        /* [5] 触发"粘贴"（下标 1）：信号送达、菜单同步关闭 */
        menu._trigger(1)
        root.expect(root.triggers === 1 && !menu.opened)

        /* [6] 主题浮层如实上报阴影外扩量（TDesign = 3px） */
        root.expect(tdOverlay.extender === 3)

        /* [7] apply() 之后 tabIndicator / selectOverlay 换成主题实现；
         * 主题缺失的令牌组（四套主题都没写 motion）保留地基默认值 ——
         * 否则所有控件里的 Behavior 在 apply 之后当场断掉；
         * remove()（同步 JS）之后立即复位回 Basic / Neutral */
        TDesign.apply()
        var swapped = Slots.tabIndicator !== Slots.basicTabIndicator
                      && Slots.selectOverlay !== Slots.basicSelectOverlay
                      && Theme.motion !== null && Theme.motion.fast === 120
                      && Theme.color.brand !== undefined
        TDesign.remove()
        root.expect(swapped && Slots.tabIndicator === Slots.basicTabIndicator)

        Qt.exit(root.failures & 0xFF)
    }
}
