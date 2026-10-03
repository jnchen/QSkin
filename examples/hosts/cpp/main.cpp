/****************************************************************************
 * QSkin · Quick Design System — C++ 宿主
 *
 * SPDX-License-Identifier: MIT OR Apache-2.0
 *
 * 用法：
 *     qdshost --import-path .cache/qmlimports --scene tests/scene_host_parity.qml
 *
 * ── 为什么要有这个文件 ──────────────────────────────────────────────────
 * README 的立场是「QSkin 是纯 QML 源码分发、没有 C++ 入口」。这句话长期
 * **只被 qml 运行器验证过** —— 真正的 C++ 宿主（QtWidgets/QtQuick 应用
 * 用 C++ main + QQmlApplicationEngine 起引擎）一次都没跑过。"纯 QML 所以
 * C++ 能用"是推论，不是实测。
 *
 * 这个宿主把它变成一条可复算的命令，并与 PySide6 宿主加载**完全相同**的
 * 场景文件，于是两边结果可以直接对齐。
 *
 * ── 它刻意只做三件事 ────────────────────────────────────────────────────
 *   1. 起 QGuiApplication + QQmlApplicationEngine
 *   2. 加 import 路径、注入 hostTag、加载场景
 *   3. exec()
 *
 * 所有对账逻辑住在 QML 场景里（tests/scene_host_parity.qml）。宿主之间不
 * 存在"测的不是同一件事"的空间 —— 这是整个设计的关键。
 ****************************************************************************/

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QCommandLineParser>
#include <QDebug>
#include <QDir>
#include <QUrl>
#include <QVariantMap>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("qdshost"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("QSkin C++ 宿主"));
    parser.addHelpOption();
    QCommandLineOption importOpt(QStringLiteral("import-path"),
                                 QStringLiteral("QML import 路径"),
                                 QStringLiteral("dir"));
    QCommandLineOption sceneOpt(QStringLiteral("scene"),
                                QStringLiteral("要加载的 QML 场景"),
                                QStringLiteral("file"));
    QCommandLineOption tagOpt(QStringLiteral("host-tag"),
                              QStringLiteral("打进画面的宿主标识"),
                              QStringLiteral("tag"), QStringLiteral("cpp"));
    QCommandLineOption noShotOpt(QStringLiteral("no-shot"),
                                 QStringLiteral("不抓图，只做契约检查"));
    parser.addOption(importOpt);
    parser.addOption(sceneOpt);
    parser.addOption(tagOpt);
    parser.addOption(noShotOpt);
    parser.process(app);

    // 宿主把自己链接的 Qt 版本报出去：对账时这是判读差异的关键背景。
    // （QML 侧拿不到"宿主链接了哪个 Qt"，只能由这里报。）
    qInfo().noquote() << "PARITY qt" << qVersion();

    const QString scene = parser.value(sceneOpt);
    if (scene.isEmpty() || !QFileInfo::exists(scene)) {
        qCritical().noquote() << "工装错误：场景不存在 ->" << scene;
        return 8;
    }

    QQmlApplicationEngine engine;
    const QString importPath = parser.value(importOpt);
    if (!importPath.isEmpty())
        engine.addImportPath(QDir::fromNativeSeparators(importPath));

    // hostTag / shotMode 必须在 load **之前**注入：场景的
    // Component.onCompleted 会立刻开跑，晚了就只是改了个没人读的属性。
    QVariantMap init;
    init.insert(QStringLiteral("hostTag"), parser.value(tagOpt));
    if (parser.isSet(noShotOpt))
        init.insert(QStringLiteral("shotMode"), false);
    engine.setInitialProperties(init);

    engine.load(QUrl::fromLocalFile(QFileInfo(scene).absoluteFilePath()));
    if (engine.rootObjects().isEmpty()) {
        qCritical().noquote() << "PARITY fail 9999  （无根对象：场景没加载起来）";
        return 4;
    }

    return app.exec();
}
