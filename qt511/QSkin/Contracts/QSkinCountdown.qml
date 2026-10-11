/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinCountdown
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 倒计时 —— 距离某个时刻还剩多久。
 *
 * 用法：
 *     QSkinCountdown { deadline: 1790000000000 }          // 毫秒时间戳
 *     QSkinCountdown { deadline: new Date(2026, 8, 16) }  // Date
 *     QSkinCountdown { deadline: "2026-09-16T12:00:00" }  // ISO 串
 *
 * ════════════════════════════════════════════════════════════════════════
 *  这一件存在的**前提**是 `now` 可注入 —— 不然它根本不该被造出来
 * ════════════════════════════════════════════════════════════════════════
 * 本项目对"会自己走的控件"有一条硬约束（`QSkinCarousel` 把 `autoplay` 默认
 * 关掉、`QSkinStatistic` 的文件头把倒计时**列为不做**，都是这条）：
 *
 *     **会自己变的界面抓不住。** 抓到的图取决于快门那一刻它走到哪儿，
 *     "这张图对不对"于是没有答案。
 *
 * 所以这一件的形态是**先有注入、再有走时**：
 *   · `now` 默认 `-1`（哨兵值）= 用内部时钟，由 `Timer` 推进；
 *   · 一旦宿主把 `now` 设成任何别的值（毫秒数 / Date），
 *     **内部 Timer 立刻停**，画面完全由注入值决定。
 *
 * 于是门禁的做法与 `QSkinCalendar`（`today` / `panelYear` 可注入）同构：
 * 灌几个 `now`，读 `remainingMs` 与 `text`，再抓图 —— 全程零时间依赖。
 *
 * ⚠ `-1` 当哨兵而不是"默认 undefined"：`undefined` 在 QML 里既可能是
 *   "没设"也可能是"设成了一个错的东西"，分不开；而且把它赋给一个
 *   `double` 属性会在运行期打 `Unable to assign [undefined] to double`。
 *   `now: 0`（epoch）是一个**合法**输入，所以哨兵不能是 0。
 *
 * ════════════════════════════════════════════════════════════════════════
 *  排版一律继承 `Body`，本件只回答"还剩多久"
 * ════════════════════════════════════════════════════════════════════════
 * 字号 / 字重 / 行高 / 四种 `tone` / 四个行内修饰位全部来自 `Body` ——
 * 与 `Paragraph` 同一条理由：连尺寸都不冲突的地方，复用是唯一正确的写法。
 * 本件新增的只有时间字段与格式化。
 *
 * ── 数字宽度抖动：**本机实测不需要处理，所以不处理** ────────────────────
 * 倒计时最经典的观感缺陷是"每秒重排一次"（比例字体里 `1` 比 `8` 窄）。
 * 本仓对它的处置是**先量再说**（`.cache/_probe_m30c.qml`，Neutral 主题）：
 *
 *     字体族令牌   family=Inter   monoFamily=JetBrains Mono   pixelSize(sm)=14
 *     逐位宽度     0..9 十个数字**全部 7.640625**（span = 0）
 *     tnum 打开后  同前（十个全部 7.640625）
 *     monoFamily   与 family 量出来**完全相同** → JetBrains Mono 本机没有装，
 *                  回退到了同一个字体
 *
 * 三个结论，每个都反着一条"想当然"：
 *   ① **不抖**。本机解析出来的字体数字本来就是等宽的，span = 0。
 *      "加 mono / 加 tnum 防抖"在这里是**空操作**，卖它等于卖一个
 *      没被验证过的机制。
 *   ② `font.features: {"tnum": 1}` 属性**存在**（探针 B 实测对象可读），
 *      但因为①，它在本机量不出任何差别 —— 一个改变不了任何东西的
 *      开关，无法被证伪，也就不该进契约。
 *   ③ `Theme.font.monoFamily` 在本机是**回退**：拿它当"等宽数字"的手段
 *      是假的（JetBrains Mono 未安装）。这条同时是给 `Body.mono` 的记账：
 *      那个开关在没装等宽字体的机器上不生效，而**没有任何门禁会发现**。
 *
 * 所以本件不加第二个防抖旋钮。宿主若在自己的字体下真的看到抖动，
 * 逃生口是继承来的 `mono: true` 或者宿主自己绑 `font.family`。
 *
 * ── 两条**实测**出来的时序（不写下来下次一定重栽）────────────────────────
 *
 * ① **宿主自己的 `Component.onCompleted` 比本件的更早跑。**
 *    实测（`.cache/_probe_m30e.log`，两次独立跑一致）：在宿主根 Item 的
 *    `Component.onCompleted` 里读 `_ready` 得到 **false**，要等一个
 *    `Qt.callLater` 之后才是 true。也就是说"子项先完成"这个直觉**是错的**。
 *
 *    后果是一条必须写进契约的边界：**挂载期只同步 `_fired`、不发信号**。
 *    在宿主的 `Component.onCompleted` 里改 `now` 造出的跳变会被吞掉。
 *    需要在那里造跳变就包一层 `Qt.callLater`；只是想知道"现在到期没有"，
 *    读 `done` —— 它任何时刻都对。
 *
 *    为什么不干脆去掉这道闸、让挂载期也发：**发在没人听得到的时候的
 *    信号比没有这个信号更坏**。宿主写完 `onFinished:` 却永远收不到，
 *    而屏幕上一切正常。
 *
 * ② **`remainingMs` 的跳变是惰性的 —— "物化"发生在下一次读它的时候。**
 *    于是 `onRemainingMsChanged` 只在有人读之后才跑。真实界面里 `text`
 *    每帧被渲染管线读，走时因此是准的；但**门禁里必须显式读一次
 *    `remainingMs`**，否则那条断言量的是"handler 有没有跑过"，而不是
 *    "值对不对"（探针 D 的第 4 段就是按这条写的，注释里写明了为什么
 *    每次改完 `now` 都要接一次读）。
 *
 * ③ 与②同源、但更阴的一条：**在 `onRemainingMsChanged` 里读派生属性
 *    `done` 会拿到上一次的值**。`done` 是 `remainingMs <= 0` 的绑定，
 *    它的失效还没物化。实测指纹是两对自相矛盾的状态
 *    （`r=0,d=false` 与 `r=1000000,d=true`）—— `d` 永远慢一步，
 *    于是到期那一刻读到 `false`，信号一次都发不出去，而所有属性读数
 *    看着都对。修法：**只读刚刚变了的那个值**（`var r = root.remainingMs`）。
 *
 * ── 不做"最后几秒变红" ─────────────────────────────────────────────────
 * "多久算紧急"是业务知识（3 分钟？10 秒？），组件猜不出来。本件的 `tone`
 * 就是 `Body` 的四种弱化档，要语义色请宿主自己绑 `color` ——
 * 与 `QSkinStatistic` 的 `valueStyle` 不冲突：那里是**数值本身**带语义
 * （涨/跌/告警），这里是**时间**带语义，阈值在业务侧。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Body {
    id: root

    /* ══════════════════════ 时间 ══════════════════════ */

    /** 目标时刻。毫秒时间戳 / `Date` / ISO 串都收（见 `toMillis`）。 */
    property var deadline: 0

    /** **可注入的"现在"**。
     *  `-1`（默认）= 用内部时钟走时；任何别的值 = 冻结在这个时刻。
     *  门禁/抓图一律注入 —— 见文件头。 */
    property var now: -1

    /** 内部时钟的步长（毫秒）。只在**未注入**时有意义。 */
    property int tickInterval: 1000

    /* ══════════════════════ 输出 ══════════════════════ */

    /** `auto`（默认）| `hms` | `dhms` —— 见 `formatRemaining`。
     *  `auto` 在天数 > 0 时切到 `dhms`，其余时候用 `hms`。 */
    property string style: "auto"

    /** 自定义格式化：`function (remainingMs, parts) { return "…" }`。
     *  给了它就完全接管 —— `style` 不再参与。`parts` 是
     *  `{days, hours, minutes, seconds, millis}`。 */
    property var formatter: null

    /** 剩余毫秒数，**下钳到 0**（过期不会给出负数 —— 负数会渲染成
     *  "-1:59:59" 这种看着像 bug 的东西）。 */
    readonly property double remainingMs:
        Math.max(0, root.deadlineMs - root.nowMs)

    /** 目标时刻的毫秒表示。坏入参归 0（见 `toMillis`）。 */
    readonly property double deadlineMs: root.toMillis(root.deadline)

    /** 当前的"现在"（毫秒）。注入优先，否则用内部时钟。 */
    readonly property double nowMs:
        root.injected ? root.toMillis(root.now) : root._clock

    /** 宿主是否注入了 `now`。注入时内部 Timer 停 —— 这是确定性的开关。 */
    readonly property bool injected:
        root.now !== -1 && root.now !== undefined && root.now !== null

    /** 是否已经到期。**这是本件唯一的可读终态** ——
     *  `finished` 是信号，两者不能同名（QML 不允许，见文件头下方）。 */
    readonly property bool done: root.remainingMs <= 0

    /** 内部时钟**此刻是否在走**。它等于「未注入」，但作为独立属性暴露，
     *  是因为门禁要能**直接读到**这件事：`injected` 只说明"拿到了一个值"，
     *  而"Timer 真的停了"是另一回事（比如 `running` 写成常量 true 时，
     *  `injected` 照样对，画面却会一秒一跳）。 */
    readonly property bool ticking: ticker.running

    /* ══════════════════════ 时间字段 ══════════════════════ */

    readonly property int totalSeconds: Math.floor(root.remainingMs / 1000)
    readonly property int millis:   Math.round(root.remainingMs % 1000)
    readonly property int seconds:  root.totalSeconds % 60
    readonly property int minutes:  Math.floor(root.totalSeconds / 60) % 60
    readonly property int hours:    Math.floor(root.totalSeconds / 3600) % 24
    readonly property int days:     Math.floor(root.totalSeconds / 86400)
    /** 小时总数（不折成天）—— `hms` 档用得到，超过 24 会给出 26 这样的数 */
    readonly property int totalHours: Math.floor(root.totalSeconds / 3600)

    /** 到期信号。**上升沿触发一次**，且**只在挂载之后**触发。 */
    signal finished()

    /* ══════════════════════ 显示 ══════════════════════ */

    text: root._format(root.remainingMs)

    /** 走一层本地函数转调宿主的 `formatter`。
     *
     *  ⚠ 为什么不直接在绑定里写 `root.formatter(...)`：`formatter` 是 `var`
     *    属性，qmllint 会报 `use-proper-function`（"它可能是个方法"）。
     *    拆成局部量之后不报，而且「是不是函数」这条守卫也收在一处。
     *    **依赖不受影响**：绑定里调用函数时，函数体内读到的属性照样登记依赖
     *    （这里读到 `formatter` / `parts` / `style`；实参 `remainingMs` 在绑定
     *    那一侧求值）。 */
    function _format(ms) {
        var f = root.formatter
        if (typeof f === "function") return String(f(ms, root.parts))
        return root.formatRemaining(ms, root.style)
    }

    /** 给 `formatter` 的字段包。做成属性而不在调用处现拼，
     *  是为了让自定义格式化的两处实现看到**同一份**字段。 */
    readonly property var parts: ({
        days: root.days, hours: root.hours, minutes: root.minutes,
        seconds: root.seconds, millis: root.millis,
        totalHours: root.totalHours, totalSeconds: root.totalSeconds
    })

    Accessible.role: Accessible.StaticText
    Accessible.name: root.text
    Accessible.description: qsTr("倒计时")

    /* ══════════════════════ 内部时钟 ══════════════════════ */

    /** 内部时钟的当前值。只在 `injected` 为假时被推进。 */
    property double _clock: Date.now()

    /** 到期信号只发一次 —— 上升沿检测。 */
    property bool _fired: false

    /** 挂载完成之前不发信号。
     *
     *  ★ 这一条是**实测逼出来的**：`remainingMs` 是绑定，它在组件构造期间
     *    就会求值一次，于是 `onRemainingMsChanged` 在构造期就跑 —— 那一刻
     *    宿主的 `Connections`（或 `onFinished:`）**还没接上**（兄弟节点的
     *    创建序），信号发出去没人听得见。
     *
     *    一个"发在没人听的时候"的信号比不存在的信号更坏：宿主写完
     *    `onFinished:` 却永远收不到，而且屏幕上一切正常。
     *
     *    所以挂载期**只同步不发**。挂载时就已到期的，请读 `done` ——
     *    含义清楚、任何时刻都能读。 */
    property bool _ready: false

    Timer {
        id: ticker

        /* ★ 注入即停。这就是"会自己变的控件"与"可抓的控件"之间的那一个开关。 */
        running: !root.injected
        interval: root.tickInterval
        repeat: true

        onTriggered: root._clock = Date.now()
    }

    onRemainingMsChanged: {
        /* ★ **只读刚刚变了的那个值**，绝不读 `done`。
         *
         *   `done` 是 `remainingMs <= 0` 的派生绑定，而 QML 的绑定求值是
         *   **惰性**的：在这个通知处理器里读 `done`，拿到的是**上一次**的
         *   值 —— 它自己的失效还没被物化。实测指纹（临时诊断打出的四次
         *   执行序，`.cache/_probe_m30e.log`）：
         *
         *       [r=1000000, d=false]   ← 构造期，自洽
         *       [r=0,       d=false]   ← **r 与 d 自相矛盾**
         *       [r=1000000, d=true ]   ← 又矛盾，且 d 正好是上一行的答案
         *       [r=0,       d=false]   ← 同样滞后一步
         *
         *   后三行每行都是"`r` 是新的、`d` 是上一行的 `r` 判出来的"。
         *   于是 `done` 永远慢一拍，到期那一刻 `done` 读出来还是 false，
         *   走了 else 分支把 `_fired` 清掉 —— **`finished` 一次都发不出来**，
         *   而所有属性读数看着都对（`done` 自己下次被读时是 true）。
         *
         *   这条与本项目反复栽过的「onValueChanged 里读派生属性拿到上一次的
         *   值」是同一个坑，只是这次它藏在一个**信号**后面：屏幕上没有
         *   任何异常，只有"宿主写了 onFinished 却永远收不到"。 */
        if (!root._ready) return
        var r = root.remainingMs
        if (r <= 0) {
            if (!root._fired) { root._fired = true; root.finished() }
        } else {
            root._fired = false
        }
    }

    /* 切换到注入态时把内部时钟对齐到注入值：否则"先自走、后注入"的场景
     * 会在切换的那一帧里先读一次旧的 `_clock`，画面闪一下。
     * 反过来（先注入、后取消注入）不能对齐 —— 那要用真实的当前时间。 */
    onInjectedChanged: {
        if (root.injected) root._clock = root.toMillis(root.now)
    }

    Component.onCompleted: {
        if (root.injected) root._clock = root.toMillis(root.now)
        /* 同步起始态，**不发信号**（见 `_ready` 的说明）。
         * 这里同样直接读 `remainingMs` 而不是 `done` —— 同一个惰性理由，
         * 只是这里是构造期，滞后一步的后果是"起始态判反"。 */
        root._fired = root.remainingMs <= 0
        root._ready = true
    }

    /* ══════════════════════ 纯函数（公开，给门禁直接喂输入）══════════════ */

    /**
     * toMillis(v) → number
     *
     * 毫秒时间戳 / `Date` / ISO 串 / 别的什么都收：
     *   · 有限数 → 原样
     *   · `Date` → `getTime()`
     *   · 字符串 → `Date.parse()`；解不出来的 **归 0**，不返回 NaN
     *   · 其余（null / undefined / 对象）→ 0
     *
     * 为什么不把 NaN 透出去：NaN 会一路变成 `"NaN:NaN:NaN"` 显示在屏幕上，
     * 而 0 会变成 `00:00:00` + 到期。**两个都是错的，但要选错得看得见的
     * 那一个** —— 与 `Slots.install` 对未知插槽名打 warn 同源：
     * 静默通过是最危险的一种通过。
     */
    function toMillis(v) {
        if (v === null || v === undefined) return 0
        if (typeof v === "number") return isFinite(v) ? v : 0
        if (typeof v === "string") {
            var t = Date.parse(v)
            return isFinite(t) ? t : 0
        }
        if (typeof v.getTime === "function") {
            var g = v.getTime()
            return isFinite(g) ? g : 0
        }
        return 0
    }

    /**
     * formatRemaining(ms, style) → string
     *
     * 两档，都不是 locale 相关的（理由同 `QSkinStatistic.groupDigits`：
     * 一个设计系统的数字格式不能随机器变）：
     *
     *     hms   →  "HH:MM:SS"，小时**不折天**（26:00:00 是合法的）
     *     dhms  →  "D:HH:MM:SS"，天不补零
     *     auto  →  天数 > 0 时 dhms，否则 hms
     *
     * 负数**下钳到 0**（与 `remainingMs` 同一条）。`00:00:00` 而不是乱码。
     */
    function formatRemaining(ms, style) {
        var total = isFinite(ms) && ms > 0 ? Math.floor(ms / 1000) : 0
        var s = total % 60
        var m = Math.floor(total / 60) % 60
        var h = Math.floor(total / 3600) % 24
        var d = Math.floor(total / 86400)
        var hAll = Math.floor(total / 3600)

        var two = function (n) { return (n < 10 ? "0" : "") + n }

        var st = style
        if (st === "auto" || st === undefined || st === null)
            st = d > 0 ? "dhms" : "hms"

        if (st === "dhms") return d + ":" + two(h) + ":" + two(m) + ":" + two(s)
        return two(hAll) + ":" + two(m) + ":" + two(s)
    }
}
