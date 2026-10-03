# 更新日志

本项目是 **Qt Quick 的跨设计语言组件库**（Quick Design System）：
一套契约层，四套设计语言（TDesign / Ant Design / Arco Design / shadcn）各自实现。

版本号遵循[语义化版本](https://semver.org/lang/zh-CN/)，写法参考
[Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

> **0.0.1 不承诺 API 稳定** —— 它是「第一个可以被外部评估的快照」，不是功能完整版。
> 对外的承诺只有三条：**能装**（照文档走一遍，不用读源码就能让一个窗口显示出来）、
> **能信**（每一件都有门在守，且**门自己能被证伪**）、**边界清楚**（做不了的写在明处）。
> API 稳定是 0.1.0 之后的事 —— 版本号里那两个 0 就是说这个的。

---

## 0.0.1 - 2026-10-01

### Qt 5 双轨：PyQt5 / PySide6 / C++ 三条线（本轮新增）

`src/` 仍是唯一事实源（Qt 6.8+ 写法）。新增 Qt 5 侧源码树 `qt5/`，由
`tools/qml-downgrade.py --profile qt515` 生成（197 文件），每条规则带预期
命中数、跑不对照就红。

- **新增** `examples/hosts/pyqt5/main.py` —— Python 侧在 Qt 5 下的宿主。
  实测 PyQt5 5.15.11 / Qt 5.15.2：可解析 105/105、可裸实例化 103/103、
  单例 17/17，与 Qt 6 侧数字一致。

**宿主对账从「三宿主」扩到「五宿主」，两条线全部实测（本轮）：**

- `tools/check-host-parity.py`：`qml` / `cpp` / `pyside6`（Qt 6，跑 `src/`）
  + `pyqt5` / `cpp-qt5`（Qt 5，跑 `qt5/`）。两个 Python 线的解释器可分别用
  `QSkin_PYSIDE6_PYTHON` / `QSkin_PYQT5_PYTHON` 指定；缺任一个报**工装错误 8**，
  不静默跳过。
- Qt 5 侧**参与契约对账**（数字必须与 Qt 6 侧同口径，否则位掩码 2），
  **不参与像素对账** —— Qt 5 与 Qt 6 渲染本就不可能逐像素相同，算进去
  只是个永远红的假判据。
- 证伪：在 `qt5/` 里加一个不存在的类型 → 门报 RC=3（位 1 + 位 2），
  精确列出 13 个受牵连类型。
- **C++ Qt 5 不再是「未实测」**：改用 MinGW 构建（Qt 5.15.2 的 `mingw81_64`
  变体 + 项目内 `.qt/Tools/mingw1310_64` 的 g++ 13.1），实测
  105/105 · 103/103 · 17/17，与其余四个宿主数字一致。原先走 MSVC 是因为
  默认变体是 msvc2019，而本机只有 VS2022 BuildTools（无完整工具链）。

**删除 `qt511` 档（Qt 5.11.3 兜底）：**

- 一并删除只服务它的 `PATCHES` 表、`CONNECTIONS_PATCH`、`CONTEXT_REQUIRED`
  与 R2/R3/R4/R5 四条降级分支（共约 8.5k 字符死代码）。
- 理由：5.11 官方分发不带 `QtQuick.Shapes`（Tech Preview 未构建），
  34 文件 233 处 Shape 要另写一套；而 PyQt5 自带 5.15，没有真实目标机需要
  这一档。留着它只会让「到底支持哪个 Qt 5」说不清。
- 生成器现在只有 `qt515` 一档，`--profile qt511` 会被 argparse 直接拒绝。

**像素对账的两个真 bug（都是「门绿得没道理 / 红得没道理」）：**

- **`--host-tag` 撞车**：Qt 5 那份 C++ 宿主与 Qt 6 那份共用 `main.cpp`，
  默认 tag 都是 `cpp`，于是后跑的 Qt 5 宿主把 Qt 6 的
  `host_parity_cpp.png` **覆盖**了 —— 像素对账拿着一张 Qt 5 的图去和
  qml / pyside6 比，报出 4804 像素的差异。图是真的、差异是真的，
  只是**比错了对象**。现在门里对每个宿主显式传 tag。
- **抓图尺寸不确定**：`grabToImage` 的实际像素会乘 `devicePixelRatio`，
  而 DPR 随会话漂（同一份 C++ 宿主两次跑出 1350x930 与 900x620）。
  钉 `windows:dpiawareness=1` 偶发失效、`=0` 会让 C++ 宿主与 qml 出现
  **内容级**错位；最终统一用 **`QT_QPA_PLATFORM=offscreen`** —— 不建真窗口、
  不看屏幕，Qt 5 / Qt 6 五个宿主都能起，三宿主实测逐像素零差异。
- 「某个宿主没抓图」不再靠删旧图来暴露（删文件会被宿主的批量删除保护拦），
  改为比对 **mtime 是否晚于本轮起始时刻**，没更新就报工装错误。

**新增 Qt 5 产物漂移门（lint 第 15 段）：**

- `qt5/` 是**入库的生成物**。`src/` 改一行却不重跑生成器，它会悄悄陈旧 ——
  而 lint 照样全绿（它扫的是 `src/`），生成器自带的「规则命中数对账」
  也照样全 OK（那些数字只证明规则按预期命中，证明不了产物是最新的）。
- `tools/check-qt5-drift.sh` → `qml-downgrade.py --check`：**不落盘**，
  把当前 `src/` 的降级结果在内存里与入库产物逐文件比 sha256，
  新增 / 残留 / 内容不同都红（退出码 3）。
- 证伪：在 `src/contracts/QSkinButton.qml` 追加一行注释 → 门报 RC=3。
- ⚠ 早期版本是「生成到 `qt5.tmpgen` 再 rmtree」，在门禁里跑会被宿主的
  批量删除保护拦下（985 项需人工确认）→ 门变成永远红。改内存比对后
  零写入、零删除。
- **新增** `examples/hosts/cpp-qt5/` —— C++ 侧 Qt 5 宿主（与 Qt 6 版共用
  `main.cpp`，只有 CMake 不同）。
- **为何 Qt 5 目标定在 5.15 而非 5.11**：PyQt5 的 wheel 自带 Qt 5.15.2，
  而 5.15 已具备 `required property` / Pointer Handlers / `QtQuick.Shapes`。
  定 5.15 后降级仅为 6 类机械改写；定 5.11 需另重写 69 处 `required property`
  与 34 文件 233 处 `Shape`。

**新增 `tools/setup-hosts.sh` —— 环境体检 / 一键补齐（把「必跑五宿主」的代价收成一条命令）：**

- 门禁默认必跑五个宿主、缺依赖报**工装错误 8**（不静默跳过），代价是**干净
  机器第一次跑门禁一定是红的**，而红的原因与库毫无关系。此前「怎么补齐」只是
  README 一句话加几个 `--skip-*` 参数 —— 后者更危险：跳过即这一层没在防任何东西。
- `--check` 只体检，逐项列出缺什么，**退出码 = 缺失项数**（0 = 齐）；不带参数
  则缺什么装什么（PySide6 / PyQt5 / Qt 5 SDK / 两个 C++ 宿主），已齐的项跳过。
- ⚠ 绑定探测**复用门自己的 `find_python_with_*`**，不另写一句
  `python -c "import X"`：两个绑定常装在不同环境（本机 PySide6 在
  `.cache/pyhost-venv`、PyQt5 在托管 venv），只查当前解释器会把「装了」报成
  「缺失」 —— 体检假阳性一次，就再没人信它了。
- 门里 **5 处**工装报错现在都指向这条命令，而不是只说「缺 PyQt5」。
- 证伪：`QSkin_PYTHON=/nonexistent/python ./tools/setup-hosts.sh --check`
  → 精确报 3 项缺失、RC=3；本机实跑 → 7 项全齐、RC=0。

**修 `.gitignore` 一直没生效（首次提交前才发现，差点把 5 万个文件提交进去）：**

- 三条规则写成 `.qt/    # 说明` —— Git 的 `.gitignore` **不支持行尾注释**，
  整行（连 `# 说明` 一起）被当成一个模式 ⇒ 该条**完全失效**。文件一直在那儿，
  却一次都没起过作用。
- 实测后果：`git add -A` 待入库 **50402** 个文件，含 1.8 G 的 `.qt/`、
  20934 个 `.cache/` 中间产物、1114 个 `build/`。
- 修复：注释改为独占一行，并补 `qt5_probe/`（二分排查的遗留目录）与
  `__pycache__/`。复核命令 `git status --porcelain | wc -l` → **547**
  （顶层：src 197 / qt5 197 / tools 54 / tests 54 / examples 35）。
- 订正 README 的过期读数：qmllint 扫描面 **260 → 261**（`find src examples
  tests -name '*.qml' | wc -l`）。

**修掉的两个跨版本真缺陷（Qt 6 静默、Qt 5 才暴露）：**

- `QSkinTimePicker` / `QSkinDatePicker` 用了 `Window.window` 却没
  `import QtQuick.Window`（Qt 6 容忍，Qt 5 报 ReferenceError）。
- `QSkinColorPicker` 把 `swatchRing()` 返回的对象当 hex 字符串用（4 处），
  Qt 6 下**预设色块颜色根本没生效**，只是不报错。改为 `.hex` 后正常。

### 里程碑总表（M0–M34）

**先定地基与契约，再做主题与控件** —— 顺序不能反：地基没定就做主题，等于把布局语义
写死在某个设计语言里，第二套主题必然推倒重来；契约层没定就做控件，等于把逻辑复制 N 份。

| 里程碑 | 内容 |
|---|---|
| M0 | 地基层：Layout / Spacing / Typography / Breakpoints / Focus / 按钮布局 / 默认令牌 |
| M1 | 契约层：五个插槽 + Button / Input / Checkbox / Switch / Select / Tooltip |
| M2 | 首发主题：TDesign for Qt Quick（1 份 token + 6 个插槽实现） |
| M3 | 主题矩阵：Ant Design / Arco Design / shadcn 并行，反向验证契约层够不够用 |
| M4 | 契约回收：浮层 `extender` 上报、`tabIndicator` 插槽、`QSkinTabs` / `QSkinMenu` |
| M5 | 控件扩充：`QSkinTable`、浮层 `contentHeight` 上报、label header 变体 |
| M6 | 表格行为：列排序（内置比较器 + `sortChanged`）、多选、首列 checkbox |
| M7 | 分页：`QSkinPagination`（页码窗口 + 省略号）+ 表格客户端分页 + 跨页勾选跟数据 |
| M8 | 反馈三件套 + Form：Dialog / Drawer（零新插槽）/ Toast 队列 / Form 校验 |
| M9 | 取值控件：`QSkinSlider` / `QSkinInputNumber`；ButtonBar self-width 死锁修复 |
| M9.x | ButtonBar 结案：三层病因定位 + 哨兵 + `smoke_buttonbar.qml` |
| M10 | 导航 + 状态标识：Progress / Tag / Badge / Breadcrumb / Steps |
| M11 | 浮层选择类：`DateUtil` + DatePicker / TimePicker（**零新增插槽**） |
| M12 | 列宽可拖：三档优先级 + 拖拽即快照 + 双击自适应 |
| M13 | 横滚 + 左固定列：`contentWidth` + `fixedColumns` 双区 |
| M14 | 树形展开：`treeMode`，折叠整枝剪掉、排序只作用于同级 |
| M15 | 树形键勾选：`selectedKeys` / `indeterminateKeys` / `checkStrictly` |
| M15.1 | 图标归位：补上 `chevronIndicator` 插槽 + `QSkinButton.icon`；字符图标清零 |
| M16 | 右侧固定列：双区扩成三区；坐标分「内容侧 / 屏幕侧」两个概念 |
| M17 | 树逻辑下沉：`QSkin.Foundation.TreeUtil` + 一维树 `QSkinTree`（与表格共用同一份实现） |
| M18 | 布局与容器原子：Divider / AspectRatio / ScrollArea / Card / Layout / Splitter（另附 M18.1 divider 令牌可见性） |
| M19 | 数据展示类：List / Avatar / AvatarGroup / Empty / Skeleton / Spin（另附 M19.1 四家主题 `install` 键名修复） |
| M20 | 表单选择类：Radio / RadioGroup / Toggle / ToggleGroup / Textarea / Label / Rate / InputOTP |
| M21 | 浮层家族：Popover / Popconfirm / HoverCard / Dropdown / ContextMenu / Notification（+ `OverlayStack` 单例） |
| M22 | Alert / Result / AlertDialog 预设（+ 第六族插槽 `statusGlyph`） |
| M23 | Collapse / CollapseItem / Carousel / Segmented / Timeline（+ `segmentThumb` / `timelineDot`） |
| M24 | Descriptions / Statistic / Image / QRCode / Calendar / Comment / Tour |
| M25 | Anchor / Affix / BackTop / PageHeader / Command / NavigationMenu / Menubar / Sidebar（+ `ScrollUtil` / `FuzzyMatch`） |
| M26 | TreeSelect / Tabs 内容区 / Cascader / Transfer / Mentions / AutoComplete / ColorPicker（+ `ColorUtil`） |
| M27 | Upload（交互壳） / Watermark / Masonry / Kbd / FloatButton / ButtonGroup（+ 内部件 `FloatPlate`） |
| M28 | 发布形态试跑：官方 CMake 构建路径修好，构建清单 191 条路径与实际一致 |
| M29 | 布局层专项 + 类型名别名重构：默认分配改 `flex-start`、`justify` 三档旋钮、别名改单名注册 |
| M30 | 查缺补漏：Link / Textarea 变体组 / Typography 变体 / Countdown 落地；`SplitButton` 与独立 `Icon` 裁决为**不做 / 终态** |
| M31 | 门禁补强：① M30 绘制面像素门 ② 第十二道门（运行期警告）上线 + 逐处清噪声 |
| M32 | 发布收口：版本号单点定为 `0.0.1`、`CHANGELOG.md` 建档、示例整理（22 个演示屏归位 `examples/showcase/` + 新增「三分钟上手」`HelloQSkin.qml`） |
| M33 | 文案与本地化：i18n 门禁（第十二道）+ 运行期翻译门、格式本地化、`i18n/qds_en.ts` **120/120** 全译 |
| M34 | 文档发布面收口：发布面泄露门禁（第十三道）、四份发布面文档瘦身（实现机制整段搬去 `docs/PITFALLS.md`） |

### M32 · 发布收口与示例整理

**示例整理**

- 新增 **`examples/HelloQSkin.qml`**（"三分钟上手"）：一个文件、只依赖文档里出现过
  的 API、能直接用 `qml` 跑起来 —— 它同时是发布准入条件 B 的判据。
- 原先 26 个按里程碑命名的演示屏，保留 4 个门面（`HelloThemes` /
  `HelloContracts` / `HelloFoundation` / `HelloIcons`），其余 **22 个**移入
  `examples/showcase/`。移动时同步修补了 `../.cache/` / `assets/` 等相对路径 ——
  它们**相对本 QML 文件**解析，下沉一层后不改，抓图会落进一个没人看的目录。

**顺手修掉的三个真缺陷（都是"文档写了个不存在的东西"）**

1. README「在你的项目里用」的代码片段**整段跑不起来**：写的是
   `Column { gap: … }` / `Grid { minChildWidth: … }`，而本仓注册的是
   `QSkinColumn` / `QSkinGrid`（裸名落到 QtQuick positioner，只有 `spacing`），
   且缺 `import QtQuick`。
2. **`TDesignTheme` 这个类型根本不存在**（真名单例是 `TDesign`）—— README 3 处
   与 `src/foundation/Theme.qml` 注释 1 处已订正。
3. **`tools/run.sh` 承诺了第二参数却从未实现**：`$2` 在本文件里一次都没出现过，
   `./tools/run.sh HelloM8 tdesign` 静默什么都不做（换肤无效，也不报错）。
   现已实现 `theme=<名>` 透传。

**顺手修掉的门禁假红**（记它是因为"假阳性会让下一次没人信这道闸"）：
`tools/check-build-manifest.py` 的解析是**全文正则、不认注释**，在版本说明注释里
提了一次 `qt_add_qml_module` 就被当成第 7 个模块块，而清单本身一个字都没错。

> ⚠ **`qt_add_qml_module(... VERSION 1.0 ...)` 里的 `1.0` 是 QML 模块导入版本**
> （`import QSkin.Foundation 1.0`），**与项目版本无关** —— 不要"统一版本号"，
> 改它会断 39 处 import。

### M33 · 文案与本地化

**契约变更（单列 —— 这是对 `error` 字段的破坏性变更）**

- **`QRCodeEncoder.encode()` 的失败返回**新增 `code` + `params`；`error` 从
  **中文用户文案**降为 **ASCII 诊断串**。原因：算路层住在 `foundation/`，那一层要能在
  **node 下裸跑** —— 里面不能出现 `qsTr`，所以**用户文案只能落在控件层**。
- **`QSkinQRCode` 新增只读 `errorCode`**，`errorText` 改为**按码 `qsTr` 翻译**。
  非破坏性的部分：`ok` / `status` 的语义与取值**一个都没动**。

⚠ 这是**对 `error` 字段的破坏性变更**（语种与形状都变了）。0.0.1 明确「不承诺 API 稳定」，
故只登记、不做兼容层 —— 仓内该字段的消费者本来就**只有 `QSkinQRCode.qml` 一处**。

### M33-6 · 格式本地化

**新增（非破坏性）**

- **`DateUtil` 新增只读 `amPmLabels`** —— `formatTime(t, "…A")` 的 12 小时制上/下午
  标记，默认 `["上午", "下午"]`。提出来是为了让「上午/下午怎么写」与「时间怎么算」
  分开 —— 与 `QSkinStatistic` 把格式化抽成 `formatValue()` 是同一个手法。
- **`DateUtil.weekdayLabels` / `monthLabels` 的默认值改走 `qsTr`** —— 类型与形状不变
  （仍是 `readonly property var` 数组、元素仍是字符串）；**未加载翻译时行为与改动前
  完全一致**。
- 三个 `*Labels` 都带 `qsTr` 的**消歧说明**（第二参）：译者在 `.ts` 里看到的是
  「这是星期几的缩写」「这是几月」，而不是孤立的一个「日」或「1月」。

⚠ **解析侧未变**：`DateUtil.parseTime` 接受的 AM/PM 词表仍是 `上午 / 下午 / AM / PM`
—— **比格式化输出更宽是刻意的**（解析要宽容历史数据与外部输入）。所以把 `amPmLabels`
设成 `["AM", "PM"]` 时往返仍然闭合；换成词表之外的词则**不闭合** —— 这是已知边界，
写在属性注释里。

⚠ **未改动**：`QSkinStatistic` 的数字格式化（千分位自己写、**不用
`Number.prototype.toLocaleString()`**）—— 复核后**维持**原裁决：它的分隔符与分组
跟着**运行环境的 locale** 走，同一份代码在不同机器上可能给出 `1,234,567` /
`1 234 567` / `12,34,567`，而抓图与判据要的是可复现；且**应用语言 ≠ 机器 locale**
—— `qsTr` 翻译字符串，翻译不了数字格式。要改的宿主请覆盖 `separator` / `formatter`。

### M33-7 · 英文翻译 + 文档

**新增（非破坏性）**

- **`i18n/qds_en.ts` 填入真实英文** —— **120/120 全译**（`en_US`），
  `i18n/qds_en.qm` 随之重新编译（`lrelease`：120 finished / 0 unfinished）。
  在此之前这两个件里是**全未翻译**的骨架。
- **`QSkinCalendar` / `QSkinDatePicker` 新增只读 `monthText`** —— 面板标题上的月份
  文字。原先那一格是 `qsTr("%1月").arg(panelMonth)`，而这个串**在英文里没有对应
  构造**（中文加后缀「月」，英文的月份是独立的词 `Sep`）。改取 `DateUtil.monthLabels`
  （下标夹在 0..11）—— 与**同一标题行**里早就这么做的星期头一致。
  ⚠ **中文渲染逐字节不变**（两边都是 `9月`）；`qsTr("%1月")` 两条 message 随之
  从源码消失（`lupdate -no-obsolete` 实测移除 2 条 obsolete）。
- **`tests/scene_i18n.qml` + `tools/check-i18n-runtime.sh`** —— 运行期翻译门，
  接在 `./tools/test.sh` 的 **3.11** 节。它把同一个场景跑**两遍**：带
  `--translation i18n/qds_en.qm` 必须恰好全绿；不带必须恰好红在声明的那 7 位上
  （**只跑正面那一遍是一道不可证伪的门**）。证伪器 `tools/falsify-i18n-runtime.sh`
  **7/7**。

**文档**

- `README.md` 第六节新增「**文案与本地化**」：库只提供 `.ts` / `.qm`，**装翻译器是
  宿主的责任**（本仓无 C++ 入口）；装完是全局生效，单点改动请用属性覆盖；
  并写明**刻意不进翻译的两类**（算路层诊断与解析字符集、数字格式）与
  「解析比输出宽是刻意的」那条已知边界。
- `COVERAGE.md`：现状节登记 i18n（120 条 `qsTr` / 7 条豁免 / 复算命令）；
  **RTL 那条 ⛔ 的理由改判** —— 旧话「QML 无对应痛点」不成立（`LayoutMirroring`
  是真实机制），真实理由是"镜像动的是布局方向不是文案 / 两道像素门的坐标系从左往右
  扫 / RTL 当前无消费者"。**结论仍是 ⛔，改的是理由。**

### M34 · 文档发布面收口

**新增第十三道门：发布面泄露门禁**（`tools/check-doc-leak.{py,sh}`，接在
`./tools/lint.sh` 第 13 段）。它判三件事：无本机绝对路径与用户名、无本机一次性
件名（`.cache/` 下的探针 / 变异脚本 / 抓图）、无本机工具链细节。证伪器
`tools/falsify-doc-leak.sh`。

> 起因是"文档里混进了本地过程痕迹"这个担心。实测下来**绝对路径与用户名一处都没有**，
> 真正的问题是**过程痕迹被写进了说明书** —— 本机一次性件名被 `.gitignore` 排除，
> 新克隆的仓库里一个都不存在 ⇒ 发布出去就是一批**悬空引用**。

**文档瘦身**（判据：留在发布面的信息，必须对"拿到库写界面的人"当下有用）：

| 文件 | 行数 |
|---|---|
| `README.md` | 1204 → 781 |
| `COVERAGE.md` | 334 → 285 |

搬走**不是删**：实现机制类的条目整段移入 `docs/PITFALLS.md`（+127 行）。
### 新增

- **契约层 92 个 `QSkin*.qml`**（复算：`ls src/contracts/QSkin*.qml | wc -l`），覆盖
  Ant Design 6 / Arco Design / shadcn 三家组件的并集 —— 逐项口径见 `COVERAGE.md`。
- **四套主题**：TDesign / Ant Design / Arco Design / shadcn（各含 `src/themes/<name>/tokens.js`
  + 6 个插槽实现）。
- **地基层纯计算单例**（可被独立算路打、不依赖渲染；`.js` + 薄转发 `.qml` 成对出现）：
  `TreeUtil` / `DateUtil` / `ScrollUtil` / `FuzzyMatch` / `ColorUtil` / `MasonryUtil` /
  `CornerUtil` / `QRCodeEncoder`。（复算：`ls src/foundation/`）
- **门禁**：`./tools/lint.sh` **11 道**（qmllint / 字符图标 / Shape 抗锯齿 / 未定义函数 /
  comprehension 作用域 / 令牌名 / 变异残留审计 / 构建清单校验 …）+ `./tools/test.sh` 上的
  **第十二道**（运行期警告），以及**两道渲染侧像素门**（布局分配 / 绘制面）。
- **双许可**：Apache-2.0（`LICENSE-APACHE`）+ MIT（`LICENSE-MIT`）。

- **三宿主对账**：`qml` 运行器 / **C++ `QQmlApplicationEngine`** / **PySide6** 三种宿主
  跑同一个场景（`tests/scene_host_parity.qml`），要求 qmldir 声明的 **105 个类型全部
  可解析**、**103 个公开类型全部可裸实例化**、**17 个单例全部可取**，
  且三张抓图**逐像素一致**（实测 Qt 6.8.3 与 6.11.2 之间零差异）。
  可运行宿主：`examples/hosts/cpp/`、`examples/hosts/pyside6/main.py`；
  门禁：`tools/check-host-parity.py`，证伪器 `tools/falsify-host-parity.py`。

### 变更

- **布局默认分配**由 `center` 改为 Web 的 `flex-start`；`justify` 只保留
  `start` / `center` / `end` 三档（`between` / `around` 被探针否决：造不出干净形状）。
- **五个别名类型改单名注册**（`QT_QML_SOURCE_TYPENAME` 是单值属性，官方构建路径下
  表达不出双名），并结清 **39 处**引用。
- **`QSkinUpload` 的真实 IO 收进契约**而不是留在嘴上：控件本身零 IO，只出
  `uploadRequested` / `pickerRequested` 两个信号，宿主回调 `reportProgress` /
  `reportSuccess` / `reportFailure` 三个方法。

### 修复

- **`QSkinToast` 的淡出此前从未生效**。`PropertyChanges` 没写目标，赋值被当成落在
  `PropertyChanges` 自身（而它没有 `opacity`），静默失败后 `opacity` 停在 1 ——
  退场实际是「停满再瞬间消失」。修后 `opacity` 真的到 0。**这是一处行为变更**，
  已单独裁决。
- **运行期警告 868 行 / 26 条键 → 179 行 / 15 条键**（修 10 个库文件）：`Unable to
  assign [undefined] to double`、layout `anchors`、`Cannot read property of null`、
  `PropertyChanges` 四族共 11 处。其余 15 条为**存量豁免**（名单 + 对账在
  `tools/runtime-warn-exempt.txt`，新增即红）。
- **构建清单与实际严重不符**（原先只列 27 个 QML，实际 135 个）→ 已修，191 条路径
  与实际一致，并接进 lint 常驻。
- **四家主题的 `install` 键名全部写错**、被白名单静默忽略（M19.1）。
- 一批「属性值对、界面画错」的真缺陷：分割线宽度恒 0、`Shape` 隐式尺寸绑定被盖掉、
  单选组按注册回调序而非声明序、`url` 与空串裸比较丢掉整张插图、`mapToItem()` 不产生
  属性依赖致锚点只求值一次 …… 逐条见 `docs/PITFALLS.md`。

### 已知限制

写在这里而不是留给人踩：

- **布局是一层「有损翻译」，不是等价封装** —— 无 `between` / `around`，无
  `align-self` / `order`；对照表见 `COVERAGE.md` 第 1.1 节。
- **`QSkinUpload` 不做真实文件 IO**（纯 QML 做不出），只交付交互壳。
- **`SplitButton` 不提供**（无消费者）；**独立 `Icon` 控件不做**（插槽路线是对的）。
- **无 RTL 整体方向**（见 `COVERAGE.md` 第六节）。
- 完整清单与逐条理由：**`README.md` 的「已知的限制与取舍」一节 ↔ `COVERAGE.md` 第六节
  「不列入的项（附理由）」**，两处互相指认。

---

## 版本号约定

- **项目版本单点定义**在 `CMakeLists.txt` 的 `project(QSkin VERSION …)`。
  复算：`grep -n 'project(QSkin' CMakeLists.txt`（应只有 1 处）。
- ⚠ `qt_add_qml_module(... VERSION 1.0 ...)` 里的 `1.0` 是 **QML 模块的导入版本**
  （`import QSkin.Foundation 1.0`），**与项目版本无关**，不要一并「统一」。

### 发布收口 · 行尾策略与首次提交（2026-10-01）

- **新增** `.gitattributes`：全仓 `* -text`，并把仓库级的 `core.autocrlf`
  设成 `false`。
  ⚠ 原配置是 **`autocrlf=true`**，而本仓是**混合行尾**：32 个 `.sh` 与 21 个
  `.py` 全部 LF，而 `README.md`、`src/contracts/qmldir` 与 20 个 `.qml` 是
  CRLF。autocrlf=true 会在**检出时**把整个工作副本铺成 CRLF —— 于是 `.sh`
  在 Linux / macOS 上 clone 之后会 `/bin/bash^M: bad interpreter`，全仓构建
  与门禁脚本一起废掉，而 Windows 侧**完全看不出来**（这颗雷只炸别人）。
  改成 `-text` = 字节原样进出：索引实测 **524 LF / 22 CRLF / 2 二进制**，
  与磁盘逐字节一致。
- 代价写在这里：将来若要把全仓统一成 LF，得**有意地**做一次重规范化
  （`git add --renormalize .`）+ 重跑全量门禁 —— 那是一次该被 review 的改动，
  不该由 Git 在背后悄悄完成。
- `0.0.1` 于本日打 tag `v0.0.1`。内容自 **2026-09-17** 冻结，此后到 tag 之间
  只多了上面这一件，以及三处过期读数的订正（qmllint **261** 文件、**11 道**
  脚本门禁、五宿主对账补进测试清单）。

### 0.0.1 之后 · 人工看窗发现并修掉的一个真缺陷（2026-10-03）

0.0.1 发布清单里唯一自动化替不了的一条是「人工开一次窗口看画面」。
执行 `./tools/run.sh HelloQSkin` 时日志里出现 3 条：

```
ACButtonBackground.qml:51:5: Unable to assign [undefined] to QColor
```

- **根因**：`src/themes/arco/tokens.js` 的 `fillHover` / `fillActive`
  **只存在于 light 段，dark 段没有**。而 `slots/ACButtonBackground.qml`
  的 `bg()` 在「灰色实心按钮 hover / 按下」两条分支上读它们 ⇒ 深色下拿到
  undefined ⇒ **Rectangle 这一帧没有底色**（不是回退成别的色，是不画）。
  四主题横向核对：tdesign / ant / shadcn 的 dark 段都覆盖全了，只有 arco 缺。
- **修复**：按 Arco 暗色灰阶补两档 —— `fillHover: #333335`（gray-3）/
  `fillActive: #48484B`（gray-4），与该段已有的 `border` / `borderStrong` 同族。
  重跑窗口：告警 3 → **0**。`qt5/` 产物同步重生成。

- **新增门 · 令牌门规则 [D]**（`tools/check-tokens.py`）：
  `dark` 段的 `color` 组必须覆盖 `light` 段的每一个键。
  **证伪过**：删掉 dark 段的 `fillHover` → 精确报红 RC=1 并点名该键。

  为什么原来的 [A]/[B]/[C] 三条都没抓到 —— 这才是值得记的部分：
  `parse_tokens()` 用 `out.setdefault(group, {})` 把 light / dark 两段
  **合并进同一个组**，于是「dark 缺键」在合并结果里**根本不存在**。
  三条规则查的都是合并后的集合，所以这不是漏了一条规则，是**结构性看不见**。
  现在 `parse_tokens(path, by_mode=True)` 按模式分开解析。

  ⚠ 规则 [D] 的载荷比对刻意**只记不红**：深色下色值本来就该与浅色不同
  （`bg` #17171A vs #FFFFFF），那是常态不是缺陷 —— 第一版逐条报出来是
  152 条噪声，而一条天天在响的闸等于没有闸。深浅**字面量完全相同**时才提示
  （纯黑 `scrim`、白 `onBrand` 这类，现 5 条提示）。

- **为什么全套自动化都是绿的**：`lint` 15 段（含三道令牌规则）、
  `test`（冒烟 48 + 两道像素门 + 运行期警告门 + 五宿主对账）全过，
  而界面在深色下有一处不画 —— 无头抓图跑的场景没有覆盖「深色 + hover 态」。
  这条教训写进了 `docs/PITFALLS.md`。

- 回归：`lint` RC=0 · `test` RC=0 · 五宿主对账位掩码 0x00。
