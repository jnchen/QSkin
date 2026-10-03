#!/usr/bin/env bash
#############################################################################
# QSkin · i18n 资产工具（抽取 / 编译）
#
# 用法：
#     ./tools/i18n.sh update    # lupdate：把 src/ 的 qsTr 抽进 i18n/*.ts（已译保留）
#     ./tools/i18n.sh build     # lrelease：i18n/*.ts -> i18n/*.qm
#     ./tools/i18n.sh all       # update + build（默认）
#
# ── 为什么不用 CMake 的 qt_add_translations ────────────────────────────────
# 本仓是**纯 QML 源码分发**（无 C++ 入口，见 ROADMAP §8.3）。构建路径由
# tools/lint.sh 的"构建清单门禁"守着，不走 cmake 的翻译目标。直接调
# lupdate / lrelease 更贴近"这份源码实际怎么被用"，也让 check-i18n.sh 能用
# **同一条命令**复算 —— 门禁与工具**不许各写一份路径逻辑**（写岔了就是
# 一套判据量两个东西，本项目栽过）。
#
# ── 为什么 .qm 要入库 ─────────────────────────────────────────────────────
# 源码分发形态下，宿主拿到的是 src/ 而不是编译产物。`.qm` 不跟着走的话，
# 宿主拿到的是一个**不能本地化**的框架 —— 而那正是 0.0.1 要避免的事。
#
# ── lupdate 的两个行为要知道 ──────────────────────────────────────────────
#   · `<location filename="…">` 是**相对 .ts 所在目录**写的。所以同一份源码、
#     同一个 .ts 路径 → location 稳定；但**判据不许比 location**（它含行号，
#     一改源码就漂）。check-i18n.py 只比 (context, source) 集合，就是这个原因。
#   · `-no-obsolete` 会把源码里已经没有的条目删掉。**保留已翻译的内容**不受
#     影响（lupdate 按 source 文本匹配），所以 update 是安全动作、可反复跑。
#############################################################################

set -euo pipefail
cd "$(dirname "$0")/.."

# ---------- 1. 定位 Qt（与 lint.sh / check-i18n.sh 同一段逻辑）----------
QT_ROOT="${QSkin_QT:-}"
if [ -z "$QT_ROOT" ]; then
    for d in .qt/*/*/; do
        [ -x "${d}bin/qmllint" ] && QT_ROOT="$d" && break
    done
fi

LUPDATE="$QT_ROOT/bin/lupdate"
LRELEASE="$QT_ROOT/bin/lrelease"
for tool in "$LUPDATE" "$LRELEASE"; do
    if [ ! -x "$tool" ]; then
        echo "找不到 $(basename "$tool")。"
        echo "请先跑 ./tools/install-qt.sh，或设置 QSkin_QT=/path/to/qt/mingw_64"
        exit 1
    fi
done

I18N_DIR="i18n"
SRC_DIR="src"
CMD="${1:-all}"

shopt -s nullglob
collect_ts() {
    TS_FILES=("$I18N_DIR"/*.ts)
    if [ ${#TS_FILES[@]} -eq 0 ]; then
        echo "$I18N_DIR/ 下没有 .ts 文件 —— 翻译资产尚未建立。"
        echo "（第一个语言文件应在 M33-7 落地：i18n/qskin_en.ts）"
        exit 1
    fi
}

do_update() {
    collect_ts
    for ts in "${TS_FILES[@]}"; do
        echo "==> lupdate  $SRC_DIR -> $ts"
        "$LUPDATE" "$SRC_DIR" -ts "$ts" -no-obsolete
    done
}

do_build() {
    collect_ts
    for ts in "${TS_FILES[@]}"; do
        qm="${ts%.ts}.qm"
        echo "==> lrelease $ts -> $qm"
        "$LRELEASE" "$ts" -qm "$qm"
    done
}

case "$CMD" in
    update) do_update ;;
    build)  do_build ;;
    all)    do_update; echo; do_build ;;
    *)
        echo "用法：$0 [update|build|all]"
        exit 2
        ;;
esac

echo
echo "完成。当前资产："
ls -l "$I18N_DIR"
