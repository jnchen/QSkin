#!/usr/bin/env python3
"""QSkin 双轨生成器 —— src/（Qt 6.8+ 写法）→ Qt5 产物

    生成 ORDER：
      python tools/qml-downgrade.py --profile qt515                # → qt5/（主产物）
      python tools/qml-downgrade.py --profile qt515 --check         # 漂移门（不落盘）

只有 **qt515 一档**（Qt 5.15.x）：

  · PyQt5 的 wheel 自带 Qt 5.15 运行时（PyQt5 5.15.x 链接 Qt 5.15），
    这是 Python 侧唯一能落地的 Qt5 版本。
  · required property / HoverHandler·TapHandler（5.15 的 Pointer Handlers）/
    QtQuick.Shapes（5.12 转正）/ Connections 新语法 / 箭头函数 —— **全部支持，保留原样**。
    真正要改的只有 6 类机械改写（逐条带预期命中数，见 PROFILES）。
  · C++ 侧同版本：Qt 5.15.2 SDK 与 PyQt5 自带运行时同版，对账才可比。

⚠ 曾经还有一档 qt511（Qt 5.11.3），**已删除**：5.11 官方分发不带
  QtQuick.Shapes（5.10/5.11 是 Tech Preview 且默认不构建，5.12 才转正），
  34 个文件 233 处 Shape 得另写一套实现；而 PyQt5 自带的是 5.15，
  没有真实目标机需要这一档。留着它只会让「到底支持哪个 Qt 5」说不清。

硬约束：
两档共用的硬约束：
  · Qt5 **没有** qt_add_qml_module 的 URI→目录映射（那是 6.2 引入的），物理目录必须等于
    module URI 路径，所以 contracts/ 要落到 QSkin/Contracts/，themes/shadcn/ 要落到 QSkin/Theme/Shadcn/。
  · `pragma ComponentBehavior` 是 Qt 6.5 才有的，**两档都必须删**。

改动的每一处都有**预期命中数**，跑完对账；补丁失配 = 报错（不静默通过）。
"""
import os, re, sys, shutil, argparse, collections, hashlib

SRC_DEFAULT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src')


# ── profile ───────────────────────────────────────────────────────────────
# 每条规则都对应一个**实测过的** Qt5 行为；改这里等于改兼容承诺，必须先跑真引擎。
PROFILES = {
    # ── Qt 5.15.x：PyQt5 wheel 自带的就是它，Python 侧唯一能落地的 Qt5 ──────
    'qt515': dict(
        outdir='qt5',
        desc='Qt 5.15.x（PyQt5 自带运行时；支持 required/Handler/Shapes，改动最小）',
        # 只有 Basic 风格是 Qt 6.0 才有 → 回退到 Qt5 默认风格的 Controls
        imports={
            ('QtQuick.Controls.Basic', '2.15'): ('QtQuick.Controls', '2.15'),
        },
        expect_import={('QtQuick.Controls.Basic', '2.15'): 1},
        # ── 无版本号 import：Qt 6 允许「不写版本 = 取最高版」，Qt 5.15 不允许 ──
        # 实测报错：`Library import requires a version`。
        # 这一条上一轮**被扫描漏掉**了：正则写成「必须有版本号」才匹配，
        # 于是无版本 import 直接隐身。教训见 docs/PITFALLS.md。
        # 值为 (新模块名, 版本)；None = 删整行
        nover={
            'QtQuick.Shapes': ('QtQuick.Shapes', '1.15'),   # 35 处
            'QtQuick': ('QtQuick', '2.15'),                 # 10 处
            # ⚠ 别删！这里曾误判成「只 import 未使用」而删掉，结果 MultiEffect
            #   is not a type，4 个控件（Avatar/AvatarGroup/Image/Comment）全挂。
            #   Qt 5 的对应物是 QtGraphicalEffects.OpacityMask（只做圆形遮罩）。
            'QtQuick.Effects': ('QtGraphicalEffects', '1.15'),  # 2 处
        },
        expect_nover={'QtQuick.Shapes': 35, 'QtQuick': 10, 'QtQuick.Effects': 2},
        # 四角独立半径（topLeftRadius 等）是 Qt 6 独有，且只在**无版本 import**
        # 下才存在（原注释有实测记录）。Qt 5.15 两样都没有 → 必须替换实现。
        corner_radius=True,
        # 14 = 10 个文件，其中 4 个主题 InputBackground 各有 2 块（本体 + 聚焦光晕）。
        # ⚠ 别用 re.search 数文件：那每文件只取首个块，会读成 10。
        expect_corner=14,
        # Qt 6 独有属性，Qt 5.15 无对应物 → 整行删掉（值无等价物，不能改写成别的）
        drop_props={'preferredRendererType': 43},
        # 行内片段删除（不能整行删：这些属性写在行尾且带 `}`，整行删会吃掉花括号）
        drop_inline={'restoreMode': 4},   # Binding.restoreMode 在 QtQuick 2.15 不可用
        # MultiEffect（Qt 6.5+）→ OpacityMask（Qt 5）。全库只用来做圆形遮罩。
        multieffect=True,
        expect_multieffect=3,
        pragma_component_behavior=True,# Qt 6.5 引入 → 必须删（当前实测 0 处真代码）
        expect_pragma_cb=0,
    ),
}


# ── 四角独立半径块（Qt 6 独有，Qt 5.15 无对应物）────────────────────────────
# 全库 10 个文件，写法只有两种变量名（_corners / _haloCorners），结构统一。
CORNER_BLK = re.compile(
    r'^([ \t]*)topLeftRadius:\s*(\w+)\.tl[^\n]*\n'
    r'[ \t]*topRightRadius:\s*\w+\.tr[^\n]*\n'
    r'[ \t]*bottomRightRadius:\s*\w+\.br[^\n]*\n'
    r'[ \t]*bottomLeftRadius:\s*\w+\.bl[^\n]*\n', re.M)


# ── 注释 / 字符串掩码 ──────────────────────────────────────────────────────
def split_code(text):
    """把文本切成 [(kind, start, end)]，kind ∈ {'code','comment','string'}。
    字符串也要屏蔽：否则 import 里若含 // 会误判。"""
    spans, i, n = [], 0, len(text)
    kind, start = 'code', 0
    def flush(end):
        nonlocal i, start
        if end > start:
            spans.append((kind, start, end))
        start = end
    while i < n:
        c = text[i]
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            flush(i); j = text.find('\n', i); j = n if j < 0 else j
            spans.append(('comment', i, j)); start = j; i = j
        elif c == '/' and i + 1 < n and text[i + 1] == '*':
            flush(i); j = text.find('*/', i + 2); j = n if j < 0 else j + 2
            spans.append(('comment', i, j)); start = j; i = j
        elif c in '"\'':
            flush(i); q = c; i += 1
            while i < n and text[i] != q:
                i += 2 if text[i] == '\\' else 1
            i = min(i + 1, n)
            spans.append(('string', start, i)); start = i
        else:
            i += 1
    flush(n)
    return spans


def build_mask(text):
    """返回 code 段的字节掩码：code 位置为 True。"""
    mask = bytearray(len(text))
    for kind, s, e in split_code(text):
        if kind == 'code':
            for k in range(s, e):
                mask[k] = 1
    return mask


def repl_in_code(text, pattern, rep, counters, key, flags=0):
    """只在 code 段（非注释非字符串）做替换，返回新文本。"""
    mask = build_mask(text)
    out, pos, n_hit = [], 0, 0
    for m in re.finditer(pattern, text, flags):
        s, e = m.span()
        if not all(mask[k] for k in range(s, min(e, len(mask)))):
            continue
        piece = rep(m) if callable(rep) else m.expand(rep)
        out.append(text[pos:s]); out.append(piece)
        pos = e; n_hit += 1
    out.append(text[pos:])
    if key:
        counters[key] += n_hit
    return ''.join(out)



# Connections 新语法 → 老语法（Qt 5.11 实测：新语法 rc=0 但**不生效**，比报错更危险）


def downgrade_text(text, counters, relpath, prof):
    t = text

    # R1 import 版本映射（Basic 风格可能整体换模块名）
    def do_imports(t):
        mask = build_mask(t)
        out, pos = [], 0
        for m in re.finditer(r'^(\s*)import\s+([A-Za-z0-9_.]+)\s+([0-9.]+)', t, re.M):
            s, e = m.span()
            if not all(mask[k] for k in range(s, e)):
                continue
            mod, ver = m.group(2), m.group(3)
            key = (mod, ver)
            if key not in prof['imports']:
                continue
            newmod, newver = prof['imports'][key]
            out.append(t[pos:s])
            out.append(f'{m.group(1)}import {newmod} {newver}')
            pos = e
            counters[('import', mod, ver)] += 1
        out.append(t[pos:])
        return ''.join(out)

    t = do_imports(t)

    # R1b 无版本号 import：Qt5 一律要求写版本（None = 该模块 Qt5 无对应物，删整行）
    def do_nover(t):
        mask = build_mask(t)
        out, pos = [], 0
        for m in re.finditer(r'^[ \t]*import[ \t]+([A-Za-z0-9_.]+)[ \t]*\r?\n', t, re.M):
            s, e = m.span()
            if not all(mask[k] for k in range(s, min(e, len(mask)))):
                continue
            mod = m.group(1)
            if mod not in prof['nover']:
                continue
            ver = prof['nover'][mod]
            out.append(t[pos:s])
            if ver is not None:
                newmod, newver = ver
                out.append(f'import {newmod} {newver}\n')
            pos = e
            counters[('nover', mod)] += 1
        out.append(t[pos:])
        return ''.join(out)

    t = do_nover(t)

    # R2b 四角独立半径 → 主体取最大值 + 补角矩形（Qt5 无 topLeftRadius 等）
    if prof['corner_radius']:
        def corner_rep(m):
            ind, v = m.group(1), m.group(2)
            out = [f'{ind}radius: Math.max({v}.tl, {v}.tr, {v}.br, {v}.bl)\n']
            out.append(
                f'{ind}/* Qt 5.15 无四角独立半径（topLeftRadius 等是 Qt 6 独有，且只在\n'
                f'{ind} * 「无版本 import」下才存在 —— 原注释有实测记录）。\n'
                f'{ind} * 降级：主体取四角最大值，再用补角矩形把该直的角填回方形。\n'
                f'{ind} * 已知差异：补角会盖掉一小段 border，而那正是分组按钮与相邻\n'
                f'{ind} * 按钮的接缝；standalone（四角全等）与中段（四角全零）两种\n'
                f'{ind} * 情形与 Qt 6 侧逐像素一致。 */\n')
            # ⚠ 别写死 `root.*`：10 个块里有 4 个属于嵌套元素（聚焦光晕 halo，
            #   缩进 8），它的尺寸不是 root 的。统一用 `parent.*` 指宿主元素、
            #   不限定的 `radius` 走作用域链解析到宿主自己的 radius。
            #   `color` 必须限定成 parent.color —— 不限定会解析成补角自己的
            #   color，那是自引用。
            for corner, cx, cy in (
                    ('tl', '0', '0'),
                    ('tr', 'parent.width - radius', '0'),
                    ('br', 'parent.width - radius', 'parent.height - radius'),
                    ('bl', '0', 'parent.height - radius')):
                out.append(f'{ind}Rectangle {{ visible: {v}.{corner} < radius; '
                           f'x: {cx}; y: {cy}; '
                           f'width: radius; height: radius; '
                           f'color: parent.color }}\n')
            return ''.join(out)
        t = repl_in_code(t, CORNER_BLK, corner_rep, counters, ('corner', 'block'))

    # R2c Qt 6 独有属性 → 整行删（无等价物，不能"翻译成"别的值）
    for prop in prof['drop_props']:
        # ⚠ 必须传 re.M：不传的话 `^` 只匹配整个文件开头，规则会**静默空转**
        #   （实测漏过一次，表现为「预期 43 实际 0」）。
        t = repl_in_code(t, r'^[ \t]*' + re.escape(prop) + r'\s*:[^\n]*\n', '',
                         counters, ('drop', prop), flags=re.M)

    # R2d 行内片段删除（保留行尾的 `}` 等语法结构）
    for prop in prof['drop_inline']:
        t = repl_in_code(t, r'\b' + re.escape(prop) + r'\s*:[^}\n]*', '',
                         counters, ('drop_inline', prop))

    # R2e MultiEffect（Qt 6.5+）→ OpacityMask（Qt 5）—— 全库只做圆形遮罩
    if prof['multieffect']:
        def meff_rep(m):
            # OpacityMask 没有 maskEnabled（它本来就是遮罩），只留 maskSource
            body = re.sub(r'^[ \t]*maskEnabled\s*:[^\n]*\n', '', m.group(1), flags=re.M)
            return 'layer.effect: OpacityMask {' + body + '}'
        t = repl_in_code(t, r'layer\.effect:\s*MultiEffect\s*\{([^}]*)\}',
                         meff_rep, counters, ('effect', 'MultiEffect'))

    # R0 pragma ComponentBehavior（Qt 6.5+）：两档都必须删，否则 Qt5 解析失败
    if prof['pragma_component_behavior']:
        t = repl_in_code(t, r'^[ \t]*pragma[ \t]+ComponentBehavior[^\n]*\n', '',
                         counters, ('pragma', 'ComponentBehavior'), flags=re.M)


    return t


def module_map(src):
    """src 目录 → module URI（读 qmldir 的 module 行），用于决定输出目录。"""
    mapping = {}
    for root, dirs, files in os.walk(src):
        if 'qmldir' not in files:
            continue
        t = open(os.path.join(root, 'qmldir'), encoding='utf-8', errors='replace').read()
        m = re.search(r'^\s*module\s+([A-Za-z0-9_.]+)', t, re.M)
        if not m:
            continue
        rel = os.path.relpath(root, src).replace(os.sep, '/')
        mapping[rel] = m.group(1)
    return mapping


def snapshot(root):
    """目录 → {相对路径: 内容 sha256}。"""
    out = {}
    for r, _dirs, files in os.walk(root):
        for fn in files:
            p = os.path.join(r, fn)
            rel = os.path.relpath(p, root).replace(os.sep, '/')
            with open(p, 'rb') as fh:
                out[rel] = hashlib.sha256(fh.read()).hexdigest()
    return out


def drift_between(gen_text, dest_root):
    """内存里的降级结果 vs 入库产物：返回差异描述列表（空列表 = 一致）。

    入库产物不存在时返回 None（那是**工装问题**，与"有差异"要分开报）。

    ⚠ 比的是**文本的 sha256**，不是落盘再读：写盘会用 newline='\\n'，
    读回来又可能带平台的行尾转换，等于拿"生成逻辑"和"IO 行为"混在一起比。
    直接比降级后的文本，漂移才只反映 src/ 的变化。
    """
    if not os.path.isdir(dest_root):
        return None
    dest = snapshot(dest_root)
    out = []
    for rel in sorted(gen_text):
        if rel not in dest:
            out.append('新增（src/ 有、产物没有）%s' % rel)
            continue
        got = hashlib.sha256(gen_text[rel].encode('utf-8')).hexdigest()
        if got != dest[rel]:
            out.append('内容不同 %s' % rel)
    for rel in sorted(set(dest) - set(gen_text)):
        out.append('残留（产物有、src/ 没有）%s' % rel)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--profile', default='qt515', choices=sorted(PROFILES),
                    help='目标 Qt5 档位（默认 qt515）')
    ap.add_argument('--src', default=os.path.abspath(SRC_DEFAULT))
    ap.add_argument('--out', default=None, help='输出目录，默认 qt5/')
    ap.add_argument('--check', action='store_true',
                    help='漂移检查：**不落盘**，把降级结果在内存里与入库产物'
                         '逐文件比对（新增 / 残留 / 内容不同都报）')
    args = ap.parse_args()

    prof = PROFILES[args.profile]
    out_default = os.path.abspath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', prof['outdir']))
    src, out = args.src, (args.out or out_default)
    print(f'profile = {args.profile}  ({prof["desc"]})')
    print(f'src     = {src}')
    print(f'out     = {out}')
    if not os.path.isdir(src):
        print(f'FAIL: src 不存在 {src}', file=sys.stderr); return 2

    modmap = module_map(src)
    if not modmap:
        print('FAIL: 没找到任何 qmldir，src 结构不符预期', file=sys.stderr); return 2

    counters = collections.Counter()
    dest_root = out
    # ⚠ --check **刻意不建临时目录**：早期版本是"生成到 qt5.tmpgen 再比对、
    # 比对完 rmtree"，结果在门禁里跑时，删那 985 个文件会被宿主的安全删除
    # 拦截（批量删除要人工确认）→ 门变成"永远红"，而且红得莫名其妙。
    # 改成内存比对后：零写入、零删除、零临时目录残留。
    real_root = dest_root
    if not args.check and os.path.isdir(real_root):
        shutil.rmtree(real_root)

    # check 模式下：降级结果直接进这里（相对 dest_root 的路径 → 文本），
    # 最后与磁盘上的入库产物比对。
    gen_text = {}
    written = []
    for root, dirs, files in os.walk(src):
        rel = os.path.relpath(root, src).replace(os.sep, '/')
        if rel == '.':
            continue
        # 找它归属的模块（可能是 features\SubModel 形态）
        uri = None
        for mf in modmap:
            if rel == mf or rel.startswith(mf + '/'):
                if uri is None or len(mf) > len(uri[0]):
                    uri = (mf, modmap[mf])
        if uri is None:
            continue
        sub = rel[len(uri[0]):].lstrip('/')
        dst_dir = os.path.join(real_root, uri[1].replace('.', os.sep), sub.replace('/', os.sep)) if sub \
            else os.path.join(real_root, uri[1].replace('.', os.sep))
        if not args.check:
            os.makedirs(dst_dir, exist_ok=True)
        for fn in files:
            sp = os.path.join(root, fn)
            dp = os.path.join(dst_dir, fn)
            text = open(sp, encoding='utf-8', errors='replace').read()
            relp = os.path.relpath(sp, src)
            if fn.endswith(('.qml', '.js')):
                text = downgrade_text(text, counters, relp, prof)
            if args.check:
                gen_text[os.path.relpath(dp, dest_root).replace(os.sep, '/')] = text
            else:
                open(dp, 'w', encoding='utf-8', newline='\n').write(text)
                written.append(dp)

    # ── 对账 ──
    print(f'生成文件: {len(written)}  →  {real_root}')
    print()
    print('=== import 改写账 ===')
    ok = True
    for (mod, ver), exp in prof['expect_import'].items():
        got = counters[('import', mod, ver)]
        flag = 'OK ' if got == exp else 'DIFF'
        if got != exp: ok = False
        print(f'  {flag} {mod:28s} {ver:6s} 预期 {exp:4d} 实际 {got:4d}')

    print()
    print('=== 无版本 import 补齐账 ===')
    for mod, exp in prof['expect_nover'].items():
        got = counters[('nover', mod)]
        flag = 'OK ' if got == exp else 'DIFF'
        if got != exp: ok = False
        print(f'  {flag} {mod:28s} 预期 {exp:4d} 实际 {got:4d}')

    print()
    print('=== Qt6 独有属性删除账 ===')
    for prop, exp in prof['drop_props'].items():
        got = counters[('drop', prop)]
        flag = 'OK ' if got == exp else 'DIFF'
        if got != exp: ok = False
        print(f'  {flag} {prop:28s} 预期 {exp:4d} 实际 {got:4d}')
    for prop, exp in prof['drop_inline'].items():
        got = counters[('drop_inline', prop)]
        flag = 'OK ' if got == exp else 'DIFF'
        if got != exp: ok = False
        print(f'  {flag} {prop:28s}(行内) 预期 {exp:4d} 实际 {got:4d}')
    got_me = counters[('effect', 'MultiEffect')]
    exp_me = prof['expect_multieffect']
    if got_me != exp_me:
        print(f'  DIFF MultiEffect→OpacityMask 预期 {exp_me} 实际 {got_me}', file=sys.stderr)
        ok = False
    else:
        print(f'  OK  MultiEffect→OpacityMask 替换数 = {got_me}')

    # 四角独立半径：Qt6 独有且只在无版本 import 下存在，Qt5 必须换实现
    got_corner = counters[('corner', 'block')]
    exp_corner = prof['expect_corner']
    if got_corner != exp_corner:
        print(f'  DIFF 四角半径块替换 预期 {exp_corner} 处，实际 {got_corner} 处', file=sys.stderr)
        ok = False
    else:
        print(f'  OK  四角半径块替换数 = {got_corner}（与预期一致）')

    # pragma ComponentBehavior 是 Qt 6.5 才有的，删干净才能保证 Qt5 能解析。
    # 这一条写成**断言**而不是注释：一旦 src/ 里真出现了，生成器必须炸，不能静默。
    got_cb = counters[('pragma', 'ComponentBehavior')]
    exp_cb = prof['expect_pragma_cb']
    if got_cb != exp_cb:
        print(f'  DIFF pragma ComponentBehavior 预期删 {exp_cb} 处，实际删 {got_cb} 处', file=sys.stderr)
        ok = False
    else:
        print(f'  OK  pragma ComponentBehavior 删除数 = {got_cb}（与预期一致）')

    print()
    print('=== 其它账目 ===')
    for k in sorted(counters):
        if k[0] in ('import', 'pragma'):
            continue
        print(f'  {str(k):70s} {counters[k]}')
    print()
    if not ok:
        print('RESULT: 计数与预期不一致（上面 DIFF 行）', file=sys.stderr)
        return 1

    if args.check:
        # ── 漂移比对：现在生成的 vs 已经入库的 ──────────────────────────
        # 上面那一堆「预期命中数」账**管不了这件事**：它们只证明"规则按
        # 预期命中了"，证明不了 **入库产物就是当前 src/ 生成的**。
        # src/ 改一行却不重跑生成器 ⇒ 命中数照样全 OK、门照样绿，而 qt5/
        # 已经陈旧（Qt 5 侧的新写法会"明明写了却跑不起来"）。
        # 所以 --check 必须落到**逐文件比对**上，而不是停在计数。
        drift = drift_between(gen_text, dest_root)
        if drift is None:
            print(f'RESULT: 漂移 —— 入库产物不存在（{dest_root}）', file=sys.stderr)
            print('       先跑一次不带 --check 的生成，或确认 out 路径', file=sys.stderr)
            return 3
        if drift:
            print(f'RESULT: 漂移 —— 入库产物与 src/ 不一致（{len(drift)} 处）', file=sys.stderr)
            for line in drift[:20]:
                print('       ' + line, file=sys.stderr)
            if len(drift) > 20:
                print(f'       ...（另有 {len(drift) - 20} 处）', file=sys.stderr)
            print('       修法：python tools/qml-downgrade.py --profile %s' % args.profile,
                  file=sys.stderr)
            return 3
        print(f'RESULT: OK  (--check：入库产物与 src/ 逐文件一致)')
        return 0

    print(f'RESULT: OK  (profile={args.profile})')
    return 0


if __name__ == '__main__':
    sys.exit(main())
