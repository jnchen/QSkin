/****************************************************************************
 * QSkin · 冒烟测试 —— M9：ButtonBar self-width 修复 + Slider + InputNumber
 *
 * 断言写法见 tools/test.sh 文件头：≤ 8 条，bit n = 断言 [n]。
 *
 * [0] 是 M3 老 bug 的回归哨兵：hug 模式的 ButtonBar（不设 width）
 *     必须横排。修复前 availW < stackBelow 恒触发堆叠并永久锁死。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int failures: 0

    /** bit n = 断言 [n] 失败 */
    function bit(n, ok) { if (!ok) root.failures |= (1 << n) }

    /* ── 被测对象 ─────────────────────────────────────────────── */

    /* [0] hug 模式：不设 width，宽度跟内容 —— 必须横排 */
    ButtonBar {
        id: hugBar
        x: 0; y: 0

        QSkinButton { text: "第一步" }
        QSkinButton { text: "跳过此步"; variant: "ghost" }
        QSkinButton { text: "继续"; variant: "text" }
    }

    /* [1] 受约束模式：显式窄 width —— 应堆叠（这才是堆叠的本职场景） */
    ButtonBar {
        id: narrowBar
        x: 0; y: 200
        width: 220

        QSkinButton { text: "确定继续" }
        QSkinButton { text: "保存草稿"; variant: "ghost" }
        QSkinButton { text: "放弃更改"; variant: "text" }
    }

    /* [2][3][4] Slider */
    QSkinSlider { id: posSlider;  width: 100; from: 0; to: 100; value: 50 }
    QSkinSlider { id: snapSlider; width: 100; from: 0; to: 100; stepSize: 10; value: 0 }
    QSkinSlider { id: boundSlider; from: 10; to: 20; value: 10 }

    /* [5][6] InputNumber */
    QSkinInputNumber { id: numStep; min: 0; max: 10; step: 1; value: 0 }
    QSkinInputNumber { id: numCommit; min: 0; max: 100; decimals: 1; value: 0 }

    /* [7] Form + InputNumber / Slider 的取值契约 */
    QSkinForm {
        id: form

        QSkinFormItem {
            id: qtyField

            label: "数量"; required: true
            rules: [ { test: function(v) { return v >= 5 }, message: "至少 5 件" } ]

            QSkinInputNumber { min: 1; max: 99; value: 1 }
        }

        QSkinFormItem {
            id: rateField

            label: "折扣"
            rules: [ { test: function(v) { return v <= 50 }, message: "不能超过 50%" } ]

            QSkinSlider { width: 160; from: 0; to: 100; value: 30 }
        }
    }

    /* ── 断言 ─────────────────────────────────────────────────── */

    Timer { interval: 300; running: true; repeat: false; onTriggered: root.stage1() }

    function stage1() {
        /* ── ButtonBar 布局状态（最直接的断言）───────────────────
         * 不要按 children 数组下标断言 y 值 —— primaryLeft 会在
         * 平台为 Windows 时把主按钮挪到最前，children 的下标顺序与
         * 视觉顺序可能不一致。ButtonBar 暴露了 stacked 只读 alias，
         * 直接读它才是测试的本意。 */

        /* [0] hug 模式横排：stacked=false，宽度大于高度 */
        root.bit(0, !hugBar.stacked && hugBar.width > hugBar.height)

        /* [1] 窄约束堆叠：stacked=true */
        root.bit(1, narrowBar.stacked)

        /* [2] position 派生量：value 50 / [0,100] → 0.5 */
        root.bit(2, Math.abs(posSlider.position - 0.5) < 1e-9)

        /* [3] stepSize 吸附：x=33 落在 30 的格点 */
        snapSlider._setValueFromX(33)
        root.bit(3, snapSlider.value === 30)

        /* [4] 步进 + 直达边界：_step 后 40；_setValue(to) 落在 20 */
        snapSlider._step(1)
        boundSlider._setValue(boundSlider.to)
        root.bit(4, snapSlider.value === 40 && boundSlider.value === 20)

        /* [5] 步进 + 钳制：0→1；到顶再步进停在 max */
        numStep._step(1)
        var steppedTo1 = (numStep.value === 1)
        numStep.value = 10
        numStep._step(1)
        root.bit(5, steppedTo1 && numStep.value === 10)

        /* [6] 草稿解析：越界钳制 / 非法回滚 / 小数位舍入 */
        root.bit(6, numCommit._commitText("999") === 100
                   && numCommit._commitText("abc") === null
                   && Math.abs(numCommit._commitText("2.34") - 2.3) < 1e-9)

        /* [7] Form 取值契约：value 控件走 test 规则；
         *     改值后 validate 反映新值（实时重校走 onValueModified） */
        var q1 = !qtyField.validate() && qtyField.errorText !== ""
        qtyField._control.value = 6
        var q2 = qtyField.validate()
        var r1 = rateField.validate()                    // 30 ≤ 50 → 通过
        rateField._control.value = 60
        rateField._touched = true                        // 先触发过一次才持续重校
        var r2 = !rateField.validate()                   // 60 > 50 → 拦下
        root.bit(7, q1 && q2 && r1 && r2)

        Qt.exit(Math.min(255, root.failures))
    }
}
