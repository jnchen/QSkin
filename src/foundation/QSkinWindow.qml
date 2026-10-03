/****************************************************************************
 * QSkin · Quick Design System — Foundation / QSkinWindow
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 应用窗口基类。它只做两件"每次都要写、又最容易漏"的事：
 *
 *   1. 把窗口宽度接进 Breakpoints，让整个应用可以直接用
 *      Breakpoints.compact / .medium / .expanded 做响应式判断
 *   2. 把窗口底色接到 Theme.color.bg，换主题时窗口底色自动跟着变
 *
 * 用法：
 *     QSkinWindow {
 *         width: 1024; height: 720
 *         title: "我的应用"
 *         ...
 *     }
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Window 2.15

Window {
    id: root

    color: Theme.color.bg

    Component.onCompleted: Breakpoints.attach(root)
}
