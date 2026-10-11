/****************************************************************************
 * QSkin · 示例 —— M26：树选择、级联、取色器、穿梭框、自动完成、提及、Tabs 内容区
 *
 * 这一批七件的共同点：**六件是"输入框 + 浮层"，一件是实心复合体**。
 *
 * ── 抓不到的东西先说清楚（与 M24 / M25 同一条能力边界）──────────────
 * `Popup` 是**独立窗口**，`grabToImage(win.contentItem)` 抓不到它。
 * 所以 TreeSelect / Cascader / ColorPicker / AutoComplete / Mentions 的
 * **面板内部**（色域面、色相条、色板、候选行）在这一屏上是量不到的。
 *
 * 于是这一屏量的是**触发器**，以及两件实心的东西（Transfer / Tabs 内容区）。
 * 面板内部的正确性由另外两处覆盖：
 *   · `tools/check-color-util.js`（node，32 条判据）管 ColorUtil 的算法
 *   · `tools/check-fuzzy-match.js` 第 6 段管候选过滤
 *   · 面板的**外壳**是 `Slots.selectOverlay`，它已被 M4/M5 的件覆盖
 *
 * ── 这一屏上七个测点各看什么 ──────────────────────────────────────────
 *   A 五个触发器并排（y 相同、高相同）——
 *     ① 五件的 `implicitHeight` 都该落在 `Theme.size.controlMd` 上，
 *        所以要**顶边对齐、底边对齐**：这一眼就是"尺寸契约真的落地了"。
 *     ② `QSkinColorPicker` 的色块颜色**由 `ColorUtil.hsvToRgb(210, .9, 1)`
 *        算出来**再喂给控件。于是那一格的像素成了端到端证据：
 *        算法 → QML color → 屏幕像素，三段都在这一格里被钉住。
 *        核验脚本用**独立实现**的 HSV→RGB（Python 里另写一遍）算期望值。
 *     ③ 其余四件给的是固定文字/固定键，图里能读出回显文字的位置。
 *
 *   B 两个 `QSkinTabs` 并排，**这是本批最重要的一组对照**：
 *     左：`contentDelegate: null`（M4 的原样）→ 总高 **= tabHeight**
 *     右：`contentDelegate` 非空、`contentHeight: 80`
 *         → 总高 **= tabHeight + contentSpacing + 80**
 *     两条高度差就是"零回归"的像素证据。属性侧只能靠两个布尔说
 *     （`_hasContent` 真/假），而"我到底长高没有"只有像素能回答。
 *
 *   C `QSkinTransfer` 是这一批唯一的实心复合体：两栏 + 中间按钮列。
 *     量：① 两栏**等宽**（都等于 panelWidth）② 栏高 = listHeight
 *         ③ 行高 = rowHeight ④ 栏与控件左右边缘对齐
 *     它**不需要**浮层，所以面板内部（勾选框、行文字、空态）全都能抓到。
 *
 * ── 抓图（这个文件同时是截图入口，图存到 .cache/keep/）────────────────
 *     ./tools/shot.sh examples/showcase/HelloM26.qml theme=tdesign            shot=1
 *     ./tools/shot.sh examples/showcase/HelloM26.qml theme=ant               shot=1
 *     ./tools/shot.sh examples/showcase/HelloM26.qml theme=arco              shot=1
 *     ./tools/shot.sh examples/showcase/HelloM26.qml theme=shadcn            shot=1
 *     ./tools/shot.sh examples/showcase/HelloM26.qml theme=tdesign mode=dark shot=1
 *
 * `out=` 可以改输出目录（**相对本文件**，即相对 `examples/`）：
 *     ./tools/shot.sh examples/showcase/HelloM26.qml theme=tdesign out=../../.cache/ shot=1
 * 变异脚本走这一条 —— 它要重拍，但归档图（`.cache/keep/`）不该被它覆盖。
 *
 * ── 确定性（抓图不能有两帧不一样的东西）──────────────────────────────
 * · 所有浮层都**不开**：AutoComplete 的 `openOnFocus: false`、其余四件
 *   不拿焦点（本屏没有任何控件 `forceActiveFocus`）
 * · `QSkinTransfer` 的勾选态**钉死**在"左栏第一条已勾"（脚本给 `_checkedLeft`）
 *   —— 否则那一格的颜色取决于"运行到那时用户点过什么"
 * · 没有动画：本批七件都没有过渡（Behavior / Animation 一个都没有）
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

    width: 1260
    /* 高度按内容 + 底部自证行留余量。抓图那一帧会打两行
     * `M26-PAGE …` / `M26-GEO …`，正数 overflow 表示底部被切掉 ——
     * 期望值见 `.cache/keep/m26_*.log`，改这一屏之后要重新量。
     * （大改过一版：C 组标题曾压在 B 组内容区上，而 `overflow` 仍然是
     *   负数 —— **「没溢出」不等于「没压」**，重叠必须另立判据。） */
    height: 680
    visible: true
    title: "QSkin · M26 — 树选择 / 级联 / 取色 / 穿梭 / 自动完成 / 提及 / Tabs 内容区"

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
    readonly property bool shotMode:    win.argOf("shot", "") !== ""
    readonly property string outBase:   win.argOf("out", "../../.cache/keep/")

    function applyTheme() {
        Theme.mode = win.mode
        switch (win.themeName) {
            case "ant":    AntDesign.apply();   break
            case "arco":   ArcoDesign.apply();  break
            case "shadcn": Shadcn.apply();      break
            default:       TDesign.apply();     break
        }
    }

    Component.onCompleted: {
        win.applyTheme()
        win._syncPickerFromUtil()
    }

    /* ---------- 页底 ----------
     * `grabToImage(win.contentItem)` **不含** Window 的 `color`，所以自己铺。 */
    Rectangle {
        anchors.fill: parent
        color: Theme.color.bg
    }

    /* ══════════════════════════════════════════════════════════════════
     * 测点几何 —— 核验脚本 `.cache/_verify_m26px.py` 镜像同一组。
     * **改这里就要改那里**：两边不一致时脚本会量到别人家的矩形上。
     * ══════════════════════════════════════════════════════════════════ */

    /* A 五个触发器 */
    readonly property int rowAY: 80
    readonly property int ctlW: 200
    readonly property int ctlH: Theme.size.controlMd
    readonly property var rowAX: [40, 260, 480, 700, 920]

    /* B 两个 Tabs */
    readonly property int rowBY: 170
    readonly property int tabsW: 240
    readonly property int tabsH: Theme.size.controlLg
    readonly property int tabsPadHeight: 80
    readonly property var rowBX: [40, 340]

    /* C Transfer */
    /* `trY` 是**由 B 组算出来的**，不是拍的：B 组内容区的底边
     * = rowBY + tabHeight + contentSpacing + tabsPadHeight = 302，
     * 标题行再往上占 22px。先前写 290（= 标题落在 268）时标题整条
     * **压在内容区卡片上** —— 抓图里看得见。 */
    readonly property int trY: 336
    readonly property int trX: 40
    readonly property int trPanelW: 220
    readonly property int trListH: 220
    readonly property int trRowH: Theme.size.controlMd

    /* ---------- 测点内容（全部钉死，不依赖焦点/时间）---------- */

    readonly property var treeNodes: [
        { id: "zj", label: "浙江", children: [
            { id: "hz", label: "杭州", children: [
                { id: "xh", label: "西湖区", children: [] },
                { id: "yh", label: "余杭区", children: [] }
            ] },
            { id: "nb", label: "宁波", children: [] }
        ] },
        { id: "js", label: "江苏", children: [
            { id: "nj", label: "南京", children: [] },
            { id: "sz", label: "苏州", children: [] }
        ] }
    ]

    readonly property var cats: [
        { id: "zhejiang", label: "浙江", children: [
            { id: "hangzhou", label: "杭州", children: [
                { id: "xihu", label: "西湖区", children: [] }
            ] }
        ] },
        { id: "jiangsu", label: "江苏", children: [
            { id: "nanjing", label: "南京", children: [] }
        ] }
    ]

    readonly property var acOptions: [
        { id: "beijing",  label: "北京" },
        { id: "shanghai", label: "上海" },
        { id: "shenzhen", label: "深圳" }
    ]

    readonly property var mentionOptions: [
        { id: "alice", label: "爱丽丝" },
        { id: "bob",   label: "鲍勃" }
    ]

    /** 取色器这一格的**期望颜色**由 ColorUtil 算出来，不是写死的 hex ——
     *  于是"那一格的像素"就是 ColorUtil 的端到端证据。核验脚本用
     *  **Python 里独立实现**的同一条 HSV→RGB 公式算期望值来比对。 */
    readonly property int pickerH: 210
    readonly property real pickerS: 0.9
    readonly property real pickerV: 1.0

    function _syncPickerFromUtil() {
        var c = ColorUtil.hsvToRgb(win.pickerH, win.pickerS, win.pickerV)
        pickerCtl.value = Qt.rgba(c.r / 255, c.g / 255, c.b / 255, 1)
    }

    /* ══════════════════════════════════════════════════════════════════
     * A —— 五个触发器
     * ══════════════════════════════════════════════════════════════════ */

    Text {
        x: win.rowAX[0]
        y: win.rowAY - 22
        text: "A · 五个触发器（顶边对齐在 y=" + win.rowAY
              + "；前四件高 = controlMd，Mentions 是多行输入、高 = controlLg×2）"
        font.family: Theme.font.family
        font.pixelSize: Theme.font.sm
        color: Theme.color.fgMuted
        renderType: Text.NativeRendering
    }

    QSkinTreeSelect {
        id: treeSel

        x: win.rowAX[0]
        y: win.rowAY
        width: win.ctlW

        nodes: win.treeNodes
        /* `textRole` **必须**给：它的默认值是 `""`，而 `TreeUtil.labelOf`
         * 在 `textRole === ""` 时**刻意**返回 `String(node)` —— 那是为
         * "`nodes` 直接是字符串数组"准备的（`["a","b"]` → `"a"`）。
         * 于是对象节点不写这一行就会渲染成 `[object Object]`（本屏抓到过）。 */
        textRole: "label"
        value: "hz"
        showPath: true
        placeholderText: "选择地区"
        focus: false
    }

    QSkinCascader {
        id: cascSel

        x: win.rowAX[1]
        y: win.rowAY
        width: win.ctlW

        nodes: win.cats
        textRole: "label"          /* 同上：不给会渲染成 `[object Object]` */
        value: ["zhejiang", "hangzhou"]
        placeholderText: "选择地区"
        focus: false
    }

    QSkinColorPicker {
        id: pickerCtl

        x: win.rowAX[2]
        y: win.rowAY
        width: win.ctlW

        showText: true
        focus: false
    }

    QSkinAutoComplete {
        id: acCtl

        x: win.rowAX[3]
        y: win.rowAY
        width: win.ctlW

        options: win.acOptions
        textRole: "label"
        placeholderText: "输入城市"
        openOnFocus: false
        focus: false
    }

    QSkinMentions {
        id: menCtl

        x: win.rowAX[4]
        y: win.rowAY
        width: win.ctlW

        options: win.mentionOptions
        textRole: "label"
        placeholderText: "说点什么"
        focus: false
    }

    /* ══════════════════════════════════════════════════════════════════
     * B —— Tabs 那一组对照（本批最重要的两条高度）
     * ══════════════════════════════════════════════════════════════════ */

    Text {
        x: win.rowBX[0]
        y: win.rowBY - 22
        text: "B · 左：无内容区（总高应 = tabHeight）｜右：有内容区（总高应 = tabHeight + 间距 + 80）"
        font.family: Theme.font.family
        font.pixelSize: Theme.font.sm
        color: Theme.color.fgMuted
        renderType: Text.NativeRendering
    }

    QSkinTabs {
        id: tabsPlain

        x: win.rowBX[0]
        y: win.rowBY
        width: win.tabsW

        model: ["概览", "配置", "日志"]
        currentIndex: 0
        focus: false
        /* contentDelegate 保持默认 null —— 这就是零回归的对照组 */
    }

    QSkinTabs {
        id: tabsWithBody

        x: win.rowBX[1]
        y: win.rowBY
        width: win.tabsW

        model: ["概览", "配置", "日志"]
        currentIndex: 1
        contentHeight: win.tabsPadHeight
        focus: false

        contentDelegate: Component {
            Rectangle {
                id: pane

                /* 鸭子类型 —— 与 `Slots.*` 里那 20 多个 slot 同一写法。
                 * 写成 `property QtObject control` 会被 qmllint 判
                 * `Member "currentIndex" not found on type "QObject"`。 */
                property var control: null

                color: Theme.color.bgSunken
                radius: Theme.radius.md
                border.width: 1
                border.color: Theme.color.divider

                /* 内容里放一行字，好让人一眼看出"这一格真的有东西"。
                 * 子项读 `control` 走**根 id**（`pane.control`）而不是裸名
                 * —— 裸名会被 qmllint 判「非限定访问」。这一处**不必**用
                 * `// qmllint disable`：那是给"读外层 id"准备的，而这里只要
                 * 给同一个组件内的根节点起个 id 就能真的限定住。 */
                Text {
                    anchors.centerIn: parent
                    text: "第 " + (pane.control ? (pane.control.currentIndex + 1) : 0) + " 页 / 共 "
                          + (pane.control ? pane.control.count : 0) + " 页"
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.sm
                    color: Theme.color.fg
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    /* ══════════════════════════════════════════════════════════════════
     * C —— Transfer（本批唯一的实心复合体）
     * ══════════════════════════════════════════════════════════════════ */

    Text {
        x: win.trX
        y: win.trY - 22
        text: "C · 两栏等宽 / 栏高 = listHeight / 行高 = rowHeight；左栏第一条钉死为已勾选"
        font.family: Theme.font.family
        font.pixelSize: Theme.font.sm
        color: Theme.color.fgMuted
        renderType: Text.NativeRendering
    }

    QSkinTransfer {
        id: transfer

        x: win.trX
        y: win.trY

        titles: ["待选", "已选"]
        listHeight: win.trListH
        panelWidth: win.trPanelW
        rowHeight: win.trRowH
        focus: false

        dataSource: [
            { key: "a", label: "条目 A" },
            { key: "b", label: "条目 B" },
            { key: "c", label: "条目 C" },
            { key: "d", label: "条目 D", disabled: true }
        ]
        targetKeys: ["c"]

        /* 勾选态**钉死**：抓图里那一格的底色不该取决于"运行到那时点过什么" */
        _checkedLeft: ["a"]
    }

    /* ══════════════════════════════════════════════════════════════════
     * 自证行 —— 人看图就能核对这一帧的几何，机器也从这里读期望值
     * ══════════════════════════════════════════════════════════════════ */

    Text {
        id: witness

        x: 40
        y: 580
        text: "M26-PAGE theme=" + win.themeName + " mode=" + win.mode
              + " ctlH=" + win.ctlH
              + " heights="
              + Math.round(treeSel.height) + "," + Math.round(cascSel.height) + ","
              + Math.round(pickerCtl.height) + "," + Math.round(acCtl.height) + ","
              + Math.round(menCtl.height)
              /* Mentions 的期望高**不是** `ctlH` —— 它自己声明的是
               * `inputHeight`（= `controlLg * 2`，多行）。把操作数也打出来，
               * 核验脚本才能判"前四件等于 ctlH、第五件等于 inputHeight"，
               * 而不是笼统地判"五个相等"（那是判据写错了）。 */
              + " menInputH=" + menCtl.inputHeight
              /* `overflow` 量的是**最后一个元素**（自证行的下沿），
               * 不是本行自己 —— 下面那行也是内容，先前漏算过它。 */
              + " overflow=" + Math.round((witness2.y + witness2.height) - win.height)
        font.family: Theme.font.family
        font.pixelSize: Theme.font.sm
        color: Theme.color.fg
        renderType: Text.NativeRendering
    }

    /* 第二行自证：把**能被复算的关系**连同它的操作数一起打出来。
     * 只写公式不写数 = 人看图核不了、机器也得去猜哪个是期望值。 */
    Text {
        id: witness2

        x: 40
        y: 604
        text: "M26-GEO tabs=" + win.rowBY + ":" + Math.round(tabsPlain.height)
              + "/" + Math.round(tabsWithBody.height)
              + " gap=" + tabsWithBody.contentSpacing
              + " pad=" + win.tabsPadHeight
              + " | tr=" + Math.round(transfer.y) + ".." + Math.round(transfer.y + transfer.height)
              + " listH=" + win.trListH + " rowH=" + win.trRowH + " panelW=" + win.trPanelW
              /* 回显文字直接进 log：`[object Object]` 这种错**不该只活在像素里**，
               * 它得在日志里就能被判据咬住。 */
              + " | text=[" + treeSel.text + "][" + cascSel.text + "]"
              + " | rgb=" + Math.round(pickerCtl.value.r * 255)
              + "," + Math.round(pickerCtl.value.g * 255)
              + "," + Math.round(pickerCtl.value.b * 255)
        font.family: Theme.font.family
        font.pixelSize: Theme.font.sm
        color: Theme.color.fgMuted
        renderType: Text.NativeRendering
    }

    /* ══════════════════════ 开场与抓图 ══════════════════════ */

    /* 1500ms 与 M17 起的其它屏一致：等淡入与布局收尾。
     * 抓图逻辑住在**示例屏自己**里（`grabToImage(win.contentItem)`），
     * `shot.sh` 只负责把参数递进来、把 log 收走。 */
    Timer {
        interval: 1500
        running: win.shotMode
        onTriggered: {
            /* 两行自证**原样**打进 log —— 不在这里另拼一份。
             * 另拼一份 = 两处独立算路，log 与图会各说各话；
             * 读 `witness.text` 则两者**在构造上**不可能不一致。 */
            console.log(witness.text)
            console.log(witness2.text)
            var base = Qt.resolvedUrl(win.outBase).toString().replace("file:///", "")
            var name = "m26_example_" + win.themeName + "_" + win.mode + ".png"
            win.contentItem.grabToImage(function (res) {
                Qt.exit(res.saveToFile(base + name) ? 0 : 9)
            })
        }
    }
}
