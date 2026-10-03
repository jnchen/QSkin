/****************************************************************************
 * QSkin · 冒烟测试 — M24：Descriptions / Statistic / QRCode / Image /
 *                        Calendar / Comment / Tour
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这一批的属性侧能守什么、守不住什么
 * ════════════════════════════════════════════════════════════════════════
 * 能守：**纯函数**（Statistic.formatValue / QSkinImage.fillModeOf / 二维码的
 * 矩阵与路径的互推）、**派生几何的等式**（Tour 的四块遮罩拼出那个洞、
 * Calendar 的格子宽 = 可用宽/7）、**状态机**（日历的 select 三拒、漫游的
 * 步序与边界）。
 *
 * 守不住：画出来是不是那个样子。本批里最贵的一项是二维码 ——
 * `modulePath` 与 `encoded.modules` 互为推算（两个 derivaion 一致只说明
 * **它们俩自洽**），所以真正"画对了"的判据是**把抓到的图喂给解码器**
 * （`.cache/shot_m24.qml` 那条链），不是这里的任何一条断言。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么 [3] 硬要拉上 `matrixText`
 * ════════════════════════════════════════════════════════════════════════
 * `_buildPath()` 把矩阵压成"每行深色连续段"的路径。如果只看
 * "路径非空"或"路径里有 M"，那么把 run 的合并逻辑改坏（比如相邻两段之间
 * 少一次 h-w 回折）也照样绿。
 *
 * 所以这里数的是**两个独立推导出的同一个量**：
 *   · 路径里 "M" 的个数（水平段数，由 _buildPath 数出来）
 *   · `matrixText` 里每一行 ".#" 或 "#" 开头的次数（由文本形式数出来）
 * 两者必须相等。这条能被证伪（改坏任一侧都会红），而"非空"不能。
 *
 * ════════════════════════════════════════════════════════════════════════
 * [7] 的 `tourTarget.y` 是**故意挪动的**
 * ════════════════════════════════════════════════════════════════════════
 * QSkinTour 的洞位置靠 `mapToItem` 算。QML 的依赖捕获发生在**属性读经 JS
 * 包装层**时，而 `mapToItem` 是一次 C++ 调用、内部读 x/y/width/height
 * 不经过那层 —— 于是"目标动了、洞不跟着动"这个缺陷**只有把目标真的挪
 * 一次才抓得到**。所以 [7] 先读下方的布局，再把目标挪到底部读上方的布局。
 * 顺带验掉了翻转：放得下在下方、放不下翻到上方。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 断言上限 8 条（位掩码退出码的数学约束，见 tools/test.sh 文件头）
 * ════════════════════════════════════════════════════════════════════════
 *   [0] Descriptions · 声明序登记 + offset 是**累计跨度**（不是下标）
 *                      + 统一标签宽 + 冒号 + 格线两条 + **底纹格从格左边起**
 *                      （两种 layout 各一条对照）+ itemClicked
 *   [1] Statistic · formatValue / groupDigits 纯函数全谱 + valueText 绑定
 *   [2] QRCode · 编码器契约 + 路径段数 == 文本形式数出的段数 + 空载荷占位
 *   [3] Calendar · 42 格 + `today` 注入后只认注入值 + select 三拒 + 钳制
 *                  + 翻月走 `_goMonth`（箭头那条路，含跨年进位）
 *   [4] Calendar fullscreen · 格子宽 = 可用宽/7 + 高亮块在左上 + 7×6 排布
 *   [5] Image · fillModeOf 五值（含 scale-down ≠ contain）+ empty 态 + 预览守卫
 *   [6] Comment · 动作行（含 disabled）+ 嵌套真的进了内容宿主 + 信号
 *                  + 缩进**落成几何**（`indent` 的两个消费者：头像 x 与
 *                  正文列 x，都拿父条当参照物，配负向对照）
 *   [7] Tour · 步序/边界 + changed 计数 + 四块遮罩拼出那个洞 + 上下翻转
 *
 * ── 刻意**没验**的（别以为是漏了）────────────────────────────────────────
 *   · 真鼠标点击（禁用动作点不动、日历格子点得动）：那要真事件，
 *     归 tests/tst_*.qml 与像素核验。这里只断言 `MouseArea.enabled`
 *     这个**输入侧**的事实（见 [6]）。
 *   · 二维码"能扫"：归抓图 + 解码器。
 *   · QSkinImage 的**圆角遮罩**：`layer.enabled` 依赖渲染后端，
 *     离屏 runner 里的值与真实窗口可能不同 —— 归抓图的像素核验。
 ****************************************************************************/

import QtQuick 2.15
/* [6] 里那条嵌套评论必须用 `Layout.fillWidth` 而不是 `width:` / `anchors`
 * —— QSkinComment 的默认子项落到 `contentHost`（一个 QSkinColumn =
 * ColumnLayout），Layout 会接管子项的 x/y/width/height，写死尺寸或锚点
 * 属未定义行为（项目在 `Layout.alignment` 那处已记过同款）。
 * 少这一行 import，报错是 `Non-existent attached object`，退出码 2 ——
 * 恰好等于 bit1，会被误诊成"第 1 条断言失败"。 */
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

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

    /** 跑一段会写断言的代码；抛异常算这一条失败（见 smoke_m21/m22/m23 同源
     *  的理由：分回合时任何 TypeError 都会让 run() 中断、Qt.exit 永不执行，
     *  而 qml.exe 是个开着窗口的 GUI 进程 —— 测试不是失败，是永远挂着）。 */
    function check(block) {
        var ok = false
        try { ok = block() === true } catch (e) { ok = false }
        root.expect(ok)
    }

    /* ══════════════════ 遍历辅助（与 smoke_m23 同一份）══════════════════ */

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
        var ch = item.children
        if (ch === undefined) return
        for (var i = 0; i < ch.length; ++i) root.collect(ch[i], pred, out, d + 1)
    }

    /* ══════════════════ 颜色比较（与 smoke_m22/m23_theme 同一份）══════════
     *
     * 不能直接 `a === b`：读一个 `color` 型属性拿回来的是**规范化过的
     * 字符串**（小写、带 alpha），而令牌是手写的 "#16A34A"。两者永远不等。
     * 也不能把 "#16A34A" 直接塞进同一个比较 —— 得先经 `property color`
     * 过一遍，让引擎把它规范成同一个形态。 */
    QtObject {
        id: cvt
        property color c: "#000000"
    }

    function sameColorQ(a, b) {
        if (a === null || a === undefined || b === null || b === undefined) return false
        if (typeof a === "string" || typeof b === "string") return false
        if (a.r === undefined || b.r === undefined) return false
        return Math.round(a.r * 255) === Math.round(b.r * 255)
            && Math.round(a.g * 255) === Math.round(b.g * 255)
            && Math.round(a.b * 255) === Math.round(b.b * 255)
    }

    function sameTokenQ(actual, token) {
        if (token === undefined || token === null) return false
        cvt.c = token
        return root.sameColorQ(actual, cvt.c)
    }

    /* ══════════════════ 固定"今天" ══════════════════
     *
     * QSkinCalendar 的 `today` 是声明期取一次、可注入的（理由见那份文件头：
     * 一个会自己变的控件没法做像素门禁）。这里注入一个**与真实今天不同**
     * 的日期，于是 [3] 那两条断言才有意义 —— 如果控件偷偷用了真实时钟，
     * "只有注入的那一天 isToday" 立刻变红。 */

    readonly property var fixedToday: ({ year: 2026, month: 3, day: 15 })

    /* ══════════════════════ 被测对象 ══════════════════════ */

    /* ── [0] 描述列表 A：无边框 + 三列 + 冒号 ──
     * 三个成员的 span 是 1 / 2 / 1 —— 正是"offset 不是下标"的取证：
     * 第三个成员的下标是 2，偏移是 3。 */
    property int descClickCount: 0
    property int descClickOffset: -1
    property int descItemClickCount: 0

    QSkinDescriptions {
        id: descA

        x: 10
        y: 10
        column: 3
        bordered: false
        colon: true

        onItemClicked: function (offset) {
            root.descClickCount++
            root.descClickOffset = offset
        }

        /* `clickable` 是**成员级**的（不是组的）—— 这里只把第三个成员
         * 打开。有意这么选：它的偏移是 3、下标是 2，"带出去的到底是哪
         * 一个"才有鉴别力。前两个保持不可点，顺带当负向对照：
         * [0] 里会先 `di0._activate()` 一次，它必须什么都不发。 */
        QSkinDescriptionsItem {
            id: di0
            label: "姓名"
            span: 1
            Body { text: "张伟" }
        }
        QSkinDescriptionsItem {
            id: di1
            label: "联系电话"
            span: 2
            Body { text: "13800000000" }
        }
        QSkinDescriptionsItem {
            id: di2
            label: "备注"
            span: 1
            clickable: true
            /* 成员自己的 `clicked` 也要能收到（组那条不是唯一出口） */
            onClicked: root.descItemClickCount++
            Body { text: "无" }
        }
    }

    /* ── [0] 描述列表 B：有边框（换成格线语言）+ 两列 ──
     * offset 依次 0 / 1 / 2 / 3，两列下：
     *   offset%2 == 0 者**不**画左线（它在行首），floor(offset/2) > 0 者画上线。
     * 于是四个成员恰好覆盖"左上都不画 / 只左 / 只上 / 左上都画"四种。 */
    QSkinDescriptions {
        id: descB

        x: 620
        y: 10
        column: 2
        bordered: true

        QSkinDescriptionsItem { id: db0; label: "主机"; Body { text: "node-01" } }
        QSkinDescriptionsItem { id: db1; label: "端口"; Body { text: "8080" } }
        QSkinDescriptionsItem { id: db2; label: "区域"; Body { text: "ap-shanghai" } }
        QSkinDescriptionsItem { id: db3; label: "状态"; Body { text: "运行中" } }
    }

    /* ── [0] 描述列表 C：有边框 + **vertical** ──
     * 这一份只为一件事存在：`vertical` 形态下标签格宽 = **整格宽**
     * （`_inner()` 的 vertical 分支），而 `horizontal` 形态下它是标签文字宽。
     * 两种形态语义不同，所以必须各有一条实例，不能拿一条推另一条。
     * 首版把底纹格写成 `labelX: pad` + `labelW: width − pad*2`，在
     * **两种形态上**都让格子两侧各空 12px 页底色（像素核验抓出来的），
     * 而属性侧全绿 —— [0] 里那条 `plateOk` 就是那个缺陷的不变量。 */
    QSkinDescriptions {
        id: descV

        x: 900
        y: 10
        column: 2
        layout: "vertical"
        bordered: true

        QSkinDescriptionsItem { id: dv0; label: "主机"; Body { text: "node-01" } }
        QSkinDescriptionsItem { id: dv1; label: "状态"; Body { text: "运行中" } }
    }

    /* ── [1] 数值展示 ── */
    QSkinStatistic {
        id: stat

        x: 10
        y: 220
        title: "总请求"
        value: 1234567.891
        precision: 2
        separator: true
        prefix: "≈"
        suffix: "次"
    }

    QSkinStatistic {
        id: statOk

        x: 240
        y: 220
        title: "成功率"
        value: 99.6
        suffix: "%"
        valueStyle: "success"
    }

    QSkinStatistic {
        id: statLoad

        x: 470
        y: 220
        title: "加载中"
        loading: true
    }

    /* ── [2] 二维码 ── */
    QSkinQRCode {
        id: qr

        x: 10
        y: 350
        value: "https://qds.dev/m24"
        moduleSize: 4
    }

    QSkinQRCode {
        id: qrEmpty

        x: 300
        y: 350
        value: ""
    }

    /* ── [3][4] 月历（面板形态 / 铺满形态）── */
    property int calSelCount: 0
    property var calSelArg: null
    property int calPanCount: 0

    QSkinCalendar {
        id: cal

        x: 10
        y: 520

        today: root.fixedToday
        value: ({ year: 2026, month: 3, day: 10 })
        minimumDate: ({ year: 2026, month: 3, day: 5 })
        maximumDate: ({ year: 2026, month: 3, day: 20 })
        disabledDate: function (d) { return d.day === 12 }

        onSelected: function (date) {
            root.calSelCount++
            root.calSelArg = date
        }
        onPanelChange: function (panel) { root.calPanCount++ }
    }

    QSkinCalendar {
        id: calFull

        x: 480
        y: 520
        width: 700

        fullscreen: true
        today: root.fixedToday
        value: ({ year: 2026, month: 3, day: 15 })
    }

    /* ── [5] 图片 ── */
    QSkinImage {
        id: img

        x: 10
        y: 830
        width: 120
        height: 60
        src: ""
        preview: true
    }

    /* ── [6] 评论 ── */
    property int cmtActionCount: 0
    property int cmtActionIndex: -1

    QSkinComment {
        id: cmt

        x: 620
        y: 240
        width: 420

        author: "张伟"
        datetime: "2026-09-14 10:20"
        content: "这条接口的幂等键要改一下。"
        actions: ["回复", "引用", ({ text: "删除", disabled: true })]

        onActionClicked: function (index) {
            root.cmtActionCount++
            root.cmtActionIndex = index
        }

        QSkinComment {
            id: cmtNested

            Layout.fillWidth: true
            indent: Theme.space.xl
            author: "李娜"
            content: "同意，我改。"
        }
    }

    /* ── [7] 引导漫游 ── */
    property int tourChangedCount: 0
    property int tourFinishedCount: 0
    property int tourSkippedCount: 0

    /* 被瞄的目标。它的 `y` 在 [7] 里会被**故意挪动** —— 见文件头。 */
    Item {
        id: tourTarget

        x: 300
        y: 80
        width: 120
        height: 40
        visible: false
    }

    QSkinTour {
        id: tour

        steps: [
            { target: tourTarget, title: "第一步", description: "看这里" },
            { title: "第二步", description: "看那里" },
            { title: "第三步", description: "完了" }
        ]
        onChanged:        root.tourChangedCount++
        onFinished:       root.tourFinishedCount++
        onSkipped:        root.tourSkippedCount++
    }

    /* ══════════════════ 断言 ══════════════════ */

    function run() {

        /* ─────────────────── [0] 描述列表 ─────────────────── */
        root.check(function () {
            /* 登记顺序 = **声明序**。
             * 兄弟节点的 onCompleted 是逆声明序触发的（M20 实测 "321"），
             * 所以这条直接读成员数组的下标 —— 它是那次实测的可证伪形式。 */
            var orderOk = descA._members.length === 3
                          && descA._members[0] === di0
                          && descA._members[1] === di1
                          && descA._members[2] === di2

            /* offset 是**累计跨度**，不是下标：di1 的 span 是 2，
             * 所以 di2 的偏移是 3 而不是 2。 */
            var offOk = descA._offsetOf(di0) === 0
                        && descA._offsetOf(di1) === 1
                        && descA._offsetOf(di2) === 3
                        && di2._offset === 3

            /* 统一标签宽取组内最宽的那个（"联系电话" 4 字 > "姓名" 2 字）
             * —— 量的是**渲染出来的** label，所以主题换字体后会跟着变。 */
            var wOk = di0.labelWidthHint > 0
                      && di1.labelWidthHint > di0.labelWidthHint
                      && descA._uniformLabelWidth === di1.labelWidthHint
                      && di0._labelW === descA._uniformLabelWidth

            /* 冒号拼进**标签文本**（Ant 的 colon 同款），不是另起一个 Text */
            var colonOk = di0.labelText === "姓名："
                          && di1.labelText === "联系电话："
                          && db0.labelText === "主机"      /* 有边框 → 无冒号 */

            /* span 会被夹到 [1, column] */
            var clampOk = db0.span === 1

            /* 格线：两列下 offset 0..3 →
             *   db0 无左无上、db1 有左无上、db2 无左有上、db3 有左有上 */
            var gridOk = !db0._leftLine && !db0._topLine
                         && db1._leftLine && !db1._topLine
                         && !db2._leftLine && db2._topLine
                         && db3._leftLine && db3._topLine
                         && db0._cellPad > 0

            /* 可点成员 → 组发 itemClicked，带的是**偏移**（3，不是下标 2）。
             * 先打一次不可点的成员：`_activate()` 在 `clickable` 为假时
             * 直接返回，两个计数都不该动 —— 这一半是负向对照，也是首跑
             * 变红的那一处（初版把 `clickable: true` 写在了 di0 上）。 */
            var before = root.descClickCount
            var itemBefore = root.descItemClickCount
            di0._activate()
            var silentOk = root.descClickCount === before
                           && root.descItemClickCount === itemBefore
            di2._activate()
            var clickOk = silentOk
                          && root.descClickCount === before + 1
                          && root.descClickOffset === 3
                          && root.descItemClickCount === itemBefore + 1

            /* 标签底纹格必须**从单元格左边界起**（`labelX === 0`）。
             * 这条不是凭空加的：M24 的像素核验量出首版 `labelX: pad` +
             * `labelW: width - pad*2`，底纹格两侧各空 12px 页底色，单元格里
             * 出现一条不属于任何东西的空带；而**属性侧当时全绿**
             * （`_uniformLabelWidth` 照样有数、`labelAlignment` 照样 AlignLeft、
             * 冒烟测试全过）。所以把那个缺陷的不变量写进属性门禁 ——
             * 以后谁把 `labelX` 挪回去，这一条会响，不必等抓图。
             * ⚠ `labelW` 只在 **vertical** 形态下等于整格宽；horizontal
             *   （含无边框）时它是"标签文字宽"，两种形态语义不同，不能混判。
             *   这里两种形态各断一条，正好互为对照。 */
            var plateOk = di0._geo.labelX === 0
                          && db0._geo.labelX === 0
                          && dv0._geo.labelX === 0
                          && Math.abs(dv0._geo.labelW - dv0.width) < 0.5
                          && Math.abs(dv1._geo.labelW - dv1.width) < 0.5
                          && dv0._geo.contentX >= dv0._cellPad
                          && db0._geo.labelW < db0.width

            return orderOk && offOk && wOk && colonOk && clampOk && gridOk
                   && plateOk && clickOk
        })

        /* ─────────────────── [1] 数值展示 ─────────────────── */
        root.check(function () {
            var S = stat

            /* 格式化：精度 → 分组（**顺序写死**：先取整再分组，
             * 所以 1234567 + precision 0 得到 "1,234,567" 而不是被
             * 分组后再截断的怪东西）。 */
            var fmtOk =
                S.formatValue(1234567.891, 2, true, null) === "1,234,567.89"
                && S.formatValue(1234567, 0, true, null) === "1,234,567"
                && S.formatValue(-1234.5, 1, true, null) === "-1,234.5"
                && S.formatValue(42, -1, false, null) === "42"

            /* 非数原样：字符串 / null / 指数形式都不该被分组逻辑咬到。
             * 1e21 走 String() 得到 "1e+21"，分组必须先识别出指数并放行 ——
             * 否则会得到 "1,e+21" 这类垃圾。 */
            var oddOk =
                S.formatValue("abc", 2, true, null) === "abc"
                && S.formatValue(null, 2, true, null) === ""
                && S.formatValue(1e21, -1, true, null) === "1e+21"
                && S.formatValue(undefined, 2, true, null) === ""

            /* formatter 一旦给了就是**唯一的**出口（精度与分组都不再参与） */
            var ffOk = S.formatValue(42, 2, true, function (v) { return "占比 " + v + "%" })
                       === "占比 42%"

            var grpOk = S.groupDigits("1234567") === "1,234,567"
                        && S.groupDigits("1234") === "1,234"
                        && S.groupDigits("123") === "123"
                        && S.groupDigits("") === ""
                        && S.groupDigits("-1234") === "-1,234"
                        && S.groupDigits("1234567.89") === "1,234,567.89"

            /* 绑定层：valueText 走的就是同一个函数 */
            var bindOk = S.valueText === "1,234,567.89"
                         && statOk.valueText === "99.6"
                         /* 颜色必须过 `property color` 再比（见 sameTokenQ） */
                         && root.sameTokenQ(statOk._valueColor, Theme.color.success)
                         && !root.sameTokenQ(stat._valueColor, Theme.color.success)
                         /* 加载态：数值位置被骨架占掉，与"值是空串"是两件事 */
                         && statLoad.loading === true
                         && S.loading === false

            return fmtOk && oddOk && ffOk && grpOk && bindOk
        })

        /* ─────────────────── [2] 二维码 ─────────────────── */
        root.check(function () {
            var cOk = qr.valid === true
                      && qr.status === "ok"
                      && qr.moduleCount === qr.encoded.size
                      && qr.moduleCount >= 21
                      && qr.version >= 1 && qr.version <= 40
                      && qr.mask >= 0 && qr.mask <= 7

            /* 侧长 = 模块数 + 两侧静默边 */
            var sideOk = qr.codeSide === qr.moduleCount + qr.quietZone * 2
                         && qr.implicitWidth === qr.codeSide * qr.moduleSize

            /* ── 两个独立推导出的同一个量 ──
             * 路径里的水平段数（数 "M"）必须等于文本形式里每行的段数
             * （数每行 ".#" 与行首 "#" 的出现次数）。 */
            var rows = qr.encoded.modules
            var runsFromText = 0
            for (var r = 0; r < rows.length; ++r) {
                var line = ""
                for (var c = 0; c < rows[r].length; ++c) line += rows[r][c] ? "#" : "."
                var inRun = false
                for (var k = 0; k < line.length; ++k) {
                    if (line.charAt(k) === "#" && !inRun) { runsFromText++; inRun = true }
                    else if (line.charAt(k) !== "#") inRun = false
                }
            }
            var runsFromPath = 0
            var p = qr.modulePath
            for (var i = 0; i < p.length; ++i) if (p.charAt(i) === "M") runsFromPath++

            var pathOk = p.length > 0 && runsFromPath === runsFromText && runsFromText > 0

            /* 文本形式的形状：行数 = 模块数、每行长 = 模块数、'#' 数 = 真值数 */
            var lines = qr.matrixText.split("\n")
            var hashes = 0
            var trues = 0
            var shapeOk = lines.length === qr.moduleCount
            for (var y = 0; y < rows.length; ++y) {
                if (lines[y].length !== qr.moduleCount) shapeOk = false
                for (var x = 0; x < rows[y].length; ++x) {
                    if (lines[y].charAt(x) === "#") hashes++
                    if (rows[y][x]) trues++
                }
            }
            shapeOk = shapeOk && hashes === trues

            /* 空载荷：不画码，退到占位 —— 且**不是**"顺手加的保护"，
             * 是编码器对退化输入的显式拒绝（见 QSkinQRCode 文件头）。 */
            var emptyOk = qrEmpty.valid === false
                          && qrEmpty.status === "empty"
                          && qrEmpty.modulePath === ""
                          && qrEmpty.moduleCount === 0
                          && qrEmpty.codeSide === qrEmpty.placeholderModules + qrEmpty.quietZone * 2

            return cOk && sideOk && pathOk && shapeOk && emptyOk
        })

        /* ─────────────────── [3] 月历：状态机 ─────────────────── */
        root.check(function () {
            var cells = root.findAll(cal, function (o) {
                return o.canPick !== undefined && o.isToday !== undefined
                       && o.d !== undefined
            })

            var cellsOk = cells.length === 42 && cal.cells.length === 42

            /* `today` **注入后只认注入值**：整个 42 格里恰好一格 isToday，
             * 且它就是 fixedToday。真实今天（2026-09-14）在面板上不是
             * 2026-03，所以控件若偷看系统时钟，这里会变成 0 格或错格。 */
            var todayCells = []
            for (var i = 0; i < cells.length; ++i)
                if (cells[i].isToday === true) todayCells.push(cells[i])
            var todayOk = todayCells.length === 1
                          && todayCells[0].d.year === root.fixedToday.year
                          && todayCells[0].d.month === root.fixedToday.month
                          && todayCells[0].d.day === root.fixedToday.day

            /* select 的三拒：被 disabledDate 拒 / 低于下界 / 高于上界。
             * 三者在界面上的表现是一样的（灰掉），但拒绝的理由不同 ——
             * 所以三条都要过。 */
            var before = root.calSelCount
            var r1 = cal.select({ year: 2026, month: 3, day: 12 })
            var r2 = cal.select({ year: 2026, month: 3, day: 1 })
            var r3 = cal.select({ year: 2026, month: 3, day: 25 })
            var rejectOk = r1 === false && r2 === false && r3 === false
                           && root.calSelCount === before
                           && cal.value.day === 10          /* 原值没动 */

            /* 选中一次：返回 true、发一次 selected、且 value 跟着变 */
            var panBefore = root.calPanCount
            var r4 = cal.select({ year: 2026, month: 3, day: 18 })
            var pickOk = r4 === true
                         && root.calSelCount === before + 1
                         && root.calSelArg.day === 18
                         && cal.value.day === 18
                         /* select 会连带一次 panelChange：value 变了、面板
                          * 跟过去。这不是副作用，是设计（见 QSkinCalendar
                          * 的 onValueChanged）。 */
                         && root.calPanCount === panBefore + 1

            /* 程序化改 value：越界被**钳制**（不是丢弃），且不发 selected；
             * 非法日期归 null。 */
            var before2 = root.calSelCount
            cal.value = ({ year: 2026, month: 3, day: 1 })
            var clampOk = cal.value.day === 5 && root.calSelCount === before2
            cal.value = ({ year: 2026, month: 13, day: 1 })
            clampOk = clampOk && cal.value === null

            /* 翻月与"今天"：都不改 value */
            cal.value = ({ year: 2026, month: 3, day: 18 })
            var pan2 = root.calPanCount
            cal.goToMonth(2026, 5)
            var navOk = cal.panelYear === 2026 && cal.panelMonth === 5
                        && root.calPanCount === pan2 + 1
                        && cal.value.day === 18
            cal.goToToday()
            navOk = navOk && cal.panelMonth === root.fixedToday.month
                    && cal.panelYear === root.fixedToday.year
                    && cal.value.day === 18

            /* ── 箭头那条路：`_goMonth(±1)` → `DateUtil.addMonths(…, delta)` ──
             * 上面那两条只走 `goToMonth()`，而它是**直接写** panelYear /
             * panelMonth 的 —— "翻月"真正被用户走到的路是 `_goMonth`
             * （两个箭头按钮的 onClicked，QSkinCalendar 323 / 373 行）。
             * 首版这里没有这一节，于是把 `addMonths(…, delta)` 改成
             * `addMonths(…, 0)` 时属性侧全绿 —— mutate_m24.py 的 [3]
             * 首跑 MISSED，逮住的就是这个缺口。
             *
             * ⚠ 只数 `panelChange` 次数**不够**：`_goMonth` 无论 delta 是几
             * 都会调 `goToMonth`，信号照发、只是"月不动"。必须比年月值。
             * ⚠ `_goMonth` 是私有的，但它是"翻月"的**唯一实现**（那两个箭头
             * 是一行绑定）。点箭头属于真事件，归 tests/tst_*.qml —— 目前那里
             * 还没有月历，这是一条**已知缺口**，记在这里不自称已覆盖。 */
            cal.goToMonth(2026, 12)
            var pan3 = root.calPanCount
            cal._goMonth(1)
            var arrowOk = cal.panelYear === 2027 && cal.panelMonth === 1 /* 跨年进位 */
                          && root.calPanCount === pan3 + 1
                          && cal.value.day === 18                       /* 翻月不改 value */
            cal._goMonth(-1)
            arrowOk = arrowOk && cal.panelYear === 2026 && cal.panelMonth === 12
            cal._goMonth(-1)
            arrowOk = arrowOk && cal.panelYear === 2026 && cal.panelMonth === 11
            cal._goMonth(0)
            arrowOk = arrowOk && cal.panelYear === 2026 && cal.panelMonth === 11

            return cellsOk && todayOk && rejectOk && pickOk && clampOk && navOk
                   && arrowOk
        })

        /* ─────────────────── [4] 月历：fullscreen 几何 ─────────────────── */
        root.check(function () {
            var cells = root.findAll(calFull, function (o) {
                return o.markSide !== undefined && o.markX !== undefined
                       && o.d !== undefined
            })
            if (cells.length !== 42) return false

            /* 格子宽 = (可用宽) / 7，可用宽 = 本件宽 - 两侧内距。
             * 这条把"公开的 width/padding"与"派生出来的 colWidth"绑在一起
             * —— 谁把 /7 写成 /6 或漏掉内距，立刻红。 */
            var expectW = (calFull.width - calFull.padding * 2) / 7
            var sizeOk = Math.abs(calFull.colWidth - expectW) <= 0.01
                         && calFull.colWidth > 0
                         && calFull.fullscreen === true
                         /* fullscreen 下**不定** implicitWidth（宽度由宿主给，
                          * 否则 implicitWidth 会依赖 width 成环） */
                         && calFull.implicitWidth === 0

            var layoutOk = true
            var markOk = true
            var spanOk = true
            for (var i = 0; i < cells.length; ++i) {
                var cell = cells[i]

                if (Math.abs(cell.width - calFull.colWidth) > 0.01) layoutOk = false
                if (Math.abs(cell.height - calFull.fullRowHeight) > 0.01) layoutOk = false

                /* 7 列：第 i 格落在 (i%7, floor(i/7)) */
                var ex = (cell.index % 7) * calFull.colWidth
                var ey = Math.floor(cell.index / 7) * calFull.fullRowHeight
                if (Math.abs(cell.x - ex) > 0.01) layoutOk = false
                if (Math.abs(cell.y - ey) > 0.01) layoutOk = false

                /* 高亮块在**左上**（panel 形态是居中），尺寸 = markerSize。
                 * 这是两种形态唯一不同的几何 —— 数字仍居中在块里（同一段
                 * 代码），所以它不在这里。 */
                if (Math.abs(cell.markSide - calFull.markerSize) > 0.01) markOk = false
                if (Math.abs(cell.markX - 2) > 0.01 || Math.abs(cell.markY - 2) > 0.01)
                    markOk = false

                /* 6 行恰好用满：42 格覆盖 y = 0 … 5*rowHeight */
                if (cell.index === 41
                        && Math.abs(cell.y - 5 * calFull.fullRowHeight) > 0.01)
                    spanOk = false
                if (cell.index === 41
                        && Math.abs(cell.x - 6 * calFull.colWidth) > 0.01)
                    spanOk = false
            }

            /* 对照：panel 形态是**定尺正方形**格子、高亮块 = 格子 - 4。
             * 两种形态真正的差别在**行高**（36 vs 88）与高亮块边长
             * （32 vs 28）—— 不是高亮块的位置（panel 下它居中，
             * 而 36 格的 (36-32)/2 恰好也是 2，用 markX 区分不出来）。 */
            var pCells = root.findAll(cal, function (o) {
                return o.markSide !== undefined && o.d !== undefined
            })
            var panelOk = pCells.length === 42
                          && Math.abs(cal.colWidth - cal.cellSize) <= 0.01
                          && Math.abs(cal.rowHeight - cal.cellSize) <= 0.01
                          && Math.abs(pCells[0].width - cal.cellSize) <= 0.01
                          && Math.abs(pCells[0].height - cal.cellSize) <= 0.01
                          && Math.abs(pCells[0].markSide - (cal.cellSize - 4)) <= 0.01
                          && Math.abs(calFull.rowHeight - calFull.fullRowHeight) <= 0.01
                          && calFull.cellSize !== calFull.fullRowHeight

            return sizeOk && layoutOk && markOk && spanOk && panelOk
        })

        /* ─────────────────── [5] 图片 ─────────────────── */
        root.check(function () {
            /* 五个取值全谱。scale-down 与 contain 的**唯一**区别在小图上：
             * 40×40 的图放进 200×200 的框 → Pad（原尺寸）；
             * 400×400 的图放进 200×200 的框 → PreserveAspectFit。
             * 首版把 scale-down 直接写成 PreserveAspectFit，这一条会红。
             *
             * ⚠ 必须走**实例**（`img.fillModeOf`）。QML 里类型名不是 JS
             * 对象，`QSkinImage.fillModeOf(...)` 抛
             * `TypeError: Property 'fillModeOf' of object QSkinImage is not
             * a function` —— 而 check() 会把它吞成"这条失败"，首跑就是这么
             * 红的。[1] 里 `S = stat` 能过是因为那本来就取的实例。 */
            var fitOk =
                img.fillModeOf("cover",      400, 400, 200, 200) === Image.PreserveAspectCrop
                && img.fillModeOf("contain",  400, 400, 200, 200) === Image.PreserveAspectFit
                && img.fillModeOf("fill",     400, 400, 200, 200) === Image.Stretch
                && img.fillModeOf("none",     400, 400, 200, 200) === Image.Pad
                && img.fillModeOf("scale-down",  40,  40, 200, 200) === Image.Pad
                && img.fillModeOf("scale-down", 400, 400, 200, 200) === Image.PreserveAspectFit
                /* 认不出的取值退回 cover（默认值），而不是抛异常 */
                && img.fillModeOf("乱写",     400, 400, 200, 200) === Image.PreserveAspectCrop

            /* 空 src → empty 态：不显示图、状态是 empty、也没有可预览的东西。
             * `openPreview()` 必须**什么都不做** —— 一个空的预览浮层比
             * 没有浮层更糟。
             *
             * ⚠ `previewSource` 是 **url 型**：交给 JS 的是 QUrl 对象，
             * `=== ""` **恒为 false**（`== ""` 才是 true，`String(u)` 最可靠）。
             * 这是本项目第四次撞同一个坑（QSkinEmpty 两次、QSkinAvatar 一次，
             * 这次在测试里）—— 首跑 [5] 就是红的，而日志里那一行打出来
             * 长得就像 `""`。 */
            img.openPreview()
            var emptyOk = img.status === "empty"
                          && img.showImage === false
                          && img.hasSource === false
                          && img.hasFallback === false
                          && img.previewVisible === false
                          && String(img.previewSource) === ""
                          /* 圆角遮罩是**跟随图片可见性**的：没图就不该开着
                           * 一次离屏渲染（masked 是这条契约的公开读数） */
                          && img.masked === false
                          && img.radius > 0

            return fitOk && emptyOk
        })

        /* ─────────────────── [6] 评论 ─────────────────── */
        root.check(function () {
            var cntOk = cmt._actionCount === 3
                        && cmt._hasHeader === true

            /* 三个动作 delegate 都实例化了，文字与禁用位都对 */
            var acts = root.findAll(cmt, function (o) { return o.actionText !== undefined })
            var textOk = acts.length === 3
                         && acts[0].actionText === "回复"
                         && acts[1].actionText === "引用"
                         && acts[2].actionText === "删除"
                         && acts[1].actionDisabled === false
                         && acts[2].actionDisabled === true

            /* 禁用位落在**输入侧**：那个动作的 MouseArea 是 disabled 的。
             * （真点击点不动归 tests/tst_*.qml；这里验的是"它根本不接事件"） */
            var guardOk = true
            if (acts.length === 3) {
                for (var i = 0; i < 3; ++i) {
                    var ma = root.findIn(acts[i], function (o) {
                        return o.containsMouse !== undefined && o.pressed !== undefined
                               && o.cursorShape !== undefined
                    })
                    if (ma === null) { guardOk = false; continue }
                    var wantEnabled = (i !== 2)
                    if (ma.enabled !== wantEnabled) guardOk = false
                }
            }

            /* 发信号：手动发 MouseArea 的 clicked（离屏 runner 里没有真指针）。
             * ⚠ **必须传参** —— Qt 6 的 `MouseArea.clicked(MouseEvent mouse)`
             * 参数是必填的，`ma0.clicked()` 抛
             * `Error: Insufficient arguments`，被 check() 吞成"这条失败"。
             * 首跑就是这么红的；同款记录见 smoke_m22 的 onClose 那一段。 */
            var before = root.cmtActionCount
            if (acts.length === 3) {
                var ma0 = root.findIn(acts[0], function (o) {
                    return o.containsMouse !== undefined && o.cursorShape !== undefined
                })
                if (ma0 !== null) ma0.clicked(null)
            }
            var sigOk = root.cmtActionCount === before + 1 && root.cmtActionIndex === 0

            /* 嵌套：默认子项真的进了**内容宿主**（不是被丢掉）。
             * 这正是 QSkinDescriptionsItem 首版翻车的那个形态 —— 属性侧
             * 一切正常、屏幕上少一半。判据是"从外层往下找得到它"。 */
            var nestedOk = root.findIn(cmt, function (o) { return o === cmtNested }) !== null
                           /* 内容宿主是那个 QSkinColumn：它得真的把两条评论
                            * 的高度加起来（外层比内层高） */
                           && cmt.implicitHeight > cmtNested.implicitHeight

            /* ── 缩进必须落成**几何**，不能只验"宿主声明了 indent" ──
             * 首版这里写的是 `cmtNested.indent === Theme.space.xl` —— 那读的
             * 是**宿主声明的输入**（一个 int 属性）。把 QSkinComment 里头像那行
             * `x: root.indent` 改成 `x: 0` 时它照样为真：控件压根没读这个值，
             * 值也还是 xl。mutate_m24.py 的 [6] 首跑 MISSED 就是这么来的
             * —— 而同一处改动的**像素**版（`[P8] 子评论不缩进`）是绿的判定，
             * 也就是说它一直是靠像素侧兜着，属性侧那条等于没写。
             *
             * 现在比的是"同一份实现下，头像的 x 是否等于它自己的 indent"，
             * 并配一条**负向对照**：indent = 0 的父条头像必须在 0 ——
             * 否则一个写死的 `x: 12` 也能让内层"看起来对了"。 */
            var avPred = function (o) {
                return o.size !== undefined && o.imageFit !== undefined
                       && o.autoFixFontSize !== undefined
            }
            var hostAv = root.findIn(cmt, avPred)
            var nestedAv = root.findIn(cmtNested, avPred)

            /* `indent` 有**两个**消费者：头像的 x、以及正文列的 x
             * （= `indent + avatarSize + _gap`）。两个都要落成几何 ——
             * 只验头像那一半，同族错法会从正文列漏过去
             * （那个形态在截图上更难看：文字顶格、头像飘在右边）。
             *
             * 正文列那一份**不把内部常量抄进断言**：拿父条（indent = 0）
             * 当参照物算出「头像宽 + 间隙」这个与 indent 无关的步长，
             * 再要求内层的正文列 = `自己的 indent + 这个步长`。 */
            var colPred = function (o) {
                return o.gap !== undefined && o.implicitHeight !== undefined
                       && o.width !== undefined
            }
            var hostCol = root.findIn(cmt, colPred)
            var nestedCol = root.findIn(cmtNested, colPred)
            var colStep = (hostCol !== null) ? hostCol.x - cmt.indent : 0

            var indentOk = cmtNested.indent === Theme.space.xl  /* 前提：宿主确实给了 xl */
                           && hostAv !== null && nestedAv !== null
                           && hostCol !== null && nestedCol !== null
                           && colStep > 0            /* 参照物本身必须非退化 */
                           && Math.abs(hostAv.x - cmt.indent) < 0.5
                           && Math.abs(nestedAv.x - cmtNested.indent) < 0.5
                           && Math.abs(nestedCol.x
                                       - (cmtNested.indent + colStep)) < 0.5

            return cntOk && textOk && guardOk && sigOk && nestedOk && indentOk
        })

        /* ─────────────────── [7] 引导漫游 ─────────────────── */
        root.check(function () {
            var stOk = tour.count === 3
                       && tour.current === 0
                       && tour.isFirst === true && tour.isLast === false
                       && tour.currentStep.title === "第一步"
                       /* 几何可读的前提：浮层已经被实例化。首跑这一条也红 ——
                        * 那时 `_mask` 还是退化形态（洞被钳成零矩形），
                        * 见 QSkinTour.maskReady 与下面 tryRun 的等待。 */
                       && tour.maskReady === true

            /* ── 先用"浮层还开着"的状态读几何 ──
             * 顺序是有意义的：`next()` 走到末尾会 finish 掉、把浮层关掉，
             * 而遮罩的视口尺寸来自那个浮层的内容区。先读几何再动步序。 */
            var hole = tour._hole
            var m = tour._mask

            /* 四块遮罩拼出那个洞。这几条是纯几何等式：上块的底边 = 洞的
             * 顶边、左块的宽 = 洞的左边距、三块高度相加 = 视口高……
             * 任一处少减一个 pad、忘了钳进窗口，都会让某一条不成立。 */
            var maskOk = hole !== null
                         && Math.abs(m.frame.x - hole.x) <= 0.01
                         && Math.abs(m.frame.y - hole.y) <= 0.01
                         && Math.abs(m.frame.w - hole.w) <= 0.01
                         && Math.abs(m.frame.h - hole.h) <= 0.01
                         && Math.abs(m.top.h - hole.y) <= 0.01
                         && Math.abs(m.bottom.y - (hole.y + hole.h)) <= 0.01
                         && Math.abs(m.left.w - hole.x) <= 0.01
                         && Math.abs(m.right.x - (hole.x + hole.w)) <= 0.01
                         && Math.abs(m.left.y - hole.y) <= 0.01
                         && Math.abs(m.left.h - hole.h) <= 0.01
                         /* 三块 + 洞 = 视口（横向与纵向各一条） */
                         && Math.abs((m.left.w + m.frame.w + m.right.w)
                                     - (m.top.w)) <= 0.01

            /* 洞是目标外扩一圈（highlightPadding），且被钳进窗口 */
            var pad = tour.highlightPadding
            var holeOk = maskOk
                         && Math.abs(hole.w - (tourTarget.width + pad * 2)) <= 0.01
                         && Math.abs(hole.h - (tourTarget.height + pad * 2)) <= 0.01
                         && hole.x >= 0 && hole.y >= 0
                         && Math.abs(hole.x - (tourTarget.x - pad)) <= 0.01

            /* 面板放得下就放**下方** */
            var p1 = tour._panel
            var belowOk = Math.abs(p1.y - (hole.y + hole.h + Theme.space.sm)) <= 0.01
                          && p1.w > 0 && p1.w <= tour.panelWidth

            /* ── 把目标挪到底部：放不下 → 面板翻到**上方** ──
             * 这一条同时是"mapToItem 的依赖真的登记了"的取证：
             * 如果洞不跟着目标走，hole.y 与 p1.y 都不会变，这里必红。 */
            tourTarget.y = root.height - 30
            var hole2 = tour._hole
            var p2 = tour._panel
            var flipOk = hole2 !== null
                         && Math.abs(hole2.y - (tourTarget.y - pad)) <= 1.01
                         && hole2.y > hole.y
                         && p2.y < hole2.y
            tourTarget.y = 80

            /* 步序：goTo 会夹到 [0, count-1]，且**同值不重复发** changed */
            var c0 = root.tourChangedCount
            tour.goTo(2)
            var seqOk = tour.current === 2 && tour.isLast === true
                        && root.tourChangedCount === c0 + 1
            tour.goTo(2)
            seqOk = seqOk && root.tourChangedCount === c0 + 1   /* 没重复发 */
            tour.goTo(99)
            seqOk = seqOk && tour.current === 2                 /* 越界夹住 */

            /* 末尾再 next() = 完成（不是"什么都不做"）；prev() 在首端停住 */
            tour.next()
            var endOk = root.tourFinishedCount === 1 && tour.current === 2
            tour.goTo(0)
            tour.prev()
            endOk = endOk && tour.current === 0 && tour.isFirst === true

            /* 跳过：发 skipped，且**不**重复发 finished */
            var skipBefore = root.tourSkippedCount
            tour.skip()
            var skipOk = root.tourSkippedCount === skipBefore + 1
                         && root.tourFinishedCount === 1

            return stOk && holeOk && belowOk && flipOk && seqOk && endOk && skipOk
        })

        Qt.exit(root.mask)
    }

    /* 退场：浮层要先**打开**、并且要**被实例化**，才能读到遮罩几何。
     *
     * 声明式写 `open: true` 不会触发变更处理（初始值不发信号），所以这里
     * 在 onCompleted 里设。但设完**还没完**：`open = true` 只把标志置上，
     * contentItem 要等一帧才交给 Popup 并定尺寸 —— 实测在那一瞬间读
     * `tour.contentItem` 得到的是 null，读 `_mask` 得到的是退化形态
     * （M24 首跑：[7] 因为读到一个零尺寸的洞而红）。
     *
     * 所以这里等 `maskReady` 这个**可证伪的读数**，而不是"等两轮事件循环"
     * —— 赌轮数的话换个 Qt 小版本就会红，而那种红说不出原因。
     * 上界 20 轮只是防呆：真等不到就**照跑**，让 [7] 自然变红（它的
     * stOk 里就有 `maskReady === true`），而不是挂死或者退一个不是位掩码
     * 的码出来。 */
    property bool _ran: false
    property int _turns: 0

    function tryRun() {
        if (root._ran) return
        if (!tour.maskReady && root._turns < 20) {
            root._turns++
            Qt.callLater(root.tryRun)
            return
        }
        root._ran = true
        root.run()
    }

    Component.onCompleted: function () {
        tour.open = true
        Qt.callLater(root.tryRun)
    }

    /* 看门狗：正常路径走不到这里。
     * 255 → 8 位全亮，配合 test.sh 的输出就是"这个文件炸了"。 */
    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }
}
