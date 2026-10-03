# -*- coding: utf-8 -*-
"""M33-7 · 运行期翻译门的证伪器

七枪打的是 tools/check-i18n-runtime.sh 的四条判据与它读的两面读数。

── 为什么证伪体**不篡改仓库里的件** ────────────────────────────────────
这个门有两个环境口子（`QSkin_I18N_SCENE` / `QSkin_I18N_QM` / `QSkin_I18N_IMPORTS` /
`QSkin_I18N_EXPECT_RED`），所以每枪的变异体都落在 `.cache/_falsify_i18n/`，
跑完**不需要还原任何仓库件**。收尾仍然**逐件核 md5**：证明"不该被碰的没被碰"
（本项目原话：批量改写要证「不该改的没被碰」）。

── 枪单（每枪都要**先声明**预期，跑完逐项比对）─────────────────────────
  R1  把 `--translation` 指向一份**全未翻译**的 `.qm`      → RC 1（面 A 红）
  R2  场景里**一条断言都不跑**（掩码恒 0）                → RC 2（面 B 绿 = 门是空的）
  R3  把**声明**改错（EXPECT_RED 63，实测 127）           → RC 4（掩码不符）
  R4  `QSkin_I18N_QM` 指向不存在的文件                      → RC 8（工装）
  R5  import 树副本的 mtime 拨回 2000 年                  → RC 8（工装：树陈旧）
  R6  场景里写一个不存在的属性（引擎静态错误）            → RC 8（工装：一条断言没跑）
  R7  把 `QSkinCalendar.cellSize` 压到 20（英文星期头 36 装不下） → RC 1，且
      面 A 掩码**恰 128**（只有 bit7）、面 B 掩码**恰 127** —— 这条是 bit[7]
      那个"度量 bit"的同族红面枪（它平时两面都绿，见 check 脚本头部）
      ⚠ 打 `width` 不动这一格（panel 模式下 `colWidth == cellSize`）——
        第一版就是打 width、**没中**，记在 make_scene_narrow() 的 docstring 里。

  ⚠ R5 会动 `.cache/qmlimports` 里一个副本的 mtime（那是可丢弃目录）。跑完拨回。
  ⚠ R3 打的是「声明」不是「场景」—— 它证明的是"判据 4 真在读声明"，
    与"场景变了没同步声明"是同一条判据的两面。

用法：python tools/falsify-i18n-runtime.py
退出码：0 = 七枪全部与声明相符；1 = 有枪不符（**逐枪打印实测 vs 声明**）。
"""

import hashlib
import io
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, ".cache", "_falsify_i18n")
SCENE = os.path.join(ROOT, "tests", "scene_i18n.qml")
QM = os.path.join(ROOT, "i18n", "qskin_en.qm")
IMPORTS = os.path.join(ROOT, ".cache", "qmlimports")
CHECKER = os.path.join(ROOT, "tools", "check-i18n-runtime.sh")
REF_COPY = os.path.join(IMPORTS, "QSkin", "Foundation", "DateUtil.qml")

# 收尾核 md5 的「不该被碰」清单。
UNTOUCHED = [
    "src/foundation/DateUtil.qml",
    "src/contracts/QSkinCalendar.qml",
    "src/contracts/QSkinDatePicker.qml",
    "i18n/qskin_en.ts",
    "i18n/qskin_en.qm",
    "tests/scene_i18n.qml",
    "tools/check-i18n-runtime.sh",
]


def md5(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()


def find_qt():
    root = os.environ.get("QSkin_QT", "")
    if root:
        return root
    qt = os.path.join(ROOT, ".qt")
    for ver in sorted(os.listdir(qt)) if os.path.isdir(qt) else []:
        for plat in sorted(os.listdir(os.path.join(qt, ver))):
            d = os.path.join(qt, ver, plat)
            if os.path.exists(os.path.join(d, "bin", "lupdate.exe")) or \
               os.path.exists(os.path.join(d, "bin", "lupdate")):
                return d
    return ""


QT = find_qt()


def run_checker(env_extra):
    env = dict(os.environ)
    env.update(env_extra)
    p = subprocess.run(["bash", CHECKER], cwd=ROOT, env=env,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.stdout.decode("utf-8", "replace")
    masks = {}
    for k in ("MASK_A", "MASK_B"):
        m = re.search(r"^%s=(\d+)$" % k, out, re.M)
        masks[k] = int(m.group(1)) if m else None
    return p.returncode, masks, out


def write(path, text, newline=""):
    with io.open(path, "w", encoding="utf-8", newline=newline) as f:
        f.write(text)


def read(path):
    with io.open(path, "r", encoding="utf-8", newline="") as f:
        return f.read()


# ── 变异体构造 ───────────────────────────────────────────────────────────

def make_untranslated_qm():
    """R1：用 lupdate 重抽一份**全未翻译**的 .ts，再 lrelease → 空 .qm。"""
    ts = os.path.join(WORK, "r1_untranslated.ts")
    qm = os.path.join(WORK, "r1_untranslated.qm")
    lu = os.path.join(QT, "bin", "lupdate.exe")
    lr = os.path.join(QT, "bin", "lrelease.exe")
    if not os.path.exists(lu):
        lu, lr = lu[:-4], lr[:-4]
    p = subprocess.run([lu, "src", "-ts", ts, "-no-obsolete"],
                       cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if p.returncode != 0:
        raise RuntimeError("lupdate 失败：%s" % p.stdout.decode("utf-8", "replace"))
    p = subprocess.run([lr, ts, "-qm", qm],
                       cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if p.returncode != 0:
        raise RuntimeError("lrelease 失败：%s" % p.stdout.decode("utf-8", "replace"))
    return qm


def make_scene_no_assertions():
    """R2：把 check() 里 8 条调用全注释掉 —— 掩码恒 0（= 门是空的）。"""
    src = read(SCENE)
    n = len(re.findall(r"^        root\.check\w+\(\)$", src, re.M))
    out = re.sub(r"^        root\.check(\w+)\(\)$",
                 r"        // R2 变异：跳过 check\1()", src, flags=re.M)
    if n != 8:
        raise RuntimeError("R2 只匹配到 %d 条 check 调用（声称 8）" % n)
    p = os.path.join(WORK, "r2_scene_skip.qml")
    write(p, out)
    return p, n


def make_scene_bad_property():
    """R6：写一个不存在的属性 → 引擎静态错误，一条断言都不会跑。"""
    src = read(SCENE)
    old = "QSkinCalendar { id: cal; width: 320; panelMonth: 9 }"
    if src.count(old) != 1:
        raise RuntimeError("R6 锚点不唯一（%d）" % src.count(old))
    out = src.replace(old, "QSkinCalendar { id: cal; width: 320; panelMonth: 9; "
                           "noSuchProperty: 1 }")
    p = os.path.join(WORK, "r6_scene_badprop.qml")
    write(p, out)
    return p


def make_scene_narrow():
    """R7：把星期头的**格宽**压到装不下英文缩写。

    ⚠ 第一版打的是 `QSkinCalendar.width`（320 → 176），**没中** —— 面 A 掩码 0。
      先查自己的理解：`colWidth` 的公式是

          fullscreen ? Math.max(1, gridArea.width / 7) : cellSize

      **panel 模式（默认）下它就是 `cellSize`，与控件宽度无关** ——
      所以压 width 根本不动这一格。该压的是 `cellSize`（默认 36）。
      实测中文星期头 12px、英文 36px：cellSize 压到 20 时中文仍装得下、
      英文装不下 ⇒ 只有 bit[7] 该红。**这正是"面不符先查自己的理解"那条。**
    """
    src = read(SCENE)
    old = "QSkinCalendar { id: cal; width: 320; panelMonth: 9 }"
    if src.count(old) != 1:
        raise RuntimeError("R7 锚点不唯一（%d）" % src.count(old))
    out = src.replace(old, "QSkinCalendar { id: cal; cellSize: 20; panelMonth: 9 }")
    p = os.path.join(WORK, "r7_scene_narrow.qml")
    write(p, out)
    return p


# ── 主流程 ───────────────────────────────────────────────────────────────

def main():
    if not QT:
        print("!! 找不到 Qt（lupdate / qml）—— 证伪器跑不了。**这不代表门是好的。**")
        return 1

    # ⚠ 不用 rmtree：宿主对"批量删除"有确认钩子，趟一次就够（本仓的老坑）。
    #   变异体是定名覆盖，同一个目录反复用即可。
    if not os.path.isdir(WORK):
        os.makedirs(WORK)

    before = {f: md5(os.path.join(ROOT, f)) for f in UNTOUCHED}
    ref_mtime = None
    if os.path.exists(REF_COPY):
        ref_mtime = os.path.getmtime(REF_COPY)

    scenes = {}
    scenes["r2"], n_r2 = make_scene_no_assertions()
    scenes["r6"] = make_scene_bad_property()
    scenes["r7"] = make_scene_narrow()
    qm_untranslated = make_untranslated_qm()
    print("变异体就位：%s" % os.path.relpath(WORK, ROOT))
    print("  R2 注释掉 %d 条 check 调用" % n_r2)
    print("  R1 未翻译的 .qm = %d B" % os.path.getsize(qm_untranslated))
    print()

    # 枪单：名字 / 环境覆盖 / 预期 RC / 预期的掩码（可选）
    guns = [
        ("R1 未翻译的 .qm → 面 A 必须红",
         {"QSkin_I18N_QM": qm_untranslated}, 1, None),
        ("R2 场景一条断言都不跑 → 面 B 必须被认出是空的",
         {"QSkin_I18N_SCENE": scenes["r2"]}, 2, None),
        ("R3 声明改错（EXPECT_RED=63，实测 127）→ 判据 4 必须红",
         {"QSkin_I18N_EXPECT_RED": "63"}, 4, None),
        ("R4 .qm 不存在 → 工装错误",
         {"QSkin_I18N_QM": os.path.join(WORK, "no_such.qm")}, 8, None),
        ("R5 import 树 mtime 拨回 2000 → 工装错误（树陈旧）",
         "__STALE__", 8, None),
        ("R6 不存在的属性 → 工装错误（一条断言没跑）",
         {"QSkin_I18N_SCENE": scenes["r6"]}, 8, None),
        ("R7 列宽压到装不下英文星期头 → 面 A 恰 bit7、面 B 恰 bit0~6",
         {"QSkin_I18N_SCENE": scenes["r7"]}, 1, {"MASK_A": 128, "MASK_B": 127}),
    ]

    bad = []
    for name, env, want_rc, want_masks in guns:
        stale_gun = (env == "__STALE__")
        if stale_gun:
            if ref_mtime is None:
                bad.append("%s：import 树不在，跳过（**不能算通过**）" % name)
                continue
            os.utime(REF_COPY, (946684800, 946684800))   # 2000-01-01
            env = {}
        rc, masks, out = run_checker(env)
        if stale_gun:
            os.utime(REF_COPY, (ref_mtime, ref_mtime))   # 拨回

        ok = (rc == want_rc)
        detail = "RC %d（期望 %d）" % (rc, want_rc)
        if want_masks:
            for k, v in want_masks.items():
                detail += " ／ %s %s（期望 %s）" % (k, masks.get(k), v)
                if masks.get(k) != v:
                    ok = False
        print("%s %-52s %s" % ("✓" if ok else "✗", name, detail))
        if not ok:
            bad.append(name)
            for ln in out.splitlines():
                if ln.startswith("NG") or ln.startswith("!!"):
                    print("      | " + ln)

    # ── 收尾：证"不该被碰的没被碰" ──────────────────────────────────────
    print()
    drift = [f for f in UNTOUCHED
             if md5(os.path.join(ROOT, f)) != before[f]]
    if drift:
        print("!! 有仓库件被改动（证伪器不该碰它们）：%s" % drift)
        return 1
    print("收尾核对：%d 个仓库件 md5 逐件未变；import 副本 mtime 已拨回。"
          % len(UNTOUCHED))

    print()
    if bad:
        print("NG  %d/%d 枪与声明不符：%s" % (len(bad), len(guns), bad))
        return 1
    print("OK  %d/%d 枪全部与声明相符。" % (len(guns), len(guns)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
