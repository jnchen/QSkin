/****************************************************************************
 * QSkin · 示例 —— M15.1：图标归位（chevronIndicator 插槽与它的五个使用处）
 *
 * ── 交互式跑（推荐先跑这个）────────────────────────────────────────────
 *     ./tools/run.sh examples/HelloIcons.qml
 *
 * 顶部一排按钮切换主题 / 展开收起 / 开合下拉与日历。看的就是**同一个动作
 * 在四套主题下的四种笔画**。
 *
 * ── 抓图（这个文件同时是截图入口，图存到 .cache/）──────────────────────
 *     ./tools/shot.sh examples/HelloIcons.qml theme=tdesign state=open shot=1
 *     ./tools/shot.sh examples/HelloIcons.qml theme=tdesign mode=dark state=open shot=1
 *
 * 为什么抓图入口和交互示例**是同一个文件**：分两份必然漂移 ——
 * 示例改了场景、抓图脚本忘了跟，于是"验过的"和"给人看的"不是同一个东西。
 * 而 tools/shot.sh 需要一个驱动文件，那就让这个文件兼两份工：不给 shot
 * 参数就是普通交互示例，给了就摆好场景抓图退出。
 *
 * 参数：
 *     theme = tdesign | ant | arco | shadcn
 *     mode  = light | dark（默认 light）
 *     state = closed —— 树全收起、下拉未开、翻月面板未开
 *             open   —— 树展开、下拉打开、翻月面板打开（**箭头翻过面**）
 *     shot  = 给了就进入抓图模式（摆好场景、存盘、退出）；不给则留在交互模式
 *
 * ── 这一板要看的是什么 ─────────────────────────────────────────────────
 * 图片里五处箭头必须**笔画一致**（同一主题下是同一种图标语言）：
 *
 *   ① 树形展开箭头   QSkinTable（tree mode）
 *   ② 排序方向三角   QSkinTable 表头
 *   ③ 下拉展开箭头   QSkinSelect
 *   ④ 上下页箭头     QSkinPagination
 *   ⑤ 翻月箭头       QSkinDatePicker 面板
 *
 * 改造之前 ①③④⑤ 是**四种不同画法**（字符 "▾" / 自绘三角 / 按钮文字 "‹" /
 * 自绘折线），② 是字符 "↓"。这一板就是验收它们已经归位。
 * state=open 额外验"展开后翻面"的角度。
 *
 * ── 为什么四处各画一遍（根因不在控件里）────────────────────────────────
 * 契约层 Slots.qml 的 indicator 家族从 M1 起就写着"勾选框、开关轨道、
 * **展开箭头**"，但那一格**从来没被实现过**。于是谁要用谁自己画。
 * M15.1 把它补上（BasicChevronIndicator + 四主题各一份），四处一起收编。
 * 详见 src/contracts/slots/BasicChevronIndicator.qml 文件头。
 *
 * ── 本环境实测结论（沿用 M12~M15 的三条，别再踩）──────────────────
 * ① 根节点必须是 Window（见 QSkinWindow）。Item 作根节点事件循环起不来。
 * ② 抓图用 Item.grabToImage，不要用 Window.grabWindow（返回空图且静默）。
 * ③ 子控件宽度要给绝对像素 —— 从 implicitWidth 反推会读到半算完的值。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0
import QSkin.Theme.AntDesign 1.0
import QSkin.Theme.ArcoDesign 1.0
import QSkin.Theme.Shadcn 1.0

QSkinWindow {
    id: win

    width: 900
    height: 640
    visible: true
    title: "QSkin · 图标归位（M15.1）"

    /* ---------- 命令行参数 ---------- */
    readonly property var args: Qt.application.arguments
    function argOf(key, dflt) {
        for (var i = 0; i < win.args.length; ++i) {
            var a = win.args[i]
            if (a.indexOf(key + "=") === 0) return a.substring(key.length + 1)
        }
        return dflt
    }
    readonly property string themeName: win.argOf("theme", "tdesign")
    readonly property string mode:      win.argOf("mode", "light")
    readonly property string state:     win.argOf("state", "closed")
    /** 抓图模式：摆好场景 → 存盘 → 退出。不给就留在交互模式 */
    readonly property bool shotMode: win.argOf("shot", "") !== ""

    /** 当前生效的皮肤：初始取命令行，交互模式下由控制条改 */
    property string activeTheme: win.themeName
    onActiveThemeChanged: win.applyTheme()

    function applyTheme() {
        Theme.mode = win.mode
        switch (win.activeTheme) {
            case "ant":    AntDesign.apply();   break
            case "arco":   ArcoDesign.apply();  break
            case "shadcn": Shadcn.apply();      break
            default:       TDesign.apply();     break
        }
    }

    readonly property var selectModel: ["设计稿", "需求文档", "接口说明", "测试用例"]

    /* ---------- 可抓取的内容区 ---------- */
    Item {
        id: canvas
        anchors.fill: parent

        /* 抓图要自己铺底：grabToImage 只抓 canvas 这一棵子树，
         * 窗口底色（QSkinWindow 的 Theme.color.bg）在 canvas 外面，抓不进来。
         *
         * 注意是 **bg** 不是 bgPage —— "bgPage" 是 TDesign CSS 变量
         * （--td-bg-color-page）的名字，QSkin 里**没有这个令牌**：写它不会报错，
         * 只会静默拿到 undefined，于是 Rectangle 不着色、抓图背景透明，
         * 同时日志里留一句 "Unable to assign [undefined] to QColor"。
         * 令牌命名沿用 Web 语义约定（bg / fg / border / brand），见 neutral.js。 */
        Rectangle {
            anchors.fill: parent
            color: Theme.color.bg
        }

        /* 交互模式下的控制条。抓图时隐藏，保证存盘画面就是验收画面的样子 */
        QSkinRow {
            x: 24
            y: 16
            gap: 8
            visible: !win.shotMode

            QSkinButton { text: "TDesign"; variant: win.activeTheme === "tdesign" ? "primary" : "default"
                        onClicked: win.activeTheme = "tdesign" }
            QSkinButton { text: "Ant";     variant: win.activeTheme === "ant" ? "primary" : "default"
                        onClicked: win.activeTheme = "ant" }
            QSkinButton { text: "Arco";    variant: win.activeTheme === "arco" ? "primary" : "default"
                        onClicked: win.activeTheme = "arco" }
            QSkinButton { text: "shadcn";  variant: win.activeTheme === "shadcn" ? "primary" : "default"
                        onClicked: win.activeTheme = "shadcn" }

            QSkinButton { text: "全部展开 / 收起"; variant: "text"
                        onClicked: win.treeExpanded = !win.treeExpanded }
            QSkinButton { text: "开关下拉"; variant: "text"; onClicked: select._toggle() }
            QSkinButton { text: "开关日历"; variant: "text"; onClicked: picker._toggle() }
        }

        /* QSkinColumn / QSkinRow 而不是 QtQuick 的 Column / Row：
         * QSkin.Foundation 也注册了这两个同名类型，而它的属性叫 gap 不叫
         * spacing。写裸名要靠在两个 import 之间消歧义，太脆弱。 */
        QSkinColumn {
            x: 24
            y: win.shotMode ? 20 : 60
            gap: 20

            /* ① 树形 + ② 排序：同一张表同时体现两处 */
            QSkinTable {
                id: table
                width: 560
                treeMode: true
                treeColumn: 0
                treeIndentWidth: 20
                sortColumn: 1
                sortDirection: "desc"
                columns: [
                    { title: "名称",  dataIndex: "name",  sortable: true },
                    { title: "大小",  dataIndex: "size",  sortable: true },
                    { title: "状态",  dataIndex: "state" }
                ]
                rows: [
                    { id: "src", name: "src", size: "—", state: "已同步", children: [
                        { id: "contracts", name: "contracts", size: "—", state: "评审中", children: [
                            { id: "qml-table",  name: "QSkinTable.qml",  size: "2.0k", state: "评审中" },
                            { id: "qml-select", name: "QSkinSelect.qml", size: "610",  state: "已同步" }
                        ] },
                        { id: "foundation", name: "foundation", size: "—", state: "已同步" }
                    ] },
                    { id: "docs", name: "docs", size: "—", state: "已同步", children: [
                        { id: "readme", name: "README.md", size: "1.5k", state: "已同步" }
                    ] }
                ]
            }

            /* ③ 下拉 + ④ 分页 同一行 */
            QSkinRow {
                gap: 24

                QSkinSelect {
                    id: select
                    width: 200
                    model: win.selectModel
                }

                QSkinPagination {
                    id: pager
                    total: 105
                    pageSize: 10
                    page: 3
                }
            }

            /* ④ 图标按钮：单独摆一行，看 QSkinButton.icon 的通路 */
            QSkinRow {
                gap: 12

                QSkinButton {
                    icon:          Slots.chevronIndicator
                    iconDirection: "left"
                    accessibleName: "上一页"
                    variant: "text"
                }
                QSkinButton {
                    icon:          Slots.chevronIndicator
                    iconDirection: "right"
                    accessibleName: "下一页"
                    variant: "text"
                }
                QSkinButton {
                    icon:          Slots.chevronIndicator
                    iconDirection: "down"
                    accessibleName: "展开"
                    variant: "default"
                    text: "更多"
                }
            }
        }

        /* ⑤ 日期选择器面板：翻月箭头在面板里 */
        QSkinDatePicker {
            id: picker
            x: 620
            y: win.shotMode ? 20 : 60
            width: 240
        }
    }

    /** 树的展开态，控制条那个按钮翻它 */
    property bool treeExpanded: true

    onTreeExpandedChanged: {
        if (treeExpanded) table.expandAll()
        else              table.collapseAll()
    }

    /* ---------- 摆场景 ---------- */
    Component.onCompleted: {
        win.applyTheme()
        table.expandAll()
        if (win.state === "open") {
            /* 弹层的公开入口就是 _toggle（与点一下输入框等价） */
            select._toggle()
            picker._toggle()
        }
    }

    /* ---------- 抓图（仅 shot 模式）----------
     * 存到 **.cache/** 而不是本文件旁边：截图是每轮的验证中间产物、
     * 不是交付物，跑完当轮就失效（换一行代码像素就可能变）。
     * `../.cache/` 是相对**本文件**解析的（resolvedUrl 的基准是 QML
     * 文件自身，不是 cwd），所以不管从哪个目录调用都落在仓库根下。
     * .cache 的清理策略见 tools/clean-cache.sh。 */
    Timer {
        interval: 1400
        running: win.shotMode
        onTriggered: {
            var base = Qt.resolvedUrl("../.cache/").toString().replace("file:///", "")
            var name = "icons_" + win.themeName + "_" + win.mode + "_" + win.state + ".png"
            canvas.grabToImage(function (res) {
                Qt.exit(res.saveToFile(base + name) ? 0 : 9)
            })
        }
    }
}
