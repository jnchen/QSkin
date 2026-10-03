#!/usr/bin/env bash
#############################################################################
# QSkin · 公开类型清单对账（包装）
#
# 判据住在 `tools/gen-contract-manifest.py --check`；这里只负责**定位 python**。
# 这道门**不需要 Qt** —— 它只读几个 qmldir 加一个生成物。
#
# 用法：
#     ./tools/check-contract-manifest.sh      # 一般不用直接调（lint.sh 带它）
#
# ── 它在防什么 ────────────────────────────────────────────────────────────
# `tests/ContractManifest.js` 是**生成物**：它由各模块的 `qmldir` 生成，供
# `tests/scene_host_parity.qml` 遍历「宿主能用哪些类型」。
#
# 于是有个静默失效的方向：有人在 qmldir 里加了新类型、却没重跑生成器。
# 结果是宿主对账**全绿，但少测了那个类型** —— 门绿着，覆盖却悄悄缩水。
# 生成物与源码脱节不会自己喊，这道闸替它喊。
#
# 同时它还查「内部件名单是否过期」：INTERNAL_TYPES 里列的 (模块, 类型) 若
# 已从 qmldir 消失，说明要么删了、要么改名了 —— 同样要红。
#
# ── 缺 python 时报 8 而不是 0 ────────────────────────────────────────────
# 更早的几道包装器在找不到解释器时 `exit 0`（跳过）。那会让"这一层没在防
# 任何东西"看起来像"这一层通过了"。本仓后来的规矩是**缺工具 ≠ 跳过**，
# 报**工装错误**（位掩码 8），并给出 QSkin_PYTHON 的指定方式。
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
    echo "工装错误：找不到 python —— **清单对账这一层没有在防任何东西**。"
    echo "          可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 8
fi

echo "（解释器：$PY ｜ 本门不需要 Qt）"
exec "$PY" tools/gen-contract-manifest.py --check "$@"
