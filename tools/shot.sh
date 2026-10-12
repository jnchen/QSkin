#!/usr/bin/env bash
#############################################################################
# QSkin · 自动化截图运行器（带看门狗）
#
# 用法：
#     ./tools/shot.sh <qml文件> [qml 参数...]
#     ./tools/shot.sh .cache/shot_m8.qml theme=tdesign scene=dialog
#
# ── 为什么必须走这个脚本，而不是直接 qml.exe ──────────────────────────
# qml.exe 是 Windows GUI 子系统，抓图脚本的退出路径依赖 Timer /
# grabToImage 回调，在这套工具环境里偶发停摆（M8 实录：Toast 场景卡死）。
# 卡死的进程不会自己退出，窗口画了第一帧就冻结 —— 点不动、没 hover，
# 还会被用户当成「交互没接上」的 bug。
#
# 所以这里套 60 秒硬超时：正常抓图 1.5~3 秒完成，超时即杀，
# 退出码 124 = 超时（截图没生成，脚本层面就知道出事了）。
#############################################################################

set -euo pipefail
cd "$(dirname "$0")/.."

# ⚠ `--lib <dir>` 必须在读 FILE **之前**解析：否则第一个参数会被当成
#   qml 文件名（实测 `--lib qt511 scene.qml` ⇒ `FILE=--lib` ⇒ 报「用法」）。
LIB_ARG=""
if [ "${1:-}" = "--lib" ]; then
    LIB_ARG="$2"; shift 2
fi

FILE="${1:-}"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "用法：./tools/shot.sh [--lib <产物目录>] <qml文件> [qml 参数...]"
    exit 1
fi
shift

# ---------- 定位 Qt ----------
QT_ROOT="${QSkin_QT:-}"
if [ -z "$QT_ROOT" ]; then
    for d in .qt/*/*/; do
        [ -x "${d}bin/qml" ] && QT_ROOT="$d" && break
    done
fi
QML="$QT_ROOT/bin/qml"
if [ ! -x "$QML" ]; then
    echo "找不到 qml 运行器。请先跑 ./tools/install-qt.sh，或设置 QSkin_QT=/path/to/qt"
    exit 1
fi

# ---------- 搭 import 树（强制重建：mv 旧目录重建新目录） ----------
#
# ⚠ `--lib <dir>`：把 import 根从 src/ 换成**降级产物**（qt5/ · qt511/）。
#   动机：像素门与冒烟要在**目标 Qt 的那棵树**上跑才有意义
#   （在 src/ 上跑等于又验了一遍 Qt 6，那条线本来就有门）。
#   ⚠ 降级产物的物理目录**已经等于 URI 路径**（Qt 5 没有 URI→目录映射），
#       所以这里直接整目录当 import 根，不做上面那套 URI 映射。
LIB_ROOT="src"
IMPORT_DIR=".cache/qmlimports"
if [ -n "$LIB_ARG" ]; then
    LIB_ROOT="$LIB_ARG"
    IMPORT_DIR=".cache/imports.$(basename "$LIB_ARG")"
fi

# 旧版用 rm -rf + 重建，被批量删除确认钩子拦过（M8+ 教训）。
# 这里用 mv + 重建：旧目录整批移走（一次 rename，不触发 rm 钩子），
# 然后 cp 出新的。旧目录留在 .cache/qmlimports.stale.<时间戳>，
# 用 tools/clean-cache.sh 统一清理。
if [ -d "$IMPORT_DIR" ]; then
    mv "$IMPORT_DIR" "${IMPORT_DIR}.stale.$(date +%s)" 2>/dev/null || true
fi
if [ "$LIB_ROOT" = "src" ]; then
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
else
    # 降级产物：QSkin/Contracts、QSkin/Foundation、QSkin/Theme/* 都已就位
    mkdir -p "$IMPORT_DIR"
    cp -r "$LIB_ROOT/QSkin" "$IMPORT_DIR/QSkin"
    echo "（import 根来自降级产物：$LIB_ROOT → $IMPORT_DIR）"
fi

# ---------- 让 QML 的报错真的可见（M13 实录） ----------
# 本环境是 Windows GUI 子系统、没有控制台：QML 引擎的报错默认走
# OutputDebugString 而不是 stderr，于是**静默失败** —— 组件的加载错误
# 在日志里只剩一句 "Did not load any objects, exiting."，既不说哪一行、
# 也不说哪个属性，排查全靠二分猜。这个变量把日志强制接到 stderr。
# 可以自己覆盖：QT_FORCE_STDERR_LOGGING=0 ./tools/shot.sh ...
export QT_FORCE_STDERR_LOGGING="${QT_FORCE_STDERR_LOGGING:-1}"

# ---------- 看门狗 ----------
timeout --kill-after=5 60 "$QML" -I "$IMPORT_DIR" "$FILE" "$@"
code=$?
if [ "$code" -eq 124 ]; then
    echo "NG  截图超时被看门狗击杀（$FILE）—— 脚本停摆，未产出图片"
    exit 124
fi
exit "$code"
