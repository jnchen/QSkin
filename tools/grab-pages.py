#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批量抓图 · 逐页渲染并落盘（核「这一页有没有画出来」）

用法：
    python tools/grab-pages.py                     # examples/ 下全部
    python tools/grab-pages.py examples/HelloQSkin.qml

做法：**给页面生成一份带抓图 Timer 的副本**，原件一个字都不改。

五版都栽在同一类地方，逐条记下来（每一条都是实测报错换来的）：
  ① 根必须是 `Window` —— Item 作根时事件循环起不来、Timer 永不触发，
     而 `qml.exe` **仍然返回 0** ⇒ 拿到一张全黑图而判据全绿。
     （项目已记：`tests/scene_layout_justify.qml` 文件头 ①）
  ② 抓的是 `contentItem` —— `grabToImage` 是 Item 的方法，
     `win.grabToImage(...)` 报 `Property 'grabToImage' … is not a function`
  ③ 窗口必须已 show —— `contentItem` 的尺寸只在 show 之后才有；
     未 show 时是 **0×0**。实测只有 `examples/HelloContracts.qml` 缺
     `visible: true`，所以只在**确实缺**的页面上补那一行。
  ④ 路径**不能走命令行参数** —— `qml` 会把 `grab=xxx` 当成第二个待加载的
     qml 文件，报 `grab=…: No such file or directory` 而整页加载失败。
  ⑤ **绝对不要碰 `Component.onCompleted`** —— 注入 `show()` 撞上页面
     已有的同名声明（`showcase/HelloM18.qml`），报
     `Property value set multiple times`；页面有多个 onCompleted
     （根上一个、末尾一个）还会插错那一个；按 `id: win` 反推缩进会
     **匹配到文件头注释里的** `id: win`。
     ⇒ **Timer 只是个普通子对象，放文件末尾即可，零冲突。**

判据必须三条一起查：**rc / stderr 的 QML 报错 / 图的色彩数**。
只看 rc 会被 ①③ 骗过去 —— 那两种情况 rc 都是 0，而图是纯色。
"""
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".cache", "pages")
WRAP = os.path.join(ROOT, ".cache", "_wrap")

ERR_MARKERS = (
    "is not a type", "Cannot assign", "is not a function",
    "Unable to assign", "TypeError", "ReferenceError",
    "is not a property", "Syntax Error", "Unable to",
    "Property value set", "Expected token",
)

TIMER_TPL = '''
    /* ↓↓↓ 自动追加的抓图尾（tools/grab-pages.py）↓↓↓
     * ⚠ 纯机械插入：不碰本页任何声明，所以不会与页面撞名。 */
    Timer {
        running: true
        interval: %(WAIT)d
        onTriggered: {
            var target = %(ROOTID)s.contentItem
            if (!target || target.width <= 0 || target.height <= 0) {
                console.error("grab: contentItem 无尺寸 "
                              + (target ? target.width + "x" + target.height
                                        : "null"))
                Qt.exit(10)
                return
            }
            target.grabToImage(function(res) {
                Qt.exit(res.saveToFile("%(OUT)s") ? 0 : 9)
            })
        }
    }
'''


def find_qml():
    env = os.environ.get("QSkin_QT", "")
    cands = []
    if env:
        cands.append(os.path.join(env, "bin", "qml.exe"))
    cands += [os.path.join(d, "bin", "qml.exe")
              for d in glob.glob(os.path.join(ROOT, ".qt", "*", "*"))
              if os.path.isdir(d)]
    for c in cands:
        if os.path.exists(c):
            return c
    raise SystemExit("找不到 qml.exe")


def png_colors(path):
    """图的色彩数。Pillow 缺失返回 None —— **不假装通过**。"""
    try:
        from PIL import Image
    except ImportError:
        return None
    try:
        return len(Image.open(path).convert("RGB")
                   .getcolors(maxcolors=200000) or [])
    except Exception:
        return None


def prepare(page_rel, name, wait, lib=None, outdir=None):
    """生成带抓图 Timer 的副本。返回 (副本路径, 错误说明)。"""
    lib = lib or ROOT
    raw = open(os.path.join(lib, page_rel), encoding="utf-8",
               newline="").read()
    nl = "\r\n" if ("\r\n" in raw and raw.count("\n") == raw.count("\r\n")) \
        else "\n"

    # ① 根必须是 Window 家族，且能拿到它的 id
    m = re.search(r"(?m)^(QSkinWindow|Window|ApplicationWindow)\s*\{\s*$",
                  raw)
    if not m:
        return None, "根类型不是 Window 家族（Item 作根 ⇒ Timer 不触发）"
    mid = re.search(r"(?m)^\s*id:\s*([A-Za-z_][A-Za-z0-9_]*)",
                    raw[m.end():])
    if not mid:
        return None, "根节点没有 id —— 无法取 contentItem"
    root_id = mid.group(1)

    # ③ 只在**确实缺** visible: true 时补一行，插在根类型行**之后**。
    #    ⚠ 第一版插在 `{` 之前，生成了 `visible: true{` 这种坏语法。
    out = raw
    if not re.search(r"(?m)^\s*visible:\s*true", raw[m.end():m.end() + 2000]):
        after = m.end()              # 紧跟 `{` 之后（m 以 `\s*$` 结束）
        out = raw[:after] + nl + "    visible: true" + raw[after:]

    # ⑤ 只在文件末尾追加 Timer，不碰任何已有声明
    idx = out.rstrip().rfind("}")
    if idx < 0:
        return None, "找不到文件末尾的 }"
    # ⚠ 输出目录必须来自**参数**，不能读模块级 OUT 常量 ——
    #   第一版 grab() 用了 --out 参数、prepare() 却仍读常量 OUT，
    #   于是「副本写到 .cache/pages、判据看 .cache/qt511_pages」两边错开，
    #   表现是抓图恒为「没产出图」而代码全对（实测踩过一次）。
    out_dir = outdir or OUT
    tail = TIMER_TPL % {"WAIT": wait, "ROOTID": root_id,
                        "OUT": (os.path.join(out_dir, name + ".png")
                                .replace("\\", "/"))}
    out = out[:idx] + tail.replace("\n", nl) + out[idx:]

    os.makedirs(WRAP, exist_ok=True)
    dst = os.path.join(WRAP, name + ".qml")
    with open(dst, "w", encoding="utf-8", newline="") as f:
        f.write(out)
    return dst, None


def grab(page_rel, name, qml, wait=1400, timeout=45, lib=None, outdir=None):
    lib = lib or ROOT
    outdir = outdir or OUT
    os.makedirs(outdir, exist_ok=True)
    png = os.path.join(outdir, name + ".png")
    if os.path.exists(png):
        os.remove(png)          # 判「是不是新鲜的」靠色彩数，不靠时间戳

    wrapped, err = prepare(page_rel, name, wait, lib=lib, outdir=outdir)
    if err:
        return {"rc": -1, "png": False, "bytes": 0, "colors": None,
                "errors": [err]}

    env = dict(os.environ)
    env["PATH"] = os.path.dirname(qml) + os.pathsep + env.get("PATH", "")
    env["QT_FORCE_STDERR_LOGGING"] = "1"

    # ⚠ .cache/qmlimports 只在抓 **src/（Qt 6 侧）** 时才有意义：
    #   那个目录是给 Qt 6 的模块缓存用的。对降级产物（qt5/qt511）加上它，
    #   Qt 5.11 的 qml.exe 会 `Did not load any objects, exiting.` 且 **rc=0**
    #   —— 图没生成、判据却显示「无报错」，是最难查的一种假绿。
    #   （实测 A/B 对照：只 -I qt511 ⇒ 出图；再加 qmlimports ⇒ 无图 rc=0。）
    args = [qml, "-I", lib]
    if os.path.abspath(lib) == os.path.abspath(ROOT):
        extra = os.path.join(ROOT, ".cache", "qmlimports")
        if os.path.isdir(extra):
            args += ["-I", extra]
    args.append(wrapped)
    try:
        r = subprocess.run(
            args,
            capture_output=True, text=True, errors="replace",
            env=env, timeout=timeout)
        rc, errs = r.returncode, (r.stderr or "")
    except subprocess.TimeoutExpired:
        rc, errs = -1, "<subprocess timeout>"

    qml_errs = [l.strip() for l in errs.splitlines()
                if any(m in l for m in ERR_MARKERS)]
    ok = os.path.exists(png)
    return {"rc": rc, "png": ok,
            "bytes": os.path.getsize(png) if ok else 0,
            "colors": png_colors(png) if ok else None,
            "errors": qml_errs}


def main():
    # --lib <dir>：把 examples 根指到别处（默认ROOT/examples）。
    # 用途：抓**降级产物**里的页面（如 qt511/），验证「这份产物在目标 Qt 上
    # 真画得出来」。判据与抓src/ 的页面完全一致，不另开一套。
    lib = ROOT
    if "--lib" in sys.argv:
        i = sys.argv.index("--lib")
        if i + 1 < len(sys.argv):
            lib = os.path.abspath(sys.argv[i + 1])
            del sys.argv[i:i + 2]
    outdir = OUT
    if "--out" in sys.argv:
        i = sys.argv.index("--out")
        if i + 1 < len(sys.argv):
            outdir = os.path.abspath(sys.argv[i + 1])
            del sys.argv[i:i + 2]

    qml = find_qml()
    targets = []
    if len(sys.argv) > 1:
        for a in sys.argv[1:]:
            targets.append((a, os.path.splitext(os.path.basename(a))[0]))
    else:
        exdir = os.path.join(lib, "examples")
        for f in sorted(os.listdir(exdir)):
            if f.endswith(".qml") and f.startswith("Hello"):
                targets.append(("examples/" + f, f[:-4]))
        sc = os.path.join(exdir, "showcase")
        if os.path.isdir(sc):
            for f in sorted(os.listdir(sc)):
                if f.endswith(".qml"):
                    targets.append(("examples/showcase/" + f, "sc_" + f[:-4]))

    print("库根 = %s" % lib)
    print("输出 = %s" % outdir)
    print("目标 %d 页   （色彩数 ≤ 3 视为「没画出来」）\n" % len(targets))
    bad = []
    for rel, name in targets:
        res = grab(rel, name, qml, lib=lib, outdir=outdir)
        col = res["colors"]
        blank = (col is not None and col <= 3)
        coltxt = ("%d 色" % col) if col is not None else "色彩数未知"
        flag = "**空白**" if blank else ("有图" if res["png"] else "无图")
        print("  %-22s rc=%-5s %-8s %-10s %8d B%s"
              % (name, res["rc"], flag, coltxt, res["bytes"],
                 ("  ⚠ %d 报错" % len(res["errors"])) if res["errors"] else ""))
        if blank or not res["png"] or res["errors"]:
            bad.append((name, res, blank))

    print("\n有问题的页：%d / %d" % (len(bad), len(targets)))
    for name, res, blank in bad:
        why = []
        if blank:
            why.append("图纯色（内容没画出来）")
        if not res["png"]:
            why.append("没产出图")
        if res["errors"]:
            why.append("%d 条 QML 报错" % len(res["errors"]))
        print("  %-22s %s" % (name, "；".join(why)))
        for e in res["errors"][:3]:
            print("      " + e[:100])


if __name__ == "__main__":
    main()