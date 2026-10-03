/****************************************************************************
 * QSkin · Quick Design System — Contracts / slots / BasicTimelineDot
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 「timelineDot」插槽的 Basic 默认实现 —— 时间轴上那一颗圆点。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么这一格没有复用 stepIndicator
 * ════════════════════════════════════════════════════════════════════════
 * 两者看着都是"沿一条线排开的小圆"，但把两份契约并排放就散了：
 *
 *   stepIndicator（QSkinSteps 的步骤圆）
 *     状态词汇  finish | process | wait | error
 *     内容       **必带数字**（`text: String(idx()+1)`，无条件画）
 *     额外       process 有一圈无限脉冲光环
 *     尺寸       24（stepSize）
 *
 *   timelineDot（本格）
 *     状态词汇  default | primary | success | warning | danger（语义色轴）
 *     内容       无数字。可以是一枚自定义图形（宿主自己放，插槽让位）
 *     额外       无脉冲
 *     尺寸       10（dotSize）—— 比步骤圆小一半还多
 *
 * 三条都撞：状态词汇不通用（时间轴没有"进行中/等待"这种进程语义，它有的是
 * 语义色的四档）、内容不同（数字 vs 无）、尺寸差一个量级。
 *
 * 而**同一主题内两者必须并存**：一个页面可以同时有步骤条与时间轴，
 * 参照实现里这两处的圆也确实不是同一个东西（步骤圆是品牌色的编号圆，
 * 时间轴的缺省点是一颗小灰点）。一格插槽装不下两种取值 ——
 * 与 segmentThumb 那条判据同源，是它的第二次应用。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 契约
 * ════════════════════════════════════════════════════════════════════════
 *   property var control   宿主 = 一个时间轴条目。鸭子类型，要求暴露：
 *     · type      string   default | primary | success | warning | danger
 *                          （未知值一律按 default）
 *     · last      bool     是不是最后一颗（末点的画法不同，见下）
 *     · dotSize   int      圆点直径，宿主给；缺省 10
 *     · color     color    可选。给了就用它（宿主已按 type 算好）；
 *                          缺省由本格按 type 自己推
 *
 *   尺寸：宿主**给** dotSize，因为时间轴的圆点是被"行的节奏"约束的
 *   （它要和两侧文字的基线对齐）—— 与 chevronIndicator 那条"尺寸是主题的
 *   差异之一，宿主别给"相反，这里尺寸是**宿主的**决定，所以进契约。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 末点画成空心 —— 这是本仓的取法，不是抄来的规定
 * ════════════════════════════════════════════════════════════════════════
 * 非末条：**实心**圆（`color` 填满）。
 * 末  条：**空心**圆（透明底 + 描边 = `color`）。
 *
 * 这么取有两个理由：
 *   ① 实心点读起来像"这里还有下一站"，空心点读起来像"到这里为止"；
 *   ② 它给了像素核验一条**只在渲染上成立**的性质 —— 同一张图上，实心点
 *      是一整块墨，末点只剩**左、右两道壁**（环里是空的）。
 *      属性侧只能读到 `last === true`，读不到"那颗点真的画空了"。
 *      核验器量的是环的**内径 / 壁厚 / 外径**三项，外加"中心那一行到底
 *      是不是空的"（`.cache/_verify_m23.py` 的 `[3][4]` 组）。
 *
 * ── 这里原来写着的那两个数已经删掉了（记账）──────────────────────────
 * 本条第一版写的是"墨迹填充率相差约 4 倍（0.78 vs 0.2 上下）"。那两个数是
 * **没量就写的**，而且量法本身也不成立：空心点是个小圆环，"填充率"取决于
 * 你拿谁当分母（环的外接方框 / 环自身面积 / 中心行），换个量法就换个数 ——
 * 写下来的数**无法复算**，也就没法被证伪。
 * 所以改成"环里到底空不空"这个**二值**性质：只有真/假两种答案，不受量法
 * 影响，而且正好是属性侧永远看不到的那一面。
 * （项目规矩：文档里的数字必须可复算，否则不写。）
 *
 * 要说清楚的是：**这是本仓的取法**。参照实现里这一处各家的表达方式不同
 * （有的用点位属性、有的用形状枚举），所以本条不是"对齐某一家"的转述，
 * 而是一条本仓自己的、可被主题整格替换掉的默认。
 * 主题想要另一套（全实心 / 方点 / 带图标的点），覆盖这一格即可。
 *
 * 契约第 3 条：圆点没有交互，插槽里不许放 MouseArea。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    property var control: null

    readonly property int   size:  (root.control && root.control.dotSize > 0)
                                   ? root.control.dotSize : 10
    readonly property bool  isLast: root.control ? root.control.last === true : false

    implicitWidth:  root.size
    implicitHeight: root.size

    /** 宿主算好的语义色优先；没给就按 type 自己推。 */
    readonly property color tone: (root.control && root.control.color !== undefined
                                  && root.control.color !== null)
                                  ? root.control.color : root._toneFromType()

    function _toneFromType() {
        var t = root.control ? root.control.type : "default"
        switch (t) {
        case "primary": return Theme.color.brand
        case "success": return Theme.color.success
        case "warning": return Theme.color.warning
        case "danger":  return Theme.color.danger
        default:        return Theme.color.borderStrong   /* default：弱化的中性点 */
        }
    }

    Rectangle {
        id: disc

        anchors.fill: parent
        radius: width / 2

        /* 末点空心：底透明、边框本色。
         * 边框宽度按直径取比例，这样宿主改 dotSize 时不会出现
         * "大点配细圈"的失真（chevronIndicator 的线宽同一手法）。 */
        color:        root.isLast ? "transparent" : root.tone
        border.width: root.isLast ? Math.max(1, Math.round(root.size * 0.16)) : 0
        border.color: root.tone

        Behavior on color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
        }
    }
}
