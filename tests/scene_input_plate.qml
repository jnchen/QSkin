/****************************************************************************
 * QSkin · 输入底板像素核验场景（M31）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 用法（由 tools/check-input-plate-pixels.sh 驱动，一般不用手跑）：
 *     ./tools/shot.sh tests/scene_input_plate.qml
 *     python tools/check-input-plate-pixels.py .cache/m31_plate.png
 *
 * ── 为什么要有这个文件 ──────────────────────────────────────────────────
 *
 * M30 给输入底板加了两件绘制：**分组圆角**（first/middle/last 的四个角
 * 各自不同）与**聚焦/报错光晕**（外扩 2px 的一圈）。属性侧的门
 * （`tests/smoke_m30_theme.qml` 的 [2]~[4]）读的是插槽 `Rectangle` 的
 * `topLeftRadius` 等四个属性 —— 它证明的是"**我设了这些值**"。
 *
 * 本项目的原话是「**属性值对 ≠ 界面画对**」（已撞七次）。这里要证明的是
 * 那四个值**真的被画成了那个形状**：
 *
 *   · `CornerUtil.corners` 的键名（tl/tr/br/bl）与插槽的
 *     `topLeftRadius`… 是否真的对上了 —— 写错一格的症状是**镜像**
 *     （四个数字全对、属性全对、界面全错）。属性门读的就是那个结果，
 *     所以它与被测量**共享同一份假设**；像素门不共享。
 *   · `halo` 的 `anchors.margins: -2` 是否真的画到了字段**外面**，
 *     以及它的**四角是否跟着主体走**（`_haloCorners`）—— 属性读得出
 *     `visible: true`，读不出这两件事。
 *
 * ── 场景约定（核验器里有一份同样的表，改一边必须改两边）────────────────
 *
 *   画布 900×520，衬底 `#3C3C3C` 深灰（**刻意与字段白拉开**：圆角切掉的
 *   那一小块要露出衬底，判据才能量到"这里没东西"）
 *
 *   | 组 | 件         | x   | y   | w   | h  | 期望                     |
 *   |----|------------|-----|-----|-----|----|--------------------------|
 *   | A  | 分组 first  | 60  | 60  | 200 | 40 | 左两角圆、右两角方       |
 *   | A  | 分组 middle | 260 | 60  | 200 | 40 | 四角方                   |
 *   | A  | 分组 last   | 460 | 60  | 200 | 40 | 右两角圆、左两角方       |
 *   | B  | standalone  | 60  | 160 | 200 | 40 | 四角圆（半径的实测来源） |
 *   | C  | error       | 60  | 260 | 200 | 40 | 外圈光晕，四角圆         |
 *   | C  | 常态对照    | 320 | 260 | 200 | 40 | 外圈是衬底               |
 *   | D  | 分组 first  | 60  | 360 | 200 | 40 | （不判角：见下）         |
 *   | D  | 分组 middle | 260 | 360 | 200 | 40 | error → 方角 + 方角光晕  |
 *   | D  | 分组 last   | 460 | 360 | 200 | 40 | （不判角：见下）         |
 *
 *   A 组与 D 组的 first/last 是**同一个绘制机制**（[2][3] 已在 A 组判过），
 *   D 组存在的唯一目的是拿一枚**方角主体 + 光晕**的件，与 C 组那枚
 *   **圆角主体 + 光晕**的件成对 —— 光晕的四角跟着主体走这件事，只有
 *   这样一正一反地量才**不会"永远为真"**（见核验器 [7]）。
 *
 * ── 为什么只跑一档主题（ant）────────────────────────────────────────────
 *
 * 核验器判的是**方向性的结构事实**（哪几个角是圆的），半径的**数值**
 * 由属性门在五档主题上守（`smoke_m30_theme` [2][3] 逐档读插槽属性）。
 * 而"半径数值 → 弧度"这一跳是**插槽的绘制机制**，不随主题变 ——
 * 所以一档足够证明它通了。
 * 选 ant 的理由：它 radius.md=6，是四家里最大的，弧最可辨。
 * ⚠ 代价（如实记）：**核验器 [1]~[4] 的阈值 2 是按 ant 的 r=6 实测标定的**
 *   （实测圆角侧 3~5、方角侧恒 0）。若将来让本场景跑更多主题，
 *   那个阈值必须重测，不能直接搬 —— 尤其 TDesign 的 r=3。
 *
 * ── 为什么 Link 的下划线**不**在这里 ────────────────────────────────────
 *
 * 下划线是 `Text.underline`，Qt 直接绘制的，中间没有映射层 ——
 * 属性侧读插槽 `Text` 的 `font.underline` **就是绘制指令本身**，
 * 与像素判据等价，而它有 `smoke_m30_theme` 那份门守。详见
 * `tools/check-input-plate-pixels.py` 文件头「已知未覆盖」那一节。
 *
 * ── 为什么衬底是写死的深灰，而不是读主题令牌 ────────────────────────────
 *
 * 与 `tests/scene_layout_justify.qml` 同一条：核验器拿**全图众数色**当
 * 背景参考，它不关心那个色是怎么来的。写死一个与字段色拉开距离的值，
 * 比"跟着主题走"更稳（换主题时衬底不会反过来贴近字段色而让判据失效）。
 *
 * ── 为什么光晕用 error 触发，而不是 focus ──────────────────────────────
 *
 * `showHalo()` = `focused() || error()`，两者都行。选 error：
 *   · 它是**普通属性**，可以静态设死 —— 不依赖 offscreen 平台能否给到
 *     `activeFocus`（那是一条环境相关的通路，会让门在别的机器上静默失效）；
 *   · ant 的 error 光晕色 `dangerSubtle` 是**不透明**的 `#FFF1F0`，
 *     比半透明的 `focusHalo`（`#1A0591FF`）好量一个数量级。
 ****************************************************************************/

import QtQuick
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.AntDesign 1.0

QSkinWindow {
    id: win

    width: 900
    height: 520
    visible: true

    /* 抓图区：衬底 + 全部夹具。坐标从 (0,0) 算起（核验器按此折回逻辑像素）。 */
    Item {
        id: canvas
        x: 0
        y: 0
        width: 900
        height: 520

        Rectangle { anchors.fill: parent; color: "#3C3C3C" }

        /* ── A 组：分组三枚（紧邻，spacing 恒 0），圆角由方位决定 ── */
        QSkinInputGroup {
            id: grp
            x: 60; y: 60
            width: 600; height: 40
            QSkinInput { id: gFirst; width: 200; height: 40 }
            QSkinInput { id: gMid;   width: 200; height: 40 }
            QSkinInput { id: gLast;  width: 200; height: 40 }
        }

        /* ── B 组：孤立那枚，四角全圆。核验器拿它的角当"半径的实测值" ── */
        QSkinInput { id: solo; x: 60;  y: 160; width: 200; height: 40 }

        /* ── C 组：光晕的一正一反。error 那枚四角是**圆**的 ── */
        QSkinInput { id: err;  x: 60;  y: 260; width: 200; height: 40; error: true }
        QSkinInput { id: norm; x: 320; y: 260; width: 200; height: 40 }

        /* ── D 组：中间那枚是 error，而 middle 的四角是**方**的。
         * 于是它的光晕也必须是方的 —— 否则光晕会在角上"支出来"
         * （M30 给 ADInputBackground 写的那句注释说的正是这个）。── */
        QSkinInputGroup {
            id: grp2
            x: 60; y: 360
            width: 600; height: 40
            QSkinInput { id: hFirst; width: 200; height: 40 }
            QSkinInput { id: hMid;   width: 200; height: 40; error: true }
            QSkinInput { id: hLast;  width: 200; height: 40 }
        }

        /* ── 自证：人看图能直接核对，扫描行不会经过它（y >= 450）── */
        Text {
            id: report
            x: 60
            y: 450
            width: 780
            wrapMode: Text.WordWrap
            color: "#D0D0D0"
            font.pixelSize: 13
            text: ""
        }
    }

    function describe() {
        return "场景：输入底板绘制（M31）· 衬底 #3C3C3C / 字段白\n"
             + "A 分组 first/middle/last @ x=60/260/460，各 200×40，y=60\n"
             + "B standalone @ (60,160) · C error @ (60,260) / 常态 @ (320,260)\n"
             + "D 分组（中间那枚 error）@ y=360\n"
             + "A 组方位：" + [gFirst.groupPosition, gMid.groupPosition, gLast.groupPosition].join(" / ")
             + " · D 组方位：" + [hFirst.groupPosition, hMid.groupPosition, hLast.groupPosition].join(" / ")
             + " · radius.md=" + Theme.radius.md
    }

    Component.onCompleted: {
        /* 先应用主题，再写自证行 —— 否则自证里的 radius.md 是地基默认值 */
        AntDesign.apply()
        report.text = win.describe()
    }

    Timer {
        interval: 1500          /* 覆盖 apply() 引发的 color 动画（motion.fast=120） */
        running: true
        repeat: false
        onTriggered: {
            /* 产物写进项目根的 .cache/ —— 不要把图丢进 tests/ */
            var base = Qt.resolvedUrl("..").toString().replace("file:///", "") + "/.cache/"
            var out  = base + "m31_plate.png"
            canvas.grabToImage(function(res) {
                Qt.exit(res.saveToFile(out) ? 0 : 9)
            })
        }
    }
}
