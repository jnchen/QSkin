import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

/* ════════════════════════════════════════════════════════════════════════
 * M33-7 · 英文翻译在**运行期**真的生效吗
 *
 * 用法（由 tools/check-i18n-runtime.sh 驱动，一般不用手跑）：
 *     qml -platform offscreen -I .cache/qmlimports \
 *         --translation i18n/qskin_en.qm tests/scene_i18n.qml
 *
 * ── 为什么不能复用 smoke_m11 ────────────────────────────────────────────
 * smoke_m11 的 bit[4] 里有一条断言是「`amPmLabels` 的默认值是『上午/下午』」——
 * 它**只在没加载翻译的环境里成立**（冒烟不带 `--translation`）。
 * 拿它当翻译门禁会红，而红的现象看着像"i18n 坏了"。所以本文件另写断言。
 *
 * ── 这个场景为什么要跑**两遍** ──────────────────────────────────────────
 * 「英文出来了」这句话本身**不可证伪**：若断言全绿是因为场景压根没加载翻译，
 * 那这道门就是空的。所以 tools/check-i18n-runtime.sh 拿同一个文件跑两遍 ——
 * 带 `--translation` 必须恰好 **0**；不带必须**恰好**是声明的那位掩码
 * （见那个脚本头部的 `EXPECT_RED`）。两遍读数都与声明相符，门才成立。
 *
 *   ⚠ bit[7] 是**度量**不是**翻译** —— 两面都该绿，所以它不进 `EXPECT_RED`。
 *     它要的红面靠"把列宽压到装不下"来造（tools/falsify-i18n-runtime.py 的 R7）。
 *
 * ── bit[7] 为什么量的是**真实 Text** ────────────────────────────────────
 * 英文星期缩写比中文单字宽（实测 12 → 36），而星期头每格宽是 `colWidth`
 * （由控件宽度算出来的，**不是**主题令牌）。"装不装得下"只有控件自己画的
 * 那个 Text 知道 —— 另起一个 Text 再抄一遍字体，量的是**另一件事**
 * （本项目原话：量法不能与被测量共享硬编码假设）。所以这里递归 `children`
 * 把那 7 个 Text 找出来直接读 `implicitWidth`。
 * ⚠ 已知边界：这条只覆盖**内联**的星期头。`QSkinTimePicker` 的列头住在浮层里，
 *   offscreen + 无 Window 的环境下即使 `opened === true` 也不实例化（实测），
 *   所以那三列的宽度**没有**被本场景覆盖 —— 写在这里，不装作有。
 * ════════════════════════════════════════════════════════════════════════ */

Item {
    id: root

    property int failures: 0
    function bit(n, ok) { if (!ok) root.failures |= (1 << n) }

    /* ── 夹具：全部取**默认文案**（不传参数），测的是"构造时求值"这一步 ── */
    QSkinEmpty { id: emp }
    QSkinAlertDialog { id: dlg }
    QSkinList { id: lst }
    QSkinUpload { id: upl }
    QSkinTour { id: tour }
    QSkinPopconfirm { id: pcf }
    QSkinCommand { id: cmd }
    QSkinCascader { id: cas }
    QSkinQRCode { id: qr }
    QSkinTimePicker { id: tp }
    QSkinDatePicker { id: dp; panelMonth: 9 }
    QSkinCalendar { id: cal; width: 320; panelMonth: 9 }
    QSkinSteps { id: st; model: 3 }
    /* ⚠ `_colon` 是**只读派生量**（`!bordered && !vertical`），不能赋值 ——
     * 默认即 true，所以 `labelText` 天然带分隔符。这条实测过。 */
    QSkinDescriptionsItem { id: desc; label: "Name" }

    /* ⚠ 属性名首字母不能大写（QML 把大写开头当成类型引用）—— 实测撞过。 */
    readonly property var cjkRe:
        /[\u3400-\u4dbf\u4e00-\u9fff\u3000-\u303f\uff01-\uff5e]/

    /* ── 递归收集视觉子项 ────────────────────────────────────────────────
     * `children` 只给可视子项；`Loader.item` / Repeater 的 delegate 都在里面。
     * 深度设 16 是防"某种循环引用"把场景挂死 —— 挂死的表现不是红，是
     * test.sh 的 30 秒看门狗杀掉（那会报成 HANG，很有误导性）。 */
    function _walk(o, depth, out) {
        if (depth > 16 || o === null || o === undefined) return out
        var cs = o.children
        if (!cs) return out
        for (var i = 0; i < cs.length; ++i) {
            var c = cs[i]
            if (c === null || c === undefined) continue
            out.push(c)
            _walk(c, depth + 1, out)
        }
        return out
    }

    /* [0] 地基层：三个 `*Labels` 就是英文词表本身。
     *     一条 bit 覆盖 M33-6 新增的 21 条 message（7 星期 + 12 月名 + 2 上下午）——
     *     它们是**数据**、不是被拼出来的串，所以只能逐条钉。 */
    function checkLabels() {
        root.bit(0, DateUtil.weekdayLabels.length === 7
                   && DateUtil.weekdayLabels.join(",") === "Sun,Mon,Tue,Wed,Thu,Fri,Sat"
                   && DateUtil.monthLabels.length === 12
                   && DateUtil.monthLabels[0] === "Jan"
                   && DateUtil.monthLabels[8] === "Sep"
                   && DateUtil.monthLabels[11] === "Dec"
                   && DateUtil.amPmLabels.length === 2
                   && DateUtil.amPmLabels[0] === "AM"
                   && DateUtil.amPmLabels[1] === "PM")
    }

    /* [1] `formatTime` 的 A token：结构（由属性渲染）+ 具体词。
     *     最后一条 `HH:mm` 是**反向**的：没有 A 的 pattern 不许受影响。 */
    function checkFormatTime() {
        var t = DateUtil.makeTime(13, 45)
        root.bit(1, DateUtil.formatTime(t, "hh:mm A") === "01:45 PM"
                   && DateUtil.formatTime(DateUtil.makeTime(0, 5), "hh:mm A") === "12:05 AM"
                   && DateUtil.formatTime(DateUtil.makeTime(12, 0), "hh:mm A") === "12:00 PM"
                   && DateUtil.formatTime(t, "hh:mm A") === "01:45 " + DateUtil.amPmLabels[1]
                   && DateUtil.formatTime(t, "HH:mm") === "13:45"
                   && DateUtil.formatTime(t) === "13:45")
    }

    /* [2] 控件默认值**在构造时**就是英文。
     *     跨 12 个控件取一遍 —— 单看一个控件说明不了"翻译在 QML 加载前装好了"，
     *     因为那是全局事实；取一片是让它不容易被局部巧合糊过去。
     *     ⚠ 这里只碰**公开的可写文案属性**，不碰 Accessible（那条在 [6] 的扫描里）。 */
    function checkControlDefaults() {
        root.bit(2, emp.description === "No data"
                   && dlg.cancelText === "Cancel" && dlg.confirmText === "OK"
                   && lst.loadingText === "Loading…"
                   && lst.loadMoreText === "Load more"
                   && lst.noMoreText === "No more items"
                   && tour.prevText === "Previous" && tour.nextText === "Next"
                   && tour.finishText === "Done" && tour.skipText === "Skip"
                   && pcf.okText === "OK" && pcf.cancelText === "Cancel"
                   && cmd.placeholder === "Type a command or search…"
                   && cas.placeholderText === "Please select"
                   && tp.placeholderText === "Select time" && tp.okText === "OK"
                   && tp.columnLabels.join("|") === "Hr|Min|Sec"
                   && dp.placeholderText === "Select date"
                   && cal.todayText === "Today"
                   && qr.emptyText === "No content"
                   && upl.triggerText === "Choose file"
                   && upl.retryText === "Retry" && upl.removeText === "Remove")
    }

    /* [3] 占位符在英文下仍按位填入 —— 用**真实代码路径**（不是拼串）：
     *     `QSkinUpload` 的状态机文案带 `%1`，`QSkinSteps` 的数字模型走 `步骤 %1`。
     *     `error: ""` 是刻意的：那条 `%1` 只在 error 非空时用，
     *     不带它会被 `arg(undefined)` 糊出一个 "…: undefined"，那是假读数。 */
    function checkPlaceholders() {
        root.bit(3, upl._statusTextOf({ status: "success" }) === "Completed"
                   && upl._statusTextOf({ status: "error", error: "boom" })
                      === "Upload failed: boom"
                   && upl._statusTextOf({ status: "error", error: "" })
                      === "Upload failed"
                   && upl._statusTextOf({ status: "uploading", retryCount: 0 })
                      === "Uploading"
                   && upl._statusTextOf({ status: "uploading", retryCount: 2 })
                      === "Retrying (2)"
                   && upl._statusTextOf({ status: "queued" }) === "Waiting"
                   && st._fieldOf(0, "title", true) === "Step 1"
                   && st._fieldOf(2, "title", true) === "Step 3")
    }

    /* [4] 标点也翻：`：` → `": "`（**含尾随空格**）。
     *     空格在这里不是排版细节 —— 值紧跟着标签格起画（`contentX = pad + lw`），
     *     谁都不再加间距，所以 "Label:" 与 "Label: value" 的差别只在这一条译文里。
     *     ⚠ `_colon` 是派生量，断言它等于 true 是为了说明"这条路径真的走到了"。 */
    function checkColon() {
        root.bit(4, desc._colon === true
                   && desc.label === "Name"
                   && desc.labelText === "Name: ")
    }

    /* [5] 月标题：走 `DateUtil.monthLabels`，**不是** `qsTr("%1月")` 模板。
     *     后半条是**结构断言**（它确实是 monthLabels 的第 panelMonth-1 项），
     *     它在中文那面也成立 —— 这个 bit 的"红"由前半条给。 */
    function checkMonthHeader() {
        var i = Math.max(0, Math.min(11, cal.panelMonth - 1))
        var j = Math.max(0, Math.min(11, dp.panelMonth - 1))
        root.bit(5, cal.panelMonth === 9 && dp.panelMonth === 9
                   && cal.monthText === "Sep" && dp.monthText === "Sep"
                   && cal.monthText === DateUtil.monthLabels[i]
                   && dp.monthText === DateUtil.monthLabels[j])
    }

    /* [6] 广度扫描：一批**可读的**默认文案属性，一个都不许含 CJK。
     *     ⚠ 读不到（undefined / null）算**失败**，不跳过 —— 属性名写错一个字母
     *     就会让那一条静默消失，而"检查了 0 条"在本项目里一律算失败。
     *     条数下限 20 是同一个道理：扫描面自己缩水也要红。 */
    property var sweepList: [
        ["QSkinEmpty.description",               "text",  function () { return emp.description }],
        ["QSkinAlertDialog.cancelText",          "text",  function () { return dlg.cancelText }],
        ["QSkinAlertDialog.confirmText",         "text",  function () { return dlg.confirmText }],
        ["QSkinList.loadingText",                "text",  function () { return lst.loadingText }],
        ["QSkinList.loadMoreText",               "text",  function () { return lst.loadMoreText }],
        ["QSkinList.noMoreText",                 "text",  function () { return lst.noMoreText }],
        ["QSkinList.emptyText",                  "text",  function () { return lst.emptyText }],
        ["QSkinUpload.triggerText",              "text",  function () { return upl.triggerText }],
        ["QSkinUpload.retryText",                "text",  function () { return upl.retryText }],
        ["QSkinUpload.removeText",               "text",  function () { return upl.removeText }],
        ["QSkinTour.prevText",                   "text",  function () { return tour.prevText }],
        ["QSkinTour.nextText",                   "text",  function () { return tour.nextText }],
        ["QSkinTour.finishText",                 "text",  function () { return tour.finishText }],
        ["QSkinTour.skipText",                   "text",  function () { return tour.skipText }],
        ["QSkinPopconfirm.okText",               "text",  function () { return pcf.okText }],
        ["QSkinPopconfirm.cancelText",           "text",  function () { return pcf.cancelText }],
        ["QSkinCommand.placeholder",             "text",  function () { return cmd.placeholder }],
        ["QSkinCommand.emptyText",               "text",  function () { return cmd.emptyText }],
        ["QSkinCascader.placeholderText",        "text",  function () { return cas.placeholderText }],
        ["QSkinCascader.emptyText",              "text",  function () { return cas.emptyText }],
        ["QSkinQRCode.emptyText",                "text",  function () { return qr.emptyText }],
        ["QSkinTimePicker.placeholderText",      "text",  function () { return tp.placeholderText }],
        ["QSkinTimePicker.okText",               "text",  function () { return tp.okText }],
        ["QSkinTimePicker.columnLabels.join",    "text",  function () { return tp.columnLabels.join("|") }],
        ["QSkinDatePicker.placeholderText",      "text",  function () { return dp.placeholderText }],
        ["QSkinCalendar.todayText",              "text",  function () { return cal.todayText }],
        ["QSkinCalendar.monthText",              "text",  function () { return cal.monthText }],
        ["QSkinDescriptionsItem.labelText",      "text",  function () { return desc.labelText }]
    ]

    property int sweepChecked: 0
    property var sweepBad: []

    function checkNoCjkSweep() {
        var bad = []
        var n = 0
        for (var i = 0; i < root.sweepList.length; ++i) {
            var name = root.sweepList[i][0]
            var v = root.sweepList[i][2]()
            n += 1
            if (v === undefined || v === null) { bad.push(name + "=<读不到>"); continue }
            if (root.cjkRe.test(String(v))) bad.push(name + "=" + v)
        }
        root.sweepChecked = n
        root.sweepBad = bad
        root.bit(6, n >= 20 && bad.length === 0)
    }

    /* [7] 度量：英文星期头装得进**固定列宽**（见文件头）。
     *     从真实 Text 上读 `implicitWidth` —— 找不够 7 个也算失败：找不到
     *     说明控件结构变了，这条闸已经量不到东西了（"检查了 0 条算失败"）。 */
    property int wdFound: 0
    property real wdMax: 0

    function checkWeekHeaderWidth() {
        var all = root._walk(cal, 0, [])
        var wl = DateUtil.weekdayLabels
        var found = []
        for (var i = 0; i < all.length; ++i) {
            var t = all[i].text
            if (t === undefined || t === null) continue
            if (wl.indexOf(t) >= 0) found.push(all[i])
        }
        var maxW = 0
        var ok = (found.length === 7) && (cal.colWidth > 0)
        for (var j = 0; j < found.length; ++j) {
            var w = found[j].implicitWidth
            if (w > maxW) maxW = w
            if (w > cal.colWidth) ok = false
        }
        root.wdFound = found.length
        root.wdMax = maxW
        root.bit(7, ok)
    }

    Timer {
        interval: 800
        running: true
        repeat: false
        onTriggered: root.check()
    }

    function check() {
        root.checkLabels()
        root.checkFormatTime()
        root.checkControlDefaults()
        root.checkPlaceholders()
        root.checkColon()
        root.checkMonthHeader()
        root.checkNoCjkSweep()
        root.checkWeekHeaderWidth()

        /* 自证行：人看一眼就知道"这一面加载的是哪门语言"。
         * 门禁判成败靠下面的退出码，这行是诊断通道（两者各司其职）。 */
        console.log("[i18n-scene] week=" + DateUtil.weekdayLabels.join("/")
                    + " ap=" + DateUtil.amPmLabels.join("/")
                    + " empty=" + emp.description
                    + " colon=" + JSON.stringify(desc.labelText)
                    + " month=" + cal.monthText + "/" + dp.monthText
                    + " colW=" + cal.colWidth
                    + " wdFound=" + root.wdFound
                    + " wdMax=" + root.wdMax
                    + " sweep=" + root.sweepChecked
                    + (root.sweepBad.length > 0 ? (" BAD=" + root.sweepBad.join(",")) : ""))
        console.log("[i18n-scene] mask=" + root.failures)

        Qt.exit(Math.min(255, root.failures))
    }
}
