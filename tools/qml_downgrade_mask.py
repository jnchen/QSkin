#!/usr/bin/env python3
"""QML 注释 / 字符串掩码 —— 「什么算真代码」的唯一口径。

为什么单独抽出来：之前 build_mask / split_code 只内嵌在 qml-downgrade.py 里。
后来要复算「Qt 5.11 障碍点到底有多少处真代码」，第一版用 grep 数，
结果把注释里的 `required property`、`HoverHandler` 等**说明文字**全数了进去
（66 处、15 处都是虚高）。于是需要一个能被两个工具共用、且**只有一份定义**
的口径。

⚠ 为什么要共用一份而不是各写一份：一旦两处定义不同，「生成器按 A 口径改、
   门禁按 B 口径数」，就会出现「门禁绿但产物漏改」——
   判据与被测量共享不了同一套假设时，账就对不上（本项目反复踩过这条）。

判定规则（三类段）：
  code    —— 真代码，可被规则改写
  comment —— `//…`、`/*…*/`
  string  —— `"…"` / `'…'`（含转义）
⚠ 字符串也必须屏蔽：import 行里若出现 `//` 会把后半截误判成注释。
"""
import re


def split_code(text):
    """把文本切成 [(kind, start, end)]，kind ∈ {'code','comment','string'}。

    未闭合的字符串/注释按「到文件末尾」处理，不抛异常 —— 探针要能跑在
    半截文件上（门禁经常只看片段）。
    """
    spans, i, n = [], 0, len(text)
    kind, start = 'code', 0

    def flush(end):
        nonlocal start
        if end > start:
            spans.append((kind, start, end))
        start = end

    while i < n:
        c = text[i]
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            flush(i)
            j = text.find('\n', i)
            j = n if j < 0 else j
            spans.append(('comment', i, j))
            start = j
            i = j
        elif c == '/' and i + 1 < n and text[i + 1] == '*':
            flush(i)
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            spans.append(('comment', i, j))
            start = j
            i = j
        elif c in '"\'':
            flush(i)
            q = c
            i += 1
            while i < n and text[i] != q:
                i += 2 if text[i] == '\\' else 1
            i = min(i + 1, n)
            spans.append(('string', start, i))
            start = i
        else:
            i += 1
    flush(n)
    return spans


def build_mask(text):
    """返回长度与 text 相同的 bytearray：code 位置为 1。"""
    mask = bytearray(len(text))
    for kind, s, e in split_code(text):
        if kind == 'code':
            for k in range(s, e):
                mask[k] = 1
    return mask


def code_only(text):
    """把非代码字符（注释/字符串内字符）换成 \\x00，长度不变。

    ⇒ 可以直接拿它跑正则，命中数天然等于「真代码处数」，
       且不会破坏跨行的行结构（换行符本身在注释里也会被换掉，
       但正则里用的是 [^\\n] 之类，不会因此漏行）。
    """
    mask = build_mask(text)
    return ''.join(ch if mask[i] else '\x00' for i, ch in enumerate(text))


def count_code(text, pattern, flags=0):
    """掩码后统计 pattern 在**真代码**里的命中数。"""
    return len(re.findall(pattern, code_only(text), flags))


if __name__ == '__main__':
    src = 'import QtQuick 2.11 // 注释里 required property 不该被数\nItem { property int x: 1 }'
    m = build_mask(src)
    print('长度一致:', len(m) == len(src))
    print('真代码里 required property 命中数:',
          count_code(src, r'required\s+property'))
    print('（应为 0：两个 required property 都在注释里）')
