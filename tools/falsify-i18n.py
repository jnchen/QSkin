#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""QSkin · i18n 门禁的证伪器（9 枪 + 1 真源枪）。

规则：**一道没被证伪过的闸不算闸。** 本脚本给 `tools/check-i18n.py` 打枪，
每枪**声明预期的退出码**，跑完逐一比对；有一枪不符就整体判失败。

── 这 10 枪各证明什么 ─────────────────────────────────────────────────────
  G0  全真跑一遍                          → 期望 0（**没有这一枪，后面的红没有参照**
                                             —— 分不清"红是因为变异"还是"本来就红"）
  G1  源码多一条**裸文案**（非 qsTr）      → 期望 1（新增即红）
  G2  **算路层 `.js` 里出现 qsTr**         → 期望 5（= 1|4）
      反向判据护的是三道 node 门禁；而判据 3 **必然跟着红**，因为
      `lupdate` **真的会从 `.js` 抽 qsTr**（开工实测：探针 `t.js` 抽出来了）——
      加了一条 qsTr 而 `.ts` 没更新，本来就不是同步的。
      **首跑我声明的是 1，实测 5 —— 是我声明窄了，不是门错了。**
  G3  豁免表**删**掉一条（源码还在）       → 期望 1（那条退化成"新增未登记"）
  G4  豁免表**加**一条源码里没有的         → 期望 2（过期豁免）
  G5  源码某条**改成 qsTr**（表不动）      → 期望 6（= 2|4）
      判据 2 报"过期豁免"（对 —— 该行指纹已经变了），判据 3 报".ts 不同步"
      （也对 —— 源码多了一条 qsTr）。**首跑我声明的是 2，实测 6 —— 声明窄了。**
      ⚠ 但 G5 首跑**顺带抓出一个真缺陷**：判据 2 多报了一条**假的**"该销账"
      （`confirmText: "确定"` 根本没被改）。根因是当时 `qsTr` 判定用了
      "本行或前两行"的窗口，相邻两行互相污染。已收窄到**本行**（收窄前量过：
      全仓"靠窗口才判成 qsTr"的行 = 0 条，不误伤）。
      ★ **靶有寿命，而且漂得准时**：批次的收敛方向就是消灭靶那一类 ——
        一版靶（AlertDialog 的 cancelText / confirmText）在 M33-3 被改掉，
        二版靶（QSkinUpload 的 `case "success"`）在 M33-4 被改掉。
        ⇒ **选靶要落在"本主题的不动点"上**：现靶 = `Slots.qml` 的 **D 组**
        相邻对（登记为"不 i18n"，i18n 批次永远不动它）——
        靶的寿命长于批次，才不用每批都换一次。
        锚点仍必须带断言（漂了就报"需改靶"），否则它会**静默打空**，
        "10 枪全中"悄悄变成"9 枪全中"而没人察觉。
  G5b 源码改一条之后，**紧邻的未改行不许被报**  → 不是位掩码，是**文本对账**。
      理由：位掩码 6 只说"判据 2 红了"，**不说红在哪** —— 报对了和报多了
      退出码一模一样。这条把"本行判定"钉住，不然窗口污染会再次溜过去。
  G6  `.ts` **少**一条（源码有）           → 期望 4（资产不同步）
  G7  `.ts` 加翻译但**不重编 `.qm`**       → 期望 4（`.qm` 过期）
  G8  不提供 lupdate                       → 期望 8（工装 —— "量不出"不算通过）
  G9  **真源变异**：往真的 `src/` 里加一条裸文案，跑**真门禁** → 期望 1，
      然后**还原并用 md5 核对**（不是"我记得还原了"）

── 为什么 G9 必须存在 ──────────────────────────────────────────────────────
  G1~G8 全在**临时副本**上做。它们能证明"比较逻辑没坏"，证明不了
  "**真的那棵树**会被守住"。副本与真树之间只差一个 copytree —— 但它也可能
  差在别处（比如豁免表的路径基），而那种偏差只会让副本上的枪变绿、
  真树上失效。**真源枪是最后一道保险。**

── 已知取巧处（写在明处）───────────────────────────────────────────────────
  · G1~G5 用的副本是 `src/` 的整棵复制（copytree）。慢，但换来"扫描面与真跑
    完全同构"——比"只造几个小文件"更能证明判据在真树上成立。
  · F 系列（check-runtime-warn 的证伪器）可以对合成日志打枪，因为那道门的
    输入就是日志文本。**这道门的输入是源码树本身**，所以必须复制真树。
"""

import hashlib
import io
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECK = os.path.join(ROOT, 'tools', 'check-i18n.py')
REAL_SRC = os.path.join(ROOT, 'src')
EXEMPT = os.path.join(ROOT, 'tools', 'i18n-exempt.txt')
I18N = os.path.join(ROOT, 'i18n')


def qt_tool(qt, name):
    """Windows 上是 `lupdate.exe`，Python 的 os.path.exists **不会**自动补 .exe。"""
    for cand in (name, name + '.exe'):
        p = os.path.join(qt, 'bin', cand)
        if os.path.exists(p):
            return p
    return ''


def find_qt():
    qt = os.environ.get('QSkin_QT', '')
    if qt and os.path.isdir(qt):
        return qt
    base = os.path.join(ROOT, '.qt')
    if not os.path.isdir(base):
        return ''
    for ver in sorted(os.listdir(base)):
        for arch in sorted(os.listdir(os.path.join(base, ver))):
            d = os.path.join(base, ver, arch)
            if os.path.exists(os.path.join(d, 'bin', 'qmllint.exe')) or \
               os.path.exists(os.path.join(d, 'bin', 'qmllint')):
                return d
    return ''


QT = find_qt()
LUPDATE = qt_tool(QT, 'lupdate') if QT else ''
LRELEASE = qt_tool(QT, 'lrelease') if QT else ''

TMP = tempfile.mkdtemp(prefix='qds-i18n-falsify-')


def run_check(src=None, exempt=None, i18n=None, with_tools=True):
    cmd = [sys.executable, CHECK,
           '--src', src or REAL_SRC,
           '--exempt', exempt or EXEMPT,
           '--i18n', i18n or I18N]
    if with_tools:
        cmd += ['--lupdate', LUPDATE, '--lrelease', LRELEASE]
    else:
        cmd += ['--lupdate', '', '--lrelease', '']
    p = subprocess.run(cmd, capture_output=True)
    return p.returncode, (p.stdout + p.stderr).decode('utf-8', 'replace')


def verdict(out):
    for ln in out.split('\n'):
        if ln.startswith('OK  i18n') or ln.startswith('FAIL i18n'):
            return ln.strip()[:60]
    for ln in out.split('\n'):
        if ln.startswith('工装错误'):
            return ln.strip()[:60]
    return '(无结论行)'


FAILS = 0


def gun(name, want, **kw):
    """开一枪：比对退出码，**并把输出交回去**。

    交出输出是给 G5b 用的 —— 有些东西位掩码看不出来（比如"报的是不是该报的
    那一条"）。位掩码只说"有位红了"，不说"红在哪"。
    """
    global FAILS
    code, out = run_check(**kw)
    if code == want:
        print('   OK   %-4s 期望 %-3d 实测 %-3d  %s' % (name, want, code, verdict(out)))
    else:
        print('   MISS %-4s 期望 %-3d 实测 %-3d  <- 不符' % (name, want, code))
        for ln in out.split('\n')[:16]:
            print('          | ' + ln)
        FAILS += 1
    return code, out


# ---------------------------------------------------------------- 变异工具

def copy_src():
    """整棵复制真 src 到临时目录，返回副本里 src 的路径。

    返回 `<TMP>/src-xxx/src` —— 这样门禁算出的相对路径仍是 `src/…`。
    """
    d = tempfile.mkdtemp(prefix='src-', dir=TMP)
    dst = os.path.join(d, 'src')
    shutil.copytree(REAL_SRC, dst)
    return dst


def insert_before_last_brace(path, line):
    """在文件最后一个 `}` 前插一行（尽量保持"像真的"）。"""
    s = io.open(path, encoding='utf-8', newline='').read()
    i = s.rstrip().rfind('}')
    if i < 0:
        s = s + '\n' + line + '\n'
    else:
        s = s[:i] + line + '\n' + s[i:]
    io.open(path, 'w', encoding='utf-8', newline='').write(s)


def ex_minus_one():
    """真豁免表删掉第一条有效条目。"""
    p = os.path.join(TMP, 'exempt_minus.txt')
    lines = io.open(EXEMPT, encoding='utf-8', newline='').read().split('\n')
    out, dropped = [], False
    for ln in lines:
        if not dropped and ln.strip() and not ln.startswith('#'):
            dropped = True
            continue
        out.append(ln)
    io.open(p, 'w', encoding='utf-8', newline='').write('\n'.join(out))
    return p


def ex_plus_fake():
    """真豁免表加一条源码里根本不存在的。"""
    p = os.path.join(TMP, 'exempt_plus.txt')
    s = io.open(EXEMPT, encoding='utf-8', newline='').read()
    s += 'A\tsrc/contracts/ZZZ.qml\tproperty string x: "源码里没有这条"\n'
    io.open(p, 'w', encoding='utf-8', newline='').write(s)
    return p


def i18n_ts_minus_one():
    """临时 i18n：.ts 少一条 message（源码里有）。"""
    d = os.path.join(TMP, 'i18n_g6')
    os.makedirs(d, exist_ok=True)
    s = io.open(os.path.join(I18N, 'qskin_en.ts'), encoding='utf-8',
                newline='').read()
    s2 = re.sub(r'[ \t]*<message>.*?</message>\n?', '', s, count=1, flags=re.S)
    io.open(os.path.join(d, 'qskin_en.ts'), 'w', encoding='utf-8',
            newline='').write(s2)
    shutil.copy(os.path.join(I18N, 'qskin_en.qm'), os.path.join(d, 'qskin_en.qm'))
    return d


def i18n_qm_stale():
    """临时 i18n：.ts 填了翻译，但 .qm 还是旧的（没重编）。"""
    d = os.path.join(TMP, 'i18n_g7')
    os.makedirs(d, exist_ok=True)
    s = io.open(os.path.join(I18N, 'qskin_en.ts'), encoding='utf-8',
                newline='').read()
    s2 = s.replace('<translation type="unfinished"></translation>',
                   '<translation>Probe translation</translation>')
    io.open(os.path.join(d, 'qskin_en.ts'), 'w', encoding='utf-8',
            newline='').write(s2)
    shutil.copy(os.path.join(I18N, 'qskin_en.qm'), os.path.join(d, 'qskin_en.qm'))
    return d


# ---------------------------------------------------------------- 开枪

print('i18n 门禁 · 证伪（9 枪 + 1 真源枪）')
print('  Qt：%s' % (QT or '未找到'))
print('  临时区：%s' % TMP)
print()

# G0 —— 参照
gun('G0', 0)

# G1 —— 新增裸文案（副本）
s1 = copy_src()
insert_before_last_brace(os.path.join(s1, 'contracts', 'QSkinEmpty.qml'),
                         '    property string __probeI18n: "探针裸文案"')
gun('G1', 1, src=s1)

# G2 —— 算路层出现 qsTr（副本）
s2 = copy_src()
insert_before_last_brace(os.path.join(s2, 'foundation', 'ColorUtil.js'),
                         'var __probeI18n = qsTr("probe")')
gun('G2', 5, src=s2)

# G3 —— 豁免表少一条
gun('G3', 1, exempt=ex_minus_one())

# G4 —— 豁免表多一条假的
gun('G4', 2, exempt=ex_plus_fake())

# G5 —— 源码某条改成 qsTr（表不动）
#
# ★ 这一枪的**靶是有寿命的**，而且漂得准时 —— 批次的收敛方向就是消灭靶那一类：
#     · 一版靶 = QSkinAlertDialog 的 cancelText / confirmText → M33-3 改掉了
#     · 二版靶 = QSkinUpload 的 case "success" / "error"    → M33-4 改掉了
#   ⇒ **选靶原则（M33-4 补上）：靶要落在"本主题的不动点"上。**
#   现靶 = `Slots.qml` 的 **D 组**相邻对（登记为"**不 i18n**"，
#   i18n 批次永远不动它）—— 靶的寿命长于批次。
#   ⚠ 锚点仍必须带断言（漂了就报"需改靶"），否则它会**静默打空** ——
#     "10 枪全中"悄悄变成"9 枪全中"，而没人察觉。
s5 = copy_src()
f5 = os.path.join(s5, 'contracts', 'Slots.qml')
_t = io.open(f5, encoding='utf-8', newline='').read()
G5_TARGET = 'console.warn("QSkin.Slots.install(): 未知插槽名 \'" + key'
assert G5_TARGET in _t, 'G5 的锚点漂了，需改靶'
# ⚠ 子串替换，只碰行内 —— Slots.qml 是 **CRLF**，行尾原样保留
_t = _t.replace(G5_TARGET,
                'console.warn(qsTr("QSkin.Slots.install(): 未知插槽名 \'") + key')
io.open(f5, 'w', encoding='utf-8', newline='').write(_t)
G5_CODE, G5_OUT = gun('G5', 6, src=s5)

# G5b —— 位掩码 6 只说"判据 2 与判据 3 红了"，**不说红在哪**。
# 被改的那一行该报；**紧邻的下一行一个字没动，不该报**。
# 这一枪的来历：旧版判据把"这一行是 qsTr 形式"判成"本行或前两行"的窗口，
# 于是相邻行互相污染，G5 首跑时多报了一条假的"该销账"。已收窄到"本行"。
# **这条断言就是把那次修复钉住** —— 光有位掩码，那个假阳性会再次溜过去。
# ⚠ 靶换成 Slots.qml 之后，被盯的串也跟着换：改的是**上一行**（`console.warn`），
#   不许被误报的是**下一行**（`+ "'，已忽略。…"`）—— 窗口版会把它一起吃进来。
G5_STRAY = [ln for ln in G5_OUT.split('\n') if '已忽略' in ln]
if G5_STRAY:
    print('   MISS G5b 相邻行被误报（"本行"判定退化成窗口了）：')
    for ln in G5_STRAY[:3]:
        print('          | ' + ln.strip()[:100])
    FAILS += 1
else:
    print('   OK   G5b  只报了被改的那一条；紧邻的 `已忽略` 行未被牵连')

# G6 / G7 —— 资产不同步
gun('G6', 4, i18n=i18n_ts_minus_one())
gun('G7', 4, i18n=i18n_qm_stale())

# G8 —— 工装：不给 lupdate
gun('G8', 8, with_tools=False)

# G9 —— 真源变异（改真文件 → 跑真门禁 → 还原 → 核 md5）
print()
G9F = os.path.join(REAL_SRC, 'contracts', 'QSkinEmpty.qml')
BEFORE = io.open(G9F, 'rb').read()
MD5_BEFORE = hashlib.md5(BEFORE).hexdigest()
try:
    insert_before_last_brace(G9F, '    property string __probeI18n: "真源探针文案"')
    gun('G9', 1)
finally:
    io.open(G9F, 'wb').write(BEFORE)
    MD5_AFTER = hashlib.md5(io.open(G9F, 'rb').read()).hexdigest()

if MD5_AFTER == MD5_BEFORE:
    print('   OK   G9b  真源已逐字节还原（md5 %s）' % MD5_BEFORE[:12])
else:
    print('   MISS G9b  真源**没有**还原干净：%s -> %s'
          % (MD5_BEFORE[:12], MD5_AFTER[:12]))
    FAILS += 1

# 还原后再确认整体仍是绿的 —— 否则 G9 的变异可能留了尾
gun('G9c', 0)

print()
if FAILS == 0:
    print('OK  10 枪全部按声明命中（含真源枪与还原核对）')
    print('    另有三条非位掩码核对通过：G5b（相邻行未被牵连）、'
          'G9b（真源逐字节还原）、G9c（还原后回归绿）')
    sys.exit(0)
print('NG  %d 枪不符声明 —— 这道门的判据需要重看' % FAILS)
sys.exit(1)
