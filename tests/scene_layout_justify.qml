/****************************************************************************
 * QSkin · 布局像素核验场景（M29）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 用法（由 tools/check-layout-pixels.sh 驱动，一般不用手跑）：
 *     ./tools/shot.sh tests/scene_layout_justify.qml theme=ant
 *     python tools/check-layout-pixels.py .cache/m29_layout_ant.png
 *
 * ── 为什么要有这个文件 ──────────────────────────────────────────────────
 *
 * `smoke_layout.qml` / `smoke_layout_gap.qml` / `smoke_layout_justify.qml`
 * 全是**属性侧**的门 —— 读的是 `x` / `y` / `width`。而本项目的原话是
 * **"属性值对 ≠ 界面画对"**（M27 的 `QSkinKbd` 就是属性门与冒烟全绿、
 * 只有抓图能看见）。布局这一层在 M29 之前**一道像素门都没有**。
 *
 * ── 场景怎么设计的（核验器依赖这些约定，改之前先读）──────────────────────
 *
 * ① **根节点必须是 QSkinWindow（Window）**。Item 作根节点时事件循环起不来、
 *    Timer 永不触发，整个抓图静默停摆（被 shot.sh 的看门狗杀掉）。M12 实录。
 * ② **锚条**（`anchorBar`，4px 高的实心条）横跨容器的完整宽度。核验器
 *    **先量它**，得到"容器在图里的 x 范围"，于是所有落点判据都是**相对
 *    量出来的容器**，而不是相对写死的坐标。
 * ③ 三档 justify 各占一行，**颜色完全相同**（`#2B6CB0`）。核验器按 y 分档，
 *    不靠颜色区分 —— 颜色一致也让"自校准取前景参考色"更稳。
 * ④ 每行的三枚色块都是 **40×40**、容器 **580** 宽、gap **8**。
 *    于是内容宽 = 3×40 + 2×8 = 136，三档的组左沿分别是
 *    0 / (580−136)/2 = 222 / 580−136 = 444。
 * ⑤ 最后一行是**原生 `RowLayout`**，同配置。它是反证：Qt 会把余量摊进间距，
 *    于是它的"间隙"远大于 8。没有这一行，前三行的绿可能只是"读了个 0"。
 * ⑥ 自证文字放在画面最底部，扫描行不会经过它。
 *
 * ── 为什么不接主题 ──────────────────────────────────────────────────────
 * 这里被测量的东西是**纯几何**（余量怎么分、间隙多宽），QSkinRow 的分配
 * 逻辑一个主题令牌都不读。所以本场景**一个主题模块都不 import**：
 *   · 画面自带白底与固定色块，核验器又拿"本行众数色"当背景参考 ——
 *     整条链上没有一处依赖配色；
 *   · 于是也不需要 `theme=` 这类命令行参数。**那玩意儿在 `qml` 运行器下
 *     会被当成第二个要加载的文件**（实测报
 *     `theme=ant: No such file or directory`），场景会加载失败而
 *     qml 仍然返回 0 —— 典型静默失败。
 * 主题相关的渲染由 `shot_*.qml` 那一族各管一段。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

QSkinWindow {
    id: win

    width: 700
    height: 480
    visible: true

    /* 抓图区：显式白底，坐标从 (0,0) 算起 */
    Item {
        id: canvas
        x: 0
        y: 0
        width: 700
        height: 480

        Rectangle { anchors.fill: parent; color: "#FFFFFF" }

        /* ── 锚条：核验器据此量出容器范围 ── */
        Rectangle {
            id: anchorBar
            x: 30; y: 10
            width: 580; height: 4
            color: "#2B6CB0"
        }

        /* ── [0] start（默认）→ 组贴左沿，余量留在末端 ── */
        QSkinRow {
            id: rStart; x: 30; y: 40; width: 580; height: 40; gap: 8
            Rectangle { width: 40; height: 40; color: "#2B6CB0" }
            Rectangle { width: 40; height: 40; color: "#2B6CB0" }
            Rectangle { width: 40; height: 40; color: "#2B6CB0" }
        }

        /* ── [1] center → 组居中，左侧空 222 ── */
        QSkinRow {
            id: rCenter; x: 30; y: 110; width: 580; height: 40; gap: 8
            justify: "center"
            Rectangle { width: 40; height: 40; color: "#2B6CB0" }
            Rectangle { width: 40; height: 40; color: "#2B6CB0" }
            Rectangle { width: 40; height: 40; color: "#2B6CB0" }
        }

        /* ── [2] end → 组贴右沿，左侧空 444 ── */
        QSkinRow {
            id: rEnd; x: 30; y: 180; width: 580; height: 40; gap: 8
            justify: "end"
            Rectangle { width: 40; height: 40; color: "#2B6CB0" }
            Rectangle { width: 40; height: 40; color: "#2B6CB0" }
            Rectangle { width: 40; height: 40; color: "#2B6CB0" }
        }

        /* ── [3] 反证：原生 RowLayout，同配置 ──
         * 子项**只能**写 implicit 尺寸，写 width/height 会被 qmllint 报
         * "Detected width on an item managed by a layout"。 */
        RowLayout {
            id: rRaw; x: 30; y: 250; width: 580; height: 40; spacing: 8
            Rectangle { implicitWidth: 40; implicitHeight: 40; color: "#2B6CB0" }
            Rectangle { implicitWidth: 40; implicitHeight: 40; color: "#2B6CB0" }
            Rectangle { implicitWidth: 40; implicitHeight: 40; color: "#2B6CB0" }
        }

        /* ── 自证：人看图能直接核对，不必反推 ── */
        Text {
            id: report
            x: 30
            y: 330
            width: 580
            wrapMode: Text.WordWrap
            text: ""
            font.pixelSize: 14
            color: "#333333"
        }
    }

    function describe() {
        return "场景：QSkinRow 余量分配 · 容器 580 / 3×40 / gap 8\n"
             + "锚条 x ∈ [30, 610)  宽 580\n"
             + "start / center / end 的组左沿应为 0 / 222 / 444（相对容器）\n"
             + "三档的间隙都应是 8；最后一行原生 RowLayout 的间隙远大于 8（反证）"
    }

    Component.onCompleted: {
        report.text = win.describe()
    }

    Timer {
        interval: 1200
        running: true
        onTriggered: {
            /* 输出到项目根的 .cache/ —— 不要把产物丢进 tests/ */
            var base = Qt.resolvedUrl("..").toString().replace("file:///", "") + "/.cache/"
            var out  = base + "m29_layout.png"
            canvas.grabToImage(function(res) {
                Qt.exit(res.saveToFile(out) ? 0 : 9)
            })
        }
    }
}
