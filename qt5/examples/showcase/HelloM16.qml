/****************************************************************************
 * QSkin · 示例 —— M16：QSkinTable 右侧固定列（三区结构）
 *
 * ── 交互式跑（推荐先跑这个）────────────────────────────────────────────
 *     ./tools/run.sh examples/showcase/HelloM16.qml
 *
 *   · contentWidth 1450 > 容器宽 → 内容比容器宽，出现横向滚动
 *   · fixedColumns: 1     → 最左 1 列（+ 多选时的 checkbox 列）钉在左沿
 *   · fixedRightColumns: 1 → **最右 1 列**（操作）钉在右沿
 *   · 工具条可以在运行时改左右各钉几列、内容宽、以及滚到任意位置
 *
 * 想看的四个对比：
 *   ① 右固定列：横滚到底、滚到中间、滚到最左 —— "操作"那一列**纹丝不动**，
 *      而紧挨着它左边的"说明"整列在它底下滑过去
 *   ② 两道渐隐条是**两套条件**：左边那道在"已经往右滚了"时出现，
 *      右边那道在"还没滚到底"时出现。滚到最左只有右边亮，滚到最右只有
 *      左边亮，滚在中间两道都亮 —— 按"滚到最左 / 滚到最右"两个按钮看
 *   ③ 左固定 0 列时"全选"那个 checkbox 列**仍然钉着** —— 它不是数据列，
 *      横滚把它带走用户就再也点不到全选了
 *   ④ 左右固定列数加起来超过列数时，右固定列数被夹掉（一列不能同时
 *      钉在两边）；容器比钉住列还窄时右区被裁、中间区归零，而不是
 *      横着压到左区上面
 *
 * ── 抓图（这个文件同时是截图入口，图存到 .cache/）──────────────────────
 *     ./tools/shot.sh examples/showcase/HelloM16.qml theme=tdesign pos=middle shot=1
 *     ./tools/shot.sh examples/showcase/HelloM16.qml theme=shadcn mode=dark pos=right shot=1
 *
 * 为什么抓图入口和交互示例**是同一个文件**：分两份必然漂移 ——
 * 示例改了场景、抓图脚本忘了跟，于是"验过的"和"给人看的"不是同一个东西。
 *
 * 参数：
 *     theme = tdesign | ant | arco | shadcn
 *     mode  = light | dark（默认 light）
 *     pos   = left | middle | right —— 抓图前的横滚位置（默认 middle）
 *             middle 是**最能说明问题**的一档：两道渐隐条同时可见，
 *             右固定列底下正压着"说明"列的后半截
 *     shot  = 给了就进入抓图模式（摆好场景、存盘、退出）
 *
 * ── 本环境实测结论（沿用 M12~M15，别再踩）──────────────────────────────
 * ① 根节点必须是 Window（见 QSkinWindow）。Item 作根节点事件循环起不来。
 * ② 抓图用 Item.grabToImage，不要用 Window.grabWindow（返回空图且静默）。
 * ③ 抓图要自己铺底 —— QSkinWindow 的底色在 canvas 子树外面，抓不进来。
 *    用 `Theme.color.bg`；**不存在** `bgPage` 这个令牌（那是 TDesign CSS
 *    变量名），写它不报错、只是静默透明。
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

    width: 1020
    height: 700
    visible: true
    title: "QSkin · M16 — 右侧固定列"

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
    readonly property string pos:       win.argOf("pos", "middle")
    readonly property bool shotMode: win.argOf("shot", "") !== ""

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

    QtObject {
        id: state

        property int selectedRow: -1
        property int contentW: 1450
        property bool pins: true
    }

    ListModel {
        id: files

        ListElement { name: "Slots.qml";         mod: "契约层"; lines: 420;  status: "已同步"; owner: "林一"; commit: "09-11 09:12"; note: "插槽注册表，含 chevronIndicator"; act: "编辑" }
        ListElement { name: "Theme.qml";         mod: "基础层"; lines: 260;  status: "已同步"; owner: "陈二"; commit: "09-10 22:41"; note: "令牌入口，patch 不原地改"; act: "编辑" }
        ListElement { name: "QSkinTable.qml";      mod: "契约层"; lines: 2180; status: "评审中"; owner: "张三"; commit: "09-12 10:02"; note: "三区结构：左固定 / 中间 / 右固定"; act: "评审" }
        ListElement { name: "QSkinMenu.qml";       mod: "契约层"; lines: 330;  status: "已同步"; owner: "张三"; commit: "09-06 17:30"; note: "分隔线计高修复"; act: "编辑" }
        ListElement { name: "tokens-tdesign.js"; mod: "主题层"; lines: 180;  status: "已同步"; owner: "李四"; commit: "09-02 11:05"; note: "官方令牌"; act: "编辑" }
        ListElement { name: "tokens-shadcn.js";  mod: "主题层"; lines: 165;  status: "草稿";   owner: "李四"; commit: "09-03 15:48"; note: "待补深色"; act: "编辑" }
        ListElement { name: "smoke_m16.qml";     mod: "测试";   lines: 300;  status: "评审中"; owner: "王五"; commit: "09-12 11:20"; note: "8 条断言，含对象树几何核验"; act: "评审" }
        ListElement { name: "README.md";         mod: "文档";   lines: 1900; status: "已同步"; owner: "林一"; commit: "09-12 11:50"; note: "M16 章节"; act: "编辑" }
    }

    function rowsFrom(model) {
        var out = []
        for (var i = 0; i < model.count; ++i) out.push(model.get(i))
        return out
    }

    /* ---------- 抓图场景摆放 ---------- */
    function placeForShot() {
        switch (win.pos) {
            case "left":  table.scrollTo(0);      break
            case "right": table.scrollTo(99999);  break
            default:      table.scrollTo(Math.round(table._maxScrollX / 2))
        }
    }

    /* ---------- 可抓取的内容区 ---------- */
    Item {
        id: canvas

        anchors.fill: parent

        /* 抓图要自己铺底（见文件头第 ③ 条） */
        Rectangle {
            anchors.fill: parent
            color: Theme.color.bg
        }

        QSkinColumn {
            id: page

            anchors.fill: parent
            padding: Theme.space.xl
            gap: Theme.space.md

            /* ── 头部：标题 + 主题切换 ── */
            QSkinRow {
                fill: true
                gap: Theme.space.sm

                Heading { text: "M16 · 右侧固定列" }

                Spacer { }

                QSkinButton { text: "TDesign"; variant: win.activeTheme === "tdesign" ? "primary" : "default"
                            onClicked: win.activeTheme = "tdesign" }
                QSkinButton { text: "Ant";     variant: win.activeTheme === "ant" ? "primary" : "default"
                            onClicked: win.activeTheme = "ant" }
                QSkinButton { text: "Arco";    variant: win.activeTheme === "arco" ? "primary" : "default"
                            onClicked: win.activeTheme = "arco" }
                QSkinButton { text: "shadcn";  variant: win.activeTheme === "shadcn" ? "primary" : "default"
                            onClicked: win.activeTheme = "shadcn" }
                QSkinButton {
                    variant: "ghost"
                    text: Theme.mode === "dark" ? "浅色" : "深色"
                    onClicked: Theme.mode = (Theme.mode === "dark") ? "light" : "dark"
                }
            }

            /* “现况”单独占一行 —— Layout.fillWidth 让它换行而不是溢出窗口 */
            Caption {
                Layout.fillWidth: true

                text: "内容总宽 " + table._contentTotal + "px，容器 " + Math.round(table.width)
                      + "px；三区：" + table._leftWidth + " + " + table._middleWidth
                      + " + " + table._rightWidth + " = "
                      + Math.round(table._leftWidth + table._middleWidth + table._rightWidth)
                      + "px（恒等于容器宽）。横向位置 " + Math.round(table.scrollX)
                      + " / " + table._maxScrollX + "。"
            }

            /* ── 工具条 ── */
            QSkinRow {
                fill: true
                gap: Theme.space.sm
                visible: !win.shotMode

                QSkinButton {
                    text: "左固定：" + (table.fixedColumns === 0 ? "无" : table.fixedColumns)
                    onClicked: table.fixedColumns = (table.fixedColumns + 1) % 3
                }
                QSkinButton {
                    text: "右固定：" + (table.fixedRightColumns === 0 ? "无" : table.fixedRightColumns)
                    onClicked: table.fixedRightColumns = (table.fixedRightColumns + 1) % 3
                }
                QSkinButton {
                    text: "内容宽：" + table.contentWidth
                    onClicked: table.contentWidth = table.contentWidth > 0 ? 0 : state.contentW
                }

                QSkinButton { text: "滚到最左"; variant: "ghost"; onClicked: table.scrollTo(0) }
                QSkinButton { text: "滚到中间"; variant: "ghost"
                            onClicked: table.scrollTo(Math.round(table._maxScrollX / 2)) }
                QSkinButton { text: "滚到最右"; variant: "ghost"; onClicked: table.scrollTo(99999) }
            }

            /* ── 表格 ── */
            QSkinTable {
                id: table

                Layout.fillWidth: true
                contentWidth: state.contentW       /* 0 = 撑满容器（M12 行为）*/
                fixedColumns: 1                    /* 最左 1 列钉住 */
                fixedRightColumns: 1               /* 最右 1 列钉住（操作）*/
                checkable: true
                emptyText: "没有文件"

                columns: [
                    { title: "文件名",   dataIndex: "name",   width: 240, sortable: true },
                    { title: "模块",     dataIndex: "mod",    width: 140, sortable: true },
                    { title: "行数",     dataIndex: "lines",  width: 110, align: "right", sortable: true },
                    { title: "状态",     dataIndex: "status", width: 140, sortable: true },
                    { title: "负责人",   dataIndex: "owner",  width: 140, sortable: true },
                    { title: "最近提交", dataIndex: "commit", width: 220, sortable: true },
                    { title: "说明",     dataIndex: "note",   width: 300 },
                    { title: "操作",     dataIndex: "act",    width: 160, align: "center" }
                ]
                /* rowsFrom 是外层根的函数 —— 跨作用域引用，qmllint 静态解析
                 * 不到（与 QSkinSelect delegate 同款局限），局部关闭。 */
                // qmllint disable unqualified
                rows: rowsFrom(files)
                // qmllint enable unqualified

                selectedRow: state.selectedRow
                onRowClicked: function(index) { state.selectedRow = index }
            }

            Caption {
                Layout.fillWidth: true

                text: "M16 契约：fixedRightColumns（最右 N 列不参与横滚）。"
                      + "滚动范围与钉住多少**无关** —— 可滚内容少了被钉住的那几列，"
                      + "中间区也多出同样多，两边正好抵消，能滚多远只由「内容 vs 容器」决定。"
                      + "右固定区与中间区在滚到底时恰好接上：中间区能露出的最后一个"
                      + "内容坐标，正是右区的左沿。"
            }
        }
    }

    /* ---------- 抓图（仅 shot 模式）----------
     * 分两拍：第一拍先把横滚摆到位，第二拍再抓 —— 同一拍里做完的话
     * 抓到的可能是摆位那一帧的渲染结果（右固定区的宿主 x 依赖 scrollX，
     * 而 clip 窗口的更新在下一帧的 polish 才生效）。 */
    Timer {
        interval: 700
        running: win.shotMode
        onTriggered: win.placeForShot()
    }

    Timer {
        interval: 1500
        running: win.shotMode
        onTriggered: {
            var base = Qt.resolvedUrl("../../.cache/").toString().replace("file:///", "")
            var name = "m16_" + win.themeName + "_" + win.mode + "_" + win.pos + ".png"
            canvas.grabToImage(function (res) {
                Qt.exit(res.saveToFile(base + name) ? 0 : 9)
            })
        }
    }
}
