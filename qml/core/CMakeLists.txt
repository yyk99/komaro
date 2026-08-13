cmake_minimum_required(VERSION 3.21)

project(komaro_core LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Network)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

add_library(komaro_core STATIC
    src/InfluxResponseParser.cpp
    src/InfluxDbClient.cpp
)

target_include_directories(komaro_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(komaro_core PUBLIC
    Qt6::Core
    Qt6::Network
)

option(BUILD_TESTS "Build unit tests" ON)

if(BUILD_TESTS)
    enable_testing()
    find_package(GTest CONFIG REQUIRED)

    add_executable(komaro_core_tests
        tests/InfluxResponseParserTest.cpp
    )

    target_link_libraries(komaro_core_tests PRIVATE
        komaro_core
        GTest::gtest
        GTest::gtest_main
    )

    add_test(NAME komaro_core_tests COMMAND komaro_core_tests)
endif()
