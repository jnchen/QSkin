/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinUpload
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * 上传（**交互壳**）。参照 Ant 的 `Upload`、Arco 的 `Upload`、
 * TDesign 的 `Upload`（shadcn 没有这一件，见 COVERAGE.md 第一节）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 一句话说清这一件是什么：**状态机归控件，IO 归宿主**
 * ════════════════════════════════════════════════════════════════════════
 * 纯 QML 做不出真实传输（没有文件对话框、没有网络栈）。能交付的是
 * 「选择 → 列表 → 单件进度 → 失败重试 → 移除」这套壳，真实 IO 由宿主注入。
 *
 * **本文件一行 IO 都没有**，也没有任何平台/窗口依赖 —— 它只做两件事：
 *
 *     控件 → 宿主：  signal uploadRequested(item)   请开始传这一件
 *                    signal pickerRequested()        请去开原生选择器
 *     宿主 → 控件：  reportProgress(key, fraction)
 *                    reportSuccess(key)
 *                    reportFailure(key, message)
 *
 * ── 为什么是「信号 + 方法」，不是注入一个 uploader 对象 ────────────────
 * 对象注入会把"谁先谁后"隐式化：宿主在 `start()` 里**同步回调**就是重入，
 * 而重入的 bug 只在真实 IO 的时序里出现，冒烟测试抓不到。换成
 * 「信号 + 方法」之后，每一次副作用都是一次**可数的调用** —— 于是这一件
 * 的闸能落在「调用序」上（像素核验在这里基本无效：屏幕上只有几条进度条）。
 *
 * ⚠ 重入没有被"消灭"，是被**写明了**：`addFiles` 先把整批条目录表，
 *   再发信号（见下面 `_emit` 一段）。所以宿主在 `onUploadRequested` 里
 *   立刻回调 `reportSuccess(key)` 是**合法**的，不需要 `Qt.callLater`。
 *   这条是硬契约，`tests/smoke_m27.qml` 里钉着。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 内部取值链：拉模型 + 自增版本号（四条实测，`.cache/probe_upload/p1/p4`）
 * ════════════════════════════════════════════════════════════════════════
 * `_store` 是一串**身份稳定**的对象（进了表就不再换引用），`_rev` 是版本号，
 * `count` 是结构模型的**个数**。行按 `itemAt(i)` **拉**取一份副本。
 *
 * 为什么不把 `_store` 直接喂给 Repeater：`property var` 的就地改写**不触发
 * 通知**，要通知就得整份重赋数组 → 每次进度上报把整列销毁重建（闪烁 +
 * 丢滚动位 + 丢 hover 态）。本项目把这种错法记作「属性值对、界面错」。
 *
 * 实测四条（都在本仓 Qt 6.8.3 上跑过）：
 *   1. **只动版本号**（不重赋数组）时，行的 delegate **不重建**，而它里面
 *      `text: item.name` / `width: item.progress * N` 这类派生绑定**会**刷新。
 *   2. 这条链路成立的前提是 `itemAt` **每次返回一份新副本**。若返回内部那个
 *      稳定对象，QML 的绑定引擎会判"值没变"而**跳过通知** —— 界面从此不动，
 *      且不报任何错（比"属性错"更隐蔽，因为属性也是对的）。
 *   3. 副本是**隔离**的：宿主改副本上的字段，内部状态一点不动。
 *   4. **结构变化（增/删）会重建整列**（Repeater 的 int 模型在数量变化时
 *      整体重建）—— 这是**已知且可以接受**的代价：增删是低频操作，且它
 *      不产生可见的中间帧。要连这一条也消掉，得换成 `ListView` + `ListModel`
 *      （实测 `append` / `setProperty` 确实只动受影响的那一行，见
 *      `.cache/probe_upload/p3.qml`）—— 但那会把「本仓控件一律用普通数组当
 *      模型」这条惯例破掉，为一个低频路径不值得。**升级路径已经量过了。**
 *
 * ⚠ 一处实测推翻的猜测：`_count` 曾经打算省掉，用 `model: _store.length`。
 *   它其实也能work（进度上报不重赋 `_store`），但**读起来要靠读者自己推出
 *   "这一条只在结构变化时重算"**。留一个显式的 `count`，代价是零。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 契约：状态与派生量
 * ════════════════════════════════════════════════════════════════════════
 * 每条目是一个对象，字段固定七枚：
 *
 *     { key, name, size, status, progress, error, retryCount }
 *       key        string   条目标识。宿主给就用宿主的，不给就自动发号
 *       name       string   文件名（本件不读盘，名字就是全部）
 *       size       int      字节。0 = 未知（本件对 0 不做特殊解释）
 *       status     string   queued | uploading | success | error
 *       progress   real     0 ~ 1
 *       error      string   失败原因（其它状态恒为空串）
 *       retryCount int      重试过几次
 *
 * 状态机（全部由下面几个方法维护，外部改不了）：
 *
 *     addFiles ──▶ queued ──(reportProgress)──▶ uploading ──┬─(reportSuccess)─▶ success
 *                    ▲                                      └─(reportFailure)─▶ error
 *                    └──────────────(retry)────────────────────────────────────┘
 *
 * **`success` 与 `error` 都是"锁住"的状态**：到了这两个状态之后，
 * `reportProgress` / `reportSuccess` / `reportFailure` 一律返回 false 且不改
 * 任何字段，只有 `retry(key)` 能把 `error` 打回 `queued`（并让 `retryCount` +1）。
 * 理由不是洁癖：真实 IO 有竞态，"迟到的成功"与"先报的失败"冲突时，悄悄接受
 * 迟到的那个会让 `retryCount` 与**真实**重试次数脱钩 —— 而"每次副作用都是一次
 * 可数的调用"正是这一件的闸所在。冲突就让宿主显式 `retry()`，别猜。
 *
 * 派生量（全部只读，且**只由上面那七个字段算出来**）：
 *
 *     count           条目总数
 *     files           快照数组（见下）
 *     queuedCount / uploadingCount / completedCount / failedCount
 *     totalProgress   逐条 progress 的**算术平均**（逐条 clamp 到 0~1）
 *     canRetry        failedCount > 0
 *     canAdd          maxCount <= 0 || count < maxCount
 *
 * `totalProgress` **一个特殊分支都没有** —— "成功"是 `reportSuccess` 把
 * `progress` 写成 1 的结果，"排队"是它本来就是 0，"失败"保留失败那一刻的值。
 * 于是这个量的定义只有一句话，而它在冒烟测试里可以被逐字复算。
 *
 * ── 对外给的是**快照**，不是内部对象 ──────────────────────────────────
 * `files` / `itemAt(i)` / `itemOf(key)` / `uploadRequested(item)` 交出去的
 * 都是新副本。宿主改它不会影响控件（实测 3）。这不是防着谁，是让"宿主拿到
 * 的东西"与"控件的状态"不必同寿 —— 后者会在下一次上报时就地变化。
 *
 * ════════════════════════════════════════════════════════════════════════
 * `addFiles` 的返回值与三处相等（这一件最硬的一条）
 * ════════════════════════════════════════════════════════════════════════
 *     addFiles(list) 的返回值
 *       == 真正收下的条数
 *       == 发出的 uploadRequested 次数
 *       == count 的增量
 *
 * 被拒的条目**不进列表**（因此也不占 maxCount 的位置），但每一条都会发一次
 * `rejected(item, reason)`，reason 为 `count | dup | type | size`。判定顺序
 * 就是这个顺序 —— 满了先拒，再查键重复，再查类型，最后查大小。
 *
 *     count   已达 maxCount（本批里先到先得，后面的全拒）
 *     dup     宿主给的 key 与表里已有的重复（自动发号的 key 不会撞）
 *     type    `accept` 里的扩展名记号一条都不匹配
 *     size    size > maxSize（maxSize > 0 时才判）
 *
 * ── `accept` 的判定口径（刻意保守）────────────────────────────────────
 * 只有 `.ext` 形式的记号参与判定，多个之间是"或"，大小写不敏感。
 * 出现**任一无法从文件名判定**的记号（裸星号、或含斜杠的 MIME 记号）时**放行**
 * —— 本件拿到的只有名字，没有 MIME 类型，硬判会误杀。这条口径写出来，
 * 是为了让"为什么加了 image/ 就什么都不拦"有答案。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 三条刻意的裁剪（写出来，不假装完整）
 * ════════════════════════════════════════════════════════════════════════
 * 1. **不做拖拽。** 要平台支持（QML 侧的 `DropArea` 能收，但"这是不是
 *    一个文件路径"的判定在各平台不一致），且拖拽与"点击选择"是两条并存
 *    的入口 —— 先做一条确定的。
 * 2. **不打开真实文件对话框。** `QtQuick.Dialogs` 会把窗口依赖拖进契约层
 *    （本件现在的全部依赖只有 QtQuick / QtQuick.Shapes / 令牌 / 插槽）。
 *    "选择"这一步由 `signal pickerRequested()` 交给宿主，宿主拿到文件后喂
 *    进 `addFiles` —— 于是示例屏可以用一个假按钮演全套流程。
 * 3. **不做图片档列表**（Ant / Arco 的 `listType: picture / picture-card`）。
 *    那要缩略图，而缩略图要有真实文件才能缩 —— 与本件"零 IO"直接冲突。
 *    要缩略图的是**宿主**：它的 IO 已经在手，画在哪儿是它的自由。
 *
 * 另有一条记在明处的债：行的"移除"用**文字按钮**而不是那个叉。本仓已经有
 * 三份手画的叉并记了债（QSkinTag / QSkinNotification / QSkinAlert 的文件头都写了
 * "缺的不是自觉，是那个格子"）—— 这里不画第四份，等那一格共用件落地后
 * 一起换。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Shapes
import QSkin.Foundation 1.0

/* 别名 import 是为了拿 QtQuick 的原生 positioner（`Row` 这个名字被
 * QSkin.Foundation 注册成了 CSS 语义的实现，裸名会解析到那一份，而布局会
 * 静默忽略子项自己写的尺寸）。前置写法 `QtQuick.Row` 不成立 —— 见
 * QSkinTransfer.qml 文件头里记的那条实测。 */
import QtQuick 2.15 as QQ

Item {
    id: root

    /* ══════════════════════ 约束（宿主给的输入）══════════════════════ */

    /** 允许的扩展名，逗号分隔。判定口径见文件头 —— 只有 `.ext` 生效。 */
    property string accept: ""

    /** 一次能不能收多个。false 时 `addFiles` 只收下第一件，其余按 count 拒。 */
    property bool multiple: true

    /** 最多留几条。0 = 不限。**已被拒的不占位置**。 */
    property int maxCount: 0

    /** 单件大小上限（字节）。0 = 不限。 */
    property int maxSize: 0

    /* ══════════════════════ 文案 ══════════════════════ */

    /** 触发区上的字 */
    property string triggerText: qsTr("选择文件")

    /** 失败那行上「重试」按钮的字。 */
    property string retryText: qsTr("重试")

    /** 每行「移除」按钮的字。 */
    property string removeText: qsTr("移除")

    /** 触发区下方的一行说明（空串 = 不占位、不创建 Text） */
    property string hint: ""

    /* ══════════════════════ 外观 ══════════════════════ */

    /** 画不画触发区。false = 宿主自己放一个按钮去调 `pick()`。 */
    property bool showTrigger: true

    /** 画不画条目列表。`count === 0` 时列表区高度为 0（不画空态文案）。 */
    property bool showList: true

    /** 控件宽度。行宽跟着它走。 */
    property int contentWidth: 360

    /* ══════════════════════ 状态 ══════════════════════ */

    /** 关掉之后：触发区与行内按钮都不可点。
     *  **API 不受它约束** —— IO 已经在飞了，关掉一个控件不该把回调丢掉。 */
    property bool enabled: true

    /** 转发给 `Slots.spinRing` 的 `spinning`。
     *  抓图要确定性：动画转起来的相位取决于挂钟，同一份源码出不了同一张图。
     *  抓图脚本把它钉成 false（QSkinProgress 的 indeterminate 同一条处置）。 */
    property bool spinning: true

    /* ══════════════════════ 尺寸 ══════════════════════ */

    /** 触发区高度。**虚线框的圆角不得超过它的一半**（Shape 的路径会自己夹取）。 */
    property int triggerHeight: 56

    /** 条目行高。行内几何全部由下面那几个只读量算出来 —— 像素核验要读数，
     *  不许把 48 / 44 / 2 散在绘制代码里。 */
    readonly property int rowHeight:      48
    readonly property int markSize:       16
    readonly property int nameTop:         6
    readonly property int nameHeight:     20
    readonly property int metaTop:        26
    readonly property int metaHeight:     16
    readonly property int trackThickness:  2
    readonly property int trackTop:       44
    readonly property int rowGap:  Theme.space.xs
    /** 文字（名字行 / 状态行 / 轨道）的左边界 */
    readonly property int textLeft: root.markSize + Theme.space.sm

    /* ══════════════════════ 内部状态 ══════════════════════ */

    /** 条目表。**身份稳定**：进了表就不再换引用（就地改字段 + 抬 `_rev`）。 */
    property var _store: []

    /** 版本号。任何一次状态写入都 +1。读状态的地方都把它读一遍来登记依赖
     *  —— 见文件头那四条实测。 */
    property int _rev: 0

    /** 自动发号用的下一个号 */
    property int _nextKey: 1

    /** 触发区是不是被指着 */
    property bool _hovered: false

    /* ══════════════════════ 派生：结构与计数 ══════════════════════ */

    /** 条目总数。**同时是列表的结构模型**（Repeater 的 model 就是它）。 */
    readonly property int count: root._store.length

    /** 快照数组。每次 `_rev` 或 `_store` 变都重算 —— 宿主拿到的是一份副本。 */
    readonly property var files: root._all()

    readonly property int queuedCount:    root._countOfStatus("queued")
    readonly property int uploadingCount: root._countOfStatus("uploading")
    readonly property int completedCount: root._countOfStatus("success")
    readonly property int failedCount:    root._countOfStatus("error")

    /** 逐条 progress 的算术平均。零特殊分支 —— 见文件头。 */
    readonly property real totalProgress: root._totalProgress()

    readonly property bool canRetry: root.failedCount > 0
    readonly property bool canAdd:   root.maxCount <= 0 || root.count < root.maxCount

    /* ══════════════════════ 信号 ══════════════════════ */

    /** 请宿主去开选择器 */
    signal pickerRequested()

    /** 请宿主开始传这一件。参数是**快照**。 */
    signal uploadRequested(var item)

    /** 用户移除了某一条（`clear()` 不发这个，只发 `changed()`） */
    signal removed(var key)

    /** 某一条被拒（没进列表）。reason: count | dup | type | size */
    signal rejected(var item, var reason)

    /** **结构性**变化：增 / 删 / 清空。进度上报**不**发它 —— 否则它就成了
     *  每秒几十次的噪音，宿主也没法拿它当"列表变了"的信号用。 */
    signal changed()

    /* ══════════════════════ 尺寸 ══════════════════════ */

    readonly property int _triggerH: root.showTrigger ? root.triggerHeight : 0
    readonly property bool _hasHint: root.hint !== ""
    readonly property int _hintGap: (root.showTrigger && root._hasHint) ? Theme.space.sm : 0
    readonly property int _hintH: root._hasHint ? Math.ceil(hintText.implicitHeight) : 0
    readonly property bool _hasList: root.showList && root.count > 0
    readonly property int _listGap:
        ((root.showTrigger || root._hasHint) && root._hasList) ? Theme.space.sm : 0
    readonly property int _listH: root._hasList
        ? root.count * root.rowHeight + (root.count - 1) * root.rowGap : 0

    implicitWidth:  root.contentWidth
    implicitHeight: root._triggerH + root._hintGap + root._hintH
                    + root._listGap + root._listH

    width:  implicitWidth
    height: implicitHeight

    /* ══════════════════════ 无障碍 ══════════════════════ */

    Accessible.role: Accessible.Grouping
    Accessible.name: root.triggerText
    Accessible.description: qsTr("%1 个文件").arg(root.count)

    /* ══════════════════════════════════════════════════════════════════
     *  公开方法
     * ══════════════════════════════════════════════════════════════════ */

    /** 请宿主开选择器。宿主自己放了触发按钮时调它。
     *  返回 false = 没发（被禁用了，或已经满了）。 */
    function pick() {
        if (!root.enabled || !root.canAdd) return false
        root.pickerRequested()
        return true
    }

    /**
     * 收下一批文件。`list` 可以是：
     *     "报告.pdf"                                    单个名字
     *     ["a.png", "b.png"]                            名字数组
     *     [{ name: "a.png", size: 1024 }]               对象数组
     *     { name: "a.png", size: 1024, key: "k1" }      单个对象
     * 返回真正收下的条数（== 发出的 uploadRequested 次数 == count 的增量）。
     */
    function addFiles(list) {
        var batch = root._normalize(list)

        /* ⚠ 不能在 `_store` 上就地 push —— `count` 绑的是 `_store.length`，
         * 而 `property var` 的就地改写**不触发通知**：条目会进表，`count`
         * 却还停在旧值（`model: root.count` 于是不建新行，界面上"文件没加
         * 进去"）。所以先在副本上攒，最后整体换上去。 */
        var next = root._store.slice()
        var acceptedKeys = []
        var rejected = []

        /* ── 第一趟：只判定与落表，一个信号都不发 ──
         * 这样发信号时这一批**已经全在表里**：宿主在第一个
         * `onUploadRequested` 里就能看到整批（它可能想显示"共 N 个"），
         * 也可以在处理器里同步回调 reportX —— 合法，见文件头。
         * 判定也一律看 `next`（本批先收下的要参与"满了没有"与"键重不重"）*/
        for (var i = 0; i < batch.length; ++i) {
            var f = batch[i]
            var reason = root._rejectReason(next, f.name, f.size, f.key)
            if (reason !== "") {
                rejected.push({ item: f, reason: reason })
                continue
            }
            var key = f.key !== "" ? f.key : ("f" + root._nextKey)
            if (f.key === "") root._nextKey += 1
            next.push({
                key: key, name: f.name, size: f.size,
                status: "queued", progress: 0, error: "", retryCount: 0
            })
            acceptedKeys.push(key)
        }

        /* 表真的变了才换上去（没变就一个信号都不发 —— "没变不发"） */
        var added = acceptedKeys.length
        if (added > 0) {
            root._store = next                  /* 结构变化 → 整份换（见上） */
            root._rev += 1
        }

        /* ── 第二趟：按固定顺序发信号 ──
         *   1. rejected（按输入序）—— 被拒的先说，宿主才好提示
         *   2. changed             —— 一次，不是每条一次
         *   3. uploadRequested     —— 按收下的顺序，一件一次
         * 这个顺序是契约，`tests/smoke_m27.qml` 把它记成一个字符串比。 */
        var k
        for (k = 0; k < rejected.length; ++k)
            root.rejected(root._snapshotOfSpec(rejected[k].item), rejected[k].reason)
        if (added > 0) root.changed()
        for (k = 0; k < added; ++k)
            root.uploadRequested(root.itemOf(acceptedKeys[k]))

        return added
    }

    /** 移掉一条。返回 false = 表里没有这个键。 */
    function remove(key) {
        var i = root._findIndex(key)
        if (i < 0) return false
        var next = root._store.slice()
        next.splice(i, 1)
        root._store = next
        root._rev += 1
        root.removed(String(key))
        root.changed()
        return true
    }

    /** 清空。返回 false = 本来就是空的（那就什么都不发 —— "没变不发"）。 */
    function clear() {
        if (root._store.length === 0) return false
        root._store = []
        root._rev += 1
        root.changed()
        return true
    }

    /** 把一条失败的重新排队并再发一次请求。
     *  返回 false = 这一条不在表里，或它不是 error 状态（只有 error 能重试）。 */
    function retry(key) {
        var it = root._findByKey(key)
        if (!it || it.status !== "error") return false
        it.retryCount = (Number(it.retryCount) || 0) + 1
        it.status = "queued"
        it.progress = 0
        it.error = ""
        root._rev += 1
        root.uploadRequested(root.itemOf(key))   /* 状态先落，信号后发 */
        return true
    }

    /* ────────────────────── 宿主回调这三个 ────────────────────── */

    /** 报一次进度。分数会被 clamp 到 0~1。返回 false = 没生效（见返回值）：
     *  键不在表里 / 已锁住 / 分数不是有限数。 */
    function reportProgress(key, fraction) {
        var it = root._findByKey(key)
        if (!it) return false
        if (root._isLocked(it)) return false
        var f = Number(fraction)
        if (!isFinite(f)) return false
        it.progress = Math.max(0, Math.min(1, f))
        it.status = "uploading"
        root._rev += 1
        return true
    }

    /** 传完了。`progress` 被写成 1 —— `totalProgress` 的"成功"就是这么来的。 */
    function reportSuccess(key) {
        var it = root._findByKey(key)
        if (!it) return false
        if (root._isLocked(it)) return false
        it.progress = 1
        it.status = "success"
        it.error = ""
        root._rev += 1
        return true
    }

    /** 传失败了。`progress` **保留**（不抹成 0）—— 失败点是有信息量的。 */
    function reportFailure(key, message) {
        var it = root._findByKey(key)
        if (!it) return false
        if (root._isLocked(it)) return false
        it.status = "error"
        /* 契约定的是「失败原因」（见文件头）：没给原因就是空串，
         * 怎么显示归渲染层（`_statusTextOf`）。纯空白串也算没给。 */
        var msg = (message === undefined || message === null) ? "" : String(message).trim()
        it.error = msg
        root._rev += 1
        return true
    }

    /* ────────────────────── 快照访问器 ────────────────────── */

    /** 第 index 条的**快照**。越界返回 null（不崩）。 */
    function itemAt(index) {
        var r = root._rev                    /* 登记依赖，见文件头 */
        var i = Number(index)
        if (!isFinite(i) || i < 0 || i >= root._store.length) return null
        return root._snapshotOf(root._store[i])
    }

    /** 按键取一条的**快照**。没有就 null。 */
    function itemOf(key) {
        var r = root._rev
        var i = root._findIndex(key)
        return i < 0 ? null : root._snapshotOf(root._store[i])
    }

    /* ══════════════════════════════════════════════════════════════════
     *  纯函数（handler 与属性绑定走同一条算路 —— 本项目的老规矩）
     * ══════════════════════════════════════════════════════════════════ */

    /** 字节数 → 短文案。**刻意没有下沉到 Foundation**：它是本仓第一个
     *  需要这个算路的件。等第二个消费者出现再抽（判据同 MemberOrder /
     *  ScrollUtil / CornerUtil —— 本项目已经吃过几次"两份实现"的亏）。
     *  一位小数，整数不带 `.0`（文案要短）。 */
    function formatSize(bytes) {
        var n = Number(bytes)
        if (!isFinite(n) || n < 0) return ""
        if (n < 1024) return Math.round(n) + " B"
        var kb = n / 1024
        if (kb < 1024) return root._fixed(kb) + " KB"
        var mb = kb / 1024
        if (mb < 1024) return root._fixed(mb) + " MB"
        return root._fixed(mb / 1024) + " GB"
    }

    /** 状态 → 语义记号的名字（喂给 `Slots.statusGlyph`）。
     *  `uploading` 不走这一格（它走 spinRing），所以这里落到 info。 */
    function _markStatusOf(item) {
        if (!item) return "info"
        if (item.status === "success") return "success"
        if (item.status === "error")   return "danger"
        return "info"
    }

    /** 状态行的那句话。错误带原因 —— 那正是用户要看的。 */
    function _statusTextOf(item) {
        if (!item) return ""
        switch (item.status) {
        case "success":   return qsTr("已完成")
        case "error":     return item.error !== "" ? qsTr("上传失败：%1").arg(item.error)
                                 : qsTr("上传失败")
        case "uploading": return item.retryCount > 0
                                 ? qsTr("重传中（第 %1 次）").arg(item.retryCount)
                                 : qsTr("上传中")
        default:          return qsTr("等待上传")
        }
    }

    /** 右侧的百分比。只在"传过"的两种状态下有值。 */
    function _percentTextOf(item) {
        if (!item) return ""
        if (item.status !== "uploading" && item.status !== "success") return ""
        var p = Number(item.progress)
        if (!isFinite(p)) p = 0
        return Math.round(Math.max(0, Math.min(1, p)) * 100) + "%"
    }

    /** 这一行该不该画轨道：进行中（默认色）与失败（危险色）。
     *  排队时它是 0（画一条空轨没有信息量），成功后收起 —— 三家一致。 */
    function _hasTrack(item) {
        return !!item && (item.status === "uploading" || item.status === "error")
    }

    function _trackStatusOf(item) {
        return (item && item.status === "error") ? "danger" : "default"
    }

    /** `success` 与 `error` 都锁住 —— 见文件头那段"为什么"。 */
    function _isLocked(item) {
        return item.status === "success" || item.status === "error"
    }

    function _fixed(v) {
        var r = Math.round(v * 10) / 10
        return (r === Math.floor(r)) ? String(r) : r.toFixed(1)
    }

    function _findIndex(key) {
        return root._indexIn(root._store, key)
    }

    function _indexIn(arr, key) {
        var s = String(key)
        for (var i = 0; i < arr.length; ++i)
            if (String(arr[i].key) === s) return i
        return -1
    }

    function _findByKey(key) {
        var i = root._findIndex(key)
        return i < 0 ? null : root._store[i]
    }

    function _snapshotOf(it) {
        return { key: it.key, name: it.name, size: it.size, status: it.status,
                 progress: it.progress, error: it.error, retryCount: it.retryCount }
    }

    function _snapshotOfSpec(f) {
        return { key: f.key, name: f.name, size: f.size }
    }

    function _all() {
        var r = root._rev
        var out = []
        for (var i = 0; i < root._store.length; ++i)
            out.push(root._snapshotOf(root._store[i]))
        return out
    }

    function _countOfStatus(s) {
        var r = root._rev
        var n = 0
        for (var i = 0; i < root._store.length; ++i)
            if (root._store[i].status === s) n += 1
        return n
    }

    function _totalProgress() {
        var r = root._rev
        var n = root._store.length
        if (n === 0) return 0
        var sum = 0
        for (var i = 0; i < n; ++i) {
            var p = Number(root._store[i].progress)
            if (!isFinite(p)) p = 0
            sum += Math.max(0, Math.min(1, p))
        }
        return sum / n
    }

    /** 把宿主给的各种形状归一成 `[{ name, size, key }]`。
     *  认不出的项**丢掉**（不是补全成假名字 —— 那会往上走一条不存在的路）。 */
    function _normalize(list) {
        var out = []
        if (list === null || list === undefined) return out

        if (typeof list === "string")
            return [{ name: list, size: 0, key: "" }]

        if (list.name !== undefined)
            return [{ name: String(list.name),
                      size: root._sizeOf(list.size),
                      key: list.key === undefined ? "" : String(list.key) }]

        if (list.length === undefined) return out
        for (var i = 0; i < list.length; ++i) {
            var e = list[i]
            if (e === null || e === undefined) continue
            if (typeof e === "string") {
                if (e === "") continue
                out.push({ name: e, size: 0, key: "" })
                continue
            }
            if (e.name === undefined) continue
            out.push({ name: String(e.name),
                       size: root._sizeOf(e.size),
                       key: e.key === undefined ? "" : String(e.key) })
        }
        return out
    }

    function _sizeOf(v) {
        var n = Number(v)
        return (isFinite(n) && n > 0) ? Math.round(n) : 0
    }

    /** 判定顺序就是文件头写的那个：count → dup → type → size。
     *  `arr` 是**正在攒的那一份**（不是 `root._store`）—— 本批里先收下的
     *  条目必须参与"满了没有"与"键重不重"的判定，否则一批里塞 5 个文件
     *  而 maxCount = 3 时会全收。 */
    function _rejectReason(arr, name, size, key) {
        if (root.maxCount > 0 && arr.length >= root.maxCount) return "count"
        if (!root.multiple && arr.length >= 1) return "count"
        if (key !== "" && root._indexIn(arr, key) >= 0) return "dup"
        if (!root._acceptsName(name)) return "type"
        if (root.maxSize > 0 && size > root.maxSize) return "size"
        return ""
    }

    /** 只有 `.ext` 记号参与判定；出现"无法从文件名判定"的记号就放行。
     *  口径写在文件头，别在这里改 —— 改了文件头就成了假话。 */
    function _acceptsName(name) {
        var spec = root.accept
        if (spec === undefined || spec === null) return true
        spec = String(spec).trim()
        if (spec === "" || spec === "*") return true

        var parts = spec.split(",")
        var tokens = []
        for (var i = 0; i < parts.length; ++i) {
            var t = parts[i].trim().toLowerCase()
            if (t === "") continue
            if (t === "*" || t.indexOf("/") >= 0) return true   /* MIME 记号：判不了，放行 */
            if (t.charAt(0) === ".") tokens.push(t)
        }
        if (tokens.length === 0) return true

        var n = String(name).toLowerCase()
        for (var j = 0; j < tokens.length; ++j) {
            var tk = tokens[j]
            if (n.length >= tk.length && n.lastIndexOf(tk) === n.length - tk.length)
                return true
        }
        return false
    }

    /* ══════════════════════════════════════════════════════════════════
     *  绘制
     * ══════════════════════════════════════════════════════════════════ */

    /* ────────────────────── 触发区 ────────────────────── */

    Rectangle {
        id: triggerBg

        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top
        height: root._triggerH
        visible: root.showTrigger

        radius: Theme.radius.lg
        color: root._hovered ? Theme.color.brandSubtle : Theme.color.bgSubtle
        /* 描边交给下面那个 Shape 画（Rectangle 画不出虚线）。
         * 于是这里**必须**是 0 —— 否则实线与虚线叠在一起，看起来像实线。 */
        border.width: 0

        /* 触发区是一个可点的东西，读屏要能按它 —— 父项的 Grouping 管的是
         * 整个控件（"这里有一组上传件"），这一格才是"按一下去选文件"。 */
        Accessible.role: Accessible.Button
        Accessible.name: root.triggerText
        Accessible.onPressAction: if (root.enabled && root.canAdd) root.pick()

        /* 虚线框。
         *
         * ⚠ 实测（`.cache/probe_upload/p2.qml`）：本仓 Qt 6.8.3 上
         *   `ShapePath` 的 StrokeStyle **只有 SolidLine(1) 与 DashLine(2)**
         *   两个成员 —— `DashDotLine` / `DashDotDotLine` / `CustomDashLine`
         *   全是 undefined（赋值会报 "Unable to assign [undefined] to
         *   QQuickShapePath::StrokeStyle"）。所以节距只能用 DashLine 的默认
         *   值；`dashPattern` 属性存在、读得回来，但按 Qt 文档它只在
         *   CustomDashLine 下生效，而本仓拿不到那个成员。**别写它。**
         *
         * 路径按宿主尺寸现算（`anchors.fill`），不依赖 Shape 的隐式尺寸 ——
         * 本项目已记过「Shape 的 implicitWidth 由它自己按路径包围盒算，
         * 宿主的绑定会被静默盖掉」。 */
        Shape {
            id: triggerBorder

            anchors.fill: parent
            // CurveRenderer 才有原生抗锯齿（默认 GeometryRenderer 是硬边）
            preferredRendererType: Shape.CurveRenderer

            /* 禁用时"这块在、但点不动"要看得出来。
             * ⚠ 半透明必须写在 **Shape** 上，不能写在 ShapePath 上 ——
             *   ShapePath 继承的是 QObject，没有 opacity（写在它上面是
             *   "Cannot assign to non-existent property"，实测规则同 P2）。 */
            opacity: (root.enabled && root.canAdd) ? 1.0 : 0.45

            ShapePath {
                id: borderPath

                strokeColor: root._hovered ? Theme.color.brand : Theme.color.borderStrong
                strokeWidth: 1
                fillColor: "transparent"
                strokeStyle: ShapePath.DashLine

                /* 圆角不得超过半高（宿主可以把 triggerHeight 调小） */
                readonly property real rr: Math.min(Theme.radius.lg, triggerBorder.height / 2)
                readonly property real bw: triggerBorder.width
                readonly property real bh: triggerBorder.height

                startX: borderPath.rr
                startY: 0.5
                PathLine { x: borderPath.bw - borderPath.rr; y: 0.5 }
                PathArc {
                    x: borderPath.bw - 0.5; y: borderPath.rr + 0.5
                    radiusX: borderPath.rr; radiusY: borderPath.rr
                    useLargeArc: false
                    direction: PathArc.Clockwise
                }
                PathLine { x: borderPath.bw - 0.5; y: borderPath.bh - borderPath.rr }
                PathArc {
                    x: borderPath.bw - borderPath.rr - 0.5; y: borderPath.bh - 0.5
                    radiusX: borderPath.rr; radiusY: borderPath.rr
                    useLargeArc: false
                    direction: PathArc.Clockwise
                }
                PathLine { x: borderPath.rr + 0.5; y: borderPath.bh - 0.5 }
                PathArc {
                    x: 0.5; y: borderPath.bh - borderPath.rr - 0.5
                    radiusX: borderPath.rr; radiusY: borderPath.rr
                    useLargeArc: false
                    direction: PathArc.Clockwise
                }
                PathLine { x: 0.5; y: borderPath.rr + 0.5 }
                PathArc {
                    x: borderPath.rr; y: 0.5
                    radiusX: borderPath.rr; radiusY: borderPath.rr
                    useLargeArc: false
                    direction: PathArc.Clockwise
                }
            }
        }

        QQ.Row {
            id: triggerRow

            anchors.centerIn: parent
            spacing: Theme.space.sm

            /* 加号记号 —— 两根矩形叠出来，放在 Row 的第一格。
             * 不用 Shape：正交图形没有斜边，也就不需要那套抗锯齿门禁
             * （`tools/check-shape-aa.py` 只扫 Shape，Shape 的调用有代价）。 */
            Item {
                id: plusMark

                readonly property int barLength: 14
                readonly property int barWidth:  2

                width:  plusMark.barLength
                height: plusMark.barLength

                Rectangle {
                    anchors.centerIn: parent
                    width:  plusMark.barLength
                    height: plusMark.barWidth
                    color:  root._hovered ? Theme.color.brand : Theme.color.fgMuted
                }
                Rectangle {
                    anchors.centerIn: parent
                    width:  plusMark.barWidth
                    height: plusMark.barLength
                    color:  root._hovered ? Theme.color.brand : Theme.color.fgMuted
                }
            }

            Loader {
                id: triggerLabelLoader

                sourceComponent: Slots.label

                Binding {
                    target: triggerLabelLoader.item
                    property: "control"
                    value: triggerLabelProxy
                    when: triggerLabelLoader.item !== null
                }
            }
        }

        QtObject {
            id: triggerLabelProxy

            readonly property string text: root.triggerText
            readonly property int labelAlignment: Text.AlignLeft
            readonly property bool enabled: root.enabled && root.canAdd
        }

        MouseArea {
            id: triggerMouse

            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled && root.canAdd
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            onContainsMouseChanged: root._hovered = containsMouse
            onCanceled: root._hovered = false
            onClicked: root.pick()
        }
    }

    /* ────────────────────── 说明行 ────────────────────── */

    Text {
        id: hintText

        anchors.left:  parent.left
        anchors.right: parent.right
        y: root._triggerH + root._hintGap
        visible: root._hasHint
        text: root.hint
        wrapMode: Text.WordWrap
        font.family:    Theme.font.family
        font.pixelSize: Theme.font.xs
        color:          Theme.color.fgMuted
        renderType:     Text.NativeRendering
    }

    /* ────────────────────── 条目列表 ────────────────────── */

    Item {
        id: listArea

        anchors.left:  parent.left
        anchors.right: parent.right
        y: root._triggerH + root._hintGap + root._hintH + root._listGap
        height: root._listH
        visible: root._hasList

        Repeater {
            id: listRep

            /* 结构模型是**个数**（int）：进度上报不动它，于是上报时这一列
             * 不重建。增删会重建 —— 已知代价，见文件头实测 4。 */
            model: root.count

            delegate: rowComp
        }
    }

    /* ── 行 ──
     *
     * 这个 delegate 的绑定会引用外层 id（root / Theme / Slots），qmllint 报
     * Unqualified access —— `delegate:` 开出的是一个**新的组件作用域**。
     * 抽成顶层 Component 不解决（QSkinKbd 首跑实测：换形态只是把警告挪了位置），
     * 本仓既定处置是**局部关掉这条警告**（先例与完整论证见 QSkinCalendar.qml
     * 文件头，那里有四份最小复现的实测记录）。 */
    // qmllint disable unqualified
    Component {
        id: rowComp

        Item {
            id: row

            required property int index

            /** 行数据 —— **每次都拿一份新副本**。这不是为了好看：
             *  返回内部那个稳定对象的话，QML 会把"值没变"的写入跳过，
             *  行里所有派生绑定从此不再刷新（实测 2，见文件头）。 */
            readonly property var item: root.itemAt(row.index)

            width:  root.width
            height: root.rowHeight

            /* ⚠ 这一行是**像素门禁抓出来的**（M27 示例屏首跑）。
             *
             * listArea 是裸 `Item`、里面只有一个 `Repeater` —— Repeater 是
             * **不定位的**，它只按顺序建子项，位置全留在 (0,0)。于是四行
             * 严丝合缝地叠在一起：名字、动作按钮、百分比全部糊成一团。
             *
             * 属性侧当时全绿：每行的 `width`/`height`/`item` 都对，
             * 冒烟测试也全绿 —— 因为**没有任何一条断言问过"行在哪"**。
             * 这正是本仓记过多次的那一类：「属性值对 ≠ 界面画对」。
             * 现有两道门：
             *   · `tests/smoke_m27.qml [7]` —— 逐行断言 y == index×(rowHeight+rowGap)
             *   · `.cache/_verify_m27px.py [P6]` —— 从像素上量相邻两行进度条的
             *     行距 == rowHeight + rowGap
             */
            y: row.index * (root.rowHeight + root.rowGap)

            /* ── 记号：上传中走转圈，其余走语义记号 ── */
            Loader {
                id: spinLoader

                x: 0
                y: root.nameTop + (root.nameHeight - root.markSize) / 2
                width:  root.markSize
                height: root.markSize
                sourceComponent: Slots.spinRing
                visible: row.item !== null && row.item.status === "uploading"

                Binding {
                    target: spinLoader.item
                    property: "control"
                    value: spinProxy
                    when: spinLoader.item !== null
                }
            }

            QtObject {
                id: spinProxy
                readonly property int  indicatorSize: root.markSize
                readonly property bool spinning: root.spinning
                readonly property color color: Theme.color.brand
            }

            Loader {
                id: markLoader

                x: 0
                y: root.nameTop + (root.nameHeight - root.markSize) / 2
                width:  root.markSize
                height: root.markSize
                sourceComponent: Slots.statusGlyph
                visible: row.item === null || row.item.status !== "uploading"

                Binding {
                    target: markLoader.item
                    property: "control"
                    value: markProxy
                    when: markLoader.item !== null
                }
            }

            QtObject {
                id: markProxy
                readonly property string status: root._markStatusOf(row.item)
                readonly property int    size:   root.markSize
            }

            /* ── 名字行 ── */
            Loader {
                id: nameLoader

                x: root.textLeft
                y: root.nameTop
                height: root.nameHeight
                width: Math.max(0, row.width - root.textLeft
                                   - row.actionsWidth - Theme.space.sm)
                sourceComponent: Slots.label

                Binding {
                    target: nameLoader.item
                    property: "control"
                    value: nameProxy
                    when: nameLoader.item !== null
                }
            }

            QtObject {
                id: nameProxy
                readonly property string text: row.item ? row.item.name : ""
                readonly property int labelAlignment: Text.AlignLeft
                readonly property bool enabled: true
            }

            /* ── 右侧：大小 ── */
            Text {
                id: sizeText

                anchors.right:  parent.right
                anchors.rightMargin: Theme.space.sm
                y: root.nameTop
                height: root.nameHeight
                verticalAlignment: Text.AlignVCenter
                text: (row.item && row.item.size > 0) ? root.formatSize(row.item.size) : ""
                font.family:    Theme.font.family
                font.pixelSize: Theme.font.xs
                color:          Theme.color.fgMuted
                renderType:     Text.NativeRendering
            }

            /* ── 状态行 ── */
            Text {
                id: statusText

                x: root.textLeft
                y: root.metaTop
                height: root.metaHeight
                width: Math.max(0, parent.width - root.textLeft - root.actionsWidth)
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: root._statusTextOf(row.item)
                font.family:    Theme.font.family
                font.pixelSize: Theme.font.xs
                color: row.item && row.item.status === "error"
                       ? Theme.color.danger
                       : (row.item && row.item.status === "success"
                          ? Theme.color.success : Theme.color.fgMuted)
                renderType:     Text.NativeRendering
            }

            /* ── 百分比（右端，只在传过之后有值）── */
            Text {
                id: percentText

                anchors.right:  parent.right
                anchors.rightMargin: Theme.space.sm
                y: root.metaTop
                height: root.metaHeight
                verticalAlignment: Text.AlignVCenter
                text: root._percentTextOf(row.item)
                font.family:    Theme.font.family
                font.pixelSize: Theme.font.xs
                color:          Theme.color.fgMuted
                renderType:     Text.NativeRendering
            }

            /* ── 轨道 ── */
            QSkinProgress {
                id: track

                x: root.textLeft
                y: root.trackTop
                width: Math.max(0, parent.width - root.textLeft - root.actionsWidth)
                height: root.trackThickness
                thickness: root.trackThickness
                showText: false
                progress: row.item ? row.item.progress : 0
                status: root._trackStatusOf(row.item)
                visible: root._hasTrack(row.item)
            }

            /* ── 动作按钮 ── */
            QQ.Row {
                id: actions

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.xxs

                /** 让名字行 / 状态行 / 轨道让出的宽度。做成绑定而不是常量：
                 *  文字按钮的宽度取决于它们自己的字（"重试"只在失败时出现），
                 *  写死一个数就会在错误态下被压住。 */
                readonly property int reservedWidth: implicitWidth

                QSkinButton {
                    text: root.retryText
                    variant: "text"
                    size: "sm"
                    accessibleName: qsTr("重新上传这个文件")
                    visible: row.item !== null && row.item.status === "error"
                    enabled: root.enabled
                    onClicked: root.retry(row.item.key)
                }

                QSkinButton {
                    text: root.removeText
                    variant: "text"
                    size: "sm"
                    accessibleName: qsTr("把这个文件从列表里去掉")
                    enabled: root.enabled
                    onClicked: root.remove(row.item.key)
                }
            }

            readonly property int actionsWidth: actions.reservedWidth
        }
    }
    // qmllint enable unqualified
}
