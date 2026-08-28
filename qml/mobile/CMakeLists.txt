cmake_minimum_required(VERSION 3.21)

project(komaro_qml_mobile LANGUAGES CXX)

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

qt_add_executable(komaro_qml_mobile
    src/main.cpp
    src/ScreenWakeLock.h
    src/ScreenWakeLock.cpp
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

qt_add_qml_module(komaro_qml_mobile
    URI KomaroMobile
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        qml/Main.qml
)

# Reverse-GitHub package name (no owned domain for a real reverse-DNS one).
# Qt's default ("org.qtproject.example.<target>") is a shared placeholder -
# every unconfigured Qt Android app looks like the same app to Android's
# package manager, so installing a build from a different machine/project
# over it fails with INSTALL_FAILED_UPDATE_INCOMPATIBLE (signature mismatch).
set(KOMARO_ANDROID_PACKAGE_NAME "io.github.yyk99.komaro")

# android/ is a copy of Qt's own package template (AndroidManifest.xml,
# with android:icon/android:roundIcon added - Qt's default has neither
# attribute at all - plus res/mipmap-*/ic_launcher*.png) - androiddeployqt
# copies this directory on top of the generated template, overwriting only
# the files present here, so the app gets our icon instead of Android's
# generic default one without needing to fork the rest of the manifest.
set_target_properties(komaro_qml_mobile PROPERTIES
    WIN32_EXECUTABLE TRUE
    QT_ANDROID_PACKAGE_NAME "${KOMARO_ANDROID_PACKAGE_NAME}"
    QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
)

target_link_libraries(komaro_qml_mobile PRIVATE
    komaro_core
    komaro_core_qml
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::QmlCore
)

qt_import_qml_plugins(komaro_qml_mobile)

# windeployqt deploys Qt DLLs next to a Windows executable; it doesn't apply
# to Android (APK packaging is handled by the "apk"/"komaro_qml_mobile_make_apk"
# targets that qt_add_executable already wires up under the ANDROID toolchain).
# Skip it there - on Android, Qt6::qmake resolves to the *host* Qt kit's qmake
# (needed for cross-build tooling), so without this guard the desktop kit's
# windeployqt.exe would otherwise run against the Android .so and fail.
if(NOT ANDROID)
    get_target_property(_qt6_qmake_executable Qt6::qmake IMPORTED_LOCATION)
    get_filename_component(_qt6_bin_dir "${_qt6_qmake_executable}" DIRECTORY)
    find_program(WINDEPLOYQT_EXECUTABLE windeployqt PATHS "${_qt6_bin_dir}" NO_DEFAULT_PATH)

    if(WINDEPLOYQT_EXECUTABLE)
        add_custom_command(TARGET komaro_qml_mobile POST_BUILD
            COMMAND "${WINDEPLOYQT_EXECUTABLE}"
                    --verbose 0
                    --qmldir "${CMAKE_CURRENT_SOURCE_DIR}/qml"
                    "$<TARGET_FILE:komaro_qml_mobile>"
            COMMENT "Deploying Qt runtime dependencies for komaro_qml_mobile"
        )
    else()
        message(WARNING "windeployqt not found under ${_qt6_bin_dir}; Qt runtime dependencies will not be deployed automatically")
    endif()
endif()

# `cmake --install build/<preset> --prefix <dir>` for the desktop-prototype
# build only - there's no equivalent for an Android build, which packages
# via the "apk" target instead (see qml/KB.md for the desktop install's
# mechanics; the same reasoning and the RPATH/dlopen wrapper-script fix
# apply here unchanged, since this shell also imports QtQuick.Controls).
if(NOT ANDROID)
    include(GNUInstallDirs)

    if(UNIX AND NOT APPLE)
        install(TARGETS komaro_qml_mobile
            RUNTIME DESTINATION ${CMAKE_INSTALL_LIBEXECDIR}
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        )

        file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/komaro_qml_mobile-wrapper.sh" [[#!/bin/sh
here="$(cd "$(dirname "$0")" && pwd)"
exec env LD_LIBRARY_PATH="$here/../lib:$LD_LIBRARY_PATH" "$here/../libexec/komaro_qml_mobile" "$@"
]])
        install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/komaro_qml_mobile-wrapper.sh"
            DESTINATION ${CMAKE_INSTALL_BINDIR}
            RENAME komaro_qml_mobile
        )
    else()
        install(TARGETS komaro_qml_mobile
            BUNDLE DESTINATION .
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        )
    endif()

    qt_generate_deploy_app_script(
        TARGET komaro_qml_mobile
        OUTPUT_SCRIPT deploy_script
        NO_UNSUPPORTED_PLATFORM_ERROR
    )
    install(SCRIPT ${deploy_script})

    install(CODE [[
qt6_deploy_qml_imports(TARGET komaro_qml_mobile PLUGINS_FOUND qml_plugin_libs)
qt6_deploy_runtime_dependencies(
    EXECUTABLE "$<TARGET_FILE:komaro_qml_mobile>"
    ADDITIONAL_MODULES ${qml_plugin_libs}
    NO_TRANSLATIONS
)
]])

    if(UNIX AND NOT APPLE)
        # Same desktop-menu integration as ../desktop - see qml/README.md.
        install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/komaro-mobile.desktop"
            DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications
        )
        install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/icons/komaro-mobile.svg"
            DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps
        )
    endif()
endif()

# `cmake --build <preset> --target install-apk` / `launch-apk` / `uninstall-apk`
# wrap the adb commands documented in README.md's "Install & run on a real
# device" section. ANDROID_SDK_ROOT is already a preset cache variable, so
# these work unmodified on any host's Android preset.
if(ANDROID)
    set(_android_apk_path "${CMAKE_BINARY_DIR}/android-build/build/outputs/apk/debug/android-build-debug.apk")
    set(_android_package "${KOMARO_ANDROID_PACKAGE_NAME}")

    add_custom_target(install-apk
        COMMAND "${ANDROID_SDK_ROOT}/platform-tools/adb" install -r "${_android_apk_path}"
        COMMENT "Installing ${_android_apk_path} onto the connected Android device"
    )
    add_dependencies(install-apk apk)

    add_custom_target(launch-apk
        COMMAND "${ANDROID_SDK_ROOT}/platform-tools/adb" shell am start
                -n "${_android_package}/org.qtproject.qt.android.bindings.QtActivity"
        COMMENT "Launching ${_android_package} on the connected Android device"
    )

    # Useful when switching a device between differently-signed builds of
    # this package (e.g. built on another machine) - adb install then fails
    # with INSTALL_FAILED_UPDATE_INCOMPATIBLE until the old one is removed.
    add_custom_target(uninstall-apk
        COMMAND "${ANDROID_SDK_ROOT}/platform-tools/adb" uninstall "${_android_package}"
        COMMENT "Uninstalling ${_android_package} from the connected Android device"
    )
endif()
