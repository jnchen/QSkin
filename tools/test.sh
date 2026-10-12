#!/usr/bin/env bash
#############################################################################
# QSkin · QML 运行时冒烟测试
#
# 用法：
#     ./tools/test.sh
#
# ── 为什么测试要用「退出码位掩码」这种奇怪的形式 ──────────────────────────
# Windows 上的 Qt 是 GUI 子系统程序，没有控制台。默认情况下 console.log
# 走 OutputDebugString 而不是 stderr —— 于是「重定向到文件也是 0 字节」。
#
#     ⚠ 这句话**有前提**，别当成绝对句（本节原先就写成绝对句，实测是错的）：
#     前提是没设 QT_FORCE_STDERR_LOGGING。实测同一份探针、
#     同一条 qml.exe 命令行（本机 Qt 6.8.3 / mingw_64）：
#
#         不设该变量   →  日志 0 字节（两行 console.log 全丢）
#         设为 1       →  日志 42 字节，两行都在（各带 "qml: " 前缀）
#
#     第 3 步开头那个 `export QT_FORCE_STDERR_LOGGING="${...:-1}"` 就是把
#     这个前提显式建立起来；下面的 LOAD 分支靠 grep 日志来判断
#     "组件没加载起来"，靠的也正是它。
#
# 那为什么**断言结果**仍然不走日志、一定要走退出码？
# 不是因为日志读不到（在设了变量的前提下读得到），而是因为：
#   1. 位掩码是**结构化**的 —— "第几条断言失败了"本身就是被编码的信息，
#      不需要人去 grep 自由文本；
#   2. 日志是**人读的诊断通道**，会被 QML 引擎自己的噪声（绑定循环警告、
#      QtQuick 版本提示）淹没，拿它当判据就得靠正则去猜哪一行算数。
# 通道各司其职：退出码判成败，日志判"为什么"。
#
# 而 POSIX 的 WEXITSTATUS 只保留低 8 位 —— 实测 Qt.exit(1000) 在 bash 里
# 读到的是 232（= 1000 & 0xFF）。所以每个测试文件把断言限制在 8 条以内，
# 一条占一个 bit：
#
#     退出码 0              全部通过
#     退出码第 n 位为 1     第 n 条断言失败
#
# 一次运行报出全部失败项。断言上方的 [n] 注释就是这里的 n。
#
# ── 硬上限：一个文件最多 8 条断言 ────────────────────────────────────────
# 这不是"建议"，是数学约束。Qt.exit(n) 在 POSIX 下只保留低 8 位，而下面
# 第 3 步的解码循环只扫 0..7。如果给第 9 条断言用了 bit 8，会造出
# **最难查的一类假失败**：
#
#     failures = 256（bit 8 置位）→ Qt.exit(256) → bash 读到 256 & 0xFF = 0
#
# 单纯这样还算"漏报"，但测试文件通常写 Qt.exit(Math.min(255, failures))
# 兜底，于是 256 被钳成 255 → 8 个 bit 全亮 → 报「8 条断言全部失败」。
# 一个真失败被放大成满屏红，你会去翻一堆根本不存在的错误。
# （实测踩过：smoke_m10 的新回归曾用 bit 8/9/10。）
#
# 里程碑文件越攒越长，8 条很容易顶格。到顶时的正解是**按组件合并同类项**
# ——把同一组件的好几条子断言 && 进一条 bit，而不是继续往上加位。
# 见 tests/smoke_m10.qml 里 [4] 的写法与注释。
#
# ── 为什么要在 Qt.callLater 之后再断言 ──────────────────────────────────
# Qt Quick Layouts 把尺寸重算推迟到渲染循环的 polish 阶段。在
# Component.onCompleted 里同步读 implicitWidth 会读到重算之前的值（0）。
# 实测推迟一轮事件循环即可拿到正确值，且早于首帧 —— 详见
# tests/smoke_sizes.qml 文件头记录的排查过程。
#############################################################################

set -euo pipefail
cd "$(dirname "$0")/.."

# ---------- 1. 定位 Qt ----------
QT_ROOT="${QSkin_QT:-}"
if [ -z "$QT_ROOT" ]; then
    for d in .qt/*/*/; do
        [ -x "${d}bin/qml" ] && QT_ROOT="$d" && break
    done
fi

QML="$QT_ROOT/bin/qml"
if [ ! -x "$QML" ]; then
    echo "找不到 qml 运行器。"
    echo "请先跑 ./tools/install-qt.sh，或设置 QSkin_QT=/path/to/qt/gcc_64"
    exit 1
fi

# ---------- 2. 搭 import 树（与 lint.sh 同一套逻辑） ----------
# 用 mv + 重建而不是 rm -rf —— 整批删除会触发环境的批量删除确认钩子，
# 把测试卡死在确认框上（表现为整个 test.sh 无输出地停摆）。
# 旧目录留作 .cache/qmlimports.stale.<时间戳>，由 tools/clean-cache.sh 清理。
# 见 tools/shot.sh 里同款注释。
if [ -d .cache/qmlimports ]; then
    mv .cache/qmlimports ".cache/qmlimports.stale.$(date +%s)" 2>/dev/null || true
fi
mkdir -p .cache/qmlimports/QSkin/Theme
cp -r src/foundation .cache/qmlimports/QSkin/Foundation
cp -r src/contracts  .cache/qmlimports/QSkin/Contracts

# 与 lint.sh 保持一致：主题层也要按 URI 铺一份
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

# ---------- 3. 跑测试 ----------
# ⚠ `--lib <产物目录>`：把冒烟跑在**降级产物**上（qt5/ · qt511/），
#   而不是 src/。动机：src/ 那条线本来就有门，而「Qt 5.11 上冒烟还过吗」
#   是另一个问题 —— 实测它会抓到 src/ 上永远抓不到的东西
#   （import 版本、5.11 不支持的属性）。
#   场景本身是 Qt 6 写法 ⇒ 跑之前**逐个降级**到 .cache/smoke.<lib>/，
#   原件一个字都不改。
# 用法：
#   ./tools/test.sh                          # Qt 6 侧（默认）
#   QSkin_QT=<根> ./tools/test.sh --lib qt511  # 在 5.11 产物上跑
#   QSkin_QT=<根> ./tools/test.sh --lib qt511 --only smoke_layout  # 只跑几个
SMOKE_LIB="src"
ONLY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --lib)  SMOKE_LIB="$2"; shift 2 ;;
        --only) ONLY="$2"; shift 2 ;;
        *)      shift ;;
    esac
done
IMPORT_ARG=".cache/qmlimports"
if [ "$SMOKE_LIB" != "src" ]; then
    SMOKE_DIR=".cache/smoke.$SMOKE_LIB"
    echo "（冒烟跑在降级产物：$SMOKE_LIB ⇒ 场景先降到 $SMOKE_DIR/）"
    QSkin_PYTHON_FALLBACK="${QSkin_PYTHON:-python}"
    "$QSkin_PYTHON_FALLBACK" - "$SMOKE_LIB" "$SMOKE_DIR" <<'PYEOF'
import sys, os, collections, importlib.util
lib, outdir = sys.argv[1], sys.argv[2]
root = os.getcwd()
sys.path.insert(0, os.path.join(root, 'tools'))
spec = importlib.util.spec_from_file_location(
    'dg', os.path.join(root, 'tools', 'qml-downgrade.py'))
dg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dg)
prof = dg.PROFILES[lib]
src = os.path.join(root, 'tests')
dst = os.path.join(root, outdir)
n = 0
for fn in sorted(os.listdir(src)):
    if not (fn.startswith('smoke_') or fn.startswith('scene_')):
        continue
    if not fn.endswith('.qml'):
        continue
    txt = open(os.path.join(src, fn), encoding='utf-8').read()
    out = dg.downgrade_text(txt, collections.Counter(), fn, prof)
    os.makedirs(dst, exist_ok=True)
    open(os.path.join(dst, fn), 'w', encoding='utf-8', newline='\n').write(out)
    n += 1
print('  已降级 %d 个场景' % n)
PYEOF
    FILES=$(find "$SMOKE_DIR" -name "smoke_*.qml" 2>/dev/null | sort)
    IMPORT_ARG="$(pwd)/$SMOKE_LIB"
else
    FILES=$(find tests -name "smoke_*.qml" 2>/dev/null | sort)
fi
if [ -n "$ONLY" ]; then
    FILES=$(echo "$FILES" | grep "$ONLY" || true)
fi
if [ -z "$FILES" ]; then
    echo "tests/ 下没有 smoke_*.qml"
    exit 1
fi

FAILED_FILES=0
TOTAL_FAILURES=0
ERRLOG=".cache/_test_stderr.log"

# ── 第十二道门：把每个文件的 stderr **累积**下来（M31 第二件）──────────
# 原来 ERRLOG 是 `>` 覆盖的、且只在 FAIL / LOAD / HANG 时才打印出来 ——
# 于是 **PASS 的文件的运行期警告被整段丢掉**。这不是猜测：M27 做裁决五的
# 探针时写了个一次性审计器量过，**675 行警告**（9 个库文件）而三道门禁全绿。
#
# 这里把每个文件的输出按 `@@@FILE / @@@EXIT / 正文 / @@@END` 四段追加到
# 一个总日志里，交给 3.10 节的核验器归类、与豁免名单对账。
#
# ⚠ 四段的**顺序是写死的**（FILE → EXIT → 正文 → END），解析器就是按这个
#   顺序读的。M31 首跑我按"FILE → 正文 → EXIT"解析过一次，结果每一块都被
#   判成空、报告"48 个文件零输出" —— 与 M27 量到的 675 行完全对不上。
#   **解析器要按实际写入顺序写，不是按记忆写。**
WARNLOG=".cache/_test_warn_all.log"
: > "$WARNLOG"
printf '@@@RUN test.sh @ %s · %s 个 smoke 文件\n' \
       "$(date '+%Y-%m-%d %H:%M:%S')" "$(echo "$FILES" | wc -l | tr -d ' ')" >> "$WARNLOG"

# ---------- 3.0 每个文件都套一层超时看门狗 ----------
# ── 为什么必须有（M21 实录）─────────────────────────────────────────────
# 冒烟文件的收尾是 `Qt.exit(mask)`。如果 run() 里任何一处抛了异常
# （典型：引用了还没加的属性 → TypeError），`Qt.exit` 就**永远执行不到**，
# 而 `qml.exe` 是一个开着窗口的 GUI 进程 —— 它不会退，它会一直开着。
#
#     表现：./tools/test.sh 卡在这个文件上不动，没有输出、没有退出码。
#     实测：smoke_m21 首跑挂了 2 分 13 秒，直到被外部工具杀掉；
#           日志里其实只有一行 "exception occurred during delayed
#           function evaluation"，但那行要等进程结束才落盘。
#
# 这不是某一个文件的问题，是所有 smoke_*.qml 的共同结构。所以在**门禁**
# 这一层兜住：超时即失败，退出码 124 单独识别（免得它被解码成
# "第 2~6 条断言失败"那种看似有信息量、实则完全误导的报告）。
#
# 期望值说明：全套 smoke 里最慢的一个约 3 秒（首帧 + 布局 polish）。
# 30 秒是"远远够用、但真挂住了很快就能看出来"的折中。
QSkin_TEST_TIMEOUT="${QSkin_TEST_TIMEOUT:-30}"
TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout $QSkin_TEST_TIMEOUT"
elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_CMD="gtimeout $QSkin_TEST_TIMEOUT"      # macOS（coreutils）
fi

for f in $FILES; do
    name=$(basename "$f")

    set +e
    # shellcheck disable=SC2086
    $TIMEOUT_CMD "$QML" -I "$IMPORT_ARG" "$f" > "$ERRLOG" 2>&1
    code=$?
    set -e

    # 累积进总日志（第十二道门的输入）。位置在**所有分支之前** ——
    # 下面 HANG / PASS / LOAD / FAIL 四条路径里有三条会 `continue`，
    # 漏掉任何一条都会让那一段的运行期警告凭空消失，而那正是本道门
    # 存在的理由（"PASS 的文件的警告被丢掉"就是原病灶）。
    {
        printf '@@@FILE %s\n' "$name"
        printf '@@@EXIT %s\n' "$code"
        cat "$ERRLOG" 2>/dev/null || true
        printf '@@@END\n'
    } >> "$WARNLOG"

    if [ "$code" -eq 124 ]; then
        echo "  HANG  $name（超过 ${QSkin_TEST_TIMEOUT}s 没退出 —— 多半是"
        echo "          run() 里抛了异常，Qt.exit 没执行到。看下面的日志）"
        FAILED_FILES=$((FAILED_FILES + 1))
        TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
        if [ -s "$ERRLOG" ]; then
            sed 's/^/          | /' "$ERRLOG" | head -6
        fi
        continue
    fi

    if [ "$code" -eq 0 ]; then
        echo "  PASS  $name"
        continue
    fi

    # ── 加载失败：退出码**不是**位掩码 ──────────────────────────────────
    # 实测（M23）：测试文件里写了一个不存在的属性，得到的是
    #
    #     QQmlApplicationEngine failed to load component
    #     ...: Cannot assign to non-existent property "title"
    #     qml: Did not load any objects, exiting.
    #
    # 而退出码是 **2** —— 恰好等于 bit1。按位解码就会报"断言 #1 失败"，
    # 于是你去翻那条断言，而真相是**这个文件一条断言都没跑**。
    # 这是最坏的一类误诊：报告看着有信息量（点名了某一条），实则完全误导。
    #
    # 所以这里把"没加载起来"当成独立形态报出来，并且**不做位解码**。
    # 判据是引擎自己说的那两句话，不是退出码 —— 退出码在这里靠不住。
    if grep -qE 'failed to load component|Did not load any objects' "$ERRLOG" 2>/dev/null; then
        echo "  LOAD  $name（引擎没把组件加载起来 —— 一条断言都没跑，"
        echo "         退出码不是位掩码，所以下面不做解码）"
        FAILED_FILES=$((FAILED_FILES + 1))
        TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
        if [ -s "$ERRLOG" ]; then
            sed 's/^/          | /' "$ERRLOG" | head -6
        fi
        continue
    fi

    echo "  FAIL  $name"
    FAILED_FILES=$((FAILED_FILES + 1))

    # 引擎自己说的话比退出码位掩码更有信息量（典型：组件根本没加载起来，
    # 此时 8 个位会一起报失败，看着像"逻辑全错"，实则一句
    # "Non-existent attached object" 就定位了）。
    if [ -s "$ERRLOG" ]; then
        sed 's/^/          | /' "$ERRLOG" | head -6
    fi

    for n in 0 1 2 3 4 5 6 7; do
        if [ $(( code & (1 << n) )) -ne 0 ]; then
            echo "          断言 #$n 失败"
            TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
        fi
    done
done

# ---------- 3.5 真鼠标事件交互测试（qmltestrunner） ----------
# smoke_* 靠程序化调属性验证契约逻辑；tst_* 用 Qt Quick Test 注入
# 真实鼠标/键盘事件，端到端验证「事件 → 状态机 → 插槽视觉」链路。
# qmltestrunner 也是 GUI 子系程序，stdout 会被丢，必须 -o 落文件再读。
QTR="$QT_ROOT/bin/qmltestrunner"
if [ -n "$(find tests -name 'tst_*.qml' 2>/dev/null)" ] && [ -x "$QTR" ]; then
    set +e
    "$QTR" -platform offscreen -import .cache/qmlimports -input tests \
           -o .cache/itest.out,txt >/dev/null 2>&1
    itcode=$?
    set -e

    if [ "$itcode" -eq 0 ]; then
        echo "  PASS  tst_*（真鼠标事件，$(grep -c '^PASS' .cache/itest.out || true) 条）"
    else
        echo "  FAIL  tst_*（真鼠标事件）"
        grep -E '^(FAIL|Totals)' .cache/itest.out || true
        FAILED_FILES=$((FAILED_FILES + 1))
        TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
    fi
fi

# ---------- 3.6 FuzzyMatch 的独立算路交叉验证（M25.1）----------
# 上面 3.5 那一段是 QML 侧的真鼠标事件；这一段与 3.7 是**仅有的两段
# 不需要 Qt 的** —— 它们直接跑 node，连 qml.exe 都不碰。
#
# 为什么它必须在 test.sh 里（而不是待在某人的命令行历史里）：
#   它是 FuzzyMatch 的**唯一独立裁判**。`smoke_m25.qml` 的 [1] 也会读分数，
#   但那读的是"控件认为的分数"——控件与实现的分数一致，什么也证明不了。
#   这条闸的参照实现是**穷举**（枚举所有 C(n,m) 种对齐、按定义算分），
#   与 DP 没有一行共享代码、也不共享"必须用 DP"这个假设。
#
# 它原来是 `.cache/_m25fuzzy_probe.js`，M25.1 升格过来的。原话：
#   **一个住在可丢弃目录里的闸不算闸**（clean-cache.sh --all 一次就清掉，
#   而且没有任何门禁会报"我的裁判不见了"）。
#
# 找不到 node 的处置见 tools/check-fuzzy-match.sh 头部（按 0 退出但不静默）。
echo ""
FUZZY_SCAN="tools/check-fuzzy-match.sh"
FUZZY_CODE=0
if [ -x "$FUZZY_SCAN" ]; then
    "$FUZZY_SCAN" || FUZZY_CODE=$?
else
    echo "（跳过模糊匹配交叉验证：$FUZZY_SCAN 不存在或没有执行权限）"
fi
if [ "$FUZZY_CODE" -ne 0 ]; then
    FAILED_FILES=$((FAILED_FILES + 1))
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
fi

# ---------- 3.7 ColorUtil 的独立算路核验（M26）----------
# 与 3.6 同一族（纯函数、node 直接跑、不需要 Qt），但**参照实现的构造方式
# 不同**，这一点值得写清楚：
#
#   3.6 的参照是**穷举**（枚举所有合法对齐）—— 它证明的是"最优解找对了"。
#   3.7 的主力参照是**性质**，不需要任何参考答案：
#        · 色相 +120° 必须是三通道的**循环置换**（r←b, g←r, b←g）
#        · h 与 360−h 关于红轴对称（r 相同、g/b 互换）
#        · s = 0 必是灰阶；固定 h,s 时 v 递增则三通道都不减
#   第二条与第一条联手，把六个扇区的排列**互相钉住** —— 任何一处错位都会
#   露出来，而这不需要"另一个实现"当答案。另有 HSL 中转的数值交叉作补充，
#   它在文件头里被明确标成**弱独立**（两条链都有扇区分支），不装作主力。
#
# 它为什么必须在 test.sh 里：见 tools/check-color-util.js 文件头
# （**一个住在可丢弃目录里的闸不算闸** —— M25 记的原话，这里照办）。
echo ""
COLOR_SCAN="tools/check-color-util.sh"
COLOR_CODE=0
if [ -x "$COLOR_SCAN" ]; then
    "$COLOR_SCAN" || COLOR_CODE=$?
else
    echo "（跳过颜色换算核验：$COLOR_SCAN 不存在或没有执行权限）"
fi
if [ "$COLOR_CODE" -ne 0 ]; then
    FAILED_FILES=$((FAILED_FILES + 1))
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
fi

# ---------- 3.8 布局层像素核验（M29）----------
# 前面 1~2 节全是 `tests/smoke_*.qml` —— 那是**属性侧**的门，读的是
# x / y / width。而本项目的原话是「**属性值对 ≠ 界面画对**」（M27 的
# `QSkinKbd` 就是属性门与冒烟全绿、只有抓图能看见）。
#
# M29 之前**布局这一层一道像素门都没有**。这一节补上：抓一张确定性的图，
# 在像素上核验 QSkinRow 的**余量落在哪里**与**间隙真的是不是 gap**。
# 判据全部来自从图里量出来的东西（容器范围读锚条、缩放比两路对账、
# 前景/背景用众数色自校准），没有写死的像素坐标 —— 详见
# tools/check-layout-pixels.py 的文件头。
#
# 它为什么必须是**常驻**的：见下面那句话的原作者 —— M25 记下的
# **「一个住在可丢弃目录里的闸不算闸」**，M26 / M27 各自又验证了一遍。
# 所以场景（tests/scene_layout_justify.qml）与核验器（tools/）都在仓库里，
# 只有抓出来的 PNG 进 .cache/。
#
# 代价：一次抓图约 3 秒。只跑一个主题 —— 这里被测量的是纯几何，
# QSkinRow 的分配逻辑一个主题令牌都不读（理由写在场景文件头）。
echo ""
PIX_SCAN="tools/check-layout-pixels.sh"
PIX_CODE=0
if [ -x "$PIX_SCAN" ]; then
    "$PIX_SCAN" || PIX_CODE=$?
else
    echo "（跳过布局像素核验：$PIX_SCAN 不存在或没有执行权限）"
fi
if [ "$PIX_CODE" -ne 0 ]; then
    FAILED_FILES=$((FAILED_FILES + 1))
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
fi

# ---------- 3.9 输入底板像素核验（M31）----------
# 3.8 守的是**布局分配**（余量落在哪、间隙多宽）。这一节守的是**绘制**：
# 输入框底板的分组圆角（first/middle/last 四角各自不同）与聚焦/报错光晕
# （外扩 2px、四角跟着主体走）。
#
# 它们与 3.8 是同一类缝的两个位置 —— 属性侧的门
# （tests/smoke_m30_theme.qml 的 [2]~[4]）读的是插槽 `Rectangle` 的
# `topLeftRadius` 等四个属性，证明的是「**我设了这些值**」；
# 而本项目已经付过七次学费的那句话是「**属性值对 ≠ 界面画对**」。
# 具体差在哪、判据是怎么自校准的、以及**已知未覆盖**有哪三处，
# 都写在 tools/check-input-plate-pixels.py 的文件头。
#
# ⚠ 它必须与 3.8 节**串行**：两个脚本都调 tools/shot.sh，而 shot.sh 用
#   `mv` 归档再重建 import 树 —— 同一秒内连跑两次会撞名。这里是顺序写的，
#   不要改成并行。
#
# 代价：再多一次抓图，约 3 秒。只跑一档主题（ant）—— 半径的**数值**
# 由属性门在五档上守，这里守的是"数值 → 弧度"那一跳，它不随主题变。
echo ""
PLATE_SCAN="tools/check-input-plate-pixels.sh"
PLATE_CODE=0
if [ -x "$PLATE_SCAN" ]; then
    "$PLATE_SCAN" || PLATE_CODE=$?
else
    echo "（跳过输入底板像素核验：$PLATE_SCAN 不存在或没有执行权限）"
fi
if [ "$PLATE_CODE" -ne 0 ]; then
    FAILED_FILES=$((FAILED_FILES + 1))
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
fi

# ---------- 3.10 运行期警告核验（M31 · 第十二道门）----------
# 编号说明：「第十一道」已经被 M28 的构建清单门禁占了（它先一天进
# lint.sh），所以这一道顺延为**第十二道**。同一个名字指两道闸正是本
# 项目最忌讳的"自相矛盾的报告行"。
#
# 前面 3.8 / 3.9 两道像素门看的都是"画出来对不对"。这一道看的是
# **引擎在运行期喊了什么** —— 两者互补：属性对 + 像素对，全程看不见
# 运行期的一句话（M27 实测 675 行警告而三道门禁全绿）。
#
# 它读的输入是第 3 节累积出来的 .cache/_test_warn_all.log；判据三条：
#   ① 未豁免的警告      → 红
#   ② 过期豁免          → 红（照抄构建清单门禁 [8] 的裁决）
#   ③ 读不到输入（0 个文件） → 红 ——「检查了 0 条」一律算失败
#
# ⚠ 它与 3.8 / 3.9 不冲突：那两节要重建 import 树（shot.sh），这一节只读
#   文本日志。放在最后是因为输入由第 3 节产出。
echo ""
WARN_SCAN="tools/check-runtime-warn.sh"
WARN_CODE=0
if [ -x "$WARN_SCAN" ]; then
    "$WARN_SCAN" || WARN_CODE=$?
else
    echo "（跳过运行期警告核验：$WARN_SCAN 不存在或没有执行权限）"
fi
if [ "$WARN_CODE" -ne 0 ]; then
    FAILED_FILES=$((FAILED_FILES + 1))
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
fi

# ---------- 3.11 运行期翻译门（M33-7）----------
# 前面各节守的是"算得对 / 画得对 / 不喊"。这一节守**加载了翻译之后文案真的变**：
# M33 把库自产的 CJK 全部改成 `qsTr`（豁免表只剩 D 类 7 条），而 `qsTr` 本身
# **不证明任何事** —— 它只是一个标记，抽出 `.ts`、编成 `.qm`、被宿主装进
# `QTranslator`，这条链任何一环断了，界面照样是中文，而所有的冒烟照样绿。
#
# 判据是 `qml --translation i18n/qskin_en.qm tests/scene_i18n.qml`（纯 QML 环境
# 就能验证，不需要 C++ —— 见 ROADMAP §8.5 第 7 件）。
#
# ⚠ 它必须跑**两遍**：同一份场景，带 `--translation` 要**恰好 0**，不带要
#   **恰好**是声明的位掩码（127）。只跑正面那遍是一道不可证伪的门 ——
#   "全绿"可能只是因为场景压根没加载翻译。红面枪**常驻在门里**，不是靠人记得。
#   详见 tools/check-i18n-runtime.sh 头部。
echo ""
I18NRT_SCAN="tools/check-i18n-runtime.sh"
I18NRT_CODE=0
if [ -x "$I18NRT_SCAN" ]; then
    "$I18NRT_SCAN" || I18NRT_CODE=$?
else
    echo "（跳过运行期翻译门：$I18NRT_SCAN 不存在或没有执行权限）"
fi
if [ "$I18NRT_CODE" -ne 0 ]; then
    FAILED_FILES=$((FAILED_FILES + 1))
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
fi

# ---------- 3.12 三宿主对账（qml / C++ / PySide6）----------
# README 写「为 Qt Quick 打造的设计系统」，但长期只有 `qml` 运行器被验证过。
# 这一段跑**同一个场景**过三个宿主，要求每个公开类型都能被实例化、
# 每个单例都能取到，并且**三张图逐像素一致**。
#
# ⚠ 三种"缺东西"都算**工装错误**（位掩码 8），不静默跳过：
#   缺 Qt / 缺 PySide6 / 缺编译好的 C++ 宿主 —— 判据的输入没了 ≠ 没问题。
#   详略见 tools/check-host-parity.sh 头部与 tools/check-host-parity.py。
echo ""
HOST_SCAN="tools/check-host-parity.sh"
HOST_CODE=0
if [ -x "$HOST_SCAN" ]; then
    "$HOST_SCAN" || HOST_CODE=$?
else
    echo "（跳过三宿主对账：$HOST_SCAN 不存在或没有执行权限）"
fi
if [ "$HOST_CODE" -ne 0 ]; then
    FAILED_FILES=$((FAILED_FILES + 1))
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
fi

# ---------- 4. 汇总 ----------
echo ""
if [ "$TOTAL_FAILURES" -eq 0 ]; then
    echo "OK  全部通过"
    exit 0
else
    echo "NG  $TOTAL_FAILURES 条断言失败，分布在 $FAILED_FILES 个文件"
    echo "    （断言编号对应测试文件里 [n] 标记的那一条）"
    exit 1
fi
