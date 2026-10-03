#!/usr/bin/env bash
#############################################################################
# QSkin · 构建 C++ 宿主（examples/hosts/cpp）
#
# 用法：bash examples/hosts/cpp/build.sh
#
# ── 为什么这份脚本要自己找工具链 ──────────────────────────────────────────
# 本机的 cmake / ninja 都住在 WorkBuddy 的托管 Python 环境里，**不在 PATH**；
# Qt 与 MinGW 则是项目内安装的（`.qt/`）。直接敲 `cmake` 会 command not found。
# 所以这里按主工程 `build/CMakeCache.txt` 里已验证过的那套路径逐个定位 ——
# 不猜、不重新发明。
#############################################################################
set -euo pipefail

# 本脚本住在 examples/hosts/cpp/ —— 回仓库根要退**三**层。
# ⚠ 别写成 ../..（那就停在 examples/，.qt glob 匹配不到、转成字面量，
#   表现为"找不到 Qt"而没有任何报错）。下面那条断言就是防这个的。
cd "$(dirname "$0")/../../.."

if [ ! -f CMakeLists.txt ]; then
    echo "工装错误：没落在仓库根（当前 $(pwd)），CMakeLists.txt 不在。"
    echo "          检查 build.sh 里 cd 的层数。"
    exit 8
fi

HERE="$(pwd)"
SRC="examples/hosts/cpp"
OUT=".cache/hostbuild-cpp"

# ---------- cmake ----------
# ⚠ 探测循环一律用 `if`，不要写 `[ -x X ] && VAR=X && break`：
#   在 `set -e` 下，第一项不匹配时整个 && 列表返回非 0，**脚本直接退出**
#   （且不带任何报错，看起来像"后面的逻辑没跑"）。踩过。
CMAKE="${CMAKE:-}"
if [ -z "$CMAKE" ]; then
    for c in \
        "$HOME/.workbuddy/binaries/python/envs/default/Lib/site-packages/cmake/data/bin/cmake.exe" \
        "$HOME/.workbuddy/binaries/python/envs/default/Lib/site-packages/cmake/data/bin/cmake" ; do
        if [ -x "$c" ]; then CMAKE="$c"; break; fi
    done
fi
if [ -z "$CMAKE" ] && command -v cmake >/dev/null 2>&1; then CMAKE="$(command -v cmake)"; fi
if [ -z "$CMAKE" ]; then echo "找不到 cmake。请安装或设置 CMAKE=/path/to/cmake"; exit 8; fi

# ---------- ninja ----------
NINJA="${NINJA:-}"
if [ -z "$NINJA" ]; then
    for n in \
        "$HOME/.workbuddy/binaries/python/envs/default/Scripts/ninja.exe" \
        "$HOME/.workbuddy/binaries/python/envs/default/Scripts/ninja" ; do
        if [ -x "$n" ]; then NINJA="$n"; break; fi
    done
fi
if [ -z "$NINJA" ] && command -v ninja >/dev/null 2>&1; then NINJA="$(command -v ninja)"; fi

# ---------- Qt 前缀 ----------
QT_PREFIX="${QT_PREFIX:-}"
if [ -z "$QT_PREFIX" ]; then
    for d in .qt/*/*/; do
        if [ -d "${d}lib/cmake/Qt6" ]; then
            QT_PREFIX="$(cd "$d" && pwd)"
            break
        fi
    done
fi
if [ -z "$QT_PREFIX" ]; then echo "找不到 Qt。请先跑 ./tools/install-qt.sh 或设置 QT_PREFIX"; exit 8; fi

# ---------- MinGW 编译器 ----------
CXX="${CXX:-}"
CC="${CC:-}"
if [ -z "$CXX" ]; then
    for g in .qt/Tools/*/bin/g++.exe .qt/Tools/*/bin/g++; do
        if [ -x "$g" ]; then
            CXX="$(cd "$(dirname "$g")" && pwd)/$(basename "$g")"
            break
        fi
    done
fi
if [ -n "$CXX" ]; then
    bindir="$(dirname "$CXX")"
    [ -x "$bindir/gcc.exe" ] && CC="$bindir/gcc.exe"
    [ -x "$bindir/gcc" ] && CC="$bindir/gcc"
fi

# ── 路径风格转换 ──────────────────────────────────────────────────────────
# 上面探测到的是 Git Bash 风格（/c/Users/...）。bash 自己能执行这种路径，
# 但 **cmake.exe 是 Windows 原生程序**，它拿到 /c/... 会原样传给
# CreateProcess ⇒ "no such file or directory"（实测就卡在这儿）。
# 所以凡是要**交给 cmake** 的路径，都用 cygpath 转成 C:/... 。
winpath() {
    if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1" 2>/dev/null || echo "$1"
    else echo "$1"; fi
}

echo "cmake     : $CMAKE"
echo "ninja     : ${NINJA:-（未找到，回退默认生成器）}"
echo "Qt prefix : $QT_PREFIX"
echo "CXX       : ${CXX:-（用 cmake 默认）}"

GEN_ARGS=(-S "$SRC" -B "$OUT" -DCMAKE_PREFIX_PATH="$(winpath "$QT_PREFIX")" -DCMAKE_BUILD_TYPE=Release)
[ -n "$CXX" ] && GEN_ARGS+=(-DCMAKE_CXX_COMPILER="$(winpath "$CXX")")
[ -n "$CC" ] && GEN_ARGS+=(-DCMAKE_C_COMPILER="$(winpath "$CC")")
if [ -n "$NINJA" ]; then GEN_ARGS+=(-G Ninja -DCMAKE_MAKE_PROGRAM="$(winpath "$NINJA")"); fi

"$CMAKE" "${GEN_ARGS[@]}"
"$CMAKE" --build "$OUT"

echo ""
if [ -f "$OUT/qdshost.exe" ]; then BIN="$OUT/qdshost.exe"; else BIN="$OUT/qdshost"; fi
if [ -x "$BIN" ]; then
    echo "OK  构建完成：$BIN"
else
    echo "NG  构建结束但没找到可执行文件（$BIN）"
    exit 1
fi
