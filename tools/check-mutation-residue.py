#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""QSkin · 变异残留审计：`src/` 里有没有**没被复原回去**的变异？

── 为什么必须有这件东西 ──────────────────────────────────────────────
变异脚本的复原逻辑都在 `try/finally` 里，正常结束一定收干净。但
**`finally` 挡不住硬杀**：进程被 SIGKILL / 安全删除守卫 / 外层超时带走时，
它一行都不执行 —— 于是"改坏的那一行"就留在源码里了。

实测（M21 收口当天）：`mutate_m20_px.py` 的一次运行在中途被杀，把
`src/contracts/QSkinLabel.qml` 的

        visible: root.required        →        visible: true

留在了源码里。症状是本项目最熟悉的那个形状：**`required` 属性读出来
完全正确，而屏幕上每个标签都带着一颗红星**（属性对、界面全错）。
更糟的是它**当时没人发现**：

  · `lint.sh` 看不见 —— `visible: true` 是完全合法的 QML；
  · 唯一能看见它的 `smoke_m20.qml [4]` 确实红了 —— 但**上一次跑 test.sh
    是在变异之前**（17:13），之后没人再跑过（17:14 变异，17:15 留下）。

也就是说：**"跑过门禁"这件事有时间窗口，而变异就发生在窗口之后。**
处置不是"以后记得再跑一次"（记不住的），而是**直接问源码要答案**。

── 为什么不用 exec 加载变异脚本（重要）────────────────────────────────
`.cache/_preflight_m21.py` 靠 `src.split("def find_qml()")[0]` 截断主体，
对 `mutate_m1x.py` / `*_theme.py` 有效 —— 它们有 `find_qml()`。
但 **`mutate_m18_px.py` / `mutate_m20_px.py` 这类没有 `find_qml`，而
`mutate_m20_px.py` 连 `if __name__ == "__main__"` 守卫都没有**（主体直接
写在模块级）。对它们 exec 一次 = **真的跑一轮变异**。
所以这里改用 `ast` + 一个小求值器（`ev`）：只认常量、名字、元组、列表、
字典、字符串拼接，**不执行任何代码**。

── 三种书写形状都要认（实测都出现过）──────────────────────────────────
    ① `edits=[("src/…", 原, 改), …]`              （m20 / m20_px / m21）
    ② `dict(path="src/…", old=…, new=…)`           （m18_px / m19_px / m20_gate）
    ③ `edits=[(SMOKE,) + INJECT]`                  （m21_gate：3 元组由拼接得到）
    ④ 路径常量写成 `os.path.join("src", "contracts", "X.qml")`
       （m26px / m26_theme / m26_gate）—— **首元素不是字面量**（是个 Call），
       于是整条 edit 抽不出来、三道脚本一起变盲区。
   再加上首元素常用模块级常量（`POP = "src/contracts/QSkinPopover.qml"`）。
   少认一种形状，那批变异就**静默不在审计范围内** —— 与"检查了 0 条算通过"
   是同一个错误，所以每种形状都要能抽出来，并且抽不到的脚本要报出来。
   ⚠ ①~③ 是老形状，**④ 是 M26 才第一次出现的**（M25 收口时还是"盲区 0 道"）。
   形状会继续长 —— 所以"抽不到就报出来"这条兜底，才是本审计器真正的承重件；
   那三条形状识别只是尽力而为。

── 判据（无阈值，四分类）──────────────────────────────────────────────
    OK       原文在位
    RESIDUE  源码里是「改坏成」那一份          → **非 0 退出**
    SUSPECT  只能由"原文不在了"间接怀疑（删行型变异）→ 只提示，不判红
    STALE    原文与改坏成都不在（锚点漂了）    → 只提示，不判红

**"先判原文在不在"和"先判改坏成在不在"都不对**，要按包含关系分型：

  · `改坏成` 是 `原文` 的**子串**（典型：删掉后半段。如 OTP 的
    `return i * root.stride + seps * root.sepStride` → `return i * root.stride`）
    → 原文在位时改坏成**也**在（它是前缀）⇒ 必须**先看原文**。
  · `原文` 是 `改坏成` 的**子串**（典型：往中间插一句）
    → 原文在位时无法区分 ⇒ 必须**先看改坏成**。
  · 互不包含 ⇒ 随便，两个都判。
  （第一版只写了"先判改坏成"，于是把一个**健康的** `QSkinTextarea.qml`
   报成残留 —— 假阳性。审计器报假阳性的代价是下一次没人信它。）

── 行尾 ───────────────────────────────────────────────────────────────
与变异脚本同款处理：按文件自己的行尾把 `old` / `new` 里的 `\\n` 换算过去。
否则 CRLF 文件（本仓有 13 个）上的多行锚点一条都匹配不上，
**审计器自己变成摆设**。

── 从 .cache/ 升格到 tools/（M26 收口）────────────────────────────────
它原本住在 `.cache/_audit_residue.py`，而被引用 **14 处**（README 的目录树
与三处里程碑小节、COVERAGE 的方法论小节、长笔记的门禁表），还标着"收口必跑"。
问题不在"会不会被 `clean-cache.sh --all` 删掉"—— 它名字不匹配那批模式，
**碰巧**活了下来 —— 而在于：

  · 名字碰巧存活是**不可依赖的**。clean-cache.sh 自己的文件头就写着这条教训
    （"实测 `.cache/_probe_del.py`（一个 .py）就是被 `*_probe*` 删掉的。
    所以：凡是文档引用过的产物，别只留一个文件名引用"），而那张模式表在 M26
    之前就**刚长过一次**（新增 `_*.qml`）。
  · `.cache/` 是本项目**明文规定可随时清空**的构建目录。引用它的文档越多，
    "一次清空 = 一批引用同时悬空"的爆炸半径越大。
  · 同项目已有先例：comprehension 作用域门禁同样从 `.cache/` 升格到 `tools/`，
    理由逐字相同 —— **一个住在可丢弃目录里的闸不算闸**。

升格后它进了 `./tools/lint.sh` 作**第十道**（前九道：qmllint / 字符图标 /
Shape 渲染器 / 未定义函数 / comprehension 作用域 / 令牌名 —— 排在最后是因为
它审的是"源码此刻装的是哪一份"，与前面每道判的都不是同一件事）。
接线时补掉一个环境耦合：`.cache/` **整棵不存在**时跳过且**不算失败**
（变异脚本不住在这台机器上，也就无残留可言）；有 `.cache/` 却抽不到任何
`mutate_m*.py` 仍算**失败** —— 那是"没查"，不是"没问题"。

用法：
    ./tools/check-mutation-residue.sh              # 审 src/ + 登记过的构建文件（lint 用这一档）
    ./tools/check-mutation-residue.sh --all        # 连 tests/ examples/ 一起审
    python tools/check-mutation-residue.py [--all]
退出码：0 = 无残留；1 = 有残留 / 有脚本一条都没抽出来（覆盖不全）/ 有 .cache
        却没有任何变异脚本；`.cache/` 整棵不存在 → 0（跳过，且出声）
"""

import ast
import glob
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

SUFFIX = (".qml", ".js", ".py", ".qrc")
ONLY_SRC = "--all" not in sys.argv

# ── 变异靶子不必都在 `src/` 下（M28 补）─────────────────────────────────
#
# M28 的清单门禁变异打的是 **`CMakeLists.txt`** —— 构建入口，是真源码。
# 而它的路径既不含 `/`、后缀也不在 SUFFIX 里，于是 `looks_like_path` 一格都
# 认不出来，整道脚本被判**盲区**（第十道当次就红了：`一条 edit 都没抽出来`）。
#
# 这里**显式登记**，而不是放宽成"任意 .txt / 任意仓库根文件"：多认一个名字就
# 多一分把散文元组误认成 edit 的风险，而本审计器**报假阳性的代价是下次没人信它**
# （已栽过 4 次）。窄表 + 出声，与 `check-build-manifest.py` 里那张故意写窄的
# BLOCK_KEYWORDS 同一个取舍。
#
# 表只有一张，但要被**两个**判据共用 —— 抽得到而审不到，报告照样说"干净"：
#   · `looks_like_path`   抽得到
#   · `is_source_target`  默认档里审得到
# 而"抽到了但这一档不审"会**计数出声**（见 `skipped`），不静默跳过：
# 下次有人换了靶子却忘了登记，那个数会跳起来。
EXTRA_TARGET_FILES = (
    "CMakeLists.txt",        # M28：构建入口（清单门禁的靶子）
    "src/foundation/qmldir", # M29：类型名注册表（别名判据 [8] 的靶子）
                             #   它的后缀是 `qmldir` 而不是 `.qml`，所以
                             #   `looks_like_path` 的后缀那一条认不出它。
                             #   它虽然落在 src/ 下（默认档本来就审），但
                             #   **抽不出来 = 审不到** —— 判据是两段的，
                             #   只满足后一段等于没登记。
)


class _Unknown:
    def __repr__(self):
        return "<未知>"


UNKNOWN = _Unknown()


def read(path):
    """`newline=""` —— 见 README 第十一节第 11 条，本仓换行符是混的。"""
    with open(path, "r", encoding="utf-8", newline="") as f:
        return f.read()


def brief(text, n=74):
    """把一段替换文本压成一行用于打印。

    不能直接 `text.strip().splitlines()[0]` —— **"删掉一行"型变异的
    `改坏成` 可能整段都是空白**（实测：本审计器第一版正是在这里
    `IndexError` 崩掉，而崩的那一次已经找到了一处真残留）。
    一个"只在有东西要报的时候才崩"的审计器，等于没有。
    """
    for ln in text.strip().splitlines():
        if ln.strip():
            return ln.strip()[:n]
    return "<空 / 纯空白，多半是「删掉一行」型变异>"


def ev(node, consts):
    """只认常量/名字/元组/列表/字典/字符串拼接。**不执行任何代码。**"""
    if isinstance(node, ast.Constant):
        return node.value
    if isinstance(node, ast.Name):
        return consts.get(node.id, UNKNOWN)
    if isinstance(node, (ast.Tuple, ast.List)):
        vals = [ev(e, consts) for e in node.elts]
        if any(v is UNKNOWN for v in vals):
            return UNKNOWN
        return tuple(vals) if isinstance(node, ast.Tuple) else vals
    if isinstance(node, ast.Dict):
        out = {}
        for k, v in zip(node.keys, node.values):
            kk = ev(k, consts)
            if not isinstance(kk, str):
                return UNKNOWN
            out[kk] = ev(v, consts)
        return out
    if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add):
        a, b = ev(node.left, consts), ev(node.right, consts)
        if isinstance(a, (str, tuple, list)) and isinstance(b, type(a)):
            return a + b
        return UNKNOWN
    if isinstance(node, ast.JoinedStr):          # f-string：拼可求值的部分
        parts = []
        for v in node.values:
            if isinstance(v, ast.Constant) and isinstance(v.value, str):
                parts.append(v.value)
            else:
                return UNKNOWN
        return "".join(parts)
    if isinstance(node, ast.Call):
        # ── 形状 ④（M26 第一次出现）：`os.path.join("src", "contracts", "X.qml")`
        #
        # 为什么必须补：M26 的三道脚本用这个写路径常量，于是**一条 edit 都抽不出来**
        # —— 审计器照样打印"残留 0 处"，而那三道此刻根本不在审计范围内。
        # 文件头那句「少认一种形状，那批变异就静默不在审计范围内」第四次应验。
        #
        # ⚠ 拼的时候用 **"/"**，不是 `os.path.join`：本审计器下游有两处按 `/` 判
        #   ——`looks_like_path` 要求 `"/" in s`、`ONLY_SRC` 用 `p.startswith("src/")`。
        #   在 Windows 上拼成反斜杠的话，`looks_like_path` 会**又**把这条 edit
        #   静默判掉（同一个错犯第二次），而 `os.path.exists` 其实两种都认。
        #   只认 `os.path.join` 这一种调用，且**全部实参都必须是可求值字符串**；
        #   仍然不执行任何代码。
        f = node.func
        is_join = (isinstance(f, ast.Attribute) and f.attr == "join"
                   and isinstance(f.value, ast.Attribute) and f.value.attr == "path"
                   and isinstance(f.value.value, ast.Name)
                   and f.value.value.id == "os")
        if not is_join:
            return UNKNOWN
        vals = [ev(a, consts) for a in node.args]
        if not vals or any(not isinstance(v, str) for v in vals):
            return UNKNOWN
        return "/".join(vals)
    return UNKNOWN


def module_consts(tree):
    """模块级的 `名字 = <可求值表达式>`，含 `A = B + "/x"` 这种拼接。"""
    consts = {}
    for _ in range(3):                            # 允许常量互相引用
        for node in tree.body:
            if not isinstance(node, ast.Assign):
                continue
            val = ev(node.value, consts)
            if val is UNKNOWN:
                continue
            for t in node.targets:
                if isinstance(t, ast.Name):
                    consts[t.id] = val
    return consts


def looks_like_path(s):
    """一格看起来像「仓库内某个文件的路径」。"""
    if not isinstance(s, str):
        return False
    if s in EXTRA_TARGET_FILES:          # 见文件头：变异靶子不必都在 src/ 下
        return True
    return "/" in s and s.endswith(SUFFIX)


def is_source_target(p):
    """默认档（ONLY_SRC）审哪些文件。

    必须与 `looks_like_path` 对齐：**抽得到却审不到 = 报告照样说"干净"**，
    而那是本审计器最贵的一种失败（见文件头「没在审这批」一条）。
    """
    return p.startswith("src/") or p in EXTRA_TARGET_FILES


def edits_of(script):
    """抽取去重后的 `(文件, 原文, 改坏成)` 列表。"""
    try:
        tree = ast.parse(read(script), script)
    except SyntaxError as e:
        print("!! %s 有语法错，抽不出来：%s" % (script, e))
        return None
    consts = module_consts(tree)
    found = []
    for node in ast.walk(tree):
        # 形状 ②：`dict(path=…, old=…, new=…)` —— 注意这是 **ast.Call**，
        # **不是 ast.Dict**（那只是 `{…}` 字面量）。实测第一版就栽在这里：
        # `mutate_m18.py`~`mutate_m19_theme.py` 七道脚本一条都抽不出来，
        # 因为它们的 edit 全写成 `dict(...)` 调用。
        # 这一类"盲区"最危险 —— 审计器照样打印"干净"，只是**没在审这批**。
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) \
                and node.func.id == "dict":
            kv = {}
            if node.args:                      # dict(字面量) 这一种也认
                d = ev(node.args[0], consts)
                if isinstance(d, dict):
                    kv.update(d)
            for kw in node.keywords:
                if kw.arg:
                    kv[kw.arg] = ev(kw.value, consts)
            if all(isinstance(kv.get(k), str) for k in ("path", "old", "new")) \
                    and looks_like_path(kv["path"]):
                found.append((kv["path"], kv["old"], kv["new"]))
            continue
        # 形状 ②′：`{...}` 字面量（同样的键）
        if isinstance(node, ast.Dict):
            kv = {}
            for k, v in zip(node.keys, node.values):
                kk = ev(k, consts)
                if isinstance(kk, str):
                    kv[kk] = ev(v, consts)
            if all(isinstance(kv.get(k), str) for k in ("path", "old", "new")) \
                    and looks_like_path(kv["path"]):
                found.append((kv["path"], kv["old"], kv["new"]))
            continue
        # 形状 ①③：元组/列表（可能是拼接出来的）
        if isinstance(node, (ast.Tuple, ast.List)):
            t = ev(node, consts)
            if not isinstance(t, tuple) or not all(isinstance(x, str) for x in t):
                continue
            # 路径**不固定在首位** —— `mutate_m21_px.py` 是六元组
            # `(标签, 路径, 原, 改, 期望, 说明)`，路径在索引 1。
            # 所以按"找到像路径的那一格"来定位，而不是写死 [0]。
            for i in range(len(t) - 2):
                if looks_like_path(t[i]):
                    found.append((t[i], t[i + 1], t[i + 2]))
                    break
    seen, out = set(), []
    for e in found:
        if e not in seen:
            seen.add(e)
            out.append(e)
    return out


def classify(body, old, new):
    """返回 (结论, 说明)。结论 ∈ {OK, RESIDUE, SUSPECT, STALE}。

    规则按**包含关系**分三型（顺序本身就是判据的一部分，不能随手调）：

      A. `改坏成` 是 `原文` 的子串（删掉后半段那一类）
         原文在位 ⇒ 改坏成**也**在位（它是前缀）⇒ 只能**先看原文**。
      B. `原文` 是 `改坏成` 的子串（往中间插一句那一类）
         改坏成在位 ⇒ 原文也在位 ⇒ 只能**先看改坏成**。
      C. 互不包含 ⇒ **先看原文**。理由不是"原文更可靠"，而是：
         变异脚本落刀前都会核对「原文恰好出现一次」；所以只要原文还在，
         那次替换就没有发生。反过来先看改坏成会踩**假阳性**——
         实测：`mutate_m19_px.py [7]` 把 `: Math.min(Theme.radius.lg, …)`
         换成 `: 0`，而 `": 0"` 这三个字符在一个正常 QML 文件里到处都是
         （任何 `foo: 0` 都含它）。先看改坏成 → 把一个**健康**的
         `QSkinAvatar.qml` 报成残留。
    """
    nl = "\r\n" if "\r\n" in body else "\n"
    o = old.replace("\n", nl)
    n = new.replace("\n", nl)

    if o == n:
        # 第 ④ 型：`原文 == 改坏成`（**空变异**）。
        # 落刀时脚本自己就会拒（`替换后文本没变`），所以空变异**永远不会**在源码里
        # 留下东西 —— 不可能有残留。
        # 不单独处理的话它会掉进 B 型（`o in n` 恒真）→ 被报成 RESIDUE：
        # 实测 M26 的 `P7x` 在源码里写过一个"占位 edit"（`y: 580` → `y: 580`），
        # 运行时才由 `CASES[-1]['edits'] = […]` 换成真锚点 —— 审计器当场打出一处
        # **假残留**。假阳性的代价是下一次没人信它（本文件第 57 行已经记过一次）。
        # 报成 NOOP 而不是 OK：空变异本身是个味道，要让人看见，但不该判红。
        return "NOOP", "原文与改坏成相同（空变异，不可能有残留）"

    old_in = o in body
    new_in = n.strip() != "" and n in body

    if n.strip() == "":
        # 删行型：`"" in body` 永远为真，无法用改坏成判定
        return ("OK", "") if old_in else \
               ("SUSPECT", "原文不在了，而这一枪只是删行，无法自动判定")
    if n in o and o not in n:                       # A
        if old_in:
            return "OK", ""
        return ("RESIDUE", brief(n)) if new_in else ("STALE", "原文与改坏成都不在")
    if o in n:                                      # B
        if new_in:
            return "RESIDUE", brief(n)
        return ("OK", "") if old_in else ("STALE", "原文与改坏成都不在")
    if old_in:                                      # C
        return "OK", ""
    return ("RESIDUE", brief(n)) if new_in else ("STALE", "原文与改坏成都不在")


def main():
    # ── 两种"没东西可查"必须分开（升格进 lint 时补的）──────────────────
    # `.cache/` 整棵不在 = 变异脚本不住在这台机器上 → 没有残留可言，跳过且
    # **不算失败**（与 comprehension 作用域门禁同款：环境缺件不该把 lint 拖红，
    # 但要出声）。有 `.cache/` 却抽不到 mutate_m*.py = **工具链缺件** →
    # "没查"不是"没问题"，判红。
    if not os.path.isdir(".cache"):
        print("（跳过变异残留审计：没有 .cache/ —— 变异脚本不在这台机器上）")
        return 0
    scripts = [s for s in sorted(glob.glob(".cache/mutate_m*.py"))
               if "_preflight" not in s and "_audit" not in s]
    if not scripts:
        print("有 .cache/ 却找不到 .cache/mutate_m*.py —— 审计器没东西可查 = 失败")
        print("（这不是「没问题」，是「没查」—— 见文件头「抽不到就报出来」一条）")
        return 1

    total = residue = suspect = stale = blind = noop = skipped = 0
    touched = set()

    # 登记表里的名字必须真的在 —— 过期登记会把"审到了"变成错觉
    for f in EXTRA_TARGET_FILES:
        if not os.path.isfile(f):
            print("  ✗ 过期登记  EXTRA_TARGET_FILES 里的 %s 不在仓库里" % f)
            stale += 1

    for script in scripts:
        edits = edits_of(script)
        if edits is None:
            blind += 1
            continue
        if not edits:
            # "抽不到"绝不能算通过：那批变异此刻**不在审计范围内**
            print("  ✗ 盲区  %-30s 一条 edit 都没抽出来（形状没认全）"
                  % os.path.basename(script))
            blind += 1
            continue
        for p, old, new in edits:
            total += 1
            if ONLY_SRC and not is_source_target(p):
                # 抽到了，但不在这一档的范围内 —— **计数出声**，不静默跳过。
                # 默认档只审 src/ + 登记表，另有 tests/ examples/ 那部分；
                # 下次有人换了靶子却忘了登记，这个数会跳起来。
                skipped += 1
                continue
            if not os.path.exists(p):
                stale += 1
                continue
            touched.add(p)
            verdict, why = classify(read(p), old, new)
            if verdict == "RESIDUE":
                print("  ✗ 残留  %-44s ← %s" % (p, os.path.basename(script)))
                print("          源码里现在是「改坏成」那一份：%s" % why)
                residue += 1
            elif verdict == "SUSPECT":
                print("  ? 存疑  %-44s ← %s：%s" % (p, os.path.basename(script), why))
                suspect += 1
            elif verdict == "NOOP":
                noop += 1
                print("  ! 空变异  %-44s ← %s" % (p, os.path.basename(script)))
                print("          声明里 `原文` 与 `改坏成` 逐字相同：落刀那一刻会被"
                      "脚本自己拒掉（`替换后文本没变`），**不可能**在源码里留东西。"
                      "不影响残留判定 —— 但这是个味道：看一眼是不是忘了填锚点。")
            elif verdict == "STALE":
                stale += 1

    print()
    print("---- %d 道脚本 / 抽到 %d 条 edit / 本轮实际触及 %d 个文件%s"
          % (len(scripts), total, len(touched),
             "（只审 src/ + 登记过的构建文件）" if ONLY_SRC else ""))
    if ONLY_SRC and skipped:
        print("     其中 %d 条不在本档范围内（tests/ examples/ 等）"
              "—— 要看请加 --all" % skipped)
    print("     残留 %d 处 · 存疑 %d 处 · 锚点漂移 %d 处 · 盲区脚本 %d 道"
          " · 空变异 %d 处" % (residue, suspect, stale, blind, noop))
    if residue:
        print("\n**源码里有没复原的变异 —— 先还原再谈别的。**")
        print("（还原后必须重跑 `./tools/test.sh`：判据可能正是被它弄红的）")
    elif suspect:
        print("\n有「存疑」项：多半是删行型变异没复原。请人看一眼再决定。")
    elif blind:
        print("\n有脚本一条 edit 都没抽出来 —— 那批变异此刻**不在审计范围内**，"
              "别把它读成「没问题」。")
    else:
        print("\nsrc/ 干净：所有变异的「原文」都在位 ✓")
        if noop:
            print("（另有 %d 处**空变异**声明 —— 见上面 `!` 标记。"
                  "它不影响残留判定，但值得看一眼锚点是不是忘了填。）" % noop)
    # 存疑与盲区**也算失败**：宁可让人来看一眼，不可静默放过。
    return 1 if (residue or suspect or blind) else 0


if __name__ == "__main__":
    sys.exit(main())
