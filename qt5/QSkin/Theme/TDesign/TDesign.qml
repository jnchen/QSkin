/****************************************************************************
 * QSkin · Quick Design System — Theme / TDesign
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * TDesign 主题的**唯一入口**。用法就两行：
 *
 *     import QSkin.Theme.TDesign 1.0
 *     Component.onCompleted: TDesign.apply()      // 换上
 *     ...
 *     TDesign.remove()                            // 换下
 *
 * ── 一个主题 = 一份令牌 + 若干个插槽 ────────────────────────────────────
 * apply() 只做两件事：把令牌交给 Theme，把插槽交给 Slots。
 * 业务代码、控件代码、状态机、键盘导航、无障碍语义 —— 一个字都不用改。
 *
 * 这就是 M1 契约层的兑现方式：主题作者**没能碰到**任何控件源码，
 * 也不需要碰到。
 *
 * ── M2 的实际覆盖情况（重要结论）────────────────────────────────────────
 * 九个插槽里，TDesign 只覆盖了五个：
 *
 *   覆盖  buttonBackground  默认按钮 hover 只变描边不变底色
 *         label             字重恒 400；默认按钮 hover 文字变蓝
 *         inputBackground   常态白底（不是下沉）+ 聚焦外发光
 *         checkIndicator    未选中底色必须是白，用 bg 会和灰色页面糊在一起
 *         selectOverlay     圆角 6 + 8px 内边距 + 阴影
 *
 *   未覆盖 buttonContent / switchIndicator / tooltipOverlay
 *          —— 纯令牌换肤即可达标，没必要写第二份实现。
 *
 * 「五个覆盖、三个不用覆盖」本身就是 M2 想验证的结论：
 * 契约层切对了地方，主题作者八成的活是抄令牌，剩下两成才是真正的差异。
 *
 * ── 此后新增的覆盖（M4 / M15.1）────────────────────────────────────────
 *
 *   M4    tabIndicator       页签指示条
 *   M15.1 chevronIndicator   展开 / 折叠 / 翻页方向箭头
 *
 * 上面那句"九个插槽"说的是 M2 当时；这两条是后来长出来的家族成员。
 * M15.1 这条尤其值得记：indicator 家族从 M1 起就许诺了"展开箭头"，
 * 但那一格空了五个里程碑 —— 期间 QSkinSelect / QSkinTable / QSkinDatePicker /
 * QSkinPagination 各自绕过了它（详见契约层 Slots.qml 文件头）。
 * 四家的箭头**长得都不一样**，正是它必须进插槽而不是"统一画个矢量"的原因：
 * 尺寸（12 / 11 / 13 / 14）、线宽（18% / 14% / 22% / 固定 2px）、
 * 端点拐角（Flat+Miter / 三份 Round+Round）全是主题差异。
 ****************************************************************************/

pragma Singleton
import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

import "tokens.js" as Tokens
import "slots"

QtObject {
    id: root

    /* ── 令牌 ───────────────────────────────────────────────
     * 直接把 tokens.js 的对象交给 Theme。
     * Theme.patch() 已经改成整份复制（见 Theme.qml 里那段注释），
     * 所以这里的引用不会被就地改坏。 */
    property string name:  "TDesign"
    property var    light: Tokens.light
    property var    dark:  Tokens.dark

    /* ── 插槽实现 ───────────────────────────────────────────
     * Component 只能声明在对象树的声明位置，不能写进函数体 ——
     * 所以先在这里实例化好，apply() 里只做引用传递。
     * （同一个坑在 Slots.qml 文件头有详细记录。） */
    property Component tdButtonBackground: Component { TDButtonBackground { } }
    property Component tdLabel:            Component { TDLabel { } }
    property Component tdInputBackground:  Component { TDInputBackground { } }
    property Component tdCheckIndicator:   Component { TDCheckIndicator { } }
    property Component tdSelectOverlay:    Component { TDSelectOverlay { } }
    property Component tdTabIndicator:     Component { TDTabIndicator { } }
    /* 方向箭头（展开 / 折叠 / 翻页）。indicator 家族里「展开箭头」那一格
     * 此前一直是空的（谁要用谁自己画），这里补齐。契约见
     * slots/BasicChevronIndicator.qml 文件头。 */
    property Component tdChevronIndicator:  Component { TDChevronIndicator { } }

    /* 加载指示器的形态（M19）。这一格是四家里形态差异最大的一处 ——
     * 弧长/段数/线宽规则各不相同，没有一个能被令牌表达。 */
    property Component tdSpinRing: Component { TDSpinRing { } }

    /* 单选的圆环与圆心（M20）。TDesign 与 Basic 同为实心策略，
     * 但**圆点是 8 而不是 6**（`@radio-dot-size = @radio-size / 2`）。
     * Arco 的 5.6 与 6 只差 0.4px 所以复用了 Basic；TDesign 的 8 差 2px，
     * 在小圆点上就是 33% 的相对差 —— 这就是这一格存在的全部理由。 */
    property Component tdRadioIndicator: Component { TDRadioIndicator { } }

    /** 换上 TDesign 主题 */
    function apply() {
        Theme.install(root, root.name)
        Slots.install({
            buttonBackground: root.tdButtonBackground,
            label:            root.tdLabel,
            inputBackground:  root.tdInputBackground,
            checkIndicator:   root.tdCheckIndicator,
            selectOverlay:    root.tdSelectOverlay,
            tabIndicator:     root.tdTabIndicator,
            chevronIndicator: root.tdChevronIndicator,
            spinRing:    root.tdSpinRing,
            radioIndicator: root.tdRadioIndicator
        })
    }

    /** 换下 —— 回到地基的 Neutral 主题与 Basic 插槽 */
    function remove() {
        Slots.reset()
        Theme.reset()
    }
}
