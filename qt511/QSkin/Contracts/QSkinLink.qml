/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinLink
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 链接 —— 一段**认得出是链接**的可点文字。
 *
 * 用法：
 *     QSkinLink { text: "查看详情"; href: "https://example.com" }
 *     QSkinLink { text: "隐私政策"; variant: "muted" }
 *     QSkinLink { text: "删除账号"; variant: "danger"; onClicked: del() }
 *
 * ════════════════════════════════════════════════════════════════════════
 *  它存在的理由是**了结 label 插槽上记了二十多个里程碑的那个缺口**
 * ════════════════════════════════════════════════════════════════════════
 * M4 的原始记录（`README.md` 第 169 行，原文）：
 *
 *     「契约层露出两个缺口：a) label 无下划线语义（shadcn link 变体只能
 *       hover 近似）；b) 浮层无法上报「内容 + 阴影外扩」尺寸…」
 *
 * `shadcn/slots/SCLabel.qml` 的文件头把那笔账记得更准：它当时把下划线
 * 用 `Text.underline` 在 hover 时**近似**，并写明"该升格为
 * `control.labelUnderline`，而不是每个主题各自 hardcode"。
 *
 * 所以 M30 做这一件时分成了两半，**缺一半都不算做完**：
 *
 *   ① **契约侧**：label 插槽新增 `link` 变体 + `labelUnderline` 读取字段。
 *      `link` 变体是必需的 —— 链接要"不 hover 也认得出是链接"，而四家
 *      已有的 `ghost` / `text` 里，Ant 与 Arco 的**非 hover 态是正文色**
 *      （见 `ADLabel` / `ACLabel` 的注释），拿它们当链接会渲染成一段黑字。
 *      `labelUnderline` 是三态的（`undefined` = 主题按自家惯例），
 *      理由写在 `contracts/slots/BasicLabel.qml` 文件头。
 *   ② **控件侧**：本件。它只做"把一个 label 插槽当成自己的文字"，
 *      颜色与下划线**全部**归插槽 —— 本文件里一个颜色字面量都没有。
 *      这就是"两段文字必须一起换肤"那条（`QSkinLabel` 文件头）的又一次应用。
 *
 * ════════════════════════════════════════════════════════════════════════
 *  `href` **不**自动打开
 * ════════════════════════════════════════════════════════════════════════
 * 不加 `openExternally` 之类的开关，理由是 `QSkinUpload` 立下的那条规矩：
 * **控件里一行 IO 都没有**（那一件把真实上传收成"一个信号 + 三个方法"）。
 * `Qt.openUrlExternally` 是真实副作用 —— 由宿主在 `onClicked` 里写：
 *
 *     QSkinLink { text: "官网"; href: url
 *               onClicked: Qt.openUrlExternally(url) }
 *
 * `href` 于是是**元数据**：它进无障碍描述、也给宿主的处理器用。这样
 * "点了会弹浏览器"这件事在代码里看得见，而不是藏在控件的某个属性后面。
 *
 * ════════════════════════════════════════════════════════════════════════
 *  三个变体，不是五个
 * ════════════════════════════════════════════════════════════════════════
 * `link`（默认）| `muted`（次要链接）| `danger`（破坏性操作）。
 * 不做 `success` / `warning`：label 插槽家族里没有这两档，为链接单独给
 * 五份 label 实现各加两个语义色，收益（一个绿色的"成功链接"）与成本
 * （五个文件 × 两档 × 以后每次换肤都要照顾）不成比例。
 * 真要那种颜色，宿主绑 `color` —— 本件是 `Item`，文字在插槽里，
 * 想改色请提需求而不是在调用处硬写。
 *
 * ════════════════════════════════════════════════════════════════════════
 *  键盘与无障碍
 * ════════════════════════════════════════════════════════════════════════
 *   · `activeFocusOnTab` + Space / Enter 触发 —— 与按钮同一套键位；
 *   · `Accessible.role: Accessible.Link`（不是 StaticText）——
 *     读屏软件据此把它念成"链接"并允许回车激活；
 *   · `Accessible.onPressAction` 接上同一个动作，且**与鼠标点击共用
 *     一条 `activate()`** —— 两条路径分别实现是"键鼠行为漂移"的经典来源。
 *
 * ── 已知有损（如实记，别在别处补全）────────────────────────────────────
 *   · **没有外链记号**（Ant 的 Link 可挂一个 ↗）。画它要再占一格图标，
 *     而本仓的图标路线是插槽（见 `COVERAGE.md` 的 Icon 那一行），
 *     为一个可选装饰开新格不划算。
 *   · **没有 visited 状态**：Qt 的 `Text` 拿不到浏览历史，这一档是 Web
 *     浏览器独有的，桌面端没有对应物。
 *   · **不省略**：`BasicLabel` 的 `elide` 只在文字宽度被容器夹住时生效，
 *     而本件按内容收缩（继承 `QSkinRow` 的行语义）。要截断请给一个窄容器，
 *     与 `QSkinLabel` 文件头里那条"没有 elide"同源。
 ****************************************************************************/

import QtQuick 2.11
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 内容 ══════════════════════ */

    property string text: ""

    /** 目标地址。**只作元数据**（无障碍描述 + 给宿主的处理器读）——
     *  本件不打开它，见文件头。 */
    property string href: ""

    /* ══════════════════════ 外观 ══════════════════════ */

    /** link | muted | danger —— 直接就是 label 插槽的变体名，
     *  不做一层"控件名 → 插槽名"的翻译（多一层就多一处会写错的地方）。 */
    property string variant: "link"

    /** auto | always | never。auto = **hover 时画下划线**（四家参照的
     *  共同惯例：Ant 的 `:hover`、Argo/TDesign 的 `hover: underline`、
     *  shadcn 的 `hover:underline`）。 */
    property string underline: "auto"

    /* ══════════════════════ 状态 ══════════════════════ */

    property bool hovered: false
    property bool pressed: false

    /** 被点击 / 被键盘或读屏激活。**两者共用同一个出口**（见文件头）。 */
    signal clicked()

    /* ══════════════════════ 契约上报 ══════════════════════
     * label 插槽读这三个。与 QSkinLabel 同款 —— 宿主上报状态、主题决定样子。 */

    /** 要不要画下划线。**三态**：auto 时上报 hovered（具体值），
     *  而不是 `undefined` —— "auto"这个词在本件里已经有确定的含义
     *  （= hover），把"没意见"留给主题会变成两处都在猜。 */
    readonly property bool labelUnderline:
        root.underline === "always" ? true
      : root.underline === "never"  ? false
                                    : root.hovered

    /** 链接是行内文字，左对齐 */
    readonly property int labelAlignment: Text.AlignLeft

    /* ══════════════════════ 尺寸 ══════════════════════ */

    implicitWidth:  row.implicitWidth
    implicitHeight: row.implicitHeight

    width:  implicitWidth
    height: implicitHeight

    /* ══════════════════════ 无障碍 ══════════════════════ */

    activeFocusOnTab: root.enabled

    Accessible.role: Accessible.Link
    Accessible.name: root.text
    Accessible.description: root.href !== "" ? root.href : ""
    Accessible.focusable: true

    /** 读屏软件的"激活"手势走这里 —— 与鼠标、键盘同一条出口。 */
    Accessible.onPressAction: root.activate()

    /* ══════════════════════ 文字 ══════════════════════
     * 只放一个 Loader，别的什么都不放：文字的字体、颜色、下划线
     * **全部**归插槽（见文件头）。本件一行颜色都没有。 */

    QSkinRow {
        id: row

        x: 0
        y: 0
        padding: 0
        gap: 0

        Loader {
            id: labelLoader

            sourceComponent: Slots.label

            Binding {
                target: labelLoader.item
                property: "control"
                value: root
                when: labelLoader.item !== null
            }
        }
    }

    /* ══════════════════════ 交互 ══════════════════════ */

    /* 键盘不做 `pressed` 态：按住空格不放不是一个有意义的链接状态，
     * 而"假装按下"会让插槽里的按下色在没有鼠标的情况下亮起来。 */
    Keys.onSpacePressed: root.activate()
    Keys.onReturnPressed: root.activate()
    Keys.onEnterPressed:  root.activate()

    MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onEntered: root.hovered = true
        onExited:  { root.hovered = false; root.pressed = false }
        onPressed: root.pressed = true
        onReleased: root.pressed = false
        /* 不用 `onReleased` 触发：`MouseArea.clicked` 本身就要求
         * "在同一片里按下并松开"，在控件上按下、拖出去再松手它不会发
         * —— 那正是按钮的惯例（拖出去 = 取消）。自己用 released 触发
         * 反而会把这个约定丢掉。 */
        onClicked: root.activate()
    }

    FocusRing { control: root }

    /* ══════════════════════ 动作 ══════════════════════ */

    /**
     * activate() —— 鼠标 / 键盘 / 读屏**唯一**的激活出口。
     * 三处各写一遍是"键鼠行为漂移"的经典来源（`Slots.qml` 契约第 3 条
     * 禁止插槽引入交互，正是为了不在插槽那一侧再多出第四遍）。
     */
    function activate() {
        if (!root.enabled) return
        root.clicked()
    }
}
