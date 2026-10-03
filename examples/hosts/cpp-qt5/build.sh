#!/usr/bin/env bash
#############################################################################
# QSkin · 构建 C++ 宿主的 Qt 5 变体（examples/hosts/cpp-qt5）
#
# 用法：bash examples/hosts/cpp-qt5/build.sh
#
# ── 与 Qt 6 那份 build.sh 的关键差别 ───────────────────────────────────────
#   · Qt 前缀来自 QT5_PREFIX（默认 ~/.workbuddy/binaries/qt5/5.15.2/mingw81_64）
#     —— 那是为了和 **PyQt5 自带的 Qt 5.15.2 同版本** 才装的：对账要可比，
#        两边 Qt 版本必须一致，否则差异说不清是库的问题还是 Qt 的问题。
#
# ── 为什么改用 MinGW（原先走 MSVC，走不通）────────────────────────────────
# 原先这份脚本要求 vcvars64.bat + MSVC，但本机只有 VS2022 **BuildTools**
# （没有完整 MSVC 工具链），cmake 报 `No CMAKE_CXX_COMPILER could be found`
# —— 那不是 QSkin 的问题，是这台机器缺工具链，于是这一格一直写着"未实测"。
#
# 换 MinGW 之后能编了：编译器用项目内 `.qt/Tools/mingw1310_64`（GCC 13.1），
# Qt 用 **mingw81_64** 变体。§ 关于"Qt 用 GCC 8.1 编、我们用 GCC 13 编"：
# MinGW 的 libstdc++ 向后兼容，实测链接与运行都正常；若将来换了 Qt 变体，
# 这条注释要跟着改，别当成无条件成立。
#
# ⚠ 本脚本沿用 cpp/build.sh 里踩过的三条坑，别改回去：
#    1. 探测循环一律 `if`，不要 `[ -x X ] && VAR=X && break`（set -e 下会静默退出）
#    2. 交给 cmake.exe 的路径必须 cygpath -w 转 Windows 风格
#    3. 回仓库根要退**三**层，并断言 CMakeLists.txt 在
#############################################################################
set -euo pipefail

cd "$(dirname "$0")/../../.."

if [ ! -f CMakeLists.txt ]; then
    echo "工装错误：没落在仓库根（当前 $(pwd)），CMakeLists.txt 不在。"
    exit 8
fi

HERE="$(pwd)"
SRC="examples/hosts/cpp-qt5"
OUT=".cache/hostbuild-cpp-qt5"

# ---------- cmake ----------
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
    for n in "$HOME/.workbuddy/binaries/python/envs/default/Scripts/ninja.exe" \
             "$HOME/.workbuddy/binaries/python/envs/default/Scripts/ninja"; do
        if [ -x "$n" ]; then NINJA="$n"; break; fi
    done
fi
if [ -z "$NINJA" ] && command -v ninja >/dev/null 2>&1; then NINJA="$(command -v ninja)"; fi

# ---------- Qt 5 前缀 ----------
# ⚠ 必须**显式优先 mingw81_64**：Qt 5.15.2 目录下同时有 msvc2019_64 变体，
#   本机没有能用的 MSVC 工具链，glob 取到它就会卡在 "CXX compiler
#   identification is unknown"，而且看不出是选错了变体。
QT_PREFIX="${QT5_PREFIX:-}"
if [ -z "$QT_PREFIX" ]; then
    for d in "$HOME/.workbuddy/binaries/qt5/5.15.2"/mingw81_64/ \
             "$HOME/.workbuddy/binaries/qt5/5.15.2"/*/; do
        if [ -d "${d}lib/cmake/Qt5" ]; then
            QT_PREFIX="$(cd "$d" && pwd)"
            break
        fi
    done
fi
if [ -z "$QT_PREFIX" ]; then
    echo "找不到 Qt 5.15.2。请设置 QT5_PREFIX=/path/to/qt5/5.15.2/<variant>"
    exit 8
fi

# ---------- MinGW 编译器（与 Qt 6 那份同一套探测）----------
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
    if [ -x "$bindir/gcc.exe" ]; then CC="$bindir/gcc.exe"; fi
    if [ -x "$bindir/gcc" ]; then CC="$bindir/gcc"; fi
fi
if [ -z "$CXX" ]; then
    echo "工装错误：找不到 MinGW g++（.qt/Tools/*/bin/g++）。可用 CXX=... 指定。"
    exit 8
fi

winpath() {
    if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1" 2>/dev/null || echo "$1"
    else echo "$1"; fi
}

echo "cmake     : $CMAKE"
echo "ninja     : ${NINJA:-（未找到，回退默认生成器）}"
echo "Qt5 prefix: $QT_PREFIX"
echo "CXX       : $CXX"

GEN_ARGS=(-S "$SRC" -B "$OUT"
          -DCMAKE_PREFIX_PATH="$(winpath "$QT_PREFIX")"
          -DCMAKE_BUILD_TYPE=Release
          -DCMAKE_CXX_COMPILER="$(winpath "$CXX")")
[ -n "$CC" ] && GEN_ARGS+=(-DCMAKE_C_COMPILER="$(winpath "$CC")")
if [ -n "$NINJA" ]; then
    GEN_ARGS+=(-G Ninja -DCMAKE_MAKE_PROGRAM="$(winpath "$NINJA")")
fi

"$CMAKE" "${GEN_ARGS[@]}"
"$CMAKE" --build "$OUT"
RC_BUILD=$?

echo ""
BIN="$OUT/Release/qdshost5.exe"
[ -f "$BIN" ] || BIN="$OUT/qdshost5.exe"
[ -f "$BIN" ] || BIN="$OUT/qdshost5"
if [ -x "$BIN" ]; then
    echo "OK  构建完成：$BIN"
else
    echo "NG  构建结束但没找到可执行文件（$BIN）"
    exit 1
fi
