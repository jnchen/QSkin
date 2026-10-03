/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinWatermark
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 水印 —— 把一段淡淡的文字按固定倾角平铺满整块区域，压在内容之上。
 *
 * ── 它为什么是这一批里**最容易做对、也最容易测**的一件（M27 裁决二）──
 * 水印不承载交互、不参与布局、不影响任何状态。它要测的东西**全是几何**：
 * 步长、偏移、倾角，以及"格点之间必须是空的"。
 *
 * 于是它不走"看起来对不对"这条路，走**自校准**（M26 那条无阈值的判据）：
 *   ① 对每一个**按公式算出来的**格点，断言该点附近有墨；
 *   ② 对格点之间的**中点**，断言没有墨。
 * ① 单独可以被"画了一整块灰"满足，② 单独可以被"什么都没画"满足 ——
 * 两条一起才说明"网格真的按那个步长铺开了"。
 *
 * ── 内容怎么进来 ──────────────────────────────────────────────────────
 * 默认属性直通 host 的 data，所以用法就是"把要被盖住的东西放进去"：
 *
 *     QSkinWatermark {
 *         text: "CONFIDENTIAL"
 *         QSkinImage { ... }          // ← 进 host，被水印盖住
 *     }
 *
 * ── 三条**刻意不做**的（M27 裁决二的裁剪）────────────────────────────
 *   · 图片水印（Ant 的 `image` 档）—— 本批不需要，且它会把"位图平铺"
 *     与"文字平铺"两套几何塞进一个件里；要图片水印时另开一件更清楚。
 *   · 防篡改（Ant 的 `MutationObserver` 那一档）—— **那是 Web 特有的**，
 *     QML 里没有对应的东西，写进能力清单只会误导使用者。
 *   · 多行内容（Ant 的 `content` 数组）—— 用 `\n` 的 `text` 即可表达，
 *     单独开一条属性会让"倾角下多行怎么对齐"变成第二个几何问题。
 *
 * ── 水印不吃事件 ─────────────────────────────────────────────────────
 * 整个水印层是一个 `Item` + `Repeater` 的 `Text`。`Text` 不是输入项，
 * 事件会穿透到 host 里那些真的 `MouseArea` 上 —— 不需要额外
 * `enabled: false`（本项目里 `enabled` 关掉的 `MouseArea` 会变
 * `Qt.ArrowCursor`，那是另一回事）。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    /** 要被盖住的内容放这里（默认属性直通 host 的 data） */
    default property alias contentData: host.data

    /** 水印文字。含 `\n` 可画多行 */
    property string text: ""

    /* ══════════════════════ 外观 ══════════════════════ */

    property int fontSize: Theme.font.sm
    property color color: Theme.color.fg
    property real inkOpacity: 0.15

    /** 倾角（度）。负值 = 逆时针 */
    property real rotate: -30

    /** 网格步长 */
    property int gapX: 140
    property int gapY: 100

    /** 网格整体偏移（用来对齐到某个相位） */
    property int offsetX: 0
    property int offsetY: 0

    /** 单独关掉水印层（内容照常显示） */
    property bool inkVisible: true

    /* ══════════════════════ 网格几何（全部可算） ══════════════════════ */

    readonly property int _stepX: Math.max(1, root.gapX)
    readonly property int _stepY: Math.max(1, root.gapY)

    /** 列数 / 行数。**从 -1 起**（见下面 gridPoints 的说明），到 ceil(w/step)+1 止 */
    readonly property int gridCols: root.width  > 0 ? Math.ceil(root.width  / root._stepX) + 2 : 0
    readonly property int gridRows: root.height > 0 ? Math.ceil(root.height / root._stepY) + 2 : 0

    /* 网格点：从**负一个步长**开始，是为了让旋转后的字也铺满左/上边缘。
     * 若从 0 起，左上角会露出一块没有水印的三角形 —— 而那正是
     * "看起来只是差一点"的那类缺陷。 */
    readonly property var gridPoints: {
        var pts = []
        var w = root.width, h = root.height
        if (w <= 0 || h <= 0) return pts
        var nx = root.gridCols, ny = root.gridRows
        for (var iy = -1; iy < ny - 1; ++iy) {
            for (var ix = -1; ix < nx - 1; ++ix) {
                pts.push({ x: ix * root._stepX + root.offsetX,
                           y: iy * root._stepY + root.offsetY })
            }
        }
        return pts
    }

    readonly property int gridPointCount: root.gridPoints.length

    /* ══════════════════════ 无障碍 ══════════════════════ */

    /* 水印是**视觉装饰**，不该被读屏念出来（念了就是每个控件前面都多一句
     * "机密"）。要表达"这块内容有密级"请用 QSkinTag / QSkinBadge。 */
    Accessible.ignored: true

    /* ══════════════════════ 内容宿主 ══════════════════════ */

    Item {
        id: host

        anchors.fill: parent

        /* 触摸事件要靠它才穿得到下面的宿主控件上 —— 否则水印层会把
         * 整个区域变成一张不透光的纸。`Text` 本来就不吃事件，
         * 但把这条写在明处，将来有人往水印层加东西时能看到。 */
    }

    /* ══════════════════════ 水印层 ══════════════════════ */

    Item {
        id: ink

        anchors.fill: parent
        clip: true
        visible: root.inkVisible && root.text.length > 0

        Repeater {
            model: root.gridPoints

            /* delegate 抽成顶层 Component —— 内联 delegate 会被 qmllint
             * 判成新作用域，里面的 `root` / `Theme` 全变成 Unqualified
             * access（QSkinKbd 首跑撞过 17 条）。 */
            delegate: inkComp
        }
    }

    /* ── delegate 的绑定引用外层 id（root / Theme）—— 完整调查见
     * `QSkinCalendar.qml` 文件头，处置取第三条（局部关掉），与 QSkinKbd 同款。 */
    // qmllint disable unqualified
    Component {
        id: inkComp

        Text {
            id: inkText

            required property int index
            required property var modelData

            x: inkText.modelData.x
            y: inkText.modelData.y
            text: root.text
            color: root.color
            opacity: root.inkOpacity
            font.family: Theme.font.family
            font.pixelSize: root.fontSize

            /* 绕自己的中心转，而不是绕左上角 —— 后者会让整片网格
             * 整体平移（看起来像"位置算错了"，其实是变换基点错了）。 */
            transformOrigin: Item.Center
            rotation: root.rotate
        }
    }
    // qmllint enable unqualified
}
