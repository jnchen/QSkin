# -*- coding: utf-8 -*-
"""发布面泄露门禁的证伪器 —— 每一枪声明「预期的红位集合」，跑完**精确比对**。

枪单（位掩码：1 判据1 ／ 2 判据2 ／ 4 判据3 ／ 8 工装）：

    D0  = 0   干净副本（**空面枪** —— 必须绿；不绿说明判据在乱报）
    D1  = 1   盘符路径 `C:\\Users\\...`
    D2  = 1   `/Users/<name>/...`
    D3  = 1   `AppData`
    D4  = 1   `.workbuddy`
    D5  = 1   用户名（**动态取**，与门禁同源）
    D6  = 2   `mutate_m99.py`
    D7  = 2   `_verify_m99.py`
    D8  = 2   `shot_m99.qml`
    D9  = 2   `_probe_m99.py`
    D10 = 4   `mingw_64`
    D11 = 4   `.qt/9.9.9/`
    D12 = 8   缺一份发布文档
    D13 = 8   豁免表格式坏
    D14 = 2   豁免表里有一条**没命中**的条目（该销账了）
    D15 = 0   **负锚点**：`https://…` 与 `qrc:/…` 不许红（本批实测的假阳性源）
    D16 = 0   **负锚点**：JSON 里转义的仓库内相对路径 `\\src\\contracts\\X.qml` 不许红
    D17 = 16  `ROADMAP.md`（发行版里不存在，指向它 = 死路）
    D18 = 16  `docs/PROGRESS.md`（同上）
    D19 = 0   **负锚点**：只提"排期文档"这个**角色**、不带文件名，不许红

D15 / D16 是**同族的空面枪**：它们是"看起来像违规、其实不是"的样本。
**一条假阳性就足以让人无视报告** —— 所以给假阳性单独配枪，而不是靠人记得。

跑法：
    python tools/falsify-doc-leak.py          # 或 ./tools/falsify-doc-leak.sh

它把四份文档的最小副本写进 `.cache/_dltmp/`（**不碰真仓库**），
按 `--src` 指过去跑门禁，跑完删掉临时树。
"""
import io
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = HERE
while not os.path.isdir(os.path.join(ROOT, "src")) and len(ROOT) > 3:
    ROOT = os.path.dirname(ROOT)

GATE = os.path.join(ROOT, "tools", "check-doc-leak.py")
TMP = os.path.join(ROOT, ".cache", "_dltmp")
DOCS = ["README.md", "COVERAGE.md", "CHANGELOG.md", os.path.join("docs", "PITFALLS.md")]

CLEAN = {
    "README.md": "# QSkin\n\n一个纯 QML 的控件库。\n",
    "COVERAGE.md": "# 覆盖度清单\n\n| 项 | 状态 |\n|---|---|\n| Card | 已落地 |\n",
    "CHANGELOG.md": "# 变更记录\n\n## 0.0.1\n\n- 初版\n",
    os.path.join("docs", "PITFALLS.md"): "# 踩过的坑\n\n1. 布局只在子项 implicit 尺寸变化时重跑。\n",
}


def python_exe():
    for c in ("python3", "python"):
        p = shutil.which(c)
        if p:
            return p
    return sys.executable


def username():
    import getpass
    try:
        return getpass.getuser()
    except Exception:
        return os.path.basename(os.path.expanduser("~"))


def build(inject=None, drop=None, exempt=None):
    if os.path.isdir(TMP):
        shutil.rmtree(TMP, ignore_errors=True)
    for rel, text in CLEAN.items():
        p = os.path.join(TMP, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        body = text
        if inject and rel == "README.md":
            body += "\n" + inject + "\n"
        io.open(p, "wb").write(body.encode("utf-8"))
    # TMP 是"最小仓库"，而判据 4 要与 .gitignore 对账 —— 少了它，
    # 门禁会报"判据的输入没了"（工装位 8），于是**所有枪的期望值都被污染**。
    io.open(os.path.join(TMP, ".gitignore"), "wb").write(
        b"/ROADMAP.md\n/docs/PROGRESS.md\n")
    if drop:
        os.remove(os.path.join(TMP, drop))
    if exempt is not None:
        exp = os.path.join(TMP, "exempt.txt")
        io.open(exp, "wb").write(exempt.encode("utf-8"))
    else:
        exp = os.path.join(ROOT, "tools", "doc-leak-exempt.txt")
    return exp


def run(exp):
    cmd = [python_exe(), GATE, "--src", TMP, "--exempt", exp]
    pr = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = pr.stdout.decode("utf-8", "replace")
    m = re.search(r"位掩码 0x([0-9A-Fa-f]{2})", out)
    rc = int(m.group(1), 16) if m else pr.returncode
    return rc, out


SHOTS = [
    ("D0", None, None, None, 0x00, "干净副本（空面枪）"),
    ("D1", r"见 C:\Users\someone\proj\qds\README.md 的说明", None, None, 0x01, "盘符路径"),
    ("D2", "参考 /Users/alice/work/src 下的实现", None, None, 0x01, "/Users/<name>/"),
    ("D3", r"落在 AppData\Local 下面", None, None, 0x01, "AppData"),
    ("D4", "中间产物在 .workbuddy/memory 里", None, None, 0x01, ".workbuddy"),
    ("D5", None, None, None, 0x01, "用户名（动态注入）"),
    ("D6", "对照 tools/mutate_m99.py 的第 3 枪", None, None, 0x02, "mutate_*"),
    ("D7", "核验件 _verify_m99.py 量的是格宽", None, None, 0x02, "_verify_*"),
    ("D8", "抓图入口 shot_m99.qml 的产物", None, None, 0x02, "shot_m*"),
    ("D9", "探针 _probe_m99.py 验过 size hint", None, None, 0x02, "_probe_*"),
    ("D10", "本机工具链在 mingw_64 那一档", None, None, 0x04, "mingw_64"),
    ("D11", "Qt 装在 .qt/9.9.9/ 下面", None, None, 0x04, ".qt/<x.y>"),
    ("D12", None, os.path.join("docs", "PITFALLS.md"), None, 0x08, "缺一份发布文档"),
    ("D13", None, None, "2坏格式一行\n", 0x08, "豁免表格式坏"),
    ("D14", None, None, "# 注释\n2\tREADME.md\t这一行现在不在了\n", 0x02, "豁免条该销账"),
    ("D15", "参考 https://semver.org/lang/zh-CN/ 与 qrc:/save.svg",
     None, None, 0x00, "负锚点：URL 与 qrc 不许红"),
    ("D16", r'形如 "targets":["...\\src\\contracts\\QSkinPopover.qml.mutbak"]',
     None, None, 0x00, "负锚点：转义的仓库内相对路径不许红"),
    ("D17", "复核后维持原裁决，理由见 `ROADMAP.md` §8.7。",
     None, None, 0x10, "指向不发布文档：ROADMAP.md"),
    ("D18", "这一轮的过程见 `docs/PROGRESS.md` 的 M17。",
     None, None, 0x10, "指向不发布文档：docs/PROGRESS.md"),
    ("D19", "内部排期与发布 checklist 写在排期文档里（不发布）",
     None, None, 0x00, "负锚点：只说'排期文档'这个**角色**、不带文件名，不许红"),
]


def main():
    if not os.path.exists(GATE):
        print("!! 找不到门禁本体：%s" % GATE)
        return 1
    print("ROOT = %s" % ROOT)
    uname = username()
    print("动态用户名 = %r（长度 %d，>=4 才查）" % (uname, len(uname)))
    print("")

    fails = []
    for sid, inj, drop, exc, want, why in SHOTS:
        if sid == "D5":
            if len(uname) < 4:
                print("%-5s SKIP  用户名太短，门禁故意不查（阈值 4）" % sid)
                continue
            inj = "本机用户是 " + uname + " ，见其目录"
        exp = build(inject=inj, drop=drop, exempt=exc)
        rc, out = run(exp)
        ok = (rc == want)
        print("%-5s %s  期望 0x%02X ／ 实测 0x%02X   %s"
              % (sid, "OK  " if ok else "MISS", want, rc, why))
        if not ok:
            fails.append((sid, want, rc))
            for ln in out.split("\n"):
                if ("失败" in ln or "工装错误" in ln):
                    print("        " + ln.strip()[:100])

    shutil.rmtree(TMP, ignore_errors=True)

    print("")
    if fails:
        print("!! %d 枪未按声明命中：%s" % (len(fails), fails))
        return 1
    print("全部枪按声明命中 ✔（共 %d 枪）" % len(SHOTS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
