/****************************************************************************
 * QSkin · Quick Design System — Contracts / Slots
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * ════════════════════════════════════════════════════════════════════════
 *  这是 QSkin 最核心的资产：样式契约层。
 * ════════════════════════════════════════════════════════════════════════
 *
 * 它规定每个控件「哪些部分允许被主题替换」，一共六个**家族**：
 *
 *   background    控件底板：填充、边框、圆角、阴影、按下态
 *   contentItem   内容区：图标与文字的排布
 *   indicator     指示器：勾选框、开关轨道、展开箭头（M15.1 才补齐）
 *   overlay       浮层：下拉、气泡、菜单、Tooltip
 *   label         文本：字号、字重、颜色、禁用态
 *   glyph         语义记号：按语义取形的图形（M22 新增）
 *
 * ── label 那一格的两个「宿主上报」读取字段 ───────────────────────────────
 * 文字的样子由主题决定，但有两件事只有**宿主**知道，所以它们是字段而不是
 * 主题的猜测（两者都遵循"不声明就保持本主题原样"）：
 *
 *   labelAlignment   `Text.AlignLeft` 等。插槽默认居中（第一个使用者是按钮），
 *                    下拉框当前项、菜单项、标签要左对齐。
 *   labelUnderline   true / false，或 **undefined = 主题按自家惯例**
 *                    （三态的理由见 slots/BasicLabel.qml 文件头 —— 写成
 *                    bool 默认 false 会抹掉 shadcn 已有的 text-hover 下划线）。
 *
 * 外加一格**变体值** `link`（M30）：它必须存在，因为 Ant / Arco 的
 * `ghost` / `text` 在非 hover 时是**正文色** —— 拿它们当链接，得到的
 * 是一段认不出是链接的黑字。四家对 `link` 的取色各不相同（三家品牌色、
 * shadcn 近黑），这正是"变体归契约、样子归主题"的分工。
 *
 * 第六族是**长出来的**，不是设计出来的：M22 的三个件
 * （QSkinAlert / QSkinResult / QSkinAlertDialog）各自都需要"按语义画一个记号"，
 * 而前五族没有一个装得下它 —— 它不是控件的状态（不是 indicator），
 * 不是文字（不是 label），是一枚内容性的图形。若不给它一格，
 * 三处会各画一遍 —— 那正是下面「展开箭头」那段记录的病。
 *
 * ── 一个空着的格子会一直空着 ───────────────────────────────────────────
 *
 *   "展开箭头"从 M1 起就写在这份家族清单里，但直到 M15.1 才真正实现
 *   （chevronIndicator）。在它空着的那五个里程碑里，四个控件各自绕过了
 *   这个缺口：QSkinSelect 自绘三角、QSkinTable 打 "▾" / "▸" 字符、
 *   QSkinDatePicker 自绘折线、QSkinPagination 拿按钮文字打 "‹" / "›"。
 *
 *   同一个 affordance 四种画法，其中一种是字符 —— 而"图标不用字符"
 *   这条规矩，恰恰在同一批文件的文件头被重复申明了四次。
 *
 *   所以：**清单上写着的格子，要么实现它，要么别写它。**
 *   反复申明的规则被反复违反时，缺的不是自觉，是那个格子。
 *
 * ── 契约三条 ──────────────────────────────────────────────────────────
 *
 *   1. 每个插槽都是一个 Component。宿主控件用 Loader 实例化它，
 *      并通过 Binding 把自己的引用注入为 `control`。
 *
 *   2. 插槽**可以读**宿主控件的全部状态
 *      （hovered / pressed / checked / activeFocus / enabled / variant ...），
 *      但**不应该改**这些状态 —— 状态机是契约层的职责。
 *      一旦主题开始改状态，换肤就会开始改变行为，这套分层就白做了。
 *
 *   3. 插槽**不能**引入新的交互。插槽里不要放 MouseArea / Keys / Shortcut，
 *      否则键盘与无障碍语义就会分裂到 N 份实现里。
 *
 * ── 主题作者只需要做一件事 ────────────────────────────────────────────
 *
 *     Slots.install({
 *         buttonBackground: Component { Rectangle { ... } },
 *         buttonContent:    Component { ... },
 *         checkIndicator:   Component { ... }
 *     })
 *
 *     没提供的插槽保留 Basic 默认实现。
 ****************************************************************************/

pragma Singleton
import QtQuick 2.11
import "slots"

QtObject {
    id: root

    /* ══════════════════ Basic 默认实现 ══════════════════
     *
     * 单独保留一份初始值，是为了让 reset() 能取回它们。
     *
     * 两个 QML 的硬限制共同塑造了这里的写法，都值得记住：
     *
     *   1. 不能在 JavaScript 块内声明 `Component { }`。
     *      `Component { ... }` 是**对象声明**语法，只在对象树的声明位置有效。
     *      写进 reset() 函数体会让整个文件解析出错（qmllint 会报
     *      "declared as singleton in qmldir but missing pragma Singleton"
     *      这种看似毫不相干的错误），运行时调用也会失败。
     *
     *   2. 不能用嵌套 QtObject 收纳这些默认值。
     *      QtObject 没有 default property，往它里面放子对象会报
     *      "Cannot assign to non-existent default property"。
     *      （Foundation 的令牌文件因此改用 JS 对象，是同一个坑。）
     *
     * 所以默认值只能平铺在这里，reset() 只做纯 JS 赋值。
     */

    property Component basicButtonBackground: Component { BasicButtonBackground { } }

    /* 这里刻意**不**传 labelDelegate。
     * label 与 buttonContent 的组合关系交给宿主控件（QSkinButton）用 Binding 接线：
     *   · Slots.qml 是 QtObject，没有 default property，放不了 Loader
     *   · Component 内部引用外部 id 会被 qmllint 判为 Unqualified access
     *   · "谁需要用到 label"本来就只有宿主知道，接线放在宿主更合适 */
    property Component basicButtonContent:   Component { BasicButtonContent { } }

    property Component basicInputBackground: Component { BasicInputBackground { } }
    property Component basicCheckIndicator:  Component { BasicCheckIndicator { } }
    property Component basicSwitchIndicator: Component { BasicSwitchIndicator { } }

    /* 单选框的圆环与圆心（M20）。
     *
     * 它**没有**复用 checkIndicator，尽管两者尺寸、状态、令牌全都一样。
     * 差的是"选中时到底填哪一块"：复选框整块填满 + 反色勾，单选框的
     * 外圈有实心/描边两种画法 —— 而四家恰好 2 : 2 分成两派
     * （TDesign / Arco 实心，Ant / shadcn 描边，见各自的 slots/ 实现）。
     *
     * 判据用项目自己那条："尺寸/状态冲突才不复用" 在这里不够用，
     * 于是往下追了一层 —— 真正不共用的成本不是重复几行，是**耦合**：
     * 两者挤在一格里，任何一次"为了改单选框"的改动都会顺带改掉复选框。
     * 与 M4 把 switchIndicator / checkIndicator 分成两格同源。 */
    property Component basicRadioIndicator:  Component { BasicRadioIndicator { } }

    /* 开关（两态按钮）的底板（M20）。
     *
     * 也没有复用 buttonBackground —— 这次的理由不是"耦合"，而是
     * **`variant` 与 on/off 是两条正交的轴**：前者答"这是个什么按钮"，
     * 后者答"它现在是开还是关"。挤进同一个枚举，就再也表达不出
     * "主按钮变体的开关态"。证据与完整论证见
     * slots/BasicToggleBackground.qml 文件头（那里列了三条，
     * 每条都指得出五份已有实现里的具体一行）。 */
    property Component basicToggleBackground: Component { BasicToggleBackground { } }
    property Component basicSliderTrack:     Component { BasicSliderTrack { } }
    property Component basicProgressTrack:   Component { BasicProgressTrack { } }
    property Component basicBreadcrumbSeparator: Component { BasicBreadcrumbSeparator { } }
    property Component basicStepIndicator:   Component { BasicStepIndicator { } }
    property Component basicLabel:           Component { BasicLabel { } }

    /* 语义状态记号（M22）。
     *
     * 这是**第六个家族**的第一个成员 —— 前面五个（background / contentItem /
     * indicator / overlay / label）都答不了"一个按语义取形的记号"：
     * 它不属于任何控件的状态（所以不是 indicator），也不是文字（不是 label），
     * 而是一枚**内容性的图形**。三件（QSkinAlert / QSkinResult / QSkinAlertDialog）
     * 都要它，所以先有唯一的定义。
     *
     * 与 spinRing / radioIndicator 同一条判据：四家在**形态**上真有分歧
     * （实心圆盘 vs 描边圆环；warning 更是圆 vs 三角），令牌表达不了。
     * 完整论证见 slots/BasicStatusGlyph.qml 文件头。
     *
     * 但它与前几格有一处不同：**尺寸由宿主给**（跨 16~64 一个数量级），
     * 所以契约多了 `control.size`。 */
    property Component basicStatusGlyph:      Component { BasicStatusGlyph { } }

    /* 方向箭头（展开 / 折叠 / 翻页）。
     *
     * indicator 家族从 M1 起就写着「勾选框、开关轨道、**展开箭头**」，
     * 但这一格一直是空的 —— 于是 QSkinSelect 自绘三角、QSkinTable 打字符
     * "▾"、QSkinDatePicker 自绘折线、QSkinPagination 拿按钮文字打 "‹"。
     * 同一种记号四种画法，其中一种是字符。这里把它补齐。
     *
     * 为什么必须是插槽：项目规则「图标不用字符，用矢量画」只解决了
     * 一半 —— 还有「画成什么样」，而线宽 / 端点 / 尺寸恰恰因主题而异
     * （见四份主题实现）。差异属于主题，就不该在控件里硬编码。 */
    property Component basicChevronIndicator: Component { BasicChevronIndicator { } }

    /* 分段控制器的活动块（M23）。
     *
     * 没复用 tabIndicator（几何契约冲突：那一格被设计成"铺在一条窄带里的
     * 2px 线"，而活动块是整段项的整块底），也没复用 toggleBackground
     * （同一主题里"开关打开"与"分段选中"必须能同时取到不同样子 ——
     * 参照实现里前者是品牌色实心、后者是中性色抬起）。
     * 完整论证见 slots/BasicSegmentThumb.qml 文件头。 */
    property Component basicSegmentThumb:    Component { BasicSegmentThumb { } }

    /* 时间轴的圆点（M23）。
     *
     * 没复用 stepIndicator：状态词汇不通用（时间轴是语义色四档，不是
     * 进程语义的 finish/process/wait/error）、内容不同（步骤圆**必带数字**）、
     * 尺寸差一个量级（10 vs 24）。而一个页面可以同时有步骤条与时间轴，
     * 两者必须并存 —— 于是另开一格。见 slots/BasicTimelineDot.qml 文件头。 */
    property Component basicTimelineDot:     Component { BasicTimelineDot { } }

    /* 浮层的 Basic 实现。注意它们与别的插槽不同：
     * 只提供**外壳**，列表 / 文字等"行为"由宿主控件注入（见
     * BasicSelectOverlay.qml 文件头关于浮层为什么难拆的说明）。 */
    property Component basicSelectOverlay:   Component { BasicSelectOverlay { } }
    property Component basicTooltipOverlay:  Component { BasicTooltipOverlay { } }

    /* Tabs 的激活下划线（M4 契约回收）。它属于 indicator 家族：
     * TDesign 是 3px 圆角条、Ant/Arco 是 2px 细线、shadcn 用前景色 ——
     * 这类差异应该由主题回答，而不是在控件里硬编码。 */
    property Component basicTabIndicator:    Component { BasicTabIndicator { } }

    /* 加载指示器（M19 新增的**两个**成员，不是一格）。
     *
     * 为什么是两个：环形（一条描边）与点阵（N 个实心块）是两种**结构**，
     * 连"自然尺寸"的算法都不同。项目已有的判据是
     *     「尺寸要求冲突 → 不复用插槽；只差颜色/字重 → 复用」，
     * 所以它们必须分开 —— 与 M4 把 switchIndicator / checkIndicator
     * 分成两格是同一条判据。（完整论证见 QSkinSpin 的文件头。）
     *
     * 四家主题的覆盖情况本身就是"形态属于主题"的实证：
     *     TDesign   spinRing   一段 300° 的弧
     *     Ant       spinRing   四段 70° 的弧
     *     shadcn    spinRing   两段 120° 的弧（对角）
     *     Arco      spinDots   四个点整体旋转 + 各自明暗
     * 每家的弧长/段数/线宽规则都不同 —— 没有一条是令牌能表达的。 */
    property Component basicSpinRing:        Component { BasicSpinRing { } }
    property Component basicSpinDots:        Component { BasicSpinDots { } }

    /* ══════════════════ 当前生效的插槽 ══════════════════
     * 主题通过 install() 覆盖这里；reset() 从上面的 basic* 恢复。 */

    property Component buttonBackground: root.basicButtonBackground
    property Component buttonContent:    root.basicButtonContent
    property Component inputBackground:  root.basicInputBackground
    property Component checkIndicator:   root.basicCheckIndicator
    property Component switchIndicator:  root.basicSwitchIndicator
    property Component radioIndicator:   root.basicRadioIndicator
    property Component toggleBackground: root.basicToggleBackground
    property Component sliderTrack:      root.basicSliderTrack
    property Component progressTrack:    root.basicProgressTrack
    property Component breadcrumbSeparator: root.basicBreadcrumbSeparator
    property Component stepIndicator:    root.basicStepIndicator
    property Component tabIndicator:     root.basicTabIndicator
    property Component chevronIndicator: root.basicChevronIndicator
    property Component label:            root.basicLabel
    property Component statusGlyph:      root.basicStatusGlyph
    property Component segmentThumb:     root.basicSegmentThumb
    property Component timelineDot:      root.basicTimelineDot
    property Component spinRing:         root.basicSpinRing
    property Component spinDots:         root.basicSpinDots

    /* ══════════════════ 浮层 ══════════════════
     * 机制与上面完全一致，契约只是多了两条（见 slots/ 下各自的文件头）：
     *   · 浮层实例需提供 content 属性，用来接收宿主注入的内容
     *   · 浮层实例必须自己声明 implicitWidth / implicitHeight，
     *     宿主据此定 Popup 的尺寸 */

    property Component selectOverlay:    root.basicSelectOverlay
    property Component tooltipOverlay:   root.basicTooltipOverlay


    /* ══════════════════ 装载 ══════════════════ */

    /** 允许被 install() 覆盖的插槽名白名单 */
    readonly property var slotNames: [
        "buttonBackground", "buttonContent",
        "inputBackground",
        "checkIndicator", "switchIndicator", "radioIndicator",
        "toggleBackground",
        "sliderTrack", "progressTrack",
        "tabIndicator", "breadcrumbSeparator",
        "stepIndicator", "chevronIndicator",
        "label",
        "statusGlyph",
        "segmentThumb", "timelineDot",
        "spinRing", "spinDots",
        "selectOverlay", "tooltipOverlay"
    ]

    /**
     * install(set)
     * 只替换 set 里真正提供的插槽，其余保留当前实现。
     *
     * ── 为什么这里要**主动报**白名单外的键 ──────────────────────────────
     * 本函数是"按白名单过滤"的：不在 slotNames 里的键会被安静地丢掉。
     * 这个设计本身没问题（它让主题可以只提交自己关心的那几格），
     * 但它有一个**只在渲染时才看得见的**失败形态：
     *
     *     主题想装 spinRing，却把键名写成了 tdSpinRing
     *     → install 查 set["spinRing"] 得到 undefined → 这一格没换
     *     → 控件照样画出一圈弧（Basic 的那一圈），不报错、不警告、
     *       屏幕上"有个加载圈"，只是它不是这家主题的那一个。
     *
     * M19 实测踩到：四家主题的 spinRing / spinDots 全部因此没装上，
     * 而属性侧一切自洽（Slots.spinRing 非 null —— 它是 Basic）。
     * 抓出它的是"装上去的必须**不等于** Basic"这条断言，不是"非 null"。
     *
     * 所以这里对白名单外的键打一条 warn。它不改变装载语义（仍然忽略），
     * 只是把静默失败变成看得见的信号 —— 与项目那句
     * 「门禁必须能被证伪」同源：**静默通过是最危险的一种通过**。
     */
    function install(set) {
        if (!set) {
            console.warn("QSkin.Slots.install(): set is null")
            return
        }
        var names = root.slotNames
        var known = {}
        for (var i = 0; i < names.length; ++i) {
            var k = names[i]
            known[k] = true
            if (set[k] !== undefined && set[k] !== null)
                root[k] = set[k]
        }
        for (var key in set) {
            if (!known[key] && set[key] !== undefined && set[key] !== null)
                console.warn("QSkin.Slots.install(): 未知插槽名 '" + key
                             + "'，已忽略。合法名字见 Slots.slotNames。")
        }
    }

    /** 恢复 Basic 默认实现 */
    function reset() {
        root.buttonBackground = root.basicButtonBackground
        root.buttonContent    = root.basicButtonContent
        root.inputBackground  = root.basicInputBackground
        root.checkIndicator   = root.basicCheckIndicator
        root.switchIndicator  = root.basicSwitchIndicator
        root.radioIndicator   = root.basicRadioIndicator
        root.toggleBackground = root.basicToggleBackground
        root.sliderTrack      = root.basicSliderTrack
        root.progressTrack    = root.basicProgressTrack
        root.breadcrumbSeparator = root.basicBreadcrumbSeparator
        root.stepIndicator    = root.basicStepIndicator
        root.tabIndicator     = root.basicTabIndicator
        root.chevronIndicator = root.basicChevronIndicator
        root.label            = root.basicLabel
        root.statusGlyph      = root.basicStatusGlyph
        root.segmentThumb     = root.basicSegmentThumb
        root.timelineDot      = root.basicTimelineDot
        root.spinRing         = root.basicSpinRing
        root.spinDots         = root.basicSpinDots
        root.selectOverlay    = root.basicSelectOverlay
        root.tooltipOverlay   = root.basicTooltipOverlay
    }
}
