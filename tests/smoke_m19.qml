/****************************************************************************
 * QSkin · 冒烟测试 — M19：数据展示类（List / Avatar / AvatarGroup / Empty /
 *                            Skeleton / Spin）
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 守六个控件的**派生与账目**契约。渲染侧不在这个文件里 —— 它守不了。
 *
 * ── 这一批的属性侧风险与 M18 不同 ───────────────────────────────────────
 * M18 的风险是"几何算错 1px"（账目对不上）。这一批的风险是
 * **"派生量算对了，但算的是一件不相干的事"** —— 三个真实例子：
 *
 *   ① `count` 从 `model.length` 推。model 是数字时 `.length` 是 undefined，
 *      于是 `model: 5` 的列表算成 0 条 → 直接显示空态，而属性侧一切自洽。
 *   ② `showImage` 写成"有 src 就显示"。图片加载失败时 Image 什么都画不出，
 *      但上层那个布尔仍是 true → 图标/文字被一个透明的空图挡掉，
 *      既看不见图也看不见文字。
 *   ③ 叠放头像的 `step` 写成 `px - overlap` 而 `overlap` 忘了夹取，
 *      `overlapRatio: 2` 时 step 变负 → 后一个头像跑到前一个左边，
 *      顺序整个反过来，而每个属性单看都"没错"。
 *
 * 所以下面的断言都写成**恒等式或区间**，而不是"大概是多少"：
 * 一侧改了就必然红，红的时候能直接看出是哪一项。
 *
 * ── 断言上限 8 条（位掩码退出码的数学约束）─────────────────────────────
 * 详见 tools/test.sh 文件头。这个文件 6 个控件正好用满 8 条，
 * 合并规则是**按组件**：[1] 把 List 的"四态互斥"与"多列关分割线"
 * 并在一起（都是"列表当前处于哪一档形态"），[5] 把 Skeleton 的
 * 落位表 / 延迟机 / 内容保活并在一起（都是"骨架与内容谁在场"）。
 ****************************************************************************/

import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int mask: 0
    property int idx: 0

    function expect(cond) {
        if (!cond) root.mask |= (1 << root.idx)
        root.idx++
    }

    /* ══════════════════ 被测控件 ══════════════════
     *
     * 全部套一个固定尺寸的宿主？—— 不。这批控件的被测项几乎全是
     * **自身派生量**（count / cornerRadius / step / _k / 落位 …），
     * 与父容器无关。唯一依赖父项的是 [7] 的父色继承，那里单独安排了
     * 宿主（hostTint）。

     不过 QSkinList 的 `width` 还是要给：它的空态把 `textMaxWidth` 绑在
     **自己加载后的宽度**上（`emptyBox.width - padding*2`，见 QSkinList 空态段），
     width 为 0 时算出来是 0，量出来的数不好归因。 */

    /* ── List：model 的四种形态 ──
     * 数字 / JS 数组 / ListModel / 空。
     * 第四种（QAbstractItemModel）在 QML 里造不出来（它来自 C++），
     * 这里**不假装测过**，靠 _count() 的注释与代码评审守。 */
    QSkinList { id: listNumber; width: 300; model: 5 }
    QSkinList { id: listArray;  width: 300; model: ["甲", "乙", "丙"]
              delegate: rowDelegate }
    QSkinList { id: listZero;   width: 300; model: 0 }

    ListModel {
        id: lm4
        ListElement { label: "一" }
        ListElement { label: "二" }
        ListElement { label: "三" }
        ListElement { label: "四" }
    }

    QSkinList { id: listLm; width: 300; model: lm4 }

    /* 故意声明 modelData / index —— QSkinList 的行壳会无条件往 delegate 上写
     * 这两个属性（走 Loader.onLoaded）。不声明的话每次加载都会打一条
     * "Cannot assign to non-existent property" 的运行期警告，
     * 而**警告不会让测试变红**（这正是"属性值对 ≠ 界面画对"的同一类陷阱）。 */
    Component {
        id: rowDelegate

        Item {
            id: cell

            property var modelData
            property int index

            implicitHeight: 20
        }
    }

    /* ── List：四态 ── */
    QSkinList { id: listEmptyState; width: 300; model: 0 }
    QSkinList { id: listLoading;    width: 300; model: 5;  loading: true }
    QSkinList { id: listMore;       width: 300; model: 5;  loadMore: true }
    QSkinList { id: listNoMore;     width: 300; model: 0;  noMore: true }

    /* ── List：split 与 columns ── */
    QSkinList { id: listSplitOn;    width: 300; model: 3 }
    QSkinList { id: listSplitMulti; width: 300; model: 3; columns: 2 }
    QSkinList { id: listSplitOff;   width: 300; model: 3; split: false }

    /* ── List：空头 / 空尾**不许占高度** ──
     * `delegate` 留空 → 每行高 = 0 + padV×2，于是隐式高是一个纯算术值。
     * 这一组守的是 M19 抓图里踩到的那个缺陷：头/尾宿主里各写了一条
     * 无条件存在的分割线，于是 `data.length` 恒 ≥ 1、宿主恒可见，
     * 列表凭空高 66px（33 + 33），条目区被挤出外框下缘。 */
    QSkinList { id: listPlain;         width: 300; model: 5 }
    QSkinList { id: listPlainBordered; width: 300; model: 5; bordered: true }
    QSkinList {
        id: listWithHeader
        width: 300; model: 5; bordered: true
        header: Item { implicitWidth: 40; implicitHeight: 10 }
    }

    /* ── Avatar：内容优先级 ── */
    Component {
        id: iconComp

        Item {
            implicitWidth: 12
            implicitHeight: 12
        }
    }

    QSkinAvatar { id: avText;   size: 40; text: "张" }
    QSkinAvatar { id: avIcon;   size: 40; text: "张"; icon: iconComp }
    QSkinAvatar { id: avNoSrc;  size: 40; text: "张"; icon: iconComp; src: "" }

    /* ── Avatar：圆角夹取 ── */
    QSkinAvatar { id: avCircle;   size: 40; shape: "circle" }
    QSkinAvatar { id: avSquareSm; size: 24; shape: "square" }
    QSkinAvatar { id: avSquareLg; size: 64; shape: "square" }
    QSkinAvatar { id: avNamed;    size: "sm" }

    /* ── AvatarGroup：叠放与溢出 ──
     * 五个元素 / px 32 / overlapRatio 0.3 → overlap = round(9.6) = 10、
     * step = 22。全是整数，不依赖主题、不依赖字体。 */
    QSkinAvatarGroup { id: grp5;    size: 32; overlapRatio: 0.3
                     model: ["a", "b", "c", "d", "e"] }
    QSkinAvatarGroup { id: grpMax3; size: 32; overlapRatio: 0.3; max: 3
                     model: ["a", "b", "c", "d", "e"] }
    QSkinAvatarGroup { id: grpWide; size: 32; overlapRatio: 2.0
                     model: ["a", "b", "c"] }
    QSkinAvatarGroup { id: grpNeg;  size: 32; overlapRatio: -1
                     model: ["a", "b", "c"] }

    /* ── Empty：三档缩放 ── */
    QSkinEmpty { id: emMd;     size: "md" }
    QSkinEmpty { id: emSm;     size: "sm" }
    QSkinEmpty { id: emLg;     size: "lg" }
    QSkinEmpty { id: emSimple; size: "md"; imageVariant: "simple" }
    QSkinEmpty { id: emBare;   title: ""; description: "" }
    /* 用一张内联 PNG 当自定义插图，而不是一个假的 qrc 路径 ——
     * 后者会让 QML 引擎打一条 "Cannot open: ..." 的告警，
     * 而告警**不会**让测试变红，只会在门禁输出里留下噪音。 */
    QSkinEmpty {
        id: emCustom
        imageSource: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbS"
                     + "ncAAAAFUlEQVR42mO8o6bGgA0wMeAAg1MCAOyuAThTVvE0AAAAAElFTkSuQmCC"
    }
    QSkinEmpty {
        id: emAct
        description: "还没有项目"
        action: QSkinButton { text: "新建项目" }
    }

    /* ── Skeleton：imagePosition 的四种落位 + 关闭 ── */
    QSkinSkeleton { id: skOff }
    QSkinSkeleton { id: skTop;    image: true; imagePosition: "top" }
    QSkinSkeleton { id: skBottom; image: true; imagePosition: "bottom" }
    QSkinSkeleton { id: skLeft;   image: true; imagePosition: "left" }
    QSkinSkeleton { id: skRight;  image: true; imagePosition: "right" }

    /* ── Skeleton：延迟机与内容保活 ── */
    QSkinSkeleton { id: skDelay; loading: true; delay: 5000 }
    QSkinSkeleton { id: skIdle;  loading: false }
    QSkinSkeleton {
        id: skHost
        loading: true

        Body { id: skContent; text: "真实内容" }
    }

    /* ── Spin：尺寸与描边 ── */
    QSkinSpin { id: spinSm;    size: "sm" }
    QSkinSpin { id: spinMd }
    QSkinSpin { id: spinLg;    size: "lg" }
    QSkinSpin { id: spinNum;   size: 40 }
    QSkinSpin { id: spinTiny;  size: 4 }
    QSkinSpin { id: spinDelay; delay: 5000 }
    QSkinSpin { id: spinStop;  spinning: false }
    QSkinSpin { id: spinWrap;  Body { text: "内容" } }
    QSkinSpin { id: spinBare }

    /* ── Spin：父色继承 ──
     * hostTint 带 color（鸭子类型读取的目标）；外层 root 是裸 Item，
     * 没有 color —— 正好当"父项没有 color"的反例。 */
    Rectangle {
        id: hostTint

        width: 50
        height: 50
        color: "#123456"

        QSkinSpin { id: spinTint; inheritColor: true }
    }

    QSkinSpin { id: spinNoInherit; inheritColor: false }

    /* ══════════════════ 断言 ══════════════════ */

    function run() {
        /* ── [0] List：model 的四种形态归一 ──
         * 恒等式：每种形态都读到自己的那条路径。
         *
         * 这一条真正能证伪的是**数字型**：写成 `model.length` 的实现，
         * 在 `model: 5` 上会得到 0（`.length` 是 undefined），
         * 列表当场变成空态 —— 而另外三种形态全对。也就是说
         * "只测数组"的实现会让这里红，且只红这一项。 */
        root.expect(listNumber.count === 5
                    && listArray.count === 3
                    && listLm.count === 4
                    && listZero.count === 0
                    && listNumber.hasEmptyState === false
                    && listZero.hasEmptyState === true)

        /* ── [1] List：四态互斥 + 多列关分割线 + 空头尾不占高度 ──
         *
         * 三件都是"列表此刻处于什么形态、因此该有多大"。
         *
         * ── 四态互斥 ──
         * 空态与状态行**不能同时在**："暂无数据"下面挂一条"加载更多"
         * 是列表最常见的观感事故，而两个派生量各自单看都没错
         * （count 确实是 0，loadMore 确实是 true）。
         *
         * 尤其注意 `noMore`：到底了但一条数据都没有时，屏幕上应该是
         * "暂无数据"，不是"没有更多了" —— 后者在跟用户说一句
         * 前提不成立的话。所以 listNoMore（count 0 + noMore）必须
         * 判成"有状态行、无空态"。
         *
         * ── 多列关分割线 ──
         * columns > 1 时列间要留 gutter，逐条画分割线会把每行切成一格一格。
         *
         * ── 空头尾不占高度（M19 抓图实测抓到的那条）──
         * `delegate` 空着时每行高 = padV×2，隐式高就是个纯算术值：
         *     无外框  5 × padV × 2
         *     有外框  + framePad × 2
         * 第一版的头/尾宿主里各写了一条**无条件存在**的分割线，于是
         * `data.length` 恒 ≥ 1、两个宿主恒可见、各占 33px ——
         * 列表凭空高 66px，条目区被挤出外框下缘（抓图上第一行 101px、
         * 其余 54px、总高 316 装进 240 的框）。所以这里写成恒等式，
         * 并额外确认"真的放了 header 时高度**要**变大"——
         * 不然"把宿主全删掉"也能让前两条绿。 */
        var pv = listPlain._padV
        root.expect(listEmptyState.hasEmptyState === true
                    && listEmptyState.hasStatusRow === false
                    && listLoading.hasEmptyState === false
                    && listLoading.hasStatusRow === true
                    && listMore.hasEmptyState === false
                    && listMore.hasStatusRow === true
                    && listNoMore.hasEmptyState === false
                    && listNoMore.hasStatusRow === true
                    && listSplitOn.splitActive === true
                    && listSplitMulti.splitActive === false
                    && listSplitOff.splitActive === false
                    && listPlain.implicitHeight === 5 * pv * 2
                    && listPlainBordered.implicitHeight
                       === 5 * pv * 2 + listPlainBordered._framePad * 2
                    && listWithHeader.implicitHeight > listPlainBordered.implicitHeight)

        /* ── [2] Avatar：内容优先级 src > icon > text + 圆角夹取 ──
         *
         * 优先级：三家都是"图片优先"。链子的**末端**是文字，所以
         * "图片不可用"必须能真的落到下一档 —— 这里的判据是
         * `src: ""`（Image.status === Image.Null，同步可判）。
         *
         * ── 诚实说明：Error 那一档没被这条断言覆盖 ──
         * 加载失败（status === Image.Error）是**异步**才发生的，
         * 单次 Qt.callLater 里读不到。要测就得引入一个延时阶段，
         * 而那会让退出码的解码依赖时序（可能假红）。
         * 所以这里只守 Null 这一档，"加载失败要回落"由
         * QSkinAvatar 里 showImage 的注释 + 代码评审守，不假装测过。
         *
         * 圆角那三项是**夹取**：方头像取 radius.lg，但不超过 px/4 ——
         * 否则 24px 的小头像会被圆到看不出是方的。px 24 时
         * min(radius.lg, 6) = 6（四家主题的 radius.lg 都不小于 6，
         * 实测 ant/arco/shadcn/neutral = 8、tdesign = 6），
         * 于是"忘了夹取直接写 radius.lg"会在这里红成 8。 */
        root.expect(avText.showImage === false
                    && avText.showIcon === false
                    && avText.showText === true
                    && avIcon.showImage === false
                    && avIcon.showIcon === true
                    && avIcon.showText === false
                    && avNoSrc.showImage === false
                    && avNoSrc.showIcon === true
                    && avCircle.px === 40
                    && avCircle.cornerRadius === 20
                    && avSquareSm.px === 24
                    && avSquareSm.cornerRadius === 6
                    && avSquareLg.cornerRadius === Math.min(Theme.radius.lg, 16)
                    && avNamed.px === 24
                    && avNamed.cornerRadius === 12)

        /* ── [3] AvatarGroup：叠放算术 + 溢出 + 夹取 ──
         *
         * 恒等式（全部整数，不依赖主题与字体）：
         *   overlap = round(px × 夹取(overlapRatio, 0, 0.8))
         *   step    = max(1, px − overlap)
         *   宽      = step × (slotCount − 1) + px
         *
         *   grp5     32×0.3 = 9.6 → 10，step 22，5 个 → 22×4+32 = 120
         *   grpMax3  同上，但 min(3,5)=3 个 + 1 个"+2" → 22×3+32 = 98
         *   grpWide  ratio 2.0 → 夹到 0.8 → overlap 26，step 6
         *   grpNeg   ratio −1  → 夹到 0   → overlap 0，step 32 → 32×2+32 = 96
         *
         * grpNeg 那一项守的是"负叠放不许把头像推开"：ratio 给负、
         * step 反而变大，头像之间出现缝隙 —— 那不是叠放，是排列。
         * grpWide 守的是另一头：夹取漏了的话 step 会变成 32−64 = −32。
         *
         * 最后一项 `_entryAt(3).text === "+2"` 守的是溢出位的**内容**：
         * 槽位多了一个（slotCount 4），那个槽位里必须真的是 "+2"
         * 而不是空头像 —— 空头像会读成"还有一个人的图没加载出来"。 */
        root.expect(grp5.count === 5
                    && grp5.overlap === 10
                    && grp5.step === 22
                    && grp5.visibleCount === 5
                    && grp5.overflowCount === 0
                    && grp5.slotCount === 5
                    && grp5.implicitWidth === 120
                    && grpMax3.visibleCount === 3
                    && grpMax3.overflowCount === 2
                    && grpMax3.slotCount === 4
                    && grpMax3.implicitWidth === 98
                    && String(grpMax3._entryAt(0)) === "a"
                    && grpMax3._entryAt(3).text === "+2"
                    && grpWide.overlap === 26
                    && grpWide.step === 6
                    && grpNeg.overlap === 0
                    && grpNeg.step === 32
                    && grpNeg.implicitWidth === 96)

        /* ── [4] Empty：三档缩放 + 文案派生 ──
         *
         * 缩放系数是 0.75 / 1 / 1.35 —— 刻意**不是等比数列**：
         * 等比的话 lg 会比 md 大一倍，空态开始抢视线，而空态在
         * 信息层级里是最低的一档。所以这里连系数本身一起锁住。
         *
         * 内置插图的基准几何是"两张错开 14 / 12 的纸"：
         *   单张 72×88 → 包围盒 (72+14)×(88+12) = 86×100
         * 于是 md 档的 _iw/_ih 必须是 86 / 100。这两个数是把它
         * 换掉就会红的东西（比如有人把它改成等比缩放 96×96）。
         *
         * `_px(v) = round(v × _k)` 抽出来测一次：三档下 14 分别是
         * 11 / 14 / 19。写成函数的意义就是"取整规则只有一处"，
         * 那么测一处就够了。
         *
         * 末段守 `hasText`：title 与 description 都空时不占位
         * （否则空态容器里会多出一块透明的文字高度）。
         *
         * 最后三条守的是一个**只在像素上看得见**的缺陷（M19 抓图抓出来的）：
         * `imageSource` 是 url 型，交给 JS 的是 QUrl 对象，于是
         * `imageSource === ""` 恒假、`!== ""` 恒真 —— 内置插图被永久藏掉，
         * 空态只剩一行"暂无数据"。属性侧当时全绿，所以这个坑必须
         * 在属性侧就立一根桩：`hasCustomArt` 若被改回裸比较，
         * `emMd.hasCustomArt === false` 立刻变红。
         *
         * ⚠ 最后一条自己就是受害者：`listEmptyState.emptyImage` 同样是 url 型，
         * 写成 `=== ""` 会恒假 —— 所以这里**必须** String() 后再比。
         * 写测试的时候，同一个坑会从控件的门缝里钻进来。 */
        root.expect(emMd._k === 1.0
                    && emSm._k === 0.75
                    && emLg._k === 1.35
                    && emMd._iw === 86
                    && emMd._ih === 100
                    && emSimple._iw === 72
                    && emSimple._ih === 88
                    && emSm._iw < emMd._iw
                    && emMd._iw < emLg._iw
                    && emSm._ih < emMd._ih
                    && emMd._ih < emLg._ih
                    && emSm._px(14) === 11
                    && emMd._px(14) === 14
                    && emLg._px(14) === 19
                    && emBare.hasTitle === false
                    && emBare.hasText === false
                    && emBare.hasAction === false
                    && emAct.hasAction === true
                    && emAct.hasText === true
                    && emMd.hasCustomArt === false
                    && emCustom.hasCustomArt === true
                    && String(listEmptyState.emptyImage) === "")

        /* ── [5] Skeleton：落位表 + 延迟机 + 内容保活 ──
         *
         * 落位表是 5 种情形 × 6 个量。之所以把它整张抄下来，是因为
         * 这张表**不能靠读代码验证**：GridLayout 的 row/column/span
         * 写错一个数字，属性侧完全自洽（每个量都是合法的整数），
         * 只有渲染出来才知道图片跑到文字右边还是下面。
         * 所以这里逐格对照（left 与 right 的 _imgCol/_txtCol 必须互换，
         * top 与 bottom 的 _imgRow/_txtRow 必须互换）—— 只有成对换错
         * 或者忘了换，这里才红。
         *
         * 延迟机：`delay` 存在的意义是"别一闪而过"。skDelay 给了 5 秒，
         * 断言必须落在"骨架还没出来"那一侧（active false）——
         * 实现若把 _shown 的初值写反、或忘了在 onCompleted 里起延时，
         * 这里立刻红。同时 contentVisible 必须为 true：骨架还没出现时
         * 内容**不该**跟着消失，否则那 5 秒里屏幕上什么都没有。
         *
         * 内容保活：加载中时内容只是 visible=false，**没有离开对象树**。
         * 这一条守的是"滚动位置 / 展开态 / 半截输入"不被重建吞掉 ——
         * 用 Loader / visible 二选一实现的话，skContent 会被销毁或
         * 根本没创建，`skContent.parent !== null` 直接失败。 */
        root.expect(skOff._imgRow === 0 && skOff._txtRow === 0
                    && skOff._imgCol === 0 && skOff._txtCol === 0
                    && skOff._imgSpan === 1 && skOff._txtSpan === 2
                    && skTop._side === false
                    && skTop._imgRow === 0 && skTop._txtRow === 1
                    && skTop._imgSpan === 2 && skTop._txtSpan === 2
                    && skBottom._imgRow === 1 && skBottom._txtRow === 0
                    && skBottom._imgSpan === 2 && skBottom._txtSpan === 2
                    && skLeft._side === true
                    && skLeft._imgRow === 0 && skLeft._txtRow === 0
                    && skLeft._imgCol === 0 && skLeft._txtCol === 1
                    && skLeft._imgSpan === 1 && skLeft._txtSpan === 1
                    && skRight._imgCol === 1 && skRight._txtCol === 0
                    && skRight._imgSpan === 1 && skRight._txtSpan === 1
                    && skOff.active === true
                    && skDelay.delay === 5000
                    && skDelay.active === false
                    && skDelay.skeletonVisible === false
                    && skDelay.contentVisible === true
                    && skIdle.active === false
                    && skIdle.skeletonVisible === false
                    && skIdle.contentVisible === true
                    && skHost.active === true
                    && skHost.contentVisible === false
                    && skContent.parent !== null
                    && skContent.visible === false)

        /* ── [6] Spin：尺寸 / 描边 / 在场判定 ──
         *
         * 三档尺寸 16 / 24 / 32，描边按直径的 1/10 取整后夹到 ≥2：
         *   sm  16 → round(1.6) = 2
         *   md  24 → round(2.4) = 2
         *   lg  32 → round(3.2) = 3
         *   40     → 4
         *   4 → 边长夹到 8 → round(0.8) = 1 → 夹到 2
         * spinTiny 是这条的关键：它同时穿过**两个**夹取。
         * 只写 `strokeWidth: round(size/10)` 的实现会在 4px 上
         * 得到 1，一条比发丝还细的线 —— 屏幕上等于没画。
         *
         * 在场判定与 Skeleton 同构但语义相反：Skeleton 是
         * "知道内容长什么样，先拿骨架顶着"，Spin 是"不知道，先转着"。
         * spinDelay 的 delay 也是 5 秒，落点同样必须在"还没转"那一侧。
         *
         * spinWrap / spinBare 守 `hasContent` —— 它决定尺寸来自内容
         * 还是来自指示器块。写错的后果是包裹模式下的 Spin 撑出一个
         * 24px 的方块，把外面的布局顶歪。 */
        root.expect(spinSm.indicatorSize === 16
                    && spinSm.strokeWidth === 2
                    && spinMd.indicatorSize === 24
                    && spinMd.strokeWidth === 2
                    && spinLg.indicatorSize === 32
                    && spinLg.strokeWidth === 3
                    && spinNum.indicatorSize === 40
                    && spinNum.strokeWidth === 4
                    && spinTiny.indicatorSize === 8
                    && spinTiny.strokeWidth === 2
                    && spinSm.active === true
                    && spinDelay.delay === 5000
                    && spinDelay.active === false
                    && spinStop.active === false
                    && spinWrap.hasContent === true
                    && spinBare.hasContent === false)

        /* ── [7] Spin：继承父色（鸭子类型） ──
         *
         * 这是本批唯一一条**依赖父项**的断言，也是唯一一条读
         * "控件之外的东西"的断言 —— 所以它单独占一格。
         *
         * `inheritColor` 的用途：把加载圈放进一个按钮 / 深色标题栏，
         * 品牌紫在那个底色上要么糊要么跳，此时应该跟随父项的颜色。
         * 实现读 `root.parent.color`，而 parent 的静态类型是 QQuickItem
         * （没有 color），只能鸭子类型读 —— 于是"父项没有 color"这条
         * 分支必须真的存在，否则放错位置的 Spin 会拿到 undefined，
         * 整条弧画成黑色（或什么都不画）。
         *
         * 比的是 0..255 的整数值 —— 浮点误差不会让它假红。 */
        root.expect(Math.round(spinTint.color.r * 255) === 0x12
                    && Math.round(spinTint.color.g * 255) === 0x34
                    && Math.round(spinTint.color.b * 255) === 0x56
                    && Math.round(spinNoInherit.color.r * 255) === 0x7C
                    && Math.round(spinNoInherit.color.g * 255) === 0x3A
                    && Math.round(spinNoInherit.color.b * 255) === 0xED)

        Qt.exit(root.mask)
    }

    /* 推迟一轮：Qt Quick Layouts 把尺寸重算放在 polish 阶段，
     * 在 onCompleted 里同步读会读到重算之前的值（见 smoke_sizes.qml）。 */
    Component.onCompleted: function() { Qt.callLater(root.run) }
}
