#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""QSkin · 发布面读数对账门 —— 让 README / COVERAGE / GITHUB 里的数字**不可能漂**。

## 为什么要有这道门

2026-10-03 手工核对五份发布面文档时，实际抓到三处不一致：

  · README 同一份文件里「11 道脚本门」与「9 道脚本门」并存（一处漏改）
  · 架构图写「每套主题 = 1 份 token + **5 组**插槽实现」，
    而实测四家是 **8 / 10 / 8 / 11** 个插槽文件 —— 架构图是全仓最显眼的位置
  · 新增的 `docs/GITHUB.md` **不在发布面泄露门的扫描面里**，
    于是它成了一份没人管的发布面文档

三处的共同形状：**数字是手写的**。手写的数字必然漂，而且漂了没人喊。

## 这道门做什么

**从源码复算真值 → 在发布面文档里找对应字面量 → 对不上就红。**

不是检查「文档写得对不对」（那是人读的），而是检查「**文档里的数字
还能跟得上源码**」。加了新控件 / 换了主题 / 门增减，这条门会自己喊。

## 为什么不能靠"文档里写复算命令"就够

COVERAGE.md 里已经写了 `ls src/contracts/QSkin*.qml | wc -l` 这类命令，
但**命令在那儿，跑的是人**。发布面文档有 5 份、读数有 8 类，
靠人记得复算 = 迟早漂。这道门把它变成自动的。

判据（每条都必须**有实测**、不能只查"有没有"）：

  1. 契约文件数   = `src/contracts/QSkin*.qml` 实际个数
  2. 控件数       = COVERAGE.md 组件表里 ✅ 的行数（用 COVERAGE 自带口径）
  3. qmllint 扫描面 = `src` + `examples` + `tests` 下的 .qml 总数
  4. 主题数       = `src/themes/*/` 目录数
  5. 插槽文件数   = 四家主题 slots/*.qml 的**最小~最大**区间
  6. 脚本门数     = `tools/lint.sh` 里 `*_SCAN=` 赋值的门数
                   （⚠ **不能**用 `grep -oE "tools/check-.*"` 数 ——
                   那会把 .sh 包装器与它 exec 的 .py 各算一次，还把
                   `gen-contract-manifest.py` / `qml-downgrade.py` 这类
                   **被门调用的工具**也算进去，实测 11 被数成 18）
  7. 类型 / 单例数 = 契约清单生成物的实际条数
  8. 发布面文档清单 = 实际随仓库发布的 .md 集合（判据 4 的靶子要对得上）

## 它的边界（**别指望它管它管不了的**）

判据 9 只抓「**手滑写错一个数字**」（真值 ±1，且数字紧邻量词）。
它**抓不到**的两类：

  1. **同一读数在文档里同时存在真值与错值** —— 例如一处已改成 12、另一处
     还留着 11。实测过：把 README 的 `11 道脚本门禁` 改成 `12 道`，门是绿的
     （因为别处还有真值 11，判据 1 照样过）。这类要靠人扫。
  2. **差 ≥2 的错**（92 写成 90）。射程只取 ±1 是权衡：再宽就会被
     「契约第 3 条」「前 5 条断言」这类无关数字淹成假红。

所以它是**防漂移的护栏**，不是文档正确性的证明。文档的真值仍然要靠
`COVERAGE.md` 里那些**可复算的命令** + 偶尔人读一遍。

## 怎么证伪这道门

  1. 把 README 里的 `92` 改成 `93`      → 判据 1 必须变红
  2. 删掉 `src/contracts/` 下一个 .qml   → 判据 1 必须变红
  3. 把 `8~11` 改成 `5~11`             → 判据 5 必须变红
  4. 新建一份 .md 但不登记进
     `check-doc-leak.py` 的 DEFAULT_DOCS → 判据 8 必须变红

用法：
    ./tools/check-doc-readout.sh            # 一般不用直接调（lint.sh 第 16 段带它）

    python tools/check-doc-readout.py --list   # 只打印真值与各文档命中情况
"""

import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 会随发行版发布的文档。⚠ 必须与 tools/check-doc-leak.py 的 DEFAULT_DOCS
#   以及 .gitignore 三方一致 —— 判据 8 专门盯这件事。
PUBLISHED_DOCS = ["README.md", "COVERAGE.md", "CHANGELOG.md",
                  os.path.join("docs", "PITFALLS.md"),
                  os.path.join("docs", "GITHUB.md")]

# 各读数：(真值, 必须在文档里出现的字面量正则, 该数字出现在哪些文档里)
# 用正则而不是 `str(真值)`，是为了允许文档写成 `**92** 个` / `92 个` /
# `#92` 这类带格式的写法 —— 我们要卡的是**数值**，不是排版。
def sh(*a):
    # ⚠ `errors="replace"` 不能省：Windows 上 `awk` / `git` 的输出可能是
    #   本地编码（GBK），strict 解码会直接抛 UnicodeDecodeError，
    #   而**异常不是判据** —— 门必须在任何编码下都给出读数。
    return subprocess.run(a, capture_output=True, text=True,
                          cwd=ROOT, errors="replace").stdout


def truth():
    """→ {读数名: (真值字符串, 匹配用的正则片段)}"""
    out = {}
    n_contract = len(glob.glob(os.path.join(ROOT, "src", "contracts", "QSkin*.qml")))
    out["契约文件数"] = (str(n_contract), r"\b%d\b" % n_contract)

    # 组件表 ✅ 行数 —— **必须用 COVERAGE.md 自带的 awk 口径**。
    # 自创口径（如"取表格首个状态格"）会得出不同数字，然后得出假的
    # "文档过期"结论 —— 那比不报错更坏。
    n_ok = 0
    r = subprocess.run(
        ["awk", "-F|",
         "NF>=7 && $2 !~ /^[[:space:]]*[-:]+[[:space:]]*$/ && $2 !~ /组件/ {"
         " q=$6; gsub(/^[[:space:]]+|[[:space:]]+$/,\"\",q);"
         " if (q ~ /^✅/) ok++ } END { print ok+0 }",
         "COVERAGE.md"],
        capture_output=True, text=True, cwd=ROOT, errors="replace")
    try:
        n_ok = int(r.stdout.strip() or 0)
    except ValueError:
        n_ok = 0
    out["组件表 ✅ 行数"] = (str(n_ok), r"\b%d\b" % n_ok)

    qml = 0
    for d in ("src", "examples", "tests"):
        qml += len(glob.glob(os.path.join(ROOT, d, "**", "*.qml"), recursive=True))
    out["qmllint 扫描面"] = (str(qml), r"\b%d\b" % qml)

    themes = [d for d in os.listdir(os.path.join(ROOT, "src", "themes"))
              if os.path.isdir(os.path.join(ROOT, "src", "themes", d))]
    out["主题数"] = (str(len(themes)), r"\b%d\b" % len(themes))

    slots = [len(glob.glob(os.path.join(ROOT, "src", "themes", t, "slots", "*.qml")))
             for t in themes] or [0]
    rng = "%d~%d" % (min(slots), max(slots))
    out["插槽/主题(区间)"] = (rng, re.escape(rng))

    # ⚠ 门数**不能**用 `grep -oE "tools/check-.*"` 数（会把 .sh 包装器与
    # 它 exec 的 .py 各算一次，还会把被门调用的 gen-*-manifest.py /
    # qml-downgrade.py 也算进去 —— 实测 11 被数成 18）。
    # 口径 = lint.sh 里所有 `*SCAN=` 赋值的门。
    # ⚠ 正则必须是 `\w*SCAN=` 而不是 `\w+_SCAN=` —— 字符图标那道门
    # 的变量就叫 `SCAN`（没有前缀下划线），写成 `_+` 会漏掉它 ⇒ 10 ≠ 11。
    #   这是本门自己第一版踩的：**口径写窄了会得出假的"文档过期"结论**，
    #   比不报错更坏（项目规矩：复算一律用文档自带的命令 / 口径）。
    lint = sh("cat", os.path.join(ROOT, "tools", "lint.sh"))
    n_gate = len(re.findall(r"^\w*SCAN=", lint, re.M))
    out["lint 脚本门数"] = (str(n_gate), r"\b%d\b" % n_gate)

    # 类型 / 单例：**从契约清单生成物里读它自己写的读数**
    # （`tests/ContractManifest.js` 头部有「普通类型 N 个，单例 M 个」——
    #   那是 `tools/gen-contract-manifest.py` 生成的，与门禁判据 14 同源。
    #   不要在这里另立口径去数 qmldir：那是"量法与被测量共享假设"。）
    mf_path = os.path.join(ROOT, "tests", "ContractManifest.js")
    mf = ""
    if os.path.exists(mf_path):
        mf = open(mf_path, encoding="utf-8", errors="replace").read()
    m_t = re.search(r"普通类型\s*(\d+)\s*个", mf)
    m_s = re.search(r"单例\s*(\d+)\s*个", mf)
    if m_t:
        out["qmldir 类型数"] = (m_t.group(1), r"\b%s\b" % m_t.group(1))
    if m_s:
        out["单例数"] = (m_s.group(1), r"\b%s\b" % m_s.group(1))
    # 「可裸实例化的公开类型」= 类型总数 − 内部件。**必须单独立一个读数**：
    # 判据 10 会按「同量级」逐处核对，105 与 103 只差 2 —— 不分开就会被
    # 判成「一处对一处错」（实测）。两个数各管各的，才不会互相污染。
    n_internal = len(re.findall(r"^\s*\(\s*\"QSkin\.", mf, re.M))  # 占位，见下
    m_ex = re.search(r"内部(?:件|插槽)[^\n]*?(\d+)\s*个", mf)
    n_int = int(m_ex.group(1)) if m_ex else 2      # 已知：TimeCell / FloatPlate
    if m_t:
        out["可裸实例化类型数"] = (str(int(m_t.group(1)) - n_int),
                                  r"\b%d\b" % (int(m_t.group(1)) - n_int))
    return out


def main():
    ap = __import__("argparse").ArgumentParser()
    ap.add_argument("--list", action="store_true", help="只打印，不判")
    args = ap.parse_args()

    t = truth()
    print("== 发布面读数真值（从源码复算）")
    for k, (v, _p) in t.items():
        print("   %-20s %s" % (k, v))

    docs = {}
    for d in PUBLISHED_DOCS:
        p = os.path.join(ROOT, d)
        docs[d] = open(p, encoding="utf-8", errors="replace").read() \
            if os.path.exists(p) else None

    # ⚠ 逐处核对（判据 9 / 10）只在「**当前状态陈述**」的文档里做。
    #   CHANGELOG 与 PITFALLS 记的是**当时**的读数（"i18n 门禁（第十二道）"
    #   "lint 15 段"），那些不是错值 —— 拿今天的标准去 judge 昨天的记录，
    #   等于**逼着人改历史**。它们只在判据 1（该数出现过）里参与。
    #
    #   这是本门第二版才想清楚的：第一版把历史文档一起逐处核对，
    #   报出「CHANGELOG 里有 4 处同量级读数、只有 2 处对：10, 11, 13」——
    #   那三条**全都是对的**（M33 时的门数 / 警告条数）。
    HISTORY = {"CHANGELOG.md", "PITFALLS.md"}

    def is_history(d):
        """路径分隔符归一化后再比 —— Windows 下 `docs\\PITFALLS.md` ≠
        `docs/PITFALLS.md`，不归一化就会把历史文档漏进逐处核对。"""
        return os.path.basename(d.replace("\\", "/")) in HISTORY

    print("\n== 各读数在哪些发布面文档里出现")
    miss = []
    bad = []          # 全部红项的汇总（判据 1~4 缺数 + 判据 9 近似值）
    for k, (v, pat) in t.items():
        rx = re.compile(pat)
        hit = [d for d, c in docs.items() if c and rx.search(c)]
        print("   %-20s %-10s → %s" % (k, v, ", ".join(hit) or "**一处都没出现**"))
        if not hit:
            miss.append((k, v, "发布面里找不到这个数（要么文档漏了，要么数错了）"))

    # ── 判据 9：文档里**不许出现近似值** ─────────────────────────────────
    #
    # ⚠ 这一条是本门第一版**漏掉的那一半**，证伪时才发现：只验「文档里有
    #   真值」的话，把 `92` 改成 `93` 门照样绿 —— 因为 92 还在别处出现着，
    #   而 93 这个**错数**根本没人检查。
    #
    #   所以要反过来做：对每个读数，取它真值附近的整数，在该读数**应该出现
    #   的文档**里找。有 ⇒ 有人写了个错的 ⇒ 红。
    #
    #   射程只取 ±2（不是所有邻近数）：读数像「4 家主题」时 ±2 会误伤
    #   「105 个类型」的 102/103/104 —— 所以**逐读数声明射程**，
    #   并且默认 ±1，宁可漏也不误伤（假阳性 = 下次没人信它）。
    print("\n== 判据 9 · 发布面里不许出现「近似值」（±1，逐读数声明射程）")
    # 读数 → (允许的射程, 该读数理应出现的文档)
    # 读数 → (允许的射程, 该读数理应出现的文档, 要**排除**的邻居读数)
    # 排除邻居是必需的：`105 个类型` 与 `103 个公开类型` 只差 2，
    # 而 103 自己也是一条合法读数 —— 不排除就会互相判成"近似值"。
    # 邻居读数：值与本读数**同量级**且语义不同，不当错值。
    # ⚠ 这张表是**逐对声明**的，不是自动算的 —— 自动算（"值差 ≤2 就当邻居"）
    #   会漏：`8~11`（插槽区间）的**上界 11** 与 `11`（lint 门数）撞车，
    #   实测门把架构图里的「8~11 个」报成「README 里写着近似值 11」。
    #   ⇒ 区间读数的**上下界都要登记**成邻居。
    def _bounds(s):
        m = re.fullmatch(r"(\d+)~(\d+)", str(s))
        return [m.group(1), m.group(2)] if m else [str(s)]
    def _neigh(name):
        """与本读数**同量级**（差 ≤ 2）且语义不同的邻居值。

        为什么必须显式挑「同量级」而不是全列：全列的话每条读数都把所有
        别的读数当邻居，判据 9 永远扫不出东西 —— 那等于把门关掉。
        """
        base = t[name][0]
        try:
            b0 = int(base)
        except ValueError:
            b0 = int(re.fullmatch(r"(\d+)~(\d+)", base).group(1))
        out = []
        for nb in t:
            if nb == name:
                continue
            for b in _bounds(t[nb][0]):
                if b == base:
                    continue
                try:
                    if abs(int(b) - b0) <= 2:
                        out.append(b)
                except ValueError:
                    pass
        return out
    EXCLUDE = {k: _neigh(k) for k in t}
    RANGE = {
        "契约文件数":     (1, ["README.md", "COVERAGE.md", "docs/GITHUB.md"]),
        "组件表 ✅ 行数": (1, ["README.md", "COVERAGE.md", "docs/GITHUB.md"]),
        "qmllint 扫描面": (1, ["README.md", "docs/GITHUB.md"]),
        "主题数":         (1, ["README.md", "COVERAGE.md", "docs/GITHUB.md"]),
        "插槽/主题(区间)": (1, ["README.md", "docs/GITHUB.md"]),
        "lint 脚本门数":  (1, ["README.md", "docs/GITHUB.md"]),
        "qmldir 类型数":  (1, ["README.md", "docs/GITHUB.md"]),
        "可裸实例化类型数": (1, ["README.md", "docs/GITHUB.md"]),
        "单例数":         (1, ["README.md", "docs/GITHUB.md"]),
    }
    near = []
    # ── 判据 9 / 10 的适用范围：**逐读数显式声明**，不用「数值大小」猜 ──────
    #
    # ⚠ 第一版用 `if base <= 20: continue`（小数字豁免）—— 结果门数 11
    #   被跳过，证伪时「11 道 → 12 道」**咬不住**。
    #   而「主题数 = 4」逐处核对又必然误伤（「契约第 3 条」「前 5 条断言」）。
    #   两者不能用同一个尺子量 —— 所以改成**逐读数声明**：
    #     · SMALL = 文档里大量存在同量级无关数字（小计数）→ 只做判据 1
    #     · 其余（大计数 + 门数这类虽有小数值但语义唯一的）→ 判据 9 + 10 都做
    #   判据 1 对所有读数都生效，所以 SMALL 那一组仍有护栏。
    SMALL = {"主题数", "单例数", "插槽/主题(区间)"}
    for k, (v, _p) in sorted(t.items()):
        if k not in RANGE:
            continue
        span, where = RANGE[k]
        try:
            base = int(v)
        except ValueError:
            continue          # 区间型（8~11）不做近值检查，见下
        if k in SMALL:
            continue          # 见 SMALL 的说明：这类只做判据 1
        neigh_vals = set(EXCLUDE.get(k, []))   # 现在装的是**值**，不是读数名
        for off in range(-span, span + 1):
            if off == 0:
                continue
            wrong = str(base + off)
            if wrong in neigh_vals:
                continue      # 邻居读数是合法的，不当错值
            # 只在这读数**理应出现**的文档里找，且要求"附近有上下文词"
            #  —— 否则「4 家主题」会因为文档里别处的 3 而误报。
            for d in where:
                if is_history(d):
                    continue      # 历史文档不参与逐处核对（见 HISTORY 说明）
                c = docs.get(d)
                if not c:
                    continue
                for m in re.finditer(r"(?<![\d.])%s(?![\d])" % wrong, c):
                    # ⚠ 上下文窗口必须**紧邻**计数词，不能是"句子里含这个词"。
                    #   第一版用 `re.search(r"个|道|家|...", 整段)` 做过滤，
                    #   结果「Qt **5**.15」「**18** 条里 qskin_en」这类无关数字
                    #   全部被扫进来 —— 门当场报 30+ 条假红。
                    #   假阳性 = 下次没人信它，所以窗口收紧到 12 字符。
                    # ⚠ 数字与量词之间允许夹 **markdown 强调标记** ——
                    #   `**261** 个文件` 里 261 后面是 `** 个文件`，而第一版
                    #   的 UNIT 要求紧邻 ⇒ 三个判据全部**咬不住**（证伪时才发现）。
                    #   量词表也要全：个/道/家/套/种/份/行/条/文件/类/项。
                    tail = c[m.end():m.end() + 16]
                    head = c[max(0, m.start() - 16):m.start()]
                    GAP = r"[\s*>`_+、,，(（]*"
                    UNIT = (GAP + r"(?:个|道|家|套|种|份|行|条|文件|类|项)"
                            + GAP + r"(?:文件|控件|组件|类型|单例|断言|门|主题|插槽)?")
                    if not (re.match(UNIT, tail) or re.search(UNIT + r"$", head)):
                        continue
                    near.append((k, v, wrong, d,
                                 c[max(0, m.start() - 40):m.end() + 30]
                                 .replace("\n", " ").strip()[:78]))
    if near:
        for k, v, wrong, d, seg in near:
            print("   ✗ %s 真值 %s，但 %s 里写着 **%s**" % (k, v, d, wrong))
            print("       %s" % seg)
    else:
        print("   ✓ 未发现近似值")

    # ── 判据 10：同一读数在**一份文档里出现多次**时，每一处都要是对的 ──────
    #
    # ⚠ 判据 1 只问「这个数在文档里**至少出现过一次**吗」，判据 9 只问
    #   「有没有**近似值**」。于是漏掉一整类：**真值与错值并存**。
    #   实测：把 README 的 `11 道脚本门禁` 改成 `12 道`，别处还留着 11 ⇒
    #   判据 1 过（11 在）、判据 9 不响（12 差 1 但那处 12 后面没跟量词
    #   词组）⇒ **门是绿的**。这正是「一处漏改」最常见的形状。
    #
    # 做法：对每份文档，找出**所有**「数字 + 量词」组合里与某读数同量级的，
    # 逐处报出总数与真值处数；两者不等就红。
    print("\n== 判据 10 · 同一读数在一份文档里出现多次时，每一处都要对")
    multi = []
    for d, c in sorted(docs.items()):
        if not c:
            continue
        if is_history(d):
            continue          # 历史文档不参与逐处核对（见 HISTORY 说明）
        for k, (v, _p) in sorted(t.items()):
            # 区间型读数（如插槽数 `8~11`）也要逐处核对 —— 用**字面量**比，
            # 不能 int(v)（那会 ValueError 直接跳过，实测「8~11 改成 5~11」
            # 门是绿的）。
            m_rng = re.fullmatch(r"(\d+)~(\d+)", str(v))
            if m_rng:
                # ⚠ 区间型读数**只做「字面量必须出现」**（判据 1 已在做），
                #   不做逐处核对 —— 区间里的每个数字在文档里都有合法的分项
                #   用途（COVERAGE 里「arco 有 8 个插槽」就是其中之一），
                #   逐处核对必然误伤。区间被改错（8~11 → 5~11）时，
                #   区间下限 5 会落进别的读数的射程，由那些读数兜住。
                continue
            try:
                base = int(v)
            except ValueError:
                continue
            if k in SMALL:
                continue          # 与判据 9 同理
            # 该读数在这份文档里所有「数字+量词」的出现处。
            # ⚠ 量词窗口要够宽：`11 道脚本门禁`（无加粗）与 `**11 道**`（有加粗）
            #   两种写法都要收进来 —— 窗口太窄会只抓到其中一种，于是"改了
            #   一处、漏了另一处"这种最常见的漏改形状就抓不住（实测）。
            spots = []
            for m in re.finditer(r"(?<![\d.])(\d{1,4})(?![\d])", c):
                tail = c[m.end():m.end() + 20]
                if not re.match(r"[\s*>`_+、,，(（]*(?:个|道|家|套|种|份|行|条|文件|类|项)", tail):
                    continue
                spots.append(m.group(1))
            # 只看与真值**同量级**的（±2，避免把 105 和 8 混一起），
            # 并**排除邻居读数**（105 与 103 各是一条合法读数，不是错值）
            neigh_vals = set(EXCLUDE.get(k, []))   # 同上：装的是值
            cand = [s for s in spots
                    if abs(int(s) - base) <= 2 and s not in neigh_vals]
            if not cand:
                continue
            right = sum(1 for s in cand if s == str(base))
            if right != len(cand):
                multi.append((k, v, d, len(cand), right,
                              sorted(set(cand))))
    if multi:
        for k, v, d, n, r, seen in multi:
            print("   ✗ %s 真值 %s，但 %s 里有 %d 处同量级读数、只有 %d 处对：%s"
                  % (k, v, d, n, r, ", ".join(seen)))
            bad.append((k, v, "%s 里 %d/%d 处对（见到 %s）"
                        % (d, r, n, ", ".join(seen))))
    else:
        print("   ✓ 每处都对")

    # 判据 8：发布面文档清单与实际入库的 .md 是否一致
    #
    # ⚠ 路径分隔符必须**归一化成 `/`**：`git ls-files` 永远输出 `/`，
    #   而 `os.path.join("docs", "GITHUB.md")` 在 Windows 上是 `docs\GITHUB.md`
    #   —— 两者直接比会得出"入库了但没登记"的**假红**。本门第一版就栽在这。
    print("\n== 判据 8 · 发布面文档清单 vs 实际入库")
    def norm(p):
        return p.replace("\\", "/")
    tracked_md = set(norm(p) for p in sh("git", "ls-files", "*.md").split("\n")) - {""}
    declared = set(norm(p) for p in PUBLISHED_DOCS) | {"ROADMAP.md", "docs/PROGRESS.md"}
    only_repo = sorted(tracked_md - declared)
    only_decl = sorted(declared - tracked_md - {"ROADMAP.md", "docs/PROGRESS.md"})
    if only_repo:
        print("   ✗ 入库了但没登记为发布面文档：%s" % ", ".join(only_repo))
    if only_decl:
        print("   · 登记了但不在库里（应被 .gitignore 排除）：%s" % ", ".join(only_decl))
    if not only_repo and not only_decl:
        print("   ✓ 一致（发布面 %d 份 + 开发面 2 份被排除）"
              % len(PUBLISHED_DOCS))

    bad.extend(miss)
    for k, v, wrong, d, seg in near:
        bad.append((k, v, "%s 里写着近似值 %s" % (d, wrong)))
    if only_repo:
        bad.append(("发布面文档清单", "%d 份" % len(PUBLISHED_DOCS), "有入库文档未登记"))
    if args.list:
        return 1 if bad else 0

    print()
    if bad:
        print("✗ 发布面读数对账：%d 处对不上" % len(bad))
        for k, v, why in bad:
            print("   · %s（真值 %s）：%s" % (k, v, why))
        print("   修法：改文档去迁就源码，或改源码后重跑 —— 别改门。")
        return 1
    print("✓ 发布面读数对账：%d 项全部一致" % len(t))
    return 0


if __name__ == "__main__":
    sys.exit(main())
