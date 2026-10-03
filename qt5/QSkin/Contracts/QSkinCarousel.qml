/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinCarousel
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 轮播（M23）—— 一屏一页地横向切换，带指示点与可选的自动播放。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么它走**数据驱动**（model + delegate），不像折叠面板那样收子项
 * ════════════════════════════════════════════════════════════════════════
 * 折叠面板 / 时间轴的成员是"用户声明的、形状各异的一块块 UI"，所以收子项。
 * 轮播的每一页则是**同一种东西的第 i 份**（第 1 张、第 2 张……）——
 * 差的是**数据**，不是结构。这与 QSkinList / QSkinTable 的分工一致：
 * 同一形状重复 N 次 → `model` + `delegate`。
 *
 * 它还顺手消掉一个坑：收子项时要让"每一页的宽高 = 视口宽高"，
 * 只能挨个给子项挂 `Qt.binding`（并小心别重复挂）。数据驱动下这一句
 * 由 Repeater 的委托自然成立 —— **尺寸由布局算，不需要谁去改别人的属性**。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 确定性：`autoplay` **必须**能关掉，且默认就是关的
 * ════════════════════════════════════════════════════════════════════════
 * 项目铁律是"抓图要确定性"。一个会自己动的控件是**不可抓**的 ——
 * 抓到的图取决于快门那一刻它转到哪儿。
 *
 * 所以：默认 `autoplay: false`；抓图脚本一行都不用关它。
 * 这不是"够用就行"的取值选择，**默认值本身是门禁的一部分**：
 * 把默认设成 true 会让每一张抓图都变成"可能对、可能不对"。
 *
 * 同理，切换动画有 `animate` 开关（组件完成后才开），
 * 且抓图脚本会先把 `currentIndex` 钉死再等动画收尾 ——
 * 一个没跑完的平移动画量出来的偏移是**中间值**（M22 那条教训的近亲）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 指示点为什么**没有**进插槽
 * ════════════════════════════════════════════════════════════════════════
 * 本批新增了两格插槽（segmentThumb / timelineDot），各自都有"形态真有分歧、
 * 且同主题内需要两种取值"的证据。指示点**没有**这样的证据：
 * 四家里只有三家有轮播，而这三家的指示点在形态上是同一路货
 * （一排小点，当前那颗更宽/更亮）—— 差异全在**两个数**上，而数是令牌能表达的。
 *
 * 所以按项目纪律：**没有分歧证据就不开格**（开一格的代价是一份永久契约）。
 * 等出现第二个消费者、或者出现真正的形态分歧（比如某家改用数字页码）再收。
 * 这与 M22 那个"第三份 ✕"的处置是同一条：知道它在那儿，排在后面。
 *
 * ── 刻意**没做**的 ──────────────────────────────────────────────────────
 *   · `effect: fade`（淡入淡出）—— 需要两页同时在场并交叉淡出；
 *     而"一屏一页"的平移是轮播的基本盘。消费者为零。
 *   · 拖拽翻页 —— 它要接管手势与惯性，属于"再来一套输入处理"。
 *   · 纵向轮播 —— 与横向共用 90% 的实现，但没有消费者。
 ****************************************************************************/

import QtQuick 2.15
/* ── 这个别名 import 是为了拿到 QtQuick 那个**原生 positioner** `Row`。
 *
 * 本文件同时 import 了 QtQuick 与 QSkin.Foundation，而两边都导出 `Row`
 * （foundation/qmldir 里明写着"跨模块使用时，同名类型要靠 import 顺序
 * 消歧义，太脆弱"，每个 .qml 都注册了 `Row` 与 `QSkinRow` 两个名字）。
 *
 * 实测（`.cache/_probe_m23row.qml`，回传通道是退出码）：裸名 `Row` 在这里
 * 解析成 **QSkin.Foundation.Row**（有 `gap`、没有 `spacing`）。而
 * `foundation/QSkinRow.qml` 文件头建议的 `QtQuick.Row` 这条写法**在版本化
 * import 下不成立** —— 实测报：
 *
 *     QtQuick.Row - QtQuick is neither a type nor a namespace
 *
 * 所以用别名 import。注意它与上面那句是**两次**对同一模块的 import，
 * 这是 QML 允许的写法（一句给未限定名，一句给命名空间）。
 * 别名之后 `Row` 仍是 QSkin 那一份 —— 两者都要能写到，所以别删上面那句。 */
import QtQuick 2.15 as QQ
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 接口 ══════════════════════ */

    /** 页数或页数据。数字 = 只要数量（delegate 用 index 取数据）；
     *  数组 = 元素原样作为 `modelData` 传给 delegate（与 QSkinList 同一约定）。 */
    property var model: 0

    /** 每页的画法。**契约与 QSkinList 完全一致**（那条很要紧，见下）：
     *  根对象声明两个**普通属性**
     *
     *      property int index
     *      property var modelData
     *
     *  ⚠ **不要**写成 `required property`。required 属性只能由 Repeater
     *    直接注入给**它的** delegate，而每一页外面还有一层 Loader ——
     *    那层是"每页都等于视口大小"所必需的。实测
     *    （`.cache/_probe_m23carq.qml`，退出码 122）：
     *
     *      穿得过 Loader 的：`modelData`（bit5 亮：第一个页读到 "第一页"）
     *      穿不过去的：    `index`      （bit2 亮：typeof index === "undefined"）
     *
     *    写成 required 的后果不是"读不到"，而是**整页构造失败**。
     *    QSkinList 早就踩过并定了解法（`QSkinList.qml` 的 cellLoader）：
     *    宿主在 `onLoaded` 里把两个值注入进去，而不是指望它们穿透。
     *    本件照抄 —— 于是同一个 delegate 模板在两个控件之间可以搬。 */
    property Component delegate: null

    /** 当前页下标 */
    property int currentIndex: 0

    /** 到头之后回卷。false 时首尾停住（`next`/`prev` 到端点不动作）。 */
    property bool loop: true

    /** 自动播放。**默认关** —— 见文件头"确定性"那一节。 */
    property bool autoplay: false

    /** 自动播放间隔（毫秒） */
    property int interval: 3000

    /** 显示底部指示点 */
    property bool showDots: true

    /** 显示左右箭头 */
    property bool showArrows: false

    /** 整件的可用性（禁用时自动播放停、箭头与点不可点） */
    property bool enabled: true

    signal pageChanged(int index)

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property int count: {
        var m = root.model
        if (m === null || m === undefined) return 0
        if (typeof m === "number") return Math.max(0, Math.floor(m))
        return m.length
    }

    /** 切换动画是否已武装（首次出现时不该看见它自己滑一下）。 */
    property bool animate: false
    Component.onCompleted: root.animate = true

    /* ══════════════════════ 控制 ══════════════════════ */

    function goTo(i) {
        var n = root.count
        if (n <= 0) return
        var t = i
        if (root.loop) t = ((i % n) + n) % n
        else           t = Math.max(0, Math.min(n - 1, i))
        if (t === root.currentIndex) return
        root.currentIndex = t
        root.pageChanged(t)
    }

    function next() { root.goTo(root.currentIndex + 1) }
    function prev() { root.goTo(root.currentIndex - 1) }

    /** 页数变了要夹一次：从 5 页变 2 页时下标必须落在界内，
     *  否则整条轨道会被平移到"没有页"的地方（一片空白，而属性上看不出错）。 */
    onCountChanged: root._clamp()

    function _clamp() {
        var n = root.count
        if (n <= 0) {
            if (root.currentIndex !== 0) root.currentIndex = 0
            return
        }
        if (root.currentIndex > n - 1) root.currentIndex = n - 1
        if (root.currentIndex < 0)     root.currentIndex = 0
    }

    /* ══════════════════════ 视觉 ══════════════════════ */

    implicitWidth:  320
    implicitHeight: 180

    /* ── 视口：裁掉轨道上不该看见的页 ── */
    Item {
        id: viewport

        anchors.fill: parent
        clip: true

        /* ── 轨道 ──
         * 这里要的是 QtQuick 那个**原生 positioner** `Row`，所以必须写
         * 别名形式 `QQ.Row`（`QQ` = `import QtQuick 2.15 as QQ`）。
         *
         * 三条实测，缺一条都会写出一个"属性全绿、屏幕空白"的轮播：
         *
         *   ① 裸名 `Row` → **QSkin.Foundation.Row**（有 `gap` 无 `spacing`，
         *      见 `.cache/_probe_m23row.qml`）。那是个 RowLayout 外壳。
         *      ⚠ **M29 起这条已不成立**：`foundation/qmldir` 去掉双名注册
         *      之后，裸 `Row` 稳定指 QtQuick 的 positioner。本件仍然写
         *      `QQ.Row` —— 显式优于隐式，且改成裸名要重拍本件的像素基线。
         *      完整的两层说明见 `QSkinCascader.qml` 的同源段落。
         *   ② `QtQuick.Row` 这种限定名在**版本化** import 下不成立 ——
         *      实测报 "QtQuick.Row - QtQuick is neither a type nor a namespace"。
         *      所以 `foundation/QSkinRow.qml` 文件头那句建议在这里不可用，
         *      要拿原生 positioner 只能走别名 import。
         *   ③ 一旦用的是 Layout，每一页的 `width: viewport.width` 就会被
         *      覆盖（Layout 决定子项尺寸用的是 `implicitWidth`，而页面 Item
         *      没有隐式宽）—— 页面缩成 0 宽、整条轨道一片空白。
         *      这与 M22 在 QSkinResult 上量到的 `height:` 被 ColumnLayout 覆盖
         *      是同一件事，所以 tests/smoke_m23.qml 的 [7] 专门读页面宽度。
         *
         * 为什么这里要 positioner 而不是 QSkinRow：要的就是"按顺序横排、
         * 每页的宽度由每页自己说了算"。等宽由 `width: viewport.width`
         * 表达即可，不需要 Layout 的分配逻辑 —— 而 Layout 恰恰会**覆盖**
         * 那个显式宽度。 */
        QQ.Row {
            id: strip

            y: 0
            x: -root.currentIndex * viewport.width

            Behavior on x {
                enabled: root.animate
                NumberAnimation { duration: Theme.motion.normal; easing.type: Theme.motion.easing }
            }

            Repeater {
                model: root.model
                delegate: pageComp
            }
        }
    }

    /* ══════════════════════ 一页 ══════════════════════ */

    /* 下面三段 Component 都引用了外层 id（root / viewport / chevCtl）——
     * 与 QSkinList / QSkinAvatar 同款 qmllint 局限，各自局部关闭。
     * 注释首行不要以 qmllint 开头。 */
    // qmllint disable unqualified

    Component {
        id: pageComp

        Item {
            id: page

            /* 这一层**是** Repeater 的 delegate，所以 required 在这里成立
             * （QSkinList 的 rowItem 同款）。用户那一层拿到的则是注入 ——
             * 见下面 onLoaded 与 `delegate` 属性的注释。 */
            required property int index
            required property var modelData

            width:  viewport.width
            height: viewport.height

            /* 用户那一页。没给 delegate 时留白 —— 不报错，也不画别的东西：
             * 一个空槽比一条警告更容易被看见。 */
            Loader {
                id: pageLoader

                anchors.fill: parent
                sourceComponent: root.delegate

                /* 数据注入走 onLoaded 而不是 Binding（照 QSkinList.qml:394）：
                 * Binding 会无条件给目标属性赋值，delegate 忘了声明
                 * 那两个字就会每帧刷一条警告；onLoaded 只跑一次，
                 * 且能顺带做 null 保护。
                 *
                 * ⚠ `index` 穿不过这层 Loader（实测见 `delegate` 的注释），
                 *   所以这两行不是"保险"，而是**唯一的通道**。 */
                onLoaded: {
                    if (!pageLoader.item)
                        return
                    pageLoader.item.index = page.index
                    pageLoader.item.modelData = page.modelData
                }
            }
        }
    }

    // qmllint enable unqualified

    /* ══════════════════════ 指示点 ══════════════════════
     * 按项目纪律没进插槽（见文件头）。画法用**前景色的两档透明度**：
     * 它的底是用户内容（图片 / 任意色块），令牌表里没有"叠在未知底上的
     * 对比色"这一档，所以只能靠"同一色 + 明暗差"表达当前页。 */
    QSkinRow {
        id: dots

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.sm

        visible: root.showDots && root.count > 1
        gap: Theme.space.xs

        Repeater {
            model: root.count
            delegate: dotComp
        }
    }

    // qmllint disable unqualified
    Component {
        id: dotComp

        Rectangle {
            id: dot

            /* Repeater 注入的下标，声明成 required 属性收下 —— 照
             * QSkinList.qml:357。指示点要知道"我是第几个"。 */
            required property int index

            readonly property bool _active: index === root.currentIndex

            width:  dot._active ? 16 : 6
            height: 4
            radius: height / 2

            color: Theme.color.fg
            opacity: dot._active ? 1 : 0.35

            Behavior on width {
                NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
            }

            Accessible.role: Accessible.RadioButton
            Accessible.name: qsTr("第 %1 页").arg(index + 1)
            Accessible.checked: dot._active

            MouseArea {
                anchors.fill: parent
                /* 点的可点区域比它自己大一圈 —— 4px 高的目标太薄了。
                 * 用 anchors.margins 反向扩：负 margin 扩大命中区。 */
                anchors.margins: -Theme.space.xs
                enabled: root.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.goTo(index)
            }
        }
    }

    // qmllint enable unqualified

    /* ══════════════════════ 箭头 ══════════════════════ */
    Loader {
        id: prevBtn

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.space.sm

        visible: root.showArrows && (root.loop || root.currentIndex > 0)
        active:  visible
        sourceComponent: arrowComp

        onLoaded: item.direction = "left"
    }

    Loader {
        id: nextBtn

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Theme.space.sm

        visible: root.showArrows && (root.loop || root.currentIndex < root.count - 1)
        active:  visible
        sourceComponent: arrowComp

        onLoaded: item.direction = "right"
    }

    // qmllint disable unqualified
    Component {
        id: arrowComp

        Item {
            id: arrow

            /** "left" | "right" —— 由上面两个 Loader 的 onLoaded 给。
             *  读 `direction` 而不是读"上/下页"，因为 chevronIndicator 的
             *  契约明说"翻页语义不进插槽，宿主自己翻译成方向"。 */
            property string direction: "left"

            readonly property bool _usable: root.enabled
                                             && (arrow.direction === "left"
                                                 ? (root.loop || root.currentIndex > 0)
                                                 : (root.loop || root.currentIndex < root.count - 1))

            width:  Theme.size.controlSm
            height: Theme.size.controlSm

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color:  arrow._usable
                        ? (arrowMouse.containsMouse ? Theme.color.bgSubtle : Theme.color.bgElevated)
                        : Theme.color.bgSunken

                Behavior on color {
                    ColorAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing }
                }
            }

            Loader {
                id: chevLoader

                anchors.centerIn: parent
                sourceComponent: Slots.chevronIndicator

                Binding {
                    target: chevLoader.item
                    property: "control"
                    value: chevCtl
                    when: chevLoader.status === Loader.Ready
                }
            }

            QtObject {
                id: chevCtl

                readonly property string direction: arrow.direction
                readonly property bool enabled: arrow._usable
            }

            MouseArea {
                id: arrowMouse

                anchors.fill: parent
                hoverEnabled: true
                enabled: arrow._usable
                cursorShape: arrow._usable ? Qt.PointingHandCursor : Qt.ArrowCursor

                onClicked: arrow.direction === "left" ? root.prev() : root.next()
            }
        }
    }

    // qmllint enable unqualified

    /* ══════════════════════ 自动播放 ══════════════════════
     * 三个条件都要成立才跑：开了自动播放、不止一页、整件可用。
     * 少任何一条都会出现"只有一页却在原地刷新"或"禁用后还在动"这类
     * 只在行为上看得见的缺陷。 */
    Timer {
        id: autoTimer

        interval: root.interval
        repeat: true
        running: root.autoplay && root.count > 1 && root.enabled

        onTriggered: root.next()
    }

    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("轮播")
}
