#!/usr/bin/env python3
"""QSkin · 未定义函数门禁（M20.1 起）

规则：一个 QML 文件里出现的 `name(...)` 调用，其 `name` 必须是
      **本文件里定义过的** 函数 / 信号 / 属性 / id / 变量，或者是 JS 内建。

── 为什么要这道闸 ────────────────────────────────────────────────────
M20 撞出一份这样的实现（BasicButtonBackground）：

    function opacity() { … isOn() … }
    function bg()      { … isOn() … }
    /* 而 `function isOn()` 一个字都没有 */

后果不是「少画一个像素」：`isOn()` 抛 ReferenceError → `d.bg()` 的返回值
失效 → `color: d.bg()` 这条**绑定**停在 Rectangle 的默认色上。整个按钮
变成一块白砖（实测 Basic 是 #ffffff）。

而现成的三道检查**全部放行**：
  · qmllint      —— QtObject 里的调用走运行时 JS 解析，静态检查不做
                    未定义函数分析（`unqualified` 那一条也不会命中）
  · smoke_*.qml  —— 属性侧断言不读按钮底色，29 个文件全绿
  · 只有 tst_interactive 那条**真鼠标事件**读到了颜色，才把红点亮

也就是说：从「代码写错」到「被人看见」之间隔了整整一层门禁的厚度。
修一次不难，难的是下次别再犯 —— 所以补上这道闸。

同批还撞到一处同族缺陷：`themes/*/slots/` 写在块注释里，那个
`星号+斜杠` 把注释提前闭合，后面半句变成代码，整棵 import 树 29 个
文件全红。那一条由 scan_comment_terminators() 一并守住。

── 判据 ─────────────────────────────────────────────────────────────
先剥掉注释与字符串（免得把散文和界面文本里的 `foo()` 当调用），然后：

    defined = function NAME(  ·  signal NAME  ·  property … NAME
            · id: NAME        ·  var / let / const NAME
    calls   = 前面不是 `.`、不是标识符字符、也不是 `new` 的 `NAME(`

    calls − defined − BUILTIN − KEYWORD ≠ ∅   →  报错，退出码 1

── 已知的宽松处（刻意宁漏不误）──────────────────────────────────────
  · 不解析作用域：任何位置定义过就算定义过。
  · **带接收者的调用一律不查** —— `root._snap(x)`、`listView.itemAt(i)`
    的名字解析要过 QML 类型系统，那是 qmllint 的活。所以把 `_snap` 改名
    而漏改 `root._snap(...)` 这类调用点，这道闸看不见。
    能看见的是**无接收者**的调用（`isOn()`、`variant()` 这种）——
    也就是 M20 实际撞到的那一类，全都在 `QtObject` 辅助块里。
  · 不认解构赋值、不认 `a.b = function(){}` 这类动态挂载。
  · 正则字面量不单独识别（含 `//` 的会被当注释剥掉），QML 里极少见。
全都往**放宽**的方向偏 —— 只会漏报，不会误报。误报会让人开始忽略这道闸，
那比没有这道闸更糟。
"""

import os
import re
import sys

ROOTS = ["src", "examples", "tests"]

# ── JS / QML 的全局名字。不是"允许"，是"本文件之外的定义" ──────────────
BUILTIN = {
    # JS 内建
    "Array", "BigInt", "Boolean", "Date", "Error", "Function", "JSON", "Map",
    "Math", "Number", "Object", "Promise", "Proxy", "Reflect", "RegExp",
    "Set", "String", "Symbol", "WeakMap", "WeakSet",
    "decodeURI", "decodeURIComponent", "encodeURI", "encodeURIComponent",
    "eval", "isFinite", "isNaN", "parseFloat", "parseInt",
    "console",
    # Qt / QML 全局函数
    "qsTr", "qsTranslate", "qsTrId", "qsTrIdNoOp",
    "QT_TR_NOOP", "QT_TRANSLATE_NOOP", "QT_TRID_NOOP",
}

# 控制流关键字也会长成 `if (`、`for (`，得挡掉
KEYWORD = {
    "if", "for", "while", "switch", "catch", "do", "else", "return", "case",
    "throw", "typeof", "void", "delete", "in", "of", "new", "function",
    "await", "yield", "class", "extends", "super", "instanceof", "with",
}

# QML TestCase 基类提供的断言 / 合成事件方法。只在 `import QtTest` 的
# 文件里放行 —— 这四个字本身就是"这些名字从哪来"的答案。
TESTCASE_API = {
    "compare", "tryCompare", "verify", "tryVerify", "fail", "skip", "wait",
    "waitForRendering", "sleep", "ignoreWarning", "expectFail",
    "expectFailContinue", "findChild",
    "mouseClick", "mouseDoubleClick", "mousePress", "mouseRelease",
    "mouseMove", "mouseWheel",
    "keyClick", "keyPress", "keyRelease", "keySequence",
    "touchEvent", "touchPress", "touchRelease", "touchMove",
    "gesture", "grabImage", "qtest_",
}

# ── QML 基类型上的方法（无接收者调用时解析到本对象）──────────────────
# 这一层是**判据的已知边界**：QML 里 `mapToItem(...)`、`getContext(...)`
# 这类调用没有接收者，名字来自对象自身的基类型（QQuickItem / Canvas…），
# 本文件里当然找不到定义。要做严格判定就得解析 QML 类型系统（那是 qmllint
# 的活，而 qmllint 实测对未定义函数退出码 0，不管）。
#
# 代价说清楚：这是一个**名单**，不是类型解析。名单外的合法 QML 方法会被
# 误报。遇到时把它加进来即可 —— 加一个名字的成本，远低于漏掉一个
# `isOn()` 然后整块按钮变白砖。
QML_METHODS = {
    # QQuickItem
    "mapToItem", "mapFromItem", "mapToGlobal", "mapFromGlobal",
    "childAt", "contains", "forceActiveFocus", "nextItemInFocusChain",
    "grabToImage", "grabToImageSync", "stackBefore", "stackAfter", "update",
    # Canvas
    "getContext", "requestPaint", "markDirty", "loadImage", "unloadImage",
    "isImageLoaded", "isImageError", "toDataURL", "saveToFile",
    # Window / ApplicationWindow
    "close", "show", "hide", "raise", "lower", "requestActivate", "alert",
    # TextEdit / TextInput / TextArea
    "cut", "copy", "paste", "selectAll", "select", "deselect", "canPaste",
    "canUndo", "canRedo", "undo", "redo", "insert", "remove", "append",
    "getText", "getFormattedText", "positionToRectangle",
    "moveCursorSelection", "ensureVisible",
    # ListView / GridView / PathView
    "positionViewAtBeginning", "positionViewAtEnd", "positionViewAtIndex",
    "indexAt", "itemAt", "forceLayout",
    "incrementCurrentIndex", "decrementCurrentIndex",
    # Timer / Animation
    "start", "stop", "restart", "pause", "resume", "complete",
    # Component / Loader / ShaderEffectSource
    "createObject", "incubateObject", "setSource", "scheduleUpdate",
}

IDENT = r"[A-Za-z_$][\w$]*"

RE_FUNC = re.compile(r"\bfunction\s+(" + IDENT + r")\s*\(")
RE_SIGNAL = re.compile(r"\bsignal\s+(" + IDENT + r")")
RE_PROP_ALIAS = re.compile(r"\bproperty\s+alias\s+(" + IDENT + r")")
RE_PROP = re.compile(r"\bproperty\s+(?:[\w.$]+(?:<[^>]*>)?)\s+(" + IDENT + r")")
RE_ID = re.compile(r"\bid\s*:\s*(" + IDENT + r")")
RE_VAR = re.compile(r"\b(?:var|let|const)\s+(" + IDENT + r")\s*[,=;)]")

# 参数名只从**函数签名**与**箭头函数头**里取。
# 早期版本写的是"任意括号里的标识符都算参数"，那会把 `foo(bar)` 里的 bar
# 也算成"已定义"—— 于是 `bg()` 里写一个不存在的 `helper()`，只要它是以
# 参数形式出现就会被放行。判据必须只认真正的形参表。
RE_FUNC_ARGS = re.compile(r"\bfunction\s*(?:" + IDENT + r")?\s*\(([^)]*)\)")
RE_ARROW_ARGS = re.compile(r"(?:\(([^)]*)\)|(" + IDENT + r"))\s*=>")
RE_ARG_IDENT = re.compile(IDENT)

RE_CALL = re.compile(r"(" + IDENT + r")\s*\(")


def strip_comments_and_strings(src: str) -> str:
    """把注释与字符串换成空格，保留换行 —— 行号才不会漂。"""
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""

        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                out.append(" ")
                i += 1
            continue

        if c == "/" and nxt == "*":
            out.append("  ")
            i += 2
            while i < n and not (src[i] == "*" and i + 1 < n and src[i + 1] == "/"):
                out.append("\n" if src[i] == "\n" else " ")
                i += 1
            out.append("  ")
            i += 2
            continue

        if c in "\"'`":
            quote = c
            out.append(" ")
            i += 1
            while i < n and src[i] != quote:
                if src[i] == "\\" and i + 1 < n:
                    out.append("  ")
                    i += 2
                    continue
                out.append("\n" if src[i] == "\n" else " ")
                i += 1
            out.append(" ")
            i += 1
            continue

        out.append(c)
        i += 1
    return "".join(out)


def scan_comment_terminators(src: str):
    """块注释被 `星号+斜杠` 提前闭合 → 报出来。

    这是 M20 把 `themes/星号/slots/` 写进文件头导致的：报错行号指在注释中间，
    因果极难看出，而后果是整棵 import 树全红。

    这个坏法有**两种形状**，一种判据盖不住两种 —— 第一次写的时候只做了
    跨行那一种，用它自己的变异体一测就漏（变异写在单行里，闸没反应）：

      (A) 跨行：注释从第 1 行开到第 25 行，中间那个 `星号+斜杠` 把它提前
          闭合，同一行余下的半句变成代码。
          → 判据：**闭合符之后同一行还有非空白内容**。
      (B) 单行：整段写在一行里，提前闭合之后余下的内容里**又出现一个
          游离的结束符**（没有对应的开始符）。
          → 判据：**不在注释里时遇到结束符**。

    (B) 顺带把"结束符游离"这种最普通的括号不配对也一起守住了。
    """
    lines = src.splitlines()
    bad = []
    block = False
    i, n = 0, len(src)
    lineno = 1

    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""

        if c == "\n":
            lineno += 1
            i += 1
            continue

        # 字符串里的符号一律不算数（`text: "*/"` 之类）
        if c in "\"'`":
            quote = c
            i += 1
            while i < n and src[i] != quote:
                if src[i] == "\\":
                    i += 1
                elif src[i] == "\n":
                    lineno += 1
                i += 1
            i += 1
            continue

        if block:
            if c == "*" and nxt == "/":
                block = False
                i += 2
                tail = src[i:src.find("\n", i) if src.find("\n", i) >= 0 else n]
                if tail.strip():
                    # (A) 提前闭合：闭合符之后同一行还有内容
                    bad.append((lineno, lines[lineno - 1].strip() if lineno - 1 < len(lines) else ""))
                continue
            i += 1
            continue

        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue

        if c == "/" and nxt == "*":
            block = True
            i += 2
            continue

        if c == "*" and nxt == "/":
            # (B) 不在注释里却遇到结束符 —— 前面某处注释被提前闭合了
            bad.append((lineno, lines[lineno - 1].strip() if lineno - 1 < len(lines) else ""))
            i += 2
            continue

        i += 1

    return bad


def collect_defined(code: str) -> set:
    names = set()
    for rx in (RE_FUNC, RE_SIGNAL, RE_PROP_ALIAS, RE_PROP, RE_ID, RE_VAR):
        names.update(rx.findall(code))

    for m in RE_FUNC_ARGS.finditer(code):
        names.update(RE_ARG_IDENT.findall(m.group(1)))
    for m in RE_ARROW_ARGS.finditer(code):
        names.update(RE_ARG_IDENT.findall(m.group(1) or ""))
        if m.group(2):
            names.add(m.group(2))
    return names


def find_bad_calls(code: str, defined: set, allowed: set):
    bad = []
    for m in RE_CALL.finditer(code):
        name = m.group(1)
        prev = code[m.start() - 1] if m.start() > 0 else ""
        if prev == ".":
            continue
        if name in defined or name in allowed or name in KEYWORD:
            continue
        # `new Foo(` —— Foo 是类型不是函数
        before = code[max(0, m.start() - 8):m.start()]
        if re.search(r"\bnew\s*$", before):
            continue
        lineno = code.count("\n", 0, m.start()) + 1
        bad.append((lineno, name))
    return bad


def qml_files(roots):
    found = []
    for root in roots:
        if not os.path.isdir(root):
            continue
        for dirpath, _dirs, files in os.walk(root):
            for f in sorted(files):
                if f.endswith(".qml"):
                    found.append(os.path.join(dirpath, f))
    return sorted(found)


def main() -> int:
    roots = sys.argv[1:] or ROOTS
    files = qml_files(roots)
    if not files:
        print("（没有找到 QML 文件）")
        return 0

    total_bad = 0
    total_bad_comment = 0

    for path in files:
        with open(path, "r", encoding="utf-8") as fh:
            raw = fh.read()

        for lineno, text in scan_comment_terminators(raw):
            print(f"{path}:{lineno}: 块注释被提前闭合 —— 注释里写着 `*/`，"
                  f"后面还有内容会变成代码")
            print(f"    {text}")
            total_bad_comment += 1

        code = strip_comments_and_strings(raw)
        defined = collect_defined(code)
        allowed = (BUILTIN | QML_METHODS
                   | (TESTCASE_API if "import QtTest" in raw else set()))
        for lineno, name in find_bad_calls(code, defined, allowed):
            print(f"{path}:{lineno}: 调用了未定义的函数 `{name}()` "
                  f"（本文件里没有 function {name} / signal {name} / "
                  f"property {name} / var {name}）")
            total_bad += 1

    print("")
    if total_bad == 0 and total_bad_comment == 0:
        print(f"✓ 未定义函数：{len(files)} 个文件，0 处")
        return 0

    if total_bad:
        print(f"✗ {total_bad} 处调用了未定义的函数")
    if total_bad_comment:
        print(f"✗ {total_bad_comment} 处块注释被 `*/` 提前闭合")
    return 1


if __name__ == "__main__":
    sys.exit(main())
