cmake_minimum_required(VERSION 3.21)

project(komaro_core LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Network Qml)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# Q_OBJECT headers are listed explicitly (not just their .cpp files): AUTOMOC's
# transitive-include scanning silently found nothing to moc for this target
# when the headers were only reachable via #include, leaving InfluxDbClient
# and ConnectionManager's signals/metaobject undefined at link time. Explicit
# listing forces AUTOMOC to scan them directly.
add_library(komaro_core STATIC
    include/komaro/core/InfluxResponseParser.h
    include/komaro/core/InfluxDbClient.h
    include/komaro/core/RecentServers.h
    include/komaro/core/ConnectionManager.h
    include/komaro/core/ChartController.h
    include/komaro/core/MovingAverage.h
    include/komaro/core/SensorPoint.h
    src/InfluxResponseParser.cpp
    src/InfluxDbClient.cpp
    src/RecentServers.cpp
    src/ConnectionManager.cpp
    src/ChartController.cpp
    src/MovingAverage.cpp
)

target_include_directories(komaro_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(komaro_core PUBLIC
    Qt6::Core
    Qt6::Network
)

# Separate target from komaro_core: qt_add_qml_module's automatic plugin
# linkage (into consumers like komaro_qml_desktop) is only fully wired up
# when it creates the backing library itself, not when attached to an
# already-existing one.
qt_add_library(komaro_core_qml STATIC)

# QML_FILES live under qml/, a subdirectory of this module's resource root,
# which qt_add_qml_module treats as an "extra" importable sub-namespace as of
# Qt 6.8 (QTP0004). We don't use that sub-namespace; NEW just means a harmless
# extra qmldir gets generated for it, and is what Qt says will become the
# unconditional default in a future version.
qt_policy(SET QTP0004 NEW)

qt_add_qml_module(komaro_core_qml
    URI KomaroCore
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        qml/AppActions.qml
        qml/SensorChart.qml
)

target_link_libraries(komaro_core_qml PUBLIC
    Qt6::Qml
)

option(BUILD_TESTS "Build unit tests" ON)

if(BUILD_TESTS)
    enable_testing()
    find_package(GTest CONFIG REQUIRED)

    add_executable(komaro_core_tests
        tests/main.cpp
        tests/InfluxResponseParserTest.cpp
        tests/RecentServersTest.cpp
        tests/InfluxDbClientTest.cpp
        tests/MovingAverageTest.cpp
        tests/ChartControllerTest.cpp
    )

    target_link_libraries(komaro_core_tests PRIVATE
        komaro_core
        GTest::gtest
    )

    add_test(NAME komaro_core_tests COMMAND komaro_core_tests)
endif()
