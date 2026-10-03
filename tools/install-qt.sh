#!/usr/bin/env bash
#############################################################################
# QSkin · 把 Qt 装到项目本地
#
# 用法：
#     ./tools/install-qt.sh              # 默认 Qt 6.8.3 / win64_mingw
#     ./tools/install-qt.sh 6.8.3        # 指定版本
#
# 装到 qds/.qt/ 下，不污染系统、不进 git（已在 .gitignore 里）。
# 本机没有 Qt 也能跑静态检查与示例。
#
# ── 一个值得记住的坑 ──────────────────────────────────────────────────────
# aqt 默认 concurrency = 4，四个包同时下载。在某些网络环境（企业代理、
# 沙箱、部分 CI）下会**稳定**产出校验和不匹配的损坏包：
#
#     ERROR: Downloaded file ...qtbase-...7z is corrupted! Detect checksum error.
#     Expect a2cd0905...  Actual a38121fa...
#
# 5 次重试次次失败，且每次哈希都一样 —— 说明是确定性的损坏，不是网络抖动。
# 同样的 URL 用 curl 或单线程 requests 下载，哈希完全正确。
# 结论：并发流被中间件搞坏了。把 concurrency 降为 1 即可。
#
# 这个脚本会自动改 aqt 的 settings.ini。若你手动跑 aqt，记得自己改。
#############################################################################

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-6.8.3}"
ARCH="${2:-win64_mingw}"
MIRROR="${QSkin_QT_MIRROR:-https://mirrors.aliyun.com/qt/}"
OUTDIR="$(pwd)/.qt"

echo "==> 目标：Qt $VERSION / $ARCH -> $OUTDIR"

# ---------- 1. 找 Python + aqt ----------
PY="${QSkin_PYTHON:-}"
if [ -z "$PY" ]; then
    for cand in python3 python; do
        if command -v "$cand" >/dev/null 2>&1; then PY="$cand"; break; fi
    done
fi
[ -n "$PY" ] || { echo "错误：找不到 python"; exit 1; }

if ! "$PY" -m aqt version >/dev/null 2>&1; then
    echo "==> 安装 aqtinstall"
    "$PY" -m pip install -q aqtinstall
fi

# ---------- 2. 把并发降为 1（见文件头的坑） ----------
AQT_PKG="$("$PY" -c 'import aqt,os;print(os.path.dirname(aqt.__file__))')"
SETTINGS="$AQT_PKG/settings.ini"
if [ -f "$SETTINGS" ]; then
    if grep -q "^concurrency" "$SETTINGS"; then
        sed -i.bak 's/^concurrency[[:space:]]*:.*/concurrency : 1/' "$SETTINGS"
        rm -f "$SETTINGS.bak"
    else
        sed -i.bak '1a\
concurrency : 1' "$SETTINGS"
        rm -f "$SETTINGS.bak"
    fi
    echo "==> aqt concurrency -> $(grep '^concurrency' "$SETTINGS")"
fi

# ---------- 3. 安装 ----------
mkdir -p "$OUTDIR"
echo "==> 开始下载（串行，约 250MB，视网络 3~10 分钟）"
"$PY" -m aqt install-qt windows desktop "$VERSION" "$ARCH" \
    -b "$MIRROR" \
    --outputdir "$OUTDIR"

# ---------- 4. 确认 ----------
TOOLCHAIN_DIR=""
for d in "$OUTDIR/$VERSION"/*/; do
    [ -x "${d}bin/qmllint" ] && TOOLCHAIN_DIR="$d" && break
done

if [ -z "$TOOLCHAIN_DIR" ]; then
    echo "错误：安装完成但没找到 qmllint，目录内容如下："
    ls -R "$OUTDIR" | head -30
    exit 1
fi

echo ""
echo "==> 完成"
"${TOOLCHAIN_DIR}bin/qmllint" --version
echo "==> 接下来可以跑： ./tools/lint.sh"
