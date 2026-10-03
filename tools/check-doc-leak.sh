#!/usr/bin/env bash
#############################################################################
# QSkin · 发布面泄露门禁（包装）
#
# 三道判据在 `tools/check-doc-leak.py`；这里只负责**定位 python**。
# 这道门**不需要 Qt** —— 它只读四个 markdown 文档。
#
# 用法：
#     ./tools/check-doc-leak.sh        # 一般不用直接调（lint.sh 的第 13 段带它）
#
# ── 它在防什么 ────────────────────────────────────────────────────────────
# `README.md` / `COVERAGE.md` / `CHANGELOG.md` / `docs/PITFALLS.md` 会随发行版
# 发布。开发机上的一次性件名（`mutate_*` / `_verify_*` / `shot_m*`）与
# 个人路径**对外部读者没有意义**，还会变成一批悬空引用 —— 那些文件被
# `.gitignore` 排除，新克隆的仓库里一个都没有。
#
# 逐条规则与"盘符正则为什么必须加前置否定"写在 `tools/check-doc-leak.py` 头部，
# 那里是唯一说明处，不在这里抄。
#
# ── 为什么这道门住在 tools/ ───────────────────────────────────────────────
# 老话，M25 记的、M26/M27/M31/M33 各自又验了一遍：
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
    echo "找不到 python —— **发布面泄露这一层没有在防任何东西**。"
    echo "可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 0
fi

echo "（解释器：$PY ｜ 本门不需要 Qt）"
exec "$PY" tools/check-doc-leak.py "$@"
