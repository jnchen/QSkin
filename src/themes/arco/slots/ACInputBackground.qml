/****************************************************************************
 * QSkin · Quick Design System — Theme / Arco Design / slots / ACInputBackground
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * Arco Design 的输入框底板 —— **三套主题里唯一起手就是灰底的**。
 *
 *   常态   #F2F3F5 灰底（color-fill-2）+ 无描边
 *   hover  底色微降 / 描边 #C9CDD4
 *   聚焦   **变白**（color-bg-white）+ 边框透明 + 3px 品牌光晕
 *   错误   白底 + 红描边 + 红光晕
 *   禁用   fill-1 浅灰 + 无描边
 *
 * 有趣的是：Basic 的「下沉常态、聚焦提亮」映射恰好就是这个**形状** ——
 * 但 Arco 的灰是 fill 语义（#F2F3F5），不是 Basic 的 sunken（#F0F0F4），
 * 数值和语义都对不上。独立插槽把对应关系写明，而不是偷懒复用 Basic
 * 让灰色去「将就」—— 这就是插槽层的价值：形状相同，语义各自声明。
 ****************************************************************************/

/* QtQuick **不带版本号**：四角独立半径（topLeftRadius 等）在版本化导入下
 * 不存在 —— 实测 2.15 / 2.16 / 2.17 全报 "is not available"。完整实测与
 * 理由见 COVERAGE.md 第七节「M27 裁决四」；第一个用户是 ACButtonBackground。
 * M30 的输入框底板是第二个用户（分组圆角），同一条。 */
import QtQuick
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    anchors.fill: parent

    Rectangle {
        id: halo

        anchors.fill:    parent
        anchors.margins: -3        // Arco 的光晕是 3px，比 Ant/TD 宽一档
        /* 光晕层跟着主体走 —— 不同步会让聚焦环在分组的内侧角上"支出来" */
        readonly property var _haloCorners:
            CornerUtil.corners(d.groupPosition(), Theme.radius.md + 3)

        topLeftRadius:      _haloCorners.tl
        topRightRadius:     _haloCorners.tr
        bottomRightRadius:  _haloCorners.br
        bottomLeftRadius:   _haloCorners.bl

        color:        "transparent"
        border.width: 3
        border.color: d.haloColor()

        visible:  d.showHalo()
        opacity:  d.showHalo() ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    Rectangle {
        id: field

        anchors.fill: parent
        readonly property var _corners: CornerUtil.corners(d.groupPosition(), Theme.radius.md)

        topLeftRadius:      _corners.tl
        topRightRadius:     _corners.tr
        bottomRightRadius:  _corners.br
        bottomLeftRadius:   _corners.bl

        color:        d.bg()
        border.width: d.borderWidth()
        border.color: d.borderColor()

        Behavior on color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }

    QtObject {
        id: d

        /* M30 · 分组方位。由父项（QSkinInputGroup）上报。
         * 没设 groupPosition 的消费者拿到 "standalone" → 四角全等 →
         * 与本件加这个字段之前**逐字相同**。 */
        function groupPosition() {
            return (root.control && root.control.groupPosition !== undefined)
                    ? root.control.groupPosition : "standalone"
        }

        function disabled() { return root.control ? root.control.enabled === false : false }
        function focused()  { return root.control ? root.control.activeFocus === true : false }
        function hovered()  { return root.control ? root.control.hovered === true : false }
        function error()    { return root.control ? root.control.error === true : false }

        function showHalo() {
            if (disabled() || error()) return error()
            return focused()
        }

        function haloColor() {
            return Theme.color.focusHalo
        }

        /* ★ 常态灰底（color-fill-2），聚焦才变白（Arco 招牌） */
        function bg() {
            if (disabled()) return Theme.color.bgSubtle
            if (focused() || error()) return Theme.color.bgElevated
            if (hovered()) return Theme.color.fillHover
            return Theme.color.bgSunken
        }

        function borderWidth() {
            /* Arco 输入框常态无描边；聚焦/错误用描边强表达 */
            return (focused() || error()) ? 1 : 0
        }

        function borderColor() {
            if (error())    return Theme.color.danger
            if (focused())  return Theme.color.brand
            return "transparent"
        }
    }
}
