/****************************************************************************
 * QSkin · 主题装载测试 — M27：Kbd / Watermark / Masonry / ButtonGroup /
 *                           FloatButton / Upload
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这一份量什么、不量什么
 * ════════════════════════════════════════════════════════════════════════
 * 量的是「四家换肤之后，这一批的皮肤确实换成了这一家」。
 *
 * 但 M27 跟 M26 有一个**结构性差别**，它决定了这一份的形状：
 *
 *   M26 那批五件的浮层壳走插槽（`Slots.selectOverlay` / `inputBackground`），
 *   所以判据是"槽里装的是不是这一家自己那一格"。
 *   **M27 六件一个插槽都不碰** —— 唯一的契约变化是给**既有**的
 *   `buttonBackground` 加了一个**读取字段** `groupPosition`（裁决四），
 *   而且那个映射下沉到了 `CornerUtil`（一份实现、五个消费者）。
 *
 * 所以这一份的重心从"装了哪一格"移到了「**换肤之后算路对不对**」：
 *   ① 四角的映射必须在每一家、每个方位上都等于
 *      `CornerUtil.corners(pos, Theme.radius.md)` —— 且**老消费者**
 *      （没有 groupPosition 字段的 control）读到 standalone、逐字不变；
 *   ② 各件的**几何**在四家下该变的变、该恒等的恒等 —— 而"该不该变"
 *      由 [1] 的前提账定：吃 `space.*` / `font.*` 的那些令牌四家**共用**，
 *      所以 Masonry / Kbd / Watermark 的几何恒等是**应该**的；
 *      吃 `radius.md` 的那一处（键帽圆角）则必须逐家不同。
 *
 * 不量**渲染出来的颜色**：那在像素侧，归 `.cache/_verify_m27px.py`。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 两条实测记录（写在这里，因为它们是"为什么这么写"的全部理由）
 * ════════════════════════════════════════════════════════════════════════
 *
 * ① **`FloatPlate.color` 带 `Behavior on color`，换肤区间内读不到新值。**
 *    实测（`.cache/probe_m27smoke/t_measure.qml`）—— 同一份读数、四个主题：
 *
 *        fill   : #ffffff,#f3e8ff,#f7f7fa   ← 四家**完全一样**
 *        border : #e7e7e7 | #f0f0f0 | #e5e6eb | #e4e4e7   ← 逐家不同
 *
 *    fill 那三个值（默认 / hover / disabled）是 **Neutral** 的；
 *    `border.color` 没有 Behavior，所以立刻读就是新家的值。
 *    这不是缺陷 —— 换肤时颜色本来就该渐变过去；但**它意味着
 *    "底色换了没有"这件事在同步区间里量不出来**（要量得等动画收敛，
 *    而抓图/冒烟都不该去等一个时间量）。
 *
 *    所以 [6] 把这条**钉成断言**（四家 fill 签名必须相同）：
 *    哪天有人把那个 Behavior 去掉（或把 duration 改成 0），
 *    这里会红，提示"文档里那句实测记录过期了"，
 *    而不是让那句话悄悄变成假话。这是"**注释也要被门禁守**"的用法。
 *
 * ② **`Theme.color.bgElevated` 四家都是纯白**（`#ffffff` ×4）。
 *    所以 `FloatPlate` 的默认底色在四家下**没有鉴别力** ——
 *    它是"该被记下来、不该被当判据"的令牌（与 M26 的 `space.md` 同款）。
 *    [1] 用 `distinct === 1` 把它钉在明处；真值断言在
 *    `tests/smoke_m27.qml` [6]（那边比的是"等于不等于令牌"，
 *    与主题无关，所以没有鉴别力也不影响）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 断言清单（位掩码退出码，见 tools/test.sh 文件头；上限 8 条）
 * ════════════════════════════════════════════════════════════════════════
 *   [0] 白名单账目：21 格 / 六个具名反例不在 / 白名单外的键被安静丢掉 /
 *       install↔reset 往返 / **`groupPosition` 是字段不是格**
 *   [1] 前提账：**有分歧**的令牌（radius.sm/md/lg · border · fg ·
 *       brandSubtle · bg · size.controlMd · font.monoFamily）至少取到两个值；
 *       **四家共用**的（space.xs/sm/md · font.xs/sm · **bgElevated**）
 *       必须**恰好一个值** —— 后者没有鉴别力，别拿它当判据
 *   [2] 唯一动契约的一格：四家 × 四个方位，四角半径都等于
 *       `CornerUtil.corners(pos, Theme.radius.md)`；零模式正确
 *       （first 的 tr/br 为 0、last 的 tl/bl 为 0、middle 全 0、
 *       standalone 四角全等）；**老消费者**（无 groupPosition 字段）
 *       读到 standalone；四家的 `buttonBackground` 是**四个不同**的
 *       Component 且就是各家自己那一个
 *   [3] Kbd：不吃令牌的四项（keyHeight / minKeyWidth / thickness /
 *       implicitWidth）四家**逐位相同**；吃令牌的 fontSize / keyRadius
 *       逐家等于 `Theme.font.sm` / `Theme.radius.md`，且 keyRadius
 *       四家至少两个值（有鉴别力）
 *   [4] Watermark：网格几何（cols / rows / 点数 / 首尾点 / 倾角 /
 *       透明）四家**逐位相同**；`color` 逐家等于 `Theme.color.fg`
 *       且四家至少两个值
 *   [5] Masonry：`gap` 等于 `Theme.space.md`；`columnCount` /
 *       `columnWidth` / `contentHeight` / 整张槽位表四家**逐位相同**
 *       （它只吃 gap，而 gap 四家共用 —— 恒等是**应该**的）
 *   [6] FloatButton：`plateDiameter` 四家恒等；`plate.border.color`
 *       逐家等于这一家的 `border` / hover 时等于 `brand`（四家至少两个值）；
 *       而 fill 的四家签名**必须相同** —— 那是 Behavior 在起作用
 *       （实测记录 ①），这条断言是它的守卫
 *   [7] 暗色：四家下 M27 六件 + 那格插槽的**几何逐位不变**，而
 *       `Theme.color.bg` 必须与亮色**不同**（后者证明模式真的切了）；
 *       收尾 `Slots.reset()` 后回到 Basic（21 格 · 那一格回到 basic*），
 *       且 `Theme.mode` 回到 "light"
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0
import QSkin.Theme.AntDesign 1.0
import QSkin.Theme.ArcoDesign 1.0
import QSkin.Theme.Shadcn 1.0

Item {
    id: root

    property int mask: 0
    property int idx: 0

    width: 1200
    height: 900

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    function check(block) {
        var ok = false
        try { ok = block() === true } catch (e) { ok = false }
        root.expect(ok)
    }

    function all(conds) {
        for (var i = 0; i < conds.length; ++i)
            if (conds[i] !== true) return false
        return true
    }

    /* ══════════════════ 换肤区间底座（与 smoke_m25/m26_theme 同一份）══════════════════ */

    /** 换肤 → 量 → 换回。**所有**要读"当下这一家"的值都必须在这个区间里读。 */
    function one(theme, fn) {
        var v = null
        theme.apply()
        try { v = fn() } finally { theme.remove() }
        return v
    }

    function perTheme(fn) {
        return [ root.one(TDesign, fn),
                 root.one(AntDesign, fn),
                 root.one(ArcoDesign, fn),
                 root.one(Shadcn, fn) ]
    }

    /** 颜色的可比签名。**必须统一大小写**：`String(color)` 给小写 `#ffffff`，
     *  而令牌字面量是 `#FFFFFF`。 */
    function hex(c) { return String(c).toLowerCase() }

    function distinctCount(arr) {
        var seen = []
        for (var i = 0; i < arr.length; ++i) {
            var s = String(arr[i])
            if (seen.indexOf(s) < 0) seen.push(s)
        }
        return seen.length
    }

    function eqArr(a, b) {
        if (a === null || b === null || a === undefined || b === undefined) return false
        if (a.length !== b.length) return false
        for (var i = 0; i < a.length; ++i) if (a[i] !== b[i]) return false
        return true
    }

    function sigArr(a) { return (a === null || a === undefined) ? "nil" : a.join("/") }

    /* ══════════════════ 那格插槽的读数 ══════════════════ */

    /** 假 control。插槽是**鸭子类型**（统一用 `var control`），
     *  所以只要状态面凑齐就行 —— 这里造的是"这一格的最小消费者"。 */
    QtObject {
        id: fake
        property string groupPosition: "standalone"
        property string variant: "default"
        property bool pressed: false
        property bool hovered: false
        property bool enabled: true
        property bool checkable: false
        property bool checked: false
    }

    /** 老消费者：**没有** `groupPosition` 这个字段（M27 之前的所有调用方）。 */
    QtObject {
        id: fakeOld
        property string variant: "default"
        property bool pressed: false
        property bool hovered: false
        property bool enabled: true
        property bool checkable: false
        property bool checked: false
    }

    /** 白名单外键 / "装上了"的假插槽。
     *
     *  ⚠ 根对象**必须**声明 `control` —— 插槽契约的第 1 条。
     *  写成裸 `Item { }` 会在 `QSkinButton` 里打出
     *
     *      QML Binding: Property 'control' does not exist on QQuickItem
     *
     *  实测：本文件首跑 3 条（= 组里三枚按钮各一条）。那条警告**没有任何
     *  一道门在看**（COVERAGE.md 第九节），所以这里自己守住它。
     *  顺带说明一件事：**把不合契约的 Component 装进 `buttonBackground`，
     *  唯一的表现就是一条运行期警告** —— 没有属性会变得可疑，
     *  没有断言会红。这正是"第十一道门"要做的事。 */
    Component { id: slotStub; Item { property var control: null } }

    /** 现场造一个插槽实例，读四角半径。**不从控件里反推** ——
     *  控件上的绑定正是被检查的东西，拿它当基准就是自证。
     *  ⚠ 本函数**会写** `ctl.groupPosition`，所以只能喂声明了那个字段的
     *  control；老消费者另走 `slotCornersOld()` —— 往没有该字段的 QtObject
     *  上赋值会直接抛 TypeError（本文件首版就是这么红的）。 */
    function slotCorners(pos, ctl) {
        var o = Slots.buttonBackground.createObject(root)
        if (o === null || o === undefined) return null
        ctl.groupPosition = pos
        o.control = ctl
        var r = [o.topLeftRadius, o.topRightRadius,
                 o.bottomRightRadius, o.bottomLeftRadius]
        o.destroy()
        return r
    }

    /** 老消费者（M27 之前的调用方）：control 上**没有** groupPosition。 */
    function slotCornersOld() {
        var o = Slots.buttonBackground.createObject(root)
        if (o === null || o === undefined) return null
        o.control = fakeOld
        var r = [o.topLeftRadius, o.topRightRadius,
                 o.bottomRightRadius, o.bottomLeftRadius]
        o.destroy()
        return r
    }

    /** 期望值**现场**用 CornerUtil 算（同一份纯函数），令牌在区间内读。 */
    function expectCorners(pos) {
        var c = CornerUtil.corners(pos, Theme.radius.md)
        return [c.tl, c.tr, c.br, c.bl]
    }

    /* ══════════════════ 夹具 ══════════════════ */

    QSkinKbd { id: kbd; keys: ["Ctrl", "K"] }
    QSkinKbd { id: kbdPair; keys: ["Ctrl", "Esc"] }
    QSkinKbd { id: kbdSm; keys: "K"; size: "sm" }

    QSkinWatermark {
        id: wm
        width: 300; height: 200
        text: "CONFIDENTIAL"
        gapX: 100; gapY: 50
    }

    QSkinMasonry {
        id: ma
        width: 640
        columns: 2
        gap: Theme.space.md
        model: [100, 80, 60]
    }

    QSkinButtonGroup {
        id: grp
        QSkinButton { id: g1; text: "一" }
        QSkinButton { id: g2; text: "二" }
        QSkinButton { id: g3; text: "三" }
    }

    QSkinFloatButton { id: fb }
    QSkinFloatButton { id: fbH; hovered: true }
    QSkinFloatButton { id: fbD; enabled: false }

    QSkinUpload { id: up; spinning: false }

    function plateOf(ctl) {
        return root.findIn(ctl, function (it) {
            return typeof it.plateRadius === "number"
        })
    }

    function findIn(item, pred) {
        var out = []
        root.collect(item, pred, out, 0)
        return out.length > 0 ? out[0] : null
    }

    function collect(item, pred, out, d) {
        if (item === null || item === undefined || d > 16) return
        if (pred(item)) out.push(item)
        var kids = item.children
        if (kids === undefined || kids === null) return
        for (var i = 0; i < kids.length; ++i)
            root.collect(kids[i], pred, out, d + 1)
    }

    /** 亮/暗两态下必须**逐位相同**的几何签名。
     *  拉 `up` 进来是刻意的：它的刻度（行高 / 触发区高 / 记号）全是常量，
     *  换主题一个像素都不该动 —— 那是"零 IO、零平台依赖"那件的一个侧证。 */
    function geoms() {
        var plate = root.plateOf(fb)
        return [
            kbd.keyHeight, kbd.minKeyWidth, kbd.thickness,
            kbd.fontSize, kbd.keyRadius, kbd.keyCount, kbd.implicitWidth,
            kbdPair.implicitWidth,
            wm.gridCols, wm.gridRows, wm.gridPointCount,
            wm.gridPoints[0].x, wm.gridPoints[0].y,
            wm.gridPoints[wm.gridPointCount - 1].x,
            wm.gridPoints[wm.gridPointCount - 1].y,
            ma.columnCount, ma.columnWidth, ma.layoutResult.contentHeight, ma.gap,
            grp.count, g1.groupPosition, g2.groupPosition, g3.groupPosition,
            fb.plateDiameter, fb.iconSize,
            up.rowHeight, up.triggerHeight, up.markSize, up.count,
            up.implicitWidth, up.implicitHeight,
            root.sigArr(root.slotCornersOld())
        ]
    }

    /* ══════════════════════════════════════════════════════════════════════
     * 跑
     * ══════════════════════════════════════════════════════════════════════ */

    function run() {
        Slots.reset()
        Theme.mode = "light"

        /* ───────────── [0] 白名单账目（本批零新增插槽） ───────────── */
        root.idx = 0
        root.check(function () {
            var names = Slots.slotNames
            var countOk = names.length === 21

            /* 六个具名反例：上一批刻意**不新开**的格子，各有归属。
             * M27 又加了第六个候选 `groupPosition` —— 它**不是格**，
             * 是 `buttonBackground` 多读的一个**字段**（裁决四）。 */
            var banned = ["anchorInk", "floatPlate", "backTopArrow",
                          "pageBackArrow", "menuPanel", "sidebarCollapseArrow",
                          "groupPosition", "kbdCap", "watermarkInk"]
            var bannedOk = true
            for (var i = 0; i < banned.length; ++i)
                if (names.indexOf(banned[i]) >= 0) bannedOk = false

            var bgRef = Slots.buttonBackground
            var labelRef = Slots.label

            /* 白名单外的键被**安静地丢掉**（不报错、不占格）*/
            Slots.install({ groupPosition: slotStub, floatPlate: slotStub })
            var filterOk = Slots.slotNames.length === 21
                           && Slots.label === labelRef

            Slots.install({ buttonBackground: slotStub })
            var installedOk = Slots.buttonBackground === slotStub

            Slots.reset()
            var backOk = Slots.slotNames.length === 21
                         && Slots.buttonBackground === bgRef
                         && Slots.label === labelRef
                         && Slots.buttonBackground === Slots.basicButtonBackground

            return countOk && bannedOk && filterOk && installedOk && backOk
        })

        /* ───────────── [1] 前提账 ───────────── */
        root.idx = 1
        root.check(function () {
            /* **有分歧**的：拿它们当判据才有鉴别力 */
            var diverge = [
                function () { return Theme.radius.sm },
                function () { return Theme.radius.md },
                function () { return Theme.radius.lg },
                function () { return Theme.color.border },
                function () { return Theme.color.fg },
                function () { return Theme.color.brandSubtle },
                function () { return Theme.color.bg },
                function () { return Theme.size.controlMd },
                function () { return Theme.font.monoFamily }
            ]
            for (var i = 0; i < diverge.length; ++i)
                if (root.distinctCount(root.perTheme(diverge[i])) < 2) return false

            /* **四家共用**的：记录下来，别拿它当判据。
             *
             * `space.md` / `font.sm` 共用 → M27 里吃它们的那些几何
             * （Masonry 的列宽与总高、Kbd 的字号、Watermark 的字号）
             * 在四家下**逐位相同**。所以 [3][4][5] 里那几条"恒等"
             * 是**前提账推出来的结论**，不是"没量出来"。
             *
             * `bgElevated` 共用（四家都纯白）→ FloatPlate 的**默认底色**
             * 在四家下没有鉴别力（见文件头实测记录 ②），
             * [6] 改测 `border.color`，而默认底色那条留在
             * tests/smoke_m27.qml [6]（那边比的是"等不等于令牌"）。 */
            var uniform = [
                function () { return Theme.space.xs },
                function () { return Theme.space.sm },
                function () { return Theme.space.md },
                function () { return Theme.font.xs },
                function () { return Theme.font.sm },
                function () { return Theme.color.bgElevated }
            ]
            for (var k = 0; k < uniform.length; ++k)
                if (root.distinctCount(root.perTheme(uniform[k])) !== 1) return false

            return true
        })

        /* ───────────── [2] 唯一动契约的一格：四角半径 ─────────────
         * M27 给 `buttonBackground` 加的不是新格子，是一个**读取字段**。
         * 这一条同时守三件事：
         *   ① 五家消费者读的是**同一个** CornerUtil（四家结果与纯函数逐位相等）；
         *   ② 映射随令牌走（radius.md 有分歧 → standalone 的四角四家不同）；
         *   ③ 老消费者一行不改（没有该字段的 control 读到 standalone）。 */
        root.idx = 2
        root.check(function () {
            var poss = ["standalone", "first", "middle", "last"]
            var eqOk = true
            var standSigs = []

            for (var i = 0; i < poss.length; ++i) {
                var pos = poss[i]
                /* `perTheme` 是**同步**的 —— 闭包在本次迭代里就被求值了，
                 * 不存在"循环变量被后面几圈改掉"那类问题（那是异步才有的）。 */
                var rows = root.perTheme(function () {
                    return { got: root.slotCorners(pos, fake),
                             want: root.expectCorners(pos) }
                })
                for (var k = 0; k < rows.length; ++k) {
                    if (!root.eqArr(rows[k].got, rows[k].want)) eqOk = false
                    if (pos === "standalone") standSigs.push(root.sigArr(rows[k].got))
                }
            }

            /* 零模式：first 的右上/右下为 0、last 的左上/左下为 0、
             * middle 四角全 0、standalone 四角全等且非 0。
             * 这一条守的是**角序**（tl / tr / br / bl 顺时针）——
             * 写错一格的表现是**镜像**：四个数字全对、属性全对、界面全错。 */
            var f = root.one(TDesign, function () { return root.slotCorners("first", fake) })
            var l = root.one(TDesign, function () { return root.slotCorners("last", fake) })
            var m = root.one(TDesign, function () { return root.slotCorners("middle", fake) })
            var s = root.one(TDesign, function () { return root.slotCorners("standalone", fake) })
            var shapeOk = f[1] === 0 && f[2] === 0 && f[0] > 0 && f[3] > 0
                          && l[0] === 0 && l[3] === 0 && l[1] > 0 && l[2] > 0
                          && m[0] === 0 && m[1] === 0 && m[2] === 0 && m[3] === 0
                          && s[0] === s[1] && s[1] === s[2] && s[2] === s[3] && s[0] > 0

            /* **老消费者零回归**：M27 之前的调用方（control 上没有
             * `groupPosition`）必须读到 standalone、四角全等 ——
             * 这就是"新增契约字段必须带默认值"的实证。
             * 四家都要成立，因为默认值落在插槽里，不在主题里。 */
            var oldSigs = root.perTheme(function () {
                var c = root.slotCornersOld()
                return root.sigArr(c) + "|" + Theme.radius.md
            })
            var oldOk = true
            for (var o = 0; o < oldSigs.length; ++o) {
                var parts = oldSigs[o].split("|")
                var four = parts[0].split("/").map(function (x) { return Number(x) })
                var rmd = Number(parts[1])
                if (four[0] !== rmd || four[1] !== rmd
                    || four[2] !== rmd || four[3] !== rmd) oldOk = false
            }

            /* 鉴别力：radius.md 有分歧 → standalone 的四角至少两个取值。
             * 若哪天四家圆角被统一了，这里会红，提醒"判据不再有鉴别力"。 */
            var discOk = root.distinctCount(standSigs) >= 2

            /* 四家装的是**四个不同**的 Component，且就是各家自己那一个 */
            var comps = root.perTheme(function () { return Slots.buttonBackground })
            var named = [ TDesign.tdButtonBackground, AntDesign.adButtonBackground,
                          ArcoDesign.acButtonBackground, Shadcn.scButtonBackground ]
            var compOk = root.distinctCount(comps) === 4
            for (var c = 0; c < 4; ++c)
                if (comps[c] !== named[c]) compOk = false

            return root.all([eqOk, shapeOk, oldOk, discOk, compOk])
        })

        /* ───────────── [3] Kbd：不吃令牌的四项必须恒等 ───────────── */
        root.idx = 3
        root.check(function () {
            /* 不吃令牌的四项 + 总宽：四家**逐位相同**。
             * 总宽也列进来，是因为它只由 font.monoFamily + fontSize + 缝
             * 决定，而这两枚令牌四家共用（前提账）→ 它应当恒等。
             * 若哪天有人把它改成读 size.* ，这里立刻红。 */
            var fixed = root.perTheme(function () {
                return [kbd.keyHeight, kbd.minKeyWidth, kbd.thickness,
                        kbd.keyCount, kbd.implicitWidth, kbd.implicitHeight,
                        kbdPair.implicitWidth].join(",")
            })
            var fixedOk = root.distinctCount(fixed) === 1

            /* 吃令牌的两项：逐家等于这一家的令牌 */
            var pairs = root.perTheme(function () {
                return { fs: kbd.fontSize === Theme.font.sm,
                         kr: kbd.keyRadius === Theme.radius.md,
                         rs: kbd.keyRadius }
            })
            var tokenOk = true
            var radii = []
            for (var i = 0; i < pairs.length; ++i) {
                if (!pairs[i].fs || !pairs[i].kr) tokenOk = false
                radii.push(pairs[i].rs)
            }

            /* sm 档：18 / 18 / 1 / font.xs / radius.sm，同样逐家成立 */
            var smPairs = root.perTheme(function () {
                return { h: kbdSm.keyHeight === 18,
                         w: kbdSm.minKeyWidth === 18,
                         t: kbdSm.thickness === 1,
                         f: kbdSm.fontSize === Theme.font.xs,
                         r: kbdSm.keyRadius === Theme.radius.sm,
                         ih: kbdSm.implicitHeight === 18 }
            })
            var smOk = true
            for (var j = 0; j < smPairs.length; ++j) {
                var s = smPairs[j]
                if (!s.h || !s.w || !s.t || !s.f || !s.r || !s.ih) smOk = false
            }

            /* 鉴别力 */
            var discOk = root.distinctCount(radii) >= 2

            return root.all([fixedOk, tokenOk, smOk, discOk])
        })

        /* ───────────── [4] Watermark：网格几何恒等，颜色逐家 ───────────── */
        root.idx = 4
        root.check(function () {
            var geom = root.perTheme(function () {
                var p = wm.gridPoints
                return [wm.gridCols, wm.gridRows, wm.gridPointCount,
                        p[0].x, p[0].y,
                        p[p.length - 1].x, p[p.length - 1].y,
                        wm.rotate, wm.inkOpacity, wm.gapX, wm.gapY].join(",")
            })
            var geomOk = root.distinctCount(geom) === 1

            var paints = root.perTheme(function () {
                return { c: root.hex(wm.color) === root.hex(Theme.color.fg),
                         f: wm.fontSize === Theme.font.sm,
                         v: root.hex(wm.color) }
            })
            var paintOk = true
            var vals = []
            for (var i = 0; i < paints.length; ++i) {
                if (!paints[i].c || !paints[i].f) paintOk = false
                vals.push(paints[i].v)
            }

            /* `fg` 四家取到 4 个值（前提账）→ 这条有鉴别力 */
            return geomOk && paintOk && root.distinctCount(vals) >= 2
        })

        /* ───────────── [5] Masonry：只吃 gap，而 gap 四家共用 ───────────── */
        root.idx = 5
        root.check(function () {
            /* gap 必须**跟着令牌**（不是写死的 12）*/
            var gaps = root.perTheme(function () { return ma.gap === Theme.space.md })
            var gapOk = true
            for (var i = 0; i < gaps.length; ++i) if (!gaps[i]) gapOk = false

            /* 整张槽位表 + 三个标量：四家逐位相同。
             * 恒等在这里是**应该的** —— Masonry 的几何只由 gap 与高度表
             * 决定，而 gap 四家共用。若哪天列宽改成吃 radius，这里会红。 */
            var geom = root.perTheme(function () {
                var its = ma.items
                var s = [ma.columnCount, ma.columnWidth,
                         ma.layoutResult.contentHeight, ma.implicitHeight]
                for (var k = 0; k < its.length; ++k)
                    s.push(its[k].col, its[k].x, its[k].y, its[k].w, its[k].h)
                return s.join(",")
            })
            var geomOk = root.distinctCount(geom) === 1

            /* 手推值与换肤无关（列宽 = (640-12)/2 = 314）——
             * 这里再钉一次绝对值，免得"四家都一样地错"。 */
            var absOk = ma.columnWidth === 314 && ma.layoutResult.contentHeight === 152
                        && ma.columnCount === 2

            /* 越界槽位在四家下也恒定 */
            var bound = root.perTheme(function () {
                return ma.slotAt(9).col
            })
            var boundOk = root.distinctCount(bound) === 1 && ma.slotAt(9).col === -1

            return root.all([gapOk, geomOk, absOk, boundOk])
        })

        /* ───────────── [6] FloatButton：尺寸恒等，颜色走两位令牌 ───────────── */
        root.idx = 6
        root.check(function () {
            /* 直径归一化的结果不吃令牌 */
            var dia = root.perTheme(function () {
                return [fb.plateDiameter, fb.iconSize,
                        fb.plateDiameter === fb.width].join(",")
            })
            var diaOk = root.distinctCount(dia) === 1 && fb.plateDiameter === 40

            /* `border.color` **没有** Behavior → 立刻读就是新家的值。
             * 默认态走 `border`、hover 态走 `brand`、禁用态走 `border`。 */
            var rows = root.perTheme(function () {
                var p0 = root.plateOf(fb)
                var pH = root.plateOf(fbH)
                var pD = root.plateOf(fbD)
                return { base: root.hex(p0.border.color) === root.hex(Theme.color.border),
                         hov: root.hex(pH.border.color) === root.hex(Theme.color.brand),
                         off: root.hex(pD.border.color) === root.hex(Theme.color.border),
                         sig: root.hex(p0.border.color) + "/" + root.hex(pH.border.color)
                              + "/" + root.hex(pD.border.color) }
            })
            var borderOk = true
            var sigs = []
            for (var i = 0; i < rows.length; ++i) {
                if (!rows[i].base || !rows[i].hov || !rows[i].off) borderOk = false
                sigs.push(rows[i].sig)
            }
            var borderDisc = root.distinctCount(sigs) >= 2

            /* ★ fill 侧：**必须四家相同** —— 它带 `Behavior on color`，
             *   换肤区间内读到的是动画起点的旧值（文件头实测记录 ①）。
             *   这条断言是那条注释的守卫：Behavior 被去掉 / duration 改成 0
             *   → 四家 fill 会逐家不同 → 这里红 → 提示更新文档。 */
            var fills = root.perTheme(function () {
                return [root.hex(root.plateOf(fb).color),
                        root.hex(root.plateOf(fbH).color),
                        root.hex(root.plateOf(fbD).color)].join(",")
            })
            var fillOk = root.distinctCount(fills) === 1

            return root.all([diaOk, borderOk, borderDisc, fillOk])
        })

        /* ───────────── [7] 暗色：几何逐位不变 + 收尾 ───────────── */
        root.idx = 7
        root.check(function () {
            var themes = [["TDesign", TDesign], ["AntDesign", AntDesign],
                          ["ArcoDesign", ArcoDesign], ["Shadcn", Shadcn]]
            var ok = true
            for (var i = 0; i < themes.length; ++i) {
                themes[i][1].apply()

                Theme.mode = "light"
                var gl = root.geoms()
                var bl = root.hex(Theme.color.bg)

                Theme.mode = "dark"
                var gd = root.geoms()
                var bd = root.hex(Theme.color.bg)

                Theme.mode = "light"
                themes[i][1].remove()

                /* 模式没真换 → 下面那条"几何不变"就没有意义（前提账）*/
                if (bl === bd) ok = false
                for (var k = 0; k < gl.length; ++k)
                    if (gl[k] !== gd[k]) ok = false
            }

            /* 收尾：回到地基的 Neutral 与 Basic */
            Slots.reset()
            Theme.mode = "light"
            var tailOk = Slots.slotNames.length === 21
                         && Slots.buttonBackground === Slots.basicButtonBackground
                         && Slots.label === Slots.basicLabel
                         && Slots.inputBackground === Slots.basicInputBackground
                         && Theme.mode === "light"

            return ok && tailOk
        })

        Qt.exit(root.mask)
    }

    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }

    /* 推迟一轮再断言：尺寸绑定由 polish 阶段求值（见 smoke_sizes.qml 的
     * 时序说明）—— [3]/[5] 读的是布局结果。 */
    Component.onCompleted: function () {
        try {
            Qt.callLater(root.run)
        } catch (e) {
            Qt.exit(255)
        }
    }
}
