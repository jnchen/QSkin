#!/usr/bin/env bash
#############################################################################
# QSkin · 模糊匹配门禁（M25.1 起）
#
# 规则：`FuzzyMatch.score()` 的最优对齐必须与**穷举**算出来的逐例一致。
#       详见 tools/check-fuzzy-match.js 头部。
#
# 用法：
#     ./tools/check-fuzzy-match.sh          # 全绿退出 0
#
# 一般不用直接调 —— ./tools/test.sh 会自动带上这一步。
#
# ── 为什么要包一层 .sh 而不是直接跑 .js ──────────────────────────────────
# 与其它 wrapper 同一条理由，只是这次找的是 node：这台机器上 node 不在
# PATH 里（coreutils 与 python 同样不在），直接 `node x.js` 会
# command not found。按 QSkin_NODE → PATH → 托管目录 的顺序找一遍。
#
# ── 找不到 node 时**为什么按 0 退出**（这一条是取舍，不是随手） ──────────
# 前八道闸的 wrapper 在环境缺可执行体时一律 `exit 0` + 出声。这一条也照办，
# 为的是**不制造假失败**：环境缺 node 不是"这段代码错了"，报红会让
# `tools/test.sh` 的解码器把它读成"第 N 条断言失败"——一种看着有信息量、
# 实则完全误导的报告（test.sh 文件头记过同一类误诊）。
#
# 代价说清楚：**这条闸在缺 node 的环境里是静默失效的。** 本仓对这件事的
# 立场是"让前提一直可见"—— 所以下面每次运行都会把**实际用的是哪个 node**
# 打出来。看到路径是空的、或者报"找不到 node"，就说明这一层没在防任何东西。
#############################################################################

set -euo pipefail
cd "$(dirname "$0")/.."

find_node() {
    if [ -n "${QSkin_NODE:-}" ] && [ -x "${QSkin_NODE}" ]; then
        echo "${QSkin_NODE}"; return
    fi
    if command -v node >/dev/null 2>&1; then
        command -v node; return
    fi
    # WorkBuddy 托管 node 兜底（本机固定布局，仅作最后一条路）
    for d in "$HOME"/.workbuddy/binaries/node/versions/*/node.exe \
             "$HOME"/.workbuddy/binaries/node/versions/*/bin/node; do
        if [ -x "$d" ]; then echo "$d"; return; fi
    done
    echo ""
}

NODE=$(find_node)
if [ -z "$NODE" ]; then
    echo "找不到 node —— 跳过模糊匹配交叉验证（这一层没有在防任何东西）。"
    echo "可用 QSkin_NODE=/path/to/node 指定。"
    exit 0
fi

echo "==> node：$NODE"
exec "$NODE" tools/check-fuzzy-match.js "$@"
