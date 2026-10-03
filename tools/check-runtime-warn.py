#!/usr/bin/env python3
#############################################################################
# QSkin · 第十二道门：运行期警告（存量豁免 + 新增即红）
#
# 用法：
#     ./tools/check-runtime-warn.sh              # 跟着 test.sh 走，全绿退出 0
#     python tools/check-runtime-warn.py --list  # 列出全部警告（含已豁免）
#     python tools/check-runtime-warn.py 日志路径
#
# ── 这道门守的是什么 ────────────────────────────────────────────────────
# `tools/test.sh` 原来把每个冒烟文件的 stdout+stderr 写进同一个
# `.cache/_test_stderr.log`，**每轮覆盖**，且只在文件 FAIL / LOAD / HANG
# 时才打印出来。于是 **PASS 的文件的运行期警告被整段丢掉** ——
# "属性对 + 像素对"这套判据从头到尾看不见运行期在喊什么。
#
# M27 做裁决五的探针时撞见这件事，量出 675 行警告而三道门禁全绿，
# 欠账记在 COVERAGE.md 第七节。**M31 第二件**补上：
#   · test.sh 把自己的 stderr **累积**成 .cache/_test_warn_all.log（每文件分段）
#   · 本核验器把累积日志归类，与 tools/runtime-warn-exempt.txt 对账
#
# ── 判据（三条，都能被证伪）────────────────────────────────────────────
#   ① 有警告**没出现在豁免名单里**  → 红（"新增即红"）
#   ② 豁免名单里有条目**一条警告都没命中** → 红（"过期豁免"）
#   ③ 累积日志里一个文件都没读到 / 一行都没有 → 红（工装坏了）
#
#   ⚠ ③ 是本项目的硬规矩：**"检查了 0 条"一律算失败。** 一个"没有输入
#     所以永远绿"的闸，比没有闸更坏 —— 它会让人以为这里有人在看。
#
# ── 为什么"过期豁免"也要判红（照抄构建清单门禁 [8] 的裁决）──────────────
# 豁免的作用是"**临时**承认一笔账"，不是"永久关掉一条判据"。一笔不再命中
# 的豁免有两种可能，都必须有人看一眼：
#     · 那一处真的修好了 → 删掉这行（这就是"可复位"）
#     · 警告还在，但**测试面变了**（触发它的那个冒烟改了/删了）→ 那是
#       覆盖变窄，不是问题消失。删掉这行之前先问一句"它还该被谁触发"。
# 所以本报告对过期豁免的措辞是**两种可能都写出来**，而不是简单命令删除。
#
# ── 键为什么是 (形态, 出处, 消息) 三元组，**不含行号** ──────────────────
# 行号会漂。本项目已经栽过一次：COVERAGE 里原写「QSkinRow.qml:110」，
# M29 重写该文件后那个行号指到别处了。**指路要用结构名，别用行号。**
# 换成"形态 + 库文件 + 消息"之后，行号怎么漂都不影响对账；代价是
# **同一文件里同一形态的第二个不同 bug 会撞进同一条豁免** —— 这是这笔
# 设计的已知损失，写在"已知未覆盖"里，不装作没有。
#
# ── 已知未覆盖（正账，不是"应该没问题"）────────────────────────────────
#   1. **看不见 `console.warn` / `console.error`。** 实测本机 Qt 6.8.3：
#      `console.log` / `warn` / `error` / `debug` 四种**前缀全是 `qml: `**，
#      无法区分。本闸因此把 `qml: ` 开头的行整段判为"程序自己的输出"
#      （其中有负向测试故意打的日志），于是新代码里的 `console.warn` 逃逸。
#      报告里会把这类行的**条数与形状数打出来** —— 漂移看得见，但不判红。
#      真正的堵法是静态查 `console.warn` 的用法，属另一条账。
#   2. **只覆盖 `tests/smoke_*.qml`。** 场景（`tests/scene_*.qml`，走
#      shot.sh）与真鼠标事件那一段（`tst_*`，走 qmltestrunner，
#      输出被 `>/dev/null 2>&1` 丢掉）不在累积范围内。
#   3. **同一文件同一形态的第二个不同 bug 会撞进同一条豁免**（见上）。
#   4. **单平台成立。** 豁免名单是对着 mingw64 / 本机 Qt 6.8.3 量的；
#      换平台插件或换 Qt 版本，警告集合可能不同 → 会把一堆豁免判成过期。
#      本仓只有一套 Qt（`.qt/6.8.3/mingw_64`），所以这个前提目前成立，
#      但它是一句**前提**，不是一句结论。
#############################################################################

import os
import re
import sys
import collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

DEFAULT_LOG = ".cache/_test_warn_all.log"
EXEMPT = "tools/runtime-warn-exempt.txt"

# ── 形态表 ────────────────────────────────────────────────────────────────
# 认不出的行**不放过** —— 它会被判成 `UNCLASSIFIED` 并计入"新增"。
# 理由：本项目最忌讳的是"抽不到就沉默"（变异残留审计器那条教训：
# **"抽不到就报出来"这条兜底才是承重件**）。多出来的红是**可处置**的
# ——要么把形状加进来（并说明它为什么该被看），要么给一条豁免（并写明理由）。
KINDS = [
    ("ASSIGN",   re.compile(r"Unable to assign\b")),
    ("NOEXIST",  re.compile(r"does not exist\b"
                            r"|Cannot assign to non-existent property"
                            r"|Non-existent attached object"
                            r"|Cannot assign to read-only")),
    ("ANCHORS",  re.compile(r"Detected anchors on an item that is managed by a layout")),
    ("BINDLOOP", re.compile(r"Binding loop detected")),
    ("DEPREC",   re.compile(r"Injection of parameters into signal handlers is deprecated")),
    ("NOVER",    re.compile(r"is not available in ")),
    ("EXC",      re.compile(r"ReferenceError|TypeError|is not defined")),
    # `QQmlApplicationEngine failed to load component` 本来会被判成
    # UNCLASSIFIED（也一样是红，判据不变）—— 给它一个名字只是为了报告好读：
    # 看到 "LOAD" 就知道是"文件没加载起来"，而不是"出现了一种新形状"。
    ("LOAD",     re.compile(r"QQmlApplicationEngine failed to load component")),
]

# 位置前缀。实测有两种：
#   `…QSkinDrawer.qml:77:9: 消息`   （常规）
#   `…QSkinDrawer.qml:77: TypeError…`（类型错误——**只有一个行号**，没有列）
# ⚠ 用**命名组**，不要用 group(3)。这两种形状的组数不一样（3 个 vs 2 个），
#   写位置下标必然有一边取错 —— 首版就是这么把"列号"当成"消息"的，
#   于是所有消息都成了一串数字，族的汇总整段失真。
LOC2 = re.compile(r"^(?:file:///)?(?P<path>.*?\.qml):(?P<line>\d+):(?P<col>\d+):\s?(?P<msg>.*)$")
LOC1 = re.compile(r"^(?:file:///)?(?P<path>.*?\.qml):(?P<line>\d+):\s?(?P<msg>.*)$")

# 累积日志里我们自己打的记号
RE_FILE = re.compile(r"^@@@FILE\s+(.+?)\s*$")
RE_EXIT = re.compile(r"^@@@EXIT\s+(\d+)\s*$")
RE_RUN  = re.compile(r"^@@@RUN\s+(.*)$")


def norm_origin(path):
    """把绝对路径归一成**跟着仓库走的相对键**。

    为什么要归一：警告里的路径指向 `.cache/qmlimports/QSkin/…` **副本**，
    而不是 `src/`。直接拿它当键的话，本机路径一换（用户名、盘符）全对不上，
    而且键里塞着一串绝对路径没法读。
    """
    p = path.replace("\\", "/")
    for prefix in (".cache/qmlimports/", "src/"):
        i = p.find(prefix)
        if i >= 0:
            return p[i + len(prefix):]
    i = p.find("/tests/")
    if i >= 0:
        return "tests/" + p[i + len("/tests/"):]
    return "(未标位置)"


def classify(line):
    for kind, rx in KINDS:
        if rx.search(line):
            return kind
    return None


def parse_log(text):
    """把累积日志切成 per-file 的块。

    ⚠ 段的**顺序**是 shot 侧写死的：@@@FILE → @@@EXIT → 正文 → @@@END。
       本函数按这个顺序解析。M31 首跑我按"FILE → 正文 → EXIT"解析过，
       于是**每一块都被判成空**、报告"48 个文件零输出" —— 与 M27 量到的
       675 行完全对不上。教训：解析器要按**实际写入顺序**写，不是按记忆。
    """
    blocks = []
    run = None
    name = None
    code = None
    body = []
    for raw in text.splitlines():
        m = RE_RUN.match(raw)
        if m:
            run = m.group(1)
            continue
        m = RE_FILE.match(raw)
        if m:
            name, code, body = m.group(1), None, []
            continue
        m = RE_EXIT.match(raw)
        if m:
            code = int(m.group(1))
            continue
        if raw.strip() == "@@@END":
            if name is not None:
                blocks.append((name, code, body))
            name = None
            continue
        if name is not None:
            body.append(raw.rstrip())
    return run, blocks


def collect(blocks):
    """→ (hits, own_lines, scanned)

    hits       : {(kind, origin, message): [(测试文件, 行号, 原文)]}
    own_lines  : [(测试文件, 原文)]  —— `qml: ` 开头的自家程序输出（不判）
    scanned    : 读到的测试文件名（"面"有多大）
    """
    hits = collections.defaultdict(list)
    own = []
    scanned = []
    for name, code, body in blocks:
        scanned.append(name)
        last_key = None
        for raw in body:
            ln = raw.strip()
            if not ln:
                continue
            if ln.startswith("qml: "):
                own.append((name, ln))
                continue
            if ln.startswith("qml:"):
                own.append((name, ln))
                continue
            m = LOC2.match(ln) or LOC1.match(ln)
            if m:
                path = m.group("path")
                lineno = int(m.group("line"))
                msg = m.group("msg").strip()

                # 续行：引擎把一条警告的消息折成两行时（实测 Binding loop），
                # 第二行只剩 `…:行:列`，没有消息 —— 解析出来是空串或**一个纯
                # 数字的列号**。把它并进上一条，不单独计数。
                # ⚠ 只并文件、**不并行号**：行号会漂，键里带行号就等于把漂移
                #   引回来（这条键存在的全部理由就是不带行号）。
                if not msg or msg.isdigit():
                    if last_key is not None:
                        k = (last_key[0], last_key[1],
                             last_key[2] + " ⏎ " + norm_origin(path))
                        hits[k].extend(hits.pop(last_key, []))
                        last_key = k
                    else:
                        # 没有上一条可并 —— 报出来，别悄悄丢掉
                        key = ("UNCLASSIFIED", norm_origin(path), ln)
                        hits[key].append((name, lineno, ln))
                        last_key = key
                    continue

                kind = classify(msg) or "UNCLASSIFIED"
                key = (kind, norm_origin(path), msg)
                hits[key].append((name, lineno, ln))
                last_key = key
            else:
                kind = classify(ln) or "UNCLASSIFIED"
                key = (kind, "(未标位置)", ln)
                hits[key].append((name, None, ln))
                last_key = key
    return hits, own, scanned


def load_exempt(path):
    out = []
    if not os.path.isfile(path):
        return out
    with open(path, "r", encoding="utf-8", newline="") as f:
        for i, line in enumerate(f, 1):
            s = line.rstrip("\r\n")
            if not s.strip() or s.lstrip().startswith("#"):
                continue
            parts = s.split("\t")
            if len(parts) != 3:
                print("!! %s:%d 格式不对（要 形态<TAB>出处<TAB>消息 三格）：%s"
                      % (path, i, s[:70]))
                sys.exit(9)
            out.append((parts[0], parts[1], parts[2]))
    return out


def write_exempt(path, keys):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("# 运行期警告 · 存量豁免名单（**自动生成的初始版本，理由要人补**）\n")
        f.write("# 键 = 形态<TAB>出处<TAB>消息；**不含行号**（行号会漂）。\n")
        f.write("# ⚠ 这是**迁移工具**的产物，不是收口工具：生成它会一次性把所有\n")
        f.write("#   现存警告变成绿。逐条补上理由，修掉一族就删掉那一族。\n")
        for k in sorted(keys):
            f.write("%s\t%s\t%s\n" % k)


def main(argv):
    show_all = "--list" in argv
    do_write = "--write-exempt" in argv
    # `--exempt=<路径>`：只给**证伪器**用（拿变过的名单跑对照实验，
    # 不去动仓库里那份真名单）。默认就是仓库里那份。
    exempt_path = EXEMPT
    for a in argv:
        if a.startswith("--exempt="):
            exempt_path = a.split("=", 1)[1]
    rest = [a for a in argv if not a.startswith("--")]
    log = rest[0] if rest else DEFAULT_LOG

    if not os.path.isfile(log):
        print("!! 找不到累积日志 %s" % log)
        print("   （它不是自动生成的 —— 先跑一次 ./tools/test.sh；")
        print("     第 3 节会把每个冒烟文件的 stderr 累积进去。）")
        return 9

    with open(log, "rb") as f:
        text = f.read().decode("utf-8", "replace").replace("\r\n", "\n").replace("\x00", "")

    run, blocks = parse_log(text)
    if not blocks:
        print("!! 累积日志里**一个文件都没读到**（@@@FILE 段为 0）。")
        print("   这是工装坏了，不是「没有警告」。**检查了 0 条一律算失败。**")
        return 9

    hits, own, scanned = collect(blocks)

    # ── 解析器自检：消息不可能是一串纯数字 ──────────────────────────────
    # 这不是"防御性编程"，是一条**针对已知 bug 类的断言**：首版把 LOC2 的
    # group(3)（列号）当成了消息，于是所有消息都成了一串数字、族的汇总
    # 整段失真，而报告看起来照样"有信息量"。取错位置字段是解析器最常见的
    # 坏法，所以在这里钉死：出现纯数字消息 = 工装坏了，不是代码错了。
    bad = [k for k in hits if not re.search(r"[A-Za-z]", k[2])]
    if bad:
        print("!! 解析器自检失败：有 %d 条键的'消息'里一个字母都没有。" % len(bad))
        print("   这几乎一定是**位置字段取错了**（把行号/列号当成了消息）。")
        for k in sorted(bad)[:5]:
            print("      %s | %s | %r" % (k[0], k[1], k[2]))
        return 9

    exempt = load_exempt(exempt_path)
    exempt_set = set(exempt)

    if do_write:
        write_exempt(exempt_path, hits.keys())
        print("已写入 %s：%d 条" % (exempt_path, len(hits)))
        return 0

    total = sum(len(v) for v in hits.values())
    print("运行期警告核验")
    if run:
        print("  累积日志档：%s" % run)
    print("  面        ：%d 个冒烟文件" % len(scanned))
    print("  引擎诊断  ：%d 行 · 归入 %d 条键" % (total, len(hits)))
    print("  自家输出  ：%d 行（`qml: ` 前缀 —— 含负向测试刻意打的日志，不判；"
          "⚠ warn/error 与它不可区分，见文件头" % len(own))
    print("  豁免名单  ：%d 条" % len(exempt_set))

    # ── 按族汇总（族 = 形态 + 消息；出处各自一行） ──
    fam = collections.defaultdict(lambda: [0, set()])
    for (kind, origin, msg), occ in hits.items():
        fam[(kind, msg)][0] += len(occ)
        fam[(kind, msg)][1].add(origin)
    print("")
    print("  ── 按族（形态 + 消息）──")
    for (kind, msg), (n, origins) in sorted(fam.items(), key=lambda kv: -kv[1][0]):
        print("    %-10s %5d 行 · %2d 处 · %s" % (kind, n, len(origins), msg[:78]))

    new = [(k, hits[k]) for k in sorted(hits) if k not in exempt_set]
    stale = [k for k in sorted(exempt_set) if k not in hits]

    if show_all:
        print("")
        print("  ── 全部（✓ = 已豁免）──")
        for k in sorted(hits):
            mark = "✓" if k in exempt_set else "✗"
            print("    %s %-9s %-52s %s" % (mark, k[0], k[1], k[2][:70]))

    if new:
        print("")
        print("  ✗ 未豁免的运行期警告（%d 条键）：" % len(new))
        for k, occ in new:
            print("      %-9s %-52s %s" % (k[0], k[1], k[2][:64]))
            print("              例：%s:%s" % (occ[0][0], occ[0][1]))

    if stale:
        print("")
        print("  ✗ 过期豁免（%d 条 —— 一条警告都没命中）：" % len(stale))
        for k in stale:
            print("      %-9s %-52s %s" % (k[0], k[1], k[2][:64]))
        print("    这一条要么已经不存在了（修好了 / 触发它的冒烟改了），")
        print("    要么键写错了。核实后**删掉那一行**，或把警告找回来。")

    print("")
    if not new and not stale:
        print("OK  运行期警告：%d 行全部在豁免名单里，名单无过期条目（位掩码 0x00）" % total)
        return 0
    code = (1 if new else 0) | (2 if stale else 0)
    print("NG  未豁免 %d 条键 · 过期豁免 %d 条键（位掩码 0x%02x）" % (len(new), len(stale), code))
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
