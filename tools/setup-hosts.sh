#!/usr/bin/env bash
#############################################################################
# QSkin · 五宿主环境的「体检 / 一键补齐」
#
# 用法：
#     ./tools/setup-hosts.sh --check    # 只体检（退出码 = 缺失项数；0 = 全齐）
#     ./tools/setup-hosts.sh            # 缺什么装什么
#
# ── 为什么要有这个脚本 ────────────────────────────────────────────────────
# 对账门（`tools/test.sh` 末段）**默认必跑五个宿主**，缺依赖一律报
# **工装错误 8**，不静默跳过 —— 这是刻意的：判据的输入没了 ≠ 没问题。
#
# 但「必跑」是有代价的：拿到库的人在干净机器上第一次跑门禁一定是红的，
# 而红的原因（没装 PyQt5 / 没有 Qt 5 SDK）与库本身毫无关系。过去这份
# 「怎么补齐」只存在于 README 的一句话和一个个 `--skip-*` 参数里 ——
# 后者更危险：跳过就等于这一层没在防任何东西。
#
# 本脚本把补齐动作收成一条命令，并且能反过来**体检**（`--check`），
# 让「我这台机器齐不齐」成为一个可回答的问题，而不是靠跑一遍门禁猜。
#
# ── 五宿主需要的四样东西 ──────────────────────────────────────────────────
#   1. 解释器 + PySide6（Qt 6 侧）/ PyQt5（Qt 5 侧，wheel 自带 Qt 5.15 运行时）
#   2. Qt 6 SDK —— 项目内 .qt/6.8.3（qml 运行器 + C++ Qt6 宿主 + MinGW 编译器）
#   3. Qt 5 SDK —— ~/.workbuddy/binaries/qt5/5.15.2/mingw81_64（C++ Qt5 宿主）
#   4. 两个 C++ 宿主二进制（.cache/hostbuild-cpp / .cache/hostbuild-cpp-qt5）
#
# ⚠ Qt 5 **不装在项目内**：它只服务于对账门，而门的 `find_qt5_prefix()`
#   把路径钉在托管目录 —— 换个地方门就找不到（工装错误 8），别挪。
#
# ⚠ 不用 `set -e`：体检要**把每一项都跑完再汇总**，缺一项就退出的话，
#   使用者得修一次跑一次才能看全缺什么。
#############################################################################

set -uo pipefail

cd "$(dirname "$0")/.." || exit 8
if [ ! -f CMakeLists.txt ] && [ ! -f README.md ]; then
    echo "工装错误：没落在仓库根（当前 $(pwd)）"
    exit 8
fi

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

QT5_BASE="$HOME/.workbuddy/binaries/qt5"
QT5_VER="5.15.2"
QT5_ARCH="win64_mingw81"
MIRROR="${QSkin_QT_MIRROR:-https://mirrors.aliyun.com/qt/}"

MISSING=0
ok()   { printf '  [✓] %-16s %s\n' "$1" "$2"; }
miss() { printf '  [ ] %-16s %s\n' "$1" "$2"; MISSING=$((MISSING + 1)); }

# ---------- 1. 解释器 ----------
PY="${QSkin_PYTHON:-}"
if [ -z "$PY" ]; then
    for c in python3 python py; do
        if command -v "$c" >/dev/null 2>&1; then PY="$(command -v "$c")"; break; fi
    done
fi
if [ -z "$PY" ]; then
    for d in "$HOME"/.workbuddy/binaries/python/versions/*/python.exe \
             "$HOME"/.workbuddy/binaries/python/versions/*/bin/python3; do
        if [ -x "$d" ]; then PY="$d"; break; fi
    done
fi

echo "═══ 五宿主环境体检 ═══"
if [ -n "$PY" ] && [ -x "$PY" ]; then
    ok "python" "$PY"
else
    miss "python" "缺失 —— 装 Python 3，或用 QSkin_PYTHON=/path/to/python 指定"
    PY=""
fi

# ---------- 2. Python 绑定 ----------
# ⚠ 必须复用**门自己的查找逻辑**（check-host-parity.py 的 find_python_with_*），
#   不能另写一句 `python -c "import X"`：两个绑定常装在不同环境里（本机
#   PySide6 在 hermes venv、PyQt5 在托管 venv），只查当前解释器会把"装了"
#   报成"缺失" —— 假阳性一次，这份体检就再没人信了。
#   加载模块不会触发 main（它的 __name__ 不是 __main__）。
probe() {
    [ -n "$PY" ] || { echo ""; return; }
    "$PY" - "$1" <<'PYEOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("chp", "tools/check-host-parity.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
print(getattr(m, "find_python_with_" + sys.argv[1])() or "")
PYEOF
}

NEED_PYQT5=0
NEED_PYSIDE6=0
PYSIDE6_PY="$(probe pyside6)"
if [ -n "$PYSIDE6_PY" ]; then
    V="$("$PYSIDE6_PY" -c 'import PySide6;print(PySide6.__version__)' 2>/dev/null)"
    ok "PySide6 (Qt 6)" "$V · $PYSIDE6_PY"
else
    miss "PySide6 (Qt 6)" "缺失 —— pip install PySide6，或 QSkin_PYSIDE6_PYTHON=... 指定"
    NEED_PYSIDE6=1
fi
PYQT5_PY="$(probe pyqt5)"
if [ -n "$PYQT5_PY" ]; then
    V="$("$PYQT5_PY" -c 'from PyQt5.QtCore import QT_VERSION_STR;print(QT_VERSION_STR)' 2>/dev/null)"
    ok "PyQt5 (Qt 5)" "自带 Qt $V · $PYQT5_PY"
else
    miss "PyQt5 (Qt 5)" "缺失 —— pip install PyQt5（wheel 自带 Qt 5.15 运行时）"
    NEED_PYQT5=1
fi

# ---------- 3. Qt 6 SDK ----------
QT6=""
for d in .qt/*/*/; do
    [ -d "$d" ] || continue
    if [ -f "${d}bin/qml.exe" ] || [ -f "${d}bin/qml" ]; then QT6="${d%/}"; break; fi
done
if [ -n "$QT6" ]; then
    ok "Qt 6 SDK" "$QT6"
else
    miss "Qt 6 SDK" "缺失 —— bash tools/install-qt.sh（约 250MB）"
fi

# ---------- 4. Qt 5 SDK ----------
QT5=""
for d in "$QT5_BASE/$QT5_VER"/mingw81_64/ "$QT5_BASE"/*/*/; do
    [ -d "$d" ] || continue
    if [ -d "${d}lib/cmake/Qt5" ]; then QT5="${d%/}"; break; fi
done
if [ -n "$QT5" ]; then
    ok "Qt 5 SDK" "$QT5"
else
    miss "Qt 5 SDK" "缺失 —— aqt install-qt windows desktop $QT5_VER $QT5_ARCH"
fi

# ---------- 5. 两个 C++ 宿主 ----------
CPP=""
for c in .cache/hostbuild-cpp/qdshost.exe .cache/hostbuild-cpp/qdshost; do
    [ -f "$c" ] && { CPP="$c"; break; }
done
if [ -n "$CPP" ]; then ok "C++ 宿主 (Qt 6)" "$CPP"
else miss "C++ 宿主 (Qt 6)" "缺失 —— bash examples/hosts/cpp/build.sh"; fi

CPP5=""
for c in .cache/hostbuild-cpp-qt5/qdshost5.exe .cache/hostbuild-cpp-qt5/qdshost5; do
    [ -f "$c" ] && { CPP5="$c"; break; }
done
if [ -n "$CPP5" ]; then ok "C++ 宿主 (Qt 5)" "$CPP5"
else miss "C++ 宿主 (Qt 5)" "缺失 —— bash examples/hosts/cpp-qt5/build.sh"; fi

# ══════════ 体检模式到此为止 ══════════
if [ "$CHECK" -eq 1 ]; then
    echo ""
    if [ "$MISSING" -eq 0 ]; then
        echo "OK  五宿主环境齐备（缺失 0 项）—— 可以直接 ./tools/test.sh"
    else
        echo "NG  缺 $MISSING 项。补齐：./tools/setup-hosts.sh（不带 --check）"
    fi
    exit "$MISSING"
fi

# ══════════ 安装模式 ══════════
echo ""
echo "═══ 开始补齐 ═══"
RC_ALL=0

if [ -z "$PY" ]; then
    echo "跳过：没有 python，其余都装不了。"
    exit 8
fi

if [ "$NEED_PYSIDE6" -eq 1 ] || [ "$NEED_PYQT5" -eq 1 ]; then
    PKGS=""
    [ "$NEED_PYSIDE6" -eq 1 ] && PKGS="$PKGS PySide6"
    [ "$NEED_PYQT5" -eq 1 ] && PKGS="$PKGS PyQt5"
    echo "==> pip install$PKGS  （解释器：$PY）"
    if "$PY" -m pip install --disable-pip-version-check $PKGS; then
        echo "    装好了"
    else
        echo "    ✗ 安装失败（退出码 $?）—— 若是权限问题，加 --user 或换成 venv"
        RC_ALL=8
    fi
fi

if [ -z "$QT6" ]; then
    echo "==> 安装 Qt 6 SDK（串行下载，约 250MB，视网络 3~10 分钟）"
    if bash tools/install-qt.sh; then echo "    装好了"; else
        echo "    ✗ 安装失败（退出码 $?）"; RC_ALL=8
    fi
fi

if [ -z "$QT5" ]; then
    echo "==> 安装 Qt 5 SDK（$QT5_VER / $QT5_ARCH → $QT5_BASE）"
    if ! "$PY" -m aqt version >/dev/null 2>&1; then
        "$PY" -m pip install -q aqtinstall
    fi
    # ⚠ concurrency=1 不是保守，是必需：见 tools/install-qt.sh 文件头 ——
    #   并发下载在某些网络环境会**稳定**产出校验和不匹配的损坏包，5 次重试
    #   次次失败且哈希一致。这里自己跑 aqt，所以这段要跟着走一遍。
    AQT_PKG="$("$PY" -c 'import aqt,os;print(os.path.dirname(aqt.__file__))')"
    SETTINGS="$AQT_PKG/settings.ini"
    if [ -f "$SETTINGS" ]; then
        if grep -q "^concurrency" "$SETTINGS"; then
            sed -i.bak 's/^concurrency[[:space:]]*:.*/concurrency : 1/' "$SETTINGS"
        else
            sed -i.bak '1a\
concurrency : 1' "$SETTINGS"
        fi
        rm -f "$SETTINGS.bak"
    fi
    mkdir -p "$QT5_BASE"
    if "$PY" -m aqt install-qt windows desktop "$QT5_VER" "$QT5_ARCH" \
            -b "$MIRROR" --outputdir "$QT5_BASE"; then
        echo "    装好了"
    else
        echo "    ✗ 安装失败（退出码 $?）"
        RC_ALL=8
    fi
fi

if [ -z "$CPP" ]; then
    echo "==> 构建 C++ 宿主（Qt 6）"
    if bash examples/hosts/cpp/build.sh >/dev/null 2>&1; then echo "    好了"
    else echo "    ✗ 构建失败 —— 单独跑一次看报错：bash examples/hosts/cpp/build.sh"; RC_ALL=8; fi
fi

if [ -z "$CPP5" ]; then
    echo "==> 构建 C++ 宿主（Qt 5）"
    if bash examples/hosts/cpp-qt5/build.sh >/dev/null 2>&1; then echo "    好了"
    else echo "    ✗ 构建失败 —— 单独跑一次看报错：bash examples/hosts/cpp-qt5/build.sh"; RC_ALL=8; fi
fi

echo ""
if [ "$RC_ALL" -eq 0 ]; then
    echo "OK  补齐完成。下一步：./tools/test.sh"
    echo "    （若门仍说找不到 PySide6/PyQt5，用 QSkin_PYSIDE6_PYTHON / QSkin_PYQT5_PYTHON 指定解释器）"
else
    echo "NG  有步骤失败（见上）。修完再跑一次本脚本，它会跳过已齐的项。"
fi
exit "$RC_ALL"
