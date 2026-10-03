#!/usr/bin/env bash
#############################################################################
# QSkin · 字符图标门禁（M15.1 起）
#
# 规则：图标要么是矢量，要么是插槽，**不能是一个字形**。
#
# 用法：
#     ./tools/scan-glyph-icons.sh           # 只报 ICON，有则退出码 1
#     ./tools/scan-glyph-icons.sh --all     # 带上 REVIEW 与注释提及
#
# 一般不用直接调 —— ./tools/lint.sh 末尾会自动带上这一步。
#
# ── 为什么要包一层 .sh 而不是直接跑 .py ─────────────────────────────────
# 这台机器上 python 不在 PATH 里（和 coreutils 一样），直接 `python3 x.py`
# 会 command not found。所以这里按 QSkin_PYTHON → PATH → 托管目录 的顺序找一遍。
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
    # WorkBuddy 托管 Python 兜底（本机固定布局，仅作最后一条路）
    for d in "$HOME"/.workbuddy/binaries/python/versions/*/python.exe \
             "$HOME"/.workbuddy/binaries/python/versions/*/bin/python3; do
        if [ -x "$d" ]; then echo "$d"; return; fi
    done
    echo ""
}

PY=$(find_python)
if [ -z "$PY" ]; then
    echo "找不到 python —— 跳过字符图标扫描。"
    echo "可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 0   # 环境缺 python 不该把 lint 拖红，但要出声
fi

exec "$PY" tools/scan-glyph-icons.py "$@"
