#!/usr/bin/env bash
#############################################################################
# QSkin · 第十二道门（运行期警告）的证伪器
#
# 规则：**一道没被证伪过的闸不算闸。** 本脚本给
#       tools/check-runtime-warn.py 打 7 枪，每枪**声明预期的退出码**，
#       跑完逐一比对；有一枪不符就整体判失败。
#
# 用法：
#     ./tools/falsify-runtime-warn.sh
#
# ── 这 7 枪各证明什么 ───────────────────────────────────────────────────
#   F0 先跑一遍"全豁免"                    → 期望 0（**没有这一枪，后面的红没有参照**：
#                                            分不清"红是因为变异"还是"本来就红"）
#   F1 名单里删掉一条**确实命中**的豁免    → 期望 1（新增即红）
#   F2 名单里加一条**假的**豁免            → 期望 2（过期豁免即红）
#   F3 上面两种同时来                      → 期望 3（两个位都亮）
#   F4 日志里一个 @@@FILE 段都没有         → 期望 9（工装坏了；"检查了 0 条"算失败）
#   F5 把日志里某条的**出处**换成一个新文件 → 期望 3（新键 NEW + 原键 STALE）
#   F6 **真源变异**：往一个真的 QML 里塞一句必然报错的赋值，
#      真跑一次、按 test.sh 的段格式累积      → 期望 1（累积链路是通的）
#   F6b F6 的附带断言：真跑必须**真的产出引擎诊断**
#       （否则"期望 1 实测 1"可能只是空日志碰巧也红 —— F4 就是空日志）
#
#   F0~F5 打的是**比较逻辑**（纯文本，秒级、确定性）；
#   F6/F6b 打的是**累积链路**（真跑 qml.exe）。少了 F6，F0~F5 全绿也只能
#   证明"比较器没坏"，证明不了"警告真的会进到日志里"。
#
# ── 为什么 F4 期望的是 9 而不是 1 ────────────────────────────────────────
# 本项目的一条硬规矩：**「检查了 0 条」一律算失败。** 一个"没有输入所以
# 永远绿"的闸比没有闸更坏 —— 它让人以为这里有人在看。所以"读不到输入"
# 必须是**独立的一类**（退出码 9 = 工装），不能混进"新增警告"里，
# 否则维护者会去翻代码，而真相是日志没生成。
#
# ── 已知的刻意重复 ──────────────────────────────────────────────────────
# 本脚本自己拼 `@@@FILE / @@@EXIT / 正文 / @@@END` 四段 —— 也就是把
# tools/test.sh 第 3 节的段格式**抄了一份**。这是有意的：证伪器必须是
# 自足的（不能依赖"先跑一次 test.sh"）。代价是格式漂移时两边会不一致，
# 而那正好会被 F1~F6 打出来（解析器读不懂 → 键全变 → 全线红）。
#############################################################################

cd "$(dirname "$0")/.."

PY=""
for c in python3 python py; do
    command -v "$c" >/dev/null 2>&1 && PY=$(command -v "$c") && break
done
if [ -z "$PY" ]; then
    for d in "$HOME"/.workbuddy/binaries/python/versions/*/python.exe; do
        [ -x "$d" ] && PY="$d" && break
    done
fi
if [ -z "$PY" ]; then
    echo "!! 找不到 python —— 证伪器跑不了。**这不代表门是好的。**"
    exit 1
fi

W=".cache/m31b_falsify"
mkdir -p "$W"
LOG="$W/log.txt"
EX="$W/exempt.txt"

# ── 合成一份"像真的"累积日志 ────────────────────────────────────────────
# 三条引擎诊断（**逐字抄自真实输出**，连路径形状与两种位置格式都一致）
# + 一条自家输出（必须被判为"不判"）。
mklog() {
    : > "$LOG"
    printf '@@@RUN falsify @ test\n' >> "$LOG"
    printf '@@@FILE smoke_a.qml\n@@@EXIT 0\n' >> "$LOG"
    printf 'file:///C:/x/.cache/qmlimports/QSkin/Contracts/AAA.qml:10:5: Unable to assign [undefined] to double\n' >> "$LOG"
    printf 'qml: 自家输出，不是警告\n' >> "$LOG"
    printf '@@@END\n' >> "$LOG"
    printf '@@@FILE smoke_b.qml\n@@@EXIT 0\n' >> "$LOG"
    printf 'file:///C:/x/.cache/qmlimports/QSkin/Contracts/BBB.qml:20:9: QML Rectangle: Detected anchors on an item that is managed by a layout. This is undefined behavior; use Layout.alignment instead.\n' >> "$LOG"
    printf '@@@END\n' >> "$LOG"
    printf '@@@FILE smoke_c.qml\n@@@EXIT 1\n' >> "$LOG"
    printf 'file:///C:/x/.cache/qmlimports/QSkin/Contracts/CCC.qml:30: TypeError: Cannot read property '"'"'width'"'"' of null\n' >> "$LOG"
    printf '@@@END\n' >> "$LOG"
}

K_A="ASSIGN	QSkin/Contracts/AAA.qml	Unable to assign [undefined] to double"
K_B="ANCHORS	QSkin/Contracts/BBB.qml	QML Rectangle: Detected anchors on an item that is managed by a layout. This is undefined behavior; use Layout.alignment instead."
K_C="EXC	QSkin/Contracts/CCC.qml	TypeError: Cannot read property 'width' of null"

mkext() {          # $1 = 要写进去的条目（多个，用换行分隔）
    printf '# 证伪器临时名单\n' > "$EX"
    printf '%s\n' "$1" >> "$EX"
}

FAILS=0
gun() {            # $1=枪名  $2=声明的退出码  $3..=日志路径与额外参数
    local name="$1" want="$2"; shift 2
    local got=0
    "$PY" tools/check-runtime-warn.py "$@" > "$W/$name.out" 2>&1 || got=$?
    if [ "$got" -eq "$want" ]; then
        printf '   OK   %-4s 期望 %-3s 实测 %-3s  %s\n' "$name" "$want" "$got" "$(grep -m1 '^OK  \|^NG  \|^!!' "$W/$name.out" | cut -c1-72)"
    else
        printf '   MISS %-4s 期望 %-3s 实测 %-3s  <- 不符\n' "$name" "$want" "$got"
        sed 's/^/          | /' "$W/$name.out" | head -12
        FAILS=$((FAILS + 1))
    fi
}

echo "第十二道门 · 证伪（7 枪）"

# ── F0：先确认"全豁免"这一档是绿的 ──────────────────────────────────────
# 没有这一枪，后面 F1/F2 的红就没有参照 —— 分不清"红是因为变异"还是
# "本来就红"。
mklog; mkext "$K_A
$K_B
$K_C"
gun F0 0 "$LOG" --exempt="$EX"

# ── F1：删掉一条命中中的豁免 → 新增即红 ─────────────────────────────────
mklog; mkext "$K_B
$K_C"
gun F1 1 "$LOG" --exempt="$EX"

# ── F2：加一条假豁免 → 过期豁免即红 ─────────────────────────────────────
mklog; mkext "$K_A
$K_B
$K_C
NOEXIST	QSkin/Contracts/ZZZ.qml	QML Binding: Property 'control' does not exist on QQuickItem."
gun F2 2 "$LOG" --exempt="$EX"

# ── F3：两种同时来 → 3 ──────────────────────────────────────────────────
mklog; mkext "$K_B
$K_C
ASSIGN	QSkin/Contracts/YYY.qml	Unable to assign [undefined] to double"
gun F3 3 "$LOG" --exempt="$EX"

# ── F4：日志里没有 @@@FILE 段 → 工装（9）─────────────────────────────────
mklog; mkext "$K_A
$K_B
$K_C"
sed 's/^@@@FILE /@@@XXFILE /' "$LOG" > "$W/log_nofile.txt"
gun F4 9 "$W/log_nofile.txt" --exempt="$EX"

# ── F5：换掉某条的出处 → 新键 NEW + 原键 STALE → 3 ───────────────────────
mklog; mkext "$K_A
$K_B
$K_C"
sed 's#Contracts/BBB.qml#Contracts/BBB_MOVED.qml#' "$LOG" > "$W/log_renamed.txt"
gun F5 3 "$W/log_renamed.txt" --exempt="$EX"

# ── F6：真源变异 —— 真跑一次 qml，证明"警告真的会进日志" ────────────────
# 这一枪打的是累积链路。前面五枪全在文本层面，全绿也证明不了这件事。
#
# ⚠ 它用的是**一份空名单**，不是前面那份合成的。理由（首跑实测出来的）：
#   真源跑出来的日志，与任何**手写**名单都对不上 —— 首跑我拿合成的三条名单
#   跑它，实测 3 而不是我声明的 1，因为多亮了一个 STALE 位（合成名单里有
#   三条真日志里根本不存在的键）。**那是我声明错了，不是门错了。**
#   空名单把这一枪的语义收窄成一句话：**新出现的警告 = 红。**
#
#   实测它一次报出**两条**新键，两条都对：
#     · NOEXIST `Cannot assign to non-existent property "title"` （我塞的那句）
#     · LOAD    `QQmlApplicationEngine failed to load component`（随之而来的）
#   顺手证明了形态表里那条兜底：认不出的行会被判成 UNCLASSIFIED 并计红，
#   不会被悄悄放过。
PROBE="$W/broken.qml"
cat > "$PROBE" <<'QML'
import QtQuick 2.15
Item {
    property int ok: 1
    Item { id: bad; title: "Item 上没有 title —— 必然报错" }
}
QML
EXE="$W/exempt_empty.txt"
printf '# 空名单：这一枪只证明「新增即红」\n' > "$EXE"
LOG2="$W/log_real.txt"
: > "$LOG2"
printf '@@@RUN falsify-real\n' >> "$LOG2"
printf '@@@FILE broken.qml\n' >> "$LOG2"
printf '@@@EXIT %s\n' 0 >> "$LOG2"
QT_FORCE_STDERR_LOGGING=1 timeout 30 .qt/*/*/bin/qml.exe -I .cache/qmlimports "$PROBE" \
    >> "$LOG2" 2>&1 || true
printf '@@@END\n' >> "$LOG2"
gun F6 1 "$LOG2" --exempt="$EXE"
# 这一枪还附带一条断言：真跑必须真的产出 ≥1 行引擎诊断。
# 否则"期望 1 实测 1"可能只是**空日志碰巧也报红**（F4 那种情形）。
if grep -qE 'failed to load component|does not exist' "$LOG2"; then
    printf '   OK   %-4s 真跑产出了引擎诊断（不是空日志碰巧红）\n' "F6b"
else
    printf '   MISS %-4s 真跑没产出任何引擎诊断 —— 这一枪没有在打累积链路\n' "F6b"
    FAILS=$((FAILS + 1))
fi

echo ""
if [ "$FAILS" -eq 0 ]; then
    echo "OK  7 枪全部按声明命中"
    exit 0
else
    echo "NG  $FAILS 枪不符声明 —— 这道门的判据需要重看"
    exit 1
fi
