import QtQuick 2.11
import QtQuick.Window 2.2
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0

// 深色场景抓图 —— 用来验「深色下这一帧到底画没画」。
//
// ⚠ 为什么单独做这个场景：本项目的原话是「**无头抓图只跑浅色场景就等于没跑**」
//   —— M18.1 就是自动化全绿、人工开窗才看见深色下按钮没画底色
//   （`Unable to assign [undefined] to QColor`）。
//   而 examples/HelloThemes.qml 里 dark 的**真代码是0 行**（只有注释提到），
//   所以那27 页抓图**一张深色都没有**。这个场景补上这块。
Window {
    id: win
    visible: true
    width: 520
    height: 300

    // ⚠⚠ **第一句**就切深色 + 装主题 —— 必须早于任何子项创建，
    //   且 `apply()` 不可省：插槽（文字/描边/底板全靠它）在没 apply 时是**空的**。
    //   实测漏了 apply 的后果 = **所有文字都不画**（浅色也一样），
    //   而引擎**零报错** —— 纯静默的视觉缺陷，只能从图里看出来。
    Component.onCompleted: {
        TDesign.apply()
        Theme.mode = "dark"
    }

    // 深色底：深色令牌出错时这里会露出底色本身（一眼可见）
    Rectangle {
        anchors.fill: parent
        color: Theme.color.bg
    }

    Column {
        id: col
        anchors.centerIn: parent
        spacing: Theme.space.md

        // 三种状态的按钮：静止 / hover / disabled
        // ⚠ disabled 是最容易被令牌门漏掉的一档
        Row {
            spacing: Theme.space.sm

            QSkinButton { text: "深色按钮"; objectName: "btnNormal" }
            QSkinButton {
                text: "悬停"
                objectName: "btnHover"
                hovered: true
            }
            QSkinButton {
                text: "禁用"
                objectName: "btnDisabled"
                enabled: false
            }
        }

        // 输入框：聚焦光晕在深色下最容易露馅
        QSkinInput {
            objectName: "inputDark"
            width: 280
            placeholderText: "深色输入框"
        }

        // 带圆角的标签 + 开关：验证四角半径降级在深色下的补角
        Row {
            spacing: Theme.space.sm

            QSkinTag { text: "深色标签"; closable: true }
            QSkinSwitch { objectName: "switchDark"; checked: true }
        }
    }

    // ── 自证行：单独放在图**左下角** ──
    //
    // ⚠ 为什么挪出 Column：判据 ⑥ 要按区域单独量「这行文字画没画」。
    //   放在 Column 末尾时它与标签/开关共用一条横条（量到 118 种色，
    //   把 DARKPROBE 清空也只降到 3 种 —— 阈值根本分不开）。
    //   放进一个**独立底色的方块**之后，那一块的像素只可能来自它自己。
    Rectangle {
        id: probeBox
        x: 16
        y: parent.height - height - 16
        width: 200
        height: 28
        color: Theme.color.bgSunken
        border.width: 1
        border.color: Theme.color.divider

        Text {
            anchors.centerIn: parent
            objectName: "probeLabel"
            text: "DARKPROBE"
            color: Theme.color.fg
            font.pixelSize: Theme.font.md
        }
    }

    // 抓图：等主题与插槽装好再抓
    Timer {
        running: true
        interval: 900
        onTriggered: win.contentItem.grabToImage(function (res) {
            res.saveToFile(Qt.resolvedUrl("../.cache/qt511_dark.png"))
            Qt.exit(0)
        })
    }
}
