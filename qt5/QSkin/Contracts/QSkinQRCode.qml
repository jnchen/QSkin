/****************************************************************************
 * QSkin · Quick Design System — Contracts / QSkinQRCode
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 二维码（M24）。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 矩阵从哪来：**唯一**的实现在地基层，本件只负责"画出来"
 * ════════════════════════════════════════════════════════════════════════
 *     QSkin.Foundation.QRCodeEncoder.encode(text, ecc, opts)
 *         → { ok, version, mask, size, modules: [[bool…]…], … }
 *
 * 本件一行编码算法都没有。这条分工是**被验证撑起来的**，不是洁癖：那份
 * 编码器能在 node 下被 require（`.cache/_qrdump.js`），于是它与 qrcode 库
 * 逐模块比对、与 segno 归因、再用 zxing-cpp 往返回读 —— 三条独立算路都
 * 成立。如果算法长在控件里，这三条一条也做不了。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么**没有**新开插槽
 * ════════════════════════════════════════════════════════════════════════
 * 判据沿用 M21 的：插槽只给"**同一主题里两种取值必须并存**的**形态**差异"
 * 开格；只差颜色/尺寸的，用令牌或属性。
 *
 * 二维码没有那种差异 —— 等大方块 + 静默边，四家一模一样。真正会不一样的
 * 只有前景/底色与模块大小，那两样本来就是属性。硬开一格 "qrModule" 只会
 * 得到一格"所有主题都写成同一个矩形"的插槽。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 颜色默认是**纯黑/纯白**，而不是令牌 —— 这是本件唯一一处刻意不用主题
 * ════════════════════════════════════════════════════════════════════════
 * 其余每一件控件都从 `Theme.color.*` 取色，这一件不取。理由是职责不同：
 *
 *   · 其它控件的颜色是**给人看**的，属于品牌与层级，该跟着主题走。
 *   · 二维码是**给机器读**的。`Theme.color.fg` 在深色主题下是 #F2F2F5、
 *     `bg` 是 #141419 —— 那是一个**反色**二维码。规范里符号是深色模块印在
 *     浅底上（ISO/IEC 18004 §7.1），反色码有一部分解码器读不出来。而
 *     参照实现（Ant / Arco / TDesign）的二维码在深色主题下**都是黑白**的，
 *     真实的扫码页（支付码、分享码）也一律保持白底。
 *
 * 所以默认值写死 `#000000` / `#FFFFFF`，同时把它们开成属性 —— 想要品牌色
 * 就显式改，并且**自己承担可读性的后果**。这不是"忘了接令牌"，是接错了
 * 才是错的。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 怎么画：1 个 Shape + 1 条 SVG 路径，不是一个模块一个 Rectangle
 * ════════════════════════════════════════════════════════════════════════
 * v40 是 177×177 = 31329 个模块。`Repeater` + `Rectangle` 那种写法在这里
 * 是三万个节点。
 *
 * 矩阵里同一行的深色模块本来就是**成段**的，所以先把每行压成若干水平段
 * （run），再把这些段拼成**一条路径字符串**：
 *
 *     M0 0h20v4h-20z M40 0h8v4h-8z …
 *
 * 于是整幅码只有 1 个 Shape + 1 个 ShapePath + 1 个 PathSvg。
 *
 * ── 为什么用 PathSvg 而不是 Canvas ────────────────────────────────────
 * 项目已经为这件事付过一次学费（见 `slots/BasicProgressTrack.qml` 文件头）：
 * **Canvas 不参与 QML 的绑定依赖图**，`value` 变了必须手动 `requestPaint()`，
 * 忘一次就得到一个停在旧值的画面。而 `PathSvg.path` 是**一条普通绑定** ——
 * 矩阵一变自己就重画，没有"忘记请求重绘"这种状态。
 *
 * ── fillRule 为什么是 WindingFill（以及实测打翻了首版的说法）───────────
 * 首版这里写的是「用默认的 OddEvenFill 时，共享边的两侧各被计一次跨越，
 * 覆盖数成偶数 → 那条边会被挖掉」。**这个推演是错的**，探针把它否掉了。
 *
 * 实测（`.cache/_probe_m24path.qml` + `_probe_m24path.py`）：5×5 全深色块
 * （每格 8px，**每条边都共享**）用三种画法并排画出来 —— 单路径 WindingFill /
 * 单路径 OddEvenFill / 25 个独立 Rectangle —— 再逐像素比对。结论三条：
 *
 *   ① 偶奇规则只在子路径**重叠**处抵消，而二维码这条路径里的子路径**只相切**：
 *      同一行里两段之间必隔至少一个浅色模块，行与行之间也不重叠。
 *      于是 A 与 B **逐像素完全相同**（差异 0）。判据里因此留了一条
 *      `A == B` 的等式 —— 把「分不出差别」这件事本身变成可证伪的。
 *   ② 内部共享边**没有缝**：外接框往里缩 3 设备像素后，浅色像素数为 0。
 *   ③ 真正的差别在**外轮廓**：单路径留下一圈约 1/6 设备像素、亮度约 83%
 *      的淡边（170 个像素），逐格 Rectangle 的对照是 0。
 *
 * 所以 WindingFill 是**语义上正确**（所有子路径同向绕行），**不是**「修了
 * 一个缝」—— 写在这里免得下一个人以为换个 fillRule 屏幕上就会变。那圈外
 * 轮廓淡边落在码的边界上、与静默边相接（宽度约一个模块的 3%），交给
 * 「把渲染结果喂给解码器」那条判据兜底 —— 那是唯一能同时证明"画对了"
 * 与"真的能扫"的判据。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 静默边（quiet zone）是**画出来的**，不是靠宿主留白
 * ════════════════════════════════════════════════════════════════════════
 * 码外那一圈空白是规范的一部分（≥ 4 模块），不是"留白好看"。所以本件把它
 * 画成**自己的底板**（`background` 填满整个 implicit 尺寸），于是"被父级
 * 裁掉"与"静默边被吃掉"变成同一件事 —— 宿主压着边框放，图上看得出。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 空内容 = 占位符，不画码 —— 而且这不是"顺手加的保护"
 * ════════════════════════════════════════════════════════════════════════
 * 编码器对空载荷是**显式拒绝**的。这个行为是实测裁定的：零长度载荷在
 * numeric / alnum / byte 三种模式下用 zxing-cpp 3.1.1 **都读不出**，
 * 参照实现 qrcode 库编出的空串符号同样读不出 —— 所以它不是本仓的编码
 * 缺陷，是退化输入。产品侧的正确行为在这里：显示占位框。
 *
 * ── 本件**刻意不做**的一件事 ─────────────────────────────────────────
 * 参照实现的二维码有"已过期 / 加载中"那套状态遮罩（Ant 的 `status`）。
 * 本件不做，理由是它属于**宿主的业务状态机**：什么时候过期由业务说了算，
 * 控件再存一份只会与宿主那一份打架（回到 QSkinCollapse 文件头批过的
 * "两份状态"）。宿主用 `visible` 叠一层 QSkinEmpty 就能表达，那正是 QSkinEmpty
 * 存在的意义。
 *
 * 用法：
 *     QSkinQRCode { value: "https://example.com/invite/abc"; ecc: "M" }
 *
 *     // 带中心 logo（默认属性）
 *     QSkinQRCode {
 *         value: "…"
 *         ecc: "H"                       // 带 logo 就该提到 Q/H，见下
 *         Rectangle { width: 28; height: 28; radius: 6; color: Theme.color.brand }
 *     }
 ****************************************************************************/

import QtQuick 2.15
/* ⚠ **不要**给这一句加版本号：`import QtQuick.Shapes 1.15` 会让
 * preferredRendererType / Shape.CurveRenderer 整个不可用 —— 这一条是
 * tools/check-shape-aa.py 明写出来的门禁（M16.1 就是这么踩的）。 */
import QtQuick.Shapes 1.15
import QSkin.Foundation 1.0

Item {
    id: root

    /* ══════════════════════ 取值 ══════════════════════ */

    /** 要编码的内容。空串 / null → 显示占位框，不画码。 */
    property string value: ""

    /** 纠错档：L(7%) | M(15%) | Q(25%) | H(30%)。
     *
     *  取 M 而不是 L：参照实现这一档的默认值**并不统一**（Ant 的
     *  `errorLevel` 与另一些生成器的默认档不是同一个），本仓取 M 并在这里
     *  写明，不假装它跟谁一致。
     *
     *  带 logo 时必须提档：logo 压掉的那块模块不会因为"看不见"就不算损失，
     *  纠错余量是唯一的兜底。经验线是"logo 占宽 ≤ 20% 时用 Q、≤ 15% 时用 H"。
     *  非法值会被编码器回落到 M，不报错。 */
    property string ecc: "M"

    /* ══════════════════════ 几何 ══════════════════════ */

    /** 一个模块的边长（像素）。默认 4 —— v3（29 模块）的码约 148px。 */
    property int moduleSize: 4

    /** 静默边宽度，单位是**模块数**（不是像素）。规范要求 ≥ 4。 */
    property int quietZone: 4

    /** 内容为空 / 不可编码时，占位框按多少个模块的边长画。
     *
     *  默认 29 = v3 的矩阵边长 —— 取"一个中等长度的 URL 会落到哪一版"，
     *  于是从空到有内容时版面几乎不跳高。写成可调属性而不是常量，
     *  是因为"跳不跳"取决于宿主的典型载荷。 */
    property int placeholderModules: 29

    /* ══════════════════════ 外观 ══════════════════════
     * 见文件头：默认是纯黑/纯白，**不是**令牌。 */

    /** 深色模块的颜色 */
    property color color: "#000000"

    /** 底色（同时是静默边） */
    property color background: "#FFFFFF"

    /** 占位框里的文字（内容为空时显示） */
    property string emptyText: qsTr("暂无内容")

    /* ══════════════════════ 中心 logo ══════════════════════
     *
     * 默认属性 —— 写进来的东西被摆在码的正中，并自动垫一块 background 色的
     * 底板。底板是必须的：没有它，logo 四角外的深色模块会从 logo 的圆角里
     * 透出来（那既难看，也让"这块区域已被覆盖"变得不可肉眼核对）。 */
    default property alias logo: logoHost.data

    /* ══════════════════════ 派生 ══════════════════════ */

    /** 编码结果。**唯一**的一次编码，所有派生量都从它算 ——
     *  再调一次 encode() 就是第二份算路（两份算路对不上时最难查）。 */
    readonly property var encoded: QRCodeEncoder.encode(root.value, root.ecc)

    /** 矩阵是否可用 */
    readonly property bool valid: root.encoded.ok === true

    /** 状态：ok | empty | error
     *  ——  区分 empty 与 error 是必要的：两者都要显示占位框，
     *      但"内容为空"和"内容装不下"?去是完全不同的两件事。 */
    readonly property string status:
        root.valid ? "ok"
                   : (root.value === null || root.value === undefined
                      || String(root.value).length === 0) ? "empty" : "error"

    /** 失败原因**码**（status 为 ok 时是空串）。取值：
     *      "" | "EMPTY" | "VERSION_OUT_OF_RANGE" | "NOT_FIT" | "TOO_LONG"
     *
     *  ── 为什么码在这儿、文案在下面 ────────────────────────────────────
     *  `QRCodeEncoder` 住在 `foundation/`，那一层要在 node 下**裸跑**
     *  （这正是它存在的理由：与 qrcode / segno / zxing-cpp 三条独立算路对拍）。
     *  裸跑时没有 QML 的翻译域，`qsTr` 在那儿既取不到也抽不走 —— 所以算路层
     *  只给**码 + 参数**，文案归这里。算路层的返回里仍留了一个 ASCII 的
     *  `error` 串，那是给 node / 日志的诊断，**不是**给用户看的（本件不读它）。 */
    readonly property string errorCode: root.valid ? "" : String(root.encoded.code || "")

    /** 失败原因（status 为 ok 时是空串）。宿主拿它去提示，控件自己不用它
     *  当占位文字 —— 那句错误文案很长，塞进小方框里会溢出。 */
    readonly property string errorText: {
        if (root.valid) return ""
        var p = root.encoded.params || {}
        switch (root.encoded.code) {
        case "EMPTY":
            return qsTr("内容为空：二维码没有可承载的载荷")
        case "VERSION_OUT_OF_RANGE":
            return qsTr("版本 %1 不在 1..40").arg(p.version)
        case "NOT_FIT":
            return qsTr("内容装不进版本 %1 的 %2 档（需要 %3 位，可容 %4 位）")
                    .arg(p.version).arg(p.ecc).arg(p.need).arg(p.cap)
        case "TOO_LONG":
            return qsTr("内容超出 40 版 %1 档容量（需要 %2 位以上，最大 %3 位）")
                    .arg(p.ecc).arg(p.need).arg(p.max)
        }
        return ""
    }

    /** 矩阵边长（模块数）；不可用时为 0 */
    readonly property int moduleCount: root.valid ? root.encoded.size : 0

    /** 落到第几版（1..40）与选中了哪个掩码 —— 诊断用，也是判据的抓手 */
    readonly property int version: root.valid ? root.encoded.version : 0
    readonly property int mask:    root.valid ? root.encoded.mask    : -1

    /** 模块路径（Shape 的输入）。**坐标是"码内局部像素"** —— 不含静默边
     *  的偏移，也不含任何填充。
     *
     *  ── 为什么路径里不含静默边 ────────────────────────────────────────
     *  静默边由 Shape 的 x/y 承担。于是"改 quietZone 不该重建路径"是一条
     *  可断言的性质（冒烟测试里就是这么读的）：依赖越少，能停在旧值的
     *  机会越少。 */
    readonly property string modulePath: root._buildPath()

    /** 矩阵的文本形式（'#' 深 '.' 浅，一行一行）。
     *  给调试与判据用 —— 它让"控件拿到的矩阵"可以直接与黄金向量对拍，
     *  不必去解码渲染结果。 */
    readonly property string matrixText:
        root.valid ? QRCodeEncoder.matrixToText(root.encoded.modules) : ""

    /** 外接边长，**单位是模块**（不是像素）：模块数（不可用时用占位模块数）
     *  + 两侧静默边。**像素**边长是 `codeSide * moduleSize`，也就是
     *  `implicitWidth` / `implicitHeight`。
     *
     *  ⚠ 这里的口径必须写死，因为它**不合直觉**：示例屏的自证行第一版
     *  直接把它当像素打成了「边长 37px」（真值 148px），而**属性侧一条断言
     *  都没红** —— 冒烟测试读的是模块口径（`codeSide === moduleCount
     *  + quietZone * 2`），与实现一致，所以两边都"对"。
     *  文档首版写的是"…再乘模块边长"，与实现相反（实现不乘，乘法在
     *  `implicitWidth` 那一行），读到它的人会以为 `codeSide` 是像素。
     *  要像素就自己乘 `moduleSize` —— 这一条现在只在这里有一份说法。 */
    readonly property int codeSide:
        (root.valid ? root.moduleCount : root.placeholderModules) + root.quietZone * 2

    implicitWidth:  root.codeSide * root.moduleSize
    implicitHeight: root.codeSide * root.moduleSize

    width:  implicitWidth
    height: implicitHeight

    /* 角色用 `Graphic` —— **不是** `Accessible.Image`。
     * 后者在本机 Qt 6.8.3 上不存在：`Accessible.role` 的类型是
     * `QAccessible::Role`，而 qmllint 报过
     *     Member "Image" not found on type "QQuickAccessibleAttached"
     * 实测枚举名是 Graphic。这类"看着该有、其实没有"的成员与
     * QSkinCollapseItem 文件头记的 `Accessible.expanded` 是同一个坑，
     * 而它只在 qmllint 下现形（属性断言抓不到 —— 对象根本没建成）。 */
    Accessible.role: Accessible.Graphic
    Accessible.name: root.valid ? qsTr("二维码，内容 %1").arg(root.value)
                                : qsTr("二维码，%1").arg(root.emptyText)
    Accessible.ignored: !root.valid

    /* ══════════════════════ 视觉 ══════════════════════ */

    /* 底板 —— 它同时就是静默边。**不可用时也画**：占位框底下那一层必须是
     * 同一个底色，否则"空"与"有内容"两种状态在版面上会换一个底色。 */
    Rectangle {
        anchors.fill: parent
        color:  root.background
        radius: root.valid ? 0 : Theme.radius.md
    }

    Shape {
        id: code

        visible: root.valid

        /* 只覆盖"码区"，静默边留在外面。见 modulePath 的注释。 */
        x: root.quietZone * root.moduleSize
        y: root.quietZone * root.moduleSize

        width:  root.moduleCount * root.moduleSize
        height: root.moduleCount * root.moduleSize

        /* CurveRenderer 才有原生抗锯齿（项目门禁：每个 Shape 都必须带这一行）。
         * 这里的形状全是轴对齐矩形，抗锯齿本来不该起作用 —— 但"不该起作用"
         * 与"没有接缝"是两件事，接缝恰恰是抗锯齿在**共享边**上算出来的，
         * 所以这一行与 fillRule 必须一起看（见文件头）。 */

        ShapePath {
            fillColor:   root.color
            strokeColor: "transparent"
            strokeWidth: 0
            fillRule:    ShapePath.WindingFill

            PathSvg { path: root.modulePath }
        }
    }

    /* ── 中心 logo ──
     * 两层：底板（background 色，给 logo 一个干净的四邻）+ 宿主塞进来的内容。
     * 用 QSkinRow 承载而不是裸 Item：QSkinRow 定义了 implicitWidth，于是
     * "有没有塞东西"可以靠 implicitWidth > 0 读出来（可通知）；
     * 而 `children.length` 在别名写进 layout 的情况下并不跟着变
     * （QSkinCollapse 的 extraHost 记过这条）。 */
    Item {
        id: logoPlate

        anchors.centerIn: parent
        visible: root.valid && logoHost.implicitWidth > 0

        width:  logoHost.implicitWidth  + Theme.space.xs * 2
        height: logoHost.implicitHeight + Theme.space.xs * 2

        Rectangle {
            anchors.fill: parent
            color:  root.background
            radius: Theme.radius.sm
        }

        QSkinRow {
            id: logoHost

            anchors.centerIn: parent
            gap: 0
            padding: 0
        }
    }

    /* ── 占位框 ──
     * 内容为空/装不下时的一个空框。它**不**画二维码，也不假装画一个。 */
    Rectangle {
        anchors.fill: parent
        visible: !root.valid
        color: "transparent"
        border.width: 1
        border.color: Theme.color.border
        radius: Theme.radius.md

        Caption {
            anchors.centerIn: parent
            width: parent.width - Theme.space.md * 2
            horizontalAlignment: Text.AlignHCenter
            text: root.emptyText
        }
    }

    /* ══════════════════════ 内部 ══════════════════════ */

    /** 矩阵 → 一条 SVG 路径（每行的深色连续段压成一个闭环矩形）。
     *
     *  闭环方向必须**完全一致**（这里是"右→下→左"，即顺时针），
     *  否则 WindingFill 在共享边上会得到 0 而不是非零，缝就回来了。
     *
     *  用 while 扫而不是逐格判断：连续段本来就是二维码的天然结构，
     *  v40 的路径字符串因此从 31329 个闭环降到约 4400 个（每行约 25 段）。 */
    function _buildPath() {
        var rows = root.encoded.modules
        if (!rows || rows.length === 0) return ""

        var n = rows.length
        var m = root.moduleSize
        var s = ""

        for (var r = 0; r < n; ++r) {
            var c = 0
            while (c < n) {
                if (!rows[r][c]) { ++c; continue }
                var from = c
                while (c < n && rows[r][c]) ++c
                var w = (c - from) * m
                s += "M" + (from * m) + " " + (r * m)
                   + "h" + w + "v" + m + "h-" + w + "z"
            }
        }
        return s
    }
}
