cmake_minimum_required(VERSION 3.21)

project(komaro_qml_desktop LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

qt_standard_project_setup()

qt_add_executable(komaro_qml_desktop
    src/main.cpp
)

qt_add_qml_module(komaro_qml_desktop
    URI KomaroDesktop
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        qml/Main.qml
)

set_target_properties(komaro_qml_desktop PROPERTIES
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(komaro_qml_desktop PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
)
