#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""QSkin · Python 静态扫描：**comprehension 里引用了未绑定的名字**

用法：
    ./tools/check-comprehension-scope.sh                    # 扫默认范围
    ./tools/check-comprehension-scope.sh 路径...             # 只扫给定文件
    python tools/check-comprehension-scope.py tools/*.py    # 直接跑 .py 也行

默认范围：`tools/*.py` + `.cache/*.py`（后者不存在时自动跳过，不算失败）。
**不含** `.cache/keep/` —— 那里放的是历史快照，不是活代码。

退出码：0 = 干净，1 = 有命中，2 = 用法错。

═══════════════════════════════════════════════════════════════════════════
这个扫描器是为一个**真撞到的**缺陷写的（M23 收口）
═══════════════════════════════════════════════════════════════════════════
`.cache/_verify_m23.py` 的 `check_timeline` 里原本写着：

    hits = [x / DPR for _x, _y, c in img.region(cx, TL_Y, cx, top_win_y1) if is_dv(c)]

绑的是 `_x`，表达式却用 `x`。它不会在导入时报错、也不会在第一次运行时报错 ——
**列表推导的表达式只对"通过过滤器的元素"求值**。于是：

  · 画面对的时候（没有任何像素命中 `is_dv`）→ 表达式一次都不求值 → 静默通过；
  · 画面错的时候（本该报红）→ 求值 → `NameError` → **核验器整个崩掉**。

也就是说那条断言**从写下的那一刻起就没真正跑过**，而它恰好是 QSkinTimelineItem
文件头点名"最值钱"的那条（"属性侧只能读到 isFirst，读不到那颗点上面真的没有线"）。
它是被变异测试逼出来的：改坏实现 → 期望 `[3][4]` 红 → 实际看到的是
"没有组变红"（因为核验器崩在 stderr，stdout 一个字都没有）。

同类写法在整个 Python 生态里都很常见（`for _k, v in ...` 然后写 `k`）。
纯靠 review 抓不住，所以做成扫描器：**comprehension 里 Load 的名字必须
绑定于它自己的 target、外层函数的局部/参数、或内建**。

═══════════════════════════════════════════════════════════════════════════
从 `.cache/` 升格到 `tools/`（同一轮），以及升格时补掉的一个缺陷
═══════════════════════════════════════════════════════════════════════════
它原本住在 `.cache/_scan_compscope.py` —— 而 `.cache/` 是本项目**明文规定
可随时清空**的构建目录（`tools/clean-cache.sh --all`）。**一个住在可丢弃
目录里的闸不算闸**：清一次缓存，它连同它抓到的那个病一起消失。

升格时做的第一件事是拿它扫一遍**整个工具链**（`tools/*.py` + `.cache/*.py`），
结果它在干净代码上报了 **16 处误报**（全在 `.cache/mutate_m22_gate.py`）：

    FAIL  .cache/mutate_m22_gate.py:174  名字 'out' 未绑定
            [l for l in out.strip().splitlines() if l.strip()]

`out` 明明绑在上一行的 `code, out = run_gate(cmd)` 里。根因是第一版的
`module_names()` **只认顶层 `Assign`**，而那段代码在**模块级的 `for` 循环体**里
（`for cmd in (FN, AA, ICON):`）。`For` 的 target、`With ... as x`、`Try` 分支
里的赋值，全都收集不到。它当年也没被发现，因为它当时的唯一消费者
`_verify_m23.py` 是"模块级常量 + 全函数体"的写法，恰好绕开了这一类。

修法：模块作用域改成**作用域感知的遍历**（`_ModuleScope`）—— 走遍模块体的
所有语句（`for` / `if` / `with` / `try` 都进），只在遇到函数 / 类 / lambda /
comprehension 这些**新作用域**时停下。同时把这一类误报从"已知宽松处"改成
"已修缺陷"：**误报的闸一定会被无视，然后就成了死闸。**

已知宽松处（写在这里免得后人当缺陷报）：
  · 不做跨函数的全局名解析 —— 只把**模块作用域**的绑定与内建算作"外层已有"。
  · 不管 `global` / `nonlocal`（函数里 `global x; x = 1` 会绑到模块级，
    这里看不到 → 可能误报；本项目没有这种写法）。
  · 不管装饰器改类、不管 `del`。
  · 推导式第一个 `for` 的 `iter` 与外层同名时不会报（把"本层所有 target"
    一律当可见的）。宁可宽松 —— 目标是抓"根本没绑定过"的名字。

═══════════════════════════════════════════════════════════════════════════
第二次修：**嵌套推导式**上的误报（M24 撞到）
═══════════════════════════════════════════════════════════════════════════
M24 的真现场（`.cache/_qr_empty_probe.py:43`，合法且实测跑通过的代码）：

    ref = ["".join("1" if c else "0" for c in row) for row in qr.get_matrix()]

它在 `c` 与 `row` 两个名字上各报一次 FAIL。两个都是误报，根因是同一个：
`_comp()` 查本层时用的是 `ast.walk(piece)` —— 而 `ast.walk` 会**一路走进
嵌套推导式的函数体**，把内层的名字当成"本层直接用了"：

  · `c` —— 内层 genexp 的 target，被外层当成"外层引用了 c"，而外层没绑它；
  · `row` —— 外层 target，递归到内层 `_comp()` 时又不在内层的 `bound` 里。

也就是说：**每一次递归都把作用域链丢掉一层**。修法两条，缺一不可：
  ① 查本层时换成 `_loads_shallow()` —— 遇到新作用域（lambda / 嵌套推导式 /
     函数 / 类）就**停在门口**，里面的名字交给它自己的入口去查；
  ② 加一条"推导式 target 栈"（`_comp_scopes`），递归进内层时把外层的 target
     带过去 —— `for row in M` 的 `row` 对 `for c in row` 是可见的。

这条与上一段那个"模块级 for 循环"是同一类病（**作用域没跟着走**），
只是这次丢的是**推导式**那一层。
"""

import ast
import builtins
import glob
import os
import sys

# 默认扫描范围。放在这里（而不是写死在 .sh 里）是为了让"直接跑 .py"与
# "跑 .sh"扫到同一批文件 —— 两条入口扫不同范围，是门禁最隐蔽的一种失信。
DEFAULT_ROOTS = ("tools/*.py", ".cache/*.py")


class _ModuleScope(ast.NodeVisitor):
    """收集**模块作用域**被绑定的名字。

    与 `ast.walk(tree)` 的差别只有一条、但正是本轮翻车的那条：**遇到新作用域
    就停**（函数 / 类 / lambda / comprehension 的函数体不进），而**语句体全进**
    —— `for` / `if` / `while` / `with` / `try` 里的赋值都是模块作用域的绑定。
    第一版只遍历 `tree.body` 顶层的 `Assign`，于是模块级循环里的名字全丢。
    """

    def __init__(self):
        self.names = set()

    # ── 语句体里真正的绑定 ──
    def visit_Name(self, node):
        if isinstance(node.ctx, ast.Store):
            self.names.add(node.id)

    def visit_Import(self, node):
        for al in node.names:
            self.names.add((al.asname or al.name).split(".")[0])

    visit_ImportFrom = visit_Import

    def visit_ExceptHandler(self, node):
        if node.name:
            self.names.add(node.name)
        for s in node.body:
            self.visit(s)

    # ── 新作用域：只收名字，不进函数体 ──
    def visit_FunctionDef(self, node):
        self.names.add(node.name)

    visit_AsyncFunctionDef = visit_FunctionDef

    def visit_ClassDef(self, node):
        self.names.add(node.name)

    def visit_Lambda(self, node):
        pass

    def visit_ListComp(self, node):
        pass

    visit_SetComp = visit_ListComp
    visit_DictComp = visit_ListComp
    visit_GeneratorExp = visit_ListComp


def module_names(tree):
    out = set(dir(builtins)) | {"__name__", "__file__", "__doc__"}
    scope = _ModuleScope()
    for stmt in tree.body:
        scope.visit(stmt)
    return out | scope.names


def function_locals(fn):
    """一个函数体里**任何位置**被赋值/绑定过的名字（不做流敏感分析 —— 这里
    宁可宽松：我们的目标是抓"根本没绑定过"的名字）。"""
    out = set()
    a = fn.args
    for x in list(a.args) + list(a.posonlyargs) + list(a.kwonlyargs):
        out.add(x.arg)
    if a.vararg:
        out.add(a.vararg.arg)
    if a.kwarg:
        out.add(a.kwarg.arg)
    for sub in ast.walk(fn):
        if isinstance(sub, ast.Name) and isinstance(sub.ctx, ast.Store):
            out.add(sub.id)
        elif isinstance(sub, (ast.Import, ast.ImportFrom)):
            for al in sub.names:
                out.add((al.asname or al.name).split(".")[0])
        elif isinstance(sub, ast.ExceptHandler) and sub.name:
            out.add(sub.name)
        elif isinstance(sub, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            out.add(sub.name)
    return out


# 新作用域的节点 —— 查名字时**停在它们门口**（里面的名字由各自入口去查，
# 否则会把内层推导式的 target 误判成"外层引用了未绑定的名字"）。
_SCOPE_NODES = (ast.Lambda, ast.ListComp, ast.SetComp, ast.DictComp,
                ast.GeneratorExp, ast.FunctionDef, ast.AsyncFunctionDef,
                ast.ClassDef)


def loads_shallow(node):
    """node 里所有 `Load` 的名字，**不进新作用域**。

    与 `ast.walk(node)` 的差别只有这一条，而它正是 M24 那次误报的根因 ——
    `ast.walk` 会走进嵌套推导式的函数体，把内层的 target（或内层用到、
    由内层 `iter` 提供的名字）当成外层直接引用的名字。
    """
    out = []
    stack = [node]
    while stack:
        n = stack.pop()
        if isinstance(n, ast.Name):
            if isinstance(n.ctx, ast.Load):
                out.append(n)
            continue
        if isinstance(n, _SCOPE_NODES):
            continue
        stack.extend(ast.iter_child_nodes(n))
    return out


class Scanner(ast.NodeVisitor):
    def __init__(self, path):
        self.path = path
        self.scopes = [set()]
        # 推导式 target 的栈：递归进内层时，外层的 target 对内层可见
        # （`[... for c in row] ... for row in M` 里的 row）。
        self.comp_scopes = []
        self.hits = []

    def visit_Module(self, node):
        self.scopes = [module_names(node)]
        self.generic_visit(node)

    def visit_FunctionDef(self, node):
        self.scopes.append(function_locals(node))
        self.generic_visit(node)
        self.scopes.pop()

    visit_AsyncFunctionDef = visit_FunctionDef

    def visit_Lambda(self, node):
        self.scopes.append(function_locals(node))
        self.generic_visit(node)
        self.scopes.pop()

    def visit_ListComp(self, node):
        self._comp(node)

    def visit_SetComp(self, node):
        self._comp(node)

    def visit_DictComp(self, node):
        self._comp(node)

    def visit_GeneratorExp(self, node):
        self._comp(node)

    def _comp(self, node):
        bound = set()
        for g in node.generators:
            for n in ast.walk(g.target):
                if isinstance(n, ast.Name):
                    bound.add(n.id)
        pieces = [getattr(node, "elt", None),
                  getattr(node, "key", None),
                  getattr(node, "value", None)]
        for g in node.generators:
            pieces.append(g.iter)
            pieces.extend(g.ifs)

        outer = set()
        for s in self.scopes:
            outer |= s
        for s in self.comp_scopes:
            outer |= s

        for piece in pieces:
            if piece is None:
                continue
            # **浅**遍历：嵌套推导式 / lambda 里的名字不在这里判（它们由
            # 各自的入口查，并会带上本层的 target）。见 loads_shallow 的注释。
            for n in loads_shallow(piece):
                if n.id not in bound and n.id not in outer:
                    self.hits.append(
                        (n.lineno, n.id, ast.unparse(node).replace("\n", " ")[:88]))

        # 继续往下走（嵌套推导式也要查），但要把**本层的 target** 带上 ——
        # 否则内层的 `for c in row` 会找不到 `row`。
        self.comp_scopes.append(bound)
        try:
            for g in node.generators:
                self.visit(g.iter)
            for piece in (getattr(node, "elt", None),
                          getattr(node, "key", None),
                          getattr(node, "value", None)):
                if piece is not None:
                    self.visit(piece)
        finally:
            self.comp_scopes.pop()


def discover():
    """默认范围：把 DEFAULT_ROOTS 展开成排序后的文件表。

    去掉 `.cache/keep/`（历史快照不是活代码）。文件表排序是为了让输出
    稳定 —— 一个顺序会变的门禁没法拿来比日志。
    """
    files = []
    for pat in DEFAULT_ROOTS:
        for p in glob.glob(pat):
            if os.path.isfile(p) and p not in files:
                files.append(p)
    return sorted(files)


def main(argv):
    paths = argv[1:] or discover()
    if not paths:
        print("!! 没有扫到任何 .py 文件 —— 默认范围 %s 全是空的。"
              % " + ".join(DEFAULT_ROOTS))
        print("   「检查了 0 个文件」按本项目纪律算**失败**，不算通过。")
        return 1

    total = 0
    for path in paths:
        try:
            with open(path, encoding="utf-8") as f:
                src = f.read()
        except OSError as e:
            print("读不到 %s：%s" % (path, e))
            total += 1
            continue
        try:
            tree = ast.parse(src, path)
        except SyntaxError as e:
            # 解析不了的 .py 不算"干净" —— 它是"这道闸看不见它"。
            print("FAIL  %s:%s  **解析失败**：%s" % (path, e.lineno, e.msg))
            total += 1
            continue
        sc = Scanner(path)
        sc.visit(tree)
        if not sc.hits:
            continue
        total += len(sc.hits)
        for lineno, name, code in sc.hits:
            print("FAIL  %s:%d  名字 %r 未绑定" % (path, lineno, name))
            print("        %s" % code)

    print("")
    print("扫了 %d 个文件，命中 %d 处" % (len(paths), total))
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
