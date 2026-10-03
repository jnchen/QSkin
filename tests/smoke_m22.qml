/****************************************************************************
 * QSkin · 冒烟测试 — M22：Alert / Result / AlertDialog
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 这一批守的是**同一枚"state → 形"的映射被三个场景问了三遍**：
 *
 *     QSkinAlert        行内一条      type 四态 → 记号 + 底色 + 描边
 *     QSkinResult       整屏一页      status 七态 → 记号 或 状态码
 *     QSkinAlertDialog  模态一句      type 四态 → 记号 + 确定钮的变体
 *
 * 属性侧能守的只有"**问对了没有**"（归一化、派生、别名、占位、出口），
 * 守不了"画对了没有" —— 后者归 `.cache/_verify_m22.py`（8 张图 / 57 条
 * 读数）。分界就是项目那条老规矩：**属性值对 ≠ 界面画对**。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这一批独有的风险（一）：四条出口收成两个信号
 * ════════════════════════════════════════════════════════════════════════
 * QSkinAlertDialog 的关闭路径有四条（取消 / 确定 / Esc / 遮罩），信号只有
 * 两个（`confirmed` / `cancelled`）。实现把它们**统一收在 `opened` 的
 * 下降沿**上，而"点的是确定"先记在 `_confirmIntent` 里（见那份文件头）。
 *
 * 这是一个好看的设计，也是一个**只跑单次开合永远看不出问题**的设计：
 *
 *   · 两个按钮各自 emit 一次、下降沿再 emit 一次 → 点一次确定发**两次**
 *   · `_confirmIntent` 若在 `opened` 变 true 之后才置位 → 下降沿读到的
 *     永远是 false → "确定"永远走成"取消"（**静默地反了**）
 *   · 只在按钮里 emit、下降沿那条不写 → Esc 与遮罩关闭变成静默失败
 *
 * 这三种错法**必须跨回合取证**：`opened` 是 `QSkinDialog.opened` 的别名，
 * 而后者是 `Popup.visible` —— Popup 定义了 exit Transition，`close()`
 * 之后 `opened` 要等 `Theme.motion.fast`（本机 120ms）才变 false。
 * 实测（`.cache/_probe_m22dlg.qml`）：open() 后立即读 = true，
 * close() 后 300ms 读 = false。
 *
 * 所以 [6] / [7] 各读一次**计数器**而不是一个布尔值：
 * **"恰好一次"这件事只有计数能表达**，读末态无论如何都读不出来。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这一批独有的风险（二）：按钮**摸不到**
 * ════════════════════════════════════════════════════════════════════════
 * 第一版按 M21 的惯例从 `ad` 往下遍历找那两枚按钮 —— **找到 0 个**。
 * 探针（`.cache/_probe_m22tree.qml` / `_probe_m22dlg.qml`）给出的硬事实：
 *
 *     typeof ad.footer            === undefined   （footer 是 QSkinDialog 的
 *                                                  别名，AlertDialog 没暴露它）
 *     ad.children.length          === 1           （只有那个 QSkinDialog）
 *     QSkinDialog.children          === []
 *     从 ad 往下遍历到的按钮数      === 0
 *     从 window.contentItem 遍历   === 2  ['放弃','删除']   ← 打开时
 *     同上                         === 0            ← 关闭时
 *
 * 原因：按钮活在 `Popup.contentItem` 里，而 **`Popup` 不是 `Item`** ——
 * 它被 Qt 挂到窗口的 overlay 上，不在控件的子树里。所以认领它们只有一条
 * 路：从窗口树里找，并且**只在打开期间存在**。
 *
 * `root.Window.window.contentItem` 在 `qml` 运行器下**不等于** root
 * （root 是它的子项），所以遍历必须从 contentItem 起步；再用
 * `underNode(o, root)` 把本文件里自己声明的按钮（"重试"/"返回列表"）
 * 摘出去 —— 于是剩下的恰好是对话框那两枚。
 *
 * ── 顺带守到一条：按钮只在打开期间存在 ──────────────────────────────────
 * 关闭后窗口树里是 0 枚。这不是重点，但它说明 `_activate()` 必须每次
 * **重新认领**：Popup 的 contentItem 会随开关重建，上一轮拿到的引用
 * 在下一轮可能已经不在树里了。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 这一批独有的风险（三）："占同一个视觉盒子"是个 Layout 陷阱
 * ════════════════════════════════════════════════════════════════════════
 * `QSkinResult` 承诺过"换 status 时整页高度不会跳一下"，载体是状态码那个
 * Text 的高度锁成 `glyphSize`。它原来写的是 `height: root.glyphSize` ——
 * **在 ColumnLayout 里是个空操作**（Layout 用 implicitHeight 覆盖子项
 * 显式 height），实测 48 而不是 64，于是 404 ↔ success 整页差 16px。
 * 已按项目的既定修法改成 `Layout.preferredHeight`（M22.2）。
 *
 * [3] 因此不再只读"高度等于 glyphSize"（那是把实现抄一遍），而是直接
 * 读**承诺本身**：把同一个实例的 status 在 404 与 success 之间切一次，
 * 两个 implicitHeight 必须相等。这条判据在修之前是红的。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么这个文件用 check(closure) 而不是裸写 root.expect(a && b)
 * ════════════════════════════════════════════════════════════════════════
 * 与 smoke_m21.qml 同源：分回合意味着 `Qt.exit()` 只在最后一回合执行，
 * 于是断言里任何一处 TypeError 都会让 run() 中断、`Qt.exit` 永不执行，
 * 而 `qml.exe` 是一个开着窗口的 GUI 进程 —— **测试不是失败，是永远挂着**
 * （smoke_m21 首跑挂了 2 分 13 秒，日志里只有一行
 * "exception occurred during delayed function evaluation"）。
 *
 * 两道防线：① 每条断言用 `check(closure)` 包住（闭包抛异常 = 该位失败，
 * 不中断、不错位）；② 20 秒看门狗 `Qt.exit(255)`（255 → 8 位全亮，
 * 配合 test.sh 打出的 stderr 就是"这个文件炸了"）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 断言上限 8 条（位掩码退出码的数学约束，见 tools/test.sh 文件头）
 * ════════════════════════════════════════════════════════════════════════
 *   [0] Alert 语义轴与派生色          [1] Alert 内容 / 关闭钮 / close 信号
 *   [2] Result 状态解析              [3] Result 尺寸与"不跳版"承诺
 *   [4] AlertDialog 接口与派生        [5] AlertDialog 按钮区（窗口树认领）
 *   [6] 出口 · 确定恰一次             [7] 出口 · 取消 / 程序关闭各恰一次
 *
 * ── [7] 为什么要**两种**关闭途径放在同一条里 ──────────────────────────
 * "点取消"和"程序调 close()"走的是同一条代码路（都不置 `_confirmIntent`），
 * 但它们的**入口**完全不同：前者是控件的 onClicked，后者是调用方直接调
 * 方法（真实场景就是 Esc 与遮罩，QSkinDialog 内部走的也是 close()）。
 * 只验前者会放过"close() 里没清 `_confirmIntent`"的实现 —— 那种实现
 * 会在第二次关闭时把上一次的意图重放一遍。所以末态要求
 * `cancelled === 2 && confirmed === 1`：两个出口各一次、且都不越界。
 *
 * ⚠ 上面这段讲的是"为什么两种关闭途径都要各走一遍"。[7] 里**没有**
 *   给"打开时归位"造状态的语句 —— 那件事在测试侧**做不到**，理由与
 *   实测记录写在 roundReopen 上方，别重试。

 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Window 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int mask: 0
    property int idx: 0

    /* 给根一个尺寸：AlertDialog 是模态框，Popup 按窗口居中；
     * 没有窗口尺寸时它落在 0×0 上（属性断言仍成立，但看着莫名其妙）。 */
    width: 900
    height: 700

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    /** 跑一段会写断言的代码；抛异常算这一条失败（见文件头）。 */
    function check(block) {
        var ok = false
        try { ok = block() === true } catch (e) { ok = false }
        root.expect(ok)
    }

    /* ══════════════════ 被测对象 ══════════════════ */

    /* ── [0][1] QSkinAlert ──
     * 四个实例刻意分工，而不是把一个实例改来改去：
     *   al          语义轴（type 会被逐值改写）
     *   alPlain / alAction  同一句话、只差一个 action —— 占位判据靠**对照**
     *   alClosable  关闭钮的可见性与信号
     * 项目一贯的取证手法：绝对数字会把实现细节钉进断言，差值不会。 */
    QSkinAlert {
        id: al

        x: 10
        y: 10
        width: 380
        title: "当前套餐即将到期"
        description: "3 天后将自动降级到免费版。"
    }

    QSkinAlert {
        id: alPlain

        x: 10
        y: 90
        width: 380
        title: "同一句话"
    }

    QSkinAlert {
        id: alAction

        x: 10
        y: 140
        width: 380
        title: "同一句话"

        action: [ QSkinButton { text: "重试" } ]
    }

    property int alertCloseCount: 0

    QSkinAlert {
        id: alClosable

        x: 10
        y: 190
        width: 380
        title: "可关闭的提示条"
        closable: true

        onClose: root.alertCloseCount++
    }

    /* ── [2][3] QSkinResult ── */
    QSkinResult {
        id: resOk

        x: 420
        y: 10
        width: 368
        status: "success"
        title: "提交成功"
        subtitle: "审核结果会在 1 个工作日内发送到你的邮箱。"
    }

    /* 这一个会被 [2] / [3] 逐值改写 status —— 单实例来回切才能证明
     * "换 status 不跳版"（两个实例的差别会被别的东西混进来）。 */
    QSkinResult {
        id: resStat

        x: 420
        y: 200
        width: 368
        status: "404"
        title: "页面不存在"
    }

    QSkinResult {
        id: resPlain

        x: 420
        y: 380
        width: 368
        status: "info"
        title: "提示"
    }

    QSkinResult {
        id: resExtra

        x: 420
        y: 520
        width: 368
        status: "info"
        title: "提示"

        extra: [ QSkinButton { text: "返回列表" } ]
    }

    /* ── [4]~[7] QSkinAlertDialog ──
     * 文案给成 "放弃"/"删除" 而不是缺省的 "取消"/"确定"：窗口树的认领
     * 要能分清"这两枚是不是本对话框的"，万一别处也有按钮，缺省文案太常见。 */
    property int okCount: 0
    property int noCount: 0

    QSkinAlertDialog {
        id: ad

        title: "删除这 3 个文件？"
        description: "删除后不可恢复。"
        cancelText: "放弃"
        confirmText: "删除"

        onConfirmed: root.okCount++
        onCancelled: root.noCount++
    }

    /* ══════════════════ 工具 ══════════════════ */

    QtObject {
        id: cvt
        property color c: "#000000"
    }

    /** 两个 QColor 是否同色（按 0..255 取整，浮点误差不造成假红）。
     *  QML 里 QColor 是值类型，`!==` 比的是对象身份不是颜色。
     *
     *  ⚠ 入参**必须是 QColor**。塞一个令牌字符串进来是不会报错的：
     *  `"#E2E2E9".r` 是 undefined，比较结果 false，看起来就像"颜色不对"。
     *  M21 真踩过 —— 一个恒假的判据伪装成了实现缺陷。所以显式挡一道。 */
    function sameColorQ(a, b) {
        if (a === null || a === undefined || b === null || b === undefined) return false
        if (typeof a === "string" || typeof b === "string") return false
        if (a.r === undefined || b.r === undefined) return false
        return Math.round(a.r * 255) === Math.round(b.r * 255)
            && Math.round(a.g * 255) === Math.round(b.g * 255)
            && Math.round(a.b * 255) === Math.round(b.b * 255)
    }

    /** 一个 QColor 值是否等于某个令牌（令牌是字符串，先过一遍 color）。 */
    function sameTokenQ(actual, token) {
        if (token === undefined || token === null) return false
        cvt.c = token
        return root.sameColorQ(actual, cvt.c)
    }

    /** 在子树里按谓词找第一个命中者。
     *
     *  ── 为什么谓词必须自己防住非 Item 的节点 ──────────────────────────
     *  子项里混着 `QtObject`（各控件用它当中转 control 的鸭子对象）与
     *  `ShapePath`（Shape.data 里的路径）。它们没有 `font` / `children`，
     *  谓词里一句 `o.font.pixelSize` 就是 TypeError —— 而 TypeError 会被
     *  check() 吞成"这一条失败"，看起来像判据不成立。所以每个谓词都
     *  先验类型再取值。 */
    function findIn(item, pred) {
        var out = []
        root.collect(item, pred, out, 0)
        return out.length > 0 ? out[0] : null
    }

    /** 收集全部命中者。深度上限 16：Popup 的内容链比控件子树深，
     *  但不会到 16；给上限是为了万一遇到环时不会死循环（v1 探针里
     *  QSkinAlertDialog 的 default property 指向它自己内部的容器，
     *  形状看着就像环 —— 实测不是，但递归不能假设这一点）。 */
    function collect(item, pred, out, d) {
        if (item === null || item === undefined || d > 16) return
        if (pred(item)) out.push(item)
        var ch = item.children
        if (ch === undefined) return
        for (var i = 0; i < ch.length; ++i) root.collect(ch[i], pred, out, d + 1)
    }

    /** `o` 是不是 `anc` 的后代（沿 parent 链走）。
     *  用来把本文件自己声明的按钮从窗口树的结果里摘出去。 */
    function underNode(o, anc) {
        var p = o
        var guard = 0
        while (p !== null && p !== undefined && guard < 64) {
            if (p === anc) return true
            p = p.parent
            guard++
        }
        return false
    }

    /** 对话框那两枚按钮（见文件头"按钮摸不到"）。
     *  只在对话框**打开期间**存在；每次用之前都要重新认领。 */
    function dialogButtons() {
        var win = root.Window.window
        if (win === null || win === undefined) return []
        var ci = win.contentItem
        if (ci === null || ci === undefined) return []
        var out = []
        root.collect(ci, function (o) {
            return typeof o._activate === "function" && !root.underNode(o, root)
        }, out, 0)
        return out
    }

    /** Alert 的关闭按钮：它内部那个 MouseArea 是整条提示里**唯一**的
     *  手型光标区域，所以按行为特征认领，比按 16×16 的尺寸认领稳
     *  （尺寸是主题给的，行为是控件给的）。返回的是 MouseArea，
     *  它的 `parent` 才是那个 Item。 */
    function findCloseMouse(alert) {
        return root.findIn(alert, function (o) {
            return typeof o.containsMouse === "boolean"
                && o.cursorShape === Qt.PointingHandCursor
        })
    }

    /** 结果页里那个"画状态码"的 Text：按内容认领。
     *  它的 `text` 恒等于 `status`，与 `_isCode` 无关 —— 所以即使
     *  `visible` 为假，这个节点仍在树里，能被找到并读出 visible。 */
    function findCodeText(res) {
        return root.findIn(res, function (o) {
            if (typeof o.text !== "string" || o.text !== res.status) return false
            if (o.font === undefined || o.font === null) return false
            return o.font.pixelSize !== undefined
        })
    }

    /* ══════════════════ 断言 ══════════════════ */

    function run() {
        /* ── [0] Alert 的语义轴：四个合法值各归一，其余一律按 info ──
         *
         * 两条**不同**的性质分开验，因为错法不同：
         *   · `_type` 归一化 —— 写漏一个分支时 `toneColor` 那串三元表达式
         *     会**静默地**掉到最后的 else（也就是 info），颜色看着"合法"，
         *     只是不是要的那个。
         *   · 底色取 subtle 档、记号取本色 —— 这是"语义色的两级用法"，
         *     写反了（底色用本色）在浅色主题上糊成一片深色块。
         *
         * 最后一项是**未知值**：`type: "danger "`（多一个空格）或者上游
         * 传来 `undefined` 都不该让整条提示变成没颜色的。按项目惯例，
         * 未知值一律归 info，而不是报错。 */
        root.check(function() {
            al.type = "success"
            var s = al._type === "success"
                    && root.sameTokenQ(al.toneColor,  Theme.color.success)
                    && root.sameTokenQ(al.toneSubtle, Theme.color.successSubtle)

            al.type = "warning"
            var w = al._type === "warning"
                    && root.sameTokenQ(al.toneColor,  Theme.color.warning)
                    && root.sameTokenQ(al.toneSubtle, Theme.color.warningSubtle)

            al.type = "danger"
            var g = al._type === "danger"
                    && root.sameTokenQ(al.toneColor,  Theme.color.danger)
                    && root.sameTokenQ(al.toneSubtle, Theme.color.dangerSubtle)

            al.type = "info"
            var i = al._type === "info"
                    && root.sameTokenQ(al.toneColor,  Theme.color.info)
                    && root.sameTokenQ(al.toneSubtle, Theme.color.infoSubtle)

            al.type = "nonsense"
            var n = al._type === "info"
                    && root.sameTokenQ(al.toneColor,  Theme.color.info)
                    && root.sameTokenQ(al.toneSubtle, Theme.color.infoSubtle)

            al.type = "info"
            return s && w && g && i && n
        })

        /* ── [1] Alert 的内容、占位、关闭钮与 close 信号 ──
         *
         * "没内容就不占位"**不能**用绝对高度验（那是把实现的行高算进
         * 断言），所以用 alPlain / alAction 的**差值**：两句话完全相同，
         * 只有 action 一个有一个没有。实测 46 vs 56。
         *
         * 关闭钮分两件事：
         *   · `closable` 控制它的 `visible` —— 注意那个 Item **始终在树里**，
         *     所以"找不到"和"不可见"是两件事，这里分开验（探针实测：
         *     两者各命中 1 个 MouseArea，closable 的 parent.visible=true、
         *     另一个 parent.visible=false）
         *   · 它的 MouseArea 真的连到 `close` 信号上 —— 直接 emit 那个
         *     信号只能证明信号存在，什么也证明不了；要驱动的是控件里
         *     那一行 `onClicked: root.close()`，所以取到 MouseArea 再发
         *     它自己的 `clicked`（QML 里信号可以从外部当方法调用）。
         *
         *     ⚠ **必须传参**：Qt 6 的 `MouseArea.clicked(MouseEvent mouse)`
         *     参数是必填的。写成 `m.clicked()` 会抛
         *     "Error: Insufficient arguments" —— 而 check(closure) 会把
         *     它**吞成一声不响的"这一条失败"**，看起来像实现没接线。
         *     实探（`.cache/_probe_m22alert.qml`）：`m.clicked(null)` 正常
         *     触发 onClose，`m.clicked()` 抛异常。
         *     这是 `check(closure)` 那道防线自带的代价 —— 它保住了"不挂死"，
         *     代价是把 TypeError 伪装成断言不成立。红了先怀疑调用姿势。
         *
         * 无障碍名一并查：它是"读屏能不能念出这条告警"的唯一开关，
         * 而 QSkinAlert 写了三级回落（标题 → 说明 → 空字符串）。 */
        root.check(function() {
            var m = root.findCloseMouse(alClosable)
            var mOff = root.findCloseMouse(alPlain)

            var visOk = m !== null && m.parent !== null
                        && m.parent.visible === true
                        && m.parent.width === Theme.size.iconSm
                        && mOff !== null && mOff.parent !== null
                        && mOff.parent.visible === false

            var wireOk = false
            if (m !== null) {
                root.alertCloseCount = 0
                m.clicked(null)
                wireOk = root.alertCloseCount === 1
            }

            var accOk = al.Accessible.name === al.title
                        && alPlain.Accessible.name === alPlain.title

            var placeOk = alAction.implicitHeight > alPlain.implicitHeight

            return visOk && wireOk && accOk && placeOk
        })

        /* ── [2] Result 的状态解析：七个取值收成两类 ──
         *
         * `_isCode` 决定"画记号还是画数字"，`_glyphStatus` 决定"画哪一枚
         * 记号"。两者是**独立的**两张表，所以分开读 —— 合并成一个
         * `a && b` 会让"404 也被当成 _glyphStatus 的一支"这种错逃掉。
         *
         * `error` 与 `danger` 都要归 danger：Arco 用前者、Ant 用后者，
         * 组件两个都收，免得调用方要记住是哪一家的口径。这条**只有**
         * 对着两张表一起读才看得出来。
         *
         * 颜色这一格有它自己的门道：404 / 403 取 **warning**（"你走错了
         * 路"），500 取 **danger**（"我们坏了"）。写成一个统一色也能跑，
         * 但那是把两个不同的语义压成一个。 */
        root.check(function() {
            var st = resStat

            st.status = "404"
            var c404 = st._isCode === true
            st.status = "403"
            var c403 = st._isCode === true
            st.status = "500"
            var c500 = st._isCode === true
            st.status = "success"
            var cNo = st._isCode === false
            st.status = "error"
            var cErr = st._isCode === false

            var gDanger = st._glyphStatus === "danger"      /* error → danger */
            st.status = "danger"
            var gDanger2 = st._glyphStatus === "danger"
            st.status = "warning"
            var gWarning = st._glyphStatus === "warning"
            st.status = "success"
            var gSuccess = st._glyphStatus === "success"
            st.status = "whatever"
            var gUnknown = st._glyphStatus === "info"

            st.status = "404"
            var tone404 = root.sameTokenQ(st.toneColor, Theme.color.warning)
            st.status = "403"
            var tone403 = root.sameTokenQ(st.toneColor, Theme.color.warning)
            st.status = "500"
            var tone500 = root.sameTokenQ(st.toneColor, Theme.color.danger)
            st.status = "success"
            var toneS = root.sameTokenQ(st.toneColor, Theme.color.success)

            st.status = "404"
            return c404 && c403 && c500 && cNo && cErr
                   && gDanger && gDanger2 && gWarning && gSuccess && gUnknown
                   && tone404 && tone403 && tone500 && toneS
        })

        /* ── [3] Result 的尺寸：状态码与记号**占同一个视觉盒子** ──
         *
         * 这一条读的是承诺本身，不是实现：把**同一个实例**的 status 在
         * 404 与 success 之间切一次，两个 `implicitHeight` 必须相等。
         * 修之前（`height: root.glyphSize` 被 ColumnLayout 覆盖）实测
         * 138 vs 154 —— 差 16px，这条红。详见 QSkinResult 里 M22.2 那段。
         *
         * 另外三项：
         *   · 状态码 Text 的 `height === glyphSize` —— 注意读的是
         *     `height` 不是 `implicitHeight`（Layout 会把前者写成 64、
         *     后者仍是 48）。这一对数值差本身就是"Layout 在管它"的证据。
         *   · 字号跟着 glyphSize 走。`font.pixelSize` 是普通绑定，读了
         *     就重算，所以改完立刻读是可靠的（`height` 不行 —— 那是
         *     Layout 在 polish 时写的，改完立刻读会拿到旧值）。
         *   · extra 的占位同 [1]：resPlain / resExtra 的差值（实测 154 vs 198）。 */
        root.check(function() {
            var t = root.findCodeText(resStat)
            var defOk = resStat.glyphSize === 64
                        && t !== null
                        && t.height === 64
                        && t.font.pixelSize === Math.round(64 * 0.75)
                        && t.visible === true

            /* 承诺：换 status 不跳版。两行读的是同一个实例的同一个属性。 */
            var hCode = resStat.implicitHeight
            resStat.status = "success"
            var hGlyph = resStat.implicitHeight
            resStat.status = "404"
            var jumpOk = Math.abs(hCode - hGlyph) <= 0.5

            resStat.glyphSize = 32
            var scaledOk = t.font.pixelSize === Math.round(32 * 0.75)
            resStat.glyphSize = 64

            var tOk = root.findCodeText(resOk)
            var visOk = tOk !== null && tOk.visible === false && t.visible === true

            var placeOk = resExtra.implicitHeight > resPlain.implicitHeight

            return defOk && jumpOk && scaledOk && visOk && placeOk
        })

        /* ── [4] AlertDialog 的接口与派生 ──
         *
         * `type` 缺省 **warning**（不是 info）—— Ant 的 Modal.confirm
         * 就是用感叹号，"确认"这件事本身带着一点"请注意"。这是本组件
         * 唯一一处与 M22 另外两件**不同**的缺省值，所以单独钉一条。
         *
         * `dismissOnScrim` 缺省 **false**：确认框的语义是"必须选一个"，
         * 误触遮罩就关掉会让调用方永远等不到答复。它是"预设"三条差异里
         * 最要紧的一条，而**它恰好是属性侧唯一能验的那一条** —— 真点遮罩
         * 需要真鼠标事件，归 `tst_interactive.qml`；这里钉住缺省值与被
         * 调用方改写的能力。
         *
         * 文案可改也要验：它们是**接口**，而按钮上的字是派生 —— 见 [5]。 */
        root.check(function() {
            var defOk = ad._type === "warning"
                        && ad.dismissOnScrim === false
                        && ad.opened === false
                        && ad.panelWidth === 420
                        && ad.cancelText === "放弃"
                        && ad.confirmText === "删除"

            ad.type = "danger"
            var dOk = ad._type === "danger"
            ad.type = "success"
            var sOk = ad._type === "success"
            ad.type = "info"
            var iOk = ad._type === "info"
            ad.type = "nope"
            var nOk = ad._type === "info"

            ad.type = "danger"
            ad.dismissOnScrim = true
            var setOk = ad.dismissOnScrim === true
            ad.dismissOnScrim = false

            ad.cancelText = "不删了"
            ad.confirmText = "删掉"
            var txtOk = ad.cancelText === "不删了" && ad.confirmText === "删掉"
            ad.cancelText = "放弃"
            ad.confirmText = "删除"

            ad.type = "warning"
            return defOk && dOk && sOk && iOk && nOk && setOk && txtOk
        })

        /* ══════════════════ 出口（跨回合，见文件头）══════════════════
         * 打开对话框，剩下的断言交给 Timer —— 因为 `opened` 要等退场动画
         * 播完才变 false，同步读永远读到 true。 */
        ad.open()
        root.phase = 0
        step.start()
    }

    /* ══════════════════ 出口：分回合 ══════════════════ */

    property int phase: 0

    function next() {
        if (root.phase === 0)      root.roundButtons()
        else if (root.phase === 1) root.roundConfirm()
        else if (root.phase === 2) root.roundCancel()
        else if (root.phase === 3) root.roundReopen()
        else if (root.phase === 4) root.roundClose()
        else                       root.roundFinal()
    }

    /** ── [5] 按钮区：恰好两枚，且是**活的** ──
     *
     * "预设的边界划在按钮区"是这一件与 QSkinDialog 的分工：要自定义按钮行
     * 就往回退到 QSkinDialog。所以这里钉的不是"有按钮"，而是**恰好两枚**、
     * 顺序是"取消在前、确定在后"、且确定钮的 variant 跟着 `type` 走。
     *
     * 每改一次属性都**重新认领**一次按钮（Popup 的内容会随开关重建），
     * 且读的是**按钮上的值**而不是只读 `_confirmVariant` —— 后者自己
     * 算对了但没绑到按钮上，是一条完整的错法（属性读数全对、界面是一个
     * 蓝按钮配一句"删除后不可恢复"）。
     *
     * 最后一项是显式覆盖：`confirmVariant` 一旦非空就完全接管，不再看
     * `type`。把 `""` 还原回去也要验一次 —— "能覆盖"和"能取消覆盖"
     * 是两件事，只验前者会放过把 `""` 当成一个合法 variant 的实现。 */
    function roundButtons() {
        root.check(function() {
            var openOk = ad.opened === true

            var b = root.dialogButtons()
            var shapeOk = b.length === 2
                          && b[0].text === ad.cancelText
                          && b[1].text === ad.confirmText

            ad.cancelText = "不删"
            ad.confirmText = "确定删除"
            var b1 = root.dialogButtons()
            var liveOk = b1.length === 2
                         && b1[0].text === "不删"
                         && b1[1].text === "确定删除"
            ad.cancelText = "放弃"
            ad.confirmText = "删除"

            var b2 = root.dialogButtons()
            var vWarnOk = b2.length === 2
                          && ad._confirmVariant === "primary"
                          && b2[1].variant === "primary"

            ad.type = "danger"
            var b3 = root.dialogButtons()
            var vDangerOk = b3.length === 2
                            && ad._confirmVariant === "danger"
                            && b3[1].variant === "danger"

            ad.confirmVariant = "ghost"
            var b4 = root.dialogButtons()
            var vOverrideOk = b4.length === 2 && b4[1].variant === "ghost"

            ad.confirmVariant = ""
            var b5 = root.dialogButtons()
            var vRestoreOk = b5.length === 2 && b5[1].variant === "danger"

            /* 用真按钮走一遍确定（这是 [6] 的前置动作，不是断言） */
            root.confirmBtn = b5.length === 2 ? b5[1] : null
            if (root.confirmBtn !== null) root.confirmBtn._activate()

            return openOk && shapeOk && liveOk && vWarnOk
                   && vDangerOk && vOverrideOk && vRestoreOk
        })

        root.phase = 1
        step.start()
    }

    /** ── [6] 确定出口：confirmed **恰好一次**，cancelled 一次都没有 ──
     *  顺带读 `_confirmIntent` 是否已归位 —— 它若没清，下一次关闭会把
     *  这次的意图重放一遍（而那一遍会在 [7] 里露出来）。 */
    function roundConfirm() {
        root.check(function() {
            return ad.opened === false
                   && root.okCount === 1
                   && root.noCount === 0
                   && ad._confirmIntent === false
        })

        ad.open()
        root.phase = 2
        step.start()
    }

    /** 点"放弃"：按钮不置意图，直接 close()。 */
    function roundCancel() {
        var b = root.dialogButtons()
        if (b.length === 2) b[0]._activate()
        root.phase = 3
        step.start()
    }

    function roundReopen() {
        /* ⚠ 这里**没有**给"打开时归位"造状态的写法 —— 别重试这条路。
         *
         * 实现里有两处 `_confirmIntent = false`（上升沿那句 / 下降沿末尾
         * 那句），守的是**同一个**不变量，于是单删任一处都不可证伪：
         *   · 单删**末尾**那句 → 残余意图被下一次 open 的上升沿归位清掉，
         *     [7] 的末态表达式看不见它（看见它的是 [6] 末尾那条，也就是
         *     mutate_m22.py 的 [6·c]）；
         *   · 单删**上升沿**那句 → 末尾那句总是把标志留成 false，没有任何
         *     断言会红。
         * 只有两处都删（mutate_m22.py 的 [7·a]）才露头，那一枪同时点亮
         * bit 6 与 bit 7。
         *
         * 想从测试侧直接造出"意图已置位、但还没关闭"这个状态也不行 ——
         * **`_` 前缀的属性跨文件只读不可写**。实测赋值报：
         *     Error: Cannot assign to non-existent property "_confirmIntent"
         * （读却一直正常，所以 [6] 末尾读它是对的；引擎那句"不存在"的
         *   说法是误导，真相是"只读"。）而这个状态在实现里也确实不可达：
         * 唯一置位的入口紧接着就 close()，close() 必然走完下降沿那句归位。
         *
         * → 如实记为：上升沿那句是**防御性**的（对当前实现是恒真分支）。
         *   要验证它，得先有一个"能置位而不关闭"的入口；在那之前，
         *   本项目不假装它被测到。 */
        ad.open()
        root.phase = 4
        step.start()
    }

    function roundClose() {
        ad.close()
        root.phase = 5
        step.start()
    }

    /** ── [7] 取消出口 + 程序关闭出口：两条各一次、都不越界 ──
     *
     *  末态 `noCount === 2 && okCount === 1` 是这一条的全部内容：
     *    · `noCount === 2` → 两条路都发出来了（只验一条会放过
     *      "close() 不走下降沿"的实现）
     *    · `okCount === 1` → 都没有误发 confirmed（`_confirmIntent`
     *      残留会让第二次关闭走成 confirmed，这里就变 2）
     *    · 顺带：对话框确实关上了，且按钮从窗口树里消失 */
    function roundFinal() {
        root.check(function() {
            return ad.opened === false
                   && root.okCount === 1
                   && root.noCount === 2
                   && ad._confirmIntent === false
                   && root.dialogButtons().length === 0
        })
        Qt.exit(root.mask)
    }

    /** [5] 里认领到的那枚确定按钮（跨回合传递） */
    property var confirmBtn: null

    /* 退场动画：`Popup` 的 exit Transition 走 Theme.motion.fast。
     * 比它多 80ms 是为了让"动画结束 → visible 变 false → 下降沿"这条链
     * 走完；写成符号而不是 120 是因为各主题的 motion 可以不同。 */
    Timer {
        id: step

        interval: Theme.motion.fast + 80
        running: false
        repeat: false
        onTriggered: root.next()
    }

    /* 看门狗：正常路径下走不到这里（测试 2 秒内就结束了）。
     * 255 → 8 个位全亮，配合 test.sh 打出的 stderr 就是"这个文件炸了"。 */
    Timer {
        interval: 20000
        running: true
        repeat: false
        onTriggered: Qt.exit(255)
    }

    /* 推迟一轮：Qt Quick Layouts 把尺寸重算放在 polish 阶段，
     * 在 onCompleted 里同步读会读到重算之前的值（见 smoke_sizes.qml）。
     * [1] / [3] 那几条占位判据读的正是布局算出来的隐式高度。 */
    Component.onCompleted: function() { Qt.callLater(root.run) }
}
