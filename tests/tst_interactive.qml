/****************************************************************************
 * QSkin · 真鼠标事件交互测试（qmltestrunner）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 与 smoke_*.qml 的分工：
 *   smoke_*：程序化调属性/调函数，断言契约逻辑 —— 退出码位掩码回传。
 *   本文件 ：Qt Quick Test 注入**真实鼠标/键盘事件**，端到端验证
 *            「事件 → 状态机 → 插槽视觉」整条链路真的接通了。
 *
 * 由来：M8 收尾时抓图工具卡死，留下一个画了第一帧但事件循环停摆的
 * 假窗口，用户点上去毫无反应，怀疑「交互没接上」。本文件就是自动化
 * 的回答：hover 会变状态也会变色、点击会发信号、键盘能激活。
 *
 * 运行（offscreen 平台，无窗口，CI 友好）：
 *   .qt/6.8.3/mingw_64/bin/qmltestrunner.exe \
 *       -platform offscreen -I .cache/qmlimports tests/interactive_basic.qml
 *
 * 注意：.qmltest 文件名带 tst_ 前缀才会被 qmltestrunner 自动发现；
 * 本项目改用显式传文件路径的方式，命名保持 interactive_* 与 smoke_*
 * 并列，同时避免被 tools/test.sh 的 find tests -name "smoke_*" 误扫。
 ****************************************************************************/

import QtQuick 2.15
import QtTest
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root
    width: 480
    height: 340

    /* ── 被测控件：一个关注点一个按钮，测试互不污染 ───────────────── */

    QSkinButton {
        id: hoverBtn
        text: "主要按钮"
        variant: "primary"
        x: 24; y: 24
    }

    QSkinButton {
        id: clickBtn
        text: "点我"
        x: 24; y: 88
    }

    QSkinButton {
        id: pressBtn
        text: "按住"
        x: 24; y: 152
    }

    QSkinButton {
        id: toggleBtn
        text: "可切换"
        checkable: true
        x: 200; y: 24
    }

    QSkinCheckBox {
        id: cb
        text: "记住我"
        x: 200; y: 88
    }

    QSkinButton {
        id: disBtn
        text: "禁用"
        enabled: false
        x: 200; y: 152
    }

    QSkinButton {
        id: keyBtn
        text: "键盘"
        x: 360; y: 24
    }

    QSkinSwitch {
        id: sw
        text: "开关"
        x: 360; y: 88
    }

    /* ── M9 新增：Slider 拖拽 / InputNumber 步进器 ── */

    QSkinSlider {
        id: dragSlider
        width: 180
        x: 24; y: 216
        from: 0; to: 100
    }

    QSkinInputNumber {
        id: num
        x: 240; y: 216
        min: 0; max: 10; step: 1; value: 3
    }

    /* ── 信号哨兵 ─────────────────────────────────────────────── */

    SignalSpy { id: hoverClickedSpy;  target: hoverBtn;  signalName: "clicked" }
    SignalSpy { id: clickSpy;         target: clickBtn;  signalName: "clicked" }
    SignalSpy { id: toggleSpy;        target: toggleBtn; signalName: "toggled" }
    SignalSpy { id: cbClickedSpy;     target: cb;        signalName: "clicked" }
    SignalSpy { id: disSpy;           target: disBtn;    signalName: "clicked" }
    SignalSpy { id: keySpy;           target: keyBtn;    signalName: "clicked" }
    SignalSpy { id: swSpy;            target: sw;        signalName: "toggled" }
    SignalSpy { id: movedSpy;         target: dragSlider; signalName: "moved" }
    SignalSpy { id: numSpy;           target: num;       signalName: "valueModified" }

    TestCase {
        name: "InteractiveBasic"
        when: windowShown

        /* 找按钮背景插槽实例（Loader 里那个 Rectangle）。
         * 只扫 children —— 非视觉 QtObject 不在 children 里，
         * 天然避开 M8 踩过的「QtObject 伪装件」坑。
         * FocusRing 也是带 control 的 Rectangle，用 thickness 排除。 */
        function findBg(item, host) {
            var kids = item.children
            for (var i = 0; i < kids.length; ++i) {
                var k = kids[i]
                if (k.control === host && k.color !== undefined
                        && k.thickness === undefined)
                    return k
                var r = findBg(k, host)
                if (r) return r
            }
            return null
        }

        /* ── 1. hover：状态机 + 视觉双验证 ─────────────────────────── */

        function test_hover_state_and_visual() {
            mouseMove(root, 5, 330)              // 先挪走，保证初始无 hover
            wait(Theme.motion.fast + 50)
            compare(hoverBtn.hovered, false)

            var bg = findBg(hoverBtn, hoverBtn)
            verify(!!bg, "找不到背景插槽实例")
            verify(Qt.colorEqual(bg.color, Theme.color.brand),
                   "常态应为 brand 色，实际 " + bg.color)

            // 挪到按钮中心 → hovered 置位，底色滑到 brandHover
            mouseMove(hoverBtn, hoverBtn.width / 2, hoverBtn.height / 2)
            tryCompare(hoverBtn, "hovered", true)
            tryVerify(function() {
                return Qt.colorEqual(bg.color, Theme.color.brandHover)
            }, 5000, "hover 后底色应为 brandHover，实际 " + bg.color)

            // 挪走 → 复原
            mouseMove(root, 5, 330)
            tryCompare(hoverBtn, "hovered", false)
            tryVerify(function() {
                return Qt.colorEqual(bg.color, Theme.color.brand)
            })
        }

        /* ── 2. 点击：信号 + 状态 ─────────────────────────────────── */

        function test_click_fires_signal() {
            clickSpy.clear()
            mouseClick(clickBtn, clickBtn.width / 2, clickBtn.height / 2,
                       Qt.LeftButton)
            tryCompare(clickSpy, "count", 1)
            compare(clickBtn.checked, false, "非 checkable 不应置 checked")

            mouseClick(clickBtn, clickBtn.width / 2, clickBtn.height / 2,
                       Qt.LeftButton)
            tryCompare(clickSpy, "count", 2)
        }

        /* ── 3. 按压：pressed 时序 + 按下态视觉 ───────────────────── */

        function test_press_states() {
            var bg = findBg(pressBtn, pressBtn)
            verify(!!bg)

            mousePress(pressBtn, pressBtn.width / 2, pressBtn.height / 2,
                       Qt.LeftButton)
            compare(pressBtn.pressed, true)
            tryVerify(function() {
                return Qt.colorEqual(bg.color, Theme.color.bgSunken)
            }, 5000, "按下应为 bgSunken，实际 " + bg.color)

            mouseRelease(pressBtn, pressBtn.width / 2, pressBtn.height / 2,
                         Qt.LeftButton)
            compare(pressBtn.pressed, false)
        }

        /* ── 4. checkable 按钮：点击切换 + toggled 信号 ───────────── */

        function test_checkable_toggle() {
            toggleSpy.clear()
            compare(toggleBtn.checked, false)

            mouseClick(toggleBtn, toggleBtn.width / 2, toggleBtn.height / 2)
            tryCompare(toggleBtn, "checked", true)
            tryCompare(toggleSpy, "count", 1)

            mouseClick(toggleBtn, toggleBtn.width / 2, toggleBtn.height / 2)
            tryCompare(toggleBtn, "checked", false)
            tryCompare(toggleSpy, "count", 2)
        }

        /* ── 5. 复选框：框可点，文字也是热区 ─────────────────────── */

        function test_checkbox_text_hotzone() {
            cbClickedSpy.clear()
            compare(cb.checked, false)

            // 点方框
            mouseClick(cb, 8, cb.height / 2)
            tryCompare(cb, "checked", true)
            tryCompare(cbClickedSpy, "count", 1)

            // 点文字右缘 —— 热区必须盖住文字，这是桌面端体感底线
            mouseClick(cb, cb.width - 4, cb.height / 2)
            tryCompare(cb, "checked", false)
            tryCompare(cbClickedSpy, "count", 2)
        }

        /* ── 6. 禁用：点击必须无效 ───────────────────────────────── */

        function test_disabled_blocks_input() {
            disSpy.clear()
            mouseClick(disBtn, disBtn.width / 2, disBtn.height / 2)
            wait(100)
            compare(disSpy.count, 0, "禁用按钮不应发出 clicked")
        }

        /* ── 7. 键盘：Enter / Space 都能激活 ─────────────────────── */

        function test_keyboard_activation() {
            keySpy.clear()
            keyBtn.forceActiveFocus()
            verify(keyBtn.activeFocus)

            keyClick(Qt.Key_Return)
            tryCompare(keySpy, "count", 1)

            keyClick(Qt.Key_Space)
            tryCompare(keySpy, "count", 2)
        }

        /* ── 8. 开关：轨道可点，文字也是热区（M9）───────────────── */

        function test_switch_click() {
            swSpy.clear()
            compare(sw.checked, false)

            // 点轨道左端
            mouseClick(sw, 8, sw.height / 2)
            tryCompare(sw, "checked", true)
            tryCompare(swSpy, "count", 1)

            // 点文字右缘 —— 热区必须盖住文字
            mouseClick(sw, sw.width - 4, sw.height / 2)
            tryCompare(sw, "checked", false)
            tryCompare(swSpy, "count", 2)
        }

        /* ── 9. 滑块：按住拖拽取值（M9）────────────────────────── */

        function test_slider_drag() {
            dragSlider.value = 0
            movedSpy.clear()
            compare(dragSlider.pressed, false)

            // 按在轨道左端 → 立即取该点值
            mousePress(dragSlider, 10, dragSlider.height / 2, Qt.LeftButton)
            compare(dragSlider.pressed, true)
            verify(dragSlider.value > 0, "按下即应取值，实际 " + dragSlider.value)

            // 拖到中点 → 值 50（180 宽，x=90 → 0.5）
            mouseMove(dragSlider, 90, dragSlider.height / 2)
            mouseRelease(dragSlider, 90, dragSlider.height / 2, Qt.LeftButton)
            compare(dragSlider.pressed, false)
            tryCompare(dragSlider, "value", 50)
            verify(movedSpy.count > 0, "拖拽过程应持续发 moved")
        }

        /* ── 10. 数字输入：步进器点击 + 键盘方向键（M9）────────── */

        function test_inputnumber_steppers() {
            numSpy.clear()
            tryCompare(num, "value", 3)

            // 点步进器上半（增）
            mouseClick(num, num.width - 12, num.height * 0.25)
            tryCompare(num, "value", 4)
            tryCompare(numSpy, "count", 1)

            // 点步进器下半（减）
            mouseClick(num, num.width - 12, num.height * 0.75)
            tryCompare(num, "value", 3)
            tryCompare(numSpy, "count", 2)

            // 点文本区拿到焦点 → ↑ 键步进
            mouseClick(num, 20, num.height / 2)
            keyClick(Qt.Key_Up)
            tryCompare(num, "value", 4)
            tryCompare(numSpy, "count", 3)
        }
    }
}
