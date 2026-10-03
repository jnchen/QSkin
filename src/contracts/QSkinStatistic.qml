/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinStatistic
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 数值展示（M24）—— 一枚大数字配上标题、单位与前后缀。仪表盘顶部那一排、
 * 报表的摘要块都用它。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 数字格式化是**这一件的核心**，不是附属功能
 * ════════════════════════════════════════════════════════════════════════
 * 参照实现的这一件，props 里一半都在回答"这个数怎么显示"：
 *     precision（小数位）、groupSeparator（千分位）、formatter（自定义）
 * 因为"数值展示"的难点从来不是排版，而是**同一个数字有好几种正确写法**：
 *     1234567.891   →  1,234,567.89（千分位 + 两位）
 *                   →  1234567.9   （一位、无分隔）
 *                   →  ¥1,234,568 （取整、带符号前缀）
 *
 * 所以格式化抽成**纯函数** `formatValue()`，并且：
 *   · 它是**公开**的（`QSkinStatistic.formatValue(...)` 走实例上的函数）——
 *     判据可以直接喂输入、读输出，不必去猜渲染出来的字。
 *   · 它不问渲染的任何事（没有颜色、没有字号），所以能在冒烟测试里
 *     一次跑几十组。
 *
 * ── 千分位是**自己写的**，而且是按"整数字符串"分组的 ──────────────────
 * 不能用 `Number.prototype.toLocaleString()`：它的分隔符与分组方式跟着
 * **运行环境的 locale** 走，同一份代码在不同机器上可能给出
 * "1,234,567" 或 "1 234 567" 或 "12,34,567"。一个设计系统的数字格式
 * 不能随机器变 —— 那会让抓图与判据都不可复现。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 标题走 label 插槽，数值**不**走
 * ════════════════════════════════════════════════════════════════════════
 * 标题（"总销售额"）与其它控件的标题是同一件事，走 `Slots.label`
 * （变体 `muted`）—— 换主题时它与折叠面板标题、对话框标题一起变。
 *
 * 数值不走，理由是 QSkinBadge 文件头记过的那条判据：**尺寸契约冲突时
 * 不复用插槽**。label 是"正文 14"，而这里要的是 24 号、半粗、并且按
 * `valueStyle` 换色 —— 让 label 同时服务这两件事，只会逼主题作者写
 * "如果我在统计里就…"。只在**颜色/字重**上不同才复用；尺寸不同就分开。
 *
 * ── 倒计时（Ant 的 Countdown / Arco 的 countDown）已由 `QSkinCountdown` 承接 ──
 * M24 当时把倒计时刻意留空，理由是「会自己走的控件不可抓」（与 QSkinCarousel
 * 把 `autoplay` 默认关掉同源），并留了一句"它的正确形态正好是这一件"。
 *
 * ⚠ **那句话在 M30 之后不再成立，别照着它写新代码。** 倒计时确实可以靠
 * `value: (deadline - Date.now()) / 1000` 绑出来，但那样得到的东西有两个
 * 它自己解决不了的缺口：**没有"现在"的注入点**（于是不可抓、不可门禁），
 * 以及**到期事件**（信号）与时间字段（天/时/分/秒）都得宿主各写一遍。
 * 这两个缺口是"倒计时作为一个件"的全部内容，所以 M30 另开了
 * `QSkinCountdown` —— 形态是**先有注入、再有走时**（`now` 可注入）。
 *
 * 本件仍然只做**数值展示**：`QSkinStatistic.value` 收 `QSkinCountdown` 算好的
 * 数也可以，但两件的职责不重叠 —— 这里回答"这个数怎么写"，那里回答
 * "还剩多久"。
 *
 * 用法：
 *     QSkinStatistic { title: "总销售额"; value: 1234567.891
 *                    prefix: "¥"; precision: 2; separator: true }
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 取值 ══════════════════════ */

    /** 标题（"总销售额"）。空则不占位 */
    property string title: ""

    /** 要展示的数。数字走格式化；**字符串原样输出**（"3.2 万"这种
     *  已经成型的写法不该被再格式化一遍） */
    property var value: 0

    /** 值前缀 / 后缀（"¥" / "元" / "%"）。它们与数值同色、小一号 */
    property string prefix: ""
    property string suffix: ""

    /** 小数位数。−1 = **原样**（不做 toFixed，也就不会把 12 变成 12.00） */
    property int precision: -1

    /** 千分位分隔符。分隔符是令牌性的写法选择，不是 locale（见文件头） */
    property bool separator: false

    /** 自定义格式化：`function (value) { return "…" }`。
     *  给了它就完全接管 —— precision / separator 都不再参与。 */
    property var formatter: null

    /* ══════════════════════ 外观 ══════════════════════ */

    /** default | success | warning | danger —— 决定数值的颜色 */
    property string valueStyle: "default"

    /** 底部一行说明（Arco 的 `extra`）。空则不占位 */
    property string extra: ""

    /** 加载态：数值位置换成骨架条，标题与 extra 照常显示。
     *  换的是**值**，不是整块 —— 因为"标题已经拿到了、数还没拿到"
     *  是仪表盘的常态，整块骨架会让版面先塌一次再撑回来。 */
    property bool loading: false

    /** 加载态骨架条的宽度（像素）。写成属性而不是常量：它该跟"值通常
     *  有多长"匹配，而那是宿主才知道的事。 */
    property int loadingWidth: 96

    /* ══════════════════════ 派生 ══════════════════════ */

    /** 最终显示的数值文字。**唯一的**格式化入口（见文件头） */
    readonly property string valueText:
        root.formatValue(root.value, root.precision, root.separator, root.formatter)

    readonly property color _valueColor:
        root.valueStyle === "success" ? Theme.color.success
      : root.valueStyle === "warning" ? Theme.color.warning
      : root.valueStyle === "danger"  ? Theme.color.danger
                                      : Theme.color.fg

    readonly property int _valueSize: Theme.font.xl
    readonly property int _affixSize: Theme.font.md

    implicitWidth:  Math.max(80, content.implicitWidth)
    implicitHeight: content.implicitHeight

    width:  implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: (root.title !== "" ? qsTr("%1：").arg(root.title) : "")
                     + root.prefix + root.valueText + root.suffix
    Accessible.ignored: root.loading

    /* ══════════════════════ 视觉 ══════════════════════ */

    QSkinColumn {
        id: content

        x: 0
        y: 0
        width: root.width
        gap: Theme.space.xs
        padding: 0

        /* ── 标题 ── 走 label 插槽（见文件头） */
        Loader {
            id: titleLoader

            sourceComponent: Slots.label
            active: root.title !== ""
            visible: active

            Binding {
                target: titleLoader.item
                property: "control"
                value: titleCtl
                when: titleLoader.status === Loader.Ready
            }
        }

        QtObject {
            id: titleCtl

            readonly property string text: root.title
            readonly property string variant: "muted"
            readonly property int labelAlignment: Text.AlignLeft
        }

        /* ── 数值行 ── */
        QSkinRow {
            id: valueRow

            visible: !root.loading
            gap: Theme.space.xs
            padding: 0
            align: "baseline"

            Text {
                visible: root.prefix !== ""
                text: root.prefix
                color: root._valueColor
                font.family:    Theme.font.family
                font.pixelSize: root._affixSize
                font.weight:    Theme.font.weightMedium
                renderType:     Text.NativeRendering
                verticalAlignment: Text.AlignBottom
            }

            /* 数值：**不走 label 插槽**（尺寸契约冲突，见文件头）。
             * 对齐用 baseline —— 前后缀小一号，按盒子底部对齐会让它们
             * 骑在数值的下缘上；基线对齐才是"贴在数字脚边"。 */
            Text {
                id: valueText

                text: root.valueText
                color: root._valueColor
                font.family:    Theme.font.family
                font.pixelSize: root._valueSize
                font.weight:    Theme.font.weightSemiBold
                renderType:     Text.NativeRendering

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.motion.fast
                        easing.type: Theme.motion.easing
                    }
                }
            }

            Text {
                visible: root.suffix !== ""
                text: root.suffix
                color: root._valueColor
                font.family:    Theme.font.family
                font.pixelSize: root._affixSize
                font.weight:    Theme.font.weightMedium
                renderType:     Text.NativeRendering
                verticalAlignment: Text.AlignBottom
            }
        }

        /* ── 加载态 ──
         * 复用 QSkinSkeleton，不自己画一条灰条（那会是第二份骨架实现）。
         * `titleWidth: 1.0` 让它就是**一条**满宽的条，`titleHeight` 对齐
         * 数值的行高，于是加载完的那一刻版面不会跳高。 */
        QSkinSkeleton {
            id: valueSkeleton

            visible: root.loading
            loading: true
            title: true
            paragraph: false
            titleWidth: 1.0
            titleHeight: root._valueSize
            baseWidth: root.loadingWidth
            gap: 0
        }

        Caption {
            id: extraText

            visible: root.extra !== ""
            text: root.extra
        }
    }

    /* ══════════════════════ 格式化（纯函数，公开）══════════════════════ */

    /**
     * formatValue(value, precision, separator, formatter) → string
     *
     * 四条规则，按优先级：
     *   ① formatter 是函数 → 由它全权决定（precision / separator 不再参与）
     *   ② value 不是有限数（字符串、null、NaN）→ **原样输出**
     *   ③ precision >= 0 → toFixed(precision)
     *   ④ separator → 按**整数字符串**插千分位
     *
     * 为什么③之后才做④：先分组再取整会让 "1,234,567.891" 变成
     * "1,235,000"（分组发生在取整之前），而正确结果是 "1,234,568"。
     * 顺序反了是这类格式化最常见的错，所以在这里写死。
     */
    function formatValue(v, precision, separator, formatter) {
        if (formatter !== null && formatter !== undefined
                && typeof formatter === "function") {
            return String(formatter(v))
        }
        if (v === null || v === undefined) return ""
        if (typeof v !== "number" || !isFinite(v)) return String(v)

        var s = precision !== undefined && precision !== null && precision >= 0
                ? v.toFixed(Math.min(20, Math.round(precision)))
                : String(v)

        if (separator === true) s = root.groupDigits(s)
        return s
    }

    /**
     * groupDigits(s) → string
     *
     * 给**十进制数字串**的整数部分插千分位。负号留在最前面。
     *
     * 输入是"已经定型的小数字符串"（toFixed 的产物或 String(number)），
     * 于是不必关心科学计数法之外的形态 —— `String(1e21)` 会给出
     * "1e+21"，那种串里没有小数点也没有可分组的三位段，本函数会原样
     * 返回（**已知缺口**：超大数不做分组；参照实现同样不处理）。
     */
    function groupDigits(s) {
        var str = String(s)
        if (str.indexOf("e") >= 0 || str.indexOf("E") >= 0) return str

        var neg = false
        if (str.charAt(0) === "-") { neg = true; str = str.substring(1) }

        var dot = str.indexOf(".")
        var intPart = dot < 0 ? str : str.substring(0, dot)
        var rest    = dot < 0 ? "" : str.substring(dot)

        /* 从右往左每三位切一刀，再倒回来 —— 比"从左往右插入"少一次
         * 索引换算，也不会在位数是 3 的倍数时多插一个前导分隔符。 */
        var out = ""
        var count = 0
        for (var i = intPart.length - 1; i >= 0; --i) {
            out = intPart.charAt(i) + out
            count++
            if (count % 3 === 0 && i > 0) out = "," + out
        }
        return (neg ? "-" : "") + out + rest
    }
}
