#!/usr/bin/env bash
#############################################################################
# QSkin · 构建清单门禁（M28 起，作为 lint.sh 第十一道）
#
# 问的问题：**CMakeLists.txt 里列的 QML / JS 文件，和 src/ 下真实存在的
# 那一堆，是不是同一份？**
#
# 为什么要有这一条：`CMakeLists.txt` 的文件头一直写着「M0 地基层 + M1 契约层
# （五个插槽 + 六个控件）」，而 tools/ 那套**直跑路线**一直工作良好 ——
# 于是没有人跑过官方构建路径，也就没有人发现清单已经烂了。M28 开工实测：
# 清单 27 条、实际 187 个，四套主题一个模块都没挂。**一个没人跑的东西，
# 看起来一直是好的。**
#
# 详见 tools/check-build-manifest.py 头部（含七条判据与六枪证伪法）。
#
# 用法：
#     ./tools/check-build-manifest.sh          # 结论 + 问题（每类最多 20 条）
#     ./tools/check-build-manifest.sh -v       # 不截断
#
# 一般不用直接调 —— ./tools/lint.sh 末尾会自动带上这一步。
#
# ── 退出码 ──────────────────────────────────────────────────────────────
#   0 = 清单与实际一致
#   1 = 有某条判据不过（含"查了 0 条"这类元判据失败）
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
    echo "找不到 python —— 跳过构建清单检查。"
    echo "可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 0   # 环境缺 python 不该把 lint 拖红，但要出声
fi

exec "$PY" tools/check-build-manifest.py "$@"
