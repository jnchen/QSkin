#!/usr/bin/env bash
#############################################################################
# QSkin · QML 静态检查
#
# 用法：
#     ./tools/lint.sh                 # 检查全部 QML
#     ./tools/lint.sh src/foundation  # 只检查某个目录
#
# ── 为什么需要先搭一份临时 import 树 ──────────────────────────────────────
# QML 引擎是按 **URI 路径** 找模块的：import QSkin.Foundation 1.0 会去
#     <importPath>/QSkin/Foundation/qmldir
# 而我们的源码目录叫 src/foundation，名字对不上，直接跑 qmllint 会报
#     Failed to import QSkin.Foundation. Are your import paths set up properly?
#
# 走 CMake 时 qt_add_qml_module 会帮你做这层映射；但静态检查想脱离构建跑，
# 就得自己搭一份 URI 与目录匹配的副本。复制到 .cache/qmlimports 下即可，
# 文件都很小，每次重建成本可以忽略。
#############################################################################

set -euo pipefail
cd "$(dirname "$0")/.."

# ---------- 1. 定位 Qt ----------
QT_ROOT="${QSkin_QT:-}"
if [ -z "$QT_ROOT" ]; then
    for d in .qt/*/*/; do
        [ -x "${d}bin/qmllint" ] && QT_ROOT="$d" && break
    done
fi

QMLLINT="$QT_ROOT/bin/qmllint"
if [ ! -x "$QMLLINT" ]; then
    echo "找不到 qmllint。"
    echo "请先跑 ./tools/install-qt.sh，或设置 QSkin_QT=/path/to/qt/gcc_64"
    exit 1
fi

# ---------- 2. 搭 import 树 ----------
# 用 mv + 重建而不是 rm -rf —— 整批删除会触发环境的批量删除确认钩子，
# 把脚本卡死在确认框上（同 tools/test.sh / shot.sh 的处理）。
if [ -d .cache/qmlimports ]; then
    mv .cache/qmlimports ".cache/qmlimports.stale.$(date +%s)" 2>/dev/null || true
fi
mkdir -p .cache/qmlimports/QSkin
cp -r src/foundation .cache/qmlimports/QSkin/Foundation
cp -r src/contracts  .cache/qmlimports/QSkin/Contracts

# 主题层：URI 是 QSkin.Theme.TDesign，源码目录叫 src/themes/tdesign，
# 同样需要按 URI 铺一份。多主题时在这里加一行即可。
# 主题层：src/themes/<dir> 按 URI 铺成 QSkin.Theme/<Name>
mkdir -p .cache/qmlimports/QSkin/Theme
for d in src/themes/*/; do
    name=$(basename "$d")
    case "$name" in
        tdesign) uri=TDesign ;;
        ant)     uri=AntDesign ;;
        arco)    uri=ArcoDesign ;;
        shadcn)  uri=Shadcn ;;
        *)       uri="$name" ;;
    esac
    cp -r "$d" ".cache/qmlimports/QSkin/Theme/$uri"
done

# ---------- 3. 收集文件 ----------
if [ $# -gt 0 ]; then
    FILES=$(find "$@" -name "*.qml" | sort)
else
    FILES=$(find src examples tests -name "*.qml" | sort)
fi

COUNT=$(echo "$FILES" | wc -l | tr -d ' ')
echo "==> qmllint $($QMLLINT --version | awk '{print $2}')  ·  $COUNT 个文件"

# ---------- 4. 检查 ----------
set +e
OUT=$("$QMLLINT" -I .cache/qmlimports $FILES 2>&1)
CODE=$?
set -e

WARNINGS=$(echo "$OUT" | grep -c '^Warning:' || true)

echo "$OUT" | grep '^Warning:' | sed 's/^Warning: //' | sort | uniq -c | sort -rn || true

echo ""
if [ "$WARNINGS" -eq 0 ]; then
    echo "✓ 通过：$COUNT 个文件，0 警告"
else
    echo "✗ $WARNINGS 个警告"
fi

# ---------- 5. 字符图标门禁（M15.1）----------
# qmllint 管不到这条：`text: "更多操作 ▾"` 是**合法 QML**，静态检查一个字都不会说。
# 但项目规矩是图标不许用字形（字体覆盖率与回退链不可控）。规矩写在四个文件头里，
# 仍然在三个地方被违反过 —— 说明只靠注释不够，得有个会红的东西。
# 详见 tools/scan-glyph-icons.py 头部。
echo ""
SCAN="tools/scan-glyph-icons.sh"
ICON_CODE=0
if [ -x "$SCAN" ]; then
    "$SCAN" || ICON_CODE=$?
else
    echo "（跳过字符图标扫描：$SCAN 不存在或没有执行权限）"
fi

# ---------- 6. Shape 渲染器门禁（M16.1）----------
# 这条也是 qmllint 管不到的：`Shape { }` 不带 preferredRendererType 是
# **完全合法的 QML**，只是斜边会渲染成硬边阶梯。而且 `Shape.antialiasing`
# 在 Qt 6 里已是死属性 —— 写了不报错、也不生效，反而让人以为已经处理过。
# 本轮 18 个 Shape 里 8 个是这么写的、另外 10 个连这行都没有，
# 于是所有勾、箭头、排序三角都带着锯齿。详见 tools/check-shape-aa.py 头部。
echo ""
SHAPE_SCAN="tools/check-shape-aa.sh"
SHAPE_CODE=0
if [ -x "$SHAPE_SCAN" ]; then
    "$SHAPE_SCAN" || SHAPE_CODE=$?
else
    echo "（跳过 Shape 渲染器检查：$SHAPE_SCAN 不存在或没有执行权限）"
fi

# ---------- 7. 未定义函数门禁（M20.1）----------
# 也是 qmllint 管不到的。M20 有一份底板写成 `isOn()` 而没写 `function isOn()`：
# 调用未定义函数抛 ReferenceError → `color: d.bg()` 这条**绑定**失效 →
# 整个按钮停在 Rectangle 的默认色（实测 Basic 是 #ffffff，一块白砖）。
# 29 个 smoke 文件全绿，qmllint 退出码 0 —— 只有真鼠标事件那条读颜色的
# 测试把它揪了出来。顺便守住"块注释被 `星号+斜杠` 提前闭合"（同一轮里
# 那处让整棵 import 树 29 个文件全红）。
# 详见 tools/check-undefined-fn.py 头部。
echo ""
FN_SCAN="tools/check-undefined-fn.sh"
FN_CODE=0
if [ -x "$FN_SCAN" ]; then
    "$FN_SCAN" || FN_CODE=$?
else
    echo "（跳过未定义函数扫描：$FN_SCAN 不存在或没有执行权限）"
fi

# ---------- 8. comprehension 作用域门禁（M23.1）----------
# 前七道都是 QML 侧的。这一道管 **Python 工具链**（tools/ 与 .cache/ 的
# 变异脚本 + 像素核验器）—— 那里的推导式密度最高，而没有人 review 它们。
#
# 病是 M23 真撞到的：`.cache/_verify_m23.py` 里写过
#       [x / DPR for _x, _y, c in ... if is_dv(c)]
# 绑 `_x` 却用 `x`。**列表推导的表达式只对"通过过滤器的元素"求值**，
# 于是画面对的时候它一次都不求值（静默通过），画面错的时候抛 NameError
# 把整个核验器崩掉 —— 那条断言从写下起就没跑过，而它恰好是
# QSkinTimelineItem 文件头点名最值钱的一条。
#
# 它原来是住在 .cache/ 里的，本轮升格过来：**一个住在可丢弃目录里的闸
# 不算闸**（clean-cache.sh --all 一次就清掉了）。升格时顺手补掉一个缺陷
# —— 它原本只认顶层 Assign，在模块级 for 循环里的推导式上误报 16 处。
# 详见 tools/check-comprehension-scope.py 头部。
echo ""
CS_SCAN="tools/check-comprehension-scope.sh"
CS_CODE=0
if [ -x "$CS_SCAN" ]; then
    "$CS_SCAN" || CS_CODE=$?
else
    echo "（跳过 comprehension 作用域扫描：$CS_SCAN 不存在或没有执行权限）"
fi

# ---------- 9. 令牌名门禁（M25.1）----------
# `Theme.color` 是 `property var`（令牌集合可被 install() 整体替换），
# 于是 qmllint **拿不到成员表**：写错的令牌名不是语法错也不是成员错，
# 只是 undefined —— 那一块不画了，而 lint 依然退出 0。这是 M18 那次
# "divider 整屏不可见、属性断言一片绿"事故的另一半（那次名字对、值不对）。
#
# M25 一句都没提令牌名检查，是写 QSkinBackTop 时意识到"我这一批有 2054 处
# `Theme.<组>.<名>`"才回头补的 —— 补之前先做了个一次性核对器，拿到
# 139 处报警，逐条看下来发现其中 135 处是**解析器自己的 bug**
# （JS 对象最后一个成员不带逗号，我的收尾正则写死了 `},`）。剩下
# 4 处是 tdesign 有意保留的刻度档，于是给它加了 `token-gate: extend`
# 这条显式声明 —— 决定要写在源文件里，而不是把闸改成警告。
# 详见 tools/check-tokens.py 头部。
echo ""
TOK_SCAN="tools/check-tokens.sh"
TOK_CODE=0
if [ -x "$TOK_SCAN" ]; then
    "$TOK_SCAN" || TOK_CODE=$?
else
    echo "（跳过令牌名扫描：$TOK_SCAN 不存在或没有执行权限）"
fi

# ---------- 10. 变异残留审计（M26 收口）----------
# 前九道判的都是"代码写得好不好"。这一道判的是**另一件事**：
#   `src/` 里此刻装的到底是「原文」还是「改坏成」那一份？
#
# 病是 M21 收口当天实测到的：`mutate_m20_px.py` 的一次运行中途被杀（硬杀，
# `finally` 一行都不执行），把 `src/contracts/QSkinLabel.qml` 的
#       visible: root.required   →   visible: true
# 留在了源码里 —— 症状是本项目最熟悉的那个形状：`required` 属性读出来完全
# 正确，而屏幕上每个标签都带着一颗红星（**属性对、界面全错**）。
#
# 它当时没人发现，因为 **"跑过门禁"有时间窗口**：lint 看不见（`visible: true`
# 完全合法），唯一能看见它的 `smoke_m20.qml [4]` 确实红了 —— 但上一次跑
# test.sh 是在变异**之前**。处置不是"以后记得再跑一次"（记不住的），
# 而是**直接问源码要答案** —— 就是这一步。
#
# 它原本住在 `.cache/_audit_residue.py`，本轮升格过来：**一个住在可丢弃
# 目录里的闸不算闸**（同 comprehension 作用域门禁的先例，理由逐字相同）。
# 带 `--all`：变异也会落在 `examples/` / `tests/` 上（M26 的 P7x 就打在示例屏上）。
# 详见 tools/check-mutation-residue.py 头部。
echo ""
RES_SCAN="tools/check-mutation-residue.sh"
RES_CODE=0
if [ -x "$RES_SCAN" ]; then
    "$RES_SCAN" --all || RES_CODE=$?
else
    echo "（跳过变异残留审计：$RES_SCAN 不存在或没有执行权限）"
fi

# ---------- 11. 构建清单门禁（M28）----------
# 前九道判的是"代码写得好不好"，第十道判的是"源码里装的是原文还是改坏成"，
# 这一道判的是第三件事：**别人按官方路径构建时，拿到的到底是不是完整的库？**
#
# 病是 M28 开工实测到的：`CMakeLists.txt` 里列着 27 条路径，而 `src/` 下
# 真实的 QML/JS 有 **187** 个；四套主题**一个模块都没挂**。它从 M1 之后
# 就没改过，而 `tools/` 那套直跑路线一直好用 —— 于是没人跑过 cmake，
# 也就没人发现。**一个没人跑的东西，看起来一直是好的。**
#
# 它顺带守住了两处"两份 qmldir 的落差"（源码那份比 Qt 生成的多东西）：
#   · 17 个 singleton 标记（Qt 只认源文件属性 QT_QML_SINGLETON_TYPE）
#   · Row/Column/Grid 各两个类型名（QT_QML_SOURCE_TYPENAME 是单值，补不上
#     → 以 `manifest-gate: alias` 显式豁免，M29 到期）
#
# 清单是**手写**的，闸独立扫两侧比对 —— 刻意不用 file(GLOB)：那样两边
# 永远相等，闸就成了恒真式。详见 tools/check-build-manifest.py 头部
# （八条判据 + 七枪证伪法）。
echo ""
MAN_SCAN="tools/check-build-manifest.sh"
MAN_CODE=0
if [ -x "$MAN_SCAN" ]; then
    "$MAN_SCAN" || MAN_CODE=$?
else
    echo "（跳过构建清单检查：$MAN_SCAN 不存在或没有执行权限）"
fi

# ---------- 12. i18n 门禁（M33）----------
# 前九道判"代码写得好不好"，第十道判"源码里装的是原文还是改坏成"，
# 第十一道判"别人按官方路径构建时拿到的到底是不是完整的库"，
# 这一道判第四件事：**这份源码能不能被翻译。**
#
# 三道判据（新增即红 / 修了要销账 / 资产同步）与三条硬约束（算力层禁 qsTr、
# 拼接必须给占位符、`.qm` 随源码入库）写在 tools/check-i18n.py 头部 —— 那里
# 是唯一说明处，不在这里抄。
#
# ⚠ 缺 lupdate/lrelease 时它报**工装错误**（退出码含 8），不是跳过。
#   理由：判据 3 量不出 = 这一层没在防 = 不算通过。
echo ""
I18N_SCAN="tools/check-i18n.sh"
I18N_CODE=0
if [ -x "$I18N_SCAN" ]; then
    "$I18N_SCAN" || I18N_CODE=$?
else
    echo "（跳过 i18n 检查：$I18N_SCAN 不存在或没有执行权限）"
fi

# ---------- 13. 发布面泄露门禁（M34）----------
# 第十二段判"这份源码能不能被翻译"，这一道判第五件事：
# **会随发行版发布的四份文档里，有没有留下只在开发机上成立的东西。**
#
# 三类（本机路径与个人标识 / 本机一次性件名 / 本机工具链路径细节）与两条
# "故意不查"的理由（`\\\\host\\share` 为什么查不了、`aqtinstall` 为什么不算）
# 都写在 `tools/check-doc-leak.py` 头部与 `build_patterns()` —— 那里是唯一说明处。
#
# ⚠ 缺发布文档时它报**工装错误**（退出码含 8），不是跳过 ——
#   判据的输入没了，不等于"没问题"。
echo ""
DOC_SCAN="tools/check-doc-leak.sh"
DOC_CODE=0
if [ -x "$DOC_SCAN" ]; then
    "$DOC_SCAN" || DOC_CODE=$?
else
    echo "（跳过发布面泄露检查：$DOC_SCAN 不存在或没有执行权限）"
fi

# ---------- 14. 公开类型清单对账 ----------
# `tests/ContractManifest.js` 是**由 qmldir 生成的**。它一旦与 qmldir 脱节，
# 宿主对账就会「全绿，但少测了几个类型」—— 门绿着、覆盖悄悄缩水，
# 而且不会有任何东西喊。这道闸替它喊。
#
# 规则与「内部件名单过期」的检查都在 `tools/gen-contract-manifest.py`
# 与包装器 `tools/check-contract-manifest.sh` 里，那里是唯一说明处。
echo ""
MF_CODE=0
MANIFEST_SCAN="tools/check-contract-manifest.sh"
if [ -x "$MANIFEST_SCAN" ]; then
    "$MANIFEST_SCAN" || MF_CODE=$?
else
    echo "（跳过清单对账：$MANIFEST_SCAN 不存在或没有执行权限）"
fi

# ---------- 15. Qt 5 产物漂移门 ----------
# 上面 14 段扫的全是 src/。这一道扫的是**另一棵树的健康度**：
# qt5/ 是入库的降级产物，src/ 改了却不重跑生成器，它会悄悄陈旧 —— 而
# lint 照样全绿、生成器自带的"命中数对账"也照样全 OK。
#
# 判据（逐文件 sha256 比对：新增 / 残留 / 内容不同）与修法写在
# `tools/check-qt5-drift.sh` 与 `tools/qml-downgrade.py` 的 `--check` 分支。
echo ""
QT5_CODE=0
QT5_SCAN="tools/check-qt5-drift.sh"
if [ -x "$QT5_SCAN" ]; then
    "$QT5_SCAN" >/dev/null || QT5_CODE=$?
    if [ "$QT5_CODE" -ne 0 ]; then
        echo "✗ Qt 5 产物漂移（重跑一遍看明细：./$QT5_SCAN 输出很长，这里折叠）"
        "$QT5_SCAN" 2>&1 | grep -E "RESULT|漂移|残留|内容不同|新增|修法|工装" | head -20
    else
        echo "✓ Qt 5 产物与 src/ 一致（逐文件 sha256 比对）"
    fi
else
    echo "（跳过 Qt 5 漂移检查：$QT5_SCAN 不存在或没有执行权限）"
fi

# ---------- 16. 发布面读数对账门 ----------
# 上面 15 段扫的是**代码**。这一道扫的是**文档里的数字**：
# README / COVERAGE / GITHUB 里的读数全是手写的，手写的数字必然漂 ——
# 2026-10-03 手工核对就抓到「同一份 README 里 11 道与 9 道并存」
# 「架构图写 5 组插槽而实测 8/10/8/11」这类不一致。
#
# 做法是**从源码复算真值 → 逐份发布面文档对账**，边界与修法写在
# `tools/check-doc-readout.sh` 头部。
echo ""
RD_CODE=0
RD_SCAN="tools/check-doc-readout.sh"
if [ -x "$RD_SCAN" ]; then
    "$RD_SCAN" >/dev/null || RD_CODE=$?
    if [ "$RD_CODE" -ne 0 ]; then
        echo "✗ 发布面读数对账（看明细：./$RD_SCAN）"
        "$RD_SCAN" 2>&1 | grep -E "✗|真值|对不上" | head -16
    else
        echo "✓ 发布面读数与源码一致（9 项逐份对账）"
    fi
else
    echo "（跳过发布面读数对账：$RD_SCAN 不存在或没有执行权限）"
fi

if [ "$WARNINGS" -eq 0 ] && [ "$ICON_CODE" -eq 0 ] && [ "$SHAPE_CODE" -eq 0 ] \
        && [ "$FN_CODE" -eq 0 ] && [ "$CS_CODE" -eq 0 ] && [ "$TOK_CODE" -eq 0 ] \
        && [ "$RES_CODE" -eq 0 ] && [ "$MAN_CODE" -eq 0 ] && [ "$I18N_CODE" -eq 0 ] \
        && [ "$DOC_CODE" -eq 0 ] && [ "$MF_CODE" -eq 0 ] && [ "$QT5_CODE" -eq 0 ] \
        && [ "$RD_CODE" -eq 0 ]; then
    exit 0
fi
exit 1
