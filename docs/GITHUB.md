# GitHub 项目介绍 · QSkin

> 三份材料，按 GitHub 创建流程的顺序排：① 仓库 description ② README 首屏 ③ topics + release notes 模板。
> 读数全部来自 `README.md` / `COVERAGE.md`，可复算。

---

## ① 仓库 description（100 字以内，直接粘进创建表单）

**主推（英文，GitHub 面向国际）**

```
A framework-level design system for Qt Quick. One style contract, four design languages (TDesign, Ant Design, Arco Design, shadcn). MIT / Apache-2.0.
```

**备选 1（更短，31 字符级）**

```
Design system for Qt Quick. One contract, four design languages.
```

**备选 2（带卖点「五宿主实测」）**

```
Qt Quick design system: one contract, 4 design languages, verified across 5 hosts (QML/C++/PySide6/PyQt5/Qt5-C++). MIT/Apache-2.0.
```

**中文版**

```
Qt Quick 的框架级设计系统：一层样式契约，四套设计语言（TDesign / Ant Design / Arco Design / shadcn）。MIT / Apache-2.0 双协议。
```

---

## ② README 首屏（GitHub 仓库首页）

> 完整的 README 在仓库里（1300+ 行），下面是**首屏**——别人打开仓库最先看到的部分。

```markdown
<div align="center">

# QSkin

**为 Qt Quick 打造的框架级设计系统**
一层样式契约 · 四套设计语言 · 五个宿主实测

`TDesign` · `Ant Design` · `Arco Design` · `shadcn`

[![license](https://img.shields.io/badge/license-MIT%20%7C%20Apache--2.0-blue.svg)](LICENSE-MIT)
[![qt](https://img.shields.io/badge/Qt-6.8%2B%20%7C%20Qt--5.15-green.svg)](https://doc.qt.io)
[![version](https://img.shields.io/badge/version-0.0.1-lightgrey.svg)](CHANGELOG.md)

</div>

---

## 它解决什么问题

Qt Quick 生态**不缺组件**，缺的是**三件事同时成立**的方案：

1. **同一套业务代码按不同设计语言交付**（给客户 A 是 TDesign，给客户 B 是 shadcn）
2. **协议宽松** —— 动态链接 Qt 即可闭源商用
3. **跨宿主 + 跨 Qt 版本** —— 含信创机器上的 Qt 5.15

| 项目 | 协议 | Qt 版本 | 设计语言 | 需编译 |
|---|---|---|---|---|
| [Kirigami](https://invent.kde.org/frameworks/kirigami) | ❌ LGPL-2.0+ | 6.x | KDE 1 套 | ✅ |
| [HuskarUI](https://github.com/Polaris-Night/HuskarUI) | ✅ MIT | ≥ 6.7 | Ant Design 1 套 | ✅ |
| [Qaterial](https://github.com/OlivierLD/qaterial) | ✅ MIT | 6.x | Material 1 套 | ✅ |
| [RinUI](https://github.com/RinLit-233-shiroko/Rin-UI) | ✅ MIT | PySide6 | Fluent 1 套 | ❌ |
| **QSkin** | ✅ MIT / Apache-2.0 | **6.8+ 与 5.15 双轨** | **4 套 × 明暗 = 8 套** | ❌ |

**前三家都只给得出「一套设计语言」**。要同时满足那三条，得自己写第二套 ——
这正是 QSkin 存在的位置。

更根本的问题是：**Qt Quick 的人才池太小**。Web 端任何人写出来的第一个页面都不会太难看，
因为 `gap` / `padding` / `flex` / `minmax` 已经成了肌肉记忆。QML 没有这层约定，
于是每个初学者都在手算 x/y，写出来的界面自然显得原始。

**所以 QSkin 的第一层不是「组件」，而是「地基层」**——把 Web 的布局语义搬进 QML，
顺带把 Web 开发者的上手成本压到接近零。

## 架构：两层 + 一层契约

```
┌─────────────────────────────────────────────────────────┐
│  主题层  Theme                                           │
│  TDesign · Ant Design · Arco Design · shadcn            │
│  每套主题 = 1 份 token + 若干插槽实现（8~11 个，各家不同）  │
│           —— 不含任何控件逻辑                                │
└──────────────────────────┬──────────────────────────────┘
                           │  样式契约层 Style Contract
                           │  background / contentItem / indicator
                           │  / overlay / label —— 定义可被替换的插槽
┌──────────────────────────┴──────────────────────────────┐
│  地基层  Foundation                                      │
│  UI 无关：Layout / Spacing / Typography                  │
│           Breakpoints / Focus / 按钮布局系统              │
│  完全不关心最终长什么样 —— 这是「UI 无关」的字面意思         │
└─────────────────────────────────────────────────────────┘
```

**为什么要插入一层「契约」？** 因为少了它，「多主题」会退化成「复制 4 份控件代码」。
契约层规定每个控件**哪些部分允许被替换**：状态机、键盘导航、无障碍语义、数据绑定留在契约层；
圆角、边框、图标、动画全部下沉到插槽。主题作者只对着插槽写代码，**业务代码一行不改就能换肤**。

## 当前状态

| | |
|---|---|
| 契约层 | **92** 个 `QSkin*.qml`（其中控件 **86** 个 + 配套件） |
| 组件覆盖 | ✅ **86** · 🔶 **2**（都已写明是「终态」还是「欠账」）· ⬜ **0** |
| 主题 | 4 家 × 明暗 = **8 套**，换肤不改控件代码 |
| 宿主 | **5 个**实测对账：QML / C++ / PySide6 / PyQt5 / C++ Qt 5 |
| 授权 | MIT 或 Apache-2.0，任选其一 |

## 快速开始

```bash
git clone https://github.com/<你的账号>/qskin.git
cd qskin

# 环境体检（缺什么会列出来，退出码 = 缺失项数）
./tools/setup-hosts.sh --check

# 跑一个示例窗口（不需要编译）
./tools/run.sh HelloQSkin
```

在你的项目里用：

```qml
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0
import QSkin.Theme.TDesign 1.0   // 换 shadcn / AntDesign / ArcoDesign 即换肤

QSkinButton {
    text: "Hello"
    onClicked: console.log("clicked")
}
```

C++ 侧**不需要链接任何 QSkin 库**——它是纯 QML 源码分发，把 `src/` 挂进 import 路径即可：

```cpp
QQmlApplicationEngine engine;
engine.addImportPath("<把 src/ 映射成 QSkin/... 的那层目录>");
engine.load(QUrl::fromLocalFile("Main.qml"));
```

## 门禁：每一道都能被证伪

「能信」不是形容词，是有机制的：

| 命令 | 内容 |
|---|---|
| `./tools/lint.sh` | qmllint（**264** 个文件，0 警告）+ **12 道脚本门禁** |
| `./tools/test.sh` | **48** 个冒烟 + 真鼠标事件 + **2 道像素门** + **2 道运行期门** + **5 宿主对账** |

同一场景（`tests/scene_host_parity.qml`）在五个宿主下各跑一遍，要求
**105 个类型全部可解析 · 103 个公开类型全部可裸实例化 · 17 个单例全部可取**，
且 Qt 6 侧三宿主**抓图逐像素一致**。

> **纯 QML 所以谁都能用是推论，不是实测。** 能力承诺要有跑起来的宿主。
> 门禁缺了工具会报**工装错误**而不是静默跳过；每道门都做过变异验证——
> 故意破坏一处，确认它真的会红。

## 授权现实（请读完这一节）

本仓库代码以 **MIT 与 Apache-2.0 双协议**发布，你可以任选其一。

**但必须说清楚：QSkin 依赖 Qt 运行时，而 Qt 自身的授权不由本项目决定。**

- ✅ **能做到**：地基层、契约层、四套主题全部是自有代码，MIT / Apache-2.0。
  动态链接 Qt 即可闭源商用，不需要公开业务代码——这是相比 LGPL 框架最实际的区别。
- ❌ **做不到**：不能替 Qt 放宽授权，也不能把 Qt 的代码换个协议再分发。
  Qt 运行时仍然是 **LGPLv3 / GPL / 商业授权**（由 The Qt Company 决定）。

**「协议友好」的上限就是：QSkin 代码 MIT + 你动态链接 Qt（闭源可行）。**
含糊其辞等于误导使用者。如果你的项目需要完全摆脱 LGPL 约束，
请直接向 The Qt Company 购买商业授权。

## 状态与路线

**0.0.1 是「第一个可被外部评估的快照」，不是功能完整版，也不承诺 API 稳定。**
对外的承诺只有三条：**能装**、**能信**、**边界清楚**（做不了的写在明处）。

已知限制与取舍逐条列在 `README.md` 第十节，不藏。

## License

[MIT](LICENSE-MIT) 或 [Apache-2.0](LICENSE-APACHE)，任选其一。
```

---

## ③ topics 标签（GitHub 仓库设置里填，最多 20 个，取 12）

```
qml
qtquick
qt6
design-system
ui-components
qml-components
design-tokens
theme
dark-mode
tdesign
ant-design
pyside6
```

> 刻意**不放** `qt-quick-controls`（Qt 官方的 topic 池比我们宽得多，
> 蹭它会让仓库在无关搜索里露出来）。

---

## ④ Release notes 模板（0.1.0 用；现在先建 0.0.1 的 release）

```markdown
## QSkin 0.0.1 — $(date +%Y-%m-%d)

第一个可被外部评估的快照。**不承诺 API 稳定。**

### 读数（都可复算，命令写在 README / COVERAGE）

- 契约层 92 个 `QSkin*.qml`；qmldir 声明 105 类型 + 17 单例
- 组件覆盖 ✅86 · 🔶2（终态声明，非欠账）· ⬜0
- 主题 4 家 × 明暗 = 8 套
- 门禁：qmllint 264 文件 0 警告 + 12 道脚本门；48 冒烟 + 2 像素门 + 2 运行期门

### 五宿主实测对账

同一场景，105/105 可解析 · 103/103 可裸实例化 · 18/18 单例：

| 宿主 | Qt | 源码树 | 结果 |
|---|---|---|---|
| QML 运行器 | 6.8.3 | `src/` | ✅ |
| C++（QQmlApplicationEngine） | 6.8.3 | `src/` | ✅ 与 qml 逐像素一致 |
| PySide6 | 6.11.2 | `src/` | ✅ 与 qml 逐像素一致 |
| PyQt5 | 5.15.2 | `qt5/` | ✅ 契约数同口径 |
| C++（Qt 5） | 5.15.2 | `qt5/` | ✅ 契约数同口径 |

### 三条对外承诺

1. **能装** —— 照文档走一遍，不用读源码就能让一个窗口显示出来
2. **能信** —— 每一道门自己都能被证伪
3. **边界清楚** —— 做不了的写在明处（README 第十节 / COVERAGE 第六节）

### 授权

MIT 或 Apache-2.0。**依赖 Qt 运行时，Qt 的授权不由本项目决定**（LGPLv3 / GPL / 商业授权）。
动态链接 Qt 可闭源商用。
```

---

## ⑤ 建议的仓库设置

| 项 | 值 | 理由 |
|---|---|---|
| 名称 | `qskin` | 短、无冲突（注意 `QSkinny` 是另一个 Qt/QML 框架，只差一个字母）|
| 描述 | 见 ① | |
| 许可证 | `MIT license` + 额外放 `LICENSE-APACHE` | 双协议任选，GitHub 只认一个 |
| 默认分支 | `main` | |
| Topics | 见 ③ | |
| Discussions | 开 | 组件需求 / 主题建议 |
| Wiki | **关** | 本仓的说明在仓库里，wiki 会变成第二份会漂的副本 |

---
