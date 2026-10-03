#!/usr/bin/env bash
#############################################################################
# QSkin · 变异残留审计（M26 收口起，作为 lint.sh 第十道）
#
# 问的问题：**`src/` 里此刻装的是「原文」还是「改坏成」那一份？**
#
# 为什么要有这一条：变异脚本的复原都在 `try/finally` 里，正常结束必然收干净。
# 但 **`finally` 挡不住硬杀** —— 进程被 SIGKILL / 安全删除守卫 / 前台超时
# 带走时它一行都不执行，于是"改坏的那一行"就留在源码里了。M21 收口当天
# 实测过一次（`QSkinLabel.qml` 的 `visible: root.required` → `visible: true`，
# 症状是每个标签都带一颗红星：**属性对、界面全错**）。
#
# 要命的是本仓最熟悉的那件事：**"跑过门禁"有时间窗口**。那处残留 lint 看不见
# （`visible: true` 完全合法），唯一能看见它的 `smoke_m20.qml [4]` 确实红了 ——
# 但上一次跑 test.sh 是在变异**之前**。所以处置不是"以后记得再跑一次"
# （记不住的），而是**直接问源码要答案**。
#
# 它原本住在 `.cache/_audit_residue.py`，M26 收口时升格过来 ——
# 同项目已有先例（comprehension 作用域门禁也从 `.cache/` 升格到 `tools/`），
# 理由逐字相同：**一个住在可丢弃目录里的闸不算闸**。
# 详见 tools/check-mutation-residue.py 头部。
#
# 用法：
#     ./tools/check-mutation-residue.sh              # 只审 src/
#     ./tools/check-mutation-residue.sh --all        # 连 tests/ examples/ 一起审
#
# 一般不用直接调 —— ./tools/lint.sh 末尾会自动带上这一步（带 `--all`）。
#
# ── 退出码 ──────────────────────────────────────────────────────────────
#   0 = 无残留（或 `.cache/` 整棵不在 —— 跳过且出声，环境缺件不拖红 lint）
#   1 = 有残留 / 有脚本一条 edit 都没抽出来（覆盖不全）/ 有 `.cache/`
#       却没有任何 `mutate_m*.py`（那是"没查"，不是"没问题"）
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
    echo "找不到 python —— 跳过变异残留审计。"
    echo "可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 0   # 环境缺 python 不该把 lint 拖红，但要出声
fi

exec "$PY" tools/check-mutation-residue.py "$@"
