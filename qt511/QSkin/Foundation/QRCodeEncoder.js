/****************************************************************************
 * QSkin · Quick Design System — Foundation
 * 二维码编码器（ISO/IEC 18004：2015）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 输入一段文本 + 一档纠错等级，输出**模块矩阵**（二维布尔网格）。
 * 它不画一笔 —— 画是 Contracts 层 QSkinQRCode 的事。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 为什么这是一个 `.js` 而不是一个 QML 单例
 * ════════════════════════════════════════════════════════════════════════
 * 因为门禁要**运行同一份源码**。
 *
 * 本仓对"算出来的东西要对"这件事的既有做法是像素核验（把屏幕上的墨读回来），
 * 但二维码有更强的可能：它的输出是一个**离散矩阵**，存在独立的参照实现
 * （`segno`，纯 Python，无依赖）。于是核验可以做到两件事同时成立：
 *
 *   ① 用 node 直接跑**这一个文件**，拿到矩阵；
 *   ② 拿它与参照实现的矩阵逐模块比对。
 *
 * 如果编码逻辑长在 QML 控件里，就只能通过控件属性去摸"控件认为的矩阵" ——
 * 而"控件认为的"与"算出来的"一致，什么也证明不了。住在 `.js` 之后，
 * `QSkinQRCode` 与核验器是**同一份源码的两个消费者**，不是看起来一样的
 * 两份实现（本仓在 M18 记过这条：「出现了第二份画线的代码」）。
 *
 * 所以本文件刻意**不写 `.pragma library`** —— 那条指令是 QML 专有的，
 * node 会当作语法错误。没有它，QML 只为每个引用方各建一份实例，而本文件
 * 只有纯函数与常量，多一份实例的开销可以忽略。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 容量表是怎么来的，以及它怎么被证明是对的
 * ════════════════════════════════════════════════════════════════════════
 * `ECC_TABLE` 是 ISO/IEC 18004 附录里的块结构表（40 版本 × 4 档 = 160 条），
 * 逐条手工誊写必然出错，所以它是**从参照实现导出的**，然后用一条**独立算路**
 * 证明它对：
 *
 *     对每个版本 v，从几何布局数出"自由模块数" F(v)：
 *         总模块 (4v+17)²
 *         − 三个定位图形与分隔符 3×64
 *         − 两条定时图形 2×(n−16)
 *         − 校正图形（跳过与定位图形重叠的三个角落）× 25
 *         − 格式信息两份 + 固定深色模块 31
 *         − 版本信息两份 36（仅 v ≥ 7）
 *     必须满足：  8 × Σ(块数 × 每块总码字数) = F(v) − 剩余位数(v)
 *
 * 这是一条**跨算路**的等式：左边来自表，右边来自几何。实测 160 条全部成立
 * （`.cache/_verify_m24.py` 的 [0] 组把这条等式做成了门禁）。写这条自检的
 * 过程本身就抓到了我一次错 —— 我第一版的公式是 (16v+128)v+64，它在 v1 上
 * 恰好成立（208 位），从 v2 起就系统性偏大，因为**剩余位**不是 0。
 *
 * ⚠ 但这条恒等式有一个**结构性盲区**：它是一个**计数**论证，只看"保留了多少
 * 格"，看不见"保留在哪儿"。版本信息（v ≥ 7）的保留区形状我一开始写错了
 * （rows n-11..n-6 × cols 0..2，应为 rows n-11..n-9 × cols 0..5），
 * 格数仍是 18，160 条等式照样全绿。抓到它的是**钉死版本 + 钉死掩码**的
 * 逐模块比对：v1/v2/v5 共 1440 组全 0 差异，v ≥ 7 共 1920 组全错 ——
 * 分界干净得刺眼。教训：**计数不变的错，要用位置敏感的判据去抓。**
 *
 * ════════════════════════════════════════════════════════════════════════
 * 支持范围与刻意的取舍
 * ════════════════════════════════════════════════════════════════════════
 *   · 全部 40 个版本、四档纠错（L/M/Q/H）—— 没有人为的上限。
 *   · 模式：数字 / 字母数字 / 字节（UTF-8）。**汉字模式（0xD）不做** ——
 *     它要 Shift_JIS/GB2312 编码表。**代价说清楚**：汉字模式下每个汉字
 *     13 位，走 UTF-8 字节模式是 24 位（3 字节），所以同内容**可能大一档
 *     版本**（例如 20 个纯汉字：Kanji 模式 260 位够 v3-M，字节模式
 *     480 位要 v5-M）。这是**已知且刻意**的，不是缺陷：字节模式的 UTF-8
 *     被所有现代扫码器接受，而汉字模式在非中文环境反而有兼容风险。
 *   · **单段编码**：整段文本用同一种模式。最优编码器会切成多段
 *     （"ABC123" 用两段能省几位），代价是代码量翻倍而观感一致；
 *     本仓的用途是 UI 里的短文本与短链，不值得。这条也意味着
 *     "版本可能比理论最优大一档"，同样是已知且刻意的。
 *   · **空载荷显式拒绝**（见 encode() 里的注释）。零长度载荷在三种模式下
 *     用 zxing-cpp 都读不出，参照实现编出的空串符号同样读不出 ——
 *     它是退化输入，不是编码缺陷。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 掩码：为什么"掩码号相同"不能当判据
 * ════════════════════════════════════════════════════════════════════════
 * 四条罚分规则本身是标准写死的（本文件按 §7.8.3 实现），但**评罚分时
 * 格式信息在不在场**，各家取法不同，且都能自圆其说：
 *
 *     ZXing   ：buildMatrix() 已含 embedTypeInfo/embedVersionInfo → **在场**
 *     本文件  ：_writeFormat(cand, ...) 在 _penalty(cand, ...) 之前 → 同 ZXing
 *     qrcode  ：makeImpl(test=True) 把格式位写成浅色 → **抹白**
 *     segno   ：源码注释明写 "DO NOT add format / version info in advance
 *               of evaluation" → 抹白
 *
 * 两种约定都存在，所以**自动掩码选出的掩码号与参照实现不同，不能说明
 * 谁错了**。门禁因此分两层：
 *   · 钉死掩码 + 钉死版本 → 逐模块比对（`_verify_m24.py` [1] 组，3128 组）；
 *   · 自动掩码 → 交给**独立解码器**（zxing-cpp）读回原文（[5] 组）。
 *     "能不能读懂"对任何掩码都成立，这才是该断言的东西。
 *
 * ════════════════════════════════════════════════════════════════════════
 * 与 segno 的一处已知分歧（填充位位置）—— 归因已确证
 * ════════════════════════════════════════════════════════════════════════
 * 早期比对里，`'a'`（1-L，掩码 0）与 segno 差 136 个模块。逐层切开后
 * 定位到第 3 个数据码字：本仓是 236（PAD0），segno 是 0 —— 它凭空插了
 * 一个 0x00，于是其后所有数据码字与全部纠错码字整体偏移。
 *
 * 根因在 segno/encoder.py 的 write_padding_bits：
 *     buff.extend([0] * (8 - (length % 8)))
 * 当 `length % 8 == 0`（已字节对齐）时它加 **8 位**而不是 0 位。
 * ISO/IEC 18004 §7.4.10 的原文是 "**If** the bit stream length is such
 * that it does not end at a codeword boundary, padding bits ... shall be
 * added" —— 对齐时应当是空操作；qrcode 库写的 `if delimit:` 才是对的。
 *
 * 这不是孤例：字节模式 `4 + 8 + 8n` 加 4 位终比特后**恒为 8 的倍数**，
 * 所以 segno 对**任何**字节模式内容都会多插一个字节；数字模式在
 * 9/21/33… 位数字、字母数字模式在特定长度上同样触发。
 * `_verify_m24.py` [3] 组把这条做成了可证伪判据（14 例逐例对照）。
 *
 * 结论：本仓与 **qrcode 库**一致（3128 组逐模块 0 差异），
 * 与 **zxing-cpp** 一致（往返回读全绿）。黄金向量取这两家，不取 segno。
 ****************************************************************************/


/* ═══════════════════════════ 常量 ═══════════════════════════ */

/** 四档纠错，顺序即本文件与控件对外使用的下标 */
var eccNames = ["L", "M", "Q", "H"]

/** 纠错档在格式信息里的 2 位指示符（ISO/IEC 18004 表 12） */
var ECC_INDICATOR = { L: 1, M: 0, Q: 3, H: 2 }

/** 字母数字模式的字符表（下标即码值） */
var ALNUM_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"

/** 各模式在三个版本区间里的"字符计数指示符"位宽 */
var COUNT_BITS = {
    numeric: [10, 12, 14],
    alnum:   [9, 11, 13],
    byte:    [8, 16, 16]
}

/** 模式指示符（4 位） */
var MODE_INDICATOR = { numeric: 1, alnum: 2, byte: 4 }

/** 每版本的剩余位（ISO/IEC 18004 表 1），下标 0 = 版本 1 */
var REMAINDER_BITS = [
    0, 7, 7, 7, 7, 7, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3,
    4, 4, 4, 4, 4, 4, 4, 3, 3, 3, 3, 3, 3, 3, 0, 0, 0, 0, 0, 0
]

/**
 * 块结构表。键是版本号，值是四个纠错档：
 *   [ 每块纠错码字数, [ [组1块数, 组1每块数据码字], [组2块数, 组2每块数据码字]… ], 数据码字总数 ]
 * 组2 存在时，它的每块数据码字恒为组1 的 +1（这是标准的分组方式，
 * 门禁里有一条断言守着它）。
 */
var ECC_TABLE = {
    1: { l: [7, [[1, 19]], 19], m: [10, [[1, 16]], 16], q: [13, [[1, 13]], 13], h: [17, [[1, 9]], 9] },
    2: { l: [10, [[1, 34]], 34], m: [16, [[1, 28]], 28], q: [22, [[1, 22]], 22], h: [28, [[1, 16]], 16] },
    3: { l: [15, [[1, 55]], 55], m: [26, [[1, 44]], 44], q: [18, [[2, 17]], 34], h: [22, [[2, 13]], 26] },
    4: { l: [20, [[1, 80]], 80], m: [18, [[2, 32]], 64], q: [26, [[2, 24]], 48], h: [16, [[4, 9]], 36] },
    5: { l: [26, [[1, 108]], 108], m: [24, [[2, 43]], 86], q: [18, [[2, 15], [2, 16]], 62], h: [22, [[2, 11], [2, 12]], 46] },
    6: { l: [18, [[2, 68]], 136], m: [16, [[4, 27]], 108], q: [24, [[4, 19]], 76], h: [28, [[4, 15]], 60] },
    7: { l: [20, [[2, 78]], 156], m: [18, [[4, 31]], 124], q: [18, [[2, 14], [4, 15]], 88], h: [26, [[4, 13], [1, 14]], 66] },
    8: { l: [24, [[2, 97]], 194], m: [22, [[2, 38], [2, 39]], 154], q: [22, [[4, 18], [2, 19]], 110], h: [26, [[4, 14], [2, 15]], 86] },
    9: { l: [30, [[2, 116]], 232], m: [22, [[3, 36], [2, 37]], 182], q: [20, [[4, 16], [4, 17]], 132], h: [24, [[4, 12], [4, 13]], 100] },
    10: { l: [18, [[2, 68], [2, 69]], 274], m: [26, [[4, 43], [1, 44]], 216], q: [24, [[6, 19], [2, 20]], 154], h: [28, [[6, 15], [2, 16]], 122] },
    11: { l: [20, [[4, 81]], 324], m: [30, [[1, 50], [4, 51]], 254], q: [28, [[4, 22], [4, 23]], 180], h: [24, [[3, 12], [8, 13]], 140] },
    12: { l: [24, [[2, 92], [2, 93]], 370], m: [22, [[6, 36], [2, 37]], 290], q: [26, [[4, 20], [6, 21]], 206], h: [28, [[7, 14], [4, 15]], 158] },
    13: { l: [26, [[4, 107]], 428], m: [22, [[8, 37], [1, 38]], 334], q: [24, [[8, 20], [4, 21]], 244], h: [22, [[12, 11], [4, 12]], 180] },
    14: { l: [30, [[3, 115], [1, 116]], 461], m: [24, [[4, 40], [5, 41]], 365], q: [20, [[11, 16], [5, 17]], 261], h: [24, [[11, 12], [5, 13]], 197] },
    15: { l: [22, [[5, 87], [1, 88]], 523], m: [24, [[5, 41], [5, 42]], 415], q: [30, [[5, 24], [7, 25]], 295], h: [24, [[11, 12], [7, 13]], 223] },
    16: { l: [24, [[5, 98], [1, 99]], 589], m: [28, [[7, 45], [3, 46]], 453], q: [24, [[15, 19], [2, 20]], 325], h: [30, [[3, 15], [13, 16]], 253] },
    17: { l: [28, [[1, 107], [5, 108]], 647], m: [28, [[10, 46], [1, 47]], 507], q: [28, [[1, 22], [15, 23]], 367], h: [28, [[2, 14], [17, 15]], 283] },
    18: { l: [30, [[5, 120], [1, 121]], 721], m: [26, [[9, 43], [4, 44]], 563], q: [28, [[17, 22], [1, 23]], 397], h: [28, [[2, 14], [19, 15]], 313] },
    19: { l: [28, [[3, 113], [4, 114]], 795], m: [26, [[3, 44], [11, 45]], 627], q: [26, [[17, 21], [4, 22]], 445], h: [26, [[9, 13], [16, 14]], 341] },
    20: { l: [28, [[3, 107], [5, 108]], 861], m: [26, [[3, 41], [13, 42]], 669], q: [30, [[15, 24], [5, 25]], 485], h: [28, [[15, 15], [10, 16]], 385] },
    21: { l: [28, [[4, 116], [4, 117]], 932], m: [26, [[17, 42]], 714], q: [28, [[17, 22], [6, 23]], 512], h: [30, [[19, 16], [6, 17]], 406] },
    22: { l: [28, [[2, 111], [7, 112]], 1006], m: [28, [[17, 46]], 782], q: [30, [[7, 24], [16, 25]], 568], h: [24, [[34, 13]], 442] },
    23: { l: [30, [[4, 121], [5, 122]], 1094], m: [28, [[4, 47], [14, 48]], 860], q: [30, [[11, 24], [14, 25]], 614], h: [30, [[16, 15], [14, 16]], 464] },
    24: { l: [30, [[6, 117], [4, 118]], 1174], m: [28, [[6, 45], [14, 46]], 914], q: [30, [[11, 24], [16, 25]], 664], h: [30, [[30, 16], [2, 17]], 514] },
    25: { l: [26, [[8, 106], [4, 107]], 1276], m: [28, [[8, 47], [13, 48]], 1000], q: [30, [[7, 24], [22, 25]], 718], h: [30, [[22, 15], [13, 16]], 538] },
    26: { l: [28, [[10, 114], [2, 115]], 1370], m: [28, [[19, 46], [4, 47]], 1062], q: [28, [[28, 22], [6, 23]], 754], h: [30, [[33, 16], [4, 17]], 596] },
    27: { l: [30, [[8, 122], [4, 123]], 1468], m: [28, [[22, 45], [3, 46]], 1128], q: [30, [[8, 23], [26, 24]], 808], h: [30, [[12, 15], [28, 16]], 628] },
    28: { l: [30, [[3, 117], [10, 118]], 1531], m: [28, [[3, 45], [23, 46]], 1193], q: [30, [[4, 24], [31, 25]], 871], h: [30, [[11, 15], [31, 16]], 661] },
    29: { l: [30, [[7, 116], [7, 117]], 1631], m: [28, [[21, 45], [7, 46]], 1267], q: [30, [[1, 23], [37, 24]], 911], h: [30, [[19, 15], [26, 16]], 701] },
    30: { l: [30, [[5, 115], [10, 116]], 1735], m: [28, [[19, 47], [10, 48]], 1373], q: [30, [[15, 24], [25, 25]], 985], h: [30, [[23, 15], [25, 16]], 745] },
    31: { l: [30, [[13, 115], [3, 116]], 1843], m: [28, [[2, 46], [29, 47]], 1455], q: [30, [[42, 24], [1, 25]], 1033], h: [30, [[23, 15], [28, 16]], 793] },
    32: { l: [30, [[17, 115]], 1955], m: [28, [[10, 46], [23, 47]], 1541], q: [30, [[10, 24], [35, 25]], 1115], h: [30, [[19, 15], [35, 16]], 845] },
    33: { l: [30, [[17, 115], [1, 116]], 2071], m: [28, [[14, 46], [21, 47]], 1631], q: [30, [[29, 24], [19, 25]], 1171], h: [30, [[11, 15], [46, 16]], 901] },
    34: { l: [30, [[13, 115], [6, 116]], 2191], m: [28, [[14, 46], [23, 47]], 1725], q: [30, [[44, 24], [7, 25]], 1231], h: [30, [[59, 16], [1, 17]], 961] },
    35: { l: [30, [[12, 121], [7, 122]], 2306], m: [28, [[12, 47], [26, 48]], 1812], q: [30, [[39, 24], [14, 25]], 1286], h: [30, [[22, 15], [41, 16]], 986] },
    36: { l: [30, [[6, 121], [14, 122]], 2434], m: [28, [[6, 47], [34, 48]], 1914], q: [30, [[46, 24], [10, 25]], 1354], h: [30, [[2, 15], [64, 16]], 1054] },
    37: { l: [30, [[17, 122], [4, 123]], 2566], m: [28, [[29, 46], [14, 47]], 1992], q: [30, [[49, 24], [10, 25]], 1426], h: [30, [[24, 15], [46, 16]], 1096] },
    38: { l: [30, [[4, 122], [18, 123]], 2702], m: [28, [[13, 46], [32, 47]], 2102], q: [30, [[48, 24], [14, 25]], 1502], h: [30, [[42, 15], [32, 16]], 1142] },
    39: { l: [30, [[20, 117], [4, 118]], 2812], m: [28, [[40, 47], [7, 48]], 2216], q: [30, [[43, 24], [22, 25]], 1582], h: [30, [[10, 15], [67, 16]], 1222] },
    40: { l: [30, [[19, 118], [6, 119]], 2956], m: [28, [[18, 47], [31, 48]], 2334], q: [30, [[34, 24], [34, 25]], 1666], h: [30, [[20, 15], [61, 16]], 1276] }
}

/** 校正图形中心的坐标（ISO/IEC 18004 附录 E），下标 0 = 版本 2 */
var ALIGN_TABLE = [
    [6, 18],
    [6, 22],
    [6, 26],
    [6, 30],
    [6, 34],
    [6, 22, 38],
    [6, 24, 42],
    [6, 26, 46],
    [6, 28, 50],
    [6, 30, 54],
    [6, 32, 58],
    [6, 34, 62],
    [6, 26, 46, 66],
    [6, 26, 48, 70],
    [6, 26, 50, 74],
    [6, 30, 54, 78],
    [6, 30, 56, 82],
    [6, 30, 58, 86],
    [6, 34, 62, 90],
    [6, 28, 50, 72, 94],
    [6, 26, 50, 74, 98],
    [6, 30, 54, 78, 102],
    [6, 28, 54, 80, 106],
    [6, 32, 58, 84, 110],
    [6, 30, 58, 86, 114],
    [6, 34, 62, 90, 118],
    [6, 26, 50, 74, 98, 122],
    [6, 30, 54, 78, 102, 126],
    [6, 26, 52, 78, 104, 130],
    [6, 30, 56, 82, 108, 134],
    [6, 34, 60, 86, 112, 138],
    [6, 30, 58, 86, 114, 142],
    [6, 34, 62, 90, 118, 146],
    [6, 30, 54, 78, 102, 126, 150],
    [6, 24, 50, 76, 102, 128, 154],
    [6, 28, 54, 80, 106, 132, 158],
    [6, 32, 58, 84, 110, 136, 162],
    [6, 26, 54, 82, 110, 138, 166],
    [6, 30, 58, 86, 114, 142, 170]
]


/* ═══════════════════════ 有限域 GF(256) ═══════════════════════ */

/* 本原多项式 0x11D（x⁸+x⁴+x³+x²+1），与二维码标准一致。
 * 表是懒初始化的：只有真的编码时才付这份代价。 */
var _gfExp = null
var _gfLog = null

function _gfInit() {
    if (_gfExp !== null) return
    var exp = new Array(512)
    var log = new Array(256)
    var x = 1
    for (var i = 0; i < 255; ++i) {
        exp[i] = x
        log[x] = i
        x <<= 1
        if (x & 0x100) x ^= 0x11D
    }
    for (var j = 255; j < 512; ++j) exp[j] = exp[j - 255]
    log[0] = 0        // 未定义；乘法里被 a===0||b===0 提前拦掉
    _gfExp = exp
    _gfLog = log
}

function _gfMul(a, b) {
    if (a === 0 || b === 0) return 0
    return _gfExp[_gfLog[a] + _gfLog[b]]
}

/**
 * 生成多项式 g(x) = Π (x − α^i)，i = 0..ecLen-1。
 * 返回 ecLen+1 个系数，**最高次在前**（g[0] 恒为 1）。
 */
function _rsGenPoly(ecLen) {
    _gfInit()
    var g = [1]
    for (var i = 0; i < ecLen; ++i) {
        var ng = new Array(g.length + 1)
        for (var k = 0; k < ng.length; ++k) ng[k] = 0
        for (var j = 0; j < g.length; ++j) {
            ng[j]     ^= g[j]                              // × x
            ng[j + 1] ^= _gfMul(g[j], _gfExp[i])           // × α^i
        }
        g = ng
    }
    return g
}

/**
 * 对 data（码字数组）取 ecLen 个纠错码字。
 * 用综合除法：把 data 当作多项式高位在前，取 x^ecLen 除后的余式。
 */
function _rsEncode(data, ecLen) {
    var gen = _rsGenPoly(ecLen)
    var res = new Array(ecLen)
    for (var i = 0; i < ecLen; ++i) res[i] = 0
    for (var d = 0; d < data.length; ++d) {
        var factor = data[d] ^ res[0]
        for (var k = 0; k < ecLen - 1; ++k) res[k] = res[k + 1]
        res[ecLen - 1] = 0
        if (factor !== 0) {
            for (var m = 0; m < ecLen; ++m) res[m] ^= _gfMul(gen[m + 1], factor)
        }
    }
    return res
}


/* ═══════════════════════ 内容归一 ═══════════════════════ */

/** 字符串 → UTF-8 字节数组（自己写，QML 里没有 TextEncoder） */
function utf8Bytes(str) {
    var out = []
    for (var i = 0; i < str.length; ++i) {
        var c = str.charCodeAt(i)
        /* 代理对合成一个码位 —— 缺了这一步，emoji 会被拆成两个
         * 非法字节序列（每个代理项单独编码）。 */
        if (c >= 0xD800 && c <= 0xDBFF && i + 1 < str.length) {
            var lo = str.charCodeAt(i + 1)
            if (lo >= 0xDC00 && lo <= 0xDFFF) {
                c = 0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00)
                ++i
            }
        }
        if (c < 0x80) {
            out.push(c)
        } else if (c < 0x800) {
            out.push(0xC0 | (c >> 6)); out.push(0x80 | (c & 0x3F))
        } else if (c < 0x10000) {
            out.push(0xE0 | (c >> 12))
            out.push(0x80 | ((c >> 6) & 0x3F)); out.push(0x80 | (c & 0x3F))
        } else {
            out.push(0xF0 | (c >> 18)); out.push(0x80 | ((c >> 12) & 0x3F))
            out.push(0x80 | ((c >> 6) & 0x3F)); out.push(0x80 | (c & 0x3F))
        }
    }
    return out
}

/** 选出模式：全数字 → numeric；全字母数字表内 → alnum；否则 byte */
function pickMode(text) {
    if (text.length === 0) return "byte"
    var digits = true
    var alnum = true
    for (var i = 0; i < text.length; ++i) {
        var ch = text.charAt(i)
        if (ch < "0" || ch > "9") digits = false
        if (ALNUM_CHARS.indexOf(ch) < 0) alnum = false
        if (!digits && !alnum) break
    }
    if (digits) return "numeric"
    if (alnum) return "alnum"
    return "byte"
}

/** 载荷代号：numeric 用字符个数，其余用字节个数 */
function payloadUnits(text, mode) {
    if (mode === "byte") return utf8Bytes(text)
    var units = []
    for (var i = 0; i < text.length; ++i) units.push(text.charAt(i))
    return units
}

function countBitsFor(mode, version) {
    var g = version <= 9 ? 0 : (version <= 26 ? 1 : 2)
    return COUNT_BITS[mode][g]
}

/** 载荷占多少位（不含模式与计数指示符） */
function payloadBitsFor(mode, n) {
    if (mode === "numeric") return 10 * Math.floor(n / 3) + [0, 4, 7][n % 3]
    if (mode === "alnum")   return 11 * Math.floor(n / 2) + 6 * (n % 2)
    return 8 * n
}

/** 某版本某档能装多少数据位 */
function dataCapacityBits(version, eccName) {
    return ECC_TABLE[version][eccName.toLowerCase()][2] * 8
}


/* ═══════════════════════ 位流 ═══════════════════════ */

function _putBits(bits, value, nbits) {
    for (var i = nbits - 1; i >= 0; --i) bits.push((value >> i) & 1)
}

function _bitsToBytes(bits) {
    var out = []
    for (var i = 0; i < bits.length; i += 8) {
        var b = 0
        for (var j = 0; j < 8; ++j) b = (b << 1) | (bits[i + j] || 0)
        out.push(b)
    }
    return out
}

/**
 * 按选定模式把 units 编成位流，并补齐到 dataCodewords 个码字。
 * 补齐三步（标准 8.4.9）：终止符 → 补到字节边界 → 交替填 0xEC / 0x11。
 */
function _buildCodewords(units, mode, version, dataCodewords) {
    var bits = []
    _putBits(bits, MODE_INDICATOR[mode], 4)
    _putBits(bits, units.length, countBitsFor(mode, version))

    if (mode === "numeric") {
        var i = 0
        for (; i + 3 <= units.length; i += 3) {
            _putBits(bits, parseInt(units.slice(i, i + 3).join(""), 10), 10)
        }
        var rest = units.length - i
        if (rest === 2)      _putBits(bits, parseInt(units.slice(i).join(""), 10), 7)
        else if (rest === 1) _putBits(bits, parseInt(units.slice(i).join(""), 10), 4)
    } else if (mode === "alnum") {
        var k = 0
        for (; k + 2 <= units.length; k += 2) {
            var v = ALNUM_CHARS.indexOf(units[k]) * 45
                  + ALNUM_CHARS.indexOf(units[k + 1])
            _putBits(bits, v, 11)
        }
        if (units.length - k === 1) {
            _putBits(bits, ALNUM_CHARS.indexOf(units[k]), 6)
        }
    } else {
        for (var b = 0; b < units.length; ++b) _putBits(bits, units[b], 8)
    }

    var capacity = dataCodewords * 8
    var term = Math.min(4, capacity - bits.length)
    for (var t = 0; t < term; ++t) bits.push(0)
    while (bits.length % 8 !== 0) bits.push(0)

    var cw = _bitsToBytes(bits)
    var pad = [0xEC, 0x11]
    var p = 0
    while (cw.length < dataCodewords) {
        cw.push(pad[p % 2])
        ++p
    }
    return cw
}

/* ═══════════════════════ 格式与版本信息 ═══════════════════════ */

/** 格式信息的 BCH(15,5)，生成多项式 0x537，最后与掩码 0x5412 异或 */
function formatBits(eccName, mask) {
    var data = (ECC_INDICATOR[eccName] << 3) | mask
    var d = data << 10
    var g = 0x537
    for (var i = 14; i >= 10; --i) {
        if ((d >> i) & 1) d ^= g << (i - 10)
    }
    return ((data << 10) | d) ^ 0x5412
}

/** 版本信息的 BCH(18,6)，生成多项式 0x1F25（仅 v ≥ 7） */
function versionBits(version) {
    var d = version << 12
    var g = 0x1F25
    for (var i = 17; i >= 12; --i) {
        if ((d >> i) & 1) d ^= g << (i - 12)
    }
    return (version << 12) | d
}


/* ═══════════════════════ 矩阵 ═══════════════════════ */

/** 校正图形中心坐标；v ≥ 2 */
function alignmentCenters(version) {
    if (version < 2) return []
    return ALIGN_TABLE[version - 2]
}

/**
 * 落函数图形，并返回 { mod, fn }：
 *   mod  模块颜色（true = 深）
 *   fn   该模块是否属于函数图形（数据不落在这里）
 */
function _functionPatterns(version) {
    var n = 4 * version + 17
    var mod = []
    var fn = []
    for (var r = 0; r < n; ++r) {
        mod.push(new Array(n))
        fn.push(new Array(n))
        for (var c = 0; c < n; ++c) { mod[r][c] = false; fn[r][c] = false }
    }

    function mark(r0, c0, h, w, dark) {
        for (var r = r0; r < r0 + h; ++r) {
            for (var c = c0; c < c0 + w; ++c) {
                if (r < 0 || r >= n || c < 0 || c >= n) continue
                fn[r][c] = true
                if (dark) mod[r][c] = true
            }
        }
    }

    /* 定位图形：7×7 同心方 + 分隔符。
     *
     * ⚠ 三个角的分隔符位置**不一样**，首版我按"分隔符总在右下"写，
     * 于是右上角少画了左侧那一列、左下角少画了上侧那一行 ——
     * 那 16 个模块被当成了数据位。后果不是"扫不出来"（扫不出来反而好办），
     * 而是**扫出来是错的**：函数图形的位置在解码端是固定的，
     * 编码端挪一格，读到的就是另一串码字。
     *
     *   左上：定位方在块内的左上角，分隔符在右、下
     *   右上：分隔符在**左**、下   → 定位方右移一格
     *   左下：分隔符在**上**、右   → 定位方下移一格
     */
    var blocks = [
        [0,     0,     0, 0],
        [0,     n - 8, 0, 1],
        [n - 8, 0,     1, 0]
    ]
    for (var k = 0; k < blocks.length; ++k) {
        var br = blocks[k][0]
        var bc = blocks[k][1]
        var dr = blocks[k][2]
        var dc = blocks[k][3]
        mark(br, bc, 8, 8, false)                // 整块：含分隔符
        for (var y = 0; y < 7; ++y) {
            for (var x = 0; x < 7; ++x) {
                var edge = (y === 0 || y === 6 || x === 0 || x === 6)
                var core = (y >= 2 && y <= 4 && x >= 2 && x <= 4)
                mod[br + dr + y][bc + dc + x] = edge || core
            }
        }
    }

    /* 定时图形：第 6 行 / 第 6 列，深浅交替 */
    for (var i = 8; i < n - 8; ++i) {
        fn[6][i] = true; mod[6][i] = (i % 2 === 0)
        fn[i][6] = true; mod[i][6] = (i % 2 === 0)
    }

    /* 校正图形：5×5，中心一圈深、内圈浅、正中一点深 */
    var centers = alignmentCenters(version)
    for (var a = 0; a < centers.length; ++a) {
        for (var b = 0; b < centers.length; ++b) {
            var cr = centers[a]
            var cc = centers[b]
            if ((cr === 6 && cc === 6)
                    || (cr === 6 && cc === n - 7)
                    || (cr === n - 7 && cc === 6)) continue
            for (var y = -2; y <= 2; ++y) {
                for (var x = -2; x <= 2; ++x) {
                    var ring = (Math.abs(y) === 2 || Math.abs(x) === 2)
                    var center = (y === 0 && x === 0)
                    fn[cr + y][cc + x] = true
                    mod[cr + y][cc + x] = ring || center
                }
            }
        }
    }

    /* 格式信息占位（先全浅，稍后按掩码写实），含固定深色模块 */
    for (var f = 0; f < 9; ++f) {
        fn[8][f] = true
        fn[f][8] = true
    }
    for (var e = 0; e < 8; ++e) {
        fn[8][n - 1 - e] = true
        fn[n - 1 - e][8] = true
    }
    mod[n - 8][8] = true

    /* 版本信息（v ≥ 7）：两块 18 位 = 3×6 与 6×3。
     *
     * ⚠ 两块的方向**不一样**，这一点是**实测回来的**，不是读标准读来的：
     * 在 v = 7..40 共 34 个版本上，对每个格子求
     *     S(r,c) = ∩_v { i : bit_i(versionBits(v)) == matrix_v[r][c] }
     * 只有真正的版本信息格会收缩到 |S| == 1（数据格随内容变→空集；
     * 定位图形跨版本恒定→留下多个候选）。实测 36/36 全部唯一钉死：
     *
     *     右上块 rows 0..5 × cols n-11..n-9 ：(r, n-11+c) → b(3r+c)  行优先
     *     左下块 rows n-11..n-9 × cols 0..5 ：(n-11+c, r) → b(3r+c)  列优先
     *
     * 首版左下块写成了 (n-11+r, c) —— 行列互换，落在 rows n-11..n-6 ×
     * cols 0..2，越界进数据区 9 格。**这个错躲过了 160 条容量恒等式**，
     * 因为保留的总格数没变（仍 18），自由模块数 F(v) 不变：容量自检是
     * 一个**计数论证**，对"保留格的位置置换"天然失明。抓到它的是
     * 钉死版本 + 钉死掩码的逐模块比对（v1/v2/v5 全 0 差异，v ≥ 7 全错，
     * 1440 : 1920 的分界干净得刺眼）。 */
    if (version >= 7) {
        for (var vc = 0; vc < 3; ++vc) {
            for (var vr = 0; vr < 6; ++vr) {
                fn[vr][n - 11 + vc] = true
                fn[n - 11 + vc][vr] = true
            }
        }
    }
    return { mod: mod, fn: fn, size: n }
}

/** 把最终码字按之字形填进非函数模块；剩余位留浅色 */
function _placeData(base, bytes) {
    var n = base.size
    var bits = []
    for (var b = 0; b < bytes.length; ++b) _putBits(bits, bytes[b], 8)

    var idx = 0
    var col = n - 1
    var upward = true
    while (col > 0) {
        if (col === 6) --col                 // 让开竖向定时图形那一列
        for (var k = 0; k < n; ++k) {
            var row = upward ? (n - 1 - k) : k
            for (var side = 0; side < 2; ++side) {
                var cc = col - side
                if (base.fn[row][cc]) continue
                base.mod[row][cc] = (idx < bits.length) ? (bits[idx] === 1) : false
                ++idx
            }
        }
        col -= 2
        upward = !upward
    }
    return idx
}

/** 掩码条件（标准表 10）。返回 true 表示要翻转该模块。 */
function maskAt(maskId, r, c) {
    switch (maskId) {
    case 0: return (r + c) % 2 === 0
    case 1: return r % 2 === 0
    case 2: return c % 3 === 0
    case 3: return (r + c) % 3 === 0
    case 4: return (Math.floor(r / 2) + Math.floor(c / 3)) % 2 === 0
    case 5: return (r * c) % 2 + (r * c) % 3 === 0
    case 6: return ((r * c) % 2 + (r * c) % 3) % 2 === 0
    case 7: return ((r + c) % 2 + (r * c) % 3) % 2 === 0
    }
    return false
}

/**
 * 把格式信息写进两处。
 *
 * ⚠ 这一段的**位序是实测回来的**，不是推导出来的。
 * 首版我把方向写反了（bit0 放在 (8,0)、bit14 放在 (0,8)），于是
 * 32 个模块里恰好有一半对不上，而"能扫"这件事完全不受影响 ——
 * 因为解码器读的是同一张错位表。发现它的唯一途径是与参照实现逐模块比对。
 *
 * 实测得到的对应（`ecc=M, mask=0`，格式信息 = 0x5412）：
 *   第一份绕左上角定位图形走一个 L 形 ——
 *     bit0..5  → (0,8)…(5,8)      bit6 → (7,8)     bit7 → (8,8)
 *     bit8     → (8,7)            bit9..14 → (8,5)…(8,0)
 *   第二份 ——
 *     bit0..7  → (8,n-1)…(8,n-8)  bit8..14 → (n-7,8)…(n-1,8)
 * 两处都跳过定时图形所在的 (6,8) / (8,6)，最后补上固定深色模块 (n-8,8)。
 */
function _writeFormat(mod, n, eccName, mask) {
    var fb = formatBits(eccName, mask)
    function bit(j) { return ((fb >> j) & 1) === 1 }

    for (var j = 0; j <= 5; ++j) mod[j][8] = bit(j)
    mod[7][8] = bit(6)
    mod[8][8] = bit(7)
    mod[8][7] = bit(8)
    for (var k = 9; k <= 14; ++k) mod[8][14 - k] = bit(k)

    for (var m = 0; m <= 7; ++m) mod[8][n - 1 - m] = bit(m)
    for (var v = 8; v <= 14; ++v) mod[n - 15 + v][8] = bit(v)

    mod[n - 8][8] = true                     // 固定深色模块
}

function _writeVersion(mod, n, version) {
    if (version < 7) return
    var vb = versionBits(version)
    for (var i = 0; i < 18; ++i) {
        var bit = ((vb >> i) & 1) === 1
        var r = Math.floor(i / 3)
        var c = i % 3
        mod[r][n - 11 + c] = bit       /* 右上：行优先，(r, n-11+c) */
        mod[n - 11 + c][r] = bit       /* 左下：列优先，(n-11+c, r) —— 行列互换 */
    }
}

/* ── 四条罚分规则（标准 8.8.2）── */

/** 规则 1：同色连续 ≥ 5 的行程，罚 3 + (长度 − 5) */
function _penaltyRuns(mod, n) {
    var score = 0
    for (var pass = 0; pass < 2; ++pass) {
        for (var i = 0; i < n; ++i) {
            var run = 1
            var prev = pass === 0 ? mod[i][0] : mod[0][i]
            for (var j = 1; j < n; ++j) {
                var cur = pass === 0 ? mod[i][j] : mod[j][i]
                if (cur === prev) {
                    ++run
                } else {
                    if (run >= 5) score += 3 + (run - 5)
                    run = 1
                    prev = cur
                }
            }
            if (run >= 5) score += 3 + (run - 5)
        }
    }
    return score
}

/** 规则 2：2×2 同色方块，每个罚 3 */
function _penaltyBlocks(mod, n) {
    var score = 0
    for (var r = 0; r < n - 1; ++r) {
        for (var c = 0; c < n - 1; ++c) {
            var v = mod[r][c]
            if (mod[r][c + 1] === v && mod[r + 1][c] === v && mod[r + 1][c + 1] === v)
                score += 3
        }
    }
    return score
}

/** 规则 3：1:1:3:1:1 的定位图形模样（两侧留 4 浅），每处罚 40 */
function _penaltyFinderLike(mod, n) {
    var a = [true, false, true, true, true, false, true, false, false, false, false]
    var b = [false, false, false, false, true, false, true, true, true, false, true]
    var score = 0
    for (var pass = 0; pass < 2; ++pass) {
        for (var i = 0; i < n; ++i) {
            for (var j = 0; j + 11 <= n; ++j) {
                var hitA = true
                var hitB = true
                for (var k = 0; k < 11; ++k) {
                    var v = pass === 0 ? mod[i][j + k] : mod[j + k][i]
                    if (v !== a[k]) hitA = false
                    if (v !== b[k]) hitB = false
                }
                if (hitA) ++score
                if (hitB) ++score
            }
        }
    }
    return score * 40
}

/** 规则 4：深色占比每偏离 50% 达 5%，罚 10 */
function _penaltyBalance(mod, n) {
    var dark = 0
    for (var r = 0; r < n; ++r)
        for (var c = 0; c < n; ++c)
            if (mod[r][c]) ++dark
    var pct = dark * 100 / (n * n)
    return 10 * Math.floor(Math.abs(pct - 50) / 5)
}

function _penalty(mod, n) {
    return _penaltyRuns(mod, n) + _penaltyBlocks(mod, n)
           + _penaltyFinderLike(mod, n) + _penaltyBalance(mod, n)
}


/* ═══════════════════════ 主入口 ═══════════════════════ */

/**
 * encode(text, eccName, opts) → 结果对象
 *
 * eccName：'L' | 'M' | 'Q' | 'H'（大小写不敏感，默认 'M'）
 * opts.version：指定版本（1..40）。给了就用它，装不下则报错 ——
 *               这是给"我要这一版"的场景留的口子，正常用法不给。
 *
 * 返回：
 *   { ok, text, mode, version, ecc, mask, size, modules, dataCodewords }
 *
 *   失败时 { ok: false, code, error, params? }，modules 为空数组。
 *
 *   `code` 是**契约**（算路层唯一的失败标识，ASCII）：
 *       "EMPTY" | "VERSION_OUT_OF_RANGE" | "NOT_FIT" | "TOO_LONG"
 *   `params` 只在需要参数的码上出现：
 *       NOT_FIT                → { version, ecc, need, cap }
 *       TOO_LONG               → { ecc, need, max }
 *       VERSION_OUT_OF_RANGE   → { version }
 *   `error` 是 **ASCII 诊断串**，给 node / 日志看 —— 这一层**不产用户文案**：
 *   它要在 node 下裸跑（与三条独立算路对拍），拿不到 QML 的翻译域。
 *   用户可见的那句话由 `QSkinQRCode` 按 `code` + `params` 翻译（M33-5）。
 *
 * 失败**不是**静默降级：调用方拿到 ok:false 必须自己决定显示什么
 * （QSkinQRCode 的做法是显示一段占位文字，而不是画一张扫不出来的码）。
 */
function encode(text, eccName, opts) {
    var options = opts || {}
    var ecc = (eccName || "M").toUpperCase()
    if (eccNames.indexOf(ecc) < 0) ecc = "M"
    var body = (text === null || text === undefined) ? "" : String(text)

    /* 空载荷：显式拒绝，而不是产出一个"结构合法但谁都读不懂"的符号。
     * 这是**实测**出来的，不是想当然：零长度载荷在 numeric / alnum / byte
     * 三种模式下，用 zxing-cpp 3.1.1 都读不出（参照实现 qrcode 库编出的
     * 空串符号同样读不出）。所以它不是本仓的编码缺陷，而是退化输入。
     * 产品侧的正确行为由 QSkinQRCode 承担：空值显示占位符，不画码。 */
    if (body.length === 0)
        return { ok: false, code: "EMPTY",
                 error: "empty payload: nothing to encode",
                 modules: [] }

    var mode = pickMode(body)
    var units = payloadUnits(body, mode)

    /* 选版本：能装下该模式的最小版本。计数指示符的位宽随版本区间变，
     * 所以必须逐个版本试，不能一次算完。 */
    var version = 0
    var dataCwTarget = 0
    if (options.version) {
        version = options.version
        if (version < 1 || version > 40)
            return { ok: false, code: "VERSION_OUT_OF_RANGE",
                     error: "version " + options.version + " is not in 1..40",
                     params: { version: options.version },
                     modules: [] }
    }
    for (var v = (options.version || 1); v <= 40; ++v) {
        var cap = dataCapacityBits(v, ecc)
        var need = 4 + countBitsFor(mode, v) + payloadBitsFor(mode, units.length)
        if (need <= cap) {
            if (!options.version) version = v
            dataCwTarget = ECC_TABLE[version][ecc.toLowerCase()][2]
            break
        }
        if (options.version) {
            return { ok: false, code: "NOT_FIT",
                     error: "payload needs " + need + " bits; version " + options.version
                            + " / " + ecc + " holds " + cap,
                     params: { version: options.version, ecc: ecc, need: need, cap: cap },
                     modules: [] }
        }
    }
    if (version === 0) {
        var maxCap = dataCapacityBits(40, ecc)
        var needMax = 4 + payloadBitsFor(mode, units.length)
        return { ok: false, code: "TOO_LONG",
                 error: "payload needs " + needMax + " bits; version 40 / " + ecc
                        + " holds at most " + maxCap,
                 params: { ecc: ecc, need: needMax, max: maxCap },
                 modules: [] }
    }

    var codewords = _buildCodewords(units, mode, version, dataCwTarget)
    var row = ECC_TABLE[version][ecc.toLowerCase()]
    var ecLen = row[0]
    var groups = row[1]

    /* 分块 → 各自纠错 → 交织 */
    var dataBlocks = []
    var ecBlocks = []
    var at = 0
    for (var gi = 0; gi < groups.length; ++gi) {
        for (var bi = 0; bi < groups[gi][0]; ++bi) {
            var per = groups[gi][1]
            var blk = codewords.slice(at, at + per)
            at += per
            dataBlocks.push(blk)
            ecBlocks.push(_rsEncode(blk, ecLen))
        }
    }
    var stream = []
    var maxData = dataBlocks[0].length
    for (var di = 1; di < dataBlocks.length; ++di)
        if (dataBlocks[di].length > maxData) maxData = dataBlocks[di].length
    for (var ci = 0; ci < maxData; ++ci) {
        for (var si = 0; si < dataBlocks.length; ++si) {
            if (ci < dataBlocks[si].length) stream.push(dataBlocks[si][ci])
        }
    }
    for (var ei = 0; ei < ecLen; ++ei) {
        for (var eb = 0; eb < ecBlocks.length; ++eb) stream.push(ecBlocks[eb][ei])
    }

    /* 落函数图形 → 填数据 → 写版本信息（版本信息也是函数图形，
     * 且不参与掩码，所以必须在掩码循环**之前**写） */
    var base = _functionPatterns(version)
    var n = base.size
    _placeData(base, stream)
    _writeVersion(base.mod, n, version)

    /* 掩码：默认按四条罚分规则自动选；options.mask 给了就钉死它。
     * 钉死这个口子是**为了可被验证** —— 校验时要把编码器和参照实现的
     * 掩码都钉在同一档上，才能把"数据流对不对"与"掩码选得对不对"
     * 这两件事分开看。两者混在一起时，一个掩码选错会把 82 个模块的
     * 差异全盖在"数据流错了"的名下。 */
    var maskToTry = (typeof options.mask === "number") ? [options.mask] : [0, 1, 2, 3, 4, 5, 6, 7]

    var bestMask = -1
    var bestScore = -1
    var bestMod = null
    for (var mi = 0; mi < maskToTry.length; ++mi) {
        var mask = maskToTry[mi]
        var cand = []
        for (var r = 0; r < n; ++r) cand.push(base.mod[r].slice(0))
        for (var rr = 0; rr < n; ++rr) {
            for (var cc = 0; cc < n; ++cc) {
                if (base.fn[rr][cc]) continue
                if (maskAt(mask, rr, cc)) cand[rr][cc] = !cand[rr][cc]
            }
        }
        _writeFormat(cand, n, ecc, mask)
        var score = _penalty(cand, n)
        if (bestScore < 0 || score < bestScore) {
            bestScore = score
            bestMask = mask
            bestMod = cand
        }
    }

    return {
        ok: true,
        text: body,
        mode: mode,
        version: version,
        ecc: ecc,
        mask: bestMask,
        size: n,
        modules: bestMod,
        dataCodewords: dataCwTarget,
        /* 交织后的最终码字序列（数据在前、纠错在后）。
         * 它不是渲染需要的量，但它是**中间层**：与参照实现比对时，
         * 矩阵不一致有两种可能（码字流错 / 落位错），留着这一项就能
         * 一刀切开。诊断口开在这里的成本几乎为零。 */
        codewords: stream,
        penalty: bestScore
    }
}


/* ═══════════════════════ 诊断 ═══════════════════════ */

/** 矩阵 → 便于粘贴/比对的字符串（1 行 1 行，'#' 深 '.' 浅） */
function matrixToText(mod) {
    var lines = []
    for (var r = 0; r < mod.length; ++r) {
        var s = ""
        for (var c = 0; c < mod[r].length; ++c) s += mod[r][c] ? "#" : "."
        lines.push(s)
    }
    return lines.join("\n")
}

/* node 可直接 require 本文件（QML 侧看不到 module，用 typeof 保护） */
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        encode: encode,
        matrixToText: matrixToText,
        pickMode: pickMode,
        utf8Bytes: utf8Bytes,
        formatBits: formatBits,
        versionBits: versionBits,
        ECC_TABLE: ECC_TABLE,
        ALIGN_TABLE: ALIGN_TABLE,
        REMAINDER_BITS: REMAINDER_BITS,
        eccNames: eccNames
    }
}
