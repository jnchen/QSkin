/****************************************************************************
 * QSkin · Quick Design System — Foundation / Spacer
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 弹性占位 —— 对应 Web 里的 `flex: 1`，用来把右侧内容顶到末端。
 *
 * 为什么需要单独一个类型：
 *   Row / Column / Grid 内部用的是 QtQuick.Layouts，想让某个子项撑开剩余
 *   空间，得写 `Layout.fillWidth: true` —— 而这要求**使用方的文件**也 import
 *   了 QtQuick.Layouts。那是地基的内部实现，不该泄漏给业务代码。
 *
 *   Spacer 把这个 import 收在自己内部，业务只写 `Spacer { }`。
 *
 * 用法（把主题切换按钮推到行尾）：
 *     Row {
 *         fill: true              // ⚠ 不是 width: parent.width —— 见下
 *         Heading { text: "标题" }
 *         Spacer { }
 *         Button { text: "切换" }
 *     }
 *
 * ⚠ 本文件原先的示例写的是 `width: parent.width` —— **那是错的**，而且是
 *   本组件最讽刺的一种错法：一个专门用来"撑开剩余空间"的组件，示例里
 *   那行根本没生效（Layouts 用 implicitWidth 作 size hint，显式 width
 *   被静默忽略），于是 Row 退化成 hug、Spacer 没有空间可占、按钮也没被
 *   推到行尾，而**没有任何报错**。正确的写法是 `fill: true`。
 *   这个坑的完整说明在 QSkinRow.qml 文件头，门是 tests/smoke_layout.qml [0]-[7]。
 *
 * 注意：只在 Row / Column / Grid 内有效；放进普通 Item 里它就是一个 0×0 的空项。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Layouts 1.11

Item {
    id: root

    /** 主轴方向撑满剩余空间（Row 里是横向，Column 里是纵向） */
    property bool fillWidth: true

    /** 交叉轴方向撑满；一般保持 false */
    property bool fillHeight: false

    /** 需要占位的最小尺寸，默认 0（纯粹弹性） */
    property int minSize: 0

    Layout.fillWidth:  root.fillWidth
    Layout.fillHeight: root.fillHeight
    Layout.minimumWidth:  root.fillWidth  ? root.minSize : 0
    Layout.minimumHeight: root.fillHeight ? root.minSize : 0
}
