# Qt/QML based apps

A QML app to display temperature/humidity plots from InfluxDB, targeting desktop and Android, similar in purpose to the `nano/plot_sensor.py` / `nano/plot_multi_sensor.py` Python scripts.

## Status

Desktop skeleton in `desktop/`: a Qt Quick `ApplicationWindow` with `File`/`Help` menus and a placeholder plot area filling the space below the menu bar. The app's actions (Connect, About, Exit) live in `core/qml/AppActions.qml` (the `KomaroCore` QML module) rather than being hardcoded in `desktop/qml/Main.qml`, so `Main.qml` is just a "thin shell" that arranges those shared actions into a `MenuBar`. Connect is wired end-to-end: an editable history combo box (backed by `core/`'s `ConnectionManager`, persisted via `QSettings`) feeds a real `InfluxDbClient` connectivity check, with the result shown as status text — but that still isn't wired into the plot area, which stays a placeholder.

`mobile/` is the second shell for that same shared `AppActions`: a `ToolBar`+`Drawer` (Material Dark) presentation instead of a `MenuBar`, currently built for desktop only as a quick way to iterate on the mobile UI without an Android toolchain — see `mobile/README.md` and `TODO.md`.

## Backend

Starting with a C++ backend (native Qt Quick app, CMake + Qt for Android). Other backends (e.g. PySide6/Python, reusing the existing `nano/` InfluxDB query code) may be added later.

## Desktop build

Qt 6.8.3 (LTS) is installed directly at `E:\qt6\6.8.3\msvc2022_64` and used via `CMAKE_PREFIX_PATH`. `desktop/CMakeLists.txt` pulls in `../core` via `add_subdirectory` and links it into the app. Using the CMake bundled with Visual Studio 2022 and the `windows-msvc` preset in `desktop/CMakePresets.json`:

```
cd qml/desktop
cmake --preset windows-msvc
cmake --build --preset windows-msvc-debug
ctest --preset windows-msvc-debug
```

Executables land in `build/windows-msvc/bin/<Config>/`, libraries in `build/windows-msvc/lib/<Config>/`. After a successful build, `windeployqt` runs automatically as a post-build step, so `komaro_qml_desktop.exe` is self-contained (no manual PATH/deploy step needed).

`desktop/vcpkg.json` (against the vcpkg instance at `G:\opt\vcpkg`) currently only pulls in `gtest`, needed to build `core`'s tests as part of this project; it isn't wired into `CMAKE_PREFIX_PATH`, so Qt itself is not built from source via vcpkg. Tests are gated by the `BUILD_TESTS` cache variable (default `ON`); pass `-DBUILD_TESTS=OFF` to skip them.
