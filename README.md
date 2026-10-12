# QSkin · Quick Design System

> 为 Qt Quick 打造的**框架级**开源设计系统。
> 借鉴 Web 端已经被验证过的布局与令牌思想，让用代码写出来的 UI 默认就不难看；
> 再在此之上，用一层样式契约承载 TDesign / Ant Design / Arco Design / shadcn 的 Qt 实现。

> **一句话**：生态里那些项目都是**一套设计语言**；QSkin是**四套**
> （× 明暗 = 8 套），**纯 QML 源码不用编译**，并且在 **Qt 6.8+ 与 Qt 5.15** 上
> **各自实测跑通** —— 含 PyQt5 / PySide6 / C++ 五个宿主，
> **信创机器（龙芯 / 麒麟）**上是能跑的那一个。
>
> **Qt 5.11**（openEuler 20.03 LTS 的系统 Qt）另有一档 `qt511/`：
> **Windows x64 上实测通过**（控件实例化 · 像素门 23 条 · 深色场景 · 27 页抓图），
> **Linux 侧尚未在目标机验证** —— 见下文「验证到哪一步」。

---

## 一、它为什么存在

**先说清楚生态里有什么**（2026-10 逐个查过 GitHub 与官网，不是印象）：

| 项目 | 是什么 | 协议 | Qt 版本 | 设计语言 | 需编译 |
|---|---|---|---|---|---|
| [Kirigami](https://invent.kde.org/frameworks/kirigami) | KDE 官方 QML 框架，20 年历史 | ❌ LGPL-2.0+ | 6.x | KDE 一套 | ✅ C++ |
| [HuskarUI](https://github.com/Polaris-Night/HuskarUI) | Ant Design 的 QML 实现，50+ 控件，带 gallery 应用 | ✅ MIT | **≥ 6.7** | Ant Design **一套** | ✅ C++ |
| [Qaterial](https://github.com/OlivierLD/qaterial) | Material Design 的 QML 实现 | ✅ MIT | 6.x | Material **一套** | ✅ C++ |
| [RinUI](https://github.com/RinLit-233-shiroko/Rin-UI) | Fluent Design 的 QML 实现，`pip install` 可用，100+ star | ✅ MIT | PySide6 | Fluent **一套** | ❌ |
| [QSkinny](https://github.com/uwerat/qskinny) | 面向汽车 HMI 的场景图框架，Fendt 拖拉机量产用过 | ✅ BSD-3 | 5.15 / 6.x | 自定义 | ✅ C++ |
| [Qlementine](https://github.com/oclero/qlementine) | ⚠️ **QWidget 的**，不是 QML —— 常被误列在这里 | ✅ MIT | ≥ 6.8 | 自定义 | ✅ C++ |
| **QSkin（本仓）** | 见下 | ✅ MIT / Apache-2.0 | **6.8+ 与 5.15 双轨** | **4 套** | ❌ 纯 QML 源码 |

**它们的共同点**：一套设计语言、一套自己的控件实现。

**QSkin 解决的是另一个问题** —— 当你要**同时**满足下面三条时：

1. **同一套业务代码，要按不同设计语言交付**（给客户 A 是 TDesign，给客户 B 是 shadcn）
2. **协议要宽松** —— 动态链接 Qt 即可闭源商用，不受 LGPL 传染
3. **要跨宿主** —— QML / C++ / PySide6 / PyQt5，以及**信创机器上的 Qt 5.15**

那三件事必须**同时**满足。**「一套主题 + 一种语言 + 要编译」的项目给你前两件里的第三件或第四件，
但给不了「四套设计语言 + 五个宿主 + 零编译」。**

### QSkin 与它们的具体差异（逐条可核验）

| | HuskarUI | RinUI | **QSkin** |
|---|---|---|---|
| 设计语言 | Ant Design **1 套** | Fluent **1 套** | **4 套**（TDesign / Ant Design / Arco / shadcn）× 明暗 = 8 套 |
| 接入成本 | C++ 编译 + 链接 | `pip install RinUI` | **纯 QML 源码，把 `src/` 挂进 import 路径即可** |
| Qt 5.15 | ❌ 需 ≥ 6.7 | ❌ 需 PySide6 | ✅ **实测通过**（PyQt5 5.15.2 + C++ Qt 5） |
| Qt 5.11（openEuler 20.03） | ❌ 需 ≥ 6.7 | ❌ 需 PySide6 | 🟡 **Windows x64 上实测通过**（见下方「验证到哪一步」）；**Linux 侧待目标机验证** |
| 信创（龙芯 / 麒麟） | 未声明 | ❌ 无 loongarch wheel | ✅ **PyQt5 sdist 可装**（龙芯有 pypi 镜像） |
| 宿主 | QML + C++ | **仅 PySide6** | **5 个**：QML / C++ / PySide6 / PyQt5 / C++ Qt5 |
| 能力承诺怎么来的 | 文档 | 文档 | **5 宿主跑同一场景对账 + 逐像素核验**（`tools/test.sh`） |

⚠️ **最后一行是本仓与其它项目最大的方法论差异**：
「纯 QML 所以谁都能用」是**推论**，不是实测。别的项目靠文档说，我们靠门禁证 ——
每一条能力承诺都有对应的门，**而且每道门都被做过变异验证**（故意破坏一处，确认它真的会红）。

更根本的问题是：**Qt Quick 的人才池太小**。而 Web 端任何人写出来的第一个页面都不会太难看，
因为 `gap` / `padding` / `flex` / `minmax` 这些语义已经成了肌肉记忆。
QML 没有这层约定，于是每个初学者都在手算 x/y，写出来的界面自然显得原始。

**所以 QSkin 的第一层不是"组件"，而是"地基层"——把 Web 的布局语义搬进 QML，
顺带把 Web 开发者的上手成本压到接近零。**

---

## 二、架构：两层 + 一层契约

```
┌─────────────────────────────────────────────────────────┐
│  主题层  Theme                                           │
│  TDesign · Ant Design · Arco Design · shadcn            │
│  每套主题 = 1 份 token + 若干插槽实现（8~11 个，各家不同）  │
│           —— 不含任何控件逻辑                                │
└──────────────────────────┬──────────────────────────────┘
                           │ 样式契约层 Style Contract（M1）
                           │ background / contentItem / indicator
                           │ / overlay / label —— 定义可被替换的插槽
┌──────────────────────────┴──────────────────────────────┐
│  地基层  Foundation（M0 · 已落地）                         │
│  UI 无关：Layout / Spacing / Typography                  │
│           Breakpoints / Focus / 按钮布局系统              │
│           文本度量 TextMetricsUtil                        │
│  完全不关心最终长什么样 —— 这是"UI 无关"的字面意思          │
└─────────────────────────────────────────────────────────┘
```

### 渲染前量文本：`TextMetricsUtil`

QML 的绑定是**声明式 + 惰性**的：`height: text.implicitHeight` 要等 polish
才算出结果。于是「按宽度算高度 → 据此定容器 → 据此排兄弟」这条链在 QML 里
只能写成死算式，或者**先塌一下再撑开**（CLS 那个问题）。

```qml
import QSkin.Foundation 1.0

Item {
    // 签名：lineCountAt(text, maxWidth, font?) / blockHeightAt(text, maxWidth, font?, lineHeight?, mode?)
    TextMetricsUtil.lineCountAt("按宽度折行", 200)                  // → 行数（渲染前就有答案）
    TextMetricsUtil.blockHeightAt("按宽度折行", 200, null, 16)      // → 整块高
    TextMetricsUtil.fitsIn("一行放得下吗", 120)                    // → bool
}
```

改 `TextMetrics.text` 再读是**同步**的 —— 不等帧、不触发 reflow。

> ⚠ **两个坑已在源码里写明，这里再提一次**：
> ① 度量要用 `advanceWidth`（排版真正用的前进宽度），**不是** `width`
>   （包围盒，含左右 side bearing）—— 混用会让逐字累加凭空少几十 px；
> ② 自然行高要 `ceil`（`round` 只在默认字体下偶然成立）。
> 这两条都实测踩过：贪心算法因此与引擎差一行。

**为什么要插入一个"契约层"？**
因为少了它，"多主题"就会退化成"复制 4 份控件代码"。
契约层规定每个控件**哪些部分允许被替换**：状态机、键盘导航、无障碍语义、数据绑定留在契约层；
圆角、边框、图标、动画全部下沉到插槽。主题作者只对着插槽写代码，业务代码一行不改就能换肤。

地基层里除了布局与排版，还收着两个**纯计算 singleton**：`DateUtil`
（日期/时间的加减与格式化，M11）和 `TreeUtil`（树的索引、展平、级联、
半选推导，M17）。它们和布局令牌住在同一层的理由是一样的：

> **只要一件事会被两个以上控件问到，它就不该住在任何一个控件里。**

`TreeUtil` 是 M17 才搬过去的 —— 在此之前它住 `QSkinTable` 里，"能跑"，
直到要做第二棵树时它才变成"同一道题两份答案"。

---

## 三、当前状态

> 本节只留**现在是什么样**（里程碑过程属开发记录，不随发行版发布）；
> 逐项规格在 `COVERAGE.md`，版本与变更在 `CHANGELOG.md`。

**契约层**：`src/contracts/` 下 **92 个 `QSkin*.qml`** —— 其中控件 **86** 个，
其余是配套件（`Slots` / 各控件的插槽实现等）。⚠ 「文件数」与「控件数」**不是一回事**。

**组件覆盖**（Ant Design 6 / Arco / shadcn 三家组件的**并集**，逐项 ✅ / 🔶 / ⬜ / ⛔）：

| 口径 | 数 | 说明 |
|---|---|---|
| ✅ 已落地 | **86** | |
| 🔶 部分 | **2** | 两条**都已写明是「终态」还是「欠账」** |
| ⬜ 未做 | **0** | |
| ⛔ 明确不做 | — | 每条都写了理由，见 `COVERAGE.md` |

**主题**：4 家（`tdesign` / `ant` / `arco` / `shadcn`）× 明暗 = **8 套**。
令牌是**纯数据**（`src/themes/<主题>/tokens.js`），换肤**不改控件代码**。

**示例**：`examples/` —— `HelloQSkin`（三分钟上手）+ 4 个门面
（`HelloThemes` / `HelloContracts` / `HelloFoundation` / `HelloIcons`）；
按里程碑命名的演示屏在 `examples/showcase/`。

**门禁**（全部**可被证伪**，每道都跑过变异）：

| 命令 | 内容 |
|---|---|
| `./tools/lint.sh` | qmllint（**264** 个文件，0 警告）+ **12 道脚本门禁**（字符图标 · Shape 抗锯齿 · 未定义函数 · comprehension 作用域 · 令牌名 · 构建清单 · 清单与 qmldir 对账 · 变异残留审计 · i18n · 发布面泄露 · Qt 5 产物漂移 · 发布面读数对账）|
| `./tools/test.sh` | **49 个冒烟** + 真鼠标事件 + 纯函数独立算路 + **两道像素门**（布局 / 输入底板）+ **两道运行期门**（警告 / 翻译）+ **五宿主对账**（qml / C++ / PySide6 / PyQt5 / C++ Qt 5） |

⚠ 布局是**有损翻译层**（抽象模型不同，只能管理不能消灭）—— 这是本项目**已知的
最大差距**；对照表在 `COVERAGE.md` 第一节，展开见本文件第十节。

## 四、目录结构

```
qds/
├── src/
│   ├── foundation/          UI 无关的地基
│   │                        Theme 令牌入口 / Breakpoints
│   │                        QSkinRow · QSkinColumn · QSkinGrid · Spacer · ButtonBar · FocusRing
│   │                        Heading · Body · Caption / QSkinWindow
│   │                        DateUtil · TreeUtil —— 纯计算单例，无 UI
│   ├── contracts/           92 个 QSkin*.qml 契约控件 + Slots 插槽注册表
│   │   └── slots/           Basic* 默认插槽实现（换主题时被整体替换）
│   │                        ⚠ 逐件清单在 COVERAGE.md，此处不抄第二份
│   └── themes/              四套主题，每套同构：token + 插槽 + 入口
│                            tdesign / ant / arco / shadcn
├── i18n/                    qskin_en.ts（翻译源）+ qskin_en.qm（可直接加载）
├── examples/                HelloQSkin.qml（三分钟上手）+ 4 个门面
│   └── showcase/            按里程碑命名的演示屏（HelloM*.qml）
├── tests/                   smoke_*.qml 冒烟测试，退出码位掩码上报
│                            （每个文件头部写明它守的是哪条契约）
├── tools/                   构建 / 运行 / 门禁脚本
├── docs/
│   └── PITFALLS.md          踩过的坑 + Qt 行为陷阱速查 ★ 改构建或测试前先读
├── COVERAGE.md              控件覆盖度 —— 唯一事实来源（逐项 ✅/🔶/⬜/⛔）
└── CHANGELOG.md             版本与变更
```

三个入口命令：

| 命令 | 作用 |
|---|---|
| `./tools/run.sh HelloQSkin [主题名]` | 交互式跑示例：窗口可点击、有 hover、有动画 |
| `./tools/lint.sh` | 静态检查：qmllint + 12 道脚本门禁 |
| `./tools/test.sh` | 冒烟测试 + 真实鼠标事件 + 像素核验 |

每道门禁查什么，**读 `tools/lint.sh` 自己** —— 它就是那张表，不在这里抄第二份。

## 五、快速开始

### 先做一次环境体检（可选，但要跑满门禁就得齐）

用这套库写界面只需要 Qt 6（见下面方式 A）。**仓库自带的门禁**跑的是五个宿主，
需要额外几样东西 —— 它们缺了会报**工装错误 8**，不会静默跳过：

```bash
./tools/setup-hosts.sh --check     # 体检：列出缺什么，退出码 = 缺失项数（0 = 齐）
./tools/setup-hosts.sh             # 补齐：缺什么装什么（PySide6 / PyQt5 / Qt 5 SDK / 两个 C++ 宿主）
```

> 缺依赖 ≠ 库有问题，但**也不等于这一层通过了**：判据的输入没了，门就什么都没在防。
> 所以默认行为是报错而不是跳过。确实要临时跳过某个宿主，用
> `--skip-pyside6` / `--skip-pyqt5` / `--skip-cpp-qt5` —— 但请在心里把它记成欠账。

### 方式 A：直接用 qml 跑示例（无需编译）

```bash
./tools/install-qt.sh     # 装一份项目内 Qt 到 .qt/（已加入 .gitignore）
./tools/lint.sh           # 静态检查总入口（qmllint + 12 道脚本门禁），当前 264 个文件 0 警告
./tools/test.sh           # 冒烟测试 + qmltestrunner 真鼠标事件 + 两道独立算路核验

# 只跑字符图标门禁（一般不用单独跑，lint.sh 会自动带上）
./tools/scan-glyph-icons.sh --all

# 只跑变异残留审计：`src/` 此刻装的是「原文」还是「改坏成」（lint.sh 也会带上）
./tools/check-mutation-residue.sh --all

# 交互式跑示例（窗口可点击、有 hover、有动画，关闭即退出）
./tools/run.sh HelloQSkin           # 三分钟上手（默认主题）
./tools/run.sh HelloQSkin tdesign   # 第二个参数是主题名
./tools/run.sh HelloThemes        # 示例名不带 .qml 后缀；全部见 examples/
```

> **不要把抓图入口当交互演示跑。** 它的退出路径依赖 Timer / grabToImage 回调，
> 在这套工具环境里偶发停摆，会留下一个「画了第一帧但事件循环已冻结」的假窗口
> ——点不动、没 hover，看起来像交互没接上，实际是抓图工具卡死。
> 要截图请走 `tools/shot.sh`（带 60 秒看门狗，超时即杀）。

> **为什么不能 `QML2_IMPORT_PATH=src` 一把梭？**
> QML 是按 **URI 路径** 找模块的：`import QSkin.Foundation 1.0` 会去
> `<importPath>/QSkin/Foundation/qmldir`，而源码目录叫 `src/foundation`，名字对不上，
> 直接跑会报 *Failed to import QSkin.Foundation. Are your import paths set up properly?*
> 走 CMake 时 `qt_add_qml_module` 会替你做这层映射；脱离构建跑的话，
> `tools/` 下的脚本会先在 `.cache/` 下搭一份目录名与 URI 匹配的副本。

### 方式 B：CMake 构建 QML 模块

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=<你的 Qt 安装前缀>
cmake --build build
```

需要 C++ 编译器（`qt_add_qml_module` 会生成一个插件 target）。
只改 QML、不发布二进制的话，方式 A 更快。

### 在 C++ 应用里用

QSkin 是**纯 QML 源码分发**，C++ 侧不需要链接任何 QSkin 的库 —— 把 `src/` 挂进
import 路径，`QQmlApplicationEngine` 加载你的 QML 即可：

```cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    engine.addImportPath("<把 src/ 映射成 QSkin/... 的那层目录>");
    engine.load(QUrl::fromLocalFile("Main.qml"));
    return app.exec();
}
```

可运行的完整宿主在 `examples/hosts/cpp/`（`main.cpp` + `CMakeLists.txt` + `build.sh`）。

> **Qt 的 DLL 必须在搜索路径上。** 直接跑宿主二进制若报 `0xC0000135`
> （`STATUS_DLL_NOT_FOUND`），是 Qt 的 `bin` 不在 `PATH` 里，不是 QSkin 的问题 ——
> `tools/check-host-parity.py` 内部就是这么处理的。

### 在 Python（PySide6 / PyQt5）里用

Python 侧的本质就是「用 Python 起一个 QML 引擎再加载 .qml」，QSkin 不需要为
Python 做任何适配。**但两个绑定绑的不是同一个 Qt**，所以走的是两份源码树：

| 绑定 | 绑哪个 Qt | 用哪份源码树 |
|---|---|---|
| **PySide6** | Qt 6 | `src/`（事实源） |
| **PyQt5** | Qt 5 | `qt5/`（`tools/qml-downgrade.py` 生成） |

```python
# PySide6 —— 用 Qt 6，指向 src/ 那层 import 路径
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

app = QGuiApplication([])
engine = QQmlApplicationEngine()
engine.addImportPath("<把 src/ 映射成 QSkin/... 的那层目录>")
engine.load("Main.qml")
app.exec()
```

```python
# PyQt5 —— 用 Qt 5，指向 qt5/；唯一差异是 exec_() 带下划线
from PyQt5.QtGui import QGuiApplication
from PyQt5.QtQml import QQmlApplicationEngine

app = QGuiApplication([])
engine = QQmlApplicationEngine()
engine.addImportPath("<qt5/ 所在的 import 根>")
engine.load("Main.qml")
app.exec_()
```

可运行的完整宿主：`examples/hosts/pyside6/main.py` 与 `examples/hosts/pyqt5/main.py`。

> **PyQt5 自带 Qt 运行时。** `pip install PyQt5` 会连带装 `PyQt5-Qt5`（实测
> 5.15.2），wheel 里有一整套 Qt 5，**不依赖系统 Qt** —— 所以即便目标机系统
> Qt 是 5.11，PyQt5 跑的仍是自带的 5.15.2。反过来：**sdist 安装**（信创机器上
> 常见）不自带 Qt，需要系统有 Qt 5 开发库；龙芯有 `pypi.loongnix.cn` 镜像
> （glibc 2.28 那档正好覆盖 Debian 10）。

> **翻译器要自己装。** 本仓是纯 QML 分发、**没有 C++ 入口**，装 `QTranslator`
> 是宿主的责任；且必须在 QML 引擎加载**之前**装，否则已求值的绑定不会再翻译。

### 宿主对账：上面每种用法都在门禁里跑着

「纯 QML 所以谁都能用」是推论，不是实测。本仓的做法是：**同一个场景**
（`tests/scene_host_parity.qml`）在每个宿主下各跑一遍，要求

- qmldir 声明的 **105 个类型全部可解析**、
- 其中 **103 个公开类型全部可裸实例化**（另 2 个是内部件，见下）、
- **17 个单例全部可取**、
- Qt 6 侧三个宿主抓图**逐像素一致**。

```bash
python tools/check-host-parity.py          # 四个宿主：qml / C++ / PySide6 / PyQt5
python tools/falsify-host-parity.py        # 证伪：确认上面那道门真的会红
python tools/qml-downgrade.py --profile qt515   # 生成 Qt 5.15 侧源码树 qt5/
python tools/qml-downgrade.py --profile qt511 --also-examples   # 生成 Qt 5.11 侧 qt511/
```

### Qt 5.11 档（openEuler 20.03 LTS）

```bash
# 生成（--also-examples 才会把示例页也降级；抓图验证需要它们）
python tools/qml-downgrade.py --profile qt511 --also-examples

# 三层门，任何一层红都算 Qt 5.11 不成立
python tools/check-residue.py qt511                # ① 产物无 Qt 6 写法残留（代码掩码口径）
python tools/check-qt511-contracts.py qt511    # ② 真实 5.11.1 引擎逐个实例化 qmldir 里的对外控件
python tools/falsify-qt511-gate.py                # ③ 证伪：注入 5 类缺陷，门必须变红

# 插槽层（补上面三道的盲区，见下）
python tools/check-qt511-slots.py --lib qt511# 常规
python tools/check-qt511-slots.py --lib qt511 --make-baseline  # 生成中文判据的基线

# 深色场景 + 它自己的证伪
QSkin_QT=<Qt5.11根> python tools/check-dark-scene.py --lib qt511
QSkin_QT=<Qt5.11根> python tools/falsify-dark-scene.py

# 布局像素门（在 qt511 产物上跑，23 条判据）
QSkin_QT=<Qt5.11根> ./tools/check-layout-pixels.sh --lib qt511

# 真实页面抓图（27 页；库与示例要同一个 --lib 根）
QSkin_QT=<Qt5.11根> python tools/grab-pages.py --lib qt511 --out .cache/qt511_pages
```

**⚠ 插槽层那道门为什么必须单独有**（实测踩出来的）：
`check-qt511-contracts.py` 逐个实例化 `qmldir` 里的**对外类型**，
**不覆盖 `slots/`** —— 而 5.11 档的核心降级规则（四角半径内联）**只在插槽里生效**。
上一版那个 `id is not unique` 的bug 就发生在这里：`TDInputBackground` **加载期就失败**
⇒ `TDesign` 整个类型 unavailable ⇒ 3 个示例页 + 深色场景全挂，
而那一刻**实例化门是绿的**、残留扫描绿的、漂移门绿的 —— 只有真实渲染看得见。

**⚠ 中文需要额外装字体（所有 Qt 版本都要，5.11 尤其）**：
Qt **官方二进制不带字体** —— 实测 `lib/fonts/` 在 5.11.1 / 5.15.2 / 6.8.3
**三个版本里全都不存在**，而它**只认自己那份**：系统明明装了雅黑、它也找不到。
结果 `Microsoft YaHei` 解析失败 ⇒ 回退到无中文字形的字体 ⇒
**每一页的中文都是空心方框**，而 `qml.exe` rc=0、`qmlscene` 只报无关的 OpenGL 提示。
⚠ **库的字体声明是对的，不是库的 bug** —— 从控制台完全看不出来。

`./tools/install-qt.sh` **装完会自动补一份中文字体**（Windows 找 msyh / simsun /
simhei，Linux 与macOS 找 NotoSansCJK / 文泉驿 / Source Han Sans）。
手动装 Qt 的话，把任意中文 `.ttf/.ttc/.otf` 拷进 `$QtRoot/lib/fonts/`。

**⚠ 哪道门能用在哪个档上**（**拿错会假红**，实测）：

| 工具 | 适用 | 不适用 |
|---|---|---|
| `check-residue.py <档>` | `qt511` | ❌ `qt5/` —— 它按 5.11 口径判 `required property` 与 Pointer Handler，而这两类在 5.15 **是合法的**，会报 6 类假残留 |
| `check-qt511-contracts.py <档>` | `qt511` | ❌ `qt5/` —— 名字与实现都写死了 5.11 |
| **`check-qt511-slots.py --lib <目录>`** | ✅ `qt511` **与 `qt5`** 两档 | —— 它按 `--lib` 走，是唯一两档都能用的（名字里的 "qt511" 有歧义） |

**Qt 5.11 的实测边界**（逐条在真实 5.11.1 上验过，写下来免得下次再撞）：

| 项 | 结论 |
|---|---|
| `QtQuick` | ≤ **2.11**（2.12 起崩） |
| `QtQuick.Controls` | ≤ **2.4**（2.5+ 崩：`module … version 2.11 is not installed`） |
| `QtQuick.Window` / `Layouts` | 2.11 / 1.11 可用 |
| `QtGraphicalEffects` | **1.0**（1.1+ 崩） |
| `QtQuick.Shapes` | **可用** —— Shape / ShapePath / PathLine / PathAngleArc / PathSvg 全通过；只有 `preferredRendererType` 不支持 |
| `required property` | 不支持 → 降级为普通 property（61 处） |
| Pointer Handlers | 不支持 → MouseArea（Hover / Tap / Wheel 共 6 处） |
| `Gradient.orientation` | 不支持（5.11 只有纵向） |
| Popup/Dialog 的 anchors | 不支持（浮层不是 Item）→ 手动 x/y 居中 |
| JS 保留字 `as` | 引擎拒绝 → 改名 `aS` |

> **最大的一块工程量没有发生**：Shapes 在 5.11 上可用，所以 162 处
> `ShapePath` **不需要**为 5.11 另写一套 Canvas 实现。

### 验证到哪一步（Qt 5.11 档）

⚠ **下面这张表就是「支持」二字的全部依据** —— 哪一格是空的，就是还没验的。

| 验证项 | 平台 | 状态 |
|---|---|---|
| 产物无 Qt 6 写法残留（代码掩码口径） | — | ✅ 通过 |
| 真实引擎逐个实例化全部对外控件 | Windows x64 | ✅ 通过 |
| **插槽层加载 + 渲染**（59 个 `slots/*.qml`，含四角半径降级路径） | Windows x64 | ✅ 通过（证伪：注入 id 冲突变红） |
| **中文字形真的画出来了**（对比无中文字体基线） | Windows x64 | ✅ 通过（证伪：移走雅黑变红） |
| 变异证伪（注入缺陷门必须变红） | Windows x64 | ✅ 通过 |
| 布局像素门（23 条判据，数值与 Qt 6 侧逐项相同） | Windows x64 | ✅ 通过 |
| 深色场景（三态按钮 / 输入 / 标签 / 开关 + 自证块） | Windows x64 | ✅ 通过 |
| 27 个真实页面抓图 | Windows x64 | ✅ 通过 |
| 冒烟套件（54 个） | Windows x64 | 🟡 **34 过 / 8 断言值不同 / 0 加载失败**，见下 |
| **Linux / aarch64（openEuler 真机或容器）** | Linux | ❌ **未验** |
| **C++ 宿主 / PyQt5 宿主在 5.11 上对账** | — | ❌ 未验 |

**关于那 8 个冒烟**：它们**不是加载失败**（QML 报错 0 条，产物能跑），
而是**断言的期望值**在 5.11 上不成立 —— 这些期望值是照Qt 6 写的，
而 Qt 5.11 的浮层时序、字体度量、`children` 语义与 Qt 6 有细节差异。
典型例子：`smoke_m8` 的 `[0] dlg.opened === true`（`open()` 后立即读）。
**这些差异尚未逐条定性**（可能是「断言该按版本分档」，也可能是真缺陷），
所以**不把它们算作通过**。

> **为什么 Linux 那一格不能靠推断填**：Qt Quick 的 Shapes 光栅化、字体度量、
> 渲染后端都随平台变。项目自己的记录里就有只在特定渲染路径暴露的缺陷
> （M18.1：自动化全绿、人工开窗才看见深色下按钮没画底色）。
> 在 Windows 上验过 ≠ 在 openEuler 上能用。
>
> ⚠ 另有两个**环境侧**的坑：Qt 5.11 官方二进制**不自带字体**，
> 缺 `lib/fonts` 时**所有文字都画不出来而引擎零报错**；
> 同一份代码在 Qt 6 上却正常回退到系统字体。本机验证时补了该目录。

**PySide6 与 PyQt5 是同一道门里的两个宿主**，不是两次手工验证 —— PyQt5
缺失（解释器里没装）会报**工装错误 8**，不静默跳过。两条线的数字必须同口径，
不一致就是位掩码 2。两条 Python 线装在两个不同环境时，用环境变量指过去：

```bash
QSkin_PYSIDE6_PYTHON=/path/to/py-with-pyside6 \
QSkin_PYQT5_PYTHON=/path/to/py-with-pyqt5 \
python tools/check-host-parity.py
```

实测覆盖 —— **Qt 6 侧**用 `src/`，**Qt 5 侧**用 `qt5/`（降级产物）：

| 源码树 | 宿主 | Qt 版本 | 结果 |
|---|---|---|---|
| `src/` | `qml` 运行器 | 6.8.3 | 105/105 · 103/103 · 18/18 |
| `src/` | C++（`QQmlApplicationEngine`） | 6.8.3 | 同上，且与 qml 逐像素一致 |
| `src/` | PySide6 | 6.11.2 | 同上，且与 qml 逐像素一致 |
| `qt5/` | PyQt5 | 5.15.2（wheel 自带） | 105/105 · 103/103 · 18/18 |
| `qt5/` | C++（Qt 5，MinGW） | 5.15.2 | 105/105 · 103/103 · 18/18 |
| `qt511/` | `qml` 运行器 | **5.11.1** | 全部对外控件可实例化 · 27 页抓图（见上节三层门） |

> **PyQt5 为什么不参与像素对账**：Qt 5 与 Qt 6 的渲染（抗锯齿、Shape 光栅化）
> 本就不可能逐像素相同，把它算进来只会得到一个永远红的假判据。它参与的是
> **契约对账** —— 解析数 / 可实例化数 / 单例数必须与 Qt 6 侧完全一致。

> **`qt5/` 会漂移，所以有专门的门**：`qt5/` 是入库的生成物，`src/` 改一行
> 却不重跑生成器，它会悄悄陈旧 —— 而 lint 照样全绿（它扫的是 `src/`）。
> `tools/check-qt5-drift.sh`（lint 第 15 段）把当前 `src/` 重新生成一份与
> 入库产物逐文件比 sha256，新增 / 残留 / 内容不同都红。修法就是重跑生成器
> 并把产物一起提交。

> **为什么 Qt 5 目标定在 5.15，且只有这一档**：PyQt5 的 wheel 自带 Qt 5.15，
> 而 5.15 已经有 `required property`、Pointer Handlers、`QtQuick.Shapes`
> （Shapes 5.12 转正；5.10/5.11 是 Tech Preview 且默认不构建）。所以降级只剩
> 6 类机械改写（生成器逐条带预期命中数，跑不对照就红）。
> 曾经验证过一档 `qt511`（Qt 5.11.3）并**已删除**：5.11 官方分发不带 Shapes，
> 34 个文件 233 处 `Shape` 要另写一套实现，而 PyQt5 自带的是 5.15 —— 没有真实
> 目标机需要它，留着只会让「到底支持哪个 Qt 5」说不清。

> **Qt 5 侧 C++ 的构建**：宿主代码与 Qt 6 那份是**同一个** `main.cpp`
> （`QGuiApplication` / `QQmlApplicationEngine` / `QCommandLineParser` 在
> 5.15 与 6.x 都存在），只有 CMake 配置不同。用 **MinGW** 编（Qt 5.15.2 的
> `mingw81_64` 变体 + 项目内 `.qt/Tools/mingw1310_64` 的 g++ 13.1）：
> `bash examples/hosts/cpp-qt5/build.sh`。
> （原先走 MSVC，但本机只有 VS2022 **BuildTools**、无完整工具链，一直编不出来；
> 换 MinGW 后实测通过。）

> **PySide6 下的 23 条属性遮蔽警告：** Qt 6.11 起会对「子类型重新声明了基类
> 已有的属性」发警告（`Member X of the object Y overrides a member of the base
> object`），并建议加 `override`。本仓**刻意不加**：
> **Qt 6.8.3 不认识 `override` 关键字**（实测语法错误、直接加载失败），
> 而 6.8.3 是本仓的开发基准；且 `data`（`default property alias`，
> `QSkinRow { Item{} }` 靠它）与 `enabled` 都不宜改名。
> 于是这 23 条被写成**断言清单**：多一条少一条门都会红 —— 注释不会红，断言会。

### 在你的项目里用

```qml
import QtQuick 2.15
import QSkin.Foundation 1.0

QSkinWindow {
    width: 960; height: 640; visible: true

    QSkinColumn {
        width: parent.width - 48
        x: 24; y: 24
        gap: Theme.space.lg
        align: "start"

        Heading { level: 2; text: "设置" }

        QSkinGrid {
            fill: true
            minChildWidth: 240
            gap: Theme.space.md
            Repeater {
                model: 8
                Rectangle {
                    height: 96
                    radius: Theme.radius.lg
                    color: Theme.color.bgElevated
                    border.color: Theme.color.border
                }
            }
        }
    }
}
```

---

## 六、核心 API

### Theme —— 令牌入口

```qml
Theme.color.bg            // 容器底色
Theme.color.fg            // 主文字
Theme.color.brand         // 品牌色
Theme.space.md            // 12（4pt 基线刻度）
Theme.radius.md           // 4
Theme.font.sm             // 14
Theme.size.controlMd      // 32（标准控件高度）
Theme.motion.fast         // 120

Theme.mode = "dark"                       // 切换明暗
TDesign.apply()                           // 换主题，全 UI 同一帧刷新
Theme.patch("color", { brand: "#0052D9" }) // 品牌微调
Theme.reset()                             // 回到地基默认值
```

> **为什么换肤不用改业务代码？**
> QML 的属性绑定天然响应式：把 `Theme.light` 整个换成另一个对象，
> 所有写了 `Theme.color.bg` 的地方会在同一帧内自动更新。
> 这比 CSS 变量少了一层"级联传播"的心智负担。

### Grid —— CSS 那句 grid 模板的等价物

```css
/* Web */
grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
```

```qml
// QSkin
QSkinGrid { minChildWidth: 160; gap: Theme.space.md }
```

窄屏强制单列：`minChildWidth: Breakpoints.compact ? 99999 : 240`

### Breakpoints

```qml
Breakpoints.compact      // ≤ 767
Breakpoints.medium       // 768 – 1279
Breakpoints.expanded     // > 1279
Breakpoints.name         // "compact" | "medium" | "expanded"
```

由 `QSkinWindow` 自动挂载；也可手动 `Breakpoints.attach(someItem)`。

### ButtonBar —— 按钮布局系统

它解决的不是"按钮长什么样"（那是主题层的事），而是"按钮该怎么排"：

```qml
ButtonBar {
    width: parent.width
    align: "end"
    dangerIndexes: [0]        // 声明下标为 0 的按钮是危险操作

    QSkinButton { text: "删除" }   // index 0，危险
    QSkinButton { text: "取消" }   // index 1
    QSkinButton { text: "确定" }   // index 2，主按钮
}
```

- **平台顺序**：业务永远把主按钮写在最后。macOS / Linux 主按钮在右，Windows 自动挪到最左。
- **危险间距**：危险按钮两侧自动插入更大的间距，避免误点。
- **窄屏堆叠**：宽度不足自动改纵向，主按钮在上。

### FocusRing

```qml
FocusScope {
    id: scope
    activeFocusOnTab: true
    Rectangle { ... }
    FocusRing { control: scope }
}
```

只在键盘导航（`activeFocus`）时显示，鼠标点击不打扰 —— 对齐 Web 的 `:focus-visible` 语义。

### Slots —— 插槽注册表（M1 核心）

```qml
import QSkin.Contracts 1.0

// 换肤：只替换你提供的插槽，其余保留当前实现
Slots.install({
    buttonBackground: Component { Rectangle { radius: 0; color: "black" } },
    label:            Component { Text { font.weight: 700; /* ... */ } }
})

Slots.reset()   // 回到 Basic 默认实现
```

`examples/HelloContracts.qml` 里有一份约 50 行的完整换肤示例
（直角描边 + 全大写 + 加粗），点一个按钮就能在两套皮肤之间来回切换 ——
而键盘导航、无障碍语义、状态机一行都没动。

**契约三条：**

1. 每个插槽都是一个 `Component`；宿主用 `Loader` 实例化它，并把自身注入为 `control`
2. 插槽**可以读**宿主的全部状态（`hovered` / `pressed` / `checked` / `variant` …），
   但**不应该改**这些状态 —— 一旦主题开始改状态，换肤就会开始改变行为
3. 插槽**不能**引入交互 —— 不要放 `MouseArea` / `Keys` / `Shortcut`，
   否则键盘与无障碍语义会分裂成 N 份实现

**插槽清单的权威来源是 `src/contracts/Slots.qml` 本身**（`slotNames` 是运行时的
可枚举清单，`reset()` 是回落到 `Basic*` 的唯一入口），README 不另立一份 ——
因为它一旦和源码不同步，比没有更糟。

#### indicator 家族：一个空了很久的格子（M15.1）

`Slots.qml` 的家族注释从 M1 起就写着「勾选框、开关轨道、**展开箭头**」，
但**「展开箭头」这一格直到 M15.1 才被真正实现**（`chevronIndicator`）。

一个空着的格子代价远超预期：四个控件各自绕过它 —— `QSkinSelect` 自绘三角、
`QSkinTable` 打 `▾` / `▸` 字符、`QSkinDatePicker` 自绘折线、`QSkinPagination` 拿
按钮文字打 `‹` / `›`。**同一个 affordance 四种画法，其中一种是字符**，
而"图标不用字符"这条规矩在同一批文件的文件头被重复申明了四次。

教训在 M15.1 章节末尾：**规矩写在注释里不等于规矩被执行**；一条规则被反复
申明却被反复违反时，缺的不是自觉，是一个插槽。

### QSkinButton —— 契约层控件的样子

```qml
QSkinButton {
    text: "保存"
    variant: "primary"        // default | primary | danger | ghost | text
    size: "md"                // sm | md | lg
    iconSource: "qrc:/save.svg"
    onClicked: save()
}
```

M15.1 又给它补了三个属性，为了放得下**画出来**的图标（而不是图片资源）：

```qml
QSkinButton {
    icon:           Slots.chevronIndicator   // Component（插槽），不是资源路径
    iconDirection:  "left"                   // up | down | left | right
    accessibleName: "上一页"                 // 空则回落到 text
    variant: "text"; size: "sm"
}
```

- `icon` 收的是 **Component**：项目里一个图标**资源**都没有，`iconSource` 那条
  通路到今天一次都没被真正用过；收 Component 才能让"图标长什么样"跟着主题走。
  它由 `BasicButtonContent` 的 `iconDelegate` 装进 `Loader`，宿主给插槽注入
  `control`（带 `direction` / `enabled` / `hovered`）。
- `iconDirection` 是**方向类图标（箭头）**的朝向。方向本身是"状态"、由宿主翻译；
  箭头**长什么样**是主题差异、交给插槽 —— 见 M15.1 章节。
- `accessibleName` 解决一个真实缺陷：分页按钮原先写作 `text: "‹"`，
  **读屏软件念出来的就是「‹」**。现在 `text` 留空、`icon` 出图、
  `accessibleName: "上一页"`，`Accessible.name` 优先取它、空则回落 `text`。

控件自己只管状态机、键盘（Enter / Space）、`Accessible.*` 与尺寸阶梯；
长什么样由三个插槽决定 —— 同一段业务代码，在 TDesign 下是蓝底 3px 圆角，
在 shadcn 下是黑底 6px 圆角。

### QSkinSelect —— 浮层插槽是怎么拆的

浮层是最难的一档：它同时含「外壳」（视觉）和「列表」（行为），
而列表要显示在面板里面，天生纠缠。

拆法沿用 Qt Quick Controls 的思路：**控件持有 ListView，插槽持有外壳**，
控件把列表作为 `content` 注入插槽，由插槽摆进自己的内容区。

```qml
QSkinSelect {
    width: 200
    model: ["红色", "绿色", "蓝色"]   // 或 ListModel + textRole
    currentIndex: 0
    maxVisibleRows: 6                // 超过就滚动
    onActivated: function(i) { ... }
}
```

于是「换一套下拉面板外观」退化成「换一个只画面板的 Component」；
上下键导航、Enter 选中、Esc 取消这些最容易写错的部分，仍然只有一份。

### QSkinDatePicker / QSkinTimePicker —— 同一套浮层契约的第二次复用

两个选择器**没有引入任何新插槽**，因为它们需要的三件事
（浮层外壳 `selectOverlay` / 输入框底 `inputBackground` / 全部文字 `label`）
在做 QSkinSelect 那轮已经抽出来了。它们只是浮层里的**新内容**。

```qml
QSkinDatePicker {
    width: 200
    value: DateUtil.make(2026, 9, 9)     // {year, month, day}，给 null 表示未选
    displayFormat: "YYYY年MM月DD日"
    minimumDate: DateUtil.make(2026, 9, 10)   // 闭区间，赋值/选值都就地钳制
    maximumDate: DateUtil.make(2026, 9, 20)
    onActivated: function(d) { ... }
}

QSkinTimePicker {
    width: 200
    value: DateUtil.makeTime(13, 45)     // {hour, minute, second}
    displayFormat: "hh:mm A"             // → 01:45 下午
    showSeconds: true                    // 面板自动多一列、宽度跟着变
    minuteStep: 15                       // 档位粒度：00/15/30/45
    minimumTime: DateUtil.makeTime(9, 0)
    maximumTime: DateUtil.makeTime(17, 0)
}
```

**行为差异是刻意的**：日期点一下格子就收面板（一个维度，选完即完）；
时间有三列，改某一列**不关面板**，只有「确定」/ 回车才收 —— 逐个点完
再统一确认更顺手。

**日期时间算术全在 `DateUtil`**（地基层 singleton，无 UI）：
`make` / `today` / `isValid` / `addMonths` / `compare` / `clamp` /
`format` / `parse` / `monthGrid` / `daysInMonth` / `firstWeekday`，
以及时间侧的 `makeTime` / `now` / `compareTime` / `clampTime` /
`formatTime` / `parseTime` / `hoursList` / `minutesList` / `secondsList`。
控件里没有一行日期算术，所以这些规则可以被单独测试（`smoke_m11.qml`
前 5 条断言全在守它）。

```qml
// make() 有意滚动（网格补格需要），parse() 必须严格（不许静默滚动）
DateUtil.make(2026, 2, 30)        // → 2026-03-02
DateUtil.parse("2026-02-30")      // → null
DateUtil.formatTime(DateUtil.makeTime(15, 30), "hh:mm A")  // → "03:30 下午"
```

### 文案与本地化（i18n）

**库只提供资产，装翻译器是宿主的事。** 本仓是纯 QML 源码分发、**没有 C++ 入口**，
所以库不会替宿主 `installTranslator`。翻译资产在这个目录的 `i18n/`：

| 件 | 是什么 |
|---|---|
| `i18n/qskin_en.ts` | **源**：`lupdate` 抽出来的 message 表（`en_US`，**120/120 全译**） |
| `i18n/qskin_en.qm` | **可直接加载**的编译产物 —— 随源码入库。源码分发形态下不带着它，宿主拿到的是一个**不能本地化**的框架 |

重新抽取 / 编译用 `./tools/i18n.sh update` 与 `build`。三道判据（`src/` 里带 CJK
的用户可见字面量必须登记在案、豁免表**双向**对账、`.ts`/`.qm` 与源码同步）在
`./tools/check-i18n.sh` —— `./tools/lint.sh` 会带上它。

宿主侧的样子（**顺序是重点**：必须在 QML 引擎加载之前装，否则已经求值过的绑定
不会回头）：

```cpp
QTranslator qds;
if (qds.load("qrc:/qds/i18n/qskin_en.qm")) app.installTranslator(&qds);
```

装上之后是**全局**生效（整进程的 `qsTr` 结果都变）。只想改一处，用**属性覆盖**
（`cancelText` / `emptyText` 这类公开属性）比装翻译器更局部 —— 那也是这一层
存在的理由：**默认值可翻，单点可覆盖，两件事互不干扰**。

**刻意不进翻译的**（`tools/i18n-exempt.txt`，当前 7 条全属"开发者可见"一类）：

- **算路层的诊断与解析字符集**。`src/foundation/*.js` 要能在 node 下裸跑（三道
  纯函数门禁直接 `require` 它们），而 node 里没有 `qsTr`。所以那一层的失败信息是
  **错误码 + ASCII 诊断**，给用户看的那句落在控件层（`QSkinQRCode.errorText`）。
- **数字格式**。`QSkinStatistic` 的千分位是**自己写的**，不用
  `Number.prototype.toLocaleString()` —— 后者的分隔符与分组跟着**运行环境的
  locale** 走，同一份代码换台机器就换个数，抓图与判据都不可复现。`qsTr` 也翻不了
  数字格式（那是 `QLocale` 的地盘，而**应用语言不等于机器 locale**）。

⚠ **解析比输出宽是刻意的**：`DateUtil.parseTime` 接受 `上午 / 下午 / AM / PM`
四个词，而 `amPmLabels` 只产出其中两个 —— 历史数据与外部输入要宽容。代价是把
`amPmLabels` 换成接受集之外的词时，`format → parse` 的往返会断（**已知边界**，
不是缺陷；换回 `["AM", "PM"]` 即闭合）。

⚠ **翻译资产里的 `.ts` 不要手改 `<source>`** —— 它是 `lupdate` 的产物，改了就和
源码脱钩，判据 3 会红。改文案请改 `src/`，然后重跑 `./tools/i18n.sh`。

⚠ **上面那段 `formatTime` 的例子是"没加载翻译"时的结果**（库自身不带翻译域，
默认就是中文）；装上 `qskin_en.qm` 之后它是 `"03:30 PM"`。

这条链路上有门守着，而且**门自己能被证伪**：`tests/scene_i18n.qml` 被跑**两遍**
—— 带 `--translation` 必须恰 `0`，不带必须恰是声明的那份位掩码。接在
`./tools/test.sh` 的 **3.11** 节（红了就是"翻译没生效"，不是"文案写错了"）。

---

---

## 七、怎么写一套主题

一套主题 = 1 份 token + 若干插槽实现，不含任何控件逻辑。
令牌侧的契约现在就能用 —— 一个主题只需要提供这个形状：

```qml
// src/themes/tdesign/TDesign.qml
pragma Singleton
import QtQuick 2.15

QtObject {
    readonly property string name: "TDesign"
    readonly property var light: {
        color:  { brand: "#0052D9", bg: "#FFFFFF", fg: "#000000E6", /* ... */ },
        radius: { sm: 3, md: 3, lg: 6, xl: 9 },      // TDesign 圆角更克制
        size:   { controlMd: 32 }
        // space / font / motion 不提供 → 自动保留地基默认值
    }
    readonly property var dark: { /* ... */ }
}
```

装载：

```qml
TDesign.apply()          // 内部就是 Theme.install(TDesign, TDesign.name)
```

**令牌规则三条：**

1. 只替换你真正提供的明暗集合，另一个保留当前值
2. 集合内部缺失的组（比如不定义 `space`）保留地基默认值
3. 因此主题作者只需要写自己真正想改的那部分

一套完整主题 = 上面的 token **+** 一组插槽实现（`Slots.install({ ... })`）。
插槽那半边的规则见上一节的「契约三条」。

---

## 八、协议现实（务必读完这一节）

本仓库代码以 **MIT 与 Apache-2.0 双协议**发布，你可以任选其一。

**但必须说清楚一件事：QSkin 依赖 Qt 运行时，而 Qt 自身的授权不由本项目决定。**

- ✅ **能做到的**：地基层、契约层、四套主题全部是自有代码，MIT / Apache-2.0 双协议。
  你动态链接 Qt 即可闭源商用，不需要公开自己的业务代码 —— 这是相比 LGPL 框架最实际的区别。
- ❌ **做不到的**：我不能替 Qt 放宽授权，也不能把 Qt 的代码换个协议再分发。
  Qt 运行时仍然是 **LGPLv3 / GPL / 商业授权**（由 The Qt Company 决定）。

**所以「协议友好」的上限是：QSkin 代码 MIT + 你动态链接 Qt（闭源可行）。**

这一条原本就写在这里，不会藏在角落 —— 含糊其辞等于误导使用者。
如果你的项目需要完全摆脱 LGPL 约束，请直接向 The Qt Company 购买商业授权。

---

## 九、演进原则

**发过什么版本** -> `CHANGELOG.md`（M0–M34 总表，唯一出处）。

下面这段是这个项目的**排序原则**：它解释了为什么里程碑必须是这个顺序 ——
把顺序换一下，后面就得推倒重来。

顺序不能反：**地基没定就做主题**，等于把布局语义写死在某个设计语言里，第二套主题必然推倒重来；
**契约层没定就做控件**，等于把逻辑复制 N 份。

M17 是这条原则的第三次发作，只是这一回被"复制"的是**算法**：
树逻辑在 `QSkinTable` 里活着并不算错，直到你要做第二棵树上——那时它才变成
"同一道题两份答案"。所以那一轮的第一步不是写 `QSkinTree`，是先把算法搬进
`QSkin.Foundation.TreeUtil` 并证明表格**零回归**。判断依据与 Theme / DateUtil
同源：**只要出现第二个消费者，"它现在能跑"就不再是理由。**

M18 换了个方向用同一条原则：**先把"别处都要用"的原子做出来**。
Divider / Card / Layout 会被后面每一批引用，它们的接口一旦晚定，
后续批次的视觉稿就得按"当时的临时实现"来画。

M19 补的是另一条线：**"拼第一屏必然撞上"的基础件**。List / Avatar /
Empty / Skeleton / Spin 五件在四家里是三家全有的通用件，缺了它们，
任何页面都只能先用别的控件"临时凑一个"——而临时凑出来的东西会
在后续每个页面里复制一次。同一批还第一次把 `Slots` 的两格
（`spinRing` / `spinDots`）交给了四家主题，并因此暴露了一条
**只在运行时才看得见的契约**：`install` 按白名单索引，键名写错
会静默忽略，且"非 null"这种断言永远抓不到它（见 M19.1）。

M20 是**第一次"八件里有六件是成对的"**（Radio/RadioGroup、Toggle/ToggleGroup、
Label 与四个用它起头的显式标注位），于是它撞上的错几乎都不是"某个控件写错了"，
而是**件与件之间的那条暗契约写错了**：

- 单选组的成员顺序不能信"谁先注册" —— 兄弟节点的 `Component.onCompleted`
  是**逆声明序**触发的（实测 "321"）。方向键于是倒着走、roving tabindex
  落在最后一个成员上，而属性侧看到的一切自洽。改成按 `children` 下标路径
  排序之后才对。
- 宿主把值推给成员，与成员把值推给宿主，必须是**同一个算法**。`QSkinRadioGroup`
  的 `onValueChanged` 一开始直接读 `isComplete` 这类派生属性，于是读到了
  **上一次**的结果 —— QML 绑定是惰性的，依赖变了只标脏，而 `valueChanged`
  先于那次重算触发。抽成纯函数（`_isComplete(v)`）之后两边才走同一条算路。
- 尺寸这件事上，**谁最后写谁赢**：`Shape` 的隐式尺寸是它自己按路径包围盒
  算的，`implicitWidth: root.markerSize` 绑定会被静默盖掉（必填星标量出
  8.75 而不是 10，整块布局跟着按 8.75 排）。改用 `Layout.preferred*`。

这三条都落进了变异脚本的回归护栏里 —— 不是靠"我记得"，是靠"改回去就会红"。

M21 把这条原则用在了**"该不该新增一个概念"**上。浮层六件看着花样很多，
但它们之间的差别全在**内容**里，不在外壳里 —— 所以这一批的正确做法不是
"给气泡、菜单、通知各来一格插槽"，而是**零新增**：

- 气泡一族（Popover / Popconfirm / HoverCard）复用 M1 就有的
  `selectOverlay`，菜单一族复用 `chevronIndicator`。于是换肤时它们的
  底色 / 圆角 / 阴影 / 内边距**一起**变 —— "不为气泡新开一格"这句话在屏幕上
  看得见。变异脚本里专门有一枪去推翻它（新开一格 `popoverOverlay`），
  它必须被打红。
- "同一时刻只有一个**排他**浮层"这条规则**不属于任何控件**，所以它落在
  地基层（`OverlayStack` 单例）。放进控件的话，五个件会各写一套，
  而且"谁该排他"这件事会在三处出现三个版本。它的边界也是设计出来的：
  悬停类是 `exclusive: false`、**不进来**；菜单那一腿天然不进
  （它走 `QSkinMenu`，不经过 `Popup`）。
- `QSkinNotification` 是这一族里唯一**不用 `Popup`** 的成员 —— 因为它不是
  "锚定到某个控件"的浮层，而是一块固定在窗口右上角的堆叠区。硬把它塞进
  同一套外壳，只会让"浮层"这个词同时表示两件事。

而这一批最值钱的一条教训，是**"零新增"必须被证伪**：
`smoke_m21_theme.qml` 本来宣称"通知卡底色跟着令牌走"，但它只在**浅色**下跑，
而浅色的 `bgElevated` 恰好就是 `#FFFFFF` —— 于是把实现写死成 `"#FFFFFF"`
是**数值空操作**，那条断言一个字都抓不到。挖出它的是**门禁侧**的变异
（改弱判据，看它会不会放过）。**不是变异选得不好，是断言没测到它声称要测的东西。**

---

## 十、已知的限制与取舍

> 这一节写**用法上的边界** —— 你写页面时会撞到的那些，以及"我们选择了不做"。
> **范围上的边界**（哪些件不在计划内、每条的 ⛔ 理由）在 `COVERAGE.md` 第六节。
> **实现级的机制与不变量**（改 `src/` 才会碰到的）在 `docs/PITFALLS.md`。

### 布局与容器

- **容器默认按内容收缩**（≈ CSS `inline-flex`）。需要撑满父容器时请显式写
  `width: parent.width`，不要和 `anchors.fill` 混用。
- **"宽度等于内容"的组件（`QSkinBreadcrumb` 等）内部不要放依赖父宽的子项**
  （`anchors.right: parent.right` 之类）。父宽由子项内容推出、子项位置又依赖
  父宽 —— 双向往返会让隐式宽度收敛不稳，实测表现为内容被压扁。
  需要并排元素时，外层套一个 `QSkinRow` 做兄弟。
- **`QSkinRow` / `QSkinColumn` / `QSkinGrid` 统一管理子项的 `Layout.alignment`**；
  要自己控制就设 `manageAlignment: false`。
- **在这三个容器里的 `Text` 系子项（`Heading` / `Body` / `Caption`），宽度只能靠
  `Layout.*` 给**。写 `width: page.width` 会被 Layout 静默覆盖（它取
  `implicitWidth`，即不换行的整行宽），`wrapMode: WordWrap` 随之失效、长文本溢出
  右沿。用 `Layout.fillWidth: true` 或 `Layout.preferredWidth`。
  同一个容器里的 `Rectangle` 反而吃显式 `width` —— 这个不一致正是问题难被发现的原因。
- **`Rectangle` 在 `QSkinColumn` 里不给宽度会塌成 0 宽**（Layout 取 `implicitWidth`
  = 0）。画分隔线要显式给宽度，或用 `Layout.fillWidth: true`。
- **`Layout` 是附加类型，用它的每个文件都要自己 `import QtQuick.Layouts`** ——
  import 不随模块传递，漏了报 `Non-existent attached object`。
- **`Shape` 在 Layout 里的尺寸要写 `Layout.preferredWidth/Height`** —— 它的
  `implicitWidth` 由路径包围盒自己算，你写的 `implicitWidth:` 绑定会被静默盖掉。
- **`anchors` 不喂父项的隐式尺寸**：`anchors.fill + anchors.margins` 时，
  `implicitHeight = 子.implicitHeight` 会少算两倍内距，外框比内容小一圈。

### 令牌与主题

- **`Theme.color.*` 取到的是十六进制字符串，不是 `color` 值**。直接写在 `color:`
  上没问题（QML 自动转），但要**调透明度或做插值**时得先声明一个
  `readonly property color` 过一手类型；否则 `Qt.rgba()` 收到 NaN，
  **静默退化成「黑色 + 指定透明度」** —— 浅色主题上像正常阴影，深色主题上直接隐形。
- **`motion.easing` 存的是数值**（`QEasingCurve::Type`），因为 `.js` 令牌文件里取不到
  QML 的 `Easing` 枚举。文件内已注明对应枚举名。
- **`Theme.patch()` 绝不原地改令牌集合** —— `Theme.light` 与 `Neutral.light` 是同一个
  JS 对象，原地改会污染出厂默认值、`reset()` 再也回不来。现有实现是整份复制后再换。
- **换滚动条皮肤 = 连带接管它的行为**（`QSkinScrollArea`）。主题提供
  `ScrollBar.contentItem` 之后，Qt 6.8 Basic 样式自带的淡出状态机被一并丢掉 ——
  "没有东西可滚"的栏位也可能画出一条贯穿视口的线，`policy: auto` 形同虚设。
- **`divider` 可见性下限 `ΔL ≥ 12` 是本项目的约定，不是三家规范的产物**。
  需要时**按主题单独调 `divider` 色，不要动阈值** —— 阈值一旦为某套主题放宽，
  另一套主题"画了等于没画"就会静默滑过去。

### 插槽

- **插槽里的宿主引用声明为 `var`，不要声明成 `Item`**。契约是鸭子类型：声明成
  `Item` 会让 qmllint 按 `QQuickItem` 做成员检查，把 `control.radius`、
  `target.hovered` 报成 *Member not found*。
- **`Slots.label` 的宿主类型靠鸭子类型判**：`iconSize !== undefined` 即实心按钮
  （要 `onBrand` 白字），否则是菜单项 / 复选框这类透明宿主（要前景色）。
  `primary` / `danger` 两个 variant 都依赖这条规则分叉。
- **`Slots.install` 按白名单索引，键名写错是静默的** —— 装不上去，也不报错。
  白名单外的键现在会打 `console.warn`，留意它。
- **插槽覆盖矩阵可以是不对称的**：TDesign / Ant / shadcn 只覆盖 `spinRing`、
  Arco 只覆盖 `spinDots`。这是故意的 —— 主题只提交自己关心的那几格，其余继承 `Basic`。

### 浮层

- **浮层用了 QtQuick.Controls 的 `Popup` 当引擎**（overlay 层级、模态、Esc 关闭、焦点
  管理都是行为，自己实现一套再交给插槽会违反契约第 3 条）。取舍是：把 `background`
  清空、外观全交给插槽，Controls 只当浮层引擎用。
- **"同一时刻只有一个排他浮层"归地基层**（`OverlayStack`），不归控件 —— 放进控件，
  五个件会各写一套。悬停类不进栈，菜单那一腿天然不进。
- **`QSkinNotification` 是家族里唯一不用 `Popup` 的成员**：它不是"锚定到某个控件"的
  浮层，而是一块固定在窗口右上角的堆叠区。
- **`variant` 在契约层只是个自由字符串**，长相同由主题外壳决定。四家只认
  `primary / default / danger / ghost / text`；写 `"outline"`（那是 `QSkinToggle` 的
  词汇表）**不报错、也不落到任何 case**，静默长得和 `default` 一样。
  同理 `notify.show()` 只收**一个**参数，多给的被 JS 静默丢掉。
- **命令式方法调用不产生属性依赖**：`readonly property point o: t.mapToItem(null,0,0)`
  只求值一次 —— 目标一移动，浮层留在原地，而属性侧读它永远是对的。判定法是问
  "**改哪个属性会让它重算**"，答不上来就是没依赖。

### 表格与树

- **列宽拖拽一旦发生即快照所有列**，之后不再自动等分（否则容器 resize 会把用户
  拖出来的宽度洗掉）。`resetColumnWidths()` 可回到等分模式。
- **等分列有 `minColumnWidth` 下限**：内容宽窄到装不下时宁可整表横向溢出（由横滚
  兜住），也不把列压成 0 宽 —— **0 宽列等于"数据凭空消失"**。
- **给表格加固定列不会改变滚动范围**：能滚多远只取决于内容总宽与容器宽。
- **一列不能同时钉在左右两边**（`fixedRightColumns` 会被夹取）。
- **窄容器下左固定区优先**：右固定列可能只露出一部分，而不是左右各让一半 ——
  左区里还有 checkbox 列，那是"全选"的唯一入口。
- **`QSkinTable` 目前没有节点级禁用**（`disabledKeys` 是 `QSkinTree` 独有的）——
  已知的一处不对称。
- **树的排序只作用于同级兄弟**，绝不跨层搬行。
- **树形缩进有上限**（列宽 − 内边距 − 箭头位 − `treeMinLabelWidth`，夹到 ≥ 0）：
  窄列上宁可停止缩进，也不把文字挤没。
- **`Flickable.contentX / contentY` 外部直接赋值不会被夹取**：夹取只发生在拖拽与
  惯性滑动路径上。要超界保护得自己 `Math.min/max`，或走 `scrollTo()`。
- **`Text.maximumLineCount <= 0` ≡ 「不限」**，且属性回读原样保留 0 / 负数。

### 取值与输入

- **`url` 型属性判空必须过 `String()`**：`imageSource` 这类 url 属性交给 JS 的是
  `QUrl` **对象**，于是 `imageSource === ""` **恒假**、`== ""` 才是 true。
  统一写 `String(u) !== ""`。（`BasicButtonContent.qml` 里那处用的是宽松比较，
  是**故意**的，有注释挡着"顺手改成 `!==`"。）
- **`onValueChanged` 里不要读派生属性，要调函数**：QML 绑定是惰性的，依赖变了只
  标脏、下次读才重算，而 `valueChanged` 先于那次重算触发 —— 读到的是**上一次**的
  结果。把判定抽成纯函数，handler 与属性绑定走同一条算路。

### 明确不做的（终态）

- **`Icon` 不做**：图标在本仓是**宿主给的内容** —— `chevronIndicator` /
  `statusGlyph` / `spinRing` 这些插槽已经是它的全部形态。`COVERAGE.md` 里这一行的
  🔶 因此表示**就停在这个粒度**：它不欠任何东西。
- **`SplitButton` 不做**：要复用 `QSkinDropdown` 的触发与翻转，成本不低，而按钮组
  （`QSkinButtonGroup`）已经落地，市场上没有第二个消费者。
  项目原则：**没有消费者就不做。**

---

## 十一、踩过的坑与 Qt 行为陷阱

这一块很长，且是**给要改构建 / 测试的人**看的，已整段移出到 `docs/PITFALLS.md`：

- **十六个踩过的坑** —— 构建 / 测试 / 门禁上真实栽过的地方，每条都记了
  「症状 -> 根因 -> 判据」；
- **`十一·附` Qt 行为陷阱速查** —— 12 组（尺寸 / 坐标 / 像素·出图 / 跑场景 /
  时序·响应式 / 导入 / 成组协议 / 假读数 / 渲染侧不可观测 …）。

改这个库的构建或测试之前，建议先读它 —— 里面大部分坑**只暴露在渲染或运行期**，
属性断言和冒烟全绿的时候照样会踩。

> 原节号**保留**（旧引用里的「第十一节」指的就是这两块）。

## 十二、贡献

欢迎 PR。地基层的准入标准只有一条：

> **这一层不允许出现任何"好不好看"的判断。**
> 地基层只负责"有没有秩序"（对齐、节奏、层级、可读性），
> "好不好看"全部留给主题层。

如果你提交的改动里出现了具体的设计语言特征（比如某个圆角值只在 TDesign 下才合理），
那它应该属于主题层，而不是这里。

---

SPDX-License-Identifier: MIT OR Apache-2.0
