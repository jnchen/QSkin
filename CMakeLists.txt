cmake_minimum_required(VERSION 3.16)
# 项目版本：约定见 CHANGELOG.md 的「版本号约定」一节。
# ⚠ 别把这里和下面各模块的导入版本混为一谈（那是 `import QSkin.X 1.0` 的那个 1.0）。
project(QSkin VERSION 0.0.1 LANGUAGES CXX)

# ─────────────────────────────────────────────────────────────────────────
# QSkin · Quick Design System
#
# 六个 QML 模块：地基（Foundation）/ 契约（Contracts）/ 四套主题。
#
# 构建：
#     cmake -S . -B build -G Ninja \
#           -DCMAKE_PREFIX_PATH=<你的 Qt 安装前缀> \
#           -DCMAKE_C_COMPILER=<mingw>/gcc.exe \
#           -DCMAKE_CXX_COMPILER=<mingw>/g++.exe
#     cmake --build build
#
# 不构建也能直接跑（省一次 configure —— 日常开发走这条）：
#     ./tools/install-qt.sh    # 装一份项目内 Qt 到 .qt/
#     ./tools/lint.sh          # 静态检查，0 警告
#     ./tools/test.sh          # 运行时冒烟测试
#     .qt/*/*/bin/qml -I .cache/qmlimports examples/HelloContracts.qml
#
# ── 为什么没有「QML2_IMPORT_PATH=src 直接跑」这条捷径 ──────────────────
# QML 是按 **URI 路径** 找模块的：import QSkin.Foundation 1.0 会去
#     <importPath>/QSkin/Foundation/qmldir
# 而源码目录叫 src/foundation，名字对不上，直接跑会报
#     Failed to import QSkin.Foundation. Are your import paths set up properly?
# 走 CMake 时 qt_add_qml_module 会帮你做这层映射；脱离构建跑的话，
# tools/ 下的脚本会先在 .cache/qmlimports 搭一份目录名与 URI 匹配的副本。
#
# 注意：qt_add_qml_module 会在构建目录生成自己的 qmldir，**不读**源码目录
#       里的那一份。源码 qmldir 是给上面那条直跑路径用的，两条路互不影响。
#       这句话有后果，见下面「两份 qmldir 的落差」。
#
# ═════════════════════════════════════════════════════════════════════════
# M28 · 这份文件修了什么（以及为什么之前一直是坏的）
# ═════════════════════════════════════════════════════════════════════════
#
# 它原来写着「M0 地基层 + M1 契约层（五个插槽 + 六个控件）」，列了 27 条
# 路径。而 tools/ 那套直跑路线一直工作良好，于是**没有人跑过官方构建路径**
# —— 也就没有人发现它已经烂了。这正是本项目最熟悉的那类失败：
#
#                     一个没人跑的东西，看起来一直是好的。
#
# 实测落差：清单 27 条 / 实际 187 个文件；四套主题一个模块都没挂。
#
# 本批做了六件事，前四件是"补"，后两件是"这份文件根本跑不通"：
#
#  [1] QML_FILES 补全到 **177 个 .qml**（原 27 条里还有 1 个 .js 挪走了）
#  [2] 补上四个主题模块（QSkin.Theme.TDesign / AntDesign / ArcoDesign / Shadcn）
#  [3] 10 个 .js 全部列进 RESOURCES（原来只列了 1 个）
#  [4] 17 个 singleton 补 `QT_QML_SINGLETON_TYPE` 声明
#  [5] 补 `QT_QML_OUTPUT_DIRECTORY`（原来多个库目标撞在同一个输出目录）
#  [6] REQUIRES 6.5 → 6.8（打开 QTP0004：为 slots/ 这类子目录生成 qmldir）
#
# ── [5] 为什么必须：Qt 对"库"不追加 URI 路径 ────────────────────────────
# Qt6QmlMacros.cmake 里那段（6.8.3 在第 512 行起）：
#
#     if("${QT_QML_OUTPUT_DIRECTORY}" STREQUAL "")
#         set(arg_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
#         # For libraries, we assume/require that the source directory
#         # structure is consistent with the target path. ...
#         if(is_executable)
#             string(APPEND arg_OUTPUT_DIRECTORY "/${arg_TARGET_PATH}")
#         endif()
#
# 对**库**目标，输出目录就是 `${CMAKE_CURRENT_BINARY_DIR}`、**不追加**目标
# 路径 —— Qt 假定库会用 add_subdirectory 分层。而本文件的六个模块全写在
# 根目录，于是 qdsfoundation 与 qdscontracts 的输出目录都是 `build/`，
# configure 直接 FATAL_ERROR：「Output directory ... is already used by
# another QML module」。**这个错误在 M1 就会出现**（那时已经有两个模块），
# 所以这份文件从写下起就没跑通过一次。
#
# ── [6] 为什么必须：slots/ 子目录需要自己的 qmldir ──────────────────────
# QTP0004（Qt 6.8 引入）管的是这件事：模块里若**有子目录含 .qml**，QML 引擎
# 要从那个子目录里 import 时，该子目录需要一个 qmldir。policy 为 NEW 时
# Qt 自动生成（内容 `prefer :<模块前缀>`）；为 OLD 时只报一条 Author
# Warning 然后什么都不做。
#
# 而 `src/contracts/Slots.qml` 里就有 `import "slots"` —— 也就是说 policy
# 不提上去的话，构建产物里那一行会找不到目录。`REQUIRES 6.8` 是最简单的
# 正确写法；代价是把最低 Qt 版本从 6.5 提到 6.8（本项目实际用 6.8.3）。
#
# ── 两份 qmldir 的落差：两处已知且已裁决 ────────────────────────────────
# 源码 qmldir 是给直跑路径用的，它比 Qt 生成的那份多一样东西：
#
#   17 个 `singleton` 标记。Qt 只从源文件属性（`QT_QML_SINGLETON_TYPE`）读
#   —— 已由 [4] 补上，两边现在**完全一致**。
#
# ── 曾经多出来的第二样：M29 已消掉 ────────────────────────────────────────
#
#   那时 `Row.qml` / `Column.qml` / `Grid.qml` 各注册**两个**类型名
#   （裸名 + QSkin 前缀）。这一样**补不上**：`QT_QML_SOURCE_TYPENAME` 是单值
#   属性，一个文件只能有一个类型名，而 Qt 生成的 qmldir 每个文件只写一行。
#   后果是构建产物里 `QSkinRow` / `QSkinColumn` / `QSkinGrid` 不存在 —— 而它们
#   被大量真代码引用。M28 实测现场：
#
#       examples/HelloContracts.qml:104: QSkinColumn is not a type
#
#   M29 的处置是**把文件改名**（`Row.qml` → `QSkinRow.qml`），不是删掉前缀
#   那一组：这样源侧与构建侧只剩同一个名字，两边不再有差异，也就不需要
#   豁免。改名后 [8] 会对末尾那三条报「过期豁免」—— 那正是它在工作
#   （豁免必须能复位），于是它们被删掉了，账记在这里。
#
# ── 这份清单是**手写**的，且由闸守着 ────────────────────────────────────
# 不用 file(GLOB) 自动收集：那样"清单 vs 实际"永远相等，闸就成了恒真式
# （判据空转）。清单手写、闸独立扫两侧比对，才有真实的失败模式。
#
# 改这个文件之后必须跑：  ./tools/check-build-manifest.sh
# 它判七件事：悬空 / 漏列 / 重复 / 归属 / 模块 / 单例 / 别名（外加"解析"
# 与"查了 0 条"两条兜底）。**每加一个控件、每加一套主题，都要来补这里。**
# ─────────────────────────────────────────────────────────────────────────

find_package(Qt6 6.8 REQUIRED COMPONENTS
    Quick
    QuickControls2
    QuickLayouts
)

# REQUIRES 6.8 而不是 6.5：见上面 [6]。这一句会决定 QTP0001（资源前缀
# `/qt/qml`）与 QTP0004（子目录 qmldir）的取值，两者都必须是 NEW。
qt_standard_project_setup(REQUIRES 6.8)

# 模块输出根目录。必须是绝对路径（Qt 会 FATAL_ERROR 拦下相对路径），
# 且必须显式给 —— 否则多个库目标撞在 ${CMAKE_CURRENT_BINARY_DIR}。
# 给了之后每个模块落在 <build>/qml/<URI 路径>，例如
#     build/qml/QSkin/Foundation/
#     build/qml/QSkin/Contracts/
set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")

# ═════════════════════════════════════════════════════════════════════════
# 单例声明（17 个）—— **必须在任何 qt_add_qml_module 之前**
#
# Qt 生成 qmldir 时只问源文件属性（Qt6QmlMacros.cmake:3292），不读源码目录
# 的 qmldir。缺了这一段，17 个单例在构建产物里会全部退化成**普通组件**：
# `Theme.color.xxx` 在非单例上不是"未定义"，是**另一个对象上的成员**，
# 报的错会离现场很远。
#
# 这份名单的**事实来源是各处 qmldir**，由 tools/check-build-manifest.py
# 的 [6] 逐条对账 —— 新加单例忘了写这里，lint 会红。
# ═════════════════════════════════════════════════════════════════════════

set_source_files_properties(
    # QSkin.Foundation
    src/foundation/Theme.qml
    src/foundation/Breakpoints.qml
    src/foundation/DateUtil.qml
    src/foundation/TreeUtil.qml
    src/foundation/MemberOrder.qml
    src/foundation/OverlayStack.qml
    src/foundation/QRCodeEncoder.qml
    src/foundation/ScrollUtil.qml
    src/foundation/FuzzyMatch.qml
    src/foundation/ColorUtil.qml
    src/foundation/MasonryUtil.qml
    src/foundation/CornerUtil.qml
    src/foundation/TextMetricsUtil.qml

    # QSkin.Contracts
    src/contracts/Slots.qml

    # 四套主题
    src/themes/tdesign/TDesign.qml
    src/themes/ant/AntDesign.qml
    src/themes/arco/ArcoDesign.qml
    src/themes/shadcn/Shadcn.qml

    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

# ═════════════════════════════════════════════════════════════════════════
# M0 · Foundation —— UI 无关的地基
#
# 令牌、布局、排版预设、焦点环。刻意不绑定任何设计语言。
#
# 清单顺序是**语义分组**（单例 → 容器 → 排版），不是字母序：这份清单是给
# 人看的（闸只比对集合）。按里程碑分组的完整说明在各模块的 qmldir 里。
# ═════════════════════════════════════════════════════════════════════════

qt_add_qml_module(qdsfoundation
    URI "QSkin.Foundation"
    VERSION 1.0
    QML_FILES
        # 单例：令牌、断点、日期与树算法、成员序、浮层协调、
        # 以及六个"可被独立算路打"的纯函数（QR / 滚动 / 模糊匹配 / 颜色 / 瀑布流 / 圆角）
        src/foundation/Theme.qml
        src/foundation/Breakpoints.qml
        src/foundation/DateUtil.qml
        src/foundation/TreeUtil.qml
        src/foundation/MemberOrder.qml
        src/foundation/OverlayStack.qml
        src/foundation/QRCodeEncoder.qml
        src/foundation/ScrollUtil.qml
        src/foundation/FuzzyMatch.qml
        src/foundation/ColorUtil.qml
        src/foundation/MasonryUtil.qml
        src/foundation/CornerUtil.qml
        src/foundation/TextMetricsUtil.qml

        # 窗口与布局容器
        src/foundation/QSkinWindow.qml
        src/foundation/QSkinRow.qml
        src/foundation/QSkinColumn.qml
        src/foundation/QSkinGrid.qml
        src/foundation/Spacer.qml
        src/foundation/ButtonBar.qml

        # 排版预设与焦点环
        src/foundation/Heading.qml
        src/foundation/Body.qml
        src/foundation/Paragraph.qml
        src/foundation/Caption.qml
        src/foundation/FocusRing.qml

    # ── 为什么 .js 放 RESOURCES 而不是 QML_FILES ─────────────────────────
    # 放 QML_FILES 会被 Qt 当**模块类型**处理：它会为每个 .js 生成一条
    # qmldir 条目，并警告"不是 ECMAScript module、也没有 .pragma library
    # → 会在每个 import 本模块的文档里被重新求值"
    # （Qt6QmlMacros.cmake:3265；这 10 个 .js 确实都没写 pragma）。
    #
    # 它们是**实现细节**，不该出现在模块的公共 API 里。而资源路径两者等价
    # —— Qt 把 arg_QML_FILES 与 arg_RESOURCES 一起交给同一个
    # qt6_add_resources（:3511），所以 `import "ColorUtil.js" as CU` 照常工作。
    RESOURCES
        src/foundation/ColorUtil.js
        src/foundation/CornerUtil.js
        src/foundation/FuzzyMatch.js
        src/foundation/MasonryUtil.js
        src/foundation/QRCodeEncoder.js
        src/foundation/tokens/neutral.js
)

target_include_directories(qdsfoundation PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)

# ═════════════════════════════════════════════════════════════════════════
# M1–M27 · Contracts —— 样式契约层
#
# 五个插槽族（background / contentItem / indicator / overlay / label）
# 加 21 格插槽白名单。逻辑留在这里，视觉下沉到 slots/ 下的 Basic* 实现。
#
# slots/ 里的文件不单独对外，但也必须列进 QML_FILES 编译进模块资源，
# 否则 Slots.qml 里的 `import "slots"` 在构建产物中找不到它们。
#
# 92 个顶层文件按**字母序**列，不按里程碑分组 —— 因为按里程碑的分组说明
# 已经写在 src/contracts/qmldir 里（那份是给人读的，带 M18–M27 的来龙
# 去脉）；这份是给构建看的，字母序便于与 tools/check-build-manifest.py
# 的输出机械比对。
# ═════════════════════════════════════════════════════════════════════════

qt_add_qml_module(qdscontracts
    URI "QSkin.Contracts"
    VERSION 1.0
    QML_FILES
        src/contracts/FloatPlate.qml
        src/contracts/QSkinAffix.qml
        src/contracts/QSkinAlert.qml
        src/contracts/QSkinAlertDialog.qml
        src/contracts/QSkinAnchor.qml
        src/contracts/QSkinAspectRatio.qml
        src/contracts/QSkinAutoComplete.qml
        src/contracts/QSkinAvatar.qml
        src/contracts/QSkinAvatarGroup.qml
        src/contracts/QSkinBackTop.qml
        src/contracts/QSkinBadge.qml
        src/contracts/QSkinBreadcrumb.qml
        src/contracts/QSkinButton.qml
        src/contracts/QSkinButtonGroup.qml
        src/contracts/QSkinCalendar.qml
        src/contracts/QSkinCard.qml
        src/contracts/QSkinCarousel.qml
        src/contracts/QSkinCascader.qml
        src/contracts/QSkinCheckBox.qml
        src/contracts/QSkinCollapse.qml
        src/contracts/QSkinCollapseItem.qml
        src/contracts/QSkinColorPicker.qml
        src/contracts/QSkinCommand.qml
        src/contracts/QSkinComment.qml
        src/contracts/QSkinContextMenu.qml
        src/contracts/QSkinCountdown.qml
        src/contracts/QSkinDatePicker.qml
        src/contracts/QSkinDescriptions.qml
        src/contracts/QSkinDescriptionsItem.qml
        src/contracts/QSkinDialog.qml
        src/contracts/QSkinDivider.qml
        src/contracts/QSkinDrawer.qml
        src/contracts/QSkinDropdown.qml
        src/contracts/QSkinEmpty.qml
        src/contracts/QSkinFloatButton.qml
        src/contracts/QSkinForm.qml
        src/contracts/QSkinFormItem.qml
        src/contracts/QSkinHoverCard.qml
        src/contracts/QSkinImage.qml
        src/contracts/QSkinInput.qml
        src/contracts/QSkinInputGroup.qml
        src/contracts/QSkinInputNumber.qml
        src/contracts/QSkinInputOTP.qml
        src/contracts/QSkinKbd.qml
        src/contracts/QSkinLabel.qml
        src/contracts/QSkinLayout.qml
        src/contracts/QSkinLink.qml
        src/contracts/QSkinList.qml
        src/contracts/QSkinMasonry.qml
        src/contracts/QSkinMentions.qml
        src/contracts/QSkinMenu.qml
        src/contracts/QSkinMenubar.qml
        src/contracts/QSkinNavigationMenu.qml
        src/contracts/QSkinNotification.qml
        src/contracts/QSkinPageHeader.qml
        src/contracts/QSkinPagination.qml
        src/contracts/QSkinPopconfirm.qml
        src/contracts/QSkinPopover.qml
        src/contracts/QSkinProgress.qml
        src/contracts/QSkinQRCode.qml
        src/contracts/QSkinRadio.qml
        src/contracts/QSkinRadioGroup.qml
        src/contracts/QSkinRate.qml
        src/contracts/QSkinResult.qml
        src/contracts/QSkinScrollArea.qml
        src/contracts/QSkinSegmented.qml
        src/contracts/QSkinSelect.qml
        src/contracts/QSkinSidebar.qml
        src/contracts/QSkinSidebarItem.qml
        src/contracts/QSkinSkeleton.qml
        src/contracts/QSkinSlider.qml
        src/contracts/QSkinSpin.qml
        src/contracts/QSkinSplitter.qml
        src/contracts/QSkinStatistic.qml
        src/contracts/QSkinSteps.qml
        src/contracts/QSkinSwitch.qml
        src/contracts/QSkinTable.qml
        src/contracts/QSkinTabs.qml
        src/contracts/QSkinTag.qml
        src/contracts/QSkinTextarea.qml
        src/contracts/QSkinTimePicker.qml
        src/contracts/QSkinTimeline.qml
        src/contracts/QSkinTimelineItem.qml
        src/contracts/QSkinToast.qml
        src/contracts/QSkinToggle.qml
        src/contracts/QSkinToggleGroup.qml
        src/contracts/QSkinTooltip.qml
        src/contracts/QSkinTour.qml
        src/contracts/QSkinTransfer.qml
        src/contracts/QSkinTree.qml
        src/contracts/QSkinTreeSelect.qml
        src/contracts/QSkinUpload.qml
        src/contracts/QSkinWatermark.qml
        src/contracts/Slots.qml
        src/contracts/TimeCell.qml

        # 插槽的默认实现（21 格）
        src/contracts/slots/BasicBreadcrumbSeparator.qml
        src/contracts/slots/BasicButtonBackground.qml
        src/contracts/slots/BasicButtonContent.qml
        src/contracts/slots/BasicCheckIndicator.qml
        src/contracts/slots/BasicChevronIndicator.qml
        src/contracts/slots/BasicInputBackground.qml
        src/contracts/slots/BasicLabel.qml
        src/contracts/slots/BasicProgressTrack.qml
        src/contracts/slots/BasicRadioIndicator.qml
        src/contracts/slots/BasicSegmentThumb.qml
        src/contracts/slots/BasicSelectOverlay.qml
        src/contracts/slots/BasicSliderTrack.qml
        src/contracts/slots/BasicSpinDots.qml
        src/contracts/slots/BasicSpinRing.qml
        src/contracts/slots/BasicStatusGlyph.qml
        src/contracts/slots/BasicStepIndicator.qml
        src/contracts/slots/BasicSwitchIndicator.qml
        src/contracts/slots/BasicTabIndicator.qml
        src/contracts/slots/BasicTimelineDot.qml
        src/contracts/slots/BasicToggleBackground.qml
        src/contracts/slots/BasicTooltipOverlay.qml

    # slots/ 子目录的 qmldir 由 QTP0004 自动生成（见文件头 [6]）。
    DEPENDENCIES
        qdsfoundation
)

target_include_directories(qdscontracts PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)

# ═════════════════════════════════════════════════════════════════════════
# 四套主题
#
# 每套的结构一样：一个 singleton 入口 + 一份令牌表 + 若干插槽实现。
# 主题**不新增插槽**，只替换既有 21 格的实现 —— 所以它们只依赖地基与契约。
#
# 名称与 URI 的对齐关系是刻意反着的（`shadcn` 目录 → `QSkin.Theme.Shadcn`），
# 由各处 qmldir 的 `module` 行定义 —— 闸的 [5] 拿它当事实来源，不靠猜命名。
# ═════════════════════════════════════════════════════════════════════════

# ── TDesign ──────────────────────────────────────────────────────────────
qt_add_qml_module(qdstdesign
    URI "QSkin.Theme.TDesign"
    VERSION 1.0
    QML_FILES
        src/themes/tdesign/TDesign.qml
        src/themes/tdesign/slots/TDButtonBackground.qml
        src/themes/tdesign/slots/TDCheckIndicator.qml
        src/themes/tdesign/slots/TDChevronIndicator.qml
        src/themes/tdesign/slots/TDInputBackground.qml
        src/themes/tdesign/slots/TDLabel.qml
        src/themes/tdesign/slots/TDRadioIndicator.qml
        src/themes/tdesign/slots/TDSelectOverlay.qml
        src/themes/tdesign/slots/TDSpinRing.qml
        src/themes/tdesign/slots/TDTabIndicator.qml
    RESOURCES
        src/themes/tdesign/tokens.js
    DEPENDENCIES
        qdsfoundation
        qdscontracts
)

# ── Ant Design ───────────────────────────────────────────────────────────
qt_add_qml_module(qdsantdesign
    URI "QSkin.Theme.AntDesign"
    VERSION 1.0
    QML_FILES
        src/themes/ant/AntDesign.qml
        src/themes/ant/slots/ADButtonBackground.qml
        src/themes/ant/slots/ADCheckIndicator.qml
        src/themes/ant/slots/ADChevronIndicator.qml
        src/themes/ant/slots/ADInputBackground.qml
        src/themes/ant/slots/ADLabel.qml
        src/themes/ant/slots/ADRadioIndicator.qml
        src/themes/ant/slots/ADSegmentThumb.qml
        src/themes/ant/slots/ADSelectOverlay.qml
        src/themes/ant/slots/ADSpinRing.qml
        src/themes/ant/slots/ADTabIndicator.qml
    RESOURCES
        src/themes/ant/tokens.js
    DEPENDENCIES
        qdsfoundation
        qdscontracts
)

# ── Arco Design ──────────────────────────────────────────────────────────
qt_add_qml_module(qdsarco
    URI "QSkin.Theme.ArcoDesign"
    VERSION 1.0
    QML_FILES
        src/themes/arco/ArcoDesign.qml
        src/themes/arco/slots/ACButtonBackground.qml
        src/themes/arco/slots/ACCheckIndicator.qml
        src/themes/arco/slots/ACChevronIndicator.qml
        src/themes/arco/slots/ACInputBackground.qml
        src/themes/arco/slots/ACLabel.qml
        src/themes/arco/slots/ACSelectOverlay.qml
        src/themes/arco/slots/ACSpinDots.qml
        src/themes/arco/slots/ACTabIndicator.qml
    RESOURCES
        src/themes/arco/tokens.js
    DEPENDENCIES
        qdsfoundation
        qdscontracts
)

# ── shadcn ───────────────────────────────────────────────────────────────
qt_add_qml_module(qdsshadcn
    URI "QSkin.Theme.Shadcn"
    VERSION 1.0
    QML_FILES
        src/themes/shadcn/Shadcn.qml
        src/themes/shadcn/slots/SCButtonBackground.qml
        src/themes/shadcn/slots/SCCheckIndicator.qml
        src/themes/shadcn/slots/SCChevronIndicator.qml
        src/themes/shadcn/slots/SCInputBackground.qml
        src/themes/shadcn/slots/SCLabel.qml
        src/themes/shadcn/slots/SCRadioIndicator.qml
        src/themes/shadcn/slots/SCSelectOverlay.qml
        src/themes/shadcn/slots/SCSpinRing.qml
        src/themes/shadcn/slots/SCStatusGlyph.qml
        src/themes/shadcn/slots/SCTabIndicator.qml
        src/themes/shadcn/slots/SCToggleBackground.qml
    RESOURCES
        src/themes/shadcn/tokens.js
    DEPENDENCIES
        qdsfoundation
        qdscontracts
)

# ═════════════════════════════════════════════════════════════════════════
# 别名豁免 —— **M29 已结清，这里不再有豁免行**（保留本段当账）
#
# 原状：`src/foundation/{Row,Column,Grid}.qml` 在 qmldir 里各注册两个类型名
# （裸名 + QSkin 前缀）。Qt 生成的 qmldir 每个文件只写一行，而
# `QT_QML_SOURCE_TYPENAME` 是单值属性 —— "一个文件两个名字"在这一侧
# 表达不出来。
#
# 后果：构建产物里 `QSkinRow` / `QSkinColumn` / `QSkinGrid` **不存在**，而几十个
# 契约文件在用它们（`QSkinAlert.qml:143` 那种是真代码）。M28 实测现场：
# `examples/HelloContracts.qml:104: QSkinColumn is not a type`。
#
# 这三条曾以 `# manifest-gate: alias <路径>` 的**显式豁免**留在明处，由
# tools/check-build-manifest.py 的 [8] 当账目守着。M29 的处置是**把文件
# 改名**成 `QSkinRow.qml` / `QSkinColumn.qml` / `QSkinGrid.qml`，于是源侧与构建侧
# 只剩同一个名字 —— 豁免不再有必要，[8] 随即报「过期豁免」，三条被删掉。
#
# 这正是当初把它写成豁免而不是一句注释的理由：**注释不会红，豁免会过期**。
# [8] 判据本身留着 —— 它现在守的是"以后不要再长出第二个名字"。
# ═════════════════════════════════════════════════════════════════════════

