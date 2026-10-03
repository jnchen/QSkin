/****************************************************************************
 * QSkin · 冒烟测试 —— M8：反馈三件套（Dialog / Drawer / Toast）+ Form 校验
 *
 * 断言写法见 tools/test.sh 文件头：≤ 8 条，bit n = 断言 [n]。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int failures: 0

    function expect(ok) { if (!ok) root.failures++ }

    QSkinDialog {
        id: dlg

        title: "确认删除"
        panelWidth: 320

        Body { text: "删除后不可恢复。" }

        footer: [
            QSkinButton { text: "取消"; onClicked: dlg.close() },
            QSkinButton { text: "删除"; variant: "danger"; onClicked: dlg.close() }
        ]
    }

    QSkinDrawer {
        id: drw

        edge: "right"
        panelWidth: 280
        title: "设置"
    }

    QSkinToast { id: toast; maxVisible: 3 }

    QSkinForm {
        id: form

        QSkinFormItem {
            id: f1

            label: "用户名"; required: true
            rules: [
                { required: true, message: "请输入用户名" },
                { minLength: 2,   message: "至少 2 个字符" }
            ]

            QSkinInput { text: "" }
        }

        QSkinFormItem {
            id: f2

            label: "邮箱"
            rules: [ { pattern: /^.+@.+$/, message: "邮箱格式不对" } ]

            QSkinInput { text: "a@b.c" }
        }

        QSkinFormItem {
            id: f3

            label: "条款"; required: true
            rules: [ { required: true, message: "请勾选条款" } ]

            QSkinCheckBox { }
        }
    }

    Timer { id: stage1Timer; interval: 300;  running: true;  onTriggered: root.stage1() }
    Timer { id: stage2Timer; interval: 800;  running: false; onTriggered: root.stage2() }

    function stage1() {
        /* [0] Dialog 打开（close 后的状态留到 stage2 验：
         *     定义了 exit Transition 的 Popup，visible 要等
         *     退场动画播完才变 false —— Qt 的设计，不是 bug） */
        dlg.open()
        root.expect(dlg.opened === true)
        dlg.close()

        /* [1] Drawer：edge 语义派生 + 开合。垂直边切换后 _horizontal 翻转 */
        drw.open()
        var drwOpen = drw.opened === true && drw._horizontal === true
        drw.close()
        drw.edge = "bottom"
        root.expect(drwOpen && drw._horizontal === false)

        /* [2] Toast 队列：连发 4 条（duration 给足，测试期不消失），
         *     maxVisible 3 → 可见 3 条、排队 1 条 */
        toast.show("一", "success", 60000)
        toast.show("二", "info",    60000)
        toast.show("三", "warning", 60000)
        toast.show("四", "danger",  60000)
        root.expect(toast._items.length === 3 && toast._queue.length === 1)

        /* [3] Toast 类型色映射 */
        root.expect(toast._typeColor("success") === Theme.color.success
                    && toast._typeColor("danger")  === Theme.color.danger
                    && toast._typeColor("info")    === Theme.color.info)

        /* [4] Form 聚合校验：f1 空、f3 未勾 → 整体不过 */
        root.expect(form.validateAll() === false)

        /* [5] 分字段错误：f1 必填、f2 格式对没错、f3 要求勾选 */
        root.expect(f1.errorText === "请输入用户名"
                    && f2.errorText === ""
                    && f3.errorText === "请勾选条款")

        /* [6] 修正数据后单字段过：用户名 2 字符 + 勾选条款 */
        f1._firstControl().text = "ab"
        f3._firstControl().checked = true
        root.expect(f1.validate() === true && f3.validate() === true)

        stage2Timer.start()
    }

    function stage2() {
        /* [7] 退场动画播完：Dialog / Drawer 都关上；实时重校（出过错后
         *     值变化自动重算）+ 聚合错误收集 */
        f1._firstControl().text = "a"          /* 触发 onTextChanged 重校 → 长度错 */
        root.expect(dlg.opened === false
                    && drw.opened === false
                    && f1.errorText === "至少 2 个字符"
                    && form.errors().length === 1
                    && form.errors()[0].label === "用户名")

        Qt.exit(root.failures & 0xFF)
    }
}
