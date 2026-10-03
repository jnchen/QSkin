#!/usr/bin/env bash
#############################################################################
# QSkin · 颜色换算门禁（M26 起）
#
# 规则：`ColorUtil` 必须满足顶点定义、四条性质（v 单调 / 灰阶 / 色相 +120°
#       是通道循环 / 红轴对称）、HSL 中转交叉、分档往返、hex 语义、
#       取色几何、预设色块可复算。详见 tools/check-color-util.js 头部。
#
# 用法：
#     ./tools/check-color-util.sh          # 全绿退出 0
#
# 一般不用直接调 —— ./tools/test.sh 会自动带上这一步。
#
# ── 为什么找不到 node 时按 0 退出 ────────────────────────────────────────
# 与 tools/check-fuzzy-match.sh 逐字同源的理由（见那份文件头）：**不制造
# 假失败** —— 环境缺 node 不是"这段代码错了"，报红会让 test.sh 的解码器
# 把它读成"第 N 条断言失败"，一种看着有信息量、实则完全误导的报告。
#
# 代价说清楚：**这一层在缺 node 的环境里是静默失效的。** 所以下面每次
# 运行都会把**实际用的是哪个 node** 打出来 —— 看到路径是空的、或者报
# "找不到 node"，就说明这一层没在防任何东西。
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
    echo "找不到 node —— 跳过颜色换算交叉验证（这一层没有在防任何东西）。"
    echo "可用 QSkin_NODE=/path/to/node 指定。"
    exit 0
fi

echo "==> node：$NODE"
exec "$NODE" tools/check-color-util.js "$@"
