#!/usr/bin/env bash
#############################################################################
# QSkin · 运行期翻译门的证伪器（包装）
#
# 7 枪都在 tools/falsify-i18n-runtime.py 里；这里只做 python 定位。
# 枪单与各自的证明义务写在那个文件的头部 —— 那里是**唯一**的说明处，
# 不在这里抄一份（抄了就会漂）。
#############################################################################

set -euo pipefail
cd "$(dirname "$0")/.."

PY=""
if [ -n "${QSkin_PYTHON:-}" ] && [ -x "${QSkin_PYTHON}" ]; then
    PY="${QSkin_PYTHON}"
else
    for c in python3 python py; do
        if command -v "$c" >/dev/null 2>&1; then PY=$(command -v "$c"); break; fi
    done
    if [ -z "$PY" ]; then
        for d in "$HOME"/.workbuddy/binaries/python/versions/*/python.exe; do
            [ -x "$d" ] && PY="$d" && break
        done
    fi
fi
if [ -z "$PY" ]; then
    echo "!! 找不到 python —— 证伪器跑不了。**这不代表门是好的。**"
    exit 1
fi

exec "$PY" tools/falsify-i18n-runtime.py "$@"
