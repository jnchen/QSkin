/****************************************************************************
 * QSkin · 宿主对账场景（C++ / PySide6 / qml 三宿主共用）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ── 这个文件回答什么问题 ────────────────────────────────────────────────
 * 「QSkin 是纯 QML 库，C++ 和 PySide6 都能直接用」这句话的**可证伪版本**是：
 *
 *      同一个库，在 C++ 宿主与 PySide6 宿主下，
 *      qmldir 声明的每一个公开类型都能被实例化、每一个单例都能被取到。
 *
 * 抓几张图只能证明"画出来的那几个能用"；这里遍历的是 **qmldir 的全集**
 * （清单由 `tests/ContractManifest.js` 提供，它由 qmldir 生成、漂移即红）。
 *
 * ── 为什么三种宿主跑**同一个**这个文件 ──────────────────────────────────
 * 只要宿主能把 QML 跑起来，本文件就自己做完检查、自己打印结果、自己
 * `Qt.exit(code)`。对账逻辑住在 QML 里 ⇒ **宿主之间不存在"测的不是同一件事"
 * 的空间**。宿主只负责：起引擎 → 加 import 路径 → 加载本文件 → exec()。
 *
 * ── 输出协议（宿主侧解析这个）──────────────────────────────────────────
 *      PARITY <key> <value>
 *  key ∈ { host, resolved, total, ok, fail, failList, singles, tokens, shot }
 *  退出码：0 = 全部通过；非 0 = 失败个数（上限 125）
 *
 * ── 两条判据，为什么是两条而不是一条 ────────────────────────────────────
 *  qmldir 里**不只有对外控件**：`TimeCell` / `FloatPlate` 这类内部件注册进
 *  qmldir 只为同目录能按名使用（见各自文件头），它们要么有 required property
 *  要 delegate 喂、要么要有宿主控件喂 —— **裸实例化必然失败，且那是设计如此**。
 *
 *  于是只留一条「全部能实例化」就会把设计当缺陷报；只留一条「全部能解析」
 *  又测不到"控件能不能真的 new 出来"。所以：
 *      L1a 可解析     —— 全集，用惰性 `Component { T {} }`，不真实例化
 *      L1b 可裸实例化 —— 公开类型（排除内部件）
 *
 * ── 三条设计约定（改之前先读）──────────────────────────────────────────
 * ① 根节点必须是 **Window**（不是 Item）：Item 作根时事件循环起不来、
 *    Timer 永不触发，整个流程静默停摆（M12 实录，被看门狗杀掉才知道）。
 * ② 抓图区 **canvas** 必须自己铺底：`grabToImage` 只抓这一棵子树，
 *    不铺底就是透明图（HelloIcons.qml:103 同款坑）。
 * ③ 自证文字用 **原生 Text / Rectangle**，不用 QSkin 自己的控件 ——
 *    被测对象不能同时当测量工具，否则控件一坏，连报错都显示不出来。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Window 2.15
import "ContractManifest.js" as Manifest  /* 类型清单，由 qmldir 生成 */

Window {
    id: win
    width: 900
    height: 620
    visible: true
    color: "#FFFFFF"

    property bool shotMode: true

    /* 默认 "qml" —— `qml` 运行器没法注入属性，就用这个默认值；
       C++ / PySide6 宿主通过 setInitialProperties 覆盖成 "cpp" / "pyside6"。 */
    property string hostTag: "qml"

    /* `Qt.createQmlObject` 的返回类型是 QObject，qmllint 会按它做成员检查、
       于是 `comp.status` 报 missing-property。落进 `property var` 再访问就
       没有这层检查 —— 与 FloatPlate.qml「用 var 而不是 Item」同款处理。 */
    property var probe: null

    /* ── 统计（画面与 stdout 都从这里读，保证两处永远一致）────────────── */
    property int total: 0
    property int okCount: 0
    property int failCount: 0
    property int resolvedCount: 0
    property int resolvedTotal: 0
    property string failText: ""
    property string themeText: ""
    property string tokenText: ""

    /* 被实例化的对象都挂在这里；父容器不可见 ⇒ 不会真的弹出窗口 */
    Item {
        id: dump
        visible: false
    }

    /* ── 抓图区：显式白底 ──────────────────────────────────────────────── */
    Item {
        id: canvas
        x: 0
        y: 0
        width: 900
        height: 620

        Rectangle {
            anchors.fill: parent
            color: "#FFFFFF"
        }

        /* ⚠ 标题**不能**写 hostTag：三张图要逐像素比对，而 hostTag 本来
           就三个值 —— 写进去等于给每张图种下必然的差异，比对就失去意义。
           宿主标识走 stdout（PARITY host）与输出文件名，不进画面。 */
        Text {
            id: title
            x: 16
            y: 12
            text: "QSkin 三宿主对账"
            font.pixelSize: 18
            color: "#111111"
        }

        Text {
            id: lineResolve
            x: 16
            y: 42
            text: "L1a 可解析     " + win.resolvedCount + "/" + win.resolvedTotal
            font.pixelSize: 15
            color: win.resolvedCount === win.resolvedTotal ? "#1B7F3B" : "#C0392B"
        }

        Text {
            id: lineInstant
            x: 16
            y: 68
            text: "L1b 可实例化   " + win.okCount + "/" + win.total
            font.pixelSize: 15
            color: win.okCount === win.total ? "#1B7F3B" : "#C0392B"
        }

        Text {
            id: lineStat
            x: 16
            y: 94
            text: "失败 " + win.failCount
            font.pixelSize: 15
            color: win.failCount === 0 ? "#1B7F3B" : "#C0392B"
        }

        Text {
            id: lineTheme
            x: 16
            y: 122
            text: "单例 " + win.themeText
            font.pixelSize: 14
            color: "#333333"
        }

        Text {
            id: lineToken
            x: 16
            y: 146
            text: "令牌 " + win.tokenText
            font.pixelSize: 14
            color: "#333333"
        }

        /* 失败名单（最多显示 10 行，完整名单走 stdout）*/
        Text {
            id: lineFail
            x: 16
            y: 178
            width: parent.width - 32
            wrapMode: Text.Wrap
            text: win.failText
            font.pixelSize: 12
            color: "#C0392B"
        }

        /* 底部自证条：核验器用它确认「图确实画出来了」而不是空白 */
        Rectangle {
            x: 0
            y: parent.height - 24
            width: parent.width
            height: 24
            color: "#2B6CB0"
        }
    }

    Component.onCompleted: run()

    function emit(k, v) {
        console.log("PARITY " + k + " " + v)
    }

    function shortErr(e, n) {
        var s = ("" + e).replace(/\s+/g, " ")
        return s.length > n ? s.slice(0, n) : s
    }

    function run() {
        emit("host", hostTag)
        /* Qt 版本**不在这里报**：宿主才知道自己链接了哪个 Qt
           （C++ 用 qVersion()、PySide6 用 QtCore.qVersion()），
           由宿主侧打进 PARITY qt —— 比 QML 侧猜的版本准。 */

        var fails = []

        /* ── L1a · 每一个类型都必须能**被解析** ────────────────────────
         * `Component { T {} }` 是**惰性**的：它解析类型但不实例化。
         * 于是「类型不存在」与「类型存在但缺上下文」被分开了。 */
        var all = Manifest.allTypePairs || []
        var resolved = 0
        for (var i = 0; i < all.length; i++) {
            var rsrc = 'import QtQuick 2.15; import ' + all[i].uri + ' 1.0; Component { '
                       + all[i].name + ' { } }'
            probe = null
            try {
                probe = Qt.createQmlObject(rsrc, dump, "res_" + all[i].name)
            } catch (e1) {
                probe = null
            }
            if (probe && probe.status === Component.Ready) {
                resolved++
                probe.destroy()
            } else {
                fails.push("resolve:" + all[i].name)
            }
        }
        resolvedCount = resolved
        resolvedTotal = all.length
        emit("resolved", resolved + "/" + all.length)

        /* ── L1b · 每一个**公开**类型都必须能**裸实例化** ───────────── */
        var pub = Manifest.publicTypePairs || []
        var ok = 0
        for (var j = 0; j < pub.length; j++) {
            var src = 'import QtQuick 2.15; import ' + pub[j].uri + ' 1.0; '
                      + pub[j].name + ' { }'
            var obj = null
            var err = ""
            try {
                obj = Qt.createQmlObject(src, dump, "inst_" + pub[j].name)
            } catch (e2) {
                err = shortErr(e2, 80)
            }
            if (obj) {
                ok++
                obj.destroy()          /* 立刻回收：105 个对象没必要留着 */
            } else {
                fails.push("instantiate:" + pub[j].name + "(" + err + ")")
            }
        }
        total = pub.length
        okCount = ok
        failCount = fails.length
        failText = fails.length ? fails.slice(0, 10).join("  ") : "（无失败）"
        emit("total", total)
        emit("ok", okCount)
        emit("fail", failCount)
        emit("failList", fails.join(" | "))

        /* ── L2 · 单例可取 + 主题令牌可读 ───────────────────────────── */
        var spairs = Manifest.allSinglePairs || []
        var sok = 0
        for (var k = 0; k < spairs.length; k++) {
            var ssrc = 'import QtQuick 2.15; import ' + spairs[k].uri
                       + ' 1.0; QtObject { property var v: ' + spairs[k].name + ' }'
            var sobj = null
            try {
                sobj = Qt.createQmlObject(ssrc, dump, "parity_s_" + spairs[k].name)
            } catch (e3) {
                sobj = null
            }
            if (sobj && sobj.v !== undefined && sobj.v !== null) {
                sok++
                sobj.destroy()
            } else {
                fails.push("singleton:" + spairs[k].name)
            }
        }
        themeText = sok + "/" + spairs.length
        emit("singles", sok + "/" + spairs.length)

        /* 主题令牌：走 Foundation 的 Theme 单例 */
        var tsrc = 'import QtQuick 2.15; import QSkin.Foundation 1.0; QtObject { property var t: Theme }'
        var tobj = null
        try {
            tobj = Qt.createQmlObject(tsrc, dump, "parity_theme")
        } catch (e4) {
            tobj = null
        }
        if (tobj && tobj.t) {
            var T = tobj.t
            tokenText = "name=" + T.themeName
                + " color=" + (T.color ? "Y" : "N")
                + " space=" + (T.space ? "Y" : "N")
                + " radius=" + (T.radius ? "Y" : "N")
                + " font=" + (T.font ? "Y" : "N")
                + " size=" + (T.size ? "Y" : "N")
                + " motion=" + (T.motion ? "Y" : "N")
            emit("tokens", tokenText)
            emit("themeName", T.themeName)
        } else {
            tokenText = "Theme 单例取不到"
            failCount = failCount + 1
            emit("tokens", "NULL")
        }

        emit("done", "1")

        if (shotMode) {
            shotTimer.start()
        } else {
            Qt.exit(failCount > 125 ? 125 : failCount)
        }
    }

    Timer {
        id: shotTimer
        interval: 900
        repeat: false
        onTriggered: {
            var base = Qt.resolvedUrl("../.cache/").toString().replace("file:///", "")
            var name = "host_parity_" + win.hostTag + ".png"
            canvas.grabToImage(function (res) {
                var okSave = res.saveToFile(base + name)
                emit("shot", okSave ? name : "SAVE_FAIL")
                Qt.exit(failCount > 125 ? 125 : failCount)
            })
        }
    }
}
