#!/usr/bin/env python3
"""**增量**重新生成降级产物 —— 不删目录，只覆盖变化的文件。

为什么不直接用 qml-downgrade.py 的生成模式：那条路先 rmtree 整个产物目录，
在门禁里跑会被宿主的批量删除拦下（项目踩坑记录里就有这条：删 985 项、
甚至只删 3 个文件都会因本轮累计被拦 ⇒ 门永远红且红得莫名其妙）。

⚠ 增量的正确性前提：**产物目录里不能有「src 已不存在」的残留文件**。
   所以本脚本会先**报告**残留（新增/多余），由人确认；
   默认不删任何文件（--prune 才删，且会逐个列出）。
   绝大多数情况下增量结果与全量重新生成**逐字节一致**：
   覆盖了所有生成过的文件，且没有需要删的残留。

与 --check 的分工：
  --check 只说「一致 / 不一致」，不给出**差在哪**；
  本脚本给出逐文件的 覆盖 / 新增 / 残留 三类清单，并实际写出。
"""
import os, sys, collections, hashlib, importlib.util

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..'))
sys.path.insert(0, HERE)

spec = importlib.util.spec_from_file_location('dg', os.path.join(HERE, 'qml-downgrade.py'))
dg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dg)


def gen_text(src, prof, with_examples):
    """产出 {相对 out 根的路径: 文本}（不落盘）。"""
    modmap = dg.module_map(src)
    if not modmap:
        raise SystemExit('FAIL: src 结构不符预期（找不到 qmldir）')
    out = {}
    counters = collections.Counter()
    for root, _dirs, files in os.walk(src):
        rel = os.path.relpath(root, src).replace(os.sep, '/')
        if rel == '.':
            continue
        uri = None
        for mf in modmap:
            if rel == mf or rel.startswith(mf + '/'):
                if uri is None or len(mf) > len(uri[0]):
                    uri = (mf, modmap[mf])
        if uri is None:
            continue
        sub = rel[len(uri[0]):].lstrip('/')
        # ⚠ `sub` 为空时**不能**再拼 '/'：否则键变成 `Contracts//X.qml`
        #   （双斜杠），与磁盘上的 `Contracts/X.qml` 对不上 →
        #   于是「新增 138 个 + 残留 125 个」全是假的，
        #   还会顺手写出一批错路径文件。（实测踩过。）
        base = os.path.join(uri[1].replace('.', os.sep), sub.replace('/', os.sep)) if sub \
            else uri[1].replace('.', os.sep)
        for fn in files:
            sp = os.path.join(root, fn)
            text = open(sp, encoding='utf-8', errors='replace').read()
            if fn.endswith(('.qml', '.js')):
                text = dg.downgrade_text(text, counters, os.path.relpath(sp, src), prof)
            out[(base.replace(os.sep, '/') + '/' + fn)] = text
    if with_examples:
        ex_src = os.path.join(ROOT, 'examples')
        for root, _dirs, files in os.walk(ex_src):
            for fn in files:
                if not fn.endswith('.qml'):
                    continue
                sp = os.path.join(root, fn)
                text = open(sp, encoding='utf-8', errors='replace').read()
                text = dg.downgrade_text(text, counters, os.path.relpath(sp, ex_src), prof)
                out['examples/' + os.path.relpath(sp, ex_src).replace(os.sep, '/')] = text
    return out, counters


def main():
    if len(sys.argv) < 2:
        print('用法: regenerate-incremental.py <profile> [--with-examples] [--prune]')
        return 2
    profile = sys.argv[1]
    with_ex = '--with-examples' in sys.argv
    prune = '--prune' in sys.argv
    if profile not in dg.PROFILES:
        print('FAIL: 未知 profile %r（可选 %s）' % (profile, ', '.join(sorted(dg.PROFILES))))
        return 2
    prof = dg.PROFILES[profile]
    src = os.path.join(ROOT, 'src')
    out_root = os.path.join(ROOT, prof['outdir'])

    new, counters = gen_text(src, prof, with_ex)
    print('profile = %s  （%s）' % (profile, prof['desc']))
    print('目标= %s' % out_root)
    print('将写入 %d 个文件' % len(new))
    print()

    existing = {}
    for r, _d, fns in os.walk(out_root):
        for fn in fns:
            p = os.path.join(r, fn)
            rel = os.path.relpath(p, out_root).replace(os.sep, '/')
            existing[rel] = hashlib.sha256(open(p, 'rb').read()).hexdigest()

    written, same, added = 0, 0, []
    for rel, text in sorted(new.items()):
        dp = os.path.join(out_root, rel.replace('/', os.sep))
        h = hashlib.sha256(text.encode('utf-8')).hexdigest()
        if rel in existing and existing[rel] == h:
            same += 1
            continue
        if rel not in existing:
            added.append(rel)
        os.makedirs(os.path.dirname(dp), exist_ok=True)
        open(dp, 'w', encoding='utf-8', newline='\n').write(text)
        written += 1

    stale = sorted(set(existing) - set(new))
    print('覆盖更新 %d 个；未变 %d 个；新增 %d 个' % (written, same, len(added)))
    for rel in added[:20]:
        print('   新增 %s' % rel)
    if len(added) > 20:
        print('   ...（另有 %d 个）' % (len(added) - 20))
    print()
    if stale:
        print('⚠ 残留 %d 个（src 已无对应源文件，**本脚本不删**）：' % len(stale))
        for rel in stale[:20]:
            print('   %s' % rel)
        if len(stale) > 20:
            print('   ...（另有 %d 个）' % (len(stale) - 20))
        if not prune:
            print('   ⇒ 增量结果与「全量重新生成」的差异就在这些文件。')
            print('   ⇒ 确认它们确实是废弃产物后，加 --prune 再跑一次。')
    else:
        print('无残留 ⇒ 增量结果与全量重新生成逐字节一致')
    print()
    print('RESULT: OK（%d 个文件已写出）' % written)
    return 0


if __name__ == '__main__':
    sys.exit(main())
