#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""QSkin i18n 门禁 —— 三道判据，每道都能被证伪。

为什么需要它（而不是"记得加 qsTr"）
====================================
本仓有 **109 行**库自产中文文案，散在 **50 个文件**里。靠人记 = 必然漂。
更要紧的是三条**很容易走进去的错**，每一条都有具体代价：

  · 给 `src/foundation/*.js` 加 `qsTr` —— 那 5 个文件是**纯算路层**，必须能在
    **node 里裸跑**（`QRCodeEncoder.js` 自带 `module.exports`；
    `ColorUtil.js` / `FuzzyMatch.js` 被 `tools/check-color-util.js` /
    `tools/check-fuzzy-match.js` 直接 `require`）。**node 里没有 qsTr** ——
    一加就打断三道 node 门禁。所以这条是**反向判据：出现即红**。
  · 用 `+` 拼文案而不给占位符 —— `lupdate` 会把它切成碎片，译者拿不到语序。
  · 加了 `qsTr` 但忘了更新 `.ts` —— 于是 `.ts` 与源码静默漂开，
    翻译**永远对不上**，而且没有任何东西会红。

三道判据
========
  判据 1（新增即红）
      `src/**` 里含 CJK 的"用户可见文案"行，要么命中豁免表，要么是 `qsTr` 形式。
      两样都不是 = 红。**反向**：`src/foundation/*.js` 里出现 `qsTr` = 红。

  判据 2（修了要销账 —— 双向对账）
      豁免表里每一条都必须"仍然欠着"：
        · 源码里那条已经改成 `qsTr` 形式了  → 该删条目了，红（催销账）
        · 源码里彻底找不到那条了            → 条目漂了，红
      这条让"**修一处 = 删一条**"成为强制动作，也让删条目本身成为**证伪**。

  判据 3（资产同步）
      `i18n/*.ts` 的 message 集合 == 源码里 `qsTr` 的集合（跑 lupdate 实抽比对）；
      `i18n/*.qm` == `lrelease(.ts)` 的产物。

退出码（位掩码，与 `tools/check-runtime-warn.py` 同一套约定）
=============================================================
  0 = 全绿
  1 = 判据 1 红
  2 = 判据 2 红
  4 = 判据 3 红
  8 = 工装问题（找不到 lupdate / lrelease / 豁免表）—— **一律不算通过**

已知近似（写在这里，不当成精确判据用）
======================================
  · "这一行是 `qsTr` 形式"的判定 = **本行**内出现 `qsTr(`，**不看前后行**。
    一开始用的是"本行或前两行"的窗口，想容下跨行调用
    `property string x: qsTr(\n  "很长的文案")`。**实测证明那个窗口更坏** ——
    它让相邻两行互相污染。证伪器 G5 首跑就撞上了：

        property string cancelText:  qsTr("取消")   <- 被改的
        property string confirmText: "确定"          <- 没被改的，却报了"该销账"

    一条假阳性就足以让人开始无视报告（本项目最贵的一种失败）。
    收窄前先量过：全仓"靠窗口才判成 qsTr"的行 = **0 条**，收窄不误伤。
    代价：真写了跨行 `qsTr` 时会报"未走 qsTr"，加一条豁免即可 ——
    **假阴性可以补，假阳性会毁掉报告的可信度。**
    真正的判据是判据 3（lupdate 实抽），它不依赖这个标记。
  · 豁免表的键是 **（相对路径, 归一化行内容）**，不是行号 —— 行号会漂。
"""

import argparse
import collections
import io
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
EXEMPT_PATH = os.path.join(ROOT, 'tools', 'i18n-exempt.txt')
I18N_DIR = os.path.join(ROOT, 'i18n')

CJK = re.compile(r'[\u3400-\u9fff\u3000-\u303f\uff01-\uff5e]')

# 算路层：这几个 .js 必须能在 node 里裸跑，**禁止出现 qsTr**（反向判据）
NODE_RUNNABLE_DIR = os.path.join(ROOT, 'src', 'foundation')

# qsTr 的字面标记。判定取**本行**，不取窗口 —— 见文末"已知近似"。
QSTR = 'qsTr('


# ---------------------------------------------------------------- 工具

def strip_comments(text):
    """去 /* */ 与行内 //（引号内的 // 不动）。QML 与 JS 共用这一条规则。"""
    text = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group(0).count('\n'), text,
                  flags=re.S)
    out = []
    for ln in text.split('\n'):
        inq, q, i, cut = False, '', 0, None
        while i < len(ln):
            c = ln[i]
            if inq:
                if c == '\\':
                    i += 2
                    continue
                if c == q:
                    inq = False
            elif c in '"\'':
                inq, q = True, c
            elif c == '/' and i + 1 < len(ln) and ln[i + 1] == '/':
                cut = i
                break
            i += 1
        out.append(ln[:cut] if cut is not None else ln)
    return '\n'.join(out)


def norm(s):
    """归一化行指纹：去首尾空白 + 内部连续空白压成一个空格。

    源码里的缩进/tab 与空格等价 —— 指纹只关心"写了什么文案"，不关心排布。
    """
    return re.sub(r'\s+', ' ', s).strip()


def load_exempt(path):
    """豁免表 → (Counter[(rel, 指纹)] , {键: 组})。文件不存在返回 (None, None)。"""
    if not os.path.exists(path):
        return None, None
    cnt = collections.Counter()
    grp = {}
    for raw in io.open(path, encoding='utf-8', newline='').read().split('\n'):
        s = raw.rstrip('\r')
        if not s.strip() or s.lstrip().startswith('#'):
            continue
        parts = s.split('\t')
        if len(parts) != 3:
            raise ValueError('豁免表格式错（应为「组<TAB>路径<TAB>行指纹」）：%r' % s)
        g, rel, fp = (p.strip() for p in parts)
        key = (rel, fp)
        cnt[key] += 1
        grp[key] = g
    return cnt, grp


def scan_src(src=None):
    """扫 `src/**/*.qml|*.js`（去注释后）里含 CJK 的行。"""
    src = src or SRC
    # relpath 相对 src 的**父目录**算，不是相对 ROOT ——
    # 这样证伪器把 src 复制到临时目录后，相对路径仍是 `src/contracts/X.qml`，
    # 与豁免表对得上。否则副本里每一行都会被判成"新增"，判据 1 满屏假阳性。
    base = os.path.dirname(os.path.abspath(src))
    hits = []
    for dirpath, _dirs, names in os.walk(src):
        for name in sorted(names):
            if not name.endswith(('.qml', '.js')):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, base).replace('\\', '/')
            raw = io.open(full, encoding='utf-8', newline='').read()
            lines = strip_comments(raw).split('\n')
            for i, ln in enumerate(lines):
                if not CJK.search(ln):
                    continue
                hits.append({
                    'rel': rel,
                    'line': i + 1,
                    'norm': norm(ln),
                    'raw': ln.strip()[:110],
                    'qstr': QSTR in ln,
                })
    return hits


def run(cmd):
    p = subprocess.run(cmd, capture_output=True)
    return (p.returncode,
            p.stdout.decode('utf-8', 'replace'),
            p.stderr.decode('utf-8', 'replace'))


# ---------------------------------------------------------------- 判据 1

def check_new(hits, exempt_cnt, src=None):
    """新增即红 + 反向（算路层禁止 qsTr）。"""
    src = src or SRC
    base = os.path.dirname(os.path.abspath(src))
    problems = []
    for h in hits:
        key = (h['rel'], h['norm'])
        if exempt_cnt.get(key, 0) > 0:
            continue                       # 存量欠账，放行（判据 2 管它）
        if not h['qstr']:
            problems.append('%s:%d  新增了未走 qsTr 的文案: %s'
                            % (h['rel'], h['line'], h['raw']))

    # 反向：算路层（node 可裸跑的 .js）禁止 qsTr。
    # 它跟着 --src 走 —— 否则证伪器往副本里塞 qsTr 时这一枪打不中。
    node_dir = os.path.join(src, 'foundation')
    for dirpath, _dirs, names in os.walk(node_dir):
        for name in sorted(names):
            if not name.endswith('.js'):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, base).replace('\\', '/')
            for i, ln in enumerate(
                    strip_comments(io.open(full, encoding='utf-8',
                                           newline='').read()).split('\n'), 1):
                if QSTR in ln:
                    problems.append('%s:%d  算路层（node 可裸跑）里出现了 qsTr —— '
                                    'node 没有 qsTr，会打断 check-*.js 门禁: %s'
                                    % (rel, i, ln.strip()[:100]))
    return problems


# ---------------------------------------------------------------- 判据 2

def check_ledger(hits, exempt_cnt, exempt_grp):
    """双向对账：该销账的销账，漂掉的条目报出来。"""
    problems = []
    seen = collections.Counter()
    fixed = collections.Counter()          # 键 -> 已改成 qsTr 的出现次数
    for h in hits:
        key = (h['rel'], h['norm'])
        if exempt_cnt.get(key, 0) <= 0:
            continue
        seen[key] += 1
        if h['qstr']:
            fixed[key] += 1

    for key, want in sorted(exempt_cnt.items()):
        got = seen.get(key, 0)
        if got == 0:
            problems.append('过期豁免（源码里已找不到这一行）：[%s] %s  |  %s'
                            % (exempt_grp.get(key, '?'), key[0], key[1][:80]))
            continue
        if got < want:
            problems.append('豁免表条目数多于源码命中数（%d vs %d）：[%s] %s  |  %s'
                            % (want, got, exempt_grp.get(key, '?'), key[0],
                               key[1][:80]))
        if fixed.get(key, 0) > 0:
            problems.append('该销账了（源码已改成 qsTr，请删掉豁免条目）：[%s] %s  |  %s'
                            % (exempt_grp.get(key, '?'), key[0], key[1][:80]))
    return problems


# ---------------------------------------------------------------- 判据 3

def ts_messages(path):
    """读 .ts → Counter[(context, source)]。"""
    root = ET.parse(path).getroot()
    out = collections.Counter()
    for ctx in root.findall('context'):
        name = ctx.findtext('name') or ''
        for msg in ctx.findall('message'):
            out[(name, msg.findtext('source') or '')] += 1
    return out


def check_assets(lupdate, lrelease, src, i18n_dir):
    """`i18n/*.ts` 与源码同步；`i18n/*.qm` 与 `.ts` 同步。

    `i18n_dir` 是参数而不是常量 —— 证伪器要拿**临时目录**打这两条判据
    （从任一侧制造"不同步"都行：改源码、或改 .ts，效果一样）。
    """
    problems = []
    if not os.path.isdir(i18n_dir):
        return ['i18n/ 目录不存在 —— 翻译资产尚未建立']

    tss = sorted(n for n in os.listdir(i18n_dir) if n.endswith('.ts'))
    if not tss:
        return ['i18n/ 下没有任何 .ts 文件']

    with tempfile.TemporaryDirectory() as td:
        for tsname in tss:
            ts_path = os.path.join(i18n_dir, tsname)
            # --- 3a: .ts 与源码同步 ---
            tmp_ts = os.path.join(td, tsname)
            rc, out, err = run([lupdate, src, '-ts', tmp_ts, '-no-obsolete'])
            if rc != 0:
                problems.append('lupdate 失败（%d）：%s' % (rc, (err or out).strip()[:200]))
                continue
            want = ts_messages(tmp_ts)
            have = ts_messages(ts_path)
            for k in sorted(set(want) | set(have)):
                if want.get(k, 0) != have.get(k, 0):
                    problems.append('.ts 与源码不同步 [%s] %s → 源码 %d 条 / .ts %d 条'
                                    % (tsname, k[0] + ' | ' + k[1][:60],
                                       want.get(k, 0), have.get(k, 0)))

            # --- 3b: .qm 与 .ts 同步 ---
            qmname = tsname[:-3] + '.qm'
            qm_path = os.path.join(i18n_dir, qmname)
            if not os.path.exists(qm_path):
                problems.append('缺少 %s（用 ./tools/i18n.sh build 生成）' % qmname)
                continue
            tmp_qm = os.path.join(td, qmname)
            rc, out, err = run([lrelease, ts_path, '-qm', tmp_qm])
            if rc != 0:
                problems.append('lrelease 失败（%d）：%s' % (rc, (err or out).strip()[:200]))
                continue
            a = io.open(qm_path, 'rb').read()
            b = io.open(tmp_qm, 'rb').read()
            if a != b:
                problems.append('%s 与 %s 不同步（入库 %d 字节 / 重编译 %d 字节）'
                                % (qmname, tsname, len(a), len(b)))
    return problems


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--lupdate', default=None,
                    help='lupdate 可执行文件；缺省则判据 3 报工装错误')
    ap.add_argument('--lrelease', default=None)
    ap.add_argument('--exempt', default=EXEMPT_PATH)
    ap.add_argument('--src', default=SRC)
    ap.add_argument('--i18n', default=I18N_DIR,
                    help='翻译资产目录；证伪器用临时目录打判据 3')
    args = ap.parse_args()

    code = 0
    hits = scan_src(args.src)
    exempt_cnt, exempt_grp = load_exempt(args.exempt)

    print('=== i18n 门禁 ===')
    print('扫描面：%s（.qml / .js）' % os.path.relpath(args.src, ROOT))
    print('含 CJK 的文案行：%d 条' % len(hits))

    if exempt_cnt is None:
        print('工装错误：豁免表不存在 —— %s' % args.exempt)
        return 8
    print('豁免表：%s（%d 条）' % (os.path.relpath(args.exempt, ROOT),
                                  sum(exempt_cnt.values())))

    # 分组进度（给报告用，不是判据）
    grp_left = collections.Counter()
    for (rel, fp), n in exempt_cnt.items():
        grp_left[exempt_grp.get((rel, fp), '?')] += n
    if grp_left:
        print('仍欠（按组）：' + '  '.join('%s=%d' % (k, v)
                                          for k, v in sorted(grp_left.items())))

    # --- 判据 1 ---
    p1 = check_new(hits, exempt_cnt, args.src)
    print()
    if p1:
        print('判据 1 失败（新增未登记 / 形式不对 / 算路层出现 qsTr）：%d 条' % len(p1))
        for s in p1[:40]:
            print('  - ' + s)
        if len(p1) > 40:
            print('  … 另有 %d 条' % (len(p1) - 40))
        code |= 1
    else:
        print('判据 1 通过：无新增未登记文案，算路层无 qsTr')

    # --- 判据 2 ---
    p2 = check_ledger(hits, exempt_cnt, exempt_grp)
    print()
    if p2:
        print('判据 2 失败（该销账 / 漂了）：%d 条' % len(p2))
        for s in p2[:40]:
            print('  - ' + s)
        if len(p2) > 40:
            print('  … 另有 %d 条' % (len(p2) - 40))
        code |= 2
    else:
        print('判据 2 通过：豁免表双向对账一致（无该销账、无漂移）')

    # --- 判据 3 ---
    print()
    if not args.lupdate or not args.lrelease:
        print('判据 3 工装错误：未提供 --lupdate / --lrelease')
        code |= 8
    else:
        p3 = check_assets(args.lupdate, args.lrelease, args.src, args.i18n)
        if p3:
            print('判据 3 失败（资产不同步）：%d 条' % len(p3))
            for s in p3[:40]:
                print('  - ' + s)
            if len(p3) > 40:
                print('  … 另有 %d 条' % (len(p3) - 40))
            code |= 4
        else:
            print('判据 3 通过：.ts 与源码一致，.qm 与 .ts 一致')

    print()
    if code == 0:
        print('OK  i18n：三道判据全过（位掩码 0x00）')
    else:
        print('FAIL i18n：位掩码 0x%02x' % code)
    return code


if __name__ == '__main__':
    sys.exit(main())
