#!/usr/bin/env bash
#############################################################################
# QSkin · 令牌名门禁（M25.1 起）
#
# 规则：`Theme.<组>.<名>` 的 `<名>` 必须真的存在 —— 详见 tools/check-tokens.py 头部。
#
# 用法：
#     ./tools/check-tokens.sh          # 默认就扫 src examples tests
#
# 一般不用直接调 —— ./tools/lint.sh 末尾会自动带上这一步。
#
# 为什么不直接跑 .py：这台机器上 python 不在 PATH 里，`python3 x.py` 会
# command not found。按 QSkin_PYTHON → PATH → 托管目录 的顺序找一遍。
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
    echo "找不到 python —— 跳过令牌名扫描。"
    echo "可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 0   # 环境缺 python 不该把 lint 拖红，但要出声
fi

exec "$PY" tools/check-tokens.py "$@"
