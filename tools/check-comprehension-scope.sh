#!/usr/bin/env bash
#############################################################################
# QSkin · comprehension 作用域门禁（M23.1 起）
#
# 规则：comprehension（列表/集合/字典推导式、生成器表达式）里被**读**的名字，
#       必须绑定于它自己的 target、外层函数/模块作用域、或内建。
#
# 为什么要有这一条：QML 侧的闸管不到 Python 工具链，而这一类的缺陷
# **完全静默**——`.cache/_verify_m23.py` 里写过
#       [x / DPR for _x, _y, c in ... if is_dv(c)]
# 绑 `_x` 却用 `x`：画面对时表达式一次都不求值（静默通过），画面错时
# 抛 NameError 把整个核验器崩掉。也就是说那条断言从写下起就没跑过。
# 它是被变异测试逼出来的（期望红、实际"没有组变红"）。
# 详见 tools/check-comprehension-scope.py 头部。
#
# 用法：
#     ./tools/check-comprehension-scope.sh              # 扫默认范围
#     ./tools/check-comprehension-scope.sh 文件...       # 只扫给定文件
#
# 一般不用直接调 —— ./tools/lint.sh 末尾会自动带上这一步。
#
# ── 为什么默认范围含 .cache/ ────────────────────────────────────────────
# 变异脚本与像素核验器都住在那里，而它们正是这一类缺陷的高发地
# （推导式密度高、又没人 review）。`.cache/` 不存在时自动跳过，不算失败。
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
    echo "找不到 python —— 跳过 comprehension 作用域检查。"
    echo "可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 0   # 环境缺 python 不该把 lint 拖红，但要出声
fi

exec "$PY" tools/check-comprehension-scope.py "$@"
