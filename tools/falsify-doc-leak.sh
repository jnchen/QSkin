#!/usr/bin/env bash
#############################################################################
# QSkin · 发布面泄露门禁的**证伪器**（包装）
#
# 枪单、预期红位与两条负锚点的理由写在 `tools/falsify-doc-leak.py` 头部。
# 这里只负责**定位 python**。
#
# 用法：
#     ./tools/falsify-doc-leak.sh
#
# 它把四份文档的最小副本写进 `.cache/_dltmp/`（**不碰真仓库**），
# 把门禁指向那棵临时树跑，跑完删掉。
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
    echo "找不到 python —— 证伪器跑不起来（这一层没有在防任何东西）。"
    echo "可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 0
fi

exec "$PY" tools/falsify-doc-leak.py "$@"
