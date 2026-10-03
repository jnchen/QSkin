#!/usr/bin/env bash
#############################################################################
# QSkin · 第十二道门：运行期警告（包装）
#
# 规则：`tests/smoke_*.qml` 跑出来的**全部** stderr 累积到
#       `.cache/_test_warn_all.log`，与 `tools/runtime-warn-exempt.txt`
#       对账。判据三条（新增即红 / 过期豁免即红 / 读不到输入即红），
#       详见 tools/check-runtime-warn.py 头部。
#
# 用法：
#     ./tools/check-runtime-warn.sh          # 一般不用直接调
#
# 正常路径是 ./tools/test.sh 的第 3.10 节自动带上它 —— 因为**累积日志
# 是 test.sh 第 3 节写出来的**，本脚本只负责"读 + 判"。
#
# ── 为什么这道门住在 tools/ 而不是 .cache/ ──────────────────────────────
# 与 check-layout-pixels.sh / check-input-plate-pixels.sh 逐字同源的理由：
# **一个住在可丢弃目录里的闸不算闸**（M25 记的原话，M26 / M27 / M31 各自
# 又验证了一遍）。所以核验器与豁免名单都进仓库；累积日志进 `.cache/`。
#
# ── 找不到累积日志时为什么按 0 退出 ─────────────────────────────────────
# 与"找不到 python 就按 0 退出"是**不同**的一件事，别混：
#   · 缺 python  → 这一层在这个环境里不可能工作  → 报出来、按 0 退出
#   · 缺日志     → 说明**还没跑过 test.sh**（或有人删了 .cache）——
#                  这是"前置条件没满足"，不是"代码错了"。
# 两条都**不制造假失败**：报红会让 test.sh 读成"第 N 条断言失败"，
# 那是本项目最忌讳的"看着有信息量、实则完全误导的报告"。
# 代价要说清楚：**这两条路径上，这一层都是静默失效的** ——
# 所以下面一定会把实际用的解释器与日志路径打出来，让人看见它有没有在防。
#
# ⚠ 核验器自己会区分"日志存在但一个文件都没读到"（那是工装坏了 → 红）。
#   所以"按 0 退出"只覆盖**日志文件不存在**这一种，不覆盖内容为空。
#############################################################################

set -euo pipefail
cd "$(dirname "$0")/.."

LOG=".cache/_test_warn_all.log"

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
    echo "找不到 python —— **运行期警告这一层没有在防任何东西**。"
    echo "可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 0
fi

if [ ! -f "$LOG" ]; then
    echo "（还没有累积日志 $LOG —— 先跑一次 ./tools/test.sh。）"
    echo "  **运行期警告这一层这次没有在防任何东西。**"
    exit 0
fi

echo "（解释器：$PY ｜ 累积日志：$LOG）"
exec "$PY" tools/check-runtime-warn.py "$LOG"
