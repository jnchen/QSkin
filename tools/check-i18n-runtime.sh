#!/usr/bin/env bash
#############################################################################
# QSkin · 运行期翻译门（M33-7）
#
# 判据：`qml --translation i18n/qskin_en.qm tests/scene_i18n.qml` 真的把界面
#       文案变成英文 —— 而"真的"这三个字要靠**跑两遍**来证明（见下）。
#
# 用法：
#     ./tools/check-i18n-runtime.sh          # 全绿退出 0
#
# 一般不用直接调 —— ./tools/test.sh 的第 3.11 节会自动带上这一步。
#
# ── 这道门为什么必须跑两遍 ──────────────────────────────────────────────
# 「场景断言全绿」有两种原因：翻译生效了，或者**场景根本没加载翻译**。
# 只看正面读数分不出这两者 —— 那是一道**不可证伪**的门。所以：
#
#     面 A（带 --translation）   位掩码必须**恰好 0**
#     面 B（不带）               位掩码必须**恰好 == EXPECT_RED**
#
# 面 B 是这道门的**红面枪**，常驻在门里，不是靠人记得去跑一次变异脚本。
# 它同时钉住两件事：① 场景里那些断言**确实**在测翻译（否则面 B 会绿）；
# ② 声明的那份掩码与实测**逐位相符**（否则 4）。
#
#   ⚠ EXPECT_RED = 127（bit 0..6）。bit[7] 是**度量**不是**翻译**——
#     它量"英文星期头装不装得进固定列宽"，两面都该绿。所以它不在 EXPECT_RED 里，
#     而它的红面由 tools/falsify-i18n-runtime.py 的 R7 单独造（压列宽）。
#
# ── 退出码（位掩码） ────────────────────────────────────────────────────
#     1  面 A 红：带翻译时场景断言失败 —— 翻译没生效、或渲染不对
#     2  面 B 绿：不带翻译也是 0 —— **这道门是空的**
#     4  面 B 的位掩码与 EXPECT_RED 不符
#     8  工装问题（缺 qml / 缺 .qm / 缺场景 / import 树陈旧 / 引擎静态错误）
#         ——「量不出」在本项目里**一律不算通过**
#
# ── 为什么 import 树要查"新鲜度" ────────────────────────────────────────
# 老坑（MEMORY 里那条）：改了 `src/` 不重建 import 树，跑的是**上一版代码**，
# 而所有断言照样绿。这一层没法从读数上分辨新旧树，只能比 mtime：
# `src/` 下有文件比 import 树里的副本**新** ⇒ 报工装错误，不猜。
#
# ── 环境覆盖（给证伪器用，见 tools/falsify-i18n-runtime.py） ────────────
#     QSkin_I18N_SCENE=…  QSkin_I18N_QM=…  QSkin_I18N_IMPORTS=…
#     QSkin_I18N_EXPECT_RED=…  QSkin_PYTHON=…  QSkin_QT=…
# 有了这几个口子，证伪器**不必篡改仓库里的件** —— 变异体都落 `.cache/`。
#############################################################################

set -euo pipefail
cd "$(dirname "$0")/.."

SCENE="${QSkin_I18N_SCENE:-tests/scene_i18n.qml}"
QM="${QSkin_I18N_QM:-i18n/qskin_en.qm}"
IMPORTS="${QSkin_I18N_IMPORTS:-.cache/qmlimports}"
EXPECT_RED="${QSkin_I18N_EXPECT_RED:-127}"
LOG_A=".cache/_i18n_runtime_en.log"
LOG_B=".cache/_i18n_runtime_zh.log"
CODE=0

# ---------- 1. 定位 Qt（与 test.sh / shot.sh / lint.sh 同一段逻辑） ----------
QT_ROOT="${QSkin_QT:-}"
if [ -z "$QT_ROOT" ]; then
    for d in .qt/*/*/; do
        [ -x "${d}bin/qml" ] && QT_ROOT="$d" && break
    done
fi
QML="$QT_ROOT/bin/qml"
if [ ! -x "$QML" ]; then
    echo "找不到 qml 运行器。请先跑 ./tools/install-qt.sh，或设置 QSkin_QT=/path/to/qt"
    exit 8
fi

# ---------- 2. 前置件：缺一个就报工装，不制造假失败 ----------
for f in "$SCENE" "$QM"; do
    if [ ! -f "$f" ]; then
        echo "!! 缺 $f —— 这条判据**量不出来**，按工装错误处理（不算通过）。"
        exit 8
    fi
done

if [ ! -d "$IMPORTS/QSkin/Foundation" ] || [ ! -d "$IMPORTS/QSkin/Contracts" ]; then
    echo "!! import 树不在（$IMPORTS/QSkin/Foundation | Contracts）—— 这条判据量不出来。"
    echo "   先跑一次 ./tools/test.sh 或 ./tools/lint.sh 把树搭起来。"
    exit 8
fi

# ---------- 3. import 树新鲜度（比 mtime，不猜内容） ----------
REF="$IMPORTS/QSkin/Foundation/DateUtil.qml"
if [ -f "$REF" ]; then
    STALE=$(find src/foundation src/contracts -type f -newer "$REF" 2>/dev/null \
            | wc -l | tr -d ' ')
    if [ "$STALE" != "0" ]; then
        echo "!! import 树陈旧：src/ 下有 $STALE 个文件比副本新 —— 跑的是上一版代码。"
        echo "   （老坑：改了 src 不重建树，断言照样全绿。先重跑 ./tools/test.sh。）"
        exit 8
    fi
fi

# ---------- 4. 看门狗（与 test.sh 同一段） ----------
QSkin_TEST_TIMEOUT="${QSkin_TEST_TIMEOUT:-30}"
TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout $QSkin_TEST_TIMEOUT"
elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_CMD="gtimeout $QSkin_TEST_TIMEOUT"
fi

# Windows GUI 子系统没有控制台，QML 报错默认走 OutputDebugString ——
# 不设这个变量，加载失败会**静默**变成"断言全错"（M13/§3 实录）。
export QT_FORCE_STDERR_LOGGING="${QT_FORCE_STDERR_LOGGING:-1}"

# ---------- 5. 跑两遍 ----------
# ⚠ 与 3.8 / 3.9 一样**必须串行**（它们会 mv 重建 import 树，本脚本只读不建）。
set +e
# shellcheck disable=SC2086
$TIMEOUT_CMD "$QML" -platform offscreen -I "$IMPORTS" \
              --translation "$QM" "$SCENE" > "$LOG_A" 2>&1
RC_A=$?
# shellcheck disable=SC2086
$TIMEOUT_CMD "$QML" -platform offscreen -I "$IMPORTS" "$SCENE" > "$LOG_B" 2>&1
RC_B=$?
set -e

if [ "$RC_A" -eq 124 ] || [ "$RC_B" -eq 124 ]; then
    echo "!! 超时被看门狗击杀（${QSkin_TEST_TIMEOUT}s）—— 场景停摆，读数无效。"
    exit 8
fi

# ---------- 6. 引擎静态错误：**先于**位解码判断 ----------
# 与 test.sh §3 同一个教训（M23）：组件没加载起来时退出码**不是**位掩码 ——
# 按位解码会报"第 N 条断言失败"，看着有信息量、实则完全误导。
for L in "$LOG_A" "$LOG_B"; do
    BAD=$(grep -a -E 'failed to load component|Did not load any objects|Cannot assign to non-existent|TypeError|Cannot read property' "$L" 2>/dev/null | head -3 || true)
    if [ -n "$BAD" ]; then
        echo "!! $L 里有引擎静态错误 —— 一条断言都没跑，不做位解码："
        echo "$BAD" | sed 's/^/     | /'
        exit 8
    fi
done

# ---------- 7. 位解码 ----------
decode() {
    local m="$1" names=""
    for n in 0 1 2 3 4 5 6 7; do
        if [ $(( m & (1 << n) )) -ne 0 ]; then
            names="$names #$n"
        fi
    done
    echo "$names"
}

# ⚠ 取值必须**锚在 `mask=` 上**：先写过 `grep -o '[0-9]*'`，它把行里 `i18n`
#   的 `18` 也抓出来了（读数是 "18\n0"，去重后当成掩码 18）—— 一次"量法
#   与被测量无关"的假读数。sed 精确取 `mask=` 后面那串数字。
MASK_A=$(sed -n 's/.*\[i18n-scene\] mask=\([0-9]\{1,\}\).*/\1/p' "$LOG_A" | tail -1)
MASK_B=$(sed -n 's/.*\[i18n-scene\] mask=\([0-9]\{1,\}\).*/\1/p' "$LOG_B" | tail -1)
if [ -z "$MASK_A" ] || [ -z "$MASK_B" ]; then
    echo "!! 两面都读不到 mask= 行 —— 场景没跑到收尾（异常吞掉了 Qt.exit）。"
    exit 8
fi

echo "（解释器无关；Qt：$QT_ROOT）"
echo "面 A · 带 --translation <$QM>"
grep -a '\[i18n-scene\]' "$LOG_A" | sed 's/^qml: /     /' || true
echo "      退出码 $RC_A ／ mask $MASK_A$(decode "$MASK_A")"
echo "面 B · 不带（红面：必须恰好 $EXPECT_RED）"
grep -a '\[i18n-scene\]' "$LOG_B" | sed 's/^qml: /     /' || true
echo "      退出码 $RC_B ／ mask $MASK_B$(decode "$MASK_B")"
echo
echo "MASK_A=$MASK_A"
echo "MASK_B=$MASK_B"

# ---------- 8. 三条判据 ----------
if [ "$MASK_A" != "0" ]; then
    echo "NG  面 A 红：带翻译时场景断言失败$(decode "$MASK_A") —— 翻译没生效或渲染不对。"
    CODE=$(( CODE | 1 ))
fi

if [ "$MASK_B" = "0" ]; then
    echo "NG  面 B **绿**：不带翻译也是 0 —— 那些断言没在测翻译，**这道门是空的**。"
    CODE=$(( CODE | 2 ))
elif [ "$MASK_B" != "$EXPECT_RED" ]; then
    echo "NG  面 B 掩码 $MASK_B ≠ 声明的 $EXPECT_RED$(decode "$MASK_B")"
    echo "    ——要么场景变了没同步声明，要么中间那些 bit 不再是「翻译相关」。"
    CODE=$(( CODE | 4 ))
fi

if [ "$CODE" -eq 0 ]; then
    echo "OK  运行期翻译：面 A 恰 0、面 B 恰 $EXPECT_RED（位掩码 0x00）"
fi

exit "$CODE"
