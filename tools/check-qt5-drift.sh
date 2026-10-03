#!/usr/bin/env bash
#############################################################################
# QSkin · Qt 5 产物漂移门（包装）
#
# 判据住在 `tools/qml-downgrade.py --check`；这里只负责定位 python。
#
# ── 它在防什么 ────────────────────────────────────────────────────────────
# `qt5/` 是**入库的生成物**（src/ 经降级器产出）。它是双轨里最危险的一环：
#
#     src/ 改一行 → 没重跑生成器 → qt5/ 陈旧
#
# 这时 `lint` 依然全绿（它扫的是 src/），而 Qt 5 侧跑起来就是旧的。更糟的是
# 生成器自带的"规则命中数对账"也**照样全 OK** —— 那些数字只证明"规则按预期
# 命中了"，证明不了"入库产物就是当前 src/ 生成的"。
#
# 所以这道门做的是**逐文件比对**：把当前 src/ 重新生成一份到临时目录，与
# 入库的 qt5/ 比 sha256，新增 / 残留 / 内容不同都报出来。
#
# ── 修法 ──────────────────────────────────────────────────────────────────
#     python tools/qml-downgrade.py --profile qt515
# 然后把重新生成的 qt5/ 一起提交。
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
    for d in "$HOME"/.workbuddy/binaries/python/envs/default/Scripts/python.exe \
             "$HOME"/.workbuddy/binaries/python/envs/default/bin/python \
             "$HOME"/.workbuddy/binaries/python/versions/*/python.exe; do
        if [ -x "$d" ]; then echo "$d"; return; fi
    done
    echo ""
}

PY=$(find_python)
if [ -z "$PY" ]; then
    echo "工装错误：找不到 python —— **Qt 5 漂移这一层没有在防任何东西**。"
    echo "          可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 8
fi

echo "（解释器：$PY）"
exec "$PY" tools/qml-downgrade.py --profile qt515 --check
