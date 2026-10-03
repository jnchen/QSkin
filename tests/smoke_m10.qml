import QtQuick 2.15
import QSkin.Foundation 1.0
import QSkin.Contracts 1.0

Item {
    id: root

    property int failures: 0
    function bit(n, ok) { if (!ok) root.failures |= (1 << n) }

    /* ── QSkinProgress ── */
    QSkinProgress { id: pr1; width: 200; progress: 0.62 }
    QSkinProgress { id: pr2; width: 200; progress: 1.8 }        /* 越界应钳到 1 */
    QSkinProgress { id: pr3; width: 200; progress: -0.5 }       /* 越界应钳到 0 */
    QSkinProgress { id: pr4; variant: "circle"; progress: 0.4; circleSize: 96 }
    QSkinProgress { id: pr5; width: 200; indeterminate: true }

    /* ── QSkinTag ── */
    QSkinTag { id: tag1; text: "已上线"; variant: "success" }
    QSkinTag { id: tag2; text: "高危"; variant: "danger"; closable: true }

    /* ── QSkinBadge ── */
    QSkinBadge { id: bd1; value: 5 }
    QSkinBadge { id: bd2; value: 150; max: 99 }                  /* 应显示 99+ */
    QSkinBadge { id: bd3; value: 0 }                             /* 应隐藏 */
    QSkinBadge { id: bd4; value: 3; dot: true }                  /* 圆点 */
    QSkinBadge { id: bd5; value: 0; showZero: true }

    /* ── QSkinBreadcrumb ── */
    QSkinBreadcrumb { id: bc1; model: ["首页", "项目", "详情"] }
    QSkinBreadcrumb { id: bc2; collapsible: false
                    model: ["首页", "一级", "二级", "三级", "四级", "当前"] }
    QSkinBreadcrumb { id: bc3; model: ["首页", "一级", "二级", "三级", "四级", "当前"] }

    /* ── QSkinSteps ── */
    QSkinSteps { id: st1; currentIndex: 1
               model: [{title:"填写",description:"基础信息"}, {title:"确认",description:"核对"}, {title:"完成"}] }
    QSkinSteps { id: st2; variant: "vertical"; currentIndex: 2
               model: ["第一步", "第二步", "第三步"] }
    QSkinSteps { id: st3; currentIndex: 9
               model: ["A", "B"] }                             /* 全部完成 */

    /* ── QSkinProgress 文字槽位（回归：百分比不许叠在轨道上）──
     * 实测过的 bug：文字叠放 + label 默认深色前景，100% 时深字压深底，
     * 看起来像文字溢出到条外。修法是把文字让到轨道右侧的独立槽位。
     * 这里钉死"让位"这件事：轨道宽必须比控件整体窄出文字槽 + 间距。 */
    QSkinProgress { id: pr6; width: 200; progress: 1.0 }              /* 满进度 */
    QSkinProgress { id: pr7; width: 200; progress: 0.5; showText: false }
    QSkinProgress { id: pr8; width: 200; progress: 0.5; textBeside: false }

    /* ── QSkinBadge 视觉回归 ──
     * 实测过的两个缺陷：
     *   ① 高度 16px 配 12px 字号 → 数字顶到胶囊边缘，看着发闷；
     *   ② anchors.centerIn 让"盒子"居中，但 Text 盒子含下行留白，
     *      数字字形实际偏高 —— 视觉上像没对齐。
     * 修法：高度取 iconMd(20) + anchors.fill + AlignVCenter。 */
    QSkinBadge { id: bd6; value: 5 }
    QSkinBadge { id: bd7; value: 12 }
    QSkinBadge { id: bd8; value: 7; status: "success" }

    /* ── QSkinBadge.anchorTo ── */
    QSkinButton { id: hostBtn; text: "宿主" }
    QSkinBadge { id: bd9;  anchorTo: hostBtn; value: 5 }
    QSkinBadge { id: bd10; anchorTo: hostBtn; value: 9; anchorCorner: "bottomLeft" }

    Timer {
        interval: 500
        running: true
        repeat: false
        onTriggered: root.check()
    }

    function check() {
        /* [0] Progress 钳制 */
        root.bit(0, Math.abs(pr1.clamped - 0.62) < 1e-9
                   && Math.abs(pr2.clamped - 1.0) < 1e-9
                   && Math.abs(pr3.clamped - 0.0) < 1e-9)

        /* [1] Progress 文字 */
        root.bit(1, pr1.text === "62%" && pr2.text === "100%")

        /* [2] Tag 尺寸合理 + 关闭态 */
        root.bit(2, tag1.width > 0 && tag1.height > 0
                   && tag2.closable === true && tag2.width > tag1.width)

        /* [3] Badge 封顶 / 隐藏 / 圆点 / showZero */
        root.bit(3, bd1.text === "5"
                   && bd2.text === "99+"
                   && bd3.effectiveVisible === false
                   && bd4.effectiveVisible === true
                   && bd5.text === "0")

        /* [4] 里程碑回归三合一：Breadcrumb 折叠 + Steps 状态推导 +
         *     Progress 文字让位。
         *
         *     为什么把三件事压进一条：退出码只有低 8 位可用（见
         *     tools/test.sh 文件头），8 个 bit 是硬上限。里程碑文件
         *     攒到后面就会顶到上限 —— 与其把新回归挤到 bit 8+ 被
         *     test.sh 漏掉（这是真实踩过的坑），不如按"同一被改动的
         *     组件"合并同类项。 */
        var ents = bc3._visibleEntries()
        var crumbCount = 0, ellipsisCount = 0
        for (var i = 0; i < ents.length; ++i) {
            if (ents[i].kind === "crumb") crumbCount++
            if (ents[i].kind === "ellipsis") ellipsisCount++
        }
        var lastEnt = null
        for (var j = ents.length - 1; j >= 0; --j)
            if (ents[j].kind === "crumb") { lastEnt = ents[j]; break }

        root.bit(4, bc1.count === 3 && bc2.count === 6
                   && bc1._needsCollapse === false
                   && bc2._needsCollapse === false
                   && bc3._needsCollapse === true
                   && crumbCount === 3 && ellipsisCount === 1
                   && lastEnt !== null && lastEnt.last === true
                   && lastEnt.srcIndex === bc3.count - 1
                   && st1.statusOf(0) === "finish"
                   && st1.statusOf(1) === "process"
                   && st1.statusOf(2) === "wait"
                   && st3.statusOf(0) === "finish"
                   && st3.statusOf(1) === "finish"
                   && Math.abs(pr6._trackWidth - pr6.width) > 1e-9
                   && pr6._textBesideLine === true
                   && pr6.text === "100%")

        /* [5] Progress 文字槽位的两条边界：不显示文字 / 显式叠放时，
         *     轨道必须吃满整个宽度（回归「文字让位」的开关逻辑）。 */
        root.bit(5, Math.abs(pr7._trackWidth - pr7.width) < 1e-9
                   && pr7._textBesideLine === false
                   && Math.abs(pr8._trackWidth - pr8.width) < 1e-9
                   && pr8._textBesideLine === false
                   && Math.abs(pr6._trackWidth
                                - (pr6.width - pr6.textWidth - pr6.textGap)) < 1e-9)

        /* [6] Badge 尺寸与居中回归 —— 数字徽标高度必须够（>= iconMd 20），
         *     单数字正圆、两位数比单数字宽，且高度明显大于字号 12。
         *
         *     注意阈值：两位数胶囊的宽度是「文字宽 + 左右各 xs」，
         *     "12" 实测算得 22px，与 badgeHeight(20) 只差 2px ——
         *     所以**不能**要求 width > height + 2（实测 22 > 22 不成立）。
         *     改为和「单数字徽标」比宽度，这才是"两位数更宽"的稳定判据。 */
        root.bit(6, bd6.height >= 20
                   && Math.abs(bd6.width - bd6.height) < 0.6      /* 单数字正圆 */
                   && bd7.width >= bd7.height                      /* 两位数不比正圆窄 */
                   && bd7.width > bd6.width                        /* 且确实更宽 */
                   && bd6.height >= 12 + 4)                        /* 字号上下有余量 */

        /* [7] anchorTo 挂靠 —— 徽标中心应压在宿主角上，且盖在宿主之上。
         *      topRight:   x ≈ host.x + host.w - badge.w/2,
         *                  y ≈ host.y - badge.h/2
         *      bottomLeft: x ≈ host.x - badge.w/2,
         *                  y ≈ host.y + host.h - badge.h/2  */
        var trDx = Math.abs(bd9.x - (hostBtn.x + hostBtn.width - bd9.width / 2))
        var trDy = Math.abs(bd9.y - (hostBtn.y - bd9.height / 2))
        var blDx = Math.abs(bd10.x - (hostBtn.x - bd10.width / 2))
        var blDy = Math.abs(bd10.y - (hostBtn.y + hostBtn.height - bd10.height / 2))
        root.bit(7, trDx < 1.0 && trDy < 1.0 && blDx < 1.0 && blDy < 1.0
                    && bd9.z > hostBtn.z)                           /* 徽标在宿主之上 */

        Qt.exit(Math.min(255, root.failures))
    }
}
