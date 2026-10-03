#!/usr/bin/env python3
#############################################################################
# QSkin · Shape 渲染器门禁
#
# 规则：每个 Shape 都必须显式写 preferredRendererType: Shape.CurveRenderer，
#       并且 QtQuick.Shapes 的导入**不能带版本号**。
#
# ── 为什么这条规矩非有不可 ──────────────────────────────────────────────
# Qt 6 的 RHI 后端下，Shape 的**默认**渲染器是 GeometryRenderer：它把路径
# 三角化成三角形交给 GPU，**不做抗锯齿**。于是所有斜线 —— 勾选框的勾、
# 展开箭头、排序三角、标签上的叉 —— 边缘都是纯色阶梯。
#
# 更坑的是第二层：`Shape.antialiasing` 这个属性在 Qt 6 的官方属性表里
# **已经不存在了**（Qt 5 才有）。写了不报错、也不生效。所以代码里躺着一句
# `antialiasing: true` 反而让人以为"抗锯齿已经处理过了" —— 实测 18 个 Shape
# 里有 8 个是这么写的，另外 10 个连这句都没有。
#
# 官方文档原文：
#   GeometryRenderer — "Uses the same CPU-based triangulation approach as
#                       QPainter's OpenGL 2 paint engine."
#   CurveRenderer    — "provides native, high-quality anti-aliasing, without
#                       the performance cost of multi- or supersampling."
#
# ── 第三层坑：import 版本号 ─────────────────────────────────────────────
# `import QtQuick.Shapes 1.15` 会让 preferredRendererType 变成**不可用**，
# 运行时直接报 "Shape.preferredRendererType is not available in
# QtQuick.Shapes 1.15"，整个控件加载失败。实测只有不带版本号的
# `import QtQuick.Shapes` 才能用（Qt 6 里无版本导入 = 取最高可用版本）。
#
# ── 用法 ────────────────────────────────────────────────────────────────
#     tools/check-shape-aa.py [目录...]     默认 src/
# 退出码：0 = 全部就位；1 = 有违规
#
# 一般不用直接调 —— ./tools/lint.sh 末尾会自动带上这一步。
#############################################################################

import os
import re
import sys

TARGETS = sys.argv[1:] or ["src"]

SHAPE_RE = re.compile(r"^([ \t]*)Shape[ \t]*\{[ \t]*$")
DEAD_AA_RE = re.compile(r"^[ \t]*antialiasing[ \t]*:")

VER_IMPORT_RE = re.compile(r"^import[ \t]+QtQuick\.Shapes[ \t]+\S+")


def qml_files(roots):
    for root in roots:
        if os.path.isfile(root):
            yield root
            continue
        for dirpath, _dirs, files in os.walk(root):
            for name in sorted(files):
                if name.endswith(".qml"):
                    yield os.path.join(dirpath, name)


def shape_head(lines, i):
    """Shape { 之后、ShapePath 或块结束之前的行 —— 也就是 Shape 自己的属性区。

    只在这个范围里找 preferredRendererType：ShapePath 里面也可能出现同名
    字符串（比如将来某个路径带注释），不该误判成"已经指定过了"。
    """
    j = i + 1
    while j < len(lines):
        s = lines[j].strip()
        if "ShapePath" in s or s.startswith("}"):
            break
        j += 1
    return lines[i + 1:j]


def main():
    n_shape = 0
    missing = []         # 没写渲染器 → 默认 GeometryRenderer，硬边
    dead_aa = []         # 残留的 antialiasing，Qt6 无效
    bad_import = []      # Shapes 导入带了版本号

    for path in qml_files(TARGETS):
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().split("\n")

        for i, line in enumerate(lines):
            if VER_IMPORT_RE.match(line):
                bad_import.append((path, i + 1, line.strip()))

            m = SHAPE_RE.match(line)
            if not m:
                continue

            n_shape += 1
            head = shape_head(lines, i)

            if not any("preferredRendererType" in h for h in head):
                missing.append((path, i + 1))

            for k, h in enumerate(head):
                if DEAD_AA_RE.match(h):
                    dead_aa.append((path, i + 2 + k))
                    break

    print(f"==> Shape 抗锯齿  ·  扫到 {n_shape} 个 Shape")

    if missing:
        print("=== \u2605 未指定渲染器（默认 GeometryRenderer，斜边是硬边阶梯）===")
        for path, ln in missing:
            print(f"  {path}:{ln}")
    if bad_import:
        print("=== \u2605 QtQuick.Shapes 导入带了版本号（会让 preferredRendererType 整个不可用）===")
        for path, ln, text in bad_import:
            print(f"  {path}:{ln}  {text}")
    if dead_aa:
        print("=== \u2605 Shape 上残留的 antialiasing（Qt6 无此属性，写了不生效）===")
        for path, ln in dead_aa:
            print(f"  {path}:{ln}")

    total = len(missing) + len(bad_import) + len(dead_aa)
    if total:
        print(f"\n\u2717 {total} 处")
        return 1

    print(f"\u2713 {n_shape} 个 Shape 全部指定了 CurveRenderer")
    return 0


if __name__ == "__main__":
    sys.exit(main())
