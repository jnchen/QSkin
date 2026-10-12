/****************************************************************************
 * QSkin · Quick Design System — Theme / TDesign / slots / TDInputBackground
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * TDesign 的输入框底板。
 *
 * ── 这个文件解释了一类「令牌解决不了」的问题 ──────────────────────────
 * Basic 实现写的是：**常态用 bgSunken（下沉），聚焦才提亮。**
 * 而 TDesign 恰恰相反：输入框常态是**白色**（--td-bg-color-specialcomponent），
 * 深色主题下甚至是 transparent —— 它靠描边而不是底色来划边界。
 *
 * 能不能只改令牌解决？把 TDesign 的 bgSunken 也设成白色就行了，
 * 但 bgSunken 还被代码块、表格表头等其它地方共用，一改全塌。
 * **同一个令牌在不同控件里语义不同** —— 这正是必须开插槽的典型场景。
 *
 * ── TDesign 输入框的三态 ────────────────────────────────────────────────
 *   常态   白底 + 1px #DCDCDC（--td-component-border）
 *   hover  描边变品牌色 #0052D9
 *   聚焦   描边变品牌色 + 2px 外发光 #D9E1FF（--td-brand-color-focus）
 *   错误   描边变 #D54941 + 2px 外发光 #FFF0ED
 *   禁用   底 #EEEEEE（--td-bg-color-component-disabled）+ 描边 #E7E7E7
 *
 * 优先级：error > disabled > focus > hover > 常态
 * （错误态优先级高于禁用：已经标红的校验失败不该因为禁用就消失。）
 *
 * 外发光用什么画：官方是 box-shadow 0 0 0 2px。QML 没有 box-shadow，
 * 这里用一个向外扩 2px 的空心圆角矩形近似。没有走 DropShadow /
 * MultiEffect —— 它们要额外模块，最小化安装的 Qt 未必带。
 ****************************************************************************/

/* QtQuick **不带版本号**：四角独立半径（topLeftRadius 等）在版本化导入下
 * 不存在 —— 实测 2.15 / 2.16 / 2.17 全报 "is not available"。完整实测与
 * 理由见 COVERAGE.md 第七节「M27 裁决四」；第一个用户是 TDButtonBackground。
 * M30 的输入框底板是第二个用户（分组圆角），同一条。 */
import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    anchors.fill: parent

    /* ── 外发光 ──
     * 声明在 field 之前 —— QML 按声明顺序绘制，先声明的在下层。
     * anchors.margins 为负，让它比输入框大出一圈 2px。 */
    Rectangle {
        id: halo

        anchors.fill:    parent
        anchors.margins: -2
        /* 光晕层跟着主体走 —— 不同步会让聚焦环在分组的内侧角上"支出来" */
        readonly property var _haloCorners:
            CornerUtil.corners(d.groupPosition(), Theme.radius.md + 2)

        /* Qt 5.11：_corners 是函数调用属性，5.11 在它返回前
         * 就求值 radius ⇒ ReferenceError。守卫挡不住（读属性就抛）。
         * 正解：自己算一次放进一个 QtObject，后续都从它取。*/
        QtObject { id: _c511_0; property var v: CornerUtil.corners(d.groupPosition(), Theme.radius.md + 2) }
        radius: _c511_0.v ? Math.max(_c511_0.v.tl, _c511_0.v.tr, _c511_0.v.br, _c511_0.v.bl) : 0
        /* Qt 5.15 无四角独立半径（topLeftRadius 等是 Qt 6 独有，且只在
         * 「无版本 import」下才存在 —— 原注释有实测记录）。
         * 降级：主体取四角最大值，再用补角矩形把该直的角填回方形。
         * 已知差异：补角会盖掉一小段 border，而那正是分组按钮与相邻
         * 按钮的接缝；standalone（四角全等）与中段（四角全零）两种
         * 情形与 Qt 6 侧逐像素一致。 */
        Rectangle { visible: _c511_0.v.tl < radius; x: 0; y: 0; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _c511_0.v.tr < radius; x: parent.width - radius; y: 0; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _c511_0.v.br < radius; x: parent.width - radius; y: parent.height - radius; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _c511_0.v.bl < radius; x: 0; y: parent.height - radius; width: radius; height: radius; color: parent.color }

        color:        "transparent"
        border.width: 2
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

    /* ── 输入框本体 ── */
    Rectangle {
        id: field

        anchors.fill: parent
        readonly property var _corners: CornerUtil.corners(d.groupPosition(), Theme.radius.md)

        /* Qt 5.11：_corners 是函数调用属性，5.11 在它返回前
         * 就求值 radius ⇒ ReferenceError。守卫挡不住（读属性就抛）。
         * 正解：自己算一次放进一个 QtObject，后续都从它取。*/
        QtObject { id: _c511_1; property var v: CornerUtil.corners(d.groupPosition(), Theme.radius.md) }
        radius: _c511_1.v ? Math.max(_c511_1.v.tl, _c511_1.v.tr, _c511_1.v.br, _c511_1.v.bl) : 0
        /* Qt 5.15 无四角独立半径（topLeftRadius 等是 Qt 6 独有，且只在
         * 「无版本 import」下才存在 —— 原注释有实测记录）。
         * 降级：主体取四角最大值，再用补角矩形把该直的角填回方形。
         * 已知差异：补角会盖掉一小段 border，而那正是分组按钮与相邻
         * 按钮的接缝；standalone（四角全等）与中段（四角全零）两种
         * 情形与 Qt 6 侧逐像素一致。 */
        Rectangle { visible: _c511_1.v.tl < radius; x: 0; y: 0; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _c511_1.v.tr < radius; x: parent.width - radius; y: 0; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _c511_1.v.br < radius; x: parent.width - radius; y: parent.height - radius; width: radius; height: radius; color: parent.color }
        Rectangle { visible: _c511_1.v.bl < radius; x: 0; y: parent.height - radius; width: radius; height: radius; color: parent.color }

        color:        d.bg()
        border.width: 1
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
            if (disabled()) return false
            return focused() || error()
        }

        function haloColor() {
            return error() ? Theme.color.dangerSubtle : Theme.color.focusHalo
        }

        /* ★ 常态白底（--td-bg-color-specialcomponent）。
         *   深色下令牌给的是 bgElevated(#242424)，与官方 transparent 略有差别：
         *   transparent 会让输入框完全融进卡片，这里保留一层容器色，
         *   否则输入框与卡片之间没有边界。 */
        function bg() {
            if (disabled()) return Theme.color.bgSubtle
            return Theme.color.bgElevated
        }

        function borderColor() {
            if (error())    return Theme.color.danger
            if (disabled()) return Theme.color.border
            if (focused())  return Theme.color.brand
            if (hovered())  return Theme.color.brand
            return Theme.color.borderStrong
        }
    }
}
