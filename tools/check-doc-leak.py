#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""发布面泄露门禁 —— 挡住「本机痕迹」流进会随发行版发布的文档。

## 它守的是什么

`README.md` / `COVERAGE.md` / `CHANGELOG.md` / `docs/PITFALLS.md` /
`docs/GITHUB.md` 会随发行版发布。它们的读者是**外部用户**，看不到开发机上任何东西。
所以下面三类内容**在发布面里一律没有意义**，而且第二类还会变成一批**悬空引用**
（那些文件被 `.gitignore` 排除，新克隆的仓库里一个都没有）：

- **判据 1 · 本机路径与个人标识** —— `C:\\...` / `/Users/<你>` / `AppData` / `.workbuddy` / 用户名。
  这条是**真泄露**：路径里往往带用户名，甚至暴露出项目目录之外的结构。
- **判据 2 · 本机一次性件名** —— `_verify_*` / `_probe_*` / `_gen_*` / `_diag*` /
  `mutate_*` / `shot_m<n>*`。它们是开发机上的一次性脚本与抓图入口。
- **判据 3 · 本机工具链路径细节** —— `mingw_64` / 带版本号的 `.qt/<x.y>`。
  （只查**路径**，不查工具名 —— `aqtinstall` 那类理由见 `build_patterns()` 里的注释。）
- **判据 4 · 指向「不发布文档」的引用** —— `ROADMAP.md` / `docs/PROGRESS.md`。
  它们被 `.gitignore` 排除 ⇛ **发行版里根本不存在**这个文件，发布面里写
  「理由见 `ROADMAP.md` §8.7」对读者就是一条**死路**。
  （M34 补的：前三道判据只管"有没有泄露本机痕迹"，管不到"指向的目标存不存在"。
  2026-09-17 全仓审计实测到 13 处，分布在四份发布面文档里 —— 而门禁此前全绿。）

**`.cache/` 这个目录名本身不算违规** —— 它是仓库的一部分（由 `tools/clean-cache.sh`
管理，README 的目录结构里也写了）。违规的是**枚举它里面的件**，所以判据 2 只认件名。

## 为什么门禁自己不带用户名

用户名是**动态取**的（`getpass.getuser()` + `~` 的 basename），不写死在源码里 ——
`tools/` 也会随仓库发布，把用户名写进来等于门禁自己泄露一次。

## 盘符规则为什么要加前置否定

裸写 `[A-Za-z]:[\\/]` 会把 `https://…` 和 `qrc:/save.svg` 都吃进来
（`s:/`、`c:/` 恰好命中）—— 本仓已经因为这条误报过一次。
改成 `(?<![A-Za-z0-9])[A-Za-z]:[\\/]`：前面那个字母不能是字母数字，
于是 `https:` 的 `s`、`qrc:` 的 `c` 都被排除，只有真的写在行首 / 空白 / 括号后的
`C:\\` `D:/` 才命中。

## 豁免表

`tools/doc-leak-exempt.txt`：`<组>\t<相对路径>\t<归一化行指纹>`（`norm` = 去首尾空白 +
内部连续空白压成一个空格）。**只减不增**，与判据**双向对账**：
豁免了却没命中 = **该销账了**，同样判红。用**行指纹**而不是行号 —— 行号会漂。

## 退出码（位掩码，沿用本仓约定）

`1` 判据 1 ／ `2` 判据 2 ／ `4` 判据 3 ／ `8` 工装（缺发布文档、豁免表格式坏、
`.gitignore` 与判据 4 的名单对不上）／ **`16` 判据 4**。
`0` = 全过。

⚠ **缺发布文档 ≠ 跳过**：那是"判据的输入没了"，报**工装错误**，不报通过。

⚠ **判据 4 的名单必须与 `.gitignore` 对账**：它写的是"哪些文档不发布"这个事实。
两边对不上（比如有人把 `ROADMAP.md` 从 `.gitignore` 里删了，却没改这里的名单）
会让这道门**守着一个过期的目标** —— 所以 `main()` 里有一条断言，对不上就报工装错误
（本仓规矩：**注释不会红，断言会**）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 会随发行版发布的文档（.gitignore 里没被排除的那批）
#
# ⚠ `docs/GITHUB.md` 也在其中：它是**建仓素材**（description / README 首屏 /
# topics / release 模板），会被外部读者当发布面读。它的读数与 README 同源，
# 漏扫它就等于留了一份不受门禁管的发布面文档 —— 口径必然漂。
DEFAULT_DOCS = ["README.md", "COVERAGE.md", "CHANGELOG.md",
                os.path.join("docs", "PITFALLS.md"),
                os.path.join("docs", "GITHUB.md")]

EXEMPT = os.path.join(ROOT, "tools", "doc-leak-exempt.txt")

# ── 判据 4 的靶子：不随发行版发布的开发过程文档 ────────────────────────
# ⚠ 必须与 `.gitignore` 一致（main() 里有对账断言）。
NONPUB_DOCS = ["ROADMAP.md", os.path.join("docs", "PROGRESS.md")]

LABEL = {"1": "本机路径与个人标识", "2": "本机一次性件名",
         "3": "本机工具链细节", "4": "指向不发布文档的引用"}
BIT = {"1": 1, "2": 2, "3": 4, "4": 16}


def user_names():
    """动态取用户名 —— 不写死在源码里（见文件头）。"""
    names = set()
    try:
        import getpass
        names.add(getpass.getuser())
    except Exception:
        pass
    try:
        names.add(os.path.basename(os.path.expanduser("~")))
    except Exception:
        pass
    # 太短的（`adm` 之类）会到处误报；门禁误报一次就没人信它了
    return set(n for n in names if n and len(n) >= 4)


def build_patterns():
    pats = [
        # ── 判据 1：本机路径与个人标识 ──────────────────────────────
        ("1", re.compile(r"(?<![A-Za-z0-9])[A-Za-z]:[\\/]")),   # 盘符（见文件头）
        ("1", re.compile(r"/c/Users/", re.I)),
        ("1", re.compile(r"AppData", re.I)),
        ("1", re.compile(r"\.workbuddy", re.I)),
        ("1", re.compile(r"/Users/[A-Za-z0-9_.-]+/")),
        # ⚠ **故意不查 UNC 形态**（`\\\\host\\share`）。它与"JSON 里转义的
        #    **仓库内相对路径**"（`"...\\src\\contracts\\X.qml"`）在正则上**无法区分**，
        #    而后者在本仓真实存在（`docs/PITFALLS.md` 就有一条）。
        #    按本仓那条规矩：**假阳性比假阴性贵** —— 宁可漏报 UNC，也不制造误报。
        # ── 判据 2：本机一次性件名 ─────────────────────────────────
        ("2", re.compile(r"_verify_[A-Za-z0-9_]+")),
        ("2", re.compile(r"_probe_[A-Za-z0-9_]+")),
        ("2", re.compile(r"_gen_[A-Za-z0-9_]+")),
        ("2", re.compile(r"_diag[A-Za-z0-9_]*")),
        ("2", re.compile(r"mutate_[a-z0-9_]+")),
        ("2", re.compile(r"shot_m[0-9][A-Za-z0-9_.]*")),
        # ── 判据 3：本机**工具链路径**细节 ──────────────────────────
        #    ⚠ 只查**路径**，不查工具名。`aqtinstall.log` 是安装脚本写在
        #    仓库根目录的日志（已在 `.gitignore` 里），它出现在一条真实教训里
        #    （glob 被 shell 提前展开），**不是本机路径、不构成泄露** ——
        #    把它算进来是误报，而误报会让这道门被绕过。
        ("3", re.compile(r"mingw[_-]?64", re.I)),
        ("3", re.compile(r"\.qt[/\\][0-9]+\.[0-9]+")),
        # ── 判据 4：指向不发布文档的引用 ────────────────────────────
        #    只认**文件名**，不认裸的 "ROADMAP" / "PROGRESS" —— 正文里用它
        #    们指代"排期文档"这类角色是常事，把角色名算进来是误报。
    ]
    for _rel in NONPUB_DOCS:
        _name = os.path.basename(_rel)
        pats.append(("4", re.compile(re.escape(_name))))
    # 用户名按**大小写敏感**匹配（用户名本身是大小写敏感的）
    for n in sorted(user_names()):
        pats.append(("1", re.compile(re.escape(n))))
    return pats


def gitignore_mismatch(src):
    """判据 4 的名单 ↔ .gitignore 对账 —— 返回不一致的说明列表（空 = 一致）。

    为什么要有这条：`NONPUB_DOCS` 写的是"哪些文档不发布"这个**事实**，
    而事实的另一半写在 `.gitignore` 里。两边一旦分叉，这道门就会去守一个
    过期的目标（比如 `ROADMAP.md` 已经进仓库了，门还在把它当悬空引用报）。
    ⚠ 缺 `.gitignore` 也算不一致 —— 那是"判据的输入没了"，按工装错误报。
    """
    gi = os.path.join(src, ".gitignore")
    if not os.path.exists(gi):
        return ["找不到 .gitignore —— 判据 4 的名单无从对账（判据的输入没了）"]
    ent = set()
    for ln in io.open(gi, encoding="utf-8").read().split("\n"):
        s = ln.strip().lstrip("/")
        if s:
            ent.add(s)
    out = []
    for rel in NONPUB_DOCS:
        u = rel.replace("\\", "/")
        if u not in ent:
            out.append("NONPUB_DOCS 里的 %s 没被 .gitignore 排除 —— "
                       "它其实会发布出去，不该再当悬空引用查" % u)
    return out


def norm(line):
    return " ".join(line.split())


def load_exempt(path):
    """返回 ({(组, 相对路径, 指纹)}, 格式错误列表)。"""
    ent, bad = set(), []
    if not os.path.exists(path):
        return ent, bad
    for i, ln in enumerate(io.open(path, encoding="utf-8").read().split("\n"), 1):
        if not ln.strip() or ln.lstrip().startswith("#"):
            continue
        parts = ln.split("\t")
        if len(parts) != 3 or parts[0] not in ("1", "2", "3", "4"):
            bad.append("%s:%d 格式应为 <组 1|2|3>TAB<相对路径>TAB<归一化行指纹>" % (path, i))
            continue
        ent.add((parts[0], parts[1].replace("\\", "/"), parts[2]))
    return ent, bad


def main(argv):
    docs, exempt_path, src = DEFAULT_DOCS, EXEMPT, ROOT
    i = 1
    while i < len(argv):
        a = argv[i]
        if a == "--docs":
            i += 1
            docs = [x for x in argv[i].split(",") if x]
        elif a == "--exempt":
            i += 1
            exempt_path = argv[i]
        elif a == "--src":
            i += 1
            src = argv[i]
        i += 1

    print("=" * 74)
    print("发布面泄露门禁")
    print("扫描面：" + ", ".join(docs))
    print("=" * 74)

    exempt, bad_fmt = load_exempt(exempt_path)
    code = 0
    if bad_fmt:
        code |= 8
        print("")
        for b in bad_fmt:
            print("工装错误：" + b)

    # ── 判据 4 的名单 ↔ .gitignore 对账（注释不会红，断言会）──────────
    for miss in gitignore_mismatch(src):
        code |= 8
        print("工装错误：" + miss)

    pats = build_patterns()
    used_exempt = set()
    hits = {"1": [], "2": [], "3": [], "4": []}
    scanned = 0

    for rel in docs:
        p = os.path.join(src, rel)
        if not os.path.exists(p):
            code |= 8
            print("工装错误：发布文档不存在 —— " + rel)
            continue
        scanned += 1
        raw = io.open(p, "rb").read().decode("utf-8", "replace")
        for no, ln in enumerate(raw.split("\n"), 1):
            for grp, rx in pats:
                m = rx.search(ln)
                if not m:
                    continue
                key = (grp, rel.replace("\\", "/"), norm(ln))
                if key in exempt:
                    used_exempt.add(key)
                else:
                    hits[grp].append((rel, no, m.group(0), ln.strip()[:96]))
                break

    print("")
    print("扫描 %d 个文档 ／ 豁免表 %d 条" % (scanned, len(exempt)))

    for grp in ("1", "2", "3", "4"):
        h = hits[grp]
        print("")
        if h:
            code |= BIT[grp]
            print("判据 %s 失败：%s —— %d 处" % (grp, LABEL[grp], len(h)))
            for rel, no, tok, text in h[:25]:
                print("   %s:%d  [%s]  %s" % (rel, no, tok, text))
            if len(h) > 25:
                print("   …（另有 %d 处）" % (len(h) - 25))
        else:
            print("判据 %s 通过：无%s" % (grp, LABEL[grp]))

    print("")
    stale = sorted(exempt - used_exempt)
    if stale:
        by = {}
        for grp, rel, fp in stale:
            by.setdefault(grp, []).append((rel, fp))
        for grp in sorted(by):
            code |= BIT[grp]
            print("判据 %s 失败：豁免表有 %d 条**该销账**（条目在，命中不在）"
                  % (grp, len(by[grp])))
            for rel, fp in by[grp][:10]:
                print("   %s  %s" % (rel, fp[:80]))
    else:
        print("豁免表双向对账一致（无该销账、无漂移）")

    print("")
    if code == 0:
        print("OK  发布面泄露：四道判据全过（位掩码 0x00）")
    else:
        print("FAIL 位掩码 0x%02X" % code)
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
