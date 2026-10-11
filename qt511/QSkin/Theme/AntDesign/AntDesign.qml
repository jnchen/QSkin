/****************************************************************************
 * QSkin · Quick Design System — Theme / Ant Design
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Ant Design 主题的唯一入口。用法：
 *
 *     import QSkin.Theme.AntDesign 1.0
 *     Component.onCompleted: AntDesign.apply()
 *     ...
 *     AntDesign.remove()
 *
 * 结构与 TDesign 同构（一个 token 文件 + 一组插槽实现），这份同构本身就是
 * M3 反向验证的第一个结论：M2 的主题结构可以复制。
 *
 * ⚠ 这里**不写**"几个插槽"这类计数 —— 它会随每个里程碑变化，而写在文件头
 *   的数字没人会记得改。真实的覆盖情况由 `install()` 的键列表唯一决定；
 *   `tests/smoke_m*_theme.qml` 里那条"装上去的必须**不等于** Basic"的断言
 *   是它的门禁（M19 栽过一次：键名写错 → 静默留在 Basic → 非 null 也成立）。
 ****************************************************************************/

pragma Singleton
import QtQuick 2.11
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

import "tokens.js" as Tokens
import "slots"

QtObject {
    id: root

    property string name:  "AntDesign"
    property var    light: Tokens.light
    property var    dark:  Tokens.dark

    property Component adButtonBackground: Component { ADButtonBackground { } }
    property Component adLabel:            Component { ADLabel { } }
    property Component adInputBackground:  Component { ADInputBackground { } }
    property Component adCheckIndicator:   Component { ADCheckIndicator { } }
    property Component adSelectOverlay:    Component { ADSelectOverlay { } }
    property Component adTabIndicator:     Component { ADTabIndicator { } }
    /* 方向箭头（展开 / 折叠 / 翻页）。indicator 家族里「展开箭头」那一格
     * 此前一直是空的（谁要用谁自己画），这里补齐。契约见
     * slots/BasicChevronIndicator.qml 文件头。 */
    property Component adChevronIndicator:  Component { ADChevronIndicator { } }

    /* 加载指示器的形态（M19）。这一格是四家里形态差异最大的一处 ——
     * 弧长/段数/线宽规则各不相同，没有一个能被令牌表达。 */
    property Component adSpinRing: Component { ADSpinRing { } }

    /* 单选框的圆环（M20）。Ant 是**描边策略**（选中时外圈仍是浅底、
     * 只有描边变品牌色，圆心是品牌色圆点），与 Basic 的实心策略相反 ——
     * 这正是这一格必须存在的理由。见 slots/ADRadioIndicator.qml。 */
    property Component adRadioIndicator: Component { ADRadioIndicator { } }

    /* 分段控制器的活动块（M23）。Ant 是这一格的**参照家**：它的分段选中
     * 是"白块抬起"，与它自己的开关打开态（品牌色实心轨道）**不是同一种
     * 视觉** —— 那正是这一格必须与 toggleBackground 分开的理由。
     * 见 slots/ADSegmentThumb.qml 文件头。 */
    property Component adSegmentThumb: Component { ADSegmentThumb { } }

    function apply() {
        Theme.install(root, root.name)
        Slots.install({
            buttonBackground: root.adButtonBackground,
            label:            root.adLabel,
            inputBackground:  root.adInputBackground,
            checkIndicator:   root.adCheckIndicator,
            selectOverlay:    root.adSelectOverlay,
            tabIndicator:     root.adTabIndicator,
            chevronIndicator: root.adChevronIndicator,
            spinRing:    root.adSpinRing,
            radioIndicator: root.adRadioIndicator,
            segmentThumb: root.adSegmentThumb
        })
    }

    function remove() {
        Slots.reset()
        Theme.reset()
    }
}
