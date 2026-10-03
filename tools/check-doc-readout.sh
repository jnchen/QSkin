#!/usr/bin/env bash
#############################################################################
# QSkin · 发布面读数对账门（包装）
#
# 三部分在 `tools/check-doc-readout.py`；这里只负责**定位 python**。
# 这道门**不需要 Qt** —— 它从源码复算读数，再去发布面文档里对账。
#
# 用法：
#     ./tools/check-doc-readout.sh        # 一般不用直接调（lint.sh 的第 16 段带它）
#     ./tools/check-doc-readout.sh --list # 只打印真值与各文档命中情况
#
# ── 它在防什么 ────────────────────────────────────────────────────────────
# 发布面文档（README / COVERAGE / CHANGELOG / PITFALLS / GITHUB）里的读数
# **全是手写的**。手写的数字必然漂，而且漂了没人喊 —— 2026-10-03 手工核对
# 就抓到三处：同一份 README 里「11 道」与「9 道」并存；架构图写
# 「5 组插槽」而实测四家是 8/10/8/11；新写的 GITHUB.md 压根不在
# 泄露门的扫描面里。
#
# 所以有了这道门：**从源码复算 → 逐份文档对账**。加了控件、换了主题、
# 门增减，它会自己喊。
#
# ── 它的边界（别指望它管它管不了的）────────────────────────────────────
# 只抓「手滑写错一个数字」与「真值/错值并存」。**抓不到**差 ≥2 的错、
# 也抓不到「措辞对但含义错」。它是**防漂移的护栏**，不是文档正确性的证明。
# 完整边界写在 tools/check-doc-readout.py 头部。
#
# ── 为什么这道门住在 tools/ ───────────────────────────────────────────────
# 老话：**一个住在可丢弃目录里（.cache/）的闸不算闸。**
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
    echo "找不到 python —— 跳过发布面读数对账。"
    echo "可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 0   # 环境缺 python 不该把 lint 拖红，但要出声
fi

exec "$PY" tools/check-doc-readout.py "$@"
