/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinRate
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 评分（星星）。
 *
 * ── 这一件**没有**新增插槽，理由要写清楚 ────────────────────────────────
 * 前三件（Radio / Textarea / Label）都指得出一个格子：Radio 需要一格
 * "选中怎么填"，Textarea 复用 inputBackground，Label 复用 label。
 * Rate 没有 —— 四家的星星在**形态上完全一致**（正五角、外接圆占满方框、
 * 未选中同样是实心星只是颜色淡），差异只剩两个颜色，而颜色是令牌能
 * 表达的东西。按项目那条判据「只差颜色 → 复用」：**不新增插槽是对的**。
 *
 * 代价要说明：这等于承认"星形是控件的知识"。如果将来某家要做
 * 心形 / 表情 / 半星用描边，那时再补一格 `rateIcon` 插槽 —— 到那时
 * 它才是一格真格子，而不是提前为想象中的差异留的空位。
 *
 * ── 星形用矢量、不用 ✩ ──────────────────────────────────────────────────
 * U+2605 / U+2606 的覆盖率在 Linux / 嵌入式上不稳（项目规矩「图标不用
 * 字符」的原始理由），所以星形是一条 10 个点的闭合路径，画在**固定的
 * 20×20 坐标空间**里，再由外层 `scale` 缩到实际尺寸。
 * 固定坐标空间是必要的：`ShapePath` 的顶点是**静态声明**，没法按
 * `starSize` 现算 —— 而按 starSize 算 PathLine 正是最容易出"半颗星偏
 * 0.5px"的地方，不如让缩放矩阵去做。
 *
 * ── 半星 = 裁剪，不是"画一半的路径"──────────────────────────────────────
 * `allowHalf` 的实现是一条 `clip: true` 的窄矩形盖在实心星上，宽度 =
 * `20 × frac`。这样 0 / 0.5 / 1 三种状态共用**同一条路径**，半星必然是
 * 精确的一半 —— 而"另外生成一条半个星的路径"会在两个版本之间产生
 * 一条肉眼看不见、但一放大就露馅的缝。
 ****************************************************************************/

import QtQuick 2.11
import QtQuick.Shapes 1.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 当前分值。写入时会被**吸附**到步长上（allowHalf 时是 0.5）。 */
    property real value: 0

    /** 一共几颗星。 */
    property int count: 5

    /** 允许半星。 */
    property bool allowHalf: false

    /** 只读（展示用）。只读时没有 hover 预览，鼠标也不变手型。 */
    property bool readOnly: false

    /** 再点一次当前分值能否清零。 */
    property bool allowClear: true

    signal ratingChanged(real value)

    /* ══════════════════════ 外观 ══════════════════════ */

    /** sm | md | lg 或像素数。 */
    property var size: "md"

    /** 已点亮的星的颜色。 */
    property color color: Theme.color.warning

    /** 未点亮的星的颜色。**也是实心**，只是淡 —— 与四家一致。
     *  想要"空心描边"的观感就把它设成 bg，星形仍在（只是看不见），
     *  而那正是"看不见的占位"该有的样子。 */
    property color emptyColor: Theme.color.bgSunken

    /** 星间距 */
    property int gap: Theme.space.xs

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property int starSize:
        typeof root.size === "number" ? Math.max(8, Math.round(root.size))
      : root.size === "sm" ? 16
      : root.size === "lg" ? 24
                           : 20

    /** 一颗星占的横向步长 —— 像素核验量的就是它。 */
    readonly property int step: root.starSize + root.gap

    readonly property real stepValue: root.allowHalf ? 0.5 : 1

    readonly property real snapped: root._snap(root.value)

    /** 悬停预览值。-1 = 没有预览（**默认值**：不读物理鼠标位置，
     *  否则抓图的结果会随鼠标停在哪而变，见 M19 教训）。 */
    property real hoverValue: -1

    /** 实际画出来的分值 */
    readonly property real display:
        root.hoverValue >= 0 ? root._snap(root.hoverValue) : root.snapped

    readonly property bool isEmpty: root.snapped <= 0

    implicitWidth:  root.count > 0
                    ? root.starSize * root.count + root.gap * (root.count - 1) : 0
    implicitHeight: root.starSize

    width:  implicitWidth
    height: implicitHeight

    /* 交互时可聚焦 + 键盘：←/→ 走一格，Home/End 到两端。
     * 只读时不占 Tab 位（它没有可操作的东西）。 */
    activeFocusOnTab: !root.readOnly
    /* 只报 role / name：Qt 6.8 的 Accessible 附加类型里没有可用的
     * value / minimumValue / maximumValue（qmllint 报 missing-property）。
     * 宁可少报一个数值，也不要为一个门禁认不出的属性开 lint 豁免 ——
     * 豁免是给"已知误报"用的，这里的报是对的：那个属性确实不存在。 */
    Accessible.role:      Accessible.Slider
    Accessible.name:      qsTr("评分，共 %1 星，当前 %2").arg(root.count).arg(root.snapped)

    /* ══════════════════════ 排布 ══════════════════════ */

    Repeater {
        model: root.count
        delegate: starComp
    }

    // qmllint disable unqualified
    Component {
        id: starComp

        Item {
            id: starCell

            property int index

            x: starCell.index * root.step
            width:  root.starSize
            height: root.starSize

            /** 这一颗点亮了几成（0 / 0.5 / 1） */
            readonly property real frac:
                Math.max(0, Math.min(1, root.display - starCell.index))

            /* 画在固定的 20×20 坐标空间里，再整体缩到 starSize。
             * 星是**填充**的、没有描边，所以缩放不会让线宽失真。 */
            Item {
                id: art

                width:  20
                height: 20
                scale:  root.starSize / 20
                transformOrigin: Item.TopLeft

                /* ── 底星（未点亮）── */
                Shape {
                    anchors.fill: parent
                    ShapePath {
                        fillColor:   root.emptyColor
                        strokeColor: "transparent"
                        startX: 10;    startY: 0
                        PathLine { x: 12.245; y: 6.910  }
                        PathLine { x: 19.511; y: 6.910  }
                        PathLine { x: 13.633; y: 11.181 }
                        PathLine { x: 15.878; y: 18.090 }
                        PathLine { x: 10;     y: 13.820 }
                        PathLine { x: 4.122;  y: 18.090 }
                        PathLine { x: 6.367;  y: 11.181 }
                        PathLine { x: 0.489;  y: 6.910  }
                        PathLine { x: 7.755;  y: 6.910  }
                        PathLine { x: 10;     y: 0      }
                    }
                }

                /* ── 已点亮：同一路径，被裁到 frac ── */
                Rectangle {
                    width:  20 * starCell.frac
                    height: 20
                    color:  "transparent"
                    clip:   true

                    Shape {
                        anchors.fill: parent
                        ShapePath {
                            fillColor:   root.color
                            strokeColor: "transparent"
                            startX: 10;    startY: 0
                            PathLine { x: 12.245; y: 6.910  }
                            PathLine { x: 19.511; y: 6.910  }
                            PathLine { x: 13.633; y: 11.181 }
                            PathLine { x: 15.878; y: 18.090 }
                            PathLine { x: 10;     y: 13.820 }
                            PathLine { x: 4.122;  y: 18.090 }
                            PathLine { x: 6.367;  y: 11.181 }
                            PathLine { x: 0.489;  y: 6.910  }
                            PathLine { x: 7.755;  y: 6.910  }
                            PathLine { x: 10;     y: 0      }
                        }
                    }
                }
            }
        }
    }
    // qmllint enable unqualified

    FocusRing { control: root }

    /* ══════════════════════ 交互 ══════════════════════ */

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        enabled: !root.readOnly
        cursorShape: root.readOnly ? Qt.ArrowCursor : Qt.PointingHandCursor

        onExited: root.hoverValue = -1

        onPositionChanged: function(mouse) {
            root.hoverValue = root._valueAt(mouse.x)
        }

        onPressed: function(mouse) {
            if (mouse.button !== Qt.LeftButton) return
            root.forceActiveFocus()
            var v = root._valueAt(mouse.x)
            root._commit(v)
        }
    }

    /* 信号参数必须写成 function(event)，否则 qmllint 报 Unqualified access */
    Keys.onLeftPressed:  function(event) { event.accepted = true; root._commit(root.snapped - root.stepValue) }
    Keys.onRightPressed: function(event) { event.accepted = true; root._commit(root.snapped + root.stepValue) }
    /* Home / End 没有对应的 onXPressed 信号（Keys 只为一小部分键提供了
     * 便利处理器），所以它们必须在 onPressed 里按 key 判。 */
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Home) {
            event.accepted = true
            root._commit(0)
        } else if (event.key === Qt.Key_End) {
            event.accepted = true
            root._commit(root.count)
        }
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    function _clamp(v) {
        return Math.max(0, Math.min(root.count, v))
    }

    function _snap(v) {
        var s = root.stepValue
        return root._clamp(Math.round(v / s) * s)
    }

    /** 鼠标横坐标 → 分值。落在一颗星的**中缝左边**就是半颗。 */
    function _valueAt(x) {
        var i = Math.floor(x / root.step)
        i = Math.max(0, Math.min(root.count - 1, i))
        var within = (x - i * root.step) / root.starSize
        if (root.allowHalf && within < 0.5)
            return i + 0.5
        return i + 1
    }

    function _commit(v) {
        if (root.readOnly) return
        var snapped = root._snap(v)
        /* 点同一个值 = 清零（allowClear）。Ant / TDesign 都有这个行为：
         * 打错的分数必须能撤回来，否则用户只能改成一个"不是它的分"。 */
        if (root.allowClear && snapped === root.snapped && snapped > 0)
            snapped = 0
        if (snapped === root.value) return
        root.value = snapped
        root.ratingChanged(root.value)
    }

    /** 第 i 颗星点亮了几成。**公开给属性侧与像素核验用** ——
     *  两边量的是同一个数，于是"属性对而界面错"无处可藏。 */
    function fracAt(i) {
        return Math.max(0, Math.min(1, root.display - i))
    }
}
