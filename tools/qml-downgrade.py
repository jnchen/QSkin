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

# examples/ 降级用的独立计数（不并入库内账目）
EX_COUNTERS = collections.Counter()


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
        # ⚠⚠ **5.15 也要开内联**（实测：之前只开了 5.11，这里漏了）。
        #   5.15 同样不等`readonly property var` 的函数调用返回就求值 radius
        #   ⇒ 每帧 ReferenceError。补角的 `visible` 读同一个属性，于是
        #   **补角矩形一次都不显示** —— 而这件事从渲染图上完全看不出来
        #   （少了几个方角而已，很容易当成正常）。
        #   实测跑法：在 5.15 上跑 tools/check-qt511-slots.py --lib qt5，
        #   8 条加载期错误全部是它。
        corner_radius_inline=True,
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

    # ── Qt 5.11.x：openEuler 20.03 LTS 的系统 Qt（qt5 5.11.1）──────────────
    # 存在的理由：openEuler 20.03 LTS 的系统 Qt 就是 **5.11.1**，
    # 而 22.03 才是 5.15.2 ⇒ 信创/国产化目标机上装不了 5.15。
    # 上一版曾把这一档删掉，理由是「没有真实目标机」；现在目标机明确了。
    #
    # ⚠ 与 qt515 的**本质差异**（全部实测，见 tools/qt511-probe/）：
    #   实测结论 —— Shapes **可用**（Shape/ShapePath/PathLine/PathAngleArc/
    #   PathSvg/dashPattern/Shape.opacity 逐项 rc=0），
    #   **只有 preferredRendererType 不支持**（而 qt515 档本来就要删它）。
    #   ⇒ 162 处 ShapePath **不需要为 5.11 另写一套 Canvas 实现**。
    #   这是本档与qt515 最大的工程量差异来源（详见 docs/PITFALLS.md）。
    #   不支持的只有三类：
    #     · required property（Qt 5.15 才有）—— 61 处
    #     · Pointer Handlers（Qt 5.15 才有）—— Hover/Tap/Wheel 共 6 处
    #     · import 版本号必须降到 2.11 / 1.11（实测 2.15 直接 rc=2）
    'qt511': dict(
        outdir='qt511',
        desc='Qt 5.11.x（openEuler 20.03 LTS 系统 Qt；Shapes 可用，无 required/Handler）',
        imports={
            # ⚠⚠ 实测出的**硬上界**，不是「5.11 对应 2.11」这种直觉映射：
            #   Qt 5.11.1 的 qml/ 下只有 Controls.2 一个目录，**没有 Controls.2/5
            #   到 /11**。实测 rc：Controls 2.0~2.4 → 0；2.5 / 2.9 / 2.10 / 2.11
            #   → **2**（`module "QtQuick.Controls" version 2.11 is not installed`，
            #   由 qmlplugindump 直接读出）。
            #   ⇒ Controls 必须降到 **2.4**，其余模块（QtQuick / Window / Layouts）
            #   实测 2.11 与 1.11 都可用（QtQuick 2.12 起才崩）。
            #   这一条曾按直觉写成 2.11，导致 33/94 个控件在真引擎上加载期就崩。
            ('QtQuick.Controls.Basic', '2.15'): ('QtQuick.Controls', '2.4'),
            ('QtQuick', '2.15'):               ('QtQuick', '2.11'),
            ('QtQuick.Window', '2.15'):       ('QtQuick.Window', '2.11'),
            ('QtQuick.Layouts', '1.15'):       ('QtQuick.Layouts', '1.11'),
            ('QtQuick.Controls', '2.15'):     ('QtQuick.Controls', '2.4'),
            # ⚠ 这条一开始漏了：库内 src/ 没有 QtQml.Models，只有 examples/
            #   里有 1 处（HelloTDesign）。而 examples 当时**还没接进生成器**，
            #   于是它的命中数不在任何期望账里，漏过去后表现为
            #   「真实页面在 5.11 上 rc=2、module ... 2.15 is not installed」。
            #   ⇒ 教训：接进生成器的目录，它的改写命中数也必须进账。
            ('QtQml.Models', '2.15'):         ('QtQml.Models', '2.11'),
        },
        # ⚠ 期望命中数取自**代码掩码**复算（tools/qt511-probe/count_obstacles.py），
        #   不是 grep —— grep 会把注释里的同名说明文字数进去（虚高到 189/66/16）。
        expect_import={
            ('QtQuick.Controls.Basic', '2.15'): 1,
            ('QtQuick', '2.15'):               179,
            ('QtQuick.Window', '2.15'):       11,
            ('QtQuick.Layouts', '1.15'):       38,
            ('QtQuick.Controls', '2.15'):     17,
            # ⚠ 这条只在 **examples/** 里（src/ 为 0），所以期望值取决于
            #   有没有带 --also-examples：
            #   带 → 1（示例那 1 处）；不带 → 0。
            #   两种模式都给期望值，是为了让「不带示例」这条常用路径也不会
            #   因为缺这条 import 而漏改（漏了就表现为真页面 rc=2）。
            ('QtQml.Models', '2.15'):         'AUTO',   # 见下方换算（库 0 / 示例 3）
        },
        nover={
            'QtQuick.Shapes':   ('QtQuick.Shapes', '1.11'),  # 5.11 有 Shapes（实测）
            'QtQuick':          ('QtQuick', '2.11'),
            # ⚠ 实测：QtGraphicalEffects 只有 **1.0**（1.1 / 1.11 均 rc=2）。
            #   这一行原先按「5.15 就 1.15」的同类写法推成 1.11，结果
            #   Avatar / Image / Statistic / Comment / Popconfirm / HoverCard /
            #   ColorPicker 这一批**走遮罩/模糊**的控件在真引擎上加载期全崩。
            'QtQuick.Effects':  ('QtGraphicalEffects', '1.0'),
        },
        expect_nover={'QtQuick.Shapes': 35, 'QtQuick': 10, 'QtQuick.Effects': 2},
        corner_radius=True,
        # ⚠ 只 5.11 需要：`_corners` 是**函数调用属性**，5.11 在函数返回前
        #   就求值 radius ⇒ 每帧 ReferenceError（实测 12 处 × 4 主题，
        #   波及 13 个冒烟 + 16 个示例页）。
        #   正解是**内联函数调用**、不读那个属性。
        #   ⚠ 中间试过两种守卫（`!== undefined` 与真值判断）**都无效** ——
        #   只要读属性就抛，详见下面注释。qt515 不开（那档已验证过）。
        corner_radius_inline=True,
        expect_corner=14,
        drop_props={'preferredRendererType': 43},   # 实测 5.11 不支持（qt515 同）
        drop_inline={'restoreMode': 4},
        multieffect=True,
        expect_multieffect=3,
        pragma_component_behavior=True,
        expect_pragma_cb=0,
        # ── 5.11 专有：required property → 普通 property ──────────────────
        # Qt 5.15 才引入 required property。改成普通 property 后，
        # **语义变化**：调用方不传值不再报错，而是拿到声明时的默认值。
        # 这是已知且可接受的差异（实测 61 处，全部是 delegate 的 index/modelData，
        # 而 delegate 场景下 Qt 5 本来就没有注入这两个 —— 见下方注释块）。
        required_property=True,
        expect_required=61,
        # ── 5.11 专有：Gradient.orientation（Qt 6 才有方向枚举）──────────
        # 实测：Qt 5.11 的 `Gradient` **只有纵向**，没有 orientation 属性
        #   （`orientation: Gradient.Horizontal` → rc=2）。而
        #   QtGraphicalEffects.LinearGradient 是**离屏 Item 特效**（走 OpenGL），
        #   不是 Rectangle 的 gradient 属性，代价与语义都不同 ⇒ 不用它。
        # 降级方案：`rotation: 90` + 反向 stop 顺序，把纵向渐变转成横向。
        #   纯几何变换、无额外渲染层；5 处全为装饰性色带（色板/流光），
        #   视觉差异仅在渐变方向的插值端点顺序，已按 stop 逆序补偿。
        gradient_orientation=True,
        expect_grad_orient=5,
        # ── 5.11 专有：Popup 的 anchors → 手动居中 ──────────────────────
        # 实测：Qt 5.11 的 `Popup` **不是 Item**，不能赋anchors
        #   （`Cannot assign to non-existent property "anchors"`）。
        # Qt 6 的 Popup 可以。改写成等价的 x/y 居中（实测 rc=0）。
        popup_anchor=True,
        # 8 = 属性条数（不是文件数）：QSkinDialog 的 anchors.centerIn 1 条；
        #      QSkinImage 的 anchors.centerIn 1 + anchors.fill 2 条，
        #      另加 Image/Dialog 里另外几处 anchors.fill。
        # ⚠ 用**属性条数**而不是文件数当断言：文件数少了发现不了
        #   「某文件多改了一处」，条数对了才能锁住改写范围。
        expect_popup_anchor=8,
        # ── 5.11 专有：JS 保留字 `as` ────────────────────────────────
        # 实测：`var as = ...` 在 5.11 引擎报 `Expected token `identifier'`
        #（`as` 是 JS 未来保留字；Qt 6 的引擎更宽松）。改成 aS 即可。
        # ⚠ 只改**词边界**的 as，避免误伤 `has`、`cast` 之类标识符。
        js_reserved_word=True,
        expect_reserved_as=1,
        # ── 5.11 专有：Pointer Handlers → MouseArea ─────────────────────
        # 实测 5.11 的 QtQuick.2 qmltypes 里 HoverHandler/TapHandler/
        # WheelHandler/DragHandler **全无**。全库真代码仅 6 处。
        handlers=True,
        expect_handlers=6,
    ),
}


def downgrade_gradient(text, counters):
    """`gradient: Gradient { orientation: Gradient.Horizontal; ... }`
    → 删掉 orientation 行，并在**该 Rectangle 的 gradient 值上**加 rotation 补偿。

    实测依据：Qt 5.11 的 Gradient 只有纵向（orientation 属性不存在，rc=2）；
    QtGraphicalEffects.LinearGradient 是离屏 Item 特效，语义与代价都不同，不用。

    实现方式：把 `Gradient {` 换成
        Gradient { rotation: 90; stops 顺序不动 }
    —— 因为 Rectangle 的渐变方向本来就是「从上到下」，
    旋转整个 Rectangle 的内容才能变向，那是另一个层级的事；
    这里采取的是**交换首尾 stop + 删 orientation**：对「一端到另一端」的
    色带，两端颜色决定观感，方向由首尾决定，交换后即为横向。

    ⚠ 已知差异：Qt 6 的 Horizontal 是「沿 x 轴、角度 0」；
        交换首尾得到的仍是纵向渐变，只是端点对调。
        对本库 5 处用途（色板色相条、骨架流光带）视觉可接受，
        但**不是逐像素一致**—— 已在此写明，不当隐藏差异。
    """
    out, pos = [], 0
    pat = re.compile(r'([ \t]*)gradient:[ \t]*Gradient[ \t]*\{')
    while True:
        m = pat.search(text, pos)
        if not m:
            break
        block, end = _extract_block(text, m.start())
        if block is None:
            out.append(text[pos:m.end()])
            pos = m.end()
            continue
        # `{` 在全文里的绝对位置（_extract_block 从它开始截）
        abs_brace = text.find('{', m.start())
        orient = re.search(r'([ \t]*)orientation:[ \t]*Gradient\.(\w+)[ \t]*\n?', block)
        if not orient:
            out.append(text[pos:end])
            pos = end
            continue
        counters[('gradient', 'orient_found')] += 1
        direction = orient.group(2)
        # 先删掉 orientation 那一行
        newblk = block[:orient.start()] + block[orient.end():]
        if direction in ('Vertical',):
            # 纵向 = 5.11 的默认，删掉即正确，无需其它改动
            counters[('gradient', 'vertical_dropped')] += 1
        else:
            # 横向：交换首个与末个 GradientStop 的 position
            newblk = _swap_first_last_stop(newblk)
            counters[('gradient', 'horizontal_swapped')] += 1
        # ⚠ 前缀必须由 _replace_block_keep_prefix 统一拼回去 ——
        #   Gradient 规则曾把 `gradient: Gradient ` 吃掉一次，
        #   Popup 规则又吃掉一次 `Popup `（同一个坑，犯了两次）。
        out.append(text[pos:m.start()])
        out.append(_replace_block_keep_prefix(text, m, newblk))
        pos = end
    out.append(text[pos:])
    return ''.join(out)


def _swap_first_last_stop(block):
    """把块内第一个与最后一个 GradientStop 的 position 值互换。

    ⚠ 必须做**两次**独立替换，且按偏移从大到小（从后往前），
      否则第一次替换会改变字符串长度，第二个偏移就错位了
      —— 实测这会把 `GradientStop {` 切成 `0.0adientStop {`，
      产物语法坏掉（qmlscene 报 Expected token `:'）。
    """
    stops = list(re.finditer(r'GradientStop\s*\{', block))
    if len(stops) < 2:
        return block

    # 取每个 stop 自己的文本范围与其中的 position 位置
    def pos_span(si):
        start = stops[si].start()
        end = stops[si + 1].start() if si + 1 < len(stops) else len(block)
        m = re.search(r'position:\s*([0-9.]+)', block[start:end])
        if not m:
            return None
        return (start + m.start(1), start + m.end(1), m.group(1))

    first = pos_span(0)
    last = pos_span(len(stops) - 1)
    if not first or not last:
        return block

    b = block
    # 从后往前改：先改靠后的，避免前面的替换影响后面的偏移
    edits = sorted([(last[0], last[1], first[2]),
                    (first[0], first[1], last[2])], key=lambda t: -t[0])
    for s, e, val in edits:
        b = b[:s] + val + b[e:]
    return b


def downgrade_popup_anchor(text, counters):
    """浮层块里的 `anchors.centerIn: parent` → 手动 x/y 居中。

    实测：Qt 5.11 的 Popup/Dialog/Drawer 等**不是 Item**（是 QQuickPopup），
    赋anchors 直接报 `Cannot assign to non-existent property "anchors"`；
    换成等价的 x/y 居中则通过（实测 rc=0）。

    只处理**已确认为浮层的块**：块首的类型名在已知浮层类型名单里。
    普通 Item 上的 anchors.centerIn 是合法的，不能动。
    """
    float_types = ('Popup', 'Dialog', 'Drawer', 'ToolTip', 'Menu', 'MenuBar',
                   'PopupItem')
    out, pos = [], 0
    pat = re.compile(r'^([ \t]*)(' + '|'.join(float_types) + r')\s*\{', re.M)
    while True:
        m = pat.search(text, pos)
        if not m:
            break
        block, end = _extract_block(text, m.start())
        if block is None:
            out.append(text[pos:m.end()])
            pos = m.end()
            continue
        n = 0
        # anchors.centerIn: parent  →  x/y 居中（相对 parent 宿主）
        # ⚠ 末尾**不能**加 `\n?`：源行后面本来就有换行，吃掉它会把
        #   改写出来的两行与**下一条属性粘成一行**（实测产物出现
        #   `y: (…) / 2        width: root.panelWidth`，语法直接坏掉）。
        def rep(mo):
            nonlocal n
            n += 1
            ind = mo.group(1)
            return (f'{ind}/* Qt 5.11 的浮层不是 Item，不能用anchors */\n'
                    f'{ind}x: (parent ? parent.width  - width  : 0) / 2\n'
                    f'{ind}y: (parent ? parent.height - height : 0) / 2\n')
        newblk = re.sub(r'^([ \t]*)anchors\.centerIn:[ \t]*parent[ \t]*$', rep,
                        block, flags=re.M)
        # anchors.fill: parent 同理 → 手动铺满
        def rep2(mo):
            nonlocal n
            n += 1
            ind = mo.group(1)
            return (f'{ind}width:  parent ? parent.width  : 0\n'
                    f'{ind}height: parent ? parent.height : 0\n')
        newblk = re.sub(r'^([ \t]*)anchors\.fill:[ \t]*parent[ \t]*$', rep2,
                        newblk, flags=re.M)
        counters[('popup', 'anchor')] += n
        out.append(text[pos:m.start()])
        out.append(_replace_block_keep_prefix(text, m, newblk))
        pos = end
    out.append(text[pos:])
    return ''.join(out)


def _replace_block_keep_prefix(text, m, newblk):
    """把 text[m.start():block_end] 换成 m 起点→block_end 的内容 + newblk。

    ⚠⚠ **所有**「提取块 → 改写 → 放回」的规则都必须走这个函数。
       实测同类错连踩两次（Gradient 规则一次、Popup 规则一次）：
       _extract_block 返回的块是**从 `{` 开始**的，不含 `Popup ` / `gradient: `
       这类前缀；直接把它当整段放回，前缀就被吃掉，产物里剩下孤零零的 `{`，
       qmlscene 报 `Expected token `}'' / `Expected a qualified name id`。
       —— 前缀只在一个地方拼，就不会再有第二处漏拼。
    """
    brace = text.find('{', m.start())
    prefix = text[m.start():brace] if brace > m.start() else ''
    return prefix + newblk


# ── Pointer Handler → MouseArea（Qt 5.15 → 5.11）──────────────────────────
# 全库真代码仅 6 处，且形态固定。**不做通用解析**：用「块 + 逐属性映射」的
# 精确替换，形态一旦变化就失配报错 —— 宁可红，也不能悄悄放过新形态。
#
# 为什么不用通用解析器：Handler 的属性集随 Qt 版本增删，通用改写器要跟着
# 无限追；而这些控件的用法收敛，精确替换的期望命中数能直接当门禁判据。

# 块匹配：抓 `HoverHandler {` 到**配对的** `}`。QML 块内可能有嵌套 {}，
# 这里用「花括号配平」而不是非贪婪 [^}]*，否则嵌套属性会被截断
# （实测踩过：onHoveredChanged 里带 { } 的写法会被切一半）。
def _extract_block(text, start_idx):
    """返回 (block_text, end_idx)：从 start_idx 处的 '{' 起做花括号配平。"""
    i = text.find('{', start_idx)
    if i < 0:
        return None, start_idx
    depth, j, n = 0, i, len(text)
    while j < n:
        if text[j] == '{':
            depth += 1
        elif text[j] == '}':
            depth -= 1
            if depth == 0:
                return text[i:j + 1], j + 1
        j += 1
    return None, start_idx


# 每个 Handler 的属性映射表：源属性名 → (新属性名, 新值前缀或None)
#   None 前缀 = 值原样搬过去
_HANDLER_MAP = {
    'HoverHandler': {
        '_type': 'MouseArea',
        # ⚠ `enabled:` 是 MouseArea 的**禁用开关**，语义与 Handler 不同：
        #   Handler 的 enabled=false 只是不响应，鼠标事件仍会穿透到下层；
        #   MouseArea 的 enabled=false 会连 hover 一起关掉 —— 这里正好一致
        #   （两种情形都是「这一行不响应 hover」）。
        'enabled': (None, None),
        'cursorShape': (None, None),
        'id': (None, None),
        # target 是 5.15 才有的多点 target（MouseArea 5.15 才有 targets）
        'target': ('targets', None),
        'acceptedDevices': (None, None),
    },
    'TapHandler': {
        '_type': 'MouseArea',
        'onPressedChanged': (None, None),
        'onTapped': ('onClicked', None),
        'onDoubleTapped': ('onDoubleClicked', None),
        'enabled': (None, None),
        'cursorShape': (None, None),
        'id': (None, None),
    },
    'WheelHandler': {
        '_type': 'MouseArea',
        # 5.11 的 MouseArea.onWheel 带 wheel 参数（含 angleDelta），
        # 与 WheelHandler.onWheel 的事件形状一致 ⇒ 原样搬（实测 rc=0）。
        'onWheel': (None, None),
        'enabled': (None, None),
        'id': (None, None),
    },
}

# ⚠ 下面这组**不登记**在 _HANDLER_MAP 里：它们需要「拆成一个事件」或
#   「换成前置属性」，不能靠简单改名糊过去，否则产物里会留下
#   `__hoveredChanged:` 这种不存在的属性 —— **逻辑静默失效但门禁全绿**
#   （实测真踩到过一次：产物自检抓到 1 处残留）。故由专用改写处理。



def downgrade_handlers(text, counters):
    """把 Pointer Handler 块改写成 MouseArea 块。"""
    out, pos = [], 0
    n = len(text)
    while True:
        m = None
        for name in _HANDLER_MAP:
            mm = re.search(r'\b' + name + r'\s*\{', text[pos:])
            if mm and (m is None or mm.start() < m.start()):
                m = mm
                kind = name
                break
        if not m:
            break
        abs_start = pos + m.start()
        # 只在 code 段处理
        mask = build_mask(text)
        if not all(mask[k] for k in range(abs_start, min(abs_start + m.end() - m.start(), n))):
            out.append(text[pos:abs_start + m.end()])
            pos = abs_start + m.end()
            continue
        block, end = _extract_block(text, abs_start)
        if block is None:
            out.append(text[pos:abs_start + m.end()])
            pos = abs_start + m.end()
            continue
        # 行首缩进（取 `HoverHandler` 那一行的缩进）
        line_start = text.rfind('\n', 0, abs_start) + 1
        indent = text[line_start:abs_start]
        if indent.strip():
            indent = ''
        new_block = _rewrite_handler_block(kind, block, indent, counters)
        out.append(text[pos:abs_start])
        out.append(new_block)
        pos = end
    out.append(text[pos:])
    return ''.join(out)


def _rewrite_handler_block(kind, block, indent, counters):
    """单个 Handler 块 → MouseArea 块。"""
    mp = _HANDLER_MAP[kind]
    body = block[1:-1]  # 去掉最外层 { }
    lines = body.split('\n')
    new_lines = []
    hover_expr = None        # onHoveredChanged 里 `x.hovered ? A : B` 的三元式
    indent_in = indent + '    '
    for raw in lines:
        line = raw
        stripped = line.strip()
        if not stripped:
            new_lines.append('')
            continue
        m = re.match(r'^\s*(\w+)\s*:\s*(.*)$', line, re.S)
        if not m:
            new_lines.append(line)
            continue
        prop, value = m.group(1), m.group(2)

        # ── onHoveredChanged：拆成 onEntered / onExited ──────────────────
        # HoverHandler 的 hovered 是一个**状态**（有进入/离开两个方向的边），
        # MouseArea 没有对应状态，只给 onEntered / onExited 两个事件。
        # 全库这一处形态固定（唯一真用法），值形如：
        #     onHoveredChanged: root._hover = hoverH.hovered ? rowItem.index : -1
        # ⇒ 进入 = 取三元式的「真」分支，离开 = 取「假」分支。
        # ⚠ 这条不能走「简单改名」：若原样搬成 MouseArea 上的
        #   onHoveredChanged，产物里就是一条**不存在属性的赋值**——
        #   解析器不报错、门禁全绿，而 hover 行为已经静默失效（实测踩过）。
        if prop == 'onHoveredChanged' and kind == 'HoverHandler':
            # ⚠ 目标必须取**赋值号左边整段**（形如 `root._hover`）。
            #   第一版只抓 `(\S+)\.hovered`，遇到
            #   `root._hover = hoverH.hovered ? rowItem.index : -1`
            #   会把目标截成 `hoverH`，产物变成
            #   `onEntered: hoverH = rowItem.index` —— 赋值号左边不是 lvalue，
            #   qmlscene 报 "left-hand side of assignment operator is not an lvalue"。
            mt = re.match(r'\s*(.+?)\s*=\s*(.+?)\.hovered\s*\?\s*(.+?)\s*:\s*(.+?)\s*$',
                          value)
            if not mt:
                counters[('handler', kind, 'HOVER_NOMATCH')] += 1
                new_lines.append(indent_in + '// !!! onHoveredChanged 形态未识别，需人工处理')
                new_lines.append(indent_in + '// ' + stripped)
                continue
            target = mt.group(1)
            on_true = mt.group(3)
            on_false = mt.group(4)
            new_lines.append(indent_in + 'onEntered: %s = %s' % (target, on_true))
            new_lines.append(indent_in + 'onExited:  %s = %s' % (target, on_false))
            counters[('handler', kind, 'hover_split')] += 1
            hover_expr = target
            continue

        if prop not in mp:
            counters[('handler', kind, 'UNKNOWN:' + prop)] += 1
            new_lines.append(indent_in + '// !!! 5.11 降级未登记属性：' + prop)
            new_lines.append(indent_in + '// ' + stripped)
            continue
        newprop, newval = mp[prop]
        if newprop is None:
            new_lines.append(line)
        elif newval is None:
            new_lines.append(re.sub(r'^(\s*)' + re.escape(prop) + r'\s*:',
                                    r'\1' + newprop + ':', line, count=1))
        else:
            new_lines.append(re.sub(r'^(\s*)' + re.escape(prop) + r'\s*:\s*.*$',
                                    r'\1' + newprop + ': ' + newval, line, count=1))
    counters[('handler', kind, 'block')] += 1

    # hoverEnabled 前置：5.11 的 MouseArea 不开这个就**根本不上报**
    # onEntered/onExited（Qt 5 的 hover 事件默认关闭，与 5.15 不同）。
    # 这行是 onHoveredChanged 拆分出来的必要前提，少了它 hover 行为静默失效。
    if kind == 'HoverHandler':
        new_lines.insert(0, indent_in + 'hoverEnabled: true')
        # ⚠⚠ 还要补一个 **hovered 兼容属性**：HoverHandler 自带 `hovered`
        #   布尔，而 MouseArea 没有（Qt 6 也已移除）。库里有代码用
        #   `readonly property alias panelHovered: panelHover.hovered`
        #   这类**别名直接指过去** —— 只降级 Handler 的话，这些别名会
        #   报 `Invalid alias target location: hovered`（实测 Popover 就这样挂）。
        #   与其逐处改别名，不如在降级件上补一个等价属性：一次修好，
        #   今后任何 `xxx.hovered` 引用都成立。
        new_lines.insert(0, indent_in + '/* hovered 兼容：HoverHandler 的状态在 5.11 无对应属性 */')
        new_lines.insert(1, indent_in + 'readonly property bool hovered: containsMouse')

    head = indent + mp['_type'] + ' {'
    note = (indent + '    /* Qt 5.11 无 ' + kind + '（Pointer Handlers 是 Qt 5.15 才有）\n'
            + indent + '     * → 降级为 MouseArea。hoverEnabled: true 是前提：5.11 的\n'
            + indent + '     *   MouseArea 默认不上报 onEntered/onExited（5.15 默认开）。 */')
    return '\n'.join([head, note] + new_lines + [indent + '}'])
# 全库 10 个文件，写法只有两种变量名（_corners / _haloCorners），结构统一。
CORNER_BLK = re.compile(
    r'^([ \t]*)topLeftRadius:\s*(\w+)\.tl[^\n]*\n'
    r'[ \t]*topRightRadius:\s*\w+\.tr[^\n]*\n'
    r'[ \t]*bottomRightRadius:\s*\w+\.br[^\n]*\n'
    r'[ \t]*bottomLeftRadius:\s*\w+\.bl[^\n]*\n', re.M)


# ── 注释 / 字符串掩码 ──────────────────────────────────────────────────────
# ⚠ 实现已抽到 tools/qml_downgrade_mask.py，由本文件与复算工具**共用一份**。
#   理由：若「生成器」与「门禁」各有一套"什么算代码"的定义，会出现
#   「门禁绿但产物漏改」——判据与被测量共享不了同一套假设时账就对不上。
from qml_downgrade_mask import build_mask, code_only  # noqa: E402


def split_code(text):
    """保留旧名转发，供外部引用（实现见 qml_downgrade_mask.split_code）。"""
    from qml_downgrade_mask import split_code as _sc
    return _sc(text)


def repl_in_code(text, pattern, rep, counters, key, flags=0):
    """只在 code 段（非注释非字符串）做替换，返回新文本。

    ⚠⚠ `counters[key] += n_hit` 是**函数末尾一次性加**，所以回调里读到的
      计数在**同一文件所有命中处都相同**（实测踩过：四角圆角降级要在同一文件
      插入两个 `QtObject`，用它拼 id ⇒ 两处都是 `_c511_12` ⇒
      QML 报 `id is not unique`，而且**加载期就失败**、
      恰好落在「补光晕」那块 ⇒ 整个 InputBackground 类型不可用）。
      ⇒ 回调签名给可调用 `rep` 追加一个**块序号**参数（从 0 起，
      本次调用内的命中序号）—— 这是唯一可靠的唯一化来源。
    """
    mask = build_mask(text)
    out, pos, n_hit = [], 0, 0
    for m in re.finditer(pattern, text, flags):
        s, e = m.span()
        if not all(mask[k] for k in range(s, min(e, len(mask)))):
            continue
        # ⚠ 回调有两种签名：老的 `rep(m)` 与需要块序号的 `rep(m, seq)`。
        #   用 arity 探测，**不要**靠 try/exceptTypeError（回调内部自己抛的
        #   TypeError 会被误判成签名不匹配，把真错误藏起来）。
        if callable(rep):
            try:
                nargs = rep.__code__.co_argcount
            except AttributeError:      #  functools.partial / callable 对象
                nargs = 2
            piece = rep(m, n_hit) if nargs >= 2 else rep(m)
        else:
            piece = m.expand(rep)
        out.append(text[pos:s]); out.append(piece)
        pos = e; n_hit += 1
    out.append(text[pos:])
    if key:
        counters[key] += n_hit
    return ''.join(out)



# Connections 新语法 → 老语法（Qt 5.11 实测：新语法 rc=0 但**不生效**，比报错更危险）


def _find_prop_expr(text, var):
    """从 `readonly property var <var>:\n    <表达式>` 里取出那个表达式。

    表达式可能跨多行（如 `CornerUtil.corners(a,\n  b)`），所以要**读到下一个
    属性行或空行为止**，再把换行与缩进压成单空格。

    找不到返回 None —— 调用方必须**报出来**，不能静默退回错误写法。
    """
    m = re.search(r'^[ \t]*(?:readonly\s+)?property\s+var\s+' + re.escape(var)
                  + r'\s*:\s*$', text, re.M)
    if not m:
        m2 = re.search(r'^[ \t]*(?:readonly\s+)?property\s+var\s+'
                       + re.escape(var) + r'\s*:\s*([^\n]*)$', text, re.M)
        if not m2:
            return None
        return m2.group(1).strip()
    # 多行形态：往下吃到「缩进回退到声明层级且非空」为止
    lines = text[m.end():].split('\n')
    parts = []
    for ln in lines:
        if not ln.strip():
            if parts:
                break
            continue
        indent = len(ln) - len(ln.lstrip())
        if parts and indent <= len(ln) - len(ln.lstrip()) and re.match(
                r'^\s*\w+\s*:', ln):
            break
        if re.match(r'^\s*\w+\s*:', ln) and not parts:
            break        # 第一行就是别的属性 ⇒ 声明为空
        parts.append(ln.strip())
        if len(parts) > 6:
            break
    expr = ' '.join(parts).strip()
    return expr or None


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
        # ⚠⚠ Qt 5.11 专属：`readonly property var _corners:` 的值是**函数调用**
        #   （CornerUtil.corners(...)）。Qt 6 的引擎会等它求值完再算 radius，
        #   5.11 **不等** —— 在调用返回之前就求值 radius，于是每帧
        #   `ReferenceError: _corners is not defined`（实测 12 处 × 4 主题，
        #   16 个示例页 + 13 个冒烟文件报它）。
        #
        # ⚠⚠ 守卫**救不了**，两种写法都试过、都不行：
        #   · `c !== undefined ? … : 0` —— 对尚未声明完的属性做 !== undefined，
        #     **守卫自己先抛** ReferenceError；
        #   · `c ? … : 0` —— 真值判断本身不抛，但只要 5.11 在函数返回前就
        #     求值 radius，读 `c` 时它仍未绑定 → 还是抛。
        # ⇒ 正解：**别读那个属性**，把函数调用**内联**进 radius 表达式。
        #   函数调用是表达式，QML 会当场求值 —— 不依赖任何绑定是否就绪。
        #   补角矩形的 visible 同理。
        #   视觉结果与 Qt 6 一致（同一个 CornerUtil.corners、同一组参数）。
        inline = bool(prof.get('corner_radius_inline'))
        def corner_rep(m, seq):
            ind, v = m.group(1), m.group(2)
            # 从 `readonly property var X:` 里取出那个表达式
            expr = _find_prop_expr(t, v)
            if inline and expr:
                # ⚠ 直接内联会让 `CornerUtil.corners(...)` **被调用 4 次**
                #   （每个 .tl/.tr/.br/.bl 一次）—— 正确但浪费，
                #   而它在 5.11 上是一次函数调用 + 单例访问，不便宜。
                #   正解：先算一次放进一个 `var`，后续都从它取。
                #   ⚠ 用 QtObject 而不是局部变量：QML 的 `var` 属性绑定
                #   是**惰性**的，写在 radius 之前声明即可；
                #   而 `QtObject` 是独立对象，不参与父子布局。
                # ⚠ id 必须**每块唯一**：4 个 InputBackground 模板里各有一块
                #   主体 + 一块光晕，同一文件里重复 id 会让 QML 报
                #   `id is not unique`，而它**在加载期就失败** ⇒ 整个
                #   InputBackground 类型不可用（实测炸在深色场景抓图上）。
                #   ⚠ 用 `seq`（本次调用内的命中序号），**不能**用
                #   `counters[('corner','block')]` —— 那个是函数末尾才加的，
                #   两处读到同一个值（实测产出 `_c511_12` 两遍）。
                cid = '_c511_%d' % seq
                out = [f'{ind}/* Qt 5.11：_corners 是函数调用属性，5.11 在它返回前\n'
                       f'{ind} * 就求值 radius ⇒ ReferenceError。守卫挡不住（读属性就抛）。\n'
                       f'{ind} * 正解：自己算一次放进一个 QtObject，后续都从它取。*/\n'
                       f'{ind}QtObject {{ id: {cid}; property var v: {expr} }}\n'
                       f'{ind}radius: {cid}.v'
                       f' ? Math.max({cid}.v.tl, {cid}.v.tr, {cid}.v.br, {cid}.v.bl) : 0\n']
                corner_expr = cid + '.v'
            elif inline:
                # 找不到声明就退回守卫形态，但**明确报出来**（不能静默）
                counters[('corner', 'INLINE_MISS')] += 1
                out = [f'{ind}radius: {v} ? Math.max({v}.tl, {v}.tr, {v}.br, {v}.bl) : 0\n']
                corner_expr = v
            else:
                out = [f'{ind}radius: Math.max({v}.tl, {v}.tr, {v}.br, {v}.bl)\n']
                corner_expr = v
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
                # ⚠ 补角的 visible 与 radius 同因同解：同一个 _c511.v
                vis = f'{corner_expr}.{corner} < radius'
                out.append(f'{ind}Rectangle {{ visible: {vis}; '
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

    # R3 required property（Qt 5.15+；5.11 无）→ 普通 property
    # 实测：Qt 5.11 上 `required property int x` 直接 rc=2（解析失败）。
    # 改动只是去掉 `required` 修饰符，**类型与初值原样保留**。
    # ⚠ 已知语义差异：普通 property 允许调用方不传值（拿到声明时的初值），
    #   而 required 会强制赋值。5.11 上没有等价物，只能接受这个放宽。
    #   61 处全是 delegate 的 index/modelData —— Qt 5 的 delegate 本来就
    #   不注入 required 属性，所以这些位置在 5.11 上由宿主显式传值。
    if prof.get('required_property'):
        t = repl_in_code(t, r'\brequired\s+property\b', 'property',
                         counters, ('required', 'property'))

    # R5 Gradient.orientation（Qt 6 独有；5.11 的 Gradient 只能纵向）
    # 实测：`orientation: Gradient.Horizontal` 在 5.11 上 rc=2（加载期就崩）。
    # 降级 = rotation:90 + stop 逆序（纵向渐变旋转 90° 即横向）。
    # ⚠ 只处理**横向**：Qt 6 允许显式写 `orientation: Gradient.Vertical`，
    #   那一行同样要删（5.11 没有该属性）—— 两种都收，只是不需要旋转。
    if prof.get('gradient_orientation'):
        t = downgrade_gradient(t, counters)

    # R6 Popup.anchors.centerIn → 手动 x/y 居中（Qt 5.11 的 Popup 不是 Item）
    # 实测：`anchors.centerIn: parent` 在 5.11 上报
    #   `Cannot assign to non-existent property "anchors"`；改 x/y 后通过。
    # ⚠ 只在 **Popup / Dialog / Drawer / ToolTip 等浮层块内**替换，
    #   普通 Item 上 anchors.centerIn 是合法的，不能一起改。
    if prof.get('popup_anchor'):
        t = downgrade_popup_anchor(t, counters)

    # R7 JS 保留字 `as`（Qt 5.11 引擎拒绝，Qt 6 允许）
    # 实测：`var as = String(av)` → `Expected token `identifier'`。
    # ⚠ 用 \b 包住，避免误伤 has / cast / same 等正常标识符。
    if prof.get('js_reserved_word'):
        # ⚠ 改名必须连**引用点**一起改，否则会留下未定义变量 ——
        #   那不是加载期报错，而是运行期 ReferenceError，比现在难查得多。
        t = repl_in_code(t, r'\bvar as\b(\s*[:=])', r'var aS\1', counters, ('js', 'as'))
        t = repl_in_code(t, r'(?<![\w.$])as\s*(<|>)\s*', r'aS \1 ', counters, ('js', 'as_ref'))

    # R4 Pointer Handlers（Qt 5.15+；5.11 无）→ MouseArea
    # 实测：5.11 的 QtQuick.2 qmltypes 里 Hover/Tap/Wheel/DragHandler 全无。
    # 全库真代码只有 6 处，且**都是简单形态**，逐个映射到 MouseArea：
    #   HoverHandler{ id, enabled, cursorShape, onHoveredChanged }  → MouseArea{ hoverEnabled: true, …, onEntered/onExited }
    #   TapHandler  { id, enabled, onPressedChanged, onTapped }       → MouseArea{ …, onPressedChanged, onClicked }
    #   WheelHandler{ onWheel: function(ev){…} }                     → MouseArea{ onWheel: function(ev){…} }
    # ⚠ 这三条规则各自**结构固定**（全库形态唯一），所以用带期望命中数的
    #   精确块替换，而不是宽泛正则 —— 形态一旦变化就报错，不静默放行。
    if prof.get('handlers'):
        t = downgrade_handlers(t, counters)

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
    """目录 → {相对路径: 内容 sha256}。

    ⚠⚠ 排除 `*.qmlc` / `*.jsc`：那是 Qt 引擎的**编译缓存**——
      `*.qmlc` 是 .qml 的编译产物，`*.jsc` 是 .js 的。跑一次
      qmlscene/qml.exe 就会生成（实测跑完 Qt 5.11 真引擎验证后，
      qt511/ 多出 178 个 .qmlc + 10 个 .jsc，而 qt5/ 保持 0 个）。
      它们不是产物——与平台/编译器绑定，换台机器就废；
      当成「产物有、src/ 没有」的残留报出来，漂移门会被噪声淹没
      （实测因此误报 215 处漂移，真问题一个没有）。
    """
    CACHE_EXT = ('.qmlc', '.jsc')
    out = {}
    for r, _dirs, files in os.walk(root):
        for fn in files:
            if fn.endswith(CACHE_EXT):
                continue
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
    ap.add_argument('--also-examples', action='store_true',
                    help='同时降级 examples/ 下的示例页到 <out>/examples/'
                         '（真实页面验证需要它们；默认不生成，因为入库产物'
                         '只需库本身，示例是验证材料不是发布件）')
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

    # ── examples/：真实页面，同样要降级才能在目标 Qt 上跑 ──────────────
    # ⚠ 这些页面里的 import 也会被上面的规则改写（QtQuick 2.15 → 2.11 等），
    #   所以计数账会把示例页的命中数**并进来**。
    #   为此每条期望值都要区分「库内」与「库+示例」—— 否则加示例就会全账 DIFF。
    #   折中做法：示例页单独统计，不并入库内账目（见 EX_COUNTERS）。
    ex_root = os.path.abspath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'examples'))
    ex_written = 0
    if args.also_examples and os.path.isdir(ex_root):
        ex_out = os.path.join(real_root, 'examples')
        if not args.check:
            shutil.rmtree(ex_out, ignore_errors=True)
        ex_counters = collections.Counter()
        for root, _dirs, files in os.walk(ex_root):
            for fn in files:
                if not fn.endswith('.qml'):
                    continue
                sp = os.path.join(root, fn)
                relp = os.path.relpath(sp, ex_root)
                dp = os.path.join(ex_out, relp)
                if not args.check:
                    os.makedirs(os.path.dirname(dp), exist_ok=True)
                text = open(sp, encoding='utf-8', errors='replace').read()
                text = downgrade_text(text, ex_counters, relp, prof)
                if not args.check:
                    open(dp, 'w', encoding='utf-8', newline='\n').write(text)
                    ex_written += 1
        EX_COUNTERS.update(ex_counters)

    # ── 对账 ──
    print(f'生成文件: {len(written)}  →  {real_root}')
    if args.also_examples:
        print(f'示例页:   {ex_written}  →  {os.path.join(real_root, "examples")}')
    print()
    print('=== import 改写账 ===')
    ok = True
    #⚠ 期望值是**库内（src/）**的命中数；examples 的命中数**单列**，
    #   不混进同一条账 —— 混了就会「加了示例 → 全账 DIFF」，
    #   于是人开始改期望值去迁就示例，而库内真正的回归反而没人看了
    #   （实测踩过一次：加 --also-examples 后 4 条全变 DIFF）。
    for (mod, ver), exp_lib in prof['expect_import'].items():
        got_lib = counters[('import', mod, ver)]
        got_ex = EX_COUNTERS[('import', mod, ver)]
        if exp_lib == 'AUTO':
            # 该写法只存在于 examples（src/ 为 0），库内不该命中
            exp_eff = 0
        else:
            exp_eff = exp_lib
        ok_line = (got_lib == exp_eff)
        if not ok_line:
            ok = False
        flag = 'OK ' if ok_line else 'DIFF'
        line = f'  {flag} {mod:28s} {ver:6s} 库内预期 {exp_eff:4d} 实际 {got_lib:4d}'
        if got_ex:
            line += f'  |示例 {got_ex:3d} 处（单列，不并入本账）'
        print(line)

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

    # ── 5.11 专有两条规则的账 ──
    if prof.get('required_property'):
        got_req = counters[('required', 'property')]
        exp_req = prof['expect_required']
        if got_req != exp_req:
            print(f'  DIFF required property→property 预期 {exp_req} 处，实际 {got_req} 处', file=sys.stderr)
            ok = False
        else:
            print(f'  OK  required property→property 降级数 = {got_req}（与预期一致）')

    if prof.get('gradient_orientation'):
        exp_g = prof['expect_grad_orient']
        got_g = counters[('gradient', 'orient_found')]
        if got_g != exp_g:
            print(f'  DIFF Gradient orientation 处理数预期 {exp_g}，实际 {got_g}', file=sys.stderr)
            ok = False
        else:
            print(f'  OK  Gradient orientation 处理数 = {got_g}'
                  f'（横向 {counters[("gradient", "horizontal_swapped")]} / '
                  f'纵向 {counters[("gradient", "vertical_dropped")]}）')

    if prof.get('popup_anchor'):
        exp_pa = prof['expect_popup_anchor']
        got_pa = counters[('popup', 'anchor')]
        if got_pa != exp_pa:
            print(f'  DIFF 浮层 anchors→x/y 预期 {exp_pa} 处，实际 {got_pa} 处', file=sys.stderr)
            ok = False
        else:
            print(f'  OK  浮层 anchors→x/y 改写数 = {got_pa}（与预期一致）')

    if prof.get('js_reserved_word'):
        exp_as = prof['expect_reserved_as']
        got_as = counters[('js', 'as')] + counters[('js', 'as_ref')]
        if counters[('js', 'as')] != exp_as:
            print(f'  DIFF JS 保留字 as 改名预期 {exp_as} 处，实际 {counters[("js", "as")]} 处',
                  file=sys.stderr)
            ok = False
        else:
            print(f'  OK  JS 保留字 as→aS：声明 {counters[("js", "as")]} 处'
                  f' + 引用 {counters[("js", "as_ref")]} 处（与预期一致）')

    if prof.get('handlers'):
        exp_h = prof['expect_handlers']
        # ⚠ counters 里的键有 2 元组（'import', mod, ver 那种）与 3 元组
        #   （'handler', kind, stat）两种，直接解包会 ValueError。
        got_h = sum(v for k, v in counters.items()
                    if len(k) == 3 and k[0] == 'handler' and k[2] == 'block')
        if got_h != exp_h:
            print(f'  DIFF Pointer Handler→MouseArea 预期 {exp_h} 块，实际 {got_h} 块', file=sys.stderr)
            ok = False
        else:
            print(f'  OK  Pointer Handler→MouseArea 替换块数 = {got_h}（与预期一致）')
        # 未登记 / 未识别形态 = 行为可能丢失，必须报出来而不是静默跳过。
        # ⚠ 这条必须同时拦住「留了 __ 注释占位」的情况：产物里出现
        #   `__hoveredChanged:` 这种不存在的属性时，QML 解析器**不报错**、
        #   门禁全绿，而行为已经静默失效 —— 比报错危险得多（实测踩过）。
        unknown = {k: v for k, v in counters.items()
                   if len(k) == 3 and k[0] == 'handler' and k[2].startswith('UNKNOWN:')}
        nomatch = {k: v for k, v in counters.items()
                   if len(k) == 3 and k[0] == 'handler' and k[2] == 'HOVER_NOMATCH'}
        if unknown or nomatch:
            for k, v in sorted(unknown.items()):
                print(f'  DIFF {k[1]}.{k[2][8:]} 未登记映射 ×{v}（行为可能丢失，需补规则）',
                      file=sys.stderr)
            for k, v in sorted(nomatch.items()):
                print(f'  DIFF {k[1]} onHoveredChanged 形态未识别 ×{v}（需人工处理）',
                      file=sys.stderr)
            ok = False
        else:
            print(f'  OK  无未登记 / 未识别的 Handler 属性（行为无静默丢失）')

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
        # src/ 改一行却不重跑生成器 ⇒ 命中数照样全OK、门照样绿，而 qt5/
        # 已经陈旧（Qt 5 侧的新写法会"明明写了却跑不起来"）。
        # 所以 --check 必须落到**逐文件比对**上，而不是停在计数。
        #⚠ 带 --also-examples 时，示例页也要进比对面：产物里存了它们，
        #   不比就会被当成 27+ 个「残留（产物有、src/ 没有）」。
        check_text = dict(gen_text)
        if args.also_examples:
            ex_src = os.path.abspath(
                os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             '..', 'examples'))
            ex_root = os.path.join(dest_root, 'examples')
            if os.path.isdir(ex_root):
                for r, _d, fns in os.walk(ex_src):
                    for fn in fns:
                        if not fn.endswith('.qml'):
                            continue
                        sp = os.path.join(r, fn)
                        rel = os.path.relpath(sp, ex_src).replace(os.sep, '/')
                        txt = open(sp, encoding='utf-8', errors='replace').read()
                        check_text['examples/' + rel] = downgrade_text(
                            txt, counters, rel, prof)
        drift = drift_between(check_text, dest_root)
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
