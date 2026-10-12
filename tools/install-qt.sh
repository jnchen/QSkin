#!/usr/bin/env bash
#############################################################################
# QSkin · 把 Qt 装到项目本地
#
# 用法：
#     ./tools/install-qt.sh              # 默认 Qt 6.8.3 / win64_mingw
#     ./tools/install-qt.sh 6.8.3        # 指定版本
#
# 装到 qds/.qt/ 下，不污染系统、不进 git（已在 .gitignore 里）。
# 本机没有 Qt 也能跑静态检查与示例。
#
# ── 一个值得记住的坑 ──────────────────────────────────────────────────────
# aqt 默认 concurrency = 4，四个包同时下载。在某些网络环境（企业代理、
# 沙箱、部分 CI）下会**稳定**产出校验和不匹配的损坏包：
#
#     ERROR: Downloaded file ...qtbase-...7z is corrupted! Detect checksum error.
#     Expect a2cd0905...  Actual a38121fa...
#
# 5 次重试次次失败，且每次哈希都一样 —— 说明是确定性的损坏，不是网络抖动。
# 同样的 URL 用 curl 或单线程 requests 下载，哈希完全正确。
# 结论：并发流被中间件搞坏了。把 concurrency 降为 1 即可。
#
# 这个脚本会自动改 aqt 的 settings.ini。若你手动跑 aqt，记得自己改。
#############################################################################

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-6.8.3}"
ARCH="${2:-win64_mingw}"
MIRROR="${QSkin_QT_MIRROR:-https://mirrors.aliyun.com/qt/}"
OUTDIR="$(pwd)/.qt"

echo "==> 目标：Qt $VERSION / $ARCH -> $OUTDIR"

# ---------- 1. 找 Python + aqt ----------
PY="${QSkin_PYTHON:-}"
if [ -z "$PY" ]; then
    for cand in python3 python; do
        if command -v "$cand" >/dev/null 2>&1; then PY="$cand"; break; fi
    done
fi
[ -n "$PY" ] || { echo "错误：找不到 python"; exit 1; }

if ! "$PY" -m aqt version >/dev/null 2>&1; then
    echo "==> 安装 aqtinstall"
    "$PY" -m pip install -q aqtinstall
fi

# ---------- 2. 把并发降为 1（见文件头的坑） ----------
AQT_PKG="$("$PY" -c 'import aqt,os;print(os.path.dirname(aqt.__file__))')"
SETTINGS="$AQT_PKG/settings.ini"
if [ -f "$SETTINGS" ]; then
    if grep -q "^concurrency" "$SETTINGS"; then
        sed -i.bak 's/^concurrency[[:space:]]*:.*/concurrency : 1/' "$SETTINGS"
        rm -f "$SETTINGS.bak"
    else
        sed -i.bak '1a\
concurrency : 1' "$SETTINGS"
        rm -f "$SETTINGS.bak"
    fi
    echo "==> aqt concurrency -> $(grep '^concurrency' "$SETTINGS")"
fi

# ---------- 3. 安装 ----------
mkdir -p "$OUTDIR"
echo "==> 开始下载（串行，约 250MB，视网络 3~10 分钟）"
"$PY" -m aqt install-qt windows desktop "$VERSION" "$ARCH" \
    -b "$MIRROR" \
    --outputdir "$OUTDIR"

# ---------- 4. 确认 ----------
TOOLCHAIN_DIR=""
for d in "$OUTDIR/$VERSION"/*/; do
    [ -x "${d}bin/qmllint" ] && TOOLCHAIN_DIR="$d" && break
done

if [ -z "$TOOLCHAIN_DIR" ]; then
    echo "错误：安装完成但没找到 qmllint，目录内容如下："
    ls -R "$OUTDIR" | head -30
    exit 1
fi

# ---------- 5. 补中文字体（Qt 5.11 必需；6.8 上无害）----------
#
# ⚠⚠ **为什么这一步不能省**（实测踩过，且引擎零报错）：
#   Qt **官方二进制不带字体**（5.11 更是连 `lib/fonts` 目录都没有），
#   而它**只认自己那份** —— 系统明明装了雅黑，它也找不到。
#   结果：`Microsoft YaHei` 解析失败 ⇒ 回退到无中文字形的字体
#   ⇒ **每一页的中文都是空心方框**，而 `qml.exe` rc=0、
#   `qmlscene` 只报无关的 OpenGL 提示。**从控制台完全看不出来**，
#   只有把图抓下来看才知道（见 docs/PITFALLS.md）。
#   ⚠ 不是库的 bug —— 库的字体声明是对的。
#
#   Qt 6.8 自带 DejaVu（无 CJK），所以这一步在 6.x 上同样是**必要**的。
FONT_SEED=""
case "$(uname -s 2>/dev/null || echo Windows)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
        # Windows：直接用系统字体
        for c in /c/Windows/Fonts/msyh.ttc "$USERPROFILE/AppData/Local/Microsoft/Windows/Fonts/msyh.ttc" \
                 /c/Windows/Fonts/simsun.ttc /c/Windows/Fonts/simhei.ttf; do
            [ -f "$c" ] && FONT_SEED="$c" && break
        done
        ;;
    Linux|Darwin)
        # ⚠ **不要用 `**`glob** —— bash 要 `shopt -s globstar` 才有，
        #   而这个脚本是 `sh` 兼容写法、未必生效 ⇒ 会静默匹配不到。
        #   用 find（可移植、行为确定）。
        FONT_SEED=$(find /usr/share/fonts /usr/local/share/fonts \
                    -type f \( -iname '*YaHei*' -o -iname '*msyh*' \
                    -o -iname '*NotoSansCJK*' -o -iname '*wqy*' \
                    -o -iname '*SimHei*' -o -iname '*simsun*' \
                    -o -iname '*SourceHanSans*' \) 2>/dev/null | head -1)
        ;;
esac

FONT_DIR="$TOOLCHAIN_DIR/lib/fonts"
if [ -z "$FONT_SEED" ]; then
    echo ""
    echo "⚠️  找不到可用的中文字体（msyh / NotoSansCJK / 文泉驿 / SimHei…）"
    echo "    Qt 不会自带，缺了它**中文会渲染成空心方框而引擎不报错**。"
    echo "    手工放一份进去即可：把任意中文 .ttf/.ttc/.otf 拷到"
    echo "      $FONT_DIR"
else
    # ⚠ `lib/fonts` **默认不存在** —— 实测本机三套 Qt（5.11.1 / 5.15.2 × 2 /
    #   6.8.3）装出来**全都没有**这个目录。所以必须 mkdir，
    #   不能「不存在就跳过」—— 那样这段等于永不生效（实测踩过一次）。
    mkdir -p "$FONT_DIR"
    cp "$FONT_SEED" "$FONT_DIR/"
    echo "==> 中文字体已就位：$(basename "$FONT_SEED") → $FONT_DIR"
fi

echo ""
echo "==> 完成"
"${TOOLCHAIN_DIR}bin/qmllint" --version
echo "==> 接下来可以跑： ./tools/lint.sh"
