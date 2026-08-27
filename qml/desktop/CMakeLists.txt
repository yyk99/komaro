cmake_minimum_required(VERSION 3.21)

project(komaro_qml_desktop LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 QmlCore)

qt_standard_project_setup()

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# So qt_add_qml_module in subdirectories (e.g. ../core) places its modules
# directly under the top-level build dir, matching where qmlimportscanner's
# default -importPath looks; otherwise a subdirectory's own module would
# land one level too deep under its own CMAKE_CURRENT_BINARY_DIR and never
# be found.
set(QT_QML_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

option(BUILD_TESTS "Build unit tests" ON)

if(BUILD_TESTS)
    enable_testing()
endif()

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../core ${CMAKE_CURRENT_BINARY_DIR}/core)

qt_add_executable(komaro_qml_desktop
    src/main.cpp
)

# `cmake --build build/<preset> -t touch` (or --target touch) forces
# main.cpp to recompile even if unchanged, so its __DATE__/__TIME__-derived
# appBuildTimestamp reflects the current build rather than a stale one.
add_custom_target(touch
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp"
    COMMENT "Touching src/main.cpp to force a fresh build timestamp"
)

# See core/CMakeLists.txt for why QTP0004 is set explicitly.
qt_policy(SET QTP0004 NEW)

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
    komaro_core
    komaro_core_qml
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QmlCore
)

qt_import_qml_plugins(komaro_qml_desktop)

get_target_property(_qt6_qmake_executable Qt6::qmake IMPORTED_LOCATION)
get_filename_component(_qt6_bin_dir "${_qt6_qmake_executable}" DIRECTORY)
find_program(WINDEPLOYQT_EXECUTABLE windeployqt PATHS "${_qt6_bin_dir}" NO_DEFAULT_PATH)

if(WINDEPLOYQT_EXECUTABLE)
    add_custom_command(TARGET komaro_qml_desktop POST_BUILD
        COMMAND "${WINDEPLOYQT_EXECUTABLE}"
                --verbose 0
                --qmldir "${CMAKE_CURRENT_SOURCE_DIR}/qml"
                "$<TARGET_FILE:komaro_qml_desktop>"
        COMMENT "Deploying Qt runtime dependencies for komaro_qml_desktop"
    )
else()
    message(WARNING "windeployqt not found under ${_qt6_bin_dir}; Qt runtime dependencies will not be deployed automatically")
endif()

# `cmake --install build/<preset> --prefix <dir>` installs the executable
# (QML files are already embedded as Qt resources via qt_add_qml_module, so
# there's nothing else of ours to install) plus deploys its Qt runtime
# dependencies into the install tree via qt_generate_deploy_app_script. Unlike
# the POST_BUILD windeployqt command above (Windows-only, since windeployqt
# doesn't exist on Linux - see qml/README.md), this one works cross-platform:
# on Linux it uses Qt's "generic deploy tool" instead, which resolves and
# copies the actual shared library dependencies rather than shelling out to a
# platform-specific deploy binary - verified by installing to a scratch
# prefix and confirming `ldd` on the installed binary resolves everything
# against the bundled lib/ dir, not the build tree's Qt.
include(GNUInstallDirs)

if(UNIX AND NOT APPLE)
    # Qt's QML plugins are loaded via dlopen() at runtime, not linked
    # directly into komaro_qml_desktop, so they don't inherit its
    # $ORIGIN-relative RPATH when resolving THEIR OWN transitive
    # dependencies - RUNPATH (which CMake sets by default, unlike the
    # older, transitively-inherited RPATH) only governs a binary's own
    # direct link dependencies. Confirmed by testing an install: without
    # this wrapper, QtQuick.Controls' plugin resolved
    # libQt6QuickTemplates2.so.6 from Ubuntu's own system Qt6 package
    # instead of our bundled one, crashing with an undefined-symbol error
    # from the ABI mismatch. LD_LIBRARY_PATH, unlike RPATH/RUNPATH, applies
    # to every dlopen() in the process, so a thin wrapper script that sets
    # it fixes this without requiring the user to set anything themselves.
    install(TARGETS komaro_qml_desktop
        RUNTIME DESTINATION ${CMAKE_INSTALL_LIBEXECDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    )

    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/komaro_qml_desktop-wrapper.sh" [[#!/bin/sh
here="$(cd "$(dirname "$0")" && pwd)"
exec env LD_LIBRARY_PATH="$here/../lib:$LD_LIBRARY_PATH" "$here/../libexec/komaro_qml_desktop" "$@"
]])
    install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/komaro_qml_desktop-wrapper.sh"
        DESTINATION ${CMAKE_INSTALL_BINDIR}
        RENAME komaro_qml_desktop
    )
else()
    install(TARGETS komaro_qml_desktop
        BUNDLE DESTINATION .
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    )
endif()

qt_generate_deploy_app_script(
    TARGET komaro_qml_desktop
    OUTPUT_SCRIPT deploy_script
    NO_UNSUPPORTED_PLATFORM_ERROR
)
install(SCRIPT ${deploy_script})

# qt_generate_deploy_app_script()'s generated script only deploys shared
# library dependencies of komaro_qml_desktop ITSELF (qt6_deploy_runtime_
# dependencies) - it does NOT deploy Qt's own QML modules (QtQuick,
# QtQuick.Controls, QtQuick.Layouts, QtCore's Settings, ...) even though
# Main.qml imports them, so a standalone install previously failed at
# runtime with "module ... is not installed". qt6_deploy_qml_imports()
# below fixes that - but its plugins (e.g. libqtquickcontrols2plugin.so)
# have their OWN transitive dependencies (e.g. libQt6QuickTemplates2.so.6)
# that were never scanned, since they didn't exist yet when
# qt6_deploy_runtime_dependencies ran above. Without this second call
# (using its PLUGINS_FOUND output as ADDITIONAL_MODULES), those
# dependencies are silently missing from lib/, and the plugin loader falls
# back to resolving them from the system's own (possibly ABI-incompatible)
# Qt6 packages instead - confirmed by testing: this exact gap caused an
# undefined-symbol crash from Ubuntu's system libQt6QuickTemplates2.so.6.
install(CODE [[
qt6_deploy_qml_imports(TARGET komaro_qml_desktop PLUGINS_FOUND qml_plugin_libs)
qt6_deploy_runtime_dependencies(
    EXECUTABLE "$<TARGET_FILE:komaro_qml_desktop>"
    ADDITIONAL_MODULES ${qml_plugin_libs}
    NO_TRANSLATIONS
)
]])
