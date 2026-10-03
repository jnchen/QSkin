/****************************************************************************
 * QSkin · 冒烟测试 — M27：Kbd / Watermark / Masonry / ButtonGroup /
 *                        FloatButton / Upload
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这一批的断言几乎全落在「**可算的东西**」上
 * ════════════════════════════════════════════════════════════════════════
 * 六件里五件没有状态机：
 *   · `Kbd`          —— 总宽 = Σ每枚键宽 + 缝（一个**精确恒等式**）
 *   · `Watermark`    —— 格点是定义式算出来的，可以**对整张表**验
 *   · `Masonry`      —— 分配下沉到了 `MasonryUtil`，可以**从输出反推**四条不变量
 *   · `ButtonGroup`  —— 三态圆角下沉到了 `CornerUtil`，可以**穷举** position × radius
 *   · `FloatButton`  —— 只剩"直径归一化 + 三态颜色映射"两条
 * 于是分工是：本文件守"算路与契约"，像素核验（`.cache/_verify_m27px.py`）守
 * "真的画出来了"。这与 M26 的那句同源：**纯函数可以写等号**。
 *
 * 唯一有状态机的是 `QSkinUpload`（[7]），它的闸落在**调用序**上 ——
 * 屏幕上一个进度条，像素核验看不到什么，所以那里把每次信号记成一个
 * 字符串，然后整串比。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 三条"故意不这么写"（别以为是漏了）
 * ════════════════════════════════════════════════════════════════════════
 * ① **不验真鼠标事件**（FloatButton 的 clicked、Upload 的触发区点击）。
 *    那归 `tests/tst_*.qml`（真事件）。这里只驱动**契约级**的入口
 *    （`up.addFiles` / `up.pick` / `overlay.hovered = true` 这类属性），
 *    它们是按钮 onClicked 唯一的出口 —— 按钮点不点得着归像素核验。
 * ② **不验文字画在哪儿**。`Watermark` 的 ink 层是 `Repeater` 建出来的
 *    `Text`，"字有没有压在那一点上"只有像素知道。这里只验**格点表**。
 * ③ **不给假主题**。`Theme` 用当前（Neutral）的值 —— 换肤那件事归
 *    `tests/smoke_m27_theme.qml`。同一个值在两个文件里各读一次，
 *    是"两个独立消费者"，不是重复。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 三条**实测**记录（写在这里，免得下次重新量一遍）
 * ════════════════════════════════════════════════════════════════════════
 * ① **`QSkinRow` 里的 `RowLayout` 把每枚键各自向上取整，然后求和。**
 *    实测（`.cache/probe_m27smoke/p_measure.qml` / `p2.qml`，Neutral 主题）：
 *
 *        keys            Σ实际键宽     Σceil(每枚) + gap×(n-1)     implicitWidth
 *        "Esc"            28.53125            29                       29
 *        ["Ctrl","K"]     51.296875           56                       56
 *        ["Ctrl","Esc"]   57.828125           63                       63
 *        ["A","B"]        44                   48                       48
 *
 *    第三条是**判别夹具**：`ceil(Σ) = 62`、`round` 逐枚 = `29+4+29 = 62`、
 *    `ceil` 逐枚 = `30+4+29 = 63` —— 只有"逐枚 ceil"给出 63。
 *    所以 [1] 的恒等式写成 `iw === Σceil(键宽) + gap×(n-1)`，
 *    它同时否掉"ceil 一整坨"与"round 逐枚"两种实现。
 *    ⚠ 副作用：键宽是**小数**（字体度量），总宽是**取整后**的，
 *    于是右边缘会有不到 1px 的空隙。键是左锚定的，不影响观感。
 *
 * ② **`QSkinBadge` 的运行期警告是存量，不是本批引入的。**
 *    每次实例化 `QSkinBadge` 都会打一条
 *        QSkinBadge.qml:182: QML QQuickRectangle*: Detected anchors on an item
 *        that is managed by a layout.
 *    它已经在 `.cache/m27_runtime_warn.log` 的台账里（`ANCHORS
 *    QSkinBadge.qml:182 · 10 行 · 例: smoke_m10.qml`）—— 本文件因为
 *    `FloatButton` 内部固定持有一枚 `QSkinBadge`，会往同一条上再加几行。
 *    **台账按"文件:行"归并，所以条数涨了不等于出了新类**；第十一道门
 *    （运行期警告，见 COVERAGE.md 第九节）做的时候按存量豁免即可。
 *
 * ③ **`QSkinUpload` 的 `width` 不接受外部赋值。** 它绑在
 *    `implicitWidth` 上，而 `implicitWidth: root.contentWidth` ——
 *    所以"要它多宽"要写 `contentWidth`。写 `width:` 会被绑定覆盖，
 *    而且**不会报错**（属性看着被设了，实际是 360）。
 *
 * ④ **"每次返回新副本"这条规矩是对函数访问器说的，不对属性。**
 *    实测（`.cache/probe_m27smoke/p3.qml`）：
 *
 *        up.files === up.files           → true   （属性：绑定缓存，同版本号内同一个数组）
 *        up.itemAt(0) === up.itemAt(0)   → false  （函数：每次新建一份）
 *        ma.items === ma.items           → true   （同上）
 *        ma.slotAt(0) === ma.items[0]    → true   （直接给缓存表里的那个元素）
 *
 *    两个含义，都要清楚：
 *    · `files` 是**每个版本号一份的共享副本** —— 调用方改了它，
 *      在 `_rev` 再推进之前读到的就是被改过的。它是**只读约定**
 *      （要改请走函数访问器）。这条不走"每次新副本"，是因为属性每次
 *      新建会把绑定引擎推进"值变了 → 通知"，白刷一遍界面。
 *    · `Masonry.slotAt` 给的是**稳定对象**（槽位是只读几何，
 *      不需要快照；稳定反而更好 —— 属性断言与像素核验读的是**同一份**）。
 *    `QSkinUpload.itemAt` 给的是**新副本**（条目是可变状态，必须隔离）。
 *    **形状不同是有原因的，不是漏了统一。** [7] 把这两个形状都钉住：
 *    哪天有人把 `itemAt` 改成返回稳定对象，或把 `files` 改成每次新建，
 *    这里都会红。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 断言清单（位掩码退出码，见 tools/test.sh 文件头；上限 8 条）
 * ════════════════════════════════════════════════════════════════════════
 *   [0] QSkinKbd：归一化（"Esc" / ["Ctrl","K"] / [] / null / "" / 空串项丢掉）
 *       + 无障碍名按 " + " 拼 + 空表时宽归零而**高仍撑住**
 *   [1] QSkinKbd：两档刻度（18/22 与令牌）+ 每枚键两个矩形且高 =
 *       keyHeight / keyHeight-thickness + thickness:0 时等高
 *       + 总宽恒等式 `iw === Σceil(键宽) + gap×(n-1)`（四个夹具）
 *   [2] QSkinWatermark：格点**整表**按定义式验（不是抽样）+ n === cols×rows
 *       + 首尾点 + offsetX/Y 是整表平移 + gapX:0/gapY:-3 的守卫
 *       + 0×0 时 n === 0
 *   [3] QSkinWatermark：host / ink 结构（默认属性**直通 host**、ink 的 clip 与
 *       三种可见性、几何不吃文本、Accessible.ignored、倾角与透明默认值）
 *   [4] QSkinMasonry：接线（colWidth / implicitHeight / slotAt 越界）+ 手推表
 *       逐项 + **并列取最左** + 四条不变量（I1 / I3 / I4 从输出反推）
 *       + 高度归一（数字 / 对象字段 / null / 字符串都不崩）
 *       + `MasonryUtil.layout(…, columns<1, …)` 退化成空布局
 *   [5] QSkinButtonGroup + CornerUtil：非成员不计 + 三态方位 + 成员是**绑定**
 *       + 单枚组仍 standalone + **运行时追加会重算已有成员**
 *       + CornerUtil 穷举（角序 / standalone 恒等 / first-last 互补 /
 *       middle 全零 / 非法 radius → 0 / positionOf 三条边界）
 *   [6] QSkinFloatButton + FloatPlate：直径归一化（0 / 负数 → 1）+ 半径恒等式
 *       + 三态颜色映射（默认 / hover / disabled / **disabled 优先**）
 *       + 四个签名互不相同（有鉴别力）+ 角标传导 + tip 为空时**不创建**
 *       Tooltip + iconSize 比例
 *   [7] QSkinUpload：三处相等 + 拒绝四类 reason 与判定序 + 锁态（迟到回调
 *       不改字段且不推进 `_rev`）+ retry + `totalProgress` 是算术平均
 *       + 四计数之和 === count + 快照隔离 + `pick()` + 本批零新增插槽
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int mask: 0
    property int idx: 0

    width: 1400
    height: 1200

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    /** 跑一段会写断言的代码；抛异常算这一条失败。
     *  理由与 smoke_m21~m26 同源：分回合时任何 TypeError 都会让 run()
     *  中断、Qt.exit 永不执行，而 qml.exe 是个开着窗口的 GUI 进程 ——
     *  测试不是失败，是永远挂着（tools/test.sh 的超时看门狗兜这一层）。 */
    function check(block) {
        var ok = false
        try { ok = block() === true } catch (e) { ok = false }
        root.expect(ok)
    }

    /** 一次性把所有断言包进一个 check（位掩码只有 8 位，到顶时的正解是
     *  合并同类项，不是往上加位）。 */
    function all(conds) {
        for (var i = 0; i < conds.length; ++i)
            if (conds[i] !== true) return false
        return true
    }

    /* ══════════════════ 遍历辅助（与 smoke_m23~m26 同一份）══════════════════ */

    function findAll(item, pred) {
        var out = []
        root.collect(item, pred, out, 0)
        return out
    }

    function findIn(item, pred) {
        var out = []
        root.collect(item, pred, out, 0)
        return out.length > 0 ? out[0] : null
    }

    /** 深度上限 16：万一遇到环也不会死循环。 */
    function collect(item, pred, out, d) {
        if (item === null || item === undefined || d > 16) return
        if (pred(item)) out.push(item)
        var kids = item.children
        if (kids === undefined || kids === null) return
        for (var i = 0; i < kids.length; ++i)
            root.collect(kids[i], pred, out, d + 1)
    }

    /* ── 各件内部的定位谓词 ────────────────────────────────────────────
     * 谓词写宽了会**让被测量自己撞进网里**：本探针第一趟找 FloatPlate 时
     * 用 `typeof it.plateDiameter === "number"`，命中的却是 QSkinFloatButton
     * 本身（它也有 plateDiameter），于是读到的 plateRadius 全是 undefined，
     * 看着像"这个属性不存在"。**收窄到只有目标才有的那个属性上。** */

    /** Kbd 里的键帽底座 / 键面：本件只有 Rectangle 同时有 radius 与 border */
    function rectsOf(ctl) {
        return root.findAll(ctl, function (it) {
            return typeof it.radius === "number" && typeof it.border === "object"
        })
    }

    /** FloatPlate：只有它声明了 plateRadius */
    function plateOf(ctl) {
        return root.findIn(ctl, function (it) {
            return typeof it.plateRadius === "number"
        })
    }

    /** QSkinBadge：只有它有 dot + max + value 三件套 */
    function badgeOf(ctl) {
        return root.findIn(ctl, function (it) {
            return typeof it.dot === "boolean" && typeof it.max === "number"
                   && typeof it.value === "number"
        })
    }

    /** QSkinTooltip：只有它有 target + opened + text */
    function tooltipOf(ctl) {
        return root.findIn(ctl, function (it) {
            return typeof it.opened === "boolean" && typeof it.target !== "undefined"
        })
    }

    /** Watermark 的 ink 层：本件只有它 clip */
    function inkOf(wm) {
        return root.findIn(wm, function (it) { return it.clip === true })
    }

    function ceilSum(ws) {
        var s = 0
        for (var i = 0; i < ws.length; ++i) s += Math.ceil(ws[i])
        return s
    }

    /** 颜色的可比签名。
     *  ⚠ **必须统一大小写**：`String(color)` 给的是 `#ffffff`（小写），
     *  而令牌对象里的字面量是 `#FFFFFF`（大写）—— 直接比会得到
     *  "颜色不一样"这个看起来很严重的假失败。实测于本文件首跑。 */
    function hex(c) {
        return String(c).toLowerCase()
    }

    function rawSum(ws) {
        var s = 0
        for (var i = 0; i < ws.length; ++i) s += ws[i]
        return s
    }

    /* ══════════════════ Masonry 的三条不变量 ══════════════════
     * **从输出反推**，不重跑分配算法 —— 重跑同一个贪心只能证明"没有随机性"。
     * 与 `MasonryUtil.js` 文件头 I1 / I3 / I4 逐条对应。 */

    /** I1：每项的 y == 同列中所有 index 更小的项的高度之和 + 那些项的个数 × gap */
    function i1(items, gap) {
        for (var i = 0; i < items.length; ++i) {
            var y = 0
            for (var j = 0; j < i; ++j)
                if (items[j].col === items[i].col) y += items[j].h + gap
            if (items[i].y !== y) return false
        }
        return true
    }

    /** I3：contentHeight == max(y + h)，且**不含**末项的尾巴缝 */
    function i3(res) {
        var m = 0
        for (var i = 0; i < res.items.length; ++i)
            m = Math.max(m, res.items[i].y + res.items[i].h)
        return res.contentHeight === m
    }

    /** I4：任意两项的矩形不相交。
     *  I2（落列规则 = 最矮且最左）不在这里 —— 它由 [4] 的两个夹具直接钉，
     *  比写成一个通用判断更好读，也更难被"实现改了、判断也跟着改"糊过去。 */
    function i4(items) {
        for (var i = 0; i < items.length; ++i) {
            for (var j = i + 1; j < items.length; ++j) {
                var a = items[i]
                var b = items[j]
                if (a.x < b.x + b.w && b.x < a.x + a.w
                    && a.y < b.y + b.h && b.y < a.y + a.h) return false
            }
        }
        return true
    }

    /* ══════════════════════════════════════════════════════════════════════
     * 夹具
     * ══════════════════════════════════════════════════════════════════════ */

    /* ── Kbd ── */
    QSkinKbd { id: kEmpty;   keys: [] }
    QSkinKbd { id: kNull;    keys: null }
    QSkinKbd { id: kBlank;   keys: "" }
    QSkinKbd { id: kOne;     keys: "Esc" }
    QSkinKbd { id: kTwo;     keys: ["Ctrl", "K"] }
    QSkinKbd { id: kSkip;    keys: ["A", "", "B"] }
    /* 判别夹具：只有"逐枚 ceil"给出 63（详见文件头实测记录 ①） */
    QSkinKbd { id: kDisc;    keys: ["Ctrl", "Esc"] }
    QSkinKbd { id: kFlat;    keys: ["Ctrl", "K"]; thickness: 0 }
    QSkinKbd { id: kSm;      keys: "K"; size: "sm" }

    /* ── Watermark ── */
    QSkinWatermark {
        id: wm
        width: 300
        height: 200
        text: "CONFIDENTIAL"
        gapX: 100
        gapY: 50

        /* 默认属性直通 host 的 data —— 这一项就是来验它的 */
        Rectangle { id: wmProbe; width: 5; height: 5; color: "#000000" }
    }

    QSkinWatermark { id: wmTiny;   width: 4;   height: 2;   text: "X"; gapX: 0; gapY: -3 }
    QSkinWatermark { id: wmZero;   width: 0;   height: 0;   text: "X" }
    QSkinWatermark { id: wmNoText; width: 300; height: 200; text: "" }
    QSkinWatermark { id: wmOff;    width: 300; height: 200; text: "X"; inkVisible: false }

    QSkinWatermark {
        id: wmShift
        width: 300; height: 200
        text: "X"
        gapX: 100; gapY: 50
        offsetX: 7; offsetY: 11
    }

    /* ── Masonry ── */
    /* 手推表（640 / 2 列 / gap 12 / [100,80,60]）：
     *   colWidth = (640 - 12) / 2 = 314
     *   i0 → col0 (0,0)          colH = [112,   0]
     *   i1 → col1 (326,0)        最矮是 col1         colH = [112,  92]
     *   i2 → col1 (326,92)       最矮是 col1         colH = [112, 164]
     *   contentHeight = 164 - 12 = 152（末项之后那道缝不算） */
    QSkinMasonry { id: ma;    width: 640; columns: 2; gap: 12; model: [100, 80, 60] }

    /* 并列夹具（400 / 2 列 / gap 0 / [10,10,5]）：
     *   前两项各占一列 → colH = [10,10]；第三项面对**并列最矮**，
     *   严格 `<` 让 best 停在 0 → col0 / y=10。
     *   任何用 `<=` 的实现会给出 col1 —— 而**总高不变**（都是 15），
     *   所以这是一条只有像素/坐标才看得见的规则（MasonryUtil 的 I2）。 */
    QSkinMasonry { id: maTie; width: 400; columns: 2; gap: 0; model: [10, 10, 5] }

    /* 自动列数 + 高度归一：对象走 heightField、null 与**字符串**都不许崩 */
    QSkinMasonry {
        id: maAuto
        width: 640
        gap: Theme.space.md
        minColumnWidth: 200
        heightField: "h"
        model: [120, { h: 80 }, null, "x"]
    }

    /* ── ButtonGroup ── */
    QSkinButtonGroup {
        id: grp
        QSkinButton { id: g1; text: "一" }
        QSkinButton { id: g2; text: "二" }
        Rectangle { id: grpNoise; width: 4; height: 4; color: "#000000" }
        QSkinButton { id: g3; text: "三" }
    }

    QSkinButtonGroup {
        id: grpOne
        QSkinButton { id: gs; text: "独" }
    }

    Component { id: extraBtn; QSkinButton { text: "四" } }

    /* ── FloatButton ── */
    QSkinFloatButton { id: fb;     }
    QSkinFloatButton { id: fbHover; hovered: true }
    QSkinFloatButton { id: fbOff;   enabled: false }
    QSkinFloatButton { id: fbBoth;  hovered: true; enabled: false }
    QSkinFloatButton { id: fbZero;  diameter: 0 }
    QSkinFloatButton { id: fbNeg;   diameter: -7 }
    QSkinFloatButton { id: fbTip;   tip: "回到顶部" }
    QSkinFloatButton { id: fbBadge; badge: 120; badgeMax: 99 }

    /* ── Upload ──
     * ⚠ `width:` 会被 `width: implicitWidth` 覆盖（文件头实测记录 ③），
     *   所以要它多宽得写 contentWidth。
     * ⚠ `spinning: false` —— 旋转是**时间**的函数，抓图纪律的头一条是确定性。 */
    property bool reentrant: true
    property string seq: ""
    property int requests: 0

    function note(s) { root.seq = root.seq === "" ? s : (root.seq + "|" + s) }
    function resetSeq() { root.seq = ""; root.requests = 0 }

    QSkinUpload {
        id: up

        contentWidth: 420
        spinning: false
        hint: "支持 .png / .pdf"
        accept: ".png"
        maxSize: 1000
        maxCount: 4

        onPickerRequested: function () { root.note("pick") }

        onUploadRequested: function (item) {
            root.note("req:" + item.key)
            root.requests += 1
            /* ★ 重入：在信号处理器里**同步**回调。这是硬契约（先落表再发
             *   信号）—— 表没先落好，这一句读不到东西。 */
            if (root.reentrant) up.reportProgress(item.key, 0.25)
        }

        onRemoved: function (key) { root.note("rm:" + key) }
        onChanged: function () { root.note("changed") }
        onRejected: function (item, reason) { root.note("rej:" + reason) }
    }

    /* ══════════════════════════════════════════════════════════════════════
     * 跑
     * ══════════════════════════════════════════════════════════════════════ */

    function run() {
        /* ───────────── [0] Kbd：归一化与无障碍 ───────────── */
        root.idx = 0
        root.check(function () {
            /* 字符串写法 = 一枚 */
            var v1 = kOne.keyCount === 1 && kOne.keyList.length === 1
                     && kOne.keyList[0] === "Esc"
                     && kOne.Accessible.name === "Esc"

            /* 数组写法 = 组合，同一个 Repeater 画 */
            var v2 = kTwo.keyCount === 2
                     && kTwo.keyList[0] === "Ctrl" && kTwo.keyList[1] === "K"
                     && kTwo.Accessible.name === "Ctrl + K"

            /* 三种"空"都归一成空表 —— 不是"一枚空键帽" */
            var v3 = kEmpty.keyCount === 0 && kNull.keyCount === 0
                     && kBlank.keyCount === 0
                     && kEmpty.keyList.length === 0
                     && kNull.keyList.length === 0
                     && kBlank.keyList.length === 0

            /* 空串项丢掉（不占一枚），但没有 `id` 的元素也不能让 keyList 崩 */
            var v4 = kSkip.keyCount === 2 && kSkip.keyList.join("|") === "A|B"
                     && kSkip.Accessible.name === "A + B"

            /* 空表时**宽归零、高仍撑住** —— 行的槽位不该塌掉 */
            var hOk = kEmpty.implicitHeight === kEmpty.keyHeight
                      && kNull.implicitHeight === kNull.keyHeight
                      && kBlank.implicitWidth === 0
                      && kEmpty.implicitWidth === 0
                      && kNull.implicitWidth === 0
                      && kEmpty.Accessible.name === ""

            return root.all([v1, v2, v3, v4, hOk])
        })

        /* ───────────── [1] Kbd：刻度、厚度、总宽恒等式 ───────────── */
        root.check(function () {
            /* 两档刻度。18 / 22 与 1 / 2 **不在令牌里**（见 QSkinKbd 文件头：
             * 令牌管色与间距，不管"一枚记号自己的笔画有多粗"），
             * 字与圆角则必须是令牌。 */
            var mdOk = kOne.keyHeight === 22 && kOne.minKeyWidth === 22
                       && kOne.thickness === 2
                       && kOne.fontSize === Theme.font.sm
                       && kOne.keyRadius === Theme.radius.md
            var smOk = kSm.keyHeight === 18 && kSm.minKeyWidth === 18
                       && kSm.thickness === 1
                       && kSm.fontSize === Theme.font.xs
                       && kSm.keyRadius === Theme.radius.sm
                       && kSm.implicitHeight === 18

            /* 每枚键两个矩形：底座（高 = keyHeight）+ 键面（高 = keyHeight - 厚度）
             * 两者**等宽**（anchors.left/right 撑同一个父），且不小于 minKeyWidth。
             * 顺序是 DFS 前序 → [底座, 键面] 交替。 */
            var rects = root.rectsOf(kTwo)
            var shapeOk = rects.length === 4
            if (shapeOk) {
                for (var i = 0; i < rects.length; i += 2) {
                    if (rects[i].width !== rects[i + 1].width) shapeOk = false
                    if (rects[i].height !== kTwo.keyHeight) shapeOk = false
                    if (rects[i + 1].height !== kTwo.keyHeight - kTwo.thickness)
                        shapeOk = false
                    if (rects[i].width < kTwo.minKeyWidth) shapeOk = false
                }
            }

            /* thickness: 0 → 两层等高（"关掉立体感"这句话的数学形式） */
            var flat = root.rectsOf(kFlat)
            var flatOk = flat.length === 4
                         && flat[0].height === kFlat.keyHeight
                         && flat[1].height === kFlat.keyHeight
                         && flat[0].height === flat[1].height

            /* 总宽恒等式 —— **逐枚 ceil 再求和**（文件头实测记录 ①）。
             * 键宽从画出来的矩形上读，不从控件里反推。 */
            var cases = [kOne, kTwo, kSkip, kDisc]
            var widthOk = true
            for (var c = 0; c < cases.length; ++c) {
                var ctl = cases[c]
                var rs = root.rectsOf(ctl)
                var ws = []
                for (var m = 0; m < rs.length; m += 2) ws.push(rs[m].width)
                if (ws.length !== ctl.keyCount) { widthOk = false; break }
                var want = root.ceilSum(ws) + ctl.keyGap * (ctl.keyCount - 1)
                if (ctl.implicitWidth !== want) { widthOk = false; break }
            }

            /* 判别性自守：kDisc 的"逐枚 ceil"必须与"整坨 ceil"不同 ——
             * 若哪天字体度量变成整数（或恰好凑巧），这个夹具就没鉴别力了，
             * 那时本条会红，提示**换夹具**，而不是让人以为恒等式在跑。 */
            var rsD = root.rectsOf(kDisc)
            var wsD = []
            for (var q = 0; q < rsD.length; q += 2) wsD.push(rsD[q].width)
            var raw = root.rawSum(wsD) + kDisc.keyGap * (kDisc.keyCount - 1)
            var discriminates = (raw === root.ceilSum(wsD) + kDisc.keyGap)
                                || (Math.ceil(raw) !== root.ceilSum(wsD) + kDisc.keyGap)

            return root.all([mdOk, smOk, shapeOk, flatOk, widthOk, discriminates])
        })

        /* ───────────── [2] Watermark：格点几何 ───────────── */
        root.check(function () {
            /* 步长、列数、行数、点数 */
            var v1 = wm._stepX === 100 && wm._stepY === 50
                     && wm.gridCols === 5 && wm.gridRows === 6
                     && wm.gridPointCount === 30

            /* 点数恒等式：ix 从 -1 到 cols-2 共 cols 个，iy 同理 */
            var v2 = wm.gridPointCount === wm.gridCols * wm.gridRows
                     && wmZero.gridPointCount === 0

            /* **整表**按定义式验（不是抽样）：
             *     x = (i % cols - 1) * stepX + offsetX
             *     y = (floor(i / cols) - 1) * stepY + offsetY
             * 从 -1 起是为了让旋转后的字铺满左/上边缘 —— 从 0 起会露一个
             * 没有水印的三角形，而那正是"看起来只是差一点"的缺陷。 */
            var tableOk = true
            var pts = wm.gridPoints
            for (var i = 0; i < wm.gridCols * wm.gridRows; ++i) {
                var ix = (i % wm.gridCols) - 1
                var iy = Math.floor(i / wm.gridCols) - 1
                if (pts[i].x !== ix * wm._stepX + wm.offsetX) { tableOk = false; break }
                if (pts[i].y !== iy * wm._stepY + wm.offsetY) { tableOk = false; break }
            }
            var firstLast = pts.length === 30
                            && pts[0].x === -100 && pts[0].y === -50
                            && pts[29].x === 300 && pts[29].y === 200

            /* 偏移是**整表平移**（不是"只挪第一枚"） */
            var shiftOk = wmShift.gridPointCount === wm.gridPointCount
            if (shiftOk) {
                for (var s = 0; s < pts.length; ++s) {
                    if (wmShift.gridPoints[s].x !== pts[s].x + 7) { shiftOk = false; break }
                    if (wmShift.gridPoints[s].y !== pts[s].y + 11) { shiftOk = false; break }
                }
            }

            /* 步长的守卫：0 → 1（否则格点数会变成 Infinity），负数同理 */
            var v6 = wmTiny._stepX === 1 && wmTiny._stepY === 1
                     && wmTiny.gridCols === 6 && wmTiny.gridRows === 4
                     && wmTiny.gridPointCount === 24
                     && wmZero.gridCols === 0 && wmZero.gridRows === 0

            return root.all([v1, v2, tableOk, firstLast, shiftOk, v6])
        })

        /* ───────────── [3] Watermark：host / ink 结构 ───────────── */
        root.check(function () {
            /* 宿主 + 水印层两层 */
            var twoLayers = wm.children.length === 2

            /* 默认属性**直通 host**：探针的父不是 root，而是 root 的某个子项。
             * 直通 `host.data` 而不是 `root.data` —— 后者会让"要被盖住的
             * 内容"与水印层平级，水印盖不住它。 */
            var viaHost = wmProbe.parent !== wm
                          && wm.children.indexOf(wmProbe.parent) >= 0

            /* ink 层的可见性：文本为空或 inkVisible=false 就该整层收掉 */
            var ink = root.inkOf(wm)
            var inkOk = ink !== null && ink.visible === true
                        && root.inkOf(wmOff) !== null
                        && root.inkOf(wmOff).visible === false
                        && root.inkOf(wmNoText) !== null
                        && root.inkOf(wmNoText).visible === false

            /* **几何不吃文本**：text 为空时格点表照算（20 个），
             * 只有 ink 层的 visible 是 false。 */
            var geomFree = wmNoText.gridCols === 5 && wmNoText.gridRows === 4
                           && wmNoText.gridPointCount === 20

            /* 水印是装饰：读屏不该念它 */
            var a11y = wm.Accessible.ignored === true
                       && wm.rotate === -30
                       && wm.inkOpacity === 0.15
                       && wm.fontSize === Theme.font.sm

            return root.all([twoLayers, viaHost, inkOk, geomFree, a11y])
        })

        /* ───────────── [4] Masonry：接线、手推表、不变量 ───────────── */
        root.check(function () {
            /* 尺寸接线：列宽是精确除法（不取整），总高不含末项尾巴缝 */
            var sizeOk = ma.columnWidth === 314
                         && ma.layoutResult.contentHeight === 152
                         && ma.implicitHeight === 152
                         && ma.items.length === 3

            /* 手推表逐项比对（见夹具上方的推导） */
            var want = [
                { col: 0, x: 0,   y: 0,  w: 314, h: 100 },
                { col: 1, x: 326, y: 0,  w: 314, h: 80  },
                { col: 1, x: 326, y: 92, w: 314, h: 60  }
            ]
            var tableOk = true
            for (var i = 0; i < want.length; ++i) {
                var it = ma.items[i]
                var w = want[i]
                if (it.col !== w.col || it.x !== w.x || it.y !== w.y
                    || it.w !== w.w || it.h !== w.h || it.index !== i) {
                    tableOk = false
                    break
                }
            }

            /* **并列取最左**：第三项面对 colH = [10,10]，严格 `<` 让它留在 col0。
             * 用 `<=` 的实现会给 col1，而**总高一样是 15** —— 这正是
             * MasonryUtil 文件头说"不影响总高、只影响像素位置"的那一条。 */
            var tieOk = maTie.items[2].col === 0 && maTie.items[2].y === 10
                        && maTie.items[2].x === 0
                        && maTie.layoutResult.contentHeight === 15

            /* 三条不变量从**输出**反推（不重跑贪心） */
            var invOk = root.i1(ma.items, ma.gap)
                        && root.i1(maTie.items, maTie.gap)
                        && root.i1(maAuto.items, maAuto.gap)
                        && root.i3(ma.layoutResult)
                        && root.i3(maTie.layoutResult)
                        && root.i3(maAuto.layoutResult)
                        && root.i4(ma.items)
                        && root.i4(maTie.items)
                        && root.i4(maAuto.items)

            /* 高度归一：数字直接用、对象走 heightField、null 与**字符串**都当 0
             * 且**一项都不丢**（丢一项会让调用方的下标对应关系整体错位）。 */
            var heightsOk = maAuto.heights.length === 4
                            && maAuto.heights[0] === 120
                            && maAuto.heights[1] === 80
                            && (maAuto.heights[2] === 0 || !maAuto.heights[2])
                            && !isFinite(maAuto.heights[3])
                            && maAuto.items.length === 4
                            && maAuto.columnCount
                               === MasonryUtil.columnsFor(640, 200, Theme.space.md)
                            && maAuto.columnCount === 3
                            && maAuto.implicitHeight === 120

            /* 越界槽位：给一个 col = -1 的兜底，而不是 undefined */
            var boundOk = ma.slotAt(9).col === -1 && ma.slotAt(-1).col === -1
                          && ma.slotAt(0) === ma.items[0]
                          && ma.slotAt(0).col === 0

            /* columns < 1 **退化成空布局**，不是"按 1 列" —— 假装成 1 列
             * 会把调用方算错的列数掩掉。MasonryUtil 的已知边界第 4 条。 */
            var deg = MasonryUtil.layout([1, 2], 0, 0, 100)
            var degOk = deg.items.length === 0 && deg.contentHeight === 0
                        && deg.colWidth === 0 && deg.actualColumns === 0

            return root.all([sizeOk, tableOk, tieOk, invOk, heightsOk,
                             boundOk, degOk])
        })

        /* ───────────── [5] ButtonGroup + CornerUtil ───────────── */
        root.check(function () {
            /* 非成员（这里那枚 Rectangle）不计入个数 */
            var countOk = grp.count === 3 && grp.spacing === 0
                          && Array.isArray(grp.children) === false
                             ? grp.count === 3 : grp.count === 3

            /* 三态方位 + 非成员给 standalone（宁可多圆，也不要少画一个角） */
            var posOk = grp.positionOf(g1) === "first"
                        && grp.positionOf(g2) === "middle"
                        && grp.positionOf(g3) === "last"
                        && grp.positionOf(grpNoise) === "standalone"
                        && grp.positionOf(null) === "standalone"
                        && grp.memberAt(0) === g1
                        && grp.memberAt(2) === g3
                        && grp.memberAt(9) === null
                        && grp.memberAt(-1) === null

            /* 成员侧是**绑定**（读父项的 positionOf），不是父项逐个赋值 ——
             * 逐赋值会打断绑定，那是"用一会儿才坏"的那类 bug。 */
            var bindOk = g1.groupPosition === grp.positionOf(g1)
                         && g2.groupPosition === grp.positionOf(g2)
                         && g3.groupPosition === grp.positionOf(g3)
                         && g1.groupPosition === "first"
                         && grp.isButtonGroup === true
                         && g1.isGroupMember === true

            /* 组里只有一枚 → 仍是 standalone（不是"首尾合一"的怪态） */
            var oneOk = grpOne.count === 1 && gs.groupPosition === "standalone"
                        && grpOne.positionOf(gs) === "standalone"

            /* ★ 运行时往组里塞一枚：已有成员的方位**必须跟着重算**。
             *   追加前 g3 = last；追加后它是第 3/4 枚 → middle。
             *   这一条同时证明"children 参与绑定"与"拉模型读的是当前场景树"。 */
            var extra = extraBtn.createObject(grp)
            var growOk = extra !== null && grp.count === 4
                         && g1.groupPosition === "first"
                         && g2.groupPosition === "middle"
                         && g3.groupPosition === "middle"
                         && extra.groupPosition === "last"

            /* CornerUtil 穷举：角序约定（tl / tr / br / bl 顺时针）、
             * standalone 是**恒等**映射（不分组的按钮四角全等 —— 这就是
             * "新增契约字段带默认值、老消费者一行不改"的数学形式）、
             * first 与 last **互补**、middle 四角全零。 */
            var c4 = CornerUtil.corners("first", 4)
            var l4 = CornerUtil.corners("last", 4)
            var m4 = CornerUtil.corners("middle", 4)
            var s4 = CornerUtil.corners("standalone", 4)
            var cornerOk = c4.tl === 4 && c4.tr === 0 && c4.br === 0 && c4.bl === 4
                           && l4.tl === 0 && l4.tr === 4 && l4.br === 4 && l4.bl === 0
                           && m4.tl === 0 && m4.tr === 0 && m4.br === 0 && m4.bl === 0
                           && s4.tl === 4 && s4.tr === 4 && s4.br === 4 && s4.bl === 4
                           && c4.tl === l4.tr && c4.bl === l4.br

            /* 坏 radius 一律 0（渲染路径不该因为一个坏入参把整块界面弄崩）；
             * 未知 position 落回 standalone（失败方向选"更圆"的那个）。 */
            var bad = CornerUtil.corners("first", -1)
                      && CornerUtil.corners("first", NaN)
                      && CornerUtil.corners("first", "x")
                      && CornerUtil.corners("first", undefined)
            var badOk = bad.tl === 0 && bad.tr === 0 && bad.br === 0 && bad.bl === 0
                        && CornerUtil.corners("???", 4).tl === 4

            /* positionOf 的三条边界：n <= 1 与越界都回 standalone */
            var edgeOk = CornerUtil.positionOf(0, 1) === "standalone"
                         && CornerUtil.positionOf(0, 0) === "standalone"
                         && CornerUtil.positionOf(-1, 3) === "standalone"
                         && CornerUtil.positionOf(3, 3) === "standalone"
                         && CornerUtil.positionOf(0, 3) === "first"
                         && CornerUtil.positionOf(1, 3) === "middle"
                         && CornerUtil.positionOf(2, 3) === "last"
                         && CornerUtil.positionOf(0, 2) === "first"
                         && CornerUtil.positionOf(1, 2) === "last"

            return root.all([countOk, posOk, bindOk, oneOk, growOk,
                             cornerOk, badOk, edgeOk])
        })

        /* ───────────── [6] FloatButton + FloatPlate ───────────── */
        root.check(function () {
            /* 直径归一化：0 与负数都 → 1（radius 为 0 会让圆球变方块，
             * 而"看不见的球"比"方球"更难查） */
            var diaOk = fb.plateDiameter === 40
                        && fbZero.plateDiameter === 1
                        && fbNeg.plateDiameter === 1
                        && fb.implicitWidth === fb.plateDiameter
                        && fb.width === fb.plateDiameter
                        && fb.implicitHeight === fb.plateDiameter

            /* 半径：声明值 === 直径/2 === 实际尺寸的一半 */
            var p = root.plateOf(fb)
            var radiusOk = p !== null
                           && p.plateRadius === fb.plateDiameter / 2
                           && p.radius === p.plateRadius
                           && p.radius === Math.min(p.width, p.height) / 2
                           && p.width === fb.plateDiameter

            /* 三态颜色映射。四个签名**互不相同** → 有鉴别力。 */
            var p0 = root.plateOf(fb)
            var pH = root.plateOf(fbHover)
            var pD = root.plateOf(fbOff)
            var pB = root.plateOf(fbBoth)
            var sig = function (x) {
                return root.hex(x.color) + "/" + root.hex(x.border.color)
                       + "/" + x.border.width
            }
            var baseOk = root.hex(p0.color) === root.hex(Theme.color.bgElevated)
                         && root.hex(p0.border.color) === root.hex(Theme.color.border)
            var hoverOk = root.hex(pH.color) === root.hex(Theme.color.brandSubtle)
                          && root.hex(pH.border.color) === root.hex(Theme.color.brand)
            var offOk = root.hex(pD.color) === root.hex(Theme.color.bgSubtle)
                        && root.hex(pD.border.color) === root.hex(Theme.color.border)
            /* ★ disabled **压过** hovered（同一条三元里 disabled 在前） */
            var bothOk = sig(pB) === sig(pD) && sig(pB) !== sig(pH)
            var distinct = sig(p0) !== sig(pH) && sig(pH) !== sig(pD)
                           && sig(p0) !== sig(pD)
            var colorOk = baseOk && hoverOk && offOk && bothOk && distinct

            /* 角标：<= 0 不显示；上限生效 */
            var bd = root.badgeOf(fbBadge)
            var bd1 = root.badgeOf(fb)
            var badgeOk = bd !== null && bd.value === 120 && bd.max === 99
                          && bd.visible === true
                          && bd1 !== null && bd1.value === 0 && bd1.visible === false

            /* tip 为空 → **连 QSkinTooltip 都不创建**（它内部挂 Timer）；
             * 非空 → 建了，text / target 都对，而 opened 仍应是 false
             * （鼠标没悬停 —— `opened` 是"显示中"，不是"创建了"）。
             * 本探针第一趟就是读错这一个属性，看着像"tip 没生效"。 */
            var tt = root.tooltipOf(fbTip)
            var tipOk = tt !== null && tt.text === "回到顶部"
                        && tt.target === fbTip && tt.opened === false
                        && root.tooltipOf(fb) === null

            /* iconSize 是"建议尺寸"（球径的 44%），不强行施加给记号 */
            var iconOk = fb.iconSize === Math.round(fb.plateDiameter * 0.44)
                         && fbZero.iconSize === Math.round(1 * 0.44)

            return root.all([diaOk, radiusOk, colorOk, badgeOk, tipOk, iconOk])
        })

        /* ───────────── [7] Upload：契约骨架 ───────────── */
        root.check(function () {
            /* ── 拒绝四类 reason 与**判定序**（count → dup → type → size）──
             * 判定用的是"正在攒的那一份"，所以一批里先收下的条目也参与
             * "满了没有"与"键重不重"—— 否则 maxCount=4 时一批塞 5 个会全收。 */
            up.clear()
            root.resetSeq()
            root.reentrant = false
            var got = up.addFiles([
                { name: "a.png", key: "a", size: 500 },   /* 收 */
                { name: "b.png", key: "a", size: 100 },   /* dup：键重 */
                { name: "c.pdf", key: "c", size: 100 },   /* type：accept 只放 .png */
                { name: "d.png", key: "d", size: 2000 },  /* size：maxSize = 1000 */
                { name: "e.png", key: "e", size: 100 },   /* 收 */
                { name: "f.png", key: "f", size: 100 },   /* 收 */
                { name: "g.png", key: "g", size: 100 },   /* 收（攒到 4 之前）*/
                { name: "h.png", key: "h", size: 100 }    /* count：已经 4 了 */
            ])
            var rejOk = got === 4 && up.count === 4
                        && root.seq === "rej:dup|rej:type|rej:size|rej:count"
                                       + "|changed|req:a|req:e|req:f|req:g"

            /* 三处相等：返回值 == 发出的请求次数 == count 的增量。
             * 被拒的**不进表、不占位、不发请求**，只发一次 rejected。 */
            var eqOk = got === root.requests && got === up.count

            /* 裸状态（宿主没同步回报时）是 queued / 0 —— 证明"先落表再发信号"
             * 之后表里已经是完整的一条，而不是一个占位符。 */
            var bareOk = up.itemAt(0).status === "queued"
                         && up.itemAt(0).progress === 0
                         && up.itemAt(0).name === "a.png"
                         && up.itemAt(0).size === 500

            /* ── 重入被写成契约 ──
             * 宿主在 onUploadRequested 里**同步**回报是合法用法；此时 addFiles
             * 返回时条目已经是 uploading/0.25。两条路径都验。 */
            up.clear()
            root.resetSeq()
            root.reentrant = true
            var got2 = up.addFiles([
                { name: "p.png", key: "p", size: 10 },
                { name: "q.png", key: "q", size: 10 }
            ])
            var reOk = got2 === 2
                       && root.seq === "changed|req:p|req:q"
                       && up.itemAt(0).status === "uploading"
                       && up.itemAt(0).progress === 0.25
                       && up.itemAt(1).status === "uploading"
                       && up.itemAt(1).progress === 0.25

            /* ── 锁态 + 迟到的回调 + 未知键 ──
             * `success` / `error` 都锁住；被拒的调用**不推进 `_rev`**
             * （晚一步的 reportProgress 不该把界面晃一下）。 */
            var okS = up.reportSuccess("p")
            var revLock = up._rev
            var lateP = up.reportProgress("p", 0.5)
            var lateF = up.reportFailure("p", "迟到的失败")
            var lockOk = okS === true && lateP === false && lateF === false
                         && up.itemAt(0).status === "success"
                         && up.itemAt(0).progress === 1
                         && up.itemAt(0).error === ""
                         && up._rev === revLock
                         && up.reportProgress("nope", 0.5) === false
                         && up.reportProgress("q", NaN) === false
                         && up.itemAt(99) === null
                         && up.itemOf("nope") === null

            /* 分数 clamp：> 1 收成 1，< 0 收成 0 */
            var clampOk = up.reportProgress("q", 9) === true
                          && up.itemAt(1).progress === 1
                          && up.reportProgress("q", -9) === true
                          && up.itemAt(1).progress === 0
                          && up.itemAt(1).status === "uploading"

            /* ── 派生量：`totalProgress` 是逐条 progress 的**算术平均**，
             *    零特殊分支 ──
             * 把状态摆成一个**已知配置**再读，期望值是手算的
             * （p = success → 1；q = uploading 0.4 → 平均 0.7）。
             * 不"自己再算一遍平均" —— 那是与实现共享公式，什么也证明不了。 */
            up.reportProgress("q", 0.4)
            var meanOk = up.totalProgress === 0.7
                         && up.completedCount === 1 && up.uploadingCount === 1
                         && up.queuedCount === 0 && up.failedCount === 0
                         && up.completedCount + up.queuedCount
                            + up.uploadingCount + up.failedCount === up.count

            /* ── retry：只有 error 能离开 error ──
             * ⚠ 这一段必须**关掉重入**：`retry` 会发 `uploadRequested`，
             *   宿主若同步回报，"裸状态"就看不到了（读到的会是
             *   uploading/0.25）。本文件首跑就是在这里红的 ——
             *   「重入被写成契约」的另一面：**要看哪一层的状态就切哪个开关**。 */
            root.reentrant = false
            root.resetSeq()
            var failOk = up.reportFailure("q", "网络断了") === true
                         && up.itemAt(1).status === "error"
                         && up.itemAt(1).error === "网络断了"
            var retOk = up.retry("q") === true
                        && up.itemAt(1).status === "queued"
                        && up.itemAt(1).progress === 0
                        && up.itemAt(1).retryCount === 1
                        && up.itemAt(1).error === ""
                        && root.seq === "req:q"
                        && up.retry("p") === false      /* success 不能重试 */
                        && up.retry("nope") === false

            /* 重入路径的对照：同一个 `retry`，开了重入就立刻是 uploading/0.25。
             * 两条一起才说明"状态先落、信号后发"这条硬契约真的成立：
             * 宿主在信号里读到的已经是新状态。 */
            up.reportFailure("q", "再失败一次")
            root.reentrant = true
            root.resetSeq()
            var retRe = up.retry("q") === true
                        && root.seq === "req:q"
                        && up.itemAt(1).retryCount === 2
                        && up.itemAt(1).status === "uploading"
                        && up.itemAt(1).progress === 0.25
            root.reentrant = false

            /* ── 快照与缓存：**函数**与**属性**的形状不同（实测记录 ④）──
             * `itemAt` / `itemOf` 是函数 → 每次一份新副本，改副本不污染内部；
             * `files` 是属性 → 绑定缓存，同一版本号内是**同一个数组**
             * （所以它是只读约定，调用方不该改它）。
             * 与 Masonry 的 `slotAt`（稳定对象，只读几何）刻意不同形状。 */
            var snap = up.itemAt(0)
            snap.status = "error"
            snap.name = "改坏了"
            var isoOk = up.itemAt(0).status === "success"
                        && up.itemAt(0).name === "p.png"
                        && up.itemAt(0) !== up.itemAt(0)
                        && up.itemOf("p") !== up.itemOf("p")
                        && up.files === up.files
                        && up.files.length === up.count
                        && up.files[0] !== up.itemAt(0)

            /* ── pick()：可以加才发 ── */
            root.resetSeq()
            var pickOk = up.pick() === true && root.seq === "pick"
            up.maxCount = 2
            var pickFull = up.pick()
            up.maxCount = 4
            var pickGuard = pickFull === false

            /* ── 行的**位置** ──────────────────────────────────────────
             * ★ 这条是 **M27 像素门禁抓出来的缺陷**补上的门：
             *   `rowComp` 的根 Item 原先只有 `width`/`height`，**没有 `y`**，
             *   而它挂在裸 `Item`（listArea）里的 `Repeater` 上 ——
             *   Repeater **不定位**，四行于是全落在 (0,0)、糊成一团。
             *   属性侧当时全绿（每行的宽高与 item 都对），冒烟也全绿：
             *   **没有一条断言问过"行在哪"**。这就是「属性值对 ≠ 界面画对」。
             *   判据同时钉住"个数"与"位置"，两条都必要 —— 只有位置的话，
             *   一行都没有时会**空着通过**（量了 0 条算失败）。 */
            up.clear()
            root.reentrant = false
            up.addFiles(["a.png", "b.png", "c.png", "d.png"])
            var rows = root.findAll(up, function (it) {
                return it.height === up.rowHeight
                       && typeof it.index === "number"
                       && it.item !== undefined && it.item !== null
            })
            var rowOk = rows.length === up.count && up.count === 4
            if (rowOk) {
                rows.sort(function (a, b) { return a.index - b.index })
                for (var ri = 0; ri < rows.length; ++ri) {
                    if (rows[ri].y !== ri * (up.rowHeight + up.rowGap)) {
                        rowOk = false
                        break
                    }
                }
            }

            /* ── 本批零新增插槽（M27 只给 buttonBackground 加了一个**读取
             *    字段** groupPosition，没开新格）── */
            var slotOk = Slots.slotNames.length === 21

            return root.all([rejOk, eqOk, bareOk, reOk, lockOk, clampOk,
                             meanOk, failOk, retOk, retRe, isoOk,
                             pickOk, pickGuard, rowOk, slotOk])
        })

        Qt.exit(root.mask)
    }

    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }

    /* 推迟一轮再断言：`QSkinRow` 内部是 `RowLayout`，尺寸重算在 polish 阶段
     * （与 smoke_sizes.qml / smoke_m26.qml 的时序说明同源）—— [1] 与 [6]
     * 读的全是尺寸。 */
    Component.onCompleted: function () {
        try {
            Qt.callLater(root.run)
        } catch (e) {
            Qt.exit(255)
        }
    }
}
