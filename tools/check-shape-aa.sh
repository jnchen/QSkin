#!/usr/bin/env bash
#############################################################################
# QSkin · Shape 渲染器门禁
#
# 规则：每个 Shape 都要显式指定 preferredRendererType: Shape.CurveRenderer，
#       且 QtQuick.Shapes 的导入不带版本号。
#
# 用法：
#     ./tools/check-shape-aa.sh          # 有违规则退出码 1
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
    echo "找不到 python —— 跳过 Shape 渲染器检查。"
    echo "可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 0   # 环境缺 python 不该把 lint 拖红，但要出声
fi

exec "$PY" tools/check-shape-aa.py "$@"
