#!/usr/bin/env python3
"""QSkin · PyQt5 宿主 —— 证明 Python 侧在 **Qt 5** 下也能直接用 QSkin。

SPDX-License-Identifier: MIT OR Apache-2.0

用法：
    python examples/hosts/pyqt5/main.py --import-path qt5 \
           --scene tests/scene_host_parity.qml

── 为什么还要有这个宿主（已经有了 PySide6）─────────────────────────────────
PySide6 只绑 Qt 6；PyQt5 只绑 Qt 5。**它们不是同一个 Qt**，走的是两条不同的
源码树：

    PySide6（Qt 6）  →  src/     （Qt 6.8+ 写法，事实源）
    PyQt5  （Qt 5）  →  qt5/     （tools/qml-downgrade.py 生成）

信创机器（龙芯 LoongArch / MIPS、麒麟 V10 等）系统 Qt 是 5.x，装不上 PySide6，
但 PyQt5 可以——它提供 sdist 可本地编译，龙芯还有自己的 pypi 镜像。所以 Qt 5
这条线不是"顺手支持"，是那些机器上**唯一能用 Python 的路**。

── 关于 "PyQt5 自带 Qt 运行时" ──────────────────────────────────────────────
`pip install PyQt5` 会连带装上 `PyQt5-Qt5`（实测 5.15.2），wheel 自带一套
完整的 Qt 5 运行时，**不依赖系统 Qt**。所以即便目标机系统 Qt 更旧，PyQt5 跑的
仍是它自带的 5.15.2 —— 这也是本仓把 Qt5 目标定在 **5.15 而不是 5.11** 的原因
（5.15 才有 Shapes / required property / Pointer Handlers，省掉大量改写）。

⚠ 反过来：**sdist 安装**（龙芯常见）不自带 Qt，需要系统有 Qt 5 开发库。

── 它只做三件事，别的都不做 ───────────────────────────────────────────────
    1. 起 QGuiApplication + QQmlApplicationEngine
    2. 加 import 路径、注入 hostTag、加载场景
    3. exec_()，把场景打印的 PARITY 行透传出去

对账逻辑全部住在 QML 场景里（见 tests/scene_host_parity.qml）—— 宿主之间
不存在"测的不是同一件事"的空间。

── 与 PySide6 宿主的两处必要差异 ───────────────────────────────────────────
    · `app.exec_()`：PyQt5 只有带下划线的版本（PySide6 是 `exec()`）。
    · 默认 import 路径是 `qt5/` 而不是 `.cache/qmlimports` —— 那是 Qt 6 侧
      的产物目录，Qt 5 侧用降级产物。
"""

import argparse
import os
import sys


def _find_root():
    """向上找仓库根（`CMakeLists.txt` 所在层）。

    ⚠ 别用「固定层数 dirname」：那跟本文件嵌了多深绑死，挪一层目录就静默
    指错地方（实测就犯过 —— 少算一层，ROOT 落到 examples/）。
    """
    d = os.path.dirname(os.path.abspath(__file__))
    for _ in range(8):
        if os.path.exists(os.path.join(d, "CMakeLists.txt")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            break
        d = parent
    return os.path.dirname(os.path.abspath(__file__))


ROOT = _find_root()


def main():
    ap = argparse.ArgumentParser(description="QSkin · PyQt5 宿主")
    ap.add_argument("--import-path", default=os.path.join(ROOT, "qt5"),
                    help="QML import 路径（默认 qt5/，即降级产物）")
    ap.add_argument("--scene", default=os.path.join(ROOT, "tests", "scene_host_parity.qml"),
                    help="要加载的场景（默认 tests/scene_host_parity.qml）")
    ap.add_argument("--host-tag", default="pyqt5", help="打进画面的宿主标识")
    ap.add_argument("--no-shot", action="store_true", help="不抓图（只做契约检查）")
    args = ap.parse_args()

    # Windows GUI 子系统下 QML 报错默认走 OutputDebugString（静默失败），
    # 这个变量把日志强制接到 stderr —— 与 tools/shot.sh 同款处理。
    os.environ.setdefault("QT_FORCE_STDERR_LOGGING", "1")

    from PyQt5.QtCore import QUrl, QT_VERSION_STR
    from PyQt5.QtGui import QGuiApplication
    from PyQt5.QtQml import QQmlApplicationEngine

    print("PARITY qt %s" % QT_VERSION_STR)

    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.addImportPath(args.import_path)

    # hostTag / shotMode 必须在 load 之前注入：场景的 Component.onCompleted
    # 会立刻开跑，晚了就只是改了个没人读的属性。
    props = {"hostTag": args.host_tag}
    if args.no_shot:
        props["shotMode"] = False
    engine.setInitialProperties(props)

    scene = os.path.abspath(args.scene)
    if not os.path.exists(scene):
        print("工装错误：场景不存在 -> %s" % scene)
        return 8

    engine.load(QUrl.fromLocalFile(scene))
    if not engine.rootObjects():
        print("PARITY fail 9999  （无根对象：场景没加载起来）")
        return 4

    return app.exec_()


if __name__ == "__main__":
    sys.exit(main())
