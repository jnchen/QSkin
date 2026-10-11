/****************************************************************************
 * QSkin · 示例 —— M27：键帽、水印、瀑布流、按钮组、悬浮球、上传
 *
 * 这一批六件的共同点：**五件的正确性几乎全是几何**，只有 Upload 带状态。
 * 所以这一屏量的是"画出来的几何"，而不是"看起来像不像"。
 *
 * ── 这一屏上六组测点各看什么 ──────────────────────────────────────────
 *   A `QSkinKbd` ×4 —— 键帽个数 / 键间缝 / **两段色**（键面 + 底座厚度）。
 *     ① 每枚键由两个同宽矩形叠成：底座高 = keyHeight（borderStrong），
 *        键面高 = keyHeight - thickness（bgSubtle + 1px 描边）。
 *        于是"厚度有没有画出来"这件事在像素上是一条**两段色**的竖切面：
 *        同一列上，上面是键面色、最下面 thickness 行是底座色。
 *        属性侧只能读到 `height: 20`，读不出"下面那 2 行是另一个色"。
 *     ② `thickness: 0` 的第 4 枚**不该有底座色** —— 没有这条对照，
 *        上面那条判据可以被"整枚都刷成底座色"满足。
 *     ③ 键与键之间的缝 = keyGap，从像素上量 = 6 设备像素。
 *
 *   B `QSkinWatermark` ×4 —— 全是几何：步长 / 偏移 / 倾角 / 裁剪。
 *     四个盒子只有**一个变量**在动，两两成对照：
 *       wm0     rotate 0   offset(0,0)   ← 基准：格子间距 = gapX / gapY
 *       wm30    rotate -30 offset(0,0)   ← 只动倾角
 *       wmOff   rotate -30 offset(30,20) ← 只动偏移
 *       wmCover rotate 0 + 整幅内容色     ← 只问"盖不盖得住内容"
 *     于是：
 *       ① 格距：wm0 的"可见格点"对应的墨团重心，横/纵间距 == gapX/gapY
 *       ② 倾角：旋转**不改重心**（绕自身中心转）、只改外框 —— 用 wm0 实测到的
 *          (w,h) 按旋转公式**算出** wm30 该是多少，与实测比（自校准）
 *       ③ 偏移：wmOff 的重心 == wm0 的重心 + (30,20)，逐团比
 *          （用 wm0 而不是 wm30 当基准，是因为**重心本来就不受旋转影响**，
 *            而 wm0 与 wmOff 都是"无内容"的干净底 —— 判墨基准不会换）
 *       ④ 裁切：四个盒子外面一条带里都不该有墨
 *       ⑤ 盖在内容之上：wmCover 里存在"偏离内容色"的像素。
 *          属性侧说不出这件事（它只说 visible）。
 *
 *   C `QSkinMasonry` —— 布局算法的**像素证据**。
 *     核验脚本用 Python **独立实现**一遍贪心（不是读控件的 layoutResult），
 *     算出每项该在哪个矩形，再与图上每个矩形比。属性侧那套断言在冒烟测试里
 *     （`tests/smoke_m27.qml [4]`），这里管的是"算对了有没有画对"。
 *
 *   D `QSkinButtonGroup` ×3 —— 三态圆角。这是本批**最需要像素**的一件：
 *     同一组里相邻两枚按钮底色相同、紧邻，于是"中间那枚的角是方的"这件事
 *     只能从**轮廓**上读出来。三个组三种测法：
 *       grp0  4 枚、`spacing: 0`（常态）：整组是一个连通块 →
 *             轮廓说明"外两角被切、缝上没有缺口"
 *       grp4  3 枚、`spacing: 4`：每枚各自成一个块 →
 *             **逐枚逐角**判（4×4 个角，正好穷举 first/middle/last 三态）
 *       grp1  1 枚：`standalone`，四角全圆（与"首尾合一"的怪态区分开）
 *     ⚠ 为什么给 grp4 加间距：`QSkinButtonGroup` 文件头写了"spacing 写成属性
 *       而不是常量，是为了方便探针把它设成非 0 来确认分组语义不依赖间距"。
 *       这里正是那个用法 —— 不是绕过契约，是契约里留的口子。
 *
 *   E `QSkinFloatButton` ×4 —— 圆 / 直径 / 三态 / 角标。
 *     ① 圆不是方：外接框**四角无墨**（方角在像素上是立刻可见的）
 *     ② 直径 = `plateDiameter`；悬停态另量**填充圆**（内缩 1px 描边）
 *     ③ 三态各有自己的色：静息 `bgElevated`、悬停 `brandSubtle`+`brand` 环、
 *        禁用 `bgSubtle` —— 在**圆心那一格**读，与令牌比。
 *        ⚠ `bgElevated` 在 arco / shadcn 亮色下与 `bg` **完全相同**（实测距离
 *          0.0），所以静息球只有描边环可见 —— 这不是缺陷，是那两家的设计。
 *     ④ 角标：与**没有角标**的那枚比，同一个窗口里多出来的墨就是它
 *        （差分量，不需要知道角标是什么色、多大）。
 *
 *   F `QSkinUpload` —— 这一批唯一带状态的。
 *     ① 触发区：盒子 = contentWidth × triggerHeight、四角按 radius.lg 切
 *     ② **虚线**：顶边沿行数"墨的段数" ≥ 4（实线只有 1 段）——
 *        这是"DashLine 真的生效了"的唯一证据（属性侧 `strokeStyle` 只是个枚举）
 *     ③ 三根进度条的**填充宽之比** == 进度值之比（0.25 : 0.75 : 1）
 *        → 状态 → 几何的端到端，且只有比值、不含任何绝对常量
 *     ④ 三根条的 y 间距 == rowHeight + rowGap（= 52）→ 行高契约
 *
 * ── 抓不到的东西先说清楚 ──────────────────────────────────────────────
 * 本批**没有浮层**，六件都能抓到。唯一抓不到的是 `QSkinTooltip`（`Popup`，
 * 独立窗口）—— 所以浮球的 `tip` 在这一屏上只做"不创建"那一条的旁证：
 * 第 1 枚不给 tip，画面与给了 tip 的第 2 枚**不该有差别**。
 *
 * ── 确定性（抓图不能有两帧不一样的东西）──────────────────────────────
 * · `spinning: false` —— 上传中的状态记号默认**转**，旋转是时间的函数。
 * · 进度条宽度带 `Behavior`（`BasicProgressTrack` 第 104 行）：示例在
 *   `Component.onCompleted` 里播种状态，动画从那一刻起跑，1500ms 后抓图时
 *   早已收敛。**这条是抓图时刻的约束，改小 `interval` 会拍到中间帧。**
 * · 悬停态用**属性钉**（`hovered: true`）而不是等鼠标：M25 起的既有做法。
 *   自证行把三枚球的 `hovered` 都打出来 —— 真鼠标若污染了别的球，
 *   日志里看得见，核验脚本也会因为"两枚球同时是品牌环"而红。
 * · 没有任何控件 `forceActiveFocus`；`QSkinButtonGroup` / `Masonry` 不吃焦点。
 *
 * ── 测点几何（核验脚本 `.cache/_verify_m27px.py` 镜像同一组）──────────
 * **改这里就要改那里**：两边不一致时脚本会量到别人家的矩形上。
 * 下面每个 `readonly property` 都是给那个镜像用的。
 *
 * ── 抓图（这个文件同时是截图入口，图存到 .cache/keep/）────────────────
 *     ./tools/shot.sh examples/showcase/HelloM27.qml theme=tdesign            shot=1
 *     ./tools/shot.sh examples/showcase/HelloM27.qml theme=ant               shot=1
 *     ./tools/shot.sh examples/showcase/HelloM27.qml theme=arco              shot=1
 *     ./tools/shot.sh examples/showcase/HelloM27.qml theme=shadcn            shot=1
 *     ./tools/shot.sh examples/showcase/HelloM27.qml theme=tdesign mode=dark shot=1
 *
 * `out=` 可以改输出目录（**相对本文件**），变异脚本走这一条：
 *     ./tools/shot.sh examples/showcase/HelloM27.qml theme=tdesign out=../../.cache/ shot=1
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
    height: 720
    visible: true
    title: "QSkin · M27 — 键帽 / 水印 / 瀑布流 / 按钮组 / 悬浮球 / 上传"

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
        win.seedUpload()
    }

    /* ---------- 页底 ----------
     * `grabToImage(win.contentItem)` **不含** Window 的 `color`，所以自己铺。 */
    Rectangle {
        anchors.fill: parent
        color: Theme.color.bg
    }

    /* ══════════════════════════════════════════════════════════════════
     * 测点几何 —— 核验脚本镜像同一组
     * ══════════════════════════════════════════════════════════════════ */

    /* A 键帽 */
    readonly property int rowAY: 80
    readonly property var kbdX: [40, 130, 250, 420]

    /* B 水印：四个盒子只有一处变量不同 */
    readonly property int rowBY: 170
    readonly property var wmX: [40, 200, 360, 520]
    readonly property int wmW: 150
    readonly property int wmH: 140
    /* 步长取 50/50 是**为了让判据站得住**，不是审美：
     * 墨团（"QSkin"三个字符聚成一团）实测外框 26.7×20 逻辑像素，
     * 旋转后 33×30 —— 步长 50 时"可见格点"在 150×140 里恰好排成 3×3，
     * 横向/纵向各有两段间距可量。步长再大就会只剩 2×2（只有一段间距）。 */
    readonly property int wmGapX: 50
    readonly property int wmGapY: 50

    /* C 瀑布流 */
    readonly property int rowCY: 350
    readonly property int maX: 40
    readonly property int maW: 580
    readonly property int maCols: 3
    readonly property var maHeights: [90, 60, 120, 70, 50, 100, 80]

    /* D 按钮组 */
    readonly property int rowDY: 80
    readonly property var grpX: [680, 920, 1120]

    /* E 悬浮球 */
    readonly property int rowEY: 180
    /* 五枚，第 5 枚是 `fbTip`（声明了 `tip` 但不悬浮 = 提示一直关着）。
     * 坐标必须给足 —— 少一个值 `win.fbX[4]` 就是 `undefined`，`x` 得到 NaN。 */
    readonly property var fbX: [680, 770, 860, 950, 1040]
    readonly property int fbDia: 48

    /* F 上传 */
    readonly property int rowFY: 290
    readonly property int upX: 680
    readonly property int upW: 420
    readonly property int upTriggerH: 56
    readonly property var upProgress: [0.25, 0.75, 1.0, 0.0]

    /* ══════════════════════════════════════════════════════════════════
     * 组标题
     *
     * 用 `Foundation/Caption`（12px、`tone` 决定色）—— 不自己声明
     * inline component：那个名字在 `QSkin.Foundation` 里已经有了，
     * 再声明一份就是两个同名类型互相遮（`QSkinButtonGroup` 文件头记过
     * Foundation 的 `Row` 把 QtQuick 的 `Row` 遮住那一课）。
     * ══════════════════════════════════════════════════════════════════ */

    Caption {
        x: win.kbdX[0]
        y: win.rowAY - 22
        tone: "muted"
        text: "A · 键帽：个数 / 缝 4 / 两段色（键面 + 底座厚度）；第 4 枚 thickness:0"
    }

    Caption {
        x: win.wmX[0]
        y: win.rowBY - 22
        tone: "muted"
        text: "B · 水印：①倾角0 ②倾角-30 ③倾角-30+偏移(30,20) ④满幅内容（看「盖在内容之上」）"
    }

    Caption {
        x: win.maX
        y: win.rowCY - 22
        tone: "muted"
        text: "C · 瀑布流：3 列 / 列宽 = (580-2×12)/3 / gap = space.md"
    }

    Caption {
        x: win.grpX[0]
        y: win.rowDY - 22
        tone: "muted"
        text: "D · 按钮组：左 4 枚 spacing:0 ｜ 中 3 枚 spacing:4（逐角可量）｜ 右 单枚 standalone"
    }

    Caption {
        x: win.fbX[0]
        y: win.rowEY - 22
        tone: "muted"
        text: "E · 悬浮球：静息 ｜ hovered ｜ disabled ｜ badge=5 ｜ 静息+tip(关着)"
    }

    Caption {
        x: win.upX
        /* ⚠ 这里原先是 `win.rowEY - 22` —— 与 E 组的标题**同一个坐标**
         * （两组都在右栏、`fbX[0]` 与 `upX` 都是 680），两行字直接叠在一起。
         * E 组在 rowEY、F 组在 rowFY，标题各跟着自己那一组走。 */
        y: win.rowFY - 22
        tone: "muted"
        text: "F · 上传：虚线触发区 + 四行（0.25 / 0.75 / 1.0 / 失败）"
    }

    /* ══════════════════════════════════════════════════════════════════
     * A —— 键帽 ×4
     * ══════════════════════════════════════════════════════════════════ */

    QSkinKbd {
        id: kMd1
        x: win.kbdX[0]
        y: win.rowAY
        keys: "Esc"
    }

    QSkinKbd {
        id: kMd2
        x: win.kbdX[1]
        y: win.rowAY
        keys: ["Ctrl", "K"]
    }

    QSkinKbd {
        id: kSm
        x: win.kbdX[2]
        y: win.rowAY
        keys: ["Ctrl", "Shift", "K"]
        size: "sm"
    }

    /* 对照：没有厚度 */
    QSkinKbd {
        id: kThin
        x: win.kbdX[3]
        y: win.rowAY
        keys: ["Alt"]
        thickness: 0
    }

    /* ══════════════════════════════════════════════════════════════════
     * B —— 水印 ×3
     * ══════════════════════════════════════════════════════════════════ */

    QSkinWatermark {
        id: wm0
        x: win.wmX[0]
        y: win.rowBY
        width: win.wmW
        height: win.wmH
        text: "QSkin"
        gapX: win.wmGapX
        gapY: win.wmGapY

        /* ⚠ `rotate: 0` **必须写** —— `QSkinWatermark.rotate` 的**默认值是 -30**，
         *   不是 0。不写这一行，这个"基准盒"自己就是斜的，与 wm30 一模一样的
         *   形状 → 倾角那条判据（"wm0 是 0°、wm30 是 -30°"）**恒真**，
         *   等于没测。
         *   实测证据（`.cache/_p13_m27px.py`，量同一格三字 Q→D→S 的中心连线）：
         *   不写时 wm0 的斜率 = -0.608 → 31.3°（与 wm30 的 30° 同档）。 */
        rotate: 0
    }

    QSkinWatermark {
        id: wm30
        x: win.wmX[1]
        y: win.rowBY
        width: win.wmW
        height: win.wmH
        text: "QSkin"
        gapX: win.wmGapX
        gapY: win.wmGapY
        rotate: -30
    }

    QSkinWatermark {
        id: wmOff
        x: win.wmX[2]
        y: win.rowBY
        width: win.wmW
        height: win.wmH
        text: "QSkin"
        gapX: win.wmGapX
        gapY: win.wmGapY
        rotate: -30
        offsetX: 30
        offsetY: 20
    }

    /* 第四个盒子：整幅都是内容色 —— 只问一件事："墨有没有压在内容之上"。
     * 这件事属性侧只说得出 `visible`。 */
    QSkinWatermark {
        id: wmCover
        x: win.wmX[3]
        y: win.rowBY
        width: win.wmW
        height: win.wmH
        text: "QSkin"
        gapX: win.wmGapX
        gapY: win.wmGapY
        /* 同 wm0：默认值是 -30，要 0° 就得写出来 */
        rotate: 0

        Rectangle {
            anchors.fill: parent
            color: Theme.color.bgSubtle
        }
    }

    /* ══════════════════════════════════════════════════════════════════
     * C —— 瀑布流
     * ══════════════════════════════════════════════════════════════════ */

    QSkinMasonry {
        id: masonry
        x: win.maX
        y: win.rowCY
        width: win.maW
        columns: win.maCols
        heightField: "h"
        model: [
            { h: win.maHeights[0] }, { h: win.maHeights[1] }, { h: win.maHeights[2] },
            { h: win.maHeights[3] }, { h: win.maHeights[4] }, { h: win.maHeights[5] },
            { h: win.maHeights[6] }
        ]

        delegate: Component {
            Rectangle {
                id: card

                property var modelData: null
                property int index: -1

                color: Theme.color.brandSubtle
                radius: Theme.radius.sm

                Caption {
                    anchors.centerIn: parent
                    text: card.index >= 0 ? ("#" + (card.index + 1) + "  h="
                                            + (card.modelData ? card.modelData.h : "?")) : ""
                }
            }
        }
    }

    /* ══════════════════════════════════════════════════════════════════
     * D —— 按钮组 ×3
     * ══════════════════════════════════════════════════════════════════ */

    QSkinButtonGroup {
        x: win.grpX[0]
        y: win.rowDY
        accessibleName: "四枚一组"

        QSkinButton { text: "一"; variant: "primary" }
        QSkinButton { text: "二"; variant: "primary" }
        QSkinButton { text: "三"; variant: "primary" }
        QSkinButton { text: "四"; variant: "primary" }
    }

    /* 间距非 0：每枚各自成一个连通块 —— 逐枚逐角都能量 */
    QSkinButtonGroup {
        x: win.grpX[1]
        y: win.rowDY
        spacing: 4
        accessibleName: "三枚一组（带间距）"

        QSkinButton { text: "一"; variant: "primary" }
        QSkinButton { text: "二"; variant: "primary" }
        QSkinButton { text: "三"; variant: "primary" }
    }

    QSkinButtonGroup {
        x: win.grpX[2]
        y: win.rowDY
        accessibleName: "单枚"

        QSkinButton { text: "独"; variant: "primary" }
    }

    /* ══════════════════════════════════════════════════════════════════
     * E —— 悬浮球 ×5
     * ══════════════════════════════════════════════════════════════════ */

    /* ① 静息 —— 不给 tip */
    QSkinFloatButton {
        id: fbIdle
        x: win.fbX[0]
        y: win.rowEY
        diameter: win.fbDia
    }

    /* ② 悬停（属性钉死）—— 填色与描边都换档，另带一枚方向朝上的记号
     *
     * ⚠ 这一枚**刻意不给 tip**。原先给了 `tip: "回到顶部"`，而 `hovered` 是
     *   属性钉死的 —— `QSkinTooltip` 读 `target.hovered`，于是提示**真的弹开**
     *   并被抓进图里（实测：一个深色圆角框压在 D 组标题与第 1 枚按钮上方，
     *   x≈903..965 / y≈54..84），把相邻组的测点窗污染了。
     *   `Popup` **会被 `contentItem.grabToImage()` 拍进来** —— 文件头那段
     *   "抓不到浮层"的说法是错的，这里改掉：本屏**不许有任何浮层开着**。
     *   提示本身归冒烟测试管（`tipOpened` 需要真悬浮），本屏只管几何。 */
    QSkinFloatButton {
        id: fbHover
        x: win.fbX[1]
        y: win.rowEY
        diameter: win.fbDia
        hovered: true
        icon: Slots.chevronIndicator
        iconDirection: "up"
    }

    /* ③ 禁用 */
    QSkinFloatButton {
        id: fbOff
        x: win.fbX[2]
        y: win.rowEY
        diameter: win.fbDia
        enabled: false
    }

    /* ④ 角标 —— 与 ① 的差就是角标本身 */
    QSkinFloatButton {
        id: fbBadge
        x: win.fbX[3]
        y: win.rowEY
        diameter: win.fbDia
        badge: 5
    }

    /* ⑤ 声明了 tip 但**不悬浮** —— 于是提示一直关着。
     *    它的墨量应与 ① 静息球**完全一致**：这就是"声明 tip 不改变几何、
     *    关着的浮层不落笔"那条旁证（比原先"两枚都不给 tip"强，那条是空的）。 */
    QSkinFloatButton {
        id: fbTip
        x: win.fbX[4]
        y: win.rowEY
        diameter: win.fbDia
        tip: "回到顶部"
    }

    /* ══════════════════════════════════════════════════════════════════
     * F —— 上传
     * ══════════════════════════════════════════════════════════════════ */

    QSkinUpload {
        id: upload
        x: win.upX
        y: win.rowFY
        contentWidth: win.upW
        triggerHeight: win.upTriggerH
        hint: "支持 png / jpg，单个不超过 2MB"
        spinning: false
        maxCount: 6
    }

    /** 播种四行状态。**必须与 `_verify_m27px.py` 里的期望表逐字一致。**
     *  只在 `Component.onCompleted` 里跑一次 —— 进度条宽度带动画，
     *  在这里改值会起一段动画，1500ms 后抓图时已收敛。 */
    function seedUpload() {
        upload.addFiles([
            { name: "方案-v3.pdf", size: 1048576 },
            { name: "截图-01.png", size: 524288 },
            { name: "数据.csv",   size: 2048 },
            { name: "坏文件.zip", size: 999 }
        ])
        upload.reportProgress("f1", win.upProgress[0])
        upload.reportProgress("f2", win.upProgress[1])
        upload.reportSuccess("f3")                       /* progress → 1 */
        upload.reportFailure("f4", "网络中断")            /* progress 停 0 */
    }

    /* ══════════════════════════════════════════════════════════════════
     * 自证行 —— 人看图就能核对这一帧
     * ══════════════════════════════════════════════════════════════════ */

    Caption {
        id: witness

        x: 40
        y: 660
        tone: "default"
        text: "M27-PAGE theme=" + win.themeName + " mode=" + win.mode
              + " | kbd=" + Math.round(kMd1.implicitWidth) + "," + Math.round(kMd2.implicitWidth)
              + "," + Math.round(kSm.implicitWidth) + "," + Math.round(kThin.implicitWidth)
              + " n=" + kMd1.keyCount + "," + kMd2.keyCount + "," + kSm.keyCount + "," + kThin.keyCount
              + " | ma colW=" + Math.round(masonry.columnWidth * 100) / 100
              + " contentH=" + Math.round(masonry.implicitHeight)
              + " | up iw=" + Math.round(upload.implicitWidth)
              + " ih=" + Math.round(upload.implicitHeight)
              + " count=" + upload.count
    }

    Caption {
        id: witness2

        x: 40
        y: 684
        text: "M27-GEO r=" + Theme.radius.md + "/" + Theme.radius.lg
              + " gap=" + Theme.space.md + " ctlH=" + Theme.size.controlMd
              + " | wm cols=" + wm0.gridCols + " n=" + wm0.gridPointCount
              + " | up rowH=" + upload.rowHeight + " rowGap=" + upload.rowGap
              + " trackTop=" + upload.trackTop + " thk=" + upload.trackThickness
              + " | p=" + upload.itemAt(0).progress + "," + upload.itemAt(1).progress
              + "," + upload.itemAt(2).progress + "," + upload.itemAt(3).progress
              + " st=" + upload.itemAt(0).status + "," + upload.itemAt(1).status
              + "," + upload.itemAt(2).status + "," + upload.itemAt(3).status
              /* 悬停是属性钉的，但真鼠标能改它 —— 打进日志，人一眼能核对 */
              + " | hover=" + fbIdle.hovered + "," + fbHover.hovered
              + "," + fbOff.hovered + "," + fbBadge.hovered
              + " tipOpened=" + fbHover.tipOpened
              + " overflow=" + Math.round((witness2.y + witness2.height) - win.height)
    }

    /* ══════════════════════ 开场与抓图 ══════════════════════ */

    Timer {
        interval: 1500
        running: win.shotMode
        onTriggered: {
            /* 两行自证**原样**打进 log（与 M26 同款：另拼一份 = 两处算路） */
            console.log(witness.text)
            console.log(witness2.text)
            var base = Qt.resolvedUrl(win.outBase).toString().replace("file:///", "")
            var name = "m27_example_" + win.themeName + "_" + win.mode + ".png"
            win.contentItem.grabToImage(function (res) {
                Qt.exit(res.saveToFile(base + name) ? 0 : 9)
            })
        }
    }
}
