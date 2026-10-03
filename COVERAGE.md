# 覆盖度清单

> **目标**：Ant Design 6 / Arco Design / shadcn/ui 三家组件**并集**的 100% 覆盖。
>
> 本文是这件事唯一的**事实来源**。每落地一个控件就在此勾一次 ——
> 别在 issue、聊天记录、脑子里记第二份。
>
> **入列判据**：三家**任一**有 → 入列。只在一家有的也入列，但会标出来源，
> 因为"只有 shadcn 有"往往意味着它是**组合原语**而不是组件（见第六节）。

## 图例

| 记号 | 含义 |
|---|---|
| ✅ | 已落地，且四主题插槽齐备 |
| 🔶 | 部分落地（括号里写差在哪） |
| ⬜ | 待做 |
| ⛔ | **不列入**，理由写在第六节 |

---

## 现状

| 类别 | 已落地 | 待做 |
|---|---|---|
| 既有控件文件 | **92**（`src/contracts/QSkin*.qml`，含 `QSkinFormItem` / `QSkinSidebarItem` 两个配套件；不含 `Slots` 与 `TimeCell` 两个非控件件）| — |
| 三家并集总数 | — | 见下 |

> 复算：`ls src/contracts/QSkin*.qml | wc -l` → **92**。

**一句话现状**：**86 个控件** + 一批地基层原语（`Row`/`Column`/`Grid`/`Spacer`/
`ButtonBar`/`FocusRing`/`Heading`/`Body`/`Caption`/`Theme`/`Breakpoints`/
`OverlayStack`/`DateUtil`/`TreeUtil`/`QRCodeEncoder`/`ScrollUtil`/`FuzzyMatch`/
`MemberOrder`/`CornerUtil`/`MasonryUtil`）。

> 「86 个控件」的来处是组件表里 ✅ 的行数，复算命令在下面（读 **✅ 86**）。
> 它与文件数 92 之间的差仍然全部来自那两类：两个配套件
> （`QSkinFormItem` / `QSkinSidebarItem`）+ "一个控件两个文件"
> （`QSkinRadioGroup`、`QSkinToggleGroup`、`QSkinAvatarGroup`、`QSkinInputGroup`
> 的组与成员各占一个文件）。差额成员随批次变动，**别把这两个数当成一回事**
> —— 要精确对账就数文件，不要推。

### 还缺多少

**两个口径都已清零**：

- **待做批次件数 0** —— 第七节批次表里每一批都有 ✅；
- **组件表里的 ⬜ 0 行** —— 最后两行（`Link` / `Textarea 变体组` / `Typography` /
  `Statistic-Countdown`）已点亮。

往后「还缺多少」不再由 ⬜ 回答，而是由 `🔶` 里「哪些是终态、哪些还欠着」回答 ——
**当前所有 🔶 都是终态**（见第八节第 5 条）。

复算（在本目录跑，读 **✅ 86  🔶 2  ⬜ 0**）：

```bash
awk -F'|' 'NF>=7 && $2 !~ /^[[:space:]]*[-:]+[[:space:]]*$/ && $2 !~ /组件/ {
  q=$6; gsub(/^[[:space:]]+|[[:space:]]+$/,"",q);
  if (q ~ /^✅/) ok++; else if (q ~ /^🔶/) part++; else if (q ~ /^⬜/) todo++;
} END { printf "✅ %d  🔶 %d  ⬜ %d\n", ok, part, todo }' COVERAGE.md
```

> **凡是"约 X 项"这类数字，要么给出算法，要么别写。** 上面那条 `awk` 就是"算法"。

**库自产文案与本地化**：库自产的**用户可见**文案共 **120 条**，全部走
`qsTr`。翻译资产在 `i18n/`（`qskin_en.ts` 源 + `qskin_en.qm` 可直接加载），`en_US`
**120/120 全译**。不 i18n 的只有 **7 条**，逐条登记在 `tools/i18n-exempt.txt`
—— **那张表是「不翻」这件事的账目，不是漏做的清单**：7 条全属「开发者可见」
（`console.warn` 诊断、解析用字符集、算路层错误码）。

> 复算：`./tools/check-i18n.sh`（三道判据，位掩码 `0x00`；`./tools/lint.sh` 会带上）。
> 「装了 `.qm` 之后界面真的是英文」由 `tests/scene_i18n.qml` + `tools/check-i18n-runtime.sh`
> 守着，接在 `./tools/test.sh` 的 **3.11** 节 —— 它跑两遍（带 / 不带 `--translation`），
> 只跑正面那一遍是一道**不可证伪**的门。
> ⚠ **数字格式刻意不走本地化**：`qsTr` 翻不了数字格式，而机器 locale 会让同一份
> 代码在不同机器上给出不同结果（详见 `QSkinStatistic` 里的裁决与 README 第六节）。

---

## 一、通用与布局

| 组件 | Ant | Arco | shadcn | QSkin | 备注 |
|---|---|---|---|---|---|
| Button | ✅ | ✅ | ✅ | ✅ `QSkinButton` | |
| SplitButton / ButtonGroup | — | ✅ | ✅ | 🔶 `QSkinButtonGroup` | 按钮组已落地 —— 三态圆角走 `buttonBackground` 已有的插槽，新增的只是一个**读取字段** `groupPosition`。`SplitButton`（带下拉的分裂按钮）**未做**，且 **终态**：它要复用 `QSkinDropdown` 的触发与翻转，成本不低；没有消费者就不做，别顺手长第二份。⚠ 本行 🔶 自此表示**终态**，不表示欠账（与 `Icon` 同一套语义）|
| FloatButton | ✅ | — | — | ✅ `QSkinFloatButton` | 与 `QSkinBackTop` 共用浮球底板 `FloatPlate`（契约层内部件）；两件**不互相继承** —— 记号一个固定、一个走内容槽，出现时机一个看阈值、一个完全由宿主定 |
| Icon | ✅ | ✅ | — | 🔶 只有 `chevronIndicator` / `statusGlyph` 等**插槽**，无独立控件 | **终态声明：不做，而且不是"迟早要做"。** 图标在本仓是**宿主给的内容**（插槽），不是控件 —— 独立控件要引入一份与四家主题无关的图标字体资产，而 `Shape` / `Svg` 插槽已经能表达任意一枚。这个 🔶 的意思是**就停在这个粒度**，与 `SplitButton` 的 🔶 同义；见 README 第十节 |
| Typography | ✅ | ✅ | ✅ | ✅ `Heading` / `Body` / `Caption` / `Paragraph` | 新增 `Paragraph`：根类型是 `Body`，**不重定义任何排版**，唯一新增的能力是按行数截断（`maxLines` 必须 `maximumLineCount` + `elide` **一起给**，单给 `elide` 对折行文本无效）；`Body` 补四个**行内修饰**位 `strong` / `italic` / `underline` / `strike`（= 「Text 的组合写法」）。⚠ `maxLines <= 0` 的兜底只能靠**属性回读**守 —— Qt 把 `maximumLineCount: 0` 当"不限"，渲染侧分辨不出来 |
| Link | ✅ | ✅ | — | ✅ `QSkinLink` | 补上了一条契约缺口：label 侧新增 `underline` 三态（`auto` 跟随 hover / `always` / `never`），`QSkinLink` 只管"什么时候点得动、点什么"（`activate()` 单一出口 + `enabled` 检查 + `Accessible.Link` + 空格 / 回车）。**本件一个颜色字面量都没有** —— 取色全在四家 `*Label.qml` 的 `case "link"`（shadcn 是例外：它的 `--primary` 就是近黑 → 取 `fg`） |
| Divider / Separator | ✅ | ✅ | ✅ | ✅ `QSkinDivider` | 横/竖 · 三种对齐 · 虚线；账目恒等式由 `smoke_m18 [1]` 守 |
| Space | ✅ | ✅ | — | ✅ `Row`/`Column`/`Spacer` | |
| Grid | ✅ | ✅ | — | ✅ `QSkinGrid` | |
| Layout（Header/Sider/Content/Footer） | ✅ | ✅ | ✅ `Sidebar` | ✅ `QSkinLayout` | 侧栏折叠 + 顶栏由内容撑高 |
| Sidebar / Sider | ✅ | ✅ | ✅ | ✅ `QSkinSidebar` / `QSkinSidebarItem` | 与 `QSkinLayout.sider`（**布局空槽**：吃任意内容 + 一个折叠宽度）**不是同一个件** —— 另有分组 / 项 / 活动态，`side`、`variant`(sidebar\|floating\|inset)、`collapsible`(offcanvas\|icon\|none)；成员顺序按**声明序**（兄弟 `onCompleted` 是逆序的）。 |
| Splitter / Resizable | ✅ | ✅ | ✅ | ✅ `QSkinSplitter` | minSize 夹取 + 双击复位 |
| AspectRatio | — | — | ✅ | ✅ `QSkinAspectRatio` | 非法比例退化成 1:1 |
| ScrollArea | — | — | ✅ | ✅ `QSkinScrollArea` | 自绘滚动条；`policy` 的真实语义见 `_barVisible()` |
| Masonry | ✅ | — | — | ✅ `QSkinMasonry` | 分配算法下沉到 `QSkin.Foundation.MasonryUtil`（`.js` + 薄转发 `.qml`），并列时**取最左** —— 它不影响总高，只影响像素位置，正是"属性对但界面错"最喜欢的藏身处 |
| Kbd | — | — | ✅ | ✅ `QSkinKbd` | **不做成两件**：`keys` 收 `"Esc"` 或 `["Ctrl","K"]` 两种写法，走**同一份**绘制，没有"组合模式"分支。总宽可算 → 像素侧"键帽个数与总宽"能写等号 |

### 1.1 布局是一层「有损翻译」，不是一层等价封装

这一节单列出来，是因为**布局是本项目里唯一一处"抽象模型不同"、而不是
"件数不够"的差距**。控件缺口可以靠继续做消灭；
布局缺口**消灭不了**，只能管理 —— 所以必须把每一处翻译损失写清楚，
并且**逐条配门**。

| Web 语义 | QML 那侧实际是什么 | 损失在哪 | 门 |
|---|---|---|---|
| `gap` / `padding` | `spacing` / 内层 layout 的显式 `x`·`y` 与 `padding` 手算 | QSkin 封装**不让余量存在**：内层 layout 按内容收缩，除非有子项声明 `fillWidth` / `fillHeight` —— 于是 gap 就是 gap。⚠ **原生**容器不这样：Qt 会把余量分进间距，且两种原生容器的分配形状**不一样**（见下方实测表） | ✅ 两侧都已补：`smoke_layout_gap [0]`（Column）/ `[6]`（Row）+ 像素侧 `check-layout-pixels` |
| `justify-content` | `justify: "start" \| "center" \| "end"` | **已补上显式旋钮**（≈ `flex-start` / `center` / `flex-end`）：让内层 layout 收缩，再决定它在容器里的**落点**。仍然**没有** `space-between` / `around` / `evenly` —— Qt 的 fill 是**布尔量、没有权重**，`Layout.maximumWidth` 卡半份实测分配不均（八档探针量过）。也不处理**溢出**（`Row` 不换行） | ✅ `smoke_layout_justify [0]–[7]` + 像素侧 `check-layout-pixels`（23 条，变异 6/6） |
| `width: 100%` | `fill: true`（= `Layout.fillWidth`） | **`width: parent.width` 被静默忽略、不报错**。Layouts 拿 `implicitWidth` 当 size hint，显式 `width` 在布局里不作数。这个坑是抓图抓出来的 | ✅ `smoke_layout [0]–[7]` |
| `flex: 1` | `Spacer { }` | 得专门造一个类型（为了让业务代码不必 import `QtQuick.Layouts`），且**只在 QSkin 布局容器内有效** | ✅ `smoke_layout [2]`、`smoke_layout_gap [7]` |
| `repeat(auto-fit, minmax(N,1fr))` | `Grid { minChildWidth: N; fill: true }` | 列数是 **QSkin 自己算的**（`columnCount` 公式），Qt 不给 auto-fit | ✅ `smoke_layout_gap [3][4]` |
| 分数布局（`1fr`） | 逐枚取整 | `columnWidth` 是实数 **185.333**，落到子项是整数 **[185, 186, 185]** —— 余数塞给其中一格。好消息是 `Σ列宽 + Σgap` 精确填满 580，**无累积误差** | ✅ `smoke_layout_gap [3]` |
| 尺寸取整粒度 | 逐枚 `ceil` 再求和 | n 枚子项总宽误差可达 n/2。实测 `iw(["Ctrl","Esc"]) = 63`，而 `round` 逐枚 = 62、`ceil(Σ)` = 62 —— 只有 `ceil` 逐枚 = 63 | ✅ `smoke_m27`（一条恒等式同时否掉另两种实现） |
| 内容度量时序 | 无对应物 | Web 在 font swap 后**自动重排**；Qt 要子项**自己上报 implicit 尺寸**，否则布局**永不重跑**。`QSkinKbd` 的真缺陷就是这条：属性门禁与冒烟**全绿**，只有抓图能看见 | ✅ 像素核验 `[P1]` + 像素侧变异第一枪 |

**两种容器的余量分配形状不一样，别互相推**（实测）：

| | 落点 | 间隙 | 边缘 |
|---|---|---|---|
| 原生 `ColumnLayout`（400 高 / 3×32 / spacing 8） | 48 / 184 / 320 | 各 **104** | 上 **48**、下 **48**（≈ `space-around`：边缘半份、间隙整份） |
| `QSkinRow`（580 宽 / 3×40 / gap 8，无 fill 子项） | **0 / 48 / 96** | 各 **8**（= gap） | 余量 **444 全部留在末端**；`justify` 决定这 444 落在哪 |

QSkin 这一行不是推理出来的，是在**像素**上量出来的（`start` / `center` / `end` 三档的
组左沿分别 +0.0 / +222.0 / +444.0，间隙恒为 8.0）。同一张图上的原生 `RowLayout`
对照仍量到间隙 **156** —— 反证 Qt 的默认行为没变，变的是 QSkin 的封装。

## 二、导航

| 组件 | Ant | Arco | shadcn | QSkin | 备注 |
|---|---|---|---|---|---|
| Breadcrumb | ✅ | ✅ | ✅ | ✅ `QSkinBreadcrumb` | |
| Menu | ✅ | ✅ | ✅ | ✅ `QSkinMenu` | |
| Menubar | ✅ | ✅ | ✅ | ✅ `QSkinMenubar` | 与 `QSkinMenu`（**竖排浮层内容**：读 `model`、上下键导航）**不是同一个件** —— 另有水平模式、复选 / 单选项、子菜单、快捷键显示、左右键条目间移动。「条目条高度 = `itemHeight`」这一条**属性侧抓不到**（抽掉 `bar.height` 断言全绿），由像素门禁 `[P7]` 守。 |
| Pagination | ✅ | ✅ | ✅ | ✅ `QSkinPagination` | |
| Steps | ✅ | ✅ | — | ✅ `QSkinSteps` | |
| Tabs | ✅ | ✅ | ✅ | ✅ `QSkinTabs` | 导航条 · 补内容区（`contentDelegate` 默认 `null`，此时 `implicitHeight` 与旧版逐字相同 → 零回归）。 |
| Dropdown | ✅ | ✅ | ✅ | ✅ `QSkinDropdown` | 自带触发器 + 开合状态机；行语义委托给 `QSkinMenu` |
| ContextMenu | — | — | ✅ | ✅ `QSkinContextMenu` | 声明在目标容器里、撑满它；只吃右键、不吃 hover |
| Anchor | ✅ | ✅ | — | ✅ `QSkinAnchor` | 高亮与滚动**共用同一条算路**（判定抽成 `Foundation/ScrollUtil.sectionIndexAt` 纯函数）—— 「点到哪」与「高亮哪」不是两套逻辑 |
| Affix | ✅ | ✅ | — | ✅ `QSkinAffix` | 钉住 = 相对宿主算出一个**位移量**（`affixDeltaY`），**不改自己的 `y` 锚点**；`target` 为 null 时静默退化成普通块。`_itemY` 必须 `mapToItem(target.contentItem)`（内容坐标）—— 写成视口坐标会双重计数 |
| BackTop | — | ✅ | — | ✅ `QSkinBackTop` | 可见性阈值是**闭区间**（`>=`）；回到顶走 `clampScrollY(0, …)`，不给「静默滚到 0」留缝。底板**不走 `buttonBackground` 插槽** —— 那一格装不下（它的契约不读 `radius`，四家按钮圆角都不是圆）；本件直绘 + 令牌，那枚球抽成 `FloatPlate` 与 `QSkinFloatButton` 共用 |
| PageHeader | 🔶 已废弃 | ✅ | — | ✅ `QSkinPageHeader` | `hasTitleRow` 派生（返回键 / 标题 / 副标题 / 额外区**任一**有）；分割线是 `anchors.left/right: parent` 一条 1px。Ant 标记已废弃不改变 Arco 有它这件事 |
| NavigationMenu | — | — | ✅ | ✅ `QSkinNavigationMenu` | 站点导航条 + 子面板；面板外壳复用 `selectOverlay`（这一族不为面板新开格） |
| Command | — | — | ✅ | ✅ `QSkinCommand` | 模糊搜索**自研并下沉到** `Foundation/FuzzyMatch`（全整数打分、并列取最左、空查询不排序）；面板外壳复用 `selectOverlay`；`activated()` 拦 `enabled === false`。这份模糊匹配是**唯一不需要 Qt 的一层**，由 `tools/test.sh` 的 `[3.6]` 独立算路交叉验证 |

## 三、数据录入

| 组件 | Ant | Arco | shadcn | QSkin | 备注 |
|---|---|---|---|---|---|
| Input | ✅ | ✅ | ✅ | ✅ `QSkinInput` | 长出三个**插槽变体**（不开新控件）：`prefix` / `suffix`（Search = 前后缀各给一枚；图标一律**不内建**）、`echoMode` + `revealed`（Password）、`groupPosition`（成组，读 `QSkinInputGroup`）。⚠ **`implicitWidth` 恒 200 不变** —— 前后缀是从里面挤的，"没设前后缀 ⇒ 逐字不变"必须在数学上成立 |
| Textarea | ✅ | ✅ | ✅ | ✅ `QSkinTextarea` | 高 = 行数×行高 + 内距（+ 计数器条）；截断与计数是同一件事的两面；`editorText` 是那条不变量 |
| InputNumber | ✅ | ✅ | — | ✅ `QSkinInputNumber` | |
| Select | ✅ | ✅ | ✅ | ✅ `QSkinSelect` | |
| Checkbox | ✅ | ✅ | ✅ | ✅ `QSkinCheckBox` | |
| Radio / RadioGroup | ✅ | ✅ | ✅ | ✅ `QSkinRadio` / `QSkinRadioGroup` | 值由**组**保管、成员自己动；成员顺序按**声明序**排（兄弟 `onCompleted` 是逆序的） |
| Switch | ✅ | ✅ | ✅ | ✅ `QSkinSwitch` | |
| Slider | ✅ | ✅ | ✅ | ✅ `QSkinSlider` | |
| Rate | ✅ | ✅ | — | ✅ `QSkinRate` | `allowHalf` 改的是吸附**步长**；只读与可交互同形态 |
| DatePicker | ✅ | ✅ | ✅ | ✅ `QSkinDatePicker` | |
| TimePicker | ✅ | ✅ | — | ✅ `QSkinTimePicker` | |
| Calendar | ✅ | ✅ | ✅ | ✅ `QSkinCalendar` | **≠ DatePicker 面板**：它是常驻月历；`today` / `panelYear` + `panelMonth` **可注入**（"会自己变的控件没法做像素门禁"）；选中 = **实底**、今天 = **描边**、两者同时成立时实底优先 |
| Cascader | ✅ | ✅ | — | ✅ `QSkinCascader` | 多列面板，每列一个 `ListView`；列间展开走 `TreeUtil.columnsOf`。`value` 是**路径键数组**，路径里不存在的段就地截断（不崩、不补全）。不做多选（没有第二个设计系统背书）、展开只有 `click` 没有 `hover`（与键盘导航冲突）|
| TreeSelect | ✅ | ✅ | — | ✅ `QSkinTreeSelect` | 与 `QSkinCascader` 同批，但**共享的是 `TreeUtil` 的算路，不是缩进渲染**：Cascader 是多列、同列层级相同，没有缩进可画。缩进树那一份渲染归 `QSkinTree`，本件**直接复用其实例**。刻意**不给树的选择状态写绑定**（`QSkinTree._commitKeys` 会直接赋值打断绑定 —— 那是"用一会儿才坏"的 bug）|
| Transfer | ✅ | ✅ | — | ✅ `QSkinTransfer` | 唯一的对外值是 `targetKeys`；左栏 = `dataSource \ targetKeys`（**不是**独立数据）。行的勾选态**不进 model** —— 进了的话每次勾选都会重算数组 → 两栏整体重建 → 滚动位置丢失。裁剪：不做搜索框、不做"全部移动"按钮（理由见文件头）|
| Mentions | ✅ | ✅ | — | ✅ `QSkinMentions` | 与 `QSkinAutoComplete` 的判据只有一条：**选中候选之后，用户前面打的字还在不在**（在 → 本件）。上下键用 `Keys.priority: Keys.BeforeItem` 抢在 TextEdit 前面（否则面板开着时上下键会去移动光标）。`value` 是"插入过的项"，**不**从 `text` 反解 |
| AutoComplete / Combobox | ✅ | ✅ | ✅ | ✅ `QSkinAutoComplete` | 过滤走 `FuzzyMatch.filterBy`（本件是它的第二个消费者）。空查询给全量这件事**`filterBy` 自己就做了**（`score` 对空 query 返回 `{score:0,hits:[]}`，是对象 → 真值 → 全量进结果；判据在 `check-fuzzy-match.js` 第 149 行），控件里那一支是等价冗余，留着是为了把"空文本框展开就有得选"写在控件这一层。输入框是**自绘**的：QSkinInput 的 `text` 在"用户打过字之后"能否被程序化赋值尚未实测，而回填是本件的核心路径 |
| ColorPicker | ✅ | — | — | ✅ `QSkinColorPicker` | 色域面 / 色相条 / 色板是**控件自绘**（它们是"算法结果的显示"，不是主题差异 → 本件零新增插槽）。色相是**内部状态**、不从 `value` 反推 —— 反推会让"拖到 s=0 的纯白"时色相自己跳回 0°（`ColorUtil.js` 的量化误差表算了这笔）|
| Upload | ✅ | ✅ | — | ✅ `QSkinUpload` | **只能做交互壳**（见第七节的诚实说明）：状态机归控件、真实 IO 归宿主。契约是「一个信号 + 三个方法」：`uploadRequested(item)` / `pickerRequested()` 出去，`reportProgress` / `reportSuccess` / `reportFailure` 回来。**三处相等**：`addFiles()` 的返回值 == 收下的条数 == 发出的请求次数 == `count` 的增量（被拒的不进表、不占位、不发请求，只发一次 `rejected(item, reason)`，reason 为 `count\|dup\|type\|size`）。`success` / `error` 都**锁住**，只有 `retry()` 能离开 `error`；`totalProgress` 是逐条 progress 的算术平均（**零特殊分支**）。**零 IO、零平台依赖** —— 示例屏用一个假按钮就能演全套 |
| InputOTP | — | — | ✅ | ✅ `QSkinInputOTP` | 固定分隔符方框排版 → "第 i 格中心"可算（像素侧量得到同一个数）；总宽 = 6 格 + 6 缝 + 分隔符 |
| Textarea 变体 / InputGroup / Search / Password | ✅ | ✅ | ✅ | ✅ 插槽变体（+ `QSkinInputGroup`） | 按原判断执行：**拆成插槽变体，非新控件**。`QSkinInputGroup` 照 `QSkinButtonGroup` 的模子（`QQ.Row` + `positionOf`）。**裁剪如实记账**：不排间距、**不做"相邻边框合并"**（紧邻时中间是 **2px 同色线**；Ant 用负外边距 -1px 吃掉一道，本仓不做 —— 那要求容器知道成员的边框宽 = 跨层硬编码）、不做竖排 / RTL |
| Label | — | — | ✅ | ✅ `QSkinLabel` | 已抽成独立件；必填星标是 `Shape` 画的（不是字形）；尺寸走 `Layout.preferred*` |
| Toggle / ToggleGroup | — | — | ✅ | ✅ `QSkinToggle` / `QSkinToggleGroup` | off/on 与 `variant` 是**正交**的一条轴（新增 `toggleBackground` 插槽）；组可多选 |
| Form / FormItem | ✅ | ✅ | ✅ | ✅ `QSkinForm` / `QSkinFormItem` | |

## 四、数据展示

| 组件 | Ant | Arco | shadcn | QSkin | 备注 |
|---|---|---|---|---|---|
| Table / DataTable | ✅ | ✅ | ✅ | ✅ `QSkinTable` | 排序 / 分页 / 多选 / 树形 / 三区固定列已齐 |
| List | ✅ | ✅ | — | ✅ `QSkinList` | 四态互斥（头/尾/加载/空）+ 隔行底色 + 分割线只在条目之间 |
| Card | ✅ | ✅ | ✅ | ✅ `QSkinCard` | 头/体/尾三段派生 + 分割线条件 |
| Avatar | ✅ | ✅ | ✅ | ✅ `QSkinAvatar` / `QSkinAvatarGroup` | 圆/方/图片三形态；组 = 叠放步长（双向夹取）+ 溢出计数 + 边界环 |
| Badge | ✅ | ✅ | ✅ | ✅ `QSkinBadge` | |
| Tag | ✅ | ✅ | — | ✅ `QSkinTag` | |
| Empty | ✅ | ✅ | ✅ | ✅ `QSkinEmpty` | 内置图/自定义图二选一；各控件内置的 `emptyText` 仍在，这个件是给宿主复用的 |
| Collapse / Accordion | ✅ | ✅ | ✅ | ✅ `QSkinCollapse` / `QSkinCollapseItem` | shadcn 拆成 Collapse + Collapsible —— 本仓并成 `Collapse`（容器）+ `CollapseItem`（一块）两件；`accordion` 收敛**留最后一个**（`_enforceAccordion`）；箭头复用 `chevronIndicator` 插槽（**展开语义不进插槽**） |
| Carousel | ✅ | ✅ | ✅ | ✅ `QSkinCarousel` | 轨道 + 指示点；`autoplay` **缺省 false**（抓图要确定性、桌面端不该默认动）；箭头复用 `chevronIndicator`（读 `direction`，不读"上/下页"） |
| Calendar | ✅ | ✅ | ✅ | ✅ `QSkinCalendar` | 见"数据录入" |
| Image | ✅ | ✅ | — | ✅ `QSkinImage` | 四态（empty / loading / ready / error）；圆角遮罩走 `layer` + `MultiEffect` —— `masked` 是 **`layer` 的事**，离屏 runner 里与真实窗口不一定同值，所以"圆角真的遮住了"归抓图的像素核验；预览是**模态**，不进 `OverlayStack` |
| Descriptions | ✅ | ✅ | — | ✅ `QSkinDescriptions` / `QSkinDescriptionsItem` | `layout`(horizontal/vertical) × `bordered` 是**两个正交开关**；标签列共享统一宽度（只在同一列的上下两行之间才可观察）；**底纹格必须从单元格左边界起** —— 这条属性侧结构上抓不到，是**像素核验**抓出来的真缺陷 |
| Statistic / Countdown | ✅ | ✅ | — | ✅ `QSkinStatistic` / `QSkinCountdown` | `QSkinStatistic`（唯一格式化入口 `formatValue` —— 纯函数，冒烟直接打全谱；三档语义色走令牌）；`QSkinCountdown` 同批落地。它**必须可注入 `now`**（哨兵 `-1` = 走内部时钟，给值即**冻结**）—— 否则"会自己变"就没法做像素门禁（`QSkinCalendar` 先例）。到期事件**只发一次**：handler 里**只读刚刚变了的那个值**（读派生属性 `done` 会拿到上一次的值 → 事件永不发） |
| Segmented | ✅ | — | — | ✅ `QSkinSegmented` | 活动块**只有一个实例**、由宿主摆到当前段的**实际盒子**上（不是等分公式 —— 段宽按文字量）；新开插槽 `segmentThumb`，**不复用** `tabIndicator` / `toggleBackground`（理由见 `slots/BasicSegmentThumb.qml` 文件头） |
| Timeline | ✅ | ✅ | — | ✅ `QSkinTimeline` / `QSkinTimelineItem` | 新开插槽 `timelineDot`（四家都**不**覆盖：形态一致、差异全在令牌色上）；**末点空心**、其余实心；上/下段线只在 `!first` / `!last` 时可见 |
| Tooltip | ✅ | ✅ | ✅ | ✅ `QSkinTooltip` | |
| Popover | ✅ | ✅ | ✅ | ✅ `QSkinPopover` | **浮层基座**：Popconfirm / HoverCard 都基于它；面板外壳复用 `selectOverlay`（不为这一族新开格） |
| HoverCard | — | — | ✅ | ✅ `QSkinHoverCard` | `exclusive: false` —— 悬停类不该顶掉用户刚点开的东西 |
| QRCode | ✅ | — | — | ✅ `QSkinQRCode` | 编码器**自带**（字节模式 UTF-8 + RS 纠错 + 8 个掩码按罚分择优，见 `foundation/QRCodeEncoder.qml`）；本批**唯一不含自证**的判据是"把码扫出来"（`zxing-cpp` 回读，与编码器无共享代码）；底板 `#FFFFFF` **刻意不走令牌**（深色主题的 fg 会把对比度压到扫不出来） |
| Tour | ✅ | — | — | ✅ `QSkinTour` | 挖洞 = **四块遮罩矩形**（不是 ShaderEffect —— 理由见 `QSkinTour` 文件头）；面板按"洞下方放得下"自动翻转；`modal: true` ⟹ 整屏另有一层样式默认遮罩（实测 18/255 ≈ 7%，所以洞里也不是逐位等于原色） |
| Tree | ✅ | ✅ | — | ✅ `QSkinTree` | |
| Comment | 🔶 已废弃 | ✅ | — | ✅ `QSkinComment` | 嵌套 = 把子评论放进上一条的**默认子项**并给 `indent`（Ant 标记已废弃不改变 Arco 有它这件事） |
| Skeleton | ✅ | ✅ | ✅ | ✅ `QSkinSkeleton` | 图片落位表 + 文字行数 + **末行更短** |
| Spin / Spinner | ✅ | ✅ | ✅ | ✅ `QSkinSpin` | 三档 16/24/32 + `inheritColor`；新增 `spinRing`/`spinDots` 两格插槽（四家覆盖矩阵刻意不对称） |

## 五、反馈

| 组件 | Ant | Arco | shadcn | QSkin | 备注 |
|---|---|---|---|---|---|
| Alert | ✅ | ✅ | ✅ | ✅ `QSkinAlert` | 四条语义一行一色（实心左竖条）；左侧记号走新插槽 `statusGlyph`，**尺寸由宿主给** |
| Message | ✅ | ✅ | ✅ `sonner` | ✅ `QSkinToast` | 语义已覆盖 |
| Notification | ✅ | ✅ | — | ✅ `QSkinNotification` | 右上角带标题的通知卡；浮层家族里唯一**不走 Popup** 的成员 |
| Modal / Dialog | ✅ | ✅ | ✅ | ✅ `QSkinDialog` | |
| AlertDialog | — | — | ✅ | ✅ `QSkinAlertDialog` | 是**预设**不是新控件 ——包一层 `QSkinDialog`，加标题/正文/两出口；默认钮是 danger 变体 |
| Drawer / Sheet | ✅ | ✅ | ✅ | ✅ `QSkinDrawer` | |
| Popconfirm | ✅ | ✅ | — | ✅ `QSkinPopconfirm` | 两条出口都「关面板 + 发信号」；`stackWhenNarrow: false`（气泡面板窄，堆叠行为只会帮倒忙） |
| Progress | ✅ | ✅ | ✅ | ✅ `QSkinProgress` | |
| Result | ✅ | ✅ | — | ✅ `QSkinResult` | 同一枚记号放大到 64px（跨了一个数量级）；`glyphSize` 是「记号与状态码**共用**的视觉盒子」，所以 404 ↔ success 切换时整页不跳高 |
| Watermark | ✅ | — | — | ✅ `QSkinWatermark` | 纯绘制件，判据在**像素**侧：文字按固定倾角、固定步长平铺。**平铺几何可算** → 走自校准（对按公式算出来的格点断言"有墨"、对格点中点断言"没墨"），一条判据同时否掉"步长写错"与"只画一枚"。裁剪：不做图片水印、不做防篡改（那是 Web 的 `MutationObserver`，QML 里没有对应物） |

---

## 六、**不列入**的项（附理由）

| 项 | 来源 | 不做的理由 |
|---|---|---|
| Chart | shadcn | 图表库（recharts 封装），不是控件库该造的东西 |
| Direction | shadcn | RTL 方向控制。**不做的理由有三条**：① 镜像动的是**布局方向**，不是文案 —— 每个控件的定位与图标朝向都要跟着翻，属结构级改动；② 本仓两道**像素门禁的坐标系是从左往右**扫的（布局门从左边界往外扫、底板门判「哪一角是圆的」），镜像会同时废掉这两道门的判据，要做就得先给门加一维；③ 0.0.1 的翻译资产只提供 `en_US`，RTL 语言当前**没有消费者**（项目一贯的入列判据） |
| ConfigProvider | Ant / Arco | **已由 `Theme` 覆盖**（`Slots.install()` 就是它的等价物） |
| App / Util | Ant | 框架级包装（路由上下文、全局 message 容器），无 QML 对应物 |
| BorderBeam | Ant | 装饰性 effect，非组件 |
| Field / Item / Marker | shadcn | React 的**组合原语**（给 form/list 用的空壳 div），QML 里由控件内部承担 |
| Bubble / Attachment / MessageScroller | shadcn | 新的「AI 会话」实验件，当前无消费者 |
| Questionnaire | shadcn | 实验件，无消费者 |

> 这一档的判断依据是项目一直在用的那条：**没有消费者就不做** —— 「只要出现第二个消费者，它现在能跑就不再是理由」，反过来读同样成立。

---

## 七、落地批次（历史）

> 本清单按**族**分批落地，每批 3~8 件，同族共享验证方法（一次抓图脚本覆盖一批）。
> 这一节只回答「**哪一批落了什么、几件**」，作为上方各行的来路。
>
> 每批的裁决过程、收口读数、变异枪单与踩坑记录属于**开发过程**，且大量引用只
> 存在于开发机上的临时件 —— 因此**不在本文件里**。本文件只留**结论**。

| 批次 | 落地内容 | 件数 |
|---|---|---|
| **M18** | Divider / AspectRatio / ScrollArea / Card / Layout / Splitter | 6 |
| **M19** | List / Avatar / AvatarGroup / Empty / Skeleton / Spin | 6 |
| **M20** | Radio / RadioGroup / Textarea / Label / Rate / InputOTP / Toggle / ToggleGroup | 8 |
| **M21** | Popover / Popconfirm / HoverCard / Dropdown / ContextMenu / Notification | 6 |
| **M22** | Alert / Result / AlertDialog 预设 | 3 |
| **M23** | Collapse / Collapsible / Carousel / Segmented / Timeline | 5 |
| **M24** | Descriptions / Statistic / Image / QRCode / Calendar / Comment / Tour | 7 |
| **M25** | Anchor / Affix / BackTop / PageHeader / Command / NavigationMenu / Menubar / Sidebar | 8 |
| **M26** | TreeSelect / Tabs 内容区 / Cascader / Transfer / Mentions / AutoComplete / ColorPicker | 7 |
| **M27** | Upload（交互壳） / Watermark / Masonry / Kbd / FloatButton / ButtonGroup | 6 |
| **M30** | Link / Textarea 变体组 / Typography 变体 / Countdown | 4 |

两条与读者有关的次序约束：**M18 先行** —— Divider / Card / Layout 是被后续批次
反复复用的原子，Popover 是浮层家族的基座；**同族连做** —— 抓图、变异、断言写法
在一族里高度复用。

> **关于 Upload 的诚实说明**：纯 QML 做不出真实传输。`QSkinUpload` 交付的是
> 「选择 → 列表 → 单件进度 → 失败重试 → 移除」这套**交互壳**，真实 IO 由宿主注入。
> 契约见上方表格里 Upload 那一行。

---

## 八、维护约定

1. **一个控件落地 → 本文件对应行改 ✅**，并在行尾补上它验证了什么。
2. **新增控件必须同时进 `tests/` 与 `examples/`**（项目既有规矩）。
3. 门禁三件套（`lint.sh` / `test.sh` / 像素核验）在批内统一跑，不按件跑。
4. 若某行判断变了（例如新证据表明某项该做 / 不该做），**改本文件并写理由**，
   不要只在对话里说。
5. **🔶 有两种含义，必须写明是哪一种**：
   · **欠账** —— 还会做，括号里写差在哪；
   · **终态** —— **就停在这个粒度**，不打算再做（括号里写"就停在这里"）。
   到目前为止 🔶 全部是**终态**（`SplitButton / ButtonGroup`、`Icon`）。
   不写清楚的话，读者会默认它是欠账 —— 而"迟早要做"的错觉正是 0.0.1 之后
   最容易被重新捡起来当需求的东西。
