#!/usr/bin/env python3
"""QSkin · 扫源码里「把字符当图标」的地方（M15.1 起接入 lint.sh 门禁）

规则本身很短：**图标要么是矢量，要么是插槽，不能是一个字形。**
理由写在 QSkinSelect / QSkinTag / QSkinInputNumber / BasicCheckIndicator 四个
文件头里 —— 字体的覆盖率和回退链不可控，同一段界面换个机器就不是那个样子。

为什么不是一条 grep：
    这些字符散在多个 Unicode 区段（Arrows / Geometric Shapes / Dingbats /
    Box Drawing / Misc Symbols），而 GNU grep 的区间语法在 Git Bash 下
    写 `[\\x{2190}-\\x{21FF}\\x{25A0}-\\x{25FF}]` 这类混合区间时会报
    "range out of order in character class" 并**静默返回非零** ——
    于是 `|| echo "（无）"` 打出"（无）"，看起来全绿，其实是**假阴性**。
    （M15.1 实录：那条坏 grep 报了"全仓返回空"，实际漏掉 4 处真问题。）

    退一步改用单字符 grep 也能对，但要求把字符集**穷举完整** —— 同样漏过
    （`◀` U+25C0 一开始不在表里）。

    所以这里用 Python：按**区段**判定，不靠穷举。

── 三档分类（这是这个脚本唯一需要动脑的地方）────────────────────────────
    ★ ICON      判为图标：字形本身就是"一个记号"（箭头 / 三角 / 勾叉 / 制表符）
                → **算问题**，退出码 1
    ? REVIEW    两可：箭头类可能只是**文中的"到"**（"步进 10 → 40"）
                → 只提示、不算问题，人工扫一眼
    -  IGNORE   明确不算：`·` 是中文排版里的间隔号（"M10 · 导航"），
                `×` 在"6×7"里是乘号 —— 出现在文案里完全正常。
                M15.1 第一版把它们算成问题，一次报了 30 处噪声，
                这种工具会被直接忽略掉，比没有更糟。

用法（一般不用直接调，跑 ./tools/lint.sh 会自动带上）：
    ./tools/scan-glyph-icons.sh            # 只报 ICON，有则退出码 1
    ./tools/scan-glyph-icons.sh --all      # ICON + REVIEW + 注释提及

退出码：0 = 无 ICON 问题；1 = 有。
"""

import os
import re
import sys

# ── ★ ICON：字形即记号，出现在 text 里就是拿字符当图标 ─────────────────
ICON_BLOCKS = [
    (0x2500, 0x257F, "Box Drawing ├─└"),
    (0x25A0, 0x25FF, "Geometric Shapes ▾◀▶▲▼●○"),
    (0x2600, 0x26FF, "Misc Symbols"),
    (0x2700, 0x27BF, "Dingbats ✓✗"),
    (0x2B00, 0x2BFF, "Misc Symbols and Arrows"),
]
ICON_SINGLES = {
    0x2039: "‹ 单左角引号（被当翻页箭头用）",
    0x203A: "› 单右角引号（被当翻页箭头用）",
}

# ── ? REVIEW：可能只是文案里的"到"，人工看一眼 ─────────────────────────
REVIEW_BLOCKS = [
    (0x2190, 0x21FF, "Arrows →←↑↓"),
]

# ── -  IGNORE：明确不算问题（注释里写明理由，免得下次又有人加回来）──────
#   ·  U+00B7 中文排版间隔号："M10 · 导航与状态标识"
#   ×  U+00D7 乘号："6×7 = 42"
#   °  ±  ÷  ²  同理（数值/单位）
IGNORE = {0x00B7, 0x00D7, 0x00B0, 0x00B1, 0x00F7, 0x00B2, 0x00B3}

# text / placeholderText / displayText … 都要管。
# 注意不能写成 `\btext` —— "placeholderText" 里 r→T 是同为词字符的
# 大小写切换，**没有词边界**，`\btext` 匹配不上，会静默漏掉输入框提示语。
# 所以用 `\w*[Tt]ext`。
TEXT_ASSIGN = re.compile(r'\w*[Tt]ext\s*:\s*(?:qsTr\s*\(\s*)?(?:"([^"\n]*)"|\'([^\'\n]*)\')')

ROOTS = ["src", "examples", "tests"]


def classify(ch):
    """返回 ('ICON'|'REVIEW'|'IGNORE'|None, 说明)"""
    cp = ord(ch)
    if cp in IGNORE:
        return "IGNORE", ""
    if cp in ICON_SINGLES:
        return "ICON", ICON_SINGLES[cp]
    for lo, hi, name in ICON_BLOCKS:
        if lo <= cp <= hi:
            return "ICON", name
    for lo, hi, name in REVIEW_BLOCKS:
        if lo <= cp <= hi:
            return "REVIEW", name
    return None, ""


def scan():
    icon, review, notes = [], [], []
    for root in ROOTS:
        for dirpath, _dirs, filenames in os.walk(root):
            for fn in sorted(filenames):
                if not fn.endswith(".qml"):
                    continue
                path = os.path.join(dirpath, fn)
                with open(path, encoding="utf-8") as fh:
                    for lineno, line in enumerate(fh, 1):
                        stripped = line.lstrip()
                        if stripped.startswith(("//", "*", "/*")):
                            bad = sorted({c for c in line
                                          if classify(c)[0] == "ICON"})
                            if bad:
                                notes.append((path, lineno, "".join(bad), line.rstrip()))
                            continue

                        m = TEXT_ASSIGN.search(line)
                        if not m:
                            continue
                        literal = m.group(1) if m.group(1) is not None else m.group(2)
                        kinds = [classify(c) for c in literal]
                        ic = sorted({c for c, (k, _) in zip(literal, kinds) if k == "ICON"})
                        rv = sorted({c for c, (k, _) in zip(literal, kinds) if k == "REVIEW"})
                        if ic:
                            icon.append((path, lineno, "".join(ic), line.rstrip()))
                        elif rv:
                            review.append((path, lineno, "".join(rv), line.rstrip()))
    return icon, review, notes


def main():
    # Windows 下 stdout 默认可能是 cp936，打不出 ▾ 会抛 UnicodeEncodeError ——
    # 一个"因为打不出错误信息而失败"的门禁比没有门禁更误导人。
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    show_all = "--all" in sys.argv
    icon, review, notes = scan()

    print("==> 字符图标扫描  ·  src/ examples/ tests/")
    print("=== ★ ICON：把符号当图标写进了 text 字面量 ===")
    if icon:
        for path, lineno, bad, src in icon:
            print(f"  {path}:{lineno}  [{bad}]\n      {src.strip()}")
    else:
        print("  （无）")

    if show_all:
        print(f"\n=== ? REVIEW：箭头类，可能只是文案里的“到”（{len(review)} 处）===")
        for path, lineno, bad, src in review:
            print(f"  {path}:{lineno}  [{bad}]  {src.strip()}")
        print(f"\n=== 注释里的提及（{len(notes)} 处，不算问题）===")
        for path, lineno, bad, _src in notes[:40]:
            print(f"  {path}:{lineno}  [{bad}]")

    if icon:
        print(f"\n✗ 字符图标 {len(icon)} 处 —— 图标请走 Slots 插槽或 Shape，"
              f"不要写字形。详见本文件头部。")
    else:
        print(f"\n✓ 字符图标 0 处"
              + (f"（? REVIEW {len(review)} 处，非问题）" if show_all else ""))
    return 1 if icon else 0


if __name__ == "__main__":
    sys.exit(main())
