#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#############################################################################
# QSkin · 令牌名门禁（M25.1 起）
#
# 规则：`Theme.<组>.<名>` 的 `<名>` 必须真的存在。
#
# ── 为什么 qmllint 抓不到 ────────────────────────────────────────────────
# `Theme.color` 在 Theme.qml 里声明成 `property var` —— 令牌集合是个可被
# `Theme.install()` 整体替换的 JS 对象，静态类型系统拿不到成员表。于是
# 写错的令牌名**既不是语法错、也不是成员错**：它只是 `undefined`，表现为
# "那一块东西不见了 / 那根线不画了"，而 lint 依然退出 0。
#
# 这正是 M18 那次事故的形状：tdesign 主题上 divider / 分栏栏杆 / 滚动条
# 整屏不可见，而属性断言一片绿。那次令牌**名**是对的、值不对；这道闸查的
# 是名字 —— 同一类静默失效的另一半。
#
# ── 三条规则 ────────────────────────────────────────────────────────────
#   [A] 地基侧（src/contracts、src/foundation、examples、tests）读到的令牌
#       必须定义在 `src/foundation/tokens/neutral.js` 里。
#
#   [B] 主题侧（src/themes/<t>/slots/*.qml）读到的令牌必须定义在
#       `neutral.js ∪ 该主题自己的 tokens.js` 里。主题**允许**扩展令牌
#       （focusHalo / fillHover / fillActive 就是这么来的），但不允许读一个
#       连自己都没定义的 —— 那在该主题下就是 undefined。
#
#   [C] 主题 tokens.js 里不在 neutral 表内的键（= 扩展键）必须有归宿：
#       要么至少被读到一处，要么该行注释里显式写了 `token-gate: extend`。
#
#       为什么允许"显式声明"这条后门：tdesign 的 `space.size6/20/28` 与
#       `radius.xxl` 是**有意保留**的 —— `--td-size-3/7/9` 与
#       `--td-radius-extraLarge` 在地基刻度里没有对应档，留着是为了对着官方
#       刻度表可核验。一条在静止状态下就是红的闸会被无视，然后就成了死闸；
#       所以这里要的是"**决定必须写在源文件里**"，而不是把闸改成警告。
#
#   [D] 每个主题 tokens.js 的 **dark 段必须覆盖 light 段的全部键**。
#
#       这条是 2026-10-03 补的，补它的是一个**真缺陷**而不是假想：那天
#       人工开窗口跑 HelloQSkin，日志里出现
#         ACButtonBackground.qml:51:5: Unable to assign [undefined] to QColor
#       根因是 arco 的 `fillHover` / `fillActive` **只在 light 段有**，
#       而槽代码在「灰色实心按钮 hover / 按下」两条分支上读它们 ——
#       深色下拿到 undefined，Rectangle **这一帧没有底色**（不是回退成
#       别的色，是不画）。
#
#       为什么 [A]/[B]/[C] 三条都没抓到：它们查的都是 light ∪ dark 的
#       **合并集合**，而"dark 缺键"在合并结果里根本不存在。parse_tokens()
#       早期版本用 `out.setdefault(group, {})` 把两段并进同一个组，于是
#       这个缝隙是**结构性看不见**的 —— 现在它按模式分开解析（by_mode）。
#
# ── 怎么证伪这道闸 ──────────────────────────────────────────────────────
#   1. 在任一契约文件里写 `color: Theme.color.bgElvated` → [A] 必须变红
#   2. 在 tdesign 的 slots 里读一个只有 ant 定义的令牌 → [B] 必须变红
#   3. 去掉 tdesign tokens.js 里那四行的 `token-gate: extend` → [C] 必须变红
#   4. 删掉任一主题 dark 段里的任一 color 键 → [D] 必须变红
#
# 用法：
#     ./tools/check-tokens.sh            # 默认就扫全部（本闸不看参数）
#
# 一般不用直接调 —— ./tools/lint.sh 末尾会自动带上这一步。
#############################################################################

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

NEUTRAL = os.path.join(ROOT, "src", "foundation", "tokens", "neutral.js")
THEMES = ["ant", "arco", "shadcn", "tdesign"]
GROUPS = ("color", "space", "radius", "font", "size", "motion")
SCAN_DIRS = ["src", "examples", "tests"]

EXTEND_MARK = "token-gate: extend"


# ══════════════════════ 注释剥离（按字符走，不按正则猜） ══════════════════
#
# 为什么不用正则：`//` 出现在字符串里（"http://…"）会被截断，而
# `Theme.color.xxx` 出现在注释里会被当成真访问 —— tests/smoke_m18_theme.qml
# 里就有一处（那句注释在解释"从 JS 来的令牌是字符串，需要显式转 color"）。
# 剥离时字节保留、注释换成空格，行号列号都不动。

def strip_comments(text):
    out = []
    i = 0
    n = len(text)
    quote = None
    while i < n:
        ch = text[i]
        if quote is not None:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch == '"' or ch == "'":
            quote = ch
            out.append(ch)
            i += 1
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append("".join(" " if c != "\n" else "\n" for c in text[i:j]))
            i = j
            continue
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
            continue
        out.append(ch)
        i += 1
    return "".join(out)


# ══════════════════════ 令牌文件解析 ══════════════════════
#
# 只认显式给出的块：组行是 4 空格缩进的 `name: {`，键行是 8 空格缩进的
# `key:`。neutral + 四家主题的格式完全一致，按缩进切比引一个 JS 解析器省事。
#
# ⚠ 组的收尾**可能是 `}` 而不是 `},`** —— JS 对象的最后一个成员不带逗号。
#   第一版把收尾正则写成 `^ {4}\},$`，于是每个文件里最后一个组一直开着，
#   把后面整个 dark 块的键全吞进那个组（报出 `size.bg`、`space.size20`
#   这类明显不可能的名字，139 处噪声）。收尾正则必须容忍缺逗号。
#
# 别名组（neutral 深色里的 `space: light.space,`）刻意不解析 —— 它指向
# light 的同名组，重复记一遍不会多出任何键。

GROUP_OPEN = re.compile(r"^ {4}([A-Za-z_]\w*):\s*\{\s*$")
GROUP_CLOSE = re.compile(r"^ {4}\},?\s*$")
TOP_LEVEL = re.compile(r"^var\s+\w+\s*=\s*\{")
KEY_LINE = re.compile(r"^ {8}([A-Za-z_]\w*):")


def parse_tokens(path, by_mode=False):
    """→ {组名: {键名: 原始行}}；只含显式给出的组，不含别名组。

    返回原始行是为了规则 [C] 能读到 `token-gate: extend` —— 那个标记住在
    注释里，而注释已经被剥掉了。

    ⚠ `by_mode=True` 时改为返回 {模式名: {组名: {键名: 原始行}}}，规则
      [D] 要用它核对 light / dark 两段的对称性。

      为什么必须分开：默认形态把两段**合并进同一个组**（`out.setdefault`
      只在第一次建组），于是「dark 缺某个键」在合并结果里根本看不见 ——
      这正是 2026-10-03 那个坑逃过全部三道令牌规则的原因：arco 的
      `fillHover` / `fillActive` 只在 light 段有，dark 段缺，而 [A]/[B]/[C]
      查的都是合并后的集合，全都判它「有定义」。
    """
    raw = open(path, encoding="utf-8", newline="").read()
    lines_raw = raw.split("\n")
    lines = strip_comments(raw).split("\n")
    out = {}
    group = None
    mode = None
    for idx, ln in enumerate(lines):
        if TOP_LEVEL.match(ln):              # 新的 var light / var dark 块
            m = re.match(r"^var\s+(\w+)\s*=", ln)
            mode = m.group(1) if m else None
            group = None
            if by_mode and mode:
                out.setdefault(mode, {})
            continue
        if group is None:
            m = GROUP_OPEN.match(ln)
            if m:
                group = m.group(1)
                if by_mode and mode:
                    out.setdefault(mode, {}).setdefault(group, {})
                else:
                    out.setdefault(group, {})
            continue
        if GROUP_CLOSE.match(ln):
            group = None
            continue
        m = KEY_LINE.match(ln)
        if m:
            tgt = out[mode][group] if (by_mode and mode) else out[group]
            tgt[m.group(1)] = lines_raw[idx]
    return out


# ══════════════════════ 访问侧扫描 ══════════════════════

ACCESS = re.compile(r"\bTheme\.(color|space|radius|font|size|motion)\.([A-Za-z_]\w*)")


def scan_accesses():
    """→ [(相对路径, 行号, 组, 名)]；注释里的不算"""
    hits = []
    for d in SCAN_DIRS:
        for dirpath, _dirnames, filenames in os.walk(os.path.join(ROOT, d)):
            for fn in sorted(filenames):
                if not fn.endswith((".qml", ".js")):
                    continue
                full = os.path.join(dirpath, fn)
                rel = os.path.relpath(full, ROOT).replace("\\", "/")
                text = strip_comments(open(full, encoding="utf-8", newline="").read())
                for i, ln in enumerate(text.split("\n"), 1):
                    for m in ACCESS.finditer(ln):
                        hits.append((rel, i, m.group(1), m.group(2)))
    return hits


def theme_of(rel):
    """→ 主题名；不是主题文件就是 None"""
    parts = rel.split("/")
    if len(parts) >= 3 and parts[0] == "src" and parts[1] == "themes" \
            and parts[2] in THEMES:
        return parts[2]
    return None


def main():
    neutral = parse_tokens(NEUTRAL)
    if sorted(neutral.keys()) != sorted(GROUPS):
        print("✗ neutral.js 解析出 %d 组（应为 %d）—— 解析器坏了，"
              "下面的结论全部不可信" % (len(neutral), len(GROUPS)))
        return 1

    print("== 令牌表：neutral 6 组，共 %d 个"
          % sum(len(v) for v in neutral.values()))
    for g in GROUPS:
        print("   %-7s %3d" % (g, len(neutral[g])))

    theme_tokens = {}
    for t in THEMES:
        theme_tokens[t] = parse_tokens(
            os.path.join(ROOT, "src", "themes", t, "tokens.js"))

    hits = scan_accesses()
    bad = 0

    # ── [A] 地基侧 ──
    base_hits = [h for h in hits if theme_of(h[0]) is None]
    base_bad = [h for h in base_hits if h[3] not in neutral.get(h[2], ())]
    print("\n== [A] 地基侧：%d 处访问，必须全部在 neutral 表内" % len(base_hits))
    if base_bad:
        bad += len(base_bad)
        for rel, ln, grp, name in base_bad:
            print("   ✗ %s:%d  Theme.%s.%s —— neutral 里没有" % (rel, ln, grp, name))
    else:
        print("   ✓ 全部命中")

    # ── [B] 主题侧 ──
    print("\n== [B] 主题侧：必须落在 neutral ∪ 该主题自己的 tokens.js")
    for t in THEMES:
        allowed = {g: set(neutral.get(g, ())) for g in GROUPS}
        for g, keys in theme_tokens[t].items():
            allowed.setdefault(g, set()).update(keys.keys())
        t_hits = [h for h in hits if theme_of(h[0]) == t]
        t_bad = [h for h in t_hits if h[3] not in allowed.get(h[2], ())]
        if t_bad:
            bad += len(t_bad)
            for rel, ln, grp, name in t_bad:
                print("   ✗ %s:%d  Theme.%s.%s —— 本主题与 neutral 都没定义"
                      % (rel, ln, grp, name))
        else:
            print("   ✓ %-8s %3d 处访问全部有定义" % (t, len(t_hits)))

    # ── [C] 扩展键的归宿 ──
    print("\n== [C] 主题扩展令牌：要么被读到，要么标 `%s`" % EXTEND_MARK)
    read_names = {}
    for _rel, _ln, grp, name in hits:
        read_names.setdefault(grp, set()).add(name)

    for t in THEMES:
        declared, unread, marked = [], [], []
        for g, keys in sorted(theme_tokens[t].items()):
            if g not in GROUPS:
                bad += 1
                print("   ✗ %s: 组 `%s` 不在六组里" % (t, g))
                continue
            for k, raw in sorted(keys.items()):
                if k in neutral.get(g, ()):
                    continue
                declared.append("%s.%s" % (g, k))
                if k in read_names.get(g, set()):
                    continue
                if EXTEND_MARK in raw:
                    marked.append("%s.%s" % (g, k))
                else:
                    unread.append("%s.%s" % (g, k))
        if unread:
            bad += len(unread)
            for name in unread:
                print("   ✗ %s: %s —— 定义了、没人读、也没标 `%s`"
                      % (t, name, EXTEND_MARK))
        else:
            print("   ✓ %-8s 扩展键 %d 个%s%s"
                  % (t, len(declared),
                     ("（其中 %d 个标为有意保留：%s）" % (len(marked), ", ".join(marked)))
                     if marked else "",
                     "" if declared else "（无扩展）"))

    # ── [D] light / dark 两段的对称性 ──
    #
    # 载荷**必须逐字相同** —— 所以「要在 dark 段重新推导一个值」这种做法
    # 在这道闸下是**过不去**的，只能改槽代码。这是有意的：载荷是设计
    # 决策，两段各写一遍就变成两份会漂的副本。
    print("\n== [D] light / dark 对称性：dark 段的 color 必须覆盖 light 的每一个键"
          "（载荷不同是设计，不红）")
    for t in THEMES:
        by_mode = parse_tokens(
            os.path.join(ROOT, "src", "themes", t, "tokens.js"), by_mode=True)
        if "light" not in by_mode or "dark" not in by_mode:
            print("   ✗ %-8s 解析不出 light/dark 两段（读到 %s）—— 解析器坏了，"
                  "这一段的结论不可信" % (t, sorted(by_mode)))
            bad += 1
            continue
        L, D = by_mode["light"], by_mode["dark"]
        # 除 color 外的五组在 dark 段是**别名组**（`font: light.font,`）——
        # 整组指向 light 的同名对象，深色下读到的就是 light 那一份值。
        # 所以只有 color 组需要"dark 覆盖 light"的对称性要求；拿别名组
        # 去比缺键会报出 152 条假红（第一版就栽在这：SKIP 只挡住了载荷
        # 比对，忘了同样要挡缺键比对）。
        #
        # 颜色**不能**这样省：深色下的语义色本来就与浅色不同（bg #17171A
        # vs #FFFFFF），别名会把浅色值直接搬到深色画布上 —— 那不是省事，
        # 是错色。所以 color 必须在两段都显式写全。
        NEEDS_EXPLICIT = ("color",)
        only_l = {g: sorted(set(L.get(g, {})) - set(D.get(g, {})))
                  for g in NEEDS_EXPLICIT}
        only_d = {g: sorted(set(D.get(g, {})) - set(L.get(g, {})))
                  for g in NEEDS_EXPLICIT}
        only_l = {g: v for g, v in only_l.items() if v}
        only_d = {g: v for g, v in only_d.items() if v}
        payload_diff = []
        same_payload = []
        for g in GROUPS:
            if g not in NEEDS_EXPLICIT:
                continue
            for k in sorted(set(L.get(g, {})) & set(D.get(g, {}))):
                # 载荷比较**保留注释**（要判的是"两段是不是同一个值"，
                # 注释不同不影响），但要去掉行尾空白与逗号。
                a = L[g][k].strip().rstrip(",").strip()
                b = D[g][k].strip().rstrip(",").strip()
                if a != b:
                    payload_diff.append((g, k))
                else:
                    same_payload.append((g, k, a))
        if not only_l and not only_d and not same_payload:
            print("   ✓ %-8s color 两段对称（%d 键，%d 键载荷按设计不同）"
                  % (t, len(L.get("color", {})), len(payload_diff)))
            continue
        for g, v in sorted(only_l.items()):
            for k in v:
                bad += 1
                print("   ✗ %s: %s.%s —— light 有、**dark 缺**（深色下读到 "
                      "undefined，颜色直接不画）" % (t, g, k))
        for g, v in sorted(only_d.items()):
            for k in v:
                print("   · %s: %s.%s dark 有、light 无 —— 只记不红（深色加键是允许的）"
                      % (t, g, k))
        for g, k, v in same_payload:
            print("   · %s: %s.%s 两段字面量**完全相同**（%s）—— 深浅同色，"
                  "确认是刻意的吗" % (t, g, k, v))

    print()
    if bad:
        print("✗ 令牌名门禁：%d 处不合格" % bad)
        return 1
    print("✓ 令牌名门禁通过")
    return 0

if __name__ == "__main__":
    sys.exit(main())
