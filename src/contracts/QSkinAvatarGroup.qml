/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinAvatarGroup
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 头像组 —— 一排**叠起来**的头像，末尾可能挂一个 "+N"。
 * 用在"谁参与了这个项目""这条记录被谁看过"这类地方。
 *
 * ── 它是 QSkinAvatar 的消费者，不是它的复制品 ─────────────────────────────
 * 每一个头像一个 QSkinAvatar 实例，尺寸/形状/描边全部转手传下去。
 * 所以"画一个头像"的代码在这个项目里只有一份 —— 头像改了什么
 * （比如那个圆角遮罩），头像组自动跟着改。
 *
 * ── 为什么 `model` 里放不下图标 ────────────────────────────────────────
 * 条目只认三个字段：`src` / `text` / `alt`。**没有 `icon`**，原因是
 * QML 的一条硬限制而不是设计取舍：
 *
 *     `Component { }` 是**对象声明**语法，只能在对象树的声明位置出现。
 *     JS 对象字面量里写不出 Component —— `{ icon: Component { … } }`
 *     整个文件都解析不过去（同一个坑在 Slots.qml 文件头记过一次）。
 *
 * 要让组里的某个头像带图标，走 `collapseAvatar` 那条路：给它一个
 * Component，它就能引用外层任意 id、想画什么画什么。
 *
 * ── 叠放量用"比例"表达，不用像素 ────────────────────────────────────────
 * `overlapRatio: 0.3` 是"每个头像被后一个压住 30% 的直径"。
 * 三家的默认叠放量都跟着尺寸走（小头像压得少、大头像压得多），
 * 给像素值会让 sm / xl 两种档位里有一种明显不对。
 * TDesign 的 `cascading: right-up` 就是这里的正负号 ——
 * 本实现只做向右叠（`overlapRatio` 为正）；要左叠把顺序反过来即可，
 * 不值得为它再开一个枚举。
 *
 * ── 定位是**手算**的，没走 QSkinRow ───────────────────────────────────────
 * 叠放需要负间距，而"负间距"在 RowLayout 里的行为没有文档保证。
 * 手算 `x = index × (直径 − 叠放量)` 一共一行，而且把
 * "第 n 个头像的圆心在哪"变成了可断言的算式 —— 像素核验直接对着量。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 数据 ══════════════════════ */

    /** 头像数组。每个元素是 `{ src, text, alt }` 三选一的对象；
     *  也可以直接给字符串（**当作文本**，不猜它是不是路径 ——
     *  "是不是 URL" 这种猜测在 `abc.png` 和 `abc` 之间必然出错）。 */
    property var model: []

    /** 最多显示几个。超出的折成末尾一个 "+N"。0 = 全显示。 */
    property int max: 0

    /** 末尾那个 "+N" 的自定义样子。null = 用 QSkinAvatar 显示文字。
     *  这是组内**唯一**能放任意 QML 的地方（可以用它放带图标的头像）。 */
    property Component collapseAvatar: null

    /** "+N" 的文案模板，`{n}` 会被替换成数字。 */
    property string moreText: "+{n}"

    /* ══════════════════════ 外观 ══════════════════════ */

    /** 同 QSkinAvatar：sm | md | lg | xl 或像素数。 */
    property var size: 32

    /** 同 QSkinAvatar：circle | square。 */
    property string shape: "circle"

    /** 每个头像被后一个压住的比例（0 ~ 0.8）。 */
    property real overlapRatio: 0.3

    /** 叠放分隔环的宽度。0 = 不画（头像会糊成一片，一般不该关）。 */
    property int ringWidth: 2

    /** 分隔环的颜色。**一般填"头像组所在的那个面的底色"** ——
     *  环的作用是"抠掉后面那个头像的一条边"，不是给头像加边框。 */
    property color ringColor: Theme.color.bgElevated

    /* ══════════════════════ 派生 ══════════════════════ */

    readonly property int count: root._countOf(root.model)

    readonly property int px:
        typeof root.size === "number" ? Math.max(8, Math.round(root.size))
      : root.size === "sm" ? 24
      : root.size === "lg" ? 40
      : root.size === "xl" ? 64
                           : 32

    /** 实际叠放像素数。夹在 0 ~ 0.8×直径之间：负的会把头像推开
     *  （"那不是叠放"），超过 0.8 会把前一个吃得只剩一条边。 */
    readonly property int overlap: Math.round(root.px * Math.max(0, Math.min(0.8, root.overlapRatio)))

    /** 相邻两个头像原点的距离 —— 核验脚本量的就是这个数。 */
    readonly property int step: Math.max(1, root.px - root.overlap)

    /** 真正画出来的头像个数（含 "+N"）。 */
    readonly property int visibleCount:
        root.max > 0 ? Math.min(root.max, root.count) : root.count

    /** 折掉的个数。0 = 不显示 "+N"。 */
    readonly property int overflowCount: Math.max(0, root.count - root.visibleCount)

    readonly property int slotCount: root.visibleCount + (root.overflowCount > 0 ? 1 : 0)

    implicitWidth:  root.slotCount > 0 ? root.step * (root.slotCount - 1) + root.px : 0
    implicitHeight: root.px

    width:  implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("%1 个头像").arg(root.count)

    /* ══════════════════════ 排布 ══════════════════════ */

    Repeater {
        model: root.slotCount
        delegate: slotComp
    }

    /* ══════════════════════ 两个内置块 ══════════════════════ */

    // qmllint disable unqualified
    Component {
        id: slotComp

        Item {
            id: slot

            required property int index

            x: slot.index * root.step
            width:  root.px
            height: root.px

            /* z 用下标：后来的压住先来的。叠放全靠这一条 ——
             * 若改成按声明顺序（Repeater 本来就是），行为相同，
             * 但显式写出来是为了让"谁在上"不依赖 Repeater 的实现细节。 */
            z: slot.index

            Loader {
                id: cellLoader

                anchors.fill: parent
                sourceComponent: (slot.index >= root.visibleCount && root.collapseAvatar !== null)
                                 ? root.collapseAvatar : avatarComp

                /* Loader.item 的静态类型是 QQuickItem，没有 entry。
                 * 这是刻意的鸭子类型写入（见文件头"为什么 model 里放不下图标"）：
                 * 自定义的 collapseAvatar 不一定声明 entry，所以先判存在再写。 */
                // qmllint disable missing-property
                onLoaded: {
                    if (!cellLoader.item)
                        return
                    if (cellLoader.item.entry !== undefined)
                        cellLoader.item.entry = root._entryAt(slot.index)
                }
                // qmllint enable missing-property
            }
        }
    }

    Component {
        id: avatarComp

        QSkinAvatar {
            property var entry: null

            size:  root.size
            shape: root.shape
            ringWidth: root.ringWidth
            ringColor: root.ringColor

            src:  root._field(entry, "src", "")
            text: root._field(entry, "text", "")
            alt:  root._field(entry, "alt", "")
        }
    }
    // qmllint enable unqualified

    /* ══════════════════════ 内部 ══════════════════════ */

    /** 第 index 个槽位的数据。落在溢出位时返回 "+N" 的描述对象。 */
    function _entryAt(index) {
        if (index >= root.visibleCount)
            return { text: root.moreText.replace("{n}", String(root.overflowCount)) }
        var m = root.model
        if (m === null || m === undefined) return null
        return m[index]
    }

    /** 从条目里取一个字段。条目是字符串时，字符串就是 `text`。 */
    function _field(entry, key, dflt) {
        if (entry === null || entry === undefined) return dflt
        if (typeof entry === "string" || typeof entry === "number")
            return key === "text" ? String(entry) : dflt
        return entry[key] !== undefined ? entry[key] : dflt
    }

    /** model 的条目数。判据与 QSkinList._count() 同源。 */
    function _countOf(m) {
        if (m === null || m === undefined) return 0
        if (typeof m === "number") return Math.max(0, Math.floor(m))
        if (m.count  !== undefined) return m.count
        if (m.length !== undefined) return m.length
        return 0
    }
}
