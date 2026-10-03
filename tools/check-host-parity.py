#!/usr/bin/env python3
"""QSkin · 五宿主对账（Qt 6：qml / C++ / PySide6 · Qt 5：PyQt5 / C++）——
证明「QSkin 在 C++、PySide6(Qt 6)、PyQt5(Qt 5) 与 C++(Qt 5) 下都能用」。

SPDX-License-Identifier: MIT OR Apache-2.0

用法：
    python tools/check-host-parity.py               # 五宿主全跑
    python tools/check-host-parity.py --no-shot     # 只做契约检查，不抓图

── Qt 5 那两个宿主和前三个不是同一条路 ────────────────────────────────────
前三个宿主跑的都是 `src/`（Qt 6.8+ 写法，事实源）；Qt 5 侧两个宿主跑的是
`qt5/`（`tools/qml-downgrade.py` 从 src/ 生成的降级产物）。所以：

    · Qt 5 侧的 import 路径是 qt5/，不是 .cache/qmlimports；
    · Qt 5 侧**不参与像素对账** —— Qt 5 与 Qt 6 的渲染（抗锯齿、Shape 光栅化）
      本来就不可能逐像素相同，把不同 Qt 版本的图拿去比像素是**假判据**；
    · 但 Qt 5 侧**参与契约对账**（判据 1 / 2）：解析数、可实例化数、单例数
      必须与 Qt 6 侧完全一致 —— 这才是"两条线都支持"的承重断言。

── 为什么这道门存在 ────────────────────────────────────────────────────────
README 写的是「为 Qt Quick 打造的设计系统」，但本仓长期**只验证过 `qml`
运行器**：全仓搜 `PySide|PyQt` 曾经零命中，C++ 宿主也从未写过。"纯 QML 库
所以谁都能用"是**推论**，不是实测。这道门把它变成实测。

── 判据（位掩码）──────────────────────────────────────────────────────────
    1   契约失败     —— 某个宿主没做到「全部可解析 / 全部可实例化 / 单例全中」
    2   宿主不一致   —— 五个宿主跑出来的数字不一致（含 Qt 5 侧两个）
    4   警告漂移     —— PySide6(Qt 6.11) 的属性遮蔽警告集合与已知清单不符
    8   工装错误     —— 缺宿主二进制 / 缺 PySide6 / **缺 PyQt5** / 缺 Qt
                        （**不静默跳过** —— 判据的输入没了 ≠ 没问题）
    16  像素对账失败 —— Qt 6 侧三宿主抓的图不一致（Qt 5 侧不参与，见上）

── 关于判据 4 的那些警告，为什么是「对账」而不是「清零」──────────────────
Qt 6.11 开始对「属性遮蔽基类成员」发警告，并建议加 `override`。实测结论：

    · Qt 6.8.3 **不认识** `override` 关键字 —— 加了直接语法错误、加载失败
      （`Expected token ':'`，RC=2）。本仓开发基准就是 6.8.3。
    · 所以「为 6.11 消警告」=「放弃 6.8 兼容」或「改属性名」；
      而 `data` 是 `default property alias` 机制（`QSkinRow { Item{} }` 靠它），
      `enabled` 是控件语义 —— 改名都要破坏 API。

结论：**不改源码**，改为把已知警告写成**断言清单**：数量与内容必须恰好
等于清单，多一条（新引入的遮蔽）就红、少一条（问题消失了，清单该更新）
也红。这比"写句注释说已知无害"强 —— 注释不会红，断言会。
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, ".cache")
SCENE = os.path.join(ROOT, "tests", "scene_host_parity.qml")
IMPORT = os.path.join(CACHE, "qmlimports")
# Qt 5 侧走**另一棵源码树**（降级产物，入库），不是 .cache/qmlimports。
IMPORT_QT5 = os.path.join(ROOT, "qt5")

# ── 已知的属性遮蔽警告（Qt 6.11 在 PySide6 宿主下报），(成员, 类型) 集合 ──
# 生成方式：跑一次 PySide6 宿主，从 stderr 抽 `propertyCache.append` 行。
# 顺序无关；新增一条遮蔽 ⇒ 门红（那说明有人又遮蔽了一个基类成员）。
KNOWN_SHADOW = {
    # `default property alias data` —— QML 让 `QSkinRow { Item{} }` 生效的机制，
    # 不是缺陷；改名会破坏 API，故保留并登记。
    ("data", "ButtonBar"),
    ("data", "QSkinColumn"),
    ("data", "QSkinFormItem"),
    ("data", "QSkinGrid"),
    ("data", "QSkinRow"),
    # 控件重新声明 `enabled`，遮蔽基类 Item.enabled。语义上就是同一个开关，
    # 不是误覆盖；同样保留并登记。
    ("enabled", "ACChevronIndicator"),
    ("enabled", "ADChevronIndicator"),
    ("enabled", "BasicChevronIndicator"),
    ("enabled", "QSkinAutoComplete"),
    ("enabled", "QSkinCarousel"),
    ("enabled", "QSkinCascader"),
    ("enabled", "QSkinCollapse"),
    ("enabled", "QSkinColorPicker"),
    ("enabled", "QSkinMentions"),
    ("enabled", "QSkinSegmented"),
    ("enabled", "QQuickItem"),          # 匿名内联组件（_QML_<n> 后缀已归一化）
    ("enabled", "QSkinTimeline"),
    ("enabled", "QSkinTransfer"),
    ("enabled", "QSkinTree"),
    ("enabled", "QSkinTreeSelect"),
    ("enabled", "QSkinUpload"),
    ("enabled", "SCChevronIndicator"),
    ("enabled", "TDChevronIndicator"),
}

WARN_RE = re.compile(
    r"Member\s+([A-Za-z_]\w*)\s+of the object\s+([A-Za-z_]\w*?)(?:_QMLTYPE_\d+|_QML_\d+)?\s+overrides"
)

EXPECTED_QT_MIN = "6.8"     # C++ / qml 宿主用的 Qt（.qt/6.8.3）


def find_qml_runner():
    """返回 (qml 运行器路径, Qt 前缀)。"""
    qtdir = os.path.join(ROOT, ".qt")
    if not os.path.isdir(qtdir):
        return None, None
    for d in sorted(os.listdir(qtdir)):
        for sub in ("mingw_64", "msvc2019_64", "gcc_64", "macos", "linux"):
            base = os.path.join(qtdir, d, sub)
            for cand in (os.path.join(base, "bin", "qml"),
                         os.path.join(base, "bin", "qml.exe")):
                if os.path.exists(cand):
                    return cand, base
    return None, None


def find_qt5_prefix():
    """返回 Qt 5 前缀（供 C++ Qt 5 宿主跑起来时找 DLL），没有则 None。

    Qt 5 装在 WorkBuddy 的托管目录里（`~/.workbuddy/binaries/qt5/<ver>/<变体>`），
    与 Qt 6 的 `.qt/` 不是同一处 —— 所以不能复用 `find_qml_runner`。
    """
    base = os.path.join(os.path.expanduser("~"), ".workbuddy", "binaries", "qt5")
    if not os.path.isdir(base):
        return None
    for v in sorted(os.listdir(base), reverse=True):
        for sub in ("mingw81_64", "msvc2019_64", "gcc_64", "clang_64"):
            p = os.path.join(base, v, sub)
            if os.path.isdir(os.path.join(p, "lib", "cmake", "Qt5")):
                return p
    return None


def qt_runtime_env(qt_prefix, with_tools=True):
    """构造跑 Qt 程序所需的 PATH 追加项。

    ⚠ 不加这个，C++ 宿主会死在 `0xC0000135 / STATUS_DLL_NOT_FOUND`
      （实测 rc=3221225781）—— 二进制本身没问题，是 Qt 的 DLL 不在
      搜索路径上。qml.exe 同理（它自带的 Qt 也在同一目录）。

    ⚠ `with_tools` 只在 **Qt 6 侧**为 True：`.qt/Tools/mingw1310_64/bin` 里
      是 GCC 13 的运行库（Qt 6 宿主由它编译）。**给 Qt 5 侧加它就是毒**：
      Qt 5.15 的 mingw81_64 自带 GCC 8.1 的 `libstdc++-6.dll` /
      `libgcc_s_seh-1.dll` / `libwinpthread-1.dll`，两套 MinGW 运行库撞在
      一个进程里 → 实测 C++ Qt 5 宿主直接 `0xC0000005`（rc=3221225477），
      而**单独手动跑同一个二进制是好的**（那时 PATH 里只有 Qt5 的 bin）。
      这个错误看起来像"Qt 5 宿主有 bug"，其实是把 Qt 6 的运行库喂给了它。
    """
    if not qt_prefix:
        return {}
    bins = [os.path.join(qt_prefix, "bin")]
    tools = os.path.join(ROOT, ".qt", "Tools")
    if with_tools and os.path.isdir(tools):
        for t in sorted(os.listdir(tools)):
            b = os.path.join(tools, t, "bin")
            if os.path.isdir(b):
                bins.append(b)
    sep = os.pathsep
    return {"PATH": sep.join(bins) + sep + os.environ.get("PATH", "")}


def find_python_with_pyside6():
    """定位能 import PySide6 的解释器。

    优先级：环境变量 QSkin_PYSIDE6_PYTHON > 项目内 .cache/pyhost-venv >
    WorkBuddy 托管 venv > PATH 里的 python。找不到返回 None（由调用方报
    **工装错误**，不静默跳过）。

    ⚠ 托管 venv 这一档与 `find_python_with_pyqt5` 同款：依赖常装在隔离环境里
    （不在 PATH），只扫 PATH 会在"明明装了"的机器上误报工装错误。
    """
    cands = []
    env = os.environ.get("QSkin_PYSIDE6_PYTHON")
    if env:
        cands.append(env)
    for p in (os.path.join(CACHE, "pyhost-venv", "Scripts", "python.exe"),
              os.path.join(CACHE, "pyhost-venv", "bin", "python")):
        cands.append(p)
    home = os.path.expanduser("~")
    for base in (os.path.join(home, ".workbuddy", "binaries", "python", "envs", "default"),
                 os.path.join(home, ".workbuddy", "binaries", "python", "versions")):
        for sub in ("Scripts", "bin"):
            d = os.path.join(base, sub)
            if not os.path.isdir(d):
                continue
            if sub == "bin":
                cands.append(os.path.join(d, "python"))
                cands.append(os.path.join(d, "python3"))
            else:
                cands.append(os.path.join(d, "python.exe"))
        if base.endswith("versions"):
            try:
                for v in sorted(os.listdir(base)):
                    cands.append(os.path.join(base, v, "python.exe"))
                    cands.append(os.path.join(base, v, "bin", "python3"))
            except OSError:
                pass
    for p in ("python", "python3"):
        w = shutil.which(p)
        if w:
            cands.append(w)
    for p in cands:
        if not p or not os.path.exists(p):
            continue
        try:
            r = subprocess.run([p, "-c", "import PySide6"],
                               capture_output=True, timeout=60)
            if r.returncode == 0:
                return p
        except Exception:
            continue
    return None


def find_python_with_pyqt5():
    """定位能 import PyQt5 的解释器（Qt 5 侧宿主）。

    与 `find_python_with_pyside6` 同构，但**必须分开找**：PySide6 与 PyQt5
    很少装在同一环境里（本项目就是各装各的）。找不到返回 None → 调用方
    报**工装错误 8**，不静默跳过。

    优先级：QSkin_PYQT5_PYTHON > .cache/pyqt5-venv > WorkBuddy 托管 venv
    > PATH 里的 python。

    ⚠ 为什么要扫"托管 venv"这一档：装依赖的往往是隔离环境（本项目实测就
    装在 `~/.workbuddy/binaries/python/envs/default`），它**不在 PATH 里**。
    只扫 PATH 会在"明明装了"的机器上误报工装错误 —— 报红了却不是真问题，
    等于把门变成噪声。
    """
    cands = []
    env = os.environ.get("QSkin_PYQT5_PYTHON")
    if env:
        cands.append(env)
    for p in (os.path.join(CACHE, "pyqt5-venv", "Scripts", "python.exe"),
              os.path.join(CACHE, "pyqt5-venv", "bin", "python")):
        cands.append(p)
    home = os.path.expanduser("~")
    for base in (os.path.join(home, ".workbuddy", "binaries", "python", "envs", "default"),
                 os.path.join(home, ".workbuddy", "binaries", "python", "versions")):
        for sub in ("Scripts", "bin"):
            d = os.path.join(base, sub)
            if not os.path.isdir(d):
                continue
            if sub == "bin":
                cands.append(os.path.join(d, "python"))
                cands.append(os.path.join(d, "python3"))
            else:
                cands.append(os.path.join(d, "python.exe"))
        if base.endswith("versions"):
            try:
                for v in sorted(os.listdir(base)):
                    cands.append(os.path.join(base, v, "python.exe"))
                    cands.append(os.path.join(base, v, "bin", "python3"))
            except OSError:
                pass
    for p in ("python", "python3"):
        w = shutil.which(p)
        if w:
            cands.append(w)
    for p in cands:
        if not p or not os.path.exists(p):
            continue
        try:
            r = subprocess.run([p, "-c", "import PyQt5"],
                               capture_output=True, timeout=60)
            if r.returncode == 0:
                return p
        except Exception:
            continue
    return None


def parse_parity(text):
    out = {}
    for line in text.splitlines():
        line = line.strip()
        m = re.match(r"^(?:qml:\s*)?PARITY\s+(\w+)\s*(.*)$", line)
        if m:
            out[m.group(1)] = m.group(2).strip()
    return out


def parse_shadows(text):
    got = set()
    for m in WARN_RE.finditer(text):
        got.add((m.group(1), m.group(2)))
    return got


def pixel_compare(names, t0=None):
    """三宿主抓的图逐像素比对。

    返回 (结果列表, 错误串)。结果列表每项 (a, b, 差异像素数, 总像素数)。
    错误串非 None 表示**工装问题**（缺 PIL / 图不存在），不是渲染不一致。
    """
    try:
        from PIL import Image
    except ImportError:
        return None, "缺 PIL（既有像素门也依赖它）：pip install pillow"

    ims = {}
    for n in names:
        p = os.path.join(CACHE, "host_parity_%s.png" % n)
        if not os.path.exists(p):
            return None, "缺图 -> %s" % p
        if t0 is not None and os.path.getmtime(p) < t0:
            # 图是**上一轮**留下的：这个宿主这轮没抓图。不报出来就会拿旧图
            # 跟别人比，绿得毫无道理。
            return None, ("图没更新（宿主这一轮没抓图）-> %s" % p)
        ims[n] = Image.open(p).convert("RGB")

    sizes = {ims[n].size for n in names}
    if len(sizes) != 1:
        return None, "三张图尺寸不一致：%s" % {n: ims[n].size for n in names}

    out = []
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            A, B = ims[a], ims[b]
            pa, pb = A.load(), B.load()
            w, h = A.size
            diff = 0
            for y in range(h):
                for x in range(w):
                    r1, g1, b1 = pa[x, y]
                    r2, g2, b2 = pb[x, y]
                    if abs(r1 - r2) + abs(g1 - g2) + abs(b1 - b2) > 12:
                        diff += 1
            out.append((a, b, diff, w * h))
    return out, None


def run_host(name, cmd, env=None):
    e = dict(os.environ)
    e["QT_FORCE_STDERR_LOGGING"] = "1"
    # ⚠ 抓图尺寸必须**确定**，不能靠默认：
    # 场景里 `grabToImage` 抓的是 900x620 的逻辑尺寸，实际像素会再乘
    # Screen.devicePixelRatio。而 DPR 取决于宿主进程的 DPI 感知 —— 实测同一个
    # C++ 二进制两次跑出 1350x930 与 900x620，于是像素对账报
    # "三张图尺寸不一致"（工装错误 8），而**库本身一点问题都没有**。
    # 钉死 dpiawareness 之后，同一轮里所有宿主拿到的 DPR 一致。
    # （只在 Windows 注入：`windows:` 是 Windows 平台插件的参数，别的平台
    #  传进去只会让 Qt 找不到平台插件。）
    # 用 **offscreen** 平台插件：不建真窗口、不连屏幕，于是 devicePixelRatio、
    # 窗口尺寸、字体度量全都不看当前机器/当前会话 —— 抓图才是确定的。
    #
    # 为什么非要它（踩过来的三步）：
    #   1. 不钉平台时，同一个 C++ 宿主两次跑出 1350x930 与 900x620（DPR 随
    #      会话漂），像素对账报"尺寸不一致"，而库一点问题都没有；
    #   2. 钉 `windows:dpiawareness=1` 后尺寸稳定在 1350x930，但**偶发**仍有
    #      某个宿主拿到 DPR=1 —— 复现不出，属于不能用；
    #   3. 钉 `dpiawareness=0`（DPR 恒 1）后尺寸稳定，但 C++ 宿主与 qml /
    #      pyside6 出现 1.85% 的**内容**差异（不是抗锯齿，是元素错位）——
    #      unaware 下三个宿主对字体/布局的处理并不一致。
    #   offscreen 是唯一实测三宿主**逐像素零差异**且尺寸恒定的环境
    #   （900x620，Qt 5 / Qt 6 五个宿主都能起）。
    e.setdefault("QT_QPA_PLATFORM", "offscreen")
    if env:
        e.update(env)
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           timeout=300, cwd=ROOT, env=e)
    except subprocess.TimeoutExpired:
        return None, "超时（300s）—— 场景停摆", 124
    return r.stdout + r.stderr, None, r.returncode


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-shot", action="store_true", help="不抓图")
    ap.add_argument("--cpp-bin", default=os.path.join(CACHE, "hostbuild-cpp", "qdshost.exe"))
    ap.add_argument("--skip-cpp", action="store_true")
    ap.add_argument("--skip-pyside6", action="store_true")
    ap.add_argument("--skip-pyqt5", action="store_true")
    ap.add_argument("--skip-cpp-qt5", action="store_true")
    ap.add_argument("--pixel-only", action="store_true",
                    help="**不跑宿主**，只拿 .cache 里已有的图做像素对账。"
                         "（证伪器要用：先正常跑一遍出图，改掉一个像素，再用这个模式复核）")
    args = ap.parse_args()

    code = 0
    results = {}
    shadow_report = None

    if args.pixel_only:
        names = [n for n in ("qml", "cpp", "pyside6")
                 if os.path.exists(os.path.join(CACHE, "host_parity_%s.png" % n))]
        print("═══ 像素对账（--pixel-only，不重跑宿主）═══")
        res, perr = pixel_compare(names)
        if perr:
            print("  工装错误：%s" % perr)
            return 8
        for a, b, d, tot in res:
            if d == 0:
                print("  ✓ %-8s vs %-8s 逐像素一致（%d 像素）" % (a, b, tot))
            else:
                code |= 16
                print("  ✗ %-8s vs %-8s 差异 %d/%d = %.4f%%" % (a, b, d, tot, 100.0 * d / tot))
        print("")
        print("OK  像素对账：全过（位掩码 0x00）" if code == 0
              else "NG  像素对账：位掩码 0x%02X" % code)
        return code

    if not os.path.exists(SCENE):
        print("工装错误：对账场景不存在 -> %s" % SCENE)
        return 8
    if not os.path.isdir(IMPORT):
        print("工装错误：import 树不存在 -> %s（先跑 ./tools/shot.sh 任一场景搭一次）" % IMPORT)
        return 8

    # ⚠ 抓图**不能靠删旧图来保证新鲜**：早期版本先删 `host_parity_*.png`
    #   再跑，结果在 `test.sh` 里被宿主的批量删除保护拦下（一个 turn 内累计
    #   删除超阈值要人工确认）—— 门变成永远红，而且红得莫名其妙。
    #   改成**记时间戳**：跑完比对每张图的 mtime 是否晚于本轮开始时刻，
    #   没更新的就是"这个宿主根本没抓图"，按工装错误报出来。
    shot_t0 = time.time() - 1.0   # 留 1s 余量，防文件系统时间粒度

    qml_runner, qt_prefix = find_qml_runner()
    if not qml_runner:
        print("工装错误：找不到 qml 运行器（.qt/*/*/bin/qml）。")
        print("          补齐：./tools/setup-hosts.sh   （缺什么装什么；--check 只体检）")
        return 8
    qtenv = qt_runtime_env(qt_prefix)
    # 从前缀反推 Qt 版本（例：.../.qt/6.8.3/mingw_64 -> 6.8.3）
    qt_ver_guess = os.path.basename(os.path.dirname(qt_prefix)) if qt_prefix else "?"

    # ── 宿主 1：qml（基准）──────────────────────────────────────────────
    # `qml` 运行器不支持注入属性，场景用默认 hostTag="qml"，也总是抓图。
    cmd = [qml_runner, "-I", IMPORT, SCENE]
    out, err, rc = run_host("qml", cmd, env=qtenv)
    if err:
        print("qml 宿主：%s" % err)
        code |= 8
    else:
        p = parse_parity(out)
        p.setdefault("qt", qt_ver_guess)   # 场景不报 Qt 版本（宿主才知道）
        results["qml"] = (p, rc)

    # ── 宿主 2：C++ ─────────────────────────────────────────────────────
    if args.skip_cpp:
        print("（按参数跳过 C++ 宿主）")
    else:
        cpp = args.cpp_bin
        if not os.path.exists(cpp):
            print("工装错误：C++ 宿主二进制不存在 -> %s" % cpp)
            print("          构建：bash examples/hosts/cpp/build.sh")
            code |= 8
        else:
            # ⚠ `hostTag` 必须**显式传**：它决定抓图文件名
            #   （`host_parity_<tag>.png`）。Qt 5 那份宿主与 Qt 6 这份共用
            #   `main.cpp`，默认 tag 都是 "cpp" —— 不显式区分的话，后跑的
            #   Qt 5 宿主会把 Qt 6 宿主的图**覆盖掉**，像素对账于是拿一张
            #   Qt 5 的图去和 qml / pyside6 比，报出一堆根本不存在的差异
            #   （实测 4804 像素）。这种错最难看：图是真的、差异是真的，
            #   只是比错了对象。
            cmd = [cpp, "--import-path", IMPORT, "--scene", SCENE, "--host-tag", "cpp"]
            if args.no_shot:
                cmd.append("--no-shot")
            # ⚠ 必须带 Qt 的 bin 进 PATH，否则 0xC0000135（找不到 Qt DLL）
            out, err, rc = run_host("cpp", cmd, env=qtenv)
            if err:
                print("cpp 宿主：%s" % err)
                code |= 8
            else:
                results["cpp"] = (parse_parity(out), rc)

    # ── 宿主 3：PySide6 ─────────────────────────────────────────────────
    if args.skip_pyside6:
        print("（按参数跳过 PySide6 宿主）")
    else:
        py = find_python_with_pyside6()
        if not py:
            print("工装错误：找不到装了 PySide6 的解释器。")
            print("          这不是代码问题 —— 补齐：./tools/setup-hosts.sh")
            print("          （或 pip install PySide6 / QSkin_PYSIDE6_PYTHON=/path/to/python）")
            code |= 8
        else:
            cmd = [py, os.path.join(ROOT, "examples", "hosts", "pyside6", "main.py"),
                   "--import-path", IMPORT, "--scene", SCENE]
            if args.no_shot:
                cmd.append("--no-shot")
            out, err, rc = run_host("pyside6", cmd)
            if err:
                print("pyside6 宿主：%s" % err)
                code |= 8
            else:
                results["pyside6"] = (parse_parity(out), rc)
                shadow_report = parse_shadows(out)

    # ── 宿主 4：PyQt5（Qt 5，走 qt5/ 降级产物）──────────────────────────
    if args.skip_pyqt5:
        print("（按参数跳过 PyQt5 宿主）")
    else:
        if not os.path.isdir(IMPORT_QT5):
            print("工装错误：Qt 5 源码树不存在 -> %s" % IMPORT_QT5)
            print("          生成：python tools/qml-downgrade.py --profile qt515")
            code |= 8
        else:
            py5 = find_python_with_pyqt5()
            if not py5:
                print("工装错误：找不到装了 PyQt5 的解释器。")
                print("          这不是代码问题 —— 补齐：./tools/setup-hosts.sh")
                print("          （或 pip install PyQt5，wheel 自带 Qt 5.15 运行时；")
                print("           装到别处时用 QSkin_PYQT5_PYTHON=/path/to/python 指定）")
                code |= 8
            else:
                cmd = [py5, os.path.join(ROOT, "examples", "hosts", "pyqt5", "main.py"),
                       "--import-path", IMPORT_QT5, "--scene", SCENE]
                if args.no_shot:
                    cmd.append("--no-shot")
                out, err, rc = run_host("pyqt5", cmd)
                if err:
                    print("pyqt5 宿主：%s" % err)
                    code |= 8
                else:
                    results["pyqt5"] = (parse_parity(out), rc)

    # ── 宿主 5：C++（Qt 5，走 qt5/ 降级产物）────────────────────────────
    if args.skip_cpp_qt5:
        print("（按参数跳过 C++ Qt 5 宿主）")
    else:
        cpp5 = os.path.join(CACHE, "hostbuild-cpp-qt5", "qdshost5.exe")
        if not os.path.exists(cpp5):
            cpp5 = os.path.join(CACHE, "hostbuild-cpp-qt5", "qdshost5")
        if not os.path.exists(cpp5):
            print("工装错误：C++ Qt 5 宿主二进制不存在 -> %s" % cpp5)
            print("          补齐：./tools/setup-hosts.sh（或 bash examples/hosts/cpp-qt5/build.sh）")
            code |= 8
        else:
            qt5_prefix = find_qt5_prefix()
            if not qt5_prefix:
                print("工装错误：找不到 Qt 5 SDK（~/.workbuddy/binaries/qt5/*/*/lib/cmake/Qt5）")
                print("          补齐：./tools/setup-hosts.sh（会装 5.15.2/mingw81_64 到该路径）")
                code |= 8
            else:
                # ⚠ Qt 的 DLL 必须在 PATH 上（否则 0xC0000135），但**只加
                #   Qt 5 自己那一套**：混进 Qt 6 的 MinGW 运行库会 0xC0000005。
                env5 = qt_runtime_env(qt5_prefix, with_tools=False)
                # 同上：tag 必须显式，否则会覆盖 Qt 6 那份 C++ 宿主的图。
                cmd = [cpp5, "--import-path", IMPORT_QT5, "--scene", SCENE,
                       "--host-tag", "cpp-qt5"]
                if args.no_shot:
                    cmd.append("--no-shot")
                out, err, rc = run_host("cpp-qt5", cmd, env=env5)
                if err:
                    print("cpp-qt5 宿主：%s" % err)
                    code |= 8
                else:
                    results["cpp-qt5"] = (parse_parity(out), rc)

    # ══════════ 判据 ══════════
    print("")
    print("═══ 五宿主对账（Qt 6：qml / cpp / pyside6 · Qt 5：pyqt5 / cpp-qt5）═══")
    for name in ("qml", "cpp", "pyside6", "pyqt5", "cpp-qt5"):
        if name not in results:
            print("  %-8s —— 未跑（见上方工装错误）" % name)
            continue
        p, rc = results[name]
        print("  %-8s qt=%-8s 解析 %-9s 实例化 %-8s 单例 %-7s fail=%-3s rc=%d"
              % (name, p.get("qt", "?"), p.get("resolved", "?"),
                 (p.get("ok", "?") + "/" + p.get("total", "?")),
                 p.get("singles", "?"), p.get("fail", "?"), rc))

        # 判据 1：契约
        problems = []
        res = p.get("resolved", "")
        if res:
            a, b = res.split("/")
            if a != b:
                problems.append("可解析 %s（应相等）" % res)
        okv, totv = p.get("ok"), p.get("total")
        if okv and totv and okv != totv:
            problems.append("可实例化 %s/%s" % (okv, totv))
        if p.get("fail", "0") not in ("0", ""):
            problems.append("fail=%s :: %s" % (p.get("fail"), p.get("failList", ""))[:160])
        sv = p.get("singles", "")
        if sv:
            a, b = sv.split("/")
            if a != b:
                problems.append("单例 %s（应相等）" % sv)
        if p.get("tokens") == "NULL":
            problems.append("Theme 单例取不到")
        if rc != 0:
            problems.append("退出码 %d" % rc)
        if problems:
            code |= 1
            print("           ✗ " + "; ".join(problems))

    # 判据 2：宿主一致（**含 Qt 5 侧两个** —— 两条线数字必须同口径）
    keys = [k for k in ("qml", "cpp", "pyside6", "pyqt5", "cpp-qt5") if k in results]
    sigs = {}
    for k in keys:
        p = results[k][0]
        sigs[k] = (p.get("resolved"), p.get("ok"), p.get("total"), p.get("singles"))
    uniq = set(sigs[k] for k in keys)
    if len(uniq) > 1:
        code |= 2
        print("  ✗ 宿主不一致：%s" % sigs)
    elif keys:
        print("  ✓ %d 个宿主结果一致：%s" % (len(keys), list(uniq)[0]))

    # 判据 4：警告清单对账
    if shadow_report is not None:
        missing = KNOWN_SHADOW - shadow_report      # 清单里有、实际没报
        extra = shadow_report - KNOWN_SHADOW        # 实际报了、清单里没有
        print("")
        print("═══ Qt 6.11 属性遮蔽警告（PySide6 宿主）═══")
        print("  已知 %d 条 / 实测 %d 条" % (len(KNOWN_SHADOW), len(shadow_report)))
        if extra:
            code |= 4
            print("  ✗ 新增遮蔽 %d 条（说明有人又覆盖了基类成员）：" % len(extra))
            for m, t in sorted(extra):
                print("      %s.%s" % (t, m))
        if missing:
            code |= 4
            print("  ✗ 清单里 %d 条未出现（问题消失了，清单该更新）：" % len(missing))
            for m, t in sorted(missing):
                print("      %s.%s" % (t, m))
        if not extra and not missing:
            print("  ✓ 与已知清单逐条吻合（%d 条，多一条少一条都红）" % len(KNOWN_SHADOW))

    # 判据 16：像素对账 —— **只比 Qt 6 侧三宿主**。
    # Qt 5（pyqt5）刻意排除：不同 Qt 版本的渲染本就不可能逐像素相同，
    # 把它算进来只会得到一个永远红的假判据。
    pixel_keys = [k for k in ("qml", "cpp", "pyside6") if k in results]
    if not args.no_shot and len(pixel_keys) >= 2:
        print("")
        print("═══ 像素对账（Qt 6 三宿主同一场景；Qt 5 侧不参与）═══")
        res, perr = pixel_compare(pixel_keys, t0=shot_t0)
        if perr:
            code |= 8
            print("  工装错误：%s" % perr)
        else:
            for a, b, d, tot in res:
                pct = 100.0 * d / tot if tot else 0.0
                if d == 0:
                    print("  ✓ %-8s vs %-8s 逐像素一致（%d 像素）" % (a, b, tot))
                else:
                    code |= 16
                    print("  ✗ %-8s vs %-8s 差异 %d/%d = %.4f%%" % (a, b, d, tot, pct))

    print("")
    if code == 0:
        print("OK  五宿主对账：全过（位掩码 0x00）")
    else:
        print("NG  五宿主对账：位掩码 0x%02X" % code)
    return code


if __name__ == "__main__":
    sys.exit(main())
