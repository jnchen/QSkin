#!/usr/bin/env bash
#############################################################################
# QSkin · i18n 门禁（包装）
#
# 三道判据在 `tools/check-i18n.py`；这里只负责**定位工具**并把路径传过去。
#
# 用法：
#     ./tools/check-i18n.sh          # 一般不用直接调（lint.sh 的第 12 段带它）
#
# ── 缺 lupdate / lrelease 时为什么报**工装错误**（退出码含 8） ────────────
# 与运行期警告门"缺日志按 0 退出"**不是同一条规矩**，别混：
#   · 缺累积日志  → 说明**前置条件还没满足**（没跑过 test.sh），不是代码错了
#                   → 报出来、按 0 退出，不制造假失败
#   · 缺 lupdate  → 判据 3 是"`.ts`/`.qm` 与源码同步"，**没有它就量不出这条**
#                   → 而"量不出"在本项目的规矩里**一律不算通过**
#                     （"检查了 0 条算失败"）→ 报工装错误
# 两条都不制造假失败；差别在**这一层到底有没有在防**：前者是没有输入，
# 后者是**判据本身残缺**。
#
# ── 为什么这道门住在 tools/ ───────────────────────────────────────────────
# 老话，M25 记的、M26/M27/M31 各自又验了一遍：
# **一个住在可丢弃目录里（.cache/）的闸不算闸。**
#############################################################################

set -euo pipefail
cd "$(dirname "$0")/.."

find_python() {
    if [ -n "${QSkin_PYTHON:-}" ] && [ -x "${QSkin_PYTHON}" ]; then
        echo "${QSkin_PYTHON}"; return
    fi
    for c in python3 python py; do
        if command -v "$c" >/dev/null 2>&1; then
            command -v "$c"; return
        fi
    done
    for d in "$HOME"/.workbuddy/binaries/python/versions/*/python.exe \
             "$HOME"/.workbuddy/binaries/python/versions/*/bin/python3; do
        if [ -x "$d" ]; then echo "$d"; return; fi
    done
    echo ""
}

PY=$(find_python)
if [ -z "$PY" ]; then
    echo "找不到 python —— **i18n 这一层没有在防任何东西**。"
    echo "可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 0
fi

# 与 lint.sh / i18n.sh 同一段定位逻辑
QT_ROOT="${QSkin_QT:-}"
if [ -z "$QT_ROOT" ]; then
    for d in .qt/*/*/; do
        [ -x "${d}bin/qmllint" ] && QT_ROOT="$d" && break
    done
fi

LUPDATE=""
LRELEASE=""
if [ -n "$QT_ROOT" ]; then
    [ -x "$QT_ROOT/bin/lupdate" ]  && LUPDATE="$QT_ROOT/bin/lupdate"
    [ -x "$QT_ROOT/bin/lrelease" ] && LRELEASE="$QT_ROOT/bin/lrelease"
fi

if [ -z "$LUPDATE" ] || [ -z "$LRELEASE" ]; then
    echo "（注意：没找到 lupdate / lrelease —— 判据 3 会报**工装错误**，不算通过。）"
fi

echo "（解释器：$PY ｜ Qt：${QT_ROOT:-未找到}）"
exec "$PY" tools/check-i18n.py \
    --lupdate "$LUPDATE" \
    --lrelease "$LRELEASE" \
    "$@"
