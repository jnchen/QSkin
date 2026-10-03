import subprocess, hashlib, sys
PY = r"C:/Users/caoji/.workbuddy/binaries/python/versions/3.13.12/python.exe"


def run():
    return subprocess.run([PY, "tools/check-doc-readout.py"],
                          capture_output=True, text=True, errors="replace")


def mutate(path, old, new, label, expect_red=True):
    raw = open(path, "rb").read()
    h0 = hashlib.sha256(raw).hexdigest()
    o, n = old.encode("utf-8"), new.encode("utf-8")
    try:
        c = raw.count(o)
        if c != 1:
            print("  %-32s SKIP（锚点命中 %d 次）" % (label, c))
            return
        open(path, "wb").write(raw.replace(o, n))
        r = run()
        red = r.returncode != 0
        mark = "OK 咬住" if red == expect_red else "!! 没咬住"
        first = [l.strip() for l in (r.stdout + r.stderr).splitlines()
                 if l.strip().startswith("·")]
        print("  %-32s RC=%d  %s  %s"
              % (label, r.returncode, mark, (first[0][:52] if first else "")))
    finally:
        open(path, "wb").write(raw)
        assert hashlib.sha256(open(path, "rb").read()).hexdigest() == h0


print("证伪 · 应红的都红了？")
mutate("README.md", "92 个 `QSkin*.qml`", "93 个 `QSkin*.qml`", "契约数 92→93")
mutate("README.md", "**261** 个文件", "**262** 个文件", "qmllint 面 261→262")
mutate("README.md", "控件 **86** 个", "控件 **87** 个", "控件数 86→87")
mutate("README.md", "**105 个类型全部可解析**", "**106 个类型全部可解析**", "类型数 105→106")
mutate("README.md", "8~11 个，各家不同", "5~11 个，各家不同", "插槽区间 8~11→5~11")
mutate("README.md", "**12 道脚本门禁**", "**13 道脚本门禁**", "门数 12→13")

print()
print("反向 · 不该红的别误伤")
mutate("README.md", "契约第 3 条", "契约第 4 条", "'契约第 3 条'→'第 4 条'", False)
mutate("README.md", "**12 道脚本门禁**（字符图标", "**12 道脚本门禁**(字符图标", "去掉一处加粗", False)
