#!/usr/bin/env python3
"""QSkin · 生成宿主对账用的「公开类型清单」。

SPDX-License-Identifier: MIT OR Apache-2.0

── 事实源是 `qmldir`，不是文件名 ─────────────────────────────────────────
宿主能 import 到什么，完全由 `qmldir` 决定。所以「这个库对外有多少个类型」
这个问题的答案在 qmldir 里，不在 `ls src/contracts` 里：

  · `src/contracts/` 下有 92 个 `QSkin*.qml`，但 `slots/` 子目录里的那些是
    **内部插槽**，不出现在 qmldir 里 ⇒ 它们不是公开类型（已知：文件数 ≠ 控件数）；
  · 反过来，qmldir 里声明的类型名可以和文件名不同（改名过）。

拿文件名当清单，会测到一堆宿主根本 import 不到的东西，也会漏掉改过名的。
所以这里只认 qmldir。

── 产出 ──────────────────────────────────────────────────────────────────
`tests/ContractManifest.qml` —— 一个 `pragma Singleton` 的 QtObject，把清单
以 JS 数组形式暴露给 QML 侧。场景 `tests/scene_host_parity.qml` 读它，逐个
`Qt.createQmlObject` 动态实例化。

⚠ 这个文件是**生成物**，别手改。它与 qmldir 的一致性由
`tools/check-contract-manifest.py` 守（漂移就红，配证伪器）。
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "ContractManifest.js")

# ── 为什么产出是 `.js` 而不是 `.qml` ──────────────────────────────────────
# 清单是**纯数据**：一串 (URI, 类型名) 对。它不需要 QML 对象、不需要绑定、
# 不需要实例化。做成 .qml 会撞上 QML 相对导入的类型解析规则（qmllint 实测
# 报 `CM.ContractManifest was not found`），而 .js 相对导入语法明确、
# 与 `src/foundation/*.js` 那一族同款。别为了"看着像 QML"多绕一层。

# 模块 URI -> (qmldir 相对路径, 在 manifest 里的组名)
MODULES = [
    ("QSkin.Foundation", "src/foundation/qmldir", "foundation"),
    ("QSkin.Contracts", "src/contracts/qmldir", "contracts"),
]
# 主题模块目录名 -> URI 段（与 tools/shot.sh 的映射保持一致）
THEME_URI = {"tdesign": "TDesign", "ant": "AntDesign", "arco": "ArcoDesign", "shadcn": "Shadcn"}

# ── 内部件名单：注册进 qmldir 只为同目录按名使用，不是给宿主用的控件 ──────
# 它们**能被 import 到**，但**不能裸实例化**（要么有 required property 需要
# delegate 上下文，要么要有宿主控件喂进来）。所以宿主对账对它们只要求
# 「类型可解析」，不要求「可裸实例化」。
#
# ⚠ 判据不能写成「不带 QSkin 前缀 = 内部件」：那在 contracts 成立，在
#   foundation 不成立 —— foundation 的 Heading / Body / Spacer / ButtonBar
#   都不带前缀，却是对外排版原子（有 smoke_buttonbar.qml 在测）。
#   所以这里用**显式名单**，并由 check-contract-manifest.py 守：
#   名单里的类型若从 qmldir 消失了，门要红（否则名单静默过期）。
INTERNAL_TYPES = {
    ("QSkin.Contracts", "TimeCell"): "QSkinTimePicker 的滚轮格子，有 required property（需 delegate 上下文）",
    ("QSkin.Contracts", "FloatPlate"): "QSkinBackTop / QSkinFloatButton 共用的浮球底板，要外部喂 control",
}

TYPE_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def parse_qmldir(path):
    """返回 (普通类型名列表, 单例名列表)。"""
    types, singles = [], []
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.split("#")[0].strip()
            if not line:
                continue
            tok = line.split()
            # singleton Name Version File.qml
            if tok[0] == "singleton" and len(tok) >= 4:
                singles.append(tok[1])
                continue
            # Name Version File.qml
            if len(tok) >= 3 and TYPE_RE.match(tok[0]):
                ver, fn = tok[1], tok[2]
                if ver.count(".") == 1 and ver.replace(".", "").isdigit() and fn.endswith(".qml"):
                    types.append(tok[0])
    return types, singles


def qml_str_list(items, indent="        "):
    if not items:
        return "[]"
    body = ",\n".join('%s"%s"' % (indent, x) for x in items)
    return "[\n%s\n    ]" % body


def main():
    check_only = "--check" in sys.argv

    groups = []
    for uri, rel, gname in MODULES:
        p = os.path.join(ROOT, rel.replace("/", os.sep))
        if not os.path.exists(p):
            print("工装错误：qmldir 不存在 -> %s" % p)
            return 8
        types, singles = parse_qmldir(p)
        groups.append((gname, uri, types, singles))

    themes = []
    tdir = os.path.join(ROOT, "src", "themes")
    for d in sorted(os.listdir(tdir)):
        p = os.path.join(tdir, d, "qmldir")
        if not os.path.exists(p):
            continue
        types, singles = parse_qmldir(p)
        uri = "QSkin.Theme.%s" % THEME_URI.get(d, d)
        themes.append((d, uri, types, singles))

    total_types = sum(len(g[2]) for g in groups) + sum(len(t[2]) for t in themes)
    total_single = sum(len(g[3]) for g in groups) + sum(len(t[3]) for t in themes)

    lines = []
    A = lines.append
    A(".pragma library")
    A("")
    A("/****************************************************************************")
    A(" * QSkin · Quick Design System — 公开类型清单（**生成物，勿手改**）")
    A(" *")
    A(" * SPDX-License-Identifier: MIT OR Apache-2.0")
    A(" *")
    A(" * 由 `tools/gen-contract-manifest.py` 从各模块的 `qmldir` 生成。")
    A(" * 一致性由 `tools/check-contract-manifest.py` 守（漂移即红）。")
    A(" *")
    A(" * 用途：`tests/scene_host_parity.qml` 在 C++ / PySide6 / qml 三种宿主下")
    A(" * 逐个 `Qt.createQmlObject` 实例化这里列的每一个类型，证明宿主真的能用。")
    A(" *")
    A(" * ⚠ 清单以 **qmldir** 为事实源，不是以文件名为事实源 —— 理由见生成器头。")
    A(" *   当前：普通类型 %d 个，单例 %d 个。" % (total_types, total_single))
    A(" ****************************************************************************/")
    A("")
    for gname, uri, types, singles in groups + [
        ("theme_" + re.sub(r"[^A-Za-z0-9]", "", d), uri, t, s) for d, uri, t, s in themes
    ]:
        A("/* %s —— %d 个普通类型 + %d 个单例 */" % (uri, len(types), len(singles)))
        A("var %sTypes = %s;" % (gname, qml_str_list(types, "    ")))
        A("var %sSingles = %s;" % (gname, qml_str_list(singles, "    ")))
        A("")
    # 场景真正遍历的是这两个「(URI, 类型名)」扁平数组：
    # 按 URI 分组暴露是给人看的，扁平对才是给机器跑的。
    all_groups = groups + [
        ("theme_" + re.sub(r"[^A-Za-z0-9]", "", d), uri, t, s) for d, uri, t, s in themes
    ]
    tpairs = [(uri, n) for _, uri, t, _ in all_groups for n in t]
    spairs = [(uri, n) for _, uri, _, s in all_groups for n in s]

    # 内部件名单必须与 qmldir 对得上：名单里某个类型若已从 qmldir 消失，
    # 说明要么它被删了（名单该更新）、要么它改了名（清单该重生成）。
    # 不查的话，名单会静默过期 —— 注释不会红，断言会。
    allset = set(tpairs)
    stale = sorted("%s::%s" % k for k in INTERNAL_TYPES if k not in allset)
    if stale:
        print("NG  内部件名单过期：以下已不在 qmldir 里 -> %s" % ", ".join(stale))
        print("    要么从 INTERNAL_TYPES 删掉，要么检查 qmldir")
        return 1

    ppairs = [p for p in tpairs if p not in INTERNAL_TYPES]
    ipairs = [p for p in tpairs if p in INTERNAL_TYPES]

    A("/* 全部（模块 URI, 类型名）对 —— L1a 判据：每一个都必须**可解析** */")
    A("var allTypePairs = [")
    A(",\n".join('    { uri: "%s", name: "%s" }' % (u, n) for u, n in tpairs))
    A("];")
    A("")
    A("/* 公开类型（排除内部件）—— L1b 判据：每一个都必须能**裸实例化** */")
    A("var publicTypePairs = [")
    A(",\n".join('    { uri: "%s", name: "%s" }' % (u, n) for u, n in ppairs))
    A("];")
    A("")
    A("/* 内部件 —— 只要求可解析，不要求可裸实例化。理由见生成器里的名单 */")
    A("var internalTypePairs = [")
    A(",\n".join('    { uri: "%s", name: "%s" }' % (u, n) for u, n in ipairs))
    A("];")
    A("")
    A("/* 全部（模块 URI, 单例名）对 */")
    A("var allSinglePairs = [")
    A(",\n".join('    { uri: "%s", name: "%s" }' % (u, n) for u, n in spairs))
    A("];")
    A("")
    A("/* 计数：场景会把它打进 stdout，对账脚本据此判断「清单有没有被截断」 */")
    A("var typeCount = %d;" % len(tpairs))
    A("var publicTypeCount = %d;" % len(ppairs))
    A("var internalTypeCount = %d;" % len(ipairs))
    A("var singleCount = %d;" % len(spairs))

    txt = "\n".join(lines) + "\n"

    # ── --check：不写文件，只与现有生成物比对 ────────────────────────────
    # 这道闸防的是**清单漂移**：qmldir 加了新类型却没重跑生成器，于是宿主
    # 对账"全绿"地少测了东西。生成物与源码脱节是静默的，必须有人喊。
    if check_only:
        if not os.path.exists(OUT):
            print("NG  生成物不存在 -> %s（跑一次不带 --check 的命令）" % OUT)
            return 1
        cur = open(OUT, encoding="utf-8").read()
        if cur == txt:
            print("OK  清单与 qmldir 一致（普通类型 %d / 单例 %d）"
                  % (len(tpairs), len(spairs)))
            return 0
        import difflib
        d = list(difflib.unified_diff(cur.splitlines(), txt.splitlines(),
                                      "现有", "应由 qmldir 生成", lineterm="", n=1))
        print("NG  清单已漂移（qmldir 变过，生成物没跟上）")
        print("    修法：python tools/gen-contract-manifest.py")
        for ln in d[:40]:
            print("    " + ln)
        return 1

    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(txt)

    print("已生成 %s" % os.path.relpath(OUT, ROOT))
    print("  普通类型 %d（公开 %d / 内部件 %d）  单例 %d  合计 %d"
          % (total_types, len(ppairs), len(ipairs), total_single,
             total_types + total_single))
    for gname, uri, types, singles in groups:
        print("    %-22s 类型 %3d  单例 %d" % (uri, len(types), len(singles)))
    for d, uri, types, singles in themes:
        print("    %-22s 类型 %3d  单例 %d" % (uri, len(types), len(singles)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
