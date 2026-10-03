#!/usr/bin/env bash
#############################################################################
# QSkin · 三宿主对账（包装）
#
# 判据住在 `tools/check-host-parity.py`；这里负责三件脏活：
#   1. 定位 python
#   2. **确保 C++ 宿主已构建**（缺就构建一次）
#   3. 搭 import 树
#
# 用法：
#     ./tools/check-host-parity.sh        # 一般不用直接调（test.sh 带它）
#
# ── 它在防什么 ────────────────────────────────────────────────────────────
# README 写「为 Qt Quick 打造的设计系统」。但长期只有 `qml` 运行器被验证过：
# 全仓搜 `PySide|PyQt` 曾零命中，C++ 宿主从未存在过。对 C++ / Python 用户
# 来说，"纯 QML 所以谁都能用"是**推论**，不是实测。
#
# 这道门跑**同一个场景**过三个宿主：
#     qml(6.8.3) / C++(6.8.3) / PySide6(6.11.2)
# 要求：每个公开类型都能实例化、每个单例都能取到、**三张图逐像素一致**。
#
# ── 缺工具时报 8，不静默跳过 ─────────────────────────────────────────────
# 缺 PySide6 / 缺 Qt / 缺编译好的 C++ 宿主，都是**工装错误**（位掩码 8），
# 不是"这一层通过了"。判据的输入没了 ≠ 没问题。
#   · 缺 PySide6：pip install PySide6，或 QSkin_PYSIDE6_PYTHON=... 指定
#   · 缺 C++ 宿主：本脚本会自动尝试构建一次
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
    echo "工装错误：找不到 python —— **三宿主对账这一层没有在防任何东西**。"
    echo "          可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 8
fi

# ---------- import 树（与 tools/shot.sh 同一套映射） ----------
if [ ! -d .cache/qmlimports ]; then
    mkdir -p .cache/qmlimports/QSkin/Theme
    cp -r src/foundation .cache/qmlimports/QSkin/Foundation
    cp -r src/contracts  .cache/qmlimports/QSkin/Contracts
    for d in src/themes/*/; do
        name=$(basename "$d")
        case "$name" in
            tdesign) uri=TDesign ;;
            ant)     uri=AntDesign ;;
            arco)    uri=ArcoDesign ;;
            shadcn)  uri=Shadcn ;;
            *)       uri="$name" ;;
        esac
        cp -r "$d" ".cache/qmlimports/QSkin/Theme/$uri"
    done
fi

# ---------- C++ 宿主：缺就构建一次 ----------
CPP_BIN=".cache/hostbuild-cpp/qdshost.exe"
if [ ! -f "$CPP_BIN" ]; then
    CPP_BIN=".cache/hostbuild-cpp/qdshost"
fi
if [ ! -f "$CPP_BIN" ]; then
    echo "（C++ 宿主未构建，尝试构建一次：bash examples/hosts/cpp/build.sh）"
    # 构建失败**不在这里吞掉**：下面 check-host-parity.py 会按缺二进制报工装错误。
    bash examples/hosts/cpp/build.sh >/dev/null 2>&1 || \
        echo "（构建未成功 —— 交由对账脚本按工装错误报出）"
fi

echo "（解释器：$PY）"
exec "$PY" tools/check-host-parity.py "$@"
