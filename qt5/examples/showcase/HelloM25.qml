/****************************************************************************
 * QSkin · 示例 —— M25：锚点、固钉、回到顶部、页头、命令面板、
 *                     菜单条、导航菜单、侧栏、侧栏行
 *
 * 这一批九件的共同点：**都要一个滚动宿主才会活**（前三件），
 * **或者本身就是浮层/栏架**（其余六件）。所以这一屏的排法是
 * "把滚动状态钉死 + 把每一档摆在一起对照"。
 *
 * ── 九件在这一屏上各看什么 ────────────────────────────────────────────
 *   A  `QSkinAnchor`      竖轨贴左边缘，**活动记号跟着 `currentIndex` 走**
 *       （= 跟滚动位置走，不跟 hover）。这里把 `contentY` 钉在 450，
 *       `offsets` 是 [0,200,400,600,800] → 记号落在第 3 段（下标 2），
 *       于是记号的顶边 = `rowTop(2)` = 60。
 *       看「三」那一行左边的蓝条 —— 它与那一行**对齐**是这一件唯一的承诺。
 *   B  `QSkinAffix` ×2    **左：`holderHeight > 内容高`**（钉在线上，内容顶边
 *       落在视口顶边）；**右：`holderHeight < 内容高`**（被占位块的底边顶出去，
 *       内容只露出下半截）。两块的橙色条目**可见高度不同**（30 vs 15）——
 *       这一眼就是"钉住 / 顶出"两种结局，属性侧只能靠两个布尔说。
 *   C  `QSkinBackTop` ×3  左：静息（浮层底 + 描边）；中：`hovered`
 *       （brandSubtle + brand 描边）；右：**没到阈值 → 一点墨都没有**。
 *       第三枚是这一组的对照：它的 40×40 里必须找不出任何非页底的像素。
 *   D  `QSkinCommand`     面板高 = `padding*2 + inputHeight + 1 + headingHeight
 *       + 条目数*rowHeight`，输入下面那条通栏分隔线。改任何一档字号，
 *       整块高度都会对不上（核验脚本按令牌算这个和）。
 *   E  `QSkinPageHeader`  分隔线在块的**最下沿**、通栏、颜色是 divider。
 *   F  `QSkinSidebar` ×3  三档并排：`sidebar`（bgSubtle + 内边缘线）、
 *       `floating`（bgElevated + 圆角 + 四周描边 + 外留白）、
 *       `inset`（bgElevated + 方角 + 内边缘线）。三种"与外界分界"的做法。
 *   G  `QSkinMenubar` / `QSkinNavigationMenu`  都**关着**（弹出层是独立窗口，
 *       抓画布抓不到 —— 与 M24 的 Popup 同一条）。所以这一组量的是
 *       "条高对不对"（文字墨的竖直中心 = barHeight/2）与
 *       **"没焦点时环不出墨"**（`border.width` 为 0）。
 *   H  `QSkinSidebarItem` ×5  五档状态：idle / active / active+hover /
 *       hover / press。active 是 brandSubtle、hover 与 press 是 bgSunken ——
 *       后两者同色是**刻意的**（"我是这一页"与"鼠标在这"必须能同时被看懂）。
 *
 * ── 为什么 F 的三档要摆在 `bgSunken` 卡片上 ────────────────────────────
 * 亮色下 arco / shadcn 的 `bgElevated` **等于**页底 `bg`（都纯白）。
 * 摆在页面上时 `floating` / `inset` 两档的"面"整个消失，
 * "圆角在哪、描边在哪"就无从量起。卡片底换成 `bgSunken` 之后，
 * 四家的 `dist(bgElevated, bgSunken)` 是 11~24 阶，都分得开。
 * 这与 M24 把二维码摆在 `bgSunken` 卡片上是同一条理由。
 *
 * ── H 那五行为什么留在**页底**而不是卡片上 ──────────────────────────────
 * 与 F 正好相反：`hovered` / `pressed` 两档是 `bgSunken`。
 * 摆在 `bgSunken` 卡片上，那两档同样"消失"。所以两处用两种底，
 * 各自让**被测的那一档**与它的底有差。
 *
 * ── 抓图（这个文件同时是截图入口，图存到 .cache/keep/）────────────────
 *     ./tools/shot.sh examples/showcase/HelloM25.qml theme=tdesign            shot=1
 *     ./tools/shot.sh examples/showcase/HelloM25.qml theme=ant               shot=1
 *     ./tools/shot.sh examples/showcase/HelloM25.qml theme=arco              shot=1
 *     ./tools/shot.sh examples/showcase/HelloM25.qml theme=shadcn            shot=1
 *     ./tools/shot.sh examples/showcase/HelloM25.qml theme=tdesign mode=dark shot=1
 *
 * `out=` 可以改输出目录（**相对本文件**，即相对 `examples/`）：
 *     ./tools/shot.sh examples/showcase/HelloM25.qml theme=tdesign out=../../.cache/ shot=1
 * 变异脚本走这一条 —— 它要重拍，但归档图（`.cache/keep/`）不该被它覆盖。
 *
 * 本批**没有**会自己动的东西（`animated: false` 关掉了侧栏与回顶的过渡，
 * 滚动状态是声明期常量），所以"抓到的就是终态"是结构上成立的。
 *
 * ── 本环境实测结论（沿用 M16~M24，别再踩）──────────────────────────────
 * ① 根节点必须是 Window（见 QSkinWindow）。Item 作根节点事件循环起不来。
 * ② 抓图用 `Item.grabToImage`，不要用 `Window.grabWindow`（返回空图且静默）。
 * ③ 抓 `win.contentItem`；未设 parent 的 `Popup` 会被挂到 `Overlay.overlay`，
 *    抓画布等于把它丢掉 —— 本屏的弹出层一律**不开**，所以不受这条影响。
 * ④ 抓图要自己铺底（`grabToImage` **不含** Window 的 `color`）。用 `Theme.color.bg`。
 * ⑤ `grabToImage` 带 `devicePixelRatio`：本机 DPR=1.5，1280 宽的窗口抓到的是
 *    1920×1800。核验脚本按比例换算，别按 1:1 读。
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0
import QSkin.Theme.AntDesign 1.0
import QSkin.Theme.ArcoDesign 1.0
import QSkin.Theme.Shadcn 1.0

QSkinWindow {
    id: win

    width: 1280
    /* 高度按底部的自证行放出余量。抓图那一帧会打一行 `M25-PAGE … overflow=…`，
     * 正数表示底部被切掉 —— 实测值见 `.cache/m25_*.log`，
     * 改这一屏的内容之后要重新量。 */
    height: 1240
    visible: true
    title: "QSkin · M25 — 锚点 / 固钉 / 回顶 / 页头 / 命令 / 菜单条 / 导航 / 侧栏"

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

    /* 抓图落到哪个目录。默认 `.cache/keep/` —— 归档件就在那儿。
     * 变异脚本（`.cache/mutate_m25px.py`）会传 `out=../../.cache/`：它**要重拍**，
     * 但绝不该把归档图覆盖掉。路径按 `Qt.resolvedUrl` 解析，即**相对本文件
     * 所在目录**（`examples/`），所以是 `../../.cache/` 而不是 `.cache/`。 */
    readonly property string outBase: win.argOf("out", "../../.cache/keep/")

    function applyTheme() {
        Theme.mode = win.mode
        switch (win.themeName) {
            case "ant":    AntDesign.apply();   break
            case "arco":   ArcoDesign.apply();  break
            case "shadcn": Shadcn.apply();      break
            default:       TDesign.apply();     break
        }
    }

    /* ---------- 页底 ----------
     * `grabToImage(win.contentItem)` **不含** Window 的 `color`，所以自己铺。 */
    Rectangle {
        anchors.fill: parent
        color: Theme.color.bg
    }

    /* ══════════════════════════════════════════════════════════════════
     * 测点几何 —— 核验脚本 `.cache/_verify_m25px.py` 镜像同一组。
     * **改这里就要改那里**：两边不一致时脚本会量到别人家的矩形上。
     * ══════════════════════════════════════════════════════════════════ */

    /* A 锚点 */
    readonly property int ancX: 40
    readonly property int ancY: 70
    readonly property int ancW: 180
    readonly property int ancItemH: 30
    readonly property int ancSpacing: 0
    readonly property int ancInkW: 4
    readonly property int ancScrollY: 450
    readonly property var ancOffsets: [0, 200, 400, 600, 800]

    /* B 固钉（两例） */
    readonly property int affAX: 250
    readonly property int affAY: 70
    readonly property int affAW: 200
    readonly property int affAH: 110
    readonly property int affAItemY: 100
    readonly property int affAHolder: 60
    readonly property int affAScroll: 120

    readonly property int affBX: 470
    readonly property int affBBHolder: 20
    readonly property int affBScroll: 105

    readonly property int affItemH: 30          /* 内容高（那条橙色条目） */
    readonly property int affSticky: 0

    /* C 回到顶部 */
    readonly property int btY: 70
    readonly property int btD: 40
    readonly property var btX: [700, 770, 880]
    readonly property int btHigh: 500
    readonly property int btLow: 0
    readonly property int btThreshold: 400

    /* D 命令面板 */
    readonly property int cmdX: 540
    readonly property int cmdY: 250
    readonly property int cmdW: 420
    readonly property var cmdModel: [
        { heading: "建议", items: [{ text: "新建文件" }, { text: "打开设置" }] }
    ]

    /* E 页头 */
    readonly property int phX: 40
    readonly property int phY: 250
    readonly property int phW: 460

    /* F 侧栏三档 */
    readonly property int cardX: 40
    readonly property int cardY: 450
    readonly property int cardW: 800
    readonly property int cardH: 250
    readonly property int sbY: 466
    readonly property int sbW: 240
    readonly property int sbH: 218
    readonly property var sbX: [56, 312, 568]

    /* G 菜单条 / 导航菜单 */
    readonly property int mbX: 880
    readonly property int mbY: 450
    readonly property int mbW: 260
    readonly property int navX: 880
    readonly property int navY: 520
    readonly property int navW: 260

    /* H 侧栏行五档 */
    readonly property int sbiX: 40
    readonly property int sbiW: 200
    readonly property int sbiH: 40
    readonly property var sbiY: [720, 770, 820, 870, 920]

    /* 色块基准行 + 自证行 */
    readonly property int swX: 40
    readonly property int swY: 990
    readonly property int swSize: 24
    readonly property int swGap: 4
    readonly property var swKeys: [ "bg", "bgElevated", "bgSubtle", "bgSunken",
                                    "border", "divider", "brand", "brandSubtle",
                                    "focus", "fg", "fgSecondary" ]
    readonly property int noteX: 40
    readonly property int noteY: 1030

    /* ══════════════════════════════════════════════════════════════════
     * 滚动宿主（**声明的一部分，不是布局的一部分**）
     * ══════════════════════════════════════════════════════════════════
     * 前三件都是"吃一个 target: Flickable"的设计（裁决二：滚动宿主是输入，
     * 控件自己不造滚动）。所以这一屏必须**真的**有 Flickable ——
     * 假对象（只有一个 contentY 属性的 QtObject）在本批行不通：
     * `QSkinAffix` 要 `mapToItem(target.contentItem)`，那需要真的内容项。 */

    /* 只为 A / C 提供滚动状态的两只：它们自己没有可见内容，
     * 摆在右上角（不放任何东西，所以不出墨）。 */
    Flickable {
        id: flA

        x: 1190
        y: 1180
        width: 10
        height: 10
        contentWidth: 10
        contentHeight: 2000
        contentY: win.ancScrollY
    }

    Flickable {
        id: flHigh

        x: 1200
        y: 1180
        width: 10
        height: 10
        contentWidth: 10
        contentHeight: 2000
        contentY: win.btHigh
    }

    Flickable {
        id: flLow

        x: 1210
        y: 1180
        width: 10
        height: 10
        contentWidth: 10
        contentHeight: 2000
        contentY: win.btLow
    }

    /* ── A 锚点 ── */
    QSkinAnchor {
        id: anc

        x: win.ancX
        y: win.ancY
        width: win.ancW
        itemHeight: win.ancItemH
        spacing: win.ancSpacing
        inkWidth: win.ancInkW
        anchorOffset: 0
        target: flA
        offsets: win.ancOffsets
        model: ["一、起步", "二、安装", "三、配置", "四、部署", "五、进阶"]
    }

    /* ── B 固钉（钉住）── */
    Flickable {
        id: flAffA

        x: win.affAX
        y: win.affAY
        width: win.affAW
        height: win.affAH
        contentWidth: win.affAW
        contentHeight: 400
        contentY: win.affAScroll
        clip: true

        QSkinColumn {
            width: win.affAW
            /* `gap: 0` —— 让"固钉件在**内容坐标**里的顶边"恰好等于前导空白的
             * 高度（`affAItemY`）。缺省 gap 是 `Theme.space.sm`（8），会把顶边
             * 顶到 108，而核验脚本镜像的是 100 —— 差的正是这 8px
             * （M22~M24 同款纪律：镜像常量改一处等于没改）。 */
            gap: 0

            /* 前导空白：它的高度就是固钉件在**内容坐标**里的顶边。
             * ⚠ 必须走 `Layout.preferredHeight` —— `QSkinColumn` 内部是
             *   ColumnLayout，它按 `implicitHeight` 排子项；一个裸 `Item`
             *   的 implicitHeight 是 0，直写 `height: 100` 会被布局**静默忽略**
             *   （`QSkinRow.qml` 文件头记着同一条，M2 的 Spacer 就是这么丢的）。 */
            Item {
                Layout.preferredWidth: win.affAW
                Layout.preferredHeight: win.affAItemY
            }

            QSkinAffix {
                id: affA

                width: win.affAW
                /* ⚠ **不设 `target` 的话本件会静默退化成普通块**：
                 * `reached` 恒 false、`_deltaY` 恒 0 —— 钉住/顶出两种结局
                 * 一个都不发生，而两例的橙色条会落在**同一个位置**上。
                 * 图上看着"有东西"，其实这一组什么都没测到。
                 * M25 抓图首轮就是这么栽的：自证行印着两例都是
                 * `viewportY=108 delta=0 pinned=false`。 */
                target: flAffA
                holderHeight: win.affAHolder
                stickyTop: win.affSticky
                spacing: 0

                Rectangle {
                    width: win.affAW
                    height: win.affItemH
                    color: "#FF7A00"
                }
            }
        }
    }

    /* ── B 固钉（被顶出）── */
    Flickable {
        id: flAffB

        x: win.affBX
        y: win.affAY
        width: win.affAW
        height: win.affAH
        contentWidth: win.affAW
        contentHeight: 400
        contentY: win.affBScroll
        clip: true

        QSkinColumn {
            width: win.affAW
            /* 同上：`gap: 0` 让顶边落在 `affAItemY`（两例共用同一个前导高度，
             * 这样"可见高度不同"只由 `holderHeight` 造成）*/
            gap: 0

            /* 同上：这一格的高度必须走 `Layout.preferredHeight` */
            Item {
                Layout.preferredWidth: win.affAW
                Layout.preferredHeight: win.affAItemY
            }

            QSkinAffix {
                id: affB

                width: win.affAW
                /* 同上：`target` 不设则本件退化成普通块（见 affA 那段注释） */
                target: flAffB
                holderHeight: win.affBBHolder
                stickyTop: win.affSticky
                spacing: 0

                Rectangle {
                    width: win.affAW
                    height: win.affItemH
                    color: "#FF7A00"
                }
            }
        }
    }

    /* ── C 回到顶部 ×3 ── */
    QSkinBackTop {
        id: btIdle

        x: win.btX[0]
        y: win.btY
        diameter: win.btD
        target: flHigh
        threshold: win.btThreshold
        animated: false
    }

    QSkinBackTop {
        id: btHot

        x: win.btX[1]
        y: win.btY
        diameter: win.btD
        target: flHigh
        threshold: win.btThreshold
        animated: false
        hovered: true
    }

    QSkinBackTop {
        id: btHidden

        x: win.btX[2]
        y: win.btY
        diameter: win.btD
        target: flLow
        threshold: win.btThreshold
        animated: false
    }

    /* ── D 命令面板 ── */
    QSkinCommand {
        id: cmd

        x: win.cmdX
        y: win.cmdY
        width: win.cmdW
        model: win.cmdModel
    }

    /* ── E 页头 ── */
    QSkinPageHeader {
        id: ph

        x: win.phX
        y: win.phY
        width: win.phW
        title: "组件总览"
        subtitle: "锚点 / 固钉 / 回到顶部"
        showBack: true
    }

    /* ── F 侧栏三档（摆在 bgSunken 卡片上，理由见文件头）── */
    Rectangle {
        id: card

        x: win.cardX
        y: win.cardY
        width: win.cardW
        height: win.cardH
        color: Theme.color.bgSunken
    }

    QSkinSidebar {
        id: sbSide

        x: win.sbX[0]
        y: win.sbY
        width: win.sbW
        height: win.sbH
        animated: false
        model: [{ header: "分组" }, { text: "首页" }, { text: "设置" }]
    }

    QSkinSidebar {
        id: sbFloat

        x: win.sbX[1]
        y: win.sbY
        width: win.sbW
        height: win.sbH
        animated: false
        variant: "floating"
        model: [{ header: "分组" }, { text: "首页" }, { text: "设置" }]
    }

    QSkinSidebar {
        id: sbInset

        x: win.sbX[2]
        y: win.sbY
        width: win.sbW
        height: win.sbH
        animated: false
        variant: "inset"
        model: [{ header: "分组" }, { text: "首页" }, { text: "设置" }]
    }

    /* ── G 菜单条 / 导航菜单（都关着，理由见文件头）── */
    QSkinMenubar {
        id: mb

        x: win.mbX
        y: win.mbY
        width: win.mbW
        model: [{ text: "文件", items: ["新建", "打开"] },
                { text: "编辑", items: ["撤销"] }]
    }

    QSkinNavigationMenu {
        id: nav

        x: win.navX
        y: win.navY
        width: win.navW
        model: [{ text: "产品" }, { text: "文档" }, { text: "定价" }]
    }

    /* ── H 侧栏行五档 ── */
    QSkinSidebarItem {
        id: sbiIdle

        x: win.sbiX
        y: win.sbiY[0]
        width: win.sbiW
        height: win.sbiH
        text: "首页"
    }

    QSkinSidebarItem {
        id: sbiActive

        x: win.sbiX
        y: win.sbiY[1]
        width: win.sbiW
        height: win.sbiH
        text: "首页"
        active: true
    }

    QSkinSidebarItem {
        id: sbiActiveHot

        x: win.sbiX
        y: win.sbiY[2]
        width: win.sbiW
        height: win.sbiH
        text: "首页"
        active: true
        hovered: true
    }

    QSkinSidebarItem {
        id: sbiHover

        x: win.sbiX
        y: win.sbiY[3]
        width: win.sbiW
        height: win.sbiH
        text: "首页"
        hovered: true
    }

    QSkinSidebarItem {
        id: sbiPress

        x: win.sbiX
        y: win.sbiY[4]
        width: win.sbiW
        height: win.sbiH
        text: "首页"
        pressed: true
    }

    /* 五档的说明（**离被测矩形足够远**：x=260 起，行宽 200 到此为止） */
    QSkinColumn {
        x: 260
        y: win.sbiY[0] + 4
        gap: 46

        Caption { text: "idle（无底色）" }
        Caption { text: "active（brandSubtle）" }
        Caption { text: "active + hovered（活动态赢）" }
        Caption { text: "hovered（bgSunken）" }
        Caption { text: "pressed（bgSunken）" }
    }

    /* ── 色块基准行（核验脚本的参照系）── */
    QSkinRow {
        id: swatches

        x: win.swX
        y: win.swY
        gap: win.swGap

        Repeater {
            model: win.swKeys

            /* 代理里要引用外层的 `win` —— qmllint 把嵌套组件里的外层 id
             * 访问一律判为「非限定访问」（它建议 `pragma ComponentBehavior: Bound`，
             * 而那会改变整个文件的 id 解析语义，本仓不用）。与 QSkinMenubar /
             * QSkinAnchor 的代理同一处置：局部关掉。 */
            // qmllint disable unqualified
            delegate: Rectangle {
                required property string modelData

                /* 尺寸用 `width`/`height` —— 与 M24 那一屏同一写法。 */
                width: win.swSize
                height: win.swSize
                color: win.tokenColor(modelData)
            }
            // qmllint enable unqualified
        }
    }

    /** 令牌名 → 颜色。`Theme.color` 是 `property var`（一个可被整体替换的
     *  JS 对象），所以 qmllint 拿不到成员表 —— 只能这样按名字取。 */
    function tokenColor(key) {
        return Theme.color[key]
    }

    /* ══════════════════════ 自证行 ══════════════════════
     * 读数直接印在图上：人看图就能核对，不必信任脚本。
     * 脚本读不了文字，所以这些数是**给人**看的；脚本要断言的量一律
     * 从像素上量（不然就成了"用属性证明属性"）。 */
    QSkinColumn {
        id: notes

        x: win.noteX
        y: win.noteY
        width: 1200
        gap: 2

        Caption {
            Layout.fillWidth: true
            text: "theme=" + win.themeName + "  mode=" + win.mode
                  + "    基准行色块 = " + win.swKeys.join(" / ")
        }

        Caption {
            Layout.fillWidth: true
            text: "anchor: scrollY=" + win.ancScrollY + " offsets=" + win.ancOffsets.join(",")
                  + "  currentIndex=" + anc.currentIndex
                  + "  rowTop(idx)=" + anc.rowTop(anc.currentIndex)
                  + "  itemHeight=" + anc.itemHeight + " inkWidth=" + anc.inkWidth
                  + "  [期望] 记号 y = " + (win.ancY + anc.rowTop(anc.currentIndex))
                  + ".." + (win.ancY + anc.rowTop(anc.currentIndex) + anc.itemHeight)
        }

        Caption {
            Layout.fillWidth: true
            text: "affix A: itemY=" + win.affAItemY + " holder=" + win.affAHolder
                  + " itemH=" + win.affItemH + " scrollY=" + win.affAScroll
                  + " → viewportY=" + Math.round(affA._viewportY)
                  + " delta=" + Math.round(affA._deltaY)
                  + " drawY=" + Math.round(affA._viewportY + affA._deltaY)
                  + " pinned=" + affA.pinned + " pushedOut=" + affA.pushedOut
                  + "     affix B: holder=" + win.affBBHolder
                  + " scrollY=" + win.affBScroll
                  + " → viewportY=" + Math.round(affB._viewportY)
                  + " delta=" + Math.round(affB._deltaY)
                  + " drawY=" + Math.round(affB._viewportY + affB._deltaY)
                  + " pinned=" + affB.pinned + " pushedOut=" + affB.pushedOut
        }

        Caption {
            Layout.fillWidth: true
            text: "backtop: diameter=" + win.btD + " threshold=" + win.btThreshold
                  + "  scrollY(high)=" + win.btHigh + " scrollY(low)=" + win.btLow
                  + "  showing=" + btIdle.showing + "/" + btHot.showing + "/" + btHidden.showing
                  + "（第三枚必须为 false → 一点墨都不该有）"
        }

        Caption {
            Layout.fillWidth: true
            text: "command: panelWidth=" + cmd.width + "  padding=" + cmd.padding
                  + " inputHeight=" + cmd.inputHeight + " headingHeight=" + cmd.headingHeight
                  + " rowHeight=" + cmd.rowHeight + " 条目数=" + cmd.matchCount
                  + "  [期望] 面板高 = " + (cmd.padding * 2 + cmd.inputHeight + 1
                                            + cmd.headingHeight + cmd.matchCount * cmd.rowHeight)
                  + "  分隔线 y = " + (win.cmdY + cmd.padding + cmd.inputHeight)
                  + " 宽 = " + (cmd.width - cmd.padding * 2)
        }

        Caption {
            Layout.fillWidth: true
            text: "pageHeader: implicitHeight=" + Math.round(ph.implicitHeight)
                  + "  padding=" + ph.padding + "  分隔线 y = "
                  + (win.phY + Math.round(ph.implicitHeight) - 1)
                  + "     sidebar: 宽=" + sbSide.currentWidth + "/" + sbFloat.currentWidth
                  + "/" + sbInset.currentWidth
                  + "  margin=" + sbSide._margin + "/" + sbFloat._margin + "/" + sbInset._margin
                  + "  radius=" + sbSide._radius + "/" + sbFloat._radius + "/" + sbInset._radius
        }

        Caption {
            Layout.fillWidth: true
            text: "menubar: barHeight=" + mb.barHeight + " itemHeight=" + mb.itemHeight
                  + " padding=" + mb.padding
                  + "     navMenu: barHeight=" + nav.barHeight + " itemHeight=" + nav.itemHeight
                  + " padding=" + nav.padding
                  + "     sidebarItem: itemHeight=" + sbiActive.itemHeight
                  + " radius=" + sbiActive.radius + " iconOnly=" + sbiActive.iconOnly
        }
    }

    /* ══════════════════════ 开场与抓图 ══════════════════════ */

    Component.onCompleted: win.applyTheme()

    /* 1500ms 与 M17 起的其它屏一致：等淡入与布局收尾。 */
    Timer {
        interval: 1500
        running: win.shotMode
        onTriggered: {
            /* 抓图那一帧核对「整页装下了没有」。溢出为正 = 底部被切掉，
             * 而那在图上只看得出"少了一块"。 */
            console.log("M25-PAGE theme=" + win.themeName + " mode=" + win.mode
                        + " page=" + Math.round(win.height)
                        + " noteBottom=" + Math.round(notes.y + notes.implicitHeight)
                        + " overflow=" + Math.round(notes.y + notes.implicitHeight - win.height))
            var base = Qt.resolvedUrl(win.outBase).toString().replace("file:///", "")
            var name = "m25_example_" + win.themeName + "_" + win.mode + ".png"
            win.contentItem.grabToImage(function (res) {
                Qt.exit(res.saveToFile(base + name) ? 0 : 9)
            })
        }
    }
}
