/****************************************************************************
 * QSkin · 冒烟测试 — M20：表单可选控件与文本输入
 *              （Radio / RadioGroup / Textarea / Label / Rate / InputOTP /
 *                Toggle / ToggleGroup）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 守这八件的**派生与账目**契约。渲染侧不在这个文件里 —— 它守不了。
 *
 * ── 这一批的属性侧风险与 M19 不同 ───────────────────────────────────────
 * M19 的风险是"派生量算对了，但算的是一件不相干的事"。这一批多了一类，
 * 而且这一类更隐蔽：**"值改了，但改动没有到达该到的地方"**。
 *
 *   ① `QSkinRadioGroup.value` 被宿主直接赋值 —— 变量变了、`selectionChanged`
 *      也发了，但四个单选框一个都没动。原因是"推送"只写在 `_selectFrom()`
 *      里，于是宿主那条路径漏掉了它。**属性侧读 `value` 一切正常。**
 *      修法是把推送挂在 `onValueChanged` 上：值的入口只有一个。
 *   ② `QSkinTextarea` 的截断原本直接写 `editor.text`，那会把
 *      `text: root.text` 这条**绑定**打掉 —— 截断生效了，但此后宿主
 *      再改 `text` 就同步不进来了。这类缺陷只在"改两次"时才现形。
 *   ③ `QSkinRadio` 的 `value` 是 `undefined` 时，`undefined === undefined`
 *      为真 —— 组会把"没写 value 的成员"也勾上。四个成员一起亮，
 *      而每一项单看都"没错"。
 *
 * 所以下面的断言都写成**恒等式或区间**，并且刻意包含"反面"：
 * 该不动的没动、该不被勾上的没被勾上。
 *
 * ── 断言上限 8 条（位掩码退出码的数学约束）─────────────────────────────
 * 详见 tools/test.sh 文件头。合并规则按**组件**：
 *   [0] Radio 组推选中  [1] Radio 导航与 roving tabindex
 *   [2] Textarea 行数   [3] Textarea 截断与计数器
 *   [4] Label 必填标记  [5] Rate 吸附与半星
 *   [6] InputOTP 几何   [7] Toggle / ToggleGroup
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int mask: 0
    property int idx: 0
    property int doneCount: 0

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    /* ══════════════════ [0] Radio：组推选中 ══════════════════ */

    QSkinRadioGroup { id: grpA; value: "md" }
    QSkinRadio { id: aSm;    group: grpA; value: "sm"; text: "小" }
    QSkinRadio { id: aMd;    group: grpA; value: "md"; text: "中" }
    QSkinRadio { id: aLg;    group: grpA; value: "lg"; text: "大"; enabled: false }
    /* 没写 value 的成员 —— 它永远不该被自动勾上 */
    QSkinRadio { id: aNoVal; group: grpA; text: "无值" }

    /* ══════════════════ [1] Radio：导航 ══════════════════ */

    QSkinRadioGroup { id: grpB; value: "r1" }
    QSkinRadio { id: b1; group: grpB; value: "r1"; text: "一" }
    QSkinRadio { id: b2; group: grpB; value: "r2"; text: "二"; enabled: false }
    QSkinRadio { id: b3; group: grpB; value: "r3"; text: "三" }
    QSkinRadio { id: b4; group: grpB; text: "四" }

    /* 一个都没选：roving tabindex 该落在第一个**可用**成员上 */
    QSkinRadioGroup { id: grpC }
    QSkinRadio { id: c1; group: grpC; value: "c1"; text: "甲" }
    QSkinRadio { id: c2; group: grpC; value: "c2"; text: "乙" }

    /* ══════════════════ [2][3] Textarea ══════════════════ */

    QSkinTextarea { id: taFixed; rows: 3 }
    QSkinTextarea { id: taGrow;  rows: 3; autoGrow: true }
    QSkinTextarea { id: taGrow5; rows: 3; autoGrow: true
                  text: "1\n2\n3\n4\n5" }
    QSkinTextarea { id: taGrowCap; rows: 2; autoGrow: true; maxRows: 4
                  text: "a\nb\nc\nd\ne\nf" }
    /* 初值在**声明期**给：截断会在创建时发生一次，而 run() 是
     * Qt.callLater 里跑的 —— 读它时绑定已经落定。若改成在 run() 里
     * 现写现读，读到的是"绑定还没回推"的中间态（见 [3] 的注释）。 */
    QSkinTextarea { id: taMax; rows: 2; maxLength: 4; maxCount: true
                  text: "abcdefgh" }
    /* maxCount 有、maxLength 没有 → 计数器不该出现（它不知道分母） */
    QSkinTextarea { id: taMaxOnly; rows: 2; maxCount: true }

    /* ══════════════════ [4] Label ══════════════════ */

    QSkinLabel { id: lbReq;  text: "用户名"; required: true }
    QSkinLabel { id: lbOpt;  text: "用户名" }
    /* muted 只改**颜色**、不改盒子。要断言这一点，两个标签的文本必须
     * **一样** —— 初版这里写的是"（可选）"，于是
     * `lbMuted.implicitWidth === lbOpt.implicitWidth` 实际比的是两个
     * 不同字符串的宽度，**恒假**：这条断言从写下来那天起就是红的，
     * 而它看上去像在守一条真契约。见 [4] 段的注释。 */
    QSkinLabel { id: lbMuted; text: "用户名"; variant: "muted" }

    /* ══════════════════ [5] Rate ══════════════════ */

    QSkinRate { id: rateInt;  count: 5; size: 20; gap: 4; value: 3.4 }
    QSkinRate { id: rateHalf; count: 5; size: 20; gap: 4
              allowHalf: true; value: 2.5 }
    QSkinRate { id: rateRo;   count: 5; size: 20; gap: 4; readOnly: true; value: 2 }
    QSkinRate { id: rateClr;  count: 5; size: 20; gap: 4; value: 3 }

    /* ══════════════════ [6] InputOTP ══════════════════ */

    QSkinInputOTP { id: otp; length: 6; separator: "-"; separatorEvery: 3 }
    QSkinInputOTP { id: otpNoSep; length: 4 }
    QSkinInputOTP { id: otpDone; length: 6; onCompleted: root.doneCount++ }

    /* ══════════════════ [7] Toggle / ToggleGroup ══════════════════ */

    QSkinToggle { id: tgSolo; text: "加粗" }

    QSkinToggleGroup { id: tgOne }
    QSkinToggle { id: tA;  group: tgOne; value: "a"; text: "A" }
    QSkinToggle { id: tB;  group: tgOne; value: "b"; text: "B" }
    QSkinToggle { id: tNoVal; group: tgOne; text: "无值" }

    QSkinToggleGroup { id: tgMulti; multiple: true; maxSelected: 2 }
    QSkinToggle { id: m1; group: tgMulti; value: 1; text: "1" }
    QSkinToggle { id: m2; group: tgMulti; value: 2; text: "2" }
    QSkinToggle { id: m3; group: tgMulti; value: 3; text: "3" }

    QSkinToggleGroup { id: tgEmpty }

    /* ══════════════════ 断言 ══════════════════ */

    function run() {
        /* ── [0] Radio：组推选中、排他、禁用的点不动 ──
         *
         * 三条互斥候选各自的取证方式：
         *   · 声明期就给的 value（grpA 的 "md"）→ 靠 `_register()` 推送
         *   · 用户点一个成员 → 靠 `_selectFrom()`
         *   · 宿主**直接写** `value` → 靠 `onValueChanged`
         * 第三条是这一批抓出来的缺陷所在：修之前它只改一个变量。
         * 所以这里显式走一次 `grpA.value = "lg"` —— 若推送没挂在
         * `onValueChanged` 上，`aLg.checked` 会是 false，这条立刻红。
         *
         * `aNoVal` 守"空值相等"：它的 value 是 undefined，而
         * `undefined === undefined` 为真 —— 不显式挡住的话它会跟着一起亮。 */
        var r0 = grpA.count === 4
                 && grpA.value === "md"
                 && aMd.checked === true
                 && aSm.checked === false
                 && aNoVal.checked === false
        aSm._activate()
        var r1 = grpA.value === "sm" && aSm.checked === true && aMd.checked === false
        aSm._activate()                       /* 已是选中 → **不取消** */
        var r2 = grpA.value === "sm" && aSm.checked === true
        grpA._selectFrom(aLg)                 /* 禁用成员：点不动 */
        var r3 = grpA.value === "sm"
        grpA.value = "lg"                     /* 宿主直接写 → 必须也推 */
        var r4 = aLg.checked === true && aSm.checked === false && aNoVal.checked === false
        root.expect(r0 && r1 && r2 && r3 && r4
                    && grpA.hasSelection === true
                    && grpA._isTabStop(aLg) === true
                    && grpA._isTabStop(aSm) === false)

        /* ── [1] Radio：方向键导航 + roving tabindex ──
         *
         * 导航三条规则：**跳过禁用**、**跳过没有 value 的**、**两端回绕**。
         * grpB 的成员顺序是 [b1, b2(禁用), b3, b4(无 value)]，
         * 从 b1 往后走一格必须落到 b3（连跳两个），再走一格回到 b1。
         * 写错任何一条，落点就会停在一个禁用成员或一个没有 value 的成员上。
         *
         * roving tabindex：一组里只有**选中的**那个可以 Tab 到；
         * 一个都没选时（grpC）落到第一个可用成员上。若把
         * `activeFocusOnTab` 写成恒真，键盘用户要按 N 次 Tab 才能穿过这一组。 */
        grpB._moveFrom(b1, 1)
        var n1 = grpB.value === "r3" && b3.checked === true && b1.checked === false
        grpB._moveFrom(b3, 1)                 /* b4 无 value → 再跳 → 回绕到 b1 */
        var n2 = grpB.value === "r1" && b1.checked === true && b3.checked === false
        root.expect(n1 && n2
                    && grpB._isTabStop(b1) === true
                    && grpB._isTabStop(b3) === false
                    && grpC.hasSelection === false
                    && grpC._isTabStop(c1) === true
                    && grpC._isTabStop(c2) === false)

        /* ── [2] Textarea：行数算术（固定 / 自增长 / 上下夹取）──
         *
         * `visibleRows = clamp(max(rows, 逻辑行), ∞, maxRows)`
         * 三档全部取证，因为三者可以各自写对而合起来写错：
         *   taFixed    autoGrow 关 → 恒等于 rows（内容多长都一样）
         *   taGrow     1 行 + rows 3 → 3（**下夹**：长不高也不该缩到 1 行）
         *   taGrow5    5 行 → 5（真的长了）
         *   taGrowCap  6 行 + maxRows 4 → 4（**上夹**）
         *
         * 高度写成恒等式：`visibleRows × 行高 + 上下内距 + 计数器条`。
         * 行高**取令牌**（`round(font.sm × lineHeightBody)`）而不是常量 22 ——
         * 行距是主题的事，写死等于把主题的选择搬进断言。
         *
         * 逻辑行只数换行符、不数折行：折行数要等 TextEdit 度量完才有值，
         * 读它等于"用实现验证实现"（文件头有完整取舍）。 */
        var lh = Math.round(Theme.font.sm * Theme.font.lineHeightBody)
        var pd = Theme.space.md
        root.expect(taFixed.lineHeight === lh
                    && taFixed.padding === pd
                    && taFixed.logicalRows === 1        /* 空串算 1 行 */
                    && taFixed.visibleRows === 3
                    && taGrow.visibleRows === 3
                    && taGrow5.visibleRows === 5
                    && taGrowCap.visibleRows === 4
                    && taFixed.implicitHeight === 3 * lh + pd * 2
                    && taGrow5.implicitHeight === 5 * lh + pd * 2
                    && taGrowCap.implicitHeight === 4 * lh + pd * 2)

        /* ── [3] Textarea：截断级联与计数器 ──
         *
         * 这一段守的是**绑定没被打掉**。宿主写一个超长的 text：
         *   写进去 → 编辑器拿到 → 截断（只写回 root.text）→ 绑定再推回去
         * 收敛后 `text` 必须正好是上限那么长。
         *
         * ⚠ 这里刻意走"写两次"的路径：第一次超长（触发截断），第二次
         * 写一个正常长度的新值。若截断那一步是直接写 `editor.text`，
         * 绑定会在第一次之后失效，于是**第二次写不进去** —— 屏幕上
         * 显示的还是上一次的截断结果。只写一次的测试永远抓不到它。
         *
         * ⚠⚠ 但"第二次写不进去"这件事，**只读 `charCount` 是看不见的**：
         * 宿主写的就是 `text`，`charCount` 读的也是 `text`，它当然跟着
         * 变成 2 —— 不一致的那一边在**编辑器**里。第一版就是只读
         * `charCount`，对着这个变异**逃掉了**（8 组里唯一一组 MISSED）。
         * 所以这里改成同时读 `editorText`（QSkinTextarea 为此公开的只读
         * 属性，理由见那边的注释）。教训：**判据要落在"会坏的那一边"**
         * —— 缺陷改变的是编辑器里的文本，那就要去读编辑器。
         *
         * ⚠⚠⚠ 还有一层时序：`text` 与 `editor` 之间的回推**不是同步的**。
         * 第一版在 `taMax.text = "abcdefgh"` 之后**立刻**读 `charCount`
         * 期望 4 —— 它曾经是绿的，但绿得没有道理：只要换一种读写顺序、
         * 或者在控件上多挂一条无关的绑定，那次读就会拿到还没被截断的 8
         * （实测：把 `editorText` 这条只读属性刚加上去，这一条立刻由绿转红）。
         * 所以现在把初值放到**声明期**（截断发生在创建时），判定放到
         * `run()`（`Qt.callLater` 里跑，至少过了一轮）—— 读的是落定值。
         * 这与 smoke_m20_theme.qml 里那条「`Behavior on color` 让"赋值后
         * 立即读"变成读到动画起点」是同一族：**测量本身也要有确定的时序。**
         *
         * 计数器：`showCount = maxCount && maxLength > 0`。
         * taMaxOnly 守"有计数器但没分母"那一档 —— 它必须**不**出现，
         * 否则屏幕上会显示一个 "0 / 0"。 */
        /* 先读的必须是**已经落定**的状态：taMax 的初值是声明期给的
         * （见声明处），而 run() 在 Qt.callLater 里跑 —— 至少过了一轮。 */
        var t1 = taMax.charCount === 4                /* 截断生效：8 → 4 */
                 && taMax.editorText === "abcd"       /* 编辑器也真的跟上了 */
        taMax.text = "xy"                             /* 第二次写：正常长度 */
        var t2 = taMax.charCount === 2
                 && taMax.editorText === "xy"         /* 也必须到得了编辑器 */
        root.expect(t1 && t2
                    && taMax.editorText === taMax.text      /* 不变量 */
                    && taMax.maxLength === 4
                    && taMax.showCount === true
                    && taMax.counterStrip === taMax.counterHeight
                    && taMax.implicitHeight === 2 * lh + pd * 2 + taMax.counterHeight
                    && taMaxOnly.showCount === false
                    && taMaxOnly.counterStrip === 0
                    && taFixed.showCount === false
                    && taFixed.counterStrip === 0)

        /* ── [4] Label：必填标记的账目 ──
         *
         * 标记是**一个 10×10 的矢量块**，不是 "*" 字符。于是
         *     「有必填标记的标签」−「没有的标签」= markerSize + gap
         * 是一个**与字体无关的恒等式**（12 = 10 + 2）。写成"大概更宽"
         * 就守不住"标记尺寸被改小"；写成这个差，改一个数就红。
         *
         * `labelAlignment` 必须是左对齐：插槽的默认居中（那是给按钮的），
         * 标签若居中，表单里每个字段名都会跑到自己的格子中间。
         *
         * 关于"它用的确实是 label 插槽"这件事 —— 那属于**装载**侧的契约，
         * 由 smoke_m20_theme.qml 守（这里只能证明几何对）。
         *
         * ── 这一条里出过两处判据错（都是判据错，不是实现错）──────────
         * ① 标记尺寸：曾经直接绑 `Shape.implicitWidth: markerSize`，而
         *    `Shape` 的隐式尺寸由它自己按路径包围盒算，绑定被盖掉 ——
         *    属性读 10、布局按 8.75 排。**是这条差式抓出来的**，修的是
         *    实现（改成 `Layout.preferredWidth`）。
         * ② `lbMuted` 那半条：比的是两个不同文本的宽度，恒假。
         *    修的是判据（把文本对齐）。
         * 一条红断言里可以**同时**藏着一处实现错和一处判据错 ——
         * 所以红了之后要逐项拆开看，不能整条"改到绿"为止。 */
        root.expect(lbReq.required === true
                    && lbOpt.required === false
                    && lbReq.markerSize === 10
                    && lbReq.gap === Theme.space.xxs
                    && lbReq.implicitWidth - lbOpt.implicitWidth
                       === lbReq.markerSize + lbReq.gap
                    && lbReq.labelAlignment === Text.AlignLeft
                    && lbMuted.variant === "muted"
                    && lbMuted.implicitWidth === lbOpt.implicitWidth)

        /* ── [5] Rate：吸附、半星份额、清零、只读 ──
         *
         * 份额（fracAt）是"画出来几成"的唯一来源，也是像素核验要量的
         * 那个数 —— 两边指着同一个函数，于是"属性对而界面错"没有缝隙。
         *
         *   整数模式 value 3.4 → snapped 3 → frac(2)=1、frac(3)=0
         *   半星模式 value 2.5 → snapped 2.5 → frac(2)=0.5（**精确一半**）
         *
         * `_valueAt` 是"点在哪个位置 = 几分"，它决定半星到底能不能被
         * 点出来：星宽 20、步长 24，x=2 落在第一颗星的前半 → 0.5。
         *
         * 清零（allowClear）与只读各有一条反面：
         *   · 同一个值再点一次 → 归零；关掉 allowClear 后 → 保持不变
         *   · 只读时点哪都不动 */
        var sMid = rateHalf._valueAt(2)
        var sEnd = rateHalf._valueAt(14)
        var sSec = rateHalf._valueAt(26)
        rateClr._commit(3)                    /* 与当前值相同 → 清零 */
        var clrA = rateClr.snapped === 0
        rateClr._commit(4)
        var clrB = rateClr.snapped === 4
        rateClr.allowClear = false
        rateClr._commit(4)                    /* 关掉清零 → 保持不变 */
        var clrC = rateClr.snapped === 4
        rateRo._commit(5)                     /* 只读 → 不动 */
        root.expect(rateInt.snapped === 3
                    && rateInt.fracAt(2) === 1
                    && rateInt.fracAt(3) === 0
                    && rateHalf.snapped === 2.5
                    && rateHalf.fracAt(1) === 1
                    && rateHalf.fracAt(2) === 0.5
                    && rateHalf.fracAt(3) === 0
                    && sMid === 0.5 && sEnd === 1 && sSec === 1.5
                    && rateHalf._valueAt(200) === 5
                    && rateInt.step === rateInt.starSize + rateInt.gap
                    && rateInt.implicitWidth
                       === 5 * rateInt.starSize + 4 * rateInt.gap
                    && clrA && clrB && clrC
                    && rateRo.snapped === 2
                    && rateRo.readOnly === true)

        /* ── [6] InputOTP：几何必须是纯算术 + 完成信号只发一次 ──
         *
         * 第 i 格的 x = `i×步长 + 它前面几个分隔符 × 分隔符步长`。
         * 这里同时验三样：
         *   · 逐格步长（xOf(1)-xOf(0) 恰好一个 stride）
         *   · 跨过分隔符那一跳（xOf(3) = 3×stride + sepStride）
         *   · 总宽用**另一条表达式**算一遍（**7 个盒子** —— 6 格 +
         *     1 个分隔符 —— 之间有 **6 道缝**，即 `6c + 6g + sw`）——
         *     与 xOf 的实现不同路，所以它不是自证。
         *
         *     ⚠ 初版这里写的是「6 格 + 5 道缝 + 分隔符盒 + 两侧各一道缝」，
         *     **多算了一道缝**：分隔符是**插进**原有的那道缝里，不是额外
         *     再占一道（xOf 只在跨越分隔符时多走一个 sepStride−stride）。
         *     实测渲染宽度 304 = 6×40 + 6×8 + 16，与像素核验量到的 W 一致。
         *     所以是**这条断言写错了**，不是实现错了 —— 判据红的时候先
         *     分清"实现错"还是"判据错"，别把对的实现改成迁就错的判据。
         *
         * `indexOfX` 用相邻两格的**几何中缝**判界：带分隔符时那道缝
         * 宽 32px（16 分隔符 + 两侧各 8），第一版拿 `xOf(i)-gap/2`
         * 当界，把整段缝判给了左边那格("点缝里跳回上一格")。
         *
         * `activeIndex` 未聚焦时必须是 -1：没聚焦还亮着一格，是在说
         * "你正在这里输入"，而那句是假的。
         *
         * completed 只发一次：先给一个 5 位的（不该发），再补满（发一次），
         * 再把同一个值写一遍（**不**再发）。 */
        var mid23 = (otp.xOf(2) + otp.cellSize + otp.xOf(3)) / 2
        otp.value = "123"
        otpDone.value = "12345"
        var d0 = root.doneCount === 0 && otpDone.isComplete === false
        otpDone.value = "123456"
        var d1 = root.doneCount === 1 && otpDone.isComplete === true
        otpDone.value = "123456"
        var d2 = root.doneCount === 1
        root.expect(otp.cellCount === 6
                    && otp.stride === otp.cellSize + otp.gap
                    && otp.sepStride === otp.separatorWidth + otp.gap
                    && otp.sepCount === 1
                    && otp.xOf(0) === 0
                    && otp.xOf(1) === otp.stride
                    && otp.xOf(3) === 3 * otp.stride + otp.sepStride
                    && otp.implicitWidth
                       === 6 * otp.cellSize + 6 * otp.gap + otp.separatorWidth
                    && otpNoSep.sepCount === 0
                    && otpNoSep.implicitWidth === 4 * otpNoSep.cellSize + 3 * otpNoSep.gap
                    && otp.indexOfX(mid23 - 2) === 2
                    && otp.indexOfX(mid23 + 2) === 3
                    && otp.activeIndex === -1
                    && otp.hasFocus === false
                    && otp.filledCount === 3
                    && otp.isComplete === false
                    && d0 && d1 && d2)

        /* ── [7] Toggle / ToggleGroup ──
         *
         * 独立开关：点一下翻、再点一下翻回来（它没有组，checked 归自己）。
         *
         * 单选组：点 B → 只有 B；**再点 B 不动**（单选组不清空 —— 那会
         * 产生"什么都没选"这个通常无意义的状态）。`tNoVal` 守空值相等。
         *
         * 多选组：连点 m1 / m2 → [1,2]；再点 m3 时**到上限**，规则是
         * "替换最后一个"而不是静默忽略 —— 用户点了没反应会被读成坏了。
         * 再点 m3 → 取消（多选模式下允许取消）。
         *
         * 顺序必须钉死：每一步都读一次中间值，因为最终态无法区分
         * "替换"与"清空重来"。 */
        var q0 = tgSolo.checked === false
        tgSolo._activate()
        var q1 = tgSolo.checked === true
        tgSolo._activate()
        var q2 = tgSolo.checked === false

        var g0 = tgOne.count === 3
        tB._activate()
        var g1 = String(tgOne.value) === "b" && tB.checked === true
                 && tA.checked === false && tNoVal.checked === false
        tB._activate()
        var g2 = String(tgOne.value) === "b" && tB.checked === true

        var e0 = tgEmpty.count === 0 && tgEmpty.selectedCount === 0
                 && tgEmpty.current === undefined
        m1._activate()
        var e1 = String(tgMulti.value) === "1"
        m2._activate()
        var e2 = String(tgMulti.value) === "1,2"
        m3._activate()
        var e3 = String(tgMulti.value) === "1,3"      /* 到上限 → 替换最后一个 */
        m3._activate()
        var e4 = String(tgMulti.value) === "1"        /* 多选 → 再点取消 */

        root.expect(q0 && q1 && q2
                    && g0 && g1 && g2
                    && tgOne.isSelected("b") === true
                    && tgOne.isSelected("a") === false
                    && tgOne.current === "b"
                    && tgMulti.limit === 2
                    && tgMulti.multiple === true
                    && e0 && e1 && e2 && e3 && e4)

        Qt.exit(root.mask)
    }

    /* 推迟一轮：Qt Quick Layouts 把尺寸重算放在 polish 阶段，
     * 在 onCompleted 里同步读会读到重算之前的值（见 smoke_sizes.qml）。 */
    Component.onCompleted: function() { Qt.callLater(root.run) }
}
