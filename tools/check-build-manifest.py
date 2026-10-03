#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#############################################################################
# QSkin · 构建清单门禁（M28 起，lint.sh 第十一道）
#
# 问的问题：**`CMakeLists.txt` 里列的 QML / JS 文件，和 `src/` 下真实存在的
# 那一堆，是不是同一份？**
#
# ── 为什么要有这一条 ────────────────────────────────────────────────────
# `CMakeLists.txt` 的文件头一直写着「M0 地基层 + M1 契约层（五个插槽 +
# 六个控件）」。这句话在 M1 之后就没再改过，而 `tools/` 那套**直跑路线**
# （在 `.cache/qmlimports` 里搭一份目录名与 URI 匹配的副本）一直工作良好，
# 于是**没有人跑过官方构建路径，也就没有人发现它已经烂了**。
#
# M28 开工实测：清单里 27 条路径，`src/` 下真实的 QML/JS 有 187 个；
# 四套主题**一个模块都没挂**。用官方路径构建出来的人拿到的是一份
# **只有 6 个控件、没有任何主题**的残缺品 —— 而三道门禁全绿。
#
# 这正是本项目最熟悉的那类失败：**一个没人跑的东西，看起来一直是好的。**
#
# ── 为什么不是「生成器 + 清单」─────────────────────────────────────────
# 用 `file(GLOB)` 或一个生成脚本自动产出清单，确实能消灭"漏列"这一类缺陷
# —— 但同时也会让**这道闸恒绿**：清单是算出来的，两边当然永远相等。
# 那是判据空转（本项目明令禁止的形状），比没有闸更坏：它会被记进
# "已验证"。
#
# 所以取舍是：**清单手写、闸独立扫**（不读任何生成器的产物、不 import
# CMake、不调用 `cmake`）。漏列的修法也反过来 —— **先让闸把漏项报出来，
# 再按报告补清单**，而不是先写个脚本把清单凑齐。
#
# ── 八条判据 ────────────────────────────────────────────────────────────
#   [1] 悬空   清单里写的路径必须真实存在
#   [2] 漏列   `src/` 下每个 .qml / .js 必须被某个模块列进去
#   [3] 重复   同一个路径不得出现在两处（含同块重复、跨块重复）
#   [4] 归属   路径必须落在它所属模块的源目录下
#   [5] 模块   每个 qmldir 的 `module` URI 必须有一个 qt_add_qml_module 块，
#              反之每个块的 URI 也必须有一个 qmldir —— 两条都要，否则
#              「模块在源码里有、构建产物里没有」这种半死状态查不出来
#   [6] 单例   qmldir 里 `singleton` 声明过的文件，清单里必须有
#              `set_source_files_properties(<它> PROPERTIES
#               QT_QML_SINGLETON_TYPE TRUE)`
#   [7] 解析   块内出现了既不认识、又不是 `src/…` 路径的 token
#              （防"清单里有一行我看不懂"——看不懂就是没查）
#   [8] 别名   qmldir 里**同一个文件注册了多个类型名**的，构建路径复现不了
#              —— 要么声明豁免，要么修掉；声明了却没这个必要 = 过期豁免
#
# 另有一条**元判据**（本项目惯例）：抽到 0 个模块 / 扫到 0 个文件一律算失败。
# 「检查了 0 条」不是「没问题」，是「没查」。
#
# ── [6] 与 [8] 的依据不是推理，是 Qt 自己的源码 ─────────────────────────
# `$QT/lib/cmake/Qt6Qml/Qt6QmlMacros.cmake` 里生成 qmldir 的那一段
# （6.8.3 在第 3292 / 3312 行）只做两件事：
#
#     get_source_file_property(qml_file_singleton ${qml_file_src}
#         QT_QML_SINGLETON_TYPE)                       # ← 只认源文件属性
#     string(APPEND qmldir_file_contents
#         "singleton " ... "${qml_file_typename} ${version} ${path}\n")
#                                                      # ← 每个文件只写一个名字
#
# 它**不读**源目录的 qmldir。而 `CMakeLists.txt` 自己的注释早就写着
# 「源码目录里的 qmldir 是给直跑路径用的，两条路互不影响」——
# 所以这两条不是"可能"，是**由既有声明直接推出的必然**：
#
#   · 17 个 singleton（Theme / Breakpoints / OverlayStack / ScrollUtil /
#     Slots / 四家主题…）在构建产物里会退化成**普通组件**。
#     `Theme.color.xxx` 在非单例上不是"未定义"，是**另一个对象上的成员**，
#     报的错会离现场很远。
#   · `Row.qml` / `Column.qml` / `Grid.qml` 各注册两个名字（`Row` + `QSkinRow`），
#     而**58 个文件在用 `QSkinRow` / `QSkinColumn` / `QSkinGrid`**（是真代码，
#     不是注释）→ 构建产物里这些名字不存在，契约层会直接崩。
#
# [6] 的修法是补 17 行 `set_source_files_properties`（本批已做）。
# [8] **修不掉** —— `QT_QML_SOURCE_TYPENAME` 是单值属性，一个文件只能有
# 一个类型名，"一个文件两个名字"在 CMake 这一侧表达不出来。它要动那三个
# 布局容器本身，而已经裁决并入 M29（布局层专项），理由：M29 本来就要改
# 它们的默认行为，一起改只需重拍一次基线。
#
# 所以 [8] 的形式是**存量豁免 + 新增即红**（与令牌门禁的
# `token-gate: extend` 同构）：豁免写在 CMakeLists 里，决定留在源文件里。
#
# ── 怎么证伪这道闸（每条判据都要能被证伪）───────────────────────────────
#   1. 从 `QML_FILES` 里删掉任一行          → [2] 必须变红
#   2. 把某一行改成不存在的文件              → [1] 必须变红
#   3. 把同一行贴两遍                        → [3] 必须变红
#   4. 把 `src/contracts/QSkinAlert.qml` 挪进
#      foundation 块                          → [4] 必须变红
#   5. 删掉整块主题模块                      → [2] + [5] 必须变红
#   6. 删掉一行 `set_source_files_properties` → [6] 必须变红
#   7. 删掉一行 `# manifest-gate: alias`      → [8] 必须变红
#   8. 在 `CMakeLists.txt` 的**注释**里写一句 `qt_add_qml_module` 后跟一个
#      左括号                                    → **必须仍然绿**
#      （`parse_blocks` / `parse_singleton_decls` 是**全文**正则，它们不认
#        注释。没有 `blank_comments` 时，注释里提一次函数名就会被当成
#        第 7 个模块块，报"第 N 行没有 URI / 未识别 token"的**假红** ——
#        M32 实测撞过一次，修法见 `blank_comments`。）
#
# 第 1–7 枪已实测（脚本 `.cache/mutate_m28_manifest.py`，2026-09-16）；
# 第 8 枪由 M32 补上（同日 `ROADMAP.md` §7.1）。第 8 枪的实测方式：
#     把一句话塞进 `CMakeLists.txt` 的注释里 → 门禁退出码必须仍为 0；
#     同一句话塞进**代码位置**（真的多一个块）→ 必须变红（对照）。
#
# ⚠ 2026-09-16（M29 之后）：`manifest-gate: alias` 的**存量豁免已归零**
#   （别名改成单名注册，问题从根上消失了）→ **第 7 枪暂时没有靶子**，
#   真文件里现在量不出任何区别。那条判据本身仍然有效：将来谁再声明一条
#   豁免，它就会重新有对象。写成这一行而不是把那一枪删掉，是因为
#   「检查了 0 条」必须留痕 —— 否则下一个人会以为它一直在被验证。
#
# ── 退出码 ──────────────────────────────────────────────────────────────
#   0 = 清单与实际一致（含[8]的豁免账目已对齐）
#   1 = 有某条判据不过
#
# 用法：
#     ./tools/check-build-manifest.sh          # 结论 + 问题（每类最多 20 条）
#     ./tools/check-build-manifest.sh -v       # 不截断，并列出豁免账目
#
# 一般不用直接调 —— ./tools/lint.sh 末尾会自动带上这一步。
#############################################################################

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CMAKE_PATH = os.path.join(ROOT, "CMakeLists.txt")
SRC_PATH = os.path.join(ROOT, "src")

WANT_EXTS = (".qml", ".js")

# 块内的段落开关。出现在这里的是"段名"，不是路径。
SEGMENTS = ("QML_FILES", "RESOURCES", "DEPENDENCIES")

# 块内合法但不是路径的关键字。**这张表故意写窄**：多认一个关键字，
# 就少抓一处"清单里有我看不懂的东西"。[7] 的价值全在这张表够窄。
BLOCK_KEYWORDS = (
    "URI", "VERSION", "NO_PLUGIN", "NO_PLUGIN_OPTIONAL",
    "NO_CREATE_PLUGIN_TARGET", "NO_GENERATE_PLUGIN_SOURCE",
    "OUTPUT_DIRECTORY", "RESOURCE_PREFIX", "CLASS_NAME", "PLUGIN_TARGET",
    "STATIC", "SHARED", "OBJECT_LIBRARIES", "NO_RESOURCE_TARGET_PATH",
    "NO_LINT", "NO_CACHEGEN", "NO_REPLACE",
)

VERBOSE = "-v" in sys.argv
MAX_PER_KIND = 20

MODULE_RE = re.compile(r"^\s*module\s+(\S+)")
SINGLETON_RE = re.compile(r"^\s*singleton\s+\S+\s+\S+\s+(\S+)")

# qmldir 的普通条目：`<类型名> <版本> <文件>`，`singleton` 是可选前缀。
ENTRY_RE = re.compile(
    r"^\s*(?:singleton\s+)?([A-Za-z_][A-Za-z0-9_]*)\s+\d+\.\d+\s+(\S+\.qml)\s*$")

# 别名豁免：写在 CMakeLists 里的注释行，**整行只有这个记号**：
#     # manifest-gate: alias src/foundation/Row.qml
#
# ⚠ 为什么必须锚到"整行 + 路径形态"（M29 实测的教训，别改回去）：
#   原来只用 `EXEMPT_RE.search(line)`、且正则不锚行首，于是**散文里提到这个
#   记号**也会被当成一条豁免声明。M29 改造时在 CMakeLists 的说明段里写了
#   一句「这三条曾以 `# manifest-gate: alias <路径>` 的形式留在明处」——
#   闸立刻报：
#       过期豁免：<路径> 不在任何 qmldir 里，删掉这行
#   把一句说明读成了一条指向假路径的豁免。**闸本身没坏**（格式化正确、路径
#   确实不在任何 qmldir 里），坏的是判据分不清「声明」与「提及」。
#   同族的坑 M28 已经吃过一次：`grep -c 'manifest-gate: alias'` 数出 5 条，
#   而真豁免只有 3 条，多出来的两条正是散文。两次都是**用一句话数了两件
#   不同的事**。这次从"写文档时小心点"改成**结构上不可能**：
#     ① 必须整行只有记号（行首 `#` + 记号 + 行尾即止）；
#     ② 路径必须长得像路径（`.qml` / `.js` / `.qrc` 后缀）。
#   两条缺一不可 —— ① 挡掉行内提及，② 挡掉「整行但后面跟中文」那种形态。
EXEMPT_RE = re.compile(
    r"^\s*#\s*manifest-gate:\s*alias\s+(\S+\.(?:qml|js|qrc))\s*$")


# ══════════════════════════ 基础工具 ══════════════════════════════════════

def rel_posix(path):
    """统一成 `src/xxx/yyy.qml` 这种 POSIX 相对路径 —— 与 CMakeLists 里的写法一致。"""
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def read_text(path):
    f = open(path, "r", encoding="utf-8", errors="replace")
    try:
        return f.read()
    finally:
        f.close()


def strip_comment(line):
    """去掉 CMake / qmldir 的行注释。

    按字符走而不是用正则猜：`#` 可能出现在引号里（路径一般不会，但不值得赌），
    而"引号外的第一个 # 之后全是注释"这条规则本身是确定的。

    CMake 与 qmldir 恰好共用同一条注释规则，所以一个函数够用。
    """
    out = []
    in_quote = False
    for ch in line:
        if ch == '"':
            in_quote = not in_quote
            out.append(ch)
        elif ch == "#" and not in_quote:
            break
        else:
            out.append(ch)
    return "".join(out)


def blank_comments(text):
    """把每行 `#` 之后的注释字符换成**等长空格**，其余原样，行尾不动。

    ── 为什么需要它 ────────────────────────────────────────────────────
    `parse_blocks` / `parse_singleton_decls` 是对**全文**跑正则找块的，
    它们不认注释。于是"注释里提了一次函数名"就会被当成一个真块 ——
    M32 在 `CMakeLists.txt` 的版本说明里提了那个函数名，门禁立刻报
    「模块第 7 行没有 URI / 第 7 行出现未识别 token」的**假红**，
    而清单本身一个字都没错。

    这正是本项目的第 8 条老规矩：正则里凡是"任意词"的位置，都要问一句
    "它会不会把别的东西也吃进来"。这里吃进来的是注释。

    ── 为什么是"空格化"而不是"删掉" ─────────────────────────────────────
    调用方拿这个副本做完 `finditer` 之后，还要用 `m.start()` 走 `line_of()`
    归因行号、用 `take_balanced()` 按偏移取块。**长度一变，两者全错位。**
    所以必须等长替换（每个被吃掉的字符换成一个空格）。

    ⚠ 但 `# manifest-gate: alias <路径>` 那类**指令**就住在注释里 ——
      `parse_alias_exemptions` 必须继续读**原文**，别拿这个副本去扫。
    """
    out = []
    for line in text.split("\n"):
        kept = strip_comment(line)
        out.append(kept + " " * (len(line) - len(kept)))
    return "\n".join(out)


def take_balanced(text, pos):
    """从 `text[pos] == '('` 开始取括号平衡的块内容，返回 (inner, end_index)。

    引号内的括号不计数 —— `URI "QSkin.Foundation"` 本身不含括号，但赌不起。
    """
    if pos >= len(text) or text[pos] != "(":
        return None, pos
    depth = 0
    in_quote = False
    i = pos
    while i < len(text):
        ch = text[i]
        if in_quote:
            if ch == '"':
                in_quote = False
        elif ch == '"':
            in_quote = True
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return text[pos + 1:i], i
        i += 1
    return None, pos


def tokenize(text):
    """把块内容切成 token。引号串整体算一个 token（含引号）。

    先逐行去注释，再按空白切 —— 与 CMake 的实际行为一致（CMake 里
    换行与空格等价，注释以行计）。
    """
    parts = []
    for line in text.split("\n"):
        parts.append(strip_comment(line))
    body = "\n".join(parts)

    out = []
    i = 0
    n = len(body)
    while i < n:
        ch = body[i]
        if ch.isspace():
            i += 1
            continue
        if ch == '"':
            j = body.find('"', i + 1)
            if j < 0:
                j = n - 1
            out.append(body[i:j + 1])
            i = j + 1
            continue
        j = i
        while j < n and not body[j].isspace():
            j += 1
        out.append(body[i:j])
        i = j
    return out


def line_of(text, offset):
    return text.count("\n", 0, offset) + 1


# ══════════════════════════ 读 qmldir ═════════════════════════════════════
#
# qmldir 是**源码侧的模块定义**。这份数据不是"另一份清单"，而是闸用来判
# 归属、单例与别名的依据 —— 所以它能当裁判，不会被裁判。

def load_qmldirs():
    """返回 (records, problems)。records 按目录名排序。

    records[i] = {"dir": "src/foundation", "uri": "QSkin.Foundation",
                  "qmldir": "src/foundation/qmldir",
                  "singletons": ["src/foundation/Theme.qml", ...],
                  "names": {"src/foundation/Row.qml": ["Row", "QSkinRow"], ...}}
    """
    records = []
    problems = []
    for dirpath, dirnames, filenames in os.walk(SRC_PATH):
        if "qmldir" not in filenames:
            continue
        qml = os.path.join(dirpath, "qmldir")
        text = read_text(qml)
        uri = None
        sings = []
        names = {}
        for line in text.split("\n"):
            line = strip_comment(line)
            if not line.strip():
                continue
            m = MODULE_RE.match(line)
            if m and uri is None:
                uri = m.group(1)
                continue
            m = SINGLETON_RE.match(line)
            if m:
                sings.append(rel_posix(os.path.join(dirpath, m.group(1))))
                continue
            m = ENTRY_RE.match(line)
            if m:
                f = rel_posix(os.path.join(dirpath, m.group(2)))
                names.setdefault(f, []).append(m.group(1))
                continue
            problems.append("qmldir 里有不认识的条目（%s）：%s"
                            % (rel_posix(qml), line.strip()))
        if uri is None:
            problems.append("qmldir 里没有 `module` 行：%s" % rel_posix(qml))
        rec = {"dir": rel_posix(dirpath), "uri": uri,
               "qmldir": rel_posix(qml), "singletons": sings, "names": names}
        records.append(rec)
    records.sort(key=lambda r: r["dir"])
    return records, problems


def scan_src_files():
    """`src/` 下所有 .qml / .js，POSIX 相对路径，排序。"""
    out = []
    for dirpath, dirnames, filenames in os.walk(SRC_PATH):
        for fn in filenames:
            if fn.endswith(WANT_EXTS):
                out.append(rel_posix(os.path.join(dirpath, fn)))
    out.sort()
    return out


# ══════════════════════════ 解析 CMakeLists ═══════════════════════════════

def parse_blocks(text):
    """切出所有 `qt_add_qml_module(...)` 块并解析。返回 (blocks, problems)。"""
    blocks = []
    problems = []
    for m in re.finditer(r"\bqt_add_qml_module\s*\(", text):
        pos = m.end() - 1
        inner, end = take_balanced(text, pos)
        if inner is None:
            problems.append("第 %d 行的 qt_add_qml_module 括号不平衡"
                            % line_of(text, m.start()))
            continue
        blocks.append(parse_one_block(inner, line_of(text, m.start())))
    return blocks, problems


def parse_one_block(inner, lineno):
    toks = tokenize(inner)
    info = {"line": lineno, "target": None, "uri": None,
            "QML_FILES": [], "RESOURCES": [], "deps": [], "unknown": []}
    seg = None
    i = 0
    n = len(toks)
    if n:
        info["target"] = toks[0]      # 第一个 token 是 target 名
        i = 1
    while i < n:
        t = toks[i]

        # `URI "QSkin.Foundation"` —— 值在下一个 token 里
        if t == "URI":
            if i + 1 < n:
                v = toks[i + 1]
                if v.startswith('"') and v.endswith('"') and len(v) >= 2:
                    info["uri"] = v[1:-1]
                else:
                    info["unknown"].append("URI 的值不是引号串：%s" % v)
            i += 2
            continue

        # `VERSION 1.0`
        if t == "VERSION":
            i += 2
            continue

        if t in SEGMENTS:
            seg = t
            i += 1
            continue

        if t in BLOCK_KEYWORDS:
            seg = None
            i += 1
            continue

        if t.startswith("src/"):
            if seg in ("QML_FILES", "RESOURCES"):
                info[seg].append(t)
            else:
                info["unknown"].append(t)
            i += 1
            continue

        # DEPENDENCIES 段里是 target 名，不是路径 —— 合法
        if seg == "DEPENDENCIES":
            info["deps"].append(t)
            i += 1
            continue

        info["unknown"].append(t)
        i += 1
    return info


def parse_singleton_decls(text):
    """抽出 `set_source_files_properties(<paths> PROPERTIES QT_QML_SINGLETON_TYPE TRUE)`。

    返回 (declared:set, unknown:list)。一个调用可以声明多个文件。
    """
    declared = set()
    unknown = []
    for m in re.finditer(r"\bset_source_files_properties\s*\(", text):
        pos = m.end() - 1
        inner, end = take_balanced(text, pos)
        if inner is None:
            unknown.append("第 %d 行的 set_source_files_properties 括号不平衡"
                           % line_of(text, m.start()))
            continue
        toks = tokenize(inner)
        paths = []
        flag = False
        i = 0
        n = len(toks)
        while i < n:
            t = toks[i]
            if t.startswith("src/"):
                paths.append(t)
                i += 1
                continue
            if t == "QT_QML_SINGLETON_TYPE":
                if i + 1 < n and toks[i + 1] == "TRUE":
                    flag = True
                i += 2
                continue
            if t == "PROPERTIES":
                i += 1
                continue
            # 别的属性（比如将来的 QT_QML_SOURCE_TYPENAME）不拦，只记账
            unknown.append("set_source_files_properties 里的未识别 token：%s" % t)
            i += 1
        if flag:
            for p in paths:
                declared.add(p)
    return declared, unknown


def parse_alias_exemptions(text):
    """抽出 `# manifest-gate: alias <path>` 豁免声明。"""
    out = set()
    for line in text.split("\n"):
        m = EXEMPT_RE.search(line)
        if m:
            out.add(m.group(1))
    return out


# ══════════════════════════ 主逻辑 ════════════════════════════════════════

def module_of(rel, dir_to_uri):
    """一个文件属于哪个 URI —— 从它自己所在的目录往上找最近的 qmldir。"""
    d = os.path.dirname(rel)
    while d:
        if d in dir_to_uri:
            return dir_to_uri[d]
        nd = os.path.dirname(d)
        if nd == d:
            break
        d = nd
    return None


def main():
    if not os.path.isfile(CMAKE_PATH):
        sys.stdout.write("构建清单门禁：找不到 %s\n" % rel_posix(CMAKE_PATH))
        return 1

    cmake_text = read_text(CMAKE_PATH)
    # 结构扫描跑在「注释已空格化」的副本上 —— 见 `blank_comments` 的说明：
    # 那两个扫描器是全文正则，注释里提一次函数名（后面紧跟左括号）就会被
    # 当成一个真块，报出"第 N 行没有 URI"的假红（M32 实测撞过）。
    # ⚠ `parse_alias_exemptions` 必须继续读**原文** ——
    #   `# manifest-gate: alias <路径>` 这条指令本身就住在注释里。
    cmake_scan = blank_comments(cmake_text)
    records, qmldir_problems = load_qmldirs()
    src_files = scan_src_files()
    blocks, block_problems = parse_blocks(cmake_scan)
    singleton_decls, singleton_problems = parse_singleton_decls(cmake_scan)
    alias_exempt = parse_alias_exemptions(cmake_text)

    dir_to_uri = {}
    uri_to_record = {}
    name_map = {}
    for r in records:
        if r["uri"]:
            dir_to_uri[r["dir"]] = r["uri"]
            uri_to_record[r["uri"]] = r
        for f in r["names"]:
            name_map.setdefault(f, [])
            for nm in r["names"][f]:
                name_map[f].append(nm)

    # ── 清单侧的两张表 ───────────────────────────────────────────────────
    listed_from = {}        # 路径 → [(模块 URI, 段落, 行号)]
    for b in blocks:
        for seg in ("QML_FILES", "RESOURCES"):
            for p in b[seg]:
                listed_from.setdefault(p, []).append((b["uri"], seg, b["line"]))
    listed_all = sorted(listed_from.keys())

    # ── 判据 ─────────────────────────────────────────────────────────────
    P_DANGLING = []         # [1]
    P_MISSING = []          # [2]
    P_DUP = []              # [3]
    P_HOME = []             # [4]
    P_MODULE = []           # [5]
    P_SINGLETON = []        # [6]
    P_PARSE = []            # [7]
    P_ALIAS = []            # [8]

    # [1] 悬空
    for p in listed_all:
        if not os.path.isfile(os.path.join(ROOT, p)):
            where = listed_from[p][0]
            P_DANGLING.append("%s   ← 模块 %s 第 %d 行" % (p, where[0], where[2]))

    # [2] 漏列 + [4] 归属
    for rel in src_files:
        if rel not in listed_from:
            P_MISSING.append(rel)
            continue
        want_uri = module_of(rel, dir_to_uri)
        for uri, seg, lineno in listed_from[rel]:
            if want_uri is not None and uri != want_uri:
                P_HOME.append("%s   ← 列在模块 %s（应为 %s）第 %d 行"
                              % (rel, uri, want_uri, lineno))

    # [3] 重复
    for p in listed_all:
        if len(listed_from[p]) > 1:
            spots = []
            for uri, seg, lineno in listed_from[p]:
                spots.append("%s/%s@%d" % (uri, seg, lineno))
            P_DUP.append("%s   ← %d 处：%s"
                         % (p, len(listed_from[p]), "、".join(spots)))

    # [5] 模块 ↔ qmldir 双射
    block_uris = set()
    for b in blocks:
        if b["uri"] is None:
            P_MODULE.append("模块第 %d 行没有 URI" % b["line"])
            continue
        block_uris.add(b["uri"])
    for r in records:
        if r["uri"] and r["uri"] not in block_uris:
            P_MODULE.append("qmldir 声明了模块 %s（%s），但 CMakeLists 里没有对应块"
                            % (r["uri"], r["qmldir"]))
    for u in sorted(block_uris):
        if u not in uri_to_record:
            P_MODULE.append("CMakeLists 声明了模块 %s，但找不到声明它的 qmldir" % u)

    # [6] 单例保真
    for r in records:
        for s in r["singletons"]:
            if s not in singleton_decls:
                P_SINGLETON.append("%s   ← %s 里声明为 singleton，清单没有 "
                                   "QT_QML_SINGLETON_TYPE" % (s, r["qmldir"]))

    # [7] 解析
    for b in blocks:
        for t in b["unknown"]:
            P_PARSE.append("模块 %s 第 %d 行出现未识别 token：%s"
                           % (b["uri"] or b["target"], b["line"], t))
    for s in singleton_problems:
        P_PARSE.append(s)
    for s in block_problems:
        P_PARSE.append(s)
    for s in qmldir_problems:
        P_PARSE.append(s)

    # [8] 类型名别名：要么声明豁免，要么修掉；声明了却没这个必要 = 过期豁免
    alias_pairs = {}
    for rel in sorted(name_map.keys()):
        names = name_map[rel]
        if len(names) > 1:
            alias_pairs[rel] = names
            if rel not in alias_exempt:
                P_ALIAS.append("%s   ← qmldir 注册了 %d 个名字：%s（构建路径复现不了）"
                               % (rel, len(names), " / ".join(names)))
    for rel in sorted(alias_exempt):
        if rel not in name_map:
            P_ALIAS.append("过期豁免：%s 不在任何 qmldir 里，删掉这行" % rel)
        elif len(name_map[rel]) < 2:
            P_ALIAS.append("过期豁免：%s 只有 1 个类型名（%s），删掉这行"
                           % (rel, name_map[rel][0]))

    # ── 元判据：查了 0 条 = 没查 ─────────────────────────────────────────
    meta = []
    if not blocks:
        meta.append("CMakeLists 里抽到 0 个 qt_add_qml_module 块")
    if not src_files:
        meta.append("src/ 下扫到 0 个 .qml/.js")
    if not records:
        meta.append("src/ 下扫到 0 个 qmldir")
    if not listed_all:
        meta.append("清单里抽到 0 条路径")

    # ── 报告 ─────────────────────────────────────────────────────────────
    qml_n = 0
    js_n = 0
    for f in src_files:
        if f.endswith(".qml"):
            qml_n += 1
        else:
            js_n += 1

    sin_total = 0
    for r in records:
        sin_total += len(r["singletons"])

    lines = []
    lines.append("构建清单门禁（M28）")
    lines.append("─" * 60)
    lines.append("CMakeLists.txt ：%d 个模块 / 清单 %d 条路径"
                 % (len(blocks), len(listed_all)))
    lines.append("src/           ：%d 个文件（.qml %d · .js %d）"
                 % (len(src_files), qml_n, js_n))
    lines.append("qmldir         ：%d 个 / %d 个 singleton 声明"
                 % (len(records), sin_total))
    lines.append("─" * 60)

    kinds = [
        ("[1] 悬空（清单里有、文件不在）", P_DANGLING),
        ("[2] 漏列（文件在、清单里没有）", P_MISSING),
        ("[3] 重复（同一个文件列了多次）", P_DUP),
        ("[4] 归属（列进了别的模块）", P_HOME),
        ("[5] 模块（CMakeLists 与 qmldir 对不上）", P_MODULE),
        ("[6] 单例（构建产物会丢掉 singleton）", P_SINGLETON),
        ("[7] 解析（清单里有看不懂的东西）", P_PARSE),
        ("[8] 别名（构建路径复现不了，且没声明豁免）", P_ALIAS),
    ]
    if meta:
        kinds.insert(0, ("[0] 元判据（查了 0 条 = 没查）", meta))

    bad = 0
    for title, items in kinds:
        if not items:
            continue
        bad += len(items)
        lines.append("✗ %s  %d 处" % (title, len(items)))
        shown = items if VERBOSE else items[:MAX_PER_KIND]
        for it in shown:
            lines.append("    " + it)
        if not VERBOSE and len(items) > MAX_PER_KIND:
            lines.append("    …（还有 %d 处，用 -v 看全部）"
                         % (len(items) - MAX_PER_KIND))
        lines.append("")

    if bad == 0:
        lines.append("清单与实际一致 ✓")
        lines.append("（%d 个模块 / %d 条路径；%d 个单例全部保真）"
                     % (len(blocks), len(listed_all), sin_total))
    else:
        lines.append("构建清单门禁：红 —— 共 %d 处" % bad)

    # 豁免账目：绿的时候也报一行，但**不刷屏**（[8] 的欠账要一直在视野里，
    # 只是不该盖过真问题 —— 一条恒定的长报告会训练人无视报告）。
    if alias_pairs:
        if VERBOSE:
            lines.append("")
            lines.append("别名豁免账目（构建产物里不存在这些别名，消费者会崩）：")
            for rel in sorted(alias_pairs.keys()):
                mark = "已声明" if rel in alias_exempt else "**未声明**"
                lines.append("    %s  → %s   [%s]"
                             % (rel, " / ".join(alias_pairs[rel]), mark))
        else:
            declared = 0
            for rel in alias_pairs:
                if rel in alias_exempt:
                    declared += 1
            lines.append("别名豁免：%d 处（已记入 ROADMAP，M29 处理 ｜ -v 看明细）"
                         % declared)

    sys.stdout.write("\n".join(lines) + "\n")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
