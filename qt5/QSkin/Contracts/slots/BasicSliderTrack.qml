/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicSliderTrack
 *
 * 「indicator」插槽 —— 滑块的轨道、已滑过区与手柄。
 *
 * 与开关同一个设计考量（见 BasicSwitchIndicator 文件头）：滑块的
 * 视觉语义（轨道多粗、手柄是圆是方、已滑过区用不用品牌色）在
 * 各设计系统里差异巨大，但它读的状态是同一组 ——
 * control.position（0~1 视觉位置）/ hovered / pressed / enabled。
 *
 * 手柄位移只在**非拖拽**时走动画：拖拽过程中动画会给手柄"追不上
 * 鼠标"的迟滞感，Ant Design 也只在释放后回弹。Behavior 的 enabled
 * 绑到 control.pressed 上，拖拽期间动画即时关闭。
 *
 * 注意：轨道自身只有视觉，不含任何交互 —— 命中与取值是宿主控件
 * （QSkinSlider）MouseArea 的职责，插槽不许引入交互（契约三条之三）。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    /* 轨道高度语义由插槽自己决定 —— 主题把手柄做大做小时，
     * 只需要改这个文件，宿主的行高（controlSm）不受影响 */
    implicitHeight: Theme.size.controlSm
    height: implicitHeight

    readonly property int trackH:      4
    readonly property int handleSize:  12

    function pos()      { return root.control && root.control.position !== undefined
                               ? root.control.position : 0 }
    function disabled() { return root.control ? root.control.enabled === false : false }
    function hovered()  { return root.control ? root.control.hovered  === true  : false }
    function pressed()  { return root.control ? root.control.pressed  === true  : false }

    /* ── 轨道（未滑过区） ── */

    Rectangle {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        width:  root.width
        height: root.trackH
        radius: root.trackH / 2

        color: root.disabled() ? Theme.color.bgSubtle : Theme.color.bgSunken
    }

    /* ── 已滑过区 ── */

    Rectangle {
        id: fill

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        width:  d.fillW()
        height: root.trackH
        radius: root.trackH / 2

        color: root.disabled() ? Theme.color.border
                              : (root.pressed() ? Theme.color.brandActive : Theme.color.brand)

        Behavior on color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    /* ── 手柄 ── */

    Rectangle {
        id: handle

        width:  root.handleSize
        height: root.handleSize
        radius: root.handleSize / 2

        y: (root.height - root.handleSize) / 2
        x: d.handleX()

        color:        root.disabled() ? Theme.color.bgSubtle   : Theme.color.bgElevated
        border.width: 1
        border.color: d.handleBorder()

        /* 拖拽时即时跟随，释放/键盘步进时回弹 —— 见文件头 */
        Behavior on x {
            enabled: !root.pressed()
            NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    QtObject {
        id: d

        function fillW() {
            return Math.max(0, Math.min(root.width, root.pos() * root.width))
        }

        function handleX() {
            return Math.max(0, Math.min(root.width - root.handleSize,
                                        root.pos() * (root.width - root.handleSize)))
        }

        function handleBorder() {
            if (root.disabled()) return Theme.color.border
            if (root.pressed())  return Theme.color.brandActive
            if (root.hovered())  return Theme.color.brandHover
            return Theme.color.brand
        }
    }
}
