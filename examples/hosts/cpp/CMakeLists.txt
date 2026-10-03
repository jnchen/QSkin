# QSkin · C++ 宿主（独立小工程，不挂进主 CMakeLists）
#
# ── 为什么是独立工程而不是主工程的一个 target ────────────────────────────
# 主 `CMakeLists.txt` 有 25KB、六个 `qt_add_qml_module`，为一个宿主验证脚本
# 动它风险太高。这个宿主是**验证工装**，不是库的一部分 —— 它只需要能找到
# Qt 的 Qml/Quick 模块就够了。
#
# 构建：bash examples/hosts/cpp/build.sh
cmake_minimum_required(VERSION 3.16)
project(qdshost LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)

qt_add_executable(qdshost main.cpp)

target_link_libraries(qdshost PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
)

# Windows GUI 子系统：不加这句会弹控制台窗口，且 QML 报错走
# OutputDebugString（静默失败）。与 tools/shot.sh 的
# QT_FORCE_STDERR_LOGGING 是同一件事的两个面。
set_target_properties(qdshost PROPERTIES WIN32_EXECUTABLE FALSE)
