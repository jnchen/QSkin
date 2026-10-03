/****************************************************************************
 * QSkin · Quick Design System — Theme / shadcn
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * shadcn/ui 主题的唯一入口。用法：
 *
 *     import QSkin.Theme.Shadcn 1.0
 *     Component.onCompleted: Shadcn.apply()
 *     ...
 *     Shadcn.remove()
 ****************************************************************************/

pragma Singleton
import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

import "tokens.js" as Tokens
import "slots"

QtObject {
    id: root

    property string name:  "shadcn"
    property var    light: Tokens.light
    property var    dark:  Tokens.dark

    property Component scButtonBackground: Component { SCButtonBackground { } }
    property Component scLabel:            Component { SCLabel { } }
    property Component scInputBackground:  Component { SCInputBackground { } }
    property Component scCheckIndicator:   Component { SCCheckIndicator { } }
    property Component scSelectOverlay:    Component { SCSelectOverlay { } }
    property Component scTabIndicator:     Component { SCTabIndicator { } }
    /* 方向箭头（展开 / 折叠 / 翻页）。indicator 家族里「展开箭头」那一格
     * 此前一直是空的（谁要用谁自己画），这里补齐。契约见
     * slots/BasicChevronIndicator.qml 文件头。 */
    property Component scChevronIndicator:  Component { SCChevronIndicator { } }

    /* 加载指示器的形态（M19）。这一格是四家里形态差异最大的一处 ——
     * 弧长/段数/线宽规则各不相同，没有一个能被令牌表达。 */
    property Component scSpinRing: Component { SCSpinRing { } }

    /* 单选框的圆环（M20）。与 Ant 同为描边策略，但圆心更大（10 vs 8）——
     * 两个数不同就值得两份实现，理由见 slots/SCRadioIndicator.qml。 */
    property Component scRadioIndicator: Component { SCRadioIndicator { } }

    /* 开关底板（M20）。四家主题里**唯一**覆盖这一格的一份 ——
     * shadcn 的开关打开时不用品牌色，而是"另一种灰"
     * （`data-[state=on]:bg-accent`），理由与对照表见
     * slots/SCToggleBackground.qml 文件头。 */
    property Component scToggleBackground: Component { SCToggleBackground { } }

    /* 语义状态记号（M22）。四家主题里**唯一**覆盖这一格的一份 ——
     * 前三家（Ant / TDesign / Arco）都是实心圆盘 + 反白记号，
     * 与 Basic 同形；shadcn 的 lucide 是描边圆环 + 同色记号，
     * 而且 warning **是三角**（triangle-alert）。分歧在形态上，
     * 令牌表达不了，所以只有它需要第二份实现。
     * 与 scToggleBackground 的情形同源（那一格也只有 shadcn 覆盖）。
     * 完整论证见 slots/SCStatusGlyph.qml 与 BasicStatusGlyph.qml 文件头。 */
    property Component scStatusGlyph: Component { SCStatusGlyph { } }

    function apply() {
        Theme.install(root, root.name)
        Slots.install({
            buttonBackground: root.scButtonBackground,
            label:            root.scLabel,
            inputBackground:  root.scInputBackground,
            checkIndicator:   root.scCheckIndicator,
            selectOverlay:    root.scSelectOverlay,
            tabIndicator:     root.scTabIndicator,
            chevronIndicator: root.scChevronIndicator,
            spinRing:    root.scSpinRing,
            radioIndicator: root.scRadioIndicator,
            toggleBackground: root.scToggleBackground,
            statusGlyph:  root.scStatusGlyph
        })
    }

    function remove() {
        Slots.reset()
        Theme.reset()
    }
}
