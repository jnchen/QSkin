# QSkin · C++ 宿主的 **Qt 5** 变体
#
# ── 为什么单独一份 CMakeLists，而不是给上面那份加开关 ──────────────────────
# Qt 5 与 Qt 6 的 CMake 接口是**两套**，不是参数差异：
#     Qt 6: find_package(Qt6 …)  + qt_add_executable()
#     Qt 5: find_package(Qt5 …)  + add_executable()      （没有 qt_add_executable）
# 硬塞进一个文件里做分支，两边都难读。宿主本身（main.cpp）是同一份 ——
# 它用的 QGuiApplication / QQmlApplicationEngine / QCommandLineParser 在
# Qt 5.15 与 Qt 6 下都存在，这正是"纯 QML 库"该有的性质。
#
# 构建：bash examples/hosts/cpp-qt5/build.sh
cmake_minimum_required(VERSION 3.16)
project(qdshost5 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt5 REQUIRED COMPONENTS Core Gui Qml Quick)

add_executable(qdshost5 ../cpp/main.cpp)

target_link_libraries(qdshost5 PRIVATE
    Qt5::Core
    Qt5::Gui
    Qt5::Qml
    Qt5::Quick
)

set_target_properties(qdshost5 PROPERTIES WIN32_EXECUTABLE FALSE)
