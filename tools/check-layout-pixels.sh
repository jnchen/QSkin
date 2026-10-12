#!/usr/bin/env bash
#############################################################################
# QSkin · 布局层像素门（M29）
#
# 规则：QSkinRow / QSkinColumn 的**余量分配**（justify）与**间隙**，在渲染出来
#       的像素上必须与场景定义的形状一致。详见 tools/check-layout-pixels.py
#       头部（含"自校准是怎么自校准的"）。
#
# 用法：
#     ./tools/check-layout-pixels.sh                 # Qt 6 侧（src/）
#     QSkin_QT=<Qt5.11根> ./tools/check-layout-pixels.sh --lib qt511
#                                                  # 在降级产物上跑
# ⚠ --lib 走的是同一条判据（从图里量余量与 gap），只是换了一棵树与一个引擎；
#   场景文件本身是 Qt 6 写法，跑之前**必须先降级**，
#   否则 5.11 直接 rc=2（import 版本不认）—— 这里自动做。
#
# 一般不用直接调 —— ./tools/test.sh 的第 3.8 节会自动带上这一步。
#
# ── 为什么这道门住在 tools/ 而不是 .cache/ ──────────────────────────────
# 本项目已经栽过：一批像素核验脚本（`_verify_mXXpx.py`）全住在 `.cache/`
# 里，一次清缓存就没了。**一个住在可丢弃目录里的闸不算闸**（M25 记的原话，
# M26 / M27 各自又验证了一遍）。所以：
#     · 场景   → tests/scene_layout_justify.qml   （跟门一起进仓库）
#     · 核验器 → tools/check-layout-pixels.py     （同上）
#     · 只有抓出来的 PNG 进 .cache/               （可丢弃才对）
#
# ── 为什么找不到 python 时按 0 退出 ─────────────────────────────────────
# 与 tools/check-color-util.sh / check-fuzzy-match.sh 逐字同源的理由：
# **不制造假失败** —— 环境缺 python 不是"这段代码错了"，报红会让 test.sh
# 把它读成"第 N 条断言失败"，一种看着有信息量、实则完全误导的报告。
# 代价说清楚：**这一层在缺 python 的环境里是静默失效的**，所以下面会把
# 实际用的解释器路径打出来 —— 看到"找不到 python"就说明它没在防任何东西。
#############################################################################

set -euo pipefail
cd "$(dirname "$0")/.."

LIB="src"
if [ "${1:-}" = "--lib" ]; then
    LIB="$2"; shift 2
fi

PNG=".cache/m29_layout.png"
SCENE="tests/scene_layout_justify.qml"

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
    echo "找不到 python —— **布局像素门这一层没有在防任何东西**。"
    echo "可用 QSkin_PYTHON=/path/to/python 指定。"
    exit 0
fi

# ⚠ 降级产物的场景要**先降级**再抓：场景是 src/ 的 Qt 6 写法，
#   不降级则 5.11 直接 rc=2（import 版本不认）。副本落在 .cache/，不污染 tests/。
if [ "$LIB" != "src" ]; then
    "$PY" - "$SCENE" "$LIB" <<'PYEOF'
import sys, os, collections, importlib.util
scene, lib = sys.argv[1], sys.argv[2]
root = os.path.dirname(os.path.dirname(os.path.abspath(scene)))
sys.path.insert(0, os.path.join(root, 'tools'))
spec = importlib.util.spec_from_file_location(
    'dg', os.path.join(root, 'tools', 'qml-downgrade.py'))
dg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dg)
txt = open(scene, encoding='utf-8').read()
out = dg.downgrade_text(txt, collections.Counter(), os.path.basename(scene),
                        dg.PROFILES[lib])
work = os.path.join(root, '.cache', 'scene')
os.makedirs(work, exist_ok=True)
open(os.path.join(work, os.path.basename(scene)), 'w',
     encoding='utf-8', newline='\n').write(out)
PYEOF
    SCENE=".cache/scene/scene_layout_justify.qml"
fi

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

# ---------- 1. 抓图 ----------
# 场景自己写 PNG 并 Qt.exit；shot.sh 带 60s 看门狗。
# ⚠ 场景把产物写到 `.cache/`（它用 `Qt.resolvedUrl("..")` 定位项目根），
#   不是 tests/ —— 尽量别把抓图产物丢进测试目录。
# ⚠ **不要**给 shot.sh 传 `theme=xxx`：qml 运行器会把这种 `k=v` 参数当成
#   第二个要加载的文件（实测 `theme=ant: No such file or directory`），
#   于是场景加载失败、而 qml 仍然返回 0。本场景不接主题（见其文件头）。
if [ "$LIB" = "src" ]; then
    SHOT_ARGS=()
else
    SHOT_ARGS=(--lib "$LIB")
fi
if ! ./tools/shot.sh "${SHOT_ARGS[@]}" "$SCENE"; then
    echo "!! 抓图失败（shot.sh 退出码非 0）"
    exit 1
fi
if [ ! -f "$PNG" ]; then
    echo "!! 抓图返回成功但 $PNG 不存在 —— 静默失败。"
    echo "   （grabWindow() 在本环境会这样：saveToFile 返回 true 但盘上没有文件，"
    echo "     场景必须用 Item.grabToImage —— 见 tests/scene_layout_justify.qml）"
    exit 1
fi

# ---------- 2. 核验 ----------
# 每次把解释器打出来：这一层静默失效时唯一的线索。
echo "（解释器：$PY）"
exec "$PY" tools/check-layout-pixels.py "$PNG"
