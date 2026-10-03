#!/usr/bin/env bash
#############################################################################
# QSkin · 清理 .cache 下的陈旧 import 树与临时探针产物
#
# 用法：
#     ./tools/clean-cache.sh               # 清 import 树副本
#     ./tools/clean-cache.sh --shots       # 只清验证截图（*.png）
#     ./tools/clean-cache.sh --all         # 探针脚本 + 截图 + 中间产物
#
# ── 为什么需要它 ───────────────────────────────────────────────────────
# tools/lint.sh、tools/test.sh、tools/shot.sh 每次运行都要重建一份
# .cache/qmlimports（因为 QML 按 URI 路径找模块，源码目录名对不上，
# 必须铺一份 URI 与目录匹配的副本）。
#
# 这些脚本刻意**不用 rm -rf** 删旧树，而是 mv 走 —— 整批删除会触发
# 环境的批量删除确认钩子把脚本卡死（M9.x 实录）。代价是每次都留一份
# .cache/qmlimports.stale.<时间戳>，几十次运行后会堆出上千个文件。
# 所以清理这件事单独放这里，由人显式触发，不在检查流程里做。
#
# ── 哪些东西该清、哪些该留 ─────────────────────────────────────────────
# 留：qmlimports（运行依赖）、shot_m*.qml（可复用的抓图入口，**--all 也不删**）。
# 清：验证截图（每轮跑完就是死数据，不是交付物）、
#     _det*（确定性演练目录，见下）、
#     diag_* / probe_* / iso* / dbg_* / bisect_* / t[0-9]（一次性诊断脚本）、
#     *.out（退出码探针日志）、__pycache__。
#
#     ⚠ 上面这些模式**按名字匹配、不分扩展名** —— 实测 `.cache/_probe_del.py`
#     （一个 .py）就是被 `*_probe*` 删掉的。所以：**凡是文档引用过的产物，
#     别只留一个文件名引用** —— 把内容写进文档，或放进不会被清理的目录。
#     README 曾同时引着 `_probe_url.qml` / `_probe_m20_4.qml` / `_probe_del.py`，
#     跑过一次 `--all` 之后三处全部悬空（M21 收口时才发现，已改为内联描述）。
#
# ── 与「安全删除守卫」共处（M17 实录，两轮才看穿）──────────────────────
# 宿主内置 safe-delete bulk guard：**一条命令里累计删除的文件数**达到阈值
# （代码默认 20，本机实测配成 50）就要求人在**宿主弹窗**里确认；未确认时
# `rm` 直接非零退出，stderr 打一行
#     [safe-delete][SAFE_DELETE_BULK_CONFIRM_REQUIRED] {...}
#
# 而 .cache 里**一份 qmlimports.stale.* 就有近百个文件** —— 必然触发。
#
# 于是本脚本**必须容忍 rm 失败**。早期版本带 `set -euo pipefail`，被守卫
# 拦下的第一次 rm 就把整个脚本打死：人看到的现象只是"跑了一下就没了 /
# 没输出"，完全看不出是守卫而不是 bug（M17 收口时因此白卡了两轮）。
# 所以下面每一处删除都单独兜错并**汇报实际清掉多少、还剩多少**。
#
# 用法结论：
#   **在前台跑**，别塞后台 —— 宿主才有机会把确认递到人手里。
#   确认之后，同一条命令里后续的删除都会被放行（确认是按"这一次工具调用"
#   记的，不是永久的）。
#############################################################################

set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d .cache ]; then
    echo "没有 .cache 目录，无需清理。"
    exit 0
fi

# ---------- 陈旧 import 树 ----------
N=$(find .cache -maxdepth 1 -name 'qmlimports.stale.*' -type d 2>/dev/null | wc -l | tr -d ' ')
BLOCKED=0
if [ "$N" -gt 0 ]; then
    # 一次删一个目录（不用通配一次删一批），但单份树里就有近百个文件，
    # 仍会撞上守卫的计数阈值 —— 所以 `|| BLOCKED=...` 是必需的，不是防御性冗余。
    for d in .cache/qmlimports.stale.*; do
        [ -d "$d" ] || continue
        rm -r "$d" 2>/dev/null || BLOCKED=$((BLOCKED + 1))
    done
    LEFT=$(find .cache -maxdepth 1 -name 'qmlimports.stale.*' -type d 2>/dev/null | wc -l | tr -d ' ')
    echo "陈旧 import 树：$N 份 → 清掉 $((N - LEFT)) 份，剩 $LEFT 份"
else
    echo "没有陈旧 import 树"
fi

# ---------- 验证截图 ----------
# 截图是**每轮**的验证中间产物，不是交付物：跑完当轮就失效了
# （换一行代码，像素就可能变）。留着只会让 .cache 里堆几十上百张
# 分不清哪张对应哪版代码的图，M11 收口时积了 82 张。
# 要长期保留某张，请显式复制到 .cache/keep/ 或文档目录。
if [ "${1:-}" = "--shots" ] || [ "${1:-}" = "--all" ]; then
    S=$(find .cache -maxdepth 1 -name '*.png' -type f 2>/dev/null | wc -l | tr -d ' ')
    find .cache -maxdepth 1 -name '*.png' -type f -delete 2>/dev/null || BLOCKED=$((BLOCKED + 1))
    S2=$(find .cache -maxdepth 1 -name '*.png' -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "验证截图：$S 张 → 清掉 $((S - S2)) 张，剩 $S2 张"
fi

# ---------- 确定性演练目录（--shots / --all）----------
# 排查"同一抓图屏两次拍出来不一样"时，会把连拍结果存进 _det/ _det2/ _det3/
# 逐张比 md5，用"哪种改法能让 md5 稳定"来反推根因。M20 靠这个办法定位到
# 焦点漂移（_det 三次同 md5 = 什么都不做；_det2 三次三个 md5 = forceActiveFocus
# 反而更糟；_det3 四次同 md5 = 0×0 惰性焦点承载者），M21 又照做了一遍。
#
# 这类目录是**过程证据**：结论一旦写进 README 就该丢 —— 留着只是十几张
# 分不清对应哪版代码的图。注意上面 --shots 那段只清 `-maxdepth 1 -name '*.png'`，
# **够不到子目录里的图**，所以演练目录会一直静静堆着
# （M21 收口时实测已堆了 5 个目录 / 16 张图）。
if [ "${1:-}" = "--shots" ] || [ "${1:-}" = "--all" ]; then
    D=$(find .cache -maxdepth 1 -name '_det*' -type d 2>/dev/null | wc -l | tr -d ' ')
    F=$(find .cache -maxdepth 2 -path '.cache/_det*/*' -type f 2>/dev/null | wc -l | tr -d ' ')
    for d in .cache/_det*; do
        [ -d "$d" ] || continue
        rm -r "$d" 2>/dev/null || BLOCKED=$((BLOCKED + 1))
    done
    D2=$(find .cache -maxdepth 1 -name '_det*' -type d 2>/dev/null | wc -l | tr -d ' ')
    echo "确定性演练目录：$D 个 / $F 个文件 → 清掉 $((D - D2)) 个，剩 $D2 个"
fi

# ---------- 探针与中间产物（--all） ----------
if [ "${1:-}" = "--all" ]; then
    # 一次性诊断脚本：按已知前缀清。
    # 注意 **不能** 用 `-name 'shot_*.qml'` —— 那个通配会连
    # shot_m4.qml / shot_m12.qml 这类**可复用**抓图入口一起删掉
    # （`shot_m12` 同样匹配 `shot_*`）。旧版注释写"shot_m*.qml 已保留"，
    # 但模式里根本没排除它，实际会删干净 —— 曾因此误删 6 个抓图脚本。
    #
    # ── 为什么是数组而不是 eval 拼串（M13 实录）──────────────────────
    # 早先用 `eval "find ... \( $PATTERNS \) ..."` 拼命令。问题在于：
    # 赋值时那些单引号只挡了第一层，**eval 里还有一层 shell 展开**，
    # 裸的 `*.log` 会被按**当前工作目录**展开成实际存在的文件名
    # （实测变成了 `aqtinstall.log`），于是 `-name '*.log'` 变成
    # `-name aqtinstall.log` —— 在 .cache 里永远匹配不到任何东西。
    # 这个 bug 长期隐形：`*.out` 恰好没匹配到文件才侥幸还能用。
    # 正解就是数组 + 直接调用，把 glob 交给 find 而不是 shell。
    PATTERNS=(
        -name 'diag*' -o -name 'probe*' -o -name 'iso*' -o -name 'dbg_*'
        -o -name 'bisect_*' -o -name 't[0-9]*' -o -name '*_probe*'
        -o -name '*.out' -o -name '*.log' -o -name 'test_*.qml'
        -o -name 'vis_*.qml' -o -name 'visual_*.qml' -o -name 'mini_*'
        -o -name '_*.qml'
    )
    P=$(find .cache -maxdepth 1 \( "${PATTERNS[@]}" \) -type f 2>/dev/null | wc -l | tr -d ' ')
    find .cache -maxdepth 1 \( "${PATTERNS[@]}" \) -type f -delete 2>/dev/null || BLOCKED=$((BLOCKED + 1))
    P2=$(find .cache -maxdepth 1 \( "${PATTERNS[@]}" \) -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "探针 / 一次性脚本：$P 个 → 清掉 $((P - P2)) 个，剩 $P2 个"
    K=$(find .cache -maxdepth 1 -name 'shot_m*.qml' -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "（shot_m*.qml 属可复用抓图入口，已保留 $K 个）"

    # Python 字节码缓存（.cache 下那些 _verify_*.py / mutate_*.py 的编译产物）。
    # 删掉只是下次导入慢一点点，无副作用。
    if [ -d .cache/__pycache__ ]; then
        rm -r .cache/__pycache__ 2>/dev/null || BLOCKED=$((BLOCKED + 1))
        echo "Python 字节码缓存：已清"
    fi
fi

# ---------- 守卫拦截时的交代 ----------
# 这是本脚本最容易被人误读的一步：被拦下时 rm 会失败，但**脚本本身没坏**。
# 必须把"这不是错误、该怎么继续"写清楚，否则下一个人还会当成 bug 查一遍。
if [ "$BLOCKED" -gt 0 ]; then
    echo
    echo "!! 有 $BLOCKED 批删除被宿主的「安全删除守卫」拦下，尚未执行。"
    echo "   判据是**一条命令里累计删除的文件数**超过阈值（代码默认 20，本机 50），"
    echo "   此时 rm 直接失败并在 stderr 打："
    echo "       [safe-delete][SAFE_DELETE_BULK_CONFIRM_REQUIRED] {...}"
    echo "   → 请在**前台**重跑本脚本，等宿主弹窗出现并点确认。"
    echo "     确认后同一条命令里后续删除都会被放行（按「这一次工具调用」记，非永久）。"
    echo "   → 或者：把要保留的先 cp 到 .cache/keep/，其余整体弃掉再重建 .cache。"
fi

echo "完成。.cache 现有 $(ls -1 .cache | wc -l | tr -d ' ') 项。"
