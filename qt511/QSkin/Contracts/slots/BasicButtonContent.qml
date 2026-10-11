/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicButtonContent
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「contentItem」插槽的 Basic 默认实现 —— 图标 + 文字的排布。
 *
 * 这里只决定「图标在左还是右、两者间距多少」，不决定文字长什么样：
 * 文字交给 label 插槽。原因是同一套 contentItem 排布在四套主题里基本通用，
 * 而字重 / 字号每套都不一样 —— 拆开之后主题只需要替换 label。
 *
 * ── 为什么不在这里直接写 Slots.label ──────────────────────────────────
 * slots/ 与它所在的模块根目录互相引用会形成模块内循环依赖。
 * 所以插槽之间的组合关系统一由 Slots.qml 在声明处接线：
 *     Component { BasicButtonContent { labelDelegate: root.label } }
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

/* 用 QSkinRow 而不是 Row：本文件属于 QSkin.Contracts 模块，同时 import 了
 * QtQuick 和 QSkin.Foundation。
 *
 * M23 实测（`.cache/_probe_m23row.qml`）：**那时**这种文件里的裸名 `Row` 会
 * 解析成 `QSkin.Foundation.Row`（有 `gap`、没有 `spacing`）—— 所以它不是
 * "撞名报错"，而是**静默地拿到了另一个类型**。想拿 QtQuick 那个原生
 * positioner 得写别名 import（`import QtQuick 2.15 as QQ` 然后 `QQ.Row`；
 * 直接写 `QtQuick.Row` 会报 "QtQuick is neither a type nor a namespace"）。
 *
 * ⚠ **M29 更新**：`foundation/qmldir` 已去掉双名注册，裸 `Row` 现在稳定地
 * 指 QtQuick 的 positioner，歧义消失（改名理由见该 qmldir 与
 * `CMakeLists.txt` 的模块头）。上面那段实测记录**保留** —— 它是当年的事实，
 * 也是这次改名的起因。
 *
 * 这里本来就要 QSkin 那一份（行布局 + gap/padding），但**写全名 QSkinRow**
 * 而不是靠 import 顺序 —— 后者"太脆弱"（foundation/qmldir 原话）。
 * 这一句与 M29 无关，现在依然成立。 */
QSkinRow {
    id: root

    property var control: null

    /** label 插槽，由 Slots.qml 注入 */
    property Component labelDelegate: null

    /** 图标插槽，由 QSkinButton 注入（见 QSkinButton.icon 的注释）。
     *  为 null 时退回 Image + control.iconSource 那条老路。 */
    property Component iconDelegate: null

    gap: Theme.space.xs
    padding: 0
    align: "center"

    Image {
        id: icon

        visible: root.iconDelegate === null
                 && root.control
                 && root.control.iconSource !== undefined
                 /* 这里**故意**用宽松比较 `!=`，不要"顺手"改成 `!==`：
                  * iconSource 是 url 型，交给 JS 的是 QUrl 对象，
                  * `url !== ""` 恒为 true（QSkinEmpty 因此丢过整张插图，
                  * 实测见 QSkinEmpty 文件头）。宽松比较会走一次隐式转换，
                  * 是这两种写法里真正有效的那一种。 */
                 && root.control.iconSource != ""

        source: root.control ? root.control.iconSource : ""
        sourceSize.width:  root.control ? root.control.iconSize : 16
        sourceSize.height: root.control ? root.control.iconSize : 16
    }

    /* 画出来的图标。宿主不是按钮本身，而是一个**伪装成控件**的代理 ——
     * 与 QSkinTable 的表头 hcell、QSkinPagination 的 totalCtl 同一套约定：
     * 图标插槽（见 chevronIndicator）只认 direction / enabled 这几个
     * 名字，而按钮那边的属性叫 iconDirection，名字对不上，所以这里翻译。 */
    Loader {
        id: iconLoader

        sourceComponent: root.iconDelegate
        visible: root.iconDelegate !== null

        Binding {
            target: iconLoader.item
            property: "control"
            value: iconProxy
            when: iconLoader.item !== null
        }
    }

    QtObject {
        id: iconProxy

        readonly property string direction: root.control
                                            && root.control.iconDirection !== undefined
                                            ? String(root.control.iconDirection) : "down"
        readonly property bool enabled: root.control
                                        && root.control.enabled !== undefined
                                        ? root.control.enabled === true : true
        readonly property bool hovered: root.control
                                        && root.control.hovered !== undefined
                                        ? root.control.hovered === true : false
    }

    /* 用 Binding 注入，不用 onLoaded 回调 —— 理由见 QSkinButton.qml 同名注释。 */
    Loader {
        id: labelLoader

        sourceComponent: root.labelDelegate

        Binding {
            target: labelLoader.item
            property: "control"
            value: root.control
            when: labelLoader.item !== null
        }
    }
}
