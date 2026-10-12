/****************************************************************************
 * QSkin · 示例 —— M22：反馈与结果
 *
 * 三个件（Alert / Result / AlertDialog）在这一屏里全部用上，而且互相挨着 ——
 * 单独摆三个样例看不出"它们是不是同一个系统里的东西"，而"同一系统"正是
 * 这一批的全部意义：
 *
 *   · `QSkinAlert`        行内提示。四条语义一行一色（左侧竖条 + 记号都落在
 *                       `toneColor`），`closable` / `action` / `showIcon`
 *                       三个开关各自演示一次。
 *   · `QSkinResult`       结果页。同一枚记号放大到 64px —— 与 Alert 里的 20px
 *                       是**同一个插槽**，只是宿主报的 size 不同。
 *   · `QSkinAlertDialog`  确认对话框**预设**（不是新控件）：包一层 QSkinDialog，
 *                       加标题 / 正文 / 两个出口。
 *
 * ── 三件事共用一枚记号 ────────────────────────────────────────────────
 * 三件的记号（✓ / i / ! / ×）来自**同一个**插槽 `Slots.statusGlyph`，尺寸由
 * 宿主报：Alert 给 `Theme.size.iconMd`（20）、AlertDialog 给 `iconLg`（24）、
 * Result 自己有一个公开旋钮 `glyphSize`（默认 64）。切主题时它的**形态**会变
 * （Basic 系是实心圆盘 + 反白记号；shadcn 是描边圆环 + 同色记号，warning 还是
 * 三角）—— 这正是它必须是插槽、而不是画在契约层的原因。
 *
 * ── 这一屏的结构就是它的测试用例 ──────────────────────────────────────
 *
 *   QSkinWindow
 *   ├─ Rectangle                        页底（抓图要自己铺，见下）
 *   └─ QSkinColumn                        页
 *      ├─ QSkinRow                        标题行
 *      ├─ QSkinRow                        主区，左窄右宽
 *      │  ├─ QSkinColumn
 *      │  │  ├─ QSkinCard「行内提示」       ← 四条语义 + closable + action + showIcon:false
 *      │  │  └─ QSkinCard「确认对话框」      ← 两个触发器 + 两个 QSkinAlertDialog
 *      │  └─ QSkinColumn
 *      │     ├─ QSkinCard「结果页」          ← success | 404 **并排**（同级对比）
 *      │     └─ QSkinCard「glyphSize 是公开的旋钮」
 *      └─ QSkinColumn id: selfTest         自证行（见下）
 *
 * ── 想看的六件事 ──────────────────────────────────────────────────────
 *   ① 四条 Alert 的**语义色只在两处**：左侧那条竖条 + 记号本身。
 *      底纹是 subtle 档（比页底重一档、又不是饱和色）—— 换主题时这两处
 *      一起变，写死色值在这里会立刻穿帮。
 *   ② `closable: true` 的 × 与 `action` 里的按钮**不打架**：一个在右内边距，
 *      一个在它左边，顺序由 Alert 自己排。
 *   ③ `showIcon: false` 那条**没有记号**，左内边距与其它三条仍然对齐 ——
 *      隐藏记号不该让文字整体左移。
 *   ④ 结果页里 success 与 404 **一样高**。404 走的是"画状态码"分支，而状态码
 *      与记号**共用同一个视觉盒子**（`glyphSize`）；盒子一旦失效，自证行里的
 *      Δ 立刻非 0（那正是 M22.2 修的东西）。两页**并排**是为了让这条对比
 *      落在同一个宽度上 —— 宽度不同的话，折行行数一变，等式就不成立了。
 *   ⑤ `scene=dialog` 里 AlertDialog 打开的样子：遮罩把整屏压暗、面板居中、
 *      标题前的记号是 24px、两颗按钮**右对齐**。
 *   ⑥ 切到 shadcn 再跑一次：记号从实心圆盘变描边圆环，warning 变三角。
 *
 * ── 抓图（这个文件同时是截图入口，图存到 .cache/keep/）────────────────
 *     ./tools/shot.sh examples/showcase/HelloM22.qml theme=tdesign scene=base shot=1
 *     ./tools/shot.sh examples/showcase/HelloM22.qml theme=shadcn mode=dark scene=dialog shot=1
 *
 * 为什么抓图入口和交互示例**是同一个文件**：分两份必然漂移 —— 示例改了场景、
 * 抓图脚本忘了跟，于是"验过的"和"给人看的"不是同一个东西（M16 起沿用）。
 *
 * ── 高度是按**实测**排的，不是估的 ─────────────────────────────────────
 * 第一版摆完跑起来发现自证行被窗口底边裁掉了。探出来的真数字（tdesign/light）：
 * `page.implicitHeight = 1101` 而窗口只有 `1010`，其中右列 `907` 是约束
 * （结果页卡 568 + glyphSize 卡 323 + 缝 16）。于是把两张结果页**并排**、
 * 把卡内的长说明收进卡 `subtitle`，重排后 page 落到窗口以内并留出余量 ——
 * 换主题时字号与行高的差幅远小于这个余量。
 * **改这一屏的布局前先跑一次探针**（把 `page.implicitHeight` 打进日志），
 * 不要再靠估。
 *
 * ── 本环境实测结论（沿用 M16~M21，别再踩）──────────────────────────────
 * ① 根节点必须是 Window（见 QSkinWindow）。Item 作根节点事件循环起不来。
 * ② 抓图用 `Item.grabToImage`，不要用 `Window.grabWindow`（返回空图且静默）。
 * ③ **抓 `win.contentItem`，不要抓那个铺底的 Rectangle** —— 未设 parent 的
 *    `Popup` 会被 Qt 挂到窗口的 `Overlay.overlay` 上，而 overlay 是画布兄弟：
 *    抓画布等于把对话框整块丢掉，而图看起来"什么都没坏"。
 * ④ 抓图要自己铺底（`grabToImage` **不含** Window 的 `color`）。用
 *    `Theme.color.bg`；**不存在** `bgPage` 这个令牌（那是 TDesign 的 CSS
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

    width: 1440
    height: 1010
    visible: true
    title: "QSkin · M22 — 反馈与结果"

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
    readonly property string scene:     win.argOf("scene", "base")
    readonly property bool shotMode:    win.argOf("shot", "") !== ""

    function applyTheme() {
        Theme.mode = win.mode
        switch (win.themeName) {
            case "ant":    AntDesign.apply();   break
            case "arco":   ArcoDesign.apply();  break
            case "shadcn": Shadcn.apply();      break
            default:       TDesign.apply();     break
        }
    }

    /* 场景开关写成绑定，不做命令式赋值 —— 少一个时序变量（M18 教训）。 */
    readonly property bool scDialog: win.scene === "dialog"

    /* 业务回执（自证行里读） */
    property int confirmCount: 0
    property int cancelCount:  0
    property int closedCount:  0

    Component.onCompleted: function () {
        win.applyTheme()
        if (win.scDialog) confirmDel.open()
    }

    /* ---------- 页底（抓图要自己铺，见文件头 ④）---------- */
    Rectangle {
        anchors.fill: parent
        color: Theme.color.bg
    }

    /* ══════════════════════ 页面 ══════════════════════ */

    QSkinColumn {
        id: page

        anchors.fill: parent
        padding: Theme.space.xl
        gap: Theme.space.lg

        /* ── 标题行 ── */
        QSkinRow {
            Layout.fillWidth: true
            gap: Theme.space.md

            Heading { level: 3; text: "反馈与结果" }

            Caption {
                Layout.fillWidth: true
                text: "QSkinAlert · QSkinResult · QSkinAlertDialog"
                      + "（三件的记号来自同一个插槽 statusGlyph）"
            }

            Caption { text: win.themeName + " / " + win.mode + " / " + win.scene }
        }

        /* ══════════ 主区：左窄右宽 ══════════ */
        QSkinRow {
            Layout.fillWidth: true
            Layout.fillHeight: true
            gap: Theme.space.lg

            QSkinColumn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 4
                gap: Theme.space.lg

                /* ══════ 行内提示 ══════ */
                QSkinCard {
                    Layout.fillWidth: true
                    title: "行内提示"
                    subtitle: "四条语义一行一色；语义只落在左侧竖条与记号上 —— "
                              + "底纹是 subtle 档，比页底重一档又不是饱和色"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        QSkinAlert {
                            id: alInfo

                            Layout.fillWidth: true
                            type: "info"
                            title: "系统将在今晚 02:00 维护"
                            description: "预计 30 分钟，期间只读。"
                        }

                        QSkinAlert {
                            id: alSuccess

                            Layout.fillWidth: true
                            type: "success"
                            title: "保存成功"
                            description: "草稿已同步到云端。"
                        }

                        QSkinAlert {
                            id: alWarning

                            Layout.fillWidth: true
                            type: "warning"
                            title: "套餐 3 天后到期"
                            description: "到期后自动降级到免费版。"
                            closable: true

                            onClose: win.closedCount++
                        }

                        QSkinAlert {
                            id: alDanger

                            Layout.fillWidth: true
                            type: "danger"
                            title: "同步失败"
                            description: "网络不可达，可以马上重试。"
                            closable: true

                            onClose: win.closedCount++

                            action: QSkinButton { text: "重试"; variant: "text" }
                        }

                        /* ── 反面对照：`showIcon: false` 的那一条 ──
                         * 加这一条的理由是"判据要有反例"：若屏幕上**每一行**
                         * 都有记号，那么"记号有没有接 showIcon"这件事永远测
                         * 不出来 —— 一个把 `showIcon` 忽略掉的实现照样全绿。
                         * 所以这里必须留一条**看起来应该没有记号**的。 */
                        QSkinAlert {
                            id: alNoIcon

                            Layout.fillWidth: true
                            type: "danger"
                            title: "这一条故意不画记号（showIcon: false）"
                            description: "文字左沿仍与上面四条对齐。"
                            showIcon: false
                        }
                    }
                }

                /* ══════ 确认对话框 ══════
                 * 卡内只放"触发器 + 计数"：长说明全部收进 subtitle —— 这一屏的
                 * 高度是按实测挤出来的（见文件头那段），卡内 Caption 很贵。 */
                QSkinCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "确认对话框"
                    subtitle: "预设，不是新控件：包一层 QSkinDialog + 标题 / 正文 / 两出口。"
                              + "语义决定记号与确认键的变体 —— danger 那个确认键变红"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.sm

                        QSkinRow {
                            gap: Theme.space.md

                            QSkinButton {
                                text: "删除 3 个文件"
                                variant: "danger"
                                onClicked: confirmDel.open()
                            }

                            QSkinButton {
                                text: "标记为已同步"
                                variant: "text"
                                onClicked: confirmOk.open()
                            }

                            Caption {
                                text: "确认 " + win.confirmCount
                                      + " 次 / 取消 " + win.cancelCount + " 次"
                            }
                        }

                        Caption {
                            Layout.fillWidth: true
                            text: "打开之后 Esc 与点遮罩都算取消；两个出口各自恰好发一次信号"
                        }
                    }

                    /* ── 两个预设实例 ──
                     * 声明在卡片里、由上面的按钮驱动：定位是模态居中，与
                     * "声明在哪一层"无关。 */
                    QSkinAlertDialog {
                        id: confirmDel

                        type: "danger"
                        title: "删除这 3 个文件？"
                        description: "删除后不可恢复，协作者会立即失去访问权。"
                        panelWidth: 420
                        confirmText: "删除"

                        onConfirmed: win.confirmCount++
                        onCancelled: win.cancelCount++
                    }

                    QSkinAlertDialog {
                        id: confirmOk

                        type: "success"
                        title: "标记为已同步？"
                        description: "只改本地标记，不会立刻上传。"
                        confirmText: "标记"

                        onConfirmed: win.confirmCount++
                        onCancelled: win.cancelCount++
                    }
                }
            }

            QSkinColumn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 5
                gap: Theme.space.lg

                /* ══════ 结果页 ══════ */
                QSkinCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "结果页"
                    subtitle: "操作走完之后的整页交代。success 与 404 摆在同一行、"
                              + "同一个宽度下 —— 前者画记号，后者画状态码"

                    QSkinColumn {
                        Layout.fillWidth: true
                        gap: Theme.space.lg

                        /* 同级对比：两页**并排**，宽度相同、内容行数相同，
                         * 所以两个 implicitHeight 应当相等。自证行里那个 Δ
                         * 就是这条承诺的读数（M22.2 修的就是它）。 */
                        QSkinRow {
                            Layout.fillWidth: true
                            gap: Theme.space.lg

                            QSkinResult {
                                id: rSuccess

                                Layout.fillWidth: true
                                status: "success"
                                title: "提交成功"
                                subtitle: "审核结果会在 1 个工作日内发到邮箱。"
                            }

                            QSkinResult {
                                id: r404

                                Layout.fillWidth: true
                                status: "404"
                                title: "页面不存在"
                                subtitle: "链接可能已失效，或地址输错了。"
                            }
                        }

                        Caption {
                            Layout.fillWidth: true
                            text: "状态码与记号占的是同一个视觉盒子（都是 glyphSize），"
                                  + "所以换状态时整页不跳 —— 上面两页等高就是它"
                        }
                    }
                }

                /* ══════ 尺寸旋钮 ══════ */
                QSkinCard {
                    Layout.fillWidth: true
                    title: "glyphSize 是公开的旋钮"
                    subtitle: "同一枚记号在 Alert 里是 20、AlertDialog 里是 24、默认 64"

                    QSkinResult {
                        id: rSmall

                        Layout.fillWidth: true
                        status: "warning"
                        glyphSize: 32
                        title: "这个记号是 32px"
                        subtitle: "旋钮只改盒子大小，形态与语义色仍由主题决定。"
                        extra: QSkinButton { text: "知道了" }
                    }
                }
            }
        }

        /* ══════════ 自证行 ══════════
         * 抓图与人工核验都需要一个**不依赖眼睛判断**的锚点：把这一屏的读数
         * 直接印在图上 —— 图里看到的和它写的对不上，就是渲染出了问题
         * （M17 起沿用这个做法，这是第 7 个这么干的示例屏）。 */
        QSkinColumn {
            id: selfTest

            Layout.fillWidth: true
            gap: 2

            Caption {
                Layout.fillWidth: true
                text: "theme=" + win.themeName + "  mode=" + win.mode
                      + "  scene=" + win.scene
                      + "    alert: " + alInfo.type + "→" + alInfo._type
                      + " tone=" + alInfo.toneColor
                      + " showIcon=" + alInfo.showIcon
                      + " closable=" + alDanger.closable
                      + " title/desc=" + alInfo.hasTitle + "/" + alInfo.hasDescription
                      + "    noIcon条=" + (alNoIcon.showIcon === false)
            }

            Caption {
                Layout.fillWidth: true
                text: "result: success isCode=" + rSuccess._isCode
                      + " glyph=" + rSuccess._glyphStatus
                      + " size=" + rSuccess.glyphSize
                      + " h=" + rSuccess.implicitHeight
                      + "    |    404 isCode=" + r404._isCode
                      + " glyph=" + r404._glyphStatus
                      + " h=" + r404.implicitHeight
                      + "    →    Δ=" + (r404.implicitHeight - rSuccess.implicitHeight)
                      + "    小号 h=" + rSmall.implicitHeight
                      + "（size=" + rSmall.glyphSize + "）"
            }

            Caption {
                Layout.fillWidth: true
                text: "dialog: danger _type=" + confirmDel._type
                      + " confirmVariant=" + confirmDel._confirmVariant
                      + " opened=" + confirmDel.opened
                      + " panelW=" + confirmDel.panelWidth
                      + "    |    success _type=" + confirmOk._type
                      + " confirmVariant=" + confirmOk._confirmVariant
                      + "    |    confirmed=" + win.confirmCount
                      + " cancelled=" + win.cancelCount
                      + " closed=" + win.closedCount
            }
        }
    }

    /* ---------- 抓图（仅 shot 模式）----------
     * 1500ms 与 M17 起的其它屏一致：等淡入动画收尾，否则抓到的是中间帧。
     * 抓 `win.contentItem`（含 Popup 的 overlay 层），不抓那个铺底的 Rectangle
     * —— 理由见文件头 ③。 */
    Timer {
        interval: 1500
        running: win.shotMode
        onTriggered: {
            var base = Qt.resolvedUrl("../../.cache/keep/").toString().replace("file:///", "")
            var name = "m22_example_" + win.themeName + "_" + win.mode
                       + "_" + win.scene + ".png"
            win.contentItem.grabToImage(function (res) {
                Qt.exit(res.saveToFile(base + name) ? 0 : 9)
            })
        }
    }
}
