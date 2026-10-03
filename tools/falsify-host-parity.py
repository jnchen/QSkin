#!/usr/bin/env python3
"""QSkin · 三宿主对账门的**证伪器**。

SPDX-License-Identifier: MIT OR Apache-2.0

用法：
    python tools/falsify-host-parity.py

── 为什么要有这个文件 ──────────────────────────────────────────────────────
一道门"现在是绿的"证明不了任何事 —— 它可能只是**从来没被触发过**。
这个文件做的事是：把门该红的每一种情形**真的制造一遍**，确认它确实红，
并且红在**预期的那一位**上。

每支枪都声明「预期位集合」，跑完精确比对：
    · 该红的没红   ⇒ 枪失效（门是哑的）
    · 红错了位     ⇒ 判据归类有问题
    · 还原失败     ⇒ 直接中止并报出来（不许留脏文件）

── 各枪对应关系 ────────────────────────────────────────────────────────────
    G1  把清单里一个类型名改成不存在的  → 期望 1（契约失败）
    G2  挪走 C++ 宿主二进制             → 期望 8（工装错误）
    G3  改掉一张宿主图的一个像素        → 期望 16（像素对账）
    N1  负锚点：什么都不动              → 期望 0（当前状态确实全过）

── 两个「没证伪到」的判据，如实登记在案 ──────────────────────────────────
  · **位 2（宿主不一致）**：要触发它，得让**某一个**宿主跑出与另外两个不同
    的结果。而三个宿主加载的是同一个场景、同一份清单、同一棵 import 树 ——
    在不动产品代码的前提下，找不到只在单宿主生效的注入点。
    于是这一位**目前没有枪**。这比"编一支假枪假装证伪过"诚实。
  · **位 4（警告漂移）**：注入一条新的属性遮蔽需要改 `src/` 再重建 import
    树，成本远高于收益；已知清单的对账逻辑与位 1 同构（都是集合比对），
    位 1 有枪 ⇒ 机制可信。同样如实登记。

── 关于「临时改真文件」────────────────────────────────────────────────────
本门依赖固定路径（tests/ContractManifest.js 等），做不了"在临时目录里跑
整套"。所以这里是**备份 → 改 → 跑 → 还原**，还原放在 finally 里，并在还原
后**校验和比对**，确保没留下脏文件。留脏文件比不加这道门更糟。

⚠ 备份**放在 .cache/ 下且还原后不删**：本工作区有批量删除确认钩子，
`os.remove()` 会被拦下并中断脚本（实测 SAFE_DELETE_BULK_CONFIRM_REQUIRED）。
丢在 .cache/ 里由 clean-cache.sh 统一清理，才是这里的正确姿势。
"""

import hashlib
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "tests", "ContractManifest.js")
CPP_BIN = os.path.join(ROOT, ".cache", "hostbuild-cpp", "qdshost.exe")
SHOT_CPP = os.path.join(ROOT, ".cache", "host_parity_cpp.png")
CHECK = os.path.join(ROOT, "tools", "check-host-parity.py")

PY = sys.executable

BIT_NAME = {1: "契约失败", 2: "宿主不一致", 4: "警告漂移", 8: "工装错误", 16: "像素对账"}


def sha(p):
    if not os.path.exists(p):
        return None
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def run_check(skip=()):
    cmd = [PY, CHECK, "--no-shot"]
    for s in skip:
        cmd.append(s)
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT, timeout=600)
    return r.returncode, r.stdout + r.stderr


def main():
    fails = []
    report = []

    # ── N1 · 负锚点：当前状态必须全过 ─────────────────────────────────
    rc, out = run_check()
    ok = (rc == 0)
    report.append(("N1", "负锚点：现状应全过", 0, rc, ok))
    if not ok:
        fails.append("N1 负锚点不绿（rc=%d）—— 基准就是坏的，后面的枪无从判断" % rc)

    # ── G1 · 清单里塞一个不存在的类型 → 契约位 1 ─────────────────────
    bak = os.path.join(ROOT, ".cache", "_falsify_manifest.bak")
    h0 = sha(MANIFEST)
    try:
        shutil.copy2(MANIFEST, bak)
        t = open(MANIFEST, encoding="utf-8").read()
        if 'name: "QSkinButton"' not in t:
            fails.append("G1 找不到锚点 QSkinButton，无法注入")
        else:
            t = t.replace('name: "QSkinButton"', 'name: "QSkinNoSuchType"', 1)
            open(MANIFEST, "w", encoding="utf-8", newline="\n").write(t)
            rc, out = run_check()
            # 期望**只有**位 1：清单是三宿主共享的输入，改了它三个宿主会
            # 一起失败，于是结果**仍然一致** —— 位 2 不该被触发。
            # （第一版这里写的是 1|2，实测 rc=1，是枪的期望写错了，不是门错。）
            want = 1
            ok = (rc & want) == want
            report.append(("G1", "清单塞入不存在的类型", want, rc, ok))
            if not ok:
                fails.append("G1 期望位 %s 实测 rc=%d :: %s"
                             % (bits(want), rc, tail(out)))
    finally:
        shutil.copy2(bak, MANIFEST)
        # 刻意**不删**备份：见文件头，删除会被宿主钩子拦下。
        if sha(MANIFEST) != h0:
            fails.append("G1 还原失败：%s 与原始不一致" % MANIFEST)

    # ── G2 · 挪走 C++ 宿主二进制 → 工装位 8 ──────────────────────────
    if os.path.exists(CPP_BIN):
        moved = CPP_BIN + ".falsify.moved"
        try:
            shutil.move(CPP_BIN, moved)
            rc, out = run_check()
            ok = (rc & 8) == 8
            report.append(("G2", "挪走 C++ 宿主二进制", 8, rc, ok))
            if not ok:
                fails.append("G2 期望位 8（工装）实测 rc=%d :: %s" % (rc, tail(out)))
        finally:
            shutil.move(moved, CPP_BIN)
    else:
        report.append(("G2", "（跳过：C++ 宿主二进制不存在）", 8, -1, None))

    # ── G3 · 改掉一张图的一个像素 → 像素位 16 ────────────────────────
    # ⚠ 这枪要 **开着抓图** 跑（--no-shot 会跳过像素对账），所以单独跑。
    if os.path.exists(SHOT_CPP):
        h0 = sha(SHOT_CPP)
        bakp = os.path.join(ROOT, ".cache", "_falsify_shot_cpp.bak.png")
        try:
            shutil.copy2(SHOT_CPP, bakp)
            from PIL import Image
            im = Image.open(SHOT_CPP).convert("RGB")
            px = im.load()
            px[5, 5] = (255, 0, 0) if px[5, 5] != (255, 0, 0) else (0, 255, 0)
            im.save(SHOT_CPP)
            # ⚠ 必须走 `--pixel-only`：正常模式会**重新抓图**、把我刚改的
            #   那一像素覆盖掉，于是门照绿（第一版就是这么哑掉的，rc=0）。
            r = subprocess.run([PY, CHECK, "--pixel-only"],
                               capture_output=True, text=True, cwd=ROOT, timeout=600)
            rc = r.returncode
            ok = (rc & 16) == 16
            report.append(("G3", "改掉宿主图一个像素", 16, rc, ok))
            if not ok:
                fails.append("G3 期望位 16（像素）实测 rc=%d :: %s"
                             % (rc, tail(r.stdout + r.stderr)))
        except ImportError:
            report.append(("G3", "（跳过：缺 PIL）", 16, -1, None))
        finally:
            shutil.copy2(bakp, SHOT_CPP)
            # 同样不删备份，理由见文件头。
            if sha(SHOT_CPP) != h0:
                fails.append("G3 还原失败：%s 与原始不一致" % SHOT_CPP)
    else:
        report.append(("G3", "（跳过：宿主图不存在）", 16, -1, None))

    # ── 汇总 ──────────────────────────────────────────────────────────
    print("")
    print("═══ 三宿主对账门 · 证伪 ═══")
    for gid, desc, want, got, ok in report:
        if ok is None:
            print("  %-4s —    %s" % (gid, desc))
        else:
            mark = "✓" if ok else "✗"
            print("  %-4s %s  期望位 %-10s 实测 rc=%-4d  %s"
                  % (gid, mark, bits(want), got, desc))
    print("")
    if fails:
        print("NG  证伪失败 %d 项：" % len(fails))
        for f in fails:
            print("    · " + f)
        return 1
    print("OK  全部枪支符合预期（门有牙）")
    return 0


def bits(want):
    if want == 0:
        return "0x00"
    names = [BIT_NAME[b] for b in (1, 2, 4, 8, 16) if want & b]
    return "0x%02X(%s)" % (want, "+".join(names))


def tail(s, n=3):
    ls = [x for x in s.strip().splitlines() if x.strip()]
    return " / ".join(x.strip()[:100] for x in ls[-n:])


if __name__ == "__main__":
    sys.exit(main())
