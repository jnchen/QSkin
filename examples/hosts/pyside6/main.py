#!/usr/bin/env python3
"""QSkin · PySide6 宿主 —— 证明 Python 侧能直接用 QSkin。

SPDX-License-Identifier: MIT OR Apache-2.0

用法：
    python examples/hosts/pyside6/main.py --import-path .cache/qmlimports \
           --scene tests/scene_host_parity.qml

── 为什么要有这个文件 ──────────────────────────────────────────────────────
README 写的是「为 Qt Quick 打造的设计系统」。但本仓此前**只验证过 `qml`
运行器**：全仓搜 `PySide|PyQt` 零命中。对 Python 用户来说，"能加载 QML"
只是理论上成立 —— 从没被跑过一次。

这个宿主把它变成一条可复算的命令：起一个 PySide6 的 QML 引擎，加载与
C++ 宿主**完全相同**的场景文件，于是两边的结果可以直接对齐。

── 它只做三件事，别的都不做 ───────────────────────────────────────────────
    1. 起 QGuiApplication + QQmlApplicationEngine
    2. 加 import 路径、注入 hostTag、加载场景
    3. exec()，把场景打印的 PARITY 行透传出去

对账逻辑全部住在 QML 场景里（见 tests/scene_host_parity.qml）—— 宿主之间
不存在"测的不是同一件事"的空间。

── 关于 Qt 版本 ────────────────────────────────────────────────────────────
PySide6 自带一套 Qt，**版本未必等于本仓开发用的 .qt/6.8.3**。所以这里会
把自己链接的 Qt 版本打进 `PARITY qt` —— 对账时它是判读差异的关键背景，
不是装饰。
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
    ap = argparse.ArgumentParser(description="QSkin · PySide6 宿主")
    ap.add_argument("--import-path", default=os.path.join(ROOT, ".cache", "qmlimports"),
                    help="QML import 路径（默认 .cache/qmlimports）")
    ap.add_argument("--scene", default=os.path.join(ROOT, "tests", "scene_host_parity.qml"),
                    help="要加载的场景（默认 tests/scene_host_parity.qml）")
    ap.add_argument("--host-tag", default="pyside6", help="打进画面的宿主标识")
    ap.add_argument("--no-shot", action="store_true", help="不抓图（只做契约检查）")
    args = ap.parse_args()

    # Windows GUI 子系统下 QML 报错默认走 OutputDebugString（静默失败），
    # 这个变量把日志强制接到 stderr —— 与 tools/shot.sh 同款处理。
    os.environ.setdefault("QT_FORCE_STDERR_LOGGING", "1")

    from PySide6.QtCore import QUrl, qVersion
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine

    print("PARITY qt %s" % qVersion())

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

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
