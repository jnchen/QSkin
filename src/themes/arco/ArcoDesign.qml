/****************************************************************************
 * QSkin · Quick Design System — Theme / Arco Design
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Arco Design 主题的唯一入口。用法：
 *
 *     import QSkin.Theme.ArcoDesign 1.0
 *     Component.onCompleted: ArcoDesign.apply()
 *     ...
 *     ArcoDesign.remove()
 ****************************************************************************/

pragma Singleton
import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

import "tokens.js" as Tokens
import "slots"

QtObject {
    id: root

    property string name:  "ArcoDesign"
    property var    light: Tokens.light
    property var    dark:  Tokens.dark

    property Component acButtonBackground: Component { ACButtonBackground { } }
    property Component acLabel:            Component { ACLabel { } }
    property Component acInputBackground:  Component { ACInputBackground { } }
    property Component acCheckIndicator:   Component { ACCheckIndicator { } }
    property Component acSelectOverlay:    Component { ACSelectOverlay { } }
    property Component acTabIndicator:     Component { ACTabIndicator { } }
    /* 方向箭头（展开 / 折叠 / 翻页）。indicator 家族里「展开箭头」那一格
     * 此前一直是空的（谁要用谁自己画），这里补齐。契约见
     * slots/BasicChevronIndicator.qml 文件头。 */
    property Component acChevronIndicator:  Component { ACChevronIndicator { } }

    /* 加载指示器的形态（M19）。这一格是四家里形态差异最大的一处 ——
     * 弧长/段数/线宽规则各不相同，没有一个能被令牌表达。 */
    property Component acSpinDots: Component { ACSpinDots { } }

    function apply() {
        Theme.install(root, root.name)
        Slots.install({
            buttonBackground: root.acButtonBackground,
            label:            root.acLabel,
            inputBackground:  root.acInputBackground,
            checkIndicator:   root.acCheckIndicator,
            selectOverlay:    root.acSelectOverlay,
            tabIndicator:     root.acTabIndicator,
            chevronIndicator: root.acChevronIndicator,
            spinDots:    root.acSpinDots
        })
    }

    function remove() {
        Slots.reset()
        Theme.reset()
    }
}
